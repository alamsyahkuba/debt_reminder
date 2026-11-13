import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';

class PublicCursor {
  const PublicCursor({required this.timestamp, required this.id});

  final DateTime timestamp;
  final String id;

  String toJson() => jsonEncode(<String, Object?>{
    'timestamp': timestamp.toUtc().toIso8601String(),
    'id': id,
  });

  static PublicCursor? fromJson(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final timestamp = DateTime.tryParse(
        decoded['timestamp'] as String? ?? '',
      );
      final id = decoded['id'];
      if (timestamp == null || id is! String || id.isEmpty) {
        return null;
      }
      return PublicCursor(timestamp: timestamp.toUtc(), id: id);
    } catch (_) {
      return null;
    }
  }
}

class PublicPage<T> {
  const PublicPage({required this.items, required this.cursor});

  final List<T> items;
  final PublicCursor? cursor;
}

abstract interface class PublicPullSource {
  int get pageSize;

  Future<PublicPage<PublicDebtGroup>> fetchGroups({PublicCursor? cursor});

  Future<PublicPage<PublicDebt>> fetchDebts({PublicCursor? cursor});

  Future<PublicPage<PublicPayment>> fetchPayments({PublicCursor? cursor});
}

class PublicDebtGroup {
  const PublicDebtGroup({
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
}

class PublicDebt {
  const PublicDebt({
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
}

class PublicPayment {
  const PublicPayment({
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
}

class PublicReadRepository implements PublicPullSource {
  PublicReadRepository({
    required String baseUrl,
    required String anonKey,
    http.Client? client,
    this.pageSize = 100,
    this.timeout = const Duration(seconds: 20),
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _anonKey = anonKey.trim(),
       _client = client ?? http.Client();

  final String _baseUrl;
  final String _anonKey;
  final http.Client _client;
  @override
  final int pageSize;
  final Duration timeout;

  @override
  Future<PublicPage<PublicDebtGroup>> fetchGroups({
    PublicCursor? cursor,
  }) async {
    final rows = await _fetchPage(
      'public_debt_groups_page',
      afterUpdatedAt: cursor?.timestamp,
      afterId: cursor?.id,
    );

    final groups = rows.map(_groupFromJson).toList(growable: false);
    return PublicPage(
      items: groups,
      cursor: groups.isEmpty
          ? null
          : PublicCursor(timestamp: groups.last.updatedAt, id: groups.last.id),
    );
  }

  @override
  Future<PublicPage<PublicDebt>> fetchDebts({PublicCursor? cursor}) async {
    final rows = await _fetchPage(
      'public_debts_page',
      afterUpdatedAt: cursor?.timestamp,
      afterId: cursor?.id,
    );

    final debts = rows.map(_debtFromJson).toList(growable: false);
    return PublicPage(
      items: debts,
      cursor: debts.isEmpty
          ? null
          : PublicCursor(timestamp: debts.last.updatedAt, id: debts.last.id),
    );
  }

  @override
  Future<PublicPage<PublicPayment>> fetchPayments({
    PublicCursor? cursor,
  }) async {
    final rows = await _fetchPage(
      'public_payments_page',
      afterCreatedAt: cursor?.timestamp,
      afterId: cursor?.id,
    );

    final payments = rows.map(_paymentFromJson).toList(growable: false);
    return PublicPage(
      items: payments,
      cursor: payments.isEmpty
          ? null
          : PublicCursor(
              timestamp: payments.last.createdAt,
              id: payments.last.id,
            ),
    );
  }

  Future<List<Map<String, Object?>>> _fetchPage(
    String functionName, {
    DateTime? afterUpdatedAt,
    DateTime? afterCreatedAt,
    String? afterId,
  }) async {
    if (_baseUrl.isEmpty || _anonKey.isEmpty) {
      throw const AppException(
        code: AppErrorCode.remoteUnavailable,
        message: 'Supabase belum dikonfigurasi.',
      );
    }

    final uri = Uri.parse('$_baseUrl/rest/v1/rpc/$functionName');
    final body = <String, Object?>{'p_limit': pageSize};
    if (afterUpdatedAt != null) {
      body['p_after_updated_at'] = afterUpdatedAt.toUtc().toIso8601String();
    }
    if (afterCreatedAt != null) {
      body['p_after_created_at'] = afterCreatedAt.toUtc().toIso8601String();
    }
    if (afterId != null) {
      body['p_after_id'] = afterId;
    }

    final response = await _send(
      () => _client
          .post(
            uri,
            headers: <String, String>{
              'content-type': 'application/json',
              'apikey': _anonKey,
              'authorization': 'Bearer $_anonKey',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
        code: AppErrorCode.remoteUnavailable,
        message: 'Data publik tidak dapat dimuat (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const AppException(
        code: AppErrorCode.remoteUnavailable,
        message: 'Respons data publik tidak valid.',
      );
    }

    return decoded.whereType<Map<String, Object?>>().toList(growable: false);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on TimeoutException catch (error) {
      throw AppException(
        code: AppErrorCode.offline,
        message: 'Server publik tidak merespons. Coba lagi.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw AppException(
        code: AppErrorCode.offline,
        message: 'Tidak dapat terhubung ke server publik.',
        cause: error,
      );
    }
  }

  PublicDebtGroup _groupFromJson(Map<String, Object?> row) {
    return PublicDebtGroup(
      id: _string(row, 'id'),
      name: _string(row, 'name'),
      description: _optionalString(row, 'description'),
      color: _optionalString(row, 'color'),
      icon: _optionalString(row, 'icon'),
      sortOrder: _int(row, 'sort_order'),
      isArchived: row['is_archived'] == true,
      createdAt: _timestamp(row, 'created_at'),
      updatedAt: _timestamp(row, 'updated_at'),
    );
  }

  PublicDebt _debtFromJson(Map<String, Object?> row) {
    return PublicDebt(
      id: _string(row, 'id'),
      groupId: _optionalString(row, 'group_id'),
      title: _string(row, 'title'),
      principalAmount: _int(row, 'principal_amount'),
      dueDate: _optionalDate(row, 'due_date'),
      notes: _optionalString(row, 'notes'),
      isArchived: row['is_archived'] == true,
      createdAt: _timestamp(row, 'created_at'),
      updatedAt: _timestamp(row, 'updated_at'),
    );
  }

  PublicPayment _paymentFromJson(Map<String, Object?> row) {
    return PublicPayment(
      id: _string(row, 'id'),
      debtId: _string(row, 'debt_id'),
      amount: _int(row, 'amount'),
      paidAt: _timestamp(row, 'paid_at'),
      notes: _optionalString(row, 'notes'),
      createdAt: _timestamp(row, 'created_at'),
    );
  }

  String _string(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw AppException(
      code: AppErrorCode.remoteUnavailable,
      message: 'Field publik $key tidak valid.',
    );
  }

  String? _optionalString(Map<String, Object?> row, String key) {
    final value = row[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  int _int(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw AppException(
      code: AppErrorCode.remoteUnavailable,
      message: 'Field publik $key tidak valid.',
    );
  }

  DateTime _timestamp(Map<String, Object?> row, String key) {
    final value = row[key];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) {
      throw AppException(
        code: AppErrorCode.remoteUnavailable,
        message: 'Field publik $key tidak valid.',
      );
    }
    return parsed.toUtc();
  }

  DateTime? _optionalDate(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value == null || value == '') {
      return null;
    }
    if (value is! String) {
      return null;
    }
    final parts = value.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime.utc(year, month, day);
  }
}
