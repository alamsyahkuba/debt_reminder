final class AdminMutationItemResult {
  const AdminMutationItemResult({
    required this.id,
    required this.version,
    required this.serverUpdatedAt,
  });

  final String id;
  final int version;
  final DateTime serverUpdatedAt;
}

final class AdminMutationResult {
  const AdminMutationResult._({
    required this.status,
    this.version,
    this.serverUpdatedAt,
    this.serverRow,
    this.message,
    this.items = const <AdminMutationItemResult>[],
  });

  factory AdminMutationResult.applied({
    int? version,
    DateTime? serverUpdatedAt,
    List<AdminMutationItemResult> items = const <AdminMutationItemResult>[],
  }) {
    return AdminMutationResult._(
      status: AdminMutationStatus.applied,
      version: version,
      serverUpdatedAt: serverUpdatedAt,
      items: items,
    );
  }

  factory AdminMutationResult.conflict({
    required int serverVersion,
    required DateTime serverUpdatedAt,
    required Map<String, Object?> serverRow,
    String? message,
  }) {
    return AdminMutationResult._(
      status: AdminMutationStatus.conflict,
      version: serverVersion,
      serverUpdatedAt: serverUpdatedAt,
      serverRow: serverRow,
      message: message,
    );
  }

  factory AdminMutationResult.notFound({String? message}) {
    return AdminMutationResult._(
      status: AdminMutationStatus.notFound,
      message: message,
    );
  }

  final AdminMutationStatus status;
  final int? version;
  final DateTime? serverUpdatedAt;
  final Map<String, Object?>? serverRow;
  final String? message;
  final List<AdminMutationItemResult> items;

  Map<String, Object?> toConflictData() {
    return <String, Object?>{
      'status': 'conflict',
      'server_version': version,
      'server_updated_at': serverUpdatedAt?.toUtc().toIso8601String(),
      'server_row': serverRow,
      'message': message,
    };
  }
}

enum AdminMutationStatus { applied, conflict, notFound }
