import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../admin/application/admin_providers.dart';
import '../application/sync_providers.dart';

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final connectivityChangesProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return ref.watch(connectivityProvider).onConnectivityChanged;
});

/// Starts foreground sync on app start, resume, and connectivity changes.
///
/// Sync remains best-effort: the actual request result is the source of truth,
/// not the connectivity hint.
class SyncLifecycle extends ConsumerStatefulWidget {
  const SyncLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<SyncLifecycle>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _run();
    }
  }

  void _start() {
    if (!mounted) {
      return;
    }
    if (!ref.read(appConfigProvider).hasSupabaseConfig) {
      return;
    }

    _subscription = ref.read(connectivityProvider).onConnectivityChanged.listen(
      (results) {
        if (results.any((result) => result != ConnectivityResult.none)) {
          _run();
        }
      },
    );
    _run();
  }

  void _run() {
    if (!mounted) {
      return;
    }
    unawaited(ref.read(syncRunControllerProvider.notifier).syncNow());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(adminSessionControllerProvider, (previous, next) {
      if (next.hasValue) {
        _scheduleRun();
      }
    });

    return widget.child;
  }

  void _scheduleRun() {
    if (!ref.read(appConfigProvider).hasSupabaseConfig) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }
}
