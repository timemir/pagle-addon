# Pagle product spec

> Status: Done · Sources: [Map: Forever fishing addon - product spec](https://github.com/timemir/wow-fish/issues/1), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652), [Define the Core/Module contract](https://github.com/timemir/wow-fish/issues/9#issuecomment-6112445901), [How do DBM-style multi-addon packages wire Core and Modules?](https://github.com/timemir/wow-fish/issues/3#issuecomment-6109740635), [Cut the MVP slice and roadmap](https://github.com/timemir/wow-fish/issues/18#issuecomment-6113973068), [Write the spec index](https://github.com/timemir/wow-fish/issues/45); ADR 0001–0010

**Pagle** is a fishing addon for World of Warcraft: Forever (Blizzard's Classic+ branch on the Retail client: interface 16001, `WOW_PROJECT_ID` 18, Camelot; Classic-style fishing with one 1–300 skill). It aims to be the only fishing addon a player needs. It observes and rewards, never plays for the player, and every reward is display-only.

This directory is Pagle's product spec. It describes the current state only, and it is written for build agents who split one section at a time into build tickets, with the dev as reviewer. This file is the way in: the index, how the pieces fit, which Module does what, and how to read the rest.

## Index

| File | Prefix | Covers | Milestones |
|---|---|---|---|
| [core/README.md](core/README.md) | `CORE` | Packaging and load, attaching a Module, the `Pagle` API at a glance, the event bus, restriction state, the Settings root and topic pages, the compartment menu, `/pagle`, the tracker dock | M0–M5 |
| [core/catch-log.md](core/catch-log.md) | `LOG` | Observing fishing, the Catch log and its entry formats, characters and the Angler, Skill Readings, conditions and `NextWindow`, the content catalogue at runtime, Sessions, Simulated Size, projections, the diagnostics buffer | M1, M2, M3, M4, M7 |
| [core/announcements.md](core/announcements.md) | `ANN` | Moments and the rung ladder, a Cast's Announcements, the display lanes, the Interruption budget, combat hold, Cozy mode, the Session summary, the Write-up, sounds and toast styles | M2, M4 |
| [core/wallet-and-shop.md](core/wallet-and-shop.md) | `SHOP` | Pagle Coins (earning, spending, balance), goods and slots, owning and equipping, the Curio Shop window, the Look and Feel page | M2, M4 |
| [core/activity-xp.md](core/activity-xp.md) | `AXP` | Activity XP: the lifetime totals Modules other than the Ledger report toward the Angler Level, their snapshot in each Prestige entry, and the overview of what pays | M8 Hunt Events |
| [core/pushed-content.md](core/pushed-content.md) | `PUSH` | The companion's `Pagle_Content` data addon: the signature check, the companion state, content by kind | M8 Hunt Events |
| [core/field-report.md](core/field-report.md) | `REP` | The Field report: what goes in, the `PAGLE-REPORT 1` format, privacy, the report box | M3 |
| [content-data.md](content-data.md) | `DATA` | The `data/` layers, the generator and its checks, the catalogue's Lua shape, `confirmed` and the two-reporter rule, the content fingerprint, the Hunt list format and `released.lock`, lore, Field report intake, the DB2 watch | M0–M8 |
| [qol.md](qol.md) | `QOL` | `Pagle_QoL`: the Fishing key, the double-click, gear, lures, clams, CVar leases for a Fishing stretch, the next-action button, Nudges, the Angleur and Fishing Buddy popup | M1, Track Q, M8 |
| [ledger.md](ledger.md) | `LED` | `Pagle_Ledger`: XP, Fresh Water, Angler Level and Prestige, milestones, Species and Zone Mastery, collections, Legends, Ledger completion, titles, size records, and the Fish Journal | M2, M3, M4 |
| [hunts.md](hunts.md) | `HNT` | `Pagle_Hunts`: which Catches qualify, tiers and set titles, effort, grouping into Now / Soon / Later / On demand, the Hunts board and tracker, and the v1 Hunt list | M5 |
| [stats.md](stats.md) | `STA` | `Pagle_Stats`: counts per place, skill side and window, Session records, Your odds, Dry spells and luck readings, the Stats book and the live tracker | M6 |
| [tackle-board.md](tackle-board.md) | `TKB` | `Pagle_TackleBoard`: board days, Notices and Expeditions as Module records, goal kinds, rerolls, the Campfire and Kindling, the Fly Box, the cork board and its tracker | M7 |
| [settings.md](settings.md) | `SET` | Where every option sits in the Settings tree: rows, order, headers, greying, Defaults, entry points, and each row's milestone | M1–M7 |
| [roadmap.md](roadmap.md) | none | The milestones M0–M8 and Track Q: goal, the rules each one builds, and its in-game exit check; the toolchain (M0); the launch re-verification checklist (M8) | M0–M8 |
| README.md (this file) | none | The index, the architecture overview, the Module map, and how to read the spec | |

Beside the spec:
- [`CONTEXT.md`](../../CONTEXT.md): the glossary. Every capitalised term in the spec (Cast, Catch, Session, Notice, Your odds…) means exactly what it says there.
- [`docs/adr/`](../adr/): the decision records, which keep the *why* (listed under [Decisions](#decisions)).
- [`prototypes/`](../../prototypes/README.md): the UI prototypes the UI sections link to.
- [`docs/research/`](../research/) and [`probes/`](../../probes/): research notes and in-game probe results, linked as evidence.

**A suggested reading order** for someone new: this file, `CONTEXT.md`, [core/README.md](core/README.md), [core/catch-log.md](core/catch-log.md), [core/announcements.md](core/announcements.md), then the file for the work at hand, with [roadmap.md](roadmap.md) for what is built when.

## Architecture overview

### The package

Pagle ships as one zip of six addons, DBM-style (CORE-R1–R3): **Core** (`Pagle`) and five **Modules**, `Pagle_Ledger`, `Pagle_Hunts`, `Pagle_Stats`, `Pagle_TackleBoard` and `Pagle_QoL`. Each Module depends on Core and can be disabled in the AddOns list, which leaves nothing of it loaded (CORE-R17), so a player can, for example, swap QoL for Angleur. Every TOC is Forever-only (`## AllowLoadGameType: camelot`), and Core refuses to start anywhere else (CORE-R4). Every addon splits pure `logic/` (unit-tested) from `adapter/` code (CORE-R7). The toolchain and the check gate are in [roadmap.md M0](roadmap.md#m0-foundation).

### Modules see only Core

A Module talks to Core and nothing else (ADR 0001): it never calls, reads or listens to another Module, and no Module earns anything from another. Core publishes one global, `Pagle` (the read-only API and the event bus), and hands each Module a **Module handle** from `Pagle.RegisterModule` for the calls that act on its behalf (CORE-R12). Everything shared between Modules lives in Core: the Catch log, the content catalogue, conditions, Sessions, Simulated Sizes, Announcements, the wallet and the Curio Shop, the Settings tree, the compartment menu, `/pagle` and the tracker dock.

```
                 the game client (loot, spells, calendar, auras, skill, zone text)
                                         │   observed by Core alone (ADR 0001)
                                         ▼
 ┌────────────────────────────────── Core (Pagle) ─────────────────────────────────────┐
 │  Catch log (PagleLog): C1 Casts · S1 Skill Readings · P1 Prestiges · B1 builds ·      │
 │                        U1 purchases · A1 Module records          (ADR 0003, 0008)   │
 │  content catalogue · conditions and NextWindow · Sessions · Simulated Sizes         │
 │  projection machinery (ADR 0004)                                                     │
 │  Announcements, Session summary, Write-up (ADR 0007) · Pagle Coins, Curio Shop       │
 │  (ADR 0009) · Field report · Settings tree · compartment menu · /pagle · tracker dock │
 └──────────────────────────────────────────────────────────────────────────────────────┘
        │ typed records (live, replay, rebuild), events,            ▲ moments, summary lines, Write-ups,
        │ catalogue lookups, conditions                             │ Coins totals, goods, Module records,
        ▼                                                           │ settings rows, trackers
   Ledger · Hunts · Stats · Tackle Board: one stored projection each, and their own views
   QoL: no projection; reads live game state only for its own key (QOL-R4)
```

### The Catch log and projections

**Core alone observes the game.** It turns each fishing attempt that ends caught or got away into a **Cast** entry in the **Catch log** (`PagleLog`), with a snapshot of raw observations: realm minute, zone and subzone areaIDs, skill, lure, events and auras, and each item offered (LOG-R1–R9, LOG-R20). Every offered item is a **Catch**, Uncharted ones included (LOG-R8). The log is account-wide, append-only and never rewritten: one tagged string per entry, with globally unique entry and Catch IDs and a `(logId, seq)` cursor for a future backend (LOG-R10–R18). Besides Casts it holds Skill Readings, Prestiges, build entries, purchases and **Module records**, opaque entries a Module asks Core to append for choices the log couldn't otherwise rebuild, such as a Notice being issued (LOG-R40, ADR 0008).

**Everything a Module shows is derived from the log**, read through the content catalogue. Each Module keeps a **stored projection** in its own SavedVariable (ADR 0004): Core feeds it every entry once, as `"live"` while the Module runs, as `"replay"` when it catches up on entries recorded while it was off, or as `"rebuild"` when the content fingerprint or its rules version changed (LOG-R70–R77). Only live entries may raise moments. A Module's **celebrated set**, kept outside the projection, remembers what was already shown, so a rebuild never shows anything twice or takes anything away. History a Module first builds from, or catches up on, becomes one **Write-up** card instead of pop-ups (ANN-R60–R63).

Sessions (runs of Casts with no 5-minute gap) are cut by Core from the log and tagged on every record, never stored and never cut by a Module (LOG-R60–R64, LOG-R98). Simulated Sizes are computed by Core from the Catch ID alone, with frozen bands (LOG-R65–R69, ADR 0010).

### Feedback, Coins and looks

**Core presents every Announcement** (ADR 0007). Modules raise **moments** on a fixed rung ladder (`nod`, `toast.low`, `toast`, `toast.high`, `banner`, `splash`); Core merges one Cast's moments from every Module into at most two Announcements (its banners and splash, its toasts and nods), then applies the Interruption budget, the combat hold, Cozy mode and expiry, plays the sound, and collects everything into the Session summary (ANN-R1–R63). Stats and QoL raise none: Stats announces nothing, and QoL's **Nudges** are its own silent lines, not Announcements (QOL-R75–R78).

**Core holds Pagle Coins** (ADR 0009). The Ledger, Hunts and the Tackle Board pay in for achievements only, each reporting its own lifetime total, so disabling a Module never takes back what it paid (SHOP-R1–R5). Coins buy **looks** in Core's **Curio Shop**: goods each Module registers for its own views (Journal bindings, notebook covers, tracker frames) beside Core's toast styles, sound sets and bookplate crests. Goods never carry meaning: titles, flies, stars and Legends are never sold (SHOP-R20).

### Content data

Pagle's knowledge of the fishing world is built in the repo, not in the game ([content-data.md](content-data.md)). Four layers under `data/` (a frozen VMaNGOS baseline, hand-edited Forever overrides, a per-build DB2 slice, and in-game observations) are merged by a typed Python generator into committed Lua: the **catalogue** in Core (`Catalogue.lua`), the **Hunt list** in Pagle_Hunts (`HuntList.lua`), and each addon's **lore** (`Lore.lua`). It ships IDs and numbers only, never game names or drop rates (DATA-R3, DATA-R4). A release that changes the catalogue changes the **content fingerprint**, which rebuilds every projection, and that is how Uncharted Catches are credited later (DATA-R70, DATA-R71). Gaps after launch close through the loop of `/pagle report` → a GitHub issue form → `data/observed/` → the next release (REP, DATA-R115–R123).

### Saved data

| SavedVariable | Owner | Holds |
|---|---|---|
| `PagleLog` | Core (plain table) | The Catch log: `format`, `logId`, `characters`, `entries` ([catch-log.md](core/catch-log.md#data)) |
| `PagleDB` | Core (AceDB) | Core's settings, Announcement data, the wallet and goods cache, Core's projections, the diagnostics buffer ([catch-log.md](core/catch-log.md#pagledb-acedb-one-shared-default-profile)) |
| `PagleLedgerDB`, `PagleHuntsDB`, `PagleStatsDB`, `PagleTackleBoardDB` | each Module (AceDB) | its settings, its projection table and its celebrated set (Stats has none) |
| `PagleQoLDB` | QoL (AceDB) | its settings, the fishing set per character, and leased CVars |

Everything is account-wide, per WoW game account; per-character facts are keyed by character GUID (CORE-R5). A Module never reads `PagleLog`, `PagleDB` or another Module's DB ([catch-log.md](core/catch-log.md#module-savedvariables)). Nothing needs backward compatibility before 1.0 ([roadmap.md](roadmap.md#how-the-roadmap-works)).

### Standing product rules

These hold everywhere and come from the map's settled Notes:
- **Observe and reward.** Pagle never plays for the player. QoL does at most one game action per keypress and never acts on its own (QOL-R5).
- **Forever only.** No Retail, no other game type (CORE-R2, CORE-R4).
- **Language-independent.** Items, places and spells are identified by ID; names resolve at runtime. 1.0 is enUS, with every string in `ns.L` (CORE-R8, DATA-R3).
- **Native look**, with four exceptions in one leather-and-parchment language: three books (the Fish Journal, the Hunts board, the Stats book) and the Tackle Board's cork board. HUD trackers stay native.
- **Sync-ready data**, so a future backend or social layer can read the log from SavedVariables (LOG-R13–R15).

## Module map

### What each addon is

| Addon | `def.name` · title · order | In one line | View and entry points | Tracker (dock order) | Built in |
|---|---|---|---|---|---|
| `Pagle` (Core) | none | Observes and records; hosts every shared service and surface | Settings root, compartment menu, `/pagle`, the Curio Shop (`/pagle shop`), the Field report box (`/pagle report`) | the dock itself (CORE-R70) | M0–M5, M7 |
| `Pagle_Ledger` | `Ledger` · Ledger · 10 | The Angler's identity: levels, mastery, collections, Legends, titles, records | the Fish Journal: compartment "Fish Journal", `/pagle journal`, root button "Open Fish Journal" | none | M2–M4 |
| `Pagle_Hunts` | `Hunts` · Hunts · 20 | Data-defined target Catches under conditions that open and close | the Hunts board: compartment "Hunts", `/pagle hunts`, "Open Hunts" | pinned Hunts (10) | M5 |
| `Pagle_Stats` | `Stats` · Stats · 30 | The Angler's own numbers: Sessions, Your odds, Dry spells | the Stats book: compartment "Stats", `/pagle stats`, "Open Stats" | Session and watched Dry spells (20) | M6 |
| `Pagle_TackleBoard` | `TackleBoard` · Tackle Board · 40 | Opt-in goals that never expire, with a Campfire and a Fly Box | the cork board: compartment "Tackle Board", `/pagle board`, "Start my board" / "Open Tackle Board" | goals workable here (30) | M7 |
| `Pagle_QoL` | `QoL` · QoL · 50 | One game action per keypress: cast, reel, gear, lures, clams | no view: compartment "Input: …", `/pagle qol`, "Fishing settings »", the Fishing key and Swap gear bindings | none (its own next-action button) | M1, Track Q, M8 |

### What each Module gives and takes

| Module | Projection | Module records | Moments (highest rung) | Pagle Coins | Curio Shop slots | Settings rows | Summary line |
|---|---|---|---|---|---|---|---|
| Ledger | XP, levels, mastery, collections, records (LED-R2) | none | many, up to `splash` for a Legend (LED-R97) | levels, Prestige, discoveries, ranks, Legends (LED-R88) | `ledger.binding` | none (LED-R1) | `ledger` |
| Hunts | counts, tiers, effort, set titles (HNT-R136) | none | `toast.high` tiers, `banner` set titles, opt-in `nod` windows (HNT-R86, HNT-R88) | 30 / 15 / 100 (HNT-R110) | `hunts.notebookcover`, `hunts.trackerframe` | Announcements, Trackers | `hunts` |
| Stats | counts per scope, every Session (STA-R20) | none | none (STA-R2) | none | `stats.trackerframe` | Trackers | none |
| Tackle Board | goals, Campfire, Fly Box, titles (TKB-R81) | `start`, `day`, `issue`, `reroll` (TKB-R80) | `toast.low` / `toast` goals, `banner` milestones and titles, `nod` Campfire news (TKB-R86) | goals and Campfire milestones (TKB-R63) | `tackleboard.trackerframe` | Trackers | `board` |
| QoL | none (QOL-R3) | none | none | none | none | the Fishing page | none |

Core's rung table ([announcements.md](core/announcements.md#rungs-modules-use-so-far)) and payout table ([wallet-and-shop.md](core/wallet-and-shop.md#contracts)) repeat these as cross-checks; each Module's spec is authoritative for its own rows. [settings.md](settings.md) shows every row in place.

### Where to look for a cross-cutting topic

| Topic | Owner | Also see |
|---|---|---|
| Module disabled, then enabled again | LOG-R71, LOG-R90 (catch-up) | each file's first edge-case rule; ANN-R60 (the Write-up) |
| Projection rebuild and first build | LOG-R72–R77 | ANN-R60–R63; each Module's `done` rules |
| Combat and restriction | CORE-R30–R33 | ANN-R35–R37; QOL-R30–R34; HNT-R43; each file's "In combat" rule |
| Crashes | LOG-R85, LOG-R86 | QOL-R67; each file's "Crash mid-Session" rule |
| Daily and weekly reset | TKB-R10–R14 (the only Module that uses it) | every other file says it doesn't depend on it |
| Uncharted and unconfirmed Catches | LOG-R8, LOG-R96 | DATA-R45–R57; REP-R10; each Module's last edge-case rule |
| Windows, time and seasons | LOG-R46–R50, DATA-R35–R38 | HNT-R40–R53 (the board); LED-R127; STA-R14–R15 |
| Simulated Size | LOG-R65–R69, ADR 0010 | LED-R80–R85 (records); HNT-R10 (`minBand`); TKB-R42 (Size goals) |
| Lore and display text | DATA-R100–R112 | each Module's Lore rule; CORE-R8 for interface text |
| Settings | CORE-R40–R44 (mechanism) | [settings.md](settings.md) (layout); each file's Settings section (values) |

## How to read the spec

### Source of truth

- **The spec is canonical for the current state.** Amendments are folded in and superseded designs don't appear. Where a ticket and the spec differ, the spec wins.
- **Tickets are history.** Each file's header lists the tickets it came from, linked to their resolution comments; you shouldn't need them to build.
- **ADRs keep the why.** The spec links them instead of restating the reasoning.
- **`CONTEXT.md` is the glossary.** The spec uses its terms without redefining them; a few files add local words for their own views (for example the Stats book's "spread" and "kicker", stats.md UI).
- **Prototypes are visual reference only.** Where a prototype and the text differ, the text wins.
- **One owner per fact.** Each rule, contract and number has one owning file. A file that repeats another's facts (Core's rung and payout tables, settings.md's rows, the roadmap's lists) says who owns them, and the owner wins. Two files that disagree on behaviour is a question for the dev, not a call for the reader.
- **Research and probe notes** are evidence, linked where a rule depends on them.

### Rule IDs

- Every rule has a stable ID: the file's prefix, then `-R` and a number (`LED-R12`). Build tickets, tests and the roadmap cite rules by ID, and other files cite them instead of restating them.
- Numbers are grouped by topic, with gaps left for later rules, so `R1–R7` then `R10` is normal. Each file's edge-case rules are one block near the end of its numbering: from `R80` in core/README.md, `R90` in most files, and `R190` where the topic rules run past 100.
- An ID is never reused or renumbered. A changed rule keeps its ID; a removed one stays, marked *Retired*. There is no spec versioning before 1.0: git history is enough.
- A range such as `LOG-R70–R77` means every rule from the first to the last.

### The file template

Every Core and Module file follows one template (the conventions in [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652)):

```
# <Module>
> Status: Draft | Done · Milestones: … · Sources: <ticket names>, ADRs

## Purpose and boundary   owns / doesn't own / uses from Core
## Rules                  <PREFIX>-R1… grouped by topic; each testable
## Data                   log entries / Module records written, projection shape + version, SavedVariables keys
## Contracts              Pagle API used/exposed, events raised/consumed, moments + rung, Coins paid, Curio goods registered
## UI                     frames, states, entry points, link to prototypes/<name>
## Settings               option · values · default
## Tunables               name · value · rule IDs that use it
## Pending                only while a ticket is open; must be empty for Done
## Edge cases             the checklist below, answered as rules
```

`content-data.md`, `settings.md` and `roadmap.md` adapt it to what they cover. The level of detail is behaviour plus every **public contract**, stated exactly: `Pagle` API functions, events, Catch log entry formats, SavedVariables shapes and projection versions, Announcement rungs, Coins paid. Module internals (files, local functions) are left to build tickets.

Every number lives in its file's **Tunables** table, with the rules that use it; a few values that must never change (the Size band cut points, the Simulated Size hash) are marked frozen instead.

### The edge-case checklist

Every Core and Module file answers each of these with rules: a Module disabled and then enabled again; a projection rebuild; the first build over existing history (the Write-up); in combat; a crash mid-Session; a daily or weekly reset; an Uncharted or unconfirmed Catch. Files add their own cases (a new dev log, two machines, a retired Hunt).

### Status and Pending

- **Done** means the file has no `Pending:` markers, every term is in `CONTEXT.md`, every number is in Tunables, and a **dry-run split** came back clean: a fresh agent with only the file, `CONTEXT.md` and the ADRs split it into build tickets and had nothing left to guess.
- **Draft** means a `Pending: <ticket>` marker points at a ticket that is still open. Today every file is Done and there are no `Pending:` markers.

### Words that mean one thing everywhere

| Phrase | Meaning | Rule |
|---|---|---|
| raises a Lua error | `error(message, 2)`: the call is aborted and has no effect | CORE-R14 |
| restricted | combat lockdown or Midnight's addon restriction is active (`Pagle.IsRestricted()`) | CORE-R30 |
| On (a Module) | enabled and registered with Core | CORE-R41 |
| `"live"`, `"replay"`, `"rebuild"` | how a projection is being fed an entry; only `"live"` may raise moments | LOG-R75 |
| server time / realm time | `GetServerTime()` / the realm's clock from `GetGameTime()`; windows and labels use realm time | LOG-R20, LOG-R49 |
| item `0` | a Catch whose item ID was secret; it counts as a Catch and is never credited | LOG-R8 |
| interface text / lore | strings in `ns.L` written in code / invented names and flavour from `data/lore/` | CORE-R8, DATA-R100 |

### From the spec to build tickets

[roadmap.md](roadmap.md) assigns every rule ID to a milestone (M0–M8) or to Track Q, and each milestone has an in-game exit check. A build ticket belongs to one milestone and cites the rules it builds; a test cites the rule it checks. Rules that name a later feature take effect when that feature lands (roadmap.md, How the roadmap works). Nothing is published before 1.0, and nothing needs backward compatibility until then.

### Changing the spec

Any ticket whose answer changes the spec edits the spec in the same change, keeping rule IDs stable and filling any `Pending:` marker that points at it. A change that touches a contract repeated elsewhere (a rung, a payout, a settings row, a milestone list) updates the copies too.

## Decisions

| ADR | Decision |
|---|---|
| [0001](../adr/0001-modules-only-see-core.md) | Modules only see Core |
| [0002](../adr/0002-ledger-derived-from-catch-log.md) | Ledger progression is derived from the Catch log, with a high-water mark (superseded by 0004) |
| [0003](../adr/0003-catch-log-entries-are-tagged-strings.md) | Catch log entries are tagged strings that are never rewritten |
| [0004](../adr/0004-module-state-is-a-stored-projection.md) | Module state is a stored projection, rebuilt only when versions change |
| [0005](../adr/0005-shipped-hunt-definitions-are-immutable.md) | Shipped Hunt definitions are immutable |
| [0006](../adr/0006-pagle-is-gpl-because-it-ships-vmangos-data.md) | Pagle is GPL because it ships VMaNGOS-derived data |
| [0007](../adr/0007-core-presents-announcements.md) | Core presents Announcements |
| [0008](../adr/0008-modules-append-opaque-records-to-the-catch-log.md) | Modules append opaque records to the Catch log |
| [0009](../adr/0009-core-holds-the-pagle-coins-wallet.md) | Core holds the Pagle Coins wallet and the Curio Shop |
| [0010](../adr/0010-simulated-size-is-fixed-by-the-catch-id.md) | A Simulated Size is fixed by the Catch ID, and its band cut points are frozen |

## Outside this spec

Planned for after 1.0 and listed in [roadmap.md](roadmap.md#after-10), but not specified: custom Journal art, translations, the export/backup string, QoL's recast reminder, and post-launch Hunts. Out of scope altogether (the map's Out of scope): Retail, social and guild features, a backend or companion app, merging logs from two machines, Hunts pushed from a backend, and any automation beyond one action per keypress.
