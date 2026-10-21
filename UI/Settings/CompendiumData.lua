-- Spielerhilfe. Inhalte bewusst getrennt von der Such- und Panel-Logik.
local A = _G.ArcadiaNexus
A.Compendium = A.Compendium or {}

local pages = {
    {
        id = "overview",
        de = {
            title = "Arcadia im Überblick",
            summary = "Wo du Spiele, Mehrspieler, Bestenliste, Erfolge und Profil findest.",
            tags = "start einstieg hub tabs navigation spiele",
            body = "Spiele: Wähle links eine Kategorie und ein Spiel. Die Spielanleitung und Optionen findest du unter Einstellungen in der jeweiligen Spielkategorie.\n\nMehrspieler: Hoste oder tritt einer Sitzung im Mehrspieler-Tab bei. Dieser Bereich ist von den Einzelspielen getrennt.\n\nBestenliste: Sieh deine lokalen Bestwerte und Ergebnisse pro Spiel.\n\nErfolge: Hier findest du freigeschaltete und noch offene Ziele.\n\nProfil: Dein Fortschritt, deine Spielstatistik, Challenges und Titel stehen in vier Boxen.\n\nEinstellungen: Die Arcadia-Einstellungen haben eigene Reiter für Allgemein, Spiele und das Kompendium. Spieloptionen erreichst du über die Kategorie links.",
        },
        en = {
            title = "Arcadia at a glance",
            summary = "Find games, multiplayer, scores, achievements, and your profile.",
            tags = "start introduction hub tabs navigation games",
            body = "Games: Choose a category and game on the left. Game instructions and options are in Settings under that game's category.\n\nMultiplayer: Host or join a session in the Multiplayer tab. It is separate from local games.\n\nLeaderboard: View your local records and results for each game.\n\nAchievements: Find completed and open goals.\n\nProfile: Your progress, game statistics, challenges, and titles are shown in four boxes.\n\nSettings: Arcadia settings have tabs for General, Games, and the Compendium. Game options are reached through the category on the left.",
        },
    },
    {
        id = "profile",
        de = {
            title = "Profil und die vier Boxen",
            summary = "Fortschritt, Partien, Challenges und Titel verstehen.",
            tags = "profil level xp gold streak statistik siege challenges titel",
            body = "Spieler-Profil: Zeigt Level, Gesamt-XP, Tavern Gold, Login-Serie und den Fortschritt zum nächsten Level.\n\nSpielstatistik: Fasst Partien, Siege, Niederlagen und Unentschieden zusammen. Weitere Zeilen zeigen häufig gespielte Titel und Kategorien.\n\nChallenges: Tägliche und wöchentliche Aufgaben samt Fortschritt und Belohnungen. Das Spiel des Tages kann zusätzliche XP geben.\n\nTitel: Zeigt verfügbare Titel und lässt dich einen aktiven Titel wählen. Du kannst seine Anzeige im Header steuern.",
        },
        en = {
            title = "Profile and its four boxes",
            summary = "Understand progress, matches, challenges, and titles.",
            tags = "profile level xp gold streak statistics wins challenges titles",
            body = "Player Profile: Shows level, total XP, Tavern Gold, login streak, and progress to the next level.\n\nGame Statistics: Summarizes matches, wins, losses, and draws. Other rows show your most played games and categories.\n\nChallenges: Daily and weekly tasks with progress and rewards. The Game of the Day can grant extra XP.\n\nTitles: Shows available titles and lets you choose an active one. You can control whether it appears in the header.",
        },
    },
    {
        id = "multiplayer",
        de = {
            title = "Mehrspieler und Verbindung",
            summary = "Sitzung starten, beitreten und Versionsprobleme lösen.",
            tags = "multiplayer mp match lobby host join party raid whisper pin invite version protokoll verbindung",
            body = "Öffne den Mehrspieler-Tab und wähle links einen unterstützten Titel. Der Host legt eine Sitzung an; Gäste wählen die Sitzung und klicken auf Teilnehmen. Die Lobby und das Spielfeld bleiben in diesem Tab. Alle Teilnehmer müssen bereit sein, bevor der Host startet.\n\nOffene Sitzungen werden in Party oder Raid entdeckt. Ohne gemeinsame Gruppe kann ein Beitritt per Whisper möglich sein. Je nach Host-Einstellung ist die Sitzung offen, mit PIN geschützt oder nur für freigegebene Spieler zugänglich. Bei Freigabe klickt der Gast selbst auf Teilnehmen.\n\nWenn der Beitritt wegen einer Version scheitert: Arcadia prüft das Match-Protokoll und gegebenenfalls das Spielprotokoll. Verschiedene Addon-Versionsnummern allein sind nicht die Entscheidung. Bei nicht passenden Protokollen startet die Partie nicht. Vergleicht die angezeigten Versionen und aktualisiert die betroffenen Addons.\n\nWenn keine Antwort kommt, prüfe die Gruppen- oder Whisper-Verbindung und versuche den Beitritt erneut. Ein /reload während einer Partie kann die Verbindung unterbrechen. Wenn der Mehrspieler-Bereich nicht verfügbar ist, fehlt möglicherweise das optionale Match-Modul; Einzelspiele bleiben nutzbar.",
        },
        en = {
            title = "Multiplayer and connections",
            summary = "Host, join, and resolve version problems.",
            tags = "multiplayer mp match lobby host join party raid whisper pin invite version protocol connection",
            body = "Open the Multiplayer tab and choose a supported game on the left. The host creates a session; guests select it and click Join. The lobby and board remain in this tab. Everyone must be ready before the host starts.\n\nOpen sessions are discovered in a party or raid. Without a shared group, joining by whisper may be possible. Depending on the host's policy, the session is open, PIN protected, or restricted to approved players. Approved guests still click Join themselves.\n\nIf a version prevents joining: Arcadia checks the match protocol and, where applicable, the game protocol. Different addon version labels alone do not decide compatibility. A match cannot start when protocols differ. Compare the displayed versions and update the affected addons.\n\nIf there is no response, check the group or whisper connection and try again. A /reload during a match can interrupt the connection. If multiplayer is unavailable, the optional Match module may be missing; local games remain usable.",
        },
    },
    {
        id = "settings",
        de = {
            title = "Arcadia-Einstellungen",
            summary = "Skalierung, Spieleliste und Spieloptionen.",
            tags = "einstellungen settings allgemein spiele skalierung fenster toast",
            body = "Im Tab Einstellungen öffnen sich zuerst die Arcadia-Einstellungen. Allgemein enthält Skalierung, Fensterposition sowie die Anzeigen für Toast und Spiel des Tages.\n\nSpiele verwaltet die sichtbaren Titel in der Sidebar. Änderungen an der Spieleliste werden nach einem Reload wirksam.\n\nDie Optionen und Anleitungen einzelner Spiele findest du über die Spielkategorie in der linken Settings-Sidebar. Die Einführung kannst du hier im Kompendium erneut starten.",
        },
        en = {
            title = "Arcadia settings",
            summary = "Scale, game list, and game options.",
            tags = "settings general games scale window toast",
            body = "The Settings tab first opens Arcadia settings. General contains scaling, window position, and the toast and Game of the Day displays.\n\nGames manages titles visible in the sidebar. Changes to the game list take effect after a reload.\n\nOptions and instructions for individual games are reached through the game category in the left Settings sidebar. You can restart the introduction from this compendium.",
        },
    },
    {
        id = "achievements",
        de = {
            title = "Erfolge und Challenges",
            summary = "Langfristige Ziele und tägliche Aufgaben unterscheiden.",
            tags = "erfolge achievements challenges täglich wöchentlich belohnung xp gold",
            body = "Erfolge sind dauerhafte Ziele und werden im Erfolge-Tab gesammelt. Dort siehst du, welche Ziele bereits freigeschaltet sind.\n\nChallenges sind tägliche oder wöchentliche Aufgaben. Ihr aktueller Fortschritt und die Belohnungen stehen im Profil. Die Aufgaben können nach Ablauf wechseln.\n\nDas Spiel des Tages wird gesondert hervorgehoben und kann zusätzliche XP beim Spielen bringen.",
        },
        en = {
            title = "Achievements and challenges",
            summary = "Understand long-term goals and daily tasks.",
            tags = "achievements challenges daily weekly reward xp gold",
            body = "Achievements are lasting goals collected in the Achievements tab. You can see which goals are already unlocked.\n\nChallenges are daily or weekly tasks. Their current progress and rewards appear in your profile. Tasks can change when their period ends.\n\nThe Game of the Day is highlighted separately and can grant extra XP when played.",
        },
    },
}

function A.Compendium.GetPages()
    local locale = GetLocale and GetLocale() or "deDE"
    local lang = locale == "deDE" and "de" or "en"
    local result = {}
    for _, page in ipairs(pages) do
        local content = page[lang]
        result[#result + 1] = {
            id = page.id,
            title = content.title,
            summary = content.summary,
            tags = content.tags,
            body = content.body,
        }
    end
    return result
end

function A.Compendium.Search(query)
    local matches = {}
    query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    for _, page in ipairs(A.Compendium.GetPages()) do
        local haystack = (page.title .. " " .. page.summary .. " " .. page.tags .. " " .. page.body):lower()
        local found = true
        for term in query:gmatch("%S+") do
            if not haystack:find(term, 1, true) then found = false; break end
        end
        if found then matches[#matches + 1] = page end
    end
    return matches
end
