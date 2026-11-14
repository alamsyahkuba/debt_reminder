import 'package:debt_reminder/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('addMonthsClamped menambah bulan dan menjaga tanggal', () {
    final result = addMonthsClamped(DateTime.utc(2026, 11, 15), 1);
    expect(result, DateTime.utc(2026, 12, 15));
  });

  test('addMonthsClamped memotong tanggal ke akhir bulan', () {
    expect(
      addMonthsClamped(DateTime.utc(2026, 1, 31), 1),
      DateTime.utc(2026, 2, 28),
    );
    expect(
      addMonthsClamped(DateTime.utc(2024, 2, 29), 12),
      DateTime.utc(2025, 2, 28),
    );
  });
}
