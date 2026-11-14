import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/backup/backup_file_service.dart';
import '../data/local/app_database.dart';
import '../data/local/dev_seed.dart';
import '../data/repositories/backup_repository_impl.dart';
import '../data/repositories/debt_group_repository_impl.dart';
import '../data/repositories/debt_repository_impl.dart';
import '../data/repositories/payment_repository_impl.dart';
import '../domain/repositories/backup_repository.dart';
import '../domain/repositories/debt_group_repository.dart';
import '../domain/repositories/debt_repository.dart';
import '../domain/repositories/payment_repository.dart';

/// Konfigurasi aplikasi yang dimuat dari `--dart-define`.
///
/// Nilai dapat di-override pada test tanpa bergantung pada environment build.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// Database lokal aplikasi. Provider menutup koneksi saat scope dibuang.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Membuka database sebelum shell aplikasi ditampilkan.
///
/// Seed demo hanya berjalan pada environment development dan hanya jika
/// `SEED_DEMO_DATA=true`.
final databaseReadyProvider = FutureProvider<void>((ref) async {
  final database = ref.watch(appDatabaseProvider);
  await database.ensureOpen();

  final config = ref.watch(appConfigProvider);
  if (config.environment == AppEnvironment.development && config.seedDemoData) {
    await seedDevelopmentData(database);
  }
});

final debtGroupRepositoryProvider = Provider<DebtGroupRepository>((ref) {
  return DebtGroupRepositoryImpl(ref.watch(appDatabaseProvider));
});

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepositoryImpl(ref.watch(appDatabaseProvider));
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(ref.watch(appDatabaseProvider));
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepositoryImpl(ref.watch(appDatabaseProvider));
});

final backupFileServiceProvider = Provider<BackupFileService>((ref) {
  return BackupFileService();
});
