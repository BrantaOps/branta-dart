import '../../classes/branta_client_options.dart';
import '../models/payment.dart';

abstract class IBrantaClient {
  Future<List<Payment>> getPaymentsAsync(String destinationValue, {BrantaClientOptions? options});
  Future<Payment?> postPaymentAsync(Payment payment, {BrantaClientOptions? options});
  Future<bool> isApiKeyValidAsync({BrantaClientOptions? options});
}
