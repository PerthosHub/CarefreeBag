-- CarefreeBag: Stock.lua
-- "Keep N" per item (issues #22 + #24, Johans ontwerp 2026-11-27): Shift + muiswiel op een item
-- in je tassen = hoeveel je er altijd bij je wilt hebben. Dan doet CFB vanzelf:
--  * vendor: bijkopen tot N (als de vendor het verkoopt, alleen voor goud);
--  * bank: aanvullen tot N uit de bank, en alles boven N naar de bank;
--  * AH: één regel in de chat met wat je tekort komt;
--  * tassen: zak je onder N, dan één regel in de chat ("Running low").
-- N = 0: alles naar de bank (zo heb je ook een "naar de bank"-item, #24). Per karakter: ch.stock[itemID] = N.
-- Shift + muiswiel is een bewuste uitzondering op "geen verborgen trucjes" (Johans keuze,
-- 2026-11-27); daarom staat het in de tooltip van elk stapelbaar item, en het getal op het vakje.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Log, Print, Scan, T = ns.Log, ns.Print, ns.Scan, ns.T

local STEPS = { 1, 2, 3, 4, 5, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 120, 150, 200 }
local MAX_BUY = 200      -- noodrem: nooit meer dan dit in één keer kopen
local MAX_BANK_STEPS = 60 -- noodrem voor verplaatsen bij de bank
local COLOR = "|cff66ccff"

-- Instellingen van dit karakter: [itemID] = N.
function ns.Stock()
	local ch = ns.CharEntry()
	if not ch then return {} end
	ch.stock = ch.stock or {}
	return ch.stock
end

-- Hoeveel van elk item zit er in je tassen (zonder bank en sleutelring)? Eén keer scannen.
local function Counts()
	local n = {}
	for _, e in ipairs(Scan()) do
		if not e.key then n[e.itemID] = (n[e.itemID] or 0) + (e.count or 1) end
	end
	return n
end
local function Have(id) return Counts()[id] or 0 end

local function ItemName(id)
	local ok, name, link = pcall(C_Item.GetItemInfo, id)
	return (ok and (link or name)) or ("item " .. tostring(id))
end

local function Money(m) return GetMoneyString and GetMoneyString(math.floor(m), true) or tostring(m) end

-- Volgende stap van het muiswiel. Omhoog: uit → 1 → 2 … 200. Omlaag: … 1 → 0 (alles naar de bank) → uit.
local function Next(n, up)
	if up then
		if n == nil or n == 0 then return 1 end
		for _, s in ipairs(STEPS) do if s > n then return s end end
		return n
	end
	if n == nil or n == 0 then return nil end
	if n == 1 then return 0 end
	local prev = 1
	for _, s in ipairs(STEPS) do
		if s >= n then return prev end
		prev = s
	end
	return prev
end
ns.StockNext = Next -- voor de tests

---------------------------------------------------------------------------
-- Op het vakje en in de tooltip
---------------------------------------------------------------------------

-- Klein getal linksboven op het vakje: blauw = genoeg, oranje = te weinig. "0" = alles naar de bank.
function ns.StockBadge(b, g)
	local n = g and ns.Stock()[g.itemID]
	if n == nil then
		if b.stockText then b.stockText:Hide() end
		return
	end
	if not b.stockText then
		b.stockText = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		b.stockText:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	end
	b.stockText:SetText(tostring(n))
	if n > 0 and Have(g.itemID) < n then b.stockText:SetTextColor(1, 0.6, 0.2) else b.stockText:SetTextColor(0.4, 0.8, 1) end
	b.stockText:Show()
end

-- Tooltipregels (Data.lua, tooltip van een CFB-vakje). Zonder instelling alleen de uitleg,
-- en alleen bij stapelbare items: daar is het voor.
function ns.StockLine(tt, g)
	if not (tt and g and g.itemID) then return end
	local n = ns.Stock()[g.itemID]
	if n == nil then
		if g.rep and (g.rep.maxStack or 1) > 1 then
			tt:AddLine(COLOR .. "CarefreeBag:|r |cffaaaaaa" .. T("Shift + mouse wheel: always keep a number of these in your bags.") .. "|r", 1, 1, 1, true)
		end
		return
	end
	if n == 0 then
		tt:AddLine(COLOR .. "CarefreeBag:|r " .. T("Keep 0 in your bags: all of them go to the bank."), 1, 1, 1, true)
	else
		tt:AddLine(COLOR .. "CarefreeBag:|r " .. T("Keep %d in your bags (now %d). The vendor and the bank top up to %d, the rest goes to the bank.")
			:format(n, Have(g.itemID), n), 1, 1, 1, true)
	end
	tt:AddLine("|cffaaaaaa" .. T("Shift + mouse wheel to change.") .. "|r", 1, 1, 1, true)
end

local lastHave = {} -- voor "Running low": wat je had bij de vorige keer kijken

-- Shift + muiswiel op een vakje (BagWindow.lua, scrollgebied).
function ns.StockWheel(b, delta)
	local g = b and b.group
	if not g then return end
	local s = ns.Stock()
	local n = Next(s[g.itemID], (delta or 0) > 0)
	s[g.itemID] = n
	Log("keep in bags " .. tostring(g.itemID) .. " = " .. tostring(n))
	lastHave[g.itemID] = Have(g.itemID) -- het instellen zelf geeft geen "Running low"
	ns.StockBadge(b, g)
	-- tooltip meteen bijwerken (zelfde knop, opnieuw opbouwen)
	if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(b) then
		local enter = b:GetScript("OnEnter")
		if enter then pcall(enter, b) end
	end
end

---------------------------------------------------------------------------
-- Vendor: bijkopen tot N
---------------------------------------------------------------------------

local function MerchantID(i)
	if GetMerchantItemID then
		local ok, id = pcall(GetMerchantItemID, i)
		if ok and id then return id end
	end
	local link = GetMerchantItemLink and GetMerchantItemLink(i)
	return link and tonumber(link:match("item:(%d+)"))
end

-- prijs (per aankoop), aantal per aankoop, beschikbaar (-1 = onbeperkt), te koop, andere munt nodig
local function MerchantInfo(i)
	if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
		local ok, t = pcall(C_MerchantFrame.GetItemInfo, i)
		if ok and type(t) == "table" then return t.price, t.stackCount, t.numAvailable, t.isPurchasable, t.hasExtendedCost end
	end
	if GetMerchantItemInfo then
		local _, _, price, qty, avail, purchasable, _, ext = GetMerchantItemInfo(i)
		return price, qty, avail, purchasable, ext
	end
end

local lastBuy = -10
local function BuyUp()
	if not ns.DB.enabled or not (MerchantFrame and MerchantFrame:IsShown()) then return end
	local stock = ns.Stock()
	if not next(stock) then return end
	if GetTime() - lastBuy < 3 then return end -- MERCHANT_SHOW kan dubbel komen: niet twee keer kopen
	lastBuy = GetTime()
	local have = Counts()
	local money = GetMoney and GetMoney() or 0
	for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
		local id = MerchantID(i)
		local want = id and stock[id]
		if want and want > 0 then
			local need = math.min(want - (have[id] or 0), MAX_BUY)
			local price, pack, avail, purchasable, ext = MerchantInfo(i)
			pack = (pack and pack > 0) and pack or 1
			price = price or 0
			if need > 0 and purchasable ~= false and not ext then
				local packs = math.ceil(need / pack)
				if avail and avail >= 0 then packs = math.min(packs, avail) end -- -1 = onbeperkt
				if price > 0 then packs = math.min(packs, math.floor(money / price)) end
				if packs > 0 then
					if pack == 1 then
						-- per aankoop hooguit één volle stapel
						local max = (GetMerchantItemMaxStack and GetMerchantItemMaxStack(i)) or 20
						local left = packs
						while left > 0 do
							local k = math.min(left, math.max(1, max))
							BuyMerchantItem(i, k)
							left = left - k
						end
					else
						for _ = 1, packs do BuyMerchantItem(i) end
					end
					money = money - packs * price
					Print(T("Bought %s x%d for %s (you keep %d)."):format(ItemName(id), packs * pack, Money(packs * price), want))
					Log(("keep: bought %s x%d for %d copper"):format(tostring(id), packs * pack, packs * price))
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Bank: aanvullen tot N, en alles boven N naar de bank
---------------------------------------------------------------------------

-- Gewone tas (geen beroeps- of reagent-tas) met plek voor dit item: eerst een stapel met ruimte.
local function BagSpot(id, items, free)
	local okI, max = pcall(function() return select(8, C_Item.GetItemInfo(id)) end)
	max = okI and max or 1
	for _, e in ipairs(items) do
		if e.itemID == id and not e.key and not e.info.isLocked and (e.count or 1) < max then return e.bag, e.slot end
	end
	for _, f in ipairs(free) do
		if not f.reagent then
			local family = 0
			if f.bag ~= 0 then
				local okF, _, fam = pcall(C_Container.GetContainerNumFreeSlots, f.bag)
				family = okF and fam or 0
			end
			if family == 0 then return f.bag, f.slot end
		end
	end
end

-- Stapels van dit item in de bank.
local function BankStacks(id)
	local list = {}
	for _, bag in ipairs(ns.BankBags()) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID == id then list[#list + 1] = { bag = bag, slot = slot, count = info.stackCount or 1, locked = info.isLocked } end
		end
	end
	return list
end

local job -- { steps, before = { [id] = aantal in de tassen bij de start } }

local function Finish()
	if not job then return end
	local toBank, fromBank = {}, {}
	local now = Counts()
	for id, before in pairs(job.before) do
		local d = (now[id] or 0) - before
		if d < 0 then toBank[#toBank + 1] = ItemName(id) .. " x" .. -d end
		if d > 0 then fromBank[#fromBank + 1] = ItemName(id) .. " x" .. d end
	end
	if #toBank > 0 then Print(T("To the bank: %s."):format(table.concat(toBank, ", "))) end
	if #fromBank > 0 then Print(T("From the bank: %s."):format(table.concat(fromBank, ", "))) end
	if #toBank + #fromBank > 0 then Log("keep: bank done in " .. job.steps .. " step(s)") end
	job = nil
end

-- Eén verplaatsing per stap; daarna even wachten tot WoW klaar is.
local function BankStep()
	if not job then return end
	job.steps = job.steps + 1
	if not ns.bankOpen or job.steps > MAX_BANK_STEPS or not ns.DB.enabled then Finish(); return end
	local again = function() C_Timer.After(0.3, BankStep) end
	if CursorHasItem() then again(); return end
	local items, free = Scan()
	local have = {}
	for _, e in ipairs(items) do
		if e.info.isLocked then again(); return end -- WoW is nog bezig
		if not e.key then have[e.itemID] = (have[e.itemID] or 0) + (e.count or 1) end
	end
	for id, want in pairs(ns.Stock()) do
		local n = have[id] or 0
		if n > want then
			-- te veel: de kleinste stapel eerst naar de bank (past hij niet helemaal, dan splitsen)
			local surplus, src = n - want, nil
			for _, e in ipairs(items) do
				if e.itemID == id and not e.key and (not src or e.count < src.count) then src = e end
			end
			local spot = src and ns.BankSpot(id)
			if spot then
				if job.before[id] == nil then job.before[id] = n end
				if src.count <= surplus then C_Container.PickupContainerItem(src.bag, src.slot)
				else C_Container.SplitContainerItem(src.bag, src.slot, surplus) end
				C_Container.PickupContainerItem(spot.bag, spot.slot)
				-- bankstapel vol geraakt: de rest terug in hetzelfde vakje
				if CursorHasItem() then C_Container.PickupContainerItem(src.bag, src.slot) end
				again()
				return
			end
		elseif want > 0 and n < want then
			-- te weinig: uit de grootste bankstapel (meer dan nodig = splitsen)
			local need, src = want - n, nil
			for _, s in ipairs(BankStacks(id)) do
				if s.locked then again(); return end
				if not src or s.count > src.count then src = s end
			end
			local bag, slot = BagSpot(id, items, free)
			if src and bag then
				if job.before[id] == nil then job.before[id] = n end
				if src.count <= need then C_Container.PickupContainerItem(src.bag, src.slot)
				else C_Container.SplitContainerItem(src.bag, src.slot, need) end
				C_Container.PickupContainerItem(bag, slot)
				if CursorHasItem() then C_Container.PickupContainerItem(src.bag, src.slot) end
				again()
				return
			end
		end
	end
	Finish()
end

local function BankStart()
	if job or not ns.bankOpen or not ns.DB.enabled or not next(ns.Stock()) then return end
	if InCombatLockdown and InCombatLockdown() then return end
	job = { steps = 0, before = {} }
	BankStep()
end

---------------------------------------------------------------------------
-- Te weinig: in je tassen en bij het AH
---------------------------------------------------------------------------

local function Low(have)
	local list = {}
	for id, want in pairs(ns.Stock()) do
		if want > 0 and (have[id] or 0) < want then list[#list + 1] = ("%s %d/%d"):format(ItemName(id), have[id] or 0, want) end
	end
	table.sort(list)
	return list
end

-- Zak je onder N (en had je eerst genoeg)? Eén regel in de chat. Niet bij vendor of bank (daar vult CFB zelf aan).
local function CheckLow()
	local have = Counts()
	local busy = ns.bankOpen or (MerchantFrame and MerchantFrame:IsShown())
	for id, want in pairs(ns.Stock()) do
		local n, before = have[id] or 0, lastHave[id]
		if want > 0 and not busy and before and before >= want and n < want then
			Print(T("Running low: %s %d/%d."):format(ItemName(id), n, want))
		end
		lastHave[id] = n
	end
end

local function AtAuctionHouse()
	local list = Low(Counts())
	if #list > 0 then Print(T("Low on: %s. Buy them here?"):format(table.concat(list, ", "))) end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

ns.OnEvent("MERCHANT_SHOW", "keep", function() C_Timer.After(0.3, function() ns.Try("keep buy", BuyUp) end) end)
ns.OnEvent("BANKFRAME_OPENED", "keep", function() C_Timer.After(0.5, function() ns.Try("keep bank", BankStart) end) end)
ns.OnEvent("BAG_UPDATE_DELAYED", "keep", function() if next(ns.Stock()) then CheckLow() end end)
ns.OnEvent("AUCTION_HOUSE_SHOW", "keep", AtAuctionHouse)
ns.OnEvent("AUCTION_SHOW", "keep", AtAuctionHouse) -- Classic-AH
