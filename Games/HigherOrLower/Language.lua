-- ============================================================
--  HigherOrLower – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "HIGHERORLOWER"
-- ============================================================

ArcadiaNexus.RegisterLocale("HIGHERORLOWER", "deDE", {
    game_title          = "Higher or Lower",

    -- HUD / Labels
    lbl_capital         = "Kapital",
    lbl_bet             = "Einsatz",
    lbl_streak          = "Streak",
    lbl_multiplier      = "Multiplikator",
    lbl_pending         = "Ausstehend",
    lbl_theme           = "Karten-Theme",
    lbl_card_backs      = "Kartenrückseiten:",
    lbl_gold            = "Gold",

    -- Buttons
    btn_higher          = "Höher",
    btn_lower           = "Niedriger",
    btn_cashout         = "Auszahlen",
    btn_continue        = "Weiter riskieren",
    btn_exit            = "Beenden",
    btn_start           = "Spiel starten",
    btn_reset           = "Reset",

    -- Schwierigkeiten
    diff_easy           = "Einfach",
    diff_normal         = "Normal",
    diff_hard           = "Schwer",

    -- Zustände
    state_idle          = "Schwierigkeit wählen",
    state_betting       = "Einsatz setzen",
    state_playing       = "Höher oder Niedriger?",
    state_streak_prompt = "Auszahlen oder weitermachen?",
    state_result        = "",
    state_gameover      = "Bankrott!",

    -- Ergebnisse
    result_correct      = "Richtig! Streak: {0}",
    result_wrong        = "Falsch! -{0} Gold",
    result_push         = "Unentschieden – Einsatz zurück",
    result_cashout      = "Ausgezahlt! +{0} Gold",
    result_joker        = "Joker! Streak verloren!",
    result_deck_empty   = "Deck leer – automatisch ausgezahlt!",

    -- Streak-Prompt
    prompt_title        = "Richtig! Streak: {0}",
    prompt_pending      = "Ausstehender Gewinn: +{0} Gold",
    prompt_multiplier   = "Multiplikator: x{0}",

    -- Themes
    theme_neutral       = "Classic",
    theme_alliance      = "Allianz",
    theme_horde         = "Horde",

    -- Ass-Hinweis
    ace_high            = "Ass: Hoch (14)",
    ace_low             = "Ass: Niedrig (1)",

    -- Settings-Boxen
    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Anleitung",

    -- Sound-Labels
    sound_enabled       = "Sound aktiviert",
    sound_flip          = "Karte aufdecken",
    sound_correct       = "Richtig geraten",
    sound_wrong         = "Falsch geraten",
    sound_cashout       = "Auszahlen",
    sound_joker         = "Joker",

    -- Spielanleitung
    guide_1             = "Tippe ob die nächste Karte höher oder niedriger ist.",
    guide_2             = "Richtig: Streak steigt, Multiplikator erhöht sich.",
    guide_3             = "Falsch: Streak endet, Einsatz verloren.",
    guide_4             = "Gleichstand: Unentschieden, Einsatz zurück, Streak bleibt.",
    guide_5             = "Auszahlen: Gewinn einstreichen und Serie beenden.",
    guide_6             = "Einfach: Ass = niedrig. Normal/Schwer: Ass flexibel.",
    guide_7             = "Schwer: 2 Joker im Deck — Joker bedeutet sofortigen Verlust.",
})

ArcadiaNexus.RegisterLocale("HIGHERORLOWER", "enUS", {
    game_title          = "Higher or Lower",

    -- HUD / Labels
    lbl_capital         = "Capital",
    lbl_bet             = "Bet",
    lbl_streak          = "Streak",
    lbl_multiplier      = "Multiplier",
    lbl_pending         = "Pending",
    lbl_theme           = "Card Theme",
    lbl_card_backs      = "Card backs:",
    lbl_gold            = "Gold",

    -- Buttons
    btn_higher          = "Higher",
    btn_lower           = "Lower",
    btn_cashout         = "Cash Out",
    btn_continue        = "Risk It",
    btn_exit            = "Exit",
    btn_start           = "Start Game",
    btn_reset           = "Reset",

    -- Schwierigkeiten
    diff_easy           = "Easy",
    diff_normal         = "Normal",
    diff_hard           = "Hard",

    -- Zustände
    state_idle          = "Choose Difficulty",
    state_betting       = "Place Your Bet",
    state_playing       = "Higher or Lower?",
    state_streak_prompt = "Cash Out or Risk It?",
    state_result        = "",
    state_gameover      = "Bankrupt!",

    -- Ergebnisse
    result_correct      = "Correct! Streak: {0}",
    result_wrong        = "Wrong! -{0} Gold",
    result_push         = "Push – Bet returned",
    result_cashout      = "Cash Out! +{0} Gold",
    result_joker        = "Joker! Streak lost!",
    result_deck_empty   = "Deck empty – automatic Cash Out!",

    -- Streak-Prompt
    prompt_title        = "Correct! Streak: {0}",
    prompt_pending      = "Pending Win: +{0} Gold",
    prompt_multiplier   = "Multiplier: x{0}",

    -- Themes
    theme_neutral       = "Classic",
    theme_alliance      = "Alliance",
    theme_horde         = "Horde",

    -- Ace hint
    ace_high            = "Ace: High (14)",
    ace_low             = "Ace: Low (1)",

    -- Settings boxes
    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Guide",

    -- Sound labels
    sound_enabled       = "Sound enabled",
    sound_flip          = "Card flip",
    sound_correct       = "Correct guess",
    sound_wrong         = "Wrong guess",
    sound_cashout       = "Cash Out",
    sound_joker         = "Joker",

    -- Guide
    guide_1             = "Guess whether the next card is higher or lower.",
    guide_2             = "Correct: streak grows, multiplier increases.",
    guide_3             = "Wrong: streak ends, bet is lost.",
    guide_4             = "Push: tie – bet returned, streak continues.",
    guide_5             = "Cash Out: collect winnings and end the streak.",
    guide_6             = "Easy: Ace = low. Normal/Hard: Ace is flexible.",
    guide_7             = "Hard: 2 Jokers in deck – Joker means instant loss.",
})
