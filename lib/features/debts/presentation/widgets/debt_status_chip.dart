import 'package:flutter/material.dart';

import '../../../../domain/entities/debt_status.dart';

String debtStatusLabel(DebtStatus status) {
  return switch (status) {
    DebtStatus.unpaid => 'Belum dibayar',
    DebtStatus.partial => 'Sebagian',
    DebtStatus.paid => 'Lunas',
    DebtStatus.overdue => 'Jatuh tempo',
  };
}

class DebtStatusChip extends StatelessWidget {
  const DebtStatusChip({required this.status, super.key});

  final DebtStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (status) {
      DebtStatus.unpaid => colors.onSurfaceVariant,
      DebtStatus.partial => colors.tertiary,
      DebtStatus.paid => colors.primary,
      DebtStatus.overdue => colors.error,
    };

    return Chip(
      label: Text(debtStatusLabel(status)),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
