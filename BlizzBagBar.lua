-- CarefreeBag: BlizzBagBar.lua
-- De tassenbalk van WoW zelf (issue #4, deel B):
--  * vulbalk óp de echte rugzakknop: van onder naar boven, groen -> rood (alleen gewone vakjes;
--    reagent-tas en beroepstassen tellen niet mee). Optie DB.bagFill, standaard aan.
--  * de andere tasvakjes verbergen (per karakter: ch.hideBagSlots) zolang het CFB-venster dicht is;
--    tassen open = hele balk zichtbaar. Retail: WoW's eigen inklap-pijltje (CVar expandBagBar).
--    Forever/Classic: geen werkend pijltje, dus de vakjes, sleutelring en balk-achtergrond zelf.
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

-- Retail heeft een inklap-pijltje naast de rugzak (CVar expandBagBar). Forever kent de CVar en
-- het frame misschien wel, maar toont het pijltje niet (Classic-tassenbalk): alleen een
-- zichtbaar pijltje telt, anders verbergen we de vakjes zelf.
local function HasCollapse()
	local t = BagBarExpandToggle
	return t ~= nil and t.IsVisible ~= nil and t:IsVisible() and GetCV("expandBagBar") ~= nil
end

-- De tasvakjes naast de rugzak, plus het reagent-vak en de sleutelring
-- (sleutels zie je in CFB als de groep Keys aan staat).
local function ClassicSlots()
	local list = {}
	for i = 0, NUM_BAGS - 1 do
		local f = _G["CharacterBag" .. i .. "Slot"]
		if f then list[#list + 1] = f end
	end
	if CharacterReagentBag0Slot then list[#list + 1] = CharacterReagentBag0Slot end
	if KeyRingButton then list[#list + 1] = KeyRingButton end
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

-- Forever: de vakjes zitten in BagsBar, die zelf de randen tekent (plaatje UI-HUD-ActionBar-Frame)
-- en per vakje een naamloos kind-frame met de zwarte achtergrond heeft (gezien in Johans log,
-- 2026-11-20). Die maken we onzichtbaar met alpha (niet Hide), zodat Edit Mode en de layout
-- van WoW er niet van in de war raken. Alleen kind-frames zonder naam, zichtbaar en zo groot als
-- een vakje: het Edit Mode-selectiekader (verborgen) en de rugzak blijven met rust.
local art -- { region of frame, ... }, één keer verzameld
local function BarArt()
	if art then return art end
	art = {}
	local bar = BagsBar
	if not bar or not CharacterBag0Slot or not CharacterBag0Slot.GetParent then return art end
	-- alleen als de vakjes echt in deze balk zitten (direct of via BagSlotCluster)
	local p, inBar = CharacterBag0Slot:GetParent(), false
	for _ = 1, 3 do
		if p == bar then inBar = true end
		p = p and p.GetParent and p:GetParent()
	end
	if not inBar then return art end
	for _, r in ipairs({ bar:GetRegions() }) do art[#art + 1] = r end
	for _, c in ipairs({ bar:GetChildren() }) do
		local named = c.GetName and c:GetName()
		local w = c.GetWidth and c:GetWidth() or 0
		if not named and c:IsShown() and w > 0 and w <= 64 then art[#art + 1] = c end
	end
	return art
end

local function SetBarArt(show)
	local list = BarArt()
	for _, o in ipairs(list) do
		if o.SetAlpha then o:SetAlpha(show and 1 or 0) end
	end
	return #list
end

local function SetSlotsHidden(hide, quiet)
	if InCombatLockdown() then
		pending = hide
		if not quiet then Log("bag slots: wait for end of combat") end
		return
	end
	pending = nil
	slotsHidden = hide
	if HasCollapse() then
		if not quiet then Log("bag slots " .. (hide and "collapsed" or "expanded") .. " with the arrow") end
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
	-- Forever/Classic: geen pijltje, dus de vakjes zelf (en weer verbergen als WoW ze toont).
	for _, f in ipairs(ClassicSlots()) do
		if not classicHooked and f.HookScript then
			f:HookScript("OnShow", function(self) if slotsHidden then self:Hide() end end)
		end
		f:SetShown(not hide)
	end
	classicHooked = true
	local nArt = SetBarArt(not hide)
	if not quiet then Log("bag slots " .. (hide and "hidden" or "shown") .. " (" .. #ClassicSlots() .. " frames, " .. nArt .. " art)") end
end

-- Hoe hoort de balk nu te staan? Verborgen alleen als je dat gekozen hebt, CFB aan staat en
-- het CFB-venster dicht is. Tassen open = hele balk zichtbaar (tassen + sleutelring).
-- Alleen iets doen als het verandert (en dan stil: openen/sluiten hoort niet in de log).
function ns.UpdateBagSlots(quiet)
	local hide = WantHidden() and ns.DB.enabled and not (ns.main and ns.main:IsShown()) or false
	if hide == slotsHidden and pending == nil then return end
	SetSlotsHidden(hide, quiet)
end

-- Vanuit de opties (en de vraag): per karakter.
function ns.SetHideBagSlots(v)
	local ch = ns.CharEntry()
	if not ch then return end
	ch.hideBagSlots = v and true or false
	Log("hide other bag slots: " .. tostring(ch.hideBagSlots))
	ns.UpdateBagSlots()
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
		text = T("CarefreeBag shows how full your bags are on the backpack button. Hide the other bag slots and key ring while your bags are closed? You can change this in the options."),
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
	ns.UpdateBagSlots()
	-- CFB open = tassen en sleutelring zichtbaar, dicht = alleen de rugzak
	if ns.main and ns.main.HookScript then
		ns.main:HookScript("OnShow", function() ns.UpdateBagSlots(true) end)
		ns.main:HookScript("OnHide", function() ns.UpdateBagSlots(true) end)
	end
	C_Timer.After(8, function() ns.Try("bag bar question", ns.BagBarAsk) end)
end

ns.OnEvent("BAG_UPDATE_DELAYED", "backpack fill", function() ns.UpdateBackpackFill() end)
ns.OnEvent("PLAYER_REGEN_ENABLED", "bag slots", function()
	if pending ~= nil then pending = nil; ns.UpdateBagSlots(true) end -- stand van nu, niet van tijdens het gevecht
	if ns.bagBarAskLater then ns.bagBarAskLater = nil; ns.BagBarAsk() end
end)
