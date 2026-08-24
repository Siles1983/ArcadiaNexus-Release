-- Hangman UI localization.
-- Puzzle content is intentionally kept in Words_deDE.lua and Words_enUS.lua.

ArcadiaNexus.RegisterLocale("HANGMAN", "deDE", {

    -- Portal-Titel (Renderer, linke Hälfte)
    portal_title    = "|cffaa44ffDunkles Portal|r",

    -- Fehler-Label (Renderer)
    error_label     = "Beschwörungsfehler: %s%d|r / %d",
    error_idle      = "Beschwörungsfehler: 0",

    -- Kategorie-Anzeige (Renderer, im Spielfeld)
    cat_display     = "Kategorie: |cff88aaff%s|r",

    -- Hint-Box Titel (Renderer)
    hint_label      = "|cffaa88ffHinweis:|r",

    -- Fehlversuche-Header (Renderer)
    wrong_header    = "|cffff4444Fehlversuche:|r",

    -- Dropdowns (Renderer)
    label_category  = "Kategorie:",
    label_diff      = "Schwierigkeit:",
    diff_easy       = "Einfach",
    diff_normal     = "Normal",
    diff_hard       = "Schwer",

    -- Buttons (Renderer)
    btn_exit        = "Beenden",
    btn_start       = "Spiel starten",

    -- GameOver-Panel (Renderer)
    go_win_title    = "|cff44ff44Beschwörung gelungen!|r",
    go_loss_title   = "|cffff2222Das Portal öffnet sich...|r",
    go_word         = "Das gesuchte Wort: |cff%s%s|r",
    go_stats        = "|cff88ff88Gewonnen: %d|r   |cffff6666Verloren: %d|r",
    btn_retry       = "Nochmal",
    btn_menu        = "Beenden",

    -- Settings-Panel: Box-Titel
    box_sounds      = "Sound",
    box_stats       = "Statistiken",
    box_guide       = "Anleitung",

    -- Settings-Panel: Sounds
    sound_enabled   = "Soundeffekte",

    -- Settings-Panel: Statistiken
    stats_wins      = "|cff44ff44Gewonnen:|r  %d",
    stats_losses    = "|cffff4444Verloren:|r   %d",
    btn_reset_stats = "Zurücksetzen",
    btn_reset       = "Reset",

    -- Settings-Panel: Spielanleitung
    guide_goal      = "|cffffff00Ziel:|r Errate das verborgene WoW-Lore-Wort, einen Buchstaben nach dem anderen.",
    guide_input     = "|cffffff00Eingabe:|r Klicke auf einen Buchstaben-Button oder tippe direkt auf der Tastatur.",
    guide_error     = "|cffffff00Fehler:|r Jeder Fehlversuch aktiviert ein Runensegment des Dunklen Portals.",
    guide_lose      = "|cffffff00Zu viele Fehler:|r Das Portal öffnet sich vollständig – Spiel verloren!",
    guide_hint      = "|cffaaaaaa Kategorie und Schwierigkeit im Spielfeld wählbar. Umlaute werden als AE/OE/UE geschrieben. Leicht=8 | Normal=6 | Schwer=4 Versuche.|r",
})
-- ============================================================
ArcadiaNexus.RegisterLocale("HANGMAN", "enUS", {

    -- Portal title
    portal_title    = "|cffaa44ffDark Portal|r",

    -- Error label
    error_label     = "Summoning errors: %s%d|r / %d",
    error_idle      = "Summoning errors: 0",

    -- Category display
    cat_display     = "Category: |cff88aaff%s|r",

    -- Hint box
    hint_label      = "|cffaa88ffHint:|r",

    -- Wrong letters header
    wrong_header    = "|cffff4444Wrong letters:|r",

    -- Dropdowns
    label_category  = "Category:",
    label_diff      = "Difficulty:",
    diff_easy       = "Easy",
    diff_normal     = "Normal",
    diff_hard       = "Hard",

    -- Buttons
    btn_exit        = "Exit",
    btn_start       = "Start Game",

    -- GameOver panel
    go_win_title    = "|cff44ff44Summoning complete!|r",
    go_loss_title   = "|cffff2222The portal opens...|r",
    go_word         = "The word was: |cff%s%s|r",
    go_stats        = "|cff88ff88Won: %d|r   |cffff6666Lost: %d|r",
    btn_retry       = "Play again",
    btn_menu        = "Exit",

    -- Settings boxes
    box_sounds      = "Sound",
    box_stats       = "Statistics",
    box_guide       = "Guide",

    -- Sounds
    sound_enabled   = "Sound effects",

    -- Statistics
    stats_wins      = "|cff44ff44Won:|r  %d",
    stats_losses    = "|cffff4444Lost:|r  %d",
    btn_reset_stats = "Reset",
    btn_reset       = "Reset",

    -- Guide
    guide_goal      = "|cffffff00Goal:|r Guess the hidden WoW-lore word, one letter at a time.",
    guide_input     = "|cffffff00Input:|r Click a letter button or type directly on the keyboard.",
    guide_error     = "|cffffff00Errors:|r Each wrong guess lights up a rune segment of the Dark Portal.",
    guide_lose      = "|cffffff00Too many errors:|r The portal fully opens – game lost!",
    guide_hint      = "|cffaaaaaa Category and difficulty selectable in the game area. Easy=8 | Normal=6 | Hard=4 attempts.|r",
})

-- Category labels are UI localization; puzzle answers and clues live in Words_*.lua.
ArcadiaNexus.RegisterLocale("HANGMAN_CATEGORIES", "deDE", {
    cat_all="Alle", cat_chars="Charaktere", cat_places="Orte",
    cat_weapons="Waffen", cat_raids="Schlachtzüge", cat_dungeons="Dungeons",
    cat_classes="Klassen", cat_races="Völker", cat_bosses="Bosse",
    cat_factions="Fraktionen", cat_creatures="Kreaturen", cat_professions="Berufe",
})

ArcadiaNexus.RegisterLocale("HANGMAN_CATEGORIES", "enUS", {
    cat_all="All", cat_chars="Characters", cat_places="Places",
    cat_weapons="Weapons", cat_raids="Raids", cat_dungeons="Dungeons",
    cat_classes="Classes", cat_races="Races", cat_bosses="Bosses",
    cat_factions="Factions", cat_creatures="Creatures", cat_professions="Professions",
})
