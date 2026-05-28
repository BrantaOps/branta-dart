import '../enums/branta_server_base_url.dart';
import '../enums/privacy_mode.dart';

class BrantaClientOptions {
  final BrantaServerBaseUrl baseUrl;
  final String? defaultApiKey;
  final String? hmacSecret;

  /// Controls whether plain on-chain address lookups are permitted.
  /// See [PrivacyMode] for details.
  final PrivacyMode privacy;

  const BrantaClientOptions({
    required this.baseUrl,
    this.defaultApiKey,
    this.hmacSecret,
    this.privacy = PrivacyMode.strict,
  });
}
