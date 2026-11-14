import '../entities/app_update.dart';

abstract interface class AppUpdateRepository {
  /// Returns null when the latest public release has no newer build.
  Future<AppUpdateInfo?> fetchLatest();
}

abstract interface class ApkInstallerGateway {
  Future<AppInstallerPermission> permission();

  /// Returns available bytes in the app cache directory, or null if unknown.
  Future<int?> availableStorageBytes();

  Future<void> openInstallPermissionSettings();

  Future<AppInstallerResult> install({
    required String apkPath,
    required String packageName,
    required int versionCode,
  });
}
