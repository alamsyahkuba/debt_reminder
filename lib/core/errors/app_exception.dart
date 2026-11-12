/// Kategori error domain yang dapat ditampilkan dengan aman oleh UI.
enum AppErrorCode {
  validation,
  notFound,
  offline,
  unauthorized,
  conflict,
  duplicateOperation,
  remoteUnavailable,
  localDatabase,
}

/// Error bertipe untuk lapisan domain dan data.
///
/// Pesan harus ramah pengguna dan tidak boleh memuat PIN, token, atau data
/// finansial yang tidak perlu.
final class AppException implements Exception {
  const AppException({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final AppErrorCode code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'AppException(${code.name}): $message';
}
