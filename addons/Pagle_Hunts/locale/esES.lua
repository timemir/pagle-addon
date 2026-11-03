if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end
if not GetLocale or GetLocale() ~= "esES" then
	return
end

-- Hunts' Spanish (Spain) strings, over enUS.lua's.
local ns = select(2, ...)
local L = ns.L

L.TITLE = "Cazas"
L.BOARD = "Cazas"
L.BOARD_SLASH_HELP = "Abrir o cerrar el tablero de Cazas"

L.SLOT_TRACKER_FRAME = "Marco de rastreador de Cazas"
L.PREVIEW_TRACKER_HUNTS = { { "Ronda nocturna", "en 37m" }, { "Hora punta", "a demanda" } }
L.EARNED_TEXT = {
	anySetTitle = "Completa una serie de Cazas",
	everySetTitle = "Completa todas las series de Cazas",
	wagerRuns = "%d rondas de Apuestas completadas",
	wagerCentury = "%d rondas de Apuestas completadas",
	nightTide = "Nivel 3 en tres Cazas nocturnas de Apuestas",
	deepTrench = "Nivel 3 en todas las Cazas de la Apuesta de la langosta",
}
L.WINDOW_MOMENTS_SETTING = "Avísame cuando se abra la franja de una Caza fijada"
L.WINDOW_MOMENTS_TOOLTIP =
	"Un Gesto discreto cuando se abre la franja de una Caza fijada. Se desvanece cuando se cierra."
L.WINDOW_OPEN = "%s: franja abierta"
L.WINDOW_OPENED = "%s: franja abierta desde %s"
L.WINDOW_OPENED_UNTIL = "%s: franja abierta, %s–%s"

L.WEEKDAYS_SHORT = { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" }
L.WEEKDAYS_PLURAL = { "domingos", "lunes", "martes", "miércoles", "jueves", "viernes", "sábados" }
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
L.LABEL_NEED = "necesito %d"
L.TRACKER_NEED = "necesita %d"
L.LABEL_UP_NOW = "activa ya"
L.LABEL_ON_DEMAND = "a demanda"
L.LABEL_ANY_TIME = "a cualquier hora"
L.LABEL_WHILE_EVENT = "mientras dure el evento"
L.TRACKER_NOW = "ahora"
L.LABEL_UNTIL = "hasta %s"
L.TRACKER_ENDS_IN = "acaba en %s"
L.LABEL_IN = "en %s"
L.LABEL_BACK_IN = "vuelve en %s"
L.LABEL_NO_DATE = "sin fecha conocida"
L.LINE_UP_NOW = "Activa ya."
L.LINE_ON_DEMAND = "Cuando prepare %s."
L.LINE_ANY_TIME = "Abierta a cualquier hora."
L.LINE_WHILE_EVENT = "Abierta mientras dure el evento."
L.LINE_CLOSES = "Abierta ya. Cierra en %s (%s)."
L.LINE_UNTIL = "Abierta ya, hasta %s."
L.LINE_SOON = "Abre en %s (%s)."
L.LINE_OPENS_AT = "Abre a las %s."
L.LINE_OPENS_ON = "Abre el %s."
L.LINE_BACK = "Vuelve en %s."
L.LINE_NO_DATE = "Sin fecha conocida."
L.LINE_NEEDS = "Necesito %d; mi máximo es %d."
L.LINE_LURE = "Con un señuelo llego."
L.JOIN_OR = " o "
L.CONDITION_NIGHT = "Noche %s"
L.CONDITION_DAY = "Día %s"
L.CONDITION_TIME = "Hora del reino %s"
L.SEASONS = { spring = "Primavera", summer = "Verano", autumn = "Otoño", winter = "Invierno" }
L.CONDITION_EVENT = "%s, %s %s durante %s"
L.EVENT_UNKNOWN = "un evento del calendario"
L.CONDITION_AREAS = "En %s"
L.CONDITION_AURAS = "Mientras dure %s"
L.CONDITION_LURE = "Con un señuelo puesto"
L.CONDITION_SKILL = "Habilidad %d o más (los señuelos cuentan)"
L.TARGET_UNCOMMON = "Cualquier Captura poco común o mejor"
L.TARGET_RARE = "Cualquier Captura rara o mejor"
L.TARGET_ANY = "Cualquier pez"
L.TARGET_MIN_BAND = "%s, %s o mejor"

L.TIMELINE_TITLE = "Qué pica, y cuándo"
L.GROUP_HEADINGS = {
	now = "Ahora: abiertas ahora mismo",
	soon = "Pronto: abren en menos de 3 horas",
	later = "Más tarde: abren después, o piden más habilidad",
	onDemand = "A demanda: empiezan cuando tú quieras",
	wagers = "Apuestas: duran días, no horas",
}
L.GROUP_NAMES = { now = "Ahora", soon = "Pronto", later = "Más tarde", onDemand = "A demanda", wagers = "Apuestas" }
L.GROUP_NOTES = {
	now = "abiertas ahora mismo",
	soon = "abren en menos de 3 horas",
	later = "abren después, o piden más habilidad",
	onDemand = "empiezan cuando tú quieras",
	wagers = "duran días, no horas",
}
L.TIMELINE_LEGEND =
	"Rayado: abierta · Discontinua: franja sin confirmar · Lápiz: pide más habilidad · Azul: tu campamento está montado"
L.LEGEND_ITEMS = {
	hatched = "abierta",
	dashed = "franja sin confirmar",
	pencil = "pide más habilidad",
	camp = "tu campamento está montado",
}
L.TIMELINE_KICKER = "El Tablero"
L.SET_KICKER = "Serie de Cazas"
L.SET_HUNTS_HEADING = "Cazas de esta serie"
L.RULER_REALM_TIME = "Hora del reino"
L.RULER_NEXT = "próximas %dh"
L.OUT_OF_SEASON = "fuera de temporada"
L.SET_HEADING_EARNS = "%s: otorga %s"
L.NO_HUNTS = "Aún no hay Cazas."
L.CLOCK_PAUSED = "%s (en pausa en combate)"
-- ENTRY_ALL_DONE quotes this checkbox's words.
L.SHOW_COMPLETED = "mostrar completadas"

L.TRACKER_EMPTY = "Fija una Caza para tenerla aquí."
L.TRACKER_MORE = "+%d más"
L.TRACKER_HERE = "estás aquí"
L.TRACKER_ALL_TIERS = "todos los niveles"
L.TRACKER_UPDATING = "actualizando…"
L.TRACKER_SETTLED = "liquidada"
L.TRACKER_FIRST_MARKS = "%d de %d primeras marcas"
L.TRACKER_WAGERS_MORE = "+%d apuestas más en la mesa"
L.SETTING_SHOW_TRACKER = "Mostrar el rastreador de Cazas"
L.SETTING_SHOW_TRACKER_TOOLTIP = "Un pequeño rastreador bajo el minimapa con las Cazas que has fijado en el tablero."

L.HUNT_COMPLETE = "Caza completada"
L.HUNT_COMPLETE_STAMP = "Caza"
L.HUNT_TIER = "Nivel de %s"
L.HUNT_TIER_TEXT = "%s · %d capturas"
L.TRIMS = { bronze = "Bronce", silver = "Plata", gold = "Oro" }
L.TITLE_EARNED = "Título conseguido"
L.TITLE_EARNED_STAMP = "Título"
L.WAGER_MARK = "Apuestas Pagle"
L.WAGER_MARK_TEXT = "%s · primera marca"
L.WAGER_MARK_STAMP = "Marca"
L.WAGER_TIER = "Marca de %s"
L.WAGER_SETTLED = "Apuesta liquidada"
L.WAGER_SETTLED_STAMP = "Liquidada"
L.WRITE_UP_FIRST_BUILD_ONE = "Tus Cazas, reseñadas a partir de %s Lance"
L.WRITE_UP_FIRST_BUILD_OTHER = "Tus Cazas, reseñadas a partir de %s Lances"
L.WRITE_UP_WHILE_OFF = "Mientras Cazas estaba desactivado"
L.WRITE_UP_COMPLETED_ONE = "%s Caza completada"
L.WRITE_UP_COMPLETED_OTHER = "%s Cazas completadas"
L.WRITE_UP_FURTHER_ONE = "%s nivel más"
L.WRITE_UP_FURTHER_OTHER = "%s niveles más"
L.WRITE_UP_SETTLED_ONE = "%s apuesta liquidada"
L.WRITE_UP_SETTLED_OTHER = "%s apuestas liquidadas"
L.WRITE_UP_TITLE = "Título: %s"
L.WRITE_UP_COINS = "Monedas Pagle +%s"
L.WRITE_UP_XP = "XP de Pescador +%s"
L.SUMMARY_LINE = "Cazas: %s de %s hechas · %s"
L.SUMMARY_LINE_SETTLED = "Cazas: %s de %s hechas · %s · %s"
L.SUMMARY_TITLES_ONE = "%s título"
L.SUMMARY_TITLES_OTHER = "%s títulos"
L.SUMMARY_SETTLED_ONE = "%s apuesta liquidada"
L.SUMMARY_SETTLED_OTHER = "%s apuestas liquidadas"

L.ENTRY_NATURAL = "Natural"
L.ENTRY_IMPOSED = "Impuesta"
L.ENTRY_RETIRED = "Retirada el %s"
L.ENTRY_BACK = "volver a %s"
L.ENTRY_PIN = "Fijar en el rastreador"
L.ENTRY_UNPIN = "Quitar"
L.SEAL_HUNTED = "Cazada el %s"
L.SEAL_NOT_YET = "aún no"
L.SEAL_HUNTED_WORD = "Cazada"
L.ENTRY_PINNED = "Fijada"
L.ENTRY_PIN_WORD = "Fijar"
L.LADDER_NOT_YET = "aún no"
L.LADDER_CAUGHT = "%d capturas"
L.EFFORT_CASTS_ONE = "%d Lance"
L.EFFORT_CASTS_OTHER = "%d Lances"
L.EFFORT = "%s en estas condiciones."
L.EFFORT_SINCE = "%s en estas condiciones, %d desde la última."
L.EFFORT_ODDS = "Las probabilidades, en Estadísticas."
L.SET_LINE = "%s: %d de %d · %s"
L.SET_EARNS = "otorga %s"
L.SET_EARNED = "otorgó %s"
L.CHIP_HERE = "estás aquí"
L.CHIP_MORE = "+%d más"
L.CHIP_SKILL = "habilidad %d"
L.CHIP_SHORT = "necesita %d, máx.: %d"
L.CHIP_LURE = "necesita señuelo"
L.CHIP_UNCONFIRMED = "sin confirmar"
L.UNCONFIRMED_WINDOW = "Esta franja es una estimación."
L.UNCONFIRMED_GATING = "Aún no se ha visto picar solo en esta franja."
L.ENTRY_ALL_DONE = 'Todas las Cazas de aquí están hechas. Marca "mostrar completadas" para verlas otra vez.'

L.RIBBON_BOARD = "Tablero"
L.CRUMB_HUNTS = "Cazas"
L.UPDATING = "Actualizando desde tu Registro de capturas…"
L.NAMEPLATE_DONE_ONE = "%s Caza hecha"
L.NAMEPLATE_DONE_OTHER = "%s Cazas hechas"
L.NAMEPLATE_TITLE = "%s, conseguido el %s"
L.SET_PAGE_EARNS = "Otorga el título %s"
L.SET_PAGE_EARNED = "Conseguido: %s"
L.SET_SEAL = "Título conseguido el %s"
L.SET_SEAL_WORD = "Conseguido"
L.SET_PROGRESS = "%d de %d hechas"
L.SET_RULE = "El primer nivel de cada Caza otorga el título."
L.SET_RETIRED = "Retirada"

L.WAGERS_KICKER = "Apuestas Pagle"
L.JOIN_ZONES = " y "
L.STRIP_CLOSES = "cierra en %s"
L.STRIP_MORE = "+%d más en la mesa"
L.RUN_KICKER_ROTATION = "De la rotación · aguas de nivel %s"
L.BANDS = { low = "bajo", mid = "medio", high = "alto" }
L.RUN_KICKER_PUSHED = "Enviada por el acompañante"
L.RUN_SETTLED_OPEN = "liquidada, y aún abierta"
L.RUN_OPENS = "abre el %s"
L.RUN_UNTIL_ALL = "hasta el %s · %s en total"
L.RUN_UNTIL_TABLE = "hasta el %s · %s en la mesa"
L.SEAL_SETTLED_WORD = "Liquidada"
L.SHAPES = { timed = "Con horario", big = "Grandes", quality = "Calidad", haul = "Redada", named = "Pez con nombre" }
L.RUN_HUNT_CAUGHT = "%s capturas"
L.RUN_WINDOW_OPEN = "abierta ya, hasta %s"
L.RUN_WINDOW_SHUT = "abre a las %s, en %s"
L.RUN_CASTS_ONE = "%s Lance en estas aguas en esta ronda · %d de %d primeras marcas"
L.RUN_CASTS_OTHER = "%s Lances en estas aguas en esta ronda · %d de %d primeras marcas"
L.PAY_SO_FAR = "Pagado hasta ahora"
L.PAY_AMOUNT = "+%d XP · %d Monedas"
L.PAY_SETTLE = "Al liquidarla"
L.PAY_SETTLED = "Liquidada"
L.PAY_PAID_OUT = "pagado"
L.RUN_PAY_RULE = "La primera marca de cada Caza paga +%d XP y %d Monedas, cada nivel posterior +%d XP y %d Monedas, y "
	.. "liquidar la apuesta +%d XP y %d Monedas más."
L.PAY_REFRESH_ONE = "+%s Renovación"
L.PAY_REFRESH_OTHER = "+%s Renovaciones"
L.REFRESH_ONE = "%s Renovación"
L.REFRESH_OTHER = "%s Renovaciones"
L.RUN_PAY_RULE_REFRESH_BOTH = " La tercera marca de una Caza también paga %s, y liquidar la apuesta %d más."
L.RUN_PAY_RULE_REFRESH_TIER = " La tercera marca de una Caza también paga %s."
L.RUN_PAY_RULE_REFRESH_RUN = " Liquidar la apuesta también paga %s."
L.ENTRY_NONE_TITLE = "Nada que leer aún"
L.ENTRY_NONE_HAND = "Cuando salga una apuesta, se escribirá aquí: sus aguas, sus Cazas y lo que paga."

L.RIBBON_ON = "%d en curso"
L.SPREAD_TITLE = "En la mesa"
L.SPREAD_NOTE_MANY = "%d apuestas en curso. Consigue la primera marca de cada Caza antes de que cierre su apuesta."
L.SPREAD_NOTE_ONE = "Una apuesta en curso. Consigue la primera marca de cada Caza antes de que cierre."
L.SPREAD_NOTE_AHEAD = "Nada en curso ahora mismo. La próxima apuesta abre el %s."
L.SPREAD_NOTE_NONE = "Nada en la mesa, y nada anunciado aún."
L.SPREAD_CLOSING = "¡%s cierra en %s!"
L.SPREAD_ON_NOW = "En curso"
L.SPREAD_AHEAD = "Próximas"
L.SPREAD_AHEAD_CAPTION = "anunciadas, pueden cambiar antes de abrir"
L.SPREAD_EMPTY = "No hay apuestas en la mesa ni anunciadas. La rotación pondrá una en el próximo turno."
L.TICKET_CLOSED_AT = "cerró el %s"
L.TICKET_CLOSED = "cerrada"
L.TICKET_MARKS = "%d de %d primeras marcas"
L.TICKET_UPDATING = "actualizando…"
L.NEEDS_SKILL = "necesita habilidad %d"
L.AHEAD_OPENS = "abre el %s"
L.AHEAD_FOR = "durante %s"
L.LADDER_LABEL = "La escalera"
L.HOLIDAYS = {
	hallows_end = "Halloween",
	winter_veil = "Festival de Invierno",
	lunar_festival = "Festival Lunar",
	noblegarden = "Jardín Noble",
	midsummer = "Festival del Fuego del Solsticio de Verano",
	harvest_festival = "Festival de la Cosecha",
	stv_extravaganza = "Torneo de pesca de Tuercespina",
}
L.WAGERS_SETTLED_ONE = "%s apuesta liquidada"
L.WAGERS_SETTLED_OTHER = "%s apuestas liquidadas"
L.WAGERS_LADDER_LINE = "%s · %d más para %s"

L.GUIDE_BLURB = "Peces que solo pican de noche, en invierno o en la feria, y cuáles pican ahora mismo."
L.LOOK_TITLE = "Cazas"
L.LOOK_GROUPS = "*Ahora*, *Pronto* y *Más tarde*: lo que está abierto, lo que abre en tres horas y el resto."
L.LOOK_NOW_LINE =
	"La línea roja es el *ahora*, en hora del reino. Las barras rayadas marcan cuándo está abierta cada Caza."
L.LOOK_NATURAL =
	"*Natural* significa que el propio juego limita las horas de este pez. Las Cazas impuestas son reglas de Pagle."
L.LOOK_PIN = "*Fija* una Caza para tenerla en tu rastreador mientras pescas."
L.LOOK_SETS = "Cada cinta es una *serie de Cazas*. Completa todas sus Cazas y su título es tuyo. *Apuestas Pagle* "
	.. "guarda las apuestas que hay ahora en la mesa."
L.LOOK_AGAIN = "Mostrar otra vez las notas de esta página"
L.HINT_MISSING =
	"Hay apuestas nuevas por ahí. El acompañante de Pagle las trae: más XP, más Monedas y el estilo de aviso Sonar Scope."
L.HINT_NOD = "Hay apuestas nuevas por ahí. El acompañante de Pagle las trae: más XP, más Monedas."
L.HINT_FIRST_INSTALL = "¿Acabas de instalarlo? Sal a la selección de personaje una vez."
L.HINT_NOT_RUNNING = "El acompañante de Pagle no está en marcha. Ábrelo para recibir las apuestas de esta semana."
L.HINT_GET_IT = "Conseguirlo"
L.HINT_DISMISS = "Descartar"
L.HINT_ADDRESS_KICKER = "El acompañante de Pagle"
L.HINT_ADDRESS_COPY = "Ctrl+C para copiar"
L.HINT_ADDRESS_CLOSE = "Cerrar"
L.TRACKER_HINT_MISSING = "Apuestas nuevas con el acompañante de Pagle"
L.TRACKER_HINT_NOT_RUNNING = "Acompañante de Pagle detenido"
L.TRACKER_HINT_WHY = "¿por qué?"
L.COMPANION_HINT_SETTING = "Recordarme lo del acompañante de Pagle"
L.COMPANION_HINT_TOOLTIP = "Una línea en el tablero de Cazas, y un Gesto una vez por semana, mientras el acompañante "
	.. "de Pagle no te traiga apuestas nuevas."
