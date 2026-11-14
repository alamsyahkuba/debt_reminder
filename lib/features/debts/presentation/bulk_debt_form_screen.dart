import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/debt_draft.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../domain/validation/entity_validation.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../application/debt_providers.dart';

class BulkDebtFormScreen extends ConsumerStatefulWidget {
  const BulkDebtFormScreen({super.key});

  @override
  ConsumerState<BulkDebtFormScreen> createState() => _BulkDebtFormScreenState();
}

class _BulkDebtFormScreenState extends ConsumerState<BulkDebtFormScreen> {
  final List<_BulkDebtRow> _rows = <_BulkDebtRow>[_BulkDebtRow(id: 0)];
  final TextEditingController _defaultDueDateController =
      TextEditingController();
  final Map<int, _RowErrors> _rowErrors = <int, _RowErrors>{};

  int _nextRowId = 1;
  int _lastActiveCount = 0;
  String? _selectedGroupId;
  DateTime? _defaultDueDate;
  String? _formError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _attachRow(_rows.first);
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _defaultDueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(allGroupsProvider);

    return Scaffold(
      key: const Key('bulk-debt-screen'),
      appBar: AppBar(title: const Text('Tambah Banyak Hutang')),
      body: groups.when(
        loading: () => const LoadingState(label: 'Memuat group...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Group tidak dapat dimuat.',
          onRetry: () => ref.invalidate(allGroupsProvider),
        ),
        data: (items) => _buildForm(context, items),
      ),
      bottomNavigationBar: groups.hasValue
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                key: const Key('bulk-debt-save-button'),
                onPressed: _saving || _activeRowCount() == 0 ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving
                      ? 'Menyimpan...'
                      : 'Simpan ${_activeRowCount()} hutang',
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildForm(BuildContext context, List<DebtGroup> groups) {
    final theme = Theme.of(context);
    final selectedGroupValue =
        groups.any((group) => group.id == _selectedGroupId)
        ? _selectedGroupId ?? ''
        : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.playlist_add, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Detail batch', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('bulk-debt-group-field'),
                  initialValue: selectedGroupValue,
                  decoration: const InputDecoration(
                    labelText: 'Group untuk semua hutang',
                    border: OutlineInputBorder(),
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Tanpa group (Unassigned)'),
                    ),
                    for (final group in groups)
                      DropdownMenuItem<String>(
                        value: group.id,
                        child: Text(
                          group.isArchived
                              ? '${group.name} (arsip)'
                              : group.name,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGroupId = value == null || value.isEmpty
                          ? null
                          : value;
                      _formError = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('bulk-debt-default-date'),
                  controller: _defaultDueDateController,
                  readOnly: true,
                  onTap: _pickDefaultDueDate,
                  decoration: InputDecoration(
                    labelText: 'Jatuh tempo default (opsional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: _defaultDueDate == null
                        ? const Icon(Icons.calendar_today_outlined)
                        : IconButton(
                            key: const Key('bulk-debt-default-date-clear'),
                            tooltip: 'Hapus tanggal default',
                            onPressed: _clearDefaultDueDate,
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('bulk-debt-apply-default-date'),
                    onPressed: _defaultDueDate == null
                        ? null
                        : _applyDefaultDueDate,
                    icon: const Icon(Icons.event_repeat_outlined),
                    label: const Text('Terapkan ke semua baris'),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_activeRowCount()}/$maxDebtBatchSize hutang siap disimpan. '
                  'Group dan tanggal default hanya mengisi baris yang kosong.',
                  key: const Key('bulk-debt-summary'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_formError != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _formError!,
            key: const Key('bulk-debt-form-error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var index = 0; index < _rows.length; index++) ...<Widget>[
          _BulkDebtRowEditor(
            key: ValueKey<int>(_rows[index].id),
            row: _rows[index],
            index: index,
            errors: _rowErrors[_rows[index].id] ?? const _RowErrors(),
            canRemove: _rows.length > 1,
            onRemove: () => _removeRow(_rows[index]),
            onPickDate: () => _pickRowDueDate(_rows[index]),
            onClearDate: () => _clearRowDate(_rows[index]),
            onChanged: () => _clearRowError(_rows[index].id),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          key: const Key('bulk-debt-add-row'),
          onPressed: _rows.length >= maxDebtBatchSize ? null : _addRow,
          icon: const Icon(Icons.add),
          label: Text(
            _rows.length >= maxDebtBatchSize
                ? 'Batas $maxDebtBatchSize baris tercapai'
                : 'Tambah baris',
          ),
        ),
      ],
    );
  }

  int _activeRowCount() => _rows.where((row) => !row.isBlank).length;

  void _attachRow(_BulkDebtRow row) {
    row.titleController.addListener(_handleRowTextChanged);
    row.principalController.addListener(_handleRowTextChanged);
    row.notesController.addListener(_handleRowTextChanged);
  }

  void _detachRow(_BulkDebtRow row) {
    row.titleController.removeListener(_handleRowTextChanged);
    row.principalController.removeListener(_handleRowTextChanged);
    row.notesController.removeListener(_handleRowTextChanged);
  }

  void _handleRowTextChanged() {
    final count = _activeRowCount();
    if (count != _lastActiveCount) {
      setState(() => _lastActiveCount = count);
    }
  }

  void _addRow() {
    if (_rows.length >= maxDebtBatchSize) {
      return;
    }

    final row = _BulkDebtRow(id: _nextRowId++);
    _attachRow(row);
    setState(() => _rows.add(row));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        row.titleFocus.requestFocus();
      }
    });
  }

  void _removeRow(_BulkDebtRow row) {
    if (_rows.length == 1) {
      return;
    }
    _detachRow(row);
    setState(() {
      _rows.remove(row);
      _rowErrors.remove(row.id);
      _formError = null;
      _lastActiveCount = _activeRowCount();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _clearRowError(int rowId) {
    if (_rowErrors.containsKey(rowId) || _formError != null) {
      setState(() {
        _rowErrors.remove(rowId);
        _formError = null;
      });
    }
  }

  Future<void> _pickDefaultDueDate() async {
    final selected = await _pickDate(_defaultDueDate);
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _defaultDueDate = selected;
      _defaultDueDateController.text = formatDate(selected);
      _formError = null;
    });
  }

  void _clearDefaultDueDate() {
    setState(() {
      _defaultDueDate = null;
      _defaultDueDateController.clear();
    });
  }

  void _applyDefaultDueDate() {
    final date = _defaultDueDate;
    if (date == null) {
      return;
    }
    setState(() {
      for (final row in _rows) {
        if (row.dueDate == null) {
          row.dueDate = date;
          row.dueDateController.text = formatDate(date);
        }
      }
      _lastActiveCount = _activeRowCount();
    });
  }

  Future<void> _pickRowDueDate(_BulkDebtRow row) async {
    final selected = await _pickDate(row.dueDate ?? _defaultDueDate);
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      row.dueDate = selected;
      row.dueDateController.text = formatDate(selected);
      _rowErrors.remove(row.id);
      _lastActiveCount = _activeRowCount();
    });
  }

  void _clearRowDate(_BulkDebtRow row) {
    setState(() {
      row.dueDate = null;
      row.dueDateController.clear();
      _lastActiveCount = _activeRowCount();
    });
  }

  Future<DateTime?> _pickDate(DateTime? initialDate) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    ).then(
      (selected) => selected == null
          ? null
          : DateTime.utc(selected.year, selected.month, selected.day),
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    final drafts = _validateRows();
    if (drafts == null) {
      return;
    }

    if (drafts.length > 1) {
      final confirmed = await _confirmSave(drafts.length);
      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(debtRepositoryProvider)
          .createMany(groupId: _selectedGroupId, drafts: drafts);

      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.debts);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${drafts.length} hutang ditambahkan dan menunggu sinkronisasi.',
          ),
        ),
      );
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Hutang tidak dapat disimpan.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<DebtDraft>? _validateRows() {
    final errors = <int, _RowErrors>{};
    final drafts = <DebtDraft>[];

    for (final row in _rows) {
      if (row.isBlank) {
        continue;
      }

      final title = row.titleController.text.trim();
      final amount = int.tryParse(row.principalController.text.trim());
      final notes = row.notesController.text.trim();
      final rowErrors = _RowErrors(
        title: title.isEmpty
            ? 'Judul hutang wajib diisi.'
            : title.length > 200
            ? 'Judul maksimal 200 karakter.'
            : null,
        principal: amount == null || amount <= 0
            ? 'Pokok hutang harus berupa angka positif.'
            : amount > maxSafeRupiah
            ? 'Pokok hutang terlalu besar.'
            : null,
        notes: notes.length > 2000 ? 'Catatan maksimal 2000 karakter.' : null,
      );

      if (rowErrors.hasError) {
        errors[row.id] = rowErrors;
        continue;
      }

      drafts.add(
        DebtDraft(
          title: title,
          principalAmount: amount!,
          dueDate: row.dueDate,
          notes: notes.isEmpty ? null : notes,
        ),
      );
    }

    setState(() {
      _rowErrors
        ..clear()
        ..addAll(errors);
      _formError = errors.isNotEmpty
          ? 'Periksa ${errors.length} baris yang ditandai.'
          : drafts.isEmpty
          ? 'Isi minimal satu hutang.'
          : null;
    });

    if (errors.isNotEmpty || drafts.isEmpty) {
      return null;
    }
    return drafts;
  }

  Future<bool?> _confirmSave(int count) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Simpan $count hutang?'),
          content: const Text(
            'Semua baris akan disimpan sebagai satu batch. Data langsung '
            'tersedia lokal dan menunggu sinkronisasi admin.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('bulk-debt-confirm-save'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _formError = message);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BulkDebtRow {
  _BulkDebtRow({required this.id});

  final int id;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController principalController = TextEditingController();
  final TextEditingController dueDateController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final FocusNode titleFocus = FocusNode();
  DateTime? dueDate;

  bool get isBlank =>
      titleController.text.trim().isEmpty &&
      principalController.text.trim().isEmpty &&
      notesController.text.trim().isEmpty &&
      dueDate == null;

  void dispose() {
    titleController.dispose();
    principalController.dispose();
    dueDateController.dispose();
    notesController.dispose();
    titleFocus.dispose();
  }
}

class _RowErrors {
  const _RowErrors({this.title, this.principal, this.notes});

  final String? title;
  final String? principal;
  final String? notes;

  bool get hasError => title != null || principal != null || notes != null;
}

class _BulkDebtRowEditor extends StatelessWidget {
  const _BulkDebtRowEditor({
    required this.row,
    required this.index,
    required this.errors,
    required this.canRemove,
    required this.onRemove,
    required this.onPickDate,
    required this.onClearDate,
    required this.onChanged,
    super.key,
  });

  final _BulkDebtRow row;
  final int index;
  final _RowErrors errors;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Hutang ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: Key('bulk-debt-remove-${row.id}'),
                  tooltip: 'Hapus baris',
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextField(
              key: Key('bulk-debt-title-${row.id}'),
              controller: row.titleController,
              focusNode: row.titleFocus,
              textInputAction: TextInputAction.next,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Judul hutang',
                hintText: 'Contoh: Hutang Budi',
                border: const OutlineInputBorder(),
                errorText: errors.title,
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 8),
            TextField(
              key: Key('bulk-debt-principal-${row.id}'),
              controller: row.principalController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: 'Pokok hutang',
                prefixText: 'Rp ',
                border: const OutlineInputBorder(),
                errorText: errors.principal,
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 8),
            TextField(
              key: Key('bulk-debt-due-${row.id}'),
              controller: row.dueDateController,
              readOnly: true,
              onTap: onPickDate,
              decoration: InputDecoration(
                labelText: 'Jatuh tempo (opsional)',
                border: const OutlineInputBorder(),
                suffixIcon: row.dueDate == null
                    ? const Icon(Icons.calendar_today_outlined)
                    : IconButton(
                        key: Key('bulk-debt-due-clear-${row.id}'),
                        tooltip: 'Hapus jatuh tempo',
                        onPressed: onClearDate,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: Key('bulk-debt-notes-${row.id}'),
              controller: row.notesController,
              maxLines: 2,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'Catatan (opsional)',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
                errorText: errors.notes,
              ),
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}
