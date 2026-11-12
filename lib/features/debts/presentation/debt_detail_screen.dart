import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/debt.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../domain/entities/debt_overview.dart';
import '../../../domain/entities/payment.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../application/debt_providers.dart';
import 'widgets/debt_status_chip.dart';

const String _unassignedGroupValue = '__unassigned__';

class DebtDetailScreen extends ConsumerStatefulWidget {
  const DebtDetailScreen({required this.debtId, super.key});

  final String debtId;

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(debtOverviewByIdProvider(widget.debtId));
    final payments =
        ref.watch(paymentsByDebtProvider(widget.debtId)).value ??
        const <Payment>[];
    final groups = ref.watch(allGroupsProvider).value ?? const <DebtGroup>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Hutang')),
      body: overviewAsync.when(
        loading: () => const LoadingState(label: 'Memuat hutang...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Hutang tidak dapat dimuat.',
          onRetry: () =>
              ref.invalidate(debtOverviewByIdProvider(widget.debtId)),
        ),
        data: (overview) {
          if (overview == null) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Hutang tidak ditemukan',
              message: 'Hutang mungkin sudah dihapus.',
            );
          }

          return _buildDetail(
            context,
            overview: overview,
            payments: payments,
            groups: groups,
          );
        },
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context, {
    required DebtOverview overview,
    required List<Payment> payments,
    required List<DebtGroup> groups,
  }) {
    final theme = Theme.of(context);
    final debt = overview.debt;
    String? selectedGroupName;
    for (final group in groups) {
      if (group.id == debt.groupId) {
        selectedGroupName = group.name;
        break;
      }
    }
    final groupName = debt.groupId == null
        ? 'Unassigned'
        : selectedGroupName ?? 'Group tidak tersedia';
    final dueDate = debt.dueDate == null
        ? 'Tanpa jatuh tempo'
        : 'Jatuh tempo ${formatDate(debt.dueDate!)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        debt.title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    DebtStatusChip(status: overview.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$groupName • $dueDate',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (debt.notes != null && debt.notes!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(debt.notes!, style: theme.textTheme.bodyMedium),
                ],
                if (debt.isArchived) ...<Widget>[
                  const SizedBox(height: 8),
                  const Chip(
                    label: Text('Diarsipkan'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
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
              key: const Key('debt-edit-button'),
              onPressed: _busy
                  ? null
                  : () => context.push(AppRoutes.debtEdit(debt.id)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            OutlinedButton.icon(
              key: const Key('debt-move-group-button'),
              onPressed: _busy ? null : () => _moveGroup(debt, groups),
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('Pindah group'),
            ),
            OutlinedButton.icon(
              key: const Key('debt-archive-button'),
              onPressed: _busy ? null : () => _toggleArchive(overview),
              icon: Icon(
                debt.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              label: Text(debt.isArchived ? 'Pulihkan' : 'Arsipkan'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            MetricCard(
              label: 'Pokok',
              value: formatRupiah(debt.principalAmount),
            ),
            MetricCard(
              label: 'Dibayar',
              value: formatRupiah(overview.paidAmount),
            ),
            MetricCard(
              label: 'Sisa',
              value: formatRupiah(overview.outstandingAmount),
              emphasize: true,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Histori pembayaran', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (payments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Belum ada pembayaran untuk hutang ini.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (final payment in payments)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: Text(formatRupiah(payment.amount)),
                subtitle: Text(
                  <String>[
                    formatDate(payment.paidAt),
                    if (payment.notes != null && payment.notes!.isNotEmpty)
                      payment.notes!,
                  ].join(' • '),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _moveGroup(Debt debt, List<DebtGroup> groups) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  'Pindahkan "${debt.title}"',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.folder_off_outlined),
                title: const Text('Tanpa group (Unassigned)'),
                selected: debt.groupId == null,
                onTap: () =>
                    Navigator.of(sheetContext).pop(_unassignedGroupValue),
              ),
              for (final group in groups)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(
                    group.isArchived ? '${group.name} (arsip)' : group.name,
                  ),
                  selected: group.id == debt.groupId,
                  onTap: () => Navigator.of(sheetContext).pop(group.id),
                ),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    final targetGroupId = selected == _unassignedGroupValue ? null : selected;
    if (targetGroupId == debt.groupId) {
      return;
    }

    await _runAction(() async {
      await ref
          .read(debtRepositoryProvider)
          .moveToGroup(
            id: debt.id,
            expectedVersion: debt.version,
            groupId: targetGroupId,
          );
      if (!mounted) {
        return;
      }
      _showMessage('Hutang dipindahkan.');
    });
  }

  Future<void> _toggleArchive(DebtOverview overview) async {
    final archiving = !overview.debt.isArchived;
    final confirmed = await showConfirmDialog(
      context,
      title: archiving ? 'Arsipkan hutang?' : 'Pulihkan hutang?',
      message: archiving
          ? 'Hutang akan diarsipkan. Histori pembayaran tetap tersimpan.'
          : 'Hutang akan muncul kembali di daftar aktif.',
      confirmLabel: archiving ? 'Arsipkan' : 'Pulihkan',
    );
    if (!confirmed) {
      return;
    }

    await _runAction(() async {
      await ref
          .read(debtRepositoryProvider)
          .setArchived(
            id: overview.debt.id,
            expectedVersion: overview.debt.version,
            isArchived: archiving,
          );
      if (!mounted) {
        return;
      }
      _showMessage(archiving ? 'Hutang diarsipkan.' : 'Hutang dipulihkan.');
      if (archiving) {
        context.go(AppRoutes.debts);
      }
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on AppException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Aksi tidak dapat diselesaikan.');
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
