enum BrantaServerBaseUrl {
  staging('https://staging.guardrail.branta.pro'),
  production('https://guardrail.branta.pro'),
  localhost('http://localhost:3000');

  const BrantaServerBaseUrl(this.url);
  final String url;
}
