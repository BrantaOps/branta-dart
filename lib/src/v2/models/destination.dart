import '../../../src/enums/destination_type.dart';

class Destination {
  String value;
  bool isPrimary;
  bool isZk;

  /// Runtime-only flag set by [BrantaService] after a lookup.
  /// Not serialized to/from JSON.
  bool isEncrypted;

  DestinationType? type;
  String? zkId;
  String? encryptedDek;

  Destination({
    required this.value,
    this.isPrimary = false,
    this.isZk = false,
    this.isEncrypted = false,
    this.type,
    this.zkId,
    this.encryptedDek,
  });

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
        value: json['value'] as String,
        isPrimary: json['primary'] as bool? ?? false,
        isZk: json['zk'] as bool? ?? false,
        type: DestinationType.fromJson(json['type'] as String?),
        zkId: json['zk_id'] as String?,
        encryptedDek: json['encrypted_dek'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'value': value,
        'primary': isPrimary,
        'zk': isZk,
        if (type != null) 'type': type!.jsonValue,
        if (zkId != null) 'zk_id': zkId,
        if (encryptedDek != null) 'encrypted_dek': encryptedDek,
      };
}
