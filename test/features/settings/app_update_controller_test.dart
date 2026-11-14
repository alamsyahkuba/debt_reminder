import 'dart:io';

import 'package:debt_reminder/core/errors/app_exception.dart';
import 'package:debt_reminder/data/updates/app_update_service.dart';
import 'package:debt_reminder/domain/entities/app_update.dart';
import 'package:debt_reminder/domain/repositories/app_update_repository.dart';
import 'package:debt_reminder/features/settings/application/app_update_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUpdateInfo _update({int buildNumber = 2}) {
  return AppUpdateInfo(
    versionName: '1.1.0',
    buildNumber: buildNumber,
    tag: 'v1.1.0',
    apkAsset: 'debt-reminder-v1.1.0+$buildNumber.apk',
    apkUrl:
        'https://github.com/alamsyahkuba/debt_reminder/releases/download/'
        'v1.1.0/debt-reminder-v1.1.0+$buildNumber.apk',
    apkSha256: List<String>.filled(64, 'a').join(),
    apkSizeBytes: 1024,
    releaseUrl:
        'https://github.com/alamsyahkuba/debt_reminder/releases/tag/v1.1.0',
    publishedAt: DateTime.utc(2026, 11, 14, 8),
    notes: 'Catatan rilis.',
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
  Object? downloadError;
  File? downloadFile;
  bool waitForCancel = false;
  AppInstallerPermission permission = AppInstallerPermission.allowed;
  AppInstallerResult installResult = const AppInstallerResult(
    status: AppInstallerStatus.installerOpened,
  );
  Object? installSettingsError;
  int installCalls = 0;
  int permissionSettingsCalls = 0;
  bool cleanupCalled = false;

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
    if (waitForCancel) {
      while (!(isCancelled?.call() ?? false)) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      throw const AppUpdateCancelledException();
    }
    if (downloadError != null) {
      throw downloadError!;
    }
    onProgress?.call(512, 1024);
    return downloadFile ?? File('/tmp/update.apk');
  }

  @override
  Future<AppInstallerPermission> installerPermission() async => permission;

  @override
  Future<AppInstallerResult> install({
    required File file,
    required AppUpdateInfo update,
  }) async {
    installCalls++;
    return installResult;
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    permissionSettingsCalls++;
    if (installSettingsError != null) {
      throw installSettingsError!;
    }
  }

  @override
  Future<void> cleanup() async {
    cleanupCalled = true;
  }
}

void main() {
  late _FakeUpdateService service;
  late AppVersionInfo current;
  late ProviderContainer container;

  AppUpdateController controller() {
    return container.read(appUpdateControllerProvider.notifier);
  }

  AppUpdateState state() => container.read(appUpdateControllerProvider);

  setUp(() {
    service = _FakeUpdateService();
    current = const AppVersionInfo(versionName: '1.0.0', buildNumber: 1);
    container = ProviderContainer.test(
      overrides: [
        appVersionProvider.overrideWith((ref) async => current),
        appUpdateServiceProvider.overrideWithValue(service),
      ],
    );
  });

  test('update yang lebih baru tersedia dan cache lama dibersihkan', () async {
    service.checkResult = _update();

    await controller().check();

    expect(state().status, AppUpdateStatus.available);
    expect(state().current?.buildNumber, 1);
    expect(state().update?.buildNumber, 2);
    expect(state().error, isNull);
    expect(service.cleanupCalled, isTrue);
  });

  test('build yang sama dianggap versi terbaru', () async {
    service.checkResult = _update(buildNumber: 1);

    await controller().check();

    expect(state().status, AppUpdateStatus.upToDate);
    expect(state().update?.buildNumber, 1);
  });

  test('build remote yang lebih rendah tidak menawarkan downgrade', () async {
    current = const AppVersionInfo(versionName: '2.0.0', buildNumber: 3);
    service.checkResult = _update(buildNumber: 2);

    await controller().check();

    expect(state().status, AppUpdateStatus.upToDate);
  });

  test('kegagalan pengecekan menampilkan pesan retry', () async {
    service.checkError = const AppException(
      code: AppErrorCode.offline,
      message: 'Tidak dapat terhubung ke server pembaruan.',
    );

    await controller().check();

    expect(state().status, AppUpdateStatus.error);
    expect(state().error, 'Tidak dapat terhubung ke server pembaruan.');
  });

  test('download dan install yang diizinkan membuka installer', () async {
    service.checkResult = _update();
    await controller().check();

    await controller().downloadAndInstall();

    expect(state().status, AppUpdateStatus.installerOpened);
    expect(state().file, isNotNull);
    expect(service.installCalls, 1);
  });

  test('izin installer yang ditolak menampilkan pengaturan izin', () async {
    service.checkResult = _update();
    service.permission = AppInstallerPermission.denied;
    await controller().check();

    await controller().downloadAndInstall();

    expect(state().status, AppUpdateStatus.permissionRequired);
    expect(state().file, isNotNull);
    expect(service.installCalls, 0);
  });

  test('pembatalan download kembali ke state update tersedia', () async {
    service
      ..checkResult = _update()
      ..waitForCancel = true;
    await controller().check();

    final downloading = controller().downloadAndInstall();
    expect(state().status, AppUpdateStatus.downloading);
    controller().cancelDownload();
    await downloading.timeout(const Duration(seconds: 2));

    expect(state().status, AppUpdateStatus.available);
    expect(state().error, isNull);
    expect(state().receivedBytes, 0);
    expect(service.installCalls, 0);
  });

  test('kegagalan download menampilkan error tanpa install', () async {
    service.checkResult = _update();
    service.downloadError = const AppException(
      code: AppErrorCode.remoteUnavailable,
      message: 'Unduhan update gagal.',
    );
    await controller().check();

    await controller().downloadAndInstall();

    expect(state().status, AppUpdateStatus.error);
    expect(state().error, 'Unduhan update gagal.');
    expect(service.installCalls, 0);
  });

  test('signature mismatch menolak update', () async {
    service.checkResult = _update();
    service.installResult = const AppInstallerResult(
      status: AppInstallerStatus.signatureMismatch,
    );
    await controller().check();

    await controller().downloadAndInstall();

    expect(state().status, AppUpdateStatus.error);
    expect(state().error, contains('Tanda tangan APK tidak cocok'));
    expect(service.installCalls, 1);
  });

  test('install ulang file yang sudah diunduh memakai izin terbaru', () async {
    service.checkResult = _update();
    service.permission = AppInstallerPermission.denied;
    await controller().check();
    await controller().downloadAndInstall();
    expect(state().status, AppUpdateStatus.permissionRequired);

    service.permission = AppInstallerPermission.allowed;
    await controller().installDownloaded();

    expect(state().status, AppUpdateStatus.installerOpened);
    expect(service.installCalls, 1);
  });

  test('membuka pengaturan izin mempertahankan state izin', () async {
    service.checkResult = _update();
    service.permission = AppInstallerPermission.denied;
    await controller().check();
    await controller().downloadAndInstall();

    await controller().openInstallPermissionSettings();

    expect(service.permissionSettingsCalls, 1);
    expect(state().status, AppUpdateStatus.permissionRequired);
  });

  test('reset membersihkan state dan cache', () async {
    service.checkResult = _update();
    await controller().check();

    await controller().reset();

    expect(state().status, AppUpdateStatus.idle);
    expect(state().update, isNull);
    expect(service.cleanupCalled, isTrue);
  });
}
