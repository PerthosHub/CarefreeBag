-- CarefreeBag: Start.lua
-- Opstarten, events en /cfb-commando's.
-- Alle bestanden delen één omgeving (zie Env.lua). De namen hieronder maakt dit bestand.
local _, ns = ...
setfenv(1, ns.Env(
	"driver", "Try"
))

---------------------------------------------------------------------------
-- Opstarten en events
---------------------------------------------------------------------------

driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")

function Try(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		DB.lastError = label .. ": " .. tostring(err)
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
		Try("bags", HookBags)
		C_Timer.After(2, function() Try("other bags", CheckOtherBags) end)
		mail.step = false
		DB.mailStep = nil -- niet meer onthouden: elk mailboxbezoek eerst automatisch proberen
		for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY",
			"GET_ITEM_INFO_RECEIVED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED",
			"MAIL_SEND_SUCCESS", "MAIL_FAILED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED",
			"ADDON_ACTION_FORBIDDEN", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED",
			"PLAYERBANKBAGSLOTS_CHANGED", "PLAYER_LOGOUT" }) do
			pcall(driver.RegisterEvent, driver, ev)
		end
		Print(T("v%s loaded. Open your bags as usual, or type /cfb for options."):format(VERSION))
		local sep = SurnameSep()
		Log("v" .. VERSION .. " loaded as '" .. tostring(MyFullName()) .. "', name separator: '" .. tostring(sep) .. "'")
		pcall(driver.RegisterEvent, driver, "UI_ERROR_MESSAGE")
		pcall(driver.RegisterEvent, driver, "UPDATE_BINDINGS")
		ScheduleRestack()
		C_Timer.After(3, function() Try("snapshot", SnapBags) end)
	elseif event == "BANKFRAME_OPENED" then
		bankOpen = true
		Try("bank", SnapBank)
		if ViewRefresh then ViewRefresh() end
	elseif event == "BANKFRAME_CLOSED" then
		Try("bank", SnapBank)
		bankOpen = false
	elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYERBANKBAGSLOTS_CHANGED" then
		if bankOpen then
			Try("bank", SnapBank)
			if ViewRefresh then ViewRefresh() end
		end
	elseif event == "PLAYER_LOGOUT" then
		pcall(SnapBags)
	elseif event == "MERCHANT_SHOW" then
		Refresh()
		local ok, err = pcall(SellStart)
		if not ok then Log("auto sell error: " .. tostring(err)) end
	elseif event == "MERCHANT_CLOSED" then
		SellStop("vendor closed")
		Refresh()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if layoutPending then layoutPending = false; Refresh() end
		ScheduleRestack()
		if bindPending then bindPending = false; BindKeys() end
	elseif event == "UPDATE_BINDINGS" then
		if not binding then C_Timer.After(0.1, BindKeys) end
	elseif event == "UI_ERROR_MESSAGE" then
		if mail.busy then Log("game message during mail: " .. tostring(a2)) end
	elseif event == "MAIL_SHOW" then
		mail.step = false -- nieuw bezoek: eerst weer automatisch proberen
		mail.skipped = {}  -- en alle categorieën worden weer gevraagd
		if not DB.enabled then return end
		if not mailPanel then Try("mail", BuildMailPanel) end
		if mailPanel then mailPanel:Show(); UpdateMailPanel() end
		Refresh()
		C_Timer.After(0.5, MailAutoNext)
	elseif event == "MAIL_CLOSED" then
		if mail.busy then MailStop(T("mailbox closed, stopped.")) end
		if mailPanel then mailPanel:Hide() end
		Refresh()
	elseif event == "MAIL_SEND_SUCCESS" then
		if mail.busy and mail.waiting then
			mail.waiting = false
			mail.current = nil
			if mail.step then
				UpdateMailPanel()
			else
				C_Timer.After(0.6, function()
					if mail.busy and MailPack() then
						C_Timer.After(0.4, function() if mail.busy then MailSend() end end)
					end
					UpdateMailPanel()
				end)
			end
		end
		Refresh()
	elseif event == "MAIL_FAILED" then
		Log("MAIL_FAILED" .. (mail.current and (" (to '" .. mail.current.to .. "')") or ""))
		if mail.busy then
			mail.waiting = false
			MailStop(T("sending failed (not enough gold or wrong name?). The items are still in the mail window."))
		end
	elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
		if a1 == ADDON then
			DB.lastError = event .. ": " .. tostring(a2)
			Log("blocked by WoW: " .. tostring(a2))
			if mail.busy and not mail.step then
				-- WoW staat automatisch versturen niet toe: vanaf nu één klik per stap.
				mail.step = true
				mail.waiting = false
				Print(T("WoW blocks automatic sending. Click the button for each mail this time."))
				UpdateMailPanel()
			end
		end
	else
		-- Tassen veranderd, vendor open/dicht, geld, iteminfo binnen.
		Refresh()
		if event == "BAG_UPDATE_DELAYED" then
			ScheduleRestack()
			ScheduleSnap()
			if mailPanel and mailPanel:IsShown() and not mail.busy then UpdateMailPanel() end
		end
	end
end)

_G.SLASH_CAREFREEBAG1 = "/carefree"
_G.SLASH_CAREFREEBAG2 = "/cfb"
SlashCmdList["CAREFREEBAG"] = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "show" or msg == "tassen" then
		ShowMain()
	elseif msg == "minimap" then
		DB.hideMinimap = not DB.hideMinimap
		if CarefreeBagMinimapButton then CarefreeBagMinimapButton:SetShown(not DB.hideMinimap) end
	elseif msg == "log" then
		local l = DB.log or {}
		Print(T("last %d lines of the log:"):format(math.min(15, #l)))
		for i = math.max(1, #l - 14), #l do print("  " .. l[i]) end
	elseif msg == "resetgroups" then
		-- Groepen van dit karakter terugzetten naar de accountlijst van vóór 1.3.0.
		local ch = CharEntry()
		if ch then
			ch.cats, ch.order, ch.sort, ch.collapsed = nil, nil, nil, nil
			catsNamed = nil
			CharEntry(); ResetOrder(); Refresh(); RefreshConfig()
			Print(T("Groups of this character reset."))
			Log("groups reset by /cfb resetgroups")
		end
	elseif msg == "fout" or msg == "error" then
		Print(T("last error: %s"):format(tostring(DB.lastError or T("none"))))
	else
		ToggleConfig()
	end
end
