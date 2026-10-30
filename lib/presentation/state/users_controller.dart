import '../../core/error/app_exception.dart';
import '../../data/models/user.dart';
import '../../data/repositories/post_repository.dart';
import 'safe_notifier.dart';

/// Список авторов — для фильтра и формы создания.
class UsersController extends SafeChangeNotifier {
  UsersController(this._repo);

  final PostRepository _repo;

  List<User> _users = [];
  bool _loading = true;
  AppException? _error;

  bool get loading => _loading;
  AppException? get error => _error;
  List<User> get users => _users;

  /// id -> подпись. Если авторы не загрузились, используем запасной список.
  Map<int, String> get labels {
    if (_users.isNotEmpty) {
      return {for (final u in _users) u.id: u.name};
    }
    return {for (var i = 1; i <= 10; i++) i: 'Автор #$i'};
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _users = await _repo.getUsers();
    } on AppException catch (e) {
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }
}
