import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, prod }

class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final bool enableLogging;
  final bool isOfflineOnly;

  const AppConfig({
    required this.environment,
    this.appName = 'Quevaa',
    this.enableLogging = true,
    this.isOfflineOnly = true,
  });

  static AppConfig? _instance;

  static AppConfig get instance {
    _instance ??= const AppConfig(
      environment: AppEnvironment.dev,
      enableLogging: true,
      isOfflineOnly: true,
    );
    return _instance!;
  }

  static void initialize(AppEnvironment env) {
    _instance = AppConfig(
      environment: env,
      enableLogging: env == AppEnvironment.dev,
      isOfflineOnly: true,
    );
  }

  /// Auto-detect environment from build mode. Call from main.dart.
  static void initializeFromPlatform() {
    _instance = const AppConfig(
      environment: kReleaseMode ? AppEnvironment.prod : AppEnvironment.dev,
      enableLogging: !kReleaseMode,
      isOfflineOnly: true,
    );
  }

  bool get isProduction => environment == AppEnvironment.prod;
}
