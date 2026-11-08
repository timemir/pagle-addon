# Core: Anglers in game

> Status: Draft · Milestones: Track V In-game views · Sources: [Amendments from the Pagle backend](https://github.com/timemir/pagle-addon/issues/76) items 9 and 10, pagle-backend's [in-game-views.md](https://github.com/timemir/pagle-backend/blob/main/docs/spec/in-game-views.md) (IGV), its [prototype](https://github.com/timemir/pagle-backend/tree/main/prototypes/in-game-views) (variant A, IGV-R81), and the grilling on [#76](https://github.com/timemir/pagle-addon/issues/76) (2026-10-22); *from 1.6,* [#650](https://github.com/timemir/pagle-addon/issues/650) (The Morning Tide) and pagle-backend's news block (IGV-R60–R66, [#466](https://github.com/timemir/pagle-backend/issues/466)); ADR 0001

Part of [Core](README.md). The Companion brings Published Anglers into the game as two data addons it creates and owns, never shipped in Pagle's zip: **`Pagle_Following`**, the Followed Anglers with their full cards, and **`Pagle_Anglers`**, every Published Angler in the player's regions with the tooltip card (IGV-R40–R43). Core alone reads both, shows a Pagle block on player tooltips, and hands the Followed Anglers to the Ledger's Following spread (LED-R163). *From 1.6,* `Pagle_Following` also brings **news**: the Feed of the Anglers the player follows and the region headlines, which Core reads for the news sign, The Morning Tide ([news-sign.md](news-sign.md)), and hands to the Ledger's news list (LED-R176). Their formats, and what counts as absent or expired, are pagle-backend's and are cited here, never restated.

## Purpose and boundary

**Owns:** reading `Pagle_Following` and `Pagle_Anglers`, when `Pagle_Anglers` loads, the lookup of a player unit, `Pagle.GetFollowedAnglers()`, the Pagle block on the unit tooltip, and its Settings row; *from 1.6,* reading the news block, `Pagle.GetNews()`, `Pagle.NewsWords()`, the seen items and the floor (`PagleDB.global.news`), and the `def.news` hand-over.

**Doesn't own:** the data files' formats, the absent and expired checks and the lookups' key rules (IGV-R40–R47, IGV Contracts); which Anglers and values the files hold (IGV-R1–R16); the Companion; the Following spread (LED-R163) and the news list (LED-R176); when the news sign drops and what it shows (SIGN-R14–R19); which news there is (IGV-R60–R64); `Pagle_Content` (pushed-content.md).

## Rules

### The data addons

- **VIEW-R1** Core reads `Pagle_Following` (loaded normally, after Pagle, IGV-R42) once at `PLAYER_LOGIN`, and `Pagle_Anglers` (load-on-demand, IGV-R43) once it has loaded it (VIEW-R3). Each file is **absent** or **expired** exactly as IGV-R44 and IGV-R45 say, with the expiry age of IGV's Tunables (24 h by `GetServerTime()`); a file that is neither is **live**. Core reads only file version `1` (IGV-R44).
- **VIEW-R2** Expiry is checked again at every use (IGV-R45): a file live at login that passes the expiry age during the session is used no more from then on, without a reload.
- **VIEW-R3** Core calls `C_AddOns.LoadAddOn("Pagle_Anglers")` once per login, the first time a player unit tooltip shows (VIEW-R20) while `Pagle.IsRestricted()` is false and the tooltip setting (VIEW-R30) is on. It never loads it otherwise: while restricted, a hover uses `Pagle_Following` alone and the next hover outside restriction loads it. A load that fails leaves the file absent for the login, and Core doesn't try again.
- **VIEW-R4** Nothing flows back (IGV-R47): Core writes nothing into either folder, and nothing from them enters `PagleLog` or any SavedVariables, with one exception from 1.6: the ids and times of news items Core has marked seen, and the floor (VIEW-R44), which hold no name, GUID or card. Core never logs, prints or reports a GUID, name or card from them, except under `/pagle dev views` (VIEW-R12).

### The reads

- **VIEW-R10** **Looking up a unit.** For a player unit's GUID (the tooltip data's `guid`, the value `UnitGUID` gives), Core looks in `Pagle_Following` first, then `Pagle_Anglers`, each only while live, by IGV-R46's lookups. A match in `Pagle_Following` is a **Followed Angler**'s full card; one in `Pagle_Anglers` a tooltip card (IGV-R10, IGV-R11). No match, or neither file live, is no card. A secret or `nil` GUID (CORE-R31) is never looked up.
- **VIEW-R11** **`Pagle.GetFollowedAnglers()`** returns `{ state, anglers }`:
  - `state` is `"absent"` when `Pagle_Following` is absent (VIEW-R1), `"expired"` when it is expired, `"none"` when it is live with no Anglers, and `"ok"` otherwise;
  - `anglers` is a fresh array, empty unless the state is `"ok"`, of every Angler in the file in the file's order (IGV-R31), each a copy the caller may keep (an exception to CORE-R18's no defensive copies, since the file is read once a login and outlives the call), with the full card's fields as `Pagle_Following`'s grammar names them: `name`, `more`, `hardcore`, `title` (`""` when none), `level`, `prestige`, `ledger`, `legends`, `legendsTotal`, `waters`, `catches`, `asOf` (`YYYYMMDD`) and `guids`.

  It reads the state at the call, so an expiry mid-session (VIEW-R2) shows at the next call.
- **VIEW-R12** With dev mode on (`/pagle dev on`), `/pagle dev views` prints each file's state (live, absent with IGV-R44's first failing condition, or expired with its age), its `generatedAt`, its Angler or block count, and whether `Pagle_Anglers` has loaded this login; *from 1.6* also the news state (VIEW-R42), the number of news lines used and skipped (VIEW-R41), how many are seen, and the floor.
- **VIEW-R13** **Text is drawn as written.** Core doubles every `|` in a name or title it reads from either file, in the cards VIEW-R10 finds and the Anglers VIEW-R11 hands out, so the client never reads one as an escape sequence (a colour, texture or link). *Decided while building Track V: IGV's grammar allows `|` in Lua strings.*

### The news (VIEW-R40–R46)

*From 1.6 (rule set pagle-2026j).* pagle-backend's news block (IGV-R60–R66, IGV Contracts › `Pagle_Following`) is read here and cited, never restated.

- **VIEW-R40** **Reading it.** Core reads `PagleFollowingData.news` with the rest of the file, once at `PLAYER_LOGIN` (VIEW-R1). The news is used only while the file is live (VIEW-R1, VIEW-R2). A live file whose `news` isn't a table has no news block: its Companion predates the news (IGV-R65), and that is the news state `none` (VIEW-R42), never a reason to call the file absent; the Anglers read as before.
- **VIEW-R41** **A news line** is used when it holds every field of IGV's `news-line` with its type: `id` a string of 16 lowercase hexadecimal digits, `kind` one of SIGN-R10's nine (`first`, `legend`, `prestige`, `ledger`, `colour`, `hunt`, `zone`, `monster`, `region`), `name`, `region`, `key` and `text` strings, `time`, `angler`, `item`, `rank`, `zone` and `length` whole numbers from 0, and `angler` at most the number of `anglers`. Any other line is skipped on its own, never the file, so a kind a later server sends is ignored here (IGV Contracts). A line repeating an earlier line's `id` is skipped. `name` and `text` are drawn as written (VIEW-R13: every `|` doubled). The fields' meanings by kind are IGV Contracts'.
- **VIEW-R42** **`Pagle.GetNews()`** returns `{ state, items }`:
  - `state` is `"absent"` or `"expired"` as `GetFollowedAnglers` says (VIEW-R11), `"none"` when the file is live with no news block (VIEW-R40), and `"ok"` otherwise, with or without items;
  - `items` is a fresh array, empty unless the state is `"ok"`, of every line used (VIEW-R41) in the file's order (IGV-R64), each a copy with the line's fields and `new`: true when, at the session's first read of the news, its `id` wasn't seen (VIEW-R44) and its `time` was at or after the floor (SIGN-R18), so it stays new for the whole session after it is marked, and the first login, which sets the floor, calls nothing new.

  It reads the state at the call, so an expiry mid-session (VIEW-R2) shows at the next call.
- **VIEW-R43** **`Pagle.MarkNewsSeen(ids)`** marks each id seen with its item's `time`; with no argument, every item of `GetNews()`. It does nothing while the news isn't `ok`. Only the news sign (SIGN-R17) and the Fish Journal's news list (LED-R177) call it.
- **VIEW-R44** **Seen, and the floor** (IGV-R47's exception). Core keeps `PagleDB.global.news`: `since`, the floor (SIGN-R18), and `seen`, `{ [id] = time }`, every news item marked seen with its `time`. Nothing else from the file is kept: no name, kind, Angler or text. Reading the news never sets the floor: the sign's decision does (SIGN-R14, SIGN-R18), and "Show news at login" turned on (SET-R37). At the session's first read of `ok` news, Core drops from `seen` every entry whose time is older than the seen age before `GetServerTime()`, longer than the news age (SIGN-R15), so an entry is kept while its item can still be due and the table holds at most what the block held over that time. It is account-wide, as the followed Anglers are the Player's. Losing it (a deleted `PagleDB`) only sets a new floor at the next login (SIGN-R18), so nothing old floods back.
- **VIEW-R45** **`Pagle.NewsWords(item)`** gives an item's words and emblem as the sign draws them (SIGN-R12, SIGN-R13, SIGN-R19): `{ kind, kicker, head, detail, emblem }`, the `PagleNewsSignNews` of [news-sign.md](news-sign.md) without its more line. A name the client hasn't loaded yet reads `SIGN_ITEM_UNKNOWN` at the call; a caller that draws again once `GET_ITEM_INFO_RECEIVED` fires gets it. So the Fish Journal's list says what the sign said, in the same words and with the same care for an uncaught variety (VAR-R27).
- **VIEW-R46** **`def.news(id?)`.** A Module may offer `def.news(id?)`, a view of the news (the Ledger's news list, LED-R176) that opens on the item with that `id` when given and present. Core calls the first On Module's that has one, by `def.order`, from the sign's left click (SIGN-R42), as it calls `def.collection` (CORE-R45); with none, the click only sends the sign up. A `news` that raises is reported through `geterrorhandler()`.

### The tooltip block

- **VIEW-R20** Core adds the block with `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, …)`, after the game's own lines, to the tooltip of any player unit with a card (VIEW-R10). Core owns it, so it shows with every Module off. The player's own characters show it too when their Angler is Published, read from the same files. A unit with no card gets nothing.
- **VIEW-R21** **The block**, in this order (the look and colours are variant A's, IGV-R81; the text here wins):

  | Line | Left | Right |
  |---|---|---|
  | gap | a small blank gap | |
  | header | the Pagle favicon (the compartment entry's gilt "P", CORE-R50) and "Pagle Angler", in Pagle teal | "Following", in green, only for a Followed Angler |
  | title | the title, in gold, without angle brackets so it can't be mistaken for the guild line; left out when there is none | |
  | level | "Angler Level", in parchment | "{L}"; with " · {emblem} Prestige {I–X}" at ranks 1–10, and " · {emblem} Master Prestige {n}" from rank 11, `n` being rank − 10 (LED-R34); `{emblem}` is the rank's Prestige emblem at 22, the Master's from rank 11, inline before its words (LED-R152, `Pagle.PrestigeEmblemMarkup`). At rank 0 the line is "{L}" alone, with no emblem and no space kept for one |
  | ledger | "Ledger" | "{p}%" |
  | legends | "Legends" | "{n} of {N}" |
  | hardcore | "Hardcore Angler", in red, only for a Hardcore Angler | |

  It names no region (IGV-R6). Master Prestige is written in words, as the bookplate writes it (LED-R146), because ★ is outside the client's fonts (CORE-R9). *Decided in the grilling on #76 (2026-10-22): #76 item 10 drew one ★ per rank above 10.* *Decided with the emblems in lists:* the emblem keeps LED-R152's list size of 22 rather than the line's height, as on the Prestige frame's tooltip (LED-R154), so its shape and colour still carry the rank; the words stay beside it, since the Master's emblem is the same from rank 11 on.
- **VIEW-R22** The block shows in combat and while restricted, since the unit tooltip isn't secure; it is only text added to the game's tooltip. A first hover in combat finds Followed Anglers only, as `Pagle_Anglers` loads after (VIEW-R3).

### Settings

- **VIEW-R30** **"Show other Anglers on player tooltips"** is a checkbox on the Settings root (SET-R10 row 11), on by default, bound to `PagleDB.profile.anglerTooltips`. Tooltip: "Adds a Pagle block to the tooltip of players whose Angler is on the Pagle website. Needs the Pagle Companion." Off means no block at all, and `Pagle_Anglers` is never loaded (VIEW-R3); turned on mid-session, the next hover outside restriction loads it. The Following spread doesn't depend on it.

## Data

| Key | Contents |
|---|---|
| `PagleDB.profile.anglerTooltips` | the tooltip setting, default `true` (VIEW-R30) |
| `PagleDB.global.news.since` | from 1.6: the floor, a server time, or nil before the first `ok` news (SIGN-R18) |
| `PagleDB.global.news.seen` | from 1.6: `{ [id] = time }`, the news items marked seen (VIEW-R44) |

Nothing else from the data files is stored (VIEW-R4).

## Contracts

| Function | Rules |
|---|---|
| `Pagle.GetFollowedAnglers()` → `{ state = "ok" \| "none" \| "expired" \| "absent", anglers = { … } }` | VIEW-R11 |
| `Pagle.GetNews()` → `{ state = "ok" \| "none" \| "expired" \| "absent", items = { { id, kind, time, angler, name, region, item, rank, key, text, zone, length, new }, … } }` (from 1.6) | VIEW-R42 |
| `Pagle.MarkNewsSeen(ids?)` (from 1.6) | VIEW-R43 |
| `Pagle.NewsWords(item)` → `PagleNewsSignNews` without `more` (from 1.6) | VIEW-R45 |
| `def.news(id?)`, a Module's (from 1.6) | VIEW-R46 |

Core-internal, from 1.6 (logic/Wiring.lua's `ns.WireAnglerViews`): `ns.SetNewsFloor()` sets the floor to `GetServerTime()` (SIGN-R18), for "Show news at login" turned on and a Defaults that turns it back on (SET-R37); `ns.anglerViews:NewsSeen(id)` tells whether an item is marked seen now, for the sign's decision (SIGN-R15); `ns.OpenNews(id?)` calls the first On Module's `def.news` (VIEW-R46) and returns whether one did, for the sign's left click (SIGN-R42).

`PagleFollowingData` and `PagleAnglersData` are read as [IGV Contracts › The addon folders](https://github.com/timemir/pagle-backend/blob/main/docs/spec/in-game-views.md#the-addon-folders) gives them: `Pagle_Following`'s plain tables, and `Pagle_Anglers`' packed strings, binary-searched by the 13-character search key formed from the unit's GUID.

## Tunables

| Name | Value | Rules |
|---|---|---|
| Expiry age | IGV's (24 h by `GetServerTime()`) | VIEW-R1, VIEW-R2 |
| File format versions read | 1 (its news block from 1.6, VIEW-R40) | VIEW-R1 |
| Seen age | 31 days: the news age (SIGN-R15) and a day (from 1.6) | VIEW-R44 |

## Edge cases

- **VIEW-R90 First install of the Companion.** New folders appear only at character select (IGV-R40), so until then both files are absent: no block, and the Following spread's absent state.
- **VIEW-R91 The Companion is closed, unlinked or refused.** Its files stay until it deletes them (IGV-R53) and expire 24 h after their `generatedAt`; from then on no block and the spread's expired state, mid-session too (VIEW-R2).
- **VIEW-R92 A broken or oversized file.** Lua 5.1 skips a chunk past ~262k constants with only a `LUA_WARNING`, so such a file runs as if empty; its missing `ok` makes it absent (IGV-R44), never a file with no Anglers.
- **VIEW-R93 The same GUID in both files.** `Pagle_Following` is read first (VIEW-R10), so a Followed Angler always shows "Following", though `Pagle_Anglers` holds them too (IGV-R4).
- **VIEW-R94 A hidden or unpublished character.** It isn't in either file (IGV-R2), so it gets no block; within 24 h of being hidden or unpublished every copy has gone or expired (IGV-R52).
- **VIEW-R95 The first hover loads `Pagle_Anglers`.** Loading 16 MB costs about 40–50 ms once (IGV Contracts › Size), on that first hover outside restriction; later hovers only binary-search.
- **VIEW-R96 A Companion without news** (from 1.6). One older than pagle-backend's news-aware release gets `Pagle_Following` without the news block (IGV-R65): the Anglers read as before, the news state is `none`, no sign drops, and the Fish Journal's news list says to update the Companion (LED-R179).
- **VIEW-R97 An item about an Angler since unfollowed** (from 1.6). The next download leaves it out (IGV-R66); until then it is in the file, and its `angler` still points at that Angler's card in the same file.
- **VIEW-R98 A news line Core can't use** (from 1.6): a kind it doesn't know, a field missing or of the wrong type. It is skipped and counted under `/pagle dev views` (VIEW-R12); the other lines and the Anglers are used.
