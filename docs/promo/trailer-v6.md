# Pagle trailer v6

78-second revision, 19 October 2026. Review export:
`C:/Users/Tim/wow.export/pagle-promo/previews/blender-trailer-revision-06.mp4`.
Project and media: `C:/Users/Tim/wow.export/pagle-promo/revision-06/`.
The original v4 and v5 projects are
preserved. The master remains a review cut, with new editable 3D animation,
animated UI recreations, subtitles, and a separate sound design mix.

| Time | Picture |
|---|---|
| 0–6 | Nat starts at the pier entrance and walks toward the rookie during the first green fish catch |
| 6–13 | Nat continues approaching; the second Catch is a skeleton, held for the reaction |
| 13–16 | Nat says “That one's worth writing down”; the rookie turns to him and lowers the skeleton |
| 16–20 | The book handoff, given more time |
| 20–25 | The rookie sits and opens the book |
| 25–36 | Fish Journal: native page turn, discovery reveal, Trophy Room page turn and personal-record stamp |
| 36–41 | Angler Level banner, including its seal and tooling animation |
| 41–47 | Hunts timeline and an animated turn to a Hunt set |
| 47–52 | A Notice completes on the Tackle Board |
| 52–56 | Legend splash with turning rays |
| 56–65 | Over the rookie's shoulder: read, close the book, reveal the front |
| 65–68 | Move closer to the closed cover |
| 68–70 | The book fades away, leaving the same P geometry aligned on screen |
| 70–78 | P develops into PAGLE; OUT NOW; CurseForge / Wago / GitHub; pagle.app |

The opening camera moves continuously through the catches, turn and handoff.
Nat's walk uses the supplied `pagle-walking.glb` Walk clip. His supported book
carry continues into the existing talking and handoff animation. The second
Catch uses a pale geometric skeleton so the joke remains legible in motion.
The ending keeps the reader's hands at the book edges to protect the title.

The UI runs the actual motion functions from the supplied v2 Lua art kits in
their offline simulator. Anchoring, clipping, easing, page turns and effect
timings come from those kits. Game icon artwork replaces the simulator's
generic icons. These are faithful recreations with sample data, rather than
client captures. Short dissolves connect the different surfaces.

The selected original lighter Nat voice reuses the existing Eleven v4
performance, with sentences placed on the new picture cues. The final download
message is shown on screen. New ElevenLabs SFX and a spoken closing line were
attempted, but every new generation returned HTTP 429. Prepared generation
nodes remain in ElevenLabs flow `1nE4kqP69qXN0DwF1I4r`.

The sound pass has separate ambience, foley, UI, narration and music stems.
Pier footsteps approach in level and stereo position; the two catches have
distinct impacts; the skeleton gets dry bone clicks. Leather handling,
parchment, quill writing, record/DONE stamps, the addon's real level and Legend
sounds, and the final book close land on their picture cues. The music ducks
under narration and the book close. The new foley is locally authored, with
existing fishing/addon recordings; no successful ElevenLabs SFX generation is
claimed. The music remains the existing temporary review track.

The review export is 1920 × 1080 / 30 fps. The editable master has a 4K output
setting at 50%; its cinematic and UI movie strips are 720p review proxies.
Final 4K source renders, cinematic lighting and in-client verification remain
production finishing work.
