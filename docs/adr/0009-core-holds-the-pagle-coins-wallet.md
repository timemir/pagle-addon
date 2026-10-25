# Core holds the Pagle Coins wallet and the Curio Shop

Amends ADR 0001 and ADR 0007.

Pagle has one currency, **Pagle Coins**, and one shop, the **Curio Shop**, and both belong to Core. Modules pay in by reporting the lifetime Coins their own projection has earned (the Tackle Board for Notices, Expeditions and Campfire milestones; the Ledger for discoveries, ranks, levels, Prestiges and Legends; Hunts for completions, tiers and sets). Core keeps the last total each Module reported in `PagleDB`, records every purchase as its own Catch log entry (`U1|good|price|serverTime`), and shows the balance as earned minus spent. Modules register the goods for their own views; Core registers its own (toast styles, sound sets, bookplate crests). Modules ask Core what is owned and equipped.

The dev's vision was one currency that many things pay into and that buys addon cosmetics. That can't sit in a Module without Module-to-Module traffic, and it can't sit in Core without amending ADR 0001: with a shared wallet, disabling the Tackle Board slows what the player can buy in the Journal. We accept that, because the harm ADR 0001 guards against is a *hidden* loss, and this one is neither hidden nor a loss. Income only ever adds, the shop shows income by source, and disabling a Module stops only its future income.

## Considered Options

- **Core pays from the Catch log alone, Modules pay nothing.** Keeps ADR 0001 whole, but reverses the Tackle Board's payouts and misses the "many things pay in" vision.
- **One purse and shop per Module.** Keeps ADR 0001 whole, but there is no shared currency at all.
- **A Core trickle per Catch on top of Module income.** Rejected: Coins reward achieving something, never raw volume, and a Core-and-QoL player has few views to dress up.
- **A separate `Pagle_Shop` Module.** Rejected for the reason ADR 0007 rejected a separate Announcements Module: every payment would be Module-to-Module traffic through a Core relay.

## Consequences

- ADR 0001 allowed one cross-Module effect here: Coins paid into Core's wallet. Later ADRs added more (Activity XP in ADR 0011, pushed content in ADR 0013, Refreshes in [ADR 0017](0017-core-holds-the-refresh-purse-from-reported-totals.md), which lists all four). Modules still never see each other, and a Module's reward is still never another Module's call.
- ADR 0007's "toast style and sound set are free choices" no longer holds: the defaults (and the Driftwood sound set) stay free, the rest are sold in the Curio Shop. Its reasoning still stands, because the purchase is Core's, not a Module's reward.
- A purchase stores its price, so a later price change never moves a balance. Purchases are never revoked. If a rebuild or rebalance pushes earned below spent, the balance shows 0 and new income fills the gap before it moves again; there is never a negative balance or a "debt".
- A disabled Module's goods leave the shop, but goods already bought stay owned. If `PagleDB` is lost, a disabled Module's earned total is lost with it until the Module is enabled again and rebuilds.
- Coins and purchases are client-written. A future backend that needs to trust them must validate them on the server.

## Note: the Core spec

The wallet and shop are specified in `docs/spec/core/wallet-and-shop.md` ([Write the Core spec](https://github.com/timemir/pagle-addon/issues/35)). A purchase entry carries the shared entry header, `U1|<char>|<time>|<tie>|<good>|<price>` (layout in `docs/spec/core/catch-log.md`). "Income only ever adds" means disabling a Module never lowers what it paid; a rebalance or data fix can still recount a Module's total lower, which the balance-held-at-0 rule above already covers.
