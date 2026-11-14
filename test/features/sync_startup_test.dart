import 'package:debt_reminder/features/sync/application/sync_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 14, 12);

  test('full pull berjalan jika belum pernah pull', () {
    expect(shouldRunFullPull(null, now), isTrue);
  });

  test('full pull berjalan setelah 24 jam', () {
    expect(
      shouldRunFullPull(now.subtract(const Duration(hours: 24)), now),
      isTrue,
    );
    expect(
      shouldRunFullPull(now.subtract(const Duration(hours: 25)), now),
      isTrue,
    );
  });

  test('full pull tidak berjalan jika pull terakhir kurang dari 24 jam', () {
    expect(
      shouldRunFullPull(
        now.subtract(const Duration(hours: 23, minutes: 59)),
        now,
      ),
      isFalse,
    );
    expect(shouldRunFullPull(now, now), isFalse);
  });

  test('timestamp masa depan tidak memicu full pull berulang', () {
    expect(shouldRunFullPull(now.add(const Duration(hours: 2)), now), isFalse);
  });
}
