if not Pagle then -- luacheck: read globals Pagle
	return
end
if not GetLocale or GetLocale() ~= "esES" then
	return
end

-- The Ledger's string table in Spanish (Spain), over enUS.lua's.
local ns = select(2, ...)
local L = ns.L

local CAUGHT, IN_ITS_ELEMENT, REGULAR = "Capturado", "En su elemento", "Habitual"
local PARTS = "Interface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts"
local function sprite(x, y, w, h, size)
	return ("|T%s:%s:0:0:1024:2048:%d:%d:%d:%d|t"):format(PARTS, size or "0:0", x, x + w, y, y + h)
end
local STAR = sprite(650, 1126, 23, 23)
local TICK = sprite(486, 1586, 27, 20, "11:15")
local BEGIN_A_NEW_LEDGER = "Empezar un Libro nuevo"
local ZONE_REWARD = "Recompensa por maestría: cada sello nuevo da XP."
local UNWRITTEN_LEGEND = "leyenda sin escribir"
local IN_THIS_LEDGER = "En este Libro"

L.UNFISHED = "sin pescar"
L.POOLS = "bancos"
L.TROPHY_TITLE = "La Sala de trofeos"

L.TITLE = "Libro de registro"

L.SUMMARY_LINE = "Libro: Nivel de Pescador %d · %d%% completado"
L.SUMMARY_LINE_PRESTIGE = "Libro: Prestigio %d · Nivel de Pescador %d · %d%% completado"

L.ITEM_FALLBACK = "Objeto %d"
L.CONTINENT_NAMES = { [0] = "Reinos del Este", [1] = "Kalimdor" }
L.OTHER_WATERS = "Otras aguas"

L.BINDING_EARNED = "Nivel de Pescador %d"
L.EARNED_TEXT = {
	legend = "Captura una Leyenda",
	legends = "Captura las tres Leyendas",
	monster = "Captura un Monstruo",
	prestige1 = "Prestigio I",
	prestige5 = "Prestigio V",
	prestige10 = "Prestigio X",
	ledger = "Completa el Libro",
	varieties = "Cada pez en cada color",
	glass = "12 esquirlas de cristal",
	deep = "100 capturas pasada la medianoche",
	koi = "25 parejas seguidas",
	trophy = "25 récords de tamaño",
	slate = "30 Especies",
	ice = "100 capturas en el hielo",
	stitch = "Los 20 peces del dechado",
	wave = "300 capturas en el mar",
	logbook = "25 zonas pescadas",
	heartwood = "Una captura tras 10 que se escaparon",
	stormglass = "Maestro en 10 zonas",
	lacquer = "30 días pescando",
	knit = "10.000 Lances",
	flywallet = "5 señuelos distintos",
	carapace = "50 almejas de boca grande",
	ember = "Prestigio VII",
	crier = "Captura 100 peces como humano",
	hall = "Captura 100 peces como enano",
	glade = "Captura 100 peces como elfo de la noche",
	blueprint = "Captura 100 peces como gnomo",
	drum = "Captura 100 peces como orco",
	shroud = "Captura 100 peces como no-muerto",
	totem = "Captura 100 peces como tauren",
	hex = "Captura 100 peces como trol",
	lion = "Captura 300 peces con personajes de la Alianza",
	warband = "Captura 300 peces con personajes de la Horda",
	cartographer = "Maestro en 5 zonas",
}
L.EARNED_COUNT = "%s de %s %s"
L.EARNED_UNIT = {
	glass = "esquirlas",
	deep = "capturas",
	koi = "parejas",
	trophy = "récords",
	slate = "Especies",
	ice = "capturas",
	stitch = "peces",
	wave = "capturas",
	logbook = "zonas",
	stormglass = "zonas",
	lacquer = "días",
	knit = "Lances",
	flywallet = "señuelos",
	carapace = "almejas",
	crier = "peces",
	hall = "peces",
	glade = "peces",
	blueprint = "peces",
	drum = "peces",
	shroud = "peces",
	totem = "peces",
	hex = "peces",
	lion = "peces",
	warband = "peces",
	cartographer = "zonas",
}

L.CREST_UNFISHED = "Sin pescar"
L.CREST_UNCHARTED = "Aún sin catalogar"
L.CREST_NOTE_PROGRESS = "Se gana cuando %s llega a Maestro en el Diario de peces. Ahora es %s, %d%%. %s."
L.CREST_NOTE_UNFISHED = "Se gana cuando %s llega a Maestro en el Diario de peces. Captura algo allí para empezar."
L.CREST_NOTE_UNCHARTED = "Se gana cuando %s llega a Maestro en el Diario de peces, cuando sus aguas estén catalogadas."

L.LEVEL_UP_TITLE = "Nivel de Pescador %d"
L.LEVEL_UP_STAMP = "Nivel %d"
L.LEVELS_RAISED_ONE = "+%d nivel"
L.LEVELS_RAISED_OTHER = "+%d niveles"
L.NEW_SPECIES_TITLE = "Nueva Especie"
L.NEW_SPECIES_STAMP = "¡Nueva!"
L.NEW_SPECIES_FIRST_NOTE = "Una Especie nueva para tu Libro."
L.NEW_IN_ZONE_TITLE = "Nuevo aquí"
L.NEW_IN_ZONE_TEXT = "%s en %s"
L.NEW_IN_ZONE_STAMP = "Nuevo aquí"
L.SKILL_MILESTONE_TITLE = "Hito de habilidad"
L.SKILL_MILESTONE_TEXT = "Pesca %d"
L.ZONE_RANK_TITLE = "Rango de zona: %s"
L.ZONE_RANK_STAMP = "Sube de rango"
L.ZONE_MASTER_TITLE = "Maestro de zona"
L.ZONE_MASTER_STAMP = "Maestro"
L.CREST_EARNED = "Ganado: %s"
L.TROPHY_WEIGHT_TITLE = "Peso de trofeo"
L.TROPHY_WEIGHT_STAMP = "Trofeo"
L.NEW_CURIO_TITLE = "Nueva curiosidad"
L.NEW_CURIO_STAMP = "¡Nueva!"
L.UNCHARTED_TITLE = "Captura desconocida, registrada"
L.UNCHARTED_STAMP = "Registrada"
L.LEGEND_TITLE = "Leyenda"
L.LEGEND_STAMP = "¡Leyenda!"
L.PRESTIGE_READY_TITLE = "Prestigio listo"
L.PRESTIGE_READY_TEXT = "Abre el Diario de peces para empezar un Libro nuevo."
L.PRESTIGE_READY_STAMP = "Prestigio listo"
L.PRESTIGE_TITLE = "Prestigio %s"
L.MASTER_PRESTIGE_TITLE = "Prestigio de Maestro %d"
L.CATCHES_ONE = "%s Captura"
L.CATCHES_OTHER = "%s Capturas"
L.SIZE_RECORD_TITLE = "Récord de tamaño"
L.SIZE_RECORD_STAMP = "Récord"
L.RULER_LENGTH = "longitud"
L.NEW_VARIETY_TITLE = "Nueva variedad"
L.NEW_VARIETY_STAMP = "Nueva variedad"
L.RARE_VARIETY_TITLE = "Variedad rara"
L.EPIC_VARIETY_TITLE = "Variedad épica"
L.EVERY_COLOUR_TITLE = "Todos los colores de %s"
L.EVERY_COLOUR_STAMP = "Todos los colores"
L.TITLE_LINE = "Título: %s"
L.TITLE_EARNED = "Título ganado"
L.CAUGHT_STAR_TITLE = CAUGHT
L.ELEMENT_STAR_TITLE = IN_ITS_ELEMENT
L.REGULAR_STAR_TITLE = REGULAR
L.FAMILY_STAR_TITLE = "Familia de trofeos"

L.ZONE_RANKS = { "Visitante", "Habitual", "Local", "Experto", "Maestro" }

L.ZONE_NEXT_VISITOR = "Captura algo aquí para ser Visitante"
L.ZONE_NEXT_REGULAR_ONE = "Habitual: %d Especie más a cualquier hora"
L.ZONE_NEXT_REGULAR_OTHER = "Habitual: %d Especies más a cualquier hora"
L.ZONE_NEXT_LOCAL_ONE = "Local: %d Especie más a cualquier hora"
L.ZONE_NEXT_LOCAL_OTHER = "Local: %d Especies más a cualquier hora"
L.ZONE_NEXT_EXPERT = "Experto: %s"
L.ZONE_NEXT_GATED_ONE = "%d captura más de día, noche, temporada o evento"
L.ZONE_NEXT_GATED_OTHER = "%d capturas más de día, noche, temporada o evento"
L.ZONE_NEXT_JUNK = "un trasto"
L.ZONE_NEXT_TREASURE = "un tesoro"
L.ZONE_NEXT_MASTER_ONE = "Maestro: un trofeo de %d familia más"
L.ZONE_NEXT_MASTER_OTHER = "Maestro: un trofeo de %d familias más"
L.ZONE_NEXT_MASTERED = "Maestro de estas aguas"
L.ZONE_NEW_TO_FIND_ONE = "%d por descubrir: los datos crecieron, y tu sello se queda"
L.ZONE_NEW_TO_FIND_OTHER = "%d por descubrir: los datos crecieron, y tu sello se queda"

L.WRITE_UP_FIRST_BUILD_ONE = "Tu Libro se ha escrito a partir de %s Lance"
L.WRITE_UP_FIRST_BUILD_OTHER = "Tu Libro se ha escrito a partir de %s Lances"
L.WRITE_UP_WHILE_OFF = "Mientras el Libro estaba desactivado"
L.WRITE_UP_LEVEL = "Nivel de Pescador %d"
L.WRITE_UP_LEVEL_ROSE = "Nivel de Pescador %d a %d"
L.WRITE_UP_SPECIES_ONE = "%d Especie"
L.WRITE_UP_SPECIES_OTHER = "%d Especies"
L.WRITE_UP_VARIETIES_ONE = "%d variedad"
L.WRITE_UP_VARIETIES_OTHER = "%d variedades"
L.WRITE_UP_EVERY_COLOUR_ONE = "%d pez en todos los colores"
L.WRITE_UP_EVERY_COLOUR_OTHER = "%d peces en todos los colores"
L.WRITE_UP_ZONES_ONE = "%d zona con rango"
L.WRITE_UP_ZONES_OTHER = "%d zonas con rango"
L.WRITE_UP_MASTERED_ONE = "%d dominada"
L.WRITE_UP_MASTERED_OTHER = "%d dominadas"
L.WRITE_UP_TROPHY_ONE = "%d peso de trofeo"
L.WRITE_UP_TROPHY_OTHER = "%d pesos de trofeo"
L.WRITE_UP_CURIO_ONE = "%d curiosidad"
L.WRITE_UP_CURIO_OTHER = "%d curiosidades"
L.WRITE_UP_WITH_PRESTIGE = "%s · Prestigio %d"
L.WRITE_UP_LEGENDS_ONE = "%d Leyenda"
L.WRITE_UP_LEGENDS_OTHER = "%d Leyendas"
L.WRITE_UP_MORE_TITLES_ONE = "+%d título más"
L.WRITE_UP_MORE_TITLES_OTHER = "+%d títulos más"
L.WRITE_UP_SKILL_ONE = "%d Hito de habilidad"
L.WRITE_UP_SKILL_OTHER = "%d Hitos de habilidad"
L.WRITE_UP_COINS = "Monedas Pagle +%s"

L.JOURNAL = "Diario de peces"
L.JOURNAL_SLASH_HELP = "Abre o cierra el Diario de peces"
L.JOURNAL_UPDATING = "El Libro se está escribiendo a partir de tu Registro de capturas."
L.JOURNAL_HOME = "Inicio"
L.JOURNAL_BACK = "« volver"
L.JOURNAL_SEARCH_HINT = "Busca un pez o unas aguas…"
L.JOURNAL_HELP_CHART = "Ayuda a catalogar las aguas"
L.JOURNAL_CHART_PROMPT = "¿Has visto algo que Pagle no conoce?"
L.HOME_KICKER = "Las aguas"
L.HOME_TITLE = "Donde he pescado"
L.HOME_NOTES = "Notas para mí"
L.HOME_NOTE_NEW = "%s: %d por descubrir"
L.HOME_NOTE_CAUGHT_STAR = "%s: %d para " .. STAR
L.HOME_NOTE_STAR = "%s: %d para " .. STAR:rep(3)
L.HOME_NOTE_NONE = "¡A pescar!"
L.HOME_LEVEL = "Nivel de Pescador"
L.HOME_CONTENTS = IN_THIS_LEDGER
L.HOME_SEAL_WORD = "Libro"
L.HOME_CURIOS = "Curiosidades: trastos, tesoros, sin catalogar"
L.HOME_ANGLER = "El Pescador: manos e hitos"
L.BRASS_PLATE = "Nv %d · Libro %d%%"
L.BRASS_PLATE_TITLE = "Nv %d · %s · Libro %d%%"

L.MONTHS_SHORT = { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic" }
L.MONTHS = {
	"enero",
	"febrero",
	"marzo",
	"abril",
	"mayo",
	"junio",
	"julio",
	"agosto",
	"septiembre",
	"octubre",
	"noviembre",
	"diciembre",
}

L.WINDOWS = {
	day = "día",
	night = "noche",
	spring = "primavera",
	summer = "verano",
	autumn = "otoño",
	winter = "invierno",
	["event.301"] = "Torneo de pesca",
}
L.WINDOW_EVENT = "evento"
L.WINDOW_OPEN = "pican ahora"
L.WINDOW_BACK_HOURS = "vuelve en %d h"
L.WINDOW_BACK_MINUTES = "vuelve en %d min"
L.WINDOW_BACK_MONTH = "vuelve en %s"

L.XP_BAR_TEXT = "%s de %s."
L.XP_BAR_FRESH_ONE = " Agua fresca para %d Captura más."
L.XP_BAR_FRESH_OTHER = " Agua fresca para %d Capturas más."
L.XP_BAR_SET_ASIDE = "%s XP reservada para el próximo Prestigio"
L.XP_BAR_TIP_TITLE = "De dónde vino la XP de esta subida"
L.XP_BAR_TIP_NOTE = "por fuente, aproximado"
L.XP_SOURCE_OWN = "Capturas y descubrimientos"
L.XP_SOURCE_NAMES = {
	Hunts = "Cazas",
	TackleBoard = "Tablón de aparejos",
}

L.HINT_ANY_TIME = "A cualquier hora"
L.HINT_SKILL = "habilidad ~%d"
L.HINT_ANY_SKILL = "cualquier habilidad"

L.TILE_NEW = "¡Nuevos: %d!"
L.TILE_UNFISHED_SKILL = "sin pescar · habilidad ~%d"
L.TILE_UNFISHED_ANY_SKILL = "sin pescar · cualquier habilidad"
L.TILE_UNCHARTED = "aguas sin catalogar"

L.LIST_LAST = " y "
L.ENTRY_STAMPS = { CAUGHT, IN_ITS_ELEMENT, REGULAR }
L.STAMP_TIP_LAND_ONE = "Captúralo %d vez."
L.STAMP_TIP_LAND_OTHER = "Captúralo %d veces."
L.STAMP_TIP_LANDED = "%d de %d capturados."
L.STAMP_TIP_ELEMENT_WINDOW = "Captúralo en su ventana de elemento, en cualquier zona."
L.STAMP_TIP_ELEMENT_WINDOWS = "Captúralo en cada una de sus %d ventanas de elemento, en cualquier zona."
L.STAMP_TIP_ELEMENT_NEEDED = "%d de %d cumplidas. Faltan: %s."
L.STAMP_TIP_ELEMENT_MET = "Todas cumplidas: %s."
L.STAMP_TIP_ZONE = "Captúralo en cualquier zona."
L.STAMP_TIP_ZONES = "Captúralo en %d zonas distintas."
L.STAMP_TIP_ZONES_ONE = "En %d de %d zona."
L.STAMP_TIP_ZONES_OTHER = "En %d de %d zonas."
L.ENTRY_FIRST = "Primera captura el %s en %s, por %s. %s en total."
L.ENTRY_FIRST_NO_ZONE = "Primera captura el %s, por %s. %s en total."
L.ENTRY_FOUND_IN = "Se encuentra en %s."
L.ENTRY_ONLY_BY = " Solo de %s."
L.ENTRY_LARGEST = "El más grande que he capturado: %s"
L.ENTRY_REMOVED = "Ya no está en las aguas de Forever."
L.ENTRY_UNKNOWN = "Un pez desconocido"
L.ENTRY_HINT_LINK = "Leer la pista sencilla »"
L.FISH_KICKER = "Dónde encontrarlo"
L.FISH_TITLE = "Sus aguas"
L.FISH_CAUGHT_HERE = "capturado " .. TICK
L.FISH_WHEN = "Cuándo"
L.FISH_CAUGHT = "%s " .. CAUGHT .. " (%d/%d)"
L.FISH_ELEMENT = "%s " .. IN_ITS_ELEMENT .. " (%d/%d)"
L.FISH_REGULAR = "%s " .. REGULAR .. " (%d/%d)"
L.FISH_VARIETIES = "Variedades"
L.FISH_VARIETIES_COUNT = "%d de %d encontradas"
L.FISH_VARIETIES_LINK = "Ver las diez »"
L.VARIETIES_TITLE = "Sus colores"
L.VARIETIES_CAUGHT = "%d de %d capturadas"
L.VARIETY_COUNT = "Capturas: %s"
L.VARIETY_UNDISCOVERED = "Sin descubrir"
L.VARIETY_KICKER = {
	common = "Un color común",
	uncommon = "Un color poco común",
	rare = "Un color raro",
	epic = "Un color épico",
}
L.VARIETY_NOT_DISCOVERED = "Aún sin descubrir"
L.VARIETY_ODDS = "Aún sin capturar. Más o menos una Captura de cada %s."
L.VARIETY_ALL_TEN = "Las diez."
L.VARIETY_TO_GO = "Faltan %d."
L.SEARCH_NONE = "Aún no hay nada con ese nombre en el Libro."
L.SEARCH_WATERS = "Aguas"
L.SEARCH_FISH = "Peces"

L.ANGLER_CRUMB = "El Pescador"
L.ANGLER_EX_LIBRIS = "Ex libris"
L.ANGLER_LEDGER = "El Libro del Pescador"
L.ANGLER_KEPT_SINCE = "llevado desde el %s"
L.ANGLER_TALLY = "El Libro"
L.ANGLER_COMPLETE = "%d%% del Libro completado (%s de %s)"
L.ANGLER_PARTS = {
	species = "Especies",
	varieties = "Variedades",
	junk = "Museo de trastos",
	treasure = "Tesoros",
	trophy = "Pesos de la Sala de trofeos",
	zones = "Zonas dominadas",
}
L.ANGLER_PART_COUNT = "%s de %s"
L.ANGLER_CATCHES_ONE = "%s Captura"
L.ANGLER_CATCHES_OTHER = "%s Capturas"
L.ANGLER_HANDS = "Manos en la caña"
L.ANGLER_HAND = "habilidad %d / %d"
L.ANGLER_MILESTONES = "Hitos"
L.ANGLER_NEXT_MILESTONE = " · próximo hito: %s"
L.ANGLER_NO_PRESTIGE = "Aún sin Prestigio"
L.ANGLER_PRESTIGE = BEGIN_A_NEW_LEDGER .. " (Prestigio)"
L.ANGLER_AUTOMATIC = "Automático"
L.ANGLER_XP_SOURCES = "De dónde vino tu XP"
L.ANGLER_XP_CLIMB = "Esta subida"
L.ANGLER_XP_ALL = "En total"

L.ZONE_NEXT = "Siguiente: %s"
L.ZONE_NEW_HERE_ONE = "¡%d por descubrir aquí! Mi sello se queda."
L.ZONE_NEW_HERE_OTHER = "¡%d por descubrir aquí! Mi sello se queda."
L.ZONE_GROUPS = {
	anyTime = "A cualquier hora",
	pools = "Bancos",
	dayNight = "Día y noche",
	seasonal = "De temporada",
	events = "Eventos",
	trophies = "Trofeos",
	curios = "Curiosidades",
}
L.ZONE_POOLS_NOTE = "aguas abiertas y bancos juntos"
L.ZONE_TROPHY = "un trofeo de %s, cualquier peso"
L.ZONE_ALSO_NOTE = "Aún no está en la lista de Pagle para estas aguas."
L.ZONE_UNKNOWN_FISH = "— desconocido —"
L.ZONE_CAUGHT_ELSEWHERE = "%s (capturado en otro sitio)"
L.ZONE_ABOUT = "Sobre estas aguas"
L.ZONE_SKILL = "Habilidad ~%d"
L.ZONE_ANY_SKILL = "Cualquier habilidad"
L.ZONE_KNOWN = "%d%% de estas aguas conocido: %d de %d peces, %d de %d familias de trofeos"
L.ZONE_TROPHIES_HERE = "Trofeos capturados aquí"
L.ZONE_REWARD = ZONE_REWARD
L.ZONE_REWARD_TITLE = ZONE_REWARD .. " El sello de Maestro da el título %s."
L.ZONE_PICK = "Elige un pez a la izquierda para leer su página."
L.ZONE_UNCHARTED_NOTE = "Cada captura de aquí sigue anotada, y cuenta en cuanto los datos de Pagle se pongan al día."
L.ZONE_LOOSE_PAGES = "Hojas sueltas"
L.ZONE_LOOSE_TITLE = "Lo que salió aquí"
L.ZONE_UNCHARTED_GROUP = "Sin catalogar"
L.ZONE_UNCHARTED_SEAL = "sin catalogar"
L.ZONE_ALSO_CAUGHT_TITLE = "También capturado aquí"
L.ZONE_NOTHING_YET = "Nada capturado aquí todavía."

L.TROPHY_WEIGHTS = "%s de %s pesos."
L.TROPHY_KICKER = "Una colección"
L.TROPHY_FAMILIES = "Familias"
L.TROPHY_FAMILIES_NOTE = "pesos"
L.TROPHY_FAMILY_KICKER = "Una familia de trofeos"
L.TROPHY_HEAVIEST = "el más pesado"
L.TROPHY_STAMPS = { "Cualquier peso", "La mitad de los pesos", "El más pesado" }
L.TROPHY_TIP_ANY = "Captura cualquier peso de esta familia."
L.TROPHY_TIP_NONE_YET = "Aún no has capturado ninguno."
L.TROPHY_TIP_UNLISTED = "Capturado, aunque no está en la lista de esta familia."
L.TROPHY_TIP_LANDED_ONE = "%d de %d peso capturado."
L.TROPHY_TIP_LANDED_OTHER = "%d de %d pesos capturados."
L.TROPHY_TIP_HALF_ONE = "Captura su único peso de la lista."
L.TROPHY_TIP_HALF_OTHER = "Captura al menos %d de sus %d pesos de la lista."
L.TROPHY_TIP_NO_WEIGHTS = "Esta familia aún no tiene pesos en la lista."
L.TROPHY_TIP_HEAVIEST = "Captura su peso más alto de la lista, %s lb."
L.TROPHY_TIP_HEAVIEST_DONE = "Capturado."
L.TROPHY_TIP_HEAVIEST_TODO = "Aún no."
L.TROPHY_POUNDS = "libras"
L.TROPHY_LANDED = "Capturados %s de %s. El más pesado hasta ahora: %s lb."
L.TROPHY_NONE_LANDED = "Ninguno de esta familia todavía."
L.CURIOS_CRUMB = "Curiosidades"
L.CURIOS_JUNK_KICKER = "Trastos"
L.CURIOS_JUNK_TITLE = "El Museo de trastos"
L.CURIOS_TREASURES_KICKER = "Contenedores y tesoros"
L.CURIOS_EXHIBITS = "%s de %s piezas"
L.CURIOS_EMPTY_PLINTH = "Un pedestal vacío"
L.CURIOS_TREASURES_TITLE = "Tesoros"
L.CURIOS_OPENED = "%s de %s abiertos"
L.CURIOS_LOOSE_PAGES = "Hojas sueltas: sin catalogar"
L.CURIOS_LOOSE_PAGE = "%s: %s× en %s, el primero el %s. Pagle no lo conoce. Registrado."
L.CURIOS_UNKNOWN_WATERS = "aguas desconocidas"
L.CURIOS_NONE_UNCHARTED = "Ninguna. Cada captura está en el Libro."
L.LEGENDS_TITLE = "Leyendas"
L.LEGENDS_KICKER = "Fuera de los cien"
L.LEGENDS_INDEX = "El índice"
L.LEGENDS_COUNT = "%s de %s. Quedan fuera de los cien del Libro."
L.LEGENDS_UNWRITTEN = "una " .. UNWRITTEN_LEGEND
L.LEGENDS_UNWRITTEN_TITLE = "Una " .. UNWRITTEN_LEGEND
L.LEGENDS_OPEN_PLATE = "Abrir la lámina"
L.LEGENDS_PLATE_RETURN = "Haz clic en cualquier sitio para volver."
L.LEGENDS_PLATE_KICKER = "Una Leyenda de estas aguas"
L.LEGENDS_PLATE_SEAL = "Título"
L.FOLLOWING_TITLE = "Siguiendo"
L.FOLLOWING_KICKER = IN_THIS_LEDGER
L.FOLLOWING_NO_COMPANION = "sin Companion"
L.FOLLOWING_COUNT_ONE = "%s Pescador al que sigues. Sigue y deja de seguir en la web de Pagle."
L.FOLLOWING_COUNT_OTHER = "%s Pescadores a los que sigues. Sigue y deja de seguir en la web de Pagle."
L.FOLLOWING_ROW = "Nv %d · %s · %d%%"
L.FOLLOWING_ROW_NO_PRESTIGE = "Nv %d · %d%%"
L.FOLLOWING_HARDCORE = "Pescador Hardcore"
L.FOLLOWING_MORE_ONE = "y %s personaje más"
L.FOLLOWING_MORE_OTHER = "y %s personajes más"
L.FOLLOWING_SEAL = "Libro %d%%"
L.FOLLOWING_LEGENDS = "Leyendas"
L.FOLLOWING_LEGENDS_COUNT = "%s de %s"
L.FOLLOWING_WATERS = "Aguas dominadas"
L.FOLLOWING_CATCHES = "Capturas totales"
L.FOLLOWING_AS_OF = "A fecha de %s"
L.FOLLOWING_EMPTY = {
	none = {
		"Aún no sigues a nadie.",
		"Sigue a un Pescador desde su página en la web de Pagle.",
		"El Companion los trae en menos de una hora; aparecen aquí tras tu próximo /reload.",
	},
	absent = {
		"El Companion lleva esta página.",
		"El Pagle Companion trae al juego a los Pescadores que sigues en la web de Pagle.",
		"Sin él, esta página queda vacía. Pegar tu registro sigue actualizando tu propia página de Pescador.",
	},
	expired = {
		"Estas páginas tienen más de un día.",
		"Pagle las ha apartado hasta que el Companion traiga otras nuevas.",
		"Abre el Companion y luego haz /reload.",
	},
}
L.PRESTIGE_CONFIRM_KICKER = "Prestigio"
L.PRESTIGE_CONFIRM_TITLE = "¿" .. BEGIN_A_NEW_LEDGER .. "?"
L.PRESTIGE_CONFIRM_TEXT = "Tu Nivel de Pescador vuelve a subir desde 1. No pierdes nada de lo que has ganado."
L.PRESTIGE_CONFIRM_YES = "Prestigio"
L.PRESTIGE_CONFIRM_NO = "Aún no"
L.GUIDE_BLURB = "Tu libro: todas las aguas y todos los peces, tu Nivel de Pescador, récords y títulos."
L.GUIDE_RIBBON = "Tu Libro"
L.GUIDE_KICKER = "Tu Libro"
L.GUIDE_TITLE = "Empieza con tu próximo pez"
L.GUIDE_BODY = "Pagle solo anota lo que ve. Los peces que pescaste antes de hoy no están en tu Libro, y Pagle "
	.. "no fingirá que sí. Tu primera Captura es la página uno."
L.GUIDE_KEPT_NONE = "llevado desde … tu primera Captura"
L.GUIDE_RIGHT_KICKER = "Ya anotado"
L.GUIDE_RIGHT_TITLE = "Lo que Pagle pudo ver"
L.GUIDE_RIGHT_BODY =
	"Tu habilidad de Pesca es lo único que cuenta tu pasado con honestidad, así que cuenta desde el principio."
L.GUIDE_HEADING = "%s · Pesca %d"
L.GUIDE_READ_NOW = "leída ahora mismo"
L.GUIDE_MILESTONE = "Hito de habilidad %d"
L.GUIDE_MILESTONES = "Hitos de habilidad %s y %d"
L.GUIDE_REACHED_BEFORE = "alcanzado antes de llegar Pagle"
L.GUIDE_REACHED = "alcanzado el %s"
L.GUIDE_TO_GO = "faltan %d puntos"
L.GUIDE_LATER = "para más tarde"
L.GUIDE_ACCOUNT = "Todos los personajes de esta cuenta escriben en el mismo Libro. Entra con otro y Pagle "
	.. "también lee su habilidad de Pesca."
L.GUIDE_NOTE = "Activa una parte más tarde y repasará *cada Captura* desde hoy, y luego reseñará lo que "
	.. "habías ganado."
L.NOTE_FRESH = "Has estado fuera, así que tus próximas Capturas dan XP extra. Eso es *Agua fresca*, el azul de tu "
	.. "barra. Un descanso nunca es una penalización."
L.PRESTIGE_LETTER_KICKER = "Una carta, dejada en el muelle"
L.PRESTIGE_LETTER_TEXT = "Sesenta: la cima de la subida. Empieza un Libro nuevo cuando quieras. Tu nivel vuelve a "
	.. "empezar desde 1, tu Libro recibe una marca de Prestigio y no pierdes nada de lo que has ganado. O quédate en "
	.. "sesenta todo el tiempo que quieras."
L.PRESTIGE_LETTER_SHOW = "Muéstramelo"
L.PRESTIGE_LETTER_LATER = "Más tarde"
L.NOTE_PRESTIGE = "*Empieza un Libro nuevo* aquí, cuando estés listo. Sin prisa."
L.FIRST_LOOK_TITLE = "el Diario de peces"
L.FIRST_LOOK_TILE = "Cada agua que pescas tiene su casilla. Su rango sube de *Visitante* a *Maestro*."
L.FIRST_LOOK_XP_BAR = "Tu Nivel de Pescador. El tramo *azul* es Agua fresca: XP extra tras un descanso."
L.FIRST_LOOK_NOTES = "Notas para mí: lo que está más cerca de terminar. Se reescriben mientras pescas."
L.FIRST_LOOK_SEARCH = "Busca unas aguas o un pez. Un pez que no has capturado *nunca tiene nombre*."
L.FIRST_LOOK_UNFISHED = "Las casillas punteadas son aguas que aún no has pescado, con la habilidad que piden."
L.FIRST_LOOK_AGAIN = "Volver a mostrar las notas de esta página"

L.COLLECTION_CONTENTS = "La Colección: aspectos y títulos"
L.COLLECTION_CRUMB = "La Colección"
L.COLLECTION_TITLE = "La Colección"
L.COLLECTION_NEW_COUNT = "nuevos: %s"
L.COLLECTION_NEW_MARK = "¡nuevo!"
L.COLLECTION_SEARCH_HINT = "Busca un aspecto…"
L.COLLECTION_SEARCH_LOOKS = "Aspectos"
L.COLLECTION_SLASH_HELP = "Abre la Colección del Diario de peces"
L.COLLECTION_LINE = "Todos los aspectos de Pagle: los que llevas, los que guardas y cómo ganar el resto."
L.COLLECTION_OF = "%s de %s"
L.COLLECTION_WEARING = "Llevas %s"
L.COLLECTION_SIGNED = "Firmado “%s”"
L.COLLECTION_REACH = "A tu alcance"
L.COLLECTION_LATELY = "Añadidos hace poco"
L.COLLECTION_NEWEST_FIRST = "los más nuevos primero"
L.COLLECTION_SEAL = "%s\nde %s"
L.COLLECTION_ADDED_BOUGHT = "Comprado"
L.COLLECTION_ADDED_CRATE = "De un Cofre de curiosidades"
L.COLLECTION_ADDED_EARNED = "Ganado"
L.COLLECTION_FOR_SALE_ONE = "%s aspecto a la venta que aún no tienes."
L.COLLECTION_FOR_SALE_OTHER = "%s aspectos a la venta que aún no tienes."
L.COLLECTION_OPEN_SHOP = "Abrir la Tienda de Curiosidades"
L.COLLECTION_SHELF_KICKER = "La Colección"
L.COLLECTION_YOURS_COUNT = "%s de %s tuyos"
L.COLLECTION_TAB_ALL = "Todos"
L.COLLECTION_TAB_YOURS = "Tuyos"
L.COLLECTION_TAB_EARN = "Por ganar"
L.COLLECTION_TAB_SHOP = "En la tienda"
L.COLLECTION_TAG_IN_USE = "En uso"
L.COLLECTION_TAG_SIGNED = "firmado como"
L.COLLECTION_TAG_YOURS = "Tuyo"
L.COLLECTION_TAG_DEFAULT = "Por defecto"
L.COLLECTION_TAG_CRATE = "Cofre de curiosidades"
L.COLLECTION_TAG_PUT_AWAY = "Guardado"
L.COLLECTION_SLOT_NAMES = {
	["core.toaststyle"] = { "Estilo de aviso emergente", "Estilos de aviso emergente" },
	["core.soundset"] = { "Juego de sonidos", "Juegos de sonidos" },
	["core.binding"] = { "Encuadernación", "Encuadernaciones" },
	["core.crest"] = { "Blasón de ex libris", "Blasones de ex libris" },
}
L.COLLECTION_TRACKER_FRAME = "Marco de rastreador"
L.COLLECTION_TRACKER_FRAMES = "Marcos de rastreador"
L.COLLECTION_TITLE_ONE = "Título"
L.COLLECTION_TITLE_OTHER = "Títulos"
L.COLLECTION_TITLE_GROUPS = {
	levels = "Niveles y Prestigio",
	wardens = "Guardianes",
	legends = "Leyendas",
	ledger = "El Libro entero",
}
L.COLLECTION_AUTOMATIC_NOTE = "Tu título de nivel más alto, sea cual sea"
L.COLLECTION_TITLE_DESCRIPTION = "Un título del Libro. Firma el Libro con él, y se muestra en tu placa de latón y "
	.. "en tu ex libris."
L.COLLECTION_EARN_MASTER = "Maestro en %s"
L.COLLECTION_EARN_LEGEND = "Primera Captura de %s"
L.COLLECTION_EARN_JUNK = "Llena el Museo de trastos"
L.COLLECTION_EARN_TREASURE = "Encuentra todos los Tesoros"
L.COLLECTION_EARN_TROPHY = "Captura todos los pesos de trofeo"
L.COLLECTION_MODULES = {
	Core = "Pagle",
	Ledger = "Libro de registro",
	Hunts = "Cazas",
	Stats = "Estadísticas",
	TackleBoard = "Tablón de aparejos",
	QoL = "Comodidades",
}
L.COLLECTION_SIGNED_AS = "Firmado como"
L.COLLECTION_STAGE_LINE = "%s · Nivel de Pescador %d"
L.COLLECTION_BEFORE = "Un aspecto antes de tenerlo"
L.COLLECTION_SOURCE_DEFAULT = "Por defecto"
L.COLLECTION_SOURCE_SHOP = "Tienda de Curiosidades"
L.COLLECTION_SOURCE_CRATE = "Solo en Cofre de curiosidades"
L.COLLECTION_SOURCE_REWARD = "Recompensa de %s"
L.COLLECTION_IN_USE = "En uso"
L.COLLECTION_USE = "Úsalo"
L.COLLECTION_WEAR = "Llévalo"
L.COLLECTION_SIGN = "Firma con él"
L.COLLECTION_EFFECTS = {
	["core.toaststyle"] = "Todos los Anuncios lo llevan.",
	["core.soundset"] = "Suena en cada Anuncio.",
	["core.binding"] = "Todos tus libros la llevan.",
	["core.crest"] = "Prendido en tu ex libris.",
}
L.COLLECTION_EFFECT_TRACKER = "En el rastreador de %s."
L.COLLECTION_EFFECT_TITLE = "El Libro va firmado con él."
L.COLLECTION_HOW_DEFAULT = "Gratis, y siempre tuyo."
L.COLLECTION_HOW_BOUGHT = "Comprado el %s por %s Monedas."
L.COLLECTION_HOW_BOUGHT_FREE = "Comprado el %s."
L.COLLECTION_HOW_CRATE = "De un Cofre de curiosidades, el %s."
L.COLLECTION_HOW_EARNED = "Ganado el %s: %s."
L.COLLECTION_HOW_EARNED_DATE = "Ganado el %s."
L.COLLECTION_HOW_EARNED_LINE = "Ganado: %s."
L.COLLECTION_HOW_TO_EARN = "Cómo ganarlo"
L.COLLECTION_COUNT = "%s de %s"
L.COLLECTION_COUNT_UNIT = "%s de %s %s"
L.COLLECTION_FALLBACK = "¿Sin ganar para el %s? Entonces también sale a la venta, por %s Monedas."
L.COLLECTION_BUY = "Comprar en la Tienda de Curiosidades"
L.COLLECTION_ENOUGH = "Tienes %s Monedas, suficiente."
L.COLLECTION_SHORT = "Tienes %s Monedas: faltan %s."
L.COLLECTION_CRATE_ONLY = "Solo sale de un Cofre de curiosidades."
L.COLLECTION_OPEN_CRATE = "Abrir un cofre"
L.COLLECTION_CRATE_NOTE = "Nunca a la venta y nunca ganado: lo da un cofre, o nada."
L.COLLECTION_PUT_AWAY = "Guardado: %s está desactivado"
