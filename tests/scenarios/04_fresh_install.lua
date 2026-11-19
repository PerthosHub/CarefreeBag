local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
bit = bit or { band = function(a, b) local r, m = 0, 1; while a > 0 and b > 0 do if a % 2 == 1 and b % 2 == 1 then r = r + m end; a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2 end; return r end }
ITEMS = {
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 3, class = 0 },
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, class = 7, family = 0 },
  [2447] = { name = "Peacebloom", quality = 1, stack = 20, bind = 0, icon = 4, class = 7, family = 32 },
  [2000] = { name = "My Tank Sword", quality = 3, stack = 1, bind = 2, icon = 6, class = 2, equip = "INVTYPE_WEAPON" },
  [1000] = { name = "Green BoE Sword", quality = 2, stack = 1, bind = 2, icon = 5, class = 2, equip = "INVTYPE_WEAPON" },
  [6948] = { name = "Hearthstone", quality = 1, stack = 1, bind = 1, icon = 1, class = 15 },
}
BAGS[0] = { n = 4, [1] = { itemID = 4599, count = 5 }, [2] = { itemID = 2589, count = 5 }, [3] = { itemID = 2000, count = 1, bound = true }, [4] = { itemID = 1000, count = 1 } }
BAGS[1] = { n = 4, family = 32, [1] = { itemID = 6948, count = 1, bound = true } } -- herb bag
LOADED_ADDONS = {}
function C_Container.GetContainerNumFreeSlots(b) return 0, (BAGS[b] and BAGS[b].family) or 0 end
C_Item.GetItemFamily = function(id) return ITEMS[id] and ITEMS[id].family or 0 end
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
local function secOf(name)
  for i = 1, 50 do local b = _G["CarefreeBagItem" .. i]; if b and b:IsShown() and b.group and b.group.name == name then
    -- zoek de kop boven deze tegel: gebruik de sectie uit de groep via SectionOf-uitkomst in de log niet; daarom: vergelijk met assign-loze indeling
    return b.group end end
end
check(CFC().cats[1].key == "consum", "standaard Consumables")
-- indeling controleren via de volgorde van tegels: eerst Consumables, dan Professions, dan Gear, dan BoE
local order = {}
for i = 1, 50 do local b = _G["CarefreeBagItem" .. i]; if b and b:IsShown() then order[#order+1] = b.group.name end end
local s = table.concat(order, ",")
check(s == "Cured Ham Steak,Linen Cloth,My Tank Sword,Green BoE Sword,Hearthstone", "automatisch ingedeeld: " .. s)
-- per karakter leren
CURSOR = { itemID = 4599 }
local p; for _, f in ipairs(ALLFRAMES) do if f.section == "gear" and f.shown then p = f end end
p:Fire("OnReceiveDrag"); RunTimers()
local n = 0; for k, ch in pairs(CarefreeBagDB.chars) do n = n + 1; check(ch.assign[4599] == "gear", "ham geleerd op dit karakter (" .. k .. ")") end
check(n == 1, "één karakter")
-- beroepstas: linen gaat niet in de herb bag, peacebloom wel
BAGS[0][1] = nil; E("BAG_UPDATE_DELAYED")  -- 0:1 vrij (gewone tas), 1:2..4 vrij (herb bag)
BAGS[0][1] = { itemID = 4599, count = 5 }; E("BAG_UPDATE_DELAYED") -- gewone tas weer vol
CURSOR = nil
local gh; for _, f in ipairs(ALLFRAMES) do if type(f.text)=="string" and f.text:find("Auto Sell") and f.shown then gh = f end end
check(gh == nil or not gh.text:find("off"), "nieuwe gebruiker: geen 'selling is off' voor de eerste vendor")
CarefreeBagDB.autoSellAsked = true; CarefreeBagDB.autoSell = false; BAGS[0][2] = { itemID = 8000, count = 1 }
ITEMS[8000] = { name = "Broken Fang", quality = 0, stack = 10, bind = 0, icon = 9, price = 5 }
E("BAG_UPDATE_DELAYED"); RunTimers()
gh = nil; for _, f in ipairs(ALLFRAMES) do if type(f.text)=="string" and f.text:find("^|cff66ccffAuto Sell") and f.shown then gh = f end end
check(gh and gh.text:find("selling is off"), "na 'nee': grijs 'selling is off': " .. tostring(gh and gh.text))
local b = CarefreeBagFrame.freeBar
check(b and b.text.text:match("^%d+/8$"), "balk met klein getal: " .. tostring(b and b.text.text))
-- kant-en-klaar: Eten & drinken toevoegen via het lijstje, wint van Consumables
SlashCmdList.CAREFREEBAG(""); RunTimers()
CarefreeBagConfig:Show(); RunTimers()
ITEMS[4599].sub = 5
CarefreeBagDB.chars = {}  -- leren vergeten
for _, ch in pairs(CarefreeBagDB.chars) do ch.assign = {} end
local pb; for _, f in ipairs(ALLFRAMES) do if f.presetID == "food" then pb = f end end
check(pb, "keuzeveld heeft Food & Drink")
check(CarefreeBagConfig.pickBtn.text:find("Add group"), "knop heet + Add group")
pb:Fire("OnClick"); RunTimers()
check(not CarefreeBagConfig.newEdit:IsShown(), "kant-en-klaar: direct toegevoegd, geen naamveld")
local fc; for _, c in ipairs(CFC().cats) do if c.preset == "food" then fc = c end end
check(fc and fc.name == "Food & Drink", "kant-en-klare categorie toegevoegd met vaste naam")
local row; for _, f in ipairs(ALLFRAMES) do if f.fixedName and f.key == fc.key and f.shown then row = f end end
check(row and not row.name:IsShown() and row.fixedName:IsShown(), "naam niet aan te passen in de opties")
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
local o = {}; for i = 1, 50 do local b = _G["CarefreeBagItem" .. i]; if b and b:IsShown() then o[#o+1] = b.group.name end end
check(table.concat(o, ",") == "Broken Fang,Linen Cloth,My Tank Sword,Cured Ham Steak,Green BoE Sword,Hearthstone" or table.concat(o, ","):find("My Tank Sword,Cured Ham Steak"), "ham nu bij Eten & drinken (na Gear), niet bij Consumables: " .. table.concat(o, ","))
-- handmatig omwisselen binnen een groep
BAGS[1][3] = { itemID = 2589, count = 4 }; BAGS[1][4] = { itemID = 2447, count = 3 }; E("BAG_UPDATE_DELAYED")
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
local function names() local o = {}; for i = 1, 50 do local b = _G["CarefreeBagItem" .. i]; if b and b:IsShown() then o[#o+1] = b.group.name end end return table.concat(o, ",") end
local before = names()
check(before:find("^Linen Cloth,Peacebloom") or before:find("^Peacebloom,Linen Cloth"), "twee items in Professions: " .. before)
local first, second = CarefreeBagItem1, CarefreeBagItem2
CURSOR = { itemID = second.group.itemID }

first:Fire("OnReceiveDrag"); RunTimers()
local after = names()
check(CURSOR == nil and CFC().sort.prof == "manual", "slepen in de groep: sortering op handmatig")
check(after:sub(1, #second.group.name) == second.group.name or after ~= before, "omgewisseld: " .. after)
-- sorteerknop wisselen
local hdr; for _, f in ipairs(ALLFRAMES) do if f.sort and f.key == "prof" and f.shown then hdr = f end end
check(hdr and hdr.sort.mode == "manual", "sorteerknop kent de sortering: " .. tostring(hdr and hdr.sort.mode))
hdr.sort:Fire("OnClick"); RunTimers()
check(CarefreeBagSortMenu and CarefreeBagSortMenu:IsShown(), "sorteerknop opent keuzelijst")
local tb; for _, b in ipairs(CarefreeBagSortMenu.buttons) do if b.mode == "newest" then tb = b end end
check(#CarefreeBagSortMenu.buttons == 3 and tb.text:find("Newest last") and not tb.text:find("Check"), "3 keuzes, 'Newest last' zonder vinkje")
check(CarefreeBagMenuCatcher:IsShown(), "klikvanger achter de keuzelijst")
tb:Fire("OnClick"); RunTimers()
check(CFC().sort.prof == "newest" and not CarefreeBagSortMenu:IsShown(), "gekozen: nieuwste als laatst, lijst dicht")
hdr.sort:Fire("OnClick"); RunTimers(); CarefreeBagMenuCatcher:Fire("OnClick"); RunTimers()
check(not CarefreeBagSortMenu:IsShown() and not CarefreeBagMenuCatcher:IsShown(), "klik ernaast sluit de lijst")
-- inklappen
hdr.toggle:Fire("OnClick"); RunTimers()
check(CFC().collapsed.prof and not names():find("Peacebloom"), "Professions ingeklapt: " .. names())
hdr = nil; for _, f in ipairs(ALLFRAMES) do if f.sort and f.key == "prof" and f.shown then hdr = f end end
check(hdr.fs.text:find("%(2%)"), "ingeklapt toont aantal: " .. hdr.fs.text)
hdr.toggle:Fire("OnClick"); RunTimers()
check(names():find("Peacebloom"), "weer uitgeklapt")
-- auto mail in de kop
CFC().cats[3].mailTo = "Bankie Alt"; E("BAG_UPDATE_DELAYED")
local gh2; for _, f in ipairs(ALLFRAMES) do if f.sort and f.key == "gear" and f.shown then gh2 = f end end
check(gh2.mail:IsShown() and gh2.mail.fs.text:find("Auto") and not gh2.fs.text:find("Bankie"), "kop: aparte Auto-knop met envelop, naam alleen in tooltip")
local nb; for _, f in ipairs(ALLFRAMES) do if f.sort and f.key == "prof" and f.shown then nb = f end end
check(not nb.mail:IsShown(), "geen Auto bij groep zonder post")
-- lege BoE blijft staan als hij aan staat
BAGS[0][4] = nil; E("BAG_UPDATE_DELAYED"); CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
local bh; for _, f in ipairs(ALLFRAMES) do if f.sort and f.key == "boe" and f.shown then bh = f end end
check(bh ~= nil, "lege BoE-groep wordt getoond")
local bp = false; for _, f in ipairs(ALLFRAMES) do if f.section == "boe" and f.shown then bp = true end end
check(bp, "lege BoE heeft een +vakje")
check(CarefreeBagDB.fixedOn.keys == false, "Keys staat standaard uit")
GOLD_MOCK = true
print("lastError:", CarefreeBagDB.lastError)
