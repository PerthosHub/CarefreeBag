local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
ITEMS = { [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 3, class = 0 } }
BAGS[0] = { n = 2, [1] = { itemID = 4599, count = 5 } }
LOADED_ADDONS = {}
local function Load()
  local NS = {}
  LoadAddon(NS)
  DRIVER:Fire("OnEvent", "ADDON_LOADED", "CarefreeBag"); DRIVER:Fire("OnEvent", "PLAYER_LOGIN"); RunTimers()
end
-- bestaande gebruiker van voor 1.3.0: groepen op accountniveau
CarefreeBagDB = { lang = "en", cats = { { key = "consum", preset = "consum" }, { key = "bank", name = "Bank", mailTo = "Jaina Frostwolf" } },
  order = { "bank", "consum" }, sort = { bank = "manual" }, chars = {} }
Load()
local A = CarefreeBagDB.chars["Thrall Frostwolf-"]
check(A and #A.cats == 2 and A.cats[2].mailTo == "Jaina Frostwolf", "karakter A begint met de oude accountgroepen")
check(A.order[1] == "bank" and A.sort.bank == "manual", "volgorde en sortering meegekopieerd")
A.cats[#A.cats + 1] = { key = "alleenA", name = "Alleen A" }
-- ander karakter logt in
function UnitName() return "Jaina-Frostwolf" end; rawset(_G, "UnitNameUnmodified", function() return "Jaina", "Frostwolf" end)
Load()
local B = CarefreeBagDB.chars["Jaina Frostwolf-"]
check(B and #B.cats == 2, "karakter B ziet de groep van A niet")
B.cats[2].mailTo = nil
check(A.cats[2].mailTo == "Jaina Frostwolf", "aanpassen bij B verandert A niet")
check(#CarefreeBagDB.cats == 2, "accountlijst blijft ongemoeid als sjabloon")
print("lastError:", LASTERROR)
B.cats = { { key = "x", name = "X" } }
SlashCmdList.CAREFREEBAG("resetgroups")
check(#B.cats == 2 and B.cats[2].name == "Bank", "/cfb resetgroups zet de groepen terug naar de accountlijst")
-- groep verwijderen bij B haalt de geleerde items van A niet weg
A.assign[4599] = "bank"; B.assign[4599] = "bank"
