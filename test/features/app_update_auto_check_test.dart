import 'dart:io';

import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/updates/app_update_service.dart';
import 'package:debt_reminder/domain/entities/app_update.dart';
import 'package:debt_reminder/domain/repositories/app_update_repository.dart';
import 'package:debt_reminder/features/admin/application/admin_providers.dart';
import 'package:debt_reminder/features/settings/application/app_update_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_admin_session_store.dart';

AppUpdateInfo _update() {
  return AppUpdateInfo(
    versionName: '1.1.0',
    buildNumber: 2,
    tag: 'v1.1.0',
    apkAsset: 'debt-reminder-v1.1.0+2.apk',
    apkUrl:
        'https://github.com/alamsyahkuba/debt_reminder/releases/download/'
        'v1.1.0/debt-reminder-v1.1.0+2.apk',
    apkSha256: List<String>.filled(64, 'a').join(),
    apkSizeBytes: 1024,
    releaseUrl:
        'https://github.com/alamsyahkuba/debt_reminder/releases/tag/v1.1.0',
    publishedAt: DateTime.utc(2026, 11, 15, 8),
    notes: 'Perbaikan bug dan peningkatan stabilitas.',
  );
}

class _FakeRepository implements AppUpdateRepository {
  @override
  Future<AppUpdateInfo?> fetchLatest() async => null;
}

class _FakeInstaller implements ApkInstallerGateway {
  @override
  Future<AppInstallerPermission> permission() async {
    return AppInstallerPermission.allowed;
  }

  @override
  Future<int?> availableStorageBytes() async => 200 * 1024 * 1024;

  @override
  Future<void> openInstallPermissionSettings() async {}

  @override
  Future<AppInstallerResult> install({
    required String apkPath,
    required String packageName,
    required int versionCode,
  }) async {
    return const AppInstallerResult(status: AppInstallerStatus.installerOpened);
  }
}

class _FakeUpdateService extends AppUpdateService {
  _FakeUpdateService()
    : super(repository: _FakeRepository(), installer: _FakeInstaller());

  AppUpdateInfo? checkResult;
  int checkCalls = 0;

  @override
  Future<AppUpdateInfo?> check() async {
    checkCalls++;
    return checkResult;
  }

  @override
  Future<File> download(
    AppUpdateInfo update, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    return File('/tmp/update.apk');
  }

  @override
  Future<AppInstallerPermission> installerPermission() async {
    return AppInstallerPermission.allowed;
  }

  @override
  Future<AppInstallerResult> install({
    required File file,
    required AppUpdateInfo update,
  }) async {
    return const AppInstallerResult(status: AppInstallerStatus.installerOpened);
  }

  @override
  Future<void> openInstallPermissionSettings() async {}

  @override
  Future<void> cleanup() async {}
}

class _Harness {
  _Harness(this.database);

  final AppDatabase database;

  Future<void> pump(
    WidgetTester tester,
    _FakeUpdateService service, {
    bool autoCheck = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(
            FakeAdminSessionStore.unlocked(),
          ),
          appVersionProvider.overrideWith(
            (ref) async =>
                const AppVersionInfo(versionName: '1.0.0', buildNumber: 1),
          ),
          appUpdateServiceProvider.overrideWithValue(service),
          if (autoCheck) appUpdateAutoCheckProvider.overrideWithValue(true),
        ],
        child: const DebtReminderApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 20));
    await database.close();
  }
}

void main() {
  testWidgets('cek update otomatis saat aplikasi dibuka dan banner dashboard', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    final service = _FakeUpdateService()..checkResult = _update();
    try {
      await harness.pump(tester, service);

      expect(service.checkCalls, 1);
      expect(find.byKey(const Key('dashboard-update-banner')), findsOneWidget);
      expect(
        find.textContaining('Update tersedia: 1.1.0 (build 2)'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('dashboard-update-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('banner tidak tampil jika sudah versi terbaru', (tester) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    final service = _FakeUpdateService()
      ..checkResult = AppUpdateInfo(
        versionName: '1.0.0',
        buildNumber: 1,
        tag: 'v1.0.0',
        apkAsset: 'debt-reminder-v1.0.0+1.apk',
        apkUrl:
            'https://github.com/alamsyahkuba/debt_reminder/releases/download/'
            'v1.0.0/debt-reminder-v1.0.0+1.apk',
        apkSha256: List<String>.filled(64, 'b').join(),
        apkSizeBytes: 1024,
        releaseUrl:
            'https://github.com/alamsyahkuba/debt_reminder/releases/tag/v1.0.0',
        publishedAt: DateTime.utc(2026, 11, 15, 8),
        notes: '',
      );
    try {
      await harness.pump(tester, service);

      expect(service.checkCalls, 1);
      expect(find.byKey(const Key('dashboard-update-banner')), findsNothing);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('auto-check tidak berjalan pada widget test default', (
    tester,
  ) async {
    final harness = _Harness(AppDatabase(NativeDatabase.memory()));
    final service = _FakeUpdateService()..checkResult = _update();
    try {
      await harness.pump(tester, service, autoCheck: false);

      expect(service.checkCalls, 0);
      expect(find.byKey(const Key('dashboard-update-banner')), findsNothing);
    } finally {
      await harness.dispose(tester);
    }
  });
}
