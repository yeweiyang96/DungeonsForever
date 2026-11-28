local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local NAME = "DungeonsForeverProfDB"

local function getSolverCfg()
    return ns.SolverConfig or (type(gns) == "table" and gns.SolverConfig) or nil
end

local function getPricingCfg()
    return ns.PricingConfig or (type(gns) == "table" and gns.PricingConfig) or nil
end

local function getProfCfg()
    return ns.ProfessionsConfig or (type(gns) == "table" and gns.ProfessionsConfig) or nil
end

local solverCfg = getSolverCfg()
local pricingCfg = getPricingCfg()

local DB = {}
DB.SCHEMA_VERSION = 4
DB.LV_CAP = (type(solverCfg) == "table" and type(solverCfg.CAP) == "number" and solverCfg.CAP) or 300
DB.LV_DEF = (type(solverCfg) == "table" and type(solverCfg.DEFAULT_TARGET) == "number" and solverCfg.DEFAULT_TARGET) or 300

DB.SETTING_DEF = {
    greyPassed = true,
    hlCurrent = true,
    autoRoute = false,
    autoOnlyAH = true,
    autoUseBagMaterials = false,
    autoConsiderAuctionSupply = false,
    autoBuyLimitedFormulas = false,
    autoAllowDropFormulas = false,
    autoAllowCurrencyFormulas = false,
    autoExcludeQuestRecipes = true,
    autoExcludeQuestTrainers = true,
    autoExcludeQuestVendors = true,
    autoExcludeInstanceVendors = true,
    autoExcludeInstanceTrainers = true,
    autoScheme = "cost",
    autoSecondaryLeveling = false,
    autoRouteRiskMode = "expected",
    autoReserveMode = "safe",
    auctionRecoveryEnabled = false,
    recoveryFeePercent = (type(pricingCfg) == "table" and type(pricingCfg.DEFAULT_RECOVERY_FEE_PCT) == "number" and pricingCfg.DEFAULT_RECOVERY_FEE_PCT) or 5,
    autoCraftTools = true,
    autoFromCurrent = true,
    autoStartSkill = 1,
    writOwnProfessionsOnly = false,
    autoSnapshot = false,
}

DB.PROF_SETTING_DEF = {
    enchanting = {
        autoExcludeInstanceTrainers = false,
    },
    mining = {
        autoRoute = true,
        autoScheme = "cost",
        autoCraftTools = false,
        autoSecondaryLeveling = false,
        auctionRecoveryEnabled = false,
    },
}

DB.PROF_SETTING_KEYS = {
    autoRoute = true,
    autoScheme = true,
    autoOnlyAH = true,
    autoConsiderAuctionSupply = true,
    autoUseBagMaterials = true,
    autoBuyLimitedFormulas = true,
    autoAllowDropFormulas = true,
    autoAllowCurrencyFormulas = true,
    autoExcludeQuestRecipes = true,
    autoExcludeQuestTrainers = true,
    autoExcludeQuestVendors = true,
    autoExcludeInstanceVendors = true,
    autoExcludeInstanceTrainers = true,
    autoSecondaryLeveling = true,
    autoFromCurrent = true,
    autoStartSkill = true,
    autoCraftTools = true,
    auctionRecoveryEnabled = true,
    recoveryFeePercent = true,
    autoRouteRiskMode = true,
    autoReserveMode = true,
}

local RETIRED_SETTINGS = {
    autoLearnedOnly = true,
    autoAllowUnknownLearning = true,
    autoSkipUnpricedFormulas = true,
    autoNoFormula = true,
    autoSkillBudget = true,
    autoAllowBindOnPickupFormulas = true,
    autoResidualMass = true,
    computationSpeed = true,
}

local function normalizeScheme(scheme, recoveryOn)
    if scheme == "net" then return "net" end
    if recoveryOn == true and (scheme == nil or scheme == "cheapest" or scheme == "cost") then
        return "net"
    end
    return "cost"
end

local function ensureTable(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end
    return parent[key]
end

local function migrateLegacyFormulaBucket(bucket)
    if type(bucket) ~= "table" then return end
    if bucket.autoAllowBindOnPickupFormulas ~= nil then
        if bucket.autoAllowBindOnPickupFormulas == true then
            if bucket.autoAllowDropFormulas == nil then bucket.autoAllowDropFormulas = true end
            if bucket.autoAllowCurrencyFormulas == nil then bucket.autoAllowCurrencyFormulas = true end
            if bucket.autoExcludeQuestRecipes == nil then bucket.autoExcludeQuestRecipes = false end
        end
        bucket.autoAllowBindOnPickupFormulas = nil
    end
    if bucket.autoSkillBudget ~= nil then
        if bucket.autoRouteRiskMode == nil and bucket.autoSkillBudget == "pessimistic" then
            bucket.autoRouteRiskMode = "quantile"
        end
        if bucket.autoReserveMode == nil then
            bucket.autoReserveMode = (bucket.autoSkillBudget == "optimistic") and "expected" or "safe"
        end
        bucket.autoSkillBudget = nil
    end
    bucket.autoResidualMass = nil
    bucket.computationSpeed = nil
    if bucket.autoScheme ~= nil or bucket.recoveryEnabled ~= nil then
        bucket.autoScheme = normalizeScheme(bucket.autoScheme, bucket.recoveryEnabled)
        bucket.recoveryEnabled = nil
    end
end

local function seedProfDefaults(prof)
    if prof.target == nil then prof.target = DB.LV_DEF end
    if prof.autoSnapshot == nil then prof.autoSnapshot = false end
    if prof.engChoice == nil then prof.engChoice = "none" end
    if prof.cookingRoute == nil then prof.cookingRoute = "fishing" end
    if prof.gatherMode == nil then prof.gatherMode = "gather" end
    ensureTable(prof, "policies")
    ensureTable(prof, "lvTarget")
    local ps = ensureTable(prof, "professionSettings")
    ensureTable(prof, "routePartners")
    ensureTable(prof, "specChoices")
    ensureTable(prof, "matBan")
    ensureTable(prof, "customRecoveryRecipes")
    ensureTable(prof, "excludedRecoveryItems")
    ensureTable(prof, "writFav")
    migrateLegacyFormulaBucket(prof)
    for _, bucket in pairs(ps) do
        migrateLegacyFormulaBucket(bucket)
    end
end

local function initFresh(tbl)
    if type(tbl) ~= "table" then
        tbl = {}
    else
        for k in pairs(tbl) do
            tbl[k] = nil
        end
    end
    tbl.schemaVersion = DB.SCHEMA_VERSION
    tbl.prof = {
        target = DB.LV_DEF,
        autoSnapshot = false,
        engChoice = "none",
        policies = {},
        lvTarget = {},
        professionSettings = {},
        routePartners = {},
        specChoices = {},
        matBan = {},
        customRecoveryRecipes = {},
        excludedRecoveryItems = {},
        writFav = {},
        cookingRoute = "fishing",
        gatherMode = "gather",
    }
    tbl.chars = {}
    tbl.client = {}
    tbl.cdWatch = {}
    tbl.execution = {}
    tbl.routePlans = {}
    return tbl
end

local function ensureSchema(db)
    if type(db) ~= "table" or db.schemaVersion ~= DB.SCHEMA_VERSION then
        db = initFresh(db)
        _G[NAME] = db
    end
    local prof = ensureTable(db, "prof")
    seedProfDefaults(prof)
    ensureTable(db, "chars")
    ensureTable(db, "client")
    ensureTable(db, "cdWatch")
    ensureTable(db, "execution")
    ensureTable(db, "routePlans")
    return db
end

function DB.Get()
    return ensureSchema(_G[NAME])
end

function DB.Reset()
    local db = initFresh(_G[NAME])
    _G[NAME] = db
    seedProfDefaults(db.prof)
    return db
end

function DB.CharacterKey()
    if type(_G.UnitGUID) == "function" then
        local ok, guid = pcall(_G.UnitGUID, "player")
        if ok and type(guid) == "string" and guid ~= "" then
            return guid
        end
    end
    local name, realm
    if type(_G.UnitNameUnmodified) == "function" then
        local ok, v = pcall(_G.UnitNameUnmodified, "player")
        if ok and type(v) == "string" and v ~= "" then name = v end
    end
    if not name and type(_G.UnitName) == "function" then
        local ok, v = pcall(_G.UnitName, "player")
        if ok and type(v) == "string" and v ~= "" then name = v end
    end
    if type(_G.GetRealmName) == "function" then
        local ok, v = pcall(_G.GetRealmName)
        if ok and type(v) == "string" and v ~= "" then realm = v end
    end
    if name or realm then
        return "offline:" .. tostring(name or "?") .. "-" .. tostring(realm or "?")
    end
    return "offline:player"
end

function DB.CharacterMeta(key)
    local db = DB.Get()
    if type(key) ~= "string" or key == "" then
        key = DB.CharacterKey()
    end
    local meta = ensureTable(db.chars, key)
    meta.guid = key
    local name
    if type(_G.UnitNameUnmodified) == "function" then
        local ok, v = pcall(_G.UnitNameUnmodified, "player")
        if ok and type(v) == "string" and v ~= "" then name = v end
    end
    if not name and type(_G.UnitName) == "function" then
        local ok, v = pcall(_G.UnitName, "player")
        if ok and type(v) == "string" and v ~= "" then name = v end
    end
    if name then meta.name = name end
    if type(_G.GetRealmName) == "function" then
        local ok, v = pcall(_G.GetRealmName)
        if ok and type(v) == "string" and v ~= "" then meta.realm = v end
    end
    if type(_G.UnitClass) == "function" then
        local ok, _, classToken, classID = pcall(_G.UnitClass, "player")
        if ok then
            if type(classToken) == "string" and classToken ~= "" then meta.class = classToken end
            if type(classID) == "number" then meta.classID = classID end
        end
    end
    return meta
end

function DB.CharacterStore(domain, key)
    if type(domain) ~= "string" or domain == "" then domain = "client" end
    local db = DB.Get()
    if type(key) ~= "string" or key == "" then
        key = DB.CharacterKey()
    end
    local bucket = ensureTable(db, domain)
    local store = ensureTable(bucket, key)
    DB.CharacterMeta(key)
    return store, key
end

local function isFixedOnly(slug)
    if type(slug) ~= "string" or slug == "" then return false end
    local cfg = getProfCfg()
    local entry = type(cfg) == "table" and type(cfg.BY_SLUG) == "table" and cfg.BY_SLUG[slug]
    if type(entry) == "table" then
        return entry.fixedOnly == true
    end
    return slug == "first-aid" or slug == "poisons"
end

function DB.TargetSkill(slug)
    local prof = DB.Get().prof
    local v
    if type(slug) == "string" and slug ~= "" and type(prof.lvTarget) == "table" then
        v = tonumber(prof.lvTarget[slug])
    end
    if not v then
        v = tonumber(prof.target)
    end
    if not v or v ~= v then return DB.LV_DEF end
    return math.max(1, math.min(DB.LV_CAP, math.floor(v)))
end

function DB.SetTargetSkill(slug, value)
    if value == nil and type(slug) == "number" then
        value = slug
        slug = nil
    end
    local n = tonumber(value)
    if not n or n ~= n then return nil end
    n = math.max(1, math.min(DB.LV_CAP, math.floor(n)))
    local prof = DB.Get().prof
    if type(slug) == "string" and slug ~= "" and slug ~= "__index" then
        ensureTable(prof, "lvTarget")[slug] = n
    else
        prof.target = n
    end
    return n
end

function DB.SettingDefault(k, slug)
    if RETIRED_SETTINGS[k] then return nil end
    if k == "target" then return DB.LV_DEF end
    if k == "engChoice" then return "none" end
    if type(slug) == "string" and type(DB.PROF_SETTING_DEF) == "table" then
        local pdef = DB.PROF_SETTING_DEF[slug]
        if type(pdef) == "table" and pdef[k] ~= nil then
            return pdef[k]
        end
    end
    return DB.SETTING_DEF[k]
end

function DB.SettingRaw(k, slug)
    if RETIRED_SETTINGS[k] then return nil end
    if slug == "mining" then
        if k == "autoRoute" then return true end
        if k == "autoScheme" then return "cost" end
        if k == "recoveryEnabled" or k == "auctionRecoveryEnabled" then return false end
    end
    if k == "recoveryEnabled" then
        if isFixedOnly(slug) then return false end
        return DB.SettingRaw("autoScheme", slug) == "net"
    end
    if isFixedOnly(slug) then
        if k == "autoRoute" then return false end
        if k == "autoScheme" then return "fixed" end
    end
    local prof = DB.Get().prof
    if k == "target" then return DB.TargetSkill(slug) end
    if k == "engChoice" then
        local v = prof.engChoice
        return (v == "goblin" or v == "gnomish") and v or "none"
    end
    if k == "policies" then return ensureTable(prof, "policies") end
    local values = DB.PROF_SETTING_KEYS[k] and type(slug) == "string" and type(prof.professionSettings) == "table" and prof.professionSettings[slug]
    local v
    if type(values) == "table" then v = values[k] end
    if v == nil then v = prof[k] end
    if k == "autoScheme" then
        local recVal = type(values) == "table" and values.recoveryEnabled
        if recVal == nil then recVal = prof.recoveryEnabled end
        if v == nil then return normalizeScheme(DB.SETTING_DEF.autoScheme, recVal) end
        return normalizeScheme(v, recVal)
    end
    if v == nil then return DB.SettingDefault(k, slug) end
    return v
end

function DB.Setting(k, slug)
    return DB.SettingRaw(k, slug) and true or false
end

function DB.SetSettingRaw(k, value, slug)
    if RETIRED_SETTINGS[k] then return nil end
    if slug == "mining" then
        if k == "autoRoute" then value = true
        elseif k == "autoScheme" then value = "cost"
        elseif k == "recoveryEnabled" or k == "auctionRecoveryEnabled" then return false end
    end
    if k == "recoveryEnabled" then
        if isFixedOnly(slug) then return nil end
        local on = value and true or false
        DB.SetSettingRaw("autoScheme", on and "net" or "cost", slug)
        return on
    end
    if isFixedOnly(slug) and (k == "autoRoute" or k == "autoScheme") then return nil end
    if k == "target" then return DB.SetTargetSkill(slug, value) end
    if k == "autoScheme" then
        value = (value == "net") and "net" or "cost"
    end
    local prof = DB.Get().prof
    if DB.PROF_SETTING_KEYS[k] and type(slug) == "string" and slug ~= "" and slug ~= "__index" then
        local ps = ensureTable(prof, "professionSettings")
        local bucket = ensureTable(ps, slug)
        bucket[k] = value
        if k == "autoScheme" then bucket.recoveryEnabled = nil end
    else
        prof[k] = value
        if k == "autoScheme" then prof.recoveryEnabled = nil end
    end
    return value
end

function DB.SetSetting(k, value, slug)
    return DB.SetSettingRaw(k, value, slug)
end

function DB.AutoStartSkillOf(slug, current)
    if DB.Setting("autoFromCurrent", slug) then
        local lv = tonumber(current)
        return lv and math.max(1, math.floor(lv)) or 1
    end
    local n = tonumber(DB.SettingRaw("autoStartSkill", slug)) or 1
    if n < 1 then
        n = 1
    elseif n > DB.LV_CAP then
        n = DB.LV_CAP
    end
    return math.floor(n)
end

function DB.GetCustomRecoveryRecipes(slug)
    if type(slug) ~= "string" or slug == "" then return {} end
    local prof = DB.Get().prof
    local all = ensureTable(prof, "customRecoveryRecipes")
    local bucket = all[slug]
    if type(bucket) ~= "table" then return {} end
    local out = {}
    for k, v in pairs(bucket) do
        local sid = tonumber(k)
        if sid and sid > 0 and v == true then
            out[math.floor(sid)] = true
        end
    end
    return out
end

function DB.IsCustomRecoveryRecipe(slug, spellID)
    local sid = tonumber(spellID)
    if type(slug) ~= "string" or slug == "" or not sid or sid <= 0 then return false end
    local prof = DB.Get().prof
    local all = type(prof.customRecoveryRecipes) == "table" and prof.customRecoveryRecipes or nil
    local bucket = all and all[slug] or nil
    return type(bucket) == "table" and (bucket[math.floor(sid)] == true or bucket[tostring(math.floor(sid))] == true) or false
end

function DB.SetCustomRecoveryRecipe(slug, spellID, enabled)
    local sid = tonumber(spellID)
    if type(slug) ~= "string" or slug == "" or not sid or sid <= 0 then return false end
    sid = math.floor(sid)
    local prof = DB.Get().prof
    local all = ensureTable(prof, "customRecoveryRecipes")
    local bucket = ensureTable(all, slug)
    bucket[tostring(sid)] = nil
    if enabled then
        bucket[sid] = true
        return true
    else
        bucket[sid] = nil
        return false
    end
end

function DB.GetExcludedRecoveryItems(slug)
    if type(slug) ~= "string" or slug == "" then return {} end
    local prof = DB.Get().prof
    local all = ensureTable(prof, "excludedRecoveryItems")
    local bucket = all[slug]
    if type(bucket) ~= "table" then return {} end
    local out = {}
    for k, v in pairs(bucket) do
        local iid = tonumber(k)
        if iid and iid > 0 and v == true then
            out[math.floor(iid)] = true
        end
    end
    return out
end

function DB.IsExcludedRecoveryItem(slug, itemID)
    local iid = tonumber(itemID)
    if type(slug) ~= "string" or slug == "" or not iid or iid <= 0 then return false end
    local prof = DB.Get().prof
    local all = type(prof.excludedRecoveryItems) == "table" and prof.excludedRecoveryItems or nil
    local bucket = all and all[slug] or nil
    return type(bucket) == "table" and (bucket[math.floor(iid)] == true or bucket[tostring(math.floor(iid))] == true) or false
end

function DB.SetExcludedRecoveryItem(slug, itemID, excluded)
    local iid = tonumber(itemID)
    if type(slug) ~= "string" or slug == "" or not iid or iid <= 0 then return false end
    iid = math.floor(iid)
    local prof = DB.Get().prof
    local all = ensureTable(prof, "excludedRecoveryItems")
    local bucket = ensureTable(all, slug)
    bucket[tostring(iid)] = nil
    if excluded then
        bucket[iid] = true
        return true
    else
        bucket[iid] = nil
        return false
    end
end

function DB.ResetExcludedRecoveryItems(slug)
    if type(slug) ~= "string" or slug == "" then return false end
    local prof = DB.Get().prof
    if type(prof.excludedRecoveryItems) == "table" and type(prof.excludedRecoveryItems[slug]) == "table" and next(prof.excludedRecoveryItems[slug]) ~= nil then
        prof.excludedRecoveryItems[slug] = {}
        return true
    end
    return false
end

function DB.ClearCustomRecoveryRecipes(slug)
    if type(slug) ~= "string" or slug == "" then return false end
    local prof = DB.Get().prof
    if type(prof.customRecoveryRecipes) == "table" and type(prof.customRecoveryRecipes[slug]) == "table" and next(prof.customRecoveryRecipes[slug]) ~= nil then
        prof.customRecoveryRecipes[slug] = {}
        return true
    end
    return false
end

function DB.ResetRecoveryOverrides(slug)
    local a = DB.ClearCustomRecoveryRecipes(slug)
    local b = DB.ResetExcludedRecoveryItems(slug)
    return a or b
end

function DB.CustomRecoveryFingerprint(slug)
    local map = DB.GetCustomRecoveryRecipes(slug)
    local ids = {}
    for sid in pairs(map) do ids[#ids + 1] = sid end
    table.sort(ids)
    local parts = {}
    for i = 1, #ids do parts[i] = tostring(ids[i]) end
    local addFp = table.concat(parts, ",")

    local exMap = DB.GetExcludedRecoveryItems(slug)
    local exIds = {}
    for iid in pairs(exMap) do exIds[#exIds + 1] = iid end
    if #exIds == 0 then
        return addFp
    end
    table.sort(exIds)
    local exParts = {}
    for i = 1, #exIds do exParts[i] = tostring(exIds[i]) end
    return addFp .. "|ex:" .. table.concat(exParts, ",")
end

setmetatable(DB, {
    __call = function()
        return DB.Get()
    end,
})

ns.ProfDB = DB
ns.ProfSettings = DB
if type(gns) == "table" and gns ~= ns then
    gns.ProfDB = DB
    gns.ProfSettings = DB
end
