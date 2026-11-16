-- CarefreeBag: Loot.lua
-- Tassen vol en er ligt loot die niet past? Dan vragen we of je het goedkoopste item
-- (of de goedkoopste stapel) in je tassen wilt weggooien om de loot op te pakken, met een
-- duidelijk advies. Weggooien (DeleteCursorItem) mag WoW alleen na een klik van de speler
-- doen, daarom gebeurt het niet helemaal automatisch.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local AHPrice, Log, MakeButton, NewWindow, Print, Scan = ns.AHPrice, ns.Log, ns.MakeButton, ns.NewWindow, ns.Print, ns.Scan
local CatByKey, Kept, KeptGroups, SectionOf, T = ns.CatByKey, ns.Kept, ns.KeptGroups, ns.SectionOf, ns.T

local LOOT_ITEM = (Enum and Enum.LootSlotType and Enum.LootSlotType.Item) or LOOT_SLOT_ITEM or 1
local AH_CUT = 0.05
local QUEST_VALUE = 2 ^ 50                                -- questloot is altijd "meer waard"
local NEVER = { quest = true, keys = true, hidden = true } -- deze groepen stellen we nooit voor
local W, H = 300, 150
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
local state = { pending = nil, dismissed = false, scheduled = false, skipItems = {}, skipGroups = {}, left = {} }
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
local function Cheapest(items, lootItem, lootIDs)
	local best
	lootIDs = lootIDs or {}
	local keep, keepGroups = Kept(), KeptGroups()
	for _, e in ipairs(items) do
		local sec = SectionOf(e)
		if not e.key and not e.info.isLocked and not e.info.hasNoValue and not NEVER[sec]
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
			if id and not locked and not state.left[i .. link] and not Fits(items, free, id, qty, r and r[18]) then
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

-- Klik op "Destroy & pick up" (een echte klik: anders weigert WoW het weggooien).
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

-- Opties bij het item (zichtbaar bij hover): nooit / nu niet, voor het item of de hele groep.
local function MenuChoice(what)
	local o = panel and panel.offer
	if not o then return end
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
		if self:IsMouseOver() or (panel.junkRow and panel.junkRow:IsMouseOver()) then self.away = 0; return end
		self.away = self.away + (dt or 0)
		if self.away > 0.3 then self:Hide() end
	end)
	m:Hide()
	return m
end

local function ShowMenu()
	local o = panel.offer
	if not o then return end
	local m = panel.menu
	-- Auto Sell en Other zijn er juist voor spullen die weg mogen: geen "hele groep nooit".
	local groupOk = o.junk.sec ~= "grey" and o.junk.sec ~= "other"
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
	if panel.menuLeft then m:SetPoint("TOPRIGHT", panel, "TOPLEFT", -2, -44)
	else m:SetPoint("TOPLEFT", panel, "TOPRIGHT", 2, -44) end
	m.away = 0
	m:Show()
end

local function BuildPanel()
	panel = NewWindow("CarefreeBagLootPanel", T("Bags full"), W, H)
	panel:SetFrameStrata("HIGH")
	-- Dichte achtergrond: de standaard dialoogachtergrond is half doorzichtig, en dit
	-- venster ligt vaak boven je tassen (clam openen) en dan wordt het een rommeltje.
	panel.solid = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
	panel.solid:SetColorTexture(0.05, 0.05, 0.05, 0.95)
	panel.solid:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
	panel.solid:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 10)
	local inner = W - 2 * ns.PAD
	-- De vraag: om de loot op te pakken, dit weggooien?
	panel.question = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	panel.question:SetPoint("TOPLEFT", panel, "TOPLEFT", ns.PAD, -32)
	panel.question:SetWidth(inner)
	panel.question:SetJustifyH("LEFT")
	panel.question:SetWordWrap(true) -- lange itemnaam: liever 2 regels dan "destroy:" kwijt
	-- Het item dat weg zou gaan; pijltje rechts = er zijn opties (hover).
	local r = CreateFrame("Button", nil, panel)
	r:SetSize(inner, 30)
	r:SetPoint("TOPLEFT", panel.question, "BOTTOMLEFT", 0, -4)
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(26, 26)
	r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
	r.arrow = r:CreateTexture(nil, "OVERLAY")
	r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
	r.arrow:SetSize(12, 12)
	r.arrow:SetPoint("RIGHT", r, "RIGHT", -2, 0)
	r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.value:SetPoint("RIGHT", r.arrow, "LEFT", -6, 0)
	r.value:SetJustifyH("RIGHT")
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -1)
	r.name:SetWidth(inner - 34 - 100)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.label = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall") -- groep
	r.label:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 1)
	r:SetScript("OnEnter", function(self)
		ShowMenu()
		if not self.link then return end
		-- tooltip onder het paneel, zodat het menu ernaast vrij blijft
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -2)
		GameTooltip:SetHyperlink(self.link)
		local o = panel.offer
		if o then
			GameTooltip:AddLine(" ")
			for _, l in ipairs(ns.PriceLines(o.junk.e.link, o.loot.link)) do GameTooltip:AddLine(l, 0.8, 0.8, 0.8, true) end
		end
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	panel.junkRow = r
	panel.menu = BuildMenu()
	-- oude namen, voor de tests en wie ze nog gebruikt
	panel.keepItem, panel.keepGroup = panel.menu.keepItem, panel.menu.keepGroup
	panel.skipItem, panel.skipGroup = panel.menu.skipItem, panel.menu.skipGroup

	local bw = (inner - 10) / 2
	panel.swap = MakeButton(panel, T("Destroy & pick up"), bw)
	panel.swap:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", ns.PAD, 14)
	panel.swap:SetScript("OnClick", Swap)
	ns.Tooltip(panel.swap, T("Destroy & pick up"), T("Destroys the cheapest item for good (it cannot be bought back) and picks up the loot."))
	panel.skip = MakeButton(panel, T("Leave it"), bw)
	panel.skip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -ns.PAD, 14)
	-- Leave it: alleen dit loot-item laten liggen; ligt er nog meer dat niet past, dan meteen dat.
	panel.skip:SetScript("OnClick", function()
		local o = panel.offer
		if o then state.left[o.loot.slot .. o.loot.link] = true; Log("loot: leave " .. (o.loot.link:match("%[(.-)%]") or "?")) end
		HidePanel()
		Evaluate()
	end)
	ns.Tooltip(panel.skip, T("Leave it"), T("Leave the loot where it is. CarefreeBag asks again the next time you loot."))
	panel.leave = panel.skip
	-- Het advies staat boven de knop die we aanraden.
	panel.verdict = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	panel.verdict:SetWidth(inner) -- hele breedte: "1s 34c more" niet over twee regels
	panel.verdict:SetWordWrap(false)
	panel:HookScript("OnHide", function() panel.menu:Hide() end)
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

-- Naast het lootvenster, op de eerste plek die op het scherm past en je tassen niet
-- bedekt: rechts, links, eronder, erboven. Lukt dat nergens: rechts of links, wat past.
local function Place()
	panel:ClearAllPoints()
	panel.menuLeft = false
	local L = LootFrame and LootFrame:IsShown() and Rect(LootFrame)
	if not L then
		if LootFrame and LootFrame:IsShown() then panel:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 4, 0)
		else panel:SetPoint("TOP", UIParent, "TOP", 0, -140) end
		return
	end
	local k = (panel:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
	local pw, ph, mw = W * k, (panel:GetHeight() or H) * k, MENU_W * k
	local sw, sh = UIParent:GetWidth() or 1920, UIParent:GetHeight() or 1080
	local bags = ns.main and ns.main:IsShown() and Rect(ns.main)
	local spots = {
		{ r = { L[3] + 4, L[4] - ph, L[3] + 4 + pw, L[4] }, p = { "TOPLEFT", "TOPRIGHT", 4, 0 } },
		{ r = { L[1] - 4 - pw, L[4] - ph, L[1] - 4, L[4] }, p = { "TOPRIGHT", "TOPLEFT", -4, 0 }, menuLeft = true },
		{ r = { L[1], L[2] - 4 - ph, L[1] + pw, L[2] - 4 }, p = { "TOPLEFT", "BOTTOMLEFT", 0, -4 } },
		{ r = { L[1], L[4] + 4, L[1] + pw, L[4] + 4 + ph }, p = { "BOTTOMLEFT", "TOPLEFT", 0, 4 } },
	}
	local function OnScreen(r) return r[1] >= 0 and r[2] >= 0 and r[3] <= sw and r[4] <= sh end
	local pick
	for _, s in ipairs(spots) do
		if OnScreen(s.r) and not (bags and Overlap(s.r, bags)) then pick = s; break end
	end
	if not pick then pick = OnScreen(spots[1].r) and spots[1] or spots[2] end
	panel:SetPoint(pick.p[1], LootFrame, pick.p[2], pick.p[3], pick.p[4])
	-- menu aan de kant waar plek is (niet over het lootvenster of buiten beeld)
	panel.menuLeft = pick.menuLeft or (pick.r[3] + mw > sw) or false
end

local function ShowOffer(lootItem, junk)
	if not panel then BuildPanel() end
	local old = panel.offer and panel.offer.junk and panel.offer.junk.e
	local same = old and old.bag == junk.e.bag and old.slot == junk.e.slot and old.itemID == junk.e.itemID
	panel.offer = { loot = lootItem, junk = junk }
	panel.question:SetText(T("To pick up %s, destroy:"):format(lootItem.link .. ((lootItem.count or 1) > 1 and (" x" .. lootItem.count) or "")))
	-- hoogte: vraag (1 of 2 regels) + rij + advies + knoppen
	local qh = panel.question:GetStringHeight() or 12
	panel:SetHeight(math.max(H, 32 + qh + 4 + 30 + 34 + 36))
	local e, r = junk.e, panel.junkRow
	r.link = e.link
	r.icon:SetTexture(e.info.iconFileID)
	r.name:SetText((e.link or e.name or "?") .. (e.count > 1 and (" x" .. e.count) or ""))
	r.label:SetText(GroupName(junk.sec))
	r.value:SetText(Money(junk.value) .. (junk.ah and " |cff66ccffAH|r" or ""))
	-- Advies: oppakken als de loot meer waard is (of een questitem), anders laten liggen.
	local pickUp = lootItem.quest or lootItem.value > junk.value
	panel.advice = pickUp and "pickup" or "leave"
	if lootItem.quest then
		panel.verdict:SetText(T("The loot is a quest item."))
	elseif pickUp then
		panel.verdict:SetText(T("The loot is worth %s more."):format(Money(lootItem.value - junk.value)))
	else
		panel.verdict:SetText(T("The loot is worth %s less."):format(Money(junk.value - lootItem.value)))
	end
	local good = pickUp and panel.swap or panel.skip
	-- Boven de aanbevolen knop, uitgelijnd aan de kant van die knop.
	panel.verdict:ClearAllPoints()
	if pickUp then
		panel.verdict:SetPoint("BOTTOMLEFT", good, "TOPLEFT", 2, 5)
		panel.verdict:SetJustifyH("LEFT")
	else
		panel.verdict:SetPoint("BOTTOMRIGHT", good, "TOPRIGHT", -2, 5)
		panel.verdict:SetJustifyH("RIGHT")
	end
	Tint(panel.swap, pickUp)
	Tint(panel.skip, not pickUp)
	-- Zelfde item als net (bijv. tassen veranderden tijdens het looten): menu laten staan.
	if same and panel.menu:IsShown() then ShowMenu() else panel.menu:Hide() end
	Place()
	panel:Show()
end

Evaluate = function()
	if not ns.DB.enabled or state.dismissed or state.pending then return end
	if not (GetNumLootItems and (GetNumLootItems() or 0) > 0) then HidePanel(); return end
	local items, free = Scan()
	local lootItem = BestLoot(items, free)
	-- Items die ook in de loot liggen (bijv. een schelp die op je stapel past) niet weggooien.
	local lootIDs = {}
	for i = 1, (GetNumLootItems() or 0) do
		local link = GetLootSlotLink and GetLootSlotLink(i)
		local id = link and tonumber(link:match("item:(%d+)"))
		if id then lootIDs[id] = true end
	end
	local junk = lootItem and Cheapest(items, lootItem, lootIDs)
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
		state.skipItems, state.skipGroups, state.left = {}, {}, {} -- "eenmalig overslaan" is voorbij
		HidePanel()
	elseif event == "BAG" then
		if panel and panel:IsShown() then Schedule() end
	else -- LOOT_OPENED, LOOT_SLOT_CLEARED, tassen vol
		Schedule()
	end
end
