import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';

/// Konfigurasi aplikasi yang dimuat dari `--dart-define`.
///
/// Nilai dapat di-override pada test tanpa bergantung pada environment build.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
