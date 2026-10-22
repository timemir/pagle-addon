# Core: Fish varieties

> Status: In progress · Prefix `VAR` · Sources: the varieties kit (`pagle-varieties-kit.zip`: its SPEC, the catalogue page and the "Fish crests (earned)" and "Fish Journal · the varieties spread" boards of the Zone crests canvas, signed off by the dev on 22 Oct 2026), and the dev's grilling of it the same day; ADR 0001, 0010

Part of [Core](README.md). Every fish Pagle sizes comes in **ten varieties**: an everyday look, rarer colourings and one Epic specimen. Each Catch is one of them, chosen from its Catch ID. Collecting all ten of a fish earns that fish's **crest**; collecting all of them earns the Ledger's rarest title.

## Purpose and boundary

**Owns (Core):** which Catches have a variety, each Species' ten in their frozen order, the rarity odds, the variety of a Catch (decoded, never stored), Core's variety projection (which varieties each Species has been caught in), the 37 earned **fish crests** in Core's `core.crest` slot, the variety on the catch Nod (amending ANN-R13), and the variety art and lore.

**Owns (the Ledger, amending ledger.md):** the Journal's varieties spread, the moments for a new variety and a completed fish, the Ledger completion part, and the `complete.varieties` title. The Ledger keeps its own record of varieties caught in its own projection (it never reads Core's), so each side rebuilds on its own (ADR 0001).

**Doesn't own:** Simulated Size (LOG-R65–R68, unchanged, and independent of the variety), XP and Coins (varieties pay neither, SHOP-R1), the crest slot's other goods (SHOP-R25).

## Rules

### Which Catches, and the ten

- **VAR-R1** A Catch has a **variety** when it has a Simulated Size (LOG-R65) and its item is not a Legend. Trophies, Sub-collection items, Noise, Uncharted items, Legends and item `0` have none. An Uncharted Catch gains its variety when a release classifies it as a Species (as LOG-R96 for size).
- **VAR-R2** Each Species with a variety has exactly **ten**, in a fixed order, listed in `data/forever/varieties.toml` (Data). Position sets the **rarity**: 1–4 **Common**, 5–7 **Uncommon**, 8–9 **Rare**, 10 **Epic**. A variety's ID is `<speciesID>.<key>` (`6359.phoenix-fin`). The generator fails when a sized, non-Legend Species has no entry, an entry is for anything else, has other than ten keys, or a key repeats within a Species (DATA-R132, its `varieties` switch on from the varieties release).
- **VAR-R3** The **variety percentile** `v` of a Catch is LOG-R66's hash (FNV-1a 32-bit, then `fmix32`) over the Catch ID string with `#variety` appended, `v = h / 2^32`. The salt makes it independent of the size percentile: a big fish is no likelier to be a rare one. The variety is the first position `i` whose cumulative weight exceeds `v × 10000`, with the weights (per 10,000 Catches of a Species) 1750, 1750, 1750, 1750, 734, 733, 733, 350, 350, 100: Common 70%, Uncommon 22%, Rare 7%, Epic 1%.

  Test vectors (`h` after `fmix32`, over the Catch ID followed by `#variety`):

  | Catch ID | `h` | `v` | Position | Rarity |
  |---|---|---|---|---|
  | `Player-4395-0A1B2C3D-1791731747-0:1` | 4121951395 | 0.959717 | 9 | Rare |
  | `Player-4395-0A1B2C3D-1791731747-0:2` | 141524587 | 0.032951 | 1 | Common |
  | `Player-4395-0A1B2C3D-1791731762-1:1` | 4262029481 | 0.992331 | 10 | Epic |
  | `Player-1-00000001-1700000000-0:1` | 218561979 | 0.050888 | 1 | Common |

  A test draws 200,000 synthetic Catch IDs (sequential times, 2 items per Cast) and checks each position's share is within 0.3 percentage points of its weight (the kit measured 17.44–17.59, 7.29–7.39, 3.50–3.51 and 1.03) and that `v` and the size percentile `u` of the same Catch are uncorrelated (the kit measured 0.0005).
- **VAR-R4** Core computes the variety whenever it decodes a record, from the Catch ID and the current catalogue, as it does the size; it is never stored. Records carry it as `variety = { id, index, rarity }` (`rarity` one of `"common"`, `"uncommon"`, `"rare"`, `"epic"`), beside `size`. The catalogue carries each Species item's ten keys in order as `varieties` (`Pagle.GetItem(itemID).varieties`).
- **VAR-R5** The hash, the salt, the weights and each Species' order are **frozen once shipped** (as LOG-R68, ADR 0010): a Catch's variety never changes. The variety hash is its own frozen copy of LOG-R66's steps 1 and 2 (`ns.VarietyHash`), never a call into Size's, so a change to the Simulated Size (its rules version, its Reach) can never move a variety. A freeze spec (`spec/Pagle/logic/Variety_spec.lua`) pins the table above and, for each cumulative cut point, the two synthetic Catch IDs closest below and at or above it. A variety's name, description and art can change in any release; its key and position never do. A removed Species keeps its ten.

### Core's variety projection and the fish crests

- **VAR-R10** Core keeps a **variety projection** over the log (a Core projection, LOG-R78, bound at login step 1 after the wallet's and ahead of every Module's): for each Species, the set of positions caught, from every caught Cast's items that have a variety, keyed by the Species in the variety's ID (a folded item's Catches count for its Species). It is saved in `PagleDB.global.projections.varieties` with its `rulesVersion` (1) and rebuilt when the catalogue fingerprint changes (DATA-R71). The backend folds it too (`ns.BindCoreProjections`, LOG-R79).
- **VAR-R11** `Pagle.GetVarieties(speciesID)` returns the Species' ten, in order: `{ id, key, index, rarity, name, description, art }`, with `name` and `description` from lore (`ns.L`) and `art` the variety's texture and texel rectangle (UI: `{ texture, left, right, top, bottom }`, texture coordinates ready for `SetTexCoord`). It is the Species' static list: it never says which were caught, and showing an uncaught one's name, description or colours is the caller's choice (VAR-R14, VAR-R24 never do). `Pagle.GetVarietiesCaught(speciesID)` returns Core's caught positions as a fresh set `{ [index] = true }` each call, empty for a Species with none caught or without varieties and before the projection's first build has finished; while it rebuilds, it answers from the last stored state (LOG-R72). `Pagle.VARIETY_RARITIES` lists `{ key, name, weight }` in order.
- **VAR-R12** Core registers one **fish crest** per Species with a variety, in its `core.crest` slot: `core.crest.fish.<speciesID>`, **earned** (SHOP-R22), owned once all ten of that Species have been caught (Core's projection). The 37 at release are listed in Data. Its icon is the crest's own texture (`media/crests/fish/<speciesID>`), drawn like the zone crests (SHOP-R25). Its name is lore's "{fish} Crest" with `{fish}` the Species' item name as the client resolves it at runtime (DATA-R3: no game name ships), "Item {itemID}" until the client has it cached, after which Core refreshes the good's cached name (SHOP-R26); its description is lore's own and never names the fish.
- **VAR-R13** Amends SHOP-R22 and SHOP-R31 for Core's own earned goods: Core calls their `isEarned()` after its variety projection's `done` and after a live Catch that adds a variety; never mid-catch-up or mid-rebuild. The projection runs Core's internal hooks (`ns.OnVarietiesCaught(fn)`, logic/Wiring.lua) at exactly those points, every `done` (a catch-up's or a rebuild's, with or without a change) and each live Catch adding a position not caught before, so the fish crests refresh Core's goods from a hook. Their `earnedText` is a function, read each time the shop draws: "{n} of 10 varieties" (shown at the row's right, SHOP UI). An earned good of a Module keeps a plain string.
- **VAR-R14** In the Curio Shop, an unearned fish crest's stage shows the crest on the bookplate as any crest (SHOP UI), and its description card's foot shows ten dots in variety order, filled in the rarity's colour when caught and ringed in it when not, then "{n} of 10 {Species name} varieties. Still out there: {count and rarity of the uncaught, rarest last, as "2 Common, 1 Rare, 1 Epic"}." It never names an uncaught variety (VAR-R27). An earned one shows Use or In use as any owned crest.

### In the Ledger (amending ledger.md)

- **VAR-R20 (LED-R70)** Ledger completion adds **every Species with varieties** (done: all ten caught), from the Ledger's own projection, removed Species left out of both sides. 37 parts at release.
- **VAR-R21 (LED-R71)** The Angler page adds the part "Varieties" with "{fish complete} of {N}".
- **VAR-R22 (LED-R75)** Title `complete.varieties`, earned when every variety of every Species with varieties has been caught (a total above 0). Lore: "Keeper of Every Colour". It is meant to be the rarest title the Ledger gives.
- **VAR-R23 (LED-R142)** The fish spread's right page adds, under the stamps, "Varieties" with "{n} of 10" and a link "See all ten »" that opens the **varieties spread** (UI). A Species without varieties shows neither.
- **VAR-R24** The varieties spread: left page kicker the Species' name, title "Its colours", "{n} of 10 caught" in the hand, then the ten as rows in order, each with a dotted rule under it: the variety's art (76 × 38), its name, its rarity as a pill in the rarity's colour, and "{count} caught" in the hand at the right. An uncaught row shows the art as a dark silhouette, "Undiscovered" in ghost ink in place of its name, the pill outlined and no count. Clicking a row selects it (a pale band). Right page: the selected variety (the first caught, or position 1), kicker "A {rarity} colour" in the rarity's ink, then for a caught one its name, its art large (340 × 170), its description in italic and "First landed {date} in {zone}, by {character}. {count} caught."; for an uncaught one "Not yet discovered", the silhouette large, no description, and "Not landed yet. About one Catch in {round(10000 / weight)}." At the foot, over a rule, the fish crest small with its name and, in the hand, "All ten." when complete, else "{10 − n} to go."
- **VAR-R25** Moments (raised by the Ledger with the Cast, ANN-R10), for a variety caught for the first time:
  - Common or Uncommon: a stamp "New variety" on the Cast's toast; with no other moment, a `toast.low` headline "New variety · {name}".
  - Rare: a `toast` headline "Rare variety", the variety's name and its art in the bezel.
  - Epic: a `banner` "Epic variety", the variety's name, the art on the seal's ribbon.
  - The tenth of a Species: a `banner` "Every colour of {Species}", sealed with its fish crest (`seal = "crest"` showing the fish crest), plus the crest's "Earned" line.
  - The last of all: the `complete.varieties` title moment, as the other `complete.*` titles.
  None carries Coins or XP. These moments are where a variety's name, description and art are first shown (VAR-R27). Their rows and orders are LED-R97's, the art rides as the moment's `art` (announcements.md › Contracts), and a catch-up writes them up as LED-R94's "{n} varieties · {m} fish in every colour" (VAR-R91).
- **VAR-R26 (amends ANN-R13)** The catch Nod names its Catch's variety when that Catch has one: "{item name} · {variety name} · {band} · {length}", as "Firefin Snapper · Coral · Decent · 34.2 cm". The variety name is in its rarity's ink with a small gem in the rarity's colour before it; the medallion shows the variety's art cropped to the fish's head (as a toast bezel, UI) in place of the item icon, its ring tinted in the rarity's colour. A Rare or Epic Nod's strip gets one gleam across it as it enters (the rarity's colour); it stays silent and never interrupts (ANN-R13, ANN-R30). The rarity colours replace the toast style's ink only on the gem and the variety name (ANN-R80). A first catch of a variety is a moment of VAR-R25, which replaces the Nod as ANN-R13 says, so the Nod names only varieties already caught.
- **VAR-R27 Discovery.** Until a variety is first caught, nothing names it or shows its colours: the varieties spread (VAR-R24) and the shop (VAR-R14) show its rarity, its silhouette and its odds only. Its name, description and art are first shown in its own moment (VAR-R25).

## Data

- `data/forever/varieties.toml`: one table per Species, `[varieties.<speciesID>]` with `keys = [ten keys]` in frozen order (DATA-R131). Emitted into the catalogue on every item of the Species (a folded item too, as its typical length) as `varieties = { keys }`. Changing a key or its position fails the generator against the shipped list (`data/forever/varieties.lock`, DATA-R133), which `--lock` writes beside Hunts' `released.lock` from the 1.0 tag and which stays empty until then (DATA-R73).
- Lore, `data/lore/core.toml`: `[variety."<speciesID>.<key>"]` with `name` (28) and `description` (200), a new Core kind `core.variety` in `manifest.toml` listing all 370; `[good."core.crest.fish.<speciesID>"]` under `core.good`, each with its own `description` and the one name pattern every fish crest shares, `name = "{fish} Crest"` (VAR-R12), its manifest entry allowing the `{fish}` placeholder (DATA-R108, DATA-R134). Core reads it as any good's, `ns.L["good.core.crest.fish.<speciesID>.name"]`, and replaces `{fish}` with the item name. `data/lore/ledger.toml`: `[title."complete.varieties"]`. Lore limits add `description` 200 for `variety`.
- **The generator fails** when a variety's or a fish crest's text holds an area's name from `data/db2/areas.csv` (any area, zones and subzones, matched as whole words with its capitals) or a Species item's name (whole words, ignoring case, with and without a leading "Raw "), so no game name ships through them (DATA-R3, DATA-R135). The kit's names made from part of a game name (a lake's, a town's, a fish's own word, a game metal's) were renamed with their keys before release (#338); nothing had shipped.
- `addons/Pagle/data/VarietyArt.lua`: `ns.VARIETY_ATLASES` (the two atlas paths), `ns.VARIETY_ART_SIZE = { w = 192, h = 96, atlas = 2048 }` (texels) and `ns.VARIETY_ART[speciesID]`, the ten images in variety order as `{ atlas, x, y }` (the atlas's index, the top left corner in texels), from the kit's `atlas.json`; positions, not keys, so a renamed key keeps its art.
- Saved: `PagleDB.global.projections.varieties` (Core, VAR-R10), the projection machinery's stored values (`lastSeq`, `logId`, `fingerprint`, `rulesVersion`, LOG-R70) with `projection = { bySpecies = { [speciesID] = { [index] = true } } }`; `{}` in `ns.PAGLEDB_DEFAULTS`. The Ledger's projection gains `varieties = { [speciesID] = { [index] = { count, first = { entryId, date, zone, char } } } }`.
- **Gaffer Jack (6717) and Electropeller (6718)** are `junk`, not `questFish`: they are a goblin engineer's lost gadgets fished up for his quests, not fish. They have no Simulated Size, no varieties, no crest and no fish page; each has a Junk Museum plaque. 37 Species have varieties at release.

## UI

Drawn from the canvas boards (the kit's `canvas/`): the catalogue page's variety art, "Fish crests · all 39" (37 after the two gadgets left), "Curio Shop · fish crests earned and in progress", "The Angler · Ahi Crest pinned on Prestige VII" and "Fish Journal · the varieties spread". The kit's probe (`PagleArtVarieties/Varieties.lua`) is the layout reference, in UI units.

- **Variety art** is prerendered: each variety a 192 × 96 texel image, transparent around the fish, packed into two 2048 × 2048 atlases (`media/varieties/Varieties1`, `Varieties2`, BLP2 DXT5 with mips); `art` (VAR-R11) names the atlas and rectangle. The varieties spread draws a card's art 76 × 38 and the selected one 340 × 170; a toast bezel and the catch Nod's medallion crop it to the fish's head.
- **Silhouette**: an uncaught variety's art desaturated and tinted black at 28% (`SetDesaturated(true)`, `SetVertexColor(0, 0, 0, 0.28)`), a soft shadow of the fish.
- **Fish crests**: 256 × 256 textures as the zone crests (silver rim instead of gilt, the fish's water as the field, ten gilt stars at the foot), drawn and pinned exactly as SHOP-R25 and LED-R146 describe for crests.
- **Rarity colours**, the game's own quality colours: Common `#ffffff` (ink `#6a5a44` on parchment), Uncommon `#1eff00` (`#2f6a2a`), Rare `#0070dd` (`#23407a`), Epic `#a335ee` (`#7a2f8a`). On parchment Pagle uses the darker ink of each.

## Edge cases

- **VAR-R90 A release reclassifies an item.** A Catch that becomes a Species gains its variety; one that stops being one loses it. Both projections rebuild with the fingerprint (DATA-R71); a crest once earned stays owned (SHOP-R26 never prunes an owned good).
- **VAR-R91 Ledger disabled.** Core still tracks varieties and still awards crests; the Ledger catches up on its own record when enabled (LOG-R72) and raises a Write-up, not moments (ANN-R60).
- **VAR-R92 A stack of fish in one loot slot.** One Catch, one variety, whatever its quantity (as size, LOG-R65).

## Tunables

| Name | Value | Rule |
|---|---|---|
| Weights per 10,000 | 1750 ×4, 734, 733, 733, 350 ×2, 100 (frozen) | VAR-R3 |
| Salt | `#variety` (frozen) | VAR-R3 |
| Varieties per Species | 10 (frozen) | VAR-R2 |
| Variety art | 192 × 96 texels, 2 atlases of 2048 × 2048 | UI |

## Decisions

Settled in the dev's grilling of the kit (22 Oct 2026):

1. **Gaffer Jack and Electropeller** are junk, not fish (Data): their quests call them a dropped box of gaffer jacks and a lost bag of electropellers.
2. **Art** ships prerendered (UI), about 14 MB.
3. **The catch Nod** names the variety and shows its rarity (VAR-R26).
4. **Discovery**: an uncaught variety is never named or shown in colour (VAR-R27).
5. **No game names** in variety or crest lore, checked by the generator (Data); a fish crest's name is filled in at runtime (VAR-R12).
