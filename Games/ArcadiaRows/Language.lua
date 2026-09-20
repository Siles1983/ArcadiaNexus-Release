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
    box_display     = "Anzeige",
    box_rules       = "Regeln",
    opt_instant_drops = "Steine sofort setzen",
    opt_instant_hint  = "|cff888888Ohne Fall-Animation und ohne KI-Denkpause.|r",
    opt_pop_out       = "Pop-out",
    opt_pop_out_hint  = "|cff888888Rechtsklick oder Umschalt+1–7 entfernt den untersten eigenen Stein. Nur gegen die KI, nicht im MATCH.|r",

    -- Anleitung
    guide_1 = "Wirf abwechselnd eine Scheibe in eine Spalte. Sie fällt nach unten.",

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
    guide_5 = "Schwierigkeit der KI wählst du im Spiel vor dem Start. Gegen die KI zählt Best-of-3.",
    guide_6 = "Im Mehrspieler-Tab spielst du gegen einen Menschen (kein KI, keine Serie). Vier in einer Reihe gewinnt.",
    guide_7 = "Gelbe Markierung: du kannst im nächsten Zug gewinnen. Rote Markierung: blocken!",
    guide_8 = "Tasten 1–7 werfen in die entsprechende Spalte (auch Ziffernblock). Die Zahlen stehen unter dem Brett.",
    guide_9 = "Optional: Pop-out (Einstellungen). Rechtsklick oder Umschalt+1–7 nimmt deinen untersten Stein; die anderen fallen nach. Umschalt+Hover zeigt die Vorschau. Nur gegen die KI, nicht im MATCH.",
    guide_10 = "Stellung: Steine liegen schon, du bist am Zug. Schwierigkeit = Gewinn in 1, 2 oder 3 Zügen. Tipp markiert die Schlüsselspalte. Überspringen geht zur nächsten Stellung ohne Niederlage. Gewonnen: nächste Stellung. Verloren: dieselbe nochmal. Kein Best-of-3, kein Pop-out, nicht im MATCH.",

    -- Spielfeld / Renderer
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    result_win      = "Du gewinnst!",
    result_loss     = "Du verlierst!",
    result_draw     = "Unentschieden!",
    result_series_win  = "Serie gewonnen!",
    result_series_loss = "Serie verloren.",
    hud_your_turn   = "Dein Zug",
    hud_ai_turn     = "KI denkt…",
    hud_opp_turn    = "Gegner denkt…",
    hud_series      = "Serie %d : %d",
    hud_win_in      = "Gewinn in %d",
    hud_win_left    = "Noch %d",
    result_puzzle_win  = "Stellung gelöst!",
    result_puzzle_loss = "Nicht gelöst.",
    result_series_bestof = "Best of 3",
    mode_play       = "Partie",
    mode_puzzle     = "Stellung",
    btn_hint        = "Tipp",
    btn_skip        = "Überspringen",
    btn_next_puzzle = "Nächste Stellung",
    btn_retry_puzzle = "Nochmal",
    lb_puzzles         = "Stellung / Extra",
    lb_puzzles_solved  = "Stellungen gelöst",
    lb_pop_wins        = "Pop-out-Siege",

    -- Schwierigkeit / Start
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",
    start_you       = "Du zuerst",
    start_ai        = "KI zuerst",
    start_random    = "Zufall",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("ARCADIAROWS", "enUS", {

    -- Settings-Panel: Box-Titel
    box_symbols     = "Symbols",
    box_sounds      = "Sound",
    box_guide       = "Guide",
    box_display     = "Display",
    box_rules       = "Rules",
    opt_instant_drops = "Place stones instantly",
    opt_instant_hint  = "|cff888888Skips drop animation and AI think delay.|r",
    opt_pop_out       = "Pop-out",
    opt_pop_out_hint  = "|cff888888Right-click or Shift+1–7 removes your bottom disc. AI games only, not MATCH.|r",

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
    guide_5 = "AI difficulty is chosen in the game before start. Versus AI you play best of 3.",
    guide_6 = "On the Multiplayer tab you face another player (no AI, no series). Four in a row wins.",
    guide_7 = "Yellow mark: you can win next drop. Red mark: block it!",
    guide_8 = "Keys 1–7 drop into that column (numpad works too). Numbers sit under the board.",
    guide_9 = "Optional: Pop-out (settings). Right-click or Shift+1–7 removes your bottom disc; the rest fall down. Shift+hover shows a preview. AI games only, not MATCH.",
    guide_10 = "Puzzle: stones are already on the board and you move first. Difficulty is win in 1, 2, or 3 moves. Hint marks the key column. Skip goes to the next puzzle without a loss. Win: next puzzle. Loss: retry the same one. No best of 3, no pop-out, not in MATCH.",

    -- Spielfeld / Renderer
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    result_win      = "You win!",
    result_loss     = "You lose!",
    result_draw     = "Draw!",
    result_series_win  = "You won the series!",
    result_series_loss = "You lost the series.",
    hud_your_turn   = "Your turn",
    hud_ai_turn     = "AI is thinking…",
    hud_opp_turn    = "Opponent is thinking…",
    hud_series      = "Series %d : %d",
    hud_win_in      = "Win in %d",
    hud_win_left    = "%d left",
    result_puzzle_win  = "Puzzle solved!",
    result_puzzle_loss = "Not solved.",
    result_series_bestof = "Best of 3",
    mode_play       = "Game",
    mode_puzzle     = "Puzzle",
    btn_hint        = "Hint",
    btn_skip        = "Skip",
    btn_next_puzzle = "Next puzzle",
    btn_retry_puzzle = "Retry",
    lb_puzzles         = "Puzzles / extra",
    lb_puzzles_solved  = "Puzzles solved",
    lb_pop_wins        = "Pop-out wins",

    -- Difficulty / start
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",
    start_you       = "You first",
    start_ai        = "AI first",
    start_random    = "Random",
})
