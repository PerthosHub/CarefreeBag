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
	-- UIPanelButtonTemplate eerst, zodat de OnClick van de beveiligde template wint
	local ok, b = pcall(CreateFrame, "Button", "CarefreeBagQuestStartButton", popup, "UIPanelButtonTemplate,SecureActionButtonTemplate")
	if not ok then b = ns.MakeButton(popup, T("Start quest"), bw) end
	b:SetSize(bw, 22)
	if b.SetText then b:SetText(T("Start quest")) end
	if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "AnyUp", "AnyDown") end
	b:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", ns.PAD, 14)
	b:HookScript("PostClick", function(_, _, down)
		-- We luisteren naar indrukken én loslaten (de knop doet het op één van de twee, afhankelijk
		-- van de instelling "actie bij indrukken"). Pas bij loslaten dicht, anders mist hij het.
		if down then return end
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

-- Per karakter onthouden welke quest-items al een venster kregen (ch.questOffered[itemID] = true).
-- Zo komt een item dat je lootte terwijl CFB uit stond (of vlak voor uitloggen) na het inloggen
-- alsnog, en vraagt CFB niet elke keer opnieuw naar items die je bewust laat liggen.
local function Offered()
	local ch = ns.CharEntry and ns.CharEntry()
	if not ch then return nil end
	local first = ch.questOffered == nil
	ch.questOffered = ch.questOffered or {}
	return ch.questOffered, first
end

local function ShowFor(itemID, f)
	if not popup then Build() end
	local offered = Offered()
	if offered then offered[itemID] = true end
	popup.itemID, popup.used = itemID, nil
	popup.icon:SetTexture(f.icon)
	popup.name:SetText(f.link or tostring(itemID))
	popup.start:SetAttribute("type", "item")
	-- op itemID, niet op tas/vak: schuift het item intussen op, dan gebruikt de knop nog steeds dit item
	popup.start:SetAttribute("item", "item:" .. itemID)
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
local ready = false -- pas na het laadscherm (+3 s): dan zijn tassen en questinfo er
function ns.QuestStartReady()
	ready = true
	ns.QuestStartCheck()
end

function ns.QuestStartCheck()
	if not ready then return end
	if InCombatLockdown and InCombatLockdown() then return end -- beveiligde knop: pas na het gevecht
	local found = Starters()
	if not known then
		-- eerste keer (inloggen): items die al een venster kregen zijn de basis. Een item dat nog
		-- nooit gevraagd is (geloot met CFB uit, of vlak voor uitloggen) komt nu alsnog.
		-- Allereerste keer voor dit karakter (nog geen lijst): alles wat je al had telt als gevraagd.
		local offered, first = Offered()
		known = {}
		for id, f in pairs(found) do
			if not offered or first or offered[id] then
				known[id] = f.count
				if offered then offered[id] = true end
			end
		end
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
