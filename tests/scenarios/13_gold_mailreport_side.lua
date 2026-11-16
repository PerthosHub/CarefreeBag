local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Issues #3 (goud in het bankpaneel), #2 (mailbox dicht met aftelknop), #1 (panelen links/rechts).
ITEMS = {
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 3, class = 0, sub = 5, price = 10 },
  [1000] = { name = "Green BoE Sword", quality = 2, stack = 1, bind = 2, icon = 5, class = 2, equip = "INVTYPE_WEAPON" },
}
BAGS[0] = { n = 8, [1] = { itemID = 4599, count = 5 }, [2] = { itemID = 1000, count = 1 } }
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
CarefreeBagDB = { lang = "en", boeMail = "Jaina Proudmoore", boeMailAuto = true }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
local me = CarefreeBagDB.chars["Thrall Frostwolf-"]
check(me, "eigen karakter bestaat")

-- #3 goud ------------------------------------------------------------------
check(me.snap and me.snap.money == 123456, "goud van dit karakter onthouden: " .. tostring(me.snap and me.snap.money))
CarefreeBagDB.chars["Jaina Proudmoore-"] = { snap = { name = "Jaina Proudmoore", class = "MAGE", money = 5000, bags = {} } }
NS.ToggleViewer(); RunTimers()
local g = CarefreeBagViewer.goldText or ""
check(g:find("You: |r123456c", 1, true), "bankpaneel: jouw goud: " .. g)
check(g:find("All characters: |r128456c", 1, true), "bankpaneel: alles samen 123456 + 5000: " .. g)
GetMoney = function() return 200000 end
E("PLAYER_MONEY"); RunTimers()
check(me.snap.money == 200000, "goud veranderd: opnieuw onthouden")
check((CarefreeBagViewer.goldText or ""):find("205000c", 1, true), "totaal ververst: " .. tostring(CarefreeBagViewer.goldText))

-- #1 kant wisselen ----------------------------------------------------------
local function anchor(f) local p = f.points and f.points[1]; return p and p[1], p and p[3] end
local a1, a3 = anchor(CarefreeBagViewer)
check(a1 == "TOPRIGHT" and a3 == "TOPLEFT", "standaard: bankpaneel links van de tassen")
check(CarefreeBagViewer.sideArrow and CarefreeBagViewer.sideArrow:IsShown(), "pijltje zichtbaar")
local ap = CarefreeBagViewer.sideArrow.points[1]
check(ap[1] == "TOPRIGHT", "pijltje rechts (kant van de tassen)")
CarefreeBagViewer.sideArrow:Fire("OnClick"); RunTimers()
check(me.panelSide == "right", "kant onthouden voor dit karakter")
a1, a3 = anchor(CarefreeBagViewer)
check(a1 == "TOPLEFT" and a3 == "TOPRIGHT", "bankpaneel nu rechts van de tassen")
check(CarefreeBagViewer.sideArrow.points[1][1] == "TOPLEFT", "pijltje verhuist mee naar de kant van de tassen (links)")
SlashCmdList.CAREFREEBAG(""); RunTimers() -- opties openen
check(CarefreeBagConfig:IsShown(), "optievenster open")
a1, a3 = anchor(CarefreeBagConfig)
check(a1 == "TOPLEFT" and a3 == "TOPRIGHT", "optievenster ook rechts")
CarefreeBagConfig.sideArrow:Fire("OnClick"); RunTimers()
a1, a3 = anchor(CarefreeBagConfig)
check(me.panelSide == "left" and a1 == "TOPRIGHT" and a3 == "TOPLEFT", "pijltje in de opties: terug naar links")
CarefreeBagDB.chars["Jaina Proudmoore-"].panelSide = "right"
check(me.panelSide == "left", "een ander karakter heeft zijn eigen kant")
CarefreeBagConfig:Hide()

-- #2 mailbox dicht met aftelknop ---------------------------------------------
local slow = {}
local realAfter = C_Timer.After
C_Timer.After = function(d, f) if d == 1 then slow[#slow + 1] = f else realAfter(d, f) end end
local closed = 0
function CloseMail() closed = closed + 1; MailFrame.shown = false; DRIVER:Fire("OnEvent", "MAIL_CLOSED") end
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
check(#SENT == 1, "BoE zonder vragen verstuurd")
E("MAIL_SEND_SUCCESS"); RunTimers()
local p = CarefreeBagMailPanel
check(closed == 1, "alles verstuurd: mailbox dicht")
check(p:IsShown() and p.reporting, "paneel blijft staan met het verslag")
check(p.parent == UIParent, "paneel los van de mailbox")
check(p.text:GetText():find("Green BoE Sword", 1, true) and p.text:GetText():find("Jaina Proudmoore", 1, true), "verslag: wat en naar wie: " .. p.text:GetText())
check(p.send.text == "Close (5)", "knop telt af vanaf 5: " .. tostring(p.send.text))
check(not p.skip:IsShown(), "geen Overslaan-knop in het verslag")
local f = table.remove(slow, 1); f()
check(p.send.text == "Close (4)", "na 1 seconde: 4")
for _ = 1, 4 do local t = table.remove(slow, 1); if t then t() end end
check(not p:IsShown() and not p.reporting, "na 5 seconden weg")
check(p.parent == MailFrame, "weer aan de mailbox vast voor de volgende keer")

-- opnieuw, nu wegklikken met de knop
slow = {}
BAGS[0][3] = { itemID = 1000, count = 1 }; E("BAG_UPDATE_DELAYED")
for _, t in ipairs(slow) do t() end; slow = {} -- snapshot-timer gewoon laten lopen
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
E("MAIL_SEND_SUCCESS"); RunTimers()
check(p.reporting and closed == 2, "tweede keer: weer verslag en mailbox dicht")
p.send:Fire("OnClick"); RunTimers()
check(not p:IsShown() and not p.reporting and p.parent == MailFrame, "klik op de aftelknop: meteen weg")
for _, t in ipairs(slow) do t() end -- oude timers doen niets meer
check(not p:IsShown(), "oude aftel-timer opent niets opnieuw")

-- post in de inbox: verslag wel, mailbox blijft open
function GetInboxNumItems() return 2, 2 end
function GetInboxHeaderInfo(i) if i == 2 then return nil, nil, "AH", "Sold", 5000, 0, 3, nil end return nil, nil, "Bob", "Hi", 0, 0, 3, nil end
slow = {}
BAGS[0][4] = { itemID = 1000, count = 1 }; E("BAG_UPDATE_DELAYED")
for _, t in ipairs(slow) do t() end; slow = {}
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
E("MAIL_SEND_SUCCESS"); RunTimers()
check(p.reporting and closed == 2 and MailFrame.shown, "goud van het AH in de inbox: verslag, maar mailbox blijft open")
check(p.parent == MailFrame, "paneel blijft dan aan de mailbox")
for _ = 1, 5 do local t = table.remove(slow, 1); if t then t() end end
check(p:IsShown() and not p.reporting and p.send.text ~= "Close (1)", "na het aftellen: paneel blijft, weer de gewone weergave")
E("MAIL_CLOSED")
-- alleen een oude brief zonder iets erin: telt niet, mailbox gaat wel dicht
function GetInboxHeaderInfo(i) return nil, nil, "Bob", "Hi", 0, 0, 3, nil end
slow = {}
BAGS[0][5] = { itemID = 1000, count = 1 }; E("BAG_UPDATE_DELAYED")
for _, t in ipairs(slow) do t() end; slow = {}
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
E("MAIL_SEND_SUCCESS"); RunTimers()
check(closed == 3 and p.reporting and p.parent == UIParent, "lege brieven in de inbox: mailbox gaat wel dicht")
p.send:Fire("OnClick"); RunTimers()
GetInboxNumItems, GetInboxHeaderInfo = nil, nil

-- niets verstuurd (alleen een vraag): mailbox blijft open
CarefreeBagDB.boeMailAuto = false; CarefreeBagDB.mailAlwaysAuto = false
BAGS[0][3] = { itemID = 1000, count = 1 }; E("BAG_UPDATE_DELAYED")
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
check(closed == 3 and MailFrame.shown and not p.reporting, "alleen een vraag: mailbox blijft open")
C_Timer.After = realAfter
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
