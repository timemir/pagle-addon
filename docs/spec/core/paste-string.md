# Core: Paste string

> Status: Done · Milestones: Track P Paste string · Sources: [The Paste string: export the log for the Pagle website (1.0)](https://github.com/timemir/pagle-addon/issues/361), [Amendments from the Pagle backend](https://github.com/timemir/pagle-addon/issues/76) items 3 and 4, pagle-backend's [upload.md](https://github.com/timemir/pagle-backend/blob/main/docs/spec/upload.md) (UPL); ADR 0003, [Catch log hardening](https://github.com/timemir/pagle-backend/issues/302)

Part of [Core](README.md). A **Paste string** is the no-install way to get the Catch log onto the Pagle website: the Player copies it out of Pagle's export window and pastes it on the website's Paste upload page. What a Paste string holds is pagle-backend's: [upload.md](https://github.com/timemir/pagle-backend/blob/main/docs/spec/upload.md) is canonical for it (UPL-R50–R52, Contracts › The Paste string and › The upload document), and its decoder is built. This file cites those rules rather than restating them, and fixes only how Core builds one, the export window, and the last exported seq.

## Purpose and boundary

**Owns:** building upload documents from `PagleLog`, cutting an export into parts, the CRC-32, compressing and print-encoding each part into a Paste string, the export window and its entry points, the last exported seq per `logId`, and `/pagle dev pastetest`.

**Doesn't own:** the upload document's grammar, the Paste string's prefix and encoding, the Paste part cap and every check the website makes (UPL-R10, UPL-R50–R52, UPL Contracts); what the website does with a Paste (UPL-R30–R39, UPL-R81); the Companion, which uploads the same document without a Paste string; LibDeflate itself (CORE-R6).

**Uses:** `PagleLog` (catch-log.md › Data), content checkpoints (pagle-backend UPL-R32), `GetServerTime()`, the restriction state (CORE-R30), the Field report box's art kit (field-report.md › UI), Core's motion driver.

## Rules

### General

- **PST-R1** A Paste string carries `PagleLog` alone: its `logId`, `format`, `characters` and `entries`, in the upload document of UPL Contracts. Nothing from `PagleDB` or any Module's SavedVariables goes in. Building one writes nothing to `PagleLog`; the only things it ever stores are the last exported seq (PST-R40) and the content checkpoints kept for the next export (PST-R42).
- **PST-R2** Only the export window builds Paste strings, when the Player opens it or picks a choice in it. Nothing about it pops up on its own, and nothing is built in the background.

### The upload document

- **PST-R10** Each part is a complete document version 2: `PGL|2|<logId>|<format>|<as-of>|<total>|<chars>|<from>|<anchor>|<count>|<body-bytes>|<body-crc>`, followed by the ordered character lines and exact entry bytes, each ending in LF. Record format is 3. The anchor is the cumulative content digest at `from - 1`, including the initial digest for `from = 1`. It binds sequence, character GUID, and exact record bytes under the shared backend contract. It is never an entry ID or empty string.
- **PST-R11** `body-bytes` is the number of bytes after the header's LF, in decimal (the grammar's `nat`); `body-crc` is the CRC-32 of those bytes as 8 lowercase hex digits. The CRC-32 is UPL Contracts' (zlib / ISO-HDLC: polynomial 0x04C11DB7 reflected, initial and final XOR 0xFFFFFFFF), whose check value for the ASCII bytes `123456789` is `cbf43926`. LibDeflate has none (UPL-R52), so Core's `logic/` computes it on the client's `bit` library.
- **PST-R12** A character line is `guid|name|surname|classID|raceID|faction|realmID|hardcore|firstSeen|lastSeen` (UPL Contracts' `character`, LOG-R26's fields). It never has a `selfFound` field (UPL Contracts), which the character table no longer holds either (LOG-R26, [#363](https://github.com/timemir/pagle-addon/issues/363)); one an older dev log still holds is left out. `surname` is empty when the character has none; `hardcore` is `1` or `0`, and empty when the log holds `nil`.
- **PST-R13** A character line always fits the grammar, whatever the log holds:
  - `name` and `surname` keep only field bytes that make valid UTF-8 (UPL Contracts' `field-byte`, UPL-R10 step 5): every byte below 0x20 (LF and CR among them), 0x7F, `|`, and any byte that isn't part of a well-formed UTF-8 sequence is left out. A `name` left empty is written `?`; a `surname` left empty is empty.
  - A number field that isn't a whole number from 0 is written `0`, and a `faction` that isn't letters only is written `Unknown`.

  The client never records such values (LOG-R25, LOG-R26, and LOG-R101 for a line feed); this keeps a damaged log exportable.
- **PST-R14** Every entry line preserves the stored byte string exactly. An entry containing LF makes export fail rather than removing or repairing bytes. Export never changes record identities or authoritative history.
- **PST-R15** Core refuses export when the log ID, characters, character GUIDs, entry headers, resolved indexes, or line boundaries cannot be represented correctly. It verifies every exported entry, and every prefix entry it hashes for the content digest; a prefix entry before a kept checkpoint (PST-R42) was verified when that checkpoint was hashed. The window shows **Pagle can't export this Catch log** and marks nothing. Backend canonical validation still checks every ranked field; a local export is not proof of valid gameplay.
### Exports and parts

- **PST-R20** An **export** is made each time the window opens and each time the Player picks a choice (PST-R51). Its **as-of** is `GetServerTime()` then and its **total** the log's length then, the same in every one of its parts (UPL-R52). Entries appended while the window stays open wait for the next export.
- **PST-R21** "Everything" exports from `seq` 1. "New since last export" exports from one after the log's last exported seq (PST-R40), or from 1 when it has none. When that is past the total, there is nothing new: the window says "Nothing new since your last export." and shows no string.
- **PST-R22** An export's entries are cut, in `seq` order, into **parts** of at most the part size (Tunables), numbered "Part 1 of k". Each part has its own `from`, `anchor`, `count`, `body-bytes` and `body-crc`, and the same characters table, as-of and total (UPL-R52). An export with no entries (Everything on an empty log) is one part with `count` 0.
- **PST-R23** The part size never exceeds the Paste part cap (UPL-R51, UPL Tunables), which the website refuses a longer part at (`paste_too_long`). Raising it follows the copy test (PST-R60) and the backend raising its cap first.

### The Paste string

- **PST-R30** A part's Paste string is `!PGL2!` followed by LibDeflate 1.0.2's `EncodeForPrint` of its `CompressDeflate` (raw DEFLATE, at LibDeflate's default level) of the part's document (UPL-R50, UPL Contracts › The Paste string). LibDeflate is the vendored copy (CORE-R6).
- **PST-R31** A Paste string is one unbroken run of the print alphabet (`a`–`z`, `A`–`Z`, `0`–`9`, `(`, `)`) after its prefix: no space, line break or other whitespace, which the website refuses inside it (UPL-R50). The export window shows it on one line and never wraps it.
- **PST-R32** One submission carries one Paste string (UPL-R50), so the Player copies and pastes each part on its own, in order. A part pasted before the one ahead of it is refused as a gap until that one arrives (UPL-R52), and a part pasted twice is taken as unchanged (UPL-R34).
- **PST-R33** A part is compressed only when first shown and is cached within that captured export. Prefix digests are calculated once in sequence and cached at part boundaries; preparing later parts does not hash every prior entry again. The export captures total, metadata, and as-of consistently, while new records wait for the next export. Preparation yields to the existing frame budget.
### The last exported seq

- **PST-R40** `PagleDB.global.pasteExports[logId]` is the log's **last exported seq**: the highest last `seq` (`from + count − 1`) of a part the Player has copied. A copy is Ctrl+C, or Cmd+C on a Mac, pressed in the string's box. Showing a part doesn't mark it, and a part with no entries marks nothing. The mark only rises. A mark for another `logId` is kept, for that log's return (a restored backup).
- **PST-R41** Why a copy and not a showing: a part shown but never pasted would leave the next "New since last export" starting past entries the website never got, which it refuses as a gap (UPL-R31) until the Player exports Everything. A part copied but not pasted costs only a repeat, which the website takes as unchanged (UPL-R34).
- **PST-R42** An export keeps the content checkpoint after every part-size-th entry it hashes (seq 5,000, 10,000, …) in `PagleDB.global.pasteCheckpoints`, with that entry's bytes, and the next export of the same log and format starts hashing from the highest kept checkpoint at or below its first anchor, so an export hashes at most one part size of entries before its first part, however long the log. A kept entry that is no longer the log's entry at its seq drops every kept checkpoint. Another log or format replaces them, and Recovery discards them (RCV-R6). A wrong checkpoint can only make the website refuse the anchor; it is never trusted as proof.

### The export window

- **PST-R50** `/pagle export`, `Pagle.OpenPasteExport()` and the Settings root's button (SET-R10 row 12) open the **export window**. While `Pagle.IsRestricted()` is true no entry point opens it; each prints one chat line, "Pagle: the export window opens after combat.", and a window already open stays open (CORE-R33).
- **PST-R51** The window shows, from the top:
  - the title, "Export for the website";
  - the privacy line, "Holds your characters' names. Paste it only on the Pagle website.", and "Ctrl+C to copy" beside it;
  - the two choices, "New since last export" and "Everything". The window always opens on "New since last export"; picking one makes a new export (PST-R20) and shows its part 1, and picking the one shown changes nothing;
  - the part's Paste string in a read-only, selected and focused one-line edit box, so Ctrl+C copies all of it; typing in it puts the string back, selected;
  - under it, "Entries {from}–{last} of {total}" (or "No entries" for a part with none) and the string's size, "{n} KB" (1,024 bytes, rounded up), then, when there is more than one part, "Paste each part on its own, in order.";
  - "PASTE IT AT" and the Paste upload page's URL (Tunables) in a second read-only edit box, shown from its start;
  - "Part N of M" between a previous and a next arrow, hidden when there is one part; the window always opens at part 1;
  - Close, and a brass X; Esc closes it too.

  Instead of the string, its lines and the parts, the window says "Nothing new since your last export." (PST-R21) or "Pagle can't export this Catch log." (PST-R15); the choices stay.
- **PST-R52** What the window shows is built when it opens and when a choice is picked, and isn't refreshed while it stays open (PST-R20).
- **PST-R53** The window has a fixed size, 520 × 360, centred on the screen, whatever the string's length.

### The copy test (dev)

- **PST-R60** `/pagle dev pastetest <KB>` (dev mode, #247) shows a **test string** of exactly that many KB (1,024 characters each, from 1 to 2,048) in the export window's string box, with "Copy test: {n} KB" on the line under it, so the dev can check on the live client whether a string that long survives being copied out of the game (launch re-verification check 25: 64, 128, 256 and 512 KB). It marks nothing (PST-R40), and the window's choices make a real export again. The test string is runs of 16 characters, each `(`, the run's offset in characters as 8 decimal digits, and `PGLtest`, so a paste that lost or broke a run shows where; its last run starts at its length less 16. Without a number, or with one out of range, it prints its usage.

## Data

| Key | Contents |
|---|---|
| `PagleDB.global.pasteExports` | `{ [logId] = seq }`, each log's last exported seq (PST-R40); default `{}` |
| `PagleDB.global.pasteCheckpoints` | `{ logId, format, at = { [seq] = { digest, entry } } }`, the content checkpoints kept for the next export (PST-R42); default `{}` |

No Paste string or document is stored (PST-R2).

## Contracts

| Call | Rules |
|---|---|
| `Pagle.OpenPasteExport()` | PST-R50–R53 |

The document and the Paste string are a contract with pagle-backend's decoder (UPL-R10, UPL-R50, UPL Contracts): Core and that file change together, and the document version in the prefix and the header (`1`) changes with any change to their shape. `spec/Pagle/fixtures/PasteString.lua` holds a Paste string Core built and the document it decodes to, as a test vector for both sides.

## UI

The export window (PST-R50–R53) is drawn in the Field report box's look (field-report.md › UI): the same sea chart with its slip, compass, brass X and arrows, leather Close, fonts, inks, motion and sounds (`IG_MAINMENU_OPEN`, `IG_MAINMENU_CLOSE`, `IG_MAINMENU_OPTION`), on the same canvas positions where the two share a part: the title, the privacy line and the copy hint, the URL line at 279 down (with "PASTE IT AT"), and the part controls and Close at 324 down. On the slip, from 34 across: the two choices in Caveat at 104 down, the chosen one in the chart's sea ink after a bullet and the other in the hint's ink; the string's one-line box in Cutive Mono at 140 down, 426 wide; its lines under it at 168 and 188 down. A message (PST-R15, PST-R21) takes the string's place on the slip, in Caveat.

## Settings

None of its own; the Settings root has its button (SET-R10 row 12).

## Tunables

| Name | Value | Rules |
|---|---|---|
| Document version, and the prefix | `2`, `!PGL2!` | PST-R10, PST-R30 |
| Part size | 5,000 entries, the Paste part cap of UPL Tunables (provisional there until the copy test) | PST-R22, PST-R23 |
| Characters cap | 100, UPL Tunables' | PST-R15 |
| Paste upload page | `https://pagle.app/me/paste` | PST-R51 |
| Export window size | 520 × 360 | PST-R53 |
| Test string sizes | 1 to 2,048 KB; the check copies 64, 128, 256 and 512 | PST-R60 |

## Edge cases

- **PST-R90 Module disabled, then enabled again.** Not relevant: a Paste string reads only `PagleLog`, so it is the same with any Modules enabled.
- **PST-R91 Projection rebuild.** Not relevant: nothing here reads a projection.
- **PST-R92 First build over existing history.** Not relevant. The first export of a log with no mark starts at 1 either way (PST-R21).
- **PST-R93 In combat.** PST-R50: the window doesn't open while restricted, and one already open stays open, as the Field report box does.
- **PST-R94** An export can include observations still only in memory. If a later crash loses them after the website admitted them, another local branch cannot overwrite the accepted bytes. The shorter or divergent local branch requires Recovery. Copy marks are convenience state and never establish server acceptance.
- **PST-R95 Daily or weekly reset.** Nothing here depends on it.
- **PST-R96 Uncharted or unconfirmed Catch.** Entries go verbatim (PST-R14); what the website makes of them is its own.
- **PST-R97 A new dev log or a new `logId`.** A log started over (LOG-R18) has a new `logId` and no mark, so "New since last export" exports all of it.
- **PST-R98** A shorter local backup may have a copy mark beyond its end. **Everything** lets the server compare the complete local copy, but never replaces or truncates Accepted history. An exact shorter copy requires [Recovery](recovery.md) without alleging a contradiction. A different accepted observation is an Integrity conflict.
- **PST-R99 Two machines.** Each `PagleLog` has its own `logId` and mark (LOG-R97); a `WTF` folder copied to a second PC shares both, and the website settles the two forks (UPL-R99).
