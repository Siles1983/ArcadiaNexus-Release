-- ============================================================
--  ArgusOrbitDefense – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "ARGUSORBDEFENSE"
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.RegisterLocale("ARGUSORBDEFENSE", "deDE", {
    game_title        = "Argus Orbit Defense",

    -- HUD
    lbl_score         = "Punkte",
    lbl_wave          = "Welle",
    lbl_level         = "Level",
    lbl_lives         = "Leben",
    lbl_highscore     = "Highscore",

    -- Buttons
    btn_start_endless = "Endlos starten",
    btn_start_levels  = "Level-Modus starten",
    btn_resume        = "Weiterspielen",
    btn_new_game      = "Neues Spiel",
    btn_exit          = "Beenden",
    btn_pause         = "Pause",
    btn_continue      = "Weiter",
    btn_start         = "Spiel starten",

    -- Modi
    mode_endless      = "Endlos",
    mode_levels       = "Level-Modus",

    -- Schwierigkeiten (Dropdown)
    diff_easy         = "Einfach",
    diff_normal       = "Normal",
    diff_hard         = "Schwer",

    -- Zustände
    state_idle        = "Modus & Schwierigkeit wählen",
    state_paused      = "Pause",
    state_wave_clear  = "Level geschafft!",
    state_victory     = "Argus verteidigt!",
    state_gameover    = "Schiff zerstört!",
    state_resume_hint = "Gespeichertes Spiel gefunden – Weiterspielen?",

    -- Save-Slots
    menu_title        = "Argus Orbit Defense",
    slot_info         = "Level %d · %s",
    slot_paused       = "läuft",
    hint_select_slot  = "Wähle einen Speicherslot",
    confirm_overwrite = "Spielstand überschreiben?",
    confirm_overwrite_body = "Slot %d enthält einen Spielstand.",
    confirm_delete    = "Spielstand wirklich löschen?",
    confirm_delete_body = "Slot %d wird geleert.",

    -- Power-Ups
    powerup_shield    = "Heiliger Schild",
    powerup_rapid     = "Schnellfeuer",
    powerup_spread    = "Streuschuss",
    powerup_bomb      = "Naaru-Bombe",
    powerup_life      = "Extraleben",

    -- Sound-Labels (SettingsPanel)
    sound_master         = "Sound aktiviert",
    sound_shoot          = "Schuss",
    sound_explode        = "Explosion",
    sound_powerup_bomb   = "Power-Up: Bombe",
    sound_powerup_life   = "Power-Up: Leben",
    sound_powerup_shield = "Power-Up: Schild",
    sound_engine         = "Triebwerk",
    sound_waveclear      = "Welle geschafft",
    sound_win            = "Sieg",
    sound_lose           = "Niederlage",
    lbl_screen_flash     = "Screen-Flash",

    -- Spielanleitung
    guide_1           = "W / Pfeil oben: Schub",
    guide_2           = "A / Pfeil links: Links drehen",
    guide_3           = "D / Pfeil rechts: Rechts drehen",
    guide_4           = "Leertaste: Schießen",
    guide_5           = "ESC: Pause / Fortsetzen",
    guide_6           = "Meteore teilen sich: Groß -> 2 Mittel -> 2 Klein -> zerstört.",
    guide_7           = "Fel Hunter verfolgen dich – schieß sie zuerst ab!",
    guide_8           = "Power-Ups stapeln sich bis zur doppelten Laufzeit (SHIELD/RAPID/SPREAD). Die Bombe zerstört alle Objekte im Umkreis.",
    guide_9           = "Power-Up-Farben: Gelb=Schild  Rot=Schnellfeuer  Blau=Streuschuss  Orange=Bombe  Grün=Leben",

    -- Settings-Boxen
    box_gamemode      = "Spielmodus",
    box_difficulty    = "Schwierigkeit",
    box_sounds        = "Sound",
    box_visuals       = "Visuelles",
    box_guide         = "Anleitung",
    box_stats         = "Statistiken",

    -- Stats
    lbl_played        = "Gespielt",
    lbl_wins          = "Siege",
    lbl_losses        = "Niederlagen",
    lbl_top3          = "Top 3",
    lbl_meteors       = "Meteore zerstört",
    lbl_hunters       = "Fel Hunter abgeschossen",

    -- Overlay
    popup_score       = "Punkte:",
    popup_wave        = "Welle:",
    popup_level       = "Level:",
    popup_play_again  = "Nochmal",
    popup_exit        = "Beenden",
    popup_resume      = "Weiterspielen",
    popup_new_game    = "Neues Spiel",

    -- Reset
    btn_reset         = "Reset",

    -- Endlosmodus-Checkbox
    lbl_endless       = "Endlos",
})

ArcadiaNexus.RegisterLocale("ARGUSORBDEFENSE", "enUS", {
    game_title        = "Argus Orbit Defense",

    -- HUD
    lbl_score         = "Score",
    lbl_wave          = "Wave",
    lbl_level         = "Level",
    lbl_lives         = "Lives",
    lbl_highscore     = "Highscore",

    -- Buttons
    btn_start_endless = "Start Endless",
    btn_start_levels  = "Start Level Mode",
    btn_resume        = "Resume",
    btn_new_game      = "New Game",
    btn_exit          = "Exit",
    btn_pause         = "Pause",
    btn_continue      = "Continue",
    btn_start         = "Start Game",

    -- Modi
    mode_endless      = "Endless",
    mode_levels       = "Level Mode",

    -- Schwierigkeiten
    diff_easy         = "Easy",
    diff_normal       = "Normal",
    diff_hard         = "Hard",

    -- Zustände
    state_idle        = "Choose Mode & Difficulty",
    state_paused      = "Paused",
    state_wave_clear  = "Level Clear!",
    state_victory     = "Argus Defended!",
    state_gameover    = "Ship Destroyed!",
    state_resume_hint = "Saved game found – Resume?",

    -- Save slots
    menu_title        = "Argus Orbit Defense",
    slot_info         = "Level %d · %s",
    slot_paused       = "in progress",
    hint_select_slot  = "Choose a save slot",
    confirm_overwrite = "Overwrite save?",
    confirm_overwrite_body = "Slot %d already has a save.",
    confirm_delete    = "Delete this save?",
    confirm_delete_body = "Slot %d will be cleared.",

    -- Power-Ups
    powerup_shield    = "Holy Shield",
    powerup_rapid     = "Rapid Fire",
    powerup_spread    = "Spread Shot",
    powerup_bomb      = "Naaru Bomb",
    powerup_life      = "Extra Life",

    -- Sound-Labels
    sound_master         = "Sound enabled",
    sound_shoot          = "Shoot",
    sound_explode        = "Explosion",
    sound_powerup_bomb   = "Power-Up: Bomb",
    sound_powerup_life   = "Power-Up: Life",
    sound_powerup_shield = "Power-Up: Shield",
    sound_engine         = "Engine",
    sound_waveclear      = "Wave Clear",
    sound_win            = "Victory",
    sound_lose           = "Defeat",
    lbl_screen_flash     = "Screen Flash",

    -- Spielanleitung
    guide_1           = "W / Arrow Up: Thrust",
    guide_2           = "A / Arrow Left: Rotate Left",
    guide_3           = "D / Arrow Right: Rotate Right",
    guide_4           = "Space: Shoot",
    guide_5           = "ESC: Pause / Resume",
    guide_6           = "Meteors split: Large -> 2 Medium -> 2 Small -> destroyed.",
    guide_7           = "Fel Hunters track you - shoot them first!",
    guide_8           = "Power-Ups stack up to double duration (SHIELD/RAPID/SPREAD). Bomb destroys all objects in range.",
    guide_9           = "Power-Up colors: Yellow=Shield  Red=Rapid Fire  Blue=Spread  Orange=Bomb  Green=Life",

    -- Settings-Boxen
    box_gamemode      = "Game Mode",
    box_difficulty    = "Difficulty",
    box_sounds        = "Sound",
    box_visuals       = "Visuals",
    box_guide         = "Guide",
    box_stats         = "Statistics",

    -- Stats
    lbl_played        = "Played",
    lbl_wins          = "Wins",
    lbl_losses        = "Losses",
    lbl_top3          = "Top 3",
    lbl_meteors       = "Meteors Destroyed",
    lbl_hunters       = "Fel Hunters Shot Down",

    -- Overlay
    popup_score       = "Score:",
    popup_wave        = "Wave:",
    popup_level       = "Level:",
    popup_play_again  = "Play Again",
    popup_exit        = "Exit",
    popup_resume      = "Resume",
    popup_new_game    = "New Game",

    -- Reset
    btn_reset         = "Reset",

    -- Endlosmodus-Checkbox
    lbl_endless       = "Endless",
})
