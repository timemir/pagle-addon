if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- Prestiging on the client (LED-R33): whether it is allowed now, and the Journal's own confirm card that asks before
-- the Ledger calls `M:RecordPrestige()` (LOG-R38). The Ledger is the only Module that calls it. The Angler page's
-- button calls ns.AskPrestige, and closing the Journal hides the card. The card is the Ledger art kit's (its Angler.lua:
-- the Prestige confirm), drawn in the book: the book darkens, the card drops in and the emblem of the rank to come
-- (Core's, LED-R152) is pressed on.

local INK = ns.JOURNAL_INK

--- Whether the Angler may Prestige now (LED-R33): the computed level of the climb is 60 and the projection isn't
--- updating. False while the Ledger is inert (no projection).
---@return boolean
function ns.CanPrestige()
	local projection = ns.projection
	if not projection then
		return false
	end
	return ns.PrestigeAllowed(projection:GetState() --[[@as LedgerState?]], projection:IsUpdating())
end

--- The confirm card over the book: the shade, the card with the emblem of the rank to come, its words and its two
--- buttons.
---@class LedgerPrestigeCard: Frame
---@field shade Texture
---@field card Frame
---@field emblem Texture
---@field yes LedgerButton
---@field no LedgerButton
---@field closing boolean?

-- The card's size and place on the book (the kit's 380 × 219.7 at 270, 160).
local CARD_W, CARD_H, CARD_X, CARD_Y = 380, 219.7, 270, 160
-- The emblem of the rank to come, centred on the card's top edge (LED-R152).
local EMBLEM_SIZE = 64

---@type LedgerPrestigeCard?
local shown

-- Builds the card on the Journal's frame, hidden.
---@param book Frame
---@return LedgerPrestigeCard
local function build(book)
	local L = ns.L
	local card = CreateFrame("Frame", nil, book) --[[@as LedgerPrestigeCard]]
	card:SetAllPoints()
	card:SetFrameLevel(book:GetFrameLevel() + 20)
	card:EnableMouse(true)
	card.shade = ns.JournalTint(card, "0a0602", 0.55, "BACKGROUND")
	card.shade:SetPoint("TOPLEFT", 4, -4)
	card.shade:SetPoint("BOTTOMRIGHT", -4, 4)
	local face = CreateFrame("Frame", nil, card)
	face:SetSize(CARD_W, CARD_H)
	ns.JournalAt(face, card, CARD_X, CARD_Y)
	local back = ns.JournalVSlice(face, "Parts", "dialog", CARD_H, 22, 22, "BACKGROUND")
	back:SetPoint("TOPLEFT")
	card.card = face
	card.emblem = face:CreateTexture(nil, "OVERLAY")
	card.emblem:SetPoint("CENTER", face, "TOP", 0, 0)
	local kicker = ns.JournalLabel(face, "sc", 14, INK.kicker, L.PRESTIGE_CONFIRM_KICKER, { justify = "CENTER" })
	kicker:SetPoint("TOP", face, "TOPLEFT", CARD_W / 2, -46)
	local title = ns.JournalLabel(face, "print", 26, INK.title, L.PRESTIGE_CONFIRM_TITLE, { justify = "CENTER" })
	title:SetPoint("TOP", face, "TOPLEFT", CARD_W / 2, -64)
	local words = ns.JournalLabel(face, "print", 15, INK.body, L.PRESTIGE_CONFIRM_TEXT, {
		justify = "CENTER",
		wrap = true,
		width = 316,
		spacing = 5,
	})
	words:SetPoint("TOP", face, "TOPLEFT", CARD_W / 2, -102)
	card.yes = ns.JournalButton(face)
	ns.JournalSetButton(card.yes, L.PRESTIGE_CONFIRM_YES, 89.3)
	ns.JournalAt(card.yes, face, 95.5, 161.7)
	card.no = ns.JournalButton(face, "light")
	ns.JournalSetButton(card.no, L.PRESTIGE_CONFIRM_NO, 87.8)
	ns.JournalAt(card.no, face, 196.8, 161.7)
	card.yes.action = function()
		ns.ConfirmPrestige()
	end
	card.no.action = function()
		ns.HidePrestigeConfirm()
	end
	card:Hide()
	return card
end

-- The card, made on the Journal's frame at its first asking.
---@return LedgerPrestigeCard?
local function cardOf()
	local book = ns.journal.frame
	if not book then
		return nil
	end
	ns.journal.prestigeCard = ns.journal.prestigeCard or build(book)
	return ns.journal.prestigeCard
end

--- Asks "Begin a new Ledger?" on the open Journal, with "Prestige" and "Not yet" (LED-R33), when Prestige is allowed
--- now: the book darkens to 55% (0.2 s), the card drops in from 20 units up (0.3 s, a slight overshoot) and the
--- Prestige emblem of the rank to come, 64 units (LED-R152), is pressed on at 0.2 s with the stamp sound (MOTION.md ›
--- The Prestige confirm).
--- Confirming checks again and calls `M:RecordPrestige()` only if it still is; otherwise nothing happens.
function ns.AskPrestige()
	if not ns.CanPrestige() or not ns.journal:IsShown() then
		return
	end
	local card = cardOf()
	if not card then
		return
	end
	local state = ns.projection:GetState() --[[@as LedgerState]]
	Pagle.SetPrestigeEmblem(card.emblem, state.prestige + 1, EMBLEM_SIZE)
	card.closing = false
	card:Show()
	card:SetAlpha(1)
	shown = card
	ns.JournalSound("popupOpen")
	Pagle.StopMotion(card)
	Pagle.Animate(card, {
		{
			dur = 0.2,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				card.shade:SetAlpha(0.55 * v[1])
			end,
		},
		{
			dur = 0.3,
			ease = Pagle.Bezier(0.3, 1.3, 0.5, 1),
			keys = { { 0, { -20, 0 } }, { 1, { 0, 1 } } },
			apply = function(v)
				ns.JournalAt(card.card, card, CARD_X, CARD_Y + v[1])
				card.card:SetAlpha(v[2])
			end,
		},
		{
			dur = 0.3,
			delay = 0.2,
			ease = Pagle.Bezier(0.3, 1.5, 0.5, 1),
			keys = { { 0, { 1.8, 0 } }, { 0.7, { 0.95, 1 } }, { 1, { 1, 1 } } },
			apply = function(v)
				card.emblem:SetSize(EMBLEM_SIZE * v[1], EMBLEM_SIZE * v[1])
				card.emblem:SetAlpha(v[2])
			end,
		},
	})
	Pagle.Cue(card, 0.36, function()
		ns.JournalSound("stamp")
	end)
end

--- Whether the confirm card is up.
---@return boolean
function ns.IsPrestigeConfirmShown()
	return shown ~= nil and shown:IsShown() and not shown.closing
end

--- Hides the confirm card if it is up, choosing nothing (LED-R33): "Not yet", and the Journal as it closes. It fades
--- out (0.18 s) with the close sound while the book stays open, then calls `after`.
---@param after fun()?
function ns.HidePrestigeConfirm(after)
	local card = shown
	if not card or not card:IsShown() or card.closing then
		return
	end
	card.closing = true
	shown = nil
	if not ns.journal:IsShown() then
		card:Hide()
		return
	end
	ns.JournalSound("popupClose")
	Pagle.StopMotion(card)
	Pagle.Animate(card, {
		{
			dur = 0.18,
			ease = Pagle.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				card:SetAlpha(v[1])
			end,
		},
	}, function()
		card:Hide()
		card:SetAlpha(1)
		if after then
			after()
		end
	end)
end

--- "Prestige" on the card (LED-R33): checks again and, while Prestige is still allowed, closes the card, plays the
--- banner and calls `M:RecordPrestige()`; the Angler page then turns forward to the new rank. Otherwise only closes it.
--- With the Prestige it saves each source's Activity XP total as it stood, in `PagleLedgerDB.global.prestigeSources`,
--- for "Where your XP came from"'s split of the new climb (LED-R150); display only, never rebuilt.
function ns.ConfirmPrestige()
	local allowed = ns.CanPrestige()
	ns.HidePrestigeConfirm()
	if not allowed then
		return
	end
	ns.JournalSound("banner")
	ns.journal:TurnNext("fwd")
	local sources = Pagle.GetActivityXP().bySource
	local record = ns.Module:RecordPrestige()
	ns.db.global.prestigeSources = ns.PrestigeSources(sources, record)
end
