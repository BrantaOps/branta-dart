import '../classes/branta_api_options.dart';
import '../models/payment.dart';

abstract class BrantaClient {
  Future<List<Payment>> getPayments(
    String destinationValue, {
    BrantaApiOptions? options,
  });
  Future<Payment?> postPayment(Payment payment, {BrantaApiOptions? options});
  Future<bool> isApiKeyValid({BrantaApiOptions? options});
}
