local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end

local _E = ns.Data._empty
ns.Data._loaders["guides"] = function()
  return {
    fishingGuides = {
      cookingSteps = {
        {
          fishReagentIDs = { 6291 },
          green = 65,
          grey = 85,
          learnedAt = 1,
          orange = 1,
          outputItemID = 6290,
          reagents = {
            { count = 1, itemID = 6291 },
          },
          spellID = 7751,
          yellow = 45,
        },
        {
          fishReagentIDs = { 6303 },
          green = 65,
          grey = 85,
          learnedAt = 1,
          orange = 1,
          outputItemID = 787,
          reagents = {
            { count = 1, itemID = 6303 },
          },
          spellID = 7752,
          yellow = 45,
        },
        {
          fishReagentIDs = { 6289 },
          green = 110,
          grey = 130,
          learnedAt = 50,
          orange = 50,
          outputItemID = 4592,
          reagents = {
            { count = 1, itemID = 6289 },
          },
          spellID = 7753,
          yellow = 90,
        },
        {
          fishReagentIDs = { 6361 },
          green = 110,
          grey = 130,
          learnedAt = 50,
          orange = 50,
          outputItemID = 5095,
          reagents = {
            { count = 1, itemID = 6361 },
          },
          spellID = 7827,
          yellow = 90,
        },
        {
          fishReagentIDs = { 21071 },
          green = 140,
          grey = 160,
          learnedAt = 80,
          orange = 80,
          outputItemID = 21072,
          reagents = {
            { count = 1, itemID = 2678 },
            { count = 1, itemID = 21071 },
          },
          spellID = 25704,
          yellow = 120,
        },
        {
          fishReagentIDs = { 6308 },
          green = 160,
          grey = 180,
          learnedAt = 100,
          orange = 100,
          outputItemID = 4593,
          reagents = {
            { count = 1, itemID = 6308 },
          },
          spellID = 7755,
          yellow = 140,
        },
        {
          fishReagentIDs = { 6362 },
          green = 210,
          grey = 230,
          learnedAt = 175,
          orange = 175,
          outputItemID = 4594,
          reagents = {
            { count = 1, itemID = 6362 },
          },
          spellID = 7828,
          yellow = 190,
        },
        {
          fishReagentIDs = { 8365 },
          green = 235,
          grey = 255,
          learnedAt = 175,
          orange = 175,
          outputItemID = 8364,
          reagents = {
            { count = 1, itemID = 8365 },
          },
          spellID = 20916,
          yellow = 215,
        },
        {
          fishReagentIDs = { 21153 },
          green = 235,
          grey = 255,
          learnedAt = 175,
          orange = 175,
          outputItemID = 21217,
          reagents = {
            { count = 1, itemID = 2692 },
            { count = 1, itemID = 21153 },
          },
          spellID = 25954,
          yellow = 215,
        },
        {
          fishReagentIDs = { 4603 },
          green = 285,
          grey = 305,
          learnedAt = 225,
          orange = 225,
          outputItemID = 6887,
          reagents = {
            { count = 1, itemID = 4603 },
          },
          spellID = 18238,
          yellow = 265,
        },
        {
          fishReagentIDs = { 13754 },
          green = 285,
          grey = 305,
          learnedAt = 225,
          orange = 225,
          outputItemID = 13927,
          reagents = {
            { count = 1, itemID = 3713 },
            { count = 1, itemID = 13754 },
          },
          spellID = 18239,
          yellow = 265,
        },
        {
          fishReagentIDs = { 13758 },
          green = 285,
          grey = 305,
          learnedAt = 225,
          orange = 225,
          outputItemID = 13930,
          reagents = {
            { count = 1, itemID = 13758 },
          },
          spellID = 18241,
          yellow = 265,
        },
        {
          fishReagentIDs = { 13755 },
          green = 300,
          grey = 320,
          learnedAt = 240,
          orange = 240,
          outputItemID = 13928,
          reagents = {
            { count = 1, itemID = 3713 },
            { count = 1, itemID = 13755 },
          },
          spellID = 18240,
          yellow = 280,
        },
        {
          fishReagentIDs = { 13756 },
          green = 300,
          grey = 320,
          learnedAt = 240,
          orange = 240,
          outputItemID = 13929,
          reagents = {
            { count = 2, itemID = 2692 },
            { count = 1, itemID = 13756 },
          },
          spellID = 18242,
          yellow = 280,
        },
        {
          fishReagentIDs = { 13759 },
          green = 310,
          grey = 330,
          learnedAt = 250,
          orange = 250,
          outputItemID = 13931,
          reagents = {
            { count = 1, itemID = 159 },
            { count = 1, itemID = 13759 },
          },
          spellID = 18243,
          yellow = 290,
        },
        {
          fishReagentIDs = { 13760 },
          green = 310,
          grey = 330,
          learnedAt = 250,
          orange = 250,
          outputItemID = 13932,
          reagents = {
            { count = 1, itemID = 13760 },
          },
          spellID = 18244,
          yellow = 290,
        },
        {
          fishReagentIDs = { 13889 },
          green = 335,
          grey = 355,
          learnedAt = 275,
          orange = 275,
          outputItemID = 13935,
          reagents = {
            { count = 1, itemID = 3713 },
            { count = 1, itemID = 13889 },
          },
          spellID = 18247,
          yellow = 315,
        },
      },
      fish = {
        [4603] = {
          areas = {
            { areaID = 440, minSkill = 205, noGetaway = 300 },
            { areaID = 47, minSkill = 205, noGetaway = 300 },
            { areaID = 357, minSkill = 205, noGetaway = 300 },
          },
          rate = 0.4,
        },
        [6289] = {
          areas = {
            { areaID = 1519, minSkill = 1, noGetaway = 75 },
            { areaID = 1537, minSkill = 1, noGetaway = 75 },
            { areaID = 1637, minSkill = 1, noGetaway = 75 },
            { areaID = 1638, minSkill = 1, noGetaway = 75 },
          },
        },
        [6291] = {
          areas = {
            { areaID = 12, minSkill = 1, noGetaway = 25 },
            { areaID = 215, minSkill = 1, noGetaway = 25 },
            { areaID = 14, minSkill = 1, noGetaway = 25 },
            { areaID = 141, minSkill = 1, noGetaway = 25 },
          },
          rate = 0.6,
        },
        [6303] = {
          areas = {
            { areaID = 14, minSkill = 1, noGetaway = 25 },
            { areaID = 141, minSkill = 1, noGetaway = 25 },
          },
        },
        [6308] = {
          areas = {
            { areaID = 267, minSkill = 55, noGetaway = 150 },
            { areaID = 44, minSkill = 55, noGetaway = 150 },
            { areaID = 406, minSkill = 55, noGetaway = 150 },
          },
          rate = 0.6,
        },
        [6361] = {
          areas = {
            { areaID = 17, minSkill = 1, noGetaway = 75 },
            { areaID = 40, minSkill = 1, noGetaway = 75 },
          },
        },
        [6362] = {
          areas = {
            { areaID = 15, minSkill = 130, noGetaway = 225 },
            { areaID = 33, minSkill = 130, noGetaway = 225 },
          },
        },
        [8365] = {
          areas = {
            { areaID = 36, minSkill = 130, noGetaway = 225 },
            { areaID = 15, minSkill = 130, noGetaway = 225 },
            { areaID = 33, minSkill = 130, noGetaway = 225 },
          },
        },
        [13754] = {
          areas = {
            { areaID = 440, minSkill = 205, noGetaway = 300 },
            { areaID = 47, minSkill = 205, noGetaway = 300 },
            { areaID = 357, minSkill = 205, noGetaway = 300 },
          },
          rate = 0.2,
        },
        [13755] = {
          areas = {
            { areaID = 440, minSkill = 205, noGetaway = 300 },
            { areaID = 47, minSkill = 205, noGetaway = 300 },
            { areaID = 357, minSkill = 205, noGetaway = 300 },
          },
          rate = 0.1,
          season = true,
        },
        [13756] = {
          areas = {
            { areaID = 440, minSkill = 205, noGetaway = 300 },
            { areaID = 47, minSkill = 205, noGetaway = 300 },
            { areaID = 357, minSkill = 205, noGetaway = 300 },
          },
          rate = 0.1,
          season = true,
        },
        [13758] = {
          areas = {
            { areaID = 47, minSkill = 205, noGetaway = 300 },
            { areaID = 361, minSkill = 205, noGetaway = 300 },
          },
          rate = 0.4,
        },
        [13759] = {
          areas = {
            { areaID = 47, minSkill = 205, noGetaway = 300 },
            { areaID = 361, minSkill = 205, noGetaway = 300 },
          },
          night = true,
          rate = 0.25,
        },
        [13760] = {
          areas = {
            { areaID = 47, minSkill = 205, noGetaway = 300 },
            { areaID = 361, minSkill = 205, noGetaway = 300 },
          },
          night = true,
          rate = 0.25,
        },
        [13889] = {
          areas = {
            { areaID = 618, minSkill = 330, noGetaway = 425 },
            { areaID = 357, minSkill = 330, noGetaway = 425 },
          },
          rate = 0.4,
        },
        [21071] = {
          areas = {
            { areaID = 38, minSkill = 1, noGetaway = 75 },
            { areaID = 130, minSkill = 1, noGetaway = 75 },
          },
          pool = true,
        },
        [21153] = {
          areas = {
            { areaID = 36, minSkill = 130, noGetaway = 225 },
            { areaID = 33, minSkill = 130, noGetaway = 225 },
          },
          pool = true,
        },
      },
      fishingSteps = {
        {
          areas = {
            { areaID = 12, minSkill = 1, noGetaway = 25 },
            { areaID = 215, minSkill = 1, noGetaway = 25 },
            { areaID = 14, minSkill = 1, noGetaway = 25 },
            { areaID = 141, minSkill = 1, noGetaway = 25 },
          },
          fishIDs = { 6291 },
          from = 1,
          to = 25,
        },
        {
          areas = {
            { areaID = 1519, minSkill = 1, noGetaway = 75 },
            { areaID = 1537, minSkill = 1, noGetaway = 75 },
            { areaID = 1637, minSkill = 1, noGetaway = 75 },
            { areaID = 1638, minSkill = 1, noGetaway = 75 },
            { areaID = 267, minSkill = 55, noGetaway = 150 },
            { areaID = 44, minSkill = 55, noGetaway = 150 },
            { areaID = 406, minSkill = 55, noGetaway = 150 },
          },
          fishIDs = { 6291, 6289, 6308 },
          from = 25,
          to = 150,
        },
        {
          areas = {
            { areaID = 36, minSkill = 130, noGetaway = 225 },
            { areaID = 15, minSkill = 130, noGetaway = 225 },
            { areaID = 33, minSkill = 130, noGetaway = 225 },
          },
          fishIDs = { 6362, 8365 },
          from = 150,
          to = 225,
        },
        {
          areas = {
            { areaID = 440, minSkill = 205, noGetaway = 300 },
            { areaID = 47, minSkill = 205, noGetaway = 300 },
            { areaID = 357, minSkill = 205, noGetaway = 300 },
          },
          fishIDs = { 4603 },
          from = 225,
          to = 300,
        },
      },
    },
    gatheringGuides = {
      herbalism = {
        bands = {
          {
            itemIDs = _E,
            maxSkill = 70,
            minSkill = 1,
            zones = _E,
          },
          {
            itemIDs = _E,
            maxSkill = 115,
            minSkill = 70,
            zones = _E,
          },
          {
            itemIDs = _E,
            maxSkill = 170,
            minSkill = 115,
            zones = _E,
          },
          {
            itemIDs = _E,
            maxSkill = 205,
            minSkill = 170,
            zones = _E,
          },
          {
            itemIDs = _E,
            maxSkill = 225,
            minSkill = 205,
            zones = _E,
          },
        },
        profession = "herbalism",
      },
      mining = {
        bands = {
          {
            itemIDs = _E,
            maxSkill = 65,
            minSkill = 1,
            zones = _E,
          },
          {
            itemIDs = _E,
            maxSkill = 125,
            minSkill = 65,
            zones = _E,
          },
          {
            itemIDs = _E,
            maxSkill = 175,
            minSkill = 125,
            zones = _E,
          },
          {
            itemIDs = _E,
            maxSkill = 225,
            minSkill = 175,
            zones = _E,
          },
        },
        profession = "mining",
      },
      skinning = {
        bands = {
          {
            itemIDs = _E,
            maxSkill = 75,
            minSkill = 1,
            zones = _E,
          },
          {
            itemIDs = _E,
            maxSkill = 125,
            minSkill = 75,
            zones = {
              { areaID = 17 },
              { areaID = 38 },
              { areaID = 148 },
            },
          },
          {
            itemIDs = _E,
            maxSkill = 175,
            minSkill = 125,
            zones = {
              { areaID = 331 },
              { areaID = 10 },
              { areaID = 267 },
              { areaID = 11 },
            },
          },
          {
            itemIDs = _E,
            maxSkill = 225,
            minSkill = 175,
            zones = {
              { areaID = 45 },
              { areaID = 33 },
              { areaID = 400 },
            },
          },
        },
        profession = "skinning",
      },
    },
  }
end
