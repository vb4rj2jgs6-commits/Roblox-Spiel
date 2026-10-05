# STELLAR DOMINION — Arbeitsregeln

**Vor dem ersten Schritt: `docs/UEBERGABE.md` lesen.** Dort steht der aktuelle
Stand, was zuletzt gebaut wurde und die Aufgabenliste.

## Projekt
Space-Tycoon für Roblox in Luau. Welt, Planeten, Schiffe und GUI entstehen
komplett per Code — keine von Hand gebauten Modelle, keine externen Assets.

## Der Nutzer ist Anfänger in Roblox Studio und Lua
Das prägt jede Zeile:
- **Kommentare auf Deutsch**, und zwar erklärend (*warum*), nicht beschreibend (*was*)
- Jedes Script hat im Kopf: **in welchen Explorer-Ordner es gehört und warum**
- Namen auf Deutsch: `baueDropper`, `Siegchance`, `plot.Besitzer`
- Alle Balance-Zahlen in die Config-Module, nie in den Logik-Code

## Harte Regeln
1. **Geld ändert sich nur über `CurrencyService`** (`:Hinzufuegen()` / `:Abbuchen()`).
   Kein anderes Script schreibt `daten.Geld`. `:Abbuchen()` prüft selbst und gibt `false` zurück.
2. **Client-Remotes enthalten nie Beträge oder Preise** — nur Absichten.
   Validierung immer: Typ → existiert? → Zahl brauchbar (inkl. `NaN`) → freigeschaltet?
   → Grenzen → *erst dann* abbuchen.
3. **`Signal.lua` statt `BindableEvent`.** BindableEvents kopieren Tabellen; eine
   kopierte Plot-Tabelle bedeutet, dass neu gekaufte Dropper nie Geld produzieren.
4. **Keine Umlaute in Variablennamen** — Luau erlaubt nur ASCII in Bezeichnern.
   In Strings und Kommentaren sind sie in Ordnung.
5. **Teile auf einer Station mit `PlotService:ZuWeltCF`** setzen (Position *und*
   Drehung). Die Stationen stehen im Ring und sind unterschiedlich gedreht.
   `ZuWelt` (nur Position) nur für Kugeln und zufällig gedrehtes Zeug.
6. **`Id`-Werte in Configs nie umbenennen** — sie stehen so in den Spielständen.
7. **Neue Parts**: `Util.NeuerPart`, verankert, `CanCollide/CanQuery/CanTouch = false`
   wo möglich. Keine unverankerten Parts, keine Physik (Mobile-Performance).
8. **Neues RemoteEvent**: Name in `Net.lua` → `EVENT_NAMEN` eintragen, mehr nicht.

## Nach jeder Änderung
```bash
for f in $(find src -name "*.lua"); do luau-compile --null "$f"; done
luau-analyze src/ReplicatedStorage/*.lua src/ServerScriptService/**/*.lua src/StarterPlayerScripts/*.lua
python3 tools/build_installer.py    # erzeugt install/ neu — nicht vergessen
```

`src/` ist die Quelle der Wahrheit. Änderungen, die nur im Studio gemacht werden,
sind beim nächsten Einspielen weg.

## Struktur
`.lua` = ModuleScript · `.server.lua` = Script · `.client.lua` = LocalScript.
Die Ordner unter `src/` spiegeln die Explorer-Hierarchie 1:1.
Details: `docs/ARCHITEKTUR.md`.
