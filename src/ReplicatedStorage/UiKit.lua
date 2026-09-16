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
		return UiKit.Farben.Warnung
	elseif name == "Gut" then
		return UiKit.Farben.Gut
	elseif name == "Gold" then
		return UiKit.Farben.Gold
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
	return UiKit.Neu("UICorner", { CornerRadius = UDim.new(0, radius) }, eltern)
end

function UiKit.Rand(eltern: Instance, farbe: Color3, dicke: number?, transparenz: number?)
	return UiKit.Neu("UIStroke", {
		Color = farbe,
		Thickness = dicke or 1,
		Transparency = transparenz or 0.4,
	}, eltern)
end

function UiKit.Abstand(eltern: Instance, pixel: number)
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

return UiKit
