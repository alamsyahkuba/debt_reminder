import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/debt.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../application/debt_providers.dart';

class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({this.debtId, super.key});

  final String? debtId;

  bool get isEditing => debtId != null;

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _principalController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();

  Debt? _existing;
  String? _selectedGroupId;
  DateTime? _dueDate;
  bool _loadingInitial = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadingInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadDebt());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _principalController.dispose();
    _notesController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _loadDebt() async {
    final debtId = widget.debtId;
    if (debtId == null) {
      return;
    }

    try {
      final debt = await ref.read(debtRepositoryProvider).findById(debtId);
      if (!mounted) {
        return;
      }

      if (debt == null) {
        setState(() {
          _loadingInitial = false;
          _loadError = 'Hutang tidak ditemukan.';
        });
        return;
      }

      _existing = debt;
      _titleController.text = debt.title;
      _principalController.text = debt.principalAmount.toString();
      _notesController.text = debt.notes ?? '';
      _dueDate = debt.dueDate;
      _dueDateController.text = debt.dueDate == null
          ? ''
          : formatDate(debt.dueDate!);
      setState(() {
        _selectedGroupId = debt.groupId;
        _loadingInitial = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingInitial = false;
        _loadError = 'Hutang tidak dapat dimuat.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('debt-form-screen'),
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Hutang' : 'Tambah Hutang'),
      ),
      body: _loadingInitial
          ? const LoadingState(label: 'Memuat hutang...')
          : _loadError != null
          ? ErrorState(message: _loadError!, onRetry: _loadDebt)
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final groups = ref.watch(allGroupsProvider).value ?? const <DebtGroup>[];
    final selectedGroupValue =
        groups.any((group) => group.id == _selectedGroupId)
        ? _selectedGroupId ?? ''
        : '';

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextFormField(
            key: const Key('debt-title-field'),
            controller: _titleController,
            textInputAction: TextInputAction.next,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Judul hutang',
              hintText: 'Contoh: Hutang Budi',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Judul hutang wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('debt-principal-field'),
            controller: _principalController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Pokok hutang',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final amount = int.tryParse(value?.trim() ?? '');
              if (amount == null || amount <= 0) {
                return 'Pokok hutang harus berupa angka positif.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Group',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('debt-group-field'),
                isExpanded: true,
                value: selectedGroupValue,
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Tanpa group (Unassigned)'),
                  ),
                  for (final group in groups)
                    DropdownMenuItem<String>(
                      value: group.id,
                      child: Text(
                        group.isArchived ? '${group.name} (arsip)' : group.name,
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGroupId = value == null || value.isEmpty
                        ? null
                        : value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('debt-due-date-field'),
            controller: _dueDateController,
            readOnly: true,
            onTap: _pickDueDate,
            decoration: InputDecoration(
              labelText: 'Jatuh tempo (opsional)',
              border: const OutlineInputBorder(),
              suffixIcon: _dueDate == null
                  ? const Icon(Icons.calendar_today_outlined)
                  : IconButton(
                      key: const Key('debt-due-clear'),
                      tooltip: 'Hapus jatuh tempo',
                      onPressed: () {
                        setState(() {
                          _dueDate = null;
                          _dueDateController.clear();
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('debt-notes-field'),
            controller: _notesController,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('debt-save-button'),
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() {
        _dueDate = DateTime.utc(selected.year, selected.month, selected.day);
        _dueDateController.text = formatDate(selected);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final repository = ref.read(debtRepositoryProvider);
      final principal = int.parse(_principalController.text.trim());

      if (widget.isEditing) {
        final existing = _existing;
        if (existing == null) {
          throw const AppException(
            code: AppErrorCode.notFound,
            message: 'Hutang tidak ditemukan.',
          );
        }

        await repository.update(
          id: existing.id,
          expectedVersion: existing.version,
          groupId: _selectedGroupId,
          title: _titleController.text,
          principalAmount: principal,
          dueDate: _dueDate,
          notes: _notesController.text,
        );
      } else {
        await repository.create(
          groupId: _selectedGroupId,
          title: _titleController.text,
          principalAmount: principal,
          dueDate: _dueDate,
          notes: _notesController.text,
        );
      }

      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.debts);
      }
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

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
