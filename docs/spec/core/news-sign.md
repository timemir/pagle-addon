# Core: The Morning Tide (the news sign)

> Status: Draft (art, motion and the dev command built; no news source, Settings or unlocks yet) · Prefix `SIGN` · Sources: the design brief "Pagle's news sign"; ADR 0019; the map, timemir/pagle-addon#650

Part of [Core](README.md). **The Morning Tide** is what players call the news sign; the spec and code keep "news sign" as its internal name. At login or `/reload` a sign drops in from the top of the screen with one piece of news about the Anglers the player follows, or a region headline: it overshoots, settles, hangs about 8 s and goes back up. It comes in six **looks**: plain wood, free and the default, and five that are Curio Shop goods. This draft covers the sign itself, its art, motion and sounds, and the dev command that shows it with sample news; what raises it with real news, its Settings and the unlocking are to come (Open questions).

## Purpose and boundary

**Owns (Core):** the sign's frame, `PagleNewsSign`; its six looks, their art (`Pagle/media/sign`) and sounds (`Pagle/media/sign/sounds`); how a piece of news is laid out on it; its timing, hover, clicks, drag and saved spot; and `/pagle dev sign`.

**Doesn't own:** what the news is and when there is some (the following list and its feed, to come), which looks the Angler owns (the Curio Shop's, to come), or the Fish Journal it opens (the Ledger's).

## Rules

### The news (SIGN-R10–R13)

- **SIGN-R10** A piece of news is one of eight **kinds** about a followed Angler, in this order of rank: `first` (first in the region to land a fish), `legend`, `prestige`, `ledger` (completed the Ledger), `colour` (a rare variety), `hunt` (Hunt gold), `zone` (Zone Master) and `monster`; or the **region headline**, `region`, the region's first of a fish this month. When there is more news than the sign shows, it shows the highest-ranked and says how many more.
- **SIGN-R11** The news names an Angler by the Angler's name, never a character's.
- **SIGN-R12** The sign's words are its **kicker** (the kind, `SIGN_KICKER.<kind>`), its **headline** (`SIGN_HEAD.<kind>`, two lines at most), an optional **detail** line (the Legend, the variety and species `SIGN_DETAIL_COLOUR`, the Hunt, the Monster and its length `SIGN_DETAIL_MONSTER`, the Angler for `first` and `region`) and, when there's more, the **more line** (`SIGN_MORE`, counted). Every one goes through `ns.L`. They are set in the repo's faces: the kicker in IM Fell English SC, the headline in Marcellus, the detail in IM Fell English italic, the more line in Caveat SemiBold. Each look has a words box; the words are centred in it, above the more line where it sits on the board. Words that don't fit at their sizes, a long translation's or the pseudo-locale's, are set smaller together, at 0.9, 0.8 then 0.72 of them; a detail still wider than the box scrolls to and fro in it as a toast's does (ANN-R101); the more line is set smaller to fit its room, and cut there at the last.
- **SIGN-R13** Each kind has an **emblem** at the board's left, drawn in a slot 58 units across: the sign's laurel (`first`, `region`) and medal (`hunt`); a Legend's crest and the fish's item icon (`legend`); the Prestige emblem (`prestige`); the Ledger's book (`ledger`); the variety's fish (`colour`); the zone's crest from the Ledger (`zone`); the fish's crest with a measuring tape over it (`monster`). Each look frames the slot its own way.

### Where it hangs (SIGN-R20)

- **SIGN-R20** The sign is one frame, `PagleNewsSign`, on UIParent at a scale of 0.85, in the `HIGH` strata. Its top centre rests at its **spot**, saved as fractions of UIParent from its top left as the minimap icon's is (CORE-R53): `PagleDB.global.newsSign.point = { x, y }`, else 0.285 and 0.05. The Angler can drag it out of combat; the release saves the spot, and isn't a click.

### Art and sounds (SIGN-R30–R31)

- **SIGN-R30** The art is one shared atlas (`SignCommon`: glows, dots, sparkles, rings, puffs, the tentacle's discs and suckers, the drop, a pixel, the laurel, the medal, the tape) and one per look (`SignWood`, `SignScroll`, `SignLantern`, `SignKraken`, `SignAstro`, `SignCoral`), each a power-of-two BLP at 2 texels a unit, its sprites in `ns.ATLASES` (`data/NewsSignArt.lua`). Everything is drawn as upright sprites placed from the sign's top left each frame; only round sprites turn (the astrolabe's rings). A look's frames, textures and font strings are made once and drawn again on its next drop.
- **SIGN-R31** Each look plays its sounds at cues on its timeline (SIGN-R50–R56) with `PlaySoundFile(path, "SFX")`, Ogg Vorbis, mono, 44.1 kHz, from `Pagle/media/sign/sounds`. A cue more than 0.25 s late is skipped, so a hitch never stacks them. `PagleDB.global.newsSign.mute` mutes them (its Setting is to come).

### A drop (SIGN-R40–R43)

- **SIGN-R40** The sign drops only when Pagle isn't restricted: a drop asked for in combat waits for it to end, and the last asked for wins. If combat starts while it shows, it goes up at once.
- **SIGN-R41** It plays its look's entrance, then hangs 8 s and goes up, then hides. While the mouse is over it, it eases a little toward the player and its time stands still; its time runs on once the mouse leaves.
- **SIGN-R42** A right click sends it up at once. A left click opens the Fish Journal and sends it up.
- **SIGN-R43** With Animations off (`announcements.motion`), it appears at rest and still, plays no sounds, and hides at once when its time is up.

### The looks (SIGN-R50–R56)

- **SIGN-R50** A look has a size, its words box, its inks and sizes, an entrance and an exit length, its sound cues, and a draw that places every sprite from the time since the drop and its state (hover, exit). The motion is deterministic: its particles come from a seeded generator, so a drop looks the same each time. The looks, in their order (`ns.NEWS_SIGN_LOOK_ORDER`):

| Look | Size | Entrance | Exit | Sounds (s) |
|---|---|---|---|---|
| **SIGN-R51** Wood (default) | 400 × 112 | 1.0 s | 0.74 s | wood_land 0.46, wood_creak 0.84, 1.6; out: wood_rise 0 |
| **SIGN-R52** Scroll | 400 × 176 | 1.55 s | 0.8 s | reel_out 0, line_snap 0.44, paper_unroll 0.56, seal_thump 1.32; out: paper_roll 0, reel_in 0.3 |
| **SIGN-R53** Lantern | 460 × 100 | 2.1 s | 1.1 s | chain_lower 0, lantern_clank 0.78, ignite 1.0, glass_chime 1.25; out: snuff 0, chain_raise 0.35 |
| **SIGN-R54** Kraken | 392 × 112 | 1.6 s | 0.75 s | ink_burst 0, kraken_groan 0.2, tentacle_slap 0.58, drip 1.4, 2.3; out: whoosh_up 0, ink_burst 0.1 |
| **SIGN-R55** Astrolabe | 392 × 100 | 1.5 s | 0.9 s | star_fall 0, star_impact 0.55, astro_spin 0.7; out: astro_out 0 |
| **SIGN-R56** Coral | 392 × 108 | 1.4 s | 0.9 s | drop_fall 0, splash 0.46, bubbles 0.7; out: splash_down 0 |

- **SIGN-R51** **Wood**: a weathered plank board on two ropes falls from above the screen, lands past its rest at 0.46 s, springs back and sways to a stop; the more line hangs under it on a tag on two short twines that lag the swing; sawdust shakes loose at the catch. It goes up on its ropes.
- **SIGN-R52** **Scroll**: a red and white bobber reels a rolled chart down on a line; the line snaps taut, the paper unrolls downward between its rods, revealing the words as it goes, and the wax seal stamps on last. It rolls up and reels in.
- **SIGN-R53** **Lantern**: a wrought rail on a chain lowers a dark teal pane and a brass lantern swinging from its hook; the lantern clanks, lights and flickers, the lines fade in one by one, and fireflies drift. It snuffs out and the chain draws it up.
- **SIGN-R54** **Kraken**: ink bursts, and two tentacles reach down from above the screen with a weed-hung stone tablet, gripping it at its corners with their tips curled round; it drips and its suckers pulse. It is pulled up with a whoosh and a last burst of ink.
- **SIGN-R55** **Astrolabe**: a star falls and strikes; a brass astrolabe spins up around the emblem, its rings turning, and its plate opens to a starry field with the words. It spins away upward.
- **SIGN-R56** **Coral**: a drop of water falls and splashes, and a pearl-rimmed plaque surfaces from the splash, overshooting, as kelp and coral grow round it; bubbles rise and caustic light plays on it. It sinks back with a splash.

### For development (SIGN-R60)

- **SIGN-R60** `/pagle dev sign <look> [kind] [more]`, with dev mode on (`/pagle dev on`), as PST-R60's, drops the sign in `look` with sample news of `kind` (`first` by default), and with `more`, a "+11 more" line (not for `region`). An unknown look or kind prints its usage, naming the looks and kinds. With dev mode off it prints that dev commands are off and drops nothing. The samples are the dev's English text; the sign's own words are `ns.L`'s.

## Contracts

```lua
ns.DropNewsSign(lookKey, news)   -- SIGN-R40: drops when unrestricted; the last asked for wins
ns.SendNewsSignUp()              -- SIGN-R42
ns.NewsSignState()               -- nil, or { look, exiting, static } for a spec or the dev command
ns.NewsSignFrame()               -- PagleNewsSign, once made
ns.NewsSignSample(kind, more?)   -- SIGN-R60's sample news

---@class PagleNewsSignNews
---@field kind string     -- SIGN-R10
---@field kicker string?  -- SIGN-R12
---@field head string
---@field detail string?
---@field more string?
---@field emblem table    -- SIGN-R13: { sign = name } | { atlas, sprite } | { legend, item } | { variety = { species, position } } | { file, fill, tape? }
```

The code is in `adapter/NewsSign.lua` (the frame, its drop and the drawing kit), `adapter/NewsSignLooks.lua` (the six looks) and `adapter/NewsSignDev.lua` (the kinds, the samples and the dev command), loaded by `adapter/Settings.xml`, after the files they use, so no TOC line changes. Specs: `spec/Pagle/adapter/NewsSign_spec.lua`.

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

## Open questions

- **The Following spread.** The brief's left click opens the Fish Journal's Following spread. The Ledger has no view for it, and adding one changes `logic/Module.lua`, which is hashed (PRJ-R64); for now the click opens the Journal (its `journal` view). Needs the Ledger's view.
- **Unlocks.** Decided (#650): the five looks beyond Wood are Curio Shop goods, bought with Pagle Coins as the toast styles are. Their prices, Catalogue entries (hashed), how a look is equipped and the shop's previews are to come.
- **Settings.** The look in use, the mute and whether the sign shows at all are to come; `newsSign.mute` exists already, with no Setting.
- **The news.** Nothing yet raises the sign but SIGN-R60. Decided (#650): it ships in 1.6 with real news, the verified Feed items the Companion brings in `Pagle_Following`; reading them, last seen, and picking the best item are to come.
- **Loading through Settings.xml.** The new files load from `adapter/Settings.xml` because the TOC couldn't change on the branch they were made on; 1.6 ships on a new rule set (pagle-2026j), so TOC lines of their own can replace these there.
- **Size.** The textures are about 5.7 MB of BLPs. They could be halved by dropping to DXT1 where a look has no soft alpha, or by loading a look's atlas only when it's owned.
- **The zone crest** is the Ledger's (`Pagle_Ledger/media/crests`), so with the Ledger off it's missing.
