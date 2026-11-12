# Architecture

## 1. Overview

Flutter Android
→ Presentation (screens/widgets)
→ Application (Riverpod providers/use cases)
→ Domain (entities/repository contracts)
→ Data (repository implementations)
→ Local Drift/SQLite + Outbox
→ Sync service
→ Supabase Edge Functions
→ PostgreSQL

UI tidak boleh memanggil Supabase langsung untuk CRUD bisnis. UI menggunakan repository/use case.

## 2. Stack

- Flutter stable; pin SDK constraint dan dependency versions di `pubspec.yaml`.
- Riverpod untuk dependency injection/state.
- GoRouter untuk navigation.
- Drift + SQLite untuk local database.
- `supabase_flutter` untuk Supabase client.
- `flutter_local_notifications` + timezone package untuk reminder.
- `flutter_secure_storage` untuk local admin session/token.
- `connectivity_plus` hanya sebagai sinyal konektivitas; hasilnya bukan bukti internet benar-benar tersedia.
- WorkManager untuk best-effort background sync; foreground sync juga wajib.

## 3. Suggested folder structure

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    config/
    errors/
    logging/
    network/
    security/
    utils/
  data/
    local/
      app_database.dart
      tables/
      daos/
    remote/
      supabase_client.dart
      edge_function_client.dart
    repositories/
    sync/
      sync_service.dart
      sync_queue.dart
      sync_worker.dart
      conflict_resolver.dart
  domain/
    entities/
    repositories/
    usecases/
  features/
    dashboard/
    debt_groups/
    customers/
    debts/
    payments/
    reminders/
    admin/
    settings/
  shared/
    widgets/
    extensions/
```

## 4. Repository rules

- Repository adalah satu-satunya entry point data untuk feature.
- Read stream/query berasal dari Drift.
- Write lokal harus atomik: update local entity + insert outbox dalam transaksi SQLite yang sama.
- Remote writes melalui Edge Functions.
- Setelah remote success, update sync metadata/local record.
- Tidak boleh ada network request langsung dari widget.
- Domain entities tidak bergantung pada Drift/Supabase model.

## 5. State

- Riverpod providers expose local streams.
- UI state (form, filter, selected tab) dipisah dari persisted data.
- Sync status global: offline, syncing, synced, pending, error.
- Admin session state: locked, unlocked, expired.

## 6. Error handling

Gunakan typed/domain errors untuk:
- validation
- offline
- unauthorized/expired admin session
- conflict
- duplicate operation
- remote unavailable
- local database failure

UI menampilkan pesan ramah; log tidak boleh memuat PIN, token, atau data hutang sensitif.

## 7. Configuration

- Supabase URL dan anon/publishable key boleh berada di client; tetap bukan secret.
- Service role key hanya di Supabase server/secret.
- Environment config dipisah dev/prod.
- Jangan commit `.env` yang berisi secret.
