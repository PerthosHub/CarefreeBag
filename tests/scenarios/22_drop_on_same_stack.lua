local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Issue #15: een potion van de bank op een stapel van dezelfde potion laten vallen = bij die
-- stapel erbij, niet in een eigen vakje. Op een ander item of op het venster = vrij vakje.
-- (Tussen de stappen alleen hertekenen: BAG_UPDATE_DELAYED zou de stapels zelf al samenvoegen.)
ITEMS = {
  [2459] = { name = "Swiftness Potion", quality = 1, stack = 5, bind = 0, icon = 3, class = 0, price = 25 },
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 4, class = 0, price = 10 },
}
BAGS[0] = { n = 8, [1] = { itemID = 2459, count = 3 }, [2] = { itemID = 4599, count = 5 } }
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
local function Tile(id) for _, f in ipairs(ALLFRAMES) do if f.isCarefreeItem and f.shown and f.group and f.group.itemID == id then return f end end end
local function used() local n = 0; for s = 1, BAGS[0].n do if BAGS[0][s] then n = n + 1 end end; return n end

-- 1) 1 potion van de bank op de stapel van 3
CURSOR = { itemID = 2459, count = 1, outside = true }
Tile(2459):Fire("OnReceiveDrag"); RunTimers()
check(CURSOR == nil, "cursor leeg")
check(BAGS[0][1].count == 4 and used() == 2, "potion bij de stapel: 4, geen nieuw vakje (" .. BAGS[0][1].count .. ", " .. used() .. " vakjes)")
NS.Refresh(); RunTimers()

-- 2) Op een ander item (ham) laten vallen = eigen vakje (bewust ergens anders)
CURSOR = { itemID = 2459, count = 1, outside = true }
Tile(4599):Fire("OnReceiveDrag"); RunTimers()
check(CURSOR == nil and used() == 3 and BAGS[0][1].count == 4, "op een ander item: in een vrij vakje")
NS.Refresh(); RunTimers()

-- 3) Stapel van het vakje vol: dan bij een andere stapel met plek
BAGS[0][1].count = 5; NS.Refresh(); RunTimers()
CURSOR = { itemID = 2459, count = 1, outside = true }
Tile(2459):Fire("OnReceiveDrag"); RunTimers()
local small; for s = 1, BAGS[0].n do local it = BAGS[0][s]; if it and it.itemID == 2459 and s ~= 1 then small = it end end
check(CURSOR == nil and used() == 3 and small and small.count == 2, "volle stapel: bij de andere stapel erbij")
NS.Refresh(); RunTimers()

-- 4) Alle stapels vol: vrij vakje
for s = 1, BAGS[0].n do local it = BAGS[0][s]; if it and it.itemID == 2459 then it.count = 5 end end
NS.Refresh(); RunTimers()
CURSOR = { itemID = 2459, count = 1, outside = true }
Tile(2459):Fire("OnReceiveDrag"); RunTimers()
check(CURSOR == nil and used() == 4, "alle stapels vol: in een vrij vakje")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
