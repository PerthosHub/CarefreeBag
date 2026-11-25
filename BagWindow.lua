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
	-- Zonder OnDragStop blijft het venster na loslaten aan de muis plakken.
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
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

-- Goud onderaan de tassen. Met goud: geen koper, maar het zilver altijd (ook "0"),
-- want GetMoneyString laat een 0 weg (1g 0s werd "1g").
function ns.FooterMoney(m)
	m = math.floor(m or 0)
	local function MS(x) return GetMoneyString and GetMoneyString(x, true) or tostring(x) end
	if m < 10000 then return MS(m) end
	local s = math.floor(m / 100) % 100
	local silver
	if SILVER_AMOUNT_TEXTURE then
		local ok, t = pcall(string.format, SILVER_AMOUNT_TEXTURE, s, 0, 0)
		if ok then silver = t end
	end
	return MS(m - m % 10000) .. " " .. (silver or (s .. "s"))
end

---------------------------------------------------------------------------
-- Optievenster en bankpaneel zitten vast naast de tassen: links (standaard)
-- of rechts, per karakter. Een pijltje aan de kant van de tassen wisselt.
---------------------------------------------------------------------------

local sidePanels = {}

function ns.PanelSide()
	local ch = CharEntry()
	return (ch and ch.panelSide == "right") and "right" or "left"
end

local function PlaceSideArrow(f)
	local a = f.sideArrow
	if not a then return end
	local right = ns.PanelSide() == "right"
	a:ClearAllPoints()
	-- Aan de kant van de tassen, wijzend naar de tassen (en eroverheen). Valt het venster
	-- half buiten beeld, dan zit het pijltje nog aan de kant die wel te zien is.
	if right then a:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -7)
	else a:SetPoint("TOPRIGHT", f, "TOPRIGHT", -38, -7) end -- naast het kruisje
	local tex = right and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-"
	a:SetNormalTexture(tex .. "Up")
	a:SetPushedTexture(tex .. "Down")
	a:SetShown(f.docked ~= false)
end

-- Venster naast de tassen zetten, aan de gekozen kant.
function ns.DockPanel(f)
	f:ClearAllPoints()
	if ns.PanelSide() == "right" then f:SetPoint("TOPLEFT", ns.main, "TOPRIGHT", 4, 0)
	else f:SetPoint("TOPRIGHT", ns.main, "TOPLEFT", -4, 0) end
	PlaceSideArrow(f)
end

function ns.AddSideArrow(f)
	sidePanels[#sidePanels + 1] = f
	local a = CreateFrame("Button", nil, f)
	a:SetSize(24, 24)
	a:SetFrameLevel(f:GetFrameLevel() + 10)
	a:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	a:SetScript("OnClick", function()
		local ch = CharEntry()
		if not ch then return end
		ch.panelSide = (ns.PanelSide() == "right") and "left" or "right"
		Log("panels on the " .. ch.panelSide .. " of the bags")
		for _, p in ipairs(sidePanels) do if p.docked ~= false then ns.DockPanel(p) end end
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
	end)
	a:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(T("Move to the other side of your bags"))
		GameTooltip:Show()
	end)
	a:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.sideArrow = a
	PlaceSideArrow(f)
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

-- Alle nieuwe items als gezien markeren (tas dicht of beginnen met zoeken).
local function ClearNew()
	openCounts, freshIDs = nil, {} -- nil: de volgende opbouw neemt de huidige stand als basis
	if C_NewItems and C_NewItems.RemoveNewItem then
		for _, e in ipairs(lastItems) do
			local okN, isNew = pcall(C_NewItems.IsNewItem, e.bag, e.slot)
			if okN and isNew then pcall(C_NewItems.RemoveNewItem, e.bag, e.slot) end
		end
	end
end
ns.searchText = ""
-- Vaste volgorde zolang het venster open is: [sectie] = { key, key, ... }.
-- Leeg = opnieuw sorteren (bij openen, of als je een categorie wijzigt).
local frozen = {}
function ns.ResetOrder() frozen = {} end

local function CursorItemID()
	local kind, id = GetCursorInfo()
	if kind == "item" then return id end
end

-- Komt het item op de cursor uit je tassen? Dan staat het vakje waar het uit komt op slot.
-- Zo niet, dan komt het van ergens anders (wat je aan hebt, de bank).
local function FromBags(id)
	for _, e in ipairs(lastItems) do
		if e.itemID == id then
			local ok, info = pcall(C_Container.GetContainerItemInfo, e.bag, e.slot)
			if ok and info and info.isLocked then return true end
		end
	end
	return false
end
local StoreCursorItem -- staat verderop, na FirstFreeSlot

-- Gesplitste stapel (Shift-klik, bijv. 10 van 20) op de cursor. CFB toont één vakje per item, dus
-- er is geen leeg vakje om hem op te leggen: terugleggen op het item voegde hem weer samen
-- (Johan, 2026-11-24). Zolang een gesplitste stapel aan de muis hangt, ligt er over elk item een
-- vanger: klik of loslaten = in een vrij vakje. Achtergrond, vulbalk en "+" doen hetzelfde.
local split -- { id = itemID } zolang de gesplitste stapel op de cursor zit
ns.splitKeep = {} -- [itemID] = zelf gesplitst: aparte vakjes tot je de tas sluit
local function SplitOnCursor()
	if not split then return false end
	if not CursorHasItem() or CursorItemID() ~= split.id then split = nil; return false end
	return true
end
local splitWatch = CreateFrame("Frame")
splitWatch:Hide()
local function ShowCatchers(on)
	for _, b in ipairs(itemPool) do
		if b.splitCatch then b.splitCatch:SetShown(on and b:IsShown() and true or false) end
	end
end
local function CheckSplit()
	-- ook na een Refresh (nieuwe tegels) blijven de vangers kloppen
	if SplitOnCursor() then ShowCatchers(true); return end
	ShowCatchers(false); splitWatch:Hide()
end
splitWatch:SetScript("OnUpdate", CheckSplit)
local function OnSplit(bag, slot)
	local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
	if not (ok and info and info.itemID) then return end
	if split and split.id == info.itemID and SplitOnCursor() then return end -- al gezien (2 hooks)
	-- Gesplitst in de bank: gewoon WoW (bij je stapel leggen = erbij, zie MergeCursorInto).
	for _, id in ipairs(ns.BankBags and ns.BankBags() or {}) do
		if id == bag then return end
	end
	split = { id = info.itemID }
	-- Zelf gesplitst = bewust losse stapels: elk een eigen vakje (GroupItems) en niet vanzelf
	-- samenvoegen (Chores.lua). Tas dicht = vergeten, dan mag alles weer samen (Johan, 2026-11-25).
	ns.splitKeep[info.itemID] = true
	Log("split " .. info.itemID .. " from " .. tostring(bag) .. ":" .. tostring(slot))
	ShowCatchers(true); splitWatch:Show()
end
if C_Container and C_Container.SplitContainerItem then hooksecurefunc(C_Container, "SplitContainerItem", OnSplit) end
if _G.SplitContainerItem then hooksecurefunc("SplitContainerItem", OnSplit) end
-- Item op de cursor dat (nog) geen eigen vakje heeft: van buiten je tassen, of een gesplitste stapel.
local function Loose(id) return SplitOnCursor() or not FromBags(id) end

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
ns.shownOrder = lastOrder -- (alleen lezen; tests)

-- Komt het item op de cursor uit dezelfde groep als deze tegel?
local function ReorderTarget(b)
	local id = CursorItemID()
	local g = b.group
	if not id or not g or id == g.itemID or not b.secKey then return false end
	-- Van buiten je tassen (bank, wat je aan hebt): geen volgorde, maar in je tassen leggen.
	if not FromBags(id) then return false end
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
	-- Eén gedrag: het item neemt de plek van de tegel in, de rest schuift op.
	table.remove(list, from)
	table.insert(list, to, id)
	CS().sort = CS().sort or {}
	if CS().sort[key] ~= "manual" then
		CS().sort[key] = "manual"
		Print(T("Sorting set to manual for this group."))
	end
	CharData().manual[key] = list
	Log("reorder " .. key .. ": " .. id .. " -> plek van " .. target)
	ClearCursor()
	b.swapMark:Hide(); b.watch:Hide()
	ns.ResetOrder(); ns.Refresh()
	return true
end

local function NewItemButton(i)
	local b = CreateFrame("ItemButton", "CarefreeBagItem" .. i, ns.main.content, "ContainerFrameItemButtonTemplate")
	b:SetSize(ns.TILE, ns.TILE)
	b.isCarefreeItem = true
	HookAHTooltip()
	-- Volgorde aanpassen: sleep een item op een ander item in dezelfde groep (gouden rand =
	-- hier komt het, de rest schuift op).
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
			b.swapMark:Hide(); b.watch:Hide(); return
		end
		b.swapMark:Show()
	end)
	b:HookScript("OnEnter", function(self)
		if ReorderTarget(self) then self.watch:Show() end
	end)
	b:HookScript("OnLeave", function(self) self.swapMark:Hide(); self.watch:Hide() end)
	-- Rechtsklik op een tas: slim wisselen als alle tasvakken vol zijn (BagSwap.lua).
	-- Rechtsklik bij de mailbox: alle stapels van dit vakje in de mail (Mail.lua).
	b:HookScript("PreClick", function(self, button)
		-- Het getal op het vakje is alles bij elkaar (bijv. 60), maar splitsen kan alleen binnen
		-- één stapel: WoW's splitsvenster krijgt daarom het echte aantal van de stapel.
		-- (Niet afhankelijk van IsShiftKeyDown: die mist de eerste klik vanuit een ander venster.)
		if self.group and self.group.rep then self.count = self.group.rep.count end
		-- Oppakken (klik zonder iets aan de muis) bij de bank: de rest volgt als het in de bank landt.
		if button == "LeftButton" and not CursorHasItem() and ns.BankPickup then
			pcall(ns.BankPickup, self.group, self:GetBagID(), self:GetID())
		end
		if button ~= "RightButton" then return end
		if ns.BagRightClick then pcall(ns.BagRightClick, self:GetBagID(), self:GetID()) end
		if ns.MailAttachRest then pcall(ns.MailAttachRest, self.group, self:GetBagID(), self:GetID()) end
	end)
	-- Slepen = ook oppakken.
	b:HookScript("OnDragStart", function(self)
		if ns.BankPickup then pcall(ns.BankPickup, self.group, self:GetBagID(), self:GetID()) end
	end)
	local origDrag = b:GetScript("OnReceiveDrag")
	b:SetScript("OnReceiveDrag", function(self, ...)
		if Reorder(self) then return end
		-- Iets van buiten je tassen (bijv. de bank, wat je aan hebt): op hetzelfde item = bij die
		-- stapel erbij (issue #15), anders naar een vrij vakje, niet ruilen.
		local id = CursorItemID()
		if id and not FromBags(id) then
			if self.group and self.group.itemID == id and ns.MergeCursorInto(id, self.group.rep) then return end
			if StoreCursorItem(true) then return end
		end
		if origDrag then return origDrag(self, ...) end
	end)
	-- Vanger voor een gesplitste stapel (zie SplitOnCursor): alleen zichtbaar zolang die aan de muis hangt.
	local c = CreateFrame("Button", nil, b)
	c:SetAllPoints(b)
	c:SetFrameLevel(b:GetFrameLevel() + 6)
	c:RegisterForClicks("LeftButtonUp")
	c:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	-- Volle tassen: op een stapel van hetzelfde item = er weer bij.
	local function catch()
		if SplitOnCursor() and not StoreCursorItem(true) then
			local id = CursorItemID()
			if not (b.group and b.group.itemID == id and ns.MergeCursorInto(id, b.group.rep)) then
				StoreCursorItem() -- geeft de melding "Inventory is full"
			end
		end
		CheckSplit()
	end
	c:SetScript("OnClick", catch)
	c:SetScript("OnReceiveDrag", catch)
	c:Hide()
	b.splitCatch = c
	-- WoW's splitsvenster roept owner:SplitStack(n) aan. Ook hier luisteren: als WoW de functie
	-- C_Container.SplitContainerItem al vóór CFB in een local had gezet, mist de hook hierboven hem.
	if type(b.SplitStack) == "function" then
		hooksecurefunc(b, "SplitStack", function(self) OnSplit(self:GetBagID(), self:GetID()) end)
	end
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
		-- Groep Quest: oranje "3 leftovers" (of grijs "2 kept"); klik = lijstje met knoppen (QuestReminder.lua)
		h.quest = CreateFrame("Button", nil, h)
		h.quest:SetSize(90, 14)
		h.quest:SetPoint("LEFT", h.fs, "RIGHT", 8, 0)
		h.quest.fs = h.quest:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		h.quest.fs:SetPoint("LEFT")
		h.quest:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		h.quest:SetScript("OnClick", function() if ns.QuestReminderOpen then ns.QuestReminderOpen() end end)
		h.quest:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(T("Quest items you may not need"))
			GameTooltip:AddLine(T("Click: keep, remind me next level, or see why you may still need them."), 1, 1, 1, true)
			GameTooltip:Show()
		end)
		h.quest:SetScript("OnLeave", function() GameTooltip:Hide() end)
		h.quest:Hide()
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
	local outside = Loose(id)
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
	if ns.StatsCount then ns.StatsCount("dr") end -- gebruiksstatistieken (Stats.lua)
	-- Uit je tassen: terug naar zijn eigen vakje. Van ergens anders: in een vrij vakje leggen.
	if not (outside and StoreCursorItem()) then ClearCursor() end
	CheckSplit()
	-- Niet opnieuw sorteren (Johan, 2026-11-21): het item komt achteraan in de groep waar je
	-- het losliet, de rest blijft staan. Netjes sorteren gebeurt pas bij het weer openen.
	-- Stond het deze keer al eerder in die groep, dan ook achteraan (niet op zijn oude plek).
	local order = frozen[sectionKey]
	if order then
		for i = #order, 1, -1 do if order[i].id == id then table.remove(order, i) end end
	end
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

-- Item op de cursor in een vrij vakje leggen. Geen plek: melding (behalve als quiet).
StoreCursorItem = function(quiet)
	if not CursorHasItem() then return false end
	-- een tas uit de tassenbalk: eerst leeghalen, dan uitdoen (BagSwap.lua)
	if ns.BagUnequip and ns.BagUnequip() then return true end
	local f = FirstFreeSlot()
	if not f then
		if not quiet and UIErrorsFrame and ERR_INV_FULL then pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, ERR_INV_FULL, 1, 0.1, 0.1) end
		return false
	end
	Log("stored cursor item " .. tostring(CursorItemID()) .. " in " .. f.bag .. ":" .. f.slot)
	C_Container.PickupContainerItem(f.bag, f.slot)
	return true
end

-- Bank open en het item op de cursor komt uit de bank: welk bankvakje (dat staat op slot)?
local function BankSource(id)
	if not ns.bankOpen or not ns.BankBags then return nil end
	for _, bag in ipairs(ns.BankBags()) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID == id and info.isLocked then return { bag = bag, slot = slot } end
		end
	end
end

-- Een stapel van dit item in je tassen met plek (vers uitgelezen).
local function BagStackWithRoom(id)
	for _, e in ipairs(ns.Scan()) do
		if e.itemID == id and not e.key and (e.maxStack or 1) > 1 and (e.count or 1) < (e.maxStack or 1)
			and not (e.info and e.info.isLocked) then return e end
	end
end

-- Paste niet alles bij de stapel (bijv. 3 op een stapel van 4 met max 5)? Dan de rest ook naar je
-- tassen: eerst bij een andere stapel met plek, anders één vrij vakje (zo hooguit één stapel erbij).
-- WoW laat de rest op de cursor of in het bankvakje; allebei afhandelen. Even wachten per stap.
local function PlaceRest(id, src, tries)
	if tries <= 0 then return end
	C_Timer.After(0.3, function()
		if CursorHasItem() then
			if CursorItemID() ~= id then return end
		else
			if not src or not ns.bankOpen then return end
			local info = C_Container.GetContainerItemInfo(src.bag, src.slot)
			if not (info and info.itemID == id) then return end -- alles is mee
			if info.isLocked then PlaceRest(id, src, tries - 1); return end
			C_Container.PickupContainerItem(src.bag, src.slot)
		end
		local e = BagStackWithRoom(id)
		if e then
			Log("rest of " .. id .. " -> stack " .. e.bag .. ":" .. e.slot)
			C_Container.PickupContainerItem(e.bag, e.slot)
			PlaceRest(id, src, tries - 1)
		elseif not StoreCursorItem() then
			ClearCursor() -- geen plek: terug waar het vandaan kwam
		end
	end)
end

-- Item op de cursor bij een stapel van hetzelfde item leggen (zoals WoW zelf doet als je het op
-- een stapel laat vallen). Eerst de stapel van het vakje (`prefer`), anders een andere met plek.
-- Past niet alles, dan gaat de rest daarna ook naar je tassen (PlaceRest). Geen stapel met plek: false.
function ns.MergeCursorInto(id, prefer)
	local function room(e)
		return e and e.itemID == id and (e.maxStack or 1) > 1 and (e.count or 1) < (e.maxStack or 1)
	end
	local target = room(prefer) and prefer or nil
	if not target then
		for _, e in ipairs(lastItems) do
			if room(e) and not e.key then target = e; break end
		end
	end
	if not target then return false end
	local src = BankSource(id)
	Log("merged cursor item " .. id .. " into " .. target.bag .. ":" .. target.slot)
	C_Container.PickupContainerItem(target.bag, target.slot)
	PlaceRest(id, src, 4)
	return true
end

-- Ergens op het venster (achtergrond, vulbalk) laten vallen.
local function DropAnywhere()
	local id = CursorItemID()
	if id and Loose(id) then StoreCursorItem() end
	CheckSplit()
end

-- Per tas een onzichtbaar ouder-frame met SetID(tas). WoW's knop leest de tas dan zelf via
-- GetParent():GetID(). Nooit b:SetBagID(): dat zet een Lua-veld vanuit onze code, en dan
-- blokkeert WoW het gebruiken van sommige items (bijv. een questitem op een voorwerp in de wereld:
-- ADDON_ACTION_FORBIDDEN UseContainerItem, Johan 2026-11-22). Zo doen andere tassen-addons het ook.
local bagParents = {}
local function BagParent(bag)
	local p = bagParents[bag]
	if not p then
		p = CreateFrame("Frame", nil, ns.main.content)
		p:SetAllPoints(ns.main.content)
		p:SetID(bag)
		bagParents[bag] = p
	end
	return p
end

local function SetupItemButton(b, g)
	local e = g.rep
	local info = e.info
	b.group = g
	local parent = BagParent(e.bag)
	if b:GetParent() ~= parent then b:SetParent(parent) end
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
	if ns.searchText ~= "" then isNew = false end -- tijdens zoeken geen knipperen
	if b.newGlow then
		b.newGlow:SetShown(isNew)
		if isNew then
			-- niet opnieuw starten bij elke verversing, anders hapert het knipperen
			if b.newPulse and not (b.newPulse.IsPlaying and b.newPulse:IsPlaying()) then b.newPulse:Play() end
		elseif b.newPulse then b.newPulse:Stop() end
	end
	-- quest-items: "!" + blauwe gloed (start een quest), "?" (niet in je questlog). QuestItems.lua.
	if ns.QuestMark then pcall(ns.QuestMark, b, g) end
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
			rules = T("Grey items. Sold at a vendor.") }
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

local FOOTER_H = ns.TILE + 6

local function StripColors(t)
	return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Stap 1: items groeperen per sectie (en per item als stapels samengevoegd worden).
-- Geeft { [sectie] = { groups = {...}, byKey = {...} } } en het aantal verborgen items.
local function GroupItems(items)
	local bySection, hiddenCount = {}, 0
	for _, e in ipairs(items) do
		local sec = SectionOf(e)
		if sec == "hidden" then hiddenCount = hiddenCount + 1 end
		local s = bySection[sec]
		if not s then s = { groups = {}, byKey = {} }; bySection[sec] = s end
		-- zelf gesplitst: elke stapel een eigen vakje, zodat je er één kunt handelen, banken of veilen
		local apart = ns.splitKeep[e.itemID]
		local key = (ns.DB.merge and e.maxStack > 1 and not apart) and ("i" .. e.itemID) or ("s" .. e.bag .. ":" .. e.slot)
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
		-- Het vakje wijst naar de grootste stapel: dan werkt Shift-klik (splitsen) altijd zoals in
		-- WoW zelf, ook als WoW de Shift bij de eerste klik vanuit een ander venster niet doorgeeft.
		if not g.rep or e.count > g.rep.count then g.rep = e end
	end
	return bySection, hiddenCount
end

-- Stap 2: bijhouden wat nieuw is.
-- Nieuwste als laatst: onthoud wanneer een item voor het eerst in je tassen kwam.
-- Knipperen: erbij geloot terwijl het venster open is = meer dan de laagste stand sinds openen
-- (een drankje drinken en er daarna één looten telt ook als nieuw).
local function TrackNew(items)
	local ch, now, present, counts = CharData(), (time and time()) or 0, {}, {}
	for _, e in ipairs(items) do
		present[e.itemID] = true
		if not ch.seen[e.itemID] then ch.seen[e.itemID] = now end
		counts[e.itemID] = (counts[e.itemID] or 0) + (e.count or 1)
	end
	for id in pairs(ch.seen) do if not present[id] then ch.seen[id] = nil end end
	if not openCounts then
		openCounts = counts
		return
	end
	for id, n in pairs(counts) do
		local was = openCounts[id] or 0
		if n > was then freshIDs[id] = true end
		if n < was then openCounts[id] = n end
	end
	for id in pairs(openCounts) do if not counts[id] then openCounts[id] = 0 end end
end

-- Stap 3a: de groepen van één sectie sorteren zoals gekozen (waarde, nieuwste, handmatig).
local function SortGroups(sec, groups)
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
end

-- Stap 3b: zolang het venster open is blijft de volgorde staan (niets verspringt).
-- Wat op is valt weg en de rest schuift op (issue #6); wat nieuw is komt achteraan.
local function FrozenCells(sec, s, groups)
	local cells = {}
	local order = frozen[sec.key]
	if not order then
		order = {}
		for _, g in ipairs(groups) do cells[#cells + 1] = g; order[#order + 1] = { key = g.key, id = g.itemID } end
		frozen[sec.key] = order
		return cells
	end
	local byKey = s and s.byKey or {}
	local known, used, kept = {}, {}, {}
	for _, o in ipairs(order) do known[o.key] = true end
	for _, o in ipairs(order) do
		local g = byKey[o.key]
		if not g then
			-- sleutel veranderd (stapel gesplitst of weer samen): zelfde item op dezelfde plek
			for _, n in ipairs(groups) do
				if n.itemID == o.id and not used[n.key] and not known[n.key] then g = n; break end
			end
		end
		if g and not used[g.key] then
			cells[#cells + 1] = g; used[g.key] = true
			kept[#kept + 1] = { key = g.key, id = g.itemID } -- vak kan een ander item hebben gekregen
		elseif not g then
			kept[#kept + 1] = o -- even weg: houdt zijn plek
		end
	end
	-- Nieuw: naast een ander vakje van hetzelfde item (de tweede stapel), anders achteraan.
	local function after(list, id)
		for i = #list, 1, -1 do
			if (list[i].id or list[i].itemID) == id then return i + 1 end
		end
		return #list + 1
	end
	for _, g in ipairs(groups) do
		if not used[g.key] then
			table.insert(cells, after(cells, g.itemID), g)
			table.insert(kept, after(kept, g.itemID), { key = g.key, id = g.itemID })
		end
	end
	frozen[sec.key] = kept
	return cells
end

-- Stap 3: welke secties komen in beeld, met welke vakjes. Lege vaste groepen krijgen een
-- gewone regel (met het lege +vakje als die er een heeft); ingeklapt = alleen de kop.
local function BuildSections(bySection)
	local full = {}
	CS().collapsed = CS().collapsed or {}
	for _, sec in ipairs(ns.SectionList()) do
		local s = bySection[sec.key]
		local groups = s and s.groups or {}
		SortGroups(sec, groups)
		local cells = FrozenCells(sec, s, groups)
		if CS().collapsed[sec.key] then
			full[#full + 1] = { sec = sec, cells = {}, title = sec.title, collapsed = true, n = #groups }
		elseif #cells > 0 or sec.plus or (sec.fixed and sec.key ~= "hidden" and (sec.key ~= "keys" or KeyringBag())) then
			full[#full + 1] = { sec = sec, cells = cells, title = sec.title }
		end
	end
	return full
end

-- Kop van een sectie: naam, in-/uitklappen, sorteerknop, post en (Quest) de restjes.
local function SetupHeader(h, f)
	h.key, h.sec = f.sec.key, f.sec
	local t = f.sec.fixed and (ns.BLUE .. f.title .. "|r") or f.title
	if f.collapsed and f.n > 0 then t = t .. "  |cff888888(" .. f.n .. ")|r" end
	h:SetText(t)
	SetRedKit(h.toggle, f.collapsed and "128-redbutton-plus" or "128-redbutton-minus",
		f.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
	h.sort:SetShown(ns.DB.showSort and not f.collapsed and f.sec.key ~= "hidden" and f.sec.key ~= "keys" or false)
	h.sort.mode = SortMode(f.sec)
	h.mail:SetShown(f.sec.mailTo ~= nil)
	-- Quest: hoeveel restjes (oranje) of, als die er niet zijn, hoeveel je houdt/uitstelt (grijs)
	local qText
	if f.sec.key == "quest" and ns.QuestLeftovers then
		local all, nLeft = ns.QuestLeftovers(true)
		if nLeft > 0 then qText = "|cffff9933" .. T("Leftovers: %d"):format(nLeft) .. "|r"
		elseif #all > 0 then qText = "|cff888888" .. T("Kept: %d"):format(#all) .. "|r" end
	end
	h.quest:SetShown(qText ~= nil)
	if qText then
		h.quest.fs:SetText(qText)
		h.quest:SetWidth((h.quest.fs:GetStringWidth() or 80) + 4)
	end
	h.rules, h.ruleTitle = f.sec.rules, StripColors(f.sec.title)
end

-- Stap 4: koppen, vakjes en +vakjes neerzetten. Geeft de hoogte van de inhoud terug.
local function PlaceSections(full, cols, width)
	usedItems, usedHeaders, usedPlus = 0, 0, 0
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
		SetupHeader(h, f)
		y = y - 18
		local col = 0
		local ids = {}
		lastOrder[f.sec.key] = ids
		for _, cell in ipairs(f.collapsed and {} or f.cells) do
			local b = GetItemButton()
			SetupItemButton(b, cell)
			b.secKey = f.sec.key
			ids[#ids + 1] = cell.itemID
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
	return -y
end

-- Stap 5: scrollgebied. Geeft de zichtbare hoogte terug.
local function FitScroll(width, contentH, top, maxView)
	local viewH = math.min(contentH, maxView)
	ns.main.content:SetSize(width, contentH)
	ns.main.scroll:ClearAllPoints()
	ns.main.scroll:SetPoint("TOPLEFT", ns.main, "TOPLEFT", ns.PAD, -top)
	ns.main.scroll:SetSize(width, viewH)
	ns.main.scrollMax = math.max(0, contentH - viewH)
	local cur = ns.main.scroll.GetVerticalScroll and ns.main.scroll:GetVerticalScroll() or 0
	if cur > ns.main.scrollMax then ns.main.scroll:SetVerticalScroll(ns.main.scrollMax) end
	ns.main.scrollHint:SetShown(ns.main.scrollMax > 0)
	return viewH
end

-- In- of uitgeklapt: het venster verschuift zo dat de kop (en het minnetje) onder je muis blijft.
local function KeepHeaderInPlace()
	local keep = keepHeader
	if not keep then return end
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

-- Kleur van een vulbalk: vloeiend van groen naar oranje naar rood (ook voor de rugzakknop, BlizzBagBar.lua).
function ns.FillColor(frac)
	if frac < 0.6 then return 0.30, 0.80, 0.40 end
	if frac < 0.85 then local t = (frac - 0.6) / 0.25; return 0.30 + 0.70 * t, 0.80 - 0.10 * t, 0.40 - 0.30 * t end
	local t = math.min(1, (frac - 0.85) / 0.15)
	return 1.00 - 0.10 * t, 0.70 - 0.50 * t, 0.10 + 0.05 * t
end

local function FillBar(b, usedN, totalN)
	local frac = totalN > 0 and usedN / totalN or 0
	b:SetValue(frac)
	b:SetStatusBarColor(ns.FillColor(frac))
	b.text:SetText(usedN .. "/" .. totalN)
end

-- Stap 6: voetregel (vrije vakjes + goud) en de verbergknop.
-- De reagent-tas (retail/Forever) apart tellen: daar passen alleen crafting reagents in,
-- dus vrije vakjes daar betekenen niet dat gewone loot nog past.
local function UpdateFooter(free, total, hiddenCount)
	local rTotal, rFree = 0, 0
	local rBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
	if rBag and rBag <= (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) then
		rTotal = C_Container.GetContainerNumSlots(rBag) or 0
		for _, f in ipairs(free) do if f.reagent then rFree = rFree + 1 end end
	end
	total = total - rTotal
	local nFree = #free - rFree
	FillBar(ns.main.freeBar, math.max(0, total - nFree), total)
	ns.main.freeBar.free, ns.main.freeBar.total = nFree, total
	ns.main.freeBar.rFree, ns.main.freeBar.rTotal = rFree, rTotal
	-- Reagent-tas: kleine balk, breedte in verhouding tot de grote (tussen 20 en 60 pixels).
	local rb = ns.main.reagentBar
	if rb then
		if rTotal > 0 then
			local w = 150 * rTotal / math.max(1, total)
			rb:SetWidth(math.max(20, math.min(60, math.floor(w + 0.5))))
			FillBar(rb, rTotal - rFree, rTotal)
			rb:Show()
		else
			rb:Hide()
		end
	end
	ns.main.money:SetText(ns.FooterMoney(GetMoney()))
	ns.main.hiddenBtn.count:SetText(hiddenCount > 0 and hiddenCount or "")
	SetRedKit(ns.main.hiddenBtn, showHidden and "128-redbutton-visibilityon" or "128-redbutton-visibilityoff", "Interface\\Icons\\Spell_Shadow_EvilEye")
	ns.main.hint:SetShown(showHidden)
end

-- Het tassenvenster opbouwen. Tassenknoppen zijn geen beschermde frames: mag ook in een gevecht.
local function Layout()
	if not ns.main or not ns.main:IsShown() then return end
	if not ns.DB.enabled then ns.main:Hide(); return end
	if inLayout then return end
	inLayout = true

	local items, free, total = Scan()
	lastFree, lastItems = free, items
	local bySection, hiddenCount = GroupItems(items)
	TrackNew(items)
	local full = BuildSections(bySection)

	-- Breedte = het aantal kolommen uit de opties, maar nooit breder dan je scherm.
	-- Hoogte: tot 80% van je scherm, daarna scrollen.
	local top = showHidden and 78 or 62
	local screenH = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or 768
	if screenH <= 0 then screenH = 768 end
	local maxView = math.floor(screenH * 0.8) - top - FOOTER_H - ns.PAD
	local fit = math.floor(((UIParent:GetWidth() or 1200) - 80) / (ns.TILE + ns.GAP))
	local cols = math.max(5, math.min(ns.DB.maxCols, fit))
	local width = cols * (ns.TILE + ns.GAP) - ns.GAP

	local contentH = PlaceSections(full, cols, width)
	local viewH = FitScroll(width, contentH, top, maxView)
	KeepHeaderInPlace()
	UpdateFooter(free, total, hiddenCount)
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
		if not ok then ns.SetError("window: " .. tostring(err)); Print(T("error: %s"):format(tostring(err))) end
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
		ns.ResetOrder() -- volgende keer openen: netjes opnieuw gesorteerd
		-- Tas dicht: zelf gesplitste stapels mogen weer samen.
		if next(ns.splitKeep) then
			Log("split: bags closed, stacks may merge again")
			ns.splitKeep = {}
			if ns.ScheduleRestack then ns.ScheduleRestack() end
		end
		-- Tas dicht: nieuwe items zijn gezien, markering weghalen.
		ClearNew()
		-- Tas dicht: zoeken stopt (volgende keer openen = alles weer zichtbaar).
		if ns.main.search then ns.main.search:SetText(""); ns.main.search:ClearFocus() end
		if ns.searchText ~= "" then
			ns.searchText = ""
			if ns.OnSearch then pcall(ns.OnSearch) end
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
		if #t < 2 then t = "" end -- pas zoeken vanaf 2 tekens
		if t ~= ns.searchText then
			-- Begin met zoeken: nieuwe items zijn gezien, knipperen stopt.
			if ns.searchText == "" then ClearNew() end
			ns.searchText = t; ns.Refresh()
			if ns.OnSearch then ns.OnSearch() elseif ns.ViewRefresh then ns.ViewRefresh() end
		end
	end)
	sb:SetScript("OnEscapePressed", function(self)
		-- Escape: zoektekst weg; was hij al leeg, dan meteen de tassen dicht.
		local empty = (self:GetText() or "") == ""
		self:SetText(""); self:ClearFocus()
		if empty then ns.main:Hide() end
	end)
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
	local function NewBar(name, w, h)
		local b = CreateFrame("StatusBar", name, ns.main)
		b:SetSize(w, h)
		b:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		b:SetMinMaxValues(0, 1)
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints(b)
		b.bg:SetColorTexture(0, 0, 0, 0.6)
		b.border = b:CreateTexture(nil, "OVERLAY")
		b.border:SetTexture("Interface\\Tooltips\\UI-StatusBar-Border")
		b.border:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 2)
		b.border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
		b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.text:SetPoint("LEFT", b, "RIGHT", 6, 0)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return b
	end
	local bar = NewBar("CarefreeBagFreeBar", 150, 10)
	bar:SetPoint("LEFT", ns.main, "BOTTOMLEFT", ns.PAD + 4, ns.PAD - 2 + ns.TILE / 2)
	bar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(T("Free slots: %s of %s"):format(tostring(self.free or "?"), tostring(self.total or "?")))
		if (self.rTotal or 0) > 0 then
			GameTooltip:AddLine(T("Reagent bag: %d of %d free (only crafting reagents fit there)"):format(self.rFree, self.rTotal), 0.8, 0.8, 0.8, true)
		end
		GameTooltip:Show()
	end)
	ns.main.freeBar = bar
	-- Kleinere balk voor de reagent-tas (retail/Forever), rechts naast de grote; breedte in verhouding.
	local rbar = NewBar("CarefreeBagReagentBar", 40, 6)
	rbar:SetPoint("LEFT", bar.text, "RIGHT", 12, 0)
	rbar.text:SetFontObject("GameFontDisableSmall")
	rbar:EnableMouse(true) -- voor de tooltip
	rbar:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(T("Reagents"))
		GameTooltip:AddLine(T("Reagent bag: %d of %d free (only crafting reagents fit there)"):format(bar.rFree or 0, bar.rTotal or 0), 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	rbar:Hide()
	ns.main.reagentBar = rbar
	-- Item van buiten je tassen op het venster of de vulbalk laten vallen = in een vrij vakje.
	for _, fr in ipairs({ ns.main, bar }) do
		fr:EnableMouse(true)
		fr:SetScript("OnReceiveDrag", DropAnywhere)
		fr:HookScript("OnMouseUp", function(_, btn) if btn == "LeftButton" then DropAnywhere() end end)
	end
	ns.main.money = ns.main:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	ns.main.money:SetJustifyH("RIGHT")
	ns.main.money:SetPoint("RIGHT", ns.main, "BOTTOMRIGHT", -ns.PAD - 4, ns.PAD - 2 + ns.TILE / 2)
end

---------------------------------------------------------------------------
-- Events: venster opnieuw opbouwen (Refresh wacht zelf even en doet niets als het venster dicht is)
---------------------------------------------------------------------------

for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY", "GET_ITEM_INFO_RECEIVED",
	"MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_SUCCESS" }) do
	ns.OnEvent(ev, "window", function() ns.Refresh() end)
end
-- in een gevecht uitgesteld: nu alsnog
ns.OnEvent("PLAYER_REGEN_ENABLED", "window", function()
	if ns.layoutPending then ns.layoutPending = false; ns.Refresh() end
end)
