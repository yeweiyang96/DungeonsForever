local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end

local _E = ns.Data._empty
ns.Data._recipeLoaders["fishing"] = function()
  return {
    catalogEntries = _E,
    recipes = {
      [1229745] = {
        availability = "live",
        categoryKey = "camping",
        green = 20,
        grey = 20,
        isNew = true,
        learnedAt = 20,
        orange = 20,
        outputCountMax = 1,
        outputCountMin = 1,
        outputItemID = 279967,
        outputKind = "item",
        profession = "fishing",
        reagents = {
          { count = 1, itemID = 3371 },
          { count = 1, itemID = 6291 },
        },
        skillLineID = 356,
        spellID = 1229745,
        yellow = 20,
      },
      [1262990] = {
        availability = "live",
        categoryKey = "camping",
        green = 140,
        grey = 140,
        isNew = true,
        learnedAt = 140,
        orange = 140,
        outputCountMax = 1,
        outputCountMin = 1,
        outputItemID = 279965,
        outputKind = "item",
        profession = "fishing",
        reagents = {
          { count = 2, itemID = 4470 },
          { count = 2, itemID = 8365 },
          { count = 1, itemID = 8925 },
        },
        skillLineID = 356,
        spellID = 1262990,
        yellow = 140,
      },
      [1262998] = {
        availability = "live",
        categoryKey = "camping",
        green = 300,
        grey = 300,
        isNew = true,
        learnedAt = 300,
        orange = 300,
        outputCountMax = 1,
        outputCountMin = 1,
        outputItemID = 279966,
        outputKind = "item",
        profession = "fishing",
        reagents = {
          { count = 5, itemID = 4470 },
          { count = 2, itemID = 14048 },
          { count = 1, itemID = 273295 },
        },
        skillLineID = 356,
        spellID = 1262998,
        yellow = 300,
      },
    },
  }
end
