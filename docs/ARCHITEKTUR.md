# Script-Architektur — STELLAR DOMINION

## Die drei Regeln, die alles zusammenhalten

1. **ModuleScripts rechnen, Scripts starten.**
   Es gibt genau *einen* Server-Einstiegspunkt (`Main`). Alles andere sind
   ModuleScripts, die von dort in fester Reihenfolge gestartet werden. Damit
   legst du selbst fest, was wann bereit ist — statt zu hoffen, dass Roblox die
   Scripts günstig sortiert.

2. **Der Server besitzt die Wahrheit.**
   Geld, Käufe, Flottenstärke, Kampfwürfel — alles ausschließlich im
   `ServerScriptService`, den Clients gar nicht lesen können. Ein Exploiter
   kann höchstens seine *eigene* Anzeige verfälschen.

3. **Zahlen gehören in die Config, nicht in den Code.**
   Vier Config-Module in `ReplicatedStorage`. Balancing = eine Datei ändern.

## Warum welcher Ordner?

| Ordner | Sichtbar für | Wofür wir ihn nutzen |
|---|---|---|
| `ServerScriptService` | **nur Server** | Alle Spiellogik & Spielstände |
| `ReplicatedStorage` | Server + Client | Configs, Helfer, RemoteEvents |
| `StarterPlayerScripts` | Client | LocalScripts, laufen einmal pro Spieler und überleben den Respawn |
| `StarterGui` | Client | bleibt leer — GUI entsteht per Code |
| `Workspace` | alle | die sichtbare Welt, komplett zur Laufzeit erzeugt |

---

## Der Aufbau

```
ReplicatedStorage
├── GameConfig    Plots, Dropper, kaufbare Ausbauten, Multiplikatoren
├── FleetConfig   Schiffsklassen, Hangar-Regeln
├── PlanetConfig  Planetentypen, Planetenliste, Kampfformel
├── TechConfig    Technologien, Rebirth, Ereignisse, Gamepass-/Produkt-Ids
├── Util          Zahlen formatieren, Parts bauen, Tabellen kopieren
├── Signal        selbstgebautes Event-System (siehe unten)
├── UiKit         Farben, Knöpfe, Fenster-Rahmen, Aktionsleiste
└── Net           legt alle RemoteEvents automatisch an
    └── Remotes   ← wird zur Laufzeit erzeugt, nicht anlegen!

ServerScriptService
├── Main (Script)         ★ Einstiegspunkt, startet alles in fester Reihenfolge
└── Services
    ├── DataService          DataStore, Auto-Save, BindToClose
    ├── CurrencyService      die EINZIGE Stelle, die Geld ändert
    ├── WorldBuilder         Licht, Sternenhimmel, Asteroiden
    ├── PlotService          Plots bauen, zuweisen, freigeben, bebauen
    ├── ButtonService        Kauf-Pads + Kauf-Validierung
    ├── DropperService       passiver Geldfluss
    ├── FleetService         Schiffe ordern, Bauwarteschlange, Hangar
    ├── HangarService        Flotte sichtbar im Orbit
    ├── PlanetService        Planeten bauen, Besitz, Verteidigung
    ├── CombatService        Angriffe, Kampfformel, Verluste
    ├── ImperiumService      Technologie, Rebirth, Orbitalgeschütze
    ├── MonetizationService  Gamepasses, ProcessReceipt
    └── EventService         Zufallsereignisse

StarterPlayer > StarterPlayerScripts
├── HudClient     HUD oben rechts + Aktionsleiste links
├── FleetGui      Werft
├── PlanetGui     Sternenkarte
└── ImperiumGui   Rebirth · Technologie · Shop
```

### Startreihenfolge in `Main`

```
Net → DataService → CurrencyService → WorldBuilder → PlotService
    → ButtonService → DropperService → FleetService → HangarService
    → PlanetService → CombatService → MonetizationService
    → ImperiumService → EventService
```

Jeder Schritt setzt nur voraus, was davor schon lief. `HangarService` braucht
Plots *und* Flotte, `CombatService` braucht Planeten *und* Flotte.

### Beim Beitritt eines Spielers

```
DataService:Laden           Spielstand holen (oder neu anlegen)
CurrencyService:Leaderstats leaderstats-Ordner
PlotService:Zuweisen        freien Plot suchen, Gekauftes wieder aufbauen
FleetService:Vorbereiten    offline fertig gewordene Schiffe nachtragen
PlanetService:Vorbereiten   gespeicherte Planeten zurückgeben, soweit frei
MonetizationService         Gamepasses abfragen (im Hintergrund)
ImperiumService:Vorbereiten Orbitalgeschütze aufstellen, Stand senden
```

---

## Wie die Systeme zusammenhängen

Der Einkommens-Multiplikator in `CurrencyService:GetMultiplikator()` ist der
Knotenpunkt, an dem fast alles zusammenläuft:

```
(1 + Planeten × 0,5 + Rohstoffwelt-Bonus + Rebirths × 0,25)
  × Gamepass „Doppeltes Einkommen"
  × laufendes Zufallsereignis
```

Die übrigen Planetentypen wirken woanders — jeweils genau an einer Stelle:

| Typ | Wirkt in |
|---|---|
| Rohstoffwelt | `CurrencyService:GetMultiplikator` |
| Energiewelt | `FleetService:GetBauzeitMultiplikator` |
| Festungswelt | `PlanetService:GetVerteidigung` |
| Handelswelt | `CurrencyService:GetLagerKapazitaet` |

### Die Kampfformel

Sie steht in `PlanetConfig` — also in `ReplicatedStorage`, wo **Server und
Client** sie lesen. Beide rechnen darum garantiert dieselbe Zahl aus: Der
Client zeigt die Siegchance an, der Server würfelt damit.

```
Siegchance = Stärke / (Stärke + Verteidigung)      gedeckelt auf 5 % … 95 %
```

Verteidigung eines von einem Spieler gehaltenen Planeten:

```
Basiswert × (1 + Festungswelten × 0,3 + Schildmatrix × 0,2)
          + 20 % der Flotten-Verteidigung des Besitzers
```

---

## Zwei Entscheidungen, die man sonst schmerzhaft lernt

### Warum ein eigenes `Signal` statt `BindableEvent`?
Ein `BindableEvent` **kopiert jede Tabelle**, die man durchschickt. Der
Empfänger bekäme eine Kopie der Plot-Tabelle — neu gekaufte Dropper würden in
dieser Kopie landen und nie Geld produzieren. Ein reines Lua-Signal reicht
Werte 1:1 weiter.

### Warum Planetenbesitz pro Server gilt
Roblox startet für je ~6 Spieler einen eigenen Server. Gemeinsamer Besitz über
alle Server hinweg bräuchte einen globalen DataStore und würde ständig
Konflikte erzeugen. Stattdessen: Der Spieler speichert seine Planeten, und beim
Beitreten bekommt er jeden zurück, **der in diesem Server noch frei ist**. In
einem leeren Server hast du deine Planeten sofort wieder.

---

## Client-Server-Kommunikation

Alle RemoteEvents erzeugt `Net` automatisch. Du legst im Explorer **nichts** an.
Neue Remotes trägst du in `Net.lua` in die Liste `EVENT_NAMEN` ein — fertig.

| Remote | Richtung | Inhalt |
|---|---|---|
| `DatenUpdate` | S→C | Geld, Lager, Multiplikator, Rebirths, laufendes Ereignis |
| `FlotteUpdate` | S→C | Flotte, Bauwarteschlange, Hangar, Stärke |
| `PlanetUpdate` | S→C | Besitz und Verteidigung aller Planeten |
| `ImperiumUpdate` | S→C | Technologien, Rebirth-Stand, Shop |
| `KampfErgebnis` | S→C | Start und Ausgang eines Angriffs |
| `Benachrichtigung` | S→C | Toast-Meldung + Farbe |
| `KaufBestaetigt` | S→C | Feedback nach einem Kauf |
| `DatenAnfrage` · `FlotteAnfrage` · `PlanetAnfrage` · `ImperiumAnfrage` | C→S | „schick mir den aktuellen Stand" |
| `SammelAnfrage` | C→S | leer — der Server prüft den Abstand zum Sammelkern |
| `SchiffBauen` | C→S | Klassenname + Anzahl — **kein Preis** |
| `HangarErweitern` | C→S | leer |
| `AngriffStarten` | C→S | nur die Planeten-Id |
| `TechKaufen` | C→S | nur die Technologie-Id |
| `RebirthStarten` | C→S | leer |

**Sicherheitsprinzip:** Ein Client-Remote enthält nie einen Betrag und nie einen
Preis — nur die *Absicht*. Was das kostet und ob es erlaubt ist, entscheidet
ausschließlich der Server.

Die Validierung folgt überall demselben Muster (Beispiel `SchiffBauen`):

1. Ist der Parameter überhaupt vom richtigen Typ?
2. Gibt es das Ding, das er meint?
3. Ist die Zahl eine sinnvolle ganze Zahl? (inkl. `NaN`-Abfang)
4. Ist es für diesen Spieler freigeschaltet?
5. Sind die Grenzen eingehalten (Warteschlange, Hangar, Cooldown)?
6. Erst dann: abbuchen.

---

## GUI-Aufbau

`HudClient` baut die **Aktionsleiste** am linken Bildrand — bewusst links auf
halber Höhe: Unten links sitzt auf dem Handy der Bewegungs-Stick, unten rechts
der Sprungknopf.

Jedes Fenster hängt sich mit einer Zeile einen Knopf hinein und baut sein
Fenster mit dem gemeinsamen Rahmen aus `UiKit`:

```lua
local fenster = UiKit.Fenster({ Titel = "STERNENKARTE", Name = "PlanetGui" })
local knopf = UiKit.LeistenKnopf("PLANETEN", 20)   -- 20 = Sortier-Reihenfolge
knopf.Activated:Connect(function() fenster:Umschalten() end)
```

Die vier Client-Scripts kennen sich gegenseitig nicht. Ein fünftes Fenster wäre
eine neue Datei — kein Eingriff in die bestehenden.

---

## Wo du was änderst

| Du willst … | Datei |
|---|---|
| Preise, Einkommen, Plot-Anzahl | `GameConfig` |
| Schiffe, Hangar | `FleetConfig` |
| Planeten, Kampfbalance | `PlanetConfig` |
| Technologien, Rebirth, Ereignisse, Shop-Ids | `TechConfig` |
| Farben und GUI-Stil | `UiKit.Farben` |
| Ein neues Fenster | neues LocalScript in `StarterPlayerScripts` |
| Ein neues Server-System | neues ModuleScript in `Services` + zwei Zeilen in `Main` |
