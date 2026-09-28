-- ============================================================
--  AlchemistsSort – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "ALCHEMISTSSORT"
-- ============================================================

ArcadiaNexus.RegisterLocale("ALCHEMISTSSORT", "deDE", {
    game_title       = "Alchemist's Sort",

    -- HUD
    lbl_level        = "Level",
    lbl_choose_level = "Level ▼",
    lbl_moves        = "Züge",
    lbl_time         = "Zeit",

    -- Buttons
    btn_start        = "Spiel starten",
    btn_reset        = "Reset",
    btn_undo         = "Rückgängig",
    btn_hint         = "Tipp",
    btn_add_tube     = "+ Röhre",
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
    confirm_yes      = "Ja",
    confirm_no       = "Nein",

    -- Undo / Tipp erschöpft
    lbl_undo_left    = "Rückgängig (%d)",
    lbl_hint_left    = "Tipp (%d)",
    lbl_undo_none    = "Rückgängig",
    lbl_hint_none    = "Tipp",

    -- Fehlermeldungen / Hinweise
    msg_invalid_move = "Ungültiger Zug!",
    msg_no_hint      = "Kein Zug möglich!",

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
    guide_7 = "+ Röhre: Einmalig eine leere Flasche hinzufügen.",
    guide_8 = "Sterne: 3 ohne Hilfen; 2 mit Tipp/Rückgängig; 1 mit Zusatzröhre.",
    guide_9 = "Pro Level bleibt die beste Sternwertung im Speicherplatz erhalten. Reset und Fortsetzen löschen verwendete Hilfen nicht.",
    guide_10 = "Neue Speicherplätze öffnen die Karte. Bestwerte für Züge und Zeit stehen im Tooltip der Levelkachel.",

    box_level_info = "Level-Info",
    level_info_1   = "Level  1– 5:  3 Farben, 5 Röhren",
    level_info_2   = "Level  6–15:  4 Farben, 6 Röhren",
    level_info_3   = "Level 16–30:  5 Farben, 7 Röhren",
    level_info_4   = "Level 31–50:  6 Farben, 8 Röhren",
    level_info_5   = "Level 51–75:  7 Farben, 9 Röhren",
    level_info_6   = "Level 76+  :  8 Farben, 10 Röhren",

    -- Lade-Overlay
    lbl_loading = "Bereite Rätsel vor",
})

ArcadiaNexus.RegisterLocale("ALCHEMISTSSORT", "enUS", {
    game_title       = "Alchemist's Sort",

    -- HUD
    lbl_level        = "Level",
    lbl_choose_level = "Level ▼",
    lbl_moves        = "Moves",
    lbl_time         = "Time",

    -- Buttons
    btn_start        = "Start Game",
    btn_reset        = "Reset",
    btn_undo         = "Undo",
    btn_hint         = "Hint",
    btn_add_tube     = "+ Tube",
    btn_next_level   = "Next Level",
    btn_level_select = "Choose Level",
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
    confirm_yes      = "Yes",
    confirm_no       = "No",

    -- Undo / Hint
    lbl_undo_left    = "Undo (%d)",
    lbl_hint_left    = "Hint (%d)",
    lbl_undo_none    = "Undo",
    lbl_hint_none    = "Hint",

    -- Feedback
    msg_invalid_move = "Invalid move!",
    msg_no_hint      = "No move available!",

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
    guide_7 = "+ Tube: Add one empty bottle (once per level).",
    guide_8 = "Stars: 3 without aids; 2 with hints/undo; 1 with an extra tube.",
    guide_9 = "Each save slot keeps your best star rating per level. Reset and resume retain used aids.",
    guide_10 = "New save slots open the map. Hover over a level to see your best moves and time.",

    box_level_info = "Level Info",
    level_info_1   = "Level  1– 5:  3 colors, 5 tubes",
    level_info_2   = "Level  6–15:  4 colors, 6 tubes",
    level_info_3   = "Level 16–30:  5 colors, 7 tubes",
    level_info_4   = "Level 31–50:  6 colors, 8 tubes",
    level_info_5   = "Level 51–75:  7 colors, 9 tubes",
    level_info_6   = "Level 76+  :  8 colors, 10 tubes",

    -- Loading overlay
    lbl_loading = "Preparing puzzle",
})
