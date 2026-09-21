--[[
	MonetizationService  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ServerScriptService > Services > MonetizationService

	AUFGABE
	Gamepasses pruefen und Entwicklerprodukte abwickeln.

	SOLANGE DU NOCH KEINE IDS HAST:
	In TechConfig stehen alle Ids auf 0. Dieser Service ueberspringt
	dann einfach alles — das Spiel laeuft ganz normal, im Shop steht
	"noch nicht verfügbar". Du kannst also in Ruhe erst fertig bauen
	und die Monetarisierung spaeter nachziehen.

	WARUM ProcessReceipt SO WICHTIG IST:
	Roblox ruft diese Funktion auf, wenn jemand ein Produkt kauft.
	Gibt sie NICHT PurchaseGranted zurueck, versucht Roblox es spaeter
	erneut — der Spieler bekommt seine Ware also auch dann, wenn der
	Server mitten im Kauf abstuerzt. Genau darum darf man hier NIE
	einfach "true" zurueckgeben, ohne die Ware wirklich gutzuschreiben.
	================================================================
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local TechConfig = require(ReplicatedStorage:WaitForChild("TechConfig"))
local Util = require(ReplicatedStorage:WaitForChild("Util"))
local Net = require(ReplicatedStorage:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local CurrencyService = require(script.Parent.CurrencyService)
local DropperService = require(script.Parent.DropperService)
local FleetService = require(script.Parent.FleetService)

local MonetizationService = {}

local function log(...)
	if Config.Spiel.DebugAusgaben then
		print("[MonetizationService]", ...)
	end
end

-- ================================================================
-- GAMEPASSES
-- ================================================================

-- Fragt alle Gamepasses ab und schreibt das Ergebnis in den Spielstand.
-- Der Cache im Spielstand sorgt dafuer, dass andere Services nicht bei
-- jeder Geldberechnung eine Web-Anfrage ausloesen.
function MonetizationService:GamepassesPruefen(spieler: Player)
	local daten = DataService:Get(spieler)
	if not daten then
		return
	end

	daten.Gamepasses = daten.Gamepasses or {}

	for _, pass in TechConfig.Gamepasses do
		if pass.Id ~= 0 then
			-- pcall, weil die Abfrage uebers Internet geht und
			-- fehlschlagen kann. Ein Fehler darf den Beitritt nicht stoppen.
			local erfolg, besitzt = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(spieler.UserId, pass.Id)
			end)

			if erfolg then
				daten.Gamepasses[pass.Schluessel] = besitzt or nil
			end
		end
	end

	CurrencyService:MarkiereAenderung(spieler)
end

-- ================================================================
-- ENTWICKLERPRODUKTE
-- ================================================================

-- Schreibt die gekaufte Ware gut. Gibt true zurueck, wenn es geklappt hat.
function MonetizationService:ProduktEinloesen(spieler: Player, produkt: any): boolean
	local daten = DataService:Get(spieler)
	if not daten then
		return false
	end

	if produkt.Art == "Credits" then
		-- Der Wert richtet sich nach der eigenen Produktion, hat aber
		-- einen Mindestbetrag — sonst waere ein Paket am Spielanfang wertlos.
		local proSekunde = DropperService:GetEinkommenProSekunde(spieler)
		local betrag = math.max(
			produkt.Mindestbetrag or 0,
			math.floor(proSekunde * produkt.SekundenProduktion)
		)

		CurrencyService:Hinzufuegen(spieler, betrag)
		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = "+" .. Util.FormatGeld(betrag) .. " " .. Config.Spiel.Waehrung,
			Farbe = "Gold",
		})
		return true
	end

	if produkt.Art == "SkipBau" then
		local anzahl = #daten.Bauauftraege
		if anzahl == 0 then
			-- Nichts in der Warteschlange: Kauf trotzdem als erledigt
			-- markieren, sonst wuerde Roblox es endlos wiederholen.
			Net:Event("Benachrichtigung"):FireClient(spieler, {
				Text = "Die Werft war leer — nichts zu beschleunigen.",
				Farbe = "Warnung",
			})
			return true
		end

		-- Alle Auftraege sofort faellig stellen
		for _, auftrag in daten.Bauauftraege do
			auftrag.FertigUm = os.time() - 1
		end
		FleetService:PruefeFertigeBauten(spieler)

		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = anzahl .. " Schiff(e) sofort fertiggestellt",
			Farbe = "Gold",
		})
		return true
	end

	return false
end

-- ================================================================
-- SHOP-INFO FUER DEN CLIENT
-- ================================================================
function MonetizationService:GetShopInfo(spieler: Player): { any }
	local daten = DataService:Get(spieler)
	local liste = {}

	for _, pass in TechConfig.Gamepasses do
		table.insert(liste, {
			Art = "Gamepass",
			Schluessel = pass.Schluessel,
			Id = pass.Id,
			Name = pass.Name,
			Beschreibung = pass.Beschreibung,
			Verfuegbar = pass.Id ~= 0,
			Besitzt = (daten and daten.Gamepasses and daten.Gamepasses[pass.Schluessel]) == true,
		})
	end

	for _, produkt in TechConfig.Produkte do
		table.insert(liste, {
			Art = "Produkt",
			Schluessel = produkt.Schluessel,
			Id = produkt.Id,
			Name = produkt.Name,
			Beschreibung = produkt.Beschreibung,
			Verfuegbar = produkt.Id ~= 0,
			Besitzt = false,
		})
	end

	return liste
end

-- ================================================================
-- INIT
-- ================================================================
function MonetizationService:Init()
	-- Roblox ruft das auf, wenn ein Entwicklerprodukt gekauft wurde.
	MarketplaceService.ProcessReceipt = function(info)
		local spieler = Players:GetPlayerByUserId(info.PlayerId)
		if not spieler then
			-- Spieler ist weg. NICHT als erledigt melden — Roblox
			-- versucht es erneut, sobald er wieder da ist.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local produkt = TechConfig.ProduktNachId[info.ProductId]
		if not produkt then
			warn("[MonetizationService] Unbekanntes Produkt: " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- pcall, damit ein Fehler beim Gutschreiben nicht dazu fuehrt,
		-- dass Roblox den Kauf faelschlich als erledigt verbucht.
		local erfolg, eingeloest = pcall(function()
			return self:ProduktEinloesen(spieler, produkt)
		end)

		if not erfolg or not eingeloest then
			warn("[MonetizationService] Einloesen fehlgeschlagen: " .. tostring(eingeloest))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Sofort speichern: Wenn der Server jetzt abstuerzt, ist die
		-- gekaufte Ware trotzdem sicher im DataStore.
		DataService:Speichern(spieler)

		log(spieler.Name, "hat gekauft:", produkt.Schluessel)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Gamepass direkt im Spiel gekauft: sofort freischalten,
	-- ohne dass der Spieler neu beitreten muss.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(spieler, passId, gekauft)
		if not gekauft then
			return
		end

		local pass = TechConfig.GamepassNachId[passId]
		local daten = DataService:Get(spieler)
		if not pass or not daten then
			return
		end

		daten.Gamepasses = daten.Gamepasses or {}
		daten.Gamepasses[pass.Schluessel] = true
		CurrencyService:MarkiereAenderung(spieler)
		FleetService:Senden(spieler)

		Net:Event("Benachrichtigung"):FireClient(spieler, {
			Text = pass.Name .. " freigeschaltet!",
			Farbe = "Gold",
		})
		log(spieler.Name, "besitzt jetzt", pass.Schluessel)
	end)

	log("bereit")
end

-- Wird von Main beim Beitritt aufgerufen.
function MonetizationService:SpielerVorbereiten(spieler: Player)
	-- In einem eigenen Thread: Die Abfrage geht uebers Internet und
	-- darf den Beitritt nicht verzoegern.
	task.spawn(function()
		self:GamepassesPruefen(spieler)
	end)
end

return MonetizationService
