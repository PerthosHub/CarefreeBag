local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Gebruiksstatistieken, kant van de maker: geen vraag, "ik ben er" in het kanaal, dev-venster
-- met wie online is / ja zei / wat binnenkwam, pakketje bewaren en bevestigen, dubbel = niet
-- dubbel tellen, oude 1.12.0-whispers ook lezen, /cfb stats.
ITEMS = { [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, price = 10 } }
BAGS[0] = { n = 16, [1] = { itemID = 2589, count = 5 } }
LOADED_ADDONS = {}
WOW_PROJECT_MAINLINE = 1; WOW_PROJECT_ID = 1
function GetBuildInfo() return "11.0.0", "1", "", 16001 end
ADDONMSG = {}
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() end,
  SendAddonMessage = function(p, m, k, t) ADDONMSG[#ADDONMSG + 1] = { p = p, m = m, k = k, t = t } end,
}
function JoinTemporaryChannel(n) JOINED = n end
function GetChannelName(n) if n == JOINED then return 5 end return 0 end
local NS = LoadAddon({})
NS.STATS_COLLECTORS[NS.NameHash("Thrall Frostwolf")] = true -- dit karakter is de maker
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
local function Find(pat) for _, x in ipairs(ADDONMSG) do if x.k == "CHANNEL" and x.t == 5 and x.m:find(pat) then return x end end end
local function Dev() return CarefreeBagStatsDev and CarefreeBagStatsDev.text and CarefreeBagStatsDev.text:GetText() or "" end

CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
for _, p in ipairs(POPUPS) do check(p.which ~= "CAREFREEBAG_STATS", "maker krijgt de vraag niet") end
check(JOINED == "CFBStats", "maker zit in het kanaal")
check(Find("^H|Thrall Frostwolf$"), "maker meldt zich in het kanaal")
check(CarefreeBagStatsDev and CarefreeBagStatsDev:IsShown(), "dev-venster zichtbaar")
check(Dev():find("Channel: #5") and Dev():find("Waiting for players") and Dev():find("All time: 0 packets") and Dev():find("Last data: never"), "dev-venster: kanaal, totaal en wachten: " .. Dev())

E("CHAT_MSG_ADDON", "CFBStats", "Y|1.12.1", "CHANNEL", "Bob-Realm")
check(Dev():find("Bob%-Realm said yes %(v1.12.1%)"), "dev-venster: ja gezegd")
E("CHAT_MSG_ADDON", "CFBStats", "P|1.12.1", "CHANNEL", "Bob-Realm")
check(Dev():find("Bob%-Realm is online %(sharing, v1.12.1%)") and Dev():find("online now: 1"), "dev-venster: online")

local function Packet(seq, withError, kind)
  kind = kind or "CHANNEL"
  E("CHAT_MSG_ADDON", "CFBStats", "S|" .. seq .. "|id=abc123|v=1.12.1|c=16001|l=enUS|lang=en|s=2026-11-21|d=2|li=3|o=7|m=50|ma=1|ch=2", kind, "Bob-Realm")
  if withError then
    E("CHAT_MSG_ADDON", "CFBStats", "O|" .. seq .. "|as=1|ab=0|lp=1|oc=1|ms=1|bf=1|hb=0|mq=1|en=1|g=4|ob=1", kind, "Bob-Realm")
    E("CHAT_MSG_ADDON", "CFBStats", "F|" .. seq .. "|ls=2|lp=1|ll=1|sl=3|sg=1500|cm=4|bk=5|sr=6|dr=7|sw=1", kind, "Bob-Realm")
    E("CHAT_MSG_ADDON", "CFBStats", "E|" .. seq .. "|2|Loot.lua:10: a|b", kind, "Bob-Realm")
  end
  E("CHAT_MSG_ADDON", "CFBStats", "X|" .. seq .. "|1", kind, "Bob-Realm")
end
Packet("111", true)
local r = CarefreeBagDB.collected and CarefreeBagDB.collected.abc123
check(r and r.opens == 7 and r.logins == 3 and r.minutes == 50 and r.mails == 1 and r.days == 2, "pakketje bewaard")
check(r.version == "1.12.1" and r.name == "Bob-Realm" and r.chars == 2, "versie, afzender, karakters")
check(r.errors["Loot.lua:10: a|b"] == 2, "fout bewaard (ook met | erin)")
check(r.opts and r.opts.as == "1" and r.opts.ab == "0" and r.f and r.f.dr == 7 and r.f.sg == 1500, "opties en tellers bewaard")
check(Dev():find("Options on: Auto Sell 1/1, Equip better bags automatically 0/1") and Dev():find("items dragged 7") and Dev():find("4.0 on average, other bag addon: 1 players"), "dev-venster: overzicht opties en functies: " .. Dev())
check(Find("^A|111$"), "bevestigd in het kanaal")
check(Dev():find("Data from Bob%-Realm: 3 logins, 7 bag opens, 2 errors") and Dev():find("players: 1"), "dev-venster: data binnen: " .. Dev())
check(Dev():find("All time: 1 packets, 3 logins, 7 bag opens, 0 hours played, 2 errors") and not Dev():find("Last data: never"), "dev-venster: totaal van alles: " .. Dev())

-- Weggeklikt en er komt data binnen: venster weer open
CarefreeBagStatsDev:Hide()
E("CHAT_MSG_ADDON", "CFBStats", "S|112|id=abc123|v=1.12.1|d=0|li=0|o=0|m=0|ma=0|ch=2", "CHANNEL", "Bob-Realm")
E("CHAT_MSG_ADDON", "CFBStats", "X|112|0", "CHANNEL", "Bob-Realm")
check(CarefreeBagStatsDev:IsShown() and Dev():find("All time: 2 packets"), "weggeklikt: nieuwe data opent het venster weer")

-- Dubbel (ons A kwam niet aan): opnieuw bevestigen, niet dubbel tellen
ADDONMSG = {}
Packet("111", true)
check(r.opens == 7, "dubbel pakketje niet dubbel geteld")
check(Find("^A|111$"), "dubbel: wel weer bevestigd")

-- Onvolledig (E ontbreekt): niet bewaren, niet bevestigen
ADDONMSG = {}
Packet("222", false)
check(r.opens == 7 and not Find("^A|222$"), "onvolledig: niet bewaard en niet bevestigd")
check(Dev():find("Incomplete data from Bob%-Realm"), "dev-venster: onvolledig")

-- 1.12.0 stuurde per whisper: ook dat komt binnen
ADDONMSG = {}
E("CHAT_MSG_ADDON", "CFBStats", "S|333|id=abc123|v=1.12.0|d=0|li=0|o=7|m=0|ma=0|ch=2", "WHISPER", "Bob-Realm")
E("CHAT_MSG_ADDON", "CFBStats", "X|333|0", "WHISPER", "Bob-Realm")
check(r.opens == 14 and Find("^A|333$"), "oude whisper-pakketjes ook bewaard en bevestigd")

-- Rapport
CarefreeBagStatsDev:Hide()
SlashCmdList.CAREFREEBAG("stats")
local said = false
for _, l in ipairs(LOG) do if l:find("Usage stats: 1 players") then said = true end end
check(said, "/cfb stats toont het rapport")
check(CarefreeBagStatsDev:IsShown(), "/cfb stats opent het dev-venster")

SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig.statsCb == nil, "maker: geen deel-vinkje in de opties")
check(CarefreeBagConfig.statsDevCb, "maker: vinkje 'Show stats window (dev)'")

-- Dev-venster uit: niet meer vanzelf openen, wel bijhouden
CarefreeBagDB.statsDevShow = false
CarefreeBagStatsDev:Hide()
E("CHAT_MSG_ADDON", "CFBStats", "P|1.12.1", "CHANNEL", "Ann-Realm")
check(not CarefreeBagStatsDev:IsShown() and Dev():find("Ann%-Realm is online"), "uit: blijft dicht, maar houdt het wel bij")
SlashCmdList.CAREFREEBAG("stats")
check(CarefreeBagStatsDev:IsShown(), "uit: /cfb stats opent hem toch")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
