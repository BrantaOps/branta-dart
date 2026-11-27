import 'dart:io';

import 'package:branta/branta.dart';
import 'package:branta/src/sdk_version.dart';
import 'package:branta/src/services/http_branta_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

String manifestVersion() {
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync());
  return match!.group(1)!;
}

void main() {
  const header = 'X-Branta-SDK';

  test('SDK version constant matches pubspec.yaml', () {
    expect(brantaSdkVersion, equals(manifestVersion()));
  });

  group('X-Branta-SDK header', () {
    late List<http.BaseRequest> seen;
    late HttpBrantaClient client;

    setUp(() {
      seen = [];
      client = HttpBrantaClient(
        httpClient: MockClient((request) async {
          seen.add(request);
          return http.Response('[]', 200);
        }),
        defaultOptions: const BrantaApiOptions(
          environment: BrantaEnvironment.localhost,
          apiKey: 'key',
          hmacSecret: 'secret',
        ),
      );
    });

    test('POST carries dart/<manifest version>', () async {
      await client.postPayment(
        Payment(destinations: [Destination(value: 'x')]),
      );
      expect(seen, hasLength(1));
      expect(seen.single.method, equals('POST'));
      expect(seen.single.headers[header], equals('dart/${manifestVersion()}'));
    });

    test('GET lookups do not carry it', () async {
      await client.getPayments('value');
      await client.isApiKeyValid();
      expect(seen, hasLength(2));
      for (final request in seen) {
        expect(request.method, equals('GET'));
        expect(request.headers.containsKey(header), isFalse);
      }
    });

    test('POST body does not contain it', () async {
      await client.postPayment(
        Payment(destinations: [Destination(value: 'x')]),
      );
      final body = (seen.single as http.Request).body;
      expect(body.toLowerCase(), isNot(contains('branta-sdk')));
    });
  });
}
