# Trailer revision 10

A re-cut for pace, 94 → 70 seconds. Revision 9 had stretched the 40-second v5 script over 94 seconds: one line per
block of picture, static holds between (31% of its frames were still), the addon first seen at 25 s, and music
25 dB under the voice. Revision 10 keeps every story beat and the Darkmoon Faire music, and cuts to the music.

- **Opening in coverage, 25 s → 20 s.** Seven EEVEE shots on the existing animation replace the 26 mm oner: the
  float and its bite, the green fish into the barrel, a low wide as Nat walks in, the skeleton from the water side,
  Nat's line running on as the skeleton goes into the barrel, the hand-off cut on the rookie's reach, and the whole
  sit-down from standing to the Ledger opening.
- **Cut to the music.** 120 BPM, a bar every 2 s. The music stops on the downbeat as the skeleton comes up, returns
  quietly under the hand-off, and the full band drops as the Ledger opens. Two 4-bar edits (bars 19→23, 29→31)
  place the climax under the closing montage and the outro under the Session summary.
- **The real addon.** Every interface shot is from the in-game `/pagle trailer` capture of 22 October. Windows are
  framed whole with a slow drift, pushing in only where something happens there. The level-up banner and the
  Legend splash come from revision 9. The record toast now arrives after the fish is in hand.
- **Newer features.** Varieties, Pagle Wagers, the expanded Curio Shop (bill of sale, seal, the new toast style in
  use) and Anglers on tooltips (a mock of the real `AnglersInGame` block, its lines and colours from the addon).
- **A climax montage** of the rest of the book on the beat, the Session summary for "something to remember when the
  day's fishing is done", and an 8-second end card.
- **The Ledger stays brown.** Revision 7 keyed the hero book's `binding_blue` to 1 at Scene frame 1681, so the
  closing showed a blue book; the closing and the cover's dissolve into the P are re-rendered in brown.
- **Mix.** −14 LUFS, −2 dBTP (revision 9: −18.9 LUFS, 17.5 LU range). Music sits about 8 dB under Nat between lines
  and is ducked a further 8 dB under his voice. Five stems sum to the master.

New narration — "No two quite alike.", "And a fresh wager every few days." and "And see who else has been writing
things down." — is Eleven v4 with the approved Nat voice (`ydYLQ0Ug0aDVS7Rdoh7F`), generated through the ElevenLabs
API. Each take was checked with Scribe v2 against its script and picked for pitch and pace closest to the revision 9
lines. The other lines are revision 9's.

Build sources: `.scratch/pagle-trailer-v10/` (`edl.py` is the edit; `build-v10.py` renders picture, stems and mix;
`shots.py` renders the 3D shots; `vse-v10.py` assembles the Blender master; `generate-vo.py` and `pick-vo.py` make
and choose the narration). The ElevenLabs key is in `.scratch/pagle-trailer-v10/.env.local`, outside git.

Project: `C:\Users\Tim\wow.export\pagle-promo\revision-10\pagle-trailer-v10.blend`

Preview: `C:\Users\Tim\wow.export\pagle-promo\previews\blender-trailer-revision-10.mp4`
