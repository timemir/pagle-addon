if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The collection spreads' own widgets (LED-R143, LED-R144; ledger.md › UI): the Trophy Room's weights ruler and the
-- Junk Museum's plinths, drawn from the blocks logic/JournalCollections.lua makes, in the Ledger art kit's look (its
-- Rooms.lua: P.WeightRuler, P.Plinth), with the kit's moments of change (MOTION.md): a trophy weight landing, an
-- exhibit added.

local INK = ns.JOURNAL_INK
local rgb = ns.JournalRGB

-- The ruler's height, the ruled pitch along its foot, and where its weights sit across it (the lightest at 10%, the
-- heaviest at 90%, as the canvas spreads them).
local RULER_H, PITCH = 98, 12
local SPREAD_FROM, SPREAD = 0.1, 0.8
-- A mark's height and width, not landed and landed.
local MARK_H, MARK_H_INKED = 22, 36
local GHOST_MARK = "b8a080"

---@class LedgerRulerMarkView
---@field line Texture
---@field label FontString

---@class LedgerRulerWidget: LedgerJournalWidget
---@field box Frame
---@field edges Texture[]
---@field inset Texture
---@field pitch Texture[]
---@field marks LedgerRulerMarkView[]
---@field heaviest FontString
---@field rulerW number?

-- Places mark `view` at `cx` across the ruler, its height `h` and ink between ghost (0) and red (1).
---@param widget LedgerRulerWidget
---@param view LedgerRulerMarkView
---@param cx number
---@param h number
---@param ink number
local function placeMark(widget, view, cx, h, ink)
	local w = 2 + ink
	view.line:SetSize(w, h)
	ns.JournalAt(view.line, widget.box, cx - w / 2, RULER_H - 1.5 - 10 - h)
	local gr, gg, gb = rgb(GHOST_MARK)
	local rr, rg, rb = rgb(INK.red)
	view.line:SetColorTexture(gr + (rr - gr) * ink, gg + (rg - gg) * ink, gb + (rb - gb) * ink, 1)
	view.label:ClearAllPoints()
	view.label:SetPoint("TOP", widget.box, "TOPLEFT", cx, -(RULER_H - 1.5 - 10 - h - 3 - 17))
end

-- The weights ruler (LED-R143, LED-R62): a cream box ruled along its foot, a mark per weight placed by its pounds, its
-- weight over it; a landed weight's mark inked red and taller, and "heaviest" in the hand over the heaviest landed.
-- Drawn again on the same page with a weight newly landed, its mark inks red and grows, and "heaviest" moves over to
-- it (MOTION.md › A trophy weight landed).
ns.RegisterJournalWidget("board", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerRulerWidget]]
	widget.box = CreateFrame("Frame", nil, widget)
	widget.box:SetPoint("TOPLEFT", 4, 0)
	widget.marks = {}
	widget.heaviest = ns.JournalLabel(widget.box, "hand", 19, INK.red, ns.L.TROPHY_HEAVIEST, { justify = "CENTER" })
	if widget.heaviest.SetRotation then
		widget.heaviest:SetRotation(math.rad(4))
	end
	-- the box and its ruling, made again at a new width
	local function build(w)
		for _, region in ipairs(widget.edges or {}) do
			region:Hide()
		end
		widget.edges = {}
		widget.box:SetSize(w, RULER_H)
		local paper = ns.JournalTint(widget.box, "fff8e4", 0.3, "BACKGROUND")
		paper:SetPoint("TOPLEFT", 1.5, -1.5)
		paper:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
		widget.edges[1] = paper
		for _, edge in ipairs(ns.JournalOutline(widget.box, 0, 0, w, RULER_H, INK.tileInk, 1, "BORDER", 1.5)) do
			widget.edges[#widget.edges + 1] = edge
		end
		local inset = ns.JournalTint(widget.box, INK.tileInk, 0.25, "BORDER", 1)
		inset:SetSize(w - 3, 2)
		ns.JournalAt(inset, widget.box, 1.5, RULER_H - 3.5)
		widget.edges[#widget.edges + 1] = inset
		for i = 0, math.floor((w - 3 - PITCH) / PITCH) do
			local tick = ns.JournalTint(widget.box, INK.tileInk, 0.35, "BORDER", 2)
			tick:SetSize(1, 12)
			ns.JournalAt(tick, widget.box, 1.5 + 11 + i * PITCH, RULER_H - 13.5)
			widget.edges[#widget.edges + 1] = tick
		end
		widget.rulerW = w
	end
	function widget.Fill(self, block, width, _, draw)
		local w = math.min(374, width - 8)
		if self.rulerW ~= w then
			build(w)
		end
		local ticks = block.ticks or {}
		local inked, heaviest = {}, nil
		for i, tick in ipairs(ticks) do
			inked[i] = tick.inked
			if tick.inked and (heaviest == nil or tick.at >= ticks[heaviest].at) then
				heaviest = i
			end
		end
		local same, before = ns.JournalRemember(self, draw, "ruler:" .. #ticks, { inked = inked, heaviest = heaviest })
		local function cxOf(i)
			return 1.5 + (w - 3) * (SPREAD_FROM + SPREAD * ticks[i].at)
		end
		for i, tick in ipairs(ticks) do
			local view = self.marks[i]
			if not view then
				view = {
					line = ns.JournalTint(self.box, GHOST_MARK, 1, "ARTWORK"),
					label = ns.JournalLabel(self.box, "print", 14, INK.title, "", { justify = "CENTER" }),
				}
				self.marks[i] = view
			end
			view.label:SetText(tick.text)
			view.label:SetTextColor(rgb(tick.inked and INK.title or "a89070"))
			local cx = cxOf(i)
			ns.StopMotion(view.line)
			local landed = same and before and tick.inked and not before.inked[i] and ns.Moving()
			if landed then
				-- the grey mark inks red and grows from 22 to 36 units (0.4 s); its number darkens at 0.2 s
				view.label:SetTextColor(rgb("a89070"))
				ns.Animate(view.line, {
					{
						dur = 0.4,
						ease = ns.Ease.out,
						keys = { { 0, { MARK_H, 0 } }, { 1, { MARK_H_INKED, 1 } } },
						apply = function(v)
							placeMark(self, view, cx, v[1], v[2])
						end,
					},
				})
				ns.Cue(view.line, 0.2, function()
					view.label:SetTextColor(rgb(INK.title))
				end)
			else
				placeMark(self, view, cx, tick.inked and MARK_H_INKED or MARK_H, tick.inked and 1 or 0)
			end
			view.line:Show()
			view.label:Show()
		end
		for i = #ticks + 1, #self.marks do
			self.marks[i].line:Hide()
			self.marks[i].label:Hide()
		end
		local mark = self.heaviest
		mark:SetShown(heaviest ~= nil)
		ns.StopMotion(mark)
		if heaviest then
			local to = cxOf(heaviest)
			local from = same
				and before
				and before.heaviest
				and before.heaviest ~= heaviest
				and ticks[before.heaviest]
				and cxOf(before.heaviest)
			local function at(x)
				mark:ClearAllPoints()
				mark:SetPoint("TOP", self.box, "TOPLEFT", x, -1.3)
			end
			if from and ns.Moving() then
				-- "heaviest" moves over to it in the hand (0.5 s from 0.3 s)
				ns.Animate(mark, {
					{
						dur = 0.5,
						delay = 0.3,
						ease = ns.Ease.inOut,
						keys = { { 0, { from } }, { 1, { to } } },
						apply = function(v)
							at(v[1])
						end,
					},
				})
			else
				at(to)
			end
		end
		return RULER_H + 2
	end
	return widget
end)

---@class LedgerPlinthWidget: LedgerJournalWidget
---@field medal LedgerMedal
---@field base LedgerSpriteTexture
---@field name FontString
---@field plaque FontString

-- A plinth in the Junk Museum (LED-R144, LED-R124): the exhibit's medallion on its plinth, its name and its plaque
-- centred under it; uncaught, the unknown medallion over the dusted, empty plinth, "An empty plinth" and the shared
-- line. Two side by side (ns.DrawJournalPage pairs them). Drawn again on the same page once caught, the empty plinth
-- gives way and the exhibit drops onto it with the write sound (MOTION.md › An exhibit donated).
ns.RegisterJournalWidget("plinth", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerPlinthWidget]]
	widget.medal = ns.JournalMedal(widget, 44)
	widget.base = ns.JournalSprite(widget, "Parts", "plinth", "ARTWORK")
	widget.name = ns.JournalLabel(widget, "print", 15, INK.title, "", { justify = "CENTER" })
	widget.label = widget.name
	widget.plaque = ns.JournalLabel(widget, "italic", 12.5, INK.tileInk, "", {
		justify = "CENTER",
		wrap = true,
		spacing = 3,
	})
	widget.texture = widget.medal.icon
	function widget.Fill(self, block, width, _, draw)
		local caught = block.look ~= "silhouette"
		local cx = width / 2
		ns.JournalSetMedal(self.medal, block.icon, block.look)
		ns.StopMotion(self)
		self:SetAlpha(1)
		ns.JournalAt(self.medal, self, cx - 22, 8)
		ns.JournalSetSprite(self.base, "Parts", caught and "plinth" or "plinth-empty")
		ns.JournalPut(self.base, self, cx - 36, 55)
		ns.JournalRestyle(self.name, "print", 15, caught and INK.title or INK.noteLight)
		self.name:SetText(block.text)
		ns.JournalBound(self.name, width)
		self.name:ClearAllPoints()
		self.name:SetPoint("TOP", self, "TOPLEFT", cx, -72)
		self.plaque:SetText(block.value or "")
		self.plaque:SetShown(block.value ~= nil)
		self.plaque:SetWidth(width)
		self.plaque:ClearAllPoints()
		self.plaque:SetPoint("TOP", self, "TOPLEFT", cx, -93)
		local same, wasEmpty = ns.JournalRemember(self, draw, "plinth:" .. tostring(block.icon), not caught)
		if same and wasEmpty and caught and ns.Moving() then
			-- the exhibit fades in as the empty plinth goes (0.2 s) and drops onto it from 16 units up (0.35 s)
			ns.JournalSound("write")
			local medal = self.medal
			ns.Animate(self, {
				{
					dur = 0.2,
					ease = ns.Ease.out,
					keys = { { 0, { 0 } }, { 1, { 1 } } },
					apply = function(v)
						self:SetAlpha(v[1])
					end,
				},
				{
					dur = 0.35,
					delay = 0.05,
					ease = ns.Bezier(0.3, 1.4, 0.5, 1),
					keys = { { 0, { -16 } }, { 1, { 0 } } },
					apply = function(v)
						ns.JournalAt(medal, self, cx - 22, 8 + v[1])
					end,
				},
			})
		end
		local plaqueH = block.value and self.plaque:GetStringHeight() or 0
		return 93 + plaqueH + 14
	end
	return widget
end)
