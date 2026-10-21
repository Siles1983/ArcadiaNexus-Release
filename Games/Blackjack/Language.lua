-- ============================================================
--  Blackjack – Language.lua
--  Lokalisierung: deDE + enUS
--  catID: "BLACKJACK"
-- ============================================================

ArcadiaNexus.RegisterLocale("BLACKJACK", "deDE", {
    action_phase = "Während Austeilen oder Dealerzug sind Aktionen gesperrt.",
    action_insurance_closed = "Versicherung nur bei offenem Angebot gegen Dealer-Ass.",
    action_insurance_open = "Zuerst Versicherung kaufen oder ablehnen.",
    action_finished_hand = "Diese Hand ist bereits abgeschlossen.",
    action_capital = "Für den zusätzlichen Einsatz fehlt Kapital.",
    action_two_cards = "Verdoppeln ist nur mit genau zwei Karten möglich.",
    action_split_aces = "Geteilte Asse bekommen nur eine weitere Karte.",
    action_split_once = "Es darf nur einmal geteilt werden.",
    action_pair = "Teilen erfordert zwei Karten mit gleichem Rang.",
    btn_decline = "Ablehnen",
    lbl_return = "Rückzahlung",
    lbl_net = "Netto",
    below_minimum = "Unter Mindesteinsatz 25",
    lb_table = "Vier-Deck-Tisch",
    lb_rounds = "Abgeschlossene Runden",
    lb_legacy_sessions = "Frühere Sitzungen",
    lb_legacy_capital = "Früheres Kapital",
    state_dealing = "Karten werden ausgeteilt...",
    state_round_result = "Rundenergebnis",
    state_result_pending = "Ergebnisbuchung ausstehend",
    result_retry = "Buchung wiederholen; keine zweite Belohnung.",
    btn_retry = "Erneut buchen",
    slot_invalid = "Ungültiger Spielstand",
    guide_10 = "Dealer hält auf Soft 17 und prüft Blackjack vor Spieleraktionen (bei Ass nach Versicherung).",
    guide_11 = "Geteilte Asse: je nur eine Karte. Split-21 ist kein natürlicher Blackjack; kein erneutes Teilen.",
    guide_12 = "Start öffnet drei Slots, jeder mit eigenem Kapital. Neue Partie: 100 Chips. Beenden speichert.",
    guide_13 = "Neue Runde bleibt am selben Tisch. Netto aus allen Händen + Versicherung: Gewinn/Verlust/Unentschieden.",
    action_unavailable = "Während Austeilen, Dealerzug oder Versicherung gesperrt; sonst aktive Hand, Kartenanzahl und Kapital prüfen.",
    tip_hit = "Weitere Karte zur aktiven Hand ziehen.",
    tip_stand = "Aktive Hand halten; nächste Hand oder Dealer folgt.",
    tip_double = "Mit zwei Karten Einsatz dieser Hand verdoppeln, genau eine Karte ziehen.",
    tip_split = "Gleiche Ränge einmal teilen; zusätzlicher Einsatz für zweite Hand.",
    tip_insurance = "Halber Haupteinsatz als Nebenwette auf Dealer-Blackjack.",
    game_title          = "Blackjack",

    -- HUD / Labels
    lbl_capital         = "Kapital",
    lbl_bet             = "Einsatz",
    lbl_ai_opponents    = "Mitspieler",
    lbl_dealer          = "Dealer",
    lbl_player          = "Spieler",
    lbl_theme           = "Karten-Theme",
    lbl_card_backs      = "Kartenrückseiten:",
    lbl_gold            = "Chips",
    lbl_hidden          = "??",

    -- Buttons
    btn_hit             = "Karte",
    btn_stand           = "Halten",
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

    -- Mitspieler Dropdown
    ai_0                = "0 Mitspieler",
    ai_1                = "1 Mitspieler",
    ai_2                = "2 Mitspieler",

    -- Zustände
    state_idle          = "Tischpartie wählen",
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
    guide_2             = "Vier Decks. Ass zählt 1/11; 10, Bube, Dame und König zählen 10.",
    guide_3             = "Karte: eine weitere Karte ziehen.",
    guide_4             = "Halten: aktive Hand abschließen; danach nächste Hand oder Dealer.",
    guide_5             = "Verdoppeln: aktive Zweikartenhand, eigener Einsatz x2, eine Karte. Auch nach Nicht-Ass-Split.",
    guide_6             = "Einmal gleiche Ränge teilen, höchstens zwei Hände. Jede mit eigenem Einsatz.",
    guide_7             = "Versicherung: bei Dealer-Ass, halber Haupteinsatz, zahlt bei Dealer-Blackjack 2:1 separat.",
    guide_8             = "Natürlicher Blackjack: ursprüngliche Zweikartenhand mit Ass + 10-Wert, zahlt 3:2.",
    guide_9             = "Mindesteinsatz 25 Chips. Unter 25 endet die Tischpartie; kein automatisches Auffüllen.",

    -- Reset
    btn_reset           = "Reset",
})

ArcadiaNexus.RegisterLocale("BLACKJACK", "enUS", {
    action_phase = "Actions are locked during dealing or the dealer turn.",
    action_insurance_closed = "Insurance requires an open offer against a dealer Ace.",
    action_insurance_open = "Buy or decline insurance first.",
    action_finished_hand = "This hand is already complete.",
    action_capital = "Not enough capital for the additional bet.",
    action_two_cards = "Double requires exactly two cards.",
    action_split_aces = "Split Aces receive only one additional card.",
    action_split_once = "Only one split is allowed.",
    action_pair = "Split requires two cards of the same rank.",
    btn_decline = "Decline",
    lbl_return = "Return",
    lbl_net = "Net",
    below_minimum = "Below minimum bet 25",
    lb_table = "Four-deck table",
    lb_rounds = "Completed rounds",
    lb_legacy_sessions = "Earlier sessions",
    lb_legacy_capital = "Earlier capital",
    state_dealing = "Dealing cards...",
    state_round_result = "Round result",
    state_result_pending = "Result booking pending",
    result_retry = "Retry booking; rewards are granted once.",
    btn_retry = "Retry booking",
    slot_invalid = "Invalid save",
    guide_10 = "Dealer stands on soft 17 and checks Blackjack before player actions (after insurance against Ace).",
    guide_11 = "Split Aces: one card each. Split 21 is ordinary 21; no re-splitting.",
    guide_12 = "Start opens three slots, each with its own capital. New table: 100 chips. Exit saves.",
    guide_13 = "New Round keeps the same table. Net across all hands + insurance determines win/loss/draw.",
    action_unavailable = "Locked during deal, dealer turn or insurance; otherwise check active hand, card count and capital.",
    tip_hit = "Draw another card for the active hand.",
    tip_stand = "Stand on the active hand; next hand or dealer follows.",
    tip_double = "With two cards, double this hand only and draw one card.",
    tip_split = "Split equal ranks once; pay a second hand bet.",
    tip_insurance = "Half the main bet as a separate bet on dealer Blackjack.",
    game_title          = "Blackjack",

    -- HUD / Labels
    lbl_capital         = "Capital",
    lbl_bet             = "Bet",
    lbl_ai_opponents    = "Table Players",
    lbl_dealer          = "Dealer",
    lbl_player          = "Player",
    lbl_theme           = "Card Theme",
    lbl_card_backs      = "Card backs:",
    lbl_gold            = "Chips",
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

    -- Mitspieler Dropdown
    ai_0                = "0 Table Players",
    ai_1                = "1 Table Player",
    ai_2                = "2 Table Players",

    -- Zustände
    state_idle          = "Choose Table Save",
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
    guide_2             = "Four decks. Ace counts as 1/11; 10, Jack, Queen and King count as 10.",
    guide_3             = "Hit: draw another card.",
    guide_4             = "Stand: end your turn, dealer draws.",
    guide_5             = "Double: active two-card hand, its own bet x2, one card. Allowed after non-Ace split.",
    guide_6             = "Split equal ranks once, at most two hands, each with its own bet.",
    guide_7             = "Insurance: against dealer Ace, half the main bet; pays 2:1 separately on dealer Blackjack.",
    guide_8             = "Natural Blackjack: original two-card Ace + 10-value hand, pays 3:2.",
    guide_9             = "Minimum bet: 25 chips. Below 25 ends the table; no automatic refill.",

    -- Reset
    btn_reset           = "Reset",
})
