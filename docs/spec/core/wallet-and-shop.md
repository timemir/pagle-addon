# Core: Pagle Coins and the Curio Shop

> Status: Draft · Milestones: M2 (wallet: earned totals, balance, Coins stamps, the balance in the compartment menu), M4 (Curio Shop, Appearance page, the first goods) · Sources: [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Prototype the Curio Shop](https://github.com/timemir/wow-fish/issues/30#issuecomment-6125718197), [Prototype the Tackle Board](https://github.com/timemir/wow-fish/issues/29#issuecomment-6126015781), [Prototype the Fish Journal](https://github.com/timemir/wow-fish/issues/12#issuecomment-6112909660), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652), [Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441); ADR 0001, 0003, 0007, 0009. Prototype: `prototypes/curio-shop/` (variant B)

Part of [Core](README.md). Core holds the Angler's **Pagle Coins** and runs the **Curio Shop** (ADR 0009).

## Purpose and boundary

**Owns:** the wallet (earned totals by source, spent total, balance), the goods registry, ownership and equipped looks, purchase entries, the Curio Shop window, the Appearance settings page, and Core's own goods (toast styles, sound sets, bookplate crests).

**Doesn't own:** what a Module pays Coins for or how much (each Module's spec), the looks a Module's goods apply to (each Module draws its own views), or Ledger level rewards (the Ledger decides when a binding is earned).

## Rules

### Earning

- **SHOP-R1** Coins reward achievements only, never raw volume. Core itself pays nothing: no Coins for Casts or Catches. Stats and QoL pay nothing.
- **SHOP-R2** A paying Module keeps its own **lifetime Coins earned** in its projection (ADR 0004) and reports it with `M:ReportCoinsEarned(total)`: from its projection's `done` after every catch-up or rebuild (even when unchanged, so a lost `PagleDB` refills), and after each live entry that changes it. It never reports mid-rebuild.
- **SHOP-R3** Core stores the last total each Module reported in `PagleDB.global.coins.earned[<def.name>]`. A Module that is disabled or uninstalled keeps its last total, so nothing it paid is lost. If `PagleDB` itself is lost, a disabled Module's total is gone until it is enabled and reports again.
- **SHOP-R4** Disabling a Module never lowers what it paid. Only a rebalance or data fix can recount a Module's total lower; then `earned` follows the new report, but the balance never goes below 0 (SHOP-R12) and nothing bought is taken back.
- **SHOP-R5** Coins show as a "+N" stamp on the Announcement the moment already earns (`coins` on the moment, ANN-R23) and as one Session summary line ("Pagle Coins +45"). Earning Coins never makes an Announcement of its own. Coins earned in history a Module catches up on or first builds from appear only as a line in its Write-up section, written by the Module (ANN-R60).

### Spending

- **SHOP-R10** A purchase appends a purchase entry (`U1`, LOG-R39) with the good's ID and the price paid. A later price change never moves a balance, and purchases are never revoked.
- **SHOP-R11** Core keeps `spent` and the set of purchased good IDs as a Core projection over the log (LOG-R78). Only the first `U1` for a good counts; any later one for the same good is ignored.
- **SHOP-R12** **Balance** = Σ earned − spent, shown as **0** when that is negative. While it is negative ("held"), the shop shows one quiet line: "Your balance is 0 while Pagle re-counts earlier Coins. New Coins fill that in first." It never mentions debt or a negative number.
- **SHOP-R13** **Buy** is enabled only when the good is for sale, not owned, its Module is enabled, the balance covers the price, and no projection (Core's or any Module's) is updating. Each purchase is one good and one confirmation.

### Goods

- **SHOP-R20** A **good** is a look for one of Pagle's own views, in one **slot**. Goods never carry meaning: titles, Fly Box flies, stars, Legends, Prestige and set emblems are never goods.
- **SHOP-R21** Modules register their own slots and goods with `M:RegisterSlot` and `M:RegisterGood`, at any time after `RegisterModule`; Core registers its own. Slot and good IDs are `<def.name lowercased>.<name>` (`core.` for Core's), match `[%w_.]+`, and never change once shipped.
- **SHOP-R22** Every good is exactly one of:
  - **default**: free and owned by everyone; each slot has exactly one
  - **for sale**: price tier 1, 2 or 3 (150, 400 or 900 Coins)
  - **earned**: never for sale; owned when its Module says so (`isEarned()`), with an `earnedText` saying how ("Angler Level 30")
- **SHOP-R23** Registration raises a Lua error and ignores the call for: a duplicate ID, an ID without the Module's prefix, an unknown slot, a slot registered by a different Module (or by Core, for a Module), a second default in a slot, and a good with more than one of `default` / `tier` / `isEarned`, or none of them. At `ModulesChanged`, a slot with no default is reported through `geterrorhandler()`, and its first registered good acts as the default.
- **SHOP-R24** Stock never rotates and nothing is limited-time: every good registered is always in the shop.
- **SHOP-R25** Core's own slots and goods, at M4 (tiers are tunable):

  | Slot | Goods |
  |---|---|
  | Toast style (`core.toaststyle`) | `core.toaststyle.timber` (default), `core.toaststyle.ripple` (tier 1), `core.toaststyle.lanternglow` (tier 2) |
  | Sound set (`core.soundset`) | `core.soundset.driftwood` (default), `core.soundset.gilded` (tier 2) |
  | Bookplate crest (`core.crest`) | `core.crest.plain` (default), `core.crest.crest1` (tier 1), `core.crest.crest2` (tier 2), `core.crest.crest3` (tier 3) |

  Every good's name and description is lore, read from `data/lore/core.toml` through `ns.L`; the working names (Timber, Ripple, Lantern Glow, Driftwood, Gilded, Plain) are its first drafts. IDs may still be renamed before 1.0.
  The crest is the Angler's emblem; the Ledger draws it on the Journal bookplate. Its slot is shown whatever Modules are enabled.
- **SHOP-R26** Core caches every registered good in `PagleDB.global.goods`: name, slot, slot label and category, Module, icon, `default`, tier, description and, for earned goods, the `isEarned()` result as of the last registration or `RefreshGoods` (SHOP-R31). The cache is never pruned for a good that is owned.

### Owning and equipping

- **SHOP-R30** `Pagle.IsOwned(goodID)` is true for defaults of registered slots, purchased goods, and earned goods whose cached `isEarned()` result is true. Core never calls `isEarned()` on an ownership check; it reads the cache, whether or not the Module is enabled.
- **SHOP-R31** Core calls a Module's `isEarned()` functions only when the good is registered and when the Module calls `M:RefreshGoods()`. A Module calls it after a live entry that could change an earned good, and from its projection's `done`; never mid-catch-up or mid-rebuild, so looks don't flicker.
- **SHOP-R32** Each slot has one **equipped** good, stored as a Core setting (`PagleDB.profile.appearance[slot]`). `Pagle.SetEquipped(slot, goodID)` accepts only an owned good of that slot. `Pagle.GetEquipped(slot)` returns the stored good if it is owned and registered, and the slot's default otherwise. That fallback happens on reading only: the stored choice is never cleared, so it comes back when its Module does.
- **SHOP-R33** `AppearanceChanged(slot, goodID)` fires whenever the result of `GetEquipped(slot)` changes, whatever the reason (a `SetEquipped`, a Module enabled or disabled, an earned good lost or regained). Each Module redraws its own views from `Pagle.GetEquipped`; Core redraws its frames and picks sounds from its own slots.
- **SHOP-R34** While the wallet projection is updating, `IsOwned` answers from the owned set saved before the update started, so looks don't flicker to defaults.
- **SHOP-R35** A disabled Module's goods for sale leave the shop. Its purchased and earned goods stay owned and are listed under "Put away: Module off", from the cache. Its defaults are neither listed nor counted. Its slots don't appear on the Appearance page.

### Entry points

- **SHOP-R40** The Curio Shop opens from the compartment menu entry "Curio Shop" (CORE-R50), from `/pagle shop` (a toggle), from `Pagle.OpenShop(goodID?)`, and from the Appearance page's "Open the Curio Shop" button. `OpenShop` selects that good; an unknown ID selects nothing; a good of a disabled Module selects it in "Put away" if owned, otherwise nothing. Esc closes it.
- **SHOP-R41** While restricted, every entry point prints "Pagle: the Curio Shop opens after combat." instead. At `RestrictionChanged(true)`, an open shop and its Buy popup close; nothing is queued.

## Data

| Key | Contents |
|---|---|
| `PagleDB.global.coins.earned` | `{ [def.name] = lifetimeTotal }`, the last report per Module (SHOP-R3) |
| `PagleDB.global.goods` | `{ [goodID] = { name, slot, slotLabel, category, module, icon, default, tier, description, earned } }` (SHOP-R26) |
| `PagleDB.global.projections.wallet` | the wallet projection: `spent`, `purchased = { [goodID] = true }` (SHOP-R11) |
| `PagleDB.profile.appearance` | `{ [slot] = goodID }`, equipped looks (SHOP-R32) |
| Catch log | `U1|<header>|<good>|<price>` per purchase ([catch-log.md](catch-log.md#entry-formats)) |

## Contracts

```lua
---@class PagleSlot
---@field id string              -- "core.toaststyle", "hunts.notebookcover", "stats.trackerframe"
---@field label string           -- "Toast style"
---@field category "Announcements"|"Bookplate"|"Fish Journal"|"Hunts"|"Trackers"

---@class PagleGood
---@field id string
---@field slot string
---@field name string
---@field description? string
---@field icon? integer|string
---@field default? boolean        -- SHOP-R22
---@field tier? 1|2|3             -- for sale
---@field isEarned? fun(): boolean -- earned
---@field earnedText? string      -- earned: "Angler Level 30"
---@field preview fun(stage: Frame)   -- draws the look on the shop's preview stage

---@class Balance
---@field balance integer         -- never negative
---@field held boolean            -- earned < spent (SHOP-R12)
---@field earned { [string]: integer }   -- by def.name
```

| Call / event | Rules |
|---|---|
| `M:ReportCoinsEarned(total)` | SHOP-R2 |
| `M:RegisterSlot(slot)`, `M:RegisterGood(good)` | SHOP-R21–R23 |
| `M:RefreshGoods()` | SHOP-R31 |
| `Pagle.GetBalance()` | SHOP-R12 |
| `Pagle.IsOwned(goodID)`, `Pagle.GetEquipped(slot)`, `Pagle.SetEquipped(slot, goodID)` | SHOP-R30–R34 |
| `Pagle.OpenShop(goodID?)` | SHOP-R40, SHOP-R41 |
| event `BalanceChanged(balance: Balance)` | whenever any field of `Balance` changes |
| event `AppearanceChanged(slot, goodID)` | SHOP-R33 |

What each Module pays and registers, as designed so far (each Module's spec is authoritative):

| Source | Coins |
|---|---|
| Tackle Board: Notice / Expedition | 10, 15 or 20 by difficulty / 60 |
| Tackle Board: Campfire 7 / 30 / 100 / 365 days | 25 / 75 / 200 / 500 |
| Ledger: Angler Level up / Prestige | 20 / 100 |
| Ledger: new Species / new Sub-collection item | 10 / 5 |
| Ledger: Zone Mastery rank | 2 × rank (Visitor 2 … Master 10) |
| Ledger: Legend | 100 |
| Hunts: completed / each further tier / set finished | 30 / 15 / 100 |

Goods by Module: Ledger registers extra Journal bindings (for sale) and the six level bindings (earned); Hunts registers notebook covers; Hunts, Stats and the Tackle Board each register frames for their own tracker.

## UI

One native Collections-style window, "Curio Shop" (variant B of the prototype):

- **Header (the purse):** the balance, then income by source as a stacked bar (Tackle Board / Ledger / Hunts), with each Module's lifetime total in a legend and tooltip, and "Stats and QoL pay none". A Module that is off (CORE-R41) has its segment faded and its legend entry struck through, but its total still counts. There is no "Spent" anywhere. The held line (SHOP-R12) shows here.
- **Left, the list:** a search box (matches names); a filter (All / Owned / Not owned / Can afford); category chips in the order Announcements, Bookplate, Fish Journal, Hunts, Trackers, each shown only if a registered slot uses it. Goods are grouped by slot (Core's slots first, then by Module order), with an owned count per slot; each row shows a swatch, the name and its state. "Put away: Module off" is the last group, greyed, saying "Yours to keep".
- **Right, the preview stage:** the selected good's `preview` (a sample toast with "Show on screen" for a toast style; ▶ Toast / ▶ Banner / ▶ Legend for a sound set; the bookplate for a crest; the closed book for a binding or cover; a sample tracker for a tracker frame), then its name, slot, owning Module, description and actions. A "Put away" good shows its cached icon as a swatch.
- **States on a row and the stage:**
  - for sale: price in white, "Buy for N"
  - can't afford: price in red, Buy disabled, "N more needed"
  - owned: "Owned" tag and a **Use** button
  - equipped: "In use" tag
  - default: "default"
  - earned and not yet earned: its `earnedText`, "a Ledger reward, not for sale"
- **Buy:** a StaticPopup "Buy {name}?" with the swatch, the price, "Pagle Coins left after: N. Looks are yours for good.", a **"Use it now"** checkbox (on by default) and Buy / Cancel. No Announcement follows.

**Appearance page** (a Settings subcategory under Core's root, built when first opened so late registrations appear): one dropdown per registered slot of an enabled Module (and Core's), listing owned looks; under each, "N more in the Curio Shop", where N counts that slot's for-sale goods not owned; and one "Open the Curio Shop" button. It edits the same equipped setting as the shop's Use button.

## Settings

The Appearance page holds one option per slot (equipped good; default: the slot's default good). Where toast style and sound set also appear is for `docs/spec/settings.md`.

## Tunables

| Name | Value | Rules |
|---|---|---|
| Price tiers | 150 / 400 / 900 | SHOP-R22 |
| Core goods' tiers | as SHOP-R25 | SHOP-R25 |
| Pacing target | first purchase in week 1; whole 1.0 catalogue in 6–12 months | SHOP-R22 |
| Income mix target (committed Angler, first 3 months) | Tackle Board ~55% / Ledger ~35% / Hunts ~10% | payout table |

## Edge cases

- **SHOP-R90 Module disabled, then enabled again.** While disabled: its last earned total still counts (SHOP-R3), its goods for sale leave the shop, owned ones move to "Put away" (SHOP-R35), and `GetEquipped` falls back to defaults for its slots without clearing the stored choice (SHOP-R32). Re-enabled: it reports its total after catch-up (with a Write-up line for Coins earned meanwhile), its goods return, and its stored looks come back.
- **SHOP-R91 Projection rebuild.** A Module's rebuild may change its earned total; the balance follows, held at 0 if needed (SHOP-R12). The wallet's own projection rebuilds from `U1` entries, without flicker (SHOP-R34). Buying waits until no projection is updating (SHOP-R13).
- **SHOP-R92 First build over existing history.** A late-enabled Module reports its whole earned total at once; it shows as a line in its Write-up section, not as stamps.
- **SHOP-R93 In combat.** SHOP-R41; reports and balance updates continue.
- **SHOP-R94 Crash mid-Session.** A purchase is a log entry like any other, so a purchase not yet saved is lost with the session; the good is simply not owned at the next login.
- **SHOP-R95 Daily or weekly reset.** No rule here depends on it.
- **SHOP-R96 Uncharted or unconfirmed Catch.** Not relevant: Coins come from Module achievements, which credit Uncharted Catches only once classified.

## Not in 1.0

The **Angler card** for a future social layer (active title, bookplate crest, equipped binding, Angler Level and Prestige, Ledger completion %; one 255-byte addon message) is recorded as a shape only. Server-side validation of Coins and purchases belongs to the backend effort.
