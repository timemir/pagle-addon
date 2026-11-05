## Agent skills

### Issue tracker

Issues live in GitHub Issues for `timemir/pagle-addon`, accessed via `wsl gh` with a token scoped to this repo only. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### In-game verification

Read in-game results (Lua errors, the Catch log, CVars, addon state) from the client's WTF files with `scripts/read-wtf.lua`, after the dev's `/reload` or logout. See `docs/agents/in-game-verification.md`.

### Hotfix path

One command from a committed fix to its tagged release and pagle-backend's pin-bump pull request: `scripts/hotfix.sh start <version>`, then `scripts/hotfix.sh ship <version> [--merge-bump]`. The fix and its changelog section go in one pull request; the script merges on green, tags the tested tree at once, waits for the Release, and starts the backend's pin bump. Its header has the steps.

### Launch runbook

The plan for the 1.0.0 tag on 4 Nov 2026, before Forever's live release, and 1.0.1, the live-data update after it: who does what when, what blocks the tag, how each failure gets applied, and the kit in `scripts/launch.py`. See `docs/agents/launch-runbook.md`.
