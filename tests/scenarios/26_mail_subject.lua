local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Issue #20: onderwerp van een mail vanzelf invullen (itemnaam / Multiple items / bedrag).
-- Zelf getypt onderwerp blijft staan; optie uit = niets invullen.
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, price = 10 },
  [2770] = { name = "Copper Ore", quality = 1, stack = 20, bind = 0, icon = 5, price = 5 },
}
BAGS[0] = { n = 16, [1] = { itemID = 2589, count = 20 }, [2] = { itemID = 2589, count = 20 }, [3] = { itemID = 2770, count = 10 } }
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
check(CarefreeBagDB.mailSubject == true, "standaard aan")

-- Nagebootst verzendvenster: onderwerp, geld, rembours
SendMailSubjectEditBox = CreateFrame("EditBox", "SendMailSubjectEditBox")
SendMailMoney = CreateFrame("Frame", "SendMailMoney"); SendMailMoney.copper = 0
SendMailMoneyGold = CreateFrame("EditBox", "SendMailMoneyGold")
SendMailCODButton = CreateFrame("CheckButton", "SendMailCODButton"); SendMailCODButton.checked = false
function MoneyInputFrame_GetCopper(f) return f.copper end
function GetCoinText(c) return math.floor(c / 10000) .. " Gold" end
function GetSendMailItem(i) local a = ATTACHED[i]; if a then return ITEMS[a.itemID].name, a.itemID, 1, a.count end end
local box = SendMailSubjectEditBox
local function Attach(slot) C_Container.PickupContainerItem(0, slot); ClickSendMailItemButton(); E("MAIL_SEND_INFO_UPDATE") end
local function Money(c) SendMailMoney.copper = c; SendMailMoneyGold:Fire("OnTextChanged"); RunTimers() end

MailFrame.shown = true; SendMailFrame.shown = true; E("MAIL_SHOW")
ATTACHED = {}
Attach(1)
check(box:GetText() == "Linen Cloth", "één item: itemnaam (" .. tostring(box:GetText()) .. ")")
Attach(2)
check(box:GetText() == "Linen Cloth", "twee stapels van hetzelfde item: nog steeds de itemnaam")
Attach(3)
check(box:GetText() == "Multiple items", "verschillende items: Multiple items")
Money(120000)
check(box:GetText() == "Multiple items + 12 Gold", "items + geld (" .. tostring(box:GetText()) .. ")")
SendMailCODButton.checked = true; Money(120000)
check(box:GetText() == "Multiple items", "rembours telt niet als geld")
SendMailCODButton.checked = false

-- Alles eruit, alleen geld
ATTACHED = {}; E("MAIL_SEND_INFO_UPDATE")
check(box:GetText() == "12 Gold", "alleen geld: het bedrag")
Money(0)
check(box:GetText() == "", "niets meer in de mail: onderwerp weer leeg")

-- Zelf getypt: blijft staan
box:SetText("For my alt")
BAGS[0][1] = { itemID = 2589, count = 20 }
Attach(1)
check(#ATTACHED == 1, "item zit in de mail")
check(box:GetText() == "For my alt", "zelf getypt onderwerp blijft staan")

-- Na versturen begint het weer leeg; WoW zet zelf soms de itemnaam neer: die mogen we bijwerken
ATTACHED = {}; box:SetText(""); E("MAIL_SEND_SUCCESS")
box:SetText("Copper Ore") -- alsof WoW zelf de naam invulde
ATTACHED = { { itemID = 2770, count = 10 }, { itemID = 2589, count = 20 } }; E("MAIL_SEND_INFO_UPDATE")
check(box:GetText() == "Multiple items", "door WoW ingevulde itemnaam wordt bijgewerkt")

-- Optie uit: niets invullen
CarefreeBagDB.mailSubject = false
ATTACHED = {}; box:SetText(""); E("MAIL_SEND_INFO_UPDATE")
ATTACHED = { { itemID = 2589, count = 20 } }; E("MAIL_SEND_INFO_UPDATE")
check(box:GetText() == "", "optie uit: onderwerp blijft leeg")
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig.subjectCb, "vinkje 'Fill in the mail subject' in de opties")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
