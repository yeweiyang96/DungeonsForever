local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end

local gns = _G.DF_NS

local DS = {}
local boundRoot = nil
local overrideLocale = nil
local cacheRoot = nil
local campByProfCache = nil
local campByStationCache = nil
local campStationsByProfCache = nil
local writByItemCache = nil
local writByTargetCache = nil

local _roMt = {
  __newindex = function() error("DungeonsForeverProf: static data table is read-only", 2) end,
  __metatable = false,
}
local function newReadOnlyEmpty()
  return setmetatable({}, _roMt)
end

local function syncBridge(root)
  if type(gns) ~= "table" or gns == ns then return end
  gns.ProfDataStore = DS
  if type(root) == "table" then
    if gns.Data == nil then gns.Data = root end
    if gns.Ensure == nil and type(ns.Ensure) == "function" then gns.Ensure = ns.Ensure end
    if gns.EnsureRecipes == nil and type(ns.EnsureRecipes) == "function" then gns.EnsureRecipes = ns.EnsureRecipes end
  end
end

local function resetCaches(root)
  cacheRoot = root
  campByProfCache = nil
  campByStationCache = nil
  campStationsByProfCache = nil
  writByItemCache = nil
  writByTargetCache = nil
end

local function getRoot()
  local root = boundRoot or ns.Data or (type(gns) == "table" and gns.Data) or nil
  if root ~= cacheRoot then
    resetCaches(root)
  end
  syncBridge(root)
  return root
end

function DS.Init(dataRoot)
  if dataRoot ~= nil and type(dataRoot) ~= "table" then
    return false, "invalid_data_root"
  end
  local root = dataRoot or ns.Data or (type(gns) == "table" and gns.Data) or nil
  if type(root) ~= "table" then
    return false, "missing_data_root"
  end
  local meta = root.meta
  if type(meta) ~= "table" or meta.contractVersion ~= 1 then
    return false, "unsupported_contract_version"
  end
  boundRoot = dataRoot
  resetCaches(root)
  syncBridge(root)
  return true
end

function DS.Meta()
  local root = getRoot()
  return root and root.meta or nil
end

function DS.ContractVersion()
  local meta = DS.Meta()
  return meta and meta.contractVersion or nil
end

function DS.Build()
  local meta = DS.Meta()
  return meta and meta.foreverBuild or nil
end

function DS.Fingerprint()
  local meta = DS.Meta()
  return meta and meta.fingerprint or nil
end

function DS.Ensure(domain)
  if type(domain) ~= "string" then return nil end
  local root = getRoot()
  if type(root) ~= "table" then return nil end
  local existing = root[domain]
  if type(existing) == "table" then return existing end
  if type(root._loaders) == "table" and type(root._loaders[domain]) ~= "function" then
    return nil
  end
  if type(root.Ensure) == "function" then
    return root.Ensure(domain)
  end
  return nil
end

DS.EnsureDomain = DS.Ensure

function DS.EnsureRecipes(slug)
  if type(slug) ~= "string" then return nil end
  local root = getRoot()
  if type(root) ~= "table" then return nil end
  local existing = type(root.recipes) == "table" and root.recipes[slug] or nil
  if type(existing) == "table" then return existing end
  if type(root._recipeLoaders) == "table" and type(root._recipeLoaders[slug]) ~= "function" then
    return nil
  end
  if type(root.EnsureRecipes) == "function" then
    return root.EnsureRecipes(slug)
  end
  return nil
end

function DS.SetLocale(loc)
  if loc == nil or type(loc) == "string" then
    overrideLocale = loc
  end
end

function DS.GetLocale()
  if type(overrideLocale) == "string" and overrideLocale ~= "" then
    return overrideLocale
  end
  local b = ns.ProfHostBridge or (type(gns) == "table" and gns.ProfHostBridge) or nil
  if b and type(b.Locale) == "function" then
    return b.Locale()
  end
  if type(_G.GetLocale) == "function" then
    local ok, loc = pcall(_G.GetLocale)
    if ok and type(loc) == "string" and loc ~= "" then return loc end
  end
  return "enUS"
end

local function extractField(val, field)
  if val == nil then return nil end
  if type(val) == "string" then
    if field == nil or field == "name" then
      return val ~= "" and val or nil
    end
    return nil
  end
  if type(val) == "table" then
    local k = field or "name"
    local s = val[k]
    if type(s) == "string" and s ~= "" then return s end
    if field == nil and type(val.name) == "string" and val.name ~= "" then
      return val.name
    end
  end
  return nil
end

function DS.TextEntry(domain, key)
  if type(domain) ~= "string" or key == nil then return nil end
  local root = getRoot()
  local locales = root and root.locales
  if type(locales) ~= "table" then return nil end
  local loc = DS.GetLocale()
  local dt = type(locales[loc]) == "table" and locales[loc][domain] or nil
  local v = type(dt) == "table" and dt[key] or nil
  if v ~= nil then return v end
  if loc ~= "enUS" then
    local edt = type(locales.enUS) == "table" and locales.enUS[domain] or nil
    v = type(edt) == "table" and edt[key] or nil
    if v ~= nil then return v end
  end
  return nil
end

function DS.RawText(domain, key, field)
  if type(domain) ~= "string" or key == nil then return nil end
  local root = getRoot()
  local locales = root and root.locales
  if type(locales) ~= "table" then return nil end
  local loc = DS.GetLocale()
  local dt = type(locales[loc]) == "table" and locales[loc][domain] or nil
  local s = extractField(type(dt) == "table" and dt[key] or nil, field)
  if s ~= nil then return s end
  if loc ~= "enUS" then
    local edt = type(locales.enUS) == "table" and locales.enUS[domain] or nil
    s = extractField(type(edt) == "table" and edt[key] or nil, field)
    if s ~= nil then return s end
  end
  return nil
end

function DS.Text(domain, key, field)
  local s = DS.RawText(domain, key, field)
  if s ~= nil then return s end
  if field == nil or field == "name" then
    if type(key) == "number" then
      return "#" .. tostring(key)
    end
    if key ~= nil then
      return tostring(key)
    end
  end
  return nil
end

function DS.ItemName(id) return DS.Text("item", id) end
function DS.SpellName(id) return DS.Text("spell", id) end
function DS.NpcName(id) return DS.Text("npc", id) end
function DS.NpcTag(id) return DS.RawText("npc_tag", id) end
function DS.NpcClassification(id) return DS.RawText("npc_classification", id) end
function DS.ObjectName(id) return DS.Text("object", id) end
function DS.ZoneName(id) return DS.Text("zone", id) end
function DS.QuestName(id) return DS.Text("quest", id) end
function DS.FactionName(id) return DS.Text("faction", id) end
function DS.CurrencyName(id) return DS.Text("currency", id) end
function DS.ProfessionName(slug) return DS.Text("profession", slug) end
function DS.CategoryName(key) return DS.Text("category", key) end
function DS.PerkText(key, field) return DS.Text("perk", key, field) end
function DS.CampText(key, field) return DS.Text("camp", key, field) end
function DS.GuideText(key, field) return DS.Text("guide", key, field) end
function DS.CondText(textKey) return DS.Text("cond", textKey) end

function DS.Professions()
  local root = getRoot()
  return root and root.professions or newReadOnlyEmpty()
end

function DS.Profession(slug)
  if type(slug) ~= "string" then return nil end
  return DS.Professions()[slug]
end

function DS.SkillLines()
  local root = getRoot()
  return root and root.skillLines or newReadOnlyEmpty()
end

function DS.SkillLine(skillLineID)
  if type(skillLineID) ~= "number" then return nil end
  return DS.SkillLines()[skillLineID]
end

function DS.SkillLineToSlug(skillLineID)
  if type(skillLineID) ~= "number" then return nil end
  local row = DS.SkillLines()[skillLineID]
  if type(row) == "table" and type(row.profession) == "string" then
    return row.profession
  end
  local cfg = ns.ProfessionsConfig or (type(gns) == "table" and gns.ProfessionsConfig)
  if type(cfg) == "table" and type(cfg.SKILL_LINE_TO_SLUG) == "table" then
    return cfg.SKILL_LINE_TO_SLUG[skillLineID]
  end
  return nil
end

function DS.CraftIndex(itemID)
  if type(itemID) ~= "number" then return nil end
  local root = getRoot()
  local idx = root and root.craftIndex
  return type(idx) == "table" and idx[itemID] or nil
end

function DS.RecipeProfession(spellID)
  if type(spellID) ~= "number" then return nil end
  local root = getRoot()
  local map = root and root.recipeProfession
  return type(map) == "table" and map[spellID] or nil
end

function DS.RecipeProfessions()
  local root = getRoot()
  return (root and root.recipeProfessions) or newReadOnlyEmpty()
end

function DS.Recipes(slug)
  return DS.EnsureRecipes(slug)
end

function DS.Recipe(spellID)
  local slug = DS.RecipeProfession(spellID)
  if not slug then return nil end
  local bucket = DS.EnsureRecipes(slug)
  return type(bucket) == "table" and type(bucket.recipes) == "table" and bucket.recipes[spellID] or nil
end

function DS.CatalogEntries(slug)
  local bucket = DS.EnsureRecipes(slug)
  return type(bucket) == "table" and bucket.catalogEntries or newReadOnlyEmpty()
end

function DS.CatalogEntry(entryKey)
  if type(entryKey) ~= "string" then return nil end
  for _, slug in ipairs(DS.RecipeProfessions()) do
    local entries = DS.CatalogEntries(slug)
    if entries[entryKey] ~= nil then
      return entries[entryKey]
    end
  end
  return nil
end

local function entities()
  return DS.Ensure("entities") or newReadOnlyEmpty()
end

function DS.Item(itemID)
  if type(itemID) ~= "number" then return nil end
  local t = entities().items
  return type(t) == "table" and t[itemID] or nil
end

function DS.Currency(currencyID)
  if type(currencyID) ~= "number" then return nil end
  local t = entities().currencies
  return type(t) == "table" and t[currencyID] or nil
end

function DS.Zone(areaID)
  if type(areaID) ~= "number" then return nil end
  local t = entities().zones
  return type(t) == "table" and t[areaID] or nil
end

function DS.Npc(npcID)
  if type(npcID) ~= "number" then return nil end
  local t = entities().npcs
  return type(t) == "table" and t[npcID] or nil
end

function DS.Object(objectID)
  if type(objectID) ~= "number" then return nil end
  local t = entities().objects
  return type(t) == "table" and t[objectID] or nil
end

function DS.Quest(questID)
  if type(questID) ~= "number" then return nil end
  local t = entities().quests
  return type(t) == "table" and t[questID] or nil
end

function DS.Faction(factionID)
  if type(factionID) ~= "number" then return nil end
  local t = entities().factions
  return type(t) == "table" and t[factionID] or nil
end

local function systems()
  return DS.Ensure("systems") or newReadOnlyEmpty()
end

function DS.Ranks(slug)
  if type(slug) ~= "string" then return newReadOnlyEmpty() end
  local t = systems().ranks
  return (type(t) == "table" and t[slug]) or newReadOnlyEmpty()
end

function DS.Specializations()
  return systems().specializations or newReadOnlyEmpty()
end

function DS.Specialization(abilitySpellID)
  if type(abilitySpellID) ~= "number" then return nil end
  return DS.Specializations()[abilitySpellID]
end

function DS.Tools()
  return systems().tools or newReadOnlyEmpty()
end

function DS.Tool(itemID)
  if type(itemID) ~= "number" then return nil end
  return DS.Tools()[itemID]
end

function DS.Essences()
  return systems().essences or newReadOnlyEmpty()
end

function DS.Essence(inputItemID)
  if type(inputItemID) ~= "number" then return nil end
  return DS.Essences()[inputItemID]
end

function DS.CampObjects()
  return systems().camping or newReadOnlyEmpty()
end

function DS.CampObject(campKey)
  if type(campKey) ~= "string" then return nil end
  return DS.CampObjects()[campKey]
end

function DS.CampObjectsByProfession(slug)
  if type(slug) ~= "string" then return newReadOnlyEmpty() end
  if not campByProfCache then
    local idx = {}
    for _, obj in pairs(DS.CampObjects()) do
      if type(obj) == "table" and type(obj.profession) == "string" then
        local list = idx[obj.profession]
        if not list then
          list = {}
          idx[obj.profession] = list
        end
        list[#list + 1] = obj
      end
    end
    for _, list in pairs(idx) do
      table.sort(list, function(a, b)
        local ta, tb = a.tier or 0, b.tier or 0
        if ta ~= tb then return ta < tb end
        local ra, rb = a.reqSkill or 0, b.reqSkill or 0
        if ra ~= rb then return ra < rb end
        return tostring(a.campKey) < tostring(b.campKey)
      end)
      setmetatable(list, _roMt)
    end
    campByProfCache = idx
  end
  local list = campByProfCache[slug]
  if type(list) ~= "table" then return newReadOnlyEmpty() end
  local copy = {}
  for i = 1, #list do
    copy[i] = list[i]
  end
  return setmetatable(copy, _roMt)
end

local function ensureCampStationCaches()
  if campByStationCache and campStationsByProfCache then return end
  local bySt = { ["*"] = {} }
  local byProf = {}
  local function better(a, b)
    if not b then return true end
    local ta, tb = a.tier or 99, b.tier or 99
    if ta ~= tb then return ta < tb end
    local ra, rb = a.reqSkill or 9999, b.reqSkill or 9999
    if ra ~= rb then return ra < rb end
    return tostring(a.campKey) < tostring(b.campKey)
  end
  for _, obj in pairs(DS.CampObjects()) do
    if type(obj) == "table" and type(obj.stationKey) == "string" and obj.stationKey ~= "" then
      local sk = obj.stationKey
      if better(obj, bySt["*"][sk]) then
        bySt["*"][sk] = obj
      end
      if type(obj.profession) == "string" and obj.profession ~= "" then
        local pm = bySt[obj.profession]
        if not pm then
          pm = {}
          bySt[obj.profession] = pm
        end
        if better(obj, pm[sk]) then
          pm[sk] = obj
        end
      end
    end
  end
  for slug, pm in pairs(bySt) do
    if slug ~= "*" then
      local list = {}
      for _, obj in pairs(pm) do
        list[#list + 1] = obj
      end
      table.sort(list, function(a, b)
        local ta, tb = a.tier or 0, b.tier or 0
        if ta ~= tb then return ta < tb end
        local ra, rb = a.reqSkill or 0, b.reqSkill or 0
        if ra ~= rb then return ra < rb end
        return tostring(a.stationKey) < tostring(b.stationKey)
      end)
      setmetatable(list, _roMt)
      byProf[slug] = list
    end
  end
  campByStationCache = bySt
  campStationsByProfCache = byProf
end

function DS.CampByStation(stationKey, slug)
  if type(stationKey) ~= "string" or stationKey == "" then return nil end
  getRoot()
  ensureCampStationCaches()
  if type(slug) == "string" and slug ~= "" then
    local pm = campByStationCache[slug]
    if pm and pm[stationKey] then return pm[stationKey] end
  end
  return campByStationCache["*"][stationKey]
end

function DS.CampStationsByProfession(slug)
  if type(slug) ~= "string" or slug == "" then return newReadOnlyEmpty() end
  getRoot()
  ensureCampStationCaches()
  local list = campStationsByProfCache[slug]
  if type(list) ~= "table" then return newReadOnlyEmpty() end
  local copy = {}
  for i = 1, #list do
    copy[i] = list[i]
  end
  return setmetatable(copy, _roMt)
end

function DS.LegacyPerks()
  return systems().legacyPerks or newReadOnlyEmpty()
end

function DS.LegacyPerk(perkKey)
  if type(perkKey) ~= "string" then return nil end
  return DS.LegacyPerks()[perkKey]
end

function DS.Certification(slug)
  if type(slug) ~= "string" then return nil end
  local t = systems().certifications
  return type(t) == "table" and t[slug] or nil
end

function DS.Comprehension()
  return systems().comprehension
end

local function commerce()
  return DS.Ensure("commerce") or newReadOnlyEmpty()
end

function DS.Crates()
  return commerce().crates or newReadOnlyEmpty()
end

function DS.Crate(itemID)
  if type(itemID) ~= "number" then return nil end
  return DS.Crates()[itemID]
end

function DS.Writs()
  return commerce().writs or newReadOnlyEmpty()
end

function DS.Writ(questID)
  if type(questID) ~= "number" then return nil end
  return DS.Writs()[questID]
end

local function ensureWritCaches()
  if writByItemCache and writByTargetCache then return end
  local byItem, byTarget = {}, {}
  for _, w in pairs(DS.Writs()) do
    if type(w) == "table" then
      if type(w.writItemID) == "number" and not byItem[w.writItemID] then
        byItem[w.writItemID] = w
      end
      if type(w.targetItemID) == "number" and not byTarget[w.targetItemID] then
        byTarget[w.targetItemID] = w
      end
    end
  end
  writByItemCache = byItem
  writByTargetCache = byTarget
end

function DS.WritByItem(itemID)
  if type(itemID) ~= "number" then return nil end
  ensureWritCaches()
  return writByItemCache[itemID]
end

function DS.WritByTarget(itemID)
  if type(itemID) ~= "number" then return nil end
  ensureWritCaches()
  return writByTargetCache[itemID]
end

function DS.PlunderGoods()
  return commerce().plunder or newReadOnlyEmpty()
end

function DS.Plunder(itemID)
  if type(itemID) ~= "number" then return nil end
  return DS.PlunderGoods()[itemID]
end

local MARKET_CODE_ALIASES = {
  ["cn/pvp-horde"] = "cn/pvp-horde",
  ["cn/pvp-alliance"] = "cn/pvp-alliance",
  ["cn/pve-horde"] = "cn/pve-horde",
  ["cn/pve-alliance"] = "cn/pve-alliance",
  ["rules:1:forever:5:100:Horde"] = "cn/pvp-horde",
  ["rules:1:forever:5:100:Alliance"] = "cn/pvp-alliance",
  ["rules:1:forever:5:000:Horde"] = "cn/pve-horde",
  ["rules:1:forever:5:000:Alliance"] = "cn/pve-alliance",
}

function DS.NormalizeMarketCode(marketKeyOrCode)
  if type(marketKeyOrCode) ~= "string" or marketKeyOrCode == "" then return nil end
  local direct = MARKET_CODE_ALIASES[marketKeyOrCode]
  if direct then return direct end
  local bits, side = marketKeyOrCode:match("^rules:%d+:[^:]*:%d+:(%d%d%d):(%a+)$")
  if bits and side then
    local isPvp = bits:sub(1, 1) == "1"
    local f = (side == "Horde" and "horde") or (side == "Alliance" and "alliance") or nil
    if f then
      return "cn/" .. (isPvp and "pvp-" or "pve-") .. f
    end
  end
  return nil
end

local function marketWatchlistDomain()
  return DS.Ensure("marketWatchlist") or nil
end

function DS.MarketWatchlistMeta()
  local mw = marketWatchlistDomain()
  if type(mw) == "table" and type(mw.markets) == "table" then
    return mw
  end
  return {
    schemaVersion = 1,
    windowDays = 7,
    updatedAt = nil,
    markets = commerce().marketWatchlist or newReadOnlyEmpty(),
  }
end

function DS.MarketWatchlistUpdatedAt()
  local mw = marketWatchlistDomain()
  if type(mw) == "table" and type(mw.updatedAt) == "string" and mw.updatedAt ~= "" then
    return mw.updatedAt
  end
  return nil
end

function DS.MarketWatchlists()
  local mw = marketWatchlistDomain()
  if type(mw) == "table" and type(mw.markets) == "table" then
    for _, items in pairs(mw.markets) do
      if type(items) == "table" and next(items) ~= nil then
        return mw.markets
      end
    end
    local legacy = commerce().marketWatchlist
    if type(legacy) == "table" then
      for _, items in pairs(legacy) do
        if type(items) == "table" and next(items) ~= nil then
          return legacy
        end
      end
    end
    return mw.markets
  end
  return commerce().marketWatchlist or newReadOnlyEmpty()
end

function DS.MarketWatchlist(marketKeyOrCode)
  local code = DS.NormalizeMarketCode(marketKeyOrCode) or marketKeyOrCode
  if type(code) ~= "string" or code == "" then return newReadOnlyEmpty() end
  local t = DS.MarketWatchlists()
  return (type(t) == "table" and t[code]) or newReadOnlyEmpty()
end

function DS.MarketEasySellEntry(itemID, marketKeyOrCode)
  if type(itemID) ~= "number" or itemID <= 0 then return nil end
  local wl = DS.MarketWatchlist(marketKeyOrCode)
  if type(wl) ~= "table" then return nil end
  local entry = wl[itemID]
  if entry == nil or entry == false then return nil end
  if type(entry) == "table" then return entry end
  return { status = "recommended" }
end

function DS.IsMarketEasySell(itemID, marketKeyOrCode)
  return DS.MarketEasySellEntry(itemID, marketKeyOrCode) ~= nil
end

local function sources()
  return DS.Ensure("sources") or newReadOnlyEmpty()
end

function DS.LearningRoutes(spellID)
  if type(spellID) ~= "number" then return nil end
  local t = sources().learningRoutes
  return type(t) == "table" and t[spellID] or nil
end

function DS.VendorOffers(itemID)
  if type(itemID) ~= "number" then return nil end
  local t = sources().vendorOffers
  return type(t) == "table" and t[itemID] or nil
end

function DS.Drops(itemID)
  if type(itemID) ~= "number" then return newReadOnlyEmpty() end
  local t = sources().drops
  return (type(t) == "table" and t[itemID]) or newReadOnlyEmpty()
end

function DS.ExtraSources(itemID)
  if type(itemID) ~= "number" then return newReadOnlyEmpty() end
  local t = sources().extraSources
  return (type(t) == "table" and t[itemID]) or newReadOnlyEmpty()
end

local function guides()
  return DS.Ensure("guides") or newReadOnlyEmpty()
end

function DS.GatheringGuide(slug)
  if type(slug) ~= "string" then return nil end
  local t = guides().gatheringGuides
  return type(t) == "table" and t[slug] or nil
end

function DS.FishingGuide()
  return guides().fishingGuides
end

function DS.LevelingGuides()
  return guides().levelingGuides or newReadOnlyEmpty()
end

function DS.LevelingGuide(slug)
  if type(slug) ~= "string" then return nil end
  local t = guides().levelingGuides
  return type(t) == "table" and t[slug] or nil
end

ns.ProfDataStore = DS
syncBridge(getRoot())
