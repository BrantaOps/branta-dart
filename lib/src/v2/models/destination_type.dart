import 'package:json_annotation/json_annotation.dart';

enum DestinationType {
  @JsonValue('bitcoin_address')
  bitcoinAddress,
  @JsonValue('bolt11')
  bolt11,
  @JsonValue('bolt12')
  bolt12,
  @JsonValue('ln_url')
  lnUrl,
  @JsonValue('tether_address')
  tetherAddress,
}
