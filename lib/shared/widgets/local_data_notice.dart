import 'package:flutter/material.dart';

class LocalDataNotice extends StatelessWidget {
  const LocalDataNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.offline_bolt_outlined, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data lokal • tetap tersedia tanpa internet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
