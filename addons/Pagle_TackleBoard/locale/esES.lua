if not Pagle then -- luacheck: read globals Pagle
	return
end
if not GetLocale or GetLocale() ~= "esES" then
	return
end

-- The Tackle Board's Spanish (Spain) strings, over enUS.lua's.
local ns = select(2, ...)
local L = ns.L

L.TITLE = "Tablón de aparejos"
-- EN: Tackle Board
L.BOARD = "Tablón de aparejos"
-- EN: Tackle Board
L.BOARD_SLASH_HELP = "Abrir o cerrar el Tablón de aparejos"
-- EN: Open or close the Tackle Board
L.START_MY_BOARD = "Empezar mi tablón"
-- EN: Start my board
L.OPEN_BOARD = "Abrir Tablón de aparejos"
-- EN: Open Tackle Board
L.EMPTY_SLIP = "Cada día se cuelgan tres Avisos y cada semana una Expedición. Pesca como quieras: "
	.. "se van cumpliendo solos. Nunca se retira nada por llegar tarde."
-- EN: Three Notices go up each day and an Expedition each week. Fish as you like: they fill in as you go. Nothing is ever taken down for being late.
L.UPDATING = "Actualizando…"
-- EN: Updating…
L.UPDATING_NOTE = "Repasando cada Lance desde que se colgó el tablón. Retirar objetivos espera a que termine."
-- EN: Reading back every Cast since the board went up. Taking goals down waits until it's done.

L.AREA_UNKNOWN = "Zona {id}"
-- EN: Area {id}
L.CONTINENT_UNKNOWN = "Continente {id}"
-- EN: Continent {id}
L.CONTINENT_NAMES = { [0] = "Reinos del Este", [1] = "Kalimdor" }
-- EN: { "Kalimdor", [0] = "Eastern Kingdoms" }
L.GOAL_TEXT = {
	n = {
		haul = { one = "{n} Captura en {zone}", other = "{n} Capturas en {zone}" },
		variety = { one = "{n} Especie en {zone}", other = "{n} Especies distintas en {zone}" },
		wanderer = { one = "Capturas en {n} zona hoy", other = "Capturas en {n} zonas hoy" },
		rarity = {
			one = "Una Captura de variedad {rarity} o mejor",
			other = "{n} Capturas de variedad {rarity} o mejor",
		},
		collector = "Un objeto de basura y un contenedor hoy",
		lure = { one = "Una Captura con señuelo", other = "{n} Capturas con señuelo" },
		species = "{n} {species}",
	},
	e = {
		haul = { one = "{n} Captura en {zone}", other = "{n} Capturas en {zone}" },
		variety = "Todas las Especies de {zone}",
		wanderer = { one = "Capturas en {n} zona de {continent}", other = "Capturas en {n} zonas de {continent}" },
		rarity = {
			one = "Una Captura de variedad {rarity} o mejor",
			other = "{n} Capturas de variedad {rarity} o mejor",
		},
		collector = {
			one = "Un objeto de Subcolección que no tienes",
			other = "{n} objetos de Subcolección que no tienes",
		},
	},
}
-- EN: { e = { collector = { one = "A Sub-collection item you don't have", other = "{n} Sub-collection items you don't have" }, haul = { one = "{n} Catch in {zone}", other = "{n} Catches in {zone}" }, rarity = { one = "A Catch of {rarity} variety or better", other = "{n} Catches of {rarity} variety or better" }, variety = "Every Species of {zone}", wanderer = { one = "Catches in {n} zone of {continent}", other = "Catches in {n} zones of {continent}" } }, n = { collector = "A junk item and a container today", haul = { one = "{n} Catch in {zone}", other = "{n} Catches in {zone}" }, lure = { one = "A Catch with a lure on", other = "{n} Catches with a lure on" }, rarity = { one = "A Catch of {rarity} variety or better", other = "{n} Catches of {rarity} variety or better" }, species = "{n} {species}", variety = { one = "{n} Species in {zone}", other = "{n} different Species in {zone}" }, wanderer = { one = "Catches in {n} zone today", other = "Catches in {n} zones today" } } }
-- No article: GOAL_TEXT's rarity lines read "de variedad {rarity}", so these agree with "variedad".
L.RARITY_NAMES = { [2] = "poco común", [3] = "rara" }
-- EN: { [2] = "an uncommon", [3] = "a rare" }
L.KINDS = {
	haul = "Botín",
	variety = "Variedad",
	wanderer = "Viajero",
	rarity = "Rareza",
	collector = "Coleccionista",
	lure = "Señuelo",
	species = "Especie",
}
-- EN: { collector = "Collector", haul = "Haul", lure = "Lure", rarity = "Rarity", species = "Species", variety = "Variety", wanderer = "Wanderer" }
L.WHEREVER_IT_BITES = "donde piquen"
-- EN: wherever it bites
L.ANYWHERE = "en cualquier sitio"
-- EN: anywhere
L.WHERE_TODAY = "hoy · {where}"
-- EN: today · {where}
L.WHERE_HERE = "{where} · aquí"
-- EN: {where} · here
L.POSTED = "Colgado el {weekday} {day} {month}, {time}"
-- EN: Posted {weekday} {day} {month}, {time}
L.WEEKDAYS = { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" }
-- EN: { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
L.MONTHS = { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic" }
-- EN: { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
L.HOURS_LEFT = "{n} h"
-- EN: {n}h
L.MINUTES_LEFT = "{n} min"
-- EN: {n}m
L.TAKE_DOWN_TITLE = { n = "¿Retirar este Aviso?", e = "¿Retirar esta Expedición?" }
-- EN: { e = "Take down this Expedition?", n = "Take down this Notice?" }
L.TAKE_DOWN_TEXT = "Se pierde su progreso ({progress}) y el nuevo objetivo no se podrá retirar otra vez hoy."
-- EN: Its progress ({progress}) is lost, and the new one can't be taken down again today.
L.TAKE_DOWN_YES = "Retirar"
-- EN: Take it down
L.TAKE_DOWN_NO = "Mantener"
-- EN: Keep it
L.POST_TITLE = { n = "¿Colgar un Aviso nuevo?", e = "¿Colgar una Expedición nueva?" }
-- EN: { e = "Post a new Expedition?", n = "Post a new Notice?" }
L.POST_TEXT =
	"Esto gasta {cost} y no se puede deshacer. El nuevo objetivo se puede retirar una vez al día, como cualquier otro."
-- EN: This uses {cost}, and it can't be undone. The new goal can be taken down once a day, like any other.
L.POST_YES = "Colgar"
-- EN: Post it
L.POST_TIP_TITLE = { n = "Colgar un Aviso ahora", e = "Colgar una Expedición ahora" }
-- EN: { e = "Post an Expedition now", n = "Post a Notice now" }
L.POST_TIP = {
	n = "Haz clic para clavar aquí un Aviso nuevo en vez de esperar al próximo reinicio.",
	e = "Haz clic para clavar aquí una Expedición nueva en vez de esperar al reinicio semanal.",
}
-- EN: { e = "Click to pin a fresh Expedition here instead of waiting for the weekly reset.", n = "Click to pin a fresh Notice here instead of waiting for the next reset." }
L.POST_TIP_COST = "Gasta 1 Renovación. Tienes {held}."
-- EN: It uses 1 Refresh. You hold {held}.
L.CATCHES = { one = "{n} Captura", other = "{n} Capturas" }
-- EN: { one = "{n} Catch", other = "{n} Catches" }
L.REFRESHES = { one = "{n} Renovación", other = "{n} Renovaciones" }
-- EN: { one = "{n} Refresh", other = "{n} Refreshes" }
L.REFRESHES_HELD = { one = "{n} Renovación disponible", other = "{n} Renovaciones disponibles" }
-- EN: { one = "{n} Refresh held", other = "{n} Refreshes held" }
L.REFRESH_TIP_TITLE = "Renovaciones"
-- EN: Refreshes
L.REFRESH_TIP =
	"Cada una cuelga un Aviso o una Expedición nuevos en un hueco libre del tablón. Haz clic en un hueco libre para usarla."
-- EN: Each one posts a fresh Notice or Expedition in an empty slot on the board. Click an empty slot to use one.
L.REFRESH_TIP_SOURCE = "Se ganan con las Apuestas Pagle."
-- EN: Pagle Wagers earn them.
L.COINS = { one = "{n} Moneda", other = "{n} Monedas" }
-- EN: { one = "{n} Coin", other = "{n} Coins" }

L.PROGRESS = "{n} de {need}"
-- EN: {n} of {need}
L.PROGRESS_TODAY = "{n} de {need} hoy"
-- EN: {n} of {need} today
L.PAYS = { one = "paga {n} Moneda", other = "paga {n} Monedas" }
-- EN: { one = "pays {n} Coin", other = "pays {n} Coins" }
L.PAYS_WORD = "paga"
-- EN: pays
L.EXPEDITION = "Expedición"
-- EN: Expedition
L.IM_HERE = "Estoy aquí"
-- EN: I'm here
L.NO_LONGER_CATCHABLE = "ya no se puede pescar"
-- EN: no longer catchable
L.TAKE_IT_DOWN = "retirar"
-- EN: take it down
L.TAKE_DOWN_TIP_TITLE = "Retirar"
-- EN: Take it down
L.TAKE_DOWN_TIP = {
	n = "Clava en su lugar un Aviso nuevo de otro tipo. Se pierde el progreso de este.",
	e = "Clava en su lugar una Expedición nueva de otro tipo. Se pierde el progreso de esta.",
}
-- EN: { e = "Pin a fresh Expedition of another kind in its place. Any progress on this one is lost.", n = "Pin a fresh Notice of another kind in its place. Any progress on this one is lost." }
L.TAKE_DOWN_TIP_ONCE =
	"El nuevo objetivo no se podrá retirar hasta el reinicio diario (en {time}), salvo que deje de poder pescarse."
-- EN: The new one can't be taken down again until the daily reset (in {time}), unless it stops being catchable.
L.TAKE_DOWN_TIP_STRANDED =
	"Este objetivo ya no se puede pescar, así que puede retirarse aunque sea un reemplazo de hoy."
-- EN: This one is no longer catchable, so it can come down even though it was re-posted today.
L.TAKE_DOWN_TIP_STRANDED_FIRST = "Este objetivo ya no se puede pescar: nunca podrá cumplirse donde está colgado."
-- EN: This one is no longer catchable: it can never be finished where it hangs.
L.TAKE_DOWN_TIP_UPDATING = "No mientras el tablón se actualiza. Podrá retirarse cuando termine."
-- EN: Not while the board is updating. It can come down once that's done.
-- A noun, not a participle: the stamp lands on a Notice (masculine) or an Expedition (feminine) alike.
L.REPOSTED = "REEMPLAZO"
-- EN: RE-POSTED
L.REPOSTED_HOVER = "Reemplazo de hoy. Se podrá retirar otra vez en el reinicio diario (en {time})."
-- EN: Re-posted today. It can be taken down again at the daily reset (in {time}).
L.ONLY_SINCE = "Solo cuentan mis Capturas desde entonces"
-- EN: Only my Catches since then count
L.ONLY_SINCE_TODAY = "Solo cuentan mis Capturas desde entonces, todas en un mismo día del tablón"
-- EN: Only my Catches since then count, all on one board day
L.EMPTY_NOTICE = "Un Aviso nuevo en el reinicio (en {time})"
-- EN: A fresh Notice at reset (in {time})
L.EMPTY_NOTICE_LATER = "Más Avisos en próximos reinicios"
-- EN: More Notices at later resets
L.EMPTY_EXPEDITION = "Próxima Expedición en el reinicio semanal ({weekday})"
-- EN: Next Expedition at the weekly reset ({weekday})
L.EMPTY_EXPEDITION_LATER = "Otra en el reinicio semanal siguiente"
-- EN: Another at the weekly reset after
L.OVERFLOW_MORE = "+{n} más esperando un hueco"
-- EN: +{n} more waiting for a pin

-- "Hechos hoy: {n}" so a count of 1 reads right without a plural pair.
L.SPIKE_DONE = "Hechos hoy: {n}. El fuego arde."
-- EN: {n} done today. The fire's lit.
L.SPIKE_EMPTY = "Los hechos van al pincho."
-- EN: Done ones go on the spike.
L.SPIKE_HEAD = "Hechos hoy"
-- EN: Done today
L.SPIKE_COINS = { one = "Pagó {n} Moneda", other = "Pagó {n} Monedas" }
-- EN: { one = "Paid {n} Coin", other = "Paid {n} Coins" }
L.SPIKE_FLY = "Montada para tu Caja de moscas: {fly}"
-- EN: Tied for your Fly Box: {fly}

L.CAMPFIRE_OUT = "Apagada"
-- EN: Gone out
L.CAMPFIRE_UNLIT = "Aún sin encender"
-- EN: Not lit yet
L.CAMPFIRE_LONGEST = "récord {n}"
-- EN: longest {n}
L.DAYS_WORD = { one = "día", other = "días" }
-- EN: { one = "day", other = "days" }
L.CARD_DAYS = {
	lit = "encendida",
	burned = "Leña quemada",
	out = "se apagó",
	unlit = "sin encender",
	before = "antes del tablón",
	today = "hoy",
}
-- EN: { before = "before the board", burned = "Kindling burned", lit = "lit", out = "went out", today = "today", unlit = "not lit" }
L.CARD_NEEDS = {
	campfire = "una Hoguera de {n} días",
	tally = "{n} objetivos hechos",
	flybox = "la Caja de moscas completa",
}
-- EN: { campfire = "a Campfire of {n} days", flybox = "every Fly Box pattern tied", tally = "{n} goals done" }
L.FLY_BOX_TIED = "{n} de {total} montadas"
-- EN: {n} of {total} tied
L.FLY_UNTIED = "aún sin montar"
-- EN: not tied yet
L.FLY_TIED = "Montada el {date}"
-- EN: Tied {date}
L.FLY_GOAL = "por: {goal}"
-- EN: by: {goal}
L.FLY_RARE = "solo se monta con Expediciones"
-- EN: tied only by Expeditions
L.TALLY_NO_TITLE = "aún sin título"
-- EN: no title yet
L.SHOP_LINK = "Monedas para la Tienda de Curiosidades"
-- EN: Coins go to the Curio Shop
L.CARD_TITLE = "La Hoguera"
-- EN: The Campfire
L.KINDLING = "{n} de Leña"
-- EN: {n} Kindling
L.FLY_BOX = "Caja de moscas"
-- EN: Fly Box
L.CARD_WEEKS = "Las últimas cuatro semanas"
-- EN: The last four weeks
L.CARD_WEEKS_NOTE = "días del tablón, hora del reino"
-- EN: board days, realm time
L.CARD_MILESTONES = "Hitos"
-- EN: Milestones
L.CARD_MILESTONES_NOTE = "cada uno paga una vez"
-- EN: each pays once
L.CARD_TITLES = "Títulos"
-- EN: Titles
L.CARD_TITLES_NOTE = "solo se ven en el tablón"
-- EN: shown on the board only
L.CARD_LABELS = { campfire = "{n} días", tally = "{n} objetivos", flybox = "Caja de moscas" }
-- EN: { campfire = "{n} days", flybox = "Fly Box", tally = "{n} goals" }
L.CARD_MORE_CAMPFIRE = { one = "{n} día más", other = "{n} días más" }
-- EN: { one = "{n} more day", other = "{n} more days" }
L.CARD_MORE_TALLY = { one = "{n} objetivo más", other = "{n} objetivos más" }
-- EN: { one = "{n} more goal", other = "{n} more goals" }
L.CARD_MORE_FLYBOX = { one = "{n} patrón más", other = "{n} patrones más" }
-- EN: { one = "{n} more pattern", other = "{n} more patterns" }

L.DAYS = { one = "{n} día", other = "{n} días" }
-- EN: { one = "{n} day", other = "{n} days" }
L.NOTICE_COMPLETE = "Aviso completado"
-- EN: Notice complete
L.EXPEDITION_COMPLETE = "Expedición completada"
-- EN: Expedition complete
L.TIED_FOR_FLY_BOX = "{goal}. Montada para tu Caja de moscas: {fly}"
-- EN: {goal}. Tied for your Fly Box: {fly}
L.NOTICE_DONE = "Aviso cumplido"
-- EN: Notice done
L.EXPEDITION_DONE = "Expedición cumplida"
-- EN: Expedition done
L.CAMPFIRE_MILESTONE = "Hoguera: {n} días"
-- EN: Campfire: {n} days
L.TALLY_TITLE = "{n} objetivos hechos"
-- EN: {n} goals done
L.FLY_BOX_COMPLETE = "Todos los patrones montados"
-- EN: Every pattern tied
L.TITLE_LINE = "Título: {title}"
-- EN: Title: {title}
L.KINDLING_AWAY = "Tu Hoguera siguió ardiendo mientras no estabas: gastó {k} de Leña y sigue en {count}."
-- EN: Your Campfire kept burning while you were away: {k} Kindling used, still {count}.
L.KINDLING_BURNED = "Pasó un día sin objetivos: se gastó {k} de Leña. La Hoguera sigue en {count}."
-- EN: A day went by without a goal: {k} Kindling used. Campfire still {count}.
L.FIRE_OUT_AWAY = "Tu Hoguera se apagó mientras no estabas. Tu récord, {longest}, se guarda para siempre. "
	.. "Cualquier objetivo enciende una nueva, con 2 de Leña nueva."
-- EN: Your Campfire went out while you were away. Your longest, {longest}, is kept for good. Any goal lights a new one, with 2 fresh Kindling.
L.FIRE_OUT = "Tu Hoguera se apagó. Tu récord, {longest}, se guarda para siempre. "
	.. "Cualquier objetivo enciende una nueva, con 2 de Leña nueva."
-- EN: Your Campfire went out. Your longest, {longest}, is kept for good. Any goal lights a new one, with 2 fresh Kindling.
L.WRITE_UP_FIRST = {
	one = "Tu Tablón de aparejos se redactó a partir de {n} Lance",
	other = "Tu Tablón de aparejos se redactó a partir de {n} Lances",
}
-- EN: { one = "Your Tackle Board was written up from {n} Cast", other = "Your Tackle Board was written up from {n} Casts" }
L.WRITE_UP_WHILE_OFF = "Mientras el Tablón de aparejos estaba desactivado"
-- EN: While Tackle Board was off
L.NOTICES = { one = "{n} Aviso", other = "{n} Avisos" }
-- EN: { one = "{n} Notice", other = "{n} Notices" }
L.EXPEDITIONS = { one = "{n} Expedición", other = "{n} Expediciones" }
-- EN: { one = "{n} Expedition", other = "{n} Expeditions" }
L.GOALS_AND = "{notices} y {expeditions}"
-- EN: {notices} and {expeditions}
L.GOALS_DONE = "Cumplidos: {goals}"
-- EN: {goals} done
L.COINS_LINE = "Monedas Pagle +{coins}"
-- EN: Pagle Coins +{coins}
L.XP_LINE = "XP de Pescador +{xp}"
-- EN: Angler XP +{xp}
L.FLIES_TIED = {
	one = "{n} mosca montada para tu Caja de moscas",
	other = "{n} moscas montadas para tu Caja de moscas",
}
-- EN: { one = "{n} fly tied for your Fly Box", other = "{n} flies tied for your Fly Box" }
L.CAMPFIRE_DAYS = { one = "Hoguera de {n} día", other = "Hoguera de {n} días" }
-- EN: { one = "Campfire {n} day", other = "Campfire {n} days" }
L.CAMPFIRE_BURNED = "{campfire} · {k} de Leña quemada"
-- EN: {campfire} · {k} Kindling burned
L.CAMPFIRE_WENT_OUT = "Tu Hoguera se apagó; tu récord, {longest}, se conserva"
-- EN: Your Campfire went out; your longest, {longest}, is kept
L.SUMMARY_LINE = "Tablón de aparejos: {done} · {campfire}"
-- EN: Tackle Board: {done} · {campfire}
L.SUMMARY_LINE_NOTHING_DONE = "Tablón de aparejos: {campfire}"
-- EN: Tackle Board: {campfire}
L.DONE_TODAY = "hechos hoy: {n}"
-- EN: {n} done today
L.CAMPFIRE_NOT_LIT = "Hoguera sin encender"
-- EN: Campfire not lit

L.SLOT_TRACKER_FRAME = "Marco de rastreador del Tablón de aparejos"
-- EN: Tackle Board tracker frame
L.GOOD_EARNED_CAMPFIRE = "Hoguera: {days} días"
-- EN: Campfire: {days} days
L.TRACKER_OPEN = "{n} por hacer"
-- EN: {n} open
L.TRACKER_EXPEDITION = "Expedición: {text}"
-- EN: Expedition: {text}
L.TRACKER_MORE = "+{n} más en el tablón (en otro sitio)"
-- EN: +{n} more on the board (elsewhere)
L.TRACKER_ALL_DONE = "Todo hecho. Avisos nuevos en el reinicio."
-- EN: All done. Fresh Notices at reset.
L.TRACKER_COMPLETE = "Hecho"
-- EN: Complete

L.SETTINGS_TRACKER = "Mostrar objetivos que puedes hacer aquí"
-- EN: Show goals workable here
-- "Empezar mi tablón" is START_MY_BOARD's button text.
L.SETTINGS_TRACKER_TOOLTIP = "Muestra los objetivos que puedes hacer donde estás. Antes de empezar tu tablón, usa "
	.. "Empezar mi tablón en la página de Pagle."
-- EN: Lists the goals you can work on where you are. Before your board is started, use Start my board on the Pagle page.

L.GUIDE_BLURB = "Pequeños objetivos clavados en un tablón de corcho, si los quieres. Te esperan mientras no estás."
-- EN: Small goals pinned to a cork board, if you want them. They wait while you’re away.
L.GUIDE_RIBBON = "Tablón de aparejos"
-- EN: Tackle Board
L.GUIDE_SKIP = "Ahora no"
-- EN: Not now
L.GUIDE_KICKER = "El Tablón de aparejos"
-- EN: The Tackle Board
L.GUIDE_TITLE = "Objetivos que te esperan"
-- EN: Goals that wait for you
L.GUIDE_BODY = "Pequeños Avisos clavados en un tablón de corcho: un pez que encontrar, unas aguas que visitar. "
	.. "Pesca cuando quieras; seguirán ahí."
-- EN: Small Notices pinned to a cork board: a fish to find, a water to visit. Fish when you like; they’ll still be there.
L.GUIDE_CAMPFIRE = "{campfire} crece cada día que cumples un Aviso. Si fallas un día, se quema {kindling} en su lugar; "
	.. "no se apaga."
-- EN: {campfire} grows with each day you finish a Notice. Miss a day and {kindling} burns instead; it isn’t put out.
L.GUIDE_CAMPFIRE_TERM = "Tu Hoguera"
-- EN: Your Campfire
L.GUIDE_KINDLING_TERM = "Leña"
-- EN: Kindling
L.GUIDE_FLY_BOX = "Cada Aviso que cumples monta una mosca para tu {flybox}."
-- EN: Each Notice you finish ties one fly for your {flybox}.
L.GUIDE_ASK_KICKER = "Solo si quieres uno"
-- EN: Only if you want one
L.GUIDE_ASK_TITLE = "¿Te cuelgo un tablón?"
-- EN: Shall I put up a board?
L.GUIDE_FACTS = {
	"Tres Avisos al día y una Expedición más grande a la semana.",
	"Ninguno caduca. ¿Te vas una temporada? Te esperan hasta seis Avisos y dos Expediciones.",
	"¿No te convence uno? Cada uno se puede cambiar por otro nuevo, una vez al día.",
	"Pagan Monedas Pagle, {shop}",
}
-- EN: { "Three Notices a day, and one bigger Expedition a week.", "None of them expire. Away a while? Up to six Notices and two Expeditions wait for you.", "Don’t fancy one? Each can be taken down for a fresh one, once a day.", "They pay Pagle Coins, {shop}" }
L.GUIDE_FACT_SHOP = "para aspectos de la Tienda de Curiosidades."
-- EN: which buy looks in the Curio Shop.
L.BOARD_IS_UP = "Tu tablón está colgado"
-- EN: Your board is up
L.GUIDE_LEAVE = "O déjalo para luego. El tablón espera en Tablón de aparejos, en el menú de Pagle, y en Ajustes."
-- EN: Or leave it for now. The board waits under Tackle Board in the Pagle menu, and in Settings.
L.LOOK_TITLE = "el Tablón de aparejos"
-- EN: the Tackle Board
L.LOOK_NOTES = {
	{ text = "Las {term} son las grandes, semanales. También esperan, hasta dos.", term = "Expediciones" },
	{ text = "Un Aviso {term}. ¿No te convence? Retíralo, una vez al día, por otro.", term = "nunca caduca" },
	{ text = "Tu {term}: días seguidos con uno cumplido. Un día perdido quema Leña en su lugar.", term = "Hoguera" },
	{ text = "Cada uno cumplido monta una mosca para tu {term}.", term = "Caja de moscas" },
	{ text = "Pagan {term}, que se gastan en aspectos de la Tienda de Curiosidades.", term = "Monedas Pagle" },
}
-- EN: { { term = "Expeditions", text = "{term} are the bigger weekly ones. They wait too, up to two." }, { term = "never expires", text = "A Notice {term}. Don’t fancy it? Take it down, once a day, for another." }, { term = "Campfire", text = "Your {term}: days in a row with one done. A missed day burns Kindling instead." }, { term = "Fly Box", text = "Each one done ties a fly for your {term}." }, { term = "Pagle Coins", text = "They pay {term}, spent on looks in the Curio Shop." } }
L.LOOK_AGAIN = "Mostrar otra vez las notas de esta página"
-- EN: Show the notes for this page again
