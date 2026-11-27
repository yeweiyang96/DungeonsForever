local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end
local gns = _G.DF_NS

local S = {}
ns.ProfRouteSolver = S
if type(gns) == "table" and gns ~= ns then
    gns.ProfRouteSolver = S
end
S.ProcurementPolicyVersion = 13
S.FailureDiagnosticVersion = 1

local floor, ceil, min, max, huge = math.floor, math.ceil, math.min, math.max, math.huge

local function getEconomy()
    return ns.ProfEconomy or (type(gns) == "table" and gns.ProfEconomy) or nil
end

local function getRecovery()
    return ns.ProfRecovery or (type(gns) == "table" and gns.ProfRecovery) or nil
end

local function getEssences()
    return ns.ProfEssences or (type(gns) == "table" and gns.ProfEssences) or nil
end

local function getAuctionDepth()
    return ns.ProfAuctionDepth or (type(gns) == "table" and gns.ProfAuctionDepth) or nil
end

local function getRouteAuto()
    return ns.ProfRouteAuto or (type(gns) == "table" and gns.ProfRouteAuto) or nil
end

local function getSolverCfg()
    return ns.SolverConfig or (type(gns) == "table" and gns.SolverConfig) or nil
end

local function getDS()
    return ns.ProfDataStore or (type(gns) == "table" and gns.ProfDataStore) or nil
end

local function solverCap()
    local cfg = getSolverCfg()
    return (type(cfg) == "table" and type(cfg.CAP) == "number" and cfg.CAP) or 300
end

local function solverDefaultTarget()
    local cfg = getSolverCfg()
    return (type(cfg) == "table" and type(cfg.DEFAULT_TARGET) == "number" and cfg.DEFAULT_TARGET) or 300
end

local function solverBudget(key, fallback)
    local cfg = getSolverCfg()
    local b = type(cfg) == "table" and type(cfg.COROUTINE_BUDGET) == "table" and cfg.COROUTINE_BUDGET or nil
    local v = b and b[key]
    return (type(v) == "number" and v > 0) and v or fallback
end

local function solverReg(key, fallback)
    local cfg = getSolverCfg()
    local r = type(cfg) == "table" and type(cfg.REGULARIZATION) == "table" and cfg.REGULARIZATION or nil
    local v = r and r[key]
    if v ~= nil then return v end
    return fallback
end

local function Now()
    if type(_G.time) == "function" then
        local ok, v = pcall(_G.time)
        if ok and type(v) == "number" then return v end
    end
    if type(os) == "table" and type(os.time) == "function" then
        local ok, v = pcall(os.time)
        if ok and type(os.time) == "function" and type(v) == "number" then return v end
    end
    return 0
end

local function clock()
    if type(_G.debugprofilestop) == "function" then
        local ok, v = pcall(_G.debugprofilestop)
        if ok and type(v) == "number" then return v end
    end
    if type(os) == "table" and type(os.clock) == "function" then
        return os.clock() * 1000
    end
    return 0
end

local function nextCapTier(cap, limit)
    if cap <= 75 then return min(limit, 150) end
    if cap <= 150 then return min(limit, 225) end
    return limit
end

local stockFields = { "unlimited", "limited", "stock", "maxStock", "stockUnknown", "stockStatus" }
local function stampStock(entry, offer)
    if type(offer) == "table" then
        for _, key in ipairs(stockFields) do
            if entry[key] == nil then entry[key] = offer[key] end
        end
    end
    return entry
end

-- ============================================================================
-- Embedded v3 Clean-Room Route Optimizer Core (Lagrangian + DAG DP + Markov)
-- ============================================================================
local OptimizerCore = (function()
    -- 净室专业升级路线全局最优求解器（纯原生 Lua 5.1 零依赖实现，与 Python 引擎严格同构）
    -- 兼容 WoW 1.60 / Lua 5.1 沙盒与命令行 lua5.1 直接加载。

    local M = {}

    local math_abs = math.abs
    local math_ceil = math.ceil
    local math_floor = math.floor
    local math_huge = math.huge
    local math_log = math.log
    local math_max = math.max
    local math_min = math.min
    local math_sqrt = math.sqrt
    local table_insert = table.insert
    local table_remove = table.remove
    local table_sort = table.sort

    local INF = 1e30
    local EPS = 1e-7

    local DEFAULT_TOWN_STATIONS = {
      anvil = true,
      forge = true,
      cooking_fire = true,
      spinning_wheel = true,
      tanning_rack = true,
      fermenter = true,
      moonwell = true,
    }

    local REQUIRED_TOOL_MAP = {
      runed_copper_rod = { "runed_rod", 1 },
      runed_silver_rod = { "runed_rod", 2 },
      runed_golden_rod = { "runed_rod", 3 },
      runed_truesilver_rod = { "runed_rod", 4 },
      runed_arcanite_rod = { "runed_rod", 5 },
      blacksmith_hammer = { "blacksmith_hammer", 1 },
      arclight_spanner = { "arclight_spanner", 1 },
      gyromatic_micro_adjustor = { "gyromatic_micro_adjustor", 1 },
      philosophers_stone = { "philosophers_stone", 1 },
    }

    local function is_inf(x)
      return x == math_huge or x >= INF * 0.5
    end

    function M.normal_quantile(p)
      if p <= 0.0 then return -8.0 end
      if p >= 1.0 then return 8.0 end
      if math_abs(p - 0.5) < 1e-15 then return 0.0 end

      local a1, a2, a3, a4, a5, a6 =
        -3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
        1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00
      local b1, b2, b3, b4, b5 =
        -5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
        6.680131188771972e+01, -1.328068155288572e+01
      local c1, c2, c3, c4, c5, c6 =
        -7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
        -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00
      local d1, d2, d3, d4 =
        7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
        3.754408661907416e+00

      local p_low = 0.02425
      local p_high = 1.0 - p_low
      if p < p_low then
        local q = math_sqrt(-2.0 * math_log(p))
        return (((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6)
          / ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0)
      elseif p <= p_high then
        local q = p - 0.5
        local r = q * q
        return (((((a1 * r + a2) * r + a3) * r + a4) * r + a5) * r + a6) * q
          / (((((b1 * r + b2) * r + b3) * r + b4) * r + b5) * r + 1.0)
      else
        local q = math_sqrt(-2.0 * math_log(1.0 - p))
        return -(((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6)
          / ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0)
      end
    end

    function M.skill_up_prob(recipe, skill)
      if not recipe.grey or skill < recipe.min_skill or skill >= recipe.grey then
        return 0.0
      end
      local yellow = recipe.yellow
      if not yellow or skill <= yellow then
        return 1.0
      end
      if recipe.grey <= yellow then
        return 0.0
      end
      return (recipe.grey - skill) / (recipe.grey - yellow)
    end

    function M.compute_step_quantiles_from(probs, confidence)
      local k_len = #probs
      if k_len == 0 then return {} end
      local m_ones = 0
      while m_ones < k_len and probs[m_ones + 1] >= 1.0 - 1e-12 do
        m_ones = m_ones + 1
      end
      if m_ones == k_len then
        local res = {}
        for i = 1, k_len do res[i] = i end
        return res
      end
      if m_ones > 0 then
        local tail_p = {}
        for i = m_ones + 1, k_len do tail_p[#tail_p + 1] = probs[i] end
        local tail_q = M.compute_step_quantiles_from(tail_p, confidence)
        local res = {}
        for i = 1, m_ones do res[i] = i end
        for i = 1, #tail_q do res[m_ones + i] = m_ones + tail_q[i] end
        return res
      end

      local res = {}
      local dist = {}
      for i = 1, k_len do
        res[i] = 0
        dist[i] = 0.0
      end
      dist[0] = 1.0
      local mean_total, var_total = 0.0, 0.0
      for i = 1, k_len do
        local p = probs[i]
        mean_total = mean_total + 1.0 / p
        var_total = var_total + (1.0 - p) / (p * p)
      end
      local max_steps = math_ceil(mean_total + 12.0 * math_sqrt(math_max(1.0, var_total)) + 35.0)
      local target = confidence - 1e-12
      local solved = 0
      local lo_active = 0

      for step = 1, max_steps do
        local hi_active = math_min(k_len - 1, step - 1)
        for j = hi_active, lo_active, -1 do
          local pj = dist[j]
          if pj > 1e-16 then
            local move = pj * probs[j + 1]
            dist[j + 1] = dist[j + 1] + move
            dist[j] = pj - move
          elseif j == lo_active then
            lo_active = lo_active + 1
          end
        end
        local prefix_below = 0.0
        for idx = lo_active + 1, k_len do
          prefix_below = prefix_below + dist[idx - 1]
          if res[idx] == 0 and (1.0 - prefix_below) >= target then
            res[idx] = step
            solved = solved + 1
          end
        end
        if solved == k_len then break end
      end

      for idx = 1, k_len do
        if res[idx] == 0 then res[idx] = max_steps end
      end
      return res
    end

    -- 二叉最小堆（用于最佳优先 Branch-and-Bound）
    local function heap_new()
      return { n = 0, data = {} }
    end

    local function heap_less(a, b)
      if math_abs(a.lb - b.lb) > 1e-12 then
        return a.lb < b.lb
      end
      return a.tie < b.tie
    end

    local function heap_push(h, item)
      local n = h.n + 1
      h.n = n
      local d = h.data
      d[n] = item
      local idx = n
      while idx > 1 do
        local parent = math_floor(idx / 2)
        if heap_less(d[idx], d[parent]) then
          d[idx], d[parent] = d[parent], d[idx]
          idx = parent
        else
          break
        end
      end
    end

    local function heap_pop(h)
      if h.n == 0 then return nil end
      local d = h.data
      local top = d[1]
      local n = h.n
      d[1] = d[n]
      d[n] = nil
      n = n - 1
      h.n = n
      local idx = 1
      while true do
        local l = idx * 2
        local r = l + 1
        local smallest = idx
        if l <= n and heap_less(d[l], d[smallest]) then smallest = l end
        if r <= n and heap_less(d[r], d[smallest]) then smallest = r end
        if smallest ~= idx then
          d[idx], d[smallest] = d[smallest], d[idx]
          idx = smallest
        else
          break
        end
      end
      return top
    end

    local function sorted_keys(tbl)
      local ks = {}
      for k, _ in pairs(tbl) do
        ks[#ks + 1] = k
      end
      table_sort(ks)
      return ks
    end

    local function merge_supply_tiers(tiers)
      if not tiers or #tiers == 0 then return {} end
      local ordered = {}
      for i = 1, #tiers do
        local t = tiers[i]
        if t.max_qty > EPS and t.unit_price >= 0.0 then
          ordered[#ordered + 1] = {
            unit_price = t.unit_price,
            max_qty = t.max_qty,
            bundle_size = t.bundle_size or 1,
            source = t.source or "market",
            real_item_id = t.real_item_id,
            _idx = i,
          }
        end
      end
      table_sort(ordered, function(a, b)
        if math_abs(a.unit_price - b.unit_price) > 1e-12 then
          return a.unit_price < b.unit_price
        end
        local oa = (a.source == "owned") and 0 or 1
        local ob = (b.source == "owned") and 0 or 1
        if oa ~= ob then return oa < ob end
        return a._idx < b._idx
      end)

      local merged = {}
      for i = 1, #ordered do
        local t = ordered[i]
        local mlen = #merged
        local prev = merged[mlen]
        if prev
          and math_abs(prev.unit_price - t.unit_price) <= 1e-9
          and prev.bundle_size == t.bundle_size
          and prev.source == t.source
          and prev.real_item_id == t.real_item_id
        then
          if is_inf(prev.max_qty) or is_inf(t.max_qty) then
            prev.max_qty = math_huge
          else
            prev.max_qty = prev.max_qty + t.max_qty
          end
        else
          mlen = mlen + 1
          merged[mlen] = {
            unit_price = t.unit_price,
            max_qty = t.max_qty,
            bundle_size = t.bundle_size,
            source = t.source,
            real_item_id = t.real_item_id,
          }
        end
        if is_inf(merged[mlen].max_qty) and merged[mlen].bundle_size == 1 then
          break
        end
      end
      return merged
    end

    local function eval_tier_cost(tiers, qty)
      if qty <= EPS then return 0.0, true end
      local rem = qty
      local cost = 0.0
      for i = 1, #tiers do
        local t = tiers[i]
        local take = is_inf(t.max_qty) and rem or math_min(rem, t.max_qty)
        if take > 0.0 then
          cost = cost + take * t.unit_price
          rem = rem - take
          if rem <= EPS then return cost, true end
        end
      end
      return cost, false
    end

    local function raw_buy_tiers_from_market(market, item_id)
      local raw
      if type(market.buy_fn) == "function" then
        raw = market.buy_fn(item_id)
      elseif type(market.buy) == "table" then
        raw = market.buy[item_id] or market.buy[tostring(item_id)]
      end
      if raw == nil then return {} end
      if type(raw) == "number" then
        if raw < 0 or is_inf(raw) then return {} end
        return { { unit_price = raw, max_qty = math_huge, bundle_size = 1, source = "market", real_item_id = item_id } }
      end
      local out = {}
      for i = 1, #raw do
        local t = raw[i]
        local p = t.unit_price or t.unitPrice
        local q = t.max_qty or t.maxQty or math_huge
        if p and p >= 0 and q > 0 then
          out[#out + 1] = {
            unit_price = p,
            max_qty = q,
            bundle_size = t.bundle_size or t.bundleSize or 1,
            source = t.source or "market",
            real_item_id = t.real_item_id or t.realItemID or item_id,
          }
        end
      end
      table_sort(out, function(a, b) return a.unit_price < b.unit_price end)
      return out
    end

    local function sell_value_from_market(market, item_id)
      local v
      if type(market.sell_fn) == "function" then
        v = market.sell_fn(item_id)
      elseif type(market.sell) == "table" then
        v = market.sell[item_id] or market.sell[tostring(item_id)]
      end
      if not v or v <= 0 then return 0.0 end
      return v
    end

    local function normalize_options(opts)
      opts = opts or {}
      local conf = opts.confidence or 0.90
      return {
        objective = opts.objective or "min_cost",
        risk_mode = opts.risk_mode or "expected",
        confidence = conf,
        prep_confidence = (opts.prep_confidence ~= nil) and opts.prep_confidence or conf,
        switch_penalty_copper = (opts.switch_penalty_copper ~= nil) and opts.switch_penalty_copper or 300.0,
        switch_cost_ratio = (opts.switch_cost_ratio ~= nil) and opts.switch_cost_ratio or 0.35,
        min_segment_points = (opts.min_segment_points ~= nil) and opts.min_segment_points or 5,
        forbid_recipe_repeat = (opts.forbid_recipe_repeat == nil) and true or (opts.forbid_recipe_repeat and true or false),
        high_cost_fail_aversion = (opts.high_cost_fail_aversion ~= nil) and opts.high_cost_fail_aversion or 0.55,
        high_cost_green_threshold_copper = (opts.high_cost_green_threshold_copper ~= nil) and opts.high_cost_green_threshold_copper or 10000.0,
        enable_field_mining_fallback = (opts.enable_field_mining_fallback == nil) and true or (opts.enable_field_mining_fallback and true or false),
        allow_cooldown_recipes = opts.allow_cooldown_recipes and true or false,
        allow_limited_vendor = opts.allow_limited_vendor and true or false,
        allow_quest_rep_recipes = opts.allow_quest_rep_recipes and true or false,
        allow_master_stations = opts.allow_master_stations and true or false,
        max_subgradient_iters = opts.max_subgradient_iters or 28,
        max_bnb_nodes = opts.max_bnb_nodes or 400,
        tick = (type(opts.tick) == "function") and opts.tick or nil,
      }
    end

    local function normalize_player(p)
      p = p or {}
      return {
        faction = p.faction or "N",
        player_class_id = p.player_class_id,
        known_recipes = p.known_recipes or {},
        owned_items = p.owned_items or {},
        owned_tools = p.owned_tools or {},
        owned_tool_categories = p.owned_tool_categories or {},
        specialization_ability_ids = p.specialization_ability_ids or {},
        unlocked_stations = p.unlocked_stations or {},
        use_owned_inventory = (p.use_owned_inventory == nil) and true or (p.use_owned_inventory and true or false),
      }
    end

    function M.build_problem_from_forever_data(data_bundle, profession, market, player, options, locale)
      local p_ctx = normalize_player(player)
      local opts = normalize_options(options)
      locale = locale or "zhCN"

      local prof_meta = (data_bundle.professions and data_bundle.professions[profession]) or {}
      local max_cap = prof_meta.maxSkillCap or 300
      local locales = data_bundle.locales or {}
      local loc_tbl = locales[locale] or locales.enUS or {}
      local en_tbl = locales.enUS or {}
      local spell_names = loc_tbl.spell or {}
      local en_spell_names = en_tbl.spell or {}

      local entities = data_bundle.entities or {}
      local npcs = entities.npcs or {}
      local zones = entities.zones or {}
      local systems = data_bundle.systems or {}
      local sources = data_bundle.sources or {}
      local guides = data_bundle.guides or {}

      local specs = systems.specializations or {}
      local tools_raw = systems.tools or {}
      local essences_raw = systems.essences or {}
      local learning_routes = sources.learningRoutes or {}
      local vendor_offers = sources.vendorOffers or {}

      local function conds_satisfied(conds)
        if not conds then return true end
        for i = 1, #conds do
          local c = conds[i]
          local ctype = c.type or c.kind
          if ctype == "class" then
            if p_ctx.player_class_id and c.classID and tonumber(c.classID) ~= p_ctx.player_class_id then
              return false
            end
          elseif ctype == "reputation" or ctype == "questGroup" or ctype == "hasItem" then
            if not opts.allow_quest_rep_recipes then return false end
          elseif ctype == "ability" then
            local aid = tonumber(c.abilitySpellID or c.spellID)
            if aid and not p_ctx.specialization_ability_ids[aid] then return false end
          end
        end
        return true
      end

      local function npc_accessible(npc_id)
        local npc = npcs[npc_id] or npcs[tostring(npc_id)]
        if not npc then return true end
        local nfac = npc.faction
        if (p_ctx.faction == "A" or p_ctx.faction == "H") and (nfac == "A" or nfac == "H") and nfac ~= p_ctx.faction then
          return false
        end
        if not conds_satisfied(npc.accessConditions) then return false end
        if not opts.allow_quest_rep_recipes then
          local area_ids = npc.areaIDs
          if area_ids and #area_ids > 0 then
            local all_inst = true
            for i = 1, #area_ids do
              local aid = area_ids[i]
              local z = zones[aid] or zones[tostring(aid)]
              local zt = z and z.zoneType or "world"
              if zt == nil or zt == "world" then
                all_inst = false
                break
              end
            end
            if all_inst then return false end
          end
        end
        return true
      end

      local vendor_supply = {}
      for raw_iid, vo in pairs(vendor_offers) do
        local iid = tonumber(raw_iid)
        local offers = vo.offers or vo
        if iid and offers and #offers > 0 then
          local item_tiers = {}
          for i = 1, #offers do
            local off = offers[i]
            local has_curr = off.currencies and #off.currencies > 0
            local has_ci = off.costItems and #off.costItems > 0
            local price = off.priceCopper
            local stock = off.maxStock
            if not has_curr and not has_ci and price and price >= 0 then
              if not (stock ~= nil and stock >= 0 and not opts.allow_limited_vendor) then
                if conds_satisfied(off.conditions) and (not off.npcID or npc_accessible(tonumber(off.npcID))) then
                  local bsize = math_max(1, tonumber(off.bundleSize) or 1)
                  local max_q = (stock == nil or stock < 0) and math_huge or (stock * bsize)
                  if max_q > 0 then
                    item_tiers[#item_tiers + 1] = {
                      unit_price = price / bsize,
                      max_qty = max_q,
                      bundle_size = bsize,
                      source = "vendor",
                      real_item_id = iid,
                    }
                  end
                end
              end
            end
          end
          if #item_tiers > 0 then
            vendor_supply[iid] = merge_supply_tiers(item_tiers)
          end
        end
      end

      local prof_tools = {}
      local craft_spell_to_tool = {}
      for raw_tid, t in pairs(tools_raw) do
        local tid = tonumber(raw_tid)
        local match_prof = (t.profession == profession)
        if not match_prof and (profession == "engineering" or profession == "blacksmithing")
          and t.toolCategory == "gnomish_army_knife" and next(p_ctx.specialization_ability_ids) ~= nil then
          match_prof = true
        end
        if tid and match_prof then
          local csid = t.craftSpellID and tonumber(t.craftSpellID) or nil
          local tcat = tostring(t.toolCategory)
          local ttier = tonumber(t.tier) or 1
          prof_tools[#prof_tools + 1] = {
            item_id = tid,
            tool_category = tcat,
            tier = ttier,
            min_skill = tonumber(t.minSkill) or 1,
            bind_on_pickup = t.bindOnPickup and true or false,
            craft_spell_id = csid,
          }
          if csid then
            craft_spell_to_tool[csid] = { tcat, ttier, tid }
          end
        end
      end

      local essence_pairs = {}
      if profession == "enchanting" then
        local seen_pk = {}
        for _, ep in pairs(essences_raw) do
          local pk = tostring(ep.pairKey or "")
          if not seen_pk[pk] then
            local inc = tonumber(ep.inputCount) or 1
            local outc = tonumber(ep.outputCount) or 1
            if inc == 3 and outc == 1 then
              seen_pk[pk] = true
              essence_pairs[#essence_pairs + 1] = {
                pair_key = pk,
                lesser_item_id = tonumber(ep.inputItemID),
                greater_item_id = tonumber(ep.outputItemID),
                ratio = 3,
              }
            elseif inc == 1 and outc == 3 then
              seen_pk[pk] = true
              essence_pairs[#essence_pairs + 1] = {
                pair_key = pk,
                lesser_item_id = tonumber(ep.outputItemID),
                greater_item_id = tonumber(ep.inputItemID),
                ratio = 3,
              }
            end
          end
        end
        table_sort(essence_pairs, function(a, b) return a.lesser_item_id < b.lesser_item_id end)
      end

      local raw_prof_rec = (data_bundle.recipes_by_prof and data_bundle.recipes_by_prof[profession]) or {}
      local raw_recipes = raw_prof_rec.recipes or {}
      local recipes = {}
      local excluded_missing = {}

      for raw_sid, r in pairs(raw_recipes) do
        local sid = tonumber(raw_sid)
        if sid and (r.availability == nil or r.availability == "live") then
          local is_known = p_ctx.known_recipes[sid] and true or false
          local cd_blocked = (not opts.allow_cooldown_recipes) and r.cooldownSeconds and tonumber(r.cooldownSeconds) > 0
          if not cd_blocked then
            local spec_ok = true
            local spec_min_skill = 0
            if r.requiredAbilityID then
              local aid = tonumber(r.requiredAbilityID)
              if not p_ctx.specialization_ability_ids[aid] then
                spec_ok = false
              else
                local sp = specs[aid] or specs[tostring(aid)]
                if sp and sp.minSkill then spec_min_skill = tonumber(sp.minSkill) end
              end
            end

            local st_key = r.stationKey
            local st_ok = true
            if st_key and not is_known and not opts.allow_master_stations
              and not DEFAULT_TOWN_STATIONS[st_key] and not p_ctx.unlocked_stations[st_key] then
              st_ok = false
            end

            if spec_ok and st_ok then
              local rname = spell_names[sid] or spell_names[tostring(sid)]
                or en_spell_names[sid] or en_spell_names[tostring(sid)]
                or ("Spell #" .. tostring(sid))

              local route_ok = true
              local unlock_cost = 0.0
              local teach_item = nil
              local learn_kind = "autoGrant"
              local route_min_skill = 0

              if not is_known then
                local lr_entry = learning_routes[sid] or learning_routes[tostring(sid)]
                local routes = lr_entry and lr_entry.routes or nil
                if not routes or #routes == 0 then
                  if (tonumber(r.learnedAt) or 0) ~= 1 then route_ok = false end
                else
                  local best_cost = nil
                  local missing_teach = {}
                  for i = 1, #routes do
                    local rt = routes[i]
                    local rkind = tostring(rt.kind or "")
                    local rmin = tonumber(rt.minSkillRank) or 0
                    if not (rkind == "quest" and not opts.allow_quest_rep_recipes) and conds_satisfied(rt.conditions) then
                      local c_cand, k_cand, ti_cand = nil, nil, nil
                      if rkind == "autoGrant" then
                        c_cand, k_cand = 0.0, "autoGrant"
                      elseif rkind == "trainer" then
                        local trs = rt.trainers
                        local tr_ok = true
                        if trs and #trs > 0 then
                          tr_ok = false
                          for j = 1, #trs do
                            local tr = trs[j]
                            if tr.npcID and npc_accessible(tonumber(tr.npcID)) and conds_satisfied(tr.conditions) then
                              tr_ok = true
                              break
                            end
                          end
                        end
                        if tr_ok then
                          c_cand = rt.trainingCostCopper and tonumber(rt.trainingCostCopper) or 0.0
                          k_cand = "trainer"
                        end
                      elseif rkind == "item" then
                        local tiid = rt.teachingItemID and tonumber(rt.teachingItemID)
                        if tiid then
                          if p_ctx.use_owned_inventory and (p_ctx.owned_items[tiid] or 0) > 0 then
                            c_cand = (opts.objective == "min_net") and sell_value_from_market(market, tiid) or 0.0
                            k_cand, ti_cand = "item", tiid
                          else
                            local comb_t = {}
                            local vs = vendor_supply[tiid] or {}
                            local ms = raw_buy_tiers_from_market(market, tiid)
                            for u = 1, #vs do comb_t[#comb_t + 1] = vs[u] end
                            for u = 1, #ms do comb_t[#comb_t + 1] = ms[u] end
                            local m_tiers = merge_supply_tiers(comb_t)
                            if #m_tiers > 0 then
                              c_cand, k_cand, ti_cand = m_tiers[1].unit_price, "item", tiid
                            else
                              missing_teach[#missing_teach + 1] = tiid
                            end
                          end
                        end
                      elseif rkind == "quest" then
                        c_cand, k_cand = 0.0, "quest"
                      end

                      if c_cand ~= nil and (best_cost == nil or c_cand < best_cost - EPS) then
                        best_cost = c_cand
                        unlock_cost = c_cand
                        learn_kind = k_cand
                        teach_item = ti_cand
                        route_min_skill = rmin
                      end
                    end
                  end
                  if best_cost == nil then
                    route_ok = false
                    if #missing_teach > 0 then
                      excluded_missing[#excluded_missing + 1] = { sid, rname, missing_teach }
                    end
                  end
                end
              end

              if route_ok then
                local req_tools_parsed = {}
                local tool_ok = true
                local rtools = r.requiredTools
                if rtools then
                  for i = 1, #rtools do
                    local m = REQUIRED_TOOL_MAP[tostring(rtools[i])]
                    if not m then
                      tool_ok = false
                      break
                    end
                    req_tools_parsed[#req_tools_parsed + 1] = m
                  end
                end

                if tool_ok then
                  local orange = r.orange and tonumber(r.orange) or nil
                  local yellow = r.yellow and tonumber(r.yellow) or nil
                  local green = r.green and tonumber(r.green) or nil
                  local grey = r.grey and tonumber(r.grey) or nil
                  local learned_at = r.learnedAt and tonumber(r.learnedAt) or 0
                  local min_skill = math_max(learned_at, orange or 0, route_min_skill, spec_min_skill, 1)

                  local reagents = {}
                  if r.reagents then
                    for i = 1, #r.reagents do
                      local rg = r.reagents[i]
                      reagents[#reagents + 1] = { tonumber(rg.itemID), tonumber(rg.count) }
                    end
                  end
                  local outputs = {}
                  if r.outputKind == "item" and r.outputItemID then
                    local cmin = tonumber(r.outputCountMin) or 1
                    local cmax = tonumber(r.outputCountMax) or cmin
                    outputs[1] = { tonumber(r.outputItemID), 0.5 * (cmin + cmax) }
                  end

                  recipes[sid] = {
                    spell_id = sid,
                    kind = "craft",
                    name = rname,
                    min_skill = min_skill,
                    orange = orange,
                    yellow = yellow,
                    green = green,
                    grey = grey,
                    reagents = reagents,
                    outputs = outputs,
                    unlock_cost_copper = unlock_cost,
                    teaching_item_id = teach_item,
                    learn_kind = learn_kind,
                    required_tools = req_tools_parsed,
                    produces_tool = craft_spell_to_tool[sid],
                  }
                end
              end
            end
          end
        end
      end

      local gather_bands = {}
      if profession == "mining" then
        local mg = guides.gatheringGuides and guides.gatheringGuides.mining
        local bands = mg and mg.bands or {}
        for i = 1, #bands do
          local b = bands[i]
          local iids, zids = {}, {}
          for j = 1, #(b.itemIDs or {}) do iids[#iids + 1] = tonumber(b.itemIDs[j]) end
          for j = 1, #(b.zones or {}) do
            if b.zones[j].areaID then zids[#zids + 1] = tonumber(b.zones[j].areaID) end
          end
          gather_bands[#gather_bands + 1] = {
            min_skill = tonumber(b.minSkill) or 1,
            max_skill = tonumber(b.maxSkill) or 300,
            item_ids = iids,
            zone_ids = zids,
          }
        end
      end

      return {
        profession = profession,
        max_skill_cap = max_cap,
        recipes = recipes,
        tools = prof_tools,
        essence_pairs = essence_pairs,
        gather_bands = gather_bands,
        vendor_supply = vendor_supply,
        excluded_missing_price = excluded_missing,
      }
    end

    function M.solve_profession_route(problem, market, player, options, start_skill, target_skill)
      local p_ctx = normalize_player(player)
      local opts = normalize_options(options)
      local tick = opts.tick
      local s0 = math_max(1, tonumber(start_skill) or 1)
      local starget = math_min(tonumber(problem.max_skill_cap) or 300, tonumber(target_skill) or problem.max_skill_cap or 300)
      local is_net = (opts.objective == "min_net")

      local supply_map = {}
      local market_only_map = {}
      local sell_map = {}
      local active_recipes = {}
      for sid, r in pairs(problem.recipes or {}) do
        active_recipes[sid] = r
      end

      -- 1. 构建物品供应曲线
      local all_items = {}
      for _, r in pairs(active_recipes) do
        for i = 1, #r.reagents do all_items[r.reagents[i][1]] = true end
        for i = 1, #r.outputs do all_items[r.outputs[i][1]] = true end
        if r.teaching_item_id then all_items[r.teaching_item_id] = true end
      end
      for i = 1, #(problem.tools or {}) do all_items[problem.tools[i].item_id] = true end
      for i = 1, #(problem.essence_pairs or {}) do
        all_items[problem.essence_pairs[i].lesser_item_id] = true
        all_items[problem.essence_pairs[i].greater_item_id] = true
      end

      for iid, _ in pairs(all_items) do
        if iid > 0 then
          local sv = sell_value_from_market(market, iid)
          sell_map[iid] = sv
          local comb_mkt = {}
          local vs = (problem.vendor_supply and problem.vendor_supply[iid]) or {}
          local ms = raw_buy_tiers_from_market(market, iid)
          for i = 1, #vs do comb_mkt[#comb_mkt + 1] = vs[i] end
          for i = 1, #ms do comb_mkt[#comb_mkt + 1] = ms[i] end
          local mkt_tiers = merge_supply_tiers(comb_mkt)
          market_only_map[iid] = mkt_tiers

          local tiers = {}
          if p_ctx.use_owned_inventory then
            local oq = p_ctx.owned_items[iid] or p_ctx.owned_items[tostring(iid)] or 0
            if oq > 0 then
              tiers[#tiers + 1] = {
                unit_price = is_net and sv or 0.0,
                max_qty = oq,
                bundle_size = 1,
                source = "owned",
                real_item_id = iid,
              }
            end
          end
          for i = 1, #mkt_tiers do tiers[#tiers + 1] = mkt_tiers[i] end
          supply_map[iid] = merge_supply_tiers(tiers)
        end
      end

      local essence_by_item = {}
      for i = 1, #(problem.essence_pairs or {}) do
        local ep = problem.essence_pairs[i]
        essence_by_item[ep.lesser_item_id] = { ep, true }
        essence_by_item[ep.greater_item_id] = { ep, false }
      end

      -- 3. 可达不动点与拓扑排序
      local avail_items = {}
      for iid, ts in pairs(supply_map) do
        if #ts > 0 then avail_items[iid] = true end
      end
      local usable_recipes = {}
      local changed = true
      while changed do
        changed = false
        for i = 1, #(problem.essence_pairs or {}) do
          local ep = problem.essence_pairs[i]
          if avail_items[ep.lesser_item_id] and not avail_items[ep.greater_item_id] then
            avail_items[ep.greater_item_id] = true
            changed = true
          end
          if avail_items[ep.greater_item_id] and not avail_items[ep.lesser_item_id] then
            avail_items[ep.lesser_item_id] = true
            changed = true
          end
        end
        for sid, r in pairs(active_recipes) do
          if not usable_recipes[sid] then
            local ok = true
            for i = 1, #r.reagents do
              if not avail_items[r.reagents[i][1]] then
                ok = false
                break
              end
            end
            if ok then
              usable_recipes[sid] = r
              for i = 1, #r.outputs do
                local oid = r.outputs[i][1]
                if not avail_items[oid] then
                  avail_items[oid] = true
                  changed = true
                end
              end
            end
          end
        end
      end

      local blocked_recipes = {}
      for sid, r in pairs(active_recipes) do
        if not usable_recipes[sid] and (r.grey or 0) > r.min_skill then
          blocked_recipes[#blocked_recipes + 1] = r
        end
      end

      local produced_items = {}
      local reagent_use_count = {}
      for _, r in pairs(usable_recipes) do
        for i = 1, #r.outputs do produced_items[r.outputs[i][1]] = true end
        for i = 1, #r.reagents do
          local iid = r.reagents[i][1]
          reagent_use_count[iid] = (reagent_use_count[iid] or 0) + 1
        end
      end
      for i = 1, #(problem.essence_pairs or {}) do
        local ep = problem.essence_pairs[i]
        produced_items[ep.lesser_item_id] = true
        produced_items[ep.greater_item_id] = true
      end

      local inter_items = {}
      for iid, _ in pairs(produced_items) do
        if (reagent_use_count[iid] or 0) > 0 then inter_items[iid] = true end
      end
      for i = 1, #(problem.essence_pairs or {}) do
        local ep = problem.essence_pairs[i]
        if (reagent_use_count[ep.lesser_item_id] or 0) > 0
          or (reagent_use_count[ep.greater_item_id] or 0) > 0
          or produced_items[ep.lesser_item_id]
          or produced_items[ep.greater_item_id] then
          inter_items[ep.lesser_item_id] = true
          inter_items[ep.greater_item_id] = true
        end
      end

      local producers_by_item = {}
      local usable_sids = sorted_keys(usable_recipes)
      for _, sid in ipairs(usable_sids) do
        local r = usable_recipes[sid]
        if r.kind == "craft" and not r.produces_tool then
          for i = 1, #r.outputs do
            local oid, out_cnt = r.outputs[i][1], r.outputs[i][2]
            local in_same = 0.0
            for j = 1, #r.reagents do
              if r.reagents[j][1] == oid then in_same = in_same + r.reagents[j][2] end
            end
            if out_cnt > in_same + EPS then
              producers_by_item[oid] = producers_by_item[oid] or {}
              table_insert(producers_by_item[oid], r)
            end
          end
        end
      end

      local visited = {}
      local item_topo = {}
      local function dfs_topo(iid)
        local st = visited[iid] or 0
        if st == 1 or st == 2 then return end
        visited[iid] = 1
        local prods = producers_by_item[iid]
        if prods then
          for i = 1, #prods do
            local regs = prods[i].reagents
            for j = 1, #regs do
              if regs[j][1] ~= iid then dfs_topo(regs[j][1]) end
            end
          end
        end
        visited[iid] = 2
        item_topo[#item_topo + 1] = iid
      end
      for _, iid in ipairs(sorted_keys(avail_items)) do
        dfs_topo(iid)
      end

      -- 精确计算逐技能点最大可能材料消耗上界并截断远超全程需求的高价有限供应层
      local max_item_demand = {}
      local per_s_max = {}
      for s = s0, starget - 1 do per_s_max[s] = {} end
      local log_omc = math_log(math_max(1e-6, 1.0 - opts.confidence))
      local is_step_q_init = (opts.risk_mode == "step_quantile")

      for _, sid in ipairs(usable_sids) do
        local r = usable_recipes[sid]
        if r.produces_tool then
          for j = 1, #r.reagents do
            local rg_id, rg_cnt = r.reagents[j][1], r.reagents[j][2]
            max_item_demand[rg_id] = (max_item_demand[rg_id] or 0.0) + rg_cnt
          end
        end
        if r.grey and r.grey > r.min_skill then
          local lo = math_max(s0, r.min_skill)
          local hi = math_min(starget, r.grey)
          for s = lo, hi - 1 do
            local p = M.skill_up_prob(r, s)
            if p > 0.0 then
              local c_bound
              if p >= 1.0 - 1e-12 then
                c_bound = 1.0
              elseif is_step_q_init then
                c_bound = 1.0 + math_floor(log_omc / math_log(1.0 - p))
              else
                c_bound = 1.0 / p
              end
              local slot_s = per_s_max[s]
              for j = 1, #r.reagents do
                local rg_id, rg_cnt = r.reagents[j][1], r.reagents[j][2]
                local vn = c_bound * rg_cnt
                if vn > (slot_s[rg_id] or 0.0) then slot_s[rg_id] = vn end
              end
            end
          end
        end
      end
      for s = s0, starget - 1 do
        for rg_id, vn in pairs(per_s_max[s]) do
          max_item_demand[rg_id] = (max_item_demand[rg_id] or 0.0) + vn
        end
      end
      for i = 1, #(problem.tools or {}) do
        local tid = problem.tools[i].item_id
        max_item_demand[tid] = (max_item_demand[tid] or 0.0) + 1.0
      end
      for _, sid in ipairs(usable_sids) do
        local ti = usable_recipes[sid].teaching_item_id
        if ti then max_item_demand[ti] = (max_item_demand[ti] or 0.0) + 1.0 end
      end

      for idx = #item_topo, 1, -1 do
        local iid = item_topo[idx]
        local dem = max_item_demand[iid] or 0.0
        if dem > EPS then
          local prods = producers_by_item[iid] or {}
          for i = 1, #prods do
            local rec = prods[i]
            local out_net = 0.0
            for j = 1, #rec.outputs do
              if rec.outputs[j][1] == iid then out_net = out_net + rec.outputs[j][2] end
            end
            for j = 1, #rec.reagents do
              if rec.reagents[j][1] == iid then out_net = out_net - rec.reagents[j][2] end
            end
            if out_net > EPS then
              local b_max = math_ceil(dem / out_net)
              for j = 1, #rec.reagents do
                local rg_id, rg_cnt = rec.reagents[j][1], rec.reagents[j][2]
                if rg_id ~= iid then
                  max_item_demand[rg_id] = (max_item_demand[rg_id] or 0.0) + b_max * rg_cnt
                end
              end
            end
          end
        end
      end

      local essence_cap_units = {}
      for i = 1, #(problem.essence_pairs or {}) do
        local ep = problem.essence_pairs[i]
        local u_tot = (max_item_demand[ep.lesser_item_id] or 0.0) + ep.ratio * (max_item_demand[ep.greater_item_id] or 0.0)
        essence_cap_units[ep.lesser_item_id] = u_tot + 6.0
        essence_cap_units[ep.greater_item_id] = (u_tot / ep.ratio) + 3.0
      end

      for iid, ts in pairs(supply_map) do
        if #ts > 0 then
          local cap_lim = essence_cap_units[iid] or ((max_item_demand[iid] or 0.0) + 4.0)
          local trunc = {}
          local acc_q = 0.0
          for i = 1, #ts do
            local t = ts[i]
            if is_inf(t.max_qty) or (t.source ~= "owned" and acc_q + t.max_qty >= cap_lim - EPS) then
              trunc[#trunc + 1] = {
                unit_price = t.unit_price,
                max_qty = math_huge,
                bundle_size = t.bundle_size,
                source = t.source,
                real_item_id = t.real_item_id,
              }
              break
            end
            trunc[#trunc + 1] = t
            acc_q = acc_q + t.max_qty
          end
          supply_map[iid] = trunc
        end
      end

      local coupled_items = {}
      for iid, _ in pairs(inter_items) do coupled_items[iid] = true end
      for iid, cnt in pairs(reagent_use_count) do
        local ts = supply_map[iid]
        if ts and #ts > 0 and not is_inf(ts[1].max_qty) and cnt >= 1 then
          coupled_items[iid] = true
        end
      end

      -- 精确传播全服有限挂单总库存上限 item_total_avail 与单配方最大物理制作次数 recipe_max_crafts
      local item_total_avail = {}
      for idx = 1, #item_topo do
        local iid = item_topo[idx]
        local ts = supply_map[iid] or {}
        local raw_tot = 0.0
        for i = 1, #ts do
          if is_inf(ts[i].max_qty) then raw_tot = math_huge; break end
          raw_tot = raw_tot + ts[i].max_qty
        end
        local prods = producers_by_item[iid] or {}
        for i = 1, #prods do
          if is_inf(raw_tot) then break end
          local rec = prods[i]
          local out_net = 0.0
          for j = 1, #rec.outputs do
            if rec.outputs[j][1] == iid then out_net = out_net + rec.outputs[j][2] end
          end
          for j = 1, #rec.reagents do
            if rec.reagents[j][1] == iid then out_net = out_net - rec.reagents[j][2] end
          end
          if out_net > EPS then
            local max_b = math_huge
            for j = 1, #rec.reagents do
              local rg_id, rg_cnt = rec.reagents[j][1], rec.reagents[j][2]
              if rg_id ~= iid and rg_cnt > EPS then
                max_b = math_min(max_b, (item_total_avail[rg_id] or 0.0) / rg_cnt)
              end
            end
            if is_inf(max_b) then
              raw_tot = math_huge
            elseif max_b >= 1.0 - EPS then
              raw_tot = raw_tot + math_floor(max_b + EPS) * out_net
            end
          end
        end
        item_total_avail[iid] = raw_tot
      end

      for i = 1, #(problem.essence_pairs or {}) do
        local ep = problem.essence_pairs[i]
        local al = item_total_avail[ep.lesser_item_id] or 0.0
        local ag = item_total_avail[ep.greater_item_id] or 0.0
        if is_inf(al) or is_inf(ag) then
          item_total_avail[ep.lesser_item_id] = math_huge
          item_total_avail[ep.greater_item_id] = math_huge
        else
          local u_pool = al + ep.ratio * ag
          item_total_avail[ep.lesser_item_id] = u_pool
          item_total_avail[ep.greater_item_id] = u_pool / ep.ratio
        end
      end

      local recipe_max_crafts = {}
      local filtered_sids = {}
      for _, sid in ipairs(usable_sids) do
        local rec = usable_recipes[sid]
        local mc = math_huge
        for j = 1, #rec.reagents do
          local rg_id, rg_cnt = rec.reagents[j][1], rec.reagents[j][2]
          if rg_cnt > EPS and not inter_items[rg_id] then
            local av = item_total_avail[rg_id] or 0.0
            if not is_inf(av) then
              mc = math_min(mc, av / rg_cnt)
            end
          end
        end
        if mc < 1.0 - EPS then
          usable_recipes[sid] = nil
          if (rec.grey or 0) > rec.min_skill then
            blocked_recipes[#blocked_recipes + 1] = rec
          end
        else
          if (not is_inf(mc)) and rec.grey and rec.grey > rec.min_skill then
            local lo_s = math_max(s0, rec.min_skill)
            local hi_s = math_min(starget, rec.grey)
            local span_crafts = 0.0
            for s_chk = lo_s, hi_s - 1 do
              local p_chk = M.skill_up_prob(rec, s_chk)
              if p_chk > 0.0 then
                if is_step_q_init and p_chk < 1.0 - 1e-12 then
                  span_crafts = span_crafts + 1.0 + math_floor(log_omc / math_log(1.0 - p_chk))
                else
                  span_crafts = span_crafts + 1.0 / p_chk
                end
              end
            end
            if mc >= span_crafts - EPS then mc = math_huge end
          else
            mc = math_huge
          end
          recipe_max_crafts[sid] = mc
          filtered_sids[#filtered_sids + 1] = sid
        end
      end
      usable_sids = filtered_sids

      local producer_max_batches = {}
      for iid, prods in pairs(producers_by_item) do
        local dem = math_max(1.0, max_item_demand[iid] or 1.0)
        for i = 1, #prods do
          local rec = prods[i]
          local out_net = 0.0
          for j = 1, #rec.outputs do
            if rec.outputs[j][1] == iid then out_net = out_net + rec.outputs[j][2] end
          end
          for j = 1, #rec.reagents do
            if rec.reagents[j][1] == iid then out_net = out_net - rec.reagents[j][2] end
          end
          if out_net > EPS then
            producer_max_batches[tostring(rec.spell_id) .. ":" .. tostring(iid)] = math_max(1.0, math_ceil(dem / out_net))
          end
        end
      end

      local base_acq_price = {}
      local mkt_ref_price = {}
      for idx = 1, #item_topo do
        local iid = item_topo[idx]
        local ts = supply_map[iid] or {}
        local mts = market_only_map[iid] or {}
        local best_b = (#ts > 0) and ts[1].unit_price or INF
        local best_m = (#mts > 0) and mts[1].unit_price or best_b
        local prods = producers_by_item[iid] or {}
        for i = 1, #prods do
          local rec = prods[i]
          local out_net = 0.0
          for j = 1, #rec.outputs do
            if rec.outputs[j][1] == iid then out_net = out_net + rec.outputs[j][2] end
          end
          for j = 1, #rec.reagents do
            if rec.reagents[j][1] == iid then out_net = out_net - rec.reagents[j][2] end
          end
          if out_net > EPS then
            local rc_b, rc_m = 0.0, 0.0
            for j = 1, #rec.reagents do
              local rg, c = rec.reagents[j][1], rec.reagents[j][2]
              if rg ~= iid then
                rc_b = rc_b + c * (base_acq_price[rg] or INF)
                rc_m = rc_m + c * (mkt_ref_price[rg] or INF)
              end
            end
            best_b = math_min(best_b, rc_b / out_net)
            best_m = math_min(best_m, rc_m / out_net)
          end
        end
        base_acq_price[iid] = best_b
        mkt_ref_price[iid] = best_m
      end

      for i = 1, #(problem.essence_pairs or {}) do
        local ep = problem.essence_pairs[i]
        for _, tbl in ipairs({ base_acq_price, mkt_ref_price }) do
          local pl = tbl[ep.lesser_item_id] or INF
          local pg = tbl[ep.greater_item_id] or INF
          local pl2 = math_min(pl, pg / ep.ratio)
          local pg2 = math_min(pg, pl2 * ep.ratio)
          tbl[ep.lesser_item_id] = pl2
          tbl[ep.greater_item_id] = pg2
        end
      end

      local ext_only_price = {}
      for idx = 1, #item_topo do
        local iid = item_topo[idx]
        local mts = market_only_map[iid] or {}
        ext_only_price[iid] = (#mts > 0) and mts[1].unit_price or INF
      end

      local recipe_mkt_cost = {}
      for sid, rec in pairs(usable_recipes) do
        local s_c = 0.0
        for i = 1, #rec.reagents do
          s_c = s_c + rec.reagents[i][2] * (mkt_ref_price[rec.reagents[i][1]] or 0.0)
        end
        recipe_mkt_cost[sid] = s_c
      end

      local eff_inter_sell = {}
      local lesser_converts_up = {}
      if is_net then
        for iid, _ in pairs(inter_items) do
          eff_inter_sell[iid] = sell_map[iid] or 0.0
        end
        for i = 1, #(problem.essence_pairs or {}) do
          local ep = problem.essence_pairs[i]
          local lid, gid, ratio = ep.lesser_item_id, ep.greater_item_id, ep.ratio
          local sl = sell_map[lid] or 0.0
          local sg = sell_map[gid] or 0.0
          if sg > sl * ratio + EPS then lesser_converts_up[lid] = true end
          local eff_l = math_max(sl, sg / ratio)
          eff_inter_sell[lid] = eff_l
          eff_inter_sell[gid] = math_max(sg, eff_l * ratio)
        end
      end

      local inter_cost_cap = (opts.high_cost_green_threshold_copper > EPS)
        and math_min(4000.0, 0.4 * opts.high_cost_green_threshold_copper)
        or 4000.0
      local pure_inter_recipes = {}
      for _, sid in ipairs(usable_sids) do
        local rec = usable_recipes[sid]
        if rec.kind == "craft" and (not rec.produces_tool) and #rec.outputs > 0
          and (recipe_mkt_cost[sid] or 0.0) <= inter_cost_cap + EPS then
          local all_inter = true
          for j = 1, #rec.outputs do
            local oid = rec.outputs[j][1]
            if (not inter_items[oid]) or (reagent_use_count[oid] or 0) < 2 then
              all_inter = false
              break
            end
          end
          if all_inter then pure_inter_recipes[sid] = true end
        end
      end
      local cur_entry_caps = {}
      local cur_min_starts = {}
      local enforce_no_repeat_active = false

      -- 4. 工具状态空间编码（0-based 状态编号 0 .. num_tool_states-1）
      local req_cats = {}
      for _, r in pairs(usable_recipes) do
        for i = 1, #(r.required_tools or {}) do
          local cat, tier = r.required_tools[i][1], r.required_tools[i][2]
          req_cats[cat] = math_max(req_cats[cat] or 0, tier)
        end
      end

      local init_tiers = {}
      for k, v in pairs(p_ctx.owned_tool_categories) do init_tiers[k] = v end
      for i = 1, #(problem.tools or {}) do
        local t = problem.tools[i]
        local has_t = p_ctx.owned_tools[t.item_id]
          or (p_ctx.use_owned_inventory and ((p_ctx.owned_items[t.item_id] or 0) > 0))
        if has_t then
          init_tiers[t.tool_category] = math_max(init_tiers[t.tool_category] or 0, t.tier)
          if t.tool_category == "gnomish_army_knife" then
            init_tiers.arclight_spanner = math_max(init_tiers.arclight_spanner or 0, 1)
            init_tiers.blacksmith_hammer = math_max(init_tiers.blacksmith_hammer or 0, 1)
          end
        end
      end

      local tool_cats = {}
      local tool_radices = {}
      local cat_index = {}
      for _, cat in ipairs(sorted_keys(req_cats)) do
        local max_req = req_cats[cat]
        if (init_tiers[cat] or 0) < max_req then
          tool_cats[#tool_cats + 1] = cat
          tool_radices[#tool_radices + 1] = max_req + 1
          cat_index[cat] = #tool_cats
        end
      end

      local num_tool_states = 1
      for i = 1, #tool_radices do num_tool_states = num_tool_states * tool_radices[i] end

      local function encode_tool_arr(arr)
        local code, mult = 0, 1
        for i = 1, #tool_radices do
          code = code + arr[i] * mult
          mult = mult * tool_radices[i]
        end
        return code
      end

      local function decode_tool_arr(code)
        local res = {}
        local rem = code
        for i = 1, #tool_radices do
          local rad = tool_radices[i]
          res[i] = rem % rad
          rem = math_floor(rem / rad)
        end
        return res
      end

      local init_arr = {}
      for i = 1, #tool_cats do
        init_arr[i] = math_min(tool_radices[i] - 1, init_tiers[tool_cats[i]] or 0)
      end
      local init_tool_state = encode_tool_arr(init_arr)

      local function tool_satisfies(state, reqs)
        if not reqs or #reqs == 0 or num_tool_states == 1 then return true end
        local tiers = decode_tool_arr(state)
        for i = 1, #reqs do
          local idx = cat_index[reqs[i][1]]
          if idx and tiers[idx] < reqs[i][2] then return false end
        end
        return true
      end

      local function compute_tool_upgrade_raw(state, cidx, new_tier)
        local tiers = decode_tool_arr(state)
        if tiers[cidx] >= new_tier then return state end
        tiers[cidx] = math_min(tool_radices[cidx] - 1, new_tier)
        return encode_tool_arr(tiers)
      end

      local tool_upgrade_tbl = {}
      for st = 0, num_tool_states - 1 do
        tool_upgrade_tbl[st] = {}
        for cidx = 1, #tool_cats do
          tool_upgrade_tbl[st][cidx] = {}
          for tier = 0, tool_radices[cidx] - 1 do
            tool_upgrade_tbl[st][cidx][tier] = compute_tool_upgrade_raw(st, cidx, tier)
          end
        end
      end

      local function tool_upgrade(state, cidx, new_tier)
        local cap_t = math_min(tool_radices[cidx] - 1, new_tier)
        return tool_upgrade_tbl[state][cidx][cap_t]
      end

      local tool_buy_actions = {}
      local tool_prep_crafts = {}
      local prep_thresh_set = { [s0] = true }
      for i = 1, #(problem.tools or {}) do
        local t = problem.tools[i]
        local cidx = cat_index[t.tool_category]
        if cidx then
          local capped_t = math_min(tool_radices[cidx] - 1, t.tier)
          if capped_t > 0 then
            if (not t.bind_on_pickup) and supply_map[t.item_id] and #supply_map[t.item_id] > 0 then
              tool_buy_actions[#tool_buy_actions + 1] = { cidx, capped_t, t.item_id }
            end
            if t.craft_spell_id and usable_recipes[t.craft_spell_id] then
              local trec = usable_recipes[t.craft_spell_id]
              tool_prep_crafts[#tool_prep_crafts + 1] = { cidx, capped_t, trec }
              prep_thresh_set[math_max(s0, trec.min_skill)] = true
            end
          end
        end
      end
      local tool_prep_thresholds = sorted_keys(prep_thresh_set)

      local function compute_tool_trans_matrix(s, pi, forced_open, forced_closed)
        local mat = {}
        local acts = {}
        for i = 0, num_tool_states - 1 do
          mat[i] = {}
          acts[i] = {}
          for j = 0, num_tool_states - 1 do
            mat[i][j] = (i == j) and 0.0 or INF
            acts[i][j] = {}
          end
        end
        if num_tool_states <= 1 then return mat, acts end

        for tin = 0, num_tool_states - 1 do
          local up_tin = tool_upgrade_tbl[tin]
          for i = 1, #tool_buy_actions do
            local act = tool_buy_actions[i]
            local tout = up_tin[act[1]][act[2]]
            if tout ~= tin then
              local c = pi[act[3]] or base_acq_price[act[3]] or INF
              if c < mat[tin][tout] - 1e-9 then
                mat[tin][tout] = c
                acts[tin][tout] = { { "tool_buy", act[3] } }
              end
            end
          end
          for i = 1, #tool_prep_crafts do
            local act = tool_prep_crafts[i]
            local trec = act[3]
            if (not (forced_closed and forced_closed[trec.spell_id]))
              and s >= trec.min_skill and tool_satisfies(tin, trec.required_tools) then
              local tout = up_tin[act[1]][act[2]]
              if tout ~= tin then
                local c = 0.0
                for j = 1, #trec.reagents do
                  c = c + trec.reagents[j][2] * (pi[trec.reagents[j][1]] or 0.0)
                end
                if (not trec.grey or trec.grey <= trec.min_skill) and trec.unlock_cost_copper > EPS
                  and not (forced_open and forced_open[trec.spell_id]) then
                  c = c + trec.unlock_cost_copper
                end
                if c < mat[tin][tout] - 1e-9 then
                  mat[tin][tout] = c
                  acts[tin][tout] = { { "tool_craft", trec.spell_id } }
                end
              end
            end
          end
        end

        for k = 0, num_tool_states - 1 do
          local mk, ak = mat[k], acts[k]
          for i = 0, num_tool_states - 1 do
            local mik = mat[i][k]
            if mik < INF * 0.5 then
              local mi, ai, aik = mat[i], acts[i], acts[i][k]
              for j = 0, num_tool_states - 1 do
                if mk[j] < INF * 0.5 then
                  local cand = mik + mk[j]
                  if cand < mi[j] - 1e-9 then
                    mi[j] = cand
                    local merged_a = {}
                    for u = 1, #aik do merged_a[#merged_a + 1] = aik[u] end
                    local akj = ak[j]
                    for u = 1, #akj do merged_a[#merged_a + 1] = akj[u] end
                    ai[j] = merged_a
                  end
                end
              end
            end
          end
        end
        return mat, acts
      end

      local function compute_all_tool_trans(reached_sk, pi, forced_open, forced_closed)
        local tool_mats = {}
        local tool_acts = {}
        if num_tool_states <= 1 then
          local zmat = { [0] = { [0] = 0.0 } }
          local eact = { [0] = { [0] = {} } }
          for s = s0, reached_sk do
            tool_mats[s] = zmat
            tool_acts[s] = eact
          end
          return tool_mats, tool_acts
        end
        local bps = {}
        for i = 1, #tool_prep_thresholds do
          local b = tool_prep_thresholds[i]
          if b > s0 and b < reached_sk then bps[#bps + 1] = b end
        end
        local seg_s = { s0 }
        local seg_e = {}
        for i = 1, #bps do
          seg_e[#seg_e + 1] = bps[i]
          seg_s[#seg_s + 1] = bps[i]
        end
        seg_e[#seg_e + 1] = reached_sk
        for i = 1, #seg_s do
          local tmat, tact = compute_tool_trans_matrix(seg_s[i], pi, forced_open, forced_closed)
          for s = seg_s[i], seg_e[i] - 1 do
            tool_mats[s] = tmat
            tool_acts[s] = tact
          end
        end
        return tool_mats, tool_acts
      end

      -- 5. 构建连续技能段有向无环图
      if s0 >= starget then
        return {
          status = "unreachable",
          profession = problem.profession,
          objective = opts.objective,
          risk_mode = opts.risk_mode,
          confidence = opts.confidence,
          start_skill = s0,
          target_skill = starget,
          reached_skill = s0,
          is_optimal = true,
          lower_bound_copper = 0.0,
          optimality_gap_copper = 0.0,
          objective_value_copper = 0.0,
          gross_cost_copper = 0.0,
          sell_revenue_copper = 0.0,
          raw_net_spend_copper = 0.0,
          anti_farm_net_spend_copper = 0.0,
          owned_opportunity_cost_copper = 0.0,
          unlock_cost_copper = 0.0,
          route_std_copper = 0.0,
          steps = {},
          shopping_list = {},
          owned_consumed = {},
          sold_outputs = {},
          retained_tools = {},
          unlocked_recipes = {},
          prep_confidence = opts.prep_confidence,
          gross_std_copper = 0.0,
          safe_gross_cost_copper = 0.0,
          safe_net_spend_copper = 0.0,
          safe_prep_gross_cost_copper = 0.0,
          safe_shopping_list = {},
          safe_owned_consumed = {},
        }
      end

      local skill_has_recipe = {}
      for _, sid in ipairs(usable_sids) do
        local r = usable_recipes[sid]
        if r.grey and r.grey > r.min_skill then
          local rmax_c = recipe_max_crafts[sid] or math_huge
          local lo = math_max(s0, r.min_skill)
          local hi = math_min(starget, r.grey)
          for s = lo, hi - 1 do
            local p = M.skill_up_prob(r, s)
            if p > 0.0 and (1.0 / p) <= rmax_c + EPS then skill_has_recipe[s] = true end
          end
        end
      end

      local use_mining_gather = (problem.profession == "mining") and opts.enable_field_mining_fallback
      local reached = s0
      while reached < starget do
        if skill_has_recipe[reached] or use_mining_gather then
          reached = reached + 1
        else
          break
        end
      end

      local blocker = nil
      if reached < starget then
        local cands = {}
        for i = 1, #blocked_recipes do
          local br = blocked_recipes[i]
          if br.min_skill <= reached and reached < (br.grey or 0) then
            local miss = {}
            for j = 1, #br.reagents do
              local iid = br.reagents[j][1]
              if (not supply_map[iid] or #supply_map[iid] == 0) and not producers_by_item[iid] then
                miss[#miss + 1] = iid
              end
            end
            if #cands < 10 then cands[#cands + 1] = { spell_id = br.spell_id, name = br.name, missing_items = miss } end
          end
        end
        for i = 1, #(problem.excluded_missing_price or {}) do
          if #cands < 10 then
            local ex = problem.excluded_missing_price[i]
            cands[#cands + 1] = { spell_id = ex[1], name = ex[2], missing_items = ex[3] }
          end
        end
        blocker = { blocked_at_skill = reached, candidate_recipes = cands }
      end

      if reached <= s0 then
        return {
          status = "unreachable",
          profession = problem.profession,
          objective = opts.objective,
          risk_mode = opts.risk_mode,
          confidence = opts.confidence,
          start_skill = s0,
          target_skill = starget,
          reached_skill = s0,
          is_optimal = true,
          lower_bound_copper = 0.0,
          optimality_gap_copper = 0.0,
          objective_value_copper = 0.0,
          gross_cost_copper = 0.0,
          sell_revenue_copper = 0.0,
          raw_net_spend_copper = 0.0,
          anti_farm_net_spend_copper = 0.0,
          owned_opportunity_cost_copper = 0.0,
          unlock_cost_copper = 0.0,
          route_std_copper = 0.0,
          steps = {},
          shopping_list = {},
          owned_consumed = {},
          sold_outputs = {},
          retained_tools = {},
          unlocked_recipes = {},
          blocker = blocker,
          prep_confidence = opts.prep_confidence,
          gross_std_copper = 0.0,
          safe_gross_cost_copper = 0.0,
          safe_net_spend_copper = 0.0,
          safe_prep_gross_cost_copper = 0.0,
          safe_shopping_list = {},
          safe_owned_consumed = {},
        }
      end

      local use_step_q = (opts.risk_mode == "step_quantile")
      local linear_unit_by_s = {}
      local sq_groups_by_s1 = {}
      local gather_end_by_s = {}
      for s = s0, reached do
        linear_unit_by_s[s] = {}
        sq_groups_by_s1[s] = {}
      end

      -- 5a. 高成本绿字禁区保护：当单次毛成本 >= 阈值且当前技能点存在合理（<=2.5倍单点成本）的橙/高黄（p>=0.50）替代时，截断 p<0.50 绿字区间
      local eff_grey = {}
      for _, sid in ipairs(usable_sids) do
        eff_grey[sid] = usable_recipes[sid].grey or 0
      end
      local green_thr = opts.high_cost_green_threshold_copper
      if green_thr > EPS then
        local best_safe_pp = {}
        for s = s0, reached - 1 do best_safe_pp[s] = INF end
        for _, sid2 in ipairs(usable_sids) do
          local r2 = usable_recipes[sid2]
          local g2 = r2.grey or 0
          if g2 > r2.min_skill and (not r2.produces_tool) then
            local lo2 = math_max(s0, r2.min_skill)
            local hi2 = math_min(reached, g2)
            if lo2 < hi2 then
              local span2 = math_max(5.0, hi2 - lo2)
              local rmax2 = recipe_max_crafts[sid2] or math_huge
              local cm2 = recipe_mkt_cost[sid2] or 0.0
              local is_kn2 = p_ctx.known_recipes[sid2] or p_ctx.known_recipes[tostring(sid2)] or (r2.learn_kind == "autoGrant")
              local ul2 = is_kn2 and 0.0 or r2.unlock_cost_copper
              for s = lo2, hi2 - 1 do
                local p2 = M.skill_up_prob(r2, s)
                if p2 >= 0.50 - 1e-9 and (1.0 / p2) <= rmax2 + EPS then
                  local pp2 = cm2 / p2 + ul2 / span2
                  if pp2 < best_safe_pp[s] then best_safe_pp[s] = pp2 end
                end
              end
            end
          end
        end

        for _, sid in ipairs(usable_sids) do
          local r = usable_recipes[sid]
          if (not r.produces_tool) and (r.grey or 0) > r.min_skill then
            local cm = recipe_mkt_cost[sid] or 0.0
            if cm >= green_thr - EPS then
              local lo_r = math_max(s0, r.min_skill)
              local hi_r = math_min(reached, r.grey or 0)
              for s = lo_r, hi_r - 1 do
                local p = M.skill_up_prob(r, s)
                if p < 0.50 - 1e-9 and best_safe_pp[s] <= 2.5 * (cm / math_max(1e-6, p)) + EPS then
                  eff_grey[sid] = s
                  break
                end
              end
            end
          end
        end

        for s = s0, reached - 1 do
          if not (use_mining_gather and not skill_has_recipe[s]) then
            local ok_s = false
            for _, sid in ipairs(usable_sids) do
              local r = usable_recipes[sid]
              if r.min_skill <= s and s < eff_grey[sid] then
                local p = M.skill_up_prob(r, s)
                if p > 0.0 and (1.0 / p) <= (recipe_max_crafts[sid] or math_huge) + EPS then
                  ok_s = true
                  break
                end
              end
            end
            if not ok_s then
              for _, sid in ipairs(usable_sids) do
                local r = usable_recipes[sid]
                if r.min_skill <= s and s < (r.grey or 0) then
                  eff_grey[sid] = r.grey or 0
                end
              end
            end
          end
        end
      end

      -- 5b. 预计算每配方自适应切换惩罚、期望次数/方差前缀和与高成本局部失败风险溢价前缀和
      local recipe_sw_pen = { [-186] = 0.0 }
      local crafts_pref = {}
      local var_pref = {}
      local fail_pen_pref = {}
      local max_s2_from_lo = {}

      local sw_base = opts.switch_penalty_copper
      local sw_ratio = (sw_base > EPS) and opts.switch_cost_ratio or 0.0
      local aversion = math_max(0.0, opts.high_cost_fail_aversion)

      for _, sid in ipairs(usable_sids) do
        local r = usable_recipes[sid]
        local cm = recipe_mkt_cost[sid] or 0.0
        if sw_base <= EPS then
          recipe_sw_pen[sid] = 0.0
        elseif r.produces_tool or pure_inter_recipes[sid] then
          recipe_sw_pen[sid] = sw_base
        else
          recipe_sw_pen[sid] = sw_base + math_min(25000.0, sw_ratio * cm)
        end

        local g_orig = r.grey or 0
        local span_full = math_max(0, g_orig - r.min_skill)
        local cp_arr = { [0] = 0.0 }
        local vp_arr = { [0] = 0.0 }
        local fp_arr = { [0] = 0.0 }
        local wh = (cm > EPS) and (cm / (cm + 10000.0)) or 0.0
        for idx_k = 0, span_full - 1 do
          local sk = r.min_skill + idx_k
          local p = M.skill_up_prob(r, sk)
          local c1 = (p > 0.0) and (1.0 / p) or 0.0
          local v1 = (p > 0.0) and ((1.0 - p) / (p * p)) or 0.0
          local fp1 = 0.0
          if aversion > EPS and p > 0.0 and p < 1.0 - 1e-12 then
            fp1 = aversion * wh * cm * (math_sqrt(math_max(0.0, 1.0 - p)) + (1.0 - p)) / p
          end
          cp_arr[idx_k + 1] = cp_arr[idx_k] + c1
          vp_arr[idx_k + 1] = vp_arr[idx_k] + v1
          fp_arr[idx_k + 1] = fp_arr[idx_k] + fp1
        end
        crafts_pref[sid] = cp_arr
        var_pref[sid] = vp_arr
        fail_pen_pref[sid] = fp_arr

        local lo_r = math_max(s0, r.min_skill)
        local hi_r = math_min(reached, eff_grey[sid])
        local rmax_c = recipe_max_crafts[sid] or math_huge
        if lo_r >= hi_r then
          max_s2_from_lo[sid] = lo_r
        elseif is_inf(rmax_c) then
          max_s2_from_lo[sid] = hi_r
        else
          local acc_c = 0.0
          local cap_s2 = lo_r
          for sk = lo_r, hi_r - 1 do
            local p = M.skill_up_prob(r, sk)
            if p <= 0.0 then break end
            local c_need
            if p >= 1.0 - 1e-12 then
              c_need = 1.0
            elseif use_step_q then
              c_need = 1.0 + math_floor(log_omc / math_log(1.0 - p))
            else
              c_need = 1.0 / p
            end
            if acc_c + c_need > rmax_c + EPS then break end
            acc_c = acc_c + c_need
            cap_s2 = sk + 1
          end
          max_s2_from_lo[sid] = cap_s2
        end
      end

      -- 5c. 无损数学支配剪枝：剔除被全面严格支配的无耦合零解锁纯终端配方
      local pure_sink_specs = {}
      local function tools_sig(reqs)
        if not reqs or #reqs == 0 then return "" end
        local ps = {}
        for i = 1, #reqs do ps[i] = reqs[i][1] .. ":" .. tostring(reqs[i][2]) end
        return table.concat(ps, "|")
      end

      for _, sid in ipairs(usable_sids) do
        local r = usable_recipes[sid]
        local eg = eff_grey[sid] or 0
        if eg > r.min_skill then
          local lo = math_max(s0, r.min_skill)
          local hi = math_min(reached, eg)
          if lo < hi and (not r.produces_tool) and r.unlock_cost_copper <= EPS then
            local no_coup = true
            for j = 1, #r.reagents do
              if coupled_items[r.reagents[j][1]] then no_coup = false; break end
            end
            if no_coup then
              for j = 1, #r.outputs do
                if inter_items[r.outputs[j][1]] then no_coup = false; break end
              end
            end
            if no_coup then
              local u_in = 0.0
              for j = 1, #r.reagents do
                u_in = u_in + r.reagents[j][2] * supply_map[r.reagents[j][1]][1].unit_price
              end
              local v_out = 0.0
              if is_net then
                for j = 1, #r.outputs do v_out = v_out + r.outputs[j][2] * (sell_map[r.outputs[j][1]] or 0.0) end
              end
              local e1 = u_in - v_out
              local eret = math_max(0.0, u_in - v_out)
              local cm_r = recipe_mkt_cost[sid] or u_in
              pure_sink_specs[#pure_sink_specs + 1] = { sid, lo, hi, tools_sig(r.required_tools), e1, eret, cm_r, r }
            end
          end
        end
      end

      local dominated_spells = {}
      for i = 1, #pure_sink_specs do
        local b = pure_sink_specs[i]
        for j = 1, #pure_sink_specs do
          if i ~= j then
            local a = pure_sink_specs[j]
            if (not dominated_spells[a[1]]) and a[4] == b[4] and a[2] <= b[2] and a[3] >= b[3] then
              if a[5] <= b[5] + 1e-9 and a[6] <= b[6] + 1e-9 and a[7] <= b[7] + 1e-9 then
                if not (math_abs(a[5] - b[5]) <= 1e-9 and math_abs(a[6] - b[6]) <= 1e-9 and math_abs(a[7] - b[7]) <= 1e-9 and a[1] > b[1]) then
                  local all_p = true
                  for s = b[2], b[3] - 1 do
                    if M.skill_up_prob(a[8], s) < M.skill_up_prob(b[8], s) - 1e-12 then
                      all_p = false
                      break
                    end
                  end
                  if all_p then
                    dominated_spells[b[1]] = true
                    break
                  end
                end
              end
            end
          end
        end
      end

      if use_mining_gather then
        local s = s0
        while s < reached do
          if not skill_has_recipe[s] then
            local s_end = s + 1
            while s_end < reached and not skill_has_recipe[s_end] do s_end = s_end + 1 end
            gather_end_by_s[s] = s_end
            s = s_end
          else
            s = s + 1
          end
        end
      end

      local bridge_exempt_skills = {}
      local min_seg = math_max(1, math_floor(opts.min_segment_points))

      local function min_end_skill(sid, s1)
        local r = usable_recipes[sid]
        if min_seg <= 1 or r.produces_tool or bridge_exempt_skills[s1] then
          return s1 + 1
        end
        local eff_seg = pure_inter_recipes[sid] and math_min(3, min_seg) or min_seg
        local lo_r = math_max(s0, r.min_skill)
        local max_lo_end = max_s2_from_lo[sid] or math_min(reached, eff_grey[sid] or 0)
        if max_lo_end - lo_r < eff_seg then
          return (s1 == lo_r) and max_lo_end or (reached + 1)
        end
        return s1 + eff_seg
      end

      local function has_terminal_repeat(arcs)
        local prev_end = {}
        for i = 1, #arcs do
          local a = arcs[i]
          if a.kind ~= "gather" and a.spell_id > 0 and (not pure_inter_recipes[a.spell_id]) then
            local pe = prev_end[a.spell_id]
            if pe ~= nil and pe < a.s1 then return true end
            prev_end[a.spell_id] = a.s2
          end
        end
        return false
      end

      local function find_first_terminal_repeat(arcs)
        local prev_end = {}
        for i = 1, #arcs do
          local a = arcs[i]
          if a.kind ~= "gather" and a.spell_id > 0 and (not pure_inter_recipes[a.spell_id]) then
            local pe = prev_end[a.spell_id]
            if pe ~= nil and pe < a.s1 then return { a.spell_id, pe } end
            prev_end[a.spell_id] = a.s2
          end
        end
        return nil
      end

      if min_seg > 1 then
        for _ = 1, (reached - s0 + 1) do
          local reach_s = { [s0] = true }
          local max_r = s0
          for s_cur = s0, reached - 1 do
            if reach_s[s_cur] then
              local ge = gather_end_by_s[s_cur]
              if ge then
                reach_s[ge] = true
                if ge > max_r then max_r = ge end
              end
              for _, sid in ipairs(usable_sids) do
                if not dominated_spells[sid] then
                  local r = usable_recipes[sid]
                  local hi_r = math_min(reached, eff_grey[sid] or 0)
                  local lo_r = math_max(s0, r.min_skill)
                  if lo_r <= s_cur and s_cur < hi_r then
                    local req_end = min_end_skill(sid, s_cur)
                    local cap_end = max_s2_from_lo[sid] or hi_r
                    local rm_c = recipe_max_crafts[sid] or math_huge
                    if (not is_inf(rm_c)) and s_cur > lo_r then
                      local acc_tmp = 0.0
                      cap_end = s_cur
                      for sk_t = s_cur, hi_r - 1 do
                        local p_t = M.skill_up_prob(r, sk_t)
                        if p_t <= 0.0 then break end
                        local c_t = (p_t >= 1.0 - 1e-12) and 1.0
                          or (use_step_q and (1.0 + math_floor(log_omc / math_log(1.0 - p_t))) or (1.0 / p_t))
                        if acc_tmp + c_t > rm_c + EPS then break end
                        acc_tmp = acc_tmp + c_t
                        cap_end = sk_t + 1
                      end
                    end
                    if req_end <= cap_end then
                      for s_to = req_end, cap_end do reach_s[s_to] = true end
                      if cap_end > max_r then max_r = cap_end end
                    end
                  end
                end
              end
            end
          end
          if reach_s[reached] then break end
          local added_any = false
          for s_ex = math_max(s0, max_r - min_seg), math_min(reached - 1, max_r) do
            if reach_s[s_ex] and (not bridge_exempt_skills[s_ex]) then
              bridge_exempt_skills[s_ex] = true
              added_any = true
            end
          end
          if not added_any then
            for s_ex = s0, reached - 1 do bridge_exempt_skills[s_ex] = true end
            break
          end
        end
      end

      for _, sid in ipairs(usable_sids) do
        local r = usable_recipes[sid]
        local eg = eff_grey[sid] or 0
        if (not dominated_spells[sid]) and eg > r.min_skill then
          local lo = math_max(s0, r.min_skill)
          local hi = math_min(reached, eg)
          if lo < hi then
            local allowed_states = {}
            for st = 0, num_tool_states - 1 do
              if tool_satisfies(st, r.required_tools) then
                allowed_states[#allowed_states + 1] = st
              end
            end
            if #allowed_states > 0 then
              local prod_cidx, prod_tier, prod_bop = -1, 0, false
              if r.produces_tool then
                local pitem_id = r.produces_tool[3]
                for ti = 1, #(problem.tools or {}) do
                  if problem.tools[ti].item_id == pitem_id and problem.tools[ti].bind_on_pickup then
                    prod_bop = true
                    break
                  end
                end
                local cidx = cat_index[r.produces_tool[1]]
                if cidx then
                  prod_cidx = cidx
                  prod_tier = math_min(tool_radices[cidx] - 1, r.produces_tool[2])
                end
              end

              local trans_pairs = {}
              for u = 1, #allowed_states do
                local tin = allowed_states[u]
                local tout = (prod_cidx >= 1) and tool_upgrade(tin, prod_cidx, prod_tier) or tin
                if not (prod_bop and tout == tin) then
                  trans_pairs[#trans_pairs + 1] = { tin, tout }
                end
              end

              if #trans_pairs > 0 then
                local rmax_c = recipe_max_crafts[sid] or math_huge
                if not use_step_q then
                  for s = lo, hi - 1 do
                    local p = M.skill_up_prob(r, s)
                    if p > 0.0 then
                      local c1 = 1.0 / p
                      if (not (prod_bop and c1 > 1.0 + EPS)) and c1 <= rmax_c + EPS then
                        local v1 = (1.0 - p) / (p * p)
                        local req_s2_b = min_end_skill(r.spell_id, s)
                        local ls = linear_unit_by_s[s]
                        ls[#ls + 1] = { r.spell_id, r.kind, c1, v1, trans_pairs, prod_bop, req_s2_b }
                      end
                    end
                  end
                else
                  local probs_full = {}
                  for s = lo, hi - 1 do probs_full[#probs_full + 1] = M.skill_up_prob(r, s) end
                  local first_green = 0
                  while first_green < #probs_full and probs_full[first_green + 1] >= 1.0 - 1e-12 do
                    first_green = first_green + 1
                  end
                  local cached_green_q = nil
                  if first_green < #probs_full then
                    local gp = {}
                    for u = first_green + 1, #probs_full do gp[#gp + 1] = probs_full[u] end
                    cached_green_q = M.compute_step_quantiles_from(gp, opts.confidence)
                  end
                  for idx1 = 1, (hi - lo) do
                    local s1 = lo + idx1 - 1
                    local req_s2 = min_end_skill(r.spell_id, s1)
                    if req_s2 <= hi then
                      local sub_probs = {}
                      for u = idx1, #probs_full do sub_probs[#sub_probs + 1] = probs_full[u] end
                      local q_counts
                      if idx1 - 1 <= first_green then
                        local m_det = first_green - (idx1 - 1)
                        q_counts = {}
                        for i = 1, m_det do q_counts[i] = i end
                        if cached_green_q then
                          for i = 1, #cached_green_q do q_counts[m_det + i] = m_det + cached_green_q[i] end
                        end
                      else
                        q_counts = M.compute_step_quantiles_from(sub_probs, opts.confidence)
                      end
                      local acc_var = 0.0
                      for offset = 1, #sub_probs do
                        local p = sub_probs[offset]
                        local s2 = s1 + offset
                        acc_var = acc_var + (1.0 - p) / (p * p)
                        local crafts = q_counts[offset]
                        if (prod_bop and crafts > 1.0 + EPS) or crafts > rmax_c + EPS then break end
                        if s2 >= req_s2 then
                          local gs = sq_groups_by_s1[s1]
                          gs[#gs + 1] = { r.spell_id, r.kind, s1, s2, crafts, acc_var, s2 - s1, trans_pairs }
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      local function make_seg_arc(spell_id, kind, s1, s2, tin, tout, crafts, var_crafts)
        local aid = tostring(spell_id) .. ":" .. tostring(s1) .. ":" .. tostring(s2) .. ":" .. tostring(tin)
        return {
          arc_id = aid,
          spell_id = spell_id,
          kind = kind,
          s1 = s1,
          s2 = s2,
          tool_in = tin,
          tool_out = tout,
          crafts = crafts,
          var_crafts = var_crafts,
          delta_s = s2 - s1,
        }
      end

      local function arcs_from_s1(cur_s)
        local out = {}
        local ge = gather_end_by_s[cur_s]
        if ge then
          for tin = 0, num_tool_states - 1 do
            out[#out + 1] = make_seg_arc(-186, "gather", cur_s, ge, tin, tin, ge - cur_s, 0.0)
          end
        end
        if use_step_q then
          local gs = sq_groups_by_s1[cur_s]
          for i = 1, #gs do
            local g = gs[i]
            local sid, s1 = g[1], g[3]
            if s1 >= (cur_min_starts[sid] or 0) and s1 < (cur_entry_caps[sid] or (reached + 1)) then
              local tp = g[8]
              for u = 1, #tp do
                out[#out + 1] = make_seg_arc(sid, g[2], s1, g[4], tp[u][1], tp[u][2], g[5], g[6])
              end
            end
          end
        else
          local ls = linear_unit_by_s[cur_s]
          for i = 1, #ls do
            local u = ls[i]
            local sid, rkind, c1, v1, tp, pbop, req_s2 = u[1], u[2], u[3], u[4], u[5], u[6], u[7]
            if cur_s >= (cur_min_starts[sid] or 0) and cur_s < (cur_entry_caps[sid] or (reached + 1)) then
              local rec = usable_recipes[sid]
              local hi = math_min(reached, eff_grey[sid] or rec.grey or reached)
              if req_s2 <= hi then
                for k = 1, #tp do
                  local tin, tout0 = tp[k][1], tp[k][2]
                  local acc_c, acc_v = c1, v1
                  if cur_s + 1 >= req_s2 then
                    out[#out + 1] = make_seg_arc(sid, rkind, cur_s, cur_s + 1, tin, tout0, acc_c, acc_v)
                  end
                  if not pbop then
                    local rmax_c = recipe_max_crafts[sid] or math_huge
                    for s_nxt = cur_s + 1, hi - 1 do
                      local p = M.skill_up_prob(rec, s_nxt)
                      if p <= 0.0 then break end
                      acc_c = acc_c + 1.0 / p
                      if acc_c > rmax_c + EPS then break end
                      acc_v = acc_v + (1.0 - p) / (p * p)
                      if s_nxt + 1 >= req_s2 then
                        out[#out + 1] = make_seg_arc(sid, rkind, cur_s, s_nxt + 1, tin, tout0, acc_c, acc_v)
                      end
                    end
                  end
                end
              end
            end
          end
        end
        return out
      end

      -- 6. 对偶投影、弧简约成本、反向 DP 与精确因果原问题评估
      local function project_shadow_prices(pi, forced_open, forced_closed)
        local proj = {}
        for idx = 1, #item_topo do
          local iid = item_topo[idx]
          local ts = supply_map[iid] or {}
          if not coupled_items[iid] then
            proj[iid] = (#ts > 0) and ts[1].unit_price or 0.0
          else
            local lo = inter_items[iid] and 0.0 or ((#ts > 0) and ts[1].unit_price or 0.0)
            local inf_cap = INF
            if #ts > 0 and is_inf(ts[#ts].max_qty) and ts[#ts].bundle_size == 1 then
              inf_cap = ts[#ts].unit_price
            end
            local val = pi[iid]
            if val == nil then val = base_acq_price[iid] or lo end
            val = math_max(lo, math_min(inf_cap, val))
            local prods = producers_by_item[iid] or {}
            for i = 1, #prods do
              local rec = prods[i]
              if not (forced_closed and forced_closed[rec.spell_id]) then
                local out_net = 0.0
                for j = 1, #rec.outputs do
                  if rec.outputs[j][1] == iid then out_net = out_net + rec.outputs[j][2] end
                end
                for j = 1, #rec.reagents do
                  if rec.reagents[j][1] == iid then out_net = out_net - rec.reagents[j][2] end
                end
                if out_net > EPS then
                  local mcost = 0.0
                  for j = 1, #rec.reagents do
                    local rg, c = rec.reagents[j][1], rec.reagents[j][2]
                    if rg ~= iid then
                      mcost = mcost + c * (proj[rg] or base_acq_price[rg] or 0.0)
                    end
                  end
                  local amort_ul = 0.0
                  if rec.unlock_cost_copper > EPS and not (forced_open and forced_open[rec.spell_id]) then
                    local mb = producer_max_batches[tostring(rec.spell_id) .. ":" .. tostring(iid)] or 1.0
                    amort_ul = rec.unlock_cost_copper / mb
                  end
                  val = math_min(val, (mcost + amort_ul) / out_net)
                end
              end
            end
            proj[iid] = math_max(lo, val)
          end
        end

        for i = 1, #(problem.essence_pairs or {}) do
          local ep = problem.essence_pairs[i]
          local lid, gid, ratio = ep.lesser_item_id, ep.greater_item_id, ep.ratio
          if proj[lid] ~= nil or proj[gid] ~= nil then
            local lo_l = 0.0
            local ts_l = supply_map[lid] or {}
            local ts_g = supply_map[gid] or {}
            local hi_l = INF
            if #ts_l > 0 and is_inf(ts_l[#ts_l].max_qty) then hi_l = math_min(hi_l, ts_l[#ts_l].unit_price) end
            if #ts_g > 0 and is_inf(ts_g[#ts_g].max_qty) then hi_l = math_min(hi_l, ts_g[#ts_g].unit_price / ratio) end
            local cur_l = 0.5 * ((proj[lid] or lo_l) + ((proj[gid] or (lo_l * ratio)) / ratio))
            cur_l = math_max(lo_l, math_min(hi_l, cur_l))
            proj[lid] = cur_l
            proj[gid] = cur_l * ratio
          end
        end
        return proj
      end

      local function dual_supply_constant(pi)
        local total = 0.0
        for iid, _ in pairs(coupled_items) do
          local p_i = pi[iid]
          local ts = supply_map[iid]
          if p_i ~= nil and ts then
            for i = 1, #ts do
              local t = ts[i]
              if (not is_inf(t.max_qty)) and t.unit_price < p_i - EPS then
                total = total + t.max_qty * (t.unit_price - p_i)
              end
            end
          end
        end
        return total
      end

      local function arc_reduced_cost(arc, pi, alpha_split, var_weight, full_unlock_per_arc, forced_open)
        if arc.kind == "gather" then return 0.0 end
        local rec = usable_recipes[arc.spell_id]
        local c_bar = recipe_mkt_cost[arc.spell_id] or 0.0
        local unit_in = 0.0
        for i = 1, #rec.reagents do
          unit_in = unit_in + rec.reagents[i][2] * (pi[rec.reagents[i][1]] or 0.0)
        end
        local retain_tool_id = (rec.produces_tool and arc.tool_out ~= arc.tool_in) and rec.produces_tool[3] or -1

        local inter_credit = 0.0
        local final_sell_unit = 0.0
        for i = 1, #rec.outputs do
          local oid, cnt = rec.outputs[i][1], rec.outputs[i][2]
          local eff_tot = (oid == retain_tool_id) and math_max(0.0, arc.crafts * cnt - 1.0) or (arc.crafts * cnt)
          if inter_items[oid] then
            local p_o = pi[oid] or 0.0
            if is_net then
              local esv = eff_inter_sell[oid] or 0.0
              local rcap = lesser_converts_up[oid] and esv or math_min(esv, (cnt > EPS) and (c_bar / cnt) or 0.0)
              local eff_o = (oid == retain_tool_id) and math_max(0.0, arc.delta_s * cnt - 1.0) or (arc.delta_s * cnt)
              eff_o = math_min(eff_tot, eff_o)
              local ret_o = math_max(0.0, eff_tot - eff_o)
              inter_credit = inter_credit + eff_o * math_max(p_o, esv) + ret_o * math_max(p_o, rcap)
            else
              inter_credit = inter_credit + eff_tot * p_o
            end
          elseif is_net then
            final_sell_unit = final_sell_unit + cnt * (sell_map[oid] or 0.0)
          end
        end

        local craft_rc
        if is_net then
          local final_credit
          if retain_tool_id >= 0 then
            local eff_sold = math_max(0.0, arc.delta_s - 1.0)
            local rem_sold = math_max(0.0, arc.crafts - 1.0 - eff_sold)
            final_credit = eff_sold * final_sell_unit + rem_sold * math_min(final_sell_unit, c_bar)
          else
            local retry_crafts = math_max(0.0, arc.crafts - arc.delta_s)
            final_credit = arc.delta_s * final_sell_unit + retry_crafts * math_min(final_sell_unit, c_bar)
          end
          craft_rc = arc.crafts * unit_in - inter_credit - final_credit
        else
          craft_rc = arc.crafts * unit_in - inter_credit
        end

        local unlock_rc = 0.0
        if rec.unlock_cost_copper > EPS and not (forced_open and forced_open[arc.spell_id]) then
          if full_unlock_per_arc then
            unlock_rc = rec.unlock_cost_copper
          elseif alpha_split and alpha_split[arc.spell_id] then
            local arr = alpha_split[arc.spell_id]
            local lo = rec.min_skill
            for s = arc.s1, arc.s2 - 1 do
              unlock_rc = unlock_rc + arr[s - lo + 1]
            end
          end
        end

        local sw_rc = (arc.s1 > s0) and (recipe_sw_pen[arc.spell_id] or 0.0) or 0.0
        local fp_arr = fail_pen_pref[arc.spell_id]
        local fp_rc = fp_arr and (fp_arr[arc.s2 - rec.min_skill] - fp_arr[arc.s1 - rec.min_skill]) or 0.0
        local var_rc = 0.0
        if var_weight > 0.0 and arc.var_crafts > 0.0 then
          local c_bar = recipe_mkt_cost[arc.spell_id] or 0.0
          local v_out = 0.0
          if is_net then
            for i = 1, #rec.outputs do
              v_out = v_out + rec.outputs[i][2] * (sell_map[rec.outputs[i][1]] or 0.0)
            end
          end
          local eff_u = math_max(0.0, c_bar - v_out)
          var_rc = var_weight * (eff_u * eff_u) * arc.var_crafts
        end
        return craft_rc + unlock_rc + sw_rc + fp_rc + var_rc
      end

      -- 零临时表分配维护 { cost, spell_id, s2, tool_out, crafts, var_crafts, tmid, kind } 前两名
      local function insert_top2_vals(slot, cost, rec_id, s2, tout, crafts, vc, tmid, rkind)
        local n = #slot
        if n == 2 and cost >= slot[2][1] + 1e-9 then
          return
        end
        for i = 1, n do
          local e0 = slot[i]
          if e0[2] == rec_id then
            if cost < e0[1] - 1e-9 or (math_abs(cost - e0[1]) <= 1e-9 and crafts < e0[5] - 1e-9) then
              e0[1], e0[3], e0[4], e0[5], e0[6], e0[7], e0[8] = cost, s2, tout, crafts, vc, tmid, rkind
              if n == 2 and (slot[2][1] < slot[1][1] - 1e-9 or (math_abs(slot[2][1] - slot[1][1]) <= 1e-9 and slot[2][5] < slot[1][5] - 1e-9)) then
                slot[1], slot[2] = slot[2], slot[1]
              end
            end
            return
          end
        end
        if n < 2 then
          slot[n + 1] = { cost, rec_id, s2, tout, crafts, vc, tmid, rkind }
          if n + 1 == 2 and (slot[2][1] < slot[1][1] - 1e-9 or (math_abs(slot[2][1] - slot[1][1]) <= 1e-9 and slot[2][5] < slot[1][5] - 1e-9)) then
            slot[1], slot[2] = slot[2], slot[1]
          end
          return
        end
        if cost < slot[2][1] - 1e-9 or (math_abs(cost - slot[2][1]) <= 1e-9 and crafts < slot[2][5] - 1e-9) then
          local e2 = slot[2]
          e2[1], e2[2], e2[3], e2[4], e2[5], e2[6], e2[7], e2[8] = cost, rec_id, s2, tout, crafts, vc, tmid, rkind
          if slot[2][1] < slot[1][1] - 1e-9 or (math_abs(slot[2][1] - slot[1][1]) <= 1e-9 and slot[2][5] < slot[1][5] - 1e-9) then
            slot[1], slot[2] = slot[2], slot[1]
          end
        end
      end

      local function insert_top2_raw(slot, entry)
        insert_top2_vals(slot, entry[1], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7], entry[8])
      end

      local function build_fast_rc_tables(pi, alpha_split, var_weight, full_unlock_per_arc, forced_open, forced_closed)
        local tables = {}
        for _, sid in ipairs(usable_sids) do
          if not (forced_closed and forced_closed[sid]) then
            local rec = usable_recipes[sid]
            local unit_in = 0.0
            for i = 1, #rec.reagents do
              unit_in = unit_in + rec.reagents[i][2] * (pi[rec.reagents[i][1]] or 0.0)
            end
            local c_bar = recipe_mkt_cost[sid] or unit_in
            local eff_rate, retry_rate
            if is_net then
              local unit_inter_eff, unit_inter_ret, final_sell = 0.0, 0.0, 0.0
              for i = 1, #rec.outputs do
                local oid, cnt = rec.outputs[i][1], rec.outputs[i][2]
                if inter_items[oid] then
                  local p_o = pi[oid] or 0.0
                  local esv = eff_inter_sell[oid] or 0.0
                  local rcap = lesser_converts_up[oid] and esv or math_min(esv, (cnt > EPS) and (c_bar / cnt) or 0.0)
                  unit_inter_eff = unit_inter_eff + cnt * math_max(p_o, esv)
                  unit_inter_ret = unit_inter_ret + cnt * math_max(p_o, rcap)
                else
                  final_sell = final_sell + cnt * (sell_map[oid] or 0.0)
                end
              end
              eff_rate = unit_in - unit_inter_eff - final_sell
              retry_rate = unit_in - unit_inter_ret - math_min(final_sell, c_bar)
            else
              local unit_inter = 0.0
              for i = 1, #rec.outputs do
                local oid, cnt = rec.outputs[i][1], rec.outputs[i][2]
                if inter_items[oid] then
                  unit_inter = unit_inter + cnt * (pi[oid] or 0.0)
                end
              end
              eff_rate = unit_in - unit_inter
              retry_rate = eff_rate
            end
            local v_rate = 0.0
            if var_weight > 0.0 then
              local v_all = 0.0
              if is_net then
                for i = 1, #rec.outputs do
                  v_all = v_all + rec.outputs[i][2] * (sell_map[rec.outputs[i][1]] or 0.0)
                end
              end
              local eff_u = math_max(0.0, c_bar - v_all)
              v_rate = var_weight * (eff_u * eff_u)
            end

            local f_ul = (forced_open and forced_open[sid]) and 0.0 or rec.unlock_cost_copper
            local pref = nil
            if f_ul > EPS and (not full_unlock_per_arc) and alpha_split and alpha_split[sid] then
              local arr = alpha_split[sid]
              pref = { [0] = 0.0 }
              local acc = 0.0
              for idx_a = 1, #arr do
                acc = acc + arr[idx_a]
                pref[idx_a] = acc
              end
            end

            tables[sid] = {
              eff_rate,
              retry_rate,
              v_rate,
              f_ul,
              rec.min_skill,
              pref,
              rec.produces_tool ~= nil,
            }
          end
        end
        return tables
      end

      local function compute_backward_dp(pi, alpha_split, var_weight, full_unlock_per_arc, forced_open, forced_closed)
        local dp = {}
        for s = s0, reached do
          dp[s] = {}
          for st = 0, num_tool_states - 1 do dp[s][st] = {} end
        end
        local tool_mats, tool_acts = compute_all_tool_trans(reached, pi, forced_open, forced_closed)
        local rc_tables = build_fast_rc_tables(pi, alpha_split, var_weight, full_unlock_per_arc, forced_open, forced_closed)

        if not use_step_q then
          local cont_next = {}
          local cont_hist = {}
          for st = 0, num_tool_states - 1 do cont_next[st] = {} end

          for s = reached - 1, s0, -1 do
            if tick and (s % 16 == 0) then tick() end
            local tmat = tool_mats[s]
            local is_after_s0 = (s > s0)
            local direct_row = {}
            local cont_cur = {}
            for st = 0, num_tool_states - 1 do
              direct_row[st] = {}
              cont_cur[st] = {}
            end

            local ge = gather_end_by_s[s]
            if ge then
              local gc = ge - s
              for tin = 0, num_tool_states - 1 do
                local rem_g = (ge == reached) and 0.0 or INF
                if ge < reached then
                  local nslots = dp[ge][tin]
                  for j = 1, #nslots do
                    if nslots[j][2] ~= -186 then rem_g = nslots[j][1]; break end
                  end
                end
                if rem_g < INF * 0.5 then
                  insert_top2_raw(direct_row[tin], { rem_g, -186, ge, tin, gc, 0.0, tin, "gather" })
                end
              end
            end

            local ls = linear_unit_by_s[s]
            for i = 1, #ls do
              local u = ls[i]
              local sid = u[1]
              if (not (forced_closed and forced_closed[sid])) and s >= (cur_min_starts[sid] or 0) then
                local rkind, c1, v1, tp, pbop, req_s2_b = u[2], u[3], u[4], u[5], u[6], u[7]
                local rt = rc_tables[sid]
                local eff_r, ret_r, var_r, f_ul, min_sk, pref_al, has_pt = rt[1], rt[2], rt[3], rt[4], rt[5], rt[6], rt[7]
                local ul_1 = 0.0
                if f_ul > EPS and (not full_unlock_per_arc) and alpha_split and alpha_split[sid] then
                  ul_1 = alpha_split[sid][s - min_sk + 1]
                end
                local fp_arr = fail_pen_pref[sid]
                local fp_1 = fp_arr[s + 1 - min_sk] - fp_arr[s - min_sk]
                local base_rc1 = eff_r + (c1 - 1.0) * ret_r + ul_1 + fp_1 + v1 * var_r
                local sw_here = is_after_s0 and (recipe_sw_pen[sid] or 0.0) or 0.0
                local entry_extra = sw_here + (full_unlock_per_arc and f_ul or 0.0)
                local can_enter_here = s < (cur_entry_caps[sid] or (reached + 1))
                local req_s2 = can_enter_here and req_s2_b or (reached + 1)
                local hi_r = math_min(reached, eff_grey[sid] or reached)

                for k = 1, #tp do
                  local tin, tout = tp[k][1], tp[k][2]
                  local rc1
                  if has_pt and tout ~= tin then
                    local tmp_a = make_seg_arc(sid, rkind, s, s + 1, tin, tout, c1, v1)
                    rc1 = arc_reduced_cost(tmp_a, pi, full_unlock_per_arc and nil or alpha_split, var_weight, false, forced_open) - sw_here
                  else
                    rc1 = base_rc1
                  end

                  local best_c, best_s2, best_tout, best_cr, best_vr
                  if s + 1 == reached then
                    best_c, best_s2, best_tout, best_cr, best_vr = rc1, s + 1, tout, c1, v1
                  else
                    local rem_stop = INF
                    local nslots = dp[s + 1][tout]
                    for j = 1, #nslots do
                      if nslots[j][2] ~= sid then rem_stop = nslots[j][1]; break end
                    end
                    best_c, best_s2, best_tout, best_cr, best_vr = rc1 + rem_stop, s + 1, tout, c1, v1
                  end

                  local dir_c = (s + 1 >= req_s2) and best_c or INF
                  local dir_s2, dir_tout, dir_cr, dir_vr = best_s2, best_tout, best_cr, best_vr

                  if not pbop then
                    local rmax_c = recipe_max_crafts[sid] or math_huge
                    if is_inf(rmax_c) then
                      local st_nxt = cont_next[tout][sid]
                      if st_nxt then
                        local c_stay = rc1 + st_nxt[1]
                        local cr_stay = c1 + st_nxt[4]
                        if c_stay < best_c - 1e-9 or (math_abs(c_stay - best_c) <= 1e-9 and cr_stay < best_cr - 1e-9) then
                          best_c = c_stay
                          best_s2 = st_nxt[2]
                          best_tout = st_nxt[3]
                          best_cr = cr_stay
                          best_vr = v1 + st_nxt[5]
                        end
                      end
                      if req_s2 == s + 1 then
                        dir_c, dir_s2, dir_tout, dir_cr, dir_vr = best_c, best_s2, best_tout, best_cr, best_vr
                      elseif req_s2 <= hi_r then
                        local u_piv = req_s2 - 1
                        local st_piv = cont_hist[u_piv][tout][sid]
                        if st_piv then
                          local cp_arr = crafts_pref[sid]
                          local vp_arr = var_pref[sid]
                          local pref_ds = u_piv - s
                          local pref_cr = cp_arr[u_piv - min_sk] - cp_arr[s - min_sk]
                          local pref_vr = vp_arr[u_piv - min_sk] - vp_arr[s - min_sk]
                          local pref_ul = pref_al and (pref_al[u_piv - min_sk] - pref_al[s - min_sk]) or 0.0
                          local pref_fp = fp_arr[u_piv - min_sk] - fp_arr[s - min_sk]
                          local pref_rc = pref_ds * eff_r + (pref_cr - pref_ds) * ret_r + pref_ul + pref_fp + pref_vr * var_r
                          dir_c = pref_rc + st_piv[1]
                          dir_s2 = st_piv[2]
                          dir_tout = st_piv[3]
                          dir_cr = pref_cr + st_piv[4]
                          dir_vr = pref_vr + st_piv[5]
                        end
                      end
                    else
                      local rec_obj = usable_recipes[sid]
                      local acc_rc, acc_cr, acc_vr = rc1, c1, v1
                      for s_nxt = s + 1, hi_r - 1 do
                        local p_n = M.skill_up_prob(rec_obj, s_nxt)
                        if p_n <= 0.0 then break end
                        local cn = 1.0 / p_n
                        if acc_cr + cn > rmax_c + EPS then break end
                        local vn = (1.0 - p_n) / (p_n * p_n)
                        local ul_n = 0.0
                        if f_ul > EPS and (not full_unlock_per_arc) and alpha_split and alpha_split[sid] then
                          ul_n = alpha_split[sid][s_nxt - min_sk + 1]
                        end
                        local fp_n = fp_arr[s_nxt + 1 - min_sk] - fp_arr[s_nxt - min_sk]
                        acc_rc = acc_rc + eff_r + (cn - 1.0) * ret_r + ul_n + fp_n + vn * var_r
                        acc_cr = acc_cr + cn
                        acc_vr = acc_vr + vn
                        local s_end2 = s_nxt + 1
                        local rem2 = (s_end2 == reached) and 0.0 or INF
                        if s_end2 < reached then
                          local ns2 = dp[s_end2][tout]
                          for j = 1, #ns2 do
                            if ns2[j][2] ~= sid then rem2 = ns2[j][1]; break end
                          end
                        end
                        local tot2 = acc_rc + rem2
                        if tot2 < best_c - 1e-9 or (math_abs(tot2 - best_c) <= 1e-9 and acc_cr < best_cr - 1e-9) then
                          best_c = tot2
                          best_s2 = s_end2
                          best_tout = tout
                          best_cr = acc_cr
                          best_vr = acc_vr
                        end
                        if s_end2 >= req_s2 and (tot2 < dir_c - 1e-9 or (math_abs(tot2 - dir_c) <= 1e-9 and acc_cr < dir_cr - 1e-9)) then
                          dir_c = tot2
                          dir_s2 = s_end2
                          dir_tout = tout
                          dir_cr = acc_cr
                          dir_vr = acc_vr
                        end
                      end
                    end
                  end

                  if best_c < INF * 0.5 then
                    cont_cur[tin][sid] = { best_c, best_s2, best_tout, best_cr, best_vr }
                  end
                  if can_enter_here and dir_c < INF * 0.5 then
                    insert_top2_vals(direct_row[tin], dir_c + entry_extra, sid, dir_s2, dir_tout, dir_cr, dir_vr, tin, rkind)
                  end
                end
              end
            end

            if num_tool_states == 1 then
              dp[s][0] = direct_row[0]
            else
              for tin = 0, num_tool_states - 1 do
                local trow = tmat[tin]
                local dst = dp[s][tin]
                for tmid = 0, num_tool_states - 1 do
                  local tc = trow[tmid]
                  if tc < INF * 0.5 then
                    local dr = direct_row[tmid]
                    for j = 1, #dr do
                      local d = dr[j]
                      insert_top2_vals(dst, tc + d[1], d[2], d[3], d[4], d[5], d[6], tmid, d[8])
                    end
                  end
                end
              end
            end
            cont_hist[s] = cont_cur
            if s + min_seg <= reached then
              cont_hist[s + min_seg] = nil
            end
            cont_next = cont_cur
          end
          return dp, tool_mats, tool_acts
        end

        -- step_quantile 工具去重段扫描
        for s = reached - 1, s0, -1 do
          local tmat = tool_mats[s]
          local is_after_s0 = (s > s0)
          local direct_row = {}
          for st = 0, num_tool_states - 1 do direct_row[st] = {} end

          local ge = gather_end_by_s[s]
          if ge then
            local gc = ge - s
            for tin = 0, num_tool_states - 1 do
              local rem_g = (ge == reached) and 0.0 or INF
              if ge < reached then
                local nslots = dp[ge][tin]
                for j = 1, #nslots do
                  if nslots[j][2] ~= -186 then rem_g = nslots[j][1]; break end
                end
              end
              if rem_g < INF * 0.5 then
                insert_top2_vals(direct_row[tin], rem_g, -186, ge, tin, gc, 0.0, tin, "gather")
              end
            end
          end

          local gs = sq_groups_by_s1[s]
          for i = 1, #gs do
            local g = gs[i]
            local sid = g[1]
            local s1 = g[3]
            if (not (forced_closed and forced_closed[sid]))
              and s1 >= (cur_min_starts[sid] or 0)
              and s1 < (cur_entry_caps[sid] or (reached + 1)) then
              local rkind, s2, crafts, vc, ds, tp = g[2], g[4], g[5], g[6], g[7], g[8]
              local rt = rc_tables[sid]
              local eff_r, ret_r, var_r, f_ul, min_sk, pref, has_pt = rt[1], rt[2], rt[3], rt[4], rt[5], rt[6], rt[7]
              local ul_c = 0.0
              if f_ul > EPS then
                if full_unlock_per_arc then
                  ul_c = f_ul
                elseif pref then
                  ul_c = pref[s2 - min_sk] - pref[s1 - min_sk]
                end
              end
              local fp_arr = fail_pen_pref[sid]
              local fp_c = fp_arr[s2 - min_sk] - fp_arr[s1 - min_sk]
              local sw_here = is_after_s0 and (recipe_sw_pen[sid] or 0.0) or 0.0
              local shared_rc = ds * eff_r + (crafts - ds) * ret_r + ul_c + fp_c + sw_here + vc * var_r

              for k = 1, #tp do
                local tin, tout = tp[k][1], tp[k][2]
                local rem_cost = (s2 == reached) and 0.0 or INF
                if s2 < reached then
                  local nslots = dp[s2][tout]
                  for j = 1, #nslots do
                    if nslots[j][2] ~= sid then rem_cost = nslots[j][1]; break end
                  end
                end
                if rem_cost < INF * 0.5 then
                  local rc_val
                  if has_pt and tout ~= tin then
                    local tmp_a = make_seg_arc(sid, rkind, s1, s2, tin, tout, crafts, vc)
                    rc_val = arc_reduced_cost(tmp_a, pi, alpha_split, var_weight, full_unlock_per_arc, forced_open)
                  else
                    rc_val = shared_rc
                  end
                  insert_top2_vals(direct_row[tin], rc_val + rem_cost, sid, s2, tout, crafts, vc, tin, rkind)
                end
              end
            end
          end

          if num_tool_states == 1 then
            dp[s][0] = direct_row[0]
          else
            for tin = 0, num_tool_states - 1 do
              local trow = tmat[tin]
              local dst = dp[s][tin]
              for tmid = 0, num_tool_states - 1 do
                local tc = trow[tmid]
                if tc < INF * 0.5 then
                  local dr = direct_row[tmid]
                  for j = 1, #dr do
                    local d = dr[j]
                    insert_top2_vals(dst, tc + d[1], d[2], d[3], d[4], d[5], d[6], tmid, d[8])
                  end
                end
              end
            end
          end
        end
        return dp, tool_mats, tool_acts
      end

      local function extract_path_from_dp(dp, tool_acts, start_s, start_tool, prev_spell, first_choice)
        local arcs = {}
        local t_actions = {}
        local cur_s = start_s
        local cur_t = start_tool
        local last_spell = prev_spell

        if first_choice then
          local f_arc, f_tmid = first_choice[1], first_choice[2]
          local acts = tool_acts[cur_s][cur_t][f_tmid]
          for i = 1, #acts do t_actions[#t_actions + 1] = { cur_s, acts[i][1], acts[i][2] } end
          arcs[#arcs + 1] = f_arc
          cur_s = f_arc.s2
          cur_t = f_arc.tool_out
          last_spell = f_arc.spell_id
        end

        while cur_s < reached do
          local slots = dp[cur_s][cur_t]
          local chosen = nil
          for i = 1, #slots do
            if slots[i][2] ~= last_spell then
              chosen = slots[i]
              break
            end
          end
          if not chosen then return nil end
          local sid, s2, tout, crafts, vc, tmid, rkind = chosen[2], chosen[3], chosen[4], chosen[5], chosen[6], chosen[7], chosen[8]
          local acts = tool_acts[cur_s][cur_t][tmid]
          for i = 1, #acts do t_actions[#t_actions + 1] = { cur_s, acts[i][1], acts[i][2] } end
          arcs[#arcs + 1] = make_seg_arc(sid, rkind, cur_s, s2, tmid, tout, crafts, vc)
          last_spell = sid
          cur_s = s2
          cur_t = tout
        end
        return arcs, t_actions
      end

      local function aggregate_shopping(items)
        local by_key = {}
        local keys = {}
        for i = 1, #items do
          local it = items[i]
          local k = tostring(it.item_id) .. "|" .. it.source
          local acc = by_key[k]
          if not acc then
            acc = { item_id = it.item_id, source = it.source, q = 0.0, c = 0.0 }
            by_key[k] = acc
            keys[#keys + 1] = k
          end
          acc.q = acc.q + it.quantity
          acc.c = acc.c + it.total_cost_copper
        end
        table_sort(keys, function(ka, kb)
          local a, b = by_key[ka], by_key[kb]
          if a.item_id ~= b.item_id then return a.item_id < b.item_id end
          return a.source < b.source
        end)
        local out = {}
        for i = 1, #keys do
          local acc = by_key[keys[i]]
          out[#out + 1] = {
            item_id = acc.item_id,
            quantity = acc.q,
            planned_quantity = math_ceil(acc.q - 1e-9),
            total_cost_copper = acc.c,
            unit_price_avg = (acc.q > EPS) and (acc.c / acc.q) or 0.0,
            source = acc.source,
          }
        end
        return out
      end

      local function evaluate_primal(arcs, tool_actions, var_weight, forced_closed)
        if enforce_no_repeat_active and has_terminal_repeat(arcs) then
          return nil
        end
        var_weight = var_weight or 0.0
        local sorted_ta = {}
        for i = 1, #tool_actions do sorted_ta[i] = tool_actions[i] end
        table_sort(sorted_ta, function(a, b) return a[1] < b[1] end)

        local stages = {}
        local ta_idx = 1
        local cur_tool_state = init_tool_state
        local retained_set = {}

        for i = 1, #arcs do
          local arc = arcs[i]
          while ta_idx <= #sorted_ta and sorted_ta[ta_idx][1] <= arc.s1 do
            local ta = sorted_ta[ta_idx]
            ta_idx = ta_idx + 1
            local at_s, akind, aid = ta[1], ta[2], ta[3]
            if akind == "tool_buy" then
              stages[#stages + 1] = { at_s, "tool_buy", aid, 1.0, 0, aid }
              retained_set[aid] = true
              for u = 1, #tool_buy_actions do
                if tool_buy_actions[u][3] == aid then
                  cur_tool_state = tool_upgrade(cur_tool_state, tool_buy_actions[u][1], tool_buy_actions[u][2])
                end
              end
            elseif akind == "tool_craft" then
              local trec = usable_recipes[aid]
              local tout_id = trec.produces_tool and trec.produces_tool[3] or -1
              stages[#stages + 1] = { at_s, "tool_craft", aid, 1.0, 0, tout_id }
              if tout_id > 0 then retained_set[tout_id] = true end
              if trec.produces_tool and cat_index[trec.produces_tool[1]] then
                cur_tool_state = tool_upgrade(cur_tool_state, cat_index[trec.produces_tool[1]], trec.produces_tool[2])
              end
            end
          end

          local retain_id = -1
          if arc.kind ~= "gather" then
            local rec = usable_recipes[arc.spell_id]
            if rec.produces_tool and arc.tool_out ~= cur_tool_state then
              retain_id = rec.produces_tool[3]
              retained_set[retain_id] = true
            end
          end
          cur_tool_state = arc.tool_out
          stages[#stages + 1] = { arc.s1, arc.kind, arc.spell_id, arc.crafts, arc.delta_s, retain_id }
        end

        local unlocked_spells = {}
        for i = 1, #stages do
          local st = stages[i]
          local sid = st[3]
          if (st[2] == "craft" or st[2] == "tool_craft") and sid > 0 then
            local urec = usable_recipes[sid]
            if (not p_ctx.known_recipes[sid]) and (not p_ctx.known_recipes[tostring(sid)])
              and urec.learn_kind ~= "autoGrant"
              and (urec.unlock_cost_copper > EPS or urec.teaching_item_id ~= nil) then
              unlocked_spells[sid] = true
            end
          end
        end

        local inv = {}
        local mutable_stage_defs = {}
        local final_sell_credit = 0.0
        local final_sold_by_item = {}
        local inter_excess_caps = {}

        for i = 1, #stages do
          local st = stages[i]
          local st_skill, skind, sid, crafts, delta_s, retain_id = st[1], st[2], st[3], st[4], st[5], st[6]
          if skind == "tool_buy" then
            local avail = inv[sid] or 0.0
            local use_inv = math_min(avail, 1.0)
            if use_inv > EPS then inv[sid] = avail - use_inv end
            local rem = 1.0 - use_inv
            if rem > EPS then
              mutable_stage_defs[#mutable_stage_defs + 1] = { st_skill, { [sid] = rem } }
            end
          elseif skind ~= "gather" then
            local rec = usable_recipes[sid]
            local st_def = {}
            local has_def = false
            for j = 1, #rec.reagents do
              local rg_id, rg_cnt = rec.reagents[j][1], rec.reagents[j][2]
              local req = crafts * rg_cnt
              local avail = inv[rg_id] or 0.0
              local use_inv = math_min(avail, req)
              if use_inv > EPS then
                inv[rg_id] = avail - use_inv
                req = req - use_inv
              end
              if req > EPS then
                st_def[rg_id] = (st_def[rg_id] or 0.0) + req
                has_def = true
              end
            end
            if has_def then
              mutable_stage_defs[#mutable_stage_defs + 1] = { st_skill, st_def }
            end

            local c_bar = recipe_mkt_cost[sid] or 0.0
            local final_unit_val = 0.0
            for j = 1, #rec.outputs do
              local oid, ocnt = rec.outputs[j][1], rec.outputs[j][2]
              if oid ~= retain_id and not inter_items[oid] then
                final_unit_val = final_unit_val + ocnt * (sell_map[oid] or 0.0)
              end
            end
            local retry_crafts = math_max(0.0, crafts - delta_s)

            for j = 1, #rec.outputs do
              local out_id, out_cnt = rec.outputs[j][1], rec.outputs[j][2]
              local produced = (out_id == retain_id) and math_max(0.0, crafts * out_cnt - 1.0) or (crafts * out_cnt)
              if produced > EPS then
                if inter_items[out_id] then
                  inv[out_id] = (inv[out_id] or 0.0) + produced
                  if is_net and retry_crafts > EPS and out_cnt > EPS then
                    local sv_o = sell_map[out_id] or 0.0
                    local unit_cap = c_bar / out_cnt
                    if sv_o > unit_cap + EPS then
                      inter_excess_caps[#inter_excess_caps + 1] = { out_id, retry_crafts * out_cnt, sv_o - unit_cap }
                    end
                  end
                elseif is_net and out_id > 0 then
                  local sv_o = sell_map[out_id] or 0.0
                  if sv_o > 0.0 then
                    local raw_rev = produced * sv_o
                    local capped_rev = raw_rev
                    if final_unit_val > c_bar + EPS and skind == "craft" then
                      if out_id == retain_id then
                        local eff_sold = math_max(0.0, delta_s * out_cnt - 1.0)
                        local rem_sold = math_max(0.0, produced - eff_sold)
                        capped_rev = eff_sold * sv_o + rem_sold * math_min(sv_o, c_bar / out_cnt)
                      else
                        local share = (out_cnt * sv_o) / final_unit_val
                        capped_rev = delta_s * out_cnt * sv_o + retry_crafts * c_bar * share
                      end
                    end
                    final_sell_credit = final_sell_credit + capped_rev
                    local acc = final_sold_by_item[out_id]
                    if not acc then
                      acc = { 0.0, 0.0 }
                      final_sold_by_item[out_id] = acc
                    end
                    acc[1] = acc[1] + produced
                    acc[2] = acc[2] + raw_rev
                  end
                end
              end
            end
          end
        end

        -- 逆拓扑灰字半成品自制决策
        local subcrafts_executed = {}
        for idx = #item_topo, 1, -1 do
          local iid = item_topo[idx]
          local prods = producers_by_item[iid]
          if prods and not essence_by_item[iid] then
            local tot_q = 0.0
            for u = 1, #mutable_stage_defs do
              tot_q = tot_q + (mutable_stage_defs[u][2][iid] or 0.0)
            end
            if tot_q > EPS then
              local ext_tiers = supply_map[iid] or {}
              local ext_full_cost, ext_ok = eval_tier_cost(ext_tiers, tot_q)
              local best_est = ext_ok and ext_full_cost or INF
              local chosen_rec, chosen_batches = nil, 0.0

              for p = 1, #prods do
                local rec = prods[p]
                if not (forced_closed and forced_closed[rec.spell_id]) then
                  local out_net = 0.0
                  for j = 1, #rec.outputs do
                    if rec.outputs[j][1] == iid then out_net = out_net + rec.outputs[j][2] end
                  end
                  for j = 1, #rec.reagents do
                    if rec.reagents[j][1] == iid then out_net = out_net - rec.reagents[j][2] end
                  end
                  if out_net > EPS then
                    local craftable_q = 0.0
                    for u = 1, #mutable_stage_defs do
                      if mutable_stage_defs[u][1] >= rec.min_skill then
                        craftable_q = craftable_q + (mutable_stage_defs[u][2][iid] or 0.0)
                      end
                    end
                    if craftable_q > EPS then
                      local _, nc_ok = eval_tier_cost(ext_tiers, tot_q - craftable_q)
                      if nc_ok then
                        local is_free_ul = unlocked_spells[rec.spell_id]
                          or p_ctx.known_recipes[rec.spell_id]
                          or p_ctx.known_recipes[tostring(rec.spell_id)]
                          or rec.unlock_cost_copper <= EPS
                        local extra_unlock = is_free_ul and 0.0 or rec.unlock_cost_copper
                        local cand_set = {}
                        local max_b = math_ceil((craftable_q - EPS) / out_net)
                        if max_b > 0 then cand_set[max_b] = true end
                        local fl_b = math_floor((craftable_q + EPS) / out_net)
                        if fl_b > 0 then cand_set[fl_b] = true end
                        local acc_ext = 0.0
                        for t = 1, #ext_tiers do
                          if is_inf(ext_tiers[t].max_qty) then break end
                          acc_ext = acc_ext + ext_tiers[t].max_qty
                          local rem_m = tot_q - acc_ext
                          if rem_m > EPS and rem_m <= craftable_q + EPS then
                            local bu = math_ceil((rem_m - EPS) / out_net)
                            local bd = math_floor((rem_m + EPS) / out_net)
                            if bu > 0 then cand_set[bu] = true end
                            if bd > 0 then cand_set[bd] = true end
                          end
                        end

                        for _, batches_int in ipairs(sorted_keys(cand_set)) do
                          local produced_q = batches_int * out_net
                          local used_q = math_min(craftable_q, produced_q)
                          local surplus_q = math_max(0.0, produced_q - used_q)
                          local ec, eok = eval_tier_cost(ext_tiers, tot_q - used_q)
                          if eok then
                            local rc_sum = 0.0
                            local rok = true
                            for j = 1, #rec.reagents do
                              local rg_id, rg_cnt = rec.reagents[j][1], rec.reagents[j][2]
                              if rg_id ~= iid then
                                local rg_ts = supply_map[rg_id] or {}
                                if #rg_ts > 0 then
                                  local c_rg, ok_rg = eval_tier_cost(rg_ts, batches_int * rg_cnt)
                                  if ok_rg then
                                    rc_sum = rc_sum + c_rg
                                  else
                                    local est_p = base_acq_price[rg_id] or INF
                                    if est_p >= INF * 0.5 then rok = false; break end
                                    rc_sum = rc_sum + batches_int * rg_cnt * est_p
                                  end
                                else
                                  local est_p = base_acq_price[rg_id] or INF
                                  if est_p >= INF * 0.5 then rok = false; break end
                                  rc_sum = rc_sum + batches_int * rg_cnt * est_p
                                end
                              end
                            end
                            if rok then
                              local sur_cred = is_net and (surplus_q * math_min(sell_map[iid] or 0.0, mkt_ref_price[iid] or 0.0)) or 0.0
                              local tot_est = ec + extra_unlock + rc_sum - sur_cred
                              if tot_est < best_est - EPS then
                                best_est = tot_est
                                chosen_rec = rec
                                chosen_batches = batches_int
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end

              if chosen_rec and chosen_batches > EPS then
                if (not p_ctx.known_recipes[chosen_rec.spell_id]) and (not p_ctx.known_recipes[tostring(chosen_rec.spell_id)])
                  and chosen_rec.learn_kind ~= "autoGrant"
                  and (chosen_rec.unlock_cost_copper > EPS or chosen_rec.teaching_item_id ~= nil) then
                  unlocked_spells[chosen_rec.spell_id] = true
                end
                local out_net = 0.0
                for j = 1, #chosen_rec.outputs do
                  if chosen_rec.outputs[j][1] == iid then out_net = out_net + chosen_rec.outputs[j][2] end
                end
                for j = 1, #chosen_rec.reagents do
                  if chosen_rec.reagents[j][1] == iid then out_net = out_net - chosen_rec.reagents[j][2] end
                end
                local rem_prod = chosen_batches * out_net
                for u = #mutable_stage_defs, 1, -1 do
                  local sk, df = mutable_stage_defs[u][1], mutable_stage_defs[u][2]
                  if sk >= chosen_rec.min_skill then
                    local cur_need = df[iid] or 0.0
                    if cur_need > EPS and rem_prod > EPS then
                      local cover = math_min(cur_need, rem_prod)
                      df[iid] = cur_need - cover
                      rem_prod = rem_prod - cover
                    end
                  end
                end
                local target_idx = -1
                for u = 1, #mutable_stage_defs do
                  if mutable_stage_defs[u][1] >= chosen_rec.min_skill then
                    target_idx = u
                    break
                  end
                end
                if target_idx >= 1 then
                  local sk_exec, df_exec = mutable_stage_defs[target_idx][1], mutable_stage_defs[target_idx][2]
                  subcrafts_executed[#subcrafts_executed + 1] = { sk_exec, chosen_rec.spell_id, chosen_batches }
                  for j = 1, #chosen_rec.reagents do
                    local rg_id, rg_cnt = chosen_rec.reagents[j][1], chosen_rec.reagents[j][2]
                    if rg_id ~= iid then df_exec[rg_id] = (df_exec[rg_id] or 0.0) + chosen_batches * rg_cnt end
                  end
                  for j = 1, #chosen_rec.outputs do
                    local oid, ocnt = chosen_rec.outputs[j][1], chosen_rec.outputs[j][2]
                    if oid ~= iid then inv[oid] = (inv[oid] or 0.0) + chosen_batches * ocnt end
                  end
                  if rem_prod > EPS then
                    inv[iid] = (inv[iid] or 0.0) + rem_prod
                    if is_net then
                      local sv_i = sell_map[iid] or 0.0
                      local mc_i = mkt_ref_price[iid] or 0.0
                      if sv_i > mc_i + EPS then
                        inter_excess_caps[#inter_excess_caps + 1] = { iid, rem_prod, sv_i - mc_i }
                      end
                    end
                  end
                end
              end
            end
          end
        end

        local total_deficit = {}
        for u = 1, #mutable_stage_defs do
          for iid, q in pairs(mutable_stage_defs[u][2]) do
            if q > EPS then total_deficit[iid] = (total_deficit[iid] or 0.0) + q end
          end
        end

        local essence_conversions_used = {}
        local handled_essence = {}
        local purchases = {}
        local owned_used = {}
        local gross_buy_cost = 0.0
        local owned_opp_cost = 0.0

        local function allocate_from_tiers(iid, qty)
          if qty <= EPS then return true end
          local ts = supply_map[iid] or {}
          local rem = qty
          for i = 1, #ts do
            local t = ts[i]
            local take = is_inf(t.max_qty) and rem or math_min(rem, t.max_qty)
            if take > EPS then
              rem = rem - take
              local real_id = t.real_item_id or iid
              local c_here = take * t.unit_price
              if t.source == "owned" then
                owned_opp_cost = owned_opp_cost + c_here
                owned_used[#owned_used + 1] = { item_id = real_id, quantity = take, total_cost_copper = c_here, source = "owned" }
              else
                gross_buy_cost = gross_buy_cost + c_here
                purchases[#purchases + 1] = { item_id = real_id, quantity = take, total_cost_copper = c_here, source = t.source }
              end
              if rem <= EPS then return true end
            end
          end
          return false
        end

        for i = 1, #(problem.essence_pairs or {}) do
          local ep = problem.essence_pairs[i]
          local lid, gid, ratio = ep.lesser_item_id, ep.greater_item_id, ep.ratio
          local def_l = total_deficit[lid] or 0.0
          local def_g = total_deficit[gid] or 0.0
          local sur_l = inv[lid] or 0.0
          local sur_g = inv[gid] or 0.0
          if def_l + def_g + sur_l + sur_g > EPS then
            handled_essence[lid] = true
            handled_essence[gid] = true
            local net_unit_def = (def_l + ratio * def_g) - (sur_l + ratio * sur_g)
            if net_unit_def > EPS then
              inv[lid], inv[gid] = 0.0, 0.0
              local comb = {}
              local ts_l = supply_map[lid] or {}
              local ts_g = supply_map[gid] or {}
              for j = 1, #ts_l do comb[#comb + 1] = { ts_l[j].unit_price, ts_l[j].max_qty, 1, ts_l[j] } end
              for j = 1, #ts_g do
                local cap_u = is_inf(ts_g[j].max_qty) and math_huge or (ts_g[j].max_qty * ratio)
                comb[#comb + 1] = { ts_g[j].unit_price / ratio, cap_u, ratio, ts_g[j] }
              end
              table_sort(comb, function(a, b) return a[1] < b[1] end)

              local rem_u, bought_l, bought_g = net_unit_def, 0.0, 0.0
              for j = 1, #comb do
                local cap_u, mult, orig_t = comb[j][2], comb[j][3], comb[j][4]
                local take_u = is_inf(cap_u) and rem_u or math_min(rem_u, cap_u)
                if take_u > EPS then
                  rem_u = rem_u - take_u
                  local item_qty = take_u / mult
                  local real_id = orig_t.real_item_id or ((mult == ratio) and gid or lid)
                  if mult == ratio then bought_g = bought_g + item_qty else bought_l = bought_l + item_qty end
                  local c_here = item_qty * orig_t.unit_price
                  if orig_t.source == "owned" then
                    owned_opp_cost = owned_opp_cost + c_here
                    owned_used[#owned_used + 1] = { item_id = real_id, quantity = item_qty, total_cost_copper = c_here, source = "owned" }
                  else
                    gross_buy_cost = gross_buy_cost + c_here
                    purchases[#purchases + 1] = { item_id = real_id, quantity = item_qty, total_cost_copper = c_here, source = orig_t.source }
                  end
                  if rem_u <= EPS then break end
                end
              end
              if rem_u > EPS then return nil end
              if bought_g + sur_g > def_g + EPS then
                local cc = math_ceil((bought_g + sur_g - def_g) - 1e-9)
                if cc > 0 then essence_conversions_used[#essence_conversions_used + 1] = { gid, lid, cc } end
              elseif bought_l + sur_l > def_l + EPS then
                local cc = math_ceil(((bought_l + sur_l - def_l) / ratio) - 1e-9)
                if cc > 0 then essence_conversions_used[#essence_conversions_used + 1] = { lid, gid, cc } end
              end
            else
              local surplus_u = -net_unit_def
              local sell_l = sell_map[lid] or 0.0
              local sell_g = sell_map[gid] or 0.0
              if is_net and sell_g > sell_l * ratio + EPS and surplus_u >= ratio then
                local g_cnt = math_floor((surplus_u + 1e-9) / ratio)
                inv[gid] = g_cnt
                inv[lid] = math_max(0.0, surplus_u - g_cnt * ratio)
              else
                inv[lid] = surplus_u
                inv[gid] = 0.0
              end
            end
          end
        end

        for _, iid in ipairs(sorted_keys(total_deficit)) do
          if not handled_essence[iid] then
            if not allocate_from_tiers(iid, total_deficit[iid]) then return nil end
          end
        end

        local unlock_cost_total = 0.0
        local unlocked_list = sorted_keys(unlocked_spells)
        for i = 1, #unlocked_list do
          local sid = unlocked_list[i]
          local rec = usable_recipes[sid]
          if rec.unlock_cost_copper > EPS then
            unlock_cost_total = unlock_cost_total + rec.unlock_cost_copper
            if rec.teaching_item_id then
              purchases[#purchases + 1] = {
                item_id = rec.teaching_item_id,
                quantity = 1.0,
                total_cost_copper = rec.unlock_cost_copper,
                source = "recipe_item",
              }
            end
          end
        end

        local gross_cost = gross_buy_cost + unlock_cost_total
        local sold_list = {}
        local raw_final_rev = 0.0
        for _, iid in ipairs(sorted_keys(final_sold_by_item)) do
          local acc = final_sold_by_item[iid]
          raw_final_rev = raw_final_rev + acc[2]
          sold_list[#sold_list + 1] = {
            item_id = iid,
            quantity = acc[1],
            unit_sell_value = sell_map[iid] or 0.0,
            total_revenue_copper = acc[2],
          }
        end

        local inter_sell_raw = 0.0
        local inter_excess_deduct = 0.0
        local rem_inter_unsold = {}
        for _, iid in ipairs(sorted_keys(inv)) do
          local qty = inv[iid]
          rem_inter_unsold[iid] = qty
          if qty > EPS and iid > 0 and is_net then
            local sv = sell_map[iid] or 0.0
            if sv > 0.0 then
              local rev = qty * sv
              inter_sell_raw = inter_sell_raw + rev
              sold_list[#sold_list + 1] = {
                item_id = iid,
                quantity = qty,
                unit_sell_value = sv,
                total_revenue_copper = rev,
              }
            end
          end
        end
        if is_net then
          for i = 1, #inter_excess_caps do
            local iid, ex_q, ex_prof = inter_excess_caps[i][1], inter_excess_caps[i][2], inter_excess_caps[i][3]
            local uleft = rem_inter_unsold[iid] or 0.0
            if uleft > EPS then
              local clip = math_min(uleft, ex_q)
              inter_excess_deduct = inter_excess_deduct + clip * ex_prof
              rem_inter_unsold[iid] = uleft - clip
            end
          end
        end
        table_sort(sold_list, function(a, b) return a.item_id < b.item_id end)

        local raw_sell_revenue = is_net and (raw_final_rev + inter_sell_raw) or 0.0
        local capped_sell_credit = is_net and (final_sell_credit + inter_sell_raw - inter_excess_deduct) or 0.0
        local raw_net_spend = gross_cost + owned_opp_cost - raw_sell_revenue
        local anti_farm_net_spend = gross_cost + owned_opp_cost - capped_sell_credit

        local sw_cost = 0.0
        local fail_pen_cost = 0.0
        local gross_var = 0.0
        local net_var = 0.0
        for i = 1, #arcs do
          local a = arcs[i]
          if a.kind ~= "gather" then
            if a.s1 > s0 then sw_cost = sw_cost + (recipe_sw_pen[a.spell_id] or 0.0) end
            local rec = usable_recipes[a.spell_id]
            local fp_arr = fail_pen_pref[a.spell_id]
            if fp_arr then
              fail_pen_cost = fail_pen_cost + (fp_arr[a.s2 - rec.min_skill] - fp_arr[a.s1 - rec.min_skill])
            end
            if a.var_crafts > 0.0 then
              local c_bar = recipe_mkt_cost[a.spell_id] or 0.0
              local u_out_all = 0.0
              for j = 1, #rec.outputs do
                u_out_all = u_out_all + rec.outputs[j][2] * (sell_map[rec.outputs[j][1]] or 0.0)
              end
              local eff_net = math_max(0.0, c_bar - u_out_all)
              gross_var = gross_var + (c_bar * c_bar) * a.var_crafts
              net_var = net_var + (eff_net * eff_net) * a.var_crafts
            end
          end
        end

        local route_var = is_net and net_var or gross_var
        local reg_cost = sw_cost + fail_pen_cost
        local real_obj = is_net and anti_farm_net_spend or gross_cost
        local internal_obj = real_obj + reg_cost + var_weight * route_var

        return {
          internal_obj = internal_obj,
          real_obj = real_obj,
          reg_cost = reg_cost,
          gross_cost = gross_cost,
          sell_revenue = raw_sell_revenue,
          raw_net_spend = raw_net_spend,
          anti_farm_net_spend = anti_farm_net_spend,
          owned_opp_cost = owned_opp_cost,
          unlock_cost = unlock_cost_total,
          route_var = route_var,
          gross_var = gross_var,
          net_var = net_var,
          arcs = arcs,
          tool_actions = sorted_ta,
          subcrafts = subcrafts_executed,
          essence_conversions = essence_conversions_used,
          purchases = aggregate_shopping(purchases),
          owned_used = aggregate_shopping(owned_used),
          sold = sold_list,
          retained_tools = sorted_keys(retained_set),
          unlocked_recipes = unlocked_list,
        }
      end

      local function path_signature(arcs, tools)
        local parts = {}
        for i = 1, #arcs do parts[#parts + 1] = tostring(arcs[i].arc_id) end
        parts[#parts + 1] = "#"
        for i = 1, #tools do parts[#parts + 1] = tostring(tools[i][3]) end
        return table.concat(parts, ",")
      end

      local function copy_set(s, add_k)
        local out = {}
        if s then for k, v in pairs(s) do out[k] = v end end
        if add_k ~= nil then out[add_k] = true end
        return out
      end

      local function marginal_supply_price(iid, demand_qty)
        local ts = supply_map[iid]
        if not ts or #ts == 0 then return INF end
        if demand_qty <= EPS then return ts[1].unit_price end
        local acc = 0.0
        for i = 1, #ts do
          local t = ts[i]
          if is_inf(t.max_qty) then return t.unit_price end
          acc = acc + t.max_qty
          if acc >= demand_qty - EPS then return t.unit_price end
        end
        return ts[#ts].unit_price
      end

      local function marginal_essence_unit_price(ep, demand_u)
        local lid, gid, ratio = ep.lesser_item_id, ep.greater_item_id, ep.ratio
        local comb = {}
        local ts_l = supply_map[lid] or {}
        local ts_g = supply_map[gid] or {}
        for i = 1, #ts_l do comb[#comb + 1] = { ts_l[i].unit_price, ts_l[i].max_qty } end
        for i = 1, #ts_g do
          local cap_u = is_inf(ts_g[i].max_qty) and math_huge or (ts_g[i].max_qty * ratio)
          comb[#comb + 1] = { ts_g[i].unit_price / ratio, cap_u }
        end
        if #comb == 0 then return INF end
        table_sort(comb, function(a, b) return a[1] < b[1] end)
        if demand_u <= EPS then return comb[1][1] end
        local acc = 0.0
        for i = 1, #comb do
          local up, cap_u = comb[i][1], comb[i][2]
          if is_inf(cap_u) then return up end
          acc = acc + cap_u
          if acc >= demand_u - EPS then return up end
        end
        return comb[#comb][1]
      end

      local function run_lagrangian_bound(var_weight, forced_open, forced_closed, max_iters, seen_paths, g_ref, init_pi)
        local open_const = 0.0
        if forced_open then
          for sid, _ in pairs(forced_open) do
            open_const = open_const + usable_recipes[sid].unlock_cost_copper
          end
        end

        local alpha_split = {}
        for _, sid in ipairs(usable_sids) do
          if not ((forced_open and forced_open[sid]) or (forced_closed and forced_closed[sid])) then
            local rec = usable_recipes[sid]
            if rec.unlock_cost_copper > EPS and rec.grey and rec.grey > rec.min_skill then
              local eff_lo = math_max(s0, rec.min_skill)
              local eff_hi = math_min(reached, eff_grey[sid] or rec.grey)
              local span = rec.grey - rec.min_skill
              local arr = {}
              for u = 1, span do arr[u] = 0.0 end
              if eff_hi > eff_lo then
                local u_val = rec.unlock_cost_copper / (eff_hi - eff_lo)
                for s = eff_lo, eff_hi - 1 do
                  arr[s - rec.min_skill + 1] = u_val
                end
              else
                arr[1] = rec.unlock_cost_copper
              end
              alpha_split[sid] = arr
            end
          end
        end

        local mkt_seed = {}
        local low_seed = {}
        for i = 1, #item_topo do
          local iid = item_topo[i]
          local ep_v = ext_only_price[iid]
          mkt_seed[iid] = (ep_v and ep_v < INF * 0.5) and ep_v or (base_acq_price[iid] or 0.0)
          if inter_items[iid] then
            low_seed[iid] = 0.0
          else
            low_seed[iid] = base_acq_price[iid] or 0.0
          end
        end
        local pi_ext = project_shadow_prices(mkt_seed, forced_open, forced_closed)
        local pi_high = project_shadow_prices(base_acq_price, forced_open, forced_closed)
        local pi_low = project_shadow_prices(low_seed, forced_open, forced_closed)

        local loc_ub = INF
        local loc_lb = -INF
        local best_pi = {}
        for k, v in pairs(init_pi or pi_ext) do best_pi[k] = v end
        local best_alpha = {}
        local best_dp_pack = nil
        local best_cand_arcs = nil
        local best_cand_ev = nil
        local has_closed = forced_closed and (next(forced_closed) ~= nil) or false
        local has_open = forced_open and (next(forced_open) ~= nil) or false
        local is_root = (not has_closed) and (not has_open)

        local function record_primal(c_arcs, c_tools)
          local sig = path_signature(c_arcs, c_tools)
          if seen_paths[sig] and is_root then return nil end
          seen_paths[sig] = true
          local ev = evaluate_primal(c_arcs, c_tools, var_weight, forced_closed)
          if not ev then return nil end
          if ev.internal_obj < g_ref.ub - 1e-9 then
            g_ref.ub = ev.internal_obj
            g_ref.primal = ev
          end
          local extra_open = 0.0
          if forced_open then
            local ul_set = {}
            for i = 1, #ev.unlocked_recipes do ul_set[ev.unlocked_recipes[i]] = true end
            for sid, _ in pairs(forced_open) do
              if not ul_set[sid] then extra_open = extra_open + usable_recipes[sid].unlock_cost_copper end
            end
          end
          local branch_obj = ev.internal_obj + extra_open
          if branch_obj < loc_ub - 1e-9 then loc_ub = branch_obj end
          return ev
        end

        local seeds = is_root
          and { pi_ext, pi_high, pi_low }
          or { project_shadow_prices(best_pi, forced_open, forced_closed), pi_ext, pi_low }
        for s_idx, seed_pi in ipairs(seeds) do
          local dp_h, _, tact_h = compute_backward_dp(seed_pi, alpha_split, var_weight, true, forced_open, forced_closed)
          local ca_h, ct_h = extract_path_from_dp(dp_h, tact_h, s0, init_tool_state, 0, nil)
          if ca_h then
            local ev_w = record_primal(ca_h, ct_h)
            if (not ev_w) and is_root and s_idx == 1 then
              local rep_pi = {}
              for k, v in pairs(seed_pi) do rep_pi[k] = v end
              local cur_ca = ca_h
              for _ = 1, 4 do
                local r_cons = {}
                for i = 1, #cur_ca do
                  local a = cur_ca[i]
                  if a.kind ~= "gather" then
                    local rec_a = usable_recipes[a.spell_id]
                    for j = 1, #rec_a.reagents do
                      local rg, cnt = rec_a.reagents[j][1], rec_a.reagents[j][2]
                      r_cons[rg] = (r_cons[rg] or 0.0) + a.crafts * cnt
                    end
                  end
                end
                local bumped = false
                for rg, q_need in pairs(r_cons) do
                  local av = item_total_avail[rg] or math_huge
                  if q_need > av + EPS then
                    rep_pi[rg] = (rep_pi[rg] or 100.0) * 1.8 + 2500.0
                    bumped = true
                  end
                end
                if not bumped then break end
                rep_pi = project_shadow_prices(rep_pi, forced_open, forced_closed)
                local dp_r, _, tact_r = compute_backward_dp(rep_pi, alpha_split, var_weight, true, forced_open, forced_closed)
                local n_ca, n_ct = extract_path_from_dp(dp_r, tact_r, s0, init_tool_state, 0, nil)
                if not n_ca then break end
                cur_ca = n_ca
                ev_w = record_primal(n_ca, n_ct)
                if ev_w then break end
              end
            end
            if ev_w and is_root and s_idx == 1 then
              local f_seed = {}
              for k, v in pairs(pi_ext) do f_seed[k] = v end
              for i = 1, #ev_w.purchases do
                local it_p = ev_w.purchases[i]
                if coupled_items[it_p.item_id] then
                  f_seed[it_p.item_id] = marginal_supply_price(it_p.item_id, it_p.quantity)
                end
              end
              for i = 1, #ev_w.owned_used do
                local it_o = ev_w.owned_used[i]
                if coupled_items[it_o.item_id] then
                  f_seed[it_o.item_id] = marginal_supply_price(it_o.item_id, it_o.quantity)
                end
              end
              f_seed = project_shadow_prices(f_seed, forced_open, forced_closed)
              local dp_f, _, tact_f = compute_backward_dp(f_seed, alpha_split, var_weight, true, forced_open, forced_closed)
              local ca_f, ct_f = extract_path_from_dp(dp_f, tact_f, s0, init_tool_state, 0, nil)
              if ca_f then record_primal(ca_f, ct_f) end
            end
          end
        end

        local pi_cur = project_shadow_prices(init_pi or pi_high, forced_open, forced_closed)
        local scarce_touched = {}
        local scarce_cnt = 0

        for it = 0, max_iters - 1 do
          if tick then tick() end
          pi_cur = project_shadow_prices(pi_cur, forced_open, forced_closed)

          local dp, tmat, tact = compute_backward_dp(pi_cur, alpha_split, var_weight, false, forced_open, forced_closed)
          local start_slots = dp[s0][init_tool_state]
          if not start_slots or #start_slots == 0 then
            return -INF, best_pi, best_alpha, nil, nil, nil
          end

          local lb_val = start_slots[1][1] + dual_supply_constant(pi_cur) + open_const
          local cand_arcs, cand_tools = extract_path_from_dp(dp, tact, s0, init_tool_state, 0, nil)
          if not cand_arcs then break end
          local ev_now = record_primal(cand_arcs, cand_tools)

          if lb_val > loc_lb + 1e-9 then
            loc_lb = lb_val
            best_pi = {}
            for k, v in pairs(pi_cur) do best_pi[k] = v end
            best_alpha = {}
            for sid, arr in pairs(alpha_split) do
              local cp = {}
              for u = 1, #arr do cp[u] = arr[u] end
              best_alpha[sid] = cp
            end
            best_dp_pack = { dp, tmat, tact }
            best_cand_arcs = cand_arcs
            if ev_now then best_cand_ev = ev_now end
          end

          if math_min(loc_ub, g_ref.ub) - loc_lb <= 0.5 then break end

          local gamma = 1.0 / (0.35 * it + 1.6)
          local keep = 1.0 - gamma
          local used_pts = {}
          for i = 1, #cand_arcs do
            local a = cand_arcs[i]
            if alpha_split[a.spell_id] then
              local pts = used_pts[a.spell_id]
              if not pts then pts = {}; used_pts[a.spell_id] = pts end
              for s = a.s1, a.s2 - 1 do pts[#pts + 1] = s end
            end
          end
          for sid, pts in pairs(used_pts) do
            local arr = alpha_split[sid]
            local lo = usable_recipes[sid].min_skill
            local f_total = usable_recipes[sid].unlock_cost_copper
            local covered = 0.0
            for i = 1, #pts do covered = covered + arr[pts[i] - lo + 1] end
            if covered < f_total - EPS and #pts > 0 then
              for i = 1, #arr do arr[i] = arr[i] * keep end
              local still_cov = 0.0
              for i = 1, #pts do still_cov = still_cov + arr[pts[i] - lo + 1] end
              local add_each = (f_total - still_cov) / #pts
              for i = 1, #pts do arr[pts[i] - lo + 1] = arr[pts[i] - lo + 1] + add_each end
            end
          end

          if next(coupled_items) ~= nil then
            local cons_qty = {}
            local prod_qty = {}
            for i = 1, #cand_tools do
              local ak, aid = cand_tools[i][2], cand_tools[i][3]
              if ak == "tool_buy" and coupled_items[aid] then
                cons_qty[aid] = (cons_qty[aid] or 0.0) + 1.0
              elseif ak == "tool_craft" and usable_recipes[aid] then
                local trec = usable_recipes[aid]
                for j = 1, #trec.reagents do
                  local rg, cnt = trec.reagents[j][1], trec.reagents[j][2]
                  if coupled_items[rg] then cons_qty[rg] = (cons_qty[rg] or 0.0) + cnt end
                end
              end
            end
            for i = 1, #cand_arcs do
              local a = cand_arcs[i]
              if a.kind ~= "gather" then
                local rec = usable_recipes[a.spell_id]
                for j = 1, #rec.reagents do
                  local rg, cnt = rec.reagents[j][1], rec.reagents[j][2]
                  if coupled_items[rg] then cons_qty[rg] = (cons_qty[rg] or 0.0) + a.crafts * cnt end
                end
                for j = 1, #rec.outputs do
                  local oid, cnt = rec.outputs[j][1], rec.outputs[j][2]
                  if inter_items[oid] then
                    local eff_o = (rec.produces_tool and a.tool_out ~= a.tool_in and oid == rec.produces_tool[3])
                      and math_max(0.0, a.crafts * cnt - 1.0) or (a.crafts * cnt)
                    prod_qty[oid] = (prod_qty[oid] or 0.0) + eff_o
                  end
                end
              end
            end

            local tgt_ub = math_min(loc_ub, g_ref.ub)
            local gap_est = (tgt_ub >= INF * 0.5) and 25000.0 or math_min(150000.0, math_max(300.0, tgt_ub - lb_val))
            local beta_f = (it == 0) and 1.0 or (1.0 / (0.35 * it + 1.4))
            local beta_inter = 0.65 / (1.0 + 0.12 * it)

            for idx_t = #item_topo, 1, -1 do
              local iid = item_topo[idx_t]
              local prods = producers_by_item[iid]
              if prods and not essence_by_item[iid] then
                local net_need = (cons_qty[iid] or 0.0) - (prod_qty[iid] or 0.0)
                if net_need > EPS then
                  local dir_p = marginal_supply_price(iid, net_need)
                  local cheap_direct = 0.0
                  local ts_self = supply_map[iid] or {}
                  for j = 1, #ts_self do
                    if (not is_inf(ts_self[j].max_qty)) and ts_self[j].unit_price < dir_p - EPS then
                      cheap_direct = cheap_direct + ts_self[j].max_qty
                    end
                  end
                  local rem_need = math_max(0.0, net_need - cheap_direct)
                  if rem_need > EPS then
                    local best_tot = rem_need * dir_p
                    local best_p_rec = nil
                    local best_b_int = 0
                    for p = 1, #prods do
                      local p_rec = prods[p]
                      if not (forced_closed and forced_closed[p_rec.spell_id]) then
                        local out_n = 0.0
                        for j = 1, #p_rec.outputs do
                          if p_rec.outputs[j][1] == iid then out_n = out_n + p_rec.outputs[j][2] end
                        end
                        for j = 1, #p_rec.reagents do
                          if p_rec.reagents[j][1] == iid then out_n = out_n - p_rec.reagents[j][2] end
                        end
                        if out_n > EPS then
                          local b_int = math_ceil((rem_need - EPS) / out_n)
                          local mc_p = 0.0
                          for j = 1, #p_rec.reagents do
                            local rg, c = p_rec.reagents[j][1], p_rec.reagents[j][2]
                            if rg ~= iid then mc_p = mc_p + c * (pi_cur[rg] or 0.0) end
                          end
                          local is_free_u = (used_pts[p_rec.spell_id] ~= nil)
                            or (forced_open and forced_open[p_rec.spell_id])
                            or p_ctx.known_recipes[p_rec.spell_id]
                            or p_ctx.known_recipes[tostring(p_rec.spell_id)]
                          local real_ul = is_free_u and 0.0 or p_rec.unlock_cost_copper
                          local tot_sub = real_ul + b_int * mc_p
                          if mc_p <= EPS and tot_sub < best_tot - EPS then
                            best_tot = tot_sub
                            best_p_rec = p_rec
                            best_b_int = b_int
                          end
                        end
                      end
                    end
                    if best_p_rec and best_b_int > 0 then
                      for j = 1, #best_p_rec.reagents do
                        local rg, c = best_p_rec.reagents[j][1], best_p_rec.reagents[j][2]
                        if rg ~= iid and coupled_items[rg] then
                          cons_qty[rg] = (cons_qty[rg] or 0.0) + best_b_int * c
                        end
                      end
                    end
                  end
                end
              end
            end

            local ext_coupled = {}
            for iid, _ in pairs(coupled_items) do
              if not inter_items[iid] then ext_coupled[#ext_coupled + 1] = iid end
            end
            table_sort(ext_coupled)
            for idx_c = 1, #ext_coupled do
              local iid = ext_coupled[idx_c]
              if (cons_qty[iid] or 0.0) > (item_total_avail[iid] or math_huge) + EPS then
                if not scarce_touched[iid] then
                  scarce_touched[iid] = true
                  scarce_cnt = scarce_cnt + 1
                end
              end
            end
            local scarce_n = math_max(1, scarce_cnt)

            for idx_c = 1, #ext_coupled do
              local iid = ext_coupled[idx_c]
              local d_i = cons_qty[iid] or 0.0
              local ts = supply_map[iid] or {}
              local p0 = (#ts > 0) and ts[1].unit_price or 0.0
              local cur_p = pi_cur[iid] or p0
              local tot_av = item_total_avail[iid] or math_huge
              if d_i > tot_av + EPS then
                local mts = market_only_map[iid] or {}
                local mp0 = (#mts > 0) and mts[1].unit_price or p0
                local base_p = math_max(cur_p, (mp0 < INF * 0.5) and mp0 or cur_p)
                local supplied = 0.0
                for j = 1, #ts do
                  if (not is_inf(ts[j].max_qty)) and ts[j].unit_price < base_p - EPS then
                    supplied = supplied + ts[j].max_qty
                  end
                end
                pi_cur[iid] = base_p + 0.55 * gap_est / math_max(1.0, d_i - supplied)
              elseif scarce_touched[iid] then
                local supplied = 0.0
                for j = 1, #ts do
                  if (not is_inf(ts[j].max_qty)) and ts[j].unit_price < cur_p - EPS then
                    supplied = supplied + ts[j].max_qty
                  end
                end
                local diff_q = d_i - supplied
                if math_abs(diff_q) > EPS then
                  local step_s = (0.35 / (1.0 + 0.12 * it)) * gap_est / math_max(8.0, math_abs(diff_q) * scarce_n)
                  pi_cur[iid] = math_max(p0, cur_p + step_s * diff_q)
                end
              else
                local p_star = marginal_supply_price(iid, d_i)
                if d_i > EPS or cur_p > p_star + EPS then
                  pi_cur[iid] = (1.0 - beta_f) * cur_p + beta_f * p_star
                end
              end
            end

            local handled_ep = {}
            for i = 1, #(problem.essence_pairs or {}) do
              local ep = problem.essence_pairs[i]
              local lid, gid, ratio = ep.lesser_item_id, ep.greater_item_id, ep.ratio
              handled_ep[lid] = true
              handled_ep[gid] = true
              local u_net = ((cons_qty[lid] or 0.0) + ratio * (cons_qty[gid] or 0.0))
                - ((prod_qty[lid] or 0.0) + ratio * (prod_qty[gid] or 0.0))
              local cur_l = pi_cur[lid] or 0.0
              local tgt_l
              if u_net < -EPS then
                tgt_l = 0.0
              elseif u_net > EPS then
                local av_l = item_total_avail[lid] or math_huge
                if u_net <= av_l + EPS then
                  tgt_l = marginal_essence_unit_price(ep, u_net)
                else
                  tgt_l = cur_l + 0.45 * gap_est / math_max(1.0, u_net)
                end
              else
                tgt_l = math_min(cur_l, marginal_essence_unit_price(ep, 0.0))
              end
              local nl = math_max(0.0, (1.0 - beta_inter) * cur_l + beta_inter * tgt_l)
              pi_cur[lid] = nl
              pi_cur[gid] = nl * ratio
            end

            for iid, _ in pairs(inter_items) do
              if not handled_ep[iid] then
                local net_d = (cons_qty[iid] or 0.0) - (prod_qty[iid] or 0.0)
                local cur_p = pi_cur[iid] or 0.0
                local tgt_p
                if net_d < -EPS then
                  tgt_p = 0.0
                elseif net_d > EPS then
                  local tot_av = item_total_avail[iid] or math_huge
                  if net_d <= tot_av + EPS then
                    tgt_p = marginal_supply_price(iid, net_d)
                  else
                    tgt_p = cur_p + 0.45 * gap_est / math_max(1.0, net_d - tot_av)
                  end
                else
                  tgt_p = math_min(cur_p, base_acq_price[iid] or cur_p)
                end
                pi_cur[iid] = math_max(0.0, (1.0 - beta_inter) * cur_p + beta_inter * tgt_p)
              end
            end
          end
        end

        return loc_lb, best_pi, best_alpha, best_dp_pack, best_cand_arcs, best_cand_ev
      end

      local function copy_map(m, k_set, v_set)
        local out = {}
        if m then for k, v in pairs(m) do out[k] = v end end
        if k_set ~= nil then out[k_set] = v_set end
        return out
      end

      local function solve_core_with_windows(var_weight, entry_caps, min_starts, init_pi, is_rep_child)
        cur_entry_caps = entry_caps or {}
        cur_min_starts = min_starts or {}
        local seen_paths = {}
        local g_ref = { ub = INF, primal = nil }
        local root_iters
        if is_rep_child then
          root_iters = math_min(use_step_q and 6 or 8, opts.max_subgradient_iters)
        else
          root_iters = use_step_q and math_min(18, opts.max_subgradient_iters) or opts.max_subgradient_iters
        end

        local root_lb, best_pi, best_alpha, best_dp_pack, root_cand_arcs, root_cand_ev =
          run_lagrangian_bound(var_weight, nil, nil, root_iters, seen_paths, g_ref, init_pi)

        local ub = g_ref.ub
        local best_primal = g_ref.primal
        local best_lb = root_lb

        if best_primal and (ub - best_lb) <= 0.5 then
          return best_primal, math_min(ub, best_lb), true, root_cand_arcs, best_pi
        end
        if enforce_no_repeat_active and root_cand_arcs and has_terminal_repeat(root_cand_arcs) then
          return best_primal, best_lb, false, root_cand_arcs, best_pi
        end
        if not best_dp_pack or not best_primal then
          return best_primal, best_lb, false, root_cand_arcs, best_pi
        end

        local function pick_unlock_branch_recipe(c_arcs, c_alpha, c_ev, f_open, f_closed, cur_lb)
          local rem_gap = math_max(0.0, g_ref.ub - cur_lb)
          local best_viol = math_max(1.0, 0.04 * rem_gap)
          local chosen_sid = nil
          local by_sid = {}
          if c_arcs then
            for i = 1, #c_arcs do
              local a = c_arcs[i]
              if a.spell_id and a.spell_id > 0 then
                local pts = by_sid[a.spell_id]
                if not pts then pts = {}; by_sid[a.spell_id] = pts end
                for s = a.s1, a.s2 - 1 do pts[#pts + 1] = s end
              end
            end
          end
          for sid, pts in pairs(by_sid) do
            if not ((f_open and f_open[sid]) or (f_closed and f_closed[sid])) then
              local rec = usable_recipes[sid]
              if rec.unlock_cost_copper > EPS then
                local arr = c_alpha and c_alpha[sid] or nil
                local cov = 0.0
                if arr then
                  for i = 1, #pts do cov = cov + arr[pts[i] - rec.min_skill + 1] end
                end
                local viol = rec.unlock_cost_copper - cov
                if viol > best_viol then
                  best_viol = viol
                  chosen_sid = sid
                end
              end
            end
          end
          if (not chosen_sid) and c_ev then
            for i = 1, #c_ev.unlocked_recipes do
              local sid = c_ev.unlocked_recipes[i]
              if (not by_sid[sid]) and not ((f_open and f_open[sid]) or (f_closed and f_closed[sid])) then
                local rec = usable_recipes[sid]
                if rec.unlock_cost_copper > best_viol then
                  best_viol = rec.unlock_cost_copper
                  chosen_sid = sid
                end
              end
            end
          end
          return chosen_sid
        end

        local root_bsid = pick_unlock_branch_recipe(root_cand_arcs, best_alpha, root_cand_ev, nil, nil, root_lb)
        if root_bsid and opts.max_bnb_nodes > 0 then
          local z_heap = heap_new()
          local z_tie = 0
          local z_nodes = 0
          local max_z = math_min(is_rep_child and 1 or (use_step_q and 3 or 10), opts.max_bnb_nodes)
          local child_iters = is_rep_child and 5 or (use_step_q and 6 or 9)
          local unbranched_min_lb = INF
          heap_push(z_heap, {
            lb = root_lb,
            tie = 0,
            f_open = nil,
            f_closed = nil,
            c_arcs = root_cand_arcs,
            c_alpha = best_alpha,
            c_ev = root_cand_ev,
            c_pi = best_pi,
          })

          while z_heap.n > 0 and z_nodes < max_z do
            ub = g_ref.ub
            if math_min(z_heap.data[1].lb, unbranched_min_lb) >= ub - 0.5 then break end
            local znode = heap_pop(z_heap)
            if znode.lb >= ub - 0.5 then break end
            local b_sid = pick_unlock_branch_recipe(znode.c_arcs, znode.c_alpha, znode.c_ev, znode.f_open, znode.f_closed, znode.lb)
            if not b_sid then
              unbranched_min_lb = math_min(unbranched_min_lb, znode.lb)
            else
              z_nodes = z_nodes + 1
              local branches = {
                { copy_set(znode.f_open, b_sid), copy_set(znode.f_closed, nil) },
                { copy_set(znode.f_open, nil), copy_set(znode.f_closed, b_sid) },
              }
              for bi = 1, 2 do
                local no, nc = branches[bi][1], branches[bi][2]
                local clb, n_pi, calpha, cpack, carcs, cev =
                  run_lagrangian_bound(var_weight, no, nc, child_iters, seen_paths, g_ref, znode.c_pi)
                ub = g_ref.ub
                if cpack and clb > -INF * 0.5 and clb < ub - 0.5 then
                  z_tie = z_tie + 1
                  heap_push(z_heap, {
                    lb = clb,
                    tie = z_tie,
                    f_open = no,
                    f_closed = nc,
                    c_arcs = carcs,
                    c_alpha = calpha,
                    c_ev = cev,
                    c_pi = n_pi,
                  })
                end
              end
            end
          end

          ub = g_ref.ub
          best_primal = g_ref.primal
          local rem_hlb = (z_heap.n > 0) and z_heap.data[1].lb or INF
          local z_bound = math_min(ub, math_min(rem_hlb, unbranched_min_lb))
          best_lb = math_max(best_lb, z_bound)
          if best_primal and (ub - best_lb) <= 0.5 then
            return best_primal, math_min(ub, best_lb), true, root_cand_arcs, best_pi
          end
        end

        local best_dp, best_tmat, best_tact = best_dp_pack[1], best_dp_pack[2], best_dp_pack[3]
        local dual_const_star = dual_supply_constant(best_pi)
        local best_rc_tables = build_fast_rc_tables(best_pi, best_alpha, var_weight, false, nil, nil)

        local alpha_tail = {}
        for sid, arr in pairs(best_alpha) do
          local rec = usable_recipes[sid]
          local tails = {}
          tails[reached + 1] = 0.0
          tails[reached] = 0.0
          for s = reached - 1, s0, -1 do
            local idx = s - rec.min_skill + 1
            local add_v = (idx >= 1 and idx <= #arr) and arr[idx] or 0.0
            tails[s] = (tails[s + 1] or 0.0) + add_v
          end
          alpha_tail[sid] = tails
        end

        local function fast_arc_rc(arc, include_alpha)
          if arc.kind == "gather" then return 0.0 end
          local rt = best_rc_tables[arc.spell_id]
          local eff_r, ret_r, var_r, f_ul, min_sk, pref, has_pt = rt[1], rt[2], rt[3], rt[4], rt[5], rt[6], rt[7]
          if has_pt and arc.tool_out ~= arc.tool_in then
            return arc_reduced_cost(arc, best_pi, include_alpha and best_alpha or nil, var_weight, false, nil)
          end
          local ul_c = 0.0
          if include_alpha and f_ul > EPS and pref then
            ul_c = pref[arc.s2 - min_sk] - pref[arc.s1 - min_sk]
          end
          local sw_c = (arc.s1 > s0) and (recipe_sw_pen[arc.spell_id] or 0.0) or 0.0
          local fp_arr = fail_pen_pref[arc.spell_id]
          local fp_c = fp_arr[arc.s2 - min_sk] - fp_arr[arc.s1 - min_sk]
          local ds = arc.delta_s
          return ds * eff_r + (arc.crafts - ds) * ret_r + ul_c + fp_c + sw_c + arc.var_crafts * var_r
        end

        local function prefix_exact_lb_base(pref_arcs, pref_no_ul_rc, cur_s)
          local used_sids = {}
          for i = 1, #pref_arcs do
            local sid = pref_arcs[i].spell_id
            if sid and sid > 0 then used_sids[sid] = true end
          end
          local unlock_lb = 0.0
          for sid, _ in pairs(used_sids) do
            local rec = usable_recipes[sid]
            if rec.unlock_cost_copper > EPS then
              local rem_tail = (alpha_tail[sid] and alpha_tail[sid][cur_s]) or 0.0
              unlock_lb = unlock_lb + math_max(0.0, rec.unlock_cost_copper - rem_tail)
            end
          end
          return pref_no_ul_rc + unlock_lb
        end

        local arcs_cache_by_s = {}

        local function eval_node_suffix(cur_s, cur_t, last_spell, forbidden)
          if cur_s == reached then return 0.0, nil end
          if not forbidden or next(forbidden) == nil then
            local slots = best_dp[cur_s][cur_t]
            for i = 1, #slots do
              if slots[i][2] ~= last_spell then
                local c = slots[i]
                return c[1], { make_seg_arc(c[2], c[8], cur_s, c[3], c[7], c[4], c[5], c[6]), c[7] }
              end
            end
            return INF, nil
          end

          local list_s = arcs_cache_by_s[cur_s]
          if not list_s then
            list_s = arcs_from_s1(cur_s)
            arcs_cache_by_s[cur_s] = list_s
          end

          local best_c = INF
          local best_ch = nil
          local tmat_row = best_tmat[cur_s][cur_t]
          for i = 1, #list_s do
            local arc = list_s[i]
            local tmid = arc.tool_in
            local tc = tmat_row[tmid]
            local fkey = tostring(arc.arc_id) .. "#" .. tostring(tmid)
            if tc < INF * 0.5 and arc.spell_id ~= last_spell and not forbidden[fkey] then
              local rem_c = (arc.s2 == reached) and 0.0 or INF
              if arc.s2 < reached then
                local next_slots = best_dp[arc.s2][arc.tool_out]
                for j = 1, #next_slots do
                  if next_slots[j][2] ~= arc.spell_id then
                    rem_c = next_slots[j][1]
                    break
                  end
                end
              end
              if rem_c < INF * 0.5 then
                local c = tc + fast_arc_rc(arc, true) + rem_c
                if c < best_c - 1e-9 then
                  best_c = c
                  best_ch = { arc, tmid }
                end
              end
            end
          end
          return best_c, best_ch
        end

        local heap = heap_new()
        local tie_counter = 0
        local root_suf_c = eval_node_suffix(s0, init_tool_state, 0, nil)
        local seg_root_lb = math_max(best_lb, root_suf_c + dual_const_star)
        heap_push(heap, {
          lb = seg_root_lb,
          tie = tie_counter,
          pref_arcs = {},
          pref_tools = {},
          pref_no_ul = 0.0,
          cur_s = s0,
          cur_t = init_tool_state,
          last_spell = 0,
          forbidden = nil,
        })

        local nodes_expanded = 0
        local max_seg_nodes = is_rep_child and math_min(35, opts.max_bnb_nodes) or opts.max_bnb_nodes
        while heap.n > 0 and nodes_expanded < max_seg_nodes do
          if tick then tick() end
          ub = g_ref.ub
          if heap.data[1].lb >= ub - 0.5 then
            best_lb = math_max(best_lb, math_min(ub, heap.data[1].lb))
            break
          end
          local node = heap_pop(heap)
          if node.lb >= ub - 0.5 then
            best_lb = math_max(best_lb, math_min(ub, node.lb))
            break
          end
          nodes_expanded = nodes_expanded + 1

          local pref_base = prefix_exact_lb_base(node.pref_arcs, node.pref_no_ul, node.cur_s)
          local suf_c, first_ch = eval_node_suffix(node.cur_s, node.cur_t, node.last_spell, node.forbidden)
          if first_ch and (pref_base + suf_c + dual_const_star < ub - 0.5) then
            local ext_a, ext_t = extract_path_from_dp(best_dp, best_tact, node.cur_s, node.cur_t, node.last_spell, first_ch)
            if ext_a then
              local full_a, full_t = {}, {}
              for i = 1, #node.pref_arcs do full_a[#full_a + 1] = node.pref_arcs[i] end
              for i = 1, #ext_a do full_a[#full_a + 1] = ext_a[i] end
              for i = 1, #node.pref_tools do full_t[#full_t + 1] = node.pref_tools[i] end
              for i = 1, #ext_t do full_t[#full_t + 1] = ext_t[i] end
              local sig = path_signature(full_a, full_t)
              if not seen_paths[sig] then
                seen_paths[sig] = true
                local ev = evaluate_primal(full_a, full_t, var_weight, nil)
                if ev and ev.internal_obj < ub - 1e-9 then
                  ub = ev.internal_obj
                  g_ref.ub = ub
                  best_primal = ev
                  g_ref.primal = ev
                end
              end
            end

            local first_arc, first_tmid = first_ch[1], first_ch[2]
            local step_tc = best_tmat[node.cur_s][node.cur_t][first_tmid]
            local step_no_ul = fast_arc_rc(first_arc, false)

            local new_pa = {}
            for i = 1, #node.pref_arcs do new_pa[i] = node.pref_arcs[i] end
            new_pa[#new_pa + 1] = first_arc

            local new_pt = {}
            for i = 1, #node.pref_tools do new_pt[i] = node.pref_tools[i] end
            local acts = best_tact[node.cur_s][node.cur_t][first_tmid]
            for i = 1, #acts do new_pt[#new_pt + 1] = { node.cur_s, acts[i][1], acts[i][2] } end
            local new_p_noul = node.pref_no_ul + step_tc + step_no_ul

            if first_arc.s2 < reached then
              local left_sc = eval_node_suffix(first_arc.s2, first_arc.tool_out, first_arc.spell_id, nil)
              local left_base = prefix_exact_lb_base(new_pa, new_p_noul, first_arc.s2)
              local left_lb = left_base + left_sc + dual_const_star
              if left_lb < ub - 0.5 then
                tie_counter = tie_counter + 1
                heap_push(heap, {
                  lb = left_lb,
                  tie = tie_counter,
                  pref_arcs = new_pa,
                  pref_tools = new_pt,
                  pref_no_ul = new_p_noul,
                  cur_s = first_arc.s2,
                  cur_t = first_arc.tool_out,
                  last_spell = first_arc.spell_id,
                  forbidden = nil,
                })
              end
            else
              local sig_leaf = path_signature(new_pa, new_pt)
              if not seen_paths[sig_leaf] then
                seen_paths[sig_leaf] = true
                local ev_l = evaluate_primal(new_pa, new_pt, var_weight, nil)
                if ev_l and ev_l.internal_obj < ub - 1e-9 then
                  ub = ev_l.internal_obj
                  g_ref.ub = ub
                  best_primal = ev_l
                  g_ref.primal = ev_l
                end
              end
            end

            local new_forb = copy_set(node.forbidden, tostring(first_arc.arc_id) .. "#" .. tostring(first_tmid))
            local right_sc = eval_node_suffix(node.cur_s, node.cur_t, node.last_spell, new_forb)
            local right_lb = pref_base + right_sc + dual_const_star
            if right_lb < ub - 0.5 then
              tie_counter = tie_counter + 1
              heap_push(heap, {
                lb = right_lb,
                tie = tie_counter,
                pref_arcs = node.pref_arcs,
                pref_tools = node.pref_tools,
                pref_no_ul = node.pref_no_ul,
                cur_s = node.cur_s,
                cur_t = node.cur_t,
                last_spell = node.last_spell,
                forbidden = new_forb,
              })
            end
          end
        end

        local final_lb, is_opt
        if heap.n == 0 then
          final_lb = ub
          is_opt = true
        else
          final_lb = math_max(best_lb, math_min(ub, heap.data[1].lb))
          is_opt = ((ub - final_lb) <= 0.5)
        end
        return best_primal, final_lb, is_opt, root_cand_arcs, best_pi
      end

      local function solve_core(var_weight)
        var_weight = var_weight or 0.0
        if not opts.forbid_recipe_repeat then
          enforce_no_repeat_active = false
          local pr, lb, opt = solve_core_with_windows(var_weight, {}, {}, nil, false)
          cur_entry_caps = {}
          cur_min_starts = {}
          return pr, lb, opt
        end

        enforce_no_repeat_active = false
        local pr0, lb0, opt0, _, pi0 = solve_core_with_windows(var_weight, {}, {}, nil, false)
        if not pr0 then
          cur_entry_caps = {}
          cur_min_starts = {}
          return nil, lb0, opt0
        end

        local rep0 = find_first_terminal_repeat(pr0.arcs)
        if not rep0 then
          cur_entry_caps = {}
          cur_min_starts = {}
          return pr0, lb0, opt0
        end

        enforce_no_repeat_active = true
        local clean_ub = INF
        local clean_primal = nil
        local unbranched_lb = INF
        local best_polish_seed = { lb = lb0, ecaps = {}, mstarts = {}, pi = pi0, cand = pr0.arcs }
        local rep_heap = heap_new()
        heap_push(rep_heap, {
          lb = lb0,
          tie = 0,
          ecaps = {},
          mstarts = {},
          rep = rep0,
          pi = pi0,
        })
        local r_tie = 0
        local r_nodes = 0
        local max_r_nodes = 4

        while rep_heap.n > 0 and r_nodes < max_r_nodes do
          if rep_heap.data[1].lb >= clean_ub - 0.5 then break end
          local rnode = heap_pop(rep_heap)
          if rnode.lb >= clean_ub - 0.5 then break end
          r_nodes = r_nodes + 1

          local rsid, split_m = rnode.rep[1], rnode.rep[2]
          local cur_ec = rnode.ecaps[rsid] or (reached + 1)
          local cur_ms = rnode.mstarts[rsid] or 0
          local children = {}
          if split_m < cur_ec and split_m > cur_ms then
            children[#children + 1] = { copy_map(rnode.ecaps, rsid, split_m), copy_map(rnode.mstarts, nil, nil) }
            children[#children + 1] = { copy_map(rnode.ecaps, nil, nil), copy_map(rnode.mstarts, rsid, split_m) }
          elseif split_m <= cur_ms and (split_m + 1) < cur_ec then
            children[#children + 1] = { copy_map(rnode.ecaps, nil, nil), copy_map(rnode.mstarts, rsid, cur_ms + 1) }
          end

          for ci = 1, #children do
            local ec_c, ms_c = children[ci][1], children[ci][2]
            local c_pr, c_lb, c_opt, c_cand, c_pi = solve_core_with_windows(var_weight, ec_c, ms_c, rnode.pi, true)
            if c_pr and c_pr.internal_obj < clean_ub - 1e-9 then
              clean_ub = c_pr.internal_obj
              clean_primal = c_pr
            end
            if c_lb > -INF * 0.5 and c_lb < clean_ub - 0.5 then
              local nxt_rep = c_cand and find_first_terminal_repeat(c_cand) or nil
              if nxt_rep then
                r_tie = r_tie + 1
                heap_push(rep_heap, {
                  lb = c_lb,
                  tie = r_tie,
                  ecaps = ec_c,
                  mstarts = ms_c,
                  rep = nxt_rep,
                  pi = c_pi,
                })
                if c_cand and c_lb < best_polish_seed.lb then
                  best_polish_seed = { lb = c_lb, ecaps = ec_c, mstarts = ms_c, pi = c_pi, cand = c_cand }
                end
              elseif not c_opt then
                unbranched_lb = math_min(unbranched_lb, c_lb)
              end
            end
          end
        end

        if (not clean_primal) and best_polish_seed then
          local ec_w, ms_w, pi_w, cur_rep
          if rep_heap.n > 0 then
            local top_r = rep_heap.data[1]
            ec_w = copy_map(top_r.ecaps, nil, nil)
            ms_w = copy_map(top_r.mstarts, nil, nil)
            pi_w = top_r.pi
            cur_rep = top_r.rep
          else
            ec_w = copy_map(best_polish_seed.ecaps, nil, nil)
            ms_w = copy_map(best_polish_seed.mstarts, nil, nil)
            pi_w = best_polish_seed.pi
            cur_rep = find_first_terminal_repeat(best_polish_seed.cand)
          end

          for _ = 1, 10 do
            if not cur_rep then break end
            local rsid, split_m = cur_rep[1], cur_rep[2]
            local c_ec = ec_w[rsid] or (reached + 1)
            local c_ms = ms_w[rsid] or 0
            if not (split_m < c_ec and split_m > c_ms) then break end
            local opts_lr = {
              { copy_map(ec_w, rsid, split_m), copy_map(ms_w, nil, nil) },
              { copy_map(ec_w, nil, nil), copy_map(ms_w, rsid, split_m) },
            }
            local best_side = nil
            for si = 1, 2 do
              local ec_try, ms_try = opts_lr[si][1], opts_lr[si][2]
              cur_entry_caps = ec_try
              cur_min_starts = ms_try
              local dp_p, _, tact_p = compute_backward_dp(pi_w, nil, var_weight, true, nil, nil)
              local ca_p, ct_p = extract_path_from_dp(dp_p, tact_p, s0, init_tool_state, 0, nil)
              local slots_p = dp_p[s0][init_tool_state]
              if ca_p and slots_p and #slots_p > 0 then
                local sc_p = slots_p[1][1]
                local ev_p = evaluate_primal(ca_p, ct_p, var_weight, nil)
                if ev_p and ev_p.internal_obj < clean_ub - 1e-9 then
                  clean_ub = ev_p.internal_obj
                  clean_primal = ev_p
                end
                if (not best_side) or sc_p < best_side.sc - 1e-9 then
                  best_side = { sc = sc_p, ec = ec_try, ms = ms_try, ca = ca_p }
                end
              end
            end
            if clean_primal or (not best_side) then break end
            ec_w = best_side.ec
            ms_w = best_side.ms
            cur_rep = find_first_terminal_repeat(best_side.ca)
          end
        end

        enforce_no_repeat_active = false
        cur_entry_caps = {}
        cur_min_starts = {}

        if clean_primal then
          local rem_lb = (rep_heap.n > 0) and rep_heap.data[1].lb or INF
          local final_lb = math_max(lb0, math_min(clean_ub, math_min(rem_lb, unbranched_lb)))
          return clean_primal, final_lb, ((clean_ub - final_lb) <= 0.5)
        end
        return pr0, lb0, opt0
      end

      local best_ev, lb_internal, is_opt, z_alpha = nil, 0.0, false, 0.0
      if opts.risk_mode ~= "route_quantile" then
        best_ev, lb_internal, is_opt = solve_core(0.0)
      else
        z_alpha = math_max(0.0, M.normal_quantile(opts.confidence))
        local ev0, lb0, opt0 = solve_core(0.0)
        if ev0 then
          local function route_q_score(ev)
            return ev.real_obj + ev.reg_cost + z_alpha * math_sqrt(math_max(0.0, ev.route_var))
          end

          best_ev = ev0
          local best_q = route_q_score(ev0)
          is_opt = opt0
          local v_cur = ev0.route_var
          local tried_thetas = { 0.0 }
          local function has_theta(th, tol)
            for i = 1, #tried_thetas do
              if math_abs(th - tried_thetas[i]) <= tol then return true end
            end
            return false
          end

          if v_cur > 1e-6 and z_alpha > 1e-6 then
            local theta_tan = z_alpha / (2.0 * math_sqrt(v_cur))
            local probes = { theta_tan, theta_tan * 2.0 }
            for i = 1, #probes do
              local th = probes[i]
              if not has_theta(th, 1e-9) then
                tried_thetas[#tried_thetas + 1] = th
                local ev_t = solve_core(th)
                if ev_t then
                  local sc = route_q_score(ev_t)
                  if sc < best_q - 1e-9 then best_q = sc; best_ev = ev_t end
                  if i == 1 then
                    local vt = ev_t.route_var
                    if vt > 1e-6 and math_abs(vt - v_cur) > 1e-4 then
                      local th_next = z_alpha / (2.0 * math_sqrt(vt))
                      if not has_theta(th_next, 1e-7) then
                        tried_thetas[#tried_thetas + 1] = th_next
                        local ev_n = solve_core(th_next)
                        if ev_n then
                          local sc_n = route_q_score(ev_n)
                          if sc_n < best_q - 1e-9 then best_q = sc_n; best_ev = ev_n end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
          lb_internal = best_q
        end
      end

      if not best_ev then
        return {
          status = "unreachable",
          profession = problem.profession,
          objective = opts.objective,
          risk_mode = opts.risk_mode,
          confidence = opts.confidence,
          start_skill = s0,
          target_skill = starget,
          reached_skill = s0,
          is_optimal = false,
          lower_bound_copper = 0.0,
          optimality_gap_copper = 0.0,
          objective_value_copper = 0.0,
          gross_cost_copper = 0.0,
          sell_revenue_copper = 0.0,
          raw_net_spend_copper = 0.0,
          anti_farm_net_spend_copper = 0.0,
          owned_opportunity_cost_copper = 0.0,
          unlock_cost_copper = 0.0,
          route_std_copper = 0.0,
          steps = {},
          shopping_list = {},
          owned_consumed = {},
          sold_outputs = {},
          retained_tools = {},
          unlocked_recipes = {},
          blocker = blocker,
          prep_confidence = opts.prep_confidence,
          gross_std_copper = 0.0,
          safe_gross_cost_copper = 0.0,
          safe_net_spend_copper = 0.0,
          safe_prep_gross_cost_copper = 0.0,
          safe_shopping_list = {},
          safe_owned_consumed = {},
        }
      end

      -- 7. 后置 <0.5ms 马尔可夫单步分位稳健备料结算 + 组装因果步骤清单
      local eff_prep_conf = opts.prep_confidence
      local plan_arc_crafts = {}
      for i = 1, #best_ev.arcs do
        local a = best_ev.arcs[i]
        plan_arc_crafts[i] = (a.kind == "gather") and a.delta_s or math_ceil(a.crafts - 1e-9)
      end

      local ev_safe = best_ev
      local safe_arc_crafts = plan_arc_crafts
      if not (opts.risk_mode == "step_quantile" and math_abs(eff_prep_conf - opts.confidence) <= 1e-9) then
        local bop_tool_items = {}
        for ti = 1, #(problem.tools or {}) do
          if problem.tools[ti].bind_on_pickup then
            bop_tool_items[problem.tools[ti].item_id] = true
          end
        end
        local raw_safe = {}
        for i = 1, #best_ev.arcs do
          local a = best_ev.arcs[i]
          local pc = plan_arc_crafts[i]
          if a.kind == "gather" then
            raw_safe[i] = pc
          else
            local rec = usable_recipes[a.spell_id]
            if rec.produces_tool and bop_tool_items[rec.produces_tool[3]] then
              raw_safe[i] = pc
            else
              local probs = {}
              for s = a.s1, a.s2 - 1 do probs[#probs + 1] = M.skill_up_prob(rec, s) end
              local q_arr = M.compute_step_quantiles_from(probs, eff_prep_conf)
              local q_val = (#q_arr > 0) and q_arr[#q_arr] or pc
              local rmax = recipe_max_crafts[a.spell_id] or math_huge
              if not is_inf(rmax) then
                q_val = math_min(q_val, math_floor(rmax + EPS))
              end
              raw_safe[i] = math_max(pc, q_val)
            end
          end
        end

        local function eval_with_counts(counts)
          local s_arcs = {}
          for i = 1, #best_ev.arcs do
            local a = best_ev.arcs[i]
            s_arcs[i] = make_seg_arc(a.spell_id, a.kind, a.s1, a.s2, a.tool_in, a.tool_out, counts[i], a.var_crafts)
          end
          return evaluate_primal(s_arcs, best_ev.tool_actions, 0.0, nil)
        end

        local ev_full = eval_with_counts(raw_safe)
        if ev_full then
          ev_safe = ev_full
          safe_arc_crafts = raw_safe
        else
          local ev_plan = eval_with_counts(plan_arc_crafts)
          if ev_plan then ev_safe = ev_plan end
          local lo_f, hi_f = 0.0, 1.0
          for _ = 1, 6 do
            local mid = 0.5 * (lo_f + hi_f)
            local cand_c = {}
            for i = 1, #best_ev.arcs do
              cand_c[i] = plan_arc_crafts[i] + math_floor(mid * (raw_safe[i] - plan_arc_crafts[i]) + 1e-9)
            end
            local ev_m = eval_with_counts(cand_c)
            if ev_m then
              ev_safe = ev_m
              safe_arc_crafts = cand_c
              lo_f = mid
            else
              hi_f = mid
            end
          end
        end
      end

      local steps = {}
      local sidx = 1
      local paid_unlock = {}

      local tools_by_s = {}
      for i = 1, #best_ev.tool_actions do
        local ta = best_ev.tool_actions[i]
        tools_by_s[ta[1]] = tools_by_s[ta[1]] or {}
        table_insert(tools_by_s[ta[1]], { ta[2], ta[3] })
      end

      local sub_by_s = {}
      for i = 1, #best_ev.subcrafts do
        local sc = best_ev.subcrafts[i]
        sub_by_s[sc[1]] = sub_by_s[sc[1]] or {}
        sub_by_s[sc[1]][sc[2]] = (sub_by_s[sc[1]][sc[2]] or 0.0) + sc[3]
      end

      local safe_sub_by_s = {}
      for i = 1, #ev_safe.subcrafts do
        local sc = ev_safe.subcrafts[i]
        safe_sub_by_s[sc[1]] = safe_sub_by_s[sc[1]] or {}
        safe_sub_by_s[sc[1]][sc[2]] = (safe_sub_by_s[sc[1]][sc[2]] or 0.0) + sc[3]
      end

      local safe_ess_map = {}
      for i = 1, #ev_safe.essence_conversions do
        local ec = ev_safe.essence_conversions[i]
        safe_ess_map[tostring(ec[1]) .. ":" .. tostring(ec[2])] = ec[3]
      end

      for i = 1, #best_ev.essence_conversions do
        local ec = best_ev.essence_conversions[i]
        local from_id, to_id, times = ec[1], ec[2], ec[3]
        local is_lesser_src = essence_by_item[from_id][2]
        local in_m = is_lesser_src and 3 or 1
        local out_m = is_lesser_src and 1 or 3
        local s_times = math_max(times, safe_ess_map[tostring(from_id) .. ":" .. tostring(to_id)] or times)
        steps[#steps + 1] = {
          step_index = sidx,
          kind = "essence_convert",
          from_skill = s0,
          to_skill = s0,
          spell_id = nil,
          name = "Convert Essence " .. tostring(from_id) .. " -> " .. tostring(to_id),
          expected_crafts = times,
          planned_crafts = times,
          safe_crafts = s_times,
          reagents = { { from_id, times * in_m } },
          outputs = { { to_id, times * out_m } },
          unlock_cost_copper = 0.0,
        }
        sidx = sidx + 1
      end

      for i = 1, #best_ev.arcs do
        local arc = best_ev.arcs[i]
        local tas = tools_by_s[arc.s1]
        if tas then
          tools_by_s[arc.s1] = nil
          for j = 1, #tas do
            local tkind, tid = tas[j][1], tas[j][2]
            if tkind == "tool_buy" then
              steps[#steps + 1] = {
                step_index = sidx,
                kind = "tool_buy",
                from_skill = arc.s1,
                to_skill = arc.s1,
                name = "Acquire Tool #" .. tostring(tid),
                expected_crafts = 1.0,
                planned_crafts = 1,
                safe_crafts = 1,
                reagents = {},
                outputs = { { tid, 1.0 } },
                unlock_cost_copper = 0.0,
              }
              sidx = sidx + 1
            elseif tkind == "tool_craft" then
              local trec = usable_recipes[tid]
              local uc = 0.0
              if (not paid_unlock[tid]) and trec.unlock_cost_copper > EPS then
                uc = trec.unlock_cost_copper
                paid_unlock[tid] = true
              end
              steps[#steps + 1] = {
                step_index = sidx,
                kind = "subcraft",
                from_skill = arc.s1,
                to_skill = arc.s1,
                spell_id = tid,
                name = trec.name,
                expected_crafts = 1.0,
                planned_crafts = 1,
                safe_crafts = 1,
                reagents = trec.reagents,
                outputs = trec.outputs,
                unlock_cost_copper = uc,
                teaching_item_id = (uc > 0) and trec.teaching_item_id or nil,
                note = "Required tool preparation",
              }
              sidx = sidx + 1
            end
          end
        end

        local safe_subs_here = safe_sub_by_s[arc.s1] or {}
        safe_sub_by_s[arc.s1] = nil
        local subs = sub_by_s[arc.s1]
        if subs then
          sub_by_s[arc.s1] = nil
          for _, sid in ipairs(sorted_keys(subs)) do
            local sc_cnt = subs[sid]
            local srec = usable_recipes[sid]
            local uc = 0.0
            if (not paid_unlock[sid]) and srec.unlock_cost_copper > EPS then
              uc = srec.unlock_cost_copper
              paid_unlock[sid] = true
            end
            local s_regs, s_outs = {}, {}
            for j = 1, #srec.reagents do s_regs[j] = { srec.reagents[j][1], srec.reagents[j][2] * sc_cnt } end
            for j = 1, #srec.outputs do s_outs[j] = { srec.outputs[j][1], srec.outputs[j][2] * sc_cnt } end
            local plan_sc = math_ceil(sc_cnt - 1e-9)
            local safe_sc = math_max(plan_sc, math_ceil((safe_subs_here[sid] or sc_cnt) - 1e-9))
            steps[#steps + 1] = {
              step_index = sidx,
              kind = "subcraft",
              from_skill = arc.s1,
              to_skill = arc.s1,
              spell_id = sid,
              name = srec.name,
              expected_crafts = sc_cnt,
              planned_crafts = plan_sc,
              safe_crafts = safe_sc,
              reagents = s_regs,
              outputs = s_outs,
              unlock_cost_copper = uc,
              teaching_item_id = (uc > 0) and srec.teaching_item_id or nil,
              note = "Self-crafted intermediate reagent",
            }
            sidx = sidx + 1
          end
        end

        if arc.kind == "gather" then
          local g_items, g_zones = {}, {}
          local seen_gi, seen_gz = {}, {}
          for j = 1, #(problem.gather_bands or {}) do
            local b = problem.gather_bands[j]
            if b.min_skill < arc.s2 and b.max_skill > arc.s1 then
              for u = 1, #b.item_ids do
                local iid = b.item_ids[u]
                if not seen_gi[iid] then seen_gi[iid] = true; g_items[#g_items + 1] = iid end
              end
              for u = 1, #b.zone_ids do
                local zid = b.zone_ids[u]
                if not seen_gz[zid] then seen_gz[zid] = true; g_zones[#g_zones + 1] = zid end
              end
            end
          end
          steps[#steps + 1] = {
            step_index = sidx,
            kind = "gather",
            from_skill = arc.s1,
            to_skill = arc.s2,
            name = "Field Mining (No Smelting Skill-Ups Available)",
            expected_crafts = arc.delta_s,
            planned_crafts = arc.delta_s,
            safe_crafts = arc.delta_s,
            gather_item_ids = g_items,
            gather_zone_ids = g_zones,
            reagents = {},
            outputs = {},
            unlock_cost_copper = 0.0,
          }
          sidx = sidx + 1
        else
          local rec = usable_recipes[arc.spell_id]
          local uc = 0.0
          if (not paid_unlock[arc.spell_id]) and rec.unlock_cost_copper > EPS then
            uc = rec.unlock_cost_copper
            paid_unlock[arc.spell_id] = true
          end
          local a_regs, a_outs = {}, {}
          for j = 1, #rec.reagents do a_regs[j] = { rec.reagents[j][1], rec.reagents[j][2] * arc.crafts } end
          for j = 1, #rec.outputs do a_outs[j] = { rec.outputs[j][1], rec.outputs[j][2] * arc.crafts } end
          steps[#steps + 1] = {
            step_index = sidx,
            kind = rec.kind,
            from_skill = arc.s1,
            to_skill = arc.s2,
            spell_id = arc.spell_id,
            name = rec.name,
            expected_crafts = arc.crafts,
            planned_crafts = math_ceil(arc.crafts - 1e-9),
            safe_crafts = safe_arc_crafts[i],
            reagents = a_regs,
            outputs = a_outs,
            unlock_cost_copper = uc,
            teaching_item_id = (uc > 0) and rec.teaching_item_id or nil,
          }
          sidx = sidx + 1
        end
      end

      local route_std = math_sqrt(math_max(0.0, best_ev.route_var))
      local gross_std = math_sqrt(math_max(0.0, best_ev.gross_var))
      local net_std = math_sqrt(math_max(0.0, best_ev.net_var))
      local z_prep = math_max(0.0, M.normal_quantile(eff_prep_conf))
      local safe_gross_cost = best_ev.gross_cost + z_prep * gross_std
      local safe_net_spend = best_ev.anti_farm_net_spend + z_prep * net_std
      local safe_prep_gross = math_max(best_ev.gross_cost, ev_safe.gross_cost)

      local obj_val, real_lb, gap
      if opts.risk_mode == "route_quantile" then
        obj_val = best_ev.real_obj + z_alpha * route_std
        real_lb = obj_val
        gap = 0.0
      else
        obj_val = best_ev.real_obj
        local internal_gap = math_max(0.0, best_ev.internal_obj - lb_internal)
        real_lb = obj_val - internal_gap
        gap = internal_gap
      end

      return {
        status = (reached >= starget) and "complete" or "partial",
        profession = problem.profession,
        objective = opts.objective,
        risk_mode = opts.risk_mode,
        confidence = opts.confidence,
        prep_confidence = eff_prep_conf,
        start_skill = s0,
        target_skill = starget,
        reached_skill = reached,
        is_optimal = is_opt,
        lower_bound_copper = real_lb,
        optimality_gap_copper = gap,
        objective_value_copper = obj_val,
        gross_cost_copper = best_ev.gross_cost,
        gross_std_copper = gross_std,
        safe_gross_cost_copper = safe_gross_cost,
        sell_revenue_copper = best_ev.sell_revenue,
        raw_net_spend_copper = best_ev.raw_net_spend,
        anti_farm_net_spend_copper = best_ev.anti_farm_net_spend,
        safe_net_spend_copper = safe_net_spend,
        safe_prep_gross_cost_copper = safe_prep_gross,
        owned_opportunity_cost_copper = best_ev.owned_opp_cost,
        unlock_cost_copper = best_ev.unlock_cost,
        route_std_copper = route_std,
        steps = steps,
        shopping_list = best_ev.purchases,
        safe_shopping_list = ev_safe.purchases,
        owned_consumed = best_ev.owned_used,
        safe_owned_consumed = ev_safe.owned_used,
        sold_outputs = best_ev.sold,
        retained_tools = best_ev.retained_tools,
        unlocked_recipes = best_ev.unlocked_recipes,
        blocker = blocker,
      }
    end

    return M
end)()


S.OptimizerCore = OptimizerCore

local REQUIRED_TOOL_MAP = {
    runed_copper_rod = { "runed_rod", 1 },
    runed_silver_rod = { "runed_rod", 2 },
    runed_golden_rod = { "runed_rod", 3 },
    runed_truesilver_rod = { "runed_rod", 4 },
    runed_arcanite_rod = { "runed_rod", 5 },
    blacksmith_hammer = { "blacksmith_hammer", 1 },
    arclight_spanner = { "arclight_spanner", 1 },
    gyromatic_micro_adjustor = { "gyromatic_micro_adjustor", 1 },
    philosophers_stone = { "philosophers_stone", 1 },
}

local TOOL_ITEM_TO_KEY = {
    [6218] = { "runed_rod", 1 },
    [6339] = { "runed_rod", 2 },
    [11130] = { "runed_rod", 3 },
    [11145] = { "runed_rod", 4 },
    [16207] = { "runed_rod", 5 },
    [5956] = { "blacksmith_hammer", 1 },
    [6219] = { "arclight_spanner", 1 },
    [10498] = { "gyromatic_micro_adjustor", 1 },
    [9149] = { "philosophers_stone", 1 },
}

local function available(s, id)
    return (s.inv[id] or 0) - (s.unusable[id] or 0)
end

local function copyStateMap(source)
    local out = {}
    for k, v in pairs(source or {}) do out[k] = v end
    return out
end

local function writable(state, field)
    local current = state[field]
    if state._shared and state._shared[field] then
        local copy = copyStateMap(current)
        state[field] = copy
        state._shared[field] = nil
        return copy
    end
    return current
end

local sharedStateFields = {
    "inv", "produced", "priorityProduced", "unusable",
    "skill", "cap", "learned", "formulaPaid", "ahUsed",
    "specializationAbilities", "completedSpecializationGoals", "completedToolGoals",
    "skeletonBought",
}

local function clone(s)
    local shared = {}
    local o = {
        money = s.money,
        switches = s.switches,
        lastRecipe = s.lastRecipe,
        log = s.log,
        plannedTarget = s.plannedTarget,
        _v3Meta = s._v3Meta,
        diagnostics = copyStateMap(s.diagnostics),
        _shared = shared,
    }
    for i = 1, #sharedStateFields do
        local f = sharedStateFields[i]
        o[f] = s[f]
        shared[f] = true
    end
    if s._shared then
        for i = 1, #sharedStateFields do s._shared[sharedStateFields[i]] = true end
    else
        s._shared = copyStateMap(shared)
    end
    return o
end

local function consume(s, id, n)
    if n <= 0 then return end
    local cur = s.inv[id] or 0
    writable(s, "inv")[id] = max(0, cur - n)
    if (s.produced[id] or 0) > 0 then
        local rem = max(0, cur - n)
        if (s.produced[id] or 0) > rem then
            writable(s, "produced")[id] = rem
        end
        if (s.priorityProduced[id] or 0) > rem then
            writable(s, "priorityProduced")[id] = rem
        end
    end
end

local function log(s, a)
    s.log = { prev = s.log, action = a }
end

local function diagnostic(s, key, code, extra)
    s.diagnostics[key] = { code = code, detail = extra, item = type(extra) == "number" and extra or nil }
end

local function uncertainty(s)
    local n = 0
    for _ in pairs(s and s.diagnostics or {}) do n = n + 1 end
    return n
end

local function objective(s, snapshot)
    local rec = getRecovery()
    if snapshot and rec and type(rec.Objective) == "function" then
        return rec.Objective(s, snapshot)
    end
    return s and s.money or 0
end

local function betterState(a, b, snapshot)
    if not a then return false end
    if not b then return true end
    local ua, ub = uncertainty(a), uncertainty(b)
    if ua ~= ub then return ua < ub end
    local oa, ob = objective(a, snapshot), objective(b, snapshot)
    if math.abs(oa - ob) > 1e-7 then return oa < ob end
    if math.abs(a.money - b.money) > 1e-7 then return a.money < b.money end
    return (a.switches or 0) < (b.switches or 0)
end

local function bagMaterialsEnabled(slug, opts)
    return type(opts) == "table"
        and opts.useBagMaterials == true
        and not opts.procurementDemands
        and opts.scheme ~= "fixed"
        and opts.scheme ~= "fishing"
        and slug ~= "first-aid"
        and slug ~= "poisons"
end

local function initialInventory(snap, slug, opts)
    if bagMaterialsEnabled(slug, opts) and snap and type(snap.bagInventory) == "table" then
        return copyStateMap(snap.bagInventory)
    end
    if snap and type(snap.inventory) == "table" and opts and opts.procurementDemands then
        return copyStateMap(snap.inventory)
    end
    return {}
end

local function initial(snap, slug, opts, tick)
    local capLimit = solverCap()
    local inv = initialInventory(snap, slug, opts)
    local skill, cap = {}, {}
    for p, info in pairs(snap and snap.professions or {}) do
        skill[p] = (p == slug and tonumber(opts and opts.start)) or tonumber(info.cur) or 1
        cap[p] = tonumber(info.max) or capLimit
    end
    if not skill[slug] then
        skill[slug] = tonumber(opts and opts.start) or 1
        cap[slug] = capLimit
    end
    local learned = copyStateMap(snap and snap.known or {})
    local abilities = copyStateMap(snap and snap.specializationAbilities or {})
    local s = {
        money = 0,
        switches = 0,
        inv = inv,
        produced = {},
        priorityProduced = {},
        unusable = {},
        skill = skill,
        cap = cap,
        learned = learned,
        formulaPaid = {},
        ahUsed = {},
        specializationAbilities = abilities,
        completedSpecializationGoals = {},
        completedToolGoals = {},
        skeletonBought = {},
        diagnostics = {},
    }
    local seedIds = {}
    for id, cnt in pairs(inv) do
        if type(id) == "number" and type(cnt) == "number" and cnt > 0 then
            seedIds[#seedIds + 1] = id
        end
    end
    table.sort(seedIds)
    for i = 1, #seedIds do
        local id = seedIds[i]
        log(s, { type = "seed", item = id, count = inv[id], cost = 0, usableOutput = true })
        if tick and i % 32 == 0 then tick() end
    end
    return s
end

local function actions(s, tick)
    local rev, out = {}, {}
    local node = s and s.log
    local n = 0
    while node do
        rev[#rev + 1] = node.action
        node = node.prev
        n = n + 1
        if tick and n % 64 == 0 then tick() end
    end
    for i = #rev, 1, -1 do
        out[#out + 1] = rev[i]
    end
    return out
end

local function goalsComplete(job, state)
    if not state then return false end
    if (state.skill[job.slug] or 0) < job.target then return false end
    for _, goal in ipairs(job.snap and job.snap.toolGoals or {}) do
        if not (job.unattainableToolGoals and job.unattainableToolGoals[goal.id])
            and not state.completedToolGoals[goal.id] then
            return false
        end
    end
    for _, goal in ipairs(job.snap and job.snap.specializationGoals or {}) do
        if (goal.minSkill or 0) <= job.target
            and not state.completedSpecializationGoals[goal.id]
            and not state.specializationAbilities[goal.abilityID] then
            return false
        end
    end
    return true
end

local function completedGoals(state)
    local count = 0
    for _ in pairs(state and state.completedSpecializationGoals or {}) do count = count + 1 end
    for _ in pairs(state and state.completedToolGoals or {}) do count = count + 1 end
    return count
end

local function stampFreshResult(result, snapshot, tick)
    local recovery = getRecovery()
    if recovery and recovery.Apply and snapshot then recovery.Apply(result, snapshot, tick) end
    local route = getRouteAuto()
    if route and route.StampVendorQuotes then route.StampVendorQuotes(result) end
    if route and route.StampToolPolicy then route.StampToolPolicy(result, snapshot and snapshot.targetProfession, nil, snapshot) end
    return result
end

local function stampLearningGaps(job, result)
    result.failureDiagnosticVersion = S.FailureDiagnosticVersion
    if result._learningGapRevision ~= (job.learningGapRevision or 0) then
        result.learningGaps = {}
        for _, gap in pairs(job.learningGaps or {}) do
            result.learningGaps[#result.learningGaps + 1] = gap
            if job.tick and coroutine.running() == job.co then job.tick() end
        end
        table.sort(result.learningGaps, function(a, b)
            if a.profession ~= b.profession then return tostring(a.profession) < tostring(b.profession) end
            return (a.spell or 0) < (b.spell or 0)
        end)
        result._learningGapRevision = job.learningGapRevision or 0
    end
    result.learningCoverageComplete = #(result.learningGaps or {}) == 0
    result.blockingLearningGaps = {}
    if not result.targetReached then
        local blockers = job.blockedSkill == (result.plannedTo or result.start) and job.blockers or result.blockingDiagnostics
        local seen = {}
        for _, d in ipairs(blockers or {}) do
            if d.code == "learningDataMissing" or d.code == "learningRequirementsUnknown"
                or (type(d.missingReasons) == "table" and #d.missingReasons > 0) then
                local key = tostring(d.code) .. ":" .. tostring(d.recipe or d.spell)
                if not seen[key] then
                    result.blockingLearningGaps[#result.blockingLearningGaps + 1] = d
                    seen[key] = true
                end
            end
        end
    end
    result.learningBlocked = #result.blockingLearningGaps > 0
    if result._learningPathComplete == nil then result._learningPathComplete = result.learningComplete ~= false end
    result.learningComplete = result._learningPathComplete and not result.learningBlocked
    if result.learningBlocked then
        result.completeCost = false
        result.optimal = false
    elseif result.costComplete ~= nil then
        result.completeCost = result.costComplete
    end
end

function S.Progress(job, result)
    result = result or job.result
    local quoteComplete = result and result.costComplete and not result.essenceQuoteIncomplete and result.auctionDepthComplete ~= false and true or false
    if job.recovery and result and ((result.recoveryQuoteMissing or 0) > 0 or result.recoveryFeeMissing) then quoteComplete = false end
    local inputOptimal = result and result.targetReached and job.exhausted and not job.restricted
        and not result.alreadyAtTarget and result.learningComplete ~= false and result.formulaComplete ~= false
        and result.specializationComplete ~= false
        and result.supplyComplete ~= false
        and not job.budgetLimited and job.status ~= "error" and job.status ~= "stopped" and quoteComplete or false
    local coverage = job.snap and job.snap.coverageComplete ~= false or false
    return {
        status = job.status,
        expanded = job.expanded or 0,
        improvements = job.improvements or 0,
        searchCpuMs = job.cpuUsed or 0,
        searchCpuLimitMs = job.cpuLimitMs or solverBudget("cpuLimitMs", 8000),
        searchComplete = job.exhausted or false,
        budgetLimited = job.budgetLimited or false,
        costSearchPerformed = (job.expanded or 0) > 0,
        costSearchStatus = (job.expanded or 0) == 0 and (job.seedDone and "seed_only" or "pending")
            or (job.exhausted and not job.budgetLimited and "exhausted" or "searched_unproven"),
        searchTermination = job.searchTermination,
        resultVersion = job.resultVersion or 0,
        progressVersion = job.progressVersion or 0,
        inputModelOptimal = inputOptimal,
        catalogueCoverageComplete = coverage,
        quoteComplete = quoteComplete,
        optimal = inputOptimal and coverage or false,
        restrictedReason = job.restrictedReason,
        searchFrontierLimit = job.frontierLimit,
        finalizing = job.finalizing and true or false,
        finalizeProgress = job.finalizeProgress or 0,
        searchExternalCpuMs = job.externalCpuUsed or 0,
        searchModel = "lagrangian_dag_markov_v3",
    }
end

function S.RefreshStatus(job, result, status)
    result = result or job.result
    if not result then return end
    for key, value in pairs(S.Progress(job, result)) do result[key] = value end
    result.status = status or job.status
    result.searchTermination = job.searchTermination
    result.restrictedReason = job.restricted and (job.restrictedReason or "restricted_search") or nil
    if result.partial then
        local blockers = job.blockedSkill == result.plannedTo and job.blockers or nil
        if job.resultBlockers ~= blockers then
            local E = getEconomy()
            result.blockingDiagnostics = E.Copy(blockers or {})
            job.resultBlockers = blockers
            E.SummarizeAuctionSupply(result, job.snap)
        end
    end
    stampLearningGaps(job, result)
    result.initialTotal = job.initialTotal
    result.savings = result.feasible and job.initialTotal and max(0, job.initialTotal - result.total) or 0
    if job.recovery then
        result.initialNetTotal = job.initialNetTotal
        result.bestNetTotal = result.feasible and result.netTotal or nil
        result.netSavings = result.bestNetTotal and job.initialNetTotal and max(0, job.initialNetTotal - result.bestNetTotal) or 0
    end
    return result
end

local function restrict(job, reason)
    job.restricted = true
    job.restrictedReason = job.restrictedReason or reason
end

local function resultTick(job)
    if job.tick and coroutine.running() == job.co then job.tick() end
end

local function finalizeProgress(job, value)
    if job.finalizing and coroutine.running() == job.co then
        job.finalizeProgress = max(job.finalizeProgress or 0, min(0.99, value))
    end
end

local function buildReserveSummary(job, out, state, tick)
    local E = getEconomy()
    local reserveMode = job.reserveMode or "safe"
    local optMeta = state and state._v3Meta or nil
    if not optMeta or job.opts.procurementDemands or out.scheme == "fixed" or out.scheme == "fishing" then
        out.routeRiskMode = job.routeRiskMode or "expected"
        out.reserveMode = reserveMode
        return
    end
    out.routeRiskMode = job.routeRiskMode or "expected"
    out.reserveMode = reserveMode
    out.safeTotal = optMeta.safeGrossCost and ceil(optMeta.safeGrossCost - 1e-9) or out.total
    out.safeNetTotal = optMeta.safeNetSpend and floor(optMeta.safeNetSpend + 0.5) or out.netTotal
    out.grossStd = optMeta.grossStd or 0
    out.routeStd = optMeta.routeStd or 0

    local safeCraftsBySpellSpan = optMeta.safeCraftsByKey or {}
    local extraBySegment = {}
    for _, step in ipairs(out.steps or {}) do
        if not step.checkpoint and not step.kind and (step[2] or 0) > (step[1] or 0) and (step[3] or 0) > 0 then
            local skey = tostring(step.profession or job.slug) .. ":" .. tostring(step[3]) .. ":" .. tostring(step[1]) .. ":" .. tostring(step[2])
            local sc = safeCraftsBySpellSpan[skey]
            if not sc then
                local r = step.recipe or (job.snap and job.snap.byKey and job.snap.byKey[tostring(step.profession or job.slug) .. ":" .. tostring(step[3])])
                if r then
                    local probs = {}
                    for sk = step[1], step[2] - 1 do
                        local p = E.Gain(r, sk)
                        if p > 0 then probs[#probs + 1] = p end
                    end
                    if #probs > 0 then
                        local qArr = OptimizerCore.compute_step_quantiles_from(probs, optMeta.prepConfidence or 0.90)
                        sc = qArr[#qArr]
                    end
                end
            end
            sc = max(step[4] or 0, step.safeCrafts or 0, sc or 0)
            step.safeCrafts = sc
            step.extraReserveCrafts = max(0, sc - (step[4] or 0))
            extraBySegment[step.segmentID] = step.extraReserveCrafts
        else
            local sc = max(step[4] or 0, step.safeCrafts or 0)
            step.safeCrafts = sc
            step.extraReserveCrafts = max(0, sc - (step[4] or 0))
            if step.extraReserveCrafts > 0 then
                extraBySegment[step.segmentID] = step.extraReserveCrafts
            end
        end
        if tick then tick() end
    end

    local safeMats = E.Copy(optMeta.safeMats or {}, tick)
    local safeMatTotal = optMeta.safeMatTotal or out.matTotal
    local extraByItem = E.Copy(optMeta.extraByItem or {}, tick)
    local grossExtraByItem = E.Copy(optMeta.grossExtraByItem or extraByItem, tick)
    out.safePrepTotal = (out.formulasTotal or 0) + safeMatTotal
    out.reserve = {
        enabled = reserveMode == "safe",
        mode = reserveMode,
        confidence = optMeta.prepConfidence or 0.90,
        mats = safeMats,
        matTotal = safeMatTotal,
        extraTotal = max(0, safeMatTotal - (out.matTotal or 0)),
        extraByItem = extraByItem,
        grossExtraByItem = grossExtraByItem,
        extraBySegment = extraBySegment,
    }
end

local function finishResult(job, result, state, status)
    finalizeProgress(job, 0.97)
    local E = getEconomy()
    local tick = coroutine.running() == job.co and job.tick or nil
    if job.snap and job.snap.auctionPriceInputs then
        result.auctionPriceInputs = E.Copy(job.snap.auctionPriceInputs, tick)
    end
    if job.snap and job.snap.vendorPriceInputs then
        result.vendorPriceInputs = {}
        for _, entry in ipairs(result.mats or {}) do
            local id = entry.id or entry[1]
            result.vendorPriceInputs[id] = job.snap.vendorPriceInputs[id] or false
        end
        for id, count in pairs(result.seedInventory or {}) do
            if type(count) == "number" and count > 0 then
                result.vendorPriceInputs[id] = job.snap.vendorPriceInputs[id] or false
            end
        end
    end
    stampFreshResult(result, job.snap, tick)
    buildReserveSummary(job, result, state, tick)
    E.SummarizeAuctionSupply(result, job.snap, tick)
    finalizeProgress(job, 0.98)
    local essence = getEssences()
    if job.snap and job.snap.essenceConversions and essence and essence.MissingQuotes then
        local bought = {}
        for _, action in ipairs(result.actions or {}) do
            if action.type == "buy" and (action.count or 0) > 0 then bought[action.item] = true end
        end
        result.essenceQuoteMissing = essence.MissingQuotes(job.snap, bought)
        result.essenceQuoteIncomplete = #result.essenceQuoteMissing > 0 or nil
    end
    job.resultVersion = (job.resultVersion or 0) + 1
    job.resultState = state
    job.resultCache = result
    finalizeProgress(job, 0.99)
    return S.RefreshStatus(job, result, status)
end

function S.Result(job, state, status)
    local prefix = job.preview or job.partial
    local partial = not state and prefix and ((prefix.skill[job.slug] or 0) > (job.opts.start or 1) or completedGoals(prefix) > 0)
    if partial then
        state = prefix
        partial = not goalsComplete(job, state)
    end
    local finalStatus = status or job.status
    if finalStatus ~= "searching" and coroutine.running() == job.co then
        job.finalizing = true
        job.finalizeProgress = job.finalizeProgress or 0
    end
    finalizeProgress(job, 0.8)
    local E = getEconomy()
    local recovery = getRecovery()
    if state and job.resultState == state and job.resultCache then
        job.resultCache.reserveMode = job.reserveMode or job.resultCache.reserveMode or "safe"
        if type(job.resultCache.reserve) == "table" then
            job.resultCache.reserve.enabled = job.resultCache.reserveMode == "safe"
            job.resultCache.reserve.mode = job.resultCache.reserveMode
        end
        finalizeProgress(job, 0.99)
        return S.RefreshStatus(job, job.resultCache, status)
    end
    local out = {
        planVersion = 2,
        executionVersion = 2,
        scheme = "cost",
        steps = {},
        actions = {},
        mats = {},
        firstAt = {},
        gaps = {},
        total = 0,
        matTotal = 0,
        vendorTotal = 0,
        ahTotal = 0,
        crafts = 0,
        productAH = 0,
        productNPC = 0,
        productPartial = false,
        start = job.opts.start or 1,
        target = job.target,
        status = status or "searching",
        feasible = state ~= nil,
        priced = true,
        optimal = false,
        diagnostics = {},
        stamp = Now(),
        expanded = job.expanded or 0,
        improvements = job.improvements or 0,
        initialTotal = job.initialTotal,
        searchComplete = job.exhausted or false,
        budgetLimited = job.budgetLimited or false,
    }
    out.searchTermination = job.searchTermination
    out.procurementPolicyVersion = S.ProcurementPolicyVersion
    out.auctionDepthRevision = 1
    out.auctionDepthInputs = E.Copy(job.snap and job.snap.auctionDepthInputs)
    out.vendorDiscountSig = job.snap and job.snap.vendorDiscountSig
    out.searchCpuMs = job.cpuUsed or 0
    out.searchCpuLimitMs = job.cpuLimitMs or solverBudget("cpuLimitMs", 8000)
    out.phaseCpuMs = E.Copy(job.phaseCpuMs or {})
    out.firstFeasibleCpuMs = job.firstFeasibleCpuMs
    out.seedInventory = E.Copy(initialInventory(job.snap, job.slug, job.opts))
    out.useBagMaterials = bagMaterialsEnabled(job.slug, job.opts)
    if out.useBagMaterials then
        out.bagInventory = E.Copy(job.snap and job.snap.bagInventory or {})
        out.bagInventoryStamp = job.snap and job.snap.bagInventoryStamp
        out.bagInventoryFingerprint = job.snap and job.snap.bagInventoryFingerprint
        out.bagInventoryVersion = 1
        out.bagInventoryUnknown = job.snap and job.snap.bagInventoryUnknown or nil
        out.bagMaterialQuotes = E.Copy(job.snap and job.snap.bagMaterialQuotes or {})
    end
    out.scheme = job.opts.scheme or "cost"
    out.routeRiskMode = job.routeRiskMode or "expected"
    out.reserveMode = job.reserveMode or "safe"
    out.stability = nil
    out.toolGoals = E.Copy(job.snap and job.snap.toolGoals)
    out.toolGoalsPending = E.Copy(job.snap and job.snap.toolGoalsPending)
    out.retainedToolItems = E.Copy(job.snap and job.snap.retainedToolItems)
    out.toolFingerprint = job.snap and job.snap.toolFingerprint
    out.specializationGoals = E.Copy(job.snap and job.snap.specializationGoals)
    out.specializationContext = E.Copy(job.snap and job.snap.specializationContext)
    local specializationWarnings = out.specializationContext and out.specializationContext.warnings or {}
    out.specializationComplete = #specializationWarnings == 0 and not job.specializationConflict
    for _, warning in ipairs(specializationWarnings) do out.diagnostics[#out.diagnostics + 1] = E.Copy(warning) end
    if job.specializationConflict then
        out.diagnostics[#out.diagnostics + 1] = { code = "specializationChoiceConflict", profession = job.slug }
    end
    out.formulas = {}
    out.formulasTotal = 0
    out.formulaAHTotal = 0
    out.formulaVendorTotal = 0
    out.formulaRevision = 1
    out.formulaComplete = true
    local context = job.snap and job.snap.routeContext
    out.professionPolicy = 1
    if context then
        out.targetUnlearned = context.unlearned
        out.secondaryProfession = context.requiresPartner and context.partner or nil
    else
        out.targetUnlearned = job.opts.targetUnlearned
        out.secondaryProfession = job.opts.secondaryProfession
    end
    out.savings = state and job.initialTotal and max(0, job.initialTotal - state.money) or 0
    out.recoveryOptimized = job.recovery and true or false
    out.auctionRecoveryEnabled = job.snap and job.snap.recovery and job.snap.recovery.auctionRecoveryEnabled == true or false
    if job.recovery then
        out.initialNetTotal = job.initialNetTotal
        out.bestNetTotal = state and (state.money - recovery.StateRevenue(state, job.snap)) or nil
        out.priorityTotal = state and objective(state, job.snap) or nil
        out.netSavings = out.bestNetTotal and job.initialNetTotal and max(0, job.initialNetTotal - out.bestNetTotal) or 0
    end
    out.partial = partial and true or false
    out.targetReached = goalsComplete(job, state)
    out.plannedTo = state and max(state.skill[job.slug] or 0, state.plannedTarget or 0) or out.start
    if not state then
        out.priced = false
        out.costComplete = false
        out.completeCost = false
        for _, d in pairs(job.failures or {}) do out.diagnostics[#out.diagnostics + 1] = d end
        if job.blockedSkill == out.plannedTo or #(job.blockers or {}) > 0 then
            out.blockingDiagnostics = E.Copy(job.blockers or {})
        end
        if job.opts.procurementDemands then
            out.procurement = true
            out.demands = E.Copy(job.opts.procurementDemands)
            out.start = nil
            out.target = nil
            out.plannedTo = nil
        end
        return finishResult(job, out, state, status)
    end
    local purchases, purchaseLookup, vendorPurchases = {}, {}, {}
    local crafted = {}
    local pendingCost = 0
    local pendingUnpriced = false
    local formulaEntries, formulaRecipes, formulaByOwner = {}, {}, {}
    out.total = state.money
    out.inventory = E.Copy(state.inv)
    out.finalSkills = E.Copy(state.skill)
    out.completedSpecializationGoals = E.Copy(state.completedSpecializationGoals)
    out.completedToolGoals = E.Copy(state.completedToolGoals)
    out.specializationAbilities = E.Copy(state.specializationAbilities)
    for _, d in pairs(state.diagnostics) do out.diagnostics[#out.diagnostics + 1] = E.Copy(d) end
    local checkedLearning = {}
    for _, d in ipairs(out.diagnostics) do
        if d.code == "learningRequirementsUnknown" then checkedLearning[d.detail] = true end
    end
    local entry = state.log
    while entry do
        resultTick(job)
        local action = entry.action
        if action.type == "craft" then
            local key = action.profession .. ":" .. action.spell
            if not checkedLearning[key] then
                local recipe = job.snap.byKey and job.snap.byKey[key]
                local detail
                if recipe then
                    local _, _, value = (E.RouteRecipeEligibility or E.RecipeSpecializationAllowed)(recipe, job.snap, state)
                    detail = value
                end
                if detail and detail.status == "unknown" then
                    out.diagnostics[#out.diagnostics + 1] = { code = "learningRequirementsUnknown", detail = key, spell = action.spell }
                end
                checkedLearning[key] = true
            end
        end
        entry = entry.prev
    end
    for _, d in ipairs(out.toolGoalsPending or {}) do out.diagnostics[#out.diagnostics + 1] = E.Copy(d) end
    out.costComplete = true
    out.learningComplete = true
    for _, d in ipairs(out.diagnostics) do
        if d.code == "learningRequirementsUnknown" then
            out.learningComplete = false
        elseif d.code == "materialPriceUnknown" or d.code == "vendorPriceUnknown"
            or d.code == "vendorEstimate" or d.code == "formulaPriceUnknown" or d.code == "learningPriceUnknown" then
            out.costComplete = false
        end
    end
    out.completeCost = out.costComplete
    out.priced = out.costComplete
    out.actions = actions(state, coroutine.running() == job.co and job.tick or nil)
    out.dependencyGraph = {}
    if partial then
        out.blockingDiagnostics = E.Copy((job.blockedSkill == out.plannedTo or #(job.blockers or {}) > 0) and job.blockers or {})
        out.remainingUnknown = true
    end
    local toolOrigins = {}
    local provenance, provenanceHeads = {}, {}
    local usedOutputs, allocations = {}, {}
    local cashByRecipe, countByRecipe, unpricedByRecipe = {}, {}, {}
    for i, a in ipairs(out.actions) do
        finalizeProgress(job, 0.82 + 0.02 * (i - 1) / max(1, #out.actions))
        resultTick(job)
        if (a.type == "buy" or a.type == "formula") and a.owner and a.owner ~= "__batch__" then
            cashByRecipe[a.owner] = (cashByRecipe[a.owner] or 0) + a.cost
            unpricedByRecipe[a.owner] = unpricedByRecipe[a.owner] or a.unpriced
        elseif a.type == "craft" then
            local key = a.profession .. ":" .. a.spell
            countByRecipe[key] = (countByRecipe[key] or 0) + a.count
        end
    end
    local function addOrigin(id, n, actionID, craftedOrigin)
        local pool = provenance[id] or {}
        provenance[id] = pool
        pool[#pool + 1] = { count = n, id = actionID, crafted = craftedOrigin and true or false }
    end
    for i, a in ipairs(out.actions) do
        finalizeProgress(job, 0.84 + 0.08 * (i - 1) / max(1, #out.actions))
        resultTick(job)
        a.id = tostring(i) .. ":" .. tostring(a.profession or "") .. ":" .. tostring(a.spell or a.item or 0)
        local dependencies, dependencySet = {}, {}
        for _, input in ipairs(a.inputs or {}) do
            local need = input[2]
            local pool = provenance[input[1]] or {}
            local heads = provenanceHeads[input[1]] or { 1, 1 }
            provenanceHeads[input[1]] = heads
            for pass = 1, 2 do
                local index = heads[pass]
                while need > 0 and index <= #pool do
                    local origin = pool[index]
                    resultTick(job)
                    if origin.crafted == (pass == 2) then
                        local n = min(need, origin.count)
                        origin.count = origin.count - n
                        need = need - n
                        if n > 0 and origin.id then
                            usedOutputs[origin.id] = true
                            local list = allocations[origin.id] or {}
                            allocations[origin.id] = list
                            list[#list + 1] = { consumerID = a.id, itemID = input[1], count = n }
                            if not dependencySet[origin.id] then
                                dependencySet[origin.id] = true
                                dependencies[#dependencies + 1] = origin.id
                            end
                        end
                    end
                    if origin.crafted ~= (pass == 2) or origin.count <= 0 then
                        index = index + 1
                    else
                        break
                    end
                end
                heads[pass] = index
                if need <= 0 then break end
            end
        end
        a.dependencies = dependencies
        out.dependencyGraph[a.id] = dependencies
        if a.type == "seed" then
            if a.usableOutput ~= false then addOrigin(a.item, a.count, a.id) end
        elseif a.type == "formula" then
            local entryF = E.Copy(a.formula)
            entryF.recipes = {}
            if a.source ~= "trainer" or entryF.id ~= nil then
                out.formulas[#out.formulas + 1] = entryF
                formulaEntries[entryF.id or entryF.recipeKey] = entryF
                if a.owner then formulaByOwner[a.owner] = entryF end
            end
            out.formulaComplete = out.formulaComplete and entryF.costComplete
            out.formulasTotal = out.formulasTotal + a.cost
            if a.source == "vendor" or a.source == "trainer" or (a.source == "acquire" and entryF.acquisitionKind == "currency") then
                out.vendorTotal = out.vendorTotal + a.cost
                out.formulaVendorTotal = out.formulaVendorTotal + a.cost
            elseif a.source == "ah" then
                out.ahTotal = out.ahTotal + a.cost
                out.formulaAHTotal = out.formulaAHTotal + a.cost
            end
            out.referencePrices = out.referencePrices or (entryF.offer and entryF.offer.reference)
        elseif a.type == "buy" then
            addOrigin(a.item, a.count, a.id)
            if not a.owner then
                pendingCost = pendingCost + a.cost
                pendingUnpriced = pendingUnpriced or a.unpriced
            end
            local key = tostring(a.item) .. ":" .. a.source .. ":" .. tostring(a.npcID or 0)
            local map = purchaseLookup
            local bundlePrice = a.bundlePrice
            if a.source == "vendor" then
                local bundle = a.bundleSize or 1
                bundlePrice = bundlePrice or a.cost / (a.count / bundle)
                local identity = {
                    a.item, a.npcID or 0, bundle, bundlePrice,
                    a.priceSource or false, a.quoteSource or false, a.priceBasis or false,
                }
                map = vendorPurchases
                for idx = 1, #identity - 1 do
                    local part = identity[idx]
                    map[part] = map[part] or {}
                    map = map[part]
                end
                key = identity[#identity]
            end
            local e = map[key]
            if not e then
                e = stampStock({
                    a.item, 0,
                    id = a.item, count = 0, need = 0, cost = 0, unit = 0,
                    vendor = a.source == "vendor", source = a.source, npcID = a.npcID,
                    url = a.url, spell = a.spell, reason = a.reason,
                    bundleSize = a.bundleSize, bundlePrice = bundlePrice,
                    quoteSource = a.quoteSource, priceSource = a.priceSource,
                    priceBasis = a.priceBasis, verifiedAt = a.verifiedAt,
                }, a)
                map[key] = e
                purchases[#purchases + 1] = e
            end
            e[2] = e[2] + a.count
            e.count = e[2]
            e.need = e.count
            e.cost = e.cost + a.cost
            e.unit = e.cost / e.count
            e.netDemand = true
            e.unpriced = e.unpriced or a.unpriced or nil
            out.pricePending = out.pricePending or a.unpriced or nil
            e.reference = e.reference or a.reference or nil
            e.estimated = e.estimated or a.estimated or nil
            out.referencePrices = out.referencePrices or a.reference or nil
            out.matTotal = out.matTotal + a.cost
            if a.source == "vendor" then
                out.vendorTotal = out.vendorTotal + a.cost
            else
                out.ahTotal = out.ahTotal + a.cost
            end
        elseif a.type == "convert" then
            local c = a.conversion
            for _, output in ipairs(a.outputs or {}) do addOrigin(output[1], output[2], a.id) end
            out.steps[#out.steps + 1] = {
                a.from, a.to, 0, a.count,
                kind = "essence_conversion",
                profession = a.profession,
                reason = "essence",
                manual = true,
                essence = true,
                conversion = E.Copy(c),
                actionID = a.id,
                actionIDs = { a.id },
                item = a.item,
                cost = 0,
                expectedGain = 0,
                sourceItem = c.inputItemID,
                sourceCount = c.inputCount * a.count,
                sourcePerConversion = c.inputCount,
                targetItem = c.outputItemID,
                targetCount = c.outputCount * a.count,
                targetPerConversion = c.outputCount,
                inputs = E.Copy(a.inputs),
                outputs = E.Copy(a.outputs),
                attemptLimit = a.count,
                recipe = {
                    profession = a.profession,
                    spell = 0,
                    item = c.outputItemID,
                    count = c.outputCount,
                    mats = { { c.inputItemID, c.inputCount } },
                },
            }
            if not out.firstAt[c.inputItemID] then out.firstAt[c.inputItemID] = a.from end
        elseif a.type == "tool_goal" then
            pendingCost = pendingCost + (a.directCost or 0) + (cashByRecipe["tool:" .. a.goalID] or 0)
            pendingUnpriced = pendingUnpriced or a.directUnpriced or unpricedByRecipe["tool:" .. a.goalID] or false
            for _, origin in ipairs(provenance[a.item] or {}) do
                if origin.count > 0 and origin.crafted then
                    toolOrigins[origin.id] = a.item
                    break
                end
            end
        elseif a.type == "specialization_quest" then
            local goal = E.Copy(a.quest)
            local key = "quest:" .. goal.id
            out.steps[#out.steps + 1] = {
                a.from, a.to, 0, 0,
                kind = "specialization_quest",
                profession = a.profession,
                quest = goal,
                goalID = goal.id,
                questID = goal.questID,
                abilityID = goal.abilityID,
                inputs = E.Copy(a.inputs),
                requiredItems = E.Copy(a.inputs),
                reason = "specialization",
                actionID = a.id,
                actionIDs = { a.id },
                cost = pendingCost + (cashByRecipe[key] or 0),
                unpriced = pendingUnpriced or unpricedByRecipe[key] or nil,
                expectedGain = 0,
                recipe = { profession = a.profession, spell = 0, mats = E.Copy(a.inputs) },
            }
            pendingCost = 0
            pendingUnpriced = false
            for _, m in ipairs(a.inputs or {}) do
                if not out.firstAt[m[1]] then out.firstAt[m[1]] = a.from end
            end
        elseif a.type == "craft" or a.type == "gather" then
            local recipeKey = tostring(a.profession) .. ":" .. tostring(a.spell)
            local f = job.formulaByRecipe and job.formulaByRecipe[recipeKey]
            local entryF = formulaByOwner[recipeKey] or (f and formulaEntries[f.id or recipeKey])
            if entryF and not formulaRecipes[recipeKey] then
                entryF.recipes[#entryF.recipes + 1] = { profession = a.profession, spell = a.spell, key = recipeKey, source = f.sources }
                formulaRecipes[recipeKey] = true
            end
            if a.usableOutput ~= false then
                for _, output in ipairs(a.outputs or {}) do addOrigin(output[1], output[2], a.id, true) end
            end
            local key = tostring(a.profession) .. ":" .. tostring(a.spell)
            local stepCost = pendingCost + (a.directCost or 0) + (cashByRecipe[key] or 0) * (a.count or 0) / max(1, countByRecipe[key] or 1)
            local stepUnpriced = pendingUnpriced or a.directUnpriced or unpricedByRecipe[key] or nil
            local last = out.steps[#out.steps]
            if a.type == "craft" and last and not last.kind and not last.checkpoint and last[3] == a.spell and last.profession == a.profession then
                last[2] = a.to
                last[4] = last[4] + a.count
                last.safeCrafts = (last.safeCrafts or last[4] - a.count) + (a.safeCrafts or a.count or 0)
                last.cost = last.cost + stepCost
                last.unpriced = last.unpriced or stepUnpriced
                last.actionIDs[#last.actionIDs + 1] = a.id
                last.expectedGain = (last.expectedGain or 0) + (a.expectedGain or 0)
            else
                local recipe = job.snap.byKey and job.snap.byKey[tostring(a.profession) .. ":" .. tostring(a.spell)]
                out.steps[#out.steps + 1] = {
                    a.from, a.to, a.spell or 0, a.count or 0,
                    profession = a.profession,
                    reason = a.reason,
                    checkpoint = a.type == "gather",
                    actionID = a.id,
                    actionIDs = { a.id },
                    item = a.item,
                    cost = stepCost,
                    unpriced = stepUnpriced,
                    recipe = recipe and E.Copy(recipe),
                    tool = recipe and recipe.tool or nil,
                    toolItem = recipe and recipe.toolItem or nil,
                    expectedGain = a.expectedGain or (a.to - a.from),
                    safeCrafts = a.safeCrafts,
                }
            end
            pendingCost = 0
            pendingUnpriced = false
            if a.type == "gather" then
                out.gaps[#out.gaps + 1] = { a.from, a.to, manual = true, profession = a.profession }
            else
                out.crafts = out.crafts + a.count
                if a.item then crafted[a.item] = (crafted[a.item] or 0) + (a.outputCount or 0) end
                for _, m in ipairs(a.inputs or {}) do
                    if not out.firstAt[m[1]] then out.firstAt[m[1]] = a.from end
                end
            end
        end
    end
    if pendingCost > 0 and #out.steps > 0 then
        local last = out.steps[#out.steps]
        last.cost = last.cost + pendingCost
    end
    for _, e in ipairs(purchases) do out.mats[#out.mats + 1] = e end
    out.referenceRoute = out.pricePending or nil
    table.sort(out.mats, function(a, b) return a.id < b.id or (a.id == b.id and a.source < b.source) end)
    local occurrences, actionSegments = {}, {}
    for i, step in ipairs(out.steps) do
        finalizeProgress(job, 0.92 + 0.02 * (i - 1) / max(1, #out.steps))
        resultTick(job)
        local key = step.kind == "specialization_quest" and ("quest:" .. step.goalID)
            or step.kind == "essence_conversion" and ("convert:" .. step.sourceItem .. ":" .. step.targetItem)
            or (step.profession .. ":" .. step[3])
        occurrences[key] = (occurrences[key] or 0) + 1
        step.stepIndex = i
        step.segmentID = "segment:" .. key .. ":" .. occurrences[key]
        step.expectedCrafts = step[4]
        step.outputMin = step.recipe and (step.recipe.outputMin or step.recipe.count) or 0
        step.outputMax = step.recipe and (step.recipe.outputMax or step.recipe.count) or step.outputMin
        step.requiredOutputs = {}
        step.allocations = {}
        if step.checkpoint or ((step.expectedGain or 0) > 0 and (step[2] or 0) > (step[1] or 0)) then
            step.goalSkill = step[2]
        end
        for _, id in ipairs(step.actionIDs) do actionSegments[id] = step.segmentID end
    end
    for i, step in ipairs(out.steps) do
        finalizeProgress(job, 0.94 + 0.02 * (i - 1) / max(1, #out.steps))
        resultTick(job)
        for _, id in ipairs(step.actionIDs) do
            for _, allocation in ipairs(allocations[id] or {}) do
                step.requiredOutputs[allocation.itemID] = (step.requiredOutputs[allocation.itemID] or 0) + allocation.count
                step.allocations[#step.allocations + 1] = {
                    consumerID = actionSegments[allocation.consumerID] or allocation.consumerID,
                    itemID = allocation.itemID,
                    count = allocation.count,
                }
            end
        end
        for _, id in ipairs(step.actionIDs) do
            local item = toolOrigins[id]
            if item then
                step.requiredOutputs[item] = max(1, step.requiredOutputs[item] or 0)
                step.tool = true
                step.toolItem = item
                if #step.allocations == 0 then
                    step.allocations[#step.allocations + 1] = { consumerID = "tool:" .. item, itemID = item, count = 1 }
                end
            end
        end
        step.materialMinCrafts = 0
        for _, n in pairs(step.requiredOutputs) do
            step.materialMinCrafts = max(step.materialMinCrafts, ceil(n / max(1, step.outputMin)))
        end
        step.leveling = (step.expectedGain or 0) > 1e-9
        step.material = next(step.requiredOutputs) ~= nil
        step.role = step.leveling and (step.material and "both" or "level") or (step.material and "material" or nil)
        if step.kind == "essence_conversion" then
            step.plannedSurplus = max(0, step.targetCount - (step.requiredOutputs[step.targetItem] or 0))
        end
    end
    out.seedAllocations = {}
    for _, a in ipairs(out.actions) do
        if a.type == "seed" then
            for _, allocation in ipairs(allocations[a.id] or {}) do
                out.seedAllocations[#out.seedAllocations + 1] = {
                    itemID = a.item,
                    count = allocation.count,
                    consumerID = actionSegments[allocation.consumerID] or allocation.consumerID,
                }
            end
        end
    end
    -- O(N + E) reverse pass: anchor pure material steps (including multi-hop chains) to earliest consuming leveling skill
    local anchorBySegment = {}
    for i = #out.steps, 1, -1 do
        local step = out.steps[i]
        if step.role == "level" or step.role == "both" then
            anchorBySegment[step.segmentID] = step[1]
        elseif step.role == "material" then
            local point
            for _, allocation in ipairs(step.allocations or {}) do
                local targetSkill = anchorBySegment[allocation.consumerID]
                if targetSkill ~= nil and (point == nil or targetSkill < point) then
                    point = targetSkill
                end
            end
            point = point or step[1]
            step.displaySkill = point
            anchorBySegment[step.segmentID] = point
        end
    end
    local ra = getRouteAuto()
    for id, n in pairs(crafted) do
        local left = min(n, state.produced[id] or 0)
        local retained = job.snap.retainedToolItems and job.snap.retainedToolItems[id] or 0
        local purchased = max(0, (state.inv[id] or 0) - (state.produced[id] or 0))
        left = max(0, left - max(0, retained - purchased))
        if left > 0 then
            local ah = job.snap.prices[id]
            local npc = (ra and ra.NPCSellPriceOf and ra.NPCSellPriceOf(id))
                or (recovery and recovery.NPCSellPriceOf and recovery.NPCSellPriceOf(id))
            if ah then out.productAH = out.productAH + left * ah else out.productPartial = true end
            if npc then out.productNPC = out.productNPC + left * npc end
        end
    end
    if job.opts.procurementDemands then
        out.procurement = true
        out.demands = E.Copy(job.opts.procurementDemands)
        out.consumedDemands = E.Copy(job.opts.procurementDemands)
        out.start = nil
        out.target = nil
        out.plannedTo = nil
        local demandID
        for i = #out.steps, 1, -1 do
            local step = out.steps[i]
            if step.profession == "__purchase" then
                demandID = step.segmentID
                out.crafts = out.crafts - step[4]
                table.remove(out.steps, i)
            end
        end
        for i, step in ipairs(out.steps) do
            step.stepIndex = i
            for _, allocation in ipairs(step.allocations) do
                if allocation.consumerID == demandID then allocation.consumerID = "demand:" .. allocation.itemID end
            end
        end
        for _, allocation in ipairs(out.seedAllocations) do
            if allocation.consumerID == demandID then allocation.consumerID = "demand:" .. allocation.itemID end
        end
        for i = #out.actions, 1, -1 do
            local a = out.actions[i]
            if a.type == "craft" and a.profession == "__purchase" then
                out.dependencyGraph[a.id] = nil
                table.remove(out.actions, i)
            end
        end
    end
    out.alreadyAtTarget = out.targetReached and out.start ~= nil and out.target ~= nil
        and out.start >= out.target and #out.steps == 0 or false
    if job.snap and job.snap.auctionDepthInputs then
        local missing = {}
        out.auctionDepthFallbackItems = {}
        for _, a in ipairs(out.actions) do
            if a.type == "buy" and a.source == "ah" and not (job.snap.auctionDepth or {})[a.item] and not missing[a.item] then
                missing[a.item] = true
                out.auctionDepthFallbackItems[#out.auctionDepthFallbackItems + 1] = a.item
            end
        end
        table.sort(out.auctionDepthFallbackItems)
        out.auctionDepthComplete = #out.auctionDepthFallbackItems == 0
    end
    return finishResult(job, out, state, status)
end

function S.NewJob(slug, opts)
    local E = getEconomy()
    local capLimit = solverCap()
    local defTarget = solverDefaultTarget()
    local defCpu = solverBudget("cpuLimitMs", 8000)
    local defFrontier = solverBudget("maxFrontier", 20000)
    local rawOpts = opts or {}
    opts = {}
    for k, v in pairs(rawOpts) do opts[k] = v end
    if opts.scheme == "net" then
        opts.recoveryEnabled = true
    elseif opts.recoveryEnabled == true and (opts.scheme == nil or opts.scheme == "cheapest" or opts.scheme == "cost") then
        opts.scheme = "net"
    elseif opts.scheme ~= "fixed" and opts.scheme ~= "fishing" then
        opts.scheme = "cost"
    end

    local historical = opts.routeSkeleton and opts.routeSkeleton.options
    local rawRisk = (historical and historical.routeRiskMode) or opts.routeRiskMode or opts.riskMode
    if rawRisk == nil and (opts.greenBudget == "pessimistic" or (historical and historical.greenBudget == "pessimistic")) then
        rawRisk = "quantile"
    end
    local routeRiskMode = (E and E.RouteRiskMode and E.RouteRiskMode(rawRisk))
        or ((rawRisk == "quantile" or rawRisk == "route_quantile") and "quantile" or "expected")
    local rawReserve = (historical and historical.reserveMode) or opts.reserveMode or opts.autoReserveMode
    local reserveMode = (E and E.ReserveMode and E.ReserveMode(rawReserve))
        or ((rawReserve == "expected" or rawReserve == "none") and "expected" or "safe")

    local j = {
        slug = slug,
        opts = opts,
        target = min(capLimit, max(1, floor(opts.target or defTarget))),
        expanded = 0,
        failures = {},
        blockers = {},
        cpuUsed = 0,
        cpuLimitMs = max(1, tonumber(opts.cpuLimitMs) or defCpu),
        status = "searching",
        generation = 0,
        progressVersion = 0,
        resultVersion = 0,
        frontierLimit = max(1, floor(tonumber(opts.maxFrontier) or defFrontier)),
        routeRiskMode = routeRiskMode,
        reserveMode = reserveMode,
        phase = "capture",
        phaseCpuMs = {},
    }

    local ops = 0
    local function cpuTime()
        return j.cpuUsed + (j.sliceStart and max(0, clock() - j.sliceStart) or 0)
    end
    local function tick()
        ops = ops + 1
        if ops % 256 == 0 and type(collectgarbage) == "function" then
            local heap = collectgarbage("count")
            j.depthHeapPeak = max(j.depthHeapPeak or 0, heap)
            if heap > (j.depthGcCheckpoint or 0) + 256 then
                pcall(collectgarbage, "step", 256)
                j.depthGcSteps = (j.depthGcSteps or 0) + 1
                j.depthGcCheckpoint = collectgarbage("count")
            end
        end
        if j.tickClockStride then
            j.tickClockCountdown = (j.tickClockCountdown or 0) - 1
            if j.tickClockCountdown > 0 and ops < 1000 then return end
            j.tickClockCountdown = j.tickClockStride
            local now = clock()
            if ops >= 1000 or (j.deadline and now >= j.deadline) then
                ops = 0
                coroutine.yield("work")
            end
            return
        end
        if ops >= 1000 or (j.deadline and clock() >= j.deadline) then
            ops = 0
            coroutine.yield("work")
        end
    end
    j.tick = tick

    local function fail(code, r, id, required, availableCount, learning)
        local key = tostring(code) .. ":" .. tostring(r and r.key or "") .. ":" .. tostring(id or "")
        if code == "learningDataMissing" and j.failures[key] then
            if j.collectFailures then j.collectFailures[key] = j.failures[key] end
            return
        end
        j.failures[key] = {
            code = code,
            recipe = r and r.key,
            item = id,
            spell = r and r.spell,
            profession = r and r.profession,
            required = required,
            available = availableCount,
        }
        if learning then
            local route = getRouteAuto()
            local d = (route and route.LearningDiagnostic and route.LearningDiagnostic(code, r, learning))
                or {
                    code = code,
                    recipe = r and r.key,
                    spell = r and r.spell,
                    profession = r and r.profession,
                    item = r and (r.formula or r.formulaID),
                    coverage = learning.coverage,
                    routeId = learning.routeId,
                    missingReasons = E.Copy(learning.missingReasons or {}),
                    learningStatus = learning.status,
                }
            for k, v in pairs(d) do j.failures[key][k] = v end
            if code == "learningDataMissing" or code == "learningRequirementsUnknown"
                or (type(learning.missingReasons) == "table" and #learning.missingReasons > 0) then
                j.learningGaps = j.learningGaps or {}
                local identity = r and r.key or key
                if not j.learningGaps[identity] then j.learningGapRevision = (j.learningGapRevision or 0) + 1 end
                j.learningGaps[identity] = d
            end
        end
        if j.collectFailures then j.collectFailures[key] = j.failures[key] end
    end

    local function vendorQuote(o)
        return o.unlimited == true and type(o.price) == "number" and o.price >= 0
            and o.available ~= false and o.purchasable ~= false and not o.hasExtendedCost
            and (not o.currencyID or o.currencyID == 0)
            and (not o.faction or not j.snap.faction or o.faction == j.snap.faction or o.faction == "Neutral" or o.faction == "N")
    end

    local vendorChoices = {}
    local function materialVendorOffers(id)
        if vendorChoices[id] then return vendorChoices[id] end
        local out, byPack = {}, {}
        for _, offer in ipairs(E.PreferredVendorOffers(j.snap.offers[id], vendorQuote)) do
            if vendorQuote(offer) then
                local size = offer.quantity or offer.bundleSize or 1
                local key = tostring(size) .. ":" .. tostring(offer.estimated and not offer.reference or false)
                local index = byPack[key]
                if not index then
                    out[#out + 1] = offer
                    byPack[key] = #out
                elseif offer.price < out[index].price then
                    out[index] = offer
                end
            end
            tick()
        end
        vendorChoices[id] = out
        return out
    end

    local function auctionQuote(id)
        local price = j.snap.prices[id]
        return not j.snap.nonAuctionable[id] and type(price) == "number" and price > 0
    end

    local function auctionCost(s, id, count)
        return getAuctionDepth().Quote(j.snap, id, s.ahUsed[id] or 0, count)
    end

    local function auctionRemaining(s, id)
        local supply = j.auctionSupply[id]
        return supply and max(0, supply.quantity - (s.ahUsed[id] or 0)) or huge
    end

    local function essenceConversion(id)
        local ess = getEssences()
        return j.snap.essenceConversions and ess and ess.ForItem(id)
    end

    local function allowed(r, s, reason, ignoreSkillGate)
        if slug ~= "__purchase" and r.profession ~= slug and not opts.allowSecondaryLeveling then
            fail("secondaryDisabled", r)
            return false
        end
        local p = E.Policy(j.opts.exclusions, r)
        if p == "ban" or (p == "level" and reason ~= "material") then
            fail("excluded", r, r.item)
            return false
        end
        local skill = s.skill[r.profession]
        if not skill then
            fail("professionMissing", r)
            return false
        end
        if not ignoreSkillGate and skill < r.learn and (r.profession == slug or not opts.allowSecondaryLeveling) then
            fail("skillRequired", r)
            return false
        end
        local eligibility = E.RouteRecipeEligibility or E.RecipeSpecializationAllowed
        local learning
        if eligibility then
            local probeState = s
            if ignoreSkillGate and skill < r.learn then
                probeState = clone(s)
                writable(probeState, "skill")[r.profession] = max(skill, r.learn, j.target)
            end
            local ok, why, detail = eligibility(r, j.snap, probeState)
            if not ok then
                fail(why or "specializationRequired", r, nil, nil, nil, detail)
                return false
            end
            learning = detail
        end
        local formula = (learning and learning.quote) or (j.formulaByRecipe and j.formulaByRecipe[r.key])
        if formula and not formula.usable then
            fail(formula.reason or "formulaUnavailable", r, formula.id)
            return false
        end
        if r.clientUnavailable then fail("clientUnavailable", r, r.item); return false end
        if r.clientPending then fail("clientDataPending", r, r.item); return false end
        if r.cooldown or r.cooldownUnknown then fail(r.cooldown and "cooldown" or "cooldownUnknown", r); return false end
        if r.outputConflict then fail("outputConflict", r, r.item); return false end
        if (r.availabilityUnknown or r.verified == false) and not r.clientAvailable then
            if not s.learned[r.key] and not s.learned[r.spell] then
                fail("availabilityUnknown", r)
                return false
            end
        end
        return true, learning
    end

    local function buyItemIntoState(s, id, need, reason, owner)
        if need <= 0 then return s end
        if j.snap.toolCraftOnlyItems and j.snap.toolCraftOnlyItems[id] then
            fail("materialUnavailable", nil, id, need)
            return nil
        end
        local remaining = auctionRemaining(s, id)
        local rows, _, complete, why = E.MaterialPurchases(id, need, {
            offers = materialVendorOffers(id),
            auction = auctionQuote(id) and j.snap.prices[id] or nil,
            supply = j.auctionSupply[id],
            available = remaining < huge and remaining or nil,
            faction = j.snap.faction,
            auctionCost = function(q) return auctionCost(s, id, q) end,
        }, tick)
        if not complete and why ~= "vendorEstimate" then
            fail(why or (j.auctionSupply[id] and remaining < need and "auctionSupplyLimited" or "materialUnavailable"), nil, id, need, remaining < huge and remaining or nil)
            return nil
        end
        local t = s
        for _, row in ipairs(rows or {}) do
            local count = row.count or row[2] or 0
            if count > 0 then
                local src = row.source or (row.vendor and "vendor" or "ah")
                local bundle = row.bundleSize or 1
                local bPrice = row.bundlePrice or (row.cost / (count / bundle))
                local u = clone(t)
                local cost = row.cost
                if src == "ah" and j.snap.auctionDepth and j.snap.auctionDepth[id] then
                    cost = auctionCost(t, id, count)
                    if not cost then
                        fail("auctionSupplyLimited", nil, id, count, auctionRemaining(t, id))
                        return nil
                    end
                    bPrice = cost / (count / bundle)
                end
                if src == "ah" and j.auctionSupply[id] then
                    if count > auctionRemaining(t, id) then
                        fail("auctionSupplyLimited", nil, id, count, auctionRemaining(t, id))
                        return nil
                    end
                    writable(u, "ahUsed")[id] = (u.ahUsed[id] or 0) + count
                end
                writable(u, "inv")[id] = (u.inv[id] or 0) + count
                u.money = u.money + cost
                log(u, stampStock({
                    type = "buy",
                    item = id,
                    count = count,
                    cost = cost,
                    source = src,
                    npcID = row.npcID,
                    reason = reason,
                    url = row.url,
                    bundleSize = bundle,
                    bundlePrice = bPrice,
                    owner = owner,
                    unpriced = row.unpriced,
                    estimated = row.estimated,
                    reference = row.reference,
                    quoteSource = row.quoteSource or row.source,
                    priceSource = row.priceSource,
                    priceBasis = row.priceBasis,
                    verifiedAt = row.verifiedAt,
                }, row))
                if row.estimated and not row.reference then
                    diagnostic(u, "vendor:" .. id .. ":" .. tostring(row.npcID), "vendorEstimate", id)
                end
                if row.unpriced then
                    diagnostic(u, src .. ":" .. id, src == "vendor" and "vendorPriceUnknown" or "materialPriceUnknown", id)
                end
                t = u
            end
        end
        return t
    end

    local function stateFormula(r, s, remaining, purchaseSource)
        if E.SelectLearningRoute then
            local probeState = s
            if (s.skill[r.profession] or 0) < r.learn then
                probeState = clone(s)
                writable(probeState, "skill")[r.profession] = r.learn
            end
            local ok, _, detail = E.SelectLearningRoute(r, j.snap, probeState, remaining, purchaseSource)
            return ok and detail and detail.quote or nil
        end
        return E.FormulaFor(r, j.snap, remaining, purchaseSource)
    end

    local function learnFormula(s, r, selectedLearning)
        local ok, why, learning = true, nil, selectedLearning
        if not learning then
            local fn = E.RouteRecipeEligibility or E.RecipeSpecializationAllowed
            if fn then ok, why, learning = fn(r, j.snap, s) end
        end
        if not ok then
            fail(why or "learningDataMissing", r, nil, nil, nil, learning)
            return nil
        end
        local f = (learning and learning.quote) or (j.formulaByRecipe and j.formulaByRecipe[r.key])
        if not f or f.known or s.learned[r.key] or s.learned[r.spell] then return s end
        if not f.usable then
            fail(f.reason or "formulaUnavailable", r, f.id)
            return nil
        end
        local key = f.id or r.key
        if s.formulaPaid[key] then return s end
        if f.source == "ah" and auctionRemaining(s, f.id) < 1 then
            f = stateFormula(r, s, auctionRemaining(s, f.id))
            if not f or not f.usable then
                fail("auctionSupplyLimited", r, f and f.id)
                return nil
            end
        end
        local t = clone(s)
        writable(t, "formulaPaid")[key] = true
        writable(t, "learned")[r.key] = true
        t.money = t.money + (f.cost or 0)
        if f.automatic or (f.source == "trainer" and f.cost == nil) then return t end
        if f.source == "ah" and j.auctionSupply[f.id] then
            writable(t, "ahUsed")[f.id] = (t.ahUsed[f.id] or 0) + 1
        end
        if f.unpriced then
            diagnostic(
                t,
                "formula:" .. tostring(key),
                (f.source == "trainer" and "learningPriceUnknown") or "formulaPriceUnknown",
                f.id or r.key
            )
        end
        if f.availabilityUncertain then diagnostic(t, "formulaStock:" .. tostring(key), "formulaStockUnknown", f.id or r.key) end
        log(t, {
            type = "formula",
            item = f.id,
            count = f.bundleSize or 1,
            cost = f.cost or 0,
            source = f.source,
            owner = r.key,
            unpriced = f.unpriced,
            formula = E.Copy(f),
        })
        return t
    end

    local function convertInState(s, c, n, owner)
        if not c or n < 1 or available(s, c.inputItemID) < c.inputCount * n then return nil end
        local t = clone(s)
        consume(t, c.inputItemID, c.inputCount * n)
        writable(t, "inv")[c.outputItemID] = (t.inv[c.outputItemID] or 0) + c.outputCount * n
        local skill = t.skill.enchanting or t.skill[slug] or 1
        log(t, {
            type = "convert",
            profession = "enchanting",
            count = n,
            from = skill,
            to = skill,
            item = c.outputItemID,
            outputCount = c.outputCount * n,
            inputs = { { c.inputItemID, c.inputCount * n } },
            outputs = { { c.outputItemID, c.outputCount * n } },
            conversion = E.Copy(c),
            manual = true,
            essence = true,
            reason = "essence",
            owner = owner,
            usableOutput = true,
        })
        return t
    end

    local function executeCraftStep(s, r, n, fromSkill, toSkill, reason, safeCrafts, selectedLearning, directCost, directUnpriced)
        if n <= 0 then return s end
        local t = learnFormula(s, r, selectedLearning)
        if not t then return nil end
        t = clone(t)
        local p = r.profession
        local curSk = max(t.skill[p] or 1, fromSkill or (t.skill[p] or 1))
        local tgtSk = max(curSk, toSkill or curSk)
        while tgtSk > (t.cap[p] or capLimit) and (t.cap[p] or capLimit) < capLimit do
            writable(t, "cap")[p] = nextCapTier(t.cap[p] or capLimit, capLimit)
        end
        local inputs = {}
        for _, m in ipairs(r.mats or {}) do
            local req = m[2] * n
            if available(t, m[1]) < req then
                t = buyItemIntoState(t, m[1], req - available(t, m[1]), "material", r.key)
                if not t then return nil end
                t = clone(t)
            end
            consume(t, m[1], req)
            inputs[#inputs + 1] = { m[1], req }
        end
        local produced = r.item and (r.count * n) or 0
        local materialProfession = opts.materialProfession or slug
        local usable = r.profession == materialProfession or materialProfession == "__purchase" or (j.purchasePriced and j.purchasePriced[r.item]) or (opts.allowSecondaryLeveling == true)
        if r.item and produced > 0 then
            writable(t, "inv")[r.item] = (t.inv[r.item] or 0) + produced
            writable(t, "produced")[r.item] = (t.produced[r.item] or 0) + produced
            writable(t, "priorityProduced")[r.item] = (t.priorityProduced[r.item] or 0) + produced
            if not usable then
                writable(t, "unusable")[r.item] = (t.unusable[r.item] or 0) + produced
            end
        end
        writable(t, "skill")[p] = tgtSk
        t.plannedTarget = max(t.plannedTarget or 0, p == slug and tgtSk or 0)
        if p == slug and t.lastRecipe ~= r.key then
            t.switches = (t.switches or 0) + 1
            t.lastRecipe = r.key
        end
        log(t, {
            type = "craft",
            profession = p,
            spell = r.spell,
            count = n,
            from = curSk,
            to = tgtSk,
            expectedGain = tgtSk - curSk,
            safeCrafts = safeCrafts or n,
            directCost = directCost,
            directUnpriced = directUnpriced,
            item = r.item,
            outputCount = produced,
            outputs = (r.item and produced > 0) and { { r.item, produced } } or {},
            inputs = inputs,
            reason = reason,
            station = r.station,
            usableOutput = usable and true or false,
            learningRoute = selectedLearning and selectedLearning.route,
        })
        return t
    end

    local function finishToolInState(s, goal, directCost, directUnpriced)
        if s.completedToolGoals[goal.id] then return s end
        local t = clone(s)
        writable(t, "completedToolGoals")[goal.id] = true
        log(t, {
            type = "tool_goal",
            item = goal.item,
            count = 1,
            goalID = goal.id,
            profession = goal.profession,
            minSkill = goal.minSkill,
            directCost = directCost,
            directUnpriced = directUnpriced,
        })
        return t
    end

    local function goalBlocked(goal)
        local context = j.snap.specializationContext or {}
        local why = goal.blockedReason or (context.selectionConflict and "specializationChoiceConflict")
        if not why and (context.reason == "specializationUnknown" or context.actual == "unknown" or goal.abilityUnknown) then
            why = "specializationUnknown"
        end
        local level = j.snap.playerLevel or j.snap.level or context.level
        if not why and goal.minLevel and (not level or level < goal.minLevel) then
            why = level and "specializationLevelRequired" or "specializationLevelUnknown"
        end
        if why then
            fail(why, { key = goal.id, profession = goal.profession, spell = goal.abilityID, minLevel = goal.minLevel })
            return true
        end
        return false
    end

    -- Exact recursive DAG procurement solver (used by S.Procure / S.ProcureMany, tool goals, spec quests, & skeleton)
    local function procureItemExact(s, id, need, reason, owner, visiting, ownProfOnly, forceCraft)
        tick()
        if need <= 0 or available(s, id) >= need then return s end
        visiting = visiting or {}
        local missing = need - available(s, id)
        local best = nil

        local function considerCandidate(cand)
            if cand and available(cand, id) >= need and betterState(cand, best, j.recovery and j.snap or nil) then
                best = cand
            end
        end

        local craftOnly = forceCraft or (j.snap.toolCraftOnlyItems and j.snap.toolCraftOnlyItems[id])

        -- 1. Direct purchase (AH + Vendor integer packs)
        if not craftOnly then
            local savedFailures = copyStateMap(j.failures)
            local direct = buyItemIntoState(s, id, missing, reason, owner)
            if direct then
                considerCandidate(direct)
            else
                j.failures = savedFailures
            end
        end

        -- 2. Essence conversion (3x Lesser <-> 1x Greater, including partial direct + convert!)
        local conv = not craftOnly and essenceConversion(id)
        if conv and not visiting["ess:" .. tostring(conv.key)] then
            local nextVis = copyStateMap(visiting)
            nextVis["ess:" .. tostring(conv.key)] = true
            local maxConv = ceil(missing / conv.outputCount)
            local tryCounts = { maxConv }
            if conv.outputCount > 1 and maxConv > 1 then
                tryCounts[#tryCounts + 1] = maxConv - 1
            end
            local availSrc = available(s, conv.inputItemID)
            local remSrc = auctionRemaining(s, conv.inputItemID)
            if remSrc < huge then
                local capConv = floor((availSrc + remSrc) / conv.inputCount)
                if capConv >= 1 and capConv < maxConv then
                    tryCounts[#tryCounts + 1] = capConv
                end
            end
            local seenC = {}
            for _, nConv in ipairs(tryCounts) do
                if nConv >= 1 and not seenC[nConv] then
                    seenC[nConv] = true
                    local savedF = copyStateMap(j.failures)
                    local t1 = procureItemExact(s, conv.inputItemID, conv.inputCount * nConv, "essence", owner, nextVis, ownProfOnly, false)
                    local t2 = t1 and convertInState(t1, conv, nConv, owner)
                    if t2 then
                        local remNeed = need - available(t2, id)
                        local t3 = remNeed > 0 and buyItemIntoState(t2, id, remNeed, reason, owner) or t2
                        if t3 then considerCandidate(t3) else j.failures = savedF end
                    else
                        j.failures = savedF
                    end
                end
            end
        end

        -- 3. Craftable intermediates (including mixed craft k + buy rest when output > 1 or finite stock!)
        if not visiting[id] then
            local nextVis = copyStateMap(visiting)
            nextVis[id] = true
            local materialProfession = opts.materialProfession or slug
            for _, r in ipairs(j.snap.byItem[id] or {}) do
                local ownOK = (ownProfOnly and r.profession == ownProfOnly)
                    or (not ownProfOnly and ((j.purchasePriced and j.purchasePriced[id]) or r.profession == materialProfession or materialProfession == "__purchase"))
                if ownOK and type(r.count) == "number" and r.count > 0 then
                    local usable, learning = allowed(r, s, "material", false)
                    if usable then
                        local maxCrafts = ceil(missing / r.count)
                        local craftTrials = { maxCrafts }
                        if not craftOnly and r.count > 1 and maxCrafts >= 1 then
                            if maxCrafts - 1 >= 1 then craftTrials[#craftTrials + 1] = maxCrafts - 1 end
                        end
                        local seenK = {}
                        for _, kCrafts in ipairs(craftTrials) do
                            if kCrafts >= 1 and not seenK[kCrafts] then
                                seenK[kCrafts] = true
                                local savedF = copyStateMap(j.failures)
                                local cur = learnFormula(s, r, learning)
                                if cur then
                                    for _, m in ipairs(r.mats or {}) do
                                        cur = procureItemExact(cur, m[1], available(cur, m[1]) + m[2] * kCrafts, "material", r.key, nextVis, nil, false)
                                        if not cur then break end
                                    end
                                end
                                if cur then
                                    cur = executeCraftStep(cur, r, kCrafts, cur.skill[r.profession], cur.skill[r.profession], "material", kCrafts, learning)
                                end
                                if cur then
                                    local remAfter = need - available(cur, id)
                                    if remAfter > 0 then
                                        cur = not craftOnly and buyItemIntoState(cur, id, remAfter, reason, owner) or nil
                                    end
                                end
                                if cur then
                                    considerCandidate(cur)
                                else
                                    j.failures = savedF
                                end
                            end
                        end
                    end
                end
            end
        end

        if not best then
            local rem = auctionRemaining(s, id)
            fail(j.auctionSupply[id] and rem < missing and "auctionSupplyLimited" or "materialUnavailable", nil, id, missing, rem < huge and rem or nil)
        end
        return best
    end

    local function procureGoalTool(s, goal)
        if s.completedToolGoals[goal.id] then return s end
        if available(s, goal.item) >= 1 then
            return finishToolInState(s, goal)
        end
        local t = procureItemExact(s, goal.item, 1, "tool", "tool:" .. goal.id, nil, goal.profession, goal.bindOnPickup == true)
        if not t then return nil end
        return finishToolInState(t, goal)
    end

    local function completeSpecQuestInState(s, goal)
        if s.completedSpecializationGoals[goal.id] or s.specializationAbilities[goal.abilityID] then return s end
        if goalBlocked(goal) then return nil end
        local cur = s
        for _, m in ipairs(goal.inputs or {}) do
            cur = procureItemExact(cur, m[1], available(cur, m[1]) + m[2], "specialization", "quest:" .. goal.id, nil, goal.profession, false)
            if not cur then return nil end
            cur = clone(cur)
            consume(cur, m[1], m[2])
        end
        cur = clone(cur)
        writable(cur, "specializationAbilities")[goal.abilityID] = true
        writable(cur, "completedSpecializationGoals")[goal.id] = true
        local sk = cur.skill[goal.profession] or 1
        log(cur, {
            type = "specialization_quest",
            profession = goal.profession,
            from = sk,
            to = sk,
            quest = E.Copy(goal),
            inputs = E.Copy(goal.inputs),
            goalID = goal.id,
            questID = goal.questID,
            abilityID = goal.abilityID,
        })
        return cur
    end

    local function rebuildSkeleton(first)
        local skel = opts.routeSkeleton
        local blocked = E.StepsHaveNIP and E.StepsHaveNIP(skel.steps) and "catalogueFiltered" or nil
        if not opts.allowSecondaryLeveling then
            for _, step in ipairs(skel.steps) do
                if step.profession and step.profession ~= slug then blocked = "secondaryDisabled"; break end
            end
        end
        if blocked then
            fail(blocked)
            j.status = "recalculate_required"
            j.searchTermination = "skeleton_rejected"
            j.exhausted = true
            j.result = S.Result(j, nil, j.status)
            j.finished = true
            return "done"
        end
        local events, seen = {}, {}
        local balance, demand = {}, {}
        j.skeletonFormulas = {}
        for id in pairs(first.inv) do balance[id] = available(first, id) end
        local function addInput(id, n)
            balance[id] = (balance[id] or 0) - n
            demand[id] = max(demand[id] or 0, -balance[id])
        end
        local valid = true
        for _, step in ipairs(skel.steps) do
            local p = step.profession or slug
            if not seen[p] then
                if first.skill[p] == nil then fail("professionMissing", { profession = p }); valid = false end
                writable(first, "skill")[p] = step[1]
                seen[p] = true
            end
            local event = { step = step, inputs = {}, outputs = {} }
            if step.kind == "specialization_quest" then
                for _, goal in ipairs(j.snap.specializationGoals or {}) do
                    if goal.id == step.goalID and goal.questID == step.questID and goal.abilityID == step.abilityID then
                        event.goal = goal
                        event.inputs = goal.inputs
                        break
                    end
                end
                if not event.goal then fail("specializationChanged"); valid = false end
            elseif step.kind == "essence_conversion" then
                local c = essenceConversion(step.targetItem)
                if c and c.inputItemID == step.sourceItem then
                    event.conversion = c
                    event.inputs = { { c.inputItemID, c.inputCount * step[4] } }
                    event.outputs = { { c.outputItemID, c.outputCount * step[4] } }
                else
                    fail("executionInvalid"); valid = false
                end
            elseif not step.checkpoint then
                local r = j.snap.byKey[p .. ":" .. step[3]]
                event.recipe = r
                local f = r and j.formulaByRecipe[r.key]
                if f and not f.known and f.source == "ah" then j.skeletonFormulas[f.id or r.key] = f.id end
                if not r then
                    fail("clientDataPending", { spell = step[3], profession = p }); valid = false
                else
                    for _, m in ipairs(r.mats) do event.inputs[#event.inputs + 1] = { m[1], m[2] * step[4] } end
                    local usable = p == slug or (j.purchasePriced and j.purchasePriced[r.item])
                    if r.item and usable then event.outputs = { { r.item, r.count * step[4] } } end
                end
            end
            for _, m in ipairs(event.inputs) do addInput(m[1], m[2]) end
            for _, m in ipairs(event.outputs) do balance[m[1]] = (balance[m[1]] or 0) + m[2] end
            events[#events + 1] = event
            tick()
        end
        for _, goal in ipairs(j.snap.toolGoals or {}) do
            demand[goal.item] = max(demand[goal.item] or 0, 1 - (balance[goal.item] or 0))
        end
        local current = valid and first or nil
        if current then
            local demIds = {}
            for id, qty in pairs(demand) do
                if qty > 0 and not (j.snap.toolCraftOnlyItems and j.snap.toolCraftOnlyItems[id]) then
                    demIds[#demIds + 1] = id
                end
            end
            table.sort(demIds)
            for _, id in ipairs(demIds) do
                current = buyItemIntoState(current, id, demand[id], "material", nil)
                if not current then break end
            end
        end
        for _, event in ipairs(events) do
            if not current then break end
            local step = event.step
            local p = step.profession or slug
            if event.recipe then
                local r = event.recipe
                local okU, learning = allowed(r, current, step.reason or "level", false)
                if not okU then current = nil; break end
                current = executeCraftStep(current, r, step[4], step[1], step[2], step.reason or "level", step.safeCrafts or step[4], learning)
            elseif event.goal then
                current = completeSpecQuestInState(current, event.goal)
            elseif event.conversion then
                current = convertInState(current, event.conversion, step[4])
            elseif step.checkpoint then
                current = clone(current)
                writable(current, "skill")[p] = step[2]
                log(current, { type = "gather", profession = p, from = step[1], to = step[2], count = 0, spell = step[3], reason = step.reason })
            end
            tick()
        end
        if current then
            for _, goal in ipairs(j.snap.toolGoals or {}) do
                current = procureGoalTool(current, goal)
                if not current then break end
            end
        end
        j.seedDone = true
        j.exhausted = true
        j.searchTermination = "skeleton_rebuilt"
        restrict(j, "saved_route")
        local status = skel.status == "complete" and "complete" or skel.status == "stopped" and "stopped" or "interrupted"
        if current and skel.status == "complete" and not goalsComplete(j, current) then
            fail("executionInvalid")
            current = nil
        end
        j.status = current and status or "recalculate_required"
        j.best = current and goalsComplete(j, current) and current or nil
        j.preview = current
        j.result = S.Result(j, j.best, j.status)
        if not current then
            j.result.steps = E.Copy(skel.steps)
            j.result.costComplete = false
            j.result.completeCost = false
            j.result.priced = false
        end
        j.finished = true
        return "done"
    end

    local function buildStageProblem(profSlug, startSk, targetSk, stateAtStart, schemeMode, retiredLevelSpells)
        local recipes = {}
        local learningBySpell = {}
        local toolGoalsBySpell = {}
        local profTools = {}
        local seenToolCatTier = {}
        retiredLevelSpells = retiredLevelSpells or {}

        local rawProfTools = {}
        for _, goal in ipairs(j.snap.toolGoals or {}) do
            if goal.profession == profSlug and (goal.minSkill or 0) < targetSk then
                local mapped = TOOL_ITEM_TO_KEY[goal.item] or { "tool_" .. tostring(goal.item), goal.tier or 1 }
                local tcat, ttier = mapped[1], mapped[2]
                seenToolCatTier[tcat .. ":" .. ttier] = goal.item
                rawProfTools[#rawProfTools + 1] = {
                    item_id = goal.item,
                    tool_category = tcat,
                    tier = ttier,
                    min_skill = goal.minSkill or 1,
                    bind_on_pickup = goal.bindOnPickup == true,
                    craft_spell_id = goal.spell,
                }
                if goal.spell then
                    toolGoalsBySpell[goal.spell] = { tcat, ttier, goal.item }
                end
            end
        end

        local recipeBySpell = {}
        j.collectFailures = {}
        for _, r in ipairs(j.snap.byProfession[profSlug] or {}) do
            local isLevelCand = (not retiredLevelSpells[r.spell]) and (r.grey or 0) > startSk and (r.learn or 1) < targetSk
            local isMatCand = r.item and r.count and r.count > 0 and (r.learn or 1) <= targetSk
            if isLevelCand or isMatCand then
                local reason = isLevelCand and "level" or "material"
                local okU, learning = allowed(r, stateAtStart, reason, true)
                if okU then
                    learningBySpell[r.spell] = learning
                    recipeBySpell[r.spell] = r
                    local f = (learning and learning.quote) or (j.formulaByRecipe and j.formulaByRecipe[r.key])
                    local known = stateAtStart.learned[r.key] or stateAtStart.learned[r.spell] or (f and f.known) or false
                    local unlockCost = 0.0
                    local teachItem = nil
                    if f and not known then
                        if f.unpriced and f.source ~= "trainer" then
                            unlockCost = 1e9
                        else
                            unlockCost = tonumber(f.cost) or 0.0
                        end
                        teachItem = f.id
                    end
                    local reagents = {}
                    for _, m in ipairs(r.mats or {}) do
                        reagents[#reagents + 1] = { m[1], m[2] }
                    end
                    local outputs = {}
                    if r.item and r.count and r.count > 0 then
                        outputs[1] = { r.item, r.count }
                    end
                    local reqTools = {}
                    if type(r.requiredTools) == "table" then
                        for _, tk in ipairs(r.requiredTools) do
                            local mapped = REQUIRED_TOOL_MAP[tostring(tk)]
                            if mapped and seenToolCatTier[mapped[1] .. ":" .. mapped[2]] then
                                reqTools[#reqTools + 1] = { mapped[1], mapped[2] }
                            end
                        end
                    end
                    local prodTool = toolGoalsBySpell[r.spell]
                    recipes[r.spell] = {
                        spell_id = r.spell,
                        kind = "craft",
                        name = tostring(r.spell),
                        min_skill = max(1, floor(r.learn or 1)),
                        orange = r.orange or r.learn or 1,
                        yellow = r.yellow or r.learn or 1,
                        green = r.green or r.yellow or r.learn or 1,
                        grey = retiredLevelSpells[r.spell] and 1 or (r.grey or 1),
                        reagents = reagents,
                        outputs = outputs,
                        unlock_cost_copper = unlockCost,
                        teaching_item_id = teachItem,
                        learn_kind = f and f.source or "trainer",
                        required_tools = reqTools,
                        produces_tool = prodTool,
                    }
                end
            end
            tick()
        end

        -- Include eligible partner-profession intermediate recipes when secondary crafting is enabled
        if opts.allowSecondaryLeveling then
            for pSlug, pInfo in pairs(j.snap.professions or {}) do
                if pSlug ~= profSlug and pSlug ~= "__purchase" then
                    local pSk = stateAtStart.skill[pSlug] or tonumber(pInfo.cur) or 0
                    if pSk > 0 then
                        for _, r in ipairs(j.snap.byProfession[pSlug] or {}) do
                            if not recipes[r.spell] and r.item and j.reusable and j.reusable[r.item]
                                and r.count and r.count > 0 and (r.learn or 1) <= pSk then
                                local okU, learning = allowed(r, stateAtStart, "material", false)
                                if okU then
                                    learningBySpell[r.spell] = learning
                                    recipeBySpell[r.spell] = r
                                    local f = (learning and learning.quote) or (j.formulaByRecipe and j.formulaByRecipe[r.key])
                                    local known = stateAtStart.learned[r.key] or stateAtStart.learned[r.spell] or (f and f.known) or false
                                    local unlockCost = (f and not known) and ((f.unpriced and f.source ~= "trainer") and 1e9 or (tonumber(f.cost) or 0.0)) or 0.0
                                    local reagents = {}
                                    for _, m in ipairs(r.mats or {}) do reagents[#reagents + 1] = { m[1], m[2] } end
                                    recipes[r.spell] = {
                                        spell_id = r.spell,
                                        kind = "craft",
                                        name = tostring(r.spell),
                                        min_skill = 1,
                                        orange = 1,
                                        yellow = 1,
                                        green = 1,
                                        grey = 1,
                                        reagents = reagents,
                                        outputs = { { r.item, r.count } },
                                        unlock_cost_copper = unlockCost,
                                        teaching_item_id = (f and not known) and f.id or nil,
                                        learn_kind = f and f.source or "trainer",
                                        required_tools = {},
                                        produces_tool = nil,
                                    }
                                end
                            end
                            tick()
                        end
                    end
                end
            end
        end

        local essencePairs = {}
        local ess = getEssences()
        if j.snap.essenceConversions and ess and type(ess.Pairs) == "function" then
            for idx, pair in ipairs(ess.Pairs()) do
                essencePairs[#essencePairs + 1] = {
                    pair_key = tostring(pair.key or idx),
                    lesser_item_id = pair.lesserID,
                    greater_item_id = pair.greaterID,
                    ratio = 3,
                }
            end
        end

        local gatherBands = {}
        if profSlug == "mining" then
            local DS = getDS()
            local mg = DS and type(DS.GatheringGuide) == "function" and DS.GatheringGuide("mining") or nil
            if type(mg) == "table" and type(mg.bands) == "table" and #mg.bands > 0 then
                for _, b in ipairs(mg.bands) do
                    gatherBands[#gatherBands + 1] = {
                        min_skill = tonumber(b.minSkill) or 1,
                        max_skill = tonumber(b.maxSkill) or 300,
                        item_ids = {},
                        zone_ids = {},
                    }
                end
            else
                gatherBands[1] = { min_skill = 1, max_skill = 300, item_ids = {}, zone_ids = {} }
            end
        end

        local problem = {
            profession = profSlug,
            max_skill_cap = capLimit,
            recipes = recipes,
            tools = profTools,
            essence_pairs = essencePairs,
            gather_bands = gatherBands,
        }

        local function buyFn(itemID)
            if j.snap.toolCraftOnlyItems and j.snap.toolCraftOnlyItems[itemID] then
                return {}
            end
            local tiers = {}
            for _, o in ipairs(materialVendorOffers(itemID)) do
                local size = o.quantity or o.bundleSize or 1
                local p = o.price
                if type(p) == "number" and p >= 0 and size >= 1 then
                    tiers[#tiers + 1] = {
                        unit_price = p / size,
                        max_qty = huge,
                        bundle_size = size,
                        source = "vendor",
                    }
                end
            end
            if auctionQuote(itemID) then
                local rem = auctionRemaining(stateAtStart, itemID)
                local book = j.snap.auctionDepth and j.snap.auctionDepth[itemID]
                if book and type(book.prices) == "table" and #book.prices > 0 then
                    local used = stateAtStart.ahUsed[itemID] or 0
                    local capQ = rem < huge and (used + rem) or book.total
                    local prevCum = 0
                    for idx = 1, #book.prices do
                        local cum = min(book.quantity[idx] or 0, capQ)
                        local availTier = max(0, cum - max(prevCum, used))
                        prevCum = book.quantity[idx] or prevCum
                        if availTier > 0 then
                            tiers[#tiers + 1] = {
                                unit_price = book.prices[idx],
                                max_qty = availTier,
                                bundle_size = 1,
                                source = "ah",
                            }
                        end
                        if prevCum >= capQ then break end
                    end
                    elseif rem > 0 then
                        tiers[#tiers + 1] = {
                            unit_price = j.snap.prices[itemID],
                            max_qty = rem,
                            bundle_size = 1,
                            source = "ah",
                        }
                    end
                end
                if #tiers == 0 and j.snap.onlyAH == false then
                    tiers[1] = {
                        unit_price = 1e9,
                        max_qty = huge,
                        bundle_size = 1,
                        source = "unpriced",
                    }
                end
                return tiers
            end

        local function sellFn(itemID)
            if not j.recovery then return 0.0 end
            local q = j.snap.recovery and j.snap.recovery.quotes and j.snap.recovery.quotes[itemID]
            if q and not q.missing and type(q.unit) == "number" and q.unit > 0 then
                return q.unit
            end
            return 0.0
        end

        local ownedItems = {}
        for id, cnt in pairs(stateAtStart.inv or {}) do
            local av = available(stateAtStart, id)
            if av > 0 then ownedItems[id] = av end
        end
        local ownedTools = {}
        for id in pairs(j.snap.ownedToolItems or {}) do ownedTools[id] = true end
        for _, goal in ipairs(j.snap.toolGoals or {}) do
            if stateAtStart.completedToolGoals[goal.id] or available(stateAtStart, goal.item) >= 1 then
                ownedTools[goal.item] = true
            end
        end
        local knownSpells = {}
        for _, r in ipairs(j.snap.byProfession[profSlug] or {}) do
            if stateAtStart.learned[r.key] or stateAtStart.learned[r.spell] then
                knownSpells[r.spell] = true
            end
        end

        local playerCtx = {
            faction = j.snap.faction or "N",
            owned_items = ownedItems,
            owned_tools = ownedTools,
            known_recipes = knownSpells,
            use_owned_inventory = next(ownedItems) ~= nil,
        }

        for _, t in ipairs(rawProfTools) do
            local canOwn = ownedTools[t.item_id] or (ownedItems[t.item_id] and ownedItems[t.item_id] > 0)
            local canCraft = t.craft_spell_id and recipes[t.craft_spell_id] ~= nil
            local canBuy = (not t.bind_on_pickup) and (#buyFn(t.item_id) > 0)
            if canOwn or canCraft or canBuy then
                profTools[#profTools + 1] = t
            end
        end
        problem.tools = profTools

        local isSmallSpan = (targetSk - startSk) < 10
        local solveOpts = {
            objective = j.recovery and "min_net" or "min_cost",
            risk_mode = (j.routeRiskMode == "quantile") and "route_quantile" or "expected",
            confidence = solverReg("confidence", 0.90),
            prep_confidence = solverReg("prepConfidence", 0.90),
            switch_penalty_copper = solverReg("switchPenaltyCopper", 300),
            switch_cost_ratio = isSmallSpan and 0.0 or solverReg("switchCostRatio", 0.35),
            min_segment_points = isSmallSpan and 1 or solverReg("minSegmentPoints", 5),
            forbid_recipe_repeat = solverReg("forbidRecipeRepeat", true),
            high_cost_fail_aversion = solverReg("highCostFailAversion", 0.55),
            high_cost_green_threshold_copper = solverReg("highCostGreenThresholdCopper", 10000),
            enable_field_mining_fallback = true,
            max_subgradient_iters = solverReg("maxSubgradientIters", 28),
            max_bnb_nodes = solverReg("maxBnbNodes", 250),
            tick = tick,
        }

        return problem, { buy_fn = buyFn, sell_fn = sellFn }, playerCtx, solveOpts, learningBySpell, recipeBySpell
    end

    local function applySolutionToState(stateBefore, profSlug, sol, learningBySpell, recipeBySpell)
        if not sol or sol.status == "unreachable" or #(sol.steps or {}) == 0 then
            return nil
        end
        local cur = clone(stateBefore)
        recipeBySpell = recipeBySpell or {}
        local function lookupStepRecipe(spellID)
            return recipeBySpell[spellID] or (j.snap.byKey and j.snap.byKey[profSlug .. ":" .. tostring(spellID)])
        end

        -- Pre-calculate net external demand across all steps in `sol.steps` so Vendor Bundles + AH Depth
        -- are purchased in a single optimal batch per item before consumption!
        local simInv = {}
        for id in pairs(cur.inv or {}) do simInv[id] = available(cur, id) end
        local extDemand = {}
        local safeSimInv = copyStateMap(simInv)
        local safeExtDemand = {}
        local baseGrossInputs, baseGrossOutputs = {}, {}
        local safeGrossInputs, safeGrossOutputs = {}, {}
        local stepExtUnits = {}

        -- Reserve formula items first if any recipe unlocks via AH
        for _, st in ipairs(sol.steps) do
            if st.spell_id and st.spell_id > 0 then
                local r = lookupStepRecipe(st.spell_id)
                if r then
                    local learning = learningBySpell[r.spell]
                    cur = learnFormula(cur, r, learning)
                    if not cur then return nil end
                end
            end
        end

        -- Refresh simInv after formula payments
        for id in pairs(cur.inv or {}) do simInv[id] = available(cur, id); safeSimInv[id] = simInv[id] end

        for idx, st in ipairs(sol.steps) do
            stepExtUnits[idx] = {}
            if st.kind == "tool_buy" then
                local tid = st.outputs and st.outputs[1] and st.outputs[1][1]
                if tid then
                    local miss = max(0, 1 - (simInv[tid] or 0))
                    if miss > 0 then
                        extDemand[tid] = (extDemand[tid] or 0) + miss
                        stepExtUnits[idx][tid] = (stepExtUnits[idx][tid] or 0) + miss
                        simInv[tid] = (simInv[tid] or 0) + miss
                    end
                    local smiss = max(0, 1 - (safeSimInv[tid] or 0))
                    if smiss > 0 then
                        safeExtDemand[tid] = (safeExtDemand[tid] or 0) + smiss
                        safeSimInv[tid] = (safeSimInv[tid] or 0) + smiss
                    end
                end
            elseif st.kind == "essence_convert" then
                local inPair = st.reagents and st.reagents[1]
                local outPair = st.outputs and st.outputs[1]
                if inPair and outPair then
                    local inId, inPer = inPair[1], inPair[2] / max(1, st.planned_crafts)
                    local outId, outPer = outPair[1], outPair[2] / max(1, st.planned_crafts)
                    local req = inPer * st.planned_crafts
                    baseGrossInputs[inId] = (baseGrossInputs[inId] or 0) + req
                    baseGrossOutputs[outId] = (baseGrossOutputs[outId] or 0) + outPer * st.planned_crafts
                    local miss = max(0, req - (simInv[inId] or 0))
                    if miss > 0 then
                        extDemand[inId] = (extDemand[inId] or 0) + miss
                        stepExtUnits[idx][inId] = (stepExtUnits[idx][inId] or 0) + miss
                        simInv[inId] = (simInv[inId] or 0) + miss
                    end
                    simInv[inId] = (simInv[inId] or 0) - req
                    simInv[outId] = (simInv[outId] or 0) + outPer * st.planned_crafts

                    local sCount = max(st.planned_crafts, st.safe_crafts or st.planned_crafts)
                    local sReq = inPer * sCount
                    safeGrossInputs[inId] = (safeGrossInputs[inId] or 0) + sReq
                    safeGrossOutputs[outId] = (safeGrossOutputs[outId] or 0) + outPer * sCount
                    local sMiss = max(0, sReq - (safeSimInv[inId] or 0))
                    if sMiss > 0 then
                        safeExtDemand[inId] = (safeExtDemand[inId] or 0) + sMiss
                        safeSimInv[inId] = (safeSimInv[inId] or 0) + sMiss
                    end
                    safeSimInv[inId] = (safeSimInv[inId] or 0) - sReq
                    safeSimInv[outId] = (safeSimInv[outId] or 0) + outPer * sCount
                end
            elseif st.kind ~= "gather" and st.spell_id then
                local r = lookupStepRecipe(st.spell_id)
                if r then
                    local nPlan = st.planned_crafts
                    local nSafe = max(nPlan, st.safe_crafts or nPlan)
                    for _, m in ipairs(r.mats or {}) do
                        local mid, mcnt = m[1], m[2]
                        local req = mcnt * nPlan
                        baseGrossInputs[mid] = (baseGrossInputs[mid] or 0) + req
                        local miss = max(0, req - (simInv[mid] or 0))
                        if miss > 0 then
                            extDemand[mid] = (extDemand[mid] or 0) + miss
                            stepExtUnits[idx][mid] = (stepExtUnits[idx][mid] or 0) + miss
                            simInv[mid] = (simInv[mid] or 0) + miss
                        end
                        simInv[mid] = (simInv[mid] or 0) - req

                        local sReq = mcnt * nSafe
                        safeGrossInputs[mid] = (safeGrossInputs[mid] or 0) + sReq
                        local sMiss = max(0, sReq - (safeSimInv[mid] or 0))
                        if sMiss > 0 then
                            safeExtDemand[mid] = (safeExtDemand[mid] or 0) + sMiss
                            safeSimInv[mid] = (safeSimInv[mid] or 0) + sMiss
                        end
                        safeSimInv[mid] = (safeSimInv[mid] or 0) - sReq
                    end
                    if r.item and r.count and r.count > 0 then
                        baseGrossOutputs[r.item] = (baseGrossOutputs[r.item] or 0) + r.count * nPlan
                        safeGrossOutputs[r.item] = (safeGrossOutputs[r.item] or 0) + r.count * nSafe
                        simInv[r.item] = (simInv[r.item] or 0) + r.count * nPlan
                        safeSimInv[r.item] = (safeSimInv[r.item] or 0) + r.count * nSafe
                    end
                end
            end
        end

        -- Snapshot state before material purchases so we can also price `safeExtDemand` accurately
        local preBuyState = clone(cur)

        -- Emit batch material purchases in deterministic itemID order & record batch costs per item
        local batchItemCost, batchItemUnpriced = {}, {}
        local buyIds = {}
        for id, qty in pairs(extDemand) do
            if qty > 0 then buyIds[#buyIds + 1] = id end
        end
        table.sort(buyIds)
        for _, id in ipairs(buyIds) do
            local moneyBefore = cur.money
            local prevLog = cur.log
            cur = buyItemIntoState(cur, id, extDemand[id], "material", "__batch__")
            if not cur then return nil end
            batchItemCost[id] = cur.money - moneyBefore
            local node = cur.log
            while node and node ~= prevLog do
                if node.action and node.action.unpriced then batchItemUnpriced[id] = true; break end
                node = node.prev
            end
        end

        local function calcStepDirectCost(idx)
            local c, unp = 0, false
            for id, u in pairs(stepExtUnits[idx] or {}) do
                local tot = extDemand[id] or 0
                if tot > 0 and u > 0 then
                    c = c + (batchItemCost[id] or 0) * (u / tot)
                    if batchItemUnpriced[id] then unp = true end
                end
            end
            return c, unp or nil
        end

        -- Execute steps in causal order
        local safeCraftsByKey = {}
        local carryConvertCost, carryConvertUnp = 0, nil
        for idx, st in ipairs(sol.steps) do
            local dCost, dUnp = calcStepDirectCost(idx)
            -- Complete any due tool goals whose item is already in inventory
            for _, goal in ipairs(j.snap.toolGoals or {}) do
                if goal.profession == profSlug and not cur.completedToolGoals[goal.id]
                    and (cur.skill[profSlug] or 1) >= (goal.minSkill or 1)
                    and available(cur, goal.item) >= 1 then
                    cur = finishToolInState(cur, goal)
                end
            end

            if st.kind == "tool_buy" then
                local tid = st.outputs and st.outputs[1] and st.outputs[1][1]
                local matchedGoal = false
                for _, goal in ipairs(j.snap.toolGoals or {}) do
                    if goal.item == tid and not cur.completedToolGoals[goal.id] then
                        cur = finishToolInState(cur, goal, dCost, dUnp)
                        matchedGoal = true
                    end
                end
                if not matchedGoal then
                    carryConvertCost = carryConvertCost + dCost
                    carryConvertUnp = carryConvertUnp or dUnp
                end
            elseif st.kind == "essence_convert" then
                local outId = st.outputs and st.outputs[1] and st.outputs[1][1]
                local conv = outId and essenceConversion(outId)
                if not conv then return nil end
                carryConvertCost = carryConvertCost + dCost
                carryConvertUnp = carryConvertUnp or dUnp
                cur = convertInState(cur, conv, st.planned_crafts, nil)
                if not cur then return nil end
            elseif st.kind == "gather" then
                local p = profSlug
                local to = st.to_skill
                cur = clone(cur)
                while (cur.skill[p] or 1) < to do
                    if (cur.skill[p] or 1) >= (cur.cap[p] or capLimit) and (cur.cap[p] or capLimit) < capLimit then
                        writable(cur, "cap")[p] = nextCapTier(cur.cap[p] or capLimit, capLimit)
                    end
                    local from = cur.skill[p] or 1
                    local nxt = min(to, cur.cap[p] or capLimit)
                    writable(cur, "skill")[p] = nxt
                    cur.plannedTarget = max(cur.plannedTarget or 0, p == slug and nxt or 0)
                    log(cur, { type = "gather", profession = p, from = from, to = nxt, reason = "level", count = 0, spell = 0 })
                end
            elseif st.spell_id then
                local r = lookupStepRecipe(st.spell_id)
                if not r then return nil end
                local isLevel = r.profession == profSlug and (st.to_skill or 0) > (st.from_skill or 0)
                local reason = isLevel and (profSlug == slug and "level" or "secondary") or "material"
                local sc = max(st.planned_crafts, st.safe_crafts or st.planned_crafts)
                if isLevel then
                    safeCraftsByKey[r.profession .. ":" .. tostring(r.spell) .. ":" .. tostring(st.from_skill) .. ":" .. tostring(st.to_skill)] = sc
                end
                local fromSk = r.profession == profSlug and st.from_skill or cur.skill[r.profession]
                local toSk = r.profession == profSlug and st.to_skill or cur.skill[r.profession]
                cur = executeCraftStep(
                    cur, r, st.planned_crafts, fromSk, toSk, reason, sc, learningBySpell[r.spell],
                    dCost + carryConvertCost, dUnp or carryConvertUnp
                )
                carryConvertCost, carryConvertUnp = 0, nil
                if not cur then return nil end
                for _, goal in ipairs(j.snap.toolGoals or {}) do
                    if goal.profession == profSlug and not cur.completedToolGoals[goal.id]
                        and (cur.skill[profSlug] or 1) >= (goal.minSkill or 1)
                        and available(cur, goal.item) >= 1 then
                        cur = finishToolInState(cur, goal)
                    end
                end
            end
            tick()
        end

        -- Build safe shopping list metadata (capped cleanly if AH supply is finite!)
        local safeMats = {}
        local safeMatTotal = 0
        local extraByItem = {}
        local grossExtraByItem = {}
        for id, sIn in pairs(safeGrossInputs) do
            local sGrossNet = max(0, sIn - (safeGrossOutputs[id] or 0))
            local bGrossNet = max(0, (baseGrossInputs[id] or 0) - (baseGrossOutputs[id] or 0))
            if sGrossNet > bGrossNet then
                grossExtraByItem[id] = sGrossNet - bGrossNet
            end
        end
        local safeIds = {}
        for id, qty in pairs(safeExtDemand) do
            if qty > 0 then safeIds[#safeIds + 1] = id end
        end
        table.sort(safeIds)
        for _, id in ipairs(safeIds) do
            local sNeed = safeExtDemand[id]
            local bNeed = extDemand[id] or 0
            local rem = auctionRemaining(preBuyState, id)
            local book = j.snap.auctionDepth and j.snap.auctionDepth[id]
            local depthMax = (book and type(book.total) == "number") and max(0, book.total - (preBuyState.ahUsed[id] or 0)) or huge
            local capRem = min(rem, depthMax)
            if capRem < huge and #materialVendorOffers(id) == 0 then
                sNeed = min(sNeed, max(bNeed, capRem))
                if grossExtraByItem[id] then
                    grossExtraByItem[id] = min(grossExtraByItem[id], max(0, sNeed - bNeed))
                end
            end
            if sNeed > bNeed then
                extraByItem[id] = sNeed - bNeed
            end
            local rows, cost, complete = E.MaterialPurchases(id, sNeed, {
                offers = materialVendorOffers(id),
                auction = auctionQuote(id) and j.snap.prices[id] or nil,
                supply = j.auctionSupply[id],
                available = rem < huge and rem or nil,
                faction = j.snap.faction,
                auctionCost = function(q) return auctionCost(preBuyState, id, q) end,
            }, tick)
            if complete and type(cost) == "number" then
                safeMatTotal = safeMatTotal + cost
                for _, row in ipairs(rows or {}) do
                    safeMats[#safeMats + 1] = row
                end
            end
        end

        local prevMeta = cur._v3Meta
        cur._v3Meta = {
            prepConfidence = sol.prep_confidence or 0.90,
            safeGrossCost = (prevMeta and prevMeta.safeGrossCost or 0) + (sol.safe_gross_cost_copper or cur.money),
            safeNetSpend = (prevMeta and prevMeta.safeNetSpend or 0) + (sol.safe_net_spend_copper or 0),
            grossStd = math.sqrt((prevMeta and prevMeta.grossStd and prevMeta.grossStd ^ 2 or 0) + (sol.gross_std_copper or 0) ^ 2),
            routeStd = math.sqrt((prevMeta and prevMeta.routeStd and prevMeta.routeStd ^ 2 or 0) + (sol.route_std_copper or 0) ^ 2),
            safeCraftsByKey = safeCraftsByKey,
            safeMats = safeMats,
            safeMatTotal = (prevMeta and prevMeta.safeMatTotal or 0) + safeMatTotal,
            extraByItem = extraByItem,
            grossExtraByItem = grossExtraByItem,
        }
        if prevMeta then
            for k, v in pairs(prevMeta.safeCraftsByKey or {}) do cur._v3Meta.safeCraftsByKey[k] = v end
            for k, v in pairs(prevMeta.extraByItem or {}) do cur._v3Meta.extraByItem[k] = (cur._v3Meta.extraByItem[k] or 0) + v end
            for k, v in pairs(prevMeta.grossExtraByItem or {}) do cur._v3Meta.grossExtraByItem[k] = (cur._v3Meta.grossExtraByItem[k] or 0) + v end
            for _, row in ipairs(prevMeta.safeMats or {}) do
                table.insert(cur._v3Meta.safeMats, 1, row)
            end
        end

        return cur
    end

    j.co = coroutine.create(function()
        j.snap = E.Capture(slug, opts, tick)
        if bagMaterialsEnabled(slug, opts) and j.snap.bagInventoryUnknown then
            fail("bagInventoryUnknown")
            j.exhausted = true
            j.searchTermination = "inventory_unknown"
            j.status = "recalculate_required"
            j.result = S.Result(j, nil, j.status)
            j.finished = true
            return "done"
        end
        j.auctionSupply = E.ConsiderAuctionSupply(j.snap) and j.snap.auctionSupply or {}
        if not E.ConsiderAuctionSupply(j.snap) and E.FormulaAuctionSupplyOf then
            for id in pairs(j.snap.formulaItems or {}) do
                local supply = E.FormulaAuctionSupplyOf(j.snap, id)
                if supply then j.auctionSupply[id] = supply end
            end
        end
        j.seedSkill = opts.start or (j.snap.professions[slug] or {}).cur or 1
        local recovery = getRecovery()
        local ess = getEssences()
        j.recovery = not opts.procurementDemands and opts.scheme == "net"
            and j.snap.recovery and j.snap.recovery.enabled and recovery and recovery.StateRevenue and true or false
        j.hasFiniteSupply = next(j.auctionSupply) ~= nil
        if not opts.start then opts.start = (j.snap.professions[slug] or {}).cur or 1 end
        local context = j.snap.routeContext or E.RouteContext(slug, opts, j.snap.professions)
        local gatesMod = ns.ProfGates or (type(_G.DF_NS) == "table" and _G.DF_NS.ProfGates) or nil
        local minSpecSkill = (gatesMod and type(gatesMod.MinSpecSkill) == "function" and gatesMod.MinSpecSkill(slug)) or 200
        j.specializationConflict = j.target >= minSpecSkill
            and j.snap.specializationContext and j.snap.specializationContext.selectionConflict
        if context.requiresPartner and not context.partnerValid then
            fail("secondaryRequired")
            j.exhausted = true
            j.searchTermination = "exhausted"
            j.status = "infeasible"
            j.result = S.Result(j, nil, j.status)
            j.finished = true
            return "done"
        end

        j.formulaByRecipe = {}
        for _, r in ipairs(j.snap.recipes or {}) do
            j.formulaByRecipe[r.key] = E.FormulaFor(r, j.snap)
            tick()
        end
        j.purchasePriced = {}
        for id in pairs(j.snap.prices or {}) do
            if auctionQuote(id) then j.purchasePriced[id] = true end
            tick()
        end
        for id, offers in pairs(j.snap.offers or {}) do
            for _, o in ipairs(offers) do
                if vendorQuote(o) then j.purchasePriced[id] = true; break end
            end
            tick()
        end
        if j.snap.essenceConversions and ess then
            for _, pair in ipairs(ess.Pairs()) do
                if j.purchasePriced[pair.lesserID] or j.purchasePriced[pair.greaterID] then
                    j.purchasePriced[pair.lesserID] = true
                    j.purchasePriced[pair.greaterID] = true
                end
            end
        end
        opts.exclusions = opts.exclusions or E.GetPolicies(slug)
        local first = initial(j.snap, slug, opts, tick)

        j.reusable = {}
        for _, r in ipairs(j.snap.recipes or {}) do
            for _, m in ipairs(r.mats or {}) do j.reusable[m[1]] = true end
        end

        if opts.routeSkeleton then
            return rebuildSkeleton(first)
        end

        -- Mode 1: Procurement Demand Solver (`__purchase` for Supply Crates, Writs, & Supplements)
        if opts.procurementDemands then
            j.phase = "procurement"
            local cur = clone(first)
            local demIds = {}
            for id, qty in pairs(opts.procurementDemands) do
                if qty > 0 then demIds[#demIds + 1] = id end
            end
            table.sort(demIds)
            local okAll = true
            for _, id in ipairs(demIds) do
                cur = procureItemExact(cur, id, available(cur, id) + opts.procurementDemands[id], "material", "__purchase:2147483647", nil, nil, false)
                if not cur then okAll = false; break end
            end
            if okAll and cur then
                local pRec = j.snap.byKey["__purchase:2147483647"]
                if pRec then
                    cur = executeCraftStep(cur, pRec, 1, 1, 2, "level", 1, nil)
                else
                    writable(cur, "skill").__purchase = 2
                end
            end
            j.seedDone = true
            j.expanded = 1
            j.exhausted = true
            j.searchTermination = "exhausted"
            j.best = (okAll and cur) or nil
            j.status = j.best and (uncertainty(j.best) == 0 and "complete" or "incomplete") or "infeasible"
            j.result = S.Result(j, j.best, j.status)
            j.finished = true
            return "done"
        end

        -- Mode 2: Fixed steps execution
        if opts.fixedSteps then
            j.phase = "fixed"
            local cur = clone(first)
            for _, step in ipairs(opts.fixedSteps) do
                local p = step.profession or slug
                local r = j.snap.byKey[p .. ":" .. tostring(step[3])]
                if not r then fail("clientDataPending", { spell = step[3], profession = p }); cur = nil; break end
                local okU, learning = allowed(r, cur, step.reason or "level", false)
                if not okU then cur = nil; break end
                local n = ceil(step[4] or 0)
                local toSk = min(j.target, step[2] or (cur.skill[p] or 1))
                for _, m in ipairs(r.mats or {}) do
                    cur = procureItemExact(cur, m[1], available(cur, m[1]) + m[2] * n, "material", r.key, nil, p, false)
                    if not cur then break end
                end
                if not cur then break end
                cur = executeCraftStep(cur, r, n, cur.skill[p] or 1, toSk, step.reason or "level", n, learning)
                if not cur then break end
                j.partial = cur
                tick()
            end
            if cur then
                for _, goal in ipairs(j.snap.toolGoals or {}) do
                    if (cur.skill[slug] or 1) >= (goal.minSkill or 1) then
                        cur = procureGoalTool(cur, goal)
                        if not cur then break end
                    end
                end
            end
            j.seedDone = true
            j.exhausted = true
            restrict(j, "fixed_route")
            j.searchTermination = "fixed"
            j.best = (cur and goalsComplete(j, cur)) and cur or nil
            j.preview = cur
            j.status = j.best and "complete" or (j.preview and "incomplete" or "infeasible")
            j.result = S.Result(j, j.best, j.status)
            j.finished = true
            return "done"
        end

        -- Mode 3: Already at or above target skill
        local startSk = first.skill[slug] or opts.start or 1
        if startSk >= j.target then
            local cur = clone(first)
            for _, goal in ipairs(j.snap.toolGoals or {}) do
                if startSk >= (goal.minSkill or 1) then
                    cur = procureGoalTool(cur, goal)
                    if not cur then break end
                end
            end
            if cur then
                for _, goal in ipairs(j.snap.specializationGoals or {}) do
                    if (goal.minSkill or 0) <= j.target then
                        cur = completeSpecQuestInState(cur, goal)
                        if not cur then break end
                    end
                end
            end
            j.seedDone = true
            j.exhausted = true
            j.searchTermination = "exhausted"
            j.best = (cur and goalsComplete(j, cur)) and cur or nil
            j.status = j.best and "complete" or "infeasible"
            j.result = S.Result(j, j.best, j.status)
            j.finished = true
            return "done"
        end

        -- Mode 4: Full v3 Optimal Leveling Route Search (with Engineering Specialization Checkpoint Support)
        j.phase = "v3_optimize"
        local schemeMode = opts.scheme == "net" and "net" or "cost"

        if j.specializationConflict then
            fail("specializationChoiceConflict", { key = slug, profession = slug })
        end

        -- Split into stages for all active specialization quests in [startSk, j.target]
        local pendingSpecGoals = {}
        for _, goal in ipairs(j.snap.specializationGoals or {}) do
            if not first.completedSpecializationGoals[goal.id] and not first.specializationAbilities[goal.abilityID]
                and (goal.minSkill or 0) <= j.target then
                pendingSpecGoals[#pendingSpecGoals + 1] = goal
            end
        end

        local curState = clone(first)
        local stages = {}
        local cursor = startSk
        for _, goal in ipairs(pendingSpecGoals) do
            local gSk = max(cursor, min(j.target, goal.minSkill or 200))
            if gSk > cursor then
                stages[#stages + 1] = { from = cursor, to = gSk }
                cursor = gSk
            end
            stages[#stages + 1] = { quest = goal }
        end
        if j.target > cursor or #stages == 0 then
            stages[#stages + 1] = { from = cursor, to = j.target }
        end

        local allOptimal = true
        local retiredLevelSpells = {}
        for _, stg in ipairs(stages) do
            if stg.quest then
                if j.specializationConflict then
                    j.blockedSkill = curState.skill[slug]
                    j.blockers = { { code = "specializationChoiceConflict", profession = slug } }
                    allOptimal = false
                    break
                end
                local afterQuest = completeSpecQuestInState(curState, stg.quest)
                if not afterQuest then
                    j.blockedSkill = curState.skill[slug]
                    j.blockers = {}
                    for _, d in pairs(j.failures) do j.blockers[#j.blockers + 1] = d end
                    allOptimal = false
                    break
                end
                curState = afterQuest
                j.partial = curState
            else
                local prob, mkt, pCtx, sOpts, learningBySpell, recipeBySpell = buildStageProblem(slug, stg.from, stg.to, curState, schemeMode, retiredLevelSpells)
                local sol = OptimizerCore.solve_profession_route(prob, mkt, pCtx, sOpts, stg.from, stg.to)
                j.expanded = (j.expanded or 0) + 1
                if (not sol or sol.status == "unreachable" or (sol.reached_skill or stg.from) <= stg.from) and (stg.to - stg.from) > 1 and next(retiredLevelSpells) ~= nil then
                    -- Retry without cross-stage retired constraint if needed for feasibility
                    prob, mkt, pCtx, sOpts, learningBySpell, recipeBySpell = buildStageProblem(slug, stg.from, stg.to, curState, schemeMode, nil)
                    sol = OptimizerCore.solve_profession_route(prob, mkt, pCtx, sOpts, stg.from, stg.to)
                    j.expanded = (j.expanded or 0) + 1
                end
                if (not sol or sol.status == "unreachable" or (sol.reached_skill or stg.from) <= stg.from) and (stg.to - stg.from) > 1 then
                    -- Binary-search highest reachable skill prefix (e.g. when finite AH supply caps late-stage bars)
                    local loSk, hiSk = stg.from + 1, stg.to - 1
                    local bestPartialSol = nil
                    while loSk <= hiSk do
                        local midSk = floor((loSk + hiSk) / 2)
                        local pSub, mSub, cSub, oSub = buildStageProblem(slug, stg.from, midSk, curState, schemeMode, nil)
                        local candSol = OptimizerCore.solve_profession_route(pSub, mSub, cSub, oSub, stg.from, midSk)
                        j.expanded = (j.expanded or 0) + 1
                        if candSol and candSol.status ~= "unreachable" and (candSol.reached_skill or stg.from) >= midSk then
                            bestPartialSol = candSol
                            loSk = midSk + 1
                        else
                            hiSk = midSk - 1
                        end
                        tick()
                    end
                    if bestPartialSol then
                        sol = bestPartialSol
                    end
                end
                if not sol or sol.status == "unreachable" or (sol.reached_skill or stg.from) <= stg.from then
                    j.blockedSkill = curState.skill[slug] or stg.from
                    j.blockers = {}
                    for _, d in pairs(j.collectFailures or {}) do j.blockers[#j.blockers + 1] = d end
                    if #j.blockers == 0 then
                        j.blockers[1] = { code = "levelGap", profession = slug }
                        fail("levelGap", { key = slug .. ":" .. tostring(j.blockedSkill), profession = slug })
                    end
                    allOptimal = false
                    break
                end
                if not sol.is_optimal then allOptimal = false end
                local lastLevelSpInStage = nil
                for _, st in ipairs(sol.steps or {}) do
                    if st.spell_id and (st.to_skill or 0) > (st.from_skill or 0) then
                        lastLevelSpInStage = st.spell_id
                    end
                end
                for _, st in ipairs(sol.steps or {}) do
                    if st.spell_id and (st.to_skill or 0) > (st.from_skill or 0) and st.spell_id ~= lastLevelSpInStage then
                        retiredLevelSpells[st.spell_id] = true
                    end
                end
                local nextState = applySolutionToState(curState, slug, sol, learningBySpell, recipeBySpell)
                if not nextState then
                    j.blockedSkill = curState.skill[slug] or stg.from
                    j.blockers = {}
                    for _, d in pairs(j.failures) do j.blockers[#j.blockers + 1] = d end
                    allOptimal = false
                    break
                end
                curState = nextState
                j.partial = curState
                j.preview = curState
                j.seedSkill = curState.skill[slug]
                if (sol.reached_skill or stg.from) < stg.to then
                    j.blockedSkill = curState.skill[slug]
                    j.blockers = {}
                    for _, d in pairs(j.collectFailures or {}) do j.blockers[#j.blockers + 1] = d end
                    if #j.blockers == 0 then
                        j.blockers[1] = { code = "levelGap", profession = slug }
                        fail("levelGap", { key = slug .. ":" .. tostring(j.blockedSkill), profession = slug })
                    end
                    allOptimal = false
                    break
                end
            end
            tick()
        end
        j.collectFailures = nil

        -- Ensure any remaining required leveling tools <= reached skill are procured
        j.unattainableToolGoals = j.unattainableToolGoals or {}
        if curState and (curState.skill[slug] or 0) >= j.target then
            for _, goal in ipairs(j.snap.toolGoals or {}) do
                if not curState.completedToolGoals[goal.id] and (curState.skill[slug] or 0) >= (goal.minSkill or 1) then
                    local savedF = copyStateMap(j.failures)
                    local withTool = procureGoalTool(curState, goal)
                    if withTool then
                        curState = withTool
                    else
                        j.failures = savedF
                        j.unattainableToolGoals[goal.id] = true
                        -- Optional/disabled-formula end tools (e.g. limited Arcanite Rod when allowLimitedFormulas=false,
                        -- or Forever custom thrown items) are recorded in toolGoalsSkipped without marking route incomplete
                        j.toolGoalsSkipped = j.toolGoalsSkipped or {}
                        j.toolGoalsSkipped[#j.toolGoalsSkipped + 1] = goal.id
                    end
                end
            end
        end

        j.seedDone = true
        if curState and goalsComplete(j, curState) then
            j.best = curState
            j.initialTotal = curState.money
            j.initialNetTotal = j.recovery and (curState.money - recovery.StateRevenue(curState, j.snap)) or nil
            j.firstFeasibleCpuMs = j.cpuUsed
            j.exhausted = allOptimal and not j.budgetLimited
            j.searchTermination = j.budgetLimited and "cpu_limit" or "exhausted"
            j.status = uncertainty(curState) == 0 and "complete" or "incomplete"
        else
            j.exhausted = not j.budgetLimited
            j.searchTermination = j.budgetLimited and "cpu_limit" or "exhausted"
            if j.partial and ((j.partial.skill[slug] or 0) > startSk or completedGoals(j.partial) > 0) then
                j.preview = j.partial
                j.status = "incomplete"
            else
                j.status = "infeasible"
                for _, d in pairs(j.failures) do
                    if d.code == "clientDataPending" or d.code == "materialUnavailable"
                        or d.code == "outputConflict" or d.code == "availabilityUnknown" then
                        j.status = "incomplete"
                        break
                    end
                end
            end
        end

        j.result = S.Result(j, j.best, j.status)
        j.finished = true
        return "done"
    end)

    return j
end

function S.ChargeExternalWork(j, elapsed)
    elapsed = tonumber(elapsed)
    if not j or not elapsed or elapsed ~= elapsed or elapsed <= 0 or elapsed == huge then return end
    j.cpuUsed = (j.cpuUsed or 0) + elapsed
    j.externalCpuUsed = (j.externalCpuUsed or 0) + elapsed
    S.RefreshStatus(j)
end

local function finalize(j, status)
    j.status = status
    j.phase = "finalize"
    j.finalizing = true
    j.finalizeProgress = j.finalizeProgress or 0
    j.co = coroutine.create(function()
        j.result = S.Result(j, j.best, status)
        j.finalizing = nil
        j.finished = true
        return "done"
    end)
end

function S.Run(j, budget, deferStatus)
    if j.finished or j.cancelled or (j.status == "stopped" and not j.finalizing) or coroutine.status(j.co) == "dead" then
        S.RefreshStatus(j)
        return true
    end
    local start = clock()
    j.sliceStart = start
    j.deadline = start + (budget or 2)
    j.tickClockCountdown = 0
    local phase = j.phase or (j.finalizing and "finalize" or not j.snap and "capture" or "v3_optimize")
    local before = j.cpuUsed
    if not j.finalizing and j.cpuUsed >= j.cpuLimitMs then
        j.budgetLimited = true
        j.searchTermination = "cpu_limit"
        finalize(j, j.best and (uncertainty(j.best) == 0 and "complete" or "incomplete") or "incomplete")
    end
    local ok, why = coroutine.resume(j.co)
    local elapsed = max(0, clock() - start)
    if ok and j.status ~= "searching" and coroutine.status(j.co) ~= "dead" then j.finalizing = true end
    if not ok then
        j.status = "error"
        j.searchTermination = "error"
        j.failures.error = { code = "solverError", detail = tostring(why) }
        j.error = why
        if j.finalizing then
            j.finished = true
            j.finalizing = nil
        else
            finalize(j, "error")
        end
    elseif not j.finalizing and max(before, j.cpuUsed) + elapsed >= j.cpuLimitMs and coroutine.status(j.co) ~= "dead" then
        j.budgetLimited = true
        j.searchTermination = "cpu_limit"
        finalize(j, j.best and (uncertainty(j.best) == 0 and "complete" or "incomplete") or "incomplete")
    end
    local delta = max(0, clock() - start)
    j.phaseCpuMs[phase] = (j.phaseCpuMs[phase] or 0) + delta
    j.cpuUsed = max(before, j.cpuUsed) + delta
    j.sliceStart = nil
    local done = j.finished or coroutine.status(j.co) == "dead"
    if done then
        j.finalizing = nil
        j.finalizeProgress = 1
    end
    if done and j.result then j.result.phaseCpuMs = getEconomy().Copy(j.phaseCpuMs) end
    if done or not j.progressAt or clock() - j.progressAt >= 200 then
        j.progressAt = clock()
        j.progressVersion = (j.progressVersion or 0) + 1
    end
    if done or not deferStatus then S.RefreshStatus(j) end
    return done
end

function S.Compute(slug, opts)
    local j = S.NewJob(slug, opts)
    while coroutine.status(j.co) ~= "dead" and not j.finished and (j.status ~= "error" or j.finalizing) do
        S.Run(j, 1000)
    end
    return j.result or S.Result(j, j.best, j.status), j
end

function S.NewProcurementJob(snapshot, demands, opts)
    local E = getEconomy()
    local capLimit = solverCap()
    opts = E.Copy(opts or {}, nil, { snapshot = false })
    opts.snapshot = E.Copy(snapshot, nil, {
        recipes = {}, specializationGoals = {}, toolGoals = {},
        professions = {}, known = {}, byKey = {}, byItem = {}, byProfession = {},
    })
    if opts.referenceFallback == nil then opts.referenceFallback = false end
    for _, r in ipairs(snapshot.recipes or {}) do
        opts.snapshot.recipes[#opts.snapshot.recipes + 1] = r
    end
    local totals = {}
    if type(demands) == "table" and type(demands[1]) == "table" then
        for _, entry in ipairs(demands) do
            local id, n = entry.id or entry[1], entry.count or entry.need or entry[2]
            assert(type(id) == "number" and id > 0 and id == floor(id) and type(n) == "number" and n >= 0 and n == floor(n), "invalid procurement demand")
            totals[id] = (totals[id] or 0) + n
        end
    else
        for id, n in pairs(demands or {}) do
            assert(type(id) == "number" and id > 0 and id == floor(id) and type(n) == "number" and n >= 0 and n == floor(n), "invalid procurement demand")
            totals[id] = (totals[id] or 0) + n
        end
    end
    local ids = {}
    for id, n in pairs(totals) do if n > 0 then ids[#ids + 1] = id end end
    table.sort(ids)
    local mats = {}
    for _, id in ipairs(ids) do mats[#mats + 1] = { id, totals[id] } end
    opts.procurementDemands = totals
    opts.snapshot.recipes[#opts.snapshot.recipes + 1] = {
        profession = "__purchase",
        spell = 2147483647,
        learn = 1,
        yellow = 2,
        green = 2,
        grey = 2,
        count = 1,
        mats = mats,
        cooldown = false,
    }
    opts.snapshot.professions = E.Copy(snapshot.professions)
    opts.snapshot.professions.__purchase = { cur = 1, max = capLimit }
    opts.snapshot.known = E.Copy(snapshot.known)
    opts.snapshot.known["__purchase:2147483647"] = true
    opts.start = 1
    opts.target = 2
    return S.NewJob("__purchase", opts)
end

function S.ProcureMany(snapshot, demands, opts)
    local j = S.NewProcurementJob(snapshot, demands, opts)
    if opts and opts.defer then return nil, j end
    while coroutine.status(j.co) ~= "dead" and not j.finished and (j.status ~= "error" or j.finalizing) do
        S.Run(j, 1000)
    end
    return j.result or S.Result(j, j.best, j.status), j
end

function S.Procure(snapshot, id, count, opts)
    return S.ProcureMany(snapshot, { [id] = count }, opts)
end
