import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/customer_summary.dart';

final customerListProvider = StreamProvider.family<List<Customer>, bool>((
  ref,
  includeArchived,
) {
  return ref
      .watch(customerRepositoryProvider)
      .watchAll(includeArchived: includeArchived);
});

final customerByIdProvider = StreamProvider.family<Customer?, String>((
  ref,
  id,
) {
  return ref.watch(customerRepositoryProvider).watchById(id);
});

final customerSummaryProvider = StreamProvider.family<CustomerSummary, String>((
  ref,
  id,
) {
  return ref.watch(customerRepositoryProvider).watchSummary(id);
});

final customerSummariesProvider = StreamProvider<Map<String, CustomerSummary>>(
  (ref) => ref.watch(customerRepositoryProvider).watchSummaries(),
);
