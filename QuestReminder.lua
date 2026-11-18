-- CarefreeBag: QuestReminder.lua
-- Bij inloggen: een venster met de quest-items die waarschijnlijk weg kunnen (niet in je questlog).
-- Per item "Always keep" (nooit meer herinneren), of alles "Remind me later" (volgende login weer).
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Log, T = ns.Log, ns.T

local W, ROW, MAX_ROWS = 340, 26, 8
local win
local rows = {}
local retried = false -- leeg questlog bij inloggen: één keer later opnieuw kijken

-- Alle quest-restjes in je tassen, één regel per item.
function ns.QuestLeftovers()
	local list, at = {}, {}
	if not (ns.Scan and ns.QuestState) then return list end
	for _, e in ipairs(ns.Scan()) do
		if not e.key and not at[e.itemID] then
			local s = ns.QuestState(e.bag, e.slot, e.itemID, e.link, e.quest)
			if ns.QuestLeftover(s) then
				at[e.itemID] = true
				list[#list + 1] = { itemID = e.itemID, bag = e.bag, slot = e.slot, link = e.link, icon = e.info and e.info.iconFileID }
			end
		end
	end
	return list
end

local function Row(i)
	if rows[i] then return rows[i] end
	local r = CreateFrame("Button", nil, win)
	r:SetSize(W - 2 * ns.PAD, ROW)
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(22, 22)
	r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
	r.keep = ns.MakeButton(r, T("Always keep"), 104)
	r.keep:SetPoint("RIGHT", r, "RIGHT", 0, 0)
	r.keep:SetScript("OnClick", function()
		if r.item then ns.QuestSetKeep(r.item.itemID, true, r.item.link) end
		ns.QuestReminderFill()
	end)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetPoint("RIGHT", r.keep, "LEFT", -6, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	-- zo ziet de tooltip (QuestItems.lua) welk tasvak het is
	r.GetBagID = function(self) return self.item and self.item.bag end
	r:SetScript("OnEnter", function(self)
		if not self.item then return end
		self:SetID(self.item.slot)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetBagItem(self.item.bag, self.item.slot)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	rows[i] = r
	return r
end

local function Build()
	win = ns.NewWindow("CarefreeBagQuestReminder", T("Quest items you may not need"), W, 200)
	win:SetFrameStrata("DIALOG")
	win:ClearAllPoints()
	win:SetPoint("TOP", UIParent, "TOP", 0, -120)
	win.text = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	win.text:SetPoint("TOPLEFT", win, "TOPLEFT", ns.PAD, -32)
	win.text:SetWidth(W - 2 * ns.PAD)
	win.text:SetJustifyH("LEFT")
	win.text:SetWordWrap(true)
	win.text:SetText(T("These quest items are not in your quest log. Check them and throw away what you don't need. Hover an item to see why you may still need it."))
	win.more = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.later = ns.MakeButton(win, T("Remind me later"), 160)
	win.later:SetPoint("BOTTOM", win, "BOTTOM", 0, 14)
	win.later:SetScript("OnClick", function() win:Hide() end)
	ns.Tooltip(win.later, T("Remind me later"), T("You see this list again the next time you log in."))
end

-- Venster (opnieuw) vullen; niets meer over = dicht.
function ns.QuestReminderFill()
	if not win then return end
	local list = ns.QuestLeftovers()
	if #list == 0 then win:Hide(); return end
	local y = -32 - (win.text:GetStringHeight() or 24) - 8
	for i = 1, math.max(#rows, math.min(#list, MAX_ROWS)) do
		local item = list[i]
		if item and i <= MAX_ROWS then
			local r = Row(i)
			r.item = item
			r.icon:SetTexture(item.icon)
			r.name:SetText(item.link or tostring(item.itemID))
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", win, "TOPLEFT", ns.PAD, y)
			r:Show()
			y = y - ROW
		elseif rows[i] then
			rows[i].item = nil
			rows[i]:Hide()
		end
	end
	if #list > MAX_ROWS then
		win.more:SetText(T("and %d more in your bags (orange border)"):format(#list - MAX_ROWS))
		win.more:ClearAllPoints()
		win.more:SetPoint("TOPLEFT", win, "TOPLEFT", ns.PAD, y - 4)
		win.more:Show()
		y = y - 20
	else
		win.more:Hide()
	end
	win:SetHeight(-y + 50)
end

-- voor de tests
function ns.QuestReminderRows() return rows end

-- Bij inloggen (niet bij /reload of laadschermen): even wachten tot questlog en tassen er zijn.
function ns.QuestReminderLogin()
	C_Timer.After(6, function()
		if InCombatLockdown and InCombatLockdown() then return end
		-- questlog vers uitlezen: bij inloggen was het eerst nog leeg (dan leek alles een restje)
		if ns.QuestDirty then ns.QuestDirty() end
		local n = (GetNumQuestLogEntries and GetNumQuestLogEntries()) or (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetNumQuestLogEntries()) or 1
		if n == 0 and not retried then
			-- leeg questlog: misschien echt leeg, misschien nog niet geladen. Eén keer later opnieuw.
			retried = true
			ns.QuestReminderLogin()
			return
		end
		local list = ns.QuestLeftovers()
		Log(("quest reminder: %d leftover quest items"):format(#list))
		if #list == 0 then return end
		if not win then Build() end
		win:Show()
		ns.QuestReminderFill()
	end)
end
