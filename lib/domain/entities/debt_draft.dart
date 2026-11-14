/// Batas jumlah hutang dalam satu transaksi bulk insert.
const int maxDebtBatchSize = 50;

/// Draft hutang untuk pembuatan beberapa hutang sekaligus.
///
/// Group ditentukan di level batch; draft hanya membawa field bisnis hutang.
final class DebtDraft {
  const DebtDraft({
    required this.title,
    required this.principalAmount,
    this.dueDate,
    this.notes,
  });

  final String title;
  final int principalAmount;
  final DateTime? dueDate;
  final String? notes;
}
