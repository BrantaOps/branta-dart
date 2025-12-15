import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/payment.dart';
import '../../helpers/aes_encryption.dart' as encryption;
import 'package:uuid/uuid.dart';

class BrantaClient {
  final http.Client _httpClient;
  final String baseUrl;
  final String? apiKey;

  BrantaClient({
    required http.Client httpClient,
    required this.baseUrl,
    this.apiKey,
  }) : _httpClient = httpClient;

  Map<String, String> _getHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (apiKey != null) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    return headers;
  }

  Future<List<Payment>> getPaymentsAsync(String address) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/v2/payments/$address'),
      );

      if (response.statusCode != 200 || response.body.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList
          .map((json) => Payment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Payment>> getZKPaymentsAsync(
    String address,
    String secret,
  ) async {
    final payments = await getPaymentsAsync(address);

    for (var payment in payments) {
      for (var destination in payment.destinations) {
        if (destination.zk == false) {
          continue;
        }

        destination.value = await encryption.AesEncryption.decrypt(
          destination.value,
          secret,
        );
      }
    }

    return payments;
  }

  Future<Payment> addPaymentAsync(Payment payment) async {
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/v2/payments'),
      headers: _getHeaders(),
      body: json.encode(payment.toJson()),
    );

    return Payment.fromJson(json.decode(response.body));
  }

  Future<(Payment, String)> addZKPaymentAsync(Payment payment) async {
    final secret = Uuid().v1();

    for (var destination in payment.destinations) {
      if (destination.zk == false) {
        continue;
      }

      destination.value = await encryption.AesEncryption.encrypt(
        destination.value,
        secret,
      );
    }

    var responsePayment = await addPaymentAsync(payment);

    return (responsePayment, secret);
  }

  void dispose() {
    _httpClient.close();
  }
}
