import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../error/app_exception.dart';


class ApiInterceptor extends Interceptor {
  int _counter = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Client'] = 'post-explorer-flutter';
    options.headers['X-Request-Id'] =
        '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appError = AppException.from(err);
    // Технические подробности — только в лог разработки.
    developer.log(
      '${err.requestOptions.method} ${err.requestOptions.uri} -> $appError',
      name: 'ApiInterceptor',
    );
    handler.next(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: appError,
      stackTrace: err.stackTrace,
      message: err.message,
    ));
  }
}
