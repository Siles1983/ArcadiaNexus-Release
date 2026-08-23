-- ============================================================
--  Blackjack – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "BLACKJACK"
-- ============================================================

ArcadiaNexus.RegisterLocale("BLACKJACK", "deDE", {
    game_title          = "Blackjack",

    -- HUD / Labels
    lbl_capital         = "Kapital",
    lbl_bet             = "Einsatz",
    lbl_ai_opponents    = "KI-Gegner",
    lbl_dealer          = "Dealer",
    lbl_player          = "Spieler",
    lbl_theme           = "Karten-Theme",
    lbl_card_backs      = "Kartenrückseiten:",
    lbl_gold            = "Gold",
    lbl_hidden          = "??",

    -- Buttons
    btn_hit             = "Karte",
    btn_stand           = "Weiter",
    btn_double          = "x2",
    btn_split           = "Teilen",
    btn_insurance       = "Vers.",
    btn_new_round       = "Neue Runde",
    btn_exit            = "Beenden",
    btn_start           = "Spiel starten",
    btn_deal            = "Karten geben",

    -- Schwierigkeiten
    diff_easy           = "Einfach",
    diff_normal         = "Normal",
    diff_hard           = "Schwer",

    -- KI-Gegner Dropdown
    ai_0                = "0 KI-Gegner",
    ai_1                = "1 KI-Gegner",
    ai_2                = "2 KI-Gegner",

    -- Zustände
    state_idle          = "Schwierigkeit wählen",
    state_betting       = "Einsatz setzen",
    state_playing       = "Dein Zug",
    state_dealer_turn   = "Dealer zieht...",
    state_gameover      = "Bankrott!",

    -- Ergebnisse
    result_win          = "Gewonnen!",
    result_blackjack    = "Blackjack!",
    result_lose         = "Verloren!",
    result_bust         = "Überkauft!",
    result_push         = "Unentschieden",
    result_insurance    = "Versicherung greift!",

    -- Themes
    theme_neutral       = "Classic",
    theme_alliance      = "Allianz",
    theme_horde         = "Horde",

    -- Sound-Labels
    sound_enabled       = "Sound aktiviert",
    sound_deal          = "Karte austeilen",
    sound_flip          = "Karte aufdecken",
    sound_win           = "Gewonnen",
    sound_lose          = "Verloren",
    sound_bust          = "Überkauft",
    sound_chip          = "Chip setzen",

    -- Settings-Boxen
    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Anleitung",

    -- Spielanleitung
    guide_1             = "Ziel: näher an 21 als der Dealer, ohne zu überkaufen.",
    guide_2             = "Ass zählt 1 oder 11, Bildkarten zählen 10.",
    guide_3             = "Karte: eine weitere Karte ziehen.",
    guide_4             = "Weiter: keine weitere Karte, Dealer ist dran.",
    guide_5             = "Verdoppeln: Einsatz x2, genau eine Karte.",
    guide_6             = "Teilen: zwei gleiche Karten in zwei Hände aufteilen.",
    guide_7             = "Versicherung: bei Dealer-Ass – Neben-Wette auf Dealer-Blackjack.",
    guide_8             = "Blackjack (Ass + Bildkarte) zahlt 3:2.",
    guide_9             = "Chip wählen setzt den Einsatz. Bei 0 Gold: Bankrott.",

    -- Reset
    btn_reset           = "Reset",
})

ArcadiaNexus.RegisterLocale("BLACKJACK", "enUS", {
    game_title          = "Blackjack",

    -- HUD / Labels
    lbl_capital         = "Capital",
    lbl_bet             = "Bet",
    lbl_ai_opponents    = "AI Opponents",
    lbl_dealer          = "Dealer",
    lbl_player          = "Player",
    lbl_theme           = "Card Theme",
    lbl_card_backs      = "Card backs:",
    lbl_gold            = "Gold",
    lbl_hidden          = "??",

    -- Buttons
    btn_hit             = "Hit",
    btn_stand           = "Stand",
    btn_double          = "Double",
    btn_split           = "Split",
    btn_insurance       = "Insurance",
    btn_new_round       = "New Round",
    btn_exit            = "Exit",
    btn_start           = "Start Game",
    btn_deal            = "Deal",

    -- Schwierigkeiten
    diff_easy           = "Easy",
    diff_normal         = "Normal",
    diff_hard           = "Hard",

    -- KI-Gegner Dropdown
    ai_0                = "0 AI Opponents",
    ai_1                = "1 AI Opponent",
    ai_2                = "2 AI Opponents",

    -- Zustände
    state_idle          = "Choose Difficulty",
    state_betting       = "Place Your Bet",
    state_playing       = "Your Turn",
    state_dealer_turn   = "Dealer's Turn...",
    state_gameover      = "Bankrupt!",

    -- Ergebnisse
    result_win          = "You Win!",
    result_blackjack    = "Blackjack!",
    result_lose         = "You Lose!",
    result_bust         = "Bust!",
    result_push         = "Push",
    result_insurance    = "Insurance pays!",

    -- Themes
    theme_neutral       = "Classic",
    theme_alliance      = "Alliance",
    theme_horde         = "Horde",

    -- Sound-Labels
    sound_enabled       = "Sound enabled",
    sound_deal          = "Deal card",
    sound_flip          = "Flip card",
    sound_win           = "Win",
    sound_lose          = "Lose",
    sound_bust          = "Bust",
    sound_chip          = "Place chip",

    -- Settings-Boxen
    box_theme           = "Theme",
    box_sounds          = "Sound",
    box_guide           = "Guide",

    -- Spielanleitung
    guide_1             = "Goal: get closer to 21 than the dealer without busting.",
    guide_2             = "Ace counts as 1 or 11; face cards count as 10.",
    guide_3             = "Hit: draw another card.",
    guide_4             = "Stand: end your turn, dealer draws.",
    guide_5             = "Double: bet x2, draw exactly one card.",
    guide_6             = "Split: split two equal cards into two hands.",
    guide_7             = "Insurance: when dealer shows Ace – side bet on dealer Blackjack.",
    guide_8             = "Blackjack (Ace + face card) pays 3:2.",
    guide_9             = "Choose a chip to set your bet. At 0 Gold: bankrupt.",

    -- Reset
    btn_reset           = "Reset",
})
