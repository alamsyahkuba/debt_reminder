import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/repositories/app_update_repository.dart';

/// Reads the latest stable GitHub Release from a public repository.
class GitHubReleaseRepository implements AppUpdateRepository {
  GitHubReleaseRepository({
    required this.owner,
    required this.repo,
    http.Client? client,
    this.baseApiUrl = 'https://api.github.com',
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  static const Set<String> allowedHosts = <String>{
    'api.github.com',
    'github.com',
    'objects.githubusercontent.com',
  };

  final String owner;
  final String repo;
  final String baseApiUrl;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<AppUpdateInfo?> fetchLatest() async {
    final releaseUri = Uri.parse(
      '${baseApiUrl.replaceFirst(RegExp(r'/+$'), '')}'
      '/repos/$owner/$repo/releases/latest',
    );

    final response = await _send(
      () => _client
          .get(
            releaseUri,
            headers: const <String, String>{
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
              'User-Agent': 'Debt-Reminder-Updater',
            },
          )
          .timeout(timeout),
    );

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const AppException(
        code: AppErrorCode.remoteUnavailable,
        message: 'Batas pengecekan GitHub tercapai. Coba lagi beberapa saat.',
      );
    }
    if (response.statusCode != 200) {
      throw AppException(
        code: AppErrorCode.remoteUnavailable,
        message: 'Pembaruan tidak dapat diperiksa (${response.statusCode}).',
      );
    }

    final release = _decodeObject(response.body, 'Respons release');
    if (release['draft'] == true || release['prerelease'] == true) {
      return null;
    }

    final assets = _assets(release['assets']);
    final manifestAsset = _findAsset(assets, 'latest.json');
    if (manifestAsset == null) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Manifest update belum tersedia pada release terbaru.',
      );
    }

    final manifestResponse = await _send(
      () => _client
          .get(
            _httpsUri(manifestAsset.url, 'Manifest update'),
            headers: const <String, String>{
              'Accept': 'application/json',
              'User-Agent': 'Debt-Reminder-Updater',
            },
          )
          .timeout(timeout),
    );
    if (manifestResponse.statusCode != 200) {
      throw AppException(
        code: AppErrorCode.remoteUnavailable,
        message:
            'Manifest update tidak dapat diunduh '
            '(${manifestResponse.statusCode}).',
      );
    }

    final manifest = _decodeObject(manifestResponse.body, 'Manifest update');
    if (_asInt(manifest['schema_version']) != 1) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Versi manifest update tidak didukung.',
      );
    }

    final versionName = _requiredString(
      manifest['version_name'],
      'version_name',
    );
    final buildNumber = _requiredInt(manifest['build_number'], 'build_number');
    final tag = _requiredString(manifest['tag'], 'tag');
    final releaseTag = release['tag_name'];
    if (releaseTag is! String || releaseTag.trim() != tag) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Tag manifest tidak cocok dengan release.',
      );
    }
    final apkAssetName = _requiredString(manifest['apk_asset'], 'apk_asset');
    final apkSha256 = _requiredString(manifest['apk_sha256'], 'apk_sha256');
    final apkSize = _requiredInt(manifest['apk_size_bytes'], 'apk_size_bytes');
    final releaseUrl = _requiredString(manifest['release_url'], 'release_url');
    final publishedAt = _requiredTimestamp(
      manifest['published_at'],
      'published_at',
    );
    final notes = manifest['notes'] is String
        ? (manifest['notes'] as String).trim()
        : '';

    if (buildNumber < 1) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Build number pada manifest tidak valid.',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(apkSha256)) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Checksum APK pada manifest tidak valid.',
      );
    }
    if (apkSize < 1) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Ukuran APK pada manifest tidak valid.',
      );
    }

    final apkAsset = _findAsset(assets, apkAssetName);
    if (apkAsset == null) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Asset APK pada manifest tidak ditemukan.',
      );
    }

    return AppUpdateInfo(
      versionName: versionName,
      buildNumber: buildNumber,
      tag: tag,
      apkAsset: apkAsset.name,
      apkUrl: _httpsUri(apkAsset.url, 'APK update').toString(),
      apkSha256: apkSha256.toLowerCase(),
      apkSizeBytes: apkSize,
      releaseUrl: _httpsUri(releaseUrl, 'Halaman release').toString(),
      publishedAt: publishedAt,
      notes: notes,
    );
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on TimeoutException catch (error) {
      throw AppException(
        code: AppErrorCode.offline,
        message: 'Server pembaruan tidak merespons. Coba lagi.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw AppException(
        code: AppErrorCode.offline,
        message: 'Tidak dapat terhubung ke server pembaruan.',
        cause: error,
      );
    }
  }

  Map<String, Object?> _decodeObject(String source, String label) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw AppException(
        code: AppErrorCode.validation,
        message: '$label bukan JSON yang valid.',
      );
    }
    if (decoded is! Map) {
      throw AppException(
        code: AppErrorCode.validation,
        message: '$label bukan objek JSON.',
      );
    }
    return decoded.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  List<_GitHubAsset> _assets(Object? value) {
    if (value is! List) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'Daftar asset release tidak valid.',
      );
    }

    final assets = <_GitHubAsset>[];
    for (final item in value) {
      if (item is! Map) {
        continue;
      }
      final map = item.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final name = map['name'];
      final url = map['browser_download_url'];
      if (name is String && url is String) {
        assets.add(
          _GitHubAsset(name: name, url: url, size: _asInt(map['size']) ?? 0),
        );
      }
    }
    return assets;
  }

  _GitHubAsset? _findAsset(List<_GitHubAsset> assets, String name) {
    for (final asset in assets) {
      if (asset.name == name) {
        return asset;
      }
    }
    return null;
  }

  Uri _httpsUri(String value, String label) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !allowedHosts.contains(uri.host)) {
      throw AppException(
        code: AppErrorCode.validation,
        message: '$label harus menggunakan HTTPS dari GitHub.',
      );
    }
    return uri;
  }

  String _requiredString(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw AppException(
        code: AppErrorCode.validation,
        message: 'Field $field pada manifest tidak valid.',
      );
    }
    return value.trim();
  }

  int _requiredInt(Object? value, String field) {
    final parsed = _asInt(value);
    if (parsed == null) {
      throw AppException(
        code: AppErrorCode.validation,
        message: 'Field $field pada manifest tidak valid.',
      );
    }
    return parsed;
  }

  DateTime _requiredTimestamp(Object? value, String field) {
    if (value is! String || DateTime.tryParse(value) == null) {
      throw AppException(
        code: AppErrorCode.validation,
        message: 'Field $field pada manifest tidak valid.',
      );
    }
    return DateTime.parse(value).toUtc();
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}

final class _GitHubAsset {
  const _GitHubAsset({
    required this.name,
    required this.url,
    required this.size,
  });

  final String name;
  final String url;
  final int size;
}
