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

-- Blokkade die niet van een clam komt (eigen rechtsklik): clams gaan gewoon door
NOW = NOW + 60
E("ADDON_ACTION_FORBIDDEN", "CarefreeBag", "UseContainerItem()")
check(not NS.clamBlocked, "blokkade zonder clam-poging: clams niet stilgelegd")
local ev0 = table.concat(CarefreeBagDB.events or {}, "\n")
check(ev0:find("blocked: UseContainerItem%(%), no click on a CFB slot") and ev0:find("clam tried: no"), "blokkade genoteerd met wat eraan voorafging:\n" .. ev0)
CarefreeBagDB.lastError = nil

-- Clam die niet opengaat (blijft liggen): 2 pogingen, dan overslaan
function C_Container.UseContainerItem(b, s) OPENED[#OPENED + 1] = BAGS[b][s] and BAGS[b][s].itemID end
BAGS[0][3] = { itemID = 5524, count = 1 }
for _ = 1, 5 do E("BAG_UPDATE_DELAYED"); RunTimers() end
check(#OPENED == 4, "vastzittende clam: 2 pogingen, daarna niet meer: " .. #OPENED)
check(table.concat(CarefreeBagDB.events, "\n"):find("did not open after 2 tries"), "overslaan genoteerd")
-- Blokkade vlak na een clam-poging: dan wel stoppen
BAGS[0][4] = { itemID = 5524, count = 1 }
E("BAG_UPDATE_DELAYED"); RunTimers()
check(#OPENED == 5, "andere clam: wel geprobeerd")
E("ADDON_ACTION_FORBIDDEN", "CarefreeBag", "UseContainerItem()")
check(NS.clamBlocked, "blokkade vlak na een clam-poging: automatisch openen stopt")
NS.clamBlocked = nil; CarefreeBagDB.lastError = nil
BAGS[0][3], BAGS[0][4] = nil, nil
function C_Container.UseContainerItem(b, s) local it = BAGS[b][s]; OPENED[#OPENED + 1] = it and it.itemID; BAGS[b][s] = nil end

-- optie uit
CarefreeBagDB.autoOpenClams = false
BAGS[0][3] = { itemID = 5524, count = 1 }
E("BAG_UPDATE_DELAYED"); RunTimers()
check(#OPENED == 5, "optie uit: niet geopend")
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig.clamCb, "vinkje 'Open clams automatically' in de opties")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
-- Belangrijke momenten apart bewaard (DB.events), met tijd: later terug te lezen.
local ev = table.concat(CarefreeBagDB.events or {}, "\n")
check(ev:find("clam: open 5524") and ev:find("waits: vendor") and ev:find("waits: combat") and ev:find("login: v"), "clam-pogingen en wachtredenen in DB.events:\n" .. ev)
