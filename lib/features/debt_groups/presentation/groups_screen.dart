import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../domain/entities/group_summary.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/local_data_notice.dart';
import '../application/group_providers.dart';
import 'group_visuals.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupListProvider(_showArchived));
    final summaries =
        ref.watch(groupSummariesProvider).value ??
        const <String, GroupSummary>{};

    return Scaffold(
      key: const Key('groups-screen'),
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('groups-add-button'),
        onPressed: () => context.push(AppRoutes.groupNew),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Group'),
      ),
      body: groups.when(
        loading: () => const LoadingState(label: 'Memuat group...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Group tidak dapat dimuat dari database lokal.',
          onRetry: () => ref.invalidate(groupListProvider(_showArchived)),
        ),
        data: (items) => _buildBody(context, items, summaries),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<DebtGroup> groups,
    Map<String, GroupSummary> summaries,
  ) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: <Widget>[
        const SliverToBoxAdapter(child: LocalDataNotice()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Daftar group',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                FilterChip(
                  label: const Text('Tampilkan arsip'),
                  selected: _showArchived,
                  onSelected: (value) {
                    setState(() => _showArchived = value);
                  },
                ),
              ],
            ),
          ),
        ),
        if (groups.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.folder_outlined,
              title: _showArchived
                  ? 'Tidak ada group diarsipkan'
                  : 'Belum ada group',
              message: _showArchived
                  ? 'Group yang diarsipkan akan muncul di sini.'
                  : 'Buat group untuk mengelompokkan hutang dengan rapi.',
              actionLabel: _showArchived ? null : 'Tambah Group',
              onAction: _showArchived
                  ? null
                  : () => context.push(AppRoutes.groupNew),
            ),
          )
        else
          SliverList.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _GroupTile(
                group: group,
                summary: summaries[group.id] ?? GroupSummary.empty,
              );
            },
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
      ],
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, required this.summary});

  final DebtGroup group;
  final GroupSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = groupColorFromHex(group.color, theme.colorScheme.primary);

    return Card(
      key: Key('group-tile-${group.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        onTap: () => context.push(AppRoutes.groupDetail(group.id)),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(groupIconForKey(group.icon), color: color),
        ),
        title: Text(group.name),
        subtitle: Text(
          '${summary.debtCount} hutang • '
          '${formatRupiah(summary.outstandingTotal)} sisa',
        ),
        trailing: group.isArchived
            ? const Chip(
                label: Text('Arsip'),
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
