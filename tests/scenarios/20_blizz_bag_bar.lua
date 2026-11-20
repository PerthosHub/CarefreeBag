-- flavors: classic retail forever
-- Tassenbalk van WoW (BlizzBagBar.lua): vulbalk op de rugzakknop (alleen gewone vakjes),
-- andere tasvakjes verbergen (retail: CVar expandBagBar via het pijltje; classic en Forever:
-- vakjes zelf, Forever kent de CVar wel maar heeft geen pijltje en wel een reagent-vak),
-- CFB open = hele balk zichtbaar, dicht = alleen de rugzak; eenmalige vraag alleen bij een aangepaste UI.
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
  CreateFrame("Button", "KeyRingButton", UIParent) -- sleutelring: gaat mee weg
end
if FLAVOR == "forever" then
  NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
  Enum.BagIndex = { Backpack = 0, ReagentBag = 5 }
  BAGS[5] = { n = 20 }
  CreateFrame("Button", "CharacterReagentBag0Slot", UIParent)
  CVARS.expandBagBar = "1" -- de CVar bestaat, het pijltje-frame ook, maar onzichtbaar
  local toggle = CreateFrame("Button", "BagBarExpandToggle", UIParent); toggle.shown = false
  toggle.Click = function() CVARS.expandBagBar = (CVARS.expandBagBar == "1") and "0" or "1" end
  rawset(_G, "GetCVar", function(k) return CVARS[k] end)
  rawset(_G, "SetCVar", function(k, v) CVARS[k] = tostring(v) end)
  ACTIVE_LAYOUT = 1
  rawset(_G, "C_EditMode", { GetLayouts = function() return { activeLayout = ACTIVE_LAYOUT, layouts = {} } end })
  -- BagsBar: randen (plaatje) + naamloze achtergrond per vakje + verborgen selectiekader
  local bar = CreateFrame("Frame", "BagsBar", UIParent)
  local cluster = CreateFrame("Frame", "BagSlotCluster", bar)
  FRAME_TEX = CreateFrame("Frame"); BG1 = CreateFrame("Frame"); BG1.w = 44
  SELECTION = CreateFrame("Frame"); SELECTION.w = 314; SELECTION.shown = false
  local alpha = function(self, a) self.alpha = a end
  for _, o in ipairs({ FRAME_TEX, BG1, SELECTION, backpack }) do o.SetAlpha = alpha end
  bar.GetRegions = function() return FRAME_TEX end
  bar.GetChildren = function() return SELECTION, backpack, cluster, BG1 end
  backpack.w = 44
  CharacterBag0Slot.GetParent = function() return cluster end
  cluster.GetParent = function() return bar end
end
local function SlotsHidden()
  if FLAVOR == "retail" then return CVARS.expandBagBar == "0" end
  local all = not CharacterBag0Slot:IsShown() and not CharacterBag3Slot:IsShown() and not KeyRingButton:IsShown()
  if FLAVOR == "forever" then all = all and not CharacterReagentBag0Slot:IsShown() end
  return all
end
local function SlotsShown()
  if FLAVOR == "retail" then return CVARS.expandBagBar == "1" end
  local all = CharacterBag0Slot:IsShown() and CharacterBag3Slot:IsShown() and KeyRingButton:IsShown()
  if FLAVOR == "forever" then all = all and CharacterReagentBag0Slot:IsShown() end
  return all
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
if FLAVOR == "classic" then LOADED_ADDONS.Bartender4 = true else ACTIVE_LAYOUT = 3 end
NS.BagBarAsk()
check(#POPUPS == 1 and POPUPS[1].which == "CAREFREEBAG_BAGBAR", "aangepaste UI: vraag gesteld")
StaticPopupDialogs.CAREFREEBAG_BAGBAR.OnAccept()
check(CFC().hideBagSlots == true and SlotsHidden(), "Ja: andere tasvakjes verborgen")
if FLAVOR == "retail" then check(layouts == 1, "via WoW's eigen inklap-pijltje") end
if FLAVOR == "forever" then check(CVARS.expandBagBar == "1", "Forever: onzichtbaar pijltje niet gebruikt, vakjes zelf verborgen") end
if FLAVOR ~= "retail" then check(not KeyRingButton:IsShown(), "sleutelring ook weg") end
if FLAVOR == "forever" then
  check(FRAME_TEX.alpha == 0 and BG1.alpha == 0, "Forever: randen en zwarte achtergrond onzichtbaar")
  check(SELECTION.alpha == nil and backpack.alpha == nil, "selectiekader en rugzak niet aangeraakt")
end
NS.BagBarAsk()
check(#POPUPS == 1, "niet nog eens vragen")

-- D. CFB open = hele balk zichtbaar (tassen, sleutelring, achtergrond); dicht = weer weg.
check(not CarefreeBagFrame:IsShown(), "CFB-venster is dicht")
SlashCmdList.CAREFREEBAG("show")
check(CarefreeBagFrame:IsShown() and SlotsShown(), "CFB open: tasvakjes zichtbaar")
if FLAVOR ~= "retail" then check(KeyRingButton:IsShown(), "CFB open: sleutelring zichtbaar") end
if FLAVOR == "forever" then check(BG1.alpha == 1 and FRAME_TEX.alpha == 1, "CFB open: achtergrond terug") end
CarefreeBagFrame:Hide()
check(SlotsHidden(), "CFB dicht: alleen de rugzak")
if FLAVOR ~= "retail" then
  CharacterBag0Slot:Show()
  check(not CharacterBag0Slot:IsShown(), "WoW toont een vakje, wij verbergen het weer")
end

-- D2. CFB uit = de normale balk terug; weer aan = verborgen.
NS.SetEnabled(false)
check(SlotsShown(), "CFB uit: normale tassenbalk")
NS.SetEnabled(true)
check(SlotsHidden(), "CFB weer aan: verborgen")

-- E. In gevecht niets aan de balk veranderen; na het gevecht de stand van dat moment.
COMBAT = true
SlashCmdList.CAREFREEBAG("show")
check(SlotsHidden(), "in gevecht geopend: nog niets veranderd")
CarefreeBagFrame:Hide()
NS.SetHideBagSlots(false)
check(SlotsHidden(), "in gevecht: optie uit, nog niets veranderd")
COMBAT = nil; E("PLAYER_REGEN_ENABLED")
check(SlotsShown() and CFC().hideBagSlots == false, "na het gevecht: vakjes terug")

-- F. Al ingeklapt (zelf gedaan): niet vragen, keuze = verbergen.
CFC().hideBagSlots = nil
if FLAVOR == "retail" then CVARS.expandBagBar = "0" else for i = 0, 3 do _G["CharacterBag" .. i .. "Slot"]:Hide() end end
NS.BagBarAsk()
check(#POPUPS == 1 and CFC().hideBagSlots == true, "al ingeklapt: geen vraag, onthouden als verborgen")

-- H. Alleen terugzetten wat wij verborgen (review): een sleutelring die WoW zelf verborg, blijft weg.
NS.SetHideBagSlots(false)
if FLAVOR ~= "retail" then
  for i = 0, 3 do _G["CharacterBag" .. i .. "Slot"]:Show() end -- stap F verborg ze "zelf"
  KeyRingButton:Hide() -- bijv. geen sleutels: WoW verbergt de knop zelf
  NS.SetHideBagSlots(true)
  check(not CharacterBag0Slot:IsShown(), "verborgen")
  SlashCmdList.CAREFREEBAG("show")
  check(CharacterBag0Slot:IsShown() and not KeyRingButton:IsShown(), "CFB open: tassen terug, door WoW verborgen sleutelring blijft weg")
  CarefreeBagFrame:Hide()
else
  -- retail: de ingeklapte CVar blijft bewaard; wíj klapten hem in, dus niet "al ingeklapt" voor een ander karakter
  NS.SetHideBagSlots(true)
  check(CVARS.expandBagBar == "0" and CarefreeBagDB.bagBarCollapsedByUs == true, "retail: onthouden dat wij inklapten")
  local before = #POPUPS
  CFC().hideBagSlots = nil
  NS.BagBarAsk()
  check(#POPUPS == before + 1, "door ons ingeklapt telt niet als 'al ingeklapt': wel vragen")
  NS.SetHideBagSlots(false)
  check(CVARS.expandBagBar == "1" and CarefreeBagDB.bagBarCollapsedByUs == nil, "uitgeklapt, vlag weg")
end

-- G. Opties: twee vinkjes in Advanced.
local labels = {}
for _, o in ipairs(ALLFRAMES) do if o.text and o.text ~= "" then labels[o.text] = true end end
check(labels["Fill bar on the backpack"] and labels["Hide the other bag slots"], "vinkjes in de opties")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
