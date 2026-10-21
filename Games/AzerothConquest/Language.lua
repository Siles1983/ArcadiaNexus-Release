--[[
    Gaming Hub
    Games/AzerothConquest/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Schiffe versenken.
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("AZEROTHCONQUEST")

    WICHTIG: Schiffsnamen werden in Logic.lua ueber L[] referenziert,
    da sie im BoardState und im Placement-Hint sichtbar sind.
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
ArcadiaNexus.RegisterLocale("AZEROTHCONQUEST", "deDE", {
    btn_rotate = "Drehen",
    btn_undo = "Letztes zurücknehmen",
    btn_battle = "Kampf starten",
    orientation_horizontal = "Waagerecht",
    orientation_vertical = "Senkrecht",
    placement_invalid = "Hier passt das Schiff nicht: Rand oder Überlappung. Wähle ein anderes Feld.",
    placement_failed = "Keine vollständige Flotte möglich. Die bisherige Aufstellung bleibt erhalten.",
    hint_pending = "Gegner antwortet … Eingabe gesperrt.",
    shot_HIT = "Treffer",
    shot_MISS = "Verfehlt",
    shot_SUNK = "Versenkt",
    shot_summary = "Dein letzter Schuss: %s\nGegnerischer Schuss: %s",
    fleet_remaining = "Restflotte (übrig / gesamt)",
    fleet_fortress = "Festung",
    fleet_galleon = "Galeere",
    fleet_zeppelin = "Zeppelin",
    fleet_gunboat = "Boot",
    result_stats = "Schüsse: %d · Fehlschüsse: %d\nTrefferquote: %.1f%%",
    menu_title = "Azeroth Conquest – Spielstände",
    slot_info = "%s · %s · %d Schüsse",
    phase_PLACEMENT = "Aufstellung",
    phase_BATTLE = "Kampf",
    invalid_save_title = "Spielstand nicht fortsetzbar",
    invalid_save_body = "Der Spielstand ist ungültig, unbekannt oder bereits abgeschlossen. Er bleibt erhalten; wähle einen anderen Slot oder starte dort bewusst neu.",
    guide_8 = "|cffffff00Speichern:|r Drei Slots speichern Aufstellung und Kampf. Beenden/Tabwechsel erhält Flotten, Schüsse und eine ausstehende Gegnerantwort exakt; Fortfahren lädt dieselbe Partie.",
    guide_9 = "|cffffff00Wertung:|r Siege/Niederlagen je KI-Stufe; im Ergebnis Schüsse, Fehlschüsse und Trefferquote. Schwierigkeit ab Aufstellung gesperrt, Sound weiter bedienbar.",

    -- Schiffsnamen (in Logic.lua referenziert)
    ship_fortress   = "Fliegende Festung",
    ship_galleon    = "Kriegsgaleere",
    ship_zeppelin   = "Zeppelin",
    ship_gunboat    = "Kanonenboot",

    -- Schwierigkeit (Renderer)
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Buttons (Renderer)
    btn_start       = "Spiel starten",
    btn_resume      = "Weiterspielen",
    btn_exit        = "Beenden",
    btn_random      = "Zufällig platzieren",
    btn_new_game    = "Neues Spiel",

    -- Hints (Renderer)
    hint_start      = "|cffaaaaaa Wähle eine Schwierigkeit um zu starten.|r",
    hint_diff       = "|cffaaaaaa Jetzt Schwierigkeit wählen.|r",
    hint_battle     = "|cffaaaaaa Klicke auf das Gegnerfeld (rechts) um zu schießen.|r",

    -- Grid-Labels (Renderer)
    label_player    = "|cffffd700Dein Feld|r",
    label_enemy     = "|cffffd700Gegner|r",

    -- Placement-Hint (Renderer)
    placement_place = "|cffffff00Platziere:|r %s  (Länge %d)  |cffaaaaaa[R = Drehen]|r",
    placement_done  = "Alle Schiffe platziert. Korrigiere die Aufstellung oder bestätige mit 'Kampf starten'.",

    -- Game Over Overlay (Renderer)
    result_win      = "|cffffd700Sieg!|r",
    result_win_sub  = "Du hast alle feindlichen Schiffe versenkt!",
    result_loss     = "Niederlage!",
    result_loss_sub = "Deine Flotte wurde vernichtet.",

    -- Settings-Panel: Box-Titel
    box_difficulty  = "KI-Schwierigkeit",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    -- Settings-Panel: KI-Info
    info_classic_title = "|cffffd700Classic:|r",
    info_classic_text  = "Schießt zufällig auf unbeschossene Felder.",
    info_pro_title     = "|cffffd700Pro:|r",
    info_pro_text1     = "Sucht mit Schachbrett-Muster (Hunt).",
    info_pro_text2     = "Nach einem Treffer werden benachbarte",
    info_pro_text3     = "Felder systematisch abgearbeitet (Target).",
    info_insane_title  = "|cffffd700Insane:|r",
    info_insane_text1  = "Berechnet für jedes Feld eine",
    info_insane_text2  = "Wahrscheinlichkeit basierend auf den noch",
    info_insane_text3  = "nicht versenkten Schiffen. Schießt immer",
    info_insane_text4  = "auf das wahrscheinlichste Feld.",
    hint_diff_panel    = "|cff888888Schwierigkeit wird direkt im Spielfeld gewählt.|r",

    -- Settings-Panel: Sounds
    sound_enabled   = "Sounds aktiviert",
    sound_hit       = "Treffer",
    sound_miss      = "Verfehlt",
    sound_sunk      = "Versenkung",
    sound_win       = "Sieg",
    sound_loss      = "Niederlage",

    guide_1         = "|cffffff00Ziel:|r Versenke alle Schiffe des Gegners, bevor deine eigene Flotte vernichtet wird.",
    guide_2         = "|cffffff00Aufstellung:|r 10×10, Flotte 5/4/3/3/2. Berührung erlaubt, Überlappung verboten. Linksklick platziert; Drehen per Button, [R] oder Rechtsklick. Letztes Schiff zurücknehmen ist bis Kampfstart möglich.",
    guide_3         = "|cffffff00Start:|r 'Zufällig platzieren' stellt die komplette Flotte auf. Erst 'Kampf starten' bestätigt sie; danach keine Änderungen mehr.",
    guide_4         = "|cffffff00Kampf:|r Linksklick auf das Gegnerfeld schießt. Nach jedem gültigen Schuss wechselt der Zug, auch bei Treffer. Bereits beschossene Felder kosten keinen Zug; Rechtsklick schießt nicht. Während der Gegnerantwort warten.",
    guide_5         = "|cffffff00Treffer:|r Ein Treffer wird rot markiert. Verfehlen mit einem kleinen Kreuz.",
    guide_6         = "|cffffff00Versenkt:|r Ist ein Schiff vollständig getroffen, wird es rot eingefärbt und aufgedeckt.",
    guide_7         = "|cffffff00Schwierigkeit:|r Classic = zufällig | Pro = systematisch | Insane = wahrscheinlichkeitsbasiert.",

    -- Reset
    btn_reset       = "Reset",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
-- ============================================================
ArcadiaNexus.RegisterLocale("AZEROTHCONQUEST", "enUS", {
    btn_rotate = "Rotate",
    btn_undo = "Undo last ship",
    btn_battle = "Start battle",
    orientation_horizontal = "Horizontal",
    orientation_vertical = "Vertical",
    placement_invalid = "This ship does not fit: edge or overlap. Choose another cell.",
    placement_failed = "Cannot place a complete fleet. Your previous arrangement is preserved.",
    hint_pending = "Enemy responding … input locked.",
    shot_HIT = "Hit",
    shot_MISS = "Miss",
    shot_SUNK = "Sunk",
    shot_summary = "Your last shot: %s\nEnemy shot: %s",
    fleet_remaining = "Fleet remaining (left / total)",
    fleet_fortress = "Fortress",
    fleet_galleon = "Galleon",
    fleet_zeppelin = "Zeppelin",
    fleet_gunboat = "Gunboat",
    result_stats = "Shots: %d · Misses: %d\nHit rate: %.1f%%",
    menu_title = "Azeroth Conquest – saved games",
    slot_info = "%s · %s · %d shots",
    phase_PLACEMENT = "Placement",
    phase_BATTLE = "Battle",
    invalid_save_title = "Cannot continue this save",
    invalid_save_body = "This save is invalid, unknown or already completed. It is preserved; choose another slot or explicitly start a new game here.",
    guide_8 = "|cffffff00Saving:|r Three slots preserve placement and battle. Exit/tab changes retain fleets, shots and a pending enemy response exactly; Continue loads the same party.",
    guide_9 = "|cffffff00Results:|r Wins/losses per AI level; results show shots, misses and hit rate. Difficulty locks from placement; sound remains adjustable.",

    -- Ship names
    ship_fortress   = "Flying Fortress",
    ship_galleon    = "War Galleon",
    ship_zeppelin   = "Zeppelin",
    ship_gunboat    = "Gunboat",

    -- Difficulty
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Buttons
    btn_start       = "Start Game",
    btn_resume      = "Continue",
    btn_random      = "Random Placement",
    btn_exit        = "Exit",
    btn_new_game    = "New Game",

    -- Hints
    hint_start      = "|cffaaaaaa Choose a difficulty to start.|r",
    hint_diff       = "|cffaaaaaa Now choose a difficulty.|r",
    hint_battle     = "|cffaaaaaa Click the enemy grid (right) to fire.|r",

    -- Grid labels
    label_player    = "|cffffd700Your Board|r",
    label_enemy     = "|cffffd700Enemy|r",

    -- Placement hint
    placement_place = "|cffffff00Place:|r %s  (Length %d)  |cffaaaaaa[R = Rotate]|r",
    placement_done  = "All ships placed. Adjust your fleet or confirm with 'Start battle'.",

    -- Game Over
    result_win      = "|cffffd700Victory!|r",
    result_win_sub  = "You sank all enemy ships!",
    result_loss     = "Defeat!",
    result_loss_sub = "Your fleet was destroyed.",

    -- Settings boxes
    box_difficulty  = "AI Difficulty",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    -- AI info
    info_classic_title = "|cffffd700Classic:|r",
    info_classic_text  = "Fires randomly at unshot cells.",
    info_pro_title     = "|cffffd700Pro:|r",
    info_pro_text1     = "Hunts using a checkerboard pattern.",
    info_pro_text2     = "After a hit, systematically works through",
    info_pro_text3     = "adjacent cells until the ship is sunk.",
    info_insane_title  = "|cffffd700Insane:|r",
    info_insane_text1  = "Calculates the probability for every cell",
    info_insane_text2  = "based on remaining ship sizes.",
    info_insane_text3  = "Always fires at the highest-probability",
    info_insane_text4  = "cell.",
    hint_diff_panel    = "|cff888888Difficulty is chosen directly in the game area.|r",

    -- Sounds
    sound_enabled   = "Sounds enabled",
    sound_hit       = "Hit",
    sound_miss      = "Miss",
    sound_sunk      = "Sunk",
    sound_win       = "Victory",
    sound_loss      = "Defeat",

    guide_1         = "|cffffff00Goal:|r Sink all enemy ships before your own fleet is destroyed.",
    guide_2         = "|cffffff00Placement:|r 10×10, fleet 5/4/3/3/2. Ships may touch but cannot overlap. Left-click to place; rotate with the button, [R] or right-click. Undo the last ship until battle starts.",
    guide_3         = "|cffffff00Start:|r 'Random placement' arranges the entire fleet. Confirm with 'Start battle'; placement then locks.",
    guide_4         = "|cffffff00Battle:|r Left-click the enemy grid to fire. Every valid shot changes turns, including hits. Repeated targets cost no turn; right-click does not fire. Wait for the enemy response.",
    guide_5         = "|cffffff00Hit:|r A hit is marked in red. A miss is marked with a small cross.",
    guide_6         = "|cffffff00Sunk:|r When a ship is fully hit it turns red and is revealed.",
    guide_7         = "|cffffff00Difficulty:|r Classic = random | Pro = systematic | Insane = probability-based.",

    -- Reset
    btn_reset       = "Reset",
})
