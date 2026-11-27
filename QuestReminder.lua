-- CarefreeBag: QuestReminder.lua
-- Bij inloggen: een venster met de quest-items die waarschijnlijk weg kunnen (niet in je questlog).
-- Per item één knop met het advies (Johan, #25: minder knoppen): heeft het een prijs, dan
-- "Auto Sell" (wordt bij de volgende vendor verkocht), anders "Destroy" (met een vraag vooraf).
-- De andere keuzes staan in het ▼-menu: weggooien, volgende login, volgend level, altijd houden.
-- Onderaan "Remind me later" (volgende login) en, bij meerdere items, "All next level".
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
local skipNow = {}    -- "Remind me next login": deze sessie niet meer in het lijstje

-- Alle quest-restjes in je tassen, één regel per item. all = ook wat je altijd houdt of hebt
-- uitgesteld (achteraan, item.kind = "kept"/"snoozed"). Tweede waarde: hoeveel daarvan restjes zijn.
function ns.QuestLeftovers(all)
	local list, rest, at = {}, {}, {}
	if not (ns.Scan and ns.QuestState) then return list, 0 end
	local assign = ns.Assign()
	for _, e in ipairs(ns.Scan()) do
		if assign[e.itemID] == "grey" then
			-- al naar Auto Sell (wordt bij de vendor verkocht): geen herinnering meer nodig
		elseif not e.key and at[e.itemID] then
			at[e.itemID].count = at[e.itemID].count + (e.count or 1) -- meer stapels van hetzelfde item
		elseif not e.key then
			local s = ns.QuestState(e.bag, e.slot, e.itemID, e.link, e.quest)
			local left = ns.QuestLeftover(s) and (all or not skipNow[e.itemID])
			if left or (all and s and (s.kind == "kept" or s.kind == "snoozed")) then
				local item = { itemID = e.itemID, bag = e.bag, slot = e.slot, link = e.link, icon = e.info and e.info.iconFileID,
					kind = not left and s.kind or nil, level = s.level, price = e.price or 0, count = e.count or 1 }
				at[e.itemID] = item
				if left then list[#list + 1] = item else rest[#rest + 1] = item end
			end
		end
	end
	local n = #list
	for _, item in ipairs(rest) do list[#list + 1] = item end
	return list, n
end

local function Money(m) return GetMoneyString and GetMoneyString(math.floor(m), true) or tostring(m) end

-- Kan het naar Auto Sell? Alleen met een vendorprijs en als de groep Auto Sell aan staat.
local function CanSell(item) return (item.price or 0) > 0 and ns.On and ns.On("grey") end

local function Refill() if ns.QuestReminderFill then ns.QuestReminderFill() end end

-- Naar Auto Sell: wordt bij de volgende vendor vanzelf verkocht.
local function ToAutoSell(item)
	ns.Assign()[item.itemID] = "grey"
	ns.Print(T("%s goes to Auto Sell: sold at the next vendor."):format(item.link or tostring(item.itemID)))
	Log("quest leftover to auto sell " .. tostring(item.itemID))
	if ns.Refresh then pcall(ns.Refresh) end
	Refill()
end

-- Weggooien (alle stapels van dit item), na een vraag. Mag alleen tijdens een echte klik: de knop
-- in WoW's vraagvenster is die klik.
local destroyItem
local function DestroyNow()
	local item = destroyItem
	destroyItem = nil
	if not item then return end
	local n = 0
	for _, e in ipairs(ns.Scan()) do
		if e.itemID == item.itemID and not e.key and not e.info.isLocked then
			if CursorHasItem() then ClearCursor() end
			C_Container.PickupContainerItem(e.bag, e.slot)
			local kind, id = GetCursorInfo()
			if kind == "item" and id == item.itemID then
				DeleteCursorItem()
				n = n + (e.count or 1)
			else
				ClearCursor()
			end
		end
	end
	if n > 0 then
		ns.Print(T("Destroyed %s."):format((item.link or tostring(item.itemID)) .. (n > 1 and (" x" .. n) or "")))
		Log("quest leftover destroyed " .. tostring(item.itemID) .. " x" .. n)
	end
	Refill()
end

local function AskDestroy(item)
	if not (StaticPopupDialogs and StaticPopup_Show) then return end
	destroyItem = item
	StaticPopupDialogs["CAREFREEBAG_DESTROY"] = {
		text = T("Destroy %s?\nYou cannot get it back."),
		button1 = T("Destroy"), button2 = T("Cancel"),
		OnAccept = DestroyNow,
		OnCancel = function() destroyItem = nil end,
		timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
	}
	StaticPopup_Show("CAREFREEBAG_DESTROY", item.link or tostring(item.itemID))
end

-- Alle keuzes voor één item (knop en ▼-menu gebruiken dezelfde).
local function Choose(item, what)
	if not item then return end
	if what == "sell" then ToAutoSell(item)
	elseif what == "destroy" then AskDestroy(item)
	elseif what == "login" then
		skipNow[item.itemID] = true
		ns.Print(T("%s: reminder again the next time you log in."):format(item.link or tostring(item.itemID)))
		Refill()
	elseif what == "snooze" then ns.QuestSetSnooze(item.itemID, true, item.link); Refill()
	elseif what == "keep" then ns.QuestSetKeep(item.itemID, true, item.link); Refill()
	elseif what == "remind" then
		-- terugdraaien (lijstje via "Leftovers"): weer herinneren
		if item.kind == "kept" then ns.QuestSetKeep(item.itemID, false, item.link)
		elseif item.kind == "snoozed" then ns.QuestSetSnooze(item.itemID, false, item.link) end
		Refill()
	end
end

-- Het advies van een item: de knop, en een korte grijze tekst achter de naam.
local function Advice(item)
	if item.kind then return "remind", T("Remind me") end
	if CanSell(item) then return "sell", T("Auto Sell"), T("worth %s"):format(Money(item.price * item.count)) end
	return "destroy", T("Destroy"), T("no value")
end

local function OpenMenu(r)
	local item = r.item
	if not item or item.kind then return end
	local main = Advice(item)
	local list = {}
	if main ~= "destroy" then list[#list + 1] = { text = T("Destroy"), fn = function() Choose(item, "destroy") end } end
	if main ~= "sell" and CanSell(item) then list[#list + 1] = { text = T("Move to Auto Sell"), fn = function() Choose(item, "sell") end } end
	list[#list + 1] = { text = T("Remind me next login"), fn = function() Choose(item, "login") end }
	if ns.QuestCanSnooze() then list[#list + 1] = { text = T("Remind me next level"), fn = function() Choose(item, "snooze") end } end
	list[#list + 1] = { text = T("Always keep"), fn = function() Choose(item, "keep") end }
	r.menuChoices = list -- voor de tests
	ns.ChoiceMenu(r.opt, item.link and item.link:match("%[(.-)%]") or nil, list)
end

local function Row(i)
	if rows[i] then return rows[i] end
	local r = CreateFrame("Button", nil, win)
	r:SetSize(W - 2 * ns.PAD, ROW)
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(22, 22)
	r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
	-- ▼: de andere keuzes
	r.opt = CreateFrame("Button", nil, r)
	r.opt:SetSize(24, 24)
	r.opt:SetPoint("RIGHT", r, "RIGHT", 0, 0)
	r.opt:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	r.opt:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
	r.opt:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	r.opt:SetScript("OnClick", function() OpenMenu(r) end)
	ns.Tooltip(r.opt, T("More choices"), T("Destroy, remind me next login or next level, or always keep."))
	-- de knop met het advies
	r.main = ns.MakeButton(r, T("Destroy"), 96)
	r.main:SetPoint("RIGHT", r.opt, "LEFT", -2, 0)
	r.main:SetScript("OnClick", function() Choose(r.item, r.action) end)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
	r.name:SetPoint("RIGHT", r.main, "LEFT", -6, 0)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	-- voor de tests: een keuze maken zonder menu
	r.Choose = function(self, what) Choose(self.item, what) end
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
	win.text:SetText(T("Not in your quest log anymore, so you probably don't need these. Hover an item to see why you may still need it."))
	win.more = win:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	win.later = ns.MakeButton(win, T("Remind me later"), 170)
	win.later:SetPoint("BOTTOMRIGHT", win, "BOTTOM", -4, 14)
	win.later:SetScript("OnClick", function() win:Hide() end)
	ns.Tooltip(win.later, T("Remind me later"), T("You see this list again the next time you log in."))
	-- Alles uitstellen tot het volgende level (alleen bij meer dan één item)
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
	local can = ns.QuestCanSnooze() and nLeft > 1
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
			local action, label, note = Advice(item)
			if item.kind == "kept" then
				note = T("always kept")
			elseif item.kind == "snoozed" then
				note = T("from level %d"):format(item.level or 0)
			end
			if note then name = name .. "  |cff888888" .. note .. "|r" end
			r.name:SetText(name)
			r.action = action
			r.main:SetText(label)
			r.opt:SetShown(not item.kind)
			r.main:ClearAllPoints()
			if item.kind then r.main:SetPoint("RIGHT", r, "RIGHT", 0, 0)
			else r.main:SetPoint("RIGHT", r.opt, "LEFT", -2, 0) end
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
