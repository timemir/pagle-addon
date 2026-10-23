# Recording the in-game showcase

The script is approved in `in-game-showcase-script.md`. The narration as one
read is `in-game-showcase-voiceover.txt`.

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
Curio Shop look, pins an earned zone crest on the Angler page's bookplate, switches
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

The narrated cut of the 22 October recording
(`C:\Users\Tim\Videos\2026-10-22 22-55-03.mp4`, 0:03 to 4:25) is
`C:\Users\Tim\wow.export\pagle-promo\in-game-showcase\pagle-in-game-showcase.mp4`:
4:22, 1920 × 1080 at 60 fps, with Nat's lines burned in as Friz Quadrata
subtitles (also as `pagle-in-game-showcase.srt`). The folder holds the three
stems (game, voice, music), the mix and every take.

Nat is the ElevenLabs voice **Nat — Pagle trailer** (`ydYLQ0Ug0aDVS7Rdoh7F`),
read with Eleven v4 as in trailer revision 10: the approved script's 35 lines,
three takes each. Every chosen take was transcribed back to its script with
Scribe v2 and picked for the pitch and pace closest to the trailer's lines. The
first word of each line lands on its time in the script's table; subtitles
follow the takes' word timestamps.

Under the voice: the recording's own sound (lake, fishing, page turns and
stamps), lifted to sit about 18 dB under Nat, and the Darkmoon Faire music
looped on its bars, about 8 dB under Nat between lines and ducked a further
8 dB while he speaks, ending on the song's own outro. Master: −14 LUFS,
−2 dBTP.

Build sources are in `.scratch/pagle-showcase/`: `script.py` (lines and times),
`generate-vo.py` (takes and picking), `build.py` (stems, mix, subtitles and
picture) and `update-docs.py` (this doc's narration table). The ElevenLabs key
is the CLI's `.scratch/pagle-trailer-v10/.env.local`, outside git. A new
recording needs the lines retimed in `script.py`; the takes can be reused.

The earlier narration (the twelve MP3s in
`C:\Users\Tim\Downloads\pagle_ingame_trailer` and the
`eleven_multilingual_v2` whole-script takes) is superseded.

## Verification status

The automated rehearsal exercises every scene on the real addon files and checks
that the real catch survives, demo Coins and purchases stay separate, and
completion, cancellation, stale timers, combat and logout restore the account.
The developer confirmed in the actual client that the manual catch starts the
automated tour. A complete recording is still needed to judge composition, pacing, text
readability and visual transitions. After your rehearsal and `/reload`, the
agent can read the saved results using the repo's WTF reader.
