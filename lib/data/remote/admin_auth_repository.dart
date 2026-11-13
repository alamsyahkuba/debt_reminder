import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/admin_auth_exception.dart';
import '../../domain/entities/admin_session.dart';
import '../../domain/repositories/admin_auth_repository.dart';

class HttpAdminAuthRepository implements AdminAuthRepository {
  HttpAdminAuthRepository({
    required String baseUrl,
    required String anonKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
       _anonKey = anonKey.trim(),
       _client = client ?? http.Client();

  final String _baseUrl;
  final String _anonKey;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<AdminSession> verifyPin({
    required String pin,
    required String deviceId,
  }) async {
    final body = await _post(<String, Object?>{
      'action': 'verify',
      'pin': pin,
      'device_id': deviceId,
    });

    final token = body['token'];
    final expiresAtText = body['expires_at'];
    if (token is! String || token.isEmpty || expiresAtText is! String) {
      throw const AdminAuthException(
        code: 'server',
        message: 'Respons sesi admin tidak valid.',
      );
    }

    final expiresAt = DateTime.tryParse(expiresAtText);
    if (expiresAt == null) {
      throw const AdminAuthException(
        code: 'server',
        message: 'Waktu sesi admin tidak valid.',
      );
    }

    return AdminSession(token: token, expiresAt: expiresAt.toUtc());
  }

  @override
  Future<void> changePin({
    required String token,
    required String currentPin,
    required String newPin,
  }) async {
    await _post(<String, Object?>{
      'action': 'change',
      'current_pin': currentPin,
      'new_pin': newPin,
    }, token: token);
  }

  @override
  Future<void> logout({required String token}) async {
    await _post(<String, Object?>{'action': 'logout'}, token: token);
  }

  Future<Map<String, Object?>> _post(
    Map<String, Object?> body, {
    String? token,
  }) async {
    if (_baseUrl.isEmpty || _anonKey.isEmpty) {
      throw const AdminAuthException(
        code: 'config',
        message:
            'Supabase belum dikonfigurasi. Admin membutuhkan koneksi server.',
      );
    }

    final uri = Uri.parse('$_baseUrl/functions/v1/admin-pin');
    final headers = <String, String>{
      'content-type': 'application/json',
      'apikey': _anonKey,
      'authorization': 'Bearer $_anonKey',
    };
    if (token != null) {
      headers['x-admin-session'] = token;
    }

    final response = await _send(
      () => _client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(timeout),
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? const <String, Object?>{};
    }

    throw _errorFrom(response.statusCode, decoded);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on TimeoutException catch (error) {
      throw AdminAuthException(
        code: 'network',
        message:
            'Server admin tidak merespons. Periksa koneksi lalu coba lagi.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw AdminAuthException(
        code: 'network',
        message:
            'Tidak dapat terhubung ke server admin. Periksa koneksi internet.',
        cause: error,
      );
    }
  }

  AdminAuthException _errorFrom(int statusCode, Map<String, Object?>? body) {
    final error = body?['error'];
    if (error is Map) {
      final code = error['code'];
      final message = error['message'];
      final details = error['details'];
      final retryAfter = details is Map
          ? _positiveInt(details['retry_after_seconds'])
          : null;

      return AdminAuthException(
        code: code is String && code.isNotEmpty ? code : 'server',
        message: message is String && message.isNotEmpty
            ? message
            : 'Permintaan admin gagal.',
        retryAfterSeconds: retryAfter,
      );
    }

    return AdminAuthException(
      code: statusCode == 401 ? 'unauthorized' : 'server',
      message: statusCode == 401
          ? 'Sesi admin tidak valid.'
          : 'Permintaan admin gagal.',
    );
  }

  Map<String, Object?>? _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  int? _positiveInt(Object? value) {
    if (value is int && value > 0) {
      return value;
    }
    return null;
  }
}
