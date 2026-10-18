# Core: Pagle Coins and the Curio Shop

> Status: Done · Milestones: M2 (wallet: earned totals, balance, Coins stamps, the balance in the compartment menu), M4 (Curio Shop, Look and Feel page, the first goods) · Sources: [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Prototype the Curio Shop](https://github.com/timemir/wow-fish/issues/30#issuecomment-6125718197), [Prototype the Tackle Board](https://github.com/timemir/wow-fish/issues/29#issuecomment-6126015781), [Prototype the Fish Journal](https://github.com/timemir/wow-fish/issues/12#issuecomment-6112909660), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652), [Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441); ADR 0001, 0003, 0007, 0009. Prototype: `prototypes/curio-shop/` (variant B)

Part of [Core](README.md). Core holds the Angler's **Pagle Coins** and runs the **Curio Shop** (ADR 0009).

## Purpose and boundary

**Owns:** the wallet (earned totals by source, spent total, balance), the goods registry, ownership and equipped looks, purchase entries, the Curio Shop window, the Look and Feel settings page, and Core's own goods (toast styles, sound sets, bookplate crests).

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
- **SHOP-R23** Registration raises a Lua error and ignores the call for: a duplicate ID, an ID without the Module's prefix, an unknown slot, a slot registered by a different Module (or by Core, for a Module), a second default in a slot, and a good with more than one of `default` / `tier` / `isEarned`, or none of them. At `ModulesChanged`, a slot with no default is reported through `geterrorhandler()`, and its first registered good acts as the default. Only `default = true` marks a default; `default` is `true` or `false`, and anything else is a mistake.
- **SHOP-R24** Stock never rotates and nothing is limited-time: every good registered is always in the shop.
- **SHOP-R25** Core's own slots and goods, at M4 (tiers are tunable):

  | Slot | Goods |
  |---|---|
  | Toast style (`core.toaststyle`) | `core.toaststyle.page` (default), `core.toaststyle.ripple` (tier 1), `core.toaststyle.lanternglow` (tier 2) |
  | Sound set (`core.soundset`) | `core.soundset.driftwood` (default), `core.soundset.gilded` (tier 2) |
  | Bookplate crest (`core.crest`) | `core.crest.plain` (default), `core.crest.crest1` (tier 1), `core.crest.crest2` (tier 2), `core.crest.crest3` (tier 3) |

  Every good's name and description is lore, read from `data/lore/core.toml` through `ns.L`; the working names (Timber, Ripple, Lantern Glow, Driftwood, Gilded, Plain) were its first drafts, and the 1.0 sign-off ([#264](https://github.com/timemir/wow-fish/issues/264)) renamed Timber to Torn Page and its ID from `core.toaststyle.timber` to `core.toaststyle.page`.
  The crest is the Angler's emblem; the Ledger draws it on the Journal bookplate. Its slot is shown whatever Modules are enabled.
- **SHOP-R26** Core caches every registered good in `PagleDB.global.goods`: name, slot, slot label and category, Module, icon, `default`, tier, description and, for earned goods, the `isEarned()` result as of the last registration or `RefreshGoods` (SHOP-R31). The cache is never pruned for a good that is owned.

### Owning and equipping

- **SHOP-R30** `Pagle.IsOwned(goodID)` is true for defaults of registered slots, purchased goods, and earned goods whose cached `isEarned()` result is true. Core never calls `isEarned()` on an ownership check; it reads the cache, whether or not the Module is enabled.
- **SHOP-R31** Core calls a Module's `isEarned()` functions only when the good is registered and when the Module calls `M:RefreshGoods()`. A Module calls it after a live entry that could change an earned good, and from its projection's `done`; never mid-catch-up or mid-rebuild, so looks don't flicker.
- **SHOP-R32** Each slot has one **equipped** good, stored as a Core setting (`PagleDB.profile.appearance[slot]`). `Pagle.SetEquipped(slot, goodID)` accepts only an owned good of that slot. `Pagle.GetEquipped(slot)` returns the stored good if it is owned and registered, and the slot's default otherwise. That fallback happens on reading only: the stored choice is never cleared, so it comes back when its Module does.
- **SHOP-R33** `AppearanceChanged(slot, goodID)` fires whenever the result of `GetEquipped(slot)` changes, whatever the reason (a `SetEquipped`, a Module enabled or disabled, an earned good lost or regained). Each Module redraws its own views from `Pagle.GetEquipped`; Core redraws its frames and picks sounds from its own slots.
- **SHOP-R34** While the wallet projection is updating, `IsOwned` answers from the owned set saved before the update started, so looks don't flicker to defaults.
- **SHOP-R35** A disabled Module's goods for sale leave the shop. Its purchased and earned goods stay owned and are listed under "Put away: Module off", from the cache. Its defaults are neither listed nor counted. Its slots don't appear in Settings.

### Entry points

- **SHOP-R40** The Curio Shop opens from the compartment menu entry "Curio Shop" (CORE-R50), from `/pagle shop` (a toggle), from `Pagle.OpenShop(goodID?)`, and from the Look and Feel page's "Open the Curio Shop" button. `OpenShop` selects that good; an unknown ID selects nothing; a good of a disabled Module selects it in "Put away" if owned, otherwise nothing. Esc closes it.
- **SHOP-R41** While restricted, every entry point prints "Pagle: the Curio Shop opens after combat." instead. At `RestrictionChanged(true)`, an open shop and its bill of sale (the Buy confirmation) close; nothing is queued.

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
| `Pagle.GetGood(goodID)` | SHOP-R26: a read-only copy of the cached `{ name, slot, icon, module, description, isDefault }`, whether or not the good's Module is enabled, or `nil` for a good never registered. `isDefault` is true for its slot's default (SHOP-R22), or the good standing in for one (SHOP-R23), so a view can draw a default as no look at all |
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

One window, "Curio Shop" (the layout of the prototype's variant B), drawn with the shop art kit as a travelling merchant's sample case: brown leather with stitching, brass corners and a handle, the "Curio Shop" trade label on its lid. It is 980 × 640 at UI scale 1, centred, movable by its leather, with a brass close button at the top right. It opens over every window already open, Pagle's and the game's: it lies in the HIGH strata, as the other Pagle windows do, is raised over them each time it is opened, and comes back to the front when clicked; its bill of sale and the medallion flying to the purse lie above it, in DIALOG. On a screen too small for it and its handle (at a large UI scale UIParent is only 668 units tall), it shrinks to fit, keeping 24 units clear round it; it never grows, and it fits again when the UI scale or the game window's size changes. Its art is three textures under `media/shop/` (BLP, DXT5, each with its mipmaps; 6 MB loaded in all), their sprites listed in `data/ShopArt.lua`. Its words are set in the bundled OFL fonts (IM Fell English and its italic for print, Caveat for handwriting, Marcellus for gilt, in `media/fonts/`), in capitals where the kit sets small caps, since the client has none. They pass CORE-R9, and `/pagle dev glyphs` shows each face.

- **The purse, on the case's top band:** the brass coin, "PAGLE COINS" over the balance in gilt, then income by source as a stacked bar (Tackle Board / Ledger / Hunts, each in its own colour), with each Module's lifetime total in a handwritten legend under it. Hovering a segment shows a dark tooltip edged in gilt, in the book's voice. A Module that is off (CORE-R41) has its segment faded and greyed and its legend entry greyed and struck through in red ink, but its total still counts. There is no "Spent" anywhere. The held line (SHOP-R12) shows under the legend, the bar moving up to make room.
- **Left, the green velvet tray, the list:** a paper search slip, "Find a look…" (matches names); the filter as pills (All / Owned / Not owned / Can afford), the one on in gilt; category chips as leather tabs in the order Announcements, Bookplate, Fish Journal, Hunts, Trackers, each shown only if a registered slot uses it. Goods are grouped by slot (Core's slots first, then by Module order), each slot's name in capitals with a gilt rule and its owned count ("1 of 3"). Each row shows the good's icon round in a brass medallion, its name and its state. The selected row sits on a gilt band. "Put away: Module off" is the last group, greyed, saying "Yours to keep". The list scrolls with the wheel and a slim brass scroll bar, shown only while the list overflows.
- **Right, the quilted lid, the stage:** a showcase card, whose dark well and the paper round and under it (390 × 190 in all, the 370 × 132 well centred at its top) are the selected good's `preview` stage: a sample toast with "Show on screen" for a toast style; ▶ Toast / ▶ Banner / ▶ Legend for a sound set; the bookplate for a crest; the closed book for a binding or cover; a sample tracker for a tracker frame. A preview is clipped to the card. A good with no preview, or put away, shows its icon in a medallion in the well, greyed if put away. Under it, the description card holds the good's name in handwriting, its slot and owning Module in red capitals, its description in italic, its notes, then Buy or Use with its tags at the foot.
- **States on a row and the stage:**
  - for sale: a paper price tag on a string, the price with a coin; "Buy for N" with a coin on a leather button
  - can't afford: the price in red on its tag, Buy dimmed and disabled, "N more Coins" in red beside it
  - owned: "Owned" on the row; "OWNED" and a **Use** button on the stage
  - equipped: "IN USE" after a wax dot on the row, and on the stage
  - default: "default"
  - earned and not yet earned: its `earnedText`, "a Ledger reward, not for sale"
- **Buy:** a bill of sale over the case, which dims: a sheet of paper with a torn top, "CURIO SHOP", "Buy {name}?" in handwriting, the good's medallion, a dashed rule, "Price" with the price and a coin, "Pagle Coins left after" with N, "Looks are yours for good.", a hand-ticked **"Use it now"** checkbox (on by default), and Buy / Cancel. Esc is Cancel there and leaves the shop open; any other key goes on to the game. No Announcement follows.

### Motion and sound

The case moves as the shop art kit's motion has it (`pagle-shop-kit` v2, its `MOTION.md`), played by Core's one `OnUpdate` (`adapter/Motion.lua`); `adapter/ShopMotion.lua` holds the shop's. With the **Animations** setting off (SET-R30), each change shows as it settles. A preview on the stage stands still (announcements.md › Motion).

| Moment | Motion | Settled |
|---|---|---|
| The bill of sale opens | The case dims (0.2 s); the bill drops in from 24 units up, fading in (0.3 s, overshooting a little). | 0.3 s |
| Cancel or Esc on the bill | The bill lifts 16 units and fades as the case brightens (0.25 s). | 0.25 s |
| A purchase | The good is bought at the click; the window then shows it in motion. Buy gives under the press (0.12 s). A wax seal is pressed onto the bill, low on its right, from 2.2x (0.1–0.55 s, overshooting). The good's medallion lifts off the bill and flies to its row, shrinking from 64 to 34 units (0.7–1.4 s); the bill lifts away behind it from 0.75 s. The purse counts down to the new balance (0.8–1.7 s) as its coin turns once (0.5 s). In the row, the price tag lifts away (1.4 s, 0.25 s), "IN USE" and its wax (or "Owned") come in, and the row glows warm once (0.8 s); the slot's old good's "IN USE" gives way to its new tag. The lid's Buy gives way to what follows (1.5 s, 0.35 s). Anything that redraws the window meanwhile, or its closing, settles it at once. | 2.2 s |
| Buy without enough Coins | A click on the dimmed Buy shakes "N more Coins": 6 units left and right three times, smaller each time (0.4 s). | 0.4 s |

The shop's sounds are the client's own sound kits (`PlaySound(id, "SFX")`), UI foley that is the same in every sound set (sound sets are the Announcements', ANN-R70); they follow the player's SFX volume and mute, and Pagle has no setting of its own for them (ANN-R73). The case opening and closing play `AUCTION_WINDOW_OPEN` (5274) and `AUCTION_WINDOW_CLOSE` (5275); Buy on the bill, once it buys, `IG_BACKPACK_COIN_OK` (865); a click on the dimmed Buy `IG_MAINMENU_OPTION_CHECKBOX_OFF` (857). The seal landing (`PUT_DOWN_GEMS`, 1204, at 0.4 s) and the purse counting down (`LOOT_WINDOW_COIN_SOUND`, 120, at 0.8 s) are beats of the motion, and play only with Animations on.

**Look and Feel page** (a Settings topic page under Core's root, CORE-R40, built when first opened so late registrations appear): one dropdown per registered slot of an enabled Module (and Core's), grouped by slot category, listing owned looks; under each, "N more in the Curio Shop", where N counts that slot's for-sale goods not owned; and one "Open the Curio Shop" button. It edits the same equipped setting as the shop's Use button.

## Settings

The Look and Feel page holds one option per slot (equipped good; default: the slot's default good). Slots in the "Announcements" and "Trackers" categories also appear beside what they change, on those topic pages (CORE-R42).

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
