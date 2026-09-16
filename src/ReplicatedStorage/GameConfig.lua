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
}

return Config
