# AGENTS.md — Debt Reminder (OpenCode)

This file defines repository-wide instructions for OpenCode agents working on this project.
The approved product and technical specifications live in `plans/`. Read them before making changes.

## 1. Mandatory context

Before planning or coding, read these files when present:

1. `plans/README.md`
2. `plans/00_PROJECT_BRIEF.md`
3. `plans/01_PRODUCT_REQUIREMENTS.md`
4. `plans/02_ARCHITECTURE.md`
5. `plans/03_DATABASE_AND_SECURITY.md`
6. `plans/04_OFFLINE_SYNC.md`
7. `plans/05_UI_UX_SPEC.md`
8. `plans/06_TESTING_AND_ACCEPTANCE.md`
9. `plans/07_AGENT_WORKFLOW.md`
10. `plans/DECISIONS.md`
11. `plans/STATUS.md`
12. The active sprint file under `plans/sprints/`

If any required file is missing, do not invent its contents. Report the missing file and ask whether to regenerate it or proceed with an explicitly documented assumption.

## 2. Product decisions — do not change without approval

- Product: Android debt/reminder app built with Flutter and Supabase.
- There are exactly two roles: **owner/admin** and **public**.
- One owner and one admin in v1. The owner and admin may be the same person.
- Public users do not log in and do not have an account.
- Admin entry: Drawer → Admin → PIN.
- Cloud data is shared.
- App is offline-first using Drift/SQLite; admin CRUD remains offline-first with
  atomic outbox and server authorization at sync.
- Supabase PostgreSQL is the cloud source of truth.
- Hard delete is limited: group delete moves debts to Unassigned; debt hard
  delete only when it has no payments; payments are never deleted.
- Admin JSON backup/export is expected; restore-merge must not overwrite
  existing data or internal metadata.
- No app lock/local SQLite encryption and no PIN recovery UI in v1; document
  both limitations and the server-side PIN reset runbook.
- Business data is limited to **debt groups, debts, and payments**.
- There is **no customer entity, customer module, or `customer_id`**.
- A debt may identify a borrower only through its `title` and/or `notes`.
- Debt groups are simple: **Group → debts**. No nested groups/subgroups.
- All **business fields** are public: groups, debts, payments, notes, amounts,
  dates, archive state, and derived totals/status.
- Public read is read-only through explicit public RPCs.
- Public users cannot mutate data.
- Admin mutations are server-authorized and require a valid admin session.
- Read-only device enrollment and `read_devices` are removed.
- Payments are append-only and must not be silently edited or deleted.
- Never ship Supabase `service_role` credentials in Flutter or any client artifact.
- Database reset is approved because the app is pre-release.

### Current implementation note

Sprint 01R–08 are complete and Sprint 09 implementation is largely complete:
the cloud schema, local Drift schema, repositories, UI, and tests no longer
contain customers or device enrollment. Debt management, derived status,
append-only payments, overpayment rejection, the dashboard, server-verified
admin PIN/session, public pull, idempotent outbox sync, local due-date
reminders, conflict resolution, sync status, limited hard delete, full-pull
deletion reconciliation, and admin JSON backup/export with safe restore-merge
are implemented. Branding, package identity, and release signing are configured.
Sprint 09 QA/release verification is complete. Cloud migrations and Edge
Functions are deployed, the first PIN is bootstrapped, and a signed release APK
is built. All planned physical-device tests passed owner testing on I2505. AAB
and Play Console are not part of the v1 distribution scope; distribute the APK
directly. Sprint 10 GitHub release automation is implemented; its dry run and
the first automated `v1.0.0` release succeeded, but that release predates the
`latest.json` asset and contains only APK plus `.sha256`. Sprint 11 in-app update
is complete: `v1.0.1+2` and `v1.0.2+3` include APK, `.sha256`, and `latest.json`,
and the owner reports the full update flow passed on I2505. The app now
auto-checks on open/resume and shows a dashboard update banner. Sprint 12 bulk
insert hutang is implemented locally with an installment generator (base name,
count, nominal per installment -> `Nama 1..N`), max 50 installments, one group
per batch, one atomic `debt_batch` server RPC, and Flutter/Deno/pgTAP
tests passing; migration and Edge Function are deployed, physical-device
verification is pending.

If a task conflicts with these decisions, stop and ask the project owner. Do not
silently reinterpret the product.

## 3. OpenCode operating procedure

### Starting a task

1. Inspect the repository and `git status`; preserve existing user changes.
2. Read the mandatory context and the active sprint.
3. Identify the sprint goal, prerequisites, acceptance criteria, and out-of-scope items.
4. Determine whether the task is a planned rework or new feature work.
5. Summarize the intended implementation, affected files, risks, and tests before substantial changes.
6. If the task is ambiguous, security-sensitive, or changes product scope, ask for clarification before coding.

### Sprint discipline

- Work on **one sprint at a time**.
- Do not start a later sprint until its dependencies are complete and the owner approves progression.
- Do not implement unrelated features opportunistically.
- Keep changes small and reviewable.
- When a sprint is requested, use its checklist as the task boundary.
- If the owner explicitly asks for multiple sprints, state the expanded scope and execute in dependency order.
- Do not add customer features or device enrollment “for compatibility”; they are out of scope.

### After a task or sprint

1. Format changed Dart files.
2. Run relevant tests.
3. Run `flutter analyze` when Flutter code changes.
4. Run Supabase migration/function tests when backend changes and local tooling is available.
5. Report commands actually executed and their real results; never claim tests passed if they were not run.
6. Update the active sprint checklist.
7. Update `plans/STATUS.md` with:
   - completed work,
   - files changed,
   - test evidence,
   - blockers,
   - known limitations,
   - next recommended sprint.
8. Update planning documents if an approved decision changes.
9. If a new technical decision is needed, create/update `plans/DECISIONS.md` with context, options, decision, and consequences. Ask owner approval for product/security-impacting decisions.

## 4. Flutter implementation rules

- Use the architecture in `plans/02_ARCHITECTURE.md`.
- Keep UI, application/use-case, domain, and data layers separated.
- Widgets must not access Supabase directly.
- Use Riverpod for dependency/state management as specified.
- Use GoRouter for navigation as specified.
- Use Drift/SQLite for local persistence and reactive reads.
- Repository contracts belong in domain; implementations belong in data.
- Keep domain entities independent of Flutter, Drift, and Supabase models.
- Use typed models, clear names, and small functions.
- Avoid unnecessary abstractions and premature optimization.
- Use Indonesian user-facing copy unless the owner requests another language.
- Format Rupiah as Indonesian currency; store amounts as integer rupiah (`BIGINT`/integer), never floating-point money.
- Handle dates/timezones consistently; store timestamps in UTC where appropriate and render in local timezone.
- Include loading, empty, error, offline, and pending-sync states.
- Add tests for business logic and critical user flows.
- Public mode must never expose mutation controls or create outbox entries.
- Admin mutation controls must be gated in Sprint 06; local UI guards are not server authorization.
- Do not create a `features/customers` module.

## 5. Database and Supabase security rules

- Follow `plans/03_DATABASE_AND_SECURITY.md`.
- Enable RLS on every exposed table.
- Policies must be explicit and least-privilege.
- Public access is allowed only through explicit read-only RPCs.
- Anon must have no direct SELECT on base business tables.
- Anonymous role must never mutate business data.
- Do not expose `admin_settings`, `admin_sessions`, `audit_logs`,
  `operation_registry`, PIN hashes, tokens, or sync metadata through public endpoints.
- Do not expose or recreate a customer table; there is no customer data.
- Do not recreate `read_devices` or device enrollment.
- Admin writes must pass through Edge Functions or another approved server-side boundary.
- Every admin mutation must verify a valid server-issued admin session/token.
- Never trust a client flag, local PIN unlock, or UI route guard as server authorization.
- Validate all input server-side: amounts, IDs, relationships, dates, versions, operation IDs, and allowed fields.
- Apply rate limits to PIN verification and avoid revealing sensitive verification details.
- Keep service-role secrets in Supabase server secrets only.
- Do not log PINs, tokens, secret keys, or unnecessary personal/financial data.
- Payments must be idempotent and append-only.
- Use optimistic concurrency/version checks for mutable records.
- Preserve auditability for sensitive/admin actions.
- Public RPCs must not return internal `version`, `operation_id`, sync metadata, or admin/audit/session fields.

## 6. Offline-first and sync rules

- All feature reads come from Drift/SQLite.
- Admin local mutations must update the entity and enqueue its outbox operation in the **same SQLite transaction**.
- Public pull is read-only and must not create outbox entries.
- Do not send remote requests directly from screens/forms.
- Keep a stable `operation_id` across retries.
- Never generate a new idempotency key merely because a request failed.
- Sync must respect entity dependencies: **group → debt → payment**. There is no customer dependency.
- Use retry/backoff for transient failures; do not endlessly retry validation/auth errors.
- Do not discard pending operations after network or authorization failure.
- A stale version must produce a conflict, not silent last-write-wins.
- Do not overwrite unsynced local changes during pull.
- Use tombstones/archive markers where needed; avoid hard deletion of financial history.
- Connectivity status is only a hint; the actual request determines network availability.
- WorkManager is best-effort. Provide foreground/manual sync too.
- Show pending, syncing, conflict, failed, and offline states to users.

## 7. Group and debt rules

- Groups are flat; never add `parent_id`, subgroup navigation, or recursive group UI unless approved.
- A debt may have one group or be Unassigned (`group_id = null`).
- Group archive preserves its debts and history.
- Group deletion must follow the approved policy: move debts to Unassigned, never delete debts in the group.
- Hard delete a debt only when it has no payments; debt with payments must be archived.
- Payments are never hard-deleted.
- Moving a debt between groups must be auditable/syncable.
- Group totals must be derived from underlying debts/payments, not manually maintained counters unless a verified cache is used.
- Debt status and outstanding amount must be derived consistently from principal, payments, and due date.
- Do not allow invalid/negative amounts.
- Default policy rejects overpayment unless the owner explicitly changes it.
- A debt has no customer relation; use title/notes for borrower identity.

## 8. Admin session and device policy

- Online PIN verification is performed by a server endpoint.
- Store session/token securely on device and enforce expiry.
- Lock/logout must clear local session material.
- Offline unlock is only a local convenience for editing cached data; it does not authorize cloud mutations. v1 does not implement offline local-only unlock; a valid server session is required before local edits are queued.
- When syncing admin operations, server authorization is mandatory.
- If the admin session expires, preserve the outbox and request re-authentication; never discard local work.
- Do not add read-only device enrollment, device tokens, or `read_devices`; public read does not require enrollment.

## 9. Notifications

- Use local notifications for v1 reminders.
- Reconcile schedules at app startup.
- Reschedule when due date or relevant debt state changes.
- Cancel reminders when debt is paid or archived.
- Handle Android notification and exact-alarm permissions gracefully.
- Never imply that a notification proves a payment occurred.
- Reminder configuration is device-local and available to public users; it must
  not mutate business data or create outbox entries.

## 10. Testing and quality gates

For relevant changes, use these commands as applicable:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

For Supabase changes, use the repository's configured Supabase CLI/test commands. If no test setup exists, document the gap and add appropriate tests where practical.

Minimum expectations:
- Unit tests for calculations, validation, status derivation, and conflict logic.
- Repository tests for local transaction/outbox behavior and public pull.
- Idempotency tests for payments/sync.
- RLS tests for anon public-RPC read, base-table denial, and mutation denial.
- Edge Function tests for missing/invalid/expired admin session.
- Integration tests for offline → reconnect → sync → restart and public pull.
- Widget tests for critical forms, public read-only mode, and navigation.
- Reset/migration tests proving customers/read_devices are absent.

Do not weaken tests or security policies just to make a build pass. Explain failures and propose a fix.

## 11. Git and file safety

- Never force-push, rewrite history, or reset user work.
- Never delete unrelated files or user changes.
- Inspect `git status` before and after modifications.
- Do not commit unless explicitly requested.
- Do not overwrite planning files without checking their current contents.
- Keep generated files and secrets out of version control as appropriate.
- Do not create fake credentials or production data.
- Database reset is allowed only because the app is pre-release; confirm before deleting any real data.

## 12. Response format

At the end of each task, provide:

### Summary
What changed and why.

### Files
List created/modified files.

### Validation
Commands run and their actual results.

### Acceptance criteria
Completed / incomplete, with evidence.

### Risks or blockers
Security, migration, sync, or product decisions still pending.

### Next step
The next smallest useful task or sprint.

Be concise but specific. Do not hide incomplete work.

## 13. First-run and rework instruction

If the repository is empty or only contains planning files:

1. Read all planning files.
2. Check whether `plans/STATUS.md` still marks Sprint 00 as incomplete.
3. Propose Sprint 00 implementation.
4. Wait for owner approval unless the owner explicitly requested autonomous execution.
5. Implement Sprint 00 only.

If the repository contains customer/`read_devices`/device-enrollment artifacts:

1. Do not continue to Sprint 04+ yet.
2. Read the revised plan and `plans/STATUS.md`.
3. Propose/perform the planned rework: remove customers and device enrollment,
   reset schemas, add public read-only RPCs, and update local repositories/UI/tests.
4. Do not claim a sprint complete until the revised acceptance tests pass.

If the rework is complete (no customer/device artifacts; revised tests pass),
proceed with Sprint 04 only after owner approval.
