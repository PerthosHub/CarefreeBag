local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Issue #20: onderwerp van een mail vanzelf invullen: geld eerst, dan de items met aantal;
-- meer dan 3 soorten (of te lang) = "Multiple items". Zelf getypt blijft staan; optie uit = niets.
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, price = 10 },
  [2770] = { name = "Copper Ore", quality = 1, stack = 20, bind = 0, icon = 5, price = 5 },
  [2771] = { name = "Tin Ore", quality = 1, stack = 20, bind = 0, icon = 6, price = 5 },
  [2835] = { name = "Rough Stone", quality = 1, stack = 20, bind = 0, icon = 7, price = 1 },
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
local function Set(list) ATTACHED = {}; for _, x in ipairs(list) do ATTACHED[#ATTACHED + 1] = { itemID = x[1], count = x[2] } end; E("MAIL_SEND_INFO_UPDATE") end

MailFrame.shown = true; SendMailFrame.shown = true; E("MAIL_SHOW")
ATTACHED = {}
Attach(1)
check(box:GetText() == "Linen Cloth x20", "één item: naam + aantal (" .. tostring(box:GetText()) .. ")")
Attach(2)
check(box:GetText() == "Linen Cloth x40", "twee stapels van hetzelfde item: opgeteld")
Attach(3)
check(box:GetText() == "Linen Cloth x40, Copper Ore x10", "twee soorten: allebei met aantal (" .. tostring(box:GetText()) .. ")")
Money(120000)
check(box:GetText() == "12 Gold + Linen Cloth x40, Copper Ore x10", "geld eerst, dan de items (" .. tostring(box:GetText()) .. ")")
SendMailCODButton.checked = true; Money(120000)
check(box:GetText() == "Linen Cloth x40, Copper Ore x10", "rembours telt niet als geld")
SendMailCODButton.checked = false; Money(120000)

-- Meer dan 3 soorten: samenvoegen, geld blijft eerst
Set({ { 2589, 20 }, { 2770, 10 }, { 2771, 5 } })
check(box:GetText() == "12 Gold + Linen Cloth x20, Copper Ore x10, Tin Ore x5", "drie soorten: nog uitgeschreven")
Set({ { 2589, 20 }, { 2770, 10 }, { 2771, 5 }, { 2835, 1 } })
check(box:GetText() == "12 Gold + Multiple items", "vier soorten: Multiple items (" .. tostring(box:GetText()) .. ")")
Set({ { 2835, 1 } })
check(box:GetText() == "12 Gold + Rough Stone", "één stuk: geen x1")

-- Te lang (max. 64 letters): samenvoegen
ITEMS[2771].name = "A Very Long Item Name That Goes On And On"
Set({ { 2589, 20 }, { 2771, 5 } })
check(box:GetText() == "12 Gold + Multiple items", "past niet in 64 letters: Multiple items")
ITEMS[2771].name = "Tin Ore"

-- Alles eruit, alleen geld
Set({})
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
Set({ { 2770, 10 }, { 2589, 20 } })
check(box:GetText() == "Copper Ore x10, Linen Cloth x20", "door WoW ingevulde itemnaam wordt bijgewerkt")

-- Optie uit: niets invullen
CarefreeBagDB.mailSubject = false
box:SetText(""); Set({}); Set({ { 2589, 20 } })
check(box:GetText() == "", "optie uit: onderwerp blijft leeg")
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig.subjectCb, "vinkje 'Fill in the mail subject' in de opties")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
