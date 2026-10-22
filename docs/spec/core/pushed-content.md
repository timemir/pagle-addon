# Core: pushed content

> Status: Draft · Milestones: M8 Hunt Events (the reader; the hint stays switched off at 1.0) · Sources: [The pushed-content contract and the companion's data addon](https://github.com/timemir/wow-fish/issues/282), [Checking signed pushed content in pure Lua inside the client](https://github.com/timemir/wow-fish/issues/283), [How the Hunts redesign reshapes the road to 1.0](https://github.com/timemir/wow-fish/issues/288), map [Hunts redesigned around Hunt Events](https://github.com/timemir/wow-fish/issues/277); ADR 0001, ADR 0012, ADR 0013. Research: [pushed-content-signatures.md](https://github.com/timemir/wow-fish/blob/research/pushed-content-signatures/docs/research/pushed-content-signatures.md) (branch `research/pushed-content-signatures`)

Part of [Core](README.md). The Pagle companion (`timemir/pagle-companion`, specified in `timemir/pagle-backend`) brings backend content into the game as a **data addon** it creates and owns, **`Pagle_Content`**, never shipped in Pagle's zip. Core alone reads it, checks the backend's signature, tells whether the companion is installed and running, and hands each Module the content of the kinds it asks for (ADR 0013). Its first kinds are Hunt Events and their runs (ADR 0012, [hunts.md](../hunts.md)).

## Purpose and boundary

**Owns:** reading `Pagle_Content`, the signature check and its keys, the `seq` and expiry checks, the size cap, the companion state, the per-kind hand-out, and the dev diagnostic.

**Doesn't own:** what a kind means or how it is used, logged or shown (each Module's spec; Hunts for `huntEvent` and `huntRun`), the companion app and the backend (their repos), or the hint shown to the player (Hunts, HNT-R170).

## Rules

### The data addon

- **PUSH-R1** `Pagle_Content` is a folder the companion writes into each install's `Interface/AddOns/`, as it writes `Pagle_Following` (pagle-backend IGV-R40). Its TOC copies `## Interface:` and `## AllowLoadGameType:` from Pagle.toc and has `## Dependencies: Pagle`, loaded normally, so its one data file has run before Core's `PLAYER_LOGIN`. A brand-new folder appears in the game only at character select.
- **PUSH-R2** The data file sets one global, `PagleContentData`, a plain table: `v` (the file format, `1`), `generatedAt` (Unix seconds, the backend's answer time), `keyId` (string), `seq` (integer), `expires` (Unix seconds), `payload` (Base64 of the content's bytes) and `sig` (Base64 of the RSA signature). Base64 is used because Lua 5.1 long strings rewrite CR bytes. Nothing in it is code.

### The check

- **PUSH-R10** Core checks the file once per login or reload, after `PLAYER_LOGIN`, spread over frames by a coroutine (a few milliseconds a frame) so no frame runs long. Until it finishes, the state is `"checking"` and `GetPushedContent` returns nothing; Hunts draws its board without pushed runs meanwhile. *Decided while writing the spec (#289): ADR 0013 reads the file "before `PLAYER_LOGIN`"; the data is read then, but the RSA check runs just after, by coroutine, and a Module that needs the content waits for `PushedContentReady`.*
- **PUSH-R11** The signature is RSA-2048 with PKCS#1 v1.5 and SHA-256 (`SHA256withRSA`), public exponent 65537, over the exact bytes of the decoded `payload` concatenated with the header fields as the canonical string `v|generatedAt|keyId|seq|expires|` before it. Core rebuilds the expected PKCS#1 block and compares it byte for byte (RFC 8017 §8.2.2), in its own bignum code in `logic/` with no `bit` calls. *Decided while writing the spec (#289): the header fields are inside the signed bytes, so `seq` and `expires` can't be changed without breaking the signature.*
- **PUSH-R12** Core ships the public keys by key ID in `logic/` (the current key and the next), rotated through releases. A file whose `keyId` Core doesn't know fails the check.
- **PUSH-R13** The file is **absent** when any of these holds: the global isn't a table or lacks a field of PUSH-R2; `v` isn't a version Core knows; the `keyId` is unknown; the signature doesn't verify; `seq` is lower than the last accepted `seq` (`PagleDB.global.pushed.seq`); `GetServerTime()` is at or past `expires`; the decoded `payload` is over the size cap (Tunables); the payload doesn't parse (PUSH-R20). On an accepted file Core stores its `seq` as the last accepted one. A file that failed to load, or that the AddOns list has disabled, is absent too.
- **PUSH-R14** With dev mode on (`/pagle dev on`), `/pagle dev content` prints the state, `generatedAt`, `keyId`, `seq`, `expires`, the kinds and item counts, and, when the file is absent, the first reason PUSH-R13 found. Nothing else ever names a reason to the player.

### The states

- **PUSH-R15** `Pagle.GetCompanionState()` returns:
  - `"checking"` while PUSH-R10 runs;
  - `"missing"` when the file is absent (PUSH-R13);
  - `"notRunning"` when it passed the check but `GetServerTime() − generatedAt` is the not-running age or more (Tunables, 24 h);
  - `"connected"` otherwise.
  
  The state is fixed for the login once the check ends: the file changes only at a login or reload.
- **PUSH-R16** Core fires `PushedContentReady(state)` once per login when the check ends, whatever its result.

### The content

- **PUSH-R20** The decoded `payload` is a Lua-data-only text in the grammar under [Contracts](#the-payload), read by a strict parser in `logic/`: tables, strings, integers and booleans only, never `loadstring`. It is a **snapshot**: the whole current schedule and the definitions it needs, never a change to an earlier one.
- **PUSH-R21** The payload holds a list of **items**, each with a `kind` (`[%w_]+`), a `v` (its own version, an integer) and its fields. Core passes on only items of kinds and versions it knows (Tunables: `huntEvent` 1, `huntRun` 1), and quietly ignores the rest, so a newer backend never breaks an older addon.
- **PUSH-R22** `Pagle.GetPushedContent(kind)` returns a fresh array of the checked items of that kind, in payload order, each a copy the caller may keep; an empty array when the state isn't `"connected"` or `"notRunning"`, or the kind has no items. *Decided while writing the spec (#289): a `"notRunning"` file's content is still handed out, since it passed its signature and expiry checks; only the hint treats it as stale.*
- **PUSH-R23** Core never logs pushed content and knows nothing of what a kind means. A Module that bases rebuildable state on pushed content logs what it used as its own Module records (ADR 0008, ADR 0013); Hunts does so for runs (HNT-R150).

## Data

| Key | Contents |
|---|---|
| `PagleDB.global.pushed.seq` | the last accepted `seq` (PUSH-R13) |

## Contracts

| Function / event | Rules |
|---|---|
| `Pagle.GetCompanionState()` → `"checking" \| "missing" \| "notRunning" \| "connected"` | PUSH-R15 |
| `Pagle.GetPushedContent(kind)` → array of items | PUSH-R21, PUSH-R22 |
| event `PushedContentReady(state)` (callback `PaglePushedContentReady`) | PUSH-R16 |

### The payload

The decoded payload is one Lua table constructor, written by the backend and checked by the companion against the same grammar (pagle-backend IGV-R41's rule):

```
payload   = "{" "items" "=" "{" *(item ",") "}" "," "}"
item      = "{" "kind" "=" str "," "v" "=" int "," *(field ",") "}"
field     = name "=" value
value     = str | int | bool | "{" *(value ",") "}" | "{" *(field ",") "}"
```

`str` is a double-quoted Lua string with only `\\`, `\"` and `\n` escapes, `int` a decimal integer, `bool` `true` or `false`, `name` `[%a_][%w_]*`. No other syntax is accepted. The fields of each kind are its Module's: `huntEvent` and `huntRun` are under [hunts.md › Contracts](../hunts.md#pushed-hunt-events-and-runs).

## Tunables

| Name | Value | Rules |
|---|---|---|
| Not-running age | 24 h | PUSH-R15 |
| Payload size cap | 64 KiB decoded | PUSH-R13 |
| Kinds and versions passed on | `huntEvent` 1, `huntRun` 1 | PUSH-R21 |
| File format versions read | 1 | PUSH-R13 |
| Check budget per frame | about 4 ms | PUSH-R10 |
| Public keys shipped | none yet: `ns.PUSHED_KEYS` in `logic/PushedKeys.lua` ships empty, and the first keys come with the backend (pagle-backend #2); `scripts/pushed-key.py` prints each key's entry | PUSH-R12 |

*Decided while writing the spec (#289): the 64 KiB cap and the per-frame budget are first values; the backend's requirement on pagle-backend #2 names "a size cap agreed with the addon's Tunable".*

## Edge cases

- **PUSH-R90 First install of the companion.** The folder appears only at character select, so the first login after installing still reads `"missing"`; Hunts' hint says to log out to character select once (HNT-R170).
- **PUSH-R91 The companion is unlinked or removed.** It deletes or keeps its files as it does the social data files (pagle-backend IGV-R53); a deleted file is `"missing"`, a kept one goes `"notRunning"` after 24 h and absent at `expires`. Runs Hunts already logged play out (HNT-R150).
- **PUSH-R92 A replayed old file.** A file with a lower `seq` than the last accepted one is absent, so copying back an old file can't bring back withdrawn runs. A lost `PagleDB` forgets the last `seq`, which only lets an old but still unexpired file through.
- **PUSH-R93 The check fails on a slow PC.** The check is spread over frames; a login that ends (logout, reload) before it finishes simply checks again next time.
