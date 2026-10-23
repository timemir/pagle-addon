# Pagle: every catch, written down

Approved script for the continuous in-game product showcase.

## Creative direction

Audience: someone who enjoys fishing in World of Warcraft: Forever and has not
heard of Pagle. Promise: turn ordinary fishing into a collection, progression,
and your next adventure.

Pagle speaks like an experienced fisherman showing a friend something worth
keeping: warm, conversational, a little dry. Let the addon sound effects and
page turns breathe between lines. The existing ElevenLabs voice
**Nat - Pagle trailer** is the intended narrator; no new voice needs designing.

Record one uninterrupted in-game take; the addon does not play narration. The
narration below is the approved script for the 22 October 2026 recording, timed
to that take: it runs 4:22, cut from 0:03 to 4:25 of the capture. Times in the
table are in the finished video; the tour's own cues (`TRAILER_CUES` in
`addons/Pagle/logic/Trailer.lua`, seconds from the record announcement) land at
cue + 14.5 s. A new recording needs its lines retimed.

## Recording story

Invoke `/pagle trailer` before fishing. It preserves the account's Pagle data,
prepares a demo Catch log and derived display state, and arms the opening.
The next eligible manual catch supplies the record moment. After the record
announcement, the addon navigates the story automatically.

The initial catch is the only required gameplay event. Later pages reveal
established fishing history, present existing rewards, and perform visible
addon interactions. Pinning a Hunt and replacing a Notice do not complete them.

The narration describes the viewer's growing fishing life. It does not suggest
that all the account's seeded accomplishments came from the opening catch.

## Narration and choreography

The tour's chapter captions appear at the top of the screen; Nat's lines are
burned in as dialogue subtitles at the bottom.

| Video time | Screen action | Pagle's narration | Chapter caption |
| --- | --- | --- | --- |
| 0:00–0:15 | Manual opening: QoL's next-action indicator while the recorder presses the Fishing key to prepare, cast and reel. | "Bind one Fishing key, and every press does the next sensible thing: your pole, a lure, the cast, the reel. One press, one action. Pagle never fishes for you. Now... let's see what's biting." | None |
| 0:15–0:25 | The length record announcement completes against the fishing scene. | "Well now. That one's worth writing down. Pagle keeps your longest of every fish, so even an ordinary catch can be a personal best." | Every catch tells a story |
| 0:25–0:55 | Fish Journal: home, the current water and its mastery rank, the opening fish's page, its waters, then a search and its result. | "And that's just the first page. Your Fish Journal remembers every water you've fished. Each zone climbs from Visitor to Master by the different fish you've caught there, not the sheer number. Every fish gets its own page: where it bites, your longest, and up to three stars." (0:43) "Follow it back to its waters... or just search for an old favourite." | A collection worth keeping |
| 0:55–1:05 | The fish's varieties, then one selected. | "No two quite alike, either. Each fish comes in ten colours, up to a single epic. Land all ten, and its crest is yours." | No two quite alike |
| 1:05–1:23 | The Angler page: Angler Level and where its XP came from, then a title selected. | "Every catch grows your Angler Level, with one Ledger for all your characters." (1:11) "Discoveries, records, Hunts and goals all add to it, and you can see exactly where it came from." (1:18) "And you've earned a name for yourself, too." | Grow with every catch / Every pursuit adds up |
| 1:23–1:41 | The Trophy Room's real weights, the Curios, then an earned Legend's plate. | "Some catches deserve their own shelf. The Trophy Room keeps the real weights of your biggest fish." (1:29) "The Junk Museum takes everything else you drag up." (1:33) "And Legends: the ones you'll still be talking about long after the bait's gone." | Keep the memorable ones |
| 1:41–2:07 | Stats in the current water; an item's odds and Dry spell, watched, closed and reopened from the tracker; This Session and Lifetime. | "Wondering how the fishing's been? Stats knows every water you've fished, and what bites there." (1:46) "Your odds come only from your own casts, and always say how many they rest on." (1:52) "Watch a fish, and its dry spell follows you on the tracker." (1:58) "Look back over a Session, or a lifetime. Mind you... the next cast still doesn't owe you anything." | Know your waters |
| 2:07–2:35 | Hunts: what's on now, a later window, back to now, pinned, closed and reopened from the tracker, then a Hunt set's title. | "Fancy a change of scenery? Hunts are the catches worth planning for: a fish that only bites at night, in one season, or during an event." (2:17) "The board shows what's biting now, what opens soon, and what comes later." (2:22) "Pin one, and it follows you around, with a quiet nod when its window opens." (2:30) "Finish a whole set for its title." | Find your next adventure |
| 2:35–2:48 | A Pagle Wagers run, then the Wagers spread. | "And every few days, Pagle Wagers put a fresh run of Hunts on the table, around a zone or two." (2:42) "Finish them before the run closes; every run you complete counts toward a title." | Race the week's events |
| 2:48–3:17 | The Tackle Board: Notices and the Expedition, one Notice replaced, the Fly Box, the Campfire. | "Or take a smaller adventure from the Tackle Board: three Notices a day, and a longer Expedition each week." (2:55) "They never expire, so a missed day banks instead of vanishing. And if one doesn't suit you, swap it once." (3:02) "Every goal you finish earns Coins, and ties a new fly for your Fly Box." (3:09) "And it keeps your Campfire burning, with a little Kindling for the days life gets in the way." | A reason for another cast |
| 3:17–3:39 | The Curio Shop: a look previewed, the bill of sale, the purchase, the look in use. | "Those Pagle Coins? You earn them for things you've done, never for sheer grinding, and they only ever buy looks." (3:24) "Toast styles, sound sets, a new binding for your books." (3:28) "Try it on, sign the bill... and it's yours for good." (3:35) "Make Pagle your own." | Make it yours |
| 3:39–3:49 | Earned and still-to-earn bookplate crests. | "Master a zone, and its crest is yours to wear on the Journal's bookplate. Fifty-three of them, if you're the patient sort." | Master your waters |
| 3:49–4:06 | Cozy mode on, a quiet view of the water, then the Session summary. | "And when you'd rather just listen to the water, settle into Cozy mode. Nothing pops up, nothing plays." (3:58) "Everything you earned waits in the Session summary, ready when the fishing's done." | Enjoy the quiet |
| 4:06–4:15 | A Field report with its text ready to copy. | "Caught something Pagle doesn't know yet? Share a Field report, and help chart the waters for the next angler." | Share what you discover |
| 4:15–4:22 | The fishing scene, the wordmark and the tagline. | "A collection to keep, and a reason for one more cast." (4:18) "Pagle. Every catch, written down." | Pagle / Pagle: Every catch, written down. |

## Feature coverage and demonstration requirements

| Feature | Visible proof in the take |
| --- | --- |
| QoL | Manual Fishing key presses and the changing next-action indicator. A key press performs one game action. |
| Simulated Size and personal records | Opening length announcement and the same fish's updated Journal record. Label the length as simulated by Pagle. |
| Fish Journal | Navigate water to fish, follow a link, return, search and select a result. |
| Zone and Species Mastery | Zone seal/rank and Species stars in a populated spread. |
| Angler progression | Level, XP, Fresh Water, completion and an actual title selection. Prestige remains a visible long-term milestone where supported. |
| Collections | Trophy Room real weights, Curios, and an earned Legend's illustrated plate. |
| Stats | This Session and Lifetime; item detail; empirical Your odds and Dry spell; watch and reopen from tracker. |
| Hunts | Now/future window, conditions, pin, tracker navigation, set progress and title. |
| Tackle Board | Notices and Expedition, real replacement action, completed history, Fly Box, Campfire, Kindling and tracker. |
| Pagle Coins and Curio Shop | Adequate earned balance, preview, bill, purchase animation and equipped result. |
| Player control over interruptions | Cozy mode setting and a populated Session summary. |
| Field reports | Existing observations, report view and text selected for copying. |
| Account-wide identity | All the above is one Angler's coherent history; the fixture can include catches by multiple characters. |

## Production boundaries

- Keep the original addon data in place while rendering disposable views, and
  restore the original views after completion or cancellation. A separate
  character does not isolate account-wide SavedVariables. Retain the real
  opening catch in the original log while keeping staged history, purchases
  and progression out of the restored account. Its record status in the real
  account follows the real account's history.
- Keep the demo fixture coherent across the Catch log, progression, earned
  Coins, purchases, goals, historical catches and the visible current Session.
  Preserve the opening fish's identity through the Journal handoff.
- Standing Hunts and Pagle Wagers (Hunt Events) both ship and appear in the
  tour. The demo must also account for shipped Hunts whose availability starts
  later than the recording date.
- Stats must display observed numbers with enough sample history; they are not
  the game's exact catch probabilities or a prediction of the next cast.
- Pagle's simulated lengths and real trophy weights are separate. Fly patterns
  are addon collectibles, Curio Shop goods change appearances, and earned titles
  are displayed within Pagle.
- All gear, lure, cast and reel actions in the manual prelude need the recorder's
  inputs. The automated part operates addon interfaces.
- Use existing history for Legends, fly patterns, completed goals and Field
  report observations. No new in-world fishing events are implied by opening
  a page, watching an item, replacing a Notice or purchasing a look.
- Voice clips and final subtitle timings are produced after script agreement.
  Final addon timing follows the actual recording. Keep narration, game audio
  and captions available as separate editing assets.

## Agreed opening and voice

The manual opening demonstrates preparing gear, applying a lure, casting and
reeling with the Fishing key, with a separate press for each action. The
automated showcase begins after the record announcement.

The narrator is the existing ElevenLabs voice **Nat - Pagle trailer**, with the
warm, conversational delivery and dry humour used in this script, read with
Eleven v4 as in the trailer.

The complete script and scene sequence are approved. Recording instructions,
the generated voice takes, and verification status are in
`in-game-showcase-recording.md`.

