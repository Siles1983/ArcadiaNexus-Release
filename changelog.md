### Arcadia Nexus 1.1.3 Changelog

### English

- Ludo of Azeroth
- Capturing: no safe squares (including start). Landing on an opponent sends them back to base. Your own pieces are never captured.
- Stacking: pieces of the same color may share a square. Stacked pieces are offset left/right so they can be selected separately.
- Home squares: pieces stay visible and occupy the four home fields one by one (exact count, no stacking on the same home square). Win when all four are home.
- Dice result number is larger and no longer covered by the 2D dice texture.

- Azeroth's Tiny Guardians (overhaul)
- Stable rows and the six adoption cards now use the gold HUD boxes (same look as Blackjack capital).
- Each box, the 3D viewer, needs panel, name overlay, and stall buttons have their own CFG so layout can be tuned without playing through the game.
- Developer Mode shows all ATG layout frames at once as an overlay.
- Needs decay as usual while you play. If ATG is closed but WoW is still running, catch-up on open uses 15% of the normal decay and is capped at 30 minutes. No background tick while the UI is hidden.
- Dragon whelp and Frostwolf pup now have proper species icons.
- Sleeping no longer shifts the HUD downward; the name stays as an overlay on the 3D viewer and the needs box stays fixed.
- The Retire button sits in control-bar segment 1 and only appears when the pet is eligible.
- Need bars show 32×32 icons (hunger, happiness, energy, health, hygiene) in front of the labels.
- Opening a pet in the stable uses the same 3D viewer position as active play. Name overlay on the model, translated DE/EN detail rows with dividers, and Care / New Pet / Back in one row under the box.
- Model widget size (play_model / stall_model) no longer overrides camera zoom and scale from PetData, so framing can be adjusted per species and stage.
- Developer Mode adds a button to jump to the next evolution stage (or back to baby on adult) to review all models.
- Developer Mode is locked to a character allowlist. Other characters do not see the Developer tab, and flipping the saved flag is not enough. `/andevwho` prints the Name-Realm key to add.
- The stable list is scrollable so New Pet and Back stay visible. The shared Nexus scrollbar appears only when the list is long enough to scroll.
- Pets can be released from the stable overview via an X on each card, with a gold confirmation popup.
- A stable holds at most 24 pets. Adopting another while full shows an info popup asking you to release one first.

### Deutsch

- Ludo of Azeroth
- Schlagen: keine Safe-Zone (auch nicht am Startfeld). Landen auf einem Gegner schickt ihn zurück ins Haus. Eigene Figuren werden nie geschlagen.
- Stapeln: Figuren derselben Farbe dürfen auf einem Feld stehen. Gestapelte Figuren werden nach links/rechts versetzt, damit sie einzeln wählbar sind.
- Die Würfelzahl ist größer und wird nicht mehr von der 2D-Würfeltextur überdeckt.

- Azeroth's Tiny Guardians (Umbau)
- Stall-Zeilen und die sechs Adopt-Karten nutzen jetzt die goldenen HUD-Boxen (wie die Blackjack-Kapitalanzeige).
- Jede Box, der 3D-Viewer, die Bedürfnis-Leiste, das Namens-Overlay und die Stall-Buttons haben eigene CFG-Werte und lassen sich ohne Spielablauf justieren.
- Der Developer-Modus zeigt alle ATG-Layout-Rahmen gleichzeitig als Overlay.
- Bedürfnisse sinken im aktiven Spiel unverändert. Ist ATG geschlossen, WoW aber noch offen, gilt beim Öffnen Catch-up mit 15 % der normalen Rate, maximal 30 Minuten. Kein Hintergrund-Tick bei ausgeblendeter UI.
- Drachenwelpe und Frostwolf-Welpe haben jetzt passende Art-Icons.
- Schlafen verschiebt das HUD nicht mehr nach unten; der Name bleibt Overlay auf dem 3D-Viewer, die Bedürfnisbox bleibt fest.
- Der Ruhestand-Button sitzt in Segment 1 der Controls-Leiste und erscheint nur, wenn das Pet den Status hat.
- Vor den Bedürfnis-Labels stehen 32×32-Icons (Hunger, Glück, Energie, Gesundheit, Sauberkeit).
- Ein Pet im Stall öffnet denselben 3D-Viewer wie im aktiven Spiel. Namens-Overlay auf dem Modell, übersetzte DE/EN-Details mit Trennlinien, Pflegen / Neues Pet / Zurück in einer Reihe unter der Box.
- Die Widget-Größe von play_model / stall_model überschreibt Zoom und Scale aus PetData nicht mehr; die Kameras können pro Art und Stufe eingestellt werden.
- Im Developer-Modus springt ein Button zur nächsten Evolutionsstufe (bzw. zurück zum Baby), um alle Modelle zu prüfen.
- Der Developer-Modus ist an eine Charakter-Allowlist gebunden. Andere Charaktere sehen den Entwickler-Tab nicht, das Setzen des Saved-Flags reicht nicht. `/andevwho` gibt den Name-Realm-Schlüssel aus.
- Die Stall-Liste ist scrollbar, damit Neues Pet und Zurück sichtbar bleiben. Der gemeinsame Nexus-Scrollbalken erscheint nur, wenn die Liste lang genug zum Scrollen ist.
- Pets können in der Stall-Übersicht über ein X an der Karte freigelassen werden, mit goldenem Bestätigungs-Popup.
- Maximal 24 Pets gleichzeitig. Ist das Limit erreicht, erscheint beim Adoptieren ein Hinweis, zuerst eines freizulassen.

---

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
