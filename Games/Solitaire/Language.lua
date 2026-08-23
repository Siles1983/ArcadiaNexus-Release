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
    btn_auto_complete   = "Auto-Complete",
    btn_continue        = "Fortfahren",

    -- Modi
    mode_1card          = "1 Karte",
    mode_3card          = "3 Karten",

    -- Zustände
    state_idle          = "Modus wählen",
    state_win           = "Gewonnen!",
    state_gameover      = "Keine Züge mehr!",
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
    guide_2             = "Foundation: Ass bis König, pro Farbe.",
    guide_3             = "Tableau: abwechselnd Rot/Schwarz, absteigend.",
    guide_4             = "Leeres Tableau: nur König oder Königs-Stapel.",
    guide_5             = "Doppelklick legt automatisch ab (Foundation bevorzugt). Karten lassen sich auch ziehen – der Stapel folgt der Maus. Einfacher Klick: wählen, zweiter Klick: Ziel.",
    guide_6             = "Rückgängig: letzten Zug zurücknehmen (max. 3x, -15 Punkte).",
    guide_7             = "3-Karten-Modus: ab 4. Durchlauf Punkt-Abzug.",
    guide_8             = "Auto-Complete: erscheint wenn alle Karten (König bis 2) aufgedeckt und abräumbar sind.",

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
    btn_auto_complete   = "Auto-Complete",
    btn_continue        = "Continue",

    mode_1card          = "1 Card",
    mode_3card          = "3 Cards",

    state_idle          = "Choose Mode",
    state_win           = "You Win!",
    state_gameover      = "No More Moves!",
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
    guide_2             = "Foundation: Ace to King, same suit.",
    guide_3             = "Tableau: alternating Red/Black, descending.",
    guide_4             = "Empty tableau: only Kings allowed.",
    guide_5             = "Double-click auto-places a card (foundation first). You can also drag cards – the stack follows the cursor. Single click selects, second click chooses the target.",
    guide_6             = "Undo: revert last move (max 3x, -15 points).",
    guide_7             = "3-Card mode: penalty from 4th pass onwards (-20/card).",
    guide_8             = "Auto-Complete: appears when all cards (King to 2) are face-up and solvable.",

    btn_reset           = "Reset",
})
