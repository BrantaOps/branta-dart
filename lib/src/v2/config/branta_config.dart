import 'package:dotenv/dotenv.dart';
import 'privacy_mode.dart';

class BrantaConfig {
  final String baseUrl;
  final String? apiKey;
  final String? hmacSecret;
  /// Controls whether plain on-chain address lookups are permitted.
  /// See [PrivacyMode] for details.
  final PrivacyMode privacy;

  const BrantaConfig({
    required this.baseUrl,
    this.apiKey,
    this.hmacSecret,
    required this.privacy,
  });

  factory BrantaConfig.staging({
    String? apiKey,
    String? hmacSecret,
    required PrivacyMode privacy,
  }) =>
      BrantaConfig(
        baseUrl: 'https://staging.guardrail.branta.pro',
        apiKey: apiKey,
        hmacSecret: hmacSecret,
        privacy: privacy,
      );

  factory BrantaConfig.production({
    String? apiKey,
    String? hmacSecret,
    required PrivacyMode privacy,
  }) =>
      BrantaConfig(
        baseUrl: 'https://guardrail.branta.pro',
        apiKey: apiKey,
        hmacSecret: hmacSecret,
        privacy: privacy,
      );

  factory BrantaConfig.localhost({
    String? apiKey,
    String? hmacSecret,
    required PrivacyMode privacy,
  }) =>
      BrantaConfig(
        baseUrl: 'http://localhost:3000',
        apiKey: apiKey,
        hmacSecret: hmacSecret,
        privacy: privacy,
      );

  factory BrantaConfig.fromEnvironment({
    required String baseUrl,
    required PrivacyMode privacy,
  }) {
    final env = DotEnv()..load();
    return BrantaConfig(
      baseUrl: baseUrl,
      apiKey: env['BRANTA_API_KEY'],
      hmacSecret: env['BRANTA_HMAC_SECRET'],
      privacy: privacy,
    );
  }
}
