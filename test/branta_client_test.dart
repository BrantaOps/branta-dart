import 'dart:async';
import 'dart:convert';

import 'package:branta/branta.dart';
import 'package:branta/src/exceptions/incomplete_error.dart';
import 'package:branta/src/services/http_branta_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const sameOrigin = 'http://localhost:3000';
const otherOrigin = 'https://attacker.example';

const destinations = [
  {'value': 'test-destination'},
];

HttpBrantaClient clientWithResponse(
  dynamic body, {
  int statusCode = 200,
  String? apiKey,
}) {
  final httpClient = MockClient((request) async {
    return http.Response(body is String ? body : jsonEncode(body), statusCode);
  });
  return HttpBrantaClient(
    httpClient: httpClient,
    defaultOptions: BrantaApiOptions(
      environment: BrantaEnvironment.localhost,
      apiKey: apiKey,
    ),
  );
}

void main() {
  group('HttpBrantaClient.getPayments logo url validation', () {
    test('checks every payment logo url, not just the first', () async {
      final client = clientWithResponse([
        {'destinations': destinations},
        {
          'destinations': destinations,
          'platform_logo_url': '$otherOrigin/logo.png',
        },
      ]);

      await expectLater(
        client.getPayments('value'),
        throwsA(isA<BrantaPaymentException>()),
      );
    });

    test('catches mismatched platformLogoLightUrl', () async {
      final client = clientWithResponse([
        {
          'destinations': destinations,
          'platform_logo_light_url': '$otherOrigin/logo-light.png',
        },
      ]);

      await expectLater(
        client.getPayments('value'),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            contains('platformLogoLightUrl'),
          ),
        ),
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
        client.getPayments('value'),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            contains('parentPlatform.logoUrl'),
          ),
        ),
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
        client.getPayments('value'),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            contains('parentPlatform.logoLightUrl'),
          ),
        ),
      );
    });

    test('catches mismatched child_platform (as brand) logoUrl', () async {
      final client = clientWithResponse([
        {
          'destinations': destinations,
          'child_platform': {'logo_url': '$otherOrigin/logo.png'},
        },
      ]);

      await expectLater(
        client.getPayments('value'),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            contains('brand.logoUrl'),
          ),
        ),
      );
    });

    test('catches mismatched child_platform (as brand) logoLightUrl', () async {
      final client = clientWithResponse([
        {
          'destinations': destinations,
          'child_platform': {'logo_light_url': '$otherOrigin/logo-light.png'},
        },
      ]);

      await expectLater(
        client.getPayments('value'),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            contains('brand.logoLightUrl'),
          ),
        ),
      );
    });

    test(
      'does not throw when all logo fields are same-origin or absent',
      () async {
        final client = clientWithResponse([
          {
            'destinations': destinations,
            'platform_logo_url': '$sameOrigin/a.png',
            'platform_logo_light_url': '$sameOrigin/b.png',
            'parent_platform': {
              'logo_url': '$sameOrigin/c.png',
              'logo_light_url': '$sameOrigin/d.png',
            },
            'child_platform': {'logo_url': '$sameOrigin/e.png'},
          },
          {'destinations': destinations},
        ]);

        final payments = await client.getPayments('value');
        expect(payments, hasLength(2));
      },
    );
  });

  group('HttpBrantaClient.getPayments HTTP errors', () {
    test('404 returns an empty list', () async {
      final client = clientWithResponse('', statusCode: 404);
      expect(await client.getPayments('value'), isEmpty);
    });

    test('429 and 5xx throw IncompleteError', () async {
      for (final status in [429, 500, 502, 503, 504]) {
        final client = clientWithResponse('', statusCode: status);
        await expectLater(
          client.getPayments('value'),
          throwsA(isA<IncompleteError>()),
        );
      }
    });

    test('network failure throws IncompleteError', () async {
      final httpClient = MockClient((request) async {
        throw http.ClientException('Failed to fetch');
      });
      final client = HttpBrantaClient(
        httpClient: httpClient,
        defaultOptions: const BrantaApiOptions(
          environment: BrantaEnvironment.localhost,
        ),
      );
      await expectLater(
        client.getPayments('value'),
        throwsA(isA<IncompleteError>()),
      );
    });

    test('default HTTP timeout is 30s', () {
      expect(httpTimeout, equals(const Duration(seconds: 30)));
    });

    test('request timeout throws IncompleteError', () async {
      final httpClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('[]', 200);
      });
      final client = HttpBrantaClient(
        httpClient: httpClient,
        defaultOptions: const BrantaApiOptions(
          environment: BrantaEnvironment.localhost,
        ),
        timeout: const Duration(milliseconds: 1),
      );
      await expectLater(
        client.getPayments('value'),
        throwsA(
          isA<IncompleteError>().having(
            (e) => e.message,
            'message',
            equals('Timeout'),
          ),
        ),
      );
    });

    test('timeout sends AbortableRequest and completes abortTrigger', () async {
      final abortSeen = Completer<void>();
      final httpClient = MockClient.streaming((request, bodyStream) async {
        expect(request, isA<http.AbortableRequest>());
        final abortable = request as http.AbortableRequest;
        expect(abortable.abortTrigger, isNotNull);
        abortable.abortTrigger!.then((_) {
          if (!abortSeen.isCompleted) abortSeen.complete();
        });
        await Future<void>.delayed(const Duration(seconds: 30));
        return http.StreamedResponse(Stream.empty(), 200);
      });
      final client = HttpBrantaClient(
        httpClient: httpClient,
        defaultOptions: const BrantaApiOptions(
          environment: BrantaEnvironment.localhost,
        ),
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        client.getPayments('value'),
        throwsA(isA<IncompleteError>()),
      );
      await abortSeen.future.timeout(const Duration(seconds: 1));
    });
  });

  group('HttpBrantaClient.getPayments malformed body', () {
    test('a body that is not JSON throws IncompleteError', () async {
      for (final body in [
        'not json',
        '<html>502 Bad Gateway</html>',
        '[{"a":',
      ]) {
        final client = clientWithResponse(body);
        await expectLater(
          client.getPayments('value'),
          throwsA(isA<IncompleteError>()),
          reason: body,
        );
      }
    });

    test('a row with the wrong shape throws IncompleteError', () async {
      for (final rows in [
        [
          {'ttl': 'soon'},
        ],
        [
          {'metadata': 5},
        ],
        [
          {'platform': 7},
        ],
      ]) {
        final client = clientWithResponse(rows);
        await expectLater(
          client.getPayments('value'),
          throwsA(isA<IncompleteError>()),
          reason: jsonEncode(rows),
        );
      }
    });

    test('valid JSON that is not a list is an empty result', () async {
      for (final body in ['{}', 'null', '"text"', '42']) {
        final client = clientWithResponse(body);
        expect(await client.getPayments('value'), isEmpty, reason: body);
      }
    });

    test('a logo on the wrong origin still throws, not incomplete', () async {
      final client = clientWithResponse([
        {
          'destinations': destinations,
          'platform_logo_url': '$otherOrigin/logo.png',
        },
      ]);
      await expectLater(
        client.getPayments('value'),
        throwsA(isA<BrantaPaymentException>()),
      );
    });

    test(
      'verify returns incomplete with a verifyUrl, and does not throw',
      () async {
        final service = BrantaService(
          environment: BrantaEnvironment.localhost,
          httpClient: MockClient(
            (request) async => http.Response('<html>', 200),
          ),
        );
        final result = await service.verify(
          'bitcoin:bc1qgw3dzmhnyvcswc9r0v0z0ajtp8ulm4nuyeahwr?branta_id=abc&branta_secret=def',
        );
        expect(result.status, equals(VerifyStatus.incomplete));
        expect(result.payments, isEmpty);
        expect(result.verifyUrl, equals('$sameOrigin/v2/verify/abc'));
      },
    );
  });

  group('HttpBrantaClient.postPayment HTTP errors', () {
    final payment = Payment(
      destinations: [Destination(value: 'test-destination')],
    );

    test('401 throws Unauthorized', () async {
      final client = clientWithResponse('', statusCode: 401, apiKey: 'key');
      await expectLater(
        client.postPayment(payment),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            equals('Unauthorized'),
          ),
        ),
      );
    });

    test('500 throws InternalServerError', () async {
      final client = clientWithResponse('', statusCode: 500, apiKey: 'key');
      await expectLater(
        client.postPayment(payment),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            equals('InternalServerError'),
          ),
        ),
      );
    });

    test('missing api key throws Unauthorized', () async {
      final client = clientWithResponse({'destinations': destinations});
      await expectLater(
        client.postPayment(payment),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            equals('Unauthorized'),
          ),
        ),
      );
    });
  });
}
