-- ============================================================
--  BlockBreaker – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "BLOCKBREAKER"
-- ============================================================

ArcadiaNexus.RegisterLocale("BLOCKBREAKER", "deDE", {
    game_title        = "BlockBreaker",

    -- HUD
    lbl_score         = "Punkte",
    lbl_level         = "Level",
    lbl_lives         = "Leben",
    lbl_time          = "Zeit",
    lbl_highscore     = "Highscore",
    lbl_endless       = "Endlos",

    -- Buttons
    btn_start         = "Spiel starten",
    btn_resume        = "Weiterspielen",
    btn_new_game      = "Neues Spiel",
    btn_exit          = "Beenden",
    btn_pause         = "Pause",
    btn_continue      = "Weiter",
    btn_next_level    = "Nächstes Level",
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
    pu_small          = "Paddle halbiert!",
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

    -- Spielanleitung
    guide_1           = "A / Linkspfeil: Paddle nach links",
    guide_2           = "D / Rechtspfeil: Paddle nach rechts",
    guide_3           = "Leertaste: Pause / Fortsetzen",
    guide_4           = "Zerstöre alle Blöcke um das Level zu beenden.",
    guide_5           = "Gepanzerte Blöcke (heller Rahmen) brauchen 2 Treffer.",
    guide_6           = "Power-Ups fallen aus goldenen Blöcken.",

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
    game_title        = "BlockBreaker",

    -- HUD
    lbl_score         = "Score",
    lbl_level         = "Level",
    lbl_lives         = "Lives",
    lbl_time          = "Time",
    lbl_highscore     = "Highscore",
    lbl_endless       = "Endless",

    -- Buttons
    btn_start         = "Start Game",
    btn_resume        = "Resume",
    btn_new_game      = "New Game",
    btn_exit          = "Exit",
    btn_pause         = "Pause",
    btn_continue      = "Continue",
    btn_next_level    = "Next Level",
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
    pu_small          = "Paddle Halved!",
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

    -- Spielanleitung
    guide_1           = "A / Left Arrow: Move paddle left",
    guide_2           = "D / Right Arrow: Move paddle right",
    guide_3           = "Space: Pause / Resume",
    guide_4           = "Destroy all blocks to complete the level.",
    guide_5           = "Armored blocks (bright border) require 2 hits.",
    guide_6           = "Power-Ups drop from golden blocks.",

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
