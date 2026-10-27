# Pagle

**Pagle** (after Nat Pagle) is a fishing addon for World of Warcraft: Forever that aims to be the only fishing addon a player needs: progression and collection first, with optional quality-of-life helpers. It observes and rewards; it never plays for the player.

## Language

### Product structure

**Core**:
The always-loaded base addon that every Module depends on. It observes and records Catches, presents the Announcements Modules raise through it, holds the Angler's Pagle Coins and the Curio Shop, gives out Field reports, and welcomes a new Angler and explains each part the first time it's met; beyond those and settings it shows the player nothing of its own, and every other view belongs to a Module.
_Avoid_: framework, base module, engine

**Module**:
A separately installable addon in the package that a player can disable in the AddOns list, leaving no trace of it loaded.
_Avoid_: plugin, sub-addon, feature

**Ledger**:
The Module for the player's angler identity: the fish journal, levels, mastery and personal records.
_Avoid_: Angler's Ledger, journal module, progression module (one exception: the Angler page's bookplate is printed "The Angler's Ledger" as an in-world title, LED-R146; it never names the Module)

**Fish Journal**:
The Ledger's book, where the Angler reads their progress: the waters they have fished, each Species' page, the collections, Legends and their titles. Fish not yet caught stay nameless in it.
_Avoid_: Ledger (which is the Module), codex, encyclopedia

**Hunt**:
A target catch (one Species, or a class of Catch such as "rare or better") that is only possible, or only counts, under detectable conditions that open and close: a time of day, a season, a calendar event, an aura the player starts, or the run of the Hunt Event it belongs to. A fish tied only to a zone is not a Standing Hunt (the Ledger covers it), but it can be a Hunt within a Hunt Event, whose run is its condition. A Hunt completes once (a Hunt Event's Hunt, once per run), and may have further tiers after that.
_Avoid_: quest, challenge, bounty

**Hunts**:
The Module that tracks Hunts and shows which are possible now, soon or later.
_Avoid_: Hunt board, Hunt module

**Tackle Board**:
The Module offering opt-in rotating goals (Notices and Expeditions) that never expire, so missed days bank rather than vanish, and that never punish absence.
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
The Angler's permanent, append-only history of Casts, Skill Readings, Prestiges, Curio Shop purchases and Module records, and of the game client builds they were recorded on, kept by Core. Everything the Modules show is derived from it.
_Avoid_: history, database, event store

**Module record**:
An entry a Module has Core append to the Catch log for something only that Module understands and the log couldn't otherwise rebuild, such as a Notice being issued or rerolled. Core stores it without reading it.
_Avoid_: Module event, Module data, choice

**Skill Reading**:
One character's fishing skill as Pagle saw it at a moment, recorded the first time Pagle sees the character and whenever its skill rank or cap changes.
_Avoid_: skill snapshot, skill event

**Session**:
A run of the Angler's Casts with no break of 5 minutes or more, across characters and zones. It is cut from the Catch log after the fact, never stored.
_Avoid_: Fishing stretch (QoL's live span), trip, outing

**Species**:
The unit of the fish collection: one kind of fish. A trophy "pound" fish counts toward its family as a weight record, not as a Species of its own.
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
_Avoid_: report (alone), data dump, export (which makes a Paste string), Session summary

**Lore**:
Every name and line of flavour Pagle invents: a Species' blurb and riddle, a Sub-collection plaque, titles, Fly Box patterns, and the names of Curio Shop goods. It ships beside the content data but never changes what anything counts for. Mechanical interface text and the game's own names are not lore.
_Avoid_: flavour text, copy, strings (which covers all interface text)

**Noise**:
A Catch the content data knows but that counts toward nothing, such as a random world-drop green or potion. It is logged like any Catch and earns only Catch XP.
_Avoid_: junk (which is a Sub-collection), Uncharted (which the data doesn't know yet)

### Progression

**Angler Level**:
The Angler's effort-based level. It rises from XP earned on every Catch and on discoveries, and from Activity XP, and always keeps moving.
_Avoid_: fishing level, rank, skill (which is the game's own fishing skill)

**Activity XP**:
XP that a Module other than the Ledger pays toward the Angler Level for something achieved there, such as a Hunt's tier. It is shown by source, so what disabling a Module costs stays visible.
_Avoid_: external XP, bonus XP, XP income

**Prestige**:
Starting the Angler Level over from 1, after reaching its cap, in exchange for a permanent prestige rank.
_Avoid_: reset, rebirth, paragon

**Prestige frame**:
The portrait frame round the Angler's likeness on the Fish Journal's bookplate and on the Prestige banner, which shows their prestige rank: an unwritten one before the first Prestige, one of its own for each rank I to X, then the Master's. It is earned, never bought.
_Avoid_: Prestige crest, crest (alone), border, bookplate crest (which is the look pinned on it)

**Prestige emblem**:
The small badge for a prestige rank, its Prestige frame in miniature with its numeral, shown beside the Prestige line and the Angler Level, on the Prestige confirm and in lists and tooltips. There is none before the first Prestige.
_Avoid_: Prestige crest, seal, badge (alone), rank icon

**Fresh Water**:
Bonus XP on Catches made after a real break from fishing, the Pagle counterpart to WoW's rested XP; a short pause between casts doesn't count. A new Angler starts with a full measure. It is a bonus, never a penalty.
_Avoid_: rested XP, Rested Angler, diminishing returns

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
A real, named catch that can't be farmed on an ordinary day, recognised with a splash, a Legend sting of its own, and its own title. It is never an invented item or a combination of conditions.
_Avoid_: rare, legendary, addon legend

**Uncharted**:
A Catch whose item Pagle's content data doesn't know yet. It is logged and credited retroactively once the data classifies it.
_Avoid_: unknown item, unclassified loot

**Ledger completion**:
The Angler's bounded 100%: every Species caught, every Sub-collection item and every Zone Mastery at Master. Legends and stars sit outside it.
_Avoid_: 100%, completionist score, total progress

**Simulated Size**:
Pagle's own length for a Species Catch, decided by the Catch, the catching character's fishing skill at the time and how many of that fish the Angler had caught before, never by lures, auras, conditions or place. Skill and experience don't make the fish bigger; they set how big a fish the Angler can land. It is shown with its Size band and kept as personal records per Species. A Hunt may ask for a Size band (a Tackle Board goal never does), but it never earns Angler Level XP, stars, Zone Mastery or Ledger completion, and it is never presented as game data.
_Avoid_: weight (which is the real number on trophy fish), size roll

**Reach**:
The longest Simulated Size the Angler can land of a fish at a given Cast: the lesser of what the catching character's fishing skill allows and what the Angler's earlier Catches of that fish allow. Their first Catch of a fish is always its smallest length, and every Catch is at most the Reach. Legends have no Reach.
_Avoid_: cap, ceiling, max size, limit

**Size band**:
The word that places a Simulated Size within its Species' range: Tiddler, Decent, Hefty, Whopper or Monster. It stands in for heft; Pagle never shows a simulated weight.
_Avoid_: weight, bracket, size class, trophy (which is a real pound fish)

**Variety**:
One of the ten looks a sized Species comes in, such as a Firefin Snapper's Coral. Every Catch of that Species is exactly one of them, fixed by its Catch ID and independent of its size. Until the Angler first catches a variety, Pagle shows only its rarity, never its name or colours.
_Avoid_: colour, skin, morph, variant

**Rarity**:
How often a Variety turns up: Common, Uncommon, Rare or Epic. Each Species has four Common, three Uncommon, two Rare and one Epic.
_Avoid_: quality (which is an item's own grade in the game), tier

**Zone crest**:
A Bookplate crest earned when its zone reaches Master: the zone's shield.
_Avoid_: zone badge, Mastery crest

**Fish crest**:
A Bookplate crest earned by catching all ten varieties of one Species.
_Avoid_: species crest, variety crest

**Legend crest**:
A Legend's own crest, holding its icon, on the Fish Journal's Legends spread and plate and on the Legend splash; a Legend not yet caught, or one with no crest of its own, shows the Unwritten crest. It is never worn on the bookplate.
_Avoid_: Prestige crest, legend frame, crest (alone)

**Catch Milestone**:
A lifetime Catch count the Angler reaches, such as the 1,000th Catch, recognised with a banner. It is recognition only and earns no XP.
_Avoid_: Skill Milestone (which is about fishing skill), catch achievement

### Feedback

**Announcement**:
Pagle telling the player, in the moment, about something they just earned. One Cast produces at most two Announcements, shown at the same time: a big one for its banners and splash, and a catch one for its toasts and nods; the other moments on each side ride on it as stamps. By weight it is a nod, a toast, a banner (level and rank news) or a splash (a Legend).
_Avoid_: notification, alert, popup

**Nod**:
The quietest Announcement: one silent line, for minor moments and for toasts stepped down by the Interruption budget (a **catch toast** that steps down reads "Mud Snapper · Decent · 34.2 cm").
_Avoid_: mini toast, whisper

**Catch toast**:
The toast Core shows for an ordinary Catch when nothing bigger came of it: the size band and length ("DECENT · 34.2 CM") over the fish's name, with the toast sound. It counts toward the Interruption budget, and steps down to a Nod when the budget is spent. The player can switch it off with Show every catch.
_Avoid_: catch Nod

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

### Onboarding

**Letter**:
The note Pagle leaves a new Angler once, on arrival, that opens the Field guide. An Angler whose Catch log already holds Casts gets none.
_Avoid_: welcome popup, splash (which is a Legend's Announcement)

**Field guide**:
Pagle's short book of pages introducing each part that is on, opened from the Letter and reopened whenever the Angler asks.
_Avoid_: tour (which is the dev screenshot tour), tutorial, onboarding (the internal name for the whole effort)

**Margin note**:
A pencilled slip beside something on screen, with an arrow to it, explaining it the first time the Angler meets it. Each one shows once per Angler.
_Avoid_: tooltip, hint, coach mark

**First look**:
The set of Margin notes shown together on a window the first time it opens, and again whenever the Angler asks for it on that window.
_Avoid_: coach, walkthrough, help page

**First evening list**:
A short list of first things to do with Pagle, which ticks itself off as the Angler does them and folds away when done. It pays nothing.
_Avoid_: checklist, quest, tutorial goals

### Pagle Coins

**Pagle Coins**:
Pagle's one currency, held by Core for the Angler. Modules pay it in for things achieved (a Notice, a new Species, a Hunt completed), never for raw volume, and it buys only looks in the Curio Shop. Disabling a Module never takes back what it paid (only a rebalance can recount it), the balance never goes below zero, and nothing bought is ever taken back.
_Avoid_: currency (alone), points, gold, Tender (Retail's Trading Post currency)

**Curio Shop**:
Core's shop where the Angler spends Pagle Coins on looks for Pagle's own views, such as toast styles, sound sets, bindings and tracker frames. It never sells meanings (titles, flies, stars, Legends) and its stock never rotates.
_Avoid_: store, Trading Post, Bait Shop, shop (alone)

**Refresh** (working name):
What a Hunt Event earns (players know it as a Pagle Wager) and the Tackle Board spends to post one new goal, a Notice or an Expedition at the Angler's choice, into an empty slot. It never takes the board past its caps and is not a reroll. Core holds the count (Hunts reports the Refreshes earned, the Tackle Board the ones spent), and there is no limit on how many can be held. The name is provisional: renaming it is a glossary and string change only.
_Avoid_: ticket (the code's word, not the Angler's), reroll (which swaps an open goal and adds nothing), voucher, refill, token

**Bookplate crest**:
The look the Angler wears on the Fish Journal's bookplate, chosen in Look and Feel's Crests dropdown: a Zone crest, earned when that zone reaches Master, or a Fish crest, earned when all ten of its varieties are caught, pinned on the Prestige frame, or Plain, the default, which shows nothing. Earned crests are never listed in the Curio Shop, whose Crests category holds only the crests for sale and Plain.
_Avoid_: crest (alone), emblem, medallion, Prestige crest

**Binding**:
The look the Angler's books wear, chosen once in the Curio Shop: the Fish Journal, the Hunts board and the Stats book all wear the same one. Some are bought and some are earned, and Field Leather is the default. The Field guide keeps its own plain leather. Not to be confused with a key binding, such as the Fishing key's.
_Avoid_: cover, notebook cover, Journal binding, leather (for the look)

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

**Standing Hunt**:
A Hunt that is always there and comes round with its conditions (night, a season, a weekly game event, an aura), never expiring. Standing Hunts are grouped in Hunt sets.
_Avoid_: permanent hunt, normal hunt

**Hunt Event**:
A group of Hunts themed on one or two zones, defined without dates and kept in a pool: the addon ships one, and the backend can push new ones. It counts only during a run. Completed runs add up towards titles. Players see Hunt Events as a whole under the name **Pagle Wagers**.
_Avoid_: event (which is a game calendar event, such as the Fishing Extravaganza), season, challenge, limited hunt, Pagle Wager (as a domain term: it's only the players' name)

**Run**:
One time a Hunt Event is on, from a start to an end, about three days. The backend's schedule decides runs, or the addon's own rotation when the companion isn't connected. Any number of runs may be on at once. Each run starts fresh and pays again, and progress in a run that ends unfinished is simply lost.
_Avoid_: occurrence, instance, edition

### Tackle Board

**Notice**:
One goal on the Tackle Board, such as "4 different Species in Feralas". It never expires, never needs a time window, counts only Catches made after it appeared, and can be rerolled once. Three arrive each day, up to a cap.
_Avoid_: daily, quest, challenge, task

**Expedition**:
The Tackle Board's larger weekly Notice. It never expires and banks like any Notice.
_Avoid_: weekly, weekly quest

**Campfire**:
The Angler's run of consecutive days with at least one Notice or Expedition completed. A missed day burns Kindling instead of putting it out; the longest Campfire is kept for good.
_Avoid_: streak, flame, login streak

**Kindling**:
What keeps the Campfire burning through a missed day. Every new fire starts with some, more is earned by keeping it lit, and it is spent automatically, never bought or chosen.
_Avoid_: freeze, streak saver

**Fly Box**:
The Tackle Board's finite collection of fly patterns, one tied for each Notice or Expedition completed.
_Avoid_: collection (which is the Ledger's), tackle box (a reported Forever feature)

### Stats

**Your odds**:
The per-Cast chance of an item in a place, estimated only from the Angler's own Casts and always shown with how many Casts it rests on. It is never presented as game data.
_Avoid_: drop rate, loot chance (which are the game's own numbers), catch rate

**Dry spell**:
The Casts an Angler has made, in the scope where an item can be caught, since they last caught it. It is shown with how unusual that wait is, never as a promise that the item is due.
_Avoid_: pity, overdue, bad-luck streak

### The website

**Companion**:
The desktop app, outside the game, that uploads the Angler's Catch log to the Pagle website and writes the website's data into data addons Pagle reads. Pagle works fully without it; what it brings in shows nothing once it is a day old.
_Avoid_: companion app, client, uploader, sync tool

**Published Angler**:
An Angler shown on the Pagle website and, through other players' Companions, in their games: on player tooltips and, when followed, in the Fish Journal. Only its visible characters are ever matched, and only the website's values are shown, never the in-game ones.
_Avoid_: public profile, registered player, member

**Paste string**:
The text an Angler copies out of Pagle's export window and pastes on the Pagle website, to put the Catch log there without the Companion. A long log takes several, pasted one after another; making them is exporting.
_Avoid_: export string, backup string, share code, upload code

**Followed Angler**:
A Published Angler the player follows on the Pagle website, who gets a full card in the Fish Journal's Following spread and a "Following" mark on their tooltip.
_Avoid_: friend, contact, watched Angler
