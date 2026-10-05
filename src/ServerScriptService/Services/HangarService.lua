--[[
	HangarService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > HangarService

	AUFGABE
	Macht die Flotte sichtbar: Die Schiffe schweben in Formation im
	Orbit ueber dem eigenen Plot und drehen sich langsam.

	PERFORMANCE — der wichtigste Trick in dieser Datei:
	Alle Schiffe eines Spielers stecken in EINEM Model mit einem
	unsichtbaren Anker als PrimaryPart. Zum Drehen rufen wir einmal
	pro Plot Model:PivotTo() auf — nicht einmal pro Schiff. Bei 6
	Plots sind das 6 Aufrufe pro Frame statt ueber hundert.

	Ausserdem zeigen wir nie mehr als FleetConfig.Allgemein.MaxSichtbar
	Schiffe an. Wer 500 Jaeger hat, sieht trotzdem nur 24 — die Flotte
	selbst bleibt natuerlich vollstaendig.
	================================================================
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local FleetConfig = require(ReplicatedStorage:WaitForChild("FleetConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local FleetService = require(script.Parent.FleetService)

local HangarService = {}

local ABSTAND = 20        -- Studs zwischen zwei Schiffen
local PRO_REIHE = 6

-- ================================================================
-- SCHIFFSMODELLE (Low-Poly, komplett aus wenigen Parts)
-- ================================================================
local function baueSchiff(klasse: any): Model
	local model = Instance.new("Model")
	model.Name = klasse.Id

	local s = klasse.Skalierung

	-- Rumpf
	local rumpf = Util.NeuerPart({
		Name = "Rumpf",
		Size = Vector3.new(2.6 * s, 1.1 * s, 6 * s),
		Color = klasse.Farbe,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(0, 0, 0),
	})
	rumpf.Parent = model
	model.PrimaryPart = rumpf

	-- Bug (Keil nach vorne)
	local bug = Util.NeuerPart({
		Name = "Bug",
		Size = Vector3.new(1.6 * s, 0.9 * s, 2.4 * s),
		Color = klasse.Farbe,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(0, 0, -4 * s),
	})
	bug.Parent = model

	-- Zwei Fluegel
	for _, seite in { -1, 1 } do
		local fluegel = Util.NeuerPart({
			Name = "Fluegel",
			Size = Vector3.new(3.2 * s, 0.4 * s, 2.6 * s),
			Color = klasse.Farbe,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(seite * 2.6 * s, 0, 0.6 * s)
				* CFrame.Angles(0, 0, seite * math.rad(12)),
		})
		fluegel.Parent = model
	end

	-- Triebwerksglut hinten
	local triebwerk = Util.NeuerPart({
		Name = "Triebwerk",
		Size = Vector3.new(1.8 * s, 0.8 * s, 0.8 * s),
		Color = klasse.Akzent,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(0, 0, 3.4 * s),
	})
	triebwerk.Parent = model

	-- Grosse Klassen bekommen zusaetzliche Aufbauten,
	-- damit man sie im Orbit sofort unterscheiden kann.
	if klasse.Platzbedarf >= 4 then
		local bruecke = Util.NeuerPart({
			Name = "Bruecke",
			Size = Vector3.new(1.6 * s, 1.2 * s, 2 * s),
			Color = klasse.Akzent,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(0, 1.1 * s, 0.8 * s),
		})
		bruecke.Parent = model

		for _, seite in { -1, 1 } do
			local kanone = Util.NeuerPart({
				Name = "Kanone",
				Size = Vector3.new(0.7 * s, 0.7 * s, 4 * s),
				Color = Color3.fromRGB(45, 50, 66),
				Material = Enum.Material.Metal,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CFrame = CFrame.new(seite * 1.9 * s, -0.7 * s, -1.6 * s),
			})
			kanone.Parent = model
		end
	end

	return model
end

-- ================================================================
-- FORMATION
-- ================================================================

-- Welche Schiffe zeigen wir? Die staerksten zuerst — die sehen am
-- beeindruckendsten aus und sind das, worauf der Spieler stolz ist.
local function sichtbareAuswahl(flotte: { [string]: number }): { any }
	local klassenSortiert = table.clone(FleetConfig.Klassen)
	table.sort(klassenSortiert, function(a, b)
		return a.Angriff > b.Angriff
	end)

	local auswahl = {}
	local uebrig = FleetConfig.Allgemein.MaxSichtbar

	for _, klasse in klassenSortiert do
		if uebrig <= 0 then
			break
		end
		local anzahl = math.min(flotte[klasse.Id] or 0, uebrig)
		for _ = 1, anzahl do
			table.insert(auswahl, klasse)
			uebrig -= 1
		end
	end

	return auswahl
end

-- Position des n-ten Schiffs relativ zum Formations-Anker
local function formationsVersatz(index: number, gesamt: number): CFrame
	local zeile = (index - 1) // PRO_REIHE
	local spalte = (index - 1) % PRO_REIHE

	local schiffeInDieserZeile = math.min(PRO_REIHE, gesamt - zeile * PRO_REIHE)
	local zeilen = math.ceil(gesamt / PRO_REIHE)

	local x = (spalte - (schiffeInDieserZeile - 1) / 2) * ABSTAND
	local z = (zeile - (zeilen - 1) / 2) * ABSTAND

	-- Leichter Hoehenversatz pro Zeile: wirkt raeumlicher als ein flaches Gitter
	local y = zeile * 3

	return CFrame.new(x, y, z)
end

-- ================================================================
-- HANGAR AUFBAUEN
-- ================================================================
function HangarService:Aktualisieren(plot: any)
	local hangar = plot.HangarModel
	if not hangar then
		return
	end

	-- Alte Schiffe weg (der Anker bleibt stehen)
	for _, kind in hangar:GetChildren() do
		if kind ~= plot.HangarAnker then
			kind:Destroy()
		end
	end

	local spieler = plot.Besitzer
	if not spieler then
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	local auswahl = sichtbareAuswahl(daten.Flotte)
	local ankerCF = plot.HangarAnker.CFrame

	for index, klasse in auswahl do
		local schiff = baueSchiff(klasse)
		schiff:PivotTo(ankerCF * formationsVersatz(index, #auswahl))
		schiff.Parent = hangar
	end
end

-- Raeumt den Hangar leer. Wird gebraucht, wenn ein Plot frei wird:
-- Zu diesem Zeitpunkt steht plot.Besitzer noch, darum wuerde
-- Aktualisieren() die Schiffe faelschlich neu aufbauen.
function HangarService:Leeren(plot: any)
	local hangar = plot.HangarModel
	if not hangar then
		return
	end

	for _, kind in hangar:GetChildren() do
		if kind ~= plot.HangarAnker then
			kind:Destroy()
		end
	end
end

function HangarService:AktualisierenFuerSpieler(spieler: Player)
	local plot = PlotService:GetPlot(spieler)
	if plot then
		self:Aktualisieren(plot)
	end
end

-- ================================================================
-- INIT
-- ================================================================
function HangarService:Init()
	-- Fuer jeden Plot ein Hangar-Model mit unsichtbarem Anker anlegen.
	for _, plot in PlotService.Plots do
		local hangar = Instance.new("Model")
		hangar.Name = "Hangar"

		local anker = Util.NeuerPart({
			Name = "Anker",
			Size = Vector3.new(1, 1, 1),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = PlotService:ZuWeltCF(plot, CFrame.new(Config.PlotPunkte.Orbit)),
		})
		anker.Parent = hangar
		hangar.PrimaryPart = anker

		hangar.Parent = plot.Model

		plot.HangarModel = hangar
		plot.HangarAnker = anker
		plot.HangarGrundCF = anker.CFrame
	end

	-- Bei Plot-Zuweisung und Flottenaenderung neu aufbauen
	PlotService.Zugewiesen:Verbinden(function(_spieler, plot)
		self:Aktualisieren(plot)
	end)

	PlotService.Freigegeben:Verbinden(function(_spieler, plot)
		self:Leeren(plot)
	end)

	FleetService.FlotteGeaendert:Verbinden(function(spieler)
		self:AktualisierenFuerSpieler(spieler)
	end)

	-- Die Formation dreht sich langsam. EIN PivotTo pro Plot und Frame.
	RunService.Heartbeat:Connect(function()
		local winkel = os.clock() * FleetConfig.Allgemein.OrbitTempo * math.pi * 2

		for _, plot in PlotService.Plots do
			local hangar = plot.HangarModel
			-- Leerer Hangar (nur der Anker drin) -> nichts zu drehen
			if hangar and #hangar:GetChildren() > 1 then
				hangar:PivotTo(plot.HangarGrundCF * CFrame.Angles(0, winkel, 0))
			end
		end
	end)

	if Config.Spiel.DebugAusgaben then
		print("[HangarService] bereit")
	end
end

return HangarService
