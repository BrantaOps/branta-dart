import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/payment.dart';
import '../config/branta_config.dart';
import '../../helpers/aes_encryption.dart' as encryption;
import 'package:uuid/uuid.dart';

class BrantaClient {
  final http.Client _httpClient;
  final BrantaConfig config;

  BrantaClient({
    required http.Client httpClient,
    required this.config,
  }) : _httpClient = httpClient;

  Map<String, String> _getHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (config.apiKey != null) {
      headers['Authorization'] = 'Bearer ${config.apiKey}';
    }

    return headers;
  }

  Future<List<Payment>> getPaymentsAsync(String address) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('${config.baseUrl}/v2/payments/$address'),
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

  Map<String, String> _buildHmacHeaders(
    String method,
    String url,
    String body,
  ) {
    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final message = '$method|${config.baseUrl}$url|$body|$timestamp';
    final digest = Hmac(sha256, utf8.encode(config.hmacSecret!))
        .convert(utf8.encode(message));
    return {
      'X-HMAC-Signature': digest.toString(),
      'X-HMAC-Timestamp': timestamp,
    };
  }

  Future<Payment> addPaymentAsync(Payment payment) async {
    final body = json.encode(payment.toJson());
    final headers = _getHeaders();

    if (config.hmacSecret != null) {
      headers.addAll(_buildHmacHeaders('POST', '/v2/payments', body));
    }

    final response = await _httpClient.post(
      Uri.parse('${config.baseUrl}/v2/payments'),
      headers: headers,
      body: body,
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

  Future<List<Payment>> getPaymentsByQRCodeAsync(String qrText) async {
    String text = qrText.trim();

    // Check for ZK query params (branta_id + branta_secret)
    final queryIndex = text.indexOf('?');
    if (queryIndex != -1) {
      final queryParams = Uri.splitQueryString(text.substring(queryIndex + 1));
      final brantaId = queryParams['branta_id'];
      final brantaSecret = queryParams['branta_secret'];
      if (brantaId != null && brantaSecret != null) {
        return getZKPaymentsAsync(brantaId, brantaSecret);
      }
      text = text.substring(0, queryIndex);
    }

    // Check if text is a Branta verify URL matching config.baseUrl
    final parsed = Uri.tryParse(text);
    if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      final configUri = Uri.tryParse(config.baseUrl);
      if (configUri != null && parsed.origin == configUri.origin) {
        final segments = parsed.pathSegments;
        if (segments.length >= 3 && segments[0] == 'v2' && segments[1] == 'verify') {
          return getPaymentsAsync(segments[2]);
        }
        if (segments.length >= 3 && segments[0] == 'v2' && segments[1] == 'zk-verify') {
          final fragmentParams = Uri.splitQueryString(parsed.fragment);
          final secret = fragmentParams['secret'];
          if (secret != null) {
            return getZKPaymentsAsync(segments[2], secret);
          }
          return getPaymentsAsync(segments[2]);
        }
        if (segments.isNotEmpty) {
          return getPaymentsAsync(segments.last);
        }
      }
    }

    // Strip protocol prefixes and normalize case
    final lower = text.toLowerCase();
    if (lower.startsWith('lightning:')) {
      text = text.substring('lightning:'.length).toLowerCase();
    } else if (lower.startsWith('bitcoin:')) {
      text = text.substring('bitcoin:'.length);
      final lowerText = text.toLowerCase();
      if (lowerText.startsWith('bc1q') || lowerText.startsWith('bcrt')) {
        text = lowerText;
      }
    } else if (lower.startsWith('lnbc') || lower.startsWith('bc1q')) {
      text = lower;
    }

    return getPaymentsAsync(text);
  }

  void dispose() {
    _httpClient.close();
  }
}
