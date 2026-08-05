import 'package:flutter/foundation.dart';
import '../../app/bootstrap/app_config.dart';

/// AppLogger handles application logging while strictly stripping/sanitizing any potential sensitive health data.
class AppLogger {
  AppLogger._();

  static void info(String message) {
    if (!AppConfig.instance.enableLogging) return;
    final sanitized = _sanitize(message);
    debugPrint('[QUEVAA INFO] $sanitized');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!AppConfig.instance.enableLogging) return;
    final sanitized = _sanitize(message);
    debugPrint('[QUEVAA ERROR] $sanitized');
    if (error != null) {
      debugPrint('[QUEVAA ERROR DETAILS] ${_sanitize(error.toString())}');
    }
  }

  /// Ensures sensitive parameters (flow, symptoms, period dates, notes) are sanitized from debug output.
  static String _sanitize(String text) {
    return text
        .replaceAll(
          RegExp(r'flow:\s*\d+', caseSensitive: false),
          'flow: [REDACTED]',
        )
        .replaceAll(
          RegExp(r'symptoms:\s*\[.*?\]', caseSensitive: false),
          'symptoms: [REDACTED]',
        )
        .replaceAll(
          RegExp(r'periodDate:\s*[\d\-]+', caseSensitive: false),
          'periodDate: [REDACTED]',
        )
        .replaceAll(
          RegExp(r'notes:\s*.*', caseSensitive: false),
          'notes: [REDACTED]',
        );
  }
}
