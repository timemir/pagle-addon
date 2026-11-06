# Pagle

## 1.2.0 (2026-11-06)

Set your own fishing sound, and keep the next-action button out of the way.

### Added

- The Fishing audio mix can be set up your way. Under its switch on the Fishing page, each channel (Master volume, Effects, Music, Ambience, Dialog) has a box and a volume slider, as in the game's own Sound settings: untick a channel to leave it as you have it, or pick how loud it plays while you fish. Master volume goes no lower than 10%, so you still hear the splash. Out of the box the mix is the same as before, so nothing changes until you change it. (#576)
- The audio mix can play the game's sound on another output device while you fish, such as your headset, and switch back afterwards. The sound drops out for a moment as it switches. A device that isn't plugged in is skipped, and the row shows it as "(not found)". (#576)
- A new option under Show the next-action button, "Hide until a fishing pole is in hand": with it on, the button stays hidden while you're out of your fishing gear and shows once a pole is in hand or you're fishing. The Fishing key still puts your fishing set on. It's off unless you turn it on. (#575)

### Changed

- "Keep sound when the game is in the background" is now called "Keep sound in the background", so it fits its row. It works as before. (#576)

### TRANSLATORS

- Español: fmartingr

## 1.1.2 (2026-11-06)

Long names scroll, and the last cut labels fit.

### Added

- A fish's name too long for its toast scrolls slowly to its end and back, so you can read all of it, where it used to be cut short with "…". With Animations off it's cut short as before. (#573)
- Pagle's entry in the game's Addon Compartment shows Pagle's icon. (#572)
- For contributors: `scripts/measure-layout.sh` runs `/pagle dev tour` with every text measured in its real font, and reports text that's cut, off its page or overlapping, before an in-game test. (#577)

### Fixed

- Settings labels that the game's Settings panel cut short now fit: "Announce open Hunt windows" in English, and shorter wording for a few labels in German, Spanish and Russian. Their tooltips keep the full sentence. (#578)
- The Hunts tracker's "New wagers with the Pagle companion" line is no longer cut short, in any language. It's set a little smaller, or goes on to a second line. (#578)
- A book ribbon whose name took three lines (Spanish "Las veinticuatro horas") is set smaller so it fits on two. (#578)
- A done item on the First evening list is struck through on every line it wraps to, not only the first. (#578)
- On the Wagers ladder, two posts too close for both titles show one of them, never two printed over each other. (#578)
- A first-look ring on tightly stacked rows stays on its own row's words. (#578)
- German "UNGESCHRIEBEN" stays whole on the Legend crest. (#578)

### TRANSLATORS

- Español: fmartingr

## 1.1.1 (2026-11-06)

Pagle speaks German, and its pages fit longer languages.

### Added

- Pagle in German (Deutsch). Choose it under Language in Pagle's settings; a `/reload` applies it. "Game default" follows your game client, so a German client starts in German. The translation was drafted by machine and is waiting for a native speaker's review. Spotted something that reads wrong? Tell us on GitHub; corrections are welcome. (#565)

### Fixed

- In Spanish, Russian and German, text in the Field guide, the first-look notes, the settings, the Field report and Export windows, the Curio Shop, the Tackle Board, the Fish Journal, the Stats book and the Hunts board no longer runs into the next line, past its frame or under a button. A long line is set a little smaller, then wrapped or ended with "…". (#563, #564, #566, #570, #571)
- The Hunts tracker keeps a line's count readable at the right when the line is too long, and a run's line goes on to a second line instead of being cut. The Wagers pay box, ladder and timeline make room for their numbers, and the now-line on the timeline passes under the headings instead of through them. (#566, #570)
- The ornaments of the Hunts, Stats and Tackle Board tracker frames (the compass, orb, coin, astrolabe and embers) no longer sit on the tracker's words. (#568, #570)
- Book covers whose leather has a pattern, such as Pathfinder's Calf and Winner's Brocade, no longer run it through the words along the top of the book. (#568)
- An accent on a capital at the top of a book page, such as the Ä of "GEWÄSSER", is no longer cut off. (#571)
- First-look notes no longer cover one another, the window's close and help buttons, the coach bar or a pinned Expedition, and their rings sit beside the words they point at, not on them. The coach bar sits below a book's ribbons. (#564, #568, #571)
- The Fish Journal's pages show their scrollbar when a page is longer than the book. (#563)
- Pagle's menu opens from the minimap icon when EllesmereUI or another add-on gathers the icon into a panel of its own. Before, the menu closed before you could click an entry. (#569)
- On a Russian, Korean or Chinese game client, Pagle in English, Spanish or German no longer draws boxes where the client's fonts lack a character, and German quotation marks read as quotation marks on a Chinese client. A client font that is missing falls back to another of that client's fonts instead of one without its script. (#562, #568)

### TRANSLATORS

- Español: fmartingr

## 1.1.0 (2026-11-05)

Pagle speaks Spanish and Russian.

### Added

- Pagle in Spanish (Español) and Russian (Русский). Choose the language under Language in Pagle's settings, next to Clock; a `/reload` applies it, on every character. "Game default" follows your game client, so a Spanish or Russian client starts in its own language. Russian is offered on a Russian client, whose fonts draw it. Names the game itself supplies (fish, items, zones, events, spells) stay in your game's language. (#512)
- Parts of both translations were drafted by machine and are waiting for a native speaker's review. Spotted something that reads wrong? Tell us on GitHub; corrections are welcome. The Translations line in Pagle's settings credits each language's translators. (#526, #528)
- "Copy for the website" in Pagle's menu by the minimap, above Help chart the waters: the Paste string from `/pagle export`, one click away. (#549)
- For Module and addon authors: Pagle's API is at version 2. `Pagle.Text` fills named `{fields}`, picks plural forms and writes numbers in the chosen language; `Pagle.GetLanguage` says which language that is, and `Pagle.Upper`, `Pagle.Lower` and `Pagle.FoldCase` handle accented letters. (#513, #516)

### Changed

- Numbers Pagle writes use the chosen language's separators, such as "1.850" in Spanish and "1 850" in Russian, whatever your game client is set to. What the website and the Field report read is unchanged. (#513, #559)
- In Russian, Pagle separates with "•", which the Russian client's font draws. (#559)

### Fixed

- Rows in the Stats book and lines in the Hunts tracker keep the fish's or Hunt's name readable beside a long countdown or reading, and a Hunt's time is never cut to nothing. (#559, #561)

### TRANSLATORS

- Español: fmartingr

## 1.0.2 (2026-11-05)

### Fixed

- On Russian, Korean and Chinese clients, fish, item and zone names no longer show as empty squares: Pagle now draws its text in the game's own font there. (#553)

## 1.0.1 (2026-11-05)

### Changed

- The Field report box ("Help chart the waters" in the Pagle menu, or `/pagle report`) now says "For the website, use /pagle export." The Field report is for the GitHub issue form. The Pagle website takes the Paste string from `/pagle export` (or Settings › Catch log › "Copy for the website") instead. (#548)
- Pagle's data has been checked against Forever's live build, 1.60.1.70790. Nothing Pagle reads had changed. (#547)

## 1.0.0 (2026-11-04)

The first release. Pagle is a fishing addon for World of Warcraft: Forever, for progression and collection, with a few quality-of-life touches beside them. It watches what you catch and rewards it. It never fishes for you.

It comes as six addons in one download: Pagle itself and five Modules, the Ledger, Hunts, Stats, the Tackle Board and QoL. Turn any Module off in the AddOns list and nothing of it loads. Pagle keeps recording your Catches either way, so a Module you turn back on catches up on everything it missed, in one card.

### Pagle

- New to Pagle? A Letter arrives at your first login and opens a short Field guide. After that, notes appear beside each first moment and window, and a First evening list in the tracker shows what to try. `/pagle guide` opens the guide again.
- Every Cast you make is written into one Catch log, shared by every character on your account. Everything the Modules show is read from it.
- Open any of it from Pagle's entry in the addon compartment by the minimap, or with `/pagle`. Pagle's settings live in the game's own Settings panel, where its search finds every option.
- When you earn something, Pagle says so in the moment: a toast writes the fish's name out in ink while its stamps come down, a banner drops its seal for a new Angler Level, and a Legend gets the whole screen. A Session that earned something ends with a summary card.
- Every catch gets a toast: its size band and length over the fish's name, with a colour you've caught before named after a small gem and its rarity on the ring (the medallion keeps the fish's icon; a colour's art fills it only the first time you catch it). Past your Interruption budget (40 every 5 minutes, which you can change) it steps down to a quiet one-line Nod, and a bigger moment for the same catch shows instead. "Show every catch" turns it off.
- The Interruption budget keeps announcements from talking over your fishing, Cozy mode holds them all for the end of the Session, and the Animations setting stills the motion if you'd rather it kept still.
- Shift-drag a toast to move where toasts and Nods appear; Reset on the Announcements settings page puts them back.
- Pagle Coins are paid for progress and things achieved, never per Catch: a level-up pays 40 Coins and a Prestige 1,500. Spend them in the Curio Shop on looks: toast styles, sound sets, bindings and tracker frames. The stock never rotates, and nothing in it buys a title or a star.
- The Curio Shop prices run in six tiers, from 250 Coins to 25,000. They are paced so that an angler fishing an hour and a half a day can afford a first look within the first hour, a quarter of the stock in about 40 hours of fishing and the whole of tiers 1 to 5 in about 720.
- The Curio Shop lists each slot's looks cheapest first: the one you start with, then the ones for sale from tier 1 down to the dearest. It only sells: a look you earn stays out of it, owned or not, until it can be bought too, and is seen in the Fish Journal's Collection instead.
- The Field report: seen a fish in new waters, or outside its usual hours? `/pagle report` gathers what Pagle doesn't know yet for you to post on the issue form. It never names your characters.
- No Companion? `/pagle export`, or Copy for the website in Pagle's settings, turns your Catch log into a Paste string to paste on the Pagle website, part by part for a long log. It offers what's new since your last export, or everything.
- Lengths show in inches or centimetres, as you prefer, and times of day in 24-hour or 12-hour, following the game's own clock unless you pick one. An optional reminder tells you every 50 unsaved Casts to `/reload`, since the game saves only on a reload or logout.

### Ledger

- The Fish Journal keeps your life as an angler. Every Catch earns XP toward your Angler Level, doubled by Fresh Water after a break from fishing. At the top you can Prestige and climb again, each rank framing your portrait in a Prestige frame of its own, from the old jetty out to sea, down to the deep and up to the stars, the later ones moving.
- Each Species earns up to three stars, and each zone a Zone Mastery rank from Visitor to Master. Master a zone and its bookplate crest is yours, fifty-four in all, to wear on the Journal. The Junk Museum, Treasures and the Trophy Room fill in as you go.
- Hover a stamp on a Species' page or a trophy family's (Caught, In its element, Regular; Any weight, Half the weights, The heaviest) to read what it asks for and how far along you are.
- Fish you haven't caught stay nameless. A riddle sets the scene, and a plain hint is there when you'd rather just know.
- Legends, the named catches you won't land on an ordinary day, arrive with a splash and a title to sign the Journal with.
- Your longest of each Species is kept, from Tiddler to Monster. A size record's toast names the fish and writes its size band beside the ruler.
- A toast for a fish's new colour shows the colour in its medallion, in place of the fish's icon, with its name after a small gem. The stamp, the ring and the gem take the colour's rarity (white, green, blue, purple), and a Rare or Epic one gleams once. This holds whether the toast is the colour's own, a size record's or a New Species'. A Common, Uncommon or Rare colour that heads its catch's toast gets a full-size toast of its own: the catch's size over the fish's name and the colour, with its stamp, "New variety" or "Rare variety", at the top right.
- A fish new to a zone, a star, a trophy family's stars and an Uncharted catch show as toasts, never as Nods, so the more special catch is never smaller than a plain one.
- Search the Journal for a fish or a water. `/pagle journal` opens it.
- At level 60 a Letter from the Ledger points you at Prestige. Show me opens the Fish Journal at the Angler page; nothing prestiges from the Letter, and the Journal's confirm card stays the only way.
- The Collection is the Journal's spread of every look in Pagle and every title: a shelf each for toast styles, sound sets, bookplate crests, bindings, tracker frames and titles. What you have shows in ink and colour, what you don't in pencil, every one named, with how to earn it, how far along you are and what it costs. Choose a look and put it on from there; the Curio Shop only sells. It tells you what is new, which looks are within reach and which you added lately. Open it from Home's contents, from Look and Feel or with `/pagle collection`. You sign with a title and wear a binding on the Collection's shelves.

### Hunts

- Sixteen Hunts for the catches worth planning for: a fish that bites by night, in one season or during an event, or a catch that only counts under conditions of its own, such as a grouper by moonlight.
- The Hunts board, a leather notebook, lays them out on a timeline of what's biting now, what opens soon and what comes later.
- Each Hunt completes in bronze, some go on to silver and gold, and each of the five themed sets earns its title once finished. The first set, Home Waters, is made for new characters: four Hunts in the low-level zones.
- The board counts your Casts at each Hunt without pretending to know the odds.
- Pagle Wagers: a Hunt Event opens for about three days at a time, with Hunts in its waters. Land every Hunt's first mark before it closes to settle the wager for Coins and Angler XP, and climb the Wagers ladder to its titles. The Pagle companion, from https://pagle.app/download, brings more wagers than the addon carries itself, and a quiet hint on the board says so (Settings can turn the reminder off).
- Pin the Hunts you're after: they follow you in a tracker under the minimap, and, if you like, a quiet Nod tells you when a pinned Hunt's window opens. `/pagle hunts` opens the board.

### Stats

- The Stats book keeps your own numbers: every Session, your lifetime totals, and what bites in each water you've fished.
- Your odds for each fish come only from your own Casts, and always say how many Casts they rest on.
- A Dry spell counts the Casts since you last caught something, and says plainly when the wait is unusual. Every Cast is its own roll; nothing is owed.
- Watch up to three Dry spells on the live tracker.
- Stats shows numbers when you ask, and announces nothing. `/pagle stats` opens the book.

### Tackle Board

- Opt-in: start your board from Pagle's settings, or with `/pagle board`.
- A cork board where three Notices go up each day and an Expedition each week. Fish where you like, and they fill in as you go.
- Goals never expire, so a missed day banks rather than vanishes, and each one can be taken down, once a day, for a fresh one of another kind.
- Each day with a goal done keeps your Campfire burning. Kindling carries it through a day you couldn't make, and your longest Campfire is kept for good.
- Every goal done ties a new fly in your Fly Box.

### QoL

- A Fishing key. Bind it, and each press does the next sensible thing: put on your fishing set, apply a lure, cast, reel, or open a clam between Casts.
- A double right-click casts too. Choose the key, the click or both with `/pagle qol input key`, `click` or `both`.
- While you fish, QoL can turn the music and ambience down so you hear the splash, and switch auto-loot on. It puts your settings back when you stop.
- A small button shows what the next press will do, and a quiet line tells you when your lures run out.
- One press is one action, and QoL never acts on its own.
- If Angleur or Fishing Buddy is loaded too, QoL asks which one should keep your fishing key, and turns the other off. The rest of Pagle carries on whichever you pick.

### How it looks

Every window of Pagle's own is drawn as something an angler would keep.

- The Fish Journal, the Hunts board and the Stats book are leather-bound, with parchment pages, brass and wax seals. Their pages turn, and a catch made while one is open is written in as you watch. They wear one binding, chosen in the Curio Shop.
- The Tackle Board is cork in a leather frame, with a Campfire whose flames flicker, pins that lift under your mouse and a DONE stamp for every goal.
- The Curio Shop sells eighteen more toast styles, from a hive to an arcane sigil, and thirteen more sound sets, from a rubber duck to a dragon. Ten of the styles are earned instead: catch a hundred fish as one of eight races, or three hundred on either faction's characters, and that race's or faction's style is yours.
- The Curio Shop sorts its goods into tiers by what they do: the first tier is a clean entry look, the second richer art that stands still, and from the third up a look moves, a showpiece at the fourth. Toast styles follow it, so every moving style sits in the third tier or above, and the fifth is for the epic goods, which are earned.
- Some toast styles move: Arcane Sigil's ring of runes and orbiting mote, Sonar Scope's sweep, Tinker's Blueprint's gears, and, on a big catch, Chapel Glass's rays, Through the Ice's snowflake and Plains Totem's sun.
- Five epic toast styles, earned and never bought: the Cartographer's Folio (five zones at Master, a chart that fills in as you master more waters, gilt at all fifty-four), the Extravaganza Gala (all three Legends, with a burst of confetti on the toast of a Rare or Epic colour, and an Epic colour shown as a toast with an EPIC VARIETY stamp, not a banner, while it is on), Nightfin Tide (tier 3 in three night Wager Hunts), The Deep Trench (every Hunt of the lobster Wager at tier 3 in one run) and Nat's Study (a hundred Wager runs completed). Their art rises a little over the top of the toast.
- The Curio Shop is a travelling merchant's sample case, and each purchase is sealed in wax on its bill of sale. The Field report is a sea chart with a typed slip.
- Each window plays the game's own interface sounds, at your sound effects volume, and shrinks to fit a small screen or a large UI scale.
- With the Animations setting off, everything draws settled at once.

### Commands

- `/pagle` or `/pagle settings`: Pagle's settings
- `/pagle journal`, `/pagle hunts`, `/pagle stats`, `/pagle board`: open or close each Module's window
- `/pagle shop`: the Curio Shop
- `/pagle collection`: the Collection
- `/pagle guide`: the Field guide
- `/pagle report`: the Field report
- `/pagle export`: your Catch log as a Paste string for the Pagle website
- `/pagle qol input key`, `click` or `both`: how you cast
- `/pagle help`: list the commands

### Good to know

- Pagle runs on World of Warcraft: Forever only.
- 1.0 is in English only.
- Issues and Field reports: https://github.com/timemir/pagle-addon/issues
