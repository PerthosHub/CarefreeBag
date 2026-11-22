local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Venster "Quest found" mag niet wegvallen (Johan, 2026-11-22): een quest-item geloot terwijl CFB
-- uit stond, en daarna opnieuw ingelogd, kreeg nooit een venster. Nu onthoudt CFB per karakter
-- welke items al gevraagd zijn (ch.questOffered).
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 1, price = 10 },
  [5003] = { name = "Dusty Map", quality = 1, stack = 1, bind = 1, icon = 5, starts = 900 },
  [5005] = { name = "Bloody Note", quality = 1, stack = 1, bind = 1, icon = 7, starts = 902 },
  [5006] = { name = "Giant Tooth", quality = 1, stack = 1, bind = 1, icon = 8, starts = 903 },
}
BAGS[0] = { n = 16, [1] = { itemID = 2589, count = 5 }, [2] = { itemID = 5003, count = 1 } }

-- leeg questlog (Classic-manier)
function GetNumQuestLogEntries() return 0 end
function GetQuestLogTitle() return nil end
function GetNumQuestLeaderBoards() return 0 end
function GetQuestLogSelection() return 0 end
function SelectQuestLogEntry() end
function GetQuestLogQuestText() return "", "" end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end }
function C_Container.GetContainerItemQuestInfo(b, s)
  local it = BAGS[b] and BAGS[b][s]; local d = it and ITEMS[it.itemID]
  if not d then return { isQuestItem = false } end
  return { isQuestItem = false, questID = d.starts, isActive = false }
end
local realCF = CreateFrame
function CreateFrame(...) local o = realCF(...); o.attrs = {}; o.SetAttribute = function(self, k, v) self.attrs[k] = v end; return o end

local NS
local function Login()
  NS = {}; CFB_NS = NS
  LoadAddon(NS)
  DRIVER:Fire("OnEvent", "ADDON_LOADED", "CarefreeBag"); DRIVER:Fire("OnEvent", "PLAYER_LOGIN"); RunTimers()
  NS.questEvents:Fire("OnEvent", "PLAYER_ENTERING_WORLD"); RunTimers()
end
local function QE(ev, a1) NS.questEvents:Fire("OnEvent", ev, a1); RunTimers() end
local function Shown() local p = NS.QuestStartPopup(); return p and p:IsShown() end
local function Asks(id) return Shown() and CarefreeBagQuestStartButton.attrs.item == "item:" .. id end

-- 1. Allereerste keer (update vanaf een oude versie): wat je al had, wordt niet gevraagd
CarefreeBagDB = { lang = "en" }
Login()
check(not Shown(), "eerste keer: geen venster voor de Dusty Map die je al had")
check(CFC().questOffered and CFC().questOffered[5003], "Dusty Map telt als al gevraagd")

-- 2. CFB uit, Bloody Note geloot: geen venster. Weer aan: meteen het venster
NS.SetEnabled(false)
BAGS[0][3] = { itemID = 5005, count = 1 }
DRIVER:Fire("OnEvent", "BAG_UPDATE_DELAYED"); QE("BAG_UPDATE_DELAYED")
check(not Shown(), "CFB uit: geen venster")
NS.SetEnabled(true); RunTimers()
check(Asks(5005), "CFB weer aan: venster voor de Bloody Note")
NS.QuestStartPopup().later:Fire("OnClick"); RunTimers()

-- 3. Geloot zonder venster (CFB uit, of vlak voor uitloggen), opnieuw ingelogd met CFB uit:
-- geen venster. CFB aan: venster. En inloggen met CFB aan geeft het ook.
BAGS[0][4] = { itemID = 5006, count = 1 }
CarefreeBagDB.enabled = false
Login()
check(not Shown(), "inloggen met CFB uit: geen venster")
NS.SetEnabled(true); RunTimers()
check(Asks(5006), "CFB aan na inloggen: venster voor de Giant Tooth")
check(CFC().questOffered[5006], "Giant Tooth onthouden als gevraagd")
CFC().questOffered[5006] = nil -- nog eens, nu als het vlak voor uitloggen geloot was
Login()
check(Asks(5006), "inloggen: venster voor de Giant Tooth die nog nooit gevraagd is")
check(CFC().questOffered[5006], "Giant Tooth nu onthouden als gevraagd")

-- 4. Later gekozen, opnieuw ingelogd: niet steeds opnieuw vragen (item blijft wel knipperen)
NS.QuestStartPopup().later:Fire("OnClick"); RunTimers()
Login()
check(not Shown(), "opnieuw ingelogd: al gevraagde items niet opnieuw")

-- 5. Items gebruiken vanuit CFB: de knop krijgt de tas via zijn ouder-frame, niet via SetBagID
-- (een Lua-veld vanuit addon-code = WoW blokkeert UseContainerItem voor sommige items)
PressKey("B"); RunTimers()
local b
for _, f in ipairs(ALLFRAMES) do if f.isCarefreeItem and f.shown and f.group and f.group.itemID == 5006 then b = f end end
check(b and rawget(b, "bagID") == nil, "item-knop: geen bagID door CFB gezet")
check(b:GetBagID() == 0 and b:GetID() == 4, "item-knop: tas 0 vak 4 via het ouder-frame")
