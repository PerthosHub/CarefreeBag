local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Een tas uit de tassenbalk in het CarefreeBag-venster laten vallen (BagSwap.lua, ns.BagUnequip):
-- niet leeg = eerst leeghalen, dan uitdoen. Te weinig plek = melding, niets verplaatst.
-- Een lege tas mag niet in zichzelf belanden.

EQUIP = {}
CONTAINER_SLOTS = "%d Slot %s"
function C_Container.ContainerIDToInventoryID(c) return 30 + c end
function GetInventoryItemID(_, inv) return EQUIP[inv - 30] end
function GetInventoryItemLink(_, inv) local id = EQUIP[inv - 30]; return id and ("|cff|Hitem:" .. id .. "|h[" .. ITEMS[id].name .. "]|h|r") end
local origNum = C_Container.GetContainerNumSlots
function C_Container.GetContainerNumSlots(b) if b > 0 and not EQUIP[b] then return 0 end return origNum(b) end
local origInfo = C_Container.GetContainerItemInfo
function C_Container.GetContainerItemInfo(b, s) if b > 0 and not EQUIP[b] then return nil end return origInfo(b, s) end
-- tas uit het tasvak oppakken
local locked
function IsInventoryItemLocked(inv) return locked == inv end
function PickupBagFromSlot(inv)
  local c = inv - 30
  if CURSOR or not EQUIP[c] then return end
  CURSOR, locked, CURSOR_BAG = { itemID = EQUIP[c], count = 1 }, inv, c
end
local origClear = ClearCursor
function ClearCursor() locked, CURSOR_BAG = nil, nil; origClear() end
-- tas (op de cursor) in een tasvak leggen: WoW weigert als hij niet leeg is of in zichzelf zou gaan
local origPick = C_Container.PickupContainerItem
local refused
function C_Container.PickupContainerItem(b, s)
  if CURSOR_BAG then
    local c = CURSOR_BAG
    local n = 0
    for i = 1, (BAGS[c] and BAGS[c].n or 0) do if BAGS[c][i] then n = n + 1 end end
    if b == c or n > 0 or (BAGS[b] and BAGS[b][s]) then refused = "Can't put non-empty bags in other bags."; return end
    BAGS[b][s] = { itemID = EQUIP[c], count = 1 }
    EQUIP[c], BAGS[c], CURSOR, CURSOR_BAG, locked = nil, nil, nil, nil, nil
    return
  end
  origPick(b, s)
end
local function Bag(name, slots) return { name = name, quality = 1, stack = 1, bind = 0, icon = 1, price = 100, class = 1, sub = 0, slots = slots, equip = "INVTYPE_BAG" } end
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 5, price = 10 },
  [5764] = Bag("Green Silk Pack", 14),
  [4241] = Bag("Linen Bag", 6),
}
BAGS[0] = { n = 16 }
for s = 1, 10 do BAGS[0][s] = { itemID = 2589, count = 20 } end -- 6 vrij in de rugzak
EQUIP[1], BAGS[1] = 4241, { n = 6 }
EQUIP[2], BAGS[2] = 5764, { n = 14 }
EQUIP[3], BAGS[3] = 5764, { n = 14 }
for s = 1, 3 do BAGS[3][s] = { itemID = 2589, count = 20 } end -- tas 3 is niet leeg
EQUIP[4], BAGS[4] = nil, nil
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers(); RunTimers() end
local function Cloth() local n = 0; for b = 0, 4 do for s = 1, (BAGS[b] and BAGS[b].n or 0) do local it = BAGS[b][s]; if it and it.itemID == 2589 then n = n + it.count end end end return n end
local function Said(text) for _, l in ipairs(LOG) do if l:find(text, 1, true) then return true end end return false end
local function Run() for _ = 1, 30 do RunTimers() end end
CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")

-- A. Niet-lege tas (tas 3, 3 stapels) in het venster laten vallen: eerst leeg, dan uit.
local total = Cloth()
PickupBagFromSlot(33)
check(NS.BagUnequip() == true, "tas uit de tassenbalk: CarefreeBag regelt het")
Run()
check(EQUIP[3] == nil, "tas 3 is uitgedaan (" .. tostring(refused) .. ")")
check(refused == nil, "WoW hoefde niets te weigeren")
check(Cloth() == total, "inhoud niet kwijt")
local found = false
for b = 0, 2 do for s = 1, BAGS[b].n do local it = BAGS[b][s]; if it and it.itemID == 5764 then found = true end end end
check(found, "de Green Silk Pack ligt nu in een tas")
check(CURSOR == nil, "niets meer op de cursor")

-- B. Lege tas (tas 2): gaat niet in zichzelf, maar in een ander vak.
PickupBagFromSlot(32)
check(NS.BagUnequip() == true, "lege tas: ook via CarefreeBag")
Run()
check(EQUIP[2] == nil and refused == nil, "lege tas uitgedaan, niet in zichzelf gelegd")

-- C. Te weinig plek: melding, niets verplaatst.
for b = 0, 1 do for s = 1, BAGS[b].n do BAGS[b][s] = BAGS[b][s] or { itemID = 2589, count = 20 } end end
BAGS[1][1] = nil -- 1 vrij vak in tas 1 ... maar tas 1 is de tas die eruit moet
BAGS[0][16] = nil -- 1 vrij vak in de rugzak, tas 1 heeft 5 stapels: past niet
total = Cloth()
PickupBagFromSlot(31)
check(NS.BagUnequip() == true, "te weinig plek: toch afgehandeld (melding)")
Run()
check(EQUIP[1] == 4241 and CURSOR == nil, "tas blijft aan, cursor leeg")
check(Cloth() == total, "niets kwijt")
check(Said("Not enough room to take off"), "melding: niet genoeg plek")

-- D. Gewoon item op de cursor: BagUnequip doet niets.
CURSOR = { itemID = 2589, count = 20 }
check(NS.BagUnequip() == false, "gewoon item: niet onze zaak")
CURSOR = nil
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
