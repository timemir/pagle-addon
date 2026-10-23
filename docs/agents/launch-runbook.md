# Launch runbook: 1.0 on Forever's live build, 5 Nov 2026

The plan from Forever's live release to the `1.0.0` tag and the 1.0.1 window. The dev decided it on [#380](https://github.com/timemir/pagle-addon/issues/380) (23 Oct; map #369), and #383 prepared the kit. Times are German time (CET, UTC+1 after DST ends on 25 Oct), with UTC in brackets where the date matters.

**T** is the dev's first successful live login. Forever opens on 5 Nov at 00:00 CET (4 Nov 23:00 UTC). If queues or a delayed launch push the login back, every T-offset below moves with it. With no login by 02:00 CET, the dev sleeps, S1 runs in the morning before S2, and the tag moves to about the evening of 6 Nov. The release-day constants stay as they are.

## Roles

- **Dev:** plays in the game, owns the accounts and secrets, decides, and pushes the tag. On vacation for the launch, so S1 (~3½ h) and S2 (~9 h) are both covered.
- **Orch:** the orchestrating session. It sequences and merges the work, runs `PAGLE_NO_COVERAGE=1 GATE_JOBS=2 scripts/check.sh` (`T_full`, about 16–20 min), and posts results on the tickets.
- **Agents:** run single spec files, read WTF files with `scripts/launch.py read` (§6), and make fixes.
- **Workflow:** `.github/workflows/release.yml`, which runs on the tag push (CORE-R74).

## 1. Decisions (#380)

| # | Question | Decision |
|---|---|---|
| Q1 | The tag | 5 Nov at about 21:00 CET (20:00 UTC, T+21h), still 5 Nov in UTC. Hard limit T+48h. |
| Q2 | Release-day constants | `since = 2026-11-05` for every v1 Hunt, and `ns.ROTATION_ORIGIN = 1793890800` (5 Nov 15:00 UTC). Both are fixed in RC1 on 2 Nov by #381, whatever the tag's minute. `--lock` comes in the release commit, after the last data change. |
| Q3 | "First live build" (`--min-build`, the DB2 slice) | The build of the first live login (the probe's `GetBuildInfo()`). A day-1 client hotfix goes to 1.0.1 through the DB2 watch. |
| Q4 | Does the DB2 refresh block the tag? | No, unless the 2 Nov check shows that a refresh after the lock can change a locked class's `members` (DATA-R95/R96). If it does, the release waits for wago.tools to list the build. |
| Q5 | Does the dump pin (`BIR_COMMIT`) block the tag? | No. The live probe's check 11 is the authority. Bump the pin when Ketho publishes, by 1.0.1 at the latest. |
| Q6 | Which in-game gates block the tag? | Only M8 steps 1–3 (#311) and M8.5 steps 1–2 (#335). The rest of M8 and M8.5, and the Settings UX pass (#266), run before the tag without blocking it; their fixes may follow in 1.0.1. Screenshots (#270) come after the tag. #270 and #266 are off #276's blocked-by list (#383). |
| Q7 | deDE (check 7) | Not blocking. Run it in S2; it goes into 1.0 if the fix takes under about 2 h. |
| Q8 | Character | A fresh one near a Fishing trainer, a pole vendor and water. Checks 5, 6 and 13 move to T+24–72h. |
| Q9 | Queues or a delay | T is the first successful login (above). |
| Q10 | First login | From the RC1 zip, not junctions: the only truly fresh install. Junctions from S2 on. |
| Q11 | Who tags | The dev, from their own git, after the orchestrator's GO comment naming the SHA. Agents never push. |
| Q12 | Full checks | One per batch: A overnight, B in S2, and the release commit's own. Targeted specs in between. |
| Q13 | Companion hint switch (HNT-R170/R172) | On only if pagle-backend confirms `https://pagle.app/download` resolves by the tag. Ask by 2 Nov. Otherwise off at 1.0 and on in 1.0.1. |
| Q14 | Announce | Only once CurseForge and Wago both list 1.0.0 publicly; moderation of a first file can lag by hours. |
| Q15 | A blocker past T+48h | Hold. No `-beta` tag; a reduced 1.0 needs its own decision. |
| Q16 | 1.0.1 | About T+72h, as one bundle, if a tier-2 fix or a meaningful player bug has landed. |
| Q17 | Dev hours | S1 about 3½ h, S2 about 9 h. If S2 runs short, cut group B in this order: #266, M8.5 steps 3–13, deDE, then the rest. |

## 2. Timeline

### By Sun 1 Nov (the freeze)

| Who | Step |
|---|---|
| Dev | #378/#271: create the CurseForge and Wago projects, add the `CF_API_TOKEN` and `WAGO_API_TOKEN` secrets, post both project IDs on #271. |
| Dev | #379/#264: the lore sign-off. |
| Agents | #377's loose ends, the art kits #372–#374, #376: on main, full check green. |

### Mon 2 Nov (freeze work)

| Who | Step | Output |
|---|---|---|
| Orch | Full check on the freeze head; note `T_full` (P1). | `T_full` |
| Agent | **Check 17, the conflict list (QOL-R104):** download the current Forever releases of Angleur and both Fishing Buddy ports, list their zips' top folders, compare with qol.md › Tunables and `logic/Conflict.lua`, fix with sources. | a PR, or "unchanged", on #274 |
| Agent | **#381 "Before the tag", all but the lock:** the project IDs in `Pagle.toc`, the final `CHANGELOG.md` 1.0.0 text (§8.1 has suggestions), the 1.0 surface spec, past-tense wording, the release-day constants (Q2), the companion hint switch (Q13), and the Tunables text in content-data.md and hunts.md. | a PR on main |
| Agent | Whether a DB2 refresh after the lock can change a locked class's `members` (Q4). | yes or no, on #274 |
| Agent | Ask pagle-backend whether `pagle.app/download` resolves by the tag (Q13). | the answer on #381 |

### Tue 3 Nov: RC1

See §7, the RC1 day checklist.

### Wed 4 Nov (staging)

| When | Who | Step |
|---|---|---|
| when the pre-download opens | Dev | Install or patch the live client. Post the live install's folder name and the WTF account folder on #272. The realm folder appears only after the first login. |
| afternoon | Dev | Put BugSack and !BugGrabber into the live `Interface/AddOns/`. Unzip **RC1's zip** there, with no junctions (Q10). Tick "Load out-of-date AddOns" in case the interface number moved. |
| afternoon | Agent | Fill `~/pagle-launch.env` (§6.1) with the install folder and account. |
| afternoon | Dev | Plan the character (Q8): realm, faction and race near a trainer, a pole vendor and water. |
| 22:00 | Agent | Start the watcher in a WSL terminal: `.tools/bin/python scripts/launch.py watch --every 600` (§5, P4). Restart it with `--live-build <BUILD>` once the probe names the build. |
| 23:30 | Dev | Pre-flight: client patched, a stopwatch, the Battle.net launcher open. |

### Launch night: S1, T+0 to about T+3½h (5 Nov 00:00–03:30 CET)

Order: what needs no fishing first, then the probe, then the extras. Every step ends the same way: the dev does a `/reload` (or logs out) and says so; an agent runs `scripts/launch.py read <step>`, checks that the `!BugGrabber.lua` time it prints is after the dev's action, and reports the step's sections (§6).

| T+ | Who | Step | Agent reads |
|---|---|---|---|
| 0:00 | Dev | Log in (allow for a queue). At character select, in the AddOns list: **Pagle with its five Modules nested, not "out of date"** (checks 12 and 1 at a glance). | a one-line note |
| +0:10 | Dev | Create the character and enter the world. **The Letter shows 4 s after the world appears**: launch players see it once (ONB-R2). Then `/pagle dev on`, `/dump Pagle.API_VERSION`, M8.5 steps 1–2 (Later, `/reload` twice, `/pagle guide`). | `read first-login` |
| +0:25 | Dev | **Check 1:** disable Pagle_Stats, log in, look for Stats leftovers, re-enable it. | `read check1` |
| +0:35 | Dev, Agent | **Check 15:** the dev quits the game. The agent runs `launch.py angleur-stub "$WOW/Interface/AddOns"`. The dev logs in: the conflict note, Use Pagle, Reload now, then quits. The agent runs it again with `--remove`. | `read check15` (look for `ADDON_ACTION_BLOCKED`) |
| +0:50 | Dev | Learn Fishing and get a pole (a trainer trip, maybe a few levels). Set the Fishing key (M8.5 step 3). | – |
| ~+1:45 | Dev | **The probe:** note the server time of the first Cast as `T0`, then 10 Casts, some with the Fishing key and some from the spellbook; let one get away if you can. `/pagle dev probe`, `/reload`. | `read probe --expect-casts 10` |
| ~+2:05 | **Orch** | **Night verdict:** post the tier-1 results on #272. An interface bump, or failed probe checks? Start batch A. | – |
| 01:00 CET (00:00 UTC) | Dev | The Hunts board switches from "No Hunts yet." to the v1 list (DATA-R87, #276 step 2's line). | a note |
| ~+2:20 | Dev | **Check 9:** mid-Session, after a `/reload` and 5 more Casts, `taskkill /F`, then log in. | `read check9` |
| ~+2:30 | Dev, Agent | **Checks 2 and 10, optional tonight:** the game closed, the agent stages `big5` (`scripts/make-test-log.sh`), the dev times login and `/reload`, the same with `big20`, then `--restore`. Moves to S2 if the dev is tired. | `read big-log` |
| ~+3:30 | Dev | Sleep. | – |

**Batch A** (agents, T+2h to T+10h, while the dev sleeps): the interface bump if needed (§4.2), the dump pin if Ketho has published (§4.1), the docs path swap (§4.7), each failed rule from S1 (§4.5), "Checked on build …" notes (§4.6), and the DB2 slice and `--min-build` if wago.tools lists the build (§4.4). **Orch** merges into **RC2**, runs one full check, waits for GitHub Actions and packages `RC2.zip`. Output: the RC2 SHA, the zip's SHA-256 and a summary on #274.

### Day session: S2, about T+12h to T+21h (5 Nov 12:00–21:00 CET)

| CET | Who | Step | Agent reads |
|---|---|---|---|
| 12:00 | Dev | Install RC2 with junctions (`link-addons.ps1 -AddOnsPath <live AddOns>`). Re-probe only if batch A touched the probe's rules or the build changed. | `read reload` (`read probe` if re-run) |
| 12:15 | Dev | **#273:** check 13 (the clams and lures you have; post the `/dump`s), 14 (combat swap), 16 (the set limit). | `read check16` |
| 13:00 | Dev | **M8.5:** onboarding steps 3–13 (#335). | `read onboarding` after each `/reload` |
| 14:00 | Dev | **#266, the Settings UX pass** (not blocking, Q6). | tour screenshots against settings.md |
| 15:00 | Dev | **Check 7 (deDE):** start the German language download in the morning. Fish in 2 zones with subzones, switch back. Then **checks 5 and 6** where you can reach. | `read places` |
| 16:00 (15:00 UTC) | Dev | **The first fallback run starts.** **M8 (#311)** steps 1–4 and 6; step 5 (`level60`) if time allows. Step 7 waits for the run to end. | `read m8` |
| 17:45 | Orch | **Results freeze for 1.0.** Sort anything open into tier 1 (fix now) or tier 2 (1.0.1). | a list on #380 |
| 18:00 | Agents, Orch | **Batch B:** tier-1 fixes from S2, "Checked on build" notes, then `scripts/generate-data.py --lock` **last**, then the full check and GitHub Actions, then `scripts/package.sh`. | the release commit and its zip's SHA-256 |
| ~19:45 | Dev, Agent | **#276 steps 1–3** on the release zip: the agent backs up the SavedVariables and removes the junctions; the dev unzips, logs in and plays a fresh install for 10 Casts; then the agent restores the real log. | `read fresh-install --expect-casts 10 --since <install time>` |
| ~20:30 | **Orch → Dev** | **GO or NO-GO (§3)**, posted on #380 (§8.4). | – |
| ~20:45 | **Dev** | The tag (§8.3). | – |
| +0–15 min | Workflow | The packager builds the zip, uploads to CurseForge and Wago (`-w 0`) and creates the GitHub Release with the changelog and the zip plus `release.json`. | – |
| ~21:00 | Dev, Agent | **#276 step 4:** the workflow is green; CurseForge and Wago list 1.0.0 for Forever with the changelog; an install through the CurseForge or Wago app gives six folders and no Lua error. **Step 5 (agent):** `generate-data.py --check` against `released.lock`, and the 1.0 surface spec. Then `launch.py post-tag 1.0.0 --local .release/<zip>` and the hand-off to pagle-backend (§8.5). | `read reload` |

Announce only once both listings show 1.0.0 publicly (Q14).

### T+24h to T+72h (6–8 Nov): the 1.0.1 window

| When | Who | Step |
|---|---|---|
| daily | Orch, Agents | Triage GitHub issues, CurseForge and Wago comments, Field reports (`field-report-triage.yml`), and the DB2 watch issue for a hotfix build. |
| 6–7 Nov | Dev | Tier-2 leftovers: checks 2 and 10 if skipped, 3 (when it rains), 5 and 6 (higher zones and pools), 13 (lures found later), M8 step 5, any M8.5 steps left; check 25, the Paste copy test (report the largest size that survives to pagle-backend). |
| 6–8 Nov | Dev, Agent | **#270 screenshots:** the `showcase` test log or the dev's own; `veteran` only after slot 1 starts (8 Nov 16:00 CET). Upload on the listings; no tag needed. |
| 8 Nov 16:00 CET (T+89h) | Dev | **M8 step 7, live:** the first fallback run ends and slot 1 starts. `read m8`. |
| ~T+72h | Orch → Dev | **1.0.1 go or no-go** (Q16): release commit, full check, `--lock` if data changed (DATA-R73), tag `1.0.1`. |

## 3. What blocks the tag

"Frozen by the tag" means the log format and entry tags, the `Pagle` API, each DB's first `schemaVersion`, released Hunts, and the Simulated Size hash. From the tag on, changing any of them needs a migration or a new Hunt.

**Group A, blocks the tag:** check 12 (the interface number in every TOC, `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`); login with no Lua error in all six addons; check 11 (no inventory API missing, by the live probe); check 21 (the fishing channels' spell IDs, every rank sharing 7620's name and icon); check 20 (`bit` and the LOG-R66 vectors); check 23 and Cast recording (C1 Casts as played, `decodeErrors` 0, no repeated ID, no zone 0, a `g`); check 15 (`DisableAddOn`, Reload now not protected); check 17 (the conflict list); M8.5 steps 1–2; M8 steps 1–3; #276 steps 1–3; and #381's "Before the tag".

**Group B, fix in 1.0.1 if it fails** (run before the tag when time allows): check 1 (promote it to A if it throws a Lua error), 9, 4, 7 (promote it if the fix is under ~2 h), 6, 5, 2 and 10, 8, 18 and 19, 13, 16, 24 and the DB2 slice (promote them per Q4), the dump pin, M8 steps 4–6, M8.5 steps 3–16, and #266.

**Group C, after the tag:** check 3 (rain), 14 (a pass only opens a feature ticket), 25 (the Paste copy test), Track P's exit steps 1–3, M8 step 7, #270, and a `WOW_API_COMMIT` bump.

**GO when all of these hold:**
1. Every group-A check passes, or its fix is on the release commit and that check was re-run on it.
2. No Pagle Lua error in any BugGrabber session read since the release commit was installed.
3. `scripts/check.sh` passes on the release commit in WSL and in GitHub Actions on `main`, and `package.sh` builds one zip with six folders and `LICENSE`, `NOTICE` and `CHANGELOG.md` in `Pagle/`.
4. The release commit holds #275/#381 in full, with `released.lock` generated in that commit, after the last data change.
5. No open failure whose fix touches a frozen surface.
6. Both secrets exist, and both project IDs are in `Pagle.toc`.
7. Every tier-2 failure found so far has a 1.0.1 ticket.

**If a blocker turns up:**
- **A small fix (under ~3 h):** batch A takes it, S2 re-runs only the failed check on RC2, and the tag stays on time.
- **A big fix:** its own ticket, blocking #274/#276. The tag slips day by day while S2's other checks still run. Past T+48h, the dev decides (Q15: hold by default).
- Never tag a known group-A failure "to fix in 1.0.1" when the fix would touch a frozen surface. No `-beta` tags.
- **The workflow fails after the push:** a failure before the uploads gets the job re-run on the same tag (a re-run updates the release, CORE-R74). A half-done upload gets a manual fix on that site, not a new tag. A broken zip already on the sites gets 1.0.1 the same night.

## 4. How each kind of failure gets applied

One PR per batch on main (A overnight, B in S2, then 1.0.1). Agents run targeted spec files; the orchestrator runs one full check per batch.

| Kind | What the agent does | Full check? |
|---|---|---|
| **4.1 A new API dump** (check 11) | Once `launch.py watch` reports Ketho's dump of the live build: `launch.py dump <commit> <version> <build>` (with `--annotations <commit>` if vscode-wow-api has a newer `forever` commit), `scripts/setup.sh`, then the api stage alone (the two lines `dump` prints). For each name missing from the dump **or** the probe, change the rule that uses it or drop the use (CORE-R23). | yes |
| **4.2 An interface bump** (check 12) | `launch.py interface <n>`: the six TOCs, the five Module TOC specs, CORE-R2, spec/README and release.yml's comment (its version, too). It lists what still names the old number: the fake client in `spec/support/client.lua` and the DevProbe and Login specs keep the beta's build on purpose; `spec/scripts/read-wtf_spec.lua`'s Probe test names the TOCs' number, so fix its expectation. Run the TOC specs and read-wtf_spec one at a time. read-wtf's check 12 then reads ok. | yes |
| **4.3 The conflict list** (check 17) | Download the three zips, list the folders, edit qol.md › Tunables and `logic/Conflict.lua` with each name's source, plus its spec. Done on 2 Nov; re-check at T. | rides in the batch |
| **4.4 `--min-build` and the DB2 slice** (check 24, DATA-R12) | `generate-data.py --min-build <build>`, post the report on #274, the dev decides whether to raise the tunable (DATA-R46), regenerate. `update-db2.py <version.build>` once wago.tools lists it, regenerate, commit `data/db2/` and the generated files. **Always before `--lock`.** Add the live product to `data/db2/build.toml`'s `products` (on 23 Oct wago.tools lists Forever under `wowf`, besides `wow_classic_beta` and `wow_cn_beta`; the DB2 watch reads only the listed products). | yes |
| **4.5 A failed check's rule** | Change or retire only the rule the check names, in spec, code and tests, and note "Checked on build …" in it. A fix too big becomes its own ticket blocking #274. | yes |
| **4.6 Check-only results** | One docs commit with every "Checked on build N" line (QOL-R100–R104, LOG-R21, LOG-R26, DATA-R22, TKB-R11, LOG-R69, DATA-R39). | rides in the batch |
| **4.7 The docs path swap** (#274) | The live install's folder and realm folder into in-game-verification.md and `probes/*/README.md`. | rides in the batch |

After the tag, every fix ships as 1.0.1, and a data change needs `--lock` in the same commit (DATA-R73).

## 5. The prep items (P1–P8)

`scripts/launch.py` holds the kit's scripts; run it in WSL as `.tools/bin/python scripts/launch.py <command>`. Its pytest file is `scripts/tests/test_launch.py`.

| # | Item | State |
|---|---|---|
| P1 | `T_full` | Known: about 16–20 min with `GATE_JOBS=2` (#380). Re-time it on 2 Nov's freeze head. |
| P2 | The interface bump | `launch.py interface <n> [--dry-run]` (§4.2). Rehearsed as a dry run to 16100 on 23 Oct: 14 files. |
| P3 | `launch.env` | `~/pagle-launch.env`, outside the repo (§6.1). Filled on 4 Nov and at the first login. |
| P4 | The watchers | `launch.py watch [--every 600] [--live-build N]`: Ketho's `forever` head through the public GitHub API, and wago.tools' builds, both by curl with no credentials. With `--every` it prints only what changed. A `LIVE:` line names the command to run. On 23 Oct it read Ketho's head at 1.60.1 (70532), a beta build newer than the pin (70338), and wago.tools' 70532 under `wow_classic_beta` and `wowf`. |
| P5 | The Angleur stub | `launch.py angleur-stub <AddOns> [--remove]`: refuses while WoW runs, never touches a folder it didn't write. |
| P6 | The dump bump | `launch.py dump <commit> <version> <build> [--annotations <commit>]` (§4.1). |
| P7 | After the tag | `launch.py post-tag 1.0.0 [--local <package.sh's zip>]`: the release zip's SHA-256 (for pagle-backend), its folders and the three files in `Pagle/`, and every file that differs from the local zip. `--zip <file>` reads a downloaded zip instead. |
| P8 | The release-day constants | Not a script: #381 sets them on 2 Nov, before RC1 (Q2). |

## 6. The read-wtf checklist

`launch.py read <step>` runs `scripts/read-wtf.sh` (in-game-verification.md › The reader) with the step's flags and prints only the step's sections, after the `!BugGrabber.lua` write time. Check that time against the dev's action before reporting anything. It passes the installed addon's `Catalogue.lua`, `HuntList.lua` and `EventList.lua` when `WOW` holds them, so RC1's data is read, not the repo's. Arguments after `--` go to read-wtf.sh as they are (`-- --now T`, `-- --hunt <id>`). `read --list` prints this table. The exit code is read-wtf's: 1 means an `--expect-casts` check failed.

| Step | Dev step | Sections | Flags |
|---|---|---|---|
| `reload` | any `/reload` or logout | Lua errors | – |
| `first-login` | the Letter, M8.5 steps 1–2 | Lua errors, Onboarding, Addons | – |
| `check1` | Pagle_Stats off and on | Lua errors, Addons | – |
| `check15` | the Angleur stub | Lua errors, Addons | the six and `--addon Angleur` |
| `probe` | 10 Casts, `/pagle dev probe` | Lua errors, Probe, Catch log, Re-verification (checks 4, 6), Exit check | `--expect-casts N`, `--since $T0` |
| `check9` | the kill | Lua errors, Catch log, CVars | `--cvar` for each leased CVar in `Pagle_QoL/logic/Stretch.lua` (QOL-R62, QOL-R67) |
| `big-log` | checks 2 and 10 | Lua errors, Re-verification | – |
| `places` | checks 5, 6, 7 | Lua errors, Re-verification, Field report | – |
| `check16` | the set limit | Lua errors, Probe; `Pagle_QoL.lua`'s `PagleQoLDB.global.gear` by hand | – |
| `onboarding` | M8.5 steps 3–16 | Lua errors, Onboarding | – |
| `m8` | M8 steps 1–7 | Lua errors, Hunts, Activity XP, Ledger M4, Wallet, Tackle Board | `-- --now T` when needed |
| `fresh-install` | #276 steps 2–3 | Lua errors, Catch log, Ledger, Hunts, Stats, Tackle Board, Wallet, Varieties, Field report, Exit check | `--expect-casts 10 --since <install time>` |

**Rehearsed on 23 Oct** against the repo's fixtures under `spec/scripts/fixtures/WTF/Account/` (`--env /nonexistent --account <fixture>`), each step printing exactly its sections: `reload`, `check1`, `check15`, `check9` and `fresh-install` on `M1#1` (`--character 70/Ada-Brook`; check9 read all ten leased CVars, check15 `Angleur: disabled`), `first-login` and `onboarding` on `M8.5#1`, `probe` and `check16` on `M8-Probe#1` (7 of 9 checks FAIL, as the fixture plants) and on `M1#1` with `--expect-casts 4 --since 0` (exit 1, as planted), `big-log` and `places` on `M8-Reverify#1` with `-- --catalogue spec/scripts/fixtures/ReverifyCatalogue.lua`, and `m8` on `M8-Wagers#1` with the fixture catalogue, Hunt list and event pool. On launch night only `launch.env` changes.

### 6.1 launch.env

`~/pagle-launch.env` in WSL (or `$PAGLE_LAUNCH_ENV`). It names the dev's account, so it stays out of the repo. Plain `NAME=value` lines; bash can source it too.

```sh
# The live install as WSL sees it (post its folder name on #272 on 4 Nov)
WOW="/mnt/g/World of Warcraft/_<live folder>_"
# WTF/Account/<ACCT> (ls "$WOW/WTF/Account/", skipping SavedVariables)
ACCT=<ACCT>
# Filled at the first login: the realm folder and <Name>-<Surname> under it
REALM=<realm folder>
CHAR=<Name-Surname>
# The server time (Unix seconds) of the first live Cast, for --since
T0=<unix seconds>
# The live build, from the probe's GetBuildInfo() (Q3), for watch --live-build
BUILD=<build>
```

## 7. RC1 day checklist (Tue 3 Nov)

1. **Main has all of Monday:** #381's PR (constants, project IDs, changelog, surface spec, the hint switch per Q13), the conflict-list PR (check 17), and the Q4 answer on #274. No `--lock` yet.
2. **Spot-check the constants:** `grep -c '^since = 2026-11-05' data/hunts/hunts.toml` gives 12 (the 12 lines that read `2026-11-04` on 23 Oct) and none reads `2026-11-04`; `addons/Pagle_Hunts/logic/Rotation.lua` has `ns.ROTATION_ORIGIN = 1793890800`; `generate-data.py --check` is clean.
3. **The full check** on that head in WSL (`PAGLE_NO_COVERAGE=1 GATE_JOBS=2 scripts/check.sh`), and GitHub Actions green on `main`.
4. **Package:** `scripts/package.sh` from the main checkout (it can't read a worktree). Record the zip's name and `sha256sum` on #380 with the commit SHA, and copy it to `Pagle-RC1.zip` in the scratchpad.
5. **Check the zip:** `launch.py post-tag rc1 --zip <the zip>` (six folders, `LICENSE`, `NOTICE` and `CHANGELOG.md` in `Pagle/`); `unzip -p <zip> Pagle/Pagle.toc | head` shows both project IDs.
6. **Rehearse the live fixes** on a throwaway branch: `launch.py interface 16100`, then `dump` with a fake hash; run the TOC specs one at a time; `git reset --hard` and delete the branch.
7. **Rehearse the read steps** once more on the fixtures (§6) and, read-only, on the beta WTF folder: `launch.py read reload --account "/mnt/g/World of Warcraft/_classic_beta_/WTF/Account/<ACCT>"`.
8. **One watch poll:** `launch.py watch` reads both sources.
9. **Dev:** confirm both secrets in Settings › Secrets and the project IDs in RC1's `Pagle.toc`; tick on #271.
10. **Drafts ready:** the comment drafts for #272, #273, #274 and #276 (checkboxes with blanks for the build, values and verdicts) in the scratchpad, and §8's material up to date.

## 8. Release material

### 8.1 The release notes

`CHANGELOG.md`'s 1.0.0 entry is the GitHub Release body and the CurseForge and Wago changelog (CORE-R74). In the release commit its heading becomes `## 1.0.0 (2026-11-05)`. #381 owns the final text. A read on 23 Oct found two 1.0 features it doesn't name yet. Suggested lines, to check against the spec before they go in:

- Under **Hunts**, after the board's line: "- Pagle Wagers: every few days a Hunt Event opens for about three days, with Hunts in its waters. Land every Hunt's first mark before it closes to settle the wager for Coins and Angler XP, and climb the Wagers ladder to its titles."
- Under **Pagle**, first: "- New to Pagle? A Letter arrives at your first login and opens a short Field guide. After that, notes appear beside each first moment and window, and a First evening list in the tracker shows what to try. `/pagle guide` opens the guide again."
- Under **Commands**: "- `/pagle guide`: the Field guide".
- Only if the hint switch is on at 1.0 (Q13): a line on the Pagle companion and `https://pagle.app/download`.

The listings' "known issues" note, filled at GO:

> Pagle 1.0.0 was checked on Forever build {BUILD} on launch day. Known issues: {none known | one line each, with its ticket}. Report a problem at https://github.com/timemir/pagle-addon/issues, and new fish sightings with `/pagle report`.

The 1.0.1 skeleton, for `CHANGELOG.md` above 1.0.0:

```md
## 1.0.1 (2026-11-0X)

### Fixed

- {what a player saw, in a player's words} (#{n})

### Changed

- {a rule changed by a live check, and what it now does} (#{n})
```

### 8.2 Before GO

The orchestrator records on #380: the release commit's SHA and subject, its Actions run, the zip's name and SHA-256 from `package.sh`, and each group-A check's result link.

### 8.3 The tag

The dev, from their own git, after the GO comment (Q11). Lightweight, the bare version (release.yml, CORE-R74):

```sh
git fetch origin
git rev-parse <release sha>^{commit}       # the SHA in the GO comment
git branch -r --contains <release sha>     # lists origin/main
git tag 1.0.0 <release sha>
git push origin 1.0.0
```

A failed workflow before the uploads: re-run the job on the same tag. Never move or delete a pushed tag.

### 8.4 The GO comment (#380)

```md
**GO for 1.0.0** on {sha} ("{subject}"), {date} {time} CET, Forever build {BUILD}.

- [x] 1. Group A passes: check 12 {link}, Lua errors {link}, check 11 {link}, check 21 {link}, check 20 {link}, Cast recording and check 23 {link}, check 15 {link}, check 17 {link}, M8.5 steps 1–2 {link}, M8 steps 1–3 {link}, #276 steps 1–3 {link}, #381 {link}
- [x] 2. No Pagle Lua error since the release commit was installed (BugGrabber sessions {n}–{m})
- [x] 3. `scripts/check.sh` green in WSL ({T_full}) and in Actions ({run link}); `package.sh`: {zip name}, SHA-256 {sha256}, six folders, LICENSE, NOTICE and CHANGELOG.md in Pagle/
- [x] 4. #381 in full; `released.lock` generated in {sha}, after the last data change
- [x] 5. No open failure on a frozen surface
- [x] 6. CF_API_TOKEN and WAGO_API_TOKEN set; X-Curse-Project-ID {id} and X-Wago-ID {id} in Pagle.toc
- [x] 7. Tier-2 failures ticketed for 1.0.1: {#n, #m | none}

From your own git:

    git fetch origin
    git tag 1.0.0 {sha}
    git push origin 1.0.0

Then the Release workflow runs (about 10 min). An agent checks the release zip with `scripts/launch.py post-tag 1.0.0` and drafts the hand-off to pagle-backend. Announce once CurseForge and Wago both list 1.0.0.
```

A NO-GO names each failing item, its ticket, and the next attempt's time.

### 8.5 The hand-off to pagle-backend

The orchestrator sends this to pagle-backend's session over the cross-session channel and also comments it on #380; pagle-backend mirrors it on its #59. `{sha256}` is the first line of `launch.py post-tag 1.0.0`, read from the GitHub Release's own zip, not the local build.

```md
Pagle 1.0.0 is released: https://github.com/timemir/pagle-addon/releases/tag/1.0.0

- Release zip: {asset name}
- SHA-256: {sha256}
- Tagged commit: {sha}
- Built for Forever build {BUILD}, interface {n}

Pin this zip by its SHA-256 (your PRJ-R63) and fetch it from the GitHub Release (PRJ-R64). Frozen from this tag: `Pagle.API_VERSION` 1, the Catch log's entry tags and the Simulated Size hash (LOG-R66, #267). The Paste copy test sizes (check 25) follow within the week.
```

## 9. With pagle-backend (agreed 23 Oct)

- **Companion hint:** the Companion's first release (v0.1.0) is cut by 1 Nov. pagle-backend gives a firm yes or no on `https://pagle.app/download` before Mon 2 Nov. Yes ships `COMPANION_HINT_ON = true`; no ships it off until 1.0.1.
- **Release candidates:** RC1 (3 Nov) and RC2 go to pagle-backend, each with its zip SHA-256 and commit. It dry-runs its 1.0 pin against RC1.
- **Log format:** 1.0 ships `LOG_FORMAT` 2 (LOG-R18). pagle-backend accepts pre-1.0 logs until its launch (L). At L it wipes dev logs and refuses every format below 2 as `dev_log`. Send it the format-2 Paste vector (`spec/Pagle/fixtures/PasteString.lua`) with the commit that carries it.
- **Signing:** pushed content is signed with `pagle-2026a` at launch, with no switch to `2026b` before 1.0.1.
- **Live pushed-content check:** in S2 (5 Nov 12:00–21:00) on RC2, before GO. Tell pagle-backend's dev the time. In that window pagle-backend schedules an Operator run and a withdrawal for `/reload` checks: `/pagle dev content` reads `connected`, the pushed run shows on the board, and the withdrawal removes it.
- **After the tag:** pagle-backend pins the 1.0 commit on 6 Nov, checks the zip's SHA-256, folds the dev's live log at the tag, and re-exports the web art, which includes `hyjalcrater` if #373 landed.
- **Check 25 (6–7 Nov):** send the real 1.0 Paste strings and the largest size that survives the copy test, for its part cap.
