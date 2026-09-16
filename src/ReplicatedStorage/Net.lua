--[[
	Net  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ReplicatedStorage > Net

	WARUM HIER?
	RemoteEvents sind die einzige Bruecke zwischen Server und Client.
	Beide Seiten muessen dieselben Objekte finden -> ReplicatedStorage.

	WAS MACHT DAS MODUL?
	Du musst die RemoteEvents NICHT von Hand im Explorer anlegen.
	Der Server erstellt sie beim Start automatisch, der Client wartet
	darauf. Das verhindert den klassischen Anfaengerfehler
	"attempt to index nil with FireServer".

	BENUTZUNG:
	    local Net = require(ReplicatedStorage.Net)
	    Net:Event("GeldUpdate"):FireClient(spieler, daten)   -- Server
	    Net:Event("GeldUpdate").OnClientEvent:Connect(...)   -- Client
	================================================================
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local ORDNER_NAME = "Remotes"
local WARTEZEIT = 20 -- Sekunden, die der Client maximal auf den Server wartet

-- Alle RemoteEvents des Spiels. Neue Features tragen hier ihren Namen ein.
local EVENT_NAMEN = {
	-- Server -> Client
	"DatenUpdate",       -- Geld, Lager, Multiplikator, Rebirths ...
	"Benachrichtigung",  -- Toast-Meldung ("Zu wenig Credits!")
	"KaufBestaetigt",    -- Feedback fuer Sound/Effekt beim Kauf

	-- Client -> Server
	"DatenAnfrage",      -- Client bittet um eine frische Kopie seiner Daten
	"SammelAnfrage",     -- Spieler drueckt den "Sammeln"-Knopf in der GUI
}

-- RemoteFunctions (Client fragt, Server antwortet). Aktuell noch leer,
-- kommt bei Flotte/Planeten dazu.
local FUNKTION_NAMEN = {}

local ordnerCache: Folder? = nil

local function holeOrdner(): Folder
	if ordnerCache and ordnerCache.Parent then
		return ordnerCache
	end

	if RunService:IsServer() then
		local ordner = ReplicatedStorage:FindFirstChild(ORDNER_NAME)
		if not ordner then
			ordner = Instance.new("Folder")
			ordner.Name = ORDNER_NAME
			ordner.Parent = ReplicatedStorage
		end
		ordnerCache = ordner :: Folder
	else
		ordnerCache = ReplicatedStorage:WaitForChild(ORDNER_NAME, WARTEZEIT) :: Folder
		assert(ordnerCache, "[Net] Remotes-Ordner nicht gefunden - laeuft der Server-Main-Script?")
	end

	return ordnerCache :: Folder
end

-- Wird EINMAL vom Server aufgerufen (in Main). Legt alle Remotes an.
function Net:ServerInit()
	assert(RunService:IsServer(), "[Net] ServerInit darf nur auf dem Server laufen.")
	local ordner = holeOrdner()

	for _, name in EVENT_NAMEN do
		if not ordner:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = ordner
		end
	end

	for _, name in FUNKTION_NAMEN do
		if not ordner:FindFirstChild(name) then
			local funktion = Instance.new("RemoteFunction")
			funktion.Name = name
			funktion.Parent = ordner
		end
	end
end

function Net:Event(name: string): RemoteEvent
	local ordner = holeOrdner()
	local remote = ordner:WaitForChild(name, WARTEZEIT)
	assert(remote, ("[Net] RemoteEvent '%s' existiert nicht. In EVENT_NAMEN eintragen!"):format(name))
	return remote :: RemoteEvent
end

function Net:Function(name: string): RemoteFunction
	local ordner = holeOrdner()
	local remote = ordner:WaitForChild(name, WARTEZEIT)
	assert(remote, ("[Net] RemoteFunction '%s' existiert nicht. In FUNKTION_NAMEN eintragen!"):format(name))
	return remote :: RemoteFunction
end

return Net
