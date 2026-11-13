import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/sync/presentation/sync_lifecycle.dart';
import 'router.dart';
import 'theme.dart';

class DebtReminderApp extends ConsumerWidget {
  const DebtReminderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return SyncLifecycle(
      child: MaterialApp.router(
        title: 'Catatan Hutang',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        locale: const Locale('id'),
        supportedLocales: const <Locale>[Locale('id')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
      ),
    );
  }
}
