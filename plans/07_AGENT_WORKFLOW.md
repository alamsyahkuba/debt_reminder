# AI Agent Workflow & Rules

## Role
You are the implementation agent for the Debt Reminder Android project. Treat files in `plans/` as the approved specification.

## Before implementation
1. Read `plans/README.md`, `00_PROJECT_BRIEF.md`, `01_PRODUCT_REQUIREMENTS.md`, `02_ARCHITECTURE.md`, `03_DATABASE_AND_SECURITY.md`, `04_OFFLINE_SYNC.md`, `05_UI_UX_SPEC.md`, and `06_TESTING_AND_ACCEPTANCE.md`.
2. Read the target sprint file and previous sprint status.
3. Inspect the current repository; do not assume it is empty.
4. Report a concise plan, affected files, dependencies, and risks.
5. Do not begin a later sprint before dependencies are accepted.

## During implementation
- Work only within sprint scope.
- Prefer small, reviewable changes.
- Use clear naming and typed models.
- Add tests alongside implementation.
- Keep migrations backward-compatible where possible.
- Never hardcode secrets, PINs, tokens, or production data.
- Never place service-role credentials in Flutter.
- Do not bypass RLS or admin Edge Function verification.
- Do not expose private customer information in public endpoints.
- Never silently change product decisions.
- If requirement is ambiguous or security-impacting, stop and ask owner.
- Do not create subgroup support.
- Use Indonesian UI copy unless owner requests otherwise; code identifiers in English.
- Use consistent timezone/date handling and integer rupiah.
- Add TODO only with a tracked reason and sprint issue.

## After implementation
1. Run formatting, analyzer, and relevant tests.
2. Report commands and results truthfully.
3. Update sprint checklist.
4. Update `STATUS.md` with completed items, files changed, test evidence, and blockers.
5. Document new decisions in `DECISIONS.md` (create if needed).
6. Do not claim complete if tests were not run.

## Git discipline
- Do not force-push, rewrite history, or delete user work.
- Do not commit unless explicitly asked.
- Inspect `git status` before changes and before final report.
- Preserve unrelated modifications.

## Output format at end of sprint
- Summary
- Files created/modified
- Tests and commands run
- Acceptance criteria status
- Known limitations
- Recommended next sprint
