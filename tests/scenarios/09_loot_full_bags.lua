local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Tassen vol en loot die niet past: goedkoopste item weggooien en de loot oppakken (met één klik).
ITEMS = {
  [8000] = { name = "Broken Fang", quality = 0, stack = 10, bind = 0, icon = 9, price = 5 },
  [8001] = { name = "Torn Wing", quality = 0, stack = 10, bind = 0, icon = 9, price = 50 },
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, price = 10 },
  [6948] = { name = "Hearthstone", quality = 1, stack = 1, bind = 1, icon = 1 },
  [9000] = { name = "Shiny Ring", quality = 2, stack = 1, bind = 2, icon = 5, price = 500, class = 4 },
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
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
CFC().assign[2589] = CFC().cats[1].key -- linnen in een eigen groep (Consumables), niet in Other

-- 1. Ring (500c) en 2 linnen passen niet: ring is het meest waard
LOOT = { { id = 2589, qty = 2 }, { id = 9000, qty = 1 } }
E("LOOT_OPENED")
local P = NS.lootPanel
check(P and P:IsShown(), "tassen vol + loot past niet: paneel open")
check(P.offer.loot.slot == 2 and P.offer.junk.e.itemID == 8000, "biedt ring aan tegen goedkoopste stapel (Broken Fang)")
check(P.lootRow.value.text == "500c" and P.junkRow.value.text == "15c", "prijzen naast elkaar: 500c vs 15c")
check(P.junkRow.name.text:find("Broken Fang") and P.junkRow.name.text:find("x3"), "stapel met aantal: Broken Fang x3")
check(P.verdict.text:find("485c") and P.verdict.text:find("more"), "loot is 485c meer waard")

-- 2. Klik: weggooien en looten
P.swap:Fire("OnClick"); RunTimers()
check(DELETED[1] == 8000, "Broken Fang weggegooid")
check(LOOTED[1] == 9000, "ring opgepakt")
check(BAGS[0][1] and BAGS[0][1].itemID == 9000, "ring ligt in het vrijgekomen vak")
local said = false; for _, l in ipairs(LOG) do if l:find("Destroyed") and l:find("Shiny Ring") then said = true end end
check(said, "melding in de chat")

-- 3. Linnen past nog steeds niet; nu is Torn Wing (50c) de goedkoopste en de loot minder waard
check(P:IsShown() and P.offer.loot.slot == 1 and P.offer.junk.e.itemID == 8001, "volgende: linnen tegen Torn Wing")
check(P.verdict.text:find("30c") and P.verdict.text:find("less"), "loot is 30c minder waard (rood)")
check(P.offer.junk.e.itemID ~= 6948, "hearthstone (geen waarde) nooit voorgesteld")

-- 4. Overslaan: blijft dicht tot de loot dicht is
P.skip:Fire("OnClick"); RunTimers()
check(not P:IsShown(), "overslaan: paneel dicht")
E("LOOT_SLOT_CLEARED"); RunTimers()
check(not P:IsShown(), "overslaan: komt niet terug zolang de loot open is")
E("LOOT_CLOSED")
check(#DELETED == 1, "na overslaan niets weggegooid")

-- 5. Questloot: altijd de moeite waard
LOOT = { { id = 9100, qty = 1 } }
E("LOOT_OPENED")
check(P:IsShown() and P.lootRow.value.text:find("Quest item") and P.verdict.text:find("quest item"), "questloot: 'Quest item'")
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
E("LOOT_CLOSED")

-- 8. Melding "Inventory is full" opent het paneel ook (autoloot)
BAGS[0][3].count = 20
LOOT = { { id = 2589, qty = 2 } }
E("UI_ERROR_MESSAGE", 3, "Inventory is full.")
check(P:IsShown(), "foutmelding 'tassen vol' opent het paneel")

-- 9. "Keep this item": Torn Wing nooit meer, meteen het volgende goedkoopste item
check(P.offer.junk.e.itemID == 8001 and P.junkRow.label.text:find("Auto Sell"), "groepsnaam bij het goedkoopste item (Auto Sell)")
check(not P.keepGroup:IsShown(), "Auto Sell: geen knop 'Keep this group'")
P.keepItem:Fire("OnClick"); RunTimers()
check(CFC().keep[8001] == true, "Torn Wing onthouden als 'houden' (per karakter)")
check(P:IsShown() and P.offer.junk.e.itemID == 2589, "volgende goedkoopste: Linen Cloth")
local linenSec = P.offer.junk.sec
check(P.keepGroup:IsShown(), "andere groep: knop 'Keep this group' weer zichtbaar")
CFC().assign[2589] = nil; E("BAG_UPDATE_DELAYED"); RunTimers()
check(P.offer.junk.sec == "other" and not P.keepGroup:IsShown(), "Other: geen knop voor de hele groep")
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
E("LOOT_CLOSED"); LOOT = { { id = 2589, qty = 2 } }; E("LOOT_OPENED")
check(P:IsShown() and P.offer.junk.e.itemID == 8001, "na Wissen: Torn Wing weer voorgesteld")

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
