-- CarefreeBag: QuestStart.lua
-- Loot je een item dat een quest start, dan komt er een venstertje met "Start quest".
-- Een addon mag een item niet zelf gebruiken: daarvoor is jouw klik nodig (beveiligde knop).
-- Na de klik zie je het gewone questvenster van WoW en accepteer je zelf.
-- Het item blijft in je tas lichtblauw knipperen tot de quest in je log staat (QuestItems.lua).
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Log, T = ns.Log, ns.T

local W, H = 300, 132
local popup
local known        -- [itemID] = aantal quest-start-items bij de vorige keer kijken (nil = nog geen basis)
local later = {}   -- [itemID] = true: "Later" gekozen, deze sessie niet meer vragen
local queue = {}   -- itemIDs die nog gevraagd moeten worden

-- Alle items in je tassen die een quest starten die je nog niet hebt.
local function Starters()
	local found = {}
	if not ns.Scan or not ns.QuestState then return found end
	local items = ns.Scan()
	for _, e in ipairs(items) do
		if not e.key then
			local s = ns.QuestState(e.bag, e.slot, e.itemID, e.link, e.quest)
			if s and s.kind == "start" then
				local f = found[e.itemID]
				if not f then f = { count = 0, bag = e.bag, slot = e.slot, link = e.link, icon = e.info and e.info.iconFileID }; found[e.itemID] = f end
				f.count = f.count + (e.count or 1)
			end
		end
	end
	return found
end

local function Build()
	popup = ns.NewWindow("CarefreeBagQuestPopup", T("Quest found"), W, H)
	popup:SetFrameStrata("DIALOG")
	popup:ClearAllPoints()
	popup:SetPoint("TOP", UIParent, "TOP", 0, -140)
	popup.icon = popup:CreateTexture(nil, "ARTWORK")
	popup.icon:SetSize(32, 32)
	popup.icon:SetPoint("TOPLEFT", popup, "TOPLEFT", ns.PAD, -34)
	popup.bang = popup:CreateTexture(nil, "OVERLAY")
	popup.bang:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
	popup.bang:SetSize(16, 16)
	popup.bang:SetPoint("TOPLEFT", popup.icon, "TOPLEFT", -4, 4)
	popup.name = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	popup.name:SetPoint("TOPLEFT", popup.icon, "TOPRIGHT", 8, -1)
	popup.name:SetWidth(W - 2 * ns.PAD - 40)
	popup.name:SetJustifyH("LEFT")
	popup.name:SetWordWrap(false)
	popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	popup.text:SetPoint("BOTTOMLEFT", popup.icon, "BOTTOMRIGHT", 8, 1)
	popup.text:SetText(T("This item starts a quest."))

	local bw = (W - 2 * ns.PAD - 10) / 2
	-- Beveiligde knop: een klik van jou gebruikt het item (type "item", item "tas vak").
	local ok, b = pcall(CreateFrame, "Button", "CarefreeBagQuestStartButton", popup, "SecureActionButtonTemplate,UIPanelButtonTemplate")
	if not ok then b = ns.MakeButton(popup, T("Start quest"), bw) end
	b:SetSize(bw, 22)
	if b.SetText then b:SetText(T("Start quest")) end
	if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "AnyUp", "AnyDown") end
	b:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", ns.PAD, 14)
	b:HookScript("PostClick", function()
		Log("quest start: item used from the popup")
		popup.used = true
		popup:Hide()
		C_Timer.After(0.3, ns.QuestStartCheck)
	end)
	ns.Tooltip(b, T("Start quest"), T("Opens the quest. You accept it yourself in the quest window."))
	popup.start = b
	local l = ns.MakeButton(popup, T("Later"), bw)
	l:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -ns.PAD, 14)
	l:SetScript("OnClick", function()
		if popup.itemID then later[popup.itemID] = true end
		popup:Hide()
		C_Timer.After(0.1, ns.QuestStartCheck)
	end)
	ns.Tooltip(l, T("Later"), T("The item keeps glowing in your bags until you start the quest. Right-click it there."))
	popup.later = l
	popup:HookScript("OnHide", function(self)
		-- zelf dichtgedaan (kruisje of Escape) = net als Later
		if not self.quiet and self.itemID and not self.used then later[self.itemID] = true end
	end)
end

local function ShowFor(itemID, f)
	if not popup then Build() end
	popup.itemID, popup.used = itemID, nil
	popup.icon:SetTexture(f.icon)
	popup.name:SetText(f.link or tostring(itemID))
	popup.start:SetAttribute("type", "item")
	popup.start:SetAttribute("item", f.bag .. " " .. f.slot)
	popup.quiet = true
	popup:Hide()
	popup.quiet = nil
	popup:Show()
	Log("quest start: popup for " .. tostring(f.link and f.link:match("%[(.-)%]") or itemID))
end

local function HideQuiet()
	if popup and popup:IsShown() then
		popup.quiet = true
		popup:Hide()
		popup.quiet = nil
	end
end

-- Kijken of er een nieuw quest-start-item is (na loot, na gevecht, na een questlog-wijziging).
function ns.QuestStartCheck()
	if InCombatLockdown and InCombatLockdown() then return end -- beveiligde knop: pas na het gevecht
	local found = Starters()
	if not known then
		-- eerste keer (inloggen): wat je al had is de basis, daar vragen we niet naar
		known = {}
		for id, f in pairs(found) do known[id] = f.count end
		return
	end
	for id, f in pairs(found) do
		if f.count > (known[id] or 0) and not later[id] then
			local dup = false
			for _, q in ipairs(queue) do if q == id then dup = true end end
			if not dup then queue[#queue + 1] = id end
		end
	end
	known = {}
	for id, f in pairs(found) do known[id] = f.count end
	-- alles wat al gestart is, gedropt of verkocht: uit de rij
	local rest = {}
	for _, id in ipairs(queue) do if found[id] and not later[id] then rest[#rest + 1] = id end end
	queue = rest
	if popup and popup:IsShown() then
		if not found[popup.itemID] then HideQuiet() else return end
	end
	local id = queue[1]
	if id then
		table.remove(queue, 1)
		ShowFor(id, found[id])
	end
end

-- Gevecht begint: een venster met een beveiligde knop mag dan niet meer weg. Nu dus even weg,
-- en na het gevecht weer terug.
function ns.QuestStartCombat()
	if popup and popup:IsShown() and popup.itemID then
		table.insert(queue, 1, popup.itemID)
		if known then known[popup.itemID] = 0 end
		HideQuiet()
	end
end

-- voor de tests
function ns.QuestStartPopup() return popup end
