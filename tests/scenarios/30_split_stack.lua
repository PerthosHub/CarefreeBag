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

-- 2) Splitsen en op de achtergrond laten vallen
E("BAG_UPDATE_DELAYED"); RunTimers()
C_Container.SplitContainerItem(0, 1, 4)
CarefreeBagFrame:Fire("OnReceiveDrag"); RunTimers()
n = stacks(7964)
check(CURSOR == nil and n == 3, "achtergrond: in een vrij vakje (" .. n .. " stapels)")

-- 3) Gewoon oppakken (geen splitsing) en terugleggen: geen vanger, oud gedrag
E("BAG_UPDATE_DELAYED"); RunTimers()
CURSOR = { itemID = 4599, count = 5 }; BAGS[0][2] = nil
check(not Tile(7964).splitCatch.shown, "geen vanger bij gewoon oppakken")
CURSOR = nil; BAGS[0][2] = { itemID = 4599, count = 5 }
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
