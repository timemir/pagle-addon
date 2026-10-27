---@class PagleNS
local ns = select(2, ...)

-- The Curio crate's sounds (wallet-and-shop.md › Motion, "A crate opens"): one Ogg Vorbis file for each beat, by name,
-- under media/crate/sounds/, rendered from the prototype's WebAudio synthesis by scripts/render-crate-sounds.py
-- (pagle_data/crate_sounds.py); don't edit by hand. Played with PlaySoundFile(path, "SFX"). Each is mono, 44.1 kHz, and
-- at the one gain they share, so the levels between them are the prototype's. `ticks` are the three pitches of the card
-- tick, `stings` the six crate tiers' and Curio's, by tier. `knocks` are the three rattles, in order.

local DIR = "Interface\\AddOns\\Pagle\\media\\crate\\sounds\\"

---@type table<string, string|string[]>
ns.CRATE_SOUNDS = {
	crateLand = DIR .. "crate_land.ogg",
	sealCrack = DIR .. "seal_crack.ogg",
	strapsSnap = DIR .. "straps_snap.ogg",
	lidWhoosh = DIR .. "lid_whoosh.ogg",
	reelOpen = DIR .. "reel_open.ogg",
	cardLand = DIR .. "card_land.ogg",
	cardTurn = DIR .. "card_turn.ogg",
	stamp = DIR .. "stamp.ogg",
	payback = DIR .. "payback.ogg",
	knocks = { DIR .. "crate_knock_1.ogg", DIR .. "crate_knock_2.ogg", DIR .. "crate_knock_3.ogg" },
	ticks = { DIR .. "card_tick_1.ogg", DIR .. "card_tick_2.ogg", DIR .. "card_tick_3.ogg" },
	stings = {
		DIR .. "sting_1.ogg",
		DIR .. "sting_2.ogg",
		DIR .. "sting_3.ogg",
		DIR .. "sting_4.ogg",
		DIR .. "sting_5.ogg",
		DIR .. "sting_6.ogg",
	},
	curio = DIR .. "sting_curio.ogg",
}
