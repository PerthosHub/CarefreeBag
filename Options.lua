-- CarefreeBag: Options.lua
-- Optievenster en minimapknop.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Assign, BLUE, CatByKey, CS, FIXED, FixOrder = ns.Assign, ns.BLUE, ns.CatByKey, ns.CS, ns.FIXED, ns.FixOrder
local LangName, LANGS, LearnedCount, Log, MailAuto, MakeButton = ns.LangName, ns.LANGS, ns.LearnedCount, ns.Log, ns.MailAuto, ns.MakeButton
local NewCatKey, NewMenu, NewWindow, On, PRESET, PRESETS = ns.NewCatKey, ns.NewMenu, ns.NewWindow, ns.On, ns.PRESET, ns.PRESETS
local Print, ResetOrder, SetEnabled, ShowMain, ShowMenu, SurnameSep = ns.Print, ns.ResetOrder, ns.SetEnabled, ns.ShowMain, ns.ShowMenu, ns.SurnameSep
local T, Tooltip = ns.T, ns.Tooltip

---------------------------------------------------------------------------
-- Opties-venster
---------------------------------------------------------------------------

local config
local catRows = {}

local function NewCheck(parent, label, tip, get, set)
	local ok, cb = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
	if not ok then cb = CreateFrame("CheckButton", nil, parent) end
	cb:SetSize(24, 24)
	cb.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
	cb.label:SetText(label)
	cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); ns.Refresh(); ns.RefreshConfig() end)
	cb.get = get
	if tip then Tooltip(cb, label, tip) end
	return cb
end

local function NewEdit(parent, w)
	local ok, eb = pcall(CreateFrame, "EditBox", nil, parent, "InputBoxTemplate")
	if not ok then eb = CreateFrame("EditBox", nil, parent) end
	eb:SetSize(w, 20)
	eb:SetAutoFocus(false)
	eb:SetFontObject("ChatFontNormal")
	eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return eb
end

local function Trim(t) return ((t or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local CW = 520 -- breedte optievenster
local ROW_H = 28 -- hoogte van een regel met een vinkje

-- Kopje: gouden tekst met een dunne lijn ernaast.
local function Heading(parent, text, yy)
	local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	h:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.PAD + 4, yy)
	h:SetText(text)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.35)
	line:SetHeight(1)
	line:SetPoint("LEFT", h, "RIGHT", 8, 0)
	line:SetPoint("RIGHT", parent, "RIGHT", -ns.PAD - 4, 0)
	return h
end

-- Vinkje op een vaste plek, dat RefreshConfig bijwerkt.
local function AddCheck(parent, x, y, label, tip, get, set)
	local cb = NewCheck(parent, label, tip, get, set)
	cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	config.checks[#config.checks + 1] = cb
	return cb
end

-- Taalknop rechtsboven: alleen een icoontje; de taal staat in de tooltip.
-- Kiezen = opslaan + interface herladen.
local function BuildLanguage(y)
	local langBtn = CreateFrame("Button", "CarefreeBagLangButton", config)
	langBtn:SetSize(24, 24)
	langBtn:SetPoint("TOPRIGHT", config, "TOPRIGHT", -ns.PAD - 4, y)
	langBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
	langBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Down")
	langBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	local langMenu = NewMenu("CarefreeBagLangMenu")
	config:HookScript("OnHide", function() langMenu:Hide() end)
	langMenu:SetSize(160, #LANGS * 22 + 8)
	langMenu:SetPoint("TOPRIGHT", langBtn, "BOTTOMRIGHT", 0, -2)
	for i, l in ipairs(LANGS) do
		local b = MakeButton(langMenu, l[2], 150)
		b:SetPoint("TOP", langMenu, "TOP", 0, -4 - (i - 1) * 22)
		b.langCode = l[1]
		b:SetScript("OnClick", function()
			langMenu:Hide()
			if ns.DB.lang == l[1] then return end
			ns.DB.lang = l[1]
			Log("language: " .. ns.DB.lang)
			ns.AskReload()
		end)
	end
	langBtn:SetScript("OnClick", function() ShowMenu(langMenu) end)
	Tooltip(langBtn, "Language: " .. LangName(ns.DB.lang))
end

-- Algemeen: alleen wat de meeste spelers willen kunnen aanpassen. Geeft de nieuwe y terug.
local function BuildGeneral(y)
	Heading(config, T("General"), y)
	y = y - 26
	local x = ns.PAD + 4
	AddCheck(config, x, y, T("CarefreeBag on"), T("Off = your normal bags."),
		function() return ns.DB.enabled end, function(v) SetEnabled(v) end)
	BuildLanguage(y)
	y = y - ROW_H
	AddCheck(config, x, y, T("Show sort options"), T("Choose per group how it is sorted."),
		function() return ns.DB.showSort end, function(v) ns.DB.showSort = v; ns.Refresh() end)
	return y - ROW_H - 10
end

-- Geavanceerd: onderaan, ingeklapt tot je erop klikt (plaats en hoogte zet RefreshConfig).
local function BuildAdvanced()
	config.advBtn = CreateFrame("Button", nil, config)
	config.advBtn:SetSize(CW - 2 * ns.PAD, 22)
	config.advBtn.icon = config.advBtn:CreateTexture(nil, "ARTWORK")
	config.advBtn.icon:SetSize(16, 16)
	config.advBtn.icon:SetPoint("LEFT", config.advBtn, "LEFT", 4, 0)
	config.advBtn.fs = config.advBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	config.advBtn.fs:SetPoint("LEFT", config.advBtn.icon, "RIGHT", 6, 0)
	config.advBtn.fs:SetText(T("Advanced settings"))
	config.advBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	config.advBtn:SetScript("OnClick", function() config.advOpen = not config.advOpen; ns.RefreshConfig() end)
	local adv = CreateFrame("Frame", nil, config)
	config.adv = adv

	-- Breedte van de tas
	local colsHover = CreateFrame("Frame", nil, adv)
	colsHover:SetSize(260, 24)
	colsHover:SetPoint("TOPLEFT", adv, "TOPLEFT", 6, 0)
	colsHover:EnableMouse(true)
	config.colsLabel = colsHover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	config.colsLabel:SetPoint("LEFT", colsHover, "LEFT", 4, 0)
	Tooltip(colsHover, T("Bag width"), T("How many items fit next to each other in the bag window (5 to 30)."))
	local function SetCols(n) ns.DB.maxCols = math.max(5, math.min(30, n)); ResetOrder(); ns.Refresh(); ns.RefreshConfig() end
	local minus = MakeButton(adv, "-", 24)
	minus:SetPoint("TOPRIGHT", adv, "TOPRIGHT", -32, 0)
	minus:SetScript("OnClick", function() SetCols(ns.DB.maxCols - 1) end)
	local plus = MakeButton(adv, "+", 24)
	plus:SetPoint("LEFT", minus, "RIGHT", 2, 0)
	plus:SetScript("OnClick", function() SetCols(ns.DB.maxCols + 1) end)

	-- Items die je bij volle tassen altijd houdt ("Never destroy this item" in het venster Bags full)
	local keptHover = CreateFrame("Frame", nil, adv)
	keptHover:SetSize(300, 24)
	keptHover:SetPoint("TOPLEFT", adv, "TOPLEFT", 6, -30)
	keptHover:EnableMouse(true)
	config.keptLabel = keptHover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	config.keptLabel:SetPoint("LEFT", keptHover, "LEFT", 4, 0)
	Tooltip(keptHover, T("Never destroy this item"),
		T("When your bags are full and loot does not fit, CarefreeBag offers to destroy your cheapest item. Items you marked with 'Never destroy this item' are never offered."),
		T("Clear: all these items can be offered again. Whole groups are set with the 'Always keep' tick per group. Only for this character."))
	config.keptClear = MakeButton(adv, T("Clear"), 80)
	config.keptClear:SetPoint("TOPRIGHT", adv, "TOPRIGHT", 0, -30)
	config.keptClear:SetScript("OnClick", function()
		local k = ns.Kept()
		for id in pairs(k) do k[id] = nil end
		Log("loot: kept items cleared")
		ns.RefreshConfig()
	end)
	Tooltip(config.keptClear, T("Clear"), T("These items may be destroyed again when your bags are full. Only for this character."))

	-- Vinkjes: dingen die CarefreeBag vanzelf doet (allemaal standaard aan of eenmalig gevraagd)
	local y = -60
	config.bagsCb = AddCheck(adv, 4, y, T("Equip better bags automatically"),
		T("A bag with more slots goes on right away (not in combat). Same number of slots: soulbound bags first, BoE bags last, because equipping binds them. Right-click a bag to swap it yourself."),
		function() return ns.DB.autoBags end, function(v)
			ns.DB.autoBags = v
			Log("equip better bags automatically: " .. tostring(v))
			if v and ns.ScheduleBagCheck then ns.ScheduleBagCheck() end
		end)
	y = y - ROW_H
	config.lootCb = AddCheck(adv, 4, y, T("Bags full: offer to make room"),
		T("When loot does not fit, a panel next to the loot window offers to destroy your cheapest item. Off = no panel."),
		function() return ns.DB.lootPanel ~= false end, function(v)
			ns.DB.lootPanel = v
			Log("bags full panel: " .. tostring(v))
			if not v and ns.LootEvent then ns.LootEvent("BAG") end
		end)
	y = y - ROW_H
	config.clamCb = AddCheck(adv, 4, y, T("Open clams automatically"),
		T("Clams you loot are opened right away (not in combat, and not while a vendor, bank or mailbox is open)."),
		function() return ns.DB.autoOpenClams end, function(v)
			ns.DB.autoOpenClams = v
			Log("open clams automatically: " .. tostring(v))
			if v and ns.OpenClams then ns.OpenClams() end
		end)
	y = y - ROW_H
	-- Post: alles zonder vragen (bij de eerste mailbox wordt dit gevraagd)
	config.mailCb = AddCheck(adv, 4, y, T("Always mail without asking"),
		T("At the mailbox every group with a recipient is sent right away, without the Yes/Skip question."),
		function() return ns.DB.mailAlwaysAuto end, function(v)
			ns.DB.mailAlwaysAuto = v
			Log("mail always without asking: " .. tostring(v))
			if ns.UpdateMailPanel then ns.UpdateMailPanel() end
		end)
	y = y - ROW_H
	config.subjectCb = AddCheck(adv, 4, y, T("Fill in the mail subject"),
		T("When you put items or money in a mail, the subject is filled in for you: the money first, then the items with their count. More than 3 kinds of items: 'Multiple items'. Text you type yourself stays."),
		function() return ns.DB.mailSubject ~= false end, function(v)
			ns.DB.mailSubject = v
			Log("fill in mail subject: " .. tostring(v))
			if v and ns.MailSubjectUpdate then ns.MailSubjectUpdate() end
		end)
	y = y - ROW_H
	-- Tassenbalk van WoW zelf (BlizzBagBar.lua)
	config.fillCb = AddCheck(adv, 4, y, T("Fill bar on the backpack"),
		T("The backpack button at the bottom of your screen fills up from green to red as your bags get full. Reagent and profession bags do not count."),
		function() return ns.DB.bagFill end, function(v)
			ns.DB.bagFill = v
			Log("backpack fill bar: " .. tostring(v))
			if ns.UpdateBackpackFill then ns.UpdateBackpackFill() end
		end)
	y = y - ROW_H
	config.slotsCb = AddCheck(adv, 4, y, T("Hide the other bag slots"),
		T("While your bags are closed, only the backpack stays. Open your bags to see the bag slots and key ring. Only for this character."),
		function() local ch = ns.CharEntry(); return ch and ch.hideBagSlots == true end, function(v)
			if ns.SetHideBagSlots then ns.SetHideBagSlots(v) end
		end)
	y = y - ROW_H
	config.advH = -y
	adv:SetSize(CW - 2 * ns.PAD, config.advH)
end

-- Kop van het groepenvak met de kolomnamen. Geeft de y van de eerste rij terug.
local function BuildGroupsHeader(y)
	Heading(config, T("Groups"), y)
	y = y - 24
	-- Eigen vak achter de groepen, zodat ze los staan van de opties hierboven.
	config.groupBg = CreateFrame("Frame", nil, config, "BackdropTemplate")
	config.groupBg:SetFrameLevel(config:GetFrameLevel())
	if config.groupBg.SetBackdrop then
		config.groupBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		config.groupBg:SetBackdropColor(0, 0, 0, 0.35)
		config.groupBg:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.6)
	end
	config.groupBg:SetPoint("TOPLEFT", config, "TOPLEFT", ns.PAD - 4, y + 6)
	config.groupBg:SetWidth(CW - 2 * ns.PAD + 8)
	-- "+ Groep toevoegen" bovenaan het vak, boven alle groepen.
	config.addTop = y - 4
	y = y - 32
	for _, col in ipairs({ { "Name", "TOPLEFT", 12 }, { "Mail to / settings", "TOPLEFT", 148 }, { "Always keep", "TOP", 452 } }) do
		local fs = config:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		fs:SetPoint(col[2], config, "TOPLEFT", ns.PAD + col[3], y) -- "Always keep": midden boven het vinkje
		fs:SetText(T(col[1]))
	end
	return y - 14
end

local FIXED_TIPS -- gevuld in BuildConfig (T() werkt pas als de taal bekend is)

local function MoveKey(idx, dir)
	local o = CS().order
	local j2 = idx + dir
	if j2 < 1 or j2 > #o then return end
	o[idx], o[j2] = o[j2], o[idx]
	ResetOrder(); ns.Refresh(); ns.RefreshConfig()
end

-- Naam van een groep: invulveld (eigen groep) of vaste naam met uitleg (vaste/kant-en-klare groep).
local function RowName(r)
	r.name = NewEdit(r, 120)
	r.name:SetPoint("LEFT", r, "LEFT", 10, 0)
	local function rename(self)
		local c = r.key and CatByKey(r.key)
		local new = Trim(self:GetText())
		if c and new ~= "" and new ~= c.name then
			Log("renamed: " .. c.name .. " -> " .. new)
			c.name = new
			local n = LearnedCount(c.key)
			if n > 0 then Print(T("'%s': renaming does not move items. The %d items it learned still go here."):format(new, n)) end
			ns.Refresh()
		end
		self:ClearFocus()
		if c then self:SetText(c.name) end
	end
	r.name:SetScript("OnEnterPressed", rename)
	r.name:SetScript("OnEditFocusLost", rename)
	r.name:HookScript("OnEnter", function(self)
		if not r.key then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(T("Learned: %d items"):format(LearnedCount(r.key)))
		GameTooltip:AddLine(T("Renaming does not change which items go here."), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	r.name:HookScript("OnLeave", function() GameTooltip:Hide() end)

	r.fixedName = CreateFrame("Frame", nil, r)
	r.fixedName:SetSize(120, 20)
	r.fixedName:SetPoint("LEFT", r, "LEFT", 34, 0)
	r.fixedName:EnableMouse(true)
	r.fixedName.fs = r.fixedName:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	r.fixedName.fs:SetPoint("LEFT")
	r.fixedName:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local c = CatByKey(r.key)
		if c and c.preset then
			GameTooltip:AddLine(T("Ready-made category"))
			GameTooltip:AddLine(T(PRESET[c.preset].tip), 1, 1, 1, true)
		else
			GameTooltip:AddLine(T("Fixed group"))
			GameTooltip:AddLine(FIXED_TIPS[r.key] or "", 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	r.fixedName:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- Aan/uit voor een vaste groep (vinkje vóór de naam).
	r.onCb = NewCheck(r, "", nil, function() return r.key and On(r.key) end,
		function(v) if r.key then ns.DB.fixedOn[r.key] = v and true or false; Log("fixed group " .. r.key .. " " .. (v and "on" or "off")); ResetOrder() end end)
	r.onCb:SetPoint("LEFT", r, "LEFT", 8, 0)
	Tooltip(r.onCb, T("Off: items go to Other."))
end

-- Post: in de rij alleen een envelop (+ ontvanger). Klik = venstertje met het adres en "zonder vragen".
local function RowMail(r)
	r.mailBtn = CreateFrame("Button", nil, r)
	r.mailBtn:SetSize(22, 22)
	r.mailBtn:SetPoint("LEFT", r, "LEFT", 148, 0)
	r.mailBtn:SetNormalTexture("Interface\\Icons\\INV_Letter_15")
	r.mailBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	r.mailInfo = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.mailInfo:SetPoint("LEFT", r.mailBtn, "RIGHT", 6, 0)
	r.mailInfo:SetWidth(150)
	r.mailInfo:SetJustifyH("LEFT")
	r.mailInfo:SetWordWrap(false)
	Tooltip(r.mailBtn, T("Mail to"), T("Click: choose the alt this group is mailed to, and whether it is sent without asking."))

	r.mailPop = ns.NewMenu(nil)
	r.mailPop:SetSize(250, 112)
	r.mailPop.title = r.mailPop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	r.mailPop.title:SetPoint("TOPLEFT", r.mailPop, "TOPLEFT", 12, -10)
	r.mail = NewEdit(r.mailPop, 222)
	r.mail:SetPoint("TOPLEFT", r.mailPop, "TOPLEFT", 16, -30)
	r.mailOk = MakeButton(r.mailPop, OKAY or "OK", 70)
	r.mailOk:SetPoint("BOTTOMRIGHT", r.mailPop, "BOTTOMRIGHT", -10, 10)
	r.mailOk:SetScript("OnClick", function() r.mail:ClearFocus(); r.mailPop:Hide() end)
	r.mailBtn:SetScript("OnClick", function(self)
		local c = r.key and CatByKey(r.key)
		r.mailPop.title:SetText(T("Mail %s to:"):format(r.key == "boe" and "BoE" or (c and c.name or "?")))
		r.mailPop:ClearAllPoints()
		r.mailPop:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
		ShowMenu(r.mailPop)
		r.mail:SetFocus()
	end)
	local function setMail(self)
		if r.key == "boe" then
			ns.DB.boeMail = Trim(self:GetText())
		else
			local c = r.key and CatByKey(r.key)
			if c then
				local v = Trim(self:GetText())
				c.mailTo = (v ~= "") and v or nil
			end
		end
		Log("mail address for " .. tostring(r.key) .. " changed")
		self:ClearFocus()
		ns.Refresh()
		ns.RefreshConfig() -- vinkje "zonder vragen" verschijnt pas met een ontvanger
	end
	r.mail:SetScript("OnEnterPressed", setMail)
	r.mail:SetScript("OnEditFocusLost", setMail)
	-- Forever heeft voor- en achternaam; de andere WoW-versies naam(-realm).
	Tooltip(r.mail, T("Mail to"), SurnameSep() and T("Full name of your alt, e.g. 'Thrall Stormrage'. Empty = no mail.")
		or T("Name of your alt, e.g. 'Thrall', or 'Thrall-Stormrage' on another realm. Empty = no mail."))

	-- Zonder vragen versturen (alleen zichtbaar als er een ontvanger is).
	r.mailAuto = NewCheck(r.mailPop, T("Send without asking"), nil, function() return r.key and MailAuto(r.key) end, function(v)
		if r.key == "boe" then ns.DB.boeMailAuto = v or nil
		else local c = r.key and CatByKey(r.key); if c then c.mailAuto = v or nil end end
		Log("mail without asking for " .. tostring(r.key) .. ": " .. tostring(v))
	end)
	r.mailAuto:SetPoint("TOPLEFT", r.mailPop, "TOPLEFT", 10, -54)
	Tooltip(r.mailAuto, T("Send without asking"), T("At the mailbox this group is sent right away, without the Yes/Skip question."))
end

-- Volgorde, verwijderen en "Always keep" rechts in de rij.
local function RowButtons(r)
	r.up = MakeButton(r, "^", 24)
	r.up:SetPoint("LEFT", r, "LEFT", 334, 0)
	r.down = MakeButton(r, "v", 24)
	r.down:SetPoint("LEFT", r.up, "RIGHT", 2, 0)
	r.del = MakeButton(r, "X", 24)
	r.del:SetPoint("LEFT", r.down, "RIGHT", 6, 0)
	r.up:SetScript("OnClick", function() MoveKey(r.index, -1) end)
	r.down:SetScript("OnClick", function() MoveKey(r.index, 1) end)
	r.del:SetScript("OnClick", function()
		local c, idx = CatByKey(r.key)
		if c then
			table.remove(CS().cats, idx)
			-- alleen bij dit karakter: andere karakters houden hun groepen en geleerde items
			local own = Assign()
			for id, k in pairs(own) do if k == c.key then own[id] = nil end end
			Print(T("category '%s' removed. Its items are back in Other."):format(c.name))
		end
		ResetOrder(); ns.Refresh(); ns.RefreshConfig()
	end)
	Tooltip(r.del, T("Remove"), T("Items go back to Other."))
	-- Bij volle tassen nooit iets uit deze groep weggooien.
	r.keep = NewCheck(r, "", nil, function() return r.key and ns.KeptGroups()[r.key] end, function(v)
		if r.key then ns.KeptGroups()[r.key] = v or nil; Log("loot: keep group " .. r.key .. ": " .. tostring(v)) end
	end)
	r.keep:SetPoint("LEFT", r, "LEFT", 440, 0)
	Tooltip(r.keep, T("Always keep"), T("Never destroy anything from this group when your bags are full."))
end

-- Eén rij in het groepenvak (welke groep erin staat, zet RefreshConfig).
local function NewCatRow()
	local r = CreateFrame("Frame", nil, config)
	r:SetSize(CW - 2 * ns.PAD, 24)
	RowName(r)
	RowMail(r)
	-- Vinkjes voor vaste groepen (in de kolom van het postadres).
	r.cb1 = NewCheck(r, "", nil, function() return r.cb1Field and ns.DB[r.cb1Field] end, function(v) if r.cb1Field then ns.DB[r.cb1Field] = v end end)
	r.cb1:SetPoint("LEFT", r, "LEFT", 146, 0)
	r.cb2 = NewCheck(r, "", nil, function() return r.cb2Field and ns.DB[r.cb2Field] end, function(v) if r.cb2Field then ns.DB[r.cb2Field] = v end end)
	r.cb2:SetPoint("LEFT", r, "LEFT", 226, 0)
	for _, cb in ipairs({ r.cb1, r.cb2 }) do
		cb:HookScript("OnEnter", function(self)
			if not self.tip then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(self.label:GetText() or "")
			GameTooltip:AddLine(self.tip, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
	end
	RowButtons(r)
	return r
end

local function FreePresets()
	local list = {}
	for _, p in ipairs(PRESETS) do
		local used = false
		for _, c in ipairs(CS().cats) do if c.preset == p.id then used = true end end
		if not used then list[#list + 1] = p end
	end
	return list
end

local function AddPreset(id)
	local p = PRESET[id]
	if not p then return end
	if #CS().cats >= 12 then Print(T("at most 12 categories.")); return end
	local key = p.id
	if CatByKey(key) then key = NewCatKey("p" .. p.id) end
	CS().cats[#CS().cats + 1] = { key = key, preset = p.id, name = T(p.name) }
	Log("preset added: " .. p.id)
	ResetOrder(); ns.Refresh(); ns.RefreshConfig()
end

-- Groep toevoegen: één knop met een lijstje. Kant-en-klaar = direct toegevoegd;
-- Custom group = je typt een naam en klikt op Add.
local function BuildAddGroup()
	config.choice = nil
	config.pickBtn = MakeButton(config, "+ " .. T("Add group"), 160)
	config.newEdit = NewEdit(config, 130)
	config.addBtn = MakeButton(config, T("Add"), 80)
	config.ShowChoice = function()
		local own = config.choice == "own"
		config.newEdit:SetShown(own)
		config.addBtn:SetShown(own)
	end
	local function add()
		if #CS().cats >= 12 then Print(T("at most 12 categories.")); return end
		local name = Trim(config.newEdit:GetText())
		if name == "" then config.newEdit:SetFocus(); return end
		CS().cats[#CS().cats + 1] = { key = NewCatKey(name), name = name }
		config.newEdit:SetText("")
		config.newEdit:ClearFocus()
		config.choice = nil
		ResetOrder(); ns.Refresh(); ns.RefreshConfig()
	end
	config.newEdit:SetScript("OnEnterPressed", add)
	config.addBtn:SetScript("OnClick", add)

	-- Lijstje met twee keuzes: "Custom group" en "Predefined groups >" (opent een tweede lijstje).
	local pm = NewMenu("CarefreeBagPresetMenu") -- aan UIParent: anders vallen klikken weg achter het optievenster
	local sub = NewMenu("CarefreeBagPresetSubMenu")
	sub:SetScript("OnHide", nil)
	pm:HookScript("OnHide", function() sub:Hide() end)
	config:HookScript("OnHide", function() pm:Hide() end)
	pm:SetSize(180, 2 * 22 + 8)

	local ownBtn = MakeButton(pm, T("Custom group"), 170)
	ownBtn:SetPoint("TOP", pm, "TOP", 0, -4)
	ownBtn.presetID = "own"
	ownBtn:SetScript("OnClick", function()
		pm:Hide()
		config.choice = "own"
		ns.RefreshConfig()
		config.newEdit:SetFocus()
	end)
	Tooltip(ownBtn, T("Custom group"), T("Name it yourself. It learns: every item you drag onto it goes there from now on."))

	local preBtn = MakeButton(pm, T("Predefined groups") .. "  >", 170)
	preBtn:SetPoint("TOP", ownBtn, "BOTTOM", 0, 0)
	Tooltip(preBtn, T("Predefined groups"), T("Ready-made groups that fill themselves."))

	sub.buttons = {}
	for i, p in ipairs(PRESETS) do
		local b = MakeButton(sub, T(p.name), 170)
		b.presetID = p.id
		b:SetScript("OnClick", function()
			pm:Hide()
			config.choice = nil
			AddPreset(p.id)
		end)
		Tooltip(b, T(p.name), T(p.tip))
		sub.buttons[i] = b
	end
	local function OpenSub()
		local free = {}
		for _, p in ipairs(FreePresets()) do free[p.id] = true end
		local n = 0
		for _, b in ipairs(sub.buttons) do
			b:ClearAllPoints()
			if free[b.presetID] then
				b:SetPoint("TOP", sub, "TOP", 0, -4 - n * 22); b:Show(); n = n + 1
			else b:Hide() end
		end
		if n == 0 then sub:Hide(); return end
		sub:SetSize(180, n * 22 + 8)
		sub:ClearAllPoints()
		sub:SetPoint("TOPLEFT", preBtn, "TOPRIGHT", 6, 4)
		sub:Show()
	end
	preBtn:SetScript("OnClick", OpenSub)
	preBtn:HookScript("OnEnter", OpenSub)

	config.presetMenu = pm
	config.pickBtn:SetScript("OnClick", function()
		preBtn:SetEnabled(#FreePresets() > 0)
		pm:ClearAllPoints()
		pm:SetPoint("TOPLEFT", config.pickBtn, "BOTTOMLEFT", 0, -2)
		ShowMenu(pm)
	end)
end

function ns.BuildConfig()
	config = NewWindow("CarefreeBagConfig", T("CarefreeBag options"), CW, 600)
	config:SetPoint("CENTER", UIParent, "CENTER", -200, 40)
	-- Vast links naast de tassen (zoals het bankpaneel); los slepen kan alleen als
	-- CarefreeBag uit staat (dan zijn er geen tassen om aan vast te zitten).
	config:SetScript("OnDragStart", function(self) if not self.docked then self:StartMoving() end end)
	config:SetScript("OnDragStop", config.StopMovingOrSizing)
	ns.main:HookScript("OnHide", function()
		if not config:IsShown() or not config.docked then return end
		if ns.DB.enabled then config:Hide() else ns.PlaceConfig() end -- net uitgezet: venster blijft open
	end)
	config:SetScript("OnShow", function() ns.RefreshConfig() end)
	config.checks, config.edits = {}, {}
	FIXED_TIPS = {
		quest = T("Quest items. Never sold or mailed."),
		keys = T("Your keyring."),
		boe = T("Unbound BoE items, green and better."),
		grey = T("Grey items. Sold at a vendor."),
		other = T("Everything without a group."),
	}

	local y = BuildGeneral(-32)
	BuildAdvanced()
	config.catTop = BuildGroupsHeader(y)
	-- Venstertjes voor post sluiten mee met de opties
	config:HookScript("OnHide", function() for _, r in ipairs(catRows) do if r.mailPop then r.mailPop:Hide() end end end)
	for i = 1, 20 do catRows[i] = NewCatRow() end
	BuildAddGroup()

	config.version = config:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	config.version:SetPoint("BOTTOMRIGHT", config, "BOTTOMRIGHT", -ns.PAD, 14)
	config.version:SetText("CarefreeBag " .. ns.VERSION)
end

-- Per vaste groep: wat staat er in de middelste kolom.
local FIXED_ROW = {
	quest = {},
	keys = {},
	boe = { mail = true },
	grey = { cb1 = { "autoSell", "Sell automatically", "Sell at a vendor." } },
	other = {},
}
local FIXED_NAME = { quest = "Quest", keys = "Keys", boe = "BoE", grey = "Auto Sell", other = "Other" }

local function SetupCheck(r, cb, field, spec)
	if spec then
		r[field] = spec[1]
		cb.label:SetText(spec[2] ~= "" and T(spec[2]) or "")
		cb.tip = T(spec[3])
		cb:SetChecked(ns.DB[spec[1]] and true or false)
		cb:Show(); cb.label:Show()
	else
		r[field] = nil
		cb:Hide(); cb.label:Hide()
	end
end

-- Wat er naast de envelop staat: de ontvanger (+ "auto"), of grijs "no mail".
local function MailInfo(r, to)
	local has = (to or "") ~= ""
	local tex = r.mailBtn.GetNormalTexture and r.mailBtn:GetNormalTexture()
	if tex and tex.SetDesaturated then tex:SetDesaturated(not has); tex:SetAlpha(has and 1 or 0.5) end
	if has then
		r.mailInfo:SetText(to .. (MailAuto(r.key) and ("  |cff40ff40" .. T("Auto") .. "|r") or ""))
	else
		r.mailInfo:SetText("|cff777777" .. T("no mail") .. "|r")
	end
end

ns.RefreshConfig = function()
	if not config or not config:IsShown() then return end
	for _, cb in ipairs(config.checks) do cb:SetChecked(cb.get() and true or false) end
	config.colsLabel:SetText(T("Bag width: %d columns"):format(ns.DB.maxCols))
	local nKept = 0
	for _ in pairs(ns.Kept()) do nKept = nKept + 1 end
	config.keptLabel:SetText(T("Items kept when bags are full: %d"):format(nKept))
	config.keptClear:SetEnabled(nKept > 0)

	local order = FixOrder()
	local y = config.catTop
	-- "+ Groep toevoegen" staat bovenaan het groepenvak.
	local function PlaceAdd()
		config.ShowChoice()
		config.pickBtn:ClearAllPoints()
		config.pickBtn:SetPoint("TOPLEFT", config, "TOPLEFT", ns.PAD + 8, config.addTop)
		config.newEdit:ClearAllPoints()
		config.newEdit:SetPoint("LEFT", config.pickBtn, "RIGHT", 10, 0)
		config.addBtn:ClearAllPoints()
		config.addBtn:SetPoint("LEFT", config.newEdit, "RIGHT", 8, 0)
	end
	PlaceAdd()
	for i, r in ipairs(catRows) do
		local key = order[i]
		if key then
			r.index, r.key = i, key
			local fixed = FIXED[key]
			local cc = not fixed and CatByKey(key)
			local preset = cc and cc.preset
			r.name:SetShown(not fixed and not preset)
			r.fixedName:SetShown((fixed or preset) and true or false)
			r.fixedName:ClearAllPoints()
			r.fixedName:SetPoint("LEFT", r, "LEFT", preset and 14 or 34, 0)
			r.onCb:SetShown(fixed and key ~= "other" and true or false)
			if fixed then r.onCb:SetChecked(On(key)) end
			r.del:SetShown(not fixed)
			if fixed then
				local spec = FIXED_ROW[key]
				local nm = (key == "grey" and "Auto Sell" or (key == "boe" and "BoE" or T(FIXED_NAME[key])))
				r.fixedName.fs:SetText((On(key) and BLUE or "|cff777777") .. nm .. "|r")
				SetupCheck(r, r.cb1, "cb1Field", spec.cb1)
				SetupCheck(r, r.cb2, "cb2Field", spec.cb2)
				r.mailBtn:SetShown(spec.mail and true or false)
				r.mailInfo:SetShown(spec.mail and true or false)
				if spec.mail then
					if not r.mail:HasFocus() then r.mail:SetText(ns.DB.boeMail or "") end
					MailInfo(r, ns.DB.boeMail)
				elseif r.mailPop:IsShown() then
					r.mailPop:Hide()
				end
				r.mailAuto:SetShown(spec.mail and (ns.DB.boeMail or "") ~= "" and true or false)
				r.mailAuto.label:SetShown(r.mailAuto:IsShown())
				r.mailAuto:SetChecked(MailAuto(key))
				r.mailAuto:SetEnabled(not ns.DB.mailAlwaysAuto)
			else
				local c = CatByKey(key)
				SetupCheck(r, r.cb1, "cb1Field", nil)
				SetupCheck(r, r.cb2, "cb2Field", nil)
				r.mailBtn:Show(); r.mailInfo:Show()
				if preset then r.fixedName.fs:SetText("|cffffd100" .. c.name .. "|r")
				elseif not r.name:HasFocus() then r.name:SetText(c.name) end
				if not r.mail:HasFocus() then r.mail:SetText(c.mailTo or "") end
				MailInfo(r, c.mailTo)
				r.mailAuto:SetShown((c.mailTo or "") ~= "")
				r.mailAuto.label:SetShown(r.mailAuto:IsShown())
				r.mailAuto:SetChecked(MailAuto(key))
				r.mailAuto:SetEnabled(not ns.DB.mailAlwaysAuto) -- staat "altijd" aan: vinkje per groep doet niets
			end
			-- Quest/Keys worden toch nooit weggegooid; Auto Sell is er juist om weg te doen
			-- Other: daar staan ook items die weg mogen
			r.keep:SetShown(key ~= "quest" and key ~= "keys" and key ~= "grey" and key ~= "other")
			r.keep:SetChecked(ns.KeptGroups()[key] and true or false)
			r.up:SetEnabled(i > 1)
			r.down:SetEnabled(i < #order)
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", config, "TOPLEFT", ns.PAD, y)
			if not r.stripe then
				r.stripe = r:CreateTexture(nil, "BACKGROUND")
				r.stripe:SetAllPoints(r)
				r.stripe:SetColorTexture(1, 1, 1, 0.04)
			end
			r.stripe:SetShown(i % 2 == 0)
			r:Show()
			y = y - 26
		else
			r:Hide()
		end
	end
	y = y - 6
	config.groupBg:SetHeight(config.catTop + 52 - y)
	-- Geavanceerd: onderaan, ingeklapt tot je erop klikt
	y = y - 14
	config.advBtn:ClearAllPoints()
	config.advBtn:SetPoint("TOPLEFT", config, "TOPLEFT", ns.PAD, y)
	config.advBtn.icon:SetTexture(config.advOpen and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
	y = y - 28
	config.adv:ClearAllPoints()
	config.adv:SetPoint("TOPLEFT", config, "TOPLEFT", ns.PAD, y)
	config.adv:SetShown(config.advOpen and true or false)
	if config.advOpen then y = y - config.advH end
	config:SetHeight(-y + 30)
end

-- Plaats van het optievenster: links naast de tassen als CarefreeBag aan staat,
-- anders los in het midden van het scherm.
ns.PlaceConfig = function()
	config:ClearAllPoints()
	if not config.sideArrow then ns.AddSideArrow(config) end
	if ns.DB.enabled and ns.main and ns.main:IsShown() then
		config.docked = true
		ns.DockPanel(config) -- links of rechts van de tassen (pijltje wisselt)
	else
		config.docked = false
		config:SetPoint("CENTER", UIParent, "CENTER", -200, 40)
		config.sideArrow:Hide()
	end
end

ns.HideConfig = function() if config then config:Hide() end end

ns.ToggleConfig = function()
	if config:IsShown() then config:Hide(); return end
	if ns.DB.enabled and ns.main and not ns.main:IsShown() then ShowMain() end
	-- Bankpaneel en opties zitten op dezelfde plek: één tegelijk.
	if ns.HideViewer then ns.HideViewer() end
	ns.PlaceConfig()
	config:Show()
end

---------------------------------------------------------------------------
-- Esc → Options → AddOns: een pagina met één knop die ons eigen optievenster opent
-- (zelfde instellingen, één plek om ze te onderhouden).
---------------------------------------------------------------------------

function ns.RegisterSettings()
	local p = CreateFrame("Frame")
	p.name = "CarefreeBag"
	local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", p, "TOPLEFT", 16, -16)
	title:SetText("CarefreeBag")
	local text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	text:SetText(T("All settings are in the CarefreeBag options window, next to your bags."))
	local btn = MakeButton(p, T("Open options"), 180)
	btn:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
	btn:SetScript("OnClick", function()
		-- eerst het WoW-menu dicht, anders ligt dat over onze vensters
		for _, f in ipairs({ SettingsPanel, InterfaceOptionsFrame, GameMenuFrame }) do
			if f and f.IsShown and f:IsShown() then pcall(HideUIPanel, f) end
		end
		if not config:IsShown() then ns.ToggleConfig() end
	end)
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local cat = Settings.RegisterCanvasLayoutCategory(p, "CarefreeBag")
		Settings.RegisterAddOnCategory(cat)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(p)
	end
end

---------------------------------------------------------------------------
-- Minimapknop
---------------------------------------------------------------------------

local function PlaceMinimapButton(btn)
	local angle = math.rad(ns.DB.minimapAngle or 230)
	local radius = (Minimap:GetWidth() / 2) + 6
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.BuildMinimapButton()
	if not Minimap then return end
	local btn = CreateFrame("Button", "CarefreeBagMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(20, 20)
	bg:SetPoint("TOPLEFT", 7, -5)
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
	icon:SetSize(18, 18)
	icon:SetPoint("TOPLEFT", 7, -6)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	btn:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function(s)
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			ns.DB.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			PlaceMinimapButton(s)
		end)
	end)
	btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	btn:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" or not ns.DB.enabled then
			-- staat CFB uit, dan opent ook links de opties: aan/uit staat daar bovenaan
			ns.ToggleConfig()
		else
			if ns.main:IsShown() then ns.main:Hide() else ShowMain() end
		end
	end)
	btn.icon = icon
	ns.UpdateMinimapIcon = function()
		if btn.icon.SetDesaturated then btn.icon:SetDesaturated(not ns.DB.enabled) end
		btn.icon:SetAlpha(ns.DB.enabled and 1 or 0.5)
	end
	ns.UpdateMinimapIcon()
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("CarefreeBag  " .. (ns.DB.enabled and ("|cff33ff99" .. T("on") .. "|r") or ("|cffff5555" .. T("off") .. "|r")))
		GameTooltip:AddLine(T("Left-click: open/close bags"), 1, 1, 1)
		GameTooltip:AddLine(T("Right-click: options"), 1, 1, 1)
		GameTooltip:AddLine(T("Drag: move along the minimap"), 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	btn:SetShown(not ns.DB.hideMinimap)
	PlaceMinimapButton(btn)
end
