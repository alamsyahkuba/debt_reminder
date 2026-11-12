import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../domain/entities/group_summary.dart';

final groupListProvider = StreamProvider.family<List<DebtGroup>, bool>((
  ref,
  includeArchived,
) {
  return ref
      .watch(debtGroupRepositoryProvider)
      .watchAll(includeArchived: includeArchived);
});

final groupByIdProvider = StreamProvider.family<DebtGroup?, String>((ref, id) {
  return ref.watch(debtGroupRepositoryProvider).watchById(id);
});

final groupSummaryProvider = StreamProvider.family<GroupSummary, String>((
  ref,
  id,
) {
  return ref.watch(debtGroupRepositoryProvider).watchSummary(id);
});

final groupSummariesProvider = StreamProvider<Map<String, GroupSummary>>(
  (ref) => ref.watch(debtGroupRepositoryProvider).watchSummaries(),
);
