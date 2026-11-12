import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/customer.dart';
import '../../../domain/entities/debt.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../domain/entities/group_summary.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../debts/application/debt_providers.dart';
import '../../debts/presentation/widgets/debt_list_tile.dart';
import '../application/group_providers.dart';
import 'group_visuals.dart';

const String _unassignedGroupValue = '__unassigned__';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupByIdProvider(widget.groupId));
    final summary =
        ref.watch(groupSummaryProvider(widget.groupId)).value ??
        GroupSummary.empty;
    final debts =
        ref.watch(debtsByGroupProvider(widget.groupId)).value ?? const <Debt>[];
    final customers =
        ref.watch(allCustomersProvider).value ?? const <Customer>[];
    final groups =
        ref.watch(groupListProvider(false)).value ?? const <DebtGroup>[];

    return Scaffold(
      appBar: AppBar(title: Text(groupAsync.value?.name ?? 'Group Hutang')),
      body: groupAsync.when(
        loading: () => const LoadingState(label: 'Memuat group...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Group tidak dapat dimuat.',
          onRetry: () => ref.invalidate(groupByIdProvider(widget.groupId)),
        ),
        data: (group) {
          if (group == null) {
            return const EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'Group tidak ditemukan',
              message: 'Group mungkin sudah dihapus.',
            );
          }

          return _buildDetail(
            context,
            group: group,
            summary: summary,
            debts: debts,
            customers: customers,
            groups: groups,
          );
        },
      ),
    );
  }

  Widget _buildDetail(
    BuildContext context, {
    required DebtGroup group,
    required GroupSummary summary,
    required List<Debt> debts,
    required List<Customer> customers,
    required List<DebtGroup> groups,
  }) {
    final theme = Theme.of(context);
    final color = groupColorFromHex(group.color, theme.colorScheme.primary);
    final customerNames = <String, String>{
      for (final customer in customers) customer.id: customer.name,
    };

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
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(
                    groupIconForKey(group.icon),
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(group.name, style: theme.textTheme.titleLarge),
                      if (group.description != null &&
                          group.description!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          group.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (group.isArchived) ...<Widget>[
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
              key: const Key('group-edit-button'),
              onPressed: _busy
                  ? null
                  : () => context.push(AppRoutes.groupEdit(group.id)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            OutlinedButton.icon(
              key: const Key('group-archive-button'),
              onPressed: _busy ? null : () => _toggleArchive(group),
              icon: Icon(
                group.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              label: Text(group.isArchived ? 'Pulihkan' : 'Arsipkan'),
            ),
            TextButton.icon(
              key: const Key('group-delete-button'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _busy ? null : () => _deleteGroup(group),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Hapus'),
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
        Text('Hutang di group ini', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (debts.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Belum ada hutang di group ini.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (final debt in debts)
            DebtListTile(
              debt: debt,
              customerName: customerNames[debt.customerId],
              onMoveGroup: _busy ? null : () => _moveDebt(debt, groups),
            ),
      ],
    );
  }

  Future<void> _toggleArchive(DebtGroup group) async {
    final archiving = !group.isArchived;
    final confirmed = await showConfirmDialog(
      context,
      title: archiving ? 'Arsipkan group?' : 'Pulihkan group?',
      message: archiving
          ? 'Group akan diarsipkan. Hutang dan riwayatnya tetap tersimpan.'
          : 'Group akan muncul kembali di daftar aktif.',
      confirmLabel: archiving ? 'Arsipkan' : 'Pulihkan',
    );
    if (!confirmed) {
      return;
    }

    await _runAction(() async {
      await ref
          .read(debtGroupRepositoryProvider)
          .setArchived(
            id: group.id,
            expectedVersion: group.version,
            isArchived: archiving,
          );
      if (!mounted) {
        return;
      }
      _showMessage(archiving ? 'Group diarsipkan.' : 'Group dipulihkan.');
      if (archiving) {
        context.go(AppRoutes.groups);
      }
    });
  }

  Future<void> _deleteGroup(DebtGroup group) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Hapus group?',
      message:
          'Group "${group.name}" akan dihapus. '
          'Semua hutang di group ini akan dipindahkan ke Unassigned '
          'dan tidak dihapus.',
      confirmLabel: 'Hapus Group',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }

    await _runAction(() async {
      final moved = await ref
          .read(debtGroupRepositoryProvider)
          .delete(id: group.id, expectedVersion: group.version);
      if (!mounted) {
        return;
      }
      _showMessage('Group dihapus. $moved hutang dipindahkan ke Unassigned.');
      context.go(AppRoutes.groups);
    });
  }

  Future<void> _moveDebt(Debt debt, List<DebtGroup> groups) async {
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
                  leading: Icon(groupIconForKey(group.icon)),
                  title: Text(group.name),
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
