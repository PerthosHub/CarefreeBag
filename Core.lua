-- CarefreeBag: Core.lua
-- Basis: versie, teksten (T), log, instellingen (Defaults), groepen per karakter (CharEntry).
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...

ns.VERSION = "1.5.0"
do -- versie uit de .toc (bij een release vult de packager die in vanuit de git-tag)
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local v = get and get(ADDON, "Version")
	if v and v ~= "" and not v:find("@") then ns.VERSION = (v:gsub("^v", "")) end -- tag "v1.2.3" -> "1.2.3"
end


function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CarefreeBag|r: " .. tostring(msg))
end

-- Teksten: Engels in de code; vertalingen (nl, de, fr, ...) staan in Locales.lua.
local L = ns.L or {}
ns.L = L
function ns.T(s)
	local t = ns.DB and L[ns.DB.lang]
	return (t and t[s]) or s
end

ns.LANGS = {
	{ "en", "English" }, { "nl", "Nederlands" }, { "de", "Deutsch" }, { "fr", "Français" },
	{ "es", "Español" }, { "it", "Italiano" }, { "pt", "Português" }, { "ru", "Русский" },
}
function ns.LangName(code)
	for _, l in ipairs(ns.LANGS) do if l[1] == code then return l[2] end end
	return "English"
end
-- Taal van de WoW-client (er bestaat geen Nederlandse client, dus nl kies je zelf).
local function DetectLang()
	local map = { deDE = "de", frFR = "fr", esES = "es", esMX = "es", itIT = "it", ptBR = "pt", ptPT = "pt", ruRU = "ru" }
	return map[GetLocale and GetLocale() or ""] or "en"
end










-- Logboek in de SavedVariables (laatste 80 regels). Lees met /cfb log.
function ns.Log(msg)
	if not ns.DB then return end
	ns.DB.log = ns.DB.log or {}
	local stamp = date and date("%d-%m %H:%M:%S") or tostring(GetTime())
	table.insert(ns.DB.log, stamp .. "  " .. tostring(msg))
	while #ns.DB.log > 80 do table.remove(ns.DB.log, 1) end
end

---------------------------------------------------------------------------
-- Instellingen
---------------------------------------------------------------------------

-- Kant-en-klare categorieën: vullen zichzelf op itemsoort (zoals WoW die in de
-- tooltip toont). De naam staat vast, zodat altijd duidelijk is wat erin komt.
-- Itemsoort (Enum.ItemClass): 0 Consumable, 2 Weapon, 3 Gem, 4 Armor, 7 Tradegoods,
-- 8 ItemEnhancement, 9 Recipe, 19 Profession. Consumable-subsoort: 1 Potion,
-- 2 Elixir, 3 Flask, 4 Scroll, 5 Food & Drink.
-- Volgorde = voorrang: Food & Drink wint van het bredere Consumables.
ns.PRESETS = {
	{ id = "food", name = "Food & Drink", tip = "Fills itself with food and drink.",
		match = function(e) return e.classID == 0 and e.subclassID == 5 end },
	{ id = "potions", name = "Potions & Elixirs", tip = "Fills itself with potions, elixirs and flasks.",
		match = function(e) return e.classID == 0 and (e.subclassID == 1 or e.subclassID == 2 or e.subclassID == 3) end },
	{ id = "scrolls", name = "Scrolls", tip = "Fills itself with scrolls.",
		match = function(e) return e.classID == 0 and e.subclassID == 4 end },
	{ id = "consum", name = "Consumables", tip = "Fills itself with food, drink, potions, elixirs, scrolls, bandages and enchants.",
		match = function(e) return e.classID == 0 or e.classID == 8 end },
	{ id = "prof", name = "Professions", tip = "Fills itself with trade goods and recipes.",
		match = function(e) return e.classID == 3 or e.classID == 7 or e.classID == 9 or e.classID == 19 end },
	{ id = "gear", name = "Gear", tip = "Fills itself with weapons and armor you can wear.",
		match = function(e) return (e.classID == 2 or e.classID == 4) and (e.equipLoc or "") ~= "" end },
}
ns.PRESET = {}
for i, p in ipairs(ns.PRESETS) do p.rank = i; ns.PRESET[p.id] = p end

-- Nieuwe installaties beginnen met drie kant-en-klare categorieën.
local DEFAULT_CATS = { "consum", "prof", "gear" }

function ns.Defaults()
	local fresh = (CarefreeBagDB == nil) or (next(CarefreeBagDB) == nil)
	CarefreeBagDB = CarefreeBagDB or {}
	ns.DB = CarefreeBagDB
	-- Taal: bestaande installaties (van voor 0.6.0) waren Nederlands.
	if ns.DB.lang == nil then ns.DB.lang = fresh and DetectLang() or "nl" end
	if not L[ns.DB.lang] and ns.DB.lang ~= "en" then ns.DB.lang = "en" end
	-- Auto Sell: nieuwe gebruikers krijgen bij de eerste vendor een vraag.
	if ns.DB.autoSellAsked == nil then ns.DB.autoSellAsked = (not fresh) and ns.DB.autoSell ~= nil end
	ns.DB.chars = ns.DB.chars or {}     -- per karakter: { assign = { [itemID] = categorie-key } }
	ns.DB.hidden = ns.DB.hidden or {}   -- [itemID] = true
	ns.DB.locked = nil               -- locken is weggehaald in 0.3.0
	if not ns.DB.cats then
		ns.DB.cats = {}
		for _, id in ipairs(DEFAULT_CATS) do
			ns.DB.cats[#ns.DB.cats + 1] = { key = id, preset = id }
		end
	end
	-- 1.1.0-test had "auto"; kant-en-klare categorieën krijgen hun vaste naam in jouw taal.
	local OLD = { consumable = "consum", profession = "prof", gear = "gear" }
	for _, c in ipairs(ns.DB.cats) do
		if c.auto then c.preset = OLD[c.auto]; c.auto = nil end
		if c.preset and ns.PRESET[c.preset] then c.name = ns.T(ns.PRESET[c.preset].name) else c.preset = nil end
	end
	-- Post: elke categorie heeft zijn eigen adres (mailTo). Oude instellingen omzetten.
	if ns.DB.bankAlt ~= nil or ns.DB.boeAlt ~= nil then
		for _, c in ipairs(ns.DB.cats) do
			if c.mail == "bank" and ns.DB.bankAlt and ns.DB.bankAlt ~= "" then c.mailTo = ns.DB.bankAlt
			elseif c.mail == "boe" and ns.DB.boeAlt and ns.DB.boeAlt ~= "" then c.mailTo = ns.DB.boeAlt end
			c.mail = nil
		end
		if ns.DB.boeMail == nil then ns.DB.boeMail = ns.DB.boeAlt or "" end
		ns.DB.bankAlt, ns.DB.boeAlt = nil, nil
	end
	if ns.DB.boeMail == nil then ns.DB.boeMail = "" end
	ns.DB.merge, ns.DB.autoStack = true, true -- altijd aan: dit is wat CarefreeBag doet
	-- Vaste groepen aan/uit. Uit = de items vallen terug naar Overig.
	ns.DB.fixedOn = ns.DB.fixedOn or {}
	if ns.DB.fixedOn.boe == nil then ns.DB.fixedOn.boe = (ns.DB.boeAuto ~= false) end
	ns.DB.boeAuto = nil
	for _, k in ipairs({ "quest", "keys", "grey" }) do
		if ns.DB.fixedOn[k] == nil then ns.DB.fixedOn[k] = true end
	end
	if ns.DB.showSort == nil then ns.DB.showSort = false end -- sorteerknopjes: standaard uit
	if not ns.DB.keysOffDone then ns.DB.fixedOn.keys = false; ns.DB.keysOffDone = true end
	if ns.DB.enabled == nil then ns.DB.enabled = (ns.DB.replaceBags ~= false) end
	ns.DB.replaceBags = nil
	ns.DB.questAuto = true -- quest-items gaan altijd naar Quest (groep uit = naar Overig)
	ns.DB.greyAuto = true -- grijze items gaan altijd naar Auto Sell
	if ns.DB.autoSell == nil then ns.DB.autoSell = false end
	ns.DB.conflictOK = ns.DB.conflictOK or {}
	ns.DB.maxCols = ns.DB.maxCols or 14  -- breder dan dit wordt het venster niet; daarna scrollen
	ns.DB.cols = nil
	ns.DB.minimapAngle = ns.DB.minimapAngle or 230
end

-- Forever gebruikt voornaam + achternaam ("Voornaam Achternaam"). Intern zet de game er
-- een vast scheidingsteken tussen. Dat teken lezen we uit de game zelf, of we leiden
-- het af van je eigen naam.
function ns.SurnameSep()
	local c = Constants and Constants.CharacterNameSeparatorConsts
	local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
	if type(sep) == "string" and sep ~= "" then return sep end
	local me = UnitName("player")
	if me and me:find("-", 1, true) then return "-" end
	if me and me:find(" ", 1, true) then return " " end
	return nil
end

function ns.FullName(input)
	input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local first, last = input:match("^([^%s%-]+)[%s%-]+([^%s%-]+)$")
	local sep = ns.SurnameSep()
	if first and sep then return first .. sep .. last end
	return input
end

-- Je eigen volledige naam. UnitName("player") geeft in Forever alleen de voornaam;
-- UnitNameUnmodified geeft voornaam én achternaam terug.
function ns.MyFullName()
	local n, sur
	if UnitNameUnmodified then n, sur = UnitNameUnmodified("player") end
	if not n then n, sur = UnitName("player") end
	if sur and sur ~= "" then return n .. " " .. sur end
	return n
end

function ns.SameName(a, b)
	local function norm(x) return (x or ""):lower():gsub("[%s%-]+", " ") end
	return norm(a) == norm(b)
end

-- Wat jij versleept onthoudt CarefreeBag per karakter. Van voor 1.1.0 was dat
-- één lijst voor het hele account (DB.assign); elk karakter begint met een kopie daarvan.
-- Bekijk je de tassen of bank van een ander karakter, dan wijst viewKey even naar dat
-- karakter: zo gebruiken we dezelfde groepen-indeling zonder iets dubbel te bouwen.
function ns.CharEntry()
	if ns.viewKey and ns.DB.chars[ns.viewKey] then return ns.DB.chars[ns.viewKey] end
	if not ns.charKey then
		local name = UnitName and UnitName("player")
		if not name or name == "" or name == UNKNOWNOBJECT then return nil end
		local realm = "-" .. ((GetRealmName and GetRealmName()) or "")
		-- Forever: twee karakters kunnen dezelfde voornaam hebben (Thrall Frostwolf en
		-- Thrall Stormrage). Daarom de volledige naam als sleutel.
		local full = ns.MyFullName() or name
		ns.charKey = full .. realm
		-- Tot 1.5.0 was de sleutel alleen de voornaam; die gedeelde gegevens kopiëren we
		-- (zonder de onthouden tassen/bank, want die waren van wie het laatst inlogde).
		local old = ns.DB.chars[name .. realm]
		if full ~= name and old and not ns.DB.chars[ns.charKey] then
			local function copy(t) local n = {}; for k, v in pairs(t or {}) do n[k] = type(v) == "table" and copy(v) or v end; return n end
			-- Wie het laatst inlogde, heeft de groepen het laatst aangepast: die houdt ze.
			-- De anderen beginnen weer met de groepen van vóór 1.3.0 (de accountlijst).
			local owner = (old.snap and old.snap.name) or old.lastName
			old.lastName = owner
			local ch = copy(old)
			ch.snap, ch.legacy, ch.lastName = nil, nil, nil
			if owner and owner ~= full then ch.cats, ch.order, ch.sort, ch.collapsed = nil, nil, nil, nil end
			ns.DB.chars[ns.charKey] = ch
			old.snap, old.legacy = nil, true -- oude sleutel: niet meer tonen als karakter
		end
	end
	local ch = ns.DB.chars[ns.charKey]
	if not ch then
		ch = { assign = {} }
		for id, k in pairs(ns.DB.assign or {}) do ch.assign[id] = k end
		ns.DB.chars[ns.charKey] = ch
	end
	if not ch.hidden then -- verbergen geldt per karakter; begin met de oude lijst
		ch.hidden = {}
		for id in pairs(ns.DB.hidden or {}) do ch.hidden[id] = true end
	end
	ch.seen = ch.seen or {}
	ch.manual = ch.manual or {}
	-- Groepen gelden per karakter (sinds 1.3.0). Elk karakter begint met een kopie
	-- van de oude accountlijst; daarna past elk karakter zijn eigen lijst aan.
	if not ch.cats then
		ch.cats = {}
		for i, c in ipairs(ns.DB.cats or {}) do
			local n = {}
			for k, v in pairs(c) do n[k] = v end
			ch.cats[i] = n
		end
		local function copy(t) local n = {}; for k, v in pairs(t or {}) do n[k] = v end; return n end
		ch.order = ch.order or copy(ns.DB.order)
		ch.sort = ch.sort or copy(ns.DB.sort)
		ch.collapsed = ch.collapsed or copy(ns.DB.collapsed)
	end
	if not ns.catsNamed then -- kant-en-klare groepen krijgen hun vaste naam in jouw taal
		ns.catsNamed = true
		for _, c in ipairs(ch.cats) do
			if c.preset and ns.PRESET[c.preset] then c.name = ns.T(ns.PRESET[c.preset].name) else c.preset = nil end
		end
	end
	return ch
end
-- De instellingen van dit karakter (groepen, volgorde, sortering, ingeklapt).
function ns.CS() return ns.CharEntry() or ns.DB end
function ns.Assign()
	local ch = ns.CharEntry()
	return ch and ch.assign or (ns.DB.assign or {})
end
local NOHIDDEN = {}
function ns.Hidden()
	local ch = ns.CharEntry()
	return ch and ch.hidden or NOHIDDEN
end

-- Hoeveel items heeft dit karakter aan een groep geleerd (door slepen)?
function ns.LearnedCount(key)
	local n = 0
	for _, k in pairs(ns.Assign()) do if k == key then n = n + 1 end end
	return n
end

function ns.CatByKey(key)
	for i, c in ipairs(ns.CS().cats) do
		if c.key == key then return c, i end
	end
end

function ns.NewCatKey(name)
	local base = (name:lower():gsub("[^%w]", "")):sub(1, 12)
	if base == "" then base = "cat" end
	local key, n = base, 1
	while ns.CatByKey(key) or key == "boe" or key == "other" or key == "hidden" or key == "quest" or key == "grey" do
		n = n + 1
		key = base .. n
	end
	return key
end
