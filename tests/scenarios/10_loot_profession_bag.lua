local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Tassen vol, met een beroepstas: een vak in de mijnbouwtas vrijmaken helpt niet voor gewone loot.
bit = bit or { band = function(a, b) local r, m = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + m end; a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2 end; return r end }
ITEMS = {
  [2771] = { name = "Tin Ore", quality = 1, stack = 20, bind = 0, icon = 4, price = 1, family = 1024 },  -- goedkoopst, maar in de mijnbouwtas
  [8000] = { name = "Broken Fang", quality = 0, stack = 10, bind = 0, icon = 9, price = 5 },
  [9300] = { name = "Speckled Shell Fragment", quality = 0, stack = 10, bind = 0, icon = 9, price = 300 },
}
BAGS[0] = { n = 1, [1] = { itemID = 8000, count = 1 } }
BAGS[1] = { n = 1, family = 1024, [1] = { itemID = 2771, count = 1 } } -- mijnbouwtas
LOADED_ADDONS = {}
function C_Container.GetContainerNumFreeSlots(b) return 0, (BAGS[b] and BAGS[b].family) or 0 end
C_Item.GetItemFamily = function(id) return ITEMS[id] and ITEMS[id].family or 0 end

LOOT = { { id = 9300, qty = 1 } }
function GetNumLootItems() return #LOOT end
function GetLootSlotType(i) return LOOT[i] and 1 or 0 end
function GetLootSlotLink(i) local l = LOOT[i]; if l and l.id then return "|cff|Hitem:" .. l.id .. "|h[" .. ITEMS[l.id].name .. "]|h|r" end end
function GetLootSlotInfo(i) local l = LOOT[i]; if l and l.id then local d = ITEMS[l.id]; return d.icon, d.name, l.qty, nil, d.quality, false, d.quest end end
LOOTED = {}
function LootSlot(i)
  local l = LOOT[i]; LOOTED[#LOOTED + 1] = l.id
  for s = 1, BAGS[0].n do if not BAGS[0][s] then BAGS[0][s] = { itemID = l.id, count = l.qty }; break end end
  LOOT[i] = {}
end
DELETED = {}
function DeleteCursorItem() DELETED[#DELETED + 1] = CURSOR and CURSOR.itemID; CURSOR = nil end

local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()

E("LOOT_OPENED")
local P = NS.lootPanel
check(P and P:IsShown(), "tassen vol: paneel open")
check(P.offer.junk.e.itemID == 8000, "Tin Ore (mijnbouwtas) niet voorgesteld, Broken Fang wel")
P.swap:Fire("OnClick"); RunTimers()
check(DELETED[1] == 8000 and LOOTED[1] == 9300, "Broken Fang weg, schelp opgepakt")
check(BAGS[1][1].itemID == 2771, "Tin Ore ligt nog in de mijnbouwtas")
