-- ============================================================
--  ArcadiaNexus UI – Lokalisierung
--  catID: "UI"
-- ============================================================

ArcadiaNexus.RegisterLocale("UI", "deDE", {
    -- Bottom-Tabs
    tab_games           = "Spiele",
    tab_scoreboard      = "Bestenliste",
    tab_achievements    = "Erfolge",
    tab_settings        = "Einstellungen",

    -- Content-Label Fallbacks
    label_games         = "Spiele",
    label_settings      = "Einstellungen",
    label_feed          = "Feed",

    -- Header: Spieler-Info
    -- %1 = Level, %2 = Klasse
    HEADER_CHARACTER_LEVEL_CLASS = "Stufe %s %s",

    -- Level-Up Feedback im Header
    HEADER_LEVEL_UP     = "Arcade Level %d erreicht!",

    -- Safe-Mode / Status

    -- Kategorie-Gruppen in der Sidebar
    cat_DENKSPIELE  = "Denkspiele",
    cat_KARTEN      = "Karten & Glück",
    cat_GESCHICK    = "Geschick & Timing",
    cat_ARCADE      = "Arcade",
    cat_STRATEGIE   = "Strategie",
    cat_WORT        = "Wort & Wissen",
    cat_RAETSEL     = "Rätsel & Logik",
    cat_IDLE        = "Idle & Casual",
    cat_SONSTIGE    = "Sonstige",
    cat_ALLGEMEIN   = "Allgemein",
    cat_FAVORITEN   = "Favoriten",
    fav_empty       = "Keine Favoriten vorhanden.",

    searchbar_placeholder = "Suche…",

    ctx_fav_title_add    = "Favorit hinzufügen",
    ctx_fav_add          = "Als Favorit markieren",
    ctx_fav_title_remove = "Favorit entfernen",
    ctx_fav_remove       = "Aus Favoriten entfernen",
    welcome_title                = "Willkommen in ArcadiaNexus",
    welcome_gotd_header          = "Spiel des Tages",
    welcome_new_games_header     = "Neue Spiele",
    welcome_new_games_placeholder = "Demnächst verfügbar – stay tuned!",
    welcome_changelog_header     = "Changelog",
    welcome_changelog_text       = "v1.1.3 – Launch\n• 34 Spiele verfügbar\n• Achievement-System\n• Bestenliste\n• Tägliche & wöchentliche Herausforderungen\n• Suchfunktion\n• Custom Spiel des Tages Button",
    -- Leaderboard-UI
    lb_highscores   = "Bestscores",
    lb_wins         = "Siege",
    lb_losses       = "Niederlagen",
    lb_draws        = "Unentschieden",
    lb_played       = "Gespielt",
    lb_best_level       = "Höchstes Level",
    lb_levels_cleared   = "Level gelöst",
    lb_capital          = "Kapital",
    lb_max_capital      = "Höchstes Kapital",
    lb_fruits_eaten     = "Früchte",
    lb_lines_cleared    = "Reihen",
    lb_max_multiplier   = "Höchster Multiplikator",
    lb_max_streak       = "Höchste Streak",
    lb_adoptions        = "Adoptierte Pets",
    lb_records          = "Rekorde",
    lb_no_data          = "Noch keine Spiele",
    lb_diff_easy    = "Einfach",
    lb_diff_normal  = "Normal",
    lb_diff_hard    = "Schwer",
    lb_diff_default = "Gesamt",
    lb_diff_medium  = "Mittel",
    lb_diff_1card   = "1 Karte",
    lb_diff_3card   = "3 Karten",

    -- Tabs (neu)
    tab_profil          = "Profil",

    -- Stats-UI
    stats_header_profile      = "Spieler-Profil",
    stats_level               = "Level:",
    stats_total_xp            = "Gesamt-XP:",
    stats_tavern_gold         = "Tavern Gold:",
    stats_streak              = "Login-Streak:",
    stats_days                = "Tage",
    stats_best                = "Beste:",
    stats_gotd                = "Spiel des Tages:",
    stats_header_games        = "Spielstatistik",
    stats_total_games         = "Spiele gesamt:",
    stats_wins                = "Gewonnen:",
    stats_losses              = "Verloren:",
    stats_draws               = "Unentschieden:",
    stats_fav_game            = "Lieblingsspiel:",
    stats_top_score           = "Höchster Score:",
    stats_header_achievements = "Erfolge",
    stats_ach_count           = "Freigeschaltet:",
    stats_header_challenges   = "Challenges",
    stats_challenges_done     = "Abgeschlossen:",
    stats_challenges_gold     = "Gold verdient:",
    stats_title_select        = "Aktiver Titel:",
    stats_title_visible       = "Titel im Header anzeigen",
    stats_no_titles           = "Noch keine Titel freigeschaltet.",
    summary_title             = "Zusammenfassung",
    summary_recent            = "Neueste Erfolge",
    summary_progress          = "Fortschrittsüberblick",
    summary_overall           = "Gesamt",
    summary_no_recent         = "Noch keine Erfolge freigeschaltet.",
    summary_no_data           = "Keine Achievement-Daten verfügbar.",

    -- Toast
    toast_achievement_earned  = "Erfolg errungen!",
    toast_challenge_complete  = "Challenge abgeschlossen!",
    toast_gold_earned         = "Tavern Gold erhalten!",

    -- Hub-Einstellungen
    hubsettings_btn             = "Hub-Einstellungen",
    hubsettings_title           = "ArcadiaNexus Einstellungen",
    hubsettings_toast_section   = "Achievement Toast",
    hubsettings_toast_desc      = "Klicke den Button, um den Toast-Anker anzuzeigen. Ziehe ihn an die gewünschte Position und klicke erneut zum Bestätigen.",
    hubsettings_toast_anchor_show    = "Anker anzeigen & verschieben",
    hubsettings_toast_anchor_confirm = "Position bestätigen",
    hubsettings_anchor_label    = "Toast-Anker  (Ziehen zum Positionieren)",
    hubsettings_position        = "Position:",
    hubsettings_reset           = "Zurücksetzen",
    hubsettings_toast_preview   = "Vorschau",

    -- Hub-Einstellungen GOTD
    hubsettings_gotd_section      = "Spiel des Tages",
    hubsettings_gotd_desc         = "Das Spiel des Tages wechselt täglich. Gewinne +25% XP beim Spielen.",
    hubsettings_gotd_show         = "Box anzeigen",
    hubsettings_gotd_anchor_show  = "GOTD-Anker verschieben",
    hubsettings_gotd_anchor_label = "GOTD-Anker  (Ziehen zum Positionieren)",
    hubsettings_dev_section       = "Entwickler",
    hubsettings_dev_devmode       = "Developer-Modus aktivieren",
    hubsettings_dev_devmode_desc  = "Aktiviert detaillierte Debug-Logs im Chat. Nur für Entwicklungszwecke.",
    hubsettings_dev_locked        = "Developer-Modus ist an deine Charaktere gebunden. Dieser Charakter steht nicht auf der Allowlist.",
    hubsettings_dev_allowlist_hint = "DevMode ist noch nicht verriegelt. Im Chat /andevwho eingeben und den Key in Core/DevAccess.lua unter ALLOW_CHARS eintragen.",

    -- Hub Settings Sub-Tabs
    -- Hub Settings UI Scaling
    hubsettings_scale_section = "UI-Skalierung",
    hubsettings_scale_desc    = "Fenstergröße anpassen. 1.0 = Standardgröße.",

    hubsettings_tab_general    = "Allgemein",
    hubsettings_tab_games      = "Spiele",
    hubsettings_tab_stats      = "Statistiken",
    hubsettings_tab_developer  = "Entwickler",

    -- Hub Settings Lock
    hubsettings_lock_section   = "Fenster",
    hubsettings_lock_ui        = "Fenster-Position sperren",
    hubsettings_lock_desc      = "Verhindert, dass das Fenster versehentlich verschoben wird.",

    -- Hub Settings Stats Reset
    hubsettings_stats_section        = "Statistiken zurücksetzen",
    hubsettings_stats_reset_desc     = "Setzt Bestenliste, Profil, Streak und Challenges zurück. Erfolge bleiben erhalten.",
    hubsettings_stats_reset_btn      = "Statistiken zurücksetzen",
    hubsettings_stats_confirm1_title = "Statistiken zurücksetzen?",
    hubsettings_stats_confirm1_body  = "Bestenliste, Profil, Streak und Challenges werden unwiderruflich gelöscht. Fortfahren?",
    hubsettings_stats_confirm2_title = "Wirklich zurücksetzen?",
    hubsettings_stats_confirm2_body  = "Letzte Warnung: Alle Statistiken werden auf Startwerte gesetzt.",

    -- Export/Import Popup
    hubsettings_export_popup_title  = "Statistiken exportieren",
    hubsettings_export_popup_hint   = "Den String kopieren und sicher aufbewahren.",
    hubsettings_export_copy         = "Alles markieren",
    hubsettings_export_close        = "Schließen",
    hubsettings_import_popup_title  = "Statistiken importieren",
    hubsettings_import_popup_hint   = "Export-String einfügen und Importieren klicken.",
    hubsettings_import_confirm_btn  = "Importieren",
    hubsettings_import_cancel       = "Abbrechen",

    -- Games Tab Buttons
    hubsettings_games_confirm_btn   = "Bestätigen & Neu laden",
    hubsettings_games_confirm_title = "Änderungen übernehmen?",
    hubsettings_games_confirm_body  = "Das Addon wird neu geladen. Versteckte Spiele werden erst danach ausgeblendet.",
    hubsettings_games_reset_btn     = "Liste zurücksetzen",
    hubsettings_games_reload_hint   = "|cffffaa00Änderungen werden erst nach /reload sichtbar.|r",

    -- Hub Settings Dual Listbox
    hubsettings_games_section = "Spiele verwalten",
    hubsettings_games_desc    = "Doppelklick auf ein Spiel zum Ausblenden oder Einblenden. Versteckte Spiele erscheinen nicht in der Sidebar.",
    hubsettings_games_visible = "Sichtbar",
    hubsettings_games_hidden  = "Versteckt",

    -- Hub Settings Export/Import
    hubsettings_export_section       = "Export / Import",
    hubsettings_export_desc          = "Bestenliste, Profil, Streak und Challenge-Verlauf exportieren oder importieren. Erfolge sind nicht enthalten.",
    hubsettings_export_btn           = "Exportieren",
    hubsettings_import_btn           = "Importieren",
    hubsettings_export_clear         = "Leeren",
    hubsettings_import_confirm_title = "Statistiken importieren?",
    hubsettings_import_confirm_body  = "Aktuelle Statistiken werden durch die importierten Daten überschrieben. Fortfahren?",

    -- DevMode Confirm
    devmode_confirm_enable_title  = "Developer-Modus aktivieren?",
    devmode_confirm_enable_body   = "Der Developer-Modus ist ausschließlich für Entwickler bestimmt. Das Addon wird neu geladen.",
    devmode_confirm_disable_title = "Developer-Modus deaktivieren?",
    devmode_confirm_disable_body  = "Developer-Modus deaktivieren? Das Addon wird neu geladen.",
    -- GameResultDialog
    result_score      = "Punkte",
    result_xp         = "XP",
    result_gold       = "Gold",
    result_highscore  = "Highscore",
    result_new_hs     = "|cffffd700Neuer Highscore!|r",

    -- GameResultDialog – Buttons (zentral für alle Minigames)
    btn_play_again    = "Nochmal",
    btn_restart       = "Nochmal",
    btn_new_game      = "Neues Spiel",
    btn_retry         = "Nochmal",
    btn_exit          = "Beenden",
    btn_menu          = "Menü",
    btn_next_level    = "Nächstes Level",
    btn_replay_level  = "Wiederholen",
    btn_level_select  = "Levelauswahl",
    popup_resume      = "Weiterspielen",
    btn_next_round    = "Nächste Runde",
    btn_continue      = "Weiter",
    btn_give_up       = "Aufgeben",
    btn_stop          = "Spiel beenden",
    btn_reset_chips   = "Neu starten",
    btn_bankrupt      = "Bankrott / Reset",

    -- Save-Slot-Menü (SaveSlotMenu.lua)
    slot_menu_title          = "Spielstand wählen",
    slot_label               = "Slot %d",
    slot_empty               = "— Leer —",
    slot_paused              = "läuft",
    hint_select_slot         = "Wähle einen Speicherslot",
    confirm_overwrite        = "Spielstand überschreiben?",
    confirm_overwrite_body   = "Slot %d enthält einen Spielstand.",
    confirm_delete           = "Spielstand wirklich löschen?",
    confirm_delete_body      = "Slot %d wird geleert.",
    btn_yes                  = "Ja",
    btn_no                   = "Abbrechen",
})

ArcadiaNexus.RegisterLocale("UI", "enUS", {
    -- Bottom-Tabs
    tab_games           = "Games",
    tab_scoreboard      = "Leaderboard",
    tab_achievements    = "Achievements",
    tab_settings        = "Settings",

    -- Content-Label Fallbacks
    label_games         = "Games",
    label_settings      = "Settings",
    label_feed          = "Feed",

    -- Header: Player-Info
    HEADER_CHARACTER_LEVEL_CLASS = "Level %s %s",

    -- Level-Up Feedback in Header
    HEADER_LEVEL_UP     = "Arcade Level %d reached!",

    -- Safe-Mode / Status

    -- Category groups in the sidebar
    cat_DENKSPIELE  = "Strategy",
    cat_KARTEN      = "Cards & Luck",
    cat_GESCHICK    = "Skill & Timing",
    cat_ARCADE      = "Arcade",
    cat_STRATEGIE   = "Strategy Games",
    cat_WORT        = "Word & Knowledge",
    cat_RAETSEL     = "Puzzles & Logic",
    cat_IDLE        = "Idle & Casual",
    cat_SONSTIGE    = "Other",
    cat_ALLGEMEIN   = "General",
    cat_FAVORITEN   = "Favorites",
    fav_empty       = "No favorites yet.",

    searchbar_placeholder = "Search…",

    ctx_fav_title_add    = "Add Favorite",
    ctx_fav_add          = "Mark as Favorite",
    ctx_fav_title_remove = "Remove Favorite",
    ctx_fav_remove       = "Remove from Favorites",
    welcome_title                = "Welcome to ArcadiaNexus",
    welcome_gotd_header          = "Game of the Day",
    welcome_new_games_header     = "New Games",
    welcome_new_games_placeholder = "Coming soon – stay tuned!",
    welcome_changelog_header     = "Changelog",
    welcome_changelog_text       = "v1.1.3 – Launch\n• 34 games available\n• Achievement system\n• Leaderboard\n• Daily & weekly challenges\n• Searchbar\n• Custom Game of Day Button",

    -- Leaderboard-UI
    lb_highscores   = "Best Scores",
    lb_wins         = "Wins",
    lb_losses       = "Losses",
    lb_draws        = "Draws",
    lb_played       = "Played",
    lb_best_level       = "Highest level",
    lb_levels_cleared   = "Levels cleared",
    lb_capital          = "Capital",
    lb_max_capital      = "Highest capital",
    lb_fruits_eaten     = "Fruit eaten",
    lb_lines_cleared    = "Lines cleared",
    lb_max_multiplier   = "Highest multiplier",
    lb_max_streak       = "Highest streak",
    lb_adoptions        = "Pets adopted",
    lb_records          = "Records",
    lb_no_data          = "No games played yet",
    lb_diff_easy    = "Easy",
    lb_diff_normal  = "Normal",
    lb_diff_hard    = "Hard",
    lb_diff_default = "Overall",
    lb_diff_medium  = "Medium",
    lb_diff_1card   = "1 Card",
    lb_diff_3card   = "3 Cards",

    -- Tabs (new)
    tab_profil          = "Profile",

    -- Stats-UI
    stats_header_profile      = "Player Profile",
    stats_level               = "Level:",
    stats_total_xp            = "Total XP:",
    stats_tavern_gold         = "Tavern Gold:",
    stats_streak              = "Login Streak:",
    stats_days                = "Days",
    stats_best                = "Best:",
    stats_gotd                = "Game of the Day:",
    stats_header_games        = "Game Statistics",
    stats_total_games         = "Games Played:",
    stats_wins                = "Won:",
    stats_losses              = "Lost:",
    stats_draws               = "Draws:",
    stats_fav_game            = "Favorite Game:",
    stats_top_score           = "Top Score:",
    stats_header_achievements = "Achievements",
    stats_ach_count           = "Unlocked:",
    stats_header_challenges   = "Challenges",
    stats_challenges_done     = "Completed:",
    stats_challenges_gold     = "Gold Earned:",
    stats_title_select        = "Active Title:",
    stats_title_visible       = "Show title in header",
    stats_no_titles           = "No titles unlocked yet.",
    summary_title             = "Summary",
    summary_recent            = "Recent Achievements",
    summary_progress          = "Progress Overview",
    summary_overall           = "Overall",
    summary_no_recent         = "No achievements unlocked yet.",
    summary_no_data           = "No achievement data available.",

    -- Toast
    toast_achievement_earned  = "Achievement Earned!",
    toast_challenge_complete  = "Challenge Complete!",
    toast_gold_earned         = "Tavern Gold Received!",

    -- Hub Settings
    hubsettings_btn             = "Hub Settings",
    hubsettings_title           = "ArcadiaNexus Settings",
    hubsettings_toast_section   = "Achievement Toast",
    hubsettings_toast_desc      = "Click the button to show the toast anchor. Drag it to your desired position and click again to confirm.",
    hubsettings_toast_anchor_show    = "Show & Move Anchor",
    hubsettings_toast_anchor_confirm = "Confirm Position",
    hubsettings_anchor_label    = "Toast Anchor  (Drag to reposition)",
    hubsettings_position        = "Position:",
    hubsettings_reset           = "Reset",
    hubsettings_toast_preview   = "Preview",

    -- Hub Settings GOTD
    hubsettings_gotd_section      = "Game of the Day",
    hubsettings_gotd_desc         = "The Game of the Day changes daily. Earn +25% XP when playing it.",
    hubsettings_gotd_show         = "Show overlay",
    hubsettings_gotd_anchor_show  = "Move GOTD Anchor",
    hubsettings_gotd_anchor_label = "GOTD Anchor  (Drag to reposition)",
    hubsettings_dev_section       = "Developer",
    hubsettings_dev_devmode       = "Enable Developer Mode",
    hubsettings_dev_devmode_desc  = "Enables detailed debug logs in chat. For development purposes only.",
    hubsettings_dev_locked        = "Developer Mode is bound to your characters. This character is not on the allowlist.",
    hubsettings_dev_allowlist_hint = "DevMode is not locked yet. Type /andevwho in chat and add the key to ALLOW_CHARS in Core/DevAccess.lua.",

    -- Hub Settings Sub-Tabs
    -- Hub Settings UI Scaling
    hubsettings_scale_section = "UI Scaling",
    hubsettings_scale_desc    = "Adjust window size. 1.0 = default size.",

    hubsettings_tab_general    = "General",
    hubsettings_tab_games      = "Games",
    hubsettings_tab_stats      = "Statistics",
    hubsettings_tab_developer  = "Developer",

    -- Hub Settings Lock
    hubsettings_lock_section   = "Window",
    hubsettings_lock_ui        = "Lock window position",
    hubsettings_lock_desc      = "Prevents the window from being accidentally moved.",

    -- Hub Settings Stats Reset
    hubsettings_stats_section        = "Reset Statistics",
    hubsettings_stats_reset_desc     = "Resets leaderboard, profile, streak and challenges. Achievements are never reset.",
    hubsettings_stats_reset_btn      = "Reset Statistics",
    hubsettings_stats_confirm1_title = "Reset Statistics?",
    hubsettings_stats_confirm1_body  = "Leaderboard, profile, streak and challenges will be permanently deleted. Continue?",
    hubsettings_stats_confirm2_title = "Are you sure?",
    hubsettings_stats_confirm2_body  = "Final warning: All statistics will be reset to default values.",

    -- Export/Import Popup
    hubsettings_export_popup_title  = "Export Statistics",
    hubsettings_export_popup_hint   = "Copy the string and keep it safe.",
    hubsettings_export_copy         = "Select All",
    hubsettings_export_close        = "Close",
    hubsettings_import_popup_title  = "Import Statistics",
    hubsettings_import_popup_hint   = "Paste your export string and click Import.",
    hubsettings_import_confirm_btn  = "Import",
    hubsettings_import_cancel       = "Cancel",

    -- Games Tab Buttons
    hubsettings_games_confirm_btn   = "Confirm & Reload",
    hubsettings_games_confirm_title = "Apply Changes?",
    hubsettings_games_confirm_body  = "The addon will reload. Hidden games will only be hidden after the reload.",
    hubsettings_games_reset_btn     = "Reset List",
    hubsettings_games_reload_hint   = "|cffffaa00Changes will take effect after /reload.|r",

    -- Hub Settings Dual Listbox
    hubsettings_games_section = "Manage Games",
    hubsettings_games_desc    = "Double-click a game to hide or show it. Hidden games will not appear in the sidebar.",
    hubsettings_games_visible = "Visible",
    hubsettings_games_hidden  = "Hidden",

    -- Hub Settings Export/Import
    hubsettings_export_section       = "Export / Import",
    hubsettings_export_desc          = "Export or import leaderboard, profile, streak and challenge history. Achievements are not included.",
    hubsettings_export_btn           = "Export",
    hubsettings_import_btn           = "Import",
    hubsettings_export_clear         = "Clear",
    hubsettings_import_confirm_title = "Import Statistics?",
    hubsettings_import_confirm_body  = "Current statistics will be overwritten with the imported data. Continue?",

    -- DevMode Confirm
    devmode_confirm_enable_title  = "Enable Developer Mode?",
    devmode_confirm_enable_body   = "Developer mode is intended for developers only. The addon will reload.",
    devmode_confirm_disable_title = "Disable Developer Mode?",
    devmode_confirm_disable_body  = "Disable developer mode? The addon will reload.",
    -- GameResultDialog
    result_score      = "Score",
    result_xp         = "XP",
    result_gold       = "Gold",
    result_highscore  = "Highscore",
    result_new_hs     = "|cffffd700New Highscore!|r",

    -- GameResultDialog – Buttons (shared across all minigames)
    btn_play_again    = "Play Again",
    btn_restart       = "Play Again",
    btn_new_game      = "New Game",
    btn_retry         = "Retry",
    btn_exit          = "Exit",
    btn_menu          = "Menu",
    btn_next_level    = "Next Level",
    btn_replay_level  = "Replay",
    btn_level_select  = "Level Select",
    popup_resume      = "Continue",
    btn_next_round    = "Next Round",
    btn_continue      = "Continue",
    btn_give_up       = "Give Up",
    btn_stop          = "End Game",
    btn_reset_chips   = "Restart",
    btn_bankrupt      = "Bankrupt / Reset",

    -- Save-slot menu (SaveSlotMenu.lua)
    slot_menu_title          = "Choose Save Slot",
    slot_label               = "Slot %d",
    slot_empty               = "— Empty —",
    slot_paused              = "in progress",
    hint_select_slot         = "Choose a save slot",
    confirm_overwrite        = "Overwrite save?",
    confirm_overwrite_body   = "Slot %d already has a save.",
    confirm_delete           = "Delete this save?",
    confirm_delete_body      = "Slot %d will be cleared.",
    btn_yes                  = "Yes",
    btn_no                   = "Cancel",
})
