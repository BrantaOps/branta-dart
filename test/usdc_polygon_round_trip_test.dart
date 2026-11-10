import 'dart:io' as io;

import 'package:branta/branta.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

class _MetricsHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final token = io.Platform.environment['BRANTA_INTEGRATION_METRICS_TOKEN'];
    if (token != null && token.isNotEmpty) {
      request.headers['X-Branta-Integration-Token'] = token;
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

void main() {
  // Live addPayment → verify against staging. Needs BRANTA_API_KEY (write).
  // Skipped unless BRANTA_RUN_INTEGRATION=1 — local `dart test` and PR CI must not hit Guardrail.
  final apiKey = io.Platform.environment['BRANTA_API_KEY'] ?? '';
  final skipLive =
      io.Platform.environment['BRANTA_RUN_INTEGRATION'] == '1' &&
          apiKey.isNotEmpty
      ? null
      : 'Live write skipped unless BRANTA_RUN_INTEGRATION=1 and BRANTA_API_KEY are set';

  group('Staging usdc_polygon round-trip', () {
    late BrantaService service;

    setUpAll(() {
      service = BrantaService(
        environment: BrantaEnvironment.staging,
        apiKey: apiKey,
        httpClient: _MetricsHttpClient(),
      );
    });

    tearDownAll(() {
      service.close();
    });

    const address = '0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B';
    const swapped = '0x1111111111111111111111111111111111111111';

    String polUri(String recipient, String encrypted, String secret) =>
        'pol:$recipient?value=50&user=send&currency=USD&branta_id=${Uri.encodeComponent(encrypted)}&branta_secret=${Uri.encodeComponent(secret)}';

    test(
      'addPayment then verify match, case-insensitive, tampered, and bare unknown',
      () async {
        final payment = PaymentBuilder()
            .addDestination(address, type: DestinationType.usdcPolygon)
            .setTtl(120)
            .build();

        final created = await service.addPayment(payment);
        final encrypted = created.payment.destinations.single.value;
        final secret = created.secret;

        expect(
          created.payment.destinations.single.type,
          equals(DestinationType.usdcPolygon),
        );

        final match = await service.verify(polUri(address, encrypted, secret));
        expect(match.status, equals(VerifyStatus.match));
        expect(match.matchedDestinations, hasLength(1));
        expect(
          match.matchedDestinations.single.type,
          equals(DestinationType.usdcPolygon),
        );
        expect(
          match.matchedDestinations.single.value.toLowerCase(),
          equals(address.toLowerCase()),
        );

        final lower = await service.verify(
          polUri(address.toLowerCase(), encrypted, secret),
        );
        expect(lower.status, equals(VerifyStatus.match));

        final tampered = await service.verify(
          polUri(swapped, encrypted, secret),
        );
        expect(tampered.status, equals(VerifyStatus.tampered));

        expect(
          (await service.verify(address)).status,
          equals(VerifyStatus.unknown),
        );
        expect(
          (await service.verify(
            'pol:$address?value=50&currency=USD',
          )).status,
          equals(VerifyStatus.unknown),
        );
      },
    );
  }, skip: skipLive);
}
