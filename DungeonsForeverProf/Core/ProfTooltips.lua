local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local format = string.format
local floor = math.floor
local max = math.max
local min = math.min
local ceil = math.ceil

local TT = {}

local function getBridge()
    return ns.ProfHostBridge or (type(gns) == "table" and gns.ProfHostBridge) or nil
end

local function getDS()
    return ns.ProfDataStore or (type(gns) == "table" and gns.ProfDataStore) or nil
end

local function getRA()
    return ns.ProfRouteAuto or (type(gns) == "table" and gns.ProfRouteAuto) or nil
end

local function getEco()
    return ns.ProfEconomy or (type(gns) == "table" and gns.ProfEconomy) or nil
end

local function getRanks()
    return ns.ProfRanks or (type(gns) == "table" and gns.ProfRanks) or nil
end

local function getScanner()
    local s = ns.ProfAuctionScanner or (type(gns) == "table" and gns.ProfAuctionScanner)
    if s then return s end
    local b = getBridge()
    return b and b.ExternalAuctionBridge and b.ExternalAuctionBridge() or nil
end

local function getExports()
    return ns.ProfMainExports or (type(gns) == "table" and gns.ProfMainExports) or nil
end

local function getPD()
    return ns.ProfModule or (type(gns) == "table" and gns.ProfModule) or nil
end

local function getAPI()
    return ns.ProfAPI or (type(gns) == "table" and gns.ProfAPI) or nil
end

local L = setmetatable({}, {
    __index = function(_, k)
        local b = getBridge()
        if b and type(b.L) == "function" then return b.L(k) end
        return tostring(k)
    end,
})

local function Unpack(...)
    local b = getBridge()
    if b and type(b.Unpack) == "function" then return b.Unpack(...) end
    local fn = _G.unpack
    if type(fn) == "function" then return fn(...) end
end

local function colorOf(name, fallback)
    local b = getBridge()
    local c = b and type(b.Color) == "function" and b.Color(name) or nil
    return c or fallback
end

local TIP_MAX = 24
local TIP_RED = { 1, 0.3, 0.25 }
local CRATE_GREEN = { 0.25, 0.85, 0.25 }
local FAVOR_CURID = 3402
local CAMP_STATION_EXCLUDED = {
    anvil = true,
    forge = true,
    cooking_fire = true,
}

local function itemNameOf(id)
    local ex = getExports()
    if ex and type(ex.ItemName) == "function" then
        return ex.ItemName(id)
    end
    local pd = getPD()
    if pd and type(pd.ItemName) == "function" then
        return pd.ItemName(id)
    end
    local api = getAPI()
    if api and type(api.ItemName) == "function" then
        return api.ItemName(id)
    end
    return tostring(id or "?")
end

local function primeNamesOf(mats)
    local ex = getExports()
    if ex and type(ex.PrimeNames) == "function" then
        ex.PrimeNames(mats)
        return
    end
    local pd = getPD()
    if pd and type(pd.PrimeNames) == "function" then
        pd.PrimeNames(mats)
    end
end

local function matIconTexOf(id, px)
    local ex = getExports()
    if ex and type(ex.MatIconTex) == "function" then
        return ex.MatIconTex(id, px)
    end
    local pd = getPD()
    if pd and type(pd.MatIconTex) == "function" then
        return pd.MatIconTex(id, px)
    end
    return ""
end

local function spellNameOf(id)
    local pd = getPD()
    if pd and type(pd.SpellName) == "function" then
        return pd.SpellName(id)
    end
    local ds = getDS()
    local nm = type(id) == "number" and ds and type(ds.RawText) == "function" and ds.RawText("spell", id) or nil
    if type(nm) == "string" and nm ~= "" then return nm end
    local cs = _G.C_Spell
    if type(cs) == "table" and type(cs.GetSpellInfo) == "function" then
        local ok, info = pcall(cs.GetSpellInfo, id)
        if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    return nil
end

local function campNameOf(c)
    if type(c) ~= "table" then return "?" end
    local ds = getDS()
    local nm = ds and c.campKey and type(ds.RawText) == "function" and ds.RawText("camp", c.campKey, "name") or nil
    if type(nm) == "string" and nm ~= "" then return nm end
    if c.itemID then return itemNameOf(c.itemID) end
    if c.spellID then return spellNameOf(c.spellID) or c.campKey or "?" end
    return c.campKey or "?"
end

local function campNameByKey(campKey)
    if type(campKey) ~= "string" or campKey == "" then return nil end
    local ds = getDS()
    local raw = ds and type(ds.RawText) == "function" and ds.RawText("camp", campKey, "name") or nil
    if type(raw) == "string" and raw ~= "" then return raw end
    local camps = ds and type(ds.CampObjects) == "function" and ds.CampObjects() or nil
    local target = type(camps) == "table" and camps[campKey] or nil
    if target then return campNameOf(target) end
    return campKey
end

local function campReagentText(reagents)
    if type(reagents) ~= "table" or #reagents == 0 then return "" end
    local out = {}
    for _, m in ipairs(reagents) do
        local iid = m.itemID or m[1]
        local cnt = m.count or m[2] or 1
        if iid then
            out[#out + 1] = format("%s×%d", tostring(itemNameOf(iid)), cnt)
        end
    end
    return table.concat(out, ", ")
end

-- =========================================================================
-- 1. Core Tooltip Rendering Primitives
-- =========================================================================

function TT.SpellTipLines()
    local GT = _G.GameTooltip
    if not (GT and type(GT.NumLines) == "function") then return nil end
    local ok, v = pcall(GT.NumLines, GT)
    if ok and type(v) == "number" then return v end
    return nil
end

function TT.Hide()
    local GT = _G.GameTooltip
    if type(GT) == "table" and type(GT.Hide) == "function" then
        GT:Hide()
    end
end

function TT.TipAppendLines(lines)
    if type(lines) ~= "table" or #lines == 0 then return end
    local b = getBridge()
    if b and type(b.TipAppendLines) == "function" then
        return b.TipAppendLines(lines)
    end
    local GT = _G.GameTooltip
    if not GT or type(GT.AddLine) ~= "function" then return end
    GT:AddLine(" ")
    for i = 1, #lines do
        local ln = lines[i]
        if type(ln) == "table" and type(ln[1]) == "string" then
            GT:AddLine(ln[1], ln[2] or 1, ln[3] or 1, ln[4] or 1, true)
        end
    end
end

function TT.TipShow(owner, lines, point)
    if not (owner and type(lines) == "table") then return end
    local GT = _G.GameTooltip
    if not GT or type(GT.SetOwner) ~= "function" then return end
    GT:SetOwner(owner, point or "ANCHOR_RIGHT")
    if type(GT.ClearLines) == "function" then GT:ClearLines() end
    local last, n = nil, 0
    for i = 1, #lines do
        local ln = lines[i]
        local t = type(ln) == "table" and ln[1] or nil
        if type(t) == "string" then
            t = t:gsub("%s+$", "")
            if t ~= "" and t ~= last then
                last = t
                n = n + 1
                if n <= TIP_MAX then
                    GT:AddLine(t, ln[2] or 1, ln[3] or 1, ln[4] or 1, true)
                end
            end
        end
    end
    if n > 0 and type(GT.Show) == "function" then GT:Show() end
end

function TT.ShowSpellTip(owner, extra)
    local sid = owner and owner.__spell
    if type(sid) ~= "number" then return false end
    local GT = _G.GameTooltip
    if not GT or type(GT.SetOwner) ~= "function" then return false end
    GT:SetOwner(owner, "ANCHOR_RIGHT")
    if type(GT.ClearLines) == "function" then GT:ClearLines() end
    local ok = false
    if type(GT.SetSpellByID) == "function" then
        ok = pcall(GT.SetSpellByID, GT, sid)
    elseif type(GT.SetSpell) == "function" then
        ok = pcall(GT.SetSpell, GT, sid, _G.BOOKTYPE_SPELL or "spell")
    end
    if not ok then
        return false
    end
    local n = TT.SpellTipLines()
    if n == nil and type(GT.SetHyperlink) == "function" then
        local ok2 = pcall(GT.SetHyperlink, GT, "spell:" .. tostring(sid))
        if not ok2 then return false end
        n = TT.SpellTipLines()
    end
    if type(n) == "number" and n < 1 then
        return false
    end
    if type(extra) == "table" and #extra > 0 then
        TT.TipAppendLines(extra)
    end
    if type(GT.Show) == "function" then GT:Show() end
    return true
end

function TT.ShowItemTip(owner, it, extra, title)
    local b = getBridge()
    if b and type(b.ShowItemTip) == "function" then
        return b.ShowItemTip(owner, it, extra, title)
    end
end

-- =========================================================================
-- 2. Shared Cost & Material Tooltip Helpers
-- =========================================================================

function TT.MatsCostText(mats)
    local ra = getRA()
    if not (ra and mats and #mats > 0 and type(ra.MatListCost) == "function") then return "—" end
    local total, unpriced = ra.MatListCost(mats)
    unpriced = unpriced or 0
    if not total or total <= 0 or unpriced >= #mats then return "—" end
    return (unpriced > 0 and "≈" or "") .. (ra.MoneyStr and ra.MoneyStr(total, "copper") or tostring(total))
end

function TT.MatsCostTextC(mats)
    local ra = getRA()
    if not (ra and mats and #mats > 0 and type(ra.MatListCost) == "function") then return "—" end
    local total, unpriced = ra.MatListCost(mats)
    unpriced = unpriced or 0
    if not total or total <= 0 or unpriced >= #mats then return "—" end
    return (unpriced > 0 and "≈" or "") .. (ra.MoneyStrTip and ra.MoneyStrTip(total) or tostring(total))
end

function TT.CrateOptCost(itemId, qty)
    local ra = getRA()
    if ra and type(ra.KnownQtyCost) == "function" then
        local cost, info = ra.KnownQtyCost(itemId, qty or 1)
        return cost, info
    end
    local p = ra and type(ra.AHPriceOf) == "function" and ra.AHPriceOf(itemId) or nil
    if not p then return nil end
    return p * (qty or 1)
end

local favorIco
function TT.FavorIconTex(px)
    px = px or 14
    if favorIco == nil then
        local ic
        local cci = _G.C_CurrencyInfo
        if type(cci) == "table" and type(cci.GetCurrencyInfo) == "function" then
            local ok, info = pcall(cci.GetCurrencyInfo, FAVOR_CURID)
            if ok and type(info) == "table" then ic = info.iconFileID end
        end
        if type(ic) ~= "number" or ic <= 0 then favorIco = 0 else favorIco = ic end
    end
    if favorIco == 0 then return "" end
    return format("|T%d:%d:%d|t", favorIco, px, px)
end

function TT.MatPriceLines(mats, costTxt, productID)
    local lines = {}
    if not (mats and #mats > 0) then return lines end
    primeNamesOf(mats)
    local ra = getRA()
    local MAX = 8
    local showN = min(#mats, MAX)
    for i = 1, showN do
        local m = mats[i]
        local n = m[2] or 1
        local p = ra and ra.MatPriceOf and ra.MatPriceOf(m[1]) or nil
        local sub = p and ra and ra.MoneyStrTip and ra.MoneyStrTip(p * n) or "—"
        lines[#lines + 1] = { format("%s ×%d", tostring(itemNameOf(m[1]) or "?"), n),
                              1, 1, 1, nil, nil, sub, 1, 1, 1 }
    end
    if #mats > showN then
        lines[#lines + 1] = { format("… +%d", #mats - showN), 0.6, 0.6, 0.6 }
    end
    lines[#lines + 1] = { L["制造总成本"], 1, 1, 1, nil, nil,
                          costTxt or "—", 1, 1, 1 }
    if productID then
        local ah = ra and ra.AHPriceOf and ra.AHPriceOf(productID) or nil
        local sell = ra and ra.NPCSellPriceOf and ra.NPCSellPriceOf(productID) or nil
        lines[#lines + 1] = { L["卖商人价格"], 1, 1, 1, nil, nil,
                              sell and ra and ra.MoneyStrTip and ra.MoneyStrTip(sell) or "—", 1, 1, 1 }
        lines[#lines + 1] = { L["拍卖行价格"], 1, 1, 1, nil, nil,
                              ah and ra and ra.MoneyStrTip and ra.MoneyStrTip(ah) or "—", 1, 1, 1 }
        local costVal = ra and ra.MatListCost and select(1, ra.MatListCost(mats)) or nil
        if ah and costVal and costVal > 0 then
            local net = floor(ah * 0.95) - costVal
            lines[#lines + 1] = { L["收益（扣除5%）"], 1, 1, 1, nil, nil,
                                  ra and ra.MoneyStrTip and ra.MoneyStrTip(net) or "—", 1, 1, 1 }
        end
    end
    return lines
end

-- =========================================================================
-- 3. Global Item Tooltip Content (Exported to Main Addon via ProfMainExports)
-- =========================================================================

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

function TT.PatternTipLines(id, title)
    if type(id) ~= "number" then return nil end
    local ex = getExports()
    local idx = ex and type(ex.PatternIndex) == "function" and ex.PatternIndex() or nil
    local e = type(idx) == "table" and idx[id] or nil
    if not (e and e.pid) then return nil end
    if not isTeachingItem(e, id) then
        local pname = itemNameOf(e.pid)
        if title ~= nil and title ~= "" and title ~= pname then return nil end
    end
    local mats = e.r and e.r[12]
    if not (mats and #mats > 0) then return nil end
    return TT.MatPriceLines(mats, TT.MatsCostTextC(mats), e.itemID)
end

function TT.ProductTipLines(id, title)
    if type(id) ~= "number" then return nil end
    local ex = getExports()
    if not (ex and type(ex.LookupCraftedItem) == "function") then return nil end
    local e = ex.LookupCraftedItem(id)
    if not e then return nil end
    local mats = (e.rec and ex.ReagentsToMats and ex.ReagentsToMats(e.rec.reagents)) or (e.r and e.r[12])
    if not (type(mats) == "table" and #mats > 0) then return nil end
    local nm = itemNameOf(id)
    if title and nm and title ~= nm then return nil end
    local b = getBridge()
    local cfg = b and type(b.TipConfig) == "function" and b.TipConfig() or nil
    local lines = {}
    if not (type(cfg) == "table" and cfg.src) then
        local craftTitle = type(ex.ProductCraftTitle) == "function" and ex.ProductCraftTitle(id) or nil
        if craftTitle then
            lines[#lines + 1] = { craftTitle, 1, 0.82, 0 }
        end
    end
    local mp = TT.MatPriceLines(mats, TT.MatsCostTextC(mats), id)
    for i = 1, #mp do lines[#lines + 1] = mp[i] end
    return lines
end

function TT.CrateNeedLines(id, title)
    local ex = getExports()
    if not (ex and type(ex.CrateNeedOf) == "function" and ex.CrateNeedOf(id, title)) then return nil end
    return { { L["需求"] .. ": " .. L["板条箱"], 1, 0.82, 0.4 } }
end

function TT.WritNeedLines(id, title)
    local ex = getExports()
    if not (ex and type(ex.WritNeedOf) == "function") then return nil end
    local tid, isItem = ex.WritNeedOf(id, title)
    if not tid then return nil end
    local areaOrMap, mapFallback = ex.WritZoneOf and ex.WritZoneOf(tid)
    local nm = (ex.ZoneNameOf and ex.ZoneNameOf(areaOrMap)) or (mapFallback and ex.ZoneNameOf and ex.ZoneNameOf(mapFallback))
    if isItem then
        if not nm then return nil end
        return { { L["上交地点"] .. ": " .. nm, 1, 0.82, 0.4 } }
    end
    local txt = L["需求"] .. ": " .. L["工匠文书"]
    if nm then txt = txt .. " | " .. nm end
    return { { txt, 1, 0.82, 0.4 } }
end

function TT.CrateTipLines(id)
    local ds = getDS()
    local ra = getRA()
    local c = type(id) == "number" and ds and ds.Crate and ds.Crate(id)
    if not c then return nil end
    local list, best, bestOpt = {}, nil, nil
    for _, o in ipairs(c.options or {}) do
        local v = TT.CrateOptCost(o.itemID, o.count)
        list[#list + 1] = { o = o, v = v }
        if v and (not best or v < best) then best, bestOpt = v, o end
    end
    if not best then return nil end
    table.sort(list, function(a, b)
        if a.v and b.v then return a.v < b.v end
        if a.v or b.v then return a.v ~= nil end
        return (a.o.itemID or 0) < (b.o.itemID or 0)
    end)
    local C_TEXT = colorOf("C_TEXT", { 0.88, 0.88, 0.88 })
    local rows = {}
    for i = 1, #list do
        local e = list[i]
        local o = e.o
        local isBest = bestOpt and o.itemID == bestOpt.itemID and o.count == bestOpt.count
        local txt = matIconTexOf(o.itemID, 14) .. tostring(itemNameOf(o.itemID)) .. " ×" .. tostring(o.count or 1)
        if isBest then txt = txt .. "  " .. L["最省"] end
        local col = isBest and CRATE_GREEN or C_TEXT
        rows[#rows + 1] = { txt, col[1], col[2], col[3], nil, nil,
                            (e.v and ra and ra.MoneyStrTip) and ra.MoneyStrTip(e.v) or "—", 1, 1, 1 }
    end
    local fav = tonumber(c.rewardAmount) or 0
    local own = ra and ra.AHPriceOf and ra.AHPriceOf(c.itemID) or nil
    local total = (own and best) and (own + best) or nil
    if fav > 0 and total and ra and ra.MoneyStrTip then
        rows[#rows + 1] = { TT.FavorIconTex(14) .. L["每点青睐"],
                            C_TEXT[1], C_TEXT[2], C_TEXT[3], nil, nil,
                            ra.MoneyStrTip(floor(total / fav + 0.5)), 1, 1, 1 }
    end
    return rows
end

function TT.WritTipLines(id)
    local ds = getDS()
    local ra = getRA()
    local ex = getExports()
    local w = type(id) == "number" and ds and ds.WritByItem and ds.WritByItem(id)
    if not w then return nil end
    local qty = w.qty or 1
    local buyAll, buyInfo
    if w.targetItemID then buyAll, buyInfo = TT.CrateOptCost(w.targetItemID, qty) end
    local craftCost, craftShortInfo
    local ci = w.targetItemID and ex and type(ex.CraftInfoForItem) == "function" and ex.CraftInfoForItem(w.targetItemID) or nil
    local rec = ci and ci.rec or nil
    if rec then
        local sum, all = 0, true
        local batches = ceil(qty / (rec[3] or 1))
        for _, m in ipairs(rec[12] or {}) do
            local mc, minfo = TT.CrateOptCost(m[1], batches * (m[2] or 1))
            if mc then
                sum = sum + mc
            else
                all = false
                if minfo and minfo.shortage and not craftShortInfo then craftShortInfo = minfo end
            end
        end
        if all then
            craftCost = sum
        end
    end
    if not buyAll and not craftCost and not (buyInfo and buyInfo.shortage) and not craftShortInfo then return nil end
    local labBuy = L["交付物品拍卖行价格"]
    local labCraft = L["制造交付物品价格"]
    if qty > 1 then
        local tag = " ×" .. tostring(qty)
        labBuy = labBuy .. tag
        labCraft = labCraft .. tag
    end
    local buyStr = (buyAll and ra and ra.MoneyStrTip) and ra.MoneyStrTip(buyAll)
        or (buyInfo and buyInfo.shortage and format(L["缺货（仅有 %d/%d）"], buyInfo.available or 0, buyInfo.required or qty))
        or "—"
    local craftStr = (craftCost and ra and ra.MoneyStrTip) and ra.MoneyStrTip(craftCost)
        or (craftShortInfo and format(L["缺货（仅有 %d/%d）"], craftShortInfo.available or 0, craftShortInfo.required or 0))
        or "—"
    local C_TEXT = colorOf("C_TEXT", { 0.88, 0.88, 0.88 })
    local C_GOLD = colorOf("C_GOLD", { 1, 0.82, 0 })
    local rows = {}
    rows[#rows + 1] = { labBuy, C_TEXT[1], C_TEXT[2], C_TEXT[3], nil, nil,
                        buyStr, 1, 1, 1 }
    rows[#rows + 1] = { labCraft, C_GOLD[1], C_GOLD[2], C_GOLD[3], nil, nil,
                        craftStr, 1, 1, 1 }
    return rows
end

-- =========================================================================
-- 4. Profession Panel Tooltip Content Builders
-- =========================================================================

function TT.RecipeSourceLines(lines, r)
    lines = lines or {}
    if r and r.clientUnavailable then
        lines[#lines + 1] = { L["未实装"], 0.95, 0.75, 0.4 }
        lines[#lines + 1] = { L["此记录仅供查阅，不参与自动路线。"], 0.95, 0.75, 0.4 }
    end
    local pd = getPD()
    local output = pd and type(pd.RecipeOutputText) == "function" and pd.RecipeOutputText(r) or nil
    if output then lines[#lines + 1] = { output, 0.65, 0.75, 0.85 } end
    local economy = getEco()
    local ra = getRA()
    if r and economy and economy.RouteRecipeEligibility then
        local allowed, reason, detail = economy.RouteRecipeEligibility(r)
        if not allowed then
            local text = economy.DiagnosticText and economy.DiagnosticText(reason) or reason
            lines[#lines + 1] = { text, 0.95, 0.75, 0.4 }
            if reason == "learningDataMissing" or reason == "learningRequirementsUnknown" then
                local diagnostic = ra and ra.LearningDiagnostic and ra.LearningDiagnostic(reason, r, detail)
                    or { spell = r.spell, item = r.formula, missingReasons = detail and detail.missingReasons }
                local gapText = pd and type(pd.LearningGapText) == "function" and pd.LearningGapText(diagnostic) or nil
                if gapText then lines[#lines + 1] = { gapText, 0.95, 0.75, 0.4 } end
                lines[#lines + 1] = { L["保留供查阅；取得已确认学习路径后才用于自动路线。"], 0.7, 0.7, 0.7 }
            end
        end
    end
    return lines
end

function TT.VendorBlockLines(lines, itemID)
    local C_NM, C_MT, C_PR = { 0.92, 0.94, 0.98 }, { 0.63, 0.65, 0.70 }, { 0.55, 0.85, 0.60 }
    local pd = getPD()
    local list = pd and type(pd.VendorOffersOf) == "function" and pd.VendorOffersOf(itemID) or nil
    if not list then
        lines[#lines + 1] = { format(L["商人：%s"], "—"), Unpack(C_MT) }
        return
    end
    local mine = pd and type(pd.MyVendorSide) == "function" and pd.MyVendorSide() or nil
    if mine then
        local keep, other = {}, 0
        for i = 1, #list do
            local s = pd.VendorSideOf and pd.VendorSideOf(list[i]) or "n"
            if s == "n" or s == mine then
                keep[#keep + 1] = list[i]
            else
                other = other + 1
            end
        end
        list = keep
        if #list == 0 then
            lines[#lines + 1] = { format(L["商人：%s"], other > 0 and L["对方阵营专属"] or "—"), Unpack(C_MT) }
            return
        end
    end
    local ra = getRA()
    local shown = #list
    for i = 1, shown do
        local o = list[i]
        local nm = pd and pd.VendorName and pd.VendorName(o) or nil
        if type(nm) ~= "string" or nm == "" or nm == "?" then nm = L["位置未收录的商人"] end
        lines[#lines + 1] = { format(L["商人：%s"], nm), Unpack(C_NM) }
        if pd and pd.PurchaseConditionLines then
            pd.PurchaseConditionLines(lines, o.npcID or o.id, o.itemID or itemID, o)
        end
        local zone = o.area and pd and pd.CampZoneName and pd.CampZoneName(o.area) or nil
        local side = pd and pd.VendorSideOf and pd.VendorSideOf(o) or "n"
        local head = pd and pd.VendorSideText and pd.VendorSideText(side) or ""
        if type(zone) == "string" and zone ~= "" then head = head .. " · " .. zone end
        lines[#lines + 1] = { head, Unpack(C_MT) }
        local stock = pd and pd.FormulaStockText and pd.FormulaStockText(o) or nil
        if stock then lines[#lines + 1] = { stock, Unpack(C_MT) } end
        local ptxt, isCur
        if o.paymentOption ~= nil then
            ptxt, isCur = pd and pd.FormulaCostText and pd.FormulaCostText(o) or nil, true
        elseif o.cur and o.amt then
            local cnm, cicon = pd and pd.CurrencyOf and pd.CurrencyOf(o.cur)
            if cnm then
                isCur = true
                ptxt = tostring(o.amt)
                local texCurIcon = pd and pd.NormTexIcon and pd.NormTexIcon(cicon) or nil
                if texCurIcon then
                    ptxt = ptxt .. " |T" .. texCurIcon .. ":12:12:0:0:64:64:4:60:4:60|t"
                end
                ptxt = ptxt .. " " .. cnm
            else
                local iname = pd and pd.VendorItemName and pd.VendorItemName(o.cur) or nil
                if iname then ptxt = iname .. " ×" .. tostring(o.amt) end
            end
        end
        if not ptxt and type(o.price) == "number" and o.price > 0 and ra and ra.MoneyStr then
            ptxt = ra.MoneyStr(o.price, "copper")
        end
        if ptxt then
            if not isCur and type(o.pack) == "number" and o.pack > 1 then
                ptxt = ptxt .. " · " .. format(L["每组 %d 件"], o.pack)
            end
            lines[#lines + 1] = { format(L["价格：%s"], ptxt), Unpack(C_PR) }
        end
    end
    if #list > shown then
        local names = {}
        for i = shown + 1, min(#list, shown + 3) do
            local nm = pd and pd.VendorName and pd.VendorName(list[i]) or nil
            if type(nm) == "string" and nm ~= "" and nm ~= "?" then names[#names + 1] = nm end
        end
        local txt = format(L["另有 %d 处"], #list - shown)
        if #names > 0 then txt = txt .. " · " .. table.concat(names, "、") end
        lines[#lines + 1] = { txt, Unpack(C_MT) }
    end
end

function TT.DropBlockLines(lines, itemID)
    local C_DR = { 0.72, 0.72, 0.76 }
    local pd = getPD()
    local list = pd and type(pd.DropRowsOf) == "function" and pd.DropRowsOf(itemID) or nil
    if not list then return end
    local shown = min(#list, (pd and pd.DROP_SHOW_MAX) or 2)
    for i = 1, shown do
        local o = list[i]
        local txt = format(L["掉落：%s"], o.name)
        local zone = o.area and pd and pd.CampZoneName and pd.CampZoneName(o.area) or nil
        if type(zone) == "string" and zone ~= "" then txt = txt .. " · " .. zone end
        local pt = pd and pd.DropPctText and pd.DropPctText(o.pct) or nil
        if pt then txt = txt .. " · " .. pt end
        lines[#lines + 1] = { txt, Unpack(C_DR) }
    end
    if #list > shown then
        lines[#lines + 1] = { format(L["…等 %d 处"], #list - shown), Unpack(C_DR) }
    end
end

function TT.PriceTipLines(itemID, mats, opts)
    local lines = {}
    if not itemID then return lines end
    primeNamesOf(mats)
    local ra = getRA()
    local ah = ra and ra.AHPriceOf and ra.AHPriceOf(itemID) or nil
    local sell = ra and ra.NPCSellPriceOf and ra.NPCSellPriceOf(itemID) or nil
    local cost, unpriced, nMats
    if mats and #mats > 0 and ra and ra.MatListCost then
        cost, unpriced = ra.MatListCost(mats)
        nMats = #mats
    end
    local costTxt, approx = "—", false
    if cost and nMats then
        if cost <= 0 or unpriced >= nMats then
            costTxt = "—"
        else
            approx = unpriced > 0
            costTxt = (approx and "≈" or "") .. (ra and ra.MoneyStr and ra.MoneyStr(cost, "copper") or tostring(cost))
        end
    end
    local o = type(opts) == "table" and opts or nil
    if o and o.recipe then
        lines[#lines + 1] = { L["材料成本"], 1, 1, 1, false, nil, costTxt, 1, 1, 1 }
        if o.matDetail and nMats then
            local showN = min(nMats, 8)
            for i = 1, showN do
                local m = mats[i]
                local n = m[2] or 1
                local p = ra and ra.MatPriceOf and ra.MatPriceOf(m[1]) or nil
                lines[#lines + 1] = { format("  %s ×%d", tostring(itemNameOf(m[1]) or "?"), n),
                                      0.85, 0.85, 0.85, false, nil,
                                      (p and ra and ra.MoneyStrTip and ra.MoneyStrTip(p * n)) or "—", 0.9, 0.9, 0.9 }
            end
            if nMats > showN then
                lines[#lines + 1] = { format("  … +%d", nMats - showN), 0.6, 0.6, 0.6 }
            end
        end
        if type(o.patternCost) == "string" and o.patternCost ~= "" then
            lines[#lines + 1] = { L["NPC 配方价格"], 0.92, 0.94, 0.98, false, nil,
                                  o.patternCost, 1, 1, 1 }
        end
        lines[#lines + 1] = { format(L["卖店: %s"], sell and ra and ra.MoneyStr and ra.MoneyStr(sell, "copper") or "—") }
    else
        lines[#lines + 1] = { format(L["拍卖: %s"], ah and ra and ra.MoneyStr and ra.MoneyStr(ah, "copper") or "—") }
        local scanner = getScanner()
        local sup = scanner and scanner.GetAuctionSupply and scanner.GetAuctionSupply(itemID) or nil
        if sup and type(sup.quantity) == "number" then
            lines[#lines + 1] = { format(L["在售: %d 件"], sup.quantity), 0.72, 0.84, 0.95 }
        end
        TT.VendorBlockLines(lines, itemID)
        TT.DropBlockLines(lines, itemID)
        lines[#lines + 1] = { format(L["卖店: %s"], sell and ra and ra.MoneyStr and ra.MoneyStr(sell, "copper") or "—") }
        if o and o.matDetail and nMats then
            local mp = TT.MatPriceLines(mats, TT.MatsCostTextC(mats))
            for i = 1, #mp do lines[#lines + 1] = mp[i] end
        else
            lines[#lines + 1] = { format(L["成本: %s"], costTxt) }
        end
    end
    if ah and cost and nMats and cost > 0 then
        local pre = approx and "≈" or ""
        local diff = ah - cost
        local net = floor(ah * 0.95) - cost
        local l4 = format(L["差价: %s"], pre .. (diff > 0 and "+" or "") .. (ra and ra.MoneyStr and ra.MoneyStr(diff, "copper") or tostring(diff)))
        local l5 = format(L["净赚（扣 5%% 拍卖费）: %s"],
                          pre .. (net > 0 and "+" or "") .. (ra and ra.MoneyStr and ra.MoneyStr(net, "copper") or tostring(net)))
        if diff < 0 then
            lines[#lines + 1] = { l4, Unpack(TIP_RED) }
        else
            lines[#lines + 1] = { l4 }
        end
        if net < 0 then
            lines[#lines + 1] = { l5, Unpack(TIP_RED) }
        else
            lines[#lines + 1] = { l5 }
        end
    end
    return lines
end

function TT.PerkTipLines(pk, lvs, cur)
    local ds = getDS()
    local lines = {}
    local nm = pk.perkKey and ds and ds.PerkText and ds.PerkText(pk.perkKey, "name") or pk.perkKey
    if type(nm) == "string" and nm ~= "" then
        lines[#lines + 1] = { nm, 1, 0.82, 0 }
    end
    local head = (type(lvs) == "table" and lvs[cur])
        or (pk.perkKey and ds and ds.RawText and (ds.RawText("perk", pk.perkKey, "description") or ds.RawText("perk", pk.perkKey, "desc")))
        or ""
    if head ~= "" then lines[#lines + 1] = { head } end
    if #lines == 0 then return nil end
    return lines
end

function TT.CampTipLines(c)
    local ds = getDS()
    local pd = getPD()
    local lines = {}
    local nm = campNameOf(c)
    if nm ~= "" then
        lines[#lines + 1] = { nm, 1, 0.82, 0 }
    end
    local function add(label, v)
        if type(v) == "string" and v ~= "" then
            lines[#lines + 1] = { label .. "：" .. v }
        end
    end
    local desc = c.campKey and ds and ds.RawText and (ds.RawText("camp", c.campKey, "description") or ds.RawText("camp", c.campKey, "desc"))
    local buff = c.campKey and ds and ds.RawText and (ds.RawText("camp", c.campKey, "buff") or ds.RawText("camp", c.campKey, "effect"))
    local repName = c.replacesCampKey and campNameByKey(c.replacesCampKey)
    local exName = c.exclusiveSpellID and spellNameOf(c.exclusiveSpellID)
    add(L["描述"], desc)
    add(L["增益"], buff)
    add(L["取代"], repName)
    add(L["互斥"], exName)
    if c.campfireCapacity then add(L["容量"], tostring(c.campfireCapacity)) end
    if c.reagentsKnown ~= false and c.reagents and #c.reagents > 0 then
        lines[#lines + 1] = { format(L["材料：%s"], campReagentText(c.reagents)), 0.7, 0.7, 0.7 }
    elseif c.reagentsKnown == false then
        lines[#lines + 1] = { format(L["材料：%s"], L["尚未收录"]), 0.7, 0.7, 0.7 }
    end
    if c.formulaItemIDs and c.formulaItemIDs[1] then
        lines[#lines + 1] = { format(L["图纸：%s"], itemNameOf(c.formulaItemIDs[1])) }
    end
    local stKey = c.stationKey
    if type(stKey) == "string" and stKey ~= "" and not CAMP_STATION_EXCLUDED[stKey] then
        local stCnt = pd and type(pd.CountRecipesByStation) == "function" and pd.CountRecipesByStation(c.profession, stKey) or 0
        if stCnt > 0 then
            lines[#lines + 1] = { format(L["需要此设施：%d 配方（点击筛选）"], stCnt), 0.45, 0.85, 1 }
            if c.wowheadURL then
                lines[#lines + 1] = { L["Shift+点击复制资料链接"], 0.65, 0.65, 0.65 }
            end
        end
    end
    if #lines == 0 then return nil end
    return lines
end

function TT.RankReminderTip(slug, target)
    local pd = getPD()
    local curSlug = slug or (pd and pd.cur)
    local curTarget = target or (pd and type(pd.LvTarget) == "function" and pd.LvTarget())
    local ranks = getRanks()
    local rank = ranks and ranks.NextStep and ranks.NextStep(curSlug, curTarget)
    if not (rank and rank.due) then return nil end
    local tip = { { (ranks.Title and ranks.Title(rank)) or "", 1, 1, 1 } }
    if ranks.Lines then
        for _, line in ipairs(ranks.Lines(rank) or {}) do tip[#tip + 1] = { line, 0.88, 0.88, 0.88 } end
        for _, line in ipairs(ranks.Lines(rank, 3) or {}) do tip[#tip + 1] = { line, 0.7, 0.7, 0.7 } end
    end
    return tip
end

-- =========================================================================
-- 5. Follow HUD & Auction Scanner Tooltips
-- =========================================================================

function TT.ShowFollowButtonTip(owner, title, body)
    TT.TipShow(owner, { { title, 1, 0.82, 0 }, { body } }, "ANCHOR_TOP")
end

function TT.ShowFollowRankHintTip(owner, statusTitle, statusDetail, tasks)
    local GT = _G.GameTooltip
    if not GT then return end
    if statusTitle then
        TT.TipShow(owner, { { statusTitle, 1, 0.82, 0 }, { statusDetail } }, "ANCHOR_TOP")
        return
    end
    local ranks = getRanks()
    if not (ranks and type(tasks) == "table" and #tasks > 0) then return end
    local lines = { { L["专业晋级"], 1, 0.82, 0 } }
    for _, step in ipairs(tasks) do
        lines[#lines + 1] = { ranks.Title(step), 0.95, 0.78, 0.35 }
        for _, text in ipairs(ranks.Lines(step) or {}) do lines[#lines + 1] = { text } end
    end
    TT.TipShow(owner, lines, "ANCHOR_TOP")
end

function TT.ShowFollowCardTip(owner, guide, it, mats, hasSpell)
    local GT = _G.GameTooltip
    if guide and GT and type(GT.SetOwner) == "function" then
        GT:SetOwner(owner, "ANCHOR_TOP")
        if type(GT.ClearLines) == "function" then GT:ClearLines() end
        GT:AddLine(guide.name, 1, 0.82, 0, true)
        for _, line in ipairs(guide.lines or {}) do
            GT:AddLine(line, 1, 1, 1, true)
        end
        if type(GT.Show) == "function" then GT:Show() end
        return
    end
    if not it then return end
    local extra = TT.PriceTipLines(it[1], mats)
    TT.ShowItemTip(owner, it, extra)
    if hasSpell then
        TT.TipAppendLines({ { L["点击卡片：打开专业面板、定位本步配方并填好制作次数"], 0.62, 0.86, 1 } })
    end
end

function TT.ShowFollowSourceTip(owner, row, hasLoc, detail)
    if not (row and row.srcText) then return end
    local GT = _G.GameTooltip
    if not (GT and type(GT.SetOwner) == "function") then return end
    GT:SetOwner(owner, "ANCHOR_TOP")
    if type(GT.ClearLines) == "function" then GT:ClearLines() end
    if row.srcKind == 1 then
        GT:AddLine(row.srcFull or row.srcText, 1, 0.82, 0, true)
        GT:AddLine(hasLoc and L["点击在地图上标出该商人"] or L["该商人的位置暂未收录"], 0.75, 0.75, 0.75, true)
    else
        GT:AddLine(row.nm, 1, 0.82, 0, true)
    end
    if detail then GT:AddLine(detail, 1, 1, 1, true) end
    if type(GT.Show) == "function" then GT:Show() end
end

function TT.ShowFollowMuteTip(owner, muted)
    local GT = _G.GameTooltip
    if not (GT and type(GT.SetOwner) == "function") then return end
    GT:SetOwner(owner, "ANCHOR_TOP")
    local txt = muted and L["语音提示：已静音（点击恢复）"] or L["语音提示：开启（点击静音）"]
    if type(GT.SetText) == "function" then
        GT:SetText(txt, 1, 1, 1)
    elseif type(GT.AddLine) == "function" then
        if type(GT.ClearLines) == "function" then GT:ClearLines() end
        GT:AddLine(txt, 1, 1, 1, true)
    end
    if type(GT.Show) == "function" then GT:Show() end
end

function TT.ShowAuctionScanButtonTip(owner, snap, nowTs, cooldownLeft, formatCooldownFn)
    local tip = _G.GameTooltip
    if type(tip) ~= "table" or type(tip.SetOwner) ~= "function" then return end
    tip:SetOwner(owner, "ANCHOR_BOTTOMLEFT")
    if type(tip.ClearLines) == "function" then tip:ClearLines() end
    tip:AddLine(L["DungeonsForever 专业行情扫描"], 1, 0.82, 0)
    tip:AddLine(L["手动执行全量拍卖行扫描，用于路线规划、板条箱、工匠文书与产物回血。"], 0.85, 0.85, 0.85, true)
    if snap and snap.status == "available" and snap.observedAt then
        local mins = max(0, floor(((nowTs or 0) - snap.observedAt) / 60))
        tip:AddLine(format(L["当前快照：%d 分钟前（专业物品 %d / 其他 %d）"], mins, snap.profItems or 0, snap.refItems or 0), 0.55, 0.85, 0.6)
    elseif snap and snap.status == "expired" then
        tip:AddLine(L["当前快照已超过 2 天有效期，建议重新扫描。"], 0.95, 0.75, 0.4)
    else
        tip:AddLine(L["尚无当前市场的有效扫描快照。"], 0.95, 0.75, 0.4)
    end
    if type(cooldownLeft) == "number" and cooldownLeft > 0 then
        local cdStr = type(formatCooldownFn) == "function" and formatCooldownFn(cooldownLeft) or tostring(cooldownLeft)
        tip:AddLine(format(L["服务器冷却剩余：%s（每次全量扫描间隔 15 分钟）"], cdStr), 0.95, 0.55, 0.45)
    end
    if type(tip.Show) == "function" then tip:Show() end
end

ns.ProfTooltips = TT
if type(gns) == "table" and gns ~= ns then
    gns.ProfTooltips = TT
end
