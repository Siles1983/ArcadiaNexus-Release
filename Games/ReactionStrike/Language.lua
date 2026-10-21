-- Games/ReactionStrike/Language.lua

ArcadiaNexus.RegisterLocale("REACTIONSTRIKE", "deDE", {
    game_title         = "Reaction Strike",

    diff_easy          = "Einfach",
    diff_normal        = "Normal",
    diff_hard          = "Schwer",

    lbl_besttime       = "Bestzeit",
    lbl_lasttime       = "Letzter Versuch",
    lbl_score          = "Punkte",
    lbl_ms             = "ms",

    state_waiting      = "Warten – erst beim SIGNAL reagieren!",
    state_signal       = "SIGNAL – jetzt reagieren!",
    state_fakeout_hint = "TÄUSCHUNG – nicht reagieren!",
    result_pending    = "Ergebnis noch nicht verbucht",
    state_idle         = "Schwierigkeit wählen und starten",

    result_great       = "Ausgezeichnet!",   -- < 200ms
    result_good        = "Gut!",             -- < 350ms
    result_ok          = "Geht so.",         -- < 500ms
    result_slow        = "Gültiger Treffer", -- kein Zeitlimit

    penalty_early      = "Zu früh!",
    penalty_fakeout    = "Falscher Orb!",
    penalty_wait       = "Warte",

    btn_start          = "Spiel starten",
    btn_retry          = "Nochmal",
    btn_exit           = "Beenden",

    fakeout_survived   = "Nicht getäuscht!",

    guide_1            = "Warte auf den blauen Orb und den Text SIGNAL.",
    guide_2            = "Klick irgendwo im Spielfeld, Leertaste oder Gamepad-A / rechte Schulter reagieren gleichberechtigt.",
    guide_3            = "Roter Orb und TÄUSCHUNG: Nicht reagieren. Beide Signale haben denselben Ton.",
    guide_4            = "Klick vor dem Signal = Fehlstart und Strafe.",
    guide_5            = "Normal/Schwer bewegt sich der Orb nur zur Darstellung. Gültige Treffer haben kein Zeitlimit; Top 3 und Bestzeit verwenden aufgerundete echte Millisekunden. Beenden verwirft offene Versuche, ohne Saves.",

    box_sounds         = "Sound",
    box_guide          = "Anleitung",
    sound_enabled      = "Sound aktiviert",
    sound_signal       = "Orb erscheint",
    sound_strike       = "Treffer",
    sound_penalty      = "Fehlstart / Fakeout",
    sound_result       = "Ergebnis",

    btn_reset          = "Reset",
})

ArcadiaNexus.RegisterLocale("REACTIONSTRIKE", "enUS", {
    game_title         = "Reaction Strike",

    diff_easy          = "Easy",
    diff_normal        = "Normal",
    diff_hard          = "Hard",

    lbl_besttime       = "Best Time",
    lbl_lasttime       = "Last Attempt",
    lbl_score          = "Score",
    lbl_ms             = "ms",

    state_waiting      = "Wait – react only to SIGNAL!",
    state_signal       = "SIGNAL – react now!",
    state_fakeout_hint = "FAKE – do not react!",
    result_pending    = "Result not recorded yet",
    state_idle         = "Choose difficulty and start",

    result_great       = "Excellent!",
    result_good        = "Good!",
    result_ok          = "Average.",
    result_slow        = "Valid strike",

    penalty_early      = "Too early!",
    penalty_fakeout    = "Wrong orb!",
    penalty_wait       = "Wait",

    btn_start          = "Start Game",
    btn_retry          = "Retry",
    btn_exit           = "Exit",

    fakeout_survived   = "Not fooled!",

    guide_1            = "Wait for the blue orb and the SIGNAL text.",
    guide_2            = "Click anywhere in the field, press Space or gamepad A / right shoulder; all inputs are equivalent.",
    guide_3            = "Red orb and FAKE: Do not react. Both signals use the same sound.",
    guide_4            = "Click before signal = false start penalty.",
    guide_5            = "On Normal/Hard the moving orb is visual only. Valid strikes have no time limit; Top 3 and best time use rounded-up measured milliseconds. Leaving discards open attempts, with no saves.",

    box_sounds         = "Sound",
    box_guide          = "Guide",
    sound_enabled      = "Sound enabled",
    sound_signal       = "Orb appears",
    sound_strike       = "Strike",
    sound_penalty      = "False start / Fakeout",
    sound_result       = "Result",

    btn_reset          = "Reset",
})
