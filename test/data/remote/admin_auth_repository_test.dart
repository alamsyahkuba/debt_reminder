import 'dart:convert';

import 'package:debt_reminder/core/errors/admin_auth_exception.dart';
import 'package:debt_reminder/data/remote/admin_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('verifyPin mengirim PIN ke Edge Function dan menyimpan sesi', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode(<String, Object?>{
          'token': 'signed-admin-token',
          'token_type': 'Bearer',
          'expires_at': '2026-11-13T10:15:00.000Z',
        }),
        200,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    });
    final repository = HttpAdminAuthRepository(
      baseUrl: 'https://example.supabase.co/',
      anonKey: 'anon-key',
      client: client,
    );

    final session = await repository.verifyPin(
      pin: '123456',
      deviceId: 'device-1',
    );

    expect(
      captured.url.toString(),
      'https://example.supabase.co/functions/v1/admin-pin',
    );
    expect(captured.headers['apikey'], 'anon-key');
    expect(captured.headers['authorization'], 'Bearer anon-key');
    expect(captured.headers['x-admin-session'], isNull);
    expect(jsonDecode(captured.body), <String, Object?>{
      'action': 'verify',
      'pin': '123456',
      'device_id': 'device-1',
    });
    expect(session.token, 'signed-admin-token');
    expect(session.expiresAt, DateTime.utc(2026, 11, 13, 10, 15));
  });

  test('error invalid PIN dan rate limit dipetakan dengan aman', () async {
    final invalidRepository = HttpAdminAuthRepository(
      baseUrl: 'https://example.supabase.co',
      anonKey: 'anon-key',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 'invalid_pin',
              'message': 'PIN tidak valid.',
            },
          }),
          401,
        ),
      ),
    );

    await expectLater(
      invalidRepository.verifyPin(pin: '000000', deviceId: 'device-1'),
      throwsA(
        isA<AdminAuthException>()
            .having((error) => error.code, 'code', 'invalid_pin')
            .having((error) => error.message, 'message', 'PIN tidak valid.'),
      ),
    );

    final limitedRepository = HttpAdminAuthRepository(
      baseUrl: 'https://example.supabase.co',
      anonKey: 'anon-key',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 'rate_limited',
              'message': 'Terlalu banyak percobaan PIN.',
              'details': <String, Object?>{'retry_after_seconds': 900},
            },
          }),
          429,
        ),
      ),
    );

    await expectLater(
      limitedRepository.verifyPin(pin: '123456', deviceId: 'device-1'),
      throwsA(
        isA<AdminAuthException>()
            .having((error) => error.code, 'code', 'rate_limited')
            .having((error) => error.retryAfterSeconds, 'retry', 900),
      ),
    );
  });

  test('changePin dan logout memakai bearer token admin', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(<String, Object?>{'status': 'ok'}), 200);
    });
    final repository = HttpAdminAuthRepository(
      baseUrl: 'https://example.supabase.co',
      anonKey: 'anon-key',
      client: client,
    );

    await repository.changePin(
      token: 'signed-admin-token',
      currentPin: '123456',
      newPin: '654321',
    );
    await repository.logout(token: 'signed-admin-token');

    expect(requests, hasLength(2));
    expect(requests.first.headers['authorization'], 'Bearer anon-key');
    expect(requests.first.headers['x-admin-session'], 'signed-admin-token');
    expect(jsonDecode(requests.first.body), <String, Object?>{
      'action': 'change',
      'current_pin': '123456',
      'new_pin': '654321',
    });
    expect(jsonDecode(requests.last.body), <String, Object?>{
      'action': 'logout',
    });
  });

  test(
    'konfigurasi kosong dan gangguan jaringan menjadi error bertipe',
    () async {
      final missingConfig = HttpAdminAuthRepository(
        baseUrl: '',
        anonKey: '',
        client: MockClient((request) async => http.Response('{}', 200)),
      );

      await expectLater(
        missingConfig.verifyPin(pin: '123456', deviceId: 'device-1'),
        throwsA(
          isA<AdminAuthException>().having(
            (error) => error.code,
            'code',
            'config',
          ),
        ),
      );

      final offline = HttpAdminAuthRepository(
        baseUrl: 'https://example.supabase.co',
        anonKey: 'anon-key',
        client: MockClient((request) async {
          throw http.ClientException('offline');
        }),
      );

      await expectLater(
        offline.verifyPin(pin: '123456', deviceId: 'device-1'),
        throwsA(
          isA<AdminAuthException>()
              .having((error) => error.code, 'code', 'network')
              .having((error) => error.isNetworkError, 'isNetworkError', true),
        ),
      );
    },
  );
}
