-- CarefreeBag: Env.lua (laadt als eerste)
-- Alle bestanden van CarefreeBag delen één eigen omgeving. Elk bestand begint met
--     local _, ns = ...
--     setfenv(1, ns.Env("Naam1", "Naam2", ...))
-- en noemt daarin de namen die het zelf maakt. Die namen zijn in alle bestanden te
-- gebruiken, zonder de globale ruimte van WoW te vervuilen. Een naam die nergens is
-- genoemd, kun je niet per ongeluk vullen: dat geeft meteen een foutmelding.
-- Echte globals (SavedVariables, slash-commando's) schrijf je via _G.
local ADDON, ns = ...
local declared = { ADDON = true, ns = true }
local env = setmetatable({ ADDON = ADDON, ns = ns }, {
	-- Eigen namen die (nog) leeg zijn, niet bij WoW gaan zoeken.
	__index = function(_, k) if declared[k] then return nil end return _G[k] end,
	__newindex = function(t, k, v)
		if not declared[k] then error("CarefreeBag: '" .. tostring(k) .. "' is not declared in ns.Env(...)", 2) end
		rawset(t, k, v)
	end,
})

function ns.Env(...)
	for i = 1, select("#", ...) do declared[select(i, ...)] = true end
	return env
end
