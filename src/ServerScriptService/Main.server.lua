--[[
	Main  —  Script  (KEIN ModuleScript!)
	================================================================
	EXPLORER-ORT:  ServerScriptService > Main

	WARUM HIER?
	Ein normales "Script" im ServerScriptService startet automatisch,
	sobald der Server hochfaehrt. Es ist der EINZIGE Einstiegspunkt
	des Servers. Alles andere sind ModuleScripts, die von hier aus
	gestartet werden.

	WARUM NUR EIN EINSTIEGSPUNKT?
	Wenn 8 Scripts gleichzeitig starten, weiss niemand, was zuerst
	fertig ist ("race condition"). Hier legen wir die Reihenfolge
	selbst fest — das erspart dir extrem viel Fehlersuche.

	REIHENFOLGE (wichtig!):
	  1. Net          — Remotes anlegen, bevor irgendwer sie sucht
	  2. DataService  — Speichern muss laufen, bevor Spieler kommen
	  3. CurrencyService
	  4. WorldBuilder — Weltraum-Umgebung
	  5. PlotService  — braucht die Welt
	  6. ButtonService/DropperService — brauchen die Plots
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services.DataService)
local CurrencyService = require(Services.CurrencyService)
local WorldBuilder = require(Services.WorldBuilder)
local PlotService = require(Services.PlotService)
local ButtonService = require(Services.ButtonService)
local DropperService = require(Services.DropperService)

print(("=== %s startet ==="):format(Config.Spiel.Name))

-- ================================================================
-- 1) SYSTEME STARTEN
-- ================================================================
Net:ServerInit()

DataService:Init()
CurrencyService:Init()

local welt = WorldBuilder:Bauen()

PlotService:Init(welt)
ButtonService:Init()
DropperService:Init()

-- ================================================================
-- 2) SPIELER-LEBENSZYKLUS
-- ================================================================
local function spielerBetritt(spieler: Player)
	-- Reihenfolge ist wichtig: Erst Daten, dann alles, was Daten braucht.
	DataService:Laden(spieler)

	-- Spieler koennte waehrend des Ladens schon wieder weg sein
	if not spieler.Parent then
		DataService:Entladen(spieler)
		return
	end

	CurrencyService:LeaderstatsAnlegen(spieler)
	PlotService:Zuweisen(spieler)
	CurrencyService:Senden(spieler)

	-- Beim (Neu-)Spawn auf den eigenen Plot setzen
	local function beiCharakter(charakter: Model)
		charakter:WaitForChild("HumanoidRootPart", 10)

		-- Kurz warten, bis Roblox die Figur fertig platziert hat —
		-- sonst wird unser Teleport sofort wieder ueberschrieben.
		task.wait(0.2)
		PlotService:ZumPlotTeleportieren(spieler)
	end

	spieler.CharacterAdded:Connect(beiCharakter)
	if spieler.Character then
		task.spawn(beiCharakter, spieler.Character)
	end

	print(("[Main] %s ist beigetreten"):format(spieler.Name))
end

local function spielerVerlaesst(spieler: Player)
	PlotService:Freigeben(spieler)
	DataService:Entladen(spieler)   -- speichert automatisch
	print(("[Main] %s hat verlassen"):format(spieler.Name))
end

Players.PlayerAdded:Connect(function(spieler)
	-- task.spawn, damit ein langsamer DataStore-Ladevorgang nicht
	-- andere beitretende Spieler blockiert.
	task.spawn(spielerBetritt, spieler)
end)

Players.PlayerRemoving:Connect(spielerVerlaesst)

-- Spieler, die schon da waren, bevor dieses Script fertig geladen hat
-- (passiert im Studio-Test regelmaessig).
for _, spieler in Players:GetPlayers() do
	task.spawn(spielerBetritt, spieler)
end

print(("=== %s bereit ==="):format(Config.Spiel.Name))
