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
