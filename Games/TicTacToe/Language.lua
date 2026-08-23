--[[
    Gaming Hub
    Games/TicTacToe/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer TicTacToe.
    Aktive Sprache wird automatisch via ArcadiaNexus.ActiveLocale gewählt (deDE / enUS).
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("TICTACTOE")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("TICTACTOE", "deDE", {

    -- Settings-Panel: Box-Titel
    box_symbols     = "Symbole",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: Symbole
    sym_auto        = "Automatisch erkennen (Fraktion)",
    sym_set_label   = "Symbol-Set:",
    sym_standard    = "Standard (X und O)",
    sym_faction     = "Fraktions-Wappen",
    sym_player_label= "Mein Symbol:",
    sym_alliance    = "Allianz-Wappen",
    sym_horde       = "Horde-Wappen",
    sym_hint        = "|cff888888Symbole gelten nur für dich.|r",

    -- Settings-Panel: Hintergrund
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

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_win       = "Sieg",
    sound_loss      = "Niederlage",
    sound_draw      = "Unentschieden",
    sound_hint      = "|cff888888Sounds werden nur abgespielt wenn dein Spiel-Sound aktiv ist.|r",

    -- Reset-Button
    btn_reset       = "Reset",

    -- Anleitung
    guide_1 = "Setze abwechselnd ein Symbol. Wer eine Reihe voll hat, gewinnt.",
    guide_2 = "Reihen zählen waagerecht, senkrecht und diagonal.",
    guide_3 = "Spielfeldgröße und Gewinn-Länge wählst du im Spiel.",
    guide_4 = "Standard-Symbole sind X und O. Optional Fraktions-Wappen.",
    guide_5 = "Die KI setzt nach dir. Unentschieden, wenn das Feld voll ist.",

    -- Spielfeld-UI
    btn_start       = "Spiel starten",
    btn_new_game    = "Neues Spiel",
    btn_new_game_ov = "Nochmal",
    btn_exit        = "Beenden",
    hint_start      = "|cffaaaaaa Wähle Grid-Größe und Schwierigkeit, dann starte das Spiel.|r",
    lbl_your_turn   = "Du bist dran",
    lbl_ai_turn     = "KI denkt nach...",
    lbl_win         = "Sieg!",
    lbl_loss        = "Niederlage!",
    lbl_draw        = "Unentschieden!",
    lbl_board_size  = "Spielfeld-Größe:",
    lbl_win_length  = "Gewinn-Länge:",
    lbl_difficulty  = "Schwierigkeit:",
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",
    size_3x3        = "3 x 3",
    size_4x4        = "4 x 4",
    size_5x5        = "5 x 5",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback für alle anderen Clients
-- ============================================================
ArcadiaNexus.RegisterLocale("TICTACTOE", "enUS", {

    -- Settings-Panel: Box-Titel
    box_symbols     = "Symbols",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Settings-Panel: Symbole
    sym_auto        = "Auto-detect (Faction)",
    sym_set_label   = "Symbol set:",
    sym_standard    = "Standard (X and O)",
    sym_faction     = "Faction crests",
    sym_player_label= "My symbol:",
    sym_alliance    = "Alliance crest",
    sym_horde       = "Horde crest",
    sym_hint        = "|cff888888Symbols only apply to you.|r",

    -- Settings-Panel: Hintergrund
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

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds enabled",
    sound_win       = "Victory",
    sound_loss      = "Defeat",
    sound_draw      = "Draw",
    sound_hint      = "|cff888888Sounds only play if your in-game sound is active.|r",

    -- Reset-Button
    btn_reset       = "Reset",

    -- Guide
    guide_1 = "Take turns placing a symbol. Complete a line to win.",
    guide_2 = "Lines count horizontally, vertically, and diagonally.",
    guide_3 = "Board size and win length are chosen in the game.",
    guide_4 = "Default symbols are X and O. Faction crests are optional.",
    guide_5 = "The AI moves after you. A full board without a line is a draw.",

    -- Spielfeld-UI
    btn_start       = "Start Game",
    btn_new_game    = "New Game",
    btn_new_game_ov = "Play Again",
    btn_exit        = "Exit",
    hint_start      = "|cffaaaaaa Choose grid size and difficulty, then start the game.|r",
    lbl_your_turn   = "Your turn",
    lbl_ai_turn     = "AI is thinking...",
    lbl_win         = "Victory!",
    lbl_loss        = "Defeat!",
    lbl_draw        = "Draw!",
    lbl_board_size  = "Board size:",
    lbl_win_length  = "Win length:",
    lbl_difficulty  = "Difficulty:",
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",
    size_3x3        = "3 x 3",
    size_4x4        = "4 x 4",
    size_5x5        = "5 x 5",
})
