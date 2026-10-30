import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';


class PostCache {
  PostCache(this._prefs);

  final SharedPreferences _prefs;

  static const _localKey = 'local_posts';

  static String _key(int? userId) =>
      userId == null ? 'cache_posts_all' : 'cache_posts_user_$userId';

  /// null — кэша нет (или он повреждён).
  List<Post>? read({int? userId}) => _decode(_prefs.getString(_key(userId)));

  Future<void> save(List<Post> posts, {int? userId}) =>
      _prefs.setString(_key(userId), _encode(posts.where((p) => !p.isLocal)));

  /// Посты, созданные локально (их нет на сервере).
  List<Post> readLocal() => _decode(_prefs.getString(_localKey)) ?? [];

  Future<void> saveLocal(List<Post> posts) =>
      _prefs.setString(_localKey, _encode(posts));

  String _encode(Iterable<Post> posts) =>
      jsonEncode(posts.map((p) => p.toJson()).toList());

  List<Post>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      developer.log('Broken cache ignored: $e', name: 'PostCache');
      return null;
    }
  }
}
