import '../models/post.dart';

/// Чистая функция фильтрации/сортировки — легко тестируется.
/// Работает только по уже загруженным постам.
class PostFilter {
  static List<Post> apply(
    List<Post> posts, {
    String query = '',
    int? userId,
    bool ascending = true,
  }) {
    final q = query.trim().toLowerCase();
    final result = posts.where((p) {
      if (userId != null && p.userId != userId) return false;
      if (q.isNotEmpty && !p.title.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    result.sort((a, b) => ascending ? a.id.compareTo(b.id) : b.id.compareTo(a.id));
    return result;
  }
}
