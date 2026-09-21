# Einbau in Roblox Studio

Es gibt zwei Wege. **Weg A ist der empfohlene** — du fügst eine Datei ein und
bist fertig. Weg B ist die Handarbeit für den Fall, dass du sehen willst, wie
es aufgebaut ist.

---

## Schritt 0: Neues Projekt + DataStore freischalten

1. Roblox Studio → **New** → **Baseplate**
   (Die graue Baseplate löscht das Spiel beim ersten Start automatisch.)
2. **File → Game Settings → Security** → „Enable Studio Access to API Services"
   einschalten → Speichern

> Ohne Schritt 2 kann das Spiel später auf dem echten Server nicht speichern.
> Solange `GameConfig.Speicher.InStudioSpeichern = false` steht, speichert der
> Studio-Test *absichtlich* nichts — du startest bei jedem Test frisch bei 0
> Credits. Auf dem echten Roblox-Server wird trotzdem normal gespeichert.

---

## Weg A — Ein Klick pro Ordner *(empfohlen)*

Drei Dateien aus dem Ordner `install/` herunterladen:

- `ReplicatedStorage.rbxmx`
- `ServerScriptService.rbxmx`
- `StarterPlayerScripts.rbxmx`

Dann in Studio im **Explorer**:

| # | Rechtsklick auf … | → | Datei |
|---|---|---|---|
| 1 | `ReplicatedStorage` | **Insert from File…** | `ReplicatedStorage.rbxmx` |
| 2 | `ServerScriptService` | **Insert from File…** | `ServerScriptService.rbxmx` |
| 3 | `StarterPlayer` → `StarterPlayerScripts` | **Insert from File…** | `StarterPlayerScripts.rbxmx` |

Fertig. Alle 26 Scripts liegen an der richtigen Stelle, mit den richtigen Typen
(ModuleScript / Script / LocalScript) und dem Unterordner `Services`.

> **Beim Aktualisieren:** Lösche die alten Objekte vorher, sonst liegen sie
> doppelt da (Studio hängt „Copy" an den Namen). Am schnellsten: die acht
> Einträge in `ReplicatedStorage` markieren und löschen, dann `Main` und
> `Services` in `ServerScriptService`, dann die vier LocalScripts — und neu
> einfügen.

---

## Weg A2 — Alles mit einem einzigen Einfügen

Wenn du lieber gar keine Dateien herunterladen willst:

1. `install/INSTALLER.lua` öffnen und **den kompletten Inhalt kopieren**
2. In Studio: **View → Command Bar** einblenden
3. In die Befehlsleiste einfügen und **Enter** drücken

Das Script legt alles an und schreibt in die Konsole:

```
================================================
STELLAR DOMINION installiert: 26 Scripts
Jetzt auf Play druecken (F5).
================================================
```

Ein zweiter Lauf **überschreibt** die vorhandenen Scripts — so spielst du
Updates ein, ohne vorher etwas zu löschen.

> ⚠️ Die Datei ist ca. 265 KB groß. Manche Studio-Versionen kürzen sehr große
> Einfügungen in der Befehlsleiste. Kommt eine Syntaxfehlermeldung oder steht
> am Ende nicht „26 Scripts", nimm Weg A — der hat keine Größenbegrenzung.

---

## Weg B — Von Hand anlegen

Nur nötig, wenn du den Aufbau selbst nachvollziehen willst. Jede Datei aus
`src/` wird zu einem Objekt im Explorer. Die Dateiendung sagt dir den Typ:

| Endung | Roblox-Typ | Startet von allein? |
|---|---|---|
| `.lua` | ModuleScript | nein — wird per `require()` geladen |
| `.server.lua` | Script | ja, auf dem Server |
| `.client.lua` | LocalScript | ja, beim Spieler |

Rechtsklick auf den Zielordner → **Insert Object** → passender Typ → umbenennen
→ Doppelklick → alles markieren (`Strg+A`), löschen, Dateiinhalt einfügen.

> Die Namen müssen **exakt** stimmen (Groß-/Kleinschreibung!), sonst findet
> `require(script.Parent.XYZ)` das Modul nicht.
> Den Ordner `Remotes` **nicht** anlegen — den erzeugt `Net` beim Serverstart.

---

## Die fertige Struktur zur Kontrolle

```
ReplicatedStorage
├── GameConfig       (ModuleScript)   Balance Basis-Tycoon
├── FleetConfig      (ModuleScript)   Balance Schiffe
├── PlanetConfig     (ModuleScript)   Balance Planeten + Kampfformel
├── TechConfig       (ModuleScript)   Technologie, Rebirth, Shop-Ids
├── Util             (ModuleScript)
├── Signal           (ModuleScript)
├── UiKit            (ModuleScript)
└── Net              (ModuleScript)

ServerScriptService
├── Main             (Script)         ← Script, nicht ModuleScript!
└── Services         (Folder)
    ├── DataService         ├── FleetService
    ├── CurrencyService     ├── HangarService
    ├── WorldBuilder        ├── PlanetService
    ├── PlotService         ├── CombatService
    ├── ButtonService       ├── MonetizationService
    ├── DropperService      ├── ImperiumService
    └── EventService

StarterPlayer
└── StarterPlayerScripts
    ├── HudClient    (LocalScript)
    ├── FleetGui     (LocalScript)
    ├── PlanetGui    (LocalScript)
    └── ImperiumGui  (LocalScript)
```

---

## Testen

**Play** drücken (F5). In der **Output**-Konsole (View → Output) sollte stehen:

```
=== STELLAR DOMINION startet ===
[WorldBuilder] Weltraum-Umgebung aufgebaut
[PlotService] 6 Plots gebaut
[PlotService] bereit
[ButtonService] bereit
[DropperService] bereit
[FleetService] bereit
[HangarService] bereit
[PlanetService] 12 Planeten gebaut
[PlanetService] bereit
[CombatService] bereit
[MonetizationService] bereit
[ImperiumService] bereit
[EventService] bereit
=== STELLAR DOMINION bereit ===
[Main] DeinName ist beigetreten
[PlotService] DeinName -> Plot 1
```

### Die Runde durchspielen

1. Du stehst auf einer Plattform mit blauer Neon-Kante, ringsum Sterne
2. Oben rechts das HUD, links die Knöpfe **FLOTTE · PLANETEN · IMPERIUM**
3. Auf das blaue Pad **„Erz-Extraktor I — GRATIS"** laufen
4. Alle 2,5 s fliegt ein Erz-Brocken zum Sammelkern, der Lagerbalken füllt sich
5. **SAMMELN** drücken (oder zum Sammelkern laufen)
6. Weiter kaufen, bis du 2.500 CR hast
7. **FLOTTE** → **BAUEN +1** → nach 6 s schwebt ein Jäger über deinem Plot
8. **PLANETEN** → *Ferra* hat 150 Verteidigung. Ein Jäger hat 12 Angriff →
   Siegchance ~7 %. Bau also erst ein paar Schiffe mehr
9. Bei ~60 % Siegchance: **ANGREIFEN**. Die Flotte fliegt 4 s, dann das Ergebnis
10. Nach der Eroberung färbt sich der Planetenring in deiner Farbe und dein
    Multiplikator oben rechts springt von x1.00 auf x1.50
11. **IMPERIUM** → Technologien erforschen, später Rebirth

### Mit mehreren Spielern testen
**Test**-Reiter → **Clients and Servers** → 2 Players → **Start**.
Jeder bekommt einen eigenen Plot; Planeten könnt ihr euch gegenseitig abnehmen.

---

## Häufige Fehler

| Symptom | Ursache und Lösung |
|---|---|
| `Infinite yield possible on 'WaitForChild("XYZ")'` | Modul fehlt oder heißt anders. Namen im Explorer prüfen. |
| `attempt to index nil with 'DataService'` | Ordner `Services` fehlt oder ist falsch geschrieben. |
| Nichts passiert beim Play | `Main` ist ein *ModuleScript* statt *Script*. |
| Scripts doppelt („GameConfig", „GameConfig Copy") | Beim Aktualisieren die alten nicht gelöscht. |
| `502: API Services rejected request` | Schritt 0.2 nicht gemacht. |
| HUD erscheint nicht | LocalScripts liegen nicht in `StarterPlayerScripts`, oder sind *Scripts* statt *LocalScripts*. |
| Keine Plots sichtbar | Zu weit weg — die Plots liegen im Raster um den Nullpunkt. |
| Schiffe unsichtbar, obwohl gebaut | Nach oben schauen: Orbit liegt 75 Studs über dem Plot. |
| Shop zeigt nur „BALD VERFÜGBAR" | Normal. Die Ids in `TechConfig` stehen alle auf 0 — siehe unten. |
| Angriff tut nichts | Cooldown (30 s), Schutzschild des Gegners, oder keine Schiffe. Die Toast-Meldung sagt es dir. |

---

## Balancing

Alles in den vier Config-Modulen, kein anderes Script muss angefasst werden.

```lua
-- GameConfig: Basis-Tycoon
Config.DropperTypen.Erz.Betrag = 4            -- Credits pro Lieferung
Config.DropperTypen.Erz.Intervall = 2.5       -- Sekunden dazwischen
Config.Multiplikatoren.BonusProPlanet = 0.5   -- +50 % pro Planet
Config.Plot.Anzahl = 6                        -- Spieler pro Server

-- FleetConfig: Schiffe
FleetConfig.Allgemein.BasisKapazitaet = 12    -- Hangar-Plätze am Anfang
FleetConfig.Allgemein.MaxSichtbar = 24        -- Schiffe im Orbit (Performance!)

-- PlanetConfig: Eroberung
PlanetConfig.Kampf.AngriffsCooldown = 30
PlanetConfig.Kampf.SchildNachEroberung = 180
PlanetConfig.Planeten[1].Verteidigung = 150

-- TechConfig: Langzeit
TechConfig.Rebirth.Grundschwelle = 250000
TechConfig.Ereignisse.MinAbstand = 180        -- Sekunden zwischen Ereignissen
```

**Auf Handys** lohnt sich `FleetConfig.Allgemein.MaxSichtbar = 12`.

> ⚠️ Einmal veröffentlichte `Id`-Werte **nie** umbenennen. Sie stehen so in den
> Spielständen. Eine geänderte Id bedeutet für alle Spieler: Objekt weg, Geld weg.

### Nach Änderungen die Installationsdateien neu erzeugen

```bash
python3 tools/build_installer.py
```

---

## Gamepasses und Produkte aktivieren

Alle Ids in `TechConfig` stehen auf `0` = „noch nicht angelegt". Der Server
überspringt sie dann, und im Shop steht „BALD VERFÜGBAR". Das Spiel läuft also
vollständig ohne Monetarisierung.

So schaltest du sie frei:

1. **Creator Dashboard** → dein Spiel → **Monetization**
2. **Passes → Create Pass** bzw. **Developer Products → Create**
3. Die Id aus der URL (`…/game-pass/1234567/…`) in `TechConfig` eintragen:

```lua
{ Schluessel = "DoppeltesEinkommen", Id = 1234567, ... }
```

Mehr ist nicht nötig — Abfrage, Freischaltung und `ProcessReceipt` sind fertig.
