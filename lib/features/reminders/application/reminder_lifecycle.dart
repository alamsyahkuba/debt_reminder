import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../debts/application/debt_providers.dart';
import 'reminder_providers.dart';

/// Reconciles local reminders on startup, resume, and debt/payment changes.
class ReminderLifecycle extends ConsumerStatefulWidget {
  const ReminderLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderLifecycle> createState() => _ReminderLifecycleState();
}

class _ReminderLifecycleState extends ConsumerState<ReminderLifecycle>
    with WidgetsBindingObserver {
  bool _reconciling = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleReconcile());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleReconcile();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(debtOverviewsProvider(false), (previous, next) {
      if (next.hasValue) {
        _scheduleReconcile();
      }
    });

    return widget.child;
  }

  void _scheduleReconcile() {
    _dirty = true;
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_reconciling) {
      return;
    }

    _reconciling = true;
    try {
      while (_dirty && mounted) {
        _dirty = false;
        try {
          await _reconcileOnce();
        } catch (_) {
          // Reminder reconciliation is best-effort; debt data stays usable.
        }
      }
    } finally {
      _reconciling = false;
    }
  }

  Future<void> _reconcileOnce() async {
    final preferences = await ref
        .read(reminderPreferencesRepositoryProvider)
        .load();
    if (!preferences.enabled || !mounted) {
      return;
    }

    await ref.read(reminderSchedulerProvider).reconcile();
  }
}
