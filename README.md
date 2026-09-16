# STELLAR DOMINION

Ein Space-Tycoon für Roblox mit Eroberungs-Mechanik. Gebaut als Lernprojekt,
Schritt für Schritt, mit ausführlichen deutschen Kommentaren im Code.

## Spielidee

Du startest mit einer leeren Raumstation. Extraktoren fördern Rohstoffe und
liefern sie an deinen Sammelkern. Mit den Credits baust du die Station aus —
**und** eine Flotte. Die Flotte schickst du auf fremde Planeten. Jeder eroberte
Planet gibt dauerhaft **+50 % Einkommen** auf deine gesamte Produktion. Andere
Spieler können dir Planeten wieder abnehmen.

## Dokumentation

| Datei | Inhalt |
|---|---|
| [`docs/ARCHITEKTUR.md`](docs/ARCHITEKTUR.md) | Bauplan: welches Script wo liegt und warum |
| [`docs/EINBAU-ANLEITUNG.md`](docs/EINBAU-ANLEITUNG.md) | Copy-&-Paste-Anleitung für Roblox Studio |

## Entwicklungsstand

| # | System | Status |
|---|---|---|
| 1 | **Basis-Tycoon** — Plots, Dropper, Upgrades, Lager, HUD | ✅ fertig |
| 2 | Speichersystem — DataStore, Auto-Save, Save beim Verlassen | ✅ fertig |
| 3 | **Flotten-System** — 5 Schiffsklassen, Werft, Bauwarteschlange, Orbit | ✅ fertig |
| 4 | Planeten-Eroberung — Kampfformel, Besitz, PvP-Rückeroberung | ⬜ offen |
| 5 | Prestige / Rebirth | ⬜ offen |
| 6 | Zusatz-Features — Zufallsereignisse, Tech-Baum, Verteidigung | ⬜ offen |
| 7 | Monetarisierung — Gamepasses, Entwicklerprodukte | ⬜ offen |

Die Datenfelder für Schritt 4–7 sind im Spielstand **bereits angelegt**, und der
Planeten- sowie Rebirth-Bonus steckt schon in der Multiplikator-Formel. Die
späteren Systeme müssen diese Felder nur noch füllen — kein Umbau nötig.

## Projektstruktur

Die Ordner unter `src/` bilden die Roblox-Explorer-Hierarchie 1:1 ab.

```
src/
├── ReplicatedStorage/        → ReplicatedStorage        (Server + Client)
│   ├── GameConfig.lua            Balance-Werte Basis-Tycoon
│   ├── FleetConfig.lua           Balance-Werte Schiffsklassen
│   ├── Util.lua                  Hilfsfunktionen
│   ├── Signal.lua                Event-System
│   ├── UiKit.lua                 GUI-Baukasten (Farben, Knöpfe, Aktionsleiste)
│   └── Net.lua                   RemoteEvent-Verwaltung
├── ServerScriptService/      → ServerScriptService      (nur Server)
│   ├── Main.server.lua           ★ Einstiegspunkt Server
│   └── Services/                 die eigentliche Spiellogik
└── StarterPlayerScripts/     → StarterPlayer > StarterPlayerScripts
    ├── HudClient.client.lua      ★ HUD + Aktionsleiste
    └── FleetGui.client.lua       Werft-Fenster
```

**Dateiendungen** (gängige Roblox-Konvention):

| Endung | Roblox-Typ | Startet von allein? |
|---|---|---|
| `.lua` | ModuleScript | nein — wird per `require()` geladen |
| `.server.lua` | Script | ja, auf dem Server |
| `.client.lua` | LocalScript | ja, beim Spieler |

## Technik

- **Sprache:** Luau
- **Exploit-Schutz:** Jede Geldänderung, jeder Kauf und jede Sammel-Anfrage wird
  serverseitig geprüft. Client-Remotes übertragen nie Beträge, nur Absichten.
- **Performance:** Keine unverankerten Parts, keine Physik-Dropper. Lieferungen
  laufen über `TweenService`, Schatten sind aus, GUI-Updates sind gebündelt —
  ausgelegt auf flüssiges Mobile-Gameplay.
- **Kunstrichtung:** Low-Poly, flache Farben, Neon-Akzente. Komplett per Code
  erzeugt, keine externen Assets nötig.
