# Recording the in-game showcase

The script is approved in `in-game-showcase-script.md`. The narration text to
paste into ElevenLabs is `in-game-showcase-voiceover.txt`.

## Before recording

1. Enable Pagle, Ledger, Stats, Hunts, Tackle Board and QoL, then `/reload`.
2. Choose the fishing spot and frame the game camera. Stay out of combat.
3. In Pagle's Fishing settings, configure the Fishing key, fishing gear and
   chosen lure. Have that gear and the lure available. The key performs one
   action per press: preparing gear, applying a lure, casting, then reeling.
4. Close other addon windows and allow any announcements to finish.
5. Run `/pagle trailer`. Wait for the chat line saying the trailer is armed,
   then start recording.

## The take

Press the Fishing key to demonstrate preparation and catch a fish. If the first
catch has no Pagle length, keep fishing; the command waits for an eligible fish.
The record moment uses that fish in a disposable demo account, while the real
catch remains recorded normally in your actual Catch log.

After the record toast, leave the addon to perform its sequence. It navigates the
Fish Journal, a fish's varieties and the Angler page with where its XP came from,
then Stats, watches an item, pins a Hunt, opens a Pagle Wagers run and the Wagers
spread, replaces a Notice, opens the Fly Box and Campfire, previews and buys a
Curio Shop look, shows an earned zone crest and one still in progress, switches
to Cozy mode, shows a Session summary, and opens a Field report. The final
wordmark and tagline hold before the demo ends at about 4:19 after the record
moment.

The command runs addon UI interactions. Further fishing during playback stops
the tour. Combat also stops it. You can stop at any point with:

```text
/pagle trailer stop
```

Check whether it is idle, preparing, armed or running with:

```text
/pagle trailer status
```

## What happens to your data

The original SavedVariables globals, real Catch log and real projections remain
in place. The showcase renders separate, generated progress and temporary
settings views. Demo purchases write only to the disposable history.

Completion, cancellation, a new cast, combat and logout restore the original
views and settings. Reloading or restarting loads the original saved account.
The genuine manual catch is subject to WoW's usual save timing. Its record
status in your real account follows your real history; the staged previous
record exists only in the demonstration.

The fixture uses Pagle's catch codec and Module progression rules. It has
populated waters, collections, Stars, over 100 Campfire days, fly patterns and
enough earned Pagle Coins for the purchase. Standing Hunts use the existing
sample definitions so their release dates do not leave the board empty before
launch.

## Voiceover and editing

The current narration is the developer's twelve separately generated MP3s in
`C:\Users\Tim\Downloads\pagle_ingame_trailer`. Use these instead of the earlier
whole-script takes below. The filenames swap the shop and Cozy chapter numbers:
play `09-curio-shop.mp3` at 2:39, then `08-cozy.mp3` at 3:01. All other files
follow the scene order, from `00-opening.mp3` to `11-closing.mp3`.

The existing ElevenLabs voice is **Nat — Pagle trailer**
(`ydYLQ0Ug0aDVS7Rdoh7F`). The completed performances used
`eleven_multilingual_v2`. Two takes are downloaded to:

- `.scratch/pagle-in-game-showcase/audio/nat-take-01.mp3` — 148.38 seconds.
- `.scratch/pagle-in-game-showcase/audio/nat-take-02.mp3` — 136.53 seconds.

Two additional variants were rejected by the provider's account restriction;
neither is needed for the edit. No further generations were requested.

The narration is not played by the addon. Use the scene table's times as edit
cues and place each narration paragraph over its corresponding scene, retaining
room for the game's sounds and page turns. The raw voice performances are
shorter than the uninterrupted take and need spacing between their paragraphs.
Keep the opening fishing paragraph separate so it can fit your manual actions.

## Verification status

The automated rehearsal exercises every scene on the real addon files and checks
that the real catch survives, demo Coins and purchases stay separate, and
completion, cancellation, stale timers, combat and logout restore the account.
The developer confirmed in the actual client that the manual catch starts the
automated tour. A complete recording is still needed to judge composition, pacing, text
readability and visual transitions. After your rehearsal and `/reload`, the
agent can read the saved results using the repo's WTF reader.
