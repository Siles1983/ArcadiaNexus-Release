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
    lbl_runtime = "Laufzeit",
    lbl_remaining = "Restzeit",
    legacy_save = "Altfortsetzung",
    legacy_notice = "Altfortsetzung: Etappe beginnt neu",
    bonus_tip = "Bonus sinkt alle 2 s um 100. Bei null verlierst du ein Leben. Rettung schreibt den Rest gut. Startbudget: 100 s, auf Schwer 80 s.",
    protection_tip = "Nach einem Treffer: 2,5 s Schutz; nach Rettung 1 s. Blinken zeigt die Schutzzeit.",
    protection_left = "Schutz verbleibend: %.1f s",
    sound_warning = "Restzeitwarnung",
    cause_BARREL = "Alle Leben verloren: Fasskontakt.",
    cause_FALL = "Alle Leben verloren: zu hoher Sturz.",
    cause_TIMEOUT = "Alle Leben verloren: Zeit abgelaufen.",

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

    -- HUD-Labels
    lbl_score       = "Punkte",
    lbl_highscore   = "Highscore",
    lbl_lives       = "Leben",
    lbl_level       = "Level",
    lbl_bonus       = "Bonus",

    -- Banner / Overlays (Renderer)
    banner_rescue   = "Gerettet! Level %d\nBonus +%d",
    overlay_paused  = "PAUSE\n|cffaaaaaa(P zum Fortsetzen)|r",

    -- Result-Dialog
    result_win_title  = "Erfolgreicher Lauf beendet",
    result_loss_title = "Lauf ohne Rettung beendet",
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
    guide_controls  = "|cffffff00Steuerung:|r A/D oder Pfeiltasten bewegen. W/S klettert Leitern hoch/runter. Leertaste springt. P pausiert, ESC speichert und verlässt.",
    guide_barrels   = "|cffffff00Fässer:|r Der Troll wirft Teufelseisen-Fässer, die bergab rollen, Leitern hinunterrutschen und an offenen Kanten eine Etage tiefer fallen. Berührung kostet ein Leben!",
    guide_jump      = "|cffffff00Springen:|r Eine sichere vollständige Passage über ein Fass auf derselben Etage bringt einmal 100 Punkte. Bloße Nähe zählt nicht.",
    guide_bonus = "|cffffff00Bonus:|r Alle 2 s -100. Start: 100 s, Schwer 80 s. Bei null kostet es ein Leben; Rettung schreibt den Rest gut. ! warnt ab 10 s. Ein Lauf mit mindestens einer Rettung ist erfolgreich; gewertet wird einmal am Ende. Nach Treffer 2,5 s Schutz.",
    guide_levels    = "|cffffff00Level:|r Nach jeder Rettung geht es von vorn los – mit schnelleren Fässern und kürzeren Wurfpausen.",
    guide_diff      = "|cffffff00Schwierigkeit:|r Einfach = langsame Fässer, Normal = flotter, Schwer = schnelle Fässer, mehr Leiter-Abstiege, nur 2 Leben.",

    -- Reset
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("BARREL_BRAWL", "enUS", {
    lbl_runtime = "Run time",
    lbl_remaining = "Time left",
    legacy_save = "Legacy continuation",
    legacy_notice = "Legacy continuation: stage restarted",
    bonus_tip = "Bonus drops by 100 every 2 s. At zero you lose a life. Rescue awards the remainder. Starting budget: 100 s, Hard 80 s.",
    protection_tip = "Protection: 2.5 s after a hit, 1 s after rescue. Blinking indicates protection.",
    protection_left = "Protection remaining: %.1f s",
    sound_warning = "Time-left warning",
    cause_BARREL = "All lives lost: barrel contact.",
    cause_FALL = "All lives lost: high fall.",
    cause_TIMEOUT = "All lives lost: time expired.",

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

    -- HUD labels
    lbl_score       = "Score",
    lbl_highscore   = "Highscore",
    lbl_lives       = "Lives",
    lbl_level       = "Level",
    lbl_bonus       = "Bonus",

    -- Banner / overlays
    banner_rescue   = "Rescued! Level %d\nBonus +%d",
    overlay_paused  = "PAUSED\n|cffaaaaaa(press P to resume)|r",

    -- Result dialog
    result_win_title  = "Successful run ended",
    result_loss_title = "Run ended without a rescue",
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
    guide_controls  = "|cffffff00Controls:|r Move with A/D or Arrow Keys. W/S climbs ladders up/down. Spacebar jumps. P pauses, ESC save and exits.",
    guide_barrels   = "|cffffff00Barrels:|r The troll hurls fel-iron barrels that roll downhill, slide down ladders and drop off open edges to the floor below. Touching one costs a life!",
    guide_jump      = "|cffffff00Jumping:|r Safely passing fully over a barrel on the same floor awards 100 points once. Proximity alone does not count.",
    guide_bonus = "|cffffff00Bonus:|r -100 every 2 s. Start: 100 s, Hard 80 s. Zero costs a life; rescue awards the remainder. ! warns at 10 s. A run with at least one rescue is successful and scored once at the end. Hits grant 2.5 s protection.",
    guide_levels    = "|cffffff00Levels:|r After each rescue the tower resets – with faster barrels and shorter throw pauses.",
    guide_diff      = "|cffffff00Difficulty:|r Easy = slow barrels, Normal = brisker, Hard = fast barrels, more ladder descents, only 2 lives.",

    -- Reset
    btn_reset       = "Reset",
})
