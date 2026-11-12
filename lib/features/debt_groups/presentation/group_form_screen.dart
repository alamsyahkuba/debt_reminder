import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/debt_group.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import 'group_visuals.dart';

class GroupFormScreen extends ConsumerStatefulWidget {
  const GroupFormScreen({this.groupId, super.key});

  final String? groupId;

  bool get isEditing => groupId != null;

  @override
  ConsumerState<GroupFormScreen> createState() => _GroupFormScreenState();
}

class _GroupFormScreenState extends ConsumerState<GroupFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _sortOrderController = TextEditingController(
    text: '0',
  );

  DebtGroup? _existing;
  String? _selectedColor = groupColorChoices.first;
  String? _selectedIcon = 'folder';
  bool _loadingInitial = false;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadingInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGroup());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _loadGroup() async {
    final groupId = widget.groupId;
    if (groupId == null) {
      return;
    }

    try {
      final group = await ref
          .read(debtGroupRepositoryProvider)
          .findById(groupId);
      if (!mounted) {
        return;
      }

      if (group == null) {
        setState(() {
          _loadingInitial = false;
          _loadError = 'Group tidak ditemukan.';
        });
        return;
      }

      _existing = group;
      _nameController.text = group.name;
      _descriptionController.text = group.description ?? '';
      _sortOrderController.text = group.sortOrder.toString();
      setState(() {
        _selectedColor = group.color;
        _selectedIcon = group.icon;
        _loadingInitial = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingInitial = false;
        _loadError = 'Group tidak dapat dimuat.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Group' : 'Tambah Group'),
      ),
      body: _loadingInitial
          ? const LoadingState(label: 'Memuat group...')
          : _loadError != null
          ? ErrorState(message: _loadError!, onRetry: _loadGroup)
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextFormField(
            key: const Key('group-name-field'),
            controller: _nameController,
            textInputAction: TextInputAction.next,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Nama group',
              hintText: 'Contoh: Keluarga',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama group wajib diisi.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Deskripsi (opsional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('Warna', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                key: const Key('group-color-none'),
                label: const Text('Tanpa warna'),
                selected: _selectedColor == null,
                onSelected: (_) => setState(() => _selectedColor = null),
              ),
              for (final color in groupColorChoices)
                InkWell(
                  key: Key('group-color-$color'),
                  onTap: () => setState(() => _selectedColor = color),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: groupColorFromHex(
                        color,
                        theme.colorScheme.primary,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedColor == color
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.surface,
                        width: _selectedColor == color ? 3 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Ikon', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                key: const Key('group-icon-none'),
                label: const Text('Tanpa ikon'),
                selected: _selectedIcon == null,
                onSelected: (_) => setState(() => _selectedIcon = null),
              ),
              for (final icon in allowedDebtGroupIcons)
                ChoiceChip(
                  key: Key('group-icon-$icon'),
                  avatar: Icon(groupIconForKey(icon), size: 18),
                  label: Text(groupIconLabels[icon] ?? icon),
                  selected: _selectedIcon == icon,
                  onSelected: (_) => setState(() => _selectedIcon = icon),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _sortOrderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Urutan tampil',
              helperText: 'Angka kecil tampil lebih dahulu.',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final parsed = int.tryParse(value?.trim() ?? '');
              if (parsed == null || parsed < 0 || parsed > 1000000) {
                return 'Urutan harus berupa angka 0-1.000.000.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('group-save-button'),
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
      final repository = ref.read(debtGroupRepositoryProvider);
      final sortOrder = int.parse(_sortOrderController.text.trim());

      if (widget.isEditing) {
        final existing = _existing;
        if (existing == null) {
          throw const AppException(
            code: AppErrorCode.notFound,
            message: 'Group tidak ditemukan.',
          );
        }

        await repository.update(
          id: existing.id,
          expectedVersion: existing.version,
          name: _nameController.text,
          description: _descriptionController.text,
          color: _selectedColor,
          icon: _selectedIcon,
          sortOrder: sortOrder,
        );
      } else {
        await repository.create(
          name: _nameController.text,
          description: _descriptionController.text,
          color: _selectedColor,
          icon: _selectedIcon,
          sortOrder: sortOrder,
        );
      }

      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.groups);
      }
    } on AppException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Group tidak dapat disimpan.');
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
