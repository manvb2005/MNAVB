import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLogLevel { info, warning, error }

class AppMonitoringService {
  AppMonitoringService._();

  static final AppMonitoringService instance = AppMonitoringService._();

  static const _logsKey = 'app_monitor_recent_logs';
  static const _maxLogs = 250;

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
    }

    _isInitialized = true;
    logInfo('Monitoreo inicializado', tag: 'MONITOR', persist: false);
  }

  void logInfo(String message, {String tag = 'APP', bool persist = false}) {
    _log(AppLogLevel.info, tag, message, persist: persist);
  }

  void logWarning(String message, {String tag = 'APP', bool persist = true}) {
    _log(AppLogLevel.warning, tag, message, persist: persist);
  }

  Future<void> logError(
    String message, {
    String tag = 'APP',
    Object? error,
    StackTrace? stackTrace,
    bool persist = true,
  }) async {
    final extras = <String>[];
    if (error != null) {
      extras.add('error=$error');
    }
    if (stackTrace != null) {
      final lines = stackTrace.toString().split('\n');
      if (lines.isNotEmpty) {
        extras.add('stack=${lines.first}');
      }
    }

    final text = extras.isEmpty ? message : '$message | ${extras.join(' | ')}';
    await _log(AppLogLevel.error, tag, text, persist: persist);
  }

  Future<void> captureException(
    Object error,
    StackTrace stackTrace, {
    String tag = 'APP',
  }) {
    return logError(
      'Excepcion no controlada',
      tag: tag,
      error: error,
      stackTrace: stackTrace,
      persist: true,
    );
  }

  List<String> getRecentLogs() {
    return _prefs?.getStringList(_logsKey) ?? const [];
  }

  Future<void> clearLogs() async {
    try {
      await _prefs?.remove(_logsKey);
    } catch (_) {}
  }

  Future<void> _log(
    AppLogLevel level,
    String tag,
    String message, {
    required bool persist,
  }) async {
    final now = DateTime.now().toIso8601String();
    final levelText = switch (level) {
      AppLogLevel.info => 'INFO',
      AppLogLevel.warning => 'WARN',
      AppLogLevel.error => 'ERROR',
    };
    final line = '[$now][$levelText][$tag] $message';

    debugPrint(line);

    if (!persist) return;
    if (!_isInitialized) {
      await init();
    }

    final prefs = _prefs;
    if (prefs == null) return;

    try {
      final current = prefs.getStringList(_logsKey) ?? <String>[];
      current.add(line);
      if (current.length > _maxLogs) {
        current.removeRange(0, current.length - _maxLogs);
      }
      await prefs.setStringList(_logsKey, current);
    } catch (_) {}
  }
}
