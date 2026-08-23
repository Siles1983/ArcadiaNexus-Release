-- ============================================================
--  Azeroth Jewels – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "AZEROTHJEWELS"
-- ============================================================

ArcadiaNexus.RegisterLocale("AZEROTHJEWELS", "deDE", {
    game_title          = "Azeroth Jewels",

    -- HUD
    lbl_score           = "Punkte",
    lbl_total_score     = "Gesamt",
    lbl_moves           = "Züge",
    lbl_time            = "Zeit",
    lbl_level           = "Level",
    lbl_highscore       = "Highscore",
    lbl_goal            = "Ziel",
    goal_score          = "Punkte: %s / %s",
    goal_collect        = "Sammeln:",

    -- Slot-Menü
    menu_title          = "Azeroth Jewels",
    slot_label          = "Slot %d",
    slot_empty          = "— Leer —",
    slot_info           = "Level %d · %s Punkte",
    slot_paused         = "Level %d läuft",
    btn_new_game        = "Neues Spiel",
    btn_continue        = "Fortfahren",
    btn_delete          = "Löschen",
    confirm_overwrite   = "Spielstand überschreiben?",
    confirm_overwrite_body = "Slot %d enthält einen Spielstand.",
    confirm_delete      = "Spielstand wirklich löschen?",
    confirm_delete_body = "Slot %d wird geleert.",
    btn_yes             = "Ja",
    btn_no              = "Abbrechen",
    hint_select_slot    = "Wähle einen Speicherslot",

    -- Buttons
    btn_start           = "Spiel starten",
    btn_exit            = "Beenden",
    btn_next_level      = "Weiter",
    btn_level_select    = "Level neu starten",
    popup_play_again    = "Nochmal",

    -- Zustände / Hinweise
    hint_select         = "Klicke einen Juwel zum Auswählen",
    hint_swap           = "Klicke einen benachbarten Juwel zum Tauschen",
    hint_invalid        = "Kein Match! Tausch rückgängig.",
    hint_shuffle        = "Keine Züge möglich – Board wird gemischt...",
    hint_targeting      = "Zielfeld wählen – Rechtsklick/ESC bricht ab",
    hint_targeting_frost = "Klick = Reihe · Shift-Klick = Spalte · Rechtsklick bricht ab",
    combo_prefix        = "Kombo x",

    -- Result-Dialoge
    result_level_win_title = "Level geschafft!",
    result_final_win_title = "Alle Level geschafft!",
    result_loss_title   = "Spiel vorbei!",
    state_timeout       = "Zeit abgelaufen!",
    result_level        = "Level: %d",
    result_level_score  = "Level-Punkte: %s",
    result_total_score  = "Gesamtpunkte: %s",
    result_max_combo    = "Beste Kombo: x%d",
    result_powerups     = "PowerUps eingesetzt: %d",

    -- PowerUps
    powerup_fire        = "Feuernova",
    powerup_frost       = "Frost Nova",
    powerup_chain       = "Kettenblitz",
    powerup_bomb        = "Goblin-Bombe",
    powerup_holy        = "Heiliger Strahl",
    powerup_fire_desc   = "Zerstört ein Kreuz aus 5 Feldern.",
    powerup_frost_desc  = "Leert eine ganze Reihe oder Spalte.",
    powerup_chain_desc  = "Zerstört alle Juwelen einer Farbe.",
    powerup_bomb_desc   = "3x3-Explosion um das Zielfeld.",
    powerup_holy_desc   = "Wandelt 3 zufällige Juwelen in Wildcards.",
    powerup_ready       = "Bereit zum Einsetzen!",
    powerup_charging    = "Lädt auf...",
    powerup_inv         = "Vorrat: %d/3",

    -- Hindernisse
    obstacle_ice        = "Eis-Block",
    obstacle_stone      = "Stein-Block",
    obstacle_locked     = "Gesperrtes Feld",

    -- Schwierigkeiten
    diff_easy           = "Einfach",
    diff_normal         = "Normal",
    diff_hard           = "Schwer",

    -- Settings Panel
    box_mode            = "Spielmodus",
    box_sounds          = "Sound",
    box_guide           = "Anleitung",
    lbl_timer_check     = "Zeitmodus (Punkte x 1,5)",
    lbl_timer_on        = "Zeitmodus",
    lbl_difficulty      = "Schwierigkeit (bei neuem Spiel)",
    sound_enabled       = "Sound aktiviert",
    sound_match         = "Match-Sound",
    sound_powerup       = "PowerUp-Sound",
    sound_gameover      = "Spiel-Ende-Sound",
    btn_reset           = "Reset",

    -- Spielanleitung
    guide_1             = "Ziel: Erfülle das Level-Ziel (Punkte oder Juwelen sammeln) bevor die Züge ausgehen.",
    guide_2             = "Tausche benachbarte Juwelen für Reihen/Spalten aus 3+, oder bilde ein 2x2-Quadrat.",
    guide_3             = "4er-Match: +50% Punkte · 2x2: +25% · 5er+: +100% und alle laden PowerUps auf.",
    guide_4             = "PowerUps laden durch Kombos und Punkte auf – max. 3 pro Typ im Vorrat.",
    guide_5             = "Ab Level 21: Eis (Match daneben), Stein (nur PowerUp) und gesperrte Felder.",
    guide_6             = "Zeitmodus: Zeitlimit statt Entspannung – dafür Punkte x 1,5.",
    guide_7             = "3 Speicherslots · Auto-Save nach jedem Level · Tab schließen pausiert das Level.",
})

ArcadiaNexus.RegisterLocale("AZEROTHJEWELS", "enUS", {
    game_title          = "Azeroth Jewels",

    -- HUD
    lbl_score           = "Score",
    lbl_total_score     = "Total",
    lbl_moves           = "Moves",
    lbl_time            = "Time",
    lbl_level           = "Level",
    lbl_highscore       = "Highscore",
    lbl_goal            = "Goal",
    goal_score          = "Score: %s / %s",
    goal_collect        = "Collect:",

    -- Slot menu
    menu_title          = "Azeroth Jewels",
    slot_label          = "Slot %d",
    slot_empty          = "— Empty —",
    slot_info           = "Level %d · %s points",
    slot_paused         = "Level %d in progress",
    btn_new_game        = "New Game",
    btn_continue        = "Continue",
    btn_delete          = "Delete",
    confirm_overwrite   = "Overwrite save?",
    confirm_overwrite_body = "Slot %d contains a save.",
    confirm_delete      = "Really delete save?",
    confirm_delete_body = "Slot %d will be cleared.",
    btn_yes             = "Yes",
    btn_no              = "Cancel",
    hint_select_slot    = "Choose a save slot",

    -- Buttons
    btn_start           = "Start Game",
    btn_exit            = "Exit",
    btn_next_level      = "Continue",
    btn_level_select    = "Restart Level",
    popup_play_again    = "Play Again",

    -- States / hints
    hint_select         = "Click a jewel to select",
    hint_swap           = "Click an adjacent jewel to swap",
    hint_invalid        = "No match! Swap undone.",
    hint_shuffle        = "No moves available – shuffling board...",
    hint_targeting      = "Choose a target – right-click/ESC cancels",
    hint_targeting_frost = "Click = row · Shift-click = column · right-click cancels",
    combo_prefix        = "Combo x",

    -- Result dialogs
    result_level_win_title = "Level complete!",
    result_final_win_title = "All levels complete!",
    result_loss_title   = "Game Over!",
    state_timeout       = "Time's up!",
    result_level        = "Level: %d",
    result_level_score  = "Level score: %s",
    result_total_score  = "Total score: %s",
    result_max_combo    = "Best combo: x%d",
    result_powerups     = "PowerUps used: %d",

    -- PowerUps
    powerup_fire        = "Fire Nova",
    powerup_frost       = "Frost Nova",
    powerup_chain       = "Chain Lightning",
    powerup_bomb        = "Goblin Bomb",
    powerup_holy        = "Holy Beam",
    powerup_fire_desc   = "Destroys a cross of 5 tiles.",
    powerup_frost_desc  = "Clears an entire row or column.",
    powerup_chain_desc  = "Destroys all jewels of one color.",
    powerup_bomb_desc   = "3x3 explosion around the target.",
    powerup_holy_desc   = "Turns 3 random jewels into wildcards.",
    powerup_ready       = "Ready to use!",
    powerup_charging    = "Charging...",
    powerup_inv         = "Stock: %d/3",

    -- Obstacles
    obstacle_ice        = "Ice Block",
    obstacle_stone      = "Stone Block",
    obstacle_locked     = "Locked Tile",

    -- Difficulties
    diff_easy           = "Easy",
    diff_normal         = "Normal",
    diff_hard           = "Hard",

    -- Settings panel
    box_mode            = "Game Mode",
    box_sounds          = "Sound",
    box_guide           = "Guide",
    lbl_timer_check     = "Time mode (score x 1.5)",
    lbl_timer_on        = "Time mode",
    lbl_difficulty      = "Difficulty (for new games)",
    sound_enabled       = "Sound enabled",
    sound_match         = "Match sound",
    sound_powerup       = "PowerUp sound",
    sound_gameover      = "Game over sound",
    btn_reset           = "Reset",

    -- How to play
    guide_1             = "Goal: Meet the level goal (score or collect jewels) before you run out of moves.",
    guide_2             = "Swap adjacent jewels to form rows/columns of 3+, or make a 2x2 square.",
    guide_3             = "4-match: +50% points · 2x2: +25% · 5+: +100%, and all charge PowerUps.",
    guide_4             = "PowerUps charge through combos and points – max. 3 per type in stock.",
    guide_5             = "From level 21: ice (match next to it), stone (PowerUp only) and locked tiles.",
    guide_6             = "Time mode: a time limit instead of comfort – but score x 1.5.",
    guide_7             = "3 save slots · auto-save after each level · closing the tab pauses the level.",
})
