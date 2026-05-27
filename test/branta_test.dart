import 'package:branta/branta.dart';
import 'package:branta/src/helpers/aes_encryption.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test stubs
// ---------------------------------------------------------------------------

class _ClientCall {
  final String address;
  final BrantaClientOptions? options;
  _ClientCall(this.address, this.options);
}

class MockBrantaClient implements IBrantaClient {
  final Map<String, List<Payment>> _getPaymentsMap = {};
  Payment? _postPaymentResponse;
  bool _isApiKeyValid = true;

  final List<_ClientCall> getPaymentsCalls = [];
  int postPaymentCallCount = 0;
  BrantaClientOptions? lastIsApiKeyValidOptions;

  void setupGetPayments(String address, List<Payment> payments) {
    _getPaymentsMap[address] = payments;
  }

  void setupPostPayment(Payment payment) {
    _postPaymentResponse = payment;
  }

  void setIsApiKeyValid(bool value) => _isApiKeyValid = value;

  @override
  Future<List<Payment>> getPaymentsAsync(String destinationValue,
      {BrantaClientOptions? options}) async {
    getPaymentsCalls.add(_ClientCall(destinationValue, options));
    return _getPaymentsMap[destinationValue] ?? [];
  }

  @override
  Future<Payment?> postPaymentAsync(Payment payment,
      {BrantaClientOptions? options}) async {
    postPaymentCallCount++;
    return _postPaymentResponse;
  }

  @override
  Future<bool> isApiKeyValidAsync({BrantaClientOptions? options}) async {
    lastIsApiKeyValidOptions = options;
    return _isApiKeyValid;
  }

  int countGetCalls(String address) =>
      getPaymentsCalls.where((c) => c.address == address).length;
}

class _EncryptCall {
  final String value;
  final String secret;
  final bool deterministicNonce;
  _EncryptCall(this.value, this.secret, this.deterministicNonce);
}

class _DecryptCall {
  final String encrypted;
  final String secret;
  _DecryptCall(this.encrypted, this.secret);
}

class _EncryptSetup {
  final String value;
  final String secret;
  final bool deterministicNonce;
  final String result;
  _EncryptSetup(this.value, this.secret, this.deterministicNonce, this.result);
}

class _DecryptSetup {
  final String encrypted;
  final String secret;
  final dynamic result; // String or Exception
  _DecryptSetup(this.encrypted, this.secret, this.result);
}

class MockAesEncryption implements IAesEncryption {
  final List<_EncryptSetup> _encryptSetups = [];
  final List<_DecryptSetup> _decryptSetups = [];
  final List<_EncryptCall> encryptCalls = [];
  final List<_DecryptCall> decryptCalls = [];

  void setupEncrypt(String value, String secret, String result,
      {bool deterministicNonce = false}) {
    _encryptSetups
        .add(_EncryptSetup(value, secret, deterministicNonce, result));
  }

  void setupDecryptResult(String encrypted, String secret, String result) {
    _decryptSetups.add(_DecryptSetup(encrypted, secret, result));
  }

  void setupDecryptThrows(String encrypted, String secret, Exception error) {
    _decryptSetups.add(_DecryptSetup(encrypted, secret, error));
  }

  @override
  Future<String> encrypt(String value, String secret,
      {bool deterministicNonce = false}) async {
    encryptCalls.add(_EncryptCall(value, secret, deterministicNonce));
    for (final s in _encryptSetups) {
      if (s.value == value &&
          s.secret == secret &&
          s.deterministicNonce == deterministicNonce) {
        return s.result;
      }
    }
    throw StateError(
        'MockAesEncryption: no encrypt setup for ($value, $secret, deterministicNonce=$deterministicNonce)');
  }

  @override
  Future<String> decrypt(String encryptedValue, String secret) async {
    decryptCalls.add(_DecryptCall(encryptedValue, secret));
    for (final s in _decryptSetups) {
      if (s.encrypted == encryptedValue && s.secret == secret) {
        if (s.result is Exception) throw s.result as Exception;
        return s.result as String;
      }
    }
    throw StateError(
        'MockAesEncryption: no decrypt setup for ($encryptedValue, $secret)');
  }

  int countEncryptCalls(String value, String secret,
          {bool deterministicNonce = false}) =>
      encryptCalls
          .where((c) =>
              c.value == value &&
              c.secret == secret &&
              c.deterministicNonce == deterministicNonce)
          .length;

  int countDecryptCalls(String encrypted, String secret) =>
      decryptCalls
          .where((c) => c.encrypted == encrypted && c.secret == secret)
          .length;
}

class MockSecretGenerator implements ISecretGenerator {
  final String _secret;
  MockSecretGenerator(this._secret);

  @override
  String generate() => _secret;

  @override
  bool get deterministicNonce => false;
}

// ---------------------------------------------------------------------------
// Test constants
// ---------------------------------------------------------------------------

const String _bitcoinAddress = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
const String _encryptedBitcoinAddress = 'encrypted-bitcoin-address';
const String _secret = 'test-secret';

const String _bolt11Invoice = 'lnbc100n1ptest';
const String _encryptedBolt11 = 'encrypted-bolt11-value';
const String _decryptedBolt11 = 'lnbc100n1pdecrypted';

const String _arkAddress = 'ark100testaddress';
const String _encryptedArkAddress = 'encrypted-ark-address';

final String _bolt11Hash = _bolt11Invoice.toNormalizedHash();
final String _arkHash = _arkAddress.toNormalizedHash();

Payment get _plainBitcoinPayment => PaymentBuilder()
    .addDestination(_bitcoinAddress, type: DestinationType.bitcoinAddress)
    .build();

Payment get _zkBitcoinPayment => PaymentBuilder()
    .addDestination(_encryptedBitcoinAddress,
        type: DestinationType.bitcoinAddress)
    .setZk()
    .build();

Payment get _zkBolt11Payment => PaymentBuilder()
    .addDestination(_encryptedBolt11, type: DestinationType.bolt11)
    .setZk()
    .build();

Payment get _plainBolt11Payment => PaymentBuilder()
    .addDestination(_bolt11Invoice, type: DestinationType.bolt11)
    .build();

Payment get _zkArkPayment => PaymentBuilder()
    .addDestination(_encryptedArkAddress, type: DestinationType.arkAddress)
    .setZk()
    .build();

// ---------------------------------------------------------------------------
// Service factory helpers
// ---------------------------------------------------------------------------

const _looseOptions = BrantaClientOptions(
  baseUrl: BrantaServerBaseUrl.localhost,
  defaultApiKey: 'test-api-key',
  privacy: PrivacyMode.loose,
);

const _strictOptions = BrantaClientOptions(
  baseUrl: BrantaServerBaseUrl.localhost,
  defaultApiKey: 'test-api-key',
  privacy: PrivacyMode.strict,
);

BrantaService _makeService(MockBrantaClient client, MockAesEncryption aes,
    {bool strict = false}) {
  return BrantaService(
    client: client,
    aesEncryption: aes,
    defaultOptions: strict ? _strictOptions : _looseOptions,
    secretGenerator: MockSecretGenerator(_secret),
  );
}

void _setupDefaultMocks(MockAesEncryption aes) {
  aes.setupDecryptResult(_encryptedBitcoinAddress, _secret, _bitcoinAddress);
  aes.setupEncrypt(_bolt11Invoice, _bolt11Hash, _encryptedBolt11,
      deterministicNonce: true);
  aes.setupDecryptResult(_encryptedBolt11, _bolt11Hash, _decryptedBolt11);
  aes.setupEncrypt(_bitcoinAddress, _secret, _encryptedBitcoinAddress);
  aes.setupEncrypt(_arkAddress, _arkHash, _encryptedArkAddress,
      deterministicNonce: true);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // AesEncryption
  // -------------------------------------------------------------------------
  group('AesEncryption', () {
    test('encrypt and decrypt round-trips', () async {
      const address = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
      const secret = '12345';
      final encrypted = await AesEncryption.encrypt(address, secret);
      expect(await AesEncryption.decrypt(encrypted, secret), equals(address));
    });

    test('deterministic nonce produces same ciphertext each time', () async {
      const address = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
      const secret = '12345';
      final first =
          await AesEncryption.encrypt(address, secret, deterministicNonce: true);
      final second =
          await AesEncryption.encrypt(address, secret, deterministicNonce: true);
      expect(first, equals(second));
    });

    test('random nonce produces different ciphertext each time', () async {
      const address = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
      const secret = '12345';
      final first = await AesEncryption.encrypt(address, secret);
      final second = await AesEncryption.encrypt(address, secret);
      expect(first, isNot(equals(second)));
    });
  });

  // -------------------------------------------------------------------------
  // BrantaServerBaseUrl
  // -------------------------------------------------------------------------
  group('BrantaServerBaseUrl', () {
    test('localhost returns correct URL', () {
      expect(BrantaServerBaseUrl.localhost.url, equals('http://localhost:3000'));
    });

    test('production returns correct URL', () {
      expect(BrantaServerBaseUrl.production.url,
          equals('https://guardrail.branta.pro'));
    });

    test('staging returns correct URL', () {
      expect(BrantaServerBaseUrl.staging.url,
          equals('https://staging.guardrail.branta.pro'));
    });
  });

  // -------------------------------------------------------------------------
  // BrantaExtensions
  // -------------------------------------------------------------------------
  group('BrantaExtensions', () {
    test('isBolt11 returns true for lnbc prefix', () {
      expect('lnbc100n1ptest'.isBolt11(), isTrue);
    });

    test('isBolt11 returns true for lntb prefix', () {
      expect('lntb100n1ptest'.isBolt11(), isTrue);
    });

    test('isBolt11 returns true for lnbcrt prefix', () {
      expect('lnbcrt100n1ptest'.isBolt11(), isTrue);
    });

    test('isBolt11 is case-insensitive', () {
      expect('LNBC100N1PTEST'.isBolt11(), isTrue);
    });

    test('isBolt11 returns false for non-bolt11 values', () {
      expect('bc1qabc'.isBolt11(), isFalse);
      expect(_arkAddress.isBolt11(), isFalse);
    });

    test('isArk returns true for ark1 prefix', () {
      expect('ark1qqjqtest'.isArk(), isTrue);
    });

    test('isArk is case-insensitive', () {
      expect('ARK1QQJQTEST'.isArk(), isTrue);
    });

    test('isArk returns false for non-ark values', () {
      expect('bc1qabc'.isArk(), isFalse);
    });

    test('getHashZkType returns bolt11 for bolt11 invoice', () {
      expect(_bolt11Invoice.getHashZkType(), equals(DestinationType.bolt11));
    });

    test('getHashZkType returns arkAddress for ark address', () {
      expect(_arkAddress.getHashZkType(), equals(DestinationType.arkAddress));
    });

    test('getHashZkType returns null for bitcoin address', () {
      expect(_bitcoinAddress.getHashZkType(), isNull);
    });

    test('toNormalizedHash returns 64-char lowercase hex', () {
      final hash = _bolt11Invoice.toNormalizedHash();
      expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('toNormalizedHash is case-insensitive', () {
      expect(_bolt11Invoice.toNormalizedHash(),
          equals(_bolt11Invoice.toUpperCase().toNormalizedHash()));
    });

    test('toUrlFragment formats pairs with k- prefix', () {
      final fragment = {'zkId1': 'secret1'}.toUrlFragment();
      expect(fragment, equals('#k-zkId1=secret1'));
    });

    test('toUrlFragment joins multiple pairs with &', () {
      // LinkedHashMap preserves insertion order
      final map = <String, String>{};
      map['a'] = '1';
      map['b'] = '2';
      expect(map.toUrlFragment(), equals('#k-a=1&k-b=2'));
    });
  });

  // -------------------------------------------------------------------------
  // QRParser
  // -------------------------------------------------------------------------
  group('QRParser', () {
    test('bitcoin URI sets bitcoinAddress type and destination', () {
      final result =
          QRParser('bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa');

      expect(result.destination,
          equals('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'));
      expect(result.destinationType, equals(DestinationType.bitcoinAddress));
      expect(result.onChainEncryptionText, isNull);
      expect(result.onChainEncryptionSecret, isNull);
    });

    test('bitcoin URI with branta params sets ZK properties', () {
      final result = QRParser(
          'bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa?branta_id=abc%2Bdef%3D&branta_secret=1234');

      expect(result.destination,
          equals('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'));
      expect(result.destinationType, equals(DestinationType.bitcoinAddress));
      expect(result.onChainEncryptionText, equals('abc+def='));
      expect(result.onChainEncryptionSecret, equals('1234'));
    });

    test('bitcoin URI decodes URI-encoded lightning param', () {
      final result = QRParser(
          'bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa?lightning=lnbc100n1ptest%3Dpadded');

      expect(result.destinations.length, equals(2));
      expect(result.destinations[1].value, equals('lnbc100n1ptest=padded'));
      expect(result.destinations[1].type, equals(DestinationType.bolt11));
    });

    test('plain bitcoin address sets bitcoinAddress type', () {
      final result = QRParser('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa');

      expect(result.destination,
          equals('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'));
      expect(result.destinationType, equals(DestinationType.bitcoinAddress));
    });

    test('lightning bolt11 URI sets bolt11 type', () {
      final result = QRParser('lightning:lnbc100n1ptest');

      expect(result.destination, equals('lnbc100n1ptest'));
      expect(result.destinationType, equals(DestinationType.bolt11));
    });

    test('plain bolt11 sets bolt11 type', () {
      final result = QRParser('lnbc100n1ptest');

      expect(result.destination, equals('lnbc100n1ptest'));
      expect(result.destinationType, equals(DestinationType.bolt11));
    });

    test('lightning bolt12 URI sets bolt12 type', () {
      final result = QRParser('lightning:lno1qcptest');

      expect(result.destination, equals('lno1qcptest'));
      expect(result.destinationType, equals(DestinationType.bolt12));
    });

    test('plain bolt12 sets bolt12 type', () {
      final result = QRParser('lno1qcptest');

      expect(result.destination, equals('lno1qcptest'));
      expect(result.destinationType, equals(DestinationType.bolt12));
    });

    test('lightning LNURL URI sets lnUrl type', () {
      final result = QRParser('lightning:LNURL1DP68GURN8GHJ');

      expect(result.destination, equals('LNURL1DP68GURN8GHJ'));
      expect(result.destinationType, equals(DestinationType.lnUrl));
    });

    test('plain LNURL sets lnUrl type', () {
      final result = QRParser('LNURL1DP68GURN8GHJ');

      expect(result.destination, equals('LNURL1DP68GURN8GHJ'));
      expect(result.destinationType, equals(DestinationType.lnUrl));
    });

    test('Ethereum address sets tetherAddress type', () {
      final result =
          QRParser('0x742d35Cc6634C0532925a3b844Bc454e4438f44e');

      expect(result.destination,
          equals('0x742d35Cc6634C0532925a3b844Bc454e4438f44e'));
      expect(result.destinationType, equals(DestinationType.tetherAddress));
    });

    test('Tron address sets tetherAddress type', () {
      final result = QRParser('TJmUNSGV6b1CCVXN1KkABY49nUJGWDH3Hd');

      expect(result.destination,
          equals('TJmUNSGV6b1CCVXN1KkABY49nUJGWDH3Hd'));
      expect(result.destinationType, equals(DestinationType.tetherAddress));
    });

    test('ark address sets arkAddress type', () {
      final result = QRParser('ark1qqjqtest');

      expect(result.destination, equals('ark1qqjqtest'));
      expect(result.destinationType, equals(DestinationType.arkAddress));
    });

    test('unrecognized text sets null type', () {
      final result = QRParser('not-any-known-format');

      expect(result.destination, equals('not-any-known-format'));
      expect(result.destinationType, isNull);
    });

    test('leading and trailing whitespace is trimmed', () {
      final result = QRParser('  lnbc100n1ptest  ');

      expect(result.destination, equals('lnbc100n1ptest'));
      expect(result.destinationType, equals(DestinationType.bolt11));
    });

    test('combined QR (bitcoin + lightning) parses both destinations', () {
      final result = QRParser(
          'bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa?&lightning=lnbc100n1ptest');

      expect(result.destinations.length, equals(2));
      expect(result.destination,
          equals('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'));
      expect(result.destinationType, equals(DestinationType.bitcoinAddress));
      expect(result.destinations[1].value, equals('lnbc100n1ptest'));
      expect(result.destinations[1].type, equals(DestinationType.bolt11));
      expect(result.isOnChainZk(), isFalse);
    });

    test('combined QR with multiple alt destinations parses all', () {
      final result = QRParser(
          'bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa?&lightning=lnbc100n1ptest&ark=ark100testaddress');

      expect(result.destinations.length, equals(3));
      expect(result.destination,
          equals('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'));
      expect(result.destinationType, equals(DestinationType.bitcoinAddress));
      expect(result.destinations[1].value, equals('lnbc100n1ptest'));
      expect(result.destinations[1].type, equals(DestinationType.bolt11));
      expect(result.destinations[2].value, equals('ark100testaddress'));
      expect(result.destinations[2].type, equals(DestinationType.arkAddress));
      expect(result.isOnChainZk(), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // PaymentBuilder
  // -------------------------------------------------------------------------
  group('PaymentBuilder', () {
    test('addDestination adds destination with correct value and type', () {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .build();

      expect(payment.destinations.length, equals(1));
      expect(payment.destinations[0].value, equals(_bitcoinAddress));
      expect(payment.destinations[0].type,
          equals(DestinationType.bitcoinAddress));
      expect(payment.destinations[0].isZk, isFalse);
    });

    test('setZk marks last destination as ZK and assigns zkId', () {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .build();

      expect(payment.destinations[0].isZk, isTrue);
      expect(payment.destinations[0].zkId, isNotNull);
      expect(payment.destinations[0].zkId!.length, greaterThan(0));
    });

    test('setZk only applies to the last destination', () {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .addDestination(_bolt11Invoice, type: DestinationType.bolt11)
          .setZk()
          .build();

      expect(payment.destinations[0].isZk, isFalse);
      expect(payment.destinations[1].isZk, isTrue);
    });

    test('setDescription sets description', () {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress)
          .setDescription('test desc')
          .build();

      expect(payment.description, equals('test desc'));
    });

    test('setTtl sets ttl', () {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress)
          .setTtl(3600)
          .build();

      expect(payment.ttl, equals(3600));
    });

    test('addMetadata adds key-value pair to metadata JSON', () {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress)
          .addMetadata('orderId', '123')
          .build();

      expect(payment.metadata, contains('"orderId"'));
      expect(payment.metadata, contains('"123"'));
    });
  });

  // -------------------------------------------------------------------------
  // BrantaService — GetPaymentsByQrCodeAsync
  // -------------------------------------------------------------------------
  group('BrantaService.getPaymentsByQrCodeAsync', () {
    late MockBrantaClient client;
    late MockAesEncryption aes;
    late BrantaService service;
    late BrantaService strictService;

    setUp(() {
      client = MockBrantaClient();
      aes = MockAesEncryption();
      _setupDefaultMocks(aes);
      service = _makeService(client, aes);
      strictService = _makeService(client, aes, strict: true);
    });

    test('ZK bitcoin URI uses branta_id as lookup value and decrypts', () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [_zkBitcoinPayment]);
      final qrText =
          'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret';

      final result = await service.getPaymentsByQrCodeAsync(qrText);

      expect(client.countGetCalls(_encryptedBitcoinAddress), equals(1));
      expect(result.payments[0].destinations[0].value,
          equals(_bitcoinAddress));
    });

    test('plain bitcoin URI uses address as lookup', () async {
      client.setupGetPayments(_bitcoinAddress, [_plainBitcoinPayment]);

      final result =
          await service.getPaymentsByQrCodeAsync('bitcoin:$_bitcoinAddress');

      expect(client.countGetCalls(_bitcoinAddress), equals(1));
      expect(result.payments.length, equals(1));
    });

    test('lightning bolt11 URI uses encrypted invoice as lookup', () async {
      client.setupGetPayments(_encryptedBolt11, [_plainBolt11Payment]);

      await service.getPaymentsByQrCodeAsync('lightning:$_bolt11Invoice');

      expect(client.countGetCalls(_encryptedBolt11), equals(1));
    });

    test('uppercase lightning bolt11 URI uses encrypted invoice as lookup',
        () async {
      client.setupGetPayments(_encryptedBolt11, [_plainBolt11Payment]);

      await service
          .getPaymentsByQrCodeAsync('lightning:${_bolt11Invoice.toUpperCase()}');

      expect(client.countGetCalls(_encryptedBolt11), equals(1));
    });

    test(
        'lightning bolt11 URI leaves unrelated ZK bitcoin destination encrypted',
        () async {
      final payment = PaymentBuilder()
          .addDestination(_encryptedBolt11, type: DestinationType.bolt11)
          .setZk()
          .addDestination(_encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .build();

      client.setupGetPayments(_encryptedBolt11, [payment]);

      final result =
          await service.getPaymentsByQrCodeAsync('lightning:$_bolt11Invoice');

      expect(result.payments.length, equals(1));
      expect(result.payments[0].destinations[0].value,
          equals(_decryptedBolt11));
      expect(result.payments[0].destinations[0].isEncrypted, isFalse);
      expect(result.payments[0].destinations[1].value,
          equals(_encryptedBitcoinAddress));
      expect(result.payments[0].destinations[1].isEncrypted, isTrue);
    });

    test('combined ZK QR decrypts bitcoin, bolt11, and ark destinations',
        () async {
      final payment = PaymentBuilder()
          .addDestination(_encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .addDestination(_encryptedBolt11, type: DestinationType.bolt11)
          .setZk()
          .addDestination(_encryptedArkAddress,
              type: DestinationType.arkAddress)
          .setZk()
          .build();

      client.setupGetPayments(_encryptedBitcoinAddress, [payment]);
      aes.setupDecryptResult(_encryptedArkAddress, _arkHash, 'decrypted-ark');

      final zkId = payment.destinations[0].zkId!;
      final bolt11ZkId = payment.destinations[1].zkId!;
      final arkZkId = payment.destinations[2].zkId!;

      final qrText =
          'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret&lightning=$_bolt11Invoice&ark=$_arkAddress';
      final result = await service.getPaymentsByQrCodeAsync(qrText);

      expect(result.payments.length, equals(1));
      expect(result.payments[0].destinations[0].value,
          equals(_bitcoinAddress));
      expect(result.payments[0].destinations[1].value,
          equals(_decryptedBolt11));
      expect(
        result.verifyUrl,
        equals(
          'http://localhost:3000/v2/verify/${Uri.encodeComponent(_encryptedBitcoinAddress)}'
          '#k-$zkId=$_secret&k-$bolt11ZkId=$_bolt11Hash&k-$arkZkId=$_arkHash',
        ),
      );
      expect(aes.countDecryptCalls(_encryptedBitcoinAddress, _secret),
          equals(1));
      expect(aes.countDecryptCalls(_encryptedBolt11, _bolt11Hash), equals(1));
    });

    // Strict mode
    test('strict: plain bitcoin URI returns empty PaymentsResult', () async {
      final result =
          await strictService.getPaymentsByQrCodeAsync('bitcoin:$_bitcoinAddress');

      expect(result.payments, isEmpty);
      expect(result.verifyUrl,
          equals('http://localhost:3000/v2/verify/$_bitcoinAddress'));
      expect(client.getPaymentsCalls, isEmpty);
    });

    test('strict: ZK bitcoin URI succeeds', () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [_zkBitcoinPayment]);
      final qrText =
          'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret';

      final result = await strictService.getPaymentsByQrCodeAsync(qrText);

      expect(result.payments.length, equals(1));
      expect(client.countGetCalls(_encryptedBitcoinAddress), equals(1));
    });

    test('strict: lightning bolt11 URI succeeds', () async {
      client.setupGetPayments(_encryptedBolt11, [_plainBolt11Payment]);

      await strictService.getPaymentsByQrCodeAsync('lightning:$_bolt11Invoice');

      expect(client.countGetCalls(_encryptedBolt11), equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // BrantaService — GetPaymentsAsync
  // -------------------------------------------------------------------------
  group('BrantaService.getPaymentsAsync', () {
    late MockBrantaClient client;
    late MockAesEncryption aes;
    late BrantaService service;
    late BrantaService strictService;

    setUp(() {
      client = MockBrantaClient();
      aes = MockAesEncryption();
      _setupDefaultMocks(aes);
      service = _makeService(client, aes);
      strictService = _makeService(client, aes, strict: true);
    });

    test('returns payments when client succeeds', () async {
      client.setupGetPayments(_bitcoinAddress, [_plainBitcoinPayment]);

      final result = await service.getPaymentsAsync(_bitcoinAddress);

      expect(result.payments.length, equals(1));
      expect(result.payments[0].destinations[0].value,
          equals(_bitcoinAddress));
    });

    test('returns empty list with verifyUrl when client returns empty', () async {
      final result = await service.getPaymentsAsync(_bitcoinAddress);

      expect(result.payments, isEmpty);
      expect(result.verifyUrl,
          equals('http://localhost:3000/v2/verify/$_bitcoinAddress'));
    });

    test('forwards options to client', () async {
      client.setupGetPayments(_bitcoinAddress, [_plainBitcoinPayment]);

      await service.getPaymentsAsync(_bitcoinAddress, options: _looseOptions);

      expect(client.getPaymentsCalls.last.options, equals(_looseOptions));
    });

    test('ZK bitcoin address decrypts destination value', () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [_zkBitcoinPayment]);

      final result = await service.getPaymentsAsync(_encryptedBitcoinAddress,
          destinationEncryptionKey: _secret);

      expect(result.payments.length, equals(1));
      expect(result.payments[0].destinations[0].value,
          equals(_bitcoinAddress));
      expect(
          aes.countDecryptCalls(_encryptedBitcoinAddress, _secret), equals(1));
    });

    test('ZK bitcoin address without key leaves destination encrypted',
        () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [_zkBitcoinPayment]);

      final result =
          await service.getPaymentsAsync(_encryptedBitcoinAddress);

      expect(result.payments[0].destinations[0].value,
          equals(_encryptedBitcoinAddress));
      expect(result.payments[0].destinations[0].isEncrypted, isTrue);
      expect(aes.decryptCalls, isEmpty);
    });

    test('ZK bitcoin address with wrong key leaves destination encrypted',
        () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [_zkBitcoinPayment]);
      aes.setupDecryptThrows(_encryptedBitcoinAddress, 'wrong-key',
          Exception('Decryption failed: auth tag mismatch'));

      final result = await service.getPaymentsAsync(_encryptedBitcoinAddress,
          destinationEncryptionKey: 'wrong-key');

      expect(result.payments[0].destinations[0].value,
          equals(_encryptedBitcoinAddress));
      expect(result.payments[0].destinations[0].isEncrypted, isTrue);
    });

    test('non-ZK destination does not attempt decryption', () async {
      client.setupGetPayments(_bitcoinAddress, [_plainBitcoinPayment]);

      final result = await service.getPaymentsAsync(_bitcoinAddress,
          destinationEncryptionKey: _secret);

      expect(result.payments[0].destinations[0].value,
          equals(_bitcoinAddress));
      expect(aes.decryptCalls, isEmpty);
    });

    test('ZK bolt11 with bolt11 lookup decrypts using hash', () async {
      client.setupGetPayments(_encryptedBolt11, [_zkBolt11Payment]);

      final result = await service.getPaymentsAsync(_bolt11Invoice);

      expect(result.payments.length, equals(1));
      expect(result.payments[0].destinations[0].value,
          equals(_decryptedBolt11));
      expect(client.countGetCalls(_encryptedBolt11), equals(1));
      expect(aes.countDecryptCalls(_encryptedBolt11, _bolt11Hash), equals(1));
    });

    test('ZK bolt11 with non-bolt11 lookup does not decrypt', () async {
      const nonBolt11 = 'not-a-bolt11-value';
      client.setupGetPayments(nonBolt11, [_zkBolt11Payment]);

      final result = await service.getPaymentsAsync(nonBolt11);

      expect(result.payments[0].destinations[0].value,
          equals(_encryptedBolt11));
      expect(client.countGetCalls(nonBolt11), equals(1));
      expect(aes.decryptCalls, isEmpty);
    });

    test('non-ZK bolt11 destination does not decrypt', () async {
      client.setupGetPayments(_encryptedBolt11, [_plainBolt11Payment]);

      final result = await service.getPaymentsAsync(_bolt11Invoice);

      expect(result.payments[0].destinations[0].value,
          equals(_bolt11Invoice));
      expect(client.countGetCalls(_encryptedBolt11), equals(1));
      expect(aes.decryptCalls, isEmpty);
    });

    test('plain bitcoin address sets verifyUrl', () async {
      client.setupGetPayments(_bitcoinAddress, [_plainBitcoinPayment]);

      final result = await service.getPaymentsAsync(_bitcoinAddress);

      expect(result.verifyUrl,
          equals('http://localhost:3000/v2/verify/$_bitcoinAddress'));
    });

    test('plain bolt11 fallback sets verifyUrl to plain value', () async {
      client.setupGetPayments(_bolt11Invoice, [_plainBolt11Payment]);

      final result = await service.getPaymentsAsync(_bolt11Invoice);

      expect(result.verifyUrl,
          equals('http://localhost:3000/v2/verify/$_bolt11Invoice'));
    });

    test('ZK bitcoin address sets verifyUrl with key fragment', () async {
      final payment = PaymentBuilder()
          .addDestination(_encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .build();
      final zkId = payment.destinations[0].zkId!;
      client.setupGetPayments(_encryptedBitcoinAddress, [payment]);

      final result = await service.getPaymentsAsync(_encryptedBitcoinAddress,
          destinationEncryptionKey: _secret);

      expect(
        result.verifyUrl,
        equals(
            'http://localhost:3000/v2/verify/${Uri.encodeComponent(_encryptedBitcoinAddress)}#k-$zkId=$_secret'),
      );
    });

    test('ZK bolt11 sets verifyUrl with key fragment', () async {
      final payment = PaymentBuilder()
          .addDestination(_encryptedBolt11, type: DestinationType.bolt11)
          .setZk()
          .build();
      final zkId = payment.destinations[0].zkId!;
      client.setupGetPayments(_encryptedBolt11, [payment]);

      final result = await service.getPaymentsAsync(_bolt11Invoice);

      expect(
        result.verifyUrl,
        equals(
            'http://localhost:3000/v2/verify/${Uri.encodeComponent(_encryptedBolt11)}#k-$zkId=$_bolt11Hash'),
      );
    });

    test('loose mode bolt11 not found falls back to plain and sets plain verifyUrl',
        () async {
      // encrypted lookup returns empty, plain lookup also empty (default)

      final result = await service.getPaymentsAsync(_bolt11Invoice);

      expect(result.payments, isEmpty);
      expect(result.verifyUrl,
          equals('http://localhost:3000/v2/verify/$_bolt11Invoice'));
      expect(client.countGetCalls(_encryptedBolt11), equals(1));
      expect(client.countGetCalls(_bolt11Invoice), equals(1));
    });

    // Strict mode
    test('strict: plain bitcoin address throws BrantaPaymentException',
        () async {
      await expectLater(
        () => strictService.getPaymentsAsync(_bitcoinAddress),
        throwsA(isA<BrantaPaymentException>()),
      );
      expect(client.getPaymentsCalls, isEmpty);
    });

    test('strict: encrypted bitcoin with secret decrypts destination',
        () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [_zkBitcoinPayment]);

      final result = await strictService.getPaymentsAsync(
          _encryptedBitcoinAddress,
          destinationEncryptionKey: _secret);

      expect(result.payments.length, equals(1));
      expect(result.payments[0].destinations[0].value,
          equals(_bitcoinAddress));
      expect(result.payments[0].destinations[0].isEncrypted, isFalse);
      expect(client.countGetCalls(_encryptedBitcoinAddress), equals(1));
      expect(
          aes.countDecryptCalls(_encryptedBitcoinAddress, _secret), equals(1));
      expect(aes.encryptCalls, isEmpty);
    });

    test('strict: encrypted bitcoin with secret sets verifyUrl with fragment',
        () async {
      final payment = PaymentBuilder()
          .addDestination(_encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .build();
      final zkId = payment.destinations[0].zkId!;
      client.setupGetPayments(_encryptedBitcoinAddress, [payment]);

      final result = await strictService.getPaymentsAsync(
          _encryptedBitcoinAddress,
          destinationEncryptionKey: _secret);

      expect(
        result.verifyUrl,
        equals(
            'http://localhost:3000/v2/verify/${Uri.encodeComponent(_encryptedBitcoinAddress)}#k-$zkId=$_secret'),
      );
    });

    test('strict: encrypted bitcoin with wrong key leaves encrypted', () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [_zkBitcoinPayment]);
      aes.setupDecryptThrows(_encryptedBitcoinAddress, 'wrong-key',
          Exception('Decryption failed: auth tag mismatch'));

      final result = await strictService.getPaymentsAsync(
          _encryptedBitcoinAddress,
          destinationEncryptionKey: 'wrong-key');

      expect(result.payments[0].destinations[0].value,
          equals(_encryptedBitcoinAddress));
      expect(result.payments[0].destinations[0].isEncrypted, isTrue);
    });

    test('strict: bolt11 does not throw and uses encrypted lookup', () async {
      client.setupGetPayments(_encryptedBolt11, [_zkBolt11Payment]);

      await strictService.getPaymentsAsync(_bolt11Invoice);

      expect(client.countGetCalls(_encryptedBolt11), equals(1));
    });

    test('strict: ark address does not throw and uses encrypted lookup',
        () async {
      client.setupGetPayments(_encryptedArkAddress, [_zkArkPayment]);

      await strictService.getPaymentsAsync(_arkAddress);

      expect(client.countGetCalls(_encryptedArkAddress), equals(1));
    });

    test('strict: bolt11 does not fall back to plain text lookup', () async {
      client.setupGetPayments(_bolt11Invoice, [_plainBolt11Payment]);

      final result = await strictService.getPaymentsAsync(_bolt11Invoice);

      expect(result.payments, isEmpty);
      expect(result.verifyUrl,
          equals('http://localhost:3000/v2/verify/${Uri.encodeComponent(_encryptedBolt11)}'));
      expect(client.countGetCalls(_encryptedBolt11), equals(1));
      expect(client.countGetCalls(_bolt11Invoice), equals(0));
    });
  });

  // -------------------------------------------------------------------------
  // BrantaService — AddPaymentAsync
  // -------------------------------------------------------------------------
  group('BrantaService.addPaymentAsync', () {
    late MockBrantaClient client;
    late MockAesEncryption aes;
    late BrantaService service;
    late BrantaService strictService;

    setUp(() {
      client = MockBrantaClient();
      aes = MockAesEncryption();
      _setupDefaultMocks(aes);
      service = _makeService(client, aes);
      strictService = _makeService(client, aes, strict: true);
    });

    test('plain destination does not encrypt', () async {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .build();
      client.setupPostPayment(_plainBitcoinPayment);

      await service.addPaymentAsync(payment);

      expect(aes.encryptCalls, isEmpty);
    });

    test('ZK bitcoin address encrypts with generated secret', () async {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .build();
      final zkId = payment.destinations[0].zkId!;

      final responsePayment = PaymentBuilder()
          .addDestination(_encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .build();
      responsePayment.destinations[0].isZk = true;
      responsePayment.destinations[0].zkId = zkId;

      client.setupPostPayment(responsePayment);

      final result = await service.addPaymentAsync(payment);

      expect(aes.countEncryptCalls(_bitcoinAddress, _secret), equals(1));
      expect(result.secret, equals(_secret));
      expect(payment.destinations[0].value, equals(_encryptedBitcoinAddress));
    });

    test('ZK bolt11 encrypts with deterministic hash', () async {
      final payment = PaymentBuilder()
          .addDestination(_bolt11Invoice, type: DestinationType.bolt11)
          .setZk()
          .build();
      final zkId = payment.destinations[0].zkId!;

      final responsePayment = PaymentBuilder()
          .addDestination(_encryptedBolt11, type: DestinationType.bolt11)
          .build();
      responsePayment.destinations[0].isZk = true;
      responsePayment.destinations[0].zkId = zkId;

      client.setupPostPayment(responsePayment);

      await service.addPaymentAsync(payment);

      expect(
          aes.countEncryptCalls(_bolt11Invoice, _bolt11Hash,
              deterministicNonce: true),
          equals(1));
      expect(payment.destinations[0].value, equals(_encryptedBolt11));
    });

    test('ZK ark address encrypts with deterministic hash', () async {
      final payment = PaymentBuilder()
          .addDestination(_arkAddress, type: DestinationType.arkAddress)
          .setZk()
          .build();
      final zkId = payment.destinations[0].zkId!;

      final responsePayment = PaymentBuilder()
          .addDestination(_encryptedArkAddress,
              type: DestinationType.arkAddress)
          .build();
      responsePayment.destinations[0].isZk = true;
      responsePayment.destinations[0].zkId = zkId;

      client.setupPostPayment(responsePayment);

      await service.addPaymentAsync(payment);

      expect(
          aes.countEncryptCalls(_arkAddress, _arkHash,
              deterministicNonce: true),
          equals(1));
      expect(payment.destinations[0].value, equals(_encryptedArkAddress));
    });

    test('ZK bitcoin sets verifyUrl with key fragment', () async {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .build();
      final zkId = payment.destinations[0].zkId!;

      final responsePayment = PaymentBuilder()
          .addDestination(_encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .build();
      responsePayment.destinations[0].isZk = true;
      responsePayment.destinations[0].zkId = zkId;

      client.setupPostPayment(responsePayment);

      final result = await service.addPaymentAsync(payment);

      expect(
        result.verifyUrl,
        equals(
            'http://localhost:3000/v2/verify/${Uri.encodeComponent(_encryptedBitcoinAddress)}#k-$zkId=$_secret'),
      );
    });

    test('returns generated secret', () async {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .build();

      final responsePayment = PaymentBuilder()
          .addDestination(_encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .build();
      responsePayment.destinations[0].isZk = true;
      responsePayment.destinations[0].zkId = payment.destinations[0].zkId!;

      client.setupPostPayment(responsePayment);

      final result = await service.addPaymentAsync(payment);

      expect(result.secret, equals(_secret));
    });

    test('unsupported ZK type throws without calling client', () async {
      final payment = PaymentBuilder()
          .addDestination('0xdeadbeef', type: DestinationType.tetherAddress)
          .setZk()
          .build();

      await expectLater(
        () => service.addPaymentAsync(payment),
        throwsA(isA<BrantaPaymentException>()),
      );
      expect(client.postPaymentCallCount, equals(0));
    });

    // Strict mode
    test('strict: plain destination throws BrantaPaymentException', () async {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .build();

      await expectLater(
        () => strictService.addPaymentAsync(payment),
        throwsA(isA<BrantaPaymentException>()),
      );
      expect(client.postPaymentCallCount, equals(0));
    });

    test('strict: all ZK destinations succeeds', () async {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .build();
      final zkId = payment.destinations[0].zkId!;

      final responsePayment = PaymentBuilder()
          .addDestination(_encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .build();
      responsePayment.destinations[0].isZk = true;
      responsePayment.destinations[0].zkId = zkId;

      client.setupPostPayment(responsePayment);

      await strictService.addPaymentAsync(payment);

      expect(client.postPaymentCallCount, equals(1));
    });

    test('strict: mixed destinations throws BrantaPaymentException', () async {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress,
              type: DestinationType.bitcoinAddress)
          .setZk()
          .addDestination(_bolt11Invoice, type: DestinationType.bolt11)
          .build();

      await expectLater(
        () => strictService.addPaymentAsync(payment),
        throwsA(isA<BrantaPaymentException>()),
      );
      expect(client.postPaymentCallCount, equals(0));
    });
  });

  // -------------------------------------------------------------------------
  // BrantaService — IsApiKeyValidAsync
  // -------------------------------------------------------------------------
  group('BrantaService.isApiKeyValidAsync', () {
    late MockBrantaClient client;
    late MockAesEncryption aes;
    late BrantaService service;

    setUp(() {
      client = MockBrantaClient();
      aes = MockAesEncryption();
      service = _makeService(client, aes);
    });

    test('returns true when client returns true', () async {
      client.setIsApiKeyValid(true);
      expect(await service.isApiKeyValidAsync(), isTrue);
    });

    test('returns false when client returns false', () async {
      client.setIsApiKeyValid(false);
      expect(await service.isApiKeyValidAsync(), isFalse);
    });

    test('forwards options to client', () async {
      await service.isApiKeyValidAsync(options: _looseOptions);
      expect(client.lastIsApiKeyValidOptions, equals(_looseOptions));
    });
  });
}
