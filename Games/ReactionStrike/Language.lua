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

    state_waiting      = "Klick oder Leertaste wenn der Orb erscheint!",
    state_fakeout_hint = "Roter Orb = NICHT klicken!",
    state_idle         = "Schwierigkeit wählen und starten",

    result_great       = "Ausgezeichnet!",   -- < 200ms
    result_good        = "Gut!",             -- < 350ms
    result_ok          = "Geht so.",         -- < 500ms
    result_slow        = "Zu langsam!",      -- >= 500ms

    penalty_early      = "Zu früh!",
    penalty_fakeout    = "Falscher Orb!",
    penalty_wait       = "Warte",

    btn_start          = "Spiel starten",
    btn_retry          = "Nochmal",
    btn_exit           = "Beenden",

    fakeout_survived   = "Nicht getäuscht!",

    guide_1            = "Warte bis der blaue Orb erscheint.",
    guide_2            = "Klicke den Orb ODER drücke die Leertaste.",
    guide_3            = "Roter Orb = Fakeout! Nicht klicken.",
    guide_4            = "Klick vor dem Signal = Fehlstart und Strafe.",
    guide_5            = "Normal/Schwer: Der Orb bewegt sich!",

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

    state_waiting      = "Click or press Space when the orb appears!",
    state_fakeout_hint = "Red orb = DO NOT click!",
    state_idle         = "Choose difficulty and start",

    result_great       = "Excellent!",
    result_good        = "Good!",
    result_ok          = "Average.",
    result_slow        = "Too slow!",

    penalty_early      = "Too early!",
    penalty_fakeout    = "Wrong orb!",
    penalty_wait       = "Wait",

    btn_start          = "Start Game",
    btn_retry          = "Retry",
    btn_exit           = "Exit",

    fakeout_survived   = "Not fooled!",

    guide_1            = "Wait for the blue orb to appear.",
    guide_2            = "Click the orb OR press Space.",
    guide_3            = "Red orb = Fakeout! Do not click.",
    guide_4            = "Click before signal = false start penalty.",
    guide_5            = "Normal/Hard: The orb moves!",

    box_sounds         = "Sound",
    box_guide          = "Guide",
    sound_enabled      = "Sound enabled",
    sound_signal       = "Orb appears",
    sound_strike       = "Strike",
    sound_penalty      = "False start / Fakeout",
    sound_result       = "Result",

    btn_reset          = "Reset",
})
