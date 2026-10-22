# Settings

> Status: Done · Milestones: M1 (the root, the Fishing page), Track Q (the rest of the Fishing page), M2 (Announcements), M3 (Help chart the waters, Open Fish Journal), M4 (Units, the look rows, Look and Feel), M5 (Trackers, Hunts' rows), M6 (Stats' rows), M7 (the Tackle Board's rows), M8.5 Onboarding (Getting started, Pagle menu, the Interruptions slider's range) · Sources: [Prototype the Settings tree](https://github.com/timemir/wow-fish/issues/32#issuecomment-6129969765), [Design the Simulated Size bands](https://github.com/timemir/wow-fish/issues/33#issuecomment-6129722545) (the length unit, via a comment on [Write the Settings spec](https://github.com/timemir/wow-fish/issues/44#issuecomment-6129738678)), [Prototype the Curio Shop](https://github.com/timemir/wow-fish/issues/30#issuecomment-6125718197), [Decide how the spec is assembled](https://github.com/timemir/wow-fish/issues/31#issuecomment-6128960652), [Write the QoL spec](https://github.com/timemir/wow-fish/issues/37#issuecomment-6130705093), [Write the Stats spec](https://github.com/timemir/wow-fish/issues/42#issuecomment-6130764087), [Write the Tackle Board spec](https://github.com/timemir/wow-fish/issues/43#issuecomment-6130761945), [Write the Hunts spec](https://github.com/timemir/wow-fish/issues/41#issuecomment-6131040991), [Write the Ledger spec](https://github.com/timemir/wow-fish/issues/40#issuecomment-6131150684); ADR 0001, 0009. Prototype: `prototypes/settings-tree/` (variant B)

This file is the one place that shows Pagle's whole Settings tree: which rows sit on which page, in what order, under which header, indented under what, and when each is greyed out. Terms are used as `CONTEXT.md` defines them.

## Purpose and boundary

**Owns:** the layout of the Settings root and the four topic pages (CORE-R40): rows, order, headers, indents, greying, the texts no other file gives (headers, notes, Core's tooltips and Hunts' tooltips), each page's Defaults button, what Core's buttons do there, and the milestone each row arrives in.

**Doesn't own:**
- the mechanism: the topic list, `M:AddSetting`, `PagleSetting`, `def.settingsAction`, `Pagle.OpenSettings` and the status list (CORE-R40–R44)
- what an option does, its values, its default and where it is stored: each owner's own rules and Settings section ([QoL](qol.md#settings), [Hunts](hunts.md#settings), [Stats](stats.md#settings), [Tackle Board](tackle-board.md#settings), [Ledger](ledger.md#settings), Core's [catch-log](core/catch-log.md#settings), [announcements](core/announcements.md#settings) and [wallet-and-shop](core/wallet-and-shop.md#settings))
- the looks themselves, ownership and equipping (SHOP-R20–R35)
- Key Bindings › AddOns, where QoL's bindings are also listed (QOL-R1)

**Uses from Core:** CORE-R17, CORE-R32, CORE-R33, CORE-R40–R44, CORE-R71, `Pagle.GetEquipped`, `Pagle.SetEquipped`, `Pagle.IsOwned`, `Pagle.OpenShop`, `Pagle.OpenFieldReport`, `Pagle.GetFieldReportCount`.

## Rules

### The tree at a glance

With every Module on, after M7. `↳` marks a row indented under the nearest row before it that has no `↳`; `;` separates rows:

```
Pagle (the root)
  [Modules]                 status list: Ledger, Hunts, Stats, Tackle Board, QoL, each with its button
                            "Turn Modules on or off in the AddOns list."
  [Help chart the waters]   Field report  [Open Field report (N)]
  [Saving]                  Remind me to /reload when Casts are unsaved
  [Units]                   Length unit;  Clock
Fishing                                                    (QoL only)
  [Casting]                 Cast with  ↳ Fishing key
  [Gear]                    Fishing set  ↳ Save what I'm wearing as my fishing set  ↳ Swap gear
  [Lures and clams]         Lures  ↳ Lure;  Open clams between Casts
  [While you fish]          Fishing audio mix  ↳ Keep sound when the game is in the background;
                            Auto-loot while fishing;  Show the next-action button  ↳ Button position
Announcements
                            Cozy mode;  Interruption budget  ↳ Interruptions  ↳ Per;  Show every catch;  Animations;  Toast style;  Sound set
  [Hunts]                   Tell me when a pinned Hunt's window opens;  Remind me about the Pagle companion
                            (while Hunts' companion hint switch is on, as at 1.0: HNT-R172)
Trackers
                            Tracker position  [Reset]
  [Hunts]                   Show the Hunts tracker;  Hunts tracker frame
  [Stats]                   Show the live tracker  ↳ Watched Dry spells;  Stats tracker frame
  [Tackle Board]            Show goals workable here;  Tackle Board tracker frame
Look and Feel
  [Announcements]           Toast style;  Sound set
  [Crests]                  Crests
  [Books]                   Book binding
  [Trackers]                Hunts tracker frame;  Stats tracker frame;  Tackle Board tracker frame
  [Curio Shop]              Buy more looks with Pagle Coins  [Open the Curio Shop]
```

The rules below are authoritative; this sketch only summarises them.

### The tree

- **SET-R1** The Settings tree is Core's "Pagle" category under Options › AddOns: the root, then the topic pages Fishing, Announcements, Trackers and Look and Feel, in that order (CORE-R40). A page is registered only while it has rows (CORE-R42):

  | Page | Registered while | From |
  |---|---|---|
  | Pagle (root) | always | M1 |
  | Fishing | QoL is On | M1 |
  | Announcements | always (Core's own rows) | M2 |
  | Trackers | Hunts, Stats or the Tackle Board is On | M5 |
  | Look and Feel | always (Core's own slots) | M4 |

  Core's own rows on Trackers (SET-R40) never register the page alone. Before its milestone a page doesn't exist; in M1, the root and Fishing are the whole tree.
- **SET-R2** How the tables in this file read:
  - **Kind** is the `PagleSetting.kind`, or the native control Core uses for its own rows.
  - `↳` means the row's `parent` is the nearest row above it without `↳`, so it is drawn indented one level. There is only one level of indent.
  - **Greyed out when** is the row's `isEnabled` returning false; an empty cell means never.
  - A Module row's values, default, storage and behaviour are in the rule or Settings section cited for it.
  - **Tooltips:** this file gives tooltips only for rows whose owner's spec has none (Core's rows and Hunts' rows); there, the text here is the row's `tooltip`. Every other Module row's tooltip is its owner's. A row given no tooltip anywhere (an empty Tooltip cell, a slot dropdown) has none.
  - A **button** row has a label on the left and a caption on the button. Where a table gives one quoted string for a button, it is the caption and the row has no label.
- **SET-R3** Every topic page lists Core's rows first, then each On Module's rows in `def.order` (Ledger 10, Hunts 20, Stats 30, Tackle Board 40, QoL 50), each under a header with its `def.title`, which Core leaves out when the Module's first row is itself a header (CORE-R42). Core's rows on a topic page have no header of their own.
- **SET-R4** "On" is CORE-R41's state: enabled and registered. A Module whose projection is updating is still On. A Module that isn't On has no rows and no look slots anywhere in the tree (CORE-R17, SHOP-R35), and nothing takes their place: no note and no empty header. The root's status list (SET-R11) is the only place it appears.
- **SET-R5** Every row is a native Settings initializer, so Blizzard's settings search finds it by its label and every page has the native Defaults button (SET-R60). The status list (SET-R11), Stats' Watched Dry spells (`custom`), the slot dropdowns (SET-R51) and every `keybinding` row (SET-R20) are custom initializers carrying their label for search. Paragraphs and notes (SET-R10, SET-R50) are custom text initializers with no search label. A custom initializer is made with `Settings.CreateElementInitializer` on the owner's own XML template, whose mixin draws the row in `Init(initializer)` and clears it in `Release()`; Core's are `PagleSettingsRowTemplate`, `PagleSettingsSlotRowTemplate` and `PagleSettingsKeyRowTemplate` (`adapter/Settings.xml`), each with its own pool; a text or keybinding row is 26 pixels high (SET-R6).
- **SET-R6** No Pagle addon's code writes a field onto anything Blizzard's Settings code made or reads, or calls into it beyond building the tree. Pagle registers categories and settings, creates initializers and controls through the public `Settings` API, and adds to them only through their own methods (`SetParentInitializer`, `AddModifyPredicate`, `AddEvaluateStateCVar`, `AddSearchTags`); it hands Blizzard data and callbacks (`get`, `set`, `isEnabled`, options, `onClick`), which Blizzard runs. It never assigns an initializer's `InitFrame`, `Resetter`, `GetExtent`, `Factory` or `GetTemplate` (the Settings list reads them in its own secure update), calls a setting's `NotifyUpdate`, `SetValue` or `SetValueToDefault`, touches `SettingsCallbackRegistry` or `SettingsInbound`, or reads, calls or hooks anything on `SettingsPanel` and its list, or Blizzard's `KeybindListener`, whose pending action the panel's key handlers read (`Blizzard_Keybindings.lua`); a keybinding row binds through the client's `SetBinding` instead (SET-R20). It opens the panel with `Settings.OpenToCategory` and closes it with `HideUIPanel(SettingsPanel)`, which go through Blizzard's own secure paths. Any of these, done from Pagle's code, taints the Settings list: a Blizzard row drawn after it, such as Audio's "Use Discord client settings", then calls a protected function as Pagle's and the client blocks it (`ADDON_ACTION_FORBIDDEN`, [#246](https://github.com/timemir/wow-fish/issues/246)). So a native row never refreshes while shown from Pagle's side: it re-reads when Blizzard draws it (SET-R61, SET-R62). A custom row's frame is its owner's, so the owner may redraw it at once (SET-R20, SET-R51, SET-R62), keeping its size. `spec/Pagle/settings_taint_spec.lua` checks every shipped file for these.

### The root

- **SET-R10** The root (CORE-R40) shows, in order:

  | # | Header | Row | Kind | Text |
  |---|---|---|---|---|
  | 1 | | only while no Module is On (CORE-R41) | paragraph | "Recording your Catches. Enable a Module to see them." |
  | 2 | Modules | the status list (SET-R11) | custom | From M1. |
  | 3 | | | note | "Turn Modules on or off in the AddOns list." |
  | 4 | Getting started | Field guide | button | "Show me around again", with the line "The eight pages you saw on your first day."; opens the Field guide (ONB-R81). From M8.5. |
  | 5 | | Margin notes | checkbox | on (`PagleDB.global.onboarding.notesOn`), with the button "Show them again" (as `/pagle guide notes`, ONB-R80). Tooltip: "Explain things the first time they happen." From M8.5. |
  | 6 | | First evening list | checkbox | shows the list again (ONB-R63); its line reads "{done} of {total} done"; the row is shown only while an item isn't done. From M8.5. |
  | 7 | Help chart the waters | Field report | button | "Open Field report", or "Open Field report ({N})" while `Pagle.GetFieldReportCount()` is above 0, read each time the root is shown; it calls `Pagle.OpenFieldReport()` (REP-R43). Tooltip: "Copy what you've caught that Pagle's data doesn't know yet, and paste it into the issue form." From M3. |
  | 8 | Saving | Remind me to `/reload` when Casts are unsaved | checkbox | LOG-R86; default off. Tooltip: "A chat line every {step} Casts not yet saved. WoW saves only on /reload or logout, so a crash loses them.", with {step} filled from LOG-R86's tunable (50). From M1. |
  | 9 | Units | Length unit | dropdown | "Centimetres" / "Inches"; LOG-R69, whose default (inches or centimetres by `GetCurrentRegion()`) is Core's. Tooltip: "How Pagle shows the length of your Catches. Records are kept in millimetres, so switching changes only what you see." From M4. |
  | 9a | | Clock | dropdown | "Follow the game's clock" / "24-hour (18:30)" / "12-hour (6:30 PM)"; CORE-R87, default following the game's clock, which stores nothing (`PagleDB.profile.clockFormat` `nil`). Tooltip: "How Pagle writes a time of day, such as the realm time at the top of the Hunts board. Following the game uses the minimap clock's 24-hour mode." Every time of day the books, trackers and tooltips write follows it: the Hunts board's realm clock and its labels (HNT-R50), Stats' times and window bounds (STA-R59), the Tackle Board's posted time (TKB-R102). Added before 1.0, after M8.5. |
  | 10 | Pagle menu | Show the minimap icon | checkbox | on (CORE-R56, `PagleDB.global.minimap`). Tooltip: "A round Pagle button on the minimap's edge that opens the Pagle menu. The menu is also in the AddOns button by the minimap." From M8.5. |
  | 11 | Pagle website | Show other Anglers on player tooltips | checkbox | on (VIEW-R30, `PagleDB.profile.anglerTooltips`). Tooltip: "Adds a Pagle block to the tooltip of players whose Angler is on the Pagle website. Needs the Pagle Companion." It sits beside the Companion hint's row once that switch is on (#305). From Track V. |

  The length unit sits on the root because it is a Core option that three Modules display ([Write the Settings spec](https://github.com/timemir/wow-fish/issues/44#issuecomment-6129738678)). The Clock sits beside it for the same reason: Hunts, Stats and the Tackle Board all write times of day, and how a time reads is a unit of display like a length's, not a look (Look and Feel holds only the goods registry's slots, SET-R50) nor an announcement. Saving, Units and Pagle menu are the sections of Core's options that CORE-R40 lists; their keys are `PagleDB.profile.reloadReminder`, `PagleDB.profile.lengthUnit` ([catch-log.md](core/catch-log.md#data)), `PagleDB.profile.clockFormat` ([core/README.md](core/README.md#data), CORE-R87) and `PagleDB.global.minimap` (CORE-R53); Pagle website's is `PagleDB.profile.anglerTooltips` ([anglers-in-game.md](core/anglers-in-game.md), VIEW-R30). Getting started is onboarding's ([onboarding.md](core/onboarding.md), ONB-R81).
- **SET-R11** The status list is a table of the roster in CORE-R1 order: its name, its TOC version ("dev" in an unpackaged checkout) and its state, as CORE-R41 gives them. The version column is one line that ends before the state column; a longer version is cut with "...", so it never runs under the state. Each On Module's row ends with one button (CORE-R44):

  | Module | Button | Source |
  |---|---|---|
  | Ledger | "Open Fish Journal"; no button in M2, when the Ledger has no view | LED-R1, LED-R120 |
  | Hunts | "Open Hunts" | HNT-R68, HNT-R135 |
  | Stats | "Open Stats" | STA-R4 |
  | Tackle Board | "Start my board" until the board is started, then "Open Tackle Board" | TKB-R1, TKB-R5 |
  | QoL | "Fishing settings »" | QOL-R2 (its `settingsAction` opens Fishing) |

  A Module in any other state shows no button. The list always shows all five roster names, so before a Module is built its row reads Not installed (CORE-R41). Each button arrives with its Module's milestone: QoL's in M1, the Ledger's in M3, Hunts' in M5, Stats' in M6, the Tackle Board's in M7. The list's search label is "Modules".

  Every root row without a "From" note (the paragraph, the status list, the note) is there from M1.
- **SET-R12** Core reads each status button's label (a string, or the function's result) every time the root is shown. Pressing a button runs its action (`def.settingsAction.onClick`, or the first view's `open`). For a Module that has a view (every Module but QoL), and for "Open Field report" and "Open the Curio Shop" (SET-R50), Core first closes the Settings panel (`HideUIPanel(SettingsPanel)`), since what opens would sit behind it. QoL's "Fishing settings »" doesn't close the panel: it moves it to Fishing. While restricted, each action behaves as its own spec says, after the panel has closed: a Module view follows its Module's rules, the Field report prints REP-R44's line and the Curio Shop SHOP-R41's. QoL's button then prints CORE-R33's line, and the panel stays on the root.
- **SET-R13** The root's Defaults button restores the three value rows: the reminder to off, the length unit to its region default (LOG-R69) and the Clock to following the game's clock (CORE-R87).

### Fishing

- **SET-R20** The Fishing page holds only QoL's rows, in the order and with the values, defaults, greying and tooltips of [qol.md's Settings](qol.md#settings). Core has no rows here. QoL's first row is its "Casting" header, so Core adds no "QoL" header (CORE-R42):

  | Header | Row | Kind | Greyed out when | Arrives |
  |---|---|---|---|---|
  | Casting | Cast with | dropdown | | Track Q step 3 |
  | | ↳ Fishing key | keybinding `PAGLE_FISHING_KEY` | Cast with is Double right-click | M1, with its header |
  | Gear | Fishing set | dropdown (this character's choice) | restricted (QOL-R41) | Track Q step 2 |
  | | ↳ "Save what I'm wearing as my fishing set" | button (QOL-R41) | restricted (QOL-R41) | Track Q step 2 |
  | | ↳ Swap gear | keybinding `PAGLE_SWAP_GEAR` | no fishing set is chosen | Track Q step 2 |
  | Lures and clams | Lures | dropdown | | Track Q step 1 |
  | | ↳ Lure | dropdown | Lures isn't Only this one | Track Q step 1 |
  | | Open clams between Casts | checkbox | | Track Q step 6 |
  | While you fish | Fishing audio mix | checkbox | | Track Q step 4 |
  | | ↳ Keep sound when the game is in the background | checkbox | the audio mix is off | Track Q step 4 |
  | | Auto-loot while fishing | checkbox | | Track Q step 4 |
  | | Show the next-action button | checkbox | | Track Q step 5 |
  | | ↳ Button position | button, caption "Reset" (QOL-R73) | the next-action button is off | Track Q step 5 |

  Track Q runs in parallel with M2 onward ([roadmap.md](roadmap.md#track-q-qol-v1)); a header arrives with its section's first row. Until Cast with exists, the Fishing key row has no parent and is never greyed. In M1 the page has no value row, so its Defaults button changes nothing.

  A **keybinding** row is Core's own (SET-R5): Blizzard's native one (`KeyBindingFrameBindingTemplate`) never reads `isEnabled` and never hears its parent change, so it could never grey out ([#120](https://github.com/timemir/wow-fish/issues/120)).
  - It shows its `label`, indented under its parent, then the binding's first two keys as Game › Keybindings does ("Not Bound" for none), and its `tooltip` over the keys.
  - It is greyed out, label and keys, while its `isEnabled` returns false or while restricted (SET-R93), read each time it is drawn. Core redraws it at once after a value changes or a button is pressed through a Module's row (SET-R61), at `UPDATE_BINDINGS`, and when restriction starts or ends.
  - Clicking a key waits for the next press ("Press a key"), as Game › Keybindings does: the key with the modifiers held replaces that slot's key and is taken from any other action that had it. A modifier alone keeps it waiting; Escape or a second click on the slot stops it, binding nothing; another mouse button clicked there is bound like a key. A right-click unbinds that slot's key. Each change goes through the client's `SetBinding` and is saved to the current binding set at once.
- **SET-R21** The Fishing page's Defaults button does what qol.md's Settings says: it restores QoL's value rows and leaves the fishing set, both key bindings and the button's position alone.

### Announcements

- **SET-R30** The Announcements page holds Core's rows, in this order, then each On Module's section (SET-R3):

  | Row | Kind | Values · default | Greyed out when | Tooltip |
  |---|---|---|---|---|
  | Cozy mode | checkbox | off (ANN-R40) | | "Nothing pops up or plays. Every moment waits in the Session summary. A Legend's splash still shows, silently." |
  | Interruption budget | checkbox | on (ANN-R31, ANN-R32) | Cozy mode is on | "When toasts come close together, the smaller ones step down to a quiet Nod. Records always keep their ruler. Greyed out in Cozy mode, which holds everything anyway." |
  | ↳ Interruptions | slider | 1–30, step 1 · 20 | Cozy mode is on, or the budget is off | |
  | ↳ Per | slider, shown as "{n} min" | 1–15 min, step 1 min · 5 min (stored in seconds) | Cozy mode is on, or the budget is off | |
  | Show every catch | checkbox | on (ANN-R13, `everyCatch`) | Cozy mode is on | "A quiet line for each catch: its name, size band and length. A toast or banner for the same catch shows instead. Greyed out in Cozy mode, which shows nothing." |
  | Animations | checkbox | on ([announcements.md › Motion](core/announcements.md#motion), `motion`) | | "Toasts slide in and stamp themselves, banners drop their seal, and the Legend's rays turn. Off, each appears as it settles." |
  | Toast style | slot dropdown, `core.toaststyle` (SET-R51) | owned styles · `core.toaststyle.page` (ANN-R80) | | |
  | Sound set | slot dropdown, `core.soundset` (SET-R51) | owned sets · `core.soundset.driftwood` (ANN-R72) | | |

  Values are stored in `PagleDB.profile.announcements` and the two looks in `PagleDB.profile.appearance` ([announcements.md](core/announcements.md#data)). The two slot rows exist from M4, when Core registers its slots (SHOP-R25); in M2 and M3 the page ends after Per. Show every catch arrives with the catch Nod ([#256](https://github.com/timemir/wow-fish/issues/256)), Animations with the art kit's motion. Every row here is a native checkbox, slider or Core's own slot dropdown row (SET-R5, SET-R51), so nothing is written onto Blizzard's rows (SET-R6).
- **SET-R31** A greyed-out row keeps its value. Each row's greying is re-evaluated on its own condition (SET-R61): turning Cozy mode off makes Interruption budget and Show every catch live again, and Interruptions and Per too unless the budget is off.
- **SET-R32** Hunts adds one section (from M5):

  | Header | Row | Kind | Values · default | Tooltip |
  |---|---|---|---|---|
  | Hunts | Tell me when a pinned Hunt's window opens | checkbox | off (HNT-R88, `PagleHuntsDB.profile.windowMoments`) | "A quiet Nod when a pinned Hunt's window opens. It fades when the window closes." |
  | | Remind me about the Pagle companion | checkbox | on (HNT-R170, HNT-R171, `PagleHuntsDB.profile.companionHint`) | "A line on the Hunts board, and a Nod once a week, while the Pagle companion isn't bringing you new wagers." |

  Neither is greyed out in Cozy mode: the Nod then goes to the Session summary (ANN-R40), as moments do. The second row is registered only while Hunts' companion hint switch is on (HNT-R172), which it is at 1.0, so 1.0's section has both rows. *Default chosen while building (#305): hunts.md › Settings put it on a "Hunts" page, which Settings doesn't have (SET-R1); it governs a reminder and its Nod, so it sits here after the window row. Dismissing the hint on the board turns it off; turning it on brings the hint and the Nod back.* No other Module adds rows to Announcements: the Ledger has no rows, Stats raises no moments (STA-R2), and the Tackle Board's and QoL's sections are on other pages.
- **SET-R33** The Announcements page's Defaults button restores every row of SET-R30 and SET-R32 to its default, the two looks included (SET-R60), and so the companion row, while it is registered, to on.

### Trackers

- **SET-R40** The Trackers page starts with Core's one row (from M5, with the page): "Tracker position", a button "Reset" that puts the tracker dock back at its default place (CORE-R70, CORE-R71). Tooltip: "Shift-drag any Pagle tracker to move them all. This puts them back under the minimap." It is never greyed out; pressed while restricted, it does nothing, since the dock never moves then (CORE-R71). Then come the tracker Modules' sections, in `def.order`, which is also their order in the dock (CORE-R70).
- **SET-R41** **Hunts** (from M5):

  | Header | Row | Kind | Values · default | Tooltip |
  |---|---|---|---|---|
  | Hunts | Show the Hunts tracker | checkbox | on (HNT-R75, `PagleHuntsDB.profile.tracker.shown`) | "A small tracker under the minimap with the Hunts you've pinned on the board." |
  | | Hunts tracker frame | slot dropdown `hunts.trackerframe`, added by Core (SET-R44) | `hunts.trackerframe.none` | |
- **SET-R42** **Stats** (from M6), as [stats.md's Settings](stats.md#settings) gives it:

  | Header | Row | Kind | Values · default |
  |---|---|---|---|
  | Stats | Show the live tracker | checkbox, id `tracker` (ids are per Module, CORE-R42) | off (`PagleStatsDB.profile.tracker`) |
  | | ↳ Watched Dry spells | custom, parent `tracker`; never greyed out | the watches (STA-R60), "Stop watching" per row |
  | | Stats tracker frame | slot dropdown `stats.trackerframe`, added by Core (SET-R44) | `stats.trackerframe.none` |

  The Watched Dry spells row's contents ("{n} of 3", one line per watch, the text shown with none) and the tooltips are stats.md's. The row shows no projection numbers.
- **SET-R43** **Tackle Board** (from M7), as [tackle-board.md's Settings](tackle-board.md#settings) gives it:

  | Header | Row | Kind | Values · default | Greyed out when |
  |---|---|---|---|---|
  | Tackle Board | Show goals workable here | checkbox, id `tracker` (ids are per Module, CORE-R42) | on (`PagleTackleBoardDB.profile.tracker`) | the board isn't started (TKB-R5) |
  | | Tackle Board tracker frame | slot dropdown `tackleboard.trackerframe`, added by Core (SET-R44) | `tackleboard.trackerframe.none` | |

  Before the board is started, the section is these two rows as usual, with the checkbox greyed out; its tooltip (tackle-board.md) always points at the root's "Start my board". There is no separate note.
- **SET-R44** Core adds each Module's "Trackers"-category slot dropdown as the last row of that Module's section (CORE-R42). It has no parent, so it isn't indented, and it is never greyed out, even while its tracker is off: the look is kept for when the tracker shows, and it is also on Look and Feel.
- **SET-R45** The Trackers page's Defaults button restores the three checkboxes (Hunts on, Stats off, Tackle Board on) and the three frames to their default goods (SET-R60). It leaves Stats' watches and the dock's position alone.

### Look and Feel

- **SET-R50** Core builds Look and Feel from the goods registry; Modules add no rows to it (CORE-R42, wallet-and-shop.md UI). It shows, in order:
  1. a paragraph: "Looks you own. Pick one here or with Use in the Curio Shop; both change the same thing."
  2. for each slot category in the order Announcements, Crests, Books, Trackers, skipping a category with no slot shown: a header with the category's name, then one slot dropdown (SET-R51) per registered slot of Core or of an On Module, Core's slots first, then by `def.order`
  3. a header "Curio Shop" and a button row "Buy more looks with Pagle Coins" with the caption "Open the Curio Shop", which closes the panel and calls `Pagle.OpenShop()` (SHOP-R40, SET-R12)

  The slots in 1.0:

  | Category | Slot (label) | Owner | Rule |
  |---|---|---|---|
  | Announcements | `core.toaststyle` (Toast style), `core.soundset` (Sound set) | Core | SHOP-R25 |
  | Crests | `core.crest` (Crests), shown whatever Modules are On; its dropdown is where the earned zone and fish crests are equipped, as the Curio Shop doesn't list them | Core | SHOP-R25 |
  | Books | `core.binding` (Book binding), the one binding every book wears, shown whatever Modules are On; the Ledger's and Hunts' earned bindings are among its options while their Module is On (ADR 0015) | Core | SHOP-R25, LED-R110, HNT-R122 |
  | Trackers | `hunts.trackerframe` (Hunts tracker frame), `stats.trackerframe` (Stats tracker frame), `tackleboard.trackerframe` (Tackle Board tracker frame) | Hunts, Stats, Tackle Board | HNT-R120, STA-R88, TKB-R125 |

  The page, with its paragraph, its Curio Shop row and its first slots, arrives in M4; each later slot arrives with its Module's milestone. Core's one "Book binding" replaced the Ledger's "Journal binding" and Hunts' "Notebook cover" (#351).
- **SET-R51** A **slot dropdown** is the same row wherever it appears (Look and Feel, and beside what it changes on Announcements or Trackers): its label is the slot's label, its options are the slot's owned goods by name (`Pagle.IsOwned`, SHOP-R30) in registration order, and its value is `Pagle.GetEquipped(slot)`. Picking one calls `Pagle.SetEquipped(slot, goodID)` (SHOP-R32). Under the dropdown, "{N} more in the Curio Shop" shows as plain text (not a link) while N, the slot's for-sale goods not owned, is above 0. Its `default` is the slot's default good, so a page's Defaults button restores it like any value row (SET-R60); on every page it appears, it reads and writes the same equipped setting. The options are read each time the dropdown opens and the value redraws on `AppearanceChanged`, so a purchase, a Use in the shop or a pick on the other page shows at once. It is never greyed out.
- **SET-R52** The Look and Feel page's Defaults button sets every slot shown on it to the slot's default good (SET-R60). Slots of Modules that aren't On aren't shown, so their stored looks are left alone (SHOP-R32).
- **SET-R53** The Ledger has no other rows anywhere: its "Open Fish Journal" is on the root, and its earned bindings are picked from Core's "Book binding" on Look and Feel ([ledger.md](ledger.md#settings)).

### Defaults and live rows

- **SET-R60** Each page's Defaults button restores that page's value rows (checkbox, slider, dropdown, slot dropdown) to their `default` and touches nothing else: buttons, keybindings and custom rows keep their state, and a row its owner says Defaults leaves alone (QoL's fishing set) is left alone. A slot dropdown's default is its slot's default good, so Defaults never removes an owned look, only stops using it. A slot shown on two pages is restored by either page's Defaults. A greyed-out row is restored too (the Tackle Board's checkbox before Start). In the native Defaults dialog, "These Settings" means the page shown; "All Settings" is Blizzard's and resets every page.
- **SET-R61** Core re-evaluates every row's `isEnabled` each time its page is shown and whenever any value on that page changes. So the Tackle Board's checkbox is live on the next showing of Trackers after the board is started, wherever it was started. A native row hears only its parent's change, through Blizzard; a keybinding row, Core's own, is redrawn after every change or button press through a Module's row, so Swap gear is live as soon as "Save what I'm wearing" chooses a set (SET-R20).
- **SET-R62** A row's `get` is read each time its page is shown and after each change through the row itself, so a value changed outside Settings (Cast with, cycled from the compartment menu by QOL-R16) shows by the next time the page is shown, and a change its `set` refuses shows the value kept at once (QOL-R42). Slot dropdowns and Stats' watched list redraw at once (SET-R51, stats.md), so a Journal binding picked on the Journal's Angler page or a watch added from the Stats book shows straight away.

### Options that aren't in Settings

- **SET-R70** These are set in their own views and never appear in the tree: the Ledger's active title (the Journal's Angler page, "Signed As"), Hunts' "show completed", pins and tracker collapse (HNT-R77, HNT-R80–R82), the Tackle Board tracker's collapse, the Stats book's position, and adding a Dry spell watch (from the Stats book; stopping one works in both places). The next-action button and the tracker dock are moved by Shift-drag; Settings only resets them.

### Entry points

- **SET-R75** Settings opens:

  | From | Opens | Rule |
  |---|---|---|
  | Options › AddOns › Pagle | the root | CORE-R40 |
  | the compartment menu's "Settings" | the root | CORE-R50 |
  | `/pagle`, `/pagle settings` | the root | CORE-R60, CORE-R61 |
  | QoL's "Fishing settings »" on the root, and `/pagle qol` with no argument | Fishing | QOL-R2, QOL-R17 |
  | `Pagle.OpenSettings(topic)` from any other caller | that page, or the root if it isn't registered | CORE-R43 |

  While restricted, every one of these except Blizzard's own menu prints "Pagle: settings open after combat." (CORE-R33).

## Data

This file adds no data. Each row's value lives with its owner:

| Rows | Stored in |
|---|---|
| Saving, Units | `PagleDB.profile.reloadReminder`, `PagleDB.profile.lengthUnit` ([catch-log.md](core/catch-log.md#data)), `PagleDB.profile.clockFormat` ([core/README.md](core/README.md#data)) |
| Cozy mode, the budget, Show every catch, Animations | `PagleDB.profile.announcements` |
| Every slot dropdown | `PagleDB.profile.appearance[slot]` (SHOP-R32) |
| Tracker position | `PagleDB.profile.dock.point` (Core README Data) |
| Fishing | `PagleQoLDB` (qol.md Data), the fishing set per character in `global.gear[guid]` |
| Hunts' rows | `PagleHuntsDB.profile.tracker.shown`, `profile.windowMoments`, `profile.companionHint` (only while its switch is on, HNT-R172) |
| Stats' rows | `PagleStatsDB.profile.tracker`, `profile.watched` |
| Tackle Board's row | `PagleTackleBoardDB.profile.tracker` |

## Contracts

Uses `M:AddSetting(topic, setting)` and `PagleSetting` (CORE-R42), `def.settingsAction` (CORE-R44), `Pagle.OpenSettings(topic?)` (CORE-R43), `Pagle.IsOwned`, `GetEquipped`, `SetEquipped`, `OpenShop` and event `AppearanceChanged` (SHOP-R30–R33, SHOP-R40), `Pagle.OpenFieldReport` and `GetFieldReportCount` (REP-R26, REP-R43). Each Module calls `M:AddSetting` with exactly the rows its section above lists, in that order:

| Module | Topic | Rows |
|---|---|---|
| QoL | `"fishing"` | SET-R20 |
| Hunts | `"announcements"`, `"trackers"` | SET-R32, SET-R41 (the checkbox; Core adds the frame) |
| Stats | `"trackers"` | SET-R42 (the checkbox and the custom row) |
| Tackle Board | `"trackers"` | SET-R43 (the checkbox) |
| Ledger | none | |

It raises no events and exposes nothing.

## UI

Native Settings panels throughout (CORE-R40). Look reference: `prototypes/settings-tree/` (variant B, the topic tree). Where the prototype differs, this file wins: Hunts' rows use hunts.md's labels ("Show the Hunts tracker", "Tell me when a pinned Hunt's window opens") and its root button reads "Open Hunts"; Hunts' Announcements row sits under a "Hunts" header (CORE-R42), not "From Modules"; tracker frame dropdowns aren't indented (SET-R44); the Tackle Board's section before Start is its greyed checkbox, not a note (SET-R43); and the root has a Units section (SET-R10).

## Settings

This file is the tree; the rules above place every option. Each option's values and default are in its owner's Settings section, linked from its row.

## Tunables

| Name | Value | Rules |
|---|---|---|
| Interruptions slider | 1–30, step 1 (ANN Settings) | SET-R30 |
| Per slider | 1–15 min, step 1 min (ANN Settings) | SET-R30 |
| Watched Dry spells cap, shown as "{n} of 3" | Stats' Watches tunable (3) | SET-R42 |
| Reminder step in the tooltip | LOG-R86's step (50 Casts) | SET-R10 |

## Edge cases

- **SET-R90 Module disabled, then enabled again.** While it is off, its rows, its section header and its slots vanish (SET-R4), a topic page left with no rows isn't registered (SET-R1), and the status list shows it as Off with no button. Its values stay in its own DB, and its stored looks stay in `PagleDB.profile.appearance` (SHOP-R32), so everything comes back as it was when it is enabled. Module state changes only with a `/reload`, so the tree is fixed for a session.
- **SET-R91 Projection rebuild.** No row reads projection state except two: the Tackle Board's button and checkbox, which read whether the board is started (while its projection updates, "Start my board" only opens the board, TKB-R1), and the slot dropdowns, whose owned lists don't flicker during an update (SHOP-R34).
- **SET-R92 First build over existing history.** Nothing in Settings changes; a late-enabled Module's rows appear with their defaults, and its status button is live at once.
- **SET-R93 In combat.** Pages register only outside restriction; after a `/reload` in combat they register when it ends, with every Module's rows (CORE-R32). Opening Settings while restricted prints the chat line (SET-R75); a panel already open is Blizzard's to handle (CORE-R33). There, the dock's Reset does nothing (SET-R40), the root's buttons follow SET-R12, the Curio Shop button prints SHOP-R41's line, and QoL's keybinding rows grey out and take no click, since the client refuses `SetBinding` to addons in combat; a key waiting for a press stops waiting (SET-R20).
- **SET-R94 Crash mid-Session.** A setting changed since the last save is lost with the session, like everything in SavedVariables; nothing here needs repairing at the next login.
- **SET-R95 Daily or weekly reset.** No row depends on it.
- **SET-R96 Uncharted or unconfirmed Catch.** No row depends on it.
