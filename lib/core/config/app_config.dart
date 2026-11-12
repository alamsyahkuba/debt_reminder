/// Environment build yang didukung aplikasi.
enum AppEnvironment {
  development('development'),
  staging('staging'),
  production('production');

  const AppEnvironment(this.value);

  final String value;

  static AppEnvironment fromName(String name) {
    final normalizedName = name.trim().toLowerCase();

    return values.firstWhere(
      (environment) => environment.value == normalizedName,
      orElse: () => AppEnvironment.development,
    );
  }
}

/// Konfigurasi runtime yang aman untuk dibundel di client.
///
/// Hanya URL Supabase dan anon/publishable key yang boleh berada di sini.
/// `service_role` key tidak boleh pernah dimuat oleh aplikasi Flutter.
final class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppConfig.fromEnvironment() {
    const environmentName = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    return AppConfig(
      environment: AppEnvironment.fromName(environmentName),
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
