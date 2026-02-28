// Run `make build` before running tests to generate *.g.dart files.
import 'dart:convert';
import 'package:branta/src/helpers/aes_encryption.dart';
import 'package:branta/src/v2/classes/payment_builder.dart';
import 'package:branta/src/v2/clients/branta_client.dart';
import 'package:branta/src/v2/config/branta_config.dart';
import 'package:branta/src/v2/models/destination.dart';
import 'package:branta/src/v2/models/payment.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('AesEncryption', () {
    test('encrypt and decrypt roundtrip', () async {
      const value = 'test-address-123';
      const secret = 'my-secret-key';

      final encrypted = await AesEncryption.encrypt(value, secret);
      final decrypted = await AesEncryption.decrypt(encrypted, secret);

      expect(decrypted, equals(value));
    });

    test('decrypt with wrong secret throws', () async {
      final encrypted = await AesEncryption.encrypt('value', 'correct-secret');

      expect(
        () => AesEncryption.decrypt(encrypted, 'wrong-secret'),
        throwsException,
      );
    });

    test('decrypt with too-short data throws', () {
      expect(
        () => AesEncryption.decrypt(base64.encode([1, 2, 3]), 'secret'),
        throwsException,
      );
    });

    test('produces different ciphertext each call due to random nonce', () async {
      const value = 'same-value';
      const secret = 'same-secret';

      final enc1 = await AesEncryption.encrypt(value, secret);
      final enc2 = await AesEncryption.encrypt(value, secret);

      expect(enc1, isNot(equals(enc2)));
    });
  });

  group('PaymentBuilder', () {
    test('defaults: empty destinations and ttl 3600', () {
      final payment = PaymentBuilder().build();

      expect(payment.destinations, isEmpty);
      expect(payment.ttl, equals(3600));
    });

    test('addDestination adds destination with zk=false by default', () {
      final payment = PaymentBuilder().addDestination('addr1').build();

      expect(payment.destinations.length, equals(1));
      expect(payment.destinations[0].value, equals('addr1'));
      expect(payment.destinations[0].zk, isFalse);
    });

    test('addDestination with zk=true', () {
      final payment = PaymentBuilder().addDestination('addr1', true).build();

      expect(payment.destinations[0].zk, isTrue);
    });

    test('setDescription sets description', () {
      final payment = PaymentBuilder().setDescription('my payment').build();

      expect(payment.description, equals('my payment'));
    });

    test('addMetadata encodes key-value as JSON string', () {
      final payment = PaymentBuilder().addMetadata('k1', 'v1').build();

      final meta = json.decode(payment.metadata!) as Map<String, dynamic>;
      expect(meta['k1'], equals('v1'));
    });

    test('addMetadata merges multiple calls into one JSON object', () {
      final payment = PaymentBuilder()
          .addMetadata('k1', 'v1')
          .addMetadata('k2', 'v2')
          .build();

      final meta = json.decode(payment.metadata!) as Map<String, dynamic>;
      expect(meta['k1'], equals('v1'));
      expect(meta['k2'], equals('v2'));
    });

    test('setTtl overrides default', () {
      final payment = PaymentBuilder().setTtl(7200).build();

      expect(payment.ttl, equals(7200));
    });

    test('fluent methods return the same builder instance', () {
      final builder = PaymentBuilder();

      expect(builder.addDestination('a'), same(builder));
      expect(builder.setDescription('d'), same(builder));
      expect(builder.addMetadata('k', 'v'), same(builder));
      expect(builder.setTtl(100), same(builder));
    });
  });

  group('BrantaConfig', () {
    test('custom constructor stores baseUrl and apiKey', () {
      const config = BrantaConfig(baseUrl: 'https://example.com', apiKey: 'key');

      expect(config.baseUrl, equals('https://example.com'));
      expect(config.apiKey, equals('key'));
    });

    test('custom constructor allows null apiKey', () {
      const config = BrantaConfig(baseUrl: 'https://example.com');

      expect(config.apiKey, isNull);
    });

    test('development() sets localhost baseUrl', () {
      final config = BrantaConfig.development(apiKey: 'dev-key');

      expect(config.baseUrl, equals('http://localhost:3000'));
      expect(config.apiKey, equals('dev-key'));
    });

    test('development() allows null apiKey', () {
      final config = BrantaConfig.development();

      expect(config.baseUrl, equals('http://localhost:3000'));
      expect(config.apiKey, isNull);
    });

    test('production() sets branta.pro baseUrl', () {
      final config = BrantaConfig.production(apiKey: 'prod-key');

      expect(config.baseUrl, equals('https://branta.pro'));
      expect(config.apiKey, equals('prod-key'));
    });

    test('production() allows null apiKey', () {
      final config = BrantaConfig.production();

      expect(config.baseUrl, equals('https://branta.pro'));
      expect(config.apiKey, isNull);
    });
  });

  group('BrantaClient', () {
    const baseUrl = 'http://localhost:3000';

    Payment makePayment([String address = 'addr1']) {
      return Payment(destinations: [Destination(value: address)], ttl: 3600);
    }

    test('getPaymentsAsync returns empty list on non-200', () async {
      final client = BrantaClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
        config: BrantaConfig(baseUrl: baseUrl),
      );

      expect(await client.getPaymentsAsync('addr1'), isEmpty);
      client.dispose();
    });

    test('getPaymentsAsync returns empty list on empty body', () async {
      final client = BrantaClient(
        httpClient: MockClient((_) async => http.Response('', 200)),
        config: BrantaConfig(baseUrl: baseUrl),
      );

      expect(await client.getPaymentsAsync('addr1'), isEmpty);
      client.dispose();
    });

    test('getPaymentsAsync parses payment list', () async {
      final payment = makePayment();
      final body = json.encode([payment.toJson()]);

      final client = BrantaClient(
        httpClient: MockClient((_) async => http.Response(body, 200)),
        config: BrantaConfig(baseUrl: baseUrl),
      );

      final result = await client.getPaymentsAsync('addr1');
      expect(result.length, equals(1));
      expect(result[0].destinations[0].value, equals('addr1'));
      client.dispose();
    });

    test('getPaymentsAsync returns empty list on network exception', () async {
      final client = BrantaClient(
        httpClient: MockClient((_) async => throw Exception('network error')),
        config: BrantaConfig(baseUrl: baseUrl),
      );

      expect(await client.getPaymentsAsync('addr1'), isEmpty);
      client.dispose();
    });

    test('addPaymentAsync sends POST with correct headers and body', () async {
      final payment = makePayment();
      final responseBody = json.encode(payment.toJson());

      late http.Request captured;
      final client = BrantaClient(
        httpClient: MockClient((req) async {
          captured = req;
          return http.Response(responseBody, 200);
        }),
        config: BrantaConfig(baseUrl: baseUrl, apiKey: 'test-key'),
      );

      final result = await client.addPaymentAsync(payment);

      expect(captured.method, equals('POST'));
      expect(captured.url.toString(), equals('$baseUrl/v2/payments'));
      expect(captured.headers['Authorization'], equals('Bearer test-key'));
      expect(result.destinations[0].value, equals('addr1'));
      client.dispose();
    });

    test('addPaymentAsync omits Authorization header when apiKey is null', () async {
      final payment = makePayment();

      late http.Request captured;
      final client = BrantaClient(
        httpClient: MockClient((req) async {
          captured = req;
          return http.Response(json.encode(payment.toJson()), 200);
        }),
        config: BrantaConfig(baseUrl: baseUrl),
      );

      await client.addPaymentAsync(payment);

      expect(captured.headers.containsKey('Authorization'), isFalse);
      client.dispose();
    });

    test('getZKPaymentsAsync decrypts zk destinations and leaves plain ones', () async {
      const secret = 'test-secret';
      const originalAddress = 'bc1qoriginaladdress';

      final encrypted = await AesEncryption.encrypt(originalAddress, secret);
      final payment = Payment(
        destinations: [
          Destination(value: encrypted, zk: true),
          Destination(value: 'plain-addr', zk: false),
        ],
        ttl: 3600,
      );

      final client = BrantaClient(
        httpClient: MockClient(
          (_) async => http.Response(json.encode([payment.toJson()]), 200),
        ),
        config: BrantaConfig(baseUrl: baseUrl),
      );

      final result = await client.getZKPaymentsAsync('addr1', secret);

      expect(result[0].destinations[0].value, equals(originalAddress));
      expect(result[0].destinations[1].value, equals('plain-addr'));
      client.dispose();
    });

    group('getPaymentsByQRCodeAsync', () {
      BrantaClient makeClient(MockClient mock) => BrantaClient(
        httpClient: mock,
        config: BrantaConfig(baseUrl: baseUrl),
      );

      // Returns a MockClient that captures requests and returns an empty list.
      (MockClient, List<Uri>) capturingMock() {
        final urls = <Uri>[];
        return (
          MockClient((req) async {
            urls.add(req.url);
            return http.Response('[]', 200);
          }),
          urls,
        );
      }

      test('ZK query params routes to getZKPaymentsAsync with correct id and secret', () async {
        const secret = 'zk-secret';
        const originalAddress = 'bc1qoriginaladdress';
        final encrypted = await AesEncryption.encrypt(originalAddress, secret);
        final payment = Payment(
          destinations: [Destination(value: encrypted, zk: true)],
          ttl: 3600,
        );

        late Uri capturedUrl;
        final client = makeClient(MockClient((req) async {
          capturedUrl = req.url;
          return http.Response(json.encode([payment.toJson()]), 200);
        }));

        final result = await client.getPaymentsByQRCodeAsync(
          'bitcoin:$originalAddress?branta_id=PAYMENT_ID&branta_secret=$secret',
        );

        expect(capturedUrl.toString(), equals('$baseUrl/v2/payments/PAYMENT_ID'));
        expect(result[0].destinations[0].value, equals(originalAddress));
        client.dispose();
      });

      test('bitcoin segwit (bc1q) URI strips prefix and lowercases', () async {
        final (mock, urls) = capturingMock();
        final client = makeClient(mock);
        await client.getPaymentsByQRCodeAsync('bitcoin:BC1QABC123');
        expect(urls[0].pathSegments.last, equals('bc1qabc123'));
        client.dispose();
      });

      test('bitcoin non-segwit URI strips prefix and preserves case', () async {
        final (mock, urls) = capturingMock();
        final client = makeClient(mock);
        await client.getPaymentsByQRCodeAsync('bitcoin:1ABCDef');
        expect(urls[0].pathSegments.last, equals('1ABCDef'));
        client.dispose();
      });

      test('bitcoin bcrt URI strips prefix and lowercases', () async {
        final (mock, urls) = capturingMock();
        final client = makeClient(mock);
        await client.getPaymentsByQRCodeAsync('bitcoin:BCRT1QABC');
        expect(urls[0].pathSegments.last, equals('bcrt1qabc'));
        client.dispose();
      });

      test('lightning URI strips prefix and lowercases', () async {
        final (mock, urls) = capturingMock();
        final client = makeClient(mock);
        await client.getPaymentsByQRCodeAsync('lightning:LNBC1234TEST');
        expect(urls[0].pathSegments.last, equals('lnbc1234test'));
        client.dispose();
      });

      test('lnbc prefix without scheme lowercases', () async {
        final (mock, urls) = capturingMock();
        final client = makeClient(mock);
        await client.getPaymentsByQRCodeAsync('LNBC1234TEST');
        expect(urls[0].pathSegments.last, equals('lnbc1234test'));
        client.dispose();
      });

      test('bc1q prefix without scheme lowercases', () async {
        final (mock, urls) = capturingMock();
        final client = makeClient(mock);
        await client.getPaymentsByQRCodeAsync('BC1QABC123');
        expect(urls[0].pathSegments.last, equals('bc1qabc123'));
        client.dispose();
      });

      test('Branta verify URL extracts address', () async {
        final (mock, urls) = capturingMock();
        final client = makeClient(mock);
        await client.getPaymentsByQRCodeAsync('$baseUrl/v2/verify/bc1qabc123');
        expect(urls[0].pathSegments.last, equals('bc1qabc123'));
        client.dispose();
      });

      test('Branta zk-verify URL extracts id and secret from fragment', () async {
        const secret = 'zk-frag-secret';
        const originalAddress = 'bc1qzkaddr';
        final encrypted = await AesEncryption.encrypt(originalAddress, secret);
        final payment = Payment(
          destinations: [Destination(value: encrypted, zk: true)],
          ttl: 3600,
        );

        late Uri capturedUrl;
        final client = makeClient(MockClient((req) async {
          capturedUrl = req.url;
          return http.Response(json.encode([payment.toJson()]), 200);
        }));

        final result = await client.getPaymentsByQRCodeAsync(
          '$baseUrl/v2/zk-verify/ZK_PAYMENT_ID#secret=$secret',
        );

        expect(capturedUrl.toString(), equals('$baseUrl/v2/payments/ZK_PAYMENT_ID'));
        expect(result[0].destinations[0].value, equals(originalAddress));
        client.dispose();
      });

      test('plain address is used as-is', () async {
        final (mock, urls) = capturingMock();
        final client = makeClient(mock);
        await client.getPaymentsByQRCodeAsync('1A1zP1eP5QGefi2DMPTfTL5SLmv7Divf');
        expect(urls[0].pathSegments.last, equals('1A1zP1eP5QGefi2DMPTfTL5SLmv7Divf'));
        client.dispose();
      });
    });
  });
}
