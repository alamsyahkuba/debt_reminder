import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_update_providers.dart';

/// Runs one update check when the app opens and retries on resume after a
/// cooldown. It never interrupts an already available/downloaded update.
class AppUpdateLifecycle extends ConsumerStatefulWidget {
  const AppUpdateLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppUpdateLifecycle> createState() => _AppUpdateLifecycleState();
}

class _AppUpdateLifecycleState extends ConsumerState<AppUpdateLifecycle>
    with WidgetsBindingObserver {
  static const Duration _resumeCooldown = Duration(minutes: 30);

  DateTime? _lastCheckAt;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (ref.read(appUpdateAutoCheckProvider)) {
      _scheduleCheck(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleCheck();
    }
  }

  void _scheduleCheck({bool force = false}) {
    if (!ref.read(appUpdateAutoCheckProvider) || _checkScheduled) {
      return;
    }

    final updateState = ref.read(appUpdateControllerProvider);
    if (updateState.status == AppUpdateStatus.checking ||
        updateState.status == AppUpdateStatus.downloading ||
        updateState.status == AppUpdateStatus.readyToInstall ||
        updateState.status == AppUpdateStatus.permissionRequired ||
        updateState.status == AppUpdateStatus.installerOpened ||
        updateState.status == AppUpdateStatus.available) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastCheckAt != null &&
        now.difference(_lastCheckAt!) < _resumeCooldown) {
      return;
    }

    _lastCheckAt = now;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || !ref.read(appUpdateAutoCheckProvider)) {
        return;
      }
      unawaited(ref.read(appUpdateControllerProvider.notifier).check());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
