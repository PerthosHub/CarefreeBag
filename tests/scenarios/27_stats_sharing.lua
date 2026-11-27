local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Gebruiksstatistieken, kant van de speler: vraag bij de start, niets zonder toestemming,
-- tellen, alleen naar de echte maker sturen (via het kanaal), wissen na "ontvangen",
-- uitzetten = alles weg.
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
function JoinTemporaryChannel(n, pass) JOINED = n; JOIN_PASS = pass end
function GetChannelName(n) if n == JOINED then return 5 end return 0 end
function LeaveChannelByName(n) if n == JOINED then JOINED = nil end end
local NS = LoadAddon({})
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
local function Chan(pat) local r = {}; for _, x in ipairs(ADDONMSG) do if x.k == "CHANNEL" and x.t == 5 and x.m:find(pat) then r[#r + 1] = x.m end end; return r end
local function Whispers() local n = 0; for _, x in ipairs(ADDONMSG) do if x.k == "WHISPER" then n = n + 1 end end; return n end

check(NS.NameHash("Thrall Frostwolf") == 2411278354, "naam-hash gelijk aan die van het hulpscript (" .. NS.NameHash("Thrall Frostwolf") .. ")")
check(NS.NameHash("THRALL frostwolf") == NS.NameHash("thrall frostwolf"), "hash zonder verschil in hoofdletters")

CarefreeBagDB = { lang = "en", autoBags = false }
-- zoals in WoW: inloggen en de wereld in, pas daarna lopen de timers (melding na 12 s)
E("ADDON_LOADED", "CarefreeBag"); DRIVER:Fire("OnEvent", "PLAYER_LOGIN"); DRIVER:Fire("OnEvent", "PLAYER_ENTERING_WORLD", true); RunTimers()
local asked = false
for _, p in ipairs(POPUPS) do if p.which == "CAREFREEBAG_STATS" then asked = true end end
check(asked, "bij de start een melding (Johans keuze 2026-11-27: geen ja/nee-vraag meer)")
local dlg = StaticPopupDialogs.CAREFREEBAG_STATS
check(dlg.text:find("so bugs get fixed faster") and dlg.text:find("Turn it off in the options"), "melding: wat, waarom, en waar je het uitzet")
check(not dlg.text:find("name") and NS.StatsDetails():find("character name is sent along"), "naam niet in de melding, wel in de uitleg bij het vinkje")
check(dlg.button1 == "OK" and dlg.button2 == nil and not dlg.OnAccept, "één knop OK, geen keuze in de melding")
RunTimers()
check(CarefreeBagDB.statsShare == true, "delen staat aan zodra de melding er is")
check(JOINED == "CFBStats" and JOIN_PASS == "cfb4stats" and PREFIX_REG == "CFBStats", "verborgen kanaal met wachtwoord en prefix")
check(#Chan("^Y|") == 1 and #Chan("^P|") == 1, "maker hoort 'net ja gezegd' en 'online'")
check(Chan("^P|")[1] == "P|" .. NS.VERSION .. "|" .. tostring(CarefreeBagDB.statsID), "online-ping met nummer: " .. tostring(Chan("^P|")[1]))
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
check(CarefreeBagDB.stats.opens == 2, "tassen open geteld: " .. tostring(CarefreeBagDB.stats.opens))
E("PLAYER_ENTERING_WORLD", false); E("PLAYER_ENTERING_WORLD", true)
check(CarefreeBagDB.stats.logins == 1, "/reload telt niet als login, echt inloggen wel")
NS.SetError("Interface/AddOns/CarefreeBag/Loot.lua:10: boom")
NS.SetError("Interface/AddOns/CarefreeBag/Loot.lua:10: boom")
check(CarefreeBagDB.stats.errors["Loot.lua:10: boom"] == 2, "fout geteld, zonder pad")
NS.StatsCount("dr"); NS.StatsCount("dr"); NS.StatsCount("sg", 150)
check(CarefreeBagDB.stats.f.dr == 2 and CarefreeBagDB.stats.f.sg == 150, "tellers per functie")
CarefreeBagDB.autoSell = true

-- Nep-makers
NS.STATS_COLLECTORS[NS.NameHash("Perthos Test")] = true
E("CHAT_MSG_ADDON", "CFBStats", "H|Perthos Test", "CHANNEL", "Evil-Realm"); RunTimers()
E("CHAT_MSG_ADDON", "CFBStats", "H|Perthos Test", "CHANNEL", "Perthosian-Realm"); RunTimers()
E("CHAT_MSG_ADDON", "CFBStats", "H|Someone Else", "CHANNEL", "Someone-Realm"); RunTimers()
check(#Chan("^S|") == 0, "niets naar een nep-maker (andere voornaam, langere voornaam, onbekende naam)")

-- Echte maker
E("CHAT_MSG_ADDON", "CFBStats", "H|Perthos Test", "CHANNEL", "Perthos-Realm"); RunTimers()
local S, Er, X = Chan("^S|"), Chan("^E|"), Chan("^X|")
check(#S == 1 and #Er == 1 and #X == 1, "pakketje in het kanaal: S, E, X")
check(S[1]:find("|o=2|") and S[1]:find("|id=%x+|") and S[1]:find("|c=16001|") and S[1]:find("|li=1|"), "S-regel met tellers: " .. tostring(S[1]))
check(Er[1]:find("^E|%d+|2|Loot.lua:10: boom$"), "E-regel: " .. tostring(Er[1]))
check(X[1]:find("^X|%d+|1$"), "X-regel: " .. tostring(X[1]))
local O, F = Chan("^O|"), Chan("^F|")
check(#O == 1 and O[1]:find("|as=1|") and O[1]:find("|ab=0|") and O[1]:find("|g=%d+|") and O[1]:find("|ob=0$"), "O-regel met opties: " .. tostring(O[1]))
check(#F == 1 and F[1]:find("|dr=2|") and F[1]:find("|sg=150|") and F[1]:find("|sw=0$"), "F-regel met tellers: " .. tostring(F[1]))
check(#O[1] < 255 and #F[1] < 255 and #S[1] < 255, "elke regel past in een addon-bericht")
check(Whispers() == 0, "geen whispers (Horde en Alliance kunnen elkaar niet fluisteren)")
local seq = S[1]:match("^S|(%d+)|")
check(CarefreeBagDB.statsOutbox and CarefreeBagDB.statsOutbox.seq == seq, "pakketje bewaard tot ontvangen")
check(CarefreeBagDB.stats.opens == 0 and next(CarefreeBagDB.stats.errors) == nil and next(CarefreeBagDB.stats.f) == nil, "tellers weer op nul")

-- Nog een "H" voordat het bevestigd is: niet meteen opnieuw (pas na 5 minuten)
E("CHAT_MSG_ADDON", "CFBStats", "H|Perthos Test", "CHANNEL", "Perthos-Realm"); RunTimers()
check(#Chan("^S|") == 1, "niet meteen opnieuw versturen")

-- Ontvangen: weg bij de speler, maar alleen als het van de maker komt
E("CHAT_MSG_ADDON", "CFBStats", "A|999", "CHANNEL", "Perthos-Realm")
check(CarefreeBagDB.statsOutbox, "verkeerd volgnummer: blijft bewaard")
E("CHAT_MSG_ADDON", "CFBStats", "A|" .. seq, "CHANNEL", "Evil-Realm")
check(CarefreeBagDB.statsOutbox, "bevestiging van iemand anders telt niet")
E("CHAT_MSG_ADDON", "CFBStats", "A|" .. seq, "CHANNEL", "Perthos-Realm")
check(CarefreeBagDB.statsOutbox == nil, "bevestigd door de maker: gewist")

-- Opties: vinkje
SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig.statsCb, "vinkje 'Help improve CarefreeBag' in de opties")
check(CarefreeBagStatsDev == nil, "speler krijgt geen dev-venster")

-- Uit: niets meer bewaren, kanaal uit
local myID = CarefreeBagDB.statsID
ADDONMSG = {}
NS.SetStatsShare(false)
check(#Chan("^N|") == 1 and Chan("^N|")[1] == "N|" .. tostring(myID), "uit: eerst een afmelding met het nummer")
RunTimers()
check(CarefreeBagDB.statsShare == false and CarefreeBagDB.stats == nil and JOINED == nil, "uit: gewist en kanaal uit")
CarefreeBagFrame:Hide(); SlashCmdList.CAREFREEBAG("show"); RunTimers()
NS.StatsCount("dr")
check(CarefreeBagDB.stats == nil and CarefreeBagDB.statsID == nil, "uit: niets geteld, ook geen nummer meer")
check(CarefreeBagDB.lastError == "Interface/AddOns/CarefreeBag/Loot.lua:10: boom", "alleen de eigen testfout: " .. tostring(CarefreeBagDB.lastError))
