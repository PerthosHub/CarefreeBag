-- Een update mag je instellingen nooit resetten (Johans afspraak, 2026-11-21).
-- Aanleiding: op Forever gaf GetRealmName() bij het inloggen "" terug. CarefreeBag maakte toen
-- een nieuwe sleutel "Naam-" zonder realm: groepen van het sjabloon, alles in Other en de
-- eenmalige vragen (tassenbalk) opnieuw. Deze test laadt opgeslagen gegevens zoals een speler
-- ze heeft en controleert dat alles blijft, ook als WoW geen realm geeft.
-- Nieuwe instelling of omzetting? Zet hem hieronder in SAVED en controleer hem in KeptAll.
local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end

ITEMS = {
  [4599] = { name = "Cured Ham Steak", quality = 1, stack = 20, bind = 0, icon = 3, class = 0, sub = 5, price = 10 },
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, class = 7, price = 5 },
}
BAGS[0] = { n = 6, [1] = { itemID = 4599, count = 5 }, [2] = { itemID = 2589, count = 5 } }
REALM = "Some Realm 1 PvE"
rawset(_G, "GetRealmName", function() return REALM end)
local ME = "Thrall Frostwolf-Some Realm 1 PvE"
local ALT = "Thrall Stormrage-Some Realm 1 PvE"

-- Opgeslagen gegevens van een speler die CFB al een tijd gebruikt (vorige versie).
local function SAVED()
  return {
    lang = "nl", enabled = true, lastVersion = "1.10.1", autoSell = true, autoSellAsked = true,
    mailAlwaysAuto = false, keysOffDone = true, showSort = true, maxCols = 10, autoBags = false,
    bagFill = true, lootPanel = false, fixedOn = { boe = false, quest = true, keys = true, grey = true },
    cats = { { key = "consum", preset = "consum" }, { key = "prof", preset = "prof" }, { key = "gear", preset = "gear" } },
    chars = {
      [ME] = {
        assign = { [2589] = "drinks", [4599] = "drinks" }, hidden = { [1234] = true }, seen = {}, manual = {},
        cats = { { key = "drinks", name = "Drinks" }, { key = "craft", name = "Craft", mailTo = "Thrall Stormrage" } },
        order = { "drinks", "craft", "quest", "other" }, collapsed = { craft = true },
        hideBagSlots = true, keep = { [4599] = true }, panelSide = "left",
        snap = { name = "Thrall Frostwolf", class = "SHAMAN", bags = {}, bagsTime = 1000, bank = { { id = 2589, n = 20 } }, bankTime = 900 },
      },
      [ALT] = { assign = {}, cats = {}, snap = { name = "Thrall Stormrage", bags = {}, bagsTime = 500 } },
    },
  }
end

local function Load()
  local NS = {}; CFB_NS = NS
  POPUPS = {}
  LoadAddon(NS)
  DRIVER:Fire("OnEvent", "ADDON_LOADED", "CarefreeBag"); DRIVER:Fire("OnEvent", "PLAYER_LOGIN"); RunTimers()
  return NS
end
local function keys() local n = {}; for k in pairs(CarefreeBagDB.chars) do n[#n+1] = k end table.sort(n); return table.concat(n, " | ") end
local function asked(which) for _, p in ipairs(POPUPS) do if p.which == which then return true end end end

local function KeptAll(NS, label)
  local db = CarefreeBagDB
  check(NS.charKey == ME, label .. ": eigen sleutel met realm: " .. tostring(NS.charKey))
  check(not db.chars["Thrall Frostwolf-"], label .. ": geen nieuwe sleutel zonder realm (" .. keys() .. ")")
  local ch = db.chars[ME]
  check(ch.assign[2589] == "drinks" and ch.assign[4599] == "drinks", label .. ": geleerde items blijven in hun groep")
  check(#ch.cats == 2 and ch.cats[1].key == "drinks" and ch.cats[2].mailTo == "Thrall Stormrage", label .. ": eigen groepen + mail blijven")
  check(ch.order[1] == "drinks" and ch.collapsed.craft, label .. ": volgorde en ingeklapt blijven")
  check(ch.hidden[1234] and ch.keep[4599] and ch.panelSide == "left", label .. ": verborgen/bewaard/paneelkant blijven")
  check(ch.hideBagSlots == true and not asked("CAREFREEBAG_BAGBAR"), label .. ": tassenbalk-vraag niet opnieuw")
  check(#ch.snap.bank == 1, label .. ": onthouden bank blijft")
  check(db.lang == "nl" and db.autoSell == true and db.autoSellAsked == true and db.mailAlwaysAuto == false, label .. ": taal en Auto Sell blijven")
  check(db.showSort == true and db.maxCols == 10 and db.autoBags == false and db.lootPanel == false, label .. ": opties blijven")
  check(db.fixedOn.boe == false and db.fixedOn.keys == true, label .. ": vaste groepen aan/uit blijven")
  check(db.chars[ALT] and db.chars[ALT].snap.name == "Thrall Stormrage", label .. ": ander karakter blijft")
  local sec = NS.SectionOf({ itemID = 2589, classID = 7, subclassID = 0, quality = 1 })
  check(sec == "drinks", label .. ": Linen Cloth staat in Drinks, niet in Other: " .. tostring(sec))
end

-- 1. Gewone update, WoW geeft de realm
CarefreeBagDB = SAVED()
KeptAll(Load(), "update")
check(CarefreeBagDB.lastRealm == REALM, "realm onthouden")
check(CarefreeBagDB.lastVersion ~= "1.10.1", "versie bijgewerkt")

-- 2. Volgende login: WoW geeft geen realm (zo ging het mis op 2026-11-21)
REALM = ""
KeptAll(Load(), "geen realm")

-- 3. Geen realm en nog geen lastRealm (gegevens van vóór deze fix): eigen sleutel teruggevonden
CarefreeBagDB = SAVED()
KeptAll(Load(), "geen realm, oude gegevens")

-- 4. Herstel: de fout is al gebeurd (sleutel "Naam-" met sjabloongroepen en een nieuwere snapshot)
CarefreeBagDB = SAVED()
CarefreeBagDB.chars["Thrall Frostwolf-"] = { assign = {}, cats = { { key = "consum", preset = "consum" } }, hideBagSlots = true,
  snap = { name = "Thrall Frostwolf", bags = { { id = 4599, n = 5 } }, bagsTime = 2000 } }
REALM = "Some Realm 1 PvE"
local NS = Load()
KeptAll(NS, "herstel")
check(#CarefreeBagDB.chars[ME].snap.bags >= 1 and CarefreeBagDB.chars[ME].snap.bagsTime >= 2000, "herstel: nieuwere tassen-snapshot overgenomen")
check(#CarefreeBagDB.chars[ME].snap.bank == 1, "herstel: oudere bank blijft (die stond niet onder de foute sleutel)")

-- 5. Nieuw karakter zonder realm, terwijl de realm al eens bekend was: geen sleutel zonder realm
CarefreeBagDB = SAVED(); CarefreeBagDB.lastRealm = "Some Realm 1 PvE"
CarefreeBagDB.chars[ME] = nil
REALM = ""
NS = Load()
check(NS.charKey == ME and not CarefreeBagDB.chars["Thrall Frostwolf-"], "nieuw karakter zonder realm: sleutel met de laatst bekende realm (" .. keys() .. ")")
