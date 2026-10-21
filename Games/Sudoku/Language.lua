--[[
    Gaming Hub
    Games/Sudoku/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Sudoku.
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("SUDOKU")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("SUDOKU", "deDE", {

    -- Schwierigkeits-Buttons (Renderer)
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    btn_notes="Notizen", btn_clear="Leeren", btn_undo="Zurück", btn_back="Zurück",
    picker_notes="Notizen", picker_number="Zahl setzen",
    slot_invalid="Ungültiger Spielstand", slot_finished="Gelöst", result_pending="Ergebnis erneut buchen",
    slot_info="%s · %d Zahleneingaben",
    lb_solved="Gelöste Rätsel",
    guide_rules="Fülle jede Zeile, Spalte und jeden 3×3-Block mit 1–9, ohne Wiederholung.",
    guide_input="Feld wählen, dann Zahl im Picker oder 1–9 drücken. Pfeile wählen das Nachbarfeld; Esc schließt die Auswahl.",
    guide_notes="Notizen schaltet Kandidaten in leeren Feldern ein/aus. Der Picker bleibt offen. Eine echte Zahl entfernt die Notizen.",
    guide_undo="Leeren / Rechtsklick / Entf entfernt Zahlen und Notizen. Zurück / Strg+Z macht eine Bearbeitung rückgängig.",
    guide_conflicts="Rot zeigt Regelkonflikte, keinen Vergleich mit der Lösung. Zahleneingaben und Konflikteingaben bleiben nach Undo gezählt.",
    guide_saves="Beenden speichert ohne Niederlage. Neue Rätsel über die Slots; feste Vorgaben bleiben unveränderbar.",

    -- Hints / Statistik (Renderer)
    hint_start      = "|cffaaaaaa Wähle eine Schwierigkeit um zu starten.|r",
    stats_text      = "Zahleneingaben: %d   Konflikteingaben: %d",
    hud_score       = "Punkte bei Lösung",
    hud_highscore   = "Gelöst",

    -- Overlay: Sieg (Renderer)
    result_title    = "|cffffd700Gelöst!|r",
    result_sub      = "Zahleneingaben: %d   Konflikteingaben: %d\nSchwierigkeit: %s",

    -- EnterIdleState: DIFFS-Referenz intern – kein extra Key nötig

    -- Settings-Panel: Box-Titel
    box_difficulty  = "Schwierigkeit",
    box_sounds      = "Sound",

    -- Settings-Panel: Schwierigkeits-Info
    info_easy_title  = "|cffffd700Einfach:|r",
    info_easy_text1  = "Nackte und versteckte Singles.",
    info_easy_text2  = "Viele Hinweise, ideal zum Einstieg.",
    info_normal_title= "|cffffd700Normal:|r",
    info_normal_text1= "Zusätzlich gebundene Kandidaten.",
    info_normal_text2= "Ausgeglichene Herausforderung.",
    info_hard_title  = "|cffffd700Schwer:|r",
    info_hard_text1  = "Zusätzlich nackte Paare.",
    info_hard_text2  = "Wenige Hinweise, erfordert",
    info_hard_text3  = "fortgeschrittene Techniken.",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_place     = "Zahl gesetzt",
    sound_error     = "Fehler",
    sound_complete  = "Gelöst",
    sound_hint      = "|cff888888Sounds werden nur abgespielt wenn\ndein Spiel-Sound aktiv ist.|r",

    -- Reset
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("SUDOKU", "enUS", {

    -- Difficulty buttons
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Buttons
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    btn_notes="Notes", btn_clear="Clear", btn_undo="Undo", btn_back="Back",
    picker_notes="Notes", picker_number="Place number",
    slot_invalid="Invalid save", slot_finished="Solved", result_pending="Retry result",
    slot_info="%s · %d number entries",
    lb_solved="Solved puzzles",
    guide_rules="Fill every row, column and 3×3 box with 1–9 without repeating a number.",
    guide_input="Select a cell, then use the picker or press 1–9. Arrows select a neighbor; Esc clears the selection.",
    guide_notes="Notes toggles candidates in empty cells. The picker stays open. A real number clears that cell's notes.",
    guide_undo="Clear / right click / Delete removes numbers and notes. Undo / Ctrl+Z reverts one edit.",
    guide_conflicts="Red marks rule conflicts, not a comparison with the solution. Undo does not reduce historical entry counters.",
    guide_saves="Exit saves without a loss. Start new puzzles through slots; given numbers remain protected.",

    -- Hints / Stats
    hint_start      = "|cffaaaaaa Choose a difficulty to start.|r",
    stats_text      = "Number entries: %d   Conflict entries: %d",
    hud_score       = "Points when solved",
    hud_highscore   = "Solved",

    -- Overlay: Victory
    result_title    = "|cffffd700Solved!|r",
    result_sub      = "Number entries: %d   Conflict entries: %d\nDifficulty: %s",

    -- Settings boxes
    box_difficulty  = "Difficulty",
    box_sounds      = "Sound",

    -- Difficulty info
    info_easy_title  = "|cffffd700Easy:|r",
    info_easy_text1  = "Naked and hidden singles.",
    info_easy_text2  = "Many hints, ideal for beginners.",
    info_normal_title= "|cffffd700Normal:|r",
    info_normal_text1= "Also locked candidates.",
    info_normal_text2= "Balanced challenge.",
    info_hard_title  = "|cffffd700Hard:|r",
    info_hard_text1  = "Also naked pairs.",
    info_hard_text2  = "Few hints, requires",
    info_hard_text3  = "advanced techniques.",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_place     = "Number placed",
    sound_error     = "Mistake",
    sound_complete  = "Solved",
    sound_hint      = "|cff888888Sounds only play if your in-game sound is active.|r",

    -- Reset
    btn_reset       = "Reset",
})
