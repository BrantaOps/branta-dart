import 'dart:convert';
import 'package:branta/branta.dart';

Future<void> main() async {
  const apiKey = String.fromEnvironment('BRANTA_API_KEY');

  final service = BrantaService(
    environment: BrantaEnvironment.staging,
    apiKey: apiKey,
  );

  try {
    final result = await service.verify('bc1qexample');

    print('Verify ----------------------');
    print(result.status);
    for (final payment in result.payments) {
      print(const JsonEncoder.withIndent('  ').convert(payment.toJson()));
    }

    print('Post Payment ------------------------------');
    final payment = PaymentBuilder()
        .setDescription('Test Description')
        .addMetadata('test_key', 'test value')
        .setTtl(4000)
        .addDestination('bc1qexample', type: DestinationType.bitcoinAddress)
        .build();

    final posted = await service.addPayment(payment);
    print(const JsonEncoder.withIndent('  ').convert(posted.payment.toJson()));
    print(posted.verifyUrl);
  } finally {
    service.close();
  }
}
