-- PagleSoundBoard / Sets.lua  (PROTOTYPE, throwaway)
-- The candidate sounds. Each set offers a few candidates per weight; the board
-- cycles through them. A candidate plays one of:
--   kit = SoundKit ID              -> PlaySound
--   file = FileDataID or function  -> PlaySoundFile (game's own files, nothing shipped)
--   path = "cc0/x.ogg"             -> PlaySoundFile on a file shipped in sounds/
--   rotate = { path, path, ... }   -> next one each time, so repeats never sound identical
--   layers = { { file=, at=sec } } -> several sounds, offset in time

local _, B = ...

B.WEIGHTS = {
  { key = "toast", label = "Toast" },
  { key = "banner", label = "Banner" },
  { key = "legend", label = "Legend" },
  { key = "recast", label = "Recast cue" },
}

local function factionBell()
  return UnitFactionGroup("player") == "Horde" and 565853 or 566564
end

B.SETS = {
  {
    key = "game",
    label = "Game sounds (Classic)",
    toast = {
      { name = "Shay's Bell", file = 568154 },
      { name = "Flight path found", file = 567497 },
      { name = "Coins (small)", file = 567428 },
      { name = "Map ping", file = 567416 },
      { name = "Page turn", file = 567472 },
      { name = "Ring pick-up", file = 567542 },
    },
    banner = {
      { name = "Quest complete", file = 567439 },
      { name = "Reputation up", file = 568016 },
      { name = "Auction bell", file = 567482 },
      { name = "Tradeskill up (MoP)", file = 642845 },
      { name = "Char level-up (!)", file = 567431 },
    },
    legend = {
      { name = "Faction bell toll", file = factionBell },
      { name = "Night elf bell", file = 566558 },
      { name = "Troll gong", file = 565564 },
      { name = "Boat horn", file = 566652 },
      { name = "Fireworks", layers = { { file = 566643 }, { file = 565731, at = 0.8 }, { file = 566373, at = 1.1 } } },
    },
    recast = {
      { name = "Fishing reel-in", kit = 3407 },
      { name = "Map ping", file = 567416 },
      { name = "Icon pick-up", file = 567489 },
      { name = "Wood pick-up", file = 567576 },
      { name = "Chat emote click", kit = 825 },
    },
  },
  {
    key = "cc0",
    label = "CC0 pack (Kenney)",
    toast = {
      { name = "Confirmation", path = "cc0/toast_confirmation.ogg" },
      { name = "Glass", path = "cc0/toast_glass.ogg" },
      { name = "Pizzicato", path = "cc0/toast_pizzi.ogg" },
      { name = "Steel drum", path = "cc0/toast_steel.ogg" },
    },
    banner = {
      { name = "Pizzicato", path = "cc0/banner_pizzi.ogg" },
      { name = "Steel drum", path = "cc0/banner_steel.ogg" },
      { name = "Hit jingle", path = "cc0/banner_hit.ogg" },
    },
    legend = {
      { name = "Steel, chained", path = "cc0/legend_chained.ogg" },
      { name = "Steel drum", path = "cc0/legend_steel.ogg" },
      { name = "Pizzicato", path = "cc0/legend_pizzi.ogg" },
    },
    recast = {
      { name = "Tick", path = "cc0/recast_tick.ogg" },
      { name = "Drop", path = "cc0/recast_drop.ogg" },
      { name = "Metal latch", path = "cc0/recast_latch.ogg" },
    },
  },
  {
    key = "own",
    label = "Self-made",
    toast = {
      { name = "Wood (3 rotate)", rotate = { "own/toast_wood_1.ogg", "own/toast_wood_2.ogg", "own/toast_wood_3.ogg" } },
      { name = "Bell", path = "own/toast_bell.ogg" },
    },
    banner = {
      { name = "Wood run + bell", path = "own/banner_wood.ogg" },
      { name = "Bells", path = "own/banner_bell.ogg" },
    },
    legend = {
      { name = "Sting", path = "own/legend_sting.ogg" },
      { name = "Sting + motif A", path = "own/legend_signature_a.ogg" },
      { name = "Sting + motif B", path = "own/legend_signature_b.ogg" },
    },
    recast = {
      { name = "Double knock", path = "own/recast_double.ogg" },
      { name = "Single knock", path = "own/recast_single.ogg" },
    },
  },
}

-- Reference sounds to judge against: never Pagle candidates.
B.REFERENCES = {
  { name = "Ref: bobber splash?", file = 569285 },
  { name = "Ref: char level-up", file = 567431 },
}

B.FISHING_IDS = {
  [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true,
  [51294] = true, [88868] = true, [110410] = true, [131474] = true, [131476] = true,
}
