import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/customer_summary.dart';
import '../../../domain/entities/debt.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../debts/application/debt_providers.dart';
import '../../debts/presentation/widgets/debt_list_tile.dart';
import '../application/customer_providers.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerByIdProvider(widget.customerId));
    final summary =
        ref.watch(customerSummaryProvider(widget.customerId)).value ??
        CustomerSummary.empty;
    final debts =
        ref.watch(debtsByCustomerProvider(widget.customerId)).value ??
        const <Debt>[];
    final groups = ref.watch(allGroupsProvider).value ?? const <DebtGroup>[];

    return Scaffold(
      appBar: AppBar(title: Text(customerAsync.value?.name ?? 'Pelanggan')),
      body: customerAsync.when(
        loading: () => const LoadingState(label: 'Memuat pelanggan...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Pelanggan tidak dapat dimuat.',
          onRetry: () =>
              ref.invalidate(customerByIdProvider(widget.customerId)),
        ),
        data: (customer) {
          if (customer == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Pelanggan tidak ditemukan',
              message: 'Pelanggan mungkin sudah tidak tersedia.',
            );
          }

          return _buildDetail(
            context,
            customer: customer,
            summary: summary,
            debts: debts,
            groups: groups,
          );
        },
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context, {
    required Customer customer,
    required CustomerSummary summary,
    required List<Debt> debts,
    required List<DebtGroup> groups,
  }) {
    final theme = Theme.of(context);
    final groupNames = <String, String>{
      for (final group in groups) group.id: group.name,
    };
    final initial = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().substring(0, 1).toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(initial, style: theme.textTheme.titleLarge),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(customer.name, style: theme.textTheme.titleLarge),
                      if (customer.phone != null &&
                          customer.phone!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          customer.phone!,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (customer.notes != null &&
                          customer.notes!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          customer.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (customer.isArchived) ...<Widget>[
                        const SizedBox(height: 8),
                        const Chip(
                          label: Text('Diarsipkan'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              key: const Key('customer-edit-button'),
              onPressed: _busy
                  ? null
                  : () => context.push(AppRoutes.customerEdit(customer.id)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            OutlinedButton.icon(
              key: const Key('customer-archive-button'),
              onPressed: _busy ? null : () => _toggleArchive(customer),
              icon: Icon(
                customer.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              label: Text(customer.isArchived ? 'Pulihkan' : 'Arsipkan'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            MetricCard(label: 'Hutang', value: summary.debtCount.toString()),
            MetricCard(
              label: 'Pokok',
              value: formatRupiah(summary.principalTotal),
            ),
            MetricCard(
              label: 'Dibayar',
              value: formatRupiah(summary.paidTotal),
            ),
            MetricCard(
              label: 'Sisa',
              value: formatRupiah(summary.outstandingTotal),
              emphasize: true,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Hutang pelanggan', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (debts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Belum ada hutang untuk pelanggan ini.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (final debt in debts)
            DebtListTile(
              debt: debt,
              groupName: debt.groupId == null
                  ? 'Unassigned'
                  : groupNames[debt.groupId],
            ),
        const SizedBox(height: 16),
        Text(
          'Pelanggan dengan histori hutang hanya dapat diarsipkan, '
          'tidak dihapus permanen.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleArchive(Customer customer) async {
    final archiving = !customer.isArchived;
    final confirmed = await showConfirmDialog(
      context,
      title: archiving ? 'Arsipkan pelanggan?' : 'Pulihkan pelanggan?',
      message: archiving
          ? 'Pelanggan akan diarsipkan. Histori hutang tetap tersimpan.'
          : 'Pelanggan akan muncul kembali di daftar aktif.',
      confirmLabel: archiving ? 'Arsipkan' : 'Pulihkan',
    );
    if (!confirmed) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(customerRepositoryProvider)
          .setArchived(
            id: customer.id,
            expectedVersion: customer.version,
            isArchived: archiving,
          );
      if (!mounted) {
        return;
      }
      _showMessage(
        archiving ? 'Pelanggan diarsipkan.' : 'Pelanggan dipulihkan.',
      );
      if (archiving) {
        context.go(AppRoutes.customers);
      }
    } on AppException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Pelanggan tidak dapat diarsipkan.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
