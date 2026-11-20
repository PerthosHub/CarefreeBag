-- CarefreeBag: Loot.lua
-- Tassen vol en er ligt loot die niet past? Dan tonen we per loot-item één rij:
-- loot ➜ het goedkoopste item in je tassen dat ervoor weg moet, met het verschil in
-- groen (slim) of rood (niet slim) en een knop "Pick up". Alle rijen tegelijk, zodat je
-- met één blik ziet wat slim is. Weggooien (DeleteCursorItem) mag WoW alleen na een klik
-- van de speler doen, daarom gebeurt het niet helemaal automatisch.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local AHPrice, Log, MakeButton, NewWindow, Print, Scan = ns.AHPrice, ns.Log, ns.MakeButton, ns.NewWindow, ns.Print, ns.Scan
local CatByKey, Kept, KeptGroups, SectionOf, T = ns.CatByKey, ns.Kept, ns.KeptGroups, ns.SectionOf, ns.T

local LOOT_ITEM = (Enum and Enum.LootSlotType and Enum.LootSlotType.Item) or LOOT_SLOT_ITEM or 1
local AH_CUT = 0.05
local QUEST_VALUE = 2 ^ 50                                -- questloot is altijd "meer waard"
local NEVER = { quest = true, keys = true, hidden = true } -- deze groepen stellen we nooit voor
local W = 330
local ROW_H, ICON = 36, 30
local MAX_ROWS = 6
local MENU_W = 250

-- Naam van een groep zoals in de tas.
local function GroupName(key)
	if key == "grey" then return "Auto Sell" end
	if key == "boe" then return "BoE" end
	if key == "other" then return T("Other") end
	local c = CatByKey(key)
	return c and c.name or tostring(key)
end

-- skipItems/skipGroups: "eenmalig overslaan", geldt tot het lootvenster dichtgaat.
local state = { pending = nil, dismissed = false, scheduled = false, skipItems = {}, skipGroups = {} }
local panel

local function Money(m)
	m = math.floor(m or 0)
	return GetMoneyString and GetMoneyString(m, true) or tostring(m)
end

local function Short(link) return link and (link:match("%[(.-)%]") or "?") or "?" end

-- Alles van GetItemInfo in één tabel (r[12] = vendorprijs, r[18] = crafting reagent).
local function Info(x)
	local r = { pcall(C_Item.GetItemInfo, x) }
	if r[1] and r[2] then return r end
	return nil
end

-- Wat is één stuk waard? De vendorprijs, of het AH (na 5% kosten) als dat meer geeft.
-- Zonder Auctionator (of zonder AH-prijs) is het gewoon de vendorprijs.
local function Each(link, vendor)
	local v, ah = vendor or 0, AHPrice(link)
	if ah and math.floor(ah * (1 - AH_CUT)) > v then return math.floor(ah * (1 - AH_CUT)), true end
	return v, false
end

-- Goedkoopste stapel in je tassen. Alleen items met een prijs: items zonder waarde
-- (hearthstone, questspullen, sleutels) zijn vaak juist belangrijk. Items en groepen
-- die je wilt houden ("Keep") of nu overslaat, slaan we over.
local CanHold -- vooruit (hieronder)
-- Alleen items uit een tas waar de loot daarna ook in past: een vak in een
-- beroepstas (bijv. mijnbouw) vrijmaken helpt niets voor een gewoon item.
-- used: vakjes die al bij een andere rij horen (elke rij een eigen item).
local function Cheapest(items, lootItem, lootIDs, used)
	local best
	lootIDs, used = lootIDs or {}, used or {}
	local keep, keepGroups = Kept(), KeptGroups()
	for _, e in ipairs(items) do
		local sec = SectionOf(e)
		if not e.key and not e.info.isLocked and not e.info.hasNoValue and not NEVER[sec]
			and not used[e.bag .. ":" .. e.slot]
			and CanHold(e.bag, lootItem.id, lootItem.reagent)
			and not keep[e.itemID] and not (keepGroups[sec] and sec ~= "grey" and sec ~= "other")
			and not state.skipItems[e.itemID] and not state.skipGroups[sec]
			-- ligt hetzelfde item ook in de loot? Dan die stapel houden: daar past die loot op
			and not lootIDs[e.itemID] then
			local each, ah = Each(e.link, e.price)
			if each > 0 then
				local v = each * e.count
				if not best or v < best.value then best = { e = e, value = v, ah = ah, sec = sec } end
			end
		end
	end
	return best
end

-- Tooltipregel voor items die je bij volle tassen altijd houdt (zie Data.lua).
function ns.KeptLine(tt, id)
	if id and Kept()[id] then
		tt:AddLine("|cff66ccffCarefreeBag:|r " .. T("kept when your bags are full"), 1, 1, 1)
	end
end

-- Past dit loot-item nog? Vrij vakje, of bij een eigen stapel die nog niet vol is.
local function BagFamily(bag)
	if bag == 0 or not C_Container.GetContainerNumFreeSlots then return 0 end
	local ok, _, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
	return ok and family or 0
end

local REAGENT_BAG = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag

-- Mag dit item in deze tas? Gewone tas: alles. Reagent-tas: alleen reagents.
-- Beroepstas: alleen items van dat beroep.
CanHold = function(bag, itemID, reagent)
	if REAGENT_BAG and bag == REAGENT_BAG then return reagent and true or false end
	local family = BagFamily(bag)
	if family == 0 then return true end
	local ok, fam = pcall(C_Item.GetItemFamily, itemID)
	fam = (ok and fam) or 0
	return bit and bit.band and bit.band(fam, family) > 0 or false
end

local function Fits(items, free, itemID, qty, reagent)
	for _, f in ipairs(free) do
		if CanHold(f.bag, itemID, reagent) then return true end
	end
	for _, e in ipairs(items) do
		if e.itemID == itemID and not e.key and e.maxStack > 1 and e.count + qty <= e.maxStack then return true end
	end
	return false
end

-- Alle loot-items die niet in je tassen passen, het meest waardevolle eerst (quest bovenaan).
local function LootList(items, free)
	local n = GetNumLootItems and GetNumLootItems() or 0
	local list = {}
	for i = 1, n do
		local link = GetLootSlotLink and GetLootSlotLink(i)
		if link and (not GetLootSlotType or GetLootSlotType(i) == LOOT_ITEM) then
			local icon, _, qty, _, _, locked, isQuest = GetLootSlotInfo(i)
			local id = tonumber(link:match("item:(%d+)"))
			local r = id and Info(id)
			qty = (qty and qty > 0) and qty or 1
			if id and not locked and not Fits(items, free, id, qty, r and r[18]) then
				local each, ah = Each(link, r and r[12])
				list[#list + 1] = { slot = i, link = link, icon = icon, count = qty, value = isQuest and QUEST_VALUE or each * qty,
					price = each * qty, ah = ah, quest = isQuest, id = id, reagent = r and r[18] }
			end
		end
	end
	table.sort(list, function(a, b)
		if a.value ~= b.value then return a.value > b.value end
		return a.slot < b.slot
	end)
	return list
end

-- Waar de prijzen vandaan komen (voor de hover): geen Auctionator, nog geen AH-prijs,
-- of een AH-prijs met wanneer Auctionator die zag.
local function Age(days)
	if not days then return T("unknown") end
	if days <= 0 then return T("today") end
	if days == 1 then return T("yesterday") end
	return T("%d days ago"):format(days)
end

function ns.PriceLines(...)
	local lines = { "|cff66ccffCarefreeBag:|r" }
	for _, link in ipairs({ ... }) do
		local kind, age = ns.AHInfo(link)
		if kind == "none" then
			lines[#lines + 1] = T("Auctionator is not installed: vendor prices are used.")
			break
		elseif kind == "noprice" then
			lines[#lines + 1] = T("%s: no AH price in Auctionator yet, vendor price is used."):format(link)
		else
			lines[#lines + 1] = T("%s: AH price, last seen %s."):format(link, Age(age))
		end
	end
	return lines
end

-- Slim om op te pakken? Questloot altijd, anders als de loot meer waard is.
local function Smart(o) return o.loot.quest or o.loot.value > o.junk.value end

-- De zin voor de hover: hoeveel meer of minder de loot waard is.
local function Verdict(o)
	if o.loot.quest then return T("The loot is a quest item.") end
	if Smart(o) then return T("The loot is worth %s more."):format(Money(o.loot.value - o.junk.value)) end
	return T("The loot is worth %s less."):format(Money(o.junk.value - o.loot.value))
end

---------------------------------------------------------------------------
-- Het paneel naast het lootvenster
---------------------------------------------------------------------------

-- Rode Blizzard-knop groen kleuren (advies) of weer gewoon rood maken.
local function Tint(btn, green)
	for _, rg in ipairs({ btn:GetRegions() }) do
		if rg and rg.GetObjectType and rg:GetObjectType() == "Texture" and rg ~= btn:GetHighlightTexture() then
			if rg.SetDesaturated then rg:SetDesaturated(green and true or false) end
			if green then rg:SetVertexColor(0.35, 0.95, 0.35) else rg:SetVertexColor(1, 1, 1) end
		end
	end
	btn.green = green and true or false
end

local function SetButtons(on)
	if not panel then return end
	for _, r in ipairs(panel.rows) do r.btn:SetEnabled(on) end
	panel.leaveAll:SetEnabled(on)
end

-- Dicht vanuit de code (na de laatste ruil, loot dicht, niets meer te doen): niet als "laten liggen" tellen.
local function HidePanel()
	if panel and panel:IsShown() then panel.quiet = true; panel:Hide(); panel.quiet = nil end
	if panel then
		panel.offer, panel.busy = nil, false
		for _, r in ipairs(panel.rows) do r.offer = nil end
		SetButtons(true)
	end
end

local Evaluate -- vooruit

-- Tijdens het oppakken blijft het paneel staan (knoppen even uit); daarna komen de
-- overgebleven rijen er meteen weer in.
local function SetBusy(row)
	panel.busy = true
	SetButtons(false)
	panel.menu:Hide()
	row.diff:SetText("|cffaaaaaa" .. T("Picking up...") .. "|r")
	row.ah:SetText("")
end

-- Na het weggooien wachten tot het vakje echt vrij is, dan de loot oppakken.
local function TryPending()
	local p = state.pending
	if not p then return end
	if not GetLootSlotLink or GetLootSlotLink(p.slot) ~= p.link then
		Log("loot: slot " .. p.slot .. " changed before looting")
		state.pending = nil
		C_Timer.After(0.1, Evaluate) -- de rest, of het paneel dicht
		return
	end
	local _, free = Scan()
	local room = false
	for _, f in ipairs(free) do if CanHold(f.bag, p.id, p.reagent) then room = true end end
	if not room and p.tries < 10 then
		p.tries = p.tries + 1
		C_Timer.After(0.2, TryPending)
		return
	end
	state.pending = nil
	Log(("loot: LootSlot(%d) %s, room=%s, tries=%d"):format(p.slot, Short(p.link), tostring(room), p.tries))
	LootSlot(p.slot)
	C_Timer.After(0.3, Evaluate) -- de overige rijen
end

-- Klik op "Pick up" in een rij (een echte klik: anders weigert WoW het weggooien).
local function Swap(row)
	local o = row and row.offer
	if not o or panel.busy then return end
	local e = o.junk.e
	local info = C_Container.GetContainerItemInfo(e.bag, e.slot)
	if not info or info.itemID ~= e.itemID or info.isLocked then Evaluate(); return end
	if CursorHasItem() then ClearCursor() end
	C_Container.PickupContainerItem(e.bag, e.slot)
	local kind, id = GetCursorInfo()
	if kind ~= "item" or id ~= e.itemID then ClearCursor(); Evaluate(); return end
	DeleteCursorItem()
	local what = (e.link or e.name) .. (e.count > 1 and (" x" .. e.count) or "")
	Print(T("Destroyed %s to make room for %s."):format(what, o.loot.link))
	ns.Note("bags full", ("destroyed %s (%d copper) for %s"):format(tostring(e.itemID), o.junk.value, Short(o.loot.link)))
	state.pending = { slot = o.loot.slot, link = o.loot.link, id = o.loot.id, reagent = o.loot.reagent, tries = 0 }
	SetBusy(row)
	C_Timer.After(0.2, TryPending)
end

-- Opties bij het item dat weg zou gaan (knopje ▼ in de rij): nooit / nu niet, voor het item of de hele groep.
local function MenuChoice(what, row)
	row = row or (panel and (panel.menuRow or panel.rows[1]))
	local o = row and row.offer
	if not o or panel.busy then return end
	local e, sec = o.junk.e, o.junk.sec
	if what == "keepItem" then
		Kept()[e.itemID] = true
		Print(T("%s is never destroyed when your bags are full."):format(e.link or e.name))
		Log("loot: keep item " .. tostring(e.itemID))
	elseif what == "skipItem" then
		state.skipItems[e.itemID] = true
		Log("loot: skip item this time " .. tostring(e.itemID))
	elseif what == "keepGroup" then
		KeptGroups()[sec] = true
		Print(T("Nothing from the group %s is destroyed when your bags are full. Change it in the options (Always keep)."):format(GroupName(sec)))
		Log("loot: keep group " .. tostring(sec))
		if ns.RefreshConfig then ns.RefreshConfig() end
	elseif what == "skipGroup" then
		state.skipGroups[sec] = true
		Log("loot: skip group this time " .. tostring(sec))
	end
	panel.menu:Hide()
	Evaluate()
end

local function BuildMenu()
	local okB, m = pcall(CreateFrame, "Frame", "CarefreeBagLootMenu", panel, "BackdropTemplate")
	if not okB then m = CreateFrame("Frame", "CarefreeBagLootMenu", panel) end
	m:SetWidth(MENU_W)
	m:SetFrameStrata("DIALOG")
	-- Zelfde uiterlijk als een Blizzard-keuzemenu (rechtsklik op een speler): donkere
	-- dialoogrand, goudkleurige kopjes, witte keuzes met een lichte balk bij hover.
	if m.SetBackdrop then
		m:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 } })
	end
	m:EnableMouse(true)
	local function Head()
		local h = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		h:SetJustifyH("LEFT")
		h:SetWidth(MENU_W - 32)
		h:SetWordWrap(false)
		return h
	end
	local function Choice(key, text)
		local b = CreateFrame("Button", nil, m)
		b:SetSize(MENU_W - 28, 16)
		b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.label:SetPoint("LEFT", b, "LEFT", 12, 0)
		b.label:SetText(text)
		b.text = text
		b:SetScript("OnClick", function() MenuChoice(key) end)
		m[key] = b
		return b
	end
	m.itemHead = Head()
	Choice("keepItem", T("Never destroy this item"))
	Choice("skipItem", T("Skip this item this time"))
	m.divider = m:CreateTexture(nil, "ARTWORK")
	m.divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
	m.divider:SetSize(MENU_W - 32, 8)
	m.groupHead = Head()
	Choice("keepGroup", T("Never destroy anything from this group"))
	Choice("skipGroup", T("Skip this group this time"))
	-- Weg zodra de muis niet meer op het item of het menu staat (even wachten om over te steken).
	m.away = 0
	m:SetScript("OnUpdate", function(self, dt)
		local r = panel.menuRow
		if self:IsMouseOver() or (r and r.opt:IsMouseOver()) then self.away = 0; return end
		self.away = self.away + (dt or 0)
		if self.away > 0.3 then self:Hide() end
	end)
	m:Hide()
	return m
end

local function ShowMenu(row)
	local o = row and row.offer
	if not o or panel.busy then return end
	panel.menuRow = row
	-- Auto Sell en Other zijn er juist voor spullen die weg mogen: geen "hele groep nooit".
	local groupOk = o.junk.sec ~= "grey" and o.junk.sec ~= "other"
	-- Eerst WoW's eigen keuzemenu (zoals rechtsklik op een speler); bestaat dat niet, dan ons eigen menu.
	if MenuUtil and MenuUtil.CreateContextMenu then
		local ok = pcall(MenuUtil.CreateContextMenu, row.opt, function(_, root)
			root:CreateTitle(o.junk.e.name or "?")
			root:CreateButton(T("Never destroy this item"), function() MenuChoice("keepItem", row) end)
			root:CreateButton(T("Skip this item this time"), function() MenuChoice("skipItem", row) end)
			root:CreateDivider()
			root:CreateTitle(T("Group: %s"):format(GroupName(o.junk.sec)))
			if groupOk then root:CreateButton(T("Never destroy anything from this group"), function() MenuChoice("keepGroup", row) end) end
			root:CreateButton(T("Skip this group this time"), function() MenuChoice("skipGroup", row) end)
		end)
		if ok then return end
	end
	local m = panel.menu
	-- Van boven naar beneden: kopje item, 2 keuzes, streep, kopje groep, 1 of 2 keuzes.
	local y = -14
	local function Put(f, h, x)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", m, "TOPLEFT", x or 14, y)
		y = y - h
	end
	m.itemHead:SetText(o.junk.e.name or "?")
	Put(m.itemHead, 16, 16)
	Put(m.keepItem, 16)
	Put(m.skipItem, 16)
	Put(m.divider, 10, 16)
	m.groupHead:SetText(T("Group: %s"):format(GroupName(o.junk.sec)))
	Put(m.groupHead, 16, 16)
	m.keepGroup:SetShown(groupOk)
	if groupOk then Put(m.keepGroup, 16) end
	Put(m.skipGroup, 16)
	m:SetHeight(-y + 12)
	m:ClearAllPoints()
	-- onder het knopje ▼
	m:SetPoint("TOPRIGHT", row.opt, "BOTTOMRIGHT", 0, -2)
	m.away = 0
	m:Show()
end

-- Hover: tooltip van het item onder het paneel (menu ernaast blijft vrij), met de zin en de prijzen.
local function Tip(row, link)
	local o = row.offer
	if not o or not link then return end
	GameTooltip:SetOwner(row, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -2)
	GameTooltip:SetHyperlink(link)
	GameTooltip:AddLine(" ")
	local smart = Smart(o)
	GameTooltip:AddLine(Verdict(o), smart and 0.2 or 1, smart and 1 or 0.35, smart and 0.2 or 0.35, true)
	for _, l in ipairs(ns.PriceLines(o.junk.e.link, o.loot.link)) do GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true) end
	GameTooltip:Show()
end

-- Eén rij: [loot] ➜ [weg ►]  +31c AH  [Pick up]
local function NewRow(i)
	local inner = W - 2 * ns.PAD
	local r = CreateFrame("Button", nil, panel)
	r:SetSize(inner, ROW_H)
	r:SetPoint("TOPLEFT", panel, "TOPLEFT", ns.PAD, -30 - (i - 1) * ROW_H)
	local function Icon(x)
		local b = CreateFrame("Button", nil, r)
		b:SetSize(ICON, ICON)
		b:SetPoint("LEFT", r, "LEFT", x, 0)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints(b)
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return b
	end
	r.loot = Icon(2)
	r.loot:SetScript("OnEnter", function() Tip(r, r.offer and r.offer.loot.link) end)
	r.arrow = r:CreateTexture(nil, "OVERLAY")
	r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	r.arrow:SetSize(14, 14)
	r.arrow:SetPoint("LEFT", r.loot, "RIGHT", 4, 0)
	r.junk = Icon(2 + ICON + 22)
	r.junk:SetScript("OnEnter", function() Tip(r, r.offer and r.offer.junk.e.link) end)
	-- Achtergrond over de hele rij: groen = slim, rood = niet slim (van de rand van het lootvenster tot de knop).
	r.bg = r:CreateTexture(nil, "BACKGROUND")
	r.bg:SetPoint("TOPLEFT", r, "TOPLEFT", -6, 1)
	r.bg:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 6, -1)
	-- Vinkje of kruisje (zoals bij een ready check), dan het verschil.
	r.mark = r:CreateTexture(nil, "OVERLAY")
	r.mark:SetSize(18, 18)
	r.mark:SetPoint("LEFT", r.junk, "RIGHT", 6, 0)
	r.diff = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	r.diff:SetPoint("LEFT", r.mark, "RIGHT", 3, 0)
	r.diff:SetJustifyH("LEFT")
	r.ah = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.ah:SetPoint("LEFT", r.diff, "RIGHT", 3, 0)
	-- Knopje ▼ (zoals een WoW-keuzelijst): opties voor het item dat weg zou gaan.
	r.opt = CreateFrame("Button", nil, r)
	r.opt:SetSize(24, 24)
	r.opt:SetPoint("RIGHT", r, "RIGHT", 0, 0)
	r.opt:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	r.opt:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
	r.opt:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	r.opt:SetScript("OnClick", function()
		if panel.menu:IsShown() and panel.menuRow == r then panel.menu:Hide() else ShowMenu(r) end
	end)
	ns.Tooltip(r.opt, T("Options"), T("Never destroy this item or group, or skip it this time."))
	r.btn = MakeButton(r, T("Pick up"), 76)
	r.btn:SetPoint("RIGHT", r.opt, "LEFT", -2, 0)
	r.btn:SetScript("OnClick", function() Swap(r) end)
	ns.Tooltip(r.btn, T("Pick up"), T("Destroys the item on the right of the arrow for good (it cannot be bought back) and picks up the loot."))
	r:SetScript("OnEnter", function() Tip(r, r.offer and r.offer.loot.link) end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r:Hide()
	return r
end

local function BuildPanel()
	panel = NewWindow("CarefreeBagLootPanel", T("Bags full"), W, 120)
	panel:SetFrameStrata("HIGH")
	-- Dichte achtergrond: de standaard dialoogachtergrond is half doorzichtig, en dit
	-- venster ligt vaak boven je tassen (clam openen) en dan wordt het een rommeltje.
	panel.solid = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
	panel.solid:SetColorTexture(0.05, 0.05, 0.05, 0.95)
	panel.solid:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
	panel.solid:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
	panel.menu = BuildMenu()
	panel.rows = {}
	for i = 1, MAX_ROWS do panel.rows[i] = NewRow(i) end
	-- korte namen voor de tests: de eerste rij en de menu-keuzes
	panel.swap = panel.rows[1].btn
	panel.keepItem, panel.keepGroup = panel.menu.keepItem, panel.menu.keepGroup
	panel.skipItem, panel.skipGroup = panel.menu.skipItem, panel.menu.skipGroup
	-- Alles laten liggen: niet meer vragen tot het lootvenster dichtgaat.
	panel.leaveAll = MakeButton(panel, T("Leave all"), 110)
	panel.leaveAll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -ns.PAD, 14)
	panel.leaveAll:SetScript("OnClick", function()
		if panel.busy then return end
		Log("loot: leave all")
		panel:Hide() -- telt als zelf dichtdoen (zie OnHide)
	end)
	ns.Tooltip(panel.leaveAll, T("Leave all"), T("Leave the loot where it is. CarefreeBag asks again the next time you loot."))
	panel.skip = panel.leaveAll
	panel:HookScript("OnHide", function()
		panel.menu:Hide()
		-- Zelf dichtgedaan (kruisje, Escape, Leave all): niet meer vragen tot het lootvenster dichtgaat.
		-- Anders komt hij bij de volgende tas-update of "Inventory is full" meteen terug.
		if not panel.quiet and (panel.offer or panel.busy) then
			state.dismissed = true
			panel.offer = nil
			Log("loot: window closed by the player, no more questions for this loot")
		end
	end)
	ns.lootPanel = panel
end

-- Naast het lootvenster; past het rechts niet meer op het scherm, dan links ervan.
-- Plek van een venster in de maat van UIParent: links, onder, rechts, boven.
local function Rect(f)
	local l, b, w, h = f:GetRect()
	if not (l and b and w and h) then return nil end
	local k = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
	return { l * k, b * k, (l + w) * k, (b + h) * k }
end

local function Overlap(a, b) return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4] end

-- Het knopje in het lootvenster voor loot-vak `slot` (nieuw lootvenster: ScrollBox; oud: LootButton1-4).
local function LootButtonFor(slot)
	if not (LootFrame and LootFrame:IsShown()) then return nil end
	local found
	local sb = LootFrame.ScrollBox
	if sb and sb.ForEachFrame then
		pcall(sb.ForEachFrame, sb, function(f)
			local d = f.GetElementData and f:GetElementData()
			local s = (f.GetSlotIndex and f:GetSlotIndex()) or (type(d) == "table" and d.slotIndex) or f.slot
			if s == slot and f:IsVisible() then found = f end
		end)
	end
	if found then return found end
	for k = 1, (LOOTFRAME_NUMBUTTONS or 4) do
		local b = _G["LootButton" .. k]
		if b and b:IsVisible() and b.slot == slot then return b end
	end
end

-- Rijen onder elkaar (geen lootvenster te zien, bijv. autoloot).
local function Stack(n)
	for i, r in ipairs(panel.rows) do
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", panel, "TOPLEFT", ns.PAD, -30 - (i - 1) * ROW_H)
	end
	panel:SetHeight(30 + n * ROW_H + 8 + 22 + 16)
end

-- Naast het lootvenster, even hoog, en elke rij op dezelfde hoogte als zijn item in het
-- lootvenster: zo loopt de regel door. Rechts, of links als rechts niet op het scherm past
-- of je tassen bedekt. Geen lootvenster (of een item niet te vinden): rijen onder elkaar.
local function Place(n)
	panel:ClearAllPoints()
	local L = LootFrame and LootFrame:IsShown() and Rect(LootFrame)
	if not L then
		Stack(n)
		if LootFrame and LootFrame:IsShown() then panel:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 4, 0)
		else panel:SetPoint("TOP", UIParent, "TOP", 0, -140) end
		return
	end
	local k = (panel:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
	local pw = W * k
	local sw = UIParent:GetWidth() or 1920
	local bags = ns.main and ns.main:IsShown() and Rect(ns.main)
	local right = { L[3] + 4, L[2], L[3] + 4 + pw, L[4] }
	local left = { L[1] - 4 - pw, L[2], L[1] - 4, L[4] }
	local useLeft = (right[3] > sw or (bags and Overlap(right, bags))) and left[1] >= 0
	-- Hoogte van elk loot-item, gemeten vanaf de bovenkant van het lootvenster (in de maat van het paneel).
	local ui = UIParent:GetEffectiveScale() or 1
	local ys, aligned = {}, true
	for i, r in ipairs(panel.rows) do
		if r.offer then
			local b = LootButtonFor(r.offer.loot.slot)
			local _, cy = b and b:GetCenter()
			if not cy then aligned = false; break end
			ys[i] = (cy * (b:GetEffectiveScale() or 1) / ui - L[4]) / k
		end
	end
	local a, b = useLeft and "TOPRIGHT" or "TOPLEFT", useLeft and "TOPLEFT" or "TOPRIGHT"
	local dx = useLeft and -4 or 4
	panel:SetPoint(a, LootFrame, b, dx, 0)
	if not aligned then Stack(n); return end
	-- even hoog als het lootvenster, elke rij naast zijn loot-item
	panel:SetPoint(useLeft and "BOTTOMRIGHT" or "BOTTOMLEFT", LootFrame, useLeft and "BOTTOMLEFT" or "BOTTOMRIGHT", dx, 0)
	for i, r in ipairs(panel.rows) do
		if ys[i] then
			r:ClearAllPoints()
			r:SetPoint("LEFT", panel, "TOPLEFT", ns.PAD, ys[i])
		end
	end
end

-- Eén rij vullen: iconen, verschil in groen/rood (quest = groen "Quest"), knop groen/rood.
local function FillRow(r, o)
	r.offer = o
	r.loot.icon:SetTexture(o.loot.icon)
	r.loot.count:SetText((o.loot.count or 1) > 1 and o.loot.count or "")
	r.junk.icon:SetTexture(o.junk.e.info.iconFileID)
	r.junk.count:SetText(o.junk.e.count > 1 and o.junk.e.count or "")
	local smart = Smart(o)
	if o.loot.quest then
		r.diff:SetText("|cff33ff33" .. T("Quest") .. "|r")
	elseif smart then
		r.diff:SetText("|cff33ff33+" .. Money(o.loot.value - o.junk.value) .. "|r")
	else
		r.diff:SetText("|cffff5555-" .. Money(o.junk.value - o.loot.value) .. "|r")
	end
	r.ah:SetText((o.junk.ah or o.loot.ah) and "|cff66ccffAH|r" or "")
	-- in één oogopslag: groene rij met vinkje = doen, rode rij met kruisje = liever niet
	if smart then r.bg:SetColorTexture(0.1, 0.8, 0.1, 0.28) else r.bg:SetColorTexture(0.85, 0.1, 0.1, 0.22) end
	r.mark:SetTexture(smart and "Interface\\RaidFrame\\ReadyCheck-Ready" or "Interface\\RaidFrame\\ReadyCheck-NotReady")
	r.smart = smart
	r.advice = smart and "pickup" or "leave"
	Tint(r.btn, smart)
	r:Show()
end

local function ShowOffers(offers)
	if not panel then BuildPanel() end
	panel.busy = false
	SetButtons(true)
	for i, r in ipairs(panel.rows) do
		if offers[i] then FillRow(r, offers[i]) else r.offer = nil; r:Hide() end
	end
	local first = panel.rows[1]
	panel.offer, panel.advice = first.offer, first.advice -- korte namen (tests, andere bestanden)
	-- menu open bij een rij die er nog staat: bijwerken, anders weg
	if panel.menu:IsShown() and panel.menuRow and panel.menuRow.offer then ShowMenu(panel.menuRow) else panel.menu:Hide() end
	Place(math.min(#offers, MAX_ROWS))
	panel:Show()
end

Evaluate = function()
	if not ns.DB.enabled or state.dismissed or state.pending then return end
	if not (GetNumLootItems and (GetNumLootItems() or 0) > 0) then HidePanel(); return end
	local items, free = Scan()
	local loots = LootList(items, free)
	local normalFree = 0
	for _, f in ipairs(free) do if not f.reagent then normalFree = normalFree + 1 end end
	if #loots == 0 and normalFree == 0 then
		-- Tassen vol, loot open, maar niets aan te bieden: per loot-vak vastleggen waarom (later terug te lezen).
		for i = 1, (GetNumLootItems() or 0) do
			local link = GetLootSlotLink and GetLootSlotLink(i)
			local _, _, qty, _, _, locked, isQuest = GetLootSlotInfo(i)
			local id = link and tonumber(link:match("item:(%d+)"))
			local r = id and Info(id)
			ns.Note("bags full", ("no offer, loot slot %d: %s id %s x%s, type %s, locked %s, quest %s, fits %s"):format(i,
				link and Short(link) or "no link", tostring(id), tostring(qty),
				tostring(GetLootSlotType and GetLootSlotType(i)), tostring(locked), tostring(isQuest),
				tostring(id and Fits(items, free, id, (qty and qty > 0) and qty or 1, r and r[18]) or false)))
		end
	end
	-- Items die ook in de loot liggen (bijv. een schelp die op je stapel past) niet weggooien.
	local lootIDs = {}
	for i = 1, (GetNumLootItems() or 0) do
		local link = GetLootSlotLink and GetLootSlotLink(i)
		local id = link and tonumber(link:match("item:(%d+)"))
		if id then lootIDs[id] = true end
	end
	-- Elke rij een eigen item om weg te gooien: het goedkoopste voor de duurste loot, enzovoort.
	local offers, used = {}, {}
	for _, l in ipairs(loots) do
		local junk = Cheapest(items, l, lootIDs, used)
		if junk then
			used[junk.e.bag .. ":" .. junk.e.slot] = true
			offers[#offers + 1] = { loot = l, junk = junk }
			ns.Note("bags full", ("offer: destroy %s (%d copper) for %s (%d copper)"):format(tostring(junk.e.itemID), junk.value or 0,
				Short(l.link), l.value or 0))
		else
			ns.Note("bags full", "no offer for " .. Short(l.link) .. ": nothing cheaper to destroy")
		end
	end
	if #offers == 0 then HidePanel(); return end
	ShowOffers(offers)
end

-- Even wachten: met autoloot pakt WoW eerst op wat past.
local function Schedule()
	if state.scheduled then return end
	state.scheduled = true
	C_Timer.After(0.3, function()
		state.scheduled = false
		local ok, err = pcall(Evaluate)
		if not ok then ns.SetError("loot: " .. tostring(err)) end
	end)
end

-- Aangeroepen vanuit Start.lua.
function ns.LootEvent(event)
	if event == "LOOT_CLOSED" then
		state.pending, state.dismissed = nil, false
		state.skipItems, state.skipGroups = {}, {} -- "eenmalig overslaan" is voorbij
		HidePanel()
	elseif ns.DB and ns.DB.lootPanel == false then
		HidePanel() -- optie "Bags full: offer to make room" staat uit
	elseif event == "BAG" then
		if panel and panel:IsShown() then Schedule() end
	else -- LOOT_OPENED, LOOT_SLOT_CLEARED, tassen vol
		Schedule()
	end
end

---------------------------------------------------------------------------
-- Events: lootvenster en "tassen vol"
---------------------------------------------------------------------------

for _, ev in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED" }) do
	ns.OnEvent(ev, "loot", function(event) ns.LootEvent(event) end)
end
ns.OnEvent("BAG_UPDATE_DELAYED", "loot", function() ns.LootEvent("BAG") end)
ns.OnEvent("UI_ERROR_MESSAGE", "loot", function(_, _, msg)
	if ERR_INV_FULL and msg == ERR_INV_FULL then
		-- belangrijk moment: later terug te lezen (DB.events)
		local okS, _, free = pcall(Scan)
		local loot = GetNumLootItems and (GetNumLootItems() or 0) or 0
		ns.Note("bags full", ("free slots %s, loot window items %d, panel %s"):format(okS and free and #free or "?", loot,
			ns.DB.lootPanel == false and "off" or "on"))
		ns.LootEvent("FULL")
	elseif GetNumLootItems and (GetNumLootItems() or 0) > 0 then
		ns.Note("bags full", "loot window open, WoW says: " .. tostring(msg)) -- bijv. "kan er niet meer van dragen"
	end
end)
