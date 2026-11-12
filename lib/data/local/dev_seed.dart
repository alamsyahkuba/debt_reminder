import 'app_database.dart';

/// Inserts local-only demo data when enabled with `SEED_DEMO_DATA=true`.
///
/// Demo rows are marked `synced` and never enqueue outbox operations, so this
/// data must only be used in a development database. Never enable it before
/// connecting the app to a real cloud project.
Future<bool> seedDevelopmentData(AppDatabase db, {DateTime? now}) async {
  final existingCustomers = await db.select(db.customers).get();
  final existingGroups = await db.select(db.debtGroups).get();
  final existingDebts = await db.select(db.debts).get();
  final existingPayments = await db.select(db.payments).get();

  if (existingCustomers.isNotEmpty ||
      existingGroups.isNotEmpty ||
      existingDebts.isNotEmpty ||
      existingPayments.isNotEmpty) {
    return false;
  }

  final seededAt = (now ?? DateTime.now()).toUtc();
  final dueDate = DateTime.utc(
    seededAt.year,
    seededAt.month,
    seededAt.day,
  ).add(const Duration(days: 3));
  final laterDueDate = dueDate.add(const Duration(days: 11));

  await db.transaction(() async {
    await db
        .into(db.customers)
        .insert(
          CustomerRow(
            id: '10000000-0000-4000-8000-000000000001',
            name: 'Pelanggan Demo',
            phone: '0812-0000-0000',
            notes: 'Data demo lokal, bukan data pelanggan nyata.',
            isArchived: false,
            createdAt: seededAt,
            updatedAt: seededAt,
            version: 1,
            syncState: 'synced',
            serverUpdatedAt: seededAt,
          ),
        );

    await db
        .into(db.debtGroups)
        .insert(
          DebtGroupRow(
            id: '20000000-0000-4000-8000-000000000001',
            name: 'Keluarga Demo',
            description: 'Group contoh untuk development.',
            color: '#00695C',
            icon: 'family',
            sortOrder: 0,
            isArchived: false,
            createdAt: seededAt,
            updatedAt: seededAt,
            version: 1,
            syncState: 'synced',
            serverUpdatedAt: seededAt,
          ),
        );
    await db
        .into(db.debtGroups)
        .insert(
          DebtGroupRow(
            id: '20000000-0000-4000-8000-000000000002',
            name: 'Usaha Demo',
            description: 'Group contoh untuk development.',
            color: '#5D4037',
            icon: 'work',
            sortOrder: 1,
            isArchived: false,
            createdAt: seededAt,
            updatedAt: seededAt,
            version: 1,
            syncState: 'synced',
            serverUpdatedAt: seededAt,
          ),
        );

    await db
        .into(db.debts)
        .insert(
          DebtRow(
            id: '30000000-0000-4000-8000-000000000001',
            customerId: '10000000-0000-4000-8000-000000000001',
            groupId: '20000000-0000-4000-8000-000000000001',
            title: 'Hutang Demo Sembako',
            principalAmount: 500000,
            dueDate: dueDate,
            notes: 'Contoh hutang untuk development.',
            isArchived: false,
            createdAt: seededAt,
            updatedAt: seededAt,
            version: 1,
            syncState: 'synced',
            serverUpdatedAt: seededAt,
          ),
        );
    await db
        .into(db.debts)
        .insert(
          DebtRow(
            id: '30000000-0000-4000-8000-000000000002',
            customerId: '10000000-0000-4000-8000-000000000001',
            groupId: '20000000-0000-4000-8000-000000000002',
            title: 'Hutang Demo Modal',
            principalAmount: 1500000,
            dueDate: laterDueDate,
            notes: 'Contoh hutang untuk development.',
            isArchived: false,
            createdAt: seededAt,
            updatedAt: seededAt,
            version: 1,
            syncState: 'synced',
            serverUpdatedAt: seededAt,
          ),
        );

    await db
        .into(db.payments)
        .insert(
          PaymentRow(
            id: '40000000-0000-4000-8000-000000000001',
            debtId: '30000000-0000-4000-8000-000000000001',
            amount: 150000,
            paidAt: seededAt,
            notes: 'Contoh pembayaran untuk development.',
            operationId: '90000000-0000-4000-8000-000000000001',
            createdAt: seededAt,
            syncState: 'synced',
            serverUpdatedAt: seededAt,
          ),
        );
  });

  return true;
}
