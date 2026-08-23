--[[
    Gaming Hub
    Games/ArcadiasEcho/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Simon Says (Oger-Runen Edition).
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("ARCADIASECHO")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("ARCADIASECHO", "deDE", {

    -- Schwierigkeits-Buttons (Renderer)
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    btn_new_game    = "Neues Spiel",
    btn_new_game_ov = "Neues Spiel",

    -- HUD-Labels
    lbl_theme       = "Thema",
    lbl_round       = "Runde",

    -- Hint (Renderer)
    hint_start      = "|cffaaaaaa Wähle eine Schwierigkeit um zu starten.|r",

    -- Statusbar (Renderer)
    status_ready    = "|cffaaaaaa Bereit...|r",
    status_round    = "|cffaaaaaa Runde:|r |cffffff00%d|r",
    status_your_turn= "|cff00ff00Deine Reihe!|r",
    status_round_ok = "|cffffd700Runde %d geschafft!|r",

    -- Overlay: Gewonnen (kein echtes Ende, aber ShowOverlay(true) kann vorkommen)
    result_win_title = "|cffffd700Sequenz gemeistert!|r",
    result_win_sub   = "|cffaaaaaa Runden:|r |cffffff00%d|r",

    -- Overlay: Verloren (Renderer)
    result_loss_title = "|cffff4444Falsch!|r",
    result_loss_sub   = "|cffaaaaaa Du bist bis Runde |cffffff00%d|r|cffaaaaaa gekommen!|r",

    -- Settings-Panel: Box-Titel
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: Theme-Dropdown
    label_theme     = "Thema:",
    label_preview   = "|cffaaaaaa Symbol-Vorschau (Einfach):|r",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_flash     = "Sequenz-Flash",
    sound_input     = "Eingabe",
    sound_win       = "Sieg",
    sound_lose      = "Niederlage",

    -- Settings-Panel: Spielanleitung
    guide_goal      = "|cffffff00Ziel:|r Merke dir die angezeigte Sequenz aus leuchtenden Symbolen und wiederhole sie.",
    guide_flow      = "|cffffff00Ablauf:|r Die Sequenz wird gezeigt – dann klickst du die Symbole in derselben Reihenfolge.",
    guide_diff      = "|cffffff00Schwierigkeit:|r Einfach=2x2 (4 Symbole), Normal=3x3 (9), Schwer=4x4 (16 Symbole).",
    guide_seq       = "|cffffff00Sequenz:|r Startet bei 3 Symbolen, jede Runde +1. Die Anzeige wird mit der Zeit schneller.",
    guide_fail      = "|cffff4444Fehler:|r Ein falscher Klick beendet das Spiel sofort. Wie weit kommst du?",
    guide_tip       = "|cffaaaaaa Tipp: Spreche die Symbole laut mit – das hilft beim Merken!|r",

    -- Reset
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("ARCADIASECHO", "enUS", {

    -- Difficulty buttons
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Buttons
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    btn_new_game    = "New Game",
    btn_new_game_ov = "New Game",

    -- HUD labels
    lbl_theme       = "Theme",
    lbl_round       = "Round",

    -- Hint
    hint_start      = "|cffaaaaaa Choose a difficulty to start.|r",

    -- Statusbar
    status_ready    = "|cffaaaaaa Ready...|r",
    status_round    = "|cffaaaaaa Round:|r |cffffff00%d|r",
    status_your_turn= "|cff00ff00Your turn!|r",
    status_round_ok = "|cffffd700Round %d complete!|r",

    -- Overlay: Win
    result_win_title = "|cffffd700Sequence mastered!|r",
    result_win_sub   = "|cffaaaaaa Rounds:|r |cffffff00%d|r",

    -- Overlay: Loss
    result_loss_title = "|cffff4444Wrong!|r",
    result_loss_sub   = "|cffaaaaaa You reached round |cffffff00%d|r|cffaaaaaa!|r",

    -- Settings boxes
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Theme dropdown
    label_theme     = "Theme:",
    label_preview   = "|cffaaaaaa Symbol Preview (Easy):|r",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_flash     = "Sequence flash",
    sound_input     = "Input",
    sound_win       = "Victory",
    sound_lose      = "Defeat",

    -- Guide
    guide_goal      = "|cffffff00Goal:|r Memorize the sequence of flashing symbols and repeat it.",
    guide_flow      = "|cffffff00Flow:|r The sequence is shown – then click the symbols in the same order.",
    guide_diff      = "|cffffff00Difficulty:|r Easy=2x2 (4 symbols), Normal=3x3 (9), Hard=4x4 (16 symbols).",
    guide_seq       = "|cffffff00Sequence:|r Starts at 3 symbols, +1 each round. Display speed increases over time.",
    guide_fail      = "|cffff4444Error:|r One wrong click ends the game immediately. How far can you go?",
    guide_tip       = "|cffaaaaaa Tip: Say the symbols out loud – it really helps with memorization!|r",

    -- Reset
    btn_reset       = "Reset",
})
