# Branta Dart SDK

Package contains functionality to assist Dart projects with making requests to Branta's server.

## Requirements

## Installation

Install via Dart Package Manager

```bash
dart pub add branta
```

## Quick Start

1. Getting a payment
```dart
import 'package:http/http.dart' as http;
import 'package:branta/branta.dart' as v2;
import 'dart:convert';

Future<void> main() async {
    var brantaClient = v2.BrantaClient(
        httpClient: http.Client(),
        baseUrl: "http://localhost:3000",
        apiKey: dotenv.getOrElse('BRANTA_API_KEY', () => ''),
    );

    try {

        var address = "address1";
        var result = await brantaClient.getPaymentsAsync(address);

        for (var payment in result) {
            var json = JsonEncoder.withIndent('  ').convert(payment.toJson());
            print('Payment: $json');
        }
    } finally {
        brantaClient.dispose();
    }
}
```

2. Getting a ZK payment with known secret

```dart
var zkAddress = "pQerSFV+fievHP+guYoGJjx1CzFFrYWHAgWrLhn5473Z19M6+WMScLd1hsk808AEF/x+GpZKmNacFBf5BbQ=";
var zkSecret = "1234";
var result = await brantaClient.getZKPaymentsAsync(zkAddress, zkSecret);
```

3. Posting a Payment
```dart
// Building a payment
var payment = PaymentBuilder()
    .setDescription("Test Description")
    .addMetadata("test_key", "test value")
    .setTtl(4000)
    .addDestination("address2")
    .build();

// POST req (requires API_KEY)
var result3 = await brantaClient.addPaymentAsync(payment);
```

## Publishing
```
dart pub login
```

```
dart pub publish
```
