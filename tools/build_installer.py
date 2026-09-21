#!/usr/bin/env python3
"""
Erzeugt aus den Quelldateien unter src/ die Installationsdateien in install/:

  install/INSTALLER.lua            -> einmal in die Studio-Befehlsleiste einfuegen
  install/ReplicatedStorage.rbxmx  -> Rechtsklick auf den Dienst > "Insert from File"
  install/ServerScriptService.rbxmx
  install/StarterPlayerScripts.rbxmx

Nach jeder Aenderung an src/ einfach neu ausfuehren:
    python3 tools/build_installer.py
"""

from pathlib import Path
from xml.sax.saxutils import escape

WURZEL = Path(__file__).resolve().parent.parent
QUELLE = WURZEL / "src"
ZIEL = WURZEL / "install"

# (Ordner auf der Platte, Ziel im Explorer, Roblox-Klasse)
GRUPPEN = [
    ("ReplicatedStorage", "ReplicatedStorage", "ModuleScript"),
    ("ServerScriptService", "ServerScriptService", None),        # Main = Script
    ("ServerScriptService/Services", "ServerScriptService/Services", "ModuleScript"),
    ("StarterPlayerScripts", "StarterPlayerScripts", "LocalScript"),
]


def instanzname(datei: Path) -> str:
    """Main.server.lua -> Main,  HudClient.client.lua -> HudClient"""
    name = datei.stem
    for endung in (".server", ".client"):
        if name.endswith(endung):
            name = name[: -len(endung)]
    return name


def klasse_fuer(datei: Path, vorgabe) -> str:
    if datei.name.endswith(".server.lua"):
        return "Script"
    if datei.name.endswith(".client.lua"):
        return "LocalScript"
    return vorgabe or "ModuleScript"


def sammle():
    eintraege = []
    for unterordner, ziel, vorgabe in GRUPPEN:
        ordner = QUELLE / unterordner
        if not ordner.is_dir():
            continue
        for datei in sorted(ordner.glob("*.lua")):
            eintraege.append(
                {
                    "ziel": ziel,
                    "name": instanzname(datei),
                    "klasse": klasse_fuer(datei, vorgabe),
                    "quelle": datei.read_text(encoding="utf-8"),
                    "datei": datei,
                }
            )
    return eintraege


# ======================================================================
# 1) Befehlsleisten-Installer
# ======================================================================
def baue_installer(eintraege) -> str:
    # Lua-Langstrings werden mit [==[ ... ]==] begrenzt. Das funktioniert nur,
    # solange keine Quelldatei die Zeichenfolge ]==] enthaelt.
    for e in eintraege:
        if "]==]" in e["quelle"]:
            raise SystemExit(f"FEHLER: ]==] in {e['datei']} — Langstring-Begrenzer anpassen!")

    teile = [
        "--[[\n"
        "\tSTELLAR DOMINION — Installer\n"
        "\t================================================================\n"
        "\tNICHT in den Explorer einfuegen!\n"
        "\tDiesen Text komplett kopieren und unten in Roblox Studio in die\n"
        "\tBEFEHLSLEISTE (View > Command Bar) einfuegen, dann Enter.\n"
        "\n"
        "\tDas Script legt alle Ordner und Scripts an der richtigen Stelle an.\n"
        "\tErneutes Ausfuehren ueberschreibt sie — so spielst du Updates ein,\n"
        "\tohne etwas von Hand zu loeschen.\n"
        "\t================================================================\n"
        "]]\n\n"
        'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n'
        'local ServerScriptService = game:GetService("ServerScriptService")\n'
        'local StarterPlayer = game:GetService("StarterPlayer")\n'
        'local Workspace = game:GetService("Workspace")\n\n'
        "-- Legt einen Ordner an bzw. gibt den vorhandenen zurueck\n"
        "local function holeOrdner(eltern, name)\n"
        "\tlocal vorhanden = eltern:FindFirstChild(name)\n"
        "\tif vorhanden and not vorhanden:IsA(\"Folder\") then\n"
        "\t\tvorhanden:Destroy()\n"
        "\t\tvorhanden = nil\n"
        "\tend\n"
        "\tif not vorhanden then\n"
        "\t\tvorhanden = Instance.new(\"Folder\")\n"
        "\t\tvorhanden.Name = name\n"
        "\t\tvorhanden.Parent = eltern\n"
        "\tend\n"
        "\treturn vorhanden\n"
        "end\n\n"
        "local ZIELE = {\n"
        "\tReplicatedStorage = ReplicatedStorage,\n"
        "\tServerScriptService = ServerScriptService,\n"
        '\t["ServerScriptService/Services"] = holeOrdner(ServerScriptService, "Services"),\n'
        '\tStarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts"),\n'
        "}\n\n"
        "-- Reste aus frueheren Testlaeufen entfernen. Beide werden zur\n"
        "-- Laufzeit neu erzeugt und gehoeren nicht in die gespeicherte Place.\n"
        'for _, name in { "Remotes" } do\n'
        "\tlocal rest = ReplicatedStorage:FindFirstChild(name)\n"
        "\tif rest then rest:Destroy() end\n"
        "end\n"
        'local welt = Workspace:FindFirstChild("Welt")\n'
        "if welt then welt:Destroy() end\n\n"
        "local DATEIEN = {\n"
    ]

    for e in eintraege:
        teile.append(
            "\t{\n"
            f'\t\tZiel = "{e["ziel"]}",\n'
            f'\t\tName = "{e["name"]}",\n'
            f'\t\tKlasse = "{e["klasse"]}",\n'
            "\t\tQuelle = [==[\n"
            + e["quelle"].rstrip("\n")
            + "\n]==],\n"
            "\t},\n"
        )

    teile.append(
        "}\n\n"
        "local angelegt = 0\n"
        "for _, eintrag in DATEIEN do\n"
        "\tlocal eltern = ZIELE[eintrag.Ziel]\n"
        "\tif eltern then\n"
        "\t\tlocal alt = eltern:FindFirstChild(eintrag.Name)\n"
        "\t\tif alt then alt:Destroy() end\n\n"
        "\t\tlocal neu = Instance.new(eintrag.Klasse)\n"
        "\t\tneu.Name = eintrag.Name\n"
        "\t\tneu.Source = eintrag.Quelle\n"
        "\t\tneu.Parent = eltern\n"
        "\t\tangelegt += 1\n"
        "\telse\n"
        '\t\twarn("[Installer] Unbekanntes Ziel: " .. eintrag.Ziel)\n'
        "\tend\n"
        "end\n\n"
        'print("================================================")\n'
        'print("STELLAR DOMINION installiert: " .. angelegt .. " Scripts")\n'
        'print("Jetzt auf Play druecken (F5).")\n'
        'print("================================================")\n'
    )

    return "".join(teile)


# ======================================================================
# 2) rbxmx-Modelle
# ======================================================================
def cdata(text: str) -> str:
    # In CDATA darf ]]> nicht vorkommen -> aufteilen
    text = text.replace("]]>", "]]]]><![CDATA[>")
    return f"<![CDATA[{text}]]>"


_zaehler = [0]


def item(klasse: str, name: str, quelle=None, kinder="") -> str:
    _zaehler[0] += 1
    referenz = f"RBX{_zaehler[0]}"
    eigenschaften = f"      <string name=\"Name\">{escape(name)}</string>\n"
    if quelle is not None:
        eigenschaften += f"      <ProtectedString name=\"Source\">{cdata(quelle)}</ProtectedString>\n"
    return (
        f'  <Item class="{klasse}" referent="{referenz}">\n'
        f"    <Properties>\n{eigenschaften}    </Properties>\n"
        f"{kinder}"
        f"  </Item>\n"
    )


def baue_rbxmx(inhalt: str) -> str:
    return (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        f"{inhalt}"
        "</roblox>\n"
    )


def main():
    ZIEL.mkdir(exist_ok=True)
    eintraege = sammle()

    (ZIEL / "INSTALLER.lua").write_text(baue_installer(eintraege), encoding="utf-8")

    # --- ReplicatedStorage ---
    inhalt = "".join(
        item(e["klasse"], e["name"], e["quelle"])
        for e in eintraege
        if e["ziel"] == "ReplicatedStorage"
    )
    (ZIEL / "ReplicatedStorage.rbxmx").write_text(baue_rbxmx(inhalt), encoding="utf-8")

    # --- ServerScriptService (Main + Ordner Services) ---
    # ACHTUNG: Hier NICHT einruecken. Der Quelltext steht in einem
    # CDATA-Block — jedes eingefuegte Leerzeichen landet im Lua-Code.
    dienste = "".join(
        item(e["klasse"], e["name"], e["quelle"])
        for e in eintraege
        if e["ziel"] == "ServerScriptService/Services"
    )
    inhalt = "".join(
        item(e["klasse"], e["name"], e["quelle"])
        for e in eintraege
        if e["ziel"] == "ServerScriptService"
    )
    inhalt += item("Folder", "Services", None, dienste)
    (ZIEL / "ServerScriptService.rbxmx").write_text(baue_rbxmx(inhalt), encoding="utf-8")

    # --- StarterPlayerScripts ---
    inhalt = "".join(
        item(e["klasse"], e["name"], e["quelle"])
        for e in eintraege
        if e["ziel"] == "StarterPlayerScripts"
    )
    (ZIEL / "StarterPlayerScripts.rbxmx").write_text(baue_rbxmx(inhalt), encoding="utf-8")

    print(f"{len(eintraege)} Scripts verarbeitet:")
    for datei in sorted(ZIEL.iterdir()):
        print(f"  {datei.name:34} {datei.stat().st_size / 1024:8.1f} KB")


if __name__ == "__main__":
    main()
