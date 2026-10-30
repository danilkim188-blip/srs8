import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/presentation/state/post_list_controller.dart';

class MockPostRepository extends Mock implements PostRepository {}

List<Post> makePosts(int count, {int start = 1, int userId = 1}) => [
      for (var i = start; i < start + count; i++)
        Post(id: i, userId: userId, title: 'title $i', body: 'body $i'),
    ];

void main() {
  late MockPostRepository repo;

  setUp(() {
    repo = MockPostRepository();
    when(() => repo.localPosts(userId: any(named: 'userId'))).thenReturn([]);
    when(() => repo.cachedPosts(userId: any(named: 'userId'))).thenReturn(null);
    when(() => repo.fetchPosts(page: 1, userId: any(named: 'userId')))
        .thenAnswer((_) async => makePosts(10));
  });

  test('6. защита от дублирующейся загрузки страницы', () async {
    final page2 = Completer<List<Post>>();
    when(() => repo.fetchPosts(page: 2, userId: any(named: 'userId')))
        .thenAnswer((_) => page2.future);

    final c = PostListController(repo);
    await c.load();
    expect(c.status, ListStatus.success);

    // Два "быстрых" вызова подряд (например, два события прокрутки).
    final first = c.loadNextPage();
    final second = c.loadNextPage();
    page2.complete(makePosts(10, start: 11));
    await Future.wait([first, second]);

    verify(() => repo.fetchPosts(page: 2, userId: any(named: 'userId')))
        .called(1);
    expect(c.visibleItems.length, 20);
    expect(c.visibleItems.map((p) => p.id).toSet().length, 20); // без дублей
  });

  test('ошибка следующей страницы не стирает список и даёт retry', () async {
    var fail = true;
    when(() => repo.fetchPosts(page: 2, userId: any(named: 'userId')))
        .thenAnswer((_) async {
      if (fail) throw const AppException(AppErrorType.timeout);
      return makePosts(10, start: 11);
    });

    final c = PostListController(repo);
    await c.load();
    await c.loadNextPage();
    expect(c.pageStatus, PageStatus.error);
    expect(c.visibleItems.length, 10);

    fail = false;
    await c.retryNextPage();
    expect(c.pageStatus, PageStatus.idle);
    expect(c.visibleItems.length, 20);
  });

  test('смена фильтра сбрасывает страницы и не смешивает результаты', () async {
    when(() => repo.fetchPosts(page: 1, userId: 2))
        .thenAnswer((_) async => makePosts(3, start: 100, userId: 2));

    final c = PostListController(repo);
    await c.load();
    await c.setUserFilter(2);

    expect(c.visibleItems.map((p) => p.id), [100, 101, 102]);
    expect(c.visibleItems.every((p) => p.userId == 2), isTrue);
  });

  test('при сетевой ошибке остаются кэшированные данные', () async {
    when(() => repo.cachedPosts(userId: any(named: 'userId')))
        .thenReturn(makePosts(5));
    when(() => repo.fetchPosts(page: 1, userId: any(named: 'userId')))
        .thenThrow(const AppException(AppErrorType.noConnection));

    final c = PostListController(repo);
    await c.load();

    expect(c.status, ListStatus.success);
    expect(c.fromCache, isTrue);
    expect(c.visibleItems.length, 5);
    expect(c.error?.type, AppErrorType.noConnection);
  });
}
