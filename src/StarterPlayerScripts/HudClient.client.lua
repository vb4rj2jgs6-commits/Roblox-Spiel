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
