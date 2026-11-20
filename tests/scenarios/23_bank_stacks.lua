local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Bij de bank (Johans wens, 1.10.1): 3 potions van de bank op een stapel van 4 (max 5) = stapel vol
-- en de rest óók in je tassen (hooguit één stapel erbij). Rechtsklik op een vakje met 5+2 = alles
-- naar de bank, niet alleen de grootste stapel. Met Shift doe je het zelf (WoW's splitsen).
ITEMS = {
  [2459] = { name = "Swiftness Potion", quality = 1, stack = 5, bind = 0, icon = 3, class = 0, price = 25 },
}
BANK_CONTAINER = -1
BAGS[0] = { n = 8, [1] = { itemID = 2459, count = 4 } }
BAGS[-1] = { n = 4, [1] = { itemID = 2459, count = 3 } }
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
E("BANKFRAME_OPENED")
local function Tile(id) for _, f in ipairs(ALLFRAMES) do if f.isCarefreeItem and f.shown and f.group and f.group.itemID == id then return f end end end
local function stacks(b) local t = {}; for s = 1, BAGS[b].n do local it = BAGS[b][s]; if it and it.itemID == 2459 then t[#t + 1] = it.count end end; table.sort(t, function(x, y) return x > y end); return table.concat(t, "+") end

-- 1) 3 van de bank op de stapel van 4: 5 + 2, niets blijft op de cursor of in de bank
CURSOR = { itemID = 2459, count = 3, outside = true }; BAGS[-1][1] = nil
Tile(2459):Fire("OnReceiveDrag"); RunTimers()
check(CURSOR == nil, "cursor leeg")
check(stacks(0) == "5+2", "alles in de tassen, hooguit één stapel erbij: " .. stacks(0))
check(stacks(-1) == "", "niets meer in de bank: " .. stacks(-1))
NS.Refresh(); RunTimers()

-- 2) Rechtsklik bij de bank op het vakje (5+2): WoW zet de grootste stapel in de bank, CFB de rest
local t = Tile(2459)
local rb, rs = t.group.rep.bag, t.group.rep.slot
t:Fire("PreClick", "RightButton")
BAGS[-1][1] = BAGS[rb][rs]; BAGS[rb][rs] = nil -- wat WoW zelf doet bij rechtsklik
RunTimers()
check(stacks(0) == "", "niets meer in de tassen: " .. stacks(0))
check(stacks(-1) == "5+2", "alles in de bank: " .. stacks(-1))
check(CURSOR == nil, "cursor leeg na rechtsklik")

-- 3) Bankstapel met plek wordt eerst gevuld
BAGS[-1] = { n = 4, [1] = { itemID = 2459, count = 4 } }
BAGS[0] = { n = 8, [1] = { itemID = 2459, count = 5 }, [2] = { itemID = 2459, count = 1 } }
NS.Refresh(); RunTimers()
t = Tile(2459)
rb, rs = t.group.rep.bag, t.group.rep.slot
t:Fire("PreClick", "RightButton")
BAGS[-1][2] = BAGS[rb][rs]; BAGS[rb][rs] = nil
RunTimers()
check(stacks(-1) == "5+5" and stacks(0) == "", "eerst de bankstapel van 4 aangevuld: bank " .. stacks(-1) .. ", tassen " .. stacks(0))

-- 4) Met Shift: niets extra (zelf splitsen met WoW's eigen venster)
BAGS[0] = { n = 8, [1] = { itemID = 2459, count = 5 }, [2] = { itemID = 2459, count = 3 } }
BAGS[-1] = { n = 4 }
NS.Refresh(); RunTimers()
SHIFT = true
Tile(2459):Fire("PreClick", "RightButton"); RunTimers()
SHIFT = false
check(stacks(0) == "5+3" and stacks(-1) == "", "Shift: CFB verplaatst niets")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
