import 'package:branta/branta.dart';
import 'package:branta/src/exceptions/incomplete_error.dart';
import 'package:branta/src/helpers/aes_encryption.dart';
import 'package:branta/src/helpers/branta_extensions.dart';
import 'package:branta/src/v2/classes/qr_parser.dart';
import 'package:branta/src/v2/interfaces/i_aes_encryption.dart';
import 'package:branta/src/v2/interfaces/i_branta_client.dart';
import 'package:branta/src/v2/interfaces/i_secret_generator.dart';
import 'package:test/test.dart';

class ClientCall {
  final String address;
  final BrantaApiOptions? options;
  ClientCall(this.address, this.options);
}

class MockBrantaClient implements IBrantaClient {
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

class MockAesEncryption implements IAesEncryption {
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

class MockSecretGenerator implements ISecretGenerator {
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

class MockSequentialSecretGenerator implements ISecretGenerator {
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
const String _bolt11Invoice = 'lnbc100n1ptest';
const String _encryptedBolt11 = 'encrypted-bolt11-value';
const String _arkAddress = 'ark100testaddress';
const String _encryptedArkAddress = 'encrypted-ark-address';
const String _registeredBech32 = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
const String _encryptedBech32 = 'encrypted-bech32-address';

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
  ISecretGenerator? secretGenerator,
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
  aes.setupEncrypt(
    _bolt11Invoice,
    _bolt11Hash,
    _encryptedBolt11,
    deterministicNonce: true,
  );
  aes.setupDecryptResult(_encryptedBolt11, _bolt11Hash, _bolt11Invoice);
  aes.setupEncrypt(_bitcoinAddress, _secret, _encryptedBitcoinAddress);
  aes.setupEncrypt(
    _arkAddress,
    _arkHash,
    _encryptedArkAddress,
    deterministicNonce: true,
  );
  aes.setupDecryptResult(_encryptedArkAddress, _arkHash, _arkAddress);
}

void main() {
  group('AesEncryption', () {
    test('encrypt and decrypt round-trips', () async {
      const address = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
      const secret = 'test-secret';
      final encrypted = await AesEncryption.encrypt(address, secret);
      final decrypted = await AesEncryption.decrypt(encrypted, secret);
      expect(decrypted, equals(address));
    });

    test('deterministic nonce produces same ciphertext each time', () async {
      const value = 'lnbc100n1ptest';
      const secret = 'hash-key';
      final first = await AesEncryption.encrypt(
        value,
        secret,
        deterministicNonce: true,
      );
      final second = await AesEncryption.encrypt(
        value,
        secret,
        deterministicNonce: true,
      );
      expect(first, equals(second));
    });

    test('random nonce produces different ciphertext each time', () async {
      const value = '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa';
      const secret = 'test-secret';
      final first = await AesEncryption.encrypt(value, secret);
      final second = await AesEncryption.encrypt(value, secret);
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

    test('bitcoin URI decodes a URI-encoded lightning param', () {
      final parser = QRParser(
        'bitcoin:$_bitcoinAddress?lightning=lnbc100%2Btest',
      );
      expect(parser.destinations[1].value, equals('lnbc100+test'));
      expect(parser.destinations[1].type, equals(DestinationType.bolt11));
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
