import 'package:flutter/foundation.dart';

/// ChangeNotifier, безопасный к ответам, пришедшим после dispose().
class SafeChangeNotifier extends ChangeNotifier {
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}

/// Состояние одной независимой асинхронной операции.
class AsyncValue<T> {
  const AsyncValue.loading()
      : loading = true,
        data = null,
        error = null;
  const AsyncValue.data(T value)
      : loading = false,
        data = value,
        error = null;
  const AsyncValue.error(Object this.error)
      : loading = false,
        data = null;

  final bool loading;
  final T? data;
  final Object? error;
}
