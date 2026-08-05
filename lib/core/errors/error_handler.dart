import 'package:flutter/material.dart';
import '../analytics/app_logger.dart';

abstract class AppFailure implements Exception {
  final String message;
  final String? code;

  const AppFailure(this.message, [this.code]);
}

class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.message, [super.code]);
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message, [super.code]);
}

class ErrorHandler {
  static void handleUncaughtError(Object error, StackTrace stackTrace) {
    AppLogger.error(
      'Uncaught application exception occurred',
      error,
      stackTrace,
    );
  }

  static Widget buildErrorWidget(FlutterErrorDetails details) {
    AppLogger.error(
      'Flutter Framework Error',
      details.exception,
      details.stack,
    );
    return const Material(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Something unexpected occurred.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Quevaa handled this error safely. Your private data remains secure.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
