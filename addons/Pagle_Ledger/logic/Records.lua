if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- Simulated Size records (LED-R80–R85), the fold's part: each Species' and each Legend item's longest Catch by Pagle's
-- own measure (LOG-R65), and the size text the moments and the Journal show. Pure logic, everything passed in (CORE-R7).

-- The rare-record flair (LED-R82, Tunables): the beaten record stood this many Catches of its Species or more.
local RARE_RECORD_SINCE = 50

--- A Species' or Legend item's record (LED-R80, ledger.md › Data): its longest Catch, the earliest on a tie.
---@class LedgerRecord
---@field length integer                      -- millimetres (LOG-R65)
---@field band integer                        -- 1 Tiddler … 5 Monster (LOG-R67)
---@field catchId string                      -- the Catch's ID (LOG-R13)
---@field time integer
---@field char integer
---@field zone integer

--- A Catch's or record's size text (LED-R81), "{band} · {length}": the band's name from `bands` (Pagle.SIZE_BANDS)
--- and the length from `formatLength` (Pagle.FormatLength, in the Angler's unit, LOG-R69, LED-R85). Nil without a size.
---@param size { length: integer, band: integer }? a Catch's `size` or a LedgerRecord
---@param bands { key: string, name: string }[]
---@param formatLength fun(mm: integer): string
---@return string?
function ns.SizeText(size, bands, formatLength)
	if not size then
		return nil
	end
	return ns.L.SIZE_TEXT:format(bands[size.band].name, formatLength(size.length))
end

--- A Catch's or record's Size band's name (Pagle.SIZE_BANDS), "Tiddler" to "Monster": the label of a size record's
--- ruler (ANN-R22, LED-R97). Nil without a size.
---@param size { length: integer, band: integer }? a Catch's `size` or a LedgerRecord
---@param bands { key: string, name: string }[]
---@return string?
function ns.BandName(size, bands)
	return size and bands[size.band].name or nil
end

--- A copy of a Catch's Simulated Size (LOG-R65), for an achievement's size text (LED-R81): records are shared
--- (CORE-R18). Nil without one.
---@param size PagleSize?
---@return PagleSize?
function ns.CopySize(size)
	return size and { length = size.length, band = size.band } or nil
end

--- Notes one Catch against its Species' or Legend item's record (LED-R80), after the fold has counted it: `class` is
--- its class (LED-R5) and `species` its Species ID when a Species. Only a Species or Legend Catch with a size sets or
--- beats a record (LOG-R65): the first sets it silently (LED-R81); a strictly longer one beats it and earns a
--- `sizeRecord`, with the rare-record flair when 50 or more Catches came between (LED-R82); any other Catch after the
--- record, sized or not, counts in `since` (LED-R80). Records
--- earn nothing else (LED-R83). Appended in every mode like any achievement (LED-R3); the moments leave rebuilt ones
--- out (LED-R84).
---@param state LedgerState
---@param class string
---@param species integer?
---@param record PagleCast
---@param catch { itemID: integer, catchId: string, size: PagleSize? }
---@param earned LedgerAchievement[]
function ns.CreditSizeRecord(state, class, species, record, catch, earned)
	local size = catch.size
	---@type (LedgerSpecies|LedgerFirst)?
	local entry
	if class == "legend" then
		entry = state.items[catch.itemID]
	elseif class == "species" and species then
		entry = state.species[species]
	end
	if not entry then
		return
	end
	local old = entry.record
	if not size then
		-- Every Catch of the Species after the record counts, sized or not; only setting or beating it needs a size.
		if old then
			entry.since = entry.since + 1
		end
		return
	end
	if old then
		-- Strictly longer in millimetres, never in the shown unit (LED-R82, LED-R85); else the earlier one stands.
		if size.length <= old.length then
			entry.since = entry.since + 1
			return
		end
		-- No XP, Coins or anything else (LED-R83).
		earned[#earned + 1] = {
			kind = "sizeRecord",
			cast = record.id,
			coins = 0,
			itemID = catch.itemID,
			old = old.length,
			new = size.length,
			flair = entry.since >= RARE_RECORD_SINCE,
			size = ns.CopySize(size),
		}
	end
	entry.record = {
		length = size.length,
		band = size.band,
		catchId = catch.catchId,
		time = record.time,
		char = record.char,
		zone = record.conditions.zone,
	}
	entry.since = 0
end
