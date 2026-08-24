--[[
    Ludo of Azeroth – Language.lua
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("LOA")
]]

ArcadiaNexus.RegisterLocale("LOA", "deDE", {
    btn_exit        = "Beenden",
    btn_new_game    = "Neues Spiel",
    btn_new_game_ov = "Neues Spiel",

    hint_start      = "|cffaaaaaa Einstellungen wählen und Neues Spiel starten.\n\nKlicke auf den Würfel um zu würfeln,\ndann auf deine Figur um sie zu ziehen.\n\n|cffff8800Positions-Kalibrierung: /loa debug path|r",

    status_human    = "|cff%02x%02x%02xDu (%s)|r  %d/4",
    status_ai       = "|cff%02x%02x%02xKI (%s)|r  %d/4  %s",
    status_roll     = "|cff00ff00Dein Zug – Würfeln!|r",
    status_pick     = "|cffffff00Figur wählen|r",
    status_ai_think = "|cffaaaaaa KI denkt...|r",
    status_no_move  = "|cffff8800Kein Zug möglich!|r",
    status_reroll   = "|cffff8800Keine 6 – nochmal würfeln (%d/%d)|r",

    result_win_title  = "|cffffd700Sieg! Für den Ruhm Azeroths!|r",
    result_win_sub    = "|cff00ff00Du hast alle Figuren ins Ziel gebracht!|r",
    result_loss_title = "|cffff4444Niederlage!|r",
    result_loss_sub   = "|cffaaaaaa Die KI hat alle Figuren ins Ziel gebracht.|r",

    box_options     = "Spiel-Optionen",
    box_sounds      = "Sound",
    box_guide       = "Anleitung",

    label_theme     = "Thema:",
    label_color     = "Deine Fraktion:",
    faction_stormwind    = "Stormwind",
    faction_orgrimmar    = "Orgrimmar",
    faction_thunder_bluff = "Thunder Bluff",
    faction_ironforge    = "Ironforge",
    color_blue      = "Stormwind",
    color_red       = "Orgrimmar",
    color_green     = "Thunder Bluff",
    color_yellow    = "Ironforge",
    label_preview   = "|cffaaaaaa Vorschau (Du / KI):|r",
    preview_you     = "|cffaaaaaaSpieler|r",
    preview_ai      = "|cffaaaaaaKI|r",
    preview_you_fmt = "|cff%02x%02x%02xDu (%s)|r",
    preview_ai_fmt  = "|cff%02x%02x%02xKI (%s)|r",

    btn_start       = "Spiel starten",
    btn_resume      = "Fortsetzen",
    popup_start_title = "Spiel starten",

    label_players   = "Modus:",
    players_1       = "Du + 1 KI",
    players_2       = "Du + 2 KI",
    players_3       = "Du + 3 KI",

    status_current  = "|cff%02x%02x%02x%s|r  %d/4  %s",
    dice_result     = "|cffffd700Würfel: %d|r",

    sound_enabled   = "Sounds aktiviert",
    sound_roll      = "Würfeln",
    sound_move      = "Figur ziehen",
    sound_capture   = "Schlagen",
    sound_home      = "Einlaufen",
    sound_win       = "Sieg",

    guide_goal      = "|cffffff00Ziel:|r Bringe alle 4 Figuren ins Ziel.",
    guide_dice      = "|cffffff00Würfeln:|r Klicke auf den Würfel-Button.",
    guide_six       = "|cffffff00Würfeln:|r Keine Figur auf dem Feld: bis zu 3 Würfe, bis eine 6 fällt. Sonst nur 1 Wurf. Eine 6: nochmals würfeln.",
    guide_move      = "|cffffff00Figur ziehen:|r Gültige Figuren leuchten gelb.",
    guide_capture   = "|cffffff00Schlagen:|r Landest du auf einer gegnerischen Figur, muss sie zurück ins Haus (auch das Startfeld). Eigene Figuren werden nie geschlagen und dürfen sich stapeln.",
    guide_safe      = "|cffffff00Stapeln:|r Mehrere Figuren derselben Farbe dürfen auf einem Feld stehen. Sie werden leicht nach links/rechts versetzt, damit du sie einzeln anklicken kannst.",
    guide_home      = "|cffffff00Zielfelder:|r Die vier Felder werden nacheinander belegt. Figuren bleiben sichtbar. Exakte Augenzahl, kein Besetzen eines belegten Zielfelds.",
    guide_ai        = "|cffffff00KI:|r Schlägt bevorzugt, sonst vorderste Figur.",
    guide_hint      = "|cffaaaaaa Positions-Kalibrierung: /loa debug path|r",

    btn_reset       = "Reset",
})

ArcadiaNexus.RegisterLocale("LOA", "enUS", {
    btn_exit        = "Exit",
    btn_new_game    = "New Game",
    btn_new_game_ov = "New Game",

    hint_start      = "|cffaaaaaa Choose settings and start a New Game.\n\nClick the dice to roll,\nthen click your piece to move.\n\n|cffff8800Position calibration: /loa debug path|r",

    status_human    = "|cff%02x%02x%02xYou (%s)|r  %d/4",
    status_ai       = "|cff%02x%02x%02xAI (%s)|r  %d/4  %s",
    status_roll     = "|cff00ff00Your turn – Roll!|r",
    status_pick     = "|cffffff00Choose a piece|r",
    status_ai_think = "|cffaaaaaa AI thinking...|r",
    status_no_move  = "|cffff8800No move possible!|r",
    status_reroll   = "|cffff8800No 6 – roll again (%d/%d)|r",

    result_win_title  = "|cffffd700Victory! For the glory of Azeroth!|r",
    result_win_sub    = "|cff00ff00You moved all pieces to the goal!|r",
    result_loss_title = "|cffff4444Defeat!|r",
    result_loss_sub   = "|cffaaaaaa The AI moved all pieces to the goal.|r",

    box_options     = "Game Options",
    box_sounds      = "Sound",
    box_guide       = "Guide",

    label_theme     = "Theme:",
    label_color     = "Your faction:",
    faction_stormwind     = "Stormwind",
    faction_orgrimmar     = "Orgrimmar",
    faction_thunder_bluff = "Thunder Bluff",
    faction_ironforge     = "Ironforge",
    color_blue      = "Stormwind",
    color_red       = "Orgrimmar",
    color_green     = "Thunder Bluff",
    color_yellow    = "Ironforge",
    label_preview   = "|cffaaaaaa Preview (You / AI):|r",
    preview_you     = "|cffaaaaaaPlayer|r",
    preview_ai      = "|cffaaaaaaAI|r",
    preview_you_fmt = "|cff%02x%02x%02xYou (%s)|r",
    preview_ai_fmt  = "|cff%02x%02x%02xAI (%s)|r",

    btn_start       = "Start Game",
    btn_resume      = "Continue",
    popup_start_title = "Start Game",

    label_players   = "Mode:",
    players_1       = "You + 1 AI",
    players_2       = "You + 2 AI",
    players_3       = "You + 3 AI",

    status_current  = "|cff%02x%02x%02x%s|r  %d/4  %s",
    dice_result     = "|cffffd700Dice: %d|r",

    sound_enabled   = "Sounds enabled",
    sound_roll      = "Roll dice",
    sound_move      = "Move piece",
    sound_capture   = "Capture",
    sound_home      = "Reach home",
    sound_win       = "Victory",

    guide_goal      = "|cffffff00Goal:|r Move all 4 pieces to the goal.",
    guide_dice      = "|cffffff00Dice:|r Click the dice button.",
    guide_six       = "|cffffff00Rolling:|r No piece on the board: up to 3 rolls until a 6. Otherwise only 1 roll. A 6: roll again.",
    guide_move      = "|cffffff00Move:|r Valid pieces glow yellow.",
    guide_capture   = "|cffffff00Capture:|r Landing on an opponent sends them back to base (including the start square). Your own pieces are never captured and may stack.",
    guide_safe      = "|cffffff00Stacking:|r Several pieces of the same color may share a square. They are offset left/right so you can click them separately.",
    guide_home      = "|cffffff00Home:|r Fill the four home squares one by one. Pieces stay visible. Exact count; no landing on an occupied home square.",
    guide_ai        = "|cffffff00AI:|r Prefers captures, else leading piece.",
    guide_hint      = "|cffaaaaaa Position calibration: /loa debug path|r",

    btn_reset       = "Reset",
})
