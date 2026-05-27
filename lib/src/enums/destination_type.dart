enum DestinationType {
  bitcoinAddress('bitcoin_address'),
  bolt11('bolt11'),
  bolt12('bolt12'),
  lnUrl('ln_url'),
  tetherAddress('tether_address'),
  lnAddress('ln_address'),
  arkAddress('ark_address');

  const DestinationType(this.jsonValue);
  final String jsonValue;

  static DestinationType? fromJson(String? value) {
    if (value == null) return null;
    for (final e in DestinationType.values) {
      if (e.jsonValue == value) return e;
    }
    return null;
  }
}
