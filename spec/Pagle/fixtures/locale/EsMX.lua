-- A test fixture, never shipped: a separate esMX, which overlays esES for the strings that differ and takes the rest of
-- its record from it.
local ns = select(2, ...)

ns.Locale("esMX", function(L)
	L.TRAILER_CAPTION_CATCH = "[mx] catch"
end, { name = "Espanol (Mexico)", listed = true, fallback = "esES", decimal = "." })
