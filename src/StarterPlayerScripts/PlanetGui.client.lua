--[[
	PlanetGui  —  LocalScript
	================================================================
	EXPLORER-ORT:  StarterPlayer > StarterPlayerScripts > PlanetGui

	Die Sternenkarte: alle Planeten, ihre Verteidigung, wem sie
	gehoeren und wie hoch deine Siegchance ist.

	WARUM DIE SIEGCHANCE HIER BERECHNET WIRD:
	Die Formel steht in PlanetConfig — also in ReplicatedStorage, wo
	Server UND Client sie lesen. Beide rechnen darum garantiert
	dasselbe aus. Der Client zeigt die Zahl nur an; gewuerfelt und
	entschieden wird ausschliesslich auf dem Server.

	EXPLOIT-SCHUTZ:
	Beim Klick auf ANGREIFEN geht nur die Planeten-Id zum Server.
	Cooldown, Schutzschild, Flottenstaerke und Wuerfelwurf prueft
	der CombatService.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlanetConfig = require(ReplicatedStorage:WaitForChild("PlanetConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local UiKit = require(ReplicatedStorage:WaitForChild("UiKit"))

local spieler = Players.LocalPlayer
local Farben = UiKit.Farben

-- ================================================================
-- ZUSTAND
-- ================================================================
local planetenStand: { [string]: any } = {}   -- [PlanetId] = Serverdaten
local meineStaerke = 0
local cooldownBis = 0                          -- os.clock()-Zeitpunkt
local imFlugBis = 0

local fenster = UiKit.Fenster({
	Name = "SternenkarteGui",
	Titel = "STERNENKARTE",
	Untertitel = "Planeten erobern · +50 % Einkommen pro Planet",
	MaxGroesse = Vector2.new(680, 580),
	Ebene = 6,
})

-- ================================================================
-- STATUSLEISTE
-- ================================================================
local statusLeiste = UiKit.Neu("Frame", {
	Name = "Status",
	Size = UDim2.new(1, 0, 0, 62),
	BackgroundTransparency = 1,
}, fenster.Inhalt)

UiKit.Neu("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, statusLeiste)

local function baueKachel(reihenfolge: number, titel: string)
	local kachel = UiKit.Neu("Frame", {
		Name = titel,
		LayoutOrder = reihenfolge,
		Size = UDim2.new(1 / 3, -6, 1, 0),
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

	return UiKit.Text({
		Name = "Wert",
		Position = UDim2.new(0, 10, 0, 24),
		Size = UDim2.new(1, -20, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		Text = "0",
	}, kachel)
end

local staerkeWert = baueKachel(1, "FLOTTENSTÄRKE")
local besitzWert = baueKachel(2, "DEINE PLANETEN")
local bereitWert = baueKachel(3, "FLOTTE BEREIT")

-- ================================================================
-- PLANETENLISTE
-- ================================================================
local liste = UiKit.Neu("ScrollingFrame", {
	Name = "Planeten",
	Position = UDim2.new(0, 0, 0, 70),
	Size = UDim2.new(1, 0, 1, -70),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = Farben.PanelRand,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, fenster.Inhalt)

UiKit.Neu("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, liste)

UiKit.Neu("UIPadding", { PaddingRight = UDim.new(0, 8) }, liste)

local zeilen: { [string]: any } = {}

local function baueZeile(eintrag: any)
	local typ = PlanetConfig.Typen[eintrag.Typ]

	local zeile = UiKit.Neu("Frame", {
		Name = eintrag.Id,
		LayoutOrder = eintrag.Reihenfolge,
		Size = UDim2.new(1, 0, 0, 92),
		BackgroundColor3 = Farben.PanelHell,
		BorderSizePixel = 0,
	}, liste)
	UiKit.Ecken(zeile, 10)
	local rand = UiKit.Rand(zeile, Farben.PanelHell, 1.5, 1)

	local streifen = UiKit.Neu("Frame", {
		Size = UDim2.new(0, 4, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = typ.Atmosphaere,
		BorderSizePixel = 0,
	}, zeile)
	UiKit.Ecken(streifen, 2)

	UiKit.Text({
		Position = UDim2.new(0, 20, 0, 8),
		Size = UDim2.new(1, -180, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Text = eintrag.Name,
	}, zeile)

	UiKit.Text({
		Position = UDim2.new(0, 20, 0, 27),
		Size = UDim2.new(1, -180, 0, 14),
		TextSize = 11,
		TextColor3 = typ.Atmosphaere,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = typ.Name .. "  ·  " .. typ.BonusText,
	}, zeile)

	local vertLabel = UiKit.Text({
		Position = UDim2.new(0, 20, 0, 46),
		Size = UDim2.new(1, -180, 0, 14),
		TextSize = 11,
		TextColor3 = Farben.TextGedimmt,
		Text = "Verteidigung …",
	}, zeile)

	local statusLabel = UiKit.Text({
		Position = UDim2.new(0, 20, 0, 64),
		Size = UDim2.new(1, -180, 0, 14),
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Farben.TextGedimmt,
		Text = "unbesetzt",
	}, zeile)

	local chanceLabel = UiKit.Text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 12),
		Size = UDim2.new(0, 150, 0, 24),
		Font = Enum.Font.GothamBlack,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "—",
	}, zeile)

	local chanceText = UiKit.Text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 34),
		Size = UDim2.new(0, 150, 0, 12),
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Farben.TextGedimmt,
		Text = "SIEGCHANCE",
	}, zeile)

	local knopf = UiKit.Knopf({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 52),
		Size = UDim2.new(0, 150, 0, 30),
		TextSize = 13,
		Text = "ANGREIFEN",
	}, zeile)

	knopf.Activated:Connect(function()
		Net:Event("AngriffStarten"):FireServer(eintrag.Id)
	end)

	zeilen[eintrag.Id] = {
		Rahmen = zeile,
		Rand = rand,
		Verteidigung = vertLabel,
		Status = statusLabel,
		Chance = chanceLabel,
		ChanceText = chanceText,
		Knopf = knopf,
	}
end

for _, eintrag in PlanetConfig.Planeten do
	baueZeile(eintrag)
end

-- ================================================================
-- ANZEIGE
-- ================================================================
local function aktualisiere()
	local jetzt = os.clock()
	local cooldownRest = math.max(0, cooldownBis - jetzt)
	local unterwegs = jetzt < imFlugBis
	local eigene = 0

	for _, eintrag in PlanetConfig.Planeten do
		local zeile = zeilen[eintrag.Id]
		local daten = planetenStand[eintrag.Id]
		if not zeile or not daten then
			continue
		end

		local gehoertMir = daten.BesitzerId == spieler.UserId
		if gehoertMir then
			eigene += 1
		end

		zeile.Verteidigung.Text = "Verteidigung  " .. Util.FormatGeld(daten.Verteidigung)

		-- Zeile 4: wem gehoert er / laeuft ein Schild?
		local schildRest = daten.SchildRest or 0
		if gehoertMir then
			zeile.Status.Text = "UNTER DEINER KONTROLLE"
			zeile.Status.TextColor3 = Farben.Gut
			zeile.Rand.Color = Farben.Gut
			zeile.Rand.Transparency = 0.5
		elseif daten.BesitzerName then
			zeile.Status.Text = "gehört " .. daten.BesitzerName
			zeile.Status.TextColor3 = Farben.Warnung
			zeile.Rand.Color = Farben.Warnung
			zeile.Rand.Transparency = 0.6
		else
			zeile.Status.Text = "unbesetzt"
			zeile.Status.TextColor3 = Farben.TextGedimmt
			zeile.Rand.Transparency = 1
		end

		if schildRest > 0 and not gehoertMir then
			zeile.Status.Text ..= ("  ·  Schild %s"):format(Util.FormatZeit(schildRest))
		end

		-- Siegchance — dieselbe Formel wie auf dem Server
		local chance = PlanetConfig.Siegchance(meineStaerke, daten.Verteidigung)

		if gehoertMir then
			zeile.Chance.Text = "DEINS"
			zeile.Chance.TextColor3 = Farben.Gut
			zeile.ChanceText.Text = "EROBERT"
		else
			zeile.Chance.Text = ("%d %%"):format(math.floor(chance * 100))
			zeile.Chance.TextColor3 = (chance >= 0.6) and Farben.Gut
				or (chance >= 0.3) and Farben.Gold
				or Farben.Warnung
			zeile.ChanceText.Text = "SIEGCHANCE"
		end

		-- Knopf
		local blockiert = gehoertMir or unterwegs or cooldownRest > 0 or (schildRest > 0)
		zeile.Knopf.BackgroundColor3 = blockiert and Farben.Inaktiv or Farben.Akzent
		zeile.Knopf.TextColor3 = blockiert and Farben.TextGedimmt or Color3.fromRGB(8, 16, 24)

		if gehoertMir then
			zeile.Knopf.Text = "IN DEINEM BESITZ"
		elseif unterwegs then
			zeile.Knopf.Text = "FLOTTE UNTERWEGS"
		elseif cooldownRest > 0 then
			zeile.Knopf.Text = "BEREIT IN " .. Util.FormatZeit(cooldownRest)
		elseif schildRest > 0 then
			zeile.Knopf.Text = "GESCHÜTZT"
		else
			zeile.Knopf.Text = "ANGREIFEN"
		end
	end

	staerkeWert.Text = Util.FormatGeld(meineStaerke)
	besitzWert.Text = eigene .. " / " .. #PlanetConfig.Planeten

	if unterwegs then
		bereitWert.Text = "UNTERWEGS"
		bereitWert.TextColor3 = Farben.Gold
	elseif cooldownRest > 0 then
		bereitWert.Text = Util.FormatZeit(cooldownRest)
		bereitWert.TextColor3 = Farben.Warnung
	else
		bereitWert.Text = "JA"
		bereitWert.TextColor3 = Farben.Gut
	end
end

-- ================================================================
-- SERVER-EREIGNISSE
-- ================================================================
Net:Event("PlanetUpdate").OnClientEvent:Connect(function(uebersicht)
	for _, eintrag in uebersicht do
		planetenStand[eintrag.Id] = eintrag
		-- SchildRest kommt als Restzeit an. Wir merken uns den
		-- Ablaufzeitpunkt, damit der Countdown fluessig weiterlaeuft.
		eintrag._SchildEndeUm = os.clock() + (eintrag.SchildRest or 0)
	end
	aktualisiere()
end)

Net:Event("FlotteUpdate").OnClientEvent:Connect(function(daten)
	if daten.Staerke then
		meineStaerke = daten.Staerke
	end
end)

Net:Event("KampfErgebnis").OnClientEvent:Connect(function(ergebnis)
	if ergebnis.Phase == "Start" then
		imFlugBis = os.clock() + (ergebnis.Reisezeit or 0)
		cooldownBis = os.clock() + (ergebnis.Cooldown or 0)
		return
	end

	imFlugBis = 0

	local text = ergebnis.Gewonnen
		and ("%s erobert!  (-%d Schiffe)"):format(ergebnis.PlanetName, ergebnis.VerloreneSchiffe)
		or ("%s gehalten — Angriff gescheitert. (-%d Schiffe)")
			:format(ergebnis.PlanetName, ergebnis.VerloreneSchiffe)

	-- Die Toast-Meldung selbst kommt vom Server ueber "Benachrichtigung".
	-- Hier loggen wir nur fuer die Entwickler-Konsole.
	print("[PlanetGui] " .. text)
end)

-- Schildzeiten laufen weiter, ohne dass der Server staendig sendet
RunService.RenderStepped:Connect(function()
	if not fenster.Offen then
		return
	end

	local jetzt = os.clock()
	for _, eintrag in planetenStand do
		if eintrag._SchildEndeUm then
			eintrag.SchildRest = math.max(0, eintrag._SchildEndeUm - jetzt)
		end
	end

	aktualisiere()
end)

-- ================================================================
-- OEFFNEN
-- ================================================================
fenster.BeimOeffnen = function()
	Net:Event("PlanetAnfrage"):FireServer()
	Net:Event("FlotteAnfrage"):FireServer()
	aktualisiere()
end

local knopf = UiKit.LeistenKnopf("PLANETEN", 20)
knopf.Activated:Connect(function()
	fenster:Umschalten()
end)

task.defer(function()
	Net:Event("PlanetAnfrage"):FireServer()
end)

print("[PlanetGui] Sternenkarte bereit")
