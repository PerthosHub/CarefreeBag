ALLFRAMES = {}
-- Nagebootste WoW-API, net genoeg om BagLab te laden en te bedienen.
MISSING = {}
local real = {}
NOW = 100
QUEUE = {}
LOG = {}
local function log(s) LOG[#LOG+1] = s end

local Methods = {}
local Mt = { __index = function(t, k) if Methods[k] then return Methods[k] end if type(k) == "string" and k:match("^%u") then return function() return nil end end return nil end }
local function newObj(kind, name, parent)
  local o = setmetatable({ __kind = kind, scripts = {}, shown = true, w = 0, h = 0, name = name, parent = parent, text = "" }, Mt)
  return o
end
function Methods:SetScript(k, f) self.scripts[k] = f end
function Methods:GetScript(k) return self.scripts[k] end
function Methods:HookScript(k, f) local old = self.scripts[k]; self.scripts[k] = function(...) if old then old(...) end f(...) end end
function Methods:Fire(k, ...) if self.scripts[k] then return self.scripts[k](self, ...) end end
function Methods:Show() local was = self.shown; self.shown = true; if not was then self:Fire("OnShow") end end
function Methods:Hide() local was = self.shown; self.shown = false; if was then self:Fire("OnHide") end end
function Methods:IsShown() return self.shown end
function Methods:IsVisible() return self.shown end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:SetSize(w, h) self.w, self.h = w, h end
function Methods:SetWidth(w) self.w = w end
function Methods:SetHeight(h) self.h = h end
function Methods:GetWidth() return self.w end
function Methods:GetHeight() return self.h end
function Methods:GetFrameLevel() return 1 end
function Methods:CreateTexture() return newObj("Texture") end
function Methods:CreateFontString() local o = newObj("FontString"); ALLFRAMES[#ALLFRAMES+1] = o; return o end
function Methods:SetText(t) self.text = t end
function Methods:GetText() return self.text end
function Methods:GetStringHeight() local n = 1; for _ in tostring(self.text):gmatch("\n") do n = n + 1 end return n * 12 end
function Methods:SetChecked(v) self.checked = v end
function Methods:GetChecked() return self.checked end
function Methods:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
-- ankerpunten onthouden, zodat tests kunnen zien waar een venster vastzit
function Methods:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
function Methods:ClearAllPoints() self.points = {} end
function Methods:GetName() return self.name end
function Methods:SetID(i) self.id = i end
function Methods:GetID() return self.id end
function Methods:SetBagID(b) self.bagID = b end
-- zoals WoW: eigen bagID, anders de ID van het ouder-frame
function Methods:GetBagID() if self.bagID then return self.bagID end return self.parent and self.parent.id endfunction Methods:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true; if e == "ADDON_LOADED" then DRIVER = self end end
function Methods:GetCenter() return 0, 0 end
function Methods:GetEffectiveScale() return 1 end
function Methods:SetEnabled(v) self.enabled = v end
function Methods:SetParent(p) self.parent = p end
function Methods:SetMatchesSearch(v) self.matchesSearch = v end

function CreateFrame(kind, name, parent, template)
  local o = newObj(kind, name, parent)
  if template and template:find("ContainerFrameItemButtonTemplate") then o.shown = false end
  if name then _G[name] = o end
  ALLFRAMES[#ALLFRAMES+1] = o
  return o
end
UIParent = newObj("Frame", "UIParent"); Minimap = newObj("Frame", "Minimap"); Minimap.w = 140
GameTooltip = newObj("GameTooltip"); UIErrorsFrame = newObj("Frame")
UIErrorsFrame.AddMessage = function(_, m) log("ERR " .. m) end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) log("CHAT " .. m) end }
MerchantFrame = newObj("Frame", "MerchantFrame"); MerchantFrame.shown = false
MailFrame = newObj("Frame", "MailFrame"); MailFrame.shown = false
SendMailFrame = newObj("Frame", "SendMailFrame"); SendMailFrame.shown = false
SendMailNameEditBox = newObj("EditBox")
ContainerFrameCombinedBags = newObj("Frame"); ContainerFrameCombinedBags.shown = false
UISpecialFrames = {}
SlashCmdList = {}
SOUNDKIT = {}
function PlaySound() end
function tinsert(t, v) table.insert(t, v) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetTime() return NOW end
function InCombatLockdown() return COMBAT end
function UnitName() return "Thrall-Frostwolf" end
function GetMoney() return 123456 end
function GetMoneyString(m) return m .. "c" end
function GetCursorPosition() return 0, 0 end
C_Timer = { After = function(d, f) QUEUE[#QUEUE+1] = f end }
function RunTimers() for i = 1, 20 do local q = QUEUE; QUEUE = {}; if #q == 0 then return end for _, f in ipairs(q) do f() end end end
function hooksecurefunc(name, fn) local old = _G[name]; _G[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end end
function SetItemButtonTexture(b, t) b.tex = t end
function SetItemButtonCount(b, c) b.count = c end
function SetItemButtonDesaturated(b, d) b.desat = d end
function SetItemButtonQuality() end
function ClearItemButtonOverlay() end
StaticPopupDialogs = {}
POPUPS = {}
function StaticPopup_Show(w, a1) log("POPUP " .. w); POPUPS[#POPUPS+1] = { which = w, arg = a1 } end
RELOADED = 0
function ReloadUI() RELOADED = RELOADED + 1 end
DISABLED = {}
C_AddOns = { IsAddOnLoaded = function(n) return LOADED_ADDONS and LOADED_ADDONS[n] end, DisableAddOn = function(n) DISABLED[n] = true end }
function StaticPopup_Hide(w) log("POPUPHIDE " .. w) end
function MailFrameTab_OnClick(_, i) SendMailFrame.shown = (i == 2) end
ATTACHMENTS_MAX_SEND = 12

-- Tassen: BAGS[bag][slot] = { itemID, count }
BAGS = {}
ITEMS = {}  -- [id] = { name, quality, stack, bind, icon }
CURSOR = nil
LOCKS = {}
function CursorHasItem() return CURSOR ~= nil end
function GetCursorInfo() if CURSOR then return "item", CURSOR.itemID end end
function ClearCursor() CURSOR = nil end
C_Container = {}
function C_Container.GetContainerNumSlots(b) return BAGS[b] and BAGS[b].n or 0 end
function C_Container.GetContainerNumFreeSlots(b) return 0, 0 end
function C_Container.GetContainerItemInfo(b, s)
  local it = BAGS[b] and BAGS[b][s]; if not it then return nil end
  local d = ITEMS[it.itemID]
  return { itemID = it.itemID, stackCount = it.count, hasNoValue = (d.price or 0) == 0, quality = d.quality, iconFileID = d.icon, isBound = it.bound,
    hyperlink = "|cff|Hitem:" .. it.itemID .. "|h[" .. d.name .. "]|h|r",
    hasLoot = d.openable or false, -- te openen (clam, zakje)
    -- opgepakt uit de tas = vakje op slot; CURSOR.outside = van buiten de tassen (bijv. wat je aan hebt)
    isLocked = (CURSOR ~= nil and CURSOR.itemID == it.itemID and not CURSOR.outside) or false }
end
function C_Container.PickupContainerItem(b, s)
  local it = BAGS[b][s]
  if CURSOR and it and it.itemID == CURSOR.itemID then
    local max = ITEMS[it.itemID].stack
    local total = it.count + CURSOR.count
    it.count = math.min(max, total)
    CURSOR = (total > max) and { itemID = it.itemID, count = total - max } or nil
  elseif CURSOR then BAGS[b][s] = CURSOR; CURSOR = it else CURSOR = it; BAGS[b][s] = nil end
  log("PICKUP " .. b .. ":" .. s)
end
function C_Container.GetContainerItemQuestInfo(b, s) local it = BAGS[b][s]; return { isQuestItem = it and ITEMS[it.itemID].quest or false } end
ATTACHED = {}
function ClickSendMailItemButton() if CURSOR then ATTACHED[#ATTACHED+1] = CURSOR; CURSOR = nil end end
SENT = {}
function SendMail(to, subj, body) SENT[#SENT+1] = { to = to, n = #ATTACHED, subj = subj, body = body }; function C_Container.GetContainerItemQuestInfo(b, s) local it = BAGS[b][s]; return { isQuestItem = it and ITEMS[it.itemID].quest or false } end
ATTACHED = {} ; log("SENDMAIL " .. to .. " " .. subj) end
C_Item = {}
function C_Item.GetItemInfo(id) local d = ITEMS[id]; if not d then return nil end
  return d.name, nil, d.quality, nil, nil, nil, nil, d.stack, d.equip, d.icon, d.price or 0, d.class or 15, d.sub, d.bind end
function C_Item.RequestLoadItemDataByID() end

-- Menu
MENU = nil
MenuUtil = { CreateContextMenu = function(owner, gen)
  local items = {}
  local root = {}
  function root:CreateTitle(t) items[#items+1] = { kind = "title", text = t } end
  function root:CreateDivider() end
  function root:CreateCheckbox(t, get, set) items[#items+1] = { kind = "check", text = t, get = get, set = set } end
  function root:CreateRadio(t, get, set) items[#items+1] = { kind = "radio", text = t, get = get, set = set } end
  function root:CreateButton(t) local sub = setmetatable({}, { __index = root }); return sub end
  gen(owner, root); MENU = items end }

-- Blizzard-bagfuncties
function ToggleAllBags() OpenBackpack() end
function OpenBackpack() ContainerFrameCombinedBags.shown = true end
function ToggleBackpack() end
function OpenAllBags(frame) OpenBackpack() end
function CloseAllBags(frame) end

setmetatable(_G, { __index = function(t, k) MISSING[k] = true; return nil end })
OVERRIDES = {}
rawset(_G, "GetBindingKey", function(a) if a == "OPENALLBAGS" then return "B" end end)
rawset(_G, "SetOverrideBindingClick", function(owner, prio, key, btn) OVERRIDES[key] = btn end)
rawset(_G, "ClearOverrideBindings", function() OVERRIDES = {} end)
function PressKey(k) if OVERRIDES[k] then _G[OVERRIDES[k]]:Fire("OnClick", "LeftButton") else ToggleAllBags() end end

SOLD = {}
function C_Container.UseContainerItem(b, s)
  if MerchantFrame.shown then local it = BAGS[b][s]; SOLD[#SOLD+1] = it.itemID; BAGS[b][s] = nil end
end
function IsShiftKeyDown() return SHIFT end
rawset(_G, "UnitNameUnmodified", function() return "Thrall", MY_SURNAME or "Frostwolf" end)

TooltipDataProcessor = { AddTooltipPostCall = function(t, f) POSTCALL = f end }
Enum = Enum or {}
Enum.TooltipDataType = { Item = 0 }
-- Instellingen van het (enige) karakter in de test.
function CFC() local _, v = next(CarefreeBagDB.chars or {}); return v or CarefreeBagDB end
rawset(_G, "time", os.time); rawset(_G, "date", os.date)

-- Laadt de addon zoals WoW dat doet: alle bestanden uit de .toc, in volgorde, met
-- één gedeelde namespace-tabel.
function LoadAddon(NS)
  NS = NS or {}
  local toc = assert(io.open(ADDON_DIR .. "/CarefreeBag.toc")):read("*a")
  for file in toc:gmatch("[^\r\n]+") do
    if file:match("%.lua$") and not file:match("^#") then
      local src = assert(io.open(ADDON_DIR .. "/" .. file)):read("*a")
      assert(loadstring(src, file))("CarefreeBag", NS)
    end
  end
  return NS
end
