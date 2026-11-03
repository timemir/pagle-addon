if not GetLocale or GetLocale() ~= "esES" then
	return
end

-- Core's Spanish (Spain) strings, over enUS.lua's on an esES client.
local ns = select(2, ...)
local L = ns.L

local COIN = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
-- EN: |TInterface\\MoneyFrame\\UI-GoldIcon:0|t
local HELP_CHART = "Ayuda a catalogar las aguas"
-- EN: Help chart the waters

L.TRAILER_CAPTION_CATCH = "Cada pieza cuenta una historia"
-- EN: Every catch tells a story
L.TRAILER_CAPTION_JOURNAL = "Una colección que merece la pena"
-- EN: A collection worth keeping
L.TRAILER_CAPTION_VARIETIES = "No hay dos iguales"
-- EN: No two quite alike
L.TRAILER_CAPTION_ANGLER = "Crece con cada captura"
-- EN: Grow with every catch
L.TRAILER_CAPTION_XP = "Tener empeño suma"
-- EN: Every pursuit adds up
L.TRAILER_CAPTION_WAGERS = "Compite en los eventos de la semana"
-- EN: Race the week's events
L.TRAILER_CAPTION_CRESTS = "Domina las aguas"
-- EN: Master your waters
L.TRAILER_CAPTION_COLLECTIONS = "Guarda los más memorables"
-- EN: Keep the memorable ones
L.TRAILER_CAPTION_STATS = "Conoce las aguas"
-- EN: Know your waters
L.TRAILER_CAPTION_HUNTS = "Encuentra tu próxima aventura"
-- EN: Find your next adventure
L.TRAILER_CAPTION_BOARD = "Un motivo para lanzar otra vez"
-- EN: A reason for another cast
L.TRAILER_CAPTION_SHOP = "Hazlo tuyo"
-- EN: Make it yours
L.TRAILER_CAPTION_COZY = "Disfruta de la calma"
-- EN: Enjoy the quiet
L.TRAILER_CAPTION_REPORT = "Comparte lo que descubras"
-- EN: Share what you discover
L.TRAILER_CAPTION_END = "Pagle: cada captura, por escrito."
-- EN: Pagle: Every catch, written down.
L.TRAILER_LENGTH_NOTE = "Longitudes simuladas por Pagle"
-- EN: Lengths simulated by Pagle
L.TRAILER_ARMED =
	"Pagle: tráiler preparado. Empieza a grabar y pesca con tu Tecla de pesca. Esperando un pez con longitud de Pagle."
-- EN: Pagle: trailer armed. Start recording, then fish with your Fishing key. Waiting for a fish with a Pagle length.
L.TRAILER_ACTIVE = "Pagle: el tráiler ya está activo. /pagle trailer stop lo cancela."
-- EN: Pagle: trailer already active. /pagle trailer stop cancels it.
L.TRAILER_STOPPED = "Pagle: tráiler detenido. Tus datos del addon están restaurados."
-- EN: Pagle: trailer stopped. Your addon data is restored.
L.TRAILER_COMPLETE = "Pagle: tráiler completado. Tus datos del addon están restaurados."
-- EN: Pagle: trailer complete. Your addon data is restored.
L.TRAILER_ERROR = "Pagle: tráiler detenido tras un error; tus datos del addon están restaurados."
-- EN: Pagle: trailer stopped after an error; your addon data is restored.
L.TRAILER_COMBAT = "Pagle: tráiler detenido por un combate. Tus datos del addon están restaurados."
-- EN: Pagle: trailer stopped for combat. Your addon data is restored.
L.TRAILER_NEW_CAST = "Pagle: tráiler detenido por un nuevo lance. Tus datos del addon están restaurados."
-- EN: Pagle: trailer stopped for a new cast. Your addon data is restored.
L.TRAILER_STATUS = "Tráiler de Pagle: %s"
-- EN: Pagle trailer: %s
L.TRAILER_USAGE =
	"Pagle: /pagle trailer prepara una grabación; /pagle trailer stop la cancela; /pagle trailer status muestra su estado."
-- EN: Pagle: /pagle trailer arms a recording; /pagle trailer stop cancels; /pagle trailer status shows its state.
L.TRAILER_AFTER_COMBAT = "El tráiler de Pagle empieza tras el combate."
-- EN: The Pagle trailer starts after combat.
L.TRAILER_NEEDS_ANGLER = "El tráiler de Pagle necesita un Pescador conectado."
-- EN: The Pagle trailer needs a logged-in Angler.
L.TRAILER_WAIT_HISTORY = "Espera a que Pagle termine de leer tu Registro de capturas."
-- EN: Wait for Pagle to finish reading your Catch log.
L.TRAILER_WAIT_ANNOUNCEMENTS = "Espera a que terminen los anuncios de Pagle antes de preparar el tráiler."
-- EN: Wait for Pagle's announcements to finish before arming the trailer.
L.TRAILER_ENABLE_MODULE = "Activa Pagle %s antes de grabar el tráiler completo."
-- EN: Enable Pagle %s before recording the full trailer.
L.TRAILER_SUMMARY_LINE = "Un récord personal, nuevos descubrimientos y avances hacia tu próximo Nivel de Pescador."
-- EN: A personal best, new discoveries, and progress towards your next Angler Level.
L.TRAILER_SUMMARY_TITLE = "Una pieza que merece la pena"
-- EN: A catch worth keeping
L.TRAILER_SUMMARY_TEXT = "Tu récord queda en el Diario de peces."
-- EN: Your record lives in the Fish Journal.
L.LOG_FORMAT_CHANGED = "Pagle: el formato del registro de desarrollo cambió; se empezó un registro nuevo."
-- EN: Pagle: dev log format changed; started a new log.
L.LOG_UNREADABLE =
	"Pagle se ha detenido: tu Registro de capturas no se puede leer (%s) y no se ha cambiado nada. Antes de cerrar sesión o recargar, copia Pagle.lua y Pagle.lua.bak de WTF/Account/<cuenta>/SavedVariables a un lugar seguro y avísanos en github.com/timemir/pagle-addon/issues."
-- EN: Pagle stopped: your Catch log can't be read (%s), and nothing has been changed. Before you log out or reload, copy Pagle.lua and Pagle.lua.bak from WTF/Account/<account>/SavedVariables somewhere safe, then report it at github.com/timemir/pagle-addon/issues.
L.LOG_UNREADABLE_PAUSED =
	"Pagle está detenido: tu Registro de capturas no se puede leer y no se ha cambiado nada. La línea del inicio de sesión dice qué hacer."
-- EN: Pagle is stopped: your Catch log can't be read, and nothing has been changed. The line at login says what to do.
L.NOT_FOREVER = "Pagle: esto no es World of Warcraft: Forever, así que Pagle se queda desactivado."
-- EN: Pagle: this isn't World of Warcraft: Forever, so Pagle stays off.
L.SIZE_BANDS = { "Pececillo", "Decente", "Robusto", "Descomunal", "Monstruo" }
-- EN: { "Tiddler", "Decent", "Hefty", "Whopper", "Monster" }
L.VARIETY_RARITIES = { "Común", "Poco común", "Raro", "Épico" }
-- EN: { "Common", "Uncommon", "Rare", "Epic" }
L.LENGTH = { cm = "%.1f cm", ["in"] = "%.1f pulg." }
-- EN: { cm = "%.1f cm", ["in"] = "%.1f in" }
L.LENGTH_MARGIN_UNDER = { cm = "+<0.1 cm", ["in"] = "+<0.1 pulg." }
-- EN: { cm = "+<0.1 cm", ["in"] = "+<0.1 in" }
L.EVENT_REGISTER_FAILED = "Pagle: %s no pudo registrar el evento %s: %s"
-- EN: Pagle: %s couldn't register the event %s: %s
L.EVENT_HANDLER_FAILED = "Pagle: el controlador de %s para el evento %s falló: %s"
-- EN: Pagle: %s's handler for the event %s failed: %s
L.MODULE_NEEDS_NEWER_PAGLE = "Pagle: Pagle %s necesita un Pagle más reciente."
-- EN: Pagle: Pagle %s needs a newer Pagle.

L.SETTING_TOO_LATE = "Pagle: el AddSetting de %s llegó después de ModulesChanged, así que la fila se descarta"
-- EN: Pagle: %s's AddSetting came after ModulesChanged, so the row is dropped

L.SETTINGS_PAGES = {
	fishing = "Pesca",
	announcements = "Anuncios",
	trackers = "Rastreadores",
	look = "Apariencia",
}
-- EN: { announcements = "Announcements", fishing = "Fishing", look = "Look and Feel", trackers = "Trackers" }
L.SETTINGS_TRACKER_POSITION = "Posición de los rastreadores"
-- EN: Tracker position
L.SETTINGS_TRACKER_RESET = "Restablecer"
-- EN: Reset
L.SETTINGS_TRACKER_RESET_TOOLTIP =
	"Arrastra con Mayús cualquier rastreador de Pagle para moverlos todos. Esto los devuelve bajo el minimapa."
-- EN: Shift-drag any Pagle tracker to move them all. This puts them back under the minimap.
L.SETTINGS_TOAST_POSITION = "Posición de los avisos emergentes"
-- EN: Toast position
L.SETTINGS_TOAST_RESET = "Restablecer"
-- EN: Reset
L.SETTINGS_TOAST_RESET_TOOLTIP =
	"Arrastra con Mayús un aviso emergente para mover los avisos emergentes y los Gestos. Esto los devuelve a la parte inferior de la pantalla."
-- EN: Shift-drag a toast to move the toasts and Nods. This puts them back at the bottom of the screen.
L.SETTINGS_NO_MODULE = "Registrando tus Capturas. Activa un Módulo para verlas."
-- EN: Recording your Catches. Enable a Module to see them.
L.SETTINGS_MODULES = "Módulos"
-- EN: Modules
L.SETTINGS_MODULES_NOTE = "Activa o desactiva Módulos en la lista de accesorios."
-- EN: Turn Modules on or off in the AddOns list.
L.SETTINGS_GETTING_STARTED = "Primeros pasos"
-- EN: Getting started
L.SETTINGS_FIELD_GUIDE = "Guía de campo"
-- EN: Field guide
L.SETTINGS_FIELD_GUIDE_LINE = "Las ocho páginas que viste el primer día."
-- EN: The eight pages you saw on your first day.
L.SETTINGS_SHOW_ME_AROUND = "Enséñamelo todo otra vez"
-- EN: Show me around again
L.SETTINGS_MARGIN_NOTES = "Notas al margen"
-- EN: Margin notes
L.SETTINGS_MARGIN_NOTES_TOOLTIP = "Explica las cosas la primera vez que pasan."
-- EN: Explain things the first time they happen.
L.SETTINGS_SHOW_NOTES_AGAIN = "Mostrarlas otra vez"
-- EN: Show them again
L.SETTINGS_EVENING = "Lista de la Primera tarde"
-- EN: First evening list
L.SETTINGS_EVENING_LINE = "%d de %d hechas"
-- EN: %d of %d done
L.SETTINGS_SAVING = "Guardado"
-- EN: Saving
L.SETTINGS_RELOAD_REMINDER = "Recuérdame hacer /reload cuando haya Lances sin guardar"
-- EN: Remind me to /reload when Casts are unsaved
L.SETTINGS_RELOAD_REMINDER_TOOLTIP =
	"Una línea en el chat cada %d Lances sin guardar. WoW solo guarda al hacer /reload o cerrar sesión, así que un cierre inesperado los pierde."
-- EN: A chat line every %d Casts not yet saved. WoW saves only on /reload or logout, so a crash loses them.
L.SETTINGS_UNITS = "Unidades"
-- EN: Units
L.SETTINGS_LENGTH_UNIT = "Unidad de longitud"
-- EN: Length unit
L.SETTINGS_LENGTH_UNIT_TOOLTIP =
	"Cómo muestra Pagle la longitud de tus Capturas. Los registros se guardan en milímetros, así que cambiarla solo cambia lo que ves."
-- EN: How Pagle shows the length of your Catches. Records are kept in millimetres, so switching changes only what you see.
L.SETTINGS_LENGTH_UNITS = { cm = "Centímetros", ["in"] = "Pulgadas" }
-- EN: { cm = "Centimetres", ["in"] = "Inches" }
L.SETTINGS_CLOCK = "Reloj"
-- EN: Clock
L.SETTINGS_CLOCK_TOOLTIP =
	"Cómo escribe Pagle una hora del día, como la hora del reino arriba del tablón de Cazas. Seguir el juego usa el modo de 24 horas del reloj del minimapa."
-- EN: How Pagle writes a time of day, such as the realm time at the top of the Hunts board. Following the game uses the minimap clock's 24-hour mode.
L.SETTINGS_CLOCK_CHOICES = {
	game = "Seguir el reloj del juego",
	["24h"] = "24 horas (18:30)",
	["12h"] = "12 horas (6:30 PM)",
}
-- EN: { ["12h"] = "12-hour (6:30 PM)", ["24h"] = "24-hour (18:30)", game = "Follow the game's clock" }
L.SETTINGS_PAGLE_MENU = "Menú de Pagle"
-- EN: Pagle menu
L.SETTINGS_MINIMAP_ICON = "Mostrar el icono del minimapa"
-- EN: Show the minimap icon
L.SETTINGS_MINIMAP_ICON_TOOLTIP =
	"Un botón redondo de Pagle en el borde del minimapa que abre el menú de Pagle. El menú también está en el botón de accesorios junto al minimapa."
-- EN: A round Pagle button on the minimap's edge that opens the Pagle menu. The menu is also in the AddOns button by the minimap.
L.SETTINGS_PAGLE_WEBSITE = "Web de Pagle"
-- EN: Pagle website
L.SETTINGS_ANGLER_TOOLTIPS = "Mostrar otros Pescadores en el tooltip de los jugadores"
-- EN: Show other Anglers on player tooltips
L.SETTINGS_ANGLER_TOOLTIPS_TOOLTIP =
	"Añade un bloque de Pagle al tooltip de los jugadores cuyo Pescador está en la web de Pagle. Necesita Pagle Companion."
-- EN: Adds a Pagle block to the tooltip of players whose Angler is on the Pagle website. Needs the Pagle Companion.
L.SETTINGS_COZY = "Modo acogedor"
-- EN: Cozy mode
L.SETTINGS_COZY_TOOLTIP =
	"No salta ni suena nada. Cada momento espera en el Resumen de sesión. El Destello de una Leyenda sigue apareciendo, en silencio."
-- EN: Nothing pops up or plays. Every moment waits in the Session summary. A Legend's splash still shows, silently.
L.SETTINGS_BUDGET = "Presupuesto de interrupciones"
-- EN: Interruption budget
L.SETTINGS_BUDGET_TOOLTIP =
	"Cuando los avisos emergentes llegan muy seguidos, los pequeños se quedan en un Gesto discreto. Los récords siempre conservan su regla. En gris en el Modo acogedor, que ya lo retiene todo."
-- EN: When toasts come close together, the smaller ones step down to a quiet Nod. Records always keep their ruler. Greyed out in Cozy mode, which holds everything anyway.
L.SETTINGS_BUDGET_COUNT = "Interrupciones"
-- EN: Interruptions
L.SETTINGS_BUDGET_WINDOW = "Cada"
-- EN: Per
L.SETTINGS_EVERY_CATCH = "Mostrar cada captura"
-- EN: Show every catch
L.SETTINGS_MOTION = "Animaciones"
-- EN: Animations
L.SETTINGS_MOTION_TOOLTIP =
	"Los avisos emergentes entran deslizándose y se estampan, los estandartes dejan caer su sello y giran los rayos tras un estandarte o una Leyenda. Desactivadas, cada uno aparece ya asentado."
-- EN: Toasts slide in and stamp themselves, banners drop their seal, and the rays behind a banner or a Legend turn. Off, each appears as it settles.
L.SETTINGS_EVERY_CATCH_TOOLTIP =
	"Un aviso emergente por cada captura: su nombre, talla y longitud. Si la misma pieza trae un momento mayor, se muestra ese, y pasado tu presupuesto de interrupciones se queda en una línea discreta. En gris en el Modo acogedor, que no muestra nada."
-- EN: A toast for each catch: its name, size band and length. A bigger moment for the same catch shows instead, and past your interruption budget it steps down to a quiet line. Greyed out in Cozy mode, which shows nothing.
L.SETTINGS_LOOK_PARAGRAPH =
	"Aspectos que tienes. Elige uno aquí, en la Colección del Diario de peces o con Usar en la Tienda de Curiosidades; todos cambian lo mismo."
-- EN: Looks you own. Pick one here, in the Fish Journal's Collection or with Use in the Curio Shop; all of them change the same thing.
L.SETTINGS_SLOT_MORE = "%d más en la Tienda de Curiosidades"
-- EN: %d more in the Curio Shop
L.SETTINGS_MORE_LOOKS = "Más aspectos"
-- EN: More looks
L.SETTINGS_COLLECTION_ROW = "Cada aspecto y cómo conseguirlo"
-- EN: Every look, and how to earn it
L.SETTINGS_COLLECTION_BUTTON = "Abrir la Colección"
-- EN: Open the Collection
L.SETTINGS_SHOP_ROW = "Compra más aspectos con Monedas Pagle"
-- EN: Buy more looks with Pagle Coins
L.SETTINGS_SHOP_BUTTON = "Abrir la Tienda de Curiosidades"
-- EN: Open the Curio Shop
L.ANNOUNCEMENT_MORE = "+%d más"
-- EN: +%d more
L.ANNOUNCEMENT_STAMP_REFRESH = "Renovación +%d"
-- EN: Refresh +%d
L.ANNOUNCEMENT_NEW_RECORD = "Nuevo récord"
-- EN: New record
L.ANNOUNCEMENT_SPLASH_HINT = "Haz clic en cualquier sitio para continuar"
-- EN: Click anywhere to continue
L.ANNOUNCEMENT_SPLASH_RELOAD = "/reload para ponerla a salvo"
-- EN: /reload to keep it safe
L.LEGEND_CREST_LEGEND = "Leyenda"
-- EN: Legend
L.LEGEND_CREST_UNWRITTEN = "Por escribir"
-- EN: Unwritten
L.ANNOUNCEMENT_WHILE_FIGHTING = "Mientras combatías"
-- EN: While you were fighting
L.CATCH_TOAST_CAUGHT = "Capturada"
-- EN: Caught
L.CATCH_TOAST_ITEM = "Objeto %d"
-- EN: Item %d
L.CARD_SESSION = "Sesión de pesca"
-- EN: Fishing session
L.CARD_LAST_SESSION = "Tu última sesión"
-- EN: Your last session
L.CARD_WRITE_UP = "Reseña"
-- EN: Write-up
L.CARD_CASTS = "Lances"
-- EN: Casts
L.CARD_CATCHES = "Capturas"
-- EN: Catches
L.CARD_GOT_AWAY = "Escapados"
-- EN: Got away
L.CARD_TIME = "Tiempo pescando"
-- EN: Time fished
L.CARD_COINS = "Monedas Pagle +%s " .. COIN
-- EN: Pagle Coins +%s |TInterface\\MoneyFrame\\UI-GoldIcon:0|t
L.CARD_CLOSE = "Cerrar"
-- EN: Close
L.TOAST_SAMPLE_TITLE = "Nueva Especie"
-- EN: New Species
L.TOAST_SAMPLE_TEXT = "Un aviso emergente de muestra"
-- EN: A sample toast
L.TOAST_SAMPLE_STAMP = "Nuevo aquí"
-- EN: New here
L.TOAST_SHOW_ON_SCREEN = "Mostrar en pantalla"
-- EN: Show on screen
L.RELOAD_REMINDER = "Pagle: %d Lances sin guardar. Haz /reload para ponerlos a salvo."
-- EN: Pagle: %d Casts not yet saved. /reload to keep them safe.
L.SETTINGS_AFTER_COMBAT = "Pagle: los ajustes se abren tras el combate."
-- EN: Pagle: settings open after combat.
L.SETTINGS_KEY_NOT_BOUND = "Sin asignar"
-- EN: Not Bound
L.SETTINGS_KEY_WAITING = "Pulsa una tecla"
-- EN: Press a key
L.GUIDE_BIND_CLICK = "clic para asignar"
-- EN: click to bind
L.GUIDE_BIND_DEFAULT = "por defecto: no hay nada asignado"
-- EN: default: nothing is bound
L.GUIDE_BIND_LISTEN = "pulsa una tecla…"
-- EN: press a key…
L.GUIDE_BIND_ESC = "Esc la deja como estaba"
-- EN: Esc leaves it as it was
L.GUIDE_BIND_BOUND = "Asignada"
-- EN: Bound
L.GUIDE_BIND_PICK = "Elige otra tecla"
-- EN: Pick another key
L.GUIDE_BIND_KEPT = "el uso anterior queda anotado, nunca se pierde sin avisar"
-- EN: the old use is listed, never silently lost
L.GUIDE_BIND_ASK = {
	PAGLE_FISHING_KEY = "ya hace %s. ¿Usarla para pescar?",
	PAGLE_SWAP_GEAR = "ya hace %s. ¿Usarla para cambiar de equipo?",
}
-- EN: { PAGLE_FISHING_KEY = "already does %s. Use it for fishing instead?", PAGLE_SWAP_GEAR = "already does %s. Use it to swap gear instead?" }
L.GUIDE_BIND_USE = {
	PAGLE_FISHING_KEY = "Usar %s para pescar",
	PAGLE_SWAP_GEAR = "Usar %s para cambiar de equipo",
}
-- EN: { PAGLE_FISHING_KEY = "Use %s for fishing", PAGLE_SWAP_GEAR = "Use %s to swap gear" }
L.GUIDE_BIND_TOLD = {
	PAGLE_FISHING_KEY = "Pagle: %s ahora lanza. Antes hacía %s; reasígnalo en Asignación de teclas si lo necesitas.",
	PAGLE_SWAP_GEAR = "Pagle: %s ahora cambia tu equipo. Antes hacía %s; reasígnalo en Asignación de teclas si lo necesitas.",
}
-- EN: { PAGLE_FISHING_KEY = "Pagle: %s now casts. It used to do %s; rebind that in Key Bindings if you need it.", PAGLE_SWAP_GEAR = "Pagle: %s now swaps your gear. It used to do %s; rebind that in Key Bindings if you need it." }
L.MODULE_NAMES = {
	Ledger = "Libro de registro",
	Hunts = "Cazas",
	Stats = "Estadísticas",
	TackleBoard = "Tablón de aparejos",
	QoL = "Comodidades",
}
-- EN: { Hunts = "Hunts", Ledger = "Ledger", QoL = "QoL", Stats = "Stats", TackleBoard = "Tackle Board" }
L.MODULE_STATES = {
	on = "Activado",
	needsNewerPagle = "Necesita un Pagle más reciente",
	failedToStart = "No pudo iniciarse",
	off = "Desactivado",
	notInstalled = "No instalado",
}
-- EN: { failedToStart = "Failed to start", needsNewerPagle = "Needs a newer Pagle", notInstalled = "Not installed", off = "Off", on = "On" }
L.OPEN_VIEW = "Abrir %s"
-- EN: Open %s

L.MENU_SETTINGS = "Ajustes"
-- EN: Settings
L.MENU_CURIO_SHOP = "Tienda de Curiosidades  %s " .. COIN
-- EN: Curio Shop  %s |TInterface\\MoneyFrame\\UI-GoldIcon:0|t
L.HELP_CHART = HELP_CHART
-- EN: Help chart the waters
L.HELP_CHART_COUNT = HELP_CHART .. " (%d)"
-- EN: Help chart the waters (%d)

L.FIELD_REPORT_PRIVACY = "Esto se publicará a la vista de todos. No contiene nombres de personajes."
-- EN: This will be posted publicly. It contains no character names.
L.FIELD_REPORT_COPY_HINT = "Ctrl+C para copiar"
-- EN: Ctrl+C to copy
L.FIELD_REPORT_POST_AT = "PUBLÍCALO EN"
-- EN: POST IT AT
L.FIELD_REPORT_PART = "Parte %d de %d"
-- EN: Part %d of %d
L.FIELD_REPORT_CLOSE = "Cerrar"
-- EN: Close
L.FIELD_REPORT_NOTHING = "Nada que informar. ¡Gracias por comprobarlo!"
-- EN: Nothing to report. Thanks for checking!
L.FIELD_REPORT_UPDATING = "Actualizando... inténtalo de nuevo en un momento."
-- EN: Updating... try again in a moment.
L.FIELD_REPORT_AFTER_COMBAT = "Pagle: el Informe de campo se abre tras el combate."
-- EN: Pagle: the Field report opens after combat.
L.SETTINGS_FIELD_REPORT_ROW = "Informe de campo"
-- EN: Field report
L.SETTINGS_FIELD_REPORT_BUTTON = "Abrir el Informe de campo"
-- EN: Open Field report
L.SETTINGS_FIELD_REPORT_BUTTON_COUNT = "Abrir el Informe de campo (%d)"
-- EN: Open Field report (%d)
L.SETTINGS_FIELD_REPORT_TOOLTIP =
	"Copia lo que has sacado y los datos de Pagle aún no conocen, y pégalo en el formulario de incidencias."
-- EN: Copy what you've caught that Pagle's data doesn't know yet, and paste it into the issue form.
L.PASTE_TITLE = "Exportar para la web"
-- EN: Export for the website
L.PASTE_PRIVACY = "Contiene los nombres de tus personajes. Pégalo solo en la web de Pagle."
-- EN: Holds your characters' names. Paste it only on the Pagle website.
L.PASTE_COPY_HINT = "Ctrl+C para copiar"
-- EN: Ctrl+C to copy
L.PASTE_CHOICE_NEW = "Lo nuevo desde la última exportación"
-- EN: New since last export
L.PASTE_CHOICE_EVERYTHING = "Todo"
-- EN: Everything
L.PASTE_ENTRIES = "Entradas %s–%s de %s"
-- EN: Entries %s–%s of %s
L.PASTE_NO_ENTRIES = "Sin entradas"
-- EN: No entries
L.PASTE_IN_ORDER = "Pega cada parte por separado, en orden."
-- EN: Paste each part on its own, in order.
L.PASTE_AT = "PÉGALO EN"
-- EN: PASTE IT AT
L.PASTE_PART = "Parte %d de %d"
-- EN: Part %d of %d
L.PASTE_CLOSE = "Cerrar"
-- EN: Close
L.PASTE_NOTHING_NEW = "Nada nuevo desde tu última exportación."
-- EN: Nothing new since your last export.
L.PASTE_CANT_EXPORT = "Pagle no puede exportar este Registro de capturas."
-- EN: Pagle can't export this Catch log.
L.PASTE_PREPARING = "Preparando tu Cadena de pegado…"
-- EN: Preparing your Paste string…
L.PASTE_AFTER_COMBAT = "Pagle: la ventana de exportación se abre tras el combate."
-- EN: Pagle: the export window opens after combat.
L.PASTE_TEST_LINE = "Prueba de copia: %d KB"
-- EN: Copy test: %d KB
L.SETTINGS_PASTE_ROW = "Registro de capturas"
-- EN: Catch log
L.SETTINGS_PASTE_BUTTON = "Copiar para la web"
-- EN: Copy for the website
L.SETTINGS_PASTE_TOOLTIP =
	"Copia tu Registro de capturas como Cadena de pegado, para pegarlo en la web de Pagle sin el Companion."
-- EN: Copy your Catch log as a Paste string, to paste on the Pagle website without the Companion.
L.SHOP_AFTER_COMBAT = "Pagle: la Tienda de Curiosidades se abre tras el combate."
-- EN: Pagle: the Curio Shop opens after combat.
L.SHOP_COINS = "Monedas Pagle"
-- EN: Pagle Coins
L.SHOP_ALL_TIME = "%s Monedas en total"
-- EN: %s Coins all time
L.SHOP_OFF_NOTE = "Desactivado: no paga nada nuevo, conserva lo que pagó."
-- EN: Off: pays nothing new, keeps what it paid.
L.SHOP_SEARCH = "Busca un aspecto…"
-- EN: Find a look…
L.SHOP_FILTERS = { all = "Todos", owned = "Tuyos", notOwned = "Por conseguir", canAfford = "Asequibles" }
-- EN: { all = "All", canAfford = "Can afford", notOwned = "Not owned", owned = "Owned" }
L.SHOP_ALL_CATEGORIES = "Todos"
-- EN: All
L.SHOP_CATEGORIES = {
	Announcements = "Anuncios",
	Crests = "Blasones",
	Books = "Libros",
	Trackers = "Rastreadores",
}
-- EN: { Announcements = "Announcements", Books = "Books", Crests = "Crests", Trackers = "Trackers" }
L.SHOP_OWNED_COUNT = "%d de %d"
-- EN: %d of %d
L.SHOP_PUT_AWAY = "Guardados: Módulo desactivado"
-- EN: Put away: Module off
L.SHOP_KEEP = "Tuyo para siempre"
-- EN: Yours to keep
L.SHOP_NO_MATCH = "Ningún aspecto coincide."
-- EN: No looks match.
L.SHOP_OWNED = "Tuyo"
-- EN: Owned
L.SHOP_IN_USE = "En uso"
-- EN: In use
L.SHOP_DEFAULT = "por defecto"
-- EN: default
L.SHOP_BUY = "Comprar por %s"
-- EN: Buy for %s
L.SHOP_MORE_NEEDED = "Faltan %s Monedas"
-- EN: %s more Coins
L.SHOP_OR_BUY = "O cómpralo por %s"
-- EN: Or buy it for %s
L.SHOP_MODULE_OFF = "%s está desactivado"
-- EN: %s is off
L.SHOP_PICK = "Elige un aspecto para verlo aquí."
-- EN: Pick a look to see it here.
L.SHOP_USE = "Usar"
-- EN: Use
-- The shop's short name: the full one, spaced out, overflows the bill's head.
L.SHOP_BILL_HEAD = "C U R I O S I D A D E S"
-- EN: C U R I O   S H O P
L.SHOP_BUY_CONFIRM = "¿Comprar %s?"
-- EN: Buy %s?
L.SHOP_PRICE_LINE = "Precio"
-- EN: Price
L.SHOP_LEFT_AFTER = "Monedas Pagle restantes"
-- EN: Pagle Coins left after
L.SHOP_FOR_GOOD = "Los aspectos son tuyos para siempre."
-- EN: Looks are yours for good.
L.SHOP_USE_NOW = "Usarlo ya"
-- EN: Use it now
L.SHOP_BUY_ACCEPT = "Comprar"
-- EN: Buy
L.SHOP_BUY_CANCEL = "Cancelar"
-- EN: Cancel
L.SHOP_HELD = "Tu saldo es 0 mientras Pagle vuelve a contar Monedas anteriores. Las Monedas nuevas cubren eso primero."
-- EN: Your balance is 0 while Pagle re-counts earlier Coins. New Coins fill that in first.
L.SHOP_CRATE = "Cofre de curiosidades"
-- EN: Curio crate
L.SHOP_CRATE_KIND = "Un cofre de aspectos"
-- EN: A crate of looks
L.SHOP_CRATE_TIERS = { "Sencillo", "Fino", "Vivaz", "Vistoso", "Maravilla", "Reliquia", curio = "Curiosidad" }
-- EN: { "Plain", "Fine", "Lively", "Showpiece", "Marvel", "Heirloom", curio = "Curio" }
L.SHOP_CRATE_LEFT = "quedan %d"
-- EN: %d left
L.SHOP_CRATE_PAYS_BACK = "reembolsa %s"
-- EN: pays back %s
L.SHOP_CRATE_PITY = "Una Curiosidad en %d cofres como mucho"
-- EN: A Curio within %d more crates
L.SHOP_CRATE_PITY_ONE = "Una Curiosidad en el próximo cofre"
-- EN: A Curio in the next crate
L.SHOP_CRATE_CONFIRM = "¿Abrir un Cofre de curiosidades?"
-- EN: Open a Curio crate?
L.SHOP_CRATE_FINE = "Un aspecto que aún no tienes, al azar; las probabilidades están en el cofre."
-- EN: One look you don't own yet, by chance; the chances are on the crate.
L.SHOP_CRATE_PAYBACK = "+%s Monedas"
-- EN: +%s Coins
L.SHOP_CRATE_BACK = "Volver a la tienda"
-- EN: Back to the shop
L.SHOP_CRATE_NEW_LOOK = "Un aspecto nuevo"
-- EN: A new look
L.SHOP_CRATE_UNSHOWN = "Se mostrará aquí cuando su Módulo esté activado."
-- EN: It shows here once its Module is on.
L.SHOP_CRATE_KINDS = {
	toaststyle = "Estilo de aviso emergente",
	soundset = "Juego de sonidos",
	binding = "Encuadernación",
	trackerframe = "Marco de rastreador",
	crest = "Blasón",
}
-- EN: { binding = "Binding", crest = "Crest", soundset = "Sound set", toaststyle = "Toast style", trackerframe = "Tracker frame" }
L.SHOP_CRATE_YOURS = "Tuyo"
-- EN: Yours
L.SHOP_CRATE_PAID_BACK = "Reembolsado"
-- EN: Paid back
L.SHOP_CRATE_ONLY_NOTE = "Solo en un Cofre de curiosidades, nunca a la venta"
-- EN: Only in a Curio crate, never for sale
L.SHOP_FROM_CRATE = "De un cofre"
-- EN: From a crate
L.SHOP_SONAR_EARNED = "Vincula el Companion"
-- EN: Link the companion

L.COMPARTMENT_WAITING = "Pagle · %d en espera"
-- EN: Pagle · %d waiting
L.MENU_TOOLTIP_WAITING = "%d en espera"
-- EN: %d waiting
L.MENU_TOOLTIP_LETTER = "Una carta para ti"
-- EN: A letter for you

L.SLASH_HELP_HEADER = "Comandos de Pagle:"
-- EN: Pagle commands:
L.SLASH_SKIPPED_NO_NAME = "Pagle: %s tiene una entrada de /pagle, %s, sin nombre de una palabra; se omite"
-- EN: Pagle: %s's /pagle entry %s has no one-word name; it is skipped
L.SLASH_SKIPPED_NO_FN = "Pagle: %s define /pagle %s sin fn; se omite"
-- EN: Pagle: %s's /pagle %s has no fn; it is skipped
L.SLASH_SKIPPED_RESERVED = "Pagle: %s define /pagle %s, que se omite: Pagle reserva %s"
-- EN: Pagle: %s's /pagle %s is skipped: Pagle reserves %s
L.SLASH_SKIPPED_TAKEN = "Pagle: %s define /pagle %s, que se omite: %s ya lo usa"
-- EN: Pagle: %s's /pagle %s is skipped: %s already uses it
L.DEV_ON = "Pagle dev: los comandos de desarrollo están activados."
-- EN: Pagle dev: dev commands are on.
L.DEV_OFF = "Pagle dev: los comandos de desarrollo están desactivados."
-- EN: Pagle dev: dev commands are off.
L.DEV_IS_OFF = "Pagle dev: los comandos de desarrollo están desactivados; /pagle dev on los activa."
-- EN: Pagle dev: dev commands are off; /pagle dev on turns them on.
L.DEV_USAGE = "Pagle dev: /pagle dev on | off | endsession | preview <tipo> | stage <número> | glyphs"
	.. " | tour [module | list | stop] | probe | onboarding <comando> | content | views | pastetest <KB>"
-- EN: Pagle dev: /pagle dev on | off | endsession | preview <kind> | stage <count> | glyphs | tour [module | list | stop] | probe | onboarding <command> | content | views | pastetest <KB>
L.DEV_PASTE_TEST_USAGE = "Pagle dev: /pagle dev pastetest <KB>, de %d a %d; la comprobación copia 64, 128, 256 y 512."
-- EN: Pagle dev: /pagle dev pastetest <KB>, from %d to %d; the check copies 64, 128, 256 and 512.
L.DEV_PASTE_TEST_SHOWN =
	"Pagle dev: hay una cadena de prueba de %d KB en la ventana de exportación; cópiala y comprueba su longitud."
-- EN: Pagle dev: a %d KB test string is in the export window; copy it and check its length.
L.DEV_CONTENT_STATE = "Pagle dev: el contenido enviado está %s."
-- EN: Pagle dev: pushed content is %s.
L.DEV_CONTENT_ABSENT = "Pagle dev: falta el contenido enviado: %s."
-- EN: Pagle dev: pushed content is missing: %s.
L.DEV_CONTENT_KINDS = "Pagle dev: tipos entregados: %s."
-- EN: Pagle dev: kinds handed out: %s.
L.DEV_CONTENT_DROPPED = "Pagle dev: tipos descartados por desconocidos: %s."
-- EN: Pagle dev: kinds dropped as unknown: %s.
L.DEV_CONTENT_NONE = "ninguno"
-- EN: none
L.DEV_CONTENT_FRAMES =
	"Pagle dev: fotogramas en que corrió la comprobación: %d, el más largo %.2f ms (presupuesto %d ms)."
-- EN: Pagle dev: frames the check ran in: %d, the longest %.2f ms (budget %d ms).
L.PUSHED_NOT_INSTALLED = "sin archivo (Pagle_Content no está instalado)"
-- EN: no file (Pagle_Content isn't installed)
L.PUSHED_NOT_LOADED = "sin archivo (Pagle_Content no se cargó: %s)"
-- EN: no file (Pagle_Content didn't load: %s)
L.PUSHED_NO_DATA = "sin archivo (Pagle_Content se cargó pero no definió PagleContentData)"
-- EN: no file (Pagle_Content loaded but set no PagleContentData)
L.PUSHED_NOT_TABLE = "PagleContentData no es una tabla"
-- EN: PagleContentData isn't a table
L.PUSHED_MISSING_FIELD = "falta un campo, %s"
-- EN: a missing field, %s
L.PUSHED_NOT_INTEGER = "%s no es un número entero"
-- EN: %s isn't a whole number
L.PUSHED_NOT_STRING = "%s no es una cadena"
-- EN: %s isn't a string
L.PUSHED_BAD_KEY_ID = "un keyId que no es de 1 a 32 caracteres de A-Z, a-z, 0-9, _ y -"
-- EN: a keyId that isn't 1 to 32 of A-Z, a-z, 0-9, _ and -
L.PUSHED_UNKNOWN_VERSION = "un formato de archivo desconocido, v %s"
-- EN: an unknown file format, v %s
L.PUSHED_UNKNOWN_KEY = "un keyId desconocido, %s"
-- EN: an unknown keyId, %s
L.PUSHED_NOT_BASE64 = "%s no es Base64 (%s)"
-- EN: %s isn't Base64 (%s)
L.PUSHED_OVER_CAP = "por encima del límite de tamaño, %d bytes decodificados de %d como máximo"
-- EN: over the size cap, %d bytes decoded of %d at most
L.PUSHED_BAD_SIGNATURE = "una firma no válida (%s)"
-- EN: a bad signature (%s)
L.PUSHED_LOWER_SEQ = "un seq menor, %s, por debajo del último aceptado, %s"
-- EN: a lower seq, %s, below the last accepted %s
L.PUSHED_EXPIRED = "caducado en %s, y la hora del servidor es %s"
-- EN: expired at %s, and the server time is %s
L.PUSHED_PARSE_ERROR = "un error de análisis en el byte %d: %s"
-- EN: a parse error at byte %d: %s
L.PUSHED_CHECK_FAILED = "la propia comprobación falló (mira el error de Lua)"
-- EN: the check itself failed (see the Lua error)
L.PAYLOAD_EXPECTED = "se esperaba %s"
-- EN: expected %s
L.PAYLOAD_EXPECTED_FIELD = "se esperaba un nombre de campo"
-- EN: expected a field name
L.PAYLOAD_EXPECTED_ITEM = "se esperaba un elemento, una tabla"
-- EN: expected an item, a table
L.PAYLOAD_BAD_ITEM = 'un elemento que no empieza por kind = "…", v = <entero>'
-- EN: an item that doesn't start kind = \"…\", v = <integer>
L.PAYLOAD_BAD_NAME = "un nombre de campo que no es un nombre"
-- EN: a field name that isn't a name
L.PAYLOAD_UNEXPECTED = "un carácter inesperado, %s"
-- EN: an unexpected character, %s
L.PAYLOAD_NAME_AS_VALUE = "un nombre, %s, donde va un valor"
-- EN: a name, %s, where a value goes
L.PAYLOAD_NOT_INTEGER = "un número que no es un entero decimal"
-- EN: a number that isn't a decimal integer
L.PAYLOAD_TOO_LARGE = "un entero de más de %s dígitos"
-- EN: an integer of more than %s digits
L.PAYLOAD_UNENDED_STRING = "una cadena que no termina"
-- EN: a string that doesn't end
L.PAYLOAD_LINE_IN_STRING = "un salto de línea dentro de una cadena"
-- EN: a line end inside a string
L.PAYLOAD_BAD_ESCAPE = 'un escape distinto de \\\\, \\" o \\n'
-- EN: an escape other than \\\\, \\\" or \\n
L.PAYLOAD_DUPLICATE = "un campo repetido, %s"
-- EN: a field given twice, %s
L.PAYLOAD_MIXED = "un campo en una lista de valores"
-- EN: a field in a list of values
L.PAYLOAD_TOO_DEEP = "tablas anidadas a más de %s niveles"
-- EN: tables nested more than %s deep
L.PAYLOAD_ENDED = "la carga termina antes de tiempo"
-- EN: the payload ends too soon
L.PAYLOAD_AFTER_TABLE = "algo más tras la tabla de la carga"
-- EN: more after the payload's table
L.DEV_VIEWS_LIVE = "Pagle dev: %s está activo."
-- EN: Pagle dev: %s is live.
L.DEV_VIEWS_ABSENT = "Pagle dev: %s no está: %s."
-- EN: Pagle dev: %s is absent: %s.
L.DEV_VIEWS_EXPIRED = "Pagle dev: %s ha caducado: se generó hace %s s, la edad de caducidad es %s s."
-- EN: Pagle dev: %s is expired: generated %s s ago, the expiry age is %s s.
L.DEV_VIEWS_FOLLOWING = "Pagle dev: generatedAt de Pagle_Following %s, Pescadores %s."
-- EN: Pagle dev: Pagle_Following's generatedAt %s, Anglers %s.
L.DEV_VIEWS_ANGLERS = "Pagle dev: generatedAt de Pagle_Anglers %s, bloques %s."
-- EN: Pagle dev: Pagle_Anglers' generatedAt %s, blocks %s.
L.DEV_VIEWS_LOADED = "Pagle dev: Pagle_Anglers se ha cargado en esta sesión."
-- EN: Pagle dev: Pagle_Anglers has loaded this login.
L.DEV_VIEWS_NOT_LOADED = "Pagle dev: Pagle_Anglers no se ha cargado en esta sesión."
-- EN: Pagle dev: Pagle_Anglers hasn't loaded this login.
L.DEV_VIEWS_NONE = "ninguno"
-- EN: none
L.VIEWS_NOT_READ = "aún sin leer (Pagle lo lee al iniciar sesión)"
-- EN: not read yet (Pagle reads it at login)
L.VIEWS_NOT_LOADED_YET = "aún sin cargar (se carga con el primer tooltip de jugador mientras Pagle no está restringido, con el"
	.. " ajuste del tooltip activado)"
-- EN: not loaded yet (it loads at the first player tooltip while Pagle isn't restricted, with the tooltip setting on)
L.VIEWS_NOT_INSTALLED = "sin archivo (%s no está instalado)"
-- EN: no file (%s isn't installed)
L.VIEWS_DID_NOT_LOAD = "sin archivo (%s no se cargó: %s)"
-- EN: no file (%s didn't load: %s)
L.VIEWS_NO_DATA = "sin archivo (%s se cargó pero no definió %s)"
-- EN: no file (%s loaded but set no %s)
L.VIEWS_NOT_TABLE = "%s no es una tabla"
-- EN: %s isn't a table
L.VIEWS_NOT_OK = "ok no es true"
-- EN: ok isn't true
L.VIEWS_UNKNOWN_VERSION = "un formato de archivo desconocido, v %s"
-- EN: an unknown file format, v %s
L.VIEWS_NOT_NUMBER = "%s no es un número"
-- EN: %s isn't a number
L.VIEWS_WRONG_COUNT = "count es %s, pero %s contiene %d"
-- EN: count is %s, but %s holds %d
L.VIEWS_BLOCK_NOT_TABLE = "el bloque %d no es una tabla"
-- EN: block %d isn't a table
L.VIEWS_BLOCK_NOT_NUMBER = "en el bloque %d, %s no es un número"
-- EN: block %d's %s isn't a number
L.VIEWS_BLOCK_NOT_TITLES = "en el bloque %d, titles no es una tabla"
-- EN: block %d's titles isn't a table
L.VIEWS_BLOCK_LENGTH = "en el bloque %d, %s no mide %s bytes"
-- EN: block %d's %s isn't %s bytes long
L.ANGLER_TIP_HEADER = "Pescador de Pagle"
-- EN: Pagle Angler
L.ANGLER_TIP_FOLLOWING = "Siguiendo"
-- EN: Following
L.ANGLER_TIP_LEVEL = "Nivel de Pescador"
-- EN: Angler Level
L.ANGLER_TIP_PRESTIGE = "%d · %s Prestigio %s"
-- EN: %d · %s Prestige %s
L.ANGLER_TIP_MASTER_PRESTIGE = "%d · %s Prestigio de Maestro %d"
-- EN: %d · %s Master Prestige %d
L.PRESTIGE_FRAME_MASTER = "Maestro"
-- EN: Master
L.ANGLER_TIP_LEDGER = "Libro de registro"
-- EN: Ledger
L.ANGLER_TIP_LEGENDS = "Leyendas"
-- EN: Legends
L.ANGLER_TIP_LEGENDS_VALUE = "%d de %d"
-- EN: %d of %d
L.ANGLER_TIP_HARDCORE = "Pescador Hardcore"
-- EN: Hardcore Angler
L.DEV_ONBOARDING_RESET = "Pagle dev: la introducción vuelve a ser la de un Pescador nuevo, con la Carta esperando; haz /reload"
	.. " para empezar desde ahí."
-- EN: Pagle dev: onboarding is back as a new Angler's, with the Letter waiting; /reload to start from there.
L.DEV_PREVIEW_KINDS = "Pagle dev: /pagle dev preview <tipo>, donde tipo es uno de %s"
-- EN: Pagle dev: /pagle dev preview <kind>, where kind is one of %s
L.DEV_PREVIEWING = "Pagle dev: vista previa de %s."
-- EN: Pagle dev: previewing a %s.
L.DEV_STAGE_SET =
	"Pagle dev: el Cartographer's Folio se dibuja como si %d zonas estuvieran en Maestro, hasta /pagle dev stage off."
-- EN: Pagle dev: the Cartographer's Folio is drawn as if %d zones were at Master, until /pagle dev stage off.
L.DEV_STAGE_OFF = "Pagle dev: el Cartographer's Folio se dibuja en su etapa real."
-- EN: Pagle dev: the Cartographer's Folio is drawn at its real stage.
L.DEV_STAGE_IS = "Pagle dev: el Cartographer's Folio se dibuja como si %d zonas estuvieran en Maestro."
-- EN: Pagle dev: the Cartographer's Folio is drawn as if %d zones were at Master.
L.DEV_STAGE_USAGE = "Pagle dev: /pagle dev stage <número de zonas en Maestro> | off"
-- EN: Pagle dev: /pagle dev stage <count of zones at Master> | off
L.DEV_CARD_HELD = "Pagle dev: las tarjetas esperan a que acabe el combate; inténtalo entonces."
-- EN: Pagle dev: cards wait until combat ends; try again then.
L.DEV_SAMPLE_TOAST = "Nueva Especie"
-- EN: New Species
L.DEV_SAMPLE_STAMP = "Récord de tamaño"
-- EN: Size record
L.DEV_SAMPLE_NOD = "Nuevo aquí"
-- EN: New here
L.DEV_SAMPLE_VARIETY = "Variedad rara"
-- EN: Rare variety
L.DEV_SAMPLE_EPIC = "Variedad épica"
-- EN: Epic variety
L.DEV_SAMPLE_BANNER = "Nivel de Pescador 12"
-- EN: Angler Level 12
L.DEV_SAMPLE_SPLASH = "Una Leyenda"
-- EN: A Legend
L.DEV_SAMPLE_TEXT = "Oily Blackmouth (una vista previa de /pagle dev)"
-- EN: Oily Blackmouth (a /pagle dev preview)
L.DEV_SAMPLE_LINE = "Una línea de resumen de muestra"
-- EN: A sample summary line
L.DEV_SAMPLE_WRITE_UP = "Tu Libro de registro se redactó a partir de 2.340 Lances"
-- EN: Your Ledger was written up from 2,340 Casts
L.DEV_SESSION_ENDED = "Pagle dev: la Sesión terminó, como si hubiera pasado su pausa."
-- EN: Pagle dev: the Session ended, as if its gap had passed.
L.DEV_NO_SESSION = "Pagle dev: no hay ninguna Sesión abierta."
-- EN: Pagle dev: no Session is open.
L.DEV_NO_CHARACTER = "Pagle dev: aún no hay ningún personaje conectado."
-- EN: Pagle dev: no character is logged in yet.
--@do-not-package@
L.DEV_REAL_LOG = "Pagle dev: catch escribe en el Registro de capturas, así que solo funciona en un registro de prueba "
	.. "(PagleLog.test); este registro es real y no se ha añadido nada."
-- EN: Pagle dev: catch writes to the Catch log, so it runs on a test log only (PagleLog.test); this log is real, and nothing was added.
L.DEV_UNKNOWN_AREA = "Pagle dev: %s no es un área del catálogo de Pagle."
-- EN: Pagle dev: %s isn't an area in Pagle's catalogue.
L.DEV_CAUGHT = "Pagle dev: objeto %d capturado en la zona %d (entrada %d)."
-- EN: Pagle dev: caught item %d in zone %d (entry %d).
L.DEV_SKILL_USAGE = "Pagle dev: /pagle dev skill <rango> [máx], de 1 a 300 (máx es 300 por defecto), "
	.. "o /pagle dev skill off"
-- EN: Pagle dev: /pagle dev skill <rank> [max], from 1 to 300 (max defaults to 300), or /pagle dev skill off
L.DEV_SKILL_SET = "Pagle dev: la habilidad de Pesca marca ahora %d/%d, diga lo que diga el cliente. Los Lances y las "
	.. "Lecturas de habilidad lo registran. /pagle dev skill off devuelve la del cliente."
-- EN: Pagle dev: Fishing skill now reads %d/%d, whatever the client says. Casts and Skill Readings record it. /pagle dev skill off puts the client's back.
L.DEV_SKILL_CLEARED = "Pagle dev: la habilidad de Pesca vuelve a marcar lo que dice el cliente."
-- EN: Pagle dev: Fishing skill reads as the client says again.
L.DEV_SKILL_NOT_SET =
	"Pagle dev: la habilidad de Pesca marca lo que dice el cliente; /pagle dev skill <rango> la sustituye."
-- EN: Pagle dev: Fishing skill reads as the client says; /pagle dev skill <rank> overrides it.
L.DEV_SKILL_REMINDER =
	"Pagle dev: la habilidad de Pesca está sustituida por %d/%d (/pagle dev skill off para quitarlo)."
-- EN: Pagle dev: Fishing skill is overridden to %d/%d (/pagle dev skill off to clear it).
--@end-do-not-package@
L.DEV_GLYPHS_CHAT = "Pagle dev: la prueba de glifos en la fuente del chat: %s"
-- EN: Pagle dev: the glyph probe in the chat font: %s
L.DEV_GLYPHS_SHOWN = "Pagle dev: la misma línea en cada fuente que usa Pagle está en pantalla; un cuadro es un carácter que"
	.. " le falta a esa fuente. Haz clic o pulsa Esc para cerrar."
-- EN: Pagle dev: the same line in each font Pagle uses is on screen; a box is a character that font lacks. Click it or press Esc to close.
L.DEV_PROBE_SAVED = "Pagle dev: sonda guardada; haz /reload para escribirla."
-- EN: Pagle dev: Probe saved; /reload to write it.
L.DEV_TOUR_ONE_STOP = "1 parada"
-- EN: 1 stop
L.DEV_TOUR_STOPS = "%d paradas"
-- EN: %d stops
L.DEV_TOUR_START =
	"Pagle dev: recorriendo %s desde %s; una captura de pantalla de cada una va a la carpeta Screenshots."
-- EN: Pagle dev: touring %s from %s; a screenshot of each goes to the Screenshots folder.
L.DEV_TOUR_START_MANUAL = "Pagle dev: recorriendo %s desde %s; este cliente no puede hacer capturas de pantalla, así que pulsa"
	.. " Impr Pant cuando aparezca la línea de cada parada."
-- EN: Pagle dev: touring %s from %s; this client can't take screenshots, so press Print Screen as each stop's line appears.
L.DEV_TOUR_STOP = "Pagle dev: recorrido %d/%d: %s"
-- EN: Pagle dev: tour %d/%d: %s
L.DEV_TOUR_DONE = "Pagle dev: el recorrido terminó a las %s."
-- EN: Pagle dev: the tour is done at %s.
L.DEV_TOUR_STOPPED = "Pagle dev: el recorrido se detuvo en %d/%d."
-- EN: Pagle dev: the tour stopped at %d/%d.
L.DEV_TOUR_RESTRICTED_STOPPED = "Pagle dev: el recorrido se detuvo en %d/%d: empezó un combate."
-- EN: Pagle dev: the tour stopped at %d/%d: combat started.
L.DEV_TOUR_STOPPING = "Pagle dev: el recorrido se detiene cuando se oculte esta parada."
-- EN: Pagle dev: the tour stops once this stop hides.
L.DEV_TOUR_NOT_RUNNING = "Pagle dev: no hay ningún recorrido en marcha."
-- EN: Pagle dev: no tour is running.
L.DEV_TOUR_RUNNING = "Pagle dev: hay un recorrido en marcha; /pagle dev tour stop lo termina."
-- EN: Pagle dev: a tour is running; /pagle dev tour stop ends it.
L.DEV_TOUR_RESTRICTED = "Pagle dev: el recorrido espera a que acabe el combate; inténtalo entonces."
-- EN: Pagle dev: the tour waits until combat ends; try again then.
L.DEV_TOUR_NO_STOPS = "Pagle dev: no hay paradas de recorrido registradas."
-- EN: Pagle dev: no tour stops are registered.
L.DEV_TOUR_NO_STOPS_FOR = "Pagle dev: no hay paradas para %s; hay paradas registradas para %s."
-- EN: Pagle dev: no tour stops for %s; stops are registered for %s.
L.DEV_TOUR_LIST = "Pagle dev: %d paradas del recorrido:"
-- EN: Pagle dev: %d tour stops:
L.DEV_TOUR_LIST_ONE = "Pagle dev: 1 parada del recorrido:"
-- EN: Pagle dev: 1 tour stop:
L.DEV_TOUR_ANNOUNCE = "un %s de muestra"
-- EN: a sample %s
L.DEV_TOUR_CARD = "una tarjeta %s de muestra"
-- EN: a sample %s card
L.DEV_TOUR_SHOP = "la Tienda de Curiosidades"
-- EN: the Curio Shop
L.DEV_TOUR_FIELD_REPORT = "la ventana del Informe de campo"
-- EN: the Field report box
L.DEV_TOUR_EXPORT = "la ventana de exportación"
-- EN: the export window
L.DEV_TOUR_GLYPHS = "el panel de prueba de glifos"
-- EN: the glyph probe panel
L.DEV_TOUR_SETTINGS = "Ajustes: %s"
-- EN: Settings: %s
L.SLASH_CORE_HELP = {
	{ name = "settings", help = "abre los ajustes de Pagle (también /pagle solo)" },
	{ name = "shop", help = "abre o cierra la Tienda de Curiosidades" },
	{ name = "report", help = "abre el Informe de campo, para ayudar a catalogar las aguas" },
	{ name = "export", help = "copia tu Registro de capturas como Cadena de pegado para la web de Pagle" },
	{ name = "recovery", help = "exporta una instantánea de recuperación o revisa los registros conservados" },
	{ name = "guide", help = "abre la Guía de campo; /pagle guide notes vuelve a mostrar las notas al margen" },
	{ name = "help", help = "muestra estos comandos" },
}
-- EN: { { help = "open Pagle's settings (also /pagle on its own)", name = "settings" }, { help = "open or close the Curio Shop", name = "shop" }, { help = "open the Field report, to help chart the waters", name = "report" }, { help = "copy your Catch log as a Paste string for the Pagle website", name = "export" }, { help = "export a Recovery snapshot or inspect preserved records", name = "recovery" }, { help = "open the Field guide; /pagle guide notes shows the margin notes again", name = "guide" }, { help = "list these commands", name = "help" } }
L.GUIDE_NOTES_AGAIN = "Pagle: las notas al margen se volverán a mostrar, una vez cada una."
-- EN: Pagle: margin notes will show again, once each.
L.NOTE_NOD = "Eso es un *Gesto*: cuando Pagle ha tenido mucho que decir últimamente, las noticias pequeñas se quedan en una"
	.. " línea discreta. Desaparece en tres segundos, y queda en tu Libro de registro para siempre."
-- EN: That’s a *Nod*: when Pagle’s had a lot to say lately, the small news steps down to one quiet line. It’s gone in three seconds, and it’s in your Ledger for good.
L.NOTE_TOAST =
	"La moneda son *Monedas Pagle*: se ganan haciendo cosas, nunca se compran, y se gastan en aspectos en la Tienda de Curiosidades."
-- EN: The coin is *Pagle Coins*: earned by doing things, never bought, spent on looks in the Curio Shop.
L.NOTE_SUMMARY = "Te ausentaste cinco minutos, así que la Sesión se cerró. Todo lo que ganó está aquí, *incluso lo que"
	.. " nunca saltó*."
-- EN: You stepped away five minutes, so the Session closed. Everything it earned is here, *even what never popped up*.
L.NOTE_UNCHARTED = "Pagle aún no ha catalogado este. Queda guardado, y se te acreditará el día que lo haga. *"
	.. HELP_CHART
	.. "* en el menú de Pagle lo copia, para compartirlo si quieres."
-- EN: Pagle hasn’t charted this one yet. It’s kept, and credited the day it is. *Help chart the waters* in the Pagle menu copies it out, to share if you like.
L.NOTE_WELCOME = "Bienvenido de nuevo. */pagle guide* te lo enseña todo, si quieres el recorrido."
-- EN: Welcome back. */pagle guide* shows you around, if you want the tour.
L.NOTE_CHARACTER = "El mismo Libro de registro en cada personaje. Solo tu *ropa de pesca* es por personaje."
-- EN: Same Ledger on every character. Only your *fishing clothes* are per character.
L.DEV_NOTE_NONE = "Pagle dev: no hay nota al margen %s; las notas son %s."
-- EN: Pagle dev: no margin note %s; the notes are %s.
L.DEV_NOTE_NO_TARGET = "Pagle dev: la nota al margen %s no tiene nada en pantalla a lo que señalar ahora."
-- EN: Pagle dev: margin note %s has nothing on screen to point at now.
L.LOOK_BAR_TITLE = "Primer vistazo · %s"
-- EN: First look · %s
L.LOOK_BAR_COUNT = "%d notas, se muestran una vez"
-- EN: %d notes, shown once
L.LOOK_BAR_COUNT_ONE = "1 nota, se muestra una vez"
-- EN: 1 note, shown once
L.LOOK_BAR_DONE = "Entendido, guarda las notas"
-- EN: Got it, put the notes away
L.LOOK_AGAIN = "Volver a mostrar las notas de esta página"
-- EN: Show the notes for this page again
L.LOOK_SHOP_TITLE = "la Tienda de Curiosidades"
-- EN: the Curio Shop
L.LOOK_SHOP_COINS = "Las Monedas solo salen de cosas que has hecho. La barra muestra qué las pagó."
-- EN: Coins come only from things you’ve done. The bar shows what paid them.
L.LOOK_SHOP_LOOKS =
	"Todo aquí es un *aspecto*: avisos emergentes, sonidos, encuadernaciones, blasones. Nada te hace pescar mejor."
-- EN: Everything here is a *look*: toasts, sounds, bindings, crests. Nothing makes you fish better.
L.LOOK_SHOP_SHOW = "*Mostrar en pantalla* lo reproduce de verdad antes de que compres."
-- EN: *Show on screen* plays it for real before you buy.
L.LOOK_SHOP_STOCK = "El surtido *nunca rota*. Lo que hay hoy seguirá aquí el mes que viene."
-- EN: The stock *never rotates*. What’s here today is here next month.
L.DEV_LOOK_NONE = "Pagle dev: no hay Primer vistazo %s; los conjuntos son %s."
-- EN: Pagle dev: no First look %s; the sets are %s.
L.DEV_LOOK_CLOSED = "Pagle dev: la ventana del Primer vistazo %s no está abierta; ábrela primero."
-- EN: Pagle dev: First look %s's window isn't open; open it first.
L.DEV_LOOK_EMPTY = "Pagle dev: el Primer vistazo %s no tiene nada en pantalla a lo que señalar ahora."
-- EN: Pagle dev: First look %s has nothing on screen to point at now.
L.DEV_TOUR_LOOK = "el Primer vistazo en %s"
-- EN: the First look on %s
L.GUIDE_CRUMB_GUIDE = "Una guía de campo"
-- EN: A field guide
L.GUIDE_COUNT = "|cfff6e3a8%d|r de %d"
-- EN: |cfff6e3a8%d|r of %d
L.GUIDE_SKIP = "Saltar el resto"
-- EN: Skip the rest
L.GUIDE_NEXT = "Siguiente »"
-- EN: Next »
L.GUIDE_BACK = "« atrás"
-- EN: « back
L.GUIDE_OFF = "¡Al agua!"
-- EN: Off to the water
L.GUIDE_AFTER_COMBAT = "Pagle: la Guía de campo se abre tras el combate."
-- EN: Pagle: the Field guide opens after combat.
L.GUIDE_SHOW_ME_AROUND = "Enséñamelo todo »"
-- EN: Show me around »
L.DEV_GUIDE_NO_STEP = "Pagle dev: no hay paso de guía %s; los pasos son %s."
-- EN: Pagle dev: no guide step %s; the steps are %s.
L.DEV_TOUR_GUIDE_STEP = "la Guía de campo en su paso %s"
-- EN: the Field guide at its %s step
L.EVENING_TITLE = "Primera tarde"
-- EN: First evening
L.EVENING_COUNT = "%d de %d"
-- EN: %d of %d
L.EVENING_CAST = "Haz un Lance"
-- EN: Make a Cast
L.EVENING_CAST_HINT = "pulsa tu Tecla de pesca, o doble clic derecho"
-- EN: press your Fishing key, or double right-click
L.EVENING_CAST_HINT_NO_QOL = "clic derecho en el agua con Pesca"
-- EN: right-click the water with Fishing
L.EVENING_CATCH = "Consigue una Captura"
-- EN: Land a Catch
L.EVENING_JOURNAL = "Abre el Diario de peces"
-- EN: Open the Fish Journal
L.EVENING_JOURNAL_HINT = "Menú de Pagle junto al minimapa » Diario de peces"
-- EN: Pagle menu by the minimap » Fish Journal
L.EVENING_HUNTS = "Mira qué pica en Cazas"
-- EN: See what’s biting on Hunts
L.EVENING_HUNTS_HINT = "Menú de Pagle » Cazas"
-- EN: Pagle menu » Hunts
L.EVENING_SESSION = "Termina una Sesión"
-- EN: Finish a Session
L.EVENING_SESSION_HINT = "aléjate 5 minutos para ver tu resumen"
-- EN: step away 5 minutes for your summary
L.EVENING_SHOP = "Echa un vistazo a la Tienda de Curiosidades"
-- EN: Peek into the Curio Shop
L.EVENING_SHOP_HINT = "Menú de Pagle » Tienda de Curiosidades"
-- EN: Pagle menu » Curio Shop
L.DEV_TOUR_EVENING = "la lista de la Primera tarde"
-- EN: the First evening list
L.GUIDE_RIBBON_WELCOME = "Bienvenida"
-- EN: Welcome
L.GUIDE_RIBBON_BOX = "Qué hay en la caja"
-- EN: What’s in the box
L.GUIDE_RIBBON_MOMENTS = "Momentos"
-- EN: Moments
L.GUIDE_RIBBON_OFF = "¡A pescar!"
-- EN: Off you go
L.GUIDE_WELCOME_SKIP = "Ya me apaño solo"
-- EN: I’ll find my own way
L.GUIDE_WELCOME_NEXT = "Enséñamelo todo »"
-- EN: Show me around »
L.GUIDE_WELCOME_KICKER = "Una carta, dejada en el muelle"
-- EN: A letter, left on the dock
L.GUIDE_WELCOME_TITLE = "Querido Pescador:"
-- EN: Dear Angler,
L.GUIDE_WELCOME_RIGHT_KICKER = "Antes que nada"
-- EN: Before anything else
L.GUIDE_WELCOME_RIGHT_TITLE = "Tres promesas"
-- EN: Three promises
L.GUIDE_BOX_KICKER = "El equipo"
-- EN: The kit
L.GUIDE_BOX_TITLE = "Lo que venía en la caja"
-- EN: What came in the box
L.GUIDE_MOMENTS_KICKER = "Momentos"
-- EN: Moments
L.GUIDE_MOMENTS_TITLE = "Cuando pasa algo bueno"
-- EN: When something good happens
L.GUIDE_MOMENTS_RIGHT_KICKER = "Tú eliges"
-- EN: Your choice
L.GUIDE_MOMENTS_RIGHT_TITLE = "¿Cuánto debe hablar Pagle?"
-- EN: How chatty should Pagle be?
L.GUIDE_OFF_KICKER = "Eso es todo por ahora"
-- EN: That’s all for now
L.GUIDE_OFF_TITLE = "El resto se aprende pescando"
-- EN: The rest you learn by fishing
L.GUIDE_OFF_RIGHT_KICKER = "Tu primera tarde"
-- EN: Your first evening
L.GUIDE_OFF_RIGHT_TITLE = "Una lista corta, si quieres"
-- EN: A short list, if you like
L.GUIDE_OFF_AGAIN = "|cff3e220c/pagle guide|r vuelve a abrir esta guía."
-- EN: |cff3e220c/pagle guide|r opens this guide again.
-- Feminine: the pages only ever count partes.
L.GUIDE_COUNT_WORDS = { "ninguna", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez" }
-- EN: { "no", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten" }
L.GUIDE_LIST_AND = " y "
-- EN: " and "
L.GUIDE_WELCOME_LETTER = {
	"A partir de ahora, cada pez que saques del agua queda anotado: dónde, cuándo, de qué tamaño y lo que costó sacarlo.",
	"Pesca lo suficiente y el agua empieza a contarte cosas: qué pica solo de noche, qué peces se te siguen escapando, cuánto has avanzado.",
	"Deja que te lo enseñe todo. Son dos minutos, y puedes cambiarlo todo más tarde.",
}
-- EN: { "From now on, every fish you pull out of the water gets written down: where, when, how big, and what it took to land it.", "Fish long enough and the water starts telling you things: what bites only at night, which fish you keep missing, how far you’ve come.", "Let me show you around. It takes two minutes, and you can change everything later." }
L.GUIDE_WELCOME_FOOT = "Todo esto también está en Opciones » Accesorios » Pagle."
-- EN: Everything here is also in Options » AddOns » Pagle.
L.GUIDE_WELCOME_PROMISES = {
	{
		"I",
		"Nunca pesco por ti.",
		"Pagle observa y lo apunta todo. Cada pulsación hace una cosa como mucho, y quien pesca son tus manos.",
	},
	{
		"II",
		"Nada caduca.",
		"No hay diarias que perderse. Los objetivos te esperan, y un día fuera no te cuesta nada.",
	},
	{ "III", "Cada parte es opcional." },
}
-- EN: { { "I", "I never fish for you.", "Pagle watches and writes things down. Every key press does one thing at most, and your hands do the fishing." }, { "II", "Nothing expires.", "There are no dailies to miss. Goals wait for you, and a day away costs you nothing." }, { "III", "Every part is optional." } }
L.GUIDE_WELCOME_PARTS = "Pagle viene en %s partes. Desactiva cualquiera en la lista de accesorios y no deja rastro."
-- EN: Pagle comes in %s parts. Turn any of them off in the AddOns list and it leaves no trace.
L.GUIDE_BOX_TEXT =
	"Pagle es un pequeño equipo, no una gran ventana. Cada parte tiene su sitio, y todas se abren desde la entrada |cff3e220cPagle|r bajo el botón de accesorios junto a tu minimapa."
-- EN: Pagle is a small kit, not one big window. Each part has its own place, and every one of them opens from the |cff3e220cPagle|r entry under the addons button by your minimap.
L.GUIDE_BOX_MENU_NOTE = "Haz clic en un nombre para abrirlo. */pagle* abre los Ajustes."
-- EN: Click a name to open it. */pagle* opens Settings.
L.GUIDE_BOX_PARTS = "%s partes y una tienda"
-- EN: %s parts, and a shop
L.GUIDE_BOX_PART = "%s parte y una tienda"
-- EN: %s part, and a shop
L.GUIDE_BOX_SHOP = "Tienda de Curiosidades"
-- EN: Curio Shop
L.GUIDE_BOX_SHOP_BLURB = "Las Monedas Pagle salen de lo que logras, y compran aspectos, nunca poder."
-- EN: Pagle Coins come from things you achieve, and buy looks, never power.
L.GUIDE_BOX_NONE = "Activa partes en la lista de accesorios."
-- EN: Turn parts on in the AddOns list.
L.GUIDE_MOMENTS_TEXT = "Pagle te avisa, en uno de tres tamaños. Cuanto mayor el momento, mayor la nota."
-- EN: Pagle tells you, in one of three sizes. The bigger the moment, the bigger the note.
L.GUIDE_MOMENTS_SAMPLES = {
	nod = { "Un Gesto", "Cuando Pagle ha hablado mucho últimamente. Una línea, que desaparece en 3 segundos." },
	toast = { "Un aviso emergente", "Cada Captura, un pez nuevo, un récord, Monedas ganadas." },
	banner = { "Un estandarte", "Un nuevo Nivel de Pescador y el título que lo acompaña." },
}
-- EN: { banner = { "A banner", "A new Angler Level, and the title that comes with it." }, nod = { "A Nod", "When Pagle’s said a lot lately. One line, gone in 3 seconds." }, toast = { "A toast", "Every Catch, a new fish, a record, Coins earned." } }
L.GUIDE_MOMENTS_BUDGET =
	"Como mucho %d interrupciones cada %d minutos: pasado eso, las pequeñas se quedan en un Gesto. Todo acaba en el Resumen de sesión cuando paras."
-- EN: At most %d pop-ups every %d minutes: past that, small ones step down to a Nod. Everything lands on the Session summary when you stop.
L.GUIDE_PRESETS = {
	lively = { "Animado", "Un aviso emergente por cada Captura; estandartes también, con sonido.", "según llega" },
	quieter = {
		"Más tranquilo",
		"Sin aviso emergente para las Capturas normales y menos interrupciones. Los grandes momentos se siguen viendo.",
	},
	cozy = { "Acogedor", "No salta ni suena nada. Todo espera a tu Resumen de sesión." },
}
-- EN: { cozy = { "Cozy", "Nothing pops up and nothing plays. It all waits for your Session summary." }, lively = { "Lively", "A toast for every Catch; banners too, with sound.", "as it comes" }, quieter = { "Quieter", "No toast for ordinary Catches, and fewer pop-ups. The big moments still show." } }
L.GUIDE_PRESET_POPUPS = "%d interrupciones en %d minutos"
-- EN: %d pop-ups in %d minutes
L.GUIDE_PRESET_COZY_WHAT = "una Leyenda sigue mostrándose, en silencio"
-- EN: a Legend still shows, silently
L.GUIDE_PRESET_OWN = "Tu propia mezcla, tal como está."
-- EN: Your own mix, kept as it is.
L.GUIDE_MOMENTS_NOTE = "Cada uno solo ajusta los interruptores de Ajustes » Anuncios, donde puedes afinarlos luego."
-- EN: Each one only sets the switches in Settings » Announcements, where you can fine-tune them later.
L.GUIDE_OFF_TEXT =
	"La primera vez que pase algo nuevo (tu primer Gesto, tu primer pez nuevo, tu primer Resumen de sesión) dejaré una nota al lado. Una vez. Después, los márgenes quedan limpios."
-- EN: The first time something new happens (your first Nod, your first new fish, your first Session summary) I’ll leave a note beside it. Once. After that the margins stay clean.
L.GUIDE_OFF_NOD_NOTE = "Eso es un *Gesto*: cada pieza tiene uno. Desaparece en tres segundos."
-- EN: That’s a *Nod*: every Catch gets one. It’s gone in three seconds.
L.GUIDE_OFF_LOOKS =
	"¿No quieres notas? Desactiva las Notas al margen en los Ajustes. %s traen unas notas breves la primera vez que se abren."
-- EN: Don’t want notes? Turn off Margin notes in Settings. %s each get a short set the first time you open them.
L.GUIDE_OFF_LOOKS_ONE =
	"¿No quieres notas? Desactiva las Notas al margen en los Ajustes. %s trae unas notas breves la primera vez que se abre."
-- EN: Don’t want notes? Turn off Margin notes in Settings. %s gets a short set the first time you open it.
L.GUIDE_OFF_LIST_TEXT = "Se coloca bajo tus misiones y se va tachando sola. Ciérrala cuando quieras."
-- EN: It sits under your quests and ticks itself off. Close it whenever you like.
L.GUIDE_EVENING_TITLE = "Primera tarde"
-- EN: First evening
L.GUIDE_EVENING_COUNT = "%d de %d"
-- EN: %d of %d
L.GUIDE_EVENING_ITEMS = {
	cast = "Haz un Lance",
	catch = "Consigue una Captura",
	journal = "Abre el Diario de peces",
	hunts = "Mira qué pica en Cazas",
	session = "Termina una Sesión",
	shop = "Echa un vistazo a la Tienda de Curiosidades",
}
-- EN: { cast = "Make a Cast", catch = "Land a Catch", hunts = "See what’s biting on Hunts", journal = "Open the Fish Journal", session = "Finish a Session", shop = "Peek into the Curio Shop" }
L.GUIDE_EVENING_HINTS = {
	cast = "pulsa tu Tecla de pesca, o doble clic derecho",
	castNoQoL = "clic derecho en el agua con Pesca",
	session = "aléjate 5 minutos para ver tu resumen",
}
-- EN: { cast = "press your Fishing key, or double right-click", castNoQoL = "right-click the water with Fishing", session = "step away 5 minutes for your summary" }

L.LETTER_KICKER = "Una carta, dejada en el muelle"
-- EN: A letter, left on the dock
L.LETTER_LINE = "Pagle ha llegado. Ábrela cuando quieras; puede esperar."
-- EN: Pagle has arrived. Open it whenever you’re ready; it’ll keep.
L.LETTER_OPEN = "Abrir la carta"
-- EN: Open the letter
L.LETTER_LATER = "Más tarde"
-- EN: Later
L.DEV_TOUR_LETTER = "la Carta"
-- EN: the Letter
L.DEV_TOUR_LETTER_OF = "la carta %s"
-- EN: the letter %s
L.DEV_LETTER_NONE = "Pagle dev: no hay carta %s; las cartas son %s."
-- EN: Pagle dev: no letter %s; the letters are %s.

L.SLOT_TOAST_STYLE = "Estilo de aviso emergente"
-- EN: Toast style
L.SLOT_SOUND_SET = "Juego de sonidos"
-- EN: Sound set
L.SLOT_CREST = "Blasones"
-- EN: Crests
L.SLOT_BOOK_BINDING = "Encuadernación"
-- EN: Book binding
L.SLOT_CREST_ZONES = "Blasones de zona"
-- EN: Zone crests
L.SLOT_CREST_FISH = "Blasones de pez"
-- EN: Fish crests
L.FISH_CREST_ITEM = "Objeto %d"
-- EN: Item %d
L.FISH_CREST_ROW = "%d de 10 variedades"
-- EN: %d of 10 varieties
L.FISH_CREST_NOTE = "%d de 10 variedades de %s. Aún por ahí: %s."
-- EN: %d of 10 %s varieties. Still out there: %s.
L.FISH_CREST_NOTE_ALL = "%d de 10 variedades de %s."
-- EN: %d of 10 %s varieties.
-- Rarity first: "4 Común" doesn't agree, "Común ×4" needs no agreement.
L.FISH_CREST_UNCAUGHT = "%2$s ×%1$d"
-- EN: %d %s
-- Short of the glossary's "Aviso emergente": the three preview buttons are sized for one English word.
L.PREVIEW_TOAST = "» Aviso"
-- EN: » Toast
L.PREVIEW_BANNER = "» Estandarte"
-- EN: » Banner
L.PREVIEW_LEGEND = "» Leyenda"
-- EN: » Legend
L.PREVIEW_STING_SHARED = "La sintonía de Leyenda es la misma en todos los juegos."
-- EN: The Legend sting is the same in every set.
L.PREVIEW_EX_LIBRIS = "Ex libris"
-- EN: Ex Libris
L.PREVIEW_CREST_NOTE = "En el Ex libris del Diario de peces."
-- EN: On the Fish Journal's bookplate.
L.PREVIEW_BINDING_NOTE = "Todos tus libros la llevan."
-- EN: Every book of yours wears it.
