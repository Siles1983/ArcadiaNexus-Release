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
    sound_place     = "Zug",
    sound_hint      = "|cff888888Sounds werden nur abgespielt wenn dein Spiel-Sound aktiv ist.|r",

    -- Reset-Button
    btn_reset       = "Reset",

    -- Anleitung
    guide_1 = "Setze abwechselnd ein Symbol. Wer eine Reihe voll hat, gewinnt.",
    guide_2 = "Reihen zählen waagerecht, senkrecht und diagonal.",
    guide_3 = "Spielfeldgröße und Gewinn-Länge wählst du im Spiel.",
    guide_4 = "Standard-Symbole sind X und O. Optional Fraktions-Wappen.",
    guide_5 = "Die KI setzt nach dir, außer du wählst KI zuerst. Unentschieden, wenn das Feld voll ist.",
    guide_6 = "Gegen andere Spieler: Mehrspieler-Tab, zwei Sitze, klassisches 3x3.",
    guide_7 = "Im Spiele-Tab zählt Best of 3. Unentschieden zählen nicht als Sieg.",

    -- Spielfeld-UI
    btn_start       = "Spiel starten",
    btn_new_game    = "Neues Spiel",
    btn_new_game_ov = "Nochmal",
    btn_exit        = "Beenden",
    hint_start      = "|cffaaaaaa Wähle Größe, Gewinnlänge, Starter und Schwierigkeit.|r",
    start_you       = "Du zuerst",
    start_ai        = "KI zuerst",
    start_random    = "Zufall",
    win_3           = "3 in Folge",
    win_4           = "4 in Folge",
    win_5           = "5 in Folge",
    hud_series          = "Serie %d : %d",
    result_series_win   = "Serie gewonnen!",
    result_series_loss  = "Serie verloren.",
    result_series_bestof= "Best of 3",
    btn_next_round      = "Nächste Runde",
    lbl_your_turn   = "Du bist dran",
    lbl_opp_turn    = "Gegner ist dran",
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

    tip_size_title  = "Spielfeld-Größe",
    tip_size        = "Bestimmt, wie viele Felder das Brett hat. 3x3 ist klassisch, größere Felder dauern länger.",
    tip_size_3      = "Klassisches Tic-Tac-Toe auf 9 Feldern.",
    tip_size_4      = "Mehr Platz. Längere Partien, mehr Wege zur Reihe.",
    tip_size_5      = "Großes Brett. Passt gut zu 4 in Folge.",

    tip_win_title   = "Gewinnlänge",
    tip_win         = "So viele gleiche Symbole in einer Reihe (waagerecht, senkrecht oder diagonal) gewinnen. Auf 3x3 immer 3.",
    tip_win_3       = "Drei in einer Reihe. Standard auf 3x3, auf großen Feldern eher leicht.",
    tip_win_4       = "Vier in einer Reihe. Typisch für 5x5.",
    tip_win_5       = "Fünf in einer Reihe. Nur auf 5x5, sehr langwierig.",

    tip_diff_title  = "Schwierigkeit",
    tip_diff        = "Wie stark die KI im Spiele-Tab spielt. Gilt nicht für den Mehrspieler-Tab.",
    tip_diff_easy   = "Setzt fast zufällig. Gut zum Ausprobieren.",
    tip_diff_normal = "Nimmt offene Siege und blockt deine Drohungen.",
    tip_diff_hard   = "Auf 3x3 unbesiegbar. Auf großen Feldern sucht sie Gabeln und Doppeldrohungen.",

    tip_start_title = "Wer beginnt",
    tip_start       = "Wer den ersten Stein setzt. Auf kleinem Feld hat der Startende einen Vorteil.",
    tip_start_you   = "Du setzt zuerst, danach die KI.",
    tip_start_ai    = "Die KI eröffnet nach einer kurzen Denkpause.",
    tip_start_random= "Zufällig du oder die KI.",
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
    sound_place     = "Move",
    sound_hint      = "|cff888888Sounds only play if your in-game sound is active.|r",

    -- Reset-Button
    btn_reset       = "Reset",

    -- Guide
    guide_1 = "Take turns placing a symbol. Complete a line to win.",
    guide_2 = "Lines count horizontally, vertically, and diagonally.",
    guide_3 = "Board size and win length are chosen in the game.",
    guide_4 = "Default symbols are X and O. Faction crests are optional.",
    guide_5 = "The AI moves after you, unless you let it start. A full board without a line is a draw.",
    guide_6 = "Against other players: Multiplayer tab, two seats, classic 3x3.",
    guide_7 = "On the Games tab, play is best of 3. Draws do not count as a win.",

    -- Spielfeld-UI
    btn_start       = "Start Game",
    btn_new_game    = "New Game",
    btn_new_game_ov = "Play Again",
    btn_exit        = "Exit",
    hint_start      = "|cffaaaaaa Choose size, win length, starter, and difficulty.|r",
    start_you       = "You first",
    start_ai        = "AI first",
    start_random    = "Random",
    win_3           = "3 in a row",
    win_4           = "4 in a row",
    win_5           = "5 in a row",
    hud_series          = "Series %d : %d",
    result_series_win   = "You won the series!",
    result_series_loss  = "You lost the series.",
    result_series_bestof= "Best of 3",
    btn_next_round      = "Next round",
    lbl_your_turn   = "Your turn",
    lbl_opp_turn    = "Opponent's turn",
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

    tip_size_title  = "Board size",
    tip_size        = "How many cells the board has. 3x3 is classic; larger boards take longer.",
    tip_size_3      = "Classic Tic-Tac-Toe on 9 cells.",
    tip_size_4      = "More space. Longer games and more paths to a line.",
    tip_size_5      = "Large board. Pairs well with 4 in a row.",

    tip_win_title   = "Win length",
    tip_win         = "How many matching symbols in a line (row, column, or diagonal) win. Always 3 on a 3x3.",
    tip_win_3       = "Three in a row. Default on 3x3; easier on large boards.",
    tip_win_4       = "Four in a row. Typical for 5x5.",
    tip_win_5       = "Five in a row. 5x5 only, and quite long.",

    tip_diff_title  = "Difficulty",
    tip_diff        = "How strong the AI is on the Games tab. Multiplayer ignores this.",
    tip_diff_easy   = "Almost random moves. Good for learning.",
    tip_diff_normal = "Takes open wins and blocks your threats.",
    tip_diff_hard   = "Unbeatable on 3x3. On larger boards it hunts forks and double threats.",

    tip_start_title = "Who starts",
    tip_start       = "Who places the first mark. Going first is an edge on a small board.",
    tip_start_you   = "You move first, then the AI.",
    tip_start_ai    = "The AI opens after a short think delay.",
    tip_start_random= "You or the AI, chosen at random.",
})
