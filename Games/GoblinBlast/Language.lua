--[[
    ArcadiaNexus – Goblin Blast
    Games/GoblinBlast/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Goblin Blast.
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("GOBLINBLAST")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("GOBLINBLAST", "deDE", {

    -- Schwierigkeits-Buttons (Renderer)
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Buttons (Renderer)
    btn_start        = "Spiel starten",
    btn_exit         = "Beenden",
    btn_new_game     = "Neues Spiel",
    btn_new_game_ov  = "Neues Spiel",
    btn_resume       = "Weiterspielen",
    btn_next_level   = "Nächstes Level",
    btn_level_select = "Neu starten",

    -- Hint (Renderer)
    hint_start        = "|cffaaaaaa Wähle eine Schwierigkeit um zu starten.\n\nSteuerung: WASD / Pfeiltasten – Leertaste legt Bomben|r",
    state_resume_hint = "Gespeicherter Spielstand vorhanden",

    -- Save-Slots
    menu_title        = "Goblin Blast",
    slot_info         = "Level %d · %s",
    slot_paused       = "läuft",
    hint_select_slot  = "Wähle einen Speicherslot",
    confirm_overwrite = "Spielstand überschreiben?",
    confirm_overwrite_body = "Slot %d enthält einen Spielstand.",
    confirm_delete    = "Spielstand wirklich löschen?",
    confirm_delete_body = "Slot %d wird geleert.",

    -- HUD-Labels
    lbl_score       = "Punkte",
    lbl_highscore   = "Highscore",
    lbl_lives       = "Leben",
    lbl_enemies     = "Gegner",
    lbl_walls       = "Wände",
    lbl_level       = "Level",
    lbl_time        = "Zeit",
    lbl_bombs       = "Bomben",
    lbl_radius      = "Radius",

    -- Overlay: Level geschafft / Finale / Niederlage (Renderer)
    result_level_win_title = "|cff40ff40Level geschafft!|r",
    result_final_win_title = "|cffffd700Alle Level geschafft!|r",
    result_loss_title      = "|cffff4444Spiel vorbei!|r",
    result_level           = "|cffaaaaaa Level:|r |cffffff00%d|r",
    result_walls           = "|cffaaaaaa Wände zerstört:|r |cffffff00%d|r",
    result_enemies         = "|cffaaaaaa Gegner besiegt:|r |cffffff00%d|r",
    result_time            = "|cffaaaaaa Zeit:|r |cffffff00%d:%02d|r",
    result_time_bonus      = "|cffaaaaaa Zeitbonus:|r |cff40ff40+%d|r",

    -- Settings-Panel: Box-Titel
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_explode   = "Explosion",
    sound_powerup   = "Power-up",
    sound_die       = "Treffer / Spiel vorbei",
    sound_win       = "Sieg",

    -- Settings-Panel: Spielanleitung
    guide_goal      = "|cffffff00Ziel:|r Besiege in 12 Leveln alle Gegner mit deinen Bomben, ohne selbst getroffen zu werden!",
    guide_controls  = "|cffffff00Steuerung:|r WASD oder Pfeiltasten bewegen. Leertaste legt eine Bombe. ESC unterbricht (Fortschritt wird gespeichert).",
    guide_bombs     = "|cffffff00Bomben:|r Explodieren nach 2,5 Sekunden im Kreuz. Explosionen zünden andere Bomben (Kettenreaktion!).",
    guide_powerups  = "|cffffff00Power-ups:|r Zerstörte Wände hinterlassen manchmal Extras – |cffff8800orange|r = größerer Radius, |cff4db8ffblau|r = mehr Bomben.",
    guide_levels    = "|cffffff00Level:|r 12 Level mit mehr Gegnern, mehr Tempo und dichteren Wänden. Ab Level 4 legen Gegner selbst Bomben!",
    guide_timer     = "|cffffff00Timer:|r Je schneller du ein Level schaffst, desto höher der Zeitbonus auf deine Punkte.",
    guide_score     = "|cffffff00Punkte:|r Wand = 10 · Gegner = 100 · Level = +500 + Zeitbonus (Einfach x1 · Normal x2 · Schwer x4).",
    guide_diff      = "|cffffff00Schwierigkeit:|r Einfach = langsame Gegner, Normal = +1 Gegner pro Level, Schwer = +2 Gegner, schnelleres Tempo, mehr Gegner-Bomben, nur 2 Leben.",
    guide_hint      = "|cffaaaaaa Ein unterbrochenes Spiel kann über den Weiterspielen-Button fortgesetzt werden.|r",

    -- Reset
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("GOBLINBLAST", "enUS", {

    -- Difficulty buttons
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Buttons
    btn_start        = "Start Game",
    btn_exit         = "Exit",
    btn_new_game     = "New Game",
    btn_new_game_ov  = "New Game",
    btn_resume       = "Continue",
    btn_next_level   = "Next Level",
    btn_level_select = "Restart Run",

    -- Hint
    hint_start        = "|cffaaaaaa Choose a difficulty to start.\n\nControls: WASD / Arrow Keys – Spacebar drops bombs|r",
    state_resume_hint = "Saved game available",

    -- Save slots
    menu_title        = "Goblin Blast",
    slot_info         = "Level %d · %s",
    slot_paused       = "in progress",
    hint_select_slot  = "Choose a save slot",
    confirm_overwrite = "Overwrite save?",
    confirm_overwrite_body = "Slot %d already has a save.",
    confirm_delete    = "Delete this save?",
    confirm_delete_body = "Slot %d will be cleared.",

    -- HUD labels
    lbl_score       = "Score",
    lbl_highscore   = "Highscore",
    lbl_lives       = "Lives",
    lbl_enemies     = "Enemies",
    lbl_walls       = "Walls",
    lbl_level       = "Level",
    lbl_time        = "Time",
    lbl_bombs       = "Bombs",
    lbl_radius      = "Radius",

    -- Overlay
    result_level_win_title = "|cff40ff40Level cleared!|r",
    result_final_win_title = "|cffffd700All levels cleared!|r",
    result_loss_title      = "|cffff4444Game Over!|r",
    result_level           = "|cffaaaaaa Level:|r |cffffff00%d|r",
    result_walls           = "|cffaaaaaa Walls destroyed:|r |cffffff00%d|r",
    result_enemies         = "|cffaaaaaa Enemies defeated:|r |cffffff00%d|r",
    result_time            = "|cffaaaaaa Time:|r |cffffff00%d:%02d|r",
    result_time_bonus      = "|cffaaaaaa Time bonus:|r |cff40ff40+%d|r",

    -- Settings boxes
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_explode   = "Explosion",
    sound_powerup   = "Power-up",
    sound_die       = "Hit / Game Over",
    sound_win       = "Victory",

    -- Guide
    guide_goal      = "|cffffff00Goal:|r Defeat all enemies across 12 levels with your bombs without getting hit!",
    guide_controls  = "|cffffff00Controls:|r Move with WASD or Arrow Keys. Spacebar drops a bomb. ESC interrupts (progress is saved).",
    guide_bombs     = "|cffffff00Bombs:|r Explode after 2.5 seconds in a cross shape. Explosions ignite other bombs (chain reaction!).",
    guide_powerups  = "|cffffff00Power-ups:|r Destroyed walls sometimes drop extras – |cffff8800orange|r = bigger radius, |cff4db8ffblue|r = more bombs.",
    guide_levels    = "|cffffff00Levels:|r 12 levels with more enemies, higher speed and denser walls. From level 4 enemies drop bombs themselves!",
    guide_timer     = "|cffffff00Timer:|r The faster you clear a level, the higher the time bonus added to your score.",
    guide_score     = "|cffffff00Score:|r Wall = 10 · Enemy = 100 · Level = +500 + time bonus (Easy x1 · Normal x2 · Hard x4).",
    guide_diff      = "|cffffff00Difficulty:|r Easy = slow enemies, Normal = +1 enemy per level, Hard = +2 enemies, faster pace, more enemy bombs, only 2 lives.",
    guide_hint      = "|cffaaaaaa An interrupted game can be resumed via the Continue button.|r",

    -- Reset
    btn_reset       = "Reset",
})
