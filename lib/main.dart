import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app/bootstrap.dart';
import 'app/providers.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'data/sync/background_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  const logger = AppLogger('main');

  if (!config.hasSupabaseConfig) {
    logger.debug(
      'Konfigurasi Supabase belum tersedia; aplikasi berjalan tanpa backend.',
    );
  } else {
    await _configureBackgroundSync(logger);
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const AppBootstrap(),
    ),
  );
}

Future<void> _configureBackgroundSync(AppLogger logger) async {
  try {
    await Workmanager().initialize(backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      'debt-reminder-sync',
      backgroundSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (_) {
    logger.debug(
      'WorkManager tidak tersedia; sinkronisasi foreground tetap aktif.',
    );
  }
}
