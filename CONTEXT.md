# Pagle

**Pagle** (after Nat Pagle) is a fishing addon for World of Warcraft: Forever that aims to be the only fishing addon a player needs: progression and collection first, with optional quality-of-life helpers. It observes and rewards; it never plays for the player.

## Language

### Product structure

**Core**:
The always-loaded base addon that every Module depends on. It observes and records Catches but shows the player nothing of its own beyond settings; everything visible belongs to a Module.
_Avoid_: framework, base module, engine

**Module**:
A separately installable addon in the package that a player can disable in the AddOns list, leaving no trace of it loaded.
_Avoid_: plugin, sub-addon, feature

**Ledger**:
The Module for the player's angler identity: the fish journal, levels, mastery and personal records.
_Avoid_: Angler's Ledger, journal module, progression module

**Hunt**:
A target catch that is only possible, or only counts, under detectable conditions such as zone, time of day or a calendar event.
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
The Module for session tracking, catch rates and honest odds.
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
The Angler's permanent, append-only history of Casts, Skill Readings and Prestiges, kept by Core. Everything the Modules show is derived from it.
_Avoid_: history, database, event store

**Skill Reading**:
One character's fishing skill as Pagle saw it at a moment, recorded whenever it is read or changes.
_Avoid_: skill snapshot, skill event

**Species**:
The unit of the fish collection: one kind of fish. A trophy "pound" fish counts toward its family as a size record, not as a Species of its own.
_Avoid_: entry, fish type, item (when meaning the collection unit)

**Sub-collection**:
A small, separately completable collection of non-fish Catches, such as junk or treasure containers.
_Avoid_: category, side collection

**Skill Milestone**:
A fishing skill threshold reached by any of the Angler's characters. It is credited whenever the skill is read, even if it was reached before Pagle was installed.
_Avoid_: skill level-up, rank-up

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
A real, named catch that can't be farmed on an ordinary day, recognised with its own splash, sound and title. It is never an invented item or a combination of conditions.
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
A player setting where nothing pops up and nothing plays; every moment waits for the Session summary. A Legend's splash is the one exception.
_Avoid_: quiet mode, do not disturb

**Session summary**:
The card shown when a fishing session ends, listing everything earned in it, including moments that never popped up.
_Avoid_: recap, report, session stats (which belong to Stats)
