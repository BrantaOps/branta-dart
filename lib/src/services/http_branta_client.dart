import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../classes/branta_api_options.dart';
import '../exceptions/branta_payment_exception.dart';
import '../exceptions/incomplete_error.dart';
import '../helpers/branta_extensions.dart';
import '../interfaces/branta_client.dart';
import '../models/payment.dart';

class HttpBrantaClient implements BrantaClient {
  final http.Client _httpClient;
  final BrantaApiOptions _defaultOptions;

  HttpBrantaClient({
    required http.Client httpClient,
    required BrantaApiOptions defaultOptions,
  }) : _httpClient = httpClient,
       _defaultOptions = defaultOptions;

  @override
  Future<List<Payment>> getPayments(
    String destinationValue, {
    BrantaApiOptions? options,
  }) async {
    final baseUrl = _resolveBaseUrl(options);
    final encoded = encodeUriComponent(destinationValue);

    final http.Response response;
    try {
      response = await _httpClient.get(
        Uri.parse('$baseUrl/v2/payments/$encoded'),
        headers: _buildAuthHeaders(options),
      );
    } on IncompleteError {
      rethrow;
    } on BrantaPaymentException {
      rethrow;
    } catch (e) {
      throw IncompleteError(e.toString());
    }

    if (response.statusCode == 404) return [];
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IncompleteError(_statusText(response.statusCode));
    }
    if (response.body.isEmpty) return [];

    final decoded = jsonDecode(response.body);
    final payments = decoded is List
        ? decoded
              .whereType<Map>()
              .map((e) => Payment.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <Payment>[];

    _verifyLogoUrls(baseUrl, payments);
    return payments;
  }

  @override
  Future<Payment?> postPayment(
    Payment payment, {
    BrantaApiOptions? options,
  }) async {
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
      throw BrantaPaymentException(_statusText(response.statusCode));
    }
    if (response.body.isEmpty) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return Payment.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  Future<bool> isApiKeyValid({BrantaApiOptions? options}) async {
    final baseUrl = _resolveBaseUrl(options);
    final response = await _httpClient.get(
      Uri.parse('$baseUrl/v2/api-keys/health-check'),
      headers: _buildAuthHeaders(options, requireApiKey: true),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Map<String, String> _buildAuthHeaders(
    BrantaApiOptions? options, {
    bool requireApiKey = false,
  }) {
    final headers = <String, String>{};
    if (requireApiKey) {
      final apiKey = options?.apiKey ?? _defaultOptions.apiKey;
      if (apiKey == null) throw const BrantaPaymentException('Unauthorized');
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  void _applyHmacHeaders(
    Map<String, String> headers,
    String baseUrl,
    String body,
    BrantaApiOptions? options,
  ) {
    final hmacSecret = options?.hmacSecret ?? _defaultOptions.hmacSecret;
    if (hmacSecret == null) return;

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final trimmedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final message = 'POST|$trimmedBase/v2/payments|$body|$timestamp';

    final digest = Hmac(
      sha256,
      utf8.encode(hmacSecret),
    ).convert(utf8.encode(message));
    headers['X-HMAC-Signature'] = digest.toString();
    headers['X-HMAC-Timestamp'] = timestamp;
  }

  String _resolveBaseUrl(BrantaApiOptions? options) {
    final environment = options?.environment ?? _defaultOptions.environment;
    if (environment == null) {
      throw StateError('Branta: environment is a required option.');
    }
    return environment.url;
  }

  void _verifyLogoUrls(String baseUrl, List<Payment> payments) {
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null || !baseUri.hasScheme) return;
    final baseOrigin = baseUri.origin;

    void check(String? logoUrl, String fieldName) {
      if (logoUrl == null || logoUrl.isEmpty) return;

      final logoUri = Uri.tryParse(logoUrl);
      String? logoOrigin;
      if (logoUri != null && logoUri.hasScheme) {
        try {
          logoOrigin = logoUri.origin;
        } catch (_) {
          logoOrigin = null;
        }
      }
      if (logoOrigin != baseOrigin) {
        throw BrantaPaymentException(
          '$fieldName domain does not match the configured API domain',
        );
      }
    }

    for (final payment in payments) {
      check(payment.platformLogoUrl, 'platformLogoUrl');
      check(payment.platformLogoLightUrl, 'platformLogoLightUrl');
      check(payment.parentPlatform?.logoUrl, 'parentPlatform.logoUrl');
      check(
        payment.parentPlatform?.logoLightUrl,
        'parentPlatform.logoLightUrl',
      );
      check(payment.childPlatform?.logoUrl, 'childPlatform.logoUrl');
      check(payment.childPlatform?.logoLightUrl, 'childPlatform.logoLightUrl');
    }
  }

  String _statusText(int status) {
    const map = {
      400: 'BadRequest',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'NotFound',
      409: 'Conflict',
      422: 'UnprocessableEntity',
      429: 'TooManyRequests',
      500: 'InternalServerError',
      502: 'BadGateway',
      503: 'ServiceUnavailable',
      504: 'GatewayTimeout',
    };
    return map[status] ?? status.toString();
  }

  void dispose() => _httpClient.close();
}
