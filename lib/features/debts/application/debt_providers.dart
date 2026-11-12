import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/debt.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../domain/entities/debt_overview.dart';
import '../../../domain/entities/payment.dart';

final debtsByGroupProvider = StreamProvider.family<List<Debt>, String?>((
  ref,
  groupId,
) {
  return ref.watch(debtRepositoryProvider).watchByGroup(groupId);
});

final debtOverviewsProvider = StreamProvider.family<List<DebtOverview>, bool>((
  ref,
  includeArchived,
) {
  return ref
      .watch(debtRepositoryProvider)
      .watchOverviews(includeArchived: includeArchived);
});

final debtOverviewByIdProvider = StreamProvider.family<DebtOverview?, String>((
  ref,
  id,
) {
  return ref.watch(debtRepositoryProvider).watchOverviewById(id);
});

final paymentsByDebtProvider = StreamProvider.family<List<Payment>, String>((
  ref,
  debtId,
) {
  return ref.watch(paymentRepositoryProvider).watchByDebt(debtId);
});

final allGroupsProvider = StreamProvider<List<DebtGroup>>(
  (ref) =>
      ref.watch(debtGroupRepositoryProvider).watchAll(includeArchived: true),
);
