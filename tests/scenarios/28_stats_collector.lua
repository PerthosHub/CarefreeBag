local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
-- Gebruiksstatistieken, kant van de maker: geen vraag, "ik ben er" in het kanaal,
-- antwoord op een ping, pakketje bewaren en bevestigen, dubbel = niet dubbel tellen, /cfb stats.
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
local function Find(k, t, pat) for _, x in ipairs(ADDONMSG) do if x.k == k and x.t == t and x.m:find(pat) then return x end end end

CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); RunTimers()
for _, p in ipairs(POPUPS) do check(p.which ~= "CAREFREEBAG_STATS", "maker krijgt de vraag niet") end
check(JOINED == "CFBStats", "maker zit in het kanaal")
check(Find("CHANNEL", 5, "^H|Thrall Frostwolf$"), "maker meldt zich in het kanaal")

E("CHAT_MSG_ADDON", "CFBStats", "P", "CHANNEL", "Bob-Realm")
check(Find("WHISPER", "Bob-Realm", "^H|Thrall Frostwolf$"), "ping: antwoord per whisper")

local function Packet(seq, withError)
  E("CHAT_MSG_ADDON", "CFBStats", "S|" .. seq .. "|id=abc123|v=1.12.0|c=16001|l=enUS|lang=en|s=2026-11-21|d=2|li=3|o=7|m=50|ma=1|ch=2", "WHISPER", "Bob-Realm")
  if withError then E("CHAT_MSG_ADDON", "CFBStats", "E|" .. seq .. "|2|Loot.lua:10: a|b", "WHISPER", "Bob-Realm") end
  E("CHAT_MSG_ADDON", "CFBStats", "X|" .. seq .. "|1", "WHISPER", "Bob-Realm")
end
Packet("111", true)
local r = CarefreeBagDB.collected and CarefreeBagDB.collected.abc123
check(r and r.opens == 7 and r.logins == 3 and r.minutes == 50 and r.mails == 1 and r.days == 2, "pakketje bewaard")
check(r.version == "1.12.0" and r.name == "Bob-Realm" and r.chars == 2, "versie, afzender, karakters")
check(r.errors["Loot.lua:10: a|b"] == 2, "fout bewaard (ook met | erin)")
check(Find("WHISPER", "Bob-Realm", "^A|111$"), "bevestigd")

-- Dubbel (ons A kwam niet aan): opnieuw bevestigen, niet dubbel tellen
ADDONMSG = {}
Packet("111", true)
check(r.opens == 7, "dubbel pakketje niet dubbel geteld")
check(Find("WHISPER", "Bob-Realm", "^A|111$"), "dubbel: wel weer bevestigd")

-- Onvolledig (E ontbreekt): niet bewaren, niet bevestigen
ADDONMSG = {}
Packet("222", false)
check(r.opens == 7 and not Find("WHISPER", "Bob-Realm", "^A|222$"), "onvolledig: niet bewaard en niet bevestigd")

-- Rapport
SlashCmdList.CAREFREEBAG("stats")
local said = false
for _, l in ipairs(LOG) do if l:find("Usage stats: 1 players") then said = true end end
check(said, "/cfb stats toont het rapport")

SlashCmdList.CAREFREEBAG(""); RunTimers()
check(CarefreeBagConfig.statsCb == nil, "maker: geen vinkje in de opties")
check(CarefreeBagDB.lastError == nil, "geen fout: " .. tostring(CarefreeBagDB.lastError))
