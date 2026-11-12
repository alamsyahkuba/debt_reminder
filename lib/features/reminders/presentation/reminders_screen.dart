import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      key: Key('reminders-screen'),
      icon: Icons.notifications_none,
      title: 'Reminder',
      description:
          'Pengingat jatuh tempo akan dijadwalkan di perangkat ini dan tetap '
          'bekerja tanpa internet.',
    );
  }
}
