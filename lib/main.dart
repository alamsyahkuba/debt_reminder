import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'app/providers.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  const logger = AppLogger('main');

  if (!config.hasSupabaseConfig) {
    logger.debug(
      'Konfigurasi Supabase belum tersedia; aplikasi berjalan tanpa backend.',
    );
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const AppBootstrap(),
    ),
  );
}
