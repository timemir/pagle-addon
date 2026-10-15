---@class PagleNS
local ns = select(2, ...)

-- The projection machinery (LOG-R70–R78, ADR 0004): pure logic, fed the Catch log's records, a clock and a frame
-- scheduler (CORE-R7). Every Module's stored projection, and Core's own, runs through one machinery: it catches up
-- or rebuilds each one after login, hands it every new entry live, and tells Core's other parts whether any is
-- updating, which mode the apply in progress has, and when none is updating any more.

--- Catch-up or rebuild with more pending entries than this runs in chunks across frames, else at once (Tunables).
ns.PROJECTION_SYNC_LIMIT = 500
--- The time a chunked catch-up or rebuild may take per frame, in ms, shared by every projection (Tunables).
ns.PROJECTION_BUDGET = 4

--- What a Module passes to `M:NewProjection` (catch-log.md › Projection definition).
---@class PagleProjectionDef
---@field db table                   -- a table in the Module's SavedVariables, owned by Core from here on
---@field rulesVersion integer
---@field extraFingerprint? string   -- Hunts: its own list fingerprint
---@field reset fun(): table         -- a fresh, empty state
---@field apply fun(state: table, record: PagleRecord, mode: PagleApplyMode)
---@field done? fun(state: table, info: PagleProjectionInfo)

--- How an entry reaches a projection (LOG-R75): `"live"` just recorded (may raise moments), `"replay"` a catch-up
--- entry, `"rebuild"` a rebuild entry (neither raises moments).
---@alias PagleApplyMode "live"|"replay"|"rebuild"

--- What `def.done` learns about the catch-up or rebuild that finished (LOG-R76).
---@class PagleProjectionInfo
---@field firstBuild boolean   -- never built (or its DB lost), and at least one Cast was applied
---@field rebuilt boolean      -- it was a rebuild
---@field replayed integer     -- entries applied in "replay" mode

--- What the machinery is fed. Every function is called when needed, never stored.
---@class PagleProjectionsOptions
---@field length fun(): integer          -- the Catch log's length now
---@field logId fun(): string?           -- PagleLog.logId
---@field fingerprint fun(): string?     -- Pagle.CONTENT_FINGERPRINT
---@field clock fun(): number            -- a clock in ms (debugprofilestop)
---@field nextFrame fun(step: fun())     -- runs `step` on the next frame
---@field call fun(fn: function, ...: any): ... -- calls a Module's function; an error is reported, not raised (securecallfunction)
---@field budget? number                 -- ms per frame; default PROJECTION_BUDGET
---@field syncLimit? integer             -- default PROJECTION_SYNC_LIMIT

--- A projection, as `M:NewProjection` returns it (LOG-R70).
---@class PagleProjection
---@field package def PagleProjectionDef
---@field package iterate fun(afterSeq: integer): fun(): PagleRecord?
---@field package module string?      -- the Module whose records it gets (LOG-R41); nil for Core's own
---@field package machinery PagleProjections
---@field package state table?         -- the state apply builds
---@field package updating boolean     -- not caught up: before Start, and while catching up or rebuilding
---@field package run PagleProjectionRun? -- the catch-up or rebuild in progress
local Projection = {}
Projection.__index = Projection

--- A catch-up or rebuild in progress. It runs in steps: each entry up to the target, then the finish (the stored
--- values and done), then each entry appended since the target, applied as live.
---@class PagleProjectionRun
---@field mode "replay"|"rebuild"
---@field target integer               -- the last seq it applies; later entries are live
---@field fresh boolean                -- never built, or the Module's DB lost, when it started
---@field next fun(): PagleRecord?     -- the next record after the last one applied
---@field replayed integer
---@field casts integer                -- Casts applied in "rebuild" mode
---@field phase "apply"|"finish"|"live" -- the step it is on
---@field live (fun(): PagleRecord?)?  -- after the finish: the entries appended since the target, once read
---@field liveTo integer               -- the log's length when `live` was made
---@field inDone boolean?              -- while its done runs

--- The machinery: every projection, in the order they were added.
---@class PagleProjections
---@field package options PagleProjectionsOptions
---@field package list PagleProjection[]
---@field package loginSeq integer?    -- set by Start
---@field package mode (PagleApplyMode|"done")?
---@field package deferred PagleRecord[] -- live entries handed over while an apply or done ran
---@field package chunked PagleProjection[] -- running in chunks across frames
---@field package stepping boolean     -- a frame step is scheduled
---@field package idle fun()[]         -- WhenIdle hooks waiting
local Projections = {}
Projections.__index = Projections

---@param options PagleProjectionsOptions
---@return PagleProjections
function ns.NewProjections(options)
	return setmetatable({
		options = options,
		list = {},
		deferred = {},
		chunked = {},
		stepping = false,
		idle = {},
	}, Projections)
end

-- Why a def can't make a projection, or nil if it can (Projection definition).
---@param def any
---@return string?
local function problemWith(def)
	if type(def) ~= "table" then
		return "NewProjection takes a def table, got " .. type(def)
	end
	if type(def.db) ~= "table" then
		return "NewProjection: def.db must be a table in the Module's SavedVariables"
	end
	if type(def.rulesVersion) ~= "number" then
		return "NewProjection: def.rulesVersion must be an integer"
	end
	if type(def.reset) ~= "function" or type(def.apply) ~= "function" then
		return "NewProjection: def.reset and def.apply must be functions"
	end
	if def.done ~= nil and type(def.done) ~= "function" then
		return "NewProjection: def.done must be a function or nil"
	end
	if def.extraFingerprint ~= nil and type(def.extraFingerprint) ~= "string" then
		return "NewProjection: def.extraFingerprint must be a string or nil"
	end
	return nil
end

--- Binds a projection to `def.db` (LOG-R70). It counts as updating until its first catch-up or rebuild finishes,
--- which starts at `Start`, or at once when added after it. Returns nil and why for a def the contract refuses.
--- It gets the Module records of `module` only, which `iterate` yields too (LOG-R41); others pass it by.
---@param def PagleProjectionDef
---@param iterate fun(afterSeq: integer): fun(): PagleRecord? the Module's records after a seq (M:IterateCatches)
---@param module string? the Module's def.name; nil for Core's own projections, which get no Module records
---@return PagleProjection? projection
---@return string? problem
function Projections:Add(def, iterate, module)
	local problem = problemWith(def)
	if problem then
		return nil, problem
	end
	local db = def.db
	local projection = setmetatable({
		def = def,
		iterate = iterate,
		module = module,
		machinery = self,
		state = type(db.projection) == "table" and db.projection or nil,
		updating = true,
	}, Projection)
	self.list[#self.list + 1] = projection
	if self.loginSeq then
		self:begin(projection, self.loginSeq, false)
		self:settle()
	end
	return projection
end

-- The fingerprint a projection stores: the content fingerprint, plus its own if it has one (LOG-R70).
---@param machinery PagleProjections
---@param def PagleProjectionDef
---@return string
local function fingerprintOf(machinery, def)
	local content = tostring(machinery.options.fingerprint())
	return def.extraFingerprint and (content .. "+" .. def.extraFingerprint) or content
end

-- Whether a stored projection must be rebuilt from seq 0 (LOG-R72; DATA-R71 for the fingerprint).
---@param machinery PagleProjections
---@param def PagleProjectionDef
---@return boolean
local function mustRebuild(machinery, def)
	local db = def.db
	return type(db.projection) ~= "table"
		or type(db.lastSeq) ~= "number"
		or db.logId ~= machinery.options.logId()
		or db.lastSeq > machinery.options.length()
		or db.fingerprint ~= fingerprintOf(machinery, def)
		or db.rulesVersion ~= def.rulesVersion
end

-- Runs `fn` with `mode` as the mode in progress (Mode). Live entries handed over meanwhile wait for settle.
---@param machinery PagleProjections
---@param mode PagleApplyMode|"done"
---@param fn fun()
local function during(machinery, mode, fn)
	local outer = machinery.mode
	machinery.mode = mode
	fn()
	machinery.mode = outer
end

-- Applies one record to a projection in `mode`, through the Module-calling function so an error is reported and the
-- next entry still runs.
---@param projection PagleProjection
---@param record PagleRecord
---@param mode PagleApplyMode
---@param run PagleProjectionRun? the catch-up or rebuild it belongs to; nil for a live entry
local function applyOne(projection, record, mode, run)
	local machinery = projection.machinery
	during(machinery, mode, function()
		machinery.options.call(projection.def.apply, projection.state, record, mode)
	end)
	if not run then
		projection.def.db.lastSeq = record.seq
	elseif mode == "replay" then
		-- A catch-up changes the stored state in place, so lastSeq follows each entry: one cut short resumes there.
		projection.def.db.lastSeq = record.seq
		run.replayed = run.replayed + 1
	elseif record.kind == "cast" then
		run.casts = run.casts + 1
	end
end

-- Starts a projection's catch-up or rebuild up to `target` (LOG-R71, LOG-R72): at once when few entries are
-- pending, else in chunks on later frames.
---@package
---@param projection PagleProjection
---@param target integer
---@param force boolean rebuild whatever the stored values say (Rebuild)
function Projections:begin(projection, target, force)
	local def = projection.def
	local db = def.db
	local rebuild = force or mustRebuild(self, def)
	local from = rebuild and 0 or db.lastSeq
	projection.updating = true
	projection.run = {
		mode = rebuild and "rebuild" or "replay",
		target = target,
		-- Never built, or the Module's DB lost (LOG-R76, LOG-R77). A rebuild cut short leaves this as it was.
		fresh = type(db.projection) ~= "table",
		next = projection.iterate(from),
		replayed = 0,
		casts = 0,
		phase = "apply",
		liveTo = 0,
	}
	if rebuild then
		projection.state = self.options.call(def.reset) or {}
	end
	if target - from > (self.options.syncLimit or ns.PROJECTION_SYNC_LIMIT) then
		self.chunked[#self.chunked + 1] = projection
		self:schedule()
	else
		local run = projection.run
		while projection.run == run and self:advance(projection) do
		end
	end
end

-- Takes the next step of a projection's run (PagleProjectionRun). Returns false once the run is over.
---@package
---@param projection PagleProjection
---@return boolean
function Projections:advance(projection)
	local run = projection.run
	if not run then
		return false
	end
	if run.phase == "apply" then
		local record = run.next()
		if record == nil or record.seq > run.target then
			run.phase = "finish"
		else
			applyOne(projection, record, run.mode, run)
		end
	elseif run.phase == "finish" then
		self:finish(projection, run)
	else
		-- Every entry after the target is live, never replayed (LOG-R1). Live passes this projection over until the
		-- run is over, so entries appended meanwhile are read back here too. Reading from a seq looks back to its
		-- Session's first Cast (LOG-R98), so the first read is a step of its own.
		local live = run.live
		if not live then
			run.live, run.liveTo = projection.iterate(projection.def.db.lastSeq), self.options.length()
			return true
		end
		local record = live()
		if record == nil and self.options.length() > run.liveTo then
			run.live, run.liveTo = projection.iterate(run.liveTo), self.options.length()
			return true
		end
		if record == nil then
			-- Read to the log's end: another Module's records it passed by count as reached (LOG-R41).
			projection.def.db.lastSeq = math.max(projection.def.db.lastSeq, run.liveTo)
			projection.run = nil
			return false
		end
		applyOne(projection, record, "live")
	end
	return true
end

-- Ends a catch-up or rebuild (LOG-R72, LOG-R74, LOG-R76): writes the stored values (a rebuild's only now) and calls
-- done. The entries appended since its target follow as live, in order, in the run's next steps.
---@package
---@param projection PagleProjection
---@param run PagleProjectionRun
function Projections:finish(projection, run)
	local def = projection.def
	local db = def.db
	db.projection = projection.state
	if run.mode == "rebuild" or db.lastSeq < run.target then
		db.lastSeq = run.target
	end
	db.logId = self.options.logId()
	db.fingerprint = fingerprintOf(self, def)
	db.rulesVersion = def.rulesVersion
	projection.updating = false
	run.phase = "live"
	if def.done then
		local info = {
			firstBuild = run.fresh and run.casts > 0,
			rebuilt = run.mode == "rebuild",
			replayed = run.replayed,
		}
		run.inDone = true
		during(self, "done", function()
			self.options.call(def.done, projection.state, info)
		end)
		run.inDone = nil
	end
end

-- Schedules the next frame's chunk, once.
---@package
function Projections:schedule()
	if not self.stepping then
		self.stepping = true
		self.options.nextFrame(function()
			self.stepping = false
			self:step()
		end)
	end
end

-- One frame's chunk: works through the chunked projections in order within the budget (LOG-R71, LOG-R72). The clock
-- is read after each step, and the chunk stops once the budget left can't fit another step as costly as this
-- frame's costliest, so a frame doesn't run past the budget on its last step. A finish runs a Module's done, whose
-- cost nothing predicts, so it starts a frame of its own. At least one step runs each frame.
---@package
function Projections:step()
	local clock, budget = self.options.clock, self.options.budget or ns.PROJECTION_BUDGET
	local started, costliest, stepped = clock(), 0, false
	while #self.chunked > 0 do
		local projection = self.chunked[1]
		if stepped and projection.run and projection.run.phase == "finish" then
			break
		end
		stepped = true
		local before = clock()
		if not self:advance(projection) then
			table.remove(self.chunked, 1)
		end
		local now = clock()
		costliest = math.max(costliest, now - before)
		if now - started + costliest > budget then
			break
		end
	end
	if #self.chunked > 0 then
		self:schedule()
	end
	self:settle()
end

-- Hands over the live entries deferred during an apply or done, then runs the WhenIdle hooks if none is updating.
---@package
function Projections:settle()
	if self.mode then
		return
	end
	while #self.deferred > 0 do
		self:Live(table.remove(self.deferred, 1))
	end
	while not self:IsUpdating() and #self.idle > 0 do
		self.options.call(table.remove(self.idle, 1))
	end
end

--- Login step 3 (LOG-R1): starts every projection's catch-up or rebuild, up to `loginSeq` (LOG-R71, LOG-R72).
--- Entries after it reach them as live. Projections added later start at once.
---@param loginSeq integer the log's length at load
function Projections:Start(loginSeq)
	if self.loginSeq then
		return
	end
	self.loginSeq = loginSeq
	for _, projection in ipairs(self.list) do
		self:begin(projection, loginSeq, false)
	end
	self:settle()
end

--- Hands a just-appended entry to every projection (LOG-R73, LOG-R74): one that is up to date applies it as
--- `"live"` now and sets `lastSeq`; one that is updating, or still applying the entries appended during its update,
--- reads it back from the log as `"live"` when it gets there. A Module record goes only to its Module's projections;
--- every other one that is up to date just moves `lastSeq` past it (LOG-R41).
--- Called from inside an apply or a done, it is handed over when that returns (LOG-R40).
---@param record PagleRecord
function Projections:Live(record)
	if self.mode then
		self.deferred[#self.deferred + 1] = record
		return
	end
	local owner = record.kind == "module" and (record --[[@as PagleModuleRecord]]).module or nil
	for _, projection in ipairs(self.list) do
		if not projection.run and not projection.updating and record.seq > projection.def.db.lastSeq then
			if owner and owner ~= projection.module then
				projection.def.db.lastSeq = record.seq
			else
				applyOne(projection, record, "live")
			end
		end
	end
	self:settle()
end

--- Whether any projection is updating (LOG-R74), counting the time before `Start`, when none has caught up yet,
--- and the time a finished one takes to apply the entries appended during its update.
---@return boolean
function Projections:IsUpdating()
	if not self.loginSeq then
		return true
	end
	for _, projection in ipairs(self.list) do
		if projection.updating or projection.run then
			return true
		end
	end
	return false
end

--- The mode of the apply in progress (LOG-R75), `"done"` while a projection's done runs, or nil: how Core drops
--- moments raised during a replay or rebuild (ANN-R4).
---@return (PagleApplyMode|"done")?
function Projections:Mode()
	return self.mode
end

--- Runs `fn` once no projection is updating (LOG-R63, ANN-R10, ANN-R61): now if none is, else right after the last
--- one finishes, after its done and the live entries queued behind it. Hooks run in the order they were added.
---@param fn fun()
function Projections:WhenIdle(fn)
	self.idle[#self.idle + 1] = fn
	self:settle()
end

--- Puts `M:NewProjection` and `M:IterateCatches` on every Module handle, over `projections` (LOG-R42, LOG-R70), so
--- Core's adapter and FakePagle publish the same methods.
---@param registry PagleModuleRegistry
---@param projections PagleProjections
---@param iterate fun(afterSeq: integer?, module: string?): fun(): PagleRecord? the log's records after a seq, with
--- the Module records of `module` (PagleHost.iterate)
function ns.AddProjectionMethods(registry, projections, iterate)
	---@class PagleModuleHandle
	local ModuleHandle = ns.ModuleHandle

	--- Walks the log's records with `seq > afterSeq` (0 if nil), up to its length now, in order (LOG-R42): what
	--- `Pagle.IterateCatches` yields, plus this Module's own Module records, never another Module's (LOG-R41).
	---@param afterSeq integer?
	---@return fun(): PagleRecord?
	function ModuleHandle:IterateCatches(afterSeq)
		local module = registry:ModuleCalling(self, "IterateCatches", "afterSeq")
		return iterate(afterSeq, module.def.name)
	end

	--- Binds a projection to `def.db`, a table in the Module's SavedVariables that Core owns from now on (LOG-R70).
	--- Core catches it up or rebuilds it after login and hands it each new entry live (LOG-R71–R76). Raises an
	--- error, binding nothing, for a def the contract refuses.
	---@param def PagleProjectionDef
	---@return PagleProjection
	function ModuleHandle:NewProjection(def)
		local module = registry:ModuleCalling(self, "NewProjection", "def")
		local projection, problem = projections:Add(def, function(afterSeq)
			return self:IterateCatches(afterSeq)
		end, module.def.name)
		if not projection then
			error(problem, 2)
		end
		return projection
	end
end

--- Binds one of Core's own projections (LOG-R78) to a table in PagleDB: the same machinery as a Module's, with no
--- Module handle and no moments. Core adds its own at login step 1, before any Module's OnInitialize, so they run
--- first and the Modules' keep their order. Raises an error at the caller, binding nothing, for a def the contract
--- refuses.
---@param projections PagleProjections
---@param def PagleProjectionDef
---@param iterate fun(afterSeq: integer?): fun(): PagleRecord? the log's records after a seq (Pagle.IterateCatches)
---@return PagleProjection
function ns.AddCoreProjection(projections, def, iterate)
	local projection, problem = projections:Add(def, iterate)
	if not projection then
		error(problem, 2)
	end
	return projection
end

--- The state `apply` builds (LOG-R70): the stored projection, a rebuild's fresh one while it runs, or nil before a
--- first build starts.
---@return table?
function Projection:GetState()
	return self.state
end

--- Whether it is catching up or rebuilding, or waiting for login to start it (LOG-R74), counting the time after its
--- done until the entries appended during the update have been applied as live: a Module that appends from a step
--- scheduled at done sees its own records applied before it reads the state. Its own done reads false.
---@return boolean
function Projection:IsUpdating()
	local run = self.run
	return self.updating or (run ~= nil and not run.inDone)
end

--- A manual full rebuild from seq 0 up to the log's length now (LOG-R72), for a debug command. Does nothing while
--- it is updating.
function Projection:Rebuild()
	local machinery = self.machinery
	if self.updating or not machinery.loginSeq then
		return
	end
	machinery:begin(self, machinery.options.length(), true)
	machinery:settle()
end
