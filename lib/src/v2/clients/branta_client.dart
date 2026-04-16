import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/payment.dart';
import '../config/branta_config.dart';
import '../config/privacy_mode.dart';
import '../../helpers/aes_encryption.dart' as encryption;
import '../../exceptions/branta_payment_exception.dart';
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
    if (config.privacy == PrivacyMode.strict) {
      throw BrantaPaymentException(
        "privacy is set to 'strict': plain on-chain address lookups are not permitted",
      );
    }

    return _fetchPaymentsAsync(address);
  }

  Future<List<Payment>> _fetchPaymentsAsync(String address) async {
    List<Payment> payments;
    try {
      final response = await _httpClient.get(
        Uri.parse('${config.baseUrl}/v2/payments/${Uri.encodeComponent(address)}'),
      );

      if (response.statusCode < 200 || response.statusCode >= 300 || response.body.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(response.body);
      payments = jsonList
          .map((json) => Payment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }

    // Validate that platformLogoUrl (if present) belongs to the configured base domain.
    // This prevents a malicious server from pointing logo URLs to arbitrary domains.
    final baseOrigin = Uri.parse(config.baseUrl).origin;
    for (final payment in payments) {
      final logoUrl = payment.platformLogoUrl;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        final logoUri = Uri.tryParse(logoUrl);
        if (logoUri == null || logoUri.origin != baseOrigin) {
          throw BrantaPaymentException(
            'platformLogoUrl domain does not match the configured baseUrl domain',
          );
        }
      }
      payment.verifyUrl = _buildVerifyUrl(address);
    }

    return payments;
  }

  Future<List<Payment>> getZKPaymentsAsync(
    String address,
    String secret,
  ) async {
    final payments = await _fetchPaymentsAsync(address);

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

    for (final payment in payments) {
      payment.verifyUrl = _buildVerifyUrl(address, secret: secret);
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
    if (config.apiKey == null) {
      throw BrantaPaymentException('Unauthorized');
    }

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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BrantaPaymentException(response.statusCode.toString());
    }

    final responsePayment = Payment.fromJson(json.decode(response.body));
    responsePayment.verifyUrl = _buildVerifyUrl(payment.destinations.first.value);
    return responsePayment;
  }

  Future<bool> isApiKeyValidAsync() async {
    try {
      final headers = _getHeaders();
      final response = await _httpClient.get(
        Uri.parse('${config.baseUrl}/v2/api-keys/health-check'),
        headers: headers,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<(Payment, String)> addZKPaymentAsync(Payment payment) async {
    final secret = Uuid().v4();

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
    responsePayment.verifyUrl = _buildVerifyUrl(
      payment.destinations.first.value,
      secret: secret,
    );

    return (responsePayment, secret);
  }

  String _buildVerifyUrl(String address, {String? secret}) {
    final encoded = Uri.encodeComponent(address);
    if (secret != null) {
      return '${config.baseUrl}/v2/zk-verify/$encoded#secret=$secret';
    }
    return '${config.baseUrl}/v2/verify/$encoded';
  }

  Future<List<Payment>> _getPlainPaymentsAsync(String address) {
    if (config.privacy == PrivacyMode.strict) return Future.value([]);
    return _fetchPaymentsAsync(address);
  }

  Future<List<Payment>> getPaymentsByQRCodeAsync(String qrText) async {
    String text = qrText.trim();

    // ZK query params (branta_id + branta_secret) — always allowed regardless of privacy
    final queryIndex = text.indexOf('?');
    if (queryIndex != -1) {
      // Replace + with %2B before parsing to preserve literal + signs (Uri.splitQueryString decodes + as space).
      final rawQuery = text.substring(queryIndex + 1).replaceAll('+', '%2B');
      final queryParams = Uri.splitQueryString(rawQuery);
      final brantaId = queryParams['branta_id'];
      final brantaSecret = queryParams['branta_secret'];
      if (brantaId != null && brantaSecret != null) {
        return getZKPaymentsAsync(brantaId, brantaSecret);
      }
      text = text.substring(0, queryIndex);
    }

    // http/https URL matching the configured base URL
    final parsed = Uri.tryParse(text);
    if (parsed != null && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      final configUri = Uri.tryParse(config.baseUrl);
      if (configUri != null && parsed.origin == configUri.origin) {
        final segments = parsed.pathSegments;

        if (segments.length >= 3 && segments[0] == 'v2' && segments[1] == 'verify') {
          return _getPlainPaymentsAsync(segments[2]);
        }

        if (segments.length >= 3 && segments[0] == 'v2' && segments[1] == 'zk-verify') {
          final fragmentParams = Uri.splitQueryString(parsed.fragment.replaceAll('+', '%2B'));
          final secret = fragmentParams['secret'];
          if (secret != null) return getZKPaymentsAsync(segments[2], secret);
          return _getPlainPaymentsAsync(segments[2]);
        }

        if (segments.isNotEmpty) {
          return _getPlainPaymentsAsync(segments.last);
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

    return _getPlainPaymentsAsync(text);
  }

  void dispose() {
    _httpClient.close();
  }
}
