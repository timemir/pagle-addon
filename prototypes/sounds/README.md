# PROTOTYPE: Pagle's sounds (throwaway)

For the wow-fish issue "Prototype Pagle's sounds". **Question:** what do Pagle's Announcements sound like when you hear them in the real game mix, over the bobber splash, across a real fishing session?

`PagleSoundBoard` is a throwaway addon that compares three candidate sets:

| Set | Where it comes from | Licence |
|---|---|---|
| **Game sounds (Classic)** | The client's own vanilla-era files, played by FileDataID. Nothing is shipped. | Blizzard's, referenced only |
| **CC0 pack (Kenney)** | Cut from Kenney's *Interface Sounds*, *RPG Audio* and *Music Jingles* packs and loudness-matched | CC0 |
| **Self-made** | Rendered from scratch by `render.py` (wood and bell synthesis plus a small room) | Ours (GPL-3.0-or-later) |

Each set offers a few candidates for each of the four sounds: **Toast**, **Banner**, **Legend** and the QoL **Recast cue**. Nods stay silent, and ordinary catches never make a sound. Every shipped file is matched to the same loudness (−20 dBFS RMS), so you compare the sounds themselves, not their volume.

## 1. Install

1. Copy the `PagleSoundBoard` folder into the beta's `Interface\AddOns\`, the same place as the earlier probes.
2. **Fully restart the client.** A `/reload` doesn't pick up new sound files.
3. At character select, enable **Pagle Sound Board (throwaway)**. If it's marked out of date, tick *Load out of date AddOns*.

## 2. Run it (about 45 minutes)

1. `/psb` opens the board. Click **Check all files** first: it reports any game file ID missing on Forever. You may hear short blips.
2. **Audition.** Click each sound. `<` and `>` switch to another candidate. Play **Ref: bobber splash?** and **Ref: char level-up** next to them to judge masking and loudness. Pick your favourite candidate in each cell.
3. **Channel.** Try **SFX** (default) and **Master** with your normal volume settings. Does Pagle belong on SFX, so it follows the SFX slider, or on Master, so it still plays with SFX muted?
4. **Fish with it.** Go to the water. Set **Sounds:** to one set, density **Day one (1 in 6)**, and **Recast cue: on**, then fish for about 10 minutes. Do the same with the other two sets. If you have time, run your favourite set again at **Mid-game (1 in 23)**.
5. **Note as you go:** type `/psb note <what you felt>` whenever a sound pleases or grates, and especially when one gets tiring, is too loud, gets lost in the mix, or sounds like a game event that didn't happen.
6. When you're done, click **Report**, then **Select all**, copy, and paste it on the issue.

## 3. What to answer on the issue

- Which set, or which mix of sets? For example, game sounds for toasts but self-made for Legends.
- Does any candidate get annoying within 10 minutes? Does the self-made toast rotation help?
- Is anything confusable with a real game event (bobber, level-up, quest, whisper)?
- SFX or Master?
- **Legend:** one shared sting, or a sting plus each Legend's own motif? And should a Legend's splash make a sound in Cozy mode?
- Recast cue: is it distinct from the celebratory sounds, and is it quiet enough?

## Rebuilding the shipped sets

```
pip install numpy soundfile
python render.py <folder with the unzipped Kenney packs> PagleSoundBoard/sounds
```

The Kenney packs are at kenney.nl/assets: `interface-sounds`, `rpg-audio` and `music-jingles`.
