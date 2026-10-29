if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board's sounds (tackle-board.md › UI, the board art kit's SOUND.md): UI foley from the client's own sound kits,
-- by their numeric ids, and the Campfire's own rendered file (scripts/render-campfire-sound.py), on the SFX channel, so
-- the client's SFX volume and mute are their only switch. They are never
-- part of a sound set (core.soundset.* owns an Announcement's arrival alone), and they play only while the board shows:
-- its opening and closing, the Fly Box drawer's, and the moments of change (adapter/BoardChanges.lua). A beat tied to
-- the motion (the DONE stamp landing, a tack pressed in) plays only while Core's Animations setting is on.

--- Each sound by its event, as SOUND.md picks them (SoundKitConstants.lua's ids): a sound kit's number, played with
--- PlaySound, or the path of a file of the addon's own, played with PlaySoundFile.
ns.BOARD_SOUNDS = {
	boardOpen = 844, -- IG_QUEST_LOG_OPEN
	boardClose = 845, -- IG_QUEST_LOG_CLOSE
	noticeDone = 878, -- IG_QUEST_LIST_COMPLETE: a goal is done (then the stamp lands)
	stamp = 1204, -- PUT_DOWN_GEMS: the DONE stamp lands
	pin = 1212, -- PUT_DOWN_SMALL_CHAIN: a slip goes on the spike; a fresh Notice's tack is pressed in
	fireUp = 23287, -- UI_POWER_AURA_GENERIC: the Campfire steps up or is lit
	kindling = 838, -- IG_ABILITY_ICON_DROP: a Kindling stick burns
	fireOut = 879, -- IG_QUEST_CANCEL: the Campfire goes out
	flyTied = 73919, -- UI_PROFESSIONS_NEW_RECIPE_LEARNED_TOAST: a fly is tied
	drawerOpen = 862, -- IG_BACKPACK_OPEN: the Fly Box drawer opens
	drawerClose = 863, -- IG_BACKPACK_CLOSE: and closes
	campfire = "Interface\\AddOns\\Pagle_TackleBoard\\media\\sounds\\Campfire.ogg", -- the Campfire card opens (#473)
}

--- Plays `event`'s sound on the SFX channel; a `beat` of the motion only while Core's Animations setting is on.
---@param event string a key of ns.BOARD_SOUNDS
---@param beat boolean?
function ns.BoardSound(event, beat)
	if beat and not ns.MotionOn() then
		return
	end
	local sound = ns.BOARD_SOUNDS[event]
	if type(sound) == "string" then
		PlaySoundFile(sound, "SFX")
	else
		PlaySound(sound, "SFX")
	end
end
