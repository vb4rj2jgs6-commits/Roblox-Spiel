--[[
	WorldBuilder  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > WorldBuilder

	AUFGABE
	Baut den Weltraum-Look komplett per Code auf: Licht, Sternenhimmel,
	Atmosphaere. So musst du in Studio nichts von Hand einstellen und
	kannst das Projekt jederzeit auf einen leeren Platz kopieren.

	KUNSTRICHTUNG: Low-Poly / flache Farben, kaum Schatten,
	wenige Parts -> laeuft fluessig auf Handys.
	================================================================
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))

local WorldBuilder = {}

local function beleuchtungSetzen()
	Lighting.Ambient = Color3.fromRGB(40, 44, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(30, 34, 50)
	Lighting.Brightness = 2
	Lighting.ClockTime = 0             -- Nacht = Weltraum
	Lighting.GeographicLatitude = 0
	Lighting.GlobalShadows = false     -- Schatten aus = deutlich schneller auf Mobile
	Lighting.FogEnd = 100000
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4

	-- Alte Himmel/Effekte entfernen, damit ein zweiter Start nicht doppelt baut
	for _, kind in Lighting:GetChildren() do
		if kind:IsA("Sky") or kind:IsA("BloomEffect") or kind:IsA("ColorCorrectionEffect") then
			kind:Destroy()
		end
	end

	-- Roblox-Standard-Sternenhimmel (kostenlos, keine eigenen Assets noetig)
	local himmel = Instance.new("Sky")
	himmel.SkyboxBk = "rbxassetid://12064107"
	himmel.SkyboxDn = "rbxassetid://12064152"
	himmel.SkyboxFt = "rbxassetid://12064121"
	himmel.SkyboxLf = "rbxassetid://12064175"
	himmel.SkyboxRt = "rbxassetid://12064131"
	himmel.SkyboxUp = "rbxassetid://12064161"
	himmel.StarCount = 5000
	himmel.SunAngularSize = 8
	himmel.MoonAngularSize = 0
	himmel.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 20
	bloom.Threshold = 1.2
	bloom.Parent = Lighting

	local farbe = Instance.new("ColorCorrectionEffect")
	farbe.Saturation = 0.15
	farbe.Contrast = 0.1
	farbe.TintColor = Color3.fromRGB(225, 232, 255)
	farbe.Parent = Lighting
end

-- Entfernt die graue Standard-Baseplate, falls sie noch da ist.
local function baseplateEntfernen()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	local spawn = Workspace:FindFirstChild("SpawnLocation")
	if spawn and spawn:IsA("SpawnLocation") then
		spawn:Destroy()
	end
end

-- Asteroidenguertel weit ausserhalb der Plots.
-- Rein optisch: keine Kollision, keine Abfragen -> kostet fast nichts.
-- Random.new mit festem Startwert, damit die Karte bei jedem Serverstart
-- gleich aussieht. Ohne den Startwert waere jeder Server anders.
local function asteroidenStreuen(ordner: Folder)
	local einstellungen = Config.Welt.Asteroidenguertel
	local zufall = Random.new(2024)

	for i = 1, einstellungen.Anzahl do
		local groesse = zufall:NextNumber(einstellungen.MinGroesse, einstellungen.MaxGroesse)
		local winkel = zufall:NextNumber(0, math.pi * 2)
		local radius = zufall:NextNumber(einstellungen.InnenRadius, einstellungen.AussenRadius)

		local fels = Util.NeuerPart({
			Name = "Asteroid_" .. i,
			Size = Vector3.new(groesse, groesse * 0.7, groesse * 0.9),
			Color = Color3.fromRGB(
				zufall:NextInteger(55, 85),
				zufall:NextInteger(55, 80),
				zufall:NextInteger(65, 95)
			),
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(
				math.cos(winkel) * radius,
				zufall:NextNumber(-einstellungen.HoehenStreuung, einstellungen.HoehenStreuung),
				math.sin(winkel) * radius
			) * CFrame.Angles(
				zufall:NextNumber(0, 6),
				zufall:NextNumber(0, 6),
				zufall:NextNumber(0, 6)
			),
		})
		fels.Parent = ordner
	end
end

-- ================================================================
-- ZENTRALSTATION
--
-- Der Mittelpunkt der Karte. Die Spieler-Stationen liegen im Ring
-- darum herum und sind ueber Stege mit ihr verbunden (die Stege baut
-- der PlotService, weil nur er die Lage der Stationen kennt).
--
-- Sie ist bewusst begehbar: Damit entsteht ein Treffpunkt, an dem man
-- die Nachbarn sieht — das macht aus sechs Einzel-Plots eine Karte.
-- ================================================================
local function baueZentralstation(ordner: Folder)
	local einstellungen = Config.Welt.Zentralstation
	if not einstellungen.Aktiv then
		return
	end

	local radius = einstellungen.Radius
	local hoehe = einstellungen.Hoehe

	local station = Instance.new("Model")
	station.Name = "Zentralstation"
	station.Parent = ordner

	-- Begehbare Ringplattform. Ein Zylinder liegt flach, wenn man ihn
	-- um 90 Grad um die Z-Achse dreht: Size ist dann (Dicke, Durchmesser,
	-- Durchmesser).
	local deck = Util.NeuerPart({
		Name = "Deck",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5, radius * 2, radius * 2),
		Color = Config.Plot.DeckFarbe,
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(0, hoehe - 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	deck.Parent = station
	station.PrimaryPart = deck

	local rand = Util.NeuerPart({
		Name = "Rand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, radius * 2 + 6, radius * 2 + 6),
		Color = Config.Plot.RandFarbe,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(0, hoehe - 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	rand.Parent = station

	-- Turm in der Mitte
	local turm = Util.NeuerPart({
		Name = "Turm",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(70, 34, 34),
		Color = Color3.fromRGB(54, 60, 82),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(0, hoehe + 35, 0) * CFrame.Angles(0, 0, math.rad(90)),
	})
	turm.Parent = station

	local kuppel = Util.NeuerPart({
		Name = "Kuppel",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(44, 44, 44),
		Color = Config.Plot.RandFarbe,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(0, hoehe + 72, 0),
	})
	kuppel.Parent = station

	local licht = Instance.new("PointLight")
	licht.Brightness = 3
	licht.Range = 120
	licht.Color = Config.Plot.RandFarbe
	licht.Parent = kuppel

	-- Beschriftung, von allen Stationen aus lesbar
	local tafel = Instance.new("BillboardGui")
	tafel.Name = "Beschriftung"
	tafel.Size = UDim2.fromScale(40, 8)
	tafel.StudsOffsetWorldSpace = Vector3.new(0, 34, 0)
	tafel.MaxDistance = 900
	tafel.Parent = kuppel

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(200, 240, 255)
	text.TextStrokeTransparency = 0.4
	text.Text = Config.Spiel.Name
	text.Parent = tafel

	-- Dockkragen: Dort, wo die Stege der Spieler ankommen.
	-- Wir rechnen mit denselben Winkeln wie der PlotService, damit
	-- Kragen und Steg genau aufeinandertreffen.
	if einstellungen.Dockarme then
		for index = 1, Config.Plot.Anzahl do
			local winkel = (index - 1) / Config.Plot.Anzahl * math.pi * 2
			local richtung = Vector3.new(math.cos(winkel), 0, math.sin(winkel))

			local kragen = Util.NeuerPart({
				Name = "Dockkragen" .. index,
				Size = Vector3.new(Config.Plot.BrueckeBreite + 8, 7, 14),
				Color = Color3.fromRGB(62, 70, 94),
				Material = Enum.Material.Metal,
				CFrame = CFrame.lookAt(
					Vector3.new(0, hoehe + 1.5, 0) + richtung * (radius - 2),
					Vector3.new(0, hoehe + 1.5, 0) + richtung * (radius + 20)
				),
			})
			kragen.Parent = station

			local lampe = Util.NeuerPart({
				Name = "Docklicht" .. index,
				Size = Vector3.new(Config.Plot.BrueckeBreite + 8, 1, 1.6),
				Color = Color3.fromRGB(120, 255, 180),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CFrame = CFrame.lookAt(
					Vector3.new(0, hoehe + 5.2, 0) + richtung * (radius + 4),
					Vector3.new(0, hoehe + 5.2, 0) + richtung * (radius + 24)
				),
			})
			lampe.Parent = station
		end
	end

	return station
end

function WorldBuilder:Bauen()
	beleuchtungSetzen()
	baseplateEntfernen()

	-- Ordnerstruktur im Workspace. Ordnung im Explorer = weniger Chaos spaeter.
	local alt = Workspace:FindFirstChild("Welt")
	if alt then
		alt:Destroy()
	end

	local welt = Instance.new("Folder")
	welt.Name = "Welt"
	welt.Parent = Workspace

	local deko = Instance.new("Folder")
	deko.Name = "Deko"
	deko.Parent = welt

	asteroidenStreuen(deko)
	baueZentralstation(welt)

	-- Zentralstern als reines Leuchtobjekt am Rand der Karte
	local stern = Config.Welt.Zentralstern
	local sonne = Util.NeuerPart({
		Name = "Zentralstern",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(stern.Radius * 2, stern.Radius * 2, stern.Radius * 2),
		Position = stern.Position,
		Material = Enum.Material.Neon,
		Color = stern.Farbe,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	sonne.Parent = deko

	if Config.Spiel.DebugAusgaben then
		print("[WorldBuilder] Weltraum-Umgebung aufgebaut")
	end

	return welt
end

return WorldBuilder
