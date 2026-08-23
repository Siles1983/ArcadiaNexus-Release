-- ============================================================
--  AlienDefense – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "ALIENDEFENSE"
-- ============================================================

ArcadiaNexus.RegisterLocale("ALIENDEFENSE", "deDE", {
    game_title          = "Alien Defense",

    -- HUD
    lbl_score           = "Punkte",
    lbl_wave            = "Welle",
    lbl_lives           = "Leben",
    lbl_time            = "Zeit",
    lbl_highscore       = "Highscore",
    lbl_endless         = "Endlos",
    lbl_weapon          = "Waffe",

    -- Buttons
    btn_start           = "Spiel starten",
    btn_resume          = "Weiterspielen",
    btn_new_game        = "Neues Spiel",
    btn_exit            = "Beenden",
    btn_pause           = "Pause",
    btn_resume_game     = "Fortsetzen",
    btn_next_wave       = "Nächste Welle",
    btn_continue        = "Weiter",

    -- Schwierigkeiten
    diff_easy           = "Einfach",
    diff_normal         = "Normal",
    diff_hard           = "Schwer",

    -- Zustände
    state_idle          = "Schwierigkeit wählen",
    state_paused        = "Pause",
    state_win           = "Welle überstanden!",
    state_gameover      = "Spiel vorbei!",
    state_invaded       = "Invasion! Die Aliens haben die Basis erreicht!",
    state_resume_hint   = "Gespeichertes Spiel gefunden – Weiterspielen?",

    -- Save-Slots
    menu_title          = "Alien Defense",
    slot_info           = "Welle %d · %s",
    slot_paused         = "läuft",
    hint_select_slot    = "Wähle einen Speicherslot",
    confirm_overwrite   = "Spielstand überschreiben?",
    confirm_overwrite_body = "Slot %d enthält einen Spielstand.",
    confirm_delete      = "Spielstand wirklich löschen?",
    confirm_delete_body = "Slot %d wird geleert.",

    -- Waffen
    weapon_single       = "Einzelschuss",
    weapon_double       = "Doppelschuss",
    weapon_laser        = "Laser",
    weapon_drop_double  = "Doppelschuss eingesammelt!",
    weapon_drop_laser   = "Laser eingesammelt!",

    -- Sound-Labels
    sound_shoot         = "Schuss",
    sound_aliendeath    = "Alien besiegt",
    sound_playerhit     = "Spieler getroffen",
    sound_weapondrop    = "Waffen-Drop",
    sound_win           = "Sieg",
    sound_lose          = "Niederlage",
    lbl_screen_flash    = "Screen-Flash",

    -- Spielanleitung
    guide_1             = "A / Linkspfeil: Schiff nach links",
    guide_2             = "D / Rechtspfeil: Schiff nach rechts",
    guide_3             = "Leertaste (halten): Feuer",
    guide_4             = "W / S: Waffe wechseln",
    guide_5             = "Enter: Pause / Fortsetzen",
    guide_6             = "Besiege alle Aliens bevor sie die Basis erreichen.",
    guide_7             = "Eingesammelte Waffendrops sind 15 Sekunden aktiv.",

    -- Settings-Boxen
    box_sounds          = "Sound",
    box_visuals         = "Visuelles",
    box_guide           = "Anleitung",

    -- Overlay
    popup_score         = "Punkte:",
    popup_wave          = "Welle:",
    popup_bonus         = "Wellen-Bonus:",
    popup_play_again    = "Nochmal",
    popup_next_wave     = "Nächste Welle",
    popup_exit          = "Beenden",

    -- Reset
    btn_reset           = "Reset",
})

ArcadiaNexus.RegisterLocale("ALIENDEFENSE", "enUS", {
    game_title          = "Alien Defense",

    -- HUD
    lbl_score           = "Score",
    lbl_wave            = "Wave",
    lbl_lives           = "Lives",
    lbl_time            = "Time",
    lbl_highscore       = "Highscore",
    lbl_endless         = "Endless",
    lbl_weapon          = "Weapon",

    -- Buttons
    btn_start           = "Start Game",
    btn_resume          = "Resume",
    btn_new_game        = "New Game",
    btn_exit            = "Exit",
    btn_pause           = "Pause",
    btn_resume_game     = "Resume",
    btn_next_wave       = "Next Wave",
    btn_continue        = "Continue",

    -- Schwierigkeiten
    diff_easy           = "Easy",
    diff_normal         = "Normal",
    diff_hard           = "Hard",

    -- Zustände
    state_idle          = "Choose Difficulty",
    state_paused        = "Paused",
    state_win           = "Wave Cleared!",
    state_gameover      = "Game Over!",
    state_invaded       = "Invaded! The aliens reached the base!",
    state_resume_hint   = "Saved game found – Resume?",

    -- Save slots
    menu_title          = "Alien Defense",
    slot_info           = "Wave %d · %s",
    slot_paused         = "in progress",
    hint_select_slot    = "Choose a save slot",
    confirm_overwrite   = "Overwrite save?",
    confirm_overwrite_body = "Slot %d already has a save.",
    confirm_delete      = "Delete this save?",
    confirm_delete_body = "Slot %d will be cleared.",

    -- Waffen
    weapon_single       = "Single",
    weapon_double       = "Double Shot",
    weapon_laser        = "Laser",
    weapon_drop_double  = "Double Shot collected!",
    weapon_drop_laser   = "Laser collected!",

    -- Sound-Labels
    sound_shoot         = "Shot Fired",
    sound_aliendeath    = "Alien Killed",
    sound_playerhit     = "Player Hit",
    sound_weapondrop    = "Weapon Drop",
    sound_win           = "Victory",
    sound_lose          = "Defeat",
    lbl_screen_flash    = "Screen Flash",

    -- Spielanleitung
    guide_1             = "A / Left Arrow: Move ship left",
    guide_2             = "D / Right Arrow: Move ship right",
    guide_3             = "Space (hold): Fire",
    guide_4             = "W / S: Cycle weapon",
    guide_5             = "Enter: Pause / Resume",
    guide_6             = "Defeat all aliens before they reach the base.",
    guide_7             = "Collected weapon drops are active for 15 seconds.",

    -- Settings-Boxen
    box_sounds          = "Sound",
    box_visuals         = "Visuals",
    box_guide           = "Guide",

    -- Overlay
    popup_score         = "Score:",
    popup_wave          = "Wave:",
    popup_bonus         = "Wave Bonus:",
    popup_play_again    = "Play Again",
    popup_next_wave     = "Next Wave",
    popup_exit          = "Exit",

    -- Reset
    btn_reset           = "Reset",
})
