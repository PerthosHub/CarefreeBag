-- CarefreeBag: Core.lua
-- Basis: versie, teksten (T), log, instellingen (Defaults), groepen per karakter (CharEntry).
-- Alle bestanden delen één omgeving (zie Env.lua). De namen hieronder maakt dit bestand.
local _, ns = ...
setfenv(1, ns.Env(
	"VERSION", "DB", "Refresh", "SavePos", "Print", "L", "T", "LANGS", "LangName", "DetectLang",
	"Log", "PRESETS", "PRESET", "DEFAULT_CATS", "Defaults", "SurnameSep", "FullName", "MyFullName",
	"SameName", "charKey", "catsNamed", "viewKey", "CharEntry", "CS", "Assign", "NOHIDDEN", "Hidden",
	"LearnedCount", "CatByKey", "NewCatKey"
))

VERSION = "1.5.0"
do -- versie uit de .toc (bij een release vult de packager die in vanuit de git-tag)
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local v = get and get(ADDON, "Version")
	if v and v ~= "" and not v:find("@") then VERSION = (v:gsub("^v", "")) end -- tag "v1.2.3" -> "1.2.3"
end

-- vooruit gedeclareerd (Refresh)
-- vooruit (SavePos)

function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99CarefreeBag|r: " .. tostring(msg))
end

-- Teksten: Engels in de code; vertalingen (nl, de, fr, ...) staan in Locales.lua.
L = ns.L or {}
ns.L = L
function T(s)
	local t = DB and L[DB.lang]
	return (t and t[s]) or s
end

LANGS = {
	{ "en", "English" }, { "nl", "Nederlands" }, { "de", "Deutsch" }, { "fr", "Français" },
	{ "es", "Español" }, { "it", "Italiano" }, { "pt", "Português" }, { "ru", "Русский" },
}
function LangName(code)
	for _, l in ipairs(LANGS) do if l[1] == code then return l[2] end end
	return "English"
end
-- Taal van de WoW-client (er bestaat geen Nederlandse client, dus nl kies je zelf).
function DetectLang()
	local map = { deDE = "de", frFR = "fr", esES = "es", esMX = "es", itIT = "it", ptBR = "pt", ptPT = "pt", ruRU = "ru" }
	return map[GetLocale and GetLocale() or ""] or "en"
end










-- Logboek in de SavedVariables (laatste 80 regels). Lees met /cfb log.
function Log(msg)
	if not DB then return end
	DB.log = DB.log or {}
	local stamp = date and date("%d-%m %H:%M:%S") or tostring(GetTime())
	table.insert(DB.log, stamp .. "  " .. tostring(msg))
	while #DB.log > 80 do table.remove(DB.log, 1) end
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
PRESETS = {
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
PRESET = {}
for i, p in ipairs(PRESETS) do p.rank = i; PRESET[p.id] = p end

-- Nieuwe installaties beginnen met drie kant-en-klare categorieën.
DEFAULT_CATS = { "consum", "prof", "gear" }

function Defaults()
	local fresh = (CarefreeBagDB == nil) or (next(CarefreeBagDB) == nil)
	_G.CarefreeBagDB = CarefreeBagDB or {} -- SavedVariables staan in de echte globale ruimte
	DB = CarefreeBagDB
	-- Taal: bestaande installaties (van voor 0.6.0) waren Nederlands.
	if DB.lang == nil then DB.lang = fresh and DetectLang() or "nl" end
	if not L[DB.lang] and DB.lang ~= "en" then DB.lang = "en" end
	-- Auto Sell: nieuwe gebruikers krijgen bij de eerste vendor een vraag.
	if DB.autoSellAsked == nil then DB.autoSellAsked = (not fresh) and DB.autoSell ~= nil end
	DB.chars = DB.chars or {}     -- per karakter: { assign = { [itemID] = categorie-key } }
	DB.hidden = DB.hidden or {}   -- [itemID] = true
	DB.locked = nil               -- locken is weggehaald in 0.3.0
	if not DB.cats then
		DB.cats = {}
		for _, id in ipairs(DEFAULT_CATS) do
			DB.cats[#DB.cats + 1] = { key = id, preset = id }
		end
	end
	-- 1.1.0-test had "auto"; kant-en-klare categorieën krijgen hun vaste naam in jouw taal.
	local OLD = { consumable = "consum", profession = "prof", gear = "gear" }
	for _, c in ipairs(DB.cats) do
		if c.auto then c.preset = OLD[c.auto]; c.auto = nil end
		if c.preset and PRESET[c.preset] then c.name = T(PRESET[c.preset].name) else c.preset = nil end
	end
	-- Post: elke categorie heeft zijn eigen adres (mailTo). Oude instellingen omzetten.
	if DB.bankAlt ~= nil or DB.boeAlt ~= nil then
		for _, c in ipairs(DB.cats) do
			if c.mail == "bank" and DB.bankAlt and DB.bankAlt ~= "" then c.mailTo = DB.bankAlt
			elseif c.mail == "boe" and DB.boeAlt and DB.boeAlt ~= "" then c.mailTo = DB.boeAlt end
			c.mail = nil
		end
		if DB.boeMail == nil then DB.boeMail = DB.boeAlt or "" end
		DB.bankAlt, DB.boeAlt = nil, nil
	end
	if DB.boeMail == nil then DB.boeMail = "" end
	DB.merge, DB.autoStack = true, true -- altijd aan: dit is wat CarefreeBag doet
	-- Vaste groepen aan/uit. Uit = de items vallen terug naar Overig.
	DB.fixedOn = DB.fixedOn or {}
	if DB.fixedOn.boe == nil then DB.fixedOn.boe = (DB.boeAuto ~= false) end
	DB.boeAuto = nil
	for _, k in ipairs({ "quest", "keys", "grey" }) do
		if DB.fixedOn[k] == nil then DB.fixedOn[k] = true end
	end
	if DB.showSort == nil then DB.showSort = false end -- sorteerknopjes: standaard uit
	if not DB.keysOffDone then DB.fixedOn.keys = false; DB.keysOffDone = true end
	if DB.enabled == nil then DB.enabled = (DB.replaceBags ~= false) end
	DB.replaceBags = nil
	DB.questAuto = true -- quest-items gaan altijd naar Quest (groep uit = naar Overig)
	DB.greyAuto = true -- grijze items gaan altijd naar Auto Sell
	if DB.autoSell == nil then DB.autoSell = false end
	DB.conflictOK = DB.conflictOK or {}
	DB.maxCols = DB.maxCols or 14  -- breder dan dit wordt het venster niet; daarna scrollen
	DB.cols = nil
	DB.minimapAngle = DB.minimapAngle or 230
end

-- Forever gebruikt voornaam + achternaam ("Voornaam Achternaam"). Intern zet de game er
-- een vast scheidingsteken tussen. Dat teken lezen we uit de game zelf, of we leiden
-- het af van je eigen naam.
function SurnameSep()
	local c = Constants and Constants.CharacterNameSeparatorConsts
	local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
	if type(sep) == "string" and sep ~= "" then return sep end
	local me = UnitName("player")
	if me and me:find("-", 1, true) then return "-" end
	if me and me:find(" ", 1, true) then return " " end
	return nil
end

function FullName(input)
	input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local first, last = input:match("^([^%s%-]+)[%s%-]+([^%s%-]+)$")
	local sep = SurnameSep()
	if first and sep then return first .. sep .. last end
	return input
end

-- Je eigen volledige naam. UnitName("player") geeft in Forever alleen de voornaam;
-- UnitNameUnmodified geeft voornaam én achternaam terug.
function MyFullName()
	local n, sur
	if UnitNameUnmodified then n, sur = UnitNameUnmodified("player") end
	if not n then n, sur = UnitName("player") end
	if sur and sur ~= "" then return n .. " " .. sur end
	return n
end

function SameName(a, b)
	local function norm(x) return (x or ""):lower():gsub("[%s%-]+", " ") end
	return norm(a) == norm(b)
end

-- Wat jij versleept onthoudt CarefreeBag per karakter. Van voor 1.1.0 was dat
-- één lijst voor het hele account (DB.assign); elk karakter begint met een kopie daarvan.
-- Bekijk je de tassen of bank van een ander karakter, dan wijst viewKey even naar dat
-- karakter: zo gebruiken we dezelfde groepen-indeling zonder iets dubbel te bouwen.
function CharEntry()
	if viewKey and DB.chars[viewKey] then return DB.chars[viewKey] end
	if not charKey then
		local name = UnitName and UnitName("player")
		if not name or name == "" or name == UNKNOWNOBJECT then return nil end
		local realm = "-" .. ((GetRealmName and GetRealmName()) or "")
		-- Forever: twee karakters kunnen dezelfde voornaam hebben (Thrall Frostwolf en
		-- Thrall Stormrage). Daarom de volledige naam als sleutel.
		local full = MyFullName() or name
		charKey = full .. realm
		-- Tot 1.5.0 was de sleutel alleen de voornaam; die gedeelde gegevens kopiëren we
		-- (zonder de onthouden tassen/bank, want die waren van wie het laatst inlogde).
		local old = DB.chars[name .. realm]
		if full ~= name and old and not DB.chars[charKey] then
			local function copy(t) local n = {}; for k, v in pairs(t or {}) do n[k] = type(v) == "table" and copy(v) or v end; return n end
			-- Wie het laatst inlogde, heeft de groepen het laatst aangepast: die houdt ze.
			-- De anderen beginnen weer met de groepen van vóór 1.3.0 (de accountlijst).
			local owner = (old.snap and old.snap.name) or old.lastName
			old.lastName = owner
			local ch = copy(old)
			ch.snap, ch.legacy, ch.lastName = nil, nil, nil
			if owner and owner ~= full then ch.cats, ch.order, ch.sort, ch.collapsed = nil, nil, nil, nil end
			DB.chars[charKey] = ch
			old.snap, old.legacy = nil, true -- oude sleutel: niet meer tonen als karakter
		end
	end
	local ch = DB.chars[charKey]
	if not ch then
		ch = { assign = {} }
		for id, k in pairs(DB.assign or {}) do ch.assign[id] = k end
		DB.chars[charKey] = ch
	end
	if not ch.hidden then -- verbergen geldt per karakter; begin met de oude lijst
		ch.hidden = {}
		for id in pairs(DB.hidden or {}) do ch.hidden[id] = true end
	end
	ch.seen = ch.seen or {}
	ch.manual = ch.manual or {}
	-- Groepen gelden per karakter (sinds 1.3.0). Elk karakter begint met een kopie
	-- van de oude accountlijst; daarna past elk karakter zijn eigen lijst aan.
	if not ch.cats then
		ch.cats = {}
		for i, c in ipairs(DB.cats or {}) do
			local n = {}
			for k, v in pairs(c) do n[k] = v end
			ch.cats[i] = n
		end
		local function copy(t) local n = {}; for k, v in pairs(t or {}) do n[k] = v end; return n end
		ch.order = ch.order or copy(DB.order)
		ch.sort = ch.sort or copy(DB.sort)
		ch.collapsed = ch.collapsed or copy(DB.collapsed)
	end
	if not catsNamed then -- kant-en-klare groepen krijgen hun vaste naam in jouw taal
		catsNamed = true
		for _, c in ipairs(ch.cats) do
			if c.preset and PRESET[c.preset] then c.name = T(PRESET[c.preset].name) else c.preset = nil end
		end
	end
	return ch
end
-- De instellingen van dit karakter (groepen, volgorde, sortering, ingeklapt).
function CS() return CharEntry() or DB end
function Assign()
	local ch = CharEntry()
	return ch and ch.assign or (DB.assign or {})
end
NOHIDDEN = {}
function Hidden()
	local ch = CharEntry()
	return ch and ch.hidden or NOHIDDEN
end

-- Hoeveel items heeft dit karakter aan een groep geleerd (door slepen)?
function LearnedCount(key)
	local n = 0
	for _, k in pairs(Assign()) do if k == key then n = n + 1 end end
	return n
end

function CatByKey(key)
	for i, c in ipairs(CS().cats) do
		if c.key == key then return c, i end
	end
end

function NewCatKey(name)
	local base = (name:lower():gsub("[^%w]", "")):sub(1, 12)
	if base == "" then base = "cat" end
	local key, n = base, 1
	while CatByKey(key) or key == "boe" or key == "other" or key == "hidden" or key == "quest" or key == "grey" do
		n = n + 1
		key = base .. n
	end
	return key
end
