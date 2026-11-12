import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../domain/entities/debt.dart';

class DebtListTile extends StatelessWidget {
  const DebtListTile({
    required this.debt,
    this.groupName,
    this.onTap,
    this.onMoveGroup,
    super.key,
  });

  final Debt debt;
  final String? groupName;
  final VoidCallback? onTap;
  final VoidCallback? onMoveGroup;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (groupName != null && groupName!.isNotEmpty) groupName!,
      if (debt.isArchived) 'Diarsipkan',
      debt.dueDate == null
          ? 'Tanpa jatuh tempo'
          : 'Jatuh tempo ${formatDate(debt.dueDate!)}',
      'Pokok ${formatRupiah(debt.principalAmount)}',
    ].join(' • ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(
            Icons.receipt_long_outlined,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(debt.title),
        subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: onMoveGroup == null
            ? null
            : PopupMenuButton<String>(
                key: Key('debt-actions-${debt.id}'),
                tooltip: 'Aksi hutang',
                onSelected: (value) {
                  if (value == 'move') {
                    onMoveGroup!();
                  }
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'move',
                    child: Text('Pindah group'),
                  ),
                ],
              ),
      ),
    );
  }
}
