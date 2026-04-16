# Branta Dart SDK

Package contains functionality to assist Dart projects with making requests to Branta's server.

## Requirements

## Installation

Install via Dart Package Manager

```bash
dart pub add branta
```

## For Wallets

Wallets retrieve payment data by address or by scanning a QR code — no API key required.

```dart
import 'package:http/http.dart' as http;
import 'package:branta/branta.dart' as v2;

final client = v2.BrantaClient(
    httpClient: http.Client(),
    config: v2.BrantaConfig.production(privacy: v2.PrivacyMode.loose),
);

// Lookup by address
await client.getPaymentsAsync('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa');

// Lookup by QR code scan — handles bitcoin:, lightning:, Branta verify URLs, and ZK verify URLs
await client.getPaymentsByQRCodeAsync(qrText);
```

## For Platforms

Platforms require an API key to submit payment requests.

```dart
import 'package:http/http.dart' as http;
import 'package:branta/branta.dart' as v2;

final client = v2.BrantaClient(
    httpClient: http.Client(),
    config: v2.BrantaConfig.production(apiKey: '<api-key>', privacy: v2.PrivacyMode.loose),
);

final payment = v2.PaymentBuilder()
    .setDescription('Test Description')
    .addDestination('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa')
    .setTtl(600)
    .build();

await client.addPaymentAsync(payment);
```

## For Parent Platforms

Parent platforms sign outbound payment requests with an HMAC secret so Branta can verify the request originated from your server.

```dart
import 'package:http/http.dart' as http;
import 'package:branta/branta.dart' as v2;

final client = v2.BrantaClient(
    httpClient: http.Client(),
    config: v2.BrantaConfig.production(
        apiKey: '<api-key>',
        hmacSecret: '<hmac-secret>',
        privacy: v2.PrivacyMode.loose,
    ),
);

final payment = v2.PaymentBuilder()
    .addDestination('1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa')
    .build();

// X-HMAC-Signature and X-HMAC-Timestamp headers are added automatically
await client.addPaymentAsync(payment);
```

## Publishing
```
dart pub login
```

```
dart pub bump patch
```

```
dart pub publish
```

## Configuration

`BrantaConfig` lets you target different environments:

```dart
// Production (https://branta.pro)
v2.BrantaConfig.production(apiKey: 'your-api-key', privacy: v2.PrivacyMode.loose)

// Development (http://localhost:3000)
v2.BrantaConfig.localhost(apiKey: 'your-api-key', privacy: v2.PrivacyMode.loose)

// Custom (staging, self-hosted, etc.)
v2.BrantaConfig(baseUrl: 'https://staging.example.com', apiKey: 'your-api-key', privacy: v2.PrivacyMode.loose)

// With HMAC signing (parent platform)
v2.BrantaConfig.production(apiKey: 'your-api-key', hmacSecret: 'your-hmac-secret', privacy: v2.PrivacyMode.loose)

// From environment variables (BRANTA_API_KEY, BRANTA_HMAC_SECRET)
v2.BrantaConfig.fromEnvironment(baseUrl: 'https://branta.pro', privacy: v2.PrivacyMode.loose)
```

## Feature Support

 - [X] Per Environment configuration
 - [X] V2 Get Payment by address
 - [X] V2 Get Payment by QR Code
 - [X] V2 Get decrypted Zero Knowledge by address and secret
 - [X] V2 Add Payment
 - [X] V2 Payment by Parent Platform with HMAC
 - [X] V2 Add Zero Knowledge Payment with secret
 - [X] V2 Check API key valid
 - [X] Privacy mode (strict / loose)
