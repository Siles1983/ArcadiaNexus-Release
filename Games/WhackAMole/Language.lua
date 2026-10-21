--[[
    Gaming Hub
    Games/WhackAMole/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Whack-a-Mole.
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("WHACKAMOLE")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("WHACKAMOLE", "deDE", {

    -- Schwierigkeits-Buttons (Renderer)
    diff_easy       = "Einfach",
    tip_format      = "%dx%d Felder · %.2g s sichtbar · %d Punkte/Treffer",
    lbl_hits        = "Treffer",
    empty_text      = "|cffaaaaaaLeer|r",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_exit        = "Beenden",
    btn_retry       = "Nochmal!",
    btn_menu        = "Menü",

    -- Hint (Renderer)
    hint_start      = "|cffaaaaaa Wähle eine Schwierigkeit und haue die Moles!|r",

    -- HUD Labels (Renderer)
    hud_score       = "|cffffff00Punkte:|r",
    hud_time        = "|cffffff00Zeit:|r",
    hud_missed      = "|cffff4444Verpasst:|r",
    hud_highscore   = "|cffffff00Highscore:|r",

    lbl_score       = "Punkte",
    lbl_time        = "Zeit",
    lbl_missed      = "Verpasst",
    -- Boom-Effekt (Renderer)
    boom_text       = "|cffFF0000BOOM!|r",

    -- GameOver-Panel (Renderer)
    go_title_bomb   = "|cffFF4444BOOM! Erwischt!|r",
    go_title_time   = "|cffffff00Runde abgeschlossen!|r",
    go_reason_bomb  = "|cffff9900Die Bombe hat dich erwischt!|r",
    go_score        = "Punkte: ",
    go_missed       = "Verpasst: ",
    go_highscore    = "Highscore: ",

    -- Settings-Panel: Box-Titel
    box_preview     = "Maulwurf-Vorschau",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: Bombe-Hinweis
    bomb_hint       = "|cffFF4444Bombe: Treffer = Spiel vorbei!|r  (ab 30 Punkten, 25% Chance)",

    -- Settings-Panel: Sounds
    sound_enabled   = "Soundeffekte aktiv",
    sound_hit       = "Einfacher Treffer",
    sound_bomb      = "Bombe",
    sound_round     = "Rundenstart und -ende",
    btn_reset       = "Reset",

    -- Settings-Panel: Spielanleitung
    guide_goal      = "|cffaaaaaa Ziel:|r Haue so viele Moles wie möglich in 30 Sekunden!",
    guide_click     = "|cffaaaaaa Klick:|r Maulwurf = Punkte; leeres Feld = neutrale Rückmeldung ohne Strafe.",
    guide_points    = "|cffaaaaaa Punkte:|r 10 x Schwierigkeitsfaktor (Einfach x1, Normal x1.5, Schwer x2.5)",
    guide_bomb      = "|cffFF4444 Bombe:|r Ab 30 Punkten erscheinen Bomben (25% Chance). NICHT anklicken!",
    guide_diff      = "|cffaaaaaa Schwierigkeit:|r Einfach 2x2 / 2 s / 10 Punkte; Normal 3x3 / 1,5 s / 15; Schwer 4x4 / 1 s / 25.",
    guide_missed    = "|cffaaaaaa Verpasst:|r Nur abgelaufene Maulwürfe zählen. Ignorierte Bomben und leere Klicks kosten keine Punkte.",
    guide_highscore = "|cffaaaaaa Highscore:|r Top 3 pro Schwierigkeit. Zeitende = WIN, Bombe = LOSS; beide Endwerte zählen.",
    guide_timer     = "|cffaaaaaa Zeit:|r 30 Sekunden; letzte 10 s rot. Ab 15 s: 35% Chance auf Zusatzspawn nach 0,25 s; Sichtbarkeit bleibt gleich. Beenden verwirft unfertige Läufe.",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("WHACKAMOLE", "enUS", {

    -- Difficulty buttons
    diff_easy       = "Easy",
    tip_format      = "%dx%d grid · %.2g s visible · %d points/hit",
    lbl_hits        = "Hits",
    empty_text      = "|cffaaaaaaEmpty|r",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    btn_start       = "Start Game",
    -- Buttons
    btn_exit        = "Exit",
    btn_retry       = "Retry!",
    btn_menu        = "Menu",

    -- Hint
    hint_start      = "|cffaaaaaa Choose a difficulty and whack the moles!|r",

    -- HUD Labels
    hud_score       = "|cffffff00Score:|r",
    hud_time        = "|cffffff00Time:|r",
    hud_missed      = "|cffff4444Missed:|r",
    hud_highscore   = "|cffffff00Highscore:|r",

    lbl_score       = "Score",
    lbl_time        = "Time",
    lbl_missed      = "Missed",
    -- Boom effect
    boom_text       = "|cffFF0000BOOM!|r",

    -- GameOver panel
    go_title_bomb   = "|cffFF4444BOOM! Busted!|r",
    go_title_time   = "|cffffff00Round completed!|r",
    go_reason_bomb  = "|cffff9900The bomb got you!|r",
    go_score        = "Score: ",
    go_missed       = "Missed: ",
    go_highscore    = "Highscore: ",

    -- Settings boxes
    box_preview     = "Mole Preview",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- Bomb hint
    bomb_hint       = "|cffFF4444Bomb: Hit = Game Over!|r  (from score 30, 25% chance)",

    -- Sounds
    sound_enabled   = "Sound effects active",
    sound_hit       = "Normal hit",
    sound_bomb      = "Bomb",
    sound_round     = "Round start and end",
    btn_reset       = "Reset",

    -- Guide
    guide_goal      = "|cffaaaaaa Goal:|r Whack as many moles as possible in 30 seconds!",
    guide_click     = "|cffaaaaaa Click:|r Mole = points; empty hole = neutral feedback without penalty.",
    guide_points    = "|cffaaaaaa Points:|r 10 x difficulty factor (Easy x1, Normal x1.5, Hard x2.5)",
    guide_bomb      = "|cffFF4444 Bomb:|r From score 30, bombs appear (25% chance). DON'T click!",
    guide_diff      = "|cffaaaaaa Difficulty:|r Easy 2x2 / 2 s / 10 points; Normal 3x3 / 1.5 s / 15; Hard 4x4 / 1 s / 25.",
    guide_missed    = "|cffaaaaaa Missed:|r Only expired moles count. Ignored bombs and empty clicks cost no points.",
    guide_highscore = "|cffaaaaaa Highscore:|r Top 3 per difficulty. Timeout = WIN, bomb = LOSS; both final scores count.",
    guide_timer     = "|cffaaaaaa Time:|r 30 seconds; last 10 s red. From 15 s: 35% chance of an extra spawn after 0.25 s; visibility stays unchanged. Exit discards unfinished runs.",
})
