# Core: The Morning Tide (the news sign)

> Status: Draft (art, motion and the dev command built; the news, Settings and looks for sale specified *from 1.6*, not built) · Prefix `SIGN` · Sources: the design brief "Pagle's news sign"; ADR 0019; the map, timemir/pagle-addon#650, and the dev's decisions on it (2026-11-08); pagle-backend's [#466](https://github.com/timemir/pagle-backend/issues/466) and its `in-game-views.md` news block (IGV-R60–R66)

Part of [Core](README.md). **The Morning Tide** is what players call the news sign; the spec and code keep "news sign" as its internal name. At login or `/reload` a sign drops in from the top of the screen with one piece of news about the Anglers the player follows, or a region headline: it overshoots, settles, hangs about 8 s and goes back up. It comes in six **looks**: plain wood, free and the default, and five that are Curio Shop goods. This file covers the sign itself, its art, motion and sounds, the dev command that shows it with sample news, and *from 1.6* when it drops and with what (SIGN-R14–R19), from the news the Companion brings in `Pagle_Following` ([anglers-in-game.md](anglers-in-game.md), VIEW-R40–R46). Its Settings are [settings.md](../settings.md)'s SET-R37, its looks for sale the Curio Shop's ([wallet-and-shop.md](wallet-and-shop.md), SHOP-R60–R62), and the full list the Fish Journal's ([ledger.md](../ledger.md), LED-R176–R179).

## Purpose and boundary

**Owns (Core):** the sign's frame, `PagleNewsSign`; its six looks, their art (`Pagle/media/sign`) and sounds (`Pagle/media/sign/sounds`); how a piece of news is laid out on it and worded; its timing, hover, clicks, drag and saved spot; `/pagle dev sign`; and *from 1.6* when it drops, which item it shows, the "+N more" count, and what is marked seen (SIGN-R14–R19).

**Doesn't own:** what the news is (pagle-backend's Feed and Monthly firsts, SOC-R31, LB-R80, delivered as IGV-R60–R66 say); reading the news block and keeping what was seen (VIEW-R40–R46); its Settings rows (SET-R37); which looks the Angler owns and the shop's previews (SHOP-R60–R62); the Fish Journal's news list it opens (LED-R176–R179).

## Rules

### The news (SIGN-R10–R13)

- **SIGN-R10** A piece of news is one of eight **kinds** about a followed Angler, in this order of rank: `first` (first in the region to land a fish), `legend`, `prestige`, `ledger` (completed the Ledger), `colour` (a rare variety), `hunt` (Hunt gold), `zone` (Zone Master) and `monster`; or the **region headline**, `region`, the region's first of a fish this month. When there is more news than the sign shows, it shows the highest-ranked and says how many more. *From 1.6,* the news is the news block's items (VIEW-R40): the eight kinds are the followed items, each about an Angler the player follows, and `region` is a region headline, about any Angler of the player's regions. Each kind has its own switch, the region headlines one more, and the sign one master switch (SET-R37). The rank decides only which item the sign shows (SIGN-R15); the Fish Journal lists them all by time (LED-R176).
- **SIGN-R11** The news names an Angler by the Angler's name, never a character's: the news line's `name` (IGV-R13), drawn as written (VIEW-R13).
- **SIGN-R12** The sign's words are its **kicker** (the kind, `SIGN_KICKER.<kind>`), its **headline** (`SIGN_HEAD.<kind>`, two lines at most), an optional **detail** line (the Legend, the variety and species `SIGN_DETAIL_COLOUR`, the Hunt, the Monster and its length `SIGN_DETAIL_MONSTER`, the Angler for `first` and `region`) and, when there's more, the **more line** (`SIGN_MORE`, counted). Every one goes through `ns.L`. They are set in the repo's faces: the kicker in IM Fell English SC, the headline in Marcellus, the detail in IM Fell English italic, the more line in Caveat SemiBold. Each look has a words box; the words are centred in it, above the more line where it sits on the board. Words that don't fit at their sizes, a long translation's or the pseudo-locale's, are set smaller together, at 0.9, 0.8 then 0.72 of them; a detail still wider than the box scrolls to and fro in it as a toast's does (ANN-R101); the more line is set smaller to fit its room, and cut there at the last. *From 1.6,* a variety the player hasn't caught yet is never named on the sign (VAR-R27): its detail is `SIGN_DETAIL_COLOUR_HIDDEN`, "{rarity} {species}" ("Epic Spotted Yellowtail"), with the rarity's name (`Pagle.VARIETY_RARITIES`) for the variety's (SIGN-R19).
- **SIGN-R13** Each kind has an **emblem** at the board's left, drawn in a slot 58 units across: the sign's laurel (`first`, `region`) and medal (`hunt`); a Legend's crest and the fish's item icon (`legend`); the Prestige emblem (`prestige`); the Ledger's book (`ledger`); the variety's fish (`colour`); the zone's crest from the Ledger (`zone`); the fish's crest with a measuring tape over it (`monster`). Each look frames the slot its own way. *From 1.6:* a variety the player hasn't caught is drawn as its dark silhouette, as the varieties spread draws it (VAR-R24, VAR-R27); the zone's crest is `Pagle_Ledger/media/crests/<key>` with the news line's `key`, and the laurel when the line has no key (a zone with no crest, LED-R113) or the Ledger is off, since then its crests aren't there; a Monster of a Species with no fish crest (Core has them for the Species with varieties, VAR-R12) has the laurel under its tape.

### When it drops (SIGN-R14–R19)

*From 1.6 (rule set pagle-2026j).* The dev's decisions on #650: one drop per login or `/reload`, with the best news since the news the player last saw, never in combat.

- **SIGN-R14** **One drop a session.** Once per UI session (a login or a `/reload`), the drop delay after the session's first `PLAYER_ENTERING_WORLD`, Core reads the news (`Pagle.GetNews()`, VIEW-R42) and decides:
  - nothing is read, and nothing drops or is marked, while the news isn't `ok` (VIEW-R42: `Pagle_Following` absent or expired, or a Companion that brings no news);
  - with no floor yet (SIGN-R18), it sets the floor, marks every item seen and drops nothing;
  - with "Show news at login" off, or Cozy mode on (ANN-R40: nothing pops up or plays), it drops nothing and marks every item seen (SIGN-R17);
  - otherwise, with at least one due item (SIGN-R15), it drops the sign (SIGN-R40) in the equipped look (SIGN-R57) with the pick's words (SIGN-R19) and its more line (SIGN-R16); with none, nothing drops and every item is marked seen.

  The decision is made once; a drop that waits for combat (SIGN-R40) keeps its words. Nothing else raises the sign but SIGN-R60's dev command and the Curio Shop's "Show on screen" (SHOP-R61).
- **SIGN-R15** **Due, and the pick.** An item is **due** when all of these hold at the decision:
  - it isn't seen (VIEW-R44);
  - its `time` is at or after the floor (SIGN-R18) and within the news age before `GetServerTime()`;
  - its switch is on (SET-R37): its kind's row for a followed item, Region headlines for a `region` one;
  - a `region` item's `time` falls in the current UTC month by `GetServerTime()`, so its "this month" is still true.

  The **pick** is the first due followed item in SIGN-R10's rank, then newest first, then in the block's order; with no due followed item, the newest due region headline. So news about an Angler the player follows always comes before a region headline.
- **SIGN-R16** **The more line** counts the due followed items other than the one shown: "+{n} more from your anglers" (`SIGN_MORE`), left out at 0. Region headlines aren't counted: they aren't the player's anglers'. The full list is a left click away (SIGN-R42).
- **SIGN-R17** **Marking seen.** When the sign drops (SIGN-R40, once the entrance starts, after any wait for combat), Core marks every item of the news block seen (VIEW-R44): the one shown, the ones counted, and the ones that weren't due, switched off or older than the floor alike. So turning a kind or the headlines on later never brings back what came while it was off, and the next login's sign has only what arrived since. When SIGN-R14 drops nothing, it marks them at the decision. A drop still waiting for combat to end when the session ends marks nothing, so the next login shows it. Showing the Fish Journal's news list marks what it lists (LED-R177).
- **SIGN-R18** **The floor.** `PagleDB.global.news.since` (VIEW-R44), a server time, is set to `GetServerTime()` at the first decision of SIGN-R14 that finds `ok` news and no floor, which is the first login with 1.6 and a news-aware Companion, and again each time "Show news at login" is turned on (SET-R37). Items timed before it are never due. So the first login after the sign is enabled shows nothing older than the moment it was enabled: never the 30-day backlog the block holds (IGV-R61). An item timed before the floor that arrives later (its Angler uploaded late) is left out too: that is the price of a floor that holds.
- **SIGN-R19** **Words from a news line.** Core words an item from its line (IGV Contracts' fields), for the sign and for the Fish Journal's list alike (`Pagle.NewsWords`, VIEW-R45):
  - the Angler: `name`; the region: `region` in capitals ("EU");
  - a Legend or a Species: `item`'s name as the client gives it (`C_Item.GetItemNameByID`; a Species by its Species ID, its representative item, DATA-R19), less a leading "Raw " on an enUS client as VAR-R12 strips it; a name the client hasn't loaded yet is asked for (`Item:CreateFromItemID(item):ContinueOnItemLoad`) and the drop waits for it up to the name wait, then shows `SIGN_ITEM_UNKNOWN` ("a fish") in its place;
  - a Prestige: `rank` as the bookplate writes it (I–X, then "Master Prestige {n}", LED-R146), a Master Prestige's headline its own string (`SIGN_HEAD_MASTER_PRESTIGE`, "{name} reached Master Prestige {n}"), since "Prestige Master Prestige 2" would say it twice;
  - a variety: `Pagle.GetVarieties(item)`'s entry whose key is `key`: its name and rarity, named only once the player has caught it (`Pagle.GetVarietiesCaught(item)`, VAR-R27, SIGN-R12);
  - a Hunt: `text`, the backend's enUS name (IGV-R60);
  - a zone: `C_Map.GetAreaInfo(zone)`, or "Zone {zone}" (`SIGN_ZONE_UNKNOWN`) when the client has none;
  - a length: `Pagle.FormatLength(length)` in the player's unit (LOG-R69).

### Where it hangs (SIGN-R20)

- **SIGN-R20** The sign is one frame, `PagleNewsSign`, on UIParent at a scale of 0.85, in the `HIGH` strata. Its top centre rests at its **spot**, saved as fractions of UIParent from its top left as the minimap icon's is (CORE-R53): `PagleDB.global.newsSign.point = { x, y }`, else 0.285 and 0.05. The Angler can drag it out of combat; the release saves the spot, and isn't a click.

### Art and sounds (SIGN-R30–R31)

- **SIGN-R30** The art is one shared atlas (`SignCommon`: glows, dots, sparkles, rings, puffs, the tentacle's discs and suckers, the drop, a pixel, the laurel, the medal, the tape) and one per look (`SignWood`, `SignScroll`, `SignLantern`, `SignKraken`, `SignAstro`, `SignCoral`), each a power-of-two BLP at 2 texels a unit, its sprites in `ns.ATLASES` (`data/NewsSignArt.lua`). Everything is drawn as upright sprites placed from the sign's top left each frame; only round sprites turn (the astrolabe's rings). A look's frames, textures and font strings are made once and drawn again on its next drop.
- **SIGN-R31** Each look plays its sounds at cues on its timeline (SIGN-R50–R56) with `PlaySoundFile(path, "SFX")`, Ogg Vorbis, mono, 44.1 kHz, from `Pagle/media/sign/sounds`. A cue more than 0.25 s late is skipped, so a hitch never stacks them. `PagleDB.global.newsSign.mute` mutes them; *from 1.6* its Setting is "Mute the sign" (SET-R37).

### A drop (SIGN-R40–R43)

- **SIGN-R40** The sign drops only when Pagle isn't restricted: a drop asked for in combat waits for it to end, and the last asked for wins. If combat starts while it shows, it goes up at once. *From 1.6,* it shares the screen with Core's letters (the letter service, ONB-R15–R17, such as the Prestige letter or the party letter of [#655](https://github.com/timemir/pagle-addon/issues/655)) one at a time: a drop asked for while a letter shows waits until no letter shows, then drops (a letter answered, or hidden by a restriction, ONB-R14); and a letter due while the sign shows waits until the sign has gone up (ONB-R17). Nor does it drop while the Field guide is open (ONB-R20), as a Module's letter doesn't (ONB-R17): it waits for `GuideClosed`, so the onboarding Letter's Open the letter, which opens the guide, never sends the sign down behind it, and its items are marked seen only once it drops (SIGN-R17). Whichever is due first shows first. At login that is usually the sign, at the drop delay (SIGN-R14), since a letter also waits for the login's held Announcements and cards (ONB-R10); the letter follows `LETTER_DELAY` after the sign has gone up. A drop waiting for a letter keeps its words, as one waiting for combat does (SIGN-R14).
- **SIGN-R41** It plays its look's entrance, then hangs 8 s and goes up, then hides. While the mouse is over it, it eases a little toward the player and its time stands still; its time runs on once the mouse leaves.
- **SIGN-R42** A right click sends it up at once. A left click opens the Fish Journal and sends it up. *From 1.6,* the left click opens the Fish Journal's news list on the item shown (LED-R176), through the first On Module's `def.news(id)` (VIEW-R46), and sends the sign up; with no On Module offering one (the Ledger off), it only sends the sign up. The sign from the Curio Shop's "Show on screen" or the dev command opens nothing.
- **SIGN-R43** With Animations off (`announcements.motion`), it appears at rest and still, plays no sounds, and hides at once when its time is up.

### The looks (SIGN-R50–R56)

- **SIGN-R50** A look has a size, its words box, its inks and sizes, an entrance and an exit length, its sound cues, and a draw that places every sprite from the time since the drop and its state (hover, exit). The motion is deterministic: its particles come from a seeded generator, so a drop looks the same each time. The looks, in their order (`ns.NEWS_SIGN_LOOK_ORDER`):

| Look (rule) | Size | Entrance | Exit | Sounds (s) |
|---|---|---|---|---|
| Wood (default) (SIGN-R51) | 400 × 112 | 1.0 s | 0.74 s | wood_land 0.46, wood_creak 0.84, 1.6; out: wood_rise 0 |
| Scroll (SIGN-R52) | 400 × 176 | 1.55 s | 0.8 s | reel_out 0, line_snap 0.44, paper_unroll 0.56, seal_thump 1.32; out: paper_roll 0, reel_in 0.3 |
| Lantern (SIGN-R53) | 460 × 100 | 2.1 s | 1.1 s | chain_lower 0, lantern_clank 0.78, ignite 1.0, glass_chime 1.25; out: snuff 0, chain_raise 0.35 |
| Kraken (SIGN-R54) | 392 × 112 | 1.6 s | 0.75 s | ink_burst 0, kraken_groan 0.2, tentacle_slap 0.58, drip 1.4, 2.3; out: whoosh_up 0, ink_burst 0.1 |
| Astrolabe (SIGN-R55) | 392 × 100 | 1.5 s | 0.9 s | star_fall 0, star_impact 0.55, astro_spin 0.7; out: astro_out 0 |
| Coral (SIGN-R56) | 392 × 108 | 1.4 s | 0.9 s | drop_fall 0, splash 0.46, bubbles 0.7; out: splash_down 0 |

- **SIGN-R51** **Wood**: a weathered plank board on two ropes falls from above the screen, lands past its rest at 0.46 s, springs back and sways to a stop; the more line hangs under it on a tag on two short twines that lag the swing; sawdust shakes loose at the catch. It goes up on its ropes.
- **SIGN-R52** **Scroll**: a red and white bobber reels a rolled chart down on a line; the line snaps taut, the paper unrolls downward between its rods, revealing the words as it goes, and the wax seal stamps on last. It rolls up and reels in.
- **SIGN-R53** **Lantern**: a wrought rail on a chain lowers a dark teal pane and a brass lantern swinging from its hook; the lantern clanks, lights and flickers, the lines fade in one by one, and fireflies drift. It snuffs out and the chain draws it up.
- **SIGN-R54** **Kraken**: ink bursts, and two tentacles reach down from above the screen with a weed-hung stone tablet, gripping it at its corners with their tips curled round; it drips and its suckers pulse. It is pulled up with a whoosh and a last burst of ink.
- **SIGN-R55** **Astrolabe**: a star falls and strikes; a brass astrolabe spins up around the emblem, its rings turning, and its plate opens to a starry field with the words. It spins away upward.
- **SIGN-R56** **Coral**: a drop of water falls and splashes, and a pearl-rimmed plaque surfaces from the splash, overshooting, as kelp and coral grow round it; bubbles rise and caustic light plays on it. It sinks back with a splash.
- **SIGN-R57** **Which look.** *From 1.6,* the sign wears the look equipped in Core's slot `core.newssign` (`Pagle.GetEquipped`, SHOP-R32, SHOP-R60): Wood, the default, or one of the five the Curio Shop sells. A change of look (`AppearanceChanged`) applies from the next drop; one showing finishes in its look. Only `SignCommon` and the atlas of the look being drawn are loaded: the equipped look's at a drop, and the previewed one's in the Curio Shop or the Collection (SHOP-R61). The slot's IDs are the looks' keys (`core.newssign.<look>`, SIGN-R50's order, `ns.NEWS_SIGN_LOOK_ORDER`).

### For development (SIGN-R60)

- **SIGN-R60** `/pagle dev sign <look> [kind] [more]`, with dev mode on (`/pagle dev on`), as PST-R60's, drops the sign in `look` with sample news of `kind` (`first` by default), and with `more`, a "+11 more" line (not for `region`). An unknown look or kind prints its usage, naming the looks and kinds. With dev mode off it prints that dev commands are off and drops nothing. The samples are the dev's English text; the sign's own words are `ns.L`'s.

## Contracts

```lua
ns.DropNewsSign(lookKey?, news, onStart?) -- SIGN-R40: drops when unrestricted and no letter shows; the last asked for
                                 -- wins; no lookKey: the look equipped as it drops (SIGN-R57); onStart as it starts (SIGN-R17)
ns.SendNewsSignUp()              -- SIGN-R42
ns.NewsSignState()               -- nil, or { look, exiting, static } for a spec or the dev command
ns.NewsSignFrame()               -- PagleNewsSign, once made
ns.NewsSignSample(kind, more?)   -- SIGN-R60's sample news
ns.DecideNewsSign()              -- from 1.6: SIGN-R14's decision, run once a session after the drop delay
ns.PickNews(items, now, floor, switches) -- from 1.6: SIGN-R15's pick and SIGN-R16's count (logic/NewsSign.lua)
ns.EquippedNewsSignLook()        -- from 1.6: the look key SIGN-R57 wears, Wood by default

---@class PagleNewsSignNews
---@field kind string     -- SIGN-R10
---@field kicker string?  -- SIGN-R12
---@field head string
---@field detail string?
---@field more string?
---@field emblem table    -- SIGN-R13: { sign = name } | { atlas, sprite } | { legend, item } | { variety = { species, position, silhouette? } } | { file, fill, tape? }
                         -- silhouette: true for a variety the player hasn't caught, drawn dark (VAR-R27, from 1.6)
```

*From 1.6,* the words of an item are `Pagle.NewsWords(item)` (VIEW-R45, SIGN-R19), which gives a `PagleNewsSignNews` without its more line; the decision adds the more line (SIGN-R16).

The code is in `adapter/NewsSign.lua` (the frame, its drop and the drawing kit), `adapter/NewsSignLooks.lua` (the six looks) and `adapter/NewsSignDev.lua` (the kinds, the samples and the dev command), loaded by `adapter/Settings.xml`, after the files they use, so no TOC line changes. *From 1.6* (Decisions), they get TOC lines of their own in `Pagle.toc`, after the files they use, and `adapter/Settings.xml` loses their `<Script>` lines; the decision (SIGN-R14–R18) is `logic/NewsSign.lua` (the pick) and `adapter/NewsSignDrop.lua`. Specs: `spec/Pagle/adapter/NewsSign_spec.lua`, `spec/Pagle/adapter/NewsSignDrop_spec.lua`, `spec/Pagle/logic/NewsSign_spec.lua`.

## Data

*From 1.6.* All account-wide, in `PagleDB.global`, as the sign's spot already is: the followed Anglers are the Player's, whichever character logs in.

| Key | Contents |
|---|---|
| `newsSign.point` | the sign's spot, `{ x, y }` (SIGN-R20) |
| `newsSign.mute` | true mutes the sign's sounds (SIGN-R31); default false |
| `newsSign.show` | "Show news at login", default true (SIGN-R14, SET-R37) |
| `newsSign.kinds` | `{ [kind] = boolean }`, one per followed kind of SIGN-R10, each default true (SIGN-R15, SET-R37); a missing key reads as true |
| `newsSign.headlines` | "Region headlines", default true (SIGN-R15, SET-R37) |
| `news.since`, `news.seen` | the floor and the seen items, VIEW-R44's (SIGN-R17, SIGN-R18) |

The look in use is `PagleDB.profile.appearance["core.newssign"]`, as every slot's is (SHOP-R32).

## Settings

*From 1.6,* on the Announcements page, in Core's section "The Morning Tide": [settings.md](../settings.md)'s SET-R37 (the master switch, a row per kind, Region headlines, Mute the sign, and the look's slot dropdown).

## Tunables

| Tunable | Value | Rule |
|---|---|---|
| Scale on UIParent | 0.85 (`ns.NEWS_SIGN_SCALE`) | SIGN-R20 |
| Default spot | its top centre at 0.285 across, 0.05 down (`ns.NEWS_SIGN_SPOT`) | SIGN-R20 |
| Hang | 8 s from the end of the entrance (`ns.NEWS_SIGN_HANG`) | SIGN-R41 |
| Hover ease | rate 10 a second | SIGN-R41 |
| Longest a drop lives | 600 s | SIGN-R41 |
| A late cue skipped | over 0.25 s | SIGN-R31 |
| Word sizes | kicker 12, headline 18 (Astrolabe 17), detail 15, more 15 (Scroll 16) | SIGN-R12 |
| Shrink steps | 1, 0.9, 0.8, 0.72 | SIGN-R12 |
| Emblem slot | 58 units | SIGN-R13 |
| Art density | 2 texels a unit | SIGN-R30 |
| Drop delay | 5 s after the session's first `PLAYER_ENTERING_WORLD` (from 1.6) | SIGN-R14 |
| News age | 30 days: an item older than this is never due, whatever the block holds (from 1.6) | SIGN-R15 |
| Name wait | 2 s for an item name the client hasn't loaded (from 1.6) | SIGN-R19 |

## Decisions

*Decided by the dev (2026-11-08, [#650](https://github.com/timemir/pagle-addon/issues/650)):*

- **Prices:** cheaper starters. Scroll and Lantern at tier 3 (900 Coins each), Astrolabe and Coral at tier 4 (3,000), Kraken at tier 5 (10,000): 17,800 in all (SHOP-R25, SHOP-R60).
- **Rare colour** is a Rare or an Epic variety (SIGN-R10; pagle-backend's PRJ-R34).
- **Monster:** each new size record in the Monster band is news again (pagle-backend's PRJ-R34).
- **The news** is the Feed's: 30 days and 50 items (pagle-backend's IGV-R61).

*Adopted recommendations, the dev may revisit:*

- **Cozy mode** holds the sign and marks the items seen; the Fish Journal's list keeps them (SIGN-R14, SET-R37).
- **Region headlines** aren't counted in "+N", as the line says "from your anglers"; a sign showing a headline has no more line (SIGN-R16).
- **A variety the player hasn't caught** is never named or coloured, keeping VAR-R27's discovery: "Epic Spotted Yellowtail" on a silhouette (SIGN-R12, SIGN-R13, SIGN-R19).
- **TOC lines.** 1.6 ships on a new rule set, so the sign's files get TOC lines of their own in Core's TOC, in place of the `<Script>` lines in `adapter/Settings.xml` (Contracts).
- From pagle-backend's side: the server sends the news only to a news-aware Companion, by its version header (IGV-R65); a Hunt's name comes as enUS text in the line (IGV-R60); the player's own Monthly first is never their headline (IGV-R62); Hunt gold is Standing Hunts only (PRJ-R34); Monthly firsts are shown only in game (LB-R80).

## Open questions

- **Size.** The textures are about 5.7 MB of BLPs. SIGN-R57 loads only the atlas of the look in use; DXT1 where a look has no soft alpha would shrink them further.
- **In game, before 1.6 ships** (the designer couldn't check them): `SetClipsChildren` on `clip` for the Scroll and the Astrolabe; `SetRotation` on the Astrolabe's rings; the height of a wrapped two-line headline; the Legend emblem's item icon; each look's sound levels against the game's SFX, and the mute; the region headline's and the hidden variety's words in every language (`fitcheck.lua`).
