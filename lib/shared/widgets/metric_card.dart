import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.width = 160,
    super.key,
  });

  final String label;
  final String value;
  final bool emphasize;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: emphasize
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasize ? colors.onPrimaryContainer : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
