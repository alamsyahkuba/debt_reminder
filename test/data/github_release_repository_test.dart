import 'dart:convert';

import 'package:debt_reminder/core/errors/app_exception.dart';
import 'package:debt_reminder/data/remote/github_release_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _owner = 'alamsyahkuba';
const String _repo = 'debt_reminder';
const String _manifestUrl =
    'https://github.com/alamsyahkuba/debt_reminder/releases/download/'
    'v1.1.0/latest.json';
const String _apkUrl =
    'https://github.com/alamsyahkuba/debt_reminder/releases/download/'
    'v1.1.0/debt-reminder-v1.1.0+2.apk';
const String _releaseUrl =
    'https://github.com/alamsyahkuba/debt_reminder/releases/tag/v1.1.0';

final String _sha256 = List<String>.filled(64, 'a').join();

Map<String, Object?> _manifest({
  int schemaVersion = 1,
  int buildNumber = 2,
  String? apkSha256,
  String apkAsset = 'debt-reminder-v1.1.0+2.apk',
  String releaseUrl = _releaseUrl,
  String tag = 'v1.1.0',
}) {
  return <String, Object?>{
    'schema_version': schemaVersion,
    'version_name': '1.1.0',
    'build_number': buildNumber,
    'tag': tag,
    'apk_asset': apkAsset,
    'apk_sha256': apkSha256 ?? _sha256,
    'apk_size_bytes': 1024,
    'release_url': releaseUrl,
    'published_at': '2026-11-14T08:00:00Z',
    'notes': '  Perbaikan bug dan peningkatan stabilitas.  ',
  };
}

Map<String, Object?> _release({
  bool draft = false,
  bool prerelease = false,
  String manifestUrl = _manifestUrl,
  String apkUrl = _apkUrl,
}) {
  return <String, Object?>{
    'draft': draft,
    'prerelease': prerelease,
    'tag_name': 'v1.1.0',
    'html_url': _releaseUrl,
    'assets': <Map<String, Object?>>[
      <String, Object?>{
        'name': 'latest.json',
        'browser_download_url': manifestUrl,
        'size': 256,
      },
      <String, Object?>{
        'name': 'debt-reminder-v1.1.0+2.apk',
        'browser_download_url': apkUrl,
        'size': 1024,
      },
    ],
  };
}

GitHubReleaseRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) {
  return GitHubReleaseRepository(
    owner: _owner,
    repo: _repo,
    client: MockClient(handler),
  );
}

Future<http.Response> _releaseAndManifest(
  http.Request request, {
  Map<String, Object?>? release,
  Map<String, Object?>? manifest,
}) async {
  if (request.url.path.endsWith('/releases/latest')) {
    return http.Response(
      jsonEncode(release ?? _release()),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
  if (request.url.path.endsWith('/latest.json')) {
    return http.Response(
      jsonEncode(manifest ?? _manifest()),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }
  return http.Response('tidak ditemukan', 404);
}

void main() {
  test('mem-parsing release publik dan manifest update', () async {
    final repository = _repository(_releaseAndManifest);

    final update = await repository.fetchLatest();

    expect(update, isNotNull);
    expect(update!.versionName, '1.1.0');
    expect(update.buildNumber, 2);
    expect(update.tag, 'v1.1.0');
    expect(update.apkAsset, 'debt-reminder-v1.1.0+2.apk');
    expect(update.apkUrl, _apkUrl);
    expect(update.apkSha256, _sha256);
    expect(update.apkSizeBytes, 1024);
    expect(update.releaseUrl, _releaseUrl);
    expect(update.publishedAt, DateTime.utc(2026, 11, 14, 8));
    expect(update.notes, 'Perbaikan bug dan peningkatan stabilitas.');
    expect(update.isNewerThan(1), isTrue);
    expect(update.isNewerThan(2), isFalse);
    expect(update.isNewerThan(3), isFalse);
  });

  test('release tidak ditemukan menghasilkan null', () async {
    final repository = _repository(
      (request) async => http.Response('tidak ditemukan', 404),
    );

    expect(await repository.fetchLatest(), isNull);
  });

  test('release draft dan prerelease diabaikan', () async {
    for (final release in <Map<String, Object?>>[
      _release(draft: true),
      _release(prerelease: true),
    ]) {
      var manifestRequested = false;
      final repository = _repository((request) async {
        if (request.url.path.endsWith('/latest.json')) {
          manifestRequested = true;
        }
        return _releaseAndManifest(request, release: release);
      });

      expect(await repository.fetchLatest(), isNull);
      expect(manifestRequested, isFalse);
    }
  });

  test('release tanpa latest.json ditolak', () async {
    final repository = _repository((request) async {
      return http.Response(
        jsonEncode(<String, Object?>{
          'draft': false,
          'prerelease': false,
          'assets': <Object?>[],
        }),
        200,
      );
    });

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Manifest update belum tersedia'),
            ),
      ),
    );
  });

  test('schema manifest yang tidak didukung ditolak', () async {
    final repository = _repository(
      (request) =>
          _releaseAndManifest(request, manifest: _manifest(schemaVersion: 2)),
    );

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Versi manifest update tidak didukung'),
            ),
      ),
    );
  });

  test('tag manifest yang berbeda dari release ditolak', () async {
    final repository = _repository(
      (request) =>
          _releaseAndManifest(request, manifest: _manifest(tag: 'v9.9.9')),
    );

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Tag manifest tidak cocok dengan release'),
            ),
      ),
    );
  });

  test('checksum manifest yang tidak valid ditolak', () async {
    final repository = _repository(
      (request) => _releaseAndManifest(
        request,
        manifest: _manifest(apkSha256: 'bukan-checksum'),
      ),
    );

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Checksum APK pada manifest tidak valid'),
            ),
      ),
    );
  });

  test('asset APK yang tidak ada di release ditolak', () async {
    final repository = _repository(
      (request) => _releaseAndManifest(
        request,
        manifest: _manifest(apkAsset: 'apk-lain.apk'),
      ),
    );

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Asset APK pada manifest tidak ditemukan'),
            ),
      ),
    );
  });

  test('URL manifest non-HTTPS atau di luar allowlist ditolak', () async {
    final repository = _repository(
      (request) => _releaseAndManifest(
        request,
        release: _release(manifestUrl: 'http://evil.example/latest.json'),
      ),
    );

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Manifest update harus menggunakan HTTPS dari GitHub'),
            ),
      ),
    );
  });

  test('URL APK di luar allowlist ditolak', () async {
    final repository = _repository(
      (request) => _releaseAndManifest(
        request,
        release: _release(apkUrl: 'https://evil.example/app.apk'),
      ),
    );

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('APK update harus menggunakan HTTPS dari GitHub'),
            ),
      ),
    );
  });

  test('URL release non-HTTPS ditolak', () async {
    final repository = _repository(
      (request) => _releaseAndManifest(
        request,
        manifest: _manifest(
          releaseUrl: 'http://github.com/alamsyahkuba/debt_reminder',
        ),
      ),
    );

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Halaman release harus menggunakan HTTPS dari GitHub'),
            ),
      ),
    );
  });

  test('manifest bukan JSON yang valid ditolak', () async {
    final repository = _repository((request) async {
      if (request.url.path.endsWith('/latest.json')) {
        return http.Response('<html>error</html>', 200);
      }
      return http.Response(jsonEncode(_release()), 200);
    });

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having((error) => error.code, 'code', AppErrorCode.validation)
            .having(
              (error) => error.message,
              'message',
              contains('Manifest update bukan JSON yang valid'),
            ),
      ),
    );
  });

  test('respons API selain 200/404 menjadi remoteUnavailable', () async {
    final repository = _repository(
      (request) async => http.Response('server error', 500),
    );

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having(
              (error) => error.code,
              'code',
              AppErrorCode.remoteUnavailable,
            )
            .having(
              (error) => error.message,
              'message',
              contains('Pembaruan tidak dapat diperiksa (500)'),
            ),
      ),
    );
  });

  test('rate limit GitHub menghasilkan pesan coba lagi', () async {
    final repository = _repository(
      (request) async => http.Response('rate limit', 403),
    );

    await expectLater(
      repository.fetchLatest(),
      throwsA(
        isA<AppException>()
            .having(
              (error) => error.code,
              'code',
              AppErrorCode.remoteUnavailable,
            )
            .having(
              (error) => error.message,
              'message',
              contains('Batas pengecekan GitHub tercapai'),
            ),
      ),
    );
  });
}
