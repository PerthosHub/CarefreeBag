-- CarefreeBag: BankPanel.lua
-- Paneel naast je tassen: bank en de tassen/bank van je andere karakters (alleen bekijken).
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local GAP, Log, MakeButton, MyFullName, NewWindow = ns.GAP, ns.Log, ns.MakeButton, ns.MyFullName, ns.NewWindow
local SectionList, SectionOf, SLOT_TEX, T = ns.SectionList, ns.SectionOf, ns.SLOT_TEX, ns.T

---------------------------------------------------------------------------
-- Paneel naast je tassen: je bank, en de tassen en bank van je andere karakters
-- (alleen bekijken; verplaatsen doe je bij de bankier zoals altijd)
---------------------------------------------------------------------------

local viewer
local viewTiles, viewHeads = {}, {}
local Hits, UpdatePortraits, ViewLayout -- verderop
local PORT = 36 -- grootte van een karakterportret (knop met ronde rand)
local PORT_W = PORT + 8 -- breedte van de portrettenrij links (plus de gouden streep)

-- Goud als tekst met munt-icoontjes.
local function Money(m)
	m = math.floor(m or 0)
	if GetMoneyString then
		local ok, s = pcall(GetMoneyString, m, true)
		if ok and s then return s end
	end
	if GetCoinTextureString then
		local ok, s = pcall(GetCoinTextureString, m)
		if ok and s then return s end
	end
	return tostring(m)
end

-- Goud van een karakter: van jezelf wat je nu hebt, van de rest wat er onthouden is.
local function CharMoney(key)
	if key == ns.charKey then
		local ok, m = pcall(GetMoney)
		if ok and type(m) == "number" then return m end
	end
	local ch = ns.DB.chars[key]
	return ch and ch.snap and ch.snap.money
end

-- Karakters om uit te kiezen: jijzelf eerst, daarna de rest op naam.
local function ViewChars()
	local list = {}
	for key, ch in pairs(ns.DB.chars or {}) do
		if not ch.legacy and (key == ns.charKey or ch.snap) then
			list[#list + 1] = { key = key, name = (ch.snap and ch.snap.name) or MyFullName() or key }
		end
	end
	table.sort(list, function(a, b)
		if (a.key == ns.charKey) ~= (b.key == ns.charKey) then return a.key == ns.charKey end
		return a.name < b.name
	end)
	return list
end

local function ViewTile(i)
	local t = viewTiles[i]
	if not t then
		t = CreateFrame("Button", nil, viewer.content)
		t:SetSize(ns.TILE, ns.TILE)
		t.bg = t:CreateTexture(nil, "BACKGROUND")
		t.bg:SetAllPoints(t)
		t.bg:SetTexture(SLOT_TEX)
		t.icon = t:CreateTexture(nil, "ARTWORK")
		t.icon:SetPoint("TOPLEFT", t, "TOPLEFT", 1, -1)
		t.icon:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -1, 1)
		t.border = t:CreateTexture(nil, "OVERLAY")
		t.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		t.border:SetBlendMode("ADD")
		t.border:SetPoint("CENTER", t, "CENTER", 0, 0)
		t.border:SetSize(ns.TILE * 1.8, ns.TILE * 1.8)
		t.count = t:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		t.count:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, 2)
		t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		t:SetScript("OnEnter", function(self)
			if not self.link then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
			GameTooltip:Show()
		end)
		t:SetScript("OnLeave", function() GameTooltip:Hide() end)
		t:SetScript("OnClick", function(self)
			if self.link and HandleModifiedItemClick then pcall(HandleModifiedItemClick, self.link) end
		end)
		viewTiles[i] = t
	end
	t:Show()
	return t
end

local function ViewHead(i)
	local h = viewHeads[i]
	if not h then
		h = viewer.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h:SetJustifyH("LEFT")
		viewHeads[i] = h
	end
	h:Show()
	return h
end

---------------------------------------------------------------------------
-- Zoek-hits op de bank en bij je andere karakters
---------------------------------------------------------------------------

local function Matches(r)
	if ns.searchText == "" then return false end
	local name = ((r.l or ""):lower():match("%[(.-)%]") or "")
	return name:find(ns.searchText, 1, true) ~= nil
end

-- Aantal vakjes met een hit in de tassen ("bags") of bank ("bank") van een karakter.
function Hits(key, part)
	if ns.searchText == "" then return 0 end
	local ch = ns.DB.chars[key]
	local rows = ch and ch.snap and ch.snap[part]
	local n = 0
	for _, r in ipairs(rows or {}) do if Matches(r) then n = n + 1 end end
	return n
end

-- Waar het eerst gevonden wordt: eigen bank, dan andere karakters (tassen, dan bank).
local function FirstHit()
	if Hits(ns.charKey, "bank") > 0 then return ns.charKey, "bank" end
	for _, c in ipairs(ViewChars()) do
		if c.key ~= ns.charKey then
			if Hits(c.key, "bags") > 0 then return c.key, "bags" end
			if Hits(c.key, "bank") > 0 then return c.key, "bank" end
		end
	end
end

-- Alle hits buiten je eigen tassen (voor het getal op de knop Bank & alts).
local function OtherHits()
	local n = 0
	for _, c in ipairs(ViewChars()) do
		n = n + Hits(c.key, "bank")
		if c.key ~= ns.charKey then n = n + Hits(c.key, "bags") end
	end
	return n
end

-- Karakter met hits: kies het deel (tassen of bank) waar het zit.
local function PartWithHits(key, current)
	if key == ns.charKey then return "bank" end
	if Hits(key, current or "bags") > 0 then return current or "bags" end
	if Hits(key, "bags") > 0 then return "bags" end
	if Hits(key, "bank") > 0 then return "bank" end
	return current
end

---------------------------------------------------------------------------
-- Karakter wisselen: ronde klasse-portretten langs de linkerkant
---------------------------------------------------------------------------

local portraits = {}
ns.viewPortraits = portraits -- voor de tests

-- Rond klasse-icoon met de ronde rand van de minimapknoppen. Het gekozen karakter is in kleur
-- met een gouden rand en een gouden streep ernaast; de andere zijn grijs en doorzichtig.
local function Portrait(i)
	local p = portraits[i]
	if p then p:Show(); return p end
	p = CreateFrame("Button", nil, viewer)
	p:SetSize(PORT, PORT)
	local k = PORT / 32 -- Blizzard-maten 32/20/54
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetSize(20 * k, 20 * k)
	p.icon:SetPoint("TOPLEFT", p, "TOPLEFT", 6 * k, -6 * k)
	local okM, mask = pcall(p.CreateMaskTexture, p)
	if okM and mask then
		mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetAllPoints(p.icon)
		pcall(p.icon.AddMaskTexture, p.icon, mask)
	end
	p.ring = p:CreateTexture(nil, "OVERLAY")
	p.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	p.ring:SetSize(54 * k, 54 * k)
	p.ring:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
	-- gouden streep rechts van het gekozen karakter (wijst naar het paneel)
	-- gekozen karakter: zachte ronde gouden gloed achter het icoon
	p.sel = p:CreateTexture(nil, "BACKGROUND")
	p.sel:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	p.sel:SetBlendMode("ADD")
	p.sel:SetVertexColor(1, 0.8, 0.2, 0.9)
	p.sel:SetSize(34 * k, 34 * k)
	p.sel:SetPoint("CENTER", p.icon, "CENTER", 0, 0)
	p.sel:Hide()
	p.hits = p:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	p.hits:SetPoint("BOTTOMRIGHT", p.icon, "BOTTOMRIGHT", 4, -3)
	p.hits:SetTextColor(1, 0.82, 0)
	p:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
	local hl = p:GetHighlightTexture()
	if hl then hl:ClearAllPoints(); hl:SetSize(28 * k, 28 * k); hl:SetPoint("CENTER", p.icon, "CENTER", 0, 0) end
	p:SetScript("OnEnter", function(self)
		local c = self.char
		if not c then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		local col = self.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[self.class]
		GameTooltip:AddLine(c.name .. (c.key == ns.charKey and (" |cff33ff99" .. T("(you)") .. "|r") or ""),
			col and col.r or 1, col and col.g or 1, col and col.b or 1)
		local m = CharMoney(c.key)
		if m then GameTooltip:AddLine(Money(m), 1, 1, 1) end
		GameTooltip:Show()
	end)
	p:SetScript("OnLeave", function() GameTooltip:Hide() end)
	p:SetScript("OnClick", function(self)
		if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
		viewer.key = self.char.key
		viewer.part = PartWithHits(viewer.key, viewer.part)
		viewer.scroll:SetVerticalScroll(0)
		ViewLayout()
	end)
	portraits[i] = p
	return p
end

-- Zet de portretten neer; geeft de hoogte van de rij terug.
function UpdatePortraits()
	for _, p in ipairs(portraits) do p:Hide() end
	local list = ViewChars()
	for i, c in ipairs(list) do
		local p = Portrait(i)
		p.char = c
		p:ClearAllPoints()
		p:SetPoint("TOPLEFT", viewer, "TOPLEFT", ns.PAD - 2, -32 - (i - 1) * (PORT + 4))
		local ch = ns.DB.chars[c.key]
		local class = (ch and ch.snap and ch.snap.class) or (c.key == ns.charKey and UnitClass and select(2, UnitClass("player")))
		p.class = class
		-- Klasse-icoon: atlas "classicon-warrior" als die bestaat, anders de klassencirkels.
		local atlas = class and ("classicon-" .. class:lower())
		local tc = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
		if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) and p.icon.SetAtlas then
			p.icon:SetAtlas(atlas)
		elseif tc then
			p.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
			p.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
		else
			p.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			p.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		end
		local chosen = c.key == viewer.key
		p.sel:SetShown(chosen)
		p.icon:SetDesaturated(not chosen)
		p.icon:SetAlpha(chosen and 1 or 0.5)
		p.ring:SetDesaturated(not chosen)
		if chosen then p.ring:SetVertexColor(1, 0.9, 0.4) else p.ring:SetVertexColor(0.6, 0.6, 0.6) end
		local n = Hits(c.key, "bank") + (c.key ~= ns.charKey and Hits(c.key, "bags") or 0)
		p.hits:SetText(n > 0 and n or "")
	end
	return 32 + #list * (PORT + 4)
end

function ViewLayout()
	if not viewer or not viewer:IsShown() then return end
	for _, t in ipairs(viewTiles) do t:Hide() end
	for _, h in ipairs(viewHeads) do h:Hide() end
	-- Standaard: de bank van het karakter waarmee je speelt.
	viewer.key = viewer.key or ns.charKey
	viewer.part = viewer.part or "bank"
	-- Je eigen tassen staan al rechts open: bij jezelf alleen de bank.
	if viewer.key == ns.charKey then viewer.part = "bank" end
	viewer.tabs.bags:SetShown(viewer.key ~= ns.charKey)
	viewer.tabs.bank:SetShown(viewer.key ~= ns.charKey)
	local choice = { key = viewer.key, part = viewer.part }
	local ch0 = ns.DB.chars[choice.key]
	local me = choice.key == ns.charKey
	local who = (ch0 and ch0.snap and ch0.snap.name) or (me and MyFullName()) or choice.key
	-- Titel zegt meteen wiens bank (of tassen) je ziet.
	local title = me and T("Your bank") or (choice.part == "bank" and T("Bank of %s") or T("Bags of %s")):format(who)
	viewer:SetHeaderText(title)
	viewer.title = title
	local portH = UpdatePortraits()
	-- Tassen/Bank: gekozen = gouden tekst met gouden streep eronder, de andere grijs.
	for _, part in ipairs({ "bags", "bank" }) do
		local b = viewer.tabs[part]
		local n = Hits(choice.key, part)
		local icon = part == "bank" and "|TInterface\\Minimap\\Tracking\\Banker:16:16:0:0|t " or "|TInterface\\Icons\\INV_Misc_Bag_08:16:16:0:0:64:64:5:59:5:59|t "
		b:SetText(icon .. (part == "bank" and T("Bank") or T("Bags")) .. (n > 0 and (" |cffffd100" .. n .. "|r") or ""))
		b:SetWidth(math.max(60, (b.label:GetStringWidth() or 40) + 20))
		local on = part == choice.part
		b.sel:SetShown(on)
		if on then b.label:SetTextColor(1, 0.82, 0) else b.label:SetTextColor(0.6, 0.6, 0.6) end
	end
	local ch = ns.DB.chars[choice.key]
	local s = ch and ch.snap
	local rows = s and s[choice.part]
	local stamp = s and s[choice.part .. "Time"]
	local note = ""
	if not (choice.key == ns.charKey and choice.part == "bank" and ns.bankOpen) and stamp and date then
		note = T("Updated %s"):format(date("%d-%m %H:%M", stamp))
	end
	-- vrije vakjes van wat je bekijkt
	local free, slots = s and s[choice.part .. "Free"], s and s[choice.part .. "Slots"]
	if free and slots and slots > 0 then
		local col = (free == 0 and "|cffff2020") or (free <= 3 and "|cffff9900") or "|cff33ff99"
		note = col .. T("Free slots: %s of %s"):format(free, slots) .. "|r" .. (note ~= "" and ("   " .. note) or "")
	end
	viewer.note:SetText(note)
	local cols = 8 -- vast: breed genoeg voor de knoppen bovenin
	local width = cols * (ns.TILE + GAP) - GAP
	local y = 0
	if not rows then
		local h = ViewHead(1)
		h:SetPoint("TOPLEFT", viewer.content, "TOPLEFT", 0, 0)
		h:SetWidth(width)
		h:SetText("|cffaaaaaa" .. (choice.part == "bank" and T("Visit a banker once to see this bank here.")
			or T("Log in with this character once to see its bags here.")) .. "|r")
		y = 40
	else
		-- Indelen met de groepen van dat karakter.
		local bySec, order, titles = {}, {}, {}
		local ok, err = pcall(function()
			ns.viewKey = choice.key
			for _, r in ipairs(rows) do
				local e = { itemID = r.id, quality = r.q or 1, bound = r.b, quest = r.qu, bindType = r.bt or 0,
					classID = r.c, subclassID = r.s, equipLoc = r.e, key = r.k }
				local sec = SectionOf(e)
				if sec ~= "hidden" then
					bySec[sec] = bySec[sec] or {}
					table.insert(bySec[sec], r)
				end
			end
			for _, sec in ipairs(SectionList()) do order[#order + 1] = sec.key; titles[sec.key] = sec.title end
		end)
		ns.viewKey = nil
		if not ok then Log("viewer: " .. tostring(err)) end
		if not titles.other then order[#order + 1] = "other"; titles.other = T("Other") end
		local nt, nh = 0, 0
		for _, key in ipairs(order) do
			local list = bySec[key]
			if list and #list > 0 then
				table.sort(list, function(a, b)
					if (a.q or 1) ~= (b.q or 1) then return (a.q or 1) > (b.q or 1) end
					return (a.l or "") < (b.l or "")
				end)
				nh = nh + 1
				local h = ViewHead(nh)
				h:SetPoint("TOPLEFT", viewer.content, "TOPLEFT", 0, -y)
				h:SetText(titles[key])
				y = y + 18
				for idx, r in ipairs(list) do
					nt = nt + 1
					local t = ViewTile(nt)
					local col = (idx - 1) % cols
					if idx > 1 and col == 0 then y = y + ns.TILE + GAP end
					t:SetPoint("TOPLEFT", viewer.content, "TOPLEFT", col * (ns.TILE + GAP), -y)
					t.link = r.l
					t.icon:SetTexture(r.i or (C_Item.GetItemIconByID and C_Item.GetItemIconByID(r.id)) or 134400)
					t.count:SetText((r.n or 1) > 1 and r.n or "")
					local q = r.q or 1
					if q >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
						local c = ITEM_QUALITY_COLORS[q]
						t.border:SetVertexColor(c.r, c.g, c.b, 0.9); t.border:Show()
					else
						t.border:Hide()
					end
					-- zoekbalk van je tassen telt hier ook
					local match = ns.searchText == "" or ((r.l or ""):lower():match("%[(.-)%]") or ""):find(ns.searchText, 1, true)
					t.icon:SetDesaturated(not match)
					t:SetAlpha(match and 1 or 0.35)
				end
				y = y + ns.TILE + GAP + 6
			end
		end
		if nt == 0 then
			local h = ViewHead(nh + 1)
			h:SetPoint("TOPLEFT", viewer.content, "TOPLEFT", 0, -y)
			h:SetText("|cffaaaaaa" .. T("Empty") .. "|r")
			y = y + 20
		end
	end
	-- Onderaan: goud van het gekozen karakter en van al je karakters samen.
	local total, mine = 0, CharMoney(choice.key)
	for _, c in ipairs(ViewChars()) do total = total + (CharMoney(c.key) or 0) end
	-- Twee regels, zodat lange namen of veel goud niet over de rand lopen.
	local goldText = "|cffffd100" .. T("All characters: %s"):format("|r" .. Money(total))
	if mine and not me then goldText = "|cffffd100" .. who .. ":|r " .. Money(mine) .. "\n" .. goldText
	elseif mine then goldText = "|cffffd100" .. T("You: %s"):format("|r" .. Money(mine)) .. "\n" .. goldText end
	viewer.gold:SetText(goldText)
	viewer.goldText = goldText -- voor de tests
	local GOLD_H = 34
	local maxH = math.max(200, (UIParent:GetHeight() or 800) - 200 - GOLD_H)
	local h = math.min(y, maxH)
	viewer.content:SetSize(width, math.max(y, 1))
	viewer.scroll:SetSize(width, math.max(h, 40))
	viewer.scrollMax = math.max(0, y - h)
	viewer:SetSize(width + ns.PAD * 2 + PORT_W, math.max(math.max(h, 40) + 76 + ns.PAD + GOLD_H, portH + ns.PAD + GOLD_H))
end

local function BuildViewer()
	viewer = NewWindow("CarefreeBagViewer", T("Bank & alts"), 300, 200)
	viewer:SetMovable(false)
	viewer:SetScript("OnDragStart", nil)
	-- Links de karakterportretten; bovenin Tassen of Bank (alleen bij andere karakters).
	local left = ns.PAD + PORT_W
	viewer.tabs = {}
	local prev
	for _, part in ipairs({ "bags", "bank" }) do
		local b = CreateFrame("Button", nil, viewer)
		b:SetSize(60, 22)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0)
		else b:SetPoint("TOPLEFT", viewer, "TOPLEFT", left, -30) end
		prev = b
		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		b.label:SetPoint("CENTER", b, "CENTER", 0, 1)
		-- gekozen: zachte gloed zoals een gekozen regel in het questlog
		b.sel = b:CreateTexture(nil, "BACKGROUND")
		b.sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		b.sel:SetBlendMode("ADD")
		b.sel:SetVertexColor(1, 0.82, 0.3, 0.8)
		b.sel:SetAllPoints(b)
		b.sel:Hide()
		b:SetScript("OnEnter", function(self) if not self.sel:IsShown() then self.label:SetTextColor(1, 1, 1) end end)
		b:SetScript("OnLeave", function(self) if not self.sel:IsShown() then self.label:SetTextColor(0.6, 0.6, 0.6) end end)
		b.SetText = function(self, s) self.text = s; self.label:SetText(s) end
		b:SetText(part == "bank" and T("Bank") or T("Bags"))
		b:SetScript("OnClick", function()
			if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
			viewer.part = part; viewer.scroll:SetVerticalScroll(0); ViewLayout()
		end)
		viewer.tabs[part] = b
	end
	viewer.note = viewer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	viewer.note:SetPoint("TOPLEFT", viewer, "TOPLEFT", left + 2, -56)
	viewer.gold = viewer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	viewer.gold:SetPoint("BOTTOMLEFT", viewer, "BOTTOMLEFT", ns.PAD + 4, ns.PAD + 2)
	viewer.gold:SetJustifyH("LEFT")
	viewer.scroll = CreateFrame("ScrollFrame", nil, viewer)
	viewer.scroll:SetPoint("TOPLEFT", viewer, "TOPLEFT", left, -76)
	viewer.content = CreateFrame("Frame", nil, viewer.scroll)
	viewer.scroll:SetScrollChild(viewer.content)
	viewer.scroll:EnableMouseWheel(true)
	viewer.scroll:SetScript("OnMouseWheel", function(self, delta)
		local v = (self:GetVerticalScroll() or 0) - delta * (ns.TILE + GAP)
		self:SetVerticalScroll(math.max(0, math.min(viewer.scrollMax or 0, v)))
	end)
	viewer:SetScript("OnShow", ViewLayout)
	viewer:SetScript("OnHide", function()
		viewer.autoOpened = nil
		-- zelf dichtgedaan tijdens het zoeken: niet meteen weer openen
		if ns.searchText ~= "" then viewer.noAuto = true end
	end)
	-- Vast naast je tassen (links of rechts, pijltje wisselt), en dicht als je tassen dichtgaan.
	ns.AddSideArrow(viewer)
	ns.DockPanel(viewer)
	ns.main:HookScript("OnHide", function() viewer:Hide(); viewer.noAuto = nil end)
end

ns.ViewRefresh = function() if viewer and viewer:IsShown() then ViewLayout() end end

local function OpenViewer(key, part)
	if not viewer then BuildViewer() end
	-- Opties en bankpaneel zitten op dezelfde plek: één tegelijk.
	if ns.HideConfig then ns.HideConfig() end
	viewer.key, viewer.part = key, part
	ns.DockPanel(viewer) -- kant kan per karakter verschillen
	if viewer:IsShown() then ViewLayout() else viewer:Show() end
end

ns.ToggleViewer = function()
	if viewer and viewer:IsShown() then viewer:Hide(); return end
	OpenViewer(FirstHit())
end

ns.HideViewer = function() if viewer then viewer:Hide() end end

-- Getal en gloed op de knop Bank & alts: hits buiten je eigen tassen.
local function UpdateBadge()
	local btn = ns.main and ns.main.bankBtn
	if not btn then return end
	if not btn.hits then
		btn.hits = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		btn.hits:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 4, -3)
		btn.hits:SetTextColor(1, 0.82, 0)
		btn.glow = btn:CreateTexture(nil, "OVERLAY", nil, 6)
		btn.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		btn.glow:SetBlendMode("ADD")
		btn.glow:SetVertexColor(1, 0.82, 0)
		btn.glow:SetSize(btn:GetWidth() * 1.9, btn:GetHeight() * 1.9)
		btn.glow:SetPoint("CENTER")
		btn.glow:Hide()
	end
	local n = OtherHits()
	btn.hits:SetText(n > 0 and n or "")
	btn.glow:SetShown(n > 0)
end

-- Zoektekst veranderd (vanuit de zoekbalk van je tassen).
ns.OnSearch = function()
	UpdateBadge()
	if ns.searchText == "" then
		if viewer then
			viewer.noAuto = nil
			if viewer.autoOpened then viewer:Hide() end
		end
		ns.ViewRefresh()
		return
	end
	local key, part = FirstHit()
	if not key then ns.ViewRefresh(); return end
	if not viewer or not viewer:IsShown() then
		if viewer and viewer.noAuto then return end
		OpenViewer(key, part)
		viewer.autoOpened = true
	elseif Hits(viewer.key, viewer.part) == 0 then
		-- hier niets gevonden: spring naar waar het wel zit
		viewer.key, viewer.part = key, part
		viewer.scroll:SetVerticalScroll(0)
		ViewLayout()
	else
		ViewLayout()
	end
end

---------------------------------------------------------------------------
-- Events: bank open/dicht
---------------------------------------------------------------------------

ns.OnEvent("BANKFRAME_OPENED", "bank", function()
	ns.bankOpen = true
	ns.SnapBank()
	if ns.ViewRefresh then ns.ViewRefresh() end
end)
-- Bij het sluiten niet meer uitlezen: dan is de bank al (deels) leeg.
ns.OnEvent("BANKFRAME_CLOSED", "bank", function() ns.bankOpen = false end)
local function BankChanged()
	if not ns.bankOpen then return end
	ns.SnapBank()
	if ns.ViewRefresh then ns.ViewRefresh() end
end
ns.OnEvent("PLAYERBANKSLOTS_CHANGED", "bank", BankChanged)
ns.OnEvent("PLAYERBANKBAGSLOTS_CHANGED", "bank", BankChanged)
