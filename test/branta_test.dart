// Run `make build` before running tests to generate *.g.dart files.
import 'dart:convert';
import 'package:branta/src/helpers/aes_encryption.dart';
import 'package:branta/src/v2/classes/payment_builder.dart';
import 'package:branta/src/v2/clients/branta_client.dart';
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

  group('BrantaClient', () {
    const baseUrl = 'http://localhost:3000';

    Payment makePayment([String address = 'addr1']) {
      return Payment(destinations: [Destination(value: address)], ttl: 3600);
    }

    test('getPaymentsAsync returns empty list on non-200', () async {
      final client = BrantaClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
        baseUrl: baseUrl,
      );

      expect(await client.getPaymentsAsync('addr1'), isEmpty);
      client.dispose();
    });

    test('getPaymentsAsync returns empty list on empty body', () async {
      final client = BrantaClient(
        httpClient: MockClient((_) async => http.Response('', 200)),
        baseUrl: baseUrl,
      );

      expect(await client.getPaymentsAsync('addr1'), isEmpty);
      client.dispose();
    });

    test('getPaymentsAsync parses payment list', () async {
      final payment = makePayment();
      final body = json.encode([payment.toJson()]);

      final client = BrantaClient(
        httpClient: MockClient((_) async => http.Response(body, 200)),
        baseUrl: baseUrl,
      );

      final result = await client.getPaymentsAsync('addr1');
      expect(result.length, equals(1));
      expect(result[0].destinations[0].value, equals('addr1'));
      client.dispose();
    });

    test('getPaymentsAsync returns empty list on network exception', () async {
      final client = BrantaClient(
        httpClient: MockClient((_) async => throw Exception('network error')),
        baseUrl: baseUrl,
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
        baseUrl: baseUrl,
        apiKey: 'test-key',
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
        baseUrl: baseUrl,
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
        baseUrl: baseUrl,
      );

      final result = await client.getZKPaymentsAsync('addr1', secret);

      expect(result[0].destinations[0].value, equals(originalAddress));
      expect(result[0].destinations[1].value, equals('plain-addr'));
      client.dispose();
    });
  });
}
