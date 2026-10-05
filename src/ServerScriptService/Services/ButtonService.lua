--[[
	ButtonService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > ButtonService

	AUFGABE
	Erzeugt die begehbaren Kauf-Pads auf dem Plot und wickelt den Kauf ab.

	EXPLOIT-SCHUTZ — bitte merken:
	Der Kauf laeuft KOMPLETT auf dem Server. Der Client schickt keinen
	"Ich kaufe X"-Befehl, er laeuft nur physisch auf das Pad. Der Server
	prueft danach selbst:
	   1. Gehoert der Plot diesem Spieler?
	   2. Ist das Objekt noch nicht gekauft?
	   3. Ist die Voraussetzung erfuellt?
	   4. Hat der Spieler wirklich genug Credits?
	Selbst wenn jemand seine Figur auf das Pad teleportiert, kann er
	nichts kaufen, was er sich nicht leisten kann.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)

local ButtonService = {}

local FARBE_BEZAHLBAR = Color3.fromRGB(70, 220, 130)
local FARBE_ZU_TEUER = Color3.fromRGB(220, 80, 90)
local FARBE_GRATIS = Color3.fromRGB(90, 200, 255)

-- Entprellung: verhindert, dass ein einziger Schritt aufs Pad
-- das Touched-Event 20x ausloest.
local letzteBeruehrung: { [string]: number } = {}

local function baueButton(plot: any, eintrag: any)
	-- ZuWeltCF statt ZuWelt: Die Stationen stehen im Ring und sind darum
	-- unterschiedlich gedreht. Ohne die Drehung staenden die eckigen Pads
	-- schief auf der Plattform.
	local function cf(versatz: Vector3): CFrame
		return PlotService:ZuWeltCF(plot, CFrame.new(eintrag.ButtonPos + versatz))
	end

	local model = Instance.new("Model")
	model.Name = eintrag.Id
	model.Parent = plot.ButtonOrdner

	local sockel = Util.NeuerPart({
		Name = "Sockel",
		Size = Vector3.new(9, 1, 9),
		Color = Color3.fromRGB(35, 40, 56),
		Material = Enum.Material.Metal,
		CFrame = cf(Vector3.new(0, 0.5, 0)),
	})
	sockel.Parent = model

	local pad = Util.NeuerPart({
		Name = "Pad",
		Size = Vector3.new(7.5, 0.6, 7.5),
		Color = FARBE_BEZAHLBAR,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		-- CanCollide = false: Der Spieler laeuft DURCH das Pad hindurch.
		-- Touched feuert trotzdem. Das verhindert, dass die Schwebe-
		-- Animation die Spielfigur anhebt oder wegschiebt.
		CanCollide = false,
		CFrame = cf(Vector3.new(0, 1.2, 0)),
	})
	pad.Parent = model
	model.PrimaryPart = pad

	local schild = Instance.new("BillboardGui")
	schild.Name = "Info"
	schild.Size = UDim2.fromScale(13, 4)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	schild.MaxDistance = 180
	schild.Parent = pad

	local rahmen = Instance.new("Frame")
	rahmen.Size = UDim2.fromScale(1, 1)
	rahmen.BackgroundTransparency = 1
	rahmen.Parent = schild

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rahmen

	local name = Instance.new("TextLabel")
	name.Name = "Titel"
	name.LayoutOrder = 1
	name.Size = UDim2.fromScale(1, 0.55)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.3
	name.Text = eintrag.Name
	name.Parent = rahmen

	local preis = Instance.new("TextLabel")
	preis.Name = "Preis"
	preis.LayoutOrder = 2
	preis.Size = UDim2.fromScale(1, 0.45)
	preis.BackgroundTransparency = 1
	preis.Font = Enum.Font.GothamBlack
	preis.TextScaled = true
	preis.TextStrokeTransparency = 0.3
	preis.TextColor3 = FARBE_BEZAHLBAR
	preis.Text = eintrag.Preis <= 0
		and "GRATIS"
		or (Util.FormatGeld(eintrag.Preis) .. " " .. Config.Spiel.Waehrung)
	preis.Parent = rahmen

	-- Kleine Auf-und-ab-Animation, damit die Pads auffallen
	TweenService:Create(
		pad,
		TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = pad.CFrame + Vector3.new(0, 0.5, 0) }
	):Play()

	pad.Touched:Connect(function(getroffen)
		local charakter = getroffen:FindFirstAncestorOfClass("Model")
		if not charakter then
			return
		end
		local spieler = Players:GetPlayerFromCharacter(charakter)
		if not spieler then
			return
		end
		ButtonService:KaufVersuch(spieler, plot, eintrag)
	end)

	return model
end

-- Zeigt genau die Buttons, die gerade kaufbar sind (Voraussetzung erfuellt,
-- noch nicht gekauft). Wird nach jedem Kauf neu aufgerufen.
function ButtonService:AktualisiereButtons(plot: any)
	local spieler = plot.Besitzer
	if not spieler then
		plot.ButtonOrdner:ClearAllChildren()
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	for _, eintrag in Config.Kaufbares do
		local schonGekauft = daten.Gekauft[eintrag.Id] == true
		local freigeschaltet = (eintrag.Benoetigt == nil) or (daten.Gekauft[eintrag.Benoetigt] == true)
		local sollSichtbar = freigeschaltet and not schonGekauft

		local vorhanden = plot.ButtonOrdner:FindFirstChild(eintrag.Id)

		if sollSichtbar and not vorhanden then
			baueButton(plot, eintrag)
		elseif not sollSichtbar and vorhanden then
			vorhanden:Destroy()
		end
	end
end

-- Faerbt die Preise gruen/rot, je nach Kontostand.
function ButtonService:AktualisiereFarben(plot: any)
	local spieler = plot.Besitzer
	if not spieler then
		return
	end

	local geld = CurrencyService:GetGeld(spieler)

	for _, model in plot.ButtonOrdner:GetChildren() do
		local eintrag = PlotService.KaufbaresNachId[model.Name]
		local pad = model:FindFirstChild("Pad") :: BasePart?

		if eintrag and pad then
			local farbe
			if eintrag.Preis <= 0 then
				farbe = FARBE_GRATIS
			elseif geld >= eintrag.Preis then
				farbe = FARBE_BEZAHLBAR
			else
				farbe = FARBE_ZU_TEUER
			end

			pad.Color = farbe

			local info = pad:FindFirstChild("Info")
			local rahmen = info and info:FindFirstChildOfClass("Frame")
			local label = rahmen and rahmen:FindFirstChild("Preis")
			if label then
				(label :: TextLabel).TextColor3 = farbe
			end
		end
	end
end

-- ================================================================
-- KAUF (die eigentliche Validierung)
-- ================================================================
function ButtonService:KaufVersuch(spieler: Player, plot: any, eintrag: any)
	-- 0) Entprellung
	local schluessel = spieler.UserId .. "_" .. eintrag.Id
	local jetzt = os.clock()
	if letzteBeruehrung[schluessel] and (jetzt - letzteBeruehrung[schluessel]) < 0.6 then
		return
	end
	letzteBeruehrung[schluessel] = jetzt

	-- 1) Gehoert der Plot diesem Spieler?
	if plot.Besitzer ~= spieler then
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	-- 2) Schon gekauft?
	if daten.Gekauft[eintrag.Id] then
		return
	end

	-- 3) Voraussetzung erfuellt?
	if eintrag.Benoetigt and not daten.Gekauft[eintrag.Benoetigt] then
		return
	end

	-- 4) Genug Credits? (CurrencyService bucht nur ab, wenn es reicht)
	if eintrag.Preis > 0 then
		if not CurrencyService:Abbuchen(spieler, eintrag.Preis) then
			Net:Event("Benachrichtigung"):FireClient(spieler, {
				Text = "Nicht genug Credits fuer " .. eintrag.Name,
				Farbe = "Warnung",
			})
			return
		end
	end

	-- Alles geprueft -> jetzt erst wird gebaut
	daten.Gekauft[eintrag.Id] = true

	PlotService:BaueObjekt(plot, eintrag)
	PlotService:NeuBerechnen(plot)
	self:AktualisiereButtons(plot)

	CurrencyService:MarkiereAenderung(spieler)
	Net:Event("KaufBestaetigt"):FireClient(spieler, {
		Id = eintrag.Id,
		Name = eintrag.Name,
		Preis = eintrag.Preis,
	})

	if Config.Spiel.DebugAusgaben then
		print("[ButtonService]", spieler.Name, "kauft", eintrag.Id, "fuer", eintrag.Preis)
	end
end

function ButtonService:Init()
	PlotService.Zugewiesen:Verbinden(function(_spieler, plot)
		self:AktualisiereButtons(plot)
		self:AktualisiereFarben(plot)
	end)

	-- Preisfarben regelmaessig auffrischen (4x pro Sekunde reicht voellig)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, plot in PlotService.Plots do
				if plot.Besitzer then
					self:AktualisiereFarben(plot)
				end
			end
		end
	end)

	-- Entprellungs-Eintraege aufraeumen, damit die Tabelle nicht endlos waechst
	Players.PlayerRemoving:Connect(function(spieler)
		local praefix = spieler.UserId .. "_"
		for schluessel in letzteBeruehrung do
			if string.sub(schluessel, 1, #praefix) == praefix then
				letzteBeruehrung[schluessel] = nil
			end
		end
	end)

	if Config.Spiel.DebugAusgaben then
		print("[ButtonService] bereit")
	end
end

return ButtonService
