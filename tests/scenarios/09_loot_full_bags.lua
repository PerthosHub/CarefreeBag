local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Tassen vol en loot die niet past: goedkoopste item weggooien en de loot oppakken (met één klik).
ITEMS = {
  [8000] = { name = "Broken Fang", quality = 0, stack = 10, bind = 0, icon = 9, price = 5 },
  [8001] = { name = "Torn Wing", quality = 0, stack = 10, bind = 0, icon = 9, price = 50 },
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, price = 10 },
  [6948] = { name = "Hearthstone", quality = 1, stack = 1, bind = 1, icon = 1 },
  [9000] = { name = "Shiny Ring", quality = 2, stack = 1, bind = 2, icon = 5, price = 500, class = 4 },
  [9200] = { name = "Silk Cloth", quality = 1, stack = 20, bind = 0, icon = 7, price = 40 },
  [9100] = { name = "Wolf Pelt", quality = 1, stack = 10, bind = 1, icon = 6, quest = true, class = 12 },
}
BAGS[0] = { n = 5,
  [1] = { itemID = 8000, count = 3 },   -- 15c: de goedkoopste
  [2] = { itemID = 8001, count = 1 },   -- 50c
  [3] = { itemID = 2589, count = 20 },  -- volle stapel, 200c
  [4] = { itemID = 6948, count = 1, bound = true }, -- geen waarde: nooit weggooien
  [5] = { itemID = 2589, count = 20 } }
LOADED_ADDONS = {}

-- Nagebootst lootvenster
LOOT = {}
function GetNumLootItems() return #LOOT end
function GetLootSlotType(i) return LOOT[i] and 1 or 0 end
function GetLootSlotLink(i) local l = LOOT[i]; if l and l.id then return "|cff|Hitem:" .. l.id .. "|h[" .. ITEMS[l.id].name .. "]|h|r" end end
function GetLootSlotInfo(i) local l = LOOT[i]; if l and l.id then local d = ITEMS[l.id]; return d.icon, d.name, l.qty, nil, d.quality, false, d.quest end end
LOOTED = {}
function LootSlot(i)
  local l = LOOT[i]; LOOTED[#LOOTED + 1] = l.id
  for s = 1, BAGS[0].n do if not BAGS[0][s] then BAGS[0][s] = { itemID = l.id, count = l.qty }; break end end
  LOOT[i] = {} -- leeg vak, de nummers schuiven niet op
end
DELETED = {}
function DeleteCursorItem() DELETED[#DELETED + 1] = CURSOR and CURSOR.itemID; CURSOR = nil end
ERR_INV_FULL = "Inventory is full."

local NS = {}
LoadAddon(NS)
MenuUtil = nil -- eerst ons eigen menu (terugval); stap 19 test het WoW-menu
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
CFC().assign[2589] = CFC().cats[1].key -- linnen in een eigen groep (Consumables), niet in Other

-- 1. Ring (500c) en 2 linnen passen niet: ring is het meest waard
LOOT = { { id = 2589, qty = 2 }, { id = 9000, qty = 1 } }
E("LOOT_OPENED")
local P = NS.lootPanel
check(P and P:IsShown(), "tassen vol + loot past niet: paneel open")
local function RowOf(id) for _, r in ipairs(P.rows) do if r:IsShown() and r.offer and r.offer.loot.id == id then return r end end end
local R1, R2 = RowOf(9000), RowOf(2589)
check(P.rows[1].offer.loot.slot == 1 and P.rows[2].offer.loot.slot == 2, "rijen in de volgorde van het lootvenster (#23), niet op waarde")
check(P.offer.loot.slot == 2 and P.offer.junk.e.itemID == 8000, "duurste loot (ring) krijgt de goedkoopste stapel (Broken Fang)")
check(R1.offer.loot.value == 500 and R1.offer.junk.value == 15, "waarde: loot 500c, in de tas 15c")
check(R1.junk.count.text == 3, "aantal op het weg-icoon: 3")
check(R1.diff.text:find("+485c", 1, true) and R1.diff.text:find("4ade80"), "ring: modern groen +485c (" .. tostring(R1.diff.text) .. ")")
check(R1.advice == "pickup" and R1.btn.green and R1.btn.text == "Pick up" and R1.leave.grey and R1.leave.text == "Leave it",
  "ring: Pick up groen (advies), Leave it grijs")
check(R2 and R2.offer.junk.e.itemID == 8001, "linnen tegelijk zichtbaar, tegen Torn Wing (ander item)")
check(R2.diff.text:find("-30c", 1, true) and R2.diff.text:find("f87171") and R2.btn.grey and R2.leave.green,
  "linnen: modern rood -30c, Leave it groen (advies), Pick up grijs")
check(not P.rows[3]:IsShown(), "geen derde rij")
check(P.skip.text == "Leave all", "onderaan: Leave all")

-- 2. Klik op Pick up in rij 1: weggooien en looten
R1.btn:Fire("OnClick")
check(P:IsShown() and P.busy and R1.diff.text:find("Picking up") and R1.btn.enabled == false and R2.btn.enabled == false, "tijdens het oppakken blijft het paneel open (knoppen even uit)")
R1.btn:Fire("OnClick") -- dubbelklik: niet nog iets weggooien
R2.btn:Fire("OnClick")
RunTimers()
check(#DELETED == 1 and DELETED[1] == 8000, "Broken Fang weggegooid (één keer)")
check(LOOTED[1] == 9000, "ring opgepakt")
check(BAGS[0][1] and BAGS[0][1].itemID == 9000, "ring ligt in het vrijgekomen vak")
local said = false; for _, l in ipairs(LOG) do if l:find("Destroyed") and l:find("Shiny Ring") then said = true end end
check(said, "melding in de chat")

-- 3. Linnen past nog steeds niet; nu is Torn Wing (50c) de goedkoopste en de loot minder waard
check(P:IsShown() and P.offer.loot.slot == 1 and P.offer.junk.e.itemID == 8001, "meteen door: linnen tegen Torn Wing staat nu bovenaan")
check(not P.rows[2]:IsShown() and not P.busy and P.rows[1].btn.enabled and P.rows[1].leave.enabled, "nog één rij, knoppen weer aan")
check(P.rows[1].advice == "leave" and not P.rows[1].btn.green and P.rows[1].diff.text:find("-30c", 1, true), "advies: niet slim (rood -30c)")
check(P.offer.junk.e.itemID ~= 6948, "hearthstone (geen waarde) nooit voorgesteld")

-- 4. Leave all: blijft dicht tot de loot dicht is
P.skip:Fire("OnClick"); RunTimers()
check(not P:IsShown(), "overslaan: paneel dicht")
E("LOOT_SLOT_CLEARED"); RunTimers()
check(not P:IsShown(), "overslaan: komt niet terug zolang de loot open is")
E("LOOT_CLOSED")
check(#DELETED == 1, "na overslaan niets weggegooid")

-- 5. Questloot: altijd de moeite waard
LOOT = { { id = 9100, qty = 1 } }
E("LOOT_OPENED")
check(P:IsShown() and P.advice == "pickup" and P.rows[1].diff.text:find("Quest") and P.rows[1].btn.green, "questloot: altijd oppakken (groen Quest)")
E("LOOT_CLOSED")
check(not P:IsShown(), "loot dicht: paneel dicht")

-- 6. Er is nog een vrij vak: niets vragen
BAGS[0][2] = nil
LOOT = { { id = 9000, qty = 1 } }
E("LOOT_OPENED")
check(not P:IsShown(), "vrij vak: geen paneel")
E("LOOT_CLOSED")

-- 7. Loot die bij een eigen stapel past: niets vragen
BAGS[0][2] = { itemID = 8001, count = 1 }
BAGS[0][3].count = 18
LOOT = { { id = 2589, qty = 2 } }
E("LOOT_OPENED")
check(not P:IsShown(), "past bij een stapel (18+2): geen paneel")
check(table.concat(CarefreeBagDB.events or {}, "\n"):find("no offer, loot slot 1: Linen Cloth id 2589 x2, type 1, locked false, quest nil, fits true", 1, true),
  "geen paneel bij volle tassen: reden per loot-vak in DB.events")
E("LOOT_CLOSED")

-- 8. Melding "Inventory is full" opent het paneel ook (autoloot)
BAGS[0][3].count = 20
LOOT = { { id = 9200, qty = 1 } }
E("UI_ERROR_MESSAGE", 3, "Inventory is full.")
check(P:IsShown(), "foutmelding 'tassen vol' opent het paneel")

-- 9. "Keep this item": Torn Wing nooit meer, meteen het volgende goedkoopste item
check(P.offer.junk.e.itemID == 8001 and not P.menu:IsShown(), "goedkoopste: Torn Wing; opties pas zichtbaar bij hover")
P.rows[1].opt:Fire("OnClick")
check(P.menu:IsShown() and P.menu.groupHead.text:find("Auto Sell") and not P.keepGroup:IsShown() and P.skipGroup:IsShown(), "hover: opties met groepsnaam; Auto Sell: geen 'nooit uit deze groep'")
P.keepItem:Fire("OnClick"); RunTimers()
check(CFC().keep[8001] == true, "Torn Wing onthouden als 'houden' (per karakter)")
check(P:IsShown() and P.offer.junk.e.itemID == 2589, "volgende goedkoopste: Linen Cloth")
local linenSec = P.offer.junk.sec
P.rows[1].opt:Fire("OnClick")
check(P.keepGroup:IsShown(), "andere groep: 'nooit uit deze groep' weer zichtbaar")
CFC().assign[2589] = nil; E("BAG_UPDATE_DELAYED"); RunTimers()
P.rows[1].opt:Fire("OnClick")
check(P.offer.junk.sec == "other" and not P.keepGroup:IsShown(), "Other: geen optie voor de hele groep")
CFC().assign[2589] = CFC().cats[1].key; E("BAG_UPDATE_DELAYED"); RunTimers()
-- 10. "Keep this group": niets uit de groep van het linnen, dan de ring
P.keepGroup:Fire("OnClick"); RunTimers()
check(CFC().keepGroups[linenSec] == true, "groep '" .. tostring(linenSec) .. "' onthouden als 'houden'")
check(P:IsShown() and P.offer.junk.e.itemID == 9000, "volgende: Shiny Ring (andere groep)")
-- 11. Ring ook houden: niets meer over om weg te gooien
P.keepItem:Fire("OnClick"); RunTimers()
check(not P:IsShown(), "alles beschermd: geen paneel")
-- 12. Opties: vinkje per groep en 'Wissen' voor de items
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig:IsShown() and CarefreeBagConfig.keptLabel.text:find("2"), "opties: 2 items die je houdt")
CarefreeBagConfig.keptClear:Fire("OnClick"); RunTimers()
check(next(CFC().keep) == nil, "Wissen: geen items meer bewaard")
check(CFC().keepGroups[linenSec] == true, "Wissen laat de groepen staan")
E("LOOT_CLOSED"); LOOT = { { id = 9200, qty = 1 } }; E("LOOT_OPENED")
check(P:IsShown() and P.offer.junk.e.itemID == 8001, "na Wissen: Torn Wing weer voorgesteld")
-- eenmalig overslaan: item en groep, tot het lootvenster dichtgaat
P.skipItem:Fire("OnClick"); RunTimers()
check(P:IsShown() and P.offer.junk.e.itemID ~= 8001 and CFC().keep[8001] == nil, "item nu overslaan: volgende, niet onthouden")
local nowSec = P.offer.junk.sec
P.skipGroup:Fire("OnClick"); RunTimers()
check(not P:IsShown() or P.offer.junk.sec ~= nowSec, "groep nu overslaan: niets meer uit die groep")
check(CFC().keepGroups[nowSec] == nil, "groep nu overslaan wordt niet onthouden")
E("LOOT_CLOSED"); LOOT = { { id = 9200, qty = 1 } }; E("LOOT_OPENED")
check(P:IsShown() and P.offer.junk.e.itemID == 8001, "loot opnieuw open: overslaan is voorbij, Torn Wing weer")

-- 13. Geavanceerd: ingeklapt tot je erop klikt
check(not CarefreeBagConfig.adv:IsShown(), "geavanceerde instellingen standaard ingeklapt")
CarefreeBagConfig.advBtn:Fire("OnClick")
check(CarefreeBagConfig.adv:IsShown(), "klik: geavanceerde instellingen open")
check(CarefreeBagDB.showSort == false, "sorteeropties standaard uit")

-- 14. Post per groep: envelop in de rij, adres + "zonder vragen" in een venstertje
local mrow; for _, f in ipairs(ALLFRAMES) do if f.mailBtn and f.key == "boe" and f.shown then mrow = f end end
check(mrow and mrow.mailBtn:IsShown() and mrow.mailInfo.text:find("no mail"), "BoE: envelop met 'no mail'")
mrow.mailBtn:Fire("OnClick")
check(mrow.mailPop:IsShown() and mrow.mailPop.title.text:find("BoE"), "klik envelop: venstertje voor BoE")
mrow.mail:SetText("Jaina Frostwolf"); mrow.mail:Fire("OnEnterPressed"); RunTimers()
check(CarefreeBagDB.boeMail == "Jaina Frostwolf" and mrow.mailInfo.text:find("Jaina") and mrow.mailAuto:IsShown(), "adres ingevuld: naam in de rij, vinkje zonder vragen zichtbaar")
mrow.mailOk:Fire("OnClick")
check(not mrow.mailPop:IsShown(), "OK sluit het venstertje")

-- 15. Hover-info over de prijzen: zonder Auctionator, zonder AH-prijs, met AH-prijs en leeftijd
local wing = "|cff|Hitem:8001|h[Torn Wing]|h|r"
local fang = "|cff|Hitem:8000|h[Broken Fang]|h|r"
local L = NS.PriceLines(wing)
check(L[2]:find("not installed"), "zonder Auctionator: dat staat erbij: " .. tostring(L[2]))
Auctionator = { API = { v1 = {
  GetAuctionPriceByItemLink = function(_, l) if l:find("Torn Wing", 1, true) then return 100 end end,
  GetAuctionAgeByItemLink = function(_, l) return 2 end } } }
L = NS.PriceLines(wing, fang)
check(L[2]:find("Torn Wing", 1, true) and L[2]:find("2 days ago"), "met prijs: wanneer gezien: " .. tostring(L[2]))
check(L[3]:find("Broken Fang", 1, true) and L[3]:find("no AH price"), "zonder prijs in Auctionator: vendorprijs: " .. tostring(L[3]))
Auctionator = nil

-- 16. Item dat ook in de loot ligt: die stapel niet weggooien (daar past de loot op)
E("LOOT_CLOSED"); LOOT = { { id = 8001, qty = 1 }, { id = 9200, qty = 1 } }; E("LOOT_OPENED")
check(P:IsShown() and P.offer.loot.id == 9200 and P.offer.junk.e.itemID ~= 8001, "Torn Wing ligt ook in de loot: die stapel wordt niet voorgesteld")
P.rows[1].opt:Fire("OnClick")
check(P.menu.itemHead.text == P.offer.junk.e.name and P.menu.groupHead.text:find("Group:"), "menu: kopje met itemnaam en groep")
E("LOOT_CLOSED")

-- 17. Twee items die niet passen: twee rijen tegelijk, elk een eigen item om weg te gooien
CFC().keepGroups[linenSec] = nil -- linnen mag weer weg: zo zijn er twee items om weg te gooien
LOOT = { { id = 9200, qty = 1 }, { id = 9000, qty = 1 } }; E("LOOT_OPENED")
check(P:IsShown() and P.offer.loot.id == 9000 and P.rows[1].offer.loot.id == 9200 and P.rows[2]:IsShown() and P.rows[2].offer.loot.id == 9000,
  "zelfde volgorde als het lootvenster (zijde, dan ring); de ring is het meest waardevol")
check(P.rows[1].offer.junk.e ~= P.rows[2].offer.junk.e, "elke rij een ander item om weg te gooien")
-- Leave it in één rij: die loot blijft liggen, de andere rij blijft staan, niets weggegooid
local nDel = #DELETED
P.rows[1].leave:Fire("OnClick"); RunTimers()
check(P:IsShown() and P.rows[1].offer.loot.id == 9000 and not P.rows[2]:IsShown() and #DELETED == nDel,
  "Leave it: zijde blijft liggen, ring-rij blijft, niets weggegooid")
E("BAG_UPDATE_DELAYED"); RunTimers()
check(P.rows[1].offer.loot.id == 9000 and not P.rows[2]:IsShown(), "Leave it: komt niet terug zolang de loot open is")
P.skip:Fire("OnClick"); RunTimers()
check(not P:IsShown(), "Leave all: paneel dicht")
E("BAG_UPDATE_DELAYED"); RunTimers()
check(not P:IsShown(), "Leave all: komt niet terug zolang de loot open is")
E("LOOT_CLOSED"); E("LOOT_OPENED")
check(P:IsShown() and P.offer.loot.id == 9000, "lootvenster opnieuw open: weer vragen")
E("LOOT_CLOSED")

-- 18. Kruisje: niet meer vragen tot de loot dicht is (kwam eerst na een tas-update terug)
LOOT = { { id = 9000, qty = 1 }, { id = 9200, qty = 1 } }; E("LOOT_OPENED")
check(P:IsShown(), "paneel open")
P:Hide(); RunTimers()
E("BAG_UPDATE_DELAYED"); E("UI_ERROR_MESSAGE", 3, "Inventory is full."); E("LOOT_SLOT_CLEARED"); RunTimers()
check(not P:IsShown(), "kruisje: komt niet terug na tas-update of 'Inventory is full'")
E("LOOT_CLOSED"); E("LOOT_OPENED")
check(P:IsShown(), "volgende keer looten: weer vragen")
E("LOOT_CLOSED")
local ev9 = table.concat(CarefreeBagDB.events or {}, "\n")
check(ev9:find("bags full: free slots") and ev9:find("bags full: offer: destroy"), "tassen-vol-momenten in DB.events:\n" .. ev9)

-- 19. Knopje in de rij opent WoW's eigen keuzemenu (MenuUtil) als dat er is; rij groen/rood met vinkje/kruisje
local menu = {}
MenuUtil = { CreateContextMenu = function(owner, gen)
  menu = { owner = owner, items = {} }
  local root = {}
  function root:CreateTitle(t) menu.items[#menu.items + 1] = { title = t } end
  function root:CreateButton(t, f) menu.items[#menu.items + 1] = { text = t, fn = f } end
  function root:CreateDivider() menu.items[#menu.items + 1] = { divider = true } end
  gen(owner, root)
end }
LOOT = { { id = 9000, qty = 1 } }; E("LOOT_OPENED")
local R = P.rows[1]
check(R.smart and R.mark and R.bg, "slimme rij: groene achtergrond en vinkje")
R.opt:Fire("OnClick")
check(menu.owner == R.opt and menu.items[1].title == P.offer.junk.e.name, "WoW-menu aan het knopje, kopje = item dat weg zou gaan")
check(not P.menu:IsShown(), "eigen menu niet nodig")
local skipFn, keepFn
for _, it in ipairs(menu.items) do
  if it.text == "Skip this item this time" then skipFn = it.fn end
  if it.text == "Never destroy this item" then keepFn = it.fn end
end
local before = P.offer.junk.e.itemID
-- rij verandert terwijl het menu open is: een keuze geldt niet voor het nieuwe item
CFC().keep[before] = true; E("BAG_UPDATE_DELAYED"); RunTimers()
local other = P.offer.junk.e.itemID
check(other ~= before, "rij heeft nu een ander item")
keepFn(); RunTimers()
check(not CFC().keep[other], "keuze uit een oud menu raakt het nieuwe item niet")
CFC().keep[before] = nil; E("BAG_UPDATE_DELAYED"); RunTimers()
check(P.offer.junk.e.itemID == before, "terug naar het eerste item")
skipFn(); RunTimers()
check(P:IsShown() and P.offer.junk.e.itemID ~= before, "keuze uit het WoW-menu werkt: ander item voorgesteld")
MenuUtil = nil
E("LOOT_CLOSED")
