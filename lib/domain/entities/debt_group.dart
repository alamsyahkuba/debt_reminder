import 'sync_state.dart';

const Set<String> allowedDebtGroupIcons = <String>{
  'folder',
  'home',
  'work',
  'shopping_bag',
  'directions_car',
  'school',
  'health_and_safety',
  'receipt',
  'savings',
  'handshake',
  'family',
  'business_center',
};

final class DebtGroup {
  const DebtGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.sortOrder,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.syncState,
  });

  final String id;
  final String name;
  final String? description;
  final String? color;
  final String? icon;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final SyncState syncState;
}
