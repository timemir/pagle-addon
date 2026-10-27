# Prompting ElevenLabs sound effects for the generated sets

The model is `eleven_text_to_sound_v2`. What worked and what didn't, from the first batch of sets:

- **One sound per generation.** A prompt that stacks several sounds ("a kazoo fanfare with a slide whistle swoop and a party horn blast") comes out as mush. Generate each sound alone (a *part*) and lay them on a timeline in the set's `set.toml` (`mix = [...]`, built by `scripts/pagle_data/generated_sounds.py`).
- **Name the sound and its texture.** "Wet fish slapping against a wooden dock, single hit, one-shot" beats "a funny slap, cartoon". Pitch, material, space and mic distance ("close-mic", "outdoors", "distant") help.
- **Leave mood out.** "Triumphant", "comedic", "epic" and "magical" don't translate to audio; the sound's own description does.
- **Terms that help:** `one-shot`, `impact`, `whoosh`, `braam`, `drone`, `glitch`. For order, say it in order ("then").
- **Short.** A part runs 0.5 to 2.5 s; a duration costs 40 credits per second.
- **Pitch and length are set in the mix.** `semitones` shifts a part (a run of the same droplet becomes a rising scale), `length` cuts it with a short fade, `gain` balances it.
- **Two takes of each part**, `take_a` and `take_b`; `pick` in `set.toml` says which ships.
