if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's parts of onboarding (core/onboarding.md) as data: the Field guide's Your Ledger step's live parts
-- (ONB-R36), the Fish Journal's First look (ONB-R57) and the red pencil of a Margin note's term (Contracts). Pure
-- logic, everything passed in (CORE-R7); adapter/Onboarding.lua draws them and makes Core's calls.

--- `text` with each *term* in the red pencil, as a Margin note's text marks it (Contracts: |cff9a2a1a…|r).
---@param text string
---@return string
function ns.RedPencilTerms(text)
	return (text:gsub("%*(.-)%*", "|cff9a2a1a%1|r"))
end

--- Whether the Angler has had a real break, as `ledger.fresh` waits for (ONB-R52, LED-R22): two consecutive Catches lay
--- one apart in the Catch log (the fold's `hadBreak`), or one has passed since the last Catch, at server time `now`.
---@param state LedgerState
---@param now integer server time
---@return boolean
function ns.HadRealBreak(state, now)
	return state.hadBreak == true or (state.lastCatch ~= nil and ns.IsRealBreak(state.lastCatch, now))
end

--- One line of the Your Ledger step's box of Skill Milestones (ONB-R36).
---@class LedgerGuideMilestone
---@field credited boolean -- ticked in red
---@field title string     -- "Skill Milestone 75", or the rest folded: "Skill Milestones 225 and 300"
---@field line string      -- "reached before Pagle came", "reached {date}", "{n} skill to go" or "for later"
---@field xp string?       -- "+1,000 XP"; nil on the folded line

--- What the Your Ledger step shows that comes from the Ledger's state (ONB-R36): the bookplate's name, kept since and
--- crest, and the Write-up-style box's heading and its Skill Milestones.
---@class LedgerGuidePage
---@field name string                 -- the logged-in character's
---@field since string?               -- "kept since {date}", or "kept since … your first Catch"; nil while updating
---@field prestige integer            -- the crest's prestige rank (LED-R34)
---@field heading string              -- "{name} · Fishing {skill}"
---@field rows LedgerGuideMilestone[]

--- What the step reads: the state (nil while the projection is updating, LOG-R74), the celebrated set, the Angler,
--- the Journal's text and BreakUpLargeNumbers.
---@class LedgerGuideView
---@field state LedgerState?
---@field celebrated { skill: table<integer, any> }
---@field angler Angler
---@field text LedgerJournalText
---@field formatNumber fun(n: integer): string

-- "Skill Milestone 300", or for several "Skill Milestones 150, 225 and 300".
---@param thresholds integer[]
---@return string
local function milestonesTitle(thresholds)
	local L = ns.L
	if #thresholds == 1 then
		return L.GUIDE_MILESTONE:format(thresholds[1])
	end
	local head = {}
	for i = 1, #thresholds - 1 do
		head[i] = tostring(thresholds[i])
	end
	return L.GUIDE_MILESTONES:format(table.concat(head, L.GUIDE_MILESTONE_JOIN), thresholds[#thresholds])
end

--- The Your Ledger step's live parts (ONB-R36, LED-R40, LED-R146): the bookplate reads the logged-in character's
--- name, "kept since" as the Angler page does (or "… your first Catch" before there is one) and the crest's prestige
--- rank; the box is headed by the character and its fishing skill (0 with no Skill Reading), then one line per Skill
--- Milestone: each credited one (in the state or the celebrated set, LED-R92) ticked with its XP, "reached before
--- Pagle came" unless it was credited after the first Catch ("reached {date}"); the next one with "{n} skill to go";
--- the rest folded into one "for later" line. While the projection updates, a Milestone counts as credited when a
--- Skill Reading reaches it, as the fold will credit it (LED-R40), and kept since is left out.
---@param view LedgerGuideView
---@return LedgerGuidePage
function ns.GuideLedgerPage(view)
	local L = ns.L
	local state, angler, text = view.state, view.angler, view.text
	local current = angler.current
	local name = current and text:Character(current) or L.NAME_UNKNOWN
	local reading = current and angler.skill[current]
	local rank = reading and reading.rank or 0
	---@type LedgerGuidePage
	local page = {
		name = name,
		prestige = state and state.prestige or 0,
		heading = L.GUIDE_HEADING:format(name, rank),
		rows = {},
	}
	if state then
		local since = state.firstDate and text:Date(state.firstDate) or state.firstTime and text:DateAt(state.firstTime)
		page.since = since and L.ANGLER_KEPT_SINCE:format(since) or L.GUIDE_KEPT_NONE
	end
	local xp = L.GUIDE_XP:format(view.formatNumber(ns.SKILL_MILESTONE_XP))
	local rest, nextShown = {}, false
	for _, threshold in ipairs(ns.SKILL_MILESTONES) do
		local time = state and state.skill[threshold]
		local credited = time ~= nil
			or view.celebrated.skill[threshold] ~= nil
			or (state == nil and angler.bestBaseSkill >= threshold)
		if credited then
			local first = state and state.firstTime
			local line = L.GUIDE_REACHED_BEFORE
			if time and first and time > first then
				line = L.GUIDE_REACHED:format(text:DateAt(time))
			end
			page.rows[#page.rows + 1] = {
				credited = true,
				title = L.GUIDE_MILESTONE:format(threshold),
				line = line,
				xp = xp,
			}
		elseif not nextShown then
			nextShown = true
			page.rows[#page.rows + 1] = {
				credited = false,
				title = L.GUIDE_MILESTONE:format(threshold),
				line = L.GUIDE_TO_GO:format(math.max(0, threshold - rank)),
				xp = xp,
			}
		else
			rest[#rest + 1] = threshold
		end
	end
	if #rest > 0 then
		page.rows[#page.rows + 1] = { credited = false, title = milestonesTitle(rest), line = L.GUIDE_LATER }
	end
	return page
end

--- One note of a First look (Contracts' PagleFirstLook): its text's key in ns.L, with *terms* for Core's red pencil,
--- the part of the Journal it points at (adapter/Onboarding.lua finds it on the pages shown), where it sits from the
--- book's top left, and how wide.
---@class LedgerFirstLookNote
---@field text string
---@field target "tile"|"xpBar"|"notes"|"search"|"unfished"
---@field x number
---@field y number
---@field w number

--- The Fish Journal's First look (ONB-R57; board "First look · the Fish Journal", the probe's World.lua): five notes,
--- verbatim, in the margins beside the 920-unit book (ONB-R58), at the canvas's places from the book's top left. Its
--- title and texts are keys of ns.L, read as it registers, as logic/ loads without locale/ (#223).
---@type { id: string, title: string, width: number, notes: LedgerFirstLookNote[] }
ns.JOURNAL_FIRST_LOOK = {
	id = "ledger.journal",
	title = "FIRST_LOOK_TITLE",
	width = 920,
	notes = {
		{ text = "FIRST_LOOK_TILE", target = "tile", x = -244, y = 146, w = 176 },
		{ text = "FIRST_LOOK_XP_BAR", target = "xpBar", x = 994, y = 66, w = 176 },
		{ text = "FIRST_LOOK_NOTES", target = "notes", x = 994, y = 246, w = 176 },
		{ text = "FIRST_LOOK_SEARCH", target = "search", x = 994, y = -72, w = 176 },
		{ text = "FIRST_LOOK_UNFISHED", target = "unfished", x = -244, y = 416, w = 176 },
	},
}
