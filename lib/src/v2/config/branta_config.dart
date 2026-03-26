import 'package:dotenv/dotenv.dart';

class BrantaConfig {
  final String baseUrl;
  final String? apiKey;
  final String? hmacSecret;

  const BrantaConfig({required this.baseUrl, this.apiKey, this.hmacSecret});

  factory BrantaConfig.staging({String? apiKey, String? hmacSecret}) =>
      BrantaConfig(
        baseUrl: 'https://staging.guardrail.branta.pro',
        apiKey: apiKey,
        hmacSecret: hmacSecret,
      );

  factory BrantaConfig.production({String? apiKey, String? hmacSecret}) =>
      BrantaConfig(
        baseUrl: 'https://guardrail.branta.pro',
        apiKey: apiKey,
        hmacSecret: hmacSecret,
      );

  factory BrantaConfig.localhost({String? apiKey, String? hmacSecret}) =>
      BrantaConfig(
        baseUrl: 'http://localhost:3000',
        apiKey: apiKey,
        hmacSecret: hmacSecret,
      );

  factory BrantaConfig.fromEnvironment({required String baseUrl}) {
    final env = DotEnv()..load();
    return BrantaConfig(
      baseUrl: baseUrl,
      apiKey: env['BRANTA_API_KEY'],
      hmacSecret: env['BRANTA_HMAC_SECRET'],
    );
  }
}
