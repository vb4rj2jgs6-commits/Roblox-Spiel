--[[
	PlanetService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > PlanetService

	AUFGABE
	Baut die Planeten in die Welt, verwaltet wer welchen besitzt und
	rechnet die aktuelle Verteidigung aus.

	WICHTIG ZUM SPEICHERN — bitte einmal lesen:
	Planetenbesitz gilt PRO SERVER. Roblox startet fuer je ~6 Spieler
	einen eigenen Server, und ein DataStore fuer gemeinsamen Besitz
	ueber alle Server hinweg waere deutlich komplizierter (und wuerde
	staendig Konflikte erzeugen).

	Wir machen es so:
	  - Der Spieler speichert seine Planeten in daten.Planeten
	  - Beim Beitreten bekommt er jeden davon zurueck, DER IM AKTUELLEN
	    SERVER NOCH FREI IST
	  - Ist er belegt, verliert er ihn (und bekommt eine Meldung)

	Das ist einfach, nachvollziehbar und fuehlt sich fair an: In einem
	leeren Server hast du deine Planeten sofort wieder.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlanetConfig = require(ReplicatedStorage:WaitForChild("PlanetConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Signal = require(ReplicatedStorage:WaitForChild("Signal"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local FleetService = require(script.Parent.FleetService)

local PlanetService = {}

-- [PlanetId] = Laufzeit-Zustand
PlanetService.Planeten = {} :: { [string]: any }

PlanetService.BesitzGeaendert = Signal.neu()

local FREI_FARBE = Color3.fromRGB(150, 155, 170)

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[PlanetService]", ...)
	end
end

-- Jeder Spieler bekommt eine feste Farbe, abgeleitet aus seiner UserId.
-- So hat derselbe Spieler immer dieselbe Farbe — auch nach einem Neustart.
local function spielerFarbe(spieler: Player): Color3
	local ton = (spieler.UserId % 360) / 360
	return Color3.fromHSV(ton, 0.65, 1)
end

-- ================================================================
-- PLANETEN BAUEN
-- ================================================================
local function bauePlanet(eintrag: any)
	local typ = PlanetConfig.Typen[eintrag.Typ]

	local model = Instance.new("Model")
	model.Name = eintrag.Id

	local kugel = Util.NeuerPart({
		Name = "Kugel",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(eintrag.Radius * 2, eintrag.Radius * 2, eintrag.Radius * 2),
		Color = typ.Farbe,
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(eintrag.Position),
	})
	kugel.Parent = model
	model.PrimaryPart = kugel

	-- Leuchtende Atmosphaere: eine groessere, halbtransparente Kugel
	local huelle = Util.NeuerPart({
		Name = "Atmosphaere",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(eintrag.Radius * 2.25, eintrag.Radius * 2.25, eintrag.Radius * 2.25),
		Color = typ.Atmosphaere,
		Material = Enum.Material.Neon,
		Transparency = 0.82,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(eintrag.Position),
	})
	huelle.Parent = model

	-- Besitzer-Ring. Seine Farbe zeigt aus grosser Entfernung, wem der
	-- Planet gehoert — das ist die wichtigste Information auf der Karte.
	local ring = Util.NeuerPart({
		Name = "Ring",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.5, eintrag.Radius * 3.4, eintrag.Radius * 3.4),
		Color = FREI_FARBE,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(eintrag.Position) * CFrame.Angles(0, 0, math.rad(90)),
	})
	ring.Parent = model

	local schild = Instance.new("BillboardGui")
	schild.Name = "Info"
	schild.Size = UDim2.fromScale(26, 9)
	schild.StudsOffsetWorldSpace = Vector3.new(0, eintrag.Radius + 16, 0)
	schild.MaxDistance = 2500
	schild.Parent = kugel

	local rahmen = Instance.new("Frame")
	rahmen.Size = UDim2.fromScale(1, 1)
	rahmen.BackgroundTransparency = 1
	rahmen.Parent = schild

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rahmen

	local function zeile(reihenfolge: number, hoehe: number, farbe: Color3, schrift: Enum.Font)
		local label = Instance.new("TextLabel")
		label.LayoutOrder = reihenfolge
		label.Size = UDim2.fromScale(1, hoehe)
		label.BackgroundTransparency = 1
		label.Font = schrift
		label.TextScaled = true
		label.TextColor3 = farbe
		label.TextStrokeTransparency = 0.35
		label.Text = ""
		label.Parent = rahmen
		return label
	end

	local nameLabel = zeile(1, 0.38, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
	nameLabel.Text = string.upper(eintrag.Name)

	local typLabel = zeile(2, 0.26, typ.Atmosphaere, Enum.Font.GothamBold)
	typLabel.Text = typ.Name .. "  ·  " .. typ.BonusText

	local statusLabel = zeile(3, 0.30, FREI_FARBE, Enum.Font.GothamBold)
	statusLabel.Text = "UNBESETZT"

	return {
		Id = eintrag.Id,
		Config = eintrag,
		Typ = typ,
		Model = model,
		Kugel = kugel,
		Ring = ring,
		NameLabel = nameLabel,
		StatusLabel = statusLabel,

		Besitzer = nil :: Player?,
		-- Aktuelle NPC-Verteidigung. Faellt nach einem gescheiterten
		-- Angriff nicht, steigt aber nach Verlusten wieder an.
		Verteidigung = eintrag.Verteidigung,
		SchildBis = 0,
	}
end

-- ================================================================
-- VERTEIDIGUNG BERECHNEN
-- ================================================================
function PlanetService:GetVerteidigung(planetId: string): number
	local zustand = self.Planeten[planetId]
	if not zustand then
		return 0
	end

	local basis = zustand.Verteidigung
	local besitzer = zustand.Besitzer

	-- Unbesetzter NPC-Planet: reine Basisverteidigung
	if not besitzer or not besitzer.Parent then
		return math.floor(basis)
	end

	-- Von einem Spieler gehalten: Festungswelten und die Schildmatrix
	-- verstaerken die Basis, dazu kommt ein Teil seiner Flotte.
	local faktor = 1
		+ CurrencyService:GetPlanetenTypBonus(besitzer, "Verteidigung")
		+ CurrencyService:GetTechStufe(besitzer, "Schildmatrix") * 0.2

	local flottenAnteil = FleetService:GetVerteidigung(besitzer)
		* PlanetConfig.Kampf.AnteilFlottenVerteidigung

	return math.floor(basis * faktor + flottenAnteil)
end

function PlanetService:HatSchild(planetId: string): boolean
	local zustand = self.Planeten[planetId]
	return zustand ~= nil and os.clock() < zustand.SchildBis
end

-- ================================================================
-- BESITZ
-- ================================================================
local function anzeigeAktualisieren(zustand: any)
	local besitzer = zustand.Besitzer

	if besitzer and besitzer.Parent then
		local farbe = spielerFarbe(besitzer)
		zustand.Ring.Color = farbe
		zustand.Ring.Transparency = 0.1
		zustand.StatusLabel.TextColor3 = farbe
		zustand.StatusLabel.Text = string.upper(besitzer.DisplayName)
	else
		zustand.Ring.Color = FREI_FARBE
		zustand.Ring.Transparency = 0.25
		zustand.StatusLabel.TextColor3 = FREI_FARBE
		zustand.StatusLabel.Text = "UNBESETZT"
	end
end

function PlanetService:Zuweisen(spieler: Player?, planetId: string, mitSchild: boolean)
	local zustand = self.Planeten[planetId]
	if not zustand then
		return
	end

	-- Alten Besitzer sauber austragen
	local alterBesitzer = zustand.Besitzer
	if alterBesitzer and alterBesitzer ~= spieler then
		local alteDaten = DataService:Get(alterBesitzer)
		if alteDaten then
			alteDaten.Planeten[planetId] = nil
			CurrencyService:MarkiereAenderung(alterBesitzer)
		end
	end

	zustand.Besitzer = spieler

	if spieler then
		local daten = DataService:Get(spieler)
		if daten then
			daten.Planeten[planetId] = true
			CurrencyService:MarkiereAenderung(spieler)
		end
		-- Frisch erobert: Verteidigung startet wieder auf dem Basiswert
		zustand.Verteidigung = zustand.Config.Verteidigung
		if mitSchild then
			zustand.SchildBis = os.clock() + PlanetConfig.Kampf.SchildNachEroberung
		end
	else
		zustand.SchildBis = 0
	end

	anzeigeAktualisieren(zustand)
	self.BesitzGeaendert:Feuern(planetId, spieler, alterBesitzer)
	self:SendenAnAlle()
end

-- Beim Beitreten gespeicherte Planeten zurueckgeben, soweit noch frei.
function PlanetService:SpielerVorbereiten(spieler: Player)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	local zurueck, verloren = 0, 0

	for planetId in daten.Planeten do
		local zustand = self.Planeten[planetId]

		if not zustand then
			-- Planet gibt es in der Config nicht mehr
			daten.Planeten[planetId] = nil
		elseif zustand.Besitzer == nil then
			zustand.Besitzer = spieler
			zustand.Verteidigung = zustand.Config.Verteidigung
			anzeigeAktualisieren(zustand)
			zurueck += 1
		else
			-- Schon von jemand anderem besetzt
			daten.Planeten[planetId] = nil
			verloren += 1
		end
	end

	if zurueck > 0 then
		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = zurueck .. " Planet(en) unter deiner Kontrolle",
			Farbe = "Gold",
		})
	end
	if verloren > 0 then
		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = verloren .. " Planet(en) sind in diesem Sektor bereits besetzt",
			Farbe = "Warnung",
		})
	end

	CurrencyService:MarkiereAenderung(spieler)
	self:SendenAnAlle()
end

-- Beim Verlassen alle Planeten wieder freigeben (sie bleiben im
-- Spielstand gespeichert und kommen beim naechsten Beitritt zurueck).
function PlanetService:SpielerVerlaesst(spieler: Player)
	local geaendert = false

	for _, zustand in self.Planeten do
		if zustand.Besitzer == spieler then
			zustand.Besitzer = nil
			zustand.SchildBis = 0
			anzeigeAktualisieren(zustand)
			geaendert = true
		end
	end

	if geaendert then
		self:SendenAnAlle()
	end
end

-- ================================================================
-- AN DIE CLIENTS SCHICKEN
-- ================================================================
function PlanetService:BaueUebersicht(): { any }
	local liste = {}

	for _, eintrag in PlanetConfig.Planeten do
		local zustand = self.Planeten[eintrag.Id]
		local besitzer = zustand and zustand.Besitzer

		table.insert(liste, {
			Id = eintrag.Id,
			Verteidigung = self:GetVerteidigung(eintrag.Id),
			BesitzerName = (besitzer and besitzer.Parent) and besitzer.DisplayName or nil,
			BesitzerId = (besitzer and besitzer.Parent) and besitzer.UserId or nil,
			SchildRest = zustand and math.max(0, zustand.SchildBis - os.clock()) or 0,
		})
	end

	return liste
end

function PlanetService:SendenAnAlle()
	local uebersicht = self:BaueUebersicht()
	Net:Event("PlanetUpdate"):FireAllClients(uebersicht)
end

function PlanetService:Senden(spieler: Player)
	Net:Event("PlanetUpdate"):FireClient(spieler, self:BaueUebersicht())
end

-- ================================================================
-- INIT
-- ================================================================
function PlanetService:Init(welt: Folder)
	local ordner = Instance.new("Folder")
	ordner.Name = "Planeten"
	ordner.Parent = welt

	for _, eintrag in PlanetConfig.Planeten do
		local zustand = bauePlanet(eintrag)
		zustand.Model.Parent = ordner
		self.Planeten[eintrag.Id] = zustand
	end

	log(#PlanetConfig.Planeten .. " Planeten gebaut")

	Net:Event("PlanetAnfrage").OnServerEvent:Connect(function(spieler)
		self:Senden(spieler)
	end)

	Players.PlayerRemoving:Connect(function(spieler)
		self:SpielerVerlaesst(spieler)
	end)

	-- Planeten drehen sich langsam. Eine Schleife fuer alle zusammen.
	RunService.Heartbeat:Connect(function()
		local zeit = os.clock()
		for _, zustand in self.Planeten do
			zustand.Kugel.CFrame = CFrame.new(zustand.Config.Position)
				* CFrame.Angles(0, zeit * 0.05, 0)
		end
	end)

	-- Unbesetzte Planeten bauen ihre Verteidigung nach und nach wieder auf.
	task.spawn(function()
		while true do
			task.wait(5)

			local geaendert = false
			for _, zustand in self.Planeten do
				if not zustand.Besitzer and zustand.Verteidigung < zustand.Config.Verteidigung then
					zustand.Verteidigung = math.min(
						zustand.Config.Verteidigung,
						zustand.Verteidigung
							+ zustand.Config.Verteidigung * PlanetConfig.Kampf.RegenerationProSekunde * 5
					)
					geaendert = true
				end
			end

			if geaendert then
				self:SendenAnAlle()
			end
		end
	end)

	log("bereit")
end

return PlanetService
