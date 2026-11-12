import 'sync_state.dart';

final class Debt {
  const Debt({
    required this.id,
    required this.groupId,
    required this.title,
    required this.principalAmount,
    required this.dueDate,
    required this.notes,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.syncState,
  });

  final String id;
  final String? groupId;
  final String title;
  final int principalAmount;
  final DateTime? dueDate;
  final String? notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final SyncState syncState;
}
