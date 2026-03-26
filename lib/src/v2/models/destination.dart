import 'package:json_annotation/json_annotation.dart';
import 'destination_type.dart';

part 'destination.g.dart';

@JsonSerializable()
class Destination {
  String value;
  final bool zk;
  final DestinationType? type;

  Destination({required this.value, this.zk = false, this.type});

  factory Destination.fromJson(Map<String, dynamic> json) =>
      _$DestinationFromJson(json);
  Map<String, dynamic> toJson() => _$DestinationToJson(this);
}
