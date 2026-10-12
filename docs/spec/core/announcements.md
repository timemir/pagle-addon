# Core: Announcements, the Session summary and the Write-up

> Status: Done · Milestones: M2 · Sources: [Prototype Catch feedback: toasts, sounds and cozy mode](https://github.com/timemir/wow-fish/issues/13#issuecomment-6113132854), [Decide who owns Announcements: a Core service or each Module](https://github.com/timemir/wow-fish/issues/22#issuecomment-6113769547), [Prototype Pagle's sounds](https://github.com/timemir/wow-fish/issues/23#issuecomment-6113915981), [Design Stats: session stats, honest odds and dry spells](https://github.com/timemir/wow-fish/issues/21#issuecomment-6113657288), [Cut the MVP slice and roadmap](https://github.com/timemir/wow-fish/issues/18#issuecomment-6113973068), [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545); ADR 0001, 0004, 0007, 0009, 0010. Prototypes: `prototypes/catch-feedback/`, `prototype/sounds` branch (`prototypes/sounds/`)

Part of [Core](README.md). Core presents every Announcement (ADR 0007): Modules raise **moments**, and Core merges, paces and draws them.

## Purpose and boundary

**Owns:** the moment API, the rung ladder, merging one Cast's moments into one Announcement, the display queue, the Interruption budget, the combat hold, Cozy mode, expiry, the toast, Nod, banner and splash frames, the record ruler, Announcement sounds and sound sets, toast styles, the Session summary, and the Write-up card.

**Doesn't own:** deciding what is worth a moment or which rung it gets (each Module), QoL's Nudges (QoL draws them itself; they aren't Announcements), or any Module's own bar, tracker or view.

## Rules

### Moments and the ladder

- **ANN-R1** A Module raises a moment with `M:RaiseMoment(moment)` (fields under [Contracts](#contracts)). Each moment sits on one rung of a fixed ladder, lowest to highest: `nod`, `toast.low`, `toast`, `toast.high`, `banner`, `splash`.
- **ANN-R2** Moments are ranked by rung; on the same rung by the moment's `order` (lower first, default 100); then by the raising Module's `def.order`; then the earliest raised wins.
- **ANN-R3** Moments are display data. Core never tells one Module about another's moments (ADR 0001).
- **ANN-R4** Moments may be raised only while handling a `"live"` entry (LOG-R73), from a Core event handler, or from a Module's own timer or UI. Core drops a moment raised while it is applying a `"replay"` or `"rebuild"` entry, and reports it once per Module per login through `geterrorhandler()`. In a projection's `done`, only `summaryOnly` moments and Write-ups are allowed (LOG-R76); others are dropped the same way.

### One Announcement per Cast

- **ANN-R10** Moments with a `cast` (a Cast's entry ID) are merged by that ID. Core collects them and flushes each Cast's moments together on the next frame after the last one arrived, but while any projection is updating (LOG-R74) it holds every Cast's moments and flushes them, one Announcement per Cast in Cast order, on the frame after the last projection finishes. Live entries reach every projection and the Cast events in one frame (LOG-R9), so a Cast's moments merge whatever order the Modules raised them in.
- **ANN-R11** A Cast's moments become **one Announcement**. Its **headline** is the highest-ranked moment (ANN-R2). Every other moment rides on it as a **stamp** in the corner: the moment's `stamp`, or its `title` if it has none. At most 4 stamps show, highest ranked first; identical stamp texts merge into one; any beyond 4 show as "+N". The Coins stamp (ANN-R23) is separate and never counts toward the 4. The Announcement's weight is the headline's rung:
  - `splash`: a full-screen splash (a Legend), carrying every other moment as stamps
  - `banner`: a centre banner (level-up, Zone Master, Prestige ready, Prestige, Catch Milestone, set titles, Tackle Board milestones)
  - `toast.*`: a toast above the action bar
  - `nod`: one silent line
- **ANN-R12** A moment without a `cast` (a Skill Milestone from a Skill Reading, a Hunt window opening, a login Nod) is an Announcement of its own, flushed on the next frame.
- **ANN-R13** Ordinary Catches raise nothing and never pop up. A Module may move its own bar or view instead.

### The display queue

- **ANN-R20** Core shows Announcements through three lanes. The toast and big lanes share **one on-screen slot**: only one toast, banner or splash is on screen at a time.

  | Lane | Shows | Duration | Waiting | When another arrives |
  |---|---|---|---|---|
  | Toast | `toast.*` headlines | 6 s | up to 2, first in first out | beyond 2 waiting: it isn't shown, and the overflow count grows; the next toast to appear shows "+N more" and the count resets |
  | Big | `banner` and `splash` headlines | banner 4 s; splash until clicked or 8 s | unlimited, splashes before banners, otherwise in order raised | waits for the slot to free, then goes before any waiting toast |
  | Nod | `nod` headlines | 3 s | none | if the shared slot or a Nod is showing, it isn't shown |

  Whatever isn't shown still goes to the Session summary (ANN-R25).
- **ANN-R21** **Cards** (the Session summary and the Write-up) show only when the toast and big lanes are empty. They don't count as interruptions and play no sound. At login, held Announcements show first, then the Write-up, then "Your last session".
- **ANN-R22** A moment may carry a **record ruler** (`ruler = { old, new, unit, label }`). On a toast headline, the ruler fills past the old record's mark while the number counts up, shows the "+x" margin, then the "New record" stamp lands. On a Nod headline, a compact ruler with the margin shows instead. A ruler shows only for the headline; a record riding as a stamp shows only its stamp. `label` says whose number it is ("Pagle size" for a Simulated Size, "weight" for a real trophy weight). For a Simulated Size, `unit` is `"length"` and `old` and `new` are millimetres: Core shows them and the margin with `Pagle.FormatLength` in the Angler's length unit ([catch-log.md](catch-log.md#simulated-size), LOG-R69), and a margin that rounds to zero in that unit shows as "+<0.1 cm" or "+<0.1 in". Any other `unit` is shown as given ("lb"). A Module never leaves the ruler off a size record.
- **ANN-R23** A moment may carry `coins = N`. Core sums the `coins` of every moment in an Announcement into one "+N" Pagle Coins stamp, always shown (outside the 4-stamp limit and the merging of identical stamps), Nods included. Coins never make an Announcement of their own, and a purchase makes none ([wallet-and-shop.md](wallet-and-shop.md)).
- **ANN-R24** Ordinary display picks the headline's sound (ANN-R71) when the Announcement appears on screen, never when it is queued.
- **ANN-R25** Every moment also goes to the Session summary (ANN-R50), whether or not it popped up.

### Interruption budget

- **ANN-R30** An **interruption** is an Announcement shown as a toast, banner or splash. Nods and cards aren't interruptions.
- **ANN-R31** With the budget on (the default), when an Announcement with a `toast.low` headline reaches the front of the toast lane, Core counts the interruptions shown in the last 5 minutes. If there are already 4, it steps down to a Nod (with a compact ruler if it has one) and follows the Nod lane's rules. Every other rung always gets through and always counts.
- **ANN-R32** With the budget off, nothing steps down. The count and window are player settings.

### Combat hold

- **ANN-R35** While `Pagle.IsRestricted()` is true, Core hides whatever is on screen and holds it, together with everything waiting in the lanes and every new Announcement and card, sounds included. Announcements raised during the 2 s wait after combat (ANN-R36) are held too.
- **ANN-R36** 2 s after `RestrictionChanged(false)` (restarting the wait if a new restriction starts first), Core shows what it held, dropping expired moments (ANN-R45):
  1. each held splash and banner, as itself, through the big lane (splashes first, then in the order raised)
  2. one "While you were fighting" toast listing every held toast headline, if there is at least one. It plays the toast sound once, counts as one interruption, and never steps down.
  3. held cards (ANN-R21)

  Held Nods don't show again; they are already in the Session summary.
- **ANN-R37** Held Announcements count toward the budget only when they actually show.

### Cozy mode

- **ANN-R40** With Cozy mode on, nothing pops up and nothing plays. Every moment goes only to the Session summary.
- **ANN-R41** The one exception is a `splash` (a Legend): it still shows, silently.
- **ANN-R42** The compartment entry (CORE-R51) counts the moments raised while Cozy mode was on that are waiting for a summary. The count resets when a Session summary shows. Turning Cozy mode off doesn't replay anything.

### Expiry

- **ANN-R45** A moment may carry `expiresAt` (server time) and `pastText`. Expiry is checked when an Announcement is about to show: an expired moment is dropped from it (as headline or stamp), the next-ranked moment becomes the headline, and if none is left, nothing shows. A moment already expired when raised goes straight to the summary. In the summary, an expired moment shows its `pastText` ("Nightfin window opened 21:00–06:00"), or its `title` if it has none. Cozy mode still suppresses it, so a Legend's splash stays Cozy mode's only exception.

### Session summary

- **ANN-R50** Core keeps the open Session's summary data in `PagleDB.global.summary`, ready to show: every moment raised in it (the stored fields under [Data](#data)) and each Module's summary lines.
- **ANN-R51** A Module sets its line with `M:SetSummaryLine(key, text)` and keeps it current ("Tackle Board: 2 goals · Campfire 12 days"). Setting `nil` removes it. Lines aren't tied to a Session: they stay set across Sessions until the Module changes them, and each card copies the lines as they are when it is made. Lines alone never make a summary appear.
- **ANN-R52** A moment raised while no Session is open (`Pagle.GetSession()` is `nil`, e.g. a login Nod) still pops up under the usual rules, and is kept in `global.pending`. At `SessionStarted`, pending moments move into `global.summary`, so they land on the next Session's card.
- **ANN-R53** On `SessionEnded`, if at least one moment was raised in the Session (or a Cozy-mode Write-up section is waiting, ANN-R62), Core turns the data into a **card** and adds it to `PagleDB.global.cards`, then clears the moments in `global.summary` for the next Session (the lines stay, ANN-R51). Expiry is checked again for every moment as the card is built (ANN-R45). The card shows (ANN-R21):
  - Core's numbers from the Session: Casts, Catches, got away, time fished
  - "Pagle Coins +N", the sum of every moment's `coins`, if above 0
  - each Module's summary lines, by Module order
  - the moments, grouped by Module (stored title and order, so a since-disabled Module still sorts), highest rung first
  - any waiting Write-up sections
  If no moment was raised and no Write-up is waiting, the Session ends quietly and the data is cleared.
- **ANN-R54** A card from a `SessionEnded` with `whileAway = true` (LOG-R63) is titled "Your last session". Cards show one at a time, oldest first; a card is removed when the player closes it. At most 3 cards are kept; adding a 4th drops the oldest.
- **ANN-R55** Cards are held through combat, and show in Cozy mode (the summary is where Cozy mode sends things). They still show a Module's moments and lines after that Module was disabled.
- **ANN-R56** Summary data and cards are derived and live only in `PagleDB`, never in the Catch log.

### Write-up

- **ANN-R60** A Module raises a Write-up section with `M:RaiseWriteUp(section)` from its projection's `done` (LOG-R76) when:
  - `info.firstBuild`: it marks everything as celebrated, and the section's heading reads "Your Ledger was written up from 2,340 Casts" (the Module counts the Casts it applied)
  - `info.replayed > 0` and the replayed history earned anything: the heading reads "While Hunts was off"

  The lines say what was earned ("Angler Level 12", "3 Species", "Pagle Coins +120"). Core adds nothing of its own to a section.
- **ANN-R61** Core shows one **Write-up** card, styled like the Session summary, once no projection is updating (LOG-R74). Sections from several Modules raised in the same login share it, one section each, by Module order. Its sections are kept in `global.writeUp` until the card is closed, so it survives a logout; it is outside the 3-card limit and always shows before stored summary cards.
- **ANN-R62** The Write-up is held through combat. In Cozy mode it isn't shown; its sections stay in `global.writeUp` and join the next card Core creates (ANN-R53), whichever Session that is, making it show even if that Session raised no moment.
- **ANN-R63** After any rebuild that isn't a first build (a content update reclassifying Catches), a Module raises newly earned moments with `summaryOnly = true`: they go to the open or next Session summary, never pop up, and count toward its "at least one moment" test.

### Sounds

- **ANN-R70** Core ships and plays every Announcement sound. Each rung has one sound in the equipped **sound set**: `toast.low`, `toast` and `toast.high` play the toast sound, `banner` the banner sound, `splash` the **Legend sting**, and `nod` nothing.
- **ANN-R71** An Announcement plays its headline's sound once, when it appears (ANN-R24). A headline moment with `sound = false` makes it silent.
- **ANN-R72** Sound sets:
  - **Driftwood** (default, free): toast = two rising wooden notes, rotating through 3 variants in order so back-to-back toasts never sound the same; banner = a wooden run up the scale with a bell on top.
  - **Gilded** (a Curio Shop good from M4): toast = two bell notes, one variant; banner = three rising bells.
  - Every set shares one Legend sting: a slow bell chord, a fast wooden run and a ringing top note, about 3 s.
- **ANN-R73** Sounds play on the SFX channel (`PlaySoundFile(path, "SFX")`), so they follow the player's SFX volume and mute. There is no Pagle volume setting; loudness is baked into the files.
- **ANN-R74** Every sound file is Pagle's own: rendered by a script in the repo (wood and bell synthesis plus a small room, D major pentatonic), mono, 44.1 kHz, `.ogg`, loudness-matched. The script moves from `prototype/sounds` into the build tooling in M2 and renders both sets; its output is committed as `addons/Pagle/media/sounds/<set>/toast_<n>.ogg` and `banner.ogg` (`<set>` is `driftwood` or `gilded`), plus the shared `addons/Pagle/media/sounds/legend.ogg`.
- **ANN-R75** QoL's recast cue (a quiet wooden double knock) is a QoL sound, not an Announcement; QoL ships and plays it.

### Toast styles

- **ANN-R80** The toast, Nod, banner, splash and card frames follow the equipped **toast style**. **Timber** is the free default; other styles are Curio Shop goods Core registers ([wallet-and-shop.md](wallet-and-shop.md)). A style changes only the look, never timing or rules.

## Data

`PagleDB` keys owned here:

| Key | Contents |
|---|---|
| `global.summary` | the open Session: `{ moments = { … }, lines = { [module] = { order, title, lines = { [key] = text } } } }` |
| `global.pending` | moments raised with no Session open (ANN-R52) |
| `global.cards` | up to 3 cards waiting to be seen: `{ title, numbers = { casts, catches, gotAway, seconds }, coins, lines, moments, writeUp }` |
| `global.writeUp` | Write-up sections waiting: `{ { module, order, title, heading, lines } }` |
| `profile.announcements` | `{ cozy = false, budget = { on = true, count = 4, window = 300 } }` |
| `profile.appearance` | equipped toast style and sound set, among other slots ([wallet-and-shop.md](wallet-and-shop.md#data)) |

A stored moment keeps: `module`, `moduleTitle`, `moduleOrder`, `kind`, `rung`, `title`, `text`, `icon`, `stamp`, `coins`, `expiresAt`, `pastText`. The display lanes, the budget's recent interruptions and the hold live in memory only.

## Contracts

### `M:RaiseMoment(moment)`

```lua
---@class PagleMoment
---@field rung "nod"|"toast.low"|"toast"|"toast.high"|"banner"|"splash"
---@field kind string            -- the Module's own name for it, e.g. "newSpecies"
---@field order? integer         -- tie-break on the same rung, lower first (default 100)
---@field title string           -- headline text ("New Species")
---@field text? string           -- second line ("Nightfin Snapper")
---@field icon? integer|string   -- itemID, fileID or texture path
---@field stamp? string          -- text when riding as a stamp ("New!"); defaults to title
---@field cast? string           -- the Cast's entry ID (ANN-R10)
---@field coins? integer         -- ANN-R23
---@field ruler? { old: number, new: number, unit: string, label: string }   -- ANN-R22; unit "length" = millimetres
---@field sound? boolean         -- default true
---@field expiresAt? integer     -- server time (ANN-R45)
---@field pastText? string       -- shown in the summary if it expired
---@field summaryOnly? boolean   -- ANN-R63
```

### `M:RaiseWriteUp(section)`

```lua
---@class PagleWriteUpSection
---@field heading string         -- "Your Ledger was written up from 2,340 Casts" / "While Hunts was off"
---@field lines string[]
```

### `M:SetSummaryLine(key, text?)`

ANN-R51.

### Rungs Modules use, so far

| Module | Moment | Rung |
|---|---|---|
| Ledger | new Species, trophy weight, zone rank, Skill Milestone | `toast` |
| Ledger | size record, new junk or treasure | `toast.low`; a record beating one that stood 50+ Catches of that Species is raised at `toast` |
| Ledger | Species new to a zone, ★★★, Uncharted | `nod` |
| Ledger | level-up, Zone Master, Prestige ready, Prestige, Catch Milestone | `banner` |
| Ledger | Legend | `splash` |
| Hunts | Hunt completed, further tier | `toast.high` |
| Hunts | set title | `banner` |
| Hunts | window opened (opt-in, pinned Hunts) | `nod` with `expiresAt` at the window's close |
| Tackle Board | Notice completed | `toast.low` |
| Tackle Board | Expedition completed | `toast` |
| Tackle Board | Campfire milestone, title, Fly Box complete | `banner` |
| Tackle Board | Kindling burned, fire out | `nod` at the next login |
| Stats, QoL | none | |

The Module specs own their rows; this table is a cross-check.

## UI

- **Toast:** Retail alert-style frame above the action bar: icon, title, text, up to 4 stamps in the corner, optional record ruler, "+N more" when the lane overflows. Clicking does nothing.
- **Nod:** one line of text with an icon, under the toast position, fading after 3 s.
- **Banner:** centre-screen banner with title and text, like the level-up banner.
- **Splash:** full-screen splash for a Legend: the item icon, its name and its title.
- **"While you were fighting":** a toast listing the held headlines.
- **Session summary and Write-up cards:** a card centre-screen with the sections in ANN-R53 and ANN-R61, closed with a button or Esc.

Look reference: `prototypes/catch-feedback/` (variant A). The text above wins where they differ.

## Settings

| Option | Values | Default |
|---|---|---|
| Cozy mode | on/off | off |
| Interruption budget | on/off | on |
| Budget: interruptions | 1–10 | 4 |
| Budget: window | 1–15 min | 5 min |
| Toast style | owned styles | Timber |
| Sound set | owned sets | Driftwood |

Where toast style and sound set appear (Announcements section, Appearance page or both) is for `docs/spec/settings.md`.

## Tunables

| Name | Value | Rules |
|---|---|---|
| Nod duration | 3 s | ANN-R20 |
| Toast duration | 6 s | ANN-R20 |
| Toasts waiting | 2 | ANN-R20 |
| Banner duration | 4 s | ANN-R20 |
| Splash duration | 8 s or click | ANN-R20 |
| Stamps shown | 4 | ANN-R11 |
| Ruler fill animation | 1.5 s | ANN-R22 |
| Budget default | 4 per 5 min | ANN-R31 |
| Rare-record flair threshold (Ledger's rule) | 50 Catches of the Species since the last record | rung table |
| Delay after combat | 2 s | ANN-R36 |
| Cards kept | 3 | ANN-R54 |
| Driftwood toast variants | 3 | ANN-R72 |
| Legend sting length | ~3 s | ANN-R72 |
| Loudness target | −20 dBFS RMS, −1 dBFS peak | ANN-R74 |

## Edge cases

- **ANN-R90 Module disabled, then enabled again.** A disabled Module raises nothing; its moments and lines already stored stay and sort by their stored order (ANN-R53). Re-enabled, its catch-up raises no moments, and a Write-up section covers what that history earned (ANN-R60).
- **ANN-R91 Projection rebuild.** Raises no pop-ups; newly earned moments go to the summary only (ANN-R63).
- **ANN-R92 First build over existing history.** One Write-up card, no moments (ANN-R60–R62). A lost Module DB counts as a first build (LOG-R77).
- **ANN-R93 In combat.** ANN-R35–R37.
- **ANN-R94 Crash mid-Session.** `global.summary` and `global.cards` are saved with everything else, so moments raised before the last save survive and show as "Your last session" at the next login; later ones are lost with their Casts.
- **ANN-R95 Daily or weekly reset.** No rule here depends on it. A Tackle Board refill raises nothing; its login Nods land under ANN-R52.
- **ANN-R96 Uncharted or unconfirmed Catch.** An Uncharted Catch is the Ledger's `nod`; its later reclassification credits arrive through ANN-R63. An unconfirmed catalogue fact changes nothing here: Modules decide whether it earns a moment.
