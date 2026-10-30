# Shipped Hunt definitions are immutable

A Hunt is pure data (ID, `since` date, target, conditions, natural or imposed, tiers, set, notes), and once it ships it is never edited. A fix ships as a new Hunt with a new ID, and the old one becomes a **Retired Hunt**: off the board, completions kept. Hunts state is a stored projection that gets rebuilt from the Catch log when the content-data or rules version changes (ADR 0004). If a rule could change, a rebuild would re-judge old Casts and could revoke a completion the player has already celebrated. With immutable definitions, a rebuild gives the same answer every time.

Two companion rules keep that true:
- **Classes a shipped Hunt targets (e.g. "rare or better", a fixed set of fish) can only gain members.** A removal needs a new Hunt.
- **A Hunt only counts Casts at or after its shipped `since` date.** There is no retroactive credit for Hunts added in later updates. Casts made while the Hunts Module was disabled still count, because Core logged them.

Natural Hunts complete on the Catch alone, so correcting content-data windows (e.g. learning Forever's real Nightfin cycle) never touches completions and needs no new ID. Imposed Hunts define their own fixed windows in the definition for the same reason.

## Considered Options

- **Editable definitions with a sticky completion record that survives rebuilds.** Rejected: it's a second source of truth beside the Catch log, which ADR 0004 avoids.
- **Editable definitions, accepting revocation.** Rejected: a celebrated completion disappearing breaks "observe and reward".

## Consequences

- Hunt definitions being data, not code, also lets a future backend push new Hunts without an addon update. That backend is out of scope for now.
- Retired Hunts stay in the shipped data forever, with a `retired` date.
- A set title is earned at the first moment every Hunt in that set that existed then (shipped, not yet retired) was complete. The replay can work this out from the dates alone, so a Hunt added to the set later never takes the title away.

## Note: "shipped" means released at 1.0 or later

Pagle published nothing before 1.0 ([Cut the MVP slice and roadmap](https://github.com/timemir/pagle-addon/issues/18)), so Hunt definitions changed freely until then and there were no Retired Hunts in the first release. Every v1 Hunt has `since` set to the 1.0 release date, 2026-11-05.

## Note: Hunt Events (18 Oct)

[ADR 0012](0012-hunt-events-are-dateless-definitions-scheduled-as-runs.md) makes this ADR's "a future backend may push new Hunts" concrete. A Hunt Event's definition, shipped in the pool or pushed by the backend, falls under this ADR as soon as it has shipped or been pushed:
- its zones, Hunts, targets and tiers never change;
- its Hunts' hashes go into `released.lock`;
- a fix is a new event ID.

Its runs are immutable once they start, and a run past its end has **ended**, not **retired**: it leaves the board with nothing kept.
