# Core: Pagle Coins and the Curio Shop

> Status: Done · Milestones: M2 (wallet: earned totals, balance, Coins stamps, the balance in the compartment menu), M4 (Curio Shop, Look and Feel page, the first goods) · Sources: [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Prototype the Curio Shop](https://github.com/timemir/wow-fish/issues/30#issuecomment-6125718197), [Prototype the Tackle Board](https://github.com/timemir/wow-fish/issues/29#issuecomment-6126015781), [Prototype the Fish Journal](https://github.com/timemir/wow-fish/issues/12#issuecomment-6112909660), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652), [Decide the lore pipeline](https://github.com/timemir/wow-fish/issues/34#issuecomment-6129762441); ADR 0001, 0003, 0007, 0009. Prototype: `prototypes/curio-shop/` (variant B)

Part of [Core](README.md). Core holds the Angler's **Pagle Coins** and runs the **Curio Shop** (ADR 0009).

## Purpose and boundary

**Owns:** the wallet (earned totals by source, spent total, balance), the goods registry, ownership and equipped looks, purchase entries, the Curio crate, the Curio Shop window, the Look and Feel settings page, and Core's own goods (toast styles, sound sets, bookplate crests).

**Doesn't own:** what a Module pays Coins for or how much (each Module's spec), the looks a Module's goods apply to (each Module draws its own views), or Ledger level rewards (the Ledger decides when a binding is earned).

## Rules

### Earning

- **SHOP-R1** Coins reward achievements only, never raw volume. Core itself pays nothing: no Coins for Casts or Catches. Stats and QoL pay nothing.
- **SHOP-R2** A paying Module keeps its own **lifetime Coins earned** in its projection (ADR 0004) and reports it with `M:ReportCoinsEarned(total)`: from its projection's `done` after every catch-up or rebuild (even when unchanged, so a lost `PagleDB` refills), and after each live entry that changes it. It never reports mid-rebuild.
- **SHOP-R3** Core stores the last total each Module reported in `PagleDB.global.coins.earned[<def.name>]`. A Module that is disabled or uninstalled keeps its last total, so nothing it paid is lost. If `PagleDB` itself is lost, a disabled Module's total is gone until it is enabled and reports again. The totals belong to the log's `logId` (`PagleDB.global.coins.logId`): when `PagleLog.logId` differs from it (a new log, LOG-R18), Core empties them at `ADDON_LOADED` and takes the new `logId`, so a new log never inherits the old one's totals; each Module's report after its rebuild fills them in again (as AXP-R3 does for Activity XP, [#278](https://github.com/timemir/wow-fish/issues/278)).
- **SHOP-R4** Disabling a Module never lowers what it paid. Only a rebalance or data fix can recount a Module's total lower; then `earned` follows the new report, but the balance never goes below 0 (SHOP-R12) and nothing bought is taken back.
- **SHOP-R5** Coins show as a "+N" stamp on the Announcement the moment already earns (`coins` on the moment, ANN-R23) and as one Session summary line ("Pagle Coins +45"). Earning Coins never makes an Announcement of its own. Coins earned in history a Module catches up on or first builds from appear only as a line in its Write-up section, written by the Module (ANN-R60).

### Spending

- **SHOP-R10** A purchase appends a purchase entry (`U1`, LOG-R39) with the good's ID and the price paid. A later price change never moves a balance, and purchases are never revoked.
- **SHOP-R11** Core keeps `spent` and the set of purchased good IDs as a Core projection over the log (LOG-R78). Only the first `U1` for a good counts; any later one for the same good is ignored. A Curio crate's `U1` (good `core.crate`) is the exception: every one counts (SHOP-R50).
- **SHOP-R12** **Balance** = Σ earned − spent, shown as **0** when that is negative. While it is negative ("held"), the shop shows one quiet line: "Your balance is 0 while Pagle re-counts earlier Coins. New Coins fill that in first." It never mentions debt or a negative number.
- **SHOP-R13** **Buy** is enabled only when the good is for sale (or an earned good past its fallback date, SHOP-R28), not owned, its Module is enabled, the balance covers the price, and no projection (Core's or any Module's) is updating. Each purchase is one good and one confirmation.

### Goods

- **SHOP-R20** A **good** is a look for one of Pagle's own views, in one **slot**. Goods never carry meaning: titles, Fly Box flies, stars, Legends, Prestige and set emblems are never goods. Words drawn into a good's art ("WANTED" on Bounty Poster, "No.7" on Canvas Field Pad, "FLIES · HOOKS" on Tackle Tin, "the Long Haul" on Scrimshaw Panel, "NO.0042 · PAID" on Goblin Ticker, the I–V on Five-Set Seal) are decoration, part of the texture, not strings: they are outside CORE-R8, never in `ns.L`, and stay English in every locale.
- **SHOP-R21** Modules register their own slots and goods with `M:RegisterSlot` and `M:RegisterGood`, at any time after `RegisterModule`; Core registers its own. Slot and good IDs are `<def.name lowercased>.<name>` (`core.` for Core's), match `[%w_.]+`, and never change once shipped.
- **SHOP-R22** Every good is exactly one of:
  - **default**: free and owned by everyone; each slot has exactly one
  - **for sale**: price tier 1 to 5 (150, 400, 900, 2,000 or 5,000 Coins)
  - **earned**: not for sale (until a fallback date, if it has one: SHOP-R28); owned when its Module says so (`isEarned()`), with an `earnedText` saying how: a string ("Angler Level 30"), or a function the shop calls each time it draws the good while it isn't owned, returning the row's tag and, optionally, the stage's note ("Expert · 88%", "Earned when … Next: …"). An earned good may also have `progress()`, which the shop calls each time it draws the good on the stage while it isn't owned: a list of dots `{ color = { r, g, b }, filled = boolean }`, drawn on the stage (UI). Neither function's result is ever cached, and Core never calls either to decide ownership (SHOP-R30); one that raises is reported and its texts or dots are left out, and so is a dot without a colour of three numbers.
  - **crate only**: never for sale and never earned; owned when a Curio crate gives it (SHOP-R50). Only Core registers these, at most two in all (Tunables).
- **SHOP-R23** Registration raises a Lua error and ignores the call for: a duplicate ID, an ID without the Module's prefix, an unknown slot, a slot registered by a different Module (or by Core, for a Module, except an earned good in a Core slot registered with `openToEarned = true`: `core.toaststyle`, `core.soundset` and `core.crest`, SHOP-R25), a second default in a slot, a good with more than one of `default` / `tier` / `isEarned` / `crate`, or none of them, a `crate` good from a Module, a `fallbackTier` or `fallbackFrom` on a good that isn't earned, or one without the other (SHOP-R28), a `progress` on a good that isn't earned, a slot's `groups` that aren't a list of `{ key, name }` with distinct keys matching `[%w_]+` and non-empty names, and a good's `group` that isn't one of its slot's keys (SHOP-R27). At `ModulesChanged`, a slot with no default is reported through `geterrorhandler()`, and its first registered good acts as the default. Only `default = true` marks a default; `default` is `true` or `false`, and anything else is a mistake.
- **SHOP-R24** Stock never rotates and nothing is limited-time: every good registered is always in the shop, but for the crest slot's earned crests, which the shop never lists (SHOP-R25).
- **SHOP-R25** Core's own slots and goods, at M4 (tiers are tunable):

  | Slot | Goods |
  |---|---|
  | Toast style (`core.toaststyle`, `openToEarned`) | `core.toaststyle.page` (default), `core.toaststyle.ripple` (tier 1), `core.toaststyle.lanternglow` (tier 2); the Curio Shop expansion's: tier 1 `core.toaststyle.ship`, `core.toaststyle.birch`, `core.toaststyle.tidepool`; tier 2 `core.toaststyle.chart`, `core.toaststyle.frost`, `core.toaststyle.goblin`; tier 3 `core.toaststyle.kelp`, `core.toaststyle.moon`, `core.toaststyle.leaf`, `core.toaststyle.bottle`; tier 4 `core.toaststyle.rune`; tier 5 `core.toaststyle.folio`. The Curio Shop's second round's: tier 5 `core.toaststyle.storm`; earned by Core `core.toaststyle.sonar` (SHOP-R29); crate only `core.toaststyle.foil` (SHOP-R50). Earned, registered by their Modules: `ledger.toaststyle.legend`, `ledger.toaststyle.prestige` (LED-R117), `tackleboard.toaststyle.ember` (TKB-R126); the second round's `ledger.toaststyle.glass`, `ledger.toaststyle.deep`, `ledger.toaststyle.koi`, `ledger.toaststyle.trophy`, `ledger.toaststyle.slate`, `ledger.toaststyle.ice`, `ledger.toaststyle.stitch` (LED-R118) |
  | Sound set (`core.soundset`, `openToEarned`) | `core.soundset.driftwood` (default), `core.soundset.gilded` (tier 2); the Curio Shop expansion's: tier 1 `core.soundset.rain`, `core.soundset.marimba`, `core.soundset.shipbell`; tier 2 `core.soundset.kalimba`, `core.soundset.musicbox`, `core.soundset.glass`, `core.soundset.steelpan`, `core.soundset.dulcimer`; tier 3 `core.soundset.frost`, `core.soundset.harp`, `core.soundset.gizmo`; tier 4 `core.soundset.wardrums`. Earned, registered by their Modules: `ledger.soundset.concertina`, `ledger.soundset.choir` (LED-R117), `hunts.soundset.nightwatch` (HNT-R123) |
  | Crests (`core.crest`, `openToEarned`, `hideEarned`) | `core.crest.plain` (default), then Core's 37 fish crests, `core.crest.fish.<speciesID>` (earned, by Species ID, [varieties.md](varieties.md) VAR-R12). The zone crests in it are the Ledger's earned goods, `ledger.crest.<key>` (LED-R113); no crest is for sale yet. The shop lists Plain and the crests for sale only, never an earned crest |

  Every good's name and description is lore, read from `data/lore/core.toml` through `ns.L`; the working names (Timber, Ripple, Lantern Glow, Driftwood, Gilded, Plain) were its first drafts, and the 1.0 sign-off ([#264](https://github.com/timemir/wow-fish/issues/264)) renamed Timber to Torn Page and its ID from `core.toaststyle.timber` to `core.toaststyle.page`.
  *Lands with ADR 0015 (Core's binding slot, `core.binding`):* Core sells the second round's Shagreen and Bone there, `core.binding.shagreenbone`, at tier 4 (also in the Curio crate, SHOP-R50), and the Ledger's nine second-round bindings, `ledger.binding.<key>` (LED-R110, LED-R118), are earned goods registered into it. Its name and description are Core's lore, `good.core.binding.shagreenbone`.
  The second round's ten toast styles (Storm Front, Sonar Scope, Prize Foil and the Ledger's seven) are composed styles (ANN-R82).
  Core registers its toast styles and sound sets in the table's order, which is the shop's (SHOP-R21); neither slot has groups (SHOP-R27), so the Modules' earned goods list after Core's, as they register. An earned toast style or sound set a Module registers is drawn and played by Core like Core's own (ANN-R70, ANN-R80, ANN-R81, ANN-R82): Core ships its art and sounds, keyed by the good's ID, and the slot's `preview` draws it on the stage (a sample toast, or ▶ Toast / ▶ Banner / ▶ Legend); the Module decides only when it is earned, with `isEarned()` and an `earnedText` (SHOP-R22: a string, or for the Ledger's second-round styles a function giving its count, LED-R118), and has no `progress` or `group`. Its name and description are the Module's lore. With its Module off it is put away (SHOP-R35) and the slot falls back to its default (SHOP-R32).
  The crest is the Angler's emblem; the Ledger draws it on the Journal bookplate. Its slot, "Crests" in the "Crests" category, is shown whatever Modules are enabled. It has two groups (SHOP-R27), "Zone crests" (`zone`) then "Fish crests" (`fish`), for the zone crests and the fish crests to name; a crest naming neither, Plain among them, lists first.
  The crest slot is registered with `hideEarned = true` (Core's slots only, as `openToEarned`): the shop lists only the crests you can buy, and Plain. Its earned crests, the zone crests and the fish crests, are never listed or counted in its owned count, never selected (`Pagle.OpenShop` on one selects nothing, SHOP-R40) and never put away (SHOP-R35), so their `earnedText` and `progress` are never drawn there and their groups' headers never show. They stay earned goods: earned and owned as before (SHOP-R22, SHOP-R30), equipped from Look and Feel's Crests dropdown (SET-R51), named by the Ledger's Zone Master and Every colour banners (LED-R97, VAR-R25); an equipped one stays equipped and the Journal bookplate draws it (LED-R112).
  Each crest but Plain is a zone's, earned when that zone reaches Master in the Fish Journal (LED-R113, LED-R114), or a fish's, earned when all ten of its varieties are caught (VAR-R12): a zone's a gilt-and-enamel heater shield with a landmark of that zone over the same barry-wavy water at its foot, a fish's the fish on its water with a silver rim and ten gilt stars, original art (no faction or game crest). Its icon is its owner's texture (the Ledger's, `Interface\AddOns\Pagle_Ledger\media\crests\{key}`; Plain's and the fish crests' are Core's, `Interface\AddOns\Pagle\media\crests\plain` and `…\crests\fish\{speciesID}`), each 256 × 256, the shield 120:140 at its full height, centred, transparent around it, and every good in the slot is drawn as the shield wherever a crest's icon shows: the shop's row and bill (in place of the medallion, UI), the stage's bookplate (the slot's `preview`, which draws any crest it lists that has no preview of its own) and the Journal bookplate (LED-R146); Core's slot dropdown lists crests by name only (SET-R51). Plain's icon is the same shield as a dashed gilt outline, for the shop; the Journal draws nothing for Plain (LED-R112).
- **SHOP-R26** Core caches every registered good in `PagleDB.global.goods`: name, slot, slot label and category, Module, icon, `default`, tier, `crate`, fallback tier and date, description and, for earned goods, the `isEarned()` result as of the last registration or `RefreshGoods` (SHOP-R31). The cache is never pruned for a good that is owned.
- **SHOP-R27** A slot may declare ordered **groups** at registration, `groups = { { key, name }, … }`, `name` interface text, and a good of it may name one in `group`. The shop lists a grouped slot's goods with no group first, then each group's under a header with its name, in the slot's order, each group's goods in registration order (UI); a header with none of its goods left by the search, filter or chip isn't shown. A slot's groups are fixed when it registers, so a good can only name a group already there (SHOP-R23). A slot without groups lists its goods in registration order, as before. Groups order the list only: owned counts, filters and ownership ignore them. In a slot whose earned goods the shop hides (`hideEarned`, SHOP-R25), a group holding only earned goods never heads a row.
- **SHOP-R28** **Fallback price.** An earned good may carry `fallbackTier` and `fallbackFrom` (a server time, Unix seconds). From `fallbackFrom` on, while it isn't owned, it can also be bought at that tier's price: the shop shows its earned tag and a price tag both, and the stage's note ends "Or buy it for N". Buying appends `U1` like any purchase (SHOP-R10), so the good is owned whatever its Module says; earning it later changes nothing. Only the second round's earned goods have one (the Ledger's toast styles and bindings of LED-R118, and Sonar Scope, SHOP-R29): fallback tier 5, from 90 days after the release that ships them. Each owner's `logic/` holds that release's server time as a constant, `nil` until the release sets it; while it is `nil`, its goods register with neither field, and so have no fallback yet. An earned good from before the second round never gets one. A fallback never goes off sale again, so nothing is limited-time (SHOP-R24).
- **SHOP-R29** **Sonar Scope** (`core.toaststyle.sonar`) is Core's one earned good, `earnedText` "Link the companion": its `isEarned()` is true once the wallet projection has applied a Companion entry (`K1`, LOG-R37), the mark that the companion's data addon passed its signature check ([pushed-content.md](pushed-content.md), PUSH-R13). Core refreshes it right after appending `K1` and from the wallet projection's `done`. Unlinking the companion later doesn't take it back.

### The Curio crate

- **SHOP-R50** The **Curio crate** is sold on its own row at the very top of the shop's list, above every category's slots, under the label "Curio crate", at tier 4's price (2,000 Coins, Tunables). It belongs to no slot or category: it isn't a good (SHOP-R20), it is never owned, equipped or put away, and it stays at the top whichever category chip is on. Buying one appends `U1|<header>|core.crate|<price>` and opens it at once: it gives one good of the **crate pool** (Tunables: `core.toaststyle.foil`, `core.toaststyle.storm`, `core.binding.shagreenbone`) that the Angler doesn't own yet. It never gives a good already owned, so no crate is wasted. A good given by a crate is owned as a purchase is (SHOP-R30), never revoked, and shows in the shop as "From a crate".
- **SHOP-R51** **The draw is the log's.** The wallet projection works out each crate from the log, so every rebuild gives the same goods (ADR 0004): the **candidates** are the pool goods not owned by an earlier `U1` or crate, in pool order; each has a weight (Tunables: a crate-only good 1, any other 2); `u` is LOG-R66's frozen hash of the crate `U1`'s entry ID (LOG-R13) divided by 2^32; the crate gives the first candidate whose running share of the total weight is above `u`. Whether a good's Module is enabled doesn't change the candidates; a good of a disabled Module goes to "Put away" (SHOP-R35).
- **SHOP-R52** **Pity.** When the last 7 crates in a row gave no crate-only good and one is still unowned, the next crate's candidates are the unowned crate-only goods alone, so a crate-only good comes by the 8th crate at the latest. With today's pool a crate never repeats, so all three are owned by the third crate; the count matters once the pool grows.
- **SHOP-R53** **Frozen once shipped.** The hash, the order of the pool and its weights never change for crates already in the log (as LOG-R68): a good joins the pool only at the end, with the server time of the release that adds it, and is a candidate only for crates bought from then on. At most two goods are ever crate only.
- **SHOP-R54** **Buying a crate.** Buy is enabled when a pool good is still unowned and SHOP-R13's other conditions hold. The stage shows the crate, the pool goods with their chance of coming next as a percent (owned ones struck through), and "A crate-only look within N more crates" from the pity count. The bill of sale reads "Open a Curio crate?" with the price and the line "One look you don't own yet, by chance; the chances are on the crate." With every pool good owned, the row reads "Empty: you have it all" and Buy is gone. A crate is opened from the bill only: one crate, one confirmation, never several at once.
- **SHOP-R55** **Opening.** The crate's good shows on the stage the moment it is bought, selected, with Use; "Use it now" on the bill equips it. No Announcement follows (as SHOP-R10's purchases).

### Owning and equipping

- **SHOP-R30** `Pagle.IsOwned(goodID)` is true for defaults of registered slots, purchased goods, and earned goods whose cached `isEarned()` result is true. Core never calls `isEarned()` on an ownership check; it reads the cache, whether or not the Module is enabled.
- **SHOP-R31** Core calls a Module's `isEarned()` functions only when the good is registered and when the Module calls `M:RefreshGoods()`. A Module calls it after a live entry that could change an earned good, and from its projection's `done`; never mid-catch-up or mid-rebuild, so looks don't flicker.
- **SHOP-R32** Each slot has one **equipped** good, stored as a Core setting (`PagleDB.profile.appearance[slot]`). `Pagle.SetEquipped(slot, goodID)` accepts only an owned good of that slot. `Pagle.GetEquipped(slot)` returns the stored good if it is owned and registered, and the slot's default otherwise. That fallback happens on reading only: the stored choice is never cleared, so it comes back when its Module does.
- **SHOP-R33** `AppearanceChanged(slot, goodID)` fires whenever the result of `GetEquipped(slot)` changes, whatever the reason (a `SetEquipped`, a Module enabled or disabled, an earned good lost or regained). Each Module redraws its own views from `Pagle.GetEquipped`; Core redraws its frames and picks sounds from its own slots.
- **SHOP-R34** While the wallet projection is updating, `IsOwned` answers from the owned set saved before the update started, so looks don't flicker to defaults.
- **SHOP-R35** A disabled Module's goods for sale leave the shop. Its purchased and earned goods stay owned and are listed under "Put away: Module off", from the cache, but for an earned good in a slot whose earned goods the shop hides (a zone crest, SHOP-R25). Its defaults are neither listed nor counted. Its slots don't appear in Settings.

### Entry points

- **SHOP-R40** The Curio Shop opens from the compartment menu entry "Curio Shop" (CORE-R50), from `/pagle shop` (a toggle), from `Pagle.OpenShop(goodID?)`, and from the Look and Feel page's "Open the Curio Shop" button. `OpenShop` selects that good; an unknown ID, or an earned crest the shop doesn't list (SHOP-R25), selects nothing; a good of a disabled Module selects it in "Put away" if owned, otherwise nothing. Esc closes it.
- **SHOP-R41** While restricted, every entry point prints "Pagle: the Curio Shop opens after combat." instead. At `RestrictionChanged(true)`, an open shop and its bill of sale (the Buy confirmation) close; nothing is queued.

## Data

| Key | Contents |
|---|---|
| `PagleDB.global.coins.earned` | `{ [def.name] = lifetimeTotal }`, the last report per Module (SHOP-R3) |
| `PagleDB.global.coins.logId` | the `PagleLog.logId` the totals belong to (SHOP-R3) |
| `PagleDB.global.goods` | `{ [goodID] = { name, slot, slotLabel, category, module, icon, default, tier, description, earned } }` (SHOP-R26) |
| `PagleDB.global.projections.wallet` | the wallet projection: `spent`, `purchased = { [goodID] = true }` (SHOP-R11), `crates = { goodID, … }` in log order and `dry` (crates in a row without a crate-only good, SHOP-R50–R52), `companion` (a `K1` applied, SHOP-R29) |
| `PagleDB.profile.appearance` | `{ [slot] = goodID }`, equipped looks (SHOP-R32) |
| Catch log | `U1|<header>|<good>|<price>` per purchase and per crate (good `core.crate`), and Core's one `K1` ([catch-log.md](catch-log.md#entry-formats)) |

## Contracts

```lua
---@class PagleSlot
---@field id string              -- "core.toaststyle", "hunts.notebookcover", "stats.trackerframe"
---@field label string           -- "Toast style"
---@field category "Announcements"|"Crests"|"Fish Journal"|"Hunts"|"Trackers"
---@field openToEarned? boolean  -- Core's slots only: any Module may add earned goods to it (SHOP-R23)
---@field hideEarned? boolean    -- Core's slots only: the shop lists none of its earned goods; Look and Feel equips them (SHOP-R25)
---@field preview? fun(stage: Frame, good: PagleGood) -- Core's slots only: draws a good of the slot with no preview of its own
---@field groups? { key: string, name: string }[] -- SHOP-R27: in list order; key [%w_]+, name interface text

---@class PagleGood
---@field id string
---@field slot string
---@field name string
---@field description? string
---@field icon? integer|string
---@field default? boolean        -- SHOP-R22
---@field tier? 1|2|3|4|5         -- for sale
---@field isEarned? fun(): boolean -- earned
---@field crate? boolean          -- Core's only: given by a Curio crate alone (SHOP-R22, SHOP-R50)
---@field fallbackTier? 1|2|3|4|5 -- earned only, with fallbackFrom (SHOP-R28)
---@field fallbackFrom? integer    -- server time from which an earned good is also for sale (SHOP-R28)
---@field earnedText? string|fun(): string?, string? -- earned: "Angler Level 30", or the row's tag and the stage's note
---@field progress? fun(): { color: number[], filled: boolean }[] -- earned: the stage's dots while not owned (SHOP-R22)
---@field group? string           -- one of its slot's group keys (SHOP-R27)
---@field preview fun(stage: Frame)   -- draws the look on the shop's preview stage

---@class Balance
---@field balance integer         -- never negative
---@field held boolean            -- earned < spent (SHOP-R12)
---@field earned { [string]: integer }   -- by def.name
```

| Call / event | Rules |
|---|---|
| `M:ReportCoinsEarned(total)` | SHOP-R2 |
| `M:RegisterSlot(slot)`, `M:RegisterGood(good)` | SHOP-R21–R23, SHOP-R27, SHOP-R28 |
| `M:RefreshGoods()` | SHOP-R31 |
| `Pagle.GetBalance()` | SHOP-R12 |
| `Pagle.IsOwned(goodID)`, `Pagle.GetEquipped(slot)`, `Pagle.SetEquipped(slot, goodID)` | SHOP-R30–R34 |
| `Pagle.GetGood(goodID)` | SHOP-R26: a read-only copy of the cached `{ name, slot, icon, module, description, isDefault }`, whether or not the good's Module is enabled, or `nil` for a good never registered. `isDefault` is true for its slot's default (SHOP-R22), or the good standing in for one (SHOP-R23), so a view can draw a default as no look at all |
| `Pagle.OpenShop(goodID?)` | SHOP-R40, SHOP-R41; `OpenShop("core.crate")` selects the crate's row |
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
| Hunts: a Standing Hunt completed / each further tier / set finished | 30 / 15 / 100 |
| Hunts: a Hunt Event Hunt's tier 1 / each later tier / a completed run (paid again in every run) | 15 / 10 / 50 |

Goods by Module: Ledger registers Journal bindings (eighteen for sale; the six level bindings and five more earned, the Iridescent Scale with the `complete.varieties` title, LED-R110, LED-R116), the fifty-three zone crests (earned, in Core's crest slot, not listed in the shop, SHOP-R25), nine toast styles and two sound sets (earned, in Core's slots, LED-R117, LED-R118), and, with ADR 0015, the second round's nine earned bindings into Core's binding slot (LED-R118); Hunts registers notebook covers (three earned), frames for its tracker (one earned) and a sound set (earned, in Core's slot, HNT-R122, HNT-R123); Stats registers frames for its tracker; the Tackle Board registers frames for its tracker (one earned) and a toast style (earned, in Core's slot, TKB-R126).

## UI

One window, "Curio Shop" (the layout of the prototype's variant B), drawn with the shop art kit as a travelling merchant's sample case: brown leather with stitching, brass corners and a handle, the "Curio Shop" trade label on its lid. It is 980 × 640 at UI scale 1, centred, movable by its leather, with a brass close button at the top right. It opens over every window already open, Pagle's and the game's: it lies in the HIGH strata, as the other Pagle windows do, is raised over them each time it is opened, and comes back to the front when clicked; its bill of sale and the medallion flying to the purse lie above it, in DIALOG. On a screen too small for it and its handle (at a large UI scale UIParent is only 668 units tall), it shrinks to fit, keeping 24 units clear round it; it never grows, and it fits again when the UI scale or the game window's size changes. Its art is three textures under `media/shop/` (BLP, DXT5, each with its mipmaps; 6 MB loaded in all), their sprites listed in `data/ShopArt.lua`. Its words are set in the bundled OFL fonts (IM Fell English and its italic for print, Caveat for handwriting, Marcellus for gilt, in `media/fonts/`), in capitals where the kit sets small caps, since the client has none. They pass CORE-R9, and `/pagle dev glyphs` shows each face.

- **The purse, on the case's top band:** the brass coin, "PAGLE COINS" over the balance in gilt, then income by source as a stacked bar (Tackle Board / Ledger / Hunts, each in its own colour), with each Module's lifetime total in a handwritten legend under it. Hovering a segment shows a dark tooltip edged in gilt, in the book's voice. A Module that is off (CORE-R41) has its segment faded and greyed and its legend entry greyed and struck through in red ink, but its total still counts. There is no "Spent" anywhere. The held line (SHOP-R12) shows under the legend, the bar moving up to make room.
- **Left, the green velvet tray, the list:** a paper search slip, "Find a look…" (matches names); the filter as pills (All / Owned / Not owned / Can afford), the one on in gilt; category chips as leather tabs in the order Announcements, Crests, Fish Journal, Hunts, Trackers, each shown only if a registered slot uses it. The Curio crate's row comes first, above every slot, whichever chip is on (SHOP-R50): the crate's medallion, "Curio crate" and its price tag, or "Empty: you have it all" (SHOP-R54). Goods are grouped by slot (Core's slots first, then by Module order), each slot's name in capitals with a gilt rule and its owned count ("1 of 3"). A grouped slot (SHOP-R27) heads each group with a header row: its name in the category chips' gilt capitals, at the medallions' inset, and a fainter gilt rule to the row's end. A header is not a good: it takes no click and is never selected, and whatever points at the list's goods (the First look's note) passes over it. Each row shows the good's icon round in a brass medallion (a crest's shield instead, 30 × 35, SHOP-R25), its name and its state. The selected row sits on a gilt band. "Put away: Module off" is the last group, greyed, saying "Yours to keep". The list scrolls with the wheel and a slim brass scroll bar, shown only while the list overflows.
- **Right, the quilted lid, the stage:** a showcase card, whose dark well and the paper round and under it (390 × 190 in all, the 370 × 132 well centred at its top) are the selected good's `preview` stage: a sample toast with "Show on screen" for a toast style; ▶ Toast / ▶ Banner / ▶ Legend for a sound set; the bookplate for a crest (the crest's shield, 60 × 70, where the icon stood); the closed book for a binding or cover; a sample tracker for a tracker frame. A preview is clipped to the card. A good with no preview (its own or its Core slot's), or put away, shows its icon in a medallion in the well, greyed if put away. Under it, the description card holds the good's name in handwriting, its slot and owning Module in red capitals, its description in italic, its notes, then Buy or Use with its tags at the foot. An earned good not yet owned with `progress` (SHOP-R22) shows its dots between its description and its notes, so its note (the `earnedText` function's second text) reads under them: a centred row of round dots 10 units across, 8 apart, each with a dark hairline edge, filled in its colour when `filled` and ringed in it (the paper showing inside) when not.
- **States on a row and the stage:**
  - for sale: a paper price tag on a string, the price with a coin; "Buy for N" with a coin on a leather button
  - can't afford: the price in red on its tag, Buy dimmed and disabled, "N more Coins" in red beside it
  - owned: "Owned" on the row; "OWNED" and a **Use** button on the stage
  - equipped: "IN USE" after a wax dot on the row, and on the stage
  - default: "default"
  - earned and not yet earned: its `earnedText` on the row (a function's first text); on the stage, a function's second text, or the string, then "a {Module} reward, not for sale" ("a Ledger reward, not for sale")
- **Buy:** a bill of sale over the case, which dims: a sheet of paper with a torn top, "CURIO SHOP", "Buy {name}?" in handwriting, the good's medallion, a dashed rule, "Price" with the price and a coin, "Pagle Coins left after" with N, "Looks are yours for good.", a hand-ticked **"Use it now"** checkbox (on by default), and Buy / Cancel. Esc is Cancel there and leaves the shop open; any other key goes on to the game. No Announcement follows.

### Motion and sound

The case moves as the shop art kit's motion has it (`pagle-shop-kit` v2, its `MOTION.md`), played by Core's one `OnUpdate` (`adapter/Motion.lua`); `adapter/ShopMotion.lua` holds the shop's. With the **Animations** setting off (SET-R30), each change shows as it settles. A preview on the stage stands still (announcements.md › Motion).

| Moment | Motion | Settled |
|---|---|---|
| The bill of sale opens | The case dims (0.2 s); the bill drops in from 24 units up, fading in (0.3 s, overshooting a little). | 0.3 s |
| Cancel or Esc on the bill | The bill lifts 16 units and fades as the case brightens (0.25 s). | 0.25 s |
| A crate opens | Bought at the click, as a purchase. The bill lifts away (0.25 s); on the stage the crate's lid lifts (0.15–0.5 s, overshooting), straw puffs out, and the good's medallion rises from it to the middle of the well, growing from 34 to 64 units (0.5–1.1 s), then its row comes in as a purchase's does. | 1.6 s |
| A purchase | The good is bought at the click; the window then shows it in motion. Buy gives under the press (0.12 s). A wax seal is pressed onto the bill, low on its right, from 2.2x (0.1–0.55 s, overshooting). The good's medallion lifts off the bill and flies to its row, shrinking from 64 to 34 units (0.7–1.4 s); the bill lifts away behind it from 0.75 s. The purse counts down to the new balance (0.8–1.7 s) as its coin turns once (0.5 s). In the row, the price tag lifts away (1.4 s, 0.25 s), "IN USE" and its wax (or "Owned") come in, and the row glows warm once (0.8 s); the slot's old good's "IN USE" gives way to its new tag. The lid's Buy gives way to what follows (1.5 s, 0.35 s). Anything that redraws the window meanwhile, or its closing, settles it at once. | 2.2 s |
| Buy without enough Coins | A click on the dimmed Buy shakes "N more Coins": 6 units left and right three times, smaller each time (0.4 s). | 0.4 s |

The shop's sounds are the client's own sound kits (`PlaySound(id, "SFX")`), UI foley that is the same in every sound set (sound sets are the Announcements', ANN-R70); they follow the player's SFX volume and mute, and Pagle has no setting of its own for them (ANN-R73). The case opening and closing play `AUCTION_WINDOW_OPEN` (5274) and `AUCTION_WINDOW_CLOSE` (5275); Buy on the bill, once it buys, `IG_BACKPACK_COIN_OK` (865); a click on the dimmed Buy `IG_MAINMENU_OPTION_CHECKBOX_OFF` (857). The seal landing (`PUT_DOWN_GEMS`, 1204, at 0.4 s) and the purse counting down (`LOOT_WINDOW_COIN_SOUND`, 120, at 0.8 s) are beats of the motion, and play only with Animations on.

**Look and Feel page** (a Settings topic page under Core's root, CORE-R40, built when first opened so late registrations appear): one dropdown per registered slot of an enabled Module (and Core's), grouped by slot category, listing owned looks; under each, "N more in the Curio Shop", where N counts that slot's for-sale goods not owned; and one "Open the Curio Shop" button. It edits the same equipped setting as the shop's Use button.

## Settings

The Look and Feel page holds one option per slot (equipped good; default: the slot's default good). Slots in the "Announcements" and "Trackers" categories also appear beside what they change, on those topic pages (CORE-R42).

## Tunables

| Name | Value | Rules |
|---|---|---|
| Price tiers | 150 / 400 / 900 / 2,000 / 5,000 | SHOP-R22 |
| Core goods' tiers | as SHOP-R25 | SHOP-R25 |
| Fallback for the second round's earned goods | tier 5, 90 days after the release that ships them (its time `nil` until that release sets it) | SHOP-R28 |
| Curio crate: price / pool / weights / pity | tier 4 (2,000) / `core.toaststyle.foil`, `core.toaststyle.storm`, `core.binding.shagreenbone` / crate only 1, others 2 / 8 | SHOP-R50–R52 |
| Crate-only goods, at most | 2 | SHOP-R22, SHOP-R53 |
| Pacing target | first purchase in week 1; the base catalogue (tiers 1–3) in 6–12 months for a daily player; tiers 4–5 a long-term chase, 18 months or more | SHOP-R22 |
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
