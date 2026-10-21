-- ============================================================
--  ShellGame – Language.lua
--  Lokalisierung: deDE / enUS
-- ============================================================

local ArcadiaNexus = _G.ArcadiaNexus

ArcadiaNexus.RegisterLocale("SHELLGAME", "deDE", {
    game_title          = "Gadgetzan Cup Shuffle",
    lbl_capital         = "Kapital",
    lbl_bet             = "Einsatz",
    lbl_theme           = "Theme",
    lbl_ball            = "Kugel",
    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Anleitung",

    btn_new_round       = "Neue Runde",
    btn_exit            = "Beenden",
    btn_start           = "Spiel starten",
    btn_continue        = "Weiter spielen",
    btn_stop            = "Spiel beenden",
    btn_reset           = "Reset",

    diff_easy           = "Einfach",
    diff_normal         = "Normal",
    diff_hard           = "Schwer",

    -- Theme-Gruppen
    theme_group_alliance = "Allianz",
    theme_group_horde    = "Horde",
    theme_group_neutral  = "Neutral",

    -- Ball-Optionen
    ball_random          = "Zufällig",
    ball_blue            = "Blaue Kugel",
    ball_green           = "Grüne Kugel",
    ball_red             = "Rote Kugel",
    ball_violett         = "Violette Kugel",
    ball_yellow          = "Gelbe Kugel",

    -- Theme-Zufallsoption
    theme_random         = "Zufällig",

    state_idle          = "Schwierigkeit wählen",
    state_betting       = "Einsatz setzen",
    state_reveal        = "Merke dir den Becher!",
    state_shuffle       = "Folge der Kugel...",
    state_guessing      = "Wo ist die Kugel?",
    state_gameover      = "Bankrott!",

    result_win          = "Richtig! +{0} Gold",
    result_lose         = "Falsch! -{0} Gold",
    prompt_title        = "Runde beendet.",
    prompt_capital      = "Kapital: {0} Gold",

    sound_enabled       = "Sound aktiv",
    sound_reveal        = "Kugel zeigen",
    sound_shuffle       = "Mischen",
    sound_lift          = "Becher anheben",
    sound_win           = "Gewonnen",
    sound_lose          = "Verloren",
    sound_bankrupt      = "Bankrott",

    guide_1             = "Merke dir unter welchem Becher die Kugel liegt.",
    guide_2             = "Verfolge die Kugel während die Becher gemischt werden.",
    guide_3             = "Klicke auf den Becher unter dem du die Kugel vermutest.",
    guide_4             = "Schwer: Fake-Moves täuschen dich — Vorsicht!",
    guide_5             = "Unter 25 Kapital: Bankrott. Drei Slots speichern Kapital und Rundengrenzen. Beenden/Hide während einer gestarteten Runde verliert den bereits gesetzten Einsatz und zählt einmal als Niederlage; Fortsetzen wiederholt keine Mischsequenz.",
    guide_info_1        = "Einfach / Normal: 3 Becher  |  Schwer: 4 Becher",
    guide_info_2        = "Nettogewinn: Einsatz × 1 / 1,5 / 2 (Einfach / Normal / Schwer), zusätzlich Einsatz zurück. Halbchips werden exakt abgerechnet.",
    lbl_return="Auszahlung", lbl_net="Nettogewinn", profit_factor="Gewinn: Einsatz × %g + Einsatz zurück",
    confirm_exit="Runde abbrechen?", confirm_exit_body="Der gesetzte Einsatz geht verloren. Diese Runde zählt als Niederlage; danach wird die Kapitalpartie gespeichert.",
    btn_cancel="Abbrechen", btn_retry="Erneut buchen", result_pending="Ergebnisbuchung ausstehend",
    result_aborted="Runde abgebrochen", slot_invalid="Ungültiger Spielstand",
    phase_BETTING="Einsatzwahl", phase_RESULT="Runde beendet", phase_GAMEOVER="Bankrott",
    phase_RESULT_PENDING="Buchung ausstehend", phase_REVEAL="Offene Runde – Einsatzverlust bei Fortsetzen",
    phase_SHUFFLE="Offene Runde – Einsatzverlust bei Fortsetzen", phase_GUESSING="Offene Runde – Einsatzverlust bei Fortsetzen",
    cup_slot="Becher %d", chosen_correct="Gewählt: %d · Richtig: %d",
})

ArcadiaNexus.RegisterLocale("SHELLGAME", "enUS", {
    game_title          = "Gadgetzan Cup Shuffle",
    lbl_capital         = "Capital",
    lbl_bet             = "Bet",
    lbl_theme           = "Theme",
    lbl_ball            = "Ball",
    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Guide",

    btn_new_round       = "New Round",
    btn_exit            = "Exit",
    btn_start           = "Start Game",
    btn_continue        = "Keep Playing",
    btn_stop            = "End Game",
    btn_reset           = "Reset",

    diff_easy           = "Easy",
    diff_normal         = "Normal",
    diff_hard           = "Hard",

    theme_group_alliance = "Alliance",
    theme_group_horde    = "Horde",
    theme_group_neutral  = "Neutral",

    ball_random          = "Random",
    ball_blue            = "Blue Ball",
    ball_green           = "Green Ball",
    ball_red             = "Red Ball",
    ball_violett         = "Violet Ball",
    ball_yellow          = "Yellow Ball",

    theme_random         = "Random",

    state_idle          = "Choose difficulty",
    state_betting       = "Place your bet",
    state_reveal        = "Remember the cup!",
    state_shuffle       = "Follow the ball...",
    state_guessing      = "Where is the ball?",
    state_gameover      = "Bankrupt!",

    result_win          = "Correct! +{0} Gold",
    result_lose         = "Wrong! -{0} Gold",
    prompt_title        = "Round over.",
    prompt_capital      = "Capital: {0} Gold",

    sound_enabled       = "Sound enabled",
    sound_reveal        = "Reveal ball",
    sound_shuffle       = "Shuffle",
    sound_lift          = "Lift cup",
    sound_win           = "Win",
    sound_lose          = "Lose",
    sound_bankrupt      = "Bankrupt",

    guide_1             = "Remember which cup hides the ball.",
    guide_2             = "Track the ball while the cups are shuffled.",
    guide_3             = "Click the cup you think hides the ball.",
    guide_4             = "Hard: Fake moves will deceive you — watch out!",
    guide_5             = "Below 25 capital: bankrupt. Three slots preserve capital and round boundaries. Ending/hiding a started round loses its existing stake and counts once as a loss; resume never replays a shuffle.",
    guide_info_1        = "Easy / Normal: 3 cups  |  Hard: 4 cups",
    guide_info_2        = "Net profit: stake × 1 / 1.5 / 2 (Easy / Normal / Hard), plus stake returned. Half chips are settled exactly.",
    lbl_return="Return", lbl_net="Net profit", profit_factor="Profit: stake × %g + stake returned",
    confirm_exit="Abort round?", confirm_exit_body="Your stake will be lost. This round counts as a loss, then the capital game is saved.",
    btn_cancel="Cancel", btn_retry="Retry booking", result_pending="Result booking pending",
    result_aborted="Round aborted", slot_invalid="Invalid save",
    phase_BETTING="Place a bet", phase_RESULT="Round completed", phase_GAMEOVER="Bankrupt",
    phase_RESULT_PENDING="Booking pending", phase_REVEAL="Open round – stake lost on resume",
    phase_SHUFFLE="Open round – stake lost on resume", phase_GUESSING="Open round – stake lost on resume",
    cup_slot="Cup %d", chosen_correct="Chosen: %d · Correct: %d",
})
