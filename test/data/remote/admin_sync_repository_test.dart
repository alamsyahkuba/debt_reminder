import 'dart:convert';

import 'package:debt_reminder/core/errors/admin_sync_exception.dart';
import 'package:debt_reminder/data/remote/admin_sync_repository.dart';
import 'package:debt_reminder/domain/entities/admin_mutation_result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'applied mutation memakai header admin dan mengembalikan versi',
    () async {
      late http.Request captured;
      final repository = HttpAdminSyncRepository(
        baseUrl: 'https://example.supabase.co/',
        anonKey: 'anon-key',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object?>{
              'status': 'applied',
              'entity_type': 'debt_group',
              'entity_id': 'g1',
              'version': 3,
              'server_updated_at': '2026-11-13T10:00:01Z',
            }),
            200,
          );
        }),
      );

      final result = await repository.applyMutation(
        token: 'admin-token',
        operationId: 'op1',
        operation: 'update',
        entityType: 'debt_group',
        entityId: 'g1',
        payload: <String, Object?>{'id': 'g1', 'expected_version': 2},
      );

      expect(
        captured.url.toString(),
        'https://example.supabase.co/functions/v1/admin-sync',
      );
      expect(captured.headers['apikey'], 'anon-key');
      expect(captured.headers['authorization'], 'Bearer anon-key');
      expect(captured.headers['x-admin-session'], 'admin-token');
      expect(jsonDecode(captured.body), <String, Object?>{
        'operation_id': 'op1',
        'operation': 'update',
        'entity_type': 'debt_group',
        'entity_id': 'g1',
        'payload': <String, Object?>{'id': 'g1', 'expected_version': 2},
      });
      expect(result.status, AdminMutationStatus.applied);
      expect(result.version, 3);
    },
  );

  test('conflict mem-parse snapshot server', () async {
    final repository = HttpAdminSyncRepository(
      baseUrl: 'https://example.supabase.co',
      anonKey: 'anon-key',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'code': 'version_conflict',
              'message': 'Data berubah.',
              'details': <String, Object?>{
                'status': 'conflict',
                'server_version': 5,
                'server_updated_at': '2026-11-13T10:10:00Z',
                'server_row': <String, Object?>{'id': 'g1', 'name': 'Server'},
              },
            },
          }),
          409,
        );
      }),
    );

    final result = await repository.applyMutation(
      token: 'admin-token',
      operationId: 'op1',
      operation: 'update',
      entityType: 'debt_group',
      entityId: 'g1',
      payload: <String, Object?>{'id': 'g1'},
    );

    expect(result.status, AdminMutationStatus.conflict);
    expect(result.version, 5);
    expect(result.serverRow?['name'], 'Server');
    expect(result.serverUpdatedAt, DateTime.utc(2026, 11, 13, 10, 10));
  });

  test('auth, validasi, dan jaringan menjadi error bertipe', () async {
    Future<AdminSyncException> callWith(http.Response response) async {
      final repository = HttpAdminSyncRepository(
        baseUrl: 'https://example.supabase.co',
        anonKey: 'anon-key',
        client: MockClient((request) async => response),
      );
      try {
        await repository.applyMutation(
          token: 'token',
          operationId: 'op1',
          operation: 'create',
          entityType: 'debt_group',
          entityId: 'g1',
          payload: <String, Object?>{'id': 'g1'},
        );
        throw StateError('expected exception');
      } on AdminSyncException catch (error) {
        return error;
      }
    }

    final auth = await callWith(
      http.Response(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{
            'code': 'session_revoked',
            'message': 'Sesi berakhir.',
          },
        }),
        401,
      ),
    );
    expect(auth.isAuthError, true);
    expect(auth.isRetryable, false);

    final validation = await callWith(
      http.Response(
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{
            'code': 'validation_error',
            'message': 'Data tidak valid.',
          },
        }),
        400,
      ),
    );
    expect(validation.isRetryable, false);

    final retryable = await callWith(http.Response('{}', 503));
    expect(retryable.isRetryable, true);
  });

  test('network failure is retryable', () async {
    final repository = HttpAdminSyncRepository(
      baseUrl: 'https://example.supabase.co',
      anonKey: 'anon-key',
      client: MockClient((request) async {
        throw http.ClientException('offline');
      }),
    );

    await expectLater(
      repository.applyMutation(
        token: 'token',
        operationId: 'op1',
        operation: 'create',
        entityType: 'debt_group',
        entityId: 'g1',
        payload: <String, Object?>{'id': 'g1'},
      ),
      throwsA(
        isA<AdminSyncException>()
            .having((error) => error.code, 'code', 'network')
            .having((error) => error.isRetryable, 'retryable', true),
      ),
    );
  });
}
