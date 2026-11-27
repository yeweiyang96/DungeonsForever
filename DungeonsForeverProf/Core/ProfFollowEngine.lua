local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local E = ns.ProfFollowEngine or (type(gns) == "table" and gns.ProfFollowEngine) or {}
ns.ProfFollowEngine = E
if type(gns) == "table" and gns ~= ns then
    gns.ProfFollowEngine = E
end

local format = string.format
local floor, ceil, max, min, huge = math.floor, math.ceil, math.max, math.min, math.huge

local function fromNS(key)
    local v = ns[key]
    if v ~= nil then return v end
    if type(gns) == "table" then return gns[key] end
    return nil
end

local function getBridge() return fromNS("ProfHostBridge") end
local function getDS() return fromNS("ProfDataStore") end
local function getAPI() return fromNS("ProfAPI") end
local function getSupply() return fromNS("ProfSupply") end
local function getRA() return fromNS("ProfRouteAuto") end
local function getXP() return fromNS("ProfExecution") end
local function getPD() return fromNS("ProfModule") end
local function getEco() return fromNS("ProfEconomy") end
local function getAuctionBridge() return fromNS("AuctionBridge") or fromNS("ProfAuctionScanner") end
local function getAuctionDepth() return fromNS("ProfAuctionDepth") end
local function getRanks() return fromNS("ProfRanks") end
local function getGates() return fromNS("ProfGates") end
local function getGather() return fromNS("ProfGatheringRoutes") end
local function getDBMod() return fromNS("ProfDB") end

local L = setmetatable({}, {
    __index = function(_, k)
        local b = getBridge()
        if b and type(b.L) == "function" then return b.L(k) end
        local lt = fromNS("L")
        if type(lt) == "table" and lt[k] ~= nil then return lt[k] end
        return tostring(k)
    end,
})
E.L = L

local function hostLocale()
    local b = getBridge()
    if b and type(b.Locale) == "function" then
        return b.Locale() or "zhCN"
    end
    if type(_G.DF_Locale) == "function" then
        local ok, loc = pcall(_G.DF_Locale)
        if ok and type(loc) == "string" and loc ~= "" then return loc end
    end
    return "zhCN"
end

local function itemNameOf(id)
    local b = getBridge()
    local fallbackNm
    if b and type(b.ItemName) == "function" then
        local nm, got = b.ItemName(id)
        if got and type(nm) == "string" and nm ~= "" then return nm, true end
        fallbackNm = nm
    end
    local ds = getDS()
    local dnm = ds and type(ds.RawText) == "function" and ds.RawText("item", id) or nil
    if type(dnm) == "string" and dnm ~= "" then return dnm, true end
    if type(fallbackNm) == "string" and fallbackNm ~= "" then return fallbackNm, false end
    return "#" .. tostring(id), false
end

local function requestItem(id)
    local b = getBridge()
    if b and type(b.RequestItem) == "function" then
        b.RequestItem(id)
    end
end

E.ItemName = itemNameOf
E.RequestItem = requestItem

-- Shared mutable state tables (preserved across hot-reloads)
E.pendingPlans = type(E.pendingPlans) == "table" and E.pendingPlans or {}
E.endedPlan = type(E.endedPlan) == "table" and E.endedPlan or {}
E.bindErrors = type(E.bindErrors) == "table" and E.bindErrors or {}

function E.ProfInfo(slug)
    local api = getAPI()
    if api and type(api.ProfessionInfo) == "function" then
        return api.ProfessionInfo(slug)
    end
    local ds = getDS()
    local p = ds and type(ds.Profession) == "function" and ds.Profession(slug) or nil
    if not p then return nil end
    return {
        slug = slug,
        name = ds.ProfessionName and ds.ProfessionName(slug) or slug,
        icon = p.icon,
    }
end

function E.ProfName(slug)
    local info = E.ProfInfo(slug)
    if info and type(info.name) == "string" and info.name ~= "" then return info.name end
    local ds = getDS()
    if ds and type(ds.ProfessionName) == "function" then
        local nm = ds.ProfessionName(slug)
        if type(nm) == "string" and nm ~= "" then return nm end
    end
    return slug
end

function E.VendorName(npcID)
    if type(npcID) ~= "number" then return nil end
    local ds = getDS()
    local nm = ds and type(ds.RawText) == "function" and ds.RawText("npc", npcID) or nil
    if type(nm) == "string" and nm ~= "" then return nm end
    local legacy = fromNS("ProfVendorNames")
    if type(legacy) == "table" and type(legacy[npcID]) == "string" then
        return legacy[npcID]
    end
    return nil
end

function E.VendorLoc(npcID)
    if type(npcID) ~= "number" then return nil end
    local ds = getDS()
    local npc = ds and type(ds.Npc) == "function" and ds.Npc(npcID) or nil
    local sp = npc and type(npc.spawns) == "table" and npc.spawns[1] or nil
    local aid = sp and (sp.areaID or sp.zoneID) or nil
    if sp and (sp.uiMapID or aid) then
        return { aid, sp.uiMapID, sp.x, sp.y }
    end
    local legacy = fromNS("ProfVendors")
    if type(legacy) == "table" and type(legacy[npcID]) == "table" then
        return legacy[npcID]
    end
    return nil
end

local function normalizeFaction(f)
    if f == "Alliance" or f == "A" or f == "a" then return "A" end
    if f == "Horde" or f == "H" or f == "h" then return "H" end
    if f == "Neutral" or f == "N" or f == "n" or f == "Both" or f == "B" then return "N" end
    return nil
end

local function currentPlayerFaction()
    if type(_G.UnitFactionGroup) == "function" then
        local ok, eng = pcall(_G.UnitFactionGroup, "player")
        if ok then return normalizeFaction(eng) end
    end
    return nil
end

function E.IsVendorSold(itemID)
    if type(itemID) ~= "number" then return false end
    local supply = getSupply()
    if supply then
        if type(supply.CommonVendorCount) == "function" then
            local cnt = supply.CommonVendorCount(itemID)
            if type(cnt) == "number" and cnt > 0 then return true end
        end
        if type(supply.DisplayList) == "function" then
            local ok, list = pcall(supply.DisplayList, itemID, {})
            if ok and type(list) == "table" then
                for i = 1, #list do
                    local entry = list[i]
                    if type(entry) == "table"
                        and entry.unlimited == true
                        and entry.available ~= false
                        and not entry.hasExtendedCost then
                        return true
                    end
                end
                return false
            end
        end
    end
    local ds = getDS()
    local vo = ds and type(ds.VendorOffers) == "function" and ds.VendorOffers(itemID) or nil
    if type(vo) ~= "table" then return false end
    if (type(vo.commonVendorCount) == "number" and vo.commonVendorCount > 0) or vo.commonVendor == true then
        return true
    end
    local offers = vo.offers
    if type(offers) ~= "table" or #offers == 0 then return false end
    local pf = currentPlayerFaction()
    for i = 1, #offers do
        local o = offers[i]
        if type(o) == "table" then
            local ms = o.maxStock ~= nil and o.maxStock or o.stock
            local unlimited = (ms == -1 or ms == nil)
            local extended = (type(o.currencies) == "table" and #o.currencies > 0)
                or (type(o.costItems) == "table" and #o.costItems > 0)
            if unlimited and not extended then
                local npc = o.npcID and ds and type(ds.Npc) == "function" and ds.Npc(o.npcID) or nil
                local nf = normalizeFaction(o.faction or (npc and npc.faction))
                if not pf or not nf or nf == "N" or nf == pf then
                    return true
                end
            end
        end
    end
    return false
end

function E.TrackingPaused()
    local xp = getXP()
    return (xp and xp.IsCombatPaused and xp.IsCombatPaused()) and true or false
end

function E.SpellName(id)
    if not id or id == 0 then return "?" end
    local nm
    if _G.C_Spell and _G.C_Spell.GetSpellInfo then
        local ok, info = pcall(_G.C_Spell.GetSpellInfo, id)
        nm = ok and type(info) == "table" and info.name or nil
    end
    if (type(nm) ~= "string" or nm == "") and type(_G.GetSpellInfo) == "function" then
        local ok, v = pcall(_G.GetSpellInfo, id)
        if ok then nm = v end
    end
    if type(nm) == "string" and nm ~= "" then return nm end
    local ds = getDS()
    local dnm = ds and type(ds.RawText) == "function" and ds.RawText("spell", id) or nil
    if type(dnm) == "string" and dnm ~= "" then return dnm end
    return format(L["法术 #%d"], id)
end

function E.IsLearned(spellID)
    if not spellID then return false end
    if _G.C_Spell and _G.C_Spell.IsSpellKnown then
        local ok, r = pcall(_G.C_Spell.IsSpellKnown, spellID)
        if ok and r then return true end
    end
    for _, fn in ipairs({ _G.IsSpellKnown, _G.IsPlayerSpell }) do
        if type(fn) == "function" then
            local ok, r = pcall(fn, spellID)
            if ok and r then return true end
        end
    end
    return false
end

function E.Have(id)
    if _G.C_Item and _G.C_Item.GetItemCount then
        local ok, n = pcall(_G.C_Item.GetItemCount, id, false, false, false)
        if ok and type(n) == "number" and n >= 0 and n < huge and n == floor(n) then return n, true end
    end
    if type(_G.GetItemCount) == "function" then
        local ok, n = pcall(_G.GetItemCount, id, false)
        if ok and type(n) == "number" and n >= 0 and n < huge and n == floor(n) then return n, true end
    end
    return 0, false
end

function E.DbProf()
    local dbMod = getDBMod()
    if type(dbMod) == "function" then
        local root = dbMod()
        if type(root) == "table" then
            root.prof = root.prof or {}
            return root.prof
        end
    elseif type(dbMod) == "table" then
        local ok, root = pcall(dbMod)
        if ok and type(root) == "table" then
            root.prof = root.prof or {}
            return root.prof
        end
    end
    local fallback = _G.DungeonsForeverProfDB or _G.DungeonsForeverDB
    if type(fallback) == "table" then
        fallback.prof = fallback.prof or {}
        return fallback.prof
    end
    return {}
end

function E.CharKey()
    local name = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
    local realm = type(_G.GetRealmName) == "function" and _G.GetRealmName() or nil
    return (name or "?") .. "-" .. (realm or "?")
end

function E.OnlyMissView()
    return E.DbProf().shopOnlyMiss and true or false
end

function E.State()
    local p = E.DbProf()
    p.follow = p.follow or {}
    return p.follow[E.CharKey()]
end

function E.SkillOf(slug)
    local pd = getPD()
    if pd and type(pd.ProfLearned) == "function" then
        local learned = pd.ProfLearned(true)
        local entry = learned and learned[slug]
        if entry then return entry.cur, entry.max end
    end
    local api = getAPI()
    if api and type(api.ProfLearned) == "function" then
        local learned = api.ProfLearned(true)
        local entry = learned and learned[slug]
        if entry then return entry.cur, entry.max end
    end
    return nil, nil
end

function E.RouteDefaultTarget()
    local pd = getPD()
    return (pd and pd.LV_DEF) or 300
end

function E.RouteTarget(slug)
    local pd = getPD()
    local v
    if pd and pd.cur == slug and type(pd.LvTarget) == "function" then
        v = pd.LvTarget()
    else
        local db = E.DbProf()
        v = tonumber(db.lvTarget and db.lvTarget[slug])
    end
    if not v then return E.RouteDefaultTarget() end
    return max(1, min(300, floor(v)))
end

function E.RankTasks(slug, target, steps, currentIndex)
    local ranks = getRanks()
    if not (ranks and ranks.NextStep) then return {} end
    local targets, order = { [slug] = target or E.RouteTarget(slug) }, { slug }
    local current = steps and steps[currentIndex or 1]
    local partner = current and current.profession
    if partner and partner ~= slug then
        local recipe = current.recipe or {}
        targets[partner] = max(tonumber(current.goalSkill or current[2]) or 0, tonumber(recipe.learn or recipe.learnedAt) or 0)
        order[#order + 1] = partner
    end
    local tasks = {}
    for _, profession in ipairs(order) do
        local step = ranks.NextStep(profession, targets[profession])
        if step and step.due then tasks[#tasks + 1] = step end
    end
    return tasks
end

function E.SpecializationQuestInfo(seg)
    local xp = getXP()
    if not (xp and xp.IsSpecializationQuest and xp.IsSpecializationQuest(seg)) then return nil end
    local goal = xp.SpecializationQuest(seg)
    local function label(value)
        if type(value) ~= "table" then return value end
        local locale = hostLocale()
        return value[locale] or value.zhCN or value.enUS
    end
    local name = label(goal.questName or goal.name) or L["专业专精任务"]
    local lines = {}
    local identity = goal.questID and format(L["任务 #%d"], goal.questID) or L["任务身份尚未确认"]
    lines[#lines + 1] = identity
    local requirements = {}
    if type(goal.minSkill) == "number" then requirements[#requirements + 1] = format(L["需要专业技能 %d"], goal.minSkill) end
    if type(goal.minLevel) == "number" then requirements[#requirements + 1] = format(L["需要角色等级 %d"], goal.minLevel) end
    if #requirements > 0 then lines[#lines + 1] = table.concat(requirements, " · ") end
    if type(goal.inputs) == "table" and #goal.inputs > 0 then
        local materials = {}
        for _, pair in ipairs(goal.inputs) do
            local itemID = tonumber(pair[1])
            local quantity = tonumber(pair[2])
            if itemID and quantity and quantity > 0 then
                local nm, got = itemNameOf(itemID)
                if not got then requestItem(itemID) end
                if not nm or nm == "" then nm = "#" .. itemID end
                materials[#materials + 1] = format("%s ×%d", nm, quantity)
            end
        end
        if #materials > 0 then
            lines[#lines + 1] = format(L["任务材料：%s"], table.concat(materials, L["、"]))
        end
    end
    local place = {}
    if label(goal.npcName) then place[#place + 1] = label(goal.npcName)
    elseif goal.npcID then place[#place + 1] = "#" .. goal.npcID end
    if label(goal.zone) then place[#place + 1] = label(goal.zone) end
    if #place > 0 then lines[#lines + 1] = table.concat(place, " · ") end
    if type(goal.x) == "number" and type(goal.y) == "number" then
        lines[#lines + 1] = format(L["参考坐标 %.2f, %.2f"], goal.x, goal.y)
    end
    local gates = getGates()
    local prerequisites = gates and gates.PrerequisiteText and gates.PrerequisiteText(goal) or ""
    if prerequisites ~= "" then
        lines[#lines + 1] = format(L["先完成前置任务并与导师对话：%s"], prerequisites)
    end
    local progress = {}
    for key, value in pairs(goal.questProgress or {}) do progress[key] = value end
    local qapi = _G.C_QuestLog
    if goal.questID and qapi then
        for _, probe in ipairs({
            { "inLog", "IsOnQuest" },
            { "readyForTurnIn", "ReadyForTurnIn" },
            { "completed", "IsQuestFlaggedCompleted" },
        }) do
            if type(qapi[probe[2]]) == "function" then
                local ok, value = pcall(qapi[probe[2]], goal.questID)
                if ok and type(value) == "boolean" then progress[probe[1]] = value end
            end
        end
    end
    local status =
        progress.completed and L["任务已完成"]
        or progress.readyForTurnIn and L["任务可交付"]
        or progress.inLog and L["任务已接取"]
        or nil
    if status then lines[#lines + 1] = status end
    lines[#lines + 1] = L["实际学会对应专精后才完成此步骤。"]
    return {
        name = name,
        lines = lines,
        summary = identity .. (status and " · " .. status or ""),
        goal = goal,
    }
end

function E.ClipFixedSteps(steps, target)
    if not target or target >= 300 then return steps end
    local out = {}
    for _, step in ipairs(steps or {}) do
        local a, b = step[1], step[2]
        if a > target then break end
        local nb, nq = min(b, target), step[4] or 0
        local isClip = b > target
        if isClip and b > a then
            nq = max(1, ceil(nq * (target - a) / (b - a) - 1e-9))
        end
        local clipped = {}
        for key, value in pairs(step) do clipped[key] = value end
        clipped[2], clipped[4], clipped._clip = nb, step.checkpoint and 0 or nq, isClip or nil
        out[#out + 1] = clipped
    end
    return out
end

function E.IsGathering(slug)
    local gathering = getGather()
    if not (gathering and gathering.HasRoute and gathering.HasRoute(slug)) then return false end
    local view = getPD()
    return not (slug == "mining" and view and view.GatherMode and view.GatherMode(slug) == "smelt")
end

function E.HasRoute(slug)
    if not slug then return false end
    local gathering = getGather()
    if gathering and gathering.HasRoute and gathering.HasRoute(slug) then return true end
    local info = E.ProfInfo(slug)
    if info and (info.supportsAutoRoute or info.supportsExecution or info.fixedOnly) then return true end
    local xp = getXP()
    if xp and xp.GetPlan and xp.GetPlan(slug) then return true end
    return false
end

function E.Following(slug)
    local s = E.State()
    return (s and s.slug == slug) and true or false
end

local function routeForCalc(slug, skill)
    local ra = getRA()
    E.bindErrors[slug] = nil
    if slug == "poisons" then
        E.pendingPlans[slug] = nil
        local opts = ra and ra.OptionsFor and ra.OptionsFor(slug, skill) or {}
        opts.target, opts.scheme = E.RouteTarget(slug), "fixed"
        local summary = ra and ra.FixedPlan and ra.FixedPlan(slug, opts)
        local steps = E.ClipFixedSteps(summary and summary.steps or nil, E.RouteTarget(slug))
        return "fixed", steps, summary
    end
    if E.IsGathering(slug) then
        E.pendingPlans[slug] = nil
        local gathering = getGather()
        local steps = gathering and gathering.Steps and gathering.Steps(slug, E.RouteTarget(slug))
        if not steps then
            E.pendingPlans[slug] = { status = "incomplete", diagnostics = { { code = "professionCapUnknown" } } }
        end
        return "gather", steps or {}
    end
    local xp = getXP()
    local frozen, planError
    if xp and xp.GetPlan then frozen, planError = xp.GetPlan(slug) end
    if planError then
        E.pendingPlans[slug] = { status = "recalculate_required", slug = slug, feasible = false, diagnostics = { { code = planError } } }
        return "auto", {}
    end
    local economy = getEco()
    if frozen and frozen.learningPolicyFingerprint and economy and economy.LearningPolicyFingerprint
        and frozen.learningPolicyFingerprint ~= economy.LearningPolicyFingerprint() then
        E.pendingPlans[slug] = { status = "recalculate_required", feasible = false, diagnostics = { { code = "learningPolicyChanged" } } }
        return "auto", {}
    end
    local pd = getPD()
    local fixedOnly = slug == "first-aid" or slug == "poisons"
    if frozen and fixedOnly and frozen.mode ~= "fixed" then
        E.pendingPlans[slug] = { status = "recalculate_required", feasible = false, diagnostics = { { code = "fixedOnlyChanged" } } }
        return "fixed", {}
    end
    if frozen and frozen.pricingPolicyStale then
        E.pendingPlans[slug] = { status = "recalculate_required", feasible = false, diagnostics = { { code = "pricingPolicyChanged" } } }
        return "auto", {}
    end
    if frozen then
        return frozen.mode == "fixed" and "fixed" or "auto", frozen.steps, frozen
    end
    local ended = E.endedPlan[slug]
    if ended and E.Following(slug) then
        return ended.mode == "fixed" and "fixed" or "auto", ended.steps, ended
    end
    local scheme = pd and pd.SettingRaw and pd.SettingRaw("autoScheme", slug) or "cost"
    local fish = pd and pd.CookingFishingMode and pd.CookingFishingMode(slug)
    local auto = not fixedOnly and pd and (
        (pd.AutoRouteEnabled and pd.AutoRouteEnabled(slug))
        or (not pd.AutoRouteEnabled and pd.Setting and (pd.Setting("autoRoute", slug) or fish))
    ) and ra
    if auto then
        local opts = ra.OptionsFor and ra.OptionsFor(slug, skill) or {
            start = pd.AutoStartSkillOf and pd.AutoStartSkillOf(slug, skill)
                or ((pd.Setting("autoFromCurrent", slug) and skill) and max(1, skill) or 1),
            onlyAH = pd.Setting("autoOnlyAH", slug),
            allowLimitedFormulas = pd.Setting("autoBuyLimitedFormulas", slug),
            allowDropFormulas = pd.Setting("autoAllowDropFormulas", slug),
            allowCurrencyFormulas = pd.Setting("autoAllowCurrencyFormulas", slug),
            excludeQuestRecipes = pd.Setting("autoExcludeQuestRecipes", slug),
            excludeQuestTrainers = pd.Setting("autoExcludeQuestTrainers", slug),
            excludeQuestVendors = pd.Setting("autoExcludeQuestVendors", slug),
            excludeInstanceVendors = pd.Setting("autoExcludeInstanceVendors", slug),
            excludeInstanceTrainers = pd.Setting("autoExcludeInstanceTrainers", slug),
            target = E.RouteTarget(slug),
            scheme = fish and "fishing" or scheme,
        }
        opts.target = E.RouteTarget(slug)
        local res = ra.Get and ra.Get(slug, opts)
        local list = res and res.steps
        if res and res.status ~= "selection_required" and res.status ~= "recalculate_required" and res.feasible ~= false
            and list and #list > 0 then
            E.pendingPlans[slug] = nil
            local hudState = E.State()
            if xp and xp.Bind
                and hudState
                and hudState.slug == slug
                and not hudState.hidden
                and not hudState.autoTrackSuspended
                and res.status ~= "searching" and not res.finalizing then
                local bound, bindErr = xp.Bind(slug, res)
                if bound then
                    frozen = xp.GetPlan(slug)
                    if frozen then return "auto", frozen.steps, frozen end
                elseif bindErr then
                    E.bindErrors[slug] = bindErr
                end
            end
            return "auto", list, res
        end
        E.pendingPlans[slug] = res or { status = "not_calculated" }
        return "auto", {}
    end
    E.pendingPlans[slug] = nil
    local opts = ra and ra.OptionsFor and ra.OptionsFor(slug, skill) or {}
    opts.target, opts.scheme = E.RouteTarget(slug), "fixed"
    local summary = ra and ra.FixedPlan and ra.FixedPlan(slug, opts)
    local steps = E.ClipFixedSteps(summary and summary.steps or nil, E.RouteTarget(slug))
    if summary and summary.status == "recalculate_required" then
        E.pendingPlans[slug] = summary
        return "fixed", {}
    end
    if summary and summary.steps then steps = summary.steps end
    if ra and ra.FilterFixedSpecializations then
        local filtered, blocked = ra.FilterFixedSpecializations(slug, steps, opts)
        if blocked and #blocked > 0 then
            E.pendingPlans[slug] = {
                status = "recalculate_required",
                specializationBlocked = true,
                diagnostics = blocked or {},
                steps = {},
                feasible = false,
            }
            return "fixed", {}
        end
        steps = filtered
    end
    local hudState = E.State()
    if xp and hudState
        and hudState.slug == slug
        and not hudState.hidden
        and not hudState.autoTrackSuspended
        and steps and #steps > 0 then
        summary = summary or (ra and ra.SummarizeSteps and ra.SummarizeSteps(steps, slug, opts))
        summary = summary or { steps = steps, mats = {}, formulas = {}, total = 0, scheme = "fixed", target = E.RouteTarget(slug) }
        summary.mode = "fixed"
        summary.scheme = "fixed"
        local normalized, reason = xp.NormalizePlan(slug, summary)
        if not normalized or summary.feasible == false then
            E.pendingPlans[slug] = { status = "recalculate_required", feasible = false, diagnostics = { { code = reason or "fixedUnavailable" } } }
            return "fixed", {}
        end
        local run, bindErr = xp.Bind(slug, normalized)
        if run then
            return "fixed", run.plan.steps, run.plan
        elseif bindErr then
            E.bindErrors[slug] = bindErr
        end
    end
    return "fixed", steps, summary
end

local rMemoSlug, rMemoSkill, rMemoMode, rMemoSteps, rMemoPlan, rMemoT
local ROUTE_MEMO_TTL = 10

function E.RouteFor(slug, skill)
    local now = _G.GetTime and _G.GetTime() or 0
    if slug and rMemoSlug == slug and rMemoSkill == skill
        and (now - (rMemoT or 0)) < ROUTE_MEMO_TTL then
        return rMemoMode, rMemoSteps, rMemoPlan
    end
    local mode, steps, plan = routeForCalc(slug, skill)
    rMemoSlug, rMemoSkill, rMemoMode, rMemoSteps, rMemoPlan, rMemoT = slug, skill, mode, steps, plan, now
    return mode, steps, plan
end

function E.BindError(slug)
    return slug and E.bindErrors[slug] or nil
end

function E.InvalidateRoute()
    rMemoSlug, rMemoSkill, rMemoMode, rMemoSteps, rMemoPlan, rMemoT = nil, nil, nil, nil, nil, nil
end

function E.RouteKey(mode, steps)
    if not steps then return tostring(mode) .. ":0" end
    local a, b = steps[1], steps[#steps]
    return format("%s:%d:%s:%s:%s", tostring(mode), #steps,
        tostring(a and a[1]), tostring(a and a[3]), tostring(b and b[2]))
end

function E.DerivedStep(slug, skill)
    local xp = getXP()
    local run = slug ~= "poisons" and not E.IsGathering(slug) and xp and xp.GetRun and xp.GetRun(slug)
    if run then
        xp.Sync(slug)
        return run.currentIndex or 1
    end
    local ended = slug ~= "poisons" and E.endedPlan[slug]
    if ended and E.Following(slug) then
        return #(ended.steps or {}) + 1
    end
    local _, steps = E.RouteFor(slug, skill)
    if not steps then return nil end
    for i, s in ipairs(steps) do
        if next(s.requiredOutputs or {}) or s.kind == "specialization_quest" or s.kind == "essence_conversion" or skill < s[2] then
            return i
        end
    end
    return #steps + 1
end

function E.RecMats(rec)
    if not rec then return nil end
    if rec[12] or rec.mats then return rec[12] or rec.mats end
    if type(rec.reagents) == "table" then
        local out = {}
        for i = 1, #rec.reagents do
            local m = rec.reagents[i]
            if type(m) == "table" and type(m.itemID) == "number" then
                out[#out + 1] = { m.itemID, m.count or 1 }
            end
        end
        return out
    end
    return nil
end

function E.RecItem(rec)
    return rec and (rec[2] or rec.outputItemID or rec.item or rec.makes) or nil
end

function E.RecOutputMin(rec, seg)
    local v = (seg and seg.outputMin) or (rec and (rec.outputMin or rec.outputCountMin or rec[3] or rec.count))
    return type(v) == "number" and v > 0 and v or nil
end

function E.RecBreaks(rec)
    if not rec then return nil end
    return rec[7] or rec.learnedAt or rec.orange or rec.learn,
        rec[8] or rec.yellow,
        rec[9] or rec.green,
        rec[10] or rec.grey
end

function E.RecForLevelSrc(rec, spellID)
    if type(rec) ~= "table" then return rec end
    if rec.spell or rec[1] then return rec end
    local sid = rec.spellID or spellID
    if type(sid) ~= "number" then return rec end
    local out = { [1] = sid, spell = sid }
    for k, v in pairs(rec) do out[k] = v end
    return out
end

local recCache = {}

function E.InvalidateRecipeCache(slug)
    if slug then
        recCache[slug] = nil
    else
        recCache = {}
    end
end

function E.RecMap(slug)
    local c = recCache[slug]
    if not c then
        c = {}
        local ds = getDS()
        local bucket = ds and ds.EnsureRecipes and ds.EnsureRecipes(slug) or nil
        if type(bucket) == "table" and type(bucket.recipes) == "table" then
            for spellID, recipe in pairs(bucket.recipes) do
                if type(spellID) == "number" and type(recipe) == "table" then
                    c[spellID] = recipe
                end
            end
        end
        recCache[slug] = c
    end
    return c
end

function E.StepRecipe(seg, fallback)
    if seg and seg.recipe then return seg.recipe end
    local xp = getXP()
    if seg and xp and xp.IsConversion and xp.IsConversion(seg) then
        local conversion = xp.Conversion(seg)
        if conversion then
            return {
                mats = { { conversion.inputItemID, conversion.inputCount } },
                item = conversion.outputItemID,
                count = conversion.outputCount,
            }
        end
    end
    if seg and xp and xp.IsSpecializationQuest and xp.IsSpecializationQuest(seg) then
        return { mats = xp.SpecializationQuest(seg).inputs or {} }
    end
    return fallback
end

function E.LearningWarning(slug, progress)
    if slug == "poisons" then return nil end
    local xp = getXP()
    progress = progress or (xp and xp.Progress and xp.Progress(slug))
    if not (progress and progress.learningBlocked) then return nil end
    local eco = getEco()
    return eco and eco.DiagnosticText and eco.DiagnosticText(progress.reason or "learningDataMissing")
        or L["学习来源尚未确认"]
end

function E.DescribeStep(seg, rec, slug)
    local xp = getXP()
    local questInfo = E.SpecializationQuestInfo(seg)
    if questInfo then
        return {
            kind = "specialization_quest",
            manual = true,
            name = questInfo.name,
            subtitle = questInfo.summary,
            srcLabel = L["任务"],
            guide = questInfo,
            questInfo = questInfo,
            spellID = nil,
        }
    end
    if xp and xp.IsConversion and xp.IsConversion(seg) then
        return {
            kind = "conversion",
            manual = true,
            name = L["精华转换"],
            subtitle = nil,
            srcLabel = L["精华转换"],
            guide = nil,
            spellID = nil,
        }
    end
    if seg.navigationOnly then
        local nm = seg.name or L["参考"]
        return {
            kind = "gather",
            manual = true,
            name = nm,
            subtitle = L["按实际技能推进；不预计采集产出。"],
            srcLabel = L["参考"],
            guide = { name = nm, lines = { seg.detail or seg.note or "" } },
            spellID = nil,
        }
    end
    if seg.checkpoint then
        if seg.kind == "disenchant" then
            local nm = seg.name or L["分解"]
            local note = type(seg.note) == "string" and seg.note ~= "" and seg.note or nil
            return {
                kind = "disenchant",
                manual = true,
                name = nm,
                subtitle = note or L["按实际技能推进；不预计采集产出。"],
                srcLabel = L["分解"],
                guide = { name = nm, lines = { note or L["按实际技能推进；不预计采集产出。"] } },
                spellID = nil,
            }
        elseif seg.kind == "note" then
            local nm = seg.name or L["参考"]
            local note = type(seg.note) == "string" and seg.note ~= "" and seg.note or nil
            return {
                kind = "note",
                manual = true,
                name = nm,
                subtitle = note or L["按实际技能推进；不预计采集产出。"],
                srcLabel = L["参考"],
                guide = { name = nm, lines = { note or "" } },
                spellID = nil,
            }
        else
            local nm = seg.name or L["实地采矿"]
            local note = type(seg.note) == "string" and seg.note ~= "" and seg.note or nil
            return {
                kind = "checkpoint",
                manual = true,
                name = nm,
                subtitle = note or L["不预先计入尚未采到的矿石"],
                srcLabel = L["采集"],
                guide = note and { name = nm, lines = { note } } or nil,
                spellID = nil,
            }
        end
    end
    local spellID = (tonumber(seg[3]) or 0) > 0 and seg[3] or nil
    local nm = seg.name or (spellID and E.SpellName(spellID)) or L["实地采矿"]
    return {
        kind = "craft",
        manual = spellID == nil,
        name = nm,
        subtitle = nil,
        srcLabel = nil,
        guide = nil,
        spellID = spellID,
    }
end

function E.PurchaseSource(entry)
    local source = entry.source or entry.sourceType
    if source ~= nil then return source end
    return entry.vendor and "vendor" or nil
end

local function copyPurchase(entry)
    local out = {}
    for key, value in pairs(entry) do out[key] = value end
    out.id = entry.id or entry[1]
    out.count = tonumber(entry.count or entry[2]) or 0
    out.source = E.PurchaseSource(entry)
    return out
end

local function allocatePurchases(row)
    row.purchases = {}
    row.purchaseCount = 0
    row.purchaseCost = 0
    row.ahCount, row.vendorCount = 0, 0
    row.materialNeed = max(0, (row.need or 0) - (row.formulaNeed or 0))
    row.materialMissing = row.haveKnown and max(0, row.materialNeed - max(0, row.have - (row.formulaNeed or 0))) or nil
    if not row.haveKnown then
        row.purchaseCount, row.purchaseCost = nil, nil
        row.purchaseUnknown = true
        row.inventoryUnknown = true
        return
    end
    local left = max(0, row.need - row.have)
    row.missing = left
    row.baseMissing = max(0, (row.baseNeed or row.need) - row.have)
    row.reserveMissing = max(0, left - row.baseMissing)
    if left > 0 and row.craftedIntermediate and (row.formulaNeed or 0) == 0 then
        row.requiresRecalculation = true
        row.purchaseUnknown = true
        row.purchaseUncovered = left
        row.purchaseCount, row.purchaseCost = nil, nil
        return
    end
    local bridge = getAuctionBridge()
    local useSupply = row.considerAuctionSupply ~= false
    local available = useSupply and row.availableCount or nil
    if useSupply and row.planAHCount > 0 and bridge and bridge.GetAuctionSupply then
        local observed = bridge.GetAuctionSupply(row.id)
        available = observed and observed.quantity or nil
        row.availableCount = available
        row.supplyObserved = available ~= nil
        row.supplyStatus = bridge.GetAuctionSupplyStatus and bridge.GetAuctionSupplyStatus(row.id)
            or (available == nil and "unknown" or "verified")
    end
    row.supplyChanged = available ~= nil and available < row.planAHCount
    local function add(entry, count, cost)
        if count <= 0 then return end
        local item = copyPurchase(entry)
        item.count = count
        item[2] = count
        item.cost = cost
        row.purchases[#row.purchases + 1] = item
        row.purchaseCount = row.purchaseCount + count
        if type(cost) == "number" and not item.unpriced then
            row.purchaseCost = row.purchaseCost and row.purchaseCost + cost
        else
            row.purchaseCost = nil
            row.costUnknown = true
        end
        if item.source == "ah" or item.source == "auction" then
            row.ahCount = row.ahCount + count
        elseif item.source == "vendor" or item.source == "npc" then
            row.vendorCount = row.vendorCount + count
        end
    end
    local formulaLeft = max(0, (row.formulaNeed or 0) - row.have)
    local formulaAH = 0
    for _, entry in ipairs(row.planPurchases or {}) do
        if entry.formula and formulaLeft > 0 then
            local count = min(formulaLeft, entry.count)
            add(entry, count, entry.cost)
            formulaLeft = formulaLeft - count
            left = max(0, left - count)
            if entry.source == "ah" or entry.source == "auction" then formulaAH = formulaAH + count end
            if entry.usable == false or entry.unavailable or entry.available == false or entry.purchasable == false then
                row.purchaseUncovered = (row.purchaseUncovered or 0) + count
            end
        end
    end
    local offers, auction, ahLimit = {}, nil, 0
    local ahCostSum, ahCountSum = 0, 0
    local hasMaterials = false
    local quotesComplete = true
    for _, entry in ipairs(row.planPurchases or {}) do
        if not entry.formula then
            hasMaterials = true
            local source = entry.source
            if source == "ah" or source == "auction" then
                ahLimit = ahLimit + entry.count
                if type(entry.cost) == "number" and entry.count > 0 and entry.cost > 0 and not entry.unpriced then
                    ahCostSum = ahCostSum + entry.cost
                    ahCountSum = ahCountSum + entry.count
                    auction = ahCostSum / ahCountSum
                else
                    quotesComplete = false
                end
            elseif source == "vendor" or source == "npc" then
                local offer = copyPurchase(entry)
                local size = entry.bundleSize or 1
                local price = entry.bundlePrice or (type(entry.cost) == "number" and entry.count > 0 and entry.cost * size / entry.count)
                if type(entry.cost) == "number" and type(price) == "number" and price >= 0 and not entry.unpriced and entry.unlimited == true then
                    offer.quantity, offer.price = size, price
                    offers[#offers + 1] = offer
                else
                    quotesComplete = false
                end
            else
                quotesComplete = false
            end
        end
    end
    local bagQuotes = row.bagMaterialQuotes
    if bagQuotes then
        hasMaterials = true
        local book = bagQuotes.auctionDepth and bagQuotes.auctionDepth[row.id]
        local supply = bagQuotes.auctionSupply and bagQuotes.auctionSupply[row.id]
        available = available or (supply and supply.quantity) or (book and book.total)
        ahLimit = available and max(0, available - formulaAH) or huge
        row.availableCount = available
    elseif useSupply and available ~= nil then
        ahLimit = max(0, available - formulaAH)
    elseif not useSupply and auction ~= nil then
        ahLimit = max(ahLimit, left)
    end
    local ra = getRA()
    if left > 0 and hasMaterials then
        local entries, complete
        if bagQuotes then
            local economy = getEco()
            local depthMod = getAuctionDepth()
            local price = bagQuotes.prices and bagQuotes.prices[row.id]
            local book = bagQuotes.auctionDepth and bagQuotes.auctionDepth[row.id]
            if (bagQuotes.nonAuctionable or {})[row.id] or type(price) ~= "number" or price <= 0 then price = nil end
            local total
            entries, total, complete = economy.MaterialPurchases(row.id, left, {
                offers = bagQuotes.offers and bagQuotes.offers[row.id] or {},
                auction = price,
                supply = bagQuotes.auctionSupply and bagQuotes.auctionSupply[row.id],
                available = available and ahLimit or nil,
                faction = bagQuotes.faction,
                auctionCost = book and function(count)
                    return economy and depthMod and depthMod.Cost and depthMod.Cost(book, formulaAH, count) or huge
                end or nil,
            })
        elseif quotesComplete and ra and ra.MaterialPurchases then
            local snap = { prices = { [row.id] = auction }, offers = { [row.id] = offers }, auctionSupply = {}, considerAuctionSupply = useSupply }
            if available ~= nil then snap.auctionSupply[row.id] = { quantity = ahLimit } end
            local total
            entries, total, complete = ra.MaterialPurchases(row.id, left, { snapshot = snap, auctionRemaining = { [row.id] = ahLimit } })
        elseif row.have == 0 and row.need == row.planDemand then
            entries = {}
            complete = true
            for _, entry in ipairs(row.planPurchases or {}) do
                if not entry.formula then entries[#entries + 1] = entry end
            end
        elseif row.planVendorCount == 0 and row.planAHCount >= left + formulaAH then
            entries = { { id = row.id, count = left, source = "ah", unit = auction, cost = auction and auction * left } }
            complete = available == nil or available >= left + formulaAH
        else
            row.purchaseUnknown = true
            row.purchaseCount, row.purchaseCost = nil, nil
        end
        if entries then
            local covered = 0
            local remainingAH = ahLimit
            for _, entry in ipairs(entries) do
                local count = tonumber(entry.count or entry[2]) or 0
                local cost = entry.cost
                if E.PurchaseSource(entry) == "ah" or E.PurchaseSource(entry) == "auction" then
                    local requested = count
                    count = min(count, remainingAH)
                    remainingAH = max(0, remainingAH - count)
                    if count ~= requested then
                        cost = entry.unit and entry.unit * count
                            or (type(entry.cost) == "number" and requested > 0 and entry.cost * count / requested)
                            or nil
                    end
                end
                add(entry, count, cost)
                if E.PurchaseSource(entry) ~= nil and (not bagQuotes or (not entry.unavailable and not entry.unpriced)) then
                    covered = covered + count
                end
            end
            if complete == false or covered < left then
                row.purchaseUncovered = (row.purchaseUncovered or 0) + max(0, left - covered)
            end
        end
    elseif left > 0 then
        row.purchaseUncovered = (row.purchaseUncovered or 0) + left
    end
    if bagQuotes and (row.purchaseUncovered or 0) > 0 then
        row.purchaseUnknown = true
        row.purchaseCost = nil
        row.costUnknown = true
    end
    if row.purchaseCount then row.packSurplus = max(0, row.purchaseCount - row.missing) end
    if useSupply and row.ahCount > 0 then
        row.auctionUnknown = available == nil
        if available ~= nil and available < row.ahCount then row.auctionShortage = row.ahCount - available end
    end
    row.purchaseChanged = row.purchaseCount ~= row.planPurchaseCount or row.purchaseCost ~= row.planPurchaseCost
end

local function expPerPoint(sk, o, y, g, gr)
    if sk < y then return 1 end
    if gr and gr > y and sk < gr then
        local p = (gr - sk) / (gr - y)
        if p > 0 then return 1 / p end
    end
    return nil
end

function E.ProgressReader(run)
    local eco, xp = getEco(), getXP()
    local snapshot, credits
    local cache = {}
    return function(id)
        local key = id or false
        if not cache[key] then
            if not credits then
                snapshot = eco and eco.Professions and eco.Professions()
                credits = {}
            end
            cache[key] = xp.Progress(run.slug, id, snapshot, run.planID, credits)
        end
        return cache[key]
    end
end

function E.CraftsLeft(seg, skill, rec, routeSlug, future, readProgress)
    local xp = getXP()
    if seg.segmentID and xp and xp.CurrentPlan then
        local slug = routeSlug or (E.State() and E.State().slug)
        local run = slug and xp.GetRun(slug)
        if run then
            local progress = readProgress and readProgress(seg.segmentID) or xp.Progress(run.slug, seg.segmentID)
            if progress and (progress.segmentID == seg.segmentID or progress.complete ~= true) then
                if xp.IsSpecializationQuest and xp.IsSpecializationQuest(seg) then
                    return progress.complete and 0 or 1
                end
                local untouched = (progress.attemptsDone or 0) == 0 and type(progress.currentSkill) == "number"
                    and progress.currentSkill <= (seg[1] or 0)
                if (future or untouched) and not progress.skillDone and not (xp.IsConversion and xp.IsConversion(seg)) then
                    if seg.reason ~= "material" and seg.role ~= "material" then
                        local planned = max(0, (seg.expectedCrafts or seg[4] or 0) - (progress.attemptsDone or 0))
                        local output = E.RecOutputMin(rec, seg) or 1
                        local required = output > 0 and ceil((progress.remainingOutputs or 0) / output) or 0
                        return max(planned, required)
                    end
                end
                return progress.remainingCrafts or 0
            end
        end
    end
    if xp and xp.IsSpecializationQuest and xp.IsSpecializationQuest(seg) then return 1 end
    if future or (skill or 0) <= (seg[1] or 0) then
        return seg.expectedCrafts or seg[4] or 0
    end
    local from = max(skill or 0, seg[1])
    if from >= seg[2] then return 0 end
    local learn, y, g, gr = E.RecBreaks(rec)
    if y and g and gr and g > y and gr > g then
        local total = 0
        for sk = from, seg[2] - 1 do
            local ev = expPerPoint(sk, learn, y, g, gr)
            if not ev then break end
            total = total + ev
        end
        if expPerPoint(seg[2] - 1, learn, y, g, gr) then return total end
    end
    local span = max(1, seg[2] - seg[1])
    return (seg[4] or 0) * min(1, (seg[2] - from) / span)
end

function E.CurrentCands(steps, skill, curStep, slug, rm, run)
    local out = { max(1, min(#steps, curStep or 1)) }
    local xp = getXP()
    local readProgress = run and E.ProgressReader(run)
    local first = steps[out[1]]
    local profession = first and (first.profession or slug)
    if profession ~= slug then skill = E.SkillOf(profession) or 0 end
    local reserved, produced, consumers = {}, {}, {}
    for i = out[1], #steps do
        local sg = steps[i]
        if (sg.profession or slug) ~= profession or sg.navigationOnly or sg.checkpoint or sg.tool
            or (tonumber(sg[3]) or 0) <= 0
            or (xp and ((xp.IsConversion and xp.IsConversion(sg)) or (xp.IsSpecializationQuest and xp.IsSpecializationQuest(sg)))) then
            break
        end
        local a, b = tonumber(sg[1]) or 0, tonumber(sg[2]) or 0
        if i > out[1] and a > skill then break end
        local rec = E.StepRecipe(sg, rm[sg[3]])
        local progress = readProgress and readProgress(sg.segmentID or i)
        if progress and progress.blocked then break end
        local remaining = ceil(E.CraftsLeft(sg, skill, rec, slug, i ~= out[1], readProgress))
        if i > out[1] and a <= skill and skill < b and sg[3] ~= first[3]
            and remaining > 0 and not (progress and progress.complete)
            and not consumers[sg.segmentID or i] and E.IsLearned(sg[3]) then
            local safe = rec ~= nil
            if run and xp and xp.ValidateLearning then safe = safe and xp.ValidateLearning(run.plan, slug, sg) end
            for _, m in ipairs(E.RecMats(rec) or {}) do
                local have, known = E.Have(m[1], false)
                if not known or produced[m[1]] or have < (reserved[m[1]] or 0) + (m[2] or 1) * remaining then
                    safe = false
                    break
                end
            end
            if safe then
                out[2] = i
                break
            end
        end
        if remaining > 0 then
            for _, m in ipairs(E.RecMats(rec) or {}) do
                reserved[m[1]] = (reserved[m[1]] or 0) + (m[2] or 1) * remaining
            end
            local item = E.RecItem(rec)
            if item then produced[item] = true end
            for _, allocation in ipairs(sg.allocations or {}) do
                if (allocation.count or 0) > 0 and allocation.consumerID then consumers[allocation.consumerID] = true end
            end
            for _, allocation in ipairs(sg.reserve and sg.reserve.allocations or {}) do
                if (allocation.count or 0) > 0 and allocation.consumerID then consumers[allocation.consumerID] = true end
            end
        end
    end
    return out
end

function E.ShopList(s, onlyStep, bagsOnly, suppliedPlan)
    local _, steps, plan
    if suppliedPlan then
        plan = suppliedPlan
        steps = plan.steps
    else
        _, steps, plan = E.RouteFor(s.slug, s.skill)
    end
    if not steps then return {} end
    if plan and plan.useBagMaterials then bagsOnly = true end
    local rm = E.RecMap(s.slug)
    local totals, order = {}, {}
    local futureOutputs, futureSpells = {}, {}
    local xp = getXP()
    local run = xp and xp.GetRun and xp.GetRun(s.slug)
    local readProgress = run and E.ProgressReader(run)
    local matching = run and plan and (run.plan == plan or (plan.planID and run.originPlanID == plan.planID))
    local projected = not onlyStep and not matching and plan and xp and xp.PreviewProgress and xp.PreviewProgress(s.slug, plan)
    local casts, completed, baseRemaining = {}, {}, {}
    if not onlyStep and (matching or projected) then
        for _, seg in ipairs(steps) do
            local progress = matching and readProgress(seg.segmentID) or projected[seg.segmentID]
            if progress and progress.segmentID == seg.segmentID then
                casts[seg.segmentID] = progress.casts
                completed[seg.segmentID] = progress.complete
                baseRemaining[seg.segmentID] = progress.baseRemaining or 0
            end
        end
    end
    local curStep = s.step or 1
    local dbMod = getDBMod()
    local reserveMode = (type(dbMod) == "table" and type(dbMod.SettingRaw) == "function" and dbMod.SettingRaw("autoReserveMode", s.slug))
        or (plan and plan.reserveMode) or "safe"
    local reserveSafe = reserveMode ~= "expected" and not (plan and (plan.scheme == "fixed" or plan.scheme == "fishing"))
    local reserveRemainingIn, reserveRemainingOut = {}, {}
    for i = curStep, #steps do
        if onlyStep and i > curStep then break end
        local seg = steps[i]
        local rec = E.StepRecipe(seg, rm[seg[3]])
        local mats = E.RecMats(rec)
        local crafts = seg[4] or 0
        if seg.segmentID or i == curStep then
            crafts = ceil(E.CraftsLeft(seg, s.skill, rec, s.slug, i > curStep, readProgress))
        end
        if projected and projected[seg.segmentID]
            and (seg.reason == "material" or seg.role == "material" or (xp and xp.IsConversion and xp.IsConversion(seg))) then
            crafts = min(crafts, projected[seg.segmentID].baseCrafts or crafts)
        elseif not onlyStep and matching then
            crafts = min(crafts, baseRemaining[seg.segmentID] or 0)
        end
        local extraCrafts = 0
        if reserveSafe and crafts > 0 and (seg.extraReserveCrafts or 0) > 0 then
            local denom = max(1, seg.expectedCrafts or seg[4] or 1)
            extraCrafts = crafts >= denom and seg.extraReserveCrafts or ceil(seg.extraReserveCrafts * min(1, crafts / denom))
        end
        if crafts > 0 then
            futureSpells[(seg.profession or s.slug) .. ":" .. tostring(seg[3])] = true
            local item = E.RecItem(rec)
            local output = E.RecOutputMin(rec, seg)
            if item and type(output) == "number" and output > 0 then
                futureOutputs[item] = (futureOutputs[item] or 0) + crafts * output
                if extraCrafts > 0 then
                    reserveRemainingOut[item] = (reserveRemainingOut[item] or 0) + extraCrafts * output
                end
            end
        end
        if mats and crafts > 0 then
            for _, m in ipairs(mats) do
                local e = totals[m[1]]
                if not e then
                    e = { id = m[1], need = 0, at = seg[1] }
                    totals[m[1]] = e
                    order[#order + 1] = m[1]
                end
                local qty = (m[2] or 1) * crafts
                local rQty = (m[2] or 1) * extraCrafts
                if onlyStep and rQty > 0 then
                    e.baseNeed = (e.baseNeed or e.need) + qty
                    e.reserveNeed = (e.reserveNeed or 0) + rQty
                    e.need = e.baseNeed + e.reserveNeed
                else
                    e.need = e.need + qty
                    if rQty > 0 then
                        reserveRemainingIn[m[1]] = (reserveRemainingIn[m[1]] or 0) + rQty
                    end
                end
                if i == curStep then e.atStep = (e.atStep or 0) + qty + (onlyStep and rQty or 0) end
            end
        end
    end
    local gates = getGates()
    local active = s.slug ~= "poisons" and xp and xp.GetPlan and xp.GetPlan(s.slug)
    local goal = (not active and not onlyStep) and gates and gates.SpecGoal and gates.SpecGoal(s.slug, E.RouteTarget(s.slug))
    if goal and type(goal.inputs) == "table" then
        for _, pair in ipairs(goal.inputs) do
            local sid, sn = pair[1], tonumber(pair[2]) or 0
            if type(sid) == "number" and sn > 0 then
                local e = totals[sid]
                if not e then
                    e = { id = sid, need = 0, at = huge }
                    totals[sid] = e
                    order[#order + 1] = sid
                end
                e.spec = true
                e.need = e.need + sn
            end
        end
    end
    if not onlyStep and plan then
        local leaves = {}
        local originalNeeds, originalOutputs = {}, {}
        for _, segment in ipairs(steps) do
            local recipe = E.StepRecipe(segment, rm[segment[3]])
            local count = ceil(segment.expectedCrafts or segment[4] or 0)
            for _, material in ipairs(E.RecMats(recipe) or {}) do
                originalNeeds[material[1]] = (originalNeeds[material[1]] or 0) + (material[2] or 1) * count
            end
            local item = E.RecItem(recipe)
            local output = E.RecOutputMin(recipe, segment)
            if item and type(output) == "number" and output > 0 then
                originalOutputs[item] = (originalOutputs[item] or 0) + output * count
            end
        end
        local function purchase(entry, formula)
            local id = entry.id or entry[1]
            if not id then return end
            local leaf = leaves[id]
            if not leaf then
                leaf = { planPurchaseCount = 0, planPurchaseCost = 0, planAHCount = 0, planVendorCount = 0, planPurchases = {} }
                leaves[id] = leaf
            end
            local count = tonumber(entry.count or entry[2]) or (formula and 1 or 0)
            local source = E.PurchaseSource(entry)
            if leaf.source and leaf.source ~= source then
                leaf.source = "mixed"
            elseif not leaf.source then
                leaf.source = source
            end
            leaf.planPurchaseCount = leaf.planPurchaseCount + count
            if type(entry.cost) == "number" and not entry.unpriced then
                leaf.planPurchaseCost = leaf.planPurchaseCost and leaf.planPurchaseCost + entry.cost
            else
                leaf.planPurchaseCost = nil
            end
            leaf.considerAuctionSupply = plan.considerAuctionSupply
            local receipt = copyPurchase(entry)
            receipt.formula = formula and true or false
            receipt.count = count
            receipt.considerAuctionSupply = plan.considerAuctionSupply
            leaf.planPurchases[#leaf.planPurchases + 1] = receipt
            if source == "ah" or source == "auction" then
                leaf.planAHCount = leaf.planAHCount + count
            elseif source == "vendor" or source == "npc" then
                leaf.planVendorCount = leaf.planVendorCount + count
            end
            for _, key in ipairs({
                "npcID", "unlimited", "limited", "stockUnknown", "availableCount",
                "supplyObserved", "supplyStatus", "supplyRequired", "supplyComplete", "supplyObservedAt",
                "supplySource", "supplyMethod", "unit", "bundleSize",
            }) do
                if leaf[key] == nil then leaf[key] = entry[key] end
            end
            if formula then leaf.formulaCost = (leaf.formulaCost or 0) + (entry.cost or 0) end
        end
        local useReserveMats = reserveSafe and type(plan.reserve) == "table" and type(plan.reserve.mats) == "table" and #plan.reserve.mats > 0
        for _, entry in ipairs(useReserveMats and plan.reserve.mats or plan.mats or {}) do purchase(entry) end
        if plan.useBagMaterials then
            for id, count in pairs(plan.seedInventory or {}) do
                local amount = type(count) == "table" and count.count or count
                if type(amount) == "number" and amount > 0 and not leaves[id] then
                    leaves[id] = { planPurchaseCount = 0, planPurchaseCost = 0, planAHCount = 0, planVendorCount = 0, planPurchases = {} }
                end
            end
        end
        for id, quantity in pairs(plan.retainedToolItems or {}) do
            if leaves[id] then
                if not totals[id] then
                    totals[id] = { id = id, need = 0, at = huge }
                    order[#order + 1] = id
                end
                totals[id].need = totals[id].need + (tonumber(quantity) or 0)
            end
        end
        for _, id in ipairs(plan.toolItems or {}) do
            if leaves[id] and not (plan.retainedToolItems and plan.retainedToolItems[id]) then
                if not totals[id] then
                    totals[id] = { id = id, need = 0, at = huge }
                    order[#order + 1] = id
                end
                totals[id].need = totals[id].need + 1
            end
        end
        for _, id in ipairs(order) do
            local row = totals[id]
            row.need = max(0, row.need - (futureOutputs[id] or 0))
            if type(plan.mats) == "table" and not leaves[id] then row.need = 0 end
            row.baseNeed = row.need
        end
        if useReserveMats then
            local grossCap = plan.reserve.grossExtraByItem or plan.reserve.extraByItem or {}
            for id, capExtra in pairs(grossCap) do
                if (capExtra or 0) > 0 and leaves[id] then
                    local row = totals[id]
                    if not row then
                        row = { id = id, need = 0, baseNeed = 0, at = huge }
                        totals[id] = row
                        order[#order + 1] = id
                    end
                    local remExtra = curStep <= 1 and capExtra
                        or min(capExtra, max(0, (reserveRemainingIn[id] or 0) - (reserveRemainingOut[id] or 0)))
                    if remExtra > 0 then
                        row.reserveNeed = remExtra
                        row.need = (row.baseNeed or 0) + remExtra
                    end
                end
            end
        end
        local economy = getEco()
        for _, entry in ipairs(plan.formulas or {}) do
            local spell = entry.spell
            local needed = not spell or futureSpells[(entry.profession or s.slug) .. ":" .. spell]
            local known = entry.known or (spell and economy and economy.Known and economy.Known(spell))
            local id = entry.id or entry[1]
            if id and needed and not known and entry.usable ~= false then
                local row = totals[id]
                if not row then
                    row = { id = id, need = 0, baseNeed = 0, at = huge }
                    totals[id] = row
                    order[#order + 1] = id
                end
                local count = tonumber(entry.count or entry[2]) or 1
                if count > (row.formulaNeed or 0) then
                    purchase(entry, true)
                    local addF = count - (row.formulaNeed or 0)
                    row.need = row.need + addF
                    row.baseNeed = (row.baseNeed or 0) + addF
                end
                row.formulaNeed = max(row.formulaNeed or 0, count)
                row.formula = true
            end
        end
        for _, id in ipairs(order) do
            local row, leaf = totals[id], leaves[id]
            if leaf then
                for key, value in pairs(leaf) do row[key] = value end
                if plan.useBagMaterials then
                    row.bagMaterialQuotes = plan.bagMaterialQuotes
                    row.useBagMaterials = true
                end
                local tools = tonumber((plan.retainedToolItems or {})[id]) or 0
                if tools == 0 then
                    for _, tool in ipairs(plan.toolItems or {}) do
                        if tool == id then tools = 1; break end
                    end
                end
                local rExtra = useReserveMats and (row.reserveNeed or 0) or 0
                row.planDemand = max(0, (originalNeeds[id] or 0) - (originalOutputs[id] or 0)) + tools + (row.formulaNeed or 0) + rExtra
                row.craftedIntermediate = (leaf.planPurchaseCount == 0 and (originalOutputs[id] or 0) > 0) or nil
            end
        end
    end
    local list = {}
    for _, id in ipairs(order) do
        local e = totals[id]
        if onlyStep or e.need > 0 then
            e.have, e.haveKnown = E.Have(e.id)
            if s.slug == "poisons" then
                e.vendor = E.IsVendorSold(e.id)
                e.source = e.vendor and "vendor" or "ah"
            end
            if not onlyStep and e.planPurchases then allocatePurchases(e) end
            list[#list + 1] = e
        end
    end
    return list
end

function E.ShoppingForPlan(slug, plan)
    local xp = getXP()
    local run = xp and xp.GetRun and xp.GetRun(slug)
    local matching = run and (run.plan == plan or (plan.planID and run.originPlanID == plan.planID))
    return E.ShopList({ slug = slug, skill = E.SkillOf(slug) or plan.start or 1, step = matching and run.currentIndex or 1 }, false, true, plan)
end

function E.ShoppingList(slug, onlyStep)
    local state = E.State()
    if not state or state.slug ~= slug then
        local skill = E.SkillOf(slug) or 0
        state = { slug = slug, skill = skill, step = E.DerivedStep(slug, skill) or 1 }
    end
    return E.ShopList(state, onlyStep)
end

function E.ShoppingSourceText(entry)
    local ra = getRA()
    if entry.planPurchases then
        if entry.requiresRecalculation then
            return format(L["原计划货源还缺 %d 件，请重新计算。"], entry.purchaseUncovered or 0)
        end
        if entry.inventoryUnknown then
            return L["请检查背包"]
        end
        if entry.purchaseUnknown then return L["请核对价格"] end
        local parts = {}
        if (entry.reserveNeed or 0) > 0 then
            parts[#parts + 1] = format(L["基础缺 %d · 备用缺 %d"], entry.baseMissing or 0, entry.reserveMissing or 0)
        end
        for _, purchase in ipairs(entry.purchases or {}) do
            local source = E.PurchaseSource(purchase)
            local name = (source == "ah" or source == "auction") and L["拍卖行"]
                or (source == "vendor" or source == "npc") and (E.VendorName(purchase.npcID) or L["商人"])
                or L["尚无购买来源"]
            local cost = type(purchase.cost) == "number" and not purchase.unpriced and ra and ra.MoneyStr and ra.MoneyStr(purchase.cost, "copper")
                or L["请核对价格"]
            local text = format("%s ×%d · %s", name, purchase.count or 0, cost)
            if (source == "ah" or source == "auction") and entry.considerAuctionSupply ~= false then
                text = text .. " · " .. (entry.availableCount ~= nil and format(L["可购 %d"], entry.availableCount) or L["请扫描拍卖行"])
            elseif purchase.unlimited then
                text = text .. " · " .. L["不限量"]
            elseif purchase.limited then
                text = text .. " · " .. L["限量"]
            elseif purchase.stockUnknown then
                text = text .. " · " .. L["请向商人确认现货"]
            end
            parts[#parts + 1] = text
        end
        if (entry.packSurplus or 0) > 0 then parts[#parts + 1] = format(L["整包余量 %d"], entry.packSurplus) end
        if (entry.purchaseUncovered or 0) > 0 then parts[#parts + 1] = format(L["原计划货源还缺 %d 件，请重新计算。"], entry.purchaseUncovered) end
        if (entry.auctionShortage or 0) > 0 then parts[#parts + 1] = L["库存不足"] end
        return #parts > 0 and format(L["待购：%s"], table.concat(parts, " / ")) or L["已备齐"]
    end
    local source = E.PurchaseSource(entry)
    local text
    if source == "mixed" then
        text = L["商人"] .. " / " .. L["拍卖行"]
    elseif source == "vendor" or source == "npc" then
        text = E.VendorName(entry.npcID) or L["商人"]
        if entry.unlimited then text = text .. " · " .. L["不限量"]
        elseif entry.limited then text = text .. " · " .. L["限量"]
        elseif entry.stockUnknown then text = text .. " · " .. L["请向商人确认现货"] end
    elseif source == "ah" or source == "auction" then
        text = L["拍卖行"]
        if entry.considerAuctionSupply ~= false then
            text = text .. " · " .. (entry.availableCount and tostring(entry.availableCount) or L["请扫描拍卖行"])
        end
    end
    if text and entry.formula and entry.formulaCost and ra and ra.MoneyStr then
        text = text .. " · " .. ra.MoneyStr(entry.formulaCost, "copper")
    end
    return text
end

function E.ShoppingSourceDetail(entry)
    local ra = getRA()
    local pending = E.BidPending(entry.id, entry.have or 0) or 0
    if not entry.planPurchases then
        local text = E.ShoppingSourceText(entry)
        if pending <= 0 then return text end
        local notice = format(L["已竞标 %d 件，邮件待收"], pending)
        if type(text) ~= "string" or text == "" then return notice end
        return format("%s · %s", text, notice)
    end
    local cost = type(entry.planPurchaseCost) == "number" and ra and ra.MoneyStr and ra.MoneyStr(entry.planPurchaseCost, "copper")
        or L["请核对价格"]
    local parts = {
        E.ShoppingSourceText(entry) or "",
        format(L["原料需 %d；原计划购入 %d，费用 %s"], entry.need or 0, entry.planPurchaseCount or 0, cost),
    }
    if entry.haveKnown and (entry.have or 0) > 0 then
        parts[#parts + 1] = L["已有材料已抵扣；按原计划货源和报价计算待购费用。"]
    end
    if entry.purchaseChanged and entry.supplyChanged then
        parts[#parts + 1] = L["拍卖行可购数量已变化；待购数量按原计划货源和报价重新分配。"]
    end
    for _, purchase in ipairs(entry.planPurchases) do
        local item = copyPurchase(purchase)
        item.need = item.count
        item.have = 0
        parts[#parts + 1] = format("%s ×%d · %s",
            E.ShoppingSourceText(item) or L["尚无购买来源"],
            item.count,
            type(item.cost) == "number" and ra and ra.MoneyStr and ra.MoneyStr(item.cost, "copper") or L["请核对价格"])
    end
    if entry.auctionUnknown then
        parts[#parts + 1] = L["请打开拍卖行完成一次完整扫描，再重新计算路线。"]
    end
    if (entry.auctionShortage or 0) > 0 then
        parts[#parts + 1] = L["本次扫描的材料数量不够；请打开拍卖行完成一次完整扫描后重新计算，或更换货源。"]
    end
    if entry.purchaseUncovered and entry.purchaseUncovered > 0 then
        parts[#parts + 1] = format(L["原计划货源还缺 %d 件，请重新计算。"], entry.purchaseUncovered)
    end
    if pending > 0 then
        parts[#parts + 1] = format(L["已竞标 %d 件，邮件待收"], pending)
    end
    if entry.inventoryUnknown then
        parts[#parts + 1] = L["请检查背包"]
    end
    return table.concat(parts, "\n")
end

function E.VendorPurchases(slug, plan)
    if slug == "poisons" then return {} end
    local xp = getXP()
    local ra = getRA()
    plan = plan or (xp and xp.GetPlan and xp.GetPlan(slug)) or (ra and ra.Peek and ra.Peek(slug))
    if not plan or plan.feasible == false then return {} end
    local state = E.State()
    if not state or state.slug ~= slug then
        local skill = E.SkillOf(slug) or 0
        state = { slug = slug, skill = skill, step = 1 }
    end
    local list = E.ShopList(state, false, false, plan)
    local out, byKey = {}, {}
    for _, entry in ipairs(list) do
        for _, purchase in ipairs(entry.purchases or {}) do
            local source = E.PurchaseSource(purchase)
            if not purchase.formula and (source == "vendor" or source == "npc") and purchase.count > 0 then
                local key = tostring(entry.id) .. ":" .. tostring(purchase.npcID or 0)
                local row = byKey[key]
                if not row then
                    row = { id = entry.id, need = 0, missing = 0, cost = 0, npcID = purchase.npcID, have = entry.have }
                    byKey[key] = row
                    out[#out + 1] = row
                end
                row.need = row.need + purchase.count
                row.missing = row.need
                row.cost = type(purchase.cost) == "number" and row.cost and row.cost + purchase.cost or nil
            end
        end
    end
    return out
end

function E.SupplementNeeds(slug)
    slug = slug or (E.State() and E.State().slug)
    if not slug then return nil end
    local s = E.State()
    if not (s and s.slug == slug and s.step) then
        local cur = E.SkillOf(slug) or 0
        s = { slug = slug, skill = cur, step = E.DerivedStep(slug, cur) or 1 }
    end
    local list = E.ShopList(s, true, true)
    local items, kinds, qty = {}, 0, 0
    for _, e in ipairs(list) do
        local lack = (e.need or 0) - (e.have or 0)
        if e.haveKnown and lack > 0 then
            items[#items + 1] = { id = e.id, need = e.need, have = e.have, lack = lack }
            kinds = kinds + 1
            qty = qty + lack
        end
    end
    if kinds == 0 then return nil end
    return { items = items, kinds = kinds, qty = qty, step = s.step, basis = "bags" }
end

function E.SuspendAutoTrack(slug, reason)
    if reason == "recalculate" then E.endedPlan[slug] = nil end
    local s = E.State()
    if s and s.slug == slug then
        s.autoTrackSuspended = reason or true
        E.InvalidateRoute()
    end
end

function E.Sync()
    if E.TrackingPaused() then
        E.combatPaused = true
        return false
    end
    local s = E.State()
    if not (s and s.slug) then return false end
    if s.autoTrackSuspended == "inactive" then
        local xp = getXP()
        if not (xp and xp.GetActive and xp.GetActive(s.slug)) then return false end
        s.autoTrackSuspended = nil
    end
    local changed = E.combatPaused or false
    E.combatPaused = nil
    local cur, maxSkill = E.SkillOf(s.slug)

    local skillChanged = cur ~= nil and cur ~= s.skill
    local capChanged = maxSkill ~= nil and maxSkill ~= s.maxSkill

    if skillChanged or capChanged then
        if cur ~= nil then s.skill = cur end
        if maxSkill ~= nil then s.maxSkill = maxSkill end
        changed = true
        local pd = getPD()
        if pd and pd.built and pd.cur == s.slug
            and pd.page and pd.page.IsVisible and pd.page:IsVisible() then
            pcall(pd.Render, pd)
        end
    end
    local mode, steps = E.RouteFor(s.slug, s.skill or 0)
    local key = E.RouteKey(mode, steps)
    local resetView = false
    if key ~= s.rkey then
        s.rkey = key
        s.step = E.DerivedStep(s.slug, s.skill or 0) or 1
        resetView = true
        changed = true
    end
    local d = E.DerivedStep(s.slug, s.skill or 0)
    if d and d > (s.step or 1) then
        s.step = d
        changed = true
    end
    return changed, resetView
end

-- =========================================================================
-- Auction Bid Pending Tracking
-- =========================================================================

local BID_TTL = 7 * 24 * 3600
local BID_SEEN = 30
local BID_PATTERNS = {
    "你赢得了对(.-)的竞标", "你贏得了對(.-)的競標",
    "你赢得了对(.-)的拍卖", "你贏得了對(.-)的拍賣",
    "^You won the bid on (.-)%.?$", "^You won an auction for (.-)%.?$",
}
local bidNameCache, bidNameKey

function E.ResetBidCache()
    bidNameCache, bidNameKey = nil, nil
end

local function bidStore()
    local p = E.DbProf()
    local all = p.bidPending
    if type(all) ~= "table" then
        all = {}
        p.bidPending = all
    end
    local k = E.CharKey()
    local s = all[k]
    if type(s) ~= "table" then
        s = {}
        all[k] = s
    end
    return s
end

function E.BidPending(id, have)
    if type(id) ~= "number" then return 0 end
    local s = bidStore()
    local rec = s[id]
    if type(rec) ~= "table" then return 0 end
    local now = _G.time and _G.time() or 0
    if (rec.at or 0) > 0 and now > 0 and now - rec.at > BID_TTL then
        s[id] = nil
        return 0
    end
    local got = max(0, (tonumber(have) or 0) - (rec.base or 0))
    local left = max(0, (rec.n or 0) - got)
    if left <= 0 then
        s[id] = nil
        return 0
    end
    return left
end

local function bidNameMap(force)
    local s = E.State()
    local slug = s and s.slug
    if not slug then return nil end
    if not force and bidNameCache and bidNameKey == slug then return bidNameCache end
    local map = {}
    local function add(id)
        if type(id) ~= "number" then return end
        local nm = itemNameOf(id)
        if type(nm) == "string" and nm ~= "" then map[nm] = id end
    end
    local ds = getDS()
    local bucket = ds and ds.EnsureRecipes and ds.EnsureRecipes(slug) or nil
    if type(bucket) == "table" and type(bucket.recipes) == "table" then
        for spellID, recipe in pairs(bucket.recipes) do
            if type(recipe) == "table" then
                add(recipe.outputItemID)
                local lr = ds.LearningRoutes and ds.LearningRoutes(spellID) or nil
                if type(lr) == "table" and type(lr.routes) == "table" then
                    for _, route in ipairs(lr.routes) do
                        if type(route) == "table" and type(route.teachingItemID) == "number" then
                            add(route.teachingItemID)
                        end
                    end
                end
                for _, m in ipairs(recipe.reagents or {}) do
                    if type(m) == "table" then add(m.itemID or m[1]) end
                end
            end
        end
    end
    local ok, list = pcall(E.ShoppingList, slug, false)
    if ok and type(list) == "table" then
        for _, entry in ipairs(list) do add(entry.id) end
    end
    bidNameCache, bidNameKey = map, slug
    return map
end

function E.NoteBid(text, replay, notifyFn)
    if type(text) ~= "string" then return false end
    if not (text:find("竞标", 1, true) or text:find("競標", 1, true)
        or text:find("拍卖", 1, true) or text:find("拍賣", 1, true)
        or text:find("bid", 1, true) or text:find("auction", 1, true)) then
        return false
    end
    local body, n = text, 1
    local cnt = body:match("（(%d+)）%s*$") or body:match("%((%d+)%)%s*$")
    if cnt then
        n = tonumber(cnt) or 1
        body = body:gsub("（%d+）%s*$", ""):gsub("%(%d+%)%s*$", "")
    end
    local name
    for _, p in ipairs(BID_PATTERNS) do
        name = body:match(p)
        if name and name ~= "" then break end
    end
    if not name or name == "" then return false end
    local map = bidNameMap()
    if not map then return false end
    local id = map[name]
    if not id then
        map = bidNameMap(true)
        id = map and map[name]
    end
    if not id then
        local best, bestLen = nil, 0
        for nm, v in pairs(map or {}) do
            if #nm > bestLen and body:find(nm, 1, true) then best, bestLen = v, #nm end
        end
        id = best
    end
    if not id then return false end
    local now = _G.time and _G.time() or 0
    local have = E.Have(id)
    local s = bidStore()
    local rec = s[id]
    if type(rec) == "table" then
        if replay or (rec.body == body and now - (rec.at or 0) <= BID_SEEN) then
            rec.n = max(rec.n or 0, n)
        else
            rec.n = (rec.n or 0) + n
        end
        rec.body, rec.at = body, now
    else
        s[id] = { n = n, base = have, at = now, body = body }
    end
    if not replay and type(notifyFn) == "function" then
        notifyFn(format(L["已记录竞拍：%s ×%d（邮件待收）"], name, n))
    end
    return true
end

function E.ReplayBids(count, notifyFn)
    local now = _G.time and _G.time() or 0
    if now > 0 and (E.bidReplayAt or 0) > 0 and now - E.bidReplayAt < 5 then return 0 end
    E.bidReplayAt = now
    local cf = _G.SELECTED_CHAT_FRAME or _G.ChatFrame1
    if not (cf and cf.GetNumMessages and cf.GetMessageInfo) then return 0 end
    local ok, total = pcall(cf.GetNumMessages, cf)
    if not ok or type(total) ~= "number" or total <= 0 then return 0 end
    local from = max(1, total - (tonumber(count) or 5) + 1)
    local hits = 0
    for i = total, from, -1 do
        local ok2, txt = pcall(cf.GetMessageInfo, cf, i)
        if ok2 and type(txt) == "string" and E.NoteBid(txt, true, notifyFn) then hits = hits + 1 end
    end
    return hits
end

function E.ScanChatBids(notifyFn)
    local cf = _G.SELECTED_CHAT_FRAME or _G.ChatFrame1
    if not (cf and cf.GetNumMessages and cf.GetMessageInfo) then return 0 end
    local ok, total = pcall(cf.GetNumMessages, cf)
    if not ok or type(total) ~= "number" then return 0 end
    local from = E.bidScanCount
    if not from or total < from then
        E.bidScanCount = total
        return 0
    end
    if total == from then return 0 end
    local hits = 0
    for i = from + 1, total do
        local ok2, txt = pcall(cf.GetMessageInfo, cf, i)
        if ok2 and type(txt) == "string" and E.NoteBid(txt, false, notifyFn) then hits = hits + 1 end
    end
    E.bidScanCount = total
    return hits
end
