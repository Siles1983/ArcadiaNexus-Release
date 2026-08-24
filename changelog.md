### Arcadia Nexus 1.1.2 Changelog

### English

- Login streaks now use consecutive calendar days instead of fixed 24-hour intervals.

- Daily rewards now reset correctly when the calendar day changes.

- Fixed an error when displaying Argus Orbit Defense save slots.

- Game renderers are now initialized independently with per-game error isolation.

- A broken game can no longer interrupt the initialization of the entire hub.

- Renderer initialization was removed from the minimap module and moved into the central hub bootstrap.

- BlockBreaker HUD positions fixed

- Hangman
- Expanded the puzzle catalog from 84 to 274 fully localized German and English entries.
- Fixed German games using English answers such as "Undercity" instead of "Unterstadt".
- Reorganized the catalog into 11 distinct categories: characters, places, weapons, raids, dungeons, classes, races, bosses, factions, creatures, and professions.
- Expanded the race category from 4 to all 26 currently supported playable races, including Earthen and Haranir.
- Separated classes from races and raids from dungeons; duplicate or misleading category assignments were removed.
- Difficulty now selects dedicated easy, normal, or hard puzzle pools instead of only changing the number of allowed mistakes.
- Added a shuffled puzzle cycle using the shared ArrayUtils and LevelPool utilities. Every puzzle in a pool is used before it is reshuffled, with direct repeats prevented between cycles.
- Added support for visible apostrophes and hyphens in answers such as Gul'dan and Yogg-Saron.
- Long answers now automatically use compact spacing and a smaller font to remain readable.
- Moved puzzle content out of Language.lua into a central Words registry and separate German and English data modules.
- Added automatic validation for missing translations, invalid characters, duplicate IDs, duplicate answers, missing hints, and empty difficulty pools.
- Existing saved category values are migrated automatically to the new category structure.

- Ludo of Azeroth
- Rolling: With no piece on the board, up to three rolls until a 6; otherwise only one roll. A 6 still grants an extra turn.
- Capturing: No safe squares (including the start square). Landing on a piece — opponent or your own — sends it back to base.
- Leaving the house: If one of your pieces is already on the start square, it must move before another can leave the house.
- Home squares: Pieces stay visible on the four home squares and occupy them one by one (exact count, no stacking). Win when all four are home.





### Deutsch

- Login-Streak zählt jetzt auf Basis aufeinanderfolgender Kalendertage statt starrer 24-Stunden-Zeiträume.

- Tägliche Belohnungen werden beim Tageswechsel korrekt zurückgesetzt.

- Fehler beim Anzeigen von Argus-Orbit-Defense-Spielständen behoben.

- Spiel-Renderer werden nun unabhängig und fehlerisoliert initialisiert.

- Ein fehlerhaftes Spiel kann nicht mehr die Initialisierung des gesamten Hubs unterbrechen.

- Renderer-Initialisierung aus dem Minimap-Modul entfernt und dem zentralen Hub-Bootstrap zugeordnet.

- BlockBreaker HUD Positionen korrigiert

- Hangman
- Den Rätselkatalog von 84 auf 274 vollständig lokalisierte deutsche und englische Einträge erweitert.
- Englische Lösungswörter in der deutschen Fassung korrigiert, beispielsweise „Undercity“ zu „Unterstadt“.
- Den Katalog in 11 eindeutige Kategorien gegliedert: Charaktere, Orte, Waffen, Schlachtzüge, Dungeons, Klassen, Völker, Bosse, Fraktionen, Kreaturen und Berufe.
- Die Kategorie „Völker“ von 4 auf alle 26 derzeit unterstützten spielbaren Völker erweitert, einschließlich Irdene und Haranir.
- Klassen und Völker sowie Schlachtzüge und Dungeons getrennt; doppelte oder irreführende Kategoriezuordnungen entfernt.
- Die Schwierigkeit wählt nun eigene einfache, normale oder schwere Rätselpools aus, statt lediglich die erlaubten Fehlversuche zu verändern.
- Gemischten Rätselzyklus über die gemeinsamen Hilfsmodule ArrayUtils und LevelPool eingeführt. Jedes Rätsel eines Pools wird einmal verwendet, bevor neu gemischt wird; direkte Wiederholungen zwischen zwei Zyklen werden verhindert.
- Sichtbare Apostrophe und Bindestriche in Antworten wie Gul'dan und Yogg-Saron werden jetzt unterstützt.
- Lange Antworten verwenden automatisch kompaktere Abstände und eine kleinere Schriftgröße.
- Rätselinhalte aus der Language.lua in eine zentrale Words-Registry und getrennte deutsche und englische Datenmodule ausgelagert.
- Automatische Validierung auf fehlende Übersetzungen, ungültige Zeichen, doppelte IDs, doppelte Antworten, fehlende Hinweise und leere Schwierigkeits-Pools ergänzt.
- Bestehende gespeicherte Kategorien werden automatisch auf die neue Kategorienstruktur migriert.

- Ludo of Azeroth
- Würfeln: Ohne Figur auf dem Feld bis zu drei Würfe auf eine 6, sonst nur ein Wurf. Eine 6 gibt weiterhin einen Extra-Zug.
- Schlagen: Keine Safe-Zone mehr (auch nicht am Startfeld). Landen auf einer Figur — Gegner oder eigene — schickt sie zurück ins Haus.
- Haus verlassen: Steht bereits eine eigene Figur auf dem Startfeld, muss sie erst ziehen, bevor eine neue raus darf.
- Zielfelder: Figuren bleiben auf den vier Zielfeldern sichtbar und belegen sie nacheinander (exakte Augenzahl, kein doppeltes Feld). Sieg, wenn alle vier im Ziel stehen.
