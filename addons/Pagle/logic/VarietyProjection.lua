---@class PagleNS
local ns = select(2, ...)

-- Core's variety projection (VAR-R10, VAR-R13, LOG-R78): Core's third projection over the Catch log, keeping which
-- of its ten varieties each Species has been caught in, from the variety Core decodes on every caught Cast's items
-- (VAR-R4). The fish crests read it (VAR-R12); the Ledger keeps its own record and never reads it (ADR 0001). Pure
-- logic, everything passed in (CORE-R7); logic/Wiring.lua binds Core's one.

--- The variety rules version (varieties.md › Data): a change rebuilds the projection (LOG-R72).
ns.VARIETY_RULES_VERSION = 1

--- What the variety projection stores in PagleDB.global.projections.varieties (varieties.md › Data).
---@class PagleVarietyState
---@field bySpecies table<integer, table<integer, true>> -- each Species' positions caught (1–10), by Species ID

--- What the variety projection is fed (logic/Wiring.lua, for Core's adapter and FakePagle alike).
---@class PagleVarietyProjectionOptions
---@field projections PagleProjections   -- Core's projection machinery
---@field db table                         -- PagleDB.global.projections.varieties
---@field iterate fun(afterSeq: integer?): fun(): PagleRecord? -- the log's records (Pagle.IterateCatches)
---@field changed fun()                    -- after its done, and after a live Catch that adds a variety (VAR-R13)
---@field added? fun(castId: string, ids: table<string, true>) -- a live Cast's varieties caught for the first time,
--- before its `changed` (VAR-R27)

-- A fresh, empty state: no variety caught.
---@return PagleVarietyState
local function reset()
	return { bySpecies = {} }
end

-- The Species of a variety, from its ID "<speciesID>.<key>" (VAR-R2), or nil for any other shape.
---@param variety any
---@return integer?
local function speciesOf(variety)
	local id = type(variety) == "table" and variety.id
	return type(id) == "string" and tonumber(id:match("^(%d+)%.")) or nil
end

-- Counts one record (VAR-R10): each item of a caught Cast that has a variety (VAR-R1, VAR-R4) adds its position to
-- its Species' set. Every other kind, and an item without a variety (an Uncharted Catch, a Trophy, a Legend), adds
-- nothing. Returns the IDs of the varieties it added that weren't caught before, as a set, or nil for none.
---@param state PagleVarietyState
---@param record PagleRecord
---@return table<string, true>?
local function count(state, record)
	if record.kind ~= "cast" then
		return nil
	end
	---@cast record PagleCast
	local added
	for _, item in ipairs(record.items or {}) do
		local variety = item.variety
		local species = speciesOf(variety)
		local index = variety and variety.index
		if species and type(index) == "number" then
			-- A Species is read only from a variety.
			---@cast variety PagleVariety
			local caught = state.bySpecies[species]
			if not caught then
				caught = {}
				state.bySpecies[species] = caught
			end
			if not caught[index] then
				caught[index] = true
				added = added or {}
				added[variety.id] = true
			end
		end
	end
	return added
end

--- Binds the variety projection on Core's machinery (LOG-R78) to `options.db`, with the variety rules version and no
--- extraFingerprint, so a new catalogue fingerprint rebuilds it (DATA-R71, VAR-R90). `options.changed` runs from its
--- done, after every catch-up or rebuild, and after each live Catch that adds a variety; never mid-catch-up or
--- mid-rebuild, so Core's earned goods are asked only then (VAR-R13).
---@param options PagleVarietyProjectionOptions
---@return PagleProjection
function ns.AddVarietyProjection(options)
	return ns.AddCoreProjection(
		options.projections,
		ns.VarietyProjectionDef(options.db, options.changed, options.added),
		options.iterate,
		"varieties"
	)
end

--- The variety projection's def (LOG-R70) over `db`: each live Catch that adds a variety, and each done, calls
--- `changed`; a live Cast's first-caught varieties go to `added` first, when given, with the Cast's ID.
---@param db table PagleDB.global.projections.varieties, or a table of the caller's making
---@param changed fun()
---@param added (fun(castId: string, ids: table<string, true>))?
---@return PagleProjectionDef
function ns.VarietyProjectionDef(db, changed, added)
	return {
		db = db,
		rulesVersion = ns.VARIETY_RULES_VERSION,
		reset = reset,
		apply = function(state, record, mode)
			local ids = count(state, record)
			if ids and mode == "live" then
				if added then
					added(record.id, ids)
				end
				changed()
			end
		end,
		done = function()
			changed()
		end,
	}
end

--- The positions of `speciesID` caught in a stored variety projection (`db.projection`), as a fresh set
--- `{ [index] = true }`: what `Pagle.GetVarietiesCaught` returns (VAR-R11). Empty for a Species with none caught, one
--- without varieties, and before a first build has finished. While a rebuild runs, the state it builds isn't stored
--- yet, so this reads the last stored one (LOG-R72).
---@param db table PagleDB.global.projections.varieties
---@param speciesID any
---@return table<integer, true>
function ns.VarietiesCaughtIn(db, speciesID)
	local copy = {}
	local stored = type(db) == "table" and db.projection
	local bySpecies = type(stored) == "table" and stored.bySpecies
	local caught = type(bySpecies) == "table" and bySpecies[speciesID]
	if type(caught) == "table" then
		for index in pairs(caught) do
			if type(index) == "number" then
				copy[index] = true
			end
		end
	end
	return copy
end
