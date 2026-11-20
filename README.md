# Branta Dart SDK

Dart and Flutter SDK for [Branta](https://developer.branta.pro).

Status handling and parent platforms are in the [developer docs](https://developer.branta.pro).

## Install

```bash
dart pub add branta
```

## Send

```dart
import 'package:branta/branta.dart';

final service = BrantaService(
  environment: BrantaEnvironment.production,
);

final result = await service.verify(input); // scanned QR or pasted text

switch (result.status) {
  case VerifyStatus.match:
    // Show the card for result.payments.first. Link it to result.verifyUrl.
    // What to send is result.matchedDestinations — each has type + plaintext value.
    // Pay from matchedDestinations, not from the raw QR.
    break;
  case VerifyStatus.unknown:
    // Not in Branta — show nothing.
    break;
  case VerifyStatus.tampered:
    // Destination was altered. Warn. Do not show a verified card.
    break;
  case VerifyStatus.incomplete:
    // Branta could not complete the check. Tell the user. Do not block send.
    break;
}
```

Rules for each status: [Status rules](https://developer.branta.pro/setup/send/status-rules). Supported types: [Destination types](https://developer.branta.pro/destination-types).

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
// Link the sender to result.verifyUrl.
```

`addPayment` accepts the types on [Destination types](https://developer.branta.pro/destination-types). Pass the type for stablecoins. A bare address is not auto-detected. `usdtTron`, `usdtTon`, `usdtSolana`, and `usdcSolana` also encrypt and post, but no URI verifies them.

### HMAC signing

If Branta enabled Require HMAC on your platform, create a Secret in Guardrail and pass it as `hmacSecret`. The service signs each `addPayment`. Keep it server-side. See [HMAC signing](https://developer.branta.pro/setup/receive/hmac-signing).

```dart
final service = BrantaService(
  environment: BrantaEnvironment.production,
  apiKey: '<api-key>',
  hmacSecret: '<secret>',
);
```
