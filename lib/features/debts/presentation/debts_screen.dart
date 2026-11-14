import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../domain/entities/debt_overview.dart';
import '../../../domain/entities/debt_status.dart';
import '../../../shared/widgets/admin_locked_banner.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../../shared/widgets/local_data_notice.dart';
import '../../admin/application/admin_providers.dart';
import '../application/debt_providers.dart';
import 'widgets/debt_status_chip.dart';

const String _allFilterValue = '__all__';
const String _unassignedFilterValue = '__unassigned__';

enum _DebtSort { dueDate, newest, amount, group }

enum _DueFilter { all, overdue, nextSevenDays, noDueDate }

extension on _DebtSort {
  String get label => switch (this) {
    _DebtSort.dueDate => 'Jatuh tempo',
    _DebtSort.newest => 'Terbaru',
    _DebtSort.amount => 'Sisa terbesar',
    _DebtSort.group => 'Group',
  };
}

extension on _DueFilter {
  String get label => switch (this) {
    _DueFilter.all => 'Semua tanggal',
    _DueFilter.overdue => 'Overdue',
    _DueFilter.nextSevenDays => '7 hari ke depan',
    _DueFilter.noDueDate => 'Tanpa jatuh tempo',
  };
}

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String? _groupFilter;
  DebtStatus? _statusFilter;
  _DueFilter _dueFilter = _DueFilter.all;
  _DebtSort _sort = _DebtSort.dueDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overviews = ref.watch(debtOverviewsProvider(false));
    final groups = ref.watch(allGroupsProvider).value ?? const <DebtGroup>[];
    final isAdmin = ref.watch(adminUnlockedProvider);

    return Scaffold(
      key: const Key('debts-screen'),
      backgroundColor: Colors.transparent,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              key: const Key('debts-add-button'),
              onPressed: () => context.push(AppRoutes.debtNew),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Hutang'),
            )
          : null,
      body: overviews.when(
        loading: () => const LoadingState(label: 'Memuat hutang...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Hutang tidak dapat dimuat dari database lokal.',
          onRetry: () => ref.invalidate(debtOverviewsProvider(false)),
        ),
        data: (items) => _buildBody(context, items, groups, isAdmin),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<DebtOverview> overviews,
    List<DebtGroup> groups,
    bool isAdmin,
  ) {
    final theme = Theme.of(context);
    final groupNames = <String, String>{
      for (final group in groups) group.id: group.name,
    };
    final filtered = _filterAndSort(overviews, groupNames);
    final hasFilters =
        _query.trim().isNotEmpty ||
        _groupFilter != null ||
        _statusFilter != null ||
        _dueFilter != _DueFilter.all;
    final groupFilterValue =
        _groupFilter == null ||
            _groupFilter == _unassignedFilterValue ||
            groups.any((group) => group.id == _groupFilter)
        ? _groupFilter ?? _allFilterValue
        : _allFilterValue;

    return CustomScrollView(
      slivers: <Widget>[
        const SliverToBoxAdapter(child: LocalDataNotice()),
        const SliverToBoxAdapter(child: AdminLockedBanner()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text('Daftar hutang', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    if (isAdmin)
                      OutlinedButton.icon(
                        key: const Key('debts-bulk-add-button'),
                        onPressed: () => context.push(AppRoutes.debtBulk),
                        icon: const Icon(Icons.playlist_add, size: 18),
                        label: const Text('Tambah Banyak'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('debt-search-field'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Cari judul atau catatan',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _FilterDropdown(
                      label: 'Group',
                      keyValue: 'debt-group-filter',
                      value: groupFilterValue,
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: _allFilterValue,
                          child: Text('Semua group'),
                        ),
                        const DropdownMenuItem<String>(
                          value: _unassignedFilterValue,
                          child: Text('Unassigned'),
                        ),
                        for (final group in groups)
                          DropdownMenuItem<String>(
                            value: group.id,
                            child: Text(group.name),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _groupFilter =
                              value == null || value == _allFilterValue
                              ? null
                              : value;
                        });
                      },
                    ),
                    _FilterDropdown(
                      label: 'Status',
                      keyValue: 'debt-status-filter',
                      value: _statusFilter?.name ?? _allFilterValue,
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                          value: _allFilterValue,
                          child: Text('Semua status'),
                        ),
                        for (final status in DebtStatus.values)
                          DropdownMenuItem<String>(
                            value: status.name,
                            child: Text(debtStatusLabel(status)),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _statusFilter =
                              value == null || value == _allFilterValue
                              ? null
                              : DebtStatus.values.firstWhere(
                                  (status) => status.name == value,
                                );
                        });
                      },
                    ),
                    _FilterDropdown(
                      label: 'Jatuh tempo',
                      keyValue: 'debt-due-filter',
                      value: _dueFilter.name,
                      items: <DropdownMenuItem<String>>[
                        for (final filter in _DueFilter.values)
                          DropdownMenuItem<String>(
                            value: filter.name,
                            child: Text(filter.label),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _dueFilter = _DueFilter.values.firstWhere(
                            (filter) => filter.name == value,
                            orElse: () => _DueFilter.all,
                          );
                        });
                      },
                    ),
                    _FilterDropdown(
                      label: 'Urutkan',
                      keyValue: 'debt-sort-filter',
                      value: _sort.name,
                      items: <DropdownMenuItem<String>>[
                        for (final sort in _DebtSort.values)
                          DropdownMenuItem<String>(
                            value: sort.name,
                            child: Text(sort.label),
                          ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sort = _DebtSort.values.firstWhere(
                            (sort) => sort.name == value,
                            orElse: () => _DebtSort.dueDate,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.receipt_long_outlined,
              title: hasFilters
                  ? 'Tidak ada hutang yang cocok'
                  : 'Belum ada hutang',
              message: hasFilters
                  ? 'Ubah pencarian atau filter untuk melihat hutang lain.'
                  : 'Catat hutang pertama untuk mulai memantau pembayaran.',
              actionLabel: hasFilters || !isAdmin ? null : 'Tambah Hutang',
              onAction: hasFilters || !isAdmin
                  ? null
                  : () => context.push(AppRoutes.debtNew),
            ),
          )
        else
          SliverList.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final overview = filtered[index];
              return _DebtOverviewTile(
                overview: overview,
                groupName: overview.debt.groupId == null
                    ? 'Unassigned'
                    : groupNames[overview.debt.groupId],
              );
            },
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
      ],
    );
  }

  List<DebtOverview> _filterAndSort(
    List<DebtOverview> overviews,
    Map<String, String> groupNames,
  ) {
    final query = _query.trim().toLowerCase();
    final today = DateTime.now().toUtc();
    final todayDate = DateTime.utc(today.year, today.month, today.day);
    final nextSevenDays = todayDate.add(const Duration(days: 7));

    final filtered = overviews
        .where((overview) {
          final debt = overview.debt;
          if (query.isNotEmpty) {
            final matchesTitle = debt.title.toLowerCase().contains(query);
            final matchesNotes =
                debt.notes?.toLowerCase().contains(query) ?? false;
            if (!matchesTitle && !matchesNotes) {
              return false;
            }
          }

          if (_groupFilter != null) {
            if (_groupFilter == _unassignedFilterValue) {
              if (debt.groupId != null) {
                return false;
              }
            } else if (debt.groupId != _groupFilter) {
              return false;
            }
          }

          if (_statusFilter != null && overview.status != _statusFilter) {
            return false;
          }

          final dueDate = debt.dueDate;
          switch (_dueFilter) {
            case _DueFilter.all:
              break;
            case _DueFilter.overdue:
              if (overview.status != DebtStatus.overdue) {
                return false;
              }
            case _DueFilter.nextSevenDays:
              if (dueDate == null) {
                return false;
              }
              final normalized = DateTime.utc(
                dueDate.year,
                dueDate.month,
                dueDate.day,
              );
              if (normalized.isBefore(todayDate) ||
                  normalized.isAfter(nextSevenDays)) {
                return false;
              }
            case _DueFilter.noDueDate:
              if (dueDate != null) {
                return false;
              }
          }

          return true;
        })
        .toList(growable: true);

    switch (_sort) {
      case _DebtSort.dueDate:
        filtered.sort((a, b) {
          final aDue = a.debt.dueDate;
          final bDue = b.debt.dueDate;
          if (aDue == null && bDue == null) {
            return b.debt.createdAt.compareTo(a.debt.createdAt);
          }
          if (aDue == null) {
            return 1;
          }
          if (bDue == null) {
            return -1;
          }
          final byDue = aDue.compareTo(bDue);
          return byDue == 0
              ? b.debt.createdAt.compareTo(a.debt.createdAt)
              : byDue;
        });
      case _DebtSort.newest:
        filtered.sort((a, b) => b.debt.createdAt.compareTo(a.debt.createdAt));
      case _DebtSort.amount:
        filtered.sort(
          (a, b) => b.outstandingAmount.compareTo(a.outstandingAmount),
        );
      case _DebtSort.group:
        filtered.sort((a, b) {
          final aGroup = a.debt.groupId == null
              ? ''
              : groupNames[a.debt.groupId] ?? '';
          final bGroup = b.debt.groupId == null
              ? ''
              : groupNames[b.debt.groupId] ?? '';
          final byGroup = aGroup.toLowerCase().compareTo(bGroup.toLowerCase());
          return byGroup == 0
              ? a.debt.title.toLowerCase().compareTo(b.debt.title.toLowerCase())
              : byGroup;
        });
    }

    return filtered;
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.keyValue,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String keyValue;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: Key(keyValue),
            isExpanded: true,
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _DebtOverviewTile extends StatelessWidget {
  const _DebtOverviewTile({required this.overview, required this.groupName});

  final DebtOverview overview;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final debt = overview.debt;
    final dueDate = debt.dueDate == null
        ? 'Tanpa jatuh tempo'
        : 'Jatuh tempo ${formatDate(debt.dueDate!)}';

    return Card(
      key: Key('debt-tile-${debt.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: ListTile(
        onTap: () => context.push(AppRoutes.debtDetail(debt.id)),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.receipt_long_outlined,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(debt.title),
        subtitle: Text(
          <String>[
            groupName ?? 'Unassigned',
            dueDate,
            'Sisa ${formatRupiah(overview.outstandingAmount)}',
          ].join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: DebtStatusChip(status: overview.status),
      ),
    );
  }
}
