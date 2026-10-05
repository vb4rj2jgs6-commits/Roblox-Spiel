# STELLAR DOMINION

Ein Space-Tycoon für Roblox mit Eroberungs-Mechanik. Gebaut als Lernprojekt,
mit ausführlichen deutschen Kommentaren im Code.

## Spielidee

Du startest mit einer leeren Raumstation. Extraktoren fördern Rohstoffe und
liefern sie an deinen Sammelkern. Mit den Credits baust du die Station aus —
**und** eine Flotte. Die Flotte schickst du auf fremde Planeten. Jeder eroberte
Planet gibt dauerhaft **+50 % Einkommen**. Andere Spieler können dir Planeten
wieder abnehmen.

## Loslegen

**→ [`docs/EINBAU-ANLEITUNG.md`](docs/EINBAU-ANLEITUNG.md)**

Kurzfassung: Im Ordner `install/` liegen drei `.rbxmx`-Dateien. In Roblox Studio
Rechtsklick auf `ReplicatedStorage` → **Insert from File…** → fertig. Das
gleiche für `ServerScriptService` und `StarterPlayerScripts`. Du musst kein
einziges Script von Hand anlegen.

| Datei | Wofür |
|---|---|
| [`docs/UEBERGABE.md`](docs/UEBERGABE.md) | **Aktueller Stand, offene Aufgaben, Fallstricke** — hier anfangen |
| [`docs/EINBAU-ANLEITUNG.md`](docs/EINBAU-ANLEITUNG.md) | Einbau, Testen, Balancing, Fehlersuche |
| [`docs/ARCHITEKTUR.md`](docs/ARCHITEKTUR.md) | Bauplan: welches Script wo liegt und warum |

## Was drin ist

| System | Inhalt |
|---|---|
| **Basis-Tycoon** | 6 Plots, automatische Zuweisung, 4 Dropper-Typen, 16 kaufbare Ausbauten in einer Freischaltkette, Lager mit Kapazität |
| **Speichern** | DataStore mit Wiederholungslogik, Auto-Save, Save beim Verlassen und beim Server-Shutdown |
| **Flotte** | 5 Schiffsklassen, Werft, sequentielle Bauwarteschlange (läuft offline weiter), Hangar-Plätze, Flotte sichtbar im Orbit |
| **Eroberung** | 12 Planeten in 4 Typen, nachvollziehbare Kampfformel, Flottenverluste, Schutzschild, PvP-Rückeroberung |
| **Prestige** | Rebirth mit kumulativer Schwelle und dauerhaftem Bonus |
| **Technologie** | 5 Forschungszweige, bleiben beim Rebirth erhalten |
| **Ereignisse** | Meteoritenschauer, Piraten-Überfälle, Handelskonvois |
| **Verteidigung** | Orbitalgeschütze als sichtbare Türme auf dem Plot |
| **Monetarisierung** | 3 Gamepasses, 4 Entwicklerprodukte, `ProcessReceipt` fertig — Ids eintragen genügt |

Die Planetentypen greifen in alle anderen Systeme:

| Typ | Zusätzlich zu den +50 % |
|---|---|
| Rohstoffwelt | +25 % Einkommen |
| Energiewelt | −8 % Bauzeit in der Werft |
| Festungswelt | +30 % Verteidigung aller deiner Planeten |
| Handelswelt | +100 % Lagerkapazität |

## Projektstruktur

Die Ordner unter `src/` bilden die Roblox-Explorer-Hierarchie 1:1 ab.

```
src/
├── ReplicatedStorage/        → ReplicatedStorage        (Server + Client)
│   ├── GameConfig.lua            Balance Basis-Tycoon
│   ├── FleetConfig.lua           Balance Schiffe
│   ├── PlanetConfig.lua          Balance Planeten + Kampfformel
│   ├── TechConfig.lua            Technologie, Rebirth, Shop-Ids
│   ├── Util.lua · Signal.lua · UiKit.lua · Net.lua
├── ServerScriptService/      → ServerScriptService      (nur Server)
│   ├── Main.server.lua           ★ Einstiegspunkt Server
│   └── Services/                 13 Module, die ganze Spiellogik
└── StarterPlayerScripts/     → StarterPlayer > StarterPlayerScripts
    ├── HudClient.client.lua      HUD + Aktionsleiste
    ├── FleetGui.client.lua       Werft
    ├── PlanetGui.client.lua      Sternenkarte
    └── ImperiumGui.client.lua    Rebirth · Technologie · Shop

install/    ← fertige Installationsdateien (aus src/ erzeugt)
tools/      ← python3 tools/build_installer.py  erzeugt install/ neu
```

**Dateiendungen** (gängige Roblox-Konvention):

| Endung | Roblox-Typ | Startet von allein? |
|---|---|---|
| `.lua` | ModuleScript | nein — wird per `require()` geladen |
| `.server.lua` | Script | ja, auf dem Server |
| `.client.lua` | LocalScript | ja, beim Spieler |

## Technik

- **Sprache:** Luau
- **Exploit-Schutz:** Jede Geldänderung, jeder Kauf und jeder Angriff wird
  serverseitig geprüft. Client-Remotes übertragen nie Beträge oder Preise —
  nur Absichten („baue 5 Jäger", „greife P03 an").
- **Performance:** Keine unverankerten Parts, keine Physik-Dropper. Lieferungen
  und Angriffsflotten laufen über `TweenService`, Schatten sind aus, GUI-Updates
  sind gebündelt, die Orbit-Flotte dreht sich mit einem `PivotTo` pro Plot und
  Frame. Ausgelegt auf flüssiges Mobile-Gameplay.
- **Kunstrichtung:** Low-Poly, flache Farben, Neon-Akzente. Welt, Planeten,
  Schiffe und GUI entstehen komplett per Code — keine externen Assets.

Alle 26 Scripts sind mit dem offiziellen Luau-Compiler geprüft (`luau-compile`,
`luau-analyze`): keine Syntaxfehler, keine Analyse-Warnungen.
