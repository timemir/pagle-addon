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

One command from a committed fix to its tagged release and pagle-backend's pin bump: `scripts/hotfix.sh start <version>`, then `scripts/hotfix.sh ship <version>`. The fix and its changelog section go in one pull request; the script merges on green, tags the tested tree at once and waits for the Release. pagle-backend's CI runs locally while its Actions minutes are off, so the script then runs the backend's `ci/local-pin-bump.sh` when `HOTFIX_BACKEND_DIR` names a pagle-backend checkout, or prints the commands for the Operator, and stops with the add-on released. Its header has the steps.

### Launch runbook

The plan for the 1.0.0 tag on 4 Nov 2026, before Forever's live release, and 1.0.1, the live-data update after it: who does what when, what blocks the tag, how each failure gets applied, and the kit in `scripts/launch.py`. See `docs/agents/launch-runbook.md`.

### Layout harness

`scripts/measure-layout.sh <enUS|deDE|esES|ruRU|all> [module]` runs `/pagle dev tour` with every font string measured in its real bundled face, and reports text that's cut, off its page or overlapping beyond `scripts/measure-layout/allowlist.toml`, with PNGs in `build/measure-layout/`. It's a dev tool: the tour isn't in CI, but its advance table's freshness check is (`scripts/tests/test_layout.py`), and `GATE_LAYOUT=1 scripts/check.sh` adds the tour to the gate. See `docs/agents/layout-harness.md`.
