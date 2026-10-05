--[[
	PlotService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > PlotService

	AUFGABE
	1. Baut beim Serverstart alle Plot-Plattformen per Code auf
	2. Weist jedem beitretenden Spieler automatisch einen freien Plot zu
	3. Baut gekaufte Objekte (Dropper, Upgrades, Lager) auf dem Plot auf
	4. Gibt den Plot beim Verlassen wieder frei

	WARUM PER CODE STATT IM STUDIO BAUEN?
	- Du musst nichts von Hand duplizieren und ausrichten
	- Aenderungen an der Config wirken sofort
	- Der Aufbau ist immer identisch -> keine vergessenen Parts

	Wenn du spaeter eigene Modelle bauen willst: lege sie in
	ServerStorage > Vorlagen und ersetze die "Baue..."-Funktionen
	durch :Clone(). Die restliche Logik bleibt gleich.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))
local Signal = require(ReplicatedStorage:WaitForChild("Signal"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)

local PlotService = {}

-- Laufzeit-Zustand aller Plots. Index = Plot-Nummer.
PlotService.Plots = {} :: { any }

-- [Player] = Plot-Tabelle
local spielerPlot: { [Player]: any } = {}

-- Signale: werden gefeuert, sobald ein Spieler einen Plot bekommt bzw.
-- verliert. Andere Services (z. B. ButtonService) haengen sich hier an,
-- statt dass PlotService sie kennen muss -> keine zirkulaeren require()-Ketten.
PlotService.Zugewiesen = Signal.neu()
PlotService.Freigegeben = Signal.neu()
PlotService.ObjektGebaut = Signal.neu()

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[PlotService]", ...)
	end
end

-- Schneller Zugriff auf einen Kaufbares-Eintrag ueber seine Id
local kaufbaresNachId: { [string]: any } = {}
for _, eintrag in Config.Kaufbares do
	kaufbaresNachId[eintrag.Id] = eintrag
end
PlotService.KaufbaresNachId = kaufbaresNachId

-- ================================================================
-- GEOMETRIE-HELFER
-- ================================================================

-- Rechnet eine lokale Plot-Koordinate in eine Weltkoordinate um.
function PlotService:ZuWelt(plot: any, lokal: Vector3): Vector3
	return plot.Ursprung:PointToWorldSpace(lokal)
end

-- Wie ZuWelt, aber fuer ganze CFrames — also MIT Drehung.
-- Das ist der wichtigere der beiden Helfer: Weil die Stationen im Ring
-- stehen, ist jede anders gedreht. Wer nur die Position umrechnet und
-- CFrame.new(position) benutzt, baut eckige Teile schief zur Plattform.
--
-- REGEL: Alles, was eine erkennbare Vorderseite oder rechte Winkel hat,
-- wird mit ZuWeltCF gesetzt. Nur Kugeln und zufaellig gedrehtes Zeug
-- duerfen ZuWelt benutzen.
function PlotService:ZuWeltCF(plot: any, lokal: CFrame): CFrame
	return plot.Ursprung * lokal
end

-- Ursprung (Position + Drehung) der Station Nummer `index`.
local function plotUrsprung(index: number): CFrame
	local hoehe = Config.Plot.Hoehe

	if Config.Plot.Anordnung == "Ring" then
		local winkel = (index - 1) / Config.Plot.Anzahl * math.pi * 2
		local radius = Config.Plot.RingRadius
		local zentrum = Vector3.new(
			math.cos(winkel) * radius,
			hoehe,
			math.sin(winkel) * radius
		)

		-- Die Station soll zur Zentralstation "schauen": Wir richten sie
		-- vom Mittelpunkt WEG aus. CFrame.lookAt legt die LookVector
		-- (also -Z) auf das Ziel — damit zeigt +Z nach innen, und die
		-- lokale Koordinate z = +48 (der Spawn) liegt auf der Innenseite.
		local wegVomZentrum = (zentrum - Vector3.new(0, hoehe, 0)).Unit
		return CFrame.lookAt(zentrum, zentrum + wegVomZentrum)
	end

	-- Anordnung "Raster": schlichtes Gitter, alle gleich gedreht
	local proReihe = Config.Plot.ProReihe
	local reihen = math.ceil(Config.Plot.Anzahl / proReihe)
	local spalte = (index - 1) % proReihe
	local reihe = (index - 1) // proReihe

	return CFrame.new(
		(spalte - (proReihe - 1) / 2) * Config.Plot.Abstand,
		hoehe,
		(reihe - (reihen - 1) / 2) * Config.Plot.Abstand
	)
end

-- ================================================================
-- PLOT AUFBAUEN
-- ================================================================
local function baueRahmen(plot: any)
	local groesse = Config.Plot.Groesse
	local halbeBreite = groesse.X / 2
	local halbeTiefe = groesse.Z / 2

	-- ---------- Hauptdeck ----------
	-- Die Oberflaeche liegt genau auf Config.Plot.Hoehe, damit alles
	-- andere mit y = 0 rechnen kann.
	local boden = Util.NeuerPart({
		Name = "Basis",
		Size = groesse,
		Color = Config.Plot.BodenFarbe,
		Material = Enum.Material.Metal,
		CFrame = PlotService:ZuWeltCF(plot, CFrame.new(0, -groesse.Y / 2, 0)),
	})
	boden.Parent = plot.Model
	plot.Model.PrimaryPart = boden

	-- ---------- Bodenplatten ----------
	-- Ein durchgehendes Rechteck sieht aus wie ein Platzhalter. Vier
	-- etwas hellere Platten mit Fugen dazwischen lassen die Station
	-- sofort nach gebautem Deck aussehen — vier Teile fuer viel Wirkung.
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local platte = Util.NeuerPart({
				Name = "Deckplatte",
				Size = Vector3.new(halbeBreite - 4, 0.4, halbeTiefe - 4),
				Color = Config.Plot.DeckFarbe,
				Material = Enum.Material.Metal,
				CanQuery = false,
				CanTouch = false,
				CFrame = PlotService:ZuWeltCF(
					plot,
					CFrame.new(x * (halbeBreite / 2 + 1), 0.2, z * (halbeTiefe / 2 + 1))
				),
			})
			platte.Parent = plot.Model
		end
	end

	-- ---------- Arbeitszonen ----------
	-- Dunkle Streifen unter den Bauplaetzen. Sie fuehren das Auge und
	-- machen klar: links wird produziert, rechts aufgeruestet.
	local zonen = {
		{ Size = Vector3.new(26, 0.2, 108), Offset = Vector3.new(-40, 0.45, 0) },
		{ Size = Vector3.new(26, 0.2, 90), Offset = Vector3.new(40, 0.45, 0) },
		{ Size = Vector3.new(70, 0.2, 22), Offset = Vector3.new(0, 0.45, -34) },
	}
	for i, zone in zonen do
		local part = Util.NeuerPart({
			Name = "Zone" .. i,
			Size = zone.Size,
			Color = Config.Plot.ZonenFarbe,
			Material = Enum.Material.Metal,
			CanQuery = false,
			CanTouch = false,
			CFrame = PlotService:ZuWeltCF(plot, CFrame.new(zone.Offset)),
		})
		part.Parent = plot.Model
	end

	-- ---------- Neon-Kanten ----------
	local kanten = {
		{ Size = Vector3.new(groesse.X, 0.6, 2), Offset = Vector3.new(0, 0.3, halbeTiefe) },
		{ Size = Vector3.new(groesse.X, 0.6, 2), Offset = Vector3.new(0, 0.3, -halbeTiefe) },
		{ Size = Vector3.new(2, 0.6, groesse.Z), Offset = Vector3.new(halbeBreite, 0.3, 0) },
		{ Size = Vector3.new(2, 0.6, groesse.Z), Offset = Vector3.new(-halbeBreite, 0.3, 0) },
	}
	for i, kante in kanten do
		local part = Util.NeuerPart({
			Name = "Kante" .. i,
			Size = kante.Size,
			Color = Config.Plot.RandFarbe,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = PlotService:ZuWeltCF(plot, CFrame.new(kante.Offset)),
		})
		part.Parent = plot.Model
	end

	-- ---------- Unterbau ----------
	-- Eine schwebende Platte sieht nach nichts aus. Vier Streben nach
	-- unten und ein leuchtender Reaktorkern darunter geben ihr Masse —
	-- und man sieht es von jedem Nachbar-Plot aus.
	for _, ecke in { Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		local strebe = Util.NeuerPart({
			Name = "Strebe",
			Size = Vector3.new(9, 34, 9),
			Color = Config.Plot.StrebenFarbe,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = PlotService:ZuWeltCF(
				plot,
				CFrame.new(ecke.X * (halbeBreite - 14), -19, ecke.Y * (halbeTiefe - 14))
					* CFrame.Angles(math.rad(ecke.Y * 6), 0, math.rad(-ecke.X * 6))
			),
		})
		strebe.Parent = plot.Model
	end

	local reaktor = Util.NeuerPart({
		Name = "Reaktorkern",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(30, 30, 30),
		Color = Config.Plot.RandFarbe,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = PlotService:ZuWeltCF(plot, CFrame.new(0, -34, 0)),
	})
	reaktor.Parent = plot.Model

	local reaktorLicht = Instance.new("PointLight")
	reaktorLicht.Brightness = 2
	reaktorLicht.Range = 60
	reaktorLicht.Color = Config.Plot.RandFarbe
	reaktorLicht.Parent = reaktor
end

-- Blinkende Positionslichter an den vier Ecken. Mobilfreundlich:
-- Die Teile sind verankert, nur die Transparenz wird animiert.
local function baueBaken(plot: any)
	local groesse = Config.Plot.Groesse
	local ecken = {
		Vector2.new(1, 1), Vector2.new(1, -1),
		Vector2.new(-1, 1), Vector2.new(-1, -1),
	}

	plot.Baken = {}

	for i, ecke in ecken do
		local mast = Util.NeuerPart({
			Name = "Bakenmast",
			Size = Vector3.new(1.4, 9, 1.4),
			Color = Config.Plot.StrebenFarbe,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = PlotService:ZuWeltCF(
				plot,
				CFrame.new(ecke.X * (groesse.X / 2 - 4), 4.5, ecke.Y * (groesse.Z / 2 - 4))
			),
		})
		mast.Parent = plot.Model

		local lampe = Util.NeuerPart({
			Name = "Bake" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			Color = Color3.fromRGB(255, 120, 110),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = PlotService:ZuWeltCF(
				plot,
				CFrame.new(ecke.X * (groesse.X / 2 - 4), 10, ecke.Y * (groesse.Z / 2 - 4))
			),
		})
		lampe.Parent = plot.Model
		table.insert(plot.Baken, lampe)
	end
end

-- Steg zur Zentralstation. Nur im Ring-Modus — im Raster gibt es kein
-- Zentrum, zu dem er fuehren koennte.
local function baueBruecke(plot: any)
	if Config.Plot.Anordnung ~= "Ring" or not Config.Welt.Zentralstation.Aktiv then
		return
	end

	local halbeTiefe = Config.Plot.Groesse.Z / 2
	local innenKante = Config.Plot.RingRadius - halbeTiefe
	local stationsRand = Config.Welt.Zentralstation.Radius
	local laenge = innenKante - stationsRand

	if laenge <= 8 then
		return
	end

	-- Der Steg liegt auf der Innenseite (lokal +Z zeigt zum Zentrum).
	local mitte = halbeTiefe + laenge / 2
	local breite = Config.Plot.BrueckeBreite

	local steg = Util.NeuerPart({
		Name = "Bruecke",
		Size = Vector3.new(breite, 1.2, laenge),
		Color = Config.Plot.DeckFarbe,
		Material = Enum.Material.Metal,
		CFrame = PlotService:ZuWeltCF(plot, CFrame.new(0, -0.6, mitte)),
	})
	steg.Parent = plot.Model

	-- Zwei Leuchtstreifen als Geländer-Ersatz. Sie sind nicht begehbar
	-- und nicht kollidierend — man kann also runterfallen, das gehoert
	-- bei einer Raumstation dazu.
	for _, seite in { -1, 1 } do
		local streifen = Util.NeuerPart({
			Name = "Brueckenkante",
			Size = Vector3.new(1.2, 1.6, laenge),
			Color = Config.Plot.RandFarbe,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = PlotService:ZuWeltCF(
				plot,
				CFrame.new(seite * (breite / 2 - 0.6), 0.2, mitte)
			),
		})
		streifen.Parent = plot.Model
	end
end

local function baueSchild(plot: any)
	local saeule = Util.NeuerPart({
		Name = "Schildsaeule",
		Size = Vector3.new(3, 14, 3),
		Color = Color3.fromRGB(60, 65, 85),
		Material = Enum.Material.Metal,
		CFrame = PlotService:ZuWeltCF(plot, CFrame.new(0, 7, -56)),
	})
	saeule.Parent = plot.Model

	local tafel = Instance.new("BillboardGui")
	tafel.Name = "Besitzer"
	tafel.Size = UDim2.fromScale(16, 4)
	tafel.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
	tafel.AlwaysOnTop = false
	tafel.MaxDistance = 300
	tafel.Parent = saeule

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Config.Plot.FreiFarbe
	text.TextStrokeTransparency = 0.4
	text.Text = "FREIE STATION"
	text.Parent = tafel

	plot.SchildText = text
end

local function baueSammelkern(plot: any)
	local kernOrdner = Instance.new("Model")
	kernOrdner.Name = "Sammelkern"
	kernOrdner.Parent = plot.Model

	local lokal = Config.PlotPunkte.Sammelkern
	local basisPos = PlotService:ZuWelt(plot, lokal)

	local pad = Util.NeuerPart({
		Name = "Pad",
		Size = Vector3.new(26, 1, 26),
		Color = Color3.fromRGB(28, 32, 48),
		Material = Enum.Material.Metal,
		CFrame = PlotService:ZuWeltCF(plot, CFrame.new(lokal + Vector3.new(0, 0.5, 0))),
	})
	pad.Parent = kernOrdner

	local ring = Util.NeuerPart({
		Name = "Ring",
		Size = Vector3.new(20, 0.4, 20),
		Color = Config.Plot.RandFarbe,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = PlotService:ZuWeltCF(plot, CFrame.new(lokal + Vector3.new(0, 1.2, 0))),
	})
	ring.Parent = kernOrdner

	-- Drei Traegerboegen um den Kern. Sie machen aus dem flachen Pad eine
	-- Anlage und rahmen den schwebenden Kristall ein.
	for i = 1, 3 do
		local winkel = (i - 1) / 3 * math.pi * 2
		local bogen = Util.NeuerPart({
			Name = "Traeger" .. i,
			Size = Vector3.new(2, 15, 2),
			Color = Config.Plot.StrebenFarbe,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = PlotService:ZuWeltCF(
				plot,
				CFrame.new(lokal + Vector3.new(math.cos(winkel) * 9, 7, math.sin(winkel) * 9))
					* CFrame.Angles(math.rad(math.sin(winkel) * 18), 0, math.rad(-math.cos(winkel) * 18))
			),
		})
		bogen.Parent = kernOrdner
	end

	-- Der schwebende Kristall, auf den die Lieferungen zufliegen
	local kern = Util.NeuerPart({
		Name = "Kern",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7),
		Color = Color3.fromRGB(120, 230, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(basisPos + Vector3.new(0, 8, 0)),
	})
	kern.Parent = kernOrdner

	local licht = Instance.new("PointLight")
	licht.Brightness = 3
	licht.Range = 26
	licht.Color = Color3.fromRGB(120, 230, 255)
	licht.Parent = kern

	local anzeige = Instance.new("BillboardGui")
	anzeige.Name = "LagerAnzeige"
	anzeige.Size = UDim2.fromScale(14, 3.5)
	anzeige.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	anzeige.MaxDistance = 250
	anzeige.Parent = kern

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(180, 245, 255)
	text.TextStrokeTransparency = 0.3
	text.Text = "LAGER"
	text.Parent = anzeige

	plot.Kern = kern
	plot.KernPad = pad
	plot.LagerText = text

	-- Beruehren = Lager einsammeln (der Klassiker im Tycoon-Genre)
	pad.Touched:Connect(function(getroffen)
		local charakter = getroffen:FindFirstAncestorOfClass("Model")
		if not charakter then
			return
		end
		local spieler = Players:GetPlayerFromCharacter(charakter)
		if not spieler or spielerPlot[spieler] ~= plot then
			return
		end
		PlotService:LagerEinsammeln(spieler)
	end)
end

-- Die Werft: Gebaeude, an dem der Spieler die Flotten-GUI oeffnet.
-- Sie ist nicht kaufbar, sondern von Anfang an da — sonst haette der
-- Spieler keinen Zugang zum Flotten-System.
local function baueWerft(plot: any)
	local lokal = Config.PlotPunkte.Werft

	-- Kurzschreibweise: wandelt einen lokalen Versatz zur Werft in einen
	-- Welt-CFrame um — inklusive der Drehung der Station.
	local function cf(versatz: Vector3, drehung: CFrame?): CFrame
		local basis = CFrame.new(lokal + versatz)
		return PlotService:ZuWeltCF(plot, drehung and basis * drehung or basis)
	end

	local model = Instance.new("Model")
	model.Name = "Werft"
	model.Parent = plot.Model

	local plattform = Util.NeuerPart({
		Name = "Plattform",
		Size = Vector3.new(18, 2, 18),
		Color = Color3.fromRGB(44, 50, 70),
		Material = Enum.Material.Metal,
		CFrame = cf(Vector3.new(0, 1, 0)),
	})
	plattform.Parent = model

	-- Zwei Streben mit einem Neon-Bogen dazwischen
	for _, seite in { -1, 1 } do
		local strebe = Util.NeuerPart({
			Name = "Strebe",
			Size = Vector3.new(1.6, 16, 1.6),
			Color = Color3.fromRGB(62, 70, 94),
			Material = Enum.Material.Metal,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = cf(Vector3.new(seite * 7, 10, 0)),
		})
		strebe.Parent = model
	end

	local bogen = Util.NeuerPart({
		Name = "Bogen",
		Size = Vector3.new(15.6, 1.2, 2.4),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = cf(Vector3.new(0, 18, 0)),
	})
	bogen.Parent = model

	-- Die Konsole, an der man die Werft oeffnet
	local konsole = Util.NeuerPart({
		Name = "Konsole",
		Size = Vector3.new(5, 4, 2.4),
		Color = Color3.fromRGB(30, 36, 52),
		Material = Enum.Material.Metal,
		CFrame = cf(Vector3.new(0, 4, 6), CFrame.Angles(math.rad(-18), 0, 0)),
	})
	konsole.Parent = model

	-- ProximityPrompt = die Taste, die eingeblendet wird, wenn man nah dran
	-- steht (auf dem Handy ein antippbarer Knopf). Das Oeffnen der GUI
	-- passiert komplett auf dem Client — dafuer braucht es kein RemoteEvent.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WerftPrompt"
	prompt.ActionText = "Werft öffnen"
	prompt.ObjectText = "Raumwerft"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = konsole

	-- Ein "Tag" ist eine Markierung, nach der man spaeter suchen kann.
	-- Der Client holt sich damit alle Werft-Konsolen, ohne den Explorer
	-- durchsuchen zu muessen.
	CollectionService:AddTag(prompt, "WerftPrompt")

	local schild = Instance.new("BillboardGui")
	schild.Name = "Beschriftung"
	schild.Size = UDim2.fromScale(14, 3)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	schild.MaxDistance = 220
	schild.Parent = bogen

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(180, 225, 255)
	text.TextStrokeTransparency = 0.35
	text.Text = "RAUMWERFT"
	text.Parent = schild

	plot.WerftModel = model
end

local function baueSpawnPad(plot: any)
	local pad = Util.NeuerPart({
		Name = "SpawnPad",
		Size = Vector3.new(16, 0.6, 16),
		Color = Color3.fromRGB(70, 255, 160),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = PlotService:ZuWeltCF(
			plot,
			CFrame.new(Config.PlotPunkte.Spawn + Vector3.new(0, 0.3, 0))
		),
	})
	pad.Parent = plot.Model
	plot.SpawnPad = pad
end

function PlotService:PlotErstellen(index: number)
	local ursprung = plotUrsprung(index)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local plot = {
		Index = index,
		Model = model,
		Zentrum = ursprung.Position,
		Ursprung = ursprung,
		Besitzer = nil :: Player?,

		-- Laufzeitwerte, werden von NeuBerechnen gesetzt
		Dropper = {},        -- Liste aktiver Dropper
		WertMult = 1,
		TempoMult = 1,
	}

	baueRahmen(plot)
	baueBaken(plot)
	baueBruecke(plot)
	baueSchild(plot)
	baueSammelkern(plot)
	baueSpawnPad(plot)
	baueWerft(plot)

	local gebaeude = Instance.new("Folder")
	gebaeude.Name = "Gebaeude"
	gebaeude.Parent = model
	plot.GebaeudeOrdner = gebaeude

	local buttons = Instance.new("Folder")
	buttons.Name = "Buttons"
	buttons.Parent = model
	plot.ButtonOrdner = buttons

	local drops = Instance.new("Folder")
	drops.Name = "Lieferungen"
	drops.Parent = model
	plot.DropOrdner = drops

	model.Parent = self.PlotOrdner
	self.Plots[index] = plot
	return plot
end

-- ================================================================
-- OBJEKTE AUF DEM PLOT BAUEN
-- ================================================================
local function baueDropper(plot: any, eintrag: any)
	local typ = Config.DropperTypen[eintrag.DropperTyp]

	local function cf(versatz: Vector3): CFrame
		return PlotService:ZuWeltCF(plot, CFrame.new(eintrag.Position + versatz))
	end

	local model = Instance.new("Model")
	model.Name = eintrag.Id
	model.Parent = plot.GebaeudeOrdner

	local sockel = Util.NeuerPart({
		Name = "Sockel",
		Size = Vector3.new(10, 6, 10),
		Color = Color3.fromRGB(52, 58, 78),
		Material = Enum.Material.Metal,
		CFrame = cf(Vector3.new(0, 3, 0)),
	})
	sockel.Parent = model

	local turm = Util.NeuerPart({
		Name = "Turm",
		Size = Vector3.new(5, 8, 5),
		Color = Color3.fromRGB(70, 78, 102),
		Material = Enum.Material.Metal,
		CFrame = cf(Vector3.new(0, 10, 0)),
	})
	turm.Parent = model

	local duese = Util.NeuerPart({
		Name = "Duese",
		Size = Vector3.new(6.5, 1.6, 6.5),
		Color = typ.Farbe,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = cf(Vector3.new(0, 14.5, 0)),
	})
	duese.Parent = model

	local schild = Instance.new("BillboardGui")
	schild.Size = UDim2.fromScale(10, 2.2)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	schild.MaxDistance = 160
	schild.Parent = duese

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = typ.Farbe
	text.TextStrokeTransparency = 0.4
	text.Text = typ.Name
	text.Parent = schild

	-- Laufzeit-Eintrag fuer den DropperService
	table.insert(plot.Dropper, {
		Id = eintrag.Id,
		Typ = eintrag.DropperTyp,
		Duese = duese,
		-- Leicht versetzter Start, damit nicht alle Dropper gleichzeitig feuern
		NaechsterDrop = os.clock() + math.random() * typ.Intervall,
	})

	return model
end

local function baueModul(plot: any, eintrag: any, farbe: Color3, beschriftung: string)
	local function cf(versatz: Vector3, drehung: CFrame?): CFrame
		local basis = CFrame.new(eintrag.Position + versatz)
		return PlotService:ZuWeltCF(plot, drehung and basis * drehung or basis)
	end

	local model = Instance.new("Model")
	model.Name = eintrag.Id
	model.Parent = plot.GebaeudeOrdner

	local sockel = Util.NeuerPart({
		Name = "Sockel",
		Size = Vector3.new(11, 5, 11),
		Color = Color3.fromRGB(48, 54, 74),
		Material = Enum.Material.Metal,
		CFrame = cf(Vector3.new(0, 2.5, 0)),
	})
	sockel.Parent = model

	local kristall = Util.NeuerPart({
		Name = "Kristall",
		Size = Vector3.new(5, 7, 5),
		Color = farbe,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = cf(Vector3.new(0, 8.5, 0), CFrame.Angles(0, math.rad(45), 0)),
	})
	kristall.Parent = model

	local schild = Instance.new("BillboardGui")
	schild.Size = UDim2.fromScale(11, 2.2)
	schild.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	schild.MaxDistance = 160
	schild.Parent = kristall

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = farbe
	text.TextStrokeTransparency = 0.4
	text.Text = beschriftung
	text.Parent = schild

	return model
end

-- Baut EIN gekauftes Objekt. Wird beim Kauf und beim Laden des
-- Spielstands aufgerufen.
function PlotService:BaueObjekt(plot: any, eintrag: any)
	-- Doppelt bauen verhindern (z. B. bei doppeltem Touch-Event)
	if plot.GebaeudeOrdner:FindFirstChild(eintrag.Id) then
		return
	end

	if eintrag.Typ == "Dropper" then
		baueDropper(plot, eintrag)
	elseif eintrag.Typ == "Upgrade" then
		local istTempo = eintrag.Wirkung.TempoMultiplikator ~= nil
		baueModul(
			plot,
			eintrag,
			istTempo and Color3.fromRGB(120, 255, 180) or Color3.fromRGB(255, 200, 90),
			istTempo and "TEMPO" or "WERT"
		)
	elseif eintrag.Typ == "Lager" then
		baueModul(plot, eintrag, Color3.fromRGB(150, 180, 255), "LAGER")
	end

	self.ObjektGebaut:Feuern(plot, eintrag)
end

-- Rechnet die Plot-Multiplikatoren aus allen gekauften Upgrades neu aus.
-- Immer aufrufen, wenn sich "Gekauft" aendert.
function PlotService:NeuBerechnen(plot: any)
	local spieler = plot.Besitzer
	if not spieler then
		plot.WertMult, plot.TempoMult = 1, 1
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	local wert, tempo = 1, 1
	for _, eintrag in Config.Kaufbares do
		if daten.Gekauft[eintrag.Id] and eintrag.Wirkung then
			if eintrag.Wirkung.WertMultiplikator then
				wert *= eintrag.Wirkung.WertMultiplikator
			end
			if eintrag.Wirkung.TempoMultiplikator then
				tempo *= eintrag.Wirkung.TempoMultiplikator
			end
		end
	end

	plot.WertMult = wert
	plot.TempoMult = tempo
end

-- ================================================================
-- ZUWEISUNG / FREIGABE
-- ================================================================
function PlotService:GetPlot(spieler: Player)
	return spielerPlot[spieler]
end

function PlotService:LagerEinsammeln(spieler: Player): number
	local betrag = CurrencyService:LagerEinsammeln(spieler)
	return betrag
end

local function plotLeeren(plot: any)
	plot.GebaeudeOrdner:ClearAllChildren()
	plot.ButtonOrdner:ClearAllChildren()
	plot.DropOrdner:ClearAllChildren()
	table.clear(plot.Dropper)
	plot.WertMult = 1
	plot.TempoMult = 1
end

function PlotService:Zuweisen(spieler: Player): any?
	if spielerPlot[spieler] then
		return spielerPlot[spieler]
	end

	for _, plot in self.Plots do
		if not plot.Besitzer then
			plot.Besitzer = spieler
			spielerPlot[spieler] = plot

			plot.SchildText.Text = string.upper(spieler.DisplayName) .. "\nSTATION " .. plot.Index
			plot.SchildText.TextColor3 = Config.Plot.RandFarbe

			-- Bereits gekaufte Objekte aus dem Spielstand wieder aufbauen
			local daten = DataService:Get(spieler)
			if daten then
				for _, eintrag in Config.Kaufbares do
					if daten.Gekauft[eintrag.Id] then
						self:BaueObjekt(plot, eintrag)
					end
				end
			end

			self:NeuBerechnen(plot)
			self.Zugewiesen:FeuernSofort(spieler, plot)
			log(spieler.Name .. " -> Plot " .. plot.Index)
			return plot
		end
	end

	warn("[PlotService] Kein freier Plot fuer " .. spieler.Name .. " (Config.Plot.Anzahl erhoehen?)")
	return nil
end

function PlotService:Freigeben(spieler: Player)
	local plot = spielerPlot[spieler]
	if not plot then
		return
	end

	self.Freigegeben:FeuernSofort(spieler, plot)

	plotLeeren(plot)
	plot.Besitzer = nil
	plot.SchildText.Text = "FREIE STATION"
	plot.SchildText.TextColor3 = Config.Plot.FreiFarbe
	plot.LagerText.Text = "LAGER"
	spielerPlot[spieler] = nil

	log("Plot " .. plot.Index .. " freigegeben")
end

-- Baut den Plot komplett neu aus dem Spielstand auf.
-- Wird beim Rebirth gebraucht: erst wird der Spielstand zurueckgesetzt,
-- dann raeumt diese Funktion die Station leer und stellt sie wieder her.
-- Das Zugewiesen-Signal am Ende laesst ButtonService, HangarService und
-- ImperiumService ihre Teile ebenfalls neu aufbauen.
function PlotService:NeuAufbauen(spieler: Player)
	local plot = spielerPlot[spieler]
	if not plot then
		return
	end

	plotLeeren(plot)

	local daten = DataService:Get(spieler)
	if daten then
		for _, eintrag in Config.Kaufbares do
			if daten.Gekauft[eintrag.Id] then
				self:BaueObjekt(plot, eintrag)
			end
		end
	end

	self:NeuBerechnen(plot)
	self.Zugewiesen:FeuernSofort(spieler, plot)
end

-- Setzt den Spieler auf sein Spawn-Pad.
function PlotService:ZumPlotTeleportieren(spieler: Player)
	local plot = spielerPlot[spieler]
	local charakter = spieler.Character
	if not plot or not charakter then
		return
	end

	local wurzel = charakter:FindFirstChild("HumanoidRootPart")
	if not wurzel then
		return
	end

	-- Blickrichtung aus der Drehung der Station ableiten: Der Spieler soll
	-- auf seine Anlage schauen (lokal -Z), nicht in eine feste Weltrichtung.
	-- Mit der Ring-Anordnung ist jede Station anders gedreht.
	local ziel = self:ZuWeltCF(
		plot,
		CFrame.new(Config.PlotPunkte.Spawn + Vector3.new(0, 5, 0))
	)
	charakter:PivotTo(CFrame.lookAt(ziel.Position, ziel.Position + ziel.LookVector))
end

-- ================================================================
-- INIT
-- ================================================================
-- Der "Sammeln"-Knopf in der GUI. Auch hier gilt: Der Client sagt nur
-- "ich moechte sammeln", der Server entscheidet.
function PlotService:SammelAnfrageBehandeln(spieler: Player)
	local plot = spielerPlot[spieler]
	if not plot then
		return
	end

	local charakter = spieler.Character
	if not charakter then
		return
	end

	local wurzel = charakter:FindFirstChild("HumanoidRootPart")
	if not wurzel or not wurzel:IsA("BasePart") then
		return
	end

	-- Abstandspruefung: Der Spieler muss wirklich in der Naehe seines
	-- Sammelkerns stehen. Sonst koennte man von ueberall aus abkassieren.
	local kernPos = self:ZuWelt(plot, Config.PlotPunkte.Sammelkern)
	if (wurzel.Position - kernPos).Magnitude > Config.Lager.SammelReichweite then
		return
	end

	self:LagerEinsammeln(spieler)
end

function PlotService:Init(welt: Folder)
	local ordner = Instance.new("Folder")
	ordner.Name = "Plots"
	ordner.Parent = welt
	self.PlotOrdner = ordner

	for i = 1, Config.Plot.Anzahl do
		self:PlotErstellen(i)
	end
	log(Config.Plot.Anzahl .. " Plots gebaut")

	Net:Event("SammelAnfrage").OnServerEvent:Connect(function(spieler)
		self:SammelAnfrageBehandeln(spieler)
	end)

	-- Schwebender, drehender Sammelkern + Lageranzeige.
	-- Eine einzige Schleife fuer alle Plots ist viel guenstiger als
	-- eine Schleife pro Plot.
	task.spawn(function()
		local letzteTextaktualisierung = 0

		while true do
			local jetzt = os.clock()
			local textUpdate = (jetzt - letzteTextaktualisierung) >= 0.25
			if textUpdate then
				letzteTextaktualisierung = jetzt
			end

			-- Positionslichter blinken im Takt. Ein Wert fuer alle Baken,
			-- damit die Stationen synchron pulsieren.
			local bakenTransparenz = (math.sin(jetzt * 2.2) > 0) and 0 or 0.75

			for _, plot in self.Plots do
				local basis = self:ZuWelt(plot, Config.PlotPunkte.Sammelkern)
				plot.Kern.CFrame = CFrame.new(basis + Vector3.new(0, 8 + math.sin(jetzt * 1.5) * 0.8, 0))
					* CFrame.Angles(0, jetzt * 0.8, 0)

				if plot.Baken then
					for _, bake in plot.Baken do
						bake.Transparency = bakenTransparenz
					end
				end

				if textUpdate and plot.Besitzer then
					local daten = DataService:Get(plot.Besitzer)
					if daten then
						local kapazitaet = CurrencyService:GetLagerKapazitaet(plot.Besitzer)
						local voll = daten.Lager >= kapazitaet
						plot.LagerText.Text = string.format(
							"%s / %s%s",
							Util.FormatGeld(daten.Lager),
							Util.FormatGeld(kapazitaet),
							voll and "  (VOLL!)" or ""
						)
						plot.LagerText.TextColor3 = voll
							and Color3.fromRGB(255, 120, 120)
							or Color3.fromRGB(180, 245, 255)
					end
				end
			end

			RunService.Heartbeat:Wait()
		end
	end)

	log("bereit")
end

return PlotService
