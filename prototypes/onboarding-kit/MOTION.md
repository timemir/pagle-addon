# Guide kit: motion

Every move is played by `Motion.lua` (the same file in every kit): one `OnUpdate`, keyframes eased per segment with the canvas's cubic-béziers, applied through a setter. `/pagleguide motion` turns it off; each piece then appears settled, as it must with Pagle's **Animations** setting off (`Pagle.IsAnimationsOn()`). Times are from when the piece appears.

| Piece | Motion | Ease | Settled | Probe |
|---|---|---|---|---|
| The letter | Rises 30 units and fades in (0–0.5 s). Its seal drops from 1.6x and fades in (0.15–0.55 s), overshooting a little. | ease-out; seal `cubic-bezier(.3, 1.4, .6, 1)` | 0.55 s | `letter` |
| The guide opening | Fades in (0.16 s); the world dim shows at once. | ease-out | 0.16 s | `guide` |
| The guide closing | Fades out (0.12 s), then hides. | ease-in | 0.12 s | wax close, Esc |
| Next, back, a ribbon | The books' page turn: the page lifts toward the spine (0.22 s), then lands on the other side from the spine out (0.28 s), with the fold shade and cast shadow. The crumbs change as the leaf passes the spine. | the books' | 0.5 s | `turn` |
| Step ribbons | The new current ribbon drops from 92 to 110 units while the old one draws up (0.2 s, together). | ease-out | 0.2 s | any turn |
| A margin note | Fades in (0–0.25 s); its arrow draws on from the note to the target, segment by segment (0.2–0.55 s); the red ring pops from 0.4x (0.55–0.7 s). A set's notes start 0.12 s apart, in number order. | ease-out; arrow ease-in-out; ring `cubic-bezier(.3, 1.6, .6, 1)` | 0.7 s (+0.12 s a note) | `first`, `look`, `evening` |
| A margin note leaving | Fades out (0.2 s), arrow and ring with it. | ease-in | 0.2 s | (addon) |
| A First evening tick | The box redraws ticked and the line strikes through; the tick pops from 0.6x (0.3 s). | `cubic-bezier(.3, 1.5, .6, 1)` | 0.3 s | `tick` |
| The list folding away | 2.5 s after the last tick it fades out rising 14 units (0.4 s), then hides. | ease-in | 2.9 s | `tick` six times |

Notes for the addon:

- The arrow is `Line` objects; drawing it on is showing them in order. Nothing else needs a texture-coordinate trick.
- A note never moves after it settles; if its target moves (a window dragged), the arrow is re-drawn at once, without motion (ONB-R56).
- Nothing loops. Nothing moves while the guide is idle.
