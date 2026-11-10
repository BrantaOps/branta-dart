# Branta Dart SDK

Dart and Flutter SDK for [Branta](https://developer.branta.pro).

Use `verify()` on send and `addPayment()` on receive. Status handling and parent platforms are in the [developer docs](https://developer.branta.pro).

## Install

```bash
dart pub add branta
```

Requires Dart `^3.10.4`.

## Send

```dart
import 'package:branta/branta.dart';

final service = BrantaService(
  environment: BrantaEnvironment.production, // staging everywhere else
);

final result = await service.verify(input); // scanned QR or pasted text

switch (result.status) {
  case VerifyStatus.match:
    // Show the card for result.payments.first. Link it to result.verifyUrl.
    // What to send is result.matchedDestinations — each has type + plaintext value.
    // e.g. usdt_polygon / usdc_polygon / bitcoin_address / bolt11. Do not infer token from pol:.
    break;
  case VerifyStatus.unknown:
    // Not in Branta — show nothing.
    break;
  case VerifyStatus.tampered:
    // Destination was altered. Warn. Do not show a verified card.
    break;
  case VerifyStatus.incomplete:
    // 5xx, 429, or unreachable. Tell the user. Do not treat as unknown.
    break;
}
```

On-chain Bitcoin needs a `bitcoin:` URI with `branta_id` / `branta_secret`. Polygon EVM rails (`usdt_polygon`, `usdc_polygon`) need a `pol:` URI with the same params — token is on `matchedDestinations[].type`, not the `pol:` scheme. bolt11, Ark, and silent payments resolve from the value. A bare address (including bare `0x`) is `unknown`.

A 404 is `unknown`. 5xx, 429, or no network is `incomplete`. `verifyUrl` is always returned.

## Receive

```dart
import 'package:branta/branta.dart';

final service = BrantaService(
  environment: BrantaEnvironment.production,
  apiKey: '<api-key>',
);

final payment = PaymentBuilder()
    .setDescription('Invoice #12345')
    .addDestination('bc1q…', type: DestinationType.bitcoinAddress)
    .setTtl(600) // seconds. Omit to use the server default. 0 posts as 30 seconds.
    .build();

final result = await service.addPayment(payment);
// Store result.secret with the invoice. Put branta_id and branta_secret on the QR.
```

Every destination is encrypted. `addPayment` encrypts a copy, so a failed post can be retried with the same `Payment`. Description is stored in encrypted metadata.

Per-client parent platforms pass the child key per call:

```dart
await service.addPayment(
  payment,
  options: BrantaApiOptions(apiKey: '<child-api-key>'),
);
```

Shared-key parent platforms tag the child on the builder:

```dart
PaymentBuilder()
    .setDescription('Invoice #12345')
    .addDestination('bc1q…', type: DestinationType.bitcoinAddress)
    .setChildPlatform('ChildBrand', logoUrl: 'https://example.com/logo.png')
    .build();
```

## Publishing

- Update `version` in `pubspec.yaml`
- `dart pub login`
- `dart pub publish`

## Responsible Disclosure

Found critical bugs or vulnerabilities? Email them to support@branta.pro.
