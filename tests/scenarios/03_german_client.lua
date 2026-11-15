local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
ITEMS = { [8000] = { name = "Broken Fang", quality = 0, stack = 10, bind = 0, icon = 9, price = 5 },
          [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4 } }
BAGS[0] = { n = 16, [1] = { itemID = 8000, count = 3 }, [2] = { itemID = 2589, count = 5 } }
LOADED_ADDONS = {}
function GetLocale() return "deDE" end
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
check(CarefreeBagDB.lang == "de", "Duitse client: Duits gekozen")
SlashCmdList.CAREFREEBAG(""); RunTimers()
local lb = CarefreeBagLangButton
check(lb and CarefreeBagDB.lang == "de", "taalknop met icoon, taal Deutsch")
print("lastError:", CarefreeBagDB.lastError)
