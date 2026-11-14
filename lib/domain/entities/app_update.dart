/// Informasi update yang diterima dari manifest release publik.
final class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionName,
    required this.buildNumber,
    required this.tag,
    required this.apkAsset,
    required this.apkUrl,
    required this.apkSha256,
    required this.apkSizeBytes,
    required this.releaseUrl,
    required this.publishedAt,
    required this.notes,
  });

  final String versionName;
  final int buildNumber;
  final String tag;
  final String apkAsset;
  final String apkUrl;
  final String apkSha256;
  final int apkSizeBytes;
  final String releaseUrl;
  final DateTime publishedAt;
  final String notes;

  bool isNewerThan(int currentBuildNumber) => buildNumber > currentBuildNumber;
}

/// Versi aplikasi yang sedang terpasang.
final class AppVersionInfo {
  const AppVersionInfo({required this.versionName, required this.buildNumber});

  final String versionName;
  final int buildNumber;
}

/// Hasil pengecekan update.
final class AppUpdateCheck {
  const AppUpdateCheck({required this.current, required this.available});

  final AppVersionInfo current;
  final AppUpdateInfo? available;

  bool get hasUpdate => available != null;
}

enum AppInstallerPermission { allowed, denied, unavailable }

final class AppInstallerResult {
  const AppInstallerResult({required this.status, this.message});

  final AppInstallerStatus status;
  final String? message;
}

enum AppInstallerStatus {
  installerOpened,
  permissionRequired,
  invalidPackage,
  signatureMismatch,
  unavailable,
  failed,
}
