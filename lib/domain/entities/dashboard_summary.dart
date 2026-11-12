import 'debt_overview.dart';
import 'debt_status.dart';

/// Aggregated figures shown on the dashboard.
///
/// Every value is derived from active debt overviews so the dashboard cannot
/// drift from the debt list or payment history.
final class DashboardSummary {
  const DashboardSummary({
    required this.debtCount,
    required this.unpaidCount,
    required this.partialCount,
    required this.paidCount,
    required this.overdueCount,
    required this.principalTotal,
    required this.paidTotal,
    required this.outstandingTotal,
  });

  factory DashboardSummary.fromOverviews(Iterable<DebtOverview> overviews) {
    var debtCount = 0;
    var unpaidCount = 0;
    var partialCount = 0;
    var paidCount = 0;
    var overdueCount = 0;
    var principalTotal = 0;
    var paidTotal = 0;
    var outstandingTotal = 0;

    for (final overview in overviews) {
      debtCount++;
      principalTotal += overview.debt.principalAmount;
      paidTotal += overview.paidAmount;
      outstandingTotal += overview.outstandingAmount;

      switch (overview.status) {
        case DebtStatus.unpaid:
          unpaidCount++;
          break;
        case DebtStatus.partial:
          partialCount++;
          break;
        case DebtStatus.paid:
          paidCount++;
          break;
        case DebtStatus.overdue:
          overdueCount++;
          break;
      }
    }

    return DashboardSummary(
      debtCount: debtCount,
      unpaidCount: unpaidCount,
      partialCount: partialCount,
      paidCount: paidCount,
      overdueCount: overdueCount,
      principalTotal: principalTotal,
      paidTotal: paidTotal,
      outstandingTotal: outstandingTotal,
    );
  }

  static const DashboardSummary empty = DashboardSummary(
    debtCount: 0,
    unpaidCount: 0,
    partialCount: 0,
    paidCount: 0,
    overdueCount: 0,
    principalTotal: 0,
    paidTotal: 0,
    outstandingTotal: 0,
  );

  final int debtCount;
  final int unpaidCount;
  final int partialCount;
  final int paidCount;
  final int overdueCount;
  final int principalTotal;
  final int paidTotal;
  final int outstandingTotal;
}
