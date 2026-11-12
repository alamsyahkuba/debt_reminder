import 'package:flutter/material.dart';

import 'app_drawer.dart';
import 'navigation.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.currentPath, required this.child, super.key});

  final String currentPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final destination = destinationForPath(currentPath);

    return Scaffold(
      appBar: AppBar(title: Text(destination.label)),
      drawer: AppDrawer(currentPath: currentPath),
      body: SafeArea(child: child),
    );
  }
}
