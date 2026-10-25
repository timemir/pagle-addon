# Modules only see Core

A Pagle Module never depends on another Module: no calls between Modules, no reading another Module's saved data, no optional dependencies between them, and no events one Module publishes for another. Any fact two Modules need, such as cast state or whether a Catch met a set of conditions, is observed, computed and published by Core. If Modules could feed each other, disabling one (say Hunts) would quietly cost the player something in another (say Ledger XP). That would force a choice through the back door, which Pagle's "no player choice is forced" rule forbids. It would also stop each Module being rebuildable from Core's Catch log alone.

## Considered Options

- **Soft events between Modules** (a Module publishes on Core's bus, others listen if installed). Rejected: it still makes one Module's rewards depend on another being enabled.
- **Optional dependencies between Modules.** Rejected for the same reason, plus load-order coupling.

## Consequences

- Concepts that more than one Module needs move into Core, even when only one Module shows them. The condition vocabulary, matching and next-window forecasting live in Core; only the list of Hunts and the board live in Hunts.
- A cross-Module reward (for example "a Hunt completion grants Ledger XP") cannot exist. Each Module rewards only from Core's data.
- Only Core observes the game's fishing, conditions and restriction state. Modules may use WoW APIs for their own presentation and actions.

## Note: Pagle Coins

[ADR 0009](0009-core-holds-the-pagle-coins-wallet.md) ([Design the Pagle currency and shop](https://github.com/timemir/pagle-addon/issues/28)) allows one cross-Module effect: a Module may pay Pagle Coins into Core's wallet, so disabling it slows what the player can buy in the Curio Shop. Income only ever adds, and the shop shows it by source, so nothing already earned is lost.

## Note: a Module may read live game state for its own actions

Decided while writing the QoL spec ([Write the QoL spec](https://github.com/timemir/pagle-addon/issues/37)): a Module may read live game state it needs for its own actions (QoL watches the player's channel ending, its pole, bags and lure to re-point the Fishing key), but never to record, count or derive anything. Everything recorded or derived still comes from Core.

## Note: this ADR is about clean dependencies, not about what Pagle may do

Clarified by the dev while redesigning Hunts (18 Oct): this ADR exists to keep the code clean, with every Module depending only on Core. It was never meant to rule out features. When a feature needs one Module's result to reach another, the answer is a Core contract that the source Module feeds and the other reads, never a call or event between Modules. Two such contracts follow:
- **XP income.** Like the Coins wallet (ADR 0009), a Module may report the XP it has earned to Core, and the Ledger adds it to the Angler Level. This replaces the line under Consequences that a cross-Module reward "cannot exist". What it costs to disable a Module stays visible, because income is shown by source.
- **Pushed content.** Pagle_Companion hands Core what the companion app delivered, such as Hunt Events, and Hunts reads those from Core. Neither Module knows the other exists.

## Note: Refreshes

[ADR 0017](0017-core-holds-the-refresh-purse-from-reported-totals.md) ([Hunt-earned refresh ticket for the Tackle Board](https://github.com/timemir/pagle-addon/issues/398)) adds a fourth Core contract that one Module feeds and another reads: Hunts reports the Refreshes it has earned, the Tackle Board the ones it has spent, and Core keeps the totals and the count held. Neither Module calls, reads or listens to the other.
