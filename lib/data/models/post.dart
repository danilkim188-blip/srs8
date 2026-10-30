import 'package:json_annotation/json_annotation.dart';

part 'post.g.dart';

@JsonSerializable()
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.isLocal = false,
  });

  final int id;
  final int userId;
  final String title;
  final String body;

  /// Пост создан в приложении (JSONPlaceholder его не сохраняет).
  /// В ответе сервера поля нет — по умолчанию false.
  @JsonKey(defaultValue: false)
  final bool isLocal;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);
  Map<String, dynamic> toJson() => _$PostToJson(this);

  Post copyWith({int? id, bool? isLocal}) => Post(
        id: id ?? this.id,
        userId: userId,
        title: title,
        body: body,
        isLocal: isLocal ?? this.isLocal,
      );
}
