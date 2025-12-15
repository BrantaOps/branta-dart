import 'package:json_annotation/json_annotation.dart';
import 'destination.dart';

part 'payment.g.dart';

@JsonSerializable()
class Payment {
  String? description;
  final List<Destination> destinations;

  @JsonKey(name: 'created_at')
  final DateTime? createdDate;

  int? ttl;

  String? metadata;
  final String? platform;

  @JsonKey(name: 'platform_logo_url')
  final String? platformLogoUrl;

  Payment({
    this.description,
    required this.destinations,
    this.createdDate,
    this.ttl,
    this.metadata,
    this.platform,
    this.platformLogoUrl,
  });

  factory Payment.fromJson(Map<String, dynamic> json) =>
      _$PaymentFromJson(json);
  Map<String, dynamic> toJson() => _$PaymentToJson(this);
}
