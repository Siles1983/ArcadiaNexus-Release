--[[
    Gaming Hub
    Games/ArcadiaRows/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Vier Gewinnt.
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("ARCADIAROWS")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("ARCADIAROWS", "deDE", {

    -- Settings-Panel: Box-Titel
    box_symbols     = "Symbole",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Symbole
    sym_auto        = "Automatisch erkennen (Fraktion)",
    sym_set_label   = "Symbol-Set:",
    sym_standard    = "Standard",
    sym_faction     = "Fraktions-Wappen",
    sym_player_label= "Mein Symbol:",
    sym_alliance    = "Allianz-Wappen",
    sym_horde       = "Horde-Wappen",
    sym_hint        = "|cff888888Im Standard-Modus: Spieler = Gelb, KI = Rot. Wappen werden rund dargestellt.|r",

    -- Hintergrund
    bg_type_label   = "Hintergrund-Typ:",
    bg_neutral      = "Neutral (Standard)",
    bg_faction      = "Fraktion",
    bg_class        = "Klasse",
    bg_race         = "Rasse",
    bg_auto         = "Automatisch erkennen",
    bg_faction_label= "Fraktion:",
    bg_class_label  = "Klasse:",
    bg_race_label   = "Rasse:",

    -- Klassen
    class_warrior   = "Krieger",
    class_paladin   = "Paladin",
    class_hunter    = "Jäger",
    class_rogue     = "Schurke",
    class_priest    = "Priester",
    class_shaman    = "Schamane",
    class_mage      = "Magier",
    class_warlock   = "Hexenmeister",
    class_monk      = "Mönch",
    class_druid     = "Druide",
    class_dh        = "Dämonenjäger",
    class_dk        = "Todesritter",
    class_evoker    = "Rufer",

    -- Völker
    race_human      = "Mensch",
    race_dwarf      = "Zwerg",
    race_nightelf   = "Nachtelf",
    race_gnome      = "Gnom",
    race_draenei    = "Draenei",
    race_worgen     = "Worgen",
    race_pandaren_a = "Pandaren (A)",
    race_orc        = "Ork",
    race_undead     = "Untoter",
    race_tauren     = "Tauren",
    race_troll      = "Troll",
    race_bloodelf   = "Blutelf",
    race_goblin     = "Goblin",
    race_pandaren_h = "Pandaren (H)",
    race_dracthyr   = "Dracthyr",

    -- Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_win       = "Sieg",
    sound_loss      = "Niederlage",
    sound_draw      = "Unentschieden",
    sound_hint      = "|cff888888Sounds werden nur abgespielt wenn dein Spiel-Sound aktiv ist.|r",

    -- Reset
    btn_reset       = "Reset",

    -- Anleitung
    guide_1 = "Wirf abwechselnd eine Scheibe in eine Spalte. Sie fällt nach unten.",
    guide_2 = "Wer zuerst vier gleiche Scheiben in einer Reihe hat, gewinnt.",
    guide_3 = "Reihen zählen waagerecht, senkrecht und diagonal.",
    guide_4 = "Standard: du = Gelb, KI = Rot. Optional Fraktions-Wappen.",
    guide_5 = "Schwierigkeit der KI wählst du im Spiel vor dem Start.",

    -- Spielfeld / Renderer
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    result_win      = "Du gewinnst!",
    result_loss     = "Du verlierst!",
    result_draw     = "Unentschieden!",

    -- Schwierigkeit
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("ARCADIAROWS", "enUS", {

    -- Settings-Panel: Box-Titel
    box_symbols     = "Symbols",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Symbole
    sym_auto        = "Auto-detect (Faction)",
    sym_set_label   = "Symbol set:",
    sym_standard    = "Standard",
    sym_faction     = "Faction crests",
    sym_player_label= "My symbol:",
    sym_alliance    = "Alliance crest",
    sym_horde       = "Horde crest",
    sym_hint        = "|cff888888Standard mode: Player = Yellow, AI = Red. Crests are shown as circles.|r",

    -- Hintergrund
    bg_type_label   = "Background type:",
    bg_neutral      = "Neutral (default)",
    bg_faction      = "Faction",
    bg_class        = "Class",
    bg_race         = "Race",
    bg_auto         = "Auto-detect",
    bg_faction_label= "Faction:",
    bg_class_label  = "Class:",
    bg_race_label   = "Race:",

    -- Classes
    class_warrior   = "Warrior",
    class_paladin   = "Paladin",
    class_hunter    = "Hunter",
    class_rogue     = "Rogue",
    class_priest    = "Priest",
    class_shaman    = "Shaman",
    class_mage      = "Mage",
    class_warlock   = "Warlock",
    class_monk      = "Monk",
    class_druid     = "Druid",
    class_dh        = "Demon Hunter",
    class_dk        = "Death Knight",
    class_evoker    = "Evoker",

    -- Races
    race_human      = "Human",
    race_dwarf      = "Dwarf",
    race_nightelf   = "Night Elf",
    race_gnome      = "Gnome",
    race_draenei    = "Draenei",
    race_worgen     = "Worgen",
    race_pandaren_a = "Pandaren (A)",
    race_orc        = "Orc",
    race_undead     = "Undead",
    race_tauren     = "Tauren",
    race_troll      = "Troll",
    race_bloodelf   = "Blood Elf",
    race_goblin     = "Goblin",
    race_pandaren_h = "Pandaren (H)",
    race_dracthyr   = "Dracthyr",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_win       = "Victory",
    sound_loss      = "Defeat",
    sound_draw      = "Draw",
    sound_hint      = "|cff888888Sounds only play if your in-game sound is active.|r",

    -- Reset
    btn_reset       = "Reset",

    -- Guide
    guide_1 = "Drop a disc into a column. It falls to the lowest empty slot.",
    guide_2 = "Get four discs in a row to win.",
    guide_3 = "Rows count horizontally, vertically, and diagonally.",
    guide_4 = "Default: you = yellow, AI = red. Faction crests are optional.",
    guide_5 = "AI difficulty is chosen in the game before start.",

    -- Spielfeld / Renderer
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    result_win      = "You win!",
    result_loss     = "You lose!",
    result_draw     = "Draw!",

    -- Schwierigkeit
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",
})
