import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.userProfiles)..limit(1)).watchSingleOrNull();
});
