# Pagle

**Pagle** (after Nat Pagle) is a fishing addon for World of Warcraft: Forever that aims to be the only fishing addon a player needs: progression and collection first, with optional quality-of-life helpers. It observes and rewards; it never plays for the player.

## Language

### Product structure

**Core**:
The always-loaded base addon that every Module depends on. It observes and records Catches, and presents the Announcements Modules raise through it; beyond that and settings it shows the player nothing of its own, and every other view belongs to a Module.
_Avoid_: framework, base module, engine

**Module**:
A separately installable addon in the package that a player can disable in the AddOns list, leaving no trace of it loaded.
_Avoid_: plugin, sub-addon, feature

**Ledger**:
The Module for the player's angler identity: the fish journal, levels, mastery and personal records.
_Avoid_: Angler's Ledger, journal module, progression module

**Hunt**:
A target catch (one Species, or a class of Catch such as "rare or better") that is only possible, or only counts, under detectable conditions that open and close: a time of day, a season, a calendar event, or an aura the player starts. A fish tied only to a zone is not a Hunt; the Ledger covers it. A Hunt completes once, and may have further tiers after that.
_Avoid_: quest, challenge, bounty

**Hunts**:
The Module that tracks Hunts and shows which are possible now, soon or later.
_Avoid_: Hunt board, Hunt module

**Tackle Board**:
The Module offering opt-in rotating goals that bank when missed and never punish absence.
_Avoid_: dailies, quests, challenges

**QoL**:
The Module of convenience helpers (cast key, gear, lures, clams) where each player keypress triggers at most one game action.
_Avoid_: automation, helpers, utility module

**Stats**:
The Module for Session and lifetime numbers, Your odds and Dry spells. It shows numbers on request and announces nothing.
_Avoid_: tracker, metrics

### Fishing

**Angler**:
The player's fishing identity, shared across every character on one WoW game account. Two game licences under one Battle.net login are two Anglers.
_Avoid_: character, profile, player (when meaning the progression owner)

**Cast**:
One fishing attempt that ended, either with Catches or with the fish getting away. An attempt cut short before a bite is not a Cast.
_Avoid_: attempt, throw, fishing action (when meaning the stored record)

**Catch**:
One item brought up by a fishing action, including junk and treasure. It counts once offered, whether or not it reaches the bags. Every Catch belongs to one Cast.
_Avoid_: fish (when junk/treasure is included), loot, drop

**Catch log**:
The Angler's permanent, append-only history of Casts, Skill Readings and Prestiges, and of the game client builds they were recorded on, kept by Core. Everything the Modules show is derived from it.
_Avoid_: history, database, event store

**Skill Reading**:
One character's fishing skill as Pagle saw it at a moment, recorded whenever it is read or changes.
_Avoid_: skill snapshot, skill event

**Session**:
A run of the Angler's Casts with no break of 15 minutes or more, across characters and zones. It is cut from the Catch log after the fact, never stored.
_Avoid_: Fishing stretch (QoL's live span), trip, outing

**Species**:
The unit of the fish collection: one kind of fish. A trophy "pound" fish counts toward its family as a size record, not as a Species of its own.
_Avoid_: entry, fish type, item (when meaning the collection unit)

**Sub-collection**:
A small, separately completable collection of non-fish Catches, such as junk or treasure containers.
_Avoid_: category, side collection

**Skill Milestone**:
A fishing skill threshold reached by any of the Angler's characters. It is credited whenever the skill is read, even if it was reached before Pagle was installed.
_Avoid_: skill level-up, rank-up

**Content data**:
Pagle's shipped knowledge of the fishing world: which items are Species, trophies, junk or treasure, what bites where and when, and which facts are confirmed in-game. Everything the Modules show is derived from the Catch log read through it. It changes only with an addon release.
_Avoid_: database, loot table, game data (which is Blizzard's)

**Field report**:
The text an Angler copies out of Pagle to share what they have seen in-game that the content data doesn't yet confirm, such as Uncharted Catches or a fish outside its stated window. It carries observations, never the Catch log, and nothing that names the Angler's characters.
_Avoid_: report (alone), data dump, export (which is the backup string), Session summary

**Noise**:
A Catch the content data knows but that counts toward nothing, such as a random world-drop green or potion. It is logged like any Catch and earns only Catch XP.
_Avoid_: junk (which is a Sub-collection), Uncharted (which the data doesn't know yet)

### Progression

**Angler Level**:
The Angler's effort-based level. It rises from XP earned on every Catch and on discoveries, and always keeps moving.
_Avoid_: fishing level, rank, skill (which is the game's own fishing skill)

**Prestige**:
Starting the Angler Level over from 1, after reaching its cap, in exchange for a permanent prestige rank.
_Avoid_: reset, rebirth, paragon

**Fresh Water**:
Bonus XP on Catches made after a break from fishing, the Pagle counterpart to WoW's rested XP. It is a bonus, never a penalty.
_Avoid_: rested XP, Rested Angler (that belongs to the Tackle Board), diminishing returns

**Zone Mastery**:
The Angler's rank in one zone, earned by the breadth of what they have caught there, not the volume.
_Avoid_: zone level, zone progress

**Species Mastery**:
The Angler's star rating on one Species.
_Avoid_: fish level, species rank

**Trophy Room**:
The Sub-collection of trophy "pound" fish families, recording the real weights the Angler has caught.
_Avoid_: trophy collection, size records (when meaning real weights)

**Legend**:
A real, named catch that can't be farmed on an ordinary day, recognised with a splash, the Legend sting every Legend shares, and its own title. It is never an invented item or a combination of conditions.
_Avoid_: rare, legendary, addon legend

**Uncharted**:
A Catch whose item Pagle's content data doesn't know yet. It is logged and credited retroactively once the data classifies it.
_Avoid_: unknown item, unclassified loot

**Ledger completion**:
The Angler's bounded 100%: every Species caught, every Sub-collection item and every Zone Mastery at Master. Legends and stars sit outside it.
_Avoid_: 100%, completionist score, total progress

**Simulated Size**:
Pagle's own size for a fish Catch, shown as flavour and kept as personal records. It never counts toward progression and is never presented as game data.
_Avoid_: weight (which is the real number on trophy fish), size roll

**Catch Milestone**:
A lifetime Catch count the Angler reaches, such as the 1,000th Catch, recognised with a banner. It is recognition only and earns no XP.
_Avoid_: Skill Milestone (which is about fishing skill), catch achievement

### Feedback

**Announcement**:
Pagle telling the player, in the moment, about something they just earned. One Cast produces at most one Announcement; every moment it earned rides on it as a stamp. By weight it is a nod, a toast, a banner (level and rank news) or a splash (a Legend).
_Avoid_: notification, alert, popup

**Nod**:
The quietest Announcement: one silent line, for minor moments or toasts stepped down by the Interruption budget.
_Avoid_: mini toast, whisper

**Interruption budget**:
The player's limit on how often Pagle may interrupt within a stretch of fishing. When it is spent, low-priority toasts step down to Nods; everything else still gets through. The player can switch it off.
_Avoid_: rate limit, throttle, cooldown

**Cozy mode**:
A player setting where nothing pops up and nothing plays; every moment waits for the Session summary. A Legend's splash is the one exception, and it shows silently.
_Avoid_: quiet mode, do not disturb

**Session summary**:
The card shown when a Session in which something was earned ends, listing everything earned in it, including moments that never popped up. A Session that earned nothing ends quietly.
_Avoid_: recap, report, session stats (which belong to Stats)

**Write-up**:
The single card shown when a Module first builds from history it never saw, such as a Module the player enables late, listing what that history earned. Everything in it counts as already celebrated, so none of it pops up on its own.
_Avoid_: catch-up toast, backfill, welcome screen

### QoL

**Fishing key**:
The player's own Pagle key binding that does the next sensible fishing action on each press, such as casting, reeling or applying a lure. It belongs to Pagle all the time, never borrowed from another binding.
_Avoid_: one key, cast key, interact key, action key

**Fishing stretch**:
The live span of fishing that QoL's temporary client settings last for. It starts with a Cast and ends when the pole comes off, the player mounts or enters combat, or a minute passes without a new Cast.
_Avoid_: Session (which is cut from the Catch log after the fact), fishing mode, awake

**Nudge**:
A silent, practical message from QoL about the player's setup, such as running out of lures. It is never an Announcement, since nothing was earned, and it still shows in Cozy mode.
_Avoid_: reminder, warning, Nod (which is an Announcement)

### Hunts

**Natural Hunt**:
A Hunt whose conditions the game itself enforces, such as Nightfin Snapper only biting at night. The Catch alone completes it; its conditions only say when it is worth trying.
_Avoid_: real hunt, game hunt

**Imposed Hunt**:
A Hunt whose conditions are Pagle's own rule, such as a Darkshore Grouper by moonlight. A Catch only counts if the Cast happened under those conditions.
_Avoid_: custom hunt, challenge, addon hunt

**Hunt set**:
A themed group of Hunts. Completing every Hunt in it earns a title shown in Pagle's own views.
_Avoid_: collection (which is the Ledger's), achievement, category

**Retired Hunt**:
A Hunt that no longer appears on the board because it was replaced or proved wrong. Completions already earned are kept.
_Avoid_: removed hunt, deleted hunt, expired hunt

### Stats

**Your odds**:
The per-Cast chance of an item in a place, estimated only from the Angler's own Casts and always shown with how many Casts it rests on. It is never presented as game data.
_Avoid_: drop rate, loot chance (which are the game's own numbers), catch rate

**Dry spell**:
The Casts an Angler has made, in the scope where an item can be caught, since they last caught it. It is shown with how unusual that wait is, never as a promise that the item is due.
_Avoid_: pity, overdue, bad-luck streak
