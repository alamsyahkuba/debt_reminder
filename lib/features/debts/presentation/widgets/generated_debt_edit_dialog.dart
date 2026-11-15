import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../domain/entities/debt_draft.dart';
import '../../../../domain/validation/entity_validation.dart';

Future<DebtDraft?> showGeneratedDebtEditDialog({
  required BuildContext context,
  required int index,
  required DebtDraft initial,
}) {
  return showDialog<DebtDraft>(
    context: context,
    builder: (dialogContext) {
      return _GeneratedDebtEditDialog(index: index, initial: initial);
    },
  );
}

class _GeneratedDebtEditDialog extends StatefulWidget {
  const _GeneratedDebtEditDialog({required this.index, required this.initial});

  final int index;
  final DebtDraft initial;

  @override
  State<_GeneratedDebtEditDialog> createState() =>
      _GeneratedDebtEditDialogState();
}

class _GeneratedDebtEditDialogState extends State<_GeneratedDebtEditDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _principalController;
  late final TextEditingController _notesController;
  late final TextEditingController _dueDateController;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial.title);
    _principalController = TextEditingController(
      text: '${widget.initial.principalAmount}',
    );
    _notesController = TextEditingController(text: widget.initial.notes ?? '');
    _dueDate = widget.initial.dueDate;
    _dueDateController = TextEditingController(
      text: _dueDate == null ? '' : formatDate(_dueDate!),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _principalController.dispose();
    _notesController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Hutang ${widget.index + 1}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                key: const Key('bulk-debt-edit-title'),
                controller: _titleController,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Judul hutang',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Judul hutang wajib diisi.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('bulk-debt-edit-principal'),
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
                  if (amount > maxSafeRupiah) {
                    return 'Pokok hutang terlalu besar.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('bulk-debt-edit-due-date'),
                controller: _dueDateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  labelText: 'Jatuh tempo (opsional)',
                  border: const OutlineInputBorder(),
                  suffixIcon: _dueDate == null
                      ? const Icon(Icons.calendar_today_outlined)
                      : IconButton(
                          key: const Key('bulk-debt-edit-due-clear'),
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
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('bulk-debt-edit-notes'),
                controller: _notesController,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('bulk-debt-edit-save'),
          onPressed: _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2300),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _dueDate = DateTime.utc(selected.year, selected.month, selected.day);
      _dueDateController.text = formatDate(_dueDate!);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final notes = _notesController.text.trim();
    Navigator.of(context).pop(
      DebtDraft(
        title: _titleController.text.trim(),
        principalAmount: int.parse(_principalController.text.trim()),
        dueDate: _dueDate,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }
}
