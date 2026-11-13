import 'dart:convert';

import 'package:debt_reminder/core/errors/app_exception.dart';
import 'package:debt_reminder/data/remote/public_read_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetchGroups memakai cursor dan mem-parse field publik', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode(<Map<String, Object?>>[
          <String, Object?>{
            'id': 'g1',
            'name': 'Keluarga',
            'description': 'Group',
            'color': '#00695C',
            'icon': 'family',
            'sort_order': 1,
            'is_archived': false,
            'created_at': '2026-11-13T09:00:00Z',
            'updated_at': '2026-11-13T10:00:00Z',
          },
        ]),
        200,
      );
    });
    final repository = PublicReadRepository(
      baseUrl: 'https://example.supabase.co/',
      anonKey: 'anon-key',
      client: client,
      pageSize: 2,
    );

    final page = await repository.fetchGroups(
      cursor: PublicCursor(timestamp: DateTime.utc(2026, 11, 13, 8), id: 'g0'),
    );

    expect(
      captured.url.toString(),
      'https://example.supabase.co/rest/v1/rpc/public_debt_groups_page',
    );
    expect(captured.headers['apikey'], 'anon-key');
    expect(captured.headers['authorization'], 'Bearer anon-key');
    expect(jsonDecode(captured.body), <String, Object?>{
      'p_after_updated_at': '2026-11-13T08:00:00.000Z',
      'p_after_id': 'g0',
      'p_limit': 2,
    });
    expect(page.items.single.name, 'Keluarga');
    expect(page.items.single.sortOrder, 1);
    expect(page.cursor?.id, 'g1');
    expect(page.cursor?.timestamp, DateTime.utc(2026, 11, 13, 10));
  });

  test('fetchDebts dan fetchPayments mem-parse tanggal', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('public_debts_page')) {
        return http.Response(
          jsonEncode(<Map<String, Object?>>[
            <String, Object?>{
              'id': 'd1',
              'group_id': 'g1',
              'title': 'Hutang',
              'principal_amount': 1000000,
              'due_date': '2027-01-10',
              'notes': null,
              'is_archived': false,
              'created_at': '2026-11-13T09:00:00Z',
              'updated_at': '2026-11-13T10:00:00Z',
            },
          ]),
          200,
        );
      }
      return http.Response(
        jsonEncode(<Map<String, Object?>>[
          <String, Object?>{
            'id': 'p1',
            'debt_id': 'd1',
            'amount': 250000,
            'paid_at': '2026-11-13T10:05:00Z',
            'notes': 'Cicilan',
            'created_at': '2026-11-13T10:05:00Z',
          },
        ]),
        200,
      );
    });
    final repository = PublicReadRepository(
      baseUrl: 'https://example.supabase.co',
      anonKey: 'anon-key',
      client: client,
    );

    final debts = await repository.fetchDebts();
    final payments = await repository.fetchPayments();

    expect(debts.items.single.dueDate, DateTime.utc(2027, 1, 10));
    expect(debts.items.single.principalAmount, 1000000);
    expect(payments.items.single.amount, 250000);
    expect(payments.items.single.notes, 'Cicilan');
  });

  test(
    'public read memetakan gangguan jaringan dan konfigurasi kosong',
    () async {
      final offline = PublicReadRepository(
        baseUrl: 'https://example.supabase.co',
        anonKey: 'anon-key',
        client: MockClient((request) async {
          throw http.ClientException('offline');
        }),
      );

      await expectLater(
        offline.fetchGroups(),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.offline,
          ),
        ),
      );

      final unconfigured = PublicReadRepository(
        baseUrl: '',
        anonKey: '',
        client: MockClient((request) async => http.Response('[]', 200)),
      );
      await expectLater(
        unconfigured.fetchGroups(),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            AppErrorCode.remoteUnavailable,
          ),
        ),
      );
    },
  );
}
