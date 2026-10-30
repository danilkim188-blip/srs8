import '../../core/error/app_exception.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_filter.dart';
import '../../data/repositories/post_repository.dart';
import 'safe_notifier.dart';

/// Состояние всего экрана списка.
enum ListStatus { loading, success, error, empty }

/// Состояние подгрузки следующей страницы (независимо от [ListStatus]).
enum PageStatus { idle, loading, error, ended }

class PostListController extends SafeChangeNotifier {
  PostListController(this._repo);

  final PostRepository _repo;

  List<Post> _loaded = []; // посты с сервера / из кэша
  List<Post> _local = []; // созданные локально
  ListStatus _status = ListStatus.loading;
  PageStatus _pageStatus = PageStatus.idle;
  bool _fromCache = false; // «Cached»: показаны сохранённые данные
  bool _refreshing = false; // идёт запрос первой страницы поверх данных
  AppException? _error;
  AppException? _pageError;

  int? _userId;
  String _query = '';
  bool _ascending = true;

  int _nextPage = 1;
  int _generation = 0; // меняется при смене фильтра/обновлении
  final Set<int> _requestedPages = {};

  // ---------- геттеры ----------
  ListStatus get status => _status;
  PageStatus get pageStatus => _pageStatus;
  bool get fromCache => _fromCache;
  bool get refreshing => _refreshing;
  AppException? get error => _error;
  AppException? get pageError => _pageError;
  int? get userId => _userId;
  String get query => _query;
  bool get ascending => _ascending;
  int get loadedCount => _loaded.length + _local.length;
  bool get hasFilters => _userId != null || _query.isNotEmpty || !_ascending;

  List<Post> get visibleItems => PostFilter.apply(
        [..._local, ..._loaded],
        query: _query,
        userId: _userId,
        ascending: _ascending,
      );

  // ---------- загрузка ----------

  /// Первичная загрузка / загрузка после смены фильтра.
  Future<void> load() async {
    final gen = ++_generation;
    _requestedPages.clear();
    _nextPage = 1;
    _pageStatus = PageStatus.idle;
    _error = null;
    _pageError = null;
    _local = _repo.localPosts(userId: _userId);

    final cached = _repo.cachedPosts(userId: _userId);
    if (cached != null && cached.isNotEmpty) {
      // Сначала показываем сохранённое, параллельно просим свежее.
      _loaded = cached;
      _fromCache = true;
      _status = ListStatus.success;
      _refreshing = true;
    } else {
      _loaded = [];
      _fromCache = false;
      _status = ListStatus.loading;
      _refreshing = false;
    }
    notifyListeners();
    await _fetchFirstPage(gen);
  }

  /// Pull-to-refresh: данные на экране не сбрасываются.
  Future<void> refresh() async {
    final gen = ++_generation;
    _requestedPages.clear();
    _pageStatus = PageStatus.idle;
    _pageError = null;
    _refreshing = true;
    notifyListeners();
    await _fetchFirstPage(gen);
  }

  Future<void> _fetchFirstPage(int gen) async {
    _requestedPages.add(1);
    try {
      final posts = await _repo.fetchPosts(page: 1, userId: _userId);
      if (gen != _generation) return; // устаревший ответ
      _loaded = posts;
      _fromCache = false;
      _refreshing = false;
      _error = null;
      _status = (posts.isEmpty && _local.isEmpty)
          ? ListStatus.empty
          : ListStatus.success;
      _nextPage = 2;
      _pageStatus = posts.length < PostRepository.pageSize
          ? PageStatus.ended
          : PageStatus.idle;
    } on AppException catch (e) {
      if (gen != _generation) return;
      _error = e;
      _refreshing = false;
      _requestedPages.remove(1);
      if (_loaded.isNotEmpty || _local.isNotEmpty) {
        // Последний успешный результат не удаляем.
        _status = ListStatus.success;
        _fromCache = true;
        // Если ни одна страница с сервера не приходила, листать нечего.
        if (_nextPage == 1) _pageStatus = PageStatus.ended;
      } else {
        _status = ListStatus.error;
      }
    }
    notifyListeners();
  }

  /// Подгрузка следующей страницы. Защищена от дублей.
  Future<void> loadNextPage() async {
    if (_status != ListStatus.success || _refreshing) return;
    if (_pageStatus != PageStatus.idle) return; // loading / error / ended
    final page = _nextPage;
    if (!_requestedPages.add(page)) return; // эта страница уже запрошена

    final gen = _generation;
    _pageStatus = PageStatus.loading;
    _pageError = null;
    notifyListeners();

    try {
      final posts = await _repo.fetchPosts(page: page, userId: _userId);
      if (gen != _generation) return;
      final known = _loaded.map((p) => p.id).toSet();
      _loaded = [..._loaded, ...posts.where((p) => !known.contains(p.id))];
      _nextPage = page + 1;
      _pageStatus = posts.length < PostRepository.pageSize
          ? PageStatus.ended
          : PageStatus.idle;
    } on AppException catch (e) {
      if (gen != _generation) return;
      _requestedPages.remove(page); // чтобы можно было повторить
      _pageError = e;
      _pageStatus = PageStatus.error;
    }
    notifyListeners();
  }

  /// Кнопка «Повторить» под списком.
  Future<void> retryNextPage() {
    if (_pageStatus == PageStatus.error) {
      _pageStatus = PageStatus.idle;
    }
    return loadNextPage();
  }

  // ---------- фильтры ----------

  Future<void> setUserFilter(int? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    await load(); // страницы сбрасываются, старые данные не смешиваются
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  void toggleSort() {
    _ascending = !_ascending;
    notifyListeners();
  }

  Future<void> resetFilters() async {
    final needReload = _userId != null;
    _query = '';
    _ascending = true;
    _userId = null;
    if (needReload) {
      await load();
    } else {
      notifyListeners();
    }
  }

  // ---------- локальное создание ----------

  Future<void> addLocalPost(Post serverPost) async {
    await _repo.addLocalPost(serverPost);
    _local = _repo.localPosts(userId: _userId);
    if (_status == ListStatus.empty) _status = ListStatus.success;
    notifyListeners();
  }
}
