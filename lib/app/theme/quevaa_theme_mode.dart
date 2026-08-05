import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../features/cycle/application/cycle_workspace_provider.dart';

enum QuevaaThemeMode {
  system,
  light,
  dark;

  ThemeMode get materialMode {
    return switch (this) {
      QuevaaThemeMode.system => ThemeMode.system,
      QuevaaThemeMode.light => ThemeMode.light,
      QuevaaThemeMode.dark => ThemeMode.dark,
    };
  }

  String get label {
    return switch (this) {
      QuevaaThemeMode.system => 'Follow system',
      QuevaaThemeMode.light => 'Light',
      QuevaaThemeMode.dark => 'Dark',
    };
  }

  String get description {
    return switch (this) {
      QuevaaThemeMode.system => 'Match your phone or tablet setting.',
      QuevaaThemeMode.light => 'Warm cream surfaces with terracotta actions.',
      QuevaaThemeMode.dark => 'Deep plum surfaces with softer contrast.',
    };
  }

  static QuevaaThemeMode fromStorage(String value) {
    return switch (value.toLowerCase()) {
      'light' => QuevaaThemeMode.light,
      'dark' => QuevaaThemeMode.dark,
      _ => QuevaaThemeMode.system,
    };
  }
}

final quevaaThemeModeProvider = StreamProvider<QuevaaThemeMode>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.appSettings)..limit(1)).watchSingleOrNull().map(
    (settings) => QuevaaThemeMode.fromStorage(settings?.themeMode ?? 'system'),
  );
});

final quevaaThemeControllerProvider =
    NotifierProvider<QuevaaThemeController, bool>(QuevaaThemeController.new);

class QuevaaThemeController extends Notifier<bool> {
  @override
  bool build() => false;

  AppDatabase get _db => ref.read(appDatabaseProvider);

  Future<void> setMode(QuevaaThemeMode mode) async {
    if (state) return;
    state = true;
    try {
      final now = DateTime.now();
      final existing = await (_db.select(
        _db.appSettings,
      )..limit(1)).getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.appSettings)
            .insert(
              AppSettingsCompanion.insert(
                uuid: localUuid('settings'),
                createdAt: now,
                updatedAt: now,
                themeMode: Value(mode.name),
              ),
            );
      } else {
        await (_db.update(
          _db.appSettings,
        )..where((tbl) => tbl.id.equals(existing.id))).write(
          AppSettingsCompanion(
            themeMode: Value(mode.name),
            updatedAt: Value(now),
          ),
        );
      }
    } finally {
      state = false;
    }
  }
}
