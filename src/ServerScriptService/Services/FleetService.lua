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
