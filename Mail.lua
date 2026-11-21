-- CarefreeBag: Mail.lua
-- Post naar je alts bij de mailbox (per groep, met of zonder vraag).
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local CatByKey, Log, MailTarget, MakeButton, NewWindow, Print = ns.CatByKey, ns.Log, ns.MailTarget, ns.MakeButton, ns.NewWindow, ns.Print
local Scan, SectionList, T = ns.Scan, ns.SectionList, ns.T

---------------------------------------------------------------------------
-- Post naar je alts
---------------------------------------------------------------------------

ns.mail = { busy = false, plan = nil, step = false, skipped = {} }

-- Per categorie: wat gaat waarheen. De volgorde is die van je groepen.
-- Je krijgt per categorie de vraag of hij verstuurd moet worden.
-- Mag deze groep zonder vraag verstuurd worden? (per groep in te stellen)
-- ns.DB.mailAlwaysAuto: nil = nog niet gevraagd, true = alles zonder vragen, false = per groep.
function ns.MailAuto(key)
	if ns.DB.mailAlwaysAuto then return true end
	if key == "boe" then return ns.DB.boeMailAuto and true or false end
	local c = CatByKey(key)
	return c and c.mailAuto and true or false
end

local function BuildMailPlan()
	local items = Scan()
	local plan = {}
	for _, e in ipairs(items) do
		local to, sec = MailTarget(e)
		if to and not ns.mail.skipped[sec] then
			if not plan[sec] then
				local c = CatByKey(sec)
				plan[sec] = { key = sec, cat = c and c.name or "BoE", to = to, items = {}, auto = ns.MailAuto(sec) }
			end
			local p = plan[sec]
			p.items[#p.items + 1] = { bag = e.bag, slot = e.slot, itemID = e.itemID, name = e.name, count = e.count }
		end
	end
	-- Groepen die zonder vraag mogen eerst, daarna de groepen met een vraag.
	local list = {}
	for pass = 1, 2 do
		for _, sec in ipairs(SectionList()) do
			local p = plan[sec.key]
			if p and (p.auto == (pass == 1)) then list[#list + 1] = p end
		end
	end
	return list
end

local MailStart -- vooruit
-- Staat bovenaan een groep die zonder vraag mag? Dan meteen versturen.
function ns.MailAutoNext()
	if ns.mail.busy or ns.mail.step or not ns.mailPanel or not ns.mailPanel:IsShown() then return end
	local plan = BuildMailPlan()
	if plan[1] and plan[1].auto then
		Log("mail: " .. plan[1].cat .. " sent without asking")
		MailStart()
	end
end


function ns.MailStop(msg)
	ns.mail.busy = false
	ns.mail.current = nil
	if msg then Print(msg); Log("mail: " .. msg) end
	ns.UpdateMailPanel()
end

-- Volgende mail inpakken (max 12 items).
function ns.MailPack()
	local p = ns.mail.queue and ns.mail.queue[1]
	while p and #p.items == 0 do
		table.remove(ns.mail.queue, 1)
		p = ns.mail.queue[1]
	end
	if not p then
		local done = ns.mail.cat
		ns.mail.cat = nil
		if #BuildMailPlan() == 0 then
			ns.MailStop(T("all mail has been sent."))
			ns.MailFinish() -- verslag laten staan en de mailbox sluiten
		else
			ns.MailStop(T("%s sent."):format(done or ""))
			C_Timer.After(0.6, ns.MailAutoNext) -- volgende groep zonder vraag?
		end
		return false
	end
	if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2) end
	ClearCursor()
	local n = 0
	local max = ATTACHMENTS_MAX_SEND or 12
	local packed = {}
	while #p.items > 0 and n < max do
		local it = table.remove(p.items, 1)
		local info = C_Container.GetContainerItemInfo(it.bag, it.slot)
		if info and info.itemID == it.itemID and not info.isLocked then
			C_Container.PickupContainerItem(it.bag, it.slot)
			ClickSendMailItemButton()
			ClearCursor()
			n = n + 1
			packed[#packed + 1] = { name = it.name, count = it.count }
		end
	end
	if n == 0 then return ns.MailPack() end
	ns.mail.current = { to = p.to, n = n, cat = p.cat, items = packed }
	if SendMailNameEditBox then SendMailNameEditBox:SetText(p.to) end
	return true
end

function ns.MailSend()
	local c = ns.mail.current
	if not c then return end
	ns.mail.waiting = true
	Log("mail to '" .. c.to .. "': " .. c.n .. " item(s)")
	-- Geen tekst in de mail: dan verdwijnt hij vanzelf zodra je de bijlagen eruit haalt
	-- (een mail met tekst blijft staan als "brief").
	SendMail(c.to, "CarefreeBag: " .. c.n .. " item(s)", "")
end

-- Verstuurt alleen de categorie waar nu de vraag over staat.
MailStart = function()
	if ns.mail.busy then return end
	local plan = BuildMailPlan()
	if #plan == 0 then Log("mail: nothing to send"); return end
	ns.mail.queue = { plan[1] }
	ns.mail.cat = plan[1].cat
	ns.mail.busy = true
	if ns.MailPack() then
		if ns.mail.step then
			ns.UpdateMailPanel()
		else
			C_Timer.After(0.4, function() if ns.mail.busy then ns.MailSend() end end)
		end
	end
	ns.UpdateMailPanel()
end

-- Eerste keer dat er iets met een vraag verstuurd gaat worden: vragen of het voortaan
-- altijd zonder vragen mag (account-breed, aan te passen in de opties).
local function AskingFirstTime(plan)
	return ns.DB.mailAlwaysAuto == nil and not ns.mail.busy and plan[1] ~= nil and not plan[1].auto
end

---------------------------------------------------------------------------
-- Verslag na het versturen: de mailbox gaat dicht, het paneel blijft nog
-- 5 seconden staan met wat er verstuurd is. De knop telt af en sluit het ook.
---------------------------------------------------------------------------

local REPORT_SECONDS = 5

-- Na elke gelukte mail: onthouden wat er naar wie ging (dit mailboxbezoek).
function ns.MailSent(c)
	if not c then return end
	if ns.StatsCount then ns.StatsCount("cm") end -- gebruiksstatistieken (Stats.lua)
	ns.mail.report = ns.mail.report or {}
	local r
	for _, x in ipairs(ns.mail.report) do if x.cat == c.cat and x.to == c.to then r = x end end
	if not r then
		r = { cat = c.cat or "?", to = c.to, items = {} }
		table.insert(ns.mail.report, r)
	end
	for _, it in ipairs(c.items or {}) do r.items[#r.items + 1] = it end
end

-- Paneel weer aan de mailbox vastmaken (voor het volgende bezoek).
local function Reattach()
	local p = ns.mailPanel
	if not p or not MailFrame then return end
	p:SetParent(MailFrame)
	p:ClearAllPoints()
	p:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
end

function ns.MailReportClose()
	local p = ns.mailPanel
	if not p or not p.reporting then return end
	p.reporting, p.reportToken = false, nil
	ns.mail.report = nil
	-- Ook als de mailbox open bleef (post in de inbox): er valt niets meer te versturen, dus weg.
	p.boxOpen = nil
	p:Hide()
	Reattach()
end

-- Is er post met iets erin (items of goud) om op te halen? Lege brieven tellen niet.
local function InboxHasLoot()
	if not GetInboxNumItems then return false end
	local okN, n = pcall(GetInboxNumItems)
	n = okN and tonumber(n) or 0
	for i = 1, n do
		local okH, _, _, _, _, money, _, _, hasItem = pcall(GetInboxHeaderInfo, i)
		if not okH then return n > 0 end -- onbekend: voorzichtig, mailbox open laten
		if (money or 0) > 0 or (hasItem and hasItem ~= 0) then return true end
	end
	return false
end

local function ReportTick(token, left)
	local p = ns.mailPanel
	if not p or p.reportToken ~= token then return end -- al gesloten of opnieuw begonnen
	if left <= 0 then ns.MailReportClose(); return end
	p.send:SetText(T("Close (%d)"):format(left))
	C_Timer.After(1, function() ReportTick(token, left - 1) end)
end

-- Alles is verstuurd: verslag tonen, mailbox dicht, aftellen.
function ns.MailFinish()
	local p = ns.mailPanel
	local report = ns.mail.report
	if not p or not report or #report == 0 then return end
	local lines = { "|cff33ff99" .. T("Sent:") .. "|r", " " }
	local shown, more = 0, 0
	for _, r in ipairs(report) do
		lines[#lines + 1] = "|cffffd100" .. r.cat .. "|r > |cff66ccff" .. r.to .. "|r"
		for _, it in ipairs(r.items) do
			if shown < 10 then
				lines[#lines + 1] = "  " .. (it.name or "?") .. ((it.count or 1) > 1 and (" x" .. it.count) or "")
				shown = shown + 1
			else
				more = more + 1
			end
		end
	end
	if more > 0 then lines[#lines + 1] = "  |cff888888+" .. more .. " " .. T("more") .. "|r" end
	-- Post met items of goud in je inbox (bijv. van het AH)? Dan blijft de mailbox open om die op te halen.
	local closeBox = not InboxHasLoot()
	if closeBox then
		-- Los van de mailbox, op dezelfde plek op het scherm, zodat het blijft staan.
		-- GetLeft/GetTop zijn in de schaal van het paneel: omrekenen naar die van UIParent.
		local x, y = p:GetLeft(), p:GetTop()
		local k = 1
		local s1, s2 = p:GetEffectiveScale(), UIParent:GetEffectiveScale()
		if s1 and s2 and s2 > 0 then k = s1 / s2 end
		p:SetParent(UIParent)
		p:ClearAllPoints()
		if x and y then p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x * k, y * k)
		else p:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
	end
	p.boxOpen = not closeBox
	p.reporting = true
	p.reportToken = {}
	p.text:SetText(table.concat(lines, "\n"))
	p.skip:Hide()
	p.send:SetEnabled(true)
	p:SetHeight(math.max(120, p.text:GetStringHeight() + 80))
	p:Show()
	if closeBox then
		Log("mail: report shown, mailbox closed")
		-- Het venster sluiten (dat beëindigt ook het gesprek met de mailbox); lukt dat niet, dan CloseMail.
		if HideUIPanel and MailFrame then pcall(HideUIPanel, MailFrame) end
		if MailFrame and MailFrame:IsShown() and CloseMail then pcall(CloseMail) end
	else
		-- Post om op te halen: mailbox blijft open, en meteen naar de inbox (niet op "Send Mail" blijven staan).
		Log("mail: report shown, mailbox stays open on the inbox (mail to pick up)")
		if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 1) end
	end
	ReportTick(p.reportToken, REPORT_SECONDS)
end

local function MailButtonClick()
	if ns.mailPanel and ns.mailPanel.reporting then ns.MailReportClose(); return end
	if AskingFirstTime(BuildMailPlan()) then
		ns.DB.mailAlwaysAuto = true
		Log("mail: always without asking (first mailbox)")
		Print(T("Mail is sent without asking from now on. You can change this in the options."))
		if ns.RefreshConfig then ns.RefreshConfig() end
		MailStart()
		return
	end
	if ns.mail.busy and ns.mail.step then
		-- Stapmodus: elke klik doet één stap (inpakken of versturen).
		if ns.mail.current and not ns.mail.waiting then ns.MailSend()
		elseif not ns.mail.current then ns.MailPack() end
		ns.UpdateMailPanel()
		return
	end
	if ns.mail.busy then ns.MailStop(T("stopped.")) return end
	MailStart()
end

local function MailSkip()
	if ns.mail.busy then return end
	local plan = BuildMailPlan()
	if AskingFirstTime(plan) then
		ns.DB.mailAlwaysAuto = false
		Log("mail: keep asking (first mailbox)")
		if ns.RefreshConfig then ns.RefreshConfig() end
		ns.UpdateMailPanel()
		return
	end
	if plan[1] then ns.mail.skipped[plan[1].key] = true end
	ns.UpdateMailPanel()
end

-- Rechtsklik op een item bij de mailbox (tabblad Versturen): WoW voegt één stapel toe.
-- CarefreeBag toont alle stapels van een item als één vakje, dus voegen wij de rest erbij
-- (zolang er vakjes in de mail vrij zijn). Bijv. 60 cloth = 3 x 20 in de mail.
local function FreeAttachments()
	local max, used = ATTACHMENTS_MAX_SEND or 12, 0
	if not GetSendMailItem then return max end
	for i = 1, max do
		local ok, name = pcall(GetSendMailItem, i)
		if ok and name then used = used + 1 end
	end
	return max - used
end

function ns.MailAttachRest(g, bag, slot)
	if not (SendMailFrame and SendMailFrame:IsShown()) or ns.mail.busy then return end
	if (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) or (IsAltKeyDown and IsAltKeyDown()) then return end
	if not g or not g.slots or #g.slots < 2 then return end
	local rest = {}
	for _, e in ipairs(g.slots) do
		if not (e.bag == bag and e.slot == slot) then rest[#rest + 1] = { bag = e.bag, slot = e.slot, itemID = e.itemID } end
	end
	-- Even wachten tot WoW zijn eigen stapel heeft toegevoegd.
	C_Timer.After(0.2, function()
		if not (SendMailFrame and SendMailFrame:IsShown()) or CursorHasItem() then return end
		local n = 0
		for _, it in ipairs(rest) do
			if FreeAttachments() <= 0 then break end
			local info = C_Container.GetContainerItemInfo(it.bag, it.slot)
			if info and info.itemID == it.itemID and not info.isLocked then
				C_Container.PickupContainerItem(it.bag, it.slot)
				ClickSendMailItemButton()
				if CursorHasItem() then ClearCursor() end
				n = n + 1
			end
		end
		if n > 0 then Log("mail: right-click added " .. n .. " more stack(s) of " .. tostring(rest[1] and rest[1].itemID)) end
	end)
end

ns.UpdateMailPanel = function()
	if not ns.mailPanel or not ns.mailPanel:IsShown() or ns.mailPanel.reporting then return end
	ns.mailPanel.emptyHidden = nil
	local plan = ns.mail.busy and ns.mail.queue or BuildMailPlan()
	if AskingFirstTime(plan) then
		local to = {}
		for _, q in ipairs(plan) do to[#to + 1] = "|cffffd100" .. q.cat .. "|r > |cff66ccff" .. q.to .. "|r" end
		ns.mailPanel.text:SetText(T("Send mail to your alts automatically from now on, without asking?") .. "\n \n"
			.. table.concat(to, "\n") .. "\n \n|cff888888" .. T("You can change this in the options.") .. "|r")
		ns.mailPanel.send:SetText(T("Yes, always"))
		ns.mailPanel.send:SetEnabled(true)
		ns.mailPanel.skip:SetText(T("No, ask me"))
		ns.mailPanel.skip:Show()
		ns.mailPanel:SetHeight(math.max(120, ns.mailPanel.text:GetStringHeight() + 80))
		return
	end
	ns.mailPanel.skip:SetText(T("Skip"))
	local lines = {}
	local p = plan[1]
	local any = p ~= nil and #p.items > 0
	if any then
		-- Witte vraag, categorie in goud, ontvanger in blauw.
		lines[#lines + 1] = T("Send everything in %s to %s?"):format("|cffffd100" .. p.cat .. "|r", "|cff66ccff" .. p.to .. "|r")
		lines[#lines + 1] = " "
		for i = 1, math.min(8, #p.items) do
			local it = p.items[i]
			lines[#lines + 1] = "  " .. it.name .. (it.count > 1 and (" x" .. it.count) or "")
		end
		if #p.items > 8 then lines[#lines + 1] = "  |cff888888+" .. (#p.items - 8) .. " " .. T("more") .. "|r" end
		if not ns.mail.busy and #plan > 1 then
			local nxt = {}
			for i = 2, #plan do nxt[#nxt + 1] = plan[i].cat end
			lines[#lines + 1] = " "
			lines[#lines + 1] = "|cff888888" .. T("After that: %s"):format(table.concat(nxt, ", ")) .. "|r"
		end
	end
	-- Niets te versturen: paneel weg (komt terug zodra er iets te versturen is, zie Start.lua).
	if not any and not ns.mail.busy then
		ns.mailPanel.text:SetText("")
		ns.mailPanel.send:SetText(T("Yes, send")) -- klaar voor de volgende keer
		ns.mailPanel.emptyHidden = true -- door ons weggehaald (niet door jou met het kruisje)
		ns.mailPanel:Hide()
		return
	end
	if ns.mail.busy then
		lines[#lines + 1] = " "
		lines[#lines + 1] = "|cff33ff99" .. (ns.mail.current and T("Busy: mail to %s..."):format(ns.mail.current.to) or T("Busy...")) .. "|r"
	end
	ns.mailPanel.text:SetText(table.concat(lines, "\n"))
	if ns.mail.busy and ns.mail.step then
		ns.mailPanel.send:SetText(ns.mail.current and T("Send this mail") or T("Pack next mail"))
	elseif ns.mail.busy then
		ns.mailPanel.send:SetText("Stop")
	else
		ns.mailPanel.send:SetText(T("Yes, send"))
	end
	ns.mailPanel.send:SetEnabled(any or ns.mail.busy)
	ns.mailPanel.skip:SetShown(any and not ns.mail.busy)
	ns.mailPanel:SetHeight(math.max(120, ns.mailPanel.text:GetStringHeight() + 80))
end

function ns.BuildMailPanel()
	if not MailFrame then return end
	ns.mailPanel = NewWindow("CarefreeBagMailPanel", T("CarefreeBag mail"), 260, 160)
	ns.mailPanel:SetParent(MailFrame)
	ns.mailPanel:ClearAllPoints()
	ns.mailPanel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
	ns.mailPanel:SetMovable(false)
	ns.mailPanel.text = ns.mailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	ns.mailPanel.text:SetPoint("TOPLEFT", ns.mailPanel, "TOPLEFT", ns.PAD, -30)
	ns.mailPanel.text:SetWidth(260 - 2 * ns.PAD)
	ns.mailPanel.text:SetJustifyH("LEFT")
	ns.mailPanel.send = MakeButton(ns.mailPanel, T("Yes, send"), 110)
	ns.mailPanel.send:SetPoint("BOTTOMLEFT", ns.mailPanel, "BOTTOMLEFT", ns.PAD, 16)
	ns.mailPanel.send:SetScript("OnClick", MailButtonClick)
	ns.mailPanel.skip = MakeButton(ns.mailPanel, T("Skip"), 110)
	ns.mailPanel.skip:SetPoint("BOTTOMRIGHT", ns.mailPanel, "BOTTOMRIGHT", -ns.PAD, 16)
	ns.mailPanel.skip:SetScript("OnClick", MailSkip)

	ns.mailPanel:SetScript("OnShow", function() ns.UpdateMailPanel() end)
	-- Kruisje tijdens het verslag: netjes afsluiten en weer aan de mailbox vastmaken.
	ns.mailPanel:HookScript("OnHide", function(self) if self.reporting then ns.MailReportClose() end end)
end

---------------------------------------------------------------------------
-- Onderwerp vanzelf invullen (issue #20) als je zelf iets in een mail stopt:
-- één soort item = de itemnaam, verschillende items = "Multiple items",
-- geld = het bedrag (met items: "Linen Cloth + 12 Gold"). Rembours telt niet als geld.
-- Heb je zelf iets getypt, dan blijft dat staan (tot de mail weg is).
---------------------------------------------------------------------------

local lastSubject -- wat wij het laatst invulden

local function SendMoney()
	if not (SendMailMoney and MoneyInputFrame_GetCopper) then return 0 end
	if SendMailCODButton and SendMailCODButton.GetChecked and SendMailCODButton:GetChecked() then return 0 end
	local ok, c = pcall(MoneyInputFrame_GetCopper, SendMailMoney)
	return ok and tonumber(c) or 0
end

local function CoinText(copper)
	if GetCoinText then
		local ok, s = pcall(GetCoinText, copper, " ")
		if ok and s and s ~= "" then return s end
	end
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local parts = {}
	if g > 0 then parts[#parts + 1] = g .. "g" end
	if s > 0 then parts[#parts + 1] = s .. "s" end
	if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
	return table.concat(parts, " ")
end

function ns.MailSubjectUpdate()
	local box = SendMailSubjectEditBox
	if not box or not GetSendMailItem or not ns.DB.enabled or ns.DB.mailSubject == false or ns.mail.busy then return end
	-- Per itemnaam het totaal (stapels van hetzelfde item opgeteld), in de volgorde van de mail.
	local names, order = {}, {}
	for i = 1, ATTACHMENTS_MAX_SEND or 12 do
		local ok, name, _, _, n = pcall(GetSendMailItem, i)
		if ok and name then
			if not names[name] then names[name] = 0; order[#order + 1] = name end
			names[name] = names[name] + (tonumber(n) or 1)
		end
	end
	local now = box:GetText() or ""
	-- Alleen overschrijven wat wij (of WoW zelf, met een itemnaam) erin zetten; jouw eigen tekst blijft.
	if now ~= "" and now ~= lastSubject and not names[now] then return end
	-- Geld eerst, dan de items met aantal ("12 Gold + Linen Cloth x20, Copper Ore x10").
	-- Meer dan 3 soorten, of past het niet (max. 64 tekens): "Multiple items".
	local parts = {}
	local money = SendMoney()
	if money > 0 then parts[1] = CoinText(money) end
	if #order > 0 then
		local list = {}
		for _, name in ipairs(order) do list[#list + 1] = name .. (names[name] > 1 and (" x" .. names[name]) or "") end
		local items = table.concat(list, ", ")
		local full = parts[1] and (parts[1] .. " + " .. items) or items
		local letters = select(2, full:gsub("[^\128-\191]", "")) -- letters, niet bytes (UTF-8)
		if #order > 3 or letters > 64 then items = T("Multiple items") end
		parts[#parts + 1] = items
	end
	local subject = table.concat(parts, " + ")
	if subject ~= now then box:SetText(subject) end
	lastSubject = box:GetText() or subject -- WoW kapt lange onderwerpen af: onthoud wat er echt staat
end

-- Na Blizzards eigen bijwerken van het venster (dat zet soms zelf een itemnaam neer).
local function SubjectSoon() C_Timer.After(0, ns.MailSubjectUpdate) end

local subjectHooked = false
local function HookSubject()
	if subjectHooked then return end
	subjectHooked = true
	for _, n in ipairs({ "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper", "SendMailCODButton", "SendMailSendMoneyButton" }) do
		local f = _G[n]
		if f and f.HookScript then
			pcall(f.HookScript, f, (n:find("Button$") and "OnClick" or "OnTextChanged"), SubjectSoon)
		end
	end
end

ns.OnEvent("MAIL_SEND_INFO_UPDATE", "mail", SubjectSoon)

---------------------------------------------------------------------------
-- Events: mailbox
---------------------------------------------------------------------------

ns.OnEvent("MAIL_SHOW", "mail", function()
	ns.mailOpen = true -- geen stapels samenvoegen zolang de mailbox open is (Chores.lua)
	ns.mail.step = false -- nieuw bezoek: eerst weer automatisch proberen
	ns.mail.skipped = {}  -- en alle categorieën worden weer gevraagd
	ns.MailReportClose()  -- oud verslag nog in beeld: weg, paneel weer aan de mailbox
	ns.mail.report = nil
	if not ns.DB.enabled then return end
	HookSubject()
	if not ns.mailPanel then ns.Try("mail", ns.BuildMailPanel) end
	if ns.mailPanel then ns.mailPanel:Show(); ns.UpdateMailPanel() end
	C_Timer.After(0.5, ns.MailAutoNext)
end)

ns.OnEvent("MAIL_CLOSED", "mail", function()
	ns.mailOpen = false
	if ns.mail.busy then ns.MailStop(T("mailbox closed, stopped.")) end
	-- Tijdens het verslag blijft het paneel staan (het telt zelf af).
	if ns.mailPanel and not ns.mailPanel.reporting then ns.mailPanel:Hide() end
end)

ns.OnEvent("MAIL_SEND_SUCCESS", "mail", function()
	lastSubject = nil -- mail is weg: de volgende begint weer leeg
	if not (ns.mail.busy and ns.mail.waiting) then return end
	ns.mail.waiting = false
	ns.MailSent(ns.mail.current)
	ns.mail.current = nil
	if ns.mail.step then
		ns.UpdateMailPanel()
	else
		C_Timer.After(0.6, function()
			if ns.mail.busy and ns.MailPack() then
				C_Timer.After(0.4, function() if ns.mail.busy then ns.MailSend() end end)
			end
			ns.UpdateMailPanel()
		end)
	end
end)

ns.OnEvent("MAIL_FAILED", "mail", function()
	Log("MAIL_FAILED" .. (ns.mail.current and (" (to '" .. ns.mail.current.to .. "')") or ""))
	if ns.mail.busy then
		ns.mail.waiting = false
		ns.MailStop(T("sending failed (not enough gold or wrong name?). The items are still in the mail window."))
	end
end)

ns.OnEvent("UI_ERROR_MESSAGE", "mail", function(_, _, msg)
	if ns.mail.busy then Log("game message during mail: " .. tostring(msg)) end
end)

-- WoW staat automatisch versturen niet toe: vanaf nu één klik per stap.
local function MailBlocked(_, addon)
	if addon ~= ADDON or not ns.mail.busy or ns.mail.step then return end
	ns.mail.step = true
	ns.mail.waiting = false
	Print(T("WoW blocks automatic sending. Click the button for each mail this time."))
	ns.UpdateMailPanel()
end
ns.OnEvent("ADDON_ACTION_BLOCKED", "mail", MailBlocked)
ns.OnEvent("ADDON_ACTION_FORBIDDEN", "mail", MailBlocked)

-- Paneel bijwerken; was het weg omdat er niets te versturen was, misschien nu wel (post opgehaald).
ns.OnEvent("BAG_UPDATE_DELAYED", "mail", function()
	if not ns.mailPanel or ns.mail.busy then return end
	if ns.mailPanel:IsShown() then ns.UpdateMailPanel()
	elseif ns.mailPanel.emptyHidden and MailFrame and MailFrame:IsShown() then ns.mailPanel:Show() end
end)
