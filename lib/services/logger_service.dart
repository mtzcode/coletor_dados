import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

class LoggerService {
  LoggerService._();

  static bool _debugEnabled = !kReleaseMode;

  /// Habilita ou desabilita logs de debug (útil para troubleshooting em release)
  static void enableDebug(bool enabled) {
    _debugEnabled = enabled;
  }

  static void d(String message) {
    if (_debugEnabled) _print('DEBUG', message);
  }

  static void i(String message) {
    _print('INFO', message);
  }

  static void w(String message) {
    _print('WARN', message);
  }

  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer(message);
    if (error != null) buffer.write(' | error: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');
    _print('ERROR', buffer.toString());
  }

  static void _print(String level, String message) {
    debugPrint('[$level] $message');
  }
}
