# Core reads signed pushed content from the companion's data addon

The Pagle companion (`timemir/pagle-companion`, specified in `timemir/pagle-backend`) brings backend content into the game the way it already brings `Pagle_Following` and `Pagle_Anglers`: a **data addon** it creates and owns, never shipped in Pagle's zip, here called **`Pagle_Content`**. Its first content is Hunt Events and their runs (ADR 0012). It loads after Pagle, holds one data file, and only **Core** reads it. There is no `Pagle_Companion` Module: whether the companion is installed and running is read from the data addon itself.

Decided in [The pushed-content contract and the companion's data addon](https://github.com/timemir/wow-fish/issues/282), on the map [Hunts redesigned around Hunt Events](https://github.com/timemir/wow-fish/issues/277). The signature scheme comes from [Checking signed pushed content in pure Lua inside the client](https://github.com/timemir/wow-fish/issues/283).

- **The file:** `v`, `generatedAt`, `keyId`, `seq`, `expires`, `payload` (Base64, because Lua 5.1 long strings rewrite CR bytes) and `sig`. The signature is RSA-2048 with PKCS#1 v1.5 and SHA-256, made by the backend. The companion passes the bytes on unchanged.
- **The check:** Core checks the file once at load, spread over frames by a coroutine, against the public keys it ships by key ID (the current one and the next, rotated through releases). It keeps the last `seq` it accepted in `PagleDB`. An unknown key, a bad signature, a lower `seq`, a passed `expires`, a size over the cap (a Tunable) or a malformed payload makes the file **absent**. The reason shows only in a `/pagle dev` diagnostic.
- **The states:** `Pagle.GetCompanionState()` returns one of three:
  - `"missing"`: the data addon is absent, or failed its check;
  - `"notRunning"`: it loaded but `generatedAt` is 24 hours old or more (a Tunable);
  - `"connected"`.
- **The content:** `Pagle.GetPushedContent(kind)` returns the checked items of one kind (`"huntEvent"` definitions and `"huntRun"` runs to start with). Each delivery is a **snapshot** of the whole current schedule and the definitions it needs, so a withdrawn run is simply not listed. Items carry a `kind` and their own version, and Core passes on only those it knows, quietly ignoring the rest. The file changes only at login or `/reload`, so it is read once before `PLAYER_LOGIN`, with no change event.
- **Logging stays with the Module that uses the content.** Hunts logs every run it uses, fallback or pushed, as its own opaque records (ADR 0008) the first time it uses it, with the pushed definition. Core never logs pushed content and knows nothing about Hunt Events.

## Considered Options

- **A `Pagle_Companion` Module, shipped in Pagle's zip, that owns the check.** Rejected: the companion would still have to write its data into a folder of its own, so the Module would only be a middleman, and ADR 0001 would make it hand the content to Core anyway.
- **Core logs the whole pushed content.** Rejected: Core can't know which runs a Module actually used, so it would log content no rebuild needs.
- **Deltas instead of snapshots.** Rejected: a lost or skipped delivery would leave the schedule wrong. A snapshot is right as soon as it arrives, and runs already started are in Hunts' log anyway.
- **Trusting the file because its grammar checks out,** as the social data addons do (pagle-backend IGV-R41). Rejected: pushed content pays XP and Coins, so a hand-edited file would be a cheat channel. The dev asked for this path to be secure.

## Consequences

- **First install:** a brand-new data-addon folder appears only at character select, so the hint for a first install tells the player to log out once.
- **For the backend:** pagle-backend IGV-R47's "nothing from them enters `PagleLog` or any SavedVariables" must narrow to the social data addons. Runs that Hunts played are logged, and the backend's fold needs them to agree with the addon. This goes into [File the Hunt Event push requirements with pagle-backend and pagle-companion](https://github.com/timemir/wow-fish/issues/285).
- **New content needs no new channel:** later backend content (Notices, catalogue fixes) is a new `kind` through the same contract.
