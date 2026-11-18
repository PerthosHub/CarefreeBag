local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Zelf tassen wisselen (BagSwap.lua): rechtsklik met alle vakken vol, de nieuwe tas zit in
-- de tas die eruit moet, downgrade = eerst een vraag, te weinig plek = melding, slepen op het
-- eigen tasvak.

EQUIP = {}
CONTAINER_SLOTS = "%d Slot %s"
function C_Container.ContainerIDToInventoryID(c) return 30 + c end
function GetInventoryItemID(_, inv) return EQUIP[inv - 30] end
function GetInventoryItemLink(_, inv) local id = EQUIP[inv - 30]; return id and ("|cff|Hitem:" .. id .. "|h[" .. ITEMS[id].name .. "]|h|r") end
C_TooltipInfo = { GetBagItem = function(b, s)
  local it = BAGS[b] and BAGS[b][s]; if not it then return nil end
  local d = ITEMS[it.itemID]
  return { lines = { { leftText = d.name }, d.slots and { leftText = d.slots .. " Slot Bag" } or nil } }
end }
local origPick = C_Container.PickupContainerItem
function C_Container.PickupContainerItem(b, s)
  local before = CURSOR; origPick(b, s)
  if CURSOR and CURSOR ~= before then CURSOR_FROM = { b, s } end
end
function PutItemInBag(inv)
  local c = inv - 30
  if not CURSOR or not CURSOR_FROM or CURSOR_FROM[1] == c then return end -- WoW: tas kan niet in zichzelf
  local new, d, old = CURSOR, ITEMS[CURSOR.itemID], EQUIP[c]
  local inside = {}
  for s = 1, (BAGS[c] and BAGS[c].n or 0) do if BAGS[c][s] then inside[#inside + 1] = BAGS[c][s] end end
  if #inside > d.slots then return end
  local nb = { n = d.slots }
  for i, it in ipairs(inside) do nb[i] = it end
  BAGS[c], EQUIP[c], CURSOR = nb, new.itemID, nil
  if old then BAGS[CURSOR_FROM[1]][CURSOR_FROM[2]] = { itemID = old, count = 1 } end
end
local function Bag(name, slots, bind) return { name = name, quality = 1, stack = 1, bind = bind, icon = 1, price = 100, class = 1, sub = 0, slots = slots, equip = "INVTYPE_BAG" } end
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 5, price = 10 },
  [4241] = Bag("Linen Bag", 6, 0),
  [4500] = Bag("Traveler's Backpack", 16, 2),
  [4246] = Bag("Small Pouch", 4, 0),
  [4247] = Bag("Huge Bag", 16, 1),
}
local function Full(n) local t = { n = n }; for s = 1, n do t[s] = { itemID = 2589, count = 20 } end return t end
for c = 1, 4 do EQUIP[c] = 4241; BAGS[c] = Full(6) end
BAGS[1][1] = { itemID = 4500, count = 1 } -- de nieuwe tas zit in de tas die eruit gaat
BAGS[0] = Full(4)
CharacterBag3Slot = CreateFrame("Button", "CharacterBag3Slot")
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers(); RunTimers() end
local function Cloth() local n = 0; for b = 0, 4 do for s = 1, (BAGS[b] and BAGS[b].n or 0) do local it = BAGS[b][s]; if it and it.itemID == 2589 then n = n + it.count end end end return n end
local function Said(text) for _, l in ipairs(LOG) do if l:find(text, 1, true) then return true end end return false end
CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
local total = Cloth()

-- A. Rechtsklik op de Traveler's Backpack (16) die in tas 1 zit. Alles vol.
check(NS.BagRightClick(1, 1) == true, "rechtsklik op een tas met alle vakken vol: CarefreeBag regelt het")
RunTimers(); RunTimers()
check(EQUIP[1] == 4500 and BAGS[1].n == 16, "tas uit tas 1 toch in vak 1 gezet")
check(BAGS[0][1] and BAGS[0][1].itemID == 4241, "oude Linen Bag ligt in de rugzak")
check(Cloth() == total, "linnen niet kwijt")

-- B. Downgrade: Small Pouch (4) in plaats van een Linen Bag (6) = eerst vragen.
BAGS[0][2] = { itemID = 4246, count = 1 }
for s = 1, 16 do BAGS[1][s] = BAGS[1][s] or { itemID = 2589, count = 20 } end -- nergens meer plek
total = Cloth()
POPUPS = {}
NS.BagRightClick(0, 2); RunTimers()
check(POPUPS[1] and POPUPS[1].which == "CAREFREEBAG_BAGDOWN" and POPUPS[1].arg:find("You lose 2"), "vraag bij downgrade: " .. tostring(POPUPS[1] and POPUPS[1].arg))
check(EQUIP[2] == 4241, "nog niets gewisseld zonder Ja")
StaticPopupDialogs.CAREFREEBAG_BAGDOWN.OnAccept(); RunTimers(); RunTimers()
check(EQUIP[2] == 4241 and Said("Not enough room"), "te weinig plek: melding, niets gewisseld")
-- plek maken: tas 3 leeg
BAGS[3] = { n = 6 }
total = Cloth()
POPUPS = {}
NS.BagRightClick(0, 2); RunTimers()
StaticPopupDialogs.CAREFREEBAG_BAGDOWN.OnAccept(); RunTimers(); RunTimers()
check(EQUIP[2] == 4246, "met plek: Small Pouch in vak 2")
check(Cloth() == total, "inhoud van de oude tas verplaatst, niets kwijt")

-- C. Huge Bag (16) zit in tas 4 en wordt op zijn eigen tasvak gesleept: WoW weigert, wij wisselen.
BAGS[4][1] = { itemID = 4247, count = 1, bound = true }
total = Cloth()
CURSOR = { itemID = 4247, count = 1 } -- opgepakt: vakje staat op slot
CharacterBag3Slot:Fire("OnReceiveDrag"); RunTimers(); RunTimers()
check(EQUIP[4] == 4247, "op eigen tasvak gesleept: toch gewisseld")
check(Cloth() == total, "linnen niet kwijt")

-- Niet bij de vendor (daar verkoopt rechtsklik).
MerchantFrame.shown = true
check(NS.BagRightClick(0, 1) == false, "vendor open: rechtsklik doet WoW zelf")
MerchantFrame.shown = false
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
