--[[
	EventService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > EventService

	AUFGABE
	Zufallsereignisse, die den Server lebendig machen. Alle paar
	Minuten passiert eines von drei Dingen:

	  1. METEORITENSCHAUER — doppeltes Einkommen fuer alle, 90 s lang
	  2. PIRATEN-ÜBERFALL  — ein zufaelliger Spieler wird 20 s vorher
	     gewarnt. Wer rechtzeitig sammelt, verliert nichts. Sonst
	     stehlen die Piraten bis zu 50 % des Lagers — jede Stufe
	     Orbitalgeschütze zieht 10 Prozentpunkte davon ab.
	  3. HANDELSKONVOI — auf jedem Plot erscheinen Frachtkisten.
	     Einsammeln bringt Credits.

	WARUM DAS GUT FUERS SPIEL IST:
	Ein reiner Idle-Tycoon laeuft von allein. Diese Ereignisse geben
	dem Spieler einen Grund, tatsaechlich hinzuschauen — und der
	Piraten-Überfall gibt dem Lager-Limit und den Orbitalgeschützen
	endlich einen echten Zweck.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)
local DropperService = require(script.Parent.DropperService)

local EventService = {}

local Ereignisse = TechConfig.Ereignisse

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[EventService]", ...)
	end
end

local function meldeAllen(text: string, farbe: string)
	for _, spieler in Players:GetPlayers() do
		Net:Event("Benachrichtigung"):FireClient(spieler, { Text = text, Farbe = farbe })
	end
end

-- ================================================================
-- 1) METEORITENSCHAUER
-- ================================================================
function EventService:Meteoritenschauer()
	local daten = Ereignisse.Meteoritenschauer

	CurrencyService.EventMultiplikator = daten.Multiplikator
	CurrencyService.EventName = daten.Name
	CurrencyService.EventEndeUm = os.clock() + daten.Dauer

	meldeAllen(daten.Text, "Gold")
	log("Meteoritenschauer gestartet")

	-- Alle Anzeigen sofort auffrischen, damit der neue Multiplikator
	-- oben rechts direkt sichtbar ist.
	for _, spieler in Players:GetPlayers() do
		CurrencyService:MarkiereAenderung(spieler)
	end

	task.delay(daten.Dauer, function()
		CurrencyService.EventMultiplikator = 1
		CurrencyService.EventName = nil
		CurrencyService.EventEndeUm = 0

		for _, spieler in Players:GetPlayers() do
			CurrencyService:MarkiereAenderung(spieler)
		end

		meldeAllen("Der Meteoritenschauer ist vorüber.", "Text")
		log("Meteoritenschauer beendet")
	end)
end

-- ================================================================
-- 2) PIRATEN-ÜBERFALL
-- ================================================================
function EventService:Piratenueberfall()
	local daten = Ereignisse.Piratenueberfall

	-- Ziel: ein zufaelliger Spieler, der ueberhaupt etwas im Lager hat.
	local kandidaten = {}
	for _, spieler in Players:GetPlayers() do
		local spielerDaten = DataService:Get(spieler)
		if spielerDaten and spielerDaten.Lager > 0 then
			table.insert(kandidaten, spieler)
		end
	end

	if #kandidaten == 0 then
		return
	end

	local ziel = kandidaten[math.random(#kandidaten)]

	Net:Event("Benachrichtigung"):FireClient(ziel, {
		Text = daten.Warnung,
		Farbe = "Warnung",
	})
	log("Piraten greifen an:", ziel.Name)

	task.delay(daten.Vorwarnzeit, function()
		if not ziel.Parent then
			return
		end

		local spielerDaten = DataService:Get(ziel)
		if not spielerDaten or spielerDaten.Lager <= 0 then
			Net:Event("Benachrichtigung"):FireClient(ziel, {
				Text = "Die Piraten fanden ein leeres Lager. Gut gemacht!",
				Farbe = "Gut",
			})
			return
		end

		-- Orbitalgeschütze reduzieren den Verlust, ab Stufe 5 auf null.
		local stufe = CurrencyService:GetTechStufe(ziel, "Orbitalgeschuetze")
		local anteil = math.max(0, daten.Grundverlust - stufe * daten.SchutzProStufe)

		if anteil <= 0 then
			Net:Event("Benachrichtigung"):FireClient(ziel, {
				Text = "Deine Orbitalgeschütze haben den Überfall abgewehrt!",
				Farbe = "Gut",
			})
			return
		end

		local verlust = math.floor(spielerDaten.Lager * anteil)
		spielerDaten.Lager -= verlust
		CurrencyService:MarkiereAenderung(ziel)

		Net:Event("Benachrichtigung"):FireClient(ziel, {
			Text = ("Piraten haben %s %s gestohlen!"):format(
				Util.FormatGeld(verlust),
				Config.Spiel.Waehrung
			),
			Farbe = "Warnung",
		})
	end)
end

-- ================================================================
-- 3) HANDELSKONVOI
-- ================================================================
local function baueKiste(plot: any, spieler: Player, wert: number, lebensdauer: number)
	-- Zufaellige Stelle auf dem Plot, aber nicht direkt am Rand
	local lokal = Vector3.new(math.random(-30, 30), 3, math.random(-10, 40))
	local position = PlotService:ZuWelt(plot, lokal)

	local kiste = Util.NeuerPart({
		Name = "Frachtkiste",
		Size = Vector3.new(5, 5, 5),
		Color = Color3.fromRGB(255, 205, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0),
	})
	kiste.Parent = plot.Model

	local schild = Instance.new("BillboardGui")
	schild.Size = UDim2.fromScale(10, 2.4)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	schild.MaxDistance = 180
	schild.Parent = kiste

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 225, 150)
	text.TextStrokeTransparency = 0.35
	text.Text = "+" .. Util.FormatGeld(wert)
	text.Parent = schild

	-- Schweben und drehen, damit sie auffaellt
	TweenService:Create(
		kiste,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = kiste.CFrame + Vector3.new(0, 2, 0) }
	):Play()

	-- Verschwindet von selbst, wenn sie niemand holt
	Debris:AddItem(kiste, lebensdauer)

	local eingesammelt = false
	kiste.Touched:Connect(function(getroffen)
		if eingesammelt then
			return
		end

		local charakter = getroffen:FindFirstAncestorOfClass("Model")
		if not charakter or Players:GetPlayerFromCharacter(charakter) ~= spieler then
			return
		end

		eingesammelt = true
		CurrencyService:Hinzufuegen(spieler, wert)
		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = "Frachtkiste: +" .. Util.FormatGeld(wert) .. " " .. Config.Spiel.Waehrung,
			Farbe = "Gold",
		})
		kiste:Destroy()
	end)
end

function EventService:Handelskonvoi()
	local daten = Ereignisse.Handelskonvoi
	local jemandDabei = false

	for _, spieler in Players:GetPlayers() do
		local plot = PlotService:GetPlot(spieler)
		if plot then
			-- Der Wert richtet sich nach der eigenen Produktion, damit die
			-- Kiste in jeder Spielphase interessant bleibt.
			local proSekunde = DropperService:GetEinkommenProSekunde(spieler)
			local wert = math.max(100, math.floor(proSekunde * daten.SekundenProduktion))

			for _ = 1, daten.Kisten do
				baueKiste(plot, spieler, wert, daten.Dauer)
			end
			jemandDabei = true
		end
	end

	if jemandDabei then
		meldeAllen(daten.Text, "Gold")
		log("Handelskonvoi gestartet")
	end
end

-- ================================================================
-- STEUERUNG
-- ================================================================
function EventService:ZufallsereignisStarten()
	-- Ohne Spieler brauchen wir kein Ereignis
	if #Players:GetPlayers() == 0 then
		return
	end

	local auswahl = math.random(3)
	if auswahl == 1 then
		self:Meteoritenschauer()
	elseif auswahl == 2 then
		self:Piratenueberfall()
	else
		self:Handelskonvoi()
	end
end

function EventService:Init()
	task.spawn(function()
		-- Beim Serverstart nicht sofort: Erst sollen die Spieler ankommen.
		task.wait(Ereignisse.MinAbstand)

		while true do
			self:ZufallsereignisStarten()
			task.wait(math.random(Ereignisse.MinAbstand, Ereignisse.MaxAbstand))
		end
	end)

	log("bereit")
end

return EventService
