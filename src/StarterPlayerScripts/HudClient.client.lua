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

local spieler = Players.LocalPlayer
local spielerGui = spieler:WaitForChild("PlayerGui")

-- ================================================================
-- FARBEN (an einer Stelle, damit du das Design schnell umstellen kannst)
-- ================================================================
local FARBEN = {
	Panel = Color3.fromRGB(16, 19, 30),
	PanelRand = Color3.fromRGB(0, 190, 255),
	Text = Color3.fromRGB(235, 242, 255),
	TextGedimmt = Color3.fromRGB(140, 155, 180),
	Akzent = Color3.fromRGB(0, 220, 255),
	Gut = Color3.fromRGB(70, 230, 140),
	Warnung = Color3.fromRGB(255, 90, 100),
	Gold = Color3.fromRGB(255, 205, 90),
}

-- ================================================================
-- KLEINE BAU-HELFER
-- ================================================================
local function ecken(eltern: Instance, radius: number)
	local ecke = Instance.new("UICorner")
	ecke.CornerRadius = UDim.new(0, radius)
	ecke.Parent = eltern
	return ecke
end

local function rand(eltern: Instance, farbe: Color3, dicke: number, transparenz: number?)
	local strich = Instance.new("UIStroke")
	strich.Color = farbe
	strich.Thickness = dicke
	strich.Transparency = transparenz or 0.4
	strich.Parent = eltern
	return strich
end

-- ================================================================
-- GUI AUFBAUEN
-- ================================================================
local hud = Instance.new("ScreenGui")
hud.Name = "HUD"
hud.ResetOnSpawn = false          -- ueberlebt den Respawn
hud.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hud.Parent = spielerGui

-- ---------- Haupt-Panel oben rechts ----------
local panel = Instance.new("Frame")
panel.Name = "Waehrungspanel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, 12)
panel.Size = UDim2.new(0, 246, 0, 164)
panel.BackgroundColor3 = FARBEN.Panel
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = hud
ecken(panel, 12)
rand(panel, FARBEN.PanelRand, 1.5, 0.55)

local innenAbstand = Instance.new("UIPadding")
innenAbstand.PaddingTop = UDim.new(0, 10)
innenAbstand.PaddingBottom = UDim.new(0, 10)
innenAbstand.PaddingLeft = UDim.new(0, 12)
innenAbstand.PaddingRight = UDim.new(0, 12)
innenAbstand.Parent = panel

-- ---------- Zeile: Ueberschrift ----------
local ueberschrift = Instance.new("TextLabel")
ueberschrift.Name = "Ueberschrift"
ueberschrift.Size = UDim2.new(1, 0, 0, 14)
ueberschrift.BackgroundTransparency = 1
ueberschrift.Font = Enum.Font.GothamMedium
ueberschrift.TextSize = 11
ueberschrift.TextXAlignment = Enum.TextXAlignment.Left
ueberschrift.TextColor3 = FARBEN.TextGedimmt
ueberschrift.Text = "GUTHABEN"
ueberschrift.Parent = panel

-- ---------- Zeile: Geldbetrag ----------
local geldLabel = Instance.new("TextLabel")
geldLabel.Name = "Geld"
geldLabel.Position = UDim2.new(0, 0, 0, 16)
geldLabel.Size = UDim2.new(1, 0, 0, 34)
geldLabel.BackgroundTransparency = 1
geldLabel.Font = Enum.Font.GothamBlack
geldLabel.TextSize = 28
geldLabel.TextXAlignment = Enum.TextXAlignment.Left
geldLabel.TextColor3 = FARBEN.Text
geldLabel.Text = "0 " .. Config.Spiel.Waehrung
geldLabel.Parent = panel

-- ---------- Zeile: Multiplikator + Rebirths ----------
local multLabel = Instance.new("TextLabel")
multLabel.Name = "Multiplikator"
multLabel.Position = UDim2.new(0, 0, 0, 51)
multLabel.Size = UDim2.new(1, 0, 0, 16)
multLabel.BackgroundTransparency = 1
multLabel.Font = Enum.Font.GothamBold
multLabel.TextSize = 12
multLabel.TextXAlignment = Enum.TextXAlignment.Left
multLabel.TextColor3 = FARBEN.Gold
multLabel.Text = "x1.00 Einkommen"
multLabel.Parent = panel

-- ---------- Lager-Ueberschrift ----------
local lagerTitel = Instance.new("TextLabel")
lagerTitel.Name = "LagerTitel"
lagerTitel.Position = UDim2.new(0, 0, 0, 72)
lagerTitel.Size = UDim2.new(1, 0, 0, 14)
lagerTitel.BackgroundTransparency = 1
lagerTitel.Font = Enum.Font.GothamMedium
lagerTitel.TextSize = 11
lagerTitel.TextXAlignment = Enum.TextXAlignment.Left
lagerTitel.TextColor3 = FARBEN.TextGedimmt
lagerTitel.Text = "LAGER  0 / 0"
lagerTitel.Parent = panel

-- ---------- Lager-Fortschrittsbalken ----------
local balkenHuelle = Instance.new("Frame")
balkenHuelle.Name = "LagerBalken"
balkenHuelle.Position = UDim2.new(0, 0, 0, 89)
balkenHuelle.Size = UDim2.new(1, 0, 0, 10)
balkenHuelle.BackgroundColor3 = Color3.fromRGB(35, 40, 58)
balkenHuelle.BorderSizePixel = 0
balkenHuelle.Parent = panel
ecken(balkenHuelle, 5)

local balkenFuellung = Instance.new("Frame")
balkenFuellung.Name = "Fuellung"
balkenFuellung.Size = UDim2.new(0, 0, 1, 0)
balkenFuellung.BackgroundColor3 = FARBEN.Akzent
balkenFuellung.BorderSizePixel = 0
balkenFuellung.Parent = balkenHuelle
ecken(balkenFuellung, 5)

-- ---------- Sammeln-Knopf ----------
local sammelKnopf = Instance.new("TextButton")
sammelKnopf.Name = "Sammeln"
sammelKnopf.Position = UDim2.new(0, 0, 0, 106)
sammelKnopf.Size = UDim2.new(1, 0, 0, 38)
sammelKnopf.BackgroundColor3 = FARBEN.Gut
sammelKnopf.BorderSizePixel = 0
sammelKnopf.AutoButtonColor = true
sammelKnopf.Font = Enum.Font.GothamBold
sammelKnopf.TextSize = 15
sammelKnopf.TextColor3 = Color3.fromRGB(8, 20, 14)
sammelKnopf.Text = "SAMMELN"
sammelKnopf.Parent = panel
ecken(sammelKnopf, 9)

-- ================================================================
-- BENACHRICHTIGUNGEN (Toasts)
-- ================================================================
local toastBereich = Instance.new("Frame")
toastBereich.Name = "Toasts"
toastBereich.AnchorPoint = Vector2.new(0.5, 1)
toastBereich.Position = UDim2.new(0.5, 0, 1, -110)
toastBereich.Size = UDim2.new(0, 320, 0, 160)
toastBereich.BackgroundTransparency = 1
toastBereich.Parent = hud

local toastLayout = Instance.new("UIListLayout")
toastLayout.FillDirection = Enum.FillDirection.Vertical
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastBereich

local function zeigeToast(text: string, farbe: Color3)
	local karte = Instance.new("TextLabel")
	karte.Size = UDim2.new(1, 0, 0, 32)
	karte.BackgroundColor3 = FARBEN.Panel
	karte.BackgroundTransparency = 0.1
	karte.BorderSizePixel = 0
	karte.Font = Enum.Font.GothamBold
	karte.TextSize = 14
	karte.TextColor3 = farbe
	karte.Text = text
	karte.Parent = toastBereich
	ecken(karte, 8)
	rand(karte, farbe, 1, 0.5)

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
-- DATEN VOM SERVER VERARBEITEN
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
	local farbe = FARBEN.Text
	if info.Farbe == "Warnung" then
		farbe = FARBEN.Warnung
	elseif info.Farbe == "Gut" then
		farbe = FARBEN.Gut
	elseif info.Farbe == "Gold" then
		farbe = FARBEN.Gold
	end
	zeigeToast(info.Text, farbe)
end)

Net:Event("KaufBestaetigt").OnClientEvent:Connect(function(info)
	zeigeToast("Gekauft: " .. info.Name, FARBEN.Gut)

	-- Kleiner Puls auf dem Panel als Feedback
	local strich = panel:FindFirstChildOfClass("UIStroke")
	if strich then
		strich.Transparency = 0
		TweenService:Create(strich, TweenInfo.new(0.6), { Transparency = 0.55 }):Play()
	end
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
	balkenFuellung.BackgroundColor3 = (anteil >= 0.999) and FARBEN.Warnung or FARBEN.Akzent

	local etwasDrin = zustand.Lager > 0
	sammelKnopf.BackgroundColor3 = etwasDrin and FARBEN.Gut or Color3.fromRGB(60, 68, 88)
	sammelKnopf.TextColor3 = etwasDrin and Color3.fromRGB(8, 20, 14) or FARBEN.TextGedimmt
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
