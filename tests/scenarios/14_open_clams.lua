local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Clams na het looten automatisch openen (niet bij vendor/mailbox, niet in gevecht, optie uit = niets).
ITEMS = {
  [5524] = { name = "Thick-shelled Clam", quality = 1, stack = 20, bind = 0, icon = 3, price = 21, openable = true },
  [7974] = { name = "Zesty Clam Meat", quality = 1, stack = 20, bind = 0, icon = 4, price = 5 },
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 5, price = 10 },
}
BAGS[0] = { n = 8, [1] = { itemID = 2589, count = 3 }, [2] = { itemID = 7974, count = 2 } }
LOADED_ADDONS = {}
OPENED = {}
function C_Container.UseContainerItem(b, s) local it = BAGS[b][s]; OPENED[#OPENED + 1] = it and it.itemID; BAGS[b][s] = nil end
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
CarefreeBagDB = { lang = "en" }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
check(CarefreeBagDB.autoOpenClams == true, "standaard aan")
E("BAG_UPDATE_DELAYED"); RunTimers()
check(#OPENED == 0, "clam meat en linnen: niets geopend")

-- clam geloot
BAGS[0][3] = { itemID = 5524, count = 1 }
E("BAG_UPDATE_DELAYED"); RunTimers()
check(OPENED[1] == 5524, "clam meteen geopend")

-- bij de vendor: niet (daar verkoopt 'gebruiken' het item)
BAGS[0][3] = { itemID = 5524, count = 1 }
MerchantFrame.shown = true
E("BAG_UPDATE_DELAYED"); RunTimers()
check(#OPENED == 1 and BAGS[0][3], "vendor open: clam niet geopend (en niet verkocht)")
MerchantFrame.shown = false

-- in gevecht: niet
COMBAT = true
E("BAG_UPDATE_DELAYED"); RunTimers()
check(#OPENED == 1, "in gevecht: niet geopend")
COMBAT = nil

-- na de loot: wel
E("LOOT_CLOSED"); RunTimers()
check(#OPENED == 2, "lootvenster dicht: clam alsnog geopend")

-- optie uit
CarefreeBagDB.autoOpenClams = false
BAGS[0][3] = { itemID = 5524, count = 1 }
E("BAG_UPDATE_DELAYED"); RunTimers()
check(#OPENED == 2, "optie uit: niet geopend")
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig.clamCb, "vinkje 'Open clams automatically' in de opties")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
-- Belangrijke momenten apart bewaard (DB.events), met tijd: later terug te lezen.
local ev = table.concat(CarefreeBagDB.events or {}, "\n")
check(ev:find("clam: open 5524") and ev:find("waits: vendor") and ev:find("waits: combat") and ev:find("login: v"), "clam-pogingen en wachtredenen in DB.events:\n" .. ev)
