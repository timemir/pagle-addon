-- Core's string table (CORE-R8). Every user-facing string goes through ns.L; enUS only in 1.0.

---@class PagleNS
local ns = select(2, ...)

---@class PagleStrings
ns.L = {
	-- LOG-R18: PagleLog was in another format, so Core started a new log.
	LOG_FORMAT_CHANGED = "Pagle: dev log format changed; started a new log.",
	NOT_FOREVER = "Pagle: this isn't World of Warcraft: Forever, so Pagle stays off.",
}
