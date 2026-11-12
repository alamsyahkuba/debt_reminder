import 'debt.dart';
import 'debt_status.dart';

final class DebtOverview {
  const DebtOverview({
    required this.debt,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.status,
  });

  factory DebtOverview.fromDebt(
    Debt debt, {
    required int paidAmount,
    DateTime? today,
  }) {
    final outstanding = debt.principalAmount > paidAmount
        ? debt.principalAmount - paidAmount
        : 0;
    final now = (today ?? DateTime.now()).toUtc();
    final todayDate = DateTime.utc(now.year, now.month, now.day);
    final dueDate = debt.dueDate;

    final DebtStatus status;
    if (paidAmount >= debt.principalAmount) {
      status = DebtStatus.paid;
    } else if (dueDate != null &&
        DateTime.utc(
          dueDate.year,
          dueDate.month,
          dueDate.day,
        ).isBefore(todayDate)) {
      status = DebtStatus.overdue;
    } else if (paidAmount > 0) {
      status = DebtStatus.partial;
    } else {
      status = DebtStatus.unpaid;
    }

    return DebtOverview(
      debt: debt,
      paidAmount: paidAmount,
      outstandingAmount: outstanding,
      status: status,
    );
  }

  final Debt debt;
  final int paidAmount;
  final int outstandingAmount;
  final DebtStatus status;
}
