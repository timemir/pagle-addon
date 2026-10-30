-- Standalone actual-addon producer/importer for the backend's authenticated manual Recovery journey.
-- Run from this repository with Lua 5.1; it deliberately needs no Busted, JSON library or fake projector.
-- --mode export --branch accepted|divergent --output /tmp/prefix [--log-id 16hex]
-- --mode export --source /tmp/source.snapshot.b64 --output /tmp/prefix
-- --mode apply --source /tmp/source.snapshot.b64 --package /tmp/Pagle_Recovery --output /tmp/prefix
-- --now <server time> runs current-addon startup at the backend journey's clock, retaining old Catch identities.
---@diagnostic disable-next-line: undefined-global -- this CI helper runs on stock Lua 5.1
local arguments = arg
local options = {}
for at = 1, #arguments, 2 do
	local key = assert(arguments[at]:match("^%-%-(.+)$"), "expected a named argument")
	options[key] = assert(arguments[at + 1], "missing argument value")
end
assert(options.mode == "export" or options.mode == "apply", "--mode export|apply is required")
local output = assert(options.output, "--output is required")
local serverTime = assert(tonumber(options.now or "1793100000"), "--now must be a server time")
---@diagnostic disable-next-line: undefined-global -- load the real TOC/fake client harness without invoking its Busted hook
assert(dofile("spec/support/addon.lua"))

local function write(suffix, bytes)
	---@diagnostic disable-next-line: undefined-global -- standalone CI writes only the explicit output prefix
	local file = assert(io.open(output .. suffix, "wb"))
	assert(file:write(bytes))
	assert(file:close())
end

local function fixture()
	local character = characterRecord()
	character.hardcore, character.selfFound = false, false
	character.firstSeen, character.lastSeen = 1791735000, 1791735023
	local entries = {
		"B1|1|1791735001|0|70338|1.60.1|pagle-2026a",
		"S1|1|1791735002|0|86|150|25",
		castEntry(1791735003, options.branch == "divergent" and 6303 or 6358),
	}
	if options.branch == "divergent" then
		entries[4] = castEntry(1791735023, 6358)
	end
	local log = savedLog(entries, 4, { character })
	log.logId = options["log-id"] or "9387f1ead054bc62"
	log.futureField = { retained = { "original unknown field" } }
	return log
end

local function savedLiteral(value, seen)
	local kind = type(value)
	if kind == "nil" then
		return "nil"
	end
	if kind == "string" then
		return string.format("%q", value)
	end
	if kind == "number" or kind == "boolean" then
		return tostring(value)
	end
	assert(kind == "table", "unsupported SavedVariables fixture value: " .. kind)
	seen = seen or {}
	assert(not seen[value], "cyclic SavedVariables fixture")
	seen[value] = true
	local keys, fields = {}, {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return type(a) .. tostring(a) < type(b) .. tostring(b)
	end)
	for _, key in ipairs(keys) do
		fields[#fields + 1] = "[" .. savedLiteral(key, seen) .. "]=" .. savedLiteral(value[key], seen) .. ","
	end
	seen[value] = nil
	return "{" .. table.concat(fields) .. "}"
end

local originalBytes, originalSaved
local loaded = loadAddon(
	"Pagle",
	foreverWith({
		GetServerTime = function()
			return serverTime
		end,
	}),
	{
		also = options.mode == "apply"
				and { "Pagle_Ledger", "Pagle_Hunts", "Pagle_TackleBoard", "Pagle_Stats", "Pagle_QoL" }
			or nil,
		beforeLoaded = {
			Pagle = function(ns, client, env)
				if options["saved-variables-source"] then
					-- Only a generated CI fixture is loaded, as the game loads its own SavedVariables.
					---@diagnostic disable-next-line: undefined-global -- trusted fixture, never backend input
					local readSaved = assert(loadfile(options["saved-variables-source"]))
					local saved = {}
					setfenv(readSaved, saved)
					readSaved()
					env.PagleLog, env.PagleRecovery = saved.PagleLog, saved.PagleRecovery
					originalBytes = ns.RecoverySnapshot(env.PagleLog)
					if options.source then
						assert(originalBytes == ns.Base64Decode(readFile(options.source):gsub("%s+", "")))
					end
				elseif options.source then
					originalBytes = assert(ns.Base64Decode(readFile(options.source):gsub("%s+", "")))
					env.PagleLog = ns.RecoveryReadSnapshot(originalBytes)
				else
					env.PagleLog = fixture()
					originalBytes = ns.RecoverySnapshot(env.PagleLog)
				end
				originalSaved = savedLiteral(env.PagleLog)
				if options.mode == "apply" then
					local package = assert(options.package, "--package is required")
					local toc = readFile(package .. "/Pagle_Recovery.toc")
					assert(toc:find("## LoadOnDemand: 1", 1, true), "Recovery must load on demand")
					assert(not toc:find("Dependencies", 1, true), "Recovery must not depend on Pagle")
					---@diagnostic disable-next-line: undefined-global -- only this CI helper adds the synthetic public key
					ns.PUSHED_KEYS.testKey = dofile("spec/Pagle/fixtures/Signing.lua").testKey
					client.addons.Pagle_Recovery = {
						loaded = false,
						load = function()
							assert(ns.db == nil, "Recovery must load before SavedVariables open")
							---@diagnostic disable-next-line: undefined-global -- execute the actual fixed data file downloaded in the ZIP
							local file = assert(loadfile(package .. "/Recovery.lua"))
							setfenv(file, env)
							file()
						end,
					}
				end
			end,
		},
	}
)
assert(not loaded.ns.recoveryBlocked, table.concat(loaded.printed, "\n"))
assert(#loaded.client.errors == 0, table.concat(loaded.client.errors, "\n"))
if options.mode == "apply" then
	local saved = assert(loaded.env.PagleRecovery)
	local completed = assert(saved.completed)
	local archive = assert(saved.archives[completed.applicationId])
	assert(loaded.ns.RecoverySnapshot(archive.original) == originalBytes, "archived source changed")
	assert(savedLiteral(archive.original) == originalSaved, "complete original branch changed")
	write(".application-id", completed.applicationId)
	write(".archive.snapshot", loaded.ns.RecoveryExport(archive.original))
	write(".replacement.snapshot", loaded.ns.RecoveryExport(loaded.env.PagleLog))
	local staged = {}
	for _, held in ipairs(archive.staged) do
		staged[#staged + 1] = held.seq .. "\t" .. held.reason .. "\t" .. logEntries(archive.original)[held.seq]
	end
	write(".staged", table.concat(staged, "\n"))
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD")
	loaded.client.advance(10)
	for _, name in ipairs({ "Pagle_Ledger", "Pagle_Hunts", "Pagle_TackleBoard", "Pagle_Stats" }) do
		assert(not loaded.namespaces[name].projection:IsUpdating(), name .. " has not rebuilt")
	end
end
loaded.env.SlashCmdList.PAGLE("recovery export")
local window = assert(loaded.ns.recoveryWindow)
local lines, encoded = {}, {}
repeat
	local line = window.paste:GetText()
	lines[#lines + 1] = line
	encoded[#encoded + 1] = assert(line:match("^PGLR1|%d+|%d+|(.+)$"))
	if window.part == #window.parts then
		break
	end
	window.next:Click()
until false
write(".snapshot", table.concat(lines, "\n"))
write(".snapshot.b64", table.concat(encoded))
loaded.env.SlashCmdList.PAGLE("export")
local pasteWindow = assert(loaded.ns.pasteExportWindow)
assert(not pasteWindow.view.pending, "small journey fixture should prepare synchronously")
local export = assert(pasteWindow.view.export)
for part = 1, #export.parts do
	write(".paste." .. part, pasteWindow.paste:GetText())
	write(".document." .. part, loaded.ns.PasteDocument(export, part))
	if part < #export.parts then
		pasteWindow.next:Click()
	end
end
write(".parts", tostring(#export.parts))
write(
	".saved-variables.lua",
	"PagleLog = "
		.. savedLiteral(loaded.env.PagleLog)
		.. "\nPagleRecovery = "
		.. savedLiteral(loaded.env.PagleRecovery)
		.. "\n"
)
assert(#loaded.client.errors == 0, table.concat(loaded.client.errors, "\n"))
print("actual addon " .. options.mode .. " complete; " .. loaded.env.PagleLog.count .. " entries; outputs " .. output)
