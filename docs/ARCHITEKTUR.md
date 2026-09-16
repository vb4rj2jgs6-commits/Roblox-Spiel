# Script-Architektur — STELLAR DOMINION

Diese Datei ist der Bauplan für das ganze Spiel. Sie beschreibt **alle**
geplanten Scripts, auch die, die noch nicht existieren. So siehst du jederzeit,
wohin ein neues Feature gehört.

---

## Die drei Regeln, die alles zusammenhalten

1. **ModuleScripts rechnen, Scripts starten.**
   Es gibt genau *einen* Server-Einstiegspunkt (`Main`) und *einen* Client-
   Einstiegspunkt (`HudClient`). Alles andere sind ModuleScripts, die von dort
   gestartet werden. Damit legst du die Startreihenfolge selbst fest.

2. **Der Server besitzt die Wahrheit.**
   Geld, Käufe, Flottenstärke, Eroberungen — alles wird ausschließlich im
   `ServerScriptService` berechnet. Der Client bekommt nur fertige Zahlen zum
   Anzeigen. Ein Exploiter kann damit höchstens seine *eigene* Anzeige
   verfälschen, nie seinen echten Kontostand.

3. **Zahlen gehören in die Config, nicht in den Code.**
   Preise, Boni, Intervalle stehen in `ReplicatedStorage > GameConfig`.
   Balancing = eine Datei ändern.

---

## Warum welcher Ordner?

| Ordner | Sichtbar für | Wofür wir ihn nutzen |
|---|---|---|
| `ServerScriptService` | **nur Server** | Alle Spiellogik & Spielstände. Clients können hier nichts lesen. |
| `ReplicatedStorage` | Server + Client | Config, Hilfsfunktionen, RemoteEvents — alles, was beide Seiten brauchen. |
| `ServerStorage` | **nur Server** | Vorlagen/Modelle, die der Server klont (z. B. Schiffsmodelle). |
| `StarterPlayer > StarterPlayerScripts` | Client | LocalScripts, die einmal pro Spieler laufen und den Respawn überleben. |
| `StarterGui` | Client | Fertig gebaute GUIs. Wir bauen die GUI per Code — dieser Ordner bleibt leer. |
| `Workspace` | alle | Die sichtbare Welt. Wird komplett zur Laufzeit erzeugt. |

---

## Aktueller Stand — Schritt 1 (Basis-Tycoon) + Schritt 2 (Flotte) ✅

```
ReplicatedStorage
├── GameConfig      (ModuleScript)  Balance-Werte Basis-Tycoon.
├── FleetConfig     (ModuleScript)  Balance-Werte Schiffsklassen + Hangar.
├── Util            (ModuleScript)  Zahlen formatieren, Parts bauen, Tabellen kopieren.
├── Signal          (ModuleScript)  Selbstgebautes Event-System (siehe unten).
├── UiKit           (ModuleScript)  Farben, Knöpfe, Aktionsleiste — gemeinsamer GUI-Stil.
└── Net             (ModuleScript)  Legt RemoteEvents automatisch an.
    └── Remotes     (Folder)        ← wird zur Laufzeit erzeugt, nicht anlegen!

ServerScriptService
├── Main            (Script)        ★ Einstiegspunkt. Startet alles in fester Reihenfolge.
└── Services        (Folder)
    ├── DataService     DataStore laden/speichern, Auto-Save, BindToClose.
    ├── CurrencyService Die EINZIGE Stelle, die Geld ändern darf. Multiplikatoren.
    ├── WorldBuilder    Licht, Sternenhimmel, Asteroiden.
    ├── PlotService     Plots bauen, zuweisen, freigeben, Objekte errichten.
    ├── ButtonService   Kauf-Pads + komplette Kauf-Validierung.
    ├── DropperService  Passiver Geldfluss (Lieferungen → Lager).
    ├── FleetService    Schiffe ordern, Bauwarteschlange, Hangar, Flottenstärke.
    └── HangarService   Die Flotte sichtbar im Orbit über dem Plot.

StarterPlayer > StarterPlayerScripts
├── HudClient       (LocalScript)   ★ HUD oben rechts + Aktionsleiste links.
└── FleetGui        (LocalScript)   Werft-Fenster.
```

### Datenfluss in einem Satz
`DropperService` erzeugt Wert → `CurrencyService` legt ihn ins Lager →
`FleetService` gibt ihn für Schiffe wieder aus → `DataService` speichert alles →
`HudClient` / `FleetGui` zeigen es an.

### Wie GUI-Fenster zusammenarbeiten
`HudClient` baut die **Aktionsleiste** am linken Bildrand (bewusst links Mitte:
unten links sitzt auf dem Handy der Bewegungs-Stick, unten rechts der
Sprungknopf). Jedes weitere Fenster hängt sich dort mit einer Zeile einen Knopf
hinein:

```lua
local knopf = UiKit.LeistenKnopf("FLOTTE", 10)   -- 10 = Sortier-Reihenfolge
```

`HudClient` kennt die Werft nicht und die Werft kennt das HUD nicht. Schritt 3
bekommt genauso ein eigenes Script und einen eigenen Knopf.

### Warum ein eigenes `Signal` statt `BindableEvent`?
Ein `BindableEvent` **kopiert jede Tabelle**, die man durchschickt. Der
Empfänger bekäme also eine Kopie der Plot-Tabelle — neu gekaufte Dropper
würden in dieser Kopie landen und nie Geld produzieren. Das ist ein klassischer,
sehr schwer zu findender Fehler. Unser `Signal` reicht Werte 1:1 weiter.

---

## Geplante Erweiterungen

Jeder Schritt fügt nur Dateien hinzu. Bestehende Scripts werden höchstens um
wenige Zeilen ergänzt — das ist der Sinn der Modularisierung.

### Schritt 3 — Planeten-Eroberung
```
ReplicatedStorage
└── PlanetConfig    Planetentypen, Verteidigung, Bonus-Art, Positionen.

ServerScriptService > Services
├── PlanetService   Planeten bauen, Besitz verwalten, Farbe/Name setzen.
└── CombatService   Kampfformel, Angriffs-Cooldown, Rückeroberung (PvP).

StarterPlayerScripts
└── PlanetGui       Planeten-Info, Angriffsknopf, Siegchance-Vorschau.
```
Neue Remotes: `AngriffStarten`, `PlanetUpdate`, `KampfErgebnis`.
Der `+50 %`-Bonus ist in `CurrencyService:GetMultiplikator()` **schon eingebaut**
und liest `daten.Planeten` — Schritt 3 muss diese Liste nur noch füllen.

Für den Kampf liefert der `FleetService` bereits alles:
`FleetService:GetStaerke(spieler)` (Angriff) und
`FleetService:GetVerteidigung(spieler)` (wenn dich jemand angreift).

### Schritt 4 — Prestige / Rebirth
```
ServerScriptService > Services
└── RebirthService  Setzt Basis zurück, erhöht daten.Rebirths, prüft Voraussetzungen.

StarterPlayerScripts
└── RebirthGui      Bestätigungsdialog mit Vorher/Nachher-Vergleich.
```
Auch hier gilt: Der Rebirth-Multiplikator steckt bereits in
`CurrencyService:GetMultiplikator()`.

### Schritt 5 — Zusatz-Features
```
ServerScriptService > Services
├── EventService    Zufallsereignisse (Meteoritenschauer, Piraten-Überfälle).
├── DefenseService  Verteidigungstürme für Basis und eroberte Planeten.
└── TechService     Technologie-Baum (Angriff / Tempo / Kapazität).
```

### Schritt 6 — Monetarisierung
```
ServerScriptService > Services
└── MonetizationService  Gamepasses + Entwicklerprodukte, ProcessReceipt.
```
Die Gamepass-Abfrage ist in `CurrencyService` und `DropperService` bereits
vorgesehen (`daten.Gamepasses.DoppeltesEinkommen`, `.AutoCollect`).

---

## Client-Server-Kommunikation

Alle RemoteEvents werden von `Net` automatisch erzeugt. Du legst im Explorer
**nichts** von Hand an. Neue Remotes trägst du in `Net.lua` in die Liste
`EVENT_NAMEN` ein — fertig.

| Remote | Richtung | Inhalt |
|---|---|---|
| `DatenUpdate` | Server → Client | Geld, Lager, Kapazität, Multiplikator, Rebirths |
| `Benachrichtigung` | Server → Client | Toast-Meldung + Farbe |
| `KaufBestaetigt` | Server → Client | Feedback nach erfolgreichem Kauf |
| `FlotteUpdate` | Server → Client | Flotte, Bauwarteschlange, Hangar, Stärke |
| `DatenAnfrage` | Client → Server | „Schick mir bitte meinen Stand" |
| `SammelAnfrage` | Client → Server | „Ich möchte mein Lager leeren" |
| `FlotteAnfrage` | Client → Server | „Schick mir bitte meinen Flottenstand" |
| `SchiffBauen` | Client → Server | Klassenname + Anzahl — **kein Preis!** |
| `HangarErweitern` | Client → Server | „Ich möchte die nächste Hangar-Stufe" |

**Sicherheitsprinzip:** Ein Client-Remote enthält nie einen Betrag und nie einen
Preis — nur die *Absicht*. Was das kostet und ob es erlaubt ist, entscheidet
ausschließlich der Server.
