---@class PagleNS
local ns = select(2, ...)

-- `/pagle dev tour` (CORE-R65–R68): a screenshot tour of every surface Pagle draws, for judging a redesign. Core's own
-- surfaces and each Module's register tour stops, a show and a hide each; the tour shows them one by one, takes a
-- screenshot of each and hides it again. Pure logic over what it's handed (CORE-R7); logic/Wiring.lua's ns.WireDev
-- builds Core's one registry and tour, so Core's adapter and FakePagle run the same tour.

--- The name Core's own stops go under: what `/pagle dev tour core` names, and the first part of each one's name.
ns.TOUR_CORE = "core"

--- Seconds a stop shows before its screenshot, so its frames draw and its animations settle (CORE-R66): after a
--- toast's motion settles at 2.66 s (announcements.md › Motion), before a Nod leaves at 3 s (ANN-R20).
ns.TOUR_SHOW_SECONDS = 2.8
--- Seconds from the screenshot to the hide: Screenshot() saves a frame drawn after the call.
ns.TOUR_SHOT_SECONDS = 0.5
--- Seconds the dev has to press Print Screen at each stop, on a client with no Screenshot() (CORE-R66).
ns.TOUR_MANUAL_SECONDS = 4
--- Seconds from one stop's hide to the next one's show, so the hide has drawn.
ns.TOUR_GAP_SECONDS = 0.3

--- One tour stop (CORE-R65).
---@class PagleTourStop
---@field module string -- "core", or the Module's def.name lowercased
---@field name string   -- "<module>.<id>", as the tour's chat lines name it: "ledger.journal.home"
---@field label string  -- what it shows, for `/pagle dev tour list`
---@field show fun()    -- puts the surface on screen, in a representative state
---@field hide fun()    -- puts back everything show changed

--- Every tour stop, by Module, each Module's in the order registered (CORE-R65).
---@class PagleTourStops
---@field package stops table<string, PagleTourStop[]> -- by module
---@field package names table<string, true>            -- every stop's name
local Stops = {}
Stops.__index = Stops

---@return PagleTourStops
function ns.NewTourStops()
	return setmetatable({ stops = {}, names = {} }, Stops)
end

--- Adds a stop for `module` ("core", or a Module's def.name lowercased). Returns why it can't, adding nothing: an ID
--- that isn't [%w_.]+, one the module registered before, no label, or a show or hide that isn't a function. The
--- reason names the stop's owner: `owner`, or Core for "core".
---@param module string
---@param id any
---@param label any
---@param show any
---@param hide any
---@param owner string? the Module's def.name
---@return string? problem
function Stops:Add(module, id, label, show, hide, owner)
	owner = owner or "Core"
	local name = module .. "." .. tostring(id)
	if type(id) ~= "string" or not id:match("^[%w_.]+$") then
		return ("%s's tour stop ID %s isn't [%%w_.]+"):format(owner, tostring(id))
	elseif self.names[name] then
		return ("%s's tour stop %s is already registered"):format(owner, id)
	elseif type(label) ~= "string" or label == "" then
		return ("%s's tour stop %s has no label"):format(owner, id)
	elseif type(show) ~= "function" or type(hide) ~= "function" then
		return ("%s's tour stop %s needs a show and a hide function"):format(owner, id)
	end
	self.names[name] = true
	local list = self.stops[module] or {}
	self.stops[module] = list
	list[#list + 1] = { module = module, name = name, label = label, show = show, hide = hide }
	return nil
end

--- The stops a tour runs (CORE-R66): Core's first, then each Module's by def.order (ties by name), each Module's in
--- the order registered; only `module`'s when given ("core" or a def.name, any case).
---@param modules PagleModule[] the registered Modules, as `registry:Modules()` lists them
---@param module string?
---@return PagleTourStop[]
function Stops:List(modules, module)
	local order = { ns.TOUR_CORE }
	for _, registered in ipairs(modules) do
		order[#order + 1] = registered.def.name:lower()
	end
	local wanted = module and module:lower()
	local list = {}
	for _, name in ipairs(order) do
		if not wanted or wanted == name then
			for _, stop in ipairs(self.stops[name] or {}) do
				list[#list + 1] = stop
			end
		end
	end
	return list
end

--- The names of the Modules with stops, "core" first, in tour order.
---@param modules PagleModule[]
---@return string[]
function Stops:Modules(modules)
	local names, seen = {}, {}
	for _, stop in ipairs(self:List(modules)) do
		if not seen[stop.module] then
			seen[stop.module] = true
			names[#names + 1] = stop.module
		end
	end
	return names
end

--- `M:RegisterTourStop(id, label, show, hide)` over `stops` (CORE-R65): adds a stop under the calling Module's name,
--- lowercased, or raises an error at the Module's call, adding nothing, for each mistake Stops:Add lists.
---@param registry PagleModuleRegistry
---@param stops PagleTourStops
---@return fun(self: PagleModuleHandle, id: string, label: string, show: fun(), hide: fun())
function ns.RegisterTourStopMethod(registry, stops)
	return function(self, id, label, show, hide)
		local module = registry:ModuleCalling(self, "RegisterTourStop", "id, label, show, hide")
		local problem = stops:Add(module.def.name:lower(), id, label, show, hide, module.def.name)
		if problem then
			error(problem, 2)
		end
	end
end

--- What the tour reads from where Core runs, beyond the host: Core's adapter passes the client's, FakePagle its fakes.
---@class PagleTourSeams
---@field isRestricted fun(): boolean  -- Pagle.IsRestricted() (CORE-R30)
---@field canScreenshot fun(): boolean -- the client has Screenshot()
---@field screenshot fun()             -- Screenshot()
---@field clock fun(): string          -- the local time, "14:03:22", as the client names screenshot files by it

--- What the tour is fed. Every function is called when needed, never stored.
---@class PagleTourOptions
---@field stops PagleTourStops
---@field modules fun(): PagleModule[]       -- the registered Modules, by def.order (registry:Modules())
---@field isRestricted fun(): boolean        -- Pagle.IsRestricted() (CORE-R30)
---@field canScreenshot fun(): boolean       -- the client has Screenshot()
---@field screenshot fun()                   -- saves a screenshot (Screenshot())
---@field after fun(seconds: number, fn: fun()) -- runs fn `seconds` from now (C_Timer.After)
---@field call fun(fn: function, ...: any): ... -- calls fn; an error is reported, not raised (securecallfunction)
---@field clock fun(): string               -- the local time, as screenshot files are named by it: "14:03:22"
---@field print fun(line: string)

-- A tour under way: its stops, the one on screen and whether `tour stop` asked it to end.
---@class PagleTourRun
---@field stops PagleTourStop[]
---@field index integer
---@field stopping boolean
---@field shoot boolean -- the client takes the screenshots; otherwise the dev presses Print Screen

--- The tour (CORE-R66–R68).
---@class PagleTour
---@field package options PagleTourOptions
---@field package run PagleTourRun? -- the tour under way, if one is
local Tour = {}
Tour.__index = Tour

---@param options PagleTourOptions
---@return PagleTour
function ns.NewTour(options)
	return setmetatable({ options = options }, Tour)
end

--- Whether a tour is under way (CORE-R66): what its stops open isn't the Angler's doing (CORE-R68).
---@return boolean
function Tour:IsRunning()
	return self.run ~= nil
end

-- "1 stop", "2 stops".
---@param n integer
---@return string
local function count(n)
	return n == 1 and ns.L.DEV_TOUR_ONE_STOP or ns.L.DEV_TOUR_STOPS:format(n)
end

-- Ends the tour: done, ended by `tour stop`, or by a restriction.
---@param tour PagleTour
---@param why "done"|"stopped"|"restricted"
local function finish(tour, why)
	local L, options, run = ns.L, tour.options, tour.run --[[@as PagleTourRun]]
	tour.run = nil
	if why == "done" then
		options.print(L.DEV_TOUR_DONE:format(options.clock()))
	elseif why == "stopped" then
		options.print(L.DEV_TOUR_STOPPED:format(run.index, #run.stops))
	else
		options.print(L.DEV_TOUR_RESTRICTED_STOPPED:format(run.index, #run.stops))
	end
end

-- Shows the next stop: its line, its show, and SHOW_SECONDS later its screenshot, then its hide and the stop after.
-- A restriction or `tour stop` meanwhile skips the screenshot and ends the tour once the stop has hidden.
---@param tour PagleTour
local function nextStop(tour)
	local options, run = tour.options, tour.run --[[@as PagleTourRun]]
	run.index = run.index + 1
	local stop = run.stops[run.index]
	if not stop then
		finish(tour, "done")
		return
	end
	options.print(ns.L.DEV_TOUR_STOP:format(run.index, #run.stops, stop.name))
	options.call(stop.show)
	options.after(ns.TOUR_SHOW_SECONDS, function()
		local ending = run.stopping and "stopped" or options.isRestricted() and "restricted" or nil
		local wait = 0
		if not ending then
			if run.shoot then
				options.call(options.screenshot)
				wait = ns.TOUR_SHOT_SECONDS
			else
				wait = ns.TOUR_MANUAL_SECONDS
			end
		end
		options.after(wait, function()
			options.call(stop.hide)
			if ending then
				finish(tour, ending)
				return
			end
			options.after(ns.TOUR_GAP_SECONDS, function()
				nextStop(tour)
			end)
		end)
	end)
end

-- `/pagle dev tour [module]`: every stop, or one Module's, unless restricted or a tour is under way (CORE-R66,
-- CORE-R67).
---@param tour PagleTour
---@param module string? nil for every stop
local function start(tour, module)
	local L, options = ns.L, tour.options
	if tour.run then
		options.print(L.DEV_TOUR_RUNNING)
		return
	elseif options.isRestricted() then
		options.print(L.DEV_TOUR_RESTRICTED)
		return
	end
	local modules = options.modules()
	local stops = options.stops:List(modules, module)
	if #stops == 0 then
		local known = table.concat(options.stops:Modules(modules), ", ")
		options.print(module and L.DEV_TOUR_NO_STOPS_FOR:format(module:lower(), known) or L.DEV_TOUR_NO_STOPS)
		return
	end
	local shoot = options.canScreenshot()
	tour.run = { stops = stops, index = 0, stopping = false, shoot = shoot }
	local from = (shoot and L.DEV_TOUR_START or L.DEV_TOUR_START_MANUAL)
	options.print(from:format(count(#stops), options.clock()))
	nextStop(tour)
end

-- `/pagle dev tour list [module]`: each stop's name and label, in tour order (CORE-R68).
---@param tour PagleTour
---@param module string? nil for every stop
local function list(tour, module)
	local L, options = ns.L, tour.options
	local stops = options.stops:List(options.modules(), module)
	options.print(#stops == 1 and L.DEV_TOUR_LIST_ONE or L.DEV_TOUR_LIST:format(#stops))
	for _, stop in ipairs(stops) do
		options.print(L.DEV_TOUR_LIST_LINE:format(stop.name, stop.label))
	end
end

--- Runs `/pagle dev tour <args>` (CORE-R66–R68): `list [module]`, `stop`, or a tour of every stop or one Module's.
---@param args string what follows `/pagle dev tour`
function Tour:Run(args)
	local name, rest = ns.ParseSlash(args)
	if name == "list" then
		list(self, rest ~= "" and rest or nil)
	elseif name == "stop" then
		if self.run then
			self.run.stopping = true
			self.options.print(ns.L.DEV_TOUR_STOPPING)
		else
			self.options.print(ns.L.DEV_TOUR_NOT_RUNNING)
		end
	else
		start(self, name ~= "" and name or nil)
	end
end
