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
