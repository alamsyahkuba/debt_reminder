import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class AdminPinScreen extends StatelessWidget {
  const AdminPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      key: Key('admin-pin-screen'),
      icon: Icons.lock_outline,
      title: 'PIN Admin',
      description:
          'Masukkan PIN untuk membuka fitur pengelolaan data. Gerbang PIN dan '
          'sesi admin akan diaktifkan pada tahap berikutnya.',
    );
  }
}
