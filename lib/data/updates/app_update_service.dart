import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/repositories/app_update_repository.dart';

/// Dilempar ketika pengguna membatalkan unduhan.
class AppUpdateCancelledException implements Exception {
  const AppUpdateCancelledException();
}

class AppUpdateService {
  AppUpdateService({
    required this.repository,
    required this.installer,
    http.Client? client,
    this.cacheDirectory,
    this.timeout = const Duration(minutes: 5),
  }) : _client = client ?? http.Client();

  static const int storageReserveBytes = 5 * 1024 * 1024;

  static const Set<String> allowedDownloadHosts = <String>{
    'github.com',
    'objects.githubusercontent.com',
    'api.github.com',
  };

  final AppUpdateRepository repository;
  final ApkInstallerGateway installer;
  final Duration timeout;
  final http.Client _client;
  final Directory? cacheDirectory;

  Future<AppUpdateInfo?> check() => repository.fetchLatest();

  Future<File> download(
    AppUpdateInfo update, {
    void Function(int received, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final uri = _downloadUri(update.apkUrl);
    int? availableBytes;
    try {
      availableBytes = await installer.availableStorageBytes();
    } catch (_) {
      availableBytes = null;
    }
    if (availableBytes != null &&
        availableBytes >= 0 &&
        availableBytes < update.apkSizeBytes + storageReserveBytes) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Ruang penyimpanan tidak cukup untuk mengunduh update.',
      );
    }

    final directory = await _updatesDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fileName = update.apkAsset.split(RegExp(r'[/\\]')).last;
    final target = File('${directory.path}/$fileName');
    if (await target.exists()) {
      await target.delete();
    }

    IOSink? sink;
    try {
      final request = http.Request('GET', uri);
      final response = await _client.send(request).timeout(timeout);
      if (response.statusCode != 200) {
        throw AppException(
          code: AppErrorCode.remoteUnavailable,
          message: 'APK update tidak dapat diunduh (${response.statusCode}).',
        );
      }

      final total = response.contentLength ?? update.apkSizeBytes;
      var received = 0;
      sink = target.openWrite();
      await for (final chunk in response.stream.timeout(timeout)) {
        if (isCancelled?.call() ?? false) {
          throw const AppUpdateCancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (isCancelled?.call() ?? false) {
        throw const AppUpdateCancelledException();
      }

      if (received != update.apkSizeBytes) {
        throw const AppException(
          code: AppErrorCode.validation,
          message: 'Ukuran APK update tidak sesuai.',
        );
      }

      final digest = await sha256.bind(target.openRead()).first;
      if (digest.toString().toLowerCase() != update.apkSha256.toLowerCase()) {
        throw const AppException(
          code: AppErrorCode.validation,
          message: 'Checksum APK update tidak cocok. Unduhan dibatalkan.',
        );
      }

      return target;
    } catch (error) {
      await sink?.close();
      if (await target.exists()) {
        await target.delete();
      }
      if (error is AppException || error is AppUpdateCancelledException) {
        rethrow;
      }
      if (error is TimeoutException || error is http.ClientException) {
        throw AppException(
          code: AppErrorCode.offline,
          message: 'Unduhan update terputus. Coba lagi.',
          cause: error,
        );
      }
      throw AppException(
        code: AppErrorCode.remoteUnavailable,
        message: 'Unduhan update gagal.',
        cause: error,
      );
    }
  }

  Future<AppInstallerPermission> installerPermission() {
    return installer.permission();
  }

  Future<void> openInstallPermissionSettings() {
    return installer.openInstallPermissionSettings();
  }

  Future<AppInstallerResult> install({
    required File file,
    required AppUpdateInfo update,
  }) {
    return installer.install(
      apkPath: file.path,
      packageName: 'com.debtreminder.app',
      versionCode: update.buildNumber,
    );
  }

  Future<void> cleanup() async {
    final directory = await _updatesDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> _updatesDirectory() async {
    final base = cacheDirectory ?? await getTemporaryDirectory();
    return Directory('${base.path}/updates');
  }

  Uri _downloadUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !allowedDownloadHosts.contains(uri.host)) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'URL unduhan update tidak aman.',
      );
    }
    return uri;
  }
}
