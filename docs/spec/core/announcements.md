# Core: Announcements, the Session summary and the Write-up

> Status: Done · Milestones: M2, M4 (the Gilded sound set and the other toast styles as Curio Shop goods, size rulers, the catch Nod), M8.5 Onboarding (ANN-R38's `guide` reason, ANN-R64, `firstNote`, the budget default 20 per 5 min) · Sources: [Prototype Catch feedback: toasts, sounds and cozy mode](https://github.com/timemir/wow-fish/issues/13#issuecomment-6113132854), [Decide who owns Announcements: a Core service or each Module](https://github.com/timemir/wow-fish/issues/22#issuecomment-6113769547), [Prototype Pagle's sounds](https://github.com/timemir/wow-fish/issues/23#issuecomment-6113915981), [Design Stats: session stats, honest odds and dry spells](https://github.com/timemir/wow-fish/issues/21#issuecomment-6113657288), [Cut the MVP slice and roadmap](https://github.com/timemir/wow-fish/issues/18#issuecomment-6113973068), [Design the Pagle currency and shop](https://github.com/timemir/wow-fish/issues/28#issuecomment-6125331898), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545), [Show a quiet catch Nod for every ordinary Catch](https://github.com/timemir/wow-fish/issues/256); ADR 0001, 0004, 0007, 0009, 0010. Prototypes: `prototypes/catch-feedback/`, `prototype/sounds` branch (`prototypes/sounds/`)

Part of [Core](README.md). Core presents every Announcement (ADR 0007): Modules raise **moments**, and Core merges, paces and draws them.

## Purpose and boundary

**Owns:** the moment API, the rung ladder, the catch Nod, merging a Cast's moments into its Announcements, the display queue, the Interruption budget, the combat hold, Cozy mode, expiry, the toast, Nod, banner and splash frames, the record ruler, Announcement sounds and sound sets, toast styles, the Session summary, and the Write-up card.

**Doesn't own:** deciding what is worth a moment or which rung it gets (each Module), QoL's Nudges (QoL draws them itself; they aren't Announcements), or any Module's own bar, tracker or view.

## Rules

### Moments and the ladder

- **ANN-R1** A Module raises a moment with `M:RaiseMoment(moment)` (fields under [Contracts](#contracts)). Each moment sits on one rung of a fixed ladder, lowest to highest: `nod`, `toast.low`, `toast`, `toast.high`, `banner`, `splash`.
- **ANN-R2** Moments are ranked by rung; on the same rung by the moment's `order` (lower first, default 100); then by the raising Module's `def.order`; then the earliest raised wins.
- **ANN-R3** Moments are display data. Core never tells one Module about another's moments (ADR 0001).
- **ANN-R4** Moments may be raised only while handling a `"live"` entry (LOG-R73), from a Core event handler, or from a Module's own timer or UI. Core drops a moment raised while it is applying a `"replay"` or `"rebuild"` entry, and reports it once per Module per login through `geterrorhandler()`. In a projection's `done`, only `summaryOnly` moments and Write-ups are allowed (LOG-R76); others are dropped the same way.

### A Cast's Announcements

- **ANN-R10** Moments with a `cast` (a Cast's entry ID) are merged by that ID. Core collects them and flushes each Cast's moments together on the next frame after the last one arrived, but while any projection is updating (LOG-R74) it holds every Cast's moments and flushes them, Cast by Cast in Cast order, on the frame after the last projection finishes. Live entries reach every projection and the Cast events in one frame (LOG-R9), so a Cast's moments merge whatever order the Modules raised them in.
- **ANN-R11** A Cast's moments become at most **two Announcements**, split by lane (ANN-R20):
  - **big:** its `banner` and `splash` moments
  - **catch:** its `toast.*` and `nod` moments

  A Cast with moments on one side only makes one Announcement. Core hands the big one to the display first, so the two appear together when their lanes are free (a level-up banner and a "New Species" toast). In each, the **headline** is its highest-ranked moment (ANN-R2). Every other moment of that side rides on it as a **stamp** in the corner: the moment's `stamp`, or its `title` if it has none. At most 4 stamps show, highest ranked first; identical stamp texts merge into one; any beyond 4 show as "+N". The Coins stamp (ANN-R23) is separate and never counts toward the 4. The Announcement's weight is the headline's rung:
  - `splash`: a full-screen splash (a Legend), carrying the Cast's other banner and splash moments as stamps
  - `banner`: a centre banner (level-up, Zone Master, Prestige ready, Prestige, Catch Milestone, set titles, Tackle Board milestones), carrying the Cast's other banners as stamps
  - `toast.*`: a toast above the action bar
  - `nod`: one silent line
- **ANN-R12** A moment without a `cast` (a Skill Milestone from a Skill Reading, a Hunt window opening, a login Nod) is an Announcement of its own, flushed on the next frame.
- **ANN-R13** An ordinary Catch gets a **catch Nod**: Core raises it for every live caught Cast (LOG-R9), while the "Show every catch" setting is on (the default). It is a `nod` moment of the Cast (`cast` = its entry ID), raised by Core itself at `CastEnded("caught", cast)`, so it merges with the Cast's other moments (ANN-R10):
  - **Its line** names one of the Cast's Catches: the first, in slot order, with a Simulated Size (LOG-R65), or else the first that isn't item `0`. It reads "{item name} · {band} · {length}": the band's name (`Pagle.SIZE_BANDS`) and the Simulated Size in the Angler's length unit (`Pagle.FormatLength`, LOG-R69), as "Mud Snapper · Decent · 34.2 cm". An item with no Simulated Size (junk, treasure, a trophy, an Uncharted item) shows its name alone. The item's icon is its icon. A name the client hasn't cached reads "Item {itemID}". A Catch with a variety caught before this Cast names it after the item's name, "{item name} · {variety name} · {band} · {length}", with the variety's art in place of the icon ([varieties.md](varieties.md), VAR-R26); a variety caught for the first time is never named here (VAR-R27).
  - **A bigger moment replaces it.** If any Module raises a moment for the same Cast, on either side (ANN-R11), the catch Nod is dropped: it never headlines, never rides as a stamp and never adds to "+N".
  - **It never interrupts.** It is a Nod (ANN-R30), so it never counts toward the Interruption budget and takes its turn in the column as any Nod does (ANN-R20). It plays no sound (ANN-R70) and never goes to the Session summary (an exception to ANN-R25). In combat (ANN-R35) and in Cozy mode (ANN-R40) it is dropped, not held.
  - **Only live Catches.** A got-away Cast, and a Cast whose every item is item `0`, raise none; nor does a replay or rebuild, which fires no `CastEnded` (ANN-R4, LOG-R73).

  With "Show every catch" off, an ordinary Catch raises nothing and never pops up. Either way a Module may move its own bar or view, and a Module raises a moment only for what is worth one: an ordinary Catch is the catch Nod's.

### The display queue

- **ANN-R20** Core shows Announcements in two places: a banner or splash in the **centre**, one at a time, and toasts and Nods in one **column** at the bottom centre. A banner and the column show together. A splash is full-screen, so it holds the column back: it waits until no toast is in the column, and while it waits or shows, nothing new enters the column.

  | Place | Shows | Stays | Waiting |
  |---|---|---|---|
  | Column | `toast.*` headlines as toasts, `nod` headlines (and toasts stepped down, ANN-R31) as Nods | until its motion settles (a toast 2.7 s, a Nod 0.3 s), then its hold: `toast.low` 4 s, a ruled `toast.low` 5 s, `toast` (ruled or not) 6 s, `toast.high` and "While you were fighting" 8 s, a Nod 3 s | first in first out, unlimited; the next enters when the column has room: at most 4 entries, 3 of them toasts, and 300 units tall, so it never reaches a banner |
  | Centre | `banner` and `splash` headlines | a banner settles (1.4 s), then stays 4.5 s; a splash until clicked or 8 s | unlimited, splashes before banners, otherwise in order raised; the next starts once the last has left (a banner takes 0.5 s to leave) |

  The newest entry enters at the column's foot and the older ones move up (0.3 s). With the pointer on a toast or Nod, its clock stands still, and clicking one sends it away at once, then runs its headline's `onClick` if it has one (a Module's own action, such as opening its view; an error in it is reported through `geterrorhandler()`). *Added while building (#305): the companion Nod opens the Pagle Wagers spread when clicked (HNT-R171), which needed a way for a Module to act on a click.* One leaving fades out drifting up, and the ones above drop into its place (UI › Motion).
- **ANN-R21** **Cards** (the Session summary and the Write-up) show only when no toast, banner or splash is on screen or waits (Nods don't count). They don't count as interruptions and play no sound. At login, held Announcements show first, then the Write-up, then "Your last session".
- **ANN-R22** A moment may carry a **record ruler** (`ruler = { old, new, unit, label }`). On a toast headline, the ruler fills past the old record's mark while the number counts up, shows the "+x" margin, then the "New record" stamp lands. On a Nod headline, a compact ruler with the margin shows instead. A ruler shows only for the headline; a record riding as a stamp shows only its stamp. `label` names the number in plain words ("length" for a Simulated Size, "weight" for a trophy weight), never where it comes from. For a Simulated Size, `unit` is `"length"` and `old` and `new` are millimetres: Core shows them and the margin with `Pagle.FormatLength` in the Angler's length unit ([catch-log.md](catch-log.md#simulated-size), LOG-R69), and a margin that rounds to zero in that unit shows as "+<0.1 cm" or "+<0.1 in". Any other `unit` is shown as given ("lb"). A Module never leaves the ruler off a size record.
- **ANN-R23** A moment may carry `coins = N`. Core sums the `coins` of the moments in each Announcement into its own "+N" Pagle Coins stamp, always shown (outside the 4-stamp limit and the merging of identical stamps), Nods included. A Cast's two Announcements each sum only their own moments, so no Coins show twice. Coins never make an Announcement of their own, and a purchase makes none ([wallet-and-shop.md](wallet-and-shop.md)).
- **ANN-R24** Ordinary display picks the headline's sound (ANN-R71) when the Announcement appears on screen, never when it is queued. When a toast appears in the same frame as a banner or splash that played its sound (a Cast's two Announcements, or the release after combat, ANN-R36), only the higher rung's sound plays: the toast is silent, and the next toast plays the variant this one would have. A toast's beats follow its sound (ANN-R76).
- **ANN-R25** Every moment also goes to the Session summary (ANN-R50), whether or not it popped up. The catch Nod is the one exception: it is Core's own, never a Module's moment, and never reaches the summary (ANN-R13).

### Interruption budget

- **ANN-R30** An **interruption** is an Announcement shown as a toast, banner or splash. Each one shown counts on its own: a Cast's banner and its toast are 2. Nods and cards aren't interruptions.
- **ANN-R31** With the budget on (the default), when an Announcement with a `toast.low` headline reaches the front of the column's queue, Core counts the interruptions shown in the last 5 minutes. If there are already 20 (the default count; ONB-R35's Lively preset), it steps down to a Nod (with a compact ruler if it has one) and takes its turn as one. Every other rung always gets through and always counts.
- **ANN-R32** With the budget off, nothing steps down. The count and window are player settings.

### Combat hold

- **ANN-R35** While `Pagle.IsRestricted()` is true, Core hides whatever is on screen and holds it, together with everything waiting and every new Announcement and card, sounds included; Nods on screen or waiting are dropped. Announcements raised during the 2 s wait after combat (ANN-R36) are held too.
- **ANN-R36** 2 s after `RestrictionChanged(false)` (restarting the wait if a new restriction starts first), Core shows what it held, dropping expired moments (ANN-R45):
  1. each held splash and banner, as itself, in the centre (splashes first, then in the order raised)
  2. the held toasts, in the column at the same time as the first held banner (a held splash still holds them back, ANN-R20), so a held Cast's big and catch Announcements show together, as they would have live: 1 or 2 as themselves, in order; 3 or more as one "While you were fighting" toast listing every held headline and their Coins. That toast plays the toast sound once unless it appears with a banner (ANN-R24), counts as one interruption, and never steps down.
  3. held cards (ANN-R21), once no toast, banner or splash shows or waits

  Held Nods don't show again; they are already in the Session summary, except a catch Nod, which is simply dropped (ANN-R13).
- **ANN-R37** Held Announcements count toward the budget only when they actually show.
- **ANN-R38** **Hold reasons.** The hold is kept per reason: `combat` (ANN-R35, ANN-R36) and, from M8.5, `guide`, while the Field guide is open (ONB-R70). While any reason holds, everything is held as in ANN-R35, Nods dropped. When the last reason ends, what was held shows by the rules of the reason that held it longest: after `combat`, as ANN-R36 says; after `guide` alone, at once, with held toasts shown as themselves in order, never folded into "While you were fighting". A combat hold that starts while the guide holds closes the guide (ONB-R25), so `combat`'s rules apply.

### Cozy mode

- **ANN-R40** With Cozy mode on, nothing pops up and nothing plays. Every moment goes only to the Session summary; a catch Nod goes nowhere (ANN-R13).
- **ANN-R41** The one exception is a `splash` (a Legend): it still shows, silently.
- **ANN-R42** The compartment entry (CORE-R51) counts the moments raised while Cozy mode was on that are waiting for a summary. The count resets when a Session summary shows. Turning Cozy mode off doesn't replay anything.

### Expiry

- **ANN-R45** A moment may carry `expiresAt` (server time) and `pastText`. Expiry is checked when an Announcement is about to show: an expired moment is dropped from it (as headline or stamp), the next-ranked moment becomes the headline, and if none is left, nothing shows. A moment already expired when raised goes straight to the summary. In the summary, an expired moment shows its `pastText` ("Nightfin window opened 18:00–12:00"), or its `title` if it has none. Cozy mode still suppresses it, so a Legend's splash stays Cozy mode's only exception.

### Session summary

- **ANN-R50** Core keeps the open Session's summary data in `PagleDB.global.summary`, ready to show: every moment raised in it (the stored fields under [Data](#data)) and each Module's summary lines.
- **ANN-R51** A Module sets its line with `M:SetSummaryLine(key, text)` and keeps it current ("Tackle Board: 2 goals · Campfire 12 days"). Setting `nil` removes it. Lines aren't tied to a Session: they stay set across Sessions until the Module changes them, and each card copies the lines as they are when it is made. A card made while a Module isn't registered (disabled, inert or failed to start, CORE-R41) leaves out that Module's lines, so a disabled Module's last line ("Campfire 12 days") doesn't sit on every later card; its lines stay stored and return when it registers again. Cards already made keep the lines they copied (ANN-R55). Lines alone never make a summary appear.
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
- **ANN-R64** **Show me around.** From M8.5, a Write-up section from a Module that has a Field guide step (ONB-R21) ends with the link **Show me around »**: it closes the card and opens the guide at that Module's first step (ONB-R82). Sections from Modules without one have no link.

### Sounds

- **ANN-R70** Core ships and plays every Announcement sound. Each rung has one sound in the equipped **sound set**: `toast.low`, `toast` and `toast.high` play the toast sound, `banner` the banner sound, `splash` its Legend's **Legend sting** (ANN-R72), and `nod` nothing.
- **ANN-R71** An Announcement plays its headline's sound once, when it appears (ANN-R24), unless it is a toast appearing with a banner or splash that played its own (ANN-R24). A headline moment with `sound = false` makes it silent.
- **ANN-R72** Sound sets:
  - **Driftwood** (default, free): toast = two rising wooden notes, rotating through 3 variants in order so back-to-back toasts never sound the same; banner = a wooden run up the scale with a bell on top.
  - **Gilded** (a Curio Shop good from M4): toast = two bell notes, one variant; banner = three rising bells.
  - **Rain on the Lake** (`core.soundset.rain`, tier 1): drops landing on still water, one after another, and the faint hush of rain behind them. Three toast variants, rotated, and a banner.
  - **Marimba Shore** (`core.soundset.marimba`, tier 1): warm wooden bars, rolled quickly up the scale like a wave coming in. Three toast variants, rotated, and a banner.
  - **Ship's Bell** (`core.soundset.shipbell`, tier 1): the brass bell on the mast, rung for the catch, with the rope and timbers creaking under it. Three toast variants, rotated, and a banner.
  - **Kalimba Creek** (`core.soundset.kalimba`, tier 2): a thumb piano by running water, two notes and a little buzz, as if the creek plucked them. Three toast variants, rotated, and a banner.
  - **Music Box** (`core.soundset.musicbox`, tier 2): a tiny wind-up tune from a box with a fish painted on the lid. Two turns of the key, no more. Three toast variants, rotated, and a banner.
  - **Glass Floats** (`core.soundset.glass`, tier 2): green glass floats knocking together on a net, with bubbles rising past them. Three toast variants, rotated, and a banner.
  - **Steel Pan Lagoon** (`core.soundset.steelpan`, tier 2): bright steel drums from a warm lagoon, two notes that sound like the tide is on your side. Three toast variants, rotated, and a banner.
  - **Tavern Dulcimer** (`core.soundset.dulcimer`, tier 2): a hammered dulcimer from the corner of a dockside tavern, struck quick and bright. Three toast variants, rotated, and a banner.
  - **Frost Chimes** (`core.soundset.frost`, tier 3): icicles chiming against one another in a cold wind, ringing long after they stop moving. Three toast variants, rotated, and a banner.
  - **Harp of the Glade** (`core.soundset.harp`, tier 3): a harp in a forest glade, a short sweep of strings and the leaves answering. Three toast variants, rotated, and a banner.
  - **Gnomish Gizmo** (`core.soundset.gizmo`, tier 3): clockwork ticking, a spring letting go and two cheerful bleeps. It almost certainly works. Three toast variants, rotated, and a banner.
  - **War Drums** (`core.soundset.wardrums`, tier 4): deep drums and a low horn from the hills: a catch announced like the start of a march. Three toast variants, rotated, and a banner.
  - **Old Salt's Concertina** (`ledger.soundset.concertina`, earned, Ledger’s): a squeezebox phrase from a sea song everyone half-knows, played by somebody who knows all of it. Three toast variants, rotated, and a banner.
  - **Choir of the Deep** (`ledger.soundset.choir`, earned, Ledger’s): low voices swelling up from deep water, and something very large singing along underneath. Three toast variants, rotated, and a banner.
  - **Night Watch** (`hunts.soundset.nightwatch`, earned, Hunts'): a low bell for the night watch, a lantern humming and an owl who has seen every catch you ever made. Three toast variants, rotated, and a banner.
  - Each Legend has its own **sting**, about 3 s, the same in every set: Brownell's Blue Striped Racer (19803): an accelerating run that never lets up, a roll of drums under it, and a bright finish; Keefer's Angelfish (19805): a harp sweep that shimmers up and drifts back, with glass and soft voices on top; Dezian Queenfish (19806): a fanfare in fifths over timpani, ending on a full chord and a ringing bell. Core picks the sting by the splash headline's `icon`, the Legend's item ID (LED-R63's moment); a Legend item without a sting of its own (one added after 1.0), or a splash whose `icon` isn't a Legend item with one, plays the first one's (19803's). The shop's ▶ Legend plays that first one in every set.
- **ANN-R73** Sounds play on the SFX channel (`PlaySoundFile(path, "SFX")`), so they follow the player's SFX volume and mute. There is no Pagle volume setting; loudness is baked into the files.
- **ANN-R74** Every sound file is Pagle's own: rendered by `scripts/render-sounds.py`, whose instruments and sets live in `scripts/pagle_data/sounds.py` (modal synthesis of wood, bells, glass, tines, pans and membranes, plucked and hammered strings, reeds, brass and voices, filtered noise for water and wind, plus a small room; nothing sampled), mono, 44.1 kHz, `.ogg`, loudness-matched. It renders every sound set and every Legend sting; nothing is rendered by hand or elsewhere. It runs on the pinned Python in `.tools/`, with numpy, soundfile and SciPy (its filters) among the exact pins in `scripts/tools.env` that `scripts/setup.sh` installs. Its output is committed as `addons/Pagle/media/sounds/<set>/toast_<n>.ogg` and `banner.ogg`, `<set>` being the sound set good's last ID segment (`driftwood`, `gilded`, `rain`, …), and the Legend stings as `addons/Pagle/media/sounds/legend/<itemID>.ogg`.
- **ANN-R75** QoL's recast cue (a quiet wooden double knock) is a QoL sound, not an Announcement; QoL ships and plays it.
- **ANN-R76** A toast that plays its sound also plays its **beats**, the client's own sound kits on the SFX channel (`PlaySound(id, "SFX")`), landing on its motion (UI › Motion): the pen as its name starts writing (`IG_WRITE_QUEST`, 3093, at 0.98 s), a stamp as its stamps land (`PUT_DOWN_GEMS`, 1204, at 2.17 s, if any show), and a coin as its Coins turn in (`LOOT_WINDOW_COIN_SOUND`, 120, at 2.66 s, if any show). They are the same in every sound set. A silent toast has silent beats, and with Animations off there are none. Nods, banners, splashes and cards have none.

### Toast styles

- **ANN-R80** The toast and Nod follow the equipped **toast style**: its page and strip art, its medallion trim, its rubber stamps and its inks. **Torn Page** is the free default; other styles are Curio Shop goods Core registers, and three are earned goods a Module registers in Core's slot ([wallet-and-shop.md](wallet-and-shop.md), SHOP-R25). The banner, splash and cards look the same in every style. A style changes only the look, never timing or rules.
- **ANN-R81** Each style is one atlas of its own (`media/announce/Toasts<Style>`): the page and spine of every rung, the Nod strip, and, for the expansion's styles, its own medallion ring at the four bezel sizes in place of the gold, bronze or silver trim. The expansion's atlases are at 1.5 texels per UI unit (`scale = 1.5` in `data/ToastStyleArt.lua`, copied from the kit, outside the generated `data/AnnounceArt.lua`; the first three styles' are at 2), about 2.8 MB each, and only the equipped style's atlas is loaded. Words drawn into a style's art are decoration, not strings (SHOP-R20). A style also sets the rubber stamps' ink, the kicker and name inks, the bookmark's silk and the wax seal's tint. The expansion's styles:
  - **Ship's Log** (`core.toaststyle.ship`, tier 1): A page from the ship’s log, lashed to a sailcloth spine. Tide columns ruled in navy, an anchor in the margin.
  - **Birch Scroll** (`core.toaststyle.birch`, tier 1): Written on a strip of peeled bark and tied with twine. The ink sinks in and stays.
  - **Tidepool** (`core.toaststyle.tidepool`, tier 1): A page that went in the water and came back out. Sand in the fold, a shell left behind.
  - **Sea Chart** (`core.toaststyle.chart`, tier 2): Torn from a chart nobody should have sold. Soundings, rhumb lines and a compass rose that still points north.
  - **Frostbitten** (`core.toaststyle.frost`, tier 2): Left out overnight on the ice. The rime grew in from the corners while the ink was still wet.
  - **Goblin Ticker** (`core.toaststyle.goblin`, tier 2): Printed on a ticker that never stops. The rivets are load-bearing. Nobody knows what the gear does.
  - **Kelp & Pearl** (`core.toaststyle.kelp`, tier 3): A spine wrapped in kelp and studded with pearls, the page shining like the inside of a shell.
  - **Moonlit Vellum** (`core.toaststyle.moon`, tier 3): Night-blue vellum written in silver, for the catches that come in after the lanterns.
  - **Pressed Leaf** (`core.toaststyle.leaf`, tier 3): One great leaf, pressed flat between two heavy books and dried gold. The veins do the ruling.
  - **Driftglass Bottle** (`core.toaststyle.bottle`, tier 3): Rolled up, corked and given to the tide. It washed back with a better catch than it left with.
  - **Rune-Plate** (`core.toaststyle.rune`, tier 4): Not paper at all: a bronze plate, the catch hammered in and the runes cut round it to keep it honest.
  - **Illuminated Folio** (`core.toaststyle.folio`, tier 5): Gold leaf, lapis and vermilion, laid on vellum by a scribe with too much time and not enough fish.
  - **The Tall Tale** (`ledger.toaststyle.legend`, earned): Kept for the catches people argue about at the docks for years. Gilt border, blue silk, a proper seal.
  - **Oxblood Vellum** (`ledger.toaststyle.prestige`, earned): Oxblood vellum and gilt laurels, for an angler who started over and did it all again.
  - **Hearth Ember** (`tackleboard.toaststyle.ember`, earned): A page that was nearly kindling once. The edges still glow when a good fish comes in.
- **ANN-R82** The second round's ten styles (the Curio Shop expansion kit's "Toast styles · ten more" board) are **composed**: each rung is a stack of sprites from the style's own atlas (`media/announce/Toasts2<Style>`), each at a fixed offset from the rung's top left, drawn from the back in this order: `back`, `body`, `deco`, the medallion's `mback`, the icon, `mfront`, the words, the stamps and the Coins, `front`, then the **motion** sprites `fx1` and `fx2` and any extra the style draws round its `toast.high`. Each rung keeps its own box (`toast` 464 × 92, `toast.high` 524 × 100, `toast.low` 404 × 74, the Nod 420 × 40), medallion, icon size, text box and inks, all from the kit's data; a style's sprites replace the page, spine and trim of ANN-R81, never its timing (ANN-R20) or its rules.
  - **Stamps.** A style's stamp is its own plate, three-sliced to its word (the caps as the kit gives them), in its own ink and face, at its own tilt; the "+N" Coins sit where the style puts them, beside Core's brass coin.
  - **The Nod.** Its body is three-sliced to the line's width (ANN Nod), the caps as the kit gives them; its medallion and motion stay at the left.
  - **Motion.** A motion sprite loops on its own once the toast has landed: translation, rotation, scale and alpha keyframes, or a texture-coordinate scroll of a band of light under a mask texture, each with the duration, easing and origin the kit lists. With **Animations** off (SET-R30), and on a preview that stands still, every motion sprite shows its resting frame and nothing moves; a sprite that only flashes (lightning, a ripple) doesn't show.
  - **Memory.** A style's atlas is loaded only while it is equipped or previewed.
  The ten:
  - **Chapel Glass** (`ledger.toaststyle.glass`, earned): A window from a chapel by the water, leaded by hand. The words sit in the one clear pane; the rest is ruby, cobalt and the colour of late light. *Motion:* Every six seconds a band of light crosses the glass (one sprite, translated, masked by the panel). On toast.high the coloured rays behind the rose turn slowly.
  - **The Deep Lure** (`ledger.toaststyle.deep`, earned): Written by the only light at the bottom of the lake. Something down there holds the catch in its teeth and is in no hurry to let go. *Motion:* The lure bobs on its stalk and its glow breathes (two sprites, translate and alpha). On toast.high a jellyfish drifts under the page and two eyes wait in the dark.
  - **Ink and Koi** (`ledger.toaststyle.koi`, earned): A scroll from a painter who only ever painted fish, and painted them well. The circle round the catch took one breath. *Motion:* A koi crosses under the words and turns back (one sprite, translated), leaving a ring on the water behind it. On toast.high a second fish answers it and a red tassel sways from the roller.
  - **Mounted Trophy** (`ledger.toaststyle.trophy`, earned): Walnut, brass and four good screws. The sort of thing that goes over the fireplace and gets pointed at for the rest of the evening. *Motion:* A glint runs along the brass plate (one sprite, translated, clipped to the plate). On toast.high a gilt fish leaps over the plaque and the prize rosette swings a little.
  - **Fishmonger's Slate** (`ledger.toaststyle.slate`, earned): Chalked up this morning, on ice by noon. The price is whatever the fishmonger thinks you can bear. *Motion:* A puff of chalk dust lifts off the slate now and then, and the ice catches the light (two sprites, alpha and scale). On toast.high a kraft tag swings on its twine.
  - **Through the Ice** (`ledger.toaststyle.ice`, earned): Six inches of good black ice, one hole and a lot of waiting. When the flag goes up you run, and you do not mind the cold. *Motion:* When the toast lands the tip-up flag springs up and settles (one sprite, rotated), and rings spread on the water in the hole. On toast.high the northern lights drift behind it and a snowflake turns.
  - **Cross-Stitch Sampler** (`ledger.toaststyle.stitch`, earned): Stitched by someone patient on the long nights between seasons. Every fish in it took an evening; the needle is still in. *Motion:* The loose thread sways from the needle (one sprite, rotated). On toast.high the border is stitched in gold, a tape measure trails off the end and a red button stands in for the seal.
  - **Sonar Scope** (`core.toaststyle.sonar`, earned): Built by an engineer who wanted to see the fish before they saw him. It hums, it pings, and it has never once been wrong about a ping. *Motion:* The sweep turns on the scope and the blips light as it passes (two sprites, rotate and alpha); a faint scan line rolls down the tube. On toast.high a red lamp blinks on top.
  - **Prize Foil** (`core.toaststyle.foil`, Curio crate only): The rare one, pulled from the pack on the first try. Hold it to the light and the whole lake runs through it. *Motion:* A band of rainbow light rolls across the foil (one sprite, translated, masked to the card). On toast.high the card sits in a clear graded case.
  - **Storm Front** (`core.toaststyle.storm`, tier 5): The catch you made when everyone sensible had gone in. The pennant says gale; the angler says one more cast. *Motion:* Lightning lights the cloud from inside and a bolt cracks down (two sprites, alpha, every seven seconds); the gale pennant snaps. On toast.high a storm lantern swings over the corner.

## Data

`PagleDB` keys owned here:

| Key | Contents |
|---|---|
| `global.summary` | the open Session: `{ moments = { … }, lines = { [module] = { order, title, lines = { [key] = text } } } }` |
| `global.pending` | moments raised with no Session open (ANN-R52) |
| `global.cards` | up to 3 cards waiting to be seen: `{ title, numbers = { casts, catches, gotAway, seconds }, coins, lines, moments, writeUp }` |
| `global.writeUp` | Write-up sections waiting: `{ { module, order, title, heading, lines } }` |
| `profile.announcements` | `{ cozy = false, everyCatch = true, motion = true, budget = { on = true, count = 20, window = 300 } }` (`everyCatch`: "Show every catch", ANN-R13; `motion`: "Animations", UI › Motion) |
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
---@field firstNote? string      -- the Margin note shown the first time a moment of this Module and kind shows (ONB-R53)
---@field seal? integer|"waves"|"book"|"quill"|"crest" -- a banner's wax seal (UI); default "waves"
---@field crest? integer|string  -- with seal "crest": a crest good's icon in the Prestige crest's place (VAR-R25)
---@field art? { texture: integer|string, left: number, right: number, top: number, bottom: number } -- VAR-R11's art
---@field onClick? fun()         -- run when its toast or Nod is clicked away (ANN-R20); never stored
```

`seal` is what a banner headline's wax seal shows: a number pressed into it (an Angler Level, a Catch Milestone's count), a pressed mark (`"waves"`, `"book"`, `"quill"`), or `"crest"` for the Prestige crest holding the Angler's portrait with the title on its ribbon; with `crest` set, that icon (a fish crest, VAR-R25) shows in the Prestige crest's place, with no portrait and no ribbon. Any other value, or none, shows the waves. Only a banner headline's is read.

`art` is a texture and its rectangle as texture coordinates (a fish variety's art, VAR-R11), drawn only where the moment is the headline: a toast's or Nod's medallion shows it cropped to the fish's head (the square at the art's left, from 3% to 40.5% of its width and 12.5% to 87.5% of its height) in place of `icon`, and a banner shows it whole across its seal's foot, the seal's ribbon. `icon` still names what the moment is about, for the Session summary, which never stores `art`.

### `Pagle.IsAnimationsOn()`

True unless the player turned the Animations setting off (UI › Motion). A Module that moves its own frames follows it: off, they appear as they settle.

### `Pagle.Animate(owner, animations, onDone?)`, `Pagle.Cue(owner, seconds, fn)`, `Pagle.StopMotion(owner)`

Core's one motion driver (UI › Motion), which Modules move their frames with instead of a copy of their own:

```lua
Pagle.Animate(frame, {
  { dur = 0.16, ease = Pagle.EASE.out, keys = { { 0, { 0 } }, { 1, { 1 } } }, apply = function(v) frame:SetAlpha(v[1]) end },
  { dur = 1.4, ease = Pagle.Bezier(0.3, 1.5, 0.5, 1), iter = "infinite", dir = "alternate", keys = …, apply = … },
}, onDone)
```

- An animation is the art kits' keyframes: `keys` are `{ progress 0..1, { values } }` as the CSS percentages, a key's `ease` easing the segment after it; `iter` is a count or `"infinite"`, `dir` `"normal"`, `"alternate"` or `"alternate-reverse"`, `delay` in seconds; `apply(values)` sets the property. `Pagle.EASE` holds `linear`, `ease`, `out` and `inOut`; `Pagle.Bezier` makes a CSS cubic-bezier.
- Each starts at its first frame at once, so nothing shows its settled state first; animations started on an owner already playing play beside what it plays. `onDone` runs once all have finished. `Pagle.Cue` runs `fn` that many seconds on, on the owner's clock (a sound on a beat). `Pagle.StopMotion` stops what the owner plays, where it is, with no `onDone`.
- The driver reads the Animations setting itself: off, each animation jumps to where it settles and `onDone` runs at once, and a cue never runs.
- An owner that is no longer visible while it moves (closed, or the whole UI hidden) settles there: each animation jumps to where it settles (a loop to where it starts), each cue still to come runs, then `onDone`. Nothing it ends with, such as hiding a card or closing a note, is lost. A loop starts again only when its Module starts it, as its frame shows.
- The driver ticks only while something moves (QOL-R25).

### `Pagle.WheelScroll(scroll, delta, options?)`

What a scroll frame's `OnMouseWheel` calls, so every book and list scrolls alike: `delta` notches (the client's +1 a notch up, −1 down) of **a third of the view** each, so two thirds of what showed stay in sight. The step is in the view's own units, so a window `Pagle.FitToScreen` shrinks still moves the same share of what it shows. It glides there on the motion driver (0.12 s, `EASE.out`, the scroll frame its owner); a notch while a glide runs adds to where that glide was going, not to where it has got to, so a quick spin goes as far as its notches, and each glide starts where the last one is, so nothing jumps. It never passes the top or the foot, and gives way to anything else that scrolls the frame while it glides (a page sent back to its top, a dragged scroll bar). With Animations off it jumps there.

```lua
---@class PagleWheelOptions
---@field height number?            -- the view's height in the scroll frame's units (default its GetHeight)
---@field range (fun(): number)?    -- how far it scrolls (default its GetVerticalScrollRange)
---@field onScroll fun(offset)?     -- runs at each step of the glide: a scroll bar or thumb that follows it
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
| Core | catch Nod, every live caught Cast with no other moment (ANN-R13) | `nod`, silent, never summarized |
| Ledger | new Species, trophy weight, zone rank, Skill Milestone | `toast` |
| Ledger | size record, new junk or treasure | `toast.low`; a record beating one that stood 50+ Catches of that Species is raised at `toast` |
| Ledger | Species new to a zone, ★, ★★, ★★★, trophy family ★★ or ★★★, Uncharted | `nod` |
| Ledger | level-up, Zone Master, Prestige ready, Catch Milestone, completion title | `banner` |
| Ledger | Prestige (no `cast`: its own Announcement) | `banner` |
| Ledger | Legend | `splash` |
| Hunts | Hunt completed, further tier | `toast.high` |
| Hunts | set title | `banner` |
| Hunts | window opened (opt-in, pinned Hunts) | `nod` with `expiresAt` at the window's close |
| Hunts | Pagle Wagers: first mark | `toast` |
| Hunts | Pagle Wagers: further mark | `toast.low` |
| Hunts | Pagle Wagers: settled run | `toast.high` |
| Hunts | Pagle Wagers: ladder title | `banner` |
| Hunts | Pagle Wagers: companion hint (behind its switch, on at 1.0) | `nod`, no `cast` |
| Tackle Board | Notice completed | `toast.low` |
| Tackle Board | Expedition completed | `toast` |
| Tackle Board | Campfire milestone, title, Fly Box complete | `banner` |
| Tackle Board | Kindling burned, fire out | `nod`, no `cast`, whenever a live advance closes a board day: at login for days passed while away, or when a reset passes while logged in (TKB-R86) |
| Stats, QoL | none | |

The Module specs own their rows, and ANN-R13 owns Core's; this table is a cross-check.

## UI

Every frame is drawn from the announcements art kit: a toast is a fresh entry in the Angler's ledger. The art ships as textures in `addons/Pagle/media/announce/` (BLP, DXT5; `scripts/encode-blp.py` encodes the kit's atlases), with their atlases in `data/AnnounceArt.lua`, and three bundled fonts in `addons/Pagle/media/fonts/`: IM Fell English for print, Caveat for the Angler's hand, Marcellus for gilt, stamps and labels. A headline with a text has its title printed in capitals over the text in the hand; a headline with no text has its title alone in the hand. Stamps, labels and printed words are in capitals (the client has no small caps), leaving texture and colour escapes as they are.

- **Toast:** above the action bar, a torn page on a leather spine with the icon in a brass medallion, the stamps right to left from the page's top right corner, and the Coins beside a brass coin at the bottom right. Its page follows its weight: `toast.low` in pencil on a bare page with a smaller medallion, `toast` on the spine, `toast.high` gilt with a halo, a silk bookmark, a bronze medallion and a wax seal. A headline with a record ruler is on a ruled page of its weight (`toast.high`'s on `toast`'s): the label, a ticked track filling up to the number, the old record's pencil mark with its number, the margin in red, then the "New record" stamp beside the others. The pointer on it stops its clock, and a click sends it away (ANN-R20).
- **Nod:** one line in the column on a torn strip sized to it, with the icon in a small medallion: the words, a compact ruler (the track, the number and the margin), the stamps and the Coins. A catch Nod's line is its title alone (ANN-R13). One naming a variety (VAR-R26) writes the variety's name in its rarity's ink after a small gem in its colour (a diamond rimmed in the ink), the rest of the line in the style's ink, and shows the variety's art cropped to the fish's head in the medallion, its ring tinted the rarity's colour (Common's stays the style's).
- **Banner:** centre screen over the world with no frame: a dark glow and faint gilt rays, the title in spaced gilt capitals, gilt tooling either side of a red wax seal (the headline's `seal`, under Contracts), the text in gilt handwriting, then the stamps as leather labels and the Coins.
- **Splash:** full screen for a Legend, until clicked: the screen darkens behind slow rays, the item's icon sits in the well of the Legend's own crest (LED-R153; the Unwritten crest for a Legend with none), its motion playing while the splash holds, and a torn page carries the title, the name in large handwriting, the labels and the Coins. "Click anywhere to continue" under it.
- **"While you were fighting":** a toast on a taller page listing the held headlines, a row each with a small medallion, up to 3, and "+N more" under them for the rest.
- **Session summary and Write-up cards:** a page torn from the ledger centre-screen, the same in every toast style: a leather head with the gilt title and a close mark, Core's numbers in the hand, the sections in ANN-R53 and ANN-R61 on the page's ruled lines (a moment's text in the hand at the right of its title's line, or, when the two don't fit there side by side, on the lines under the title, wrapped), scrolling past 12 lines, and a gilt close button at the page's foot. Closed with either button or Esc.

Look reference: the announcements art kit (`pagle-announce-kit`, its previews and its probe addon). The text above wins where they differ.

### Motion

The frames move as the art kit's motion has them (`pagle-announce-kit` v2, its `MOTION.md`). Each plays once, when the Announcement appears, and holds where it settles; drawn again for a toast style change, it carries on. A sample on the Curio Shop's stage stands still, and a card has none. With the **Animations** setting off, each appears as it settles. Times are from when it appears:

| Frame | Motion | Settled |
|---|---|---|
| Toast | It rises 26 units and fades in (0.56–0.98 s, overshooting a little); its name is written out left to right in 16 steps (0.98–1.82 s); its stamps slam down from 2.6x (1.89–2.31 s, overshooting); its coin turns in edge-on (2.31–2.66 s). Its record ruler keeps its own count (ANN-R22), and its "New record" stamp slams down as it lands. | 2.66 s |
| Banner | The seal or crest drops from 2.2x (0–0.63 s, overshooting); the gilt tooling draws out from the seal (0.35–1.12 s); the rays fade in, turning from −8° (0.35–1.4 s). | 1.4 s |
| Splash | The rays turn clockwise once a minute for as long as it shows. | never |
| Nod | It fades in. A Rare or Epic catch Nod (VAR-R26) also gets one gleam across its strip, left to right in the rarity's colour, added onto the paper, brightest midway and gone at the far end (0.1–0.7 s); it holds nothing up and plays nothing. | 0.3 s |

Each leaves as its time is up (ANN-R20): a toast or Nod fades out drifting up 12 units (a toast 0.4 s, a Nod 0.3 s), while the column closes up under it (0.3 s); a banner fades and shrinks to 96% about its top (0.5 s); a splash goes at once. With Animations off, each goes at once.

One `OnUpdate` drives every animation, Core's and each Module's (`adapter/Motion.lua`, with the keyframe maths and the player in `logic/Motion.lua`; Contracts), since `AnimationGroup` can't overshoot, step, ease each segment, or animate a width, a texture coordinate or a clip.

## Settings

| Option | Values | Default |
|---|---|---|
| Cozy mode | on/off | off |
| Show every catch | on/off | on (ANN-R13) |
| Animations | on/off | on (UI › Motion) |
| Interruption budget | on/off | on |
| Budget: interruptions | 1–30 | 20 |
| Budget: window | 1–15 min | 5 min |
| Toast style | owned styles | Torn Page |
| Sound set | owned sets | Driftwood |

These sit on the Announcements page. Toast style and sound set also appear on Look and Feel; both edit the same equipped setting (CORE-R42, SHOP-R32).

## Tunables

| Name | Value | Rules |
|---|---|---|
| Settling: toast, Nod, banner | 2.7 s, 0.3 s, 1.4 s | ANN-R20 |
| Hold: `toast.low`, ruled `toast.low`, `toast`, `toast.high` and "While you were fighting", Nod, banner | 4 s, 5 s, 6 s, 8 s, 3 s, 4.5 s | ANN-R20 |
| Splash duration | 8 s or click | ANN-R20 |
| Column: entries, toasts, height | 4, 3, 300 units | ANN-R20 |
| Leaving: toast, Nod, banner | 0.4 s, 0.3 s, 0.5 s | ANN-R20 |
| Held toasts that fold into one | 3 | ANN-R36 |
| Stamps shown | 4 | ANN-R11 |
| Ruler fill animation | 1.5 s | ANN-R22 |
| Budget default | 20 per 5 min | ANN-R31 |
| Rare-record flair threshold (Ledger's rule) | 50 Catches of the Species since the last record | rung table |
| Delay after combat | 2 s | ANN-R36 |
| Cards kept | 3 | ANN-R54 |
| Toast variants per sound set | 3 (Gilded 1) | ANN-R72 |
| Motion sprites per composed rung | at most 2, plus `toast.high`'s extras | ANN-R82 |
| Legend sting length | ~3 s | ANN-R72 |
| Loudness target | −20 dBFS RMS, −1 dBFS peak | ANN-R74 |
| Toast style atlas density | 1.5 texels per UI unit for the expansion's styles (2 for Torn Page, Ripple and Lantern Glow) | ANN-R81 |

## Edge cases

- **ANN-R90 Module disabled, then enabled again.** A disabled Module raises nothing; its moments already stored stay and sort by their stored order (ANN-R53), and its lines stay stored but are left out of new cards (ANN-R51). Re-enabled, its catch-up raises no moments, and a Write-up section covers what that history earned (ANN-R60).
- **ANN-R91 Projection rebuild.** Raises no pop-ups; newly earned moments go to the summary only (ANN-R63).
- **ANN-R92 First build over existing history.** One Write-up card, no moments (ANN-R60–R62). A lost Module DB counts as a first build (LOG-R77).
- **ANN-R93 In combat.** ANN-R35–R37.
- **ANN-R94 Crash mid-Session.** `global.summary` and `global.cards` are saved with everything else, so moments raised before the last save survive and show as "Your last session" at the next login; later ones are lost with their Casts.
- **ANN-R95 Daily or weekly reset.** No rule here depends on it. A Tackle Board refill raises nothing; its login Nods land under ANN-R52.
- **ANN-R96 Uncharted or unconfirmed Catch.** An Uncharted Catch is the Ledger's `nod`, which replaces the catch Nod (ANN-R13); its later reclassification credits arrive through ANN-R63. An unconfirmed catalogue fact changes nothing here: Modules decide whether it earns a moment.
