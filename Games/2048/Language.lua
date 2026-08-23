--[[
    Gaming Hub
    Games/2048/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer 2048.
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("2048")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("2048", "deDE", {

    -- Score-Bar
    score_label     = "PUNKTE",
    best_label      = "Highscore",

    -- Größen-Auswahl (Spielfeld-Buttons)
    size_small      = "Einfach",
    size_normal     = "Normal",
    size_large      = "Schwer",

    -- Buttons
    btn_exit        = "Beenden",
    btn_new_game    = "Neues Spiel",
    btn_start       = "Spiel starten",
    btn_restart     = "Mischen",

    -- Größen-Dropdown
    size_label      = "Größe:",

    -- Starthinweis
    hint_start      = "|cffaaaaaa Wähle eine Brett-Größe um zu starten.\nSteuerung: WASD oder Pfeiltasten|r",

    -- Game Over
    go_title        = "Spiel vorbei!",
    go_score        = "Punkte: ",

    -- Settings-Panel: Box-Titel
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: Thema
    theme_label     = "Thema:",
    theme_preview   = "Vorschau:",
    theme_hint      = "|cff888888Wirkt ab dem nächsten Spiel.|r",

    -- Theme-Namen (identisch in DE/EN – Eigennamen)
    theme_classic   = "Classic (Orange)",
    theme_horde     = "Horde (Rot/Gold)",
    theme_alliance  = "Allianz (Blau/Silber)",
    theme_nightelf  = "Nachtelf (Lila/Grün)",
    theme_goblin    = "Goblin (Grün/Gelb)",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_loss      = "Niederlage",
    sound_hint      = "|cff888888Sounds werden nur abgespielt wenn\ndein Spiel-Sound aktiv ist.|r",

    -- Reset
    btn_reset       = "Reset",

    -- Anleitung
    guide_1 = "Verschiebe alle Kacheln mit WASD oder den Pfeiltasten.",
    guide_2 = "Zwei gleiche Zahlen, die zusammenstossen, verschmelzen zur doppelten Zahl.",
    guide_3 = "Nach jedem Zug erscheint eine neue 2er- oder 4er-Kachel.",
    guide_4 = "Ziel: eine 2048-Kachel bilden. Das Spiel endet, wenn kein Zug mehr möglich ist.",
    guide_5 = "Brettgröße und Farb-Theme gelten ab dem nächsten Spiel.",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("2048", "enUS", {

    -- Score-Bar
    score_label     = "SCORE",
    best_label      = "Highscore",

    -- Größen-Auswahl
    size_small      = "Easy",
    size_normal     = "Normal",
    size_large      = "Hard",

    -- Buttons
    btn_exit        = "Exit",
    btn_new_game    = "New Game",
    btn_start       = "Start Game",
    btn_restart     = "Shuffle",

    -- Größen-Dropdown
    size_label      = "Size:",

    -- Starthinweis
    hint_start      = "|cffaaaaaa Choose a board size to start.\nControls: WASD or arrow keys|r",

    -- Game Over
    go_title        = "Game Over!",
    go_score        = "Score: ",

    -- Settings-Panel: Box-Titel
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Settings-Panel: Thema
    theme_label     = "Theme:",
    theme_preview   = "Preview:",
    theme_hint      = "|cff888888Takes effect from the next game.|r",

    -- Theme-Namen
    theme_classic   = "Classic (Orange)",
    theme_horde     = "Horde (Red/Gold)",
    theme_alliance  = "Alliance (Blue/Silver)",
    theme_nightelf  = "Night Elf (Purple/Green)",
    theme_goblin    = "Goblin (Green/Yellow)",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds enabled",
    sound_loss      = "Defeat",
    sound_hint      = "|cff888888Sounds only play if your in-game sound is active.|r",

    -- Reset
    btn_reset       = "Reset",

    -- Guide
    guide_1 = "Move all tiles with WASD or the arrow keys.",
    guide_2 = "Two equal numbers that collide merge into the doubled value.",
    guide_3 = "After each move a new 2 or 4 tile appears.",
    guide_4 = "Goal: form a 2048 tile. The game ends when no moves remain.",
    guide_5 = "Board size and color theme apply from the next game.",
})
