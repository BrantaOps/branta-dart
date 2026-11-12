import 'package:branta/branta.dart';
import 'package:branta/src/enums/destination_type.dart' hide DestinationType;
import 'package:branta/src/exceptions/incomplete_error.dart';
import 'package:branta/src/helpers/aes_gcm_cipher.dart';
import 'package:branta/src/helpers/branta_extensions.dart';
import 'package:branta/src/classes/qr_parser.dart';
import 'package:branta/src/interfaces/aes_encryption.dart';
import 'package:branta/src/interfaces/branta_client.dart';
import 'package:branta/src/interfaces/secret_generator.dart';
import 'package:test/test.dart';

class ClientCall {
  final String address;
  final BrantaApiOptions? options;
  ClientCall(this.address, this.options);
}

class MockBrantaClient implements BrantaClient {
  final Map<String, List<Payment>> _getPaymentsMap = {};
  Payment? _postPaymentResponse;
  bool _isApiKeyValid = true;
  Object? getError;
  Object? postError;

  final List<ClientCall> getPaymentsCalls = [];
  int postPaymentCallCount = 0;
  Payment? lastPosted;
  BrantaApiOptions? lastIsApiKeyValidOptions;

  void setupGetPayments(String address, List<Payment> payments) {
    _getPaymentsMap[address] = payments;
  }

  void setupPostPayment(Payment payment) {
    _postPaymentResponse = payment;
  }

  void setIsApiKeyValid(bool value) => _isApiKeyValid = value;

  @override
  Future<List<Payment>> getPayments(
    String destinationValue, {
    BrantaApiOptions? options,
  }) async {
    getPaymentsCalls.add(ClientCall(destinationValue, options));
    if (getError != null) throw getError!;
    return _getPaymentsMap[destinationValue] ?? [];
  }

  @override
  Future<Payment?> postPayment(
    Payment payment, {
    BrantaApiOptions? options,
  }) async {
    postPaymentCallCount++;
    lastPosted = payment;
    if (postError != null) throw postError!;
    return _postPaymentResponse;
  }

  @override
  Future<bool> isApiKeyValid({BrantaApiOptions? options}) async {
    lastIsApiKeyValidOptions = options;
    return _isApiKeyValid;
  }
}

class EncryptCall {
  final String value;
  final String secret;
  final bool deterministicNonce;
  EncryptCall(this.value, this.secret, this.deterministicNonce);
}

class DecryptCall {
  final String encrypted;
  final String secret;
  DecryptCall(this.encrypted, this.secret);
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
  final dynamic result;
  _DecryptSetup(this.encrypted, this.secret, this.result);
}

class MockAesEncryption implements AesEncryption {
  final List<_EncryptSetup> _encryptSetups = [];
  final List<_DecryptSetup> _decryptSetups = [];
  final List<EncryptCall> encryptCalls = [];
  final List<DecryptCall> decryptCalls = [];

  void setupEncrypt(
    String value,
    String secret,
    String result, {
    bool deterministicNonce = false,
  }) {
    _encryptSetups.add(
      _EncryptSetup(value, secret, deterministicNonce, result),
    );
  }

  void setupDecryptResult(String encrypted, String secret, String result) {
    _decryptSetups.add(_DecryptSetup(encrypted, secret, result));
  }

  void setupDecryptThrows(String encrypted, String secret, Exception error) {
    _decryptSetups.add(_DecryptSetup(encrypted, secret, error));
  }

  @override
  Future<String> encrypt(
    String value,
    String secret, {
    bool deterministicNonce = false,
  }) async {
    encryptCalls.add(EncryptCall(value, secret, deterministicNonce));
    for (final s in _encryptSetups) {
      if (s.value == value &&
          s.secret == secret &&
          s.deterministicNonce == deterministicNonce) {
        return s.result;
      }
    }
    throw StateError(
      'MockAesEncryption: no encrypt setup for ($value, $secret, deterministicNonce=$deterministicNonce)',
    );
  }

  @override
  Future<String> decrypt(String encryptedValue, String secret) async {
    decryptCalls.add(DecryptCall(encryptedValue, secret));
    for (final s in _decryptSetups) {
      if (s.encrypted == encryptedValue && s.secret == secret) {
        if (s.result is Exception) throw s.result as Exception;
        return s.result as String;
      }
    }
    throw StateError(
      'MockAesEncryption: no decrypt setup for ($encryptedValue, $secret)',
    );
  }
}

class MockSecretGenerator implements SecretGenerator {
  final String _secret;
  int generateCount = 0;
  MockSecretGenerator(this._secret);

  @override
  String generate() {
    generateCount++;
    return _secret;
  }

  @override
  bool get deterministicNonce => false;
}

class MockSequentialSecretGenerator implements SecretGenerator {
  final List<String> _values;
  int _index = 0;
  MockSequentialSecretGenerator(this._values);

  @override
  String generate() => _values[_index++];

  @override
  bool get deterministicNonce => false;
}

const String _bitcoinAddress = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
const String _swappedAddress = '1BvBMSEYstWetqTFn5Au4m4GFg7xJaNVN2';
const String _encryptedBitcoinAddress = 'encrypted-bitcoin-address';
const String _secret = 'test-secret';
const String _usdtPolygonAddress = '0x278297528c32eCa01295B0d2135984d3442ec963';
const String _usdtPolygonAddressLower = '0x278297528c32eca01295b0d2135984d3442ec963';
const String _usdcPolygonAddress = '0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B';
const String _swappedUsdtPolygonAddress =
    '0x1111111111111111111111111111111111111111';
const String _encryptedUsdtPolygonAddress = 'encrypted-usdt-polygon-address';
const String _encryptedUsdcPolygonAddress = 'encrypted-usdc-polygon-address';
const String _swappedEvmAddress = _swappedUsdtPolygonAddress;
const String _usdtEthereumAddress = '0xBF5550253939187432Ef4dccE8089765d3DCb47f';
const String _encryptedUsdtEthereumAddress = 'encrypted-usdt-ethereum-address';
const String _usdcEthereumAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
const String _encryptedUsdcEthereumAddress = 'encrypted-usdc-ethereum-address';
const String _usdtBscAddress = '0x55d398326f99059fF775485246999027B3197955';
const String _encryptedUsdtBscAddress = 'encrypted-usdt-bsc-address';
const String _usdcBscAddress = '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d';
const String _encryptedUsdcBscAddress = 'encrypted-usdc-bsc-address';
const String _usdtTronAddress = 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb';
const String _encryptedUsdtTronAddress = 'encrypted-usdt-tron-address';
const String _swappedTronAddress = 'TXyZ1111111111111111111111111111111';
const String _usdtTonAddress =
    'EQDtFpEwcFAEcRe5mLVh2N6C0y-_tur3BYOM93pEZPw390by';
const String _encryptedUsdtTonAddress = 'encrypted-usdt-ton-address';
const String _swappedTonAddress =
    'EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c';
const String _usdtSolanaAddress = 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB';
const String _encryptedUsdtSolanaAddress = 'encrypted-usdt-solana-address';
const String _usdcSolanaAddress = '7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDofycyinf';
const String _encryptedUsdcSolanaAddress = 'encrypted-usdc-solana-address';
const String _swappedSolanaAddress = '11111111111111111111111111111111';

String _brantaChainLookup(String scheme, String address, String encrypted) =>
    '$scheme:$address?value=50&branta_id=${Uri.encodeComponent(encrypted)}&branta_secret=${Uri.encodeComponent(_secret)}';

const String _bolt11Invoice = 'lnbc100n1ptest';
const String _encryptedBolt11 = 'encrypted-bolt11-value';
const String _arkAddress = 'ark100testaddress';
const String _encryptedArkAddress = 'encrypted-ark-address';
const String _registeredBech32 = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
const String _encryptedBech32 = 'encrypted-bech32-address';

String _brantaUsdtPolygonLookup([
  String address = _usdtPolygonAddress,
  String secret = _secret,
]) =>
    'pol:$address?value=50&user=send&currency=USD&branta_id=${Uri.encodeComponent(_encryptedUsdtPolygonAddress)}&branta_secret=${Uri.encodeComponent(secret)}';

String _brantaUsdcPolygonLookup([
  String address = _usdcPolygonAddress,
  String secret = _secret,
]) =>
    'pol:$address?value=50&user=send&currency=USD&branta_id=${Uri.encodeComponent(_encryptedUsdcPolygonAddress)}&branta_secret=${Uri.encodeComponent(secret)}';

final String _bolt11Hash = _bolt11Invoice.toNormalizedHash();
final String _arkHash = _arkAddress.toNormalizedHash();

Payment _encryptedPayment(
  String value,
  DestinationType type, {
  String id = 'dest-id',
  String? encryptedDek,
  String? metadata,
}) {
  return Payment(
    metadata: metadata,
    destinations: [
      Destination(value: value, type: type, id: id, encryptedDek: encryptedDek),
    ],
  );
}

BrantaService _makeService(
  MockBrantaClient client,
  MockAesEncryption aes, {
  SecretGenerator? secretGenerator,
}) {
  return BrantaService(
    environment: BrantaEnvironment.localhost,
    apiKey: 'test-api-key',
    client: client,
    aesEncryption: aes,
    secretGenerator: secretGenerator ?? MockSecretGenerator(_secret),
  );
}

void _setupDefaultMocks(MockAesEncryption aes) {
  aes.setupDecryptResult(_encryptedBitcoinAddress, _secret, _bitcoinAddress);
  aes.setupDecryptResult(_encryptedBech32, _secret, _registeredBech32);
  aes.setupDecryptResult(
    _encryptedUsdtPolygonAddress,
    _secret,
    _usdtPolygonAddress,
  );
  aes.setupDecryptResult(
    _encryptedUsdcPolygonAddress,
    _secret,
    _usdcPolygonAddress,
  );
  aes.setupEncrypt(
    _bolt11Invoice,
    _bolt11Hash,
    _encryptedBolt11,
    deterministicNonce: true,
  );
  aes.setupDecryptResult(_encryptedBolt11, _bolt11Hash, _bolt11Invoice);
  aes.setupEncrypt(_bitcoinAddress, _secret, _encryptedBitcoinAddress);
  aes.setupEncrypt(
    _usdtPolygonAddress,
    _secret,
    _encryptedUsdtPolygonAddress,
  );
  aes.setupEncrypt(
    _usdcPolygonAddress,
    _secret,
    _encryptedUsdcPolygonAddress,
  );
  aes.setupDecryptResult(
    _encryptedUsdtEthereumAddress,
    _secret,
    _usdtEthereumAddress,
  );
  aes.setupDecryptResult(
    _encryptedUsdcEthereumAddress,
    _secret,
    _usdcEthereumAddress,
  );
  aes.setupDecryptResult(
    _encryptedUsdtBscAddress,
    _secret,
    _usdtBscAddress,
  );
  aes.setupDecryptResult(
    _encryptedUsdcBscAddress,
    _secret,
    _usdcBscAddress,
  );
  aes.setupDecryptResult(
    _encryptedUsdtTronAddress,
    _secret,
    _usdtTronAddress,
  );
  aes.setupDecryptResult(
    _encryptedUsdtTonAddress,
    _secret,
    _usdtTonAddress,
  );
  aes.setupDecryptResult(
    _encryptedUsdtSolanaAddress,
    _secret,
    _usdtSolanaAddress,
  );
  aes.setupDecryptResult(
    _encryptedUsdcSolanaAddress,
    _secret,
    _usdcSolanaAddress,
  );
  aes.setupEncrypt(_usdtTronAddress, _secret, _encryptedUsdtTronAddress);
  aes.setupEncrypt(_usdtEthereumAddress, _secret, _encryptedUsdtEthereumAddress);
  aes.setupEncrypt(_usdcEthereumAddress, _secret, _encryptedUsdcEthereumAddress);
  aes.setupEncrypt(_usdtBscAddress, _secret, _encryptedUsdtBscAddress);
  aes.setupEncrypt(_usdcBscAddress, _secret, _encryptedUsdcBscAddress);
  aes.setupEncrypt(_usdtTonAddress, _secret, _encryptedUsdtTonAddress);
  aes.setupEncrypt(_usdtSolanaAddress, _secret, _encryptedUsdtSolanaAddress);
  aes.setupEncrypt(_usdcSolanaAddress, _secret, _encryptedUsdcSolanaAddress);
  aes.setupEncrypt(
    _arkAddress,
    _arkHash,
    _encryptedArkAddress,
    deterministicNonce: true,
  );
  aes.setupDecryptResult(_encryptedArkAddress, _arkHash, _arkAddress);
}

void main() {
  group('AesGcmCipher', () {
    test('encrypt and decrypt round-trips', () async {
      const address = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
      const secret = 'test-secret';
      final encrypted = await AesGcmCipher.encrypt(address, secret);
      final decrypted = await AesGcmCipher.decrypt(encrypted, secret);
      expect(decrypted, equals(address));
    });

    test('deterministic nonce produces same ciphertext each time', () async {
      const value = 'lnbc100n1ptest';
      const secret = 'hash-key';
      final first = await AesGcmCipher.encrypt(
        value,
        secret,
        deterministicNonce: true,
      );
      final second = await AesGcmCipher.encrypt(
        value,
        secret,
        deterministicNonce: true,
      );
      expect(first, equals(second));
    });

    test('random nonce produces different ciphertext each time', () async {
      const value = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
      const secret = 'test-secret';
      final first = await AesGcmCipher.encrypt(value, secret);
      final second = await AesGcmCipher.encrypt(value, secret);
      expect(first, isNot(equals(second)));
    });
  });

  group('BrantaEnvironment', () {
    test('localhost returns correct URL', () {
      expect(BrantaEnvironment.localhost.url, equals('http://localhost:3000'));
    });

    test('production returns correct URL', () {
      expect(
        BrantaEnvironment.production.url,
        equals('https://guardrail.branta.pro'),
      );
    });

    test('staging returns correct URL', () {
      expect(
        BrantaEnvironment.staging.url,
        equals('https://staging.guardrail.branta.pro'),
      );
    });
  });

  group('BrantaExtensions', () {
    test('isBolt11 recognizes bolt11 prefixes', () {
      expect('lnbc100'.isBolt11(), isTrue);
      expect('lntb100'.isBolt11(), isTrue);
      expect('lnbcrt100'.isBolt11(), isTrue);
      expect('LNBC100'.isBolt11(), isTrue);
      expect('bc1q'.isBolt11(), isFalse);
    });

    test('isArk recognizes mainnet and signet', () {
      expect('ark1qq'.isArk(), isTrue);
      expect('ARK1qq'.isArk(), isTrue);
      expect('tark1qq'.isArk(), isTrue);
      expect('bc1q'.isArk(), isFalse);
    });

    test('isSilentPayment recognizes mainnet and testnet', () {
      expect('sp1qq'.isSilentPayment(), isTrue);
      expect('tsp1qq'.isSilentPayment(), isTrue);
      expect('SP1qq'.isSilentPayment(), isTrue);
      expect('bc1q'.isSilentPayment(), isFalse);
    });

    test('getDerivedKeyType maps encryptable values', () {
      expect(
        _bolt11Invoice.getDerivedKeyType(),
        equals(DestinationType.bolt11),
      );
      expect(
        _arkAddress.getDerivedKeyType(),
        equals(DestinationType.arkAddress),
      );
      expect(
        'tark1qqjqtest'.getDerivedKeyType(),
        equals(DestinationType.arkAddress),
      );
      expect(
        'sp1qqwl5p9jhz'.getDerivedKeyType(),
        equals(DestinationType.silentPayment),
      );
      expect(_bitcoinAddress.getDerivedKeyType(), isNull);
    });

    test('toNormalizedHash returns 64-char uppercase hex and ignores case', () {
      final hash = 'Hello'.toNormalizedHash();
      expect(hash, hasLength(64));
      expect(hash, equals(hash.toUpperCase()));
      expect('Hello'.toNormalizedHash(), equals('hello'.toNormalizedHash()));
    });

    test('toUrlFragment percent-encodes names and values', () {
      expect({'zkId1': 'secret1'}.toUrlFragment(), equals('#k-zkId1=secret1'));
      expect({'a': 'b', 'c': 'd'}.toUrlFragment(), equals('#k-a=b&k-c=d'));
      expect(
        {'a/b': 'c d', 'x': 'y+z'}.toUrlFragment(),
        equals('#k-a%2Fb=c%20d&k-x=y%2Bz'),
      );
      expect({'a!b': "c'(d)*"}.toUrlFragment(), equals("#k-a!b=c'(d)*"));
    });
  });

  group('QRParser', () {
    test('bitcoin URI sets bitcoinAddress type and branta params', () {
      final parser = QRParser(
        'bitcoin:$_bitcoinAddress?branta_id=ID1&branta_secret=SEC1',
      );
      expect(parser.destination, equals(_bitcoinAddress));
      expect(parser.destinationType, equals(DestinationType.bitcoinAddress));
      expect(parser.hasBrantaParams(), isTrue);
      expect(parser.onChainEncryptionText, equals('ID1'));
      expect(parser.onChainEncryptionSecret, equals('SEC1'));
    });

    test('pol URI is address-only and maps to the Polygon EVM family', () {
      final parser = QRParser(
        'pol:$_usdtPolygonAddress?value=50&user=send&currency=USD&branta_id=abc%2Bdef%3D&branta_secret=1234',
      );
      expect(parser.destination, equals(_usdtPolygonAddress));
      expect(parser.destinationType, isNull);
      expect(parser.destinations.single.secretKey, isTrue);
      expect(
        parser.expectedSecretKeyTypes,
        equals(polygonEvmDestinationTypes),
      );      expect(parser.destinations, hasLength(1));
      expect(parser.onChainEncryptionText, equals('abc+def='));
      expect(parser.onChainEncryptionSecret, equals('1234'));
    });

    test('chain URI schemes map to their destination family', () {
      expect(
        QRParser('eth:$_usdtEthereumAddress').expectedSecretKeyTypes,
        equals(ethereumEvmDestinationTypes),
      );
      expect(
        QRParser('bsc:$_usdtEthereumAddress').expectedSecretKeyTypes,
        equals(bscEvmDestinationTypes),
      );
      expect(
        QRParser('tron:$_usdtTronAddress').expectedSecretKeyTypes,
        equals(tronDestinationTypes),
      );
      final ton = QRParser('ton:$_usdtTonAddress');
      expect(ton.expectedSecretKeyTypes, equals(tonDestinationTypes));
      expect(ton.destination, equals(_usdtTonAddress));
      expect(ton.destinationType, isNull);
      expect(ton.destinations.single.secretKey, isTrue);
      final sol = QRParser('sol:$_usdcSolanaAddress?branta_id=a&branta_secret=b');
      expect(sol.expectedSecretKeyTypes, equals(solanaDestinationTypes));
      expect(sol.destination, equals(_usdcSolanaAddress));
      expect(sol.destinationType, isNull);
      expect(sol.destinations.single.secretKey, isTrue);
    });

    test('isSecretKeyAddressType covers bitcoin and every stable family member', () {
      expect(isSecretKeyAddressType(DestinationType.bitcoinAddress), isTrue);
      for (final family in secretKeyUriFamilies.values) {
        for (final type in family) {
          expect(
            isSecretKeyAddressType(type),
            isTrue,
            reason: type.jsonValue,
          );
        }
      }
      expect(isSecretKeyAddressType(DestinationType.bolt11), isFalse);
      expect(isSecretKeyAddressType(DestinationType.arkAddress), isFalse);
      expect(isSecretKeyAddressType(DestinationType.silentPayment), isFalse);
      expect(DestinationType.fromJson('usdt_tron'), DestinationType.usdtTron);
    });

    test('pol URI without query still maps to the Polygon EVM family', () {
      final parser = QRParser('pol:$_usdtPolygonAddress');
      expect(parser.destination, equals(_usdtPolygonAddress));
      expect(parser.destinationType, isNull);
      expect(
        parser.expectedSecretKeyTypes,
        equals(polygonEvmDestinationTypes),
      );      expect(parser.onChainEncryptionText, isNull);
      expect(parser.onChainEncryptionSecret, isNull);
    });

    test('bitcoin URI decodes a URI-encoded lightning param', () {
      final parser = QRParser(
        'bitcoin:$_bitcoinAddress?lightning=lnbc100%2Btest',
      );
      expect(parser.destinations[1].value, equals('lnbc100+test'));
      expect(parser.destinations[1].type, equals(DestinationType.bolt11));
    });

    test('skips malformed percent-encoded query params', () {
      final badSecret = QRParser(
        'bitcoin:$_bitcoinAddress?branta_id=ID1&branta_secret=%ZZ',
      );
      expect(badSecret.onChainEncryptionText, equals('ID1'));
      expect(badSecret.onChainEncryptionSecret, isNull);
      expect(badSecret.hasBrantaParams(), isFalse);

      // Truncated escape on an unrelated param must not drop branta_*.
      final truncatedAmount = QRParser(
        'bitcoin:$_bitcoinAddress?branta_id=ID1&branta_secret=SEC1&amount=1%',
      );
      expect(truncatedAmount.onChainEncryptionText, equals('ID1'));
      expect(truncatedAmount.onChainEncryptionSecret, equals('SEC1'));
      expect(truncatedAmount.hasBrantaParams(), isTrue);
    });

    test('plain bitcoin, bolt11, ark, and silent payment set their types', () {
      expect(
        QRParser(_bitcoinAddress).destinationType,
        equals(DestinationType.bitcoinAddress),
      );
      expect(
        QRParser('tb1qtest').destinationType,
        equals(DestinationType.bitcoinAddress),
      );
      expect(
        QRParser('bcrt1qtest').destinationType,
        equals(DestinationType.bitcoinAddress),
      );
      expect(
        QRParser(_bolt11Invoice).destinationType,
        equals(DestinationType.bolt11),
      );
      expect(
        QRParser('lightning:$_bolt11Invoice').destinationType,
        equals(DestinationType.bolt11),
      );
      expect(
        QRParser(_arkAddress).destinationType,
        equals(DestinationType.arkAddress),
      );
      expect(
        QRParser('tark1qqtest').destinationType,
        equals(DestinationType.arkAddress),
      );
      expect(
        QRParser('sp1qqtest').destinationType,
        equals(DestinationType.silentPayment),
      );
      expect(
        QRParser('tsp1qqtest').destinationType,
        equals(DestinationType.silentPayment),
      );
    });

    test('offers and LNURL are not destination types', () {
      expect(QRParser('lno1qqexample').destinationType, isNull);
      expect(QRParser('lnurl1example').destinationType, isNull);
      final offer = QRParser('lightning:lno1qqexample');
      expect(offer.hasUnverifiableInstruction, isTrue);
      expect(offer.destinationType, isNull);
    });

    test('whitespace is trimmed and unrecognized text has no type', () {
      expect(
        QRParser('  $_bitcoinAddress  ').destination,
        equals(_bitcoinAddress),
      );
      expect(QRParser('not-a-destination').destinationType, isNull);
    });

    test('combined QR parses bindable legs and drops unverifiable ones', () {
      final parser = QRParser(
        'bitcoin:$_bitcoinAddress?lightning=$_bolt11Invoice&ark=$_arkAddress&silent_payment=sp1qqtest&sp=tsp1qqtest',
      );
      expect(parser.destinations.map((d) => d.value), [
        _bitcoinAddress,
        _bolt11Invoice,
        _arkAddress,
        'sp1qqtest',
        'tsp1qqtest',
      ]);
      expect(parser.hasUnverifiableInstruction, isFalse);

      final unverifiable = QRParser(
        'bitcoin:$_bitcoinAddress?lno=lno1qq&pay=bitcoin:other&bolt12=lno1qq',
      );
      expect(unverifiable.destinations.map((d) => d.value), [_bitcoinAddress]);
      expect(unverifiable.hasUnverifiableInstruction, isTrue);
    });

    test('bip321 bc and tb are on-chain destinations', () {
      final parser = QRParser('bitcoin:?bc=bc1qmerchant&tb=tb1qtest');
      expect(parser.destinations.map((d) => d.value), [
        '',
        'bc1qmerchant',
        'tb1qtest',
      ]);
      expect(
        parser.destinations[1].type,
        equals(DestinationType.bitcoinAddress),
      );
      expect(
        parser.destinations[2].type,
        equals(DestinationType.bitcoinAddress),
      );
      expect(parser.hasUnverifiableInstruction, isFalse);
    });

    test(
      'control characters in the scheme still type the address a URL parser would pay',
      () {
        for (final prefix in [
          'bitcoi\tn:',
          'bitcoi\nn:',
          'bitcoi\rn:',
          '\x01bitcoin:',
        ]) {
          final parser = QRParser(
            '${prefix}1attackeraddr?branta_id=ID1&branta_secret=SEC1',
          );
          expect(parser.destination, equals('1attackeraddr'));
          expect(
            parser.destinationType,
            equals(DestinationType.bitcoinAddress),
          );
          expect(parser.hasBrantaParams(), isTrue);
        }

        final tabbed = QRParser(
          'bitcoin:1attac\tkeraddr?branta_id=ID1&branta_secret=SEC1',
        );
        expect(tabbed.destination, equals('1attackeraddr'));
        final lightning = QRParser('lightnin\tg:$_bolt11Invoice');
        expect(lightning.destination, equals(_bolt11Invoice));
        expect(lightning.destinationType, equals(DestinationType.bolt11));
      },
    );
  });

  group('PaymentBuilder', () {
    test('addDestination assigns an id and type', () {
      final payment = PaymentBuilder()
          .addDestination(_bitcoinAddress, type: DestinationType.bitcoinAddress)
          .build();
      expect(payment.destinations.single.value, equals(_bitcoinAddress));
      expect(
        payment.destinations.single.type,
        equals(DestinationType.bitcoinAddress),
      );
      expect(payment.destinations.single.id, isNotEmpty);
    });

    test(
      'setDescription writes metadata and toJson omits description and an unset ttl',
      () {
        final payment = PaymentBuilder()
            .setDescription('Invoice')
            .addDestination(_bitcoinAddress)
            .build();
        expect(payment.metadata, contains('Invoice'));
        expect(payment.description, isNull);
        final json = payment.toJson();
        expect(json.containsKey('description'), isFalse);
        expect(json.containsKey('ttl'), isFalse);
        expect((json['destinations'] as List).single['zk'], isTrue);
      },
    );

    test('setTtl stores zero so a posted 0 is not dropped', () {
      final payment = PaymentBuilder()
          .setTtl(0)
          .addDestination(_bitcoinAddress)
          .build();
      expect(payment.toJson()['ttl'], equals(0));
    });

    test('addMetadata and setChildPlatform serialize', () {
      final payment = PaymentBuilder()
          .addMetadata('order', '1234')
          .setChildPlatform('Child', logoUrl: 'https://example.com/logo.png')
          .addDestination(_bitcoinAddress)
          .build();
      expect(payment.metadata, contains('1234'));
      final json = payment.toJson();
      expect(json['child_platform'], {
        'name': 'Child',
        'logo_url': 'https://example.com/logo.png',
      });
    });

    test('fromJson ignores unknown destination types and unencrypted rows', () {
      final payment = Payment.fromJson({
        'description': 'ignored',
        'ttl': 30,
        'destinations': [
          {'value': 'bc1q', 'type': 'bolt12', 'zk': false, 'zk_id': 'id-1'},
        ],
      });
      expect(payment.description, isNull);
      expect(payment.ttl, equals(30));
      expect(payment.destinations.single.type, isNull);
      expect(payment.destinations.single.isEncrypted, isFalse);
      expect(payment.destinations.single.id, equals('id-1'));
    });
  });

  group('BrantaService.verify', () {
    late MockBrantaClient client;
    late MockAesEncryption aes;
    late BrantaService service;

    setUp(() {
      client = MockBrantaClient();
      aes = MockAesEncryption();
      _setupDefaultMocks(aes);
      service = _makeService(client, aes);
    });

    test('branta bitcoin URI looks up branta_id and decrypts', () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [
        _encryptedPayment(
          _encryptedBitcoinAddress,
          DestinationType.bitcoinAddress,
        ),
      ]);

      final result = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );

      expect(
        client.getPaymentsCalls.single.address,
        equals(_encryptedBitcoinAddress),
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.payments.single.destinations.single.value,
        equals(_bitcoinAddress),
      );
      expect(
        result.verifyUrl,
        equals(
          'http://localhost:3000/v2/verify/$_encryptedBitcoinAddress#k-dest-id=$_secret',
        ),
      );
    });

    test('pol URI looks up branta_id, ignores amount query, and decrypts', () async {
      client.setupGetPayments(_encryptedUsdtPolygonAddress, [
        _encryptedPayment(
          _encryptedUsdtPolygonAddress,
          DestinationType.usdtPolygon,
        ),
      ]);

      final result = await service.verify(_brantaUsdtPolygonLookup());

      expect(
        client.getPaymentsCalls.single.address,
        equals(_encryptedUsdtPolygonAddress),
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.payments.single.destinations.single.value,
        equals(_usdtPolygonAddress),
      );
      expect(
        result.payments.single.destinations.single.type,
        equals(DestinationType.usdtPolygon),
      );
      expect(result.matchedDestinations, hasLength(1));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtPolygon),
      );
      expect(
        result.matchedDestinations.single.value,
        equals(_usdtPolygonAddress),
      );
    });

    test('pol URI verifies usdc_polygon and returns matchedDestinations', () async {
      client.setupGetPayments(_encryptedUsdcPolygonAddress, [
        _encryptedPayment(
          _encryptedUsdcPolygonAddress,
          DestinationType.usdcPolygon,
        ),
      ]);

      final result = await service.verify(_brantaUsdcPolygonLookup());

      expect(
        client.getPaymentsCalls.single.address,
        equals(_encryptedUsdcPolygonAddress),
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdcPolygon),
      );
      expect(
        result.matchedDestinations.single.value,
        equals(_usdcPolygonAddress),
      );
    });

    test('pol URI with a swapped usdc address is tampered', () async {
      client.setupGetPayments(_encryptedUsdcPolygonAddress, [
        _encryptedPayment(
          _encryptedUsdcPolygonAddress,
          DestinationType.usdcPolygon,
        ),
      ]);

      final result = await service.verify(
        _brantaUsdcPolygonLookup(_swappedUsdtPolygonAddress),
      );
      expect(result.status, equals(VerifyStatus.tampered));
      expect(result.matchedDestinations, isEmpty);
    });

    test('pol verify binds only the matching rail when usdt and usdc differ', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedUsdtPolygonAddress,
            type: DestinationType.usdtPolygon,
          )
          .addDestination(
            _encryptedUsdcPolygonAddress,
            type: DestinationType.usdcPolygon,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtPolygonAddress, [payment]);

      final result = await service.verify(_brantaUsdtPolygonLookup());
      expect(result.status, equals(VerifyStatus.match));
      expect(result.matchedDestinations, hasLength(1));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtPolygon),
      );
      expect(result.payments.single.destinations[1].isEncrypted, isTrue);
    });

    test('pol URI address compare is case-insensitive', () async {
      client.setupGetPayments(_encryptedUsdtPolygonAddress, [
        _encryptedPayment(
          _encryptedUsdtPolygonAddress,
          DestinationType.usdtPolygon,
        ),
      ]);

      final result = await service.verify(
        _brantaUsdtPolygonLookup(_usdtPolygonAddressLower),
      );
      expect(result.status, equals(VerifyStatus.match));
    });

    test('pol URI 0x prefix compare is case-insensitive', () async {
      client.setupGetPayments(_encryptedUsdtPolygonAddress, [
        _encryptedPayment(
          _encryptedUsdtPolygonAddress,
          DestinationType.usdtPolygon,
        ),
      ]);

      final result = await service.verify(
        _brantaUsdtPolygonLookup('0X${_usdtPolygonAddress.substring(2)}'),
      );
      expect(result.status, equals(VerifyStatus.match));
    });

    test('pol URI with a swapped address is tampered', () async {
      client.setupGetPayments(_encryptedUsdtPolygonAddress, [
        _encryptedPayment(
          _encryptedUsdtPolygonAddress,
          DestinationType.usdtPolygon,
        ),
      ]);

      final result = await service.verify(
        _brantaUsdtPolygonLookup(_swappedUsdtPolygonAddress),
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('eth URI verifies usdt_ethereum and returns matchedDestinations', () async {
      client.setupGetPayments(_encryptedUsdtEthereumAddress, [
        _encryptedPayment(
          _encryptedUsdtEthereumAddress,
          DestinationType.usdtEthereum,
        ),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          _usdtEthereumAddress,
          _encryptedUsdtEthereumAddress,
        ),
      );

      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtEthereum),
      );
      expect(
        result.matchedDestinations.single.value,
        equals(_usdtEthereumAddress),
      );
    });

    test('eth URI with a swapped address is tampered', () async {
      client.setupGetPayments(_encryptedUsdtEthereumAddress, [
        _encryptedPayment(
          _encryptedUsdtEthereumAddress,
          DestinationType.usdtEthereum,
        ),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          _swappedEvmAddress,
          _encryptedUsdtEthereumAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.tampered));
      expect(result.matchedDestinations, isEmpty);
    });

    test('eth URI address compare is case-insensitive', () async {
      client.setupGetPayments(_encryptedUsdtEthereumAddress, [
        _encryptedPayment(
          _encryptedUsdtEthereumAddress,
          DestinationType.usdtEthereum,
        ),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          _usdtEthereumAddress.toLowerCase(),
          _encryptedUsdtEthereumAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.match));
    });

    test('eth URI 0x prefix compare is case-insensitive', () async {
      client.setupGetPayments(_encryptedUsdtEthereumAddress, [
        _encryptedPayment(
          _encryptedUsdtEthereumAddress,
          DestinationType.usdtEthereum,
        ),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          '0X${_usdtEthereumAddress.substring(2)}',
          _encryptedUsdtEthereumAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.match));
    });

    test('eth URI ignores a sibling bitcoin rail on the same payment', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedBitcoinAddress,
            type: DestinationType.bitcoinAddress,
          )
          .addDestination(
            _encryptedUsdtEthereumAddress,
            type: DestinationType.usdtEthereum,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtEthereumAddress, [payment]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          _usdtEthereumAddress,
          _encryptedUsdtEthereumAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.payments.single.destinations[0].value,
        equals(_encryptedBitcoinAddress),
      );
      expect(result.payments.single.destinations[0].isEncrypted, isTrue);
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtEthereum),
      );
    });

    test('eth URI swapped is still tampered when sibling bitcoin is present', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedBitcoinAddress,
            type: DestinationType.bitcoinAddress,
          )
          .addDestination(
            _encryptedUsdtEthereumAddress,
            type: DestinationType.usdtEthereum,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtEthereumAddress, [payment]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          _swappedEvmAddress,
          _encryptedUsdtEthereumAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('eth URI with a swapped usdc address is tampered', () async {
      client.setupGetPayments(_encryptedUsdcEthereumAddress, [
        _encryptedPayment(
          _encryptedUsdcEthereumAddress,
          DestinationType.usdcEthereum,
        ),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          _swappedEvmAddress,
          _encryptedUsdcEthereumAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('eth URI match-if-any binds usdt and leaves sibling usdc encrypted', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedUsdtEthereumAddress,
            type: DestinationType.usdtEthereum,
          )
          .addDestination(
            _encryptedUsdcEthereumAddress,
            type: DestinationType.usdcEthereum,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtEthereumAddress, [payment]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          _usdtEthereumAddress,
          _encryptedUsdtEthereumAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(result.matchedDestinations, hasLength(1));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtEthereum),
      );
      expect(result.payments.single.destinations[0].isEncrypted, isFalse);
      expect(result.payments.single.destinations[1].value,
          equals(_encryptedUsdcEthereumAddress));
      expect(result.payments.single.destinations[1].isEncrypted, isTrue);
    });

    test('eth URI swapped is tampered when no ethereum family rail matches', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedUsdtEthereumAddress,
            type: DestinationType.usdtEthereum,
          )
          .addDestination(
            _encryptedUsdcEthereumAddress,
            type: DestinationType.usdcEthereum,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtEthereumAddress, [payment]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          _swappedEvmAddress,
          _encryptedUsdtEthereumAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('eth URI with a polygon-only payment is unknown', () async {
      client.setupGetPayments(_encryptedUsdtEthereumAddress, [
        _encryptedPayment(
          _encryptedUsdtPolygonAddress,
          DestinationType.usdtPolygon,
        ),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'eth',
          _usdtEthereumAddress,
          _encryptedUsdtEthereumAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.unknown));
      expect(result.matchedDestinations, isEmpty);
    });

    test('bsc URI verifies usdt_bsc and returns matchedDestinations', () async {
      client.setupGetPayments(_encryptedUsdtBscAddress, [
        _encryptedPayment(_encryptedUsdtBscAddress, DestinationType.usdtBsc),
      ]);

      final result = await service.verify(
        _brantaChainLookup('bsc', _usdtBscAddress, _encryptedUsdtBscAddress),
      );

      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtBsc),
      );
      expect(result.matchedDestinations.single.value, equals(_usdtBscAddress));
    });

    test('bsc URI with a swapped address is tampered', () async {
      client.setupGetPayments(_encryptedUsdtBscAddress, [
        _encryptedPayment(_encryptedUsdtBscAddress, DestinationType.usdtBsc),
      ]);

      final result = await service.verify(
        _brantaChainLookup('bsc', _swappedEvmAddress, _encryptedUsdtBscAddress),
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('bsc URI match-if-any binds usdt and leaves sibling usdc encrypted', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedUsdtBscAddress,
            type: DestinationType.usdtBsc,
          )
          .addDestination(
            _encryptedUsdcBscAddress,
            type: DestinationType.usdcBsc,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtBscAddress, [payment]);

      final result = await service.verify(
        _brantaChainLookup('bsc', _usdtBscAddress, _encryptedUsdtBscAddress),
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtBsc),
      );
      expect(result.payments.single.destinations[0].isEncrypted, isFalse);
      expect(result.payments.single.destinations[1].isEncrypted, isTrue);
    });

    test('bsc URI ignores a sibling bitcoin rail on the same payment', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedBitcoinAddress,
            type: DestinationType.bitcoinAddress,
          )
          .addDestination(
            _encryptedUsdtBscAddress,
            type: DestinationType.usdtBsc,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtBscAddress, [payment]);

      final result = await service.verify(
        _brantaChainLookup('bsc', _usdtBscAddress, _encryptedUsdtBscAddress),
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(result.payments.single.destinations[0].isEncrypted, isTrue);
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtBsc),
      );
    });

    test('bsc URI swapped is still tampered when sibling bitcoin is present', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedBitcoinAddress,
            type: DestinationType.bitcoinAddress,
          )
          .addDestination(
            _encryptedUsdtBscAddress,
            type: DestinationType.usdtBsc,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtBscAddress, [payment]);

      final result = await service.verify(
        _brantaChainLookup('bsc', _swappedEvmAddress, _encryptedUsdtBscAddress),
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('tron URI verifies usdt_tron and returns matchedDestinations', () async {
      client.setupGetPayments(_encryptedUsdtTronAddress, [
        _encryptedPayment(_encryptedUsdtTronAddress, DestinationType.usdtTron),
      ]);

      final result = await service.verify(
        _brantaChainLookup('tron', _usdtTronAddress, _encryptedUsdtTronAddress),
      );

      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtTron),
      );
      expect(result.matchedDestinations.single.value, equals(_usdtTronAddress));
    });

    test('tron URI with a swapped address is tampered', () async {
      client.setupGetPayments(_encryptedUsdtTronAddress, [
        _encryptedPayment(_encryptedUsdtTronAddress, DestinationType.usdtTron),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'tron',
          _swappedTronAddress,
          _encryptedUsdtTronAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('ton URI verifies usdt_ton and returns matchedDestinations', () async {
      client.setupGetPayments(_encryptedUsdtTonAddress, [
        _encryptedPayment(_encryptedUsdtTonAddress, DestinationType.usdtTon),
      ]);

      final result = await service.verify(
        _brantaChainLookup('ton', _usdtTonAddress, _encryptedUsdtTonAddress),
      );

      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtTon),
      );
      expect(result.matchedDestinations.single.value, equals(_usdtTonAddress));
    });

    test('ton URI with a swapped address is tampered', () async {
      client.setupGetPayments(_encryptedUsdtTonAddress, [
        _encryptedPayment(_encryptedUsdtTonAddress, DestinationType.usdtTon),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'ton',
          _swappedTonAddress,
          _encryptedUsdtTonAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('sol URI verifies usdc_solana and returns matchedDestinations', () async {
      client.setupGetPayments(_encryptedUsdcSolanaAddress, [
        _encryptedPayment(
          _encryptedUsdcSolanaAddress,
          DestinationType.usdcSolana,
        ),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'sol',
          _usdcSolanaAddress,
          _encryptedUsdcSolanaAddress,
        ),
      );

      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdcSolana),
      );
      expect(
        result.matchedDestinations.single.value,
        equals(_usdcSolanaAddress),
      );
    });

    test('sol URI verifies usdt_solana and returns matchedDestinations', () async {
      client.setupGetPayments(_encryptedUsdtSolanaAddress, [
        _encryptedPayment(
          _encryptedUsdtSolanaAddress,
          DestinationType.usdtSolana,
        ),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'sol',
          _usdtSolanaAddress,
          _encryptedUsdtSolanaAddress,
        ),
      );

      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtSolana),
      );
      expect(
        result.matchedDestinations.single.value,
        equals(_usdtSolanaAddress),
      );
    });

    test('sol URI with a swapped address is tampered', () async {
      client.setupGetPayments(_encryptedUsdcSolanaAddress, [
        _encryptedPayment(
          _encryptedUsdcSolanaAddress,
          DestinationType.usdcSolana,
        ),
      ]);

      final result = await service.verify(
        _brantaChainLookup(
          'sol',
          _swappedSolanaAddress,
          _encryptedUsdcSolanaAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('sol URI match-if-any binds usdt and leaves sibling usdc encrypted', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedUsdtSolanaAddress,
            type: DestinationType.usdtSolana,
          )
          .addDestination(
            _encryptedUsdcSolanaAddress,
            type: DestinationType.usdcSolana,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtSolanaAddress, [payment]);

      final result = await service.verify(
        _brantaChainLookup(
          'sol',
          _usdtSolanaAddress,
          _encryptedUsdtSolanaAddress,
        ),
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtSolana),
      );
      expect(result.payments.single.destinations[0].isEncrypted, isFalse);
      expect(result.payments.single.destinations[1].isEncrypted, isTrue);
    });

    test('bare chain addresses and URIs without branta params are unknown', () async {
      expect(
        (await service.verify(_usdtPolygonAddress)).status,
        equals(VerifyStatus.unknown),
      );
      expect(
        (await service.verify(_usdtEthereumAddress)).status,
        equals(VerifyStatus.unknown),
      );
      expect(
        (await service.verify(_usdtTronAddress)).status,
        equals(VerifyStatus.unknown),
      );
      expect(
        (await service.verify(_usdtTonAddress)).status,
        equals(VerifyStatus.unknown),
      );
      expect(
        (await service.verify(_usdcSolanaAddress)).status,
        equals(VerifyStatus.unknown),
      );
      expect(
        (await service.verify(
          'pol:$_usdtPolygonAddress?value=50&currency=USD',
        )).status,
        equals(VerifyStatus.unknown),
      );
      expect(
        (await service.verify('eth:$_usdtEthereumAddress?value=50')).status,
        equals(VerifyStatus.unknown),
      );
      expect(
        (await service.verify('tron:$_usdtTronAddress')).status,
        equals(VerifyStatus.unknown),
      );
      expect(client.getPaymentsCalls, isEmpty);
    });

    test('pol verify ignores a sibling bitcoin rail on the same payment', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedBitcoinAddress,
            type: DestinationType.bitcoinAddress,
          )
          .addDestination(
            _encryptedUsdtPolygonAddress,
            type: DestinationType.usdtPolygon,
          )
          .build();
      client.setupGetPayments(_encryptedUsdtPolygonAddress, [payment]);

      final result = await service.verify(_brantaUsdtPolygonLookup());
      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.payments.single.destinations[0].value,
        equals(_encryptedBitcoinAddress),
      );
      expect(result.payments.single.destinations[0].isEncrypted, isTrue);
      expect(
        result.payments.single.destinations[1].value,
        equals(_usdtPolygonAddress),
      );
      expect(result.payments.single.destinations[1].isEncrypted, isFalse);
      expect(result.matchedDestinations, hasLength(1));
      expect(
        result.matchedDestinations.single.type,
        equals(DestinationType.usdtPolygon),
      );
    });

    test('bitcoin verify ignores a sibling usdt_polygon rail on the same payment', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedBitcoinAddress,
            type: DestinationType.bitcoinAddress,
          )
          .addDestination(
            _encryptedUsdtPolygonAddress,
            type: DestinationType.usdtPolygon,
          )
          .build();
      client.setupGetPayments(_encryptedBitcoinAddress, [payment]);

      final result = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.payments.single.destinations[0].value,
        equals(_bitcoinAddress),
      );
      expect(
        result.payments.single.destinations[1].value,
        equals(_encryptedUsdtPolygonAddress),
      );
      expect(result.payments.single.destinations[1].isEncrypted, isTrue);
    });

    test('bare bitcoin URI is unknown and does not call the client', () async {
      final result = await service.verify('bitcoin:$_bitcoinAddress');
      expect(result.status, equals(VerifyStatus.unknown));
      expect(result.payments, isEmpty);
      expect(
        result.verifyUrl,
        equals('http://localhost:3000/v2/verify/$_bitcoinAddress'),
      );
      expect(client.getPaymentsCalls, isEmpty);
    });

    test('pasted bitcoin address and unrecognized text are unknown', () async {
      expect(
        (await service.verify(_bitcoinAddress)).status,
        equals(VerifyStatus.unknown),
      );
      expect(
        (await service.verify('not-a-destination')).status,
        equals(VerifyStatus.unknown),
      );
      expect(client.getPaymentsCalls, isEmpty);
    });

    test('bolt11 URI looks up the encrypted invoice', () async {
      client.setupGetPayments(_encryptedBolt11, [
        _encryptedPayment(_encryptedBolt11, DestinationType.bolt11),
      ]);

      final result = await service.verify('lightning:$_bolt11Invoice');
      expect(client.getPaymentsCalls.single.address, equals(_encryptedBolt11));
      expect(result.status, equals(VerifyStatus.match));
      expect(
        result.payments.single.destinations.single.value,
        equals(_bolt11Invoice),
      );
    });

    test('uppercase bolt11 uses the same encrypted lookup', () async {
      client.setupGetPayments(_encryptedBolt11, [
        _encryptedPayment(_encryptedBolt11, DestinationType.bolt11),
      ]);
      await service.verify('lightning:${_bolt11Invoice.toUpperCase()}');
      expect(client.getPaymentsCalls.single.address, equals(_encryptedBolt11));
    });

    test(
      'bolt11 lookup leaves an unrelated bitcoin destination encrypted',
      () async {
        final payment = PaymentBuilder()
            .addDestination(_encryptedBolt11, type: DestinationType.bolt11)
            .addDestination(
              _encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress,
            )
            .build();
        client.setupGetPayments(_encryptedBolt11, [payment]);

        final result = await service.verify('lightning:$_bolt11Invoice');
        expect(result.status, equals(VerifyStatus.match));
        expect(
          result.payments.single.destinations[0].value,
          equals(_bolt11Invoice),
        );
        expect(result.payments.single.destinations[0].isEncrypted, isFalse);
        expect(
          result.payments.single.destinations[1].value,
          equals(_encryptedBitcoinAddress),
        );
        expect(result.payments.single.destinations[1].isEncrypted, isTrue);
      },
    );

    test('bolt11 decrypting to a different invoice is tampered', () async {
      aes.setupDecryptResult(
        'encrypted-attacker-invoice',
        _bolt11Hash,
        'lnbc1attacker',
      );
      client.setupGetPayments(_encryptedBolt11, [
        Payment(
          destinations: [
            Destination(
              value: 'copied-lookup',
              type: DestinationType.bitcoinAddress,
              id: 'btc',
            ),
            Destination(
              value: 'encrypted-attacker-invoice',
              type: DestinationType.bolt11,
              id: 'bolt',
            ),
          ],
        ),
      ]);

      final result = await service.verify('lightning:$_bolt11Invoice');
      expect(result.status, equals(VerifyStatus.tampered));
      expect(result.payments, isEmpty);
      expect(
        result.verifyUrl,
        equals('http://localhost:3000/v2/verify/$_bolt11Invoice'),
      );
      expect(result.verifyUrl.contains('#'), isFalse);
    });

    test('combined branta QR decrypts address, bolt11, and ark', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedBitcoinAddress,
            type: DestinationType.bitcoinAddress,
          )
          .addDestination(_encryptedBolt11, type: DestinationType.bolt11)
          .addDestination(
            _encryptedArkAddress,
            type: DestinationType.arkAddress,
          )
          .build();
      client.setupGetPayments(_encryptedBitcoinAddress, [payment]);

      final result = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret&lightning=$_bolt11Invoice&ark=$_arkAddress',
      );
      final ids = payment.destinations.map((d) => d.id).toList();
      expect(result.status, equals(VerifyStatus.match));
      expect(result.payments.single.destinations.map((d) => d.value), [
        _bitcoinAddress,
        _bolt11Invoice,
        _arkAddress,
      ]);
      expect(
        result.verifyUrl,
        equals(
          'http://localhost:3000/v2/verify/$_encryptedBitcoinAddress#k-${ids[0]}=$_secret&k-${ids[1]}=$_bolt11Hash&k-${ids[2]}=$_arkHash',
        ),
      );
    });

    test('empty lookup is unknown and a failed lookup is incomplete', () async {
      client.setupGetPayments(_encryptedBolt11, []);
      final missing = await service.verify('lightning:$_bolt11Invoice');
      expect(missing.status, equals(VerifyStatus.unknown));
      expect(missing.verifyUrl, contains('/v2/verify/$_encryptedBolt11'));

      client.getError = const IncompleteError('TooManyRequests');
      final incomplete = await service.verify('lightning:$_bolt11Invoice');
      expect(incomplete.status, equals(VerifyStatus.incomplete));
      expect(incomplete.payments, isEmpty);
      expect(
        incomplete.verifyUrl,
        equals('http://localhost:3000/v2/verify/$_bolt11Invoice'),
      );
    });

    test('forwards per-call options', () async {
      const override = BrantaApiOptions(apiKey: 'child-key');
      client.setupGetPayments(_encryptedBitcoinAddress, [
        _encryptedPayment(
          _encryptedBitcoinAddress,
          DestinationType.bitcoinAddress,
        ),
      ]);
      await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
        options: override,
      );
      expect(client.getPaymentsCalls.single.options, same(override));
    });

    test('wrong secret and an unencrypted row are unknown', () async {
      aes.setupDecryptThrows(
        _encryptedBitcoinAddress,
        'wrong',
        Exception('auth tag mismatch'),
      );
      client.setupGetPayments(_encryptedBitcoinAddress, [
        _encryptedPayment(
          _encryptedBitcoinAddress,
          DestinationType.bitcoinAddress,
        ),
      ]);
      final wrong = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=wrong',
      );
      expect(wrong.status, equals(VerifyStatus.unknown));

      client.setupGetPayments(_encryptedBolt11, [
        Payment(
          destinations: [
            Destination(
              value: _bolt11Invoice,
              type: DestinationType.bolt11,
              isEncrypted: false,
              id: 'plain',
            ),
          ],
        ),
      ]);
      final plain = await service.verify('lightning:$_bolt11Invoice');
      expect(plain.status, equals(VerifyStatus.unknown));
    });

    test('fragment encodes reserved characters', () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [
        _encryptedPayment(
          _encryptedBitcoinAddress,
          DestinationType.bitcoinAddress,
          id: 'a/b',
        ),
      ]);
      aes.setupDecryptResult(_encryptedBitcoinAddress, 'c d', _bitcoinAddress);
      final result = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=${Uri.encodeComponent('c d')}',
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(result.verifyUrl, endsWith('#k-a%2Fb=c%20d'));
    });
  });

  group('BrantaService.verify address binding', () {
    late MockBrantaClient client;
    late MockAesEncryption aes;
    late BrantaService service;

    setUp(() {
      client = MockBrantaClient();
      aes = MockAesEncryption();
      _setupDefaultMocks(aes);
      service = _makeService(client, aes);
      client.setupGetPayments(_encryptedBitcoinAddress, [
        _encryptedPayment(
          _encryptedBitcoinAddress,
          DestinationType.bitcoinAddress,
        ),
      ]);
    });

    test('swapped address is tampered', () async {
      final result = await service.verify(
        'bitcoin:$_swappedAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(result.status, equals(VerifyStatus.tampered));
      expect(result.payments, isEmpty);
    });

    test('control characters in the scheme still reject a swap', () async {
      final result = await service.verify(
        'bitcoi\tn:$_swappedAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('matching address is a match', () async {
      final result = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(result.status, equals(VerifyStatus.match));
    });

    test('uppercase bech32 matches and base58 case does not', () async {
      client.setupGetPayments(_encryptedBech32, [
        _encryptedPayment(_encryptedBech32, DestinationType.bitcoinAddress),
      ]);
      final bech32 = await service.verify(
        'bitcoin:${_registeredBech32.toUpperCase()}?branta_id=$_encryptedBech32&branta_secret=$_secret',
      );
      expect(bech32.status, equals(VerifyStatus.match));
      expect(
        bech32.payments.single.destinations.single.value,
        equals(_registeredBech32),
      );

      final base58 = await service.verify(
        'bitcoin:${_bitcoinAddress.toLowerCase()}?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(base58.status, equals(VerifyStatus.tampered));
    });

    test(
      'lightning QR with branta params and no on-chain address decrypts without comparison',
      () async {
        final payment = PaymentBuilder()
            .addDestination(_encryptedBolt11, type: DestinationType.bolt11)
            .addDestination(
              _encryptedBitcoinAddress,
              type: DestinationType.bitcoinAddress,
            )
            .build();
        client.setupGetPayments(_encryptedBolt11, [payment]);

        final result = await service.verify(
          'lightning:$_bolt11Invoice?branta_id=$_encryptedBolt11&branta_secret=$_secret',
        );
        expect(result.status, equals(VerifyStatus.match));
        expect(
          result.payments.single.destinations[0].value,
          equals(_bolt11Invoice),
        );
        expect(
          result.payments.single.destinations[1].value,
          equals(_bitcoinAddress),
        );
        expect(result.payments.single.destinations[1].isEncrypted, isFalse);
      },
    );

    test('combined QR with a swapped address is tampered', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _encryptedBitcoinAddress,
            type: DestinationType.bitcoinAddress,
          )
          .addDestination(_encryptedBolt11, type: DestinationType.bolt11)
          .addDestination(
            _encryptedArkAddress,
            type: DestinationType.arkAddress,
          )
          .build();
      client.setupGetPayments(_encryptedBitcoinAddress, [payment]);
      final result = await service.verify(
        'bitcoin:$_swappedAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret&lightning=$_bolt11Invoice&ark=$_arkAddress',
      );
      expect(result.status, equals(VerifyStatus.tampered));
    });

    test('swapped address with the wrong secret is unknown', () async {
      aes.setupDecryptThrows(
        _encryptedBitcoinAddress,
        'wrong-secret',
        Exception('auth tag mismatch'),
      );
      final result = await service.verify(
        'bitcoin:$_swappedAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=wrong-secret',
      );
      expect(result.status, equals(VerifyStatus.unknown));
    });

    test('attacker lightning or ark leg is unknown', () async {
      final lightning = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret&lightning=lnbc1attacker',
      );
      expect(lightning.status, equals(VerifyStatus.unknown));

      final ark = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret&ark=ark1attacker',
      );
      expect(ark.status, equals(VerifyStatus.unknown));
    });

    test('bip321 bc swap is tampered and a matching bc is a match', () async {
      final swapped = await service.verify(
        'bitcoin:?bc=$_swappedAddress&branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(swapped.status, equals(VerifyStatus.tampered));

      final matched = await service.verify(
        'bitcoin:?bc=$_bitcoinAddress&branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(matched.status, equals(VerifyStatus.match));
    });

    test('path and bc that disagree are tampered before lookup', () async {
      final result = await service.verify(
        'bitcoin:$_bitcoinAddress?bc=$_swappedAddress&branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(result.status, equals(VerifyStatus.tampered));
      expect(client.getPaymentsCalls, isEmpty);
    });

    test(
      'pay, lno, and an id with no payable destination are unknown without a lookup',
      () async {
        for (final qr in [
          'bitcoin:$_bitcoinAddress?pay=bitcoin:$_swappedAddress&branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
          'bitcoin:$_bitcoinAddress?lno=lno1qqattacker&branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
          'bitcoin:?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
          'bitcoin:?branta_id=$_encryptedBitcoinAddress&branta_secret=wrong-secret',
        ]) {
          final result = await service.verify(qr);
          expect(result.status, equals(VerifyStatus.unknown), reason: qr);
        }
        expect(client.getPaymentsCalls, isEmpty);
      },
    );
  });

  group('BrantaService.addPayment', () {
    late MockBrantaClient client;
    late MockAesEncryption aes;
    late MockSecretGenerator secrets;
    late BrantaService service;

    setUp(() {
      client = MockBrantaClient();
      aes = MockAesEncryption();
      secrets = MockSecretGenerator(_secret);
      _setupDefaultMocks(aes);
      service = _makeService(client, aes, secretGenerator: secrets);
    });

    test(
      'bitcoin address encrypts with the generated secret and leaves the caller unchanged',
      () async {
        final payment = PaymentBuilder()
            .addDestination(_bitcoinAddress)
            .build();
        final id = payment.destinations.single.id!;
        client.setupPostPayment(
          Payment(
            destinations: [
              Destination(
                value: _encryptedBitcoinAddress,
                type: DestinationType.bitcoinAddress,
                id: id,
              ),
            ],
          ),
        );

        final result = await service.addPayment(payment);

        expect(payment.destinations.single.value, equals(_bitcoinAddress));
        expect(
          client.lastPosted!.destinations.single.value,
          equals(_encryptedBitcoinAddress),
        );
        expect(
          client.lastPosted!.destinations.single.type,
          equals(DestinationType.bitcoinAddress),
        );
        expect(client.lastPosted!.toJson()['destinations'][0]['zk'], isTrue);
        expect(result.secret, equals(_secret));
        expect(
          result.verifyUrl,
          equals(
            'http://localhost:3000/v2/verify/$_encryptedBitcoinAddress#k-$id=$_secret',
          ),
        );
      },
    );

    test('usdt_polygon encrypts with the generated secret', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _usdtPolygonAddress,
            type: DestinationType.usdtPolygon,
          )
          .build();
      final id = payment.destinations.single.id!;
      client.setupPostPayment(
        Payment(
          destinations: [
            Destination(
              value: _encryptedUsdtPolygonAddress,
              type: DestinationType.usdtPolygon,
              id: id,
            ),
          ],
        ),
      );

      await service.addPayment(payment);

      expect(payment.destinations.single.value, equals(_usdtPolygonAddress));
      expect(
        client.lastPosted!.destinations.single.value,
        equals(_encryptedUsdtPolygonAddress),
      );
      expect(
        client.lastPosted!.destinations.single.type,
        equals(DestinationType.usdtPolygon),
      );
    });

    for (final rail in <(String, DestinationType, String)>[
      (
        _usdtEthereumAddress,
        DestinationType.usdtEthereum,
        _encryptedUsdtEthereumAddress,
      ),
      (_usdtBscAddress, DestinationType.usdtBsc, _encryptedUsdtBscAddress),
      (_usdtTronAddress, DestinationType.usdtTron, _encryptedUsdtTronAddress),
      (_usdtTonAddress, DestinationType.usdtTon, _encryptedUsdtTonAddress),
      (
        _usdtSolanaAddress,
        DestinationType.usdtSolana,
        _encryptedUsdtSolanaAddress,
      ),
      (
        _usdcSolanaAddress,
        DestinationType.usdcSolana,
        _encryptedUsdcSolanaAddress,
      ),
    ]) {
      final address = rail.$1;
      final type = rail.$2;
      final encrypted = rail.$3;
      test('${type.jsonValue} encrypts with the generated secret', () async {
        final payment = PaymentBuilder()
            .addDestination(address, type: type)
            .build();
        final id = payment.destinations.single.id!;
        client.setupPostPayment(
          Payment(
            destinations: [
              Destination(value: encrypted, type: type, id: id),
            ],
          ),
        );

        await service.addPayment(payment);

        expect(payment.destinations.single.value, equals(address));
        expect(
          client.lastPosted!.destinations.single.value,
          equals(encrypted),
        );
        expect(client.lastPosted!.destinations.single.type, equals(type));
      });
    }

    test('usdt_polygon without an explicit type cannot be encrypted', () async {
      final payment = PaymentBuilder()
          .addDestination(_usdtPolygonAddress)
          .build();

      expect(
        () => service.addPayment(payment),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            contains('cannot be encrypted'),
          ),
        ),
      );
      expect(client.postPaymentCallCount, equals(0));
    });

    test('usdc_polygon encrypts with the generated secret', () async {
      final payment = PaymentBuilder()
          .addDestination(
            _usdcPolygonAddress,
            type: DestinationType.usdcPolygon,
          )
          .build();
      final id = payment.destinations.single.id!;
      client.setupPostPayment(
        Payment(
          destinations: [
            Destination(
              value: _encryptedUsdcPolygonAddress,
              type: DestinationType.usdcPolygon,
              id: id,
            ),
          ],
        ),
      );

      await service.addPayment(payment);

      expect(payment.destinations.single.value, equals(_usdcPolygonAddress));
      expect(
        client.lastPosted!.destinations.single.value,
        equals(_encryptedUsdcPolygonAddress),
      );
      expect(
        client.lastPosted!.destinations.single.type,
        equals(DestinationType.usdcPolygon),
      );
    });

    test('usdc_polygon without an explicit type cannot be encrypted', () async {
      final payment = PaymentBuilder()
          .addDestination(_usdcPolygonAddress)
          .build();

      expect(
        () => service.addPayment(payment),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            contains('cannot be encrypted'),
          ),
        ),
      );
      expect(client.postPaymentCallCount, equals(0));
    });

    test('bolt11 and ark encrypt with the derived hash', () async {
      final bolt11 = PaymentBuilder()
          .addDestination(_bolt11Invoice, type: DestinationType.bolt11)
          .build();
      client.setupPostPayment(
        Payment(
          destinations: [
            Destination(
              value: _encryptedBolt11,
              type: DestinationType.bolt11,
              id: bolt11.destinations.single.id,
            ),
          ],
        ),
      );
      await service.addPayment(bolt11);
      expect(
        client.lastPosted!.destinations.single.value,
        equals(_encryptedBolt11),
      );

      final ark = PaymentBuilder()
          .addDestination(_arkAddress, type: DestinationType.arkAddress)
          .build();
      client.setupPostPayment(
        Payment(
          destinations: [
            Destination(
              value: _encryptedArkAddress,
              type: DestinationType.arkAddress,
              id: ark.destinations.single.id,
            ),
          ],
        ),
      );
      await service.addPayment(ark);
      expect(
        client.lastPosted!.destinations.single.value,
        equals(_encryptedArkAddress),
      );
    });

    test(
      'a value that cannot be encrypted throws before the client is called',
      () async {
        final payment = Payment(
          destinations: [
            Destination(
              value: 'not-an-invoice',
              type: DestinationType.bolt11,
              id: 'x',
            ),
          ],
        );
        expect(
          () => service.addPayment(payment),
          throwsA(
            isA<BrantaPaymentException>().having(
              (e) => e.message,
              'message',
              contains('cannot be encrypted'),
            ),
          ),
        );
        expect(client.postPaymentCallCount, equals(0));
      },
    );

    test(
      'a failed post leaves the original address so the same payment can be retried',
      () async {
        final payment = PaymentBuilder()
            .addDestination(
              _bitcoinAddress,
              type: DestinationType.bitcoinAddress,
            )
            .build();
        client.postError = const BrantaPaymentException('InternalServerError');
        await expectLater(
          service.addPayment(payment),
          throwsA(isA<BrantaPaymentException>()),
        );
        expect(payment.destinations.single.value, equals(_bitcoinAddress));

        client.postError = null;
        client.setupPostPayment(
          Payment(
            destinations: [
              Destination(
                value: _encryptedBitcoinAddress,
                type: DestinationType.bitcoinAddress,
                id: payment.destinations.single.id,
              ),
            ],
          ),
        );
        await service.addPayment(payment);
        expect(
          aes.encryptCalls.where((c) => c.value == _bitcoinAddress).length,
          equals(2),
        );
        expect(payment.destinations.single.value, equals(_bitcoinAddress));
      },
    );

    test(
      'description is encrypted in metadata and an unset payment does not mint a DEK',
      () async {
        final described = PaymentBuilder()
            .setDescription('Invoice')
            .addDestination(_bitcoinAddress)
            .build();
        final plainMetadata = described.metadata!;
        final sequential = MockSequentialSecretGenerator([
          'dek-value',
          _secret,
        ]);
        service = _makeService(client, aes, secretGenerator: sequential);
        aes.setupEncrypt(plainMetadata, 'dek-value', 'encrypted-metadata');
        aes.setupEncrypt('dek-value', _secret, 'encrypted-dek');
        final id = described.destinations.single.id!;
        client.setupPostPayment(
          Payment(
            destinations: [
              Destination(value: _encryptedBitcoinAddress, id: id),
            ],
          ),
        );

        await service.addPayment(described);

        expect(described.metadata, equals(plainMetadata));
        expect(client.lastPosted!.metadata, equals('encrypted-metadata'));
        expect(
          client.lastPosted!.destinations.single.encryptedDek,
          equals('encrypted-dek'),
        );
        expect(client.lastPosted!.toJson().containsKey('description'), isFalse);

        final plain = PaymentBuilder().addDestination(_bitcoinAddress).build();
        client.setupPostPayment(
          Payment(
            destinations: [
              Destination(
                value: _encryptedBitcoinAddress,
                id: plain.destinations.single.id,
              ),
            ],
          ),
        );
        final counted = MockSecretGenerator(_secret);
        service = _makeService(client, aes, secretGenerator: counted);
        await service.addPayment(plain);
        expect(counted.generateCount, equals(1));
        expect(client.lastPosted!.destinations.single.encryptedDek, isNull);
      },
    );
  });

  group('BrantaService metadata', () {
    late MockBrantaClient client;
    late MockAesEncryption aes;
    late BrantaService service;

    setUp(() {
      client = MockBrantaClient();
      aes = MockAesEncryption();
      _setupDefaultMocks(aes);
      service = _makeService(client, aes);
    });

    test('a decrypted DEK lifts description', () async {
      aes.setupDecryptResult('encrypted-dek', _secret, 'dek-value');
      aes.setupDecryptResult(
        'encrypted-metadata',
        'dek-value',
        '{"description":"Invoice"}',
      );
      client.setupGetPayments(_encryptedBitcoinAddress, [
        _encryptedPayment(
          _encryptedBitcoinAddress,
          DestinationType.bitcoinAddress,
          encryptedDek: 'encrypted-dek',
          metadata: 'encrypted-metadata',
        ),
      ]);

      final result = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(result.status, equals(VerifyStatus.match));
      expect(result.payments.single.description, equals('Invoice'));
      expect(
        result.payments.single.metadata,
        equals('{"description":"Invoice"}'),
      );
      expect(result.payments.single.isMetadataDecrypted, isTrue);
    });

    test('a wrong key leaves metadata encrypted', () async {
      aes.setupDecryptThrows(
        _encryptedBitcoinAddress,
        'wrong',
        Exception('auth tag mismatch'),
      );
      client.setupGetPayments(_encryptedBitcoinAddress, [
        _encryptedPayment(
          _encryptedBitcoinAddress,
          DestinationType.bitcoinAddress,
          encryptedDek: 'encrypted-dek',
          metadata: 'encrypted-metadata',
        ),
      ]);
      final result = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=wrong',
      );
      expect(result.status, equals(VerifyStatus.unknown));
    });

    test('metadata without a DEK is left alone', () async {
      client.setupGetPayments(_encryptedBitcoinAddress, [
        _encryptedPayment(
          _encryptedBitcoinAddress,
          DestinationType.bitcoinAddress,
          metadata: '{"description":"Invoice"}',
        ),
      ]);
      final result = await service.verify(
        'bitcoin:$_bitcoinAddress?branta_id=$_encryptedBitcoinAddress&branta_secret=$_secret',
      );
      expect(result.payments.single.description, isNull);
      expect(
        result.payments.single.metadata,
        equals('{"description":"Invoice"}'),
      );
    });

    test('two destinations decrypt metadata once', () async {
      aes.setupDecryptResult('encrypted-dek', _bolt11Hash, 'dek-value');
      aes.setupDecryptResult(
        'encrypted-metadata',
        'dek-value',
        '{"description":"Invoice"}',
      );
      final payment = Payment(
        metadata: 'encrypted-metadata',
        destinations: [
          Destination(
            value: _encryptedBolt11,
            type: DestinationType.bolt11,
            id: 'a',
            encryptedDek: 'encrypted-dek',
          ),
          Destination(
            value: _encryptedBolt11,
            type: DestinationType.bolt11,
            id: 'b',
            encryptedDek: 'encrypted-dek',
          ),
        ],
      );
      client.setupGetPayments(_encryptedBolt11, [payment]);
      final result = await service.verify('lightning:$_bolt11Invoice');
      expect(result.payments.single.description, equals('Invoice'));
      expect(
        aes.decryptCalls
            .where((c) => c.encrypted == 'encrypted-metadata')
            .length,
        equals(1),
      );
    });
  });

  group('BrantaService.isApiKeyValid', () {
    test('returns the client result and forwards options', () async {
      final client = MockBrantaClient();
      final service = _makeService(client, MockAesEncryption());
      client.setIsApiKeyValid(true);
      expect(await service.isApiKeyValid(), isTrue);
      client.setIsApiKeyValid(false);
      expect(await service.isApiKeyValid(), isFalse);
      const override = BrantaApiOptions(apiKey: 'child');
      await service.isApiKeyValid(options: override);
      expect(client.lastIsApiKeyValidOptions, same(override));
    });
  });
}
