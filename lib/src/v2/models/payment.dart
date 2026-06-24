import 'destination.dart';
import 'platform.dart';

class Payment {
  String? description;
  List<Destination> destinations;
  DateTime? createdAt;
  int ttl;
  String? metadata;
  String? platform;
  String? platformLogoUrl;
  String? platformLogoLightUrl;
  Platform? parentPlatform;
  String? btcPayServerPluginVersion;

  /// Runtime-only flag set by [BrantaService] after metadata decryption.
  /// Not serialized to/from JSON.
  bool isMetadataDecrypted = false;

  Payment({
    this.description,
    required this.destinations,
    this.createdAt,
    this.ttl = 0,
    this.metadata,
    this.platform,
    this.platformLogoUrl,
    this.platformLogoLightUrl,
    this.parentPlatform,
    this.btcPayServerPluginVersion,
  });

  String getDefaultValue() {
    if (destinations.isEmpty) throw Exception('Payment has no destinations.');
    return destinations.first.value;
  }

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        description: json['description'] as String?,
        destinations: (json['destinations'] as List<dynamic>?)
                ?.map((e) => Destination.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
        ttl: json['ttl'] as int? ?? 0,
        metadata: json['metadata'] as String?,
        platform: json['platform'] as String?,
        platformLogoUrl: json['platform_logo_url'] as String?,
        platformLogoLightUrl: json['platform_logo_light_url'] as String?,
        parentPlatform: json['parent_platform'] != null
            ? Platform.fromJson(json['parent_platform'] as Map<String, dynamic>)
            : null,
        btcPayServerPluginVersion:
            json['btc_pay_server_plugin_version'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (description != null) 'description': description,
        'destinations': destinations.map((d) => d.toJson()).toList(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        'ttl': ttl,
        if (metadata != null) 'metadata': metadata,
        if (platform != null) 'platform': platform,
        if (platformLogoUrl != null) 'platform_logo_url': platformLogoUrl,
        if (platformLogoLightUrl != null)
          'platform_logo_light_url': platformLogoLightUrl,
        if (parentPlatform != null) 'parent_platform': parentPlatform!.toJson(),
        if (btcPayServerPluginVersion != null)
          'btc_pay_server_plugin_version': btcPayServerPluginVersion,
      };
}
