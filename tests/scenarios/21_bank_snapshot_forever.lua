-- 1.10.1: bank-snapshot zoals op Forever. Issue #16: de sleutelring is daar vak 6, en dat is ook
-- "laatste tas + 1" (de oude telling voor banktassen): sleutels stonden dan ook bij de bank.
-- Issue #17: de klasse werd nooit opgeslagen (`UnitClass and UnitClass(...)` gaf maar één waarde).
local function check(c, msg) if not c then error("MISLUKT: " .. msg, 2) end print("ok  " .. msg) end
ITEMS = {
  [2589] = { name = "Linen Cloth", quality = 1, stack = 20, bind = 0, icon = 4, class = 7, price = 5 },
  [6893] = { name = "Workshop Key", quality = 1, stack = 1, bind = 1, icon = 10, class = 13 },
  [1710] = { name = "Greater Healing Potion", quality = 1, stack = 5, bind = 0, icon = 11, class = 0, price = 125 },
}
-- Forever: rugzak + 4 tassen + reagent-tas (0..5), sleutelring = 6, bank = -1, 7 banktassen
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
KEYRING_CONTAINER = 6
NUM_BANKBAGSLOTS = 7
BANK_CONTAINER = -1
C_ActionBar = { ShouldShowKeyring = function() return true end }
BAGS[0] = { n = 16, [1] = { itemID = 2589, count = 5 } }
BAGS[6] = { n = 12, [1] = { itemID = 6893, count = 1, bound = true } }   -- sleutelring
BAGS[-1] = { n = 28, [1] = { itemID = 1710, count = 5 }, [2] = { itemID = 1710, count = 5 } }
BAGS[7] = { n = 6, [1] = { itemID = 2589, count = 3 } }                    -- eerste echte banktas
function UnitClass() return "Paladin", "PALADIN", 2 end
LOADED_ADDONS = {}
local NS = {}
LoadAddon(NS)
local function E(ev, ...) DRIVER:Fire("OnEvent", ev, ...); RunTimers() end
CarefreeBagDB = { lang = "en", autoBags = false }
E("ADDON_LOADED", "CarefreeBag"); E("PLAYER_LOGIN"); E("BAG_UPDATE_DELAYED")
local me = CarefreeBagDB.chars[NS.charKey]
check(me and me.snap, "snapshot van dit karakter bestaat")
check(me.snap.class == "PALADIN", "#17: klasse wordt opgeslagen: " .. tostring(me.snap.class))
local keyInBags
for _, r in ipairs(me.snap.bags or {}) do if r.id == 6893 then keyInBags = r.k end end
check(keyInBags, "sleutel staat bij de tassen (als sleutel)")
E("BANKFRAME_OPENED")
local ids, pots, linen = {}, 0, 0
for _, r in ipairs(me.snap.bank or {}) do
  ids[#ids + 1] = r.id
  if r.id == 1710 then pots = r.n end
  if r.id == 2589 then linen = r.n end
end
for _, id in ipairs(ids) do check(id ~= 6893, "#16: sleutel niet bij de bank") end
check(pots == 10, "bank: 10 potions: " .. pots)
check(linen == 3, "banktas na de sleutelring (vak 7) telt mee: " .. linen)
check(me.snap.bankSlots == 34, "vrije bankvakjes zonder sleutelring: " .. tostring(me.snap.bankSlots))
print("lastError:", CarefreeBagDB.lastError)
