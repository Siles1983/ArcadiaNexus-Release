-- ============================================================
--  BlockBreaker – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "BLOCKBREAKER"
-- ============================================================

ArcadiaNexus.RegisterLocale("BLOCKBREAKER", "deDE", {
    -- Saved run overview. Cleared stages can be replayed; the scored run stays parked.
    map_title = "Laufübersicht · Level %d–%d",
    map_summary = "%s · Level %d · Punkte %s · Leben %d",
    map_current = "Hier",
    map_done = "OK",
    map_resume = "Fortsetzen",
    map_help = "Geschaffte Level können wiederholt werden. Fortsetzen lädt die gespeicherte Partie.",
    result_practice = "Wiederholung. Punkte und die Partie bleiben unverändert.",
    map_legacy = "Altstand: %s",

    game_title        = "BlockBreaker",

    -- HUD
    lbl_score         = "Punkte",
    lbl_level         = "Level",
    lbl_lives         = "Leben",
    lbl_time          = "Zeit",
    lbl_highscore     = "Highscore",
    lbl_endless       = "Endlos",
    lbl_combo         = "Combo",
    hint_serve        = "Leertaste",

    -- Buttons
    btn_start         = "Spiel starten",
    btn_resume        = "Weiterspielen",
    btn_new_game      = "Neues Spiel",
    btn_exit          = "Beenden",
    btn_pause         = "Pause",
    btn_continue      = "Weiter",
    btn_next_level    = "Nächstes Level",
    btn_level_select  = "Levelauswahl",
    btn_repeat_level  = "Level wiederholen",
    btn_replay_level  = "Wiederholen",

    -- Schwierigkeiten
    diff_easy         = "Einfach",
    diff_normal       = "Normal",
    diff_hard         = "Schwer",

    -- Zustände
    state_idle        = "Schwierigkeit wählen",
    state_paused      = "Pause",
    state_win         = "Level geschafft!",
    state_gameover    = "Spiel vorbei!",
    state_resume_hint = "Gespeichertes Spiel gefunden – Weiterspielen?",

    -- Save-Slots
    menu_title        = "BlockBreaker",
    slot_info         = "Level %d · %s",
    slot_paused       = "läuft",
    hint_select_slot  = "Wähle einen Speicherslot",
    confirm_overwrite = "Spielstand überschreiben?",
    confirm_overwrite_body = "Slot %d enthält einen Spielstand.",
    confirm_delete    = "Spielstand wirklich löschen?",
    confirm_delete_body = "Slot %d wird geleert.",

    -- Theme
    box_theme         = "Theme",
    theme_random      = "Zufall",
    theme_blue        = "Blau",
    theme_green       = "Grün",
    theme_red         = "Rot",
    theme_violett     = "Lila",
    theme_yellow      = "Gelb",

    -- Power-Ups
    pu_lives          = "+1 Leben!",
    pu_score250       = "+250 Punkte!",
    pu_score500       = "+500 Punkte!",
    pu_big            = "Paddle x2!",
    pu_bullet         = "Extra-Ball!",
    pu_fast           = "Turbo!",
    pu_slow           = "Zeitlupe!",
    pu_small          = "Paddle schmaler!",
    pu_strength       = "Stärke!",
    pu_bomb           = "Bombe!",
    pu_ironguard      = "Eisenwache!",
    pu_berserk        = "Berserker!",

    -- Sound-Labels (SettingsPanel)
    sound_bounce      = "Abprall",
    sound_break       = "Block zerstört",
    sound_powerup     = "Power-Up",
    sound_lifelost    = "Leben verloren",
    sound_win         = "Sieg",
    sound_lose        = "Niederlage",
    lbl_screen_flash  = "Screen-Flash",
    lbl_reduced_motion = "Weniger Bewegung",

    -- Spielanleitung
    guide_1           = "A / Linkspfeil: Paddle nach links",
    guide_2           = "D / Rechtspfeil: Paddle nach rechts",
    guide_3           = "Leertaste: Ball starten, danach Pause. P: Pause / Fortsetzen",
    guide_4           = "Zerstöre alle zerstörbaren Blöcke; permanente Wände bleiben bestehen.",
    guide_5           = "Gepanzerte Blöcke (heller Rahmen) brauchen 2 Treffer.",
    guide_6           = "Goldene Blöcke droppen sicher, andere zerstörte Blöcke mit 8% Chance.",
    guide_7           = "Maximal 3 Bälle und 5 Leben. Ein Leben geht erst verloren, wenn der letzte Ball fällt.",
    guide_8           = "Nach Start, Levelwechsel und Lebenverlust klebt der Ball am Paddle, bis du ihn mit Leertaste startest.",

    guide_9="100 reguläre Level gewinnen den Lauf einmal. Danach optional Endlos; keine zweite Belohnung. Escape: speichern und verlassen.",
    guide_10="Combo zählt zerstörte Blöcke ohne Paddlekontakt: 5 Treffer = Faktor 1,4. Stärke durchschlägt zerstörbare Blöcke, keine permanenten Wände.",
    guide_11="Turbo/Zeitlupe ändern Ball UND Paddle um ±50%. Klein halbiert die Basisbreite bis mindestens 32 Pixel. Groß 10 s, andere zeitliche Power-Ups 8 s.",
    lbl_balls="Bälle", lbl_level_score="Levelpunkte", btn_endless="Endlos fortsetzen",
    state_campaign_win="100 Level geschafft!", state_run_ended="Erfolgreicher Lauf beendet",
    level_no_reward="Etappenleistung – Partiebelohnung nach 100 Leveln",
    legacy_save="Altfortsetzung: Etappe neu", legacy_points="Altpunkte",
    combo_help="Trefferkette ohne Paddlekontakt. Punktefaktor: 1 + 0,1 × (Combo − 1).",
    powerup_help="Stärke durchschlägt zerstörbare Blöcke, keine Wände. Turbo/Zeitlupe beeinflussen Ball und Paddle. Klein: halbe Basisbreite, mindestens 32 Pixel.",

    -- DevMode (F8)
    dev_pu_title      = "F8  DevMode",
    dev_level_label   = "Level 1–100",
    dev_level_go      = "Laden",
    dev_test_hint     = "Test: ohne Wertung",
    dev_pu_lives      = "Leben",
    dev_pu_score250   = "+250",
    dev_pu_score500   = "+500",
    dev_pu_big        = "Breit",
    dev_pu_bullet     = "Ball",
    dev_pu_fast       = "Turbo",
    dev_pu_slow       = "Langsam",
    dev_pu_small      = "Schmal",
    dev_pu_strength   = "Stärke",

    -- Settings-Boxen
    box_difficulty    = "Schwierigkeit",
    box_sounds        = "Sound",
    box_visuals       = "Visuelles",
    sound_enabled     = "Sound aktiviert",
    box_guide         = "Anleitung",
    box_stats         = "Statistiken",

    -- Stats
    lbl_played        = "Gespielt",
    lbl_wins          = "Siege",
    lbl_losses        = "Niederlagen",
    lbl_top3          = "Top 3",

    -- Overlay
    popup_score       = "Punkte:",
    popup_level       = "Level:",
    popup_play_again  = "Nochmal",
    popup_exit        = "Beenden",
    popup_resume      = "Weiterspielen",
    popup_new_game    = "Neues Spiel",

    -- Reset
    btn_reset         = "Reset",
})

ArcadiaNexus.RegisterLocale("BLOCKBREAKER", "enUS", {
    -- Saved run overview. Cleared stages can be replayed; the scored run stays parked.
    map_title = "Run overview · Levels %d–%d",
    map_summary = "%s · Level %d · Score %s · Lives %d",
    map_current = "Here",
    map_done = "OK",
    map_resume = "Continue",
    map_help = "Cleared levels can be replayed. Continue loads the saved run.",
    result_practice = "Replay. Score and the saved run stay unchanged.",
    map_legacy = "Historical score: %s",

    game_title        = "BlockBreaker",

    -- HUD
    lbl_score         = "Score",
    lbl_level         = "Level",
    lbl_lives         = "Lives",
    lbl_time          = "Time",
    lbl_highscore     = "Highscore",
    lbl_endless       = "Endless",
    lbl_combo         = "Combo",
    hint_serve        = "Space",

    -- Buttons
    btn_start         = "Start Game",
    btn_resume        = "Resume",
    btn_new_game      = "New Game",
    btn_exit          = "Exit",
    btn_pause         = "Pause",
    btn_continue      = "Continue",
    btn_next_level    = "Next Level",
    btn_level_select  = "Level Select",
    btn_repeat_level  = "Replay Level",
    btn_replay_level  = "Replay",

    -- Schwierigkeiten
    diff_easy         = "Easy",
    diff_normal       = "Normal",
    diff_hard         = "Hard",

    -- Zustände
    state_idle        = "Choose Difficulty",
    state_paused      = "Paused",
    state_win         = "Level Complete!",
    state_gameover    = "Game Over!",
    state_resume_hint = "Saved game found – Resume?",

    -- Save slots
    menu_title        = "BlockBreaker",
    slot_info         = "Level %d · %s",
    slot_paused       = "in progress",
    hint_select_slot  = "Choose a save slot",
    confirm_overwrite = "Overwrite save?",
    confirm_overwrite_body = "Slot %d already has a save.",
    confirm_delete    = "Delete this save?",
    confirm_delete_body = "Slot %d will be cleared.",

    -- Theme
    box_theme         = "Theme",
    theme_random      = "Random",
    theme_blue        = "Blue",
    theme_green       = "Green",
    theme_red         = "Red",
    theme_violett     = "Purple",
    theme_yellow      = "Yellow",

    -- Power-Ups
    pu_lives          = "+1 Life!",
    pu_score250       = "+250 Points!",
    pu_score500       = "+500 Points!",
    pu_big            = "Paddle x2!",
    pu_bullet         = "Extra Ball!",
    pu_fast           = "Turbo!",
    pu_slow           = "Slow-Mo!",
    pu_small          = "Narrow Paddle!",
    pu_strength       = "Strength!",
    pu_bomb           = "Bomb!",
    pu_ironguard      = "Iron Guard!",
    pu_berserk        = "Berserk!",

    -- Sound-Labels
    sound_bounce      = "Bounce",
    sound_break       = "Block Break",
    sound_powerup     = "Power-Up",
    sound_lifelost    = "Life Lost",
    sound_win         = "Victory",
    sound_lose        = "Defeat",
    lbl_screen_flash  = "Screen Flash",
    lbl_reduced_motion = "Reduce motion",

    -- Spielanleitung
    guide_1           = "A / Left Arrow: Move paddle left",
    guide_2           = "D / Right Arrow: Move paddle right",
    guide_3           = "Space: serve the ball, then Pause. P: Pause / Resume",
    guide_4           = "Destroy all breakable blocks; permanent walls remain.",
    guide_5           = "Armored blocks (bright border) require 2 hits.",
    guide_6           = "Golden blocks always drop power-ups; other destroyed blocks have an 8% chance.",
    guide_7           = "Maximum 3 balls and 5 lives. A life is lost only when the last ball falls.",
    guide_8           = "After start, next level, or a lost life the ball sticks to the paddle until you serve with Space.",

    guide_9="Complete 100 regular levels to win once, then optionally continue endless without another reward. Escape: save and exit.",
    guide_10="Combo counts destroyed blocks without paddle contact: 5 hits = factor 1.4. Strength pierces breakable blocks, never permanent walls.",
    guide_11="Fast/slow change BOTH ball and paddle speed by ±50%. Small halves base width down to 32 pixels. Big lasts 10 s; other timed power-ups last 8 s.",
    lbl_balls="Balls", lbl_level_score="Level score", btn_endless="Continue endless",
    state_campaign_win="100 levels completed!", state_run_ended="Successful run ended",
    level_no_reward="Stage performance – run reward after 100 levels",
    legacy_save="Legacy continuation: stage restarted", legacy_points="Old points",
    combo_help="Block chain without paddle contact. Score factor: 1 + 0.1 × (Combo − 1).",
    powerup_help="Strength pierces breakable blocks, never walls. Fast/slow affect ball and paddle. Small: half base width, at least 32 pixels.",

    -- DevMode (F8)
    dev_pu_title      = "F8  DevMode",
    dev_level_label   = "Level 1–100",
    dev_level_go      = "Load",
    dev_test_hint     = "Test: unranked",
    dev_pu_lives      = "Life",
    dev_pu_score250   = "+250",
    dev_pu_score500   = "+500",
    dev_pu_big        = "Wide",
    dev_pu_bullet     = "Ball",
    dev_pu_fast       = "Fast",
    dev_pu_slow       = "Slow",
    dev_pu_small      = "Narrow",
    dev_pu_strength   = "Power",

    -- Settings-Boxen
    box_difficulty    = "Difficulty",
    box_sounds        = "Sound",
    box_visuals       = "Visuals",
    sound_enabled     = "Sound enabled",
    box_guide         = "Guide",
    box_stats         = "Statistics",

    -- Stats
    lbl_played        = "Played",
    lbl_wins          = "Wins",
    lbl_losses        = "Losses",
    lbl_top3          = "Top 3",

    -- Overlay
    popup_score       = "Score:",
    popup_level       = "Level:",
    popup_play_again  = "Play Again",
    popup_exit        = "Exit",
    popup_resume      = "Resume",
    popup_new_game    = "New Game",

    -- Reset
    btn_reset         = "Reset",
})
