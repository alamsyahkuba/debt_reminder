import 'package:flutter/services.dart';

import '../../domain/entities/app_update.dart';
import '../../domain/repositories/app_update_repository.dart';

class MethodChannelApkInstaller implements ApkInstallerGateway {
  MethodChannelApkInstaller({
    this.channel = const MethodChannel('com.debtreminder.app/installer'),
  });

  final MethodChannel channel;

  @override
  Future<AppInstallerPermission> permission() async {
    try {
      final value = await channel.invokeMethod<String>(
        'canRequestPackageInstalls',
      );
      return value == 'allowed'
          ? AppInstallerPermission.allowed
          : AppInstallerPermission.denied;
    } on MissingPluginException {
      return AppInstallerPermission.unavailable;
    } on PlatformException {
      return AppInstallerPermission.unavailable;
    }
  }

  @override
  Future<int?> availableStorageBytes() async {
    try {
      final value = await channel.invokeMethod<num>('availableStorageBytes');
      return value?.toInt();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    try {
      await channel.invokeMethod<void>('openInstallPermissionSettings');
    } on MissingPluginException {
      throw const AppUpdatePlatformException(
        'Pengaturan izin installer tidak tersedia.',
      );
    } on PlatformException catch (error) {
      throw AppUpdatePlatformException(
        error.message ?? 'Pengaturan izin installer tidak dapat dibuka.',
      );
    }
  }

  @override
  Future<AppInstallerResult> install({
    required String apkPath,
    required String packageName,
    required int versionCode,
  }) async {
    try {
      final value = await channel.invokeMapMethod<String, dynamic>(
        'installApk',
        <String, Object?>{
          'apkPath': apkPath,
          'packageName': packageName,
          'versionCode': versionCode,
        },
      );
      final status = _status(value?['status'] as String?);
      return AppInstallerResult(
        status: status,
        message: value?['message'] as String?,
      );
    } on MissingPluginException {
      return const AppInstallerResult(
        status: AppInstallerStatus.unavailable,
        message: 'Installer Android tidak tersedia.',
      );
    } on PlatformException catch (error) {
      return AppInstallerResult(
        status: AppInstallerStatus.failed,
        message: error.message,
      );
    }
  }

  AppInstallerStatus _status(String? value) {
    return switch (value) {
      'installer_opened' => AppInstallerStatus.installerOpened,
      'permission_required' => AppInstallerStatus.permissionRequired,
      'invalid_package' => AppInstallerStatus.invalidPackage,
      'signature_mismatch' => AppInstallerStatus.signatureMismatch,
      'unavailable' => AppInstallerStatus.unavailable,
      _ => AppInstallerStatus.failed,
    };
  }
}

class AppUpdatePlatformException implements Exception {
  const AppUpdatePlatformException(this.message);

  final String message;
}
