import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      key: Key('settings-screen'),
      icon: Icons.settings_outlined,
      title: 'Pengaturan',
      description:
          'Preferensi reminder, sinkronisasi, dan keamanan admin akan tersedia '
          'di sini.',
    );
  }
}
