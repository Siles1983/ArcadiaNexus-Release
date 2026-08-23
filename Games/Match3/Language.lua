-- ============================================================
--  Match3 – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "MATCH3"
-- ============================================================

ArcadiaNexus.RegisterLocale("MATCH3", "deDE", {
    game_title          = "Match-3",

    -- HUD
    lbl_score           = "Punkte",
    lbl_moves           = "Züge",
    lbl_time            = "Zeit",
    lbl_highscore       = "Highscore",

    -- Buttons
    btn_start           = "Spiel starten",
    btn_new_game        = "Neues Spiel",
    btn_exit            = "Beenden",

    -- Zustände
    state_idle          = "Schwierigkeit wählen",
    state_gameover_win  = "Gewonnen!",
    state_gameover_loss = "Keine Züge mehr!",
    state_timeout       = "Zeit abgelaufen!",
    hint_select         = "Klicke ein Icon zum Auswählen",
    hint_swap           = "Klicke ein benachbartes Icon zum Tauschen",
    hint_invalid        = "Kein Match! Tausch rückgängig.",
    hint_shuffle        = "Keine Züge möglich – Board wird gemischt...",

    -- Schwierigkeiten
    diff_easy           = "Einfach",
    diff_normal         = "Normal",
    diff_hard           = "Schwer",
    diff_easy_detail    = "8x8 · 20 Züge",
    diff_normal_detail  = "10x10 · 15 Züge",
    diff_hard_detail    = "12x12 · 10 Züge",

    -- Timer
    lbl_timer_on        = "Timer",
    timer_easy          = "10:00",
    timer_normal        = "7:30",
    timer_hard          = "5:00",

    -- Combo
    combo_prefix        = "Kombo x",

    -- Game Over Popup
    popup_score         = "Punkte:",
    popup_play_again    = "Nochmal",
    popup_exit          = "Beenden",

    -- Settings Panel
    box_difficulty      = "Schwierigkeit & Timer",
    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Anleitung",
    lbl_timer_check     = "Timer aktivieren",
    lbl_theme_prev      = "Vorschau:",

    -- Themes
    theme_raidmarker    = "Raid-Marker",
    theme_professions   = "Berufe",
    theme_resources     = "Ressourcen",
    theme_abilities     = "Fähigkeiten",
    theme_classic       = "Klassisch",

    -- Sound
    sound_enabled       = "Sound aktiviert",
    sound_match         = "Match-Sound",
    sound_move          = "Zug-Sound",
    sound_combo         = "Combo-Sound",
    sound_gameover      = "Spiel-Ende-Sound",

    -- Spielanleitung
    guide_1             = "Ziel: Kombiniere 3 oder mehr gleiche Icons in einer Reihe oder Spalte.",
    guide_2             = "Steuerung: Icon anklicken zum Wählen, Nachbar anklicken zum Tauschen.",
    guide_3             = "Tausch ist nur gültig wenn er mindestens ein Match erzeugt.",
    guide_4             = "Nach einem Match fallen Icons nach unten, neue erscheinen oben.",
    guide_5             = "Kaskaden (automatische Ketten) erhöhen den Combo-Multiplikator.",
    guide_6             = "Einfach: 8x8, 20 Züge · Normal: 10x10, 15 Züge · Schwer: 12x12, 10 Züge",

    -- Score / Reset
    btn_reset           = "Reset",
})

ArcadiaNexus.RegisterLocale("MATCH3", "enUS", {
    game_title          = "Match-3",

    -- HUD
    lbl_score           = "Score",
    lbl_moves           = "Moves",
    lbl_time            = "Time",
    lbl_highscore       = "Highscore",

    -- Buttons
    btn_start           = "Start Game",
    btn_new_game        = "New Game",
    btn_exit            = "Exit",

    -- States
    state_idle          = "Choose a difficulty",
    state_gameover_win  = "You Win!",
    state_gameover_loss = "No Moves Left!",
    state_timeout       = "Time's Up!",
    hint_select         = "Click an icon to select",
    hint_swap           = "Click an adjacent icon to swap",
    hint_invalid        = "No match! Swap undone.",
    hint_shuffle        = "No moves available – shuffling board...",

    -- Difficulties
    diff_easy           = "Easy",
    diff_normal         = "Normal",
    diff_hard           = "Hard",
    diff_easy_detail    = "8x8 · 20 moves",
    diff_normal_detail  = "10x10 · 15 moves",
    diff_hard_detail    = "12x12 · 10 moves",

    -- Timer
    lbl_timer_on        = "Timer",
    timer_easy          = "10:00",
    timer_normal        = "7:30",
    timer_hard          = "5:00",

    -- Combo
    combo_prefix        = "Combo x",

    -- Game Over Popup
    popup_score         = "Score:",
    popup_play_again    = "Play Again",
    popup_exit          = "Exit",

    -- Settings Panel
    box_difficulty      = "Difficulty & Timer",
    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Guide",
    lbl_timer_check     = "Enable Timer",
    lbl_theme_prev      = "Preview:",

    -- Themes
    theme_raidmarker    = "Raid Markers",
    theme_professions   = "Professions",
    theme_resources     = "Resources",
    theme_abilities     = "Abilities",
    theme_classic       = "Classic",

    -- Sound
    sound_enabled       = "Sound enabled",
    sound_match         = "Match sound",
    sound_move          = "Move sound",
    sound_combo         = "Combo sound",
    sound_gameover      = "Game over sound",

    -- How to Play
    guide_1             = "Goal: Match 3 or more identical icons in a row or column.",
    guide_2             = "Controls: Click an icon to select, then click a neighbor to swap.",
    guide_3             = "A swap is only valid if it creates at least one match.",
    guide_4             = "After a match, icons fall down and new ones appear at the top.",
    guide_5             = "Cascades (automatic chains) increase the combo multiplier.",
    guide_6             = "Easy: 8x8, 20 moves · Normal: 10x10, 15 moves · Hard: 12x12, 10 moves",

    -- Score / Reset
    btn_reset           = "Reset",
})
