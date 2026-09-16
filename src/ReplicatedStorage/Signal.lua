--[[
	Signal  —  ModuleScript
	================================================================
	EXPLORER-ORT:  ReplicatedStorage > Signal

	WOFUER?
	Ein "Signal" ist ein selbstgebautes Event: Ein Service ruft
	:Feuern(...) auf, alle angemeldeten Funktionen laufen los.
	Damit muss z. B. der PlotService den ButtonService nicht kennen —
	das verhindert zirkulaere require()-Ketten, die in Roblox zu
	endlosem Haengenbleiben fuehren.

	WARUM NICHT EINFACH EIN BindableEvent?
	Das ist ein haeufiger, sehr schwer zu findender Anfaengerfehler:
	Ein BindableEvent KOPIERT jede Tabelle, die man durchschickt.
	Der Empfaenger bekommt also nicht dieselbe Tabelle, sondern ein
	Duplikat. Aenderungen daran verpuffen. Fuer unsere Plot-Tabellen
	waere das fatal. Ein reines Lua-Signal reicht Werte 1:1 weiter.
	================================================================
]]

local Signal = {}
Signal.__index = Signal

export type Verbindung = { Trennen: (Verbindung) -> () }

function Signal.neu()
	return setmetatable({ _hoerer = {} }, Signal)
end

-- Meldet eine Funktion an. Rueckgabe: Objekt mit :Trennen()
function Signal:Verbinden(funktion: (...any) -> ())
	table.insert(self._hoerer, funktion)

	local verbindung = {}
	function verbindung:Trennen()
		local index = table.find(self._signal._hoerer, funktion)
		if index then
			table.remove(self._signal._hoerer, index)
		end
	end
	verbindung._signal = self

	return verbindung
end

-- Ruft alle angemeldeten Funktionen auf.
-- Jede laeuft in einem eigenen Thread mit Fehlerabfang: Ein Fehler in
-- einem Hoerer darf die anderen nicht mitreissen.
function Signal:Feuern(...)
	for _, funktion in table.clone(self._hoerer) do
		local argumente = table.pack(...)
		task.spawn(function()
			local erfolg, fehler = pcall(funktion, table.unpack(argumente, 1, argumente.n))
			if not erfolg then
				warn("[Signal] Fehler in einem Hoerer: " .. tostring(fehler))
			end
		end)
	end
end

-- Wie Feuern, aber sofort im selben Thread (Reihenfolge garantiert).
-- Nutzen, wenn die Reaktion abgeschlossen sein muss, bevor es weitergeht.
function Signal:FeuernSofort(...)
	for _, funktion in table.clone(self._hoerer) do
		local erfolg, fehler = pcall(funktion, ...)
		if not erfolg then
			warn("[Signal] Fehler in einem Hoerer: " .. tostring(fehler))
		end
	end
end

function Signal:Leeren()
	table.clear(self._hoerer)
end

return Signal
