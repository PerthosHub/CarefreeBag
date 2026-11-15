-- CarefreeBag: Mail.lua
-- Post naar je alts bij de mailbox (per groep, met of zonder vraag).
-- Alle bestanden delen één omgeving (zie Env.lua). De namen hieronder maakt dit bestand.
local _, ns = ...
setfenv(1, ns.Env(
	"MailAuto", "BuildMailPlan", "MailStart", "MailAutoNext", "UpdateMailPanel", "MailStop",
	"MailPack", "MailSend", "MailButtonClick", "MailSkip", "BuildMailPanel"
))

---------------------------------------------------------------------------
-- Post naar je alts
---------------------------------------------------------------------------

mail = { busy = false, plan = nil, step = false, skipped = {} }

-- Per categorie: wat gaat waarheen. De volgorde is die van je groepen.
-- Je krijgt per categorie de vraag of hij verstuurd moet worden.
-- Mag deze groep zonder vraag verstuurd worden? (per groep in te stellen)
function MailAuto(key)
	if key == "boe" then return DB.boeMailAuto and true or false end
	local c = CatByKey(key)
	return c and c.mailAuto and true or false
end

function BuildMailPlan()
	local items = Scan()
	local plan = {}
	for _, e in ipairs(items) do
		local to, sec = MailTarget(e)
		if to and not mail.skipped[sec] then
			if not plan[sec] then
				local c = CatByKey(sec)
				plan[sec] = { key = sec, cat = c and c.name or "BoE", to = to, items = {}, auto = MailAuto(sec) }
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

-- vooruit (MailStart)
-- Staat bovenaan een groep die zonder vraag mag? Dan meteen versturen.
function MailAutoNext()
	if mail.busy or mail.step or not mailPanel or not mailPanel:IsShown() then return end
	local plan = BuildMailPlan()
	if plan[1] and plan[1].auto then
		Log("mail: " .. plan[1].cat .. " sent without asking")
		MailStart()
	end
end

-- vooruit (UpdateMailPanel)

function MailStop(msg)
	mail.busy = false
	mail.current = nil
	if msg then Print(msg); Log("mail: " .. msg) end
	UpdateMailPanel()
end

-- Volgende mail inpakken (max 12 items).
function MailPack()
	local p = mail.queue and mail.queue[1]
	while p and #p.items == 0 do
		table.remove(mail.queue, 1)
		p = mail.queue[1]
	end
	if not p then
		local done = mail.cat
		mail.cat = nil
		if #BuildMailPlan() == 0 then MailStop(T("all mail has been sent."))
		else
			MailStop(T("%s sent."):format(done or ""))
			C_Timer.After(0.6, MailAutoNext) -- volgende groep zonder vraag?
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
	if n == 0 then return MailPack() end
	mail.current = { to = p.to, n = n }
	if SendMailNameEditBox then SendMailNameEditBox:SetText(p.to) end
	return true
end

function MailSend()
	local c = mail.current
	if not c then return end
	mail.waiting = true
	Log("mail to '" .. c.to .. "': " .. c.n .. " item(s)")
	-- Geen tekst in de mail: dan verdwijnt hij vanzelf zodra je de bijlagen eruit haalt
	-- (een mail met tekst blijft staan als "brief").
	SendMail(c.to, "CarefreeBag: " .. c.n .. " item(s)", "")
end

-- Verstuurt alleen de categorie waar nu de vraag over staat.
MailStart = function()
	if mail.busy then return end
	local plan = BuildMailPlan()
	if #plan == 0 then Print(T("nothing to send.")); return end
	mail.queue = { plan[1] }
	mail.cat = plan[1].cat
	mail.busy = true
	if MailPack() then
		if mail.step then
			UpdateMailPanel()
		else
			C_Timer.After(0.4, function() if mail.busy then MailSend() end end)
		end
	end
	UpdateMailPanel()
end

function MailButtonClick()
	if mail.busy and mail.step then
		-- Stapmodus: elke klik doet één stap (inpakken of versturen).
		if mail.current and not mail.waiting then MailSend()
		elseif not mail.current then MailPack() end
		UpdateMailPanel()
		return
	end
	if mail.busy then MailStop(T("stopped.")) return end
	MailStart()
end

function MailSkip()
	if mail.busy then return end
	local plan = BuildMailPlan()
	if plan[1] then mail.skipped[plan[1].key] = true end
	UpdateMailPanel()
end

UpdateMailPanel = function()
	if not mailPanel or not mailPanel:IsShown() then return end
	local plan = mail.busy and mail.queue or BuildMailPlan()
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
		if not mail.busy and #plan > 1 then
			local nxt = {}
			for i = 2, #plan do nxt[#nxt + 1] = plan[i].cat end
			lines[#lines + 1] = " "
			lines[#lines + 1] = "|cff888888" .. T("After that: %s"):format(table.concat(nxt, ", ")) .. "|r"
		end
	end
	if not any and not mail.busy then lines[1] = "|cff888888" .. T("Nothing to send.") .. "|r" end
	if mail.busy then
		lines[#lines + 1] = " "
		lines[#lines + 1] = "|cff33ff99" .. (mail.current and T("Busy: mail to %s..."):format(mail.current.to) or T("Busy...")) .. "|r"
	end
	mailPanel.text:SetText(table.concat(lines, "\n"))
	if mail.busy and mail.step then
		mailPanel.send:SetText(mail.current and T("Send this mail") or T("Pack next mail"))
	elseif mail.busy then
		mailPanel.send:SetText("Stop")
	else
		mailPanel.send:SetText(T("Yes, send"))
	end
	mailPanel.send:SetEnabled(any or mail.busy)
	mailPanel.skip:SetShown(any and not mail.busy)
	mailPanel:SetHeight(math.max(120, mailPanel.text:GetStringHeight() + 80))
end

function BuildMailPanel()
	if not MailFrame then return end
	mailPanel = NewWindow("CarefreeBagMailPanel", T("CarefreeBag mail"), 260, 160)
	mailPanel:SetParent(MailFrame)
	mailPanel:ClearAllPoints()
	mailPanel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, 0)
	mailPanel:SetMovable(false)
	mailPanel.text = mailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	mailPanel.text:SetPoint("TOPLEFT", mailPanel, "TOPLEFT", PAD, -30)
	mailPanel.text:SetWidth(260 - 2 * PAD)
	mailPanel.text:SetJustifyH("LEFT")
	mailPanel.send = MakeButton(mailPanel, T("Yes, send"), 110)
	mailPanel.send:SetPoint("BOTTOMLEFT", mailPanel, "BOTTOMLEFT", PAD, 16)
	mailPanel.send:SetScript("OnClick", MailButtonClick)
	mailPanel.skip = MakeButton(mailPanel, T("Skip"), 110)
	mailPanel.skip:SetPoint("BOTTOMRIGHT", mailPanel, "BOTTOMRIGHT", -PAD, 16)
	mailPanel.skip:SetScript("OnClick", MailSkip)

	mailPanel:SetScript("OnShow", function() UpdateMailPanel() end)
end
