import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      key: Key('groups-screen'),
      icon: Icons.folder_outlined,
      title: 'Group Hutang',
      description:
          'Kelompokkan hutang agar lebih mudah dipantau. Setiap hutang hanya '
          'berada pada satu group, tanpa subgroup.',
    );
  }
}
