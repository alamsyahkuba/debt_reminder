/// Error autentikasi admin yang aman ditampilkan ke UI.
final class AdminAuthException implements Exception {
  const AdminAuthException({
    required this.code,
    required this.message,
    this.retryAfterSeconds,
    this.cause,
  });

  final String code;
  final String message;
  final int? retryAfterSeconds;
  final Object? cause;

  bool get isNetworkError => code == 'network';

  bool get isSessionExpired => code == 'session_expired';

  @override
  String toString() => 'AdminAuthException($code): $message';
}
