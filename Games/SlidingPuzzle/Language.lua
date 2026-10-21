-- ============================================================
--  SlidingPuzzle – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "MOSAICOFAZEROTH"
-- ============================================================

ArcadiaNexus.RegisterLocale("MOSAICOFAZEROTH", "deDE", {
    game_title      = "Mosaic of Azeroth",

    -- Buttons
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    btn_shuffle     = "Mischen",

    -- HUD
    lbl_moves       = "Züge",
    lbl_time        = "Zeit",

    -- Schwierigkeit
    lbl_difficulty  = "Schwierigkeit",
    diff_easy       = "Einfach",
    diff_medium     = "Normal",
    diff_hard       = "Schwer",

    -- Bild-Auswahl
    lbl_image       = "Bild",
    img_random      = "Zufällig",
    img_prefix      = "Bild ",

    -- Timer
    lbl_timer       = "Zeit anzeigen",

    -- Gewinn
    win_title       = "Gelöst!",
    win_moves       = "Züge: %d",
    win_time        = "Zeit: %s",
    win_score       = "Punkte: %d",

    -- Settings
    box_sounds      = "Sound",
    box_guide       = "Anleitung",
    sound_enabled   = "Sound aktiviert",
    sound_move      = "Kachel bewegen",
    sound_win       = "Sieg",

    guide_1 = "Ziel: Setze alle Kacheln in die richtige Reihenfolge.",
    guide_2 = "Klicke eine Kachel neben dem leeren Feld, um sie zu verschieben.",
    guide_3 = "Die Kacheln können nur horizontal oder vertikal geschoben werden.",
    guide_4 = "Schwierigkeit: Einfach=3x3, Normal=4x4, Schwer=5x5.",
    guide_5 = "Vorschau: Zielbild öffnen/schließen und am Titel verschieben. Du kannst weiterspielen; die Zeit läuft weiter.",
    guide_6 = "Neue Partie über die Spielstandplätze; Wiederholen lädt dasselbe Rätsel. Züge und Zeit haben unabhängige Bestwerte je Rätsel.",

    btn_reset       = "Reset",

    box_difficulty = "Schwierigkeit",
    diff_info_1    = "Einfach: 3x3 – 8 Kacheln",
    diff_info_2    = "Normal:  4x4 – 15 Kacheln",
    diff_info_3    = "Schwer:  5x5 – 24 Kacheln",
    diff_info_4    = "19 vorhandene WoW-Motive",
    btn_preview = "Vorschau",
    btn_skip = "Intro überspringen",
    preview_show = "Vorschau anzeigen",
    preview_hide = "Vorschau schließen",
    preview_tip = "Zielbild als verschiebbares Fenster. Am Titel ziehen, an der Ecke skalieren. Freie Brettflächen bleiben spielbar; die Zeit läuft weiter.",
    preview_drag = "Zielbild – hier ziehen",
    box_visuals = "Anzeige",
    show_numbers = "Kachelnummern anzeigen",
    slot_info = "%dx%d · Bild %d",
    slot_moves = "%d Züge · pausiert",
    msg_invalid_save = "Dieser Spielstand ist ungültig oder bereits abgeschlossen. Er wurde nicht verändert.",
    msg_generation_failed = "Die Rätselvorbereitung wurde abgebrochen. Dein vorheriger Spielstand bleibt erhalten.",
    records_independent = "Züge und Zeit werden unabhängig für dasselbe Rätsel verglichen.",
    record_moves = "Neuer Zugbestwert für dieses Rätsel!",
    record_time = "Neuer Zeitbestwert für dieses Rätsel!",
    result_pending = "Ergebnis noch offen",
    result_pending_tip = "Die Buchung ist noch nicht abgeschlossen. Erneut versuchen, auch nach dem Wiederöffnen.",
    lb_legacy_easy = "Historie: 3x3",
    lb_legacy_medium = "Historie: 6x6",
    lb_legacy_hard = "Historie: 8x8",
    lb_legacy_points = "Historische Punkte",
    lb_size_easy = "3x3",
    lb_size_medium = "4x4",
    lb_size_hard = "5x5",
    guide_7 = "Ordne zuerst die obere Reihe und die linke Spalte. Erhalte bereits geordnete Bereiche; die letzten Reihen brauchen etwas Übung.",
    guide_8 = "Nummern zeigen die Zielposition und wandern mit der Kachel. „Zeit anzeigen“ blendet nur die Anzeige aus; Zeitbestwerte laufen weiter.",

    puzzle_best_moves = "Bestwert dieses Rätsels: %d Züge",
    puzzle_best_time = "Bestzeit dieses Rätsels: %s",
    legacy_best_moves = "Historie %dx%d (andere Rätsel): %d Züge",
    legacy_best_time = "Historie %dx%d (andere Rätsel): %s",
    lb_legacy_stats = "Historische Partien",

})

ArcadiaNexus.RegisterLocale("MOSAICOFAZEROTH", "enUS", {
    game_title      = "Mosaic of Azeroth",

    -- Buttons
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    btn_shuffle     = "Shuffle",

    -- HUD
    lbl_moves       = "Moves",
    lbl_time        = "Time",

    -- Difficulty
    lbl_difficulty  = "Difficulty",
    diff_easy       = "Easy",
    diff_medium     = "Normal",
    diff_hard       = "Hard",

    -- Image
    lbl_image       = "Image",
    img_random      = "Random",
    img_prefix      = "Image ",

    -- Timer
    lbl_timer       = "Show time",

    -- Win
    win_title       = "Solved!",
    win_moves       = "Moves: %d",
    win_time        = "Time: %s",
    win_score       = "Score: %d",

    -- Settings
    box_sounds      = "Sound",
    box_guide       = "Guide",
    sound_enabled   = "Sound enabled",
    sound_move      = "Tile move",
    sound_win       = "Victory",

    guide_1 = "Goal: Arrange all tiles in the correct order.",
    guide_2 = "Click a tile next to the empty space to slide it.",
    guide_3 = "Tiles can only be moved horizontally or vertically.",
    guide_4 = "Difficulty: Easy=3x3, Normal=4x4, Hard=5x5.",
    guide_5 = "Preview: toggle the target image and drag its title. Keep playing; time continues to run.",
    guide_6 = "Start a new puzzle through save slots; Retry repeats the same puzzle. Moves and time have independent records per puzzle.",

    btn_reset       = "Reset",

    box_difficulty = "Difficulty",
    diff_info_1    = "Easy: 3x3 – 8 tiles",
    diff_info_2    = "Normal: 4x4 – 15 tiles",
    diff_info_3    = "Hard: 5x5 – 24 tiles",
    diff_info_4    = "19 existing WoW motifs",
    btn_preview = "Preview",
    btn_skip = "Skip intro",
    preview_show = "Show preview",
    preview_hide = "Hide preview",
    preview_tip = "Target image in a movable window. Drag the title, resize from the corner. Uncovered tiles stay playable; time keeps running.",
    preview_drag = "Target image – drag here",
    box_visuals = "Display",
    show_numbers = "Show tile numbers",
    slot_info = "%dx%d · Image %d",
    slot_moves = "%d moves · paused",
    msg_invalid_save = "This save is invalid or already completed. Its data has not been changed.",
    msg_generation_failed = "Puzzle preparation was cancelled. Your previous save is preserved.",
    records_independent = "Moves and time are compared independently for this exact puzzle.",
    record_moves = "New move record for this puzzle!",
    record_time = "New time record for this puzzle!",
    result_pending = "Result pending",
    result_pending_tip = "The result has not been booked yet. Retry, including after reopening.",
    lb_legacy_easy = "History: 3x3",
    lb_legacy_medium = "History: 6x6",
    lb_legacy_hard = "History: 8x8",
    lb_legacy_points = "Historical points",
    lb_size_easy = "3x3",
    lb_size_medium = "4x4",
    lb_size_hard = "5x5",
    guide_7 = "Arrange the top row and left column first. Preserve completed areas; the last rows take practice.",
    guide_8 = "Numbers show target positions and move with each tile. Show time only hides the display; time records keep running.",

    puzzle_best_moves = "Move record for this puzzle: %d",
    puzzle_best_time = "Time record for this puzzle: %s",
    legacy_best_moves = "History %dx%d (other puzzles): %d moves",
    legacy_best_time = "History %dx%d (other puzzles): %s",
    lb_legacy_stats = "Historical games",

})
