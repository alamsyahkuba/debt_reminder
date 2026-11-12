import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/customer.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({this.customerId, super.key});

  final String? customerId;

  bool get isEditing => customerId != null;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Customer? _existing;
  bool _loadingInitial = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadingInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomer());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomer() async {
    final customerId = widget.customerId;
    if (customerId == null) {
      return;
    }

    try {
      final customer = await ref
          .read(customerRepositoryProvider)
          .findById(customerId);
      if (!mounted) {
        return;
      }

      if (customer == null) {
        setState(() {
          _loadingInitial = false;
          _loadError = 'Pelanggan tidak ditemukan.';
        });
        return;
      }

      _existing = customer;
      _nameController.text = customer.name;
      _phoneController.text = customer.phone ?? '';
      _notesController.text = customer.notes ?? '';
      setState(() => _loadingInitial = false);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingInitial = false;
        _loadError = 'Pelanggan tidak dapat dimuat.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Pelanggan' : 'Tambah Pelanggan'),
      ),
      body: _loadingInitial
          ? const LoadingState(label: 'Memuat pelanggan...')
          : _loadError != null
          ? ErrorState(message: _loadError!, onRetry: _loadCustomer)
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextFormField(
            key: const Key('customer-name-field'),
            controller: _nameController,
            textInputAction: TextInputAction.next,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Nama pelanggan',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama pelanggan wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Nomor telepon (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
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
            key: const Key('customer-save-button'),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final repository = ref.read(customerRepositoryProvider);

      if (widget.isEditing) {
        final existing = _existing;
        if (existing == null) {
          throw const AppException(
            code: AppErrorCode.notFound,
            message: 'Pelanggan tidak ditemukan.',
          );
        }

        await repository.update(
          id: existing.id,
          expectedVersion: existing.version,
          name: _nameController.text,
          phone: _phoneController.text,
          notes: _notesController.text,
        );
      } else {
        await repository.create(
          name: _nameController.text,
          phone: _phoneController.text,
          notes: _notesController.text,
        );
      }

      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.customers);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Pelanggan tidak dapat disimpan.');
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
