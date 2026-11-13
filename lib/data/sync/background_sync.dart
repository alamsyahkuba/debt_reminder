import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../data/local/app_database.dart';
import '../../data/local/secure_admin_session_store.dart';
import '../../data/remote/admin_sync_repository.dart';
import '../../data/remote/public_read_repository.dart';
import '../../data/sync/admin_sync_service.dart';
import '../../data/sync/public_pull_service.dart';

const String backgroundSyncTask = 'debt-reminder-background-sync';

@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    try {
      await runBackgroundSync();
      return true;
    } catch (_) {
      const AppLogger('background-sync').debug('Background sync failed.');
      return false;
    }
  });
}

Future<void> runBackgroundSync() async {
  final config = AppConfig.fromEnvironment();
  if (!config.hasSupabaseConfig) {
    return;
  }

  final database = AppDatabase();
  final client = http.Client();
  final sessionStore = SecureAdminSessionStore();

  try {
    await database.ensureOpen();
    final publicRepository = PublicReadRepository(
      baseUrl: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      client: client,
    );
    await PublicPullService(
      database: database,
      repository: publicRepository,
    ).pull();

    final session = await sessionStore.read();
    if (session != null && session.isValid) {
      final adminRepository = HttpAdminSyncRepository(
        baseUrl: config.supabaseUrl,
        anonKey: config.supabaseAnonKey,
        client: client,
      );
      await AdminSyncService(
        database: database,
        repository: adminRepository,
      ).sync(token: session.token);
    }
  } finally {
    client.close();
    await database.close();
  }
}
