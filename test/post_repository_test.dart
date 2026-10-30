import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/models/create_post_request.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/remote/post_api.dart';
import 'package:post_explorer/data/repositories/post_filter.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPostApi extends Mock implements PostApi {}

List<Post> makePosts(int count, {int start = 1, int userId = 1}) => [
      for (var i = start; i < start + count; i++)
        Post(id: i, userId: userId, title: 'title $i', body: 'body $i'),
    ];

DioException httpError(int code) {
  final req = RequestOptions(path: '/posts');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: code),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  late MockPostApi api;
  late PostCache cache;
  late PostRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = PostCache(await SharedPreferences.getInstance());
    api = MockPostApi();
    repo = PostRepository(api: api, cache: cache);
  });

  test('3. успешная загрузка постов через репозиторий (+ запись в кэш)',
      () async {
    final posts = makePosts(10);
    when(() => api.getPosts(
          page: 1,
          limit: 10,
          userId: any(named: 'userId'),
        )).thenAnswer((_) async => posts);

    final result = await repo.fetchPosts(page: 1);

    expect(result, posts);
    expect(repo.cachedPosts()!.length, 10);
  });

  test('4. ошибка сервера 500 -> AppException(server), кэш не стирается',
      () async {
    await cache.save(makePosts(3));
    when(() => api.getPosts(
          page: 1,
          limit: 10,
          userId: any(named: 'userId'),
        )).thenThrow(httpError(500));

    await expectLater(
      repo.fetchPosts(page: 1),
      throwsA(isA<AppException>()
          .having((e) => e.type, 'type', AppErrorType.server)),
    );
    expect(repo.cachedPosts()!.length, 3);
  });

  test('5. фильтрация по автору и заголовку', () {
    final posts = [
      const Post(id: 1, userId: 1, title: 'Sunt aut facere', body: 'x'),
      const Post(id: 2, userId: 2, title: 'qui est esse', body: 'x'),
      const Post(id: 3, userId: 2, title: 'Sunt qui', body: 'x'),
    ];
    expect(PostFilter.apply(posts, userId: 2).map((p) => p.id), [2, 3]);
    expect(PostFilter.apply(posts, query: 'sunt').map((p) => p.id), [1, 3]);
    expect(
      PostFilter.apply(posts, query: 'sunt', userId: 2).map((p) => p.id),
      [3],
    );
    expect(PostFilter.apply(posts, ascending: false).map((p) => p.id),
        [3, 2, 1]);
  });

  test('POST через mock-адаптер Dio (без реального интернета)', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));
    final adapter = DioAdapter(dio: dio);
    const body = {'title': 'Hello world', 'body': 'Long enough body', 'userId': 1};
    adapter.onPost(
      '/posts',
      (server) => server.reply(201, {'id': 101, ...body}),
      data: body,
    );
    final realRepo = PostRepository(api: PostApi(dio), cache: cache);

    final created = await realRepo.createPost(const CreatePostRequest(
      title: 'Hello world',
      body: 'Long enough body',
      userId: 1,
    ));

    expect(created.id, 101);
    expect(created.title, 'Hello world');
  });

  test('некорректный JSON (нет обязательного поля) -> AppException(parsing)',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet(
      '/posts',
      (server) => server.reply(200, [
        {'id': 1} // нет userId, title, body
      ]),
      queryParameters: {'_page': 1, '_limit': 10},
    );
    final realRepo = PostRepository(api: PostApi(dio), cache: cache);

    await expectLater(
      realRepo.fetchPosts(page: 1),
      throwsA(isA<AppException>()
          .having((e) => e.type, 'type', AppErrorType.parsing)),
    );
  });
}
