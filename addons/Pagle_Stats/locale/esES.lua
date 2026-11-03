if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

if not GetLocale or GetLocale() ~= "esES" then
	return
end

-- Stats' Spanish (Spain) strings, laid over enUS.lua's.
local ns = select(2, ...)
local L = ns.L

L.TITLE = "Estadísticas"
-- EN: Stats
L.BOOK = "Estadísticas"
-- EN: Stats
L.BOOK_SLASH_HELP = "Abre o cierra el libro de Estadísticas."
-- EN: Open or close the Stats book.

L.BOOK_ROOT = "Estadísticas"
-- EN: Stats
L.BOOK_WHERE_I_AM = "Dónde estoy"
-- EN: Where I am
L.BOOK_THIS_SESSION = "Esta Sesión"
-- EN: This Session
L.BOOK_LAST_SESSION = "Mi última Sesión"
-- EN: My last Session
L.BOOK_LIFETIME = "Historial"
-- EN: Lifetime
L.BOOK_SESSIONS = "Sesiones"
-- EN: Sessions
L.BOOK_NAMEPLATE = "%s · %s · desde %s"
-- EN: %s · %s · since %s
L.BOOK_NO_CASTS = "Aún no hay Lances"
-- EN: No Casts yet
L.BOOK_LIVE_LINE = "Sesión: %s · %s · %s"
-- EN: Session: %s · %s · %s
L.BOOK_UPDATING = "Actualizando mis registros…"
-- EN: Updating my records…

L.GUIDE_BLURB = "Tus propios números: tus probabilidades, de tus propios Lances, y cuánto llevas esperando. "
	.. "Nunca salen solas."
-- EN: Your own numbers: your odds, from your own Casts, and how long you’ve waited. It never pops up.
L.LOOK_TITLE = "Estadísticas"
-- EN: Stats
L.LOOK_ODDS_SINCE = "Cada pez de este caladero: tus probabilidades y cuántos Lances desde tu última captura."
-- EN: Every fish of this water: your odds, and how many Casts since you last caught it.
L.LOOK_YOUR_ODDS = "*Tus probabilidades* salen solo de tus propios Lances, y siempre dicen de cuántos."
-- EN: *Your odds* come only from your own Casts, and always say how many.
L.LOOK_DRY_SPELL = "Una *Racha seca* es cuánto llevas esperando. Mala suerte no es un fallo: no se te debe nada."
-- EN: A *Dry spell* is how long you’ve waited. Unlucky isn’t broken: nothing is owed.
L.LOOK_WATCH = "*Vigila* hasta tres peces para tener sus Rachas secas en tu rastreador."
-- EN: *Watch* up to three fish to keep their Dry spells on your tracker.
L.LOOK_NEVER_POPS_UP = "Las Estadísticas *nunca salen solas* ni anuncian nada. Están aquí cuando las pides."
-- EN: Stats *never pops up* and never announces. It’s here when you ask.
L.LOOK_AGAIN = "Volver a mostrar las notas de esta página"
-- EN: Show the notes for this page again

L.SESSION_NUMBERED = "Sesión %s"
-- EN: Session %s
L.SESSION_SPAN = "De %s a %s, %s junto al agua."
-- EN: %s to %s, %s at the water.
L.SESSION_NOW = "ahora"
-- EN: now
L.SESSION_CASTS = "Lances"
-- EN: Casts
L.SESSION_CATCHES = "Capturas"
-- EN: Catches
L.SESSION_GOT_AWAY = "Escapados"
-- EN: Got away
L.SESSION_PER_HOUR = "Capturas por hora"
-- EN: Catches per hour
L.SESSION_SKILL = "Habilidad ganada"
-- EN: Skill gained
L.SESSION_BY_QUALITY = "Por calidad"
-- EN: By quality
L.SESSION_WHERE_AND_WHO = "Dónde y quién"
-- EN: Where and who
L.SESSIONS_BEFORE_THAT = "Antes de eso"
-- EN: Before that
L.SESSIONS_EARLIER = "Sesiones anteriores"
-- EN: Earlier Sessions
L.SESSIONS_EVERY = "Todas las Sesiones"
-- EN: Every Session
L.SESSIONS_STARTED = "Inicio"
-- EN: Started
L.SESSIONS_WHERE = "Dónde"
-- EN: Where
L.SESSIONS_LENGTH = "Duración"
-- EN: Length
L.SESSIONS_CASTS = "Lances"
-- EN: Casts
L.SESSIONS_CATCHES = "Capturas"
-- EN: Catches
L.SESSIONS_NOTE = "Una Sesión termina tras %d minutos sin un Lance."
-- EN: A Session ends after %d minutes without a Cast.
L.SESSIONS_LATER = "más recientes"
-- EN: later
L.SESSIONS_EARLIER_PAGE = "anteriores"
-- EN: earlier
L.SESSIONS_PAGE = "página %d de %d"
-- EN: page %d of %d
L.NO_SESSIONS = "Aún no hay Sesiones."
-- EN: No Sessions yet.

L.NOTHING_IS_OWED = "Cada Lance es su propia tirada; no se te debe nada."
-- EN: Every Cast is its own roll; nothing is owed.

L.COUNTS = {
	Casts = { one = "%s Lance", other = "%s Lances" },
	Catches = { one = "%s Captura", other = "%s Capturas" },
	Sessions = { one = "%s Sesión", other = "%s Sesiones" },
	waters = { one = "%s caladero", other = "%s caladeros" },
	anglers = { one = "%s pescador de cada 100 espera", other = "%s pescadores de cada 100 esperan" },
}
-- EN: { Casts = { one = "%s Cast", other = "%s Casts" }, Catches = { one = "%s Catch", other = "%s Catches" }, Sessions = { one = "%s Session", other = "%s Sessions" }, anglers = { one = "%s angler in 100 waits", other = "%s anglers in 100 wait" }, waters = { one = "%s water", other = "%s waters" } }
L.DURATION_UNDER_MINUTE = "menos de 1m"
-- EN: under 1m
L.AGO_NOW = "ahora mismo"
-- EN: just now
L.AGO_MINUTES = "hace %dm"
-- EN: %dm ago
L.AGO_HOURS = "hace %dh"
-- EN: %dh ago
L.AGO_DAYS = "hace %dd"
-- EN: %dd ago
L.ITEM_FALLBACK = "Objeto %d"
-- EN: Item %d
L.AREA_FALLBACK = "Área %d"
-- EN: Area %d
L.CHARACTER_FALLBACK = "Personaje %d"
-- EN: Character %d
L.QUALITY_FALLBACK = "Calidad %d"
-- EN: Quality %d

L.ODDS_HEADING = "Tus probabilidades"
-- EN: Your odds
L.ODDS_LEARNING_SHORT = "aprendiendo %d/%d"
-- EN: learning %d/%d
L.ODDS_LEARNING = "Aprendiendo…"
-- EN: Learning…
L.ODDS_UNSEEN = "aún no visto"
-- EN: not seen yet
L.ODDS_KNOWN_SHORT = "1 de %s"
-- EN: 1 in %s
L.ODDS_KNOWN = "aprox. 1 de cada %s"
-- EN: about 1 in %s
-- ODDS_KNOWN's first word: the entry splits the headline on it.
L.ODDS_ABOUT = "aprox."
-- EN: about
L.ODDS_HERE = "aquí"
-- EN: here
L.ODDS_ACROSS = "en toda la zona de %s"
-- EN: across %s
L.ODDS_SIDE_HI = "con habilidad %d o más"
-- EN: at or above %d skill
L.ODDS_SIDE_LO = "con habilidad menor de %d"
-- EN: below %d skill
L.ODDS_LEARNING_SENTENCE = "%s de los %d Lances que necesito %s antes de que Tus probabilidades den un número."
-- EN: %s of the %d Casts I need %s before Your odds show a number.
L.ODDS_SCOPE_LINE = "Según %s de mis Lances %s; capturas: %s."
-- EN: From %s of my Casts %s; %s caught.
L.ODDS_UNSEEN_SENTENCE = "En %s Lances %s: más raro que 1 de cada %s o así, si es que pica aquí."
-- EN: In %s Casts %s: rarer than about 1 in %s, if it bites here at all.
L.ODDS_RANGE = "Probablemente entre 1 de cada %s y 1 de cada %s (95%%)."
-- EN: Likely between 1 in %s and 1 in %s (95%%).
L.ODDS_RANGE_ROUNDING = "Dentro del redondeo de 1 de cada %s (95%%)."
-- EN: Within rounding of 1 in %s (95%%).
L.ODDS_NOTE_ENTRY = "Pagle aún no ha confirmado que pique aquí."
-- EN: Pagle hasn't confirmed it bites here yet.
L.ODDS_NOTE_WINDOW = "La ventana aún no está confirmada."
-- EN: The window isn't confirmed yet.
L.ODDS_NOTE_LINE = "La línea sin basura aún no está confirmada."
-- EN: The no-junk line isn't confirmed yet.
L.ODDS_NOTE_POOL = "Aguas abiertas y bancos juntos: no hay datos de bancos."
-- EN: Open water and pools combined: there is no pool data.
L.WINDOW_NAMES = {
	day = "de día",
	night = "de noche",
	spring = "en primavera",
	summer = "en verano",
	autumn = "en otoño",
	winter = "en invierno",
	event = "durante su evento",
	other = "en su ventana",
}
-- EN: { autumn = "in autumn", day = "by day", event = "during its event", night = "by night", other = "in its window", spring = "in spring", summer = "in summer", winter = "in winter" }
L.DRY_NONE_YET = "%s %s, y aún nada."
-- EN: %s %s, none yet.
L.DRY_SINCE_ENTRY = "%s desde el último, %s."
-- EN: %s since my last one, %s.
L.DRY_SINCE_TRACKER = "%s desde mi última captura de %s."
-- EN: %s since my last %s.
L.DRY_CAUGHT_LAST = "Lo pesqué en mi último Lance %s."
-- EN: Caught one on my last Cast %s.
L.DRY_LEARNING = "La suerte se mide cuando Tus probabilidades tengan un número."
-- EN: A luck reading comes once Your odds have a number.
L.LUCK_NOTHING_UNUSUAL = "Nada raro."
-- EN: Nothing unusual.
L.LUCK_ABOUT = "Cerca de %s tanto. Nada raro."
-- EN: About %s this long. Nothing unusual.
L.LUCK_LONG_WAIT = "Más o menos 1 pescador de cada %s espera tanto. Una espera larga, pero dentro de la suerte normal."
-- EN: Roughly 1 angler in %s waits this long. A long wait, but well within normal luck.
L.LUCK_UNLUCKY = "Más o menos 1 pescador de cada %s espera tanto. Mala suerte, no un fallo."
-- EN: Roughly 1 angler in %s waits this long. Unlucky, not broken.
L.LUCK_VERY_UNLUCKY = "Solo 1 pescador de cada %s, más o menos, espera tanto. %s"
-- EN: Only about 1 angler in %s waits this long. %s
L.LUCK_UNDER_A_MILLION = "Menos de 1 pescador por millón espera tanto. %s"
-- EN: Fewer than 1 angler in a million waits this long. %s
L.LUCK_VERY_UNLUCKY_ROLL = "Muy mala suerte, y cada Lance sigue siendo su propia tirada."
-- EN: Very unlucky, and every Cast is still its own roll.
L.BANDS = { normal = "normal", unlucky = "mala suerte", veryUnlucky = "muy mala suerte" }
-- EN: { normal = "normal", unlucky = "unlucky", veryUnlucky = "very unlucky" }
L.DRY_SHORT_SINCE = "%s en seco"
-- EN: %s since
L.DRY_JUST_NOW = "ahora mismo"
-- EN: just now
L.DRY_WATCH_SINCE = "%s en seco%s."
-- EN: %s since the last%s.
L.DRY_WATCH_CAUGHT_LAST = "pescado en mi último Lance."
-- EN: caught on my last Cast.
L.DRY_WATCH_NONE_YET = "%s, y aún nada."
-- EN: %s, none yet.

L.GROUPS = {
	any = { heading = "A cualquier hora", note = "Tus probabilidades · Racha seca" },
	pools = { heading = "Bancos", note = "aguas abiertas y bancos juntos" },
	window = { heading = "En su ventana", note = "solo Lances en su ventana" },
	added = { heading = "También pescado aquí", note = "no está en la carta de Pagle de estos caladeros" },
}
-- EN: { added = { heading = "Also caught here", note = "not on Pagle's chart for these waters" }, any = { heading = "Any time", note = "Your odds · Dry spell" }, pools = { heading = "Pools", note = "open water and pools combined" }, window = { heading = "In their window", note = "only Casts in their window" } }
L.PLACE_ZONE_KICKER = "Caladeros"
-- EN: Waters
L.PLACE_HERE = "Estoy aquí"
-- EN: I'm here
L.PLACE_CASTS = "Llevo %s aquí."
-- EN: %s of my Casts here.
L.PLACE_NO_JUNK = "Sin basura desde %d."
-- EN: No junk from %d.
L.PLACE_NO_JUNK_PAST = "Sin basura desde %d; con %d ya lo paso, así que solo cuentan esos Lances."
-- EN: No junk from %d; at %d I'm past it, so only those Casts count.
L.PLACE_NO_JUNK_BELOW = "Sin basura desde %d; con %d no llego, así que solo cuentan mis Lances por debajo."
-- EN: No junk from %d; at %d I'm below it, so only my Casts below it count.
L.PLACE_NO_CHART = "Pagle aún no tiene carta de estos caladeros."
-- EN: Pagle has no chart of these waters yet.
L.PLACE_WATERS = "Sus caladeros"
-- EN: Its waters
L.PLACE_WATERS_NOTE = "mis Lances"
-- EN: my Casts
L.PLACE_ACROSS_ZONE = "Los peces con menos de %d Lances en %s usan toda la zona de %s hasta entonces."
-- EN: Fish with fewer than %d Casts in %s use all of %s until then.
L.PLACE_ABOUT = "Sobre estos caladeros"
-- EN: About these waters
L.PLACE_CASTS_LABEL = "Lances"
-- EN: Casts
L.PLACE_CATCHES_LABEL = "Capturas"
-- EN: Catches
L.PLACE_GOT_AWAY_LABEL = "Escapados"
-- EN: Got away
L.PLACE_PICK = "Elige un pez a la izquierda para ver sus probabilidades y su Racha seca."
-- EN: Pick a fish on the left for its odds and its Dry spell.
L.ENTRY_KICKER = "Tus probabilidades · %s"
-- EN: Your odds · %s
L.ENTRY_WATCH = "vigilar"
-- EN: watch
L.ENTRY_WATCHING = "vigilando"
-- EN: watching
L.ENTRY_DRY = "Racha seca"
-- EN: Dry spell
L.ENTRY_DRY_NOTE = "contada como las probabilidades de arriba"
-- EN: counted like the odds above
L.RULER_TICKS = { "todos", "1 de 10", "1 de 100", "1 de 1k", "1 de 10k", "1 de 100k", "1 de 1M" }
-- EN: { "all", "1 in 10", "1 in 100", "1 in 1k", "1 in 10k", "1 in 100k", "1 in 1M" }
L.RULER_ME = "yo"
-- EN: me
L.ENTRY_RECORDS = "En mis registros"
-- EN: In my records
L.ENTRY_CAUGHT_HERE = "Pescado en este recuento"
-- EN: Caught in this count
L.ENTRY_CAUGHT_ANYWHERE = "Pescado en cualquier sitio"
-- EN: Caught anywhere
L.ENTRY_ITEM_PAGE = "Todos los caladeros donde pica"
-- EN: Every water it bites in
L.HOME_KICKER = "Los caladeros"
-- EN: The waters
L.HOME_TITLE = "Dónde he pescado"
-- EN: Where I've fished
L.HOME_INTRO = "Tus probabilidades y Rachas secas salen solo de mis propios Lances, nunca de datos del juego."
-- EN: Your odds and Dry spells come only from my own Casts, never from game data.
L.HOME_TILE_NOT_FISHED = "aún sin pescar"
-- EN: not fished yet
L.HOME_HERE = "Estoy aquí"
-- EN: I'm here
L.HOME_WATCHING = "vigilando %d"
-- EN: watching %d
L.HOME_NOT_FISHED = "Aún no he pescado en ningún sitio."
-- EN: Not fished anywhere yet.
L.HOME_RIGHT_NOW = "Ahora mismo"
-- EN: Right now
L.HOME_FISHING = "Pescando en %s."
-- EN: Fishing %s.
L.HOME_FISHING_WHEN = "Pescando en %s, %s."
-- EN: Fishing %s, %s.
L.HOME_NOWHERE = "No sé dónde estoy."
-- EN: I can't tell where I am.
L.HOME_SKILL_HI = "Habilidad %d, por encima de la línea sin basura (%d)."
-- EN: Skill %d, past the no-junk line (%d).
L.HOME_SKILL_LO = "Habilidad %d, por debajo de la línea sin basura (%d)."
-- EN: Skill %d, below the no-junk line (%d).
-- "escapados %s" rather than "%s escapados": the count can be 1.
L.HOME_SESSION = "Esta Sesión: %s, %s, escapados %s, %s hasta ahora."
-- EN: This Session: %s, %s, %s got away, %s so far.
L.HOME_LAST_SESSION = "Ahora no hay Sesión. La última terminó %s."
-- EN: No Session right now. The last one ended %s.
L.HOME_NO_SESSION = "Aún no hay Sesión."
-- EN: No Session yet.
L.HOME_WATCHED = "Rachas secas que vigilo"
-- EN: Dry spells I'm watching
L.HOME_WATCHED_NOTE = "también en el rastreador en vivo"
-- EN: also on the live tracker
L.HOME_NO_WATCHES = "Nada aún. Vigila una Racha seca desde la página de cualquier pez."
-- EN: Nothing yet. Watch a Dry spell from any fish's page.
L.HOME_CONTENTS = "En este libro"
-- EN: In this book
L.HOME_WHERE_I_AM = "Dónde estoy: %s"
-- EN: Where I am: %s
L.HOME_WHERE_UNKNOWN = "Dónde estoy: no lo sé"
-- EN: Where I am: unknown
L.HOME_EVERY_SESSION = "Todas las Sesiones"
-- EN: Every Session

L.ITEM_KICKER = "Un pez"
-- EN: A fish
L.ITEM_BITES_ANY = "Pica a cualquier hora."
-- EN: Bites at any hour.
L.ITEM_BITES_ONLY = "Solo pica %s."
-- EN: Bites only %s.
L.ITEM_BITES_ONLY_TIMED = "Solo pica %s (%s, hora del reino)."
-- EN: Bites only %s (%s realm time).
L.ITEM_POOL = "También en bancos; sin datos de bancos, se cuentan juntos."
-- EN: Also in pools; with no pool data, both are counted together.
L.ITEM_CAUGHT = "Pescado"
-- EN: Caught
L.ITEM_FIRST_CAUGHT = "Primera captura"
-- EN: First caught
L.ITEM_LAST_CAUGHT = "Última captura"
-- EN: Last caught
L.ITEM_HERE_SINCE = "%s; %s en seco."
-- EN: %s; %s since the last.
L.ITEM_HERE_CAUGHT_LAST = "%s; pescado en mi último Lance."
-- EN: %s; caught on my last Cast.
L.ITEM_HERE_NONE_YET = "%s; aún nada."
-- EN: %s; none yet.
L.ITEM_OPEN_HERE = "Abrir su página aquí"
-- EN: Open its page here
L.ITEM_WATERS_KICKER = "Sus caladeros"
-- EN: Its waters
L.ITEM_WATERS_TITLE = "Dónde lo he buscado"
-- EN: Where I've fished for it
L.ITEM_NO_WATERS = "No he pescado en ningún sitio donde pique."
-- EN: I haven't fished anywhere it bites.

L.SEARCH_HINT = "Busca un pez o un caladero…"
-- EN: Find a fish or a water…
L.SEARCH_FISH = "pez"
-- EN: fish
L.SEARCH_ZONE = "zona"
-- EN: zone
L.SEARCH_NONE = "Nada con ese nombre en mis registros."
-- EN: Nothing by that name in my records.

L.LIFETIME_TITLE = "Cada Lance que he hecho"
-- EN: Every Cast I've made
L.LIFETIME_CASTS = "Lances"
-- EN: Casts
L.LIFETIME_CATCHES = "Capturas"
-- EN: Catches
L.LIFETIME_GOT_AWAY = "Escapados"
-- EN: Got away
L.LIFETIME_SESSIONS = "Sesiones"
-- EN: Sessions
L.LIFETIME_TIME_AT_THE_WATER = "Tiempo junto al agua"
-- EN: Time at the water
L.LIFETIME_BESTS = "Récords"
-- EN: Bests
L.LIFETIME_LONGEST = "Sesión más larga, %s"
-- EN: Longest Session, %s
L.LIFETIME_BEST_RATE = "Más Capturas por hora, %s"
-- EN: Most Catches per hour, %s
L.LIFETIME_BY_SKILL = "Escapados, por habilidad"
-- EN: Got away, by skill
L.LIFETIME_BY_SKILL_NOTE = "frente a la línea sin basura de cada caladero"
-- EN: against each water's no-junk line
L.LIFETIME_MARGIN_NAMES = {
	lo50 = "50+ por debajo",
	lo1 = "1–49 por debajo",
	hi0 = "0–24 por encima",
	hi25 = "25+ por encima",
}
-- EN: { hi0 = "0–24 over", hi25 = "25+ over", lo1 = "below by 1–49", lo50 = "below by 50+" }
L.LIFETIME_MARGIN_VALUE = "%d%% de %s"
-- EN: %d%% of %s
L.LIFETIME_CHARACTERS = "Personajes"
-- EN: Characters
L.LIFETIME_CHARACTER_VALUE = "%s · %s · escapados %s"
-- EN: %s · %s · %s got away
L.LIFETIME_CATCH_KICKER = "Las capturas"
-- EN: The catch
L.LIFETIME_EVERY_FISH = "Todos los peces"
-- EN: Every fish
L.LIFETIME_INDEX_NOTE = "Cuántos he pescado. Pasa el ratón para ver primera y última; haz clic para sus caladeros."
-- EN: How many I've caught. Hover for first and last; click for its waters.
L.LIFETIME_FIRST_LAST = "Primera %s, última %s"
-- EN: First %s, last %s

L.WATCH_FULL = "Puedes vigilar hasta %d Rachas secas. Deja de vigilar una antes."
-- EN: You can watch up to %d Dry spells. Stop watching one first.
L.WATCH_TRACKER_ON = "Pagle: rastreador en vivo activado para mostrar tus Rachas secas vigiladas."
-- EN: Pagle: live tracker turned on to show your watched Dry spells.

L.SETTINGS_TRACKER = "Mostrar el rastreador en vivo"
-- EN: Show the live tracker
L.SETTINGS_TRACKER_TOOLTIP = "Muestra esta Sesión y tus Rachas secas vigiladas bajo el minimapa. Vigilar una Racha "
	.. "seca lo activa."
-- EN: Shows this Session and your watched Dry spells under the minimap. Watching a Dry spell turns it on.
L.SETTINGS_WATCHED = "Rachas secas vigiladas"
-- EN: Watched Dry spells
L.SETTINGS_WATCHED_TOOLTIP = "Vigila o deja de vigilar desde la página de cualquier pez en el libro de Estadísticas."
-- EN: Watch or stop watching from any fish's page in the Stats book.
L.SETTINGS_WATCHED_COUNT = "%d de %d"
-- EN: %d of %d
L.SETTINGS_WATCHED_NONE = "Vigila una Racha seca desde la página de cualquier pez en el libro de Estadísticas."
-- EN: Watch a Dry spell from any fish's page in the Stats book.
L.SETTINGS_STOP_WATCHING = "Dejar de vigilar"
-- EN: Stop watching

L.SLOT_TRACKER_FRAME = "Marco del rastreador de Estadísticas"
-- EN: Stats tracker frame

L.TRACKER_SESSION = "Sesión · %s"
-- EN: Session · %s
L.TRACKER_COUNTS = "%s · %s · escapados %s"
-- EN: %s · %s · %s got away
L.TRACKER_PER_HOUR = "%s por hora · habilidad +%s"
-- EN: %s per hour · skill +%s
L.TRACKER_NO_SESSION = "sin Sesión"
-- EN: no Session
L.TRACKER_UPDATING = "actualizando"
-- EN: updating
