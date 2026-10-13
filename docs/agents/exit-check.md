# Reading the M1 exit check's Catch log

Steps 3 and 4 of the M1 exit check (#75, [roadmap.md › M1 Dogfood](../spec/roadmap.md#m1-dogfood)) are read from the Catch log, not by eye. After the dev's 30-minute stretch, its `/reload` and logout, an agent runs one command on the account's SavedVariables folder with the dev's Cast count:

```sh
scripts/read-catch-log.sh "/mnt/g/World of Warcraft/_classic_beta_/WTF/Account/<ACCOUNT>/SavedVariables" \
    --expect-casts <the dev's count> [--since <server time the stretch started>]
```

Run it in WSL after `scripts/setup.sh`; it runs `scripts/read-catch-log.lua` on the pinned Lua 5.1 (`.tools/bin/lua`). The folder is only read. Find `<ACCOUNT>` with `ls WTF/Account/` (on the dev's machine it is `104973978#1`).

It decodes `PagleLog` with Core's own codec (`addons/Pagle/logic/CatchLog.lua`), so it reads entries exactly as Pagle does, and prints the logId, the entries by tag, the `C1` Casts by outcome, per character and per zone areaID, the Casts in zone areaID 0 by seq, their time span, the `B1` and `S1` entries and `PagleDB.global.decodeErrors`.

`--expect-casts N` adds the checks, one `ok` or `FAIL` line each:

| #75 checkbox | Check |
|---|---|
| step 3: the `C1` count equals the count, each Cast there once | N `C1` Casts; no repeated entry ID |
| step 3: non-zero zone areaIDs | no Cast in zone areaID 0 |
| step 3: a `B1` and an `S1` entry | at least one of each, anywhere in the log |
| step 3: `decodeErrors` is 0 | `PagleDB.global.decodeErrors` is 0, and the reader decodes every entry too |
| step 4: a got-away Cast | at least one Cast with outcome `g` |

`--since T` counts only the Casts at server time T (Unix seconds) or later, so an earlier session's Casts don't change the count; `B1` and `S1` are still looked for in the whole log, since Core writes them only when the build or the skill changes.

Exit codes: 0 the log read and every check passed, 1 a check failed, 2 a usage error or an unreadable `Pagle.lua` (missing until M1 is installed, not plain data, or holding no `PagleLog`). `Pagle.lua` runs as data in an empty environment, and precompiled chunks are refused.

The specs (`spec/scripts/read-catch-log_spec.lua`) build their SavedVariables fixtures with Core's codec and write them in the client's layout.
