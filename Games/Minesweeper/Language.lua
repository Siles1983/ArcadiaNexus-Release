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
    btn_pause       = "Speichern & zurück",
    btn_back        = "Zurück",
    slot_invalid    = "Ungültiger Spielstand",
    slot_finished   = "Abgeschlossen",
    result_pending  = "Ergebnis noch nicht verbucht",
    result_retry    = "Erneut verbuchen oder speichern und später fortsetzen.",
    btn_retry_result= "Erneut verbuchen",
    lb_best_times   = "Bestzeiten",
    lb_legacy_points= "Frühere Punkterekorde",
    hud_time        = "Zeit",
    result_time_record="Neue Bestzeit!",

    -- Hint (Renderer)
    hint_start      = "|cffaaaaaa Wähle eine Schwierigkeit um zu starten.|r",

    -- Statusbar (Renderer)
    status_mines    = "%s |cffffff00%d|r   %s |cffffff00%d|r gesetzt",
    hud_mines       = "Minen",
    hud_flags       = "Flaggen",

    -- Overlay: Sieg (Renderer)
    result_win_title = "|cffffd700Boom! Geschafft!|r",
    result_win_sub   = "Alle sicheren Felder aufgedeckt!\n%d Felder geöffnet.",

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
    info_tip         = "|cffaaaaaa Leere Felder öffnen ihre Nachbarn.\nDer erste wirksame Zug ist sicher.|r",
    guide_start     = "Der erste aufdeckende Klick hält Feld und Nachbarn minenfrei. Flaggen vorher beeinflussen die Verteilung nicht.",
    guide_chord     = "Linksklick auf eine offene Zahl öffnet unmarkierte Nachbarn, wenn genau so viele Flaggen angrenzen. Beispiel: eine 2 mit zwei Flaggen. Falsche Flaggen können dabei eine Mine auslösen.",
    guide_flags     = "Flaggen sind Vermutungen: 23/20 bedeutet 23 Markierungen bei 20 Minen, kein Limit und keine bestätigten Treffer. Markierte Felder bleiben beim Aufdecken geschützt.",
    guide_result    = "Sieg: alle sicheren Felder öffnen; Flaggen sind nicht erforderlich. Nach Verlust: ! kennzeichnet die ausgelöste Mine, X eine falsche Flagge; weitere Bomben sind andere Minen.",
    guide_time      = "Zeit läuft ab dem ersten wirksamen Aufdecken und stoppt bei Ende oder Speichern. Nur aktive Zeit zählt, ohne Countdown. Siege bringen 50/100/200 Punkte; die drei kürzesten Siegzeiten ranken je Schwierigkeit, auch nach Fortsetzen.",

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
    btn_pause       = "Save & back",
    btn_back        = "Back",
    slot_invalid    = "Invalid save",
    slot_finished   = "Completed",
    result_pending  = "Result not yet recorded",
    result_retry    = "Retry recording or save and resume later.",
    btn_retry_result= "Retry recording",
    lb_best_times   = "Best times",
    lb_legacy_points= "Earlier point records",
    hud_time        = "Time",
    result_time_record="New best time!",

    -- Hint
    hint_start      = "|cffaaaaaa Choose a difficulty to start.|r",

    -- Statusbar
    status_mines    = "%s |cffffff00%d|r   %s |cffffff00%d|r flagged",
    hud_mines       = "Mines",
    hud_flags       = "Flags",

    -- Overlay: Win
    result_win_title = "|cffffd700Boom! You did it!|r",
    result_win_sub   = "All safe cells revealed!\n%d cells opened.",

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
    guide_start     = "The first effective reveal keeps its cell and neighbors free of mines. Earlier flags do not affect placement.",
    guide_chord     = "Left-click an open number to reveal unflagged neighbors when the adjacent flag count matches. Example: a 2 with two flags. Incorrect flags can trigger a mine.",
    guide_flags     = "Flags are guesses: 23/20 means 23 markers for 20 mines, not a limit or confirmed matches. Flagged cells stay protected during reveals.",
    guide_result    = "Win by opening all safe cells; flags are not required. After a loss: ! marks the triggered mine, X an incorrect flag; other bombs are the remaining mines.",
    guide_time      = "Time starts with the first effective reveal and stops on completion or saving. Only active time counts, with no countdown. Wins award 50/100/200 points; the three shortest win times rank per difficulty, including resumed games.",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_reveal    = "Reveal cell",
    sound_flag      = "Place flag",
    sound_explode   = "Explosion",
    sound_win       = "Victory",

    -- Reset
    btn_reset       = "Reset",
})
