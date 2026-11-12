import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/customer_summary.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/local_data_notice.dart';
import '../application/customer_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showArchived = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerListProvider(_showArchived));
    final summaries =
        ref.watch(customerSummariesProvider).value ??
        const <String, CustomerSummary>{};

    return Scaffold(
      key: const Key('customers-screen'),
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('customers-add-button'),
        onPressed: () => context.push(AppRoutes.customerNew),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Tambah Pelanggan'),
      ),
      body: customers.when(
        loading: () => const LoadingState(label: 'Memuat pelanggan...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Pelanggan tidak dapat dimuat dari database lokal.',
          onRetry: () => ref.invalidate(customerListProvider(_showArchived)),
        ),
        data: (items) => _buildBody(context, _filter(items), summaries),
      ),
    );
  }

  List<Customer> _filter(List<Customer> customers) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return customers;
    }

    return customers
        .where(
          (customer) =>
              customer.name.toLowerCase().contains(query) ||
              (customer.phone?.toLowerCase().contains(query) ?? false) ||
              (customer.notes?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);
  }

  Widget _buildBody(
    BuildContext context,
    List<Customer> customers,
    Map<String, CustomerSummary> summaries,
  ) {
    final theme = Theme.of(context);
    final hasSearch = _query.trim().isNotEmpty;

    return CustomScrollView(
      slivers: <Widget>[
        const SliverToBoxAdapter(child: LocalDataNotice()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Daftar pelanggan', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('customer-search-field'),
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Cari nama, telepon, atau catatan',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: hasSearch
                        ? IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilterChip(
                    label: const Text('Tampilkan arsip'),
                    selected: _showArchived,
                    onSelected: (value) {
                      setState(() => _showArchived = value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (customers.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.people_outline,
              title: hasSearch
                  ? 'Pelanggan tidak ditemukan'
                  : _showArchived
                  ? 'Tidak ada pelanggan diarsipkan'
                  : 'Belum ada pelanggan',
              message: hasSearch
                  ? 'Coba kata kunci lain atau hapus pencarian.'
                  : _showArchived
                  ? 'Pelanggan yang diarsipkan akan muncul di sini.'
                  : 'Tambahkan pelanggan sebelum membuat hutang.',
              actionLabel: hasSearch || _showArchived
                  ? null
                  : 'Tambah Pelanggan',
              onAction: hasSearch || _showArchived
                  ? null
                  : () => context.push(AppRoutes.customerNew),
            ),
          )
        else
          SliverList.builder(
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final customer = customers[index];
              return _CustomerTile(
                customer: customer,
                summary: summaries[customer.id] ?? CustomerSummary.empty,
              );
            },
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
      ],
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.summary});

  final Customer customer;
  final CustomerSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().substring(0, 1).toUpperCase();
    final contact = customer.phone == null || customer.phone!.isEmpty
        ? null
        : customer.phone;

    return Card(
      key: Key('customer-tile-${customer.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        onTap: () => context.push(AppRoutes.customerDetail(customer.id)),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text(initial),
        ),
        title: Text(customer.name),
        subtitle: Text(
          <String>[
            ?contact,
            '${summary.debtCount} hutang',
            '${formatRupiah(summary.outstandingTotal)} sisa',
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: customer.isArchived
            ? const Chip(
                label: Text('Arsip'),
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
