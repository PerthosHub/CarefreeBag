-- CarefreeBag: Start.lua
-- Opstarten, events en /cfb-commando's.
-- Gedeelde namen staan in de addon-tabel `ns` (zie CLAUDE.md).
local ADDON, ns = ...
-- uit eerdere bestanden:
local BuildConfig, BuildMailPanel, BuildMain, BuildMinimapButton, CharEntry, CheckOtherBags = ns.BuildConfig, ns.BuildMailPanel, ns.BuildMain, ns.BuildMinimapButton, ns.CharEntry, ns.CheckOtherBags
local Defaults, FixOrder, HookBags, Log, MailAutoNext, MailPack = ns.Defaults, ns.FixOrder, ns.HookBags, ns.Log, ns.MailAutoNext, ns.MailPack
local MailSend, MailStop, MyFullName, Print, ResetOrder, ScheduleRestack = ns.MailSend, ns.MailStop, ns.MyFullName, ns.Print, ns.ResetOrder, ns.ScheduleRestack
local ScheduleSnap, SellStop, ShowMain, SnapBags, SnapBank, SurnameSep = ns.ScheduleSnap, ns.SellStop, ns.ShowMain, ns.SnapBags, ns.SnapBank, ns.SurnameSep
local T = ns.T

---------------------------------------------------------------------------
-- Opstarten en events
---------------------------------------------------------------------------

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")

local function Try(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		ns.DB.lastError = label .. ": " .. tostring(err)
		Log("error in " .. label .. ": " .. tostring(err))
		Print(T("error in %s: %s"):format(label, tostring(err)))
	end
end

driver:SetScript("OnEvent", function(_, event, a1, a2)
	if event == "ADDON_LOADED" and a1 == ADDON then
		Defaults()
	elseif event == "PLAYER_LOGIN" then
		Try("order", FixOrder)
		Try("window", BuildMain)
		Try("options", BuildConfig)
		Try("minimap", BuildMinimapButton)
		Try("settings", ns.RegisterSettings)
		Try("bags", HookBags)
		Try("bag swap", ns.SetupBagSwap)
		C_Timer.After(3, function() ns.ScheduleBagCheck() end)
		C_Timer.After(2, function() Try("other bags", CheckOtherBags) end)
		ns.mail.step = false
		ns.DB.mailStep = nil -- niet meer onthouden: elk mailboxbezoek eerst automatisch proberen
		for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY",
			"GET_ITEM_INFO_RECEIVED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED",
			"MAIL_SEND_SUCCESS", "MAIL_FAILED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED",
			"ADDON_ACTION_FORBIDDEN", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
			"PLAYERBANKBAGSLOTS_CHANGED", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_CLOSED" }) do
			pcall(driver.RegisterEvent, driver, ev)
		end
		-- Alleen bij de eerste keer en na een update iets in de chat, niet bij elke login.
		if not ns.DB.lastVersion then
			Print(T("v%s loaded. Open your bags as usual, or type /cfb for options."):format(ns.VERSION))
		elseif ns.DB.lastVersion ~= ns.VERSION then
			Print(T("updated to v%s."):format(ns.VERSION))
		end
		ns.DB.lastVersion = ns.VERSION
		local sep = SurnameSep()
		Log("v" .. ns.VERSION .. " loaded as '" .. tostring(MyFullName()) .. "', name separator: '" .. tostring(sep) .. "'")
		pcall(driver.RegisterEvent, driver, "UI_ERROR_MESSAGE")
		pcall(driver.RegisterEvent, driver, "UPDATE_BINDINGS")
		ScheduleRestack()
		C_Timer.After(3, function() Try("snapshot", SnapBags) end)
	elseif event == "BANKFRAME_OPENED" then
		ns.bankOpen = true
		Try("bank", SnapBank)
		if ns.ViewRefresh then ns.ViewRefresh() end
	elseif event == "BANKFRAME_CLOSED" then
		-- Niet meer uitlezen: tijdens het sluiten is de bank al (deels) leeg.
		ns.bankOpen = false
		ScheduleRestack() -- tijdens de bank niet samengevoegd: nu wel
		ns.ScheduleBagCheck(1.5)
	elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
		if ns.bankOpen then
			Try("bank", SnapBank)
			if ns.ViewRefresh then ns.ViewRefresh() end
		end
	elseif event == "MERCHANT_SHOW" then
		ns.Refresh()
		local ok, err = pcall(ns.SellStart)
		if not ok then Log("auto sell error: " .. tostring(err)) end
	elseif event == "MERCHANT_CLOSED" then
		SellStop("vendor closed")
		ns.Refresh()
		ns.ScheduleBagCheck(1.5)
	elseif event == "PLAYER_REGEN_ENABLED" then
		if ns.layoutPending then ns.layoutPending = false; ns.Refresh() end
		ScheduleRestack()
		if ns.bindPending then ns.bindPending = false; ns.BindKeys() end
		ns.ScheduleBagCheck(1.5)
	elseif event == "UPDATE_BINDINGS" then
		if not ns.binding then C_Timer.After(0.1, ns.BindKeys) end
	elseif event == "LOOT_OPENED" or event == "LOOT_SLOT_CLEARED" or event == "LOOT_CLOSED" then
		Try("loot", ns.LootEvent, event)
		if event == "LOOT_CLOSED" then
			C_Timer.After(0.5, function() Try("clams", ns.OpenClams) end)
			ns.ScheduleBagCheck(1.5)
		end
	elseif event == "UI_ERROR_MESSAGE" then
		if ns.mail.busy then Log("game message during mail: " .. tostring(a2)) end
		if ERR_INV_FULL and a2 == ERR_INV_FULL then Try("loot", ns.LootEvent, "FULL") end
	elseif event == "MAIL_SHOW" then
		ns.mailOpen = true -- geen stapels samenvoegen zolang de mailbox open is (Chores.lua)
		ns.mail.step = false -- nieuw bezoek: eerst weer automatisch proberen
		ns.mail.skipped = {}  -- en alle categorieën worden weer gevraagd
		ns.MailReportClose()  -- oud verslag nog in beeld: weg, paneel weer aan de mailbox
		ns.mail.report = nil
		if not ns.DB.enabled then return end
		if not ns.mailPanel then Try("mail", BuildMailPanel) end
		if ns.mailPanel then ns.mailPanel:Show(); ns.UpdateMailPanel() end
		ns.Refresh()
		C_Timer.After(0.5, MailAutoNext)
	elseif event == "MAIL_CLOSED" then
		ns.mailOpen = false
		ScheduleRestack() -- tijdens de mailbox niet samengevoegd: nu wel
		if ns.mail.busy then MailStop(T("mailbox closed, stopped.")) end
		-- Tijdens het verslag blijft het paneel staan (het telt zelf af).
		if ns.mailPanel and not ns.mailPanel.reporting then ns.mailPanel:Hide() end
		ns.Refresh()
		ns.ScheduleBagCheck(1.5)
	elseif event == "MAIL_SEND_SUCCESS" then
		-- Meteen onthouden wat er nog in je tassen zit (anders mist het bankpaneel/de tooltip
		-- het als je vlak na het versturen van karakter wisselt).
		C_Timer.After(0.5, function() Try("snapshot", SnapBags) end)
		if ns.mail.busy and ns.mail.waiting then
			ns.mail.waiting = false
			ns.MailSent(ns.mail.current)
			ns.mail.current = nil
			if ns.mail.step then
				ns.UpdateMailPanel()
			else
				C_Timer.After(0.6, function()
					if ns.mail.busy and MailPack() then
						C_Timer.After(0.4, function() if ns.mail.busy then MailSend() end end)
					end
					ns.UpdateMailPanel()
				end)
			end
		end
		ns.Refresh()
	elseif event == "MAIL_FAILED" then
		Log("MAIL_FAILED" .. (ns.mail.current and (" (to '" .. ns.mail.current.to .. "')") or ""))
		if ns.mail.busy then
			ns.mail.waiting = false
			MailStop(T("sending failed (not enough gold or wrong name?). The items are still in the mail window."))
		end
	elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		if a1 == ADDON then
			ns.DB.lastError = event .. ": " .. tostring(a2)
			Log("blocked by WoW: " .. tostring(a2))
			if tostring(a2):find("UseContainerItem") and not ns.clamBlocked then
				-- WoW staat automatisch openen hier niet toe: stoppen (tot /reload) en één keer melden.
				ns.clamBlocked = true
				Print(T("WoW does not allow opening clams automatically here. Open them yourself with a right-click."))
			end
			if ns.mail.busy and not ns.mail.step then
				-- WoW staat automatisch versturen niet toe: vanaf nu één klik per stap.
				ns.mail.step = true
				ns.mail.waiting = false
				Print(T("WoW blocks automatic sending. Click the button for each mail this time."))
				ns.UpdateMailPanel()
			end
		end
	else
		-- Tassen veranderd, vendor open/dicht, geld, iteminfo binnen.
		ns.Refresh()
		if event == "PLAYER_MONEY" then ScheduleSnap() end -- goud onthouden voor het bankpaneel
		if event == "GET_ITEM_INFO_RECEIVED" then ns.ScheduleBagCheck() end -- tas-info binnen: misschien nu aandoen
		if event == "BAG_UPDATE_DELAYED" then
			-- questlijstje open en je gooit iets weg: lijstje bijwerken
			if CarefreeBagQuestReminder and CarefreeBagQuestReminder:IsShown() then Try("quest list", ns.QuestReminderFill) end
			ScheduleRestack()
			ScheduleSnap()
			ns.LootEvent("BAG")
			Try("clams", ns.OpenClams)
			ns.ScheduleBagCheck()
			if ns.mailPanel and not ns.mail.busy then
				if ns.mailPanel:IsShown() then ns.UpdateMailPanel()
				-- paneel was weg omdat er niets te versturen was: misschien nu wel (post opgehaald)
				elseif ns.mailPanel.emptyHidden and MailFrame and MailFrame:IsShown() then ns.mailPanel:Show() end
			end
		end
	end
end)

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
	elseif msg == "fout" or msg == "error" then
		Print(T("last error: %s"):format(tostring(ns.DB.lastError or T("none"))))
	else
		ns.ToggleConfig()
	end
end
