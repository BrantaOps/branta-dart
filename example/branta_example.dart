import 'package:branta/src/v2/classes/payment_builder.dart';
import 'package:http/http.dart' as http;
import 'package:branta/branta.dart' as v2;
import 'dart:convert';
import 'package:dotenv/dotenv.dart';

Future<void> main() async {
  final dotenv = DotEnv();
  dotenv.load();

  var brantaClient = v2.BrantaClient(
    httpClient: http.Client(),
    baseUrl: "http://localhost:3000",
    apiKey: dotenv.getOrElse('BRANTA_API_KEY', () => ''),
  );

  try {
    var address = "address1";
    var result = await brantaClient.getPaymentsAsync(address);

    print('Get Payment Response ----------------------');
    for (var payment in result) {
      var json = JsonEncoder.withIndent('  ').convert(payment.toJson());
      print('Payment: $json');
    }

    var zkAddress =
        "pQerSFV+fievHP+guYoGJjx1CzFFrYWHAgWrLhn5473Z19M6+WMScLd1hsk808AEF/x+GpZKmNacFBf5BbQ=";
    var zkSecret = "1234";
    var result2 = await brantaClient.getZKPaymentsAsync(zkAddress, zkSecret);

    print('Get ZK Payment Response -------------------');
    for (var payment in result2) {
      var json = JsonEncoder.withIndent('  ').convert(payment.toJson());
      print('Payment: $json');
    }

    print('Post Payment ------------------------------');
    var payment = PaymentBuilder()
        .setDescription("Test Description")
        .addMetadata("test_key", "test value")
        .setTtl(4000)
        .addDestination("address2")
        .build();

    var result3 = await brantaClient.addPaymentAsync(payment);
    var json = JsonEncoder.withIndent('  ').convert(result3.toJson());
    print('Payment: $json');
  } finally {
    brantaClient.dispose();
  }
}
