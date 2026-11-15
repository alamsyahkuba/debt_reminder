import 'dart:io';

import 'package:debt_reminder/app/app.dart';
import 'package:debt_reminder/app/providers.dart';
import 'package:debt_reminder/core/config/app_config.dart';
import 'package:debt_reminder/core/errors/app_exception.dart';
import 'package:debt_reminder/data/local/app_database.dart';
import 'package:debt_reminder/data/updates/app_update_service.dart';
import 'package:debt_reminder/domain/entities/app_update.dart';
import 'package:debt_reminder/domain/repositories/app_update_repository.dart';
import 'package:debt_reminder/features/admin/application/admin_providers.dart';
import 'package:debt_reminder/features/settings/application/app_update_providers.dart';
import 'package:debt_reminder/features/settings/presentation/app_update_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_admin_session_store.dart';

const AppConfig _config = AppConfig(
  environment: AppEnvironment.development,
  supabaseUrl: '',
  supabaseAnonKey: '',
);

AppUpdateInfo _update({String versionName = '1.1.0', int buildNumber = 2}) {
  return AppUpdateInfo(
    versionName: versionName,
    buildNumber: buildNumber,
    tag: 'v$versionName',
    apkAsset: 'debt-reminder-v$versionName+$buildNumber.apk',
    apkUrl:
        'https://github.com/alamsyahkuba/debt_reminder/releases/download/'
        'v$versionName/debt-reminder-v$versionName+$buildNumber.apk',
    apkSha256: List<String>.filled(64, 'a').join(),
    apkSizeBytes: 1024,
    releaseUrl:
        'https://github.com/alamsyahkuba/debt_reminder/releases/tag/'
        'v$versionName',
    publishedAt: DateTime.utc(2026, 11, 14, 8),
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
  Object? checkError;
  AppInstallerPermission permission = AppInstallerPermission.allowed;

  @override
  Future<AppUpdateInfo?> check() async {
    if (checkError != null) {
      throw checkError!;
    }
    return checkResult;
  }

  @override
  Future<File> download(
    AppUpdateInfo update, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    onProgress?.call(update.apkSizeBytes, update.apkSizeBytes);
    return File('/tmp/debt-reminder-update.apk');
  }

  @override
  Future<AppInstallerPermission> installerPermission() async => permission;

  @override
  Future<AppInstallerResult> install({
    required File file,
    required AppUpdateInfo update,
  }) async {
    return const AppInstallerResult(status: AppInstallerStatus.installerOpened);
  }

  @override
  Future<void> cleanup() async {}
}

Future<void> _pumpCard(WidgetTester tester, _FakeUpdateService service) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appVersionProvider.overrideWith(
          (ref) async =>
              const AppVersionInfo(versionName: '1.0.0', buildNumber: 1),
        ),
        appUpdateServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AppUpdateCard())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kartu update menampilkan versi terpasang dan tombol cek', (
    tester,
  ) async {
    await _pumpCard(tester, _FakeUpdateService());

    expect(find.byKey(const Key('app-update-card')), findsOneWidget);
    expect(find.textContaining('Versi terpasang: 1.0.0'), findsOneWidget);
    expect(find.textContaining('build 1'), findsOneWidget);
    expect(find.byKey(const Key('app-update-check')), findsOneWidget);
    expect(find.text('Cek Update'), findsOneWidget);
  });

  testWidgets('menampilkan update yang tersedia beserta catatan rilis', (
    tester,
  ) async {
    final service = _FakeUpdateService()..checkResult = _update();
    await _pumpCard(tester, service);

    await tester.tap(find.byKey(const Key('app-update-check')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Versi 1.1.0 (build 2) tersedia.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('app-update-notes')), findsOneWidget);
    expect(
      find.text('Perbaikan bug dan peningkatan stabilitas.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('app-update-download')), findsOneWidget);
  });

  testWidgets('menampilkan state sudah versi terbaru', (tester) async {
    final service = _FakeUpdateService()
      ..checkResult = _update(versionName: '1.0.0', buildNumber: 1);
    await _pumpCard(tester, service);
    await tester.tap(find.byKey(const Key('app-update-check')));
    await tester.pumpAndSettle();

    expect(
      find.text('Aplikasi sudah menggunakan versi terbaru.'),
      findsOneWidget,
    );
  });

  testWidgets('menampilkan error dan dapat mencoba lagi', (tester) async {
    final service = _FakeUpdateService()
      ..checkError = const AppException(
        code: AppErrorCode.offline,
        message: 'Tidak dapat terhubung ke server pembaruan.',
      );
    await _pumpCard(tester, service);

    await tester.tap(find.byKey(const Key('app-update-check')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-update-error')), findsOneWidget);
    expect(
      find.text('Tidak dapat terhubung ke server pembaruan.'),
      findsOneWidget,
    );

    service
      ..checkError = null
      ..checkResult = _update();
    await tester.tap(find.byKey(const Key('app-update-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-update-download')), findsOneWidget);
  });

  testWidgets('izin installer ditolak menampilkan tombol pengaturan izin', (
    tester,
  ) async {
    final service = _FakeUpdateService()
      ..checkResult = _update()
      ..permission = AppInstallerPermission.denied;
    await _pumpCard(tester, service);

    await tester.tap(find.byKey(const Key('app-update-check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-update-download')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-update-permission')), findsOneWidget);
    expect(find.byKey(const Key('app-update-install')), findsOneWidget);
  });

  testWidgets('pengguna publik tetap dapat membuka kartu update', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    var cleanedUp = false;
    Future<void> cleanup() async {
      if (cleanedUp) {
        return;
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
      await database.close();
      cleanedUp = true;
    }

    addTearDown(cleanup);
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          appDatabaseProvider.overrideWithValue(database),
          adminSessionStoreProvider.overrideWithValue(FakeAdminSessionStore()),
          appVersionProvider.overrideWith(
            (ref) async =>
                const AppVersionInfo(versionName: '1.0.0', buildNumber: 1),
          ),
          appUpdateServiceProvider.overrideWithValue(
            _FakeUpdateService()..checkResult = _update(),
          ),
        ],
        child: const DebtReminderApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('drawer-item-/settings')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-screen')), findsOneWidget);
    expect(find.text('Mode baca'), findsOneWidget);
    expect(find.byKey(const Key('app-update-card')), findsOneWidget);
    expect(find.byKey(const Key('app-update-check')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('app-update-card'))).dy,
      lessThan(tester.getTopLeft(find.text('Sinkronisasi')).dy),
    );

    await cleanup();
  });
}
