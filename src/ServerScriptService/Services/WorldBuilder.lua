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

-- Ein paar dekorative Asteroiden weit ausserhalb der Plots.
-- Rein optisch, keine Kollision -> kostet fast keine Performance.
local function asteroidenStreuen(ordner: Folder)
	local zufall = Random.new(2024)
	for i = 1, 40 do
		local groesse = zufall:NextNumber(12, 45)
		local winkel = zufall:NextNumber(0, math.pi * 2)
		local radius = zufall:NextNumber(500, 1400)

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
				zufall:NextNumber(-250, 350),
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

	-- Zentrale Sonne als reines Leuchtobjekt in der Mitte der Karte
	local sonne = Util.NeuerPart({
		Name = "Zentralstern",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(180, 180, 180),
		Position = Vector3.new(0, 900, -2200),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 190, 120),
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
