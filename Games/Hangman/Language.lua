--[[
    Gaming Hub
    Games/Hangman/Language.lua
    Version: 1.0.0

    Alle lokalisierbaren Strings fuer Hangman (WoW-Lore Edition).
    Zugriff: local L = ArcadiaNexus.GetLocaleTable("HANGMAN")
]]

-- ============================================================
-- DEUTSCH (deDE)
-- ============================================================
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
    guide_hint      = "|cffaaaaaa Kategorie und Schwierigkeit im Spielfeld wählbar. Leicht=8 | Normal=6 | Schwer=4 Versuche.|r",
})

-- ============================================================
-- ENGLISCH (enUS) – Fallback
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

-- ============================================================
-- WORTLISTEN-LOKALISIERUNG
-- Hinweise fuer jedes Wort + Kategorie-Namen
-- Keys: hint_WORT (uppercase, Sonderzeichen entfernt)
-- ============================================================

-- DEUTSCH – Hinweise
ArcadiaNexus.RegisterLocale("HANGMAN_HINTS", "deDE", {
    -- Kategorie-Namen
    cat_all         = "Alle",
    cat_chars       = "Charaktere",
    cat_places      = "Orte",
    cat_weapons     = "Waffen",
    cat_instances   = "Instanzen",
    cat_classes     = "Klassen",

    -- Charaktere
    hint_ARTHAS       = "Der Lichkönig, einstiger Prinz von Lordaeron.",
    hint_SYLVANAS     = "Bansheekönigin der Untoten, einstige Rangerin.",
    hint_THRALL       = "Grüner Kriegshäuptling, Sohn von Durotan.",
    hint_ILLIDAN      = "Der Verratene, Jäger von Dämonen.",
    hint_JAINA        = "Erzmagierin von Dalaran, Tochter des Meeres.",
    hint_ANDUIN       = "König von Stormwind, Sohn Varians.",
    hint_BOLVAR       = "Der neue Lichkönig nach dem Fall von Icecrown.",
    hint_TYRANDE      = "Hohepriesterin von Elune, Gefährtin Malfurions.",
    hint_MALFURION    = "Der erste Druide, Beschützer der Natur.",
    hint_MAGNI        = "Früher König von Ironforge, jetzt Herold Azeroths.",
    hint_KHADGAR      = "Erzmagier und Hüter des Portals in Shattrath.",
    hint_VARIAN       = "König von Stormwind, Lo'Gosh der Kriegsrufer.",
    hint_GARROSH      = "Sohn Grom Hellscreams, früher Warchief der Horde.",
    hint_GULDAN       = "Orcischer Hexenmeister, Verräter seines Volkes.",
    hint_MEDIVH       = "Der letzte Hüter, öffnete das Dunkle Portal.",
    hint_DEATHWING    = "Der Weltenbrecher, einst Neltharion.",
    hint_ALEXSTRASZA  = "Drachenkaiserin, Beschützerin des Lebens.",
    hint_YSERA        = "Aspekt des grünen Drachenschwarms, Hüterin des Traums.",
    hint_NOZDORMU     = "Aspekt der Zeit, Hüter der Ewigkeit.",
    hint_KALECGOS     = "Aspekt der Magie, blauer Drachenschwarm.",
    hint_XAVIUS       = "Der Albtraumtyrann, einst ein Berater Azsharis.",
    hint_AZSHARA      = "Einst Königin der Nachtgeborenen, jetzt Naga-Kaiserin.",
    hint_SARGERAS     = "Gefallener Titan, Herrscher der Brennenden Legion.",
    hint_ARCHIMONDE   = "Einer der Erhabensten der Brennenden Legion.",
    hint_KILJAEDEN    = "Der Trügerische, zweiter Erhabener der Legion.",
    hint_CENARIUS     = "Halbgott des Waldes, Sohn Malorne und Elunes.",
    hint_RAGNAROS     = "Feuerfürst, Herrscher von Molten Core.",
    hint_NEFARIAN     = "Sohn Deathwings, Herrscher von Blackwing Lair.",
    hint_CTHUN        = "Alter Gott, schlummert unter Ahn'Qiraj.",
    hint_YOGGSARON    = "Alter Gott des Wahnsinns, gefangen in Ulduar.",

    -- Orte
    hint_STORMWIND    = "Die größte menschliche Stadt auf Azeroth.",
    hint_ORGRIMMAR    = "Hauptstadt der Horde, benannt nach Orgrim Doomhammer.",
    hint_DALARAN      = "Fliegende Magierstadt, Heimat der Kirin Tor.",
    hint_IRONFORGE    = "Zwergenfestung tief im Berg Khaz Modan.",
    hint_DARNASSUS    = "Einst Hauptstadt der Nachtelfen auf dem Weltenbaum.",
    hint_UNDERCITY    = "Gruftstadt unter Lordaerons Ruinen, Heimat der Untoten.",
    hint_THUNDERBLUFF = "Tauren-Hauptstadt auf mächtigen Klippen in Mulgore.",
    hint_SILVERMOON   = "Hauptstadt der Blutelfen in Quel'Thalas.",
    hint_EXODAR       = "Raumschiff der Draenei, abgestürzt auf den Azuremyst Isles.",
    hint_ICECROWN     = "Eisige Zitadelle des Lichkönigs in Northrend.",
    hint_BLACKROCK    = "Vulkanischer Berg, Heimat von Drachen und Orks.",
    hint_KARAZHAN     = "Turm des Magiers Medivh in Deadwind Pass.",
    hint_ULDUAR       = "Titanenbastion in den Storm Peaks, Gefängnis von Yogg-Saron.",
    hint_NAXXRAMAS    = "Fliegende Nekropole, Heimstatt des Lich Kel'Thuzad.",
    hint_STRATHOLME   = "Stadt, die Arthas im Dritten Krieg niederbrannte.",
    hint_LORDAERON    = "Menschenkönigreich, das dem Seuchenplag zum Opfer fiel.",
    hint_OUTLAND      = "Überbleibsel der explodierten Welt Draenor.",
    hint_NORTHREND    = "Frostiger Kontinent im Norden, Heimat des Lichkönigs.",
    hint_PANDARIA     = "Verborgener Kontinent, Heimat der Pandaren.",
    hint_ZANDALAR     = "Trollinsel, Stammland der Zandalari.",

    -- Waffen
    hint_FROSTMOURNE  = "Das Schwert des Lichkönigs, das Seelen verschlingt.",
    hint_ASHBRINGER   = "Das heilige Schwert des Lichts, Waffe der Paladine.",
    hint_THUNDERFURY  = "Gesegnetes Schwert des Windsuchers.",
    hint_SHADOWMOURNE = "Chaotische Axt, geschmiedet aus Seelensplittern.",
    hint_SULFURAS     = "Hand von Ragnaros, der feurige Hammer.",
    hint_VALANYR      = "Hammer der alten Könige, aus Titanenerz.",
    hint_DOOMHAMMER   = "Der Schicksalshammer, Thralls Kriegswaffe.",
    hint_TAESHALACH   = "Titanenklinge von Aggramar.",
    hint_ATIESH       = "Stab von Medivh, dem letzten Hüter.",
    hint_XALATATH     = "Messer des Schwarzen Imperiums.",
    hint_THORIIDAL    = "Bogen der Sternschnuppen, des Schießmeisters.",
    hint_SHALAMAYNE   = "Schwert von Varian Wrynn, Sohn Loanes.",

    -- Instanzen
    hint_MOLTENCORE     = "Vulkanischer Raid unter Blackrock Mountain, Ragnaros wartet.",
    hint_KARAZHAN_INST  = "Turm des Medivh, erster Raid in Burning Crusade.",
    hint_NAXXRAMAS_INST = "Schwimmende Nekropole, Bastion des Lich Kel'Thuzad.",
    hint_ULDUAR_INST    = "Titanenfestung, Gefängnis von Yogg-Saron.",
    hint_ICECROWN_INST  = "Zitadelle des Lichkönigs, letzter Raid in WotLK.",
    hint_SUNWELLPLATEAU = "Hochplateauraid, Heimat von Kael'thas und Kil'Jaeden.",
    hint_BLACKTEMPLE    = "Illidans Festung, letzter Raid in TBC.",
    hint_AHNQIRAJ       = "Altertümlicher Raid, Gefängnis von C'Thun.",

    -- Klassen & Voelker
    hint_PALADIN      = "Heiliger Krieger des Lichts, Beschützer der Unschuldigen.",
    hint_DRUID        = "Formwandler der Natur, Diener Cenarius.",
    hint_SHAMAN       = "Rufer der Elemente, Brückenbauer zwischen Welten.",
    hint_WARLOCK      = "Dämonenbeschwörer, meistert verbotene Magie.",
    hint_DEATHKNIGHT  = "Einstiger Held, vom Lichkönig korrumpiert.",
    hint_ROGUE        = "Meister des Schattens, Dieb und Attentäter.",
    hint_HUNTER       = "Bezähmer wilder Tiere, Jäger in der Wildnis.",
    hint_MAGE         = "Meister der arkanen Magie und Elementarzauber.",
    hint_PRIEST       = "Diener des Lichts oder der Schatten.",
    hint_WARRIOR      = "Meister der Waffen, Frontkämpfer ohne Magie.",
    hint_WORGEN       = "Verfluchte Menschenwesen aus Gilneas, halb Wolf.",
    hint_GOBLIN       = "Erfinderisches Volk, immer auf der Suche nach Profit.",
    hint_PANDAREN     = "Friedlicher Bürger, Meister der Braukunst und des Kampfes.",
    hint_DRAENEI      = "Eredar, die dem Einfluss Sargeras widerstanden.",
})

-- ENGLISCH – Hinweise
ArcadiaNexus.RegisterLocale("HANGMAN_HINTS", "enUS", {
    -- Kategorie-Namen
    cat_all         = "All",
    cat_chars       = "Characters",
    cat_places      = "Places",
    cat_weapons     = "Weapons",
    cat_instances   = "Instances",
    cat_classes     = "Classes",

    -- Characters
    hint_ARTHAS       = "The Lich King, once Prince of Lordaeron.",
    hint_SYLVANAS     = "Banshee Queen of the Forsaken, former ranger.",
    hint_THRALL       = "Great Warchief, son of Durotan.",
    hint_ILLIDAN      = "The Betrayer, hunter of demons.",
    hint_JAINA        = "Archmage of Dalaran, daughter of the sea.",
    hint_ANDUIN       = "King of Stormwind, son of Varian.",
    hint_BOLVAR       = "The new Lich King after the fall of Icecrown.",
    hint_TYRANDE      = "High Priestess of Elune, companion of Malfurion.",
    hint_MALFURION    = "The first druid, protector of nature.",
    hint_MAGNI        = "Former King of Ironforge, now Herald of Azeroth.",
    hint_KHADGAR      = "Archmage and keeper of the portal in Shattrath.",
    hint_VARIAN       = "King of Stormwind, Lo'Gosh the Wolf Ancient.",
    hint_GARROSH      = "Son of Grom Hellscream, former Warchief of the Horde.",
    hint_GULDAN       = "Orcish warlock, traitor to his people.",
    hint_MEDIVH       = "The Last Guardian, who opened the Dark Portal.",
    hint_DEATHWING    = "The Worldbreaker, once known as Neltharion.",
    hint_ALEXSTRASZA  = "Dragon Queen, life-binder and protector.",
    hint_YSERA        = "Aspect of the Green Dragonflight, guardian of the Dream.",
    hint_NOZDORMU     = "Aspect of Time, keeper of eternity.",
    hint_KALECGOS     = "Aspect of Magic, blue dragonflight.",
    hint_XAVIUS       = "The Nightmare Lord, once an advisor to Azshara.",
    hint_AZSHARA      = "Once Queen of the Kaldorei, now Naga Empress.",
    hint_SARGERAS     = "Fallen Titan, master of the Burning Legion.",
    hint_ARCHIMONDE   = "One of the Eredar Lords of the Burning Legion.",
    hint_KILJAEDEN    = "The Deceiver, second Eredar Lord of the Legion.",
    hint_CENARIUS     = "Demigod of the forest, son of Malorne and Elune.",
    hint_RAGNAROS     = "Firelord, master of Molten Core.",
    hint_NEFARIAN     = "Son of Deathwing, master of Blackwing Lair.",
    hint_CTHUN        = "Old God, slumbering beneath Ahn'Qiraj.",
    hint_YOGGSARON    = "Old God of madness, imprisoned in Ulduar.",

    -- Places
    hint_STORMWIND    = "The greatest human city on Azeroth.",
    hint_ORGRIMMAR    = "Horde capital, named after Orgrim Doomhammer.",
    hint_DALARAN      = "Flying city of mages, home of the Kirin Tor.",
    hint_IRONFORGE    = "Dwarven fortress deep in Khaz Modan.",
    hint_DARNASSUS    = "Once capital of the night elves atop the World Tree.",
    hint_UNDERCITY    = "Crypt-city beneath the ruins of Lordaeron, home of the Forsaken.",
    hint_THUNDERBLUFF = "Tauren capital on mighty bluffs in Mulgore.",
    hint_SILVERMOON   = "Blood elf capital in Quel'Thalas.",
    hint_EXODAR       = "Draenei spaceship that crashed on the Azuremyst Isles.",
    hint_ICECROWN     = "Icy citadel of the Lich King in Northrend.",
    hint_BLACKROCK    = "Volcanic mountain, home of dragons and orcs.",
    hint_KARAZHAN     = "Tower of the mage Medivh in Deadwind Pass.",
    hint_ULDUAR       = "Titan stronghold in the Storm Peaks, prison of Yogg-Saron.",
    hint_NAXXRAMAS    = "Floating necropolis, home of the lich Kel'Thuzad.",
    hint_STRATHOLME   = "City burned by Arthas during the Third War.",
    hint_LORDAERON    = "Human kingdom that fell to the Scourge plague.",
    hint_OUTLAND      = "Remnants of the shattered world of Draenor.",
    hint_NORTHREND    = "Frozen continent in the north, home of the Lich King.",
    hint_PANDARIA     = "Hidden continent, home of the Pandaren.",
    hint_ZANDALAR     = "Troll island, homeland of the Zandalari.",

    -- Weapons
    hint_FROSTMOURNE  = "The Lich King's sword that devours souls.",
    hint_ASHBRINGER   = "Holy sword of the Light, weapon of the Silver Hand.",
    hint_THUNDERFURY  = "Blessed Blade of the Windseeker.",
    hint_SHADOWMOURNE = "Chaotic axe forged from soul fragments.",
    hint_SULFURAS     = "Hand of Ragnaros, the fiery hammer.",
    hint_VALANYR      = "Hammer of Ancient Kings, forged from titan ore.",
    hint_DOOMHAMMER   = "The destiny hammer, Thrall's weapon of war.",
    hint_TAESHALACH   = "Titan blade of Aggramar.",
    hint_ATIESH       = "Staff of Medivh, the Last Guardian.",
    hint_XALATATH     = "Knife of the Black Empire.",
    hint_THORIIDAL    = "Bow of the Shattered Sun, marksman's pride.",
    hint_SHALAMAYNE   = "Sword of Varian Wrynn, son of Llane.",

    -- Instances
    hint_MOLTENCORE     = "Volcanic raid beneath Blackrock Mountain, Ragnaros awaits.",
    hint_KARAZHAN_INST  = "Tower of Medivh, first raid in Burning Crusade.",
    hint_NAXXRAMAS_INST = "Floating necropolis, bastion of the lich Kel'Thuzad.",
    hint_ULDUAR_INST    = "Titan fortress, prison of Yogg-Saron.",
    hint_ICECROWN_INST  = "Citadel of the Lich King, final raid in WotLK.",
    hint_SUNWELLPLATEAU = "Plateau raid, home of Kael'thas and Kil'Jaeden.",
    hint_BLACKTEMPLE    = "Illidan's fortress, final raid in TBC.",
    hint_AHNQIRAJ       = "Ancient raid, prison of C'Thun.",

    -- Classes & Races
    hint_PALADIN      = "Holy warrior of the Light, protector of the innocent.",
    hint_DRUID        = "Shapeshifter of nature, servant of Cenarius.",
    hint_SHAMAN       = "Caller of elements, bridge between worlds.",
    hint_WARLOCK      = "Demon summoner, master of forbidden magic.",
    hint_DEATHKNIGHT  = "Former hero, corrupted by the Lich King.",
    hint_ROGUE        = "Master of shadows, thief and assassin.",
    hint_HUNTER       = "Tamer of wild beasts, tracker in the wilds.",
    hint_MAGE         = "Master of arcane magic and elemental spells.",
    hint_PRIEST       = "Servant of the Light or the Shadow.",
    hint_WARRIOR      = "Master of weapons, frontline fighter without magic.",
    hint_WORGEN       = "Cursed humans from Gilneas, half wolf.",
    hint_GOBLIN       = "Inventive people always seeking profit.",
    hint_PANDAREN     = "Peaceful citizens, masters of brewing and combat.",
    hint_DRAENEI      = "Eredar who resisted the influence of Sargeras.",
})
