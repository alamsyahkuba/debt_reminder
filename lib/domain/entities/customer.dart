import 'sync_state.dart';

final class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.notes,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.syncState,
  });

  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final SyncState syncState;
}
