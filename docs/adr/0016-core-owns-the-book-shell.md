# Core owns the book shell

Builds on ADR 0015.

The Fish Journal, the Stats book, the Hunts board and the Field guide are one kind of window: two parchment pages in a binding, with a gilt strip of crumbs, a wax close button, a brass nameplate, ribbons, a page router and a page turn. Each was a fork of the books kit's shell, about 3,400 lines in four copies that had started to drift. Since Modules never see each other (ADR 0001), the one shell that all four can share has to be Core's. So Core gives a public book API, built from the Stats book's shell. Each book keeps only its own pages, its leather anchors (search, clock, live line) and its own effects (the Hunts board's fold, the Stats book's ink reveal). We built it before 1.0, while the `Pagle` API can still change freely (CORE-R15). After 1.0 it would only be additive.

## Considered Options

- **Keep four shells until after 1.0.** Rejected: the copies were already drifting in ribbon size, button placement and fade code, and after 1.0 a shared API could only be added beside them.
- **Share only the visuals and keep each book's router, turn and window behaviour.** Rejected: the router and page turn are where most of the copied lines sit.

## Consequences

- The small drift is unified: one ribbon size, one place for the "?" button, one fade and sound path. The real differences stay as shell options: the Hunts board's unequal pages, the Stats book's foot band, and the Field guide's dim and fixed place.
- Every movable book now remembers where the Angler left it. That replaces the Journal's and the Hunts board's re-centring at each opening.
