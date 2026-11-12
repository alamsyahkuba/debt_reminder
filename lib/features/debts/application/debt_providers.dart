import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/debt.dart';
import '../../../domain/entities/debt_group.dart';

final debtsByGroupProvider = StreamProvider.family<List<Debt>, String?>((
  ref,
  groupId,
) {
  return ref.watch(debtRepositoryProvider).watchByGroup(groupId);
});

final debtsByCustomerProvider = StreamProvider.family<List<Debt>, String>((
  ref,
  customerId,
) {
  return ref.watch(debtRepositoryProvider).watchByCustomer(customerId);
});

final allCustomersProvider = StreamProvider<List<Customer>>(
  (ref) =>
      ref.watch(customerRepositoryProvider).watchAll(includeArchived: true),
);

final allGroupsProvider = StreamProvider<List<DebtGroup>>(
  (ref) =>
      ref.watch(debtGroupRepositoryProvider).watchAll(includeArchived: true),
);
