import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/debt.dart';
import '../../../domain/entities/debt_group.dart';

final debtsByGroupProvider = StreamProvider.family<List<Debt>, String?>((
  ref,
  groupId,
) {
  return ref.watch(debtRepositoryProvider).watchByGroup(groupId);
});

final allGroupsProvider = StreamProvider<List<DebtGroup>>(
  (ref) =>
      ref.watch(debtGroupRepositoryProvider).watchAll(includeArchived: true),
);
