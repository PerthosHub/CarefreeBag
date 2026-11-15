-- CarefreeBag: BagWindow.lua
-- Het tassenvenster: stijl, knoppen, menu's, Layout en slepen.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local AHPrice, Assign, CatByKey, CharEntry, CS, Hidden = ns.AHPrice, ns.Assign, ns.CatByKey, ns.CharEntry, ns.CS, ns.Hidden
local HookAHTooltip, KeyringBag, LearnedCount, Log, On, PRESET = ns.HookAHTooltip, ns.KeyringBag, ns.LearnedCount, ns.Log, ns.On, ns.PRESET
local Print, Scan, SectionOf, T = ns.Print, ns.Scan, ns.SectionOf, ns.T

---------------------------------------------------------------------------
-- Stijl
---------------------------------------------------------------------------

ns.TILE, ns.GAP, ns.PAD = 37, 4, 16
local GOLD = { 1, 0.82, 0 }
local DIALOG_BACKDROP = BACKDROP_DIALOG_32_32 or {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileEdge = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
ns.SLOT_TEX = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

function ns.NewWindow(name, title, w, h)
	local ok, f = pcall(CreateFrame, "Frame", name, UIParent, "BackdropTemplate")
	if not ok then f = CreateFrame("Frame", name, UIParent) end
	f:SetSize(w, h)
	f:SetFrameStrata("MEDIUM")
	f:SetToplevel(true)
	if f.SetBackdrop then f:SetBackdrop(DIALOG_BACKDROP) end
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	local okH, header = pcall(CreateFrame, "Frame", nil, f, "DialogHeaderTemplate")
	if okH and header and header.Setup then
		pcall(header.Setup, header, title)
		f.SetHeaderText = function(_, t) pcall(header.Setup, header, t) end
	else
		local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		t:SetPoint("TOP", f, "TOP", 0, -12)
		t:SetText(title)
		f.SetHeaderText = function(_, s) t:SetText(s) end
	end
	local okC, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
	if okC then
		close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
		close:SetScript("OnClick", function() f:Hide() end)
	end
	if UISpecialFrames then tinsert(UISpecialFrames, name) end
	f:Hide()
	return f
end

function ns.MakeButton(parent, text, w)
	local ok, btn = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
	if not ok then btn = CreateFrame("Button", nil, parent) end
	btn:SetSize(w or 100, 22)
	if btn.SetText then btn:SetText(text) end
	return btn
end

function ns.Tooltip(frame, title, ...)
	local lines = { ... }
	frame:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(title)
		for _, l in ipairs(lines) do GameTooltip:AddLine(l, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

---------------------------------------------------------------------------
-- Hoofdvenster
---------------------------------------------------------------------------

local itemPool, headerPool, plusPool = {}, {}, {}
local usedItems, usedHeaders, usedPlus = 0, 0, 0
local showHidden = false -- true = verbergmodus: verborgen groep zichtbaar, klik = verbergen/terughalen
local inLayout;  ns.layoutPending, inLayout = false, false
local lastFree, lastItems = {}, {}
-- Zolang het venster open is: hoeveel je van elk item had (laagste stand) en wat erbij kwam.
local openCounts, freshIDs = nil, {}
ns.searchText = ""
-- Vaste volgorde zolang het venster open is: [sectie] = { key, key, ... }.
-- Leeg = opnieuw sorteren (bij openen, of als je een categorie wijzigt).
local frozen = {}
function ns.ResetOrder() frozen = {} end

local function CursorItemID()
	local kind, id = GetCursorInfo()
	if kind == "item" then return id end
end

-- Sorteren per categorie: soort, stapelprijs, nieuwste als laatst of handmatig.
local SORTS = { "value", "newest", "manual" }
local SORT_NAME = { value = "Stack price", newest = "Newest last", manual = "Manual" }
local SORT_TIP = {
	value = "Most valuable stack first (with Auctionator: AH value).",
	newest = "What you got last is at the end.",
	manual = "Your own order: drag items onto each other.",
}
local function SortMode(sec)
	CS().sort = CS().sort or {}
	local m = CS().sort[sec.key]
	if m and SORT_NAME[m] then return m end
	return sec.byValue and "value" or "newest"
end

-- Per karakter: wanneer is een item voor het eerst gezien, en jouw eigen volgorde.
local function CharData()
	return CharEntry() or { seen = {}, manual = {} }
end

local lastOrder = {} -- per groep: de item-ID's in de volgorde zoals ze nu in beeld staan

-- Komt het item op de cursor uit dezelfde groep als deze tegel?
local function ReorderTarget(b)
	local id = CursorItemID()
	local g = b.group
	if not id or not g or id == g.itemID or not b.secKey then return false end
	for _, e in ipairs(lastItems or {}) do
		if e.itemID == id then return SectionOf(e) == b.secKey end
	end
	return false
end

local function Reorder(b)
	if not ReorderTarget(b) then return false end
	local id, target, key = CursorItemID(), b.group.itemID, b.secKey
	local list = {}
	for _, v in ipairs(lastOrder[key] or {}) do list[#list + 1] = v end
	local from, to
	for i, v in ipairs(list) do
		if v == id and not from then from = i end
		if v == target and not to then to = i end
	end
	if not from or not to then return false end
	if (b.dropMode or "swap") == "swap" then
		list[from], list[to] = list[to], list[from]
	else
		table.remove(list, from)
		if from < to then to = to - 1 end
		table.insert(list, to, id)
	end
	CS().sort = CS().sort or {}
	if CS().sort[key] ~= "manual" then
		CS().sort[key] = "manual"
		Print(T("Sorting set to manual for this group."))
	end
	CharData().manual[key] = list
	Log("reorder " .. key .. ": " .. id .. " " .. (b.dropMode or "swap") .. " " .. target)
	ClearCursor()
	b.insertMark:Hide(); b.swapMark:Hide(); b.watch:Hide()
	ns.ResetOrder(); ns.Refresh()
	return true
end

local function NewItemButton(i)
	local b = CreateFrame("ItemButton", "CarefreeBagItem" .. i, ns.main.content, "ContainerFrameItemButtonTemplate")
	b:SetSize(ns.TILE, ns.TILE)
	b.isCarefreeItem = true
	HookAHTooltip()
	-- Volgorde aanpassen: sleep een item op een ander item in dezelfde groep.
	-- Links op de tegel = ertussen zetten (gouden streep), rest = omwisselen (gouden rand).
	b.insertMark = b:CreateTexture(nil, "OVERLAY", nil, 7)
	b.insertMark:SetColorTexture(1, 0.82, 0, 1)
	b.insertMark:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 2)
	b.insertMark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", -3, -2)
	b.insertMark:SetWidth(3)
	b.insertMark:Hide()
	b.swapMark = b:CreateTexture(nil, "OVERLAY", nil, 7)
	b.swapMark:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	b.swapMark:SetBlendMode("ADD")
	b.swapMark:SetVertexColor(1, 0.82, 0)
	b.swapMark:SetPoint("CENTER")
	b.swapMark:SetSize(ns.TILE * 1.8, ns.TILE * 1.8)
	b.swapMark:Hide()
	-- Nieuw item: pulserende gouden rand, tot je er met de muis overheen gaat
	-- (of de tas sluit). Loot je er daarna meer van, dan knippert het opnieuw.
	b.newGlow = b:CreateTexture(nil, "OVERLAY", nil, 6)
	b.newGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	b.newGlow:SetBlendMode("ADD")
	b.newGlow:SetVertexColor(1, 0.85, 0.2)
	b.newGlow:SetPoint("CENTER")
	b.newGlow:SetSize(ns.TILE * 1.9, ns.TILE * 1.9)
	b.newGlow:Hide()
	local okA, ag = pcall(b.newGlow.CreateAnimationGroup, b.newGlow)
	if okA and ag then
		ag:SetLooping("BOUNCE")
		local a = ag:CreateAnimation("Alpha")
		a:SetFromAlpha(1); a:SetToAlpha(0.25); a:SetDuration(0.6)
		b.newPulse = ag
	end
	b:HookScript("OnEnter", function(self)
		local g = self.group
		if not g or not self.newGlow:IsShown() then return end
		self.newGlow:Hide()
		if self.newPulse then self.newPulse:Stop() end
		-- Gezien: huidige stand wordt de nieuwe basis, alle vakjes van dit item niet meer nieuw.
		local n = 0
		for _, e in ipairs(lastItems) do
			if e.itemID == g.itemID then
				n = n + (e.count or 1)
				if C_NewItems and C_NewItems.RemoveNewItem then pcall(C_NewItems.RemoveNewItem, e.bag, e.slot) end
			end
		end
		freshIDs[g.itemID] = nil
		if openCounts then openCounts[g.itemID] = n end
	end)
	b.watch = CreateFrame("Frame", nil, b)
	b.watch:Hide()
	b.watch:SetScript("OnUpdate", function()
		if not CursorHasItem() or not b:IsMouseOver() then
			b.insertMark:Hide(); b.swapMark:Hide(); b.dropMode = nil; b.watch:Hide(); return
		end
		local x = GetCursorPosition() / (b:GetEffectiveScale() or 1)
		local left, w = b:GetLeft() or 0, b:GetWidth() or ns.TILE
		b.dropMode = ((x - left) / w < 0.35) and "insert" or "swap"
		b.insertMark:SetShown(b.dropMode == "insert")
		b.swapMark:SetShown(b.dropMode == "swap")
	end)
	b:HookScript("OnEnter", function(self)
		if ReorderTarget(self) then self.watch:Show() end
	end)
	b:HookScript("OnLeave", function(self) self.insertMark:Hide(); self.swapMark:Hide(); self.watch:Hide() end)
	local origDrag = b:GetScript("OnReceiveDrag")
	b:SetScript("OnReceiveDrag", function(self, ...)
		if Reorder(self) then return end
		if origDrag then return origDrag(self, ...) end
	end)
	b.multi = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	b.multi:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.multi:SetTextColor(0.4, 0.85, 1)

	-- Een gewone knop bovenop de tegel, alleen zichtbaar in de verbergmodus.
	local o = CreateFrame("Button", nil, b)
	o:SetAllPoints(b)
	o:SetFrameLevel(b:GetFrameLevel() + 5)
	o:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	o.tex = o:CreateTexture(nil, "OVERLAY")
	o.tex:SetAllPoints(o)
	o:SetScript("OnClick", function(self)
		local g = b.group
		if g then ns.SetHidden(g.itemID, not Hidden()[g.itemID]) end
	end)
	o:SetScript("OnEnter", function(self)
		local g = b.group
		if not g then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if g.link then GameTooltip:SetHyperlink(g.link) end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(Hidden()[g.itemID] and T("CarefreeBag: click to show this item again") or T("CarefreeBag: click to hide this item"), GOLD[1], GOLD[2], GOLD[3])
		GameTooltip:Show()
	end)
	o:SetScript("OnLeave", function() GameTooltip:Hide() end)
	o:Hide()
	b.overlay = o
	return b
end

local function GetItemButton()
	usedItems = usedItems + 1
	local b = itemPool[usedItems]
	if not b then
		b = NewItemButton(usedItems)
		itemPool[usedItems] = b
	end
	return b
end

-- Rode vierkante knop zoals Blizzard die gebruikt (128-RedButton-...).
local function HasAtlas(a) return a and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(a) ~= nil end
local function SetRedKit(b, kit, fallback)
	if HasAtlas(kit) then
		b:SetNormalAtlas(kit)
		if HasAtlas(kit .. "-Pressed") then b:SetPushedAtlas(kit .. "-Pressed") end
		if HasAtlas(kit .. "-Highlight") then b:SetHighlightAtlas(kit .. "-Highlight", "ADD")
		else b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD") end
	elseif fallback then
		b:SetNormalTexture(fallback)
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	end
end
local function RedButton(parent, name, size, kit, fallback, iconAtlases)
	local b = CreateFrame("Button", name, parent)
	b:SetSize(size, size)
	SetRedKit(b, kit, fallback)
	if iconAtlases and HasAtlas(kit) then
		for _, a in ipairs(iconAtlases) do
			if HasAtlas(a) then
				b.icon = b:CreateTexture(nil, "OVERLAY")
				b.icon:SetAtlas(a)
				b.icon:SetSize(size * 0.6, size * 0.6)
				b.icon:SetPoint("CENTER", 0, 1)
				break
			end
		end
	end
	return b
end

local MAIL_ICON = "|TInterface\\Minimap\\Tracking\\Mailbox:14:14|t"
local CHECK_ICON = "|TInterface\\Buttons\\UI-CheckBox-Check:14:14|t"
local keepHeader -- na in-/uitklappen: dit kopje moet op dezelfde plek blijven

-- Keuzelijst: zelfde stijl overal; klik je ernaast, dan gaat hij dicht.
local menuCatcher
function ns.NewMenu(name, parent)
	local m = CreateFrame("Frame", name, parent or UIParent, "BackdropTemplate")
	m:SetFrameStrata("FULLSCREEN_DIALOG")
	m:SetClampedToScreen(true)
	if m.SetBackdrop then
		m:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
			insets = { left = 3, right = 3, top = 3, bottom = 3 } })
		m:SetBackdropColor(0, 0, 0, 0.95)
	end
	m:SetScript("OnHide", function() if menuCatcher and menuCatcher.menu == m then menuCatcher:Hide() end end)
	m:Hide()
	return m
end
function ns.ShowMenu(m)
	if not menuCatcher then
		menuCatcher = CreateFrame("Button", "CarefreeBagMenuCatcher", UIParent)
		menuCatcher:SetAllPoints(UIParent)
		menuCatcher:SetFrameStrata("FULLSCREEN")
		menuCatcher:RegisterForClicks("AnyUp")
		menuCatcher:SetScript("OnClick", function(self)
			if self.menu then self.menu:Hide() end
			self:Hide()
		end)
		menuCatcher:Hide()
	end
	if menuCatcher.menu and menuCatcher.menu ~= m then menuCatcher.menu:Hide() end
	menuCatcher.menu = m
	menuCatcher:Show()
	m:Show()
end

-- Keuzelijstje voor sorteren (één lijstje, gedeeld door alle groepen).
local sortMenu
local function OpenSortMenu(anchor, sec)
	if not sec then return end
	if not sortMenu then
		sortMenu = ns.NewMenu("CarefreeBagSortMenu")
		sortMenu:SetSize(180, #SORTS * 22 + 8)
		sortMenu.buttons = {}
		for i, m in ipairs(SORTS) do
			local b = ns.MakeButton(sortMenu, "", 170)
			b:SetPoint("TOP", sortMenu, "TOP", 0, -4 - (i - 1) * 22)
			b.mode = m
			b:SetScript("OnClick", function(self)
				CS().sort = CS().sort or {}
				CS().sort[sortMenu.sec.key] = self.mode
				Log("sort " .. sortMenu.sec.key .. ": " .. self.mode)
				sortMenu:Hide()
				ns.ResetOrder(); ns.Refresh()
			end)
			b:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:AddLine(T(SORT_NAME[self.mode]))
				GameTooltip:AddLine(T(SORT_TIP[self.mode]), 1, 1, 1, true)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			sortMenu.buttons[i] = b
		end
		ns.main:HookScript("OnHide", function() sortMenu:Hide() end)
	end
	sortMenu.sec = sec
	local cur = SortMode(sec)
	for _, b in ipairs(sortMenu.buttons) do
		-- de huidige keuze met een vinkje
		b:SetText((b.mode == cur and (CHECK_ICON .. " ") or "") .. T(SORT_NAME[b.mode]))
	end
	sortMenu:ClearAllPoints()
	sortMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
	ns.ShowMenu(sortMenu)
end

local function GetHeader()
	usedHeaders = usedHeaders + 1
	local h = headerPool[usedHeaders]
	if not h then
		h = CreateFrame("Frame", nil, ns.main.content)
		h:SetSize(200, 16)
		h:EnableMouse(true)
		-- [-] / [+]: groep in- of uitklappen
		h.toggle = RedButton(h, nil, 15, "128-redbutton-minus", "Interface\\Buttons\\UI-MinusButton-Up")
		h.toggle:SetPoint("LEFT", h, "LEFT", 0, 0)
		h.toggle:SetScript("OnClick", function()
			if not h.key then return end
			CS().collapsed = CS().collapsed or {}
			CS().collapsed[h.key] = not CS().collapsed[h.key] or nil
			keepHeader = { key = h.key, top = h:GetTop() } -- het minnetje blijft onder je muis
			ns.Refresh()
		end)
		h.fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h.fs:SetPoint("LEFT", h, "LEFT", 18, 0)
		h.fs:SetJustifyH("LEFT")
		h.SetText = function(self, t) self.fs:SetText(t) end
		-- "Auto" + envelop: alleen hier staat de post-info in de tooltip
		h.mail = CreateFrame("Button", nil, h)
		h.mail:SetSize(50, 14)
		h.mail:SetPoint("LEFT", h.fs, "RIGHT", 6, 0)
		h.mail.fs = h.mail:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		h.mail.fs:SetPoint("LEFT")
		h.mail.fs:SetText("|cff888888Auto|r " .. MAIL_ICON)
		h.mail:SetScript("OnEnter", function(self)
			if not (h.sec and h.sec.mailTo) then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(T("These items are mailed to %s when you open a mailbox."):format("|cffffd100" .. h.sec.mailTo .. "|r"), 1, 1, 1, true)
			GameTooltip:Show()
		end)
		h.mail:SetScript("OnLeave", function() GameTooltip:Hide() end)
		-- Sorteerknop rechts: klik = volgende manier van sorteren
		h.sort = CreateFrame("Button", nil, h)
		h.sort:SetSize(15, 15)
		h.sort:SetPoint("RIGHT", h, "RIGHT", 0, 0)
		SetRedKit(h.sort, "128-redbutton-arrowdown", "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
		h.sort:SetScript("OnClick", function(self) OpenSortMenu(self, h.sec) end)
		h.sort:SetScript("OnEnter", function(self)
			if not h.sec then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local m = SortMode(h.sec)
			GameTooltip:AddLine(T("Sort: %s"):format(T(SORT_NAME[m])))
			GameTooltip:AddLine(T(SORT_TIP[m]), 1, 1, 1, true)
			GameTooltip:Show()
		end)
		h.sort:SetScript("OnLeave", function() GameTooltip:Hide() end)
		h:SetScript("OnEnter", function(self)
			local own = self.key and CatByKey(self.key)
			if not self.rules and not own then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(self.ruleTitle or "")
			if self.rules then GameTooltip:AddLine(self.rules, 1, 1, 1, true) end
			if own then GameTooltip:AddLine(T("Learned: %d items"):format(LearnedCount(self.key)), 0.7, 0.7, 0.7) end
			GameTooltip:Show()
		end)
		h:SetScript("OnLeave", function() GameTooltip:Hide() end)
		headerPool[usedHeaders] = h
	end
	h.rules, h.ruleTitle = nil, nil
	h:Show()
	return h
end

-- Assign: wat er gebeurt als je een item op een "+"-vakje laat vallen.
local function DropOn(sectionKey)
	local id = CursorItemID()
	if not id then return end
	if sectionKey == "hidden" then
		Hidden()[id] = true
	elseif sectionKey == "other" then
		Hidden()[id] = nil
		Assign()[id] = "other"
	else
		Hidden()[id] = nil
		Assign()[id] = sectionKey
	end
	Log("dropped " .. id .. " -> " .. sectionKey)
	ClearCursor() -- item gaat terug naar zijn eigen vakje
	ns.ResetOrder()
	ns.Refresh()
end

local function NewSlotTile(parent)
	local t = CreateFrame("Button", nil, parent)
	t:SetSize(ns.TILE, ns.TILE)
	t:RegisterForClicks("LeftButtonUp")
	t.bg = t:CreateTexture(nil, "BACKGROUND")
	t.bg:SetTexture(ns.SLOT_TEX)
	t.bg:SetPoint("TOPLEFT", -1, 1)
	t.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	t.bg:SetVertexColor(0.8, 0.8, 0.8, 0.7)
	t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	t.text:SetPoint("CENTER")
	return t
end

local function GetPlus()
	usedPlus = usedPlus + 1
	local t = plusPool[usedPlus]
	if not t then
		t = NewSlotTile(ns.main.content)
		t.text:SetText("+")
		t.text:SetTextColor(0.6, 0.6, 0.6)
		local function drop(self) DropOn(self.section) end
		t:SetScript("OnReceiveDrag", drop)
		t:SetScript("OnClick", drop)
		t:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(self.tipTitle)
			GameTooltip:AddLine(self.tipText, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		t:SetScript("OnLeave", function() GameTooltip:Hide() end)
		plusPool[usedPlus] = t
	end
	t:Show()
	return t
end

-- Vrije vakjes: liever een gewone tas dan een speciale (quiver, herb bag).
local function FirstFreeSlot()
	local id = CursorItemID()
	local itemFam = 0
	if id and C_Item.GetItemFamily then
		local okI, fam = pcall(C_Item.GetItemFamily, id)
		if okI and fam then itemFam = fam end
	end
	local isReagent = false
	if id and C_Item.GetItemInfo then
		local okR, r = pcall(function() return select(17, C_Item.GetItemInfo(id)) end)
		isReagent = okR and r and true or false
	end
	local best
	for _, f in ipairs(lastFree) do
		if f.reagent then
			-- reagent-tas: alleen crafting reagents passen erin, en dan alleen als laatste keus
			if isReagent then best = best or f end
		else
			local okF, _, family = pcall(C_Container.GetContainerNumFreeSlots, f.bag)
			family = okF and family or 0
			if family == 0 then return f end
			-- beroepstas: alleen als het item erin past
			if bit and bit.band and itemFam ~= 0 and bit.band(itemFam, family) ~= 0 then best = best or f end
		end
	end
	return best
end

local function SetupItemButton(b, g)
	local e = g.rep
	local info = e.info
	b.group = g
	b:SetBagID(e.bag)
	b:SetID(e.slot)
	pcall(ClearItemButtonOverlay, b)
	pcall(b.SetHasItem, b, info.iconFileID)
	SetItemButtonTexture(b, info.iconFileID)
	pcall(SetItemButtonQuality, b, info.quality, info.hyperlink, false, info.isBound)
	SetItemButtonCount(b, g.count)
	SetItemButtonDesaturated(b, info.isLocked)
	pcall(b.UpdateNewItem, b, info.quality)
	local isNew = false
	if C_NewItems and C_NewItems.IsNewItem then
		local okN, n = pcall(C_NewItems.IsNewItem, e.bag, e.slot)
		isNew = (okN and n) and true or false
	end
	-- Ook erbij geloot terwijl de tas open staat (ook als je het item al had).
	if freshIDs[g.itemID] then isNew = true end
	if b.newGlow then
		b.newGlow:SetShown(isNew)
		if isNew then
			-- niet opnieuw starten bij elke verversing, anders hapert het knipperen
			if b.newPulse and not (b.newPulse.IsPlaying and b.newPulse:IsPlaying()) then b.newPulse:Play() end
		elseif b.newPulse then b.newPulse:Stop() end
	end
	pcall(b.UpdateJunkItem, b, info.quality, info.hasNoValue)
	pcall(b.UpdateCooldown, b, info.iconFileID)
	local match = ns.searchText == "" or (g.name or ""):lower():find(ns.searchText, 1, true) ~= nil
	if b.SetMatchesSearch then pcall(b.SetMatchesSearch, b, match) end
	b:SetAlpha(match and 1 or 0.3)
	if #g.slots > 1 then
		b.multi:SetText(#g.slots .. "x")
		b.multi:Show()
	else
		b.multi:Hide()
	end
	if showHidden then
		if Hidden()[g.itemID] then b.overlay.tex:SetColorTexture(0.6, 0, 0, 0.35)
		else b.overlay.tex:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.12) end
		b.overlay:Show()
	else
		b.overlay:Hide()
	end
	b:Show()
end

ns.BLUE = "|cff66ccff"

-- Volgorde van alle groepen (eigen categorieën + vaste groepen), aanpasbaar in de opties.
ns.FIXED = { quest = true, keys = true, boe = true, grey = true, other = true }

function ns.FixOrder()
	CS().order = CS().order or {}
	local seen, clean = {}, {}
	for _, k in ipairs(CS().order) do
		if not seen[k] and (ns.FIXED[k] or CatByKey(k)) then clean[#clean + 1] = k; seen[k] = true end
	end
	-- Ontbrekende eigen categorieën: na de laatste eigen categorie (of bovenaan).
	for _, c in ipairs(CS().cats) do
		if not seen[c.key] then
			local pos = 0
			for idx, k in ipairs(clean) do if not ns.FIXED[k] then pos = idx end end
			table.insert(clean, pos + 1, c.key)
			seen[c.key] = true
		end
	end
	for _, k in ipairs({ "quest", "keys", "boe", "grey", "other" }) do
		if not seen[k] then clean[#clean + 1] = k end
	end
	CS().order = clean
	return clean
end

local function FixedSection(key)
	if key ~= "other" and not On(key) then return nil end
	if key == "quest" then
		return { key = "quest", title = T("Quest"), plus = true, fixed = true,
			tip = T("Drop an item: it goes here from now on."),
			rules = T("Quest items. Never sold or mailed.") }
	elseif key == "keys" then
		return { key = "keys", title = T("Keys"), plus = false, fixed = true,
			rules = T("Your keyring.") }
	elseif key == "boe" then
		return { key = "boe", title = "BoE", mailTo = (ns.DB.boeMail ~= "" and ns.DB.boeMail or nil), plus = true, fixed = true,
			tip = T("Drop an item: it goes here from now on."),
			rules = T("Unbound BoE items, green and better.") }
	elseif key == "grey" then
		return { key = "grey", title = "Auto Sell" .. ((ns.DB.autoSell or not ns.DB.autoSellAsked) and "" or ("  |cff888888(" .. T("selling is off") .. ")|r")), plus = true, byValue = true, fixed = true,
			tip = T("Drop an item: it goes here from now on."),
			rules = T("Grey items. Sold at a vendor (Shift = skip).") }
	elseif key == "other" then
		return { key = "other", title = T("Other"), plus = true, fixed = true,
			tip = T("Drop an item: it goes here from now on."),
			rules = T("Everything without a group.") }
	end
end

function ns.SectionList()
	local list = {}
	for _, key in ipairs(ns.FixOrder()) do
		if ns.FIXED[key] then
			local sec = FixedSection(key)
			if sec then list[#list + 1] = sec end
		else
			local c = CatByKey(key)
			local title = c.name
			list[#list + 1] = { key = c.key, title = title, plus = true, byValue = (c.mailTo and c.mailTo ~= "") and "ah" or nil,
				mailTo = (c.mailTo and c.mailTo ~= "") and c.mailTo or nil,
				tip = T("Drop an item: it goes here from now on."),
				rules = c.preset and T(PRESET[c.preset].tip) or nil }
		end
	end
	if showHidden then
		list[#list + 1] = { key = "hidden", title = T("Hidden"), plus = true, fixed = true,
			tip = T("Drop an item to hide it."),
			rules = T("Your hidden items.") }
	end
	return list
end

local gapPool, usedGaps = {}, 0
local FOOTER_H = ns.TILE + 6

-- Gat op de plek van een item dat net op is (tot je de tassen sluit).
-- Laat je er een item op vallen, dan gaat het naar een leeg vakje.
local function GetGap()
	usedGaps = usedGaps + 1
	local t = gapPool[usedGaps]
	if not t then
		t = NewSlotTile(ns.main.content)
		t.bg:SetVertexColor(0.5, 0.5, 0.5, 0.5)
		local function drop()
			if not CursorHasItem() then return end
			local f = FirstFreeSlot()
			if f then C_Container.PickupContainerItem(f.bag, f.slot) end
		end
		t:SetScript("OnReceiveDrag", drop)
		t:SetScript("OnClick", drop)
		gapPool[usedGaps] = t
	end
	t:Show()
	return t
end

local function StripColors(t)
	return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Layout()
	if not ns.main or not ns.main:IsShown() then return end
	if not ns.DB.enabled then ns.main:Hide(); return end
	-- Tassenknoppen zijn geen beschermde frames: opbouwen mag ook in een gevecht.
	if inLayout then return end
	inLayout = true

	local items, free, total = Scan()
	lastFree, lastItems = free, items

	-- 1. Groeperen per sectie (en per item als stapels samengevoegd worden).
	local bySection, hiddenCount = {}, 0
	for _, e in ipairs(items) do
		local sec = SectionOf(e)
		if sec == "hidden" then hiddenCount = hiddenCount + 1 end
		local s = bySection[sec]
		if not s then s = { groups = {}, byKey = {} }; bySection[sec] = s end
		local key = (ns.DB.merge and e.maxStack > 1) and ("i" .. e.itemID) or ("s" .. e.bag .. ":" .. e.slot)
		local g = s.byKey[key]
		if not g then
			g = { key = key, slots = {}, count = 0, quality = e.quality, name = e.name, link = e.link, itemID = e.itemID, price = e.price, value = 0, ahValue = 0 }
			s.byKey[key] = g
			s.groups[#s.groups + 1] = g
		end
		g.slots[#g.slots + 1] = e
		g.count = g.count + e.count
		g.value = g.value + (e.price or 0) * e.count
		local c = CatByKey(sec)
		if c and c.mailTo and c.mailTo ~= "" then
			-- AH-waarde van de hele stapel; geen AH-prijs bekend = vendorprijs.
			g.ahValue = g.ahValue + (AHPrice(e.link) or e.price or 0) * e.count
		end
		-- Klik gebruikt de kleinste stapel, zo raakt hij het eerst leeg.
		if not g.rep or e.count < g.rep.count then g.rep = e end
	end

	-- Nieuwste als laatst: onthoud wanneer een item voor het eerst in je tassen kwam.
	do
		local ch, now, present = CharData(), (time and time()) or 0, {}
		for _, e in ipairs(items) do
			present[e.itemID] = true
			if not ch.seen[e.itemID] then ch.seen[e.itemID] = now end
		end
		for id in pairs(ch.seen) do if not present[id] then ch.seen[id] = nil end end
	end

	-- Erbij geloot terwijl het venster open is: meer dan de laagste stand sinds openen.
	-- (Laagste stand: een drankje drinken en er daarna één looten telt ook als nieuw.)
	do
		local counts = {}
		for _, e in ipairs(items) do counts[e.itemID] = (counts[e.itemID] or 0) + (e.count or 1) end
		if not openCounts then
			openCounts = counts
		else
			for id, n in pairs(counts) do
				local was = openCounts[id] or 0
				if n > was then freshIDs[id] = true end
				if n < was then openCounts[id] = n end
			end
			for id in pairs(openCounts) do if not counts[id] then openCounts[id] = 0 end end
		end
	end

	-- 2. Per sectie sorteren, of de vaste volgorde aanhouden zolang het venster open is.
	local full = {}
	for _, sec in ipairs(ns.SectionList()) do
		local s = bySection[sec.key]
		local groups = s and s.groups or {}
		local field = (sec.byValue == "ah") and "ahValue" or "value"
		local mode = SortMode(sec)
		local ch = CharData()
		local function newer(a, b)
			local ta, tb = ch.seen[a.itemID] or 0, ch.seen[b.itemID] or 0
			if ta ~= tb then return ta < tb end
			return a.name < b.name
		end
		if mode == "value" then
			table.sort(groups, function(a, b)
				if a[field] ~= b[field] then return a[field] > b[field] end
				return a.name < b.name
			end)
		elseif mode == "newest" then
			table.sort(groups, newer)
		elseif mode == "manual" then
			local pos = {}
			for i, id in ipairs(ch.manual[sec.key] or {}) do pos[id] = pos[id] or i end
			table.sort(groups, function(a, b)
				local pa, pb = pos[a.itemID], pos[b.itemID]
				if pa and pb then if pa ~= pb then return pa < pb end return a.key < b.key end
				if pa or pb then return pa ~= nil end
				return newer(a, b)
			end)
		else
			table.sort(groups, newer)
		end
		local cells = {}
		local order = frozen[sec.key]
		if order then
			local byKey = s and s.byKey or {}
			local used = {}
			for _, k in ipairs(order) do
				if byKey[k] then cells[#cells + 1] = byKey[k]; used[k] = true
				else cells[#cells + 1] = { gap = true } end
			end
			for _, g in ipairs(groups) do
				if not used[g.key] then cells[#cells + 1] = g; order[#order + 1] = g.key end
			end
		else
			order = {}
			for _, g in ipairs(groups) do cells[#cells + 1] = g; order[#order + 1] = g.key end
			frozen[sec.key] = order
		end
		local title = sec.title
		CS().collapsed = CS().collapsed or {}
		if CS().collapsed[sec.key] then
			full[#full + 1] = { sec = sec, cells = {}, title = title, collapsed = true, n = #groups }
		-- Ook een groep met alleen nog gaten blijft staan tot je de tassen sluit.
		elseif #cells > 0 then
			full[#full + 1] = { sec = sec, cells = cells, title = title }
		elseif sec.plus or (sec.fixed and sec.key ~= "hidden" and (sec.key ~= "keys" or KeyringBag())) then
			-- Lege groep: gewone regel (met het lege +vakje als die er een heeft).
			full[#full + 1] = { sec = sec, cells = cells, title = title }
		end
	end

	usedItems, usedHeaders, usedPlus, usedGaps = 0, 0, 0, 0

	-- 4. Hoogte uitrekenen voor een aantal kolommen.
	local function Measure(cols)
		local h = 8
		for _, f in ipairs(full) do
			local n = f.collapsed and 0 or (#f.cells + (f.sec.plus and 1 or 0))
			h = h + 18 + math.ceil(n / cols) * (ns.TILE + ns.GAP) + 6
		end
		return h
	end

	-- 5. Kolommen kiezen: eerst breder (tot het maximum), dan pas scrollen.
	local top = showHidden and 78 or 62
	local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
	if screenH <= 0 then screenH = 768 end
	local maxView = math.floor(screenH * 0.8) - top - FOOTER_H - ns.PAD
	-- Breedte = het aantal kolommen uit de opties, maar nooit breder dan je scherm.
	local fit = math.floor(((UIParent:GetWidth() or 1200) - 80) / (ns.TILE + ns.GAP))
	local cols = math.max(5, math.min(ns.DB.maxCols, fit))
	local contentH = Measure(cols)
	local width = cols * (ns.TILE + ns.GAP) - ns.GAP

	-- 6. Plaatsen.
	local y = -8
	local function place(frame, col)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", ns.main.content, "TOPLEFT", col * (ns.TILE + ns.GAP), y)
	end
	for _, f in ipairs(full) do
		local h = GetHeader()
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", ns.main.content, "TOPLEFT", 0, y)
		h:SetWidth(width)
		h.key, h.sec = f.sec.key, f.sec
		local t = f.sec.fixed and (ns.BLUE .. f.title .. "|r") or f.title
		if f.collapsed and f.n > 0 then t = t .. "  |cff888888(" .. f.n .. ")|r" end
		h:SetText(t)
		SetRedKit(h.toggle, f.collapsed and "128-redbutton-plus" or "128-redbutton-minus",
			f.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
		h.sort:SetShown(ns.DB.showSort and not f.collapsed and f.sec.key ~= "hidden" and f.sec.key ~= "keys" or false)
		h.mail:SetShown(f.sec.mailTo ~= nil)
		h.sort.mode = SortMode(f.sec)
		h.rules, h.ruleTitle = f.sec.rules, StripColors(f.sec.title)
		y = y - 18
		local col = 0
		local ids = {}
		lastOrder[f.sec.key] = ids
		for _, cell in ipairs(f.collapsed and {} or f.cells) do
			local b
			if cell.gap then
				b = GetGap()
			else
				b = GetItemButton()
				SetupItemButton(b, cell)
				b.secKey = f.sec.key
				ids[#ids + 1] = cell.itemID
			end
			place(b, col)
			col = col + 1
			if col == cols then col = 0; y = y - (ns.TILE + ns.GAP) end
		end
		if f.sec.plus and not f.collapsed then
			local p = GetPlus()
			p.section = f.sec.key
			p.tipTitle = StripColors(f.sec.title)
			p.tipText = f.sec.tip
			place(p, col)
			col = col + 1
		end
		if col > 0 then y = y - (ns.TILE + ns.GAP) end
		y = y - 6
	end
	for i = usedItems + 1, #itemPool do itemPool[i]:Hide(); itemPool[i].group = nil end
	for i = usedHeaders + 1, #headerPool do headerPool[i]:Hide() end
	for i = usedPlus + 1, #plusPool do plusPool[i]:Hide() end
	for i = usedGaps + 1, #gapPool do gapPool[i]:Hide() end

	-- 7. Scrollgebied en venstergrootte.
	local keep = keepHeader
	contentH = -y
	local viewH = math.min(contentH, maxView)
	ns.main.content:SetSize(width, contentH)
	ns.main.scroll:ClearAllPoints()
	ns.main.scroll:SetPoint("TOPLEFT", ns.main, "TOPLEFT", ns.PAD, -top)
	ns.main.scroll:SetSize(width, viewH)
	ns.main.scrollMax = math.max(0, contentH - viewH)
	local cur = ns.main.scroll.GetVerticalScroll and ns.main.scroll:GetVerticalScroll() or 0
	if cur > ns.main.scrollMax then ns.main.scroll:SetVerticalScroll(ns.main.scrollMax) end
	ns.main.scrollHint:SetShown(ns.main.scrollMax > 0)
	if keep then
		keepHeader = nil
		for i = 1, usedHeaders do
			local h = headerPool[i]
			if h.key == keep.key and keep.top then
				local now = h:GetTop()
				local p, rel, rp, x, yy = ns.main:GetPoint(1)
				if now and p then
					ns.main:ClearAllPoints()
					ns.main:SetPoint(p, rel, rp, x, yy + (keep.top - now))
					ns.SavePos()
				end
			end
		end
	end

	-- Voetregel: vrije vakjes + goud, altijd onderaan in beeld.
	local used = math.max(0, total - #free)
	local frac = total > 0 and used / total or 0
	ns.main.freeBar:SetValue(frac)
	-- vloeiend van groen naar oranje naar rood
	local r, g, bl
	if frac < 0.6 then r, g, bl = 0.30, 0.80, 0.40
	elseif frac < 0.85 then local t = (frac - 0.6) / 0.25; r, g, bl = 0.30 + 0.70 * t, 0.80 - 0.10 * t, 0.40 - 0.30 * t
	else local t = math.min(1, (frac - 0.85) / 0.15); r, g, bl = 1.00 - 0.10 * t, 0.70 - 0.50 * t, 0.10 + 0.05 * t end
	ns.main.freeBar:SetStatusBarColor(r, g, bl)
	ns.main.freeBar.text:SetText(used .. "/" .. total)
	ns.main.freeBar.free, ns.main.freeBar.total = #free, total
	local money = GetMoney()
	if money >= 10000 then money = money - money % 100 end -- met goud: geen koper meer tonen
	ns.main.money:SetText(GetMoneyString and GetMoneyString(money, true) or tostring(money))

	ns.main.hiddenBtn.count:SetText(hiddenCount > 0 and hiddenCount or "")
	SetRedKit(ns.main.hiddenBtn, showHidden and "128-redbutton-visibilityon" or "128-redbutton-visibilityoff", "Interface\\Icons\\Spell_Shadow_EvilEye")
	ns.main.hint:SetShown(showHidden)

	ns.main:SetSize(width + 2 * ns.PAD, top + viewH + FOOTER_H + ns.PAD)
	inLayout = false

	if ns.needInfo and not ns.main.infoRetry then
		ns.main.infoRetry = true
		C_Timer.After(1, function() ns.main.infoRetry = nil; ns.Refresh() end)
	end
end

local refreshQueued = false
ns.Refresh = function()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0.05, function()
		refreshQueued = false
		local ok, err = pcall(Layout)
		inLayout = false
		if not ok then ns.DB.lastError = tostring(err); Log("error: " .. tostring(err)); Print(T("error: %s"):format(tostring(err))) end
	end)
end

function ns.ShowMain()
	if InCombatLockdown() then Log("opened during combat") end
	ns.main:Show()
	ns.Refresh()
end

ns.SavePos = function()
	local point, _, rel, x, y = ns.main:GetPoint(1)
	ns.DB.pos = { point = point, rel = rel, x = x, y = y }
end


function ns.BuildMain()
	ns.main = ns.NewWindow("CarefreeBagFrame", "CarefreeBag", 438, 300)
	ns.main:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); ns.SavePos() end)
	if ns.DB.pos then
		ns.main:SetPoint(ns.DB.pos.point or "BOTTOMRIGHT", UIParent, ns.DB.pos.rel or ns.DB.pos.point or "BOTTOMRIGHT", ns.DB.pos.x or -80, ns.DB.pos.y or 120)
	else
		ns.main:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
	end
	ns.main:SetScript("OnShow", function() if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_BACKPACK_OPEN) end end)
	ns.main:SetScript("OnHide", function()
		showHidden = false
		openCounts, freshIDs = nil, {}
		ns.ResetOrder() -- volgende keer openen: netjes opnieuw gesorteerd
		-- Tas dicht: nieuwe items zijn gezien, markering weghalen.
		if C_NewItems and C_NewItems.RemoveNewItem then
			for _, e in ipairs(lastItems) do
				local okN, isNew = pcall(C_NewItems.IsNewItem, e.bag, e.slot)
				if okN and isNew then pcall(C_NewItems.RemoveNewItem, e.bag, e.slot) end
			end
		end
		if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.IG_BACKPACK_CLOSE) end
	end)

	-- Twee rode Blizzard-knoppen rechtsboven: verbergen en opties.
	ns.main.optBtn = RedButton(ns.main, "CarefreeBagOptionsButton", 24, "128-RedButton", "Interface\\Icons\\Trade_Engineering",
		{ "GM-icon-settings", "questlog-icon-setting", "OptionsIcon-Brown" })
	ns.main.optBtn:SetPoint("TOPRIGHT", ns.main, "TOPRIGHT", -ns.PAD, -32)
	ns.main.optBtn:SetScript("OnClick", function() ns.ToggleConfig() end)
	ns.Tooltip(ns.main.optBtn, T("Options"))
	ns.main.hiddenBtn = RedButton(ns.main, "CarefreeBagHideButton", 24, "128-redbutton-visibilityoff", "Interface\\Icons\\Spell_Shadow_EvilEye")
	ns.main.hiddenBtn:SetPoint("RIGHT", ns.main.optBtn, "LEFT", -4, 0)
	ns.main.hiddenBtn.count = ns.main.hiddenBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	ns.main.hiddenBtn.count:SetPoint("BOTTOMRIGHT", ns.main.hiddenBtn, "BOTTOMRIGHT", 2, -2)
	ns.main.hiddenBtn:SetScript("OnClick", function() showHidden = not showHidden; ns.Refresh() end)
	ns.Tooltip(ns.main.hiddenBtn, T("Hide items"))
	-- Bank en je andere karakters bekijken (paneel ernaast).
	ns.main.bankBtn = RedButton(ns.main, "CarefreeBagBankButton", 24, "128-RedButton", "Interface\\Icons\\INV_Misc_Bag_10_Blue")
	ns.main.bankBtn:SetPoint("RIGHT", ns.main.hiddenBtn, "LEFT", -4, 0)
	ns.main.bankBtn.icon = ns.main.bankBtn:CreateTexture(nil, "OVERLAY")
	ns.main.bankBtn.icon:SetTexture("Interface\\Minimap\\Tracking\\Banker")
	ns.main.bankBtn.icon:SetSize(16, 16)
	ns.main.bankBtn.icon:SetPoint("CENTER", 0, 1)
	ns.main.bankBtn:SetScript("OnClick", function() ns.ToggleViewer() end)
	ns.Tooltip(ns.main.bankBtn, T("Bank & alts"), T("See your bank, and the bags and bank of your other characters."))

	-- Zoekbalk: typ een naam, alles wat niet past wordt grijs.
	local okS, sb = pcall(CreateFrame, "EditBox", "CarefreeBagSearch", ns.main, "SearchBoxTemplate")
	if not okS then sb = CreateFrame("EditBox", "CarefreeBagSearch", ns.main, "InputBoxTemplate") end
	sb:SetSize(200, 20)
	sb:SetAutoFocus(false)
	sb:SetPoint("TOPLEFT", ns.main, "TOPLEFT", ns.PAD + 6, -34)
	sb:SetPoint("RIGHT", ns.main.bankBtn, "LEFT", -8, 0)
	sb:HookScript("OnTextChanged", function(self)
		local t = (self:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
		if t ~= ns.searchText then ns.searchText = t; ns.Refresh(); if ns.ViewRefresh then ns.ViewRefresh() end end
	end)
	sb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	if type(sb.Instructions) == "table" and sb.Instructions.SetText then pcall(sb.Instructions.SetText, sb.Instructions, T("Search...")) end
	ns.main.search = sb

	ns.main.hint = ns.main:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	ns.main.hint:SetPoint("TOPLEFT", ns.main, "TOPLEFT", ns.PAD, -60)
	ns.main.hint:SetText(T("|cffffd100Hiding:|r click an item to hide it or show it again."))
	ns.main.hint:Hide()

	-- Scrollgebied: alleen nodig als het venster op zijn breedst nog te hoog is.
	ns.main.scroll = CreateFrame("ScrollFrame", nil, ns.main)
	ns.main.scroll:SetPoint("TOPLEFT", ns.main, "TOPLEFT", ns.PAD, -62)
	ns.main.scroll:SetSize(100, 100)
	ns.main.content = CreateFrame("Frame", nil, ns.main.scroll)
	ns.main.content:SetSize(100, 100)
	ns.main.scroll:SetScrollChild(ns.main.content)
	ns.main.scrollMax = 0
	ns.main.scroll:EnableMouseWheel(true)
	ns.main.scroll:SetScript("OnMouseWheel", function(self, delta)
		local v = (self:GetVerticalScroll() or 0) - delta * (ns.TILE + ns.GAP)
		self:SetVerticalScroll(math.max(0, math.min(ns.main.scrollMax or 0, v)))
	end)
	ns.main.scrollHint = ns.main:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	ns.main.scrollHint:SetPoint("BOTTOMRIGHT", ns.main, "BOTTOMRIGHT", -ns.PAD, FOOTER_H + 2)
	ns.main.scrollHint:SetText(T("scroll for more"))
	ns.main.scrollHint:Hide()

	-- Balk die laat zien hoe vol je tassen zitten (groen, oranje, rood).
	-- Balk in Blizzard-stijl, zoals de levensbalk in een tooltip.
	local bar = CreateFrame("StatusBar", "CarefreeBagFreeBar", ns.main)
	bar:SetSize(150, 10)
	bar:SetPoint("LEFT", ns.main, "BOTTOMLEFT", ns.PAD + 4, ns.PAD - 2 + ns.TILE / 2)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetMinMaxValues(0, 1)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar)
	bar.bg:SetColorTexture(0, 0, 0, 0.6)
	bar.border = bar:CreateTexture(nil, "OVERLAY")
	bar.border:SetTexture("Interface\\Tooltips\\UI-StatusBar-Border")
	bar.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
	bar.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
	bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.text:SetPoint("LEFT", bar, "RIGHT", 6, 0)
	bar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(T("Free slots: %s of %s"):format(tostring(self.free or "?"), tostring(self.total or "?")))
		GameTooltip:Show()
	end)
	bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
	ns.main.freeBar = bar
	ns.main.money = ns.main:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	ns.main.money:SetJustifyH("RIGHT")
	ns.main.money:SetPoint("RIGHT", ns.main, "BOTTOMRIGHT", -ns.PAD - 4, ns.PAD - 2 + ns.TILE / 2)
end
