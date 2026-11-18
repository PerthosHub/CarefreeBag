local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- 1.8.1: Keys-groep uit = sleutels niet in het venster (#5), mailpaneel weg als er niets te
-- versturen is (#9), rechtsklik bij de mailbox = alle stapels in de mail (#12), en niet
-- samenvoegen zolang de mailbox open is (#12).
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, price = 10 },
  [9000] = { name = "Key to Searing Gorge", quality = 1, stack = 1, bind = 1, icon = 10 },
}
KEYRING_CONTAINER = -2
C_ActionBar = { ShouldShowKeyring = function() return true end }
BAGS[-2] = { n = 6, [1] = { itemID = 9000, count = 1, bound = true } }
BAGS[0] = { n = 16, [1] = { itemID = 2589, count = 20 }, [2] = { itemID = 2589, count = 20 }, [3] = { itemID = 2589, count = 20 } }
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
local function Tile(id) for _, f in ipairs(ALLFRAMES) do if f.isCarefreeItem and f.shown and f.group and f.group.itemID == id then return f end end end
CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()

-- #5 Keys uit (standaard): sleutel niet in het venster, ook niet bij Other
check(CarefreeBagDB.fixedOn.keys == false, "Keys staat standaard uit")
check(not Tile(9000), "Keys uit: sleutel niet zichtbaar in CarefreeBag")
check(BAGS[-2][1] and BAGS[-2][1].itemID == 9000, "sleutel zit gewoon nog in de keyring")
CarefreeBagDB.fixedOn.keys = true; E("BAG_UPDATE_DELAYED"); RunTimers()
check(Tile(9000), "Keys aan: sleutel zichtbaar")

-- #9 Niets te versturen: geen mailpaneel
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
check(CarefreeBagMailPanel and not CarefreeBagMailPanel:IsShown(), "niets te versturen: geen paneel")
local said = false; for _, l in ipairs(LOG) do if l:find("othing to send") and l:find("CHAT") then said = true end end
check(not said, "geen chatmelding 'nothing to send'")

-- #12 Niet samenvoegen terwijl de mailbox open is (gesplitste stapel blijft staan)
BAGS[0][4] = { itemID = 2589, count = 6 }; BAGS[0][1].count = 14
E("BAG_UPDATE_DELAYED"); RunTimers()
check(BAGS[0][4] and BAGS[0][4].count == 6 and BAGS[0][1].count == 14, "mailbox open: gesplitste stapel blijft zoals hij is")

-- #12 Rechtsklik op het vakje met alle linnen: de andere stapels gaan er ook in
SendMailFrame.shown = true
ATTACHED = {}
local t = Tile(2589)
check(t and #t.group.slots == 4, "linnen = 1 vakje met 4 stapels")
CURSOR = nil
t:Fire("PreClick", "RightButton"); RunTimers()
check(#ATTACHED == 3, "rechtsklik: de 3 andere stapels erbij in de mail (WoW doet de eerste): " .. #ATTACHED)
SendMailFrame.shown = false

-- Mailbox dicht: weer samenvoegen
MailFrame.shown = false; E("MAIL_CLOSED"); RunTimers()
for _ = 1, 5 do E("BAG_UPDATE_DELAYED"); RunTimers() end
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
