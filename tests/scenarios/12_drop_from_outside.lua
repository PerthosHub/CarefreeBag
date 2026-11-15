local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Iets wat je aan hebt (of van de bank) naar de tassen slepen: het moet in een vrij vakje komen.
ITEMS = {
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 3 },
  [7001] = { name = "Worn Helmet", quality = 1, stack = 1, bind = 0, icon = 4, equip = "INVTYPE_HEAD" },
  [7002] = { name = "Worn Boots", quality = 1, stack = 1, bind = 0, icon = 5, equip = "INVTYPE_FEET" },
  [7003] = { name = "Worn Gloves", quality = 1, stack = 1, bind = 0, icon = 6, equip = "INVTYPE_HAND" },
}
BAGS[0] = { n = 4, [1] = { itemID = 4599, count = 5 } }

local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
CarefreeBagDB = { cats = { { key = "gear", name = "Gear" } } }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
local function A() for _, ch in pairs(CarefreeBagDB.chars) do return ch.assign end end
local function plus(key) for _, f in ipairs(ALLFRAMES) do if f.section == key and f:IsShown() then return f end end end
local function count()
  local n = 0; for s = 1, BAGS[0].n do if BAGS[0][s] then n = n + 1 end end; return n
end

-- 1) Helm van je karakter op het "+"-vakje van groep Gear
check(plus("gear"), "groep Gear heeft een + vakje")
CURSOR = { itemID = 7001, count = 1, outside = true }
plus("gear"):Fire("OnReceiveDrag"); RunTimers()
check(CURSOR == nil, "cursor leeg")
check(count() == 2, "helm ligt nu in een vrij vakje")
check(A()[7001] == "gear", "en hoort bij Gear")
E("BAG_UPDATE_DELAYED"); RunTimers()

-- 2) Laarzen op de achtergrond van het venster
CURSOR = { itemID = 7002, count = 1, outside = true }
CarefreeBagFrame:Fire("OnReceiveDrag"); RunTimers()
check(CURSOR == nil and count() == 3, "laarzen op het venster = in een vrij vakje")
E("BAG_UPDATE_DELAYED"); RunTimers()

-- 3) Handschoenen op de vulbalk
CURSOR = { itemID = 7003, count = 1, outside = true }
CarefreeBagFreeBar:Fire("OnReceiveDrag"); RunTimers()
check(CURSOR == nil and count() == 4, "handschoenen op de vulbalk = in een vrij vakje")
E("BAG_UPDATE_DELAYED"); RunTimers()

-- 4) Tassen vol: helm blijft op de cursor (gaat terug), melding
CURSOR = { itemID = 7001, count = 1, outside = true }
local before = #LOG
CarefreeBagFrame:Fire("OnReceiveDrag"); RunTimers()
check(CURSOR ~= nil and count() == 4, "tassen vol: niets gelegd")
local err = false; for i = before + 1, #LOG do if LOG[i]:find("^ERR ") then err = true end end
check(err, "melding dat je tassen vol zijn")
CURSOR = nil

-- 5) Item uit je eigen tas op het venster: blijft gewoon op de cursor, niet verplaatst
BAGS[0][4] = nil; E("BAG_UPDATE_DELAYED"); RunTimers()
CURSOR = { itemID = 4599, count = 5 }
CarefreeBagFrame:Fire("OnReceiveDrag"); RunTimers()
check(CURSOR ~= nil and count() == 3, "item uit de tas zelf: niets verplaatst")
CURSOR = nil
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
