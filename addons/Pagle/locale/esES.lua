if not GetLocale or GetLocale() ~= "esES" then
	return
end

-- Core's Spanish (Spain) strings, over enUS.lua's on an esES client.
local ns = select(2, ...)
local L = ns.L

local COIN = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"
local HELP_CHART = "Ayuda a catalogar las aguas"

L.TRAILER_CAPTION_CATCH = "Cada captura cuenta una historia"
L.TRAILER_CAPTION_JOURNAL = "Una colección que merece la pena"
L.TRAILER_CAPTION_VARIETIES = "No hay dos iguales"
L.TRAILER_CAPTION_ANGLER = "Crece con cada captura"
L.TRAILER_CAPTION_XP = "Cada empeño suma"
L.TRAILER_CAPTION_WAGERS = "Compite en los eventos de la semana"
L.TRAILER_CAPTION_CRESTS = "Domina las aguas"
L.TRAILER_CAPTION_COLLECTIONS = "Guarda las memorables"
L.TRAILER_CAPTION_STATS = "Conoce las aguas"
L.TRAILER_CAPTION_HUNTS = "Encuentra tu próxima aventura"
L.TRAILER_CAPTION_BOARD = "Un motivo para otro lance"
L.TRAILER_CAPTION_SHOP = "Hazlo tuyo"
L.TRAILER_CAPTION_COZY = "Disfruta de la calma"
L.TRAILER_CAPTION_REPORT = "Comparte lo que descubras"
L.TRAILER_CAPTION_END = "Pagle: cada captura, por escrito."
L.TRAILER_LENGTH_NOTE = "Longitudes simuladas por Pagle"
L.TRAILER_ARMED =
	"Pagle: tráiler preparado. Empieza a grabar y pesca con tu Tecla de pesca. Esperando un pez con longitud de Pagle."
L.TRAILER_ACTIVE = "Pagle: el tráiler ya está activo. /pagle trailer stop lo cancela."
L.TRAILER_STOPPED = "Pagle: tráiler detenido. Tus datos del addon están restaurados."
L.TRAILER_COMPLETE = "Pagle: tráiler completado. Tus datos del addon están restaurados."
L.TRAILER_ERROR = "Pagle: tráiler detenido tras un error; tus datos del addon están restaurados."
L.TRAILER_COMBAT = "Pagle: tráiler detenido por un combate. Tus datos del addon están restaurados."
L.TRAILER_NEW_CAST = "Pagle: tráiler detenido por un nuevo lance. Tus datos del addon están restaurados."
L.TRAILER_STATUS = "Tráiler de Pagle: %s"
L.TRAILER_USAGE =
	"Pagle: /pagle trailer prepara una grabación; /pagle trailer stop la cancela; /pagle trailer status muestra su estado."
L.TRAILER_AFTER_COMBAT = "El tráiler de Pagle empieza tras el combate."
L.TRAILER_NEEDS_ANGLER = "El tráiler de Pagle necesita un Pescador conectado."
L.TRAILER_WAIT_HISTORY = "Espera a que Pagle termine de leer tu Registro de capturas."
L.TRAILER_WAIT_ANNOUNCEMENTS = "Espera a que terminen los anuncios de Pagle antes de preparar el tráiler."
L.TRAILER_ENABLE_MODULE = "Activa Pagle %s antes de grabar el tráiler completo."
L.TRAILER_SUMMARY_LINE = "Un récord personal, nuevos descubrimientos y avances hacia tu próximo Nivel de Pescador."
L.TRAILER_SUMMARY_TITLE = "Una captura que merece la pena"
L.TRAILER_SUMMARY_TEXT = "Tu récord queda en el Diario de peces."
L.LOG_FORMAT_CHANGED = "Pagle: el formato del registro de desarrollo cambió; se empezó un registro nuevo."
L.LOG_UNREADABLE =
	"Pagle se ha detenido: tu Registro de capturas no se puede leer (%s) y no se ha cambiado nada. Antes de cerrar sesión o recargar, copia Pagle.lua y Pagle.lua.bak de WTF/Account/<cuenta>/SavedVariables a un lugar seguro y avísanos en github.com/timemir/pagle-addon/issues."
L.LOG_UNREADABLE_PAUSED =
	"Pagle está detenido: tu Registro de capturas no se puede leer y no se ha cambiado nada. La línea del inicio de sesión dice qué hacer."
L.NOT_FOREVER = "Pagle: esto no es World of Warcraft: Forever, así que Pagle se queda desactivado."
L.SIZE_BANDS = { "Pececillo", "Decente", "Robusto", "Descomunal", "Monstruo" }
L.VARIETY_RARITIES = { "Común", "Poco común", "Raro", "Épico" }
L.LENGTH = { cm = "%.1f cm", ["in"] = "%.1f pulg." }
L.LENGTH_MARGIN_UNDER = { cm = "+<0.1 cm", ["in"] = "+<0.1 pulg." }
L.EVENT_REGISTER_FAILED = "Pagle: %s no pudo registrar el evento %s: %s"
L.EVENT_HANDLER_FAILED = "Pagle: el controlador de %s para el evento %s falló: %s"
L.MODULE_NEEDS_NEWER_PAGLE = "Pagle: Pagle %s necesita un Pagle más reciente."

L.SETTING_TOO_LATE = "Pagle: el AddSetting de %s llegó después de ModulesChanged, así que la fila se descarta"

L.SETTINGS_PAGES = {
	fishing = "Pesca",
	announcements = "Anuncios",
	trackers = "Rastreadores",
	look = "Apariencia",
}
L.SETTINGS_TRACKER_POSITION = "Posición de los rastreadores"
L.SETTINGS_TRACKER_RESET = "Restablecer"
L.SETTINGS_TRACKER_RESET_TOOLTIP =
	"Arrastra con Mayús cualquier rastreador de Pagle para moverlos todos. Esto los devuelve bajo el minimapa."
L.SETTINGS_TOAST_POSITION = "Posición de los avisos emergentes"
L.SETTINGS_TOAST_RESET = "Restablecer"
L.SETTINGS_TOAST_RESET_TOOLTIP =
	"Arrastra con Mayús un aviso emergente para mover los avisos emergentes y los Gestos. Esto los devuelve a la parte inferior de la pantalla."
L.SETTINGS_NO_MODULE = "Registrando tus Capturas. Activa un Módulo para verlas."
L.SETTINGS_MODULES = "Módulos"
L.SETTINGS_MODULES_NOTE = "Activa o desactiva Módulos en la lista de accesorios."
L.SETTINGS_GETTING_STARTED = "Primeros pasos"
L.SETTINGS_FIELD_GUIDE = "Guía de campo"
L.SETTINGS_FIELD_GUIDE_LINE = "Las ocho páginas que viste el primer día."
L.SETTINGS_SHOW_ME_AROUND = "Enséñamelo todo otra vez"
L.SETTINGS_MARGIN_NOTES = "Notas al margen"
L.SETTINGS_MARGIN_NOTES_TOOLTIP = "Explica las cosas la primera vez que pasan."
L.SETTINGS_SHOW_NOTES_AGAIN = "Mostrarlas otra vez"
L.SETTINGS_EVENING = "Lista de la Primera tarde"
L.SETTINGS_EVENING_LINE = "%d de %d hechas"
L.SETTINGS_SAVING = "Guardado"
L.SETTINGS_RELOAD_REMINDER = "Recuérdame hacer /reload cuando haya Lances sin guardar"
L.SETTINGS_RELOAD_REMINDER_TOOLTIP =
	"Una línea en el chat cada %d Lances sin guardar. WoW solo guarda al hacer /reload o cerrar sesión, así que un cierre inesperado los pierde."
L.SETTINGS_UNITS = "Unidades"
L.SETTINGS_LENGTH_UNIT = "Unidad de longitud"
L.SETTINGS_LENGTH_UNIT_TOOLTIP =
	"Cómo muestra Pagle la longitud de tus Capturas. Los registros se guardan en milímetros, así que cambiarla solo cambia lo que ves."
L.SETTINGS_LENGTH_UNITS = { cm = "Centímetros", ["in"] = "Pulgadas" }
L.SETTINGS_CLOCK = "Reloj"
L.SETTINGS_CLOCK_TOOLTIP =
	"Cómo escribe Pagle una hora del día, como la hora del reino arriba del tablón de Cazas. Seguir el juego usa el modo de 24 horas del reloj del minimapa."
L.SETTINGS_CLOCK_CHOICES = {
	game = "Seguir el reloj del juego",
	["24h"] = "24 horas (18:30)",
	["12h"] = "12 horas (6:30 PM)",
}
L.SETTINGS_PAGLE_MENU = "Menú de Pagle"
L.SETTINGS_MINIMAP_ICON = "Mostrar el icono del minimapa"
L.SETTINGS_MINIMAP_ICON_TOOLTIP =
	"Un botón redondo de Pagle en el borde del minimapa que abre el menú de Pagle. El menú también está en el botón de accesorios junto al minimapa."
L.SETTINGS_PAGLE_WEBSITE = "Web de Pagle"
L.SETTINGS_ANGLER_TOOLTIPS = "Mostrar otros Pescadores en el tooltip de los jugadores"
L.SETTINGS_ANGLER_TOOLTIPS_TOOLTIP =
	"Añade un bloque de Pagle al tooltip de los jugadores cuyo Pescador está en la web de Pagle. Necesita Pagle Companion."
L.SETTINGS_COZY = "Modo acogedor"
L.SETTINGS_COZY_TOOLTIP =
	"No salta ni suena nada. Cada momento espera en el Resumen de sesión. El Destello de una Leyenda sigue apareciendo, en silencio."
L.SETTINGS_BUDGET = "Presupuesto de interrupciones"
L.SETTINGS_BUDGET_TOOLTIP =
	"Cuando los avisos emergentes llegan muy seguidos, los pequeños se quedan en un Gesto discreto. Los récords siempre conservan su regla. En gris en el Modo acogedor, que ya lo retiene todo."
L.SETTINGS_BUDGET_COUNT = "Interrupciones"
L.SETTINGS_BUDGET_WINDOW = "Cada"
L.SETTINGS_EVERY_CATCH = "Mostrar cada captura"
L.SETTINGS_MOTION = "Animaciones"
L.SETTINGS_MOTION_TOOLTIP =
	"Los avisos emergentes entran deslizándose y se estampan, los estandartes dejan caer su sello y giran los rayos tras un estandarte o una Leyenda. Desactivadas, cada uno aparece ya asentado."
L.SETTINGS_EVERY_CATCH_TOOLTIP =
	"Un aviso emergente por cada captura: su nombre, talla y longitud. Si la misma captura trae un momento mayor, se muestra ese, y pasado tu presupuesto de interrupciones se queda en una línea discreta. En gris en el Modo acogedor, que no muestra nada."
L.SETTINGS_LOOK_PARAGRAPH =
	"Aspectos que tienes. Elige uno aquí, en la Colección del Diario de peces o con Usar en la Tienda de Curiosidades; todos cambian lo mismo."
L.SETTINGS_SLOT_MORE = "%d más en la Tienda de Curiosidades"
L.SETTINGS_MORE_LOOKS = "Más aspectos"
L.SETTINGS_COLLECTION_ROW = "Cada aspecto y cómo conseguirlo"
L.SETTINGS_COLLECTION_BUTTON = "Abrir la Colección"
L.SETTINGS_SHOP_ROW = "Compra más aspectos con Monedas Pagle"
L.SETTINGS_SHOP_BUTTON = "Abrir la Tienda de Curiosidades"
L.ANNOUNCEMENT_MORE = "+%d más"
L.ANNOUNCEMENT_STAMP_REFRESH = "Renovación +%d"
L.ANNOUNCEMENT_NEW_RECORD = "Nuevo récord"
L.ANNOUNCEMENT_SPLASH_HINT = "Haz clic en cualquier sitio para continuar"
L.ANNOUNCEMENT_SPLASH_RELOAD = "/reload para ponerla a salvo"
L.LEGEND_CREST_LEGEND = "Leyenda"
L.LEGEND_CREST_UNWRITTEN = "Por escribir"
L.ANNOUNCEMENT_WHILE_FIGHTING = "Mientras combatías"
L.CATCH_TOAST_CAUGHT = "Capturada"
L.CATCH_TOAST_ITEM = "Objeto %d"
L.CARD_SESSION = "Sesión de pesca"
L.CARD_LAST_SESSION = "Tu última sesión"
L.CARD_WRITE_UP = "Reseña"
L.CARD_CASTS = "Lances"
L.CARD_CATCHES = "Capturas"
L.CARD_GOT_AWAY = "Escapados"
L.CARD_TIME = "Tiempo pescando"
L.CARD_COINS = "Monedas Pagle +%s " .. COIN
L.CARD_CLOSE = "Cerrar"
L.TOAST_SAMPLE_TITLE = "Nueva Especie"
L.TOAST_SAMPLE_TEXT = "Un aviso emergente de muestra"
L.TOAST_SAMPLE_STAMP = "Nuevo aquí"
L.TOAST_SHOW_ON_SCREEN = "Mostrar en pantalla"
L.RELOAD_REMINDER = "Pagle: %d Lances sin guardar. Haz /reload para ponerlos a salvo."
L.SETTINGS_AFTER_COMBAT = "Pagle: los ajustes se abren tras el combate."
L.SETTINGS_KEY_NOT_BOUND = "Sin asignar"
L.SETTINGS_KEY_WAITING = "Pulsa una tecla"
L.GUIDE_BIND_CLICK = "clic para asignar"
L.GUIDE_BIND_DEFAULT = "por defecto: no hay nada asignado"
L.GUIDE_BIND_LISTEN = "pulsa una tecla…"
L.GUIDE_BIND_ESC = "Esc la deja como estaba"
L.GUIDE_BIND_BOUND = "Asignada"
L.GUIDE_BIND_PICK = "Elige otra tecla"
L.GUIDE_BIND_KEPT = "el uso anterior queda anotado, nunca se pierde sin avisar"
L.GUIDE_BIND_ASK = {
	PAGLE_FISHING_KEY = "ya hace %s. ¿Usarla para pescar?",
	PAGLE_SWAP_GEAR = "ya hace %s. ¿Usarla para cambiar de equipo?",
}
L.GUIDE_BIND_USE = {
	PAGLE_FISHING_KEY = "Usar %s para pescar",
	PAGLE_SWAP_GEAR = "Usar %s para cambiar de equipo",
}
L.GUIDE_BIND_TOLD = {
	PAGLE_FISHING_KEY = "Pagle: %s ahora lanza. Antes hacía %s; reasígnalo en Asignación de teclas si lo necesitas.",
	PAGLE_SWAP_GEAR = "Pagle: %s ahora cambia tu equipo. Antes hacía %s; reasígnalo en Asignación de teclas si lo necesitas.",
}
L.MODULE_NAMES = {
	Ledger = "Libro de registro",
	Hunts = "Cazas",
	Stats = "Estadísticas",
	TackleBoard = "Tablón de aparejos",
	QoL = "Comodidades",
}
L.MODULE_STATES = {
	on = "Activado",
	needsNewerPagle = "Necesita un Pagle más reciente",
	failedToStart = "No pudo iniciarse",
	off = "Desactivado",
	notInstalled = "No instalado",
}
L.OPEN_VIEW = "Abrir %s"

L.MENU_SETTINGS = "Ajustes"
L.MENU_CURIO_SHOP = "Tienda de Curiosidades  %s " .. COIN
L.HELP_CHART = HELP_CHART
L.HELP_CHART_COUNT = HELP_CHART .. " (%d)"

L.FIELD_REPORT_PRIVACY = "Esto se publicará a la vista de todos. No contiene nombres de personajes."
L.FIELD_REPORT_COPY_HINT = "Ctrl+C para copiar"
L.FIELD_REPORT_POST_AT = "PUBLÍCALO EN"
L.FIELD_REPORT_PART = "Parte %d de %d"
L.FIELD_REPORT_CLOSE = "Cerrar"
L.FIELD_REPORT_NOTHING = "Nada que informar. ¡Gracias por comprobarlo!"
L.FIELD_REPORT_UPDATING = "Actualizando... inténtalo de nuevo en un momento."
L.FIELD_REPORT_AFTER_COMBAT = "Pagle: el Informe de campo se abre tras el combate."
L.SETTINGS_FIELD_REPORT_ROW = "Informe de campo"
L.SETTINGS_FIELD_REPORT_BUTTON = "Abrir el Informe de campo"
L.SETTINGS_FIELD_REPORT_BUTTON_COUNT = "Abrir el Informe de campo (%d)"
L.SETTINGS_FIELD_REPORT_TOOLTIP =
	"Copia lo que has capturado y los datos de Pagle aún no conocen, y pégalo en el formulario de incidencias."
L.PASTE_TITLE = "Exportar para la web"
L.PASTE_PRIVACY = "Contiene los nombres de tus personajes. Pégalo solo en la web de Pagle."
L.PASTE_COPY_HINT = "Ctrl+C para copiar"
L.PASTE_CHOICE_NEW = "Lo nuevo desde la última exportación"
L.PASTE_CHOICE_EVERYTHING = "Todo"
L.PASTE_ENTRIES = "Entradas %s–%s de %s"
L.PASTE_NO_ENTRIES = "Sin entradas"
L.PASTE_IN_ORDER = "Pega cada parte por separado, en orden."
L.PASTE_AT = "PÉGALO EN"
L.PASTE_PART = "Parte %d de %d"
L.PASTE_CLOSE = "Cerrar"
L.PASTE_NOTHING_NEW = "Nada nuevo desde tu última exportación."
L.PASTE_CANT_EXPORT = "Pagle no puede exportar este Registro de capturas."
L.PASTE_PREPARING = "Preparando tu Cadena de pegado…"
L.PASTE_AFTER_COMBAT = "Pagle: la ventana de exportación se abre tras el combate."
L.PASTE_TEST_LINE = "Prueba de copia: %d KB"
L.SETTINGS_PASTE_ROW = "Registro de capturas"
L.SETTINGS_PASTE_BUTTON = "Copiar para la web"
L.SETTINGS_PASTE_TOOLTIP =
	"Copia tu Registro de capturas como Cadena de pegado, para pegarlo en la web de Pagle sin el Companion."
L.SHOP_AFTER_COMBAT = "Pagle: la Tienda de Curiosidades se abre tras el combate."
L.SHOP_COINS = "Monedas Pagle"
L.SHOP_ALL_TIME = "%s Monedas en total"
L.SHOP_OFF_NOTE = "Desactivado: no paga nada nuevo, conserva lo que pagó."
L.SHOP_SEARCH = "Busca un aspecto…"
L.SHOP_FILTERS = { all = "Todos", owned = "Tuyos", notOwned = "Por conseguir", canAfford = "Asequibles" }
L.SHOP_ALL_CATEGORIES = "Todos"
L.SHOP_CATEGORIES = {
	Announcements = "Anuncios",
	Crests = "Blasones",
	Books = "Libros",
	Trackers = "Rastreadores",
}
L.SHOP_OWNED_COUNT = "%d de %d"
L.SHOP_PUT_AWAY = "Guardados: Módulo desactivado"
L.SHOP_KEEP = "Tuyo para siempre"
L.SHOP_NO_MATCH = "Ningún aspecto coincide."
L.SHOP_OWNED = "Tuyo"
L.SHOP_IN_USE = "En uso"
L.SHOP_DEFAULT = "por defecto"
L.SHOP_BUY = "Comprar por %s"
L.SHOP_MORE_NEEDED = "Faltan %s Monedas"
L.SHOP_OR_BUY = "O cómpralo por %s"
L.SHOP_MODULE_OFF = "%s está desactivado"
L.SHOP_PICK = "Elige un aspecto para verlo aquí."
L.SHOP_USE = "Usar"
-- The shop's short name: the full one, spaced out, overflows the bill's head.
L.SHOP_BILL_HEAD = "C U R I O S I D A D E S"
L.SHOP_BUY_CONFIRM = "¿Comprar %s?"
L.SHOP_PRICE_LINE = "Precio"
L.SHOP_LEFT_AFTER = "Monedas Pagle restantes"
L.SHOP_FOR_GOOD = "Los aspectos son tuyos para siempre."
L.SHOP_USE_NOW = "Usarlo ya"
L.SHOP_BUY_ACCEPT = "Comprar"
L.SHOP_BUY_CANCEL = "Cancelar"
L.SHOP_HELD = "Tu saldo es 0 mientras Pagle vuelve a contar Monedas anteriores. Las Monedas nuevas cubren eso primero."
L.SHOP_CRATE = "Cofre de curiosidades"
L.SHOP_CRATE_KIND = "Un cofre de aspectos"
L.SHOP_CRATE_TIERS = { "Sencillo", "Fino", "Vivaz", "Vistoso", "Maravilla", "Reliquia", curio = "Curiosidad" }
L.SHOP_CRATE_LEFT = "quedan %d"
L.SHOP_CRATE_PAYS_BACK = "reembolsa %s"
L.SHOP_CRATE_PITY = "Una Curiosidad en %d cofres como mucho"
L.SHOP_CRATE_PITY_ONE = "Una Curiosidad en el próximo cofre"
L.SHOP_CRATE_CONFIRM = "¿Abrir un Cofre de curiosidades?"
L.SHOP_CRATE_FINE = "Un aspecto que aún no tienes, al azar; las probabilidades están en el cofre."
L.SHOP_CRATE_PAYBACK = "+%s Monedas"
L.SHOP_CRATE_BACK = "Volver a la tienda"
L.SHOP_CRATE_NEW_LOOK = "Un aspecto nuevo"
L.SHOP_CRATE_UNSHOWN = "Se mostrará aquí cuando su Módulo esté activado."
L.SHOP_CRATE_KINDS = {
	toaststyle = "Estilo de aviso emergente",
	soundset = "Juego de sonidos",
	binding = "Encuadernación",
	trackerframe = "Marco de rastreador",
	crest = "Blasón",
}
L.SHOP_CRATE_YOURS = "Tuyo"
L.SHOP_CRATE_PAID_BACK = "Reembolsado"
L.SHOP_CRATE_ONLY_NOTE = "Solo en un Cofre de curiosidades, nunca a la venta"
L.SHOP_FROM_CRATE = "De un cofre"
L.SHOP_SONAR_EARNED = "Vincula el Companion"

L.COMPARTMENT_WAITING = "Pagle · %d en espera"
L.MENU_TOOLTIP_WAITING = "%d en espera"
L.MENU_TOOLTIP_LETTER = "Una carta para ti"

L.SLASH_HELP_HEADER = "Comandos de Pagle:"
L.SLASH_SKIPPED_NO_NAME = "Pagle: %s tiene una entrada de /pagle, %s, sin nombre de una palabra; se omite"
L.SLASH_SKIPPED_NO_FN = "Pagle: %s define /pagle %s sin fn; se omite"
L.SLASH_SKIPPED_RESERVED = "Pagle: %s define /pagle %s, que se omite: Pagle reserva %s"
L.SLASH_SKIPPED_TAKEN = "Pagle: %s define /pagle %s, que se omite: %s ya lo usa"
L.DEV_ON = "Pagle dev: los comandos de desarrollo están activados."
L.DEV_OFF = "Pagle dev: los comandos de desarrollo están desactivados."
L.DEV_IS_OFF = "Pagle dev: los comandos de desarrollo están desactivados; /pagle dev on los activa."
L.DEV_USAGE = "Pagle dev: /pagle dev on | off | endsession | preview <tipo> | stage <número> | glyphs"
	.. " | tour [module | list | stop] | probe | onboarding <comando> | content | views | pastetest <KB>"
L.DEV_PASTE_TEST_USAGE = "Pagle dev: /pagle dev pastetest <KB>, de %d a %d; la comprobación copia 64, 128, 256 y 512."
L.DEV_PASTE_TEST_SHOWN =
	"Pagle dev: hay una cadena de prueba de %d KB en la ventana de exportación; cópiala y comprueba su longitud."
L.DEV_CONTENT_STATE = "Pagle dev: el contenido enviado está %s."
L.DEV_CONTENT_ABSENT = "Pagle dev: falta el contenido enviado: %s."
L.DEV_CONTENT_KINDS = "Pagle dev: tipos entregados: %s."
L.DEV_CONTENT_DROPPED = "Pagle dev: tipos descartados por desconocidos: %s."
L.DEV_CONTENT_NONE = "ninguno"
L.DEV_CONTENT_FRAMES =
	"Pagle dev: fotogramas en que corrió la comprobación: %d, el más largo %.2f ms (presupuesto %d ms)."
L.PUSHED_NOT_INSTALLED = "sin archivo (Pagle_Content no está instalado)"
L.PUSHED_NOT_LOADED = "sin archivo (Pagle_Content no se cargó: %s)"
L.PUSHED_NO_DATA = "sin archivo (Pagle_Content se cargó pero no definió PagleContentData)"
L.PUSHED_NOT_TABLE = "PagleContentData no es una tabla"
L.PUSHED_MISSING_FIELD = "falta un campo, %s"
L.PUSHED_NOT_INTEGER = "%s no es un número entero"
L.PUSHED_NOT_STRING = "%s no es una cadena"
L.PUSHED_BAD_KEY_ID = "un keyId que no es de 1 a 32 caracteres de A-Z, a-z, 0-9, _ y -"
L.PUSHED_UNKNOWN_VERSION = "un formato de archivo desconocido, v %s"
L.PUSHED_UNKNOWN_KEY = "un keyId desconocido, %s"
L.PUSHED_NOT_BASE64 = "%s no es Base64 (%s)"
L.PUSHED_OVER_CAP = "por encima del límite de tamaño, %d bytes decodificados de %d como máximo"
L.PUSHED_BAD_SIGNATURE = "una firma no válida (%s)"
L.PUSHED_LOWER_SEQ = "un seq menor, %s, por debajo del último aceptado, %s"
L.PUSHED_EXPIRED = "caducado en %s, y la hora del servidor es %s"
L.PUSHED_PARSE_ERROR = "un error de análisis en el byte %d: %s"
L.PUSHED_CHECK_FAILED = "la propia comprobación falló (mira el error de Lua)"
L.PAYLOAD_EXPECTED = "se esperaba %s"
L.PAYLOAD_EXPECTED_FIELD = "se esperaba un nombre de campo"
L.PAYLOAD_EXPECTED_ITEM = "se esperaba un elemento, una tabla"
L.PAYLOAD_BAD_ITEM = 'un elemento que no empieza por kind = "…", v = <entero>'
L.PAYLOAD_BAD_NAME = "un nombre de campo que no es un nombre"
L.PAYLOAD_UNEXPECTED = "un carácter inesperado, %s"
L.PAYLOAD_NAME_AS_VALUE = "un nombre, %s, donde va un valor"
L.PAYLOAD_NOT_INTEGER = "un número que no es un entero decimal"
L.PAYLOAD_TOO_LARGE = "un entero de más de %s dígitos"
L.PAYLOAD_UNENDED_STRING = "una cadena que no termina"
L.PAYLOAD_LINE_IN_STRING = "un salto de línea dentro de una cadena"
L.PAYLOAD_BAD_ESCAPE = 'un escape distinto de \\\\, \\" o \\n'
L.PAYLOAD_DUPLICATE = "un campo repetido, %s"
L.PAYLOAD_MIXED = "un campo en una lista de valores"
L.PAYLOAD_TOO_DEEP = "tablas anidadas a más de %s niveles"
L.PAYLOAD_ENDED = "la carga termina antes de tiempo"
L.PAYLOAD_AFTER_TABLE = "algo más tras la tabla de la carga"
L.DEV_VIEWS_LIVE = "Pagle dev: %s está activo."
L.DEV_VIEWS_ABSENT = "Pagle dev: %s no está: %s."
L.DEV_VIEWS_EXPIRED = "Pagle dev: %s ha caducado: se generó hace %s s, la edad de caducidad es %s s."
L.DEV_VIEWS_FOLLOWING = "Pagle dev: generatedAt de Pagle_Following %s, Pescadores %s."
L.DEV_VIEWS_ANGLERS = "Pagle dev: generatedAt de Pagle_Anglers %s, bloques %s."
L.DEV_VIEWS_LOADED = "Pagle dev: Pagle_Anglers se ha cargado en esta sesión."
L.DEV_VIEWS_NOT_LOADED = "Pagle dev: Pagle_Anglers no se ha cargado en esta sesión."
L.DEV_VIEWS_NONE = "ninguno"
L.VIEWS_NOT_READ = "aún sin leer (Pagle lo lee al iniciar sesión)"
L.VIEWS_NOT_LOADED_YET = "aún sin cargar (se carga con el primer tooltip de jugador mientras Pagle no está restringido, con el"
	.. " ajuste del tooltip activado)"
L.VIEWS_NOT_INSTALLED = "sin archivo (%s no está instalado)"
L.VIEWS_DID_NOT_LOAD = "sin archivo (%s no se cargó: %s)"
L.VIEWS_NO_DATA = "sin archivo (%s se cargó pero no definió %s)"
L.VIEWS_NOT_TABLE = "%s no es una tabla"
L.VIEWS_NOT_OK = "ok no es true"
L.VIEWS_UNKNOWN_VERSION = "un formato de archivo desconocido, v %s"
L.VIEWS_NOT_NUMBER = "%s no es un número"
L.VIEWS_WRONG_COUNT = "count es %s, pero %s contiene %d"
L.VIEWS_BLOCK_NOT_TABLE = "el bloque %d no es una tabla"
L.VIEWS_BLOCK_NOT_NUMBER = "en el bloque %d, %s no es un número"
L.VIEWS_BLOCK_NOT_TITLES = "en el bloque %d, titles no es una tabla"
L.VIEWS_BLOCK_LENGTH = "en el bloque %d, %s no mide %s bytes"
L.ANGLER_TIP_HEADER = "Pescador de Pagle"
L.ANGLER_TIP_FOLLOWING = "Siguiendo"
L.ANGLER_TIP_LEVEL = "Nivel de Pescador"
L.ANGLER_TIP_PRESTIGE = "%d · %s Prestigio %s"
L.ANGLER_TIP_MASTER_PRESTIGE = "%d · %s Prestigio de Maestro %d"
L.PRESTIGE_FRAME_MASTER = "Maestro"
L.ANGLER_TIP_LEDGER = "Libro de registro"
L.ANGLER_TIP_LEGENDS = "Leyendas"
L.ANGLER_TIP_LEGENDS_VALUE = "%d de %d"
L.ANGLER_TIP_HARDCORE = "Pescador Hardcore"
L.DEV_ONBOARDING_RESET = "Pagle dev: la introducción vuelve a ser la de un Pescador nuevo, con la Carta esperando; haz /reload"
	.. " para empezar desde ahí."
L.DEV_PREVIEW_KINDS = "Pagle dev: /pagle dev preview <tipo>, donde tipo es uno de %s"
L.DEV_PREVIEWING = "Pagle dev: vista previa de %s."
L.DEV_STAGE_SET =
	"Pagle dev: el Cartographer's Folio se dibuja como si %d zonas estuvieran en Maestro, hasta /pagle dev stage off."
L.DEV_STAGE_OFF = "Pagle dev: el Cartographer's Folio se dibuja en su etapa real."
L.DEV_STAGE_IS = "Pagle dev: el Cartographer's Folio se dibuja como si %d zonas estuvieran en Maestro."
L.DEV_STAGE_USAGE = "Pagle dev: /pagle dev stage <número de zonas en Maestro> | off"
L.DEV_CARD_HELD = "Pagle dev: las tarjetas esperan a que acabe el combate; inténtalo entonces."
L.DEV_SAMPLE_TOAST = "Nueva Especie"
L.DEV_SAMPLE_STAMP = "Récord de tamaño"
L.DEV_SAMPLE_NOD = "Nuevo aquí"
L.DEV_SAMPLE_VARIETY = "Variedad rara"
L.DEV_SAMPLE_EPIC = "Variedad épica"
L.DEV_SAMPLE_BANNER = "Nivel de Pescador 12"
L.DEV_SAMPLE_SPLASH = "Una Leyenda"
L.DEV_SAMPLE_TEXT = "Oily Blackmouth (una vista previa de /pagle dev)"
L.DEV_SAMPLE_LINE = "Una línea de resumen de muestra"
L.DEV_SAMPLE_WRITE_UP = "Tu Libro de registro se redactó a partir de 2.340 Lances"
L.DEV_SESSION_ENDED = "Pagle dev: la Sesión terminó, como si hubiera pasado su pausa."
L.DEV_NO_SESSION = "Pagle dev: no hay ninguna Sesión abierta."
L.DEV_NO_CHARACTER = "Pagle dev: aún no hay ningún personaje conectado."
--@do-not-package@
L.DEV_REAL_LOG = "Pagle dev: catch escribe en el Registro de capturas, así que solo funciona en un registro de prueba "
	.. "(PagleLog.test); este registro es real y no se ha añadido nada."
L.DEV_UNKNOWN_AREA = "Pagle dev: %s no es un área del catálogo de Pagle."
L.DEV_CAUGHT = "Pagle dev: objeto %d capturado en la zona %d (entrada %d)."
L.DEV_SKILL_USAGE = "Pagle dev: /pagle dev skill <rango> [máx], de 1 a 300 (máx es 300 por defecto), "
	.. "o /pagle dev skill off"
L.DEV_SKILL_SET = "Pagle dev: la habilidad de Pesca marca ahora %d/%d, diga lo que diga el cliente. Los Lances y las "
	.. "Lecturas de habilidad lo registran. /pagle dev skill off devuelve la del cliente."
L.DEV_SKILL_CLEARED = "Pagle dev: la habilidad de Pesca vuelve a marcar lo que dice el cliente."
L.DEV_SKILL_NOT_SET =
	"Pagle dev: la habilidad de Pesca marca lo que dice el cliente; /pagle dev skill <rango> la sustituye."
L.DEV_SKILL_REMINDER =
	"Pagle dev: la habilidad de Pesca está sustituida por %d/%d (/pagle dev skill off para quitarlo)."
--@end-do-not-package@
L.DEV_GLYPHS_CHAT = "Pagle dev: la prueba de glifos en la fuente del chat: %s"
L.DEV_GLYPHS_SHOWN = "Pagle dev: la misma línea en cada fuente que usa Pagle está en pantalla; un cuadro es un carácter que"
	.. " le falta a esa fuente. Haz clic o pulsa Esc para cerrar."
L.DEV_PROBE_SAVED = "Pagle dev: sonda guardada; haz /reload para escribirla."
L.DEV_TOUR_ONE_STOP = "1 parada"
L.DEV_TOUR_STOPS = "%d paradas"
L.DEV_TOUR_START =
	"Pagle dev: recorriendo %s desde %s; una captura de pantalla de cada una va a la carpeta Screenshots."
L.DEV_TOUR_START_MANUAL = "Pagle dev: recorriendo %s desde %s; este cliente no puede hacer capturas de pantalla, así que pulsa"
	.. " Impr Pant cuando aparezca la línea de cada parada."
L.DEV_TOUR_STOP = "Pagle dev: recorrido %d/%d: %s"
L.DEV_TOUR_DONE = "Pagle dev: el recorrido terminó a las %s."
L.DEV_TOUR_STOPPED = "Pagle dev: el recorrido se detuvo en %d/%d."
L.DEV_TOUR_RESTRICTED_STOPPED = "Pagle dev: el recorrido se detuvo en %d/%d: empezó un combate."
L.DEV_TOUR_STOPPING = "Pagle dev: el recorrido se detiene cuando se oculte esta parada."
L.DEV_TOUR_NOT_RUNNING = "Pagle dev: no hay ningún recorrido en marcha."
L.DEV_TOUR_RUNNING = "Pagle dev: hay un recorrido en marcha; /pagle dev tour stop lo termina."
L.DEV_TOUR_RESTRICTED = "Pagle dev: el recorrido espera a que acabe el combate; inténtalo entonces."
L.DEV_TOUR_NO_STOPS = "Pagle dev: no hay paradas de recorrido registradas."
L.DEV_TOUR_NO_STOPS_FOR = "Pagle dev: no hay paradas para %s; hay paradas registradas para %s."
L.DEV_TOUR_LIST = "Pagle dev: %d paradas del recorrido:"
L.DEV_TOUR_LIST_ONE = "Pagle dev: 1 parada del recorrido:"
L.DEV_TOUR_ANNOUNCE = "un %s de muestra"
L.DEV_TOUR_CARD = "una tarjeta %s de muestra"
L.DEV_TOUR_SHOP = "la Tienda de Curiosidades"
L.DEV_TOUR_FIELD_REPORT = "la ventana del Informe de campo"
L.DEV_TOUR_EXPORT = "la ventana de exportación"
L.DEV_TOUR_GLYPHS = "el panel de prueba de glifos"
L.DEV_TOUR_SETTINGS = "Ajustes: %s"
L.SLASH_CORE_HELP = {
	{ name = "settings", help = "abre los ajustes de Pagle (también /pagle solo)" },
	{ name = "shop", help = "abre o cierra la Tienda de Curiosidades" },
	{ name = "report", help = "abre el Informe de campo, para ayudar a catalogar las aguas" },
	{ name = "export", help = "copia tu Registro de capturas como Cadena de pegado para la web de Pagle" },
	{ name = "recovery", help = "exporta una instantánea de recuperación o revisa los registros conservados" },
	{ name = "guide", help = "abre la Guía de campo; /pagle guide notes vuelve a mostrar las notas al margen" },
	{ name = "help", help = "muestra estos comandos" },
}
L.GUIDE_NOTES_AGAIN = "Pagle: las notas al margen se volverán a mostrar, una vez cada una."
L.NOTE_NOD = "Eso es un *Gesto*: cuando Pagle ha tenido mucho que decir últimamente, las noticias pequeñas se quedan en una"
	.. " línea discreta. Desaparece en tres segundos, y queda en tu Libro de registro para siempre."
L.NOTE_TOAST =
	"La moneda son *Monedas Pagle*: se ganan haciendo cosas, nunca se compran, y se gastan en aspectos en la Tienda de Curiosidades."
L.NOTE_SUMMARY = "Te ausentaste cinco minutos, así que la Sesión se cerró. Todo lo que ganó está aquí, *incluso lo que"
	.. " nunca saltó*."
L.NOTE_UNCHARTED = "Pagle aún no ha catalogado este. Queda guardado, y se te acreditará el día que lo haga. *"
	.. HELP_CHART
	.. "* en el menú de Pagle lo copia, para compartirlo si quieres."
L.NOTE_WELCOME = "Bienvenido de nuevo. */pagle guide* te lo enseña todo, si quieres el recorrido."
L.NOTE_CHARACTER = "El mismo Libro de registro en cada personaje. Solo tu *ropa de pesca* es por personaje."
L.DEV_NOTE_NONE = "Pagle dev: no hay nota al margen %s; las notas son %s."
L.DEV_NOTE_NO_TARGET = "Pagle dev: la nota al margen %s no tiene nada en pantalla a lo que señalar ahora."
L.LOOK_BAR_TITLE = "Primer vistazo · %s"
L.LOOK_BAR_COUNT = "%d notas, se muestran una vez"
L.LOOK_BAR_COUNT_ONE = "1 nota, se muestra una vez"
L.LOOK_BAR_DONE = "Entendido, guarda las notas"
L.LOOK_AGAIN = "Volver a mostrar las notas de esta página"
L.LOOK_SHOP_TITLE = "la Tienda de Curiosidades"
L.LOOK_SHOP_COINS = "Las Monedas solo salen de cosas que has hecho. La barra muestra qué las pagó."
L.LOOK_SHOP_LOOKS =
	"Todo aquí es un *aspecto*: avisos emergentes, sonidos, encuadernaciones, blasones. Nada te hace pescar mejor."
L.LOOK_SHOP_SHOW = "*Mostrar en pantalla* lo reproduce de verdad antes de que compres."
L.LOOK_SHOP_STOCK = "El surtido *nunca rota*. Lo que hay hoy seguirá aquí el mes que viene."
L.DEV_LOOK_NONE = "Pagle dev: no hay Primer vistazo %s; los conjuntos son %s."
L.DEV_LOOK_CLOSED = "Pagle dev: la ventana del Primer vistazo %s no está abierta; ábrela primero."
L.DEV_LOOK_EMPTY = "Pagle dev: el Primer vistazo %s no tiene nada en pantalla a lo que señalar ahora."
L.DEV_TOUR_LOOK = "el Primer vistazo en %s"
L.GUIDE_CRUMB_GUIDE = "Una guía de campo"
L.GUIDE_COUNT = "|cfff6e3a8%d|r de %d"
L.GUIDE_SKIP = "Saltar el resto"
L.GUIDE_NEXT = "Siguiente »"
L.GUIDE_BACK = "« atrás"
L.GUIDE_OFF = "¡Al agua!"
L.GUIDE_AFTER_COMBAT = "Pagle: la Guía de campo se abre tras el combate."
L.GUIDE_SHOW_ME_AROUND = "Enséñamelo todo »"
L.DEV_GUIDE_NO_STEP = "Pagle dev: no hay paso de guía %s; los pasos son %s."
L.DEV_TOUR_GUIDE_STEP = "la Guía de campo en su paso %s"
L.EVENING_TITLE = "Primera tarde"
L.EVENING_COUNT = "%d de %d"
L.EVENING_CAST = "Haz un Lance"
L.EVENING_CAST_HINT = "pulsa tu Tecla de pesca, o doble clic derecho"
L.EVENING_CAST_HINT_NO_QOL = "clic derecho en el agua con Pesca"
L.EVENING_CATCH = "Consigue una Captura"
L.EVENING_JOURNAL = "Abre el Diario de peces"
L.EVENING_JOURNAL_HINT = "Menú de Pagle junto al minimapa » Diario de peces"
L.EVENING_HUNTS = "Mira qué pica en Cazas"
L.EVENING_HUNTS_HINT = "Menú de Pagle » Cazas"
L.EVENING_SESSION = "Termina una Sesión"
L.EVENING_SESSION_HINT = "aléjate 5 minutos para ver tu resumen"
L.EVENING_SHOP = "Echa un vistazo a la Tienda de Curiosidades"
L.EVENING_SHOP_HINT = "Menú de Pagle » Tienda de Curiosidades"
L.DEV_TOUR_EVENING = "la lista de la Primera tarde"
L.GUIDE_RIBBON_WELCOME = "Bienvenida"
L.GUIDE_RIBBON_BOX = "Qué hay en la caja"
L.GUIDE_RIBBON_MOMENTS = "Momentos"
L.GUIDE_RIBBON_OFF = "¡A pescar!"
L.GUIDE_WELCOME_SKIP = "Ya me apaño solo"
L.GUIDE_WELCOME_NEXT = "Enséñamelo todo »"
L.GUIDE_WELCOME_KICKER = "Una carta, dejada en el muelle"
L.GUIDE_WELCOME_TITLE = "Querido Pescador:"
L.GUIDE_WELCOME_RIGHT_KICKER = "Antes que nada"
L.GUIDE_WELCOME_RIGHT_TITLE = "Tres promesas"
L.GUIDE_BOX_KICKER = "El equipo"
L.GUIDE_BOX_TITLE = "Lo que venía en la caja"
L.GUIDE_MOMENTS_KICKER = "Momentos"
L.GUIDE_MOMENTS_TITLE = "Cuando pasa algo bueno"
L.GUIDE_MOMENTS_RIGHT_KICKER = "Tú eliges"
L.GUIDE_MOMENTS_RIGHT_TITLE = "¿Cuánto debe hablar Pagle?"
L.GUIDE_OFF_KICKER = "Eso es todo por ahora"
L.GUIDE_OFF_TITLE = "El resto se aprende pescando"
L.GUIDE_OFF_RIGHT_KICKER = "Tu primera tarde"
L.GUIDE_OFF_RIGHT_TITLE = "Una lista corta, si quieres"
L.GUIDE_OFF_AGAIN = "|cff3e220c/pagle guide|r vuelve a abrir esta guía."
-- Feminine: the pages only ever count partes.
L.GUIDE_COUNT_WORDS = { "ninguna", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez" }
L.GUIDE_LIST_AND = " y "
L.GUIDE_WELCOME_LETTER = {
	"A partir de ahora, cada pez que saques del agua queda anotado: dónde, cuándo, de qué tamaño y lo que costó sacarlo.",
	"Pesca lo suficiente y el agua empieza a contarte cosas: qué pica solo de noche, qué peces se te siguen escapando, cuánto has avanzado.",
	"Deja que te lo enseñe todo. Son dos minutos, y puedes cambiarlo todo más tarde.",
}
L.GUIDE_WELCOME_FOOT = "Todo esto también está en Opciones » Accesorios » Pagle."
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
L.GUIDE_WELCOME_PARTS = "Pagle viene en %s partes. Desactiva cualquiera en la lista de accesorios y no deja rastro."
L.GUIDE_BOX_TEXT =
	"Pagle es un pequeño equipo, no una gran ventana. Cada parte tiene su sitio, y todas se abren desde la entrada |cff3e220cPagle|r bajo el botón de accesorios junto a tu minimapa."
L.GUIDE_BOX_MENU_NOTE = "Haz clic en un nombre para abrirlo. */pagle* abre los Ajustes."
L.GUIDE_BOX_PARTS = "%s partes y una tienda"
L.GUIDE_BOX_PART = "%s parte y una tienda"
L.GUIDE_BOX_SHOP = "Tienda de Curiosidades"
L.GUIDE_BOX_SHOP_BLURB = "Las Monedas Pagle salen de lo que logras, y compran aspectos, nunca poder."
L.GUIDE_BOX_NONE = "Activa partes en la lista de accesorios."
L.GUIDE_MOMENTS_TEXT = "Pagle te avisa, en uno de tres tamaños. Cuanto mayor el momento, mayor la nota."
L.GUIDE_MOMENTS_SAMPLES = {
	nod = { "Un Gesto", "Cuando Pagle ha hablado mucho últimamente. Una línea, que desaparece en 3 segundos." },
	toast = { "Un aviso emergente", "Cada Captura, un pez nuevo, un récord, Monedas ganadas." },
	banner = { "Un estandarte", "Un nuevo Nivel de Pescador y el título que lo acompaña." },
}
L.GUIDE_MOMENTS_BUDGET =
	"Como mucho %d interrupciones cada %d minutos: pasado eso, las pequeñas se quedan en un Gesto. Todo acaba en el Resumen de sesión cuando paras."
L.GUIDE_PRESETS = {
	lively = { "Animado", "Un aviso emergente por cada Captura; estandartes también, con sonido.", "según llega" },
	quieter = {
		"Más tranquilo",
		"Sin aviso emergente para las Capturas normales y menos interrupciones. Los grandes momentos se siguen viendo.",
	},
	cozy = { "Acogedor", "No salta ni suena nada. Todo espera a tu Resumen de sesión." },
}
L.GUIDE_PRESET_POPUPS = "%d interrupciones en %d minutos"
L.GUIDE_PRESET_COZY_WHAT = "una Leyenda sigue mostrándose, en silencio"
L.GUIDE_PRESET_OWN = "Tu propia mezcla, tal como está."
L.GUIDE_MOMENTS_NOTE = "Cada uno solo ajusta los interruptores de Ajustes » Anuncios, donde puedes afinarlos luego."
L.GUIDE_OFF_TEXT =
	"La primera vez que pase algo nuevo (tu primer Gesto, tu primer pez nuevo, tu primer Resumen de sesión) dejaré una nota al lado. Una vez. Después, los márgenes quedan limpios."
L.GUIDE_OFF_NOD_NOTE = "Eso es un *Gesto*: cada Captura tiene uno. Desaparece en tres segundos."
L.GUIDE_OFF_LOOKS =
	"¿No quieres notas? Desactiva las Notas al margen en los Ajustes. %s traen unas notas breves la primera vez que se abren."
L.GUIDE_OFF_LOOKS_ONE =
	"¿No quieres notas? Desactiva las Notas al margen en los Ajustes. %s trae unas notas breves la primera vez que se abre."
L.GUIDE_OFF_LIST_TEXT = "Se coloca bajo tus misiones y se va tachando sola. Ciérrala cuando quieras."
L.GUIDE_EVENING_TITLE = "Primera tarde"
L.GUIDE_EVENING_COUNT = "%d de %d"
L.GUIDE_EVENING_ITEMS = {
	cast = "Haz un Lance",
	catch = "Consigue una Captura",
	journal = "Abre el Diario de peces",
	hunts = "Mira qué pica en Cazas",
	session = "Termina una Sesión",
	shop = "Echa un vistazo a la Tienda de Curiosidades",
}
L.GUIDE_EVENING_HINTS = {
	cast = "pulsa tu Tecla de pesca, o doble clic derecho",
	castNoQoL = "clic derecho en el agua con Pesca",
	session = "aléjate 5 minutos para ver tu resumen",
}

L.LETTER_KICKER = "Una carta, dejada en el muelle"
L.LETTER_LINE = "Pagle ha llegado. Ábrela cuando quieras; puede esperar."
L.LETTER_OPEN = "Abrir la carta"
L.LETTER_LATER = "Más tarde"
L.DEV_TOUR_LETTER = "la Carta"
L.DEV_TOUR_LETTER_OF = "la carta %s"
L.DEV_LETTER_NONE = "Pagle dev: no hay carta %s; las cartas son %s."

L.SLOT_TOAST_STYLE = "Estilo de aviso emergente"
L.SLOT_SOUND_SET = "Juego de sonidos"
L.SLOT_CREST = "Blasones"
L.SLOT_BOOK_BINDING = "Encuadernación"
L.SLOT_CREST_ZONES = "Blasones de zona"
L.SLOT_CREST_FISH = "Blasones de pez"
L.FISH_CREST_ITEM = "Objeto %d"
L.FISH_CREST_ROW = "%d de 10 variedades"
L.FISH_CREST_NOTE = "%d de 10 variedades de %s. Aún por ahí: %s."
L.FISH_CREST_NOTE_ALL = "%d de 10 variedades de %s."
-- Rarity first: "4 Común" doesn't agree, "Común ×4" needs no agreement.
L.FISH_CREST_UNCAUGHT = "%2$s ×%1$d"
-- Short of the glossary's "Aviso emergente": the three preview buttons are sized for one English word.
L.PREVIEW_TOAST = "» Aviso"
L.PREVIEW_BANNER = "» Estandarte"
L.PREVIEW_LEGEND = "» Leyenda"
L.PREVIEW_STING_SHARED = "La sintonía de Leyenda es la misma en todos los juegos."
L.PREVIEW_EX_LIBRIS = "Ex libris"
L.PREVIEW_CREST_NOTE = "En el Ex libris del Diario de peces."
L.PREVIEW_BINDING_NOTE = "Todos tus libros la llevan."
