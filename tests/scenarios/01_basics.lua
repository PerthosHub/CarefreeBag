function A() for _, ch in pairs(CarefreeBagDB.chars) do return ch.assign end end
function H(t) return (t:gsub("^|cff66ccff", ""):gsub("|r$", "")) end
local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
ITEMS = {
  [6948] = { name = "Hearthstone", quality = 1, stack = 1, bind = 1, icon = 1 },
  [7005] = { name = "Skinning Knife", quality = 1, stack = 1, bind = 0, icon = 2 },
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 3 },
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4 },
  [1000] = { name = "Green BoE Sword", quality = 2, stack = 1, bind = 2, icon = 5 },
  [2000] = { name = "My Tank Sword", quality = 3, stack = 1, bind = 2, icon = 6 },
  [3000] = { name = "Scroll of Agility", quality = 1, stack = 5, bind = 0, icon = 7 },
  [5000] = { name = "Kobold Candle", quality = 1, stack = 10, bind = 0, icon = 8, quest = true },
  [8000] = { name = "Broken Fang", quality = 0, stack = 10, bind = 0, icon = 9, price = 5 },
  [8001] = { name = "Torn Cloak", quality = 0, stack = 1, bind = 0, icon = 9, price = 120 },
}
BAGS[0] = { n = 16, [1] = { itemID = 6948, count = 1, bound = true }, [2] = { itemID = 7005, count = 1 },
  [3] = { itemID = 4599, count = 20 }, [4] = { itemID = 4599, count = 7 }, [5] = { itemID = 2589, count = 13 },
  [6] = { itemID = 1000, count = 1 }, [7] = { itemID = 2000, count = 1, bound = true }, [8] = { itemID = 3000, count = 2 } }
BAGS[1] = { n = 10, [1] = { itemID = 2589, count = 20 }, [3] = { itemID = 5000, count = 2 }, [4] = { itemID = 8000, count = 3 }, [5] = { itemID = 8001, count = 1 }, [6] = { itemID = 8000, count = 4 } }

local NS = {}
LoadAddon(NS)

local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...) ; RunTimers() end
CarefreeBagDB = { bankAlt = "Thrall Stormrage", boeAlt = "Jaina Proudmoore", autoSell = true, cats = { { key = "buffs", name = "Buffs" }, { key = "eten", name = "Eten" }, { key = "ah", name = "Naar AH", mail = "bank" }, { key = "craft", name = "Craften" } } }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN")
for i = 1, 5 do E("BAG_UPDATE_DELAYED") end
check(CarefreeBagFrame ~= nil, "venster gemaakt")
check(CarefreeBagDB.lastError == nil, "geen fout bij laden: " .. tostring(CarefreeBagDB.lastError))

check(OVERRIDES.B == "CarefreeBagToggleButton", "B is gekoppeld aan CarefreeBag")
PressKey("B"); RunTimers()
check(CarefreeBagFrame:IsShown(), "B opent CarefreeBag")
check(not ContainerFrameCombinedBags:IsShown(), "Blizzard-tassen verborgen")
NOW = NOW + 1; PressKey("B"); RunTimers()
check(not CarefreeBagFrame:IsShown(), "tweede B sluit CarefreeBag")
NOW = NOW + 1; PressKey("B"); RunTimers()
check(CarefreeBagFrame:IsShown(), "derde B opent weer")
PressKey("B"); RunTimers(); PressKey("B"); RunTimers()
check(CarefreeBagFrame:IsShown(), "snel twee keer B (zelfde moment) = dicht en weer open")
NOW = NOW + 1; ToggleAllBags(); RunTimers()
check(not CarefreeBagFrame:IsShown(), "tasknop in de balk sluit ook")
NOW = NOW + 1; ToggleAllBags(); RunTimers()
check(CarefreeBagFrame:IsShown(), "tasknop in de balk opent ook")

local function shownItems()
  local r = {}
  for i = 1, 60 do local b = _G["CarefreeBagItem" .. i]; if b and b:IsShown() then r[#r+1] = b end end
  return r
end
local function find(name) for _, b in ipairs(shownItems()) do if b.group and b.group.name == name then return b end end end
local function plus(key) for _, f in ipairs(ALLFRAMES) do if f.section == key and f:IsShown() then return f end end end
local function sectionOfTile(name) local b = find(name); return b end

print("tegels:", #shownItems())
local ham = find("Cured Ham Steak")
check(ham and ham.count == 27 and ham.multi:GetText() == "2x", "ham 20+7 blijft 2 vakjes (20 is vol)")
check(ham:GetID() == 4, "klik pakt kleinste stapel (vakje 4)")
local linen = find("Linen Cloth"); check(linen and linen.count == 33, "linen over 2 tassen = 33")
local fang = find("Broken Fang"); check(fang and fang.count == 7 and not fang.multi:IsShown(), "broken fang 3+4 echt samengevoegd tot 1 vakje")
check(BAGS[1][4] == nil or BAGS[1][6] == nil, "een vakje is vrijgekomen")
check(A()[5000] == nil and find("Kobold Candle"), "quest-item zichtbaar")
local qp; for _, f in ipairs(ALLFRAMES) do if f.text and type(f.text)=="string" and H(f.text):find("^Quest") and f.shown then qp = f end end
check(qp, "groep Quest bestaat")
local gp; for _, f in ipairs(ALLFRAMES) do if type(f.text)=="string" and H(f.text):find("^Auto Sell") and f.shown then gp = f end end
check(gp and H(gp.text) == "Auto Sell", "kop Auto Sell zonder totaalwaarde: " .. tostring(gp and gp.text))
check(CarefreeBagDB.lastError == nil, "layout zonder fout")
check(plus("eten") and plus("buffs") and plus("other"), "lege categorieen tonen een + vakje")

-- ham naar Eten slepen
CURSOR = { itemID = 4599 }
plus("eten"):Fire("OnReceiveDrag"); RunTimers()
check(A()[4599] == "eten" and CURSOR == nil, "ham hoort nu bij Eten, cursor leeg")

-- verbergen via de Verbergen-knop
CarefreeBagFrame.hiddenBtn:Fire("OnClick"); RunTimers()
local hs = find("Hearthstone")
check(hs.overlay:IsShown() and plus("hidden"), "verbergmodus: overlay over items en groep Verborgen zichtbaar")
hs.overlay:Fire("OnClick", "LeftButton"); RunTimers()
check((function() for _, ch in pairs(CarefreeBagDB.chars) do return ch.hidden[6948] end end)(), "Hearthstone verborgen met een klik")
check(find("Hearthstone") ~= nil, "in verbergmodus nog zichtbaar (in Verborgen)")
CarefreeBagFrame.hiddenBtn:Fire("OnClick"); RunTimers()
check(find("Hearthstone") == nil, "na Klaar: Hearthstone weg")
check(not find("Cured Ham Steak").overlay:IsShown(), "overlays weg na Klaar")
check(CarefreeBagFrame.hiddenBtn.count.text == 1 or CarefreeBagFrame.hiddenBtn.count.text == "1", "oog-knop toont aantal verborgen: " .. tostring(CarefreeBagFrame.hiddenBtn.count.text))
-- linen naar AH slepen
CURSOR = { itemID = 2589 }; plus("ah"):Fire("OnReceiveDrag"); RunTimers()
check(A()[2589] == "ah", "Linen naar AH-categorie")
-- migratie: oude bank/boe-instellingen omgezet
local ah; for _, c in ipairs(CFC().cats) do if c.key == "ah" then ah = c end end
check(ah.mailTo == "Thrall Stormrage" and CarefreeBagDB.boeMail == "Jaina Proudmoore" and CarefreeBagDB.bankAlt == nil, "oude postinstellingen omgezet naar per categorie")
-- koppen: vaste groep blauw met regels
local og; for _, f in ipairs(ALLFRAMES) do if f.rules and f.shown and f.ruleTitle == "Overig" then og = f end end
check(og and og.fs.text:find("^|cff66ccff"), "vaste groep Overig: blauwe kop met uitleg")

-- vrij-vakje: item erop laten vallen
local before = 0; for s = 1, 16 do if BAGS[0][s] then before = before + 1 end end
C_Container.PickupContainerItem(0, 3) -- ham 20 op cursor
CURSOR = nil; BAGS[0][9] = BAGS[0][3]; BAGS[0][3] = nil; E("BAG_UPDATE_DELAYED")
check(CarefreeBagFrame.free == nil and CarefreeBagFrame.freeBar.text.text:find("/"), "geen vrij-tegel meer, wel de vulbalk")

-- mail
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
check(CarefreeBagMailPanel and CarefreeBagMailPanel:IsShown(), "postpaneel bij mailbox")
check(CarefreeBagMailPanel.text:GetText():find("voortaan automatisch") and CarefreeBagMailPanel.send.text == "Ja, altijd", "eerste keer: vraag of post voortaan altijd zonder vragen mag")
CarefreeBagMailPanel.skip:Fire("OnClick"); RunTimers()
check(CarefreeBagDB.mailAlwaysAuto == false and #SENT == 0, "Nee, vraag het: niets verstuurd, per groep vragen")
print(CarefreeBagMailPanel.text:GetText())
local txt = CarefreeBagMailPanel.text:GetText()
check(txt:find("Wil je alles uit |cffffd100Naar AH|r versturen naar |cff66ccffThrall%-Stormrage|r%?") and txt:find("Linen") and txt:find("Daarna: BoE"), "vraag per categorie: eerst Naar AH, daarna BoE")
check(not txt:find("Hearthstone"), "verborgen gaat niet mee")
check(CarefreeBagMailPanel.skip:IsShown() and CarefreeBagMailPanel.send.text == "Ja, versturen", "knoppen Ja, versturen / Overslaan")
CarefreeBagMailPanel.send:Fire("OnClick"); RunTimers()
check(#SENT == 1 and SENT[1].to == "Thrall-Stormrage" and SENT[1].n == 2, "mail 1: 2x linen naar Thrall-Stormrage: " .. tostring(SENT[1] and SENT[1].to))
check(SENT[1].body == "" and SENT[1].subj:find("^CarefreeBag: "), "mail zonder tekst, onderwerp CarefreeBag")
E("MAIL_SEND_SUCCESS"); RunTimers()
check(#SENT == 1, "na Naar AH stopt hij en vraagt hij de volgende")
txt = CarefreeBagMailPanel.text:GetText()
check(txt:find("alles uit |cffffd100BoE|r versturen naar |cff66ccffJaina%-Proudmoore") and txt:find("Green BoE"), "vraag 2: BoE naar Jaina")
CarefreeBagMailPanel.send:Fire("OnClick"); RunTimers()
check(#SENT == 2 and SENT[2].to == "Jaina-Proudmoore" and SENT[2].n == 1, "mail 2: BoE naar Jaina-Proudmoore")
E("MAIL_SEND_SUCCESS"); RunTimers()
check(not LOG[#LOG]:find("fout"), "geen fout")
local done = false; for _, l in ipairs(LOG) do if l:find("alle post is verstuurd") then done = true end end
check(done, "klaar-melding")
-- overslaan
BAGS[1][2] = { itemID = 1000, count = 1 }; BAGS[0][15] = { itemID = 2589, count = 3 }; E("BAG_UPDATE_DELAYED")
E("MAIL_CLOSED"); MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
check(CarefreeBagMailPanel.text:GetText():find("^Wil je alles uit |cffffd100Naar AH"), "nieuw bezoek: weer eerst Naar AH")
CarefreeBagMailPanel.skip:Fire("OnClick"); RunTimers()
check(#SENT == 2 and CarefreeBagMailPanel.text:GetText():find("^Wil je alles uit |cffffd100BoE"), "overslaan: niets verstuurd, door naar BoE")
BAGS[0][15] = nil; E("BAG_UPDATE_DELAYED")

-- stapmodus na blokkade
BAGS[1][2] = { itemID = 1000, count = 1 }
E("BAG_UPDATE_DELAYED")
CarefreeBagMailPanel.send:Fire("OnClick"); E("ADDON_ACTION_BLOCKED", "CarefreeBag", "SendMail()"); RunTimers()
check(CarefreeBagMailPanel.send.text == "Verstuur deze mail" or CarefreeBagMailPanel.send.text == "Volgende inpakken", "na blokkade: klikmodus voor dit bezoek (" .. tostring(CarefreeBagMailPanel.send.text) .. ")")
E("MAIL_CLOSED"); MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
check(CarefreeBagMailPanel.send.text == "Ja, versturen" and CarefreeBagDB.mailStep == nil, "volgend bezoek: weer automatisch")

-- opties
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig:IsShown(), "/baglab opent opties")
local ob; for _, f in ipairs(ALLFRAMES) do if f.presetID == "own" then ob = f end end
ob:Fire("OnClick"); RunTimers()
check(CarefreeBagConfig.newEdit:IsShown(), "Eigen categorie: naamveld verschijnt")
CarefreeBagConfig.newEdit:SetText("Quest"); CarefreeBagConfig.addBtn:Fire("OnClick"); RunTimers()
check(CFC().cats[#CFC().cats].name == "Quest", "nieuwe categorie toegevoegd")
check(plus(CFC().cats[#CFC().cats].key), "nieuwe categorie zichtbaar met + vakje")
-- hernoemen
local row; for _, f in ipairs(ALLFRAMES) do if f.name and type(f.name)=="table" and f.index == 1 then row = f end end
for _, f in ipairs(ALLFRAMES) do if f.index == 1 and f.name and f.mail then row = f end end
check(row, "categorierij gevonden")
row.name:SetText("Eten"); row.name:Fire("OnEnterPressed"); RunTimers()
check(CFC().cats[1].name == "Eten" and CFC().cats[1].key == "buffs", "categorie hernoemd, key blijft gelijk")
check(CarefreeBagDB.locked == nil, "lock-data weg")
CarefreeBagMinimapButton:Fire("OnClick", "LeftButton"); RunTimers()
check(not CarefreeBagFrame:IsShown(), "minimap linksklik sluit tassen")

-- vendor opent tassen en sluit ze weer
NOW = NOW + 1; OpenAllBags(MerchantFrame); RunTimers()
check(CarefreeBagFrame:IsShown(), "vendor opent tassen")
NOW = NOW + 1; CloseAllBags(MerchantFrame); RunTimers()
check(not CarefreeBagFrame:IsShown(), "vendor dicht sluit tassen")

-- zelf iets naar "kan weg" slepen
SlashCmdList.CAREFREEBAG("show"); RunTimers()
CURSOR = { itemID = 3000 }
check(plus("grey"), "kan weg heeft een + vakje")
plus("grey"):Fire("OnReceiveDrag"); RunTimers()
check(A()[3000] == "grey", "scroll onthouden bij kan weg")
local gp2; for _, f in ipairs(ALLFRAMES) do if type(f.text)=="string" and H(f.text):find("^Auto Sell") and f.shown then gp2 = f end end
check(gp2 and H(gp2.text) == "Auto Sell", "Auto Sell-kop zonder aantal en zonder waarde: " .. tostring(gp2 and gp2.text))
-- grijze cloak eruit halen: moet in Overig blijven
CURSOR = { itemID = 8001 }; plus("other"):Fire("OnReceiveDrag"); RunTimers()
check(A()[8001] == "other", "cloak bewust naar Overig")
-- scroll heeft geen prijs in de mock: geef hem er een
ITEMS[3000].price = 10
MerchantFrame.shown = true; E("MERCHANT_SHOW"); RunTimers()
local soldFang, soldCloak, soldScroll = false, false, false
for _, id in ipairs(SOLD) do if id == 8000 then soldFang = true elseif id == 8001 then soldCloak = true elseif id == 3000 then soldScroll = true end end
check(soldFang and soldScroll, "vendor verkoopt Broken Fang en de zelf toegevoegde scroll")
check(not soldCloak, "cloak die je eruit haalde wordt NIET verkocht")
MerchantFrame.shown = false; E("MERCHANT_CLOSED")
SOLD = {}; SHIFT = true; BAGS[1][7] = { itemID = 8000, count = 1 }
MerchantFrame.shown = true; E("MERCHANT_SHOW"); RunTimers()
check(#SOLD == 0, "Shift bij openen = niets verkocht")
SHIFT = false; MerchantFrame.shown = false; E("MERCHANT_CLOSED")
E("MAIL_CLOSED")
-- in gevecht openen, met nieuw item
COMBAT = true
CarefreeBagFrame:Hide()
BAGS[1][9] = { itemID = 5000, count = 1 }
E("BAG_UPDATE_DELAYED")
NOW = NOW + 1; PressKey("B"); RunTimers()
check(CarefreeBagFrame:IsShown(), "opent in gevecht")
NOW = NOW + 1; PressKey("B"); RunTimers()
check(not CarefreeBagFrame:IsShown(), "sluit in gevecht met B")
NOW = NOW + 1; PressKey("B"); RunTimers()
local sc = find("Kobold Candle")
check(sc and sc.count == 3, "in gevecht bijgewerkt: candle 2+1 = 3")
check(BAGS[1][9] ~= nil, "in gevecht wordt er niet gestapeld")
COMBAT = false; E("PLAYER_REGEN_ENABLED"); for i = 1, 3 do E("BAG_UPDATE_DELAYED") end
check(BAGS[1][9] == nil or BAGS[1][3] == nil, "na gevecht wel gestapeld")
-- AH sorteren op stapelwaarde
Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(c, link)
  if link:find("Linen") then return 50 elseif link:find("Green BoE") then return 1000 end end } } }
BAGS[1][8] = { itemID = 1000, count = 1 }; BAGS[1][10] = { itemID = 2589, count = 20 }; BAGS[0][14] = { itemID = 2589, count = 13 }
A()[1000] = "ah"
CFC().cats[1], CFC().cats[2] = CFC().cats[1], CFC().cats[2]
-- zet AH-categorie bovenaan
for i, k in ipairs(CFC().order) do if k == "ah" then table.remove(CFC().order, i); table.insert(CFC().order, 1, k); break end end
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); E("BAG_UPDATE_DELAYED"); RunTimers()
check(CarefreeBagItem1.group.name == "Linen Cloth" and CarefreeBagItem2.group.name == "Green BoE Sword",
  "AH: linen-stapel (33x50=1650) boven zwaard (1000): " .. CarefreeBagItem1.group.name .. ", " .. CarefreeBagItem2.group.name)
local ahh; for _, f in ipairs(ALLFRAMES) do if type(f.text)=="string" and H(f.text):find("^Naar AH") and f.shown then ahh = f end end
check(ahh and not ahh.text:find("%(AH%)") and not ahh.text:find("2650c"), "AH-kop zonder totaalwaarde: " .. tostring(ahh and ahh.text))
local TT = {}
GameTooltip.AddLine = function(self, t) TT[#TT+1] = t end
GameTooltip.GetOwner = function() return CarefreeBagItem1 end
POSTCALL(GameTooltip)
local ttl = table.concat(TT, " | ")
check(ttl:find("CarefreeBag:|r |cff40ff40Verkoop op het AH: |r|cffffffff%d+c|r|cff40ff40 meer dan bij de vendor"), "tooltip: één regel met advies en verschil: " .. ttl)
-- ===== 0.5.0 =====
local function visibleItems() local r = {}; for i = 1, 200 do local b = _G["CarefreeBagItem" .. i]; if b and b:IsShown() then r[#r+1] = b end end return r end
local function chipFor(key) for _, f in ipairs(ALLFRAMES) do if f.section == key and f.shown and f.text and tostring(f.text):find("^%+ ") then return f end end end
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
check(plus("craft"), "lege categorie: gewone regel met een leeg vakje")
-- zoeken
CarefreeBagSearch:SetText("linen"); CarefreeBagSearch:Fire("OnTextChanged"); RunTimers()
local lin, other
for _, b in ipairs(visibleItems()) do if b.group.name == "Linen Cloth" then lin = b elseif not other then other = b end end
check(lin.matchesSearch == true and other.matchesSearch == false, "zoeken: linen helder, rest grijs")
CarefreeBagSearch:SetText(""); CarefreeBagSearch:Fire("OnTextChanged"); RunTimers()
-- gat laten staan als iets op is, zolang open
local firstName = CarefreeBagItem1.group.name
local e = CarefreeBagItem1.group.rep
BAGS[e.bag][e.slot] = nil; for _, s2 in ipairs(CarefreeBagItem1.group.slots) do BAGS[s2.bag][s2.slot] = nil end
E("BAG_UPDATE_DELAYED"); RunTimers()
local gapShown = false; for _, f in ipairs(ALLFRAMES) do if f.shown and f.bg and not f.section and type(f.text) == "table" and f.text.text == "" and f ~= CarefreeBagFrame.free then gapShown = true end end
check(CarefreeBagItem1.group.name ~= firstName and gapShown, "item op: gat blijft staan, rest schuift niet")
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
local gap2 = false; for _, f in ipairs(ALLFRAMES) do if f.shown and f.bg and not f.section and type(f.text) == "table" and f.text.text == "" and f ~= CarefreeBagFrame.free then gap2 = true end end
check(not gap2, "na sluiten en openen: gat weg, netjes gesorteerd")
-- keyring
KEYRING_CONTAINER = -2
C_ActionBar = { ShouldShowKeyring = function() return true end }
ITEMS[9000] = { name = "Key to Searing Gorge", quality = 1, stack = 1, bind = 1, icon = 10 }
BAGS[-2] = { n = 6, [1] = { itemID = 9000, count = 1, bound = true } }
CarefreeBagDB.fixedOn.keys = true; E("BAG_UPDATE_DELAYED"); RunTimers()
local keyHdr; for _, f in ipairs(ALLFRAMES) do if type(f.text)=="string" and H(f.text) == "Sleutels" and f.shown then keyHdr = f end end
check(keyHdr, "groep Sleutels uit de keyring")
check(CarefreeBagFrame.freeBar.total == 26, "keyring telt niet mee in vrije vakjes: totaal " .. tostring(CarefreeBagFrame.freeBar.total))
-- veel items: venster wordt breder tot max, dan scrollen
UIParent.h = 500; UIParent.w = 1920
for i = 1, 16 do BAGS[2] = BAGS[2] or { n = 16 } end
for i = 1, 16 do ITEMS[20000 + i] = { name = "Ding " .. i, quality = 2, stack = 1, bind = 0, icon = 1 }; BAGS[2][i] = { itemID = 20000 + i, count = 1 } end
BAGS[3] = { n = 16 }; for i = 1, 16 do ITEMS[21000 + i] = { name = "Spul " .. i, quality = 2, stack = 1, bind = 0, icon = 1 }; BAGS[3][i] = { itemID = 21000 + i, count = 1 } end
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
local w = CarefreeBagFrame.w
check(w == CarefreeBagDB.maxCols * 41 - 4 + 32, "venster is precies de ingestelde breedte: " .. w)
check(w <= 16 * 41 - 4 + 32, "maar niet breder dan max 16 kolommen")
check(CarefreeBagFrame.scrollMax > 0 and CarefreeBagFrame.scrollHint:IsShown(), "daarna scrollen (scrollMax " .. CarefreeBagFrame.scrollMax .. ")")
-- nieuwe items: markering weg bij sluiten
REMOVED = 0; C_NewItems = { IsNewItem = function() return true end, RemoveNewItem = function() REMOVED = REMOVED + 1 end }
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
check(CarefreeBagItem1.newGlow:IsShown(), "nieuw item: gouden rand zichtbaar")
CarefreeBagItem1:Fire("OnEnter")
check(not CarefreeBagItem1.newGlow:IsShown() and REMOVED >= 1, "na hover: rand weg en niet meer nieuw " .. tostring(CarefreeBagItem1.newGlow:IsShown()) .. " " .. REMOVED)
CarefreeBagFrame:Hide()
check(REMOVED > 0, "bij sluiten worden nieuwe-item-markeringen weggehaald (" .. REMOVED .. ")")
-- geloot terwijl de tas open staat, ook een item dat je al had: knippert tot hover of sluiten
C_NewItems = { IsNewItem = function() return false end, RemoveNewItem = function() end }
local function tile(id)
	for i = 1, 300 do
		local b = _G["CarefreeBagItem" .. i]
		if b and b.shown and b.group and b.group.itemID == id then return b end
	end
end
SlashCmdList.CAREFREEBAG("show"); RunTimers()
check(tile(20002) and not tile(20002).newGlow:IsShown(), "bij openen: oud item knippert niet")
BAGS[2][1] = { itemID = 20002, count = 1 }; E("BAG_UPDATE_DELAYED"); RunTimers() -- tweede Ding 2 erbij
check(tile(20002) and tile(20002).newGlow:IsShown(), "item dat je al had, erbij geloot: knippert")
check(tile(20003) and not tile(20003).newGlow:IsShown(), "ander item knippert niet")
tile(20002):Fire("OnEnter")
check(not tile(20002).newGlow:IsShown(), "na hover: knippert niet meer")
E("BAG_UPDATE_DELAYED"); RunTimers()
check(not tile(20002).newGlow:IsShown(), "na hover en verversen: blijft uit")
BAGS[2][5] = { itemID = 20002, count = 1 }; E("BAG_UPDATE_DELAYED"); RunTimers() -- nog een Ding 2
check(tile(20002).newGlow:IsShown(), "na hover nog meer van hetzelfde geloot: knippert weer")
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
check(not tile(20002).newGlow:IsShown(), "tas dicht en weer open: knippert niet meer")
CarefreeBagFrame:Hide()
-- quest: zelf erin slepen
SlashCmdList.CAREFREEBAG("show"); RunTimers()
CURSOR = { itemID = 1000 }
check(plus("quest"), "Quest heeft nu ook een + vakje")
plus("quest"):Fire("OnReceiveDrag"); RunTimers()
check(A()[1000] == "quest", "item onthouden bij Quest")
check(CarefreeBagDB.lang == "nl", "bestaande installatie blijft Nederlands")
local qh; for _, f in ipairs(ALLFRAMES) do if type(f.text)=="string" and H(f.text) == "Sleutels" and f.shown then qh = f end end
check(qh, "Nederlandse kop 'Sleutels'")
-- op je bank-alt zelf: niets naar jezelf sturen
MY_SURNAME = "Stormrage"
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
check(not CarefreeBagMailPanel.text.text:find("Thrall.Stormrage"), "op Thrall Stormrage: niets naar jezelf")
E("MAIL_CLOSED"); MY_SURNAME = nil; BAGS[0][15] = { itemID = 2589, count = 5 }; E("BAG_UPDATE_DELAYED")
MailFrame.shown = true; E("MAIL_SHOW"); RunTimers()
check(CarefreeBagMailPanel.text.text:find("Thrall.Stormrage"), "op Thrall Frostwolf: wel naar Thrall Stormrage")
E("MAIL_CLOSED")
print("lastError:", CarefreeBagDB.lastError)
local miss = {}; for k in pairs(MISSING) do miss[#miss+1] = k end; table.sort(miss)
print("onbekende globals:", table.concat(miss, ", "))
for _, l in ipairs(LOG) do if l:find("CHAT") then print(l) end end

print("--- log ---"); for _, l in ipairs(CarefreeBagDB.log) do print(l) end
