import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../classes/branta_api_options.dart';
import '../enums/branta_environment.dart';
import '../enums/destination_type.dart';
import '../exceptions/branta_payment_exception.dart';
import '../exceptions/incomplete_error.dart';
import '../helpers/branta_extensions.dart';
import '../classes/guid_secret_generator.dart';
import '../classes/qr_parser.dart';
import '../classes/aes_encryption_service.dart';
import '../interfaces/i_aes_encryption.dart';
import '../interfaces/i_branta_client.dart';
import '../interfaces/i_secret_generator.dart';
import '../models/add_payment_result.dart';
import '../models/destination.dart';
import '../models/payment.dart';
import '../models/platform.dart';
import '../models/verify_result.dart';
import 'branta_client.dart';

class _TamperedError implements Exception {}

VerifyResult _toVerifyResult(List<Payment> payments, String verifyUrl) =>
    payments.isEmpty
    ? VerifyResult(status: VerifyStatus.unknown, verifyUrl: verifyUrl)
    : VerifyResult(
        status: VerifyStatus.match,
        payments: payments,
        verifyUrl: verifyUrl,
      );

/// Encrypt and post this copy. A failed post must leave the caller's Payment reusable.
Payment _copyPayment(Payment payment) {
  Platform? copyPlatform(Platform? platform) => platform == null
      ? null
      : Platform(
          name: platform.name,
          logoUrl: platform.logoUrl,
          logoLightUrl: platform.logoLightUrl,
        );

  return Payment(
    description: payment.description,
    destinations: payment.destinations
        .map(
          (destination) => Destination(
            value: destination.value,
            isPrimary: destination.isPrimary,
            isEncrypted: destination.isEncrypted,
            type: destination.type,
            id: destination.id,
            encryptedDek: destination.encryptedDek,
          ),
        )
        .toList(),
    createdAt: payment.createdAt,
    ttl: payment.ttl,
    metadata: payment.metadata,
    platform: payment.platform,
    platformLogoUrl: payment.platformLogoUrl,
    platformLogoLightUrl: payment.platformLogoLightUrl,
    parentPlatform: copyPlatform(payment.parentPlatform),
    childPlatform: copyPlatform(payment.childPlatform),
  );
}

bool _addressesMatch(String a, String b) {
  bool isBech32(String v) =>
      RegExp(r'^(bc|tb|bcrt)1', caseSensitive: false).hasMatch(v);
  if (isBech32(a) && isBech32(b)) return a.toLowerCase() == b.toLowerCase();
  return a == b;
}

/// The single on-chain address every on-chain instruction agrees on, or null if there is none.
String? _uniformOnChainAddress(QRParser parser) {
  final addresses = parser.destinations
      .where(
        (d) =>
            d.type == DestinationType.bitcoinAddress &&
            d.value.trim().isNotEmpty,
      )
      .map((d) => d.value)
      .toList();
  if (addresses.isEmpty) return null;
  final first = addresses.first;
  for (final address in addresses.skip(1)) {
    if (!_addressesMatch(first, address)) throw _TamperedError();
  }
  return first;
}

class BrantaService {
  final IBrantaClient _client;
  final IAesEncryption _aesEncryption;
  final BrantaApiOptions _defaultOptions;
  final ISecretGenerator _secretGenerator;
  final bool _ownsHttpClient;

  BrantaService({
    required BrantaEnvironment environment,
    String? apiKey,
    String? hmacSecret,
    http.Client? httpClient,
    IBrantaClient? client,
    IAesEncryption? aesEncryption,
    ISecretGenerator? secretGenerator,
  }) : _defaultOptions = BrantaApiOptions(
         environment: environment,
         apiKey: apiKey,
         hmacSecret: hmacSecret,
       ),
       _aesEncryption = aesEncryption ?? AesEncryptionService(),
       _secretGenerator = secretGenerator ?? GuidSecretGenerator(),
       _ownsHttpClient = client == null && httpClient == null,
       _client =
           client ??
           BrantaClient(
             httpClient: httpClient ?? http.Client(),
             defaultOptions: BrantaApiOptions(
               environment: environment,
               apiKey: apiKey,
               hmacSecret: hmacSecret,
             ),
           );

  /// Closes the HTTP client this service created. A client passed in is left open.
  void close() {
    if (_ownsHttpClient && _client is BrantaClient) {
      _client.dispose();
    }
  }

  Future<VerifyResult> verify(String input, {BrantaApiOptions? options}) async {
    final parser = QRParser(input);
    final lookup = parser.onChainEncryptionText ?? parser.destination ?? '';

    try {
      final expectedOnChainAddress = _uniformOnChainAddress(parser);

      if (parser.hasUnverifiableInstruction) {
        return VerifyResult(
          status: VerifyStatus.unknown,
          verifyUrl: _buildVerifyUrl(options, lookup),
        );
      }

      if (parser.hasBrantaParams()) {
        final additionalValues = parser.destinations
            .where((d) => d.value.getDerivedKeyType() != null)
            .map((d) => d.value)
            .toList();
        if (expectedOnChainAddress == null && additionalValues.isEmpty) {
          return VerifyResult(
            status: VerifyStatus.unknown,
            verifyUrl: _buildVerifyUrl(options, lookup),
          );
        }
        final lookedUp = await _lookupByBrantaId(
          parser.onChainEncryptionText!,
          parser.onChainEncryptionSecret,
          additionalValues,
          expectedOnChainAddress,
          options: options,
        );
        return _toVerifyResult(lookedUp.payments, lookedUp.verifyUrl);
      }

      final destination = parser.destination!;
      if (destination.getDerivedKeyType() == null) {
        return VerifyResult(
          status: VerifyStatus.unknown,
          verifyUrl: _buildVerifyUrl(options, destination),
        );
      }

      final lookedUp = await _lookupByDerivedKey(destination, options: options);
      return _toVerifyResult(lookedUp.payments, lookedUp.verifyUrl);
    } on _TamperedError {
      return VerifyResult(
        status: VerifyStatus.tampered,
        verifyUrl: _buildVerifyUrl(options, lookup),
      );
    } on IncompleteError {
      return VerifyResult(
        status: VerifyStatus.incomplete,
        verifyUrl: _buildVerifyUrl(options, lookup),
      );
    }
  }

  Future<({List<Payment> payments, String verifyUrl})> _lookupByBrantaId(
    String lookupValue,
    String? encryptionKey,
    List<String> additionalHashValues,
    String? expectedOnChainAddress, {
    BrantaApiOptions? options,
  }) async {
    final payments = await _client.getPayments(lookupValue, options: options);

    final keys = <String, String>{};
    final bound = <Payment>[];
    for (final payment in payments) {
      final onChainBound = await _decryptDestinations(
        payment,
        encryptionKey,
        keys,
        expectedOnChainAddress: expectedOnChainAddress,
      );
      var hashesBound = true;
      for (final value in additionalHashValues) {
        if (!await _decryptDerivedKeyDestinations(payment, value, keys)) {
          hashesBound = false;
        }
      }
      final hasPayableInstruction =
          expectedOnChainAddress != null || additionalHashValues.isNotEmpty;
      if (hasPayableInstruction && onChainBound && hashesBound) {
        bound.add(payment);
      }
    }

    return (
      payments: bound,
      verifyUrl: _buildVerifyUrl(options, lookupValue, keys),
    );
  }

  /// True when at least one destination of the matching derived-key type decrypted with [plainValue].
  Future<bool> _decryptDerivedKeyDestinations(
    Payment payment,
    String plainValue,
    Map<String, String> keys,
  ) async {
    final derivedType = plainValue.getDerivedKeyType();
    if (derivedType == null) return false;

    final key = plainValue.toNormalizedHash();
    var bound = false;
    for (final destination in payment.destinations) {
      if (!destination.isEncrypted || destination.type != derivedType) continue;
      String decrypted;
      try {
        decrypted = await _aesEncryption.decrypt(destination.value, key);
      } on StateError {
        rethrow;
      } catch (_) {
        // Key didn't match this destination — leave it encrypted.
        continue;
      }
      if (decrypted.toLowerCase() != plainValue.toLowerCase()) {
        throw _TamperedError();
      }
      destination.value = decrypted;
      destination.isEncrypted = false;
      final id = destination.id;
      if (id != null) keys.putIfAbsent(id, () => key);
      await _tryDecryptMetadata(payment, destination, key);
      bound = true;
    }
    return bound;
  }

  Future<({List<Payment> payments, String verifyUrl})> _lookupByDerivedKey(
    String destinationValue, {
    BrantaApiOptions? options,
  }) async {
    final normalizedDestination = destinationValue.toLowerCase();
    final key = normalizedDestination.toNormalizedHash();
    final lookupValue = await _aesEncryption.encrypt(
      normalizedDestination,
      key,
      deterministicNonce: true,
    );

    final payments = await _client.getPayments(lookupValue, options: options);

    final keys = <String, String>{};
    final bound = <Payment>[];
    for (final payment in payments) {
      if (await _decryptDerivedKeyDestinations(
        payment,
        normalizedDestination,
        keys,
      )) {
        bound.add(payment);
      }
    }

    return (
      payments: bound,
      verifyUrl: _buildVerifyUrl(options, lookupValue, keys),
    );
  }

  /// True when the on-chain side is bound: either no on-chain address was expected,
  /// or one was decrypted and matched [expectedOnChainAddress].
  Future<bool> _decryptDestinations(
    Payment payment,
    String? encryptionKey,
    Map<String, String> keys, {
    String? expectedOnChainAddress,
  }) async {
    var onChainBound = expectedOnChainAddress == null;
    for (final destination in payment.destinations) {
      if (!destination.isEncrypted) continue;
      if (destination.type != DestinationType.bitcoinAddress) continue;
      if (encryptionKey == null) continue;
      String decrypted;
      try {
        decrypted = await _aesEncryption.decrypt(
          destination.value,
          encryptionKey,
        );
      } on StateError {
        rethrow;
      } catch (_) {
        // Key didn't match this destination — leave it encrypted.
        continue;
      }
      if (expectedOnChainAddress != null &&
          !_addressesMatch(decrypted, expectedOnChainAddress)) {
        throw _TamperedError();
      }
      if (expectedOnChainAddress != null) onChainBound = true;
      destination.value = decrypted;
      destination.isEncrypted = false;
      final id = destination.id;
      if (id != null) keys.putIfAbsent(id, () => encryptionKey);
      await _tryDecryptMetadata(payment, destination, encryptionKey);
    }
    return onChainBound;
  }

  Future<void> _tryDecryptMetadata(
    Payment payment,
    Destination destination,
    String keyUsed,
  ) async {
    final encryptedDek = destination.encryptedDek;
    if (encryptedDek == null ||
        payment.metadata == null ||
        payment.isMetadataDecrypted) {
      return;
    }
    try {
      final dek = await _aesEncryption.decrypt(encryptedDek, keyUsed);
      payment.metadata = await _aesEncryption.decrypt(payment.metadata!, dek);
      payment.isMetadataDecrypted = true;
      liftDescriptionFromMetadata(payment);
    } on StateError {
      rethrow;
    } catch (_) {
      // DEK decryption failed — leave metadata as-is.
    }
  }

  Future<AddPaymentResult> addPayment(
    Payment payment, {
    BrantaApiOptions? options,
  }) async {
    final submitted = _copyPayment(payment);
    foldDescriptionIntoMetadata(submitted);

    String? dek;
    if (submitted.metadata != null && submitted.destinations.isNotEmpty) {
      dek = _secretGenerator.generate();
      submitted.metadata = await _aesEncryption.encrypt(
        submitted.metadata!,
        dek,
        deterministicNonce: false,
      );
    }

    final secret = _secretGenerator.generate();
    final encryptedToKey = <String, String>{};

    for (final destination in submitted.destinations) {
      destination.id ??= const Uuid().v4();

      final detected =
          destination.type ?? detectDestinationType(destination.value);
      if (destination.type == null && detected != null) {
        destination.type = detected;
      }

      if (detected == DestinationType.bitcoinAddress) {
        destination.value = await _aesEncryption.encrypt(
          destination.value,
          secret,
          deterministicNonce: _secretGenerator.deterministicNonce,
        );
        encryptedToKey[destination.value] = secret;
        if (dek != null) {
          destination.encryptedDek = await _aesEncryption.encrypt(
            dek,
            secret,
            deterministicNonce: false,
          );
        }
      } else {
        final derivedType = destination.value.getDerivedKeyType();
        if (derivedType == null) {
          throw BrantaPaymentException(
            "destination type '${destination.type}' cannot be encrypted",
          );
        }
        final normalizedValue = destination.value.toLowerCase();
        final key = normalizedValue.toNormalizedHash();
        destination.value = await _aesEncryption.encrypt(
          normalizedValue,
          key,
          deterministicNonce: true,
        );
        encryptedToKey[destination.value] = key;
        if (dek != null) {
          destination.encryptedDek = await _aesEncryption.encrypt(
            dek,
            key,
            deterministicNonce: false,
          );
        }
      }
    }

    final responsePayment = await _client.postPayment(
      submitted,
      options: options,
    );
    if (responsePayment == null) {
      throw const BrantaPaymentException('No payment returned from server.');
    }

    final keys = <String, String>{};
    for (final d in responsePayment.destinations) {
      final id = d.id;
      if (id != null && encryptedToKey.containsKey(d.value)) {
        keys[id] = encryptedToKey[d.value]!;
      }
    }

    final primaryValue = submitted.destinations.isNotEmpty
        ? submitted.destinations.first.value
        : '';
    return AddPaymentResult(
      payment: responsePayment,
      secret: secret,
      verifyUrl: _buildVerifyUrl(options, primaryValue, keys),
    );
  }

  Future<bool> isApiKeyValid({BrantaApiOptions? options}) {
    return _client.isApiKeyValid(options: options);
  }

  String _resolveBaseUrl(BrantaApiOptions? options) {
    final environment = options?.environment ?? _defaultOptions.environment;
    if (environment == null) {
      throw StateError('Branta: environment is a required option.');
    }
    return environment.url;
  }

  String _buildVerifyUrl(
    BrantaApiOptions? options,
    String paymentLookup, [
    Map<String, String>? keys,
  ]) {
    final baseUrl = _resolveBaseUrl(options);
    var url = '$baseUrl/v2/verify/${encodeUriComponent(paymentLookup)}';
    if (keys != null && keys.isNotEmpty) url += keys.toUrlFragment();
    return url;
  }
}
