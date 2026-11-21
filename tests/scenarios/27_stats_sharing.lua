local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Gebruiksstatistieken, kant van de speler: vraag bij de start, niets zonder toestemming,
-- tellen, alleen naar de echte maker sturen, wissen na "ontvangen", uitzetten = alles weg.
ITEMS = { [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, price = 10 } }
BAGS[0] = { n = 16, [1] = { itemID = 2589, count = 5 } }
LOADED_ADDONS = {}
WOW_PROJECT_MAINLINE = 1; WOW_PROJECT_ID = 1
function GetBuildInfo() return "11.0.0", "1", "", 16001 end
ADDONMSG = {}
C_ChatInfo = {
  RegisterAddonMessagePrefix = function(p) PREFIX_REG = p end,
  SendAddonMessage = function(p, m, k, t) ADDONMSG[#ADDONMSG + 1] = { p = p, m = m, k = k, t = t } end,
}
function JoinTemporaryChannel(n) JOINED = n end
function GetChannelName(n) if n == JOINED then return 5 end return 0 end
function LeaveChannelByName(n) if n == JOINED then JOINED = nil end end
local NS = LoadAddon({})
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
local function Whispers(to) local r = {}; for _, x in ipairs(ADDONMSG) do if x.k == "WHISPER" and x.t == to then r[#r + 1] = x.m end end; return r end

check(NS.NameHash("Thrall Frostwolf") == 2411278354, "naam-hash gelijk aan die van het hulpscript (" .. NS.NameHash("Thrall Frostwolf") .. ")")
check(NS.NameHash("THRALL frostwolf") == NS.NameHash("thrall frostwolf"), "hash zonder verschil in hoofdletters")

CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); E("PLAYER_ENTERING_WORLD", true); RunTimers()
local asked = false
for _, p in ipairs(POPUPS) do if p.which == "CAREFREEBAG_STATS" then asked = true end end
check(asked, "bij de start de vraag")
check(StaticPopupDialogs.CAREFREEBAG_STATS.text:find("brand new"), "vraag: 'brand new'")
check(StaticPopupDialogs.CAREFREEBAG_STATS.button1 == "Sure, no problem" and StaticPopupDialogs.CAREFREEBAG_STATS.button2 == "No, rather not", "knoppen")
check(not JOINED, "geen toestemming: geen kanaal")
check(CarefreeBagDB.stats == nil and CarefreeBagDB.statsShare == nil, "geen toestemming: niets geteld")

-- Ja
StaticPopupDialogs.CAREFREEBAG_STATS.OnAccept(); RunTimers()
check(CarefreeBagDB.statsShare == true, "toestemming bewaard")
check(JOINED == "CFBStats" and PREFIX_REG == "CFBStats", "verborgen kanaal en prefix")
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
check(CarefreeBagDB.stats.opens == 2, "tassen open geteld: " .. tostring(CarefreeBagDB.stats.opens))
E("PLAYER_ENTERING_WORLD", false); E("PLAYER_ENTERING_WORLD", true)
check(CarefreeBagDB.stats.logins == 1, "/reload telt niet als login, echt inloggen wel")
NS.SetError("Interface/AddOns/CarefreeBag/Loot.lua:10: boom")
NS.SetError("Interface/AddOns/CarefreeBag/Loot.lua:10: boom")
check(CarefreeBagDB.stats.errors["Loot.lua:10: boom"] == 2, "fout geteld, zonder pad")

-- Nep-maker: andere voornaam dan de naam in het bericht
NS.STATS_COLLECTORS[NS.NameHash("Perthos Test")] = true
E("CHAT_MSG_ADDON", "CFBStats", "H|Perthos Test", "CHANNEL", "Evil-Realm"); RunTimers()
check(#Whispers("Evil-Realm") == 0, "niets naar een nep-maker")
E("CHAT_MSG_ADDON", "CFBStats", "H|Perthos Test", "CHANNEL", "Perthosian-Realm"); RunTimers()
check(#Whispers("Perthosian-Realm") == 0, "voornaam die er alleen mee begint telt niet")
-- Onbekende naam
E("CHAT_MSG_ADDON", "CFBStats", "H|Someone Else", "CHANNEL", "Someone-Realm"); RunTimers()
check(#Whispers("Someone-Realm") == 0, "niets naar een onbekende")

-- Echte maker
E("CHAT_MSG_ADDON", "CFBStats", "H|Perthos Test", "CHANNEL", "Perthos-Realm"); RunTimers()
local w = Whispers("Perthos-Realm")
check(#w == 3, "drie regels naar de maker: " .. #w)
check(w[1]:find("^S|%d+|") and w[1]:find("|o=2|") and w[1]:find("|id=%x+|") and w[1]:find("|c=16001|"), "S-regel met tellers: " .. tostring(w[1]))
check(w[2]:find("^E|%d+|2|Loot.lua:10: boom$"), "E-regel: " .. tostring(w[2]))
check(w[3]:find("^X|%d+|1$"), "X-regel: " .. tostring(w[3]))
local seq = w[1]:match("^S|(%d+)|")
check(CarefreeBagDB.statsOutbox and CarefreeBagDB.statsOutbox.seq == seq, "pakketje bewaard tot ontvangen")
check(CarefreeBagDB.stats.opens == 0 and next(CarefreeBagDB.stats.errors) == nil, "tellers weer op nul")

-- Nog een "H" voordat het bevestigd is: niet meteen opnieuw (pas na 5 minuten)
E("CHAT_MSG_ADDON", "CFBStats", "H|Perthos Test", "WHISPER", "Perthos-Realm"); RunTimers()
check(#Whispers("Perthos-Realm") == 3, "niet meteen opnieuw versturen")

-- Ontvangen: weg bij de speler
E("CHAT_MSG_ADDON", "CFBStats", "A|999", "WHISPER", "Perthos-Realm")
check(CarefreeBagDB.statsOutbox, "verkeerd volgnummer: blijft bewaard")
E("CHAT_MSG_ADDON", "CFBStats", "A|" .. seq, "WHISPER", "Perthos-Realm")
check(CarefreeBagDB.statsOutbox == nil, "bevestigd: gewist")

-- Opties: vinkje
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig.statsCb, "vinkje 'Help improve CarefreeBag' in de opties")

-- Uit: niets meer bewaren, kanaal uit
NS.SetStatsShare(false)
check(CarefreeBagDB.statsShare == false and CarefreeBagDB.stats == nil and JOINED == nil, "uit: gewist en kanaal uit")
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
check(CarefreeBagDB.stats == nil, "uit: niets geteld")
check(CarefreeBagDB.lastError == "Interface/AddOns/CarefreeBag/Loot.lua:10: boom", "alleen de eigen testfout: " .. tostring(CarefreeBagDB.lastError))
