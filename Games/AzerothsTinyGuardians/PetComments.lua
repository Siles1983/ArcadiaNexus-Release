-- ============================================================
--  Azeroth's Tiny Guardians – PetComments.lua
--  Kommentar-Sets pro Pet-Art (in ATG_PetData, deDE/enUS)
-- ============================================================

local P = ArcadiaNexus.ATG_PetData
if not P then return end

local function B(de, en)
    return { deDE = de, enUS = en or de }
end

P.comments = {
    MURLOC = {
        hungry  = B({ "Mrgl mrgl!!", "MRRGLLL!", "...mrgl?" }),
        happy   = B({ "Mrgl mrgl mrgl~", "MRGHLGLGL!" }),
        tired   = B({ "mrgl...", "*gähn* mrgl" }, { "mrgl...", "*yawn* mrgl" }),
        dirty   = B({ "Mrgl! (riecht seltsam)" }, { "Mrgl! (smells weird)" }),
        angry   = B({ "MRGL!! >:(" }, { "MRGL!! >:(" }),
        sick    = B({ "mrgl... *hust*" }, { "mrgl... *cough*" }),
        evolved = B({ "MRGLGLGLGL!!!" }),
        feed    = B({ "MRGL FOOD!", "mrgl nom nom" }),
        pet     = B({ "mrgl~ <3", "MRGHL~" }),
        sleep   = B({ "mrgl... zzz", "mrgl... zzz" }),
        wash    = B({ "Mrgl glub glub", "Splish mrgl!" }),
        train   = B({ "MRGL TRAIN!", "mrgl flex!" }),
        heal    = B({ "mrgl... besser?", "mrgl... better?" }),
    },
    DRAGON = {
        hungry  = B({ "Mein Magen knurrt...", "Ich brauche Snacks!" }, { "My tummy rumbles...", "I need snacks!" }),
        happy   = B({ "Flinker Flügelschlag!", "Das gefällt mir!" }, { "Happy wing flap!", "I like this!" }),
        tired   = B({ "*gähn* Noch fünf Minuten...", "So müde..." }, { "*yawn* Five more minutes...", "So tired..." }),
        dirty   = B({ "Meine Schuppen kleben...", "Zeit für ein Bad!" }, { "My scales feel sticky...", "Bath time!" }),
        angry   = B({ "Grrr! Nicht anfassen!", "Ich bin sauer!" }, { "Grrr! Don't touch!", "I'm mad!" }),
        sick    = B({ "*hust* Meine Flamme ist schwach...", "Mir ist schlecht..." }, { "*cough* My flame is weak...", "I feel awful..." }),
        evolved = B({ "Ich spüre die Macht!", "Auf zur nächsten Stufe!" }, { "I feel the power!", "On to the next stage!" }),
        feed    = B({ "Lecker! Mehr bitte!", "Nom nom!" }, { "Yummy! More please!", "Nom nom!" }),
        pet     = B({ "Sanft streicheln, ja?", "Das kitzelt!" }, { "Gentle scritches, yes?", "That tickles!" }),
        sleep   = B({ "Zzz... von Drachenträumen...", "Gute Nacht..." }, { "Zzz... dragon dreams...", "Good night..." }),
        wash    = B({ "Platsch! Frisch und glänzend!", "Ah, sauber!" }, { "Splash! Fresh and shiny!", "Ah, clean!" }),
        train   = B({ "Stärker! Schneller!", "Ich werde besser!" }, { "Stronger! Faster!", "I'm improving!" }),
        heal    = B({ "Ah... das tut gut.", "Danke, Wärter!" }, { "Ah... that feels good.", "Thanks, keeper!" }),
    },
    UNDEAD = {
        hungry  = B({ "Gehirne... nein, Snacks...", "Ich hab Hunger. Wie unangenehm." }, { "Brains... no, snacks...", "I'm hungry. How unpleasant." }),
        happy   = B({ "Heh. Nicht schlecht.", "Ein schwaches Grinsen." }, { "Heh. Not bad.", "A faint grin." }),
        tired   = B({ "Schon wieder müde... typisch.", "*seufz* Untot sein ist anstrengend." }, { "Tired again... typical.", "*sigh* Being undead is exhausting." }),
        dirty   = B({ "Ich... rieche?", "Staub und Moder. Charmant." }, { "Do I... smell?", "Dust and decay. Charming." }),
        angry   = B({ "Lasst mich in Ruhe!", "Grr... *knirscht*" }, { "Leave me alone!", "Grr... *clatters*" }),
        sick    = B({ "Meine Glieder wackeln...", "Ich brauche... was auch immer Untote brauchen." }, { "My limbs are loose...", "I need... whatever undead need." }),
        evolved = B({ "Mehr... Leben? Nein, mehr Power.", "Interessante Entwicklung." }, { "More... life? No, more power.", "Interesting development." }),
        feed    = B({ "Essen. Wie... lebendig.", "Schmeckt überraschend okay." }, { "Food. How... living.", "Tastes surprisingly okay." }),
        pet     = B({ "...okay, das war nett.", "Hm. Nicht schlimm." }, { "...okay, that was nice.", "Hm. Not bad." }),
        sleep   = B({ "Ruhe im Frieden... kurz.", "Zzz... *kein Schnarchen*" }, { "Rest in peace... briefly.", "Zzz... *no snoring*" }),
        wash    = B({ "Wasser? Wie grausam.", "Na gut, sauberer Untoter." }, { "Water? How cruel.", "Fine, cleaner undead." }),
        train   = B({ "Knochenarbeit.", "Stärker als gestern. Wie deprimierend." }, { "Bone work.", "Stronger than yesterday. How depressing." }),
        heal    = B({ "Ah. Weniger wackelig.", "Danke... schätze ich." }, { "Ah. Less wobbly.", "Thanks... I guess." }),
    },
    MECHAGNOME = {
        hungry  = B({ "Treibstoffstand: niedrig.", "Energiezufuhr erforderlich." }, { "Fuel level: low.", "Energy input required." }),
        happy   = B({ "Systeme: zufrieden.", "Effizienz +12%!" }, { "Systems: satisfied.", "Efficiency +12%!" }),
        tired   = B({ "Akku fast leer...", "Ruhemodus empfohlen." }, { "Battery almost empty...", "Rest mode recommended." }),
        dirty   = B({ "Schmutz erkannt. Reinigung empfohlen.", "Öl und Staub auf Sensoren." }, { "Dirt detected. Cleaning recommended.", "Oil and dust on sensors." }),
        angry   = B({ "FEHLER: Stimmung kritisch!", "Systemüberlastung emotional." }, { "ERROR: Mood critical!", "Emotional system overload." }),
        sick    = B({ "Diagnose: Reparatur nötig.", "Warnung: Integrität niedrig." }, { "Diagnosis: repair needed.", "Warning: integrity low." }),
        evolved = B({ "Upgrade abgeschlossen!", "Neue Firmware installiert!" }, { "Upgrade complete!", "New firmware installed!" }),
        feed    = B({ "Energiezelle aufgeladen.", "Input akzeptiert." }, { "Power cell recharged.", "Input accepted." }),
        pet     = B({ "Taktile Eingabe: positiv.", "Sanfte Berührung registriert." }, { "Tactile input: positive.", "Gentle touch registered." }),
        sleep   = B({ "Standby-Modus aktiviert.", "Zzz... *leises Summen*" }, { "Standby mode activated.", "Zzz... *soft humming*" }),
        wash    = B({ "Reinigungsprotokoll: OK.", "Poliert und glänzend." }, { "Cleaning protocol: OK.", "Polished and shiny." }),
        train   = B({ "Trainingsroutine ausgeführt.", "Leistung optimiert." }, { "Training routine executed.", "Performance optimized." }),
        heal    = B({ "Reparatur abgeschlossen.", "Systeme stabil." }, { "Repair complete.", "Systems stable." }),
    },
    FROSTWOLF = {
        hungry  = B({ "Awwooo... hungrig...", "Futter?" }, { "Awwooo... hungry...", "Food?" }),
        happy   = B({ "Wuff! *wedelt*", "Glücklicher Wolf!" }, { "Woof! *tail wag*", "Happy pup!" }),
        tired   = B({ "*gähn* Schläfriger Welpe...", "Müde Pfote..." }, { "*yawn* Sleepy pup...", "Tired paw..." }),
        dirty   = B({ "Mein Fell klebt...", "Baden? Wirklich?" }, { "My fur is sticky...", "A bath? Really?" }),
        angry   = B({ "GRRR!", "Wütendes Knurren!" }, { "GRRR!", "Angry growl!" }),
        sick    = B({ "*heiseres Heulen*", "Mir geht's schlecht..." }, { "*hoarse howl*", "I feel sick..." }),
        evolved = B({ "Awwooooo! Stärker!", "Der Rudelstolz wächst!" }, { "Awwooooo! Stronger!", "Pack pride grows!" }),
        feed    = B({ "Nom nom! Danke!", "Leckeres Fleisch!" }, { "Nom nom! Thanks!", "Tasty meat!" }),
        pet     = B({ "Wuff~ *kuscheln*", "Mehr Streicheln!" }, { "Woof~ *cuddle*", "More pets!" }),
        sleep   = B({ "Zzz... träumt von Schnee...", "Kuscheln und schlafen..." }, { "Zzz... dreams of snow...", "Cuddle and sleep..." }),
        wash    = B({ "Platsch! Frisches Fell!", "Ah, sauber!" }, { "Splash! Fresh fur!", "Ah, clean!" }),
        train   = B({ "Training! Ich werde tapfer!", "Stärker für das Rudel!" }, { "Training! I'll be brave!", "Stronger for the pack!" }),
        heal    = B({ "Ah... danke, Freund.", "Wieder fit!" }, { "Ah... thanks, friend.", "Fit again!" }),
    },
    QUILBOAR = {
        hungry  = B({ "Grunz! Essen!", "Bauch knurrt laut!" }, { "Grunt! Food!", "Tummy rumbles loud!" }),
        happy   = B({ "Grunz grunz~", "Zufriedenes Schnauben!" }, { "Grunt grunt~", "Happy snort!" }),
        tired   = B({ "*gähn* Kurze Pause...", "Stacheln hängen..." }, { "*yawn* Quick break...", "Quills drooping..." }),
        dirty   = B({ "Ich stinke?", "Schlammbad wann?" }, { "Do I stink?", "Mud bath when?" }),
        angry   = B({ "GRUNZ!!", "Nicht gut gelaunt!" }, { "GRUNT!!", "In a bad mood!" }),
        sick    = B({ "*wimmerndes Grunzen*", "Mir ist übel..." }, { "*whimpering grunt*", "I feel awful..." }),
        evolved = B({ "GRUNZ! Größer und stärker!", "Stolzer Quilboar!" }, { "GRUNT! Bigger and stronger!", "Proud quilboar!" }),
        feed    = B({ "Mmm! Mehr!", "Leckeres Wurzelgemüse!" }, { "Mmm! More!", "Tasty root veggies!" }),
        pet     = B({ "Grunz~ *stups*", "Das ist nett!" }, { "Grunt~ *nudge*", "That's nice!" }),
        sleep   = B({ "Zzz... im Dreck...", "Kurzes Nickerchen..." }, { "Zzz... in the dirt...", "Quick nap..." }),
        wash    = B({ "Platsch! Frisch!", "Endlich sauber!" }, { "Splash! Fresh!", "Finally clean!" }),
        train   = B({ "Stärker grunzen!", "Training macht hungrig!" }, { "Grunt stronger!", "Training makes hungry!" }),
        heal    = B({ "Ah... besser.", "Danke!" }, { "Ah... better.", "Thanks!" }),
    },
}

P.traitComments = {
    MURLOC = {
        GREEDY = {
            hungry = B({ "MRGL FOOD MRGL!", "Hungryyy mrgl!" }),
            feed   = B({ "MRGL MORE FOOD!", "nom nom NOM!" }),
        },
    },
    DRAGON = {
        WARRIOR = {
            train = B({ "Für Azeroth!", "Stärke und Ehre!" }, { "For Azeroth!", "Strength and honor!" }),
            happy = B({ "Victory-Röcheln!", "Kampfbereit!" }, { "Victory roar!", "Battle ready!" }),
        },
    },
    UNDEAD = {
        LAZY = {
            tired = B({ "Noch fünf Minuten...", "Bewegung ist overrated." }, { "Five more minutes...", "Movement is overrated." }),
            sleep = B({ "Endlich Ruhe...", "Zzz... perfekt." }, { "Finally rest...", "Zzz... perfect." }),
        },
    },
    MECHAGNOME = {
        BALANCED = {
            happy = B({ "Alle Systeme nominal.", "Optimale Balance erreicht." }, { "All systems nominal.", "Optimal balance achieved." }),
            evolved = B({ "Nexus-Protokoll 7 aktiv.", "Upgrade harmonisch." }, { "Nexus Protocol 7 active.", "Harmonic upgrade." }),
        },
    },
    FROSTWOLF = {
        CLINGY = {
            pet   = B({ "Bleib bei mir!", "Nicht gehen!" }, { "Stay with me!", "Don't go!" }),
            happy = B({ "Wuff! Du bist da!", "Mein Rudel!" }, { "Woof! You're here!", "My pack!" }),
        },
    },
    QUILBOAR = {
        PICKY = {
            dirty = B({ "Zu schmutzig! Unakzeptabel!", "Grunz... ekelhaft!" }, { "Too dirty! Unacceptable!", "Grunt... gross!" }),
            wash  = B({ "Endlich! Sauber genug.", "So ist es besser." }, { "Finally! Clean enough.", "That's better." }),
        },
    },
}
