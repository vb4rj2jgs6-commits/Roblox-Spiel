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
