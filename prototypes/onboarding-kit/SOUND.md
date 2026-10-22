# Guide kit: sound

The guide kit plays only the client's own sound kits, through `Sound.lua` (the same file in every kit: `P.Sound(event)` → `PlaySound(SOUNDKIT[name] or id, "SFX")`). The four new events were checked against `SoundKitConstants.lua` in the client's UI source (Gethe/wow-ui-source); whether each *sounds* right is for you to judge in game with `/pagleguide sounds`, which plays them a second apart and names each in chat. Swap any by changing one line in `P.SOUNDS`.

| Event | Sound kit | Id | When |
|---|---|---|---|
| `letter` | TUTORIAL_POPUP | 7355 | The letter arrives |
| `noteIn` | IG_CHAT_SCROLL_DOWN | 827 | A margin note, or a first-look set, appears (once per set, not per note) |
| `tick` | IG_MAINMENU_OPTION_CHECKBOX_ON | 856 | A First evening item is done |
| `listDone` | IG_QUEST_LIST_COMPLETE | 878 | The list's last item is done |
| `bookOpen`, `bookClose` | IG_SPELLBOOK_OPEN, IG_SPELLBOOK_CLOSE | 829, 830 | The guide opens and closes (the books') |
| `pageTurn` | IG_ABILITY_PAGE_TURN | 836 | Next, back, a ribbon |
| `click` | IG_MAINMENU_OPTION | 852 | A button, a skip link, a binding field |
| `check` | IG_MAINMENU_OPTION_CHECKBOX_ON | 856 | A choice card is picked |
| `pin` | PUT_DOWN_SMALL_CHAIN | 1212 | Start my board (the board's own) |

Rules the kit keeps: a sound marks something the player did or should notice; notes after the first in a set are silent; nothing plays in Cozy mode except what the player clicks; SFX channel only.

Note: in the probe each note calls `noteIn`; the addon plays it once per set (ONB-R55).
