import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/dashboard_summary.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../domain/entities/debt_overview.dart';
import '../../../domain/entities/debt_status.dart';
import '../../../domain/entities/group_summary.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/local_data_notice.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../debt_groups/application/group_providers.dart';
import '../../debt_groups/presentation/group_visuals.dart';
import '../../debts/application/debt_providers.dart';
import '../../debts/presentation/widgets/debt_status_chip.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewsAsync = ref.watch(debtOverviewsProvider(false));
    final groups =
        ref.watch(groupListProvider(true)).value ?? const <DebtGroup>[];
    final summaries =
        ref.watch(groupSummariesProvider).value ??
        const <String, GroupSummary>{};

    return Scaffold(
      key: const Key('dashboard-screen'),
      backgroundColor: Colors.transparent,
      body: overviewsAsync.when(
        loading: () => const LoadingState(label: 'Memuat dashboard...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Dashboard tidak dapat dimuat dari database lokal.',
          onRetry: () {
            ref.invalidate(debtOverviewsProvider(false));
            ref.invalidate(groupListProvider(true));
            ref.invalidate(groupSummariesProvider);
          },
        ),
        data: (overviews) => _DashboardContent(
          overviews: overviews,
          groups: groups,
          groupSummaries: summaries,
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.overviews,
    required this.groups,
    required this.groupSummaries,
  });

  final List<DebtOverview> overviews;
  final List<DebtGroup> groups;
  final Map<String, GroupSummary> groupSummaries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = DashboardSummary.fromOverviews(overviews);
    final upcoming = _upcomingDebts(overviews);
    final unassigned = _unassignedSummary(overviews);
    final visibleGroups = groups
        .where(
          (group) =>
              !group.isArchived ||
              (groupSummaries[group.id]?.debtCount ?? 0) > 0,
        )
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: <Widget>[
        const LocalDataNotice(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Ringkasan keuangan', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  MetricCard(
                    key: const Key('dashboard-total-principal'),
                    label: 'Total pokok',
                    value: formatRupiah(summary.principalTotal),
                  ),
                  MetricCard(
                    key: const Key('dashboard-total-paid'),
                    label: 'Total dibayar',
                    value: formatRupiah(summary.paidTotal),
                  ),
                  MetricCard(
                    key: const Key('dashboard-total-outstanding'),
                    label: 'Sisa hutang',
                    value: formatRupiah(summary.outstandingTotal),
                    emphasize: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Status hutang', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  MetricCard(
                    key: const Key('dashboard-count-active'),
                    label: 'Hutang aktif',
                    value: '${summary.debtCount}',
                  ),
                  MetricCard(
                    key: const Key('dashboard-count-partial'),
                    label: 'Sebagian',
                    value: '${summary.partialCount}',
                  ),
                  MetricCard(
                    key: const Key('dashboard-count-overdue'),
                    label: 'Jatuh tempo',
                    value: '${summary.overdueCount}',
                  ),
                  MetricCard(
                    key: const Key('dashboard-count-paid'),
                    label: 'Lunas',
                    value: '${summary.paidCount}',
                  ),
                ],
              ),
              if (overviews.isEmpty) ...<Widget>[
                const SizedBox(height: 20),
                const _NoDebtCard(),
              ],
            ],
          ),
        ),
        if (visibleGroups.isNotEmpty || unassigned != null) ...<Widget>[
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'Ringkasan group',
            trailing: TextButton(
              onPressed: () => context.push(AppRoutes.groups),
              child: const Text('Lihat group'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: <Widget>[
                for (final group in visibleGroups)
                  _GroupSummaryTile(
                    tileKey: Key('dashboard-group-${group.id}'),
                    title: group.name,
                    summary: groupSummaries[group.id] ?? GroupSummary.empty,
                    color: groupColorFromHex(
                      group.color,
                      theme.colorScheme.primary,
                    ),
                    icon: groupIconForKey(group.icon),
                    isArchived: group.isArchived,
                    onTap: () => context.push(AppRoutes.groupDetail(group.id)),
                  ),
                if (unassigned != null)
                  _GroupSummaryTile(
                    tileKey: const Key('dashboard-group-unassigned'),
                    title: 'Tanpa group',
                    summary: unassigned,
                    color: theme.colorScheme.outline,
                    icon: Icons.folder_off_outlined,
                    onTap: () => context.push(AppRoutes.debts),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _SectionTitle(
          title: 'Jatuh tempo terdekat',
          trailing: TextButton(
            onPressed: () => context.push(AppRoutes.debts),
            child: const Text('Lihat hutang'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: upcoming.isEmpty
              ? const _InfoCard(
                  icon: Icons.event_available_outlined,
                  message: 'Tidak ada hutang yang jatuh tempo dalam 7 hari ke depan.',
                )
              : Column(
                  children: <Widget>[
                    for (final overview in upcoming.take(5))
                      _UpcomingDebtTile(overview: overview),
                    if (upcoming.length > 5)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.push(AppRoutes.debts),
                          child: Text(
                            'Lihat ${upcoming.length - 5} hutang lainnya',
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  GroupSummary? _unassignedSummary(List<DebtOverview> overviews) {
    var debtCount = 0;
    var principalTotal = 0;
    var paidTotal = 0;

    for (final overview in overviews) {
      if (overview.debt.groupId != null) {
        continue;
      }
      debtCount++;
      principalTotal += overview.debt.principalAmount;
      paidTotal += overview.paidAmount;
    }

    if (debtCount == 0) {
      return null;
    }

    return GroupSummary.fromTotals(
      debtCount: debtCount,
      principalTotal: principalTotal,
      paidTotal: paidTotal,
    );
  }

  List<DebtOverview> _upcomingDebts(List<DebtOverview> overviews) {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: 7));

    final upcoming = overviews
        .where((overview) {
          final dueDate = overview.debt.dueDate;
          if (dueDate == null ||
              overview.status == DebtStatus.paid ||
              overview.outstandingAmount <= 0) {
            return false;
          }

          final date = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
          return !date.isAfter(limit);
        })
        .toList(growable: true);

    upcoming.sort((a, b) => a.debt.dueDate!.compareTo(b.debt.dueDate!));
    return upcoming;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _GroupSummaryTile extends StatelessWidget {
  const _GroupSummaryTile({
    required this.tileKey,
    required this.title,
    required this.summary,
    required this.color,
    required this.icon,
    required this.onTap,
    this.isArchived = false,
  });

  final Key tileKey;
  final String title;
  final GroupSummary summary;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: tileKey,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(
          '${summary.debtCount} hutang • '
          '${formatRupiah(summary.outstandingTotal)} sisa',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (isArchived)
              const Chip(
                label: Text('Arsip'),
                visualDensity: VisualDensity.compact,
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _UpcomingDebtTile extends StatelessWidget {
  const _UpcomingDebtTile({required this.overview});

  final DebtOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debt = overview.debt;
    final dueDate = debt.dueDate;
    final isOverdue = overview.status == DebtStatus.overdue;
    final dueLabel = dueDate == null
        ? 'Tanpa jatuh tempo'
        : isOverdue
        ? 'Terlambat sejak ${formatDate(dueDate)}'
        : 'Jatuh tempo ${formatDate(dueDate)}';

    return Card(
      key: Key('dashboard-upcoming-${debt.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => context.push(AppRoutes.debtDetail(debt.id)),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.errorContainer,
          child: Icon(
            isOverdue ? Icons.warning_amber_outlined : Icons.event_outlined,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        title: Text(debt.title),
        subtitle: Text(
          '$dueLabel • ${formatRupiah(overview.outstandingAmount)} sisa',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: DebtStatusChip(status: overview.status),
      ),
    );
  }
}

class _NoDebtCard extends StatelessWidget {
  const _NoDebtCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text('Belum ada hutang', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Catat hutang pertama untuk melihat ringkasan di dashboard.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('dashboard-add-debt-button'),
              onPressed: () => context.push(AppRoutes.debtNew),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Hutang'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
