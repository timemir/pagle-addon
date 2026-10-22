# Core owns the binding every book wears

Amends ADR 0009.

The Fish Journal, the Hunts board and the Stats book are the Angler's books, and they wear one **binding**, chosen once in the Curio Shop. Before this, the Ledger sold Journal bindings and Hunts sold notebook covers: two slots, two catalogues and two forks of the same leather renderer, for what the Angler sees as one book. Since Modules never see each other (ADR 0001), a look that more than one Module's book wears has to be Core's. So Core registers the binding slot, its default (Field Leather) and every binding for sale, ships all binding art, and gives every book one renderer that draws the equipped binding. Modules add only **earned** bindings to Core's slot, as they already do with crests and sound sets (SHOP-R23), and decide only when those are earned.

## Considered Options

- **Keep the two slots.** Rejected: a different look on each book is the inconsistency this decision removes.
- **Relax SHOP-R23 so Modules can sell goods in Core's slots.** Rejected: a binding bought from Hunts would leave the shop whenever Hunts is off (SHOP-R35), and the art and renderers would stay split across addons.
- **Core exposes only the look's data, and each book draws it.** Rejected: three drawing forks are how the Journal and the Hunts board drifted apart.

## Consequences

- Core's shop sells looks for Module views it doesn't draw itself. Core already draws a Module's earned toast style; now it also draws the leather round a Module's window.
- A bought binding is owned and wearable while any book is on screen, whichever Modules are enabled.
- An earned binding follows SHOP-R32 unchanged: while its Module is off, every book falls back to Field Leather, and the choice comes back with the Module.
- The Field guide uses the same renderer, pinned to Field Leather, because it is read before the Angler owns anything.
