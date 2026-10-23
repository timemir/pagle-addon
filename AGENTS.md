## Agent skills

### Issue tracker

Issues live in GitHub Issues for `timemir/pagle-addon`, accessed via `wsl gh` with a token scoped to this repo only. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### In-game verification

Read in-game results (Lua errors, the Catch log, CVars, addon state) from the client's WTF files with `scripts/read-wtf.lua`, after the dev's `/reload` or logout. See `docs/agents/in-game-verification.md`.
