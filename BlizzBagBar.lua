-- CarefreeBag: BlizzBagBar.lua
-- De tassenbalk van WoW zelf (issue #4, deel B):
--  * vulbalk óp de echte rugzakknop: van onder naar boven, groen -> rood (alleen gewone vakjes;
--    reagent-tas en beroepstassen tellen niet mee). Optie DB.bagFill, standaard aan.
--  * de andere tasvakjes verbergen (per karakter: ch.hideBagSlots). Retail/Forever: WoW's eigen
--    inklap-pijltje (CVar expandBagBar). Classic: de vakjes zelf verbergen.
--  * sleep je een tas, dan komen de vakjes even terug.
--  * eenmalige vraag per karakter, alleen als je je UI al hebt aangepast (eigen Edit Mode-layout
--    of een balk-addon). Standaard-UI = niet vragen (anders ontstaat er een gat). Al ingeklapt = niet vragen.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local Log, T = ns.Log, ns.T

local NUM_BAGS = NUM_BAG_SLOTS or 4 -- gewone tasvakken 1 t/m 4 (0 = rugzak); reagent-tas = 5 telt niet mee
local BAR_ADDONS = { "Bartender4", "Dominos", "ElvUI", "Tukui", "NDui", "RealUI", "SpartanUI", "LUI", "KkthnxUI", "GW2_UI" }

local fill          -- de vulbalk op de rugzakknop
local slotsHidden = false -- nu verborgen door ons
local peeking = false -- vakjes even zichtbaar omdat je een tas sleept
local pending = nil -- in gevecht gevraagd: na het gevecht toepassen (true/false)

---------------------------------------------------------------------------
-- Hulpjes
---------------------------------------------------------------------------

local function GetCV(name)
	local get = (C_CVar and C_CVar.GetCVar) or GetCVar
	if not get then return nil end
	local ok, v = pcall(get, name)
	return ok and v or nil
end

local function SetCV(name, v)
	local set = (C_CVar and C_CVar.SetCVar) or SetCVar
	if set then pcall(set, name, v) end
end

local function IsLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
		return ok and loaded
	end
	return IsAddOnLoaded and IsAddOnLoaded(name)
end

-- Retail/Forever heeft een inklap-pijltje naast de rugzak (CVar expandBagBar).
local function HasCollapse() return GetCV("expandBagBar") ~= nil end

local function ClassicSlots()
	local list = {}
	for i = 0, NUM_BAGS - 1 do
		local f = _G["CharacterBag" .. i .. "Slot"]
		if f then list[#list + 1] = f end
	end
	return list
end

local function WantHidden()
	local ch = ns.CharEntry()
	return ch and ch.hideBagSlots == true
end

---------------------------------------------------------------------------
-- Vulbalk op de rugzak
---------------------------------------------------------------------------

-- Vrije en totale vakjes in gewone tassen (rugzak + 4 tasvakken, zonder beroepstassen).
local function Count()
	local free, total = 0, 0
	local numSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
	local numFree = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
	if not numSlots or not numFree then return 0, 0 end
	for bag = 0, NUM_BAGS do
		local okN, n = pcall(numSlots, bag)
		n = okN and n or 0
		if n > 0 then
			local ok, f, family = pcall(numFree, bag)
			if ok and (family or 0) == 0 then
				total = total + n
				free = free + (f or 0)
			end
		end
	end
	return free, total
end

local function BuildFill()
	local btn = MainMenuBarBackpackButton
	if fill or not btn then return fill end
	local icon = btn.icon or _G["MainMenuBarBackpackButtonIconTexture"] or btn
	local bar = CreateFrame("StatusBar", "CarefreeBagBackpackFill", btn)
	bar:SetPoint("TOPLEFT", icon, "TOPLEFT", 3, -3)
	bar:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -3, 3)
	bar:SetOrientation("VERTICAL")
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar:SetAlpha(0.45)
	bar:EnableMouse(false) -- klikken en tooltip blijven van de rugzakknop
	if btn.GetFrameLevel and btn:GetFrameLevel() then bar:SetFrameLevel(btn:GetFrameLevel() + 1) end
	fill = bar
	return fill
end

function ns.UpdateBackpackFill()
	local bar = BuildFill()
	if not bar then return end
	if not ns.DB.bagFill then bar:Hide(); return end
	local free, total = Count()
	local frac = total > 0 and (total - free) / total or 0
	bar.frac, bar.free, bar.total = frac, free, total
	bar:SetValue(frac)
	bar:SetStatusBarColor(ns.FillColor(frac))
	bar:Show()
end

---------------------------------------------------------------------------
-- Andere tasvakjes verbergen
---------------------------------------------------------------------------

local classicHooked = false

local function SetSlotsHidden(hide)
	if InCombatLockdown() then pending = hide; return end
	pending = nil
	slotsHidden = hide
	if HasCollapse() then
		local want = hide and "0" or "1"
		if GetCV("expandBagBar") ~= want then
			-- Eerst WoW's eigen pijltje: precies wat er gebeurt als jij erop klikt.
			if BagBarExpandToggle and BagBarExpandToggle.Click then pcall(BagBarExpandToggle.Click, BagBarExpandToggle) end
			if GetCV("expandBagBar") ~= want then
				SetCV("expandBagBar", want)
				if BagBarExpandToggle and BagBarExpandToggle.UpdateOrientation then pcall(BagBarExpandToggle.UpdateOrientation, BagBarExpandToggle) end
				if BagsBar and BagsBar.Layout then pcall(BagsBar.Layout, BagsBar) end
			end
		end
		return
	end
	-- Classic: geen pijltje, dus de vakjes zelf (en weer verbergen als WoW ze toont).
	for _, f in ipairs(ClassicSlots()) do
		if not classicHooked and f.HookScript then
			f:HookScript("OnShow", function(self) if slotsHidden then self:Hide() end end)
		end
		f:SetShown(not hide)
	end
	classicHooked = true
end

-- Vanuit de opties (en de vraag): per karakter.
function ns.SetHideBagSlots(v)
	local ch = ns.CharEntry()
	if not ch then return end
	ch.hideBagSlots = v and true or false
	Log("hide other bag slots: " .. tostring(ch.hideBagSlots))
	peeking = false
	SetSlotsHidden(ch.hideBagSlots)
end

---------------------------------------------------------------------------
-- Tas slepen: vakjes even terug
---------------------------------------------------------------------------

local function CursorIsBag()
	if not GetCursorInfo then return false end
	local kind, id = GetCursorInfo()
	if kind ~= "item" or not id then return false end
	local ok, _, _, _, _, _, _, _, _, equip = pcall(C_Item.GetItemInfo, id)
	return ok and (equip == "INVTYPE_BAG" or equip == "INVTYPE_QUIVER") or false
end

local function OnCursor()
	if not WantHidden() then return end
	if CursorIsBag() then
		if not peeking then
			peeking = true
			SetSlotsHidden(false)
		end
	elseif peeking then
		-- even wachten: WoW (en BagSwap) handelen eerst het neerleggen af
		C_Timer.After(0.3, function()
			if peeking and not CursorIsBag() then
				peeking = false
				SetSlotsHidden(true)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Eenmalige vraag per karakter
---------------------------------------------------------------------------

local function AlreadyCollapsed()
	if HasCollapse() then return GetCV("expandBagBar") == "0" end
	local slots = ClassicSlots()
	return #slots > 0 and not slots[1]:IsShown()
end

-- Heb je je UI al aangepast? Eigen Edit Mode-layout of een balk-addon.
local function UICustomized()
	if C_EditMode and C_EditMode.GetLayouts then
		local ok, info = pcall(C_EditMode.GetLayouts)
		local presets = (Enum and Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues) or 2
		if ok and info and info.activeLayout and info.activeLayout > presets then return true end
	end
	for _, name in ipairs(BAR_ADDONS) do
		if IsLoaded(name) then return true end
	end
	return false
end

function ns.BagBarAsk()
	local ch = ns.CharEntry()
	if not ch or ch.hideBagSlots ~= nil or not ns.DB.enabled then return end
	if AlreadyCollapsed() then
		ch.hideBagSlots = true
		Log("bag bar: bag slots already hidden, not asking")
		return
	end
	if not UICustomized() then
		Log("bag bar: standard layout, not asking")
		return
	end
	if InCombatLockdown() then ns.bagBarAskLater = true; return end
	if not StaticPopupDialogs or not StaticPopup_Show then return end
	StaticPopupDialogs["CAREFREEBAG_BAGBAR"] = {
		text = T("CarefreeBag shows how full your bags are on the backpack button. Hide the other bag slots? They come back while you drag a bag. You can change this in the options."),
		button1 = YES or "Yes",
		button2 = NO or "No",
		OnAccept = function() ns.SetHideBagSlots(true) end,
		OnCancel = function(_, _, reason)
			if reason ~= "clicked" then return end
			ns.SetHideBagSlots(false)
		end,
		timeout = 0, whileDead = true, hideOnEscape = false,
	}
	Log("bag bar: asking to hide the other bag slots")
	StaticPopup_Show("CAREFREEBAG_BAGBAR")
end

---------------------------------------------------------------------------
-- Opstarten en events
---------------------------------------------------------------------------

function ns.SetupBagBar()
	ns.UpdateBackpackFill()
	if WantHidden() then SetSlotsHidden(true) end
	C_Timer.After(8, function() ns.Try("bag bar question", ns.BagBarAsk) end)
end

ns.OnEvent("BAG_UPDATE_DELAYED", "backpack fill", function() ns.UpdateBackpackFill() end)
ns.OnEvent("CURSOR_CHANGED", "bag slots", OnCursor) -- retail/Forever
ns.OnEvent("CURSOR_UPDATE", "bag slots", OnCursor)  -- classic
ns.OnEvent("PLAYER_REGEN_ENABLED", "bag slots", function()
	if pending ~= nil then SetSlotsHidden(pending) end
	if ns.bagBarAskLater then ns.bagBarAskLater = nil; ns.BagBarAsk() end
end)
