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
--   * Speler roept na het joinen "P|versie" (online), na "ja" ook "Y|versie" (net toegestemd).
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

local function DevUpdate()
	local f = ns.statsDev
	if not f then return end
	local ch = ChannelNumber() and ("#" .. ChannelNumber()) or T("not joined")
	local head = T("Channel: %s · online now: %d · players: %d"):format(ch, CountKeys(online), CountKeys(ns.DB.collected))
	-- Alles wat ooit binnenkwam (alle sessies), niet alleen deze sessie
	local t = { logins = 0, opens = 0, minutes = 0, errors = 0 }
	for _, r in pairs(ns.DB.collected or {}) do
		t.logins, t.opens, t.minutes = t.logins + (r.logins or 0), t.opens + (r.opens or 0), t.minutes + (r.minutes or 0)
		for _, n in pairs(r.errors or {}) do t.errors = t.errors + n end
	end
	local rec = ns.DB.statsReceived or {}
	local total = T("All time: %d packets, %d logins, %d bag opens, %d hours played, %d errors"):format(
		rec.packets or 0, t.logins, t.opens, math.floor(t.minutes / 60), t.errors)
	local last = T("Last data: %s"):format(rec.last or T("never"))
	local body = #devLines > 0 and table.concat(devLines, "\n") or ("|cff888888" .. T("Waiting for players...") .. "|r")
	f.text:SetText("|cffffd100" .. head .. "|r\n" .. total .. "\n|cff888888" .. last .. "|r\n\n" .. body)
	f:SetHeight(math.max(110, f.text:GetStringHeight() + 50))
end

local function BuildDev()
	if ns.statsDev or not ns.NewWindow then return end
	local f = ns.NewWindow("CarefreeBagStatsDev", T("CarefreeBag stats (dev)"), 340, 110)
	f:SetPoint("TOP", UIParent, "TOP", 0, -120)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -30)
	f.text:SetWidth(308)
	f.text:SetJustifyH("LEFT")
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
			SendChannel("P|" .. tostring(ns.VERSION))
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
	s.logins, s.opens, s.minutes, s.mails, s.days, s.errors = 0, 0, 0, 0, 0, {}
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
	r.name, r.last, r.version, r.client, r.locale, r.lang, r.since, r.chars =
		sender, Today(), f.v, f.c, f.l, f.lang, f.s, tonumber(f.ch)
	for _, k in ipairs({ { "logins", "li" }, { "opens", "o" }, { "minutes", "m" }, { "mails", "ma" }, { "days", "d" } }) do
		r[k[1]] = (r[k[1]] or 0) + (tonumber(f[k[2]]) or 0)
	end
	for _, e in ipairs(box.errors) do
		r.errors[e.msg] = (r.errors[e.msg] or 0) + e.n
	end
	local rec = ns.DB.statsReceived or { packets = 0 }
	ns.DB.statsReceived = rec
	rec.packets = (rec.packets or 0) + 1
	rec.last = date and date("%d-%m %H:%M") or "?"
	return true
end

local function OnCollector(msg, sender)
	local parts = {}
	for p in (msg .. "|"):gmatch("(.-)|") do parts[#parts + 1] = p end
	local kind, seq = parts[1], parts[2]
	if kind == "P" then
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
	elseif kind == "S" and seq then
		incoming[sender] = { seq = seq, fields = Fields(parts), errors = {} }
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
	return T("Sends errors and how you use CarefreeBag (logins, bags opened, play time, mails) to the developer through a hidden in-game channel. Your character name is sent along, like with any in-game message. Turn it off and everything saved is deleted.")
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
		-- Uit = niets meer bewaren of versturen, en het kanaal uit.
		ns.DB.stats, ns.DB.statsOutbox, ns.DB.statsID, sessionStart = nil, nil, nil, nil
		if joined and not IsCollector() then
			joined = false
			if LeaveChannelByName then pcall(LeaveChannelByName, CHANNEL_NAME) end
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
	local v = {}
	for ver, n in pairs(versions) do v[#v + 1] = ver .. " (" .. n .. ")" end
	table.sort(v)
	print("  " .. T("Versions: %s"):format(table.concat(v, ", ")))
	local list = {}
	for msg, n in pairs(errors) do list[#list + 1] = { msg = msg, n = n } end
	table.sort(list, function(a, b) return a.n > b.n end)
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
