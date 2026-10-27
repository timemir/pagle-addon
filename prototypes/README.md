# Prototypes

Throwaway UI prototypes made while charting the spec. Each one is a single `index.html` you open in a browser. The decision, including which variant was chosen, lives in its ticket. They're reference for `docs/spec/`, not shipping code.

- `catch-feedback/`: [Prototype Catch feedback: toasts, sounds and cozy mode](https://github.com/timemir/pagle-addon/issues/13#issuecomment-6113132854)
- `fish-journal/`: [Prototype the Fish Journal](https://github.com/timemir/pagle-addon/issues/12#issuecomment-6112909660)
- `hunts-board/`: [Prototype the Hunts board](https://github.com/timemir/pagle-addon/issues/24#issuecomment-6114195571)
- `stats-window/`: [Prototype the Stats window and live tracker](https://github.com/timemir/pagle-addon/issues/27#issuecomment-6125434287)
- `curio-shop/`: [Prototype the Curio Shop](https://github.com/timemir/pagle-addon/issues/30#issuecomment-6125718197)
- `tackle-board/`: [Prototype the Tackle Board](https://github.com/timemir/pagle-addon/issues/29#issuecomment-6126015781)
- `settings-tree/`: [Prototype the Settings tree](https://github.com/timemir/pagle-addon/issues/32#issuecomment-6129969765)
- `curio-crate/`: the Curio crate's opening over the shop window (crate, reel, reveal), with its storyboard, the odds by crate tier and the notes for the addon below it. Made with the dev in chat; spec in `docs/spec/core/wallet-and-shop.md` (SHOP-R50–R55, Motion and sound). The prototype's tier names (Common to Legendary) and the tier it gives each good are stand-ins: the crate tiers are named Plain, Fine, Lively, Showpiece, Marvel and Heirloom, a good's is its price tier's, and the whole-shop draw, payback and pity are in the spec, which wins where the prototype's notes differ. Its SVG and CSS are the brief the crate kit is rendered from, and its synthesized sounds the brief for the crate's sound beats.
- `onboarding-kit/`: the dev's onboarding kit, not an `index.html`: 18 canvas boards (`canvas/`), the `PagleArtGuide` probe addon whose Lua is the layout reference, and its motion and sound notes. [The onboarding kit, grilled with the dev](https://github.com/timemir/pagle-addon/issues/260#issuecomment-6335904394); spec in `docs/spec/core/onboarding.md`.

The sound prototype stays on the `prototype/sounds` branch. Its render script and `.ogg` files move into the addon source in M2.
