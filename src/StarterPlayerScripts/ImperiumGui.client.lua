--[[
	ImperiumGui  —  LocalScript
	================================================================
	EXPLORER-ORT:  StarterPlayer > StarterPlayerScripts > ImperiumGui

	Ein Fenster mit drei Reitern:
	  REBIRTH      — Fortschritt zurücksetzen gegen dauerhaften Bonus
	  TECHNOLOGIE  — der Forschungsbaum
	  SHOP         — Gamepasses und Credit-Pakete

	WARUM DREI REITER STATT DREI FENSTER?
	Drei Fenster hiessen drei Knoepfe in der Aktionsleiste, dreimal
	derselbe Rahmen-Code und dreimal dieselben Server-Daten. Die drei
	Themen gehoeren inhaltlich zusammen ("mein Imperium") — also ein
	Fenster.

	EXPLOIT-SCHUTZ:
	"TechKaufen" schickt nur die Id der Technologie, "RebirthStarten"
	gar nichts. Preise, Stufen und Voraussetzungen prueft der
	ImperiumService. Die Robux-Kaeufe laufen ueber MarketplaceService;
	gutgeschrieben wird erst in ProcessReceipt auf dem Server.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local UiKit = require(ReplicatedStorage:WaitForChild("UiKit"))

local spieler = Players.LocalPlayer
local Farben = UiKit.Farben

-- ================================================================
-- ZUSTAND
-- ================================================================
local stand = {
	Tech = {},
	TechPreise = {},
	Rebirths = 0,
	RebirthSchwelle = TechConfig.RebirthSchwelle(0),
	GesamtVerdient = 0,
	KannRebirth = false,
	BonusProRebirth = 0.25,
	Shop = {},
}

local geld = 0
local rebirthBestaetigungBis = 0   -- Zwei-Klick-Sicherung

local fenster = UiKit.Fenster({
	Name = "ImperiumGui",
	Titel = "IMPERIUM",
	Untertitel = "Rebirth · Technologie · Shop",
	MaxGroesse = Vector2.new(660, 580),
	Ebene = 7,
})

-- ================================================================
-- REITER
-- ================================================================
local reiterLeiste = UiKit.Neu("Frame", {
	Name = "Reiter",
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
}, fenster.Inhalt)

UiKit.Neu("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 6),
}, reiterLeiste)

local seitenBereich = UiKit.Neu("Frame", {
	Name = "Seiten",
	Position = UDim2.new(0, 0, 0, 42),
	Size = UDim2.new(1, 0, 1, -42),
	BackgroundTransparency = 1,
}, fenster.Inhalt)

local reiter: { any } = {}

local function zeigeSeite(name: string)
	for _, eintrag in reiter do
		local aktiv = eintrag.Name == name
		eintrag.Seite.Visible = aktiv
		eintrag.Knopf.BackgroundColor3 = aktiv and Farben.Akzent or Farben.PanelHell
		eintrag.Knopf.TextColor3 = aktiv and Color3.fromRGB(8, 16, 24) or Farben.TextGedimmt
	end
end

local function baueReiter(reihenfolge: number, name: string)
	local knopf = UiKit.Knopf({
		Name = name,
		LayoutOrder = reihenfolge,
		Size = UDim2.new(1 / 3, -4, 1, 0),
		BackgroundColor3 = Farben.PanelHell,
		TextColor3 = Farben.TextGedimmt,
		TextSize = 12,
		Text = name,
	}, reiterLeiste)

	local seite = UiKit.Neu("Frame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, seitenBereich)

	table.insert(reiter, { Name = name, Knopf = knopf, Seite = seite })
	knopf.Activated:Connect(function()
		zeigeSeite(name)
	end)

	return seite
end

local seiteRebirth = baueReiter(1, "REBIRTH")
local seiteTech = baueReiter(2, "TECHNOLOGIE")
local seiteShop = baueReiter(3, "SHOP")

-- ================================================================
-- SEITE 1: REBIRTH
-- ================================================================
local rebirthZahl = UiKit.Text({
	Size = UDim2.new(1, 0, 0, 40),
	Font = Enum.Font.GothamBlack,
	TextSize = 32,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Farben.Gold,
	Text = "REBIRTH 0",
}, seiteRebirth)

local rebirthBonus = UiKit.Text({
	Position = UDim2.new(0, 0, 0, 40),
	Size = UDim2.new(1, 0, 0, 18),
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "Aktuell +0 % Einkommen",
}, seiteRebirth)

local fortschrittText = UiKit.Text({
	Position = UDim2.new(0, 0, 0, 68),
	Size = UDim2.new(1, 0, 0, 14),
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Farben.TextGedimmt,
	Text = "Gesamtverdienst 0 / 0",
}, seiteRebirth)

local balkenHuelle = UiKit.Neu("Frame", {
	Position = UDim2.new(0, 0, 0, 86),
	Size = UDim2.new(1, 0, 0, 12),
	BackgroundColor3 = Color3.fromRGB(35, 40, 58),
	BorderSizePixel = 0,
}, seiteRebirth)
UiKit.Ecken(balkenHuelle, 6)

local balkenFuellung = UiKit.Neu("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Farben.Gold,
	BorderSizePixel = 0,
}, balkenHuelle)
UiKit.Ecken(balkenFuellung, 6)

-- Zwei Spalten: was weg ist und was bleibt
local function baueSpalte(x: number, titel: string, farbe: Color3, eintraege: { string })
	local spalte = UiKit.Neu("Frame", {
		Position = UDim2.new(x, x == 0 and 0 or 5, 0, 112),
		Size = UDim2.new(0.5, -5, 0, 132),
		BackgroundColor3 = Farben.PanelHell,
		BorderSizePixel = 0,
	}, seiteRebirth)
	UiKit.Ecken(spalte, 10)
	UiKit.Abstand(spalte, 10)

	UiKit.Text({
		Size = UDim2.new(1, 0, 0, 14),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = farbe,
		Text = titel,
	}, spalte)

	for index, text in eintraege do
		UiKit.Text({
			Position = UDim2.new(0, 0, 0, 20 + index * 18),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 11,
			TextColor3 = Farben.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "· " .. text,
		}, spalte)
	end
end

baueSpalte(0, "WIRD ZURÜCKGESETZT", Farben.Warnung, TechConfig.Rebirth.WirdZurueckgesetzt)
baueSpalte(0.5, "BLEIBT ERHALTEN", Farben.Gut, TechConfig.Rebirth.BleibtErhalten)

local rebirthKnopf = UiKit.Knopf({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = Farben.Inaktiv,
	TextColor3 = Farben.TextGedimmt,
	TextSize = 15,
	Text = "REBIRTH DURCHFÜHREN",
}, seiteRebirth)

-- ================================================================
-- SEITE 2: TECHNOLOGIE
-- ================================================================
local techListe = UiKit.Neu("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = Farben.PanelRand,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, seiteTech)

UiKit.Neu("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, techListe)
UiKit.Neu("UIPadding", { PaddingRight = UDim.new(0, 8) }, techListe)

local techZeilen: { [string]: any } = {}

for _, tech in TechConfig.Technologien do
	local zeile = UiKit.Neu("Frame", {
		Name = tech.Id,
		LayoutOrder = tech.Reihenfolge,
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundColor3 = Farben.PanelHell,
		BorderSizePixel = 0,
	}, techListe)
	UiKit.Ecken(zeile, 10)

	local streifen = UiKit.Neu("Frame", {
		Size = UDim2.new(0, 4, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = tech.Farbe,
		BorderSizePixel = 0,
	}, zeile)
	UiKit.Ecken(streifen, 2)

	UiKit.Text({
		Position = UDim2.new(0, 20, 0, 8),
		Size = UDim2.new(1, -180, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Text = tech.Name,
	}, zeile)

	UiKit.Text({
		Position = UDim2.new(0, 20, 0, 27),
		Size = UDim2.new(1, -180, 0, 28),
		TextSize = 11,
		TextColor3 = Farben.TextGedimmt,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = tech.Beschreibung,
	}, zeile)

	local stufenLabel = UiKit.Text({
		Position = UDim2.new(0, 20, 0, 58),
		Size = UDim2.new(1, -180, 0, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = tech.Farbe,
		Text = "",
	}, zeile)

	local preisLabel = UiKit.Text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 12),
		Size = UDim2.new(0, 150, 0, 18),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "",
	}, zeile)

	local knopf = UiKit.Knopf({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 40),
		Size = UDim2.new(0, 150, 0, 30),
		TextSize = 13,
		Text = "ERFORSCHEN",
	}, zeile)

	knopf.Activated:Connect(function()
		Net:Event("TechKaufen"):FireServer(tech.Id)
	end)

	techZeilen[tech.Id] = { Stufen = stufenLabel, Preis = preisLabel, Knopf = knopf }
end

-- ================================================================
-- SEITE 3: SHOP
-- ================================================================
local shopListe = UiKit.Neu("ScrollingFrame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 5,
	ScrollBarImageColor3 = Farben.PanelRand,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, seiteShop)

UiKit.Neu("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 8),
}, shopListe)
UiKit.Neu("UIPadding", { PaddingRight = UDim.new(0, 8) }, shopListe)

local function baueShop()
	for _, kind in shopListe:GetChildren() do
		if kind:IsA("Frame") then
			kind:Destroy()
		end
	end

	for index, eintrag in stand.Shop do
		local zeile = UiKit.Neu("Frame", {
			Name = eintrag.Schluessel,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 76),
			BackgroundColor3 = Farben.PanelHell,
			BorderSizePixel = 0,
		}, shopListe)
		UiKit.Ecken(zeile, 10)

		local istPass = eintrag.Art == "Gamepass"

		local streifen = UiKit.Neu("Frame", {
			Size = UDim2.new(0, 4, 1, -16),
			Position = UDim2.new(0, 8, 0, 8),
			BackgroundColor3 = istPass and Farben.Gold or Farben.Akzent,
			BorderSizePixel = 0,
		}, zeile)
		UiKit.Ecken(streifen, 2)

		UiKit.Text({
			Position = UDim2.new(0, 20, 0, 8),
			Size = UDim2.new(1, -180, 0, 18),
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			Text = eintrag.Name,
		}, zeile)

		UiKit.Text({
			Position = UDim2.new(0, 20, 0, 27),
			Size = UDim2.new(1, -180, 0, 14),
			TextSize = 10,
			TextColor3 = istPass and Farben.Gold or Farben.Akzent,
			Text = istPass and "GAMEPASS · einmalig, für immer" or "PAKET · beliebig oft",
		}, zeile)

		UiKit.Text({
			Position = UDim2.new(0, 20, 0, 43),
			Size = UDim2.new(1, -180, 0, 26),
			TextSize = 11,
			TextColor3 = Farben.TextGedimmt,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = eintrag.Beschreibung,
		}, zeile)

		local knopf = UiKit.Knopf({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 150, 0, 34),
			TextSize = 13,
			Text = "KAUFEN",
		}, zeile)

		if eintrag.Besitzt then
			knopf.Text = "BESITZT DU"
			knopf.BackgroundColor3 = Farben.Gut
			knopf.TextColor3 = Color3.fromRGB(8, 20, 14)
		elseif not eintrag.Verfuegbar then
			-- Id steht noch auf 0 -> im Creator Dashboard noch nicht angelegt
			knopf.Text = "BALD VERFÜGBAR"
			knopf.BackgroundColor3 = Farben.Inaktiv
			knopf.TextColor3 = Farben.TextGedimmt
		else
			knopf.Activated:Connect(function()
				if istPass then
					MarketplaceService:PromptGamePassPurchase(spieler, eintrag.Id)
				else
					MarketplaceService:PromptProductPurchase(spieler, eintrag.Id)
				end
			end)
		end
	end
end

-- ================================================================
-- ANZEIGE AKTUALISIEREN
-- ================================================================
local function aktualisiere()
	-- --- Rebirth ---
	rebirthZahl.Text = "REBIRTH " .. stand.Rebirths
	rebirthBonus.Text = ("Aktuell +%d %% Einkommen  ·  nächster Rebirth +%d %%"):format(
		math.floor(stand.Rebirths * stand.BonusProRebirth * 100),
		math.floor(stand.BonusProRebirth * 100)
	)

	local anteil = math.clamp(stand.GesamtVerdient / math.max(1, stand.RebirthSchwelle), 0, 1)
	balkenFuellung.Size = UDim2.new(anteil, 0, 1, 0)
	fortschrittText.Text = ("Gesamtverdienst  %s / %s %s"):format(
		Util.FormatGeld(stand.GesamtVerdient),
		Util.FormatGeld(stand.RebirthSchwelle),
		Config.Spiel.Waehrung
	)

	if stand.KannRebirth then
		local wartetAufBestaetigung = os.clock() < rebirthBestaetigungBis
		rebirthKnopf.BackgroundColor3 = wartetAufBestaetigung and Farben.Warnung or Farben.Gold
		rebirthKnopf.TextColor3 = Color3.fromRGB(20, 14, 0)
		rebirthKnopf.Text = wartetAufBestaetigung
			and "SICHER?  NOCHMAL DRÜCKEN"
			or "REBIRTH DURCHFÜHREN"
	else
		rebirthKnopf.BackgroundColor3 = Farben.Inaktiv
		rebirthKnopf.TextColor3 = Farben.TextGedimmt
		rebirthKnopf.Text = "NOCH " .. Util.FormatGeld(
			math.max(0, stand.RebirthSchwelle - stand.GesamtVerdient)
		) .. " VERDIENEN"
	end

	-- --- Technologie ---
	for _, tech in TechConfig.Technologien do
		local zeile = techZeilen[tech.Id]
		if not zeile then
			continue
		end

		local stufe = stand.Tech[tech.Id] or 0
		local preis = stand.TechPreise[tech.Id]

		-- Stufenanzeige als gefuellte/leere Kaestchen
		local kaestchen = {}
		for i = 1, tech.MaxStufe do
			table.insert(kaestchen, i <= stufe and "■" or "□")
		end
		zeile.Stufen.Text = table.concat(kaestchen, " ")
			.. ("   Stufe %d/%d"):format(stufe, tech.MaxStufe)

		if not preis then
			zeile.Preis.Text = "MAXIMUM"
			zeile.Preis.TextColor3 = Farben.Gut
			zeile.Knopf.Text = "VOLL ERFORSCHT"
			zeile.Knopf.BackgroundColor3 = Farben.Inaktiv
			zeile.Knopf.TextColor3 = Farben.TextGedimmt
		else
			local bezahlbar = geld >= preis
			zeile.Preis.Text = Util.FormatGeld(preis) .. " " .. Config.Spiel.Waehrung
			zeile.Preis.TextColor3 = bezahlbar and Farben.Gut or Farben.Warnung
			zeile.Knopf.Text = "ERFORSCHEN"
			zeile.Knopf.BackgroundColor3 = bezahlbar and Farben.Akzent or Farben.Inaktiv
			zeile.Knopf.TextColor3 = bezahlbar and Color3.fromRGB(8, 16, 24) or Farben.TextGedimmt
		end
	end
end

-- ================================================================
-- SERVER-EREIGNISSE
-- ================================================================
Net:Event("ImperiumUpdate").OnClientEvent:Connect(function(daten)
	local shopGeaendert = daten.Shop ~= nil

	for schluessel, wert in daten do
		stand[schluessel] = wert
	end

	if shopGeaendert then
		baueShop()
	end
	aktualisiere()
end)

Net:Event("DatenUpdate").OnClientEvent:Connect(function(daten)
	if daten.Geld then
		geld = daten.Geld
	end
	if daten.GesamtVerdient then
		stand.GesamtVerdient = daten.GesamtVerdient
	end
	if fenster.Offen then
		aktualisiere()
	end
end)

rebirthKnopf.Activated:Connect(function()
	if not stand.KannRebirth then
		return
	end

	-- Zwei-Klick-Sicherung: Ein Rebirth loescht die ganze Station.
	-- Der erste Klick fragt nach, der zweite fuehrt ihn aus.
	if os.clock() >= rebirthBestaetigungBis then
		rebirthBestaetigungBis = os.clock() + 5
		aktualisiere()
		return
	end

	rebirthBestaetigungBis = 0
	Net:Event("RebirthStarten"):FireServer()
end)

-- ================================================================
-- OEFFNEN
-- ================================================================
fenster.BeimOeffnen = function()
	rebirthBestaetigungBis = 0
	Net:Event("ImperiumAnfrage"):FireServer()
	Net:Event("DatenAnfrage"):FireServer()
	aktualisiere()
end

local knopf = UiKit.LeistenKnopf("IMPERIUM", 30)
knopf.Activated:Connect(function()
	fenster:Umschalten()
end)

zeigeSeite("REBIRTH")
baueShop()
aktualisiere()

task.defer(function()
	Net:Event("ImperiumAnfrage"):FireServer()
end)

print("[ImperiumGui] Imperium bereit")
