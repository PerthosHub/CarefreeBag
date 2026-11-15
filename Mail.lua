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
		if #BuildMailPlan() == 0 then ns.MailStop(T("all mail has been sent."))
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
	while #p.items > 0 and n < max do
		local it = table.remove(p.items, 1)
		local info = C_Container.GetContainerItemInfo(it.bag, it.slot)
		if info and info.itemID == it.itemID and not info.isLocked then
			C_Container.PickupContainerItem(it.bag, it.slot)
			ClickSendMailItemButton()
			ClearCursor()
			n = n + 1
		end
	end
	if n == 0 then return ns.MailPack() end
	ns.mail.current = { to = p.to, n = n }
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
	if #plan == 0 then Print(T("nothing to send.")); return end
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

local function MailButtonClick()
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

ns.UpdateMailPanel = function()
	if not ns.mailPanel or not ns.mailPanel:IsShown() then return end
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
	if not any and not ns.mail.busy then lines[1] = "|cff888888" .. T("Nothing to send.") .. "|r" end
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
end
