import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../../classes/branta_client_options.dart';
import '../../exceptions/branta_payment_exception.dart';
import '../interfaces/i_branta_client.dart';
import '../models/payment.dart';

class BrantaClient implements IBrantaClient {
  final http.Client _httpClient;
  final BrantaClientOptions _defaultOptions;

  BrantaClient({
    required http.Client httpClient,
    required BrantaClientOptions defaultOptions,
  })  : _httpClient = httpClient,
        _defaultOptions = defaultOptions;

  @override
  Future<List<Payment>> getPaymentsAsync(String destinationValue, {BrantaClientOptions? options}) async {
    final baseUrl = _resolveBaseUrl(options);
    final encoded = Uri.encodeComponent(destinationValue);

    List<Payment> payments;
    try {
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/v2/payments/$encoded'),
        headers: _buildAuthHeaders(options),
      );

      if (response.statusCode < 200 || response.statusCode >= 300 || response.body.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(response.body) as List<dynamic>;
      payments = decoded
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }

    _verifyLogoUrls(baseUrl, payments);
    return payments;
  }

  @override
  Future<Payment?> postPaymentAsync(Payment payment, {BrantaClientOptions? options}) async {
    final baseUrl = _resolveBaseUrl(options);
    final body = jsonEncode(payment.toJson());

    final headers = _buildAuthHeaders(options, requireApiKey: true);
    headers['Content-Type'] = 'application/json';
    _applyHmacHeaders(headers, baseUrl, body, options);

    final response = await _httpClient.post(
      Uri.parse('$baseUrl/v2/payments'),
      headers: headers,
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BrantaPaymentException(response.statusCode.toString());
    }

    return Payment.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  @override
  Future<bool> isApiKeyValidAsync({BrantaClientOptions? options}) async {
    try {
      final baseUrl = _resolveBaseUrl(options);
      final response = await _httpClient.get(
        Uri.parse('$baseUrl/v2/api-keys/health-check'),
        headers: _buildAuthHeaders(options, requireApiKey: true),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _buildAuthHeaders(BrantaClientOptions? options, {bool requireApiKey = false}) {
    final headers = <String, String>{};
    if (requireApiKey) {
      final apiKey = options?.defaultApiKey ?? _defaultOptions.defaultApiKey;
      if (apiKey == null) throw BrantaPaymentException('Unauthorized');
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  void _applyHmacHeaders(Map<String, String> headers, String baseUrl, String body, BrantaClientOptions? options) {
    final hmacSecret = options?.hmacSecret ?? _defaultOptions.hmacSecret;
    if (hmacSecret == null) return;

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final trimmedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final message = 'POST|$trimmedBase/v2/payments|$body|$timestamp';

    final digest = Hmac(sha256, utf8.encode(hmacSecret)).convert(utf8.encode(message));
    headers['X-HMAC-Signature'] = digest.toString();
    headers['X-HMAC-Timestamp'] = timestamp;
  }

  String _resolveBaseUrl(BrantaClientOptions? options) {
    return (options?.baseUrl ?? _defaultOptions.baseUrl).url;
  }

  void _verifyLogoUrls(String baseUrl, List<Payment> payments) {
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null) return;
    final baseOrigin = baseUri.origin;

    for (final payment in payments) {
      final logoUrl = payment.platformLogoUrl;
      if (logoUrl == null || logoUrl.isEmpty) return;

      final logoUri = Uri.tryParse(logoUrl);
      if (logoUri == null || logoUri.origin != baseOrigin) {
        throw BrantaPaymentException(
          'platformLogoUrl domain does not match the configured baseUrl domain',
        );
      }
    }
  }

  void dispose() => _httpClient.close();
}
