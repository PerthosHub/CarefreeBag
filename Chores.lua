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
	if stack.burst >= 40 then return false end -- veiligheidsrem
	local items = Scan()
	local by = {}
	for _, e in ipairs(items) do
		if e.stackKnown and not e.key and e.maxStack > 1 and e.count < e.maxStack and not e.info.isLocked then
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
		if not ok then ns.DB.lastError = "restack: " .. tostring(err); Log("restack error: " .. tostring(err)) end
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

ns.SellStart = function(confirmed)
	if sell.busy or not ns.DB.enabled then return end
	if not confirmed and ns.DB.autoSellAsked and not ns.DB.autoSell then return end
	if not On("grey") then return end
	if IsShiftKeyDown and IsShiftKeyDown() then Print(T("Auto Sell skipped (Shift).")); return end
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
