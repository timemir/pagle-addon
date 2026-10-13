-- securecallfunction as the client runs it (Gethe/wow-ui-source branch forever at
-- 943764493e6b16d63ded3ab304150d1f05e58b57, "1.60.1 (70338)"): the function runs protected; an error goes to the
-- error handler of the time, and the caller carries on with no results. The fake client's stubs
-- and FakePagle (spec/support/fake_pagle.lua) both build theirs here, so they agree.
--
--   local securecall = newSecureCall(function() return geterrorhandler() end)

--- A securecallfunction whose errors go to `handler()`, read at each error.
---@param handler fun(): fun(err: any)
---@return fun(fn: function, ...: any): ...
return function(handler)
	return function(fn, ...)
		local results = { pcall(fn, ...) }
		if not results[1] then
			handler()(results[2])
			return
		end
		return unpack(results, 2, table.maxn(results))
	end
end
