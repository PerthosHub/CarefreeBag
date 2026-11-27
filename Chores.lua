-- CarefreeBag: Chores.lua
-- Klusjes: stapels samenvoegen en Auto Sell bij de vendor.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Log, On, Print, Scan, SectionOf, T = ns.Log, ns.On, ns.Print, ns.Scan, ns.SectionOf, ns.T

---------------------------------------------------------------------------
-- Stapels op de achtergrond samenvoegen (echt, in de tassen)
---------------------------------------------------------------------------

-- Eén verplaatsing per keer: pak de kleinste losse stapel op en laat hem vallen
-- op de grootste niet-volle stapel van hetzelfde item. Daarna wachten we tot de
-- game klaar is (BAG_UPDATE_DELAYED) en doen we de volgende.
local stack = { moves = 0, burst = 0, scheduled = false }
local sell -- vooruit (auto sell)

local function RestackStep()
	if not ns.DB.enabled or InCombatLockdown() or CursorHasItem() then return false end
	if ns.mail and ns.mail.busy then return false end
	if sell and sell.busy then return false end
	if ns.BagSwapBusy and ns.BagSwapBusy() then return false end -- tassen worden gewisseld
	-- Mailbox, handel, bank of AH open: niet samenvoegen, anders gaat een stapel die je net
	-- met Shift hebt gesplitst meteen weer terug. Na het sluiten voegen we weer samen.
	-- (op naam: een frame dat in deze WoW-versie niet bestaat, is nil en zou ipairs stoppen)
	for _, name in ipairs({ "TradeFrame", "AuctionFrame", "AuctionHouseFrame", "GuildBankFrame" }) do
		local f = _G[name]
		if f and f.IsShown and f:IsShown() then
			C_Timer.After(2, ns.ScheduleRestack) -- geen sluit-event voor allemaal: straks opnieuw kijken
			return false
		end
	end
	if ns.bankOpen or ns.mailOpen then return false end -- MAIL_CLOSED/BANKFRAME_CLOSED starten het weer
	if stack.burst >= 40 then return false end -- veiligheidsrem
	local items = Scan()
	local by = {}
	local split = ns.splitKeep or {} -- zelf gesplitst (BagWindow.lua): laten staan tot de tas dicht is
	for _, e in ipairs(items) do
		if e.stackKnown and not e.key and e.maxStack > 1 and e.count < e.maxStack and not e.info.isLocked
			and not split[e.itemID] then
			by[e.itemID] = by[e.itemID] or {}
			table.insert(by[e.itemID], e)
		end
	end
	for _, list in pairs(by) do
		if #list >= 2 then
			table.sort(list, function(a, b) return a.count < b.count end)
			local src, dst = list[1], list[#list]
			C_Container.PickupContainerItem(src.bag, src.slot)
			C_Container.PickupContainerItem(dst.bag, dst.slot)
			if CursorHasItem() then C_Container.PickupContainerItem(src.bag, src.slot) end -- rest terug
			stack.moves = stack.moves + 1
			stack.burst = stack.burst + 1
			return true
		end
	end
	if stack.burst > 0 then
		Log("restacked: " .. stack.burst .. " move(s)")
		stack.burst = 0
	end
	return false
end

function ns.ScheduleRestack()
	if stack.scheduled or not ns.DB.enabled then return end
	stack.scheduled = true
	C_Timer.After(0.3, function()
		stack.scheduled = false
		local ok, err = pcall(RestackStep)
		if not ok then ns.SetError("restack: " .. tostring(err)) end
	end)
end

---------------------------------------------------------------------------
-- Auto Sell bij de vendor
---------------------------------------------------------------------------

sell = { busy = false, queue = nil, n = 0, value = 0 }

function ns.SellStop(reason)
	if not sell.busy then return end
	sell.busy = false
	sell.queue = nil
	if sell.n > 0 then
		local money = GetMoneyString and GetMoneyString(sell.value, true) or tostring(sell.value)
		Print(T("Auto Sell: sold %d item(s) for %s."):format(sell.n, money) .. (sell.n > 12 and T(" Note: Buyback only keeps the last 12.") or ""))
		Log("auto sell: " .. sell.n .. " item(s), " .. sell.value .. " copper" .. (reason and (" (" .. reason .. ")") or ""))
		if ns.StatsCount then ns.StatsCount("sl"); ns.StatsCount("sg", sell.value) end -- gebruiksstatistieken (Stats.lua)
	end
	ns.Refresh()
end

local function SellNext()
	if not sell.busy then return end
	if not (MerchantFrame and MerchantFrame:IsShown()) then ns.SellStop("vendor closed"); return end
	local it = table.remove(sell.queue, 1)
	if not it then ns.SellStop(); return end
	local info = C_Container.GetContainerItemInfo(it.bag, it.slot)
	if info and info.itemID == it.itemID and not info.isLocked then
		C_Container.UseContainerItem(it.bag, it.slot)
		sell.n = sell.n + 1
		sell.value = sell.value + it.value
	end
	C_Timer.After(0.15, SellNext)
end


-- Eerste keer bij een vendor (nieuwe gebruikers): vragen of Auto Sell aan moet.
local function AskAutoSell()
	if not StaticPopupDialogs or not StaticPopup_Show then return end
	StaticPopupDialogs["CAREFREEBAG_AUTOSELL"] = {
		text = T("CarefreeBag: automatically sell everything in the Auto Sell group whenever you open a vendor?\n\nYou can change this later in the options."),
		button1 = T("Yes, sell"),
		button2 = T("No"),
		OnAccept = function()
			ns.DB.autoSell, ns.DB.autoSellAsked = true, true
			Log("auto sell turned on (first vendor)")
			ns.SellStart(true)
			ns.Refresh()
		end,
		OnCancel = function(_, _, reason)
			if reason == "clicked" then
				ns.DB.autoSell, ns.DB.autoSellAsked = false, true
				Log("auto sell turned off (first vendor)")
				ns.Refresh()
			end
		end,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	StaticPopup_Show("CAREFREEBAG_AUTOSELL")
end

function ns.SellBusy() return sell.busy end

ns.SellStart = function(confirmed)
	if sell.busy or not ns.DB.enabled then return end
	if not confirmed and ns.DB.autoSellAsked and not ns.DB.autoSell then return end
	if not On("grey") then return end
	local items = Scan()
	local q = {}
	for _, e in ipairs(items) do
		if SectionOf(e) == "grey" and not e.info.hasNoValue and (e.price or 0) > 0 then
			q[#q + 1] = { bag = e.bag, slot = e.slot, itemID = e.itemID, value = e.price * e.count }
		end
	end
	if #q == 0 then return end
	if not confirmed and not ns.DB.autoSellAsked then AskAutoSell(); return end
	sell.busy, sell.queue, sell.n, sell.value = true, q, 0, 0
	C_Timer.After(0.2, SellNext)
end

---------------------------------------------------------------------------
-- Clams automatisch openen (na het looten)
---------------------------------------------------------------------------

-- Bekende clams (Classic t/m Cataclysm); daarnaast elk item met "Clam" in de naam dat
-- je kunt openen (hasLoot). Clam meat is niet te openen en valt daar dus buiten.
local CLAMS = { [5523] = true, [5524] = true, [7973] = true, [24476] = true, [36781] = true,
	[44700] = true, [45909] = true, [52340] = true }

local function IsClam(e)
	if not (e.info and e.info.hasLoot) then return false end
	return CLAMS[e.itemID] or ((e.name or ""):find("Clam") ~= nil)
end

-- "Gebruiken" verkoopt bij een vendor en verplaatst bij bank/mail/handel: dan niet.
local function SomethingOpen()
	for _, name in ipairs({ "MerchantFrame", "MailFrame", "BankFrame", "TradeFrame", "AuctionFrame", "AuctionHouseFrame", "GuildBankFrame" }) do
		local f = _G[name]
		if f and f.IsShown and f:IsShown() then return true end
	end
	return ns.bankOpen or (ns.mail and ns.mail.busy) or false
end

local openPending = false
local clamTry -- { id, t }: laatste poging, om te zien wat WoW daarna deed (belangrijke momenten)
local clamWait -- laatste reden van wachten (één keer noteren, niet bij elke tasupdate)
local lastTryTime -- wanneer CFB het laatst een clam probeerde (ook na het resultaat)
-- Pogingen per vakje: zelfde clam, zelfde vakje, zelfde aantal = niet gelukt. Na 2 keer
-- overslaan tot /reload (Johans log 27-11: 7× dezelfde clam op 3:4, die bleef liggen).
local tries, MAX_TRIES = {}, 2
local function TryKey(e) return e.bag .. ":" .. e.slot .. ":" .. e.itemID .. ":" .. (e.count or 1) end

-- Probeerde CFB net een clam? (Start.lua: welke blokkade bij welke actie hoort)
function ns.ClamTriedRecently() return lastTryTime ~= nil and GetTime() - lastTryTime < 5 end

-- Vakjes die niet meer dezelfde clam bevatten: vergeten (die is open gegaan).
local function PruneTries()
	for key in pairs(tries) do
		local bag, slot, id, n = key:match("^(-?%d+):(%d+):(%d+):(%d+)$")
		local info = bag and C_Container.GetContainerItemInfo(tonumber(bag), tonumber(slot))
		if not (info and info.itemID == tonumber(id) and (info.stackCount or 1) == tonumber(n)) then tries[key] = nil end
	end
end

local function FreeSlots()
	local _, free = Scan()
	local n = 0
	for _, f in ipairs(free) do if not f.reagent then n = n + 1 end end
	return n
end

function ns.OpenClams()
	if not ns.DB.enabled or not ns.DB.autoOpenClams or ns.clamBlocked or openPending then return end
	PruneTries()
	local clam
	for _, e in ipairs(Scan()) do
		if IsClam(e) and not e.info.isLocked then
			local n = tries[TryKey(e)] or 0
			if n < MAX_TRIES then clam = e; break end
			if n == MAX_TRIES then
				tries[TryKey(e)] = n + 1 -- één keer noteren
				ns.Note("clam", ("%s at %d:%d did not open after %d tries: skipped until /reload"):format(tostring(e.itemID), e.bag, e.slot, n))
			end
		end
	end
	if not clam then clamWait = nil; return end
	local why = (InCombatLockdown() and "combat") or (CursorHasItem() and "item on cursor") or (SomethingOpen() and "vendor/bank/mail open")
		or (ns.BagSwapBusy and ns.BagSwapBusy() and "bag swap") or (GetNumLootItems and (GetNumLootItems() or 0) > 0 and "loot window")
	if why then
		if clamWait ~= why then ns.Note("clam", clam.itemID .. " waits: " .. why); clamWait = why end
		return
	end
	clamWait = nil
	local e = clam
	openPending = true
	-- even wachten: net geloot, de tas moet eerst bijgewerkt zijn
	C_Timer.After(0.3, function()
		openPending = false
		if InCombatLockdown() or CursorHasItem() or SomethingOpen() then return end
		local info = C_Container.GetContainerItemInfo(e.bag, e.slot)
		if not info or info.itemID ~= e.itemID or info.isLocked then return end
		ns.Note("clam", ("open %s at %d:%d, free slots %d"):format(tostring(e.itemID), e.bag, e.slot, FreeSlots()))
		clamTry = { id = e.itemID, t = GetTime() }
		lastTryTime = clamTry.t
		local key = e.bag .. ":" .. e.slot .. ":" .. e.itemID .. ":" .. (info.stackCount or 1)
		tries[key] = (tries[key] or 0) + 1
		pcall(C_Container.UseContainerItem, e.bag, e.slot)
	end)
	-- één tegelijk; de volgende na het looten van deze
end

-- Wat deed WoW na een poging? (lootvenster = gelukt; foutmelding = welke)
local function RecentTry() return clamTry and GetTime() - clamTry.t < 3 end
ns.OnEvent("LOOT_OPENED", "clam result", function()
	if RecentTry() then ns.Note("clam", clamTry.id .. " opened (loot window)"); clamTry = nil end
end)
ns.OnEvent("UI_ERROR_MESSAGE", "clam result", function(_, _, msg)
	if RecentTry() then ns.Note("clam", clamTry.id .. " WoW says: " .. tostring(msg)); clamTry = nil end
end)

---------------------------------------------------------------------------
-- Events: samenvoegen, Auto Sell en clams
---------------------------------------------------------------------------

-- Samenvoegen wacht zolang bank, mailbox of een gevecht bezig is; daarna alsnog.
for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_CLOSED", "MAIL_CLOSED", "PLAYER_REGEN_ENABLED" }) do
	ns.OnEvent(ev, "restack", function() ns.ScheduleRestack() end)
end
ns.OnEvent("MERCHANT_SHOW", "auto sell", function() ns.SellStart() end)
ns.OnEvent("MERCHANT_CLOSED", "auto sell", function() ns.SellStop("vendor closed") end)
ns.OnEvent("BAG_UPDATE_DELAYED", "clams", function() ns.OpenClams() end)
ns.OnEvent("LOOT_CLOSED", "clams", function()
	C_Timer.After(0.5, function() ns.Try("clams", ns.OpenClams) end)
end)
-- WoW staat automatisch openen hier niet toe: stoppen (tot /reload) en één keer melden.
-- Alleen als CFB vlak daarvoor zelf een clam probeerde: anders was het iets anders (bijv. je
-- eigen rechtsklik op een item) en zou die blokkade de clams onterecht stilleggen (Johans log 27-11).
local function ClamBlocked(_, addon, what)
	if addon ~= ADDON or ns.clamBlocked or not tostring(what):find("UseContainerItem") then return end
	if not ns.ClamTriedRecently() then return end
	ns.clamBlocked = true
	ns.Note("clam", "blocked by WoW, free slots " .. FreeSlots() .. ": no more automatic opening until /reload")
	Print(T("WoW does not allow opening clams automatically here. Open them yourself with a right-click."))
end
ns.OnEvent("ADDON_ACTION_BLOCKED", "clams", ClamBlocked)
ns.OnEvent("ADDON_ACTION_FORBIDDEN", "clams", ClamBlocked)
