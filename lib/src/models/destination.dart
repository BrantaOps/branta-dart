import '../enums/destination_type.dart';

class Destination {
  String value;
  bool isPrimary;

  /// Runtime-only. Set from the wire `zk` flag and cleared after a successful decrypt.
  /// Not serialized.
  bool isEncrypted;

  DestinationType? type;

  /// Wire field is `zk_id`.
  String? id;
  String? encryptedDek;

  Destination({
    required this.value,
    this.isPrimary = false,
    this.isEncrypted = true,
    this.type,
    this.id,
    this.encryptedDek,
  });

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
    value: json['value'] as String? ?? '',
    isPrimary: json['primary'] as bool? ?? false,
    // Guardrail `zk: false` is a leftover unencrypted row — do not try to decrypt it.
    isEncrypted: json['zk'] != false,
    type: DestinationType.fromJson(json['type'] as String?),
    id: json['zk_id'] as String?,
    encryptedDek: json['encrypted_dek'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'value': value,
    'primary': isPrimary,
    'zk': true,
    if (type != null) 'type': type!.jsonValue,
    if (id != null) 'zk_id': id,
    if (encryptedDek != null) 'encrypted_dek': encryptedDek,
  };
}
