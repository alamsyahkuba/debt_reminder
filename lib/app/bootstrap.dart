import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';
import 'theme.dart';

/// Keeps the branded startup screen visible for a short minimum duration after
/// the local database is ready. Android 12 native splash cannot render text,
/// so the app name is shown here before the dashboard appears.
final startupReadyProvider = FutureProvider<void>((ref) async {
  await ref.watch(databaseReadyProvider.future);
  await Future<void>.delayed(const Duration(milliseconds: 800));
});

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(startupReadyProvider)
        .when(
          data: (_) => const DebtReminderApp(),
          loading: () => _StartupApp(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Menyiapkan database lokal...'),
              ],
            ),
          ),
          error: (error, stackTrace) => _StartupErrorApp(
            onRetry: () {
              ref.invalidate(databaseReadyProvider);
              ref.invalidate(startupReadyProvider);
            },
          ),
        );
  }
}

class _StartupApp extends StatelessWidget {
  const _StartupApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Debt Reminder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: const Locale('id'),
      supportedLocales: const <Locale>[Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Image.asset(
                      'assets/branding/splash_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Debt Reminder',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _StartupApp(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.storage_outlined, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Database lokal tidak dapat dibuka.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Coba lagi. Jika masalah berlanjut, periksa ruang penyimpanan '
              'perangkat.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
