import 'dart:convert';

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
    this.childPlatform,
    this.isMetadataDecrypted = false,
  });

  String getDefaultValue() {
    if (destinations.isEmpty) throw Exception('Payment has no destinations.');
    return destinations.first.value;
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    final destinationsRaw = json['destinations'];
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
      childPlatform: json['child_platform'] is Map
          ? Platform.fromJson(
              Map<String, dynamic>.from(json['child_platform'] as Map),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'destinations': destinations.map((d) => d.toJson()).toList(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (ttl != null) 'ttl': ttl,
    if (metadata != null) 'metadata': metadata,
    if (platform != null) 'platform': platform,
    if (platformLogoUrl != null) 'platform_logo_url': platformLogoUrl,
    if (platformLogoLightUrl != null)
      'platform_logo_light_url': platformLogoLightUrl,
    if (childPlatform != null) 'child_platform': childPlatform!.toJson(),
  };
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
