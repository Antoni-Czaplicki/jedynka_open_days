import 'package:json_annotation/json_annotation.dart';

part 'checkpoint.g.dart';

@JsonSerializable()
class Checkpoint {
  final int id;
  final String title, subtitle, location, description, image;

  Checkpoint({required this.id, required this.title, required this.subtitle, required this.location, required this.description, required this.image});

  factory Checkpoint.fromJson(Map<String, dynamic> json) => _$CheckpointFromJson(json);

  Map<String, dynamic> toJson() => _$CheckpointToJson(this);
}