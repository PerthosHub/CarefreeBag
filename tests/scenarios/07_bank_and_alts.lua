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
function UnitName() return "Perthos" end -- Forever: alleen de voornaam
local function Load(surname)
  rawset(_G, "UnitNameUnmodified", function() return "Perthos", surname end)
  local NS = {}
  LoadAddon(NS)
  DRIVER:Fire("OnEvent", "ADDON_LOADED", "CarefreeBag"); DRIVER:Fire("OnEvent", "PLAYER_LOGIN"); RunTimers()
end
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
local function tiles() local n = {}; for _, f in ipairs(ALLFRAMES) do if f.link and f.shown and f.parent == CarefreeBagViewer.content then n[#n+1] = f.link:match("%[(.-)%]") end end table.sort(n); return n end
-- oude data van voor 1.5.0: één sleutel "Perthos-" gedeeld door beide Perthossen
CarefreeBagDB = { lang = "en", chars = { ["Perthos-"] = { assign = { [2589] = "prof" }, cats = { { key = "prof", preset = "prof" } },
  snap = { name = "Perthos Boxdrie", bags = {} } } } }
Load("Dimbringer")
local A = CarefreeBagDB.chars["Perthos Dimbringer-"]
check(A and A.assign[2589] == "prof", "migratie: Dimbringer krijgt een kopie van wat hij geleerd had")
check(#A.cats == 3 and A.cats[1].key == "consum", "Dimbringer krijgt de groepen van voor 1.3.0 terug, niet die van Boxdrie: " .. #A.cats)
check(CarefreeBagDB.chars["Perthos-"].legacy and not CarefreeBagDB.chars["Perthos-"].snap, "oude sleutel wordt niet meer als karakter getoond")
check(A.snap and #A.snap.bags == 2, "tassen van Dimbringer onthouden")
E("BANKFRAME_OPENED")
local linen = 0; for _, r in ipairs(A.snap.bank or {}) do if r.id == 2589 then linen = r.n end end
check(linen == 27, "bank van Dimbringer onthouden (20+7)")
E("BANKFRAME_CLOSED"); E("PLAYER_LOGOUT")
-- tweede karakter met dezelfde voornaam
BAGS[0] = { n = 6, [1] = { itemID = 2000, count = 1 } }; BAGS[-1] = { n = 4 }; BAGS[6] = nil
Load("Boxdrie")
local B = CarefreeBagDB.chars["Perthos Boxdrie-"]
check(B and #B.cats == 1 and B.cats[1].key == "prof", "Boxdrie (laatst ingelogd) houdt zijn aangepaste groepen")
check(B and B ~= A and A.snap.bank, "Boxdrie heeft eigen gegevens, Dimbringer blijft bewaard")
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED")
CarefreeBagBankButton:Fire("OnClick"); RunTimers()
check(CarefreeBagViewer:IsShown() and CarefreeBagViewer.part == "bank" and CarefreeBagViewer.key == "Perthos Boxdrie-", "standaard: bank van jezelf")
check(CarefreeBagViewer.pick.text:find("^Perthos Boxdrie"), "keuzeknop toont je eigen naam")
check(not CarefreeBagViewer.tabs.bags:IsShown(), "bij jezelf geen knop Tassen (die staan al open)")
CarefreeBagViewer.pick:Fire("OnClick"); RunTimers()
local names = {}; for _, b in ipairs(CarefreeBagViewMenu.buttons) do if b.shown then names[#names+1] = b.text end end
check(table.concat(names, ",") == "Perthos Boxdrie,Perthos Dimbringer", "keuzelijst met karakters (jij eerst): " .. table.concat(names, ","))
for _, b in ipairs(CarefreeBagViewMenu.buttons) do if b.text == "Perthos Dimbringer" then b:Fire("OnClick") end end
check(CarefreeBagViewer.tabs.bags:IsShown(), "bij een ander karakter wel Tassen en Bank")
check(table.concat(tiles(), ",") == "Green Sword,Linen Cloth", "bank van Dimbringer: " .. table.concat(tiles(), ","))
CarefreeBagViewer.tabs.bags:Fire("OnClick")
check(table.concat(tiles(), ",") == "Cured Ham Steak,Linen Cloth", "tassen van Dimbringer: " .. table.concat(tiles(), ","))
check(CarefreeBagViewer.note.text:find("Updated"), "toont wanneer bijgewerkt")
CarefreeBagFrame:Hide(); check(not CarefreeBagViewer:IsShown(), "paneel gaat dicht met de tassen")
SlashCmdList.CAREFREEBAG("show"); CarefreeBagBankButton:Fire("OnClick"); RunTimers()
local seen; for _, f in ipairs(ALLFRAMES) do if f.shown and type(f.text) == "string" and f.text:find("Visit a banker") then seen = true end end
check(CarefreeBagViewer.key == "Perthos Boxdrie-" and seen, "opnieuw open: weer je eigen bank (nog nooit bezocht = uitleg)")
-- tooltip
local lines = {}
GameTooltip.GetItem = function() return "Linen Cloth", "|cff|Hitem:2589|h[Linen Cloth]|h|r" end
GameTooltip.GetOwner = function() return nil end
GameTooltip.AddLine = function(_, t) lines[#lines+1] = t end
GameTooltip.AddDoubleLine = function(_, a, b) lines[#lines+1] = a .. " = " .. b end
POSTCALL(GameTooltip)
check(table.concat(lines, "|"):find("Perthos Dimbringer = Bags 5, Bank 27"), "tooltip: " .. table.concat(lines, " | "))
print("lastError:", CarefreeBagDB.lastError)
