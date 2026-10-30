import 'dart:developer' as developer;
import 'dart:math';

import '../../core/error/app_exception.dart';
import '../local/post_cache.dart';
import '../models/comment.dart';
import '../models/create_post_request.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../remote/post_api.dart';

/// Единственная точка доступа к данным для UI-слоя:
/// объединяет сеть и кэш, переводит любые ошибки в [AppException].
class PostRepository {
  PostRepository({required PostApi api, required PostCache cache})
      : _api = api,
        _cache = cache;

  static const pageSize = 10;

  final PostApi _api;
  final PostCache _cache;

  // ---------- кэш ----------

  List<Post>? cachedPosts({int? userId}) => _cache.read(userId: userId);

  List<Post> localPosts({int? userId}) => _cache
      .readLocal()
      .where((p) => userId == null || p.userId == userId)
      .toList();

  // ---------- посты ----------

  Future<List<Post>> fetchPosts({required int page, int? userId}) async {
    final posts = await _guard(
      () => _api.getPosts(page: page, limit: pageSize, userId: userId),
    );
    await _updateCache(posts, page: page, userId: userId);
    return posts;
  }

  Future<Post> getPost(int id) => _guard(() => _api.getPost(id));

  Future<List<Post>> getPostsByUser(int userId) =>
      _guard(() => _api.getPostsByUser(userId));

  Future<List<Comment>> getComments(int postId) =>
      _guard(() => _api.getComments(postId));

  /// Возвращает объект, который вернул сервер.
  Future<Post> createPost(CreatePostRequest request) =>
      _guard(() => _api.createPost(request));

  /// JSONPlaceholder всегда отвечает id = 101 и ничего не сохраняет,
  /// поэтому в списке пост хранится локально с собственным id и пометкой.
  Future<Post> addLocalPost(Post serverPost) async {
    final local = _cache.readLocal();
    final nextId =
        local.isEmpty ? 100001 : local.map((p) => p.id).reduce(max) + 1;
    final post = serverPost.copyWith(id: nextId, isLocal: true);
    await _cache.saveLocal([post, ...local]);
    return post;
  }

  // ---------- пользователи ----------

  Future<List<User>> getUsers() => _guard(() => _api.getUsers());

  Future<User> getUser(int id) => _guard(() => _api.getUser(id));

  // ---------- внутреннее ----------

  Future<void> _updateCache(
    List<Post> posts, {
    required int page,
    int? userId,
  }) async {
    try {
      if (page == 1) {
        await _cache.save(posts, userId: userId);
      } else {
        final existing = _cache.read(userId: userId) ?? [];
        final ids = existing.map((p) => p.id).toSet();
        await _cache.save(
          [...existing, ...posts.where((p) => !ids.contains(p.id))],
          userId: userId,
        );
      }
    } catch (e) {
      // Сбой кэша не должен ломать успешный ответ сервера.
      developer.log('Cache write failed: $e', name: 'PostRepository');
    }
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e, s) {
      developer.log('Request failed',
          name: 'PostRepository', error: e, stackTrace: s);
      throw AppException.from(e);
    }
  }
}
