-- CarefreeBag: Loot.lua
-- Tassen vol en er ligt loot die niet past? Dan tonen we de loot naast het goedkoopste
-- item (of de goedkoopste stapel) in je tassen, met prijzen. Eén klik: dat item weggooien
-- en de loot oppakken. Weggooien (DeleteCursorItem) mag WoW alleen na een klik van de
-- speler doen, daarom gebeurt het niet helemaal automatisch.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local AHPrice, Log, MakeButton, NewWindow, Print, Scan = ns.AHPrice, ns.Log, ns.MakeButton, ns.NewWindow, ns.Print, ns.Scan
local CatByKey, Kept, KeptGroups, SectionOf, T = ns.CatByKey, ns.Kept, ns.KeptGroups, ns.SectionOf, ns.T

local LOOT_ITEM = (Enum and Enum.LootSlotType and Enum.LootSlotType.Item) or LOOT_SLOT_ITEM or 1
local AH_CUT = 0.05
local QUEST_VALUE = 2 ^ 50                                -- questloot is altijd "meer waard"
local NEVER = { quest = true, keys = true, hidden = true } -- deze groepen stellen we nooit voor
local W, H = 300, 230

-- Naam van een groep zoals in de tas.
local function GroupName(key)
	if key == "grey" then return "Auto Sell" end
	if key == "boe" then return "BoE" end
	if key == "other" then return T("Other") end
	local c = CatByKey(key)
	return c and c.name or tostring(key)
end

local state = { pending = nil, dismissed = false, scheduled = false }
local panel

local function Money(m)
	m = math.floor(m or 0)
	return GetMoneyString and GetMoneyString(m, true) or tostring(m)
end

-- Alles van GetItemInfo in één tabel (r[12] = vendorprijs, r[18] = crafting reagent).
local function Info(x)
	local r = { pcall(C_Item.GetItemInfo, x) }
	if r[1] and r[2] then return r end
	return nil
end

-- Wat is één stuk waard? De vendorprijs, of het AH (na 5% kosten) als dat meer geeft.
local function Each(link, vendor)
	local v, ah = vendor or 0, AHPrice(link)
	if ah and math.floor(ah * (1 - AH_CUT)) > v then return math.floor(ah * (1 - AH_CUT)), true end
	return v, false
end

-- Goedkoopste stapel in je tassen. Alleen items met een prijs: items zonder waarde
-- (hearthstone, questspullen, sleutels) zijn vaak juist belangrijk. Items en groepen
-- die je wilt houden ("Keep") slaan we over.
local CanHold -- vooruit (hieronder)
-- Alleen items uit een tas waar de loot daarna ook in past: een vak in een
-- beroepstas (bijv. mijnbouw) vrijmaken helpt niets voor een gewoon item.
local function Cheapest(items, lootItem)
	local best
	local keep, keepGroups = Kept(), KeptGroups()
	for _, e in ipairs(items) do
		local sec = SectionOf(e)
		if not e.key and not e.info.isLocked and not e.info.hasNoValue and not NEVER[sec]
			and CanHold(e.bag, lootItem.id, lootItem.reagent)
			and not keep[e.itemID] and not (keepGroups[sec] and sec ~= "grey" and sec ~= "other") then
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

-- Het meest waardevolle loot-item dat niet in je tassen past.
local function BestLoot(items, free)
	local n = GetNumLootItems and GetNumLootItems() or 0
	local best
	for i = 1, n do
		local link = GetLootSlotLink and GetLootSlotLink(i)
		if link and (not GetLootSlotType or GetLootSlotType(i) == LOOT_ITEM) then
			local icon, _, qty, _, _, locked, isQuest = GetLootSlotInfo(i)
			local id = tonumber(link:match("item:(%d+)"))
			local r = id and Info(id)
			qty = (qty and qty > 0) and qty or 1
			if id and not locked and not Fits(items, free, id, qty, r and r[18]) then
				local each, ah = Each(link, r and r[12])
				local v = isQuest and QUEST_VALUE or each * qty
				if not best or v > best.value then
					best = { slot = i, link = link, icon = icon, count = qty, value = v, ah = ah, quest = isQuest,
						id = id, reagent = r and r[18] }
				end
			end
		end
	end
	return best
end

---------------------------------------------------------------------------
-- Het paneel naast het lootvenster
---------------------------------------------------------------------------

local function Row(parent, y, label)
	local r = CreateFrame("Button", nil, parent)
	r:SetSize(W - 2 * ns.PAD, 40)
	r:SetPoint("TOPLEFT", parent, "TOPLEFT", ns.PAD, y)
	r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	r.label:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
	r.label:SetText(label)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(24, 24)
	r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -14)
	r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.value:SetPoint("RIGHT", r, "TOPRIGHT", 0, -26)
	r.value:SetJustifyH("RIGHT")
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetWidth(W - 2 * ns.PAD - 30 - 90)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r:SetScript("OnEnter", function(self)
		if not self.link then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return r
end

local function FillRow(r, link, icon, count, value, ah, quest)
	r.link = link
	r.icon:SetTexture(icon)
	r.name:SetText((link or "?") .. ((count or 1) > 1 and (" x" .. count) or ""))
	if quest then
		r.value:SetText("|cffffd100" .. T("Quest item") .. "|r")
	elseif (value or 0) <= 0 then
		r.value:SetText("|cff9d9d9d" .. T("No value") .. "|r")
	else
		r.value:SetText(Money(value) .. (ah and " |cff66ccffAH|r" or ""))
	end
end

local function HidePanel()
	if panel and panel:IsShown() then panel:Hide() end
	if panel then panel.offer = nil end
end

local Evaluate -- vooruit

-- Na het weggooien wachten tot het vakje echt vrij is, dan de loot oppakken.
local function TryPending()
	local p = state.pending
	if not p then return end
	if not GetLootSlotLink or GetLootSlotLink(p.slot) ~= p.link then
		Log("loot: slot " .. p.slot .. " changed before looting")
		state.pending = nil
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
	Log(("loot: LootSlot(%d) %s, room=%s, tries=%d"):format(p.slot, p.link:match("%[(.-)%]") or "?", tostring(room), p.tries))
	LootSlot(p.slot)
	C_Timer.After(0.3, Evaluate) -- misschien past er nog iets niet
end

-- Klik op "Weggooien & looten" (een echte klik: anders weigert WoW het weggooien).
local function Swap()
	local o = panel and panel.offer
	if not o then return end
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
	Log(("loot swap: destroyed %s (%d copper) for %s"):format(tostring(e.itemID), o.junk.value, o.loot.link:match("%[(.-)%]") or "?"))
	state.pending = { slot = o.loot.slot, link = o.loot.link, id = o.loot.id, reagent = o.loot.reagent, tries = 0 }
	HidePanel()
	C_Timer.After(0.2, TryPending)
end

local function BuildPanel()
	panel = NewWindow("CarefreeBagLootPanel", T("Bags full"), W, H)
	panel:SetFrameStrata("HIGH")
	panel.lootRow = Row(panel, -30, T("Loot that does not fit"))
	panel.junkRow = Row(panel, -76, T("Cheapest in your bags"))
	-- Dit item of deze groep nooit weggooien: dan komt meteen het volgende goedkoopste item.
	local half = (W - 2 * ns.PAD - 6) / 2
	panel.keepItem = MakeButton(panel, T("Always keep item"), half)
	panel.keepItem:SetPoint("TOPLEFT", panel, "TOPLEFT", ns.PAD, -120)
	panel.keepItem:SetScript("OnClick", function()
		local o = panel.offer
		if not o then return end
		Kept()[o.junk.e.itemID] = true
		Print(T("%s is never destroyed when your bags are full."):format(o.junk.e.link or o.junk.e.name))
		Log("loot: keep item " .. tostring(o.junk.e.itemID))
		Evaluate()
	end)
	ns.Tooltip(panel.keepItem, T("Always keep item"), T("Never destroy this item when your bags are full. The next cheapest item is shown."))
	panel.keepGroup = MakeButton(panel, T("Always keep group"), half)
	panel.keepGroup:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -ns.PAD, -120)
	panel.keepGroup:SetScript("OnClick", function()
		local o = panel.offer
		if not o then return end
		KeptGroups()[o.junk.sec] = true
		Print(T("Nothing from the group %s is destroyed when your bags are full. Change it in the options (Always keep)."):format(GroupName(o.junk.sec)))
		Log("loot: keep group " .. tostring(o.junk.sec))
		if ns.RefreshConfig then ns.RefreshConfig() end
		Evaluate()
	end)
	ns.Tooltip(panel.keepGroup, T("Always keep group"), T("Never destroy anything from this group when your bags are full. Change it in the options (Always keep)."))
	panel.verdict = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	panel.verdict:SetPoint("TOPLEFT", panel, "TOPLEFT", ns.PAD, -154)
	panel.verdict:SetWidth(W - 2 * ns.PAD)
	panel.verdict:SetJustifyH("LEFT")
	panel.swap = MakeButton(panel, T("Destroy & loot"), 140)
	panel.swap:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", ns.PAD, 16)
	panel.swap:SetScript("OnClick", Swap)
	ns.Tooltip(panel.swap, T("Destroy & loot"), T("Destroys the cheapest item for good (it cannot be bought back) and picks up the loot."))
	panel.skip = MakeButton(panel, T("Skip"), 110)
	panel.skip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -ns.PAD, 16)
	panel.skip:SetScript("OnClick", function() state.dismissed = true; HidePanel() end)
	ns.lootPanel = panel
end

local function ShowOffer(lootItem, junk)
	if not panel then BuildPanel() end
	panel.offer = { loot = lootItem, junk = junk }
	FillRow(panel.lootRow, lootItem.link, lootItem.icon, lootItem.count, lootItem.value, lootItem.ah, lootItem.quest)
	local e = junk.e
	FillRow(panel.junkRow, e.link, e.info.iconFileID, e.count, junk.value, junk.ah, false)
	panel.junkRow.label:SetText(T("Cheapest in your bags") .. " |cffaaaaaa(" .. GroupName(junk.sec) .. ")|r")
	-- Auto Sell is er juist om weg te doen; in Other staan ook items die weg mogen
	panel.keepGroup:SetShown(junk.sec ~= "grey" and junk.sec ~= "other")
	if lootItem.quest then
		panel.verdict:SetText("|cff40ff40" .. T("The loot is a quest item.") .. "|r")
	elseif lootItem.value > junk.value then
		panel.verdict:SetText("|cff40ff40" .. T("The loot is worth %s more."):format("|r" .. Money(lootItem.value - junk.value) .. "|cff40ff40") .. "|r")
	else
		panel.verdict:SetText("|cffff6060" .. T("The loot is worth %s less."):format("|r" .. Money(junk.value - lootItem.value) .. "|cffff6060") .. "|r")
	end
	panel:ClearAllPoints()
	if LootFrame and LootFrame:IsShown() then
		panel:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 4, 0)
	else
		panel:SetPoint("TOP", UIParent, "TOP", 0, -140)
	end
	panel:Show()
end

Evaluate = function()
	if not ns.DB.enabled or state.dismissed or state.pending then return end
	if not (GetNumLootItems and (GetNumLootItems() or 0) > 0) then HidePanel(); return end
	local items, free = Scan()
	local lootItem = BestLoot(items, free)
	local junk = lootItem and Cheapest(items, lootItem)
	if not junk then HidePanel(); return end
	ShowOffer(lootItem, junk)
end

-- Even wachten: met autoloot pakt WoW eerst op wat past.
local function Schedule()
	if state.scheduled then return end
	state.scheduled = true
	C_Timer.After(0.3, function()
		state.scheduled = false
		local ok, err = pcall(Evaluate)
		if not ok then ns.DB.lastError = "loot: " .. tostring(err); Log("loot error: " .. tostring(err)) end
	end)
end

-- Aangeroepen vanuit Start.lua.
function ns.LootEvent(event)
	if event == "LOOT_CLOSED" then
		state.pending, state.dismissed = nil, false
		HidePanel()
	elseif event == "BAG" then
		if panel and panel:IsShown() then Schedule() end
	else -- LOOT_OPENED, LOOT_SLOT_CLEARED, tassen vol
		Schedule()
	end
end
