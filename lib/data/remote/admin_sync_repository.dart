import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/admin_sync_exception.dart';
import '../../domain/entities/admin_mutation_result.dart';
import '../../domain/repositories/admin_sync_repository.dart';

class HttpAdminSyncRepository implements AdminSyncRepository {
  HttpAdminSyncRepository({
    required String baseUrl,
    required String anonKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _anonKey = anonKey.trim(),
       _client = client ?? http.Client();

  final String _baseUrl;
  final String _anonKey;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<AdminMutationResult> applyMutation({
    required String token,
    required String operationId,
    required String operation,
    required String entityType,
    required String entityId,
    required Map<String, Object?> payload,
  }) async {
    if (_baseUrl.isEmpty || _anonKey.isEmpty) {
      throw const AdminSyncException(
        code: 'config',
        message: 'Supabase belum dikonfigurasi.',
      );
    }

    final uri = Uri.parse('$_baseUrl/functions/v1/admin-sync');
    final response = await _send(
      () => _client
          .post(
            uri,
            headers: <String, String>{
              'content-type': 'application/json',
              'apikey': _anonKey,
              'authorization': 'Bearer $_anonKey',
              'x-admin-session': token,
            },
            body: jsonEncode(<String, Object?>{
              'operation_id': operationId,
              'operation': operation,
              'entity_type': entityType,
              'entity_id': entityId,
              'payload': payload,
            }),
          )
          .timeout(timeout),
    );

    final body = _decodeObject(response.body);
    final error = body?['error'];
    final errorMap = error is Map ? error : null;
    final code = errorMap?['code'];
    final message = errorMap?['message'];
    final details = errorMap?['details'];

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _applied(body);
    }

    if (response.statusCode == 409) {
      final detailMap = details is Map ? _stringKeyed(details) : null;
      final serverVersion = detailMap?['server_version'];
      final serverUpdatedAt = detailMap?['server_updated_at'];
      final serverRow = detailMap?['server_row'];
      if (serverVersion is num && serverUpdatedAt is String) {
        return AdminMutationResult.conflict(
          serverVersion: serverVersion.toInt(),
          serverUpdatedAt: DateTime.parse(serverUpdatedAt).toUtc(),
          serverRow: serverRow is Map ? _stringKeyed(serverRow) : const {},
          message: message is String ? message : null,
        );
      }

      throw AdminSyncException(
        code: code is String ? code : 'version_conflict',
        message: message is String ? message : 'Data telah berubah di server.',
        statusCode: response.statusCode,
        isRetryable: false,
      );
    }

    if (response.statusCode == 404) {
      return AdminMutationResult.notFound(
        message: message is String
            ? message
            : 'Data tidak ditemukan di server.',
      );
    }

    final authError = response.statusCode == 401 || response.statusCode == 403;
    final retryable = response.statusCode == 429 || response.statusCode >= 500;

    throw AdminSyncException(
      code: code is String && code.isNotEmpty
          ? code
          : (authError ? 'unauthorized' : 'sync_failed'),
      message: message is String && message.isNotEmpty
          ? message
          : (authError
                ? 'Sesi admin tidak valid.'
                : 'Operasi sinkronisasi gagal.'),
      statusCode: response.statusCode,
      isRetryable: retryable,
      isAuthError: authError,
    );
  }

  AdminMutationResult _applied(Map<String, Object?>? body) {
    if (body == null) {
      throw const AdminSyncException(
        code: 'invalid_response',
        message: 'Respons sinkronisasi tidak valid.',
      );
    }

    final version = body['version'];
    final updatedAt = body['server_updated_at'] ?? body['created_at'];
    return AdminMutationResult.applied(
      version: version is num ? version.toInt() : null,
      serverUpdatedAt: updatedAt is String
          ? DateTime.tryParse(updatedAt)?.toUtc()
          : null,
      items: _appliedItems(body['debts']),
    );
  }

  List<AdminMutationItemResult> _appliedItems(Object? value) {
    if (value is! List) {
      return const <AdminMutationItemResult>[];
    }

    final items = <AdminMutationItemResult>[];
    for (final raw in value) {
      if (raw is! Map) {
        continue;
      }
      final item = _stringKeyed(raw);
      final id = item['id'];
      final version = item['version'];
      final updatedAt = item['server_updated_at'] ?? item['updated_at'];
      final parsedUpdatedAt = updatedAt is String
          ? DateTime.tryParse(updatedAt)?.toUtc()
          : null;
      if (id is String && version is num && parsedUpdatedAt != null) {
        items.add(
          AdminMutationItemResult(
            id: id,
            version: version.toInt(),
            serverUpdatedAt: parsedUpdatedAt,
          ),
        );
      }
    }
    return items;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on TimeoutException catch (error) {
      throw AdminSyncException(
        code: 'network',
        message: 'Server sinkronisasi tidak merespons.',
        isRetryable: true,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw AdminSyncException(
        code: 'network',
        message: 'Tidak dapat terhubung ke server sinkronisasi.',
        isRetryable: true,
        cause: error,
      );
    }
  }

  Map<String, Object?>? _decodeObject(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? _stringKeyed(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _stringKeyed(Map<dynamic, dynamic> value) {
    return value.map((key, entry) => MapEntry(key.toString(), entry));
  }
}
