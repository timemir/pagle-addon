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
L.BOARD = "Tablón de aparejos"
L.BOARD_SLASH_HELP = "Abrir o cerrar el Tablón de aparejos"
L.START_MY_BOARD = "Empezar mi tablón"
L.OPEN_BOARD = "Abrir Tablón de aparejos"
L.EMPTY_SLIP = "Cada día se cuelgan tres Avisos y cada semana una Expedición. Pesca como quieras: "
	.. "se van cumpliendo solos. Nunca se retira nada por llegar tarde."
L.UPDATING = "Actualizando…"
L.UPDATING_NOTE = "Repasando cada Lance desde que se colgó el tablón. Retirar objetivos espera a que termine."

L.AREA_UNKNOWN = "Zona {id}"
L.CONTINENT_UNKNOWN = "Continente {id}"
L.CONTINENT_NAMES = { [0] = "Reinos del Este", [1] = "Kalimdor" }
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
-- No article: GOAL_TEXT's rarity lines read "de variedad {rarity}", so these agree with "variedad".
L.RARITY_NAMES = { [2] = "poco común", [3] = "rara" }
L.KINDS = {
	haul = "Botín",
	variety = "Variedad",
	wanderer = "Viajero",
	rarity = "Rareza",
	collector = "Coleccionista",
	lure = "Señuelo",
	species = "Especie",
}
L.WHEREVER_IT_BITES = "donde piquen"
L.ANYWHERE = "en cualquier sitio"
L.WHERE_TODAY = "hoy · {where}"
L.WHERE_HERE = "{where} · aquí"
L.POSTED = "Colgado el {weekday} {day} {month}, {time}"
L.WEEKDAYS = { "dom", "lun", "mar", "mié", "jue", "vie", "sáb" }
L.MONTHS = { "ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic" }
L.HOURS_LEFT = "{n} h"
L.MINUTES_LEFT = "{n} min"
L.TAKE_DOWN_TITLE = { n = "¿Retirar este Aviso?", e = "¿Retirar esta Expedición?" }
L.TAKE_DOWN_TEXT = "Se pierde su progreso ({progress}) y el nuevo objetivo no se podrá retirar otra vez hoy."
L.TAKE_DOWN_YES = "Retirar"
L.TAKE_DOWN_NO = "Mantener"
L.POST_TITLE = { n = "¿Colgar un Aviso nuevo?", e = "¿Colgar una Expedición nueva?" }
L.POST_TEXT =
	"Esto gasta {cost} y no se puede deshacer. El nuevo objetivo se puede retirar una vez al día, como cualquier otro."
L.POST_YES = "Colgar"
L.POST_TIP_TITLE = { n = "Colgar un Aviso ahora", e = "Colgar una Expedición ahora" }
L.POST_TIP = {
	n = "Haz clic para clavar aquí un Aviso nuevo en vez de esperar al próximo reinicio.",
	e = "Haz clic para clavar aquí una Expedición nueva en vez de esperar al reinicio semanal.",
}
L.POST_TIP_COST = "Gasta 1 Renovación. Tienes {held}."
L.CATCHES = { one = "{n} Captura", other = "{n} Capturas" }
L.REFRESHES = { one = "{n} Renovación", other = "{n} Renovaciones" }
L.REFRESHES_HELD = { one = "{n} Renovación disponible", other = "{n} Renovaciones disponibles" }
L.REFRESH_TIP_TITLE = "Renovaciones"
L.REFRESH_TIP =
	"Cada una cuelga un Aviso o una Expedición nuevos en un hueco libre del tablón. Haz clic en un hueco libre para usarla."
L.REFRESH_TIP_SOURCE = "Se ganan con las Apuestas Pagle."
L.COINS = { one = "{n} Moneda", other = "{n} Monedas" }

L.PROGRESS = "{n} de {need}"
L.PROGRESS_TODAY = "{n} de {need} hoy"
L.PAYS = { one = "paga {n} Moneda", other = "paga {n} Monedas" }
L.PAYS_WORD = "paga"
L.EXPEDITION = "Expedición"
L.IM_HERE = "Estoy aquí"
L.NO_LONGER_CATCHABLE = "ya no se puede pescar"
L.TAKE_IT_DOWN = "retirar"
L.TAKE_DOWN_TIP_TITLE = "Retirar"
L.TAKE_DOWN_TIP = {
	n = "Clava en su lugar un Aviso nuevo de otro tipo. Se pierde el progreso de este.",
	e = "Clava en su lugar una Expedición nueva de otro tipo. Se pierde el progreso de esta.",
}
L.TAKE_DOWN_TIP_ONCE =
	"El nuevo objetivo no se podrá retirar hasta el reinicio diario (en {time}), salvo que deje de poder pescarse."
L.TAKE_DOWN_TIP_STRANDED =
	"Este objetivo ya no se puede pescar, así que puede retirarse aunque sea un reemplazo de hoy."
L.TAKE_DOWN_TIP_STRANDED_FIRST = "Este objetivo ya no se puede pescar: nunca podrá cumplirse donde está colgado."
L.TAKE_DOWN_TIP_UPDATING = "No mientras el tablón se actualiza. Podrá retirarse cuando termine."
-- A noun, not a participle: the stamp lands on a Notice (masculine) or an Expedition (feminine) alike.
L.REPOSTED = "REEMPLAZO"
L.REPOSTED_HOVER = "Reemplazo de hoy. Se podrá retirar otra vez en el reinicio diario (en {time})."
L.ONLY_SINCE = "Solo cuentan mis Capturas desde entonces"
L.ONLY_SINCE_TODAY = "Solo cuentan mis Capturas desde entonces, todas en un mismo día del tablón"
L.EMPTY_NOTICE = "Un Aviso nuevo en el reinicio (en {time})"
L.EMPTY_NOTICE_LATER = "Más Avisos en próximos reinicios"
L.EMPTY_EXPEDITION = "Próxima Expedición en el reinicio semanal ({weekday})"
L.EMPTY_EXPEDITION_LATER = "Otra en el reinicio semanal siguiente"
L.OVERFLOW_MORE = "+{n} más esperando un hueco"

-- "Hechos hoy: {n}" so a count of 1 reads right without a plural pair.
L.SPIKE_DONE = "Hechos hoy: {n}. El fuego arde."
L.SPIKE_EMPTY = "Los hechos van al pincho."
L.SPIKE_HEAD = "Hechos hoy"
L.SPIKE_COINS = { one = "Pagó {n} Moneda", other = "Pagó {n} Monedas" }
L.SPIKE_FLY = "Montada para tu Caja de moscas: {fly}"

L.CAMPFIRE_OUT = "Apagada"
L.CAMPFIRE_UNLIT = "Aún sin encender"
L.CAMPFIRE_LONGEST = "récord {n}"
L.DAYS_WORD = { one = "día", other = "días" }
L.CARD_DAYS = {
	lit = "encendida",
	burned = "Leña quemada",
	out = "se apagó",
	unlit = "sin encender",
	before = "antes del tablón",
	today = "hoy",
}
L.CARD_NEEDS = {
	campfire = "una Hoguera de {n} días",
	tally = "{n} objetivos hechos",
	flybox = "la Caja de moscas completa",
}
L.FLY_BOX_TIED = "{n} de {total} montadas"
L.FLY_UNTIED = "aún sin montar"
L.FLY_TIED = "Montada el {date}"
L.FLY_GOAL = "por: {goal}"
L.FLY_RARE = "solo se monta con Expediciones"
L.TALLY_NO_TITLE = "aún sin título"
L.SHOP_LINK = "Monedas para la Tienda de Curiosidades"
L.CARD_TITLE = "La Hoguera"
L.KINDLING = "{n} de Leña"
L.FLY_BOX = "Caja de moscas"
L.CARD_WEEKS = "Las últimas cuatro semanas"
L.CARD_WEEKS_NOTE = "días del tablón, hora del reino"
L.CARD_MILESTONES = "Hitos"
L.CARD_MILESTONES_NOTE = "cada uno paga una vez"
L.CARD_TITLES = "Títulos"
L.CARD_TITLES_NOTE = "solo se ven en el tablón"
L.CARD_LABELS = { campfire = "{n} días", tally = "{n} objetivos", flybox = "Caja de moscas" }
L.CARD_MORE_CAMPFIRE = { one = "{n} día más", other = "{n} días más" }
L.CARD_MORE_TALLY = { one = "{n} objetivo más", other = "{n} objetivos más" }
L.CARD_MORE_FLYBOX = { one = "{n} patrón más", other = "{n} patrones más" }

L.DAYS = { one = "{n} día", other = "{n} días" }
L.NOTICE_COMPLETE = "Aviso completado"
L.EXPEDITION_COMPLETE = "Expedición completada"
L.TIED_FOR_FLY_BOX = "{goal}. Montada para tu Caja de moscas: {fly}"
L.NOTICE_DONE = "Aviso cumplido"
L.EXPEDITION_DONE = "Expedición cumplida"
L.CAMPFIRE_MILESTONE = "Hoguera: {n} días"
L.TALLY_TITLE = "{n} objetivos hechos"
L.FLY_BOX_COMPLETE = "Todos los patrones montados"
L.TITLE_LINE = "Título: {title}"
L.KINDLING_AWAY = "Tu Hoguera siguió ardiendo mientras no estabas: gastó {k} de Leña y sigue en {count}."
L.KINDLING_BURNED = "Pasó un día sin objetivos: se gastó {k} de Leña. La Hoguera sigue en {count}."
L.FIRE_OUT_AWAY = "Tu Hoguera se apagó mientras no estabas. Tu récord, {longest}, se guarda para siempre. "
	.. "Cualquier objetivo enciende una nueva, con 2 de Leña nueva."
L.FIRE_OUT = "Tu Hoguera se apagó. Tu récord, {longest}, se guarda para siempre. "
	.. "Cualquier objetivo enciende una nueva, con 2 de Leña nueva."
L.WRITE_UP_FIRST = {
	one = "Tu Tablón de aparejos se redactó a partir de {n} Lance",
	other = "Tu Tablón de aparejos se redactó a partir de {n} Lances",
}
L.WRITE_UP_WHILE_OFF = "Mientras el Tablón de aparejos estaba desactivado"
L.NOTICES = { one = "{n} Aviso", other = "{n} Avisos" }
L.EXPEDITIONS = { one = "{n} Expedición", other = "{n} Expediciones" }
L.GOALS_AND = "{notices} y {expeditions}"
L.GOALS_DONE = "Cumplidos: {goals}"
L.COINS_LINE = "Monedas Pagle +{coins}"
L.XP_LINE = "XP de Pescador +{xp}"
L.FLIES_TIED = {
	one = "{n} mosca montada para tu Caja de moscas",
	other = "{n} moscas montadas para tu Caja de moscas",
}
L.CAMPFIRE_DAYS = { one = "Hoguera de {n} día", other = "Hoguera de {n} días" }
L.CAMPFIRE_BURNED = "{campfire} · {k} de Leña quemada"
L.CAMPFIRE_WENT_OUT = "Tu Hoguera se apagó; tu récord, {longest}, se conserva"
L.SUMMARY_LINE = "Tablón de aparejos: {done} · {campfire}"
L.SUMMARY_LINE_NOTHING_DONE = "Tablón de aparejos: {campfire}"
L.DONE_TODAY = "hechos hoy: {n}"
L.CAMPFIRE_NOT_LIT = "Hoguera sin encender"

L.SLOT_TRACKER_FRAME = "Marco de rastreador del Tablón de aparejos"
L.GOOD_EARNED_CAMPFIRE = "Hoguera: {days} días"
L.TRACKER_OPEN = "{n} por hacer"
L.TRACKER_EXPEDITION = "Expedición: {text}"
L.TRACKER_MORE = "+{n} más en el tablón (en otro sitio)"
L.TRACKER_ALL_DONE = "Todo hecho. Avisos nuevos en el reinicio."
L.TRACKER_COMPLETE = "Hecho"

L.SETTINGS_TRACKER = "Mostrar objetivos que puedes hacer aquí"
-- "Empezar mi tablón" is START_MY_BOARD's button text.
L.SETTINGS_TRACKER_TOOLTIP = "Muestra los objetivos que puedes hacer donde estás. Antes de empezar tu tablón, usa "
	.. "Empezar mi tablón en la página de Pagle."

L.GUIDE_BLURB = "Pequeños objetivos clavados en un tablón de corcho, si los quieres. Te esperan mientras no estás."
L.GUIDE_RIBBON = "Tablón de aparejos"
L.GUIDE_SKIP = "Ahora no"
L.GUIDE_KICKER = "El Tablón de aparejos"
L.GUIDE_TITLE = "Objetivos que te esperan"
L.GUIDE_BODY = "Pequeños Avisos clavados en un tablón de corcho: un pez que encontrar, unas aguas que visitar. "
	.. "Pesca cuando quieras; seguirán ahí."
L.GUIDE_CAMPFIRE = "{campfire} crece cada día que cumples un Aviso. Si fallas un día, se quema {kindling} en su lugar; "
	.. "no se apaga."
L.GUIDE_CAMPFIRE_TERM = "Tu Hoguera"
L.GUIDE_KINDLING_TERM = "Leña"
L.GUIDE_FLY_BOX = "Cada Aviso que cumples monta una mosca para tu {flybox}."
L.GUIDE_ASK_KICKER = "Solo si quieres uno"
L.GUIDE_ASK_TITLE = "¿Te cuelgo un tablón?"
L.GUIDE_FACTS = {
	"Tres Avisos al día y una Expedición más grande a la semana.",
	"Ninguno caduca. ¿Te vas una temporada? Te esperan hasta seis Avisos y dos Expediciones.",
	"¿No te convence uno? Cada uno se puede cambiar por otro nuevo, una vez al día.",
	"Pagan Monedas Pagle, {shop}",
}
L.GUIDE_FACT_SHOP = "para aspectos de la Tienda de Curiosidades."
L.BOARD_IS_UP = "Tu tablón está colgado"
L.GUIDE_LEAVE = "O déjalo para luego. El tablón espera en Tablón de aparejos, en el menú de Pagle, y en Ajustes."
L.LOOK_TITLE = "el Tablón de aparejos"
L.LOOK_NOTES = {
	{ text = "Las {term} son las grandes, semanales. También esperan, hasta dos.", term = "Expediciones" },
	{ text = "Un Aviso {term}. ¿No te convence? Retíralo, una vez al día, por otro.", term = "nunca caduca" },
	{ text = "Tu {term}: días seguidos con uno cumplido. Un día perdido quema Leña en su lugar.", term = "Hoguera" },
	{ text = "Cada uno cumplido monta una mosca para tu {term}.", term = "Caja de moscas" },
	{ text = "Pagan {term}, que se gastan en aspectos de la Tienda de Curiosidades.", term = "Monedas Pagle" },
}
L.LOOK_AGAIN = "Mostrar otra vez las notas de esta página"
