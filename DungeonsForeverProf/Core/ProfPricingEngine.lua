local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local PE = ns.ProfPricingEngine or (type(gns) == "table" and gns.ProfPricingEngine) or {}
ns.ProfPricingEngine = PE
if type(gns) == "table" and gns ~= ns then
    gns.ProfPricingEngine = PE
end

local floor, ceil, min, max, huge = math.floor, math.ceil, math.min, math.max, math.huge

local function getPricingCfg()
    return ns.PricingConfig or (type(gns) == "table" and gns.PricingConfig) or nil
end

local function validNum(v)
    return type(v) == "number" and v == v and v > -huge and v < huge
end

local function cfgTable(key)
    local cfg = getPricingCfg()
    local v = type(cfg) == "table" and cfg[key] or nil
    return type(v) == "table" and v or nil
end

function PE.NormalizeLevels(levels)
    if type(levels) ~= "table" or #levels == 0 then
        return {}, 0
    end
    local byPrice = {}
    local rawTotal = 0
    if type(levels[1]) == "number" then
        for i = 1, #levels, 2 do
            local p = levels[i]
            local q = levels[i + 1]
            if validNum(p) and p > 0 and validNum(q) and q > 0 then
                local qi = floor(q)
                if qi > 0 then
                    byPrice[p] = (byPrice[p] or 0) + qi
                    rawTotal = rawTotal + qi
                end
            end
        end
    else
        for i = 1, #levels do
            local row = levels[i]
            local p = type(row) == "table" and (row[1] or row.price) or nil
            local q = type(row) == "table" and (row[2] or row.quantity or row.qty) or nil
            if validNum(p) and p > 0 and validNum(q) and q > 0 then
                local qi = floor(q)
                if qi > 0 then
                    byPrice[p] = (byPrice[p] or 0) + qi
                    rawTotal = rawTotal + qi
                end
            end
        end
    end
    if rawTotal <= 0 then
        return {}, 0
    end
    local prices = {}
    for p in pairs(byPrice) do
        prices[#prices + 1] = p
    end
    table.sort(prices)
    local rows = {}
    for i = 1, #prices do
        local p = prices[i]
        rows[i] = { p, byPrice[p] }
    end
    return rows, rawTotal
end

function PE.TrimFishingOrders(levels, cfgOverride)
    local rows, rawTotal = PE.NormalizeLevels(levels)
    local n = #rows
    if n == 0 or rawTotal <= 0 then
        return {}, 0, 0, 0, 0
    end

    local ff = (type(cfgOverride) == "table" and cfgOverride) or cfgTable("FISHING_FILTER") or {}
    local startIdx = 1
    local remTotal = rawTotal
    local trimmedQty = 0
    local trimmedLots = 0

    if ff.enabled ~= false and rawTotal >= (ff.minTotalSupplyForTrim or 5) and n >= 2 then
        local maxLots = ff.headMaxLotCount or 5
        local maxShare = ff.headMaxQtyShare or 0.05
        local cliffRatio = ff.cliffPriceRatio or 0.60
        local limit = min(n - 1, maxLots)
        local bestCut = 0
        local cumQty = 0
        for k = 1, limit do
            cumQty = cumQty + rows[k][2]
            if (cumQty / rawTotal) > maxShare then
                break
            end
            if (rows[k][1] / rows[k + 1][1]) <= cliffRatio then
                bestCut = k
            end
        end
        if bestCut > 0 then
            for k = 1, bestCut do
                trimmedQty = trimmedQty + rows[k][2]
            end
            trimmedLots = bestCut
            startIdx = bestCut + 1
            remTotal = rawTotal - trimmedQty
        end
    end

    local denoised = {}
    for i = startIdx, n do
        denoised[#denoised + 1] = { rows[i][1], rows[i][2] }
    end
    return denoised, remTotal, trimmedQty, trimmedLots, rawTotal
end

function PE.RobustReferencePrice(levels, shareOverride, cfgOverride)
    local denoised, remTotal, _, _, rawTotal = PE.TrimFishingOrders(levels, cfgOverride)
    if #denoised == 0 or remTotal <= 0 then
        return nil
    end

    local rf = cfgTable("ROBUST_FLOOR") or {}
    local minSupply = type(rf.minConfidenceSupply) == "number" and rf.minConfidenceSupply or 1
    if rawTotal < minSupply then
        return nil
    end

    local share = type(rf.bottomShare) == "number" and rf.bottomShare
        or (type(rf.defaultPercentile) == "number" and rf.defaultPercentile)
        or 0.15
    if validNum(shareOverride) and shareOverride > 0 and shareOverride <= 1 then
        share = shareOverride
    end

    local targetQty = max(1, ceil(remTotal * share))
    local taken = 0
    local cost = 0
    for i = 1, #denoised do
        local row = denoised[i]
        local take = min(row[2], targetQty - taken)
        if take > 0 then
            cost = cost + take * row[1]
            taken = taken + take
            if taken >= targetQty then
                break
            end
        end
    end
    if taken <= 0 then
        return nil
    end
    local rounded = floor(cost / taken + 0.5)
    if rounded < 1 then
        return 1
    end
    return rounded
end

PE.RobustFloorPrice = PE.RobustReferencePrice

function PE.ConsumeDepth(levels, need, used, alreadyDenoised)
    if not validNum(need) or need < 0 then
        return nil, 0, 0, nil
    end
    need = ceil(need)
    if need == 0 then
        return 0, 0, 0, 0
    end
    local skip = (validNum(used) and used > 0) and floor(used) or 0
    local denoised
    if alreadyDenoised then
        denoised = PE.NormalizeLevels(levels)
    else
        denoised = PE.TrimFishingOrders(levels)
    end
    if #denoised == 0 then
        return nil, 0, need, nil
    end

    local covered = 0
    local cost = 0
    local remSkip = skip
    for i = 1, #denoised do
        local p, q = denoised[i][1], denoised[i][2]
        if remSkip >= q then
            remSkip = remSkip - q
        else
            local avail = q - remSkip
            remSkip = 0
            local take = min(avail, need - covered)
            if take > 0 then
                cost = cost + take * p
                covered = covered + take
                if covered >= need then
                    break
                end
            end
        end
    end

    if covered < need then
        return nil, covered, need - covered, covered > 0 and (cost / covered) or nil
    end
    return cost, covered, 0, cost / need
end

function PE.BuildPrefixBook(rows, alreadyDenoised)
    local source = alreadyDenoised and PE.NormalizeLevels(rows) or PE.TrimFishingOrders(rows)
    local prices = {}
    local quantity = {}
    local cost = {}
    local total = 0
    local totalCost = 0
    for i = 1, #source do
        local p, q = source[i][1], source[i][2]
        prices[i] = p
        total = total + q
        totalCost = totalCost + p * q
        quantity[i] = total
        cost[i] = totalCost
    end
    return {
        prices = prices,
        quantity = quantity,
        cost = cost,
        total = total,
        totalCost = totalCost,
    }
end

function PE.Prefix(book, q)
    if type(book) ~= "table" or not validNum(q) or q ~= floor(q) then
        return nil
    end
    if q == 0 then
        return 0
    end
    if q < 0 or q > (book.total or 0) then
        return nil
    end
    local lo, hi = 1, #book.prices
    while lo < hi do
        local mid = floor((lo + hi) / 2)
        if book.quantity[mid] < q then
            lo = mid + 1
        else
            hi = mid
        end
    end
    return (book.cost[lo - 1] or 0) + (q - (book.quantity[lo - 1] or 0)) * book.prices[lo]
end

function PE.Cost(book, used, q)
    used = used or 0
    if not validNum(used) or not validNum(q) or q < 0 or q ~= floor(q) then
        return nil
    end
    local begin = PE.Prefix(book, used)
    local finish = PE.Prefix(book, used + q)
    if not begin or not finish then
        return nil
    end
    return finish - begin
end
