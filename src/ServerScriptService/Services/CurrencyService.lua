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
