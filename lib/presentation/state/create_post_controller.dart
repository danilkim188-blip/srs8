import '../../core/error/app_exception.dart';
import '../../data/models/create_post_request.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import 'safe_notifier.dart';

enum SubmitStatus { idle, submitting, success, failure }

class PostValidators {
  static String? title(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Введите заголовок';
    if (t.length < 5) return 'Минимум 5 символов';
    if (t.length > 100) return 'Максимум 100 символов';
    return null;
  }

  static String? body(String? value) {
    final t = value?.trim() ?? '';
    if (t.isEmpty) return 'Введите текст поста';
    if (t.length < 10) return 'Минимум 10 символов';
    if (t.length > 1000) return 'Максимум 1000 символов';
    return null;
  }

  static String? user(int? value) => value == null ? 'Выберите автора' : null;
}

/// Состояние отправки формы — отдельно от состояния списка.
class CreatePostController extends SafeChangeNotifier {
  CreatePostController(this._repo);

  final PostRepository _repo;

  SubmitStatus _status = SubmitStatus.idle;
  Post? _serverPost;
  AppException? _error;

  SubmitStatus get status => _status;
  bool get submitting => _status == SubmitStatus.submitting;
  Post? get serverPost => _serverPost;
  AppException? get error => _error;

  /// Возвращает объект сервера или null при ошибке / повторном нажатии.
  Future<Post?> submit({
    required String title,
    required String body,
    required int userId,
  }) async {
    if (submitting) return null; // защита от двойной отправки
    _status = SubmitStatus.submitting;
    _error = null;
    notifyListeners();
    try {
      final post = await _repo.createPost(CreatePostRequest(
        title: title.trim(),
        body: body.trim(),
        userId: userId,
      ));
      _serverPost = post;
      _status = SubmitStatus.success;
      notifyListeners();
      return post;
    } on AppException catch (e) {
      _error = e;
      _status = SubmitStatus.failure;
      notifyListeners();
      return null;
    }
  }
}
