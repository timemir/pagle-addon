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
-- EN: "Caught", "In its element", "Regular"
local PARTS = "Interface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts"
-- EN: Interface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts
local function sprite(x, y, w, h, size)
	return ("|T%s:%s:0:0:1024:2048:%d:%d:%d:%d|t"):format(PARTS, size or "0:0", x, x + w, y, y + h)
end
local STAR = sprite(650, 1126, 23, 23)
local TICK = sprite(486, 1586, 27, 20, "11:15")
local BEGIN_A_NEW_LEDGER = "Empezar un Libro nuevo"
-- EN: Begin a new Ledger
local ZONE_REWARD = "Recompensa por maestría: cada sello nuevo da XP."
-- EN: Reward for mastery: each new seal earns XP.
local UNWRITTEN_LEGEND = "leyenda sin escribir"
-- EN: unwritten legend
local IN_THIS_LEDGER = "En este Libro"
-- EN: In this Ledger

L.UNFISHED = "sin pescar"
-- EN: unfished
L.POOLS = "bancos"
-- EN: pools
L.TROPHY_TITLE = "La Sala de trofeos"
-- EN: The Trophy Room

L.TITLE = "Libro de registro"
-- EN: Ledger

L.SUMMARY_LINE = "Libro: Nivel de Pescador %d · %d%% completado"
-- EN: Ledger: Angler Level %d · %d%% complete
L.SUMMARY_LINE_PRESTIGE = "Libro: Prestigio %d · Nivel de Pescador %d · %d%% completado"
-- EN: Ledger: Prestige %d · Angler Level %d · %d%% complete

L.ITEM_FALLBACK = "Objeto %d"
-- EN: Item %d
L.CONTINENT_NAMES = { [0] = "Reinos del Este", [1] = "Kalimdor" }
-- EN: { "Kalimdor", [0] = "Eastern Kingdoms" }
L.OTHER_WATERS = "Otras aguas"
-- EN: Other waters

L.BINDING_EARNED = "Nivel de Pescador %d"
-- EN: Angler Level %d
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
	heartwood = "Una pieza tras 10 que se escaparon",
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
-- EN: { blueprint = "Catch 100 fish as a Gnome", carapace = "50 Big-mouth Clams", cartographer = "Master in 5 zones", crier = "Catch 100 fish as a Human", deep = "100 catches after midnight", drum = "Catch 100 fish as an Orc", ember = "Prestige VII", flywallet = "5 different lures", glade = "Catch 100 fish as a Night Elf", glass = "12 glass shards", hall = "Catch 100 fish as a Dwarf", heartwood = "A catch after 10 got away", hex = "Catch 100 fish as a Troll", ice = "100 catches on the ice", knit = "10,000 Casts", koi = "25 pairs in a row", lacquer = "30 days fished", ledger = "Complete the Ledger", legend = "Land a Legend", legends = "Land all three Legends", lion = "Catch 300 fish on Alliance characters", logbook = "25 zones fished", monster = "Land a Monster", prestige1 = "Prestige I", prestige10 = "Prestige X", prestige5 = "Prestige V", shroud = "Catch 100 fish as an Undead", slate = "30 Species", stitch = "The sampler's 20 fish", stormglass = "Master in 10 zones", totem = "Catch 100 fish as a Tauren", trophy = "25 size records", varieties = "Every fish in every colour", warband = "Catch 300 fish on Horde characters", wave = "300 catches at sea" }
L.EARNED_COUNT = "%s de %s %s"
-- EN: %s of %s %s
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
-- EN: { blueprint = "fish", carapace = "clams", cartographer = "zones", crier = "fish", deep = "catches", drum = "fish", flywallet = "lures", glade = "fish", glass = "shards", hall = "fish", hex = "fish", ice = "catches", knit = "Casts", koi = "pairs", lacquer = "days", lion = "fish", logbook = "zones", shroud = "fish", slate = "Species", stitch = "fish", stormglass = "zones", totem = "fish", trophy = "records", warband = "fish", wave = "catches" }

L.CREST_UNFISHED = "Sin pescar"
-- EN: Unfished
L.CREST_UNCHARTED = "Aún sin catalogar"
-- EN: Not yet charted
L.CREST_NOTE_PROGRESS = "Se gana cuando %s llega a Maestro en el Diario de peces. Ahora es %s, %d%%. %s."
-- EN: Earned when %s reaches Master in the Fish Journal. It is %s, %d%%. %s.
L.CREST_NOTE_UNFISHED = "Se gana cuando %s llega a Maestro en el Diario de peces. Pesca algo allí para empezar."
-- EN: Earned when %s reaches Master in the Fish Journal. Catch anything there to begin.
L.CREST_NOTE_UNCHARTED = "Se gana cuando %s llega a Maestro en el Diario de peces, cuando sus aguas estén catalogadas."
-- EN: Earned when %s reaches Master in the Fish Journal, once its waters are charted.

L.LEVEL_UP_TITLE = "Nivel de Pescador %d"
-- EN: Angler Level %d
L.LEVEL_UP_STAMP = "Nivel %d"
-- EN: Level %d
L.LEVELS_RAISED_ONE = "+%d nivel"
-- EN: +%d level
L.LEVELS_RAISED_OTHER = "+%d niveles"
-- EN: +%d levels
L.NEW_SPECIES_TITLE = "Nueva Especie"
-- EN: New Species
L.NEW_SPECIES_STAMP = "¡Nueva!"
-- EN: New!
L.NEW_SPECIES_FIRST_NOTE = "Una Especie nueva para tu Libro."
-- EN: A new Species for your Ledger.
L.NEW_IN_ZONE_TITLE = "Nuevo aquí"
-- EN: New here
L.NEW_IN_ZONE_TEXT = "%s en %s"
-- EN: %s in %s
L.NEW_IN_ZONE_STAMP = "Nuevo aquí"
-- EN: New here
L.SKILL_MILESTONE_TITLE = "Hito de habilidad"
-- EN: Skill Milestone
L.SKILL_MILESTONE_TEXT = "Pesca %d"
-- EN: Fishing %d
L.ZONE_RANK_TITLE = "Rango de zona: %s"
-- EN: Zone rank: %s
L.ZONE_RANK_STAMP = "Sube de rango"
-- EN: Rank up
L.ZONE_MASTER_TITLE = "Maestro de zona"
-- EN: Zone Master
L.ZONE_MASTER_STAMP = "Maestro"
-- EN: Master
L.CREST_EARNED = "Ganado: %s"
-- EN: Earned: %s
L.TROPHY_WEIGHT_TITLE = "Peso de trofeo"
-- EN: Trophy weight
L.TROPHY_WEIGHT_STAMP = "Trofeo"
-- EN: Trophy
L.NEW_CURIO_TITLE = "Nueva curiosidad"
-- EN: New curio
L.NEW_CURIO_STAMP = "¡Nueva!"
-- EN: New!
L.UNCHARTED_TITLE = "Captura desconocida, registrada"
-- EN: Unknown catch, logged
L.UNCHARTED_STAMP = "Registrada"
-- EN: Logged
L.LEGEND_TITLE = "Leyenda"
-- EN: Legend
L.LEGEND_STAMP = "¡Leyenda!"
-- EN: Legend!
L.PRESTIGE_READY_TITLE = "Prestigio listo"
-- EN: Prestige ready
L.PRESTIGE_READY_TEXT = "Abre el Diario de peces para empezar un Libro nuevo."
-- EN: Open the Fish Journal to begin a new Ledger.
L.PRESTIGE_READY_STAMP = "Prestigio listo"
-- EN: Prestige ready
L.PRESTIGE_TITLE = "Prestigio %s"
-- EN: Prestige %s
L.MASTER_PRESTIGE_TITLE = "Prestigio de Maestro %d"
-- EN: Master Prestige %d
L.CATCHES_ONE = "%s Captura"
-- EN: %s Catch
L.CATCHES_OTHER = "%s Capturas"
-- EN: %s Catches
L.SIZE_RECORD_TITLE = "Récord de tamaño"
-- EN: Size record
L.SIZE_RECORD_STAMP = "Récord"
-- EN: Record
L.RULER_LENGTH = "longitud"
-- EN: length
L.NEW_VARIETY_TITLE = "Nueva variedad"
-- EN: New variety
L.NEW_VARIETY_STAMP = "Nueva variedad"
-- EN: New variety
L.RARE_VARIETY_TITLE = "Variedad rara"
-- EN: Rare variety
L.EPIC_VARIETY_TITLE = "Variedad épica"
-- EN: Epic variety
L.EVERY_COLOUR_TITLE = "Todos los colores de %s"
-- EN: Every colour of %s
L.EVERY_COLOUR_STAMP = "Todos los colores"
-- EN: Every colour
L.TITLE_LINE = "Título: %s"
-- EN: Title: %s
L.TITLE_EARNED = "Título ganado"
-- EN: Title earned
L.CAUGHT_STAR_TITLE = CAUGHT
-- EN: Caught
L.ELEMENT_STAR_TITLE = IN_ITS_ELEMENT
-- EN: In its element
L.REGULAR_STAR_TITLE = REGULAR
-- EN: Regular
L.FAMILY_STAR_TITLE = "Familia de trofeos"
-- EN: Trophy family

L.ZONE_RANKS = { "Visitante", "Habitual", "Local", "Experto", "Maestro" }
-- EN: { "Visitor", "Regular", "Local", "Expert", "Master" }

L.ZONE_NEXT_VISITOR = "Pesca algo aquí para ser Visitante"
-- EN: Catch anything here to become a Visitor
L.ZONE_NEXT_REGULAR_ONE = "Habitual: %d Especie más a cualquier hora"
-- EN: Regular: %d more any-time Species
L.ZONE_NEXT_REGULAR_OTHER = "Habitual: %d Especies más a cualquier hora"
-- EN: Regular: %d more any-time Species
L.ZONE_NEXT_LOCAL_ONE = "Local: %d Especie más a cualquier hora"
-- EN: Local: %d more any-time Species
L.ZONE_NEXT_LOCAL_OTHER = "Local: %d Especies más a cualquier hora"
-- EN: Local: %d more any-time Species
L.ZONE_NEXT_EXPERT = "Experto: %s"
-- EN: Expert: %s
L.ZONE_NEXT_GATED_ONE = "%d captura más de día, noche, temporada o evento"
-- EN: %d more day, night, seasonal or event catch
L.ZONE_NEXT_GATED_OTHER = "%d capturas más de día, noche, temporada o evento"
-- EN: %d more day, night, seasonal or event catches
L.ZONE_NEXT_JUNK = "un trasto"
-- EN: a piece of junk
L.ZONE_NEXT_TREASURE = "un tesoro"
-- EN: a treasure
L.ZONE_NEXT_MASTER_ONE = "Maestro: un trofeo de %d familia más"
-- EN: Master: a trophy from %d more family
L.ZONE_NEXT_MASTER_OTHER = "Maestro: un trofeo de %d familias más"
-- EN: Master: a trophy from %d more families
L.ZONE_NEXT_MASTERED = "Maestro de estas aguas"
-- EN: Master of these waters
L.ZONE_NEW_TO_FIND_ONE = "%d por descubrir: los datos crecieron, y tu sello se queda"
-- EN: %d new to find: the data grew, and your seal stays
L.ZONE_NEW_TO_FIND_OTHER = "%d por descubrir: los datos crecieron, y tu sello se queda"
-- EN: %d new to find: the data grew, and your seal stays

L.WRITE_UP_FIRST_BUILD_ONE = "Tu Libro se ha escrito a partir de %s Lance"
-- EN: Your Ledger was written up from %s Cast
L.WRITE_UP_FIRST_BUILD_OTHER = "Tu Libro se ha escrito a partir de %s Lances"
-- EN: Your Ledger was written up from %s Casts
L.WRITE_UP_WHILE_OFF = "Mientras el Libro estaba desactivado"
-- EN: While the Ledger was off
L.WRITE_UP_LEVEL = "Nivel de Pescador %d"
-- EN: Angler Level %d
L.WRITE_UP_LEVEL_ROSE = "Nivel de Pescador %d a %d"
-- EN: Angler Level %d to %d
L.WRITE_UP_SPECIES_ONE = "%d Especie"
-- EN: %d Species
L.WRITE_UP_SPECIES_OTHER = "%d Especies"
-- EN: %d Species
L.WRITE_UP_VARIETIES_ONE = "%d variedad"
-- EN: %d variety
L.WRITE_UP_VARIETIES_OTHER = "%d variedades"
-- EN: %d varieties
L.WRITE_UP_EVERY_COLOUR_ONE = "%d pez en todos los colores"
-- EN: %d fish in every colour
L.WRITE_UP_EVERY_COLOUR_OTHER = "%d peces en todos los colores"
-- EN: %d fish in every colour
L.WRITE_UP_ZONES_ONE = "%d zona con rango"
-- EN: %d zone ranked
L.WRITE_UP_ZONES_OTHER = "%d zonas con rango"
-- EN: %d zones ranked
L.WRITE_UP_MASTERED_ONE = "%d dominada"
-- EN: %d mastered
L.WRITE_UP_MASTERED_OTHER = "%d dominadas"
-- EN: %d mastered
L.WRITE_UP_TROPHY_ONE = "%d peso de trofeo"
-- EN: %d trophy weight
L.WRITE_UP_TROPHY_OTHER = "%d pesos de trofeo"
-- EN: %d trophy weights
L.WRITE_UP_CURIO_ONE = "%d curiosidad"
-- EN: %d curio
L.WRITE_UP_CURIO_OTHER = "%d curiosidades"
-- EN: %d curios
L.WRITE_UP_WITH_PRESTIGE = "%s · Prestigio %d"
-- EN: %s · Prestige %d
L.WRITE_UP_LEGENDS_ONE = "%d Leyenda"
-- EN: %d Legend
L.WRITE_UP_LEGENDS_OTHER = "%d Leyendas"
-- EN: %d Legends
L.WRITE_UP_MORE_TITLES_ONE = "+%d título más"
-- EN: +%d more title
L.WRITE_UP_MORE_TITLES_OTHER = "+%d títulos más"
-- EN: +%d more titles
L.WRITE_UP_SKILL_ONE = "%d Hito de habilidad"
-- EN: %d Skill Milestone
L.WRITE_UP_SKILL_OTHER = "%d Hitos de habilidad"
-- EN: %d Skill Milestones
L.WRITE_UP_COINS = "Monedas Pagle +%s"
-- EN: Pagle Coins +%s

L.JOURNAL = "Diario de peces"
-- EN: Fish Journal
L.JOURNAL_SLASH_HELP = "Abre o cierra el Diario de peces"
-- EN: Open or close the Fish Journal
L.JOURNAL_UPDATING = "El Libro se está escribiendo a partir de tu Registro de capturas."
-- EN: The Ledger is being written up from your Catch log.
L.JOURNAL_HOME = "Inicio"
-- EN: Home
L.JOURNAL_BACK = "« volver"
-- EN: « back
L.JOURNAL_SEARCH_HINT = "Busca un pez o unas aguas…"
-- EN: Find a fish or a water…
L.JOURNAL_HELP_CHART = "Ayuda a catalogar las aguas"
-- EN: Help chart the waters
L.JOURNAL_CHART_PROMPT = "¿Has visto algo que Pagle no conoce?"
-- EN: Seen something Pagle doesn't know?
L.HOME_KICKER = "Las aguas"
-- EN: The Waters
L.HOME_TITLE = "Donde he pescado"
-- EN: Where I've Fished
L.HOME_NOTES = "Notas para mí"
-- EN: Notes to self
L.HOME_NOTE_NEW = "%s: %d por descubrir"
-- EN: %s: %d new to find
L.HOME_NOTE_CAUGHT_STAR = "%s: %d para " .. STAR
-- EN: %s: %d to |TInterface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts:0:0:0:0:1024:2048:650:673:1126:1149|t
L.HOME_NOTE_STAR = "%s: %d para " .. STAR:rep(3)
-- EN: %s: %d to |TInterface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts:0:0:0:0:1024:2048:650:673:1126:1149|t|TInterface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts:0:0:0:0:1024:2048:650:673:1126:1149|t|TInterface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts:0:0:0:0:1024:2048:650:673:1126:1149|t
L.HOME_NOTE_NONE = "¡A pescar!"
-- EN: Go fishing!
L.HOME_LEVEL = "Nivel de Pescador"
-- EN: Angler Level
L.HOME_CONTENTS = IN_THIS_LEDGER
-- EN: In this Ledger
L.HOME_SEAL_WORD = "Libro"
-- EN: Ledger
L.HOME_CURIOS = "Curiosidades: trastos, tesoros, sin catalogar"
-- EN: Curios: junk, treasure, uncharted
L.HOME_ANGLER = "El Pescador: manos e hitos"
-- EN: The Angler: hands and milestones
L.BRASS_PLATE = "Nv %d · Libro %d%%"
-- EN: Lv %d · Ledger %d%%
L.BRASS_PLATE_TITLE = "Nv %d · %s · Libro %d%%"
-- EN: Lv %d · %s · Ledger %d%%

L.MONTHS_SHORT = { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic" }
-- EN: { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
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
-- EN: { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

L.WINDOWS = {
	day = "día",
	night = "noche",
	spring = "primavera",
	summer = "verano",
	autumn = "otoño",
	winter = "invierno",
	["event.301"] = "Torneo de pesca",
}
-- EN: { autumn = "autumn", day = "day", ["event.301"] = "Extravaganza", night = "night", spring = "spring", summer = "summer", winter = "winter" }
L.WINDOW_EVENT = "evento"
-- EN: event
L.WINDOW_OPEN = "pican ahora"
-- EN: biting now
L.WINDOW_BACK_HOURS = "vuelve en %d h"
-- EN: back in %d h
L.WINDOW_BACK_MINUTES = "vuelve en %d min"
-- EN: back in %d min
L.WINDOW_BACK_MONTH = "vuelve en %s"
-- EN: back in %s

L.XP_BAR_TEXT = "%s de %s."
-- EN: %s of %s.
L.XP_BAR_FRESH_ONE = " Agua fresca para %d Captura más."
-- EN: " Fresh Water for %d more Catch."
L.XP_BAR_FRESH_OTHER = " Agua fresca para %d Capturas más."
-- EN: " Fresh Water for %d more Catches."
L.XP_BAR_SET_ASIDE = "%s XP reservada para el próximo Prestigio"
-- EN: %s XP set aside for the next Prestige
L.XP_BAR_TIP_TITLE = "De dónde vino la XP de esta subida"
-- EN: Where this climb's XP came from
L.XP_BAR_TIP_NOTE = "por fuente, aproximado"
-- EN: by source, roughly
L.XP_SOURCE_OWN = "Capturas y descubrimientos"
-- EN: Catches and discoveries
L.XP_SOURCE_NAMES = {
	Hunts = "Cazas",
	TackleBoard = "Tablón de aparejos",
}
-- EN: { Hunts = "Hunts", TackleBoard = "Tackle Board" }

L.HINT_ANY_TIME = "A cualquier hora"
-- EN: Any time
L.HINT_SKILL = "habilidad ~%d"
-- EN: skill ~%d
L.HINT_ANY_SKILL = "cualquier habilidad"
-- EN: any skill

L.TILE_NEW = "¡Nuevos: %d!"
-- EN: %d new!
L.TILE_UNFISHED_SKILL = "sin pescar · habilidad ~%d"
-- EN: unfished · skill ~%d
L.TILE_UNFISHED_ANY_SKILL = "sin pescar · cualquier habilidad"
-- EN: unfished · any skill
L.TILE_UNCHARTED = "aguas sin catalogar"
-- EN: uncharted waters

L.LIST_LAST = " y "
-- EN: " and "
L.ENTRY_STAMPS = { CAUGHT, IN_ITS_ELEMENT, REGULAR }
-- EN: { "Caught", "In its element", "Regular" }
L.STAMP_TIP_LAND_ONE = "Captúralo %d vez."
-- EN: Land it %d time.
L.STAMP_TIP_LAND_OTHER = "Captúralo %d veces."
-- EN: Land it %d times.
L.STAMP_TIP_LANDED = "%d de %d capturados."
-- EN: %d of %d landed.
L.STAMP_TIP_ELEMENT_WINDOW = "Captúralo en su ventana de elemento, en cualquier zona."
-- EN: Land it under its element window, in any zone.
L.STAMP_TIP_ELEMENT_WINDOWS = "Captúralo en cada una de sus %d ventanas de elemento, en cualquier zona."
-- EN: Land it under each of its %d element windows, in any zone.
L.STAMP_TIP_ELEMENT_NEEDED = "%d de %d cumplidas. Faltan: %s."
-- EN: %d of %d met. Still needed: %s.
L.STAMP_TIP_ELEMENT_MET = "Todas cumplidas: %s."
-- EN: All met: %s.
L.STAMP_TIP_ZONE = "Captúralo en cualquier zona."
-- EN: Land it in any zone.
L.STAMP_TIP_ZONES = "Captúralo en %d zonas distintas."
-- EN: Land it in %d different zones.
L.STAMP_TIP_ZONES_ONE = "En %d de %d zona."
-- EN: In %d of %d zone.
L.STAMP_TIP_ZONES_OTHER = "En %d de %d zonas."
-- EN: In %d of %d zones.
L.ENTRY_FIRST = "Primera captura el %s en %s, por %s. %s en total."
-- EN: First landed %s in %s, by %s. %s caught.
L.ENTRY_FIRST_NO_ZONE = "Primera captura el %s, por %s. %s en total."
-- EN: First landed %s, by %s. %s caught.
L.ENTRY_FOUND_IN = "Se encuentra en %s."
-- EN: Found in %s.
L.ENTRY_ONLY_BY = " Solo de %s."
-- EN: " Only by %s."
L.ENTRY_LARGEST = "El más grande que he sacado: %s"
-- EN: Largest I've landed: %s
L.ENTRY_REMOVED = "Ya no está en las aguas de Forever."
-- EN: No longer found in Forever's waters.
L.ENTRY_UNKNOWN = "Un pez desconocido"
-- EN: An unknown fish
L.ENTRY_HINT_LINK = "Leer la pista sencilla »"
-- EN: Read the plain hint »
L.FISH_KICKER = "Dónde encontrarlo"
-- EN: Where to find it
L.FISH_TITLE = "Sus aguas"
-- EN: Its waters
L.FISH_CAUGHT_HERE = "capturado " .. TICK
-- EN: caught |TInterface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts:11:15:0:0:1024:2048:486:513:1586:1606|t
L.FISH_WHEN = "Cuándo"
-- EN: When
L.FISH_CAUGHT = "%s " .. CAUGHT .. " (%d/%d)"
-- EN: %s Caught (%d/%d)
L.FISH_ELEMENT = "%s " .. IN_ITS_ELEMENT .. " (%d/%d)"
-- EN: %s In its element (%d/%d)
L.FISH_REGULAR = "%s " .. REGULAR .. " (%d/%d)"
-- EN: %s Regular (%d/%d)
L.FISH_VARIETIES = "Variedades"
-- EN: Varieties
L.FISH_VARIETIES_COUNT = "%d de %d encontradas"
-- EN: %d of %d found
L.FISH_VARIETIES_LINK = "Ver las diez »"
-- EN: See all ten »
L.VARIETIES_TITLE = "Sus colores"
-- EN: Its colours
L.VARIETIES_CAUGHT = "%d de %d capturadas"
-- EN: %d of %d caught
L.VARIETY_COUNT = "Capturas: %s"
-- EN: %s caught
L.VARIETY_UNDISCOVERED = "Sin descubrir"
-- EN: Undiscovered
L.VARIETY_KICKER = {
	common = "Un color común",
	uncommon = "Un color poco común",
	rare = "Un color raro",
	epic = "Un color épico",
}
-- EN: { common = "A common colour", epic = "An epic colour", rare = "A rare colour", uncommon = "An uncommon colour" }
L.VARIETY_NOT_DISCOVERED = "Aún sin descubrir"
-- EN: Not yet discovered
L.VARIETY_ODDS = "Aún sin pescar. Más o menos una Captura de cada %s."
-- EN: Not landed yet. About one Catch in %s.
L.VARIETY_ALL_TEN = "Las diez."
-- EN: All ten.
L.VARIETY_TO_GO = "Faltan %d."
-- EN: %d to go.
L.SEARCH_NONE = "Aún no hay nada con ese nombre en el Libro."
-- EN: Nothing by that name in the Ledger yet.
L.SEARCH_WATERS = "Aguas"
-- EN: Waters
L.SEARCH_FISH = "Peces"
-- EN: Fish

L.ANGLER_CRUMB = "El Pescador"
-- EN: The Angler
L.ANGLER_EX_LIBRIS = "Ex libris"
-- EN: Ex Libris
L.ANGLER_LEDGER = "El Libro del Pescador"
-- EN: The Angler's Ledger
L.ANGLER_KEPT_SINCE = "llevado desde el %s"
-- EN: kept since %s
L.ANGLER_TALLY = "El Libro"
-- EN: The Ledger
L.ANGLER_COMPLETE = "%d%% del Libro completado (%s de %s)"
-- EN: %d%% of the Ledger complete (%s of %s)
L.ANGLER_PARTS = {
	species = "Especies",
	varieties = "Variedades",
	junk = "Museo de trastos",
	treasure = "Tesoros",
	trophy = "Pesos de la Sala de trofeos",
	zones = "Zonas dominadas",
}
-- EN: { junk = "Junk Museum", species = "Species", treasure = "Treasures", trophy = "Trophy Room weights", varieties = "Varieties", zones = "Zones mastered" }
L.ANGLER_PART_COUNT = "%s de %s"
-- EN: %s of %s
L.ANGLER_CATCHES_ONE = "%s Captura"
-- EN: %s Catch
L.ANGLER_CATCHES_OTHER = "%s Capturas"
-- EN: %s Catches
L.ANGLER_HANDS = "Manos en la caña"
-- EN: Hands on the Rod
L.ANGLER_HAND = "habilidad %d / %d"
-- EN: skill %d / %d
L.ANGLER_MILESTONES = "Hitos"
-- EN: Milestones
L.ANGLER_NEXT_MILESTONE = " · próximo hito: %s"
-- EN: " · next milestone %s"
L.ANGLER_NO_PRESTIGE = "Aún sin Prestigio"
-- EN: No Prestige yet
L.ANGLER_PRESTIGE = BEGIN_A_NEW_LEDGER .. " (Prestigio)"
-- EN: Begin a new Ledger (Prestige)
L.ANGLER_AUTOMATIC = "Automático"
-- EN: Automatic
L.ANGLER_XP_SOURCES = "De dónde vino tu XP"
-- EN: Where your XP came from
L.ANGLER_XP_CLIMB = "Esta subida"
-- EN: This climb
L.ANGLER_XP_ALL = "En total"
-- EN: All told

L.ZONE_NEXT = "Siguiente: %s"
-- EN: Next: %s
L.ZONE_NEW_HERE_ONE = "¡%d por descubrir aquí! Mi sello se queda."
-- EN: %d new to find here! My seal stays.
L.ZONE_NEW_HERE_OTHER = "¡%d por descubrir aquí! Mi sello se queda."
-- EN: %d new to find here! My seal stays.
L.ZONE_GROUPS = {
	anyTime = "A cualquier hora",
	pools = "Bancos",
	dayNight = "Día y noche",
	seasonal = "De temporada",
	events = "Eventos",
	trophies = "Trofeos",
	curios = "Curiosidades",
}
-- EN: { anyTime = "Any time", curios = "Curios", dayNight = "Day and night", events = "Events", pools = "Pools", seasonal = "Seasonal", trophies = "Trophies" }
L.ZONE_POOLS_NOTE = "aguas abiertas y bancos juntos"
-- EN: open water and pools combined
L.ZONE_TROPHY = "un trofeo de %s, cualquier peso"
-- EN: a %s trophy, any weight
L.ZONE_ALSO_NOTE = "Aún no está en la lista de Pagle para estas aguas."
-- EN: Not in Pagle's list for these waters yet.
L.ZONE_UNKNOWN_FISH = "— desconocido —"
-- EN: — unknown —
L.ZONE_CAUGHT_ELSEWHERE = "%s (capturado en otro sitio)"
-- EN: %s (caught elsewhere)
L.ZONE_ABOUT = "Sobre estas aguas"
-- EN: About these waters
L.ZONE_SKILL = "Habilidad ~%d"
-- EN: Skill ~%d
L.ZONE_ANY_SKILL = "Cualquier habilidad"
-- EN: Any skill
L.ZONE_KNOWN = "%d%% de estas aguas conocido: %d de %d peces, %d de %d familias de trofeos"
-- EN: %d%% of these waters known: %d of %d fish, %d of %d trophy families
L.ZONE_TROPHIES_HERE = "Trofeos capturados aquí"
-- EN: Trophies landed here
L.ZONE_REWARD = ZONE_REWARD
-- EN: Reward for mastery: each new seal earns XP.
L.ZONE_REWARD_TITLE = ZONE_REWARD .. " El sello de Maestro da el título %s."
-- EN: Reward for mastery: each new seal earns XP. The Master seal earns the title %s.
L.ZONE_PICK = "Elige un pez a la izquierda para leer su página."
-- EN: Pick a fish on the left to read its page.
L.ZONE_UNCHARTED_NOTE = "Cada pieza de aquí sigue anotada, y cuenta en cuanto los datos de Pagle se pongan al día."
-- EN: Every catch here is still written down, and counted once Pagle's data catches up.
L.ZONE_LOOSE_PAGES = "Hojas sueltas"
-- EN: Loose pages
L.ZONE_LOOSE_TITLE = "Lo que salió aquí"
-- EN: What came up here
L.ZONE_UNCHARTED_GROUP = "Sin catalogar"
-- EN: Uncharted
L.ZONE_UNCHARTED_SEAL = "sin catalogar"
-- EN: uncharted
L.ZONE_ALSO_CAUGHT_TITLE = "También capturado aquí"
-- EN: Also caught here
L.ZONE_NOTHING_YET = "Nada capturado aquí todavía."
-- EN: Nothing caught here yet.

L.TROPHY_WEIGHTS = "%s de %s pesos."
-- EN: %s of %s weights.
L.TROPHY_KICKER = "Una colección"
-- EN: A collection
L.TROPHY_FAMILIES = "Familias"
-- EN: Families
L.TROPHY_FAMILIES_NOTE = "pesos"
-- EN: weights
L.TROPHY_FAMILY_KICKER = "Una familia de trofeos"
-- EN: A trophy family
L.TROPHY_HEAVIEST = "el más pesado"
-- EN: heaviest
L.TROPHY_STAMPS = { "Cualquier peso", "La mitad de los pesos", "El más pesado" }
-- EN: { "Any weight", "Half the weights", "The heaviest" }
L.TROPHY_TIP_ANY = "Captura cualquier peso de esta familia."
-- EN: Land any weight of this family.
L.TROPHY_TIP_NONE_YET = "Aún no has cobrado ninguno."
-- EN: None landed yet.
L.TROPHY_TIP_UNLISTED = "Capturado, aunque no está en la lista de esta familia."
-- EN: Landed, though not on this family's list.
L.TROPHY_TIP_LANDED_ONE = "%d de %d peso capturado."
-- EN: %d of %d weight landed.
L.TROPHY_TIP_LANDED_OTHER = "%d de %d pesos capturados."
-- EN: %d of %d weights landed.
L.TROPHY_TIP_HALF_ONE = "Captura su único peso de la lista."
-- EN: Land its one listed weight.
L.TROPHY_TIP_HALF_OTHER = "Captura al menos %d de sus %d pesos de la lista."
-- EN: Land at least %d of its %d listed weights.
L.TROPHY_TIP_NO_WEIGHTS = "Esta familia aún no tiene pesos en la lista."
-- EN: This family lists no weights yet.
L.TROPHY_TIP_HEAVIEST = "Captura su peso más alto de la lista, %s lb."
-- EN: Land its heaviest listed weight, %s lb.
L.TROPHY_TIP_HEAVIEST_DONE = "Capturado."
-- EN: Landed.
L.TROPHY_TIP_HEAVIEST_TODO = "Aún no."
-- EN: Not yet.
L.TROPHY_POUNDS = "libras"
-- EN: pounds
L.TROPHY_LANDED = "Capturados %s de %s. El más pesado hasta ahora: %s lb."
-- EN: Landed %s of %s. Heaviest so far: %s lb.
L.TROPHY_NONE_LANDED = "Ninguno de esta familia todavía."
-- EN: Not one of this family yet.
L.CURIOS_CRUMB = "Curiosidades"
-- EN: Curios
L.CURIOS_JUNK_KICKER = "Trastos"
-- EN: Junk
L.CURIOS_JUNK_TITLE = "El Museo de trastos"
-- EN: The Junk Museum
L.CURIOS_TREASURES_KICKER = "Contenedores y tesoros"
-- EN: Containers and treasure
L.CURIOS_EXHIBITS = "%s de %s piezas"
-- EN: %s of %s exhibits
L.CURIOS_EMPTY_PLINTH = "Un pedestal vacío"
-- EN: An empty plinth
L.CURIOS_TREASURES_TITLE = "Tesoros"
-- EN: Treasures
L.CURIOS_OPENED = "%s de %s abiertos"
-- EN: %s of %s opened
L.CURIOS_LOOSE_PAGES = "Hojas sueltas: sin catalogar"
-- EN: Loose pages: Uncharted
L.CURIOS_LOOSE_PAGE = "%s: %s× en %s, el primero el %s. Pagle no lo conoce. Registrado."
-- EN: %s: %s× at %s, first %s. Unknown to Pagle. Logged.
L.CURIOS_UNKNOWN_WATERS = "aguas desconocidas"
-- EN: unknown waters
L.CURIOS_NONE_UNCHARTED = "Ninguna. Cada pieza está en el Libro."
-- EN: None. Every catch is in the Ledger.
L.LEGENDS_TITLE = "Leyendas"
-- EN: Legends
L.LEGENDS_KICKER = "Fuera de los cien"
-- EN: Outside the hundred
L.LEGENDS_INDEX = "El índice"
-- EN: The index
L.LEGENDS_COUNT = "%s de %s. Quedan fuera de los cien del Libro."
-- EN: %s of %s. These sit outside the Ledger's hundred.
L.LEGENDS_UNWRITTEN = "una " .. UNWRITTEN_LEGEND
-- EN: an unwritten legend
L.LEGENDS_UNWRITTEN_TITLE = "Una " .. UNWRITTEN_LEGEND
-- EN: An unwritten legend
L.LEGENDS_OPEN_PLATE = "Abrir la lámina"
-- EN: Open the plate
L.LEGENDS_PLATE_RETURN = "Haz clic en cualquier sitio para volver."
-- EN: Click anywhere to return.
L.LEGENDS_PLATE_KICKER = "Una Leyenda de estas aguas"
-- EN: A Legend of these waters
L.LEGENDS_PLATE_SEAL = "Título"
-- EN: Title
L.FOLLOWING_TITLE = "Siguiendo"
-- EN: Following
L.FOLLOWING_KICKER = IN_THIS_LEDGER
-- EN: In this Ledger
L.FOLLOWING_NO_COMPANION = "sin Companion"
-- EN: no Companion
L.FOLLOWING_COUNT_ONE = "%s Pescador al que sigues. Sigue y deja de seguir en la web de Pagle."
-- EN: %s Angler you follow. Follow and unfollow on the Pagle website.
L.FOLLOWING_COUNT_OTHER = "%s Pescadores a los que sigues. Sigue y deja de seguir en la web de Pagle."
-- EN: %s Anglers you follow. Follow and unfollow on the Pagle website.
L.FOLLOWING_ROW = "Nv %d · %s · %d%%"
-- EN: Lv %d · %s · %d%%
L.FOLLOWING_ROW_NO_PRESTIGE = "Nv %d · %d%%"
-- EN: Lv %d · %d%%
L.FOLLOWING_HARDCORE = "Pescador Hardcore"
-- EN: Hardcore Angler
L.FOLLOWING_MORE_ONE = "y %s personaje más"
-- EN: and %s more character
L.FOLLOWING_MORE_OTHER = "y %s personajes más"
-- EN: and %s more characters
L.FOLLOWING_SEAL = "Libro %d%%"
-- EN: Ledger %d%%
L.FOLLOWING_LEGENDS = "Leyendas"
-- EN: Legends
L.FOLLOWING_LEGENDS_COUNT = "%s de %s"
-- EN: %s of %s
L.FOLLOWING_WATERS = "Aguas dominadas"
-- EN: Waters mastered
L.FOLLOWING_CATCHES = "Capturas totales"
-- EN: Lifetime Catches
L.FOLLOWING_AS_OF = "A fecha de %s"
-- EN: As of %s
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
-- EN: { absent = { "The Companion keeps this page.", "Anglers you follow on the Pagle website are brought into the game by the Pagle Companion.", "Without it, this page stays empty. Pasting your log still updates your own Angler page." }, expired = { "These pages are more than a day old.", "Pagle has set them aside until the Companion brings fresh ones.", "Start the Companion, then /reload." }, none = { "You follow no one yet.", "Follow an Angler from their page on the Pagle website.", "The Companion brings them in within the hour; they show here after your next /reload." } }
L.PRESTIGE_CONFIRM_KICKER = "Prestigio"
-- EN: Prestige
L.PRESTIGE_CONFIRM_TITLE = "¿" .. BEGIN_A_NEW_LEDGER .. "?"
-- EN: Begin a new Ledger?
L.PRESTIGE_CONFIRM_TEXT = "Tu Nivel de Pescador vuelve a subir desde 1. No pierdes nada de lo que has ganado."
-- EN: Your Angler Level climbs again from 1. Nothing you've earned is taken away.
L.PRESTIGE_CONFIRM_YES = "Prestigio"
-- EN: Prestige
L.PRESTIGE_CONFIRM_NO = "Aún no"
-- EN: Not yet
L.GUIDE_BLURB = "Tu libro: todas las aguas y todos los peces, tu Nivel de Pescador, récords y títulos."
-- EN: Your book: every water and every fish, your Angler Level, records and titles.
L.GUIDE_RIBBON = "Tu Libro"
-- EN: Your Ledger
L.GUIDE_KICKER = "Tu Libro"
-- EN: Your Ledger
L.GUIDE_TITLE = "Empieza con tu próximo pez"
-- EN: It starts with your next fish
L.GUIDE_BODY = "Pagle solo anota lo que ve. Los peces que pescaste antes de hoy no están en tu Libro, y Pagle "
	.. "no fingirá que sí. Tu primera pieza es la página uno."
-- EN: Pagle writes down only what it sees. Fish you caught before today aren’t in your Ledger, and Pagle won’t pretend they are. Your first Catch is page one.
L.GUIDE_KEPT_NONE = "llevado desde … tu primera pieza"
-- EN: kept since … your first Catch
L.GUIDE_RIGHT_KICKER = "Ya anotado"
-- EN: Already written in
L.GUIDE_RIGHT_TITLE = "Lo que Pagle pudo ver"
-- EN: What Pagle could see
L.GUIDE_RIGHT_BODY =
	"Tu habilidad de Pesca es lo único que cuenta tu pasado con honestidad, así que cuenta desde el principio."
-- EN: Your Fishing skill is the one thing that tells your past honestly, so it counts from the start.
L.GUIDE_HEADING = "%s · Pesca %d"
-- EN: %s · Fishing %d
L.GUIDE_READ_NOW = "leída ahora mismo"
-- EN: read just now
L.GUIDE_MILESTONE = "Hito de habilidad %d"
-- EN: Skill Milestone %d
L.GUIDE_MILESTONES = "Hitos de habilidad %s y %d"
-- EN: Skill Milestones %s and %d
L.GUIDE_REACHED_BEFORE = "alcanzado antes de llegar Pagle"
-- EN: reached before Pagle came
L.GUIDE_REACHED = "alcanzado el %s"
-- EN: reached %s
L.GUIDE_TO_GO = "faltan %d puntos"
-- EN: %d skill to go
L.GUIDE_LATER = "para más tarde"
-- EN: for later
L.GUIDE_ACCOUNT = "Todos los personajes de esta cuenta escriben en el mismo Libro. Entra con otro y Pagle "
	.. "también lee su habilidad de Pesca."
-- EN: Every character on this account writes in the same Ledger. Log in with another and Pagle reads their Fishing skill too.
L.GUIDE_NOTE = "Activa una parte más tarde y repasará *cada Captura* desde hoy, y luego reseñará lo que "
	.. "habías ganado."
-- EN: Turn a part on later and it reads back through *every Catch* since today, then writes up what you’d earned.
L.NOTE_FRESH = "Has estado fuera, así que tus próximas Capturas dan XP extra. Eso es *Agua fresca*, el azul de tu "
	.. "barra. Un descanso nunca es una penalización."
-- EN: You’ve been away, so your next Catches earn bonus XP. That’s *Fresh Water*, the blue in your bar. A rest is never a penalty.
L.PRESTIGE_LETTER_KICKER = "Una carta, dejada en el muelle"
-- EN: A letter, left on the dock
L.PRESTIGE_LETTER_TEXT = "Sesenta: la cima de la subida. Empieza un Libro nuevo cuando quieras. Tu nivel vuelve a "
	.. "empezar desde 1, tu Libro recibe una marca de Prestigio y no pierdes nada de lo que has ganado. O quédate en "
	.. "sesenta todo el tiempo que quieras."
-- EN: Sixty: the top of the climb. Begin a new Ledger whenever you like. Your level starts again from 1, a Prestige mark goes on your Ledger, and nothing you’ve earned is taken away. Or stay at sixty as long as you please.
L.PRESTIGE_LETTER_SHOW = "Muéstramelo"
-- EN: Show me
L.PRESTIGE_LETTER_LATER = "Más tarde"
-- EN: Later
L.NOTE_PRESTIGE = "*Empieza un Libro nuevo* aquí, cuando estés listo. Sin prisa."
-- EN: *Begin a new Ledger* here, when you’re ready. No hurry.
L.FIRST_LOOK_TITLE = "el Diario de peces"
-- EN: the Fish Journal
L.FIRST_LOOK_TILE = "Cada agua que pescas tiene su casilla. Su rango sube de *Visitante* a *Maestro*."
-- EN: Every water you fish gets a tile. Its rank climbs from *Visitor* to *Master*.
L.FIRST_LOOK_XP_BAR = "Tu Nivel de Pescador. El tramo *azul* es Agua fresca: XP extra tras un descanso."
-- EN: Your Angler Level. The *blue* stretch is Fresh Water: bonus XP after a break.
L.FIRST_LOOK_NOTES = "Notas para mí: lo que está más cerca de terminar. Se reescriben mientras pescas."
-- EN: Notes to self: what’s closest to done. They rewrite themselves as you fish.
L.FIRST_LOOK_SEARCH = "Busca unas aguas o un pez. Un pez que no has pescado *nunca tiene nombre*."
-- EN: Find a water or a fish. A fish you haven’t caught is *never named*.
L.FIRST_LOOK_UNFISHED = "Las casillas punteadas son aguas que aún no has pescado, con la habilidad que piden."
-- EN: Dashed tiles are waters you haven’t fished yet, with the skill they ask.
L.FIRST_LOOK_AGAIN = "Volver a mostrar las notas de esta página"
-- EN: Show the notes for this page again

L.COLLECTION_CONTENTS = "La Colección: aspectos y títulos"
-- EN: The Collection: looks and titles
L.COLLECTION_CRUMB = "La Colección"
-- EN: The Collection
L.COLLECTION_TITLE = "La Colección"
-- EN: The Collection
L.COLLECTION_NEW_COUNT = "nuevos: %s"
-- EN: %s new
L.COLLECTION_NEW_MARK = "¡nuevo!"
-- EN: new!
L.COLLECTION_SEARCH_HINT = "Busca un aspecto…"
-- EN: Find a look…
L.COLLECTION_SEARCH_LOOKS = "Aspectos"
-- EN: Looks
L.COLLECTION_SLASH_HELP = "Abre la Colección del Diario de peces"
-- EN: Open the Fish Journal's Collection
L.COLLECTION_LINE = "Todos los aspectos de Pagle: los que llevas, los que guardas y cómo ganar el resto."
-- EN: Every look Pagle has: the ones you wear, the ones you keep, and how to earn the rest.
L.COLLECTION_OF = "%s de %s"
-- EN: %s of %s
L.COLLECTION_WEARING = "Llevas %s"
-- EN: Wearing %s
L.COLLECTION_SIGNED = "Firmado “%s”"
-- EN: Signed “%s”
L.COLLECTION_REACH = "A tu alcance"
-- EN: Within reach
L.COLLECTION_LATELY = "Añadidos hace poco"
-- EN: Lately added
L.COLLECTION_NEWEST_FIRST = "los más nuevos primero"
-- EN: newest first
L.COLLECTION_SEAL = "%s\nde %s"
-- EN: %s\nof %s
L.COLLECTION_ADDED_BOUGHT = "Comprado"
-- EN: Bought
L.COLLECTION_ADDED_CRATE = "De un Cofre de curiosidades"
-- EN: From a Curio crate
L.COLLECTION_ADDED_EARNED = "Ganado"
-- EN: Earned
L.COLLECTION_FOR_SALE_ONE = "%s aspecto a la venta que aún no tienes."
-- EN: %s look for sale you don't have yet.
L.COLLECTION_FOR_SALE_OTHER = "%s aspectos a la venta que aún no tienes."
-- EN: %s looks for sale you don't have yet.
L.COLLECTION_OPEN_SHOP = "Abrir la Tienda de Curiosidades"
-- EN: Open the Curio Shop
L.COLLECTION_SHELF_KICKER = "La Colección"
-- EN: The Collection
L.COLLECTION_YOURS_COUNT = "%s de %s tuyos"
-- EN: %s of %s yours
L.COLLECTION_TAB_ALL = "Todos"
-- EN: All
L.COLLECTION_TAB_YOURS = "Tuyos"
-- EN: Yours
L.COLLECTION_TAB_EARN = "Por ganar"
-- EN: To earn
L.COLLECTION_TAB_SHOP = "En la tienda"
-- EN: In the shop
L.COLLECTION_TAG_IN_USE = "En uso"
-- EN: In use
L.COLLECTION_TAG_SIGNED = "firmado como"
-- EN: signed as
L.COLLECTION_TAG_YOURS = "Tuyo"
-- EN: Yours
L.COLLECTION_TAG_DEFAULT = "Por defecto"
-- EN: The default
L.COLLECTION_TAG_CRATE = "Cofre de curiosidades"
-- EN: Curio crate
L.COLLECTION_TAG_PUT_AWAY = "Guardado"
-- EN: Put away
L.COLLECTION_SLOT_NAMES = {
	["core.toaststyle"] = { "Estilo de aviso emergente", "Estilos de aviso emergente" },
	["core.soundset"] = { "Juego de sonidos", "Juegos de sonidos" },
	["core.binding"] = { "Encuadernación", "Encuadernaciones" },
	["core.crest"] = { "Blasón de ex libris", "Blasones de ex libris" },
}
-- EN: { ["core.binding"] = { "Binding", "Bindings" }, ["core.crest"] = { "Bookplate crest", "Bookplate crests" }, ["core.soundset"] = { "Sound set", "Sound sets" }, ["core.toaststyle"] = { "Toast style", "Toast styles" } }
L.COLLECTION_TRACKER_FRAME = "Marco de rastreador"
-- EN: Tracker frame
L.COLLECTION_TRACKER_FRAMES = "Marcos de rastreador"
-- EN: Tracker frames
L.COLLECTION_TITLE_ONE = "Título"
-- EN: Title
L.COLLECTION_TITLE_OTHER = "Títulos"
-- EN: Titles
L.COLLECTION_TITLE_GROUPS = {
	levels = "Niveles y Prestigio",
	wardens = "Guardianes",
	legends = "Leyendas",
	ledger = "El Libro entero",
}
-- EN: { ledger = "The whole Ledger", legends = "Legends", levels = "Levels and Prestige", wardens = "Wardens" }
L.COLLECTION_AUTOMATIC_NOTE = "Tu título de nivel más alto, sea cual sea"
-- EN: Your highest level title, whatever it is
L.COLLECTION_TITLE_DESCRIPTION = "Un título del Libro. Firma el Libro con él, y se muestra en tu placa de latón y "
	.. "en tu ex libris."
-- EN: A title of the Ledger. Sign the Ledger with it, and it shows on your brass plate and your bookplate.
L.COLLECTION_EARN_MASTER = "Maestro en %s"
-- EN: Master in %s
L.COLLECTION_EARN_LEGEND = "Primera Captura de %s"
-- EN: First Catch of %s
L.COLLECTION_EARN_JUNK = "Llena el Museo de trastos"
-- EN: Fill the Junk Museum
L.COLLECTION_EARN_TREASURE = "Encuentra todos los Tesoros"
-- EN: Find every Treasure
L.COLLECTION_EARN_TROPHY = "Captura todos los pesos de trofeo"
-- EN: Land every trophy weight
L.COLLECTION_MODULES = {
	Core = "Pagle",
	Ledger = "Libro de registro",
	Hunts = "Cazas",
	Stats = "Estadísticas",
	TackleBoard = "Tablón de aparejos",
	QoL = "Comodidades",
}
-- EN: { Core = "Pagle", Hunts = "Hunts", Ledger = "Ledger", QoL = "QoL", Stats = "Stats", TackleBoard = "Tackle Board" }
L.COLLECTION_SIGNED_AS = "Firmado como"
-- EN: Signed as
L.COLLECTION_STAGE_LINE = "%s · Nivel de Pescador %d"
-- EN: %s · Angler Level %d
L.COLLECTION_BEFORE = "Un aspecto antes de tenerlo"
-- EN: A look before you have it
L.COLLECTION_SOURCE_DEFAULT = "Por defecto"
-- EN: The default
L.COLLECTION_SOURCE_SHOP = "Tienda de Curiosidades"
-- EN: Curio Shop
L.COLLECTION_SOURCE_CRATE = "Solo en Cofre de curiosidades"
-- EN: Curio crate only
L.COLLECTION_SOURCE_REWARD = "Recompensa de %s"
-- EN: %s reward
L.COLLECTION_IN_USE = "En uso"
-- EN: In use
L.COLLECTION_USE = "Úsalo"
-- EN: Use it
L.COLLECTION_WEAR = "Llévalo"
-- EN: Wear it
L.COLLECTION_SIGN = "Firma con él"
-- EN: Sign with it
L.COLLECTION_EFFECTS = {
	["core.toaststyle"] = "Todos los Anuncios lo llevan.",
	["core.soundset"] = "Suena en cada Anuncio.",
	["core.binding"] = "Todos tus libros la llevan.",
	["core.crest"] = "Prendido en tu ex libris.",
}
-- EN: { ["core.binding"] = "Every book of yours wears it.", ["core.crest"] = "Pinned on your bookplate.", ["core.soundset"] = "Every Announcement plays it.", ["core.toaststyle"] = "Every Announcement wears it." }
L.COLLECTION_EFFECT_TRACKER = "En el rastreador de %s."
-- EN: On the %s tracker.
L.COLLECTION_EFFECT_TITLE = "El Libro va firmado con él."
-- EN: The Ledger is signed with it.
L.COLLECTION_HOW_DEFAULT = "Gratis, y siempre tuyo."
-- EN: Free, and always yours.
L.COLLECTION_HOW_BOUGHT = "Comprado el %s por %s Monedas."
-- EN: Bought %s for %s Coins.
L.COLLECTION_HOW_BOUGHT_FREE = "Comprado el %s."
-- EN: Bought %s.
L.COLLECTION_HOW_CRATE = "De un Cofre de curiosidades, el %s."
-- EN: From a Curio crate, %s.
L.COLLECTION_HOW_EARNED = "Ganado el %s: %s."
-- EN: Earned %s: %s.
L.COLLECTION_HOW_EARNED_DATE = "Ganado el %s."
-- EN: Earned %s.
L.COLLECTION_HOW_EARNED_LINE = "Ganado: %s."
-- EN: Earned: %s.
L.COLLECTION_HOW_TO_EARN = "Cómo ganarlo"
-- EN: How to earn it
L.COLLECTION_COUNT = "%s de %s"
-- EN: %s of %s
L.COLLECTION_COUNT_UNIT = "%s de %s %s"
-- EN: %s of %s %s
L.COLLECTION_FALLBACK = "¿Sin ganar para el %s? Entonces también sale a la venta, por %s Monedas."
-- EN: Not earned by %s? Then it goes on sale too, for %s Coins.
L.COLLECTION_BUY = "Comprar en la Tienda de Curiosidades"
-- EN: Buy in the Curio Shop
L.COLLECTION_ENOUGH = "Tienes %s Monedas, suficiente."
-- EN: You have %s Coins, enough for it.
L.COLLECTION_SHORT = "Tienes %s Monedas: faltan %s."
-- EN: You have %s Coins: %s more to go.
L.COLLECTION_CRATE_ONLY = "Solo sale de un Cofre de curiosidades."
-- EN: Only ever from a Curio crate.
L.COLLECTION_OPEN_CRATE = "Abrir un cofre"
-- EN: Open a crate
L.COLLECTION_CRATE_NOTE = "Nunca a la venta y nunca ganado: lo da un cofre, o nada."
-- EN: Never for sale and never earned: a crate gives it, or nothing does.
L.COLLECTION_PUT_AWAY = "Guardado: %s está desactivado"
-- EN: Put away: %s is off
