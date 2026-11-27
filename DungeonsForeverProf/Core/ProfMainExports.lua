local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local format = string.format

local EX = {}

local function getBridge()
    return ns.ProfHostBridge or (type(gns) == "table" and gns.ProfHostBridge) or nil
end

local function getDS()
    return ns.ProfDataStore or (type(gns) == "table" and gns.ProfDataStore) or nil
end

local function getAPI()
    return ns.ProfAPI or (type(gns) == "table" and gns.ProfAPI) or nil
end

local function getProfCfg()
    return ns.ProfessionsConfig or (type(gns) == "table" and gns.ProfessionsConfig) or nil
end

local function getRA()
    return ns.ProfRouteAuto or (type(gns) == "table" and gns.ProfRouteAuto) or nil
end

local function getTT()
    return ns.ProfTooltips or (type(gns) == "table" and gns.ProfTooltips) or nil
end

local function getPD()
    return ns.ProfModule or (type(gns) == "table" and gns.ProfModule) or nil
end

local L = setmetatable({}, {
    __index = function(_, k)
        local b = getBridge()
        if b and type(b.L) == "function" then return b.L(k) end
        return tostring(k)
    end,
})

local function fallbackIcon()
    local b = getBridge()
    return (b and type(b.Const) == "function" and b.Const("FALLBACK_ICON"))
        or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- =========================================================================
-- 1. Shared Item Name / Icon Memo (UI-independent, synchronized with PD)
-- =========================================================================

local MEMO_POS_CAP = 8192
local _nmPos, _nmPosN = {}, 0
local _nmNeg, _nmN = {}, 0
local _icPos, _icPosN = {}, 0
local _icNeg, _icN = {}, 0

function EX.ResetItemNameMemo(hard)
    _nmNeg, _nmN = {}, 0
    _icNeg, _icN = {}, 0
    if hard then
        _nmPos, _nmPosN, _icPos, _icPosN = {}, 0, {}, 0
        local pd = getPD()
        if pd then pd.spellNameMemo, pd.spellNameN = {}, 0 end
    end
end

function EX.ClearItemNegative(id)
    if id ~= nil then
        _nmNeg[id] = nil
        _icNeg[id] = nil
    end
end

function EX.ItemName(id)
    if id == nil then return L["暂时没有客户端数据"], false end
    local hit = _nmPos[id]
    if hit ~= nil then return hit, true end
    if _nmNeg[id] then return L["暂时没有客户端数据"], false end
    local DS = getDS()
    local nm = DS and type(DS.RawText) == "function" and DS.RawText("item", id) or nil
    local got = type(nm) == "string" and nm ~= ""
    if not got then
        local b = getBridge()
        if b and type(b.ItemName) == "function" then
            nm, got = b.ItemName(id)
        end
    end
    local ci = _G.C_Item
    if not got and type(ci) == "table" and type(ci.GetItemNameByID) == "function" then
        local ok, n = pcall(ci.GetItemNameByID, id)
        if ok and type(n) == "string" and n ~= "" then nm, got = n, true end
    end
    if got then
        if _nmPosN >= MEMO_POS_CAP then _nmPos, _nmPosN = {}, 0 end
        _nmPos[id], _nmPosN = nm, _nmPosN + 1
        return nm, true
    end
    if _nmN >= 8192 then _nmNeg, _nmN = {}, 0 end
    _nmNeg[id], _nmN = true, _nmN + 1
    return nm or L["暂时没有客户端数据"], false
end

function EX.NormTexIcon(icon)
    if type(icon) == "number" then
        return icon > 0 and tostring(icon) or nil
    end
    if type(icon) == "string" and icon ~= "" then
        if icon:match("^%d+$") then
            local n = tonumber(icon)
            return (n and n > 0) and tostring(n) or nil
        end
        return icon:find("[/\\]") and icon or ("Interface\\Icons\\" .. icon)
    end
    return nil
end

function EX.ItemIcon(id)
    local fb = fallbackIcon()
    if id == nil then return fb end
    local hit = _icPos[id]
    if hit ~= nil then return hit end
    if _icNeg[id] then return fb end
    local function isBlankIcon(t)
        return not t or t == "" or t == 0 or t == 134400 or t == fb
    end
    local tex
    local b = getBridge()
    if b and type(b.ItemIcon) == "function" then
        tex = b.ItemIcon(id)
    end
    local ci = _G.C_Item
    if isBlankIcon(tex) and type(ci) == "table" and type(ci.GetItemIconByID) == "function" then
        local ok, t = pcall(ci.GetItemIconByID, id)
        if ok and not isBlankIcon(t) then tex = t end
    end
    if isBlankIcon(tex) then
        local DS = getDS()
        local item = DS and type(DS.Item) == "function" and DS.Item(id) or nil
        local ic = type(item) == "table" and item.icon or nil
        if type(ic) == "number" and ic > 0 and ic ~= 134400 then
            tex = ic
        elseif type(ic) == "string" and ic ~= "" then
            if ic:match("^%d+$") then
                local n = tonumber(ic)
                if n and n > 0 and n ~= 134400 then tex = n end
            else
                tex = ic:find("[/\\]") and ic or ("Interface\\Icons\\" .. ic)
            end
        end
    end
    if isBlankIcon(tex) then tex = fb end
    if tex ~= fb then
        if _icPosN >= MEMO_POS_CAP then _icPos, _icPosN = {}, 0 end
        _icPos[id], _icPosN = tex, _icPosN + 1
        return tex
    end
    if _icN >= 8192 then _icNeg, _icN = {}, 0 end
    _icNeg[id], _icN = true, _icN + 1
    return tex
end

function EX.MatIconTex(id, px)
    px = px or 14
    local fb = fallbackIcon()
    local ic = EX.NormTexIcon(EX.ItemIcon(id) or fb) or fb
    return format("|T%s:%d:%d|t", ic, px, px)
end

function EX.PrimeNames(mats)
    if type(mats) ~= "table" then return end
    local pd = getPD()
    if pd and type(pd.EnsureTipNameRefresh) == "function" then
        pd.EnsureTipNameRefresh()
    end
    local b = getBridge()
    for i = 1, #mats do
        local m = mats[i]
        local id = type(m) == "table" and (m[1] or m.itemID) or nil
        if type(id) == "number" then
            _nmNeg[id] = nil
            _icNeg[id] = nil
            if b and type(b.RequestItem) == "function" then
                b.RequestItem(id)
            end
        end
    end
end

-- =========================================================================
-- 2. Recipe / Pattern / Product / Crate / Writ Queries (Zero UI Dependency)
-- =========================================================================

function EX.ReagentsToMats(reagents)
    if type(reagents) ~= "table" then return {} end
    local mats = {}
    for i = 1, #reagents do
        local m = reagents[i]
        if type(m) == "table" then
            local iid = m.itemID or m[1]
            local cnt = m.count or m[2] or 1
            if type(iid) == "number" then
                mats[#mats + 1] = { iid, cnt }
            end
        end
    end
    return mats
end

function EX.V2ToCompatRow(rec)
    return {
        rec.spellID,
        rec.outputItemID,
        rec.outputCountMin or 1,
        rec.categoryKey or "",
        "",
        "",
        rec.learnedAt,
        rec.yellow,
        rec.green,
        rec.grey,
        rec.isNew,
        EX.ReagentsToMats(rec.reagents),
    }
end

local learnedMemo, learnedT
function EX.ProfLearned(cached)
    local getTime = _G.GetTime
    local now = cached and type(getTime) == "function" and getTime() or nil
    if now and learnedMemo and (now - (learnedT or 0)) < 0.5 then return learnedMemo end
    local out = {}
    local gp = _G.GetProfessions
    local gpi = _G.GetProfessionInfo
    if type(gp) ~= "function" then return out end
    local ok, a, b, c, d, e, f = pcall(gp)
    if not ok then return out end
    local slots = { a, b, c, d, e, f }
    local ds = getDS()
    local cfg = getProfCfg()
    local slMap = cfg and cfg.SKILL_LINE_TO_SLUG or {}
    for i = 1, 6 do
        local idx = slots[i]
        if idx and type(gpi) == "function" then
            local oki, _, _, cur, mx, _, _, sid = pcall(gpi, idx)
            local slug = sid and ((ds and ds.SkillLineToSlug and ds.SkillLineToSlug(sid)) or slMap[sid])
            if oki and slug and cur and mx then
                local nCur = tonumber(cur) or 0
                local nMax = tonumber(mx) or 0
                local prev = out[slug]
                if not prev or nCur > prev.cur or (nCur == prev.cur and nMax > prev.max) then
                    out[slug] = { cur = nCur, max = nMax, skillLineID = sid }
                end
            end
        end
    end
    if now then learnedMemo, learnedT = out, now end
    return out
end

function EX.MatPriceOn()
    local b = getBridge()
    local cfg = b and type(b.TipConfig) == "function" and b.TipConfig() or nil
    if type(cfg) ~= "table" then return true end
    return cfg.matPrice ~= false
end

local patternIdx
function EX.PatternIndex()
    if patternIdx then return patternIdx end
    patternIdx = {}
    local ds = getDS()
    if not (ds and ds.RecipeProfessions and ds.EnsureRecipes) then return patternIdx end
    local slugs = ds.RecipeProfessions() or {}
    for i = 1, #slugs do
        local slug = slugs[i]
        local bucket = ds.EnsureRecipes(slug)
        if type(bucket) == "table" and type(bucket.recipes) == "table" then
            local spellIDs = {}
            for spellID, recipe in pairs(bucket.recipes) do
                if type(spellID) == "number" and type(recipe) == "table" and recipe.availability == "live" then
                    spellIDs[#spellIDs + 1] = spellID
                end
            end
            table.sort(spellIDs)
            for j = 1, #spellIDs do
                local spellID = spellIDs[j]
                local recipe = bucket.recipes[spellID]
                local tids = {}
                local lr = ds.LearningRoutes and ds.LearningRoutes(spellID)
                local routes = (type(lr) == "table" and lr.routes) or lr
                if type(routes) == "table" then
                    local seenTid = {}
                    for k = 1, #routes do
                        local rt = routes[k]
                        if type(rt) == "table" and rt.kind == "item" and type(rt.teachingItemID) == "number" and not seenTid[rt.teachingItemID] then
                            seenTid[rt.teachingItemID] = true
                            tids[#tids + 1] = rt.teachingItemID
                        end
                    end
                end
                local compatMats = EX.ReagentsToMats(recipe.reagents)
                local primaryTid = tids[1]
                local e = {
                    spellID = spellID,
                    itemID = recipe.outputItemID,
                    outputItemID = recipe.outputItemID,
                    profession = slug,
                    recipe = recipe,
                    teachingItemID = primaryTid,
                    teachingItemIDs = tids,
                    pid = primaryTid,
                    r = {
                        [1] = spellID,
                        [2] = recipe.outputItemID,
                        [3] = recipe.outputCountMin or 1,
                        [7] = recipe.learnedAt,
                        [12] = compatMats,
                        [13] = primaryTid,
                    },
                }
                for k = 1, #tids do
                    local tid = tids[k]
                    if not patternIdx[tid] then
                        patternIdx[tid] = e
                    end
                end
                if type(recipe.outputItemID) == "number" and not patternIdx[recipe.outputItemID] then
                    patternIdx[recipe.outputItemID] = e
                end
                if not patternIdx[spellID] then
                    patternIdx[spellID] = e
                end
            end
        end
    end
    return patternIdx
end

local productIdx
function EX.LookupCraftedItem(id)
    local ds = getDS()
    local spells = type(id) == "number" and ds and ds.CraftIndex and ds.CraftIndex(id)
    if type(spells) == "table" and #spells > 0 then
        local fallbackRec, fallbackSlug
        for _, sid in ipairs(spells) do
            local rec = ds.Recipe and ds.Recipe(sid)
            local slug = ds.RecipeProfession and ds.RecipeProfession(sid)
            if rec then
                if rec.availability == "live" then
                    return { rec = rec, slug = slug, r = EX.V2ToCompatRow(rec) }
                end
                if not fallbackRec then fallbackRec, fallbackSlug = rec, slug end
            end
        end
        if fallbackRec then
            return { rec = fallbackRec, slug = fallbackSlug, r = EX.V2ToCompatRow(fallbackRec) }
        end
    end
    return productIdx and productIdx[id] or nil
end

function EX.ProductIndex()
    if productIdx then return productIdx end
    productIdx = {}
    local ds = getDS()
    if not (ds and ds.RecipeProfessions and ds.EnsureRecipes) then return productIdx end
    for _, slug in ipairs(ds.RecipeProfessions() or {}) do
        local bucket = ds.EnsureRecipes(slug)
        for _, rec in pairs((type(bucket) == "table" and bucket.recipes) or {}) do
            local pid = rec.outputItemID
            if type(pid) == "number" and rec.availability == "live" and not productIdx[pid] then
                productIdx[pid] = { rec = rec, r = EX.V2ToCompatRow(rec), slug = slug }
            end
        end
    end
    return productIdx
end

function EX.CraftInfoForItem(itemID, learnedFilter)
    local ds = getDS()
    local spells = type(itemID) == "number" and ds and ds.CraftIndex and ds.CraftIndex(itemID)
    if type(spells) ~= "table" or #spells == 0 then return nil end
    local fallback
    for _, sid in ipairs(spells) do
        local slug = ds.RecipeProfession and ds.RecipeProfession(sid)
        if not learnedFilter or (slug and learnedFilter[slug]) then
            local rec = ds.Recipe and ds.Recipe(sid)
            if type(rec) == "table" and rec.availability == "live" then
                local entry = {
                    rec = EX.V2ToCompatRow(rec),
                    recipe = rec,
                    slug = slug,
                }
                if not fallback then fallback = entry end
                local ra = getRA()
                if ra and ra.SpellKnown and ra.SpellKnown(sid) then
                    return entry
                end
            end
        end
    end
    return fallback
end

function EX.ProductCraftTitle(id)
    if type(id) ~= "number" then return nil end
    local e = EX.LookupCraftedItem(id)
    if not e then return nil end
    local api = getAPI()
    local p = api and type(api.ProfessionInfo) == "function" and api.ProfessionInfo(e.slug) or nil
    local nm = tostring((p and p.name) or e.slug or "?")
    local sk = (e.rec and e.rec.learnedAt) or (e.r and e.r[7])
    if type(sk) == "number" and sk > 0 then
        return format(L["专业制造（%s%d）"], nm, sk)
    end
    return format(L["专业制造（%s）"], nm)
end

function EX.ProfKnows(id)
    if type(id) ~= "number" then return false end
    local e = EX.LookupCraftedItem(id)
    if not e or not e.slug then return false end
    return EX.ProfLearned()[e.slug] and true or false
end

local crateNeedSet
function EX.CrateMats()
    if crateNeedSet then return crateNeedSet end
    crateNeedSet = {}
    local ds = getDS()
    for _, c in pairs((ds and ds.Crates and ds.Crates()) or {}) do
        if type(c) == "table" and type(c.options) == "table" then
            for _, o in ipairs(c.options) do
                if type(o) == "table" and type(o.itemID) == "number" then
                    crateNeedSet[o.itemID] = true
                end
            end
        end
    end
    return crateNeedSet
end

function EX.CrateOf(id)
    if type(id) ~= "number" then return nil end
    local ds = getDS()
    if not ds then return nil end
    local direct = ds.Crate and ds.Crate(id)
    if direct then return direct end
    for _, crate in pairs((ds.Crates and ds.Crates()) or {}) do
        if type(crate) == "table" and type(crate.options) == "table" then
            for i = 1, #crate.options do
                if crate.options[i].itemID == id then return crate end
            end
        end
    end
    return nil
end

function EX.WritOf(id)
    if type(id) ~= "number" then return nil end
    local ds = getDS()
    if not ds then return nil end
    return (ds.WritByItem and ds.WritByItem(id))
        or (ds.Writ and ds.Writ(id))
        or (ds.WritByTarget and ds.WritByTarget(id))
end

function EX.WritZoneOf(targetId)
    if type(targetId) ~= "number" then return nil end
    local ds = getDS()
    if not ds then return nil end
    local writ = (ds.WritByTarget and ds.WritByTarget(targetId))
        or (ds.WritByItem and ds.WritByItem(targetId))
        or (ds.Writ and ds.Writ(targetId))
    if not writ or type(writ.questID) ~= "number" then return nil end
    local q = ds.Quest and ds.Quest(writ.questID)
    if not q then return nil end
    return q.areaID or q.uiMapID, q.uiMapID
end

local zoneNames
function EX.ZoneNameOf(zone)
    if type(zone) ~= "number" then return nil end
    local ds = getDS()
    local raw = ds and ds.RawText and ds.RawText("zone", zone)
    if type(raw) == "string" and raw ~= "" then return raw end
    zoneNames = zoneNames or {}
    local nm = zoneNames[zone]
    if nm == nil then
        local cm = _G.C_Map
        local mi = type(cm) == "table" and type(cm.GetMapInfo) == "function" and cm.GetMapInfo(zone) or nil
        if type(mi) == "table" and type(mi.name) == "string" and mi.name ~= "" then
            nm = mi.name
        else
            nm = false
        end
        zoneNames[zone] = nm
    end
    if nm == false then return nil end
    return nm
end

local function isTeachingItem(e, id)
    if id == e.pid or id == e.teachingItemID then return true end
    local tids = type(e.teachingItemIDs) == "table" and e.teachingItemIDs or nil
    if tids then
        for i = 1, #tids do
            if tids[i] == id then return true end
        end
    end
    return false
end

function EX.WritNeedOf(id, title)
    if type(id) ~= "number" then return nil end
    local ds = getDS()
    if not ds then return nil end
    if ds.WritByTarget and ds.WritByTarget(id) then
        return id, false
    end
    local byItem = ds.WritByItem and ds.WritByItem(id)
    if type(byItem) == "table" and type(byItem.targetItemID) == "number" then
        return byItem.targetItemID, true
    end
    local e = EX.PatternIndex()[id]
    if not (e and e.pid) then return nil end
    if not isTeachingItem(e, id) then
        local pname = EX.ItemName(e.pid)
        if title ~= nil and title ~= "" and title ~= pname then return nil end
    end
    local prod = e.itemID
    if type(prod) == "number" and prod ~= id and ds.WritByTarget and ds.WritByTarget(prod) then
        return prod, false
    end
    return nil
end

function EX.CrateNeedOf(id, title)
    if type(id) ~= "number" then return nil end
    local set = EX.CrateMats()
    if set[id] then return id end
    local e = EX.PatternIndex()[id]
    if not (e and e.pid) then return nil end
    if not isTeachingItem(e, id) then
        local pname = EX.ItemName(e.pid)
        if title ~= nil and title ~= "" and title ~= pname then return nil end
    end
    local prod = e.itemID
    if type(prod) == "number" and prod ~= id and set[prod] then return prod end
    return nil
end

-- =========================================================================
-- 3. Outbound Tooltip Bridges & Delegate Registration onto ProfAPI
-- =========================================================================

function EX.PatternTipLines(id, title)
    local tt = getTT()
    return tt and tt.PatternTipLines and tt.PatternTipLines(id, title) or nil
end

function EX.ProductTipLines(id, title)
    local tt = getTT()
    return tt and tt.ProductTipLines and tt.ProductTipLines(id, title) or nil
end

function EX.CrateTipLines(id)
    local tt = getTT()
    return tt and tt.CrateTipLines and tt.CrateTipLines(id) or nil
end

function EX.WritTipLines(id)
    local tt = getTT()
    return tt and tt.WritTipLines and tt.WritTipLines(id) or nil
end

function EX.CrateNeedLines(id, title)
    local tt = getTT()
    return tt and tt.CrateNeedLines and tt.CrateNeedLines(id, title) or nil
end

function EX.WritNeedLines(id, title)
    local tt = getTT()
    return tt and tt.WritNeedLines and tt.WritNeedLines(id, title) or nil
end

function EX.RegisterDelegates()
    local apiMod = getAPI()
    if not (apiMod and type(apiMod.RegisterDelegate) == "function") then return end
    apiMod.RegisterDelegate("exports", {
        ProfLearned       = EX.ProfLearned,
        PatternIndex      = EX.PatternIndex,
        ResetItemNameMemo = EX.ResetItemNameMemo,
        ItemName          = EX.ItemName,
        ProductCraftTitle = EX.ProductCraftTitle,
        ProfKnows         = EX.ProfKnows,
        PatternTipLines   = EX.PatternTipLines,
        ProductTipLines   = EX.ProductTipLines,
        CrateOf           = EX.CrateOf,
        WritOf            = EX.WritOf,
        WritZoneOf        = EX.WritZoneOf,
        WritNeedOf        = EX.WritNeedOf,
        CrateTipLines     = EX.CrateTipLines,
        WritTipLines      = EX.WritTipLines,
        CrateNeedLines    = EX.CrateNeedLines,
        WritNeedLines     = EX.WritNeedLines,
    })
end

EX.RegisterDelegates()

ns.ProfMainExports = EX
if type(gns) == "table" and gns ~= ns then
    gns.ProfMainExports = EX
end
