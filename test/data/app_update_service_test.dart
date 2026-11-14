import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:debt_reminder/core/errors/app_exception.dart';
import 'package:debt_reminder/data/updates/app_update_service.dart';
import 'package:debt_reminder/domain/entities/app_update.dart';
import 'package:debt_reminder/domain/repositories/app_update_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _allowedUrl =
    'https://github.com/alamsyahkuba/debt_reminder/releases/download/'
    'v1.1.0/debt-reminder-v1.1.0+2.apk';

final List<int> _apkBytes = utf8.encode('isi-apk-update-uji');

String _checksum(List<int> bytes) => sha256.convert(bytes).toString();

AppUpdateInfo _update({String? apkUrl, String? apkSha256, int? apkSizeBytes}) {
  return AppUpdateInfo(
    versionName: '1.1.0',
    buildNumber: 2,
    tag: 'v1.1.0',
    apkAsset: 'debt-reminder-v1.1.0+2.apk',
    apkUrl: apkUrl ?? _allowedUrl,
    apkSha256: apkSha256 ?? _checksum(_apkBytes),
    apkSizeBytes: apkSizeBytes ?? _apkBytes.length,
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
  String? apkPath;
  String? packageName;
  int? versionCode;
  int? availableBytes = 200 * 1024 * 1024;
  AppInstallerPermission permissionValue = AppInstallerPermission.allowed;
  AppInstallerResult result = const AppInstallerResult(
    status: AppInstallerStatus.installerOpened,
  );
  bool openedSettings = false;

  @override
  Future<int?> availableStorageBytes() async => availableBytes;

  @override
  Future<AppInstallerResult> install({
    required String apkPath,
    required String packageName,
    required int versionCode,
  }) async {
    this.apkPath = apkPath;
    this.packageName = packageName;
    this.versionCode = versionCode;
    return result;
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    openedSettings = true;
  }

  @override
  Future<AppInstallerPermission> permission() async => permissionValue;
}

void main() {
  late Directory cache;
  late _FakeInstaller installer;

  AppUpdateService service(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return AppUpdateService(
      repository: _FakeRepository(),
      installer: installer,
      client: MockClient(handler),
      cacheDirectory: cache,
    );
  }

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('debt_update_test_');
    installer = _FakeInstaller();
  });

  tearDown(() async {
    if (await cache.exists()) {
      await cache.delete(recursive: true);
    }
  });

  test('ruang penyimpanan tidak cukup ditolak sebelum download', () async {
    var requested = false;
    installer.availableBytes = 1024;
    final download = service((request) async {
      requested = true;
      return http.Response.bytes(_apkBytes, 200);
    });

    await expectLater(
      download.download(_update()),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Ruang penyimpanan tidak cukup'),
            ),
      ),
    );

    expect(requested, isFalse);
  });

  test(
    'mengunduh APK, memverifikasi checksum, dan melaporkan progress',
    () async {
      final requestedUrls = <Uri>[];
      final progress = <int>[];
      final download = service((request) async {
        requestedUrls.add(request.url);
        return http.Response.bytes(
          _apkBytes,
          200,
          headers: <String, String>{'content-length': '${_apkBytes.length}'},
        );
      });

      final file = await download.download(
        _update(),
        onProgress: (received, total) {
          expect(total, _apkBytes.length);
          progress.add(received);
        },
      );

      expect(requestedUrls, <Uri>[Uri.parse(_allowedUrl)]);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), _apkBytes);
      expect(file.path, contains('${cache.path}/updates/'));
      expect(progress, isNotEmpty);
      expect(progress.last, _apkBytes.length);
    },
  );

  test('checksum salah menghapus file dan menolak update', () async {
    final download = service(
      (request) async => http.Response.bytes(_apkBytes, 200),
    );

    await expectLater(
      download.download(
        _update(apkSha256: List<String>.filled(64, 'b').join()),
      ),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Checksum APK update tidak cocok'),
            ),
      ),
    );

    final target = File('${cache.path}/updates/debt-reminder-v1.1.0+2.apk');
    expect(await target.exists(), isFalse);
  });

  test('ukuran APK yang tidak sesuai ditolak', () async {
    final download = service(
      (request) async => http.Response.bytes(_apkBytes, 200),
    );

    await expectLater(
      download.download(_update(apkSizeBytes: _apkBytes.length + 10)),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Ukuran APK update tidak sesuai'),
            ),
      ),
    );
  });

  test('respons HTTP gagal tidak meninggalkan file parsial', () async {
    final download = service((request) async => http.Response('gagal', 500));

    await expectLater(
      download.download(_update()),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          AppErrorCode.remoteUnavailable,
        ),
      ),
    );

    final updates = Directory('${cache.path}/updates');
    expect(await updates.exists(), isTrue);
    expect(await updates.list().toList(), isEmpty);
  });

  test('pembatalan unduhan menghapus file parsial', () async {
    final download = service(
      (request) async => http.Response.bytes(_apkBytes, 200),
    );

    await expectLater(
      download.download(_update(), isCancelled: () => true),
      throwsA(isA<AppUpdateCancelledException>()),
    );

    final target = File('${cache.path}/updates/debt-reminder-v1.1.0+2.apk');
    expect(await target.exists(), isFalse);
  });

  test('URL unduhan non-HTTPS atau di luar allowlist ditolak', () async {
    var requested = false;
    final download = service((request) async {
      requested = true;
      return http.Response.bytes(_apkBytes, 200);
    });

    await expectLater(
      download.download(_update(apkUrl: 'http://evil.example/app.apk')),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('URL unduhan update tidak aman'),
            ),
      ),
    );

    expect(requested, isFalse);
  });

  test('install meneruskan package dan version code yang diharapkan', () async {
    final updates = Directory('${cache.path}/updates');
    await updates.create(recursive: true);
    final file = File('${updates.path}/app.apk');
    await file.writeAsBytes(_apkBytes);
    final update = _update();

    final result = await service((request) async => http.Response('', 200))
        .install(file: file, update: update);

    expect(result.status, AppInstallerStatus.installerOpened);
    expect(installer.apkPath, file.path);
    expect(installer.packageName, 'com.debtreminder.app');
    expect(installer.versionCode, 2);
  });

  test('cleanup menghapus direktori update', () async {
    final updates = Directory('${cache.path}/updates');
    await updates.create(recursive: true);
    await File('${updates.path}/lama.apk').writeAsBytes(_apkBytes);

    await service((request) async => http.Response('', 200)).cleanup();

    expect(await updates.exists(), isFalse);
  });
}
