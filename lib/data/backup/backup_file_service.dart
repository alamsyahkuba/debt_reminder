import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/backup_document.dart';

/// File and share-sheet integration for admin backup/export.
class BackupFileService {
  static const int _maxBackupBytes = 10 * 1024 * 1024;

  Future<void> shareBackup(BackupDocument document) async {
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/debt-reminder-backup-${_timestamp(document.exportedAt)}.json',
    );
    await file.writeAsString(document.toPrettyJson(), flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'application/json')],
        subject: 'Backup Debt Reminder',
        text: 'Backup data Debt Reminder (group, hutang, pembayaran).',
      ),
    );
  }

  /// Returns null when the user cancels the file picker.
  Future<BackupDocument?> pickBackup() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Pilih file backup Debt Reminder',
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (files.isEmpty) {
      return null;
    }

    final picked = files.single;
    final size = await picked.length();
    if (size != null && size > _maxBackupBytes) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'File backup terlalu besar (maksimal 10 MB).',
      );
    }

    Uint8List bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'File backup tidak dapat dibaca.',
      );
    }

    if (bytes.isEmpty) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'File backup kosong.',
      );
    }

    String source;
    try {
      source = utf8.decode(bytes);
    } catch (_) {
      throw const AppException(
        code: AppErrorCode.validation,
        message: 'File backup bukan teks JSON yang valid.',
      );
    }

    return BackupDocument.fromJsonString(source);
  }

  String _timestamp(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}-'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}';
  }
}
