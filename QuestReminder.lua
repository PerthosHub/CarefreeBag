-- CarefreeBag: QuestReminder.lua
-- Bij inloggen: een venster met de quest-items die waarschijnlijk weg kunnen (niet in je questlog).
-- Per item "Always keep" / "Next level", of alles "All next level" / "Remind me later" (volgende login).
-- Hetzelfde venster opent ook via het oranje "leftovers" in de kop van de groep Quest; dan staan
-- ook de items erin die je altijd houdt of hebt uitgesteld, met een knop "Remind me" om dat terug te draaien.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Log, T = ns.Log, ns.T

local W, ROW, MAX_ROWS = 430, 26, 8
local win
local rows = {}
local retried = false -- leeg questlog bij inloggen: één keer later opnieuw kijken

-- Alle quest-restjes in je tassen, één regel per item. all = ook wat je altijd houdt of hebt
-- uitgesteld (achteraan, item.kind = "kept"/"snoozed"). Tweede waarde: hoeveel daarvan restjes zijn.
function ns.QuestLeftovers(all)
	local list, rest, at = {}, {}, {}
	if not (ns.Scan and ns.QuestState) then return list, 0 end
	for _, e in ipairs(ns.Scan()) do
		if not e.key and not at[e.itemID] then
			local s = ns.QuestState(e.bag, e.slot, e.itemID, e.link, e.quest)
			local left = ns.QuestLeftover(s)
			if left or (all and s and (s.kind == "kept" or s.kind == "snoozed")) then
				at[e.itemID] = true
				local item = { itemID = e.itemID, bag = e.bag, slot = e.slot, link = e.link, icon = e.info and e.info.iconFileID,
					kind = not left and s.kind or nil, level = s.level }
				if left then list[#list + 1] = item else rest[#rest + 1] = item end
			end
		end
	end
	local n = #list
	for _, item in ipairs(rest) do list[#list + 1] = item end
	return list, n
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
		local item = r.item
		if not item then return end
		if item.kind == "kept" then ns.QuestSetKeep(item.itemID, false, item.link)
		elseif item.kind == "snoozed" then ns.QuestSetSnooze(item.itemID, false, item.link)
		else ns.QuestSetKeep(item.itemID, true, item.link) end
		ns.QuestReminderFill()
	end)
	-- "Next level": pas weer herinneren als je een level hoger bent
	r.snooze = ns.MakeButton(r, T("Next level"), 90)
	r.snooze:SetPoint("RIGHT", r.keep, "LEFT", -4, 0)
	r.snooze:SetScript("OnClick", function()
		if r.item then ns.QuestSetSnooze(r.item.itemID, true, r.item.link) end
		ns.QuestReminderFill()
	end)
	ns.Tooltip(r.snooze, T("Remind me next level"), T("No reminder for this item until you are a level higher."))
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetPoint("RIGHT", r.snooze, "LEFT", -6, 0)
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
	win.later = ns.MakeButton(win, T("Remind me later"), 170)
	win.later:SetPoint("BOTTOMRIGHT", win, "BOTTOM", -4, 14)
	win.later:SetScript("OnClick", function() win:Hide() end)
	ns.Tooltip(win.later, T("Remind me later"), T("You see this list again the next time you log in."))
	-- Alles uitstellen tot het volgende level
	win.snoozeAll = ns.MakeButton(win, T("All next level"), 170)
	win.snoozeAll:SetPoint("BOTTOMLEFT", win, "BOTTOM", 4, 14)
	win.snoozeAll:SetScript("OnClick", function()
		local list = ns.QuestLeftovers()
		for _, item in ipairs(list) do ns.QuestSetSnooze(item.itemID, true, item.link, true) end
		local lvl = tonumber(UnitLevel and UnitLevel("player")) or 0
		ns.Print(T("%d quest items: reminder again at level %d."):format(#list, lvl + 1))
		win:Hide()
	end)
	ns.Tooltip(win.snoozeAll, T("All next level"), T("No reminders for these items until you are a level higher."))
end

-- Venster (opnieuw) vullen; niets meer over = dicht.
function ns.QuestReminderFill()
	if not win then return end
	local list, nLeft = ns.QuestLeftovers(win.all)
	if #list == 0 then win:Hide(); return end
	-- op max level kun je niet hoger: dan alleen "Remind me later", in het midden
	local can = ns.QuestCanSnooze() and nLeft > 0
	win.snoozeAll:SetShown(can)
	win.later:ClearAllPoints()
	if can then win.later:SetPoint("BOTTOMRIGHT", win, "BOTTOM", -4, 14)
	else win.later:SetPoint("BOTTOM", win, "BOTTOM", 0, 14) end
	local y = -32 - (win.text:GetStringHeight() or 24) - 8
	for i = 1, math.max(#rows, math.min(#list, MAX_ROWS)) do
		local item = list[i]
		if item and i <= MAX_ROWS then
			local r = Row(i)
			r.item = item
			r.icon:SetTexture(item.icon)
			local name = item.link or tostring(item.itemID)
			if item.kind == "kept" then
				name = name .. "  |cff888888" .. T("always kept") .. "|r"
			elseif item.kind == "snoozed" then
				name = name .. "  |cff888888" .. T("from level %d"):format(item.level or 0) .. "|r"
			end
			r.name:SetText(name)
			r.keep:SetText(item.kind and T("Remind me") or T("Always keep"))
			r.snooze:SetShown(not item.kind and ns.QuestCanSnooze()) -- op max level kun je niet hoger
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
		win.all = false
		win:Show()
		ns.QuestReminderFill()
	end)
end

-- Via het oranje "leftovers" in de kop van de groep Quest (BagWindow.lua): alles, ook wat je houdt.
function ns.QuestReminderOpen()
	if not win then Build() end
	if win:IsShown() and win.all then win:Hide(); return end
	win.all = true
	win:Show()
	ns.QuestReminderFill()
end

-- Lijstje open en je gooit iets weg: lijstje bijwerken.
ns.OnEvent("BAG_UPDATE_DELAYED", "quest list", function()
	if win and win:IsShown() then ns.QuestReminderFill() end
end)
