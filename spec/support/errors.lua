-- Errors a spec has to look at. The fake client's default error handler and FakePagle's report keep each error they
-- get in a list instead of raising it: an error raised inside an error handler (AceAddon's xpcall around
-- OnInitialize) only becomes "error in error handling" and disappears. At the end of each spec, busted's helper
-- (spec/support/addon.lua) fails it if any list it made got an error and the spec never read that list, so an
-- unexpected error still fails the spec, and a spec that expects one asserts it as before.
--
--   local add = watchErrors(client, "errors")  -- client.errors is the list; reading it counts as asserting it
--   add("boom")

local lists = {} -- every list made since the current spec started

local errors = {}

--- Puts a fresh error list at `owner[key]` and returns what adds to it. Reading `owner[key]` marks the list as
--- asserted. `owner` must have no metatable and no `key` of its own.
---@param owner table
---@param key string
---@return fun(err: any)
function errors.watch(owner, key)
	assert(getmetatable(owner) == nil and rawget(owner, key) == nil, "watchErrors: owner already has " .. key)
	local list = { errors = {}, read = false }
	lists[#lists + 1] = list
	setmetatable(owner, {
		__index = function(_, name)
			if name == key then
				list.read = true
				return list.errors
			end
		end,
	})
	return function(err)
		list.errors[#list.errors + 1] = tostring(err)
	end
end

--- The errors the spec just run got and never read, in order, and starts afresh for the next spec.
---@return string[]
function errors.unasserted()
	local unread = {}
	for _, list in ipairs(lists) do
		if not list.read then
			for _, err in ipairs(list.errors) do
				unread[#unread + 1] = err
			end
		end
	end
	lists = {}
	return unread
end

return errors
