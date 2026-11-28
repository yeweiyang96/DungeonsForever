local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local format = string.format

local W = (type(gns) == "table" and type(gns.ProfCDWatch) == "table" and gns.ProfCDWatch)
    or (type(ns.ProfCDWatch) == "table" and ns.ProfCDWatch)
    or {}
ns.ProfCDWatch = W
if type(gns) == "table" and gns ~= ns then
    gns.ProfCDWatch = W
end

local KEEP_SEC = 45 * 86400
local MAX_ROWS = 3
local fallbackStore = nil

local function getDS()
    return ns.ProfDataStore or (type(gns) == "table" and gns.ProfDataStore) or nil
end

local function getAPI()
    return ns.ProfAPI or (type(gns) == "table" and gns.ProfAPI) or nil
end

local function getDB()
    return ns.ProfDB or (type(gns) == "table" and gns.ProfDB) or nil
end

local function getPricingCfg()
    return ns.PricingConfig or (type(gns) == "table" and gns.PricingConfig) or nil
end

local function getRouteAuto()
    return ns.ProfRouteAuto or (type(gns) == "table" and gns.ProfRouteAuto) or nil
end

local function getBridge()
    return ns.ProfHostBridge or (type(gns) == "table" and gns.ProfHostBridge) or nil
end

local function getZoneHint()
    local b = getBridge()
    return b and type(b.ZoneHint) == "function" and b.ZoneHint() or nil
end

local function getProfModule()
    return ns.ProfModule or (type(gns) == "table" and gns.ProfModule) or nil
end

local function tr(key)
    local b = getBridge()
    if b and type(b.L) == "function" then return b.L(key) end
    return key
end

local function now()
    if type(_G.time) == "function" then return _G.time() end
    if type(os) == "table" and type(os.time) == "function" then return os.time() end
    return 0
end

local function clock()
    local f = _G.GetTime
    return type(f) == "function" and f() or 0
end

local function getRootDB()
    local DB = getDB()
    if type(DB) == "function" or (type(DB) == "table" and type(getmetatable(DB)) == "table" and getmetatable(DB).__call) then
        local ok, res = pcall(DB)
        if ok and type(res) == "table" then return res end
    end
    if type(DB) == "table" and type(DB.Get) == "function" then
        local ok, res = pcall(DB.Get)
        if ok and type(res) == "table" then return res end
    end
    if not fallbackStore then
        fallbackStore = { chars = {}, cdWatch = {} }
    end
    return fallbackStore
end

local function cdWatchBucket()
    local db = getRootDB()
    if type(db.cdWatch) ~= "table" then db.cdWatch = {} end
    local cw = db.cdWatch
    if type(cw.records) ~= "table" then cw.records = {} end
    if type(cw.list) ~= "table" then cw.list = {} end
    if type(cw.know) ~= "table" then cw.know = {} end
    if type(cw.off) ~= "table" then cw.off = {} end
    if type(cw.todoOn) ~= "table" then cw.todoOn = {} end
    if type(cw.cls) ~= "table" then cw.cls = {} end
    return cw
end

local function store()
    return cdWatchBucket().records
end

local function list()
    return cdWatchBucket().list
end

local function know()
    return cdWatchBucket().know
end

local function offs()
    return cdWatchBucket().off
end

local function todoOns()
    return cdWatchBucket().todoOn
end

local function clsMap()
    return cdWatchBucket().cls
end

local TODO_DEF = { [17187] = true, [1317279] = true }
local slugOf

local ITEM_COOLDOWNS = {
    {
        spell = 19566,          -- 筛盐器 (Salt Shaker use spell)
        slug = "leatherworking",
        skillLineID = 165,      -- Leatherworking
        reqSkill = 250,
        useItemID = 15846,      -- 筛盐器 (Salt Shaker)
        outputItemID = 15409,   -- 精炼石中盐 (Refined Deeprock Salt)
        reagents = { { 8150, 1 } }, -- 石中盐 (Deeprock Salt)
    },
}
local ITEM_CD_BY_SPELL = {}
local ITEM_CD_BY_SLUG = {}
for i = 1, #ITEM_COOLDOWNS do
    local e = ITEM_COOLDOWNS[i]
    ITEM_CD_BY_SPELL[e.spell] = e
    local bucket = ITEM_CD_BY_SLUG[e.slug]
    if not bucket then
        bucket = {}
        ITEM_CD_BY_SLUG[e.slug] = bucket
    end
    bucket[#bucket + 1] = e
end

function W.TodoOn(spell)
    local v = todoOns()[spell]
    if v ~= nil then return v == true end
    if offs()[spell] == true then return false end
    return TODO_DEF[spell] == true
end

function W.SetTodo(spell, on)
    if type(spell) ~= "number" then return false end
    on = (on == true)
    if W.TodoOn(spell) == on and todoOns()[spell] ~= nil then return false end
    local o = todoOns()
    if on then
        o[spell] = true
        local slug = slugOf(spell)
        if type(slug) == "string" and slug ~= "" then W.Mark(spell, slug) end
    else
        o[spell] = false
    end
    offs()[spell] = nil
    local pd = getProfModule()
    if pd and pd.RequestRender then pcall(pd.RequestRender) end
    local zh = getZoneHint()
    if zh and zh.RefreshSoft then pcall(zh.RefreshSoft, true) end
    return true
end

function W.Enabled(spell)
    return W.TodoOn(spell)
end

function W.SetEnabled(spell, on)
    return W.SetTodo(spell, on)
end

W.Store = store

local function hasSurname()
    if type(_G.RegionalUniqueNamesEnabled) ~= "function" then return false end
    local ok, v = pcall(_G.RegionalUniqueNamesEnabled)
    return ok and v == true
end

local function nameParts()
    local n, s2
    if type(_G.UnitNameUnmodified) == "function" then
        local ok, a, b = pcall(_G.UnitNameUnmodified, "player")
        if ok then n, s2 = a, b end
    end
    if (type(n) ~= "string" or n == "") and type(_G.UnitName) == "function" then
        local ok, a = pcall(_G.UnitName, "player")
        if ok and type(a) == "string" then n = a end
    end
    if type(s2) ~= "string" or s2 == "" then s2 = nil end
    if s2 and not hasSurname() then s2 = nil end
    return n, s2
end

function W.Name()
    local n, s2 = nameParts()
    if type(n) ~= "string" or n == "" then return "?" end
    if s2 and s2 ~= n then return n .. " " .. s2 end
    return n
end

function W.CharKey()
    local DB = getDB()
    if type(DB) == "table" and type(DB.CharacterKey) == "function" then
        return DB.CharacterKey()
    end
    if type(_G.UnitGUID) == "function" then
        local ok, guid = pcall(_G.UnitGUID, "player")
        if ok and type(guid) == "string" and guid ~= "" then
            return guid
        end
    end
    local r
    if type(_G.GetRealmName) == "function" then
        local ok, v = pcall(_G.GetRealmName)
        if ok and type(v) == "string" and v ~= "" then r = v end
    end
    local nm = W.Name()
    if nm ~= "?" or r then
        return "offline:" .. nm .. "-" .. tostring(r or "?")
    end
    return "offline:player"
end

local function charName()
    return W.Name()
end

local function charClass()
    if type(_G.UnitClass) ~= "function" then return nil end
    local ok, _, token, id = pcall(_G.UnitClass, "player")
    if not ok then return nil end
    if type(token) == "string" and token ~= "" then return token end
    if type(id) == "string" and id ~= "" then return id end
    return nil
end

local function syncCharacterMeta(key)
    local DB = getDB()
    if type(DB) == "table" and type(DB.CharacterMeta) == "function" and key == W.CharKey() then
        pcall(DB.CharacterMeta, key)
    end
end

local function clsOf(key, rec)
    if type(rec) == "table" and type(rec.cls) == "string" then return rec.cls end
    local db = getRootDB()
    if type(db.chars) == "table" and type(db.chars[key]) == "table" and type(db.chars[key].class) == "string" then
        return db.chars[key].class
    end
    local t = clsMap()
    if type(t[key]) == "string" then return t[key] end
    if key == W.CharKey() then return charClass() end
    return nil
end

local function baseCD(spell)
    local cs = _G.C_Spell
    if type(cs) == "table" and type(cs.GetSpellBaseCooldown) == "function" then
        local ok, ms = pcall(cs.GetSpellBaseCooldown, spell)
        if ok and type(ms) == "number" then return ms > 0 end
    end
    local f = _G.GetSpellBaseCooldown
    if type(f) == "function" then
        local ok, ms = pcall(f, spell)
        if ok and type(ms) == "number" then return ms > 0 end
    end
    return nil
end

local function liveItemCD(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then return nil end
    local function tryFn(fn)
        if type(fn) ~= "function" then return nil end
        local ok, st, du, en = pcall(fn, itemID)
        if ok and type(st) == "number" and type(du) == "number" and st > 0 and du > 60 and en ~= 0 then
            local left = st + du - clock()
            if left > 0 then return left, du end
        end
        return nil
    end
    local cc = _G.C_Container
    if type(cc) == "table" then
        local left, du = tryFn(cc.GetItemCooldown)
        if left then return left, du end
    end
    local ci = _G.C_Item
    if type(ci) == "table" then
        local left, du = tryFn(ci.GetItemCooldown)
        if left then return left, du end
    end
    return tryFn(_G.GetItemCooldown)
end

local function playerProfSkill(skillLineID)
    if type(skillLineID) ~= "number" or skillLineID <= 0 then return nil, false end
    local gp, gpi = _G.GetProfessions, _G.GetProfessionInfo
    if type(gp) ~= "function" or type(gpi) ~= "function" then return nil, false end
    local ok, p1, p2, p3, p4, p5, p6 = pcall(gp)
    if not ok then return nil, false end
    local slots = { p1, p2, p3, p4, p5, p6 }
    local loaded = false
    for i = 1, 6 do
        local idx = slots[i]
        if type(idx) == "number" then
            local oki, _, _, cur, _, _, _, sid = pcall(gpi, idx)
            if oki and type(sid) == "number" and sid > 0 then
                loaded = true
                if sid == skillLineID then
                    return tonumber(cur) or 0, true
                end
            end
        end
    end
    if loaded then return 0, true end
    return nil, false
end

local function liveCD(spell)
    local ic = ITEM_CD_BY_SPELL[spell]
    if ic then
        local ileft, idu = liveItemCD(ic.useItemID)
        if ileft then return ileft, idu end
    end
    local minDur = ic and 60 or 0
    local api = _G.C_Spell
    if type(api) == "table" and type(api.GetSpellCooldown) == "function" then
        local ok, sc = pcall(api.GetSpellCooldown, spell)
        if ok and type(sc) == "table" then
            local st, du = sc.startTime, sc.duration
            if type(st) == "number" and type(du) == "number" and st > 0 and du > minDur then
                local left = st + du - clock()
                if left > 0 then return left, du end
                return nil
            end
        end
    end
    local gsc = _G.GetSpellCooldown
    if type(gsc) == "function" then
        local ok, st, du = pcall(gsc, spell)
        if ok and type(st) == "number" and type(du) == "number" and st > 0 and du > minDur then
            local left = st + du - clock()
            if left > 0 then return left, du end
            return nil
        end
    end
    if not ic then
        local ct = _G.C_TradeSkillUI
        if type(ct) == "table" and type(ct.GetRecipeCooldown) == "function" then
            local ok, sec = pcall(ct.GetRecipeCooldown, spell)
            if ok and type(sec) == "number" and sec > 0 then return sec, sec end
        end
    end
    return nil
end

function W.Mark(spell, slug)
    if type(spell) ~= "number" or type(slug) ~= "string" then return false end
    local l = list()
    if l[spell] == slug then return false end
    l[spell] = slug
    return true
end

function W.UnmarkChar(spell, key)
    local k = know()
    local marks = k[key]
    if type(marks) ~= "table" then return false end
    if marks[spell] == nil then return false end
    marks[spell] = nil
    return true
end

function W.MarkChar(spell, key, nm)
    if type(spell) ~= "number" or type(key) ~= "string" or key == "" then return false end
    local k = know()
    local marks = k[key]
    if type(marks) ~= "table" then
        marks = {}
        k[key] = marks
    end
    syncCharacterMeta(key)
    local cm = clsMap()
    local c = charClass()
    if c and key == W.CharKey() then cm[key] = c end
    if marks[spell] then return false end
    marks[spell] = nm or key
    return true
end

local function recipeInfo(spell)
    local api = _G.C_TradeSkillUI
    if type(api) ~= "table" or type(api.GetRecipeInfo) ~= "function" then return nil end
    local ok, info = pcall(api.GetRecipeInfo, spell)
    if ok and type(info) == "table" then return info end
    return nil
end

local function openRecipes()
    local api = _G.C_TradeSkillUI
    if type(api) ~= "table" or type(api.GetAllRecipeIDs) ~= "function" then return nil end
    local ok, ids = pcall(api.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" or #ids == 0 then return nil end
    if type(api.IsDataSourceChanging) == "function" then
        local ok2, changing = pcall(api.IsDataSourceChanging)
        if ok2 and changing == true then return nil end
    end
    if type(api.IsTradeSkillReady) == "function" then
        local ok3, ready = pcall(api.IsTradeSkillReady)
        if ok3 and ready == false then return nil end
    end
    local set = {}
    for i = 1, #ids do
        local id = ids[i]
        if type(id) == "number" then set[id] = true end
    end
    return set
end

local function confirmedUnlearned(spell, info)
    if type(info) ~= "table" or info.learned ~= false then return false end
    if type(info.recipeID) == "number" and info.recipeID ~= spell then return false end
    local set = openRecipes()
    return set ~= nil and set[spell] == true
end

slugOf = function(spell)
    local ic = ITEM_CD_BY_SPELL[spell]
    if ic then
        W.Mark(spell, ic.slug)
        return ic.slug
    end
    local l = list()
    if type(l[spell]) == "string" then return l[spell] end
    local DS = getDS()
    if DS and type(DS.RecipeProfession) == "function" then
        local slug = DS.RecipeProfession(spell)
        if type(slug) == "string" and slug ~= "" then
            W.Mark(spell, slug)
            return slug
        end
    end
    return nil
end

local function recipeEntryDS(slug, spell)
    local DS = getDS()
    if not DS then return nil end
    if type(slug) == "string" and type(DS.Recipes) == "function" then
        local bucket = DS.Recipes(slug)
        if type(bucket) == "table" and type(bucket.recipes) == "table" and type(bucket.recipes[spell]) == "table" then
            return bucket.recipes[spell]
        end
    end
    if type(DS.Recipe) == "function" then
        return DS.Recipe(spell)
    end
    return nil
end

local function isCraftableCooldownRecipe(rec)
    if type(rec) ~= "table" then return false end
    if rec.availability ~= "live" then return false end
    if rec.categoryKey == "camping" then return false end
    if rec.outputKind == "effect" then return false end
    if type(rec.outputItemID) ~= "number" or rec.outputItemID <= 0 then return false end
    return (type(rec.cooldownSeconds) == "number" and rec.cooldownSeconds > 0)
        or (type(rec.cooldownGroup) == "string" and rec.cooldownGroup ~= "")
end

local function hasRecipeCooldown(spell, rec)
    if ITEM_CD_BY_SPELL[spell] then return true end
    if type(rec) == "table" then
        if rec.availability ~= "live" then return false end
        if rec.categoryKey == "camping" or rec.outputKind == "effect" then return false end
        if type(rec.outputItemID) ~= "number" or rec.outputItemID <= 0 then return false end
        if type(rec.cooldownSeconds) == "number" and rec.cooldownSeconds > 0 then return true end
        if type(rec.cooldownGroup) == "string" and rec.cooldownGroup ~= "" then return true end
        return baseCD(spell) == true
    end
    return baseCD(spell) == true
end

local hasCDCache = {}

function W.HasCooldownRecipes(slug)
    if type(slug) ~= "string" or slug == "" then return false end
    local cached = hasCDCache[slug]
    if cached ~= nil then return cached end
    local icList = ITEM_CD_BY_SLUG[slug]
    if type(icList) == "table" and #icList > 0 then
        hasCDCache[slug] = true
        return true
    end
    local DS = getDS()
    if not DS or type(DS.Recipes) ~= "function" then return false end
    if type(DS.RecipeProfessions) == "function" then
        local profs = DS.RecipeProfessions()
        local listed = false
        if type(profs) == "table" then
            for i = 1, #profs do
                if profs[i] == slug then listed = true; break end
            end
        end
        if not listed then
            hasCDCache[slug] = false
            return false
        end
    end
    local ok, bucket = pcall(DS.Recipes, slug)
    local recipes = ok and type(bucket) == "table" and bucket.recipes or nil
    if type(recipes) ~= "table" then
        hasCDCache[slug] = false
        return false
    end
    for _, rec in pairs(recipes) do
        if isCraftableCooldownRecipe(rec) then
            hasCDCache[slug] = true
            return true
        end
    end
    hasCDCache[slug] = false
    return false
end

function W.Record(spell, slug, left, dur)
    if type(spell) ~= "number" or type(left) ~= "number" or left <= 0 then return false end
    local d = (type(dur) == "number" and dur >= left) and dur or left
    local t0 = now()
    local db = store()
    local by = db[spell]
    if type(by) ~= "table" then
        by = {}
        db[spell] = by
    end
    local key = W.CharKey()
    syncCharacterMeta(key)
    local rec = by[key]
    if type(rec) ~= "table" then
        rec = {}
        by[key] = rec
    end
    local stop = t0 + left
    local changed = (type(rec.u) ~= "number") or (math.abs(rec.u - stop) > 3) or rec.prof ~= slug
    rec.u = stop
    rec.d = d
    rec.s = stop - d
    rec.t = t0
    rec.prof = slug
    rec.n = charName()
    local c = charClass()
    rec.cls = c or rec.cls
    if rec.cls then clsMap()[key] = rec.cls end
    return changed
end

function W.Observe(spell, slug)
    if type(spell) ~= "number" or spell <= 0 then return false end
    local ic = ITEM_CD_BY_SPELL[spell]
    if ic then
        slug = ic.slug
        local left, dur = liveCD(spell)
        if not left then return false end
        W.Mark(spell, slug)
        W.MarkChar(spell, W.CharKey(), charName())
        return W.Record(spell, slug, left, dur)
    end
    if type(slug) ~= "string" then slug = slugOf(spell) end
    if type(slug) ~= "string" then return false end
    local rds = recipeEntryDS(slug, spell)
    if type(rds) == "table" and (rds.categoryKey == "camping" or rds.outputKind == "effect"
        or type(rds.outputItemID) ~= "number" or rds.outputItemID <= 0) then
        return false
    end
    local left, dur = liveCD(spell)
    if not left then return false end
    return W.Record(spell, slug, left, dur)
end

local function scanItemCooldowns(slug)
    local entries = slug and ITEM_CD_BY_SLUG[slug] or ITEM_COOLDOWNS
    if type(entries) ~= "table" or #entries == 0 then return 0 end
    local hit = 0
    local key, nm = W.CharKey(), charName()
    for i = 1, #entries do
        local ic = entries[i]
        W.Mark(ic.spell, ic.slug)
        local rank, loaded = playerProfSkill(ic.skillLineID)
        local left, dur = liveCD(ic.spell)
        local eligible = (type(rank) == "number" and rank >= (ic.reqSkill or 1)) or (left ~= nil)
        if eligible then
            W.UnmarkChar(ic.spell, key)
            W.MarkChar(ic.spell, key, nm)
            if left and W.Record(ic.spell, ic.slug, left, dur) then hit = hit + 1 end
        elseif loaded then
            W.UnmarkChar(ic.spell, key)
            local by = store()[ic.spell]
            if type(by) == "table" then by[key] = nil end
        end
    end
    return hit
end

local function scanRows(slug)
    local hit = 0
    local DS = getDS()
    local bucket = DS and type(DS.Recipes) == "function" and DS.Recipes(slug) or nil
    local recipes = type(bucket) == "table" and bucket.recipes or nil
    if type(recipes) == "table" then
        local ids = {}
        for spell in pairs(recipes) do
            if type(spell) == "number" then ids[#ids + 1] = spell end
        end
        table.sort(ids)
        local key, nm = W.CharKey(), charName()
        for i = 1, #ids do
            local spell = ids[i]
            local rec = recipes[spell]
            if hasRecipeCooldown(spell, rec) then
                W.Mark(spell, slug)
                local info = recipeInfo(spell)
                if info and info.learned == true then
                    W.UnmarkChar(spell, key)
                    W.MarkChar(spell, key, nm)
                    local left, dur = liveCD(spell)
                    if left and W.Record(spell, slug, left, dur) then hit = hit + 1 end
                elseif confirmedUnlearned(spell, info) then
                    W.UnmarkChar(spell, key)
                    local by = store()[spell]
                    if type(by) == "table" then by[key] = nil end
                end
            end
        end
    end
    hit = hit + scanItemCooldowns(slug)
    return hit
end

local function ensureEvents()
    if W.__ef and W.__efVer == 2 then return end
    local f = W.__ef
    if not f then
        if type(_G.CreateFrame) ~= "function" then return end
        local ok, made = pcall(_G.CreateFrame, "Frame")
        if not ok or type(made) ~= "table" or type(made.RegisterEvent) ~= "function" or type(made.SetScript) ~= "function" then
            return
        end
        f = made
        W.__ef = f
    end
    W.__efVer = 2
    pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
    pcall(f.RegisterEvent, f, "SPELLS_CHANGED")
    pcall(f.RegisterEvent, f, "UNIT_SPELLCAST_SUCCEEDED")
    pcall(f.RegisterEvent, f, "TRADE_SKILL_SHOW")
    pcall(f.RegisterEvent, f, "TRADE_SKILL_UPDATE")
    pcall(f.RegisterEvent, f, "BAG_UPDATE_COOLDOWN")
    pcall(f.RegisterEvent, f, "SKILL_LINES_CHANGED")
    pcall(f.SetScript, f, "OnEvent", function(_, event, unit, _, spell)
        if event == "BAG_UPDATE_COOLDOWN" then
            local changed = false
            for i = 1, #ITEM_COOLDOWNS do
                local ic = ITEM_COOLDOWNS[i]
                if W.Observe(ic.spell, ic.slug) then changed = true end
            end
            if changed then
                local pd = getProfModule()
                if pd and pd.RequestRender then pcall(pd.RequestRender) end
                local zh = getZoneHint()
                if zh and zh.ScheduleSoft then pcall(zh.ScheduleSoft, 1) end
            end
            return
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if unit ~= "player" or type(spell) ~= "number" then return end
            local slug = slugOf(spell)
            if not slug then return end
            local function grab()
                if W.Observe(spell, slug) then
                    local pd = getProfModule()
                    if pd and pd.RequestRender then pcall(pd.RequestRender) end
                    local zh = getZoneHint()
                    if zh and zh.ScheduleSoft then pcall(zh.ScheduleSoft, 1) end
                end
            end
            local ct = _G.C_Timer
            if type(ct) == "table" and type(ct.After) == "function" then
                ct.After(0.2, grab)
            else
                grab()
            end
            return
        end
        W.__last = 0
        W.ScanAll()
    end)
end

local function allSlugs()
    local DS = getDS()
    if not DS or type(DS.RecipeProfessions) ~= "function" then return {} end
    local raw = DS.RecipeProfessions()
    local out = {}
    if type(raw) == "table" then
        for i = 1, #raw do
            if type(raw[i]) == "string" then out[#out + 1] = raw[i] end
        end
    end
    table.sort(out)
    return out
end

function W.ScanAll()
    ensureEvents()
    local list_ = allSlugs()
    local i, hits = 0, 0
    local function step()
        for _ = 1, 2 do
            i = i + 1
            local slug = list_[i]
            if not slug then break end
            hits = hits + scanRows(slug)
        end
        if i < #list_ then
            local ct = _G.C_Timer
            if type(ct) == "table" and type(ct.After) == "function" then
                ct.After(0.02, step)
            else
                step()
            end
        else
            local pd = getProfModule()
            if pd and pd.RequestRender then pcall(pd.RequestRender) end
            local zh = getZoneHint()
            if zh and zh.ScheduleSoft then pcall(zh.ScheduleSoft, 1) end
        end
    end
    if #list_ == 0 then return 0 end
    step()
    return #list_
end

function W.AutoScan(_slug)
    local t = now()
    W.__last = W.__last or 0
    if t - W.__last < 6 then return end
    W.__last = t
    W.ScanAll()
end

function W.Sweep(slug)
    if type(slug) ~= "string" then return 0 end
    return scanRows(slug)
end

function W.ScanOpen()
    ensureEvents()
    return W.ScanAll()
end

function W.Left(rec)
    if type(rec) ~= "table" or type(rec.u) ~= "number" then return nil end
    return rec.u - now()
end

local function itemName(id, spell)
    if type(id) == "number" and id > 0 then
        local api = getAPI()
        if api and type(api.ItemName) == "function" then
            local nm, known = api.ItemName(id)
            if known == true and type(nm) == "string" and nm ~= "" then
                return nm
            end
        end
        local ci = _G.C_Item
        if type(ci) == "table" and type(ci.GetItemNameByID) == "function" then
            local ok, v = pcall(ci.GetItemNameByID, id)
            if ok and type(v) == "string" and v ~= "" then return v end
        end
        if type(_G.GetItemInfo) == "function" then
            local ok, v = pcall(_G.GetItemInfo, id)
            if ok and type(v) == "string" and v ~= "" then return v end
        end
    end
    if type(spell) == "number" then
        local DS = getDS()
        if DS and type(DS.RawText) == "function" then
            local snm = DS.RawText("spell", spell)
            if type(snm) == "string" and snm ~= "" then return snm end
        end
        return format(tr("法术 #%d"), spell)
    end
    return nil
end

local function recipeName(spell, item)
    local ic = ITEM_CD_BY_SPELL[spell]
    if ic then
        local DS = getDS()
        if DS and type(DS.RawText) == "function" and type(ic.outputItemID) == "number" then
            local inm = DS.RawText("item", ic.outputItemID)
            if type(inm) == "string" and inm ~= "" then return inm end
        end
        return itemName(ic.outputItemID, spell)
    end
    if type(spell) == "number" then
        local DS = getDS()
        if DS and type(DS.RawText) == "function" then
            local snm = DS.RawText("spell", spell)
            if type(snm) == "string" and snm ~= "" then return snm end
        end
        local cs = _G.C_Spell
        if type(cs) == "table" and type(cs.GetSpellName) == "function" then
            local ok, v = pcall(cs.GetSpellName, spell)
            if ok and type(v) == "string" and v ~= "" then return v end
        end
        if type(_G.GetSpellInfo) == "function" then
            local ok, v = pcall(_G.GetSpellInfo, spell)
            if ok and type(v) == "string" and v ~= "" then return v end
        end
    end
    return itemName(item, spell)
end

local function recipeMats(rec)
    if type(rec) ~= "table" or type(rec.reagents) ~= "table" then return nil end
    local out = {}
    for i = 1, #rec.reagents do
        local rg = rec.reagents[i]
        if type(rg) == "table" and type(rg.itemID) == "number" then
            out[#out + 1] = { rg.itemID, rg.count or 1 }
        end
    end
    return out
end

local function gainOf(item, mats)
    if type(item) ~= "number" then return nil end
    local api = getAPI()
    local ra = getRouteAuto()
    local ah
    if api and type(api.AHPriceOf) == "function" then
        local ok, v = pcall(api.AHPriceOf, item)
        if ok and type(v) == "number" then ah = v end
    end
    if (type(ah) ~= "number" or ah <= 0) and ra and type(ra.AHPriceOf) == "function" then
        local ok, v = pcall(ra.AHPriceOf, item)
        if ok and type(v) == "number" then ah = v end
    end
    if type(ah) ~= "number" or ah <= 0 then return nil end
    if type(mats) ~= "table" or #mats == 0 then return nil end

    local cost
    if ra and type(ra.MatListCost) == "function" then
        local ok2, c, unpriced, n = pcall(ra.MatListCost, mats)
        if ok2 and type(c) == "number" and c > 0
            and not (type(unpriced) == "number" and type(n) == "number" and n > 0 and unpriced >= n) then
            cost = c
        end
    elseif api and type(api.EffectiveCost) == "function" then
        local sum, unpriced = 0, 0
        for i = 1, #mats do
            local m = mats[i]
            local c = api.EffectiveCost(m[1], m[2] or 1)
            if type(c) == "number" and c >= 0 then
                sum = sum + c
            else
                unpriced = unpriced + 1
            end
        end
        if sum > 0 and unpriced < #mats then cost = sum end
    end
    if type(cost) ~= "number" or cost <= 0 then return nil end

    local cfg = getPricingCfg()
    local mult = (type(cfg) == "table" and type(cfg.NET_MULTIPLIER) == "number" and cfg.NET_MULTIPLIER) or 0.95
    return math.floor(ah * mult) - cost
end

local function fmtLeft(sec)
    if type(sec) ~= "number" then return nil end
    if sec <= 0 then return tr("可再做") end
    local s = math.floor(sec)
    local d = math.floor(s / 86400)
    local h = math.floor((s % 86400) / 3600)
    local m = math.floor((s % 3600) / 60)
    if d > 0 then return format(tr("%d 天 %d 小时"), d, h) end
    if h > 0 then return format(tr("%d 小时 %d 分"), h, m) end
    if m > 0 then return format(tr("%d 分钟"), m) end
    return tr("不到 1 分钟")
end

W.FmtLeft = fmtLeft

local MAX_CARD_ROWS = 4

local function buildCharStatus(spell, slug, db, k, cur, t)
    local by = type(db[spell]) == "table" and db[spell] or {}
    local rows = {}
    for key, rec in pairs(by) do
        local marks = k[key]
        local learned = type(marks) == "table" and marks[spell] ~= nil
        if learned and type(rec) == "table" and (rec.prof == nil or rec.prof == slug) then
            if type(rec.t) == "number" and (t - rec.t) > KEEP_SEC then
                by[key] = nil
            else
                rows[#rows + 1] = {
                    key = key,
                    name = rec.n or key,
                    left = (type(rec.u) == "number") and (rec.u - t) or nil,
                    cls = clsOf(key, rec),
                }
            end
        end
    end
    for key, marks in pairs(k) do
        if type(marks) == "table" and marks[spell] and type(by[key]) ~= "table" then
            rows[#rows + 1] = {
                key = key,
                name = marks[spell],
                left = nil,
                cls = clsOf(key, nil),
            }
        end
    end
    if #rows == 0 then
        return {}, 0, nil, 0
    end
    table.sort(rows, function(a, b)
        local ac, bc = (a.key == cur), (b.key == cur)
        if ac ~= bc then return ac end
        local al, bl = (a.left or 0), (b.left or 0)
        if al ~= bl then return al < bl end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    local free, best = 0, nil
    for i = 1, #rows do
        local it = rows[i]
        if it.left == nil or it.left <= 0 then
            free = free + 1
        elseif not best or it.left < best then
            best = it.left
        end
    end
    local limit = (#rows <= MAX_CARD_ROWS) and #rows or MAX_ROWS
    local shown = {}
    local myName = W.Name()
    local myCls = nil
    for i = 1, limit do
        local it = rows[i]
        local c = it.cls
        if not c and it.name == myName then
            if not myCls then myCls = charClass() end
            c = myCls
        end
        shown[#shown + 1] = {
            key = it.key,
            name = it.name,
            text = (it.left == nil) and tr("可再做") or fmtLeft(it.left),
            free = (it.left == nil or it.left <= 0),
            cur = (it.key == cur),
            cls = c,
        }
    end
    if #rows > limit then
        shown[#shown + 1] = {
            name = format(tr("另有 %d 个角色"), #rows - limit),
            text = "",
            more = true,
        }
    end
    return shown, free, best, #rows
end

function W.Cards(slug)
    local out = {}
    if type(slug) ~= "string" then return out end
    local db = store()
    local l = list()
    local k = know()
    local cur = W.CharKey()
    local t = now()
    local spells = {}
    for spell, s in pairs(l) do
        if s == slug and W.TodoOn(spell) then spells[spell] = true end
    end
    for spell, by in pairs(db) do
        if type(by) == "table" and W.TodoOn(spell) then
            for _, rec in pairs(by) do
                if type(rec) == "table" and rec.prof == slug then
                    spells[spell] = true
                    break
                end
            end
        end
    end
    for spell in pairs(spells) do
        local rdsCheck = recipeEntryDS(slug, spell)
        if rdsCheck == nil or hasRecipeCooldown(spell, rdsCheck) then
            local shown, free, best, count = buildCharStatus(spell, slug, db, k, cur, t)
            if count > 0 then
                local ic = ITEM_CD_BY_SPELL[spell]
                local rds = (not ic) and recipeEntryDS(slug, spell) or nil
                local item = (ic and ic.outputItemID) or (rds and rds.outputItemID) or nil
                local mats = (ic and ic.reagents) or recipeMats(rds)
                out[#out + 1] = {
                    spell = spell,
                    item = item,
                    name = recipeName(spell, item),
                    mats = mats,
                    gain = gainOf(item, mats),
                    rows = shown,
                    free = free,
                    best = best,
                    count = count,
                }
            end
        end
    end
    table.sort(out, function(a, b)
        local af = (a.free or 0) > 0
        local bf = (b.free or 0) > 0
        if af ~= bf then return af end
        return (a.best or 0) < (b.best or 0)
    end)
    return out
end

function W.TodoList()
    local out = {}
    local db = store()
    local l = list()
    local k = know()
    local t = now()
    local candidates = {}
    for spell, slug in pairs(l) do
        if type(spell) == "number" and type(slug) == "string" then
            candidates[spell] = slug
        end
    end
    for _, marks in pairs(k) do
        if type(marks) == "table" then
            for spell in pairs(marks) do
                if type(spell) == "number" and candidates[spell] == nil then
                    local slug = slugOf(spell)
                    if type(slug) == "string" and slug ~= "" then
                        candidates[spell] = slug
                    end
                end
            end
        end
    end
    for spell, slug in pairs(candidates) do
        local rdsTodo = recipeEntryDS(slug, spell)
        if W.TodoOn(spell) and (rdsTodo == nil or hasRecipeCooldown(spell, rdsTodo)) then
            local by = type(db[spell]) == "table" and db[spell] or {}
            local names, byc = {}, {}
            for key, rec in pairs(by) do
                local marks = k[key]
                if type(marks) == "table" and marks[spell] and type(rec) == "table"
                    and (rec.prof == nil or rec.prof == slug) then
                    local left = (type(rec.u) == "number") and (rec.u - t) or nil
                    if left == nil or left <= 0 then
                        local nm = rec.n or key
                        names[#names + 1] = nm
                        byc[#byc + 1] = { name = nm, cls = clsOf(key, rec) }
                    end
                end
            end
            for key, marks in pairs(k) do
                if type(marks) == "table" and marks[spell] and type(by[key]) ~= "table" then
                    local nm = marks[spell]
                    names[#names + 1] = nm
                    byc[#byc + 1] = { name = nm, cls = clsOf(key, nil) }
                end
            end
            if #names > 0 then
                table.sort(names)
                table.sort(byc, function(a, b) return (a.name or "") < (b.name or "") end)
                local ic = ITEM_CD_BY_SPELL[spell]
                local rds = (not ic) and recipeEntryDS(slug, spell) or nil
                local item = (ic and ic.outputItemID) or (rds and rds.outputItemID) or nil
                out[#out + 1] = {
                    spell = spell,
                    slug = slug,
                    item = item,
                    name = recipeName(spell, item),
                    by = names,
                    byc = byc,
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.slug ~= b.slug then return a.slug < b.slug end
        return a.spell < b.spell
    end)
    return out
end

function W.Manage(slug)
    local out = {}
    if type(slug) ~= "string" then return out end
    local DS = getDS()
    local bucket = DS and type(DS.Recipes) == "function" and DS.Recipes(slug) or nil
    local recipes = type(bucket) == "table" and bucket.recipes or nil
    local l = list()
    local db = store()
    local k = know()
    local cur = W.CharKey()
    local t = now()
    local seen = {}
    if type(recipes) == "table" then
        local ids = {}
        for spell in pairs(recipes) do
            if type(spell) == "number" then ids[#ids + 1] = spell end
        end
        table.sort(ids)
        for i = 1, #ids do
            local spell = ids[i]
            local recDS = recipes[spell]
            if type(recDS) == "table" and (isCraftableCooldownRecipe(recDS)
                or (l[spell] == slug and hasRecipeCooldown(spell, recDS))) then
                seen[spell] = true
                local by = type(db[spell]) == "table" and db[spell] or {}
                local rec = by[cur]
                local left
                if type(rec) == "table" and type(rec.u) == "number" then
                    left = rec.u - t
                    if left < 0 then left = 0 end
                end
                local shown, free, best, count = buildCharStatus(spell, slug, db, k, cur, t)
                local item = recDS.outputItemID
                local todo = W.TodoOn(spell)
                out[#out + 1] = {
                    spell = spell,
                    item = item,
                    name = recipeName(spell, item),
                    on = todo,
                    todo = todo,
                    rows = shown,
                    free = free,
                    best = best,
                    count = count,
                    left = left,
                    has = (type(rec) == "table"),
                }
            end
        end
    end
    local icList = ITEM_CD_BY_SLUG[slug]
    if type(icList) == "table" then
        for i = 1, #icList do
            local ic = icList[i]
            local spell = ic.spell
            if not seen[spell] then
                seen[spell] = true
                local by = type(db[spell]) == "table" and db[spell] or {}
                local rec = by[cur]
                local left
                if type(rec) == "table" and type(rec.u) == "number" then
                    left = rec.u - t
                    if left < 0 then left = 0 end
                end
                local shown, free, best, count = buildCharStatus(spell, slug, db, k, cur, t)
                local item = ic.outputItemID
                local todo = W.TodoOn(spell)
                out[#out + 1] = {
                    spell = spell,
                    item = item,
                    useItemID = ic.useItemID,
                    name = recipeName(spell, item),
                    on = todo,
                    todo = todo,
                    rows = shown,
                    free = free,
                    best = best,
                    count = count,
                    left = left,
                    has = (type(rec) == "table"),
                }
            end
        end
    end
    table.sort(out, function(a, b)
        local ak = (a.count or 0) > 0
        local bk = (b.count or 0) > 0
        if ak ~= bk then return ak end
        if ak then
            local af = (a.free or 0) > 0
            local bf = (b.free or 0) > 0
            if af ~= bf then return af end
            local ab, bb = (a.best or 0), (b.best or 0)
            if ab ~= bb then return ab < bb end
        end
        return (a.spell or 0) < (b.spell or 0)
    end)
    return out
end

function W.ManageCount(slug)
    local list_ = W.Manage(slug)
    local on = 0
    for _, it in ipairs(list_) do
        if it.todo then on = on + 1 end
    end
    return #list_, on
end

function W.Summary(slug)
    local cards = W.Cards(slug)
    local free, total, priced = 0, 0, 0
    for _, c in ipairs(cards) do
        if c.free > 0 then
            free = free + 1
            if type(c.gain) == "number" then
                total = total + c.gain
                priced = priced + 1
            end
        end
    end
    return free, total, priced, #cards
end

local function ensureDelegate()
    local api = getAPI()
    if api and type(api.RegisterDelegate) == "function" then
        api.RegisterDelegate("cdwatch", { TodoList = W.TodoList })
    end
end

W.RegisterDelegate = ensureDelegate
ensureDelegate()
