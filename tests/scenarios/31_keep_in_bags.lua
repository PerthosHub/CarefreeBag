local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- "Keep N" (issues #22 + #24): Shift + muiswiel op een item = hoeveel je er altijd bij je houdt.
-- Vendor koopt bij tot N, bank vult aan tot N en neemt de rest, 0 = alles naar de bank,
-- "Running low" als je eronder zakt, en een lijstje bij het AH.
ITEMS = {
  [159] = { name = "Refreshing Spring Water", quality = 1, stack = 20, bind = 0, icon = 1, class = 0, sub = 5, price = 1 },
  [2318] = { name = "Light Leather", quality = 1, stack = 20, bind = 0, icon = 2, class = 7, price = 4 },
  [118] = { name = "Minor Healing Potion", quality = 1, stack = 5, bind = 0, icon = 3, class = 0, sub = 1, price = 5 },
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, class = 7, price = 2 },
  [6948] = { name = "Hearthstone", quality = 1, stack = 1, bind = 1, icon = 5 },
}
BANK_CONTAINER = -1
BAGS[0] = { n = 16, [1] = { itemID = 159, count = 12 }, [2] = { itemID = 2318, count = 20 }, [3] = { itemID = 2318, count = 15 },
  [4] = { itemID = 118, count = 2 }, [5] = { itemID = 2589, count = 7 }, [6] = { itemID = 6948, count = 1, bound = true } }
BAGS[-1] = { n = 8, [1] = { itemID = 118, count = 4 } }
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
CarefreeBagDB = { lang = "en", autoBags = false, autoSellAsked = true, autoSell = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
local function Tile(id) for _, f in ipairs(ALLFRAMES) do if f.isCarefreeItem and f.shown and f.group and f.group.itemID == id then return f end end end
local function Chat(pat) for i = #LOG, 1, -1 do if LOG[i]:find("CHAT") and LOG[i]:find(pat, 1, true) then return LOG[i] end end end
local function total(b, id) local n = 0; for s = 1, BAGS[b].n do local it = BAGS[b][s]; if it and it.itemID == id then n = n + it.count end end; return n end
local function Wheel(tile, delta, times)
  function GetMouseFocus() return tile end
  for _ = 1, times or 1 do CarefreeBagFrame.scroll:Fire("OnMouseWheel", delta) end
end

-- 1. Tooltip zonder instelling: uitleg alleen bij stapelbare items
local lines = {}
local tt = { AddLine = function(_, l) lines[#lines + 1] = l end }
NS.StockLine(tt, Tile(159).group)
check(lines[1] and lines[1]:find("Shift + mouse wheel", 1, true), "tooltip water: uitleg Shift + muiswiel")
lines = {}; NS.StockLine(tt, Tile(6948).group)
check(#lines == 0, "hearthstone (niet stapelbaar): geen uitleg")

-- 2. Muiswiel zonder Shift scrollt gewoon; met Shift: 1, 2, 3, 4, 5, 10, 15, 20
SHIFT = false; Wheel(Tile(159), 1)
check(CFC().stock == nil or CFC().stock[159] == nil, "zonder Shift: niets ingesteld")
SHIFT = true; Wheel(Tile(159), 1, 8); SHIFT = false
check(CFC().stock[159] == 20, "Shift + 8× omhoog: 20 water (" .. tostring(CFC().stock[159]) .. ")")
check(Tile(159).stockText and Tile(159).stockText.text == "20" and Tile(159).stockText.shown, "getal 20 op het vakje")
lines = {}; NS.StockLine(tt, Tile(159).group)
check(lines[1]:find("Keep 20 in your bags (now 12)", 1, true), "tooltip: Keep 20 (now 12): " .. tostring(lines[1]))
check(NS.StockNext(20, false) == 15 and NS.StockNext(1, false) == 0 and NS.StockNext(0, false) == nil and NS.StockNext(nil, true) == 1
  and NS.StockNext(7, true) == 10 and NS.StockNext(7, false) == 5, "stappen omhoog/omlaag (1 → 0 = naar de bank → uit)")

-- 3. Vendor: water bijkopen tot 20 (8 stuks)
BOUGHT = {}
MERCHANT = { { id = 159, price = 25, qty = 1 }, { id = 2589, price = 10, qty = 1 } }
function GetMerchantNumItems() return #MERCHANT end
function GetMerchantItemID(i) return MERCHANT[i].id end
function GetMerchantItemInfo(i) local m = MERCHANT[i]; return ITEMS[m.id].name, 1, m.price, m.qty, -1, true, true, nil end
function GetMerchantItemMaxStack() return 20 end
function BuyMerchantItem(i, n)
  n = n or MERCHANT[i].qty; BOUGHT[#BOUGHT + 1] = { id = MERCHANT[i].id, n = n }
  for s = 1, BAGS[0].n do if not BAGS[0][s] then BAGS[0][s] = { itemID = MERCHANT[i].id, count = n }; break end end
end
MerchantFrame.shown = true; E("MERCHANT_SHOW"); RunTimers()
check(#BOUGHT == 1 and BOUGHT[1].id == 159 and BOUGHT[1].n == 8, "vendor: 8 water gekocht (12 → 20)")
check(Chat("Bought Refreshing Spring Water x8 for 200c (you keep 20)"), "chatregel met aantal en prijs")
check(total(0, 159) == 20, "nu 20 water")
E("MERCHANT_SHOW"); RunTimers()
check(#BOUGHT == 1, "nog eens open: niets meer kopen")
MerchantFrame.shown = false; E("MERCHANT_CLOSED")

-- 4. Bank: leer houden op 10 (35 → 10, 25 naar de bank), potions aanvullen tot 5 (2 + 3 uit de bank)
CFC().stock[2318] = 10; CFC().stock[118] = 5
NOW = NOW + 10
E("BANKFRAME_OPENED"); for _ = 1, 30 do RunTimers() end
check(total(0, 2318) == 10 and total(-1, 2318) == 25, "bank: 10 leer in de tassen, 25 in de bank (" .. total(0, 2318) .. "/" .. total(-1, 2318) .. ")")
check(total(0, 118) == 5 and total(-1, 118) == 1, "bank: potions aangevuld tot 5, 1 blijft in de bank")
check(total(0, 159) == 20 and total(0, 2589) == 7, "items zonder (of met voldoende) instelling blijven staan")
check(CURSOR == nil, "niets aan de muis")
check(Chat("To the bank: Light Leather x25") and Chat("From the bank: Minor Healing Potion x3"), "chatregels bank")
E("BANKFRAME_CLOSED")

-- 5. 0 = alles naar de bank (#24): Shift + omlaag vanaf 1
SHIFT = true; Wheel(Tile(2589), 1); Wheel(Tile(2589), -1); SHIFT = false
check(CFC().stock[2589] == 0 and Tile(2589).stockText.text == "0", "1 → 0: linnen helemaal naar de bank")
E("BANKFRAME_OPENED"); for _ = 1, 30 do RunTimers() end
check(total(0, 2589) == 0 and total(-1, 2589) == 7, "bank: al het linnen in de bank")
E("BANKFRAME_CLOSED")

-- 6. Running low: van 5 naar 4 potions
E("BAG_UPDATE_DELAYED")
for s = 1, BAGS[0].n do local it = BAGS[0][s]; if it and it.itemID == 118 then it.count = it.count - 1; break end end
E("BAG_UPDATE_DELAYED")
check(Chat("Running low: Minor Healing Potion 4/5"), "onder de 5: chatregel Running low")
check(Tile(118).stockText.text == "5", "getal blijft 5 (oranje: te weinig)")

-- 7. AH: lijstje met wat je tekort komt
E("AUCTION_HOUSE_SHOW")
check(Chat("Low on: Minor Healing Potion 4/5"), "AH: lijstje met tekort")

-- 8. Uitzetten: omlaag tot uit
SHIFT = true; Wheel(Tile(118), -1, 30); SHIFT = false
check(CFC().stock[118] == nil and not Tile(118).stockText.shown, "helemaal omlaag: uit, geen getal meer")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
