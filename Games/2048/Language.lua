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
    size_small      = "3 × 3",
    size_normal     = "4 × 4",
    size_large      = "5 × 5",
    lb_legacy       = "Historisch (Brettgröße unbekannt)",
    btn_pause       = "Speichern & zurück",
    btn_continue    = "Fortfahren",
    btn_keep_playing = "Weiterspielen",
    btn_finish      = "Partie abschließen",
    btn_slots       = "Spielstände",
    win_title       = "2048 erreicht!",
    highest_tile    = "Höchste Kachel: %s",
    win_already_recorded = "Der Sieg wurde bereits gewertet. Keine erneute Belohnung.",
    slot_info       = "%d × %d · %s Punkte",
    slot_finished   = "Abgeschlossen",
    slot_invalid    = "Ungültiger Spielstand",
    result_pending  = "Ergebnis noch offen",
    result_retry_hint = "Dein Brett ist gespeichert. Die Wertung kann erneut versucht werden.",
    btn_retry_result = "Wertung wiederholen",
    reduced_motion  = "Bewegung reduzieren",

    -- Buttons
    btn_exit        = "Beenden",
    btn_new_game    = "Neues Spiel",
    btn_start       = "Spiel starten",

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
    theme_hint      = "|cff888888Farbthema und Bewegung sind jederzeit anpassbar.|r",

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
    guide_3 = "Nach jedem wirksamen Zug erscheint eine neue 2er- oder 4er-Kachel.",
    guide_4 = "2048 zählt einmal als Sieg. Danach kannst du in derselben Partie weiterspielen.",
    guide_5 = "Neue Partien und Fortfahren über Spielstände. Speichern & zurück erhält dein Brett.",
    guide_6 = "Die Brettgröße bleibt während der Partie fest. Farben und Bewegung sind frei anpassbar.",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("2048", "enUS", {

    -- Score-Bar
    score_label     = "SCORE",
    best_label      = "Highscore",

    -- Größen-Auswahl
    size_small      = "3 × 3",
    size_normal     = "4 × 4",
    size_large      = "5 × 5",
    lb_legacy       = "Historical (unknown board size)",
    btn_pause       = "Save & back",
    btn_continue    = "Continue",
    btn_keep_playing = "Keep playing",
    btn_finish      = "Finish run",
    btn_slots       = "Save slots",
    win_title       = "2048 reached!",
    highest_tile    = "Highest tile: %s",
    win_already_recorded = "This win has already been recorded. No additional reward.",
    slot_info       = "%d × %d · %s points",
    slot_finished   = "Finished",
    slot_invalid    = "Invalid save",
    result_pending  = "Result pending",
    result_retry_hint = "Your board is saved. Result processing can be retried.",
    btn_retry_result = "Retry result",
    reduced_motion  = "Reduce motion",

    -- Buttons
    btn_exit        = "Exit",
    btn_new_game    = "New Game",
    btn_start       = "Start Game",

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
    theme_hint      = "|cff888888Colors and motion can be changed at any time.|r",

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
    guide_3 = "After each effective move a new 2 or 4 tile appears.",
    guide_4 = "2048 counts as one win. You can then keep playing the same run.",
    guide_5 = "Use save slots for new games and resuming. Save & back preserves your board.",
    guide_6 = "Board size stays fixed during a run. Colors and motion remain adjustable.",
})
