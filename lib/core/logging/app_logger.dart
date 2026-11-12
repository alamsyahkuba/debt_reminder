import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logger tipis yang hanya aktif pada debug build.
///
/// Jangan pernah menulis PIN, token, kunci rahasia, atau data hutang sensitif
/// ke log.
final class AppLogger {
  const AppLogger(this.scope);

  final String scope;

  void debug(String message) => _log('DEBUG', message);

  void info(String message) => _log('INFO', message);

  void warning(String message) => _log('WARN', message);

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log('ERROR', message, error: error, stackTrace: stackTrace);
  }

  void _log(
    String level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) {
      return;
    }

    developer.log(
      message,
      name: '$scope/$level',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
