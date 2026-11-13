final class AdminSyncException implements Exception {
  const AdminSyncException({
    required this.code,
    required this.message,
    this.statusCode,
    this.isRetryable = false,
    this.isAuthError = false,
    this.cause,
  });

  final String code;
  final String message;
  final int? statusCode;
  final bool isRetryable;
  final bool isAuthError;
  final Object? cause;

  @override
  String toString() => 'AdminSyncException($code): $message';
}
