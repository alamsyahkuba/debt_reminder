import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      key: Key('debts-screen'),
      icon: Icons.receipt_long_outlined,
      title: 'Semua Hutang',
      description:
          'Daftar seluruh hutang, pencarian, filter, dan status pembayaran '
          'akan tersedia di sini.',
    );
  }
}
