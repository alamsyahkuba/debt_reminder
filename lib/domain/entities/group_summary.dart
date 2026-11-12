final class GroupSummary {
  const GroupSummary({
    required this.debtCount,
    required this.principalTotal,
    required this.paidTotal,
    required this.outstandingTotal,
  });

  factory GroupSummary.fromTotals({
    required int debtCount,
    required int principalTotal,
    required int paidTotal,
  }) {
    final outstanding = principalTotal > paidTotal
        ? principalTotal - paidTotal
        : 0;

    return GroupSummary(
      debtCount: debtCount,
      principalTotal: principalTotal,
      paidTotal: paidTotal,
      outstandingTotal: outstanding,
    );
  }

  static const GroupSummary empty = GroupSummary(
    debtCount: 0,
    principalTotal: 0,
    paidTotal: 0,
    outstandingTotal: 0,
  );

  final int debtCount;
  final int principalTotal;
  final int paidTotal;
  final int outstandingTotal;
}
