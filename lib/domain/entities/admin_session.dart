final class AdminSession {
  const AdminSession({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

  bool get isValid =>
      token.isNotEmpty && DateTime.now().toUtc().isBefore(expiresAt.toUtc());

  Duration get remaining {
    final remaining = expiresAt.toUtc().difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
