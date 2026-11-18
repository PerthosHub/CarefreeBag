-- CarefreeBag: QuestItems.lua
-- Bij welke quest hoort een quest-item? We lezen je questlog uit (naam, level, doelen)
-- en koppelen de items in je tassen daaraan. Geen database: wat niet in je questlog
-- staat, krijgt een "?" en in de tooltip de redenen waarom je het misschien nog nodig hebt.
-- Items die een quest starten krijgen een "!", een eigen gloed en een venstertje (QuestStart.lua).
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Log, T = ns.Log, ns.T

---------------------------------------------------------------------------
-- Je questlog uitlezen
---------------------------------------------------------------------------

local quests = {}        -- { { title, level, questID, complete, objectives = { {text, have, need, done} }, text } }
local byID = {}          -- [questID] = quest
local nameCache = {}     -- [itemnaam] = quest of false (opnieuw bij elke nieuwe index)
local textCache = {}     -- [questID] = beschrijving + doeltekst (verandert niet)
local dirty = true
local lastBuild = -10

local function Try(fn, ...)
	if type(fn) ~= "function" then return nil end
	-- met n: GetQuestLogTitle geeft gaten (nil) tussen de waarden, unpack zonder n mist die
	local r = { n = 0 }
	local function pack(...) r.n = select("#", ...); for i = 1, r.n do r[i] = (select(i, ...)) end end
	pack(pcall(fn, ...))
	if not r[1] then return nil end
	return unpack(r, 2, r.n)
end

-- "Kobold Candle: 3/8" (Classic) of "3/8 Kobold Candle" (retail): de getallen eruit.
local function Counts(text)
	local have, need = tostring(text or ""):match("(%d+)%s*/%s*(%d+)")
	return tonumber(have), tonumber(need)
end

local function Objectives(q, index)
	local list = {}
	local objs = q.questID and C_QuestLog and Try(C_QuestLog.GetQuestObjectives, q.questID)
	if type(objs) == "table" and #objs > 0 then
		for _, o in ipairs(objs) do
			local have, need = o.numFulfilled, o.numRequired
			if not have then have, need = Counts(o.text) end
			list[#list + 1] = { text = o.text or "", have = have, need = need, done = o.finished, kind = o.type }
		end
		return list
	end
	local n = Try(GetNumQuestLeaderBoards, index) or 0
	for j = 1, n do
		local text, kind, done = Try(GetQuestLogLeaderBoard, j, index)
		if text then
			local have, need = Counts(text)
			list[#list + 1] = { text = text, have = have, need = need, done = done, kind = kind }
		end
	end
	return list
end

-- De questtekst (voor items die je krijgt of moet gebruiken, maar die geen doel zijn).
-- Daarvoor moet de quest even "gekozen" zijn in het questlog; we zetten de keuze terug.
local function QuestText(q, index)
	if not q.questID then return "" end
	if textCache[q.questID] then return textCache[q.questID] end
	local text
	if type(GetQuestLogQuestText) == "function" then
		if type(SelectQuestLogEntry) == "function" and type(GetQuestLogSelection) == "function" then
			local old = Try(GetQuestLogSelection)
			Try(SelectQuestLogEntry, index)
			local desc, obj = Try(GetQuestLogQuestText)
			text = (desc or "") .. " " .. (obj or "")
			if old then Try(SelectQuestLogEntry, old) end
		elseif C_QuestLog and C_QuestLog.SetSelectedQuest then
			local old = Try(C_QuestLog.GetSelectedQuest)
			Try(C_QuestLog.SetSelectedQuest, q.questID)
			local desc, obj = Try(GetQuestLogQuestText)
			text = (desc or "") .. " " .. (obj or "")
			if old and old ~= 0 then Try(C_QuestLog.SetSelectedQuest, old) end
		end
	end
	textCache[q.questID] = (text or ""):lower()
	return textCache[q.questID]
end

-- Alle quests in je log, ook onder dichtgeklapte kopjes (Classic laat die anders niet zien).
local function ReadLog()
	local list = {}
	if type(GetQuestLogTitle) == "function" and type(GetNumQuestLogEntries) == "function" then
		-- Classic-manier (ook Forever): dichtgeklapte kopjes even openklappen.
		local collapsed = {}
		local n = Try(GetNumQuestLogEntries) or 0
		for i = 1, n do
			local title, _, _, isHeader, isCollapsed = Try(GetQuestLogTitle, i)
			if isHeader and isCollapsed and title then collapsed[title] = true end
		end
		if next(collapsed) and type(ExpandQuestHeader) == "function" then Try(ExpandQuestHeader, 0) end
		n = Try(GetNumQuestLogEntries) or 0
		for i = 1, n do
			local title, level, _, isHeader, _, isComplete, _, questID = Try(GetQuestLogTitle, i)
			if title and not isHeader then
				local q = { title = title, level = level, questID = questID, complete = (isComplete == 1 or isComplete == true) }
				q.objectives = Objectives(q, i)
				q.text = QuestText(q, i)
				list[#list + 1] = q
			end
		end
		if next(collapsed) and type(CollapseQuestHeader) == "function" then
			for i = (Try(GetNumQuestLogEntries) or 0), 1, -1 do
				local title, _, _, isHeader = Try(GetQuestLogTitle, i)
				if isHeader and collapsed[title] then Try(CollapseQuestHeader, i) end
			end
		end
	elseif C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
		-- Retail-manier.
		local n = Try(C_QuestLog.GetNumQuestLogEntries) or 0
		for i = 1, n do
			local info = Try(C_QuestLog.GetInfo, i)
			if info and not info.isHeader and info.title then
				local done = info.questID and C_QuestLog.IsComplete and Try(C_QuestLog.IsComplete, info.questID)
				local q = { title = info.title, level = info.level, questID = info.questID, complete = done and true or false }
				q.objectives = Objectives(q, i)
				q.text = QuestText(q, i)
				list[#list + 1] = q
			end
		end
	end
	return list
end

local function Build()
	quests = ReadLog()
	byID, nameCache = {}, {}
	for _, q in ipairs(quests) do if q.questID then byID[q.questID] = q end end
	dirty = false
	lastBuild = GetTime and GetTime() or 0
end

local function Index()
	if dirty then
		local ok, err = pcall(Build)
		if not ok then dirty = false; Log("quest log: " .. tostring(err)) end
	end
	return quests
end

-- Bij welke quest hoort een item met deze naam? Eerst de doelen ("Kobold Candle: 3/8"),
-- dan de questtekst ("Use the Kobold Candle ..."). Korte namen niet in de tekst zoeken.
local function QuestForName(name)
	if not name or name == "" then return nil end
	Index()
	local hit = nameCache[name]
	if hit ~= nil then return hit or nil end
	local low = name:lower()
	hit = false
	for _, q in ipairs(quests) do
		for _, o in ipairs(q.objectives or {}) do
			if o.text:lower():find(low, 1, true) then hit = { quest = q, obj = o }; break end
		end
		if hit then break end
	end
	if not hit and #low >= 4 then
		for _, q in ipairs(quests) do
			if (q.text or ""):find(low, 1, true) then hit = { quest = q }; break end
		end
	end
	nameCache[name] = hit
	return hit or nil
end

---------------------------------------------------------------------------
-- Wat is dit quest-item?
---------------------------------------------------------------------------

local startsCache = {} -- [itemID] = true/false: "This Item Begins a Quest" in de tooltip

local function StartsQuestByTooltip(bag, slot, itemID)
	if startsCache[itemID] ~= nil then return startsCache[itemID] end
	local want = ITEM_STARTS_QUEST
	if not want then return false end
	local found = false
	local data = C_TooltipInfo and C_TooltipInfo.GetBagItem and Try(C_TooltipInfo.GetBagItem, bag, slot)
	if type(data) == "table" and data.lines then
		for _, l in ipairs(data.lines) do
			if l.leftText == want then found = true end
		end
		startsCache[itemID] = found
	end
	return found
end

local function Completed(questID)
	if not questID then return false end
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		return Try(C_QuestLog.IsQuestFlaggedCompleted, questID) and true or false
	end
	return Try(IsQuestFlaggedCompleted, questID) and true or false
end

local function ItemName(itemID, link)
	local n = link and link:match("%[(.-)%]")
	if n then return n end
	return C_Item and C_Item.GetItemInfo and Try(C_Item.GetItemInfo, itemID) or nil
end

-- Wat weten we van het item in dit tasvak?
-- kind: "active" (hoort bij een quest in je log), "start" (start een quest die je nog niet hebt),
-- "done" (start een quest die je al gedaan hebt), "orphan" (quest-item, niet in je log), of nil.
function ns.QuestState(bag, slot, itemID, link, isQuest)
	if not (bag and slot and itemID) then return nil end
	local q = C_Container and C_Container.GetContainerItemQuestInfo and Try(C_Container.GetContainerItemQuestInfo, bag, slot)
	q = type(q) == "table" and q or {}
	local qid = q.questID
	if qid and qid ~= 0 then
		Index()
		if q.isActive or byID[qid] then
			local rec = byID[qid]
			if rec then return { kind = "active", quest = rec } end
			return { kind = "active" }
		end
		if Completed(qid) then return { kind = "done", questID = qid } end
		return { kind = "start", questID = qid }
	end
	local quest = isQuest or q.isQuestItem
	local starts = StartsQuestByTooltip(bag, slot, itemID)
	if not quest and not starts then return nil end
	local hit = QuestForName(ItemName(itemID, link))
	if hit then return { kind = "active", quest = hit.quest, obj = hit.obj } end
	if starts then return { kind = "start" } end
	return { kind = "orphan" }
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local BLUE = "|cff66ccff"

local function QuestLabel(q)
	local name = q.title or "?"
	local level = tonumber(q.level)
	local text = level and level > 0 and ("[" .. level .. "] " .. name) or name
	local c = level and level > 0 and Try(GetQuestDifficultyColor, level)
	if type(c) == "table" and c.r then
		local f = math.floor
		return ("|cff%02x%02x%02x%s|r"):format(f(c.r * 255), f(c.g * 255), f(c.b * 255), text)
	end
	return "|cffffd100" .. text .. "|r"
end

-- Regels onder de tooltip. Werkt voor onze vakjes en die van Blizzard (bagID + slot).
function ns.QuestTooltip(tt, owner)
	if not (tt and owner) then return end
	local bag, slot
	if owner.isCarefreeItem and owner.group and owner.group.rep then
		bag, slot = owner.group.rep.bag, owner.group.rep.slot
	elseif owner.GetBagID and owner.GetID then
		bag, slot = Try(owner.GetBagID, owner), Try(owner.GetID, owner)
	end
	if not (bag and slot) then return end
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not (info and info.itemID) then return end
	-- alleen als de tooltip echt over dit item gaat
	if tt.GetItem then
		local _, link = tt:GetItem()
		local id = link and tonumber(link:match("item:(%d+)"))
		if id and id ~= info.itemID then return end
	end
	local isQuest = owner.group and owner.group.rep and owner.group.rep.quest
	local s = ns.QuestState(bag, slot, info.itemID, info.hyperlink, isQuest)
	if not s then return end
	tt:AddLine(" ")
	if s.kind == "active" then
		if s.quest then
			tt:AddLine(BLUE .. "CarefreeBag:|r " .. T("For the quest %s"):format(QuestLabel(s.quest)), 1, 1, 1, true)
			local o = s.obj
			if s.quest.complete then
				tt:AddLine(T("Quest ready to turn in."), 0.25, 1, 0.25, true)
			elseif o and o.have and o.need then
				tt:AddLine(T("Progress: %d/%d"):format(o.have, o.need), 1, 1, 1, true)
			end
		else
			tt:AddLine(BLUE .. "CarefreeBag:|r " .. T("For a quest in your quest log."), 1, 1, 1, true)
		end
	elseif s.kind == "start" then
		tt:AddLine(BLUE .. "CarefreeBag:|r |cffffd100" .. T("Starts a quest. Right-click to read it and accept.") .. "|r", 1, 1, 1, true)
	elseif s.kind == "done" then
		tt:AddLine(BLUE .. "CarefreeBag:|r " .. T("You already did the quest this item starts. It can probably go."), 1, 0.6, 0.2, true)
	else
		tt:AddLine(BLUE .. "CarefreeBag:|r |cffff9933" .. T("Not in your quest log: it can probably go.") .. "|r", 1, 1, 1, true)
		tt:AddLine(T("Check first, it may still be needed for:"), 0.8, 0.8, 0.8, true)
		for _, r in ipairs({ T("the next step of a quest chain"), T("a repeatable quest (reputation)"),
			T("a quest you have not picked up yet"), T("a class or dungeon quest") }) do
			tt:AddLine("  - " .. r, 0.8, 0.8, 0.8, true)
		end
	end
	tt:Show()
end

---------------------------------------------------------------------------
-- Markering op de vakjes in het tassenvenster
---------------------------------------------------------------------------

local START_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"   -- geel "!"
local ORPHAN_ICON = "Interface\\GossipFrame\\IncompleteQuestIcon" -- grijs "?"

local function Parts(b)
	if b.cfbQuest then return b.cfbQuest end
	local p = {}
	p.icon = b:CreateTexture(nil, "OVERLAY", nil, 7)
	p.icon:SetSize(14, 14)
	p.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	p.icon:Hide()
	-- Quest-start: lichtblauwe, rustig pulserende rand. Anders dan de gouden "nieuw"-rand,
	-- en hij blijft tot de quest in je log staat (niet weg bij hover).
	p.glow = b:CreateTexture(nil, "OVERLAY", nil, 6)
	p.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	p.glow:SetBlendMode("ADD")
	p.glow:SetVertexColor(0.3, 0.75, 1)
	p.glow:SetPoint("CENTER")
	p.glow:SetSize(ns.TILE * 1.9, ns.TILE * 1.9)
	p.glow:Hide()
	local okA, ag = pcall(p.glow.CreateAnimationGroup, p.glow)
	if okA and ag then
		ag:SetLooping("BOUNCE")
		local a = ag:CreateAnimation("Alpha")
		a:SetFromAlpha(1); a:SetToAlpha(0.1); a:SetDuration(1.2)
		p.pulse = ag
	end
	b.cfbQuest = p
	return p
end

-- Aangeroepen voor elk vakje in het tassenvenster (BagWindow.lua, SetupItemButton).
function ns.QuestMark(b, g)
	local e = g and g.rep
	local s = e and ns.QuestState(e.bag, e.slot, e.itemID, e.link, e.quest)
	local kind = s and s.kind
	if not kind and not b.cfbQuest then return end
	local p = Parts(b)
	b.questKind = kind
	if kind == "start" then
		p.icon:SetTexture(START_ICON); p.icon:Show()
	elseif kind == "orphan" or kind == "done" then
		p.icon:SetTexture(ORPHAN_ICON); p.icon:Show()
	else
		p.icon:Hide()
	end
	local glow = kind == "start" and ns.searchText == ""
	p.glow:SetShown(glow)
	if glow then
		if b.newGlow then b.newGlow:Hide() end -- de quest-gloed gaat voor
		if b.newPulse then b.newPulse:Stop() end
		if p.pulse and not (p.pulse.IsPlaying and p.pulse:IsPlaying()) then p.pulse:Play() end
	elseif p.pulse then
		p.pulse:Stop()
	end
end

---------------------------------------------------------------------------
-- Events: questlog veranderd = opnieuw uitlezen (en het venster bijwerken)
---------------------------------------------------------------------------

local refreshPending = false
local function ScheduleRefresh()
	if refreshPending then return end
	refreshPending = true
	C_Timer.After(0.5, function()
		refreshPending = false
		if ns.main and ns.main:IsShown() and ns.Refresh then pcall(ns.Refresh) end
		if ns.QuestStartCheck then pcall(ns.QuestStartCheck) end
	end)
end

function ns.QuestEvent(event, a1)
	if event == "QUEST_LOG_UPDATE" then
		-- Ons eigen uitlezen (kopjes open/dicht, quest kiezen) geeft ook deze melding: niet opnieuw.
		local now = GetTime and GetTime() or 0
		if not dirty and now - lastBuild < 1 then return end
		dirty = true
		ScheduleRefresh()
	elseif event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
		dirty = true
		if event == "QUEST_TURNED_IN" then textCache[a1 or 0] = nil end
		ScheduleRefresh()
	elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
		if ns.QuestStartCheck then pcall(ns.QuestStartCheck) end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if ns.QuestStartCombat then pcall(ns.QuestStartCombat) end
	end
end

local events = CreateFrame("Frame")
for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED",
	"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD" }) do
	pcall(events.RegisterEvent, events, ev)
end
events:SetScript("OnEvent", function(_, event, a1)
	if not (ns.DB and ns.DB.enabled ~= false) then return end
	local ok, err = pcall(ns.QuestEvent, event, a1)
	if not ok then Log("quest items: " .. tostring(err)) end
end)
ns.questEvents = events
