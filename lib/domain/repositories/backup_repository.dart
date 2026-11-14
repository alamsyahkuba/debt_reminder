import '../entities/backup_document.dart';

abstract interface class BackupRepository {
  /// Builds a business-only backup from the local database.
  Future<BackupDocument> exportBackup();

  /// Validates references and counts records that would be added.
  Future<BackupRestorePreview> previewRestore(BackupDocument document);

  /// Adds records missing by ID. Existing rows are never overwritten or
  /// deleted. Added rows are queued in the outbox for admin-authorized sync.
  Future<BackupRestoreResult> restore(BackupDocument document);
}
