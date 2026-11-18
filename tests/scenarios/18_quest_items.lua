local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Quest-items: bij welke quest hoort het (questlog uitlezen), "?" voor items die nergens bij horen,
-- "!" + blauwe gloed + venstertje voor items die een quest starten.
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 1, price = 10 },
  [5000] = { name = "Kobold Candle", quality = 1, stack = 10, bind = 1, icon = 2, quest = true },
  [5001] = { name = "Scorched Torch", quality = 1, stack = 1, bind = 1, icon = 3, quest = true },
  [5002] = { name = "Old Scrap of Paper", quality = 1, stack = 1, bind = 1, icon = 4, quest = true },
  [5003] = { name = "Dusty Map", quality = 1, stack = 1, bind = 1, icon = 5, starts = 900 },
  [5004] = { name = "Faded Letter", quality = 1, stack = 1, bind = 1, icon = 6, starts = 901 },
  [5005] = { name = "Bloody Note", quality = 1, stack = 1, bind = 1, icon = 7, starts = 902 },
}
BAGS[0] = { n = 16, [1] = { itemID = 2589, count = 5 }, [2] = { itemID = 5000, count = 3 }, [3] = { itemID = 5001, count = 1 },
  [4] = { itemID = 5002, count = 1 }, [5] = { itemID = 5004, count = 1 } }

-- Nagebootst questlog (Classic-manier). Het kopje is dichtgeklapt: de quests zie je dan niet.
QLOG = {
  { title = "Elwynn Forest", header = true, collapsed = true },
  { title = "Candles for Bob", level = 12, questID = 100, obj = { "Kobold Candle: 3/8" }, desc = "Bring me candles." },
  { title = "Burn the Nest", level = 14, questID = 101, obj = { "Nest burned: 0/1" }, desc = "Use the Scorched Torch on the nest." },
}
ACTIVE, DONE = {}, { [901] = true }
local function Visible()
  local v, hide = {}, false
  for _, q in ipairs(QLOG) do
    if q.header then hide = q.collapsed; v[#v + 1] = q elseif not hide then v[#v + 1] = q end
  end
  return v
end
SEL = 0
function GetNumQuestLogEntries() return #Visible() end
function GetQuestLogTitle(i) local q = Visible()[i]; if not q then return nil end
  return q.title, q.level, nil, q.header, q.collapsed, q.complete and 1 or nil, nil, q.questID end
function ExpandQuestHeader() for _, q in ipairs(QLOG) do if q.header then q.collapsed = false end end end
function CollapseQuestHeader(i) local q = Visible()[i]; if q then q.collapsed = true end end
function GetNumQuestLeaderBoards(i) local q = Visible()[i]; return q and q.obj and #q.obj or 0 end
function GetQuestLogLeaderBoard(j, i) local q = Visible()[i]; return q.obj[j], "item", false end
function GetQuestLogSelection() return SEL end
function SelectQuestLogEntry(i) SEL = i end
function GetQuestLogQuestText() local q = Visible()[SEL]; return q and q.desc or "", "" end
function GetQuestDifficultyColor() return { r = 1, g = 1, b = 0 } end
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return DONE[id] end }
function C_Container.GetContainerItemQuestInfo(b, s)
  local it = BAGS[b] and BAGS[b][s]; local d = it and ITEMS[it.itemID]
  if not d then return { isQuestItem = false } end
  return { isQuestItem = d.quest or false, questID = d.starts, isActive = d.starts and ACTIVE[d.starts] or false }
end
-- Beveiligde knop: attributen onthouden.
local realCF = CreateFrame
function CreateFrame(...) local o = realCF(...); o.attrs = {}; o.SetAttribute = function(self, k, v) self.attrs[k] = v end; return o end

local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
local function QE(ev, a1) NS.questEvents:Fire("OnEvent", ev, a1); RunTimers() end
CarefreeBagDB = { lang = "en" }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
QE("PLAYER_ENTERING_WORLD")
PressKey("B"); RunTimers()
check(CarefreeBagFrame:IsShown(), "tassen open")

local function Btn(id)
  for _, f in ipairs(ALLFRAMES) do if f.isCarefreeItem and f.shown and f.group and f.group.itemID == id then return f end end
end
local function Tip(id)
  local b = Btn(id)
  local lines = {}
  GameTooltip.AddLine = function(_, t) lines[#lines + 1] = t end
  GameTooltip.GetOwner = function() return b end
  GameTooltip.GetItem = function() return nil, "|Hitem:" .. id .. "|h" end
  POSTCALL(GameTooltip)
  return table.concat(lines, "\n")
end

check(Btn(5000) and Btn(5000).questKind == "active", "Kobold Candle hoort bij een quest (ook onder een dichtgeklapt kopje)")
check(QLOG[1].collapsed == true, "kopje daarna weer dichtgeklapt")
check(SEL == 0, "gekozen quest in het questlog teruggezet")
local t = Tip(5000)
check(t:find("For the quest", 1, true) and t:find("[12] Candles for Bob", 1, true), "tooltip: questnaam met level")
check(t:find("Progress: 3/8", 1, true), "tooltip: voortgang 3/8")
check(Btn(5001).questKind == "active" and Tip(5001):find("Burn the Nest", 1, true), "Scorched Torch: gevonden via de questtekst")
check(Btn(5002).questKind == "orphan", "Old Scrap of Paper: niet in je questlog")
check(Btn(5002).cfbQuest.icon:IsShown(), "  ... met een ?-icoontje")
t = Tip(5002)
check(t:find("Not in your quest log", 1, true) and t:find("quest chain", 1, true) and t:find("reputation", 1, true), "tooltip: kan waarschijnlijk weg + redenen")
check(t:find("Alt-click: always keep", 1, true), "tooltip: Alt-klik = altijd houden")
check(Btn(5002).cfbQuest.border:IsShown() and Btn(5002).desat == true, "restje: oranje rand en grijs icoon")
check(not Btn(5000).cfbQuest.border:IsShown() and not Btn(5000).desat, "lopende quest: geen oranje rand")
-- Alt-klik: altijd houden, en weer terug
function IsAltKeyDown() return ALT end
ALT = true
Btn(5002):Fire("PreClick", "LeftButton"); RunTimers()
check(CFC().questKeep and CFC().questKeep[5002], "Alt-klik: onthouden (per karakter)")
check(Btn(5002).questKind == "kept" and not Btn(5002).cfbQuest.border:IsShown() and not Btn(5002).desat, "gehouden: geen markering meer")
check(Tip(5002):find("You always keep this item", 1, true) and Tip(5002):find("remind me again", 1, true), "tooltip: je houdt dit altijd + Alt-klik terug")
Btn(5002):Fire("PreClick", "LeftButton"); RunTimers()
check(not CFC().questKeep[5002] and Btn(5002).questKind == "orphan", "nog een Alt-klik: weer herinneren")
Btn(5000):Fire("PreClick", "LeftButton"); RunTimers()
check(not CFC().questKeep[5000], "Alt-klik op een item van een lopende quest: niets")
ALT = nil
check(Btn(5004).questKind == "done" and Tip(5004):find("already did", 1, true), "Faded Letter: quest al gedaan")
check(not Btn(2589).questKind and Tip(2589) == "", "Linen Cloth: geen quest-regels")
check(not (CarefreeBagQuestPopup and CarefreeBagQuestPopup:IsShown()), "geen venstertje bij inloggen")

-- Dusty Map geloot: venstertje + blauwe gloed
BAGS[0][6] = { itemID = 5003, count = 1 }
E("BAG_UPDATE_DELAYED"); QE("BAG_UPDATE_DELAYED")
check(CarefreeBagQuestPopup and CarefreeBagQuestPopup:IsShown(), "venstertje: quest gevonden")
local start = CarefreeBagQuestStartButton
check(start.attrs.type == "item" and start.attrs.item == "0 6", "knop gebruikt het item uit tas 0 vak 6")
local b = Btn(5003)
check(b.questKind == "start" and b.cfbQuest.glow:IsShown(), "Dusty Map knippert blauw in de tas")
check(Tip(5003):find("Starts a quest", 1, true), "tooltip: start een quest")
-- Later: venster weg, gloed blijft, niet opnieuw vragen
NS.QuestStartPopup().later:Fire("OnClick"); RunTimers()
check(not CarefreeBagQuestPopup:IsShown(), "Later: venster weg")
QE("BAG_UPDATE_DELAYED")
check(not CarefreeBagQuestPopup:IsShown(), "Later: niet opnieuw gevraagd")
check(Btn(5003).cfbQuest.glow:IsShown(), "Later: blijft knipperen")
-- quest geaccepteerd: gloed weg
ACTIVE[900] = true
table.insert(QLOG, { title = "Treasure Hunt", level = 10, questID = 900, obj = { "Find the chest: 0/1" }, desc = "Follow the map." })
QE("QUEST_ACCEPTED", 900)
check(Btn(5003).questKind == "active" and not Btn(5003).cfbQuest.glow:IsShown(), "quest geaccepteerd: niet meer knipperen")

-- In gevecht geloot: pas na het gevecht het venster
COMBAT = true
BAGS[0][7] = { itemID = 5005, count = 1 }
QE("BAG_UPDATE_DELAYED")
check(not CarefreeBagQuestPopup:IsShown(), "in gevecht: nog geen venster")
COMBAT = nil
QE("PLAYER_REGEN_ENABLED")
check(CarefreeBagQuestPopup:IsShown() and start.attrs.item == "0 7", "na het gevecht: venster voor Bloody Note")
-- gevecht begint terwijl het venster open is: even weg, daarna terug
QE("PLAYER_REGEN_DISABLED")
check(not CarefreeBagQuestPopup:IsShown(), "gevecht begint: venster weg")
QE("PLAYER_REGEN_ENABLED")
check(CarefreeBagQuestPopup:IsShown(), "gevecht voorbij: venster terug")
-- Start quest geklikt: venster weg
start:Fire("PostClick"); RunTimers()
check(not CarefreeBagQuestPopup:IsShown(), "Start quest: venster weg")

-- Bij inloggen: lijstje met restjes (Old Scrap of Paper en Faded Letter)
check(not CarefreeBagQuestReminder, "geen lijstje bij laadscherm/reload")
QE("PLAYER_ENTERING_WORLD", true)
check(CarefreeBagQuestReminder and CarefreeBagQuestReminder:IsShown(), "inloggen: lijstje met restjes")
local rows = NS.QuestReminderRows()
local ids = {}
for _, r in ipairs(rows) do if r.shown and r.item then ids[r.item.itemID] = r end end
check(ids[5002] and ids[5004] and not ids[5000] and not ids[5005], "lijstje: alleen de restjes")
ids[5004].keep:Fire("OnClick"); RunTimers()
check(CFC().questKeep[5004], "Always keep in het lijstje: onthouden")
local left = 0
for _, r in ipairs(rows) do if r.shown and r.item then left = left + 1 end end
check(left == 1 and CarefreeBagQuestReminder:IsShown(), "lijstje: nog 1 over")
CarefreeBagQuestReminder.later:Fire("OnClick")
check(not CarefreeBagQuestReminder:IsShown() and not CFC().questKeep[5002], "Remind me later: dicht, niets onthouden")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
