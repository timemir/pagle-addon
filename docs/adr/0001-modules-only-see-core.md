# Modules only see Core

A Pagle Module never depends on another Module: no calls between Modules, no reading another Module's saved data, no optional dependencies between them, and no events one Module publishes for another. Any fact two Modules need, such as cast state or whether a Catch met a set of conditions, is observed, computed and published by Core. If Modules could feed each other, disabling one (say Hunts) would quietly cost the player something in another (say Ledger XP). That would force a choice through the back door, which Pagle's "no player choice is forced" rule forbids. It would also stop each Module being rebuildable from Core's Catch log alone.

## Considered Options

- **Soft events between Modules** (a Module publishes on Core's bus, others listen if installed). Rejected: it still makes one Module's rewards depend on another being enabled.
- **Optional dependencies between Modules.** Rejected for the same reason, plus load-order coupling.

## Consequences

- Concepts that more than one Module needs move into Core, even when only one Module shows them. The condition vocabulary, matching and next-window forecasting live in Core; only the list of Hunts and the board live in Hunts.
- A cross-Module reward (for example "a Hunt completion grants Ledger XP") cannot exist. Each Module rewards only from Core's data.
- Only Core observes the game's fishing, conditions and restriction state. Modules may use WoW APIs for their own presentation and actions.
