--[[
    Gaming Hub
    Games/Memory/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Memory (Pairs).
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("ARCADIAPAIRS")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("ARCADIAPAIRS", "deDE", {

    -- Schwierigkeits-Buttons (Renderer)
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Timer-Checkbox (Renderer)
    timer_label     = "Timer",

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    btn_new_game    = "Neues Spiel",
    btn_new_game_ov = "Neues Spiel",

    -- HUD-Labels
    lbl_moves       = "Züge",
    lbl_pairs       = "Paare",
    lbl_time        = "Zeit",

    -- Hint (Renderer)
    hint_start      = "|cffaaaaaa Wähle eine Schwierigkeit um zu starten.|r",

    -- Statusbar (Renderer)
    stats_moves_pairs = "|cffaaaaaa Züge:|r %d   |cffaaaaaa Paare:|r %d/%d",
    timer_color_ok    = "|cffffff00",
    timer_color_warn  = "|cffff4444",

    -- Overlay: Sieg (Renderer)
    result_win_title    = "|cffffd700Alle Paare gefunden!|r",
    result_win_sub      = "|cffaaaaaa Züge:|r |cffffff00%d|r    |cffaaaaaa Paare:|r |cffffff00%d|r",
    result_win_time     = "\n|cffaaaaaa Verbleibende Zeit:|r |cffffff00%d:%02d|r",

    -- Overlay: Verloren (Renderer)
    result_lose_title   = "|cffff4444Zeit abgelaufen!|r",
    result_lose_sub     = "|cffaaaaaa Paare gefunden:|r |cffffff00%d / %d|r\n|cffaaaaaa Züge:|r |cffffff00%d|r",

    -- Settings-Panel: Box-Titel
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: Dropdown-Labels
    label_theme_deck  = "Themen-Deck:",
    label_card_back   = "Kartenrückseite:",
    label_back_prev   = "|cffaaaaaa Vorschau Rückseite:|r",
    label_theme_prev  = "|cffaaaaaa Themen-Vorschau:|r",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_flip      = "Karte aufdecken",
    sound_match     = "Paar gefunden",
    sound_mismatch  = "Kein Treffer",
    sound_win       = "Sieg",
    sound_lose      = "Zeit abgelaufen",

    -- Settings-Panel: Spielanleitung
    guide_goal      = "|cffffff00Ziel:|r Finde alle Kartenpaare.",
    guide_click     = "|cffffff00Linksklick:|r Karte aufdecken. Zwei aufgedeckte Karten werden auf Übereinstimmung geprüft.",
    guide_match     = "|cffffff00Treffer:|r Beide Karten bleiben sichtbar (abgedunkelt) und werden aus dem Spiel genommen.",
    guide_miss      = "|cffffff00Kein Treffer:|r Beide Karten werden kurz angezeigt, dann wieder umgedreht.",
    guide_timer     = "|cffffff00Timer:|r Optional aktivierbar. Bei Ablauf: Spiel verloren. Wird oben rechts angezeigt.",
    guide_hint      = "|cffaaaaaa Schwierigkeit und Timer im Spielfeld wählbar. Thema & Rückseite hier in den Einstellungen.|r",

    -- Reset
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("ARCADIAPAIRS", "enUS", {

    -- Difficulty buttons
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Timer checkbox
    timer_label     = "Timer",

    -- Buttons
    btn_start       = "Start Game",
    btn_exit        = "Exit",
    btn_new_game    = "New Game",
    btn_new_game_ov = "New Game",

    -- HUD labels
    lbl_moves       = "Moves",
    lbl_pairs       = "Pairs",
    lbl_time        = "Time",

    -- Hint
    hint_start      = "|cffaaaaaa Choose a difficulty to start.|r",

    -- Statusbar
    stats_moves_pairs = "|cffaaaaaa Moves:|r %d   |cffaaaaaa Pairs:|r %d/%d",
    timer_color_ok    = "|cffffff00",
    timer_color_warn  = "|cffff4444",

    -- Overlay: Win
    result_win_title    = "|cffffd700All pairs found!|r",
    result_win_sub      = "|cffaaaaaa Moves:|r |cffffff00%d|r    |cffaaaaaa Pairs:|r |cffffff00%d|r",
    result_win_time     = "\n|cffaaaaaa Time remaining:|r |cffffff00%d:%02d|r",

    -- Overlay: Lost
    result_lose_title   = "|cffff4444Time's up!|r",
    result_lose_sub     = "|cffaaaaaa Pairs found:|r |cffffff00%d / %d|r\n|cffaaaaaa Moves:|r |cffffff00%d|r",

    -- Settings boxes
    box_theme       = "Theme",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Dropdown labels
    label_theme_deck  = "Theme Deck:",
    label_card_back   = "Card Back:",
    label_back_prev   = "|cffaaaaaa Back Preview:|r",
    label_theme_prev  = "|cffaaaaaa Theme Preview:|r",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_flip      = "Card revealed",
    sound_match     = "Pair found",
    sound_mismatch  = "No match",
    sound_win       = "Victory",
    sound_lose      = "Time's up",

    -- Guide
    guide_goal      = "|cffffff00Goal:|r Find all matching pairs.",
    guide_click     = "|cffffff00Left-click:|r Reveal a card. Two revealed cards are checked for a match.",
    guide_match     = "|cffffff00Match:|r Both cards stay visible (dimmed) and are removed from play.",
    guide_miss      = "|cffffff00No match:|r Both cards are shown briefly, then flipped back.",
    guide_timer     = "|cffffff00Timer:|r Optional. When it runs out: game lost. Shown in the top right.",
    guide_hint      = "|cffaaaaaa Difficulty and timer chosen in the game area. Theme & card back set here.|r",

    -- Reset
    btn_reset       = "Reset",
})
