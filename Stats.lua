-- CarefreeBag: Stats.lua
-- Gebruiksstatistieken (alleen met toestemming): bij de start één korte vraag.
-- Ja = CarefreeBag telt lokaal (logins, tassen open, speeltijd, mails, fouten) en stuurt dat
-- op de achtergrond naar de maker zodra die online is; na ontvangst wordt het hier gewist.
--
-- Hoe het gaat (alleen in het spel, addons kunnen niet naar internet):
--   * Iedereen die "ja" zei en de maker zitten in een verborgen kanaal (CHANNEL_NAME).
--     Alles gaat via dat kanaal, geen whispers: op Forever zijn Horde en Alliance gescheiden
--     (whispers komen daar niet over), en er zijn geen servers meer, alleen één grote
--     server per regelset (Normal, PvP, RP).
--   * Maker roept "H|<naam>" bij inloggen, elke 15 min en na een ping (max. 1× per 30 s).
--   * Speler roept na het joinen "P|versie|nummer" (online), na "ja" ook "Y|versie" (net toegestemd).
--     Uitzetten = eerst nog "N|nummer" (afmelding), dan het kanaal uit. De maker houdt per
--     speler "laatst gezien" bij: lang niet gezien = waarschijnlijk gestopt.
--   * Na een geldige "H" stuurt de speler zijn pakketje: "S|seq|velden", "E|seq|aantal|fout"
--     (max 5), "X|seq|aantal E". De maker bewaart het en roept "A|seq"; dan wist de speler het.
--   * Geen "A" = het pakketje blijft bewaard tot de volgende keer (niets gaat verloren).
--   * 1.12.0 stuurde per whisper; de maker leest dat nog steeds (soort bericht maakt niet uit).
-- Wie de maker is: een hash van de volledige naam (geen namen in de code), en de voornaam
-- van de afzender die WoW meegeeft moet precies gelijk zijn.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Log, MyFullName, Print, T = ns.Log, ns.MyFullName, ns.Print, ns.T

local PREFIX = "CFBStats"
local CHANNEL_NAME = "CFBStats"
local CHANNEL_PASS = "cfb4stats"
local HELLO_EVERY = 15 * 60 -- maker: zo vaak "ik ben er" in het kanaal
local HELLO_MIN = 30 -- maker: niet vaker dan dit antwoorden op pings
local RESEND_AFTER = 5 * 60 -- speler: niet vaker dan dit hetzelfde pakketje opnieuw
local MAX_ERRORS = 5

-- Hashes van de volledige namen van de verzamelaar (de maker). Tests voegen er zelf een toe.
ns.STATS_COLLECTORS = { [2250199981] = true, [1025544951] = true }

-- djb2 over de kleine letters (alleen A-Z, zoals string.lower in WoW), 32 bit.
function ns.NameHash(s)
	s = tostring(s or ""):gsub("%u", string.lower)
	local h = 5381
	for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
	return h
end

local function Today() return date and date("%Y-%m-%d") or "?" end
local function Now() return GetTime and GetTime() or 0 end

-- Werkt het versturen in deze WoW? Classic blokkeert addon-berichten in eigen kanalen.
local function Supported()
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
	local toc = GetBuildInfo and select(4, GetBuildInfo())
	return (WOW_PROJECT_ID ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) or toc == 16001
end
ns.StatsSupported = Supported

local function IsCollector()
	return ns.STATS_COLLECTORS[ns.NameHash(MyFullName())] == true
end
ns.StatsIsCollector = IsCollector

local function Sharing() return ns.DB and ns.DB.statsShare == true and Supported() and not IsCollector() end

---------------------------------------------------------------------------
-- Lokaal tellen (alleen met toestemming)
---------------------------------------------------------------------------

local function Stats()
	local s = ns.DB.stats
	if not s then
		s = { since = Today(), logins = 0, opens = 0, minutes = 0, mails = 0, days = 0, errors = {} }
		ns.DB.stats = s
	end
	if not ns.DB.statsID then ns.DB.statsID = string.format("%06x", math.random(0, 16777215)) end
	return s
end

local sessionStart = nil
local function AddMinutes()
	if not sessionStart or not Sharing() then return end
	local now = Now()
	local s = Stats()
	s.minutes = s.minutes + math.floor((now - sessionStart) / 60 + 0.5)
	sessionStart = now
end

local function Count(field)
	if not Sharing() then return end
	local s = Stats()
	s[field] = (s[field] or 0) + 1
end

local function CountDay()
	local s = Stats()
	local today = Today()
	if s.lastDay ~= today then s.lastDay = today; s.days = (s.days or 0) + 1 end
end

-- Teller per functie (aangeroepen vanuit Loot/Chores/Mail/BankPanel/BagWindow/BagSwap):
-- ls/lp/ll = Bags full-paneel getoond/Pick up/Leave all, sl/sg = Auto Sell keer/koper,
-- cm = mail naar alts via CFB, bk = Bank & alts, sr = zoeken, dr = naar een groep gesleept, sw = tas gewisseld.
function ns.StatsCount(key, n)
	if not Sharing() then return end
	local s = Stats()
	s.f = s.f or {}
	s.f[key] = (s.f[key] or 0) + (n or 1)
end

-- Aangeroepen door ns.SetError (Core.lua).
function ns.StatsError(msg)
	if not Sharing() then return end
	local s = Stats()
	msg = tostring(msg):gsub("Interface[/\\]AddOns[/\\]CarefreeBag[/\\]", ""):gsub("|", "/"):sub(1, 180)
	if s.errors[msg] then s.errors[msg] = s.errors[msg] + 1; return end
	local n = 0
	for _ in pairs(s.errors) do n = n + 1 end
	if n < 20 then s.errors[msg] = 1 end
end

---------------------------------------------------------------------------
-- Dev-venster (alleen voor de maker): wie is online, wie zei ja, wat kwam binnen
---------------------------------------------------------------------------

local devLines = {}
local online = {} -- [afzender] = true (deze sessie gezien)
local joined = false
local ChannelNumber -- vooruit

local function CountKeys(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

-- Overzicht van opties en functies over alle spelers (dev-venster en /cfb stats).
-- Namen van de opties = de vinkjes in de opties (al vertaald); Auto Sell is een vaste naam.
local OPTION_NAMES = {
	{ "as", "Auto Sell" }, { "ab", "Equip better bags automatically" }, { "lp", "Bags full: offer to make room" },
	{ "oc", "Open clams automatically" }, { "ms", "Fill in the mail subject" }, { "bf", "Fill bar on the backpack" },
	{ "hb", "Hide the other bag slots" }, { "mq", "Always mail without asking" },
}
local function Overview()
	local withOpts, on, groups, other, f = 0, {}, 0, 0, {}
	for _, r in pairs(ns.DB.collected or {}) do
		if r.opts then
			withOpts = withOpts + 1
			for _, o in ipairs(OPTION_NAMES) do if r.opts[o[1]] == "1" then on[o[1]] = (on[o[1]] or 0) + 1 end end
			groups = groups + (tonumber(r.opts.g) or 0)
			if (tonumber(r.opts.ob) or 0) > 0 then other = other + 1 end
		end
		for k, v in pairs(r.f or {}) do f[k] = (f[k] or 0) + v end
	end
	if withOpts == 0 then return nil end
	local list = {}
	for _, o in ipairs(OPTION_NAMES) do
		local name = o[2] == "Auto Sell" and o[2] or T(o[2])
		list[#list + 1] = ("%s %d/%d"):format(name, on[o[1]] or 0, withOpts)
	end
	local money = tostring(f.sg or 0)
	if GetCoinText then
		local ok, m = pcall(GetCoinText, f.sg or 0, " ")
		if ok and m then money = m end
	end
	return {
		T("Options on: %s"):format(table.concat(list, ", ")),
		T("Features used: bags full panel %d (picked up %d, left all %d), Auto Sell %d (%s), CFB mail %d, Bank & alts %d, searches %d, items dragged %d, bags swapped %d"):format(
			f.ls or 0, f.lp or 0, f.ll or 0, f.sl or 0, tostring(money), f.cm or 0, f.bk or 0, f.sr or 0, f.dr or 0, f.sw or 0),
		T("Groups per player: %.1f on average, other bag addon: %d players"):format(groups / withOpts, other),
	}
end

-- Wie deelt niet meer: zelf uitgezet (afmelding), of 14+ dagen niet gezien (gestopt of pauze).
local function Gone()
	local off, quiet = 0, 0
	local cut = (date and time) and date("%Y-%m-%d", time() - 14 * 86400) or ""
	for _, r in pairs(ns.DB.collected or {}) do
		if r.off then off = off + 1
		elseif (r.seen or r.last or "") < cut then quiet = quiet + 1 end
	end
	return T("Stopped sharing: %d · not seen for 14+ days: %d"):format(off, quiet)
end

-- Dev-venster: tegels bovenaan, spelerslijst (laatst gezien bovenaan), opties en functies
-- met iconen en balkjes, onderaan de laatste gebeurtenissen. Alles wordt bij elke update
-- opnieuw neergezet met hergebruikte tekst/textuur-objecten (pool).
local DEV_W = 580
local ICON = "Interface\\Icons\\"
local C_GOLD, C_GREY, C_GREEN, C_YELLOW, C_RED, C_BLUE = "ffd100", "888888", "33ff66", "ffd633", "ff4d4d", "66ccff"
local function Col(hex, s) return "|cff" .. hex .. tostring(s) .. "|r" end
local function Ic(path, size) return "|T" .. path .. ":" .. (size or 14) .. ":" .. (size or 14) .. ":0:0:64:64:5:59:5:59|t" end

local OPTION_ICONS = {
	as = ICON .. "INV_Misc_Coin_02", ab = ICON .. "INV_Misc_Bag_08", lp = ICON .. "INV_Misc_Bag_10",
	oc = ICON .. "INV_Misc_Shell_03", ms = ICON .. "INV_Scroll_03", bf = ICON .. "INV_Misc_Bag_07",
	hb = ICON .. "INV_Misc_Bag_09", mq = ICON .. "INV_Letter_15",
}

-- Datum "JJJJ-MM-DD" → aantal dagen geleden (nil als onbekend).
local function DaysAgo(d)
	local y, m, dd = tostring(d or ""):match("^(%d+)-(%d+)-(%d+)$")
	if not y or not (date and time) then return nil end
	local n = date("*t")
	local now = time({ year = n.year, month = n.month, day = n.day, hour = 12 })
	local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12 })
	return math.max(0, math.floor((now - t) / 86400 + 0.5))
end

local function LastSeenText(d)
	local n = DaysAgo(d)
	if not n then return Col(C_GREY, T("never")) end
	if n == 0 then return Col(C_GREEN, T("today")) end
	if n == 1 then return Col(C_YELLOW, T("yesterday")) end
	if n < 14 then return T("%d days ago"):format(n) end
	return Col(C_GREY, T("%d days ago"):format(n))
end

local function ErrCount(r) local n = 0; for _, c in pairs(r.errors or {}) do n = n + c end; return n end

local devText = {} -- alle teksten van de laatste update (voor tests: ns.StatsDevText)
function ns.StatsDevText() return table.concat(devText, "\n") end

local function DevUpdate()
	local f = ns.statsDev
	if not f then return end
	devText = {}
	local nFS, nTX = 0, 0
	for _, o in ipairs(f.fsPool) do o:Hide() end
	for _, o in ipairs(f.txPool) do o:Hide() end
	local function FS(font, x, y, w, text, justify)
		nFS = nFS + 1
		local s = f.fsPool[nFS]
		if not s then s = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.fsPool[nFS] = s end
		s:SetFontObject(font or "GameFontHighlightSmall")
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
		s:SetWidth(w or 0)
		s:SetJustifyH(justify or "LEFT")
		if s.SetWordWrap then s:SetWordWrap(false) end
		s:SetText(text)
		s:Show()
		devText[#devText + 1] = tostring(text)
		return s
	end
	local function TX(x, y, w, h, path, r, g, b, a)
		nTX = nTX + 1
		local t = f.txPool[nTX]
		if not t then t = f:CreateTexture(nil, "ARTWORK"); f.txPool[nTX] = t end
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
		t:SetSize(w, h)
		if path then
			t:SetTexture(path)
			t:SetTexCoord(0, 1, 0, 1)
			if path:find("\\Icons\\") then t:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
			t:SetVertexColor(1, 1, 1, 1)
		else
			t:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
		end
		t:Show()
		return t
	end
	local function Header(y, icon, text)
		TX(16, y - 1, 16, 16, icon)
		FS("GameFontNormal", 38, y, 300, Col(C_GOLD, text))
		TX(16, y - 19, DEV_W - 32, 1, nil, 1, 0.82, 0, 0.35)
		return y - 26
	end
	local function Bar(x, y, w, frac, r, g, b)
		TX(x, y, w, 8, nil, 0, 0, 0, 0.5)
		if frac > 0 then TX(x, y, math.max(2, math.floor(w * math.min(1, frac))), 8, nil, r, g, b, 0.9) end
	end

	local all = ns.DB.collected or {}
	local rec = ns.DB.statsReceived or {}
	local t = { players = 0, opens = 0, minutes = 0, errors = 0, off = 0, quiet = 0 }
	for _, r in pairs(all) do
		t.players = t.players + 1
		t.opens, t.minutes, t.errors = t.opens + (r.opens or 0), t.minutes + (r.minutes or 0), t.errors + ErrCount(r)
		if r.off then t.off = t.off + 1
		elseif (DaysAgo(r.seen or r.last) or 99) >= 14 then t.quiet = t.quiet + 1 end
	end

	-- Kop: kanaal en laatste data
	local y = -32
	local ch = ChannelNumber() and ("#" .. ChannelNumber()) or T("not joined")
	FS("GameFontHighlightSmall", 16, y, 260, Col(C_GREY, T("Channel %s"):format(ch)))
	FS("GameFontHighlightSmall", DEV_W - 276, y, 260, Col(C_GREY, T("Last data: %s"):format(rec.last or T("never"))), "RIGHT")
	y = y - 18

	-- Vier tegels
	local tiles = {
		{ ICON .. "Spell_Holy_PrayerOfFortitude", t.players, T("Players"), C_BLUE },
		{ "Interface\\COMMON\\Indicator-Green", CountKeys(online), T("Online now"), C_GREEN },
		{ ICON .. "INV_Misc_PocketWatch_01", math.floor(t.minutes / 60), T("Hours played"), C_GOLD },
		{ ICON .. "Spell_Shadow_DeathScream", t.errors, T("Errors"), t.errors > 0 and C_RED or C_GREEN },
	}
	local tw = math.floor((DEV_W - 32 - 3 * 8) / 4)
	for i, tile in ipairs(tiles) do
		local x = 16 + (i - 1) * (tw + 8)
		TX(x, y, tw, 46, nil, 0, 0, 0, 0.45)
		TX(x + 6, y - 7, 32, 32, tile[1])
		FS("GameFontNormalHuge", x + 44, y - 6, tw - 50, Col(tile[4], tile[2]))
		FS("GameFontHighlightSmall", x + 44, y - 30, tw - 50, Col(C_GREY, tile[3]))
	end
	y = y - 54

	-- Kleine regel eronder
	local mini = {
		Ic(ICON .. "INV_Letter_15") .. " " .. T("%d packets"):format(rec.packets or 0),
		Ic(ICON .. "INV_Misc_Bag_08") .. " " .. T("%d bag opens"):format(t.opens),
		Ic("Interface\\RaidFrame\\ReadyCheck-NotReady") .. " " .. (t.off > 0 and Col(C_RED, T("%d stopped sharing"):format(t.off)) or T("%d stopped sharing"):format(0)),
		Ic(ICON .. "Spell_Nature_Sleep") .. " " .. (t.quiet > 0 and Col(C_YELLOW, T("%d not seen for 14+ days"):format(t.quiet)) or T("%d not seen for 14+ days"):format(0)),
	}
	local mw = math.floor((DEV_W - 32) / 4)
	for i, s in ipairs(mini) do FS("GameFontHighlightSmall", 16 + (i - 1) * mw, y, mw, s) end
	y = y - 24

	-- Spelers: online eerst, dan laatst gezien, dan hoe vaak gezien
	y = Header(y, ICON .. "Spell_Holy_PrayerOfFortitude", T("Players"))
	local list = {}
	for _, r in pairs(all) do list[#list + 1] = r end
	table.sort(list, function(a, b)
		local oa, ob = online[a.name] and 1 or 0, online[b.name] and 1 or 0
		if oa ~= ob then return oa > ob end
		local sa, sb = a.seen or a.last or "", b.seen or b.last or ""
		if sa ~= sb then return sa > sb end
		return (a.seenDays or 1) > (b.seenDays or 1)
	end)
	local maxDays = 1
	for _, r in ipairs(list) do maxDays = math.max(maxDays, r.seenDays or 1) end
	local cols = { name = 38, ver = 200, last = 262, days = 350, hours = 452, bags = 494, err = 536 }
	if #list == 0 then
		FS("GameFontHighlightSmall", 38, y, 400, Col(C_GREY, T("Waiting for players...")))
		y = y - 18
	else
		FS("GameFontHighlightSmall", cols.name, y, 150, Col(C_GREY, T("Name")))
		FS("GameFontHighlightSmall", cols.ver, y, 60, Col(C_GREY, T("Version")))
		FS("GameFontHighlightSmall", cols.last, y, 86, Col(C_GREY, T("Last seen")))
		FS("GameFontHighlightSmall", cols.days, y, 100, Col(C_GREY, T("Days seen")))
		FS("GameFontHighlightSmall", cols.hours - 6, y, 40, Col(C_GREY, T("Hours")), "RIGHT")
		FS("GameFontHighlightSmall", cols.bags - 6, y, 40, Col(C_GREY, T("Bags")), "RIGHT")
		FS("GameFontHighlightSmall", cols.err - 16, y, 40, Col(C_GREY, T("Errors")), "RIGHT")
		y = y - 16
		for i, r in ipairs(list) do
			if i > 12 then
				FS("GameFontHighlightSmall", cols.name, y, 300, Col(C_GREY, T("and %d more"):format(#list - 12)))
				y = y - 16
				break
			end
			if i % 2 == 1 then TX(14, y + 2, DEV_W - 28, 16, nil, 1, 1, 1, 0.05) end
			local status = r.off and "Interface\\RaidFrame\\ReadyCheck-NotReady"
				or online[r.name] and "Interface\\COMMON\\Indicator-Green"
				or (DaysAgo(r.seen or r.last) or 99) >= 14 and (ICON .. "Spell_Nature_Sleep")
				or "Interface\\COMMON\\Indicator-Yellow"
			TX(18, y + 1, 14, 14, status)
			local nm = tostring(r.name or "?"):gsub("%-.*$", "")
			FS("GameFontHighlightSmall", cols.name, y, 158, r.off and Col(C_GREY, nm) or nm)
			FS("GameFontHighlightSmall", cols.ver, y, 60, Col(r.version == ns.VERSION and C_GREEN or "ff9933", r.version or "?"))
			FS("GameFontHighlightSmall", cols.last, y, 86, r.off and Col(C_RED, T("Stopped sharing")) or LastSeenText(r.seen or r.last))
			local sd = r.seenDays or 1
			local frac = sd / maxDays
			Bar(cols.days, y - 3, 60, frac, frac >= 0.66 and 0.2 or frac >= 0.33 and 1 or 0.6, frac >= 0.66 and 1 or frac >= 0.33 and 0.84 or 0.6, frac >= 0.66 and 0.4 or frac >= 0.33 and 0.2 or 0.6)
			FS("GameFontHighlightSmall", cols.days + 66, y, 30, tostring(sd))
			FS("GameFontHighlightSmall", cols.hours - 6, y, 40, ("%.1f"):format((r.minutes or 0) / 60), "RIGHT")
			FS("GameFontHighlightSmall", cols.bags - 6, y, 40, tostring(r.opens or 0), "RIGHT")
			local ne = ErrCount(r)
			FS("GameFontHighlightSmall", cols.err - 16, y, 40, ne > 0 and Col(C_RED, ne) or Col(C_GREY, 0), "RIGHT")
			y = y - 16
		end
	end
	y = y - 8

	-- Opties en functies (alleen spelers met 1.12.2 of nieuwer sturen dit)
	local withOpts, on, groups, other, fe = 0, {}, 0, 0, {}
	for _, r in pairs(all) do
		if r.opts then
			withOpts = withOpts + 1
			for _, o in ipairs(OPTION_NAMES) do if r.opts[o[1]] == "1" then on[o[1]] = (on[o[1]] or 0) + 1 end end
			groups = groups + (tonumber(r.opts.g) or 0)
			if (tonumber(r.opts.ob) or 0) > 0 then other = other + 1 end
		end
		for k, v in pairs(r.f or {}) do fe[k] = (fe[k] or 0) + v end
	end
	if withOpts > 0 then
		y = Header(y, ICON .. "INV_Misc_Gear_01", T("Options on"))
		local half = math.floor((DEV_W - 32) / 2)
		for i, o in ipairs(OPTION_NAMES) do
			local x = 16 + ((i - 1) % 2) * half
			local yy = y - math.floor((i - 1) / 2) * 18
			local n = on[o[1]] or 0
			TX(x, yy + 1, 14, 14, OPTION_ICONS[o[1]])
			FS("GameFontHighlightSmall", x + 20, yy, half - 120, o[2] == "Auto Sell" and o[2] or T(o[2]))
			Bar(x + half - 96, yy - 3, 50, n / withOpts, 0.2, 0.8, 1)
			FS("GameFontHighlightSmall", x + half - 40, yy, 36, Col(n > 0 and C_BLUE or C_GREY, n .. "/" .. withOpts), "RIGHT")
		end
		y = y - math.ceil(#OPTION_NAMES / 2) * 18 - 4
		FS("GameFontHighlightSmall", 16, y, DEV_W - 32, Col(C_GREY, T("%.1f groups per player · %d with another bag addon"):format(groups / withOpts, other)))
		y = y - 22

		y = Header(y, ICON .. "INV_Misc_Note_01", T("Features used"))
		local money = tostring(fe.sg or 0)
		if GetCoinTextureString then
			local ok, m = pcall(GetCoinTextureString, fe.sg or 0)
			if ok and m then money = m end
		end
		local feats = {
			{ ICON .. "INV_Misc_Bag_10", T("Bags full panel"), fe.ls, T("%d picked up, %d left all"):format(fe.lp or 0, fe.ll or 0) },
			{ ICON .. "INV_Misc_Coin_02", "Auto Sell", fe.sl, money },
			{ ICON .. "INV_Letter_15", T("CFB mail"), fe.cm },
			{ ICON .. "INV_Misc_Bag_10_Blue", T("Bank & alts"), fe.bk },
			{ ICON .. "INV_Misc_Spyglass_03", T("Searches"), fe.sr },
			{ ICON .. "INV_Misc_Bag_08", T("Items dragged"), fe.dr },
			{ ICON .. "INV_Misc_Bag_07", T("Bags swapped"), fe.sw },
		}
		local half2 = math.floor((DEV_W - 32) / 2)
		for i, ft in ipairs(feats) do
			local x = 16 + ((i - 1) % 2) * half2
			local yy = y - math.floor((i - 1) / 2) * 18
			local n = ft[3] or 0
			TX(x, yy + 1, 14, 14, ft[1])
			FS("GameFontHighlightSmall", x + 20, yy, 110, n > 0 and ft[2] or Col(C_GREY, ft[2]))
			FS("GameFontHighlightSmall", x + 132, yy, 30, Col(n > 0 and C_GREEN or C_GREY, n))
			if ft[4] and n > 0 then FS("GameFontHighlightSmall", x + 166, yy, half2 - 170, Col(C_GREY, ft[4])) end
		end
		y = y - math.ceil(#feats / 2) * 18 - 8
	end

	-- Laatste gebeurtenissen
	y = Header(y, ICON .. "INV_Misc_PocketWatch_01", T("Recent"))
	if #devLines == 0 then
		FS("GameFontHighlightSmall", 16, y, DEV_W - 32, Col(C_GREY, T("Waiting for players...")))
		y = y - 16
	end
	for i = 1, math.min(6, #devLines) do
		FS("GameFontHighlightSmall", 16, y, DEV_W - 32, Col(i == 1 and "ffffff" or "aaaaaa", devLines[i]))
		y = y - 15
	end
	f:SetHeight(-y + 16)
end

local function BuildDev()
	if ns.statsDev or not ns.NewWindow then return end
	local f = ns.NewWindow("CarefreeBagStatsDev", T("CarefreeBag stats (dev)"), DEV_W, 200)
	f:SetPoint("TOP", UIParent, "TOP", 0, -120)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f.fsPool, f.txPool = {}, {}
	ns.statsDev = f
end

-- Regel in het dev-venster (en de log), venster zichtbaar maken.
local function Dev(msg)
	if not IsCollector() then return end
	table.insert(devLines, 1, (date and date("%H:%M ") or "") .. msg)
	while #devLines > 10 do table.remove(devLines) end
	ns.Note("stats", msg)
	BuildDev()
	if not ns.statsDev then return end
	if ns.DB.statsDevShow ~= false then ns.statsDev:Show() end -- vinkje in Advanced settings
	DevUpdate()
end

function ns.StatsDevShow()
	BuildDev()
	if ns.statsDev then ns.statsDev:Show(); DevUpdate() end
end

---------------------------------------------------------------------------
-- Verborgen kanaal en berichten
---------------------------------------------------------------------------

ChannelNumber = function()
	if not GetChannelName then return nil end
	local id = GetChannelName(CHANNEL_NAME)
	return (id and id > 0) and id or nil
end

local function Send(msg, kind, target)
	local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, kind, target)
	-- retail geeft een resultaatcode (0 = gelukt); afgeremd of geweigerd = in de log
	if not ok or (type(res) == "number" and res ~= 0) or res == false then
		ns.Note("stats", "send " .. msg:sub(1, 1) .. " " .. kind .. " failed: " .. tostring(res))
	end
end

local function SendChannel(msg)
	local id = ChannelNumber()
	if id then Send(msg, "CHANNEL", id) else ns.Note("stats", "no channel yet for '" .. msg:sub(1, 1) .. "'") end
end

local filtersOn = false
local function HideFromChat()
	if filtersOn or not ChatFrame_AddMessageEventFilter then return end
	filtersOn = true
	-- "Joined channel: CFBStats" en dergelijke niet tonen.
	local function notice(_, _, _, _, _, _, _, _, _, _, channelName)
		return type(channelName) == "string" and channelName:lower():find(CHANNEL_NAME:lower(), 1, true) ~= nil
	end
	for _, ev in ipairs({ "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
		pcall(ChatFrame_AddMessageEventFilter, ev, notice)
	end
end

local function RemoveFromChatFrames()
	if not ChatFrame_RemoveChannel then return end
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local f = _G["ChatFrame" .. i]
		if f then pcall(ChatFrame_RemoveChannel, f, CHANNEL_NAME) end
	end
end

local lastHello = -math.huge
local helloQueued = false
local function Hello()
	lastHello = Now()
	SendChannel("H|" .. tostring(MyFullName()))
end

-- Maker: af en toe laten weten dat je er bent (voor wie de ping miste).
local looping = false
local function HelloLoop()
	if not (IsCollector() and joined) then looping = false; return end
	Hello()
	C_Timer.After(HELLO_EVERY, HelloLoop)
end

local justAgreed = false
local function Join()
	if joined or not Supported() then return end
	if not (IsCollector() or Sharing()) then return end
	joined = true
	HideFromChat()
	if C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
	local join = JoinTemporaryChannel or JoinChannelByName
	-- Wachtwoord: niet geheim (staat in de code), maar zo kan niet iedereen het kanaal zomaar joinen.
	if join then pcall(join, CHANNEL_NAME, CHANNEL_PASS) end
	local tries = 0
	local function Ready()
		tries = tries + 1
		if not ChannelNumber() and tries < 4 then C_Timer.After(5, Ready); return end -- kanaal nog niet klaar
		RemoveFromChatFrames()
		ns.Note("stats", "channel " .. tostring(ChannelNumber()) .. (IsCollector() and " (collector)" or " (sharing)"))
		if IsCollector() then
			if ns.DB.statsDevShow ~= false then ns.StatsDevShow() end
			Hello()
			if not looping then looping = true; C_Timer.After(HELLO_EVERY, HelloLoop) end
		else
			if justAgreed then justAgreed = false; SendChannel("Y|" .. tostring(ns.VERSION)) end
			Stats() -- zorgt dat er een nummer is
			-- Met het nummer: zo weet de maker "laatst gezien" per speler (vanaf 1.12.3).
			SendChannel("P|" .. tostring(ns.VERSION) .. "|" .. tostring(ns.DB.statsID))
		end
	end
	C_Timer.After(2, Ready)
end
ns.StatsJoin = Join

---------------------------------------------------------------------------
-- Speler: pakketje maken en versturen
---------------------------------------------------------------------------

function ns.StatsPending()
	local s = ns.DB.stats
	if not s then return false end
	return (s.logins or 0) + (s.opens or 0) + (s.minutes or 0) + (s.mails or 0) > 0 or next(s.errors or {}) ~= nil
		or next(s.f or {}) ~= nil
end

local FEATURES = { "ls", "lp", "ll", "sl", "sg", "cm", "bk", "sr", "dr", "sw" }

-- Welke opties aan staan (1/0) en hoeveel eigen groepen, en andere tassen-addons.
local function OptionsLine(seq)
	local db = ns.DB
	local ch = ns.CharEntry and ns.CharEntry()
	local function b(v) return v and "1" or "0" end
	local nOther = 0
	if ns.OtherBagsLoaded then local ok, n = pcall(ns.OtherBagsLoaded); nOther = ok and n or 0 end
	return table.concat({ "O", seq, "as=" .. b(db.autoSell), "ab=" .. b(db.autoBags), "lp=" .. b(db.lootPanel ~= false),
		"oc=" .. b(db.autoOpenClams), "ms=" .. b(db.mailSubject ~= false), "bf=" .. b(db.bagFill),
		"hb=" .. b(ch and ch.hideBagSlots), "mq=" .. b(db.mailAlwaysAuto), "en=" .. b(db.enabled),
		"g=" .. #((ch and ch.cats) or {}), "ob=" .. nOther }, "|")
end

local function CharCount()
	local n = 0
	for _, c in pairs(ns.DB.chars or {}) do if not c.legacy then n = n + 1 end end
	return n
end

-- Huidige tellers naar een pakketje (outbox) en de tellers weer op nul.
local function MakeOutbox()
	AddMinutes()
	local s = Stats()
	local seq = tostring(math.random(100000, 999999))
	local toc = GetBuildInfo and select(4, GetBuildInfo()) or 0
	local lines = { table.concat({ "S", seq, "id=" .. ns.DB.statsID, "v=" .. tostring(ns.VERSION), "c=" .. tostring(toc),
		"l=" .. tostring(GetLocale and GetLocale() or "?"), "lang=" .. tostring(ns.DB.lang), "s=" .. tostring(s.since),
		"d=" .. (s.days or 0), "li=" .. (s.logins or 0), "o=" .. (s.opens or 0), "m=" .. (s.minutes or 0),
		"ma=" .. (s.mails or 0), "ch=" .. CharCount() }, "|") }
	lines[#lines + 1] = OptionsLine(seq)
	local fl = { "F", seq }
	for _, k in ipairs(FEATURES) do fl[#fl + 1] = k .. "=" .. ((s.f or {})[k] or 0) end
	lines[#lines + 1] = table.concat(fl, "|")
	local errs = {}
	for msg, n in pairs(s.errors or {}) do errs[#errs + 1] = { msg = msg, n = n } end
	table.sort(errs, function(a, b) return a.n > b.n end)
	local nE = 0
	for i = 1, math.min(MAX_ERRORS, #errs) do
		lines[#lines + 1] = ("E|%s|%d|%s"):format(seq, errs[i].n, errs[i].msg):sub(1, 250)
		nE = nE + 1
	end
	lines[#lines + 1] = "X|" .. seq .. "|" .. nE
	ns.DB.statsOutbox = { seq = seq, lines = lines }
	s.logins, s.opens, s.minutes, s.mails, s.days, s.errors, s.f = 0, 0, 0, 0, 0, {}, {}
	s.lastDay = Today() -- vandaag is al geteld
end

local lastSend = -math.huge
local sendPending = false
local collector = nil -- afzender van de laatste geldige "H": alleen zijn "A" telt
local function SendPacket()
	if not Sharing() or sendPending then return end
	-- Nooit vaker dan om de RESEND_AFTER (ook een nieuw pakketje niet): elke ping laat de maker
	-- "H" roepen, en dan zou iedereen in het kanaal tegelijk versturen.
	if Now() - lastSend < RESEND_AFTER then return end
	if not ns.DB.statsOutbox then
		if not ns.StatsPending() then return end
		MakeOutbox()
	end
	lastSend = Now()
	local box = ns.DB.statsOutbox
	ns.Note("stats", "sending " .. #box.lines .. " line(s), seq " .. box.seq)
	sendPending = true
	-- rustig na elkaar (WoW remt addon-berichten af)
	for i, line in ipairs(box.lines) do
		C_Timer.After(0.5 * i, function()
			if not Sharing() then sendPending = false; return end -- net uitgezet: niets meer versturen
			SendChannel(line)
			if i == #box.lines then sendPending = false end
		end)
	end
end

-- Is dit "H" echt van de maker? Hash van de genoemde naam, en precies dezelfde voornaam als de afzender.
local function ValidHello(claimed, sender)
	if not claimed or claimed == "" or not ns.STATS_COLLECTORS[ns.NameHash(claimed)] then return false end
	local first = (claimed:match("^[^%s%-]+") or ""):lower()
	return first ~= "" and ((sender or ""):match("^[^%s%-]+") or ""):lower() == first
end

---------------------------------------------------------------------------
-- Maker: ontvangen en bewaren
---------------------------------------------------------------------------

local incoming = {} -- [afzender] = { seq, fields, errors }

local function Fields(parts)
	local f = {}
	for i = 3, #parts do
		local k, v = parts[i]:match("^([%w]+)=(.*)$")
		if k then f[k] = v end
	end
	return f
end

-- Gezien vandaag: "laatst gezien" en "dagen gezien" (score: op hoeveel dagen online of data).
local function MarkSeen(r)
	local today = Today()
	if r.seen == today then return end
	-- Van vóór deze teller (nog niet geteld): een eerder gezien speler telt als 1 dag.
	if not r.seenDays then r.seenDays = (r.seen or r.last) and 1 or 0 end
	if (r.seen or r.last) == today then r.seen = today; return end
	r.seenDays = r.seenDays + 1
	r.seen = today
end

local function Store(sender, box)
	ns.DB.collected = ns.DB.collected or {}
	local f = box.fields
	local id = f.id or sender
	local r = ns.DB.collected[id]
	if not r then
		if CountKeys(ns.DB.collected) >= 5000 then ns.Note("stats", "collected is full, ignored " .. sender); return false end
		r = { first = Today(), logins = 0, opens = 0, minutes = 0, mails = 0, days = 0, errors = {}, seqs = {} }
		ns.DB.collected[id] = r
	end
	r.seqs = r.seqs or {}
	for _, s in ipairs(r.seqs) do if s == box.seq then return false end end -- al eerder ontvangen (ons "A" kwam niet aan)
	table.insert(r.seqs, box.seq)
	while #r.seqs > 20 do table.remove(r.seqs, 1) end
	MarkSeen(r)
	r.name, r.last, r.version, r.client, r.locale, r.lang, r.since, r.chars =
		sender, Today(), f.v, f.c, f.l, f.lang, f.s, tonumber(f.ch)
	for _, k in ipairs({ { "logins", "li" }, { "opens", "o" }, { "minutes", "m" }, { "mails", "ma" }, { "days", "d" } }) do
		r[k[1]] = (r[k[1]] or 0) + (tonumber(f[k[2]]) or 0)
	end
	for _, e in ipairs(box.errors) do
		r.errors[e.msg] = (r.errors[e.msg] or 0) + e.n
	end
	if box.opts then r.opts = box.opts end -- laatste stand telt
	if box.feat then
		r.f = r.f or {}
		for k, v in pairs(box.feat) do r.f[k] = (r.f[k] or 0) + (tonumber(v) or 0) end
	end
	local rec = ns.DB.statsReceived or { packets = 0 }
	ns.DB.statsReceived = rec
	rec.packets = (rec.packets or 0) + 1
	rec.last = date and date("%d-%m %H:%M") or "?"
	return true
end

-- Laatst gezien (online-ping): op nummer, oude versies (zonder nummer) op afzendernaam.
local function Seen(id, sender)
	local all = ns.DB.collected
	if not all then return end
	local r = id and id ~= "" and all[id]
	if not r then
		for _, x in pairs(all) do if x.name == sender and not x.off then r = x; break end end
	end
	if r then MarkSeen(r) end
end

local function OnCollector(msg, sender)
	local parts = {}
	for p in (msg .. "|"):gmatch("(.-)|") do parts[#parts + 1] = p end
	local kind, seq = parts[1], parts[2]
	if kind == "P" then
		Seen(parts[3], sender)
		if not online[sender] then
			online[sender] = true
			Dev(T("%s is online (sharing, v%s)"):format(sender, seq or "?"))
		end
		-- Net nog "H" geroepen? Dan één keer opnieuw zodra de 30 s om zijn (deze speler miste hem).
		local wait = HELLO_MIN - (Now() - lastHello)
		if wait <= 0 then Hello()
		elseif not helloQueued then
			helloQueued = true
			C_Timer.After(wait, function() helloQueued = false; Hello() end)
		end
	elseif kind == "Y" then
		Dev(T("%s said yes (v%s)"):format(sender, seq or "?"))
	elseif kind == "N" then
		-- Speler zette delen uit (vanaf 1.12.3): niet meer volgen, wel weten dat het een keuze was.
		local r = ns.DB.collected and seq and ns.DB.collected[seq]
		if r and r.name == sender then r.off = Today() end
		online[sender] = nil
		Dev(T("%s turned off sharing"):format(sender))
	elseif kind == "S" and seq then
		incoming[sender] = { seq = seq, fields = Fields(parts), errors = {} }
	elseif kind == "O" and incoming[sender] and incoming[sender].seq == seq then
		incoming[sender].opts = Fields(parts) -- opties aan/uit (vanaf 1.12.2)
	elseif kind == "F" and incoming[sender] and incoming[sender].seq == seq then
		incoming[sender].feat = Fields(parts) -- tellers per functie (vanaf 1.12.2)
	elseif kind == "E" and incoming[sender] and incoming[sender].seq == seq then
		local text = msg:match("^E|[^|]*|[^|]*|(.*)$") or ""
		table.insert(incoming[sender].errors, { n = tonumber(parts[3]) or 1, msg = text })
	elseif kind == "X" and incoming[sender] and incoming[sender].seq == seq then
		local box = incoming[sender]
		incoming[sender] = nil
		if #box.errors ~= (tonumber(parts[3]) or -1) then
			Dev(T("Incomplete data from %s"):format(sender))
			return
		end
		if Store(sender, box) then
			local nE = 0
			for _, e in ipairs(box.errors) do nE = nE + e.n end
			Dev(T("Data from %s: %d logins, %d bag opens, %d errors"):format(sender,
				tonumber(box.fields.li) or 0, tonumber(box.fields.o) or 0, nE))
		end
		SendChannel("A|" .. seq)
		Log("stats: received from " .. sender)
	end
end

local function OnSharer(msg, sender)
	local kind, rest = msg:match("^(%a)|?(.*)$")
	if kind == "H" then
		if not ValidHello(rest, sender) then
			ns.Note("stats", "ignored hello from " .. tostring(sender))
			return
		end
		collector = sender
		-- Na een rondroep in het kanaal niet iedereen tegelijk: even wachten.
		C_Timer.After(1 + math.random() * 20, SendPacket)
	elseif kind == "A" and sender == collector then
		local box = ns.DB.statsOutbox
		if box and box.seq == rest then
			ns.DB.statsOutbox = nil
			ns.Note("stats", "delivered, seq " .. rest)
		end
	end
end

ns.OnEvent("CHAT_MSG_ADDON", "stats", function(_, prefix, msg, _, sender)
	if prefix ~= PREFIX or type(msg) ~= "string" or not ns.DB then return end
	if ns.SameName and ns.SameName(sender and sender:match("^[^-]+") or "", MyFullName()) then return end -- van jezelf
	if IsCollector() then OnCollector(msg, sender or "?")
	elseif Sharing() then OnSharer(msg, sender or "?") end
end)

---------------------------------------------------------------------------
-- De vraag bij de start: kort, wat heb jij eraan, en ja zeggen
---------------------------------------------------------------------------

function ns.StatsInvite()
	return "|cffffd100" .. T("CarefreeBag is brand new and gets better every day, with your help!") .. "|r\n\n"
		.. T("Share errors and usage stats, and we can fix bugs much faster.")
		.. "\n\n|cffaaaaaa" .. T("Runs in the background, nothing changes for you. Change it anytime in the options.") .. "|r"
end

-- Volledige uitleg (hover bij het vinkje in de opties): wat er gaat, hoe, en dat de naam meegaat.
function ns.StatsDetails()
	return T("Sends errors, which options you use and how you use CarefreeBag (logins, bags opened, play time, mails, features) to the developer through a hidden in-game channel. Your character name is sent along, like with any in-game message. Turn it off and everything saved is deleted.")
end

function ns.SetStatsShare(v)
	ns.DB.statsShare = v and true or false
	Log("usage stats: " .. tostring(ns.DB.statsShare))
	if v then
		sessionStart = Now()
		CountDay()
		justAgreed = true
		Join()
	else
		-- Uit = niets meer bewaren of versturen, en het kanaal uit. Eerst nog één afmelding
		-- ("N|nummer"), zodat de maker weet dat het een keuze was en niet dat je gestopt bent.
		local id = ns.DB.statsID
		ns.DB.stats, ns.DB.statsOutbox, ns.DB.statsID, sessionStart = nil, nil, nil, nil
		if joined and not IsCollector() then
			joined = false
			if id and ChannelNumber() then Send("N|" .. id, "CHANNEL", ChannelNumber()) end
			C_Timer.After(1, function() -- even wachten, anders gaat de afmelding misschien niet meer weg
				if not joined and LeaveChannelByName then pcall(LeaveChannelByName, CHANNEL_NAME) end
			end)
		end
	end
	if ns.RefreshConfig then ns.RefreshConfig() end
end

local asked = false
local function Ask()
	if asked or ns.DB.statsShare ~= nil or not Supported() or IsCollector() or not ns.DB.enabled then return end
	if InCombatLockdown and InCombatLockdown() then C_Timer.After(30, Ask); return end
	asked = true
	StaticPopupDialogs["CAREFREEBAG_STATS"] = {
		text = ns.StatsInvite(),
		button1 = T("Sure, I like quick bug fixes"),
		button2 = T("No, rather not"),
		OnAccept = function() ns.SetStatsShare(true); Print(T("Thank you!")) end,
		OnCancel = function(_, _, reason) if reason == "clicked" then ns.SetStatsShare(false) end end,
		timeout = 0, whileDead = 1, hideOnEscape = false, preferredIndex = 3,
	}
	StaticPopup_Show("CAREFREEBAG_STATS")
end

---------------------------------------------------------------------------
-- Rapport voor de maker: /cfb stats
---------------------------------------------------------------------------

function ns.StatsReport()
	if IsCollector() then ns.StatsDevShow() end
	local all = ns.DB.collected
	if not all or not next(all) then Print(T("No usage stats received yet.")); return end
	local players, active, t = 0, 0, { logins = 0, opens = 0, minutes = 0, mails = 0 }
	local errors, versions = {}, {}
	local weekAgo = (date and time) and date("%Y-%m-%d", time() - 7 * 86400) or ""
	for _, r in pairs(all) do
		players = players + 1
		if (r.last or "") >= weekAgo then active = active + 1 end
		for k in pairs(t) do t[k] = t[k] + (r[k] or 0) end
		versions[r.version or "?"] = (versions[r.version or "?"] or 0) + 1
		for msg, n in pairs(r.errors or {}) do errors[msg] = (errors[msg] or 0) + n end
	end
	Print(T("Usage stats: %d players, %d active in the last 7 days."):format(players, active))
	print("  " .. T("Logins %d, bags opened %d, hours played %d, mails sent %d."):format(t.logins, t.opens, math.floor(t.minutes / 60), t.mails))
	print("  " .. Gone())
	local v = {}
	for ver, n in pairs(versions) do v[#v + 1] = ver .. " (" .. n .. ")" end
	table.sort(v)
	print("  " .. T("Versions: %s"):format(table.concat(v, ", ")))
	local list = {}
	for msg, n in pairs(errors) do list[#list + 1] = { msg = msg, n = n } end
	table.sort(list, function(a, b) return a.n > b.n end)
	for _, line in ipairs(Overview() or {}) do print("  " .. line) end
	if #list > 0 then print("  " .. T("Most seen errors:")) end
	for i = 1, math.min(5, #list) do print("    " .. list[i].n .. "x " .. list[i].msg) end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- Alleen echt inloggen telt als login, niet /reload.
ns.OnEvent("PLAYER_ENTERING_WORLD", "stats", function(_, isInitialLogin)
	if isInitialLogin and Sharing() then
		local s = Stats()
		s.logins = (s.logins or 0) + 1
	end
end)

ns.OnEvent("PLAYER_LOGIN", "stats", function()
	if Sharing() then
		sessionStart = Now()
		CountDay()
	end
	-- Tassen open tellen (het venster bestaat pas na de login van Start.lua).
	C_Timer.After(1, function()
		if ns.main and ns.main.HookScript then ns.main:HookScript("OnShow", function() Count("opens") end) end
	end)
	C_Timer.After(10, Join)
	C_Timer.After(12, Ask)
end)

ns.OnEvent("MAIL_SEND_SUCCESS", "stats", function() Count("mails") end)
ns.OnEvent("PLAYER_LOGOUT", "stats", AddMinutes)
