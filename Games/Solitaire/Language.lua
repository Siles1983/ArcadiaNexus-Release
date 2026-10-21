-- ============================================================
--  Solitaire – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "SOLITAIRE"
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.RegisterLocale("SOLITAIRE", "deDE", {
    game_title          = "Solitaire",

    -- HUD / Labels
    lbl_score           = "Punkte",
    lbl_time            = "Zeit",
    lbl_undo            = "Rückgängig",
    lbl_undo_left       = "übrig",
    lbl_theme           = "Karten-Theme",
    lbl_card_backs      = "Kartenrückseiten:",
    lbl_highscore       = "Highscore",

    -- Buttons
    btn_start           = "Spiel starten",
    btn_new_game        = "Neues Spiel",
    btn_exit            = "Beenden",
    btn_undo            = "Rückgängig",
    btn_auto_complete   = "Automatisch abschließen",
    btn_continue        = "Fortfahren",

    -- Modi
    mode_1card          = "1 Karte",
    mode_3card          = "3 Karten",

    -- Zustände
    state_idle          = "Modus wählen",
    state_win           = "Gewonnen!",
    state_gameover      = "Aufgegeben",
    state_resume_hint   = "Gespeichertes Spiel – Weiterspielen?",

    -- Save-Slots
    menu_title          = "Solitaire",
    slot_info           = "%s · %s",
    slot_paused         = "läuft",
    hint_select_slot    = "Wähle einen Speicherslot",
    confirm_overwrite   = "Spielstand überschreiben?",
    confirm_overwrite_body = "Slot %d enthält einen Spielstand.",
    confirm_delete      = "Spielstand wirklich löschen?",
    confirm_delete_body = "Slot %d wird geleert.",

    -- Themes
    theme_neutral       = "Neutral",
    theme_alliance      = "Allianz",
    theme_horde         = "Horde",

    -- Sound-Labels
    sound_enabled       = "Sound aktiv",
    sound_deal          = "Karte ziehen",
    sound_place         = "Karte ablegen",
    sound_foundation    = "Foundation",
    sound_invalid       = "Ungültiger Zug",
    sound_win           = "Sieg",
    sound_undo          = "Rückgängig",

    -- Settings-Boxen
    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Anleitung",
    box_stats           = "Statistiken",

    -- Statistiken
    lbl_played          = "Gespielt",
    lbl_wins            = "Siege",
    lbl_losses          = "Niederlagen",
    lbl_top3            = "Top 3",
    lbl_top3_1card      = "Top 3 – 1 Karte",
    lbl_top3_3card      = "Top 3 – 3 Karten",

    -- Spielanleitung
    guide_1             = "Ziel: alle 52 Karten auf die 4 Foundation-Stapel legen.",
    guide_2             = "Foundation: Ass bis König, je eine Kartenfarbe (Herz, Karo, Kreuz, Pik).",
    guide_3             = "Tableau: abwechselnd Rot/Schwarz, absteigend.",
    guide_4             = "Leeres Tableau: nur König oder Königs-Stapel.",
    guide_5             = "Doppelklick legt automatisch ab (Foundation bevorzugt). Karten lassen sich auch ziehen – der Stapel folgt der Maus. Einfacher Klick: wählen, zweiter Klick: Ziel. Leertaste zieht, Strg+Z nimmt zurück, Esc hebt Auswahl auf.",
    guide_6             = "Rückgängig: bis zu 20 letzte Aktionen zurücknehmen. Jede Rücknahme kostet dauerhaft 15 Punkte; die Spielzeit läuft weiter.",
    guide_7             = "3-Karten-Modus: Recycling ab Durchlauf 4 kostet jeweils pauschal 20 Punkte. Der erste Stock zählt als Durchlauf 1; 1-Karten-Recycling ist kostenlos.",
    guide_8             = "Automatisch abschließen: nur bei leerem Stock/Waste und vollständig offenen, abräumbaren Karten. Manuelle Züge sind dabei gesperrt; Beenden pausiert.",

    guide_9 = "Aktionspunkte: Foundation +10, Waste ins Tableau +5, Aufdecken +5, Foundation zurück -15. Kein Zeitbonus; Punkte mindestens 0.",
    guide_10 = "Top 3 zählen nur Siege nach der neuen Wertung, getrennt nach Modus. Alte Bestwerte und alte Spielstände bleiben getrennt erhalten.",
    guide_11 = "Kein legaler Zug beendet die Partie nicht automatisch. Aufgeben zählt nach Bestätigung als Niederlage; Beenden speichert ohne Ergebnis.",
    btn_forfeit = "Aufgeben", btn_cancel = "Abbrechen", btn_retry = "Erneut versuchen",
    confirm_forfeit = "Partie aufgeben?", confirm_forfeit_body = "Die Partie wird als Niederlage gewertet und kann danach nicht fortgesetzt werden.",
    result_pending = "Ergebnis konnte nicht gespeichert werden",
    stock_recycle = "NEU", slot_completed = "abgeschlossen", slot_legacy = "alte Wertung",
    lb_current_scores = "Top 3 – Aktionspunkte (nur Siege)", lb_legacy_scores = "Historische Top 3 – alte Wertung",

    -- Reset
    btn_reset           = "Reset",
})

ArcadiaNexus.RegisterLocale("SOLITAIRE", "enUS", {
    game_title          = "Solitaire",

    lbl_score           = "Score",
    lbl_time            = "Time",
    lbl_undo            = "Undo",
    lbl_undo_left       = "left",
    lbl_theme           = "Card Theme",
    lbl_card_backs      = "Card Backs:",
    lbl_highscore       = "Highscore",

    btn_start           = "Start Game",
    btn_new_game        = "New Game",
    btn_exit            = "Exit",
    btn_undo            = "Undo",
    btn_auto_complete   = "Finish automatically",
    btn_continue        = "Continue",

    mode_1card          = "1 Card",
    mode_3card          = "3 Cards",

    state_idle          = "Choose Mode",
    state_win           = "You Win!",
    state_gameover      = "Given up",
    state_resume_hint   = "Saved game found – Resume?",

    -- Save slots
    menu_title          = "Solitaire",
    slot_info           = "%s · %s",
    slot_paused         = "in progress",
    hint_select_slot    = "Choose a save slot",
    confirm_overwrite   = "Overwrite save?",
    confirm_overwrite_body = "Slot %d already has a save.",
    confirm_delete      = "Delete this save?",
    confirm_delete_body = "Slot %d will be cleared.",

    theme_neutral       = "Neutral",
    theme_alliance      = "Alliance",
    theme_horde         = "Horde",

    sound_enabled       = "Sound enabled",
    sound_deal          = "Draw card",
    sound_place         = "Place card",
    sound_foundation    = "Foundation",
    sound_invalid       = "Invalid move",
    sound_win           = "Win",
    sound_undo          = "Undo",

    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Guide",
    box_stats           = "Statistics",

    lbl_played          = "Played",
    lbl_wins            = "Wins",
    lbl_losses          = "Losses",
    lbl_top3            = "Top 3",
    lbl_top3_1card      = "Top 3 – 1 Card",
    lbl_top3_3card      = "Top 3 – 3 Cards",

    guide_1             = "Goal: move all 52 cards to the 4 foundation piles.",
    guide_2             = "Foundation: Ace to King, one suit per pile (Hearts, Diamonds, Clubs, Spades).",
    guide_3             = "Tableau: alternating Red/Black, descending.",
    guide_4             = "Empty tableau: only Kings allowed.",
    guide_5             = "Double-click auto-places a card (foundation first). You can also drag cards – the stack follows the cursor. Single click selects, second click chooses the target. Space draws, Ctrl+Z undoes, Esc cancels selection.",
    guide_6             = "Undo: revert up to 20 recent actions. Each undo permanently costs 15 points; elapsed time is never rewound.",
    guide_7             = "Draw-three: each recycle from pass 4 costs a flat 20 points. The initial stock is pass 1. Draw-one recycling is free.",
    guide_8             = "Finish automatically: available with empty stock/waste and all cards face-up and clearable. Manual moves are locked; Exit pauses the game.",

    guide_9 = "Action score: foundation +10, waste to tableau +5, reveal +5, foundation back -15. No time bonus; score cannot fall below 0.",
    guide_10 = "Top 3 include only wins under the new scoring, separately per mode. Historical scores and old saves stay separate.",
    guide_11 = "No legal move never ends the game automatically. Confirmed Give up counts as a loss; Exit saves without a result.",
    btn_forfeit = "Give up", btn_cancel = "Cancel", btn_retry = "Try again",
    confirm_forfeit = "Give up this game?", confirm_forfeit_body = "This counts as a loss. The completed game cannot be resumed.",
    result_pending = "Could not save the result",
    stock_recycle = "RECYCLE", slot_completed = "completed", slot_legacy = "legacy scoring",
    lb_current_scores = "Top 3 – action score (wins only)", lb_legacy_scores = "Historical Top 3 – old scoring",
    btn_reset           = "Reset",
})
