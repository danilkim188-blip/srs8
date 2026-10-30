import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/comment.dart';
import '../models/create_post_request.dart';
import '../models/post.dart';
import '../models/user.dart';

part 'post_api.g.dart';

/// Retrofit-описание всех запросов к JSONPlaceholder.
@RestApi()
abstract class PostApi {
  factory PostApi(Dio dio, {String? baseUrl}) = _PostApi;

  // 1. Список постов с пагинацией (+ опциональный фильтр по автору).
  @GET('/posts')
  Future<List<Post>> getPosts({
    @Query('_page') int? page,
    @Query('_limit') int? limit,
    @Query('userId') int? userId,
  });

  // 2. Детали поста.
  @GET('/posts/{id}')
  Future<Post> getPost(@Path('id') int id);

  // 3. Все посты конкретного пользователя.
  @GET('/posts')
  Future<List<Post>> getPostsByUser(@Query('userId') int userId);

  // 4. Комментарии к посту.
  @GET('/posts/{id}/comments')
  Future<List<Comment>> getComments(@Path('id') int postId);

  // 5. Создание поста.
  @POST('/posts')
  Future<Post> createPost(@Body() CreatePostRequest body);

  // Дополнительно: авторы.
  @GET('/users')
  Future<List<User>> getUsers();

  @GET('/users/{id}')
  Future<User> getUser(@Path('id') int id);
}
