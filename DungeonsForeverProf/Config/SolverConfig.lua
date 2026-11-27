local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end

local C = {
  CAP = 300,
  DEFAULT_TARGET = 300,
  ROUTE_RISK_MODES = {
    ORDER = { "expected", "quantile" },
    DEFAULT = "expected",
    CONFIDENCE = 0.90,
    LABELS = {
      expected = "期望最优",
      quantile = "保守选路",
    },
  },
  RESERVE_MODES = {
    ORDER = { "safe", "expected" },
    DEFAULT = "safe",
    CONFIDENCE = 0.90,
    LABELS = {
      safe = "一次备足(90%)",
      expected = "按期望采购",
    },
  },
  REGULARIZATION = {
    switchPenaltyCopper = 300,
    switchCostRatio = 0.35,
    minSegmentPoints = 5,
    minIntermediatePoints = 3,
    forbidRecipeRepeat = true,
    highCostFailAversion = 0.55,
    highCostGreenThresholdCopper = 10000,
    maxSubgradientIters = 28,
    maxBnbNodes = 250,
  },
  OBJECTIVES = {
    ORDER = { "cost", "net" },
    DEFAULT = "cost",
    LABELS = {
      cost = "最低成本",
      net = "回血净花费",
    },
  },
  COROUTINE_BUDGET = {
    cpuLimitMs = 8000,
    maxFrontier = 20000,
    frameBudgetMs = 8,
    paintCapMs = 4,
    routeTickMs = 1,
    yieldThresholdMs = 3,
  },
  FRESHNESS = {
    executionIdleLimitSec = 48 * 3600,
    resultCacheTTL = 600,
    resultCacheSlots = 4,
  },
}

local function freezeTable(tbl)
  if type(ns.Data) == "table" and type(ns.Data._freeze) == "function" then
    return ns.Data._freeze(tbl)
  end
  local frozen = {}
  local roMt = {
    __newindex = function() error("DungeonsForeverProf: static data table is read-only", 2) end,
    __metatable = false,
  }
  local function walk(t)
    if type(t) ~= "table" or frozen[t] then return t end
    frozen[t] = true
    for _, v in pairs(t) do
      if type(v) == "table" then walk(v) end
    end
    return setmetatable(t, roMt)
  end
  return walk(tbl)
end

C = freezeTable(C)
ns.SolverConfig = C
if type(_G.DF_NS) == "table" and _G.DF_NS ~= ns then
  _G.DF_NS.SolverConfig = C
end
