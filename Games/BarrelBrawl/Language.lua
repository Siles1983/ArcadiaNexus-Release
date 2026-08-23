--[[
    ArcadiaNexus – Barrel Brawl
    Games/BarrelBrawl/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Barrel Brawl.
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("BARREL_BRAWL")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("BARREL_BRAWL", "deDE", {

    -- Schwierigkeit (Renderer-Dropdown)
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",

    -- Save-Slots
    menu_title      = "Barrel Brawl",
    slot_info       = "Level %d · %s",
    slot_paused     = "läuft",
    hint_select_slot = "Wähle einen Speicherslot",
    confirm_overwrite = "Spielstand überschreiben?",
    confirm_overwrite_body = "Slot %d enthält einen Spielstand.",
    confirm_delete  = "Spielstand wirklich löschen?",
    confirm_delete_body = "Slot %d wird geleert.",

    -- Hint (IDLE-Screen)
    hint_start      = "|cffaaaaaa Rette die Gnomen-Prinzessin vor dem tobenden Troll!\n\nSteuerung: A/D bewegen – W/S klettern\nLeertaste springen – P Pause – ESC beenden|r",

    -- HUD-Labels
    lbl_score       = "Punkte",
    lbl_highscore   = "Highscore",
    lbl_lives       = "Leben",
    lbl_level       = "Level",
    lbl_bonus       = "Bonus",

    -- Banner / Overlays (Renderer)
    banner_rescue   = "Prinzessin gerettet! Level %d",
    overlay_paused  = "PAUSE\n|cffaaaaaa(P zum Fortsetzen)|r",

    -- Result-Dialog
    result_win_title  = "Prinzessin gerettet!",
    result_loss_title = "Vom Fass erwischt!",
    result_level      = "|cffaaaaaa Erreichtes Level:|r |cffffff00%d|r",
    result_rescues    = "|cffaaaaaa Rettungen:|r |cffffff00%d|r",
    result_jumped     = "|cffaaaaaa Übersprungene Fässer:|r |cffffff00%d|r",
    result_time       = "|cffaaaaaa Zeit:|r |cffffff00%s|r",

    -- Settings-Panel: Box-Titel
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_score     = "Fass übersprungen",
    sound_hit       = "Treffer / Spiel vorbei",
    sound_win       = "Rettung",

    -- Settings-Panel: Spielanleitung
    guide_goal      = "|cffffff00Ziel:|r Klettere die Träger hinauf und rette die Gnomen-Prinzessin vor dem tobenden Troll – so oft du kannst!",
    guide_controls  = "|cffffff00Steuerung:|r A/D oder Pfeiltasten bewegen. W/S klettert Leitern hoch/runter. Leertaste springt. P pausiert, ESC beendet.",
    guide_barrels   = "|cffffff00Fässer:|r Der Troll wirft Teufelseisen-Fässer, die bergab rollen, Leitern hinunterrutschen und an offenen Kanten eine Etage tiefer fallen. Berührung kostet ein Leben!",
    guide_jump      = "|cffffff00Springen:|r Ein übersprungenes Fass bringt 100 Punkte – aber nur einmal pro Fass.",
    guide_bonus     = "|cffffff00Bonus:|r Der Bonus-Zähler tickt herunter. Erreichst du die Prinzessin, wird der Rest deinen Punkten gutgeschrieben. Bei 0 verlierst du ein Leben!",
    guide_levels    = "|cffffff00Level:|r Nach jeder Rettung geht es von vorn los – mit schnelleren Fässern und kürzeren Wurfpausen.",
    guide_diff      = "|cffffff00Schwierigkeit:|r Einfach = langsame Fässer, Normal = flotter, Schwer = schnelle Fässer, mehr Leiter-Abstiege, nur 2 Leben.",

    -- Reset
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("BARREL_BRAWL", "enUS", {

    -- Difficulty (renderer dropdown)
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Buttons
    btn_start       = "Start Game",
    btn_exit        = "Exit",

    -- Save slots
    menu_title      = "Barrel Brawl",
    slot_info       = "Level %d · %s",
    slot_paused     = "in progress",
    hint_select_slot = "Choose a save slot",
    confirm_overwrite = "Overwrite save?",
    confirm_overwrite_body = "Slot %d already has a save.",
    confirm_delete  = "Delete this save?",
    confirm_delete_body = "Slot %d will be cleared.",

    -- Hint (idle screen)
    hint_start      = "|cffaaaaaa Rescue the gnome princess from the raging troll!\n\nControls: A/D move – W/S climb\nSpacebar jump – P pause – ESC exit|r",

    -- HUD labels
    lbl_score       = "Score",
    lbl_highscore   = "Highscore",
    lbl_lives       = "Lives",
    lbl_level       = "Level",
    lbl_bonus       = "Bonus",

    -- Banner / overlays
    banner_rescue   = "Princess rescued! Level %d",
    overlay_paused  = "PAUSED\n|cffaaaaaa(press P to resume)|r",

    -- Result dialog
    result_win_title  = "Princess rescued!",
    result_loss_title = "Crushed by a barrel!",
    result_level      = "|cffaaaaaa Level reached:|r |cffffff00%d|r",
    result_rescues    = "|cffaaaaaa Rescues:|r |cffffff00%d|r",
    result_jumped     = "|cffaaaaaa Barrels jumped:|r |cffffff00%d|r",
    result_time       = "|cffaaaaaa Time:|r |cffffff00%s|r",

    -- Settings boxes
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_score     = "Barrel jumped",
    sound_hit       = "Hit / Game Over",
    sound_win       = "Rescue",

    -- Guide
    guide_goal      = "|cffffff00Goal:|r Climb the girders and rescue the gnome princess from the raging troll – as often as you can!",
    guide_controls  = "|cffffff00Controls:|r Move with A/D or Arrow Keys. W/S climbs ladders up/down. Spacebar jumps. P pauses, ESC exits.",
    guide_barrels   = "|cffffff00Barrels:|r The troll hurls fel-iron barrels that roll downhill, slide down ladders and drop off open edges to the floor below. Touching one costs a life!",
    guide_jump      = "|cffffff00Jumping:|r Jumping over a barrel awards 100 points – but only once per barrel.",
    guide_bonus     = "|cffffff00Bonus:|r The bonus counter ticks down. Reach the princess and the remainder is added to your score. At 0 you lose a life!",
    guide_levels    = "|cffffff00Levels:|r After each rescue the tower resets – with faster barrels and shorter throw pauses.",
    guide_diff      = "|cffffff00Difficulty:|r Easy = slow barrels, Normal = brisker, Hard = fast barrels, more ladder descents, only 2 lives.",

    -- Reset
    btn_reset       = "Reset",
})
