local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end

ns.Data._recipeLoaders["poisons"] = function()
  return {
    catalogEntries = {},
    recipes = {
      [2842] = {
        availability = "live",
        categoryKey = "9",
        isNew = false,
        learnedAt = 1,
        outputCountMax = 1,
        outputCountMin = 1,
        outputKind = "effect",
        profession = "poisons",
        reagents = {},
        recommendedSpecs = {},
        requiredTools = {},
        skillLineID = 40,
        spellID = 2842,
      },
    },
  }
end
