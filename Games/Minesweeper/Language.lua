--[[
    Gaming Hub
    Games/Minesweeper/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Minesweeper (Goblin-Edition).
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("MINESWEEPER")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("MINESWEEPER", "deDE", {

    -- Schwierigkeits-Buttons (Renderer)
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    btn_new_game    = "Mischen",

    -- Hint (Renderer)
    hint_start      = "|cffaaaaaa Wähle eine Schwierigkeit um zu starten.|r",

    -- Statusbar (Renderer)
    status_mines    = "%s |cffffff00%d|r   %s |cffffff00%d|r gesetzt",
    hud_mines       = "Dynamit",
    hud_flags       = "Gesetzt",

    -- Overlay: Sieg (Renderer)
    result_win_title = "|cffffd700Boom! Geschafft!|r",
    result_win_sub   = "Alle %d Minen entschärft!\n|cff00ff00%s · %d Felder aufgedeckt|r",

    -- Overlay: Niederlage (Renderer)
    result_loss_title = "BOOM!",
    result_loss_sub   = "|cffff6666Du hast eine Goblin-Bombe ausgelöst!|r\n%d von %d Feldern aufgedeckt.",

    -- Settings-Panel: Box-Titel
    box_sounds      = "Sound",
    box_guide       = "Anleitung",
    box_difficulty  = "Schwierigkeit",

    -- Settings-Panel: Anleitung – Icon-Zeilen
    guide_hidden_title = "|cffffff00Verdecktes Feld|r",
    guide_hidden_text  = "Linksklick zum Aufdecken.",
    guide_flag_title   = "|cffffff00Entschärfungs-Kit|r (Flagge)",
    guide_flag_text    = "Rechtsklick zum Markieren / Entfernen.",
    guide_mine_title   = "|cffffff00Goblin-Bombe|r (Mine)",
    guide_mine_text    = "Nicht anklicken! Wird bei Verlust sichtbar.",
    guide_numbers      = "|cffffff00Zahlen|r = Anzahl Minen in Nachbarfeldern:",

    -- Settings-Panel: Schwierigkeits-Info
    info_easy_title  = "|cffffd700Einfach:|r",
    info_easy_sub    = "9x9, 10 Minen",
    info_easy_text   = "Gut zum Einstieg.",
    info_normal_title= "|cffffd700Normal:|r",
    info_normal_sub  = "12x12, 20 Minen",
    info_normal_text = "Klassische Herausforderung.",
    info_hard_title  = "|cffffd700Schwer:|r",
    info_hard_sub    = "16x16, 40 Minen",
    info_hard_text   = "Für erfahrene Entschärfer.",
    info_tip         = "|cffaaaaaa Tipp: Leere Felder decken\notomatisch ihre Nachbarn auf.|r",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_reveal    = "Feld aufdecken",
    sound_flag      = "Flagge setzen",
    sound_explode   = "Explosion",
    sound_win       = "Sieg",

    -- Reset
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("MINESWEEPER", "enUS", {

    -- Difficulty buttons
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Buttons
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    btn_new_game    = "Shuffle",

    -- Hint
    hint_start      = "|cffaaaaaa Choose a difficulty to start.|r",

    -- Statusbar
    status_mines    = "%s |cffffff00%d|r   %s |cffffff00%d|r flagged",
    hud_mines       = "Dynamite",
    hud_flags       = "Flagged",

    -- Overlay: Win
    result_win_title = "|cffffd700Boom! You did it!|r",
    result_win_sub   = "All %d mines defused!\n|cff00ff00%s · %d cells revealed|r",

    -- Overlay: Loss
    result_loss_title = "BOOM!",
    result_loss_sub   = "|cffff6666You triggered a Goblin Bomb!|r\n%d of %d cells revealed.",

    -- Settings boxes
    box_sounds      = "Sound",
    box_guide       = "Guide",
    box_difficulty  = "Difficulty",

    -- Guide icon rows
    guide_hidden_title = "|cffffff00Hidden Cell|r",
    guide_hidden_text  = "Left-click to reveal.",
    guide_flag_title   = "|cffffff00Defusal Kit|r (Flag)",
    guide_flag_text    = "Right-click to mark / unmark.",
    guide_mine_title   = "|cffffff00Goblin Bomb|r (Mine)",
    guide_mine_text    = "Don't click it! Revealed on loss.",
    guide_numbers      = "|cffffff00Numbers|r = adjacent mine count:",

    -- Difficulty info
    info_easy_title  = "|cffffd700Easy:|r",
    info_easy_sub    = "9x9, 10 mines",
    info_easy_text   = "Good for beginners.",
    info_normal_title= "|cffffd700Normal:|r",
    info_normal_sub  = "12x12, 20 mines",
    info_normal_text = "Classic challenge.",
    info_hard_title  = "|cffffd700Hard:|r",
    info_hard_sub    = "16x16, 40 mines",
    info_hard_text   = "For experienced defusers.",
    info_tip         = "|cffaaaaaa Tip: Empty cells automatically\nreveal their neighbors.|r",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_reveal    = "Reveal cell",
    sound_flag      = "Place flag",
    sound_explode   = "Explosion",
    sound_win       = "Victory",

    -- Reset
    btn_reset       = "Reset",
})
