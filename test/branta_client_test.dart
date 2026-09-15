import 'dart:convert';

import 'package:branta/branta.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// Matches BrantaServerBaseUrl.localhost's mapped URL.
const sameOrigin = 'http://localhost:3000';
const otherOrigin = 'https://attacker.example';

const destinations = [
  {'value': 'test-destination'}
];

BrantaClient clientWithResponse(dynamic body) {
  final httpClient = MockClient((request) async {
    return http.Response(jsonEncode(body), 200);
  });
  return BrantaClient(
    httpClient: httpClient,
    defaultOptions: const BrantaClientOptions(
      baseUrl: BrantaServerBaseUrl.localhost,
      privacy: PrivacyMode.loose,
    ),
  );
}

void main() {
  group('BrantaClient.getPaymentsAsync logo url validation', () {
    test('checks every payment logo url, not just the first', () async {
      final client = clientWithResponse([
        {'destinations': destinations},
        {'destinations': destinations, 'platform_logo_url': '$otherOrigin/logo.png'},
      ]);

      await expectLater(client.getPaymentsAsync('value'), throwsA(isA<BrantaPaymentException>()));
    });

    test('catches mismatched platformLogoLightUrl', () async {
      final client = clientWithResponse([
        {'destinations': destinations, 'platform_logo_light_url': '$otherOrigin/logo-light.png'},
      ]);

      await expectLater(
        client.getPaymentsAsync('value'),
        throwsA(isA<BrantaPaymentException>().having(
          (e) => e.message,
          'message',
          contains('platformLogoLightUrl'),
        )),
      );
    });

    test('catches mismatched parentPlatform.logoUrl', () async {
      final client = clientWithResponse([
        {
          'destinations': destinations,
          'parent_platform': {'logo_url': '$otherOrigin/logo.png'},
        },
      ]);

      await expectLater(
        client.getPaymentsAsync('value'),
        throwsA(isA<BrantaPaymentException>().having(
          (e) => e.message,
          'message',
          contains('parentPlatform.logoUrl'),
        )),
      );
    });

    test('catches mismatched parentPlatform.logoLightUrl', () async {
      final client = clientWithResponse([
        {
          'destinations': destinations,
          'parent_platform': {'logo_light_url': '$otherOrigin/logo-light.png'},
        },
      ]);

      await expectLater(
        client.getPaymentsAsync('value'),
        throwsA(isA<BrantaPaymentException>().having(
          (e) => e.message,
          'message',
          contains('parentPlatform.logoLightUrl'),
        )),
      );
    });

    test('catches mismatched childPlatform.logoUrl', () async {
      final client = clientWithResponse([
        {
          'destinations': destinations,
          'child_platform': {'logo_url': '$otherOrigin/logo.png'},
        },
      ]);

      await expectLater(
        client.getPaymentsAsync('value'),
        throwsA(isA<BrantaPaymentException>().having(
          (e) => e.message,
          'message',
          contains('childPlatform.logoUrl'),
        )),
      );
    });

    test('catches mismatched childPlatform.logoLightUrl', () async {
      final client = clientWithResponse([
        {
          'destinations': destinations,
          'child_platform': {'logo_light_url': '$otherOrigin/logo-light.png'},
        },
      ]);

      await expectLater(
        client.getPaymentsAsync('value'),
        throwsA(isA<BrantaPaymentException>().having(
          (e) => e.message,
          'message',
          contains('childPlatform.logoLightUrl'),
        )),
      );
    });

    test('does not throw when all logo fields are same-origin or absent', () async {
      final client = clientWithResponse([
        {
          'destinations': destinations,
          'platform_logo_url': '$sameOrigin/a.png',
          'platform_logo_light_url': '$sameOrigin/b.png',
          'parent_platform': {'logo_url': '$sameOrigin/c.png', 'logo_light_url': '$sameOrigin/d.png'},
          'child_platform': {'logo_url': '$sameOrigin/e.png'},
        },
        {'destinations': destinations},
      ]);

      final payments = await client.getPaymentsAsync('value');
      expect(payments, hasLength(2));
    });
  });
}
