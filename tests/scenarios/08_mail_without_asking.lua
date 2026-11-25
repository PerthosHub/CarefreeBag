local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, class = 7, price = 5 },
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 3, class = 0, sub = 5, price = 10 },
  [1000] = { name = "Green BoE Sword", quality = 2, stack = 1, bind = 2, icon = 5, class = 2, equip = "INVTYPE_WEAPON" },
}
BAGS[0] = { n = 8, [1] = { itemID = 2589, count = 5 }, [2] = { itemID = 4599, count = 5 }, [3] = { itemID = 1000, count = 1 } }
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
CarefreeBagDB = { lang = "en" }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
-- Professions -> Jaina (zonder vragen), Consumables -> Jaina (met vraag), BoE -> Jaina (met vraag)
local prof, cons
for _, c in ipairs(CFC().cats) do if c.key == "prof" then prof = c elseif c.key == "consum" then cons = c end end
-- optievenster: vinkje pas zichtbaar met ontvanger
CarefreeBagConfig:Show(); RunTimers()
local row; for _, f in ipairs(ALLFRAMES) do if f.mailAuto and f.key == "prof" and f.shown then row = f end end
check(row and not row.mailAuto:IsShown(), "zonder ontvanger: geen vinkje 'zonder vragen'")
row.mail:SetText("Jaina Frostwolf"); row.mail:Fire("OnEnterPressed"); RunTimers()
check(prof.mailTo == "Jaina Frostwolf" and row.mailAuto:IsShown(), "ontvanger ingevuld: vinkje verschijnt")
row.mailAuto:SetChecked(true); row.mailAuto:Fire("OnClick"); RunTimers()
check(prof.mailAuto == true, "Professions: zonder vragen aan")
cons.mailTo = "Jaina Frostwolf"; CarefreeBagDB.boeMail = "Jaina Frostwolf"
CarefreeBagConfig:Hide()
-- mailbox
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
check(#SENT == 1 and SENT[1].n == 1, "Professions meteen verstuurd, zonder klikken")
E("MAIL_SEND_SUCCESS"); RunTimers()
check(#SENT == 1, "daarna wacht hij op de vraag voor de rest")
check(CarefreeBagMailPanel.text:GetText():find("automatically from now on") and CarefreeBagMailPanel.skip.text == "No, ask me", "eerste keer: vraag of het voortaan altijd zonder vragen mag")
CarefreeBagMailPanel.skip:Fire("OnClick"); RunTimers()
check(CarefreeBagDB.mailAlwaysAuto == false and #SENT == 1, "Nee: blijft per groep vragen, niets extra verstuurd")
local txt = CarefreeBagMailPanel.text:GetText()
check(txt:find("Send everything in"), "daarna de gewone vraag")
check(txt:find("Consumables") or txt:find("BoE"), "vraag staat klaar voor een groep met vraag: " .. txt:sub(1, 60))
CarefreeBagMailPanel.skip:Fire("OnClick"); RunTimers()
check(#SENT == 1, "overslaan verstuurt niets")
print("lastError:", CarefreeBagDB.lastError)
-- twee groepen zonder vragen: na elkaar, zonder klikken
cons.mailAuto = true; CarefreeBagDB.boeMailAuto = true
E("MAIL_CLOSED"); MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
E("MAIL_SEND_SUCCESS"); RunTimers(); RunTimers()
check(#SENT == 3, "Consumables en BoE allebei automatisch verstuurd: " .. #SENT)
print("lastError:", CarefreeBagDB.lastError)
-- eerste keer "Ja, altijd": alles meteen, en de optie staat daarna aan
E("MAIL_CLOSED")
BAGS[0] = { n = 8, [1] = { itemID = 2589, count = 5 }, [2] = { itemID = 4599, count = 5 }, [3] = { itemID = 1000, count = 1 } }
prof.mailAuto, cons.mailAuto, CarefreeBagDB.boeMailAuto, CarefreeBagDB.mailAlwaysAuto = nil, nil, nil, nil
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
local n0 = #SENT
check(n0 == 3 and CarefreeBagMailPanel.text:GetText():find("automatically from now on"), "nog niets verstuurd, eerst de vraag")
CarefreeBagMailPanel.send:Fire("OnClick"); RunTimers()
for i = 1, 3 do E("MAIL_SEND_SUCCESS"); RunTimers() end
check(CarefreeBagDB.mailAlwaysAuto == true and #SENT == n0 + 3, "Ja, altijd: alle drie groepen verstuurd: " .. (#SENT - n0))
E("MAIL_CLOSED")
CarefreeBagConfig:Show(); RunTimers()
local cb; for _, f in ipairs(ALLFRAMES) do if f.label and f.label.text == "Always mail without asking" then cb = f end end
check(cb and cb.checked == true, "optie Always mail without asking staat aan")
local row2; for _, f in ipairs(ALLFRAMES) do if f.mailAuto and f.key == "prof" and f.shown then row2 = f end end
check(row2.mailAuto.enabled == false and row2.mailAuto.checked, "vinkje per groep: aan en niet te wijzigen")
cb:SetChecked(false); cb:Fire("OnClick"); RunTimers()
check(CarefreeBagDB.mailAlwaysAuto == false and row2.mailAuto.enabled == true, "optie weer uit: per groep weer in te stellen")
CarefreeBagConfig:Hide()
-- groep verwijderen raakt andere karakters niet
CarefreeBagDB.chars["Ander-"] = { assign = { [2589] = "prof" }, cats = { { key = "prof", preset = "prof" } } }
CFC().assign = CFC().assign or {}
local me = CarefreeBagDB.chars["Thrall Frostwolf-"]; me.assign[2589] = "prof"
CarefreeBagConfig:Show(); RunTimers()
local r; for _, f in ipairs(ALLFRAMES) do if f.del and f.key == "prof" and f.shown then r = f end end
r.del:Fire("OnClick"); RunTimers()
-- eerst vragen (issue #21): zonder "ja" gebeurt er niets
check(POPUPS[#POPUPS].which == "CAREFREEBAG_DELCAT" and me.assign[2589] == "prof", "verwijderen: eerst een vraag, nog niets weg")
StaticPopupDialogs.CAREFREEBAG_DELCAT.OnCancel(); RunTimers()
check(me.assign[2589] == "prof", "nee: groep blijft")
r.del:Fire("OnClick"); StaticPopupDialogs.CAREFREEBAG_DELCAT.OnAccept(); RunTimers()
check(me.assign[2589] == nil and CarefreeBagDB.chars["Ander-"].assign[2589] == "prof", "verwijderen: alleen dit karakter vergeet de items")
