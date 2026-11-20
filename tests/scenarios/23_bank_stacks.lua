local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Bij de bank (Johans wens, 1.10.1, simpel gehouden):
-- * 3 potions van de bank op een stapel van 4 (max 5) = stapel vol en de rest óók in je tassen.
-- * Een vakje (5+2) naar de bank slepen = alle stapels naar de bank.
-- * Rechtsklik en Shift-klik (splitsen) blijven gewoon WoW: CFB doet er niets extra mee.
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
-- Vakje oppakken zoals WoW doet (klik), en daarna ergens neerleggen.
local function PickUp(t)
  t:Fire("PreClick", "LeftButton")
  local rb, rs = t.group.rep.bag, t.group.rep.slot
  CURSOR = BAGS[rb][rs]; BAGS[rb][rs] = nil
  return rb, rs
end

-- 1) 3 van de bank op de stapel van 4: 5 + 2, niets blijft op de cursor of in de bank
CURSOR = { itemID = 2459, count = 3, outside = true }; BAGS[-1][1] = nil
Tile(2459):Fire("OnReceiveDrag"); RunTimers()
check(CURSOR == nil, "cursor leeg")
check(stacks(0) == "5+2", "alles in de tassen, hooguit één stapel erbij: " .. stacks(0))
check(stacks(-1) == "", "niets meer in de bank: " .. stacks(-1))
NS.Refresh(); RunTimers()

-- 2) Vakje (5+2) naar een leeg bankvakje slepen: alles naar de bank
PickUp(Tile(2459))
BAGS[-1][1] = CURSOR; CURSOR = nil -- in de bank gelegd
RunTimers()
check(stacks(0) == "", "niets meer in de tassen: " .. stacks(0))
check(stacks(-1) == "5+2", "alles in de bank: " .. stacks(-1))
check(CURSOR == nil, "cursor leeg")

-- 3) Bankstapel met plek wordt eerst aangevuld
BAGS[-1] = { n = 4, [1] = { itemID = 2459, count = 4 } }
BAGS[0] = { n = 8, [1] = { itemID = 2459, count = 5 }, [2] = { itemID = 2459, count = 1 } }
NS.Refresh(); RunTimers()
PickUp(Tile(2459))
BAGS[-1][2] = CURSOR; CURSOR = nil
RunTimers()
check(stacks(-1) == "5+5" and stacks(0) == "", "eerst de bankstapel van 4 aangevuld: bank " .. stacks(-1) .. ", tassen " .. stacks(0))

-- 4) Opgepakt en teruggelegd: niets gebeurt
BAGS[0] = { n = 8, [1] = { itemID = 2459, count = 5 }, [2] = { itemID = 2459, count = 3 } }
BAGS[-1] = { n = 4 }
NS.Refresh(); RunTimers()
local rb, rs = PickUp(Tile(2459))
BAGS[rb][rs] = CURSOR; CURSOR = nil
RunTimers()
check(stacks(0) == "5+3" and stacks(-1) == "", "teruggelegd: niets verplaatst")

-- 5) Rechtsklik: CFB doet niets extra (WoW zelf zet één stapel in de bank)
Tile(2459):Fire("PreClick", "RightButton"); RunTimers()
check(stacks(0) == "5+3" and stacks(-1) == "", "rechtsklik: CFB verplaatst niets extra")

-- 6) Shift-klik (splitsen): niets extra
SHIFT = true
PickUp(Tile(2459))
SHIFT = false
BAGS[-1][1] = CURSOR; CURSOR = nil
RunTimers()
check(stacks(0) == "3" and stacks(-1) == "5", "Shift: alleen wat je zelf versleept")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
