import '../app_database.dart';

/// Device-local app settings that are never synced to the server.
class LocalSettingsDao {
  LocalSettingsDao(this._db);

  final AppDatabase _db;

  Future<String?> getValue(String key) async {
    final row = await (_db.select(
      _db.localSettings,
    )..where((table) => table.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue({
    required String key,
    required String value,
    required DateTime updatedAt,
  }) async {
    await _db
        .into(_db.localSettings)
        .insertOnConflictUpdate(
          LocalSettingRow(key: key, value: value, updatedAt: updatedAt.toUtc()),
        );
  }

  Stream<String?> watchValue(String key) {
    return (_db.select(_db.localSettings)
          ..where((table) => table.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<void> delete(String key) async {
    await (_db.delete(
      _db.localSettings,
    )..where((table) => table.key.equals(key))).go();
  }

  Future<void> clear() async {
    await _db.delete(_db.localSettings).go();
  }
}
