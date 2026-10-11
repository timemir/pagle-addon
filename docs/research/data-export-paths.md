# How addon data can leave the game for a future backend

Research for issue #6, which feeds #10 ("Define the Core data model"). Researched 2026-10-11, against Forever beta builds up to 1.60.1.70291.

**Question.** Addons have no network access. What are the real constraints on the two ways data can leave the game, and what rules do they impose on how the **Core** stores the **Angler**'s data so that a backend or social layer can be added later without a migration?

**Short answer.** Data leaves the game by one of three paths:

1. **SavedVariables on disk, read by a companion app.** This is the only path that can carry the full history. It is batch-only: the client writes the file only on reload, logout, quit or disconnect.
2. **In-game addon messages.** These are 255 bytes each, throttled per prefix to a burst of 10 and then 1 per second, and they go only to other online players. They are blocked entirely during encounter, Mythic+ and PvP-match lockdown. They suit small summaries, never the history.
3. **A copy-paste export string.** This works with nothing installed. It is manual and the user has to start it.

Together these mean the Core should store an **append-only log of Catch events as the source of truth**. Each event needs a stable ID, a server timestamp and game-native IDs. The journal, levels and mastery should be aggregates that can be rebuilt from that log. Everything sits in one versioned, size-budgeted, account-wide SavedVariable.

Source trust levels used below:
- **[P]**: primary, meaning Warcraft Wiki API pages (the community-maintained mirror of Blizzard's API docs) or library and addon source code.
- **[O]**: official vendor support pages.
- **[B]**: beta field reports from addon developers testing the Forever client. These are first-hand but could not be independently verified.

---

## 1. Path A: SavedVariables, then a companion app

### 1.1 How the files work

| Fact | Detail | Source |
|---|---|---|
| Declared in the TOC | `## SavedVariables:` gives one file per account. `## SavedVariablesPerCharacter:` gives one file per character. Both directives can repeat. | TOC format [P][1] |
| Account-wide path | `WTF\Account\<ACCOUNT>\SavedVariables\<AddOn>.lua` | TOC format [P][1], SavedVariables [P][2] |
| Per-character path | `WTF\Account\<ACCOUNT>\<Realm>\<Character>\SavedVariables\<AddOn>.lua` | [P][1][2] |
| Machine-wide scope | `SavedVariablesMachine` exists but is restricted and third-party addons cannot use it. | [P][1] |
| Format | "plain Lua". Any code put in the file "would be overwritten the next time variables are saved". | [P][2] |
| Types saved | "Strings, booleans, numbers and tables are the only variable types that will be saved". Functions, userdata and coroutines are dropped. "Circular references in tables may not be preserved". Two saved variables that share one table come back as "separate (but identical)" copies. | Saving variables [P][3] |
| Secret values (Midnight) | "Saved variables are no longer allowed to contain secrets". A secret value is replaced with `nil` and a comment. | 12.0.0 planned API changes [P][4] |
| Load timing | Variables load after the addon's own files, then `ADDON_LOADED` fires. `## LoadSavedVariablesFirst: 1` (added in 11.1.5) loads them before the addon's code. | [P][3], [P][1] |
| **Write timing** | Written "when you log out, disconnect, quit the game, or reload your user interface (`/reload`)". `PLAYER_LOGOUT` is "the last event before your saved variables are written". | [P][3] |
| Crash behaviour | Not documented. The `.lua.bak` file next to each save is made by the client and holds the previous save, according to community reports. | community [4b] |

**What this means.** A companion app sees **nothing from the current session until the player reloads or logs out**, and probably nothing at all from a session that ends in a crash. Raider.IO's own addon confirms this. Its Race World First loot logger has a button labelled **"Save"** with the tooltip *"Click to save the log to storage file. This will cause your Interface to Reload."* The tooltip on its minimap button says *"Left-click whenever there is pending loot. This will cause your Interface to Reload."* That data is then uploaded by the Raider.IO Client [P][5]. Even the biggest companion-app vendor can only get data out by forcing a reload.

A community claim says zone changes also flush the files. Warcraft Wiki does not list them as a write point [P][3], so do not depend on that.

### 1.2 Account-wide does not mean Battle.net-wide

- A WoW-account folder (`WTF\Account\<ACCOUNT>`) belongs to one **WoW game account**. One Battle.net account can hold several WoW accounts (WoW1, WoW2, trials, PTR) [P][6]. Each has its own folder, and an addon can only read and write the folder of the account it is logged into (community, [6b]).
- So an Angler stored in `## SavedVariables` is per WoW game account. A player with two WoW licences ends up with two Anglers. A backend that wants one Angler per person needs a merge key.
  - `BNGetInfo()` returns `battleTag`. That is the only person-level identifier visible in game. It is not guaranteed stable, because BattleTags can be changed. Its behaviour on Forever is unverified [P][7].
  - The companion app can read the WTF account-folder name, which is a stable per-game-account identifier.
- **Character identity:** `UnitGUID("player")` returns `Player-<serverID>-<UID>`. Players "keep their GUID forever", and renaming does not change it. Realm transfers and faction changes do create a new GUID [P][8]. Forever puts each ruleset on one mega-realm, so transfers between realms should be rare. Faction changes are not ruled out.

### 1.3 Size and load cost

- There is **no documented size limit** on SavedVariables [P][2][3].
- One thread on the Elder Scrolls Online forums reports load-time failures with very large flat tables, possibly from a Lua constant limit of about 2^17–2^18. That is a different game and could not be confirmed for WoW [9]. Treat a single flat table with hundreds of thousands of entries as a risk.
- The whole file is parsed into memory on every login and reload, so size costs load time and memory for every player, not only those using a backend.
- **Precedent from Raider.IO** [P][5]:
  - Its RWF log is trimmed: entries older than `LOG_ITEM_TRIM_IF_OLDER = 259200 -- 3 days` are removed.
  - `RaiderIO_CachedRuns` is wiped every season.
  - Raider.IO can afford this because the uploaded copy is the system of record. **We cannot**, because until a backend exists the SavedVariables file is the only copy of the Angler.

### 1.4 How companion apps actually work

| App | What it reads | What it writes | Source |
|---|---|---|---|
| **Raider.IO Client** | The addon's account-wide SavedVariables: `RaiderIO_Config`, `RaiderIO_LastCharacter`, `RaiderIO_MissingCharacters`, `RaiderIO_MissingServers`, `RaiderIO_CachedRuns`, `RaiderIO_RWF`, `RaiderIO_CompletedReplays`. It does not use per-character variables. | Regenerates `db/*.lua` data files inside the addon folders: about 270 MB across 100 region and type sub-addons, updated "multiple times each day". | RaiderIO.toc and core.lua [P][5]; README [P][5] |
| **TSM Desktop App** | The `TradeSkillMaster.lua` SavedVariables, which it backs up automatically and, with Premium, syncs to TSM servers. | Pricing data in the `TradeSkillMaster_AppHelper` addon's `AppData.lua`. TSM asks users to mark its addons "Ignored" in addon managers, because they would otherwise overwrite the app-written file. | TSM support [O][10][11] |
| **WarcraftLogs / Archon uploader** | Not SavedVariables at all. It reads `Logs\WoWCombatLog.txt`, which the client writes during play once `/combatlog` or `LoggingCombat()` is on. `LoggingCombat()` is limited to "5 calls per 10 seconds, shared across all addons". | Nothing to the game. | LoggingCombat [P][12]; uploader docs [O][13] |

What this means for us:

- The combat-log file is the **only near-live file an addon can influence**, and it contains combat events, not addon data. It is not a channel for fishing data, so in practice SavedVariables is the only file export.
- Data going back into the game (backend → game) has the same batch shape. A companion can write Lua files into an addon folder, but the client only reads them at login or reload. Addon managers may also overwrite them.
- Every companion parses the client-written Lua table text. Blizzard does not document how that text is formatted. Write data that parses as plain Lua data whatever the formatting: tables, strings, numbers and booleans, nothing clever.

Raider.IO's record design is directly relevant to ours [P][5]. In core.lua:

- `lootEntry.timestamp = ... GetServerTime()`
- `lootEntry.guid = lootEntry.guid or format("%05d %010d %s", index, timestamp, linkAsKey) -- attempt to create unique loot guid when the item is inserted into the SV`
- `-- Additional info for dedup in backend`
- Characters are keyed as `region-name-realmslug`.
- `ReplayCompletedSummary` records carry `completedAt = time()` and a server run ID.

The backend deduplicates by a GUID the addon stamps at write time. That is the pattern to copy.

### 1.5 Forever-specific state of SavedVariables

- **Early beta builds did not load SavedVariables.** On 1.60.1.69893 they were *"written but never loaded"*, so every addon started from defaults [B][14].
- Persistence was **confirmed on build 1.60.1.70291** for both account-wide and per-character variables, including a cold start after a full quit. On-disk evidence suggests it started working around build 69977, with medium confidence [B][15].
- On Forever, both tables are `nil` at file scope and become tables at `ADDON_LOADED`, the same as Retail [B][15].
- **`ReloadUI()` is protected on the Forever beta** (baseline research, `forever-addon-kit`). So the Raider.IO pattern of a "Save" button that calls `ReloadUI()` may not be available. The player would have to type `/reload` or log out.
- **The install folder name is unconfirmed.** Beta reports use `_classic_beta_` [B][16]. The TOC suffix is `_Camelot` or `_Forever` (Patch 1.60.1 added the "Camelot game type", with Forever as an alias) [P][1]. A future companion app must find the folder rather than hard-code `_retail_` or a guessed name.

---

## 2. Path B: In-game addon messages

### 2.1 API limits

| Fact | Detail | Source |
|---|---|---|
| Signature | `C_ChatInfo.SendAddonMessage(prefix, message [, chatType [, target]])`. `SendAddonMessageLogged` is for user-generated content. | [P][17] |
| Prefix | At most 16 characters. Must be registered with `C_ChatInfo.RegisterAddonMessagePrefix`. Registration does not survive `/reload`. There is a `MaxPrefixes` result code, but the cap is not documented. | [P][17][18] |
| **Message** | **At most 255 characters.** Bytes 1–255 are allowed; NUL (`\0`) is not. | [P][17] |
| Chat types (Retail/Mainline) | `PARTY`, `RAID`, `INSTANCE_CHAT`, `GUILD`, `OFFICER`, `WHISPER`, `CHANNEL`. Classic instead has `SAY` and `YELL` and no `CHANNEL`. | [P][17] |
| **Throttle** | Per prefix, on every chat type: **10-message allowance, regenerating 1 per second**. When it runs out, the send returns `AddonMessageThrottle`. Whispers outside instances are exempt. "The server can change these values at any time". Sending too much across many prefixes at once can disconnect the client. | [P][17] |
| Result codes | `Enum.SendAddonMessageResult`: Success (which means queued, not delivered), InvalidPrefix, InvalidMessage, AddonMessageThrottle, InvalidChatType, NotInGroup, TargetRequired, InvalidChannel, ChannelThrottle, GeneralError, NotInGuild, **AddOnMessageLockdown**, **TargetOffline**. | [P][17], 12.0.0 API changes [P][19] |
| Receive | The `CHAT_MSG_ADDON` event carries prefix, text, channel, sender, target and channel index/name. | [P][20] |

Steady-state bandwidth is about **1 message per second per prefix, so about 255 B/s at best**, with a 10-message (≈2.5 KB) burst.

### 2.2 AceComm-3.0 and ChatThrottleLib

- **AceComm-3.0** (MINOR 14) sends "messages of unlimited length" by splitting them into 255-byte parts, using control bytes `\001`, `\002` and `\003` (so 254 payload bytes per part). The receiver reassembles parts keyed by prefix, distribution and sender. Orphaned parts are dropped silently [P][21][22].
- AceComm does not check result codes or lockdown itself. It sends through ChatThrottleLib, and its callback reports `sendResult` [P][22].
- **ChatThrottleLib** (v32) [P][23]:
  - `MAX_CPS = 800` and `BURST = 4000`. The server buffer is "about 32KB", and the library uses 4 KB to be safe.
  - `MSG_OVERHEAD = 40`. It halves throughput when FPS drops below 20.
  - Priorities are `BULK`, `NORMAL` and `ALERT`.
  - It handles the per-prefix throttle (added in v25) by moving throttled pipes to a blocked ring that is retried every 0.35 s.
- **LibDeflate**: `EncodeForWoWAddonChannel` removes NUL bytes so compressed data can be sent. `EncodeForPrint` produces copy-paste text, which "will make the data 25% bigger" [P][24].

### 2.3 Midnight lockdown, which carries over to Forever

- `C_ChatInfo.InChatMessagingLockdown()` reports whether chat-messaging restrictions are in effect [P][25].
- The final scope narrowed during the 12.0 alpha. At first it covered all instances. It now applies only during an **active Mythic+ run, an unfinished PvP match, or an encounter in progress**. The restriction types are `Combat`, `Encounter`, `ChallengeMode`, `PvPMatch` and `Map` [P][4].
- During lockdown:
  - Addons cannot send addon messages or chat.
  - Chat payloads become secret.
  - `UnitIsAFK`/`UnitIsDND` return secrets.
  - **Calendar event information is secret** [P][4].
- Blizzard says it "addressed a whole host of addon communication workarounds" before release [P][4].
- The CVar `addonChatRestrictionsForced` forces the client into lockdown, for testing [P][19].
- **On Forever:** a Forever addon developer reports that *"the Forever client refuses addon messages during an encounter"*, detected with `InChatMessagingLockdown()`, and that unqueued sends are "lost outright" [B][26].

### 2.4 Channels on Forever's mega-realms

- Every player in a ruleset and region shares one realm. `GUILD`, `PARTY`, `RAID` and `WHISPER` to any online player by name all work as on Retail. `TargetOffline` (12.0.0) reports a whisper to an offline player.
- **Public channels are refused.** On build 70058, `CHANNEL` sends to General, Trade, LocalDefense and Services return Success, but the server then refuses them with *"That operation is not permitted in this channel."* Outside a city, Trade and Services return `InvalidChannel` [B][27].
- **Custom channels work, from one test.** A hidden player-made channel joined with `JoinTemporaryChannel()` from a timer delivered an addon message. Only the sender's own echo was confirmed [B][27].
  - Not tested: delivery to other players, whether Horde and Alliance share the channel, and the `ChannelThrottle` limits.
  - The same test found `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()` returned true. Plain chat text from addons is likely blocked.

### 2.5 What this path can and cannot do

- It **cannot reach a backend.** A message only reaches other WoW clients that are online at that moment. A backend would still need some player's companion app to pick up what that client received, by way of SavedVariables.
- It cannot carry history. At about 255 B/s, sending a 1 MB log would take more than an hour of saturated channel.
- It is fine for social features that are out of scope for now: small, versioned, compressed summaries such as a "Ledger card" snapshot or a Hunt ping, sent on `GUILD`, `WHISPER` or a custom channel, queued during lockdown.

---

## 3. Path C: Copy-paste export string (no install needed)

- The addon serialises a selection (for example, the log since the last export), compresses it and encodes it with LibDeflate `EncodeForPrint`, then shows it in an EditBox for the player to copy [P][24]. The player pastes it into a website.
- This is the WeakAuras/Wago pattern. It needs no companion app, no file access and no reload.
- It is manual, so it cannot sync automatically.
- It is a cheap bridge if a backend arrives before a companion app does. It uses the same log and cursor design as Path A.

---

## 4. Design rules for the Core data model (input for #10)

Each rule names the constraint that forces it.

1. **One account-wide SavedVariable owned by the Core is the system of record.** It lives under `## SavedVariables`, and per-character variables hold only UI state. *Why:* the Angler is account-wide, Raider.IO uses account-wide variables only, and a companion then has one file per WoW account to read. Every Module writes through the Core and none declares its own copy of the Angler (§1.1, §1.4).

2. **Append-only Catch log as the source of truth; journal, levels, mastery and records are rebuildable aggregates.**
   - *Why:* the backend receives the file in batches, after the fact (§1.1). It must be able to replay what happened, not just see current totals.
   - Totals cannot be merged across two WoW accounts, or across a lost upload. Events with IDs can.
   - Aggregates are a cache. They can be recomputed when XP or mastery rules change, so rebalancing never needs a data migration.
   - Corrections are new events, such as a void or adjustment. Never rewrite a past event.

3. **Every event has a stable, globally unique ID stamped once at write time.**
   - Suggested format: `<character GUID UID part>-<server time>-<per-session sequence>`.
   - *Why:* a companion will re-read the same file many times, and two WoW accounts or two machines may both upload. The backend deduplicates on this ID, which is the Raider.IO `guid` / "dedup in backend" pattern (§1.4).
   - Also keep a **monotonic per-account sequence number** so a companion can resume from a cursor ("everything after seq N").

4. **Timestamps use `GetServerTime()` (UTC epoch seconds), never `time()` or local strings.** *Why:* the server clock is "synchronized between clients", while `time()` follows the local clock [P][28]. Hunts are judged against server time anyway. Seconds can collide, which is why the sequence number exists.

5. **Store game-native IDs, never localised names.**
   - Use itemID for the Catch, uiMapID and subzone/area IDs for location, and the character GUID for the character.
   - Name-realm is display data only.
   - *Why:* the backend must join on IDs across locales. GUIDs survive renames, but realm or faction moves change them (§1.2). Keep a **character table keyed by GUID** that can record "same character as GUID X" later.

6. **Leave room for a person-level merge key, but do not depend on one.**
   - Record the WoW account context the companion can see, which is the folder name.
   - Optionally record `battleTag` if it is available on Forever.
   - The backend, not the addon, decides how to merge Anglers. *Why:* "account-wide" means per WoW game account, not per Battle.net account (§1.2).

7. **Version the schema explicitly.**
   - The top-level `schemaVersion` integer is migrated in place at `ADDON_LOADED`.
   - Each log segment or event shape carries the version it was written under, so a companion can parse old data without running the addon's migrations.
   - *Why:* companions parse the raw file (§1.4). Migrations that rewrite history break the cursor and the IDs. An additive-only evolution of event shapes avoids this.

8. **Store only plain data.**
   - Use strings, numbers, booleans and tables, with no shared or cyclic references and no functions.
   - Never store a value that could be secret, because it would silently become `nil` (§1.1).
   - Keep keys simple, using strings or array indices.

9. **Budget size from day one.**
   - Use compact positional records, for example `{seq, serverTime, itemID, mapID, flags}` rather than verbose keyed tables.
   - Set a target ceiling, for example a few MB, together with a **compaction policy**. Old raw events roll up into per-day × place × item counts, and the per-event record is kept only where it matters (firsts, records, rares, Hunts).
   - Compaction must keep IDs and the sequence intact, so a cursor still works.
   - *Why:* there is no documented limit, but the whole file is parsed on every login, and very large flat tables are a known risk (§1.3).
   - Unlike Raider.IO we cannot simply trim, because the file is the only copy until a backend exists.
   - Rough scale: about 600 Catches in a 3-hour session, over 100 such sessions, gives about 60k, which at roughly 80–120 bytes each comes to **5–7 MB uncompacted**.

10. **Assume the newest session is not yet exported.**
    - Nothing leaves before a reload or logout, and probably nothing survives a crash (§1.1).
    - Do not design features that promise near-real-time sync.
    - Do not rely on a "Save" button that calls `ReloadUI()`, because it is protected on the Forever beta (§1.5).

11. **Keep the comms payload separate from the storage schema.**
    - Social messages, when they come, are small, compressed, versioned snapshots or pings with their own `protocolVersion`.
    - Peer data is untrusted and never written into the Angler's log.
    - Sends are queued while `InChatMessagingLockdown()` is true and when throttled.
    - *Why:* 255-byte messages, a per-prefix throttle and lockdown (§2).

12. **Exports are idempotent views of the log.** Both the companion (Path A) and the copy-paste string (Path C) export "events after seq N" in the same shape. The backend accepts duplicates without harm.

---

## 5. Open questions, to verify in the Forever client before relying on them

- Whether SavedVariables are written on a client crash, and whether `/reload` flushes them on Forever. Persistence across reload and quit is confirmed [B][15]; crash behaviour is not.
- Whether `ReloadUI()` is still protected on live Forever.
- The live install folder name and WTF path.
- Whether `BNGetInfo()` returns a `battleTag` on Forever.
- Custom-channel delivery between players, whether Horde and Alliance share channels, and the `ChannelThrottle` limits on Forever [B][27].
- Whether calendar-event secrecy during lockdown affects Hunts. Fishing happens in the open world, so lockdown should rarely apply.
- The practical size at which a SavedVariables file noticeably slows Forever's load screen. Measure this with a synthetic 5 MB and 20 MB log.

---

## Sources

1. TOC format — https://warcraft.wiki.gg/wiki/TOC_format [P]
2. SavedVariables — https://warcraft.wiki.gg/wiki/SavedVariables [P]
3. Saving variables between game sessions — https://warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions [P]
4. Patch 12.0.0/Planned API changes — https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes [P]
4b. `.lua.bak` behaviour (community) — https://eu.forums.blizzard.com/en/wow/t/addon-profiles-disappeared/147019 ; https://wowinterface.com/forums/showthread.php?p=323423
5. Raider.IO addon source (commit f317282, 2026-10-11) — https://github.com/RaiderIO/raiderio-addon (`RaiderIO.toc`, `core.lua` LogItemLink / TrimHistoryFromSV / SaveLiveSummary, `locale/enUS.lua`, `README.md`) [P]
6. Account — https://warcraft.wiki.gg/wiki/Account [P]; 6b. per-account WTF folders (community) — https://www.wowinterface.com/forums/archive/index.php/t-43937.html
7. BNGetInfo — https://warcraft.wiki.gg/wiki/API_BNGetInfo [P]
8. GUID — https://warcraft.wiki.gg/wiki/GUID [P]
9. ESO forum, large saved-variable load failure (not WoW) — https://cdn.esoui.com/forums/showthread.php?p=33190
10. TSM support: AppData.lua empty — https://support.tradeskillmaster.com/addon/how-do-i-fix-an-error-about-appdatalua-being-empty [O]
11. TSM support: restoring backups — https://support.tradeskillmaster.com/how-do-i-restore-a-backup-of-my-addon-settings [O]
12. LoggingCombat — https://warcraft.wiki.gg/wiki/API_LoggingCombat [P]
13. Warcraft Logs / Archon uploader — https://www.archon.gg/wow/articles/help/uploader ; https://warcraftlogs.com/companion [O]
14. Blizzard beta forum: "Addon SavedVariables never load on 1.60.1.69893" — https://eu.forums.blizzard.com/en/wow/t/addon-savedvariables-never-load-on-160169893/629799 [B]
15. Tgaarden/Gaar.WowAddons PR #18, "SavedVariables persist on WoW Forever (70291); Forever is project 18" (merged 2026-10-09) — https://github.com/Tgaarden/Gaar.WowAddons/pull/18 [B]
16. Workaround thread with `_classic_beta_` paths — https://eu.forums.blizzard.com/en/wow/t/workaround-for-addon-settings-savedvariables-resetting-on-forever-beta/630138 [B]
17. C_ChatInfo.SendAddonMessage — https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage [P]
18. C_ChatInfo.RegisterAddonMessagePrefix — https://warcraft.wiki.gg/wiki/API_C_ChatInfo.RegisterAddonMessagePrefix [P]
19. Patch 12.0.0/API changes — https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes [P]
20. CHAT_MSG_ADDON — https://warcraft.wiki.gg/wiki/CHAT_MSG_ADDON [P]
21. AceComm-3.0 API — https://www.wowace.com/projects/ace3/pages/api/ace-comm-3-0 [P]
22. AceComm-3.0 source — https://repos.wowace.com/wow/ace3/trunk/AceComm-3.0/AceComm-3.0.lua [P]
23. ChatThrottleLib source (v32) — https://repos.wowace.com/wow/ace3/trunk/AceComm-3.0/ChatThrottleLib.lua [P]
24. LibDeflate README — https://github.com/SafeteeWoW/LibDeflate [P]
25. C_ChatInfo.InChatMessagingLockdown — https://warcraft.wiki.gg/wiki/API_C_ChatInfo.InChatMessagingLockdown [P]
26. eliog/DEABingo #43, "Queue addon messages during the Forever chat lockdown" — https://github.com/eliog/DEABingo/issues/43 [B]
27. Offroads/WoWForeverRace #40, "Realm-wide sync over a hidden custom chat channel" (build 70058) — https://github.com/Offroads/WoWForeverRace/issues/40 [B]
28. GetServerTime — https://warcraft.wiki.gg/wiki/API_GetServerTime [P]
