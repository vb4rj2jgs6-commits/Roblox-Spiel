--[[
	DropperService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > DropperService

	AUFGABE
	Der passive Geldfluss. Jeder gekaufte Dropper schickt in festen
	Abstaenden eine "Lieferung" zum Sammelkern. Kommt sie an, landet
	der Wert im Lager des Spielers.

	WARUM KEINE ECHTE PHYSIK?
	Klassische Tycoons lassen Parts ueber Foerderbaender rutschen.
	Das sind pro Spieler dutzende unverankerte Parts — auf Handys der
	haeufigste Grund fuer Ruckeln. Wir benutzen stattdessen verankerte
	Parts mit TweenService: sieht praktisch gleich aus, kostet fast
	nichts und kann nicht "steckenbleiben".

	Der WERT einer Lieferung wird beim ABSCHICKEN berechnet:
	    Betrag * Plot-Wert-Upgrades * Spieler-Multiplikator
	Der Spieler-Multiplikator enthaelt Planeten-Boni und Rebirths.
	================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local PlotService = require(script.Parent.PlotService)

local DropperService = {}

-- Sicherheitsgrenze: nie mehr als so viele Lieferungen gleichzeitig
-- pro Plot in der Luft. Schuetzt vor Lag, falls jemand extrem viele
-- Dropper besitzt.
local MAX_LIEFERUNGEN_PRO_PLOT = 40
local FLUGZEIT = 1.1 -- Sekunden von der Duese bis zum Kern

local function sendeLieferung(plot: any, spieler: Player, dropperTyp: any, startPos: Vector3, wert: number)
	if #plot.DropOrdner:GetChildren() >= MAX_LIEFERUNGEN_PRO_PLOT then
		-- Zu viel los: Wert trotzdem gutschreiben, aber ohne Animation.
		CurrencyService:InsLager(spieler, wert)
		return
	end

	local paket = Util.NeuerPart({
		Name = "Lieferung",
		Size = Vector3.new(2.2, 2.2, 2.2),
		Color = dropperTyp.Farbe,
		Material = dropperTyp.Material,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CFrame = CFrame.new(startPos),
	})

	local zielPos = PlotService:ZuWelt(plot, Config.PlotPunkte.Sammelkern) + Vector3.new(0, 8, 0)

	paket.Parent = plot.DropOrdner

	-- Notbremse: Falls der Tween aus irgendeinem Grund nicht fertig wird,
	-- raeumt Debris den Part nach 5 Sekunden weg.
	Debris:AddItem(paket, 5)

	local tween = TweenService:Create(
		paket,
		TweenInfo.new(FLUGZEIT, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{
			CFrame = CFrame.new(zielPos) * CFrame.Angles(math.rad(180), math.rad(180), 0),
			Size = Vector3.new(0.6, 0.6, 0.6),
		}
	)

	tween.Completed:Connect(function(status)
		-- Abgebrochen (z. B. weil der Spieler das Spiel verlassen hat und der
		-- Plot geleert wurde) -> keine Gutschrift.
		if status ~= Enum.PlaybackState.Completed then
			return
		end

		paket:Destroy()

		-- Erst JETZT gibt es Geld — und nur, wenn der Plot noch demselben
		-- Spieler gehoert.
		if plot.Besitzer == spieler and spieler.Parent then
			CurrencyService:InsLager(spieler, wert)
		end
	end)

	tween:Play()
end

function DropperService:Tick()
	local jetzt = os.clock()

	for _, plot in PlotService.Plots do
		local spieler = plot.Besitzer
		if spieler and spieler.Parent and #plot.Dropper > 0 then
			local daten = DataService:Get(spieler)

			if daten then
				local kapazitaet = CurrencyService:GetLagerKapazitaet(spieler)
				local lagerVoll = daten.Lager >= kapazitaet
				local spielerMult = CurrencyService:GetMultiplikator(spieler)

				for _, dropper in plot.Dropper do
					if jetzt >= dropper.NaechsterDrop then
						local typ = Config.DropperTypen[dropper.Typ]

						-- Naechsten Zeitpunkt setzen, auch wenn das Lager voll
						-- ist. Sonst wuerde der Dropper nach dem Einsammeln
						-- alle gestauten Lieferungen auf einmal abfeuern.
						dropper.NaechsterDrop = jetzt + math.max(0.2, typ.Intervall * plot.TempoMult)

						if not lagerVoll then
							local wert = Util.SichererBetrag(typ.Betrag * plot.WertMult * spielerMult)
							if wert > 0 then
								sendeLieferung(plot, spieler, typ, dropper.Duese.Position, wert)
							end
						end
					end
				end
			end
		end
	end
end

-- Auto-Collect: leert das Lager automatisch.
-- Aktiv nur fuer Spieler mit dem entsprechenden Gamepass (Schritt 6).
function DropperService:AutoSammelSchleife()
	while true do
		task.wait(Config.Lager.AutoSammelIntervall)

		for _, spieler in Players:GetPlayers() do
			local daten = DataService:Get(spieler)
			if daten and daten.Gamepasses and daten.Gamepasses.AutoCollect then
				CurrencyService:LagerEinsammeln(spieler)
			end
		end
	end
end

function DropperService:Init()
	RunService.Heartbeat:Connect(function()
		self:Tick()
	end)

	task.spawn(function()
		self:AutoSammelSchleife()
	end)

	if Config.Spiel.DebugAusgaben then
		print("[DropperService] bereit")
	end
end

return DropperService
