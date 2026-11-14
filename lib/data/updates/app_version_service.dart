import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/entities/app_update.dart';

class AppVersionService {
  const AppVersionService();

  Future<AppVersionInfo> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return AppVersionInfo(
        versionName: info.version.isEmpty ? '0.0.0' : info.version,
        buildNumber: int.tryParse(info.buildNumber) ?? 0,
      );
    } catch (_) {
      // Widget tests and unsupported platforms may not provide package info.
      return const AppVersionInfo(versionName: '0.0.0', buildNumber: 0);
    }
  }
}
