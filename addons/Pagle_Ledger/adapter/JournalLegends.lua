if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- A Legend's plate (LED-R147; ledger.md › UI): one page across the whole spread, framed in a double rule with
-- fleurons in its corners, drawn inside the book from the plate block logic/JournalLegends.lua makes. It is the
-- Journal's own drawing, never an Announcement. The Ledger art kit's plate (its Rooms.lua: plate, P.OpenPlate), with
-- its moments: it fades up over the spread as its crest rises and the Title seal is pressed on, and fades away when
-- clicked.

local INK = ns.JOURNAL_INK

-- The plate's size (the pages' whole spread) and its middle.
local W, H = 884, 546
local MID = W / 2

---@class LedgerLegendPlate: Button
---@field crest Frame
---@field crestIcon Texture
---@field kicker FontString
---@field name FontString
---@field first FontString
---@field size FontString
---@field seal LedgerSeal
---@field title FontString
---@field foot FontString
---@field place LedgerJournalPlace?
---@field open fun(place: LedgerJournalPlace)?

-- The crest's place on the plate, and its size.
local CREST_X, CREST_Y, CREST_W = 354, 56.2, 176

--- Builds the plate over `pagesFrame`, hidden: a click anywhere on it opens its place (back to the Legend's page).
---@param pagesFrame Frame
---@return LedgerLegendPlate
function ns.BuildLegendPlate(pagesFrame)
	local plate = CreateFrame("Button", nil, pagesFrame) --[[@as LedgerLegendPlate]]
	plate:SetAllPoints()
	plate:SetFrameLevel(pagesFrame:GetFrameLevel() + 30)
	local paper = ns.JournalCrisp(plate:CreateTexture(nil, "BACKGROUND"))
	paper:SetTexture(ns.JOURNAL_FILES.parchment)
	paper:SetAllPoints()
	ns.JournalOutline(plate, 22, 22, W - 44, H - 44, INK.kicker, 1, "ARTWORK", 1.5)
	ns.JournalOutline(plate, 23.5, 23.5, W - 47, H - 47, "fff8e4", 0.25, "ARTWORK", 4)
	ns.JournalOutline(plate, 27.5, 27.5, W - 55, H - 55, INK.rule, 1, "ARTWORK", 1)
	for _, corner in ipairs({
		{ 34, 34, false, false },
		{ W - 56, 34, true, false },
		{ 34, H - 56, false, true },
		{
			W - 56,
			H - 56,
			true,
			true,
		},
	}) do
		local fleuron = ns.JournalPiece(plate, "Book", "fleuron", "ARTWORK", 1)
		fleuron:SetSize(22, 22)
		fleuron:SetAlpha(0.8)
		ns.JournalAt(fleuron, plate, corner[1], corner[2])
		local l, r, t, b = ns.JournalCoords("Book", "fleuron")
		fleuron:SetTexCoord(corner[3] and r or l, corner[3] and l or r, corner[4] and b or t, corner[4] and t or b)
	end
	plate.kicker = ns.JournalLabel(plate, "sc", 16, INK.kicker, ns.L.LEGENDS_PLATE_KICKER, { justify = "CENTER" })
	plate.kicker:SetPoint("TOP", plate, "TOPLEFT", MID, -30)
	-- the crest, with the Legend's icon in its well
	plate.crest = CreateFrame("Frame", nil, plate)
	plate.crest:SetSize(CREST_W, CREST_W * 194 / 176)
	local frameArt = ns.JournalSprite(plate.crest, "Crests", "crest-legend", "ARTWORK", 1, CREST_W)
	ns.JournalPut(frameArt, plate.crest, 0, 0)
	plate.crestIcon = ns.JournalCrisp(plate.crest:CreateTexture(nil, "ARTWORK", nil, 2))
	plate.crestIcon:SetSize(108, 108)
	plate.crestIcon:SetPoint("CENTER", plate.crest, "TOPLEFT", CREST_W / 2, -87)
	local mask = plate.crest:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(plate.crestIcon)
	plate.crestIcon:AddMaskTexture(mask)
	ns.JournalAt(plate.crest, plate, CREST_X, CREST_Y)
	plate.name = ns.JournalLabel(plate, "print", 38, INK.title, "", { justify = "CENTER" })
	plate.name:SetPoint("TOP", plate, "TOPLEFT", MID, -258)
	plate.first = ns.JournalLabel(plate, "hand", 24, INK.hand, "", { justify = "CENTER" })
	plate.first:SetPoint("TOP", plate, "TOPLEFT", MID, -306)
	plate.size = ns.JournalLabel(plate, "print", 15, INK.small, "", { justify = "CENTER" })
	plate.size:SetPoint("TOP", plate, "TOPLEFT", MID, -340)
	ns.JournalRule(plate, MID - 100, 374.3, 200)
	plate.seal = ns.JournalSeal(plate, 70, 11)
	plate.seal:SetPoint("CENTER", plate, "TOPLEFT", 360, -439.3)
	ns.JournalSetSeal(plate.seal, ns.L.LEGENDS_PLATE_SEAL, true)
	plate.title = ns.JournalLabel(plate, "sc", 26, INK.red)
	plate.title:SetPoint("TOPLEFT", plate, "TOPLEFT", 409, -426)
	plate.foot = ns.JournalLabel(plate, "italic", 13, INK.note, "", { justify = "CENTER" })
	plate.foot:SetPoint("TOP", plate, "TOPLEFT", MID, -498)
	plate:SetScript("OnClick", function(self)
		if self.place and self.open then
			self.open(self.place)
		end
	end)
	plate:Hide()
	return plate
end

--- Fills the plate from `block` (LED-R147): the Legend's icon, name, first Catch (`lines[1]`, in the hand), its record's
--- size text (`lines[2]`, left out without a size), its title by the seal (`seal`, left out without one) and the foot
--- (`value`); a click opens `block.place`.
---@param plate LedgerLegendPlate
---@param block LedgerBlock
---@param open fun(place: LedgerJournalPlace)
function ns.FillLegendPlate(plate, block, open)
	ns.JournalItemIcon(plate.crestIcon, block.icon, "sepia")
	local lines = block.lines or {}
	plate.name:SetText(block.text or "")
	ns.JournalBound(plate.name, W - 80)
	plate.first:SetText(lines[1] or "")
	ns.JournalBound(plate.first, W - 80)
	plate.size:SetText(lines[2] or "")
	ns.JournalBound(plate.size, W - 80)
	plate.seal:SetShown(block.seal ~= nil)
	plate.title:SetShown(block.seal ~= nil)
	plate.title:SetText(block.seal or "")
	ns.JournalBound(plate.title, W - 409 - 40)
	plate.foot:SetText(block.value or "")
	plate.place, plate.open = block.place, open
end

--- Opens the plate over the spread (MOTION.md › Opening the Legend plate): the page-turn sound, the plate fading up as
--- its crest rises 8 units into place (0.3 s), and the Title seal pressed on at 0.25 s (1.7x to 1x, overshooting) with
--- the stamp sound. Settled at once while things don't move.
---@param plate LedgerLegendPlate
function ns.OpenLegendPlate(plate)
	plate:Show()
	ns.JournalSound("plateOpen")
	ns.Moving()
	ns.StopMotion(plate)
	local seal, crest = plate.seal, plate.crest
	ns.Animate(plate, {
		{
			dur = 0.3,
			ease = ns.Ease.out,
			keys = { { 0, { 0, 8 } }, { 1, { 1, 0 } } },
			apply = function(v)
				plate:SetAlpha(v[1])
				ns.JournalAt(crest, plate, CREST_X, CREST_Y + v[2])
			end,
		},
		{
			dur = 0.3,
			delay = 0.25,
			ease = ns.Bezier(0.3, 1.5, 0.5, 1),
			keys = { { 0, { 1.7, 0 } }, { 0.7, { 0.95, 1 } }, { 1, { 1, 1 } } },
			apply = function(v)
				seal:SetSize(70 * v[1], 70 * v[1])
				seal:SetAlpha(v[2])
			end,
		},
	})
	ns.Cue(plate, 0.42, function()
		ns.JournalSound("stamp")
	end)
end

--- Closes the plate (it fades out, 0.18 s), then calls `after`.
---@param plate LedgerLegendPlate
---@param after fun()?
function ns.CloseLegendPlate(plate, after)
	ns.Moving()
	ns.StopMotion(plate)
	ns.Animate(plate, {
		{
			dur = 0.18,
			ease = ns.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				plate:SetAlpha(v[1])
			end,
		},
	}, function()
		plate:Hide()
		plate:SetAlpha(1)
		if after then
			after()
		end
	end)
end
