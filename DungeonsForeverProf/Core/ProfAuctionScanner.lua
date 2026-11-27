local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local S = ns.ProfAuctionScanner or (type(gns) == "table" and gns.ProfAuctionScanner) or {}
ns.ProfAuctionScanner = S
ns.AuctionBridge = S
if type(gns) == "table" and gns ~= ns then
    gns.ProfAuctionScanner = S
    gns.AuctionBridge = S
end

local format = string.format
local floor, min, max, huge = math.floor, math.min, math.max, math.huge

local function getPricingCfg()
    return ns.PricingConfig or (type(gns) == "table" and gns.PricingConfig) or nil
end

local function getPE()
    return ns.ProfPricingEngine or (type(gns) == "table" and gns.ProfPricingEngine) or nil
end

local function getDS()
    return ns.ProfDataStore or (type(gns) == "table" and gns.ProfDataStore) or nil
end

local function getRouteAuto()
    return ns.ProfRouteAuto or (type(gns) == "table" and gns.ProfRouteAuto) or nil
end

local function getDB()
    return ns.ProfDB or (type(gns) == "table" and gns.ProfDB) or nil
end

local function getBridge()
    return ns.ProfHostBridge or (type(gns) == "table" and gns.ProfHostBridge) or nil
end

local function getTT()
    return ns.ProfTooltips or (type(gns) == "table" and gns.ProfTooltips) or nil
end

local function getL()
    local b = getBridge()
    return b and type(b.LocaleRaw) == "function" and b.LocaleRaw() or nil
end

local function tr(key)
    local L = getL()
    if type(L) == "table" then
        local ok, v = pcall(function() return L[key] end)
        if ok and type(v) == "string" and v ~= "" then return v end
    end
    return key
end

local function Say(msg)
    local frame = _G.DEFAULT_CHAT_FRAME
    if type(frame) == "table" and type(frame.AddMessage) == "function" then
        frame:AddMessage("|cffffd100" .. tostring(msg) .. "|r")
    end
end

local function Now()
    if type(_G.time) == "function" then
        local ok, v = pcall(_G.time)
        if ok and type(v) == "number" then return v end
    end
    if type(os) == "table" and type(os.time) == "function" then
        local ok, v = pcall(os.time)
        if ok and type(v) == "number" then return v end
    end
    return 0
end

local function ClockMs()
    if type(_G.debugprofilestop) == "function" then
        local ok, v = pcall(_G.debugprofilestop)
        if ok and type(v) == "number" then return v end
    end
    if type(_G.GetTime) == "function" then
        local ok, v = pcall(_G.GetTime)
        if ok and type(v) == "number" then return v * 1000 end
    end
    return 0
end

local function validNum(v)
    return type(v) == "number" and v == v and v ~= huge and v ~= -huge
end

local function WholeNumber(n)
    return type(n) == "number" and n >= 0 and n < huge and n == floor(n)
end

local function scannerCfg()
    local cfg = getPricingCfg()
    return type(cfg) == "table" and type(cfg.SCANNER) == "table" and cfg.SCANNER or {}
end

local function SupplyMaxAge()
    local cfg = getPricingCfg()
    if type(cfg) == "table" and type(cfg.SUPPLY_MAX_AGE_SEC) == "number" and cfg.SUPPLY_MAX_AGE_SEC > 0 then
        return cfg.SUPPLY_MAX_AGE_SEC
    end
    local ra = getRouteAuto()
    if ra and type(ra.MaxAuctionSupplyAgeSeconds) == "function" then
        local ok, v = pcall(ra.MaxAuctionSupplyAgeSeconds)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    return 172800
end

local function SnapshotVersion()
    local sc = scannerCfg()
    if type(sc.snapshotVersion) == "number" and sc.snapshotVersion >= 4 then
        return sc.snapshotVersion
    end
    local cfg = getPricingCfg()
    return (type(cfg) == "table" and type(cfg.SNAPSHOT_VERSION) == "number" and cfg.SNAPSHOT_VERSION) or 4
end

local function CooldownSec()
    local sc = scannerCfg()
    return (type(sc.cooldownSec) == "number" and sc.cooldownSec > 0 and sc.cooldownSec) or 900
end

local function ScanSilentSec()
    local sc = scannerCfg()
    if type(sc.silentTimeoutSec) == "number" and sc.silentTimeoutSec > 0 then
        return sc.silentTimeoutSec
    end
    local cfg = getPricingCfg()
    return (type(cfg) == "table" and type(cfg.SCAN_SILENT_SEC) == "number" and cfg.SCAN_SILENT_SEC > 0 and cfg.SCAN_SILENT_SEC) or 180
end

local function FrameBudgetMs()
    local sc = scannerCfg()
    return (type(sc.frameBudgetMs) == "number" and sc.frameBudgetMs > 0 and sc.frameBudgetMs) or 10
end

local function MaxRowsPerSlice()
    local sc = scannerCfg()
    return (type(sc.maxRowsPerSlice) == "number" and sc.maxRowsPerSlice > 0 and sc.maxRowsPerSlice) or 4000
end

function S.AHCut()
    local cfg = getPricingCfg()
    if type(cfg) == "table" and validNum(cfg.AH_CUT) and cfg.AH_CUT >= 0 and cfg.AH_CUT <= 1 then
        return cfg.AH_CUT
    end
    return 0.05
end

function S.NetMultiplier()
    local cfg = getPricingCfg()
    if type(cfg) == "table" and validNum(cfg.NET_MULTIPLIER) and cfg.NET_MULTIPLIER >= 0 and cfg.NET_MULTIPLIER <= 1 then
        return cfg.NET_MULTIPLIER
    end
    return 1 - S.AHCut()
end

function S.NetPrice(gross)
    if not validNum(gross) or gross < 0 then return nil end
    return floor(gross * S.NetMultiplier() + 1e-9)
end

function S.Available()
    return true
end

function S.TrimFishingOrders(levels, cfgOverride)
    local PE = getPE()
    if PE and type(PE.TrimFishingOrders) == "function" then
        return PE.TrimFishingOrders(levels, cfgOverride)
    end
    return {}, 0, 0, 0, 0
end

function S.RobustReferencePrice(levels, shareOverride, cfgOverride)
    local PE = getPE()
    if PE and type(PE.RobustReferencePrice) == "function" then
        return PE.RobustReferencePrice(levels, shareOverride, cfgOverride)
    end
    return nil
end

S.RobustFloorPrice = S.RobustReferencePrice

local fallbackScanDB = {}
local function ScanDB()
    local db = getDB()
    if type(db) == "table" and type(db.Get) == "function" then
        local ok, root = pcall(db.Get)
        if ok and type(root) == "table" then
            if type(root.prof) ~= "table" then root.prof = {} end
            return root.prof
        end
    elseif type(db) == "function" then
        local ok, root = pcall(db)
        if ok and type(root) == "table" then
            if type(root.prof) ~= "table" then root.prof = {} end
            return root.prof
        end
    end
    return fallbackScanDB
end

local function ScannerMeta()
    local db = ScanDB()
    if type(db.auctionScanner) ~= "table" then
        db.auctionScanner = {}
    end
    return db.auctionScanner
end

local profItemSetCache
local function BuildProfItemSet()
    if profItemSetCache then return profItemSetCache end
    local DS = getDS()
    if not DS or type(DS.Ensure) ~= "function" then return nil end
    local set = {}
    local any = false

    local function mark(id)
        if WholeNumber(id) and id > 0 then
            set[id] = true
            any = true
        end
    end

    local ent = DS.Ensure("entities")
    if type(ent) == "table" and type(ent.items) == "table" then
        for id in pairs(ent.items) do mark(id) end
    end

    local com = DS.Ensure("commerce")
    if type(com) == "table" then
        for id, c in pairs(com.crates or {}) do
            mark(id)
            if type(c) == "table" then
                mark(c.itemID)
                for _, o in ipairs(c.options or {}) do
                    if type(o) == "table" then mark(o.itemID) end
                end
            end
        end
        for _, w in pairs(com.writs or {}) do
            if type(w) == "table" then
                mark(w.writItemID)
                mark(w.targetItemID)
            end
        end
        for id, p in pairs(com.plunder or {}) do
            mark(id)
            if type(p) == "table" then
                mark(p.itemID)
                for _, m in ipairs(p.materials or {}) do
                    if type(m) == "table" then mark(m.itemID or m[1]) end
                end
            end
        end
    end

    local sys = DS.Ensure("systems")
    if type(sys) == "table" then
        for id, t in pairs(sys.tools or {}) do
            mark(id)
            if type(t) == "table" then mark(t.itemID or t.item) end
        end
        for id, e in pairs(sys.essences or {}) do
            mark(id)
            if type(e) == "table" then
                mark(e.inputItemID)
                mark(e.outputItemID)
            end
        end
    end

    if type(DS.RecipeProfessions) == "function" and type(DS.EnsureRecipes) == "function" then
        for _, slug in ipairs(DS.RecipeProfessions() or {}) do
            local bucket = DS.EnsureRecipes(slug)
            if type(bucket) == "table" and type(bucket.recipes) == "table" then
                for _, r in pairs(bucket.recipes) do
                    if type(r) == "table" then
                        mark(r.outputItemID)
                        mark(r.formulaID or r.formula)
                        for _, m in ipairs(r.reagents or {}) do
                            if type(m) == "table" then mark(m.itemID or m.id or m[1]) end
                        end
                    end
                end
            end
        end
    end

    if not any then return nil end
    profItemSetCache = set
    return profItemSetCache
end

local supplyRevision = 0
local supplyListeners = {}
local forcedUntil = 0

function S.ForceExpiredWindow(seconds)
    local now = Now()
    forcedUntil = now + max(30, tonumber(seconds) or 180)
    supplyRevision = supplyRevision + 1
    return forcedUntil
end

function S.ForceExpiredActive()
    return forcedUntil > 0 and Now() <= forcedUntil
end

function S.ForceExpiredLeft()
    if not S.ForceExpiredActive() then return 0 end
    return max(0, forcedUntil - Now())
end

local function MarketKey()
    local rules = _G.C_GameRules
    local enumTbl = _G.Enum
    local ids = type(enumTbl) == "table" and enumTbl.GameRule or nil
    local factionFn = _G.UnitFactionGroup
    local regionFn = _G.GetCurrentRegion
    local faction = type(factionFn) == "function" and factionFn("player") or nil
    local region = type(regionFn) == "function" and regionFn() or nil
    if not (type(rules) == "table" and type(rules.IsGameRuleActive) == "function" and type(ids) == "table"
        and WholeNumber(region) and region > 0 and (faction == "Alliance" or faction == "Horde")) then
        return nil
    end
    local bits = {}
    for _, name in ipairs({ "PvPRuleset", "RPRuleset", "HardcoreRuleset" }) do
        if ids[name] == nil then return nil end
        local ok, value = pcall(rules.IsGameRuleActive, ids[name])
        if not ok or type(value) ~= "boolean" then return nil end
        bits[#bits + 1] = value and "1" or "0"
    end
    return "rules:1:forever:" .. region .. ":" .. table.concat(bits) .. ":" .. faction
end

local function ObserverKey()
    local guidFn = _G.UnitGUID
    local nameFn = _G.UnitName
    local guid = type(guidFn) == "function" and guidFn("player") or nil
    local name = type(nameFn) == "function" and nameFn("player") or nil
    return tostring(guid or name or "")
end

local function PlayerOwnerNames()
    local names = {}
    local name, realm
    if type(_G.UnitFullName) == "function" then
        local ok, n, r = pcall(_G.UnitFullName, "player")
        if ok and type(n) == "string" and n ~= "" then name, realm = n, r end
    end
    if not name and type(_G.UnitName) == "function" then
        local ok, n = pcall(_G.UnitName, "player")
        if ok and type(n) == "string" and n ~= "" then name = n end
    end
    if (not realm or realm == "") and type(_G.GetRealmName) == "function" then
        local ok, r = pcall(_G.GetRealmName)
        if ok and type(r) == "string" and r ~= "" then realm = r end
    end
    if type(name) == "string" and name ~= "" then
        names[string.lower(name)] = true
        if type(realm) == "string" and realm ~= "" then
            local compactRealm = realm:gsub("[%s%-]+", "")
            names[string.lower(name .. "-" .. realm)] = true
            names[string.lower(name .. "-" .. compactRealm)] = true
        end
    end
    return names
end

local function isOwnAuction(ownerNames, owner, ownerFull)
    if type(owner) == "string" and owner ~= "" and ownerNames[string.lower(owner)] then
        return true
    end
    if type(ownerFull) == "string" and ownerFull ~= "" and ownerNames[string.lower(ownerFull)] then
        return true
    end
    return false
end

function S.OnChanged(fn)
    if type(fn) == "function" then
        supplyListeners[#supplyListeners + 1] = fn
    end
end

local function NotifyListeners(id, reason)
    for _, fn in ipairs(supplyListeners) do
        pcall(fn, id, reason)
    end
end

local function SupplyChanged(id)
    supplyRevision = supplyRevision + 1
    NotifyListeners(id, "supply")
    local ra = getRouteAuto()
    if ra and type(ra.NotifyPricesChanged) == "function" then
        pcall(ra.NotifyPricesChanged)
    end
end

local denoisedCache = setmetatable({}, { __mode = "k" })

local function getDenoisedItem(batch, id)
    local item = type(batch) == "table" and type(batch.items) == "table" and batch.items[id] or nil
    if type(item) ~= "table" then return nil end
    if batch.dv ~= 1 or type(item.d) ~= "table" or not WholeNumber(item.q) or item.q <= 0 then
        return {
            p = item.p,
            quantity = item.dq or item.q or 0,
            rawQuantity = item.q or 0,
            trimmedQuantity = 0,
            trimmedLots = 0,
            levels = {},
        }
    end
    local byId = denoisedCache[batch]
    if not byId then
        byId = {}
        denoisedCache[batch] = byId
    end
    local cached = byId[id]
    if cached then return cached end
    local levels, denoisedTotal, trimmedQty, trimmedLots = S.TrimFishingOrders(item.d)
    local robust = S.RobustReferencePrice(item.d)
    local price = (type(robust) == "number" and robust > 0) and robust or item.p
    cached = {
        p = price,
        quantity = denoisedTotal,
        rawQuantity = item.q,
        trimmedQuantity = trimmedQty,
        trimmedLots = trimmedLots,
        levels = levels,
    }
    byId[id] = cached
    return cached
end

local fullBatch, fullFailure, fullExpiryTimer, fullExpiryToken
local restoredSnapshot = false
local currentMarket = false
local SelectMarket
local UpdateScanButton
local UpdateScanBanner

local function StoreBatch(batch)
    local key = batch.mk or currentMarket
    if type(key) ~= "string" or key == "" then return false end
    batch.mk = key
    local db = ScanDB()
    if db.auctionFullScans ~= nil and type(db.auctionFullScans) ~= "table" then return false end
    db.auctionFullScans = db.auctionFullScans or {}
    db.auctionFullScans[key] = batch
    return true
end

local function ReleaseFullBatch(reason, observation, snapshotStatus)
    if fullExpiryTimer then fullExpiryTimer:Cancel(); fullExpiryTimer = nil end
    fullExpiryToken = nil
    local batch = observation or fullBatch or fullFailure
    fullFailure = { v = SnapshotVersion(), failure = reason, snapshotStatus = snapshotStatus }
    if type(batch) == "table" then
        fullFailure.mk, fullFailure.ob, fullFailure.ox = batch.mk, batch.ob, batch.ox
        if WholeNumber(batch.t) and batch.t > 0 then fullFailure.t = batch.t end
        if reason == "expired" and type(batch.items) == "table" then
            local keep = {}
            for id, item in pairs(batch.items) do
                if WholeNumber(id) and id > 0 and type(item) == "table" then
                    local q = tonumber(item.q)
                    if q and q >= 0 and q == floor(q) then
                        local p = tonumber(item.p)
                        local row = { q = q }
                        if p and p > 0 and p < huge then row.p = p end
                        if WholeNumber(item.dq) then row.dq = item.dq end
                        row.d = item.d
                        row.failure = item.failure
                        keep[id] = row
                    end
                end
            end
            fullFailure.items = keep
            fullFailure.dv = batch.dv
            if type(batch.ref) == "table" then
                local keepRef = {}
                for id, ritem in pairs(batch.ref) do
                    if WholeNumber(id) and id > 0 and type(ritem) == "table" then
                        local q = tonumber(ritem.q)
                        local p = tonumber(ritem.p)
                        if q and q >= 0 and q == floor(q) and p and p > 0 and p < huge then
                            keepRef[id] = { q = q, p = p }
                        end
                    end
                end
                fullFailure.ref = keepRef
            end
        end
    end
    fullBatch = nil
    StoreBatch(fullFailure)
end

local function FullBatchFailure(batch)
    local key = MarketKey()
    if not key or batch.mk ~= key then return "unverified" end
    local v = SnapshotVersion()
    if batch.v ~= v or batch.c ~= true or type(batch.items) ~= "table" then return "incomplete" end
    local stamp = batch.t
    local now = Now()
    if not WholeNumber(stamp) or stamp <= 0 or stamp > now then return "incomplete" end
    if now - stamp > SupplyMaxAge() and not S.ForceExpiredActive() then return "expired" end
end

local function ValidItemLevels(item)
    if type(item.d) ~= "table" then return false end
    local total, last = 0, 0
    local entries = 0
    for index in pairs(item.d) do
        if not WholeNumber(index) or index < 1 or index > #item.d then return false end
        entries = entries + 1
    end
    if entries ~= #item.d then return false end
    for _, level in ipairs(item.d) do
        if type(level) ~= "table" or type(level[1]) ~= "number" or level[1] ~= level[1]
            or level[1] <= last or level[1] == huge or not WholeNumber(level[2]) or level[2] == 0 then
            return false
        end
        last = level[1]
        total = total + level[2]
    end
    return total == item.q
end

local function ValidSavedBatch(batch, expectedVer)
    local now = Now()
    local ver = expectedVer or SnapshotVersion()
    if type(batch) ~= "table" or batch.v ~= ver or batch.c ~= true
        or batch.s ~= "client-auction-results" or type(batch.ox) ~= "boolean"
        or type(batch.mk) ~= "string" or batch.mk == "" or type(batch.ob) ~= "string" or batch.ob == ""
        or not WholeNumber(batch.t) or batch.t <= 0 or batch.t > now
        or not WholeNumber(batch.completedAt) or batch.completedAt < batch.t or batch.completedAt > now
        or not WholeNumber(batch.expected) or batch.received ~= batch.expected or type(batch.items) ~= "table" then
        return false
    end
    if batch.dv ~= nil and batch.dv ~= 1 then return false end
    local count = 0
    for id, item in pairs(batch.items) do
        if not WholeNumber(id) or id == 0 or type(item) ~= "table" or not WholeNumber(item.q)
            or (item.failure ~= nil and item.failure ~= "incomplete")
            or (item.p ~= nil and (type(item.p) ~= "number" or item.p ~= item.p or item.p <= 0 or item.p == huge))
            or (item.q > 0 and item.p == nil) then
            return false
        end
        if batch.dv == 1 and not ValidItemLevels(item) then
            return false
        end
        count = count + 1
    end
    if batch.ref ~= nil then
        if type(batch.ref) ~= "table" then return false end
        for id, ritem in pairs(batch.ref) do
            if not WholeNumber(id) or id == 0 or type(ritem) ~= "table"
                or not WholeNumber(ritem.q)
                or (ritem.p ~= nil and (type(ritem.p) ~= "number" or ritem.p ~= ritem.p or ritem.p <= 0 or ritem.p == huge))
                or (ritem.q > 0 and ritem.p == nil) then
                return false
            end
            count = count + 1
        end
    end
    return count <= batch.expected
end

local function UpgradeV3Batch(saved)
    if type(saved) ~= "table" or saved.v ~= 3 then return nil end
    local profSet = BuildProfItemSet()
    local upgraded = {
        v = SnapshotVersion(),
        c = saved.c,
        s = saved.s,
        ox = saved.ox,
        mk = saved.mk,
        ob = saved.ob,
        t = saved.t,
        completedAt = saved.completedAt,
        expected = saved.expected,
        received = saved.received,
        dv = saved.dv,
        failure = saved.failure,
        snapshotStatus = saved.snapshotStatus,
        method = saved.method or "native-replicate-scan",
        items = {},
        ref = {},
    }
    if type(saved.items) ~= "table" then
        upgraded.items = nil
        return upgraded
    end
    for id, item in pairs(saved.items) do
        if WholeNumber(id) and id > 0 and type(item) == "table" then
            local robust = item.p
            local dq = item.q
            if saved.dv == 1 and type(item.d) == "table" and #item.d > 0 then
                local _, remTotal = S.TrimFishingOrders(item.d)
                local calc = S.RobustReferencePrice(item.d)
                if type(calc) == "number" and calc > 0 then
                    robust = calc
                end
                if WholeNumber(remTotal) then
                    dq = remTotal
                end
            end
            if not profSet or profSet[id] then
                upgraded.items[id] = {
                    p = robust,
                    q = item.q,
                    dq = dq,
                    d = item.d,
                    failure = item.failure,
                }
            elseif WholeNumber(item.q) and item.q > 0 and validNum(robust) and robust > 0 then
                upgraded.ref[id] = {
                    p = robust,
                    q = item.q,
                }
            end
        end
    end
    return upgraded
end

local function PruneLegacyBatch(batch)
    if batch.dv ~= 1 or batch.mk ~= MarketKey() or not ValidSavedBatch(batch) then return end
    local db = ScanDB()
    local old = db.auctionFullScan
    if type(old) ~= "table" then return end
    local realm = _G.GetRealmName and _G.GetRealmName()
    local faction = _G.UnitFactionGroup and _G.UnitFactionGroup("player")
    local legacy = realm and faction and realm .. ":" .. faction
    if old.mk ~= batch.mk and old.mk ~= legacy then return end
    if type(db.auctionFullScans) == "table" and old.mk ~= batch.mk then db.auctionFullScans[old.mk] = nil end
    db.auctionFullScan = nil
end

local function CountSnapshotItems(batch)
    local nItems, nRef = 0, 0
    if type(batch) == "table" then
        for _ in pairs(batch.items or {}) do nItems = nItems + 1 end
        for _ in pairs(batch.ref or {}) do nRef = nRef + 1 end
    end
    return nItems, nRef
end

function S.FullScanSnapshotStatus()
    if SelectMarket then SelectMarket() end
    local batch = fullBatch
    local failure = batch and FullBatchFailure(batch)
    if failure and failure ~= "unverified" then ReleaseFullBatch(failure); batch = nil end
    local meta = batch or fullFailure
    local forced = S.ForceExpiredActive()
    local key = MarketKey()
    local matched = key and meta and meta.mk == key
    local staleUsable = forced and matched and meta.failure == "expired"
    local staleItems = type(meta) == "table" and meta.failure == "expired"
        and ((type(meta.items) == "table" and next(meta.items) ~= nil)
             or (type(meta.ref) == "table" and next(meta.ref) ~= nil))
    local status = batch and (failure == "unverified" and "mismatch" or "available")
        or meta and not matched and "mismatch"
        or staleUsable and "available"
        or meta and (meta.failure == "expired" and "expired" or meta.snapshotStatus == "missing" and "missing" or "invalid") or "missing"
    local nProf, nRef = CountSnapshotItems(batch or (staleUsable and meta) or nil)
    return {
        status = status,
        observedAt = meta and meta.t,
        marketKey = meta and meta.mk,
        expiresAt = meta and meta.t and meta.t + SupplyMaxAge(),
        forced = (forced and (matched and batch ~= nil or staleUsable)) or nil,
        canForce = (matched and not batch and meta.failure == "expired") or nil,
        staleIncomplete = (matched and meta.failure == "expired" and not staleItems) or nil,
        restored = restoredSnapshot,
        completedAt = batch and batch.completedAt,
        source = "native",
        profItems = nProf,
        refItems = nRef,
    }
end

local function ActiveReadableBatch()
    if SelectMarket then SelectMarket() end
    local batch = fullBatch
    if batch then
        local failure = FullBatchFailure(batch)
        if failure == "unverified" then
            return nil, { mk = batch.mk, ob = batch.ob, failure = failure }
        end
        if failure then
            ReleaseFullBatch(failure)
            batch = nil
        end
    end
    if batch then return batch, nil end
    if S.ForceExpiredActive() and type(fullFailure) == "table" and fullFailure.mk == MarketKey() and fullFailure.failure == "expired"
        and ((type(fullFailure.items) == "table" and next(fullFailure.items) ~= nil)
             or (type(fullFailure.ref) == "table" and next(fullFailure.ref) ~= nil)) then
        return fullFailure, nil, true
    end
    return nil, fullFailure
end

local function OwnRecord(id)
    local batch, failRec, isForcedExpired = ActiveReadableBatch()
    if not batch then return failRec end

    local item = type(batch.items) == "table" and batch.items[id] or nil
    if item ~= nil and type(item) ~= "table" then
        return { mk = batch.mk, ob = batch.ob, failure = "incomplete" }
    end

    if item then
        local dEntry = getDenoisedItem(batch, id)
        return {
            q = dEntry and dEntry.quantity or (item.dq or item.q or 0),
            rawQuantity = dEntry and dEntry.rawQuantity or (item.q or 0),
            trimmedQuantity = dEntry and dEntry.trimmedQuantity or 0,
            p = dEntry and dEntry.p or item.p,
            t = batch.t,
            mk = batch.mk,
            ob = batch.ob,
            c = (isForcedExpired or batch.c == true) and not item.failure,
            ox = batch.ox ~= false,
            s = "client-auction-results",
            v = SnapshotVersion(),
            failure = item.failure or (not isForcedExpired and batch.c ~= true and "incomplete") or nil,
            method = batch.method or "native-replicate-scan",
        }
    end

    local refItem = type(batch.ref) == "table" and batch.ref[id] or nil
    if refItem and type(refItem) == "table" then
        return {
            q = tonumber(refItem.q) or 0,
            rawQuantity = tonumber(refItem.q) or 0,
            trimmedQuantity = 0,
            p = tonumber(refItem.p),
            t = batch.t,
            mk = batch.mk,
            ob = batch.ob,
            c = isForcedExpired or batch.c == true,
            ox = batch.ox ~= false,
            s = "client-auction-results",
            v = SnapshotVersion(),
            failure = (not isForcedExpired and batch.c ~= true and "incomplete") or nil,
            method = batch.method or "native-replicate-scan",
            isRef = true,
        }
    end

    if not isForcedExpired and batch.c ~= true then
        return { mk = batch.mk, ob = batch.ob, failure = "incomplete" }
    end

    return {
        q = 0,
        rawQuantity = 0,
        trimmedQuantity = 0,
        p = nil,
        t = batch.t,
        mk = batch.mk,
        ob = batch.ob,
        c = true,
        ox = batch.ox ~= false,
        s = "client-auction-results",
        v = SnapshotVersion(),
        method = batch.method or "native-replicate-scan",
    }
end

function S.SupplyRevision()
    return supplyRevision
end

function S.GetAuctionSupplyStatus(id)
    if type(id) ~= "number" or id <= 0 then return nil end
    local rec = OwnRecord(id)
    if type(rec) ~= "table" then return "unknown" end
    if rec.failure then return rec.failure end
    local now = Now()
    local qty, stamp = tonumber(rec.q), tonumber(rec.t)
    if not MarketKey() or rec.mk ~= MarketKey() then return "unverified" end
    if rec.c ~= true or type(rec.ox) ~= "boolean" or rec.s ~= "client-auction-results" then return "incomplete" end
    if not qty or qty < 0 or qty == huge or qty ~= floor(qty) then return "incomplete" end
    if not stamp or stamp ~= stamp or stamp <= 0 or stamp > now then return "expired" end
    if now - stamp > SupplyMaxAge() and not S.ForceExpiredActive() then return "expired" end
    return "verified"
end

function S.GetAuctionSupply(id)
    if S.GetAuctionSupplyStatus(id) ~= "verified" then return nil end
    local rec = OwnRecord(id)
    return {
        quantity = tonumber(rec.q),
        rawQuantity = tonumber(rec.rawQuantity ~= nil and rec.rawQuantity or rec.q),
        trimmedQuantity = tonumber(rec.trimmedQuantity) or 0,
        observedAt = tonumber(rec.t) or 0,
        complete = rec.c == true,
        ownerExcluded = rec.ox == true,
        source = rec.s or "client-auction-results",
        market = tonumber(rec.p),
        marketKey = rec.mk,
        observer = rec.ob,
        method = rec.method or "native-replicate-scan",
        schemaVersion = rec.v,
        forced = S.ForceExpiredActive() or nil,
        expiresAt = max(tonumber(rec.t) or 0, S.ForceExpiredActive() and Now() or 0) + SupplyMaxAge(),
    }
end

function S.SupplyFresh(id)
    return S.GetAuctionSupply(id)
end

function S.GetReferencePrice(id)
    if type(id) ~= "number" or id <= 0 then return nil end
    if S.GetAuctionSupplyStatus(id) ~= "verified" then return nil end
    local rec = OwnRecord(id)
    local p = type(rec) == "table" and tonumber(rec.p) or nil
    local q = type(rec) == "table" and tonumber(rec.q) or 0
    if q and q > 0 and validNum(p) and p > 0 then
        return p
    end
    return nil
end

function S.GetAuctionDepth(id)
    if S.GetAuctionSupplyStatus(id) ~= "verified" then return nil end
    local batch = ActiveReadableBatch()
    if not batch or batch.dv ~= 1 or type(batch.items) ~= "table" then return nil end
    local item = batch.items[id]
    local dEntry = item and getDenoisedItem(batch, id)
    local levels = {}
    for i, row in ipairs(dEntry and dEntry.levels or {}) do
        levels[i] = { row[1], row[2] }
    end
    return {
        levels = levels,
        quantity = dEntry and dEntry.quantity or 0,
        rawQuantity = item and item.q or 0,
        trimmedQuantity = dEntry and dEntry.trimmedQuantity or 0,
        trimmedLots = dEntry and dEntry.trimmedLots or 0,
        denoised = true,
        observedAt = batch.t,
        marketKey = batch.mk,
        version = 1,
    }
end

function S.GetAuctionPriceObservedAt(id)
    if type(id) ~= "number" or id <= 0 then return nil end
    local rec = OwnRecord(id)
    if type(rec) == "table" and rec.mk == MarketKey() and tonumber(rec.p) and rec.p > 0
        and tonumber(rec.t) and rec.t > 0 then
        return tonumber(rec.t)
    end
    return nil
end

function S.GetAuctionSupplyHistory(_id)
    return nil
end

function S.SupplyEstimate(_id)
    return nil
end

local scanState = { status = "ready" }
local activeScan, scanTimer, scanWatchdog, scanEventFrame
local scanGeneration = 0

function S.FullScanStatus()
    return scanState
end

local function ScanStatusChanged()
    if UpdateScanButton then pcall(UpdateScanButton) end
    if UpdateScanBanner then pcall(UpdateScanBanner) end
    NotifyListeners(nil, "scan-status")
end

local function UnregisterScanEvents(keepLateListener)
    if not (scanEventFrame and type(scanEventFrame.UnregisterAllEvents) == "function") then return end
    pcall(scanEventFrame.UnregisterAllEvents, scanEventFrame)
    if keepLateListener and type(scanEventFrame.RegisterEvent) == "function" then
        pcall(scanEventFrame.RegisterEvent, scanEventFrame, "REPLICATE_ITEM_LIST_UPDATE")
        pcall(scanEventFrame.RegisterEvent, scanEventFrame, "AUCTION_HOUSE_CLOSED")
    end
end

local function StopActiveScan(keepLateListener)
    scanGeneration = scanGeneration + 1
    if scanTimer then scanTimer:Cancel(); scanTimer = nil end
    if scanWatchdog then scanWatchdog:Cancel(); scanWatchdog = nil end
    activeScan = nil
    UnregisterScanEvents(keepLateListener)
end

local function FailScan(status, keepLateListener)
    StopActiveScan(keepLateListener)
    scanState = { status = status, completedAt = Now() }
    ScanStatusChanged()
end

local function ScheduleFullExpiry()
    if fullExpiryTimer then fullExpiryTimer:Cancel(); fullExpiryTimer = nil end
    if not fullBatch then return end
    local failure = FullBatchFailure(fullBatch)
    if failure then
        if failure ~= "unverified" then ReleaseFullBatch(failure) end
        return
    end
    local ct = _G.C_Timer
    if not (type(ct) == "table" and type(ct.NewTimer) == "function") then return end
    local token = {}
    fullExpiryToken = token
    fullExpiryTimer = ct.NewTimer(max(1, fullBatch.t + SupplyMaxAge() + 1 - Now()), function()
        if fullExpiryToken ~= token then return end
        fullExpiryTimer = nil
        if not fullBatch then return end
        local failure2 = FullBatchFailure(fullBatch)
        if failure2 and failure2 ~= "unverified" then
            ReleaseFullBatch(failure2)
            SupplyChanged(nil)
        else
            ScheduleFullExpiry()
        end
    end)
end

local function CachedReplicateCount()
    local ahFrame = _G.AuctionHouseFrame
    if type(ahFrame) == "table" and type(ahFrame.IsShown) == "function" and not ahFrame:IsShown() then
        return 0
    end
    local ah = _G.C_AuctionHouse
    local getNum = type(ah) == "table" and ah.GetNumReplicateItems or nil
    if type(getNum) ~= "function" then return 0 end
    local ok, count = pcall(getNum)
    if ok and WholeNumber(count) and count > 0 then
        return count
    end
    return 0
end

local function HasUnreadReplicateBuffer()
    if activeScan ~= nil then return false, 0 end
    local count = CachedReplicateCount()
    if count <= 0 then return false, 0 end
    local lastReq = tonumber(ScannerMeta().lastRequestAt) or 0
    if fullBatch and type(fullBatch.t) == "number" and lastReq > 0 and fullBatch.t >= lastReq then
        return false, 0
    end
    if not MarketKey() then return false, 0 end
    return true, count
end

function S.CooldownLeft()
    local meta = ScannerMeta()
    local last = tonumber(meta.lastRequestAt)
    if not last or last <= 0 then return 0 end
    local now = Now()
    if last > now then return 0 end
    return max(0, (last + CooldownSec()) - now)
end

function S.CanStartScan()
    if activeScan ~= nil then return false, "inProgress" end
    local ah = _G.C_AuctionHouse
    if type(ah) ~= "table" or type(ah.ReplicateItems) ~= "function" then
        return false, "unavailable"
    end
    if not MarketKey() then
        return false, "unverified"
    end
    local left = S.CooldownLeft()
    if left > 0 then
        local hasBuf = HasUnreadReplicateBuffer()
        if hasBuf then
            return true, "buffer"
        end
        return false, "cooldown", left
    end
    return true
end

local function BeginAggregation(scan)
    local profSet = BuildProfItemSet()
    local hasWhitelist = type(profSet) == "table" and next(profSet) ~= nil
    local itemIDs = {}
    for id in pairs(scan.rawByItem) do
        itemIDs[#itemIDs + 1] = id
    end
    scan.aggIDs = itemIDs
    scan.aggIndex = 1
    scan.items = {}
    scan.ref = {}
    scan.profSet = profSet
    scan.hasWhitelist = hasWhitelist
    scan.profCount = 0
    scan.refCount = 0
    scan.phase = "aggregate"
    scanState = { status = "processing", phase = "aggregate", pct = 0.70, done = 0, total = #itemIDs, startedAt = scan.startedAt }
    ScanStatusChanged()
end

local function ProcessScanSlice(generation)
    if generation ~= scanGeneration or not activeScan then return end
    scanTimer = nil
    local scan = activeScan
    if not scan.mk or scan.mk ~= MarketKey() then
        FailScan("unverified")
        return
    end

    local ah = _G.C_AuctionHouse
    local getInfo = type(ah) == "table" and ah.GetReplicateItemInfo or nil
    local getLink = type(ah) == "table" and ah.GetReplicateItemLink or nil
    local startMs = ClockMs()
    local budgetMs = FrameBudgetMs()
    local maxSlice = MaxRowsPerSlice()

    if scan.phase == "read" then
        if type(getInfo) ~= "function" then
            FailScan("unavailable")
            return
        end
        local processed = 0
        while scan.readIndex < scan.expected do
            local idx = scan.readIndex
            local ok, _, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, ownerFull, _, itemID = pcall(getInfo, idx)
            if ok then
                if (not WholeNumber(itemID) or itemID == 0) and type(getLink) == "function" then
                    local okL, link = pcall(getLink, idx)
                    if okL and type(link) == "string" then
                        itemID = tonumber(link:match("item:(%d+)"))
                    end
                end
                if WholeNumber(itemID) and itemID > 0 and WholeNumber(count) and count > 0
                    and type(buyout) == "number" and buyout == buyout and buyout > 0 and buyout < huge then
                    if not isOwnAuction(scan.ownerNames, owner, ownerFull) then
                        local unit = buyout / count
                        local bucket = scan.rawByItem[itemID]
                        if not bucket then
                            bucket = {}
                            scan.rawByItem[itemID] = bucket
                        end
                        bucket[unit] = (bucket[unit] or 0) + count
                    end
                end
            end
            scan.readIndex = idx + 1
            processed = processed + 1
            if processed >= maxSlice then break end
            if processed % 64 == 0 and (ClockMs() - startMs) >= budgetMs then break end
        end

        local pct = scan.expected > 0 and (0.05 + 0.65 * (scan.readIndex / scan.expected)) or 0.70
        scanState = {
            status = "scanning",
            phase = "read",
            pct = pct,
            done = scan.readIndex,
            total = scan.expected,
            startedAt = scan.startedAt,
        }
        ScanStatusChanged()

        if scan.readIndex < scan.expected then
            local ct = _G.C_Timer
            if type(ct) == "table" and type(ct.NewTimer) == "function" then
                scanTimer = ct.NewTimer(0, function() ProcessScanSlice(generation) end)
            else
                FailScan("unavailable")
            end
            return
        end

        BeginAggregation(scan)
        local ct = _G.C_Timer
        if type(ct) == "table" and type(ct.NewTimer) == "function" then
            scanTimer = ct.NewTimer(0, function() ProcessScanSlice(generation) end)
        else
            FailScan("unavailable")
        end
        return
    end

    if scan.phase == "aggregate" then
        local totalIDs = #scan.aggIDs
        local processed = 0
        while scan.aggIndex <= totalIDs do
            local id = scan.aggIDs[scan.aggIndex]
            local byPrice = scan.rawByItem[id]
            if type(byPrice) == "table" then
                local prices = {}
                local rawQty = 0
                for p, q in pairs(byPrice) do
                    if q > 0 then
                        prices[#prices + 1] = p
                        rawQty = rawQty + q
                    end
                end
                if rawQty > 0 then
                    table.sort(prices)
                    local depth = {}
                    for i = 1, #prices do
                        local p = prices[i]
                        depth[i] = { p, byPrice[p] }
                    end
                    local _, dq = S.TrimFishingOrders(depth)
                    local robust = S.RobustReferencePrice(depth)
                    if type(robust) ~= "number" or robust <= 0 then
                        robust = depth[1][1]
                    end
                    if not scan.hasWhitelist or scan.profSet[id] then
                        scan.items[id] = {
                            p = robust,
                            q = rawQty,
                            dq = dq,
                            d = depth,
                        }
                        scan.profCount = scan.profCount + 1
                    else
                        scan.ref[id] = {
                            p = robust,
                            q = rawQty,
                        }
                        scan.refCount = scan.refCount + 1
                    end
                end
            end
            scan.rawByItem[id] = nil
            scan.aggIndex = scan.aggIndex + 1
            processed = processed + 1
            if processed >= 800 then break end
            if processed % 64 == 0 and (ClockMs() - startMs) >= budgetMs then break end
        end

        local aggDone = scan.aggIndex - 1
        local aggPct = totalIDs > 0 and (0.70 + 0.30 * (aggDone / totalIDs)) or 1.0
        scanState = {
            status = "processing",
            phase = "aggregate",
            pct = aggPct,
            done = aggDone,
            total = totalIDs,
            startedAt = scan.startedAt,
        }
        ScanStatusChanged()

        if scan.aggIndex <= totalIDs then
            local ct = _G.C_Timer
            if type(ct) == "table" and type(ct.NewTimer) == "function" then
                scanTimer = ct.NewTimer(0, function() ProcessScanSlice(generation) end)
            else
                FailScan("unavailable")
            end
            return
        end

        local completedAt = Now()
        if completedAt < scan.observedAt then completedAt = scan.observedAt end
        local candidate = {
            v = SnapshotVersion(),
            dv = 1,
            c = true,
            s = "client-auction-results",
            ox = true,
            method = "native-replicate-scan",
            t = scan.observedAt,
            completedAt = completedAt,
            mk = scan.mk,
            ob = scan.ob,
            expected = scan.expected,
            received = scan.expected,
            items = scan.items,
            ref = scan.ref,
        }
        if not ValidSavedBatch(candidate) or not StoreBatch(candidate) then
            FailScan("incomplete")
            return
        end
        PruneLegacyBatch(candidate)
        fullBatch = candidate
        fullFailure = nil
        restoredSnapshot = false
        StopActiveScan()
        ScheduleFullExpiry()
        scanState = {
            status = "complete",
            observedAt = candidate.t,
            profItems = scan.profCount,
            refItems = scan.refCount,
        }
        Say(format(tr("行情扫描完成：专业物品 %d 种（含深度），其他物品 %d 种。"), scan.profCount, scan.refCount))
        ScanStatusChanged()
        SupplyChanged(nil)
    end
end

local function BeginReadFromReplicateBuffer(scan, count)
    if scanWatchdog then scanWatchdog:Cancel(); scanWatchdog = nil end
    scan.expected = count
    local now = Now()
    scan.observedAt = now > 0 and now or scan.startedAt
    scan.phase = "read"
    scan.readIndex = 0
    scan.rawByItem = {}
    scanState = { status = "scanning", phase = "read", pct = 0.05, done = 0, total = count, startedAt = scan.startedAt }
    ScanStatusChanged()
    local gen = scanGeneration
    local ct = _G.C_Timer
    if type(ct) == "table" and type(ct.NewTimer) == "function" then
        scanTimer = ct.NewTimer(0, function() ProcessScanSlice(gen) end)
    else
        FailScan("unavailable")
    end
end

local function OnReplicateListUpdate()
    local ah = _G.C_AuctionHouse
    local getNum = type(ah) == "table" and ah.GetNumReplicateItems or nil
    if type(getNum) ~= "function" then
        if activeScan and activeScan.phase == "wait" then
            FailScan("unavailable")
        end
        return
    end
    local ok, count = pcall(getNum)
    if not ok or not WholeNumber(count) then
        if activeScan and activeScan.phase == "wait" then
            FailScan("incomplete")
        end
        return
    end

    local scan = activeScan
    if scan and scan.phase == "wait" then
        BeginReadFromReplicateBuffer(scan, count)
        return
    end

    -- 延迟救援：若等待超时后服务器才把 49 万+ 全量数据传完且拍卖行仍开着，自动接管读取，不浪费 15 分钟冷却
    if not scan and count > 0 and scanState and scanState.status == "noresponse" then
        local mk = MarketKey()
        if not mk then return end
        if SelectMarket then SelectMarket() end
        local now = Now()
        scanGeneration = scanGeneration + 1
        activeScan = {
            phase = "wait",
            startedAt = now,
            mk = mk,
            ob = ObserverKey(),
            ownerNames = PlayerOwnerNames(),
        }
        Say(format(tr("收到服务器延迟返回的全量行情（%d 条），正在自动整理…"), count))
        BeginReadFromReplicateBuffer(activeScan, count)
    end
end

local function EnsureScanEventFrame()
    if scanEventFrame then return scanEventFrame end
    if type(_G.CreateFrame) ~= "function" then return nil end
    local ok, frame = pcall(_G.CreateFrame, "Frame")
    if not ok or type(frame) ~= "table" then return nil end
    frame:SetScript("OnEvent", function(_, event)
        if event == "REPLICATE_ITEM_LIST_UPDATE" then
            OnReplicateListUpdate()
        elseif event == "AUCTION_HOUSE_CLOSED" then
            if activeScan and (activeScan.phase == "wait" or activeScan.phase == "read") then
                FailScan("cancelled")
                Say(tr("拍卖行已关闭，本次扫描已取消。"))
            elseif not activeScan then
                UnregisterScanEvents(false)
            end
        end
    end)
    scanEventFrame = frame
    return scanEventFrame
end

function S.StartScan()
    local ok, reason, left = S.CanStartScan()
    if not ok then
        return false, reason, left
    end
    local ah = _G.C_AuctionHouse
    local mk = MarketKey()
    if SelectMarket then SelectMarket() end
    StopActiveScan(false)

    local now = Now()
    -- 冷却期内但客户端已收到上次请求的全量缓存时，直接读取内存缓存，免再次触发服务器冷却
    if reason == "buffer" then
        local bufCount = CachedReplicateCount()
        if bufCount > 0 then
            scanGeneration = scanGeneration + 1
            activeScan = {
                phase = "wait",
                startedAt = now,
                mk = mk,
                ob = ObserverKey(),
                ownerNames = PlayerOwnerNames(),
            }
            local evFrame = EnsureScanEventFrame()
            if evFrame then
                pcall(evFrame.RegisterEvent, evFrame, "AUCTION_HOUSE_CLOSED")
            end
            Say(format(tr("检测到拍卖行全量缓存（%d 条），正在直接整理…"), bufCount))
            BeginReadFromReplicateBuffer(activeScan, bufCount)
            return true
        end
    end

    local prevCount = CachedReplicateCount()
    ScannerMeta().lastRequestAt = now
    scanGeneration = scanGeneration + 1
    local gen = scanGeneration
    activeScan = {
        phase = "wait",
        startedAt = now,
        mk = mk,
        ob = ObserverKey(),
        ownerNames = PlayerOwnerNames(),
        prevReplicateCount = prevCount,
    }
    scanState = { status = "scanning", phase = "wait", pct = 0, startedAt = now }

    local evFrame = EnsureScanEventFrame()
    if evFrame then
        pcall(evFrame.RegisterEvent, evFrame, "REPLICATE_ITEM_LIST_UPDATE")
        pcall(evFrame.RegisterEvent, evFrame, "AUCTION_HOUSE_CLOSED")
    end

    local ct = _G.C_Timer
    if type(ct) == "table" and type(ct.NewTimer) == "function" then
        scanWatchdog = ct.NewTimer(ScanSilentSec(), function()
            scanWatchdog = nil
            if scanGeneration ~= gen or not activeScan or activeScan.phase ~= "wait" then return end
            -- 超时前先检查客户端是否已经静默收齐缓存（避免大服刚下完就被误判超时）
            local curCount = CachedReplicateCount()
            if curCount > 0 and (prevCount == 0 or curCount ~= prevCount) then
                BeginReadFromReplicateBuffer(activeScan, curCount)
                return
            end
            -- 保留被动监听：若拍卖行未关闭且服务器稍后才返回，仍自动接管整理
            FailScan("noresponse", true)
        end)
    end

    ScanStatusChanged()
    local callOk, err = pcall(ah.ReplicateItems)
    if not callOk then
        FailScan("failed")
        return false, err
    end
    return true
end

local scanBtn, scanTicker

local SOLID_TEX = "Interface\\Buttons\\WHITE8x8"

local function formatCooldown(sec)
    sec = max(0, floor(sec + 0.5))
    local m = floor(sec / 60)
    local s = sec % 60
    return format("%02d:%02d", m, s)
end

local function setTexColor(tex, r, g, b, a)
    if not tex then return end
    if type(tex.SetColorTexture) == "function" then
        tex:SetColorTexture(r, g, b, a or 1)
    elseif type(tex.SetTexture) == "function" and type(tex.SetVertexColor) == "function" then
        tex:SetTexture(SOLID_TEX)
        tex:SetVertexColor(r, g, b, a or 1)
    end
end

local function clearTemplateTextures(btn)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local reg = btn[key]
        if type(reg) == "table" then
            if reg.SetAlpha then pcall(reg.SetAlpha, reg, 0) end
            if reg.Hide then pcall(reg.Hide, reg) end
        end
    end
    for _, method in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        if type(btn[method]) == "function" then
            local ok, tex = pcall(btn[method], btn)
            if ok and type(tex) == "table" then
                if tex.SetTexture then pcall(tex.SetTexture, tex, nil) end
                if tex.SetAlpha then pcall(tex.SetAlpha, tex, 0) end
                if tex.Hide then pcall(tex.Hide, tex) end
            end
        end
    end
end

local function resolveTitleFont(ahFrame)
    local sb = type(ahFrame) == "table" and ahFrame.SearchBar or nil
    local sbtn = type(sb) == "table" and sb.SearchButton or nil
    if type(sbtn) == "table" and type(sbtn.GetFontString) == "function" then
        local ok, fs = pcall(sbtn.GetFontString, sbtn)
        if ok and type(fs) == "table" and type(fs.GetFont) == "function" then
            local okF, fontPath = pcall(fs.GetFont, fs)
            if okF and type(fontPath) == "string" and fontPath ~= "" then
                return fontPath
            end
        end
    end
    local gf = _G.GameFontNormalSmall
    if type(gf) == "table" and type(gf.GetFont) == "function" then
        local okF, fontPath = pcall(gf.GetFont, gf)
        if okF and type(fontPath) == "string" and fontPath ~= "" then
            return fontPath
        end
    end
    return _G.STANDARD_TEXT_FONT or "Fonts\\ARKai_T.ttf"
end

local function setupScanButtonVisual(btn, ahFrame)
    clearTemplateTextures(btn)
    local vis = btn._dfVisual
    if type(vis) ~= "table" then
        if type(btn.CreateTexture) ~= "function" or type(btn.CreateFontString) ~= "function" then
            return nil
        end
        local okBg, bg = pcall(btn.CreateTexture, btn, nil, "BACKGROUND")
        local okProg, prog = pcall(btn.CreateTexture, btn, nil, "ARTWORK")
        local okDot, dot = pcall(btn.CreateTexture, btn, nil, "OVERLAY")
        local okTop, top = pcall(btn.CreateTexture, btn, nil, "OVERLAY")
        local okBot, bot = pcall(btn.CreateTexture, btn, nil, "OVERLAY")
        local okLeft, left = pcall(btn.CreateTexture, btn, nil, "OVERLAY")
        local okRight, right = pcall(btn.CreateTexture, btn, nil, "OVERLAY")
        local okLbl, label = pcall(btn.CreateFontString, btn, nil, "OVERLAY")
        if not (okBg and bg and okProg and prog and okDot and dot and okTop and top and okBot and bot and okLeft and left and okRight and right and okLbl and label) then
            return nil
        end
        if type(bg.SetAllPoints) == "function" then bg:SetAllPoints(btn) end
        if type(prog.SetPoint) == "function" then
            prog:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
            prog:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
            prog:SetWidth(1)
            if prog.Hide then prog:Hide() end
        end
        if type(top.SetPoint) == "function" and type(top.SetHeight) == "function" then
            top:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
            top:SetHeight(1)
            bot:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
            bot:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
            bot:SetHeight(1)
            left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -1)
            left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 1)
            left:SetWidth(1)
            right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -1)
            right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 1)
            right:SetWidth(1)
        end
        if type(dot.SetSize) == "function" and type(dot.SetPoint) == "function" then
            dot:SetSize(6, 6)
            dot:SetPoint("LEFT", btn, "LEFT", 8, 0)
        end
        if type(btn.GetFontString) == "function" then
            local okOld, oldFs = pcall(btn.GetFontString, btn)
            if okOld and type(oldFs) == "table" and oldFs ~= label then
                if oldFs.SetAlpha then pcall(oldFs.SetAlpha, oldFs, 0) end
                if oldFs.Hide then pcall(oldFs.Hide, oldFs) end
            end
        end
        if type(label.SetPoint) == "function" then
            if label.ClearAllPoints then label:ClearAllPoints() end
            label:SetPoint("LEFT", dot, "RIGHT", 5, 0)
            label:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
            if label.SetJustifyH then label:SetJustifyH("CENTER") end
            if label.SetJustifyV then label:SetJustifyV("MIDDLE") end
            if label.SetWordWrap then label:SetWordWrap(false) end
        end
        if type(btn.SetFontString) == "function" then
            pcall(btn.SetFontString, btn, label)
        end
        vis = {
            bg = bg,
            prog = prog,
            dot = dot,
            borders = { top, bot, left, right },
            label = label,
        }
        btn._dfVisual = vis
    end
    local fontPath = resolveTitleFont(ahFrame)
    if vis.label and type(vis.label.SetFont) == "function" then
        pcall(vis.label.SetFont, vis.label, fontPath, 12, "")
    end
    return vis
end

local function applyScanButtonStyle(btn, mode, pct)
    local vis = btn._dfVisual
    if type(vis) ~= "table" then return end
    local hovered = btn._hovered == true
    local pressed = btn._pressed == true
    local bgR, bgG, bgB, bgA
    local bdR, bdG, bdB, bdA
    local txR, txG, txB
    local dtR, dtG, dtB

    if mode == "wait" then
        bgR, bgG, bgB, bgA = 0.11, 0.14, 0.19, 0.94
        bdR, bdG, bdB, bdA = 0.34, 0.66, 0.92, 0.92
        txR, txG, txB = 0.86, 0.94, 1.00
        dtR, dtG, dtB = 0.42, 0.78, 1.00
        if vis.prog then
            local maxW = (btn.GetWidth and btn:GetWidth() or 116) - 2
            if vis.prog.SetWidth then vis.prog:SetWidth(max(8, maxW * 0.25)) end
            setTexColor(vis.prog, 0.26, 0.56, 0.84, 0.35)
            if vis.prog.Show then vis.prog:Show() end
        end
    elseif mode == "scanning" or mode == "processing" then
        bgR, bgG, bgB, bgA = 0.11, 0.14, 0.19, 0.94
        bdR, bdG, bdB, bdA = 0.32, 0.62, 0.85, 0.90
        txR, txG, txB = 0.88, 0.95, 1.00
        dtR, dtG, dtB = 0.38, 0.75, 0.96
        if vis.prog then
            local maxW = (btn.GetWidth and btn:GetWidth() or 116) - 2
            local frac = max(0.05, min(1, tonumber(pct) or 0.05))
            if vis.prog.SetWidth then vis.prog:SetWidth(max(1, maxW * frac)) end
            setTexColor(vis.prog, 0.22, 0.50, 0.74, 0.42)
            if vis.prog.Show then vis.prog:Show() end
        end
    elseif mode == "cooldown" then
        bgR, bgG, bgB, bgA = hovered and 0.13 or 0.10, hovered and 0.14 or 0.11, hovered and 0.17 or 0.13, 0.86
        bdR, bdG, bdB, bdA = hovered and 0.36 or 0.24, hovered and 0.38 or 0.25, hovered and 0.44 or 0.29, hovered and 0.85 or 0.72
        txR, txG, txB = hovered and 0.70 or 0.58, hovered and 0.72 or 0.60, hovered and 0.77 or 0.65
        dtR, dtG, dtB = 0.42, 0.44, 0.48
        if vis.prog and vis.prog.Hide then vis.prog:Hide() end
    else
        if pressed then
            bgR, bgG, bgB, bgA = 0.11, 0.12, 0.14, 0.98
        elseif hovered then
            bgR, bgG, bgB, bgA = 0.20, 0.21, 0.25, 0.98
        else
            bgR, bgG, bgB, bgA = 0.14, 0.15, 0.18, 0.94
        end
        bdR, bdG, bdB, bdA = hovered and 0.92 or 0.68, hovered and 0.76 or 0.55, hovered and 0.36 or 0.28, hovered and 1.0 or 0.82
        txR, txG, txB = hovered and 1.0 or 0.98, hovered and 0.93 or 0.86, hovered and 0.65 or 0.46
        local snap = S.FullScanSnapshotStatus and S.FullScanSnapshotStatus()
        if snap and snap.status == "available" then
            dtR, dtG, dtB = 0.30, 0.82, 0.52
        else
            dtR, dtG, dtB = 0.95, 0.72, 0.25
        end
        if vis.prog and vis.prog.Hide then vis.prog:Hide() end
    end

    setTexColor(vis.bg, bgR, bgG, bgB, bgA)
    for _, edge in ipairs(vis.borders or {}) do
        setTexColor(edge, bdR, bdG, bdB, bdA)
    end
    setTexColor(vis.dot, dtR, dtG, dtB, 1)
    if vis.label and type(vis.label.SetTextColor) == "function" then
        vis.label:SetTextColor(txR, txG, txB, 1)
    end
end

local scanBanner, bannerHideTimer

local function cancelBannerTimer()
    if bannerHideTimer then
        bannerHideTimer:Cancel()
        bannerHideTimer = nil
    end
end

local function EnsureScanBanner()
    local ahFrame = _G.AuctionHouseFrame
    if type(ahFrame) ~= "table" or type(_G.CreateFrame) ~= "function" then return nil end
    local existing = scanBanner or _G.DFProfAHScanBanner
    local b = existing
    if type(b) ~= "table" then
        local ok, created = pcall(_G.CreateFrame, "Frame", "DFProfAHScanBanner", ahFrame)
        if not ok or type(created) ~= "table" then return nil end
        b = created
    end
    scanBanner = b
    if type(b.CreateTexture) ~= "function" or type(b.CreateFontString) ~= "function" then
        return b
    end
    b:SetSize(456, 56)
    b:ClearAllPoints()
    b:SetPoint("BOTTOM", ahFrame, "TOP", 0, 8)
    if b.SetFrameLevel and ahFrame.GetFrameLevel then
        local closeLvl = type(ahFrame.CloseButton) == "table" and ahFrame.CloseButton.GetFrameLevel and ahFrame.CloseButton:GetFrameLevel() or 510
        local topLvl = max((ahFrame:GetFrameLevel() or 1) + 12, closeLvl + 2)
        pcall(b.SetFrameLevel, b, topLvl)
    end
    if type(b._dfVis) ~= "table" then
        local okBg, bg = pcall(b.CreateTexture, b, nil, "BACKGROUND")
        local okAcc, accent = pcall(b.CreateTexture, b, nil, "ARTWORK")
        local okDot, dot = pcall(b.CreateTexture, b, nil, "OVERLAY")
        local okTrk, track = pcall(b.CreateTexture, b, nil, "ARTWORK")
        local okFill, fill = pcall(b.CreateTexture, b, nil, "OVERLAY")
        local okT, tEdge = pcall(b.CreateTexture, b, nil, "OVERLAY")
        local okB, bEdge = pcall(b.CreateTexture, b, nil, "OVERLAY")
        local okL, lEdge = pcall(b.CreateTexture, b, nil, "OVERLAY")
        local okR, rEdge = pcall(b.CreateTexture, b, nil, "OVERLAY")
        local okTitle, titleFS = pcall(b.CreateFontString, b, nil, "OVERLAY")
        local okSub, subFS = pcall(b.CreateFontString, b, nil, "OVERLAY")
        local okRight, rightFS = pcall(b.CreateFontString, b, nil, "OVERLAY")
        if not (okBg and bg and okAcc and accent and okDot and dot and okTrk and track and okFill and fill
            and okT and tEdge and okB and bEdge and okL and lEdge and okR and rEdge
            and okTitle and titleFS and okSub and subFS and okRight and rightFS) then
            return b
        end
        bg:SetAllPoints(b)
        setTexColor(bg, 0.08, 0.09, 0.11, 0.96)
        tEdge:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        tEdge:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
        tEdge:SetHeight(1)
        bEdge:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        bEdge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
        bEdge:SetHeight(1)
        lEdge:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -1)
        lEdge:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 1)
        lEdge:SetWidth(1)
        rEdge:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -1)
        rEdge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 1)
        rEdge:SetWidth(1)

        accent:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
        accent:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 4)
        accent:SetWidth(3)

        dot:SetSize(7, 7)
        dot:SetPoint("TOPLEFT", b, "TOPLEFT", 14, -12)

        rightFS:SetPoint("TOPRIGHT", b, "TOPRIGHT", -14, -10)
        rightFS:SetJustifyH("RIGHT")

        titleFS:SetPoint("LEFT", dot, "RIGHT", 7, 0)
        titleFS:SetPoint("RIGHT", rightFS, "LEFT", -8, 0)
        titleFS:SetJustifyH("LEFT")
        titleFS:SetWordWrap(false)

        subFS:SetPoint("TOPLEFT", dot, "BOTTOMLEFT", 0, -6)
        subFS:SetPoint("TOPRIGHT", b, "TOPRIGHT", -14, -27)
        subFS:SetJustifyH("LEFT")
        subFS:SetWordWrap(false)

        track:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 1, 1)
        track:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        track:SetHeight(3)
        setTexColor(track, 0.15, 0.17, 0.21, 0.95)

        fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
        fill:SetWidth(40)

        b._dfVis = {
            bg = bg,
            accent = accent,
            dot = dot,
            track = track,
            fill = fill,
            borders = { tEdge, bEdge, lEdge, rEdge },
            titleFS = titleFS,
            subFS = subFS,
            rightFS = rightFS,
        }
        b:Hide()
    end
    local vis = b._dfVis
    local fontPath = resolveTitleFont(ahFrame)
    if vis.titleFS.SetFont then pcall(vis.titleFS.SetFont, vis.titleFS, fontPath, 13, "") end
    if vis.subFS.SetFont then pcall(vis.subFS.SetFont, vis.subFS, fontPath, 11, "") end
    if vis.rightFS.SetFont then pcall(vis.rightFS.SetFont, vis.rightFS, fontPath, 12, "") end
    b:SetScript("OnUpdate", function(self)
        local v = self._dfVis
        if type(v) ~= "table" or self._dfMode ~= "wait" then return end
        local t = _G.GetTime and _G.GetTime() or 0
        local pulse = 0.50 + 0.50 * (0.5 + 0.5 * math.sin(t * 4.2))
        if v.dot and v.dot.SetAlpha then v.dot:SetAlpha(pulse) end
        local tw = (v.track and v.track.GetWidth and v.track:GetWidth()) or 454
        if tw > 20 and v.fill then
            local barW = floor(tw * 0.28)
            local u = 0.5 - 0.5 * math.cos(t * 2.6)
            local offset = u * (tw - barW)
            v.fill:ClearAllPoints()
            v.fill:SetPoint("TOPLEFT", v.track, "TOPLEFT", offset, 0)
            v.fill:SetPoint("BOTTOMLEFT", v.track, "BOTTOMLEFT", offset, 0)
            v.fill:SetWidth(barW)
        end
    end)
    return b
end

UpdateScanBanner = function(overrideState)
    local ahFrame = _G.AuctionHouseFrame
    if type(ahFrame) ~= "table" or not (ahFrame.IsShown and ahFrame:IsShown()) then
        if scanBanner and scanBanner.Hide then
            scanBanner._dfMode = "hidden"
            scanBanner:Hide()
        end
        cancelBannerTimer()
        return
    end
    local b = scanBanner or _G.DFProfAHScanBanner
    local stObj = overrideState or scanState or {}
    local st = stObj.status or "ready"
    local isActive = overrideState ~= nil or activeScan ~= nil
    local mode
    local title, sub, rightText
    local acR, acG, acB
    local bdR, bdG, bdB, bdA = 0.28, 0.31, 0.38, 0.90
    local subR, subG, subB = 0.72, 0.76, 0.82
    local rightR, rightG, rightB = 0.85, 0.92, 0.98
    local fillFrac = 0

    if (st == "scanning" or st == "processing") and isActive then
        cancelBannerTimer()
        local phase = stObj.phase or (overrideState == nil and activeScan and activeScan.phase) or (st == "processing" and "aggregate" or "read")
        if phase == "wait" then
            mode = "wait"
            local elapsed = max(0, Now() - (stObj.startedAt or Now()))
            title = tr("正在向服务器请求拍卖行数据…")
            sub = tr("服务器正在打包全量数据（大服高峰期约 30–120 秒），请勿关闭拍卖行。")
            rightText = format(tr("已等待 %02d:%02d"), floor(elapsed / 60), elapsed % 60)
            acR, acG, acB = 0.36, 0.74, 0.98
            bdR, bdG, bdB, bdA = 0.28, 0.56, 0.80, 0.88
            subR, subG, subB = 0.92, 0.84, 0.58
            rightR, rightG, rightB = 0.52, 0.84, 1.00
        else
            mode = phase
            fillFrac = max(0.05, min(1, tonumber(stObj.pct) or 0.1))
            local p = floor(fillFrac * 100 + 0.5)
            title = (st == "processing" or phase == "aggregate") and tr("正在整理挂单深度与参考价…") or tr("正在读取拍卖行挂单数据…")
            sub = tr("已收到服务器数据，正在分帧整理，请保持拍卖行开启片刻。")
            rightText = format("%d%%", min(100, max(0, p)))
            acR, acG, acB = 0.34, 0.76, 0.96
            bdR, bdG, bdB, bdA = 0.28, 0.56, 0.80, 0.88
            subR, subG, subB = 0.74, 0.79, 0.86
            rightR, rightG, rightB = 0.62, 0.88, 1.00
        end
    elseif st == "complete" and stObj.bannerDismissed ~= true then
        mode = "complete"
        fillFrac = 1
        title = tr("行情扫描完成")
        sub = format(tr("专业物品 %d 种（含深度） · 其他 %d 种，价格与路线数据已更新。"), tonumber(stObj.profItems) or 0, tonumber(stObj.refItems) or 0)
        rightText = tr("完成")
        acR, acG, acB = 0.30, 0.82, 0.52
        bdR, bdG, bdB, bdA = 0.26, 0.64, 0.42, 0.88
        subR, subG, subB = 0.64, 0.88, 0.72
        rightR, rightG, rightB = 0.36, 0.90, 0.58
    elseif (st == "noresponse" or st == "failed") and stObj.bannerDismissed ~= true then
        mode = "warn"
        fillFrac = 1
        title = tr("服务器未返回扫描数据")
        sub = tr("距上次扫描不足 15 分钟时服务器会忽略请求，请冷却后再试。")
        rightText = tr("扫描冷却 %s"):format(formatCooldown(S.CooldownLeft()))
        acR, acG, acB = 0.94, 0.62, 0.28
        bdR, bdG, bdB, bdA = 0.72, 0.46, 0.22, 0.88
        subR, subG, subB = 0.92, 0.76, 0.54
        rightR, rightG, rightB = 0.96, 0.68, 0.34
    elseif st == "cancelled" and stObj.bannerDismissed ~= true then
        mode = "warn"
        fillFrac = 1
        title = tr("本次扫描已取消")
        sub = tr("拍卖行已关闭，已保留上次有效扫描数据。")
        rightText = ""
        acR, acG, acB = 0.94, 0.62, 0.28
        bdR, bdG, bdB, bdA = 0.72, 0.46, 0.22, 0.88
        subR, subG, subB = 0.88, 0.74, 0.56
        rightR, rightG, rightB = 0.94, 0.66, 0.36
    else
        if b and b.Hide then
            b._dfMode = "hidden"
            b:Hide()
        end
        cancelBannerTimer()
        return
    end

    if not b then
        b = EnsureScanBanner()
    else
        b = EnsureScanBanner()
    end
    if not b or type(b._dfVis) ~= "table" then return end
    local v = b._dfVis
    b._dfMode = mode

    for _, edge in ipairs(v.borders) do setTexColor(edge, bdR, bdG, bdB, bdA) end
    setTexColor(v.accent, acR, acG, acB, 0.95)
    setTexColor(v.dot, acR, acG, acB, 1)
    if mode ~= "wait" and v.dot.SetAlpha then v.dot:SetAlpha(1) end
    setTexColor(v.fill, acR, acG, acB, 0.95)

    v.titleFS:SetText(title)
    if v.titleFS.SetTextColor then v.titleFS:SetTextColor(0.95, 0.96, 0.98, 1) end
    v.subFS:SetText(sub)
    if v.subFS.SetTextColor then v.subFS:SetTextColor(subR, subG, subB, 1) end
    v.rightFS:SetText(rightText)
    if v.rightFS.SetTextColor then v.rightFS:SetTextColor(rightR, rightG, rightB, 1) end

    if mode ~= "wait" then
        local tw = (v.track and v.track.GetWidth and v.track:GetWidth()) or 454
        if tw <= 0 then tw = 454 end
        v.fill:ClearAllPoints()
        v.fill:SetPoint("TOPLEFT", v.track, "TOPLEFT", 0, 0)
        v.fill:SetPoint("BOTTOMLEFT", v.track, "BOTTOMLEFT", 0, 0)
        v.fill:SetWidth(max(2, tw * fillFrac))
    end

    b:Show()

    if (mode == "complete" or mode == "warn") and not overrideState and not bannerHideTimer then
        local ct = _G.C_Timer
        if type(ct) == "table" and type(ct.NewTimer) == "function" then
            bannerHideTimer = ct.NewTimer(mode == "complete" and 4.5 or 5.0, function()
                bannerHideTimer = nil
                if scanState and (scanState.status == "complete" or scanState.status == "noresponse" or scanState.status == "failed" or scanState.status == "cancelled") then
                    scanState.bannerDismissed = true
                end
                if not activeScan and b and b.Hide then
                    b._dfMode = "hidden"
                    b:Hide()
                end
            end)
        end
    end
end

S.PreviewScanBanner = UpdateScanBanner

UpdateScanButton = function()
    if not scanBtn then return end
    local st = scanState and scanState.status or "ready"
    local left = S.CooldownLeft()
    local labelText, mode, pct
    if activeScan and st == "scanning" then
        local phase = scanState.phase or activeScan.phase
        if phase == "wait" then
            local elapsed = max(0, Now() - (scanState.startedAt or Now()))
            labelText = format(tr("等待响应 %ds"), elapsed)
            mode = "wait"
        else
            local rawPct = tonumber(scanState.pct) or 0
            local p = floor(rawPct * 100 + 0.5)
            labelText = format(tr("扫描中 %d%%"), min(99, max(0, p)))
            mode, pct = "scanning", rawPct
        end
        if scanBtn.Disable then scanBtn:Disable() end
    elseif activeScan and st == "processing" then
        local done = tonumber(scanState.done) or 0
        local total = tonumber(scanState.total) or 1
        local frac = tonumber(scanState.pct) or (total > 0 and (0.70 + 0.30 * (done / total)) or 0.70)
        local p = floor(frac * 100 + 0.5)
        labelText = format(tr("整理中 %d%%"), min(100, max(0, p)))
        mode, pct = "processing", frac
        if scanBtn.Disable then scanBtn:Disable() end
    elseif left > 0 then
        local hasBuf = HasUnreadReplicateBuffer()
        if hasBuf then
            labelText = tr("读取已缓存行情")
            mode = "ready"
            if scanBtn.Enable then scanBtn:Enable() end
        else
            labelText = format(tr("扫描冷却 %s"), formatCooldown(left))
            mode = "cooldown"
            if scanBtn.Disable then scanBtn:Disable() end
        end
    else
        labelText = tr("扫描行情")
        mode = "ready"
        if scanBtn.Enable then scanBtn:Enable() end
    end
    if scanBtn.SetText then scanBtn:SetText(labelText) end
    local vis = scanBtn._dfVisual
    if vis and vis.label and type(vis.label.SetText) == "function" then
        pcall(vis.label.SetText, vis.label, labelText)
    end
    applyScanButtonStyle(scanBtn, mode, pct)
end

local function StopButtonTicker()
    if scanTicker then
        scanTicker:Cancel()
        scanTicker = nil
    end
end

local function StartButtonTicker()
    if scanTicker then return end
    local ct = _G.C_Timer
    if type(ct) == "table" and type(ct.NewTicker) == "function" then
        scanTicker = ct.NewTicker(1, function()
            if not scanBtn or not (scanBtn.IsVisible and scanBtn:IsVisible()) then
                StopButtonTicker()
                return
            end
            UpdateScanButton()
            UpdateScanBanner()
            if S.CooldownLeft() <= 0 and not activeScan then
                StopButtonTicker()
            end
        end)
    end
end

local function configureScanButton(btn, ahFrame)
    scanBtn = btn
    btn:SetSize(116, 20)
    btn:ClearAllPoints()
    local closeBtn = ahFrame.CloseButton
    if type(closeBtn) == "table" then
        btn:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    else
        btn:SetPoint("TOPRIGHT", ahFrame, "TOPRIGHT", -36, -3)
    end
    if btn.SetFrameLevel and ahFrame.GetFrameLevel then
        local baseLvl = (ahFrame:GetFrameLevel() or 1) + 10
        local closeLvl = type(closeBtn) == "table" and closeBtn.GetFrameLevel and closeBtn:GetFrameLevel() or 0
        local titleLvl = type(ahFrame.TitleContainer) == "table" and ahFrame.TitleContainer.GetFrameLevel and ahFrame.TitleContainer:GetFrameLevel() or 0
        local topLvl = max(baseLvl, max(closeLvl, titleLvl) + 1)
        pcall(btn.SetFrameLevel, btn, topLvl)
    end
    if type(btn.SetMotionScriptsWhileDisabled) == "function" then
        pcall(btn.SetMotionScriptsWhileDisabled, btn, true)
    end
    setupScanButtonVisual(btn, ahFrame)
    btn:SetScript("OnClick", function()
        local started, reason, left = S.StartScan()
        if not started and reason == "cooldown" and left then
            Say(format(tr("距离上次扫描不足 15 分钟，请等待 %s 后再试。"), formatCooldown(left)))
        end
        StartButtonTicker()
    end)
    btn:SetScript("OnMouseDown", function(self)
        self._pressed = true
        UpdateScanButton()
    end)
    btn:SetScript("OnMouseUp", function(self)
        self._pressed = false
        UpdateScanButton()
    end)
    btn:SetScript("OnEnter", function(self)
        self._hovered = true
        UpdateScanButton()
        local tt = getTT()
        if tt and type(tt.ShowAuctionScanButtonTip) == "function" then
            tt.ShowAuctionScanButtonTip(self, S.FullScanSnapshotStatus(), Now(), S.CooldownLeft(), formatCooldown)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self._hovered = false
        self._pressed = false
        UpdateScanButton()
        local tt = getTT()
        if tt and type(tt.Hide) == "function" then tt.Hide() end
    end)
end

function S.EnsureScanButton()
    local ahFrame = _G.AuctionHouseFrame
    if type(ahFrame) ~= "table" or type(_G.CreateFrame) ~= "function" then return nil end
    if scanBtn then
        configureScanButton(scanBtn, ahFrame)
        UpdateScanButton()
        if S.CooldownLeft() > 0 or activeScan then StartButtonTicker() end
        return scanBtn
    end
    local existing = _G.DFProfAHScanButton
    if type(existing) == "table" then
        configureScanButton(existing, ahFrame)
        UpdateScanButton()
        if S.CooldownLeft() > 0 or activeScan then StartButtonTicker() end
        return existing
    end
    local ok, btn = pcall(_G.CreateFrame, "Button", "DFProfAHScanButton", ahFrame)
    if not ok or type(btn) ~= "table" then return nil end
    configureScanButton(btn, ahFrame)
    if ahFrame.HookScript and not ahFrame._dfScanBtnHooked then
        ahFrame._dfScanBtnHooked = true
        pcall(ahFrame.HookScript, ahFrame, "OnShow", function()
            UpdateScanButton()
            UpdateScanBanner()
            if S.CooldownLeft() > 0 or activeScan then StartButtonTicker() end
        end)
        pcall(ahFrame.HookScript, ahFrame, "OnHide", function()
            StopButtonTicker()
            cancelBannerTimer()
            if scanBanner and scanBanner.Hide then
                scanBanner._dfMode = "hidden"
                scanBanner:Hide()
            end
        end)
    end
    UpdateScanButton()
    UpdateScanBanner()
    if S.CooldownLeft() > 0 or activeScan then StartButtonTicker() end
    return btn
end

function S.ReplicateScanReady()
    local snap = S.FullScanSnapshotStatus()
    if snap.status == "available" then return true end
    if snap.status == "expired" then return false, "expired" end
    if snap.status == "mismatch" then return false, "mismatch" end
    if snap.status == "invalid" then return false, "invalid" end
    return false, "scanRequired"
end

function S.ReplicateScanEnabled()
    return true
end

function S.ObserveReplicateMode()
    return true, { enabled = true, generation = 1, scanSerial = 0 }
end

function S.ConnectAuctionatorStock()
    return true
end

function S.HookReplicateModeSetting()
    return true
end

SelectMarket = function()
    local key = MarketKey()
    if currentMarket == key then return end
    StopActiveScan()
    if fullExpiryTimer then fullExpiryTimer:Cancel(); fullExpiryTimer = nil end
    fullExpiryToken = nil
    forcedUntil = 0
    currentMarket = key
    fullBatch = nil
    fullFailure = nil
    restoredSnapshot = false
    scanState = { status = "ready" }
    local db = ScanDB()
    local saved = key and type(db.auctionFullScans) == "table" and db.auctionFullScans[key] or nil
    if saved == nil then saved = db.auctionFullScan end
    if saved == nil then return end
    restoredSnapshot = true

    if type(saved) == "table" and saved.v == 3 then
        if saved.c == true and ValidSavedBatch(saved, 3) then
            local upgraded = UpgradeV3Batch(saved)
            if upgraded and ValidSavedBatch(upgraded) then
                if key and type(db.auctionFullScans) == "table" then
                    db.auctionFullScans[key] = upgraded
                end
                PruneLegacyBatch(upgraded)
                fullBatch = upgraded
                ScheduleFullExpiry()
                return
            end
        elseif saved.failure == "expired" and WholeNumber(saved.t) and saved.t > 0 and Now() - saved.t > SupplyMaxAge() then
            local upgradedFail = UpgradeV3Batch(saved)
            if upgradedFail then
                if key and type(db.auctionFullScans) == "table" then
                    db.auctionFullScans[key] = upgradedFail
                end
                fullFailure = upgradedFail
                return
            end
        elseif saved.failure == "incomplete" and saved.snapshotStatus == "missing" then
            fullFailure = {
                v = SnapshotVersion(),
                failure = "incomplete",
                snapshotStatus = "missing",
                mk = saved.mk,
                ob = saved.ob,
                ox = saved.ox,
                t = saved.t,
            }
            return
        end
    end

    if ValidSavedBatch(saved) then
        if key and type(db.auctionFullScans) == "table" and db.auctionFullScans[key] == saved then
            PruneLegacyBatch(saved)
        end
        fullBatch = saved
        ScheduleFullExpiry()
    elseif type(saved) == "table" and saved.v == SnapshotVersion() and saved.items == nil
        and saved.failure == "incomplete" and saved.snapshotStatus == "missing" then
        fullFailure = saved
    elseif type(saved) == "table" and saved.v == SnapshotVersion()
        and saved.failure == "expired" and WholeNumber(saved.t) and saved.t > 0
        and Now() - saved.t > SupplyMaxAge() then
        fullFailure = saved
    else
        ReleaseFullBatch("incomplete", saved)
    end
end

function S.ClearSavedScans()
    StopActiveScan()
    local db = ScanDB()
    db.auctionFullScan = nil
    db.auctionFullScans = nil
    db.auctionScanner = nil
    if fullExpiryTimer then fullExpiryTimer:Cancel(); fullExpiryTimer = nil end
    fullExpiryToken = nil
    forcedUntil = 0
    fullBatch = nil
    fullFailure = nil
    restoredSnapshot = false
    currentMarket = false
    SelectMarket()
    scanState = { status = "ready" }
    ScanStatusChanged()
    SupplyChanged(nil)
    return true
end

local function InitializeScanner()
    local db = ScanDB()
    db.auctionReplicateGate = nil
    db.replicateRequiredAfter = nil
    SelectMarket()
    S.EnsureScanButton()
    if type(_G.CreateFrame) ~= "function" then return end
    local ok, frame = pcall(_G.CreateFrame, "Frame")
    if not ok or type(frame) ~= "table" then return end
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("AUCTION_HOUSE_SHOW")
    frame:SetScript("OnEvent", function(_, event, name)
        if event == "PLAYER_LOGIN" then
            SelectMarket()
            S.EnsureScanButton()
        elseif event == "AUCTION_HOUSE_SHOW" or (event == "ADDON_LOADED" and name == "Blizzard_AuctionHouseUI") then
            S.EnsureScanButton()
        end
    end)
end

local b = getBridge()
if b and type(b.OnInit) == "function" then
    b.OnInit(InitializeScanner)
    if type(_G.AuctionHouseFrame) == "table" and _G.AuctionHouseFrame.IsShown and _G.AuctionHouseFrame:IsShown() then
        S.EnsureScanButton()
    end
else
    InitializeScanner()
end
