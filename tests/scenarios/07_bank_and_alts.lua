local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
ITEMS = {
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 3, class = 0, sub = 5, price = 10 },
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, class = 7, price = 5 },
  [2000] = { name = "Green Sword", quality = 2, stack = 1, bind = 2, icon = 6, class = 2, equip = "INVTYPE_WEAPON" },
}
BAGS[0] = { n = 6, [1] = { itemID = 4599, count = 5 }, [2] = { itemID = 2589, count = 5 } }
BANK_CONTAINER = -1; NUM_BANKBAGSLOTS = 2
BAGS[-1] = { n = 4, [1] = { itemID = 2589, count = 20 }, [2] = { itemID = 2000, count = 1 } }
BAGS[6] = { n = 2, [1] = { itemID = 2589, count = 7 } }
LOADED_ADDONS = {}
function UnitName() return "Thrall" end -- Forever: alleen de voornaam
local function Load(surname)
  rawset(_G, "UnitNameUnmodified", function() return "Thrall", surname end)
  local NS = {}; CFB_NS = NS
  LoadAddon(NS)
  DRIVER:Fire("OnEvent", "ADDON_LOADED", "CarefreeBag"); DRIVER:Fire("OnEvent", "PLAYER_LOGIN"); RunTimers()
end
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
local function tiles() local n = {}; for _, f in ipairs(ALLFRAMES) do if f.link and f.shown and f.parent == CarefreeBagViewer.content then n[#n+1] = f.link:match("%[(.-)%]") end end table.sort(n); return n end
-- oude data van voor 1.5.0: één sleutel "Thrall-" gedeeld door beide Thrallsen
CarefreeBagDB = { lang = "en", chars = { ["Thrall-"] = { assign = { [2589] = "prof" }, cats = { { key = "prof", preset = "prof" } },
  snap = { name = "Thrall Stormrage", bags = {} } } } }
Load("Frostwolf")
local A = CarefreeBagDB.chars["Thrall Frostwolf-"]
check(A and A.assign[2589] == "prof", "migratie: Frostwolf krijgt een kopie van wat hij geleerd had")
check(#A.cats == 3 and A.cats[1].key == "consum", "Frostwolf krijgt de groepen van voor 1.3.0 terug, niet die van Stormrage: " .. #A.cats)
check(CarefreeBagDB.chars["Thrall-"].legacy and not CarefreeBagDB.chars["Thrall-"].snap, "oude sleutel wordt niet meer als karakter getoond")
check(A.snap and #A.snap.bags == 2, "tassen van Frostwolf onthouden")
E("BANKFRAME_OPENED")
local linen = 0; for _, r in ipairs(A.snap.bank or {}) do if r.id == 2589 then linen = r.n end end
check(linen == 27, "bank van Frostwolf onthouden (20+7)")
-- bij het sluiten van de bank en bij uitloggen zijn de vakken (deels) leeg: niet overschrijven
local bankSave, bagSave = BAGS[-1], BAGS[0]
BAGS[-1] = { n = 4 }
E("BANKFRAME_CLOSED"); E("PLAYER_LOGOUT")
linen = 0; for _, r in ipairs(A.snap.bank or {}) do if r.id == 2589 then linen = r.n end end
check(linen == 27 and #A.snap.bags == 2, "sluiten/uitloggen wist de onthouden bank en tassen niet")
BAGS[-1] = bankSave
-- tweede karakter met dezelfde voornaam
BAGS[0] = { n = 6, [1] = { itemID = 2000, count = 1 } }; BAGS[-1] = { n = 4 }; BAGS[6] = nil
Load("Stormrage")
local B = CarefreeBagDB.chars["Thrall Stormrage-"]
check(B and #B.cats == 1 and B.cats[1].key == "prof", "Stormrage (laatst ingelogd) houdt zijn aangepaste groepen")
check(B and B ~= A and A.snap.bank, "Stormrage heeft eigen gegevens, Frostwolf blijft bewaard")
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED")
CarefreeBagBankButton:Fire("OnClick"); RunTimers()
check(CarefreeBagViewer:IsShown() and CarefreeBagViewer.part == "bank" and CarefreeBagViewer.key == "Thrall Stormrage-", "standaard: bank van jezelf")
check(CarefreeBagViewer.title == "Your bank", "titel: jouw bank")
check(not CarefreeBagViewer.tabs.bags:IsShown(), "bij jezelf geen knop Tassen (die staan al open)")
-- karakter wisselen: portretten links, jij eerst, gekozen = gouden rand
local P = CFB_NS.viewPortraits
local function shownP() local n = {}; for _, p in ipairs(P) do if p.shown then n[#n+1] = p.char.name end end return table.concat(n, ",") end
check(shownP() == "Thrall Stormrage,Thrall Frostwolf", "portretten (jij eerst): " .. shownP())
check(P[1].sel.shown and not P[2].sel.shown, "gouden rand om wie je bekijkt")
P[2]:Fire("OnClick")
check(CarefreeBagViewer.title == "Bank of Thrall Frostwolf", "titel: bank van Frostwolf: " .. tostring(CarefreeBagViewer.title))
check(CarefreeBagViewer.tabs.bags:IsShown(), "bij een ander karakter wel Tassen en Bank")
check(table.concat(tiles(), ",") == "Green Sword,Linen Cloth", "bank van Frostwolf: " .. table.concat(tiles(), ","))
CarefreeBagViewer.tabs.bags:Fire("OnClick")
check(CarefreeBagViewer.title == "Bags of Thrall Frostwolf", "titel: tassen van Frostwolf")
check(table.concat(tiles(), ",") == "Cured Ham Steak,Linen Cloth", "tassen van Frostwolf: " .. table.concat(tiles(), ","))
check(CarefreeBagViewer.note.text:find("Updated"), "toont wanneer bijgewerkt")
check(not CarefreeBagViewer.offWarn, "CFB aan voor Frostwolf (of onbekend): geen waarschuwing")
-- CFB staat uit voor Frostwolf in WoW's AddOns-lijst (volledige naam, zoals Forever; 0 = uit)
C_AddOns.GetAddOnEnableState = function(addon, who) return (addon == "CarefreeBag" and who == "Thrall Frostwolf") and 0 or 2 end
CarefreeBagViewer.tabs.bank:Fire("OnClick")
check(CarefreeBagViewer.offWarn and CarefreeBagViewer.offNote.shown and CarefreeBagViewer.offNote.text:find("off for this character"),
  "CFB uit voor Frostwolf: waarschuwing in het paneel")
check(table.concat(tiles(), ",") == "Green Sword,Linen Cloth", "items staan er nog wel (onder de waarschuwing)")
C_AddOns.GetAddOnEnableState = nil
CarefreeBagViewer.tabs.bags:Fire("OnClick")
check(not CarefreeBagViewer.offWarn and not CarefreeBagViewer.offNote.shown, "weer aan: waarschuwing weg")
CarefreeBagFrame:Hide(); check(not CarefreeBagViewer:IsShown(), "paneel gaat dicht met de tassen")
SlashCmdList.CAREFREEBAG("show"); CarefreeBagBankButton:Fire("OnClick"); RunTimers()
local seen; for _, f in ipairs(ALLFRAMES) do if f.shown and type(f.text) == "string" and f.text:find("Visit a banker") then seen = true end end
check(CarefreeBagViewer.key == "Thrall Stormrage-" and seen, "opnieuw open: weer je eigen bank (nog nooit bezocht = uitleg)")
-- zoeken: hits op de bank en bij alts
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
check(not CarefreeBagViewer:IsShown(), "bankpaneel dicht voor het zoeken")
local function search(t) CarefreeBagSearch:SetText(t); CarefreeBagSearch:Fire("OnTextChanged"); RunTimers() end
search("l")
check(not CarefreeBagViewer:IsShown() and (CarefreeBagBankButton.hits == nil or CarefreeBagBankButton.hits.text == ""), "1 teken: nog niet zoeken")
search("linen")
check(CarefreeBagViewer:IsShown() and CarefreeBagViewer.key == "Thrall Frostwolf-" and CarefreeBagViewer.part == "bags", "hits: paneel opent bij de alt, eerst tassen")
check(CarefreeBagBankButton.hits.text == 2 and CarefreeBagBankButton.glow.shown, "getal en gloed op Bank & alts: " .. tostring(CarefreeBagBankButton.hits.text))
check(P[2].hits.text == 2 and P[1].hits.text == "", "portret van Frostwolf toont 2 hits")
check(CarefreeBagViewer.tabs.bank.text:find("1"), "knop Bank toont ook een hit: " .. CarefreeBagViewer.tabs.bank.text)
search("")
check(not CarefreeBagViewer:IsShown() and not CarefreeBagBankButton.glow.shown, "zoekbalk leeg: paneel (zelf geopend door zoeken) weer dicht")
search("linen"); CarefreeBagViewer:Hide(); search("linen c")
check(not CarefreeBagViewer:IsShown(), "zelf dichtgedaan tijdens zoeken: blijft dicht")
-- #18: knop Bank & alts = altijd eerst je eigen bank, ook met hits bij een alt
CarefreeBagViewer:Hide(); CarefreeBagViewer.noAuto = nil
CarefreeBagBankButton:Fire("OnClick"); RunTimers()
check(CarefreeBagViewer:IsShown() and CarefreeBagViewer.key == "Thrall Stormrage-" and CarefreeBagViewer.part == "bank",
  "#18: knop opent je eigen bank, ook met zoek-hits bij een alt")
CarefreeBagViewer:Hide()
search("")
CarefreeBagBankButton:Fire("OnClick"); RunTimers()
-- opties en bankpaneel: vast links naast de tassen, één tegelijk
CarefreeBagOptionsButton:Fire("OnClick"); RunTimers()
check(CarefreeBagConfig:IsShown() and CarefreeBagConfig.docked and not CarefreeBagViewer:IsShown(), "opties vast naast de tassen, bankpaneel dicht")
CarefreeBagBankButton:Fire("OnClick"); RunTimers()
check(CarefreeBagViewer:IsShown() and not CarefreeBagConfig:IsShown(), "bankpaneel open: opties dicht")
CarefreeBagOptionsButton:Fire("OnClick"); RunTimers()
CarefreeBagFrame:Hide()
check(not CarefreeBagConfig:IsShown(), "opties gaan dicht met de tassen")
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagFrame:IsShown() and CarefreeBagConfig:IsShown() and CarefreeBagConfig.docked, "/cfb opent de tassen met de opties ernaast")
CarefreeBagConfig:Hide()
-- tooltip
local lines = {}
GameTooltip.GetItem = function() return "Linen Cloth", "|cff|Hitem:2589|h[Linen Cloth]|h|r" end
GameTooltip.GetOwner = function() return nil end
GameTooltip.AddLine = function(_, t) lines[#lines+1] = t end
GameTooltip.AddDoubleLine = function(_, a, b) lines[#lines+1] = a .. " = " .. b end
POSTCALL(GameTooltip)
check(table.concat(lines, "|"):find("Thrall Frostwolf = Bags 5, Bank 27"), "tooltip: " .. table.concat(lines, " | "))
print("lastError:", CarefreeBagDB.lastError)
