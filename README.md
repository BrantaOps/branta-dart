# Branta Dart SDK

Package contains functionality to assist Dart/Flutter projects with making requests to Branta's server.

## Requirements

- Dart SDK ≥ 3.0

## Installation

```bash
dart pub add branta
```

# Integration Guide

If you are an AI agent implementing this SDK, follow the steps below exactly. If you are a developer, use this as a reference for the recommended integration patterns.

**1. Ask which side(s) of a payment they are implementing:**
- **Send side** — the app is paying someone (e.g. a wallet). The user scans or pastes a destination and you verify it belongs to a known platform before funds are sent.
- **Receive side** — the app is receiving payment (e.g. a checkout, POS, invoicing platform). You post destinations to Branta so wallets can verify them.
- **Both** — some apps do both (e.g. an exchange or self-custodial wallet with invoice generation). Implement each side independently.

If they are on the receive side, ask one follow-up:
- **Platform** — single-tenant, one API key.
- **Parent Platform** — multi-tenant, manages multiple child platforms. Two variants:
  - **Per-client keys** — each child has its own API key; requests are signed with the parent HMAC secret; you scope requests per-call.
  - **Shared key** — one API key for all children (no HMAC); tag the child per-payment with `setChildPlatform()`.

**2. Follow the matching Quick Start section below.**

**3. Apply these rules:**

General (all types):
- Always use `PrivacyMode.strict`. Never switch to `PrivacyMode.loose` unless there is no QR scanner and ZK is impossible.
- Never call `BrantaClient` directly — always go through `BrantaService`.
- Never show an error or "not verified" message when a lookup returns empty or throws. An empty result means the destination is unknown to Branta, not that it is malicious. Show nothing.
- For `baseUrl`: use `BrantaServerBaseUrl.production` only in production environments. Use `BrantaServerBaseUrl.staging` everywhere else — including local development, CI, and staging/test environments.

Send side (wallets):
- Prefer `getPaymentsByQrCodeAsync` over `getPaymentsAsync` — it handles multi-value ZK QR payloads correctly.
- Only fall back to `getPaymentsAsync` for copy/paste flows where there is no QR code.
- If `result.payments` is empty or an exception is thrown, render nothing.
- When `result.payments` is non-empty, display: the platform logo, the platform name (`payment.platform`), and the payment description (`payment.description`). Only render description when non-empty. Make the verification card a clickable link to `result.verifyUrl` — do not display the raw URL.
- For the platform logo: on dark backgrounds use `payment.platformLogoUrl`. On light backgrounds prefer `payment.platformLogoLightUrl` when available, falling back to `payment.platformLogoUrl`.
- Optionally display `payment.parentPlatform?.logoUrl` / `payment.parentPlatform?.logoLightUrl` as a small secondary badge (e.g. corner icon). This is not required.

Receive side (platforms):
- Always call `.setZk()` on the `PaymentBuilder` before calling `addPaymentAsync`. Plain-text destinations are rejected in `strict` mode.
- Store the `secret` from `AddPaymentResult` alongside the invoice — it is required to reconstruct the verify URL for the wallet.

Receive side (parent platforms — per-client keys), in addition to the platform rules:
- Include `hmacSecret` in `BrantaClientOptions` but omit `defaultApiKey` at service setup.
- Pass per-call `BrantaClientOptions` with each child's API key to scope requests.

Receive side (parent platforms — shared key), in addition to the platform rules:
- Include `defaultApiKey` in `BrantaClientOptions`. Do not include `hmacSecret`.
- Call `.setChildPlatform(name, logoUrl: ..., logoLightUrl: ...)` on the builder to tag each payment with the child's branding.

# Quick Start

## Setup

All integration types share the same setup pattern. Create a `BrantaService` by composing `BrantaClient` and `AesEncryptionService`:

```dart
import 'package:branta/branta.dart';
import 'package:http/http.dart' as http;

final options = BrantaClientOptions(
  baseUrl: BrantaServerBaseUrl.staging, // use .production in production only
  privacy: PrivacyMode.strict,
);

final brantaClient = BrantaClient(
  httpClient: http.Client(),
  defaultOptions: options,
);

final service = BrantaService(
  client: brantaClient,
  aesEncryption: AesEncryptionService(),
  defaultOptions: options,
);
```

Dispose `brantaClient` when it is no longer needed.

## For Wallets (Send Side)

Wallets verify destinations before the user sends funds. Two flows are supported:

- **QR scan** (preferred): call `getPaymentsByQrCodeAsync` with the raw QR text. Handles both on-chain ZK (`branta_id`/`branta_secret`) and self-encrypted destinations (bolt11, ark_address).
- **Copy/paste**: call `getPaymentsAsync` with the pasted text. Plain-text on-chain addresses return empty in strict mode — they must be ZK-encoded.

Always catch errors and show nothing on not-found.

```dart
import 'package:branta/branta.dart';
import 'package:http/http.dart' as http;

final options = BrantaClientOptions(
  baseUrl: BrantaServerBaseUrl.staging,
  privacy: PrivacyMode.strict,
);
final brantaClient = BrantaClient(httpClient: http.Client(), defaultOptions: options);
final service = BrantaService(
  client: brantaClient,
  aesEncryption: AesEncryptionService(),
  defaultOptions: options,
);

Future<void> lookup(String input, bool isQrCode) async {
  try {
    final result = isQrCode
        ? await service.getPaymentsByQrCodeAsync(input)
        : await service.getPaymentsAsync(input);

    if (result.payments.isEmpty) {
      // Not found — show nothing. The address may simply not exist in Branta.
      return;
    }

    // Render result.payments and result.verifyUrl
  } catch (_) {
    // Swallow errors — never surface a "not found" or lookup failure to the user.
  }
}
```

## For Platforms (Receive Side)

Platforms post payments to Branta so wallets can verify them. Include your API key and always call `.setZk()` on each destination.

```dart
import 'package:branta/branta.dart';
import 'package:http/http.dart' as http;

final options = BrantaClientOptions(
  baseUrl: BrantaServerBaseUrl.staging,
  defaultApiKey: '<api-key>',
  privacy: PrivacyMode.strict,
);
final brantaClient = BrantaClient(httpClient: http.Client(), defaultOptions: options);
final service = BrantaService(
  client: brantaClient,
  aesEncryption: AesEncryptionService(),
  defaultOptions: options,
);

final payment = PaymentBuilder()
    .setDescription('Order #1234')
    .addDestination('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa')
    .setZk()
    .setTtl(600)
    .build();

final result = await service.addPaymentAsync(payment);
// Store result.secret alongside the invoice.
```

## For Parent Platforms (Receive Side)

Choose a variant based on how API keys are structured. Shared key needs only an API key; per-client keys also require HMAC.

<details>
<summary>Shared key — one API key covers all children (Recommended)</summary>

Set up with a single API key; identify the child platform per-payment. No HMAC secret.

```dart
import 'package:branta/branta.dart';
import 'package:http/http.dart' as http;

final options = BrantaClientOptions(
  baseUrl: BrantaServerBaseUrl.staging,
  defaultApiKey: '<shared-api-key>',
  privacy: PrivacyMode.strict,
);
final brantaClient = BrantaClient(httpClient: http.Client(), defaultOptions: options);
final service = BrantaService(
  client: brantaClient,
  aesEncryption: AesEncryptionService(),
  defaultOptions: options,
);

final payment = PaymentBuilder()
    .setDescription('Order #1234')
    .addDestination('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa')
    .setZk()
    .setChildPlatform('ChildBrand', logoUrl: 'https://example.com/logo.png')
    .setTtl(600)
    .build();

final result = await service.addPaymentAsync(payment);
```

</details>

<details>
<summary>Per-client keys — each child has its own API key</summary>

Set up the service with the shared HMAC secret only; pass each child's API key per-call.

```dart
import 'package:branta/branta.dart';
import 'package:http/http.dart' as http;

final options = BrantaClientOptions(
  baseUrl: BrantaServerBaseUrl.staging,
  hmacSecret: '<hmac-secret>',
  privacy: PrivacyMode.strict,
);
final brantaClient = BrantaClient(httpClient: http.Client(), defaultOptions: options);
final service = BrantaService(
  client: brantaClient,
  aesEncryption: AesEncryptionService(),
  defaultOptions: options,
);

final payment = PaymentBuilder()
    .setDescription('Order #1234')
    .addDestination('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa')
    .setZk()
    .setTtl(600)
    .build();

// Scope to the child platform's API key per-call
final result = await service.addPaymentAsync(
  payment,
  options: BrantaClientOptions(defaultApiKey: '<child-api-key>'),
);
```

</details>

# Privacy

`PrivacyMode` controls whether plain-text on-chain lookups are allowed.

| Value | Behavior |
|-------|----------|
| `PrivacyMode.strict` | Only ZK (zero-knowledge / encrypted) lookups are permitted. `getPaymentsAsync` throws `BrantaPaymentException` for plain addresses; `getPaymentsByQrCodeAsync` returns an empty list. `addPaymentAsync` requires all destinations to have `isZk = true`. |
| `PrivacyMode.loose` | Both plain and ZK lookups are allowed. No restrictions enforced. |

# IBrantaService

The primary service interface. Always use `BrantaService` (which implements `IBrantaService`) — never call `BrantaClient` directly.

```dart
Future<PaymentsResult> getPaymentsByQrCodeAsync(String qrText); // preferred for wallets
Future<PaymentsResult> getPaymentsAsync(String destinationValue, {String? destinationEncryptionKey});
Future<AddPaymentResult> addPaymentAsync(Payment payment);
Future<bool> isApiKeyValidAsync();
```

`PaymentsResult` contains the list of matching `payments` and the `verifyUrl` to display — `verifyUrl` is always returned, even when `payments` is empty.

# Publishing

```bash
dart pub login
dart pub bump patch
dart pub publish
```

# Responsible Disclosure

Found critical bugs/vulnerabilities? Please email them to support@branta.pro. Thanks!
