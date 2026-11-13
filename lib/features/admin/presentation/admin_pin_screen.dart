import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/navigation.dart';
import '../../../core/errors/admin_auth_exception.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/entities/admin_session.dart';
import '../../../shared/widgets/error_state.dart';
import '../../../shared/widgets/loading_state.dart';
import '../application/admin_providers.dart';

class AdminPinScreen extends ConsumerStatefulWidget {
  const AdminPinScreen({super.key});

  @override
  ConsumerState<AdminPinScreen> createState() => _AdminPinScreenState();
}

class _AdminPinScreenState extends ConsumerState<AdminPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _busy = false;
  String? _pinError;
  String? _changeError;
  String? _changeSuccess;

  @override
  void dispose() {
    _pinController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(adminSessionControllerProvider);

    return Scaffold(
      key: const Key('admin-pin-screen'),
      backgroundColor: Colors.transparent,
      body: sessionAsync.when(
        loading: () => const LoadingState(label: 'Memeriksa sesi admin...'),
        error: (error, stackTrace) => ErrorState(
          message: 'Sesi admin tidak dapat dibaca dari penyimpanan aman.',
          onRetry: () => ref.invalidate(adminSessionControllerProvider),
        ),
        data: (session) => session == null
            ? _buildPinForm(context)
            : _buildAdminPanel(context, session),
      ),
    );
  }

  Widget _buildPinForm(BuildContext context) {
    final theme = Theme.of(context);
    final canSubmit = !_busy && _pinController.text.trim().length == 6;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      children: <Widget>[
        Icon(
          Icons.admin_panel_settings_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Masuk sebagai Admin',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan PIN 6 digit. PIN diverifikasi oleh server sebelum aksi '
          'pengelolaan data dapat digunakan.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          key: const Key('admin-pin-field'),
          controller: _pinController,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 12),
          decoration: const InputDecoration(
            labelText: 'PIN Admin',
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _pinError = null),
          onSubmitted: (_) {
            if (!_busy && _pinController.text.trim().length == 6) {
              _submitPin();
            }
          },
        ),
        if (_pinError != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _pinError!,
            key: const Key('admin-pin-error'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const Key('admin-pin-submit'),
          onPressed: canSubmit ? _submitPin : null,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open_outlined),
          label: Text(_busy ? 'Memverifikasi...' : 'Buka Admin'),
        ),
        const SizedBox(height: 16),
        Text(
          'Verifikasi PIN membutuhkan koneksi ke server. Offline unlock tidak '
          'tersedia; sesi admin hanya berlaku 15 menit.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminPanel(BuildContext context, AdminSession session) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Admin aktif', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        'Sesi berakhir ${formatDateTime(session.expiresAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('admin-lock-button'),
          onPressed: _busy ? null : _lock,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Kunci Admin & Cabut Sesi'),
        ),
        const SizedBox(height: 24),
        Text('Ubah PIN', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Ganti PIN secara berkala. Sesi di perangkat lain akan dicabut setelah '
          'PIN berhasil diubah.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _pinField(
          keyValue: 'admin-current-pin-field',
          controller: _currentPinController,
          label: 'PIN saat ini',
        ),
        const SizedBox(height: 12),
        _pinField(
          keyValue: 'admin-new-pin-field',
          controller: _newPinController,
          label: 'PIN baru',
        ),
        const SizedBox(height: 12),
        _pinField(
          keyValue: 'admin-confirm-pin-field',
          controller: _confirmPinController,
          label: 'Ulangi PIN baru',
        ),
        if (_changeError != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _changeError!,
            key: const Key('admin-change-pin-error'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (_changeSuccess != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _changeSuccess!,
            key: const Key('admin-change-pin-success'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('admin-change-pin-button'),
          onPressed: _busy ? null : _changePin,
          icon: const Icon(Icons.password_outlined),
          label: const Text('Ubah PIN'),
        ),
      ],
    );
  }

  Widget _pinField({
    required String keyValue,
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      key: Key(keyValue),
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {
        _changeError = null;
        _changeSuccess = null;
      }),
    );
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      setState(() => _pinError = 'PIN harus terdiri dari 6 digit angka.');
      return;
    }

    setState(() {
      _busy = true;
      _pinError = null;
    });

    try {
      await ref.read(adminSessionControllerProvider.notifier).unlock(pin);
      if (!mounted) {
        return;
      }

      _pinController.clear();
      final returnTo = _safeReturnTo(
        GoRouterState.of(context).uri.queryParameters['returnTo'],
      );
      if (returnTo != null) {
        context.go(returnTo);
      }
    } on AdminAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _pinError = _messageFor(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pinError = 'PIN tidak dapat diverifikasi. Coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _lock() async {
    setState(() {
      _busy = true;
      _changeError = null;
      _changeSuccess = null;
    });

    try {
      await ref
          .read(adminSessionControllerProvider.notifier)
          .lock(revokeServerSession: true);
      if (mounted) {
        _showMessage('Admin dikunci dan sesi server dicabut.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _changePin() async {
    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (currentPin.length != 6 ||
        newPin.length != 6 ||
        confirmPin.length != 6) {
      setState(() {
        _changeError = 'Semua PIN harus terdiri dari 6 digit angka.';
        _changeSuccess = null;
      });
      return;
    }

    if (currentPin == newPin) {
      setState(() {
        _changeError = 'PIN baru harus berbeda dari PIN saat ini.';
        _changeSuccess = null;
      });
      return;
    }

    if (newPin != confirmPin) {
      setState(() {
        _changeError = 'Ulangi PIN baru dengan benar.';
        _changeSuccess = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _changeError = null;
      _changeSuccess = null;
    });

    try {
      await ref
          .read(adminSessionControllerProvider.notifier)
          .changePin(currentPin: currentPin, newPin: newPin);
      if (!mounted) {
        return;
      }
      _currentPinController.clear();
      _newPinController.clear();
      _confirmPinController.clear();
      setState(() => _changeSuccess = 'PIN admin berhasil diubah.');
    } on AdminAuthException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _changeError = _messageFor(error));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _changeError = 'PIN admin tidak dapat diubah.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _messageFor(AdminAuthException error) {
    if (error.code == 'rate_limited') {
      final seconds = error.retryAfterSeconds;
      final minutes = seconds == null ? null : (seconds / 60).ceil();
      return minutes == null
          ? 'Terlalu banyak percobaan PIN. Coba lagi nanti.'
          : 'Terlalu banyak percobaan PIN. Coba lagi dalam $minutes menit.';
    }

    if (error.isNetworkError) {
      return '${error.message} Admin tidak dapat dibuka offline.';
    }

    return error.message;
  }

  String? _safeReturnTo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.path.startsWith('/') ||
        uri.path.startsWith('//') ||
        uri.path == AppRoutes.admin) {
      return null;
    }

    return uri.toString();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
