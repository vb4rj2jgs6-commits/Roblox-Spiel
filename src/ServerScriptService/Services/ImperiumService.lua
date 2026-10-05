--[[
	ImperiumService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > ImperiumService

	AUFGABE
	Der Langzeit-Fortschritt in einem Service:
	  1. Technologie-Baum (bleibt beim Rebirth erhalten)
	  2. Rebirth / Prestige
	  3. Orbitalgeschütze sichtbar auf dem Plot
	  4. Schickt das gebuendelte "Imperium"-Update an den Client
	     (Technologien, Rebirth-Stand und Shop in einem Paket)

	WARUM ALLES IN EINER DATEI?
	Diese drei Dinge teilen sich dasselbe GUI-Fenster und fast
	dieselben Daten. Drei Services mit drei Remotes waeren mehr
	Code ohne echten Gewinn. Die Monetarisierung ist bewusst
	getrennt geblieben — die hat mit ProcessReceipt eine ganz
	eigene, heikle Aufgabe.
	================================================================
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local FleetService = require(script.Parent.FleetService)
local MonetizationService = require(script.Parent.MonetizationService)

local ImperiumService = {}

-- Wo die Orbitalgeschuetze auf dem Plot stehen (lokale Koordinaten).
-- Am linken und rechten Plotrand, damit sie nichts ueberdecken.
local GESCHUETZ_PLAETZE = {
	Vector3.new(-52, 0, 40),
	Vector3.new(52, 0, 30),
	Vector3.new(-52, 0, 0),
	Vector3.new(52, 0, -30),
	Vector3.new(-52, 0, -40),
}

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[ImperiumService]", ...)
	end
end

local function melden(spieler: Player, text: string, farbe: string)
	Net:Event("Benachrichtigung"):FireClient(spieler, { Text = text, Farbe = farbe })
end

-- ================================================================
-- ORBITALGESCHÜTZE (sichtbare Verteidigung auf dem Plot)
-- ================================================================
local function baueGeschuetz(plot: any, position: Vector3, nummer: number)
	local function cf(versatz: Vector3, drehung: CFrame?): CFrame
		local basis = CFrame.new(position + versatz)
		return PlotService:ZuWeltCF(plot, drehung and basis * drehung or basis)
	end

	local model = Instance.new("Model")
	model.Name = "Geschuetz" .. nummer

	local sockel = Util.NeuerPart({
		Name = "Sockel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 8, 8),
		Color = Color3.fromRGB(50, 56, 76),
		Material = Enum.Material.Metal,
		CFrame = cf(Vector3.new(0, 1.5, 0), CFrame.Angles(0, 0, math.rad(90))),
	})
	sockel.Parent = model

	local turm = Util.NeuerPart({
		Name = "Turm",
		Size = Vector3.new(4.5, 3.5, 4.5),
		Color = Color3.fromRGB(66, 74, 98),
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = cf(Vector3.new(0, 4.8, 0)),
	})
	turm.Parent = model
	model.PrimaryPart = turm

	local lauf = Util.NeuerPart({
		Name = "Lauf",
		Size = Vector3.new(1.2, 1.2, 9),
		Color = Color3.fromRGB(38, 44, 62),
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = cf(Vector3.new(0, 5.6, -3.5), CFrame.Angles(math.rad(-25), 0, 0)),
	})
	lauf.Parent = model

	local spitze = Util.NeuerPart({
		Name = "Spitze",
		Size = Vector3.new(1.8, 1.8, 1.2),
		Color = Color3.fromRGB(200, 150, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = cf(Vector3.new(0, 7.4, -7.3)),
	})
	spitze.Parent = model

	return model
end

-- Baut genau so viele Geschuetze, wie die Technologiestufe vorgibt.
function ImperiumService:GeschuetzeAktualisieren(spieler: Player)
	local plot = PlotService:GetPlot(spieler)
	if not plot then
		return
	end

	-- Eigener Ordner: Der Rebirth-Neuaufbau leert nur "Gebaeude",
	-- unsere Geschuetze verwalten wir selbst.
	local ordner = plot.Model:FindFirstChild("Verteidigung")
	if not ordner then
		ordner = Instance.new("Folder")
		ordner.Name = "Verteidigung"
		ordner.Parent = plot.Model
	end
	ordner:ClearAllChildren()

	local stufe = CurrencyService:GetTechStufe(spieler, "Orbitalgeschuetze")
	for i = 1, math.min(stufe, #GESCHUETZ_PLAETZE) do
		local geschuetz = baueGeschuetz(plot, GESCHUETZ_PLAETZE[i], i)
		geschuetz.Parent = ordner
	end
end

-- ================================================================
-- TECHNOLOGIE KAUFEN
-- ================================================================
function ImperiumService:TechKaufen(spieler: Player, techId: any)
	-- 1) Gueltige Id?
	if type(techId) ~= "string" then
		return
	end
	local tech = TechConfig.NachId[techId]
	if not tech then
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	daten.Tech = daten.Tech or {}
	local stufe = daten.Tech[techId] or 0

	-- 2) Schon auf Maximalstufe?
	local preis = TechConfig.Preis(techId, stufe)
	if not preis then
		melden(spieler, tech.Name .. " ist bereits voll ausgebaut.", "Warnung")
		return
	end

	-- 3) Bezahlbar? (Abbuchen prueft den Kontostand selbst)
	if not CurrencyService:Abbuchen(spieler, preis) then
		melden(spieler, "Nicht genug Credits für " .. tech.Name, "Warnung")
		return
	end

	daten.Tech[techId] = stufe + 1

	melden(spieler, ("%s Stufe %d erforscht"):format(tech.Name, stufe + 1), "Gold")
	log(spieler.Name, "erforscht", techId, "Stufe", stufe + 1)

	-- Wirkungen, die sofort sichtbar werden
	if techId == "Orbitalgeschuetze" then
		self:GeschuetzeAktualisieren(spieler)
	end

	CurrencyService:MarkiereAenderung(spieler)
	FleetService:Senden(spieler)
	self:Senden(spieler)
end

-- ================================================================
-- REBIRTH
-- ================================================================
function ImperiumService:KannRebirth(spieler: Player): (boolean, number)
	local daten = DataService:Get(spieler)
	if not daten then
		return false, 0
	end

	local schwelle = TechConfig.RebirthSchwelle(daten.Rebirths or 0)
	return daten.Statistik.GesamtVerdient >= schwelle, schwelle
end

function ImperiumService:RebirthDurchfuehren(spieler: Player)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	local erlaubt, schwelle = self:KannRebirth(spieler)
	if not erlaubt then
		melden(
			spieler,
			("Du brauchst %s %s Gesamtverdienst."):format(
				Util.FormatGeld(schwelle),
				Config.Spiel.Waehrung
			),
			"Warnung"
		)
		return
	end

	-- ZURUECKGESETZT wird der Tycoon-Fortschritt ...
	daten.Geld = Config.Spiel.StartGeld
	daten.Lager = 0
	daten.Gekauft = {}
	daten.Flotte = {}
	daten.Bauauftraege = {}
	daten.HangarStufe = 0

	-- ... ERHALTEN bleiben Planeten, Technologien und der Gesamtverdienst.
	-- Der Gesamtverdienst ist wichtig: Die naechste Schwelle ist kumulativ,
	-- sonst muesste man jedes Mal komplett von vorn anfangen.
	daten.Rebirths = (daten.Rebirths or 0) + 1

	-- Station leeren und aus dem frischen Spielstand neu aufbauen.
	-- Das Zugewiesen-Signal darin laesst auch Buttons und Hangar neu bauen.
	PlotService:NeuAufbauen(spieler)
	self:GeschuetzeAktualisieren(spieler)

	CurrencyService:MarkiereAenderung(spieler)
	FleetService.FlotteGeaendert:Feuern(spieler)
	FleetService:Senden(spieler)
	self:Senden(spieler)

	-- Sofort speichern: Ein Rebirth ist zu wertvoll, um ihn bei einem
	-- Serverabsturz zu verlieren.
	task.spawn(function()
		DataService:Speichern(spieler)
	end)

	melden(
		spieler,
		("REBIRTH %d!  Dauerhaft +%d %% Einkommen"):format(
			daten.Rebirths,
			math.floor(daten.Rebirths * Config.Multiplikatoren.BonusProRebirth * 100)
		),
		"Gold"
	)
	log(spieler.Name, "Rebirth", daten.Rebirths)
end

-- ================================================================
-- AN DEN CLIENT SCHICKEN
-- ================================================================
function ImperiumService:Senden(spieler: Player)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	local stufen, preise = {}, {}
	for _, tech in TechConfig.Technologien do
		local stufe = (daten.Tech and daten.Tech[tech.Id]) or 0
		stufen[tech.Id] = stufe
		preise[tech.Id] = TechConfig.Preis(tech.Id, stufe)
	end

	local kannRebirth, schwelle = self:KannRebirth(spieler)

	Net:Event("ImperiumUpdate"):FireClient(spieler, {
		Tech = stufen,
		TechPreise = preise,
		Rebirths = daten.Rebirths or 0,
		RebirthSchwelle = schwelle,
		GesamtVerdient = math.floor(daten.Statistik.GesamtVerdient),
		KannRebirth = kannRebirth,
		BonusProRebirth = Config.Multiplikatoren.BonusProRebirth,
		Shop = MonetizationService:GetShopInfo(spieler),
	})
end

-- ================================================================
-- INIT
-- ================================================================
function ImperiumService:Init()
	Net:Event("ImperiumAnfrage").OnServerEvent:Connect(function(spieler)
		self:Senden(spieler)
	end)

	Net:Event("TechKaufen").OnServerEvent:Connect(function(spieler, techId)
		self:TechKaufen(spieler, techId)
	end)

	Net:Event("RebirthStarten").OnServerEvent:Connect(function(spieler)
		self:RebirthDurchfuehren(spieler)
	end)

	-- Geschuetze aufstellen, sobald ein Plot zugewiesen wurde
	PlotService.Zugewiesen:Verbinden(function(spieler, _plot)
		self:GeschuetzeAktualisieren(spieler)
	end)

	-- ... und abbauen, wenn der Plot frei wird. Sonst wuerden die Tuerme
	-- des Vorgaengers auf einer leeren Station stehen bleiben.
	PlotService.Freigegeben:Verbinden(function(_spieler, plot)
		local ordner = plot.Model:FindFirstChild("Verteidigung")
		if ordner then
			ordner:ClearAllChildren()
		end
	end)

	-- Die Laeufe schwenken langsam hin und her. Eine Schleife fuer alle.
	RunService.Heartbeat:Connect(function()
		local winkel = math.sin(os.clock() * 0.4) * 0.6

		for _, plot in PlotService.Plots do
			local ordner = plot.Model:FindFirstChild("Verteidigung")
			if ordner then
				for _, geschuetz in ordner:GetChildren() do
					local turm = geschuetz:FindFirstChild("Turm")
					if turm and turm:IsA("BasePart") then
						local lauf = geschuetz:FindFirstChild("Lauf")
						local spitze = geschuetz:FindFirstChild("Spitze")
						-- plot.Ursprung.Rotation bringt die Drehung der Station
						-- mit ein. Ohne sie schwenkten die Laeufe um eine feste
						-- Weltachse und staenden quer zum Turm.
						local drehung = CFrame.new(turm.Position)
							* plot.Ursprung.Rotation
							* CFrame.Angles(0, winkel, 0)

						if lauf and lauf:IsA("BasePart") then
							lauf.CFrame = drehung
								* CFrame.new(0, 0.8, -3.5)
								* CFrame.Angles(math.rad(-25), 0, 0)
						end
						if spitze and spitze:IsA("BasePart") then
							spitze.CFrame = drehung * CFrame.new(0, 2.6, -7.3)
						end
					end
				end
			end
		end
	end)

	log("bereit")
end

function ImperiumService:SpielerVorbereiten(spieler: Player)
	self:GeschuetzeAktualisieren(spieler)
	self:Senden(spieler)
end

return ImperiumService
