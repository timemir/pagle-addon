-- A test fixture, never shipped: hand-written Locales with made-up text, registered as a generated locale file will be.
-- Codes that are not a real client's (xxXX, xxYY, ...) stand for any language; esES is here for the esMX rule.
local ns = select(2, ...)

-- xxXX: a base language. Its plural rule has a "few" at 3; its separators are "," and ".".
ns.Locale("xxXX", function(L)
	L.TRAILER_CAPTION_CATCH = "[xx] catch"
	L.TRAILER_CAPTION_JOURNAL = "[xx] journal"
	L.LOG_UNREADABLE = "[xx] unreadable (%s)"
	L.SIZE_BANDS = { "Aa", "Bb", "Cc", "Dd", "Ee" }
	L.VARIETY_RARITIES = { "Va", "Vb", "Vc", "Vd" }
	L.FIXTURE_COUNTED = { few = "{count} fews", other = "{count} others" }
end, {
	name = "Xxxx",
	listed = true,
	plural = function(n)
		return n == 3 and "few" or "other"
	end,
	decimal = ",",
	thousands = ".",
})
-- A second registration for the same code adds a function and takes no opts (Lore registers this way).
ns.Locale("xxXX", function(L)
	L.TRAILER_CAPTION_NAME = "[xx] name"
end)

-- xxYY: falls back to xxXX, gives its own decimal separator only, and rewrites one of xxXX's strings.
ns.Locale("xxYY", function(L)
	L.TRAILER_CAPTION_CATCH = "[yy] catch"
	L.LOG_UNREADABLE = "[yy] unreadable (%s)"
end, { name = "Yyyy", listed = true, fallback = "xxXX", decimal = "'" })

-- xxZZ: complete, but not listed.
ns.Locale("xxZZ", function(L)
	L.TRAILER_CAPTION_CATCH = "[zz] catch"
	L.LOG_UNREADABLE = "[zz] unreadable (%s)"
end, {
	name = "Zzzz",
	listed = false,
	plural = function()
		return "other"
	end,
	decimal = ",",
	thousands = ".",
})

-- xxFB: falls back to a Locale that is not registered and gives no plural rule, so its chain is never whole.
ns.Locale("xxFB", function(L)
	L.TRAILER_CAPTION_CATCH = "[fb] catch"
end, { name = "Fbfb", listed = true, fallback = "xxNone", decimal = "," })

-- xxER: its first function raises; its second still runs.
ns.Locale("xxER", function()
	error("fixture: this Locale's first function raises")
end, {
	name = "Erer",
	listed = true,
	plural = function()
		return "other"
	end,
	decimal = ",",
	thousands = ".",
})
ns.Locale("xxER", function(L)
	L.TRAILER_CAPTION_CATCH = "[er] catch"
end)

-- esES, as the real one will register it, with made-up text.
ns.Locale("esES", function(L)
	L.TRAILER_CAPTION_CATCH = "[es] catch"
	L.TRAILER_CAPTION_JOURNAL = "[es] journal"
end, {
	name = "Espanol",
	listed = true,
	plural = function(n)
		return n == 1 and "one" or "other"
	end,
	decimal = ",",
	thousands = ".",
})
