import '../enums/branta_environment.dart';

/// Per-call overrides. Every field is optional; unset fields keep the service defaults.
class BrantaApiOptions {
  final BrantaEnvironment? environment;
  final String? apiKey;

  /// Secret from the Secrets tab in Guardrail. Signs `POST /v2/payments` with
  /// `X-HMAC-Signature` and `X-HMAC-Timestamp`. Needed when your platform has Require HMAC on.
  /// Server-side only. See https://developer.branta.pro/setup/receive/hmac-signing
  final String? hmacSecret;

  const BrantaApiOptions({this.environment, this.apiKey, this.hmacSecret});
}
