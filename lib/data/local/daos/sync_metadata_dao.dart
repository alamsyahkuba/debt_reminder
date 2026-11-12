import '../app_database.dart';

class SyncMetadataDao {
  SyncMetadataDao(this._db);

  final AppDatabase _db;

  Future<String?> getValue(String key) async {
    final row = await (_db.select(
      _db.syncMetadata,
    )..where((table) => table.key.equals(key))).getSingleOrNull();

    return row?.value;
  }

  Future<void> setValue({
    required String key,
    required String value,
    required DateTime updatedAt,
  }) async {
    await _db
        .into(_db.syncMetadata)
        .insertOnConflictUpdate(
          SyncMetadataRow(key: key, value: value, updatedAt: updatedAt),
        );
  }
}
