# Core: Field report

> Status: Done · Milestones: M3 · Sources: [Design the /pagle report format and issue form](https://github.com/timemir/wow-fish/issues/26#issuecomment-6124884698), [Define the content data pipeline](https://github.com/timemir/wow-fish/issues/19#issuecomment-6113646946), [Define the Core data model](https://github.com/timemir/wow-fish/issues/10#issuecomment-6112707372); ADR 0003, 0004, 0006

Part of [Core](README.md). A **Field report** is the text an Angler copies out of Pagle to share what they've seen that the content data doesn't yet confirm. This file covers the in-game side: what goes in, the text format, and the box. Turning a pasted report into `data/observed/` (issue form, parser, Action, importer) belongs to `docs/spec/content-data.md`, which must accept exactly the format below.

## Purpose and boundary

**Owns:** the Field report projection, choosing what to include, the `PAGLE-REPORT` text format, the reporter key, splitting into parts, the report box, and its entry points.

**Doesn't own:** the catalogue's `confirmed` rules or the two-reporter rule (the generator's), filtering known pool text and bobber text (the tooling's), the GitHub issue form, the parser or the importer.

## Rules

### General

- **REP-R1** A Field report carries observations only: never the Catch log, never per-Cast lines, and nothing that names the Angler's characters.
- **REP-R2** It covers the whole Catch log, every time. No "last reported" state exists anywhere; reported facts keep appearing until a release confirms them.
- **REP-R3** A Cast's **report area** is its subzone areaID, or its zone areaID when the subzone is `0`. Casts whose zone and subzone are both `0` are left out of every row (their names are in the diagnostics buffer already, LOG-R81).
- **REP-R4** A Cast's **build** is the build of the latest `B1` entry before it in the log (LOG-R36), or `0` if there is none.
- **REP-R5** Times in rows are realm time: the Cast's realm minute (LOG-R20) and the realm month derived from its server time (LOG-R49).

### Which Catches go in `I` rows

- **REP-R10** A Catch **qualifies** for an `I` row when any of these holds. "Its catch entry" is the item's entry in `Pagle.GetArea(reportArea).catches`, else in `Pagle.GetArea(zone).catches` for the Cast's zone: each area's own list, never the union from `GetZoneCatches`.

  | Case | Test |
  |---|---|
  | Uncharted | `Pagle.GetItem(itemID)` is `nil` (item `0` is never reported) |
  | Unlisted pair | the item is known and not Noise, and has no catch entry |
  | Unconfirmed pair | its catch entry has `confirmed = false` |
  | Outside its window | its catch entry has a `gate`, and `Pagle.MatchesConditions(gate, cast.conditions)` is false |
  | Unconfirmed window | its catch entry has a `gate` with `gateConfirmed = false` |
  | Aura or event Cast | the Cast had a listed fishing aura or a listed fishing-relevant calendar event active, and the item isn't Noise |

  Noise items qualify only when Uncharted, which they can't be, so Noise never appears. Junk and treasure qualify like any other item.
- **REP-R11** Each qualifying Catch counts **once**, in exactly one `I` row, whose key is: report area, item, build, the sorted active listed auras, the sorted active listed events, and its time bucket and month only when REP-R20 emits them. Quantities are not summed; a row counts Catches.
- **REP-R12** A window, in this file, is a catch entry's `gate`: a condition spec with any of `time`, `season` and `events` (LOG-R48).

### Rows

- **REP-R20** **`I` rows**: `I <itemID> <areaID> <build> <count>`, plus optional keys:
  - `aura=<id,id…>` and `event=<id,id…>`: the Cast's active listed auras and events, ascending, comma-separated; left out when none
  - `t=<HH:MM>` and `m=<month>`: only for items whose catch entry has a `gate`, and for Uncharted items. `t` is the start of the Cast's 15-minute realm-time bucket; `m` is the realm month, 1–12. Both are emitted together, whatever kind of window the gate has. A Cast with no realm minute (recorded while the realm clock was secret, LOG-R49) has neither: its row leaves out both, and so does its key (REP-R11). Such a row is never time-gated evidence, inside or outside a `time` or `season` gate (DATA-R51).
  No row carries a server timestamp.
- **REP-R21** **`K` rows**, for skill evidence. An area **qualifies**, across all builds, when its catalogue entry has a `skillBase` with `skillBaseConfirmed = false`, or when its `skillBase` is **contradicted**: some Cast there caught a non-junk, known item at an effective skill (rank + modifier) below `skillBase`. The `skillBase` used for a Cast is its report area's, else its zone's; the row's area is the area that `skillBase` came from. A qualifying area gets one row per build that has Casts there: `K <areaID> <build> casts=<n> away=<n> land=<skill> lost=<skill>`, where:
  - `casts` counts every Cast there (caught and got away), `away` the got-away ones
  - `land` is the lowest effective skill of a Cast that caught a non-junk, known item; `lost` is the highest effective skill of a got-away Cast
  - `land` or `lost` is left out when there is no such Cast. A row is still emitted with only `casts` and `away`.
- **REP-R22** **`P` rows**, from the diagnostics buffer (the last 500 Casts, LOG-R81), computed on demand when the box opens and when the count is asked for, never stored. One row per report area × locale × hovered text: `P <areaID> <locale> "<text>" casts=<n> <itemID>x<count> …`:
  - a Cast with 3 hovered texts counts once toward each of its 3 rows
  - `casts` includes got-away Casts
  - the items are every item caught on those Casts, junk included, as total quantities, ascending by item ID
  - every text is included, bobber text and known pool names too: the catalogue ships no names (LOG-R56), so the tooling filters them
- **REP-R23** Rows are sorted by kind (`I`, `K`, `P`), then numerically by area ID, then:
  - `I`: item ID, build, `aura`, `event`, `t`, `m`. An absent key sorts first; `aura` and `event` lists compare element by element as numbers, a list that is a prefix of another first.
  - `K`: build
  - `P`: locale, then text by byte order

### The projection

- **REP-R25** Core keeps a **Field report projection** in `PagleDB.global.projections.fieldReport`, run by the projection machinery (LOG-R70–R77) with its own rules version: it catches up from its `lastSeq` and rebuilds when the content fingerprint or its rules version changes. It holds the `I` and `K` aggregates and their row count. It is derived data, not report history.
- **REP-R26** `Pagle.GetFieldReportCount()` returns the number of `I`, `K` and `P` rows: the projection's count plus the `P` rows computed from the buffer. While the projection is updating, it returns the projection's last stored count plus the `P` rows computed now.

### Format

- **REP-R30** A report is plain, line-based UTF-8 text:

  ```
  PAGLE-REPORT 1
  addon 0.9.0 data 3f9a2c1e locale deDE reporter f38e76b0 part 1/1
  I 6362 33 70338 2 aura=1280341            # Raw Spotted Yellowtail, Stranglethorn Vale
  I 13755 331 70338 6 event=301 t=14:30 m=5 # Winter Squid, Ashenvale
  I 6359 1519 70338 14                      # Stormwind City
  I 13760 2657 70338 3 t=21:15 m=11         # Raw Sunscale Salmon, Feralas
  K 1519 70338 casts=40 away=6 land=75 lost=60 # Stormwind City
  P 1519 deDE "Schwarm öliger Schwarzmaulfische" casts=5 6358x5 # Stormwind City
  END
  ```

  - Line 1 is the format version.
  - Line 2 is the header: the addon version (`C_AddOns.GetAddOnMetadata("Pagle", "Version")`), the first 8 characters of `Pagle.CONTENT_FINGERPRINT` (lowercase hex), the reporting client's `GetLocale()`, the reporter key, and the part number.
  - A comment is ` # ` followed by names in the player's locale, for humans only: `I` rows get the item name (left out if `C_Item.GetItemInfo` hasn't cached it), then the area name; `K` and `P` rows get the area name.
  - `END` closes every part, so a truncated paste is detectable.
- **REP-R31** Parsers treat ` # ` outside double quotes as the start of a comment and ignore the rest of the line. They ignore unknown `key=value` keys, so adding a key needs no version bump; a changed meaning of anything existing bumps `PAGLE-REPORT`.
- **REP-R32** Inside quotes, `\` escapes `"`, `\` and `n` (a newline). A carriage return in a text, alone or before a newline, is written as `\n` too, so a pasted row never splits.
- **REP-R33** A report over 60,000 bytes (header and `END` included) is split into numbered parts (`part 1/2`), each with its own two header lines and `END`, each at most 60,000 bytes, never truncated. Rows fill each part in sort order before the next part starts.

### Privacy

- **REP-R35** Left out: character names, surnames, GUIDs, realm, faction and `logId`.
- **REP-R36** The **reporter key** is the FNV-1a 32-bit hash of the bytes of `PagleLog.logId` (the 16-character string), as 8 lowercase hex characters, zero-padded. Test vector: logId `3f9a2c1e7b0d4a65` gives `f38e76b0`. It is stable per Angler, so duplicates and replacements can be spotted, but it can't be traced to a character.
- **REP-R37** The box says, above the text: "This will be posted publicly. It contains no character names."

### The box and its entry points

- **REP-R40** `/pagle report` and `Pagle.OpenFieldReport()` open the **report box**: a sea chart titled "Help chart the waters" (see [UI](#ui)) with:
  - the privacy line (REP-R37), and "Ctrl+C to copy" beside it
  - the report text typed on a slip, in a read-only, selected edit box (Ctrl+C to copy) that scrolls
  - "Part N of M" between a previous and a next arrow, hidden when there is one part; the box always opens at part 1
  - the issue-form URL, after "POST IT AT", in a second selectable edit box (addons can't open a browser), shown from its start ("https://…") whenever the box opens, the URL is put back or that edit box loses the focus
  - Close, and a brass X (Esc closes it too)
  The text is built when the box opens and isn't refreshed while it stays open.
- **REP-R41** If no row qualifies, the box says "Nothing to report. Thanks for checking!" and shows no text or URL.
- **REP-R42** While the projection is updating, the box says "Updating... try again in a moment." and shows no text.
- **REP-R43** The box is also reached from the compartment menu entry "Help chart the waters" (with the row count when above 0, CORE-R50) and the button in Core's Settings root (CORE-R40). The Ledger's Journal calls `Pagle.OpenFieldReport()` from an Uncharted fish or a zone with no data.
- **REP-R44** While `Pagle.IsRestricted()` is true, no entry point opens the box; each prints one chat line ("Pagle: the Field report opens after combat."). A box already open stays open.
- **REP-R45** Nothing about the Field report ever pops up on its own: it isn't an Announcement (nothing was earned) and it isn't a Nudge.
- **REP-R46** The issue-form URL is `https://github.com/timemir/wow-fish/issues/new?template=field-report.yml`. 1.0 accepts reports through GitHub only; players who won't use GitHub can post the text anywhere for the dev to paste in.
- **REP-R47** The box has a fixed size, 520 × 360, centred on the screen, whatever the report's length: the report text scrolls inside it and never grows the box.

## Data

| Key | Contents |
|---|---|
| `PagleDB.global.projections.fieldReport` | projection bookkeeping (LOG-R70) plus the `I` and `K` aggregates keyed by row key, and `count` |

The report text and `P` rows are built on demand and never stored.

## Contracts

| Call | Rules |
|---|---|
| `Pagle.OpenFieldReport()` | REP-R40–R44 |
| `Pagle.GetFieldReportCount()` → integer | REP-R26 |

The format in REP-R30–R33 is a contract with the repo's parser (`docs/spec/content-data.md`): parser and Core change together, and a changed meaning bumps the version. The catalogue fields this file reads (`catches`, `confirmed`, `gate`, `gateConfirmed`, `skillBase`, `skillBaseConfirmed`, `noise`, the aura and event lists) are defined in LOG-R55 and LOG-R56.

## UI

The report box (REP-R40–R42, REP-R47), in the QoL and Field report art kit's look (`PagleArtField`, post-1.0 art): a frame of Core's own, no template, drawn from `media/field/Chart.blp` (the chart with the slip, and the bare chart for REP-R41's and REP-R42's lines; 2.7 MB) and `media/field/Field.blp` (the compass, the brass arrows and X, the leather Close, the scroll thumb; 1.3 MB), both BLP2 with mipmaps and made only when the box first opens. Positions are the kit's, from the box's top left: the compass at 22, 16, the title in IM Fell English beside it; the privacy line in its italic at 22, 58; "Ctrl+C to copy" in Caveat at the right; the slip's text in Cutive Mono from 34, 92, 426 × 156, scrolled by the mouse wheel or the brass thumb down its right edge (shown only while the part is longer than the slip), and following the cursor; "POST IT AT" in red from 22 with the URL in Cutive Mono on the line 279 down, the label ending before the chart's URL field at 90 (set smaller, down to three quarters of its size, if the client draws it wider) and the URL box starting after it, at 98 or later, so the two never overlap; on the line 324 down, the arrows with "Part N of M" in Caveat on the left, and Close at the centre. A greyed arrow can't page further. A message (REP-R41, REP-R42) is in Caveat on the bare chart, with no slip, hint, URL or part controls.

Its motion and sounds are the kit's (its `MOTION.md` and `SOUND.md`), on Core's motion driver: opening, the box plays `IG_MAINMENU_OPEN` (sound kit 850) and fades in over 0.2 s (ease-out); Close and the brass X give back the keyboard at once, play `IG_MAINMENU_CLOSE` (851) and fade it out over 0.15 s (ease-in), then hide it; Esc hides it at once with the same sound. Close and the arrows play `IG_MAINMENU_OPTION` (852) on a click. Opened again while it fades out, it fades back in. With the Animations setting off (`Pagle.IsAnimationsOn()`, SET-R30) it shows and hides at once; the sounds still play. They are UI foley on the SFX channel (`PlaySound(id, "SFX")`), the same in every sound set, which owns only an Announcement's sounds (ANN-R70).

## Settings

None of its own; the Settings root has its button (CORE-R40).

## Tunables

| Name | Value | Rules |
|---|---|---|
| Time bucket | 15 min | REP-R20 |
| Part size limit | 60,000 bytes | REP-R33 |
| Reporter key | 8 hex, FNV-1a 32-bit of `logId` | REP-R36 |
| Field report rules version | 2 | REP-R25 |
| Format version | `PAGLE-REPORT 1` | REP-R30 |
| Report box size | 520 × 360 | REP-R47 |

## Edge cases

- **REP-R90 Module disabled, then enabled again.** Not relevant: the Field report reads only Core's log, catalogue and diagnostics buffer, so it works the same with any Modules enabled.
- **REP-R91 Projection rebuild.** A new content fingerprint rebuilds the projection (REP-R25), so a release that confirms facts shrinks the next report on its own. While it rebuilds, REP-R26 and REP-R42 apply.
- **REP-R92 First build over existing history.** The projection's first build covers the whole log; no Write-up, since the Field report earns nothing.
- **REP-R93 In combat.** REP-R44.
- **REP-R94 Crash mid-Session.** Casts lost in the crash are missing from reports, like everywhere else.
- **REP-R95 Daily or weekly reset.** No rule here depends on it.
- **REP-R96 Uncharted or unconfirmed Catch.** These are exactly what the report carries (REP-R10, REP-R21).
