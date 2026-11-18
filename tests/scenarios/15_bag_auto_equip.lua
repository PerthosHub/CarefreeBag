local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Betere tassen automatisch aandoen (BagSwap.lua): leeg vak eerst, gewone tas wint van
-- beroepstas, meer vakjes wint, bij gelijk aantal soulbound vóór verhandelbaar, BoE als laatste.

-- Nagebootste tasvakken: EQUIP[container] = itemID van de tas die je aan hebt.
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
-- Tas op de cursor in tasvak inv: inhoud gaat mee, oude tas naar de plek van de nieuwe.
function PutItemInBag(inv)
  local c = inv - 30
  if not CURSOR or not CURSOR_FROM or CURSOR_FROM[1] == c then return end
  local new, d, old = CURSOR, ITEMS[CURSOR.itemID], EQUIP[c]
  local inside = {}
  for s = 1, (BAGS[c] and BAGS[c].n or 0) do if BAGS[c][s] then inside[#inside + 1] = BAGS[c][s] end end
  if #inside > d.slots then return end
  local nb = { n = d.slots }
  for i, it in ipairs(inside) do nb[i] = it end
  BAGS[c], EQUIP[c], CURSOR = nb, new.itemID, nil
  if old then BAGS[CURSOR_FROM[1]][CURSOR_FROM[2]] = { itemID = old, count = 1 } end
end
local function Bag(name, slots, bind, sub) return { name = name, quality = 1, stack = 1, bind = bind, icon = 1, price = 100, class = 1, sub = sub or 0, slots = slots, equip = "INVTYPE_BAG" } end
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 5, price = 10 },
  [4240] = Bag("Woolen Bag", 10, 0),
  [4241] = Bag("Linen Bag", 6, 0),
  [22250] = Bag("Herb Pouch", 12, 0, 2),
  [4500] = Bag("Traveler's Backpack", 16, 2),
  [4242] = Bag("Bound Bag A", 10, 1),
  [4243] = Bag("Bound Bag B", 10, 1),
  [4244] = Bag("Bound Bag C", 10, 1),
  [4245] = Bag("BoE Bag", 10, 2),
  [4246] = Bag("Big Bag", 18, 1),
  [4247] = Bag("Huge Bag", 20, 1),
}
EQUIP[1] = 4241
BAGS[1] = { n = 6, [1] = { itemID = 2589, count = 20 }, [2] = { itemID = 2589, count = 20 } }
BAGS[0] = { n = 16, [1] = { itemID = 4240, count = 1 }, [2] = { itemID = 22250, count = 1 } }
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers(); RunTimers() end
local function Put(id, bound) for s = 1, BAGS[0].n do if not BAGS[0][s] then BAGS[0][s] = { itemID = id, count = 1, bound = bound }; return end end end
local function InBags(id) for b = 0, 4 do for s = 1, (BAGS[b] and BAGS[b].n or 0) do if BAGS[b][s] and BAGS[b][s].itemID == id then return true end end end return false end
local function Said(text) for _, l in ipairs(LOG) do if l:find(text, 1, true) then return true end end return false end
CarefreeBagDB = { lang = "en" }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
check(CarefreeBagDB.autoBags == true, "standaard aan")
check(EQUIP[2] == 4240, "Woolen Bag (gewoon) in het eerste lege vak, vóór de beroepstas")
check(Said("Equipped"), "melding: tas aangedaan")
E("BAG_UPDATE_DELAYED")
check(EQUIP[3] == 22250, "beroepstas mag in een leeg vak")
Put(4241); E("BAG_UPDATE_DELAYED")
check(EQUIP[4] == 4241, "tweede Linen Bag in het laatste lege vak")

-- Alle vakken vol: een gewone tas van 16 vervangt eerst de beroepstas.
Put(4500); E("BAG_UPDATE_DELAYED")
check(EQUIP[3] == 4500 and InBags(22250), "gewone tas vervangt de beroepstas")
check(Said("Swapped"), "melding: gewisseld")
E("BAG_UPDATE_DELAYED")
check(EQUIP[3] == 4500 and InBags(22250), "beroepstas gaat niet vanzelf terug")

-- Meer vakjes wint: soulbound 10 vervangt een Linen Bag van 6 (inhoud blijft bewaard).
Put(4242, true); E("BAG_UPDATE_DELAYED")
check(EQUIP[1] == 4242, "Bound Bag A (10) vervangt Linen Bag (6) in vak 1")
local n = 0
for b = 0, 4 do for s = 1, (BAGS[b] and BAGS[b].n or 0) do local it = BAGS[b][s]; if it and it.itemID == 2589 then n = n + it.count end end end
check(n == 40, "linnen niet kwijt: " .. n)
Put(4243, true); E("BAG_UPDATE_DELAYED")
check(EQUIP[4] == 4243, "Bound Bag B vervangt de andere Linen Bag")

-- Evenveel vakjes: soulbound vóór een tas zonder binding (die blijft verhandelbaar).
Put(4244, true); E("BAG_UPDATE_DELAYED")
check(EQUIP[2] == 4244 and InBags(4240), "soulbound 10 vervangt Woolen Bag 10 (geen binding)")
E("BAG_UPDATE_DELAYED")
check(EQUIP[2] == 4244, "Woolen Bag gaat niet terug")
-- BoE met evenveel vakjes: nooit (aandoen bindt hem).
Put(4245); E("BAG_UPDATE_DELAYED")
check(InBags(4245) and EQUIP[1] == 4242 and EQUIP[2] == 4244 and EQUIP[4] == 4243, "BoE 10 blijft in de tas")

-- Zelf een vak leeggemaakt: dat vak vullen we niet vanzelf.
EQUIP[4] = nil; BAGS[4] = nil; Put(4243, true)
E("BAG_UPDATE_DELAYED")
check(EQUIP[4] == nil, "zelf leeggemaakt vak blijft leeg")
-- Maar een betere tas (ook dezelfde soort als die je uitdeed) wisselt wel in een ander vak.
BAGS[2] = { n = 6 }; EQUIP[2] = 4241 -- vak 2: een Linen Bag van 6
E("BAG_UPDATE_DELAYED")
check(EQUIP[2] == 4243, "Bound Bag B (zelfde soort als uitgedaan) vervangt toch een kleinere tas")

-- In gevecht: wachten tot het gevecht voorbij is.
COMBAT = true
Put(4246, true); E("BAG_UPDATE_DELAYED")
check(InBags(4246), "in gevecht: niets gewisseld")
COMBAT = nil
E("PLAYER_REGEN_ENABLED")
check(not InBags(4246), "na het gevecht: Big Bag aangedaan")

-- Optie uit: niets.
CarefreeBagDB.autoBags = false
Put(4247, true); E("BAG_UPDATE_DELAYED")
check(InBags(4247), "optie uit: niets aangedaan")
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig.bagsCb, "vinkje in de opties")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
