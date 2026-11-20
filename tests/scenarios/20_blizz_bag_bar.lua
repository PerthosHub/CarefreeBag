-- flavors: classic retail
-- Tassenbalk van WoW (BlizzBagBar.lua): vulbalk op de rugzakknop (alleen gewone vakjes),
-- andere tasvakjes verbergen (retail: CVar expandBagBar via het pijltje, classic: vakjes zelf),
-- tas slepen = vakjes even terug, eenmalige vraag alleen bij een aangepaste UI.
local function check(c, msg) if not c then error("MISLUKT [" .. FLAVOR .. "]: " .. msg, 2) end print("ok  [" .. FLAVOR .. "] " .. msg) end

ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, class = 7, price = 5 },
  [4241] = { name = "Linen Bag", quality = 1, stack = 1, bind = 0, icon = 1, price = 100, class = 1, sub = 0, equip = "INVTYPE_BAG" },
}
-- rugzak 16 vakjes, 12 vol; tas 1 = beroepstas (telt niet mee); tas 2 = gewone tas 4 vakjes, leeg
BAGS[0] = { n = 16 }
for s = 1, 12 do BAGS[0][s] = { itemID = 2589, count = 20 } end
BAGS[1] = { n = 10, family = 8 }
BAGS[2] = { n = 4 }
function C_Container.GetContainerNumFreeSlots(b)
  local bag = BAGS[b]; if not bag then return 0, 0 end
  local f = 0
  for s = 1, bag.n do if not bag[s] then f = f + 1 end end
  return f, bag.family or 0
end

local backpack = CreateFrame("Button", "MainMenuBarBackpackButton", UIParent)
CVARS = {}
local layouts = 0
if FLAVOR == "retail" then
  NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
  Enum.BagIndex = { Backpack = 0, ReagentBag = 5 }
  BAGS[5] = { n = 20 } -- lege reagent-tas: telt niet mee
  CVARS.expandBagBar = "1"
  rawset(_G, "GetCVar", function(k) return CVARS[k] end)
  rawset(_G, "SetCVar", function(k, v) CVARS[k] = tostring(v) end)
  local toggle = CreateFrame("Button", "BagBarExpandToggle", UIParent)
  toggle.Click = function() CVARS.expandBagBar = (CVARS.expandBagBar == "1") and "0" or "1"; layouts = layouts + 1 end
  ACTIVE_LAYOUT = 1 -- Blizzard-layout (Modern)
  rawset(_G, "C_EditMode", { GetLayouts = function() return { activeLayout = ACTIVE_LAYOUT, layouts = {} } end })
else
  for i = 0, 3 do CreateFrame("Button", "CharacterBag" .. i .. "Slot", UIParent) end
end
local function SlotsHidden()
  if FLAVOR == "retail" then return CVARS.expandBagBar == "0" end
  return not CharacterBag0Slot:IsShown() and not CharacterBag3Slot:IsShown()
end

LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()

-- A. Vulbalk: 12 van 20 gewone vakjes vol (beroepstas en reagent-tas tellen niet).
local fill = CarefreeBagBackpackFill
check(fill and fill.parent == backpack, "vulbalk hangt aan de rugzakknop van WoW")
check(fill.total == 20 and fill.free == 8, "alleen gewone vakjes: " .. tostring(fill.free) .. "/" .. tostring(fill.total))
check(math.abs(fill.frac - 0.6) < 0.001 and fill:IsShown(), "60% vol, zichtbaar")
BAGS[2][1] = { itemID = 2589, count = 20 }
E("BAG_UPDATE_DELAYED")
check(fill.free == 7, "bijgewerkt na BAG_UPDATE_DELAYED")
CarefreeBagDB.bagFill = false; NS.UpdateBackpackFill()
check(not fill:IsShown(), "optie uit: vulbalk weg")
CarefreeBagDB.bagFill = true; NS.UpdateBackpackFill()

-- B. Standaard-UI: niet vragen, vakjes blijven staan.
check(#POPUPS == 0 and not SlotsHidden(), "standaard-UI: geen vraag, vakjes zichtbaar")
check(CFC().hideBagSlots == nil, "nog geen keuze opgeslagen")

-- C. Aangepaste UI (eigen layout / balk-addon): één keer vragen; Ja = verbergen.
if FLAVOR == "retail" then ACTIVE_LAYOUT = 3 else LOADED_ADDONS.Bartender4 = true end
NS.BagBarAsk()
check(#POPUPS == 1 and POPUPS[1].which == "CAREFREEBAG_BAGBAR", "aangepaste UI: vraag gesteld")
StaticPopupDialogs.CAREFREEBAG_BAGBAR.OnAccept()
check(CFC().hideBagSlots == true and SlotsHidden(), "Ja: andere tasvakjes verborgen")
if FLAVOR == "retail" then check(layouts == 1, "via WoW's eigen inklap-pijltje") end
NS.BagBarAsk()
check(#POPUPS == 1, "niet nog eens vragen")

-- D. Tas slepen: vakjes even terug, daarna weer weg. Gewoon item: niets.
CURSOR = { itemID = 2589, count = 20 }; E("CURSOR_CHANGED"); E("CURSOR_UPDATE")
check(SlotsHidden(), "gewoon item op de cursor: vakjes blijven weg")
CURSOR = { itemID = 4241, count = 1 }; E("CURSOR_CHANGED"); E("CURSOR_UPDATE")
check(not SlotsHidden(), "tas op de cursor: vakjes zichtbaar")
CURSOR = nil; E("CURSOR_CHANGED"); E("CURSOR_UPDATE"); RunTimers()
check(SlotsHidden(), "tas losgelaten: vakjes weer weg")
if FLAVOR == "classic" then
  CharacterBag0Slot:Show()
  check(not CharacterBag0Slot:IsShown(), "classic: WoW toont een vakje, wij verbergen het weer")
end

-- E. In gevecht niets aan de balk veranderen; na het gevecht wel.
COMBAT = true
NS.SetHideBagSlots(false)
check(SlotsHidden(), "in gevecht: nog niets veranderd")
COMBAT = nil; E("PLAYER_REGEN_ENABLED")
check(not SlotsHidden() and CFC().hideBagSlots == false, "na het gevecht: vakjes terug")

-- F. Al ingeklapt (zelf gedaan): niet vragen, keuze = verbergen.
CFC().hideBagSlots = nil
if FLAVOR == "retail" then CVARS.expandBagBar = "0" else for i = 0, 3 do _G["CharacterBag" .. i .. "Slot"]:Hide() end end
NS.BagBarAsk()
check(#POPUPS == 1 and CFC().hideBagSlots == true, "al ingeklapt: geen vraag, onthouden als verborgen")

-- G. Opties: twee vinkjes in Advanced.
local labels = {}
for _, o in ipairs(ALLFRAMES) do if o.text and o.text ~= "" then labels[o.text] = true end end
check(labels["Fill bar on the backpack"] and labels["Hide the other bag slots"], "vinkjes in de opties")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
