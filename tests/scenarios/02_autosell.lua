local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
ITEMS = { [8000] = { name = "Broken Fang", quality = 0, stack = 10, bind = 0, icon = 9, price = 5 },
          [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4 } }
BAGS[0] = { n = 16, [1] = { itemID = 8000, count = 3 }, [2] = { itemID = 2589, count = 5 } }
LOADED_ADDONS = { Baganator = true }
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
check(CarefreeBagDB.lang == "en", "nieuwe gebruiker: Engels")
check(CarefreeBagDB.boeMail == "" and CFC().cats[3].mailTo == nil, "geen postadressen ingevuld")
check(#CFC().cats == 3 and CFC().cats[1].name == "Consumables" and CFC().cats[2].preset == "prof" and CFC().cats[3].name == "Gear", "drie automatische standaardcategorieen")
local conflict; for _, p in ipairs(POPUPS) do if p.which == "CAREFREEBAG_CONFLICT" then conflict = p end end
check(conflict and conflict.arg == "Baganator", "waarschuwing: Baganator neemt ook de tassen over")
check(StaticPopupDialogs.CAREFREEBAG_CONFLICT.button2 == "Baganator", "keuzeknop Baganator")
StaticPopupDialogs.CAREFREEBAG_CONFLICT.OnCancel(nil, nil, "clicked")
check(CarefreeBagDB.enabled == false and CarefreeBagDB.conflictOK.Baganator, "kies Baganator: CarefreeBag staat uit")
-- CFB uit: klik op de minimapknop opent de opties (aan/uit staat bovenaan)
CarefreeBagMinimapButton:Fire("OnClick", "LeftButton")
check(CarefreeBagConfig:IsShown(), "minimap bij CFB uit: opties open")
NS.SetEnabled(true)
check(CarefreeBagDB.enabled == true, "aanzetten in de opties: CarefreeBag weer aan")
NS.SetEnabled(false)
check(CarefreeBagDB.enabled == false and OVERRIDES.B == nil, "uit: B weer voor Blizzard")
NS.SetEnabled(true)
CarefreeBagConfig:Hide()
-- opnieuw inloggen: niet nog eens vragen
POPUPS = {}
-- vendor: eerste keer vragen
MerchantFrame.shown = true; E("MERCHANT_SHOW"); RunTimers()
local ask; for _, p in ipairs(POPUPS) do if p.which == "CAREFREEBAG_AUTOSELL" then ask = p end end
check(ask and #SOLD == 0, "eerste vendor: eerst vragen, nog niets verkocht")
StaticPopupDialogs.CAREFREEBAG_AUTOSELL.OnAccept(); RunTimers()
check(#SOLD == 1 and SOLD[1] == 8000 and CarefreeBagDB.autoSell and CarefreeBagDB.autoSellAsked, "Ja: Broken Fang verkocht, linen niet")
MerchantFrame.shown = false; E("MERCHANT_CLOSED")
POPUPS = {}; BAGS[0][3] = { itemID = 8000, count = 1 }
MerchantFrame.shown = true; E("MERCHANT_SHOW"); RunTimers()
check(#POPUPS == 0 and #SOLD == 2, "tweede vendor: niet meer vragen, gewoon verkopen")
-- taal wisselen
SlashCmdList.CAREFREEBAG(""); RunTimers()
local lb = CarefreeBagLangButton
check(lb, "taalknop in de opties")
lb:Fire("OnClick"); check(CarefreeBagLangMenu:IsShown(), "taalmenu open")
local deb; for _, f in ipairs(ALLFRAMES) do if f.langCode == "de" then deb = f end end
deb:Fire("OnClick"); check(CarefreeBagDB.lang == "de" and CarefreeBagReloadPrompt:IsShown() and CarefreeBagReloadButton ~= nil, "taal naar Duits, venster met herlaadknop")
local nlb; for _, f in ipairs(ALLFRAMES) do if f.langCode == "nl" then nlb = f end end
nlb:Fire("OnClick"); check(CarefreeBagDB.lang == "nl", "taal naar Nederlands")
-- postadres per categorie via de opties
local row; for _, f in ipairs(ALLFRAMES) do if f.key == "gear" and f.fixedName then row = f end end
check(row, "categorierij met postveld")
row.mail:SetText("Bankie Alt"); row.mail:Fire("OnEnterPressed")
check(CFC().cats[3].mailTo == "Bankie Alt", "postadres voor Gear ingesteld")
row.mail:SetText(""); row.mail:Fire("OnEnterPressed")
check(CFC().cats[3].mailTo == nil, "leeg = niet mailen")
-- BoE-adres
SlashCmdList.CAREFREEBAG(""); SlashCmdList.CAREFREEBAG(""); RunTimers()
local boeEdit; for _, f in ipairs(ALLFRAMES) do if f.key == "boe" and f.fixedName then boeEdit = f.mail end end
boeEdit:SetText("Boe Friend"); boeEdit:Fire("OnEnterPressed")
check(CarefreeBagDB.boeMail == "Boe Friend", "BoE-postadres bij de vaste groep BoE")
check(CarefreeBagDB.maxCols == 14 and CarefreeBagDB.cols == nil, "één kolommen-instelling")
-- opties: één lijst met vaste groepen
local rows = {}
for _, f in ipairs(ALLFRAMES) do if f.key and f.fixedName and f.shown then rows[#rows+1] = f end end
table.sort(rows, function(a, b) return a.index < b.index end)
local keys = {}; for _, r in ipairs(rows) do keys[#keys+1] = r.key end
check(table.concat(keys, ",") == "consum,prof,gear,quest,keys,boe,grey,other", "lijst: " .. table.concat(keys, ","))
local greyRow = rows[7]
check(greyRow.fixedName:IsShown() and not greyRow.name:IsShown() and not greyRow.del:IsShown(), "vaste groep: blauwe naam, niet te wijzigen of verwijderen")
greyRow.up:Fire("OnClick")
check(CFC().order[6] == "grey", "vaste groep omhoog verplaatst")
-- vaste groep uit/aan
local gr; for _, f in ipairs(ALLFRAMES) do if f.key == "grey" and f.onCb then gr = f end end
check(gr and gr.onCb:IsShown(), "Auto Sell heeft een aan/uit-vinkje")
gr.onCb:SetChecked(false); gr.onCb:Fire("OnClick"); RunTimers()
check(CarefreeBagDB.fixedOn.grey == false, "Auto Sell uitgezet")
SOLD = {}; BAGS[0][5] = { itemID = 8000, count = 2 }
MerchantFrame.shown = true; E("MERCHANT_SHOW"); RunTimers(); MerchantFrame.shown = false; E("MERCHANT_CLOSED")
check(#SOLD == 0, "Auto Sell uit: niets verkocht")
local ot; for _, f in ipairs(ALLFRAMES) do if f.key == "other" and f.onCb then ot = f end end
check(not ot.onCb:IsShown(), "Overig kan niet uit")
local addY = select(5, CarefreeBagConfig.newEdit:GetPoint())
print("lastError:", CarefreeBagDB.lastError)
