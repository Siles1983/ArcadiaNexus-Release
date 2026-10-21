--[[
    Gaming Hub
    Games/Snake/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Snake.
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("SNAKE")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("SNAKE", "deDE", {

    -- Schwierigkeits-Buttons (Renderer)
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    btn_new_game    = "Neues Spiel",
    btn_new_game_ov = "Neues Spiel",

    -- Hint (Renderer)
    hint_start      = "|cffaaaaaa Wähle eine Schwierigkeit um zu starten.\n\nSteuerung: WASD oder Pfeiltasten|r",

    -- HUD-Labels
    lbl_score       = "Punkte",
    lbl_highscore   = "Highscore",
    lbl_length      = "Länge",

    -- Statusbar (Renderer)
    status_score    = "|cffaaaaaa Punkte:|r |cffffff00%d|r",
    status_best     = "|cffaaaaaa Best:|r |cffffd700%d|r",

    -- Overlay: Sieg (Renderer)
    result_win_title  = "|cffffd700Gewonnen!|r",
    -- Overlay: Verloren (Renderer)
    result_loss_title = "|cffff4444Spiel vorbei!|r",
    -- Overlay: gemeinsam (Renderer)
    result_sub        = "|cffaaaaaa Punkte:|r |cffffff00%d|r  |cffaaaaaa Länge:|r |cffffff00%d|r",
    result_new_hs     = "|cffffd700Neuer Highscore!|r",
    result_hs         = "|cffaaaaaa Highscore: |cffffff00%d|r",

    -- Settings-Panel: Box-Titel
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: Dropdown + Vorschau
    label_theme     = "Thema:",
    label_preview   = "|cffaaaaaa Vorschau (Kopf / Körper / Futter):|r",
    preview_head    = "Kopf",
    preview_body    = "Körper",
    preview_food    = "Futter",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_eat       = "Fressen",
    sound_die       = "Spiel vorbei",
    sound_start     = "Spielstart",

    -- Settings-Panel: Spielanleitung
    guide_goal      = "|cffffff00Ziel:|r Fülle das gesamte Feld, ohne dich selbst zu beißen – das ist der Sieg!",
    guide_controls  = "|cffffff00Steuerung:|r WASD oder Pfeiltasten. Zwei gültige Kurven werden gepuffert. P / Gamepad Y pausiert; ESC speichert und beendet.",
    guide_wrap      = "|cffffff00Rand:|r Die Schlange erscheint am gegenüberliegenden Rand wieder (Wrap-Around).",
    guide_score     = "|cffffff00Punkte:|r Einfach x1 · Normal x2 · Schwer x4 Punkte pro gefressenem Bissen.",
    guide_diff      = "|cffffff00Schwierigkeit:|r Einfach=20x20 (langsam), Normal=16x16 (mittel), Schwer=10x10 (schnell).",
    guide_hint      = "|cffaaaaaa Start → Slot → Weiter setzt Körper, Futter und Tickrest fort. Highscore je Schwierigkeit; Früchterekord = meistes Futter in einer Partie. Längere Client-Stalls pausieren automatisch.|r",

    -- Reset
    btn_pause="Pause", btn_resume="Weiter", pause_hint="Pause – P / Gamepad Y / Weiter",
    pause_stall="Client-Unterbrechung: pausiert ohne Nachholschritte. P / Weiter setzt fort.",
    pause_focus="Textfeld aktiv: pausiert. Fokus verlassen, dann P / Weiter.",
    menu_title="Snake", slot_info="%s · %d Punkte", slot_paused="in Bearbeitung",
    hint_select_slot="Spielstand wählen", confirm_overwrite="Spielstand überschreiben?",confirm_overwrite_body="Slot %d enthält einen Spielstand.",
    confirm_delete="Spielstand löschen?",confirm_delete_body="Slot %d wird geleert.",
    invalid_save_title="Spielstand nicht ladbar",invalid_save_body="Dieser Spielstand ist beschädigt oder nicht kompatibel. Er bleibt erhalten; wähle einen anderen Slot oder ein neues Spiel.",
    win_explanation="Das gesamte Feld ist gefüllt – gewonnen!",loss_explanation="Die Schlange hat ihren Körper getroffen.",
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("SNAKE", "enUS", {

    -- Difficulty buttons
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Buttons
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    btn_new_game    = "New Game",
    btn_new_game_ov = "New Game",

    -- Hint
    hint_start      = "|cffaaaaaa Choose a difficulty to start.\n\nControls: WASD or Arrow Keys|r",

    -- HUD labels
    lbl_score       = "Score",
    lbl_highscore   = "Highscore",
    lbl_length      = "Length",

    -- Statusbar
    status_score    = "|cffaaaaaa Score:|r |cffffff00%d|r",
    status_best     = "|cffaaaaaa Best:|r |cffffd700%d|r",

    -- Overlay
    result_win_title  = "|cffffd700You won!|r",
    result_loss_title = "|cffff4444Game Over!|r",
    result_sub        = "|cffaaaaaa Score:|r |cffffff00%d|r  |cffaaaaaa Length:|r |cffffff00%d|r",
    result_new_hs     = "|cffffd700New Highscore!|r",
    result_hs         = "|cffaaaaaa Highscore: |cffffff00%d|r",

    -- Settings boxes
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Dropdown + preview
    label_theme     = "Theme:",
    label_preview   = "|cffaaaaaa Preview (Head / Body / Food):|r",
    preview_head    = "Head",
    preview_body    = "Body",
    preview_food    = "Food",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_eat       = "Eating",
    sound_die       = "Game Over",
    sound_start     = "Game start",

    -- Guide
    guide_goal      = "|cffffff00Goal:|r Fill the entire grid without biting yourself – that is the win condition!",
    guide_controls  = "|cffffff00Controls:|r WASD or Arrow Keys. Two valid turns are buffered. P / Gamepad Y pauses; ESC saves and exits.",
    guide_wrap      = "|cffffff00Borders:|r The snake reappears on the opposite side (wrap-around).",
    guide_score     = "|cffffff00Score:|r Easy x1 · Normal x2 · Hard x4 points per food eaten.",
    guide_diff      = "|cffffff00Difficulty:|r Easy=20x20 (slow), Normal=16x16 (medium), Hard=10x10 (fast).",
    guide_hint      = "|cffaaaaaa Start → slot → Continue preserves body, food and tick remainder. Highscores per difficulty; food record means most food in one party. Longer client stalls pause automatically.|r",

    -- Reset
    btn_pause="Pause", btn_resume="Continue", pause_hint="Paused – P / Gamepad Y / Continue",
    pause_stall="Client interruption: paused without catch-up steps. P / Continue resumes.",
    pause_focus="Text field active: paused. Leave the field, then P / Continue.",
    menu_title="Snake", slot_info="%s · %d points", slot_paused="in progress",
    hint_select_slot="Choose a save slot",confirm_overwrite="Overwrite save?",confirm_overwrite_body="Slot %d already has a save.",
    confirm_delete="Delete this save?",confirm_delete_body="Slot %d will be cleared.",
    invalid_save_title="Cannot load save",invalid_save_body="This save is damaged or incompatible. It remains intact; choose another slot or a new game.",
    win_explanation="The entire grid is filled – you win!",loss_explanation="The snake hit its own body.",
    btn_reset       = "Reset",
})
