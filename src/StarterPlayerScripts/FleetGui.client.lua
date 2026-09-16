--[[
	FleetGui  —  LocalScript
	================================================================
	EXPLORER-ORT:  StarterPlayer > StarterPlayerScripts > FleetGui

	WARUM EIN EIGENES SCRIPT STATT ALLES IN HudClient?
	Ein Script pro Fenster. HudClient kennt die Werft nicht und die
	Werft kennt das HUD nicht — sie treffen sich nur ueber die
	Aktionsleiste, die UiKit verwaltet. Schritt 3 (Planeten) bekommt
	spaeter genauso ein eigenes Script und haengt sich einen weiteren
	Knopf in dieselbe Leiste.

	OEFFNEN GEHT AUF ZWEI WEGEN:
	  1. Knopf "FLOTTE" in der Aktionsleiste (funktioniert überall,
	     wichtig fuer Handys)
	  2. ProximityPrompt an der Werft auf dem eigenen Plot

	WICHTIG (Exploit-Schutz):
	Beim Klick auf "BAUEN" schickt der Client nur Klassenname und
	Anzahl. Preis, Hangar-Platz und Kontostand prueft ausschliesslich
	der FleetService auf dem Server. Die Farben hier (gruen/rot) sind
	reine Anzeige — sie entscheiden gar nichts.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local FleetConfig = require(ReplicatedStorage:WaitForChild("FleetConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local UiKit = require(ReplicatedStorage:WaitForChild("UiKit"))

local spieler = Players.LocalPlayer
local spielerGui = spieler:WaitForChild("PlayerGui")
local Farben = UiKit.Farben

-- ================================================================
-- ZUSTAND (alles kommt vom Server, nichts wird hier ausgerechnet)
-- ================================================================
local stand = {
	Flotte = {},
	Warteschlange = {},
	Staerke = 0,
	Verteidigung = 0,
	Kapazitaet = FleetConfig.Allgemein.BasisKapazitaet,
	Belegt = 0,
	HangarStufe = 0,
	HangarPreis = FleetConfig.HangarPreis(0),
	Freigeschaltet = {},
}

local geld = 0

-- Uhr-Abgleich: Die Uhr des Spielers kann von der Serveruhr abweichen.
-- Wir merken uns beim Empfang beide Zeiten und rechnen die Serverzeit
-- daraus fluessig hoch — sonst wuerde der Countdown sekundenweise springen.
local zeitBasis = { Serverzeit = os.time(), Clock = os.clock() }

local function jetztServer(): number
	return zeitBasis.Serverzeit + (os.clock() - zeitBasis.Clock)
end

-- ================================================================
-- FENSTER AUFBAUEN
-- ================================================================
local gui = UiKit.Neu("ScreenGui", {
	Name = "WerftGui",
	ResetOnSpawn = false,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, spielerGui)

-- Abdunkelnder Hintergrund. Klick darauf schliesst das Fenster.
-- Bewusst ein TextButton und kein Frame: nur Knoepfe melden Klicks.
local hintergrund = UiKit.Neu("TextButton", {
	Name = "Hintergrund",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Text = "",
	Visible = false,
}, gui)

local panel = UiKit.Neu("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.92, 0, 0.88, 0),
	BackgroundColor3 = Farben.Panel,
	BorderSizePixel = 0,
	-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde ein
	-- Klick mitten ins Fenster den Hintergrund-Knopf darunter ausloesen und
	-- die Werft sofort wieder schliessen.
	Active = true,
}, hintergrund)
UiKit.Ecken(panel, 14)
UiKit.Rand(panel, Farben.PanelRand, 1.5, 0.45)
UiKit.Abstand(panel, 12)

UiKit.Neu("UISizeConstraint", {
	MaxSize = Vector2.new(640, 560),
	MinSize = Vector2.new(280, 320),
}, panel)

-- ---------- Kopfzeile ----------
UiKit.Text({
	Name = "Titel",
	Size = UDim2.new(1, -44, 0, 26),
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	Text = "RAUMWERFT",
}, panel)

UiKit.Text({
	Name = "Untertitel",
	Position = UDim2.new(0, 0, 0, 24),
	Size = UDim2.new(1, -44, 0, 14),
	TextSize = 11,
	TextColor3 = Farben.TextGedimmt,
	Text = "Schiffe bauen · Hangar erweitern",
}, panel)

local schliessen = UiKit.Knopf({
	Name = "Schliessen",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0, 34, 0, 34),
	BackgroundColor3 = Farben.PanelHell,
	TextColor3 = Farben.Text,
	TextSize = 16,
	Text = "✕",
}, panel)

-- ---------- Statusleiste ----------
local statusLeiste = UiKit.Neu("Frame", {
	Name = "Status",
	Position = UDim2.new(0, 0, 0, 48),
	Size = UDim2.new(1, 0, 0, 62),
	BackgroundTransparency = 1,
}, panel)

local function baueKachel(reihenfolge: number, titel: string)
	local kachel = UiKit.Neu("Frame", {
		Name = titel,
		LayoutOrder = reihenfolge,
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = Farben.PanelHell,
		BorderSizePixel = 0,
	}, statusLeiste)
	UiKit.Ecken(kachel, 10)

	UiKit.Text({
		Position = UDim2.new(0, 10, 0, 9),
		Size = UDim2.new(1, -20, 0, 12),
		TextSize = 10,
		TextColor3 = Farben.TextGedimmt,
		Text = titel,
	}, kachel)

	local wert = UiKit.Text({
		Name = "Wert",
		Position = UDim2.new(0, 10, 0, 24),
		Size = UDim2.new(1, -20, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 19,
		Text = "0",
	}, kachel)

	return wert
end

UiKit.Neu("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, statusLeiste)

local staerkeWert = baueKachel(1, "FLOTTENSTÄRKE")
local hangarWert = baueKachel(2, "HANGAR-PLÄTZE")

-- ---------- Hangar-Ausbau ----------
local hangarKnopf = UiKit.Knopf({
	Name = "HangarAusbau",
	Position = UDim2.new(0, 0, 0, 118),
	Size = UDim2.new(1, 0, 0, 32),
	BackgroundColor3 = Farben.PanelHell,
	TextColor3 = Farben.Gold,
	TextSize = 13,
	Text = "HANGAR ERWEITERN",
}, panel)
UiKit.Rand(hangarKnopf, Farben.Gold, 1, 0.6)

-- ---------- Schiffsliste ----------
local liste = UiKit.Neu("ScrollingFrame", {
	Name = "Schiffe",
	Position = UDim2.new(0, 0, 0, 158),
	Size = UDim2.new(1, 0, 1, -250),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = Farben.PanelRand,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, panel)

UiKit.Neu("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, liste)

UiKit.Neu("UIPadding", { PaddingRight = UDim.new(0, 8) }, liste)

-- ---------- Warteschlange ----------
local warteRahmen = UiKit.Neu("Frame", {
	Name = "Warteschlange",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 84),
	BackgroundColor3 = Farben.PanelHell,
	BorderSizePixel = 0,
}, panel)
UiKit.Ecken(warteRahmen, 10)

UiKit.Text({
	Position = UDim2.new(0, 12, 0, 10),
	Size = UDim2.new(1, -24, 0, 12),
	TextSize = 10,
	TextColor3 = Farben.TextGedimmt,
	Text = "BAUWARTESCHLANGE",
}, warteRahmen)

local warteText = UiKit.Text({
	Name = "Info",
	Position = UDim2.new(0, 12, 0, 26),
	Size = UDim2.new(1, -24, 0, 20),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Text = "Werft im Leerlauf",
}, warteRahmen)

local warteBalkenHuelle = UiKit.Neu("Frame", {
	Position = UDim2.new(0, 12, 0, 52),
	Size = UDim2.new(1, -24, 0, 8),
	BackgroundColor3 = Color3.fromRGB(35, 40, 58),
	BorderSizePixel = 0,
}, warteRahmen)
UiKit.Ecken(warteBalkenHuelle, 4)

local warteBalken = UiKit.Neu("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Farben.Akzent,
	BorderSizePixel = 0,
}, warteBalkenHuelle)
UiKit.Ecken(warteBalken, 4)

local warteRest = UiKit.Text({
	Position = UDim2.new(0, 12, 0, 64),
	Size = UDim2.new(1, -24, 0, 12),
	TextSize = 10,
	TextColor3 = Farben.TextGedimmt,
	Text = "",
}, warteRahmen)

-- ================================================================
-- SCHIFFSZEILEN
-- ================================================================
local zeilen: { [string]: any } = {}

local function baueSchiffZeile(klasse: any)
	local zeile = UiKit.Neu("Frame", {
		Name = klasse.Id,
		LayoutOrder = klasse.Reihenfolge,
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundColor3 = Farben.PanelHell,
		BorderSizePixel = 0,
	}, liste)
	UiKit.Ecken(zeile, 10)

	-- Farbstreifen links: gleiche Farbe wie das Schiff im Orbit
	local streifen = UiKit.Neu("Frame", {
		Size = UDim2.new(0, 4, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = klasse.Akzent,
		BorderSizePixel = 0,
	}, zeile)
	UiKit.Ecken(streifen, 2)

	UiKit.Text({
		Position = UDim2.new(0, 20, 0, 8),
		Size = UDim2.new(1, -200, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Text = klasse.Name,
	}, zeile)

	UiKit.Text({
		Position = UDim2.new(0, 20, 0, 27),
		Size = UDim2.new(1, -200, 0, 14),
		TextSize = 11,
		TextColor3 = Farben.TextGedimmt,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = klasse.Beschreibung,
	}, zeile)

	UiKit.Text({
		Position = UDim2.new(0, 20, 0, 46),
		Size = UDim2.new(1, -200, 0, 14),
		TextSize = 11,
		TextColor3 = klasse.Akzent,
		Text = string.format(
			"ANG %s  ·  VTG %s  ·  %d Plätze  ·  %ds",
			Util.FormatGeld(klasse.Angriff),
			Util.FormatGeld(klasse.Verteidigung),
			klasse.Platzbedarf,
			klasse.Bauzeit
		),
	}, zeile)

	local preisLabel = UiKit.Text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.new(0, 170, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Farben.Gut,
		Text = Util.FormatGeld(klasse.Preis) .. " " .. Config.Spiel.Waehrung,
	}, zeile)

	local besitzLabel = UiKit.Text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 27),
		Size = UDim2.new(0, 170, 0, 14),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Farben.Gold,
		Text = "Im Hangar: 0",
	}, zeile)

	local knopf1 = UiKit.Knopf({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -96, 0, 46),
		Size = UDim2.new(0, 78, 0, 24),
		TextSize = 12,
		Text = "BAUEN  +1",
	}, zeile)

	local knopf5 = UiKit.Knopf({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 46),
		Size = UDim2.new(0, 78, 0, 24),
		TextSize = 12,
		Text = "+5",
	}, zeile)

	knopf1.Activated:Connect(function()
		Net:Event("SchiffBauen"):FireServer(klasse.Id, 1)
	end)
	knopf5.Activated:Connect(function()
		Net:Event("SchiffBauen"):FireServer(klasse.Id, 5)
	end)

	zeilen[klasse.Id] = {
		Rahmen = zeile,
		Preis = preisLabel,
		Besitz = besitzLabel,
		Knopf1 = knopf1,
		Knopf5 = knopf5,
	}
end

for _, klasse in FleetConfig.Klassen do
	baueSchiffZeile(klasse)
end

-- ================================================================
-- ANZEIGE AKTUALISIEREN
-- ================================================================
local function aktualisiereStatus()
	staerkeWert.Text = Util.FormatGeld(stand.Staerke)
	hangarWert.Text = string.format("%d / %d", stand.Belegt, stand.Kapazitaet)
	hangarWert.TextColor3 = (stand.Belegt >= stand.Kapazitaet) and Farben.Warnung or Farben.Text

	if stand.HangarPreis then
		local bezahlbar = geld >= stand.HangarPreis
		hangarKnopf.Text = string.format(
			"HANGAR ERWEITERN  ·  Stufe %d  ·  %s %s",
			stand.HangarStufe + 1,
			Util.FormatGeld(stand.HangarPreis),
			Config.Spiel.Waehrung
		)
		hangarKnopf.TextColor3 = bezahlbar and Farben.Gold or Farben.TextGedimmt
	else
		hangarKnopf.Text = "HANGAR VOLL AUSGEBAUT"
		hangarKnopf.TextColor3 = Farben.TextGedimmt
	end
end

local function aktualisiereZeilen()
	for _, klasse in FleetConfig.Klassen do
		local zeile = zeilen[klasse.Id]
		if not zeile then
			continue
		end

		local anzahl = stand.Flotte[klasse.Id] or 0
		zeile.Besitz.Text = "Im Hangar: " .. anzahl

		-- Freigeschaltet[...] kommt vom Server. Fehlt der Eintrag noch
		-- (erstes Update noch nicht da), gehen wir von "offen" aus.
		local frei = stand.Freigeschaltet[klasse.Id]
		if frei == nil then
			frei = klasse.NurGamepass == nil
		end

		local passtInHangar = (stand.Belegt + klasse.Platzbedarf) <= stand.Kapazitaet
		local bezahlbar = geld >= klasse.Preis
		local kaufbar = frei and passtInHangar and bezahlbar

		if not frei then
			zeile.Preis.Text = "GESPERRT"
			zeile.Preis.TextColor3 = Farben.TextGedimmt
			zeile.Knopf1.Text = "GAMEPASS"
			zeile.Knopf5.Text = "—"
		else
			zeile.Preis.Text = Util.FormatGeld(klasse.Preis) .. " " .. Config.Spiel.Waehrung
			zeile.Preis.TextColor3 = bezahlbar and Farben.Gut or Farben.Warnung
			zeile.Knopf1.Text = "BAUEN  +1"
			zeile.Knopf5.Text = "+5"
		end

		local knopfFarbe = kaufbar and Farben.Akzent or Farben.Inaktiv
		local schriftFarbe = kaufbar and Color3.fromRGB(8, 16, 24) or Farben.TextGedimmt
		zeile.Knopf1.BackgroundColor3 = knopfFarbe
		zeile.Knopf1.TextColor3 = schriftFarbe
		zeile.Knopf5.BackgroundColor3 = knopfFarbe
		zeile.Knopf5.TextColor3 = schriftFarbe
	end
end

local function aktualisiereWarteschlange()
	local anzahl = #stand.Warteschlange

	if anzahl == 0 then
		warteText.Text = "Werft im Leerlauf"
		warteText.TextColor3 = Farben.TextGedimmt
		warteBalken.Size = UDim2.new(0, 0, 1, 0)
		warteRest.Text = ""
		return
	end

	local naechster = stand.Warteschlange[1]
	local klasse = FleetConfig.NachId[naechster.Klasse]
	local jetzt = jetztServer()

	-- StartUm kann bei sehr alten Spielstaenden fehlen -> aus der Bauzeit
	-- der Klasse zurueckrechnen.
	local startUm = naechster.StartUm
		or (naechster.FertigUm - (klasse and klasse.Bauzeit or 1))

	local dauer = math.max(1, naechster.FertigUm - startUm)
	local fortschritt = math.clamp((jetzt - startUm) / dauer, 0, 1)
	local restZeit = math.max(0, naechster.FertigUm - jetzt)

	warteText.Text = string.format(
		"%s  —  %s",
		klasse and klasse.Name or naechster.Klasse,
		Util.FormatZeit(restZeit)
	)
	warteText.TextColor3 = Farben.Text
	warteBalken.Size = UDim2.new(fortschritt, 0, 1, 0)

	local gesamtRest = math.max(0, stand.Warteschlange[anzahl].FertigUm - jetzt)
	warteRest.Text = anzahl == 1
		and "Letztes Schiff in der Warteschlange"
		or string.format("noch %d weitere  ·  alles fertig in %s", anzahl - 1, Util.FormatZeit(gesamtRest))
end

local function aktualisiereAlles()
	aktualisiereStatus()
	aktualisiereZeilen()
	aktualisiereWarteschlange()
end

-- ================================================================
-- SERVER-EREIGNISSE
-- ================================================================
Net:Event("FlotteUpdate").OnClientEvent:Connect(function(daten)
	for schluessel, wert in daten do
		if schluessel == "Serverzeit" then
			zeitBasis.Serverzeit = wert
			zeitBasis.Clock = os.clock()
		else
			stand[schluessel] = wert
		end
	end
	aktualisiereAlles()
end)

-- Fuer die Preisfarben brauchen wir auch den Kontostand.
Net:Event("DatenUpdate").OnClientEvent:Connect(function(daten)
	if daten.Geld then
		geld = daten.Geld
	end
end)

hangarKnopf.Activated:Connect(function()
	Net:Event("HangarErweitern"):FireServer()
end)

-- ================================================================
-- OEFFNEN / SCHLIESSEN
-- ================================================================
local offen = false

local function setzeOffen(neuerZustand: boolean)
	offen = neuerZustand
	hintergrund.Visible = offen

	if offen then
		-- Frische Daten holen und eine kleine Aufzieh-Animation abspielen
		Net:Event("FlotteAnfrage"):FireServer()
		aktualisiereAlles()

		panel.Size = UDim2.new(0.92, 0, 0.8, 0)
		TweenService:Create(
			panel,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0.92, 0, 0.88, 0) }
		):Play()
	end
end

schliessen.Activated:Connect(function()
	setzeOffen(false)
end)

hintergrund.Activated:Connect(function()
	-- Klick neben das Panel schliesst das Fenster
	setzeOffen(false)
end)

local werftKnopf = UiKit.LeistenKnopf("FLOTTE", 10)
werftKnopf.Activated:Connect(function()
	setzeOffen(not offen)
end)

-- ProximityPrompt an der Werft. CollectionService:GetTagged liefert alle
-- Objekte, die der Server mit dem Tag "WerftPrompt" markiert hat.
local function verbindePrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Triggered:Connect(function(ausloeser)
		if ausloeser == spieler then
			setzeOffen(true)
		end
	end)
end

for _, prompt in CollectionService:GetTagged("WerftPrompt") do
	verbindePrompt(prompt)
end
CollectionService:GetInstanceAddedSignal("WerftPrompt"):Connect(verbindePrompt)

-- ================================================================
-- COUNTDOWN LAUFEN LASSEN
-- Nur wenn das Fenster offen ist — geschlossen kostet es nichts.
-- ================================================================
RunService.RenderStepped:Connect(function()
	if offen then
		aktualisiereWarteschlange()
		aktualisiereStatus()
		aktualisiereZeilen()
	end
end)

task.defer(function()
	Net:Event("FlotteAnfrage"):FireServer()
end)

print("[FleetGui] Werft bereit")
