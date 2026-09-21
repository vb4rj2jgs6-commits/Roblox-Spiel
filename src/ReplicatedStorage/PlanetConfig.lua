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
