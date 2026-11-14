import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/currency_formatter.dart';
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _installmentController = TextEditingController();
  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _defaultDueDateController =
      TextEditingController();

  String? _selectedGroupId;
  DateTime? _defaultDueDate;
  bool _monthlyDueDates = false;
  bool _saving = false;
  String? _formError;
  String? _nameError;
  String? _installmentError;
  String? _principalError;
  String? _notesError;

  @override
  void dispose() {
    _nameController.dispose();
    _installmentController.dispose();
    _principalController.dispose();
    _notesController.dispose();
    _defaultDueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(allGroupsProvider);

    return Scaffold(
      key: const Key('bulk-debt-screen'),
      appBar: AppBar(title: const Text('Bulk Insert Hutang')),
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
                onPressed: _saving ? null : _save,
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
                      : 'Simpan ${_installmentCount()} hutang',
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildForm(BuildContext context, List<DebtGroup> groups) {
    final theme = Theme.of(context);
    final drafts = _tryBuildDrafts();
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
                    Text('Data angsuran', style: theme.textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Hutang dibuat otomatis dengan judul Nama 1, Nama 2, dan '
                  'seterusnya sesuai jumlah angsuran.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('bulk-debt-name-field'),
                  controller: _nameController,
                  maxLength: 190,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Nama hutang',
                    hintText: 'Contoh: Budi',
                    border: const OutlineInputBorder(),
                    errorText: _nameError,
                  ),
                  onChanged: (_) => _onFieldChanged(),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('bulk-debt-installment-field'),
                  controller: _installmentController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  maxLength: 2,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Jumlah angsuran',
                    hintText: '1-$maxDebtBatchSize',
                    border: const OutlineInputBorder(),
                    errorText: _installmentError,
                  ),
                  onChanged: (_) => _onFieldChanged(),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('bulk-debt-principal-field'),
                  controller: _principalController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Pokok per angsuran',
                    prefixText: 'Rp ',
                    border: const OutlineInputBorder(),
                    errorText: _principalError,
                  ),
                  onChanged: (_) => _onFieldChanged(),
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 8),
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
                CheckboxListTile(
                  key: const Key('bulk-debt-monthly-checkbox'),
                  value: _monthlyDueDates,
                  onChanged: _defaultDueDate == null
                      ? null
                      : _setMonthlyDueDates,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Jatuh tempo per bulan'),
                  subtitle: const Text(
                    'Angsuran 1 memakai tanggal default, angsuran berikutnya '
                    '+1 bulan.',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('bulk-debt-notes-field'),
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: 'Catatan (opsional, sama untuk semua)',
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    errorText: _notesError,
                  ),
                  onChanged: (_) => _onFieldChanged(includeNotes: true),
                ),
                if (_formError != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    _formError!,
                    key: const Key('bulk-debt-form-error'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPreview(context, drafts),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, List<DebtDraft>? drafts) {
    final theme = Theme.of(context);
    if (drafts == null || drafts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Icon(Icons.preview_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Isi nama, jumlah angsuran, dan pokok per angsuran untuk '
                  'melihat pratinjau.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final total = drafts.fold<int>(
      0,
      (sum, draft) => sum + draft.principalAmount,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.format_list_numbered,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pratinjau ${drafts.length} hutang',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < drafts.length; index++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
                title: Text(drafts[index].title),
                subtitle: Text(
                  '${formatRupiah(drafts[index].principalAmount)} • '
                  '${drafts[index].dueDate == null ? 'Tanpa jatuh tempo' : formatDate(drafts[index].dueDate!)}',
                ),
              ),
            const Divider(),
            Text(
              'Total: ${formatRupiah(total)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onFieldChanged({bool includeNotes = false}) {
    setState(() {
      _nameError = null;
      _installmentError = null;
      _principalError = null;
      _formError = null;
      if (includeNotes) {
        _notesError = null;
      }
    });
  }

  int _installmentCount() {
    return int.tryParse(_installmentController.text.trim()) ?? 0;
  }

  List<DebtDraft>? _tryBuildDrafts() {
    final name = _nameController.text.trim();
    final count = _installmentCount();
    final principal = int.tryParse(_principalController.text.trim());
    final notes = _notesController.text.trim();
    if (name.isEmpty ||
        count < 1 ||
        count > maxDebtBatchSize ||
        principal == null ||
        principal <= 0 ||
        principal > maxSafeRupiah ||
        notes.length > 2000) {
      return null;
    }

    final baseDate = _defaultDueDate;
    return <DebtDraft>[
      for (var index = 0; index < count; index++)
        DebtDraft(
          title: '$name ${index + 1}',
          principalAmount: principal,
          dueDate: baseDate == null
              ? null
              : _monthlyDueDates
              ? addMonthsClamped(baseDate, index)
              : baseDate,
          notes: notes.isEmpty ? null : notes,
        ),
    ];
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
      _monthlyDueDates = false;
      _defaultDueDateController.clear();
    });
  }

  void _setMonthlyDueDates(bool? value) {
    if (_defaultDueDate == null) {
      return;
    }
    setState(() => _monthlyDueDates = value ?? false);
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
    if (_saving || !_validateFields()) {
      return;
    }

    final drafts = _tryBuildDrafts();
    if (drafts == null || drafts.isEmpty) {
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

  bool _validateFields() {
    final name = _nameController.text.trim();
    final count = _installmentCount();
    final principal = int.tryParse(_principalController.text.trim());
    final notes = _notesController.text.trim();

    final nameError = name.isEmpty
        ? 'Nama hutang wajib diisi.'
        : count >= 1 && count <= maxDebtBatchSize
        ? '$name $count'.length > 200
              ? 'Nama terlalu panjang untuk format Nama 1, Nama 2, ...'
              : null
        : null;
    final installmentError = count < 1 || count > maxDebtBatchSize
        ? 'Jumlah angsuran harus 1-$maxDebtBatchSize.'
        : null;
    final principalError = principal == null || principal <= 0
        ? 'Pokok per angsuran harus berupa angka positif.'
        : principal > maxSafeRupiah
        ? 'Pokok per angsuran terlalu besar.'
        : null;
    final notesError = notes.length > 2000
        ? 'Catatan maksimal 2000 karakter.'
        : null;

    setState(() {
      _nameError = nameError;
      _installmentError = installmentError;
      _principalError = principalError;
      _notesError = notesError;
      _formError =
          nameError != null ||
              installmentError != null ||
              principalError != null ||
              notesError != null
          ? 'Periksa field yang ditandai.'
          : null;
    });

    return nameError == null &&
        installmentError == null &&
        principalError == null &&
        notesError == null;
  }

  Future<bool?> _confirmSave(int count) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Simpan $count hutang?'),
          content: const Text(
            'Hutang akan dibuat otomatis dengan nomor urut pada judul dan '
            'disimpan sebagai satu batch. Data langsung tersedia lokal dan '
            'menunggu sinkronisasi admin.',
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
