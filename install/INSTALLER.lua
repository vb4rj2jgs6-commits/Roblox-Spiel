--[[
	STELLAR DOMINION — Installer
	================================================================
	NICHT in den Explorer einfuegen!
	Diesen Text komplett kopieren und unten in Roblox Studio in die
	BEFEHLSLEISTE (View > Command Bar) einfuegen, dann Enter.

	Das Script legt alle Ordner und Scripts an der richtigen Stelle an.
	Erneutes Ausfuehren ueberschreibt sie — so spielst du Updates ein,
	ohne etwas von Hand zu loeschen.
	================================================================
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

-- Legt einen Ordner an bzw. gibt den vorhandenen zurueck
local function holeOrdner(eltern, name)
	local vorhanden = eltern:FindFirstChild(name)
	if vorhanden and not vorhanden:IsA("Folder") then
		vorhanden:Destroy()
		vorhanden = nil
	end
	if not vorhanden then
		vorhanden = Instance.new("Folder")
		vorhanden.Name = name
		vorhanden.Parent = eltern
	end
	return vorhanden
end

local ZIELE = {
	ReplicatedStorage = ReplicatedStorage,
	ServerScriptService = ServerScriptService,
	["ServerScriptService/Services"] = holeOrdner(ServerScriptService, "Services"),
	StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts"),
}

-- Reste aus frueheren Testlaeufen entfernen. Beide werden zur
-- Laufzeit neu erzeugt und gehoeren nicht in die gespeicherte Place.
for _, name in { "Remotes" } do
	local rest = ReplicatedStorage:FindFirstChild(name)
	if rest then rest:Destroy() end
end
local welt = Workspace:FindFirstChild("Welt")
if welt then welt:Destroy() end

local DATEIEN = {
	{
		Ziel = "ReplicatedStorage",
		Name = "FleetConfig",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	FleetConfig  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ReplicatedStorage > FleetConfig

	WARUM EINE EIGENE DATEI STATT ALLES IN GameConfig?
	GameConfig waere sonst irgendwann 1000 Zeilen lang. Ein Modul pro
	System haelt die Dateien lesbar — und du weisst immer sofort, wo
	du zum Balancen hin musst.

	Server UND Client brauchen diese Werte (Server rechnet, Client
	zeigt sie in der Werft an) -> deshalb ReplicatedStorage.
	================================================================
]]

local FleetConfig = {}

-- ================================================================
-- ALLGEMEINE FLOTTEN-REGELN
-- ================================================================
FleetConfig.Allgemein = {
	-- Hangar-Plaetze. Jedes Schiff belegt je nach Klasse 1-8 Plaetze.
	BasisKapazitaet = 12,
	SlotsProStufe = 8,
	MaxHangarStufe = 10,

	-- Preis fuer die naechste Hangar-Stufe:
	--   HangarBasisPreis * HangarPreisFaktor ^ aktuelleStufe
	HangarBasisPreis = 25000,
	HangarPreisFaktor = 2.2,

	-- Bau-Warteschlange
	MaxWarteschlange = 12,      -- so viele Auftraege gleichzeitig
	MaxProKauf = 10,            -- so viele Schiffe pro Klick

	-- Wie viele Schiffe maximal sichtbar im Orbit schweben.
	-- Rein optisch — die Flotte selbst ist unbegrenzt gross.
	-- Niedriger = bessere Performance auf Handys.
	MaxSichtbar = 24,

	OrbitTempo = 0.12,          -- Umdrehungen pro Sekunde (langsam = ruhig)
}

-- ================================================================
-- SCHIFFSKLASSEN
--
-- Angriff      = Beitrag zur Flottenstaerke (Schritt 3: Eroberung)
-- Verteidigung = zaehlt, wenn dich jemand angreift
-- Platzbedarf  = belegte Hangar-Plaetze
-- Bauzeit      = Sekunden. Die Warteschlange baut nacheinander.
-- Tempo        = Reisegeschwindigkeit (wird in Schritt 3 gebraucht)
-- Frachtraum   = Beute pro Angriff (wird in Schritt 3 gebraucht)
--
-- BALANCE-GEDANKE:
-- Grosse Schiffe sind pro Credit UND pro Hangar-Platz staerker,
-- brauchen aber deutlich laenger. Jaeger sind die Notloesung, wenn
-- du schnell Staerke brauchst — z. B. um einen Planeten zu halten,
-- der gerade angegriffen wird.
-- ================================================================
FleetConfig.Klassen = {
	{
		Id = "Jaeger",
		Name = "Jäger",
		Beschreibung = "Billig und sofort da. Gut, um schnell Lücken zu stopfen.",
		Preis = 2500,
		Angriff = 12,
		Verteidigung = 8,
		Platzbedarf = 1,
		Bauzeit = 6,
		Tempo = 100,
		Frachtraum = 40,
		Farbe = Color3.fromRGB(120, 200, 255),
		Akzent = Color3.fromRGB(60, 240, 255),
		Skalierung = 1,
	},
	{
		Id = "Fregatte",
		Name = "Fregatte",
		Beschreibung = "Der solide Allrounder für die mittlere Spielphase.",
		Preis = 12000,
		Angriff = 65,
		Verteidigung = 55,
		Platzbedarf = 2,
		Bauzeit = 15,
		Tempo = 80,
		Frachtraum = 220,
		Farbe = Color3.fromRGB(150, 165, 200),
		Akzent = Color3.fromRGB(90, 220, 180),
		Skalierung = 1.5,
	},
	{
		Id = "Kreuzer",
		Name = "Kreuzer",
		Beschreibung = "Schwere Artillerie. Rechnet sich ab dem Plasma-Reaktor.",
		Preis = 75000,
		Angriff = 480,
		Verteidigung = 400,
		Platzbedarf = 4,
		Bauzeit = 40,
		Tempo = 60,
		Frachtraum = 900,
		Farbe = Color3.fromRGB(190, 150, 230),
		Akzent = Color3.fromRGB(255, 120, 220),
		Skalierung = 2.2,
	},
	{
		Id = "Schlachtschiff",
		Name = "Schlachtschiff",
		Beschreibung = "Endgame. Langsam im Bau, aber nichts hält es auf.",
		Preis = 450000,
		Angriff = 3400,
		Verteidigung = 3000,
		Platzbedarf = 8,
		Bauzeit = 90,
		Tempo = 45,
		Frachtraum = 4000,
		Farbe = Color3.fromRGB(230, 180, 110),
		Akzent = Color3.fromRGB(255, 130, 60),
		Skalierung = 3.2,
	},
	{
		-- Exklusive Klasse fuer den Gamepass (Schritt 6 / Monetarisierung).
		-- Solange der Gamepass nicht existiert, zeigt die Werft sie als
		-- gesperrt an — verkauft werden kann sie nicht.
		Id = "Phantom",
		Name = "Phantom",
		Beschreibung = "Tarnkreuzer. Viel Feuerkraft auf wenig Hangar-Platz.",
		Preis = 220000,
		Angriff = 2400,
		Verteidigung = 1200,
		Platzbedarf = 3,
		Bauzeit = 50,
		Tempo = 120,
		Frachtraum = 1500,
		Farbe = Color3.fromRGB(70, 75, 95),
		Akzent = Color3.fromRGB(160, 90, 255),
		Skalierung = 2,
		NurGamepass = "PhantomFlotte",   -- Schluessel in daten.Gamepasses
	},
}

-- Schneller Zugriff ueber die Id: FleetConfig.NachId["Kreuzer"]
FleetConfig.NachId = {}
for reihenfolge, klasse in FleetConfig.Klassen do
	klasse.Reihenfolge = reihenfolge
	FleetConfig.NachId[klasse.Id] = klasse
end

-- Preis der naechsten Hangar-Stufe. Gibt nil zurueck, wenn schon max.
function FleetConfig.HangarPreis(aktuelleStufe: number): number?
	if aktuelleStufe >= FleetConfig.Allgemein.MaxHangarStufe then
		return nil
	end
	return math.floor(
		FleetConfig.Allgemein.HangarBasisPreis
			* FleetConfig.Allgemein.HangarPreisFaktor ^ aktuelleStufe
	)
end

return FleetConfig
]==],
	},
	{
		Ziel = "ReplicatedStorage",
		Name = "GameConfig",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	GameConfig  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ReplicatedStorage > GameConfig

	WARUM HIER?
	ReplicatedStorage ist der einzige Ordner, den Server UND Client lesen
	koennen. Balance-Werte braucht der Server (Rechnen) und der Client
	(Anzeigen) — deshalb liegt die Config hier und nicht im ServerStorage.

	WICHTIG: Hier stehen NUR Zahlen und Texte, keine Spiellogik.
	Wenn du das Spiel balancen willst, aenderst du ausschliesslich
	diese Datei. Kein anderes Script muss angefasst werden.
	================================================================
]]

local Config = {}

-- ================================================================
-- ALLGEMEIN
-- ================================================================
Config.Spiel = {
	Name = "STELLAR DOMINION",
	Waehrung = "CR",        -- Kuerzel, das in der GUI hinter der Zahl steht
	StartGeld = 0,          -- Womit ein neuer Spieler startet
	DebugAusgaben = true,   -- true = Server schreibt Infos in die Output-Konsole
}

-- ================================================================
-- SPEICHERSYSTEM (DataStore)
-- ================================================================
Config.Speicher = {
	-- Achtung: Wenn du diesen Namen aenderst, sind ALLE alten Spielstaende weg.
	-- Genau das ist beim Testen manchmal gewollt ("v1" -> "v2").
	DataStoreName = "StellarDominion_Spieler_v1",

	AutoSaveIntervall = 120,     -- Sekunden zwischen automatischen Speicherungen
	MaxVersuche = 4,             -- Wiederholungen bei Netzwerkfehlern
	WartenZwischenVersuchen = 2, -- Sekunden (verdoppelt sich bei jedem Versuch)

	-- In Roblox Studio ist DataStore-Zugriff oft blockiert
	-- ("Studio Access to API Services" ist standardmaessig aus).
	-- false = im Studio wird nur im Arbeitsspeicher gespeichert -> keine Fehler,
	--         aber der Fortschritt ist nach dem Test-Stop weg. Das ist zum
	--         Entwickeln meistens genau richtig.
	InStudioSpeichern = false,
}

-- ================================================================
-- PLOTS (die Raumstation-Plattformen der Spieler)
-- ================================================================
Config.Plot = {
	Anzahl = 6,                                  -- Wie viele Spieler gleichzeitig
	Groesse = Vector3.new(120, 4, 120),          -- Breite x Dicke x Tiefe
	Abstand = 200,                               -- Abstand der Plot-Mittelpunkte
	ProReihe = 3,                                -- Plots werden im Raster angeordnet
	Hoehe = 0,                                   -- Y-Position der Plot-Oberflaeche

	BodenFarbe   = Color3.fromRGB(38, 42, 58),
	RandFarbe    = Color3.fromRGB(0, 190, 255),  -- Neon-Kante (Weltraum-Look)
	FreiFarbe    = Color3.fromRGB(120, 120, 130),-- Schildfarbe, wenn Plot frei ist
}

-- ================================================================
-- MULTIPLIKATOREN
-- Formel (siehe CurrencyService):
--   Gesamt = (1 + Planeten * BonusProPlanet + Rebirths * BonusProRebirth)
--            * Gamepass-Multiplikatoren
-- ================================================================
Config.Multiplikatoren = {
	-- +50 % Einkommen pro eroberten Planeten, ADDITIV.
	-- 2 Planeten = +100 %, 3 Planeten = +150 % usw.
	-- Setze auf 0.25 fuer sanftere Progression, oder baue auf
	-- multiplikativ um (siehe Kommentar im CurrencyService).
	BonusProPlanet = 0.5,

	-- +25 % dauerhaft pro Rebirth (Prestige). Kommt in Schritt 5 zum Einsatz.
	BonusProRebirth = 0.25,

	-- Gamepass "Doppeltes Einkommen" (Schritt 6 / Monetarisierung)
	Gamepass2xEinkommen = 2,
}

-- ================================================================
-- LAGER (nicht eingesammelte Credits am Sammelkern)
-- ================================================================
Config.Lager = {
	Startkapazitaet = 300,       -- Wird durch Lager-Upgrades erhoeht
	AutoSammelIntervall = 4,     -- Sekunden (nur mit Auto-Collect-Gamepass)
	SammelReichweite = 60,       -- Studs: so nah muss der Spieler dem Kern sein,
	                             -- damit der Server einen Sammeln-Klick akzeptiert
}

-- ================================================================
-- DROPPER-TYPEN
-- Betrag  = Basis-Credits pro Lieferung
-- Intervall = Sekunden zwischen zwei Lieferungen
-- ================================================================
Config.DropperTypen = {
	Erz = {
		Name = "Erz-Extraktor",
		Betrag = 4,
		Intervall = 2.5,
		Farbe = Color3.fromRGB(200, 140, 70),
		Material = Enum.Material.Metal,
	},
	Eis = {
		Name = "Eis-Kondensator",
		Betrag = 26,
		Intervall = 2.2,
		Farbe = Color3.fromRGB(120, 220, 255),
		Material = Enum.Material.Ice,
	},
	Plasma = {
		Name = "Plasma-Reaktor",
		Betrag = 210,
		Intervall = 2.0,
		Farbe = Color3.fromRGB(255, 110, 200),
		Material = Enum.Material.Neon,
	},
	Antimaterie = {
		Name = "Antimaterie-Falle",
		Betrag = 1800,
		Intervall = 1.8,
		Farbe = Color3.fromRGB(180, 120, 255),
		Material = Enum.Material.Neon,
	},
}

-- ================================================================
-- KAUFBARE OBJEKTE (der eigentliche Tycoon-Fortschritt)
--
-- Jeder Eintrag erzeugt automatisch einen Kauf-Button auf dem Plot.
-- Felder:
--   Id           = eindeutiger Schluessel (wird so gespeichert!) — NIE aendern,
--                  sonst verlieren Spieler ihren Fortschritt an dieser Stelle
--   Name         = Text auf dem Button
--   Preis        = Kosten in Credits (0 = gratis)
--   Benoetigt    = Id, die vorher gekauft sein muss (nil = sofort sichtbar)
--   Typ          = "Dropper" | "Upgrade" | "Lager"
--   Position     = Lokale Position auf dem Plot (Mittelpunkt = 0,0,0)
--   ButtonPos    = Lokale Position des Kauf-Buttons
--   Wirkung      = nur bei Typ "Upgrade"/"Lager"
--
-- Reihenfolge der Liste = Reihenfolge im Spiel. Einfach erweiterbar.
-- ================================================================
Config.Kaufbares = {
	-- ---------- Stufe 1 ----------
	{ Id = "Dropper_Erz_1", Name = "Erz-Extraktor I", Preis = 0, Benoetigt = nil,
	  Typ = "Dropper", DropperTyp = "Erz",
	  Position = Vector3.new(-40, 0, 42), ButtonPos = Vector3.new(-24, 0, 42) },

	{ Id = "Upg_Wert_1", Name = "Raffinerie I  (+50% Wert)", Preis = 200, Benoetigt = "Dropper_Erz_1",
	  Typ = "Upgrade", Wirkung = { WertMultiplikator = 1.5 },
	  Position = Vector3.new(40, 0, 35), ButtonPos = Vector3.new(24, 0, 35) },

	{ Id = "Dropper_Erz_2", Name = "Erz-Extraktor II", Preis = 550, Benoetigt = "Upg_Wert_1",
	  Typ = "Dropper", DropperTyp = "Erz",
	  Position = Vector3.new(-40, 0, 28), ButtonPos = Vector3.new(-24, 0, 28) },

	{ Id = "Upg_Tempo_1", Name = "Foerderband I  (-15% Zeit)", Preis = 1200, Benoetigt = "Dropper_Erz_2",
	  Typ = "Upgrade", Wirkung = { TempoMultiplikator = 0.85 },
	  Position = Vector3.new(40, 0, 21), ButtonPos = Vector3.new(24, 0, 21) },

	{ Id = "Lager_1", Name = "Lagermodul I  (+700)", Preis = 2200, Benoetigt = "Upg_Tempo_1",
	  Typ = "Lager", Wirkung = { LagerBonus = 700 },
	  Position = Vector3.new(-14, 0, -34), ButtonPos = Vector3.new(-14, 0, -24) },

	-- ---------- Stufe 2 ----------
	{ Id = "Dropper_Eis_1", Name = "Eis-Kondensator I", Preis = 4500, Benoetigt = "Lager_1",
	  Typ = "Dropper", DropperTyp = "Eis",
	  Position = Vector3.new(-40, 0, 14), ButtonPos = Vector3.new(-24, 0, 14) },

	{ Id = "Upg_Wert_2", Name = "Raffinerie II  (+80% Wert)", Preis = 9500, Benoetigt = "Dropper_Eis_1",
	  Typ = "Upgrade", Wirkung = { WertMultiplikator = 1.8 },
	  Position = Vector3.new(40, 0, 7), ButtonPos = Vector3.new(24, 0, 7) },

	{ Id = "Dropper_Eis_2", Name = "Eis-Kondensator II", Preis = 18000, Benoetigt = "Upg_Wert_2",
	  Typ = "Dropper", DropperTyp = "Eis",
	  Position = Vector3.new(-40, 0, 0), ButtonPos = Vector3.new(-24, 0, 0) },

	{ Id = "Upg_Tempo_2", Name = "Foerderband II  (-15% Zeit)", Preis = 35000, Benoetigt = "Dropper_Eis_2",
	  Typ = "Upgrade", Wirkung = { TempoMultiplikator = 0.85 },
	  Position = Vector3.new(40, 0, -7), ButtonPos = Vector3.new(24, 0, -7) },

	{ Id = "Lager_2", Name = "Lagermodul II  (+6000)", Preis = 60000, Benoetigt = "Upg_Tempo_2",
	  Typ = "Lager", Wirkung = { LagerBonus = 6000 },
	  Position = Vector3.new(0, 0, -34), ButtonPos = Vector3.new(0, 0, -24) },

	-- ---------- Stufe 3 ----------
	{ Id = "Dropper_Plasma_1", Name = "Plasma-Reaktor I", Preis = 120000, Benoetigt = "Lager_2",
	  Typ = "Dropper", DropperTyp = "Plasma",
	  Position = Vector3.new(-40, 0, -14), ButtonPos = Vector3.new(-24, 0, -14) },

	{ Id = "Upg_Wert_3", Name = "Raffinerie III  (+120% Wert)", Preis = 240000, Benoetigt = "Dropper_Plasma_1",
	  Typ = "Upgrade", Wirkung = { WertMultiplikator = 2.2 },
	  Position = Vector3.new(40, 0, -21), ButtonPos = Vector3.new(24, 0, -21) },

	{ Id = "Dropper_Plasma_2", Name = "Plasma-Reaktor II", Preis = 480000, Benoetigt = "Upg_Wert_3",
	  Typ = "Dropper", DropperTyp = "Plasma",
	  Position = Vector3.new(-40, 0, -28), ButtonPos = Vector3.new(-24, 0, -28) },

	{ Id = "Upg_Tempo_3", Name = "Foerderband III  (-20% Zeit)", Preis = 900000, Benoetigt = "Dropper_Plasma_2",
	  Typ = "Upgrade", Wirkung = { TempoMultiplikator = 0.8 },
	  Position = Vector3.new(40, 0, -35), ButtonPos = Vector3.new(24, 0, -35) },

	{ Id = "Lager_3", Name = "Lagermodul III  (+60000)", Preis = 1500000, Benoetigt = "Upg_Tempo_3",
	  Typ = "Lager", Wirkung = { LagerBonus = 60000 },
	  Position = Vector3.new(14, 0, -34), ButtonPos = Vector3.new(14, 0, -24) },

	-- ---------- Stufe 4 ----------
	{ Id = "Dropper_Anti_1", Name = "Antimaterie-Falle I", Preis = 3500000, Benoetigt = "Lager_3",
	  Typ = "Dropper", DropperTyp = "Antimaterie",
	  Position = Vector3.new(-40, 0, -42), ButtonPos = Vector3.new(-24, 0, -42) },
}

-- ================================================================
-- FESTE ORTE AUF DEM PLOT (lokale Koordinaten)
-- ================================================================
Config.PlotPunkte = {
	Sammelkern = Vector3.new(0, 0, -46),   -- Hier landen die Lieferungen
	Spawn      = Vector3.new(0, 0, 48),    -- Hier erscheint der Spieler
	Werft      = Vector3.new(30, 0, 48),   -- Gebaeude zum Oeffnen der Flotten-GUI
	Orbit      = Vector3.new(0, 75, 0),    -- Mittelpunkt der schwebenden Flotte
}

return Config
]==],
	},
	{
		Ziel = "ReplicatedStorage",
		Name = "Net",
		Klasse = "ModuleScript",
		Quelle = [==[
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
	    Net:Event("DatenUpdate"):FireClient(spieler, daten)   -- Server
	    Net:Event("DatenUpdate").OnClientEvent:Connect(...)   -- Client
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
	"FlotteUpdate",      -- Flotte, Bauwarteschlange, Hangar, Staerke
	"PlanetUpdate",      -- Besitz und Verteidigung aller Planeten
	"KampfErgebnis",     -- Ergebnis eines Angriffs (Sieg/Niederlage, Verluste)
	"ImperiumUpdate",    -- Technologien, Rebirth-Stand und Shop

	-- Client -> Server
	"DatenAnfrage",      -- Client bittet um eine frische Kopie seiner Daten
	"SammelAnfrage",     -- Spieler drueckt den "Sammeln"-Knopf in der GUI
	"FlotteAnfrage",     -- Client bittet um frische Flottendaten
	"SchiffBauen",       -- "Ich haette gern N Schiffe der Klasse X"
	"HangarErweitern",   -- "Ich moechte die naechste Hangar-Stufe kaufen"
	"PlanetAnfrage",     -- Client bittet um frische Planetendaten
	"AngriffStarten",    -- "Ich greife Planet X an" — mehr schickt er nicht
	"ImperiumAnfrage",   -- Client bittet um Technologie-/Rebirth-Stand
	"TechKaufen",        -- "Ich moechte Technologie X eine Stufe hoeher"
	"RebirthStarten",    -- "Ich moechte einen Rebirth machen"
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
]==],
	},
	{
		Ziel = "ReplicatedStorage",
		Name = "PlanetConfig",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	PlanetConfig  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ReplicatedStorage > PlanetConfig

	Alle Werte rund um Planeten und Kaempfe.

	WICHTIG ZUM GRUNDBONUS:
	JEDER eroberte Planet gibt +50 % Einkommen. Dieser Wert steht in
	GameConfig.Multiplikatoren.BonusProPlanet und gilt fuer alle Typen.
	Der Planeten-TYP gibt ZUSAETZLICH einen Spezialbonus — siehe unten.
	================================================================
]]

local PlanetConfig = {}

-- ================================================================
-- KAMPFREGELN
--
-- SIEGCHANCE = Flottenstaerke / (Flottenstaerke + Verteidigung)
-- Gleich stark = 50 %. Doppelt so stark = 67 %. Diese Formel ist
-- bewusst simpel: Der Spieler kann sie im Kopf nachvollziehen.
-- ================================================================
PlanetConfig.Kampf = {
	Reisezeit = 4,                  -- Sekunden Flug bis zum Planeten
	AngriffsCooldown = 30,          -- Sekunden bis zum naechsten Angriff
	SchildNachEroberung = 180,      -- Schutzzeit fuer den neuen Besitzer

	MindestChance = 0.05,           -- nie ganz aussichtslos
	MaxChance = 0.95,               -- nie ganz sicher

	-- Verluste. "GegnerAnteil" = Verteidigung / (Staerke + Verteidigung).
	-- Einen viel schwaecheren Planeten zu nehmen kostet also fast nichts.
	VerlustBeiSieg = 0.30,
	VerlustBeiNiederlage = 0.55,
	GrundverlustNiederlage = 0.15,  -- kommt bei Niederlage obendrauf

	-- Wenn ein SPIELER den Planeten haelt, zaehlt ein Teil seiner
	-- Flotten-Verteidigung mit. Sonst waeren eroberte Planeten
	-- viel zu leicht wieder abzunehmen.
	AnteilFlottenVerteidigung = 0.2,

	-- NPC-Planeten bauen ihre Verteidigung langsam wieder auf,
	-- wenn ein Angriff gescheitert ist.
	RegenerationProSekunde = 0.004, -- Anteil der Basisverteidigung
}

-- ================================================================
-- PLANETENTYPEN
--
-- BonusArt legt fest, wo der Spezialbonus wirkt:
--   "Einkommen"    -> zusaetzlicher Einkommens-Multiplikator
--   "Bauzeit"      -> Schiffe bauen schneller
--   "Verteidigung" -> eigene Planeten sind schwerer einzunehmen
--   "Lager"        -> groesseres Lager am Sammelkern
--
-- Der Wert gilt PRO PLANET dieses Typs und ist additiv.
-- ================================================================
PlanetConfig.Typen = {
	Rohstoff = {
		Name = "Rohstoffwelt",
		Kurz = "ERZ",
		BonusArt = "Einkommen",
		BonusWert = 0.25,                       -- zusaetzlich zu den +50 %
		BonusText = "+25 % Einkommen extra",
		Farbe = Color3.fromRGB(205, 140, 75),
		Atmosphaere = Color3.fromRGB(255, 190, 120),
	},
	Energie = {
		Name = "Energiewelt",
		Kurz = "NRG",
		BonusArt = "Bauzeit",
		BonusWert = 0.08,
		BonusText = "-8 % Bauzeit in der Werft",
		Farbe = Color3.fromRGB(90, 210, 255),
		Atmosphaere = Color3.fromRGB(120, 240, 255),
	},
	Festung = {
		Name = "Festungswelt",
		Kurz = "FST",
		BonusArt = "Verteidigung",
		BonusWert = 0.30,
		BonusText = "+30 % Verteidigung aller Planeten",
		Farbe = Color3.fromRGB(160, 90, 95),
		Atmosphaere = Color3.fromRGB(255, 120, 130),
	},
	Handel = {
		Name = "Handelswelt",
		Kurz = "HDL",
		BonusArt = "Lager",
		BonusWert = 1.0,
		BonusText = "+100 % Lagerkapazität",
		Farbe = Color3.fromRGB(150, 210, 140),
		Atmosphaere = Color3.fromRGB(180, 255, 170),
	},
}

-- ================================================================
-- DIE PLANETEN
--
-- Sie liegen in einem weiten Ring um die Plots herum, damit man sie
-- von der eigenen Station aus sieht. Die Verteidigung steigt von
-- Planet zu Planet — das ist die Eroberungs-Reihenfolge.
--
-- Position = Weltkoordinate. Die Plots liegen im Bereich +-200,
-- darum starten die Planeten erst bei Radius ~750.
-- ================================================================
local function ringPosition(index: number, gesamt: number, radius: number, hoehe: number): Vector3
	local winkel = (index - 1) / gesamt * math.pi * 2
	return Vector3.new(math.cos(winkel) * radius, hoehe, math.sin(winkel) * radius)
end

PlanetConfig.Planeten = {
	{ Id = "P01", Name = "Ferra",     Typ = "Rohstoff", Verteidigung = 150,   Radius = 34 },
	{ Id = "P02", Name = "Lumen",     Typ = "Energie",  Verteidigung = 450,   Radius = 30 },
	{ Id = "P03", Name = "Kaskade",   Typ = "Handel",   Verteidigung = 1200,  Radius = 38 },
	{ Id = "P04", Name = "Obsidia",   Typ = "Festung",  Verteidigung = 3000,  Radius = 42 },
	{ Id = "P05", Name = "Tessara",   Typ = "Rohstoff", Verteidigung = 6500,  Radius = 36 },
	{ Id = "P06", Name = "Helios IV", Typ = "Energie",  Verteidigung = 12000, Radius = 44 },
	{ Id = "P07", Name = "Novaris",   Typ = "Handel",   Verteidigung = 20000, Radius = 40 },
	{ Id = "P08", Name = "Draconis",  Typ = "Festung",  Verteidigung = 30000, Radius = 48 },
	{ Id = "P09", Name = "Xanthe",    Typ = "Rohstoff", Verteidigung = 42000, Radius = 46 },
	{ Id = "P10", Name = "Zenith",    Typ = "Energie",  Verteidigung = 55000, Radius = 50 },
	{ Id = "P11", Name = "Morgath",   Typ = "Festung",  Verteidigung = 68000, Radius = 54 },
	{ Id = "P12", Name = "Aurelia",   Typ = "Handel",   Verteidigung = 80000, Radius = 58 },
}

-- Positionen automatisch auf zwei Ringe verteilen.
-- So musst du beim Hinzufuegen eines Planeten keine Koordinaten ausrechnen.
for index, planet in PlanetConfig.Planeten do
	local innererRing = index <= 6
	planet.Position = ringPosition(
		innererRing and index or (index - 6),
		6,
		innererRing and 800 or 1250,
		innererRing and 180 or 320
	)
	planet.Reihenfolge = index
end

PlanetConfig.NachId = {}
for _, planet in PlanetConfig.Planeten do
	PlanetConfig.NachId[planet.Id] = planet
end

-- ================================================================
-- HILFSFUNKTIONEN (Server UND Client benutzen sie, damit beide
-- dieselbe Zahl anzeigen bzw. berechnen)
-- ================================================================

-- Siegchance als Wert zwischen 0 und 1.
function PlanetConfig.Siegchance(staerke: number, verteidigung: number): number
	if staerke <= 0 then
		return 0
	end
	local roh = staerke / (staerke + math.max(1, verteidigung))
	return math.clamp(roh, PlanetConfig.Kampf.MindestChance, PlanetConfig.Kampf.MaxChance)
end

-- Anteil der Flotte, der bei diesem Kampf verloren geht.
function PlanetConfig.Verlustanteil(staerke: number, verteidigung: number, gewonnen: boolean): number
	local gegnerAnteil = math.max(1, verteidigung) / (math.max(1, staerke) + math.max(1, verteidigung))

	if gewonnen then
		return math.clamp(PlanetConfig.Kampf.VerlustBeiSieg * gegnerAnteil, 0, 0.9)
	end

	return math.clamp(
		PlanetConfig.Kampf.VerlustBeiNiederlage * gegnerAnteil
			+ PlanetConfig.Kampf.GrundverlustNiederlage,
		0,
		0.9
	)
end

return PlanetConfig
]==],
	},
	{
		Ziel = "ReplicatedStorage",
		Name = "Signal",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	Signal  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ReplicatedStorage > Signal

	WOFUER?
	Ein "Signal" ist ein selbstgebautes Event: Ein Service ruft
	:Feuern(...) auf, alle angemeldeten Funktionen laufen los.
	Damit muss z. B. der PlotService den ButtonService nicht kennen —
	das verhindert zirkulaere require()-Ketten, die in Roblox zu
	endlosem Haengenbleiben fuehren.

	WARUM NICHT EINFACH EIN BindableEvent?
	Das ist ein haeufiger, sehr schwer zu findender Anfaengerfehler:
	Ein BindableEvent KOPIERT jede Tabelle, die man durchschickt.
	Der Empfaenger bekommt also nicht dieselbe Tabelle, sondern ein
	Duplikat. Aenderungen daran verpuffen. Fuer unsere Plot-Tabellen
	waere das fatal. Ein reines Lua-Signal reicht Werte 1:1 weiter.
	================================================================
]]

local Signal = {}
Signal.__index = Signal

export type Verbindung = { Trennen: (Verbindung) -> () }

function Signal.neu()
	return setmetatable({ _hoerer = {} }, Signal)
end

-- Meldet eine Funktion an. Rueckgabe: Objekt mit :Trennen()
function Signal:Verbinden(funktion: (...any) -> ())
	table.insert(self._hoerer, funktion)

	local verbindung = {}
	function verbindung:Trennen()
		local index = table.find(self._signal._hoerer, funktion)
		if index then
			table.remove(self._signal._hoerer, index)
		end
	end
	verbindung._signal = self

	return verbindung
end

-- Ruft alle angemeldeten Funktionen auf.
-- Jede laeuft in einem eigenen Thread mit Fehlerabfang: Ein Fehler in
-- einem Hoerer darf die anderen nicht mitreissen.
function Signal:Feuern(...)
	for _, funktion in table.clone(self._hoerer) do
		local argumente = table.pack(...)
		task.spawn(function()
			local erfolg, fehler = pcall(funktion, table.unpack(argumente, 1, argumente.n))
			if not erfolg then
				warn("[Signal] Fehler in einem Hoerer: " .. tostring(fehler))
			end
		end)
	end
end

-- Wie Feuern, aber sofort im selben Thread (Reihenfolge garantiert).
-- Nutzen, wenn die Reaktion abgeschlossen sein muss, bevor es weitergeht.
function Signal:FeuernSofort(...)
	for _, funktion in table.clone(self._hoerer) do
		local erfolg, fehler = pcall(funktion, ...)
		if not erfolg then
			warn("[Signal] Fehler in einem Hoerer: " .. tostring(fehler))
		end
	end
end

function Signal:Leeren()
	table.clear(self._hoerer)
end

return Signal
]==],
	},
	{
		Ziel = "ReplicatedStorage",
		Name = "TechConfig",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	TechConfig  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ReplicatedStorage > TechConfig

	Enthaelt drei Themen, die alle zum "Imperium"-Fenster gehoeren:
	  1. Technologie-Baum
	  2. Rebirth / Prestige
	  3. Monetarisierung (Gamepass- und Produkt-Ids)
	================================================================
]]

local TechConfig = {}

-- ================================================================
-- TECHNOLOGIE-BAUM
--
-- Preis der naechsten Stufe = Basispreis * Faktor ^ aktuelleStufe
-- Technologien bleiben beim Rebirth ERHALTEN — sie sind der
-- Langzeit-Fortschritt.
-- ================================================================
TechConfig.Technologien = {
	{
		Id = "Waffensysteme",
		Name = "Waffensysteme",
		Beschreibung = "+15 % Angriff der gesamten Flotte pro Stufe.",
		MaxStufe = 8,
		Basispreis = 40000,
		Faktor = 2.4,
		Farbe = Color3.fromRGB(255, 120, 110),
	},
	{
		Id = "Werftautomatik",
		Name = "Werftautomatik",
		Beschreibung = "-10 % Bauzeit in der Werft pro Stufe.",
		MaxStufe = 6,
		Basispreis = 30000,
		Faktor = 2.6,
		Farbe = Color3.fromRGB(120, 220, 180),
	},
	{
		Id = "Schildmatrix",
		Name = "Schildmatrix",
		Beschreibung = "+20 % Verteidigung deiner eroberten Planeten pro Stufe.",
		MaxStufe = 6,
		Basispreis = 60000,
		Faktor = 2.6,
		Farbe = Color3.fromRGB(130, 170, 255),
	},
	{
		Id = "Frachtsysteme",
		Name = "Frachtsysteme",
		Beschreibung = "+25 % Lagerkapazität pro Stufe.",
		MaxStufe = 6,
		Basispreis = 25000,
		Faktor = 2.2,
		Farbe = Color3.fromRGB(255, 205, 90),
	},
	{
		Id = "Orbitalgeschuetze",
		Name = "Orbitalgeschütze",
		Beschreibung = "Schützt dein Lager vor Piraten. Baut sichtbare Türme auf deinem Plot.",
		MaxStufe = 5,
		Basispreis = 15000,
		Faktor = 2.8,
		Farbe = Color3.fromRGB(200, 150, 255),
	},
}

TechConfig.NachId = {}
for reihenfolge, tech in TechConfig.Technologien do
	tech.Reihenfolge = reihenfolge
	TechConfig.NachId[tech.Id] = tech
end

function TechConfig.Preis(techId: string, aktuelleStufe: number): number?
	local tech = TechConfig.NachId[techId]
	if not tech or aktuelleStufe >= tech.MaxStufe then
		return nil
	end
	return math.floor(tech.Basispreis * tech.Faktor ^ aktuelleStufe)
end

-- ================================================================
-- REBIRTH / PRESTIGE
--
-- Voraussetzung ist der GESAMTVERDIENST, nicht das aktuelle Guthaben.
-- So kann man sich nicht durch Sparen an einem Rebirth vorbeimogeln,
-- und Ausgeben wird nicht bestraft.
-- ================================================================
TechConfig.Rebirth = {
	Grundschwelle = 250000,
	Faktor = 6,

	-- Was beim Rebirth passiert (nur zur Anzeige im Fenster —
	-- die echte Logik steht im RebirthService):
	WirdZurueckgesetzt = {
		"Guthaben und Lager",
		"Alle Basis-Ausbauten",
		"Die komplette Flotte samt Hangar",
	},
	BleibtErhalten = {
		"Eroberte Planeten",
		"Alle Technologien",
		"Der Rebirth-Bonus selbst",
	},
}

function TechConfig.RebirthSchwelle(rebirths: number): number
	return math.floor(TechConfig.Rebirth.Grundschwelle * TechConfig.Rebirth.Faktor ^ rebirths)
end

-- ================================================================
-- ZUFALLSEREIGNISSE
-- ================================================================
TechConfig.Ereignisse = {
	MinAbstand = 180,   -- Sekunden zwischen zwei Ereignissen
	MaxAbstand = 360,

	Meteoritenschauer = {
		Name = "Meteoritenschauer",
		Text = "Ein Meteoritenschauer zieht durch das System — doppeltes Einkommen!",
		Dauer = 90,
		Multiplikator = 2,
	},
	Piratenueberfall = {
		Name = "Piraten-Überfall",
		Warnung = "Piraten im Anflug! Sammle dein Lager, bevor sie da sind!",
		Vorwarnzeit = 20,
		-- Anteil des Lagers, den die Piraten stehlen.
		-- Jede Stufe Orbitalgeschuetze zieht SchutzProStufe ab.
		Grundverlust = 0.5,
		SchutzProStufe = 0.1,
	},
	Handelskonvoi = {
		Name = "Handelskonvoi",
		Text = "Ein Handelskonvoi macht Halt — sammle die Frachtkisten ein!",
		Dauer = 45,
		-- Bonus = so viele Sekunden Produktion, pro Kiste
		SekundenProduktion = 25,
		Kisten = 3,
	},
}

-- ================================================================
-- MONETARISIERUNG
--
-- ⚠️ WICHTIG: Die Ids stehen alle auf 0 = "noch nicht angelegt".
-- Solange eine Id 0 ist, wird der Eintrag im Shop ausgegraut und der
-- Server ignoriert ihn — das Spiel laeuft also ohne Fehler, auch wenn
-- du noch keine Gamepasses erstellt hast.
--
-- SO LEGST DU SIE AN:
--   Gamepass:  Creator Dashboard > dein Spiel > Monetization >
--              Passes > Create Pass. Danach die Id aus der URL
--              (.../game-pass/1234567/...) hier eintragen.
--   Produkt:   Monetization > Developer Products > Create.
-- ================================================================
TechConfig.Gamepasses = {
	{
		Schluessel = "DoppeltesEinkommen",
		Id = 0,
		Name = "Doppeltes Einkommen",
		Beschreibung = "Dauerhaft x2 auf alle Credits aus deiner Produktion.",
	},
	{
		Schluessel = "AutoCollect",
		Id = 0,
		Name = "Auto-Sammler",
		Beschreibung = "Dein Lager wird automatisch geleert. Nie wieder laufen.",
	},
	{
		Schluessel = "PhantomFlotte",
		Id = 0,
		Name = "Phantom-Flotte",
		Beschreibung = "Schaltet die exklusive Schiffsklasse Phantom frei.",
	},
}

TechConfig.Produkte = {
	{
		Schluessel = "CreditsKlein",
		Id = 0,
		Name = "Credit-Paket S",
		Beschreibung = "Sofort 10 Minuten Produktion gutgeschrieben.",
		Art = "Credits",
		SekundenProduktion = 600,
		Mindestbetrag = 5000,   -- damit auch Anfaenger etwas Brauchbares bekommen
	},
	{
		Schluessel = "CreditsMittel",
		Id = 0,
		Name = "Credit-Paket M",
		Beschreibung = "Sofort 1 Stunde Produktion gutgeschrieben.",
		Art = "Credits",
		SekundenProduktion = 3600,
		Mindestbetrag = 25000,
	},
	{
		Schluessel = "CreditsGross",
		Id = 0,
		Name = "Credit-Paket L",
		Beschreibung = "Sofort 6 Stunden Produktion gutgeschrieben.",
		Art = "Credits",
		SekundenProduktion = 21600,
		Mindestbetrag = 150000,
	},
	{
		Schluessel = "WerftSofort",
		Id = 0,
		Name = "Werft beschleunigen",
		Beschreibung = "Stellt alle Schiffe in der Bauwarteschlange sofort fertig.",
		Art = "SkipBau",
	},
}

TechConfig.GamepassNachId = {}
for _, pass in TechConfig.Gamepasses do
	if pass.Id ~= 0 then
		TechConfig.GamepassNachId[pass.Id] = pass
	end
end

TechConfig.ProduktNachId = {}
for _, produkt in TechConfig.Produkte do
	if produkt.Id ~= 0 then
		TechConfig.ProduktNachId[produkt.Id] = produkt
	end
end

return TechConfig
]==],
	},
	{
		Ziel = "ReplicatedStorage",
		Name = "UiKit",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	UiKit  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ReplicatedStorage > UiKit

	WOFUER?
	Ein kleiner Baukasten fuer die Oberflaeche: Farben, abgerundete
	Ecken, Raender, Standard-Knoepfe. Damit sehen HUD und Werft
	automatisch gleich aus — und wenn du das Farbschema aendern
	willst, aenderst du es genau hier an einer Stelle.

	Ausserdem verwaltet UiKit die AKTIONSLEISTE am linken Bildrand.
	Jedes Client-Script kann sich dort mit einer Zeile einen Knopf
	dazuhaengen. So kann Schritt 3 (Planeten) spaeter einfach einen
	weiteren Knopf ergaenzen, ohne das HUD-Script anzufassen.

	Dieses Modul wird nur von LocalScripts benutzt.
	================================================================
]]

local Players = game:GetService("Players")

local UiKit = {}

-- ================================================================
-- FARBSCHEMA
-- ================================================================
UiKit.Farben = {
	Panel = Color3.fromRGB(16, 19, 30),
	PanelHell = Color3.fromRGB(26, 31, 46),
	PanelRand = Color3.fromRGB(0, 190, 255),
	Text = Color3.fromRGB(235, 242, 255),
	TextGedimmt = Color3.fromRGB(140, 155, 180),
	Akzent = Color3.fromRGB(0, 220, 255),
	Gut = Color3.fromRGB(70, 230, 140),
	Warnung = Color3.fromRGB(255, 90, 100),
	Gold = Color3.fromRGB(255, 205, 90),
	Inaktiv = Color3.fromRGB(60, 68, 88),
}

-- Uebersetzt den Farbnamen aus einer Server-Benachrichtigung in eine Farbe.
function UiKit.FarbeAusName(name: string?): Color3
	if name == "Warnung" then
		-- ================================================================
-- FENSTER
--
-- Alle Menue-Fenster (Werft, Sternenkarte, Imperium) sehen gleich aus:
-- abgedunkelter Hintergrund, Panel in der Mitte, Kopfzeile mit Titel
-- und Schliessen-Kreuz. Diese Funktion baut genau das und gibt dir den
-- leeren Inhaltsbereich zurueck.
--
-- Benutzung:
--     local fenster = UiKit.Fenster({ Name = "MeinGui", Titel = "WERFT" })
--     -- ... etwas in fenster.Inhalt bauen ...
--     fenster:SetzeOffen(true)
-- ================================================================
function UiKit.Fenster(konfiguration: { [string]: any })
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UiKit.Neu("ScreenGui", {
		Name = konfiguration.Name or "Fenster",
		ResetOnSpawn = false,
		DisplayOrder = konfiguration.Ebene or 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, spielerGui)

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
		BackgroundColor3 = UiKit.Farben.Panel,
		BorderSizePixel = 0,
		-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde
		-- ein Klick mitten ins Fenster den Hintergrund-Knopf darunter
		-- ausloesen und das Fenster sofort wieder schliessen.
		Active = true,
	}, hintergrund)
	UiKit.Ecken(panel, 14)
	UiKit.Rand(panel, UiKit.Farben.PanelRand, 1.5, 0.45)
	UiKit.Abstand(panel, 12)

	UiKit.Neu("UISizeConstraint", {
		MaxSize = konfiguration.MaxGroesse or Vector2.new(640, 560),
		MinSize = Vector2.new(280, 320),
	}, panel)

	UiKit.Text({
		Name = "Titel",
		Size = UDim2.new(1, -44, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		Text = konfiguration.Titel or "",
	}, panel)

	UiKit.Text({
		Name = "Untertitel",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -44, 0, 14),
		TextSize = 11,
		TextColor3 = UiKit.Farben.TextGedimmt,
		Text = konfiguration.Untertitel or "",
	}, panel)

	local schliessen = UiKit.Knopf({
		Name = "Schliessen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = UiKit.Farben.PanelHell,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 16,
		Text = "X",
	}, panel)

	local inhalt = UiKit.Neu("Frame", {
		Name = "Inhalt",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
	}, panel)

	local fenster = {
		Gui = gui,
		Hintergrund = hintergrund,
		Panel = panel,
		Inhalt = inhalt,
		Offen = false,
		BeimOeffnen = nil :: (() -> ())?,
	}

	function fenster:SetzeOffen(neuerZustand: boolean)
		self.Offen = neuerZustand
		hintergrund.Visible = neuerZustand

		if neuerZustand then
			if self.BeimOeffnen then
				self.BeimOeffnen()
			end

			-- Kleine Aufzieh-Animation
			panel.Size = UDim2.new(0.92, 0, 0.8, 0)
			game:GetService("TweenService"):Create(
				panel,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.92, 0, 0.88, 0) }
			):Play()
		end
	end

	function fenster:Umschalten()
		self:SetzeOffen(not self.Offen)
	end

	schliessen.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	-- Klick neben das Panel schliesst das Fenster
	hintergrund.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	return fenster
end

return UiKit.Farben.Warnung
	elseif name == "Gut" then
		-- ================================================================
-- FENSTER
--
-- Alle Menue-Fenster (Werft, Sternenkarte, Imperium) sehen gleich aus:
-- abgedunkelter Hintergrund, Panel in der Mitte, Kopfzeile mit Titel
-- und Schliessen-Kreuz. Diese Funktion baut genau das und gibt dir den
-- leeren Inhaltsbereich zurueck.
--
-- Benutzung:
--     local fenster = UiKit.Fenster({ Name = "MeinGui", Titel = "WERFT" })
--     -- ... etwas in fenster.Inhalt bauen ...
--     fenster:SetzeOffen(true)
-- ================================================================
function UiKit.Fenster(konfiguration: { [string]: any })
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UiKit.Neu("ScreenGui", {
		Name = konfiguration.Name or "Fenster",
		ResetOnSpawn = false,
		DisplayOrder = konfiguration.Ebene or 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, spielerGui)

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
		BackgroundColor3 = UiKit.Farben.Panel,
		BorderSizePixel = 0,
		-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde
		-- ein Klick mitten ins Fenster den Hintergrund-Knopf darunter
		-- ausloesen und das Fenster sofort wieder schliessen.
		Active = true,
	}, hintergrund)
	UiKit.Ecken(panel, 14)
	UiKit.Rand(panel, UiKit.Farben.PanelRand, 1.5, 0.45)
	UiKit.Abstand(panel, 12)

	UiKit.Neu("UISizeConstraint", {
		MaxSize = konfiguration.MaxGroesse or Vector2.new(640, 560),
		MinSize = Vector2.new(280, 320),
	}, panel)

	UiKit.Text({
		Name = "Titel",
		Size = UDim2.new(1, -44, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		Text = konfiguration.Titel or "",
	}, panel)

	UiKit.Text({
		Name = "Untertitel",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -44, 0, 14),
		TextSize = 11,
		TextColor3 = UiKit.Farben.TextGedimmt,
		Text = konfiguration.Untertitel or "",
	}, panel)

	local schliessen = UiKit.Knopf({
		Name = "Schliessen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = UiKit.Farben.PanelHell,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 16,
		Text = "X",
	}, panel)

	local inhalt = UiKit.Neu("Frame", {
		Name = "Inhalt",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
	}, panel)

	local fenster = {
		Gui = gui,
		Hintergrund = hintergrund,
		Panel = panel,
		Inhalt = inhalt,
		Offen = false,
		BeimOeffnen = nil :: (() -> ())?,
	}

	function fenster:SetzeOffen(neuerZustand: boolean)
		self.Offen = neuerZustand
		hintergrund.Visible = neuerZustand

		if neuerZustand then
			if self.BeimOeffnen then
				self.BeimOeffnen()
			end

			-- Kleine Aufzieh-Animation
			panel.Size = UDim2.new(0.92, 0, 0.8, 0)
			game:GetService("TweenService"):Create(
				panel,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.92, 0, 0.88, 0) }
			):Play()
		end
	end

	function fenster:Umschalten()
		self:SetzeOffen(not self.Offen)
	end

	schliessen.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	-- Klick neben das Panel schliesst das Fenster
	hintergrund.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	return fenster
end

return UiKit.Farben.Gut
	elseif name == "Gold" then
		-- ================================================================
-- FENSTER
--
-- Alle Menue-Fenster (Werft, Sternenkarte, Imperium) sehen gleich aus:
-- abgedunkelter Hintergrund, Panel in der Mitte, Kopfzeile mit Titel
-- und Schliessen-Kreuz. Diese Funktion baut genau das und gibt dir den
-- leeren Inhaltsbereich zurueck.
--
-- Benutzung:
--     local fenster = UiKit.Fenster({ Name = "MeinGui", Titel = "WERFT" })
--     -- ... etwas in fenster.Inhalt bauen ...
--     fenster:SetzeOffen(true)
-- ================================================================
function UiKit.Fenster(konfiguration: { [string]: any })
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UiKit.Neu("ScreenGui", {
		Name = konfiguration.Name or "Fenster",
		ResetOnSpawn = false,
		DisplayOrder = konfiguration.Ebene or 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, spielerGui)

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
		BackgroundColor3 = UiKit.Farben.Panel,
		BorderSizePixel = 0,
		-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde
		-- ein Klick mitten ins Fenster den Hintergrund-Knopf darunter
		-- ausloesen und das Fenster sofort wieder schliessen.
		Active = true,
	}, hintergrund)
	UiKit.Ecken(panel, 14)
	UiKit.Rand(panel, UiKit.Farben.PanelRand, 1.5, 0.45)
	UiKit.Abstand(panel, 12)

	UiKit.Neu("UISizeConstraint", {
		MaxSize = konfiguration.MaxGroesse or Vector2.new(640, 560),
		MinSize = Vector2.new(280, 320),
	}, panel)

	UiKit.Text({
		Name = "Titel",
		Size = UDim2.new(1, -44, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		Text = konfiguration.Titel or "",
	}, panel)

	UiKit.Text({
		Name = "Untertitel",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -44, 0, 14),
		TextSize = 11,
		TextColor3 = UiKit.Farben.TextGedimmt,
		Text = konfiguration.Untertitel or "",
	}, panel)

	local schliessen = UiKit.Knopf({
		Name = "Schliessen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = UiKit.Farben.PanelHell,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 16,
		Text = "X",
	}, panel)

	local inhalt = UiKit.Neu("Frame", {
		Name = "Inhalt",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
	}, panel)

	local fenster = {
		Gui = gui,
		Hintergrund = hintergrund,
		Panel = panel,
		Inhalt = inhalt,
		Offen = false,
		BeimOeffnen = nil :: (() -> ())?,
	}

	function fenster:SetzeOffen(neuerZustand: boolean)
		self.Offen = neuerZustand
		hintergrund.Visible = neuerZustand

		if neuerZustand then
			if self.BeimOeffnen then
				self.BeimOeffnen()
			end

			-- Kleine Aufzieh-Animation
			panel.Size = UDim2.new(0.92, 0, 0.8, 0)
			game:GetService("TweenService"):Create(
				panel,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.92, 0, 0.88, 0) }
			):Play()
		end
	end

	function fenster:Umschalten()
		self:SetzeOffen(not self.Offen)
	end

	schliessen.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	-- Klick neben das Panel schliesst das Fenster
	hintergrund.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	return fenster
end

return UiKit.Farben.Gold
	end
	-- ================================================================
-- FENSTER
--
-- Alle Menue-Fenster (Werft, Sternenkarte, Imperium) sehen gleich aus:
-- abgedunkelter Hintergrund, Panel in der Mitte, Kopfzeile mit Titel
-- und Schliessen-Kreuz. Diese Funktion baut genau das und gibt dir den
-- leeren Inhaltsbereich zurueck.
--
-- Benutzung:
--     local fenster = UiKit.Fenster({ Name = "MeinGui", Titel = "WERFT" })
--     -- ... etwas in fenster.Inhalt bauen ...
--     fenster:SetzeOffen(true)
-- ================================================================
function UiKit.Fenster(konfiguration: { [string]: any })
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UiKit.Neu("ScreenGui", {
		Name = konfiguration.Name or "Fenster",
		ResetOnSpawn = false,
		DisplayOrder = konfiguration.Ebene or 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, spielerGui)

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
		BackgroundColor3 = UiKit.Farben.Panel,
		BorderSizePixel = 0,
		-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde
		-- ein Klick mitten ins Fenster den Hintergrund-Knopf darunter
		-- ausloesen und das Fenster sofort wieder schliessen.
		Active = true,
	}, hintergrund)
	UiKit.Ecken(panel, 14)
	UiKit.Rand(panel, UiKit.Farben.PanelRand, 1.5, 0.45)
	UiKit.Abstand(panel, 12)

	UiKit.Neu("UISizeConstraint", {
		MaxSize = konfiguration.MaxGroesse or Vector2.new(640, 560),
		MinSize = Vector2.new(280, 320),
	}, panel)

	UiKit.Text({
		Name = "Titel",
		Size = UDim2.new(1, -44, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		Text = konfiguration.Titel or "",
	}, panel)

	UiKit.Text({
		Name = "Untertitel",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -44, 0, 14),
		TextSize = 11,
		TextColor3 = UiKit.Farben.TextGedimmt,
		Text = konfiguration.Untertitel or "",
	}, panel)

	local schliessen = UiKit.Knopf({
		Name = "Schliessen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = UiKit.Farben.PanelHell,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 16,
		Text = "X",
	}, panel)

	local inhalt = UiKit.Neu("Frame", {
		Name = "Inhalt",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
	}, panel)

	local fenster = {
		Gui = gui,
		Hintergrund = hintergrund,
		Panel = panel,
		Inhalt = inhalt,
		Offen = false,
		BeimOeffnen = nil :: (() -> ())?,
	}

	function fenster:SetzeOffen(neuerZustand: boolean)
		self.Offen = neuerZustand
		hintergrund.Visible = neuerZustand

		if neuerZustand then
			if self.BeimOeffnen then
				self.BeimOeffnen()
			end

			-- Kleine Aufzieh-Animation
			panel.Size = UDim2.new(0.92, 0, 0.8, 0)
			game:GetService("TweenService"):Create(
				panel,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.92, 0, 0.88, 0) }
			):Play()
		end
	end

	function fenster:Umschalten()
		self:SetzeOffen(not self.Offen)
	end

	schliessen.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	-- Klick neben das Panel schliesst das Fenster
	hintergrund.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	return fenster
end

return UiKit.Farben.Text
end

-- ================================================================
-- BAU-HELFER
-- ================================================================

-- UiKit.Neu("TextLabel", { Text = "Hallo" }, elternObjekt)
function UiKit.Neu(klasse: string, eigenschaften: { [string]: any }?, eltern: Instance?): any
	local objekt = Instance.new(klasse)

	if eigenschaften then
		for schluessel, wert in eigenschaften do
			(objekt :: any)[schluessel] = wert
		end
	end

	if eltern then
		objekt.Parent = eltern
	end

	return objekt
end

function UiKit.Ecken(eltern: Instance, radius: number)
	-- ================================================================
-- FENSTER
--
-- Alle Menue-Fenster (Werft, Sternenkarte, Imperium) sehen gleich aus:
-- abgedunkelter Hintergrund, Panel in der Mitte, Kopfzeile mit Titel
-- und Schliessen-Kreuz. Diese Funktion baut genau das und gibt dir den
-- leeren Inhaltsbereich zurueck.
--
-- Benutzung:
--     local fenster = UiKit.Fenster({ Name = "MeinGui", Titel = "WERFT" })
--     -- ... etwas in fenster.Inhalt bauen ...
--     fenster:SetzeOffen(true)
-- ================================================================
function UiKit.Fenster(konfiguration: { [string]: any })
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UiKit.Neu("ScreenGui", {
		Name = konfiguration.Name or "Fenster",
		ResetOnSpawn = false,
		DisplayOrder = konfiguration.Ebene or 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, spielerGui)

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
		BackgroundColor3 = UiKit.Farben.Panel,
		BorderSizePixel = 0,
		-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde
		-- ein Klick mitten ins Fenster den Hintergrund-Knopf darunter
		-- ausloesen und das Fenster sofort wieder schliessen.
		Active = true,
	}, hintergrund)
	UiKit.Ecken(panel, 14)
	UiKit.Rand(panel, UiKit.Farben.PanelRand, 1.5, 0.45)
	UiKit.Abstand(panel, 12)

	UiKit.Neu("UISizeConstraint", {
		MaxSize = konfiguration.MaxGroesse or Vector2.new(640, 560),
		MinSize = Vector2.new(280, 320),
	}, panel)

	UiKit.Text({
		Name = "Titel",
		Size = UDim2.new(1, -44, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		Text = konfiguration.Titel or "",
	}, panel)

	UiKit.Text({
		Name = "Untertitel",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -44, 0, 14),
		TextSize = 11,
		TextColor3 = UiKit.Farben.TextGedimmt,
		Text = konfiguration.Untertitel or "",
	}, panel)

	local schliessen = UiKit.Knopf({
		Name = "Schliessen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = UiKit.Farben.PanelHell,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 16,
		Text = "X",
	}, panel)

	local inhalt = UiKit.Neu("Frame", {
		Name = "Inhalt",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
	}, panel)

	local fenster = {
		Gui = gui,
		Hintergrund = hintergrund,
		Panel = panel,
		Inhalt = inhalt,
		Offen = false,
		BeimOeffnen = nil :: (() -> ())?,
	}

	function fenster:SetzeOffen(neuerZustand: boolean)
		self.Offen = neuerZustand
		hintergrund.Visible = neuerZustand

		if neuerZustand then
			if self.BeimOeffnen then
				self.BeimOeffnen()
			end

			-- Kleine Aufzieh-Animation
			panel.Size = UDim2.new(0.92, 0, 0.8, 0)
			game:GetService("TweenService"):Create(
				panel,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.92, 0, 0.88, 0) }
			):Play()
		end
	end

	function fenster:Umschalten()
		self:SetzeOffen(not self.Offen)
	end

	schliessen.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	-- Klick neben das Panel schliesst das Fenster
	hintergrund.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	return fenster
end

return UiKit.Neu("UICorner", { CornerRadius = UDim.new(0, radius) }, eltern)
end

function UiKit.Rand(eltern: Instance, farbe: Color3, dicke: number?, transparenz: number?)
	-- ================================================================
-- FENSTER
--
-- Alle Menue-Fenster (Werft, Sternenkarte, Imperium) sehen gleich aus:
-- abgedunkelter Hintergrund, Panel in der Mitte, Kopfzeile mit Titel
-- und Schliessen-Kreuz. Diese Funktion baut genau das und gibt dir den
-- leeren Inhaltsbereich zurueck.
--
-- Benutzung:
--     local fenster = UiKit.Fenster({ Name = "MeinGui", Titel = "WERFT" })
--     -- ... etwas in fenster.Inhalt bauen ...
--     fenster:SetzeOffen(true)
-- ================================================================
function UiKit.Fenster(konfiguration: { [string]: any })
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UiKit.Neu("ScreenGui", {
		Name = konfiguration.Name or "Fenster",
		ResetOnSpawn = false,
		DisplayOrder = konfiguration.Ebene or 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, spielerGui)

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
		BackgroundColor3 = UiKit.Farben.Panel,
		BorderSizePixel = 0,
		-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde
		-- ein Klick mitten ins Fenster den Hintergrund-Knopf darunter
		-- ausloesen und das Fenster sofort wieder schliessen.
		Active = true,
	}, hintergrund)
	UiKit.Ecken(panel, 14)
	UiKit.Rand(panel, UiKit.Farben.PanelRand, 1.5, 0.45)
	UiKit.Abstand(panel, 12)

	UiKit.Neu("UISizeConstraint", {
		MaxSize = konfiguration.MaxGroesse or Vector2.new(640, 560),
		MinSize = Vector2.new(280, 320),
	}, panel)

	UiKit.Text({
		Name = "Titel",
		Size = UDim2.new(1, -44, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		Text = konfiguration.Titel or "",
	}, panel)

	UiKit.Text({
		Name = "Untertitel",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -44, 0, 14),
		TextSize = 11,
		TextColor3 = UiKit.Farben.TextGedimmt,
		Text = konfiguration.Untertitel or "",
	}, panel)

	local schliessen = UiKit.Knopf({
		Name = "Schliessen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = UiKit.Farben.PanelHell,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 16,
		Text = "X",
	}, panel)

	local inhalt = UiKit.Neu("Frame", {
		Name = "Inhalt",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
	}, panel)

	local fenster = {
		Gui = gui,
		Hintergrund = hintergrund,
		Panel = panel,
		Inhalt = inhalt,
		Offen = false,
		BeimOeffnen = nil :: (() -> ())?,
	}

	function fenster:SetzeOffen(neuerZustand: boolean)
		self.Offen = neuerZustand
		hintergrund.Visible = neuerZustand

		if neuerZustand then
			if self.BeimOeffnen then
				self.BeimOeffnen()
			end

			-- Kleine Aufzieh-Animation
			panel.Size = UDim2.new(0.92, 0, 0.8, 0)
			game:GetService("TweenService"):Create(
				panel,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.92, 0, 0.88, 0) }
			):Play()
		end
	end

	function fenster:Umschalten()
		self:SetzeOffen(not self.Offen)
	end

	schliessen.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	-- Klick neben das Panel schliesst das Fenster
	hintergrund.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	return fenster
end

return UiKit.Neu("UIStroke", {
		Color = farbe,
		Thickness = dicke or 1,
		Transparency = transparenz or 0.4,
	}, eltern)
end

function UiKit.Abstand(eltern: Instance, pixel: number)
	-- ================================================================
-- FENSTER
--
-- Alle Menue-Fenster (Werft, Sternenkarte, Imperium) sehen gleich aus:
-- abgedunkelter Hintergrund, Panel in der Mitte, Kopfzeile mit Titel
-- und Schliessen-Kreuz. Diese Funktion baut genau das und gibt dir den
-- leeren Inhaltsbereich zurueck.
--
-- Benutzung:
--     local fenster = UiKit.Fenster({ Name = "MeinGui", Titel = "WERFT" })
--     -- ... etwas in fenster.Inhalt bauen ...
--     fenster:SetzeOffen(true)
-- ================================================================
function UiKit.Fenster(konfiguration: { [string]: any })
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UiKit.Neu("ScreenGui", {
		Name = konfiguration.Name or "Fenster",
		ResetOnSpawn = false,
		DisplayOrder = konfiguration.Ebene or 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, spielerGui)

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
		BackgroundColor3 = UiKit.Farben.Panel,
		BorderSizePixel = 0,
		-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde
		-- ein Klick mitten ins Fenster den Hintergrund-Knopf darunter
		-- ausloesen und das Fenster sofort wieder schliessen.
		Active = true,
	}, hintergrund)
	UiKit.Ecken(panel, 14)
	UiKit.Rand(panel, UiKit.Farben.PanelRand, 1.5, 0.45)
	UiKit.Abstand(panel, 12)

	UiKit.Neu("UISizeConstraint", {
		MaxSize = konfiguration.MaxGroesse or Vector2.new(640, 560),
		MinSize = Vector2.new(280, 320),
	}, panel)

	UiKit.Text({
		Name = "Titel",
		Size = UDim2.new(1, -44, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		Text = konfiguration.Titel or "",
	}, panel)

	UiKit.Text({
		Name = "Untertitel",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -44, 0, 14),
		TextSize = 11,
		TextColor3 = UiKit.Farben.TextGedimmt,
		Text = konfiguration.Untertitel or "",
	}, panel)

	local schliessen = UiKit.Knopf({
		Name = "Schliessen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = UiKit.Farben.PanelHell,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 16,
		Text = "X",
	}, panel)

	local inhalt = UiKit.Neu("Frame", {
		Name = "Inhalt",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
	}, panel)

	local fenster = {
		Gui = gui,
		Hintergrund = hintergrund,
		Panel = panel,
		Inhalt = inhalt,
		Offen = false,
		BeimOeffnen = nil :: (() -> ())?,
	}

	function fenster:SetzeOffen(neuerZustand: boolean)
		self.Offen = neuerZustand
		hintergrund.Visible = neuerZustand

		if neuerZustand then
			if self.BeimOeffnen then
				self.BeimOeffnen()
			end

			-- Kleine Aufzieh-Animation
			panel.Size = UDim2.new(0.92, 0, 0.8, 0)
			game:GetService("TweenService"):Create(
				panel,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.92, 0, 0.88, 0) }
			):Play()
		end
	end

	function fenster:Umschalten()
		self:SetzeOffen(not self.Offen)
	end

	schliessen.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	-- Klick neben das Panel schliesst das Fenster
	hintergrund.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	return fenster
end

return UiKit.Neu("UIPadding", {
		PaddingTop = UDim.new(0, pixel),
		PaddingBottom = UDim.new(0, pixel),
		PaddingLeft = UDim.new(0, pixel),
		PaddingRight = UDim.new(0, pixel),
	}, eltern)
end

-- Standard-Textfeld mit unseren Schriftarten
function UiKit.Text(eigenschaften: { [string]: any }, eltern: Instance?)
	local standard = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = UiKit.Farben.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for schluessel, wert in eigenschaften do
		standard[schluessel] = wert
	end
	-- ================================================================
-- FENSTER
--
-- Alle Menue-Fenster (Werft, Sternenkarte, Imperium) sehen gleich aus:
-- abgedunkelter Hintergrund, Panel in der Mitte, Kopfzeile mit Titel
-- und Schliessen-Kreuz. Diese Funktion baut genau das und gibt dir den
-- leeren Inhaltsbereich zurueck.
--
-- Benutzung:
--     local fenster = UiKit.Fenster({ Name = "MeinGui", Titel = "WERFT" })
--     -- ... etwas in fenster.Inhalt bauen ...
--     fenster:SetzeOffen(true)
-- ================================================================
function UiKit.Fenster(konfiguration: { [string]: any })
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UiKit.Neu("ScreenGui", {
		Name = konfiguration.Name or "Fenster",
		ResetOnSpawn = false,
		DisplayOrder = konfiguration.Ebene or 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, spielerGui)

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
		BackgroundColor3 = UiKit.Farben.Panel,
		BorderSizePixel = 0,
		-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde
		-- ein Klick mitten ins Fenster den Hintergrund-Knopf darunter
		-- ausloesen und das Fenster sofort wieder schliessen.
		Active = true,
	}, hintergrund)
	UiKit.Ecken(panel, 14)
	UiKit.Rand(panel, UiKit.Farben.PanelRand, 1.5, 0.45)
	UiKit.Abstand(panel, 12)

	UiKit.Neu("UISizeConstraint", {
		MaxSize = konfiguration.MaxGroesse or Vector2.new(640, 560),
		MinSize = Vector2.new(280, 320),
	}, panel)

	UiKit.Text({
		Name = "Titel",
		Size = UDim2.new(1, -44, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		Text = konfiguration.Titel or "",
	}, panel)

	UiKit.Text({
		Name = "Untertitel",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -44, 0, 14),
		TextSize = 11,
		TextColor3 = UiKit.Farben.TextGedimmt,
		Text = konfiguration.Untertitel or "",
	}, panel)

	local schliessen = UiKit.Knopf({
		Name = "Schliessen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = UiKit.Farben.PanelHell,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 16,
		Text = "X",
	}, panel)

	local inhalt = UiKit.Neu("Frame", {
		Name = "Inhalt",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
	}, panel)

	local fenster = {
		Gui = gui,
		Hintergrund = hintergrund,
		Panel = panel,
		Inhalt = inhalt,
		Offen = false,
		BeimOeffnen = nil :: (() -> ())?,
	}

	function fenster:SetzeOffen(neuerZustand: boolean)
		self.Offen = neuerZustand
		hintergrund.Visible = neuerZustand

		if neuerZustand then
			if self.BeimOeffnen then
				self.BeimOeffnen()
			end

			-- Kleine Aufzieh-Animation
			panel.Size = UDim2.new(0.92, 0, 0.8, 0)
			game:GetService("TweenService"):Create(
				panel,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.92, 0, 0.88, 0) }
			):Play()
		end
	end

	function fenster:Umschalten()
		self:SetzeOffen(not self.Offen)
	end

	schliessen.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	-- Klick neben das Panel schliesst das Fenster
	hintergrund.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	return fenster
end

return UiKit.Neu("TextLabel", standard, eltern)
end

-- Standard-Knopf
function UiKit.Knopf(eigenschaften: { [string]: any }, eltern: Instance?)
	local standard = {
		BackgroundColor3 = UiKit.Farben.Akzent,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(8, 16, 24),
	}
	for schluessel, wert in eigenschaften do
		standard[schluessel] = wert
	end

	local knopf = UiKit.Neu("TextButton", standard, eltern)
	UiKit.Ecken(knopf, 8)
	return knopf
end

-- ================================================================
-- AKTIONSLEISTE
--
-- Sie sitzt am LINKEN Bildrand auf halber Hoehe. Bewusst nicht unten:
-- Dort liegen auf dem Handy der Bewegungs-Stick (links unten) und der
-- Sprungknopf (rechts unten).
-- ================================================================
local aktionsleisteCache: Frame? = nil

function UiKit.HoleHud(): ScreenGui
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	return spielerGui:WaitForChild("HUD", 30) :: ScreenGui
end

function UiKit.HoleAktionsleiste(): Frame
	if aktionsleisteCache and aktionsleisteCache.Parent then
		return aktionsleisteCache
	end

	local hud = UiKit.HoleHud()
	aktionsleisteCache = hud:WaitForChild("Aktionsleiste", 30) :: Frame
	return aktionsleisteCache :: Frame
end

-- Erzeugt die Leiste selbst. Wird EINMAL vom HudClient aufgerufen.
function UiKit.ErstelleAktionsleiste(hud: ScreenGui): Frame
	local leiste = UiKit.Neu("Frame", {
		Name = "Aktionsleiste",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(0, 120, 0, 240),
		BackgroundTransparency = 1,
	}, hud)

	UiKit.Neu("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, leiste)

	aktionsleisteCache = leiste
	return leiste
end

-- Haengt einen Knopf in die Leiste. Rueckgabe: der Knopf.
function UiKit.LeistenKnopf(text: string, reihenfolge: number): TextButton
	local leiste = UiKit.HoleAktionsleiste()

	local knopf = UiKit.Knopf({
		Name = text,
		LayoutOrder = reihenfolge,
		Size = UDim2.new(0, 116, 0, 42),
		BackgroundColor3 = UiKit.Farben.Panel,
		BackgroundTransparency = 0.12,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 14,
		Text = text,
	}, leiste)

	UiKit.Rand(knopf, UiKit.Farben.PanelRand, 1.5, 0.5)
	return knopf
end

-- ================================================================
-- FENSTER
--
-- Alle Menue-Fenster (Werft, Sternenkarte, Imperium) sehen gleich aus:
-- abgedunkelter Hintergrund, Panel in der Mitte, Kopfzeile mit Titel
-- und Schliessen-Kreuz. Diese Funktion baut genau das und gibt dir den
-- leeren Inhaltsbereich zurueck.
--
-- Benutzung:
--     local fenster = UiKit.Fenster({ Name = "MeinGui", Titel = "WERFT" })
--     -- ... etwas in fenster.Inhalt bauen ...
--     fenster:SetzeOffen(true)
-- ================================================================
function UiKit.Fenster(konfiguration: { [string]: any })
	local spielerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = UiKit.Neu("ScreenGui", {
		Name = konfiguration.Name or "Fenster",
		ResetOnSpawn = false,
		DisplayOrder = konfiguration.Ebene or 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, spielerGui)

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
		BackgroundColor3 = UiKit.Farben.Panel,
		BorderSizePixel = 0,
		-- Active = true laesst das Panel Klicks schlucken. Ohne das wuerde
		-- ein Klick mitten ins Fenster den Hintergrund-Knopf darunter
		-- ausloesen und das Fenster sofort wieder schliessen.
		Active = true,
	}, hintergrund)
	UiKit.Ecken(panel, 14)
	UiKit.Rand(panel, UiKit.Farben.PanelRand, 1.5, 0.45)
	UiKit.Abstand(panel, 12)

	UiKit.Neu("UISizeConstraint", {
		MaxSize = konfiguration.MaxGroesse or Vector2.new(640, 560),
		MinSize = Vector2.new(280, 320),
	}, panel)

	UiKit.Text({
		Name = "Titel",
		Size = UDim2.new(1, -44, 0, 26),
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		Text = konfiguration.Titel or "",
	}, panel)

	UiKit.Text({
		Name = "Untertitel",
		Position = UDim2.new(0, 0, 0, 24),
		Size = UDim2.new(1, -44, 0, 14),
		TextSize = 11,
		TextColor3 = UiKit.Farben.TextGedimmt,
		Text = konfiguration.Untertitel or "",
	}, panel)

	local schliessen = UiKit.Knopf({
		Name = "Schliessen",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 34, 0, 34),
		BackgroundColor3 = UiKit.Farben.PanelHell,
		TextColor3 = UiKit.Farben.Text,
		TextSize = 16,
		Text = "X",
	}, panel)

	local inhalt = UiKit.Neu("Frame", {
		Name = "Inhalt",
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
	}, panel)

	local fenster = {
		Gui = gui,
		Hintergrund = hintergrund,
		Panel = panel,
		Inhalt = inhalt,
		Offen = false,
		BeimOeffnen = nil :: (() -> ())?,
	}

	function fenster:SetzeOffen(neuerZustand: boolean)
		self.Offen = neuerZustand
		hintergrund.Visible = neuerZustand

		if neuerZustand then
			if self.BeimOeffnen then
				self.BeimOeffnen()
			end

			-- Kleine Aufzieh-Animation
			panel.Size = UDim2.new(0.92, 0, 0.8, 0)
			game:GetService("TweenService"):Create(
				panel,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0.92, 0, 0.88, 0) }
			):Play()
		end
	end

	function fenster:Umschalten()
		self:SetzeOffen(not self.Offen)
	end

	schliessen.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	-- Klick neben das Panel schliesst das Fenster
	hintergrund.Activated:Connect(function()
		fenster:SetzeOffen(false)
	end)

	return fenster
end

return UiKit
]==],
	},
	{
		Ziel = "ReplicatedStorage",
		Name = "Util",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	Util  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ReplicatedStorage > Util

	WARUM HIER?
	Kleine Helferfunktionen, die Server UND Client brauchen
	(z. B. Zahlen huebsch formatieren). ReplicatedStorage ist der
	gemeinsame Ordner fuer beide Seiten.
	================================================================
]]

local Util = {}

-- Wandelt 1234567 in "1.23M" um. Fuer die GUI und Button-Schilder.
function Util.FormatGeld(zahl: number): string
	zahl = math.floor(zahl)
	if zahl < 1000 then
		return tostring(zahl)
	end

	local einheiten = { "K", "M", "B", "T", "Qa", "Qi", "Sx" }
	local index = 0
	local wert = zahl

	while wert >= 1000 and index < #einheiten do
		wert = wert / 1000
		index += 1
	end

	-- Bei dreistelligen Zahlen keine Nachkommastellen (z. B. "123M" statt "123.00M")
	local nachkomma = (wert >= 100) and 0 or 2
	return string.format("%." .. nachkomma .. "f%s", wert, einheiten[index])
end

-- Sekunden -> "02:35"
function Util.FormatZeit(sekunden: number): string
	sekunden = math.max(0, math.floor(sekunden))
	return string.format("%02d:%02d", sekunden // 60, sekunden % 60)
end

-- Erzeugt schnell einen Part mit Standardeinstellungen fuer unsere Map.
-- Anchored + CanCollide sind bewusst als Parameter gesetzt, damit wir
-- nie vergessen, Bauteile zu verankern (unverankerte Parts = Lag).
function Util.NeuerPart(eigenschaften: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = true
	part.CastShadow = false          -- spart Performance auf Handys
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic

	for schluessel, wert in eigenschaften do
		(part :: any)[schluessel] = wert
	end

	return part
end

-- Rundet ab und stellt sicher, dass nie ein negativer Geldwert entsteht.
function Util.SichererBetrag(zahl: any): number
	if type(zahl) ~= "number" or zahl ~= zahl then  -- zahl ~= zahl faengt NaN ab
		return 0
	end
	return math.max(0, math.floor(zahl))
end

-- Kopiert eine Tabelle tief. Brauchen wir fuer die Standard-Spielerdaten,
-- damit nicht alle Spieler dieselbe Tabelle teilen.
function Util.TiefeKopie(quelle: { [any]: any }): { [any]: any }
	local ziel = {}
	for schluessel, wert in quelle do
		if type(wert) == "table" then
			ziel[schluessel] = Util.TiefeKopie(wert)
		else
			ziel[schluessel] = wert
		end
	end
	return ziel
end

return Util
]==],
	},
	{
		Ziel = "ServerScriptService",
		Name = "Main",
		Klasse = "Script",
		Quelle = [==[
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
	  7. FleetService — muss vor HangarService laufen
	  8. HangarService — braucht Plots UND FleetService
	  9. PlanetService/CombatService — brauchen die Flotte
	 10. Monetarisierung, Imperium, Ereignisse
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
local FleetService = require(Services.FleetService)
local HangarService = require(Services.HangarService)
local PlanetService = require(Services.PlanetService)
local CombatService = require(Services.CombatService)
local MonetizationService = require(Services.MonetizationService)
local ImperiumService = require(Services.ImperiumService)
local EventService = require(Services.EventService)

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

FleetService:Init()
HangarService:Init()

PlanetService:Init(welt)
CombatService:Init()

MonetizationService:Init()
ImperiumService:Init()
EventService:Init()

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

	-- Holt Schiffe nach, die waehrend der Offline-Zeit fertig geworden sind,
	-- und schickt dem Client seinen Flottenstand.
	FleetService:SpielerVorbereiten(spieler)

	-- Gespeicherte Planeten zurueckgeben, soweit sie hier noch frei sind
	PlanetService:SpielerVorbereiten(spieler)

	-- Gamepasses abfragen (laeuft im Hintergrund weiter)
	MonetizationService:SpielerVorbereiten(spieler)

	-- Orbitalgeschuetze aufstellen und Technologie-/Shop-Stand schicken
	ImperiumService:SpielerVorbereiten(spieler)

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
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "ButtonService",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	ButtonService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > ButtonService

	AUFGABE
	Erzeugt die begehbaren Kauf-Pads auf dem Plot und wickelt den Kauf ab.

	EXPLOIT-SCHUTZ — bitte merken:
	Der Kauf laeuft KOMPLETT auf dem Server. Der Client schickt keinen
	"Ich kaufe X"-Befehl, er laeuft nur physisch auf das Pad. Der Server
	prueft danach selbst:
	   1. Gehoert der Plot diesem Spieler?
	   2. Ist das Objekt noch nicht gekauft?
	   3. Ist die Voraussetzung erfuellt?
	   4. Hat der Spieler wirklich genug Credits?
	Selbst wenn jemand seine Figur auf das Pad teleportiert, kann er
	nichts kaufen, was er sich nicht leisten kann.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)

local ButtonService = {}

local FARBE_BEZAHLBAR = Color3.fromRGB(70, 220, 130)
local FARBE_ZU_TEUER = Color3.fromRGB(220, 80, 90)
local FARBE_GRATIS = Color3.fromRGB(90, 200, 255)

-- Entprellung: verhindert, dass ein einziger Schritt aufs Pad
-- das Touched-Event 20x ausloest.
local letzteBeruehrung: { [string]: number } = {}

local function baueButton(plot: any, eintrag: any)
	local basisPos = PlotService:ZuWelt(plot, eintrag.ButtonPos)

	local model = Instance.new("Model")
	model.Name = eintrag.Id
	model.Parent = plot.ButtonOrdner

	local sockel = Util.NeuerPart({
		Name = "Sockel",
		Size = Vector3.new(9, 1, 9),
		Color = Color3.fromRGB(35, 40, 56),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 0.5, 0)),
	})
	sockel.Parent = model

	local pad = Util.NeuerPart({
		Name = "Pad",
		Size = Vector3.new(7.5, 0.6, 7.5),
		Color = FARBE_BEZAHLBAR,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		-- CanCollide = false: Der Spieler laeuft DURCH das Pad hindurch.
		-- Touched feuert trotzdem. Das verhindert, dass die Schwebe-
		-- Animation die Spielfigur anhebt oder wegschiebt.
		CanCollide = false,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 1.2, 0)),
	})
	pad.Parent = model
	model.PrimaryPart = pad

	local schild = Instance.new("BillboardGui")
	schild.Name = "Info"
	schild.Size = UDim2.fromScale(13, 4)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	schild.MaxDistance = 180
	schild.Parent = pad

	local rahmen = Instance.new("Frame")
	rahmen.Size = UDim2.fromScale(1, 1)
	rahmen.BackgroundTransparency = 1
	rahmen.Parent = schild

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rahmen

	local name = Instance.new("TextLabel")
	name.Name = "Titel"
	name.LayoutOrder = 1
	name.Size = UDim2.fromScale(1, 0.55)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.3
	name.Text = eintrag.Name
	name.Parent = rahmen

	local preis = Instance.new("TextLabel")
	preis.Name = "Preis"
	preis.LayoutOrder = 2
	preis.Size = UDim2.fromScale(1, 0.45)
	preis.BackgroundTransparency = 1
	preis.Font = Enum.Font.GothamBlack
	preis.TextScaled = true
	preis.TextStrokeTransparency = 0.3
	preis.TextColor3 = FARBE_BEZAHLBAR
	preis.Text = eintrag.Preis <= 0
		and "GRATIS"
		or (Util.FormatGeld(eintrag.Preis) .. " " .. Config.Spiel.Waehrung)
	preis.Parent = rahmen

	-- Kleine Auf-und-ab-Animation, damit die Pads auffallen
	TweenService:Create(
		pad,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = pad.CFrame + Vector3.new(0, 0.5, 0) }
	):Play()

	pad.Touched:Connect(function(getroffen)
		local charakter = getroffen:FindFirstAncestorOfClass("Model")
		if not charakter then
			return
		end
		local spieler = Players:GetPlayerFromCharacter(charakter)
		if not spieler then
			return
		end
		ButtonService:KaufVersuch(spieler, plot, eintrag)
	end)

	return model
end

-- Zeigt genau die Buttons, die gerade kaufbar sind (Voraussetzung erfuellt,
-- noch nicht gekauft). Wird nach jedem Kauf neu aufgerufen.
function ButtonService:AktualisiereButtons(plot: any)
	local spieler = plot.Besitzer
	if not spieler then
		plot.ButtonOrdner:ClearAllChildren()
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	for _, eintrag in Config.Kaufbares do
		local schonGekauft = daten.Gekauft[eintrag.Id] == true
		local freigeschaltet = (eintrag.Benoetigt == nil) or (daten.Gekauft[eintrag.Benoetigt] == true)
		local sollSichtbar = freigeschaltet and not schonGekauft

		local vorhanden = plot.ButtonOrdner:FindFirstChild(eintrag.Id)

		if sollSichtbar and not vorhanden then
			baueButton(plot, eintrag)
		elseif not sollSichtbar and vorhanden then
			vorhanden:Destroy()
		end
	end
end

-- Faerbt die Preise gruen/rot, je nach Kontostand.
function ButtonService:AktualisiereFarben(plot: any)
	local spieler = plot.Besitzer
	if not spieler then
		return
	end

	local geld = CurrencyService:GetGeld(spieler)

	for _, model in plot.ButtonOrdner:GetChildren() do
		local eintrag = PlotService.KaufbaresNachId[model.Name]
		local pad = model:FindFirstChild("Pad") :: BasePart?

		if eintrag and pad then
			local farbe
			if eintrag.Preis <= 0 then
				farbe = FARBE_GRATIS
			elseif geld >= eintrag.Preis then
				farbe = FARBE_BEZAHLBAR
			else
				farbe = FARBE_ZU_TEUER
			end

			pad.Color = farbe

			local info = pad:FindFirstChild("Info")
			local rahmen = info and info:FindFirstChildOfClass("Frame")
			local label = rahmen and rahmen:FindFirstChild("Preis")
			if label then
				(label :: TextLabel).TextColor3 = farbe
			end
		end
	end
end

-- ================================================================
-- KAUF (die eigentliche Validierung)
-- ================================================================
function ButtonService:KaufVersuch(spieler: Player, plot: any, eintrag: any)
	-- 0) Entprellung
	local schluessel = spieler.UserId .. "_" .. eintrag.Id
	local jetzt = os.clock()
	if letzteBeruehrung[schluessel] and (jetzt - letzteBeruehrung[schluessel]) < 0.6 then
		return
	end
	letzteBeruehrung[schluessel] = jetzt

	-- 1) Gehoert der Plot diesem Spieler?
	if plot.Besitzer ~= spieler then
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	-- 2) Schon gekauft?
	if daten.Gekauft[eintrag.Id] then
		return
	end

	-- 3) Voraussetzung erfuellt?
	if eintrag.Benoetigt and not daten.Gekauft[eintrag.Benoetigt] then
		return
	end

	-- 4) Genug Credits? (CurrencyService bucht nur ab, wenn es reicht)
	if eintrag.Preis > 0 then
		if not CurrencyService:Abbuchen(spieler, eintrag.Preis) then
			Net:Event("Benachrichtigung"):FireClient(spieler, {
				Text = "Nicht genug Credits fuer " .. eintrag.Name,
				Farbe = "Warnung",
			})
			return
		end
	end

	-- Alles geprueft -> jetzt erst wird gebaut
	daten.Gekauft[eintrag.Id] = true

	PlotService:BaueObjekt(plot, eintrag)
	PlotService:NeuBerechnen(plot)
	self:AktualisiereButtons(plot)

	CurrencyService:MarkiereAenderung(spieler)
	Net:Event("KaufBestaetigt"):FireClient(spieler, {
		Id = eintrag.Id,
		Name = eintrag.Name,
		Preis = eintrag.Preis,
	})

	if Config.Spiel.DebugAusgaben then
		print("[ButtonService]", spieler.Name, "kauft", eintrag.Id, "fuer", eintrag.Preis)
	end
end

function ButtonService:Init()
	PlotService.Zugewiesen:Verbinden(function(_spieler, plot)
		self:AktualisiereButtons(plot)
		self:AktualisiereFarben(plot)
	end)

	-- Preisfarben regelmaessig auffrischen (4x pro Sekunde reicht voellig)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, plot in PlotService.Plots do
				if plot.Besitzer then
					self:AktualisiereFarben(plot)
				end
			end
		end
	end)

	-- Entprellungs-Eintraege aufraeumen, damit die Tabelle nicht endlos waechst
	Players.PlayerRemoving:Connect(function(spieler)
		local praefix = spieler.UserId .. "_"
		for schluessel in letzteBeruehrung do
			if string.sub(schluessel, 1, #praefix) == praefix then
				letzteBeruehrung[schluessel] = nil
			end
		end
	end)

	if Config.Spiel.DebugAusgaben then
		print("[ButtonService] bereit")
	end
end

return ButtonService
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "CombatService",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	CombatService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > CombatService

	AUFGABE
	Angriffe auf Planeten: pruefen, Flotte losschicken, Kampf
	auswerten, Verluste abziehen, Planet uebergeben.

	DIE KAMPFFORMEL (bewusst einfach nachvollziehbar):
	    Siegchance = Staerke / (Staerke + Verteidigung)
	Gleich stark = 50 %. Doppelte Staerke = 67 %.
	Gedeckelt auf 5 % bis 95 % — nichts ist je ganz sicher.

	VERLUSTE
	Auch ein Sieg kostet Schiffe. Wie viele, haengt davon ab, wie
	knapp es war: Einen viel schwaecheren Planeten zu nehmen kostet
	fast nichts, ein Kopf-an-Kopf-Rennen sehr viel.

	EXPLOIT-SCHUTZ
	Der Client schickt nur eine Planeten-Id. Staerke, Verteidigung,
	Wuerfelwurf und Verluste rechnet ausschliesslich der Server. Ein
	Exploiter kann den Angriffsknopf spammen — die Cooldown-Pruefung
	und die "ist schon unterwegs"-Sperre liegen ebenfalls hier.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlanetConfig = require(ReplicatedStorage:WaitForChild("PlanetConfig"))
local FleetConfig = require(ReplicatedStorage:WaitForChild("FleetConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local FleetService = require(script.Parent.FleetService)
local PlanetService = require(script.Parent.PlanetService)

local CombatService = {}

-- [Player] = os.clock() des letzten Angriffs
local letzterAngriff: { [Player]: number } = {}
-- [Player] = true, solange eine Flotte unterwegs ist
local imFlug: { [Player]: boolean } = {}

local function melden(spieler: Player, text: string, farbe: string)
	Net:Event("Benachrichtigung"):FireClient(spieler, { Text = text, Farbe = farbe })
end

-- ================================================================
-- FLUG-ANIMATION
-- Ein paar Neon-Parts fliegen von der Station zum Planeten. Rein
-- optisch — der Kampf wird unabhaengig davon ausgerechnet.
-- ================================================================
local function flugAnimation(plot: any, zielPosition: Vector3, dauer: number)
	if not plot then
		return
	end

	local start = PlotService:ZuWelt(plot, Config.PlotPunkte.Orbit)
	local richtung = (zielPosition - start).Unit

	for i = 1, 6 do
		local versatz = Vector3.new(
			math.random(-25, 25),
			math.random(-12, 12),
			math.random(-25, 25)
		)

		local schiff = Util.NeuerPart({
			Name = "Angriffsflotte",
			Size = Vector3.new(3, 1.4, 7),
			Color = Color3.fromRGB(120, 220, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(start + versatz, start + versatz + richtung),
		})
		schiff.Parent = workspace:FindFirstChild("Welt") or workspace

		-- Debris raeumt den Part auf, falls der Tween nie ankommt
		Debris:AddItem(schiff, dauer + 2)

		local ziel = zielPosition + versatz * 1.5
		TweenService:Create(
			schiff,
			TweenInfo.new(dauer * (0.85 + i * 0.03), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(ziel, ziel + richtung) }
		):Play()
	end
end

-- ================================================================
-- VERLUSTE
-- ================================================================

-- Zieht anteilig Schiffe aus allen Klassen ab. Gibt zurueck, wie viele
-- Schiffe insgesamt verloren gingen.
local function flotteReduzieren(daten: any, anteil: number): number
	if anteil <= 0 then
		return 0
	end

	-- Erst sammeln, dann anwenden: Eine Tabelle waehrend der Iteration
	-- zu veraendern ist eine typische Fehlerquelle.
	local aenderungen = {}
	local verloren = 0
	local gesamtVorher = 0

	for klassenId, anzahl in daten.Flotte do
		gesamtVorher += anzahl
		local weg = math.min(anzahl, math.floor(anzahl * anteil + 0.5))
		if weg > 0 then
			aenderungen[klassenId] = anzahl - weg
			verloren += weg
		end
	end

	-- Eine Niederlage ohne jeden Verlust waere unbefriedigend:
	-- Dann faellt mindestens ein Schiff der schwaechsten Klasse.
	if verloren == 0 and gesamtVorher > 0 and anteil > 0.05 then
		local schwaechste = nil
		for klassenId, anzahl in daten.Flotte do
			if anzahl > 0 then
				local klasse = FleetConfig.NachId[klassenId]
				if klasse and (not schwaechste or klasse.Angriff < schwaechste.Angriff) then
					schwaechste = klasse
				end
			end
		end
		if schwaechste then
			aenderungen[schwaechste.Id] = daten.Flotte[schwaechste.Id] - 1
			verloren = 1
		end
	end

	for klassenId, neueAnzahl in aenderungen do
		if neueAnzahl <= 0 then
			daten.Flotte[klassenId] = nil
		else
			daten.Flotte[klassenId] = neueAnzahl
		end
	end

	return verloren
end

-- ================================================================
-- ANGRIFF
-- ================================================================
function CombatService:AngriffStarten(spieler: Player, planetId: any)
	-- 1) Ist die Id ueberhaupt eine Zeichenkette und gibt es den Planeten?
	if type(planetId) ~= "string" then
		return
	end

	local zustand = PlanetService.Planeten[planetId]
	if not zustand then
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	-- 2) Schon unterwegs?
	if imFlug[spieler] then
		melden(spieler, "Deine Flotte ist bereits unterwegs.", "Warnung")
		return
	end

	-- 3) Gehoert er mir schon?
	if zustand.Besitzer == spieler then
		melden(spieler, zustand.Config.Name .. " gehört dir bereits.", "Warnung")
		return
	end

	-- 4) Cooldown
	local jetzt = os.clock()
	local letzter = letzterAngriff[spieler] or -math.huge
	local restCooldown = PlanetConfig.Kampf.AngriffsCooldown - (jetzt - letzter)
	if restCooldown > 0 then
		melden(spieler, ("Flotte sammelt sich noch — %ds"):format(math.ceil(restCooldown)), "Warnung")
		return
	end

	-- 5) Schutzschild des aktuellen Besitzers
	if PlanetService:HatSchild(planetId) then
		local rest = math.ceil(zustand.SchildBis - jetzt)
		melden(spieler, ("%s ist noch %ds durch ein Schild geschützt."):format(zustand.Config.Name, rest), "Warnung")
		return
	end

	-- 6) Hat er ueberhaupt eine Flotte?
	local staerke = FleetService:GetStaerke(spieler)
	if staerke <= 0 then
		melden(spieler, "Du hast keine Schiffe. Bau zuerst in der Werft.", "Warnung")
		return
	end

	-- Alles geprueft: Flotte startet
	letzterAngriff[spieler] = jetzt
	imFlug[spieler] = true

	local verteidigung = PlanetService:GetVerteidigung(planetId)
	local chance = PlanetConfig.Siegchance(staerke, verteidigung)

	melden(spieler, ("Flotte greift %s an …"):format(zustand.Config.Name), "Gold")
	flugAnimation(PlotService:GetPlot(spieler), zustand.Config.Position, PlanetConfig.Kampf.Reisezeit)

	-- Startmeldung an den Client: Damit kann die GUI den Cooldown und den
	-- "unterwegs"-Zustand korrekt anzeigen. Wichtig: Der Cooldown laeuft ab
	-- dem START, nicht ab dem Kampfergebnis.
	Net:Event("KampfErgebnis"):FireClient(spieler, {
		Phase = "Start",
		PlanetId = planetId,
		PlanetName = zustand.Config.Name,
		Chance = chance,
		Reisezeit = PlanetConfig.Kampf.Reisezeit,
		Cooldown = PlanetConfig.Kampf.AngriffsCooldown,
	})

	-- Der Kampf wird erst nach der Reisezeit ausgewertet.
	task.delay(PlanetConfig.Kampf.Reisezeit, function()
		imFlug[spieler] = nil
		self:Auswerten(spieler, planetId, staerke, verteidigung, chance)
	end)
end

function CombatService:Auswerten(
	spieler: Player,
	planetId: string,
	staerke: number,
	verteidigung: number,
	chance: number
)
	-- Zwischenzeitlich ausgeloggt?
	if not spieler.Parent then
		return
	end

	local daten = DataService:Get(spieler)
	local zustand = PlanetService.Planeten[planetId]
	if not daten or not zustand then
		return
	end

	local gewonnen = math.random() <= chance
	local verteidiger = zustand.Besitzer

	-- Verluste des Angreifers
	local anteil = PlanetConfig.Verlustanteil(staerke, verteidigung, gewonnen)
	local verloren = flotteReduzieren(daten, anteil)

	if gewonnen then
		PlanetService:Zuweisen(spieler, planetId, true)

		melden(spieler, ("%s erobert!  (+50 %% Einkommen)"):format(zustand.Config.Name), "Gold")

		if verteidiger and verteidiger.Parent and verteidiger ~= spieler then
			melden(
				verteidiger,
				("%s hat dir %s abgenommen!"):format(spieler.DisplayName, zustand.Config.Name),
				"Warnung"
			)
		end
	else
		-- Auch eine Niederlage schwaecht die Verteidigung. So ist ein
		-- zweiter Versuch sinnvoll, statt einfach aussichtslos zu sein.
		if not verteidiger then
			zustand.Verteidigung = math.max(
				zustand.Config.Verteidigung * 0.1,
				zustand.Verteidigung - staerke * 0.25
			)
		end

		melden(spieler, ("Angriff auf %s gescheitert."):format(zustand.Config.Name), "Warnung")

		if verteidiger and verteidiger.Parent and verteidiger ~= spieler then
			melden(
				verteidiger,
				("%s hat %s angegriffen — Verteidigung hält!"):format(spieler.DisplayName, zustand.Config.Name),
				"Gut"
			)
		end
	end

	-- Ergebnisfenster fuer den Angreifer
	Net:Event("KampfErgebnis"):FireClient(spieler, {
		Phase = "Ende",
		PlanetId = planetId,
		PlanetName = zustand.Config.Name,
		Gewonnen = gewonnen,
		Staerke = staerke,
		Verteidigung = verteidigung,
		Chance = chance,
		VerloreneSchiffe = verloren,
	})

	-- Flotte und Planetenliste bei allen auffrischen
	FleetService.FlotteGeaendert:Feuern(spieler)
	FleetService:Senden(spieler)
	PlanetService:SendenAnAlle()

	if verteidiger and verteidiger.Parent then
		FleetService:Senden(verteidiger)
	end

	if Config.Spiel.DebugAusgaben then
		print(("[CombatService] %s -> %s | %d vs %d | %.0f%% | %s | -%d Schiffe")
			:format(spieler.Name, planetId, staerke, verteidigung, chance * 100,
				gewonnen and "SIEG" or "NIEDERLAGE", verloren))
	end
end

-- Restlicher Cooldown in Sekunden (fuer die GUI-Anzeige)
function CombatService:GetCooldown(spieler: Player): number
	local letzter = letzterAngriff[spieler]
	if not letzter then
		return 0
	end
	return math.max(0, PlanetConfig.Kampf.AngriffsCooldown - (os.clock() - letzter))
end

function CombatService:Init()
	Net:Event("AngriffStarten").OnServerEvent:Connect(function(spieler, planetId)
		self:AngriffStarten(spieler, planetId)
	end)

	Players.PlayerRemoving:Connect(function(spieler)
		letzterAngriff[spieler] = nil
		imFlug[spieler] = nil
	end)

	if Config.Spiel.DebugAusgaben then
		print("[CombatService] bereit")
	end
end

return CombatService
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "CurrencyService",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	CurrencyService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > CurrencyService

	WARUM HIER?
	Das ist die einzige Stelle im ganzen Spiel, an der sich Geld
	aendern darf. Liegt sie im ServerScriptService, kann kein Client
	sie aufrufen oder veraendern -> Exploit-Schutz.

	REGEL FUER DAS GANZE PROJEKT:
	Kein anderes Script darf "daten.Geld = ..." schreiben.
	Immer ueber CurrencyService:Hinzufuegen() / :Abbuchen().
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlanetConfig = require(ReplicatedStorage:WaitForChild("PlanetConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)

local CurrencyService = {}

-- Spieler, deren Anzeige sich geaendert hat. Wird gebuendelt verschickt,
-- damit wir nicht 5x pro Sekunde ein RemoteEvent pro Spieler feuern.
local schmutzig: { [Player]: boolean } = {}

-- Serverweiter Bonus aus Zufallsereignissen (z. B. Meteoritenschauer).
-- Wird vom EventService gesetzt und gilt fuer ALLE Spieler gleichzeitig.
CurrencyService.EventMultiplikator = 1
CurrencyService.EventName = nil :: string?
CurrencyService.EventEndeUm = 0

-- Summiert den Spezialbonus aller eroberten Planeten einer Bonus-Art.
-- BonusArt ist "Einkommen", "Bauzeit", "Verteidigung" oder "Lager"
-- (siehe PlanetConfig.Typen). Andere Services rufen das ebenfalls auf.
function CurrencyService:GetPlanetenTypBonus(spieler: Player, bonusArt: string): number
	local daten = DataService:Get(spieler)
	if not daten or not daten.Planeten then
		return 0
	end

	local summe = 0
	for planetId in daten.Planeten do
		local planet = PlanetConfig.NachId[planetId]
		local typ = planet and PlanetConfig.Typen[planet.Typ]
		if typ and typ.BonusArt == bonusArt then
			summe += typ.BonusWert
		end
	end

	return summe
end

-- Stufe einer Technologie (0 = nicht erforscht)
function CurrencyService:GetTechStufe(spieler: Player, techId: string): number
	local daten = DataService:Get(spieler)
	if not daten or not daten.Tech then
		return 0
	end
	return daten.Tech[techId] or 0
end

-- ================================================================
-- MULTIPLIKATOR
-- Formel:  (1 + Planeten*0.5 + Rebirths*0.25) * Gamepass
--
-- ADDITIV heisst: 2 Planeten = +100 % (also Faktor 2.0), nicht 1.5*1.5.
-- Willst du MULTIPLIKATIV, ersetze die Schleife unten durch:
--     basis *= (1 + Config.Multiplikatoren.BonusProPlanet)
-- ================================================================
function CurrencyService:GetMultiplikator(spieler: Player): number
	local daten = DataService:Get(spieler)
	if not daten then
		return 1
	end

	local basis = 1

	-- Eroberte Planeten: +50 % pro Planet, additiv
	local anzahlPlaneten = 0
	for _ in daten.Planeten do
		anzahlPlaneten += 1
	end
	basis += anzahlPlaneten * Config.Multiplikatoren.BonusProPlanet

	-- Spezialbonus der Rohstoffwelten obendrauf
	basis += self:GetPlanetenTypBonus(spieler, "Einkommen")

	-- Rebirths
	basis += (daten.Rebirths or 0) * Config.Multiplikatoren.BonusProRebirth

	-- Gamepass. Solange der Gamepass nicht existiert, ist der
	-- Eintrag nil und der Multiplikator bleibt 1.
	if daten.Gamepasses and daten.Gamepasses.DoppeltesEinkommen then
		basis *= Config.Multiplikatoren.Gamepass2xEinkommen
	end

	-- Serverweites Zufallsereignis
	basis *= self.EventMultiplikator

	return basis
end

-- ================================================================
-- GELD LESEN / AENDERN
-- ================================================================
function CurrencyService:GetGeld(spieler: Player): number
	local daten = DataService:Get(spieler)
	return daten and daten.Geld or 0
end

function CurrencyService:Hinzufuegen(spieler: Player, betrag: number)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	betrag = Util.SichererBetrag(betrag)
	if betrag <= 0 then
		return
	end

	daten.Geld += betrag
	daten.Statistik.GesamtVerdient += betrag
	self:MarkiereAenderung(spieler)
end

-- Versucht abzubuchen. Gibt true zurueck, wenn es geklappt hat.
-- DAS ist die zentrale Kauf-Validierung: Der Server prueft den Kontostand,
-- nie der Client.
function CurrencyService:Abbuchen(spieler: Player, betrag: number): boolean
	local daten = DataService:Get(spieler)
	if not daten then
		return false
	end

	betrag = Util.SichererBetrag(betrag)
	if daten.Geld < betrag then
		return false
	end

	daten.Geld -= betrag
	self:MarkiereAenderung(spieler)
	return true
end

-- ================================================================
-- LAGER (noch nicht eingesammelte Credits)
-- ================================================================
function CurrencyService:GetLagerKapazitaet(spieler: Player): number
	local daten = DataService:Get(spieler)
	if not daten then
		return Config.Lager.Startkapazitaet
	end

	local kapazitaet = Config.Lager.Startkapazitaet
	for _, eintrag in Config.Kaufbares do
		if eintrag.Typ == "Lager" and daten.Gekauft[eintrag.Id] then
			kapazitaet += eintrag.Wirkung.LagerBonus
		end
	end

	-- Handelswelten und die Frachtsysteme-Technologie vergroessern das
	-- Lager prozentual — sie wirken also auf die ausgebaute Kapazitaet.
	local prozentual = 1
		+ self:GetPlanetenTypBonus(spieler, "Lager")
		+ self:GetTechStufe(spieler, "Frachtsysteme") * 0.25

	return math.floor(kapazitaet * prozentual)
end

-- Legt Credits ins Lager. Gibt zurueck, wie viel wirklich passte.
function CurrencyService:InsLager(spieler: Player, betrag: number): number
	local daten = DataService:Get(spieler)
	if not daten then
		return 0
	end

	local kapazitaet = self:GetLagerKapazitaet(spieler)
	local platz = math.max(0, kapazitaet - daten.Lager)
	local menge = math.min(Util.SichererBetrag(betrag), platz)

	if menge > 0 then
		daten.Lager += menge
		self:MarkiereAenderung(spieler)
	end

	return menge
end

-- Leert das Lager und schreibt alles aufs Konto. Gibt den Betrag zurueck.
function CurrencyService:LagerEinsammeln(spieler: Player): number
	local daten = DataService:Get(spieler)
	if not daten or daten.Lager <= 0 then
		return 0
	end

	local betrag = math.floor(daten.Lager)
	daten.Lager = 0
	self:Hinzufuegen(spieler, betrag)
	return betrag
end

-- ================================================================
-- ANZEIGE (leaderstats + GUI)
-- ================================================================
function CurrencyService:LeaderstatsAnlegen(spieler: Player)
	-- "leaderstats" ist ein von Roblox fest vorgegebener Name.
	-- Alles darin erscheint automatisch in der Spielerliste (Tab-Taste).
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local geld = Instance.new("IntValue")   -- IntValue ist 64-Bit, reicht dicke
	geld.Name = "Credits"
	geld.Value = self:GetGeld(spieler)
	geld.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	local daten = DataService:Get(spieler)
	rebirths.Value = daten and daten.Rebirths or 0
	rebirths.Parent = leaderstats

	leaderstats.Parent = spieler
end

-- Merkt vor, dass dieser Spieler ein GUI-Update braucht.
function CurrencyService:MarkiereAenderung(spieler: Player)
	schmutzig[spieler] = true
end

-- Schickt den aktuellen Stand sofort an den Client.
function CurrencyService:Senden(spieler: Player)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	schmutzig[spieler] = nil

	-- leaderstats aktualisieren
	local leaderstats = spieler:FindFirstChild("leaderstats")
	if leaderstats then
		local geld = leaderstats:FindFirstChild("Credits")
		if geld then
			(geld :: IntValue).Value = math.floor(daten.Geld)
		end
		local rebirths = leaderstats:FindFirstChild("Rebirths")
		if rebirths then
			(rebirths :: IntValue).Value = daten.Rebirths or 0
		end
	end

	-- Nur das schicken, was die GUI wirklich braucht.
	-- Niemals die komplette Datentabelle senden!
	Net:Event("DatenUpdate"):FireClient(spieler, {
		Geld = math.floor(daten.Geld),
		Lager = math.floor(daten.Lager),
		LagerKapazitaet = self:GetLagerKapazitaet(spieler),
		Multiplikator = self:GetMultiplikator(spieler),
		Rebirths = daten.Rebirths or 0,
		GesamtVerdient = math.floor(daten.Statistik.GesamtVerdient),
		AnzahlPlaneten = (function()
			local n = 0
			for _ in daten.Planeten do
				n += 1
			end
			return n
		end)(),
		EventName = self.EventName,
		EventRestzeit = math.max(0, self.EventEndeUm - os.clock()),
	})
end

function CurrencyService:Init()
	-- Gebuendeltes Senden: max. 5 Updates pro Sekunde und Spieler.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for spieler in schmutzig do
				if spieler.Parent then
					self:Senden(spieler)
				else
					schmutzig[spieler] = nil
				end
			end
		end
	end)

	-- Client bittet nach dem Laden um eine frische Kopie
	Net:Event("DatenAnfrage").OnServerEvent:Connect(function(spieler)
		self:Senden(spieler)
	end)

	Players.PlayerRemoving:Connect(function(spieler)
		schmutzig[spieler] = nil
	end)
end

return CurrencyService
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "DataService",
		Klasse = "ModuleScript",
		Quelle = [==[
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

	-- Planeten (Schritt 3)
	Planeten = {},       -- ["P01"] = true

	-- Technologie (Schritt 5)
	Tech = {},           -- ["Waffensysteme"] = 3

	-- Monetarisierung (Schritt 6)
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
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "DropperService",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	DropperService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > DropperService

	AUFGABE
	Der passive Geldfluss. Jeder gekaufte Dropper schickt in festen
	Abstaenden eine "Lieferung" zum Sammelkern. Kommt sie an, landet
	der Wert im Lager des Spielers.

	WARUM KEINE ECHTE PHYSIK?
	Klassische Tycoons lassen Parts ueber Foerderbaender rutschen.
	Das sind pro Spieler dutzende unverankerte Parts — auf Handys der
	haeufigste Grund fuer Ruckeln. Wir benutzen stattdessen verankerte
	Parts mit TweenService: sieht praktisch gleich aus, kostet fast
	nichts und kann nicht "steckenbleiben".

	Der WERT einer Lieferung wird beim ABSCHICKEN berechnet:
	    Betrag * Plot-Wert-Upgrades * Spieler-Multiplikator
	Der Spieler-Multiplikator enthaelt Planeten-Boni und Rebirths.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)

local DropperService = {}

-- Sicherheitsgrenze: nie mehr als so viele Lieferungen gleichzeitig
-- pro Plot in der Luft. Schuetzt vor Lag, falls jemand extrem viele
-- Dropper besitzt.
local MAX_LIEFERUNGEN_PRO_PLOT = 40
local FLUGZEIT = 1.1 -- Sekunden von der Duese bis zum Kern

local function sendeLieferung(plot: any, spieler: Player, dropperTyp: any, startPos: Vector3, wert: number)
	if #plot.DropOrdner:GetChildren() >= MAX_LIEFERUNGEN_PRO_PLOT then
		-- Zu viel los: Wert trotzdem gutschreiben, aber ohne Animation.
		CurrencyService:InsLager(spieler, wert)
		return
	end

	local paket = Util.NeuerPart({
		Name = "Lieferung",
		Size = Vector3.new(2.2, 2.2, 2.2),
		Color = dropperTyp.Farbe,
		Material = dropperTyp.Material,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(startPos),
	})

	local zielPos = PlotService:ZuWelt(plot, Config.PlotPunkte.Sammelkern) + Vector3.new(0, 8, 0)

	paket.Parent = plot.DropOrdner

	-- Notbremse: Falls der Tween aus irgendeinem Grund nicht fertig wird,
	-- raeumt Debris den Part nach 5 Sekunden weg.
	Debris:AddItem(paket, 5)

	local tween = TweenService:Create(
		paket,
		TweenInfo.new(FLUGZEIT, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			CFrame = CFrame.new(zielPos) * CFrame.Angles(math.rad(180), math.rad(180), 0),
			Size = Vector3.new(0.6, 0.6, 0.6),
		}
	)

	tween.Completed:Connect(function(status)
		-- Abgebrochen (z. B. weil der Spieler das Spiel verlassen hat und der
		-- Plot geleert wurde) -> keine Gutschrift.
		if status ~= Enum.PlaybackState.Completed then
			return
		end

		paket:Destroy()

		-- Erst JETZT gibt es Geld — und nur, wenn der Plot noch demselben
		-- Spieler gehoert.
		if plot.Besitzer == spieler and spieler.Parent then
			CurrencyService:InsLager(spieler, wert)
		end
	end)

	tween:Play()
end

function DropperService:Tick()
	local jetzt = os.clock()

	for _, plot in PlotService.Plots do
		local spieler = plot.Besitzer
		if spieler and spieler.Parent and #plot.Dropper > 0 then
			local daten = DataService:Get(spieler)

			if daten then
				local kapazitaet = CurrencyService:GetLagerKapazitaet(spieler)
				local lagerVoll = daten.Lager >= kapazitaet
				local spielerMult = CurrencyService:GetMultiplikator(spieler)

				for _, dropper in plot.Dropper do
					if jetzt >= dropper.NaechsterDrop then
						local typ = Config.DropperTypen[dropper.Typ]

						-- Naechsten Zeitpunkt setzen, auch wenn das Lager voll
						-- ist. Sonst wuerde der Dropper nach dem Einsammeln
						-- alle gestauten Lieferungen auf einmal abfeuern.
						dropper.NaechsterDrop = jetzt + math.max(0.2, typ.Intervall * plot.TempoMult)

						if not lagerVoll then
							local wert = Util.SichererBetrag(typ.Betrag * plot.WertMult * spielerMult)
							if wert > 0 then
								sendeLieferung(plot, spieler, typ, dropper.Duese.Position, wert)
							end
						end
					end
				end
			end
		end
	end
end

-- Wie viele Credits produziert dieser Spieler pro Sekunde?
-- Gebraucht fuer Zufallsereignisse und Credit-Pakete im Shop: Deren Wert
-- richtet sich nach der Produktion, damit ein Paket fuer Anfaenger UND
-- fuer Fortgeschrittene sinnvoll bleibt.
function DropperService:GetEinkommenProSekunde(spieler: Player): number
	local plot = PlotService:GetPlot(spieler)
	if not plot or #plot.Dropper == 0 then
		return 0
	end

	local spielerMult = CurrencyService:GetMultiplikator(spieler)
	local summe = 0

	for _, dropper in plot.Dropper do
		local typ = Config.DropperTypen[dropper.Typ]
		if typ then
			local intervall = math.max(0.2, typ.Intervall * plot.TempoMult)
			summe += (typ.Betrag * plot.WertMult * spielerMult) / intervall
		end
	end

	return summe
end

-- Auto-Collect: leert das Lager automatisch.
-- Aktiv nur fuer Spieler mit dem entsprechenden Gamepass (Schritt 6).
function DropperService:AutoSammelSchleife()
	while true do
		task.wait(Config.Lager.AutoSammelIntervall)

		for _, spieler in Players:GetPlayers() do
			local daten = DataService:Get(spieler)
			if daten and daten.Gamepasses and daten.Gamepasses.AutoCollect then
				CurrencyService:LagerEinsammeln(spieler)
			end
		end
	end
end

function DropperService:Init()
	RunService.Heartbeat:Connect(function()
		self:Tick()
	end)

	task.spawn(function()
		self:AutoSammelSchleife()
	end)

	if Config.Spiel.DebugAusgaben then
		print("[DropperService] bereit")
	end
end

return DropperService
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "EventService",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	EventService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > EventService

	AUFGABE
	Zufallsereignisse, die den Server lebendig machen. Alle paar
	Minuten passiert eines von drei Dingen:

	  1. METEORITENSCHAUER — doppeltes Einkommen fuer alle, 90 s lang
	  2. PIRATEN-ÜBERFALL  — ein zufaelliger Spieler wird 20 s vorher
	     gewarnt. Wer rechtzeitig sammelt, verliert nichts. Sonst
	     stehlen die Piraten bis zu 50 % des Lagers — jede Stufe
	     Orbitalgeschütze zieht 10 Prozentpunkte davon ab.
	  3. HANDELSKONVOI — auf jedem Plot erscheinen Frachtkisten.
	     Einsammeln bringt Credits.

	WARUM DAS GUT FUERS SPIEL IST:
	Ein reiner Idle-Tycoon laeuft von allein. Diese Ereignisse geben
	dem Spieler einen Grund, tatsaechlich hinzuschauen — und der
	Piraten-Überfall gibt dem Lager-Limit und den Orbitalgeschützen
	endlich einen echten Zweck.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local DropperService = require(script.Parent.DropperService)

local EventService = {}

local Ereignisse = TechConfig.Ereignisse

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[EventService]", ...)
	end
end

local function meldeAllen(text: string, farbe: string)
	for _, spieler in Players:GetPlayers() do
		Net:Event("Benachrichtigung"):FireClient(spieler, { Text = text, Farbe = farbe })
	end
end

-- ================================================================
-- 1) METEORITENSCHAUER
-- ================================================================
function EventService:Meteoritenschauer()
	local daten = Ereignisse.Meteoritenschauer

	CurrencyService.EventMultiplikator = daten.Multiplikator
	CurrencyService.EventName = daten.Name
	CurrencyService.EventEndeUm = os.clock() + daten.Dauer

	meldeAllen(daten.Text, "Gold")
	log("Meteoritenschauer gestartet")

	-- Alle Anzeigen sofort auffrischen, damit der neue Multiplikator
	-- oben rechts direkt sichtbar ist.
	for _, spieler in Players:GetPlayers() do
		CurrencyService:MarkiereAenderung(spieler)
	end

	task.delay(daten.Dauer, function()
		CurrencyService.EventMultiplikator = 1
		CurrencyService.EventName = nil
		CurrencyService.EventEndeUm = 0

		for _, spieler in Players:GetPlayers() do
			CurrencyService:MarkiereAenderung(spieler)
		end

		meldeAllen("Der Meteoritenschauer ist vorüber.", "Text")
		log("Meteoritenschauer beendet")
	end)
end

-- ================================================================
-- 2) PIRATEN-ÜBERFALL
-- ================================================================
function EventService:Piratenueberfall()
	local daten = Ereignisse.Piratenueberfall

	-- Ziel: ein zufaelliger Spieler, der ueberhaupt etwas im Lager hat.
	local kandidaten = {}
	for _, spieler in Players:GetPlayers() do
		local spielerDaten = DataService:Get(spieler)
		if spielerDaten and spielerDaten.Lager > 0 then
			table.insert(kandidaten, spieler)
		end
	end

	if #kandidaten == 0 then
		return
	end

	local ziel = kandidaten[math.random(#kandidaten)]

	Net:Event("Benachrichtigung"):FireClient(ziel, {
		Text = daten.Warnung,
		Farbe = "Warnung",
	})
	log("Piraten greifen an:", ziel.Name)

	task.delay(daten.Vorwarnzeit, function()
		if not ziel.Parent then
			return
		end

		local spielerDaten = DataService:Get(ziel)
		if not spielerDaten or spielerDaten.Lager <= 0 then
			Net:Event("Benachrichtigung"):FireClient(ziel, {
				Text = "Die Piraten fanden ein leeres Lager. Gut gemacht!",
				Farbe = "Gut",
			})
			return
		end

		-- Orbitalgeschütze reduzieren den Verlust, ab Stufe 5 auf null.
		local stufe = CurrencyService:GetTechStufe(ziel, "Orbitalgeschuetze")
		local anteil = math.max(0, daten.Grundverlust - stufe * daten.SchutzProStufe)

		if anteil <= 0 then
			Net:Event("Benachrichtigung"):FireClient(ziel, {
				Text = "Deine Orbitalgeschütze haben den Überfall abgewehrt!",
				Farbe = "Gut",
			})
			return
		end

		local verlust = math.floor(spielerDaten.Lager * anteil)
		spielerDaten.Lager -= verlust
		CurrencyService:MarkiereAenderung(ziel)

		Net:Event("Benachrichtigung"):FireClient(ziel, {
			Text = ("Piraten haben %s %s gestohlen!"):format(
				Util.FormatGeld(verlust),
				Config.Spiel.Waehrung
			),
			Farbe = "Warnung",
		})
	end)
end

-- ================================================================
-- 3) HANDELSKONVOI
-- ================================================================
local function baueKiste(plot: any, spieler: Player, wert: number, lebensdauer: number)
	-- Zufaellige Stelle auf dem Plot, aber nicht direkt am Rand
	local lokal = Vector3.new(math.random(-30, 30), 3, math.random(-10, 40))
	local position = PlotService:ZuWelt(plot, lokal)

	local kiste = Util.NeuerPart({
		Name = "Frachtkiste",
		Size = Vector3.new(5, 5, 5),
		Color = Color3.fromRGB(255, 205, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0),
	})
	kiste.Parent = plot.Model

	local schild = Instance.new("BillboardGui")
	schild.Size = UDim2.fromScale(10, 2.4)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	schild.MaxDistance = 180
	schild.Parent = kiste

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 225, 150)
	text.TextStrokeTransparency = 0.35
	text.Text = "+" .. Util.FormatGeld(wert)
	text.Parent = schild

	-- Schweben und drehen, damit sie auffaellt
	TweenService:Create(
		kiste,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = kiste.CFrame + Vector3.new(0, 2, 0) }
	):Play()

	-- Verschwindet von selbst, wenn sie niemand holt
	Debris:AddItem(kiste, lebensdauer)

	local eingesammelt = false
	kiste.Touched:Connect(function(getroffen)
		if eingesammelt then
			return
		end

		local charakter = getroffen:FindFirstAncestorOfClass("Model")
		if not charakter or Players:GetPlayerFromCharacter(charakter) ~= spieler then
			return
		end

		eingesammelt = true
		CurrencyService:Hinzufuegen(spieler, wert)
		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = "Frachtkiste: +" .. Util.FormatGeld(wert) .. " " .. Config.Spiel.Waehrung,
			Farbe = "Gold",
		})
		kiste:Destroy()
	end)
end

function EventService:Handelskonvoi()
	local daten = Ereignisse.Handelskonvoi
	local jemandDabei = false

	for _, spieler in Players:GetPlayers() do
		local plot = PlotService:GetPlot(spieler)
		if plot then
			-- Der Wert richtet sich nach der eigenen Produktion, damit die
			-- Kiste in jeder Spielphase interessant bleibt.
			local proSekunde = DropperService:GetEinkommenProSekunde(spieler)
			local wert = math.max(100, math.floor(proSekunde * daten.SekundenProduktion))

			for _ = 1, daten.Kisten do
				baueKiste(plot, spieler, wert, daten.Dauer)
			end
			jemandDabei = true
		end
	end

	if jemandDabei then
		meldeAllen(daten.Text, "Gold")
		log("Handelskonvoi gestartet")
	end
end

-- ================================================================
-- STEUERUNG
-- ================================================================
function EventService:ZufallsereignisStarten()
	-- Ohne Spieler brauchen wir kein Ereignis
	if #Players:GetPlayers() == 0 then
		return
	end

	local auswahl = math.random(3)
	if auswahl == 1 then
		self:Meteoritenschauer()
	elseif auswahl == 2 then
		self:Piratenueberfall()
	else
		self:Handelskonvoi()
	end
end

function EventService:Init()
	task.spawn(function()
		-- Beim Serverstart nicht sofort: Erst sollen die Spieler ankommen.
		task.wait(Ereignisse.MinAbstand)

		while true do
			self:ZufallsereignisStarten()
			task.wait(math.random(Ereignisse.MinAbstand, Ereignisse.MaxAbstand))
		end
	end)

	log("bereit")
end

return EventService
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "FleetService",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	FleetService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > FleetService

	AUFGABE
	Die komplette Flottenverwaltung: Schiffe in Auftrag geben,
	Bauwarteschlange abarbeiten, Hangar erweitern, Flottenstaerke
	ausrechnen.

	EXPLOIT-SCHUTZ — das Wichtigste an dieser Datei:
	Der Client schickt nur "Ich haette gern 5 Jaeger". Alles andere
	entscheidet der Server:
	   1. Gibt es diese Schiffsklasse ueberhaupt?
	   2. Ist die Anzahl eine sinnvolle ganze Zahl? (kein 1e99, kein
	      "abc", kein -5, kein NaN)
	   3. Ist die Klasse fuer diesen Spieler freigeschaltet?
	   4. Passt das noch in die Warteschlange?
	   5. Passt das noch in den Hangar?
	   6. Kann er es bezahlen?
	Erst wenn ALLE sechs Punkte stimmen, wird abgebucht.

	WARUM os.time() STATT EINES TIMERS?
	Bauauftraege speichern einen absoluten Zeitstempel. Dadurch laufen
	sie weiter, waehrend der Spieler offline ist — er kommt zurueck und
	seine Schiffe stehen fertig im Hangar. Ein laufender Timer waere
	beim Verlassen des Servers einfach weg.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local FleetConfig = require(ReplicatedStorage:WaitForChild("FleetConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Signal = require(ReplicatedStorage:WaitForChild("Signal"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local FleetService = {}

-- Wird gefeuert, wenn sich die Flotte aendert. Der HangarService haengt
-- sich hier an und baut die sichtbaren Schiffe neu.
FleetService.FlotteGeaendert = Signal.neu()

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[FleetService]", ...)
	end
end

-- ================================================================
-- ABFRAGEN
-- ================================================================

-- Ist diese Klasse fuer den Spieler freigeschaltet?
function FleetService:IstFreigeschaltet(spieler: Player, klasse: any): boolean
	if not klasse.NurGamepass then
		return true
	end

	local daten = DataService:Get(spieler)
	if not daten or not daten.Gamepasses then
		return false
	end
	return daten.Gamepasses[klasse.NurGamepass] == true
end

function FleetService:GetKapazitaet(spieler: Player): number
	local daten = DataService:Get(spieler)
	local stufe = daten and daten.HangarStufe or 0
	return FleetConfig.Allgemein.BasisKapazitaet
		+ stufe * FleetConfig.Allgemein.SlotsProStufe
end

-- Belegte Hangar-Plaetze. Schiffe in der Warteschlange zaehlen MIT —
-- sonst koennte man den Hangar per Dauerklick ueberfuellen.
function FleetService:GetBelegt(spieler: Player): number
	local daten = DataService:Get(spieler)
	if not daten then
		return 0
	end

	local belegt = 0

	for klassenId, anzahl in daten.Flotte do
		local klasse = FleetConfig.NachId[klassenId]
		if klasse then
			belegt += klasse.Platzbedarf * anzahl
		end
	end

	for _, auftrag in daten.Bauauftraege do
		local klasse = FleetConfig.NachId[auftrag.Klasse]
		if klasse then
			belegt += klasse.Platzbedarf
		end
	end

	return belegt
end

-- Gesamte Angriffsstaerke der fertigen Schiffe.
-- Schritt 3 (Eroberung) vergleicht diesen Wert mit der Planeten-Verteidigung.
function FleetService:GetStaerke(spieler: Player): number
	local daten = DataService:Get(spieler)
	if not daten then
		return 0
	end

	local staerke = 0
	for klassenId, anzahl in daten.Flotte do
		local klasse = FleetConfig.NachId[klassenId]
		if klasse then
			staerke += klasse.Angriff * anzahl
		end
	end

	return math.floor(staerke * self:GetAngriffsMultiplikator(spieler))
end

function FleetService:GetVerteidigung(spieler: Player): number
	local daten = DataService:Get(spieler)
	if not daten then
		return 0
	end

	local wert = 0
	for klassenId, anzahl in daten.Flotte do
		local klasse = FleetConfig.NachId[klassenId]
		if klasse then
			wert += klasse.Verteidigung * anzahl
		end
	end

	return math.floor(wert * self:GetAngriffsMultiplikator(spieler))
end

-- Angriffs-Multiplikator aus der Technologie "Waffensysteme":
-- +15 % pro Stufe (der Wert steht in TechConfig).
function FleetService:GetAngriffsMultiplikator(spieler: Player): number
	local daten = DataService:Get(spieler)
	if not daten or not daten.Tech then
		return 1
	end

	local multiplikator = 1
	if daten.Tech.Waffensysteme then
		multiplikator += 0.15 * daten.Tech.Waffensysteme
	end
	return multiplikator
end

-- Bauzeit-Multiplikator (kleiner = schneller). Zwei Quellen:
--   - Technologie "Werftautomatik": -10 % pro Stufe
--   - Energiewelten: -8 % pro eroberten Planeten dieses Typs
function FleetService:GetBauzeitMultiplikator(spieler: Player): number
	local daten = DataService:Get(spieler)
	if not daten then
		return 1
	end

	local multiplikator = 1

	if daten.Tech and daten.Tech.Werftautomatik then
		multiplikator *= 0.9 ^ daten.Tech.Werftautomatik
	end

	multiplikator *= math.max(0.1, 1 - CurrencyService:GetPlanetenTypBonus(spieler, "Bauzeit"))

	-- Untergrenze, damit Bauzeiten nie auf praktisch null fallen
	return math.max(0.2, multiplikator)
end

-- ================================================================
-- BAUAUFTRAG (die zentrale Validierung)
-- ================================================================
function FleetService:BauAuftragGeben(spieler: Player, klassenId: any, anzahl: any)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	local function ablehnen(text: string)
		Net:Event("Benachrichtigung"):FireClient(spieler, { Text = text, Farbe = "Warnung" })
	end

	-- 1) Gibt es die Klasse?
	if type(klassenId) ~= "string" then
		return -- gar kein gueltiger Aufruf: still ignorieren
	end
	local klasse = FleetConfig.NachId[klassenId]
	if not klasse then
		return
	end

	-- 2) Ist die Anzahl eine brauchbare ganze Zahl?
	-- anzahl ~= anzahl faengt NaN ab, das sonst jede Pruefung durchrutscht.
	if type(anzahl) ~= "number" or anzahl ~= anzahl then
		return
	end
	anzahl = math.floor(anzahl)
	if anzahl < 1 then
		return
	end
	anzahl = math.min(anzahl, FleetConfig.Allgemein.MaxProKauf)

	-- 3) Freigeschaltet?
	if not self:IstFreigeschaltet(spieler, klasse) then
		ablehnen(klasse.Name .. " braucht den passenden Gamepass.")
		return
	end

	-- 4) Platz in der Warteschlange?
	if #daten.Bauauftraege + anzahl > FleetConfig.Allgemein.MaxWarteschlange then
		ablehnen("Die Werft ist ausgelastet.")
		return
	end

	-- 5) Platz im Hangar?
	local freiePlaetze = self:GetKapazitaet(spieler) - self:GetBelegt(spieler)
	if klasse.Platzbedarf * anzahl > freiePlaetze then
		ablehnen("Nicht genug Hangar-Plätze. Hangar erweitern!")
		return
	end

	-- 6) Bezahlbar? (Abbuchen prueft den Kontostand selbst)
	local kosten = klasse.Preis * anzahl
	if not CurrencyService:Abbuchen(spieler, kosten) then
		ablehnen("Nicht genug Credits für " .. anzahl .. "x " .. klasse.Name)
		return
	end

	-- Alles geprueft -> in die Warteschlange einreihen.
	-- Die Schiffe werden NACHEINANDER gebaut: jedes startet, wenn das
	-- vorherige fertig ist.
	local bauzeit = klasse.Bauzeit * self:GetBauzeitMultiplikator(spieler)
	local fertigUm = os.time()

	for _, auftrag in daten.Bauauftraege do
		if auftrag.FertigUm > fertigUm then
			fertigUm = auftrag.FertigUm
		end
	end

	local dauer = math.max(1, math.floor(bauzeit))
	for _ = 1, anzahl do
		local startUm = fertigUm
		fertigUm += dauer
		table.insert(daten.Bauauftraege, {
			Klasse = klasse.Id,
			StartUm = startUm,   -- damit der Client einen exakten Fortschrittsbalken zeichnen kann
			FertigUm = fertigUm,
		})
	end

	log(spieler.Name, "ordert", anzahl .. "x", klasse.Id, "fuer", kosten)

	Net:Event("Benachrichtigung"):FireClient(spieler, {
		Text = anzahl .. "x " .. klasse.Name .. " in Auftrag gegeben",
		Farbe = "Gut",
	})

	self:Senden(spieler)
end

-- ================================================================
-- HANGAR ERWEITERN
-- ================================================================
function FleetService:HangarErweitern(spieler: Player)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	local stufe = daten.HangarStufe or 0
	local preis = FleetConfig.HangarPreis(stufe)

	if not preis then
		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = "Der Hangar ist bereits voll ausgebaut.",
			Farbe = "Warnung",
		})
		return
	end

	if not CurrencyService:Abbuchen(spieler, preis) then
		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = "Nicht genug Credits für den Hangar-Ausbau.",
			Farbe = "Warnung",
		})
		return
	end

	daten.HangarStufe = stufe + 1

	Net:Event("Benachrichtigung"):FireClient(spieler, {
		Text = ("Hangar-Stufe %d  (+%d Plätze)"):format(
			daten.HangarStufe,
			FleetConfig.Allgemein.SlotsProStufe
		),
		Farbe = "Gold",
	})

	self:Senden(spieler)
end

-- ================================================================
-- WARTESCHLANGE ABARBEITEN
-- ================================================================

-- Prueft, ob Bauauftraege fertig sind. Gibt die Anzahl fertiger Schiffe zurueck.
function FleetService:PruefeFertigeBauten(spieler: Player): number
	local daten = DataService:Get(spieler)
	if not daten or #daten.Bauauftraege == 0 then
		return 0
	end

	local jetzt = os.time()
	local fertig = 0
	local verworfen = 0
	local uebrig = {}

	for _, auftrag in daten.Bauauftraege do
		local klasse = FleetConfig.NachId[auftrag.Klasse]

		if not klasse then
			-- Die Klasse gibt es in der Config nicht mehr. Auftrag wegwerfen,
			-- sonst wuerde er fuer immer Hangar-Plaetze blockieren.
			verworfen += 1
		elseif auftrag.FertigUm <= jetzt then
			daten.Flotte[auftrag.Klasse] = (daten.Flotte[auftrag.Klasse] or 0) + 1
			fertig += 1
		else
			table.insert(uebrig, auftrag)
		end
	end

	if fertig > 0 or verworfen > 0 then
		daten.Bauauftraege = uebrig
		if fertig > 0 then
			self.FlotteGeaendert:Feuern(spieler)
		end
		self:Senden(spieler)
	end

	return fertig
end

-- ================================================================
-- AN DEN CLIENT SCHICKEN
-- ================================================================
function FleetService:Senden(spieler: Player)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	-- Die Warteschlange wird auf das Noetigste eingedampft.
	-- Der Client rechnet die Restzeit selbst aus dem Zeitstempel aus,
	-- damit der Countdown fluessig laeuft statt einmal pro Sekunde zu springen.
	local warteschlange = {}
	for index, auftrag in daten.Bauauftraege do
		warteschlange[index] = {
			Klasse = auftrag.Klasse,
			StartUm = auftrag.StartUm,
			FertigUm = auftrag.FertigUm,
		}
	end

	Net:Event("FlotteUpdate"):FireClient(spieler, {
		Flotte = daten.Flotte,
		Warteschlange = warteschlange,
		Serverzeit = os.time(),          -- damit der Client seine Uhr abgleichen kann
		Staerke = self:GetStaerke(spieler),
		Verteidigung = self:GetVerteidigung(spieler),
		Kapazitaet = self:GetKapazitaet(spieler),
		Belegt = self:GetBelegt(spieler),
		HangarStufe = daten.HangarStufe or 0,
		HangarPreis = FleetConfig.HangarPreis(daten.HangarStufe or 0),
		Freigeschaltet = (function()
			-- Welche Klassen darf dieser Spieler bauen?
			local liste = {}
			for _, klasse in FleetConfig.Klassen do
				liste[klasse.Id] = self:IstFreigeschaltet(spieler, klasse)
			end
			return liste
		end)(),
	})
end

-- ================================================================
-- INIT
-- ================================================================
function FleetService:Init()
	-- Client bittet um seine Flottendaten (z. B. beim Oeffnen der Werft)
	Net:Event("FlotteAnfrage").OnServerEvent:Connect(function(spieler)
		self:Senden(spieler)
	end)

	Net:Event("SchiffBauen").OnServerEvent:Connect(function(spieler, klassenId, anzahl)
		self:BauAuftragGeben(spieler, klassenId, anzahl)
	end)

	Net:Event("HangarErweitern").OnServerEvent:Connect(function(spieler)
		self:HangarErweitern(spieler)
	end)

	-- Warteschlange im Sekundentakt pruefen. Haeufiger waere Verschwendung:
	-- Bauzeiten sind in ganzen Sekunden angegeben.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, spieler in Players:GetPlayers() do
				local fertig = self:PruefeFertigeBauten(spieler)
				if fertig > 0 then
					Net:Event("Benachrichtigung"):FireClient(spieler, {
						Text = fertig == 1
							and "Ein Schiff ist fertiggestellt"
							or (fertig .. " Schiffe sind fertiggestellt"),
						Farbe = "Gut",
					})
				end
			end
		end
	end)

	log("bereit")
end

-- Wird von Main aufgerufen, sobald ein Spieler fertig geladen ist.
-- Holt Bauauftraege nach, die waehrend der Offline-Zeit fertig wurden.
function FleetService:SpielerVorbereiten(spieler: Player)
	local nachgeholt = self:PruefeFertigeBauten(spieler)
	if nachgeholt > 0 then
		log(spieler.Name, "bekommt", nachgeholt, "offline fertiggestellte Schiffe")
	end

	self.FlotteGeaendert:Feuern(spieler)
	self:Senden(spieler)
end

return FleetService
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "HangarService",
		Klasse = "ModuleScript",
		Quelle = [==[
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
			CFrame = CFrame.new(PlotService:ZuWelt(plot, Config.PlotPunkte.Orbit)),
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
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "ImperiumService",
		Klasse = "ModuleScript",
		Quelle = [==[
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
	local basisPos = PlotService:ZuWelt(plot, position)

	local model = Instance.new("Model")
	model.Name = "Geschuetz" .. nummer

	local sockel = Util.NeuerPart({
		Name = "Sockel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 8, 8),
		Color = Color3.fromRGB(50, 56, 76),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
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
		CFrame = CFrame.new(basisPos + Vector3.new(0, 4.8, 0)),
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
		CFrame = CFrame.new(basisPos + Vector3.new(0, 5.6, -3.5)) * CFrame.Angles(math.rad(-25), 0, 0),
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
		CFrame = CFrame.new(basisPos + Vector3.new(0, 7.4, -7.3)),
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
						local drehung = CFrame.new(turm.Position) * CFrame.Angles(0, winkel, 0)

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
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "MonetizationService",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	MonetizationService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > MonetizationService

	AUFGABE
	Gamepasses pruefen und Entwicklerprodukte abwickeln.

	SOLANGE DU NOCH KEINE IDS HAST:
	In TechConfig stehen alle Ids auf 0. Dieser Service ueberspringt
	dann einfach alles — das Spiel laeuft ganz normal, im Shop steht
	"noch nicht verfügbar". Du kannst also in Ruhe erst fertig bauen
	und die Monetarisierung spaeter nachziehen.

	WARUM ProcessReceipt SO WICHTIG IST:
	Roblox ruft diese Funktion auf, wenn jemand ein Produkt kauft.
	Gibt sie NICHT PurchaseGranted zurueck, versucht Roblox es spaeter
	erneut — der Spieler bekommt seine Ware also auch dann, wenn der
	Server mitten im Kauf abstuerzt. Genau darum darf man hier NIE
	einfach "true" zurueckgeben, ohne die Ware wirklich gutzuschreiben.
	================================================================
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local DropperService = require(script.Parent.DropperService)
local FleetService = require(script.Parent.FleetService)

local MonetizationService = {}

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[MonetizationService]", ...)
	end
end

-- ================================================================
-- GAMEPASSES
-- ================================================================

-- Fragt alle Gamepasses ab und schreibt das Ergebnis in den Spielstand.
-- Der Cache im Spielstand sorgt dafuer, dass andere Services nicht bei
-- jeder Geldberechnung eine Web-Anfrage ausloesen.
function MonetizationService:GamepassesPruefen(spieler: Player)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	daten.Gamepasses = daten.Gamepasses or {}

	for _, pass in TechConfig.Gamepasses do
		if pass.Id ~= 0 then
			-- pcall, weil die Abfrage uebers Internet geht und
			-- fehlschlagen kann. Ein Fehler darf den Beitritt nicht stoppen.
			local erfolg, besitzt = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(spieler.UserId, pass.Id)
			end)

			if erfolg then
				daten.Gamepasses[pass.Schluessel] = besitzt or nil
			end
		end
	end

	CurrencyService:MarkiereAenderung(spieler)
end

-- ================================================================
-- ENTWICKLERPRODUKTE
-- ================================================================

-- Schreibt die gekaufte Ware gut. Gibt true zurueck, wenn es geklappt hat.
function MonetizationService:ProduktEinloesen(spieler: Player, produkt: any): boolean
	local daten = DataService:Get(spieler)
	if not daten then
		return false
	end

	if produkt.Art == "Credits" then
		-- Der Wert richtet sich nach der eigenen Produktion, hat aber
		-- einen Mindestbetrag — sonst waere ein Paket am Spielanfang wertlos.
		local proSekunde = DropperService:GetEinkommenProSekunde(spieler)
		local betrag = math.max(
			produkt.Mindestbetrag or 0,
			math.floor(proSekunde * produkt.SekundenProduktion)
		)

		CurrencyService:Hinzufuegen(spieler, betrag)
		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = "+" .. Util.FormatGeld(betrag) .. " " .. Config.Spiel.Waehrung,
			Farbe = "Gold",
		})
		return true
	end

	if produkt.Art == "SkipBau" then
		local anzahl = #daten.Bauauftraege
		if anzahl == 0 then
			-- Nichts in der Warteschlange: Kauf trotzdem als erledigt
			-- markieren, sonst wuerde Roblox es endlos wiederholen.
			Net:Event("Benachrichtigung"):FireClient(spieler, {
				Text = "Die Werft war leer — nichts zu beschleunigen.",
				Farbe = "Warnung",
			})
			return true
		end

		-- Alle Auftraege sofort faellig stellen
		for _, auftrag in daten.Bauauftraege do
			auftrag.FertigUm = os.time() - 1
		end
		FleetService:PruefeFertigeBauten(spieler)

		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = anzahl .. " Schiff(e) sofort fertiggestellt",
			Farbe = "Gold",
		})
		return true
	end

	return false
end

-- ================================================================
-- SHOP-INFO FUER DEN CLIENT
-- ================================================================
function MonetizationService:GetShopInfo(spieler: Player): { any }
	local daten = DataService:Get(spieler)
	local liste = {}

	for _, pass in TechConfig.Gamepasses do
		table.insert(liste, {
			Art = "Gamepass",
			Schluessel = pass.Schluessel,
			Id = pass.Id,
			Name = pass.Name,
			Beschreibung = pass.Beschreibung,
			Verfuegbar = pass.Id ~= 0,
			Besitzt = (daten and daten.Gamepasses and daten.Gamepasses[pass.Schluessel]) == true,
		})
	end

	for _, produkt in TechConfig.Produkte do
		table.insert(liste, {
			Art = "Produkt",
			Schluessel = produkt.Schluessel,
			Id = produkt.Id,
			Name = produkt.Name,
			Beschreibung = produkt.Beschreibung,
			Verfuegbar = produkt.Id ~= 0,
			Besitzt = false,
		})
	end

	return liste
end

-- ================================================================
-- INIT
-- ================================================================
function MonetizationService:Init()
	-- Roblox ruft das auf, wenn ein Entwicklerprodukt gekauft wurde.
	MarketplaceService.ProcessReceipt = function(info)
		local spieler = Players:GetPlayerByUserId(info.PlayerId)
		if not spieler then
			-- Spieler ist weg. NICHT als erledigt melden — Roblox
			-- versucht es erneut, sobald er wieder da ist.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local produkt = TechConfig.ProduktNachId[info.ProductId]
		if not produkt then
			warn("[MonetizationService] Unbekanntes Produkt: " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- pcall, damit ein Fehler beim Gutschreiben nicht dazu fuehrt,
		-- dass Roblox den Kauf faelschlich als erledigt verbucht.
		local erfolg, eingeloest = pcall(function()
			return self:ProduktEinloesen(spieler, produkt)
		end)

		if not erfolg or not eingeloest then
			warn("[MonetizationService] Einloesen fehlgeschlagen: " .. tostring(eingeloest))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Sofort speichern: Wenn der Server jetzt abstuerzt, ist die
		-- gekaufte Ware trotzdem sicher im DataStore.
		DataService:Speichern(spieler)

		log(spieler.Name, "hat gekauft:", produkt.Schluessel)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Gamepass direkt im Spiel gekauft: sofort freischalten,
	-- ohne dass der Spieler neu beitreten muss.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(spieler, passId, gekauft)
		if not gekauft then
			return
		end

		local pass = TechConfig.GamepassNachId[passId]
		local daten = DataService:Get(spieler)
		if not pass or not daten then
			return
		end

		daten.Gamepasses = daten.Gamepasses or {}
		daten.Gamepasses[pass.Schluessel] = true
		CurrencyService:MarkiereAenderung(spieler)
		FleetService:Senden(spieler)

		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = pass.Name .. " freigeschaltet!",
			Farbe = "Gold",
		})
		log(spieler.Name, "besitzt jetzt", pass.Schluessel)
	end)

	log("bereit")
end

-- Wird von Main beim Beitritt aufgerufen.
function MonetizationService:SpielerVorbereiten(spieler: Player)
	-- In einem eigenen Thread: Die Abfrage geht uebers Internet und
	-- darf den Beitritt nicht verzoegern.
	task.spawn(function()
		self:GamepassesPruefen(spieler)
	end)
end

return MonetizationService
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "PlanetService",
		Klasse = "ModuleScript",
		Quelle = [==[
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
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "PlotService",
		Klasse = "ModuleScript",
		Quelle = [==[
--[[
	PlotService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > PlotService

	AUFGABE
	1. Baut beim Serverstart alle Plot-Plattformen per Code auf
	2. Weist jedem beitretenden Spieler automatisch einen freien Plot zu
	3. Baut gekaufte Objekte (Dropper, Upgrades, Lager) auf dem Plot auf
	4. Gibt den Plot beim Verlassen wieder frei

	WARUM PER CODE STATT IM STUDIO BAUEN?
	- Du musst nichts von Hand duplizieren und ausrichten
	- Aenderungen an der Config wirken sofort
	- Der Aufbau ist immer identisch -> keine vergessenen Parts

	Wenn du spaeter eigene Modelle bauen willst: lege sie in
	ServerStorage > Vorlagen und ersetze die "Baue..."-Funktionen
	durch :Clone(). Die restliche Logik bleibt gleich.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Signal = require(ReplicatedStorage:WaitForChild("Signal"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local PlotService = {}

-- Laufzeit-Zustand aller Plots. Index = Plot-Nummer.
PlotService.Plots = {} :: { any }

-- [Player] = Plot-Tabelle
local spielerPlot: { [Player]: any } = {}

-- Signale: werden gefeuert, sobald ein Spieler einen Plot bekommt bzw.
-- verliert. Andere Services (z. B. ButtonService) haengen sich hier an,
-- statt dass PlotService sie kennen muss -> keine zirkulaeren require()-Ketten.
PlotService.Zugewiesen = Signal.neu()
PlotService.Freigegeben = Signal.neu()
PlotService.ObjektGebaut = Signal.neu()

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[PlotService]", ...)
	end
end

-- Schneller Zugriff auf einen Kaufbares-Eintrag ueber seine Id
local kaufbaresNachId: { [string]: any } = {}
for _, eintrag in Config.Kaufbares do
	kaufbaresNachId[eintrag.Id] = eintrag
end
PlotService.KaufbaresNachId = kaufbaresNachId

-- ================================================================
-- GEOMETRIE-HELFER
-- ================================================================

-- Rechnet eine lokale Plot-Koordinate in eine Weltkoordinate um.
function PlotService:ZuWelt(plot: any, lokal: Vector3): Vector3
	return plot.Ursprung:PointToWorldSpace(lokal)
end

local function rasterPosition(index: number): Vector3
	local proReihe = Config.Plot.ProReihe
	local reihen = math.ceil(Config.Plot.Anzahl / proReihe)

	local spalte = (index - 1) % proReihe
	local reihe = (index - 1) // proReihe

	local x = (spalte - (proReihe - 1) / 2) * Config.Plot.Abstand
	local z = (reihe - (reihen - 1) / 2) * Config.Plot.Abstand

	return Vector3.new(x, Config.Plot.Hoehe, z)
end

-- ================================================================
-- PLOT AUFBAUEN
-- ================================================================
local function baueRahmen(plot: any)
	local groesse = Config.Plot.Groesse
	local halbeBreite = groesse.X / 2
	local halbeTiefe = groesse.Z / 2

	-- Boden. Die Oberflaeche liegt genau auf Config.Plot.Hoehe.
	local boden = Util.NeuerPart({
		Name = "Basis",
		Size = groesse,
		Color = Config.Plot.BodenFarbe,
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(plot.Zentrum - Vector3.new(0, groesse.Y / 2, 0)),
	})
	boden.Parent = plot.Model
	plot.Model.PrimaryPart = boden

	-- Vier Neon-Kanten als Weltraum-Akzent
	local kanten = {
		{ Size = Vector3.new(groesse.X, 0.6, 2), Offset = Vector3.new(0, 0.3, halbeTiefe) },
		{ Size = Vector3.new(groesse.X, 0.6, 2), Offset = Vector3.new(0, 0.3, -halbeTiefe) },
		{ Size = Vector3.new(2, 0.6, groesse.Z), Offset = Vector3.new(halbeBreite, 0.3, 0) },
		{ Size = Vector3.new(2, 0.6, groesse.Z), Offset = Vector3.new(-halbeBreite, 0.3, 0) },
	}

	for i, kante in kanten do
		local part = Util.NeuerPart({
			Name = "Kante" .. i,
			Size = kante.Size,
			Color = Config.Plot.RandFarbe,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(plot.Zentrum + kante.Offset),
		})
		part.Parent = plot.Model
	end
end

local function baueSchild(plot: any)
	local saeule = Util.NeuerPart({
		Name = "Schildsaeule",
		Size = Vector3.new(3, 14, 3),
		Color = Color3.fromRGB(60, 65, 85),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(PlotService:ZuWelt(plot, Vector3.new(0, 7, 56))),
	})
	saeule.Parent = plot.Model

	local tafel = Instance.new("BillboardGui")
	tafel.Name = "Besitzer"
	tafel.Size = UDim2.fromScale(16, 4)
	tafel.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	tafel.AlwaysOnTop = false
	tafel.MaxDistance = 300
	tafel.Parent = saeule

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Config.Plot.FreiFarbe
	text.TextStrokeTransparency = 0.4
	text.Text = "FREIE STATION"
	text.Parent = tafel

	plot.SchildText = text
end

local function baueSammelkern(plot: any)
	local kernOrdner = Instance.new("Model")
	kernOrdner.Name = "Sammelkern"
	kernOrdner.Parent = plot.Model

	local basisPos = PlotService:ZuWelt(plot, Config.PlotPunkte.Sammelkern)

	local pad = Util.NeuerPart({
		Name = "Pad",
		Size = Vector3.new(26, 1, 26),
		Color = Color3.fromRGB(28, 32, 48),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 0.5, 0)),
	})
	pad.Parent = kernOrdner

	local ring = Util.NeuerPart({
		Name = "Ring",
		Size = Vector3.new(20, 0.4, 20),
		Color = Config.Plot.RandFarbe,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 1.2, 0)),
	})
	ring.Parent = kernOrdner

	-- Der schwebende Kristall, auf den die Lieferungen zufliegen
	local kern = Util.NeuerPart({
		Name = "Kern",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		Color = Color3.fromRGB(120, 230, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 8, 0)),
	})
	kern.Parent = kernOrdner

	local licht = Instance.new("PointLight")
	licht.Brightness = 3
	licht.Range = 26
	licht.Color = Color3.fromRGB(120, 230, 255)
	licht.Parent = kern

	local anzeige = Instance.new("BillboardGui")
	anzeige.Name = "LagerAnzeige"
	anzeige.Size = UDim2.fromScale(14, 3.5)
	anzeige.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	anzeige.MaxDistance = 250
	anzeige.Parent = kern

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(180, 245, 255)
	text.TextStrokeTransparency = 0.3
	text.Text = "LAGER"
	text.Parent = anzeige

	plot.Kern = kern
	plot.KernPad = pad
	plot.LagerText = text

	-- Beruehren = Lager einsammeln (der Klassiker im Tycoon-Genre)
	pad.Touched:Connect(function(getroffen)
		local charakter = getroffen:FindFirstAncestorOfClass("Model")
		if not charakter then
			return
		end
		local spieler = Players:GetPlayerFromCharacter(charakter)
		if not spieler or spielerPlot[spieler] ~= plot then
			return
		end
		PlotService:LagerEinsammeln(spieler)
	end)
end

-- Die Werft: Gebaeude, an dem der Spieler die Flotten-GUI oeffnet.
-- Sie ist nicht kaufbar, sondern von Anfang an da — sonst haette der
-- Spieler keinen Zugang zum Flotten-System.
local function baueWerft(plot: any)
	local basisPos = PlotService:ZuWelt(plot, Config.PlotPunkte.Werft)

	local model = Instance.new("Model")
	model.Name = "Werft"
	model.Parent = plot.Model

	local plattform = Util.NeuerPart({
		Name = "Plattform",
		Size = Vector3.new(18, 2, 18),
		Color = Color3.fromRGB(44, 50, 70),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 1, 0)),
	})
	plattform.Parent = model

	-- Zwei Streben mit einem Neon-Bogen dazwischen
	for _, seite in { -1, 1 } do
		local strebe = Util.NeuerPart({
			Name = "Strebe",
			Size = Vector3.new(1.6, 16, 1.6),
			Color = Color3.fromRGB(62, 70, 94),
			Material = Enum.Material.Metal,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(basisPos + Vector3.new(seite * 7, 10, 0)),
		})
		strebe.Parent = model
	end

	local bogen = Util.NeuerPart({
		Name = "Bogen",
		Size = Vector3.new(15.6, 1.2, 2.4),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 18, 0)),
	})
	bogen.Parent = model

	-- Die Konsole, an der man die Werft oeffnet
	local konsole = Util.NeuerPart({
		Name = "Konsole",
		Size = Vector3.new(5, 4, 2.4),
		Color = Color3.fromRGB(30, 36, 52),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 4, 6))
			* CFrame.Angles(math.rad(-18), 0, 0),
	})
	konsole.Parent = model

	-- ProximityPrompt = die Taste, die eingeblendet wird, wenn man nah dran
	-- steht (auf dem Handy ein antippbarer Knopf). Das Oeffnen der GUI
	-- passiert komplett auf dem Client — dafuer braucht es kein RemoteEvent.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WerftPrompt"
	prompt.ActionText = "Werft öffnen"
	prompt.ObjectText = "Raumwerft"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = konsole

	-- Ein "Tag" ist eine Markierung, nach der man spaeter suchen kann.
	-- Der Client holt sich damit alle Werft-Konsolen, ohne den Explorer
	-- durchsuchen zu muessen.
	CollectionService:AddTag(prompt, "WerftPrompt")

	local schild = Instance.new("BillboardGui")
	schild.Name = "Beschriftung"
	schild.Size = UDim2.fromScale(14, 3)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	schild.MaxDistance = 220
	schild.Parent = bogen

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(180, 225, 255)
	text.TextStrokeTransparency = 0.35
	text.Text = "RAUMWERFT"
	text.Parent = schild

	plot.WerftModel = model
end

local function baueSpawnPad(plot: any)
	local pad = Util.NeuerPart({
		Name = "SpawnPad",
		Size = Vector3.new(16, 0.6, 16),
		Color = Color3.fromRGB(70, 255, 160),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(PlotService:ZuWelt(plot, Config.PlotPunkte.Spawn) + Vector3.new(0, 0.3, 0)),
	})
	pad.Parent = plot.Model
	plot.SpawnPad = pad
end

function PlotService:PlotErstellen(index: number)
	local zentrum = rasterPosition(index)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local plot = {
		Index = index,
		Model = model,
		Zentrum = zentrum,
		Ursprung = CFrame.new(zentrum),
		Besitzer = nil :: Player?,

		-- Laufzeitwerte, werden von NeuBerechnen gesetzt
		Dropper = {},        -- Liste aktiver Dropper
		WertMult = 1,
		TempoMult = 1,
	}

	baueRahmen(plot)
	baueSchild(plot)
	baueSammelkern(plot)
	baueSpawnPad(plot)
	baueWerft(plot)

	local gebaeude = Instance.new("Folder")
	gebaeude.Name = "Gebaeude"
	gebaeude.Parent = model
	plot.GebaeudeOrdner = gebaeude

	local buttons = Instance.new("Folder")
	buttons.Name = "Buttons"
	buttons.Parent = model
	plot.ButtonOrdner = buttons

	local drops = Instance.new("Folder")
	drops.Name = "Lieferungen"
	drops.Parent = model
	plot.DropOrdner = drops

	model.Parent = self.PlotOrdner
	self.Plots[index] = plot
	return plot
end

-- ================================================================
-- OBJEKTE AUF DEM PLOT BAUEN
-- ================================================================
local function baueDropper(plot: any, eintrag: any)
	local typ = Config.DropperTypen[eintrag.DropperTyp]
	local basisPos = PlotService:ZuWelt(plot, eintrag.Position)

	local model = Instance.new("Model")
	model.Name = eintrag.Id
	model.Parent = plot.GebaeudeOrdner

	local sockel = Util.NeuerPart({
		Name = "Sockel",
		Size = Vector3.new(10, 6, 10),
		Color = Color3.fromRGB(52, 58, 78),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 3, 0)),
	})
	sockel.Parent = model

	local turm = Util.NeuerPart({
		Name = "Turm",
		Size = Vector3.new(5, 8, 5),
		Color = Color3.fromRGB(70, 78, 102),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 10, 0)),
	})
	turm.Parent = model

	local duese = Util.NeuerPart({
		Name = "Duese",
		Size = Vector3.new(6.5, 1.6, 6.5),
		Color = typ.Farbe,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 14.5, 0)),
	})
	duese.Parent = model

	local schild = Instance.new("BillboardGui")
	schild.Size = UDim2.fromScale(10, 2.2)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	schild.MaxDistance = 160
	schild.Parent = duese

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = typ.Farbe
	text.TextStrokeTransparency = 0.4
	text.Text = typ.Name
	text.Parent = schild

	-- Laufzeit-Eintrag fuer den DropperService
	table.insert(plot.Dropper, {
		Id = eintrag.Id,
		Typ = eintrag.DropperTyp,
		Duese = duese,
		-- Leicht versetzter Start, damit nicht alle Dropper gleichzeitig feuern
		NaechsterDrop = os.clock() + math.random() * typ.Intervall,
	})

	return model
end

local function baueModul(plot: any, eintrag: any, farbe: Color3, beschriftung: string)
	local basisPos = PlotService:ZuWelt(plot, eintrag.Position)

	local model = Instance.new("Model")
	model.Name = eintrag.Id
	model.Parent = plot.GebaeudeOrdner

	local sockel = Util.NeuerPart({
		Name = "Sockel",
		Size = Vector3.new(11, 5, 11),
		Color = Color3.fromRGB(48, 54, 74),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 2.5, 0)),
	})
	sockel.Parent = model

	local kristall = Util.NeuerPart({
		Name = "Kristall",
		Size = Vector3.new(5, 7, 5),
		Color = farbe,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 8.5, 0)) * CFrame.Angles(0, math.rad(45), 0),
	})
	kristall.Parent = model

	local schild = Instance.new("BillboardGui")
	schild.Size = UDim2.fromScale(11, 2.2)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	schild.MaxDistance = 160
	schild.Parent = kristall

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = farbe
	text.TextStrokeTransparency = 0.4
	text.Text = beschriftung
	text.Parent = schild

	return model
end

-- Baut EIN gekauftes Objekt. Wird beim Kauf und beim Laden des
-- Spielstands aufgerufen.
function PlotService:BaueObjekt(plot: any, eintrag: any)
	-- Doppelt bauen verhindern (z. B. bei doppeltem Touch-Event)
	if plot.GebaeudeOrdner:FindFirstChild(eintrag.Id) then
		return
	end

	if eintrag.Typ == "Dropper" then
		baueDropper(plot, eintrag)
	elseif eintrag.Typ == "Upgrade" then
		local istTempo = eintrag.Wirkung.TempoMultiplikator ~= nil
		baueModul(
			plot,
			eintrag,
			istTempo and Color3.fromRGB(120, 255, 180) or Color3.fromRGB(255, 200, 90),
			istTempo and "TEMPO" or "WERT"
		)
	elseif eintrag.Typ == "Lager" then
		baueModul(plot, eintrag, Color3.fromRGB(150, 180, 255), "LAGER")
	end

	self.ObjektGebaut:Feuern(plot, eintrag)
end

-- Rechnet die Plot-Multiplikatoren aus allen gekauften Upgrades neu aus.
-- Immer aufrufen, wenn sich "Gekauft" aendert.
function PlotService:NeuBerechnen(plot: any)
	local spieler = plot.Besitzer
	if not spieler then
		plot.WertMult, plot.TempoMult = 1, 1
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	local wert, tempo = 1, 1
	for _, eintrag in Config.Kaufbares do
		if daten.Gekauft[eintrag.Id] and eintrag.Wirkung then
			if eintrag.Wirkung.WertMultiplikator then
				wert *= eintrag.Wirkung.WertMultiplikator
			end
			if eintrag.Wirkung.TempoMultiplikator then
				tempo *= eintrag.Wirkung.TempoMultiplikator
			end
		end
	end

	plot.WertMult = wert
	plot.TempoMult = tempo
end

-- ================================================================
-- ZUWEISUNG / FREIGABE
-- ================================================================
function PlotService:GetPlot(spieler: Player)
	return spielerPlot[spieler]
end

function PlotService:LagerEinsammeln(spieler: Player): number
	local betrag = CurrencyService:LagerEinsammeln(spieler)
	return betrag
end

local function plotLeeren(plot: any)
	plot.GebaeudeOrdner:ClearAllChildren()
	plot.ButtonOrdner:ClearAllChildren()
	plot.DropOrdner:ClearAllChildren()
	table.clear(plot.Dropper)
	plot.WertMult = 1
	plot.TempoMult = 1
end

function PlotService:Zuweisen(spieler: Player): any?
	if spielerPlot[spieler] then
		return spielerPlot[spieler]
	end

	for _, plot in self.Plots do
		if not plot.Besitzer then
			plot.Besitzer = spieler
			spielerPlot[spieler] = plot

			plot.SchildText.Text = string.upper(spieler.DisplayName) .. "\nSTATION " .. plot.Index
			plot.SchildText.TextColor3 = Config.Plot.RandFarbe

			-- Bereits gekaufte Objekte aus dem Spielstand wieder aufbauen
			local daten = DataService:Get(spieler)
			if daten then
				for _, eintrag in Config.Kaufbares do
					if daten.Gekauft[eintrag.Id] then
						self:BaueObjekt(plot, eintrag)
					end
				end
			end

			self:NeuBerechnen(plot)
			self.Zugewiesen:FeuernSofort(spieler, plot)
			log(spieler.Name .. " -> Plot " .. plot.Index)
			return plot
		end
	end

	warn("[PlotService] Kein freier Plot fuer " .. spieler.Name .. " (Config.Plot.Anzahl erhoehen?)")
	return nil
end

function PlotService:Freigeben(spieler: Player)
	local plot = spielerPlot[spieler]
	if not plot then
		return
	end

	self.Freigegeben:FeuernSofort(spieler, plot)

	plotLeeren(plot)
	plot.Besitzer = nil
	plot.SchildText.Text = "FREIE STATION"
	plot.SchildText.TextColor3 = Config.Plot.FreiFarbe
	plot.LagerText.Text = "LAGER"
	spielerPlot[spieler] = nil

	log("Plot " .. plot.Index .. " freigegeben")
end

-- Baut den Plot komplett neu aus dem Spielstand auf.
-- Wird beim Rebirth gebraucht: erst wird der Spielstand zurueckgesetzt,
-- dann raeumt diese Funktion die Station leer und stellt sie wieder her.
-- Das Zugewiesen-Signal am Ende laesst ButtonService, HangarService und
-- ImperiumService ihre Teile ebenfalls neu aufbauen.
function PlotService:NeuAufbauen(spieler: Player)
	local plot = spielerPlot[spieler]
	if not plot then
		return
	end

	plotLeeren(plot)

	local daten = DataService:Get(spieler)
	if daten then
		for _, eintrag in Config.Kaufbares do
			if daten.Gekauft[eintrag.Id] then
				self:BaueObjekt(plot, eintrag)
			end
		end
	end

	self:NeuBerechnen(plot)
	self.Zugewiesen:FeuernSofort(spieler, plot)
end

-- Setzt den Spieler auf sein Spawn-Pad.
function PlotService:ZumPlotTeleportieren(spieler: Player)
	local plot = spielerPlot[spieler]
	local charakter = spieler.Character
	if not plot or not charakter then
		return
	end

	local wurzel = charakter:FindFirstChild("HumanoidRootPart")
	if not wurzel then
		return
	end

	local ziel = self:ZuWelt(plot, Config.PlotPunkte.Spawn) + Vector3.new(0, 5, 0)
	charakter:PivotTo(CFrame.new(ziel, ziel + Vector3.new(0, 0, -1)))
end

-- ================================================================
-- INIT
-- ================================================================
-- Der "Sammeln"-Knopf in der GUI. Auch hier gilt: Der Client sagt nur
-- "ich moechte sammeln", der Server entscheidet.
function PlotService:SammelAnfrageBehandeln(spieler: Player)
	local plot = spielerPlot[spieler]
	if not plot then
		return
	end

	local charakter = spieler.Character
	if not charakter then
		return
	end

	local wurzel = charakter:FindFirstChild("HumanoidRootPart")
	if not wurzel or not wurzel:IsA("BasePart") then
		return
	end

	-- Abstandspruefung: Der Spieler muss wirklich in der Naehe seines
	-- Sammelkerns stehen. Sonst koennte man von ueberall aus abkassieren.
	local kernPos = self:ZuWelt(plot, Config.PlotPunkte.Sammelkern)
	if (wurzel.Position - kernPos).Magnitude > Config.Lager.SammelReichweite then
		return
	end

	self:LagerEinsammeln(spieler)
end

function PlotService:Init(welt: Folder)
	local ordner = Instance.new("Folder")
	ordner.Name = "Plots"
	ordner.Parent = welt
	self.PlotOrdner = ordner

	for i = 1, Config.Plot.Anzahl do
		self:PlotErstellen(i)
	end
	log(Config.Plot.Anzahl .. " Plots gebaut")

	Net:Event("SammelAnfrage").OnServerEvent:Connect(function(spieler)
		self:SammelAnfrageBehandeln(spieler)
	end)

	-- Schwebender, drehender Sammelkern + Lageranzeige.
	-- Eine einzige Schleife fuer alle Plots ist viel guenstiger als
	-- eine Schleife pro Plot.
	task.spawn(function()
		local letzteTextaktualisierung = 0

		while true do
			local jetzt = os.clock()
			local textUpdate = (jetzt - letzteTextaktualisierung) >= 0.25
			if textUpdate then
				letzteTextaktualisierung = jetzt
			end

			for _, plot in self.Plots do
				local basis = self:ZuWelt(plot, Config.PlotPunkte.Sammelkern)
				plot.Kern.CFrame = CFrame.new(basis + Vector3.new(0, 8 + math.sin(jetzt * 1.5) * 0.8, 0))
					* CFrame.Angles(0, jetzt * 0.8, 0)

				if textUpdate and plot.Besitzer then
					local daten = DataService:Get(plot.Besitzer)
					if daten then
						local kapazitaet = CurrencyService:GetLagerKapazitaet(plot.Besitzer)
						local voll = daten.Lager >= kapazitaet
						plot.LagerText.Text = string.format(
							"%s / %s%s",
							Util.FormatGeld(daten.Lager),
							Util.FormatGeld(kapazitaet),
							voll and "  (VOLL!)" or ""
						)
						plot.LagerText.TextColor3 = voll
							and Color3.fromRGB(255, 120, 120)
							or Color3.fromRGB(180, 245, 255)
					end
				end
			end

			RunService.Heartbeat:Wait()
		end
	end)

	log("bereit")
end

return PlotService
]==],
	},
	{
		Ziel = "ServerScriptService/Services",
		Name = "WorldBuilder",
		Klasse = "ModuleScript",
		Quelle = [==[
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
]==],
	},
	{
		Ziel = "StarterPlayerScripts",
		Name = "FleetGui",
		Klasse = "LocalScript",
		Quelle = [==[
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
]==],
	},
	{
		Ziel = "StarterPlayerScripts",
		Name = "HudClient",
		Klasse = "LocalScript",
		Quelle = [==[
--[[
	HudClient  —  LocalScript
	================================================================
	EXPLORER-ORT:  StarterPlayer > StarterPlayerScripts > HudClient

	WARUM DORT UND NICHT IN StarterGui?
	StarterPlayerScripts-Scripts laufen genau EINMAL pro Spieler und
	ueberleben den Tod der Spielfigur. Ein LocalScript in StarterGui
	wuerde bei jedem Respawn neu starten — und damit die GUI neu
	aufbauen. Wir erzeugen die ScreenGui hier per Code und haengen sie
	in die PlayerGui. Ergebnis: Du musst im Explorer nichts von Hand
	zusammenklicken, und die Anzeige flackert beim Respawn nicht.

	DIESES SCRIPT BAUT AUSSERDEM DIE AKTIONSLEISTE (links am Rand).
	Andere Client-Scripts (Werft, spaeter Planeten) haengen sich dort
	mit einer Zeile einen Knopf hinein — sie muessen dieses Script
	nicht kennen und nicht aendern.

	WICHTIG (Exploit-Schutz):
	Dieses Script zeigt nur an, was der Server schickt. Es RECHNET
	nichts aus. Wenn ein Exploiter hier Zahlen aendert, sieht nur er
	selbst eine falsche Zahl — sein echtes Guthaben auf dem Server
	bleibt unveraendert.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local UiKit = require(ReplicatedStorage:WaitForChild("UiKit"))

local spieler = Players.LocalPlayer
local spielerGui = spieler:WaitForChild("PlayerGui")
local Farben = UiKit.Farben

-- ================================================================
-- GRUNDGERUEST
-- ================================================================
local hud = UiKit.Neu("ScreenGui", {
	Name = "HUD",
	ResetOnSpawn = false,          -- ueberlebt den Respawn
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, spielerGui)

UiKit.ErstelleAktionsleiste(hud)

-- ================================================================
-- WAEHRUNGSPANEL (oben rechts)
-- ================================================================
local panel = UiKit.Neu("Frame", {
	Name = "Waehrungspanel",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.new(0, 246, 0, 164),
	BackgroundColor3 = Farben.Panel,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
}, hud)
UiKit.Ecken(panel, 12)
local panelRand = UiKit.Rand(panel, Farben.PanelRand, 1.5, 0.55)
UiKit.Neu("UIPadding", {
	PaddingTop = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12),
}, panel)

UiKit.Text({
	Name = "Ueberschrift",
	Size = UDim2.new(1, 0, 0, 14),
	TextSize = 11,
	TextColor3 = Farben.TextGedimmt,
	Text = "GUTHABEN",
}, panel)

local geldLabel = UiKit.Text({
	Name = "Geld",
	Position = UDim2.new(0, 0, 0, 16),
	Size = UDim2.new(1, 0, 0, 34),
	Font = Enum.Font.GothamBlack,
	TextSize = 28,
	Text = "0 " .. Config.Spiel.Waehrung,
}, panel)

local multLabel = UiKit.Text({
	Name = "Multiplikator",
	Position = UDim2.new(0, 0, 0, 51),
	Size = UDim2.new(1, 0, 0, 16),
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = Farben.Gold,
	Text = "x1.00 Einkommen",
}, panel)

local lagerTitel = UiKit.Text({
	Name = "LagerTitel",
	Position = UDim2.new(0, 0, 0, 72),
	Size = UDim2.new(1, 0, 0, 14),
	TextSize = 11,
	TextColor3 = Farben.TextGedimmt,
	Text = "LAGER  0 / 0",
}, panel)

local balkenHuelle = UiKit.Neu("Frame", {
	Name = "LagerBalken",
	Position = UDim2.new(0, 0, 0, 89),
	Size = UDim2.new(1, 0, 0, 10),
	BackgroundColor3 = Color3.fromRGB(35, 40, 58),
	BorderSizePixel = 0,
}, panel)
UiKit.Ecken(balkenHuelle, 5)

local balkenFuellung = UiKit.Neu("Frame", {
	Name = "Fuellung",
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Farben.Akzent,
	BorderSizePixel = 0,
}, balkenHuelle)
UiKit.Ecken(balkenFuellung, 5)

local sammelKnopf = UiKit.Knopf({
	Name = "Sammeln",
	Position = UDim2.new(0, 0, 0, 106),
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundColor3 = Farben.Gut,
	TextSize = 15,
	TextColor3 = Color3.fromRGB(8, 20, 14),
	Text = "SAMMELN",
}, panel)

-- ================================================================
-- BENACHRICHTIGUNGEN (Toasts)
-- ================================================================
local toastBereich = UiKit.Neu("Frame", {
	Name = "Toasts",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.new(0, 340, 0, 170),
	BackgroundTransparency = 1,
}, hud)

UiKit.Neu("UIListLayout", {
	FillDirection = Enum.FillDirection.Vertical,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
}, toastBereich)

local function zeigeToast(text: string, farbe: Color3)
	local karte = UiKit.Text({
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Farben.Panel,
		BackgroundTransparency = 0.1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = farbe,
		Text = text,
	}, toastBereich)
	UiKit.Ecken(karte, 8)
	UiKit.Rand(karte, farbe, 1, 0.5)

	task.delay(2.6, function()
		local weg = TweenService:Create(karte, TweenInfo.new(0.35), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		weg.Completed:Connect(function()
			karte:Destroy()
		end)
		weg:Play()
	end)
end

-- ================================================================
-- DATEN VOM SERVER
-- ================================================================
local zustand = {
	Geld = 0,
	Lager = 0,
	LagerKapazitaet = Config.Lager.Startkapazitaet,
	Multiplikator = 1,
	Rebirths = 0,
}

-- Angezeigte Werte laufen weich zum Zielwert hoch (fuehlt sich besser an)
local angezeigtesGeld = 0
local angezeigtesLager = 0

Net:Event("DatenUpdate").OnClientEvent:Connect(function(daten)
	for schluessel, wert in daten do
		zustand[schluessel] = wert
	end
end)

Net:Event("Benachrichtigung").OnClientEvent:Connect(function(info)
	zeigeToast(info.Text, UiKit.FarbeAusName(info.Farbe))
end)

Net:Event("KaufBestaetigt").OnClientEvent:Connect(function(info)
	zeigeToast("Gekauft: " .. info.Name, Farben.Gut)

	-- Kleiner Puls auf dem Panel als Feedback
	panelRand.Transparency = 0
	TweenService:Create(panelRand, TweenInfo.new(0.6), { Transparency = 0.55 }):Play()
end)

sammelKnopf.Activated:Connect(function()
	-- Der Client bittet nur. Der Server prueft Abstand und Betrag.
	Net:Event("SammelAnfrage"):FireServer()
end)

-- ================================================================
-- ANZEIGE AKTUALISIEREN
-- ================================================================
RunService.RenderStepped:Connect(function(deltaZeit)
	-- Weiches Hochzaehlen: 12 = Geschwindigkeit, hoeher = schneller
	local faktor = math.min(1, deltaZeit * 12)
	angezeigtesGeld += (zustand.Geld - angezeigtesGeld) * faktor
	angezeigtesLager += (zustand.Lager - angezeigtesLager) * faktor

	-- Bei sehr kleinen Restdifferenzen direkt einrasten
	if math.abs(zustand.Geld - angezeigtesGeld) < 1 then
		angezeigtesGeld = zustand.Geld
	end
	if math.abs(zustand.Lager - angezeigtesLager) < 1 then
		angezeigtesLager = zustand.Lager
	end

	geldLabel.Text = Util.FormatGeld(angezeigtesGeld) .. " " .. Config.Spiel.Waehrung

	local multText = string.format("x%.2f Einkommen", zustand.Multiplikator)
	if zustand.Rebirths > 0 then
		multText ..= string.format("   •   %d Rebirth(s)", zustand.Rebirths)
	end
	multLabel.Text = multText

	local kapazitaet = math.max(1, zustand.LagerKapazitaet)
	local anteil = math.clamp(angezeigtesLager / kapazitaet, 0, 1)

	lagerTitel.Text = string.format(
		"LAGER  %s / %s",
		Util.FormatGeld(angezeigtesLager),
		Util.FormatGeld(kapazitaet)
	)
	balkenFuellung.Size = UDim2.new(anteil, 0, 1, 0)
	balkenFuellung.BackgroundColor3 = (anteil >= 0.999) and Farben.Warnung or Farben.Akzent

	local etwasDrin = zustand.Lager > 0
	sammelKnopf.BackgroundColor3 = etwasDrin and Farben.Gut or Farben.Inaktiv
	sammelKnopf.TextColor3 = etwasDrin and Color3.fromRGB(8, 20, 14) or Farben.TextGedimmt
	sammelKnopf.Text = etwasDrin
		and ("SAMMELN  +" .. Util.FormatGeld(zustand.Lager))
		or "LAGER LEER"
end)

-- Frische Daten anfordern (falls der Server schon gesendet hat,
-- bevor dieses Script bereit war).
task.defer(function()
	Net:Event("DatenAnfrage"):FireServer()
end)

print("[HudClient] HUD bereit")
]==],
	},
	{
		Ziel = "StarterPlayerScripts",
		Name = "ImperiumGui",
		Klasse = "LocalScript",
		Quelle = [==[
--[[
	ImperiumGui  —  LocalScript
	================================================================
	EXPLORER-ORT:  StarterPlayer > StarterPlayerScripts > ImperiumGui

	Ein Fenster mit drei Reitern:
	  REBIRTH      — Fortschritt zurücksetzen gegen dauerhaften Bonus
	  TECHNOLOGIE  — der Forschungsbaum
	  SHOP         — Gamepasses und Credit-Pakete

	WARUM DREI REITER STATT DREI FENSTER?
	Drei Fenster hiessen drei Knoepfe in der Aktionsleiste, dreimal
	derselbe Rahmen-Code und dreimal dieselben Server-Daten. Die drei
	Themen gehoeren inhaltlich zusammen ("mein Imperium") — also ein
	Fenster.

	EXPLOIT-SCHUTZ:
	"TechKaufen" schickt nur die Id der Technologie, "RebirthStarten"
	gar nichts. Preise, Stufen und Voraussetzungen prueft der
	ImperiumService. Die Robux-Kaeufe laufen ueber MarketplaceService;
	gutgeschrieben wird erst in ProcessReceipt auf dem Server.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local UiKit = require(ReplicatedStorage:WaitForChild("UiKit"))

local spieler = Players.LocalPlayer
local Farben = UiKit.Farben

-- ================================================================
-- ZUSTAND
-- ================================================================
local stand = {
	Tech = {},
	TechPreise = {},
	Rebirths = 0,
	RebirthSchwelle = TechConfig.RebirthSchwelle(0),
	GesamtVerdient = 0,
	KannRebirth = false,
	BonusProRebirth = 0.25,
	Shop = {},
}

local geld = 0
local rebirthBestaetigungBis = 0   -- Zwei-Klick-Sicherung

local fenster = UiKit.Fenster({
	Name = "ImperiumGui",
	Titel = "IMPERIUM",
	Untertitel = "Rebirth · Technologie · Shop",
	MaxGroesse = Vector2.new(660, 580),
	Ebene = 7,
})

-- ================================================================
-- REITER
-- ================================================================
local reiterLeiste = UiKit.Neu("Frame", {
	Name = "Reiter",
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
}, fenster.Inhalt)

UiKit.Neu("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
}, reiterLeiste)

local seitenBereich = UiKit.Neu("Frame", {
	Name = "Seiten",
	Position = UDim2.new(0, 0, 0, 42),
	Size = UDim2.new(1, 0, 1, -42),
	BackgroundTransparency = 1,
}, fenster.Inhalt)

local reiter: { any } = {}

local function zeigeSeite(name: string)
	for _, eintrag in reiter do
		local aktiv = eintrag.Name == name
		eintrag.Seite.Visible = aktiv
		eintrag.Knopf.BackgroundColor3 = aktiv and Farben.Akzent or Farben.PanelHell
		eintrag.Knopf.TextColor3 = aktiv and Color3.fromRGB(8, 16, 24) or Farben.TextGedimmt
	end
end

local function baueReiter(reihenfolge: number, name: string)
	local knopf = UiKit.Knopf({
		Name = name,
		LayoutOrder = reihenfolge,
		Size = UDim2.new(1 / 3, -4, 1, 0),
		BackgroundColor3 = Farben.PanelHell,
		TextColor3 = Farben.TextGedimmt,
		TextSize = 12,
		Text = name,
	}, reiterLeiste)

	local seite = UiKit.Neu("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, seitenBereich)

	table.insert(reiter, { Name = name, Knopf = knopf, Seite = seite })
	knopf.Activated:Connect(function()
		zeigeSeite(name)
	end)

	return seite
end

local seiteRebirth = baueReiter(1, "REBIRTH")
local seiteTech = baueReiter(2, "TECHNOLOGIE")
local seiteShop = baueReiter(3, "SHOP")

-- ================================================================
-- SEITE 1: REBIRTH
-- ================================================================
local rebirthZahl = UiKit.Text({
	Size = UDim2.new(1, 0, 0, 40),
	Font = Enum.Font.GothamBlack,
	TextSize = 32,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Farben.Gold,
	Text = "REBIRTH 0",
}, seiteRebirth)

local rebirthBonus = UiKit.Text({
	Position = UDim2.new(0, 0, 0, 40),
	Size = UDim2.new(1, 0, 0, 18),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "Aktuell +0 % Einkommen",
}, seiteRebirth)

local fortschrittText = UiKit.Text({
	Position = UDim2.new(0, 0, 0, 68),
	Size = UDim2.new(1, 0, 0, 14),
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Farben.TextGedimmt,
	Text = "Gesamtverdienst 0 / 0",
}, seiteRebirth)

local balkenHuelle = UiKit.Neu("Frame", {
	Position = UDim2.new(0, 0, 0, 86),
	Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = Color3.fromRGB(35, 40, 58),
	BorderSizePixel = 0,
}, seiteRebirth)
UiKit.Ecken(balkenHuelle, 6)

local balkenFuellung = UiKit.Neu("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Farben.Gold,
	BorderSizePixel = 0,
}, balkenHuelle)
UiKit.Ecken(balkenFuellung, 6)

-- Zwei Spalten: was weg ist und was bleibt
local function baueSpalte(x: number, titel: string, farbe: Color3, eintraege: { string })
	local spalte = UiKit.Neu("Frame", {
		Position = UDim2.new(x, x == 0 and 0 or 5, 0, 112),
		Size = UDim2.new(0.5, -5, 0, 132),
		BackgroundColor3 = Farben.PanelHell,
		BorderSizePixel = 0,
	}, seiteRebirth)
	UiKit.Ecken(spalte, 10)
	UiKit.Abstand(spalte, 10)

	UiKit.Text({
		Size = UDim2.new(1, 0, 0, 14),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = farbe,
		Text = titel,
	}, spalte)

	for index, text in eintraege do
		UiKit.Text({
			Position = UDim2.new(0, 0, 0, 20 + index * 18),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 11,
			TextColor3 = Farben.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "· " .. text,
		}, spalte)
	end
end

baueSpalte(0, "WIRD ZURÜCKGESETZT", Farben.Warnung, TechConfig.Rebirth.WirdZurueckgesetzt)
baueSpalte(0.5, "BLEIBT ERHALTEN", Farben.Gut, TechConfig.Rebirth.BleibtErhalten)

local rebirthKnopf = UiKit.Knopf({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = Farben.Inaktiv,
	TextColor3 = Farben.TextGedimmt,
	TextSize = 15,
	Text = "REBIRTH DURCHFÜHREN",
}, seiteRebirth)

-- ================================================================
-- SEITE 2: TECHNOLOGIE
-- ================================================================
local techListe = UiKit.Neu("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = Farben.PanelRand,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, seiteTech)

UiKit.Neu("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, techListe)
UiKit.Neu("UIPadding", { PaddingRight = UDim.new(0, 8) }, techListe)

local techZeilen: { [string]: any } = {}

for _, tech in TechConfig.Technologien do
	local zeile = UiKit.Neu("Frame", {
		Name = tech.Id,
		LayoutOrder = tech.Reihenfolge,
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = Farben.PanelHell,
		BorderSizePixel = 0,
	}, techListe)
	UiKit.Ecken(zeile, 10)

	local streifen = UiKit.Neu("Frame", {
		Size = UDim2.new(0, 4, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = tech.Farbe,
		BorderSizePixel = 0,
	}, zeile)
	UiKit.Ecken(streifen, 2)

	UiKit.Text({
		Position = UDim2.new(0, 20, 0, 8),
		Size = UDim2.new(1, -180, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Text = tech.Name,
	}, zeile)

	UiKit.Text({
		Position = UDim2.new(0, 20, 0, 27),
		Size = UDim2.new(1, -180, 0, 28),
		TextSize = 11,
		TextColor3 = Farben.TextGedimmt,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = tech.Beschreibung,
	}, zeile)

	local stufenLabel = UiKit.Text({
		Position = UDim2.new(0, 20, 0, 58),
		Size = UDim2.new(1, -180, 0, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = tech.Farbe,
		Text = "",
	}, zeile)

	local preisLabel = UiKit.Text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 12),
		Size = UDim2.new(0, 150, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, zeile)

	local knopf = UiKit.Knopf({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 40),
		Size = UDim2.new(0, 150, 0, 30),
		TextSize = 13,
		Text = "ERFORSCHEN",
	}, zeile)

	knopf.Activated:Connect(function()
		Net:Event("TechKaufen"):FireServer(tech.Id)
	end)

	techZeilen[tech.Id] = { Stufen = stufenLabel, Preis = preisLabel, Knopf = knopf }
end

-- ================================================================
-- SEITE 3: SHOP
-- ================================================================
local shopListe = UiKit.Neu("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = Farben.PanelRand,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, seiteShop)

UiKit.Neu("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, shopListe)
UiKit.Neu("UIPadding", { PaddingRight = UDim.new(0, 8) }, shopListe)

local function baueShop()
	for _, kind in shopListe:GetChildren() do
		if kind:IsA("Frame") then
			kind:Destroy()
		end
	end

	for index, eintrag in stand.Shop do
		local zeile = UiKit.Neu("Frame", {
			Name = eintrag.Schluessel,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 76),
			BackgroundColor3 = Farben.PanelHell,
			BorderSizePixel = 0,
		}, shopListe)
		UiKit.Ecken(zeile, 10)

		local istPass = eintrag.Art == "Gamepass"

		local streifen = UiKit.Neu("Frame", {
			Size = UDim2.new(0, 4, 1, -16),
			Position = UDim2.new(0, 8, 0, 8),
			BackgroundColor3 = istPass and Farben.Gold or Farben.Akzent,
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
			TextSize = 10,
			TextColor3 = istPass and Farben.Gold or Farben.Akzent,
			Text = istPass and "GAMEPASS · einmalig, für immer" or "PAKET · beliebig oft",
		}, zeile)

		UiKit.Text({
			Position = UDim2.new(0, 20, 0, 43),
			Size = UDim2.new(1, -180, 0, 26),
			TextSize = 11,
			TextColor3 = Farben.TextGedimmt,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = eintrag.Beschreibung,
		}, zeile)

		local knopf = UiKit.Knopf({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 150, 0, 34),
			TextSize = 13,
			Text = "KAUFEN",
		}, zeile)

		if eintrag.Besitzt then
			knopf.Text = "BESITZT DU"
			knopf.BackgroundColor3 = Farben.Gut
			knopf.TextColor3 = Color3.fromRGB(8, 20, 14)
		elseif not eintrag.Verfuegbar then
			-- Id steht noch auf 0 -> im Creator Dashboard noch nicht angelegt
			knopf.Text = "BALD VERFÜGBAR"
			knopf.BackgroundColor3 = Farben.Inaktiv
			knopf.TextColor3 = Farben.TextGedimmt
		else
			knopf.Activated:Connect(function()
				if istPass then
					MarketplaceService:PromptGamePassPurchase(spieler, eintrag.Id)
				else
					MarketplaceService:PromptProductPurchase(spieler, eintrag.Id)
				end
			end)
		end
	end
end

-- ================================================================
-- ANZEIGE AKTUALISIEREN
-- ================================================================
local function aktualisiere()
	-- --- Rebirth ---
	rebirthZahl.Text = "REBIRTH " .. stand.Rebirths
	rebirthBonus.Text = ("Aktuell +%d %% Einkommen  ·  nächster Rebirth +%d %%"):format(
		math.floor(stand.Rebirths * stand.BonusProRebirth * 100),
		math.floor(stand.BonusProRebirth * 100)
	)

	local anteil = math.clamp(stand.GesamtVerdient / math.max(1, stand.RebirthSchwelle), 0, 1)
	balkenFuellung.Size = UDim2.new(anteil, 0, 1, 0)
	fortschrittText.Text = ("Gesamtverdienst  %s / %s %s"):format(
		Util.FormatGeld(stand.GesamtVerdient),
		Util.FormatGeld(stand.RebirthSchwelle),
		Config.Spiel.Waehrung
	)

	if stand.KannRebirth then
		local wartetAufBestaetigung = os.clock() < rebirthBestaetigungBis
		rebirthKnopf.BackgroundColor3 = wartetAufBestaetigung and Farben.Warnung or Farben.Gold
		rebirthKnopf.TextColor3 = Color3.fromRGB(20, 14, 0)
		rebirthKnopf.Text = wartetAufBestaetigung
			and "SICHER?  NOCHMAL DRÜCKEN"
			or "REBIRTH DURCHFÜHREN"
	else
		rebirthKnopf.BackgroundColor3 = Farben.Inaktiv
		rebirthKnopf.TextColor3 = Farben.TextGedimmt
		rebirthKnopf.Text = "NOCH " .. Util.FormatGeld(
			math.max(0, stand.RebirthSchwelle - stand.GesamtVerdient)
		) .. " VERDIENEN"
	end

	-- --- Technologie ---
	for _, tech in TechConfig.Technologien do
		local zeile = techZeilen[tech.Id]
		if not zeile then
			continue
		end

		local stufe = stand.Tech[tech.Id] or 0
		local preis = stand.TechPreise[tech.Id]

		-- Stufenanzeige als gefuellte/leere Kaestchen
		local kaestchen = {}
		for i = 1, tech.MaxStufe do
			table.insert(kaestchen, i <= stufe and "■" or "□")
		end
		zeile.Stufen.Text = table.concat(kaestchen, " ")
			.. ("   Stufe %d/%d"):format(stufe, tech.MaxStufe)

		if not preis then
			zeile.Preis.Text = "MAXIMUM"
			zeile.Preis.TextColor3 = Farben.Gut
			zeile.Knopf.Text = "VOLL ERFORSCHT"
			zeile.Knopf.BackgroundColor3 = Farben.Inaktiv
			zeile.Knopf.TextColor3 = Farben.TextGedimmt
		else
			local bezahlbar = geld >= preis
			zeile.Preis.Text = Util.FormatGeld(preis) .. " " .. Config.Spiel.Waehrung
			zeile.Preis.TextColor3 = bezahlbar and Farben.Gut or Farben.Warnung
			zeile.Knopf.Text = "ERFORSCHEN"
			zeile.Knopf.BackgroundColor3 = bezahlbar and Farben.Akzent or Farben.Inaktiv
			zeile.Knopf.TextColor3 = bezahlbar and Color3.fromRGB(8, 16, 24) or Farben.TextGedimmt
		end
	end
end

-- ================================================================
-- SERVER-EREIGNISSE
-- ================================================================
Net:Event("ImperiumUpdate").OnClientEvent:Connect(function(daten)
	local shopGeaendert = daten.Shop ~= nil

	for schluessel, wert in daten do
		stand[schluessel] = wert
	end

	if shopGeaendert then
		baueShop()
	end
	aktualisiere()
end)

Net:Event("DatenUpdate").OnClientEvent:Connect(function(daten)
	if daten.Geld then
		geld = daten.Geld
	end
	if daten.GesamtVerdient then
		stand.GesamtVerdient = daten.GesamtVerdient
	end
	if fenster.Offen then
		aktualisiere()
	end
end)

rebirthKnopf.Activated:Connect(function()
	if not stand.KannRebirth then
		return
	end

	-- Zwei-Klick-Sicherung: Ein Rebirth loescht die ganze Station.
	-- Der erste Klick fragt nach, der zweite fuehrt ihn aus.
	if os.clock() >= rebirthBestaetigungBis then
		rebirthBestaetigungBis = os.clock() + 5
		aktualisiere()
		return
	end

	rebirthBestaetigungBis = 0
	Net:Event("RebirthStarten"):FireServer()
end)

-- ================================================================
-- OEFFNEN
-- ================================================================
fenster.BeimOeffnen = function()
	rebirthBestaetigungBis = 0
	Net:Event("ImperiumAnfrage"):FireServer()
	Net:Event("DatenAnfrage"):FireServer()
	aktualisiere()
end

local knopf = UiKit.LeistenKnopf("IMPERIUM", 30)
knopf.Activated:Connect(function()
	fenster:Umschalten()
end)

zeigeSeite("REBIRTH")
baueShop()
aktualisiere()

task.defer(function()
	Net:Event("ImperiumAnfrage"):FireServer()
end)

print("[ImperiumGui] Imperium bereit")
]==],
	},
	{
		Ziel = "StarterPlayerScripts",
		Name = "PlanetGui",
		Klasse = "LocalScript",
		Quelle = [==[
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
]==],
	},
}

local angelegt = 0
for _, eintrag in DATEIEN do
	local eltern = ZIELE[eintrag.Ziel]
	if eltern then
		local alt = eltern:FindFirstChild(eintrag.Name)
		if alt then alt:Destroy() end

		local neu = Instance.new(eintrag.Klasse)
		neu.Name = eintrag.Name
		neu.Source = eintrag.Quelle
		neu.Parent = eltern
		angelegt += 1
	else
		warn("[Installer] Unbekanntes Ziel: " .. eintrag.Ziel)
	end
end

print("================================================")
print("STELLAR DOMINION installiert: " .. angelegt .. " Scripts")
print("Jetzt auf Play druecken (F5).")
print("================================================")
