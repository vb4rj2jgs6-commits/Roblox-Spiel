# Einbau in Roblox Studio — Schritt für Schritt

Du brauchst **kein** Rojo und keine Zusatzsoftware. Alles per Copy & Paste.
Rechne mit ca. 10 Minuten.

---

## 0. Neues Projekt anlegen

Roblox Studio → **New** → **Baseplate**.
Die graue Baseplate löscht das Spiel beim ersten Start automatisch.

---

## 1. DataStore freischalten (einmalig, wichtig!)

Ohne diesen Schritt kann das Spiel später auf dem echten Server nicht speichern.

1. In Studio oben: **File → Game Settings → Security**
2. **„Enable Studio Access to API Services"** einschalten
3. Speichern

> Solange `GameConfig.Speicher.InStudioSpeichern = false` steht, speichert das
> Spiel im Studio-Test *absichtlich* nichts. Das ist beim Entwickeln praktisch:
> Du startest immer mit 0 Credits und kannst den Fortschritt sauber testen.
> Auf dem echten Roblox-Server wird trotzdem normal gespeichert.
> Willst du auch im Studio speichern, stelle den Wert auf `true`.

---

## 2. Ordner und Scripts anlegen

Im **Explorer** (Ansicht → Explorer, falls nicht sichtbar).
Rechtsklick auf einen Ordner → **Insert Object** → passenden Typ wählen.

### 2.1 ReplicatedStorage

Rechtsklick auf `ReplicatedStorage` → **Insert Object → ModuleScript**.
Sechsmal, und jeweils umbenennen (Doppelklick auf den Namen):

| Name | Inhalt aus Datei |
|---|---|
| `GameConfig` | `src/ReplicatedStorage/GameConfig.lua` |
| `FleetConfig` | `src/ReplicatedStorage/FleetConfig.lua` |
| `Util` | `src/ReplicatedStorage/Util.lua` |
| `Signal` | `src/ReplicatedStorage/Signal.lua` |
| `UiKit` | `src/ReplicatedStorage/UiKit.lua` |
| `Net` | `src/ReplicatedStorage/Net.lua` |

Bei jedem: Doppelklick öffnet den Editor. Inhalt komplett markieren (`Strg+A`),
löschen, Datei-Inhalt einfügen.

> ⚠️ Den Ordner `Remotes` **nicht** selbst anlegen — den erzeugt `Net` beim
> Serverstart automatisch.

### 2.2 ServerScriptService

1. Rechtsklick auf `ServerScriptService` → **Insert Object → Script**
   → umbenennen in **`Main`**
   → Inhalt aus `src/ServerScriptService/Main.server.lua`

   > Achtung: Das ist ein **Script**, kein ModuleScript. Nur ein Script startet
   > von allein.

2. Rechtsklick auf `ServerScriptService` → **Insert Object → Folder**
   → umbenennen in **`Services`**

3. In diesen Ordner **acht ModuleScripts** einfügen:

| Name | Inhalt aus Datei |
|---|---|
| `DataService` | `src/ServerScriptService/Services/DataService.lua` |
| `CurrencyService` | `src/ServerScriptService/Services/CurrencyService.lua` |
| `WorldBuilder` | `src/ServerScriptService/Services/WorldBuilder.lua` |
| `PlotService` | `src/ServerScriptService/Services/PlotService.lua` |
| `ButtonService` | `src/ServerScriptService/Services/ButtonService.lua` |
| `DropperService` | `src/ServerScriptService/Services/DropperService.lua` |
| `FleetService` | `src/ServerScriptService/Services/FleetService.lua` |
| `HangarService` | `src/ServerScriptService/Services/HangarService.lua` |

> Die Namen müssen **exakt** stimmen (Groß-/Kleinschreibung!), sonst findet
> `require(script.Parent.XYZ)` das Modul nicht.

### 2.3 StarterPlayerScripts

Im Explorer: `StarterPlayer` aufklappen → `StarterPlayerScripts`.
Dort **zwei LocalScripts** einfügen (Rechtsklick → **Insert Object → LocalScript**):

| Name | Inhalt aus Datei |
|---|---|
| `HudClient` | `src/StarterPlayerScripts/HudClient.client.lua` |
| `FleetGui` | `src/StarterPlayerScripts/FleetGui.client.lua` |

> `StarterGui` bleibt leer. Das HUD wird per Code erzeugt — so flackert es beim
> Respawn nicht und du musst nichts zusammenklicken.

---

## 3. Fertige Struktur zur Kontrolle

```
ReplicatedStorage
├── GameConfig       (ModuleScript)
├── FleetConfig      (ModuleScript)
├── Util             (ModuleScript)
├── Signal           (ModuleScript)
├── UiKit            (ModuleScript)
└── Net              (ModuleScript)

ServerScriptService
├── Main             (Script)          ← Script, nicht ModuleScript!
└── Services         (Folder)
    ├── DataService      (ModuleScript)
    ├── CurrencyService  (ModuleScript)
    ├── WorldBuilder     (ModuleScript)
    ├── PlotService      (ModuleScript)
    ├── ButtonService    (ModuleScript)
    ├── DropperService   (ModuleScript)
    ├── FleetService     (ModuleScript)
    └── HangarService    (ModuleScript)

StarterPlayer
└── StarterPlayerScripts
    ├── HudClient    (LocalScript)
    └── FleetGui     (LocalScript)
```

---

## 4. Testen

**Play** drücken (F5). Erwartetes Verhalten:

1. Der Bildschirm wird dunkel, Sterne erscheinen, Asteroiden schweben herum
2. Du landest auf einer Plattform mit blauer Neon-Kante
3. Oben rechts steht dein HUD (Guthaben, Multiplikator, Lagerbalken)
4. Vor dir schwebt ein blaues Pad: **„Erz-Extraktor I — GRATIS"**
5. Drauflaufen → der Extraktor wird gebaut
6. Alle 2,5 Sekunden fliegt ein Erz-Brocken zum Sammelkern hinten
7. Der Lagerbalken füllt sich
8. Zum Sammelkern laufen **oder** oben rechts auf **SAMMELN** drücken
9. Das nächste Kauf-Pad erscheint rechts

### Flotte testen

10. Links am Bildrand auf **FLOTTE** klicken — oder rechts vorne zur
    **RAUMWERFT** laufen und den Prompt auslösen
11. Ein Jäger kostet 2.500 CR. Kurz Credits sammeln, dann **BAUEN +1**
12. Unten im Fenster läuft der Countdown der Bauwarteschlange
13. Nach 6 Sekunden erscheint das Schiff — schau nach oben: Es schwebt
    im Orbit über deinem Plot und dreht sich langsam mit
14. Mehr als 12 Hangar-Plätze brauchst du für größere Schiffe:
    **HANGAR ERWEITERN**

In der **Output**-Konsole (Ansicht → Output) sollte stehen:
```
=== STELLAR DOMINION startet ===
[WorldBuilder] Weltraum-Umgebung aufgebaut
[PlotService] 6 Plots gebaut
[PlotService] bereit
[ButtonService] bereit
[DropperService] bereit
[FleetService] bereit
[HangarService] bereit
=== STELLAR DOMINION bereit ===
[Main] DeinName ist beigetreten
[PlotService] DeinName -> Plot 1
```

### Mit mehreren Spielern testen
**Test**-Reiter oben → **Clients and Servers** → 2 Players → **Start**.
Jeder Spieler bekommt automatisch einen eigenen Plot.

---

## 5. Häufige Fehler

| Fehlermeldung / Symptom | Ursache und Lösung |
|---|---|
| `Infinite yield possible on 'ReplicatedStorage:WaitForChild("GameConfig")'` | Modul fehlt oder heißt anders. Namen im Explorer prüfen. |
| `attempt to index nil with 'DataService'` | Der Ordner `Services` fehlt oder ist falsch geschrieben. |
| Nichts passiert beim Play | `Main` ist ein *ModuleScript* statt *Script*. Neu einfügen als Script. |
| `502: API Services rejected request` | Schritt 1 nicht gemacht (API Services aktivieren). |
| HUD erscheint nicht | `HudClient` liegt in `StarterGui` statt `StarterPlayerScripts`, oder ist ein *Script* statt *LocalScript*. |
| Keine Plots sichtbar | Du bist zu weit weg. Die Plots liegen im Raster um den Nullpunkt. |
| Spieler fällt ins Nichts | `Config.Plot.Hoehe` verändert, aber der Spawn nicht angepasst. |
| Werft-Fenster öffnet sich nicht | `UiKit` fehlt in `ReplicatedStorage`, oder `FleetGui` liegt nicht in `StarterPlayerScripts`. |
| Schiffe unsichtbar, obwohl gebaut | Nach oben schauen — der Orbit liegt 75 Studs über dem Plot (`Config.PlotPunkte.Orbit`). |
| „Die Werft ist ausgelastet" | Warteschlange voll (12 Aufträge). Kurz warten oder `FleetConfig.Allgemein.MaxWarteschlange` erhöhen. |

---

## 6. Balancing anpassen

Alles in `GameConfig`:

```lua
Config.DropperTypen.Erz.Betrag = 4        -- Credits pro Lieferung
Config.DropperTypen.Erz.Intervall = 2.5   -- Sekunden zwischen Lieferungen
Config.Lager.Startkapazitaet = 300        -- ab wann das Lager voll ist
Config.Multiplikatoren.BonusProPlanet = 0.5   -- +50 % pro Planet
Config.Plot.Anzahl = 6                    -- Spieler pro Server
```

Einen neuen Dropper hinzufügen? Einen Eintrag in `Config.Kaufbares` ergänzen:

```lua
{ Id = "Dropper_Erz_3", Name = "Erz-Extraktor III", Preis = 2000,
  Benoetigt = "Lager_1", Typ = "Dropper", DropperTyp = "Erz",
  Position = Vector3.new(-40, 0, -56), ButtonPos = Vector3.new(-24, 0, -56) },
```

Mehr ist nicht nötig — Button, Modell, Speicherung und Freischaltlogik
entstehen automatisch.

### Flotte balancen

Alles in `FleetConfig`:

```lua
FleetConfig.Allgemein.BasisKapazitaet = 12    -- Hangar-Plätze am Anfang
FleetConfig.Allgemein.MaxSichtbar = 24        -- Schiffe im Orbit (Performance!)
FleetConfig.Allgemein.MaxWarteschlange = 12   -- gleichzeitige Bauaufträge
```

Eine neue Schiffsklasse ist ein weiterer Eintrag in `FleetConfig.Klassen` —
Werft-Zeile, 3D-Modell und Validierung entstehen daraus automatisch. Auf
Handys lohnt es sich, `MaxSichtbar` auf 12–16 zu senken.

> ⚠️ Einmal veröffentlichte `Id`-Werte **nie** umbenennen. Die Ids stehen so in
> den Spielständen. Eine geänderte Id bedeutet für alle Spieler: Objekt weg,
> Geld weg.
