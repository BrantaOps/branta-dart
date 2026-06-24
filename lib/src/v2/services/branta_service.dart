import '../../classes/branta_client_options.dart';
import '../../enums/destination_type.dart';
import '../../enums/privacy_mode.dart';
import '../../exceptions/branta_payment_exception.dart';
import '../../helpers/branta_extensions.dart';
import '../classes/guid_secret_generator.dart';
import '../classes/qr_parser.dart';
import '../interfaces/i_aes_encryption.dart';
import '../interfaces/i_branta_client.dart';
import '../interfaces/i_branta_service.dart';
import '../interfaces/i_secret_generator.dart';
import '../models/add_payment_result.dart';
import '../models/destination.dart';
import '../models/payment.dart';
import '../models/payments_result.dart';

class BrantaService implements IBrantaService {
  final IBrantaClient _client;
  final IAesEncryption _aesEncryption;
  final BrantaClientOptions _defaultOptions;
  final ISecretGenerator _secretGenerator;

  BrantaService({
    required IBrantaClient client,
    required IAesEncryption aesEncryption,
    required BrantaClientOptions defaultOptions,
    ISecretGenerator? secretGenerator,
  })  : _client = client,
        _aesEncryption = aesEncryption,
        _defaultOptions = defaultOptions,
        _secretGenerator = secretGenerator ?? GuidSecretGenerator();

  @override
  Future<PaymentsResult> getPaymentsByQrCodeAsync(String qrText, {BrantaClientOptions? options}) async {
    final parser = QRParser(qrText);

    if (parser.isOnChainZk()) {
      final additionalValues = parser.destinations
          .where((d) => d.value.getHashZkType() != null)
          .map((d) => d.value)
          .toList();
      return _getPaymentsForZkAsync(
        parser.onChainEncryptionText!,
        parser.onChainEncryptionSecret,
        additionalValues,
        options: options,
      );
    }

    final destination = parser.destination!;
    final privacy = _resolvePrivacy(options);
    if (privacy == PrivacyMode.strict && destination.getHashZkType() == null) {
      return PaymentsResult(
        payments: [],
        verifyUrl: _buildVerifyUrl(options, destination),
      );
    }

    return getPaymentsAsync(destination, options: options);
  }

  Future<PaymentsResult> _getPaymentsForZkAsync(
    String lookupValue,
    String? encryptionKey,
    List<String> additionalHashValues, {
    BrantaClientOptions? options,
  }) async {
    final payments = await _client.getPaymentsAsync(lookupValue, options: options);

    final keys = <String, String>{};
    for (final payment in payments) {
      await _decryptDestinations(payment, lookupValue, encryptionKey, null, keys);
      for (final value in additionalHashValues) {
        await _decryptHashZkDestinations(payment, value, keys);
      }
    }

    return PaymentsResult(
      payments: payments,
      verifyUrl: _buildVerifyUrl(options, lookupValue, keys),
    );
  }

  Future<void> _decryptHashZkDestinations(
    Payment payment,
    String plainValue,
    Map<String, String> keys,
  ) async {
    final hashZkType = plainValue.getHashZkType();
    if (hashZkType == null) return;

    final key = plainValue.toNormalizedHash();
    for (final destination in payment.destinations) {
      if (!destination.isZk || destination.type != hashZkType) continue;
      try {
        destination.value = await _aesEncryption.decrypt(destination.value, key);
        destination.isEncrypted = false;
        final zkId = destination.zkId;
        if (zkId != null) keys.putIfAbsent(zkId, () => key);
        await _tryDecryptMetadata(payment, destination, key);
      } catch (_) {
        // Key didn't match this destination — leave it encrypted.
      }
    }
  }

  @override
  Future<PaymentsResult> getPaymentsAsync(
    String destinationValue, {
    String? destinationEncryptionKey,
    BrantaClientOptions? options,
  }) async {
    final hashZkType = destinationValue.getHashZkType();
    final privacy = _resolvePrivacy(options);

    if (hashZkType == null && destinationEncryptionKey == null && privacy == PrivacyMode.strict) {
      throw BrantaPaymentException(
        'PrivacyMode.Strict does not permit plain-text lookups for this destination type.',
      );
    }

    final normalizedDestination = hashZkType != null ? destinationValue.toLowerCase() : destinationValue;
    String lookupValue;
    if (hashZkType != null) {
      final key = normalizedDestination.toNormalizedHash();
      lookupValue = await _aesEncryption.encrypt(normalizedDestination, key, deterministicNonce: true);
    } else {
      lookupValue = destinationValue;
    }

    var payments = await _client.getPaymentsAsync(lookupValue, options: options);

    if (payments.isEmpty && hashZkType != null && privacy != PrivacyMode.strict) {
      lookupValue = normalizedDestination;
      payments = await _client.getPaymentsAsync(lookupValue, options: options);
    }

    final keys = <String, String>{};
    for (final payment in payments) {
      await _decryptDestinations(payment, normalizedDestination, destinationEncryptionKey, hashZkType, keys);
    }

    return PaymentsResult(
      payments: payments,
      verifyUrl: _buildVerifyUrl(options, lookupValue, keys),
    );
  }

  Future<void> _decryptDestinations(
    Payment payment,
    String destinationValue,
    String? encryptionKey,
    DestinationType? hashZkType,
    Map<String, String> keys,
  ) async {
    for (final destination in payment.destinations) {
      destination.isEncrypted = destination.isZk;
      if (!destination.isZk) continue;

      if (destination.type == DestinationType.bitcoinAddress) {
        if (encryptionKey == null) continue;
        try {
          destination.value = await _aesEncryption.decrypt(destination.value, encryptionKey);
          destination.isEncrypted = false;
          final zkId = destination.zkId;
          if (zkId != null) keys.putIfAbsent(zkId, () => encryptionKey);
          await _tryDecryptMetadata(payment, destination, encryptionKey);
        } catch (_) {
          // Key didn't match — leave it encrypted.
        }
      } else if (hashZkType != null && destination.type == hashZkType) {
        final key = destinationValue.toNormalizedHash();
        try {
          destination.value = await _aesEncryption.decrypt(destination.value, key);
          destination.isEncrypted = false;
          final zkId = destination.zkId;
          if (zkId != null) keys.putIfAbsent(zkId, () => key);
          await _tryDecryptMetadata(payment, destination, key);
        } catch (_) {
          // Key didn't match — leave it encrypted.
        }
      }
    }
  }

  Future<void> _tryDecryptMetadata(
    Payment payment,
    Destination destination,
    String keyUsed,
  ) async {
    final encryptedDek = destination.encryptedDek;
    if (encryptedDek == null || payment.metadata == null || payment.isMetadataDecrypted) return;
    try {
      final dek = await _aesEncryption.decrypt(encryptedDek, keyUsed);
      payment.metadata = await _aesEncryption.decrypt(payment.metadata!, dek);
      payment.isMetadataDecrypted = true;
    } catch (_) {
      // DEK decryption failed — leave metadata as-is.
    }
  }

  @override
  Future<AddPaymentResult> addPaymentAsync(Payment payment, {BrantaClientOptions? options}) async {
    final privacy = _resolvePrivacy(options);
    if (privacy == PrivacyMode.strict && payment.destinations.any((d) => !d.isZk)) {
      throw BrantaPaymentException(
        'PrivacyMode.Strict requires all destinations to be ZK; one or more destinations have isZk = false.',
      );
    }

    String? dek;
    if (payment.metadata != null && payment.destinations.any((d) => d.isZk)) {
      dek = _secretGenerator.generate();
      payment.metadata = await _aesEncryption.encrypt(payment.metadata!, dek, deterministicNonce: false);
    }

    final secret = _secretGenerator.generate();
    final encryptedToKey = <String, String>{};

    for (final destination in payment.destinations) {
      if (!destination.isZk) continue;

      if (destination.type == DestinationType.bitcoinAddress) {
        destination.value = await _aesEncryption.encrypt(
          destination.value,
          secret,
          deterministicNonce: _secretGenerator.deterministicNonce,
        );
        encryptedToKey[destination.value] = secret;
        if (dek != null) {
          destination.encryptedDek = await _aesEncryption.encrypt(dek, secret, deterministicNonce: false);
        }
      } else {
        final hashZkType = destination.value.getHashZkType();
        if (hashZkType == null) {
          throw BrantaPaymentException(
            "destination type '${destination.type}' does not support ZK",
          );
        }
        final normalizedValue = destination.value.toLowerCase();
        final key = normalizedValue.toNormalizedHash();
        destination.value = await _aesEncryption.encrypt(normalizedValue, key, deterministicNonce: true);
        encryptedToKey[destination.value] = key;
        if (dek != null) {
          destination.encryptedDek = await _aesEncryption.encrypt(dek, key, deterministicNonce: false);
        }
      }
    }

    final responsePayment = await _client.postPaymentAsync(payment, options: options);
    if (responsePayment == null) {
      throw BrantaPaymentException('No payment returned from server.');
    }

    final keys = <String, String>{};
    for (final d in responsePayment.destinations) {
      final zkId = d.zkId;
      if (zkId != null && encryptedToKey.containsKey(d.value)) {
        keys[zkId] = encryptedToKey[d.value]!;
      }
    }

    final primaryValue = payment.destinations.isNotEmpty ? payment.destinations.first.value : '';
    final verifyUrl = _buildVerifyUrl(options, primaryValue, keys);

    return AddPaymentResult(payment: responsePayment, secret: secret, verifyUrl: verifyUrl);
  }

  @override
  Future<bool> isApiKeyValidAsync({BrantaClientOptions? options}) {
    return _client.isApiKeyValidAsync(options: options);
  }

  String _buildVerifyUrl(BrantaClientOptions? options, String paymentLookup, [Map<String, String>? keys]) {
    final baseUrl = (options?.baseUrl ?? _defaultOptions.baseUrl).url;
    final encoded = Uri.encodeComponent(paymentLookup);
    var url = '$baseUrl/v2/verify/$encoded';
    if (keys != null && keys.isNotEmpty) {
      url += keys.toUrlFragment();
    }
    return url;
  }

  PrivacyMode _resolvePrivacy(BrantaClientOptions? options) {
    return options?.privacy ?? _defaultOptions.privacy;
  }
}
