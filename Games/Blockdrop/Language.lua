--[[
    ArcadiaNexus
    Games/Blockdrop/Language.lua

    Alle lokalisierbaren Strings fuer BlockDrop.
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("BLOCKDROP")
    WICHTIG: "Blockdrop" ist der korrekte Name – immer "BlockDrop" verwenden!
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("BLOCKDROP", "deDE", {

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    btn_pause       = "Pause",
    btn_resume      = "Weiter",

    -- Save-Slots
    menu_title      = "Blockdrop",
    slot_info       = "Level %d · %s",
    slot_paused     = "läuft",
    hint_select_slot = "Wähle einen Speicherslot",
    confirm_overwrite = "Spielstand überschreiben?",
    confirm_overwrite_body = "Slot %d enthält einen Spielstand.",
    confirm_delete  = "Spielstand wirklich löschen?",
    confirm_delete_body = "Slot %d wird geleert.",

    -- Hint (Renderer – Idle-State)
    hint_start      = "|cffaaaaaa Drücke \"Spiel starten\" um zu beginnen.|r",

    -- Side-Panel Labels (Renderer)
    label_next      = "|cffffff00Nächster:|r",
    label_score     = "Punkte",
    label_level     = "Level",
    label_lines     = "Reihen",
    label_best      = "Highscore",

    -- Pause-Overlay (Renderer)
    pause_text      = "|cffffff00PAUSE|r",

    -- Game-Over-Panel (Renderer)
    gameover_title  = "|cffFF4444Spiel vorbei|r",
    gameover_score  = "Punkte: ",
    gameover_lines  = "Reihen: ",
    gameover_best   = "Bestzeit: ",
    btn_retry       = "Nochmal!",
    btn_menu        = "Menü",

    -- Settings-Panel: Box-Titel
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    btn_reset       = "Reset",

    -- Settings-Panel: Hintergrund
    label_background = "Hintergrund",
    bg_classic       = "Klassisch",
    bg_alliance      = "Allianz",
    bg_horde         = "Horde",

    -- Settings-Panel: Vorschau-Hint
    hint_blocks     = "|cffaaaaaa7 Block-Typen – I O T L J S Z|r",

    -- Settings-Panel: Sounds
    snd_move          = "Block bewegen",
    snd_rotate        = "Block rotieren",
    snd_line          = "Reihe gelöscht",
    snd_blockdrop     = "BlockDrop! (4 Reihen)",
    snd_levelup       = "Level Up",

    -- Settings-Panel: Spielanleitung
    guide_controls  = "|cffffff00Steuerung:|r",
    guide_keys      = "  W / Pfeil hoch / Rechtsklick: Block rotieren     |    A / Linkspfeil: Links     |    D / Rechtspfeil: Rechts",
    guide_drop      = "  S / Pfeil runter: Softdrop halten (schneller fallen)      |    Leertaste: Harddrop (sofort sperren)",
    guide_empty     = "",
    guide_scoring   = "|cffffff00Punktesystem:|r",
    guide_score1    = "  1 Reihe = 40 x (Level+1)    |    2 Reihen = 100 x (Level+1)",
    guide_score2    = "  3 Reihen = 300 x (Level+1)  |    4 Reihen = 1200 x (Level+1): BlockDrop!",
    guide_mult      = "  Multiplikator: (Level+1). Level beginnt bei 0 und zählt als x1; jedes weitere Level erhöht den Faktor um 1.",
    guide_empty2    = "",
    guide_levelup   = "|cffffff00Level-Up:|r  Alle 10 gelöschten Reihen. Blöcke fallen schneller!",
    guide_highscore = "|cffffff00Highscore:|r  Top 3, wird pro Charakter gespeichert.",
    guide_sizes     = "  10 x 20 Blöcke – Klassisches Format. Siebener-Beutel: jede Form einmal, dann neu mischen.",
    guide_pause="  P / Gamepad-Pause: Pause und Fortsetzen. Escape: speichern und verlassen. Links/Rechts halten für Wiederholung.",
    guide_lock="  Kurze Einrastzeit am Boden; Bewegungen/Rotationen können sie nur begrenzt verlängern. Harddrop sperrt sofort, ohne Zusatzpunkte.",
    invalid_save="Spielstand kann nicht fortgesetzt werden",
    invalid_save_body="Ungültige oder unvollständige Brett-/Stein-/Restzeitdaten. Der gespeicherte Stand wurde nicht verändert.",
    legacy_save="Altfortsetzung: Brett erhalten, neue Uhren/Beutel ab gespeicherter Vorschau",

})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("BLOCKDROP", "enUS", {

    -- Buttons
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    btn_pause       = "Pause",
    btn_resume      = "Resume",

    -- Save slots
    menu_title      = "Blockdrop",
    slot_info       = "Level %d · %s",
    slot_paused     = "in progress",
    hint_select_slot = "Choose a save slot",
    confirm_overwrite = "Overwrite save?",
    confirm_overwrite_body = "Slot %d already has a save.",
    confirm_delete  = "Delete this save?",
    confirm_delete_body = "Slot %d will be cleared.",

    -- Hint
    hint_start      = "|cffaaaaaa Press \"Start Game\" to begin.|r",

    -- Side-Panel Labels
    label_next      = "|cffffff00Next:|r",
    label_score     = "Score",
    label_level     = "Level",
    label_lines     = "Lines",
    label_best      = "Highscore",

    -- Pause
    pause_text      = "|cffffff00PAUSE|r",

    -- Game-Over
    gameover_title  = "|cffFF4444Game Over|r",
    gameover_score  = "Score: ",
    gameover_lines  = "Lines: ",
    gameover_best   = "Best: ",
    btn_retry       = "Retry!",
    btn_menu        = "Menu",

    -- Settings boxes
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    btn_reset       = "Reset",

    -- Background dropdown
    label_background = "Background",
    bg_classic       = "Classic",
    bg_alliance      = "Alliance",
    bg_horde         = "Horde",

    -- Preview hint
    hint_blocks     = "|cffaaaaaa7 block types – I O T L J S Z|r",

    -- Settings-Panel: Sounds
    snd_move          = "Move block",
    snd_rotate        = "Rotate block",
    snd_line          = "Line cleared",
    snd_blockdrop     = "BlockDrop! (4 lines)",
    snd_levelup       = "Level Up",

    -- Guide
    guide_controls  = "|cffffff00Controls:|r",
    guide_keys      = "  W / Up Arrow / Right-click: Rotate block     |    A / Left Arrow: Left     |    D / Right Arrow: Right",
    guide_drop      = "  S / Down Arrow: Hold soft drop (faster fall)        |    Space: Hard drop (lock immediately)",
    guide_empty     = "",
    guide_scoring   = "|cffffff00Scoring:|r",
    guide_score1    = "  1 line = 40 x (Level+1)    |    2 lines = 100 x (Level+1)",
    guide_score2    = "  3 lines = 300 x (Level+1)  |    4 lines = 1200 x (Level+1): BlockDrop!",
    guide_mult      = "  Multiplier: (Level+1). Level starts at 0 and counts as x1; each further level raises the factor by 1.",
    guide_empty2    = "",
    guide_levelup   = "|cffffff00Level-Up:|r  Every 10 cleared lines. Blocks fall faster!",
    guide_highscore = "|cffffff00Highscore:|r  Top 3, saved per character.",
    guide_sizes     = "  10 x 20 blocks – classic format. Seven-piece bag: every shape once, then reshuffle.",
    guide_pause="  P / gamepad Pause: pause and resume. Escape: save and exit. Hold Left/Right for repeat movement.",
    guide_lock="  Brief lock delay on ground; moves/rotations can extend it a limited number of times. Hard drop locks immediately, no bonus points.",
    invalid_save="Unable to continue this save",
    invalid_save_body="Invalid or incomplete board/piece/clock data. The stored save has not been changed.",
    legacy_save="Legacy continuation: board retained, new clocks/bag after saved preview",

})
