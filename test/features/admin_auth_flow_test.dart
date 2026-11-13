import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/domain/entities/admin_session.dart';
import 'package:debt_reminder/features/admin/application/admin_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_admin_session_store.dart';

class _Harness {
  _Harness({FakeAdminSessionStore? store, FakeAdminAuthRepository? auth})
    : store = store ?? FakeAdminSessionStore(),
      auth = auth ?? FakeAdminAuthRepository();

  final AppDatabase database = AppDatabase(NativeDatabase.memory());
  final FakeAdminSessionStore store;
  final FakeAdminAuthRepository auth;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(store),
          adminAuthRepositoryProvider.overrideWithValue(auth),
        ],
        child: const DebtReminderApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
    await database.close();
  }
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
}

Future<void> _tapDrawerItem(WidgetTester tester, String path) async {
  final finder = find.byKey(ValueKey<String>('drawer-item-$path'));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openAdmin(WidgetTester tester) async {
  await _openDrawer(tester);
  await _tapDrawerItem(tester, '/admin');
}

Future<void> _enterPinAndSubmit(WidgetTester tester, String pin) async {
  await tester.enterText(find.byKey(const Key('admin-pin-field')), pin);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('admin-pin-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'PIN salah ditolak, PIN benar membuka admin, ubah PIN, lalu lock',
    (tester) async {
      final harness = _Harness();
      try {
        await harness.pump(tester);
        await _openAdmin(tester);

        expect(find.text('Masuk sebagai Admin'), findsOneWidget);
        await _enterPinAndSubmit(tester, '000000');
        expect(find.text('PIN tidak valid.'), findsOneWidget);

        await _enterPinAndSubmit(tester, '123456');
        expect(find.text('Admin aktif'), findsOneWidget);
        expect(harness.store.session, isNotNull);
        expect(find.byKey(const Key('admin-lock-button')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('admin-current-pin-field')),
          '123456',
        );
        await tester.enterText(
          find.byKey(const Key('admin-new-pin-field')),
          '654321',
        );
        await tester.enterText(
          find.byKey(const Key('admin-confirm-pin-field')),
          '654321',
        );
        await tester.tap(find.byKey(const Key('admin-change-pin-button')));
        await tester.pumpAndSettle();

        expect(find.text('PIN admin berhasil diubah.'), findsOneWidget);
        expect(harness.auth.validPin, '654321');

        await _openDrawer(tester);
        await _tapDrawerItem(tester, '/dashboard');
        expect(find.byKey(const Key('admin-locked-banner')), findsNothing);
        expect(
          find.byKey(const Key('dashboard-add-debt-button')),
          findsOneWidget,
        );

        await _openAdmin(tester);
        await tester.tap(find.byKey(const Key('admin-lock-button')));
        await tester.pumpAndSettle();

        expect(find.text('Masuk sebagai Admin'), findsOneWidget);
        expect(harness.store.session, isNull);
        expect(harness.auth.logoutCalled, isTrue);
      } finally {
        await harness.dispose(tester);
      }
    },
  );

  testWidgets('route form admin dialihkan ke PIN lalu kembali setelah unlock', (
    tester,
  ) async {
    final harness = _Harness();
    try {
      await harness.pump(tester);

      final context = tester.element(find.byKey(const Key('dashboard-screen')));
      GoRouter.of(context).go('/groups/new');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-pin-screen')), findsOneWidget);
      await _enterPinAndSubmit(tester, '123456');
      expect(find.byKey(const Key('group-name-field')), findsOneWidget);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('mode terkunci tidak menampilkan tombol mutasi', (tester) async {
    final harness = _Harness();
    try {
      await harness.pump(tester);

      expect(find.byKey(const Key('admin-locked-banner')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-add-debt-button')), findsNothing);

      await _openDrawer(tester);
      await _tapDrawerItem(tester, '/groups');
      expect(find.byKey(const Key('groups-add-button')), findsNothing);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('sesi admin otomatis terkunci saat kedaluwarsa', (tester) async {
    final harness = _Harness(
      store: FakeAdminSessionStore(
        session: AdminSession(
          token: 'short-lived-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 5)),
        ),
      ),
    );
    try {
      await harness.pump(tester);
      expect(find.byKey(const Key('admin-locked-banner')), findsNothing);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('admin-locked-banner')), findsOneWidget);
      expect(harness.store.session, isNull);
    } finally {
      await harness.dispose(tester);
    }
  });
}
