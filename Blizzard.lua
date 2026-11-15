-- CarefreeBag: Blizzard.lua
-- Koppeling met WoW: tassen openen/vervangen, aan/uit, andere tassen-addons herkennen.
-- Alle bestanden delen één omgeving (zie Env.lua). De namen hieronder maakt dit bestand.
local _, ns = ...
setfenv(1, ns.Env(
	"lastToggle", "openedAt", "openedBy", "HideBlizzardBags", "OpenMain", "OnToggle", "OnOpenAll",
	"OnCloseAll", "BindKeys", "toggleBtn", "binding", "bindPending", "ToggleFromKey", "HookBags",
	"UpdateMinimapIcon", "RefreshConfig", "mailPanel", "AskReload", "reloadPrompt", "SetEnabled",
	"OTHER_BAGS", "IsLoaded", "CheckOtherBags"
))

---------------------------------------------------------------------------
-- Bewerkmenu per item
---------------------------------------------------------------------------

SetHidden = function(id, v) Hidden()[id] = v or nil; Log((v and "hidden: " or "visible: ") .. id); ResetOrder(); Refresh() end
---------------------------------------------------------------------------
-- Standaardtassen vervangen
---------------------------------------------------------------------------

lastToggle, openedAt, openedBy = -1, -1, nil

function HideBlizzardBags()
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then ContainerFrameCombinedBags:Hide() end
	for i = 1, (NUM_CONTAINER_FRAMES or 13) do
		local f = _G["ContainerFrame" .. i]
		if f and f:IsShown() then f:Hide() end
	end
end

-- Openen door de game (vendor, mailbox, backpack-knop). Als het venster nu door
-- een frame geopend wordt, onthouden we welk frame: dat mag het ook weer sluiten.
function OpenMain(frame)
	local t = GetTime()
	if not main:IsShown() then
		openedAt = t
		openedBy = nil
		ShowMain()
	end
	if frame and frame.GetName and openedAt == t then openedBy = frame:GetName() end
end

function OnToggle()
	if not DB.enabled then return end
	HideBlizzardBags()
	local t = GetTime()
	-- Eén toetsdruk kan meerdere Blizzard-functies aanroepen: maar één keer wisselen.
	if t == openedAt or t == lastToggle then return end
	lastToggle = t
	if main:IsShown() then
		main:Hide()
	else
		openedAt = t
		openedBy = nil
		ShowMain()
	end
end

function OnOpenAll(frame)
	if not DB.enabled then return end
	HideBlizzardBags()
	OpenMain(frame)
end

function OnCloseAll(frame)
	if not DB.enabled then return end
	HideBlizzardBags()
	local name = frame and frame.GetName and frame:GetName()
	if not frame or (openedBy and name == openedBy) then
		openedBy = nil
		main:Hide()
	end
end

-- De tas-toetsen van de speler (alle tassen, rugzak, losse tassen) direct aan CarefreeBag koppelen. Zo hoeft de toets
-- niet via Blizzards eigen tasfuncties, en is het altijd: open <-> dicht.
-- hieronder ingevuld (BindKeys)
toggleBtn, binding, bindPending = nil, false, false

function ToggleFromKey()
	local t = GetTime()
	lastToggle = t
	if main:IsShown() then
		main:Hide()
	else
		openedAt = t
		openedBy = nil
		HideBlizzardBags()
		ShowMain()
	end
end

BindKeys = function()
	if not toggleBtn then return end
	if InCombatLockdown() then bindPending = true; return end
	binding = true
	ClearOverrideBindings(toggleBtn)
	local keys = {}
	if DB.enabled then
		-- Elke toets waarmee jij je tassen opent: alles, rugzak of een losse tas.
		for _, action in ipairs({ "OPENALLBAGS", "TOGGLEBACKPACK", "TOGGLEBAG1", "TOGGLEBAG2", "TOGGLEBAG3", "TOGGLEBAG4" }) do
			for _, k in ipairs({ GetBindingKey(action) }) do
				SetOverrideBindingClick(toggleBtn, true, k, "CarefreeBagToggleButton")
				keys[#keys + 1] = k
			end
		end
	end
	binding = false
	local list = table.concat(keys, ", ")
	if list ~= DB.lastKeys then
		DB.lastKeys = list
		Log("keys for CarefreeBag: " .. (list ~= "" and list or "none"))
	end
end

function HookBags()
	toggleBtn = CreateFrame("Button", "CarefreeBagToggleButton", UIParent)
	toggleBtn:SetScript("OnClick", ToggleFromKey)
	BindKeys()
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

-- vooruit (UpdateMinimapIcon, RefreshConfig, mailPanel)

-- Herladen mag een addon in Forever niet zelf (ReloadUI wordt geblokkeerd).
-- Daarom een los venstertje met een beveiligde knop die de macro /reload uitvoert.
AskReload = function()
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

function SetEnabled(v)
	DB.enabled = v and true or false
	Log("CarefreeBag " .. (DB.enabled and "on" or "off"))
	if BindKeys then BindKeys() end
	if not DB.enabled then
		if main then main:Hide() end
		if mailPanel then mailPanel:Hide() end
		Print(T("CarefreeBag is off. Your normal bags are back."))
	else
		Print(T("CarefreeBag is on."))
	end
	if UpdateMinimapIcon then UpdateMinimapIcon() end
	if RefreshConfig then RefreshConfig() end
end

---------------------------------------------------------------------------
-- Andere tassen-addons herkennen
---------------------------------------------------------------------------

OTHER_BAGS = { "Baganator", "Bagnon", "AdiBags", "ArkInventory", "BetterBags", "Combuctor", "GudaBags",
	"OneBag3", "Inventorian", "LiteBag", "BagDaddy", "BazBags", "Bagforge", "HardcoreBags", "BlockBags", "MyBags", "Sorted" }

function IsLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
		return ok and loaded
	end
	return IsAddOnLoaded and IsAddOnLoaded(name)
end

function CheckOtherBags()
	if not DB.enabled or not StaticPopupDialogs or not StaticPopup_Show then return end
	for _, name in ipairs(OTHER_BAGS) do
		if IsLoaded(name) and not DB.conflictOK[name] then
			Log("other bag addon found: " .. name)
			StaticPopupDialogs["CAREFREEBAG_CONFLICT"] = {
				text = T("CarefreeBag and %s both want to replace your bags. Which one do you want to use?"),
				button1 = "CarefreeBag",
				button2 = name,
				OnAccept = function()
					DB.conflictOK[name] = true
					Log("conflict: user chose CarefreeBag, disabling " .. name)
					if C_AddOns and C_AddOns.DisableAddOn then pcall(C_AddOns.DisableAddOn, name)
					elseif DisableAddOn then pcall(DisableAddOn, name) end
					ReloadUI()
				end,
				OnCancel = function(_, _, reason)
					if reason ~= "clicked" then return end
					DB.conflictOK[name] = true
					Log("conflict: user chose " .. name .. ", CarefreeBag turned off")
					SetEnabled(false)
					Print(T("%s keeps your bags. CarefreeBag is turned off; turn it on again with the minimap button."):format(name))
				end,
				timeout = 0, whileDead = true, hideOnEscape = false,
			}
			StaticPopup_Show("CAREFREEBAG_CONFLICT", name)
			return
		end
	end
end
