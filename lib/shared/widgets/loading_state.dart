import 'package:flutter/material.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({this.label = 'Memuat data...', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    );
  }
}
