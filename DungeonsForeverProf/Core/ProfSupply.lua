local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local M = {
    built = false,
    offerCount = 0,
    itemCount = 0,
    DataSchema = 2,
    SourceAccessSchema = 1,
    SourcePurchaseSchema = 1,
}
ns.ProfSupply = M
if type(gns) == "table" and gns ~= ns then
    gns.ProfSupply = M
end

local EMPTY = setmetatable({}, {
    __newindex = function() error("ProfSupply: EMPTY table is read-only", 2) end,
    __metatable = false,
})
local formulaFactsCache = setmetatable({}, { __mode = "k" })
local flushGen = 0
local liveCache = nil
local liveCacheStamp = nil
local liveCacheFaction = nil
local invalidating = false
local delegateInvalidate = nil
local ahPriceGuard = false

function M.CacheGen()
    return flushGen
end

local function isEmptyCtx(ctx)
    return ctx == nil or (type(ctx) == "table" and next(ctx) == nil)
end

local function getDS()
    return ns.ProfDataStore or (type(gns) == "table" and gns.ProfDataStore) or nil
end

local function getCond()
    return ns.ProfConditions or (type(gns) == "table" and gns.ProfConditions) or nil
end

local function getAPI()
    return ns.ProfAPI or (type(gns) == "table" and gns.ProfAPI) or nil
end

local function getPricingCfg()
    return ns.PricingConfig or (type(gns) == "table" and gns.PricingConfig) or nil
end

local function getRouteAuto()
    return ns.ProfRouteAuto or (type(gns) == "table" and gns.ProfRouteAuto) or nil
end

local function getRecovery()
    return ns.ProfRecovery or (type(gns) == "table" and gns.ProfRecovery) or nil
end

local AREA_TO_FACTION_BY_SIDE = {
    A = {
        [1519] = 72,
        [12]   = 72,
        [40]   = 72,
        [44]   = 72,
        [10]   = 72,
        [1537] = 47,
        [1]    = 47,
        [38]   = 47,
        [1657] = 69,
        [141]  = 69,
        [148]  = 69,
    },
    H = {
        [1637] = 76,
        [14]   = 76,
        [17]   = 76,
        [1638] = 81,
        [215]  = 81,
        [1497] = 68,
        [85]   = 68,
        [130]  = 68,
    },
    N = {
        [33]   = 21,
        [440]  = 369,
        [618]  = 577,
        [17]   = 470,
        [139]  = 529,
        [1377] = 609,
    },
}

local TRACKED_DISCOUNT_FACTIONS = {
    21, 47, 59, 68, 69, 72, 76, 81, 369, 470, 529, 576, 577, 609, 2586, 2587, 2740, 2758, 2787,
}

local function discountCfg()
    local cfg = getPricingCfg()
    return type(cfg) == "table" and type(cfg.VENDOR_DISCOUNT) == "table" and cfg.VENDOR_DISCOUNT or {}
end

function M.LegacyBarterRank(ctx)
    local dcfg = discountCfg()
    local maxRank = tonumber(dcfg.barterMaxRank) or 2
    if type(ctx) == "table" and ctx.barterRank ~= nil then
        local r = tonumber(ctx.barterRank)
        if r and r == r then
            return math.max(0, math.min(maxRank, math.floor(r)))
        end
    end
    local ct = _G.C_Traits
    if type(ct) == "table" and type(ct.GetConfigIDByTreeID) == "function" and type(ct.GetNodeInfo) == "function" then
        local treeID = tonumber(dcfg.legacyTreeID) or 1187
        local nodeID = tonumber(dcfg.barterNodeID) or 110286
        local okCfg, configID = pcall(ct.GetConfigIDByTreeID, treeID)
        if okCfg and type(configID) == "number" and configID > 0 then
            local okNode, info = pcall(ct.GetNodeInfo, configID, nodeID)
            if okNode and type(info) == "table" then
                local rank = tonumber(info.activeRank or info.currentRank or info.ranksPurchased) or 0
                return math.max(0, math.min(maxRank, math.floor(rank)))
            end
        end
    end
    return 0
end

function M.LegacyBarterMultiplier(ctx)
    local dcfg = discountCfg()
    local perRank = tonumber(dcfg.barterPerRank) or 0.05
    local rank = M.LegacyBarterRank(ctx)
    local mult = 1 - rank * perRank
    if mult < 0 then mult = 0 end
    if mult > 1 then mult = 1 end
    return mult
end

function M.FactionStanding(factionID, ctx)
    if type(factionID) ~= "number" or factionID <= 0 then return nil end
    if type(ctx) == "table" and type(ctx.reputations) == "table" then
        local entry = ctx.reputations[factionID]
        if type(entry) == "table" then
            return tonumber(entry.reaction or entry.standingID or entry.rank)
        elseif type(entry) == "number" then
            return entry
        end
        if ctx.strict == true then return nil end
    end
    local cr = _G.C_Reputation
    if type(cr) == "table" and type(cr.GetFactionDataByID) == "function" then
        local ok, data = pcall(cr.GetFactionDataByID, factionID)
        if ok and type(data) == "table" and type(data.reaction) == "number" then
            return data.reaction
        end
    end
    if type(_G.GetFactionInfoByID) == "function" then
        local ok, _, _, standing = pcall(_G.GetFactionInfoByID, factionID)
        if ok and type(standing) == "number" then
            return standing
        end
    end
    return nil
end

function M.FactionDiscountMultiplier(factionID, ctx)
    if type(factionID) ~= "number" or factionID <= 0 then return 1.0 end
    local standing = M.FactionStanding(factionID, ctx)
    local dcfg = discountCfg()
    local minStanding = tonumber(dcfg.honoredStanding) or 6
    local discount = tonumber(dcfg.honoredDiscount) or 0.10
    if type(standing) == "number" and standing >= minStanding then
        return math.max(0, 1 - discount)
    end
    return 1.0
end

local function firstReputationFaction(conds)
    if type(conds) ~= "table" then return nil end
    for i = 1, #conds do
        local c = conds[i]
        if type(c) == "table" and c.kind == "reputation" and type(c.factionID) == "number" and c.factionID > 0 then
            return c.factionID
        end
    end
    return nil
end

local function Int(v, minVal)
    return type(v) == "number" and v == v and v >= minVal and v < math.huge and v == math.floor(v)
end

local function Now()
    if type(_G.debugprofilestop) ~= "function" then return nil end
    local ok, v = pcall(_G.debugprofilestop)
    if ok and type(v) == "number" then return v end
    return nil
end

local function quietMs()
    local cfg = getPricingCfg()
    local cache = type(cfg) == "table" and cfg.CACHE or nil
    if type(cache) == "table" and type(cache.quietDebounceMs) == "number" and cache.quietDebounceMs > 0 then
        return cache.quietDebounceMs
    end
    return 300
end

local function getLiveCache(playerFaction)
    local now = Now()
    if not now then return nil end
    if liveCache and liveCacheFaction == playerFaction and liveCacheStamp and (now - liveCacheStamp) <= quietMs() then
        return liveCache
    end
    liveCache = { vp = {}, disp = {}, form = {} }
    liveCacheStamp = now
    liveCacheFaction = playerFaction
    return liveCache
end

local function normalizeFaction(raw)
    if raw == "A" or raw == "Alliance" or raw == "联盟" then return "A" end
    if raw == "H" or raw == "Horde" or raw == "部落" then return "H" end
    if raw == "N" or raw == "Neutral" or raw == "Both" then return "N" end
    return nil
end

local function resolvePlayerFaction(ctx)
    if type(ctx) == "table" then
        if ctx.faction ~= nil then
            return normalizeFaction(ctx.faction)
        end
        if ctx.strict == true then
            return nil
        end
    end
    if type(_G.UnitFactionGroup) == "function" then
        local ok, localized, english = pcall(_G.UnitFactionGroup, "player")
        if ok then
            return normalizeFaction(english) or normalizeFaction(localized)
        end
    end
    return nil
end

local function allowedFaction(side, mine)
    if side == nil or side == "N" or mine == nil then return true end
    return side == mine
end

local function copyCurrencies(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for i = 1, #raw do
        local c = raw[i]
        if type(c) == "table" then
            local cid = tonumber(c.currencyID or c.id)
            local amt = tonumber(c.amount ~= nil and c.amount or c.count) or 0
            if cid and cid > 0 then
                out[#out + 1] = {
                    currencyID = cid,
                    amount = amt,
                    id = cid,
                    count = amt,
                }
            end
        end
    end
    return out
end

local function copyCostItems(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for i = 1, #raw do
        local it = raw[i]
        if type(it) == "table" then
            local iid = tonumber(it.itemID or it.id)
            local cnt = tonumber(it.count ~= nil and it.count or it.amount) or 1
            if iid and iid > 0 then
                out[#out + 1] = {
                    itemID = iid,
                    count = cnt,
                    id = iid,
                }
            end
        end
    end
    return out
end

local function copyConditions(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for i = 1, #raw do
        local c = raw[i]
        if type(c) == "table" then
            local cp = {}
            for k, v in pairs(c) do
                if type(v) == "table" then
                    local sub = {}
                    for sk, sv in pairs(v) do
                        if type(sv) == "table" then
                            local sub2 = {}
                            for s2k, s2v in pairs(sv) do sub2[s2k] = s2v end
                            sub[sk] = sub2
                        else
                            sub[sk] = sv
                        end
                    end
                    cp[k] = sub
                else
                    cp[k] = v
                end
            end
            out[#out + 1] = cp
        end
    end
    return out
end

local function copyOffer(offer, currencies, costItems)
    local out = {}
    for k, v in pairs(offer) do
        if k == "currencies" then
            out.currencies = currencies
        elseif k == "costItems" then
            out.costItems = costItems
        elseif k == "conditions" then
            out.conditions = copyConditions(v)
        else
            out[k] = v
        end
    end
    if out.currencies == nil then out.currencies = currencies end
    if out.costItems == nil then out.costItems = costItems end
    if out.conditions == nil then out.conditions = {} end
    return out
end

local function compareOffers(a, b)
    local ca = a.hasExtendedCost and 1 or 0
    local cb = b.hasExtendedCost and 1 or 0
    if ca ~= cb then return ca < cb end
    local ua = a.unitCopper or math.huge
    local ub = b.unitCopper or math.huge
    if ua ~= ub then return ua < ub end
    if (a.npcID or 0) ~= (b.npcID or 0) then return (a.npcID or 0) < (b.npcID or 0) end
    if (a.optionIndex or 0) ~= (b.optionIndex or 0) then return (a.optionIndex or 0) < (b.optionIndex or 0) end
    return (a.sourceOrder or 0) < (b.sourceOrder or 0)
end

local function resolveNpcFactionID(npc, offer, npcFaction)
    if type(offer) == "table" and type(offer.npcFactionID) == "number" and offer.npcFactionID > 0 then
        return offer.npcFactionID
    end
    if type(npc) == "table" and type(npc.npcFactionID) == "number" and npc.npcFactionID > 0 then
        return npc.npcFactionID
    end
    local condFid = firstReputationFaction(type(offer) == "table" and offer.conditions or nil)
        or firstReputationFaction(type(npc) == "table" and npc.accessConditions or nil)
    if condFid then return condFid end

    local side = npcFaction or normalizeFaction(type(npc) == "table" and npc.faction or nil) or "N"
    local areaMap = AREA_TO_FACTION_BY_SIDE[side]
    if type(areaMap) == "table" and type(npc) == "table" then
        if type(npc.spawns) == "table" then
            for i = 1, #npc.spawns do
                local sp = npc.spawns[i]
                local aid = type(sp) == "table" and sp.areaID or nil
                if type(aid) == "number" and areaMap[aid] then
                    return areaMap[aid]
                end
            end
        end
        if type(npc.areaIDs) == "table" then
            for i = 1, #npc.areaIDs do
                local aid = npc.areaIDs[i]
                if type(aid) == "number" and areaMap[aid] then
                    return areaMap[aid]
                end
            end
        end
    end
    return nil
end

M.ResolveNpcFactionID = resolveNpcFactionID

function M.DiscountSignature(ctx)
    local dcfg = discountCfg()
    local minStanding = tonumber(dcfg.honoredStanding) or 6
    local parts = { "b=" .. tostring(M.LegacyBarterRank(ctx)) }
    for i = 1, #TRACKED_DISCOUNT_FACTIONS do
        local fid = TRACKED_DISCOUNT_FACTIONS[i]
        local st = M.FactionStanding(fid, ctx)
        if type(st) == "number" and st >= minStanding then
            parts[#parts + 1] = tostring(fid) .. "=1"
        end
    end
    return table.concat(parts, ";")
end

local accessTracked
local function collectAccessTracked()
    if accessTracked then return accessTracked end
    local DS = getDS()
    if not DS or type(DS.Ensure) ~= "function" then return nil end
    local qMap, iMap, fMap = {}, {}, {}
    local function scanConds(conds)
        if type(conds) ~= "table" then return end
        for i = 1, #conds do
            local c = conds[i]
            if type(c) == "table" then
                if c.kind == "quest" and type(c.questID) == "number" and c.questID > 0 then
                    qMap[c.questID] = true
                elseif c.kind == "questGroup" and type(c.groups) == "table" then
                    for _, g in ipairs(c.groups) do
                        for _, qid in ipairs(g or {}) do
                            if type(qid) == "number" and qid > 0 then qMap[qid] = true end
                        end
                    end
                elseif (c.kind == "hasItem" or c.kind == "sourceItem") then
                    local iid = c.itemID or c.value
                    if type(iid) == "number" and iid > 0 then iMap[iid] = true end
                elseif c.kind == "reputation" and type(c.factionID) == "number" and c.factionID > 0 then
                    fMap[c.factionID] = true
                end
            end
        end
    end
    local ent = DS.Ensure("entities")
    if type(ent) == "table" and type(ent.npcs) == "table" then
        for _, npc in pairs(ent.npcs) do
            if type(npc) == "table" then scanConds(npc.accessConditions) end
        end
    end
    local src = DS.Ensure("sources")
    if type(src) == "table" and type(src.vendorOffers) == "table" then
        for _, vo in pairs(src.vendorOffers) do
            if type(vo) == "table" and type(vo.offers) == "table" then
                for _, off in ipairs(vo.offers) do
                    if type(off) == "table" then scanConds(off.conditions) end
                end
            end
        end
    end
    local function sortedKeys(t)
        local out = {}
        for k in pairs(t) do out[#out + 1] = k end
        table.sort(out)
        return out
    end
    accessTracked = {
        quests = sortedKeys(qMap),
        items = sortedKeys(iMap),
        factions = sortedKeys(fMap),
    }
    return accessTracked
end

local function questFlagState(id, ctx)
    local Cond = getCond()
    if Cond and type(Cond.EvaluateQuestGroups) == "function" then
        return Cond.EvaluateQuestGroups({ { id } }, ctx)
    end
    if type(ctx) == "table" and (ctx.completedQuests ~= nil or ctx.quests ~= nil) then
        local q = ctx.completedQuests or ctx.quests
        return q and q[id]
    end
    local cq = _G.C_QuestLog
    if type(cq) == "table" and type(cq.IsQuestFlaggedCompleted) == "function" then
        local ok, v = pcall(cq.IsQuestFlaggedCompleted, id)
        if ok then return v end
    end
    return nil
end

local function itemPresentState(id, ctx)
    if type(ctx) == "table" and (ctx.ownedSourceItems ~= nil or ctx.ownedItems ~= nil) then
        local map = ctx.ownedSourceItems or ctx.ownedItems
        local n = map and map[id]
        if type(n) == "number" then return n >= 1 end
        return nil
    end
    local ci = _G.C_Item
    if type(ci) == "table" and type(ci.GetItemCount) == "function" then
        local ok, n = pcall(ci.GetItemCount, id, false, false)
        if ok and type(n) == "number" then return n >= 1 end
    end
    return nil
end

function M.AccessSignature(ctx)
    local tracked = collectAccessTracked()
    if not tracked then return "" end
    local parts = {}
    for i = 1, #tracked.quests do
        local id = tracked.quests[i]
        parts[#parts + 1] = "q:" .. tostring(id) .. "=" .. tostring(questFlagState(id, ctx))
    end
    for i = 1, #tracked.items do
        local id = tracked.items[i]
        parts[#parts + 1] = "i:" .. tostring(id) .. "=" .. tostring(itemPresentState(id, ctx))
    end
    for i = 1, #tracked.factions do
        local fid = tracked.factions[i]
        parts[#parts + 1] = "f:" .. tostring(fid) .. "=" .. tostring(M.FactionStanding(fid, ctx))
    end
    return table.concat(parts, ";")
end

function M.ApplyVendorDiscounts(itemID, rawPrice, bundleSize, npc, offer, ctx, npcFaction, preBarterMult, standingCache)
    local DS = getDS()
    local item = DS and type(DS.Item) == "function" and DS.Item(itemID) or nil
    local db2Buy = type(item) == "table" and type(item.buyPriceCopper) == "number" and item.buyPriceCopper > 0 and item.buyPriceCopper or nil
    local npcFactionID = resolveNpcFactionID(npc, offer, npcFaction)
    local barterMult = preBarterMult ~= nil and preBarterMult or M.LegacyBarterMultiplier(ctx)
    local repMult = 1.0
    local basePrice = db2Buy or rawPrice
    if db2Buy then
        if standingCache and type(npcFactionID) == "number" and npcFactionID > 0 then
            local cached = standingCache[npcFactionID]
            if cached == nil then
                cached = M.FactionDiscountMultiplier(npcFactionID, ctx)
                standingCache[npcFactionID] = cached
            end
            repMult = cached
        else
            repMult = M.FactionDiscountMultiplier(npcFactionID, ctx)
        end
    end
    if type(basePrice) ~= "number" or basePrice ~= basePrice or basePrice < 0 or basePrice >= math.huge then
        return nil, nil, nil, 1.0, barterMult, npcFactionID
    end
    local discounted
    if basePrice == 0 then
        discounted = 0
    else
        discounted = math.max(1, math.floor(basePrice * repMult * barterMult + 0.5))
    end
    local unit = discounted / (bundleSize or 1)
    return discounted, unit, basePrice, repMult, barterMult, npcFactionID
end

local function normalizeOffer(itemID, offer, index, DS, Cond, ctx, playerFaction, checkAccess, commonVendorCount, preBarterMult, standingCache)
    if type(offer) ~= "table" then return nil end
    local rawNpc = offer.npcID ~= nil and offer.npcID or offer.id
    local npcID = rawNpc ~= nil and tonumber(rawNpc) or nil
    if rawNpc ~= nil and not Int(npcID, 1) then return nil end

    local rawBundle = offer.bundleSize ~= nil and offer.bundleSize or offer.quantity
    local bundleSize = rawBundle == nil and 1 or rawBundle
    if not Int(bundleSize, 1) then return nil end

    local ms = offer.maxStock ~= nil and offer.maxStock or offer.stock
    if checkAccess and ms == 0 then return nil end

    local npc = npcID and DS and type(DS.Npc) == "function" and DS.Npc(npcID) or nil
    local npcFaction = normalizeFaction(offer.faction or (npc and npc.faction))

    if checkAccess then
        if not allowedFaction(npcFaction, playerFaction) then return nil end
        if npc and Cond then
            if type(Cond.IsNpcAccessible) == "function" then
                if not Cond.IsNpcAccessible(npc, ctx) then return nil end
            elseif type(npc.accessConditions) == "table" and #npc.accessConditions > 0 and type(Cond.IsMet) == "function" then
                if not Cond.IsMet(npc.accessConditions, ctx) then return nil end
            end
        end
        if type(offer.conditions) == "table" and #offer.conditions > 0 and Cond and type(Cond.IsMet) == "function" then
            if not Cond.IsMet(offer.conditions, ctx) then return nil end
        end
    end

    local currencies = copyCurrencies(offer.currencies)
    local costItems = copyCostItems(offer.costItems)
    if #currencies == 0 and Int(offer.currencyID, 1) then
        local amt = tonumber(offer.currencyAmount ~= nil and offer.currencyAmount or offer.curAmt) or 0
        currencies[1] = {
            currencyID = offer.currencyID,
            amount = amt,
            id = offer.currencyID,
            count = amt,
        }
    end

    local isMixed = (#currencies > 0 or #costItems > 0 or offer.hasExtendedCost == true)
    local rawPrice = offer.priceCopper ~= nil and offer.priceCopper or offer.price
    local hasRawPrice = type(rawPrice) == "number" and rawPrice == rawPrice and rawPrice >= 0 and rawPrice < math.huge

    local finalPrice, unitCopper, basePriceCopper, repMult, barterMult, npcFactionID
    if not isMixed then
        finalPrice, unitCopper, basePriceCopper, repMult, barterMult, npcFactionID =
            M.ApplyVendorDiscounts(itemID, hasRawPrice and rawPrice or nil, bundleSize, npc, offer, ctx, npcFaction, preBarterMult, standingCache)
    elseif hasRawPrice then
        finalPrice = rawPrice
        unitCopper = rawPrice / bundleSize
        basePriceCopper = rawPrice
        repMult = 1.0
        barterMult = 1.0
    end
    local hasPrice = type(finalPrice) == "number" and finalPrice == finalPrice and finalPrice >= 0 and finalPrice < math.huge

    local areaID
    if npc and type(npc.spawns) == "table" and type(npc.spawns[1]) == "table" then
        areaID = npc.spawns[1].areaID
    end

    local unlimited = ms == -1
    local limited = (type(ms) == "number" and ms > 0) and ms or nil

    return {
        npcID = npcID,
        itemID = itemID,
        optionIndex = offer.optionIndex,
        sourceOrder = index,
        priceCopper = hasPrice and finalPrice or nil,
        price = hasPrice and finalPrice or nil,
        basePriceCopper = basePriceCopper,
        repMultiplier = repMult,
        barterMultiplier = barterMult,
        npcFactionID = npcFactionID,
        unitCopper = unitCopper,
        bundleSize = bundleSize,
        quantity = bundleSize,
        maxStock = ms,
        unlimited = unlimited,
        limited = limited,
        stockUnknown = (ms == nil) or nil,
        available = ms ~= 0,
        purchasable = true,
        currencies = currencies,
        costItems = costItems,
        hasExtendedCost = isMixed,
        currencyID = (#currencies > 0 and currencies[1].currencyID) or 0,
        currencyAmount = (#currencies > 0 and currencies[1].amount) or 0,
        priceVerified = offer.priceVerified == true,
        priceUsable = hasPrice and not isMixed,
        faction = npcFaction or "N",
        areaID = areaID,
        conditions = copyConditions(offer.conditions),
        commonVendorCount = commonVendorCount,
        offer = copyOffer(offer, currencies, costItems),
    }
end

local function buildOfferList(itemID, withCurrency, ctx, checkAccess)
    if not Int(itemID, 1) then return nil end
    local DS = getDS()
    local Cond = getCond()
    if not DS or type(DS.VendorOffers) ~= "function" then return nil end
    local vo = DS.VendorOffers(itemID)
    if type(vo) ~= "table" or type(vo.offers) ~= "table" then return nil end

    local playerFaction = checkAccess and resolvePlayerFaction(ctx) or nil
    local commonCount = type(vo.commonVendorCount) == "number" and vo.commonVendorCount or nil
    local preBarterMult = M.LegacyBarterMultiplier(ctx)
    local standingCache = {}
    local list = {}
    for index = 1, #vo.offers do
        local entry = normalizeOffer(itemID, vo.offers[index], index, DS, Cond, ctx, playerFaction, checkAccess, commonCount, preBarterMult, standingCache)
        if entry and (withCurrency or not entry.hasExtendedCost) then
            list[#list + 1] = entry
        end
    end
    table.sort(list, compareOffers)
    return list
end

function M.CommonVendorCount(itemID)
    if not Int(itemID, 1) then return nil end
    local DS = getDS()
    local vo = DS and type(DS.VendorOffers) == "function" and DS.VendorOffers(itemID) or nil
    return type(vo) == "table" and type(vo.commonVendorCount) == "number" and vo.commonVendorCount or nil
end

function M.FormulaFacts(itemID)
    if not Int(itemID, 1) then return EMPTY end
    local DS = getDS()
    if not DS or type(DS.VendorOffers) ~= "function" then return EMPTY end
    local vo = DS.VendorOffers(itemID)
    if type(vo) ~= "table" or type(vo.offers) ~= "table" then return EMPTY end
    local cached = formulaFactsCache[vo]
    if cached then return cached end
    cached = {}
    for i = 1, #vo.offers do
        local o = vo.offers[i]
        if type(o) == "table" then
            local npcID = tonumber(o.npcID or o.id)
            if Int(npcID, 1) then
                local npc = type(DS.Npc) == "function" and DS.Npc(npcID) or nil
                local side = normalizeFaction(o.faction or (npc and npc.faction))
                local avail = o.maxStock ~= 0
                local prev = cached[npcID]
                if not prev then
                    cached[npcID] = { faction = side, available = avail, purchasable = true }
                else
                    if prev.faction ~= side then prev.faction = nil end
                    prev.available = prev.available or avail
                end
            end
        end
    end
    formulaFactsCache[vo] = cached
    return cached
end

function M.FormulaList(itemID, ctx)
    if not Int(itemID, 1) then return nil end
    if isEmptyCtx(ctx) then
        local lc = getLiveCache(resolvePlayerFaction(nil))
        if lc then
            local k = (ctx ~= nil) and (-itemID) or itemID
            local hit = lc.form[k]
            if hit ~= nil then return hit ~= false and hit or nil end
            local res = buildOfferList(itemID, false, ctx, ctx ~= nil)
            lc.form[k] = res or false
            return res
        end
    end
    return buildOfferList(itemID, false, ctx, ctx ~= nil)
end

function M.DisplayList(itemID, ctx)
    if not Int(itemID, 1) then return nil end
    if isEmptyCtx(ctx) then
        local lc = getLiveCache(resolvePlayerFaction(nil))
        if lc then
            local k = (ctx ~= nil) and (-itemID) or itemID
            local hit = lc.disp[k]
            if hit ~= nil then return hit ~= false and hit or nil end
            local res = buildOfferList(itemID, true, ctx, ctx ~= nil)
            lc.disp[k] = res or false
            return res
        end
    end
    return buildOfferList(itemID, true, ctx, ctx ~= nil)
end

function M.VendorPrice(itemID, ctx)
    if not Int(itemID, 1) then return nil end
    local lc
    if isEmptyCtx(ctx) then
        lc = getLiveCache(resolvePlayerFaction(nil))
        if lc then
            local hit = lc.vp[itemID]
            if hit ~= nil then return hit ~= false and hit or nil end
        end
    end
    local list = buildOfferList(itemID, true, ctx, true)
    if type(list) ~= "table" or #list == 0 then
        if lc then lc.vp[itemID] = false end
        return nil
    end
    local bestPure, bestMixed
    for i = 1, #list do
        local e = list[i]
        if type(e.priceCopper) == "number" and e.priceCopper >= 0 then
            local cand = {
                priceCopper = e.priceCopper,
                unitCopper = e.unitCopper,
                basePriceCopper = e.basePriceCopper,
                repMultiplier = e.repMultiplier,
                barterMultiplier = e.barterMultiplier,
                npcFactionID = e.npcFactionID,
                bundleSize = e.bundleSize,
                npcID = e.npcID,
                optionIndex = e.optionIndex,
                currencies = e.currencies,
                costItems = e.costItems,
                hasExtendedCost = e.hasExtendedCost,
                maxStock = e.maxStock,
                priceVerified = e.priceVerified,
                commonVendorCount = e.commonVendorCount,
                offer = e.offer,
            }
            if not e.hasExtendedCost then
                if not bestPure or cand.unitCopper < bestPure.unitCopper then
                    bestPure = cand
                end
            else
                if not bestMixed or cand.unitCopper < bestMixed.unitCopper then
                    bestMixed = cand
                end
            end
        end
    end
    local res = bestPure or bestMixed
    if lc then lc.vp[itemID] = res or false end
    return res
end

function M.Price(itemID, ctx)
    if not Int(itemID, 1) then return nil end
    local list = buildOfferList(itemID, false, ctx, true)
    if type(list) ~= "table" or #list == 0 then return nil end
    local best
    for i = 1, #list do
        local e = list[i]
        if type(e.unitCopper) == "number" and (not best or e.unitCopper < best.unitCopper) then
            best = e
        end
    end
    if not best then return nil end
    return best.unitCopper, best.npcID
end

function M.AHPriceOf(itemID, ctx)
    if type(itemID) ~= "number" then return nil end
    if type(ctx) == "table" and type(ctx.ahPrices) == "table" and type(ctx.ahPrices[itemID]) == "number" then
        return ctx.ahPrices[itemID]
    end
    if ahPriceGuard then return nil end
    local ra = getRouteAuto()
    if ra and type(ra.AHPriceOf) == "function" then
        ahPriceGuard = true
        local ok, price = pcall(ra.AHPriceOf, itemID, ctx)
        ahPriceGuard = false
        if ok and type(price) == "number" then return price end
    end
    local API = getAPI()
    local del = API and type(API.GetDelegate) == "function" and API.GetDelegate("pricing") or nil
    if type(del) == "table" and type(del.AHPriceOf) == "function" and del.AHPriceOf ~= M.AHPriceOf then
        ahPriceGuard = true
        local ok, price = pcall(del.AHPriceOf, itemID, ctx)
        ahPriceGuard = false
        if ok and type(price) == "number" then return price end
    end
    return nil
end

function M.EffectiveCost(itemID, qtyOrCtx, ctxOrNil)
    if type(itemID) ~= "number" then return nil end
    local qty, ctx
    if type(qtyOrCtx) == "table" and ctxOrNil == nil then
        qty, ctx = 1, qtyOrCtx
    else
        qty = tonumber(qtyOrCtx) or 1
        ctx = ctxOrNil
    end
    if qty <= 0 then return 0 end

    local vp = M.VendorPrice(itemID, ctx)
    local vendorUnit = nil
    if vp then
        local pure = vp.hasExtendedCost ~= true
            and not (type(vp.offer) == "table" and vp.offer.hasExtendedCost == true)
            and (type(vp.currencies) ~= "table" or #vp.currencies == 0)
            and (type(vp.costItems) ~= "table" or #vp.costItems == 0)
        if pure and type(vp.unitCopper) == "number" then
            vendorUnit = vp.unitCopper
        end
    end
    local ahUnit = M.AHPriceOf(itemID, ctx)
    local bestUnit
    if type(vendorUnit) == "number" and type(ahUnit) == "number" then
        bestUnit = math.min(vendorUnit, ahUnit)
    elseif type(vendorUnit) == "number" then
        bestUnit = vendorUnit
    elseif type(ahUnit) == "number" then
        bestUnit = ahUnit
    end
    if not bestUnit then return nil end
    return bestUnit * qty
end

function M.MatPriceOf(itemID, ctx)
    return M.EffectiveCost(itemID, 1, ctx)
end

function M.NPCSellPriceOf(itemID)
    if type(itemID) ~= "number" then return nil end
    local rec = getRecovery()
    if rec and type(rec.NPCSellPriceOf) == "function" then
        return rec.NPCSellPriceOf(itemID)
    end
    local DS = getDS()
    local item = DS and type(DS.Item) == "function" and DS.Item(itemID) or nil
    return item and item.sellPriceCopper or nil
end

local function makeVendorOffersProxy()
    return setmetatable({}, {
        __index = function(_, itemID)
            if not Int(itemID, 1) then return EMPTY end
            local now = Now()
            local cache = M.cache
            if cache and now and M.stamp and (now - M.stamp) > quietMs() then
                cache = nil
                M.cache = nil
            end
            if not cache then
                cache = {}
                M.cache = cache
            end
            if now then M.stamp = now end
            local hit = cache[itemID]
            if hit then return hit end
            local list = M.FormulaList(itemID) or EMPTY
            cache[itemID] = list
            return list
        end,
    })
end

local function attachVendorOffersProxy()
    if type(ns.ProfVendorOffers) ~= "table" then
        ns.ProfVendorOffers = makeVendorOffersProxy()
    end
    if type(gns) == "table" and gns ~= ns and type(gns.ProfVendorOffers) ~= "table" then
        gns.ProfVendorOffers = ns.ProfVendorOffers
    end
end

local lastDiscountSig = nil
local lastAccessSig = nil

local function syncAccessBaseline()
    if M.built and lastAccessSig == nil then
        lastAccessSig = M.AccessSignature()
    end
end

function M.Ensure()
    attachVendorOffersProxy()
    if M.built then return end
    M.built = true
    local DS = getDS()
    if not DS or type(DS.Ensure) ~= "function" then return end
    local sources = DS.Ensure("sources")
    local vo = type(sources) == "table" and sources.vendorOffers or nil
    local items, offers = 0, 0
    if type(vo) == "table" then
        for _, entry in pairs(vo) do
            if type(entry) == "table" and type(entry.offers) == "table" and #entry.offers > 0 then
                items = items + 1
                offers = offers + #entry.offers
            end
        end
    end
    M.itemCount = items
    M.offerCount = offers
    syncAccessBaseline()
end

function M.Flush()
    flushGen = flushGen + 1
    M.cache = nil
    M.stamp = nil
    liveCache = nil
    liveCacheStamp = nil
    liveCacheFaction = nil
    formulaFactsCache = setmetatable({}, { __mode = "k" })
end

function M.Invalidate()
    if invalidating then return end
    invalidating = true
    M.Flush()
    local rec = getRecovery()
    if rec and type(rec.Invalidate) == "function" then
        pcall(rec.Invalidate)
    end
    local ra = getRouteAuto()
    if ra and type(ra.Invalidate) == "function" then
        pcall(ra.Invalidate)
    end
    invalidating = false
end

function M.Stats()
    M.Ensure()
    return M.itemCount, M.offerCount
end

function M.Ready()
    M.Ensure()
    return (M.offerCount or 0) > 0
end

local function registerDelegate()
    local API = getAPI()
    if not API or type(API.RegisterDelegate) ~= "function" then return end
    local prev = type(API.GetDelegate) == "function" and API.GetDelegate("pricing") or nil
    local impl = {}
    if type(prev) == "table" then
        for k, v in pairs(prev) do impl[k] = v end
    end
    impl.VendorPrice = M.VendorPrice
    impl.EffectiveCost = M.EffectiveCost
    impl.MatPriceOf = M.MatPriceOf
    local prevInv = type(prev) == "table" and type(prev.Invalidate) == "function" and prev.Invalidate or nil
    if prevInv == delegateInvalidate and delegateInvalidate ~= nil then
        impl.Invalidate = delegateInvalidate
    elseif prevInv and prevInv ~= M.Invalidate then
        local active = false
        delegateInvalidate = function()
            if active then return end
            active = true
            M.Invalidate()
            pcall(prevInv)
            active = false
        end
        impl.Invalidate = delegateInvalidate
    else
        impl.Invalidate = M.Invalidate
    end
    if not impl.AHPriceOf then impl.AHPriceOf = M.AHPriceOf end
    if not impl.NPCSellPriceOf then impl.NPCSellPriceOf = M.NPCSellPriceOf end
    API.RegisterDelegate("pricing", impl)
end

M.RegisterDelegate = registerDelegate

attachVendorOffersProxy()
registerDelegate()

if type(_G.CreateFrame) == "function" then
    local DISCOUNT_EVENTS = {
        PLAYER_ENTERING_WORLD = true,
        UPDATE_FACTION = true,
        TRAIT_CONFIG_UPDATED = true,
        TRAIT_CONFIG_LIST_UPDATED = true,
    }
    local ACCESS_EVENTS = {
        UPDATE_FACTION = true,
        QUEST_TURNED_IN = true,
        QUEST_LOG_UPDATE = true,
        QUEST_ACCEPTED = true,
        BAG_UPDATE_DELAYED = true,
        PLAYER_EQUIPMENT_CHANGED = true,
    }
    local okF, frame = pcall(_G.CreateFrame, "Frame")
    if okF and type(frame) == "table" then
        for _, ev in ipairs({
            "PLAYER_ENTERING_WORLD",
            "UPDATE_FACTION",
            "TRAIT_CONFIG_UPDATED",
            "TRAIT_CONFIG_LIST_UPDATED",
            "QUEST_TURNED_IN",
            "QUEST_LOG_UPDATE",
            "QUEST_ACCEPTED",
            "BAG_UPDATE_DELAYED",
            "PLAYER_EQUIPMENT_CHANGED",
            "MERCHANT_CLOSED",
        }) do
            pcall(frame.RegisterEvent, frame, ev)
        end
        frame:SetScript("OnEvent", function(_, event)
            local dirty = false
            if not event or DISCOUNT_EVENTS[event] then
                local sig = M.DiscountSignature()
                if sig ~= lastDiscountSig then
                    lastDiscountSig = sig
                    dirty = true
                end
            end
            if M.built then
                if event == "MERCHANT_CLOSED" then
                    dirty = true
                elseif ACCESS_EVENTS[event] then
                    local asig = M.AccessSignature()
                    if lastAccessSig ~= nil and asig ~= lastAccessSig then
                        dirty = true
                    end
                    lastAccessSig = asig
                end
            end
            if dirty then
                M.Invalidate()
                local ra = getRouteAuto()
                if ra and type(ra.NotifyPricesChanged) == "function" then
                    pcall(ra.NotifyPricesChanged)
                end
            end
        end)
        M.EventFrame = frame
    end
end
