import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quevaa/app/theme/quevaa_theme_mode.dart';
import 'package:quevaa/core/database/app_database.dart';
import 'package:quevaa/core/providers/database_provider.dart';

void main() {
  test('QuevaaThemeMode maps storage values and Material theme modes', () {
    expect(QuevaaThemeMode.fromStorage('system'), QuevaaThemeMode.system);
    expect(QuevaaThemeMode.fromStorage('light'), QuevaaThemeMode.light);
    expect(QuevaaThemeMode.fromStorage('dark'), QuevaaThemeMode.dark);
    expect(QuevaaThemeMode.fromStorage('unexpected'), QuevaaThemeMode.system);
    expect(QuevaaThemeMode.light.materialMode, ThemeMode.light);
    expect(QuevaaThemeMode.dark.materialMode, ThemeMode.dark);
    expect(QuevaaThemeMode.system.materialMode, ThemeMode.system);
  });

  test('Theme preference persists in local AppSettings', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    await container
        .read(quevaaThemeControllerProvider.notifier)
        .setMode(QuevaaThemeMode.dark);
    var settings = await db.select(db.appSettings).getSingle();
    expect(settings.themeMode, 'dark');

    await container
        .read(quevaaThemeControllerProvider.notifier)
        .setMode(QuevaaThemeMode.light);
    settings = await db.select(db.appSettings).getSingle();
    expect(settings.themeMode, 'light');
  });
}
