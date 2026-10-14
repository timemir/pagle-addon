# In-game verification

An agent can't run the WoW client, but it can read what the client writes to disk. After the dev does a `/reload` or a logout and says so, an agent reads the results from the WTF folder with `scripts/read-wtf.lua`, and the dev reads nothing. #77 tried Mechanic for this and dropped it: the files hold almost everything an agent needs.

## Where the files live

The Forever beta is in `_classic_beta_` under the WoW install. On the dev's machine that's `G:\World of Warcraft\_classic_beta_`, which WSL reaches as `/mnt/g/World of Warcraft/_classic_beta_`. The live install's folder name is unknown until launch (Nov 4).

Under `WTF/Account/<ACCT>/` (find `<ACCT>` with `ls WTF/Account/`; skip its `SavedVariables` folder):

| Fact | File | Format |
|---|---|---|
| Lua errors with stacks | `SavedVariables/!BugGrabber.lua` | `BugGrabberDB`. The latest session is the errors whose `session` equals `BugGrabberDB.session`. Needs `!BugGrabber` installed. |
| Catch log, wallet, cards, Field report | `SavedVariables/Pagle.lua` | `PagleLog` and `PagleDB` ([catch-log.md › Data](../spec/core/catch-log.md#data), [wallet-and-shop.md › Data](../spec/core/wallet-and-shop.md#data), [announcements.md › Data](../spec/core/announcements.md#data), [field-report.md › Data](../spec/core/field-report.md#data)). Pagle writes no SavedVariables before M1, so the file is missing until then. |
| Ledger | `SavedVariables/Pagle_Ledger.lua` | `PagleLedgerDB` ([ledger.md › Data](../spec/ledger.md#data)). Missing until Pagle_Ledger (M2) has run. |
| Account CVars (`SoftTargetInteract` etc.) | `config-cache.wtf` | `SET <name> "<value>"` lines |
| Character CVars | `<realm folder>/<Name-Surname>/config-cache.wtf` | the same |
| Machine CVars | `WTF/Config.wtf`, two levels up | the same |
| Addon enable state | `<realm folder>/<Name-Surname>/AddOns.txt` | `<Addon>: enabled` or `: disabled` lines. An addon that isn't listed has its TOC's default state. |

The realm folder is `70` on the beta. Characters are `<Name>-<Surname>` folders in it (find them with `ls`). The client writes CRLF line ends and keeps the previous copy of each file as `.bak` or `.old`; the script reads only the current one.

Values that exist only while the client runs, like `C_Spell.GetSpellName(7620)` or `Pagle.API_VERSION`, aren't in any file. They stay a dev `/dump`.

## The reader

Run it in WSL, with the Lua 5.1 from `scripts/setup.sh`. `scripts/read-wtf.sh` runs it on that Lua from any directory:

```sh
scripts/read-wtf.sh "/mnt/g/World of Warcraft/_classic_beta_/WTF/Account/<ACCT>" \
    --character 70/<Name-Surname> [--cvar <name>]... [--addon <name>]... [--catalogue <Catalogue.lua>] \
    [--expect-casts N] [--since T]
```

It prints eight sections, and a ninth with `--expect-casts`:

- **Lua errors:** the latest !BugGrabber session's errors, each with its count and stack, or `0 errors`.
- **Catch log:** `PagleLog` decoded with Core's own codec (`addons/Pagle/logic/CatchLog.lua`), so it reads entries exactly as Pagle does: the format, logId, character and entry counts, `PagleDB.global.decodeErrors`, the entries by tag, the entries the codec can't decode, repeated entry IDs, the `C1` Casts and their time span, by outcome, per character and per zone areaID, the Casts in zone areaID 0 by seq, and the `B1` and `S1` entries. A log in another format than the codec's is reported, not decoded.
- **Ledger:** `PagleLedgerDB` from `Pagle_Ledger.lua`. One line when the file or `PagleLedgerDB` is missing. Otherwise, in order:
  - `projection:` the stored `lastSeq`, `logId`, `fingerprint` and `rulesVersion`. Then `logId:` whether it matches `PagleLog`'s (a different one is flagged `DIFFERS`: Core rebuilds at login), `lastSeq:` whether it equals the log's length, and `rulesVersion:` whether it is the Ledger's own (`LEDGER_RULES_VERSION` × 100, so 200 in M3; any other is flagged `DIFFERS`: Core rebuilds at login).
  - `world:` the catalogue the Ledger's world index was built from, its fingerprint, whether that is the projection's (flagged `NOT the projection's` otherwise: the computed lines then use a different catalogue than the game did), and its charted zone count. One `can't load` line instead when the catalogue doesn't load, and then nothing below is computed.
  - `state:` the Casts, Catches, XP, Coins and Species count, with the Angler Level.
  - `state curio items:` and `state trophy items:` each caught item with its Catches (`6309 ×2`), classed by the Ledger's own `ClassifyCatch`; `state other items:` only if some item is neither now.
  - `state Uncharted:` the Uncharted list: one line per item ID with its Catches and its Catches per zone.
  - `state zones:` one line per fished zone: its computed rank (`none` in an M2 state), whether it is charted, and its shown rank.
  - `completion:` Ledger completion, its percent, done and total, each part's "x of N" (Species, junk, treasure, trophy, zones at Master), and the Legends beside it.
  - `celebrated` lines: the highest level, Coins, Species, Species × zone pairs, zones with their celebrated rank, Species stars and family stars (the stars in all, then each one's, as `6303 ★1 ★2`), curio and trophy items, Uncharted item IDs, and Skill Milestones.

  Everything computed (the level, charted, shown ranks, completion, the classes) comes from the Ledger's own `logic/` files, over the world index built from the repo's `addons/Pagle/data/Catalogue.lua` with Core's `logic/Catalogue.lua`. `--catalogue <file>` builds it from another, such as the installed addon's `Interface/AddOns/Pagle/data/Catalogue.lua`, when the repo's has moved on.
- **Wallet:** the balance, and each Module's last reported total from `PagleDB.global.coins.earned`.
- **Cards:** from `PagleDB.global`: each `writeUp` section's heading and lines; each card in `cards` with its title ("Your last session" for a `whileAway` one, otherwise "Session summary"), numbers, Coins, lines and its moments' titles by Module; the open `summary`'s moment count and lines; and the `pending` moment count.
- **Field report:** `PagleDB.global.projections.fieldReport`: the reporter key of `PagleLog.logId` (REP-R36, from Core's own `logic/FieldReportText.lua`) on the heading line; the projection's `lastSeq`, `logId`, `fingerprint` and `rulesVersion` with the same `logId:` and `lastSeq:` checks as the Ledger's; and `count:`, the I and K rows stored (the box's count adds the P rows built in the game). One line, the heading's, when no projection is stored yet.
- **CVars:** each named CVar from every file that sets it. `--cvar` defaults to `SoftTargetInteract`.
- **Addons:** each named addon's state. `--addon` defaults to `Pagle`, `Pagle_Ledger` and `Pagle_QoL`.

AceDB leaves out of the file every value equal to its default, so a missing `decodeErrors`, `coins`, `writeUp`, `cards`, `summary`, `pending` or celebrated set reads as its default: 0 or empty.
- **Exit check (#75 steps 3 and 4)**, with `--expect-casts N`, the dev's Cast count: one `ok` or `FAIL` line each for N `C1` Casts, no repeated entry ID among them, none in zone areaID 0, a `B1` and an `S1` entry, `decodeErrors` 0, every entry decoding, and at least one got-away Cast (`g`). It comes last, so the verdict is the last line.

`--since T` counts only the Casts at server time T (Unix seconds) or later, so earlier sessions don't change the count; `B1` and `S1` are still looked for in the whole log, since Core writes them only when the build or the skill changes. Naming a `--cvar` or `--addon` replaces its defaults. Without `--character`, the character's CVars and addons are skipped. The script loads SavedVariables files as data in an empty environment and never runs them with globals.

Exit codes: 2 on a usage error, 1 when an `--expect-casts` check fails (a missing `Pagle.lua` fails it too), otherwise 0, whatever the files hold.

## Protocol

1. **Ask for one action.** Tell the dev exactly what to do in the game: `/reload`, log out to the character screen, or quit. Say which one; the write timing below decides it.
2. **Wait for the dev to say it's done.** Don't read before that: the files hold the last write, not the live game.
3. **Check the write happened.** `ls -l --time-style=full-iso` on `SavedVariables/!BugGrabber.lua`: it must be newer than the dev's action, and the BugGrabber session number goes up by one with every load. Don't judge `config-cache.wtf` or `AddOns.txt` by their time: the client rewrites them only when something in them changed, so an older time means nothing changed (see below).
4. **Run the reader** and report what it prints. Quote errors in full.

Never ask the dev to open a file or read a value the reader prints.

## Write timing

Checked on beta build 1.60.1.70338 on 2026-10-13 (#78), with an account CVar (`SoftTargetIconGameObject`) and an addon's enable state as markers, reading the files after each step:

| What the dev does | `SavedVariables/*.lua` | account `config-cache.wtf`, `AddOns.txt` | `Config.wtf` |
|---|---|---|---|
| changes a CVar or an addon's state in the game | not written | not written | not written |
| `/reload` | written | written, with the change | written |
| logs out, quits, or **End task** on the app row in Task Manager (a clean close) | written | written if something changed; otherwise left as they were | written |
| kills the client (`taskkill /F`, or Task Manager's Details tab) | not written | not written | not written |
| logs in | – | – | written |

- **A `/reload` is enough.** Every step that reads CVars or addon state can say "`/reload`", not "log out".
- **A kill loses every change since the last write.** The files keep the last clean write, and the next login loads those values: the server didn't restore the CVar changed before the kill. So a leased CVar survives a crash only if a `/reload` or logout wrote it while the lease held.
- **Only non-default CVars are saved.** Setting a CVar to its default removes its line from the file. The reader reports a missing line as "not set (the client's default applies)".
- Not checked: when the character's `config-cache.wtf` is written. No character CVar changed in the test.

## The M1 exit check (#75)

The dev does everything in the game: casting, combat, killing the client, clicking popups, judging how the UI looks, and every `/reload` and logout. An agent reads the rest from the files:

| Step | The dev | An agent reads |
|---|---|---|
| every step | the `/reload` or logout | the latest BugGrabber session: no Lua error |
| 1 Fishing spell | the spell ID from `/etrace`; `/dump C_Spell.GetSpellName(7620)` | – |
| 2 30-minute stretch | all of it, and the count | – |
| 3 Read `PagleLog` | `/reload`, then log out | all of it, with `--expect-casts <the dev's count>`: the `C1` count equals the dev's count, no repeated entry IDs, no zone areaID `0`, a `B1` and an `S1`, `decodeErrors` 0 |
| 4 Got away | – | a `g` among the `C1` outcomes (the same `--expect-casts` run) |
| 5 Combat | enters combat; the key does nothing, then casts again; `/reload` after the stretch | `SoftTargetInteract` after the `/reload` equals the player's value, read before the stretch. The file can't show the value during combat. |
| 6 Crash | kills the client with `taskkill /F` (not **End task**, which closes cleanly), logs in, `/reload` | the leased CVars after the kill and after the `/reload`; the dev posts the result on #72 |
| 7 Conflict popup | sees the popup, clicks "Use Pagle", reloads, the key works | Angleur `disabled` after the `/reload` |
| 8 QoL off | disables Pagle_QoL, `/reload`, fishes, checks the Fishing page and the bindings are gone | Pagle_QoL `disabled` and the new `C1` entries after a `/reload` |

## Test logs (#172)

The M4 exit check needs an Angler a few Catches short of level 10, of level 60 and of 1,000 lifetime Catches. Nothing in the game appends to the Catch log by hand, so `scripts/make-test-log.sh` writes a **test log**: a copy of the dev's `Pagle.lua` with `PagleLog` replaced by a synthetic one, `PagleDB` and every other line kept byte for byte. Run it in WSL with the game fully closed: the client rewrites every SavedVariables file at logout, over whatever was put there.

| Preset | The log folds to | Exit-check step |
|---|---|---|
| `level10` | Angler Level 9, three Catches short of level 10 | 2 |
| `level60` | Angler Level 59, three Catches short of level 60 | 3 |
| `catches1000` | 995 lifetime Catches, five short of the 1,000 Catches milestone | 5 |

`level10` can't also be at 995 Catches: 995 Catches earn at least 12,950 XP (10 each, the first 300 doubled by Fresh Water, LED-R20, LED-R22), past the 12,600 level 10 costs (LED-R30). So step 5 has its own preset.

The log has a new `logId` (LOG-R15), the dev's own `characters`, their last `B1`, each character's last `S1` (so Core appends no Skill Reading at login, whose Skill Milestones would earn XP, LOG-R31, LED-R40), and caught `C1` Casts for the character of the dev's last Cast: one item each, an ordinary Species, junk or trophy on a charted zone's list outside any window (never a Legend, Noise or an Uncharted item), the zones the dev fished first. The Casts come in sessions of 60, 30 s apart, 12 h between session starts, the last an hour before the run, so Fresh Water doubles every test Catch and the next three. Core's codec (`addons/Pagle/logic/CatchLog.lua`) writes the entries, and the Ledger's own `logic/` (from `Pagle_Ledger.toc`) folds the written log over the catalogue (the repo's, or `--catalogue <file>`, such as the installed addon's): nothing is written unless it lands where the preset says. It prints the level, the XP to the next one, the XP one more Catch gives and lifetime Catches.

```sh
ACCT="/mnt/g/World of Warcraft/_classic_beta_/WTF/Account/<ACCT>"
scripts/make-test-log.sh --account "$ACCT" --preset level10     # reads the account, writes only the stage
scripts/make-test-log.sh --account "$ACCT" --install            # the game fully closed
# play: log in as the character it names
scripts/make-test-log.sh --account "$ACCT" --restore            # the game fully closed
```

- **`--preset`** only reads the account folder. It writes a stage folder `<out>/<ACCT>/<UTC time>-<preset>/` (`--out` defaults to `~/pagle-test-logs`, outside the WTF folder): first `original/`, a byte-for-byte backup of `Pagle.lua`, `Pagle_Ledger.lua` and their `.bak`, then the test `Pagle.lua` and `stage.txt` (the preset, both logIds, the character). When a test log is installed, the backup is copied from that test log's stage, so switching presets never backs up a test log as the real one.
- **`--install`** copies the newest stage's `Pagle.lua` into `SavedVariables/`, only when the account's `Pagle.lua` is still the one backed up, or is a test log made here (switching presets). Otherwise the backup is stale: run `--preset` again.
- **The next login is a first build.** The new `logId` makes Core rebuild every projection (LOG-R72); the Ledger empties its celebrated set and writes itself up from the test log in one Write-up section, with no moment (LED-R90, LED-R93). The Catches after it are live, so the milestone's moments are raised.
- **`--restore`** puts back the backup of the stage whose test log is installed: the four files byte for byte, and a file that wasn't there (a `Pagle_Ledger.lua.bak` the test play made) removed. The real `Pagle_Ledger.lua` comes back with the real `logId` and celebrated set, so nothing rebuilds or is written up again. It refuses while the real log is in place, so it can never put an old backup over newer real Catches.
- `--install` and `--restore` first copy every file they replace into `<stage>/replaced-<UTC time>/`, so nothing is lost, and the `.sh` refuses both while a WoW process runs. Every refusal exits 1 and changes nothing.

The stage folders hold the dev's account folder name and characters: they stay outside the repo.
