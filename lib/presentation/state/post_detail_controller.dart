import '../../core/error/app_exception.dart';
import '../../data/models/comment.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../data/repositories/post_repository.dart';
import 'safe_notifier.dart';

/// У экрана деталей три независимых запроса — у каждого своё состояние.
class PostDetailController extends SafeChangeNotifier {
  PostDetailController(this._repo, this.post);

  final PostRepository _repo;
  Post post;

  AsyncValue<List<Comment>> comments = const AsyncValue.loading();
  AsyncValue<User> author = const AsyncValue.loading();
  AsyncValue<int> authorPostsCount = const AsyncValue.loading();

  Future<void> load() => Future.wait([
        _refreshPost(),
        _loadComments(),
        _loadAuthor(),
      ]);

  Future<AsyncValue<T>> _run<T>(Future<T> Function() f) async {
    try {
      return AsyncValue.data(await f());
    } on AppException catch (e) {
      return AsyncValue.error(e);
    }
  }

  Future<void> _refreshPost() async {
    if (post.isLocal) return; // на сервере такого поста нет
    final result = await _run(() => _repo.getPost(post.id));
    if (result.data != null) {
      post = result.data!; // при ошибке остаётся пост из списка
      notifyListeners();
    }
  }

  Future<void> _loadComments() async {
    if (post.isLocal) {
      comments = const AsyncValue.data([]);
    } else {
      comments = await _run(() => _repo.getComments(post.id));
    }
    notifyListeners();
  }

  Future<void> _loadAuthor() async {
    final results = await Future.wait([
      _run(() => _repo.getUser(post.userId)),
      _run(() async => (await _repo.getPostsByUser(post.userId)).length),
    ]);
    author = results[0] as AsyncValue<User>;
    authorPostsCount = results[1] as AsyncValue<int>;
    notifyListeners();
  }
}
