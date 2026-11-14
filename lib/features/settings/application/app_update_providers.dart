import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../../../data/remote/github_release_repository.dart';
import '../../../data/updates/app_update_service.dart';
import '../../../data/updates/app_version_service.dart';
import '../../../data/updates/method_channel_apk_installer.dart';
import '../../../domain/entities/app_update.dart';
import '../../../domain/repositories/app_update_repository.dart';

enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  readyToInstall,
  permissionRequired,
  installerOpened,
  error,
}

final class AppUpdateState {
  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.current,
    this.update,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.error,
    this.file,
  });

  final AppUpdateStatus status;
  final AppVersionInfo? current;
  final AppUpdateInfo? update;
  final int receivedBytes;
  final int totalBytes;
  final String? error;
  final File? file;

  double? get progress {
    if (totalBytes <= 0) {
      return null;
    }
    return (receivedBytes / totalBytes).clamp(0, 1).toDouble();
  }

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    AppVersionInfo? current,
    AppUpdateInfo? update,
    int? receivedBytes,
    int? totalBytes,
    String? error,
    bool clearError = false,
    File? file,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      current: current ?? this.current,
      update: update ?? this.update,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      error: clearError ? null : (error ?? this.error),
      file: file ?? this.file,
    );
  }
}

final appVersionServiceProvider = Provider<AppVersionService>(
  (ref) => const AppVersionService(),
);

final appVersionProvider = FutureProvider<AppVersionInfo>(
  (ref) => ref.watch(appVersionServiceProvider).load(),
);

final githubReleaseRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return GitHubReleaseRepository(
    owner: 'alamsyahkuba',
    repo: 'debt_reminder',
    client: client,
  );
});

final apkInstallerProvider = Provider<ApkInstallerGateway>(
  (ref) => MethodChannelApkInstaller(),
);

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AppUpdateService(
    repository: ref.watch(githubReleaseRepositoryProvider),
    installer: ref.watch(apkInstallerProvider),
    client: client,
  );
});

final appUpdateControllerProvider =
    NotifierProvider<AppUpdateController, AppUpdateState>(
      AppUpdateController.new,
    );

class AppUpdateController extends Notifier<AppUpdateState> {
  bool _cancelRequested = false;

  @override
  AppUpdateState build() => const AppUpdateState();

  Future<void> check() async {
    if (state.status == AppUpdateStatus.checking ||
        state.status == AppUpdateStatus.downloading) {
      return;
    }

    state = state.copyWith(
      status: AppUpdateStatus.checking,
      clearError: true,
      receivedBytes: 0,
      totalBytes: 0,
    );

    try {
      await ref.read(appUpdateServiceProvider).cleanup();
      final current = await ref.read(appVersionProvider.future);
      final latest = await ref.read(appUpdateServiceProvider).check();
      if (latest != null && latest.isNewerThan(current.buildNumber)) {
        state = AppUpdateState(
          status: AppUpdateStatus.available,
          current: current,
          update: latest,
        );
      } else {
        state = AppUpdateState(
          status: AppUpdateStatus.upToDate,
          current: current,
          update: latest,
        );
      }
    } on AppException catch (error) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: 'Pembaruan tidak dapat diperiksa. Coba lagi.',
      );
    }
  }

  Future<void> downloadAndInstall() async {
    final update = state.update;
    if (update == null ||
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.checking) {
      return;
    }

    _cancelRequested = false;
    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      receivedBytes: 0,
      totalBytes: update.apkSizeBytes,
      clearError: true,
    );

    try {
      final file = await ref
          .read(appUpdateServiceProvider)
          .download(
            update,
            onProgress: (received, total) {
              state = state.copyWith(
                receivedBytes: received,
                totalBytes: total,
              );
            },
            isCancelled: () => _cancelRequested,
          );

      if (_cancelRequested) {
        _cancelRequested = false;
        await ref.read(appUpdateServiceProvider).cleanup();
        state = state.copyWith(
          status: AppUpdateStatus.available,
          receivedBytes: 0,
          totalBytes: 0,
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        status: AppUpdateStatus.readyToInstall,
        file: file,
      );

      final permission = await ref
          .read(appUpdateServiceProvider)
          .installerPermission();
      if (permission == AppInstallerPermission.allowed) {
        await _install(file, update);
      } else {
        state = state.copyWith(status: AppUpdateStatus.permissionRequired);
      }
    } on AppUpdateCancelledException {
      _cancelRequested = false;
      state = state.copyWith(
        status: AppUpdateStatus.available,
        receivedBytes: 0,
        totalBytes: 0,
        clearError: true,
      );
    } on AppException catch (error) {
      _cancelRequested = false;
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: error.message,
      );
    } on AppUpdatePlatformException catch (error) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: 'Pembaruan tidak dapat diunduh.',
      );
    }
  }

  void cancelDownload() {
    if (state.status == AppUpdateStatus.downloading) {
      _cancelRequested = true;
    }
  }

  Future<void> installDownloaded() async {
    final update = state.update;
    final file = state.file;
    if (update == null || file == null) {
      return;
    }

    try {
      final permission = await ref
          .read(appUpdateServiceProvider)
          .installerPermission();
      if (permission != AppInstallerPermission.allowed) {
        state = state.copyWith(status: AppUpdateStatus.permissionRequired);
        return;
      }
      await _install(file, update);
    } on AppUpdatePlatformException catch (error) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: 'Installer tidak dapat dibuka.',
      );
    }
  }

  Future<void> openInstallPermissionSettings() async {
    try {
      await ref.read(appUpdateServiceProvider).openInstallPermissionSettings();
      state = state.copyWith(status: AppUpdateStatus.permissionRequired);
    } on AppUpdatePlatformException catch (error) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: 'Pengaturan izin tidak dapat dibuka.',
      );
    }
  }

  Future<void> reset() async {
    _cancelRequested = false;
    state = const AppUpdateState();
    await ref.read(appUpdateServiceProvider).cleanup();
  }

  Future<void> _install(File file, AppUpdateInfo update) async {
    final result = await ref
        .read(appUpdateServiceProvider)
        .install(file: file, update: update);

    switch (result.status) {
      case AppInstallerStatus.installerOpened:
        state = state.copyWith(status: AppUpdateStatus.installerOpened);
      case AppInstallerStatus.permissionRequired:
        state = state.copyWith(status: AppUpdateStatus.permissionRequired);
      case AppInstallerStatus.signatureMismatch:
        state = state.copyWith(
          status: AppUpdateStatus.error,
          error: 'Tanda tangan APK tidak cocok. Update dibatalkan.',
        );
      case AppInstallerStatus.invalidPackage:
        state = state.copyWith(
          status: AppUpdateStatus.error,
          error: 'APK update bukan paket aplikasi yang valid.',
        );
      case AppInstallerStatus.unavailable:
        state = state.copyWith(
          status: AppUpdateStatus.error,
          error: 'Installer Android tidak tersedia.',
        );
      case AppInstallerStatus.failed:
        state = state.copyWith(
          status: AppUpdateStatus.error,
          error: result.message ?? 'Installer tidak dapat dibuka.',
        );
    }
  }
}
