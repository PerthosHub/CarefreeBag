local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Retail/Forever: een reagent-tas (5e tasvak) met vrije vakjes, maar de gewone tassen zijn vol.
Enum.BagIndex = { ReagentBag = 5 }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
ITEMS = {
  [8000] = { name = "Broken Fang", quality = 0, stack = 10, bind = 0, icon = 9, price = 5 },
  [8001] = { name = "Torn Wing", quality = 0, stack = 10, bind = 0, icon = 9, price = 50 },
  [9300] = { name = "Speckled Shell Fragment", quality = 0, stack = 10, bind = 0, icon = 9, price = 300 },
}
BAGS[0] = { n = 2, [1] = { itemID = 8000, count = 1 }, [2] = { itemID = 8001, count = 1 } }
BAGS[5] = { n = 2 } -- reagent-tas, leeg
LOADED_ADDONS = {}

LOOT = { { id = 9300, qty = 1 } }
function GetNumLootItems() return #LOOT end
function GetLootSlotType(i) return LOOT[i] and 1 or 0 end
function GetLootSlotLink(i) local l = LOOT[i]; if l and l.id then return "|cff|Hitem:" .. l.id .. "|h[" .. ITEMS[l.id].name .. "]|h|r" end end
function GetLootSlotInfo(i) local l = LOOT[i]; if l and l.id then local d = ITEMS[l.id]; return d.icon, d.name, l.qty, nil, d.quality, false, d.quest end end
function LootSlot(i) end
function DeleteCursorItem() CURSOR = nil end

local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()

local t = CarefreeBagFreeBar.text.text
check(t == "2/2", "grote balk: gewone tassen 2/2 vol: " .. t)
local rb = CarefreeBagReagentBar
check(rb and rb:IsShown() and rb.text.text == "0/2", "kleine reagent-balk: 0/2 gebruikt: " .. tostring(rb and rb.text.text))
check(rb.w >= 20 and rb.w <= 60, "kleine balk tussen 20 en 60 breed: " .. tostring(rb.w))
BAGS[5][1] = { itemID = 8000, count = 1 }; E("BAG_UPDATE_DELAYED"); RunTimers()
check(rb.text.text == "1/2", "reagent in de reagent-tas: kleine balk 1/2")
BAGS[5][1] = nil; E("BAG_UPDATE_DELAYED"); RunTimers()
check(CarefreeBagFreeBar.free == 0 and CarefreeBagFreeBar.rFree == 2, "tooltip: 0 gewone vakjes vrij, 2 in de reagent-tas")

E("LOOT_OPENED")
check(NS.lootPanel and NS.lootPanel:IsShown(), "vrije reagent-vakjes tellen niet: schelp past niet, paneel open")
check(NS.lootPanel.offer.junk.e.bag == 0, "voorgesteld item komt uit een gewone tas")
