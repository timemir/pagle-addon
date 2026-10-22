if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' own Module records (hunts.md › Contracts, ADR 0008, LOG-R40): the codec of `run` (HNT-R150) and `def`
-- (HNT-R154) payloads. Pure logic (CORE-R7). The projection (logic/Projection.lua) decodes them in `apply`; the step
-- that logs runs (#300) encodes them. pagle-backend's fold reads them through this file too (ADR 0013). A payload this
-- file can't decode is skipped by its reader, never an error.

--- The record kinds Hunts appends (hunts.md › Contracts).
ns.RUN_RECORD, ns.DEF_RECORD = "run", "def"

--- LOG-R40's payload limit, in bytes (catch-log.md › Tunables).
ns.RECORD_PAYLOAD_LIMIT = 200

local EVENT_ID = "^[%w_]+$"

--- A decoded `run` record (HNT-R150): its event, its exact server times and who scheduled it.
---@class HuntRunRecord
---@field event string
---@field start integer
---@field end_ integer
---@field source "r"|"p"   -- the fallback rotation, or pushed

--- A decoded `def` record (HNT-R154): one numbered part of a pushed definition's text.
---@class HuntDefRecord
---@field event string
---@field part integer
---@field parts integer
---@field text string

-- A decimal count with no sign and no leading zero, as the records write them, or nil.
---@param digits string?
---@return integer?
local function count(digits)
	if digits == nil or digits:find("^0%d") then
		return nil
	end
	return tonumber(digits)
end

--- The payload of a `run` record (HNT-R150): `<eventID>|<start>|<end>|<source>`, server times in decimal. Raises an
--- error for a run the record can't hold (a bad ID, times that aren't whole and ascending, an unknown source).
---@param eventID string
---@param start integer
---@param end_ integer
---@param source "r"|"p"
---@return string
function ns.EncodeRun(eventID, start, end_, source)
	assert(type(eventID) == "string" and eventID:find(EVENT_ID), "a run's event ID is [%w_]+")
	assert(type(start) == "number" and start >= 0 and start % 1 == 0, "a run's start is a whole server time")
	assert(type(end_) == "number" and end_ % 1 == 0 and start < end_, "a run's end is a whole time after its start")
	assert(source == "r" or source == "p", "a run's source is r or p")
	return ("%s|%d|%d|%s"):format(eventID, start, end_, source)
end

--- A `run` record's payload decoded (HNT-R150), or nil when it isn't one: an event ID, two decimal server times with
--- `start < end`, and the source `r` or `p`.
---@param payload string
---@return HuntRunRecord?
function ns.DecodeRun(payload)
	local event, startText, endText, source = string.match(payload, "^([%w_]+)|(%d+)|(%d+)|([rp])$")
	local start, end_ = count(startText), count(endText)
	if not event or not start or not end_ or start >= end_ then
		return nil
	end
	return { event = event, start = start, end_ = end_, source = source }
end

-- A `def` part's header: `<eventID>|<part>/<parts>|`.
---@param eventID string
---@param part integer
---@param parts integer
---@return string
local function defHeader(eventID, part, parts)
	return ("%s|%d/%d|"):format(eventID, part, parts)
end

-- The definition's text cut into parts whose payloads, with their headers for `parts` parts, fit LOG-R40's limit.
-- A cut never falls inside a UTF-8 character. Returns the parts' texts.
---@param eventID string
---@param text string
---@param parts integer
---@return string[]
local function cut(eventID, text, parts)
	local texts, at = {}, 1
	while at <= #text do
		local room = ns.RECORD_PAYLOAD_LIMIT - #defHeader(eventID, #texts + 1, parts)
		local last = math.min(#text, at + room - 1)
		-- Back off a cut before a continuation byte (0x80–0xBF), so each part is whole UTF-8.
		while last < #text and last >= at and text:byte(last + 1) >= 0x80 and text:byte(last + 1) < 0xC0 do
			last = last - 1
		end
		assert(last >= at, "a def part has no room for its text")
		texts[#texts + 1] = text:sub(at, last)
		at = last + 1
	end
	return texts
end

--- The payloads of the `def` records that carry a pushed definition's `text` (HNT-R154): `<eventID>|<part>/<parts>|`
--- then that part of the text, numbered from 1, each within LOG-R40's 200 bytes. Raises an error for an ID or text
--- the records can't hold (empty, or with a newline, LOG-R40).
---@param eventID string
---@param text string the definition in the content grammar (logic/Content.lua's ns.WriteContentItem)
---@return string[]
function ns.EncodeDefParts(eventID, text)
	assert(type(eventID) == "string" and eventID:find(EVENT_ID), "a definition's event ID is [%w_]+")
	assert(type(text) == "string" and text ~= "" and not text:find("\n"), "a definition is text without a newline")
	-- The headers grow with the count of parts, so cut again until the count it was cut for holds.
	-- A header never grows when the count of parts it names shrinks, so fewer parts than cut for still fit.
	local parts = 1
	local texts = cut(eventID, text, parts)
	while #texts > parts do
		parts = #texts
		texts = cut(eventID, text, parts)
	end
	local payloads = {}
	for part, partText in ipairs(texts) do
		payloads[part] = defHeader(eventID, part, #texts) .. partText
	end
	return payloads
end

--- A `def` record's payload decoded (HNT-R154), or nil when it isn't one: an event ID, a part number from 1 to its
--- count of parts, and non-empty text (which may hold `|`).
---@param payload string
---@return HuntDefRecord?
function ns.DecodeDef(payload)
	local event, partText, partsText, text = string.match(payload, "^([%w_]+)|(%d+)/(%d+)|(.+)$")
	local part, parts = count(partText), count(partsText)
	if not event or not part or not parts or part < 1 or part > parts then
		return nil
	end
	return { event = event, part = part, parts = parts, text = text }
end
