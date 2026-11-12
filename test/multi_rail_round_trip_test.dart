import 'dart:io' as io;
import 'dart:math';

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

class _SecretKeyRail {
  const _SecretKeyRail({
    required this.type,
    required this.scheme,
    required this.address,
    required this.swapped,
    this.caseFold = false,
  });

  final DestinationType type;
  final String scheme;
  final String address;
  final String swapped;
  final bool caseFold;
}

String _uniq() {
  final now = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  final rand = Random().nextInt(0xffffff).toRadixString(16).padLeft(6, '0');
  return '$now$rand';
}

String _secretKeyUri(
  String scheme,
  String recipient,
  String encrypted,
  String secret,
) =>
    '$scheme:$recipient?branta_id=${Uri.encodeComponent(encrypted)}&branta_secret=${Uri.encodeComponent(secret)}';

const _secretKeyRails = <_SecretKeyRail>[
  _SecretKeyRail(
    type: DestinationType.bitcoinAddress,
    scheme: 'bitcoin',
    address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
    swapped: 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4',
  ),
  _SecretKeyRail(
    type: DestinationType.usdtPolygon,
    scheme: 'pol',
    address: '0x278297528c32eCa01295B0d2135984d3442ec963',
    swapped: '0x1111111111111111111111111111111111111111',
    caseFold: true,
  ),
  _SecretKeyRail(
    type: DestinationType.usdcPolygon,
    scheme: 'pol',
    address: '0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B',
    swapped: '0x2222222222222222222222222222222222222222',
    caseFold: true,
  ),
  _SecretKeyRail(
    type: DestinationType.usdtEthereum,
    scheme: 'eth',
    address: '0xBF5550253939187432Ef4dccE8089765d3DCb47f',
    swapped: '0x3333333333333333333333333333333333333333',
    caseFold: true,
  ),
  _SecretKeyRail(
    type: DestinationType.usdcEthereum,
    scheme: 'eth',
    address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    swapped: '0x4444444444444444444444444444444444444444',
    caseFold: true,
  ),
  _SecretKeyRail(
    type: DestinationType.usdtBsc,
    scheme: 'bsc',
    address: '0x55d398326f99059fF775485246999027B3197955',
    swapped: '0x5555555555555555555555555555555555555555',
    caseFold: true,
  ),
  _SecretKeyRail(
    type: DestinationType.usdcBsc,
    scheme: 'bsc',
    address: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d',
    swapped: '0x6666666666666666666666666666666666666666',
    caseFold: true,
  ),
  _SecretKeyRail(
    type: DestinationType.usdtTron,
    scheme: 'tron',
    address: 'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb',
    swapped: 'TXyZ1111111111111111111111111111111',
  ),
  _SecretKeyRail(
    type: DestinationType.usdtTon,
    scheme: 'ton',
    address: 'EQDtFpEwcFAEcRe5mLVh2N6C0y-_tur3BYOM93pEZPw390by',
    swapped: 'EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c',
  ),
  _SecretKeyRail(
    type: DestinationType.usdtSolana,
    scheme: 'sol',
    address: 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
    swapped: '11111111111111111111111111111111',
  ),
  _SecretKeyRail(
    type: DestinationType.usdcSolana,
    scheme: 'sol',
    address: '7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDofycyinf',
    swapped: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
  ),
];

void main() {
  // Live addPayment → verify against staging. Needs BRANTA_API_KEY (write).
  // Skipped unless BRANTA_RUN_INTEGRATION=1 — local `dart test` and PR CI must not hit Guardrail.
  final apiKey = io.Platform.environment['BRANTA_API_KEY'] ?? '';
  final skipLive =
      io.Platform.environment['BRANTA_RUN_INTEGRATION'] == '1' &&
          apiKey.isNotEmpty
      ? null
      : 'Live write skipped unless BRANTA_RUN_INTEGRATION=1 and BRANTA_API_KEY are set';

  group('Staging multi-rail SDK round-trips', () {
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

    for (final rail in _secretKeyRails) {
      test(
        'secret-key ${rail.type.jsonValue}: match, caseFold, tampered, bare unknown, uri-without-branta unknown',
        () async {
          final payment = PaymentBuilder()
              .addDestination(rail.address, type: rail.type)
              .setTtl(180)
              .build();

          final created = await service.addPayment(payment);
          final encrypted = created.payment.destinations.single.value;
          final secret = created.secret;

          expect(
            created.payment.destinations.single.type,
            equals(rail.type),
          );
          expect(encrypted, isNot(equals(rail.address)));

          final match = await service.verify(
            _secretKeyUri(rail.scheme, rail.address, encrypted, secret),
          );
          expect(match.status, equals(VerifyStatus.match));
          expect(match.matchedDestinations, hasLength(1));
          expect(match.matchedDestinations.single.type, equals(rail.type));
          if (rail.caseFold) {
            expect(
              match.matchedDestinations.single.value.toLowerCase(),
              equals(rail.address.toLowerCase()),
            );
          } else {
            expect(
              match.matchedDestinations.single.value,
              equals(rail.address),
            );
          }

          if (rail.caseFold) {
            final folded = await service.verify(
              _secretKeyUri(
                rail.scheme,
                rail.address.toLowerCase(),
                encrypted,
                secret,
              ),
            );
            expect(folded.status, equals(VerifyStatus.match));
          }

          final tampered = await service.verify(
            _secretKeyUri(rail.scheme, rail.swapped, encrypted, secret),
          );
          expect(tampered.status, equals(VerifyStatus.tampered));

          expect(
            (await service.verify(rail.address)).status,
            equals(VerifyStatus.unknown),
          );
          expect(
            (await service.verify('${rail.scheme}:${rail.address}')).status,
            equals(VerifyStatus.unknown),
          );
        },
        timeout: const Timeout(Duration(seconds: 45)),
      );
    }

    for (final entry in <(DestinationType, String Function())>[
      (DestinationType.bolt11, () => 'lnbc${_uniq()}n1ptest'),
      (DestinationType.arkAddress, () => 'ark1qqroundtrip${_uniq()}'),
      (
        DestinationType.silentPayment,
        () => 'sp1qqroundtrip${_uniq()}',
      ),
    ]) {
      final type = entry.$1;
      final factory = entry.$2;
      test(
        'derived-key ${type.jsonValue}: match, wrong value unknown',
        () async {
          final value = factory();
          final payment = PaymentBuilder()
              .addDestination(value, type: type)
              .setTtl(180)
              .build();

          final created = await service.addPayment(payment);
          expect(created.payment.destinations.single.type, equals(type));
          expect(
            created.payment.destinations.single.value,
            isNot(equals(value)),
          );

          final match = await service.verify(value);
          expect(match.status, equals(VerifyStatus.match));
          expect(match.matchedDestinations.single.type, equals(type));
          expect(
            match.matchedDestinations.single.value.toLowerCase(),
            equals(value.toLowerCase()),
          );

          final miss = await service.verify(factory());
          expect(miss.status, equals(VerifyStatus.unknown));
        },
        timeout: const Timeout(Duration(seconds: 45)),
      );
    }

    test(
      'cross-scheme: eth URI must not bind a polygon-only payment',
      () async {
        const address = '0x278297528c32eCa01295B0d2135984d3442ec963';
        final payment = PaymentBuilder()
            .addDestination(address, type: DestinationType.usdtPolygon)
            .setTtl(180)
            .build();

        final created = await service.addPayment(payment);
        final encrypted = created.payment.destinations.single.value;
        final secret = created.secret;

        final cross = await service.verify(
          _secretKeyUri('eth', address, encrypted, secret),
        );
        expect(cross.status, equals(VerifyStatus.unknown));

        final correct = await service.verify(
          _secretKeyUri('pol', address, encrypted, secret),
        );
        expect(correct.status, equals(VerifyStatus.match));
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'match-if-any: eth dual-token payment binds scanned rail only',
      () async {
        const usdt = '0xBF5550253939187432Ef4dccE8089765d3DCb47f';
        const usdc = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
        final payment = PaymentBuilder()
            .addDestination(usdt, type: DestinationType.usdtEthereum)
            .addDestination(usdc, type: DestinationType.usdcEthereum)
            .setTtl(180)
            .build();

        final created = await service.addPayment(payment);
        final encryptedUsdt = created.payment.destinations[0].value;
        final secret = created.secret;

        final matchUsdt = await service.verify(
          _secretKeyUri('eth', usdt, encryptedUsdt, secret),
        );
        expect(matchUsdt.status, equals(VerifyStatus.match));
        expect(
          matchUsdt.matchedDestinations.map((d) => d.type),
          equals([DestinationType.usdtEthereum]),
        );
        final usdcDest = matchUsdt.payments.single.destinations
            .where((d) => d.type == DestinationType.usdcEthereum)
            .single;
        expect(usdcDest.isEncrypted, isTrue);

        final matchUsdc = await service.verify(
          _secretKeyUri('eth', usdc, encryptedUsdt, secret),
        );
        expect(matchUsdc.status, equals(VerifyStatus.match));
        expect(
          matchUsdc.matchedDestinations.map((d) => d.type),
          equals([DestinationType.usdcEthereum]),
        );

        final swapped = await service.verify(
          _secretKeyUri(
            'eth',
            '0x9999999999999999999999999999999999999999',
            encryptedUsdt,
            secret,
          ),
        );
        expect(swapped.status, equals(VerifyStatus.tampered));
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );
  }, skip: skipLive);
}
