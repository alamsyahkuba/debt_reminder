import 'package:debt_reminder/core/utils/currency_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatRupiah', () {
    test('memformat nominal dengan pemisah ribuan Indonesia', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(1000), 'Rp 1.000');
      expect(formatRupiah(1250000), 'Rp 1.250.000');
      expect(formatRupiah(1000000000), 'Rp 1.000.000.000');
    });
  });
}
