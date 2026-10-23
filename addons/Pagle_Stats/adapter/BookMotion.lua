if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book's own motion and sounds (stats.md › UI; the books art kit v2's MOTION.md and SOUND.md), played by
-- Core's one motion driver (`Pagle.Animate`, announcements.md › Contracts): the ink of a rewritten figure fading up,
-- and the catch's "write". The book's opening, closing and page turn, with their sounds, are Core's shell's
-- (Pagle.NewBook, core/book.md). The driver follows Core's Animations setting itself: off, everything draws settled at
-- once; the "write" goes with the motion (ns.MotionOn). The sounds are the client's own sound kits, by number, on the
-- SFX channel: the client's sound volume and mute are the only switch (no Pagle setting), and they belong to no sound
-- set.

--- Whether things move: Core's Animations setting (`Pagle.IsAnimationsOn()`, announcements.md › Contracts), which
--- Core's driver follows on its own; the book asks it only to choose what it does besides moving (a sound).
---@return boolean
function ns.MotionOn()
	return Pagle.IsAnimationsOn() ~= false
end

--- The book's own sounds (the kit's SOUND.md, Books): sound kit ids, and whether each goes with the motion.
---@type table<string, { id: integer, motion: boolean }>
ns.BOOK_SOUNDS = {
	write = { id = 3093, motion = true }, -- IG_WRITE_QUEST: a catch resets the Dry spell shown
}

--- Plays the book's sound `name` on the SFX channel; one that goes with the motion only while things move.
---@param name string
function ns.BookSound(name)
	local sound = assert(ns.BOOK_SOUNDS[name], "the Stats book has no sound " .. tostring(name))
	if sound.motion and not ns.MotionOn() then
		return
	end
	PlaySound(sound.id, "SFX")
end

--- A rewritten figure's ink fades up from 30% (0.3 s, ease-out), as the kit's ink(): settled at once with the motion
--- off.
---@param region Region
function ns.InkIn(region)
	Pagle.Animate(region, {
		{
			dur = 0.3,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0.3 } }, { 1, { 1 } } },
			apply = function(v)
				region:SetAlpha(v[1])
			end,
		},
	})
end
