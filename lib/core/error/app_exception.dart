import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';


enum AppErrorType { noConnection, timeout, client, server, parsing, unknown }


class AppException implements Exception {
  const AppException(this.type, {this.statusCode, this.technical});

  final AppErrorType type;
  final int? statusCode;
  final String? technical;

  String get userMessage {
    switch (type) {
      case AppErrorType.noConnection:
        return 'Нет соединения с интернетом. Проверьте подключение.';
      case AppErrorType.timeout:
        return 'Сервер слишком долго отвечает. Попробуйте ещё раз.';
      case AppErrorType.client:
        return statusCode == 404
            ? 'Данные не найдены (404).'
            : 'Запрос отклонён сервером (код ${statusCode ?? '4xx'}).';
      case AppErrorType.server:
        return 'Ошибка на стороне сервера (код ${statusCode ?? '5xx'}). '
            'Попробуйте позже.';
      case AppErrorType.parsing:
        return 'Сервер вернул данные в неожиданном формате.';
      case AppErrorType.unknown:
        return 'Произошла неизвестная ошибка.';
    }
  }

  /// Преобразует любое исключение в [AppException].
  factory AppException.from(Object error) {
    if (error is AppException) return error;

    if (error is DioException) {
      if (error.error is AppException) return error.error as AppException;
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return AppException(AppErrorType.timeout, technical: error.message);
        case DioExceptionType.connectionError:
          return AppException(AppErrorType.noConnection,
              technical: error.message);
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          if (code >= 500) {
            return AppException(AppErrorType.server,
                statusCode: code, technical: error.message);
          }
          if (code >= 400) {
            return AppException(AppErrorType.client,
                statusCode: code, technical: error.message);
          }
          return AppException(AppErrorType.unknown,
              statusCode: code, technical: error.message);
        case DioExceptionType.cancel:
          return const AppException(AppErrorType.unknown,
              technical: 'cancelled');
        case DioExceptionType.badCertificate:
          return const AppException(AppErrorType.unknown,
              technical: 'bad certificate');
        case DioExceptionType.unknown:
          final inner = error.error;
          if (inner is SocketException) {
            return AppException(AppErrorType.noConnection,
                technical: inner.message);
          }
          if (inner is TypeError || inner is FormatException) {
            return AppException(AppErrorType.parsing,
                technical: inner.toString());
          }
          return AppException(AppErrorType.unknown,
              technical: error.message ?? inner?.toString());
      }
    }

    if (error is SocketException) {
      return AppException(AppErrorType.noConnection, technical: error.message);
    }
    if (error is TimeoutException) {
      return AppException(AppErrorType.timeout, technical: error.message);
    }
    
    if (error is TypeError || error is FormatException) {
      return AppException(AppErrorType.parsing, technical: error.toString());
    }
    return AppException(AppErrorType.unknown, technical: error.toString());
  }

  @override
  String toString() =>
      'AppException($type, status: $statusCode, technical: $technical)';
}