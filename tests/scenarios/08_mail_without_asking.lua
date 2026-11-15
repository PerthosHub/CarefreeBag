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
local txt = CarefreeBagMailPanel.text:GetText()
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
-- groep verwijderen raakt andere karakters niet
CarefreeBagDB.chars["Ander-"] = { assign = { [2589] = "prof" }, cats = { { key = "prof", preset = "prof" } } }
CFC().assign = CFC().assign or {}
local me = CarefreeBagDB.chars["Thrall Frostwolf-"]; me.assign[2589] = "prof"
CarefreeBagConfig:Show(); RunTimers()
local r; for _, f in ipairs(ALLFRAMES) do if f.del and f.key == "prof" and f.shown then r = f end end
r.del:Fire("OnClick"); RunTimers()
check(me.assign[2589] == nil and CarefreeBagDB.chars["Ander-"].assign[2589] == "prof", "verwijderen: alleen dit karakter vergeet de items")
