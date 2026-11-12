# Sprint 09 — QA, Hardening & Release

## Goal
Prepare a stable Android release candidate for the revised public-read product.

## Tasks
- [ ] Run all unit/widget/integration tests.
- [ ] Run Flutter analyze and formatting.
- [ ] Review public RPCs, RLS, and Edge Function security.
- [ ] Verify anon can read all approved business data but cannot mutate.
- [ ] Verify internal tables/RPCs are inaccessible to anon.
- [ ] Verify no customer table/entity/UI remains.
- [ ] Verify no read_devices/device enrollment remains.
- [ ] Verify no secrets in repo/build artifacts.
- [ ] Test fresh install and database reset.
- [ ] Test offline/online transitions and public pull.
- [ ] Test Android notification permissions/background behavior.
- [ ] Add app icon, splash, package name, version.
- [ ] Configure release signing outside repo.
- [ ] Add backup/export strategy if approved.
- [ ] Document known limitations and release checklist.

## Acceptance criteria
- Critical tests pass.
- No known critical security issue.
- Release build succeeds.
- Fresh install and reset paths tested.
- Public read and anon mutation denial verified.
- No customer or device-enrollment artifacts remain.
- Owner signs off on public data visibility, PIN recovery, and backup policy.
