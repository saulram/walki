# Agent Operating Rules

## Completion Discipline

- Treat each task as incomplete until implementation, verification, and user-facing summary are done.
- Run relevant checks before closing (at minimum targeted tests; full suite for release/security changes).
- When CLI or MCP internals change, compile both `bin/walki.dart` and `bin/walki_mcp.dart`; analyzer excludes those internals.
- For security or breaking behavior changes, enforce semver bump and explicit changelog notes.
- Do not run critical release steps in parallel (commit, tag, publish, release creation).
- Verify release pointers after publishing: commit hash, tag target, remote push status, and publish confirmation.

## Post-Task Learning Update

- At the end of every completed task, update these operating rules and the local Walki rule if a new lesson emerged.
- Keep updates short, concrete, and action-oriented.
- Prefer guardrails that prevent recurrence over descriptive notes.

## Final Report Requirements

- Include: what changed, validation run, resulting commit/tag/version (if applicable), and any follow-up risk.
- If something could not be completed, state it explicitly with the blocker.
