import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../../debts/application/debt_providers.dart';

class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({required this.debtId, super.key});

  final String debtId;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  DateTime _paidAt = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = formatDate(_paidAt);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(debtOverviewByIdProvider(widget.debtId));

    return Scaffold(
      key: const Key('payment-form-screen'),
      appBar: AppBar(title: const Text('Catat Pembayaran')),
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

          return _buildForm(context, overview.outstandingAmount);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, int outstanding) {
    final paidOff = outstanding <= 0;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              paidOff
                  ? 'Hutang ini sudah lunas.'
                  : 'Sisa hutang: ${formatRupiah(outstanding)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('payment-amount-field'),
            controller: _amountController,
            enabled: !paidOff,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: 'Nominal pembayaran',
              prefixText: 'Rp ',
              border: const OutlineInputBorder(),
              helperText: paidOff
                  ? null
                  : 'Maksimal ${formatRupiah(outstanding)}',
            ),
            validator: (value) {
              if (paidOff) {
                return 'Hutang sudah lunas.';
              }
              final amount = int.tryParse(value?.trim() ?? '');
              if (amount == null || amount <= 0) {
                return 'Nominal harus berupa angka positif.';
              }
              if (amount > outstanding) {
                return 'Nominal melebihi sisa hutang.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('payment-date-field'),
            controller: _dateController,
            readOnly: true,
            enabled: !paidOff,
            onTap: _pickDate,
            decoration: const InputDecoration(
              labelText: 'Tanggal pembayaran',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('payment-notes-field'),
            controller: _notesController,
            enabled: !paidOff,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pembayaran akan disimpan lokal dan masuk antrean sinkronisasi.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (!paidOff) ...<Widget>[
            FilledButton.tonalIcon(
              key: const Key('payment-pay-full-button'),
              onPressed: _saving ? null : () => _payFull(outstanding),
              icon: const Icon(Icons.done_all),
              label: Text('Bayar Lunas (${formatRupiah(outstanding)})'),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            key: const Key('payment-save-button'),
            onPressed: _saving || paidOff ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan Pembayaran'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selected != null && mounted) {
      setState(() {
        _paidAt = selected;
        _dateController.text = formatDate(selected);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = int.parse(_amountController.text.trim());
    await _confirmAndSave(amount: amount, fullPayment: false);
  }

  Future<void> _payFull(int outstanding) async {
    if (outstanding <= 0 || _saving) {
      return;
    }
    await _confirmAndSave(amount: outstanding, fullPayment: true);
  }

  Future<void> _confirmAndSave({
    required int amount,
    required bool fullPayment,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: fullPayment ? 'Bayar lunas?' : 'Catat pembayaran?',
      message:
          '${fullPayment ? 'Pembayaran lunas' : 'Pembayaran'} '
          '${formatRupiah(amount)} pada ${formatDate(_paidAt)} akan disimpan '
          'permanen dan tidak dapat diubah.',
      confirmLabel: fullPayment ? 'Bayar Lunas' : 'Simpan',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _saving = true);

    try {
      await ref
          .read(paymentRepositoryProvider)
          .create(
            debtId: widget.debtId,
            amount: amount,
            paidAt: _paidAt,
            notes: _notesController.text,
          );

      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.debtDetail(widget.debtId));
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Pembayaran tidak dapat disimpan.');
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
