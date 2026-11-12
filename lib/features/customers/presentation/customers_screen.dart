import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      key: Key('customers-screen'),
      icon: Icons.people_outline,
      title: 'Pelanggan',
      description:
          'Daftar pelanggan dan ringkasan hutang mereka akan tampil di sini.',
    );
  }
}
