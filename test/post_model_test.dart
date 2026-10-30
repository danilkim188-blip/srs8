import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';

void main() {
  group('JSON', () {
    test('1. JSON -> Post', () {
      final post = Post.fromJson({
        'userId': 1,
        'id': 7,
        'title': 'Hello',
        'body': 'World body',
      });
      expect(post.id, 7);
      expect(post.userId, 1);
      expect(post.title, 'Hello');
      expect(post.body, 'World body');
      expect(post.isLocal, false); // поля нет в ответе сервера
    });

    test('2. Post -> JSON', () {
      const post = Post(id: 3, userId: 2, title: 'T', body: 'B', isLocal: true);
      expect(post.toJson(), {
        'id': 3,
        'userId': 2,
        'title': 'T',
        'body': 'B',
        'isLocal': true,
      });
    });

    test('вложенные модели User и nullable-поля', () {
      final user = User.fromJson({
        'id': 1,
        'name': 'Leanne',
        'username': 'Bret',
        'email': 'a@b.c',
        'company': {'name': 'Romaguera'},
      });
      expect(user.company?.name, 'Romaguera');
      expect(user.company?.bs, isNull);
      expect(user.phone, isNull);
      expect(user.toJson()['company'], isA<Map<String, dynamic>>());
    });
  });
}
