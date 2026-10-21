-- ============================================================
--  AlchemistsSort – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "ALCHEMISTSSORT"
-- ============================================================

ArcadiaNexus.RegisterLocale("ALCHEMISTSSORT", "deDE", {
    lb_legacy_points = "Historische Punkte (alte Rätsel)",
    msg_hint_unknown = "In diesem Suchbudget kein hilfreicher Tipp belegt. Keine Hilfe verbraucht.",
    msg_no_hint = "Kein hilfreicher Lösungsweg gefunden. Rückgängig, Reset oder Zusatzflasche prüfen.",
    msg_deadlock = "Kein erlaubter Zug. Rückgängig, Reset oder verfügbare Zusatzflasche nutzen.",
    msg_invalid_save = "Zwischenstand nicht sicher fortsetzbar. Originaldaten bleiben erhalten; Levelkarte ist verfügbar.",
    msg_generation_failed = "Rätsel konnte nicht geprüft werden. Bitte erneut starten.",
    msg_result_pending = "Abschluss noch nicht verbucht",
    pending_help = "Der Abschluss ist gespeichert. Erneut versuchen oder später fortfahren; keine doppelte Belohnung.",
    btn_retry_result = "Abschluss erneut prüfen",
    record_moves = "Neuer Zugbestwert für dieses Rätsel und diese Hilfsklasse!",
    record_time = "Neue Bestzeit für dieses Rätsel und diese Hilfsklasse!",
    minimum_exact = "Belegtes Minimum: %d Züge",
    aid_unassisted = "Ohne Hilfen",
    aid_hint_or_undo = "Tipp/Rückgängig",
    aid_extra_bottle = "Zusatzflasche",
    best_independent = "Züge und Zeit sind unabhängige Bestwerte; gleiche Rätsel und Hilfsklassen werden verglichen.",
    map_best_class = "%s: %d Züge / %s",
    map_legacy = "Historisch (Rätsel/Hilfen unbekannt): %d Züge / %s",
    tip_reset = "Ausgangsrätsel wiederherstellen. Zeit und verbrauchte Hilfen bleiben erhalten.",
    tip_undo = "Letzten Zug zurücknehmen. Verbleibend: %d. Mit Tipp/Rückgängig höchstens 2 Sterne.",
    tip_hint = "Zeigt den nächsten geprüften Lösungszug. Verbleibend: %d. Höchstens 2 Sterne; erfolglose Suche ist kostenlos.",
    tip_add = "Einmalige leere Zusatzflasche. Verbleibend: %d. Höchstens 1 Stern; bleibt bei Reset/Rückgängig erhalten.",
    game_title       = "Alchemist's Sort",

    -- HUD
    lbl_level        = "Level",
    lbl_choose_level = "Level",
    lbl_moves        = "Züge",
    lbl_time         = "Zeit",

    -- Buttons
    btn_start        = "Spiel starten",
    btn_reset        = "Reset",
    btn_undo         = "Rückgängig",
    btn_hint         = "Tipp",
    btn_add_tube     = "Zusatzflasche",
    btn_next_level   = "Nächstes Level",
    btn_level_select = "Levelauswahl",
    btn_prev_page    = "Zurück",
    btn_next_page    = "Weiter",
    btn_resume_level = "Fortsetzen",
    btn_exit         = "Beenden",
    btn_new_game     = "Neues Spiel",
    btn_continue     = "Fortfahren",

    -- Save-Slots
    menu_title       = "Alchemist's Sort",
    slot_label       = "Slot %d",
    slot_empty       = "— Leer —",
    slot_info        = "Level %d",
    slot_info_unlocked = "L%d · frei bis %d · %d Sterne",
    slot_paused      = "pausiert",
    confirm_overwrite = "Spielstand überschreiben?",
    confirm_overwrite_body = "Slot %d enthält einen Spielstand.",
    confirm_delete   = "Spielstand wirklich löschen?",
    confirm_delete_body = "Slot %d wird geleert.",
    btn_yes          = "Ja",
    btn_no           = "Abbrechen",

    -- Zustände / Overlays
    state_idle       = "Level wählen",
    state_playing    = "Flaschen sortieren",
    state_win        = "Gelöst!",
    win_moves        = "Züge: %d",
    win_time         = "Zeit: %s",
    win_score        = "Punkte: %d",
    map_title        = "Level %d–%d",
    map_locked       = "—",
    map_progress     = "Frei bis %d · Sterne: %d",
    level_stars      = "Sterne: %d / 3",
    result_stars     = "Sterne: %d (Bestwert: %d)",
    level_unlocked   = "Freigeschaltet bis Level %d",
    level_page       = "%d / %d",
    level_best_moves = "%d Züge",
    level_best_time  = "%s",
    level_no_best    = "—",
    level_locked     = "Gesperrt",

    -- Bestätigungs-Dialog Reset
    confirm_reset    = "Level neu starten?",
    confirm_leave_level = "Laufendes Level verwerfen?",
    confirm_yes      = "Ja",
    confirm_no       = "Nein",

    -- Undo / Tipp erschöpft
    lbl_undo_left    = "Rückgängig (%d)",
    lbl_hint_left    = "Tipp (%d)",
    lbl_undo_none    = "Rückgängig",
    lbl_hint_none    = "Tipp",

    -- Fehlermeldungen / Hinweise
    msg_invalid_move = "Ungültiger Zug!",

    -- Settings
    box_sounds       = "Sound",
    box_guide        = "Anleitung",
    btn_reset_settings = "Reset",
    sound_enabled    = "Sound aktiviert",
    sound_pour       = "Gießen",
    sound_win        = "Sieg",
    sound_invalid    = "Ungültiger Zug",

    guide_1 = "Ziel: Jede Flasche soll eine einzige Farbe enthalten.",
    guide_2 = "Klicke eine Flasche an, dann eine Zielflasche.",
    guide_3 = "Es werden alle gleichfarbigen Schichten oben übertragen.",
    guide_4 = "Leere Flaschen nehmen jede Farbe an.",
    guide_5 = "Reset: Level neu starten (Timer läuft weiter).",
    guide_6 = "Rückgängig: Letzten Zug zurücknehmen (max. 3x).",
    guide_7 = "Zusatzflasche: Einmalig eine leere Flasche hinzufügen.",
    guide_8 = "Sterne: 3 ohne Hilfen; 2 mit Tipp/Rückgängig; 1 mit Zusatzflasche.",
    guide_9 = "Level 1–1000 sind feste Rätsel und werden allmählich schwerer. Ein schon begonnenes Brett bleibt im Speicherplatz erhalten. Ab Level 1001 wird je Platz einmalig ein Zufallsrätsel festgehalten.",
    guide_10 = "Neue Speicherplätze öffnen die Karte. Bestwerte für Züge und Zeit stehen im Tooltip der Levelkachel.",

    box_level_info = "Level-Info",
    level_info_1   = "Level   1– 40:  3 Farben, 5 Röhren",
    level_info_2   = "Level  41–120:  4 Farben, 6 Röhren",
    level_info_3   = "Level 121–250:  5 Farben, 7 Röhren",
    level_info_4   = "Level 251–450:  6 Farben, 8 Röhren",
    level_info_5   = "Level 451–700:  7 Farben, 9 Röhren",
    level_info_6   = "Level 701–1000: 8 Farben, 10 Röhren; danach Zufall",

    -- Lade-Overlay
    lbl_loading = "Bereite Rätsel vor",
})

ArcadiaNexus.RegisterLocale("ALCHEMISTSSORT", "enUS", {
    lb_legacy_points = "Historical points (previous puzzles)",
    msg_hint_unknown = "No helpful hint proved within this search budget. No aid used.",
    msg_no_hint = "No helpful solution found. Check Undo, Reset or Extra bottle.",
    msg_deadlock = "No legal move. Use Undo, Reset or an available Extra bottle.",
    msg_invalid_save = "This snapshot cannot safely resume. Original data is retained; the level map is available.",
    msg_generation_failed = "The puzzle could not be verified. Please start again.",
    msg_result_pending = "Completion not recorded yet",
    pending_help = "Completion is saved. Retry now or continue later; rewards will not be duplicated.",
    btn_retry_result = "Retry completion",
    record_moves = "New move record for this puzzle and assistance class!",
    record_time = "New best time for this puzzle and assistance class!",
    minimum_exact = "Proven minimum: %d moves",
    aid_unassisted = "No aids",
    aid_hint_or_undo = "Hint/Undo",
    aid_extra_bottle = "Extra bottle",
    best_independent = "Moves and time are independent records; comparisons use the same puzzle and assistance class.",
    map_best_class = "%s: %d moves / %s",
    map_legacy = "Historical (puzzle/aids unknown): %d moves / %s",
    tip_reset = "Restore the initial puzzle. Time and used aids are retained.",
    tip_undo = "Undo the last move. Remaining: %d. Hint/Undo allows at most 2 stars.",
    tip_hint = "Shows the next verified solution move. Remaining: %d. At most 2 stars; unsuccessful search is free.",
    tip_add = "One extra empty bottle. Remaining: %d. At most 1 star; retained across Reset/Undo.",
    game_title       = "Alchemist's Sort",

    -- HUD
    lbl_level        = "Level",
    lbl_choose_level = "Level",
    lbl_moves        = "Moves",
    lbl_time         = "Time",

    -- Buttons
    btn_start        = "Start Game",
    btn_reset        = "Reset",
    btn_undo         = "Undo",
    btn_hint         = "Hint",
    btn_add_tube     = "Extra bottle",
    btn_next_level   = "Next Level",
    btn_level_select = "Level Select",
    btn_prev_page    = "Previous",
    btn_next_page    = "Next",
    btn_resume_level = "Resume",
    btn_exit         = "Exit",
    btn_new_game     = "New Game",
    btn_continue     = "Continue",

    -- Save slots
    menu_title       = "Alchemist's Sort",
    slot_label       = "Slot %d",
    slot_empty       = "— Empty —",
    slot_info        = "Level %d",
    slot_info_unlocked = "L%d · open to %d · %d stars",
    slot_paused      = "paused",
    confirm_overwrite = "Overwrite save?",
    confirm_overwrite_body = "Slot %d already has a save.",
    confirm_delete   = "Delete this save?",
    confirm_delete_body = "Slot %d will be cleared.",
    btn_yes          = "Yes",
    btn_no           = "Cancel",

    -- States / Overlays
    state_idle       = "Choose a level",
    state_playing    = "Sort the bottles",
    state_win        = "Solved!",
    win_moves        = "Moves: %d",
    win_time         = "Time: %s",
    win_score        = "Score: %d",
    map_title        = "Level %d–%d",
    map_locked       = "—",
    map_progress     = "Open to %d · Stars: %d",
    level_stars      = "Stars: %d / 3",
    result_stars     = "Stars: %d (Best: %d)",
    level_unlocked   = "Unlocked through level %d",
    level_page       = "%d / %d",
    level_best_moves = "%d moves",
    level_best_time  = "%s",
    level_no_best    = "—",
    level_locked     = "Locked",

    -- Confirm Reset
    confirm_reset    = "Restart level?",
    confirm_leave_level = "Discard the paused level?",
    confirm_yes      = "Yes",
    confirm_no       = "No",

    -- Undo / Hint
    lbl_undo_left    = "Undo (%d)",
    lbl_hint_left    = "Hint (%d)",
    lbl_undo_none    = "Undo",
    lbl_hint_none    = "Hint",

    -- Feedback
    msg_invalid_move = "Invalid move!",

    -- Settings
    box_sounds       = "Sound",
    box_guide        = "Guide",
    btn_reset_settings = "Reset",
    sound_enabled    = "Sound enabled",
    sound_pour       = "Pouring",
    sound_win        = "Victory",
    sound_invalid    = "Invalid move",

    guide_1 = "Goal: Each bottle must contain only one color.",
    guide_2 = "Click a source bottle, then a target bottle.",
    guide_3 = "All matching top layers are transferred at once.",
    guide_4 = "Empty bottles accept any color.",
    guide_5 = "Reset: Restart the level (timer keeps running).",
    guide_6 = "Undo: Undo last move (max. 3 times).",
    guide_7 = "Extra bottle: Add one empty bottle (once per level).",
    guide_8 = "Stars: 3 without aids; 2 with hints/undo; 1 with an extra bottle.",
    guide_9 = "Levels 1–1000 are fixed puzzles and grow gradually harder. A board already started stays in that save slot. From level 1001, each slot keeps one random puzzle.",
    guide_10 = "New save slots open the map. Hover over a level to see your best moves and time.",

    box_level_info = "Level Info",
    level_info_1   = "Level   1– 40:  3 colors, 5 tubes",
    level_info_2   = "Level  41–120:  4 colors, 6 tubes",
    level_info_3   = "Level 121–250:  5 colors, 7 tubes",
    level_info_4   = "Level 251–450:  6 colors, 8 tubes",
    level_info_5   = "Level 451–700:  7 colors, 9 tubes",
    level_info_6   = "Level 701–1000: 8 colors, 10 tubes; then random",

    -- Loading overlay
    lbl_loading = "Preparing puzzle",
})
