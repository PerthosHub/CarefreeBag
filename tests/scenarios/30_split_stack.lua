local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Johan (2026-11-24): 20 Solid Sharpening Stones splitsen in 2× 10 lukte niet. CFB toont één vakje
-- per item, dus terugleggen op het item voegde de 10 weer samen. Nu: gesplitste stapel op het item,
-- de achtergrond of een "+" = in een vrij vakje.
ITEMS = {
  [7964] = { name = "Solid Sharpening Stone", quality = 1, stack = 20, bind = 0, icon = 3, class = 0, price = 10 },
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 4, class = 0, price = 10 },
}
BAGS[0] = { n = 8, [1] = { itemID = 7964, count = 20 }, [2] = { itemID = 4599, count = 5 } }
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
local function Tile(id) for _, f in ipairs(ALLFRAMES) do if f.isCarefreeItem and f.shown and f.group and f.group.itemID == id then return f end end end
local function stacks(id) local n, t = 0, {} for s = 1, BAGS[0].n do local it = BAGS[0][s]; if it and it.itemID == id then n = n + 1; t[#t+1] = it.count end end; return n, t end

-- 1) Splitsen (zoals WoW's splitsvenster doet): vanger ligt over het item
C_Container.SplitContainerItem(0, 1, 10)
local t = Tile(7964)
check(t.splitCatch and t.splitCatch.shown, "vanger zichtbaar na splitsen")
t.splitCatch:Fire("OnClick", "LeftButton"); RunTimers()
local n, c = stacks(7964)
check(CURSOR == nil and n == 2 and c[1] == 10 and c[2] == 10, "2× 10 in de tas (" .. n .. " stapels)")
check(not t.splitCatch.shown, "vanger weer weg")
E("BAG_UPDATE_DELAYED"); RunTimers(); E("BAG_UPDATE_DELAYED"); RunTimers()
n = stacks(7964)
check(n == 2, "zelf gesplitst: niet vanzelf weer samengevoegd (" .. n .. " stapels)")

-- 1b) Zoals in het spel (log 21:24): WoW meldt de tas-wijziging al vóór de neergelegde stapel in
-- zijn vakje staat. Dan even maar 1 stapel te zien; daarna mag hij toch niet samengevoegd worden.
BAGS[0][1] = { itemID = 7964, count = 20 }; BAGS[0][3] = nil
E("BAG_UPDATE_DELAYED"); RunTimers()
C_Container.SplitContainerItem(0, 1, 10)
CURSOR = nil -- onderweg naar het vrije vakje
E("BAG_UPDATE_DELAYED"); RunTimers()
BAGS[0][3] = { itemID = 7964, count = 10 } -- nu pas in het vakje
E("BAG_UPDATE_DELAYED"); RunTimers(); E("BAG_UPDATE_DELAYED"); RunTimers()
n = stacks(7964)
check(n == 2, "stapel nog onderweg: daarna niet samengevoegd (" .. n .. " stapels)")

-- 1c) Twee vakjes in het venster (Johan, 2026-11-25), elk met zijn eigen aantal, naast elkaar
local function tiles(id) local t = {} for _, f in ipairs(ALLFRAMES) do if f.isCarefreeItem and f.shown and f.group and f.group.itemID == id then t[#t+1] = f.group.count end end table.sort(t); return table.concat(t, "+"), #t end
check(tiles(7964) == "10+10", "twee vakjes van 10: " .. tiles(7964))
-- na /reload nog steeds apart en niet samengevoegd
for _, f in ipairs(ALLFRAMES) do if f.isCarefreeItem then f.shown, f.isCarefreeItem = false, nil end end -- oud venster weg
NS = {}; LoadAddon(NS)
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); NOW = NOW + 60
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
n = stacks(7964)
check(n == 2, "na /reload niet samengevoegd (" .. n .. " stapels)")
-- zelf weer op elkaar gelegd: na 5 s vergeten, weer 1 vakje
BAGS[0][1] = { itemID = 7964, count = 20 }; BAGS[0][3] = nil
E("BAG_UPDATE_DELAYED"); NOW = NOW + 6; E("BAG_UPDATE_DELAYED"); RunTimers()
check(not CFC().splitKeep[7964] and select(2, tiles(7964)) == 1, "weer samen: 1 vakje (" .. tiles(7964) .. ")")
C_Container.SplitContainerItem(0, 1, 10); Tile(7964).splitCatch:Fire("OnClick", "LeftButton"); RunTimers()
E("BAG_UPDATE_DELAYED"); RunTimers()

-- 2) Splitsen en op de achtergrond laten vallen
C_Container.SplitContainerItem(0, 1, 4)
CarefreeBagFrame:Fire("OnReceiveDrag"); RunTimers()
n = stacks(7964)
check(CURSOR == nil and n == 3, "achtergrond: in een vrij vakje (" .. n .. " stapels)")

-- 3) Gewoon oppakken (geen splitsing) en terugleggen: geen vanger, oud gedrag
E("BAG_UPDATE_DELAYED"); RunTimers()
CURSOR = { itemID = 4599, count = 5 }; BAGS[0][2] = nil
check(not Tile(7964).splitCatch.shown, "geen vanger bij gewoon oppakken")
CURSOR = nil; BAGS[0][2] = { itemID = 4599, count = 5 }

-- 4) Niet zelf gesplitst: losse stapels worden gewoon samengevoegd
BAGS[0][7] = { itemID = 4599, count = 3 }
E("BAG_UPDATE_DELAYED"); RunTimers(); E("BAG_UPDATE_DELAYED"); RunTimers()
n = stacks(4599)
check(n == 1, "ander item: wel samengevoegd (" .. n .. " stapels)")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
