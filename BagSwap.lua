-- CarefreeBag: BagSwap.lua
-- Tassen aandoen en wisselen:
--  * automatisch de beste tassen aandoen zodra je een tas krijgt (optie, standaard aan);
--  * rechtsklik op een tas = slim wisselen, ook als alle tasvakken vol zijn;
--  * wisselen werkt ook als de nieuwe tas in de tas zit die eruit moet (WoW weigert dat zelf);
--  * minder vakjes (downgrade) = eerst een vraag Ja/Nee.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Log, Print, Scan, T = ns.Log, ns.Print, ns.Scan, ns.T

local NUM_BAGS = NUM_BAG_SLOTS or 4 -- gewone tasvakken: containers 1 t/m 4 (0 = rugzak)
-- Retail/Forever: een apart reagent-vak. Daar past alleen een reagent-tas in.
local REAGENT_BAG = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
local CLASS_CONTAINER, CLASS_QUIVER = 1, 11
local SUB_BAG, SUB_SOUL, SUB_REAGENT = 0, 1, 11

---------------------------------------------------------------------------
-- Wat voor tas is het?
---------------------------------------------------------------------------

-- "normal" = gewone tas, "reagent" = reagent-tas, "prof" = beroepstas (Herb Bag e.d.),
-- "keep" = pijlkoker, munitietas, soul shard-tas: die laten we altijd met rust.
-- nil = geen tas (of iteminfo nog niet binnen).
local function KindOf(itemID)
	if not itemID then return nil end
	local ok, name, _, _, _, _, _, _, _, _, _, _, classID, subID, bind = pcall(C_Item.GetItemInfo, itemID)
	if not ok or not name then return nil end
	if classID == CLASS_QUIVER then return "keep", bind or 0 end
	if classID ~= CLASS_CONTAINER then return nil end
	if subID == SUB_BAG then return "normal", bind or 0 end
	if subID == SUB_REAGENT then return "reagent", bind or 0 end
	if subID == SUB_SOUL then return "keep", bind or 0 end
	return "prof", bind or 0
end

-- Hoe graag doen we deze tas aan bij hetzelfde aantal vakjes? Hoger = liever.
-- 3 = al soulbound (kun je toch niet meer ruilen), 2 = blijft verhandelbaar (geen binding,
-- account/warband), 1 = BoE e.d.: aandoen bindt hem, dus als laatste.
local function Rank(bind, bound)
	if bind == 7 or bind == 8 then return 2 end -- account/warband: isBound is dan ook waar
	if bound or bind == 1 or bind == 4 then return 3 end
	if bind == 0 or bind == 7 or bind == 8 then return 2 end
	return 1
end

-- Aantal vakjes van een tas in je tassen: staat alleen in de tooltip ("16 Slot Bag").
local slotCache, slotPattern, scanTip = {}, nil, nil

local function SlotPattern()
	if slotPattern ~= nil then return slotPattern end
	slotPattern = false
	local s = CONTAINER_SLOTS -- bijv. "%d Slot %s"
	if type(s) == "string" then
		s = s:gsub("%%%d?%$?s", "\1"):gsub("%%%d?%$?d", "\2")
		s = s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
		s = s:gsub("\1", ".-"):gsub("\2", "(%%d+)")
		slotPattern = "^" .. s
	end
	return slotPattern
end

local function TooltipLines(bag, slot)
	local lines = {}
	if C_TooltipInfo and C_TooltipInfo.GetBagItem then
		local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
		if ok and data and data.lines then
			for _, l in ipairs(data.lines) do lines[#lines + 1] = l.leftText end
			if #lines > 0 then return lines end
		end
	end
	-- Oudere clients: een verborgen tooltip uitlezen.
	if not scanTip then
		local ok, tip = pcall(CreateFrame, "GameTooltip", "CarefreeBagScanTip", nil, "GameTooltipTemplate")
		if not ok or not tip then return lines end
		scanTip = tip
	end
	scanTip:SetOwner(UIParent, "ANCHOR_NONE")
	scanTip:ClearLines()
	pcall(scanTip.SetBagItem, scanTip, bag, slot)
	for i = 1, (scanTip:NumLines() or 0) do
		local fs = _G["CarefreeBagScanTipTextLeft" .. i]
		lines[#lines + 1] = fs and fs:GetText()
	end
	scanTip:Hide()
	return lines
end

local function BagItemSlots(bag, slot, itemID)
	if slotCache[itemID] then return slotCache[itemID] end
	local pat = SlotPattern()
	for _, line in ipairs(TooltipLines(bag, slot)) do
		local n = line and ((pat and line:match(pat)) or line:match("^(%d+) "))
		if n and tonumber(n) and tonumber(n) > 0 then
			slotCache[itemID] = tonumber(n)
			return slotCache[itemID]
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Tasvakken: wat heb je aan?
---------------------------------------------------------------------------

local function InvID(c)
	if C_Container.ContainerIDToInventoryID then
		local ok, v = pcall(C_Container.ContainerIDToInventoryID, c)
		if ok and v then return v end
	end
	if ContainerIDToInventoryID then
		local ok, v = pcall(ContainerIDToInventoryID, c)
		if ok then return v end
	end
end

local function ItemName(itemID, link)
	if link then return link end
	local ok, name = pcall(C_Item.GetItemInfo, itemID)
	return (ok and name) or tostring(itemID)
end

-- Eén tasvak: { c, inv, slotType, itemID?, kind?, slots, rank, link }
local function SlotInfo(c)
	local inv = InvID(c)
	local s = { c = c, inv = inv, slotType = (c == REAGENT_BAG) and "reagent" or "normal", slots = 0 }
	local id = inv and GetInventoryItemID and GetInventoryItemID("player", inv)
	if id then
		local kind, bind = KindOf(id)
		s.itemID, s.kind = id, kind or "keep"
		s.slots = C_Container.GetContainerNumSlots(c) or 0
		-- Wat je aan hebt is soulbound, behalve tassen zonder binding (en account/warband).
		s.rank = (bind == 0 or bind == 7 or bind == 8) and 2 or 3
		s.link = GetInventoryItemLink and GetInventoryItemLink("player", inv)
	end
	return s
end

local function BagSlots()
	local list = {}
	for c = 1, NUM_BAGS do
		if InvID(c) then list[#list + 1] = SlotInfo(c) end
	end
	if REAGENT_BAG and InvID(REAGENT_BAG) then list[#list + 1] = SlotInfo(REAGENT_BAG) end
	return list
end

-- Hoe goed is een tas voor dit soort vak? Hoger = beter, nil = hoort hier niet.
-- Een gewone tas wint altijd van een beroepstas; daarna meer vakjes; daarna Rank.
local function Score(kind, slots, rank, slotType)
	if slotType == "reagent" then
		if kind ~= "reagent" then return nil end
		return slots * 10 + rank
	end
	if kind == "normal" then return 10000 + slots * 10 + rank end
	if kind == "prof" then return slots * 10 + rank end
	return nil
end

---------------------------------------------------------------------------
-- Wisselen, stap voor stap (één verplaatsing per keer, net als stapels samenvoegen)
---------------------------------------------------------------------------

local job -- { itemID, link, slots, kind, c, steps, put, old }

local function IsNormalBag(bag)
	if bag == REAGENT_BAG then return false end
	if bag == 0 then return true end
	local ok, _, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
	return not ok or (family or 0) == 0
end

-- Een vrij vakje in een gewone tas, niet in tas `skip`.
local function FreeOutside(skip)
	for bag = 0, NUM_BAGS do
		if bag ~= skip and IsNormalBag(bag) then
			for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
				if not C_Container.GetContainerItemInfo(bag, slot) then return bag, slot end
			end
		end
	end
end

-- Een item in een andere gewone tas om mee van plek te ruilen (als nergens meer plek is).
local function SwapPartner(skip)
	for bag = 0, NUM_BAGS do
		if bag ~= skip and IsNormalBag(bag) then
			for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
				local info = C_Container.GetContainerItemInfo(bag, slot)
				if info and not info.isLocked then return bag, slot end
			end
		end
	end
end

local function ItemsIn(c)
	local list = {}
	for slot = 1, (C_Container.GetContainerNumSlots(c) or 0) do
		local info = C_Container.GetContainerItemInfo(c, slot)
		if info and info.itemID then list[#list + 1] = { slot = slot, locked = info.isLocked } end
	end
	return list
end

local function Move(b1, s1, b2, s2)
	C_Container.PickupContainerItem(b1, s1)
	C_Container.PickupContainerItem(b2, s2)
	if CursorHasItem() then C_Container.PickupContainerItem(b1, s1) end -- geruild: het andere item terug
end

-- Waar zit de tas nu? (hij kan tussendoor verplaatst zijn)
local function FindBag(j)
	if j.bag then
		local info = C_Container.GetContainerItemInfo(j.bag, j.slot)
		if info and info.itemID == j.itemID then return j.bag, j.slot end
	end
	for _, e in ipairs(Scan()) do
		if e.itemID == j.itemID and not e.key and (not j.link or e.link == j.link) then return e.bag, e.slot end
	end
end

local Step -- vooruit

local function Finish(ok, msg)
	local j = job
	job = nil
	ns.bagSwapDone = GetTime()
	if ns.RememberBags then ns.RememberBags() end
	if msg then
		Print(msg)
		if not ok and UIErrorsFrame then pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, msg, 1, 0.1, 0.1) end
	end
	Log("bag swap " .. (ok and "done" or "stopped") .. ": " .. tostring(j and j.itemID))
	if ns.Refresh then ns.Refresh() end
	if ns.ScheduleRestack then ns.ScheduleRestack() end
	-- Het tas-event van deze wissel viel tijdens het wisselen: nog een keer kijken (2e tas tegelijk gekregen).
	if ok and ns.ScheduleBagCheck then ns.ScheduleBagCheck(0.5) end
end

local function Again(delay) C_Timer.After(delay or 0.3, function() if job then Step() end end) end

Step = function()
	local j = job
	if not j then return end
	j.steps = j.steps + 1
	if j.steps > 200 then -- grote volle tas = veel verplaatsingen; dit is alleen een noodrem return Finish(false, T("Not enough room to swap bags.")) end
	if InCombatLockdown() then return Finish(false, T("Bag swap stopped: you entered combat.")) end
	if CursorHasItem() then return Again() end -- jij hebt iets vast: even wachten
	local s = SlotInfo(j.c)
	if j.put and s.itemID == j.itemID then
		local msg = j.old and T("Swapped %s for %s."):format(ItemName(j.itemID, j.link), ItemName(j.old, j.oldLink))
			or T("Equipped %s."):format(ItemName(j.itemID, j.link))
		return Finish(true, msg)
	end
	local bag, slot = FindBag(j)
	if not bag then return Finish(false, j.put and T("Not enough room to swap bags.") or nil) end
	j.bag, j.slot = bag, slot
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if info and info.isLocked then return Again() end
	if j.put then return Finish(false, T("Not enough room to swap bags.")) end -- WoW wilde niet

	-- 1. De nieuwe tas zit in de tas die eruit moet: eerst daar weg.
	if bag == j.c then
		local fb, fs = FreeOutside(j.c)
		if not fb then fb, fs = SwapPartner(j.c) end
		if not fb then return Finish(false, T("Not enough room to swap bags.")) end
		Log("bag swap: move the new bag out of bag " .. j.c)
		Move(bag, slot, fb, fs)
		return Again()
	end

	-- 2. Inhoud van de oude tas naar vrije vakjes elders, zolang er plek is.
	if s.itemID then
		local inside = ItemsIn(j.c)
		if #inside > 0 then
			for _, it in ipairs(inside) do if it.locked then return Again() end end
			local fb, fs = FreeOutside(j.c)
			if fb then
				Move(j.c, inside[1].slot, fb, fs)
				return Again()
			end
			-- Nergens meer plek: WoW neemt de rest mee naar de nieuwe tas, als die groot genoeg is.
			if j.kind ~= "normal" or (j.slots or 0) < #inside then
				return Finish(false, T("Not enough room to swap bags."))
			end
		end
	end

	-- 3. Wisselen. De oude tas komt op de plek waar de nieuwe lag.
	j.old, j.oldLink = s.itemID, s.link
	Log("bag swap: " .. j.itemID .. " -> bag slot " .. j.c .. (s.itemID and (" (was " .. s.itemID .. ")") or ""))
	C_Container.PickupContainerItem(bag, slot)
	local inv = s.inv or InvID(j.c)
	if PutItemInBag and inv then pcall(PutItemInBag, inv) end
	if CursorHasItem() then ClearCursor() end -- niet gelukt: terug naar zijn vakje
	j.put = true
	Again(0.4)
end

local function StartJob(e, target)
	if job or target.itemID == e.itemID then return end -- dezelfde soort tas: niets te winnen
	job = { itemID = e.itemID, link = e.link, bag = e.bag, slot = e.slot, kind = e.kind, slots = e.slots,
		c = target.c, steps = 0 }
	Log("bag swap start: " .. e.itemID .. " (" .. tostring(e.slots) .. " slots) -> bag slot " .. target.c)
	Step()
end

function ns.BagSwapBusy() return job ~= nil end

---------------------------------------------------------------------------
-- Welke tas, welk vak?
---------------------------------------------------------------------------

-- Een tas in je tassen als kandidaat: { bag, slot, itemID, link, kind, slots, rank }
local function Candidate(e)
	local kind, bind = KindOf(e.itemID)
	if not kind or kind == "keep" then return nil end
	local slots = BagItemSlots(e.bag, e.slot, e.itemID)
	if not slots then return nil end
	return { bag = e.bag, slot = e.slot, itemID = e.itemID, link = e.link, kind = kind, slots = slots,
		rank = Rank(bind, e.bound), entry = e }
end

-- Voor rechtsklik/slepen: in welk vak gaat deze tas? Eerst een verhandelbare tas met
-- hetzelfde aantal vakjes, anders de minst goede tas.
local function ManualTarget(cand)
	local slotType = cand.kind == "reagent" and "reagent" or "normal"
	local best, bestScore, same
	for _, s in ipairs(BagSlots()) do
		if s.slotType == slotType and s.kind ~= "keep" then
			if not s.itemID then return s, true end -- leeg vak
			-- verhandelbare tas met evenveel vakjes eruit, maar alleen als de nieuwe beter bindt
			-- (geen zinloze wissel met precies dezelfde soort tas)
			if s.slots == cand.slots and s.rank == 2 and cand.rank > s.rank and s.kind == cand.kind and not same then same = s end
			local sc = Score(s.kind, s.slots, s.rank, slotType) or 0
			if not best or sc < bestScore then best, bestScore = s, sc end
		end
	end
	return same or best, false
end

-- Is dit een stap terug? Dan eerst vragen.
local function Downgrade(cand, s)
	if not s.itemID then return nil end
	if s.kind == "normal" and cand.kind == "prof" then
		return T("Replace %s with the profession bag %s? Only items for that profession fit in it."):format(
			ItemName(s.itemID, s.link), ItemName(cand.itemID, cand.link))
	end
	if cand.slots < s.slots then
		return T("Replace %s (%d slots) with %s (%d slots)? You lose %d bag slots."):format(
			ItemName(s.itemID, s.link), s.slots, ItemName(cand.itemID, cand.link), cand.slots, s.slots - cand.slots)
	end
end

local function AskOrStart(cand, s)
	local q = Downgrade(cand, s)
	if not q or not (StaticPopupDialogs and StaticPopup_Show) then return StartJob(cand, s) end
	StaticPopupDialogs["CAREFREEBAG_BAGDOWN"] = {
		text = "%s",
		button1 = T("Swap"),
		button2 = T("No"),
		OnAccept = function() StartJob(cand, s) end,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	StaticPopup_Show("CAREFREEBAG_BAGDOWN", q)
end

-- Vendor, bank, post, handel, AH: daar doet een rechtsklik iets anders (verkopen, verplaatsen).
local function SomethingOpen()
	for _, f in ipairs({ MerchantFrame, MailFrame, BankFrame, TradeFrame, AuctionFrame, AuctionHouseFrame, GuildBankFrame }) do
		if f and f.IsShown and f:IsShown() then return true end
	end
	return ns.bankOpen or (ns.mail and ns.mail.busy) or false
end

local function Modified()
	return (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown())
		or (IsAltKeyDown and IsAltKeyDown())
end

-- Rechtsklik op een tas in het CarefreeBag-venster. true = wij regelen het.
-- Is er een leeg vak, dan doet WoW het zelf al goed (de tas gaat in het lege vak).
function ns.BagRightClick(bag, slot)
	if not ns.DB.enabled or job or InCombatLockdown() or Modified() or SomethingOpen() then return false end
	local info = bag and slot and C_Container.GetContainerItemInfo(bag, slot)
	if not info or not info.itemID then return false end
	local e = { bag = bag, slot = slot, itemID = info.itemID, link = info.hyperlink, bound = info.isBound }
	local cand = Candidate(e)
	if not cand then return false end
	local s, empty = ManualTarget(cand)
	if not s or empty then return false end
	if s.itemID == cand.itemID and cand.rank <= s.rank then return false end -- zelfde tas: niets te winnen
	-- Even wachten tot WoW zijn eigen klik heeft afgehandeld.
	C_Timer.After(0.1, function() if not job then AskOrStart(cand, s) end end)
	return true
end

---------------------------------------------------------------------------
-- Slepen op een tasvak van Blizzard, terwijl de tas in die tas zelf zit
---------------------------------------------------------------------------

-- Welk vakje in je tassen staat op slot voor het item op de cursor?
local function CursorSource()
	local kind, id = GetCursorInfo()
	if kind ~= "item" or not id then return nil end
	for _, e in ipairs(Scan()) do
		if e.itemID == id and e.info and e.info.isLocked then return e end
	end
end

local function OnBagSlotDrop(c)
	if not ns.DB.enabled or job or InCombatLockdown() or not CursorHasItem() then return end
	local e = CursorSource()
	if not e or e.bag ~= c then return end -- gewone gevallen doet WoW zelf
	local cand = Candidate(e)
	if not cand then return end
	local s = SlotInfo(c)
	if (cand.kind == "reagent") ~= (s.slotType == "reagent") then return end
	ClearCursor()
	Log("bag dropped on its own bag slot " .. c .. ": swap via CarefreeBag")
	AskOrStart(cand, s)
end

local function HookBagSlots()
	local frames = {}
	for i = 0, NUM_BAGS - 1 do frames[#frames + 1] = { _G["CharacterBag" .. i .. "Slot"], i + 1 } end
	if REAGENT_BAG then frames[#frames + 1] = { _G["CharacterReagentBag0Slot"], REAGENT_BAG } end
	for _, fc in ipairs(frames) do
		local f, c = fc[1], fc[2]
		if f and f.HookScript then
			pcall(f.HookScript, f, "OnReceiveDrag", function() OnBagSlotDrop(c) end)
			pcall(f.HookScript, f, "OnClick", function() OnBagSlotDrop(c) end)
		end
	end
end

---------------------------------------------------------------------------
-- Automatisch de beste tassen aandoen
---------------------------------------------------------------------------

-- Een tasvak dat jij zelf leeg hebt gemaakt, vullen we niet vanzelf (tot er weer een tas in zit).
-- Wisselen voor een betere tas mag daar wel gewoon.
local lastEquipped, emptiedByYou = nil, {}

function ns.RememberBags()
	lastEquipped = {}
	for _, s in ipairs(BagSlots()) do lastEquipped[s.c] = s.itemID or false end
end

local function NoticeRemoved()
	if not lastEquipped then return ns.RememberBags() end
	for _, s in ipairs(BagSlots()) do
		if s.itemID then
			emptiedByYou[s.c] = nil
		elseif lastEquipped[s.c] and not emptiedByYou[s.c] then
			emptiedByYou[s.c] = true
			Log("bag slot " .. s.c .. " emptied by you: not filled automatically")
		end
	end
	ns.RememberBags()
end

-- Tassen in een groep met post (naar een alt) of in Auto Sell: die wil je kwijt, niet aandoen.
local function MeantToGo(e)
	if ns.Hidden and ns.Hidden()[e.itemID] then return true end
	local key = ns.SectionOf and ns.SectionOf(e)
	if key == "grey" then return true end
	if key == "boe" then return (ns.DB.boeMail or "") ~= "" end
	local cat = key and ns.CatByKey and ns.CatByKey(key)
	return cat and (cat.mailTo or "") ~= "" or false
end

local function BestMove()
	local slots = BagSlots()
	local cands = {}
	for _, e in ipairs(Scan()) do
		if not e.key and not (e.info and e.info.isLocked) then
			local cand = Candidate(e)
			if cand and not MeantToGo(e) then cands[#cands + 1] = cand end
		end
	end
	local bestGain, bestCand, bestSlot
	for _, cand in ipairs(cands) do
		for _, s in ipairs(slots) do
			local new = Score(cand.kind, cand.slots, cand.rank, s.slotType)
			if new and s.kind ~= "keep" and s.itemID ~= cand.itemID and not (not s.itemID and emptiedByYou[s.c]) then
				local gain
				if not s.itemID then
					gain = 100000 + new -- leeg vak: altijd eerst
				elseif cand.kind ~= "prof" then -- een beroepstas vervangt nooit vanzelf een andere tas
					local cur = Score(s.kind, s.slots, s.rank, s.slotType) or 0
					if new > cur then gain = new - cur end
				end
				if gain and (not bestGain or gain > bestGain) then bestGain, bestCand, bestSlot = gain, cand, s end
			end
		end
	end
	return bestCand, bestSlot
end

local checkPending = false
function ns.ScheduleBagCheck(delay)
	if checkPending then return end
	checkPending = true
	C_Timer.After(delay or 0.5, function()
		checkPending = false
		local ok, err = pcall(ns.BagCheck)
		if not ok then ns.DB.lastError = "bags: " .. tostring(err); Log("bag check error: " .. tostring(err)) end
	end)
end

-- Waarom er (nog) niet gewisseld wordt; alleen in de log als het verandert.
local lastWait
local function Wait(reason)
	if reason ~= lastWait and reason then Log("bag check waits: " .. reason) end
	lastWait = reason
end

function ns.BagCheck()
	if job then return Wait("swap busy") end
	NoticeRemoved()
	if not ns.DB.enabled or not ns.DB.autoBags then return end
	-- Vendor/bank/mailbox open mag: wij verplaatsen alleen (geen rechtsklik). Wel wachten als
	-- CarefreeBag zelf aan het mailen of verkopen is.
	if InCombatLockdown() then return Wait("combat") end
	if CursorHasItem() then return Wait("item on cursor") end
	if ns.mail and ns.mail.busy then return Wait("mailing") end
	if ns.SellBusy and ns.SellBusy() then return Wait("selling") end
	if GetNumLootItems and (GetNumLootItems() or 0) > 0 then return Wait("loot window") end
	Wait(nil)
	local cand, s = BestMove()
	if cand then StartJob(cand, s) end
end

function ns.SetupBagSwap()
	HookBagSlots()
	ns.RememberBags()
end
