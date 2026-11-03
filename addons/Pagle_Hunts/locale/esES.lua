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
-- EN: Hunts
L.BOARD = "Cazas"
-- EN: Hunts
L.BOARD_SLASH_HELP = "Abrir o cerrar el tablero de Cazas"
-- EN: Open or close the Hunts board

L.SLOT_TRACKER_FRAME = "Marco de rastreador de Cazas"
-- EN: Hunts tracker frame
L.PREVIEW_TRACKER_HUNTS = { { "Ronda nocturna", "en 37m" }, { "Hora punta", "a demanda" } }
-- EN: { { "Night Run", "in 37m" }, { "Rack Hour", "on demand" } }
L.EARNED_TEXT = {
	anySetTitle = "Completa una serie de Cazas",
	everySetTitle = "Completa todas las series de Cazas",
	wagerRuns = "%d rondas de Apuestas completadas",
	wagerCentury = "%d rondas de Apuestas completadas",
	nightTide = "Nivel 3 en tres Cazas nocturnas de Apuestas",
	deepTrench = "Nivel 3 en todas las Cazas de la Apuesta de la langosta",
}
-- EN: { anySetTitle = "Finish a Hunt set", deepTrench = "Tier 3 in every Hunt of the lobster Wager", everySetTitle = "Finish every Hunt set", nightTide = "Tier 3 in three night Wager Hunts", wagerCentury = "%d Wager runs completed", wagerRuns = "%d Wager runs completed" }
L.WINDOW_MOMENTS_SETTING = "Avísame cuando se abra la franja de una Caza fijada"
-- EN: Tell me when a pinned Hunt's window opens
L.WINDOW_MOMENTS_TOOLTIP =
	"Un Gesto discreto cuando se abre la franja de una Caza fijada. Se desvanece cuando se cierra."
-- EN: A quiet Nod when a pinned Hunt's window opens. It fades when the window closes.
L.WINDOW_OPEN = "%s: franja abierta"
-- EN: %s is open
L.WINDOW_OPENED = "%s: franja abierta desde %s"
-- EN: %s window opened %s
L.WINDOW_OPENED_UNTIL = "%s: franja abierta, %s–%s"
-- EN: %s window opened %s–%s

L.WEEKDAYS_SHORT = { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" }
-- EN: { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
L.WEEKDAYS_PLURAL = { "domingos", "lunes", "martes", "miércoles", "jueves", "viernes", "sábados" }
-- EN: { "Sundays", "Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays" }
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
L.LABEL_NEED = "necesito %d"
-- EN: need %d
L.TRACKER_NEED = "necesita %d"
-- EN: needs %d
L.LABEL_UP_NOW = "activa ya"
-- EN: up now
L.LABEL_ON_DEMAND = "a demanda"
-- EN: on demand
L.LABEL_ANY_TIME = "a cualquier hora"
-- EN: any time
L.LABEL_WHILE_EVENT = "mientras dure el evento"
-- EN: while the event runs
L.TRACKER_NOW = "ahora"
-- EN: now
L.LABEL_UNTIL = "hasta %s"
-- EN: until %s
L.TRACKER_ENDS_IN = "acaba en %s"
-- EN: ends in %s
L.LABEL_IN = "en %s"
-- EN: in %s
L.LABEL_BACK_IN = "vuelve en %s"
-- EN: back in %s
L.LABEL_NO_DATE = "sin fecha conocida"
-- EN: no date known
L.LINE_UP_NOW = "Activa ya."
-- EN: Up now.
L.LINE_ON_DEMAND = "Cuando prepare %s."
-- EN: Whenever I set up %s.
L.LINE_ANY_TIME = "Abierta a cualquier hora."
-- EN: Open any time.
L.LINE_WHILE_EVENT = "Abierta mientras dure el evento."
-- EN: Open while the event runs.
L.LINE_CLOSES = "Abierta ya. Cierra en %s (%s)."
-- EN: Open now. Closes in %s, at %s.
L.LINE_UNTIL = "Abierta ya, hasta %s."
-- EN: Open now, until %s.
L.LINE_SOON = "Abre en %s (%s)."
-- EN: Opens in %s, at %s.
L.LINE_OPENS_AT = "Abre a las %s."
-- EN: Opens at %s.
L.LINE_OPENS_ON = "Abre el %s."
-- EN: Opens %s.
L.LINE_BACK = "Vuelve en %s."
-- EN: Back in %s.
L.LINE_NO_DATE = "Sin fecha conocida."
-- EN: No date known.
L.LINE_NEEDS = "Necesito %d; mi máximo es %d."
-- EN: Needs %d; my best is %d.
L.LINE_LURE = "Con un señuelo llego."
-- EN: A lure gets me there.
L.JOIN_OR = " o "
-- EN: " or "
L.CONDITION_NIGHT = "Noche %s"
-- EN: Night %s
L.CONDITION_DAY = "Día %s"
-- EN: Day %s
L.CONDITION_TIME = "Hora del reino %s"
-- EN: Realm time %s
L.SEASONS = { spring = "Primavera", summer = "Verano", autumn = "Otoño", winter = "Invierno" }
-- EN: { autumn = "Autumn", spring = "Spring", summer = "Summer", winter = "Winter" }
L.CONDITION_EVENT = "%s, %s %s durante %s"
-- EN: %s, %s %s for %s
L.EVENT_UNKNOWN = "un evento del calendario"
-- EN: a calendar event
L.CONDITION_AREAS = "En %s"
-- EN: In %s
L.CONDITION_AURAS = "Mientras dure %s"
-- EN: While %s is up
L.CONDITION_LURE = "Con un señuelo puesto"
-- EN: With a lure on
L.CONDITION_SKILL = "Habilidad %d o más (los señuelos cuentan)"
-- EN: Skill %d or more (lures count)
L.TARGET_UNCOMMON = "Cualquier Captura poco común o mejor"
-- EN: Any uncommon-or-better Catch
L.TARGET_RARE = "Cualquier Captura rara o mejor"
-- EN: Any rare-or-better Catch
L.TARGET_ANY = "Cualquier pez"
-- EN: Any fish
L.TARGET_MIN_BAND = "%s, %s o mejor"
-- EN: %s, %s or better

L.TIMELINE_TITLE = "Qué pica, y cuándo"
-- EN: What's biting, and when
L.GROUP_HEADINGS = {
	now = "Ahora: abiertas ahora mismo",
	soon = "Pronto: abren en menos de 3 horas",
	later = "Más tarde: abren después, o piden más habilidad",
	onDemand = "A demanda: empiezan cuando tú quieras",
	wagers = "Apuestas: duran días, no horas",
}
-- EN: { later = "Later: opens after that, or needs more skill", now = "Now: open right now", onDemand = "On demand: starts when you do", soon = "Soon: opens within 3 hours", wagers = "Wagers: on for days, not hours" }
L.GROUP_NAMES = { now = "Ahora", soon = "Pronto", later = "Más tarde", onDemand = "A demanda", wagers = "Apuestas" }
-- EN: { later = "Later", now = "Now", onDemand = "On demand", soon = "Soon", wagers = "Wagers" }
L.GROUP_NOTES = {
	now = "abiertas ahora mismo",
	soon = "abren en menos de 3 horas",
	later = "abren después, o piden más habilidad",
	onDemand = "empiezan cuando tú quieras",
	wagers = "duran días, no horas",
}
-- EN: { later = "opens after that, or needs more skill", now = "open right now", onDemand = "starts when you do", soon = "opens within 3 hours", wagers = "on for days, not hours" }
L.TIMELINE_LEGEND =
	"Rayado: abierta · Discontinua: franja sin confirmar · Lápiz: pide más habilidad · Azul: tu campamento está montado"
-- EN: Hatched: open · Dashed: window unconfirmed · Pencil: needs more skill · Blue: your camp is up
L.LEGEND_ITEMS = {
	hatched = "abierta",
	dashed = "franja sin confirmar",
	pencil = "pide más habilidad",
	camp = "tu campamento está montado",
}
-- EN: { camp = "your camp is up", dashed = "window unconfirmed", hatched = "open", pencil = "needs more skill" }
L.TIMELINE_KICKER = "El Tablero"
-- EN: The Board
L.SET_KICKER = "Serie de Cazas"
-- EN: Hunt set
L.SET_HUNTS_HEADING = "Cazas de esta serie"
-- EN: Hunts in this set
L.RULER_REALM_TIME = "Hora del reino"
-- EN: Realm time
L.RULER_NEXT = "próximas %dh"
-- EN: next %dh
L.OUT_OF_SEASON = "fuera de temporada"
-- EN: out of season
L.SET_HEADING_EARNS = "%s: otorga %s"
-- EN: %s: earns %s
L.NO_HUNTS = "Aún no hay Cazas."
-- EN: No Hunts yet.
L.CLOCK_PAUSED = "%s (en pausa en combate)"
-- EN: %s (paused in combat)
-- ENTRY_ALL_DONE quotes this checkbox's words.
L.SHOW_COMPLETED = "mostrar completadas"
-- EN: show completed

L.TRACKER_EMPTY = "Fija una Caza para tenerla aquí."
-- EN: Pin a Hunt to keep it here.
L.TRACKER_MORE = "+%d más"
-- EN: +%d more
L.TRACKER_HERE = "estás aquí"
-- EN: you're here
L.TRACKER_ALL_TIERS = "todos los niveles"
-- EN: all tiers
L.TRACKER_UPDATING = "actualizando…"
-- EN: updating…
L.TRACKER_SETTLED = "liquidada"
-- EN: settled
L.TRACKER_FIRST_MARKS = "%d de %d primeras marcas"
-- EN: %d of %d first marks
L.TRACKER_WAGERS_MORE = "+%d apuestas más en la mesa"
-- EN: +%d more wagers on the table
L.SETTING_SHOW_TRACKER = "Mostrar el rastreador de Cazas"
-- EN: Show the Hunts tracker
L.SETTING_SHOW_TRACKER_TOOLTIP = "Un pequeño rastreador bajo el minimapa con las Cazas que has fijado en el tablero."
-- EN: A small tracker under the minimap with the Hunts you've pinned on the board.

L.HUNT_COMPLETE = "Caza completada"
-- EN: Hunt complete
L.HUNT_COMPLETE_STAMP = "Caza"
-- EN: Hunt
L.HUNT_TIER = "Nivel de %s"
-- EN: %s tier
L.HUNT_TIER_TEXT = "%s · %d capturas"
-- EN: %s · %d caught
L.TRIMS = { bronze = "Bronce", silver = "Plata", gold = "Oro" }
-- EN: { bronze = "Bronze", gold = "Gold", silver = "Silver" }
L.TITLE_EARNED = "Título conseguido"
-- EN: Title earned
L.TITLE_EARNED_STAMP = "Título"
-- EN: Title
L.WAGER_MARK = "Apuestas Pagle"
-- EN: Pagle Wagers
L.WAGER_MARK_TEXT = "%s · primera marca"
-- EN: %s · first mark
L.WAGER_MARK_STAMP = "Marca"
-- EN: Mark
L.WAGER_TIER = "Marca de %s"
-- EN: %s mark
L.WAGER_SETTLED = "Apuesta liquidada"
-- EN: Wager settled
L.WAGER_SETTLED_STAMP = "Liquidada"
-- EN: Settled
L.WRITE_UP_FIRST_BUILD_ONE = "Tus Cazas, reseñadas a partir de %s Lance"
-- EN: Your Hunts were written up from %s Cast
L.WRITE_UP_FIRST_BUILD_OTHER = "Tus Cazas, reseñadas a partir de %s Lances"
-- EN: Your Hunts were written up from %s Casts
L.WRITE_UP_WHILE_OFF = "Mientras Cazas estaba desactivado"
-- EN: While Hunts was off
L.WRITE_UP_COMPLETED_ONE = "%s Caza completada"
-- EN: %s Hunt completed
L.WRITE_UP_COMPLETED_OTHER = "%s Cazas completadas"
-- EN: %s Hunts completed
L.WRITE_UP_FURTHER_ONE = "%s nivel más"
-- EN: %s further tier
L.WRITE_UP_FURTHER_OTHER = "%s niveles más"
-- EN: %s further tiers
L.WRITE_UP_SETTLED_ONE = "%s apuesta liquidada"
-- EN: %s wager settled
L.WRITE_UP_SETTLED_OTHER = "%s apuestas liquidadas"
-- EN: %s wagers settled
L.WRITE_UP_TITLE = "Título: %s"
-- EN: Title: %s
L.WRITE_UP_COINS = "Monedas Pagle +%s"
-- EN: Pagle Coins +%s
L.WRITE_UP_XP = "XP de Pescador +%s"
-- EN: Angler XP +%s
L.SUMMARY_LINE = "Cazas: %s de %s hechas · %s"
-- EN: Hunts: %s of %s done · %s
L.SUMMARY_LINE_SETTLED = "Cazas: %s de %s hechas · %s · %s"
-- EN: Hunts: %s of %s done · %s · %s
L.SUMMARY_TITLES_ONE = "%s título"
-- EN: %s title
L.SUMMARY_TITLES_OTHER = "%s títulos"
-- EN: %s titles
L.SUMMARY_SETTLED_ONE = "%s apuesta liquidada"
-- EN: %s wager settled
L.SUMMARY_SETTLED_OTHER = "%s apuestas liquidadas"
-- EN: %s wagers settled

L.ENTRY_NATURAL = "Natural"
-- EN: Natural
L.ENTRY_IMPOSED = "Impuesta"
-- EN: Imposed
L.ENTRY_RETIRED = "Retirada el %s"
-- EN: Retired %s
L.ENTRY_BACK = "volver a %s"
-- EN: back to %s
L.ENTRY_PIN = "Fijar en el rastreador"
-- EN: Pin to the tracker
L.ENTRY_UNPIN = "Quitar"
-- EN: Unpin
L.SEAL_HUNTED = "Cazada el %s"
-- EN: Hunted %s
L.SEAL_NOT_YET = "aún no"
-- EN: not yet
L.SEAL_HUNTED_WORD = "Cazada"
-- EN: Hunted
L.ENTRY_PINNED = "Fijada"
-- EN: Pinned
L.ENTRY_PIN_WORD = "Fijar"
-- EN: Pin
L.LADDER_NOT_YET = "aún no"
-- EN: not yet
L.LADDER_CAUGHT = "%d capturas"
-- EN: %d caught
L.EFFORT_CASTS_ONE = "%d Lance"
-- EN: %d Cast
L.EFFORT_CASTS_OTHER = "%d Lances"
-- EN: %d Casts
L.EFFORT = "%s en estas condiciones."
-- EN: %s under these conditions.
L.EFFORT_SINCE = "%s en estas condiciones, %d desde la última."
-- EN: %s under these conditions, %d since my last one.
L.EFFORT_ODDS = "Las probabilidades, en Estadísticas."
-- EN: Odds live in Stats.
L.SET_LINE = "%s: %d de %d · %s"
-- EN: %s: %d of %d · %s
L.SET_EARNS = "otorga %s"
-- EN: earns %s
L.SET_EARNED = "otorgó %s"
-- EN: earned %s
L.CHIP_HERE = "estás aquí"
-- EN: you're here
L.CHIP_MORE = "+%d más"
-- EN: +%d more
L.CHIP_SKILL = "habilidad %d"
-- EN: skill %d
L.CHIP_SHORT = "necesita %d, máx.: %d"
-- EN: needs %d, best: %d
L.CHIP_LURE = "necesita señuelo"
-- EN: needs a lure
L.CHIP_UNCONFIRMED = "sin confirmar"
-- EN: unconfirmed
L.UNCONFIRMED_WINDOW = "Esta franja es una estimación."
-- EN: This window is an estimate.
L.UNCONFIRMED_GATING = "Aún no se ha visto picar solo en esta franja."
-- EN: Not yet seen biting only in this window.
L.ENTRY_ALL_DONE = 'Todas las Cazas de aquí están hechas. Marca "mostrar completadas" para verlas otra vez.'
-- EN: Every Hunt here is done. Tick \"show completed\" to see them again.

L.RIBBON_BOARD = "Tablero"
-- EN: Board
L.CRUMB_HUNTS = "Cazas"
-- EN: Hunts
L.UPDATING = "Actualizando desde tu Registro de capturas…"
-- EN: Updating from your Catch log…
L.NAMEPLATE_DONE_ONE = "%s Caza hecha"
-- EN: %s Hunt done
L.NAMEPLATE_DONE_OTHER = "%s Cazas hechas"
-- EN: %s Hunts done
L.NAMEPLATE_TITLE = "%s, conseguido el %s"
-- EN: %s, earned %s
L.SET_PAGE_EARNS = "Otorga el título %s"
-- EN: Earns the title %s
L.SET_PAGE_EARNED = "Conseguido: %s"
-- EN: Earned: %s
L.SET_SEAL = "Título conseguido el %s"
-- EN: Title earned %s
L.SET_SEAL_WORD = "Conseguido"
-- EN: Earned
L.SET_PROGRESS = "%d de %d hechas"
-- EN: %d of %d done
L.SET_RULE = "El primer nivel de cada Caza otorga el título."
-- EN: The first tier of every Hunt earns the title.
L.SET_RETIRED = "Retirada"
-- EN: Retired

L.WAGERS_KICKER = "Apuestas Pagle"
-- EN: Pagle Wagers
L.JOIN_ZONES = " y "
-- EN: " & "
L.STRIP_CLOSES = "cierra en %s"
-- EN: closes in %s
L.STRIP_MORE = "+%d más en la mesa"
-- EN: +%d more on the table
L.RUN_KICKER_ROTATION = "De la rotación · aguas de nivel %s"
-- EN: From the rotation · %s waters
L.BANDS = { low = "bajo", mid = "medio", high = "alto" }
-- EN: { high = "high", low = "low", mid = "mid" }
L.RUN_KICKER_PUSHED = "Enviada por el acompañante"
-- EN: Sent by the companion
L.RUN_SETTLED_OPEN = "liquidada, y aún abierta"
-- EN: settled, and still open
L.RUN_OPENS = "abre el %s"
-- EN: opens %s
L.RUN_UNTIL_ALL = "hasta el %s · %s en total"
-- EN: until %s · %s in all
L.RUN_UNTIL_TABLE = "hasta el %s · %s en la mesa"
-- EN: until %s · %s on the table
L.SEAL_SETTLED_WORD = "Liquidada"
-- EN: Settled
L.SHAPES = { timed = "Con horario", big = "Grandes", quality = "Calidad", haul = "Redada", named = "Pez con nombre" }
-- EN: { big = "Big ones", haul = "Haul", named = "Named fish", quality = "Quality", timed = "Timed" }
L.RUN_HUNT_CAUGHT = "%s capturas"
-- EN: %s caught
L.RUN_WINDOW_OPEN = "abierta ya, hasta %s"
-- EN: open now, until %s
L.RUN_WINDOW_SHUT = "abre a las %s, en %s"
-- EN: opens at %s, in %s
L.RUN_CASTS_ONE = "%s Lance en estas aguas en esta ronda · %d de %d primeras marcas"
-- EN: %s Cast in these waters this run · %d of %d first marks
L.RUN_CASTS_OTHER = "%s Lances en estas aguas en esta ronda · %d de %d primeras marcas"
-- EN: %s Casts in these waters this run · %d of %d first marks
L.PAY_SO_FAR = "Pagado hasta ahora"
-- EN: Paid so far
L.PAY_AMOUNT = "+%d XP · %d Monedas"
-- EN: +%d XP · %d Coins
L.PAY_SETTLE = "Al liquidarla"
-- EN: Settle it
L.PAY_SETTLED = "Liquidada"
-- EN: Settled
L.PAY_PAID_OUT = "pagado"
-- EN: paid out
L.RUN_PAY_RULE = "La primera marca de cada Caza paga +%d XP y %d Monedas, cada nivel posterior +%d XP y %d Monedas, y "
	.. "liquidar la apuesta +%d XP y %d Monedas más."
-- EN: Each Hunt's first mark pays +%d XP and %d Coins, each tier after it +%d XP and %d Coins, and settling the wager +%d XP and %d Coins more.
L.PAY_REFRESH_ONE = "+%s Renovación"
-- EN: +%s Refresh
L.PAY_REFRESH_OTHER = "+%s Renovaciones"
-- EN: +%s Refreshes
L.REFRESH_ONE = "%s Renovación"
-- EN: %s Refresh
L.REFRESH_OTHER = "%s Renovaciones"
-- EN: %s Refreshes
L.RUN_PAY_RULE_REFRESH_BOTH = " La tercera marca de una Caza también paga %s, y liquidar la apuesta %d más."
-- EN: " A Hunt's third mark also pays %s, and settling the wager %d more."
L.RUN_PAY_RULE_REFRESH_TIER = " La tercera marca de una Caza también paga %s."
-- EN: " A Hunt's third mark also pays %s."
L.RUN_PAY_RULE_REFRESH_RUN = " Liquidar la apuesta también paga %s."
-- EN: " Settling the wager also pays %s."
L.ENTRY_NONE_TITLE = "Nada que leer aún"
-- EN: Nothing to read yet
L.ENTRY_NONE_HAND = "Cuando salga una apuesta, se escribirá aquí: sus aguas, sus Cazas y lo que paga."
-- EN: When a wager goes up it will be written here: its waters, its Hunts and what it pays.

L.RIBBON_ON = "%d en curso"
-- EN: %d on
L.SPREAD_TITLE = "En la mesa"
-- EN: On the table
L.SPREAD_NOTE_MANY = "%d apuestas en curso. Consigue la primera marca de cada Caza antes de que cierre su apuesta."
-- EN: %d wagers on. Land every Hunt's first mark before its wager closes.
L.SPREAD_NOTE_ONE = "Una apuesta en curso. Consigue la primera marca de cada Caza antes de que cierre."
-- EN: One wager on. Land every Hunt's first mark before it closes.
L.SPREAD_NOTE_AHEAD = "Nada en curso ahora mismo. La próxima apuesta abre el %s."
-- EN: Nothing on just now. The next wager opens %s.
L.SPREAD_NOTE_NONE = "Nada en la mesa, y nada anunciado aún."
-- EN: Nothing on the table, and nothing posted yet.
L.SPREAD_CLOSING = "¡%s cierra en %s!"
-- EN: %s closes in %s!
L.SPREAD_ON_NOW = "En curso"
-- EN: On now
L.SPREAD_AHEAD = "Próximas"
-- EN: Ahead
L.SPREAD_AHEAD_CAPTION = "anunciadas, pueden cambiar antes de abrir"
-- EN: posted, and may change before it opens
L.SPREAD_EMPTY = "No hay apuestas en la mesa ni anunciadas. La rotación pondrá una en el próximo turno."
-- EN: No wagers on the table, and none posted ahead. The rotation puts one on at the next turn.
L.TICKET_CLOSED_AT = "cerró el %s"
-- EN: closed %s
L.TICKET_CLOSED = "cerrada"
-- EN: closed
L.TICKET_MARKS = "%d de %d primeras marcas"
-- EN: %d of %d first marks
L.TICKET_UPDATING = "actualizando…"
-- EN: updating…
L.NEEDS_SKILL = "necesita habilidad %d"
-- EN: needs skill %d
L.AHEAD_OPENS = "abre el %s"
-- EN: opens %s
L.AHEAD_FOR = "durante %s"
-- EN: for %s
L.LADDER_LABEL = "La escalera"
-- EN: The ladder
L.HOLIDAYS = {
	hallows_end = "Halloween",
	winter_veil = "Festival de Invierno",
	lunar_festival = "Festival Lunar",
	noblegarden = "Jardín Noble",
	midsummer = "Festival del Fuego del Solsticio de Verano",
	harvest_festival = "Festival de la Cosecha",
	stv_extravaganza = "Torneo de pesca de Tuercespina",
}
-- EN: { hallows_end = "Hallow's End", harvest_festival = "Harvest Festival", lunar_festival = "Lunar Festival", midsummer = "Midsummer Fire Festival", noblegarden = "Noblegarden", stv_extravaganza = "Stranglethorn Fishing Extravaganza", winter_veil = "Feast of Winter Veil" }
L.WAGERS_SETTLED_ONE = "%s apuesta liquidada"
-- EN: %s wager settled
L.WAGERS_SETTLED_OTHER = "%s apuestas liquidadas"
-- EN: %s wagers settled
L.WAGERS_LADDER_LINE = "%s · %d más para %s"
-- EN: %s · %d more for %s

L.GUIDE_BLURB = "Peces que solo pican de noche, en invierno o en la feria, y cuáles pican ahora mismo."
-- EN: Fish that only bite at night, in winter or at the fair, and which of them bite right now.
L.LOOK_TITLE = "Cazas"
-- EN: Hunts
L.LOOK_GROUPS = "*Ahora*, *Pronto* y *Más tarde*: lo que está abierto, lo que abre en tres horas y el resto."
-- EN: *Now*, *Soon* and *Later*: what’s open, what opens within three hours, and the rest.
L.LOOK_NOW_LINE =
	"La línea roja es el *ahora*, en hora del reino. Las barras rayadas marcan cuándo está abierta cada Caza."
-- EN: The red line is *now*, in realm time. Hatched bars are when each Hunt is open.
L.LOOK_NATURAL =
	"*Natural* significa que el propio juego limita las horas de este pez. Las Cazas impuestas son reglas de Pagle."
-- EN: *Natural* means the game itself keeps this fish to its hours. Imposed Hunts are Pagle’s own rules.
L.LOOK_PIN = "*Fija* una Caza para tenerla en tu rastreador mientras pescas."
-- EN: *Pin* a Hunt to keep it on your tracker while you fish.
L.LOOK_SETS = "Cada cinta es una *serie de Cazas*. Completa todas sus Cazas y su título es tuyo. *Apuestas Pagle* "
	.. "guarda las apuestas que hay ahora en la mesa."
-- EN: Each ribbon is a *Hunt set*. Finish every Hunt in one and its title is yours. *Pagle Wagers* holds the wagers on the table now.
L.LOOK_AGAIN = "Mostrar otra vez las notas de esta página"
-- EN: Show the notes for this page again
L.HINT_MISSING =
	"Hay apuestas nuevas por ahí. El acompañante de Pagle las trae: más XP, más Monedas y el estilo de aviso Sonar Scope."
-- EN: New wagers are out there. The Pagle companion brings them: more XP, more Coins, and the Sonar Scope toast style.
L.HINT_NOD = "Hay apuestas nuevas por ahí. El acompañante de Pagle las trae: más XP, más Monedas."
-- EN: New wagers are out there. The Pagle companion brings them: more XP, more Coins.
L.HINT_FIRST_INSTALL = "¿Acabas de instalarlo? Sal a la selección de personaje una vez."
-- EN: Installed it just now? Log out to character select once.
L.HINT_NOT_RUNNING = "El acompañante de Pagle no está en marcha. Ábrelo para recibir las apuestas de esta semana."
-- EN: The Pagle companion isn't running. Start it to get this week's wagers.
L.HINT_GET_IT = "Conseguirlo"
-- EN: Get it
L.HINT_DISMISS = "Descartar"
-- EN: Dismiss
L.HINT_ADDRESS_KICKER = "El acompañante de Pagle"
-- EN: The Pagle companion
L.HINT_ADDRESS_COPY = "Ctrl+C para copiar"
-- EN: Ctrl+C to copy
L.HINT_ADDRESS_CLOSE = "Cerrar"
-- EN: Close
L.TRACKER_HINT_MISSING = "Apuestas nuevas con el acompañante de Pagle"
-- EN: New wagers with the Pagle companion
L.TRACKER_HINT_NOT_RUNNING = "Acompañante de Pagle detenido"
-- EN: Pagle companion not running
L.TRACKER_HINT_WHY = "¿por qué?"
-- EN: why?
L.COMPANION_HINT_SETTING = "Recordarme lo del acompañante de Pagle"
-- EN: Remind me about the Pagle companion
L.COMPANION_HINT_TOOLTIP = "Una línea en el tablero de Cazas, y un Gesto una vez por semana, mientras el acompañante "
	.. "de Pagle no te traiga apuestas nuevas."
-- EN: A line on the Hunts board, and a Nod once a week, while the Pagle companion isn't bringing you new wagers.
