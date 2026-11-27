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
-- voortgang verandert vlak na het uitlezen: toch bijgewerkt
QLOG[2].obj[1] = "Kobold Candle: 4/8"
QE("UNIT_QUEST_LOG_CHANGED", "target")
check(Tip(5000):find("Progress: 3/8", 1, true), "questlog van een ander: niet opnieuw uitgelezen")
QE("UNIT_QUEST_LOG_CHANGED", "player")
check(Tip(5000):find("Progress: 4/8", 1, true), "eigen questlog veranderd: voortgang 4/8")
check(Btn(5001).questKind == "active" and Tip(5001):find("Burn the Nest", 1, true), "Scorched Torch: gevonden via de questtekst")
check(Btn(5002).questKind == "orphan", "Old Scrap of Paper: niet in je questlog")
check(not Btn(5002).cfbQuest.icon:IsShown() and Btn(5002).cfbQuest.border2:IsShown(), "  ... met dubbele oranje rand, zonder vraagteken")
t = Tip(5002)
check(t:find("Not in your quest log", 1, true) and t:find("quest chain", 1, true) and t:find("reputation", 1, true), "tooltip: kan waarschijnlijk weg + redenen")
check(not t:find("Alt-click", 1, true), "tooltip: geen Alt-klik-trucjes meer")
check(Btn(5002).cfbQuest.border:IsShown() and Btn(5002).desat == true, "restje: oranje rand en grijs icoon")
check(not Btn(5000).cfbQuest.border:IsShown() and not Btn(5000).desat, "lopende quest: geen oranje rand")
-- Alt-klik doet niets meer (geen trucjes om te onthouden)
function IsAltKeyDown() return true end
Btn(5002):Fire("PreClick", "LeftButton"); RunTimers()
check(not (CFC().questKeep and CFC().questKeep[5002]), "Alt-klik: niets")
function IsAltKeyDown() return false end
-- Kop van de groep Quest: oranje "Leftovers: 2"; klik = lijstje met knoppen
LEVEL = 20
function UnitLevel() return LEVEL end
function GetMaxPlayerLevel() return 60 end
local function QuestHeader()
  for _, f in ipairs(ALLFRAMES) do if f.quest and f.key == "quest" and f.shown then return f end end
end
local function Row(id)
  for _, r in ipairs(NS.QuestReminderRows()) do if r.shown and r.item and r.item.itemID == id then return r end end
end
local hq = QuestHeader()
check(hq and hq.quest:IsShown() and hq.quest.fs:GetText():find("Leftovers: 2", 1, true), "Quest-kop: Leftovers: 2")
hq.quest:Fire("OnClick"); RunTimers()
check(CarefreeBagQuestReminder and CarefreeBagQuestReminder:IsShown(), "klik op Leftovers: lijstje open")
check(Row(5002) and Row(5004) and not Row(5000), "lijstje: alleen de restjes")
-- Always keep, en via hetzelfde lijstje weer terug
check(Row(5002).main:GetText() == "Destroy" and Row(5002).opt:IsShown() and Row(5002).name:GetText():find("no value", 1, true),
  "geen waarde: één knop Destroy (advies) + menu ▼ (#25)")
Row(5002).opt:Fire("OnClick")
local texts = {}; for _, c in ipairs(Row(5002).menuChoices) do texts[#texts + 1] = c.text end
texts = table.concat(texts, ", ")
check(texts == "Remind me next login, Remind me next level, Always keep", "menu: de andere keuzes: " .. texts)
Row(5002):Choose("keep"); RunTimers()
check(CFC().questKeep and CFC().questKeep[5002], "Always keep: onthouden (per karakter)")
check(Btn(5002).questKind == "kept" and not Btn(5002).cfbQuest.border:IsShown() and not Btn(5002).desat, "gehouden: geen markering meer")
check(Tip(5002):find("You always keep this item", 1, true), "tooltip: je houdt dit altijd")
check(Row(5002) and Row(5002).main:GetText() == "Remind me" and not Row(5002).opt:IsShown(), "lijstje: gehouden item met alleen de knop Remind me")
Row(5002).main:Fire("OnClick"); RunTimers()
check(not CFC().questKeep[5002] and Btn(5002).questKind == "orphan", "Remind me: weer een restje")
-- Next level, en weer terug
Row(5002):Choose("snooze"); RunTimers()
check(CFC().questSnooze and CFC().questSnooze[5002] == 20 and not CFC().questKeep[5002], "Next level: uitgesteld tot level 21 (per karakter)")
check(Btn(5002).questKind == "snoozed" and not Btn(5002).cfbQuest.border:IsShown(), "uitgesteld: geen oranje rand")
check(Tip(5002):find("level 21", 1, true), "tooltip: herinnering op level 21")
check(Row(5002) and Row(5002).name:GetText():find("from level 21", 1, true), "lijstje: from level 21")
Row(5002).main:Fire("OnClick"); RunTimers()
check(not CFC().questSnooze[5002] and Btn(5002).questKind == "orphan", "Remind me: meteen weer herinneren")
Row(5002):Choose("snooze"); RunTimers()
LEVEL = 21
NS.Refresh(); RunTimers()
check(Btn(5002).questKind == "orphan" and not CFC().questSnooze[5002], "level hoger: weer een restje")
LEVEL = 60
NS.QuestReminderFill()
Row(5002).opt:Fire("OnClick")
local hasNext = false; for _, c in ipairs(Row(5002).menuChoices) do if c.text == "Remind me next level" then hasNext = true end end
check(Row(5002) and not hasNext and not CarefreeBagQuestReminder.snoozeAll:IsShown(), "max level: geen Next level")
LEVEL = 20
hq = QuestHeader()
hq.quest:Fire("OnClick"); RunTimers()
check(not CarefreeBagQuestReminder:IsShown(), "nog een klik op Leftovers: lijstje dicht")
check(Btn(5004).questKind == "done" and Tip(5004):find("already did", 1, true), "Faded Letter: quest al gedaan")
check(not Btn(2589).questKind and not Tip(2589):find("uest"), "Linen Cloth: geen quest-regels (wel de uitleg van Shift + muiswiel)")
check(not (CarefreeBagQuestPopup and CarefreeBagQuestPopup:IsShown()), "geen venstertje bij inloggen")

-- Dusty Map geloot: venstertje + blauwe gloed
BAGS[0][6] = { itemID = 5003, count = 1 }
E("BAG_UPDATE_DELAYED"); QE("BAG_UPDATE_DELAYED")
check(CarefreeBagQuestPopup and CarefreeBagQuestPopup:IsShown(), "venstertje: quest gevonden")
local start = CarefreeBagQuestStartButton
check(start.attrs.type == "item" and start.attrs.item == "item:5003", "knop gebruikt de Dusty Map (op itemID, ook als hij verschuift)")
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
check(CarefreeBagQuestPopup:IsShown() and start.attrs.item == "item:5005", "na het gevecht: venster voor Bloody Note")
-- gevecht begint terwijl het venster open is: even weg, daarna terug
QE("PLAYER_REGEN_DISABLED")
check(not CarefreeBagQuestPopup:IsShown(), "gevecht begint: venster weg")
QE("PLAYER_REGEN_ENABLED")
check(CarefreeBagQuestPopup:IsShown(), "gevecht voorbij: venster terug")
-- Start quest: bij indrukken nog niet dicht (anders mist de knop het loslaten), bij loslaten wel
start:Fire("PostClick", "LeftButton", true); RunTimers()
check(CarefreeBagQuestPopup:IsShown(), "Start quest ingedrukt: venster blijft nog even")
start:Fire("PostClick", "LeftButton", false); RunTimers()
check(not CarefreeBagQuestPopup:IsShown(), "Start quest: venster weg")

-- Bij inloggen: lijstje met restjes (Old Scrap of Paper en Faded Letter)
check(not CarefreeBagQuestReminder:IsShown(), "geen lijstje bij laadscherm/reload")
QE("PLAYER_ENTERING_WORLD", true)
check(CarefreeBagQuestReminder and CarefreeBagQuestReminder:IsShown(), "inloggen: lijstje met restjes")
local rows = NS.QuestReminderRows()
local ids = {}
for _, r in ipairs(rows) do if r.shown and r.item then ids[r.item.itemID] = r end end
check(ids[5002] and ids[5004] and not ids[5000] and not ids[5005], "lijstje: alleen de restjes")
ids[5004]:Choose("keep"); RunTimers()
check(CFC().questKeep[5004], "Always keep in het lijstje: onthouden")
local left = 0
for _, r in ipairs(rows) do if r.shown and r.item then left = left + 1 end end
check(left == 1 and CarefreeBagQuestReminder:IsShown(), "lijstje: nog 1 over")
CarefreeBagQuestReminder.later:Fire("OnClick")
check(not CarefreeBagQuestReminder:IsShown() and not CFC().questKeep[5002], "Remind me later: dicht, niets onthouden")
-- "All next level": alles in het lijstje uitstellen tot het volgende level
CarefreeBagQuestReminder:Show(); NS.QuestReminderFill()
check(not CarefreeBagQuestReminder.snoozeAll:IsShown(), "één item: geen knop All next level (minder knoppen)")
CFC().questKeep[5004] = nil; NS.QuestReminderFill()
check(CarefreeBagQuestReminder.snoozeAll:IsShown(), "twee items: knop All next level")
CarefreeBagQuestReminder.snoozeAll:Fire("OnClick"); RunTimers()
check(CFC().questSnooze[5002] == 20 and CFC().questSnooze[5004] == 20 and not CarefreeBagQuestReminder:IsShown(), "All next level: uitgesteld, lijstje dicht")
check(#NS.QuestLeftovers() == 0, "uitgesteld: niet meer in het lijstje")

-- #25: item met waarde = knop Auto Sell; zonder waarde = Destroy (met een vraag); volgende login
ITEMS[5006] = { name = "Gnoll Paw", quality = 1, stack = 10, bind = 1, icon = 8, quest = true, price = 7 }
ITEMS[5007] = { name = "Torn Page", quality = 1, stack = 1, bind = 1, icon = 9, quest = true }
ITEMS[5008] = { name = "Odd Rock", quality = 1, stack = 1, bind = 1, icon = 10, quest = true }
BAGS[0][8] = { itemID = 5006, count = 2 }; BAGS[0][9] = { itemID = 5007, count = 1 }; BAGS[0][10] = { itemID = 5008, count = 1 }
E("BAG_UPDATE_DELAYED"); QE("BAG_UPDATE_DELAYED"); RunTimers()
CarefreeBagQuestReminder:Show(); NS.QuestReminderFill()
check(Row(5006) and Row(5006).main:GetText() == "Auto Sell" and Row(5006).name:GetText():find("worth 14c", 1, true), "waarde: knop Auto Sell, 'worth 14c'")
Row(5006).main:Fire("OnClick"); RunTimers()
check(CFC().assign[5006] == "grey" and not Row(5006), "Auto Sell: in de groep Auto Sell, weg uit het lijstje")
DELETED = {}
function DeleteCursorItem() DELETED[#DELETED + 1] = CURSOR and CURSOR.itemID; CURSOR = nil end
check(Row(5007).main:GetText() == "Destroy", "geen waarde: knop Destroy")
Row(5007).main:Fire("OnClick")
check(POPUPS[#POPUPS].which == "CAREFREEBAG_DESTROY" and #DELETED == 0, "Destroy: eerst een vraag, nog niets weg")
StaticPopupDialogs.CAREFREEBAG_DESTROY.OnAccept(); RunTimers()
check(DELETED[1] == 5007 and BAGS[0][9] == nil and not Row(5007), "ja: weggegooid, weg uit het lijstje")
Row(5008):Choose("login"); RunTimers()
check(not Row(5008) and #NS.QuestLeftovers() == 0 and #NS.QuestLeftovers(true) > 0, "volgende login: nu niet meer in het lijstje (via Leftovers nog wel)")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
