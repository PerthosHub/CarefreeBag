-- CarefreeBag: Blizzard.lua
-- Koppeling met WoW: tassen openen/vervangen, aan/uit, andere tassen-addons herkennen.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Hidden, Log, Print, ResetOrder, ShowMain, T = ns.Hidden, ns.Log, ns.Print, ns.ResetOrder, ns.ShowMain, ns.T

---------------------------------------------------------------------------
-- Bewerkmenu per item
---------------------------------------------------------------------------

ns.SetHidden = function(id, v) Hidden()[id] = v or nil; Log((v and "hidden: " or "visible: ") .. id); ResetOrder(); ns.Refresh() end
---------------------------------------------------------------------------
-- Standaardtassen vervangen
---------------------------------------------------------------------------

local lastToggle, openedAt, openedBy = -1, -1, nil

local function HideBlizzardBags()
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then ContainerFrameCombinedBags:Hide() end
	for i = 1, (NUM_CONTAINER_FRAMES or 13) do
		local f = _G["ContainerFrame" .. i]
		if f and f:IsShown() then f:Hide() end
	end
end

-- Openen door de game (vendor, mailbox, backpack-knop). Als het venster nu door
-- een frame geopend wordt, onthouden we welk frame: dat mag het ook weer sluiten.
local function OpenMain(frame)
	local t = GetTime()
	if not ns.main:IsShown() then
		openedAt = t
		openedBy = nil
		ShowMain()
	end
	if frame and frame.GetName and openedAt == t then openedBy = frame:GetName() end
end

local function OnToggle()
	if not ns.DB.enabled then return end
	HideBlizzardBags()
	local t = GetTime()
	-- Eén toetsdruk kan meerdere Blizzard-functies aanroepen: maar één keer wisselen.
	if t == openedAt or t == lastToggle then return end
	lastToggle = t
	if ns.main:IsShown() then
		ns.main:Hide()
	else
		openedAt = t
		openedBy = nil
		ShowMain()
	end
end

local function OnOpenAll(frame)
	if not ns.DB.enabled then return end
	HideBlizzardBags()
	OpenMain(frame)
end

local function OnCloseAll(frame)
	if not ns.DB.enabled then return end
	HideBlizzardBags()
	local name = frame and frame.GetName and frame:GetName()
	if not frame or (openedBy and name == openedBy) then
		openedBy = nil
		ns.main:Hide()
	end
end

-- De tas-toetsen van de speler (alle tassen, rugzak, losse tassen) direct aan CarefreeBag koppelen. Zo hoeft de toets
-- niet via Blizzards eigen tasfuncties, en is het altijd: open <-> dicht.
local toggleBtn;  toggleBtn, ns.binding, ns.bindPending = nil, false, false

local function ToggleFromKey()
	local t = GetTime()
	lastToggle = t
	if ns.main:IsShown() then
		ns.main:Hide()
	else
		openedAt = t
		openedBy = nil
		HideBlizzardBags()
		ShowMain()
	end
end

ns.BindKeys = function()
	if not toggleBtn then return end
	if InCombatLockdown() then ns.bindPending = true; return end
	ns.binding = true
	ClearOverrideBindings(toggleBtn)
	local keys = {}
	if ns.DB.enabled then
		-- Elke toets waarmee jij je tassen opent: alles, rugzak of een losse tas.
		for _, action in ipairs({ "OPENALLBAGS", "TOGGLEBACKPACK", "TOGGLEBAG1", "TOGGLEBAG2", "TOGGLEBAG3", "TOGGLEBAG4" }) do
			for _, k in ipairs({ GetBindingKey(action) }) do
				SetOverrideBindingClick(toggleBtn, true, k, "CarefreeBagToggleButton")
				keys[#keys + 1] = k
			end
		end
	end
	ns.binding = false
	local list = table.concat(keys, ", ")
	if list ~= ns.DB.lastKeys then
		ns.DB.lastKeys = list
		Log("keys for CarefreeBag: " .. (list ~= "" and list or "none"))
	end
end

function ns.HookBags()
	toggleBtn = CreateFrame("Button", "CarefreeBagToggleButton", UIParent)
	toggleBtn:SetScript("OnClick", ToggleFromKey)
	ns.BindKeys()
	if ToggleAllBags then hooksecurefunc("ToggleAllBags", OnToggle) end
	if ToggleBackpack then hooksecurefunc("ToggleBackpack", OnToggle) end
	if ToggleBag then hooksecurefunc("ToggleBag", OnToggle) end -- klik op een tas onderin beeld
	if OpenAllBags then hooksecurefunc("OpenAllBags", OnOpenAll) end
	if OpenBackpack then hooksecurefunc("OpenBackpack", function() OnOpenAll(nil) end) end
	if CloseAllBags then hooksecurefunc("CloseAllBags", OnCloseAll) end
end

---------------------------------------------------------------------------
-- CarefreeBag aan/uit (minimapknop en bovenaan de opties)
---------------------------------------------------------------------------


-- Herladen mag een addon in Forever niet zelf (ReloadUI wordt geblokkeerd).
-- Daarom een los venstertje met een beveiligde knop die de macro /reload uitvoert.
local reloadPrompt
ns.AskReload = function()
	if InCombatLockdown() then Print(T("Type /reload to switch language.")); return end
	if not reloadPrompt then
		local f = CreateFrame("Frame", "CarefreeBagReloadPrompt", UIParent, "BackdropTemplate")
		f:SetSize(280, 96)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
		f:SetFrameStrata("DIALOG")
		if f.SetBackdrop then
			f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24,
				insets = { left = 6, right = 6, top = 6, bottom = 6 } })
		end
		f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		f.text:SetPoint("TOP", f, "TOP", 0, -18)
		f.text:SetWidth(250)
		local ok, rb = pcall(CreateFrame, "Button", "CarefreeBagReloadButton", f, "SecureActionButtonTemplate, UIPanelButtonTemplate")
		if not ok then rb = CreateFrame("Button", "CarefreeBagReloadButton", f, "UIPanelButtonTemplate") end
		rb:SetSize(110, 22)
		rb:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 16)
		rb:RegisterForClicks("AnyUp", "AnyDown")
		rb:SetAttribute("type", "macro")
		rb:SetAttribute("macrotext", "/reload")
		f.reload = rb
		local later = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
		later:SetSize(110, 22)
		later:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 16)
		later:SetScript("OnClick", function() f:Hide() end)
		f.later = later
		f:Hide()
		reloadPrompt = f
	end
	reloadPrompt.text:SetText(T("Reload the interface to switch language."))
	reloadPrompt.reload:SetText(T("Reload"))
	reloadPrompt.later:SetText(T("Later"))
	reloadPrompt:Show()
end

function ns.SetEnabled(v)
	ns.DB.enabled = v and true or false
	Log("CarefreeBag " .. (ns.DB.enabled and "on" or "off"))
	if ns.BindKeys then ns.BindKeys() end
	if not ns.DB.enabled then
		if ns.main then ns.main:Hide() end
		if ns.mailPanel then ns.mailPanel:Hide() end
		Print(T("CarefreeBag is off. Your normal bags are back."))
	else
		Print(T("CarefreeBag is on."))
	end
	if ns.UpdateMinimapIcon then ns.UpdateMinimapIcon() end
	if ns.UpdateBagSlots then ns.UpdateBagSlots() end -- CFB uit = de normale tassenbalk terug (BlizzBagBar.lua)
	if ns.RefreshConfig then ns.RefreshConfig() end
	-- weer aan: quest-items die je lootte terwijl CFB uit stond, krijgen nu alsnog hun venster
	-- (Ready, niet Check: stond CFB al uit bij het inloggen, dan was het venster nog niet klaar)
	if ns.DB.enabled and ns.QuestStartReady then pcall(ns.QuestStartReady) end
end

---------------------------------------------------------------------------
-- Andere tassen-addons herkennen
---------------------------------------------------------------------------

local OTHER_BAGS = { "Baganator", "Bagnon", "AdiBags", "ArkInventory", "BetterBags", "Combuctor", "GudaBags",
	"OneBag3", "Inventorian", "LiteBag", "BagDaddy", "BazBags", "Bagforge", "HardcoreBags", "BlockBags", "MyBags", "Sorted" }

local function IsLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
		return ok and loaded
	end
	return IsAddOnLoaded and IsAddOnLoaded(name)
end

-- Hoeveel andere tassen-addons staan aan (voor de gebruiksstatistieken, Stats.lua)?
function ns.OtherBagsLoaded()
	local n = 0
	for _, name in ipairs(OTHER_BAGS) do if IsLoaded(name) then n = n + 1 end end
	return n
end

function ns.CheckOtherBags()
	if not ns.DB.enabled or not StaticPopupDialogs or not StaticPopup_Show then return end
	for _, name in ipairs(OTHER_BAGS) do
		if IsLoaded(name) and not ns.DB.conflictOK[name] then
			Log("other bag addon found: " .. name)
			StaticPopupDialogs["CAREFREEBAG_CONFLICT"] = {
				text = T("CarefreeBag and %s both want to replace your bags. Which one do you want to use?"),
				button1 = "CarefreeBag",
				button2 = name,
				OnAccept = function()
					ns.DB.conflictOK[name] = true
					Log("conflict: user chose CarefreeBag, disabling " .. name)
					if C_AddOns and C_AddOns.DisableAddOn then pcall(C_AddOns.DisableAddOn, name)
					elseif DisableAddOn then pcall(DisableAddOn, name) end
					ReloadUI()
				end,
				OnCancel = function(_, _, reason)
					if reason ~= "clicked" then return end
					ns.DB.conflictOK[name] = true
					Log("conflict: user chose " .. name .. ", CarefreeBag turned off")
					ns.SetEnabled(false)
					Print(T("%s keeps your bags. CarefreeBag is turned off; turn it on again with the minimap button."):format(name))
				end,
				timeout = 0, whileDead = true, hideOnEscape = false,
			}
			StaticPopup_Show("CAREFREEBAG_CONFLICT", name)
			return
		end
	end
end

---------------------------------------------------------------------------
-- Events: toetsen (B, Shift-B, ...) opnieuw aan CarefreeBag koppelen
---------------------------------------------------------------------------

ns.OnEvent("UPDATE_BINDINGS", "keys", function()
	if not ns.binding then C_Timer.After(0.1, ns.BindKeys) end
end)
ns.OnEvent("PLAYER_REGEN_ENABLED", "keys", function()
	if ns.bindPending then ns.bindPending = false; ns.BindKeys() end
end)
