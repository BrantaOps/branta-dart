import 'dart:convert';
import 'package:branta/branta.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const apiKey = String.fromEnvironment('BRANTA_API_KEY');

  final options = BrantaClientOptions(
    baseUrl: BrantaServerBaseUrl.staging,
    defaultApiKey: apiKey,
    privacy: PrivacyMode.loose,
  );

  final httpClient = http.Client();
  final brantaClient = BrantaClient(
    httpClient: httpClient,
    defaultOptions: options,
  );

  final service = BrantaService(
    client: brantaClient,
    aesEncryption: AesEncryptionService(),
    defaultOptions: options,
  );

  try {
    var address = "address1";
    var result = await service.getPaymentsAsync(address);

    print('Get Payment Response ----------------------');
    for (var payment in result.payments) {
      var json = JsonEncoder.withIndent('  ').convert(payment.toJson());
      print('Payment: $json');
    }

    var zkAddress =
        "pQerSFV+fievHP+guYoGJjx1CzFFrYWHAgWrLhn5473Z19M6+WMScLd1hsk808AEF/x+GpZKmNacFBf5BbQ=";
    var zkSecret = "1234";
    var result2 = await service.getPaymentsAsync(zkAddress,
        destinationEncryptionKey: zkSecret);

    print('Get ZK Payment Response -------------------');
    for (var payment in result2.payments) {
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

    var result3 = await service.addPaymentAsync(payment);
    var json = JsonEncoder.withIndent('  ').convert(result3.payment.toJson());
    print('Payment: $json');
  } finally {
    brantaClient.dispose();
  }
}
