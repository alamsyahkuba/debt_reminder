import 'package:debt_reminder/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment.fromName', () {
    test('mengenali nama environment yang valid', () {
      expect(
        AppEnvironment.fromName('development'),
        AppEnvironment.development,
      );
      expect(AppEnvironment.fromName('STAGING'), AppEnvironment.staging);
      expect(
        AppEnvironment.fromName(' production '),
        AppEnvironment.production,
      );
    });

    test('fallback ke development untuk nama yang tidak dikenal', () {
      expect(AppEnvironment.fromName('unknown'), AppEnvironment.development);
      expect(AppEnvironment.fromName(''), AppEnvironment.development);
    });
  });

  group('AppConfig.hasSupabaseConfig', () {
    test('true hanya jika URL dan anon key terisi', () {
      const AppConfig complete = AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      );
      const AppConfig missingUrl = AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: '',
        supabaseAnonKey: 'anon-key',
      );
      const AppConfig missingKey = AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: '',
      );
      const AppConfig whitespace = AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: '   ',
        supabaseAnonKey: 'anon-key',
      );

      expect(complete.hasSupabaseConfig, isTrue);
      expect(missingUrl.hasSupabaseConfig, isFalse);
      expect(missingKey.hasSupabaseConfig, isFalse);
      expect(whitespace.hasSupabaseConfig, isFalse);
    });
  });
}
