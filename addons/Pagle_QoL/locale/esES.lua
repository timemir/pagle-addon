if not Pagle then -- luacheck: read globals Pagle
	return
end

if not GetLocale or GetLocale() ~= "esES" then
	return
end

-- QoL's Spanish (Spain) strings, over the enUS table.
local ns = select(2, ...)
local L = ns.L

L.TITLE = "Comodidades"
-- EN: QoL
L.SETTINGS_ACTION = "Ajustes de pesca »"
-- EN: Fishing settings »
L.BINDING_FISHING_KEY = "Pagle: Tecla de pesca"
-- EN: Pagle: Fishing key
L.SETTINGS_CASTING = "Lances"
-- EN: Casting
L.SETTINGS_CAST_WITH = "Lanzar con"
-- EN: Cast with
L.SETTINGS_CAST_WITH_TOOLTIP = "También en el menú del compartimento y con /pagle qol input."
-- EN: Also on the compartment menu and /pagle qol input.
L.SETTINGS_CAST_WITH_KEY = "Tecla de pesca"
-- EN: Fishing key
L.SETTINGS_CAST_WITH_CLICK = "Doble clic derecho"
-- EN: Double right-click
L.SETTINGS_CAST_WITH_BOTH = "Ambos"
-- EN: Both
L.SETTINGS_FISHING_KEY = "Tecla de pesca"
-- EN: Fishing key
L.SETTINGS_FISHING_KEY_TOOLTIP =
	"Cada pulsación hace lo siguiente que toca: lanzar, recoger, o un señuelo, equipo o almeja cuando haga falta."
-- EN: Each press does the next single thing: cast, reel, or a lure, gear or clam when needed.
L.SETTINGS_LURES_AND_CLAMS = "Señuelos y almejas"
-- EN: Lures and clams
L.SETTINGS_LURES = "Señuelos"
-- EN: Lures
L.SETTINGS_LURES_TOOLTIP = "Una pulsación antes de lanzar pone un señuelo si no hay ninguno."
-- EN: A press before a cast applies a lure when none is on.
L.SETTINGS_LURES_OFF = "Desactivado"
-- EN: Off
L.SETTINGS_LURES_BEST = "El mejor que tenga"
-- EN: Best I have
L.SETTINGS_LURES_ONE = "Solo este"
-- EN: Only this one
L.SETTINGS_LURE = "Señuelo"
-- EN: Lure
L.SETTINGS_LURE_UNNAMED = "Objeto %d"
-- EN: Item %d
L.SETTINGS_CLAMS = "Abrir almejas entre Lances"
-- EN: Open clams between Casts
L.SETTINGS_CLAMS_TOOLTIP = "Una almeja por pulsación, nunca durante un lance."
-- EN: One clam per press, never during a cast.
L.SETTINGS_WHILE_YOU_FISH = "Mientras pescas"
-- EN: While you fish
L.SETTINGS_AUDIO_MIX = "Mezcla de sonido para pescar"
-- EN: Fishing audio mix
L.SETTINGS_AUDIO_MIX_TOOLTIP =
	"Mientras pescas: efectos al máximo; música, ambiente y diálogos en silencio; volumen general intacto. Todo vuelve a su sitio al acabar."
-- EN: While you fish: effects at full; music, ambience and dialog muted; master untouched. Put back afterwards.
L.SETTINGS_BACKGROUND_SOUND = "Mantener el sonido con el juego en segundo plano"
-- EN: Keep sound when the game is in the background
L.SETTINGS_AUTO_LOOT = "Despojo automático al pescar"
-- EN: Auto-loot while fishing
L.SETTINGS_AUTO_LOOT_TOOLTIP = "Solo mientras pescas. No hace nada si ya tienes el despojo automático activado."
-- EN: Only while you fish. Skipped if you already have auto-loot on.
L.MENU_INPUT = "Entrada: %s"
-- EN: Input: %s
L.INPUT_KEY = "Tecla de pesca"
-- EN: Fishing key
L.INPUT_CLICK = "Doble clic"
-- EN: Double-click
L.INPUT_BOTH = "Ambos"
-- EN: Both
L.SLASH_HELP = "input key|click|both: elige cómo lanzas"
-- EN: input key|click|both: choose how you cast
L.INPUT_SET_KEY = "Pagle: lanzas con la Tecla de pesca."
-- EN: Pagle: cast with the Fishing key.
L.INPUT_SET_CLICK = "Pagle: lanzas con doble clic derecho."
-- EN: Pagle: cast with a double right-click.
L.INPUT_SET_BOTH = "Pagle: lanzas con la Tecla de pesca o con doble clic derecho."
-- EN: Pagle: cast with the Fishing key or a double right-click.
L.CONFLICT_TEXT = "Dos addons quieren tu tecla de pesca."
-- EN: Two addons want your fishing key.
L.CONFLICT_USE_PAGLE = "Usar Pagle"
-- EN: Use Pagle
L.CONFLICT_USE_OTHER = "Usar %s"
-- EN: Use %s
L.CONFLICT_USE_OTHERS = "Usar los otros"
-- EN: Use the others
L.CONFLICT_TURNED_OFF = "Pagle: %s desactivado. Escribe /reload para terminar."
-- EN: Pagle: turned off %s. Type /reload to finish.
L.CONFLICT_TURNED_OFF_QOL =
	"Pagle: Pagle QoL desactivado. Escribe /reload para terminar. Pagle sigue registrando tus Capturas."
-- EN: Pagle: turned off Pagle QoL. Type /reload to finish. Pagle keeps recording your Catches.
L.CONFLICT_RELOAD_TEXT = "¿Recargar la interfaz ahora para terminar?"
-- EN: Reload the interface now to finish?
L.CONFLICT_RELOAD_NOW = "Recargar ahora"
-- EN: Reload now
L.CONFLICT_RELOAD_LATER = "Más tarde"
-- EN: Later
L.NUDGE_OUT_OF_LURES = "Se te ha acabado el señuelo y no te queda ninguno en las bolsas."
-- EN: Your lure is gone and there are none left in your bags.
L.NUDGE_OUT_OF_LURE = "Se te ha acabado el señuelo y no te queda %s en las bolsas."
-- EN: Your lure is gone and there's no %s left in your bags.
L.BINDING_SWAP_GEAR = "Pagle: Cambiar equipo"
-- EN: Pagle: Swap gear
L.SETTINGS_GEAR = "Equipo"
-- EN: Gear
L.SETTINGS_FISHING_SET = "Conjunto de pesca"
-- EN: Fishing set
L.SETTINGS_FISHING_SET_TOOLTIP =
	"La Tecla de pesca te lo pone si no llevas caña en la mano. El doble clic se lo salta."
-- EN: The Fishing key puts it on when no pole is in hand. Double-click skips this.
L.SETTINGS_FISHING_SET_NONE = "Ninguno (el equipo se queda como está)"
-- EN: None (gear stays as it is)
L.SETTINGS_SAVE_FISHING_SET = "Guardar lo que llevo como conjunto de pesca"
-- EN: Save what I'm wearing as my fishing set
L.SETTINGS_SWAP_GEAR = "Cambiar equipo"
-- EN: Swap gear
L.SETTINGS_SWAP_GEAR_TOOLTIP =
	"Alterna entre tu conjunto de pesca y lo que llevabas antes (guardado como Pagle Previous)."
-- EN: Swaps between your fishing set and what you wore before (saved as Pagle Previous).
L.GEAR_NEEDS_SLOT = "Pagle: hace falta un hueco libre de conjunto de equipo para %s."
-- EN: Pagle: needs a free equipment set slot for %s.
L.GEAR_NEEDS_TWO_SLOTS = "Pagle: hacen falta dos huecos libres de conjunto de equipo para %s y %s."
-- EN: Pagle: needs two free equipment set slots for %s and %s.
L.NUDGE_SWAP_BACK = "Sigues con la caña en la mano. Pulsa %s para volver a cambiarte."
-- EN: Still holding your pole. Press %s to swap back.
L.NUDGE_SWAP_BACK_UNBOUND = "Sigues con la caña en la mano. Asigna %s para cambiarte de una pulsación."
-- EN: Still holding your pole. Bind %s to swap back in one press.
L.BUTTON_CAST = "Lanzar"
-- EN: Cast
L.BUTTON_REEL = "Recoger"
-- EN: Reel
L.BUTTON_GEAR = "Equipo"
-- EN: Gear
L.BUTTON_LURE = "Señuelo"
-- EN: Lure
L.BUTTON_CLAM = "Almeja"
-- EN: Clam
L.BUTTON_TOOLTIP_CAST = "Lanzar"
-- EN: Cast
L.BUTTON_TOOLTIP_REEL = "Recoger"
-- EN: Reel in
L.BUTTON_TOOLTIP_GEAR = "Ponerse %s"
-- EN: Put on %s
L.BUTTON_TOOLTIP_LURE = "Aplicar %s"
-- EN: Apply %s
L.BUTTON_TOOLTIP_CLAM = "Abrir %s"
-- EN: Open %s
L.BUTTON_TOOLTIP_NOTHING = "Nada que hacer"
-- EN: Nothing to do
L.SETTINGS_SHOW_BUTTON = "Mostrar el botón de siguiente acción"
-- EN: Show the next-action button
L.SETTINGS_SHOW_BUTTON_TOOLTIP = "Muestra qué hará tu próxima pulsación. Mayús y arrastrar para moverlo."
-- EN: Shows what your next press will do. Shift-drag to move.
L.SETTINGS_BUTTON_POSITION = "Posición del botón"
-- EN: Button position
L.SETTINGS_BUTTON_RESET = "Restablecer"
-- EN: Reset
L.GUIDE_BLURB = "La Tecla de pesca, tu ropa de pescar, señuelos y almejas: una pulsación, una acción."
-- EN: The Fishing key, your fishing clothes, lures and clams: one press, one action.
L.GUIDE_CASTING_RIBBON = "Lances"
-- EN: Casting
L.GUIDE_CASTING_KICKER = "Lances"
-- EN: Casting
L.GUIDE_CASTING_TITLE = "Una tecla para todo el lance"
-- EN: One key for the whole cast
L.GUIDE_CASTING_BODY =
	"Pulsa la Tecla de pesca y Pagle hace lo siguiente que toca, y luego espera a tu próxima pulsación. Nunca hace dos cosas a la vez, y nunca hace nada por su cuenta."
-- EN: Press the Fishing key and Pagle does the one next thing, then waits for your next press. It never does two things at once, and it never does anything on its own.
L.GUIDE_CASTING_GEAR = "te pones la ropa de pescar"
-- EN: your fishing clothes go on
L.GUIDE_CASTING_LURE = "el mejor señuelo que tengas"
-- EN: the best lure you have
L.GUIDE_CASTING_CAST = "y al agua"
-- EN: out it goes
L.GUIDE_CASTING_REEL = "cuando el corcho se hunde"
-- EN: when the bobber dips
L.GUIDE_CASTING_SMALL =
	"Los pasos que no hacen falta se saltan: sin ropa de pescar guardada, no hay paso de equipo; con un señuelo ya puesto, no hay paso de señuelo. Un botoncito junto al agua muestra qué hará tu próxima pulsación."
-- EN: Steps you don’t need are passed over: no fishing clothes saved, no gear step; a lure already on, no lure step. A small button by the water shows what your next press will do.
L.GUIDE_CASTING_NOTE = "Un *doble clic derecho* en el agua también lanza y recoge, pero nunca te cambia la ropa."
-- EN: A *double right-click* on the water casts and reels too, but never changes your clothes.
L.GUIDE_CHOICE_KICKER = "Tú eliges"
-- EN: Your choice
L.GUIDE_CHOICE_TITLE = "¿Cómo quieres lanzar?"
-- EN: How would you like to cast?
L.GUIDE_CARD_KEY = "La Tecla de pesca"
-- EN: The Fishing key
L.GUIDE_CARD_KEY_LINE = "Una tecla hace lo siguiente, ropa y señuelos incluidos."
-- EN: One key does the next thing, clothes and lures included.
L.GUIDE_CARD_CLICK = "Doble clic derecho"
-- EN: Double right-click
L.GUIDE_CARD_CLICK_LINE = "Clic derecho dos veces, como siempre. Sin ceder ninguna tecla."
-- EN: Right-click twice, as you would anyway. No key to give up.
L.GUIDE_CARD_BOTH = "Ambos"
-- EN: Both
L.GUIDE_CARD_BOTH_LINE = "La tecla cuando quieras, el ratón cuando no."
-- EN: The key when you want it, the mouse when you don’t.
L.GUIDE_CARD_BOTH_TAG = "lo habitual"
-- EN: the usual
L.GUIDE_RESTING =
	"La Tecla de pesca de Pagle descansa mientras la tenga %s. Puedes seguir lanzando con doble clic derecho."
-- EN: Pagle’s Fishing key is resting while %s has it. You can still cast with a double right-click.
L.GUIDE_CLOTHES_RIBBON = "Ropa de pescar"
-- EN: Fishing clothes
L.GUIDE_CLOTHES_SKIP = "No tengo ropa de pescar"
-- EN: I don’t keep fishing clothes
L.GUIDE_CLOTHES_KICKER = "Ropa de pescar"
-- EN: Fishing clothes
L.GUIDE_CLOTHES_TITLE = "Tu sombrero, tu caña"
-- EN: Your hat, your pole
L.GUIDE_CLOTHES_BODY =
	"Si tienes un atuendo de pesca, Pagle puede ponértelo: la primera pulsación de la Tecla de pesca junto al agua te cambia la ropa, y lo que llevabas se guarda, listo para volver a ponértelo."
-- EN: If you keep a fishing outfit, Pagle can put it on for you: the Fishing key’s first press at the water changes your clothes, and what you were wearing is kept, ready to put back.
L.GUIDE_CLOTHES_PREVIOUS = "lo que llevabas antes"
-- EN: what you wore before
L.GUIDE_CLOTHES_FISHING = "tu ropa de pescar"
-- EN: your fishing clothes
L.GUIDE_CLOTHES_ONE_KEY = "una tecla"
-- EN: one key
L.GUIDE_CLOTHES_SMALL =
	"Los dos son conjuntos de equipo normales, así que también los verás en tu hoja de personaje. Si te alejas con la caña aún en la mano, una notita te recuerda cómo volver a cambiarte. Pagle nunca te cambia la ropa sin una pulsación."
-- EN: Both are ordinary equipment sets, so you’ll see them in your character sheet too. When you walk away with your pole still in hand, a small note reminds you how to change back. Pagle never changes your clothes without a press.
L.GUIDE_SAVE_KICKER = "Si tienes un atuendo de pesca"
-- EN: If you have a fishing outfit
L.GUIDE_SAVE_TITLE = "Póntelo y guárdalo"
-- EN: Put it on, then save it
L.GUIDE_SAVE_SMALL =
	"Ponte ahora el sombrero, los guantes y la caña, y pulsa el botón. Puedes hacerlo luego desde Ajustes » Pesca."
-- EN: Wear your fishing hat, gloves and pole now, then press the button. You can do this later from Settings » Fishing.
L.GUIDE_SAVE = "Guardar lo que llevo como conjunto de pesca"
-- EN: Save what I’m wearing as my fishing set
L.GUIDE_SAVE_OR = "o usa un conjunto que ya tengas"
-- EN: or use a set you made
L.GUIDE_SAVE_SLOTS =
	"Hacen falta dos huecos libres de conjunto de equipo: uno para tu ropa de pescar y otro para Pagle Previous."
-- EN: Needs two free equipment set slots: one for your fishing clothes and one for Pagle Previous.
L.GUIDE_NUDGE_KICKER = "Si te vas aún vestido para pescar"
-- EN: If you walk off still dressed for it
L.NOTE_LURE =
	"Tu caña no tiene señuelo. Tu próxima pulsación le pone el mejor de tus bolsas. |cff9a2a1aSolo eso|r; luego lanzas."
-- EN: Your pole has no lure on. Your next press puts the best one in your bags on. |cff9a2a1aOnly that|r; then you cast.
