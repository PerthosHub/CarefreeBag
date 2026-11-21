-- CarefreeBag: Start.lua
-- Opstarten en /cfb-commando's. De andere events regelt elk bestand zelf (ns.OnEvent, zie Core.lua).
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local BuildConfig, BuildMain, BuildMinimapButton, CharEntry, CheckOtherBags = ns.BuildConfig, ns.BuildMain, ns.BuildMinimapButton, ns.CharEntry, ns.CheckOtherBags
local Defaults, FixOrder, HookBags, Log, MyFullName, Print = ns.Defaults, ns.FixOrder, ns.HookBags, ns.Log, ns.MyFullName, ns.Print
local ResetOrder, ScheduleRestack, ShowMain, SnapBags, SurnameSep, Try = ns.ResetOrder, ns.ScheduleRestack, ns.ShowMain, ns.SnapBags, ns.SurnameSep, ns.Try
local T = ns.T

---------------------------------------------------------------------------
-- Opstarten
---------------------------------------------------------------------------

ns.OnEvent("ADDON_LOADED", "settings", function(_, name)
	if name == ADDON then Defaults() end
end)

ns.OnEvent("PLAYER_LOGIN", "login", function()
	-- Volgorde telt: eerst de vensters, dan pas naar events luisteren.
	Try("order", FixOrder)
	Try("window", BuildMain)
	Try("options", BuildConfig)
	Try("minimap", BuildMinimapButton)
	Try("settings", ns.RegisterSettings)
	Try("bags", HookBags)
	Try("bag swap", ns.SetupBagSwap)
	Try("bag bar", ns.SetupBagBar)
	C_Timer.After(3, function() ns.ScheduleBagCheck() end)
	C_Timer.After(2, function() Try("other bags", CheckOtherBags) end)
	ns.mail.step = false
	ns.DB.mailStep = nil -- niet meer onthouden: elk mailboxbezoek eerst automatisch proberen
	ns.StartEvents()
	-- Alleen bij de eerste keer en na een update iets in de chat, niet bij elke login.
	if not ns.DB.lastVersion then
		Print(T("v%s loaded. Open your bags as usual, or type /cfb for options."):format(ns.VERSION))
	elseif ns.DB.lastVersion ~= ns.VERSION then
		Print(T("updated to v%s."):format(ns.VERSION))
	end
	ns.DB.lastVersion = ns.VERSION
	Log("v" .. ns.VERSION .. " loaded as '" .. tostring(MyFullName()) .. "', name separator: '" .. tostring(SurnameSep()) .. "'")
	ns.Note("login", "v" .. ns.VERSION .. " as '" .. tostring(MyFullName()) .. "'") -- context bij de belangrijke momenten
	ScheduleRestack()
	C_Timer.After(3, function() Try("snapshot", SnapBags) end)
end)

-- WoW blokkeerde iets van ons: onthouden voor /cfb error (Chores.lua en Mail.lua reageren er zelf op).
local function Blocked(event, addon, what)
	if addon ~= ADDON then return end
	-- welke tassen-toestand erbij hoorde (voor later terugkijken)
	local okS, _, free = pcall(ns.Scan)
	local loot = GetNumLootItems and (GetNumLootItems() or 0) or 0
	ns.SetError(event .. ": " .. tostring(what) .. (okS and free and (" (free slots " .. #free .. ", loot window items " .. loot
		.. (InCombatLockdown and InCombatLockdown() and ", in combat" or "") .. ")") or ""))
end
ns.OnEvent("ADDON_ACTION_BLOCKED", "blocked", Blocked)
ns.OnEvent("ADDON_ACTION_FORBIDDEN", "blocked", Blocked)

---------------------------------------------------------------------------
-- /cfb
---------------------------------------------------------------------------

SLASH_CAREFREEBAG1 = "/carefree"
SLASH_CAREFREEBAG2 = "/cfb"
SlashCmdList["CAREFREEBAG"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "show" or msg == "tassen" then
		ShowMain()
	elseif msg == "minimap" then
		ns.DB.hideMinimap = not ns.DB.hideMinimap
		if CarefreeBagMinimapButton then CarefreeBagMinimapButton:SetShown(not ns.DB.hideMinimap) end
	elseif msg == "log" then
		local l = ns.DB.log or {}
		Print(T("last %d lines of the log:"):format(math.min(15, #l)))
		for i = math.max(1, #l - 14), #l do print("  " .. l[i]) end
	elseif msg == "resetgroups" then
		-- Groepen van dit karakter terugzetten naar de accountlijst van vóór 1.3.0.
		local ch = CharEntry()
		if ch then
			ch.cats, ch.order, ch.sort, ch.collapsed = nil, nil, nil, nil
			ns.catsNamed = nil
			CharEntry(); ResetOrder(); ns.Refresh(); ns.RefreshConfig()
			Print(T("Groups of this character reset."))
			Log("groups reset by /cfb resetgroups")
		end
	elseif msg == "stats" then
		ns.StatsReport()
	elseif msg == "fout" or msg == "error" then
		Print(T("last error: %s"):format(tostring(ns.DB.lastError or T("none")) .. (ns.DB.lastErrorTime and (" (" .. ns.DB.lastErrorTime .. ")") or "")))
	else
		ns.ToggleConfig()
	end
end
