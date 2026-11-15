-- flavors: classic retail
-- Andere WoW-versies: FLAVOR = "classic" (keyring, geen moderne extra's) of "retail" (reagent-tas)
local function check(c, msg) if not c then error("MISLUKT [" .. FLAVOR .. "]: " .. msg, 2) end print("ok  [" .. FLAVOR .. "] " .. msg) end
ITEMS = {
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 3, class = 0, sub = 5, price = 10 },
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, class = 7, price = 5 },
  [3000] = { name = "Grey Junk", quality = 0, stack = 1, bind = 0, icon = 7, class = 15, price = 50 },
  [5000] = { name = "Silver Key", quality = 1, stack = 1, bind = 1, icon = 8, class = 13 },
}
BAGS[0] = { n = 6, [1] = { itemID = 4599, count = 5 }, [2] = { itemID = 2589, count = 5 }, [3] = { itemID = 3000, count = 1 } }
if FLAVOR == "classic" then
  TooltipDataProcessor = nil; rawset(_G, "UnitNameUnmodified", nil)
  KEYRING_CONTAINER = -2
  BAGS[-2] = { n = 4, [1] = { itemID = 5000, count = 1, bound = true } }
else
  NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
  Enum.BagIndex = { Backpack = 0, ReagentBag = 5, Keyring = -2 }
  BAGS[5] = { n = 4 } -- lege reagent-tas
end
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
CarefreeBagDB.lang = "en"
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
check(CarefreeBagFrame:IsShown() and CarefreeBagDB.lastError == nil, "tassen openen zonder fout")
local names = {}
for i = 1, 50 do local b = _G["CarefreeBagItem" .. i]; if b and b:IsShown() then names[b.group.name] = b end end
check(names["Cured Ham Steak"] and names["Linen Cloth"] and names["Grey Junk"], "items zichtbaar")
if FLAVOR == "classic" then
  CarefreeBagDB.fixedOn.keys = true; CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
  local key; for i = 1, 50 do local b = _G["CarefreeBagItem" .. i]; if b and b:IsShown() and b.group.name == "Silver Key" then key = b end end
  check(key, "sleutel uit de keyring zichtbaar in Keys")
else
  local key; for i = 1, 50 do local b = _G["CarefreeBagItem" .. i]; if b and b:IsShown() and b.group.name == "Silver Key" then key = b end end
  check(not key, "geen keyring in retail")
end
-- vendor: grijs item verkopen
CarefreeBagDB.autoSell, CarefreeBagDB.autoSellAsked = true, true
MerchantFrame.shown = true; E("MERCHANT_SHOW"); RunTimers(); RunTimers()
check(SOLD[1] == 3000, "grijs item verkocht bij de vendor")
-- mail naar een alt
local c = CFC().cats[1]; c.mailTo = "Thrall-Stormrage"
print("lastError:", CarefreeBagDB.lastError)
local miss = {}; for k in pairs(MISSING) do miss[#miss+1] = k end; table.sort(miss)
print("niet-bestaande globals opgevraagd:", table.concat(miss, " "))
if FLAVOR == "retail" then
  -- rugzak vol, alleen de reagent-tas heeft plek
  for s = 4, 6 do BAGS[0][s] = { itemID = 2589, count = 1 } end
  SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
  BAGS[0][1] = nil; E("BAG_UPDATE_DELAYED"); RunTimers() -- ham is op: er komt een gat
  local gap; for _, f in ipairs(ALLFRAMES) do if f.bg and f:IsShown() and f.scripts and f.scripts.OnReceiveDrag and not f.section then gap = f end end
  CURSOR = { itemID = 4599, count = 1 }
  -- het enige vrije vakje is in de reagent-tas: daar mag ham niet in
  local before = BAGS[5][1]
  if gap then gap:Fire("OnReceiveDrag"); RunTimers() end
  check(BAGS[5][1] == before, "geen gewoon item in de reagent-tas" .. (gap and "" or " (geen gat gevonden)"))
end
