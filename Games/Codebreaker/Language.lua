--[[
    Gaming Hub
    Games/Codebreaker/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Codebreaker (Azeroth Edition).
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("CODEBREAKER")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("CODEBREAKER", "deDE", {

    -- Schwierigkeits-Buttons (Renderer)
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Controls (Renderer)
    dup_label       = "|cffaaaaaa Duplikate|r",
    code_label      = "|cffaaaaaa Code:|r",
    btn_submit      = "Prüfen",

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    btn_new_game    = "Neues Spiel",
    btn_new_game_ov = "Neues Spiel",

    -- Hint (Renderer)
    hint_start      = "|cffaaaaaa Wähle eine Schwierigkeit um zu starten.|r",
    hud_score       = "Punkte",
    hud_highscore   = "Highscore",

    -- Statusbar (Renderer)
    status_attempts = "|cffaaaaaa Versuche:|r %s%d/%d|r",

    -- Overlay: Sieg (Renderer)
    result_win_title = "|cffffd700Code geknackt!|r",
    result_win_sub   = "|cffaaaaaa Versuche:|r |cffffff00%d / %d|r",

    -- Overlay: Niederlage (Renderer)
    result_loss_title = "|cffff4444Code nicht geknackt!|r",
    result_loss_sub   = "|cffaaaaaa Der geheime Code war:|r",

    -- Settings-Panel: Box-Titel
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: Theme-Dropdown
    label_theme     = "Thema:",
    label_preview   = "|cffaaaaaa Symbol-Vorschau:|r",

    -- Settings-Panel: Peg-Erklärung
    peg_exact       = "|cffffff00Diamant:|r |cffaaaaaarichtige Position|r",
    peg_partial     = "|cffaaaaaaPerle: richtige Farbe, falsche Position|r",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_place     = "Symbol setzen",
    sound_submit    = "Prüfen",
    sound_win       = "Sieg",
    sound_lose      = "Niederlage",

    -- Settings-Panel: Spielanleitung
    guide_goal      = "|cffffff00Ziel:|r Knacke den geheimen Code des Gegners in möglichst wenigen Versuchen.",
    guide_input     = "|cffffff00Eingabe:|r Wähle Symbole aus der Palette unten und platziere sie in die Slots.",
    guide_submit    = "|cffffff00Prüfen:|r Klicke 'Prüfen' wenn alle Slots gefüllt sind.",
    guide_exact     = "|cffffff00Diamant (weiß):|r Symbol an exakt richtiger Position.",
    guide_partial   = "|cffaaaaaaPerle (grau):|r Symbol im Code vorhanden, aber falsche Position.",
    guide_hint      = "|cffaaaaaa Schwierigkeit wählt Versuche (Einfach=10 / Normal=8 / Schwer=6). Code-Länge und Duplikate in Einstellungen.|r",

    -- Reset
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("CODEBREAKER", "enUS", {

    -- Difficulty buttons
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Controls
    dup_label       = "|cffaaaaaa Duplicates|r",
    code_label      = "|cffaaaaaa Code:|r",
    btn_submit      = "Check",

    -- Buttons
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    btn_new_game    = "New Game",
    btn_new_game_ov = "New Game",

    -- Hint
    hint_start      = "|cffaaaaaa Choose a difficulty to start.|r",
    hud_score       = "Score",
    hud_highscore   = "Highscore",

    -- Statusbar
    status_attempts = "|cffaaaaaa Attempts:|r %s%d/%d|r",

    -- Overlay: Win
    result_win_title = "|cffffd700Code cracked!|r",
    result_win_sub   = "|cffaaaaaa Attempts:|r |cffffff00%d / %d|r",

    -- Overlay: Loss
    result_loss_title = "|cffff4444Code not cracked!|r",
    result_loss_sub   = "|cffaaaaaa The secret code was:|r",

    -- Settings boxes
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Theme dropdown
    label_theme     = "Theme:",
    label_preview   = "|cffaaaaaa Symbol Preview:|r",

    -- Peg explanation
    peg_exact       = "|cffffff00Diamond:|r |cffaaaaaacorrect position|r",
    peg_partial     = "|cffaaaaaaPearl: correct symbol, wrong position|r",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_place     = "Place symbol",
    sound_submit    = "Check",
    sound_win       = "Victory",
    sound_lose      = "Defeat",

    -- Guide
    guide_goal      = "|cffffff00Goal:|r Crack the opponent's secret code in as few attempts as possible.",
    guide_input     = "|cffffff00Input:|r Choose symbols from the palette below and place them in the slots.",
    guide_submit    = "|cffffff00Check:|r Click 'Check' when all slots are filled.",
    guide_exact     = "|cffffff00Diamond (white):|r Symbol in the exact correct position.",
    guide_partial   = "|cffaaaaaaPearl (grey):|r Symbol is in the code but in the wrong position.",
    guide_hint      = "|cffaaaaaa Difficulty sets attempts (Easy=10 / Normal=8 / Hard=6). Code length and duplicates in settings.|r",

    -- Reset
    btn_reset       = "Reset",
})
