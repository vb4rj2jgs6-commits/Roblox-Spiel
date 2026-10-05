# Übergabe — STELLAR DOMINION

> **An den Nachfolger:** Dieses Dokument ist der einzige Einstiegspunkt, den du
> brauchst. Lies Abschnitt 1–3, dann weißt du alles Wichtige. Abschnitt 6 ist
> deine Aufgabenliste.
>
> **Stand:** 2026-10-05 · Branch `claude/space-tycoon-roblox-2hn7ns` ·
> Repo `vb4rj2jgs6-commits/Roblox-Spiel`

---

## 1. Was das ist und wo es steht

Ein **Space-Tycoon für Roblox** in Luau, komplett per Code erzeugt — Welt,
Planeten, Schiffe und GUI entstehen zur Laufzeit. Es gibt **keine** von Hand
gebauten Modelle, keine externen Assets.

**Der Nutzer ist Anfänger** in Roblox Studio und Lua. Das prägt alles:

- Alle Code-Kommentare auf **Deutsch**, und zwar erklärend, nicht nur beschreibend
- Bei jedem Script steht im Kopf, **in welchen Explorer-Ordner es gehört und warum**
- Variablen- und Funktionsnamen auf Deutsch (`baueDropper`, `Siegchance`, `plot.Besitzer`)
- Alle Balance-Zahlen in Config-Modulen, damit er nie im Logik-Code suchen muss

```
src/
├── ReplicatedStorage/        → ReplicatedStorage        (Server + Client)
│   ├── GameConfig.lua            Basis-Tycoon + Welt-Deko
│   ├── FleetConfig.lua           Schiffsklassen, Hangar
│   ├── PlanetConfig.lua          Planeten + Kampfformel
│   ├── TechConfig.lua            Technologie, Rebirth, Ereignisse, Shop-Ids
│   ├── Util.lua                  FormatGeld, NeuerPart, TiefeKopie
│   ├── Signal.lua                Event-System (NICHT BindableEvent, s. Abschnitt 5)
│   ├── UiKit.lua                 Farben, Knöpfe, Fenster, Aktionsleiste
│   └── Net.lua                   erzeugt alle RemoteEvents automatisch
├── ServerScriptService/      → ServerScriptService      (nur Server)
│   ├── Main.server.lua           ★ einziger Server-Einstiegspunkt
│   └── Services/                 13 ModuleScripts, die ganze Spiellogik
└── StarterPlayerScripts/     → StarterPlayer > StarterPlayerScripts
    ├── HudClient.client.lua      HUD + Aktionsleiste
    ├── FleetGui.client.lua       Werft
    ├── PlanetGui.client.lua      Sternenkarte
    └── ImperiumGui.client.lua    Rebirth · Technologie · Shop

install/    fertige Installationsdateien, aus src/ erzeugt
tools/      python3 tools/build_installer.py   erzeugt install/ neu
docs/       ARCHITEKTUR.md · EINBAU-ANLEITUNG.md · dieses Dokument
```

Endungen: `.lua` = ModuleScript · `.server.lua` = Script · `.client.lua` = LocalScript

---

## 2. Warum es diese Übergabe gibt

Die Vorgänger-Session lief **in einem Cloud-Container** auf claude.ai/code. Das
Roblox-Studio-Plugin spricht aber über `localhost` mit einer Claude-Instanz auf
dem **Rechner des Nutzers**. Ein Cloud-Container kommt da nicht hin — die
Verbindung war dort also nicht nutzbar, obwohl der Nutzer sie eingerichtet hatte.

**Du hast die Verbindung.** Damit kannst du, was der Vorgänger nicht konnte:
direkt im Studio arbeiten, das Ergebnis ansehen und korrigieren.

---

## 3. Fertig und funktionsfähig

Alles davon ist mit dem offiziellen Luau-Compiler geprüft (`luau-compile`,
`luau-analyze`): **26/26 Dateien ohne Syntaxfehler, keine Analyse-Befunde.**

| System | Inhalt |
|---|---|
| **Basis-Tycoon** | 6 Stationen, automatische Zuweisung, 4 Dropper-Typen, 16 kaufbare Ausbauten in einer Freischaltkette, Lager mit Kapazität |
| **Speichern** | DataStore mit Wiederholungslogik, Auto-Save (120 s), Save beim Verlassen und bei `BindToClose` |
| **Flotte** | 5 Schiffsklassen, Werft, sequentielle Bauwarteschlange (läuft offline weiter, weil absolute Zeitstempel gespeichert werden), Hangar-Plätze, Flotte sichtbar im Orbit |
| **Eroberung** | 12 Planeten in 4 Typen, Kampfformel, Flottenverluste, Reisezeit mit Flug-Animation, Cooldown, Schutzschild, PvP-Rückeroberung |
| **Prestige** | Rebirth mit kumulativer Schwelle auf den Gesamtverdienst |
| **Technologie** | 5 Forschungszweige, bleiben beim Rebirth erhalten |
| **Ereignisse** | Meteoritenschauer, Piraten-Überfälle, Handelskonvois |
| **Verteidigung** | Orbitalgeschütze als sichtbare Türme auf der Station |
| **Monetarisierung** | 3 Gamepasses, 4 Produkte, `ProcessReceipt` fertig. **Alle Ids stehen auf 0** → Shop zeigt „BALD VERFÜGBAR", Server überspringt sie, Spiel läuft vollständig ohne |

### Kernschleife in einem Satz
`DropperService` erzeugt Wert → `CurrencyService` legt ihn ins Lager →
`FleetService` gibt ihn für Schiffe aus → `CombatService` erobert damit Planeten
→ die erhöhen über `CurrencyService:GetMultiplikator()` wieder den Wert.

### Der Multiplikator ist der Knotenpunkt
```
(1 + Planeten × 0,5 + Rohstoffwelt-Bonus + Rebirths × 0,25)
  × Gamepass „Doppeltes Einkommen"
  × laufendes Zufallsereignis
```
Die anderen Planetentypen wirken je an genau einer Stelle:

| Typ | Wirkt in |
|---|---|
| Rohstoffwelt | `CurrencyService:GetMultiplikator` |
| Energiewelt | `FleetService:GetBauzeitMultiplikator` |
| Festungswelt | `PlanetService:GetVerteidigung` |
| Handelswelt | `CurrencyService:GetLagerKapazitaet` |

---

## 4. Die Map — hier wurde zuletzt gearbeitet

Der Nutzer hat gebeten: *„baue eine schöne Map"*. Die alte Map war ein 3×2-Gitter
flacher Platten im Sternenhimmel — zweckmäßig, aber kein Ort.

### Was neu gebaut ist (fertig, kompiliert)

- **Ring-Anordnung**: Die 6 Stationen stehen im Kreis mit Radius 250 um die
  Kartenmitte, jede nach innen ausgerichtet. Umschaltbar über
  `Config.Plot.Anordnung = "Ring"` oder `"Raster"` (altes Verhalten).
- **Zentralstation** in der Mitte: begehbare Ringplattform (Radius 90), Turm,
  leuchtende Kuppel mit dem Spieltitel, 6 Dockkragen.
- **Begehbare Stege** von jeder Station zur Zentralstation. Dadurch ist die
  Karte ein zusammenhängender Ort und man sieht seine Nachbarn.
- **Schönere Plattformen**: Bodenplatten mit Fugen, dunkle Arbeitszonen (links
  Produktion, rechts Ausbau), Unterbau aus 4 geneigten Streben mit leuchtendem
  Reaktorkern darunter, blinkende Positionslichter an den 4 Ecken.
- **Sammelkern** mit 3 geneigten Trägerbögen statt nacktem Pad.
- **Asteroidengürtel** und **Zentralstern** lesen jetzt `Config.Welt`.

Geometrie geprüft (reine Rechnung, nicht im Spiel gesehen):

```
Plot-Innenkante   Radius 190
Stationsrand      Radius  90
Steglänge             100 Studs   → trifft beide Kanten genau
Bogen zwischen Plots  262 Studs   → 142 Studs Lücke, keine Überlappung
Max. Plot-Radius      310         → Asteroiden ab 900, kein Konflikt
```

### ⚠️ Der Umbau, den du kennen musst

Gedrehte Stationen brauchen **Orientierung**, nicht nur Position. Vorher reichte
`CFrame.new(position)`, weil alle Plots gleich ausgerichtet waren. Jetzt nicht mehr.

Dafür gibt es zwei Helfer in `PlotService`:

```lua
PlotService:ZuWelt(plot, lokalerVektor)   -- nur Position
PlotService:ZuWeltCF(plot, lokalerCFrame) -- Position UND Drehung
```

**Regel, die du einhalten musst:** Alles mit erkennbarer Vorderseite oder rechten
Winkeln wird mit `ZuWeltCF` gesetzt. Nur Kugeln und zufällig gedrehtes Zeug
dürfen `ZuWelt` benutzen. Sonst stehen eckige Teile schief auf der Plattform.

18 Stellen wurden darauf umgestellt, in `PlotService`, `ButtonService`,
`ImperiumService` und `HangarService`. Wenn du neue Teile auf die Station baust:
`ZuWeltCF` nehmen.

Zwei Stellen brauchten zusätzlich Sonderbehandlung:

- `ImperiumService`, Schwenk-Schleife der Geschütze: multipliziert jetzt
  `plot.Ursprung.Rotation` mit, sonst schwenken die Läufe um eine feste
  Weltachse und stehen quer zum Turm.
- `PlotService:ZumPlotTeleportieren`: leitet die Blickrichtung aus
  `ziel.LookVector` ab statt aus hart kodiertem `-Z`.

---

## 5. Fünf Dinge, die man leicht falsch macht

1. **Niemals `BindableEvent` für Tabellen.** Es *kopiert* jede Tabelle. Der
   Empfänger bekäme eine Kopie der Plot-Tabelle — neu gekaufte Dropper landeten
   darin und produzierten nie Geld. Ein sehr schwer zu findender Fehler. Deshalb
   gibt es `ReplicatedStorage/Signal.lua`. Benutze das.

2. **Keine Umlaute in Variablennamen.** Luau erlaubt nur ASCII in Bezeichnern.
   In Strings und Kommentaren sind Umlaute völlig in Ordnung. Hat schon einmal
   einen Compile-Fehler gekostet (`auslöser` → `ausloeser`).

3. **Geld ändert sich nur über `CurrencyService`.** Kein anderes Script darf
   `daten.Geld = ...` schreiben. Immer `:Hinzufuegen()` / `:Abbuchen()`.
   `:Abbuchen()` prüft den Kontostand selbst und gibt `false` zurück.

4. **`Id`-Werte in den Configs nie umbenennen.** Sie stehen so in den
   Spielständen. Eine geänderte Id heißt für alle Spieler: Objekt weg, Geld weg.

5. **Client-Remotes enthalten nie Beträge oder Preise.** Nur Absichten
   („baue 5 Jäger", „greife P03 an"). Die Validierung folgt überall demselben
   Muster: Typ prüfen → existiert das? → ist die Zahl brauchbar (inkl. `NaN`) →
   freigeschaltet? → Grenzen eingehalten? → *erst dann* abbuchen.

---

## 6. Deine Aufgabenliste

### Aufgabe 0 — Ins Studio bringen und anschauen *(zuerst!)*

Der Vorgänger konnte das Spiel **nie laufen sehen**. Alles ist nur statisch
geprüft. Rechne damit, dass beim ersten Start Kleinigkeiten auffallen.

Im Ordner `install/` liegen fertige Dateien:

| Rechtsklick auf … | → | Datei |
|---|---|---|
| `ReplicatedStorage` | **Insert from File…** | `ReplicatedStorage.rbxmx` |
| `ServerScriptService` | **Insert from File…** | `ServerScriptService.rbxmx` |
| `StarterPlayer` → `StarterPlayerScripts` | **Insert from File…** | `StarterPlayerScripts.rbxmx` |

Alternativ `install/INSTALLER.lua` komplett in die **Command Bar** (View →
Command Bar) einfügen — ein Lauf legt alles an, ein zweiter überschreibt.
Achtung: 265 KB, manche Studio-Versionen kürzen so große Einfügungen.

Mit Studio-Verbindung kannst du die Scripts natürlich auch direkt anlegen.
**Wenn du das tust: Quelle bleibt `src/`.** Änderungen, die du nur im Studio
machst, sind beim nächsten Mal weg. Richtige Reihenfolge:
`src/` ändern → `python3 tools/build_installer.py` → ins Studio.

Vorher einmalig: **File → Game Settings → Security → „Enable Studio Access to
API Services"**, sonst kann das Spiel nicht speichern.

Erwartete Konsolenausgabe beim Play:
```
=== STELLAR DOMINION startet ===
[WorldBuilder] Weltraum-Umgebung aufgebaut
[PlotService] 6 Plots gebaut            ... bis
[EventService] bereit
=== STELLAR DOMINION bereit ===
[Main] <Name> ist beigetreten
[PlotService] <Name> -> Plot 1
```

**Prüf-Durchgang:**
1. Stehst du auf einer Plattform mit blauer Neon-Kante? Sind Nachbar-Stationen
   im Ring zu sehen, mit Stegen zur leuchtenden Zentralstation?
2. Sind alle eckigen Teile **gerade** zur Plattform? (Das ist der Orientierungs-
   Umbau aus Abschnitt 4 — hier würde ein Fehler sofort auffallen.)
3. Kannst du über den Steg zur Zentralstation laufen?
4. Gratis-Pad „Erz-Extraktor I" → Lieferungen fliegen zum Sammelkern → SAMMELN
5. Links: **FLOTTE** → Jäger bauen (2.500 CR) → erscheint er im Orbit darüber?
6. **PLANETEN** → Siegchance plausibel? Angriff → Flug → Ergebnis
7. Nach Eroberung: Ring des Planeten in deiner Farbe, Multiplikator oben rechts
   springt von x1.00 auf x1.50
8. **IMPERIUM** → drei Reiter, Technologie kaufbar

### Aufgabe 1 — Map fertig dekorieren

Diese vier Blöcke stehen schon in `Config.Welt`, **liest aber noch niemand**.
Sie sind im Code mit `-- NOCH NICHT GEBAUT` markiert. Baue sie in
`WorldBuilder.lua` analog zu `baueZentralstation`:

| Block | Gedacht als |
|---|---|
| `Nebelwolken` | 10 sehr transparente, farbige Riesenkugeln weit außen — gibt dem Himmel Tiefe, kostet fast nichts |
| `Gasriese` | Großer Planet mit Ring als Landmarke am Horizont |
| `Wrack` | Ein Schiffswrack als Fundstück/Blickfang |
| `Komet` | Kugel auf Kreisbahn mit Schweif aus `Schweiflaenge` Teilen, `Dauer` Sekunden pro Runde |

Wichtig: verankert, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`,
`CastShadow = false` — so wie alles andere auch (`Util.NeuerPart` setzt das meiste).

### Aufgabe 2 — Balancing am laufenden Spiel

Der Vorgänger vermutet, dass der Sprung zum ersten Jäger (2.500 CR) sich zäh
anfühlt. Das lässt sich nur im Spiel beurteilen. Stellschrauben:
`GameConfig.DropperTypen.Erz.Betrag` / `.Intervall`, `FleetConfig` Preise.

### Aufgabe 3 — Auf Handy prüfen

`FleetConfig.Allgemein.MaxSichtbar = 24` ist für Handys evtl. zu hoch, 12–16
wäre sicherer. Auch die Aktionsleiste prüfen: Sie sitzt **links auf halber
Höhe**, weil unten links der Bewegungs-Stick und unten rechts der Sprungknopf
sitzen.

### Später, kein Zeitdruck
- Gamepass-/Produkt-Ids im Creator Dashboard anlegen und in `TechConfig` eintragen
- Session Locking fürs Speichern (z. B. ProfileService), falls das Spiel größer wird
- Planetenbesitz gilt **pro Server** (bewusste Entscheidung, siehe `PlanetService`-Kopf)

---

## 7. Werkzeuge

```bash
# Alles prüfen (der Vorgänger hat das nach jeder Änderung gemacht)
for f in $(find src -name "*.lua"); do luau-compile --null "$f"; done
luau-analyze src/ReplicatedStorage/*.lua src/ServerScriptService/**/*.lua \
             src/StarterPlayerScripts/*.lua

# Installationsdateien nach jeder Änderung an src/ neu erzeugen
python3 tools/build_installer.py
```

`luau-compile` / `luau-analyze` gibt es als Fertig-Binary bei
`github.com/luau-lang/luau/releases` (`luau-ubuntu.zip` / passende Plattform).
Das hat echte Fehler gefunden, die beim Lesen nicht auffielen — lohnt sich.

Der Generator prüft sich selbst: Er holt die eingebetteten Quelltexte wieder
heraus und vergleicht sie Byte für Byte mit `src/`. Das hat schon einen Bug
gefangen, bei dem eine XML-Einrückung die Lua-Quelltexte mitverändert hätte
(13 kaputte Services).

---

## 8. Ehrliche Lücken

- **Nichts davon ist im laufenden Spiel getestet.** Nur `luau-compile` und
  `luau-analyze`, plus Durchlesen und Nachrechnen. Das ist der größte
  Unterschied zwischen dem Vorgänger und dir.
- Die Ring-Geometrie ist **gerechnet, nicht gesehen**. Die Zahlen passen (s.
  Abschnitt 4), aber der Höhen-Eindruck, die Laufwege und ob die Stege sich
  gut anfühlen — das weiß erst, wer es startet.
- Das Balancing ist eine Schätzung ohne Spieltest.
- Der Shop ist ohne Ids nicht prüfbar.
