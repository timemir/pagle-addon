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
L.BOOK = "Estadísticas"
L.BOOK_SLASH_HELP = "Abre o cierra el libro de Estadísticas."

L.BOOK_ROOT = "Estadísticas"
L.BOOK_WHERE_I_AM = "Dónde estoy"
L.BOOK_THIS_SESSION = "Esta Sesión"
L.BOOK_LAST_SESSION = "Mi última Sesión"
L.BOOK_LIFETIME = "Historial"
L.BOOK_SESSIONS = "Sesiones"
L.BOOK_NAMEPLATE = "%s · %s · desde %s"
L.BOOK_NO_CASTS = "Aún no hay Lances"
L.BOOK_LIVE_LINE = "Sesión: %s · %s · %s"
L.BOOK_UPDATING = "Actualizando mis registros…"

L.GUIDE_BLURB = "Tus propios números: tus probabilidades, de tus propios Lances, y cuánto llevas esperando. "
	.. "Nunca salen solas."
L.LOOK_TITLE = "Estadísticas"
L.LOOK_ODDS_SINCE = "Cada pez de este caladero: tus probabilidades y cuántos Lances desde tu última captura."
L.LOOK_YOUR_ODDS = "*Tus probabilidades* salen solo de tus propios Lances, y siempre dicen de cuántos."
L.LOOK_DRY_SPELL = "Una *Racha seca* es cuánto llevas esperando. Mala suerte no es un fallo: no se te debe nada."
L.LOOK_WATCH = "*Vigila* hasta tres peces para tener sus Rachas secas en tu rastreador."
L.LOOK_NEVER_POPS_UP = "Las Estadísticas *nunca salen solas* ni anuncian nada. Están aquí cuando las pides."
L.LOOK_AGAIN = "Volver a mostrar las notas de esta página"

L.SESSION_NUMBERED = "Sesión %s"
L.SESSION_SPAN = "De %s a %s, %s junto al agua."
L.SESSION_NOW = "ahora"
L.SESSION_CASTS = "Lances"
L.SESSION_CATCHES = "Capturas"
L.SESSION_GOT_AWAY = "Escapados"
L.SESSION_PER_HOUR = "Capturas por hora"
L.SESSION_SKILL = "Habilidad ganada"
L.SESSION_BY_QUALITY = "Por calidad"
L.SESSION_WHERE_AND_WHO = "Dónde y quién"
L.SESSIONS_BEFORE_THAT = "Antes de eso"
L.SESSIONS_EARLIER = "Sesiones anteriores"
L.SESSIONS_EVERY = "Todas las Sesiones"
L.SESSIONS_STARTED = "Inicio"
L.SESSIONS_WHERE = "Dónde"
L.SESSIONS_LENGTH = "Duración"
L.SESSIONS_CASTS = "Lances"
L.SESSIONS_CATCHES = "Capturas"
L.SESSIONS_NOTE = "Una Sesión termina tras %d minutos sin un Lance."
L.SESSIONS_LATER = "más recientes"
L.SESSIONS_EARLIER_PAGE = "anteriores"
L.SESSIONS_PAGE = "página %d de %d"
L.NO_SESSIONS = "Aún no hay Sesiones."

L.NOTHING_IS_OWED = "Cada Lance es su propia tirada; no se te debe nada."

L.COUNTS = {
	Casts = { one = "%s Lance", other = "%s Lances" },
	Catches = { one = "%s Captura", other = "%s Capturas" },
	Sessions = { one = "%s Sesión", other = "%s Sesiones" },
	waters = { one = "%s caladero", other = "%s caladeros" },
	anglers = { one = "%s pescador de cada 100 espera", other = "%s pescadores de cada 100 esperan" },
}
L.DURATION_UNDER_MINUTE = "menos de 1m"
L.AGO_NOW = "ahora mismo"
L.AGO_MINUTES = "hace %dm"
L.AGO_HOURS = "hace %dh"
L.AGO_DAYS = "hace %dd"
L.ITEM_FALLBACK = "Objeto %d"
L.AREA_FALLBACK = "Área %d"
L.CHARACTER_FALLBACK = "Personaje %d"
L.QUALITY_FALLBACK = "Calidad %d"

L.ODDS_HEADING = "Tus probabilidades"
L.ODDS_LEARNING_SHORT = "aprendiendo %d/%d"
L.ODDS_LEARNING = "Aprendiendo…"
L.ODDS_UNSEEN = "aún no visto"
L.ODDS_KNOWN_SHORT = "1 de %s"
L.ODDS_KNOWN = "aprox. 1 de cada %s"
-- ODDS_KNOWN's first word: the entry splits the headline on it.
L.ODDS_ABOUT = "aprox."
L.ODDS_HERE = "aquí"
L.ODDS_ACROSS = "en toda la zona de %s"
L.ODDS_SIDE_HI = "con habilidad %d o más"
L.ODDS_SIDE_LO = "con habilidad menor de %d"
L.ODDS_LEARNING_SENTENCE = "%s de los %d Lances que necesito %s antes de que Tus probabilidades den un número."
L.ODDS_SCOPE_LINE = "Según %s de mis Lances %s; capturas: %s."
L.ODDS_UNSEEN_SENTENCE = "En %s Lances %s: más raro que 1 de cada %s o así, si es que pica aquí."
L.ODDS_RANGE = "Probablemente entre 1 de cada %s y 1 de cada %s (95%%)."
L.ODDS_RANGE_ROUNDING = "Dentro del redondeo de 1 de cada %s (95%%)."
L.ODDS_NOTE_ENTRY = "Pagle aún no ha confirmado que pique aquí."
L.ODDS_NOTE_WINDOW = "La ventana aún no está confirmada."
L.ODDS_NOTE_LINE = "La línea sin basura aún no está confirmada."
L.ODDS_NOTE_POOL = "Aguas abiertas y bancos juntos: no hay datos de bancos."
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
L.DRY_NONE_YET = "%s %s, y aún nada."
L.DRY_SINCE_ENTRY = "%s desde el último, %s."
L.DRY_SINCE_TRACKER = "%s desde mi última captura de %s."
L.DRY_CAUGHT_LAST = "Lo pesqué en mi último Lance %s."
L.DRY_LEARNING = "La suerte se mide cuando Tus probabilidades tengan un número."
L.LUCK_NOTHING_UNUSUAL = "Nada raro."
L.LUCK_ABOUT = "Cerca de %s tanto. Nada raro."
L.LUCK_LONG_WAIT = "Más o menos 1 pescador de cada %s espera tanto. Una espera larga, pero dentro de la suerte normal."
L.LUCK_UNLUCKY = "Más o menos 1 pescador de cada %s espera tanto. Mala suerte, no un fallo."
L.LUCK_VERY_UNLUCKY = "Solo 1 pescador de cada %s, más o menos, espera tanto. %s"
L.LUCK_UNDER_A_MILLION = "Menos de 1 pescador por millón espera tanto. %s"
L.LUCK_VERY_UNLUCKY_ROLL = "Muy mala suerte, y cada Lance sigue siendo su propia tirada."
L.BANDS = { normal = "normal", unlucky = "mala suerte", veryUnlucky = "muy mala suerte" }
L.DRY_SHORT_SINCE = "%s en seco"
L.DRY_JUST_NOW = "ahora mismo"
L.DRY_WATCH_SINCE = "%s en seco%s."
L.DRY_WATCH_CAUGHT_LAST = "pescado en mi último Lance."
L.DRY_WATCH_NONE_YET = "%s, y aún nada."

L.GROUPS = {
	any = { heading = "A cualquier hora", note = "Tus probabilidades · Racha seca" },
	pools = { heading = "Bancos", note = "aguas abiertas y bancos juntos" },
	window = { heading = "En su ventana", note = "solo Lances en su ventana" },
	added = { heading = "También pescado aquí", note = "no está en la carta de Pagle de estos caladeros" },
}
L.PLACE_ZONE_KICKER = "Caladeros"
L.PLACE_HERE = "Estoy aquí"
L.PLACE_CASTS = "Llevo %s aquí."
L.PLACE_NO_JUNK = "Sin basura desde %d."
L.PLACE_NO_JUNK_PAST = "Sin basura desde %d; con %d ya lo paso, así que solo cuentan esos Lances."
L.PLACE_NO_JUNK_BELOW = "Sin basura desde %d; con %d no llego, así que solo cuentan mis Lances por debajo."
L.PLACE_NO_CHART = "Pagle aún no tiene carta de estos caladeros."
L.PLACE_WATERS = "Sus caladeros"
L.PLACE_WATERS_NOTE = "mis Lances"
L.PLACE_ACROSS_ZONE = "Los peces con menos de %d Lances en %s usan toda la zona de %s hasta entonces."
L.PLACE_ABOUT = "Sobre estos caladeros"
L.PLACE_CASTS_LABEL = "Lances"
L.PLACE_CATCHES_LABEL = "Capturas"
L.PLACE_GOT_AWAY_LABEL = "Escapados"
L.PLACE_PICK = "Elige un pez a la izquierda para ver sus probabilidades y su Racha seca."
L.ENTRY_KICKER = "Tus probabilidades · %s"
L.ENTRY_WATCH = "vigilar"
L.ENTRY_WATCHING = "vigilando"
L.ENTRY_DRY = "Racha seca"
L.ENTRY_DRY_NOTE = "contada como las probabilidades de arriba"
L.RULER_TICKS = { "todos", "1 de 10", "1 de 100", "1 de 1k", "1 de 10k", "1 de 100k", "1 de 1M" }
L.RULER_ME = "yo"
L.ENTRY_RECORDS = "En mis registros"
L.ENTRY_CAUGHT_HERE = "Pescado en este recuento"
L.ENTRY_CAUGHT_ANYWHERE = "Pescado en cualquier sitio"
L.ENTRY_ITEM_PAGE = "Todos los caladeros donde pica"
L.HOME_KICKER = "Los caladeros"
L.HOME_TITLE = "Dónde he pescado"
L.HOME_INTRO = "Tus probabilidades y Rachas secas salen solo de mis propios Lances, nunca de datos del juego."
L.HOME_TILE_NOT_FISHED = "aún sin pescar"
L.HOME_HERE = "Estoy aquí"
L.HOME_WATCHING = "vigilando %d"
L.HOME_NOT_FISHED = "Aún no he pescado en ningún sitio."
L.HOME_RIGHT_NOW = "Ahora mismo"
L.HOME_FISHING = "Pescando en %s."
L.HOME_FISHING_WHEN = "Pescando en %s, %s."
L.HOME_NOWHERE = "No sé dónde estoy."
L.HOME_SKILL_HI = "Habilidad %d, por encima de la línea sin basura (%d)."
L.HOME_SKILL_LO = "Habilidad %d, por debajo de la línea sin basura (%d)."
-- "escapados %s" rather than "%s escapados": the count can be 1.
L.HOME_SESSION = "Esta Sesión: %s, %s, escapados %s, %s hasta ahora."
L.HOME_LAST_SESSION = "Ahora no hay Sesión. La última terminó %s."
L.HOME_NO_SESSION = "Aún no hay Sesión."
L.HOME_WATCHED = "Rachas secas que vigilo"
L.HOME_WATCHED_NOTE = "también en el rastreador en vivo"
L.HOME_NO_WATCHES = "Nada aún. Vigila una Racha seca desde la página de cualquier pez."
L.HOME_CONTENTS = "En este libro"
L.HOME_WHERE_I_AM = "Dónde estoy: %s"
L.HOME_WHERE_UNKNOWN = "Dónde estoy: no lo sé"
L.HOME_EVERY_SESSION = "Todas las Sesiones"

L.ITEM_KICKER = "Un pez"
L.ITEM_BITES_ANY = "Pica a cualquier hora."
L.ITEM_BITES_ONLY = "Solo pica %s."
L.ITEM_BITES_ONLY_TIMED = "Solo pica %s (%s, hora del reino)."
L.ITEM_POOL = "También en bancos; sin datos de bancos, se cuentan juntos."
L.ITEM_CAUGHT = "Pescado"
L.ITEM_FIRST_CAUGHT = "Primera captura"
L.ITEM_LAST_CAUGHT = "Última captura"
L.ITEM_HERE_SINCE = "%s; %s en seco."
L.ITEM_HERE_CAUGHT_LAST = "%s; pescado en mi último Lance."
L.ITEM_HERE_NONE_YET = "%s; aún nada."
L.ITEM_OPEN_HERE = "Abrir su página aquí"
L.ITEM_WATERS_KICKER = "Sus caladeros"
L.ITEM_WATERS_TITLE = "Dónde lo he buscado"
L.ITEM_NO_WATERS = "No he pescado en ningún sitio donde pique."

L.SEARCH_HINT = "Busca un pez o un caladero…"
L.SEARCH_FISH = "pez"
L.SEARCH_ZONE = "zona"
L.SEARCH_NONE = "Nada con ese nombre en mis registros."

L.LIFETIME_TITLE = "Cada Lance que he hecho"
L.LIFETIME_CASTS = "Lances"
L.LIFETIME_CATCHES = "Capturas"
L.LIFETIME_GOT_AWAY = "Escapados"
L.LIFETIME_SESSIONS = "Sesiones"
L.LIFETIME_TIME_AT_THE_WATER = "Tiempo junto al agua"
L.LIFETIME_BESTS = "Récords"
L.LIFETIME_LONGEST = "Sesión más larga, %s"
L.LIFETIME_BEST_RATE = "Más Capturas por hora, %s"
L.LIFETIME_BY_SKILL = "Escapados, por habilidad"
L.LIFETIME_BY_SKILL_NOTE = "frente a la línea sin basura de cada caladero"
L.LIFETIME_MARGIN_NAMES = {
	lo50 = "50+ por debajo",
	lo1 = "1–49 por debajo",
	hi0 = "0–24 por encima",
	hi25 = "25+ por encima",
}
L.LIFETIME_MARGIN_VALUE = "%d%% de %s"
L.LIFETIME_CHARACTERS = "Personajes"
L.LIFETIME_CHARACTER_VALUE = "%s · %s · escapados %s"
L.LIFETIME_CATCH_KICKER = "Las capturas"
L.LIFETIME_EVERY_FISH = "Todos los peces"
L.LIFETIME_INDEX_NOTE = "Cuántos he pescado. Pasa el ratón para ver primera y última; haz clic para sus caladeros."
L.LIFETIME_FIRST_LAST = "Primera %s, última %s"

L.WATCH_FULL = "Puedes vigilar hasta %d Rachas secas. Deja de vigilar una antes."
L.WATCH_TRACKER_ON = "Pagle: rastreador en vivo activado para mostrar tus Rachas secas vigiladas."

L.SETTINGS_TRACKER = "Mostrar el rastreador en vivo"
L.SETTINGS_TRACKER_TOOLTIP = "Muestra esta Sesión y tus Rachas secas vigiladas bajo el minimapa. Vigilar una Racha "
	.. "seca lo activa."
L.SETTINGS_WATCHED = "Rachas secas vigiladas"
L.SETTINGS_WATCHED_TOOLTIP = "Vigila o deja de vigilar desde la página de cualquier pez en el libro de Estadísticas."
L.SETTINGS_WATCHED_COUNT = "%d de %d"
L.SETTINGS_WATCHED_NONE = "Vigila una Racha seca desde la página de cualquier pez en el libro de Estadísticas."
L.SETTINGS_STOP_WATCHING = "Dejar de vigilar"

L.SLOT_TRACKER_FRAME = "Marco del rastreador de Estadísticas"

L.TRACKER_SESSION = "Sesión · %s"
L.TRACKER_COUNTS = "%s · %s · escapados %s"
L.TRACKER_PER_HOUR = "%s por hora · habilidad +%s"
L.TRACKER_NO_SESSION = "sin Sesión"
L.TRACKER_UPDATING = "actualizando"
