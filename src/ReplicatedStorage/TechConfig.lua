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
