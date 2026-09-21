--[[
	CombatService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > CombatService

	AUFGABE
	Angriffe auf Planeten: pruefen, Flotte losschicken, Kampf
	auswerten, Verluste abziehen, Planet uebergeben.

	DIE KAMPFFORMEL (bewusst einfach nachvollziehbar):
	    Siegchance = Staerke / (Staerke + Verteidigung)
	Gleich stark = 50 %. Doppelte Staerke = 67 %.
	Gedeckelt auf 5 % bis 95 % — nichts ist je ganz sicher.

	VERLUSTE
	Auch ein Sieg kostet Schiffe. Wie viele, haengt davon ab, wie
	knapp es war: Einen viel schwaecheren Planeten zu nehmen kostet
	fast nichts, ein Kopf-an-Kopf-Rennen sehr viel.

	EXPLOIT-SCHUTZ
	Der Client schickt nur eine Planeten-Id. Staerke, Verteidigung,
	Wuerfelwurf und Verluste rechnet ausschliesslich der Server. Ein
	Exploiter kann den Angriffsknopf spammen — die Cooldown-Pruefung
	und die "ist schon unterwegs"-Sperre liegen ebenfalls hier.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local PlanetConfig = require(ReplicatedStorage:WaitForChild("PlanetConfig"))
local FleetConfig = require(ReplicatedStorage:WaitForChild("FleetConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local FleetService = require(script.Parent.FleetService)
local PlanetService = require(script.Parent.PlanetService)

local CombatService = {}

-- [Player] = os.clock() des letzten Angriffs
local letzterAngriff: { [Player]: number } = {}
-- [Player] = true, solange eine Flotte unterwegs ist
local imFlug: { [Player]: boolean } = {}

local function melden(spieler: Player, text: string, farbe: string)
	Net:Event("Benachrichtigung"):FireClient(spieler, { Text = text, Farbe = farbe })
end

-- ================================================================
-- FLUG-ANIMATION
-- Ein paar Neon-Parts fliegen von der Station zum Planeten. Rein
-- optisch — der Kampf wird unabhaengig davon ausgerechnet.
-- ================================================================
local function flugAnimation(plot: any, zielPosition: Vector3, dauer: number)
	if not plot then
		return
	end

	local start = PlotService:ZuWelt(plot, Config.PlotPunkte.Orbit)
	local richtung = (zielPosition - start).Unit

	for i = 1, 6 do
		local versatz = Vector3.new(
			math.random(-25, 25),
			math.random(-12, 12),
			math.random(-25, 25)
		)

		local schiff = Util.NeuerPart({
			Name = "Angriffsflotte",
			Size = Vector3.new(3, 1.4, 7),
			Color = Color3.fromRGB(120, 220, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(start + versatz, start + versatz + richtung),
		})
		schiff.Parent = workspace:FindFirstChild("Welt") or workspace

		-- Debris raeumt den Part auf, falls der Tween nie ankommt
		Debris:AddItem(schiff, dauer + 2)

		local ziel = zielPosition + versatz * 1.5
		TweenService:Create(
			schiff,
			TweenInfo.new(dauer * (0.85 + i * 0.03), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(ziel, ziel + richtung) }
		):Play()
	end
end

-- ================================================================
-- VERLUSTE
-- ================================================================

-- Zieht anteilig Schiffe aus allen Klassen ab. Gibt zurueck, wie viele
-- Schiffe insgesamt verloren gingen.
local function flotteReduzieren(daten: any, anteil: number): number
	if anteil <= 0 then
		return 0
	end

	-- Erst sammeln, dann anwenden: Eine Tabelle waehrend der Iteration
	-- zu veraendern ist eine typische Fehlerquelle.
	local aenderungen = {}
	local verloren = 0
	local gesamtVorher = 0

	for klassenId, anzahl in daten.Flotte do
		gesamtVorher += anzahl
		local weg = math.min(anzahl, math.floor(anzahl * anteil + 0.5))
		if weg > 0 then
			aenderungen[klassenId] = anzahl - weg
			verloren += weg
		end
	end

	-- Eine Niederlage ohne jeden Verlust waere unbefriedigend:
	-- Dann faellt mindestens ein Schiff der schwaechsten Klasse.
	if verloren == 0 and gesamtVorher > 0 and anteil > 0.05 then
		local schwaechste = nil
		for klassenId, anzahl in daten.Flotte do
			if anzahl > 0 then
				local klasse = FleetConfig.NachId[klassenId]
				if klasse and (not schwaechste or klasse.Angriff < schwaechste.Angriff) then
					schwaechste = klasse
				end
			end
		end
		if schwaechste then
			aenderungen[schwaechste.Id] = daten.Flotte[schwaechste.Id] - 1
			verloren = 1
		end
	end

	for klassenId, neueAnzahl in aenderungen do
		if neueAnzahl <= 0 then
			daten.Flotte[klassenId] = nil
		else
			daten.Flotte[klassenId] = neueAnzahl
		end
	end

	return verloren
end

-- ================================================================
-- ANGRIFF
-- ================================================================
function CombatService:AngriffStarten(spieler: Player, planetId: any)
	-- 1) Ist die Id ueberhaupt eine Zeichenkette und gibt es den Planeten?
	if type(planetId) ~= "string" then
		return
	end

	local zustand = PlanetService.Planeten[planetId]
	if not zustand then
		return
	end

	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	-- 2) Schon unterwegs?
	if imFlug[spieler] then
		melden(spieler, "Deine Flotte ist bereits unterwegs.", "Warnung")
		return
	end

	-- 3) Gehoert er mir schon?
	if zustand.Besitzer == spieler then
		melden(spieler, zustand.Config.Name .. " gehört dir bereits.", "Warnung")
		return
	end

	-- 4) Cooldown
	local jetzt = os.clock()
	local letzter = letzterAngriff[spieler] or -math.huge
	local restCooldown = PlanetConfig.Kampf.AngriffsCooldown - (jetzt - letzter)
	if restCooldown > 0 then
		melden(spieler, ("Flotte sammelt sich noch — %ds"):format(math.ceil(restCooldown)), "Warnung")
		return
	end

	-- 5) Schutzschild des aktuellen Besitzers
	if PlanetService:HatSchild(planetId) then
		local rest = math.ceil(zustand.SchildBis - jetzt)
		melden(spieler, ("%s ist noch %ds durch ein Schild geschützt."):format(zustand.Config.Name, rest), "Warnung")
		return
	end

	-- 6) Hat er ueberhaupt eine Flotte?
	local staerke = FleetService:GetStaerke(spieler)
	if staerke <= 0 then
		melden(spieler, "Du hast keine Schiffe. Bau zuerst in der Werft.", "Warnung")
		return
	end

	-- Alles geprueft: Flotte startet
	letzterAngriff[spieler] = jetzt
	imFlug[spieler] = true

	local verteidigung = PlanetService:GetVerteidigung(planetId)
	local chance = PlanetConfig.Siegchance(staerke, verteidigung)

	melden(spieler, ("Flotte greift %s an …"):format(zustand.Config.Name), "Gold")
	flugAnimation(PlotService:GetPlot(spieler), zustand.Config.Position, PlanetConfig.Kampf.Reisezeit)

	-- Startmeldung an den Client: Damit kann die GUI den Cooldown und den
	-- "unterwegs"-Zustand korrekt anzeigen. Wichtig: Der Cooldown laeuft ab
	-- dem START, nicht ab dem Kampfergebnis.
	Net:Event("KampfErgebnis"):FireClient(spieler, {
		Phase = "Start",
		PlanetId = planetId,
		PlanetName = zustand.Config.Name,
		Chance = chance,
		Reisezeit = PlanetConfig.Kampf.Reisezeit,
		Cooldown = PlanetConfig.Kampf.AngriffsCooldown,
	})

	-- Der Kampf wird erst nach der Reisezeit ausgewertet.
	task.delay(PlanetConfig.Kampf.Reisezeit, function()
		imFlug[spieler] = nil
		self:Auswerten(spieler, planetId, staerke, verteidigung, chance)
	end)
end

function CombatService:Auswerten(
	spieler: Player,
	planetId: string,
	staerke: number,
	verteidigung: number,
	chance: number
)
	-- Zwischenzeitlich ausgeloggt?
	if not spieler.Parent then
		return
	end

	local daten = DataService:Get(spieler)
	local zustand = PlanetService.Planeten[planetId]
	if not daten or not zustand then
		return
	end

	local gewonnen = math.random() <= chance
	local verteidiger = zustand.Besitzer

	-- Verluste des Angreifers
	local anteil = PlanetConfig.Verlustanteil(staerke, verteidigung, gewonnen)
	local verloren = flotteReduzieren(daten, anteil)

	if gewonnen then
		PlanetService:Zuweisen(spieler, planetId, true)

		melden(spieler, ("%s erobert!  (+50 %% Einkommen)"):format(zustand.Config.Name), "Gold")

		if verteidiger and verteidiger.Parent and verteidiger ~= spieler then
			melden(
				verteidiger,
				("%s hat dir %s abgenommen!"):format(spieler.DisplayName, zustand.Config.Name),
				"Warnung"
			)
		end
	else
		-- Auch eine Niederlage schwaecht die Verteidigung. So ist ein
		-- zweiter Versuch sinnvoll, statt einfach aussichtslos zu sein.
		if not verteidiger then
			zustand.Verteidigung = math.max(
				zustand.Config.Verteidigung * 0.1,
				zustand.Verteidigung - staerke * 0.25
			)
		end

		melden(spieler, ("Angriff auf %s gescheitert."):format(zustand.Config.Name), "Warnung")

		if verteidiger and verteidiger.Parent and verteidiger ~= spieler then
			melden(
				verteidiger,
				("%s hat %s angegriffen — Verteidigung hält!"):format(spieler.DisplayName, zustand.Config.Name),
				"Gut"
			)
		end
	end

	-- Ergebnisfenster fuer den Angreifer
	Net:Event("KampfErgebnis"):FireClient(spieler, {
		Phase = "Ende",
		PlanetId = planetId,
		PlanetName = zustand.Config.Name,
		Gewonnen = gewonnen,
		Staerke = staerke,
		Verteidigung = verteidigung,
		Chance = chance,
		VerloreneSchiffe = verloren,
	})

	-- Flotte und Planetenliste bei allen auffrischen
	FleetService.FlotteGeaendert:Feuern(spieler)
	FleetService:Senden(spieler)
	PlanetService:SendenAnAlle()

	if verteidiger and verteidiger.Parent then
		FleetService:Senden(verteidiger)
	end

	if Config.Spiel.DebugAusgaben then
		print(("[CombatService] %s -> %s | %d vs %d | %.0f%% | %s | -%d Schiffe")
			:format(spieler.Name, planetId, staerke, verteidigung, chance * 100,
				gewonnen and "SIEG" or "NIEDERLAGE", verloren))
	end
end

-- Restlicher Cooldown in Sekunden (fuer die GUI-Anzeige)
function CombatService:GetCooldown(spieler: Player): number
	local letzter = letzterAngriff[spieler]
	if not letzter then
		return 0
	end
	return math.max(0, PlanetConfig.Kampf.AngriffsCooldown - (os.clock() - letzter))
end

function CombatService:Init()
	Net:Event("AngriffStarten").OnServerEvent:Connect(function(spieler, planetId)
		self:AngriffStarten(spieler, planetId)
	end)

	Players.PlayerRemoving:Connect(function(spieler)
		letzterAngriff[spieler] = nil
		imFlug[spieler] = nil
	end)

	if Config.Spiel.DebugAusgaben then
		print("[CombatService] bereit")
	end
end

return CombatService
