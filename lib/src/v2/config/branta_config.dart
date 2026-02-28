class BrantaConfig {
  final String baseUrl;
  final String? apiKey;

  const BrantaConfig({required this.baseUrl, this.apiKey});

  factory BrantaConfig.development({String? apiKey}) => BrantaConfig(
    baseUrl: 'http://localhost:3000',
    apiKey: apiKey,
  );

  factory BrantaConfig.production({String? apiKey}) => BrantaConfig(
    baseUrl: 'https://branta.pro',
    apiKey: apiKey,
  );
}
