# Core presents Announcements

Core, not each Module, draws every Announcement: Modules raise moments (a rung on a fixed ladder, display text, icon, optional sound, optional Cast reference and expiry) through the `Pagle` API, and Core merges them, applies the Interruption budget, combat hold and Cozy mode, and shows the toast, banner, splash and Session summary. This ends Core being headless, which a reader of ADR 0001 might not expect. It is the only way to honour "one Announcement per Cast": a Cast that earns a new Species (Ledger) and completes a Hunt (Hunts) can only become one toast with both stamps if a single renderer sees both moments. It is also the only way for one budget, one combat hold and one Session summary to cover every Module, and Core already owns the inputs the policy needs (restriction state, the Session rule).

ADR 0001 still holds. Modules raise moments to Core and never hear each other's; a moment is display data, not a fact another Module can reward from. Disabling one Module removes only its own moments and summary lines.

## Considered Options

- **Each Module announces on its own.** Rejected: separate budgets, toasts stacking on screen, no shared Session summary.
- **Core runs the policy, each Module draws.** Rejected: a Cast with moments from two Modules can't become one toast, and the look drifts between Modules.
- **A separate `Pagle_Announcements` Module.** Rejected: every other Module's moments would reach it through a Core relay, Module-to-Module traffic in all but name. Cozy mode already covers a player who wants quiet.

## Consequences

- Core ranks moments by a ladder it publishes (`nod`, `toast.low`, `toast`, `toast.high`, `banner`, `splash`), not by a list of every Module's moment kinds, so a Module adds kinds without a Core release.
- Modules must raise a Cast's moments synchronously inside their `Catch`/`CastEnded` handlers; Core flushes on the next frame.
- The Session summary's moments and Module summary lines are persisted by Core as ready-to-show data, outside the Catch log, so they survive logout and a Module disabled since.
- Toast style and sound set are Core settings and free choices. They can't be Ledger unlocks, because a Ledger reward would then change how another Module's Announcements look.

## Note: styles and sound sets are sold

[ADR 0009](0009-core-holds-the-pagle-coins-wallet.md) ([Design the Pagle currency and shop](https://github.com/timemir/pagle-addon/issues/28)) reverses "free choices": the default toast style and the Driftwood sound set stay free, and the rest are sold for Pagle Coins in Core's Curio Shop. They are still never Ledger unlocks.

## Note: where moments are raised

In the Core spec ([Write the Core spec](https://github.com/timemir/pagle-addon/issues/35)) a Module raises a Cast's moments mainly while its projection applies that Cast as a `"live"` entry; `Catch`/`CastEnded` handlers in the same frame work too. Core merges by the Cast's entry ID and, while any projection is still catching up, holds Cast moments until all are done, so one Cast still makes one Announcement.

## Note: a Cast's banner and toast are two Announcements

[Show a Cast's level-up banner and its catch toast as two Announcements](https://github.com/timemir/pagle-addon/issues/249) splits "one Announcement per Cast" by lane: a Cast's banners and splash make one Announcement, its toasts and nods another, and a banner and a toast can be on screen together (ANN-R11, ANN-R20). The decision stands: merging the toasts of a Cast that earns a new Species (Ledger) and completes a Hunt (Hunts) into one toast still needs one renderer, as does showing the two together with one sound.
