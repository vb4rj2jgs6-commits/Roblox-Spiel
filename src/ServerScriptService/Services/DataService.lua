--[[
	DataService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > DataService

	WARUM HIER?
	ServerScriptService ist fuer Clients UNSICHTBAR. Spielstaende und
	Geld-Logik duerfen niemals auf dem Client landen — sonst kann ein
	Exploiter sie manipulieren. Deshalb liegen ALLE Services hier.

	AUFGABE
	- Laedt beim Betreten die Spielerdaten aus dem DataStore
	- Haelt sie im Arbeitsspeicher (schneller Zugriff fuer andere Services)
	- Speichert automatisch alle X Sekunden, beim Verlassen und beim
	  Server-Shutdown (BindToClose)

	HINWEIS FUER SPAETER
	Fuer ein echtes Live-Spiel lohnt sich zusaetzlich "Session Locking"
	(z. B. die kostenlose Bibliothek ProfileService), damit derselbe
	Spieler nicht auf zwei Servern gleichzeitig speichert. Fuer den
	Anfang reicht diese Version voellig.
	================================================================
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))

local DataService = {}

-- ================================================================
-- STANDARD-SPIELSTAND
-- Felder fuer spaetere Systeme (Flotte, Planeten, Tech) sind schon
-- angelegt. So bleiben alte Spielstaende kompatibel, wenn wir die
-- Features nachruesten.
-- ================================================================
local STANDARD_DATEN = {
	Version = 1,
	Geld = Config.Spiel.StartGeld,
	Lager = 0,
	Gekauft = {},        -- ["Dropper_Erz_1"] = true
	Rebirths = 0,

	-- Flotte (Schritt 2)
	Flotte = {},         -- ["Jaeger"] = 3
	Bauauftraege = {},   -- { { Klasse = "Jaeger", FertigUm = <Zeitstempel> }, ... }
	HangarStufe = 0,

	-- Platzhalter fuer die naechsten Schritte
	Planeten = {},       -- Liste eroberter Planeten-Ids
	Tech = {},           -- Technologie-Baum
	Gamepasses = {},     -- Cache, damit wir nicht staendig nachfragen

	Statistik = {
		GesamtVerdient = 0,
		Beitritte = 0,
		SpielzeitSekunden = 0,
	},
}

local datastore = DataStoreService:GetDataStore(Config.Speicher.DataStoreName)
local cache: { [number]: any } = {}        -- [UserId] = Datentabelle
local ladeStatus: { [number]: boolean } = {} -- [UserId] = true, wenn fertig geladen
local schliesstGerade = false

-- Speichern im Studio nur, wenn ausdruecklich erlaubt.
local function darfSpeichern(): boolean
	if RunService:IsStudio() and not Config.Speicher.InStudioSpeichern then
		return false
	end
	return true
end

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[DataService]", ...)
	end
end

-- Wiederholt eine DataStore-Aktion mit wachsender Wartezeit (2s, 4s, 8s ...).
-- DataStore-Aufrufe koennen bei Netzwerkproblemen fehlschlagen — das ist normal.
local function mitWiederholung(aktion: () -> any): (boolean, any)
	local wartezeit = Config.Speicher.WartenZwischenVersuchen

	for versuch = 1, Config.Speicher.MaxVersuche do
		local erfolg, ergebnis = pcall(aktion)
		if erfolg then
			return true, ergebnis
		end

		warn(("[DataService] Versuch %d/%d fehlgeschlagen: %s")
			:format(versuch, Config.Speicher.MaxVersuche, tostring(ergebnis)))

		if versuch < Config.Speicher.MaxVersuche then
			task.wait(wartezeit)
			wartezeit *= 2
		end
	end

	return false, nil
end

-- Ergaenzt fehlende Felder, falls wir spaeter neue Felder hinzufuegen.
-- Ohne das wuerden alte Spielstaende nach einem Update crashen.
local function auffuellen(daten: any, vorlage: any)
	for schluessel, standardWert in vorlage do
		if daten[schluessel] == nil then
			if type(standardWert) == "table" then
				daten[schluessel] = Util.TiefeKopie(standardWert)
			else
				daten[schluessel] = standardWert
			end
		elseif type(standardWert) == "table" and type(daten[schluessel]) == "table" then
			auffuellen(daten[schluessel], standardWert)
		end
	end
end

-- ================================================================
-- OEFFENTLICHE FUNKTIONEN
-- ================================================================

-- Laedt die Daten eines Spielers. Gibt die Tabelle zurueck.
function DataService:Laden(spieler: Player)
	local schluessel = "Spieler_" .. spieler.UserId
	local daten = nil

	if darfSpeichern() then
		local erfolg, ergebnis = mitWiederholung(function()
			return datastore:GetAsync(schluessel)
		end)

		if not erfolg then
			-- Laden komplett fehlgeschlagen: Wir geben dem Spieler einen
			-- frischen Spielstand, verbieten aber das Speichern, damit wir
			-- keinen echten Fortschritt ueberschreiben.
			warn("[DataService] Laden fehlgeschlagen fuer " .. spieler.Name .. " - Speichern wird blockiert.")
			daten = Util.TiefeKopie(STANDARD_DATEN)
			daten._SpeichernBlockiert = true
			cache[spieler.UserId] = daten
			ladeStatus[spieler.UserId] = true
			return daten
		end

		daten = ergebnis
	end

	if type(daten) ~= "table" then
		daten = Util.TiefeKopie(STANDARD_DATEN)
		log("Neuer Spielstand fuer " .. spieler.Name)
	else
		auffuellen(daten, STANDARD_DATEN)
		log("Spielstand geladen fuer " .. spieler.Name)
	end

	daten.Statistik.Beitritte += 1
	daten._BeitrittsZeit = os.clock()

	cache[spieler.UserId] = daten
	ladeStatus[spieler.UserId] = true
	return daten
end

-- Holt die Daten aus dem Cache. Gibt nil zurueck, wenn noch nicht geladen.
-- ALLE anderen Services muessen dieses nil abfangen!
function DataService:Get(spieler: Player)
	return cache[spieler.UserId]
end

-- Wartet, bis die Daten geladen sind (max. 20 Sekunden).
function DataService:GetWarten(spieler: Player)
	local abbruch = os.clock() + 20
	while not ladeStatus[spieler.UserId] and os.clock() < abbruch do
		if not spieler.Parent then
			return nil
		end
		task.wait(0.1)
	end
	return cache[spieler.UserId]
end

function DataService:Speichern(spieler: Player): boolean
	local daten = cache[spieler.UserId]
	if not daten then
		return false
	end

	if daten._SpeichernBlockiert then
		log("Speichern uebersprungen (Laden war fehlgeschlagen): " .. spieler.Name)
		return false
	end

	-- Spielzeit mitschreiben
	if daten._BeitrittsZeit then
		daten.Statistik.SpielzeitSekunden += math.floor(os.clock() - daten._BeitrittsZeit)
		daten._BeitrittsZeit = os.clock()
	end

	if not darfSpeichern() then
		log("Studio-Modus: nicht wirklich gespeichert (" .. spieler.Name .. ")")
		return true
	end

	-- Felder mit "_" am Anfang sind nur zur Laufzeit interessant
	-- und werden nicht gespeichert.
	local zuSpeichern = {}
	for schluessel, wert in daten do
		if string.sub(tostring(schluessel), 1, 1) ~= "_" then
			zuSpeichern[schluessel] = wert
		end
	end

	local schluessel = "Spieler_" .. spieler.UserId
	local erfolg = mitWiederholung(function()
		-- UpdateAsync statt SetAsync: sicherer bei gleichzeitigen Zugriffen.
		datastore:UpdateAsync(schluessel, function()
			return zuSpeichern
		end)
		return true
	end)

	if erfolg then
		log("Gespeichert: " .. spieler.Name)
	else
		warn("[DataService] Speichern endgueltig fehlgeschlagen: " .. spieler.Name)
	end

	return erfolg
end

function DataService:Entladen(spieler: Player)
	self:Speichern(spieler)
	cache[spieler.UserId] = nil
	ladeStatus[spieler.UserId] = nil
end

function DataService:SpeichernAlle()
	for _, spieler in Players:GetPlayers() do
		task.spawn(function()
			self:Speichern(spieler)
		end)
	end
end

-- Setzt den Spielstand zurueck (fuer das Rebirth-System in Schritt 5).
function DataService:StandardDaten()
	return Util.TiefeKopie(STANDARD_DATEN)
end

function DataService:Init()
	-- Auto-Save-Schleife
	task.spawn(function()
		while not schliesstGerade do
			task.wait(Config.Speicher.AutoSaveIntervall)
			if schliesstGerade then break end
			self:SpeichernAlle()
		end
	end)

	-- Beim Server-Shutdown speichern. Roblox gibt uns dafuer ca. 30 Sekunden.
	game:BindToClose(function()
		schliesstGerade = true
		log("Server faehrt herunter - speichere alle Spieler ...")

		local offen = 0
		for _, spieler in Players:GetPlayers() do
			offen += 1
			task.spawn(function()
				self:Speichern(spieler)
				offen -= 1
			end)
		end

		local abbruch = os.clock() + 25
		while offen > 0 and os.clock() < abbruch do
			task.wait(0.2)
		end
	end)

	log("bereit")
end

return DataService
