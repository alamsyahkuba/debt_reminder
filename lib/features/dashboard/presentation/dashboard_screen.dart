import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      key: Key('dashboard-screen'),
      icon: Icons.space_dashboard_outlined,
      title: 'Dashboard',
      description:
          'Ringkasan total hutang, pembayaran, dan jatuh tempo akan tampil '
          'di sini setelah data lokal tersedia.',
    );
  }
}
