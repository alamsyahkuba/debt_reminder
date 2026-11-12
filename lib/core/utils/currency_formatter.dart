import 'package:intl/intl.dart';

final NumberFormat _decimalFormatter = NumberFormat.decimalPattern('id_ID');

/// Memformat nominal integer rupiah, misalnya `Rp 1.000.000`.
///
/// Nominal disimpan sebagai integer dan tidak boleh menggunakan floating point.
String formatRupiah(int amount) => 'Rp ${_decimalFormatter.format(amount)}';
