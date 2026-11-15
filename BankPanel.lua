-- CarefreeBag: BankPanel.lua
-- Paneel naast je tassen: bank en de tassen/bank van je andere karakters (alleen bekijken).
-- Alle bestanden delen één omgeving (zie Env.lua). De namen hieronder maakt dit bestand.
local _, ns = ...
setfenv(1, ns.Env(
	"viewer", "viewTiles", "viewHeads", "ViewChars", "ViewTile", "ViewHead", "ViewLayout",
	"OpenViewMenu", "BuildViewer"
))

---------------------------------------------------------------------------
-- Paneel naast je tassen: je bank, en de tassen en bank van je andere karakters
-- (alleen bekijken; verplaatsen doe je bij de bankier zoals altijd)
---------------------------------------------------------------------------

viewTiles, viewHeads = {}, {}

-- Karakters om uit te kiezen: jijzelf eerst, daarna de rest op naam.
function ViewChars()
	local list = {}
	for key, ch in pairs(DB.chars or {}) do
		if not ch.legacy and (key == charKey or ch.snap) then
			list[#list + 1] = { key = key, name = (ch.snap and ch.snap.name) or MyFullName() or key }
		end
	end
	table.sort(list, function(a, b)
		if (a.key == charKey) ~= (b.key == charKey) then return a.key == charKey end
		return a.name < b.name
	end)
	return list
end

function ViewTile(i)
	local t = viewTiles[i]
	if not t then
		t = CreateFrame("Button", nil, viewer.content)
		t:SetSize(TILE, TILE)
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
		t.border:SetSize(TILE * 1.8, TILE * 1.8)
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

function ViewHead(i)
	local h = viewHeads[i]
	if not h then
		h = viewer.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h:SetJustifyH("LEFT")
		viewHeads[i] = h
	end
	h:Show()
	return h
end

function ViewLayout()
	if not viewer or not viewer:IsShown() then return end
	for _, t in ipairs(viewTiles) do t:Hide() end
	for _, h in ipairs(viewHeads) do h:Hide() end
	-- Standaard: de bank van het karakter waarmee je speelt.
	viewer.key = viewer.key or charKey
	viewer.part = viewer.part or "bank"
	-- Je eigen tassen staan al rechts open: bij jezelf alleen de bank.
	if viewer.key == charKey then viewer.part = "bank" end
	viewer.tabs.bags:SetShown(viewer.key ~= charKey)
	viewer.tabs.bank:SetShown(viewer.key ~= charKey)
	local choice = { key = viewer.key, part = viewer.part }
	local ch0 = DB.chars[choice.key]
	local who = (ch0 and ch0.snap and ch0.snap.name) or (choice.key == charKey and MyFullName()) or choice.key
	viewer.pick:SetText(who .. "  |TInterface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up:14:14|t")
	for part, b in pairs(viewer.tabs) do
		if part == choice.part then b:LockHighlight() else b:UnlockHighlight() end
	end
	local ch = DB.chars[choice.key]
	local s = ch and ch.snap
	local rows = s and s[choice.part]
	local stamp = s and s[choice.part .. "Time"]
	if choice.key == charKey and choice.part == "bank" and bankOpen then
		viewer.note:SetText("")
	elseif stamp and date then
		viewer.note:SetText(T("Updated %s"):format(date("%d-%m %H:%M", stamp)))
	else
		viewer.note:SetText("")
	end
	local cols = 8 -- vast: breed genoeg voor de knoppen bovenin
	local width = cols * (TILE + GAP) - GAP
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
			viewKey = choice.key
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
		viewKey = nil
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
					if idx > 1 and col == 0 then y = y + TILE + GAP end
					t:SetPoint("TOPLEFT", viewer.content, "TOPLEFT", col * (TILE + GAP), -y)
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
					local match = searchText == "" or ((r.l or ""):lower():match("%[(.-)%]") or ""):find(searchText, 1, true)
					t.icon:SetDesaturated(not match)
					t:SetAlpha(match and 1 or 0.35)
				end
				y = y + TILE + GAP + 6
			end
		end
		if nt == 0 then
			local h = ViewHead(nh + 1)
			h:SetPoint("TOPLEFT", viewer.content, "TOPLEFT", 0, -y)
			h:SetText("|cffaaaaaa" .. T("Empty") .. "|r")
			y = y + 20
		end
	end
	local maxH = math.max(200, (UIParent:GetHeight() or 800) - 200)
	local h = math.min(y, maxH)
	viewer.content:SetSize(width, math.max(y, 1))
	viewer.scroll:SetSize(width, math.max(h, 40))
	viewer.scrollMax = math.max(0, y - h)
	viewer:SetSize(width + PAD * 2, math.max(h, 40) + 76 + PAD)
end

function OpenViewMenu()
	local list = ViewChars()
	local m = viewer.menu
	if not m then
		m = NewMenu("CarefreeBagViewMenu")
		m.buttons = {}
		viewer.menu = m
	end
	for _, b in ipairs(m.buttons) do b:Hide() end
	for i, c in ipairs(list) do
		local b = m.buttons[i]
		if not b then
			b = MakeButton(m, "", 180)
			m.buttons[i] = b
		end
		b:SetPoint("TOP", m, "TOP", 0, -4 - (i - 1) * 22)
		b:SetText(c.name)
		b:SetScript("OnClick", function()
			viewer.key = c.key
			m:Hide()
			viewer.scroll:SetVerticalScroll(0)
			ViewLayout()
		end)
		b:Show()
	end
	m:SetSize(190, #list * 22 + 8)
	m:ClearAllPoints()
	m:SetPoint("TOPLEFT", viewer.pick, "BOTTOMLEFT", 0, -2)
	ShowMenu(m)
end

function BuildViewer()
	viewer = NewWindow("CarefreeBagViewer", T("Bank & alts"), 300, 200)
	viewer:SetMovable(false)
	viewer:SetScript("OnDragStart", nil)
	-- Bovenin: welk karakter (keuzelijst) en Tassen of Bank.
	viewer.pick = MakeButton(viewer, "", 170)
	viewer.pick:SetPoint("TOPLEFT", viewer, "TOPLEFT", PAD, -32)
	viewer.pick:SetScript("OnClick", OpenViewMenu)
	viewer.tabs = {}
	local prev = viewer.pick
	for _, part in ipairs({ "bags", "bank" }) do
		local b = MakeButton(viewer, part == "bank" and T("Bank") or T("Bags"), 64)
		b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
		b:SetScript("OnClick", function() viewer.part = part; viewer.scroll:SetVerticalScroll(0); ViewLayout() end)
		viewer.tabs[part] = b
		prev = b
	end
	viewer.note = viewer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	viewer.note:SetPoint("TOPLEFT", viewer.pick, "BOTTOMLEFT", 2, -4)
	viewer.scroll = CreateFrame("ScrollFrame", nil, viewer)
	viewer.scroll:SetPoint("TOPLEFT", viewer, "TOPLEFT", PAD, -76)
	viewer.content = CreateFrame("Frame", nil, viewer.scroll)
	viewer.scroll:SetScrollChild(viewer.content)
	viewer.scroll:EnableMouseWheel(true)
	viewer.scroll:SetScript("OnMouseWheel", function(self, delta)
		local v = (self:GetVerticalScroll() or 0) - delta * (TILE + GAP)
		self:SetVerticalScroll(math.max(0, math.min(viewer.scrollMax or 0, v)))
	end)
	viewer:SetScript("OnShow", ViewLayout)
	viewer:SetScript("OnHide", function() if viewer.menu then viewer.menu:Hide() end end)
	-- Vast naast je tassen (links ervan), en dicht als je tassen dichtgaan.
	viewer:ClearAllPoints()
	viewer:SetPoint("TOPRIGHT", main, "TOPLEFT", -4, 0)
	main:HookScript("OnHide", function() viewer:Hide() end)
end

ViewRefresh = function() if viewer and viewer:IsShown() then ViewLayout() end end

ToggleViewer = function()
	if not viewer then BuildViewer() end
	if viewer:IsShown() then viewer:Hide() else viewer.key, viewer.part = nil, nil; viewer:Show() end
end
