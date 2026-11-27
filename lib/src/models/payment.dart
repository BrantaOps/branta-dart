import 'dart:convert';

import '../helpers/effective_brand.dart';
import 'destination.dart';
import 'platform.dart';

class Payment {
  String? description;
  List<Destination> destinations;
  DateTime? createdAt;

  /// Time to live in seconds. Null is omitted; the server default is 7 days. Posted 0 is 30 seconds.
  int? ttl;
  String? metadata;
  String? platform;
  String? platformLogoUrl;
  String? platformLogoLightUrl;
  Platform? parentPlatform;

  /// The payee a shared-key platform tags the payment with. Sent as `brand`.
  Platform? brand;

  /// Deprecated alias of [brand]. If both are set, [brand] wins.
  @Deprecated('Use brand')
  Platform? childPlatform;

  /// Runtime-only flag set after metadata decryption. Not serialized.
  bool isMetadataDecrypted = false;

  Payment({
    this.description,
    required this.destinations,
    this.createdAt,
    this.ttl,
    this.metadata,
    this.platform,
    this.platformLogoUrl,
    this.platformLogoLightUrl,
    this.parentPlatform,
    this.brand,
    @Deprecated('Use brand') this.childPlatform,
    this.isMetadataDecrypted = false,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    final destinationsRaw = json['destinations'];
    // `brand` wins over the deprecated `child_platform`. The value is mirrored
    // into the deprecated field so existing readers keep working.
    Platform? parsePlatform(Object? raw) =>
        raw is Map ? Platform.fromJson(Map<String, dynamic>.from(raw)) : null;
    final parsedBrand =
        parsePlatform(json['brand']) ?? parsePlatform(json['child_platform']);
    return Payment(
      destinations: destinationsRaw is List
          ? destinationsRaw
                .whereType<Map>()
                .map((e) => Destination.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      ttl: json['ttl'] == null ? null : (json['ttl'] as num).toInt(),
      metadata: json['metadata'] as String?,
      platform: json['platform'] as String?,
      platformLogoUrl: json['platform_logo_url'] as String?,
      platformLogoLightUrl: json['platform_logo_light_url'] as String?,
      parentPlatform: json['parent_platform'] is Map
          ? Platform.fromJson(
              Map<String, dynamic>.from(json['parent_platform'] as Map),
            )
          : null,
      brand: parsedBrand,
      // ignore: deprecated_member_use_from_same_package
      childPlatform: parsedBrand,
    );
  }

  Map<String, dynamic> toJson() {
    final effectiveBrand = this.effectiveBrand;
    return {
      'destinations': destinations.map((d) => d.toJson()).toList(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (ttl != null) 'ttl': ttl,
      if (metadata != null) 'metadata': metadata,
      if (platform != null) 'platform': platform,
      if (platformLogoUrl != null) 'platform_logo_url': platformLogoUrl,
      if (platformLogoLightUrl != null)
        'platform_logo_light_url': platformLogoLightUrl,
      if (effectiveBrand != null) 'brand': effectiveBrand.toJson(),
    };
  }
}

Map<String, dynamic> parseMetadataMap(String? metadata) {
  if (metadata == null || metadata.isEmpty) return {};
  try {
    final parsed = jsonDecode(metadata);
    if (parsed is Map) return Map<String, dynamic>.from(parsed);
  } catch (_) {
    // opaque string
  }
  return {};
}

void foldDescriptionIntoMetadata(Payment payment) {
  final description = payment.description;
  if (description == null || description.isEmpty) return;
  final metadataMap = parseMetadataMap(payment.metadata);
  metadataMap.putIfAbsent('description', () => description);
  payment.metadata = jsonEncode(metadataMap);
  payment.description = null;
}

void liftDescriptionFromMetadata(Payment payment) {
  final description = parseMetadataMap(payment.metadata)['description'];
  if (description is String) payment.description = description;
}
