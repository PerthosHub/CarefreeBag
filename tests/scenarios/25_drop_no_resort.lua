-- Een item naar een groep slepen sorteert die groep niet meteen opnieuw (Johan, 2026-11-21):
-- het item komt achteraan, de rest blijft staan. Pas bij het weer openen wordt er gesorteerd.
local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
ITEMS = {
  [8000] = { name = "Broken Fang", quality = 0, stack = 10, bind = 0, icon = 1, price = 50 },
  [8001] = { name = "Torn Cloak", quality = 0, stack = 1, bind = 0, icon = 2, price = 5 },
  [3000] = { name = "Shiny Ring", quality = 1, stack = 1, bind = 0, icon = 3, price = 500 },
}
BAGS[0] = { n = 8, [1] = { itemID = 8000, count = 1 }, [2] = { itemID = 8001, count = 1 }, [3] = { itemID = 3000, count = 1 } }

local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
CarefreeBagDB = { lang = "en", autoSell = true, autoSellAsked = true }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
local function plus(key) for _, f in ipairs(ALLFRAMES) do if f.section == key and f:IsShown() then return f end end end
local function order(key) return table.concat(NS.shownOrder[key] or {}, ",") end
local function open() SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED") end

open()
check(CarefreeBagFrame:IsShown(), "tassen open")
check(order("grey") == "8000,8001", "Auto Sell op prijs: " .. order("grey"))

-- duur item naar Auto Sell: achteraan, niet vooraan
CURSOR = { itemID = 3000 }; plus("grey"):Fire("OnReceiveDrag"); RunTimers()
check(order("grey") == "8000,8001,3000", "losgelaten item komt achteraan, de rest blijft staan: " .. order("grey"))
E("BAG_UPDATE_DELAYED")
check(order("grey") == "8000,8001,3000", "ook na een tas-update niet opnieuw gesorteerd: " .. order("grey"))

-- eruit en weer terug: ook dan achteraan (niet op zijn oude plek)
CURSOR = { itemID = 8000 }; plus("other"):Fire("OnReceiveDrag"); RunTimers()
check(order("grey") == "8001,3000", "weggesleept item valt weg, de rest schuift op: " .. order("grey"))
CURSOR = { itemID = 8000 }; plus("grey"):Fire("OnReceiveDrag"); RunTimers()
check(order("grey") == "8001,3000,8000", "terug = weer achteraan: " .. order("grey"))

-- dicht en weer open: nu netjes op prijs
CarefreeBagFrame:Hide(); RunTimers()
open()
check(order("grey") == "3000,8000,8001", "na opnieuw openen op prijs gesorteerd: " .. order("grey"))
