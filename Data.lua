-- CarefreeBag: Data.lua
-- Tassen en bank uitlezen (Scan), indeling (SectionOf), onthouden per karakter en de tooltip "waar heb je dit nog meer".
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Assign, CatByKey, CharEntry, CS, FullName, Hidden = ns.Assign, ns.CatByKey, ns.CharEntry, ns.CS, ns.FullName, ns.Hidden
local Log, MyFullName, PRESET, SameName, T = ns.Log, ns.MyFullName, ns.PRESET, ns.SameName, ns.T

---------------------------------------------------------------------------
-- Tassen uitlezen
---------------------------------------------------------------------------

local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
-- Retail heeft een aparte reagent-tas (alleen voor crafting reagents). In Classic is die er niet.
local REAGENT_BAG = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
ns.needInfo = false

local function ItemExtra(itemID)
	local ok, name, _, _, _, _, _, _, stack, equipLoc, _, price, classID, subclassID, bind = pcall(C_Item.GetItemInfo, itemID)
	if ok and name then return stack or 1, bind or 0, price or 0, classID, equipLoc, subclassID end
	ns.needInfo = true
	if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
	return nil, nil, 0, nil, nil, nil
end

local QUEST_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Questitem) or 12

local function IsQuestItem(bag, slot, classID)
	if classID == QUEST_CLASS then return true end
	if C_Container.GetContainerItemQuestInfo then
		local ok, q = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
		if ok and q and (q.isQuestItem or q.questID) then return true end
	end
	return false
end

-- AH-prijs per stuk via Auctionator (als die geïnstalleerd is en een scan heeft).
function ns.AHPrice(link)
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	if not (api and api.GetAuctionPriceByItemLink and link) then return nil end
	local ok, price = pcall(api.GetAuctionPriceByItemLink, "CarefreeBag", link)
	if ok and type(price) == "number" and price > 0 then return price end
	return nil
end

-- Waar komt de prijs vandaan? "none" = geen Auctionator, "noprice" = Auctionator kent het
-- item (nog) niet, "price" = wel een prijs; age = dagen sinds Auctionator het zag (of nil).
function ns.AHInfo(link)
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	if not (api and api.GetAuctionPriceByItemLink) then return "none" end
	if not ns.AHPrice(link) then return "noprice" end
	local age
	if api.GetAuctionAgeByItemLink then
		local ok, a = pcall(api.GetAuctionAgeByItemLink, "CarefreeBag", link)
		if ok and type(a) == "number" then age = a end
	end
	return "price", age
end

local AH_CUT = 0.05

-- Onze regels onder de item-tooltip: wat de stack op het AH oplevert na kosten,
-- en of het AH of de vendor meer geeft.
-- Icoontjes voor het advies, zodat je niet hoeft te lezen waar het heen moet.
local AH_ICON = "|TInterface\\Minimap\\Tracking\\Auctioneer:14:14|t"
local VENDOR_ICON = "|TInterface\\GossipFrame\\VendorGossipIcon:14:14|t"
-- Het woord ernaast in de kleur van het icoon (bruine geldbuidel, gouden AH-hamer).
local AH_COLOR, VENDOR_COLOR = "|cffffcc33", "|cffd9a066"

local function AddAHLines(tt, g)
	if not g then return end
	local each = ns.AHPrice(g.link)
	if not each then return end
	local money = function(m) return GetMoneyString and GetMoneyString(math.floor(m), true) or tostring(math.floor(m)) end
	local net = each * g.count * (1 - AH_CUT)
	local vendor = g.value or 0
	tt:AddLine(" ")
	-- Eén regel: "CarefreeBag:" in blauw + advies + hoeveel meer (AH al na 5% kosten).
	-- Levert het AH (afgerond) niets meer op, dan gewoon: verkoop aan de vendor, zonder bedrag.
	local diff = math.floor(net) - vendor
	if diff > 0 then
		-- het bedrag zelf in gewoon wit, zoals WoW geld altijd toont
		local amount = "|r|cffffffff" .. money(diff) .. "|r|cff40ff40"
		local ah = "|r" .. AH_ICON .. " " .. AH_COLOR .. T("AH") .. "|r|cff40ff40"
		tt:AddLine("|cff66ccffCarefreeBag:|r |cff40ff40" .. T("Sell on the %s to earn %s more than at a vendor"):format(ah, amount) .. "|r")
	else
		local vendorWord = "|r" .. VENDOR_ICON .. " " .. VENDOR_COLOR .. T("vendor") .. "|r|cffffd100"
		tt:AddLine("|cff66ccffCarefreeBag:|r |cffffd100" .. T("Sell to a %s for the best price"):format(vendorWord) .. "|r")
	end
end
local AddOwnerLines -- vooruit: "waar heb je dit nog meer" (zie Overzicht van je karakters)
local ahHooked
function ns.HookAHTooltip()
	if ahHooked then return end
	ahHooked = true
	local function post(tt)
		if tt ~= GameTooltip or not tt.GetOwner then return end
		local owner = tt:GetOwner()
		if owner and owner.isCarefreeItem and owner.group then AddAHLines(tt, owner.group) end
		if owner and owner.isCarefreeItem and owner.group and ns.KeptLine then pcall(ns.KeptLine, tt, owner.group.itemID) end
		if owner and ns.QuestTooltip then pcall(ns.QuestTooltip, tt, owner) end -- bij welke quest hoort het (QuestItems.lua)
		if AddOwnerLines then pcall(AddOwnerLines, tt) end
		if ns.BagTooltip then pcall(ns.BagTooltip, tt) end -- tas onder de muis: tasvakjes even tonen (BlizzBagBar.lua)
	end
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, post)
	elseif GameTooltip.HookScript then
		pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", post)
	end
end -- het AH houdt 5% van de verkoopprijs in (de borg krijg je terug)

local function IsBoE(e)
	return e.bindType == 2 and not e.bound and (e.quality or 0) >= 2
end

-- Keyring (sleutelring): alleen als het spel die heeft en toont.
function ns.KeyringBag()
	local id = KEYRING_CONTAINER or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)
	if not id then return nil end
	-- Classic Era en TBC hebben een keyring; retail en MoP niet (0 vakjes = geen keyring).
	local okN, n = pcall(C_Container.GetContainerNumSlots, id)
	if not okN or not n or n == 0 then return nil end
	if C_ActionBar and C_ActionBar.ShouldShowKeyring then
		local ok, show = pcall(C_ActionBar.ShouldShowKeyring)
		if ok and not show then return nil end
	end
	return id
end

-- Eén item uit een tasvak, met alles wat de indeling nodig heeft.
local function MakeEntry(bag, slot, info, isKey)
	local stack, bind, price, classID, equipLoc, subclassID = ItemExtra(info.itemID)
	local link = info.hyperlink
	return {
		bag = bag, slot = slot, info = info, itemID = info.itemID,
		count = info.stackCount or 1, quality = info.quality or 1,
		bound = info.isBound, link = link,
		name = link and link:match("%[(.-)%]") or tostring(info.itemID),
		maxStack = stack or ((info.stackCount or 1) > 1 and 20 or 1),
		stackKnown = stack ~= nil,
		bindType = bind or 0,
		price = price or 0,
		quest = IsQuestItem(bag, slot, classID),
		classID = classID, subclassID = subclassID, equipLoc = equipLoc,
		key = isKey,
	}
end

function ns.Scan()
	local items, free = {}, {}
	local total = 0
	ns.needInfo = false
	local bags = {}
	for bag = 0, LAST_BAG do bags[#bags + 1] = bag end
	local keyBag = ns.KeyringBag()
	if keyBag then bags[#bags + 1] = keyBag end
	for _, bag in ipairs(bags) do
		local isKey = (bag == keyBag)
		local n = C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, n do
			if not isKey then total = total + 1 end
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				items[#items + 1] = MakeEntry(bag, slot, info, isKey)
			elseif not isKey then
				free[#free + 1] = { bag = bag, slot = slot, reagent = (bag == REAGENT_BAG) or nil }
			end
		end
	end
	return items, free, total
end

---------------------------------------------------------------------------
-- Overzicht van je karakters: wat zit er in hun tassen en bank?
-- De bank kun je alleen bij de bankier uitlezen; daarna onthouden we wat erin zat.
---------------------------------------------------------------------------

ns.bankOpen = false
local ownerIndex -- [itemID] = { { key, bags, bank }, ... }; nil = opnieuw opbouwen

-- Compacte kopie van een lijst items (zelfde item + gebonden = één regel).
local function Snapshot(items)
	local list, at = {}, {}
	for _, e in ipairs(items) do
		local id = (e.link or e.itemID) .. (e.bound and "b" or "")
		local r = at[id]
		if r then
			r.n = r.n + e.count
		else
			r = { id = e.itemID, n = e.count, l = e.link, q = e.quality, i = e.info and e.info.iconFileID,
				b = e.bound or nil, qu = e.quest or nil, bt = e.bindType, c = e.classID, s = e.subclassID,
				e = e.equipLoc, p = e.price, k = e.key or nil }
			at[id] = r
			list[#list + 1] = r
		end
	end
	return list
end

-- Alle bankvakken: oude bank (vak -1 + banktassen; Forever en Classic) en de
-- nieuwe banktabbladen (retail). We nemen alleen wat echt vakjes heeft.
local function BankBags()
	local ids, seen = {}, {}
	local function add(id)
		if id and not seen[id] then
			seen[id] = true
			local ok, n = pcall(C_Container.GetContainerNumSlots, id)
			if ok and n and n > 0 then ids[#ids + 1] = id end
		end
	end
	add(BANK_CONTAINER or (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or -1)
	for i = 1, (NUM_BANKBAGSLOTS or 0) do add(LAST_BAG + i) end
	if Enum and Enum.BagIndex then
		for i = 1, 12 do add(Enum.BagIndex["CharacterBankTab_" .. i]) end
	end
	return ids
end

local function ScanBags(bags)
	local items = {}
	for _, bag in ipairs(bags) do
		local n = C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, n do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then items[#items + 1] = MakeEntry(bag, slot, info) end
		end
	end
	return items
end

local function MySnap()
	if ns.viewKey then return nil end
	local ch = CharEntry()
	if not ch then return nil end
	ch.snap = ch.snap or {}
	ch.snap.name = MyFullName()
	local _, class = UnitClass and UnitClass("player")
	ch.snap.class = class
	-- goud van dit karakter, voor het bankpaneel (per karakter en alles samen)
	local okM, m = pcall(GetMoney)
	if okM and type(m) == "number" then ch.snap.money = m end
	return ch.snap
end

function ns.SnapBags()
	local s = MySnap()
	if not s then return end
	-- Alleen tijdens het spelen opslaan; bij uitloggen zijn de tassen al leeg (dat ging mis).
	local items, free, total = ns.Scan()
	if #items == 0 and #free == 0 then return end -- tassen nog niet geladen
	local list = Snapshot(items)
	s.bagsFree, s.bagsSlots = #free, total -- vrije vakjes, voor het bankpaneel
	if not s.bags or #s.bags ~= #list then Log(("snapshot: bags %d items"):format(#list)) end
	s.bags, s.bagsTime = list, time and time() or nil
	ownerIndex = nil
end

function ns.SnapBank()
	if not ns.bankOpen then return end
	local s = MySnap()
	if not s then return end
	local ids = BankBags()
	if #ids == 0 then return end -- bank nog niet geladen
	local raw = ScanBags(ids)
	local list = Snapshot(raw)
	local slots = 0
	for _, id in ipairs(ids) do slots = slots + (C_Container.GetContainerNumSlots(id) or 0) end
	s.bankFree, s.bankSlots = math.max(0, slots - #raw), slots -- vrije vakjes, voor het bankpaneel
	if not s.bank or #s.bank ~= #list then
		Log(("snapshot: bank %d items (containers %s)"):format(#list, table.concat(ids, ",")))
	end
	s.bank, s.bankTime = list, time and time() or nil
	ownerIndex = nil
end

-- Na veranderingen in je tassen (of bank) even wachten en dan één keer opslaan.
local snapPending = false
function ns.ScheduleSnap()
	if snapPending then return end
	snapPending = true
	C_Timer.After(1, function()
		snapPending = false
		pcall(ns.SnapBags)
		if ns.bankOpen then pcall(ns.SnapBank) end
		if ns.ViewRefresh then pcall(ns.ViewRefresh) end
	end)
end

-- Waar heb je dit item nog meer? Voor de tooltip.
local function BuildOwnerIndex()
	ownerIndex = {}
	for key, ch in pairs(ns.DB.chars or {}) do
		local s = ch.snap
		if s then
			for _, part in ipairs({ "bags", "bank" }) do
				for _, r in ipairs(s[part] or {}) do
					local list = ownerIndex[r.id]
					if not list then list = {}; ownerIndex[r.id] = list end
					local row
					for _, x in ipairs(list) do if x.key == key then row = x end end
					if not row then row = { key = key, name = s.name or key, bags = 0, bank = 0 }; list[#list + 1] = row end
					row[part] = row[part] + r.n
				end
			end
		end
	end
end

AddOwnerLines = function(tt)
	local id
	if tt.GetItem then
		local _, link = tt:GetItem()
		id = link and tonumber(link:match("item:(%d+)"))
	end
	if not id then return end
	if not ownerIndex then BuildOwnerIndex() end
	local list = ownerIndex[id]
	if not list or #list == 0 then return end
	-- alleen tonen als het ergens anders ligt dan in je eigen tassen
	local other = false
	for _, row in ipairs(list) do
		if row.key ~= ns.charKey or row.bank > 0 then other = true end
	end
	if not other then return end
	tt:AddLine(" ")
	tt:AddLine("|cff66ccffCarefreeBag:|r")
	table.sort(list, function(a, b) return (a.key == ns.charKey) and b.key ~= ns.charKey or ((a.key == ns.charKey) == (b.key == ns.charKey) and a.name < b.name) end)
	for i, row in ipairs(list) do
		if i > 8 then break end
		local parts = {}
		if row.bags > 0 then parts[#parts + 1] = T("Bags") .. " " .. row.bags end
		if row.bank > 0 then parts[#parts + 1] = T("Bank") .. " " .. row.bank end
		tt:AddDoubleLine(row.name, table.concat(parts, ", "), 1, 0.82, 0, 1, 1, 1)
	end
	tt:Show()
end

function ns.On(k) return not (ns.DB.fixedOn and ns.DB.fixedOn[k] == false) end

function ns.SectionOf(e)
	if Hidden()[e.itemID] then return "hidden" end
	-- Sleutels uit de keyring: groep Keys uit = niet in het venster (ze blijven gewoon in de keyring).
	if e.key then return "keys" end
	local key = Assign()[e.itemID]
	if key == "grey" and ns.On("grey") then return "grey" end    -- zelf naar Auto Sell gesleept
	if key == "other" then return "other" end                 -- zelf naar Overig gesleept: nooit automatisch
	if key == "quest" and ns.On("quest") then return "quest" end -- zelf naar Quest gesleept
	if key == "boe" and ns.On("boe") then return "boe" end       -- zelf naar BoE gesleept
	if key and CatByKey(key) then return key end
	if ns.On("quest") and ns.DB.questAuto and e.quest then return "quest" end
	if ns.On("grey") and ns.DB.greyAuto and e.quality == 0 then return "grey" end
	if ns.On("boe") and IsBoE(e) then return "boe" end
	local best, bestKey
	for _, c in ipairs(CS().cats) do
		local p = c.preset and PRESET[c.preset]
		if p and (not best or p.rank < best.rank) and p.match(e) then best, bestKey = p, c.key end
	end
	if bestKey then return bestKey end
	return "other"
end

-- Waar moet een item heen bij de mailbox? (nil = nergens)
function ns.MailTarget(e)
	if Hidden()[e.itemID] or e.bound or e.key then return nil end
	local sec = ns.SectionOf(e)
	local name
	if sec == "boe" then
		name = ns.DB.boeMail
	else
		local c = CatByKey(sec)
		name = c and c.mailTo
	end
	if not name or name == "" then return nil end
	if SameName(name, MyFullName()) then return nil end -- nooit naar jezelf
	return FullName(name), sec
end

---------------------------------------------------------------------------
-- Events: tassen en goud van dit karakter onthouden (voor het bankpaneel en de tooltip)
---------------------------------------------------------------------------

ns.OnEvent("BAG_UPDATE_DELAYED", "snapshot", function() ns.ScheduleSnap() end)
ns.OnEvent("PLAYER_MONEY", "snapshot", function() ns.ScheduleSnap() end)
-- Meteen na versturen onthouden (anders mist het bankpaneel het als je vlak daarna van karakter wisselt).
ns.OnEvent("MAIL_SEND_SUCCESS", "snapshot", function()
	C_Timer.After(0.5, function() ns.Try("snapshot", ns.SnapBags) end)
end)
