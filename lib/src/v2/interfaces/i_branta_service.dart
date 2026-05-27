import '../../classes/branta_client_options.dart';
import '../models/add_payment_result.dart';
import '../models/payment.dart';
import '../models/payments_result.dart';

abstract class IBrantaService {
  Future<PaymentsResult> getPaymentsAsync(
    String destinationValue, {
    String? destinationEncryptionKey,
    BrantaClientOptions? options,
  });

  Future<PaymentsResult> getPaymentsByQrCodeAsync(
    String qrText, {
    BrantaClientOptions? options,
  });

  Future<AddPaymentResult> addPaymentAsync(
    Payment payment, {
    BrantaClientOptions? options,
  });

  Future<bool> isApiKeyValidAsync({BrantaClientOptions? options});
}
