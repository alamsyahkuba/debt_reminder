# Architecture

## 1. Overview

Flutter Android
→ Presentation (screens/widgets)
→ Application (Riverpod providers/use cases)
→ Domain (entities/repository contracts)
→ Data (repository implementations)
→ Local Drift/SQLite + Outbox
→ Admin sync service
→ Supabase Edge Functions (admin mutation)
→ PostgreSQL

Public read path:

Publik
→ anon/publishable Supabase client
→ RPC public read-only
→ PostgreSQL

UI tidak boleh memanggil Supabase langsung untuk CRUD bisnis. UI menggunakan
repository/use case. Public read juga harus melalui repository/use case, bukan
query langsung dari widget.

## 2. Stack

- Flutter stable; pin SDK constraint dan dependency versions di `pubspec.yaml`.
- Riverpod untuk dependency injection/state.
- GoRouter untuk navigation.
- Drift + SQLite untuk local database.
- `supabase_flutter` untuk Supabase client.
- `flutter_local_notifications` + timezone package untuk reminder.
- `flutter_secure_storage` untuk local admin session/token.
- `connectivity_plus` hanya sebagai sinyal konektivitas; hasilnya bukan bukti
  internet benar-benar tersedia.
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
      public_read_client.dart
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
    debts/
    payments/
    reminders/
    admin/
    settings/
  shared/
    widgets/
    extensions/
```

Tidak ada folder `features/customers`.

## 4. Repository rules

- Repository adalah satu-satunya entry point data untuk feature.
- Read stream/query berasal dari Drift.
- Public pull menggunakan RPC read-only dan hasilnya disimpan ke Drift.
- Write lokal harus atomik: update local entity + insert outbox dalam transaksi
  SQLite yang sama.
- Remote admin writes melalui Edge Functions.
- Setelah remote success, update sync metadata/local record.
- Tidak boleh ada network request langsung dari widget.
- Domain entities tidak bergantung pada Drift/Supabase model.
- Public repository/use case tidak boleh menulis atau membuat outbox.

## 5. State

- Riverpod providers expose local streams.
- UI state (form, filter, selected tab) dipisah dari persisted data.
- Sync status global: offline, syncing, synced, pending, error.
- Admin session state: locked, unlocked, expired.
- Public mode selalu read-only.
- Admin mode membuka aksi mutasi setelah PIN berhasil.

## 6. Error handling

Gunakan typed/domain errors untuk:
- validation
- offline
- unauthorized/expired admin session
- conflict
- duplicate operation
- remote unavailable
- local database failure
- public read failure

UI menampilkan pesan ramah; log tidak boleh memuat PIN, token, atau data admin
internal.

## 7. Configuration

- Supabase URL dan anon/publishable key boleh berada di client; tetap bukan
  secret.
- Service role key hanya di Supabase server/secret.
- Environment config dipisah dev/prod.
- Jangan commit `.env` yang berisi secret.

## 8. Public read architecture

- Public client menggunakan anon/publishable key.
- Public read hanya lewat RPC/view read-only yang diekspos eksplisit.
- Base table tidak memberikan grant SELECT langsung ke anon.
- RPC publik mengembalikan field bisnis yang disetujui owner.
- Tidak ada public INSERT/UPDATE/DELETE.
- Admin mutation tetap melalui Edge Function dengan sesi admin.
