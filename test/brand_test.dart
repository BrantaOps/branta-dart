// These tests exercise the deprecated `setChildPlatform` / `childPlatform` names on purpose.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:convert';

import 'package:branta/branta.dart';
import 'package:branta/src/services/http_branta_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _address = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
const _logo = 'https://example.com/logo.png';
const _logoLight = 'https://example.com/logo-light.png';

const _expectedBrand = {
  'name': 'Acme',
  'logo_url': _logo,
  'logo_light_url': _logoLight,
};

void main() {
  group('PaymentBuilder brand', () {
    test('setBrand writes brand and the wire body has no child_platform', () {
      final payment = PaymentBuilder()
          .addDestination(_address)
          .setBrand('Acme', logoUrl: _logo, logoLightUrl: _logoLight)
          .build();

      final json = payment.toJson();
      expect(json['brand'], _expectedBrand);
      expect(json.containsKey('child_platform'), isFalse);
      expect(payment.brand?.name, 'Acme');
      expect(payment.brand?.logoUrl, _logo);
      expect(payment.brand?.logoLightUrl, _logoLight);
    });

    test('setBrand omits null logo keys', () {
      final json = PaymentBuilder()
          .addDestination(_address)
          .setBrand('Acme')
          .build()
          .toJson();
      expect(json['brand'], {'name': 'Acme'});
    });

    test('setChildPlatform produces the identical brand wire body', () {
      final viaBrand = PaymentBuilder()
          .addDestination(_address)
          .setBrand('Acme', logoUrl: _logo, logoLightUrl: _logoLight)
          .build()
          .toJson();
      final viaChild = PaymentBuilder()
          .addDestination(_address)
          .setChildPlatform('Acme', logoUrl: _logo, logoLightUrl: _logoLight)
          .build();

      // The alias delegates: it writes `brand`, not the deprecated field.
      expect(viaChild.brand?.name, 'Acme');
      expect(viaChild.childPlatform, isNull);
      final childJson = viaChild.toJson();
      expect(childJson['brand'], _expectedBrand);
      expect(childJson.containsKey('child_platform'), isFalse);
      // destination ids are random, so compare everything else.
      expect(childJson['brand'], viaBrand['brand']);
    });

    test('a Payment built with only childPlatform serializes as brand', () {
      final payment = Payment(
        destinations: [Destination(value: _address)],
        childPlatform: const Platform(
          name: 'Old',
          logoUrl: _logo,
          logoLightUrl: _logoLight,
        ),
      );
      final json = payment.toJson();
      expect(json['brand'], {
        'name': 'Old',
        'logo_url': _logo,
        'logo_light_url': _logoLight,
      });
      expect(json.containsKey('child_platform'), isFalse);
    });

    test('brand wins when both brand and childPlatform are set', () {
      final payment = Payment(
        destinations: [Destination(value: _address)],
        brand: const Platform(name: 'New'),
        childPlatform: const Platform(name: 'Old'),
      );
      final json = payment.toJson();
      expect(json['brand'], {'name': 'New'});
      expect(json.containsKey('child_platform'), isFalse);
    });

    test('no brand key when neither field is set', () {
      final json = Payment(destinations: []).toJson();
      expect(json.containsKey('brand'), isFalse);
      expect(json.containsKey('child_platform'), isFalse);
    });
  });

  group('Payment.fromJson brand parsing', () {
    test('parses brand and mirrors it into childPlatform', () {
      final payment = Payment.fromJson({
        'destinations': [],
        'brand': {'name': 'Acme', 'logo_url': _logo},
      });
      expect(payment.brand?.name, 'Acme');
      expect(payment.brand?.logoUrl, _logo);
      expect(payment.childPlatform?.name, 'Acme');
      expect(payment.childPlatform?.logoUrl, _logo);
    });

    test('parses child_platform into brand and childPlatform', () {
      final payment = Payment.fromJson({
        'destinations': [],
        'child_platform': {'name': 'Old', 'logo_light_url': _logoLight},
      });
      expect(payment.brand?.name, 'Old');
      expect(payment.brand?.logoLightUrl, _logoLight);
      expect(payment.childPlatform?.name, 'Old');
      expect(payment.childPlatform?.logoLightUrl, _logoLight);
    });

    test('brand wins when both keys are present', () {
      final payment = Payment.fromJson({
        'destinations': [],
        'brand': {'name': 'New'},
        'child_platform': {'name': 'Old'},
      });
      expect(payment.brand?.name, 'New');
      expect(payment.childPlatform?.name, 'New');
    });

    test('a non-map brand falls back to child_platform', () {
      final payment = Payment.fromJson({
        'destinations': [],
        'brand': 'nope',
        'child_platform': {'name': 'Old'},
      });
      expect(payment.brand?.name, 'Old');
    });

    test('neither key leaves both fields null', () {
      final payment = Payment.fromJson({'destinations': []});
      expect(payment.brand, isNull);
      expect(payment.childPlatform, isNull);
    });
  });

  group('HttpBrantaClient brand', () {
    HttpBrantaClient clientCapturing(
      void Function(Map<String, dynamic>) onBody,
    ) {
      return HttpBrantaClient(
        httpClient: MockClient((request) async {
          onBody(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('', 201);
        }),
        defaultOptions: const BrantaApiOptions(
          environment: BrantaEnvironment.localhost,
          apiKey: 'key',
        ),
      );
    }

    test('POST body sends brand and never child_platform', () async {
      Map<String, dynamic>? body;
      final client = clientCapturing((b) => body = b);

      await client.postPayment(
        PaymentBuilder()
            .addDestination(_address)
            .setChildPlatform('Acme', logoUrl: _logo, logoLightUrl: _logoLight)
            .build(),
      );

      expect(body!['brand'], _expectedBrand);
      expect(body!.containsKey('child_platform'), isFalse);
    });

    test('POST body for a childPlatform-only Payment sends brand', () async {
      Map<String, dynamic>? body;
      final client = clientCapturing((b) => body = b);

      await client.postPayment(
        Payment(
          destinations: [Destination(value: _address)],
          childPlatform: const Platform(name: 'Old'),
        ),
      );

      expect(body!['brand'], {'name': 'Old'});
      expect(body!.containsKey('child_platform'), isFalse);
    });

    HttpBrantaClient clientReturning(Object body) => HttpBrantaClient(
      httpClient: MockClient((_) async => http.Response(jsonEncode(body), 200)),
      defaultOptions: const BrantaApiOptions(
        environment: BrantaEnvironment.localhost,
      ),
    );

    test('logo origin check covers brand', () async {
      final client = clientReturning([
        {
          'destinations': [
            {'value': 'x'},
          ],
          'brand': {'logo_url': 'https://attacker.example/logo.png'},
        },
      ]);
      await expectLater(
        client.getPayments('x'),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            contains('brand.logoUrl'),
          ),
        ),
      );
    });

    test('logo origin check covers a brand logo light url', () async {
      final client = clientReturning([
        {
          'destinations': [
            {'value': 'x'},
          ],
          'brand': {'logo_light_url': 'https://attacker.example/l.png'},
        },
      ]);
      await expectLater(
        client.getPayments('x'),
        throwsA(
          isA<BrantaPaymentException>().having(
            (e) => e.message,
            'message',
            contains('brand.logoLightUrl'),
          ),
        ),
      );
    });

    test('a same-origin brand passes the logo check', () async {
      final client = clientReturning([
        {
          'destinations': [
            {'value': 'x'},
          ],
          'brand': {'logo_url': 'http://localhost:3000/logo.png'},
        },
      ]);
      final payments = await client.getPayments('x');
      expect(payments.single.brand?.logoUrl, 'http://localhost:3000/logo.png');
    });
  });
}
