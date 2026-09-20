### Arcadia Nexus 1.1.5 Changelog

### English

- Gamepad (ConsolePort)
- Optional ConsolePort support: the hub cursor works on menus, boards, and buttons. Toggle it under Hub Settings → General.
- Arcade titles that need hold or analog input (BlockBreaker, pinball, shooters, Snake, Blockdrop, and others) map the stick, D-pad, and face buttons onto the existing keyboard controls.
- Click games keep the cursor. Circle / B leaves a round; Square / X is right-click (flag, rotate, notes). Options pauses when the game has a pause button.
- Result dialogs, save-slot menus, and choice popups are fully usable without a mouse. DualSense: Circle backs out.

- Arcane Barrage (new)
- Hex-field shooter: aim with the mouse, match three connected orbs, hanging clusters drop for big points.
- Modes: Endless (new top row after misses), Time (120 seconds, large groups add time back), Campaign (100 shot-limit levels with save slots).
- Campaign map: 10 regions from Leyline Origin to Arcane Crown.
- Combos, a power bar (Joker, Bomb, Chain Lightning, Dragonfire), and Overcharge.

- Backgammon (new)
- Classic backgammon: Ivory vs Obsidian, 15 checkers each, hit to the bar, bear off from home.
- Opening roll decides who starts. Doubles play four times. Confirm a turn or undo steps; pass when nothing is legal.
- Local play vs AI (Apprentice, Challenger, Master) with save and resume. Walnut & gold or Midnight board.
- Also playable in the Multiplayer tab (2 seats). Gammons and backgammons are scored; no doubling cube.

- Azeroth Intelligence (new)
- Codenames-style word grid: Horde vs Alliance. Spymasters see the key, operatives only the words.
- One-word clues plus a number. Own colour continues; miss ends the turn. The assassin card loses the round immediately.
- Hotseat: all four roles on one client. Word sets: Azeroth, Everyday, Nature, World & Travel.
- Online 2v2 in the Multiplayer tab (four players, one role each; two players can play as a duo).
- Four themed word sets with 400 words each for Everyday, Nature, and World & Travel. Each client sees its own German or English card text.
- The host's word set is shown in the session details and lobby before joining or starting a round.
- Clearer play feedback: a gold turn pulse, a compact action history, and helpful messages for invalid clues.
- Long card names scale to fit and show their full text on mouseover.
- Optional accessibility markers add letters/symbols to visible red, blue, neutral, and assassin cards.

- Darkmoon Pinball (new)
- Darkmoon Faire pinball: A/D flippers, hold Space to launch, Q/E/W nudge, P pause.
- Three balls per round. Combos, missions, kickback, ball save, extra ball, and lock into multiball. Too much nudge tilts the table.
- Two hand-painted tables: Midway (velvet, brass, tent lights, shrine and animated eye) and Carousel (navy, ivory, rose gold, ticket targets, curtain lock).
- Bumpers, targets, flippers, slingshots, and plunger use real sprites; hit and lit glows stay dynamic. The right flipper is a mirrored graphic. Lock and jackpot sit behind the eye.
- Midway launches from the right trough along a curve into the field. A ball that falls off the bottom still drains, so the round cannot stall.
- Light chases on lanes and bumpers during mission, combo, frenzy, and multiball. Jackpot and Super Jackpot gold-pulse; Midway lights the eye, Carousel pulses the ring bumpers.
- HUD: gold for score and mission, violet on hot combos, red on tilt.
- Own sounds: bumper bounce, flippers (A/D), charging the plunger, hitting targets, and tilt. Drain, launch, missions, jackpot, and multiball keep the existing WoW cues. Each can be toggled under Sound.

- Alien Defense (look and sound)
- Enemies and the player ship explode on hit.
- The ship hovers, with engine glow and muzzle flash.
- Two-layer starfield parallax.
- The alien formation bobs as it marches.
- New sounds for shots, kills, hits, and pickups.
- Weapon drops pulse; collecting one flashes on the ship.
- Pause panel restyled. Wave names show in the HUD.

- Argus Orbit Defense
- Shots no longer slow down when many are on screen. Rapid Fire still speeds up Spread Shot for the full pickup time.
- Two-layer scrolling starfield. Optional flight parallax (stars follow the ship) under Visuals — turn it off if it feels uncomfortable.
- Holy Shield shows a ring on the ship. Rapid Fire and Spread Shot have their own HUD timers.
- Wave or level title on spawn; Fel Hunter warning when they enter. Muzzle spark on fire; Naaru Bomb shows its blast radius.
- Pause button reads Pause again after you quit while paused and load a save. HUD and pause text follow DE/EN.

- Arcadia Pairs
- Class Reunion and Journey through Azeroth: proper 32-icon decks, no filler art. Booty Bay: broken gem icon replaced.
- Cards flip when revealed or hidden. Match pop, miss shake, stronger hover on face-down cards.
- Deal-in at round start. Found pairs stay dimmed.
- Streak ×2+ as floating combat text over the board, stronger on longer chains.
- Win: “All pairs!” plus a gold pulse, then the result.
- Timer out: remaining cards shake, unmatched pairs flip with matching colors, then the dialog (not in duels).
- Duel: floating text before win, loss, and draw.

- Leaderboard
- The selected game’s logo sits centered in the list as a watermark. Highscore boxes stay in front so scores stay readable.
- The list scrolls over the logo; the logo stays in the canvas.

- Azeroth Jewels
- Idle hint: after 5 seconds, valid swaps sparkle (toggle under Help).
- Campaign 51–100, plus a 10-page level map with 1–3 stars per level.
- Drag adjacent jewels to swap; click-to-select still works.
- Collect goals show a progress bar and flash when that color scores. Lagging target colors spawn a bit more often.
- Power-up tooltips show charge (combos or points left until the next charge).
- Warning tick at 3/2/1 moves left (Sound).
- After level 100: Endless waves (8×8, rising malus). Start from the map or the completion dialog.
- Ice, stone, and locked tiles use their own art. Cascade pop, combo pulse, ice shatter.
- Help: Reduce motion; flying scores and a light board shake (combo ×2+).

- BlockBreaker
- Extra ball: a life is lost only when the last ball falls.
- After start, next level, or a lost life the ball sticks to the paddle. Space serves it; in play Space pauses. P always pauses.
- Theme-colored ball trail. Blocks shatter with score pops. Combo in the score line; milestones flash at the top of the field.
- Paddle reacts to hits and power-ups. Catching a power-up shows a burst and label.
- Serve hint “Space” above the paddle (once per round).
- With five blocks left the field edge pulses. Wall hits and level clear use a soft edge glow.
- Multiple power-ups: up to three timer boxes stacked on the left, each with a duration bar. The wide bar at the top is gone.
- Visuals: Reduce motion (no trail, no shards).

- Tic Tac Toe
- Your mark appears at once; the AI thinks, then moves. Turn HUD sits above the board; the last cell is highlighted.
- Who starts: you, AI, or random. Win length is independent of size (e.g. 4 in a row on 5×5); 3×3 stays three.
- Hard AI is unbeatable on 3×3; on larger boards it hunts forks.
- Hover preview on empty cells. Place sound (Sound → Move). Winning cells light green or red; the rest of the board dims.
- Games tab: Best of 3 vs AI (draws do not count). Multiplayer stays a single classic 3×3.
- Standard X and O marks are larger. Dropdowns on the control bar have tooltips.
- New achievements, including series wins, 5×5, draws vs Hard, and multiplayer wins.

### Deutsch

- Gamepad (ConsolePort)
- Optionale ConsolePort-Unterstützung: der Hub-Cursor bedient Menüs, Bretter und Buttons. Schalter unter Hub-Einstellungen → Allgemein.
- Arcade-Titel mit Halten oder Analog (BlockBreaker, Pinball, Shooter, Snake, Blockdrop und weitere) legen Stick, D-Pad und Aktionstasten auf die bestehende Tastatursteuerung.
- Klickspiele behalten den Cursor. Circle / B beendet eine Runde; Square / X ist Rechtsklick (Flagge, Drehen, Notizen). Options pausiert, wenn es einen Pause-Button gibt.
- Result-Dialoge, Speicher-Slots und Auswahl-Popups gehen ohne Maus. DualSense: Circle geht zurück.

- Arcane Barrage (neu)
- Hex-Feld-Shooter: mit der Maus zielen, drei verbundene Energien matchen, hängende Cluster fallen für viele Punkte.
- Modi: Endlos (neue Reihe von oben nach Fehlschüssen), Zeit (120 Sekunden, große Gruppen geben Zeit zurück), Kampagne (100 Level mit Schusslimit und Speicherständen).
- Kampagnen-Karte: 10 Regionen vom Leylinien-Ursprung bis zur Arkanen Krone.
- Kombos, Machtleiste (Joker, Bombe, Kettenblitz, Drachenfeuer) und Overcharge.

- Backgammon (neu)
- Klassisches Backgammon: Elfenbein gegen Obsidian, je 15 Steine, Schlagen auf die Bar, Abtragen aus dem Heimfeld.
- Eröffnungswurf entscheidet den Start. Pasch zählt viermal. Zug bestätigen oder Schritte zurücknehmen; passen, wenn nichts legal ist.
- Lokal gegen KI (Lehrling, Herausforderer, Meister) mit Speichern und Fortsetzen. Brett: Walnuss & Gold oder Mitternacht.
- Auch im Mehrspieler-Tab (2 Sitze). Gammon und Backgammon werden gewertet; kein Verdopplungswürfel.

- Azeroth Intelligence (neu)
- Wort-Raster im Codenames-Stil: Horde gegen Allianz. Spione sehen die Key-Karte, Agenten nur die Wörter.
- Hinweis: ein Wort plus Zahl. Eigene Farbe: weiter. Fehlgriff beendet den Zug. Die Assassinen-Karte verliert die Runde sofort.
- Hotseat: alle vier Rollen an einem Client. Wortsets: Azeroth, Alltag, Natur, Welt & Reisen.
- Online 2v2 im Mehrspieler-Tab (vier Spieler, eine Rolle pro Client; zwei Spieler als Duo).
- Vier thematische Wortsets; Alltag, Natur sowie Welt & Reisen enthalten jeweils 400 Begriffe. Jeder Client sieht Kartentexte auf Deutsch oder Englisch.
- Das Wortset des Hosts ist vor dem Beitritt in den Sitzungsdetails und vor Rundenstart in der Lobby sichtbar.
- Klareres Spiel-Feedback: Goldimpuls beim Zugwechsel, kompakte Zughistorie und verständliche Meldungen bei ungültigen Hinweisen.
- Lange Kartenbegriffe passen sich der Kachel an und zeigen beim Mouseover den vollständigen Text.
- Optionale Barrierefreiheitsmarker ergänzen sichtbare rote, blaue, neutrale und Assassinen-Karten mit Buchstaben bzw. Symbolen.

- Darkmoon Pinball (neu)
- Pinball auf dem Dunkelmond-Jahrmarkt: A/D Flipper, Leertaste halten zum Abfeuern, Q/E/W Nudge, P Pause.
- Drei Bälle pro Runde. Combos, Missionen, Kickback, Ball Save, Extra Ball und Lock zum Multiball. Zu viel Nudge kippt den Tisch (Tilt).
- Zwei handgezeichnete Tische: Midway (Samt, Messing, Zeltlichter, Schrein und animiertes Auge) und Karussell (Nachtblau, Elfenbein, Roségold, Ticket-Ziele, Vorhang-Lock).
- Bumper, Targets, Flipper, Slingshots und Feder mit echten Sprites; Treffer- und Lit-Glows bleiben dynamisch. Rechter Flipper gespiegelt. Lock und Jackpot liegen hinter dem Auge.
- Midway startet in der rechten Rinne und folgt einer Launch-Kurve ins Feld. Eine Kugel, die unten herausfällt, gilt trotzdem als Drain — die Runde bleibt nicht hängen.
- Licht-Chases auf Lanes und Bumpern bei Mission, Combo, Frenzy und Multiball. Jackpot und Super-Jackpot als Goldpuls; Midway lässt das Auge aufleuchten, Karussell pulsiert über die Ring-Bumper.
- HUD: Gold für Punkte und Mission, Violett bei heißen Combos, Rot bei Tilt.
- Eigene Sounds: Bumper-Abpraller, Flipper (A/D), Feder spannen, Targets und Tilt. Drain, Abschuss, Missionen, Jackpot und Multiball bleiben die bisherigen WoW-Klänge. Einzelne Häkchen unter Sound.

- Alien Defense (Grafik und Sound)
- Gegner und Spielerschiff explodieren bei Treffer.
- Das Schiff schwebt, mit Schubflamme und Mündungsfeuer.
- Sternenhimmel mit zwei Parallax-Schichten.
- Die Alien-Formation wippt im Marsch.
- Neue Sounds für Schüsse, Kills, Treffer und Einsammeln.
- Waffen-Drops pulsen; Einsammeln blitzt am Schiff.
- Pause-Anzeige überarbeitet. Wellenname im HUD.

- Argus Orbit Defense
- Die Schussrate bricht nicht mehr ein, wenn viele Projektile im Feld sind. Schnellfeuer beschleunigt Streuschuss über die volle Pickup-Zeit.
- Sternenhimmel mit zwei scrollenden Schichten. Optionaler Flug-Parallax (Sterne folgen dem Schiff) unter Visuelles — abschaltbar bei Unwohlsein.
- Heiliger Schild als Ring am Schiff. Schnellfeuer und Streuschuss mit eigenen HUD-Timern.
- Wellen- bzw. Level-Titel beim Start; Warnung, wenn Fel Hunter erscheinen. Mündungsfunke beim Schuss; Naaru-Bombe zeigt den Explosionsradius.
- Pause-Button zeigt nach Beenden während Pause und erneutem Laden wieder Pause. HUD und Pause-Texte folgen DE/EN.

- Arcadia Pairs
- Klassentreffen und Reise durch Azeroth: eigene 32er-Decks, keine Füll-Icons. Beute-Bucht: defektes Gem-Icon ersetzt.
- Karten wenden sich beim Auf- und Zudecken. Treffer-Pop, Fehlversuch-Wackeln, Hover auf verdeckten Karten.
- Rundenstart: Karten werden ausgeteilt. Gefundene Paare bleiben dunkler.
- Serie ×2+ als Kampftext über dem Feld, kräftiger bei längerer Kette.
- Sieg: „Alle Paare!“ plus Gold-Puls, dann Ergebnis.
- Timer aus: offene Karten wackeln, restliche Paare werden farbig zugeordnet aufgedeckt, dann Dialog (nicht im Duell).
- Duell: Schwebetext vor Sieg, Niederlage und Unentschieden.

- Bestenliste
- Logo des gewählten Spiels als Wasserzeichen in der Listenmitte. Highscore-Boxen liegen darüber, die Werte bleiben lesbar.
- Die Liste scrollt über das Logo; das Logo bleibt im Canvas.

- Azeroth Jewels
- Zug-Hilfe: nach 5 Sekunden funkeln gültige Tausche (abschaltbar unter Hilfe).
- Kampagne 51–100, dazu eine 10-Seiten-Levelkarte mit 1–3 Sternen pro Level.
- Benachbarte Juwelen per Ziehen tauschen; Klick-Auswahl bleibt.
- Sammelziele mit Fortschrittsbalken, Aufleuchten bei Treffer. Hinterherhinkende Zielfarben erscheinen etwas häufiger.
- Power-Up-Tooltips zeigen den Ladestand (Kombos oder Punkte bis zur nächsten Ladung).
- Warn-Tick bei 3/2/1 Zügen (Sound).
- Nach Level 100: Endlos-Wellen (8×8, steigender Malus). Start über die Karte oder den Abschluss-Dialog.
- Eis, Stein und Sperrfelder mit eigener Grafik. Kaskaden-Pop, Kombo-Puls, Eisbruch.
- Hilfe: Weniger Bewegung; fliegende Punkte und leichter Bildruck am Brett (ab Kombo ×2).

- BlockBreaker
- Extra-Ball: ein Leben geht erst verloren, wenn der letzte Ball fällt.
- Nach Start, Levelwechsel und Lebenverlust klebt der Ball am Paddle. Leertaste startet ihn; im Spiel Pause. P pausiert immer.
- Kugel-Schweif in Theme-Farbe. Blöcke zerfallen in Splitter mit Punkte-Pops. Combo in der Punktezeile, Meilensteine oben im Feld.
- Paddle reagiert auf Treffer und Power-ups. Power-up-Catch mit Burst und Text.
- Serve-Hinweis „Leertaste“ über dem Paddle (einmal pro Runde).
- Ab fünf Blöcken pulsiert der Feldrand. Wandtreffer und Level-Clear als weicher Kanten-Glow.
- Mehrere Power-ups: bis zu drei Timer-Boxen links, gestapelt, mit Restzeitbalken. Die breite Leiste oben entfällt.
- Visuelles: Weniger Bewegung (kein Schweif, keine Splitter).

- Tic Tac Toe
- Dein Stein erscheint sofort; die KI denkt nach und setzt danach. Zug-HUD über dem Feld; letzter Zug ist markiert.
- Wer beginnt: du, KI oder Zufall. Gewinnlänge unabhängig von der Größe (z. B. 4 in Folge auf 5×5); 3×3 bleibt drei.
- KI auf Schwer ist auf 3×3 unschlagbar; auf großen Feldern sucht sie Gabeln.
- Hover-Vorschau auf leeren Feldern. Setz-Sound (Sound → Zug). Gewinnzellen leuchten grün oder rot; der Rest des Bretts dunkelt ab.
- Spiele-Tab: Best of 3 gegen die KI (Unentschieden zählen nicht). Mehrspieler bleibt eine klassische 3×3-Partie.
- Standard-X und -O sind größer. Dropdowns in der Leiste haben Tooltips.
- Neue Erfolge, unter anderem Serien, 5×5, Remis gegen Schwer und Mehrspieler-Siege.

---

### Arcadia Nexus 1.1.4 Changelog

### English

- Multiplayer (new hub tab)
- Host or join a session with players in your party or raid. Discovery stays in the group — no LFG.
- Join can be open, locked with a PIN, or limited to players the host allows. The PIN is never shown in the session list.
- First title: Azeroth Intelligence. Four players play classic 2v2 (one role each). Two players can play as a duo (each client plays a full pair).
- Ready in the lobby, then the host starts. After a round you can rematch with the same host.
- Guests can rejoin after a /reload. If the host reloads, the session ends for everyone.

### Deutsch

- Mehrspieler (neuer Hub-Tab)
- Sitzung hosten oder in der Party/Raid teilnehmen. Entdeckung nur in der Gruppe — kein LFG.
- Beitritt offen, per PIN oder nur für vom Host freigegebene Spieler. Die PIN steht nicht in der Sitzungsliste.
- Erstes Spiel: Azeroth Intelligence. Vier Spieler Klassik 2v2 (eine Rolle pro Client). Zwei Spieler Duo (jedes Paar auf einem Client).
- In der Lobby auf Bereit klicken, der Host startet. Danach Rematch mit demselben Host.
- Gäste können nach einem /reload wieder einsteigen. Lädt der Host neu, endet die Sitzung für alle.

---

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
