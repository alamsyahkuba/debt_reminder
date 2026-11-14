import 'dart:convert';

import '../../core/errors/app_exception.dart';
import '../validation/entity_validation.dart';

/// Business-only backup document. Internal metadata must never be added here.
final class BackupDocument {
  const BackupDocument({
    required this.exportedAt,
    required this.groups,
    required this.debts,
    required this.payments,
  });

  static const int currentSchemaVersion = 1;

  final DateTime exportedAt;
  final List<BackupDebtGroup> groups;
  final List<BackupDebt> debts;
  final List<BackupPayment> payments;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema_version': currentSchemaVersion,
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'debt_groups': groups.map((group) => group.toJson()).toList(),
      'debts': debts.map((debt) => debt.toJson()).toList(),
      'payments': payments.map((payment) => payment.toJson()).toList(),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory BackupDocument.fromJsonString(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw _invalid('File bukan JSON yang valid.');
    }

    if (decoded is! Map) {
      throw _invalid('Struktur backup harus berupa objek JSON.');
    }

    return BackupDocument.fromJson(
      decoded.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }

  factory BackupDocument.fromJson(Map<String, Object?> json) {
    final schemaVersion = _requireInt(json['schema_version'], 'schema_version');
    if (schemaVersion != currentSchemaVersion) {
      throw _invalid(
        'Versi backup $schemaVersion tidak didukung. '
        'Versi yang didukung: $currentSchemaVersion.',
      );
    }

    final exportedAt = _requireTimestamp(json['exported_at'], 'exported_at');
    final groups = _parseList(
      json['debt_groups'],
      'debt_groups',
      BackupDebtGroup.fromJson,
    );
    final debts = _parseList(json['debts'], 'debts', BackupDebt.fromJson);
    final payments = _parseList(
      json['payments'],
      'payments',
      BackupPayment.fromJson,
    );

    _ensureUniqueIds(groups.map((group) => group.id), 'debt_groups');
    _ensureUniqueIds(debts.map((debt) => debt.id), 'debts');
    _ensureUniqueIds(payments.map((payment) => payment.id), 'payments');

    return BackupDocument(
      exportedAt: exportedAt,
      groups: groups,
      debts: debts,
      payments: payments,
    );
  }
}

final class BackupDebtGroup {
  const BackupDebtGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.sortOrder,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
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

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'sort_order': sortOrder,
      'is_archived': isArchived,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory BackupDebtGroup.fromJson(Map<String, Object?> json) {
    final createdAt = _requireTimestamp(json['created_at'], 'created_at');
    final updatedAt = _requireTimestamp(json['updated_at'], 'updated_at');
    _ensureTimestampOrder(createdAt, updatedAt);

    final icon = validateDebtGroupIcon(_optionalString(json['icon'], 'icon'));

    return BackupDebtGroup(
      id: _requireUuid(json['id'], 'id'),
      name: validateText(
        _requireString(json['name'], 'name'),
        field: 'Nama group',
        maxLength: 100,
      ),
      description: validateOptionalText(
        _optionalString(json['description'], 'description'),
        field: 'Deskripsi group',
        maxLength: 1000,
      ),
      color: validateHexColor(_optionalString(json['color'], 'color')),
      icon: icon,
      sortOrder: validateSortOrder(
        _requireInt(json['sort_order'], 'sort_order'),
      ),
      isArchived: _requireBool(json['is_archived'], 'is_archived'),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

final class BackupDebt {
  const BackupDebt({
    required this.id,
    required this.groupId,
    required this.title,
    required this.principalAmount,
    required this.dueDate,
    required this.notes,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
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

  Map<String, Object?> toJson() {
    final due = dueDate;
    return <String, Object?>{
      'id': id,
      'group_id': groupId,
      'title': title,
      'principal_amount': principalAmount,
      'due_date': due == null ? null : _dateOnly(due),
      'notes': notes,
      'is_archived': isArchived,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory BackupDebt.fromJson(Map<String, Object?> json) {
    final createdAt = _requireTimestamp(json['created_at'], 'created_at');
    final updatedAt = _requireTimestamp(json['updated_at'], 'updated_at');
    _ensureTimestampOrder(createdAt, updatedAt);

    final groupId = _optionalUuid(json['group_id'], 'group_id');

    return BackupDebt(
      id: _requireUuid(json['id'], 'id'),
      groupId: groupId,
      title: validateText(
        _requireString(json['title'], 'title'),
        field: 'Judul hutang',
        maxLength: 200,
      ),
      principalAmount: validatePositiveRupiah(
        _requireInt(json['principal_amount'], 'principal_amount'),
        field: 'Pokok hutang',
      ),
      dueDate: _optionalDateOnly(json['due_date'], 'due_date'),
      notes: validateOptionalText(
        _optionalString(json['notes'], 'notes'),
        field: 'Catatan hutang',
      ),
      isArchived: _requireBool(json['is_archived'], 'is_archived'),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

final class BackupPayment {
  const BackupPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidAt,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String debtId;
  final int amount;
  final DateTime paidAt;
  final String? notes;
  final DateTime createdAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'debt_id': debtId,
      'amount': amount,
      'paid_at': paidAt.toUtc().toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory BackupPayment.fromJson(Map<String, Object?> json) {
    return BackupPayment(
      id: _requireUuid(json['id'], 'id'),
      debtId: _requireUuid(json['debt_id'], 'debt_id'),
      amount: validatePositiveRupiah(
        _requireInt(json['amount'], 'amount'),
        field: 'Jumlah pembayaran',
      ),
      paidAt: _requireTimestamp(json['paid_at'], 'paid_at'),
      notes: validateOptionalText(
        _optionalString(json['notes'], 'notes'),
        field: 'Catatan pembayaran',
      ),
      createdAt: _requireTimestamp(json['created_at'], 'created_at'),
    );
  }
}

final class BackupRestorePreview {
  const BackupRestorePreview({
    required this.newGroups,
    required this.existingGroups,
    required this.newDebts,
    required this.existingDebts,
    required this.newPayments,
    required this.existingPayments,
  });

  final int newGroups;
  final int existingGroups;
  final int newDebts;
  final int existingDebts;
  final int newPayments;
  final int existingPayments;

  int get totalNew => newGroups + newDebts + newPayments;
  int get totalExisting => existingGroups + existingDebts + existingPayments;
  bool get hasChanges => totalNew > 0;
}

typedef BackupRestoreResult = BackupRestorePreview;

AppException _invalid(String detail) {
  return AppException(
    code: AppErrorCode.validation,
    message: 'Backup tidak valid: $detail',
  );
}

List<T> _parseList<T>(
  Object? value,
  String field,
  T Function(Map<String, Object?>) parse,
) {
  if (value is! List) {
    throw _invalid('$field harus berupa array.');
  }

  return value
      .map((item) {
        if (item is! Map) {
          throw _invalid('Setiap item $field harus berupa objek.');
        }
        return parse(
          item.map<String, Object?>(
            (key, entry) => MapEntry(key.toString(), entry),
          ),
        );
      })
      .toList(growable: false);
}

String _requireString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw _invalid('$field wajib berupa teks.');
  }
  return value;
}

String? _optionalString(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw _invalid('$field harus berupa teks atau null.');
  }
  return value;
}

int _requireInt(Object? value, String field) {
  if (value is! int) {
    throw _invalid('$field wajib berupa bilangan bulat.');
  }
  return value;
}

bool _requireBool(Object? value, String field) {
  if (value is! bool) {
    throw _invalid('$field wajib berupa boolean.');
  }
  return value;
}

String _requireUuid(Object? value, String field) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
        r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    throw _invalid('$field wajib berupa UUID.');
  }
  return value.toLowerCase();
}

String? _optionalUuid(Object? value, String field) {
  if (value == null || value == '') {
    return null;
  }
  return _requireUuid(value, field);
}

DateTime _requireTimestamp(Object? value, String field) {
  if (value is! String) {
    throw _invalid('$field wajib berupa timestamp ISO-8601.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw _invalid('$field bukan timestamp ISO-8601 yang valid.');
  }
  return parsed.toUtc();
}

DateTime? _optionalDateOnly(Object? value, String field) {
  if (value == null || value == '') {
    return null;
  }
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw _invalid('$field wajib menggunakan format YYYY-MM-DD.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw _invalid('$field bukan tanggal yang valid.');
  }
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}

String _dateOnly(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-$month-$day';
}

void _ensureTimestampOrder(DateTime createdAt, DateTime updatedAt) {
  if (updatedAt.isBefore(createdAt)) {
    throw _invalid('updated_at tidak boleh lebih awal dari created_at.');
  }
}

void _ensureUniqueIds(Iterable<String> ids, String field) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw _invalid('$field memiliki ID duplikat: $id.');
    }
  }
}
