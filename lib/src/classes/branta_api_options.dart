import '../enums/branta_environment.dart';

/// Per-call overrides. Every field is optional; unset fields keep the service defaults.
class BrantaApiOptions {
  final BrantaEnvironment? environment;
  final String? apiKey;
  final String? hmacSecret;

  const BrantaApiOptions({this.environment, this.apiKey, this.hmacSecret});
}
