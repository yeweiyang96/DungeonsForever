local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end

ns.Data._loaders["guides"] = function()
  return {
    fishingGuides = {
      cookingSteps = {},
      fish = {
        [2406] = {
          areas = {
            { areaID = 38, dropRatePct = 0.009, sampleCount = 21227 },
            { areaID = 1497, dropRatePct = 0.005, sampleCount = 21972 },
          },
        },
        [2407] = {
          areas = {
            { areaID = 1638, dropRatePct = 0.004, sampleCount = 27217 },
          },
        },
        [2408] = {
          areas = {
            { areaID = 1519, dropRatePct = 0.002, sampleCount = 56120 },
            { areaID = 1637, dropRatePct = 0.005, sampleCount = 36456 },
          },
        },
        [2409] = {
          areas = {
            { areaID = 331, dropRatePct = 0.001, sampleCount = 80385 },
            { areaID = 1519, dropRatePct = 0.002, sampleCount = 119862 },
            { areaID = 1638, dropRatePct = 0.002, sampleCount = 50658 },
          },
        },
        [2553] = {
          areas = {
            { areaID = 17, dropRatePct = 0.002, sampleCount = 50390 },
            { areaID = 215, dropRatePct = 0.006, sampleCount = 35199 },
            { areaID = 331, dropRatePct = 0.002, sampleCount = 80385 },
          },
        },
        [2555] = {
          areas = {
            { areaID = 1637, dropRatePct = 0.003, sampleCount = 36456 },
            { areaID = 16593, dropRatePct = 0.004, sampleCount = 23152 },
          },
        },
        [2598] = {
          areas = {
            { areaID = 1, dropRatePct = 0.004, sampleCount = 25014 },
            { areaID = 12, dropRatePct = 0.012, sampleCount = 33298 },
            { areaID = 85, dropRatePct = 0.006, sampleCount = 16503 },
            { areaID = 215, dropRatePct = 0.006, sampleCount = 35199 },
            { areaID = 1638, dropRatePct = 0.002, sampleCount = 50658 },
            { areaID = 16593, dropRatePct = 0.013, sampleCount = 23152 },
          },
        },
        [2601] = {
          areas = {
            { areaID = 44, dropRatePct = 0.003, sampleCount = 39438 },
          },
        },
        [2882] = {
          areas = {
            { areaID = 267, dropRatePct = 0.001, sampleCount = 96153 },
          },
        },
        [2883] = {
          areas = {
            { areaID = 38, dropRatePct = 0.005, sampleCount = 21227 },
          },
        },
        [3395] = {
          areas = {
            { areaID = 618, dropRatePct = 0.002, sampleCount = 47183 },
          },
        },
        [3396] = {
          areas = {
            { areaID = 36, dropRatePct = 0.003, sampleCount = 32658 },
          },
        },
        [3609] = {
          areas = {
            { areaID = 1, dropRatePct = 0.008, sampleCount = 25014 },
            { areaID = 12, dropRatePct = 0.005, sampleCount = 61918 },
            { areaID = 40, dropRatePct = 0.009, sampleCount = 10900 },
            { areaID = 85, dropRatePct = 0.005, sampleCount = 18763 },
            { areaID = 215, dropRatePct = 0.003, sampleCount = 35199 },
            { areaID = 1519, dropRatePct = 0.002, sampleCount = 56120 },
            { areaID = 1638, dropRatePct = 0.002, sampleCount = 50658 },
          },
        },
        [3610] = {
          areas = {
            { areaID = 12, dropRatePct = 0.003, sampleCount = 33298 },
            { areaID = 1638, dropRatePct = 0.004, sampleCount = 50658 },
          },
        },
        [3612] = {
          areas = {
            { areaID = 331, dropRatePct = 0.001, sampleCount = 80385 },
          },
        },
        [3866] = {
          areas = {
            { areaID = 44, dropRatePct = 0.003, sampleCount = 39438 },
          },
        },
        [3868] = {
          areas = {
            { areaID = 405, dropRatePct = 0.006, sampleCount = 16902 },
          },
        },
        [4292] = {
          areas = {
            { areaID = 148, dropRatePct = 0.002, sampleCount = 63607 },
            { areaID = 1519, dropRatePct = 0.002, sampleCount = 56120 },
          },
        },
        [4293] = {
          areas = {
            { areaID = 1519, dropRatePct = 0.002, sampleCount = 56120 },
          },
        },
        [4294] = {
          areas = {
            { areaID = 44, dropRatePct = 0.005, sampleCount = 21672 },
            { areaID = 406, dropRatePct = 0.002, sampleCount = 63585 },
          },
        },
        [4299] = {
          areas = {
            { areaID = 15, dropRatePct = 0.002, sampleCount = 40615 },
          },
        },
        [4345] = {
          areas = {
            { areaID = 1537, dropRatePct = 0.007, sampleCount = 14220 },
            { areaID = 1637, dropRatePct = 0.001, sampleCount = 88562 },
          },
        },
        [4346] = {
          areas = {
            { areaID = 148, dropRatePct = 0.002, sampleCount = 63607 },
            { areaID = 1638, dropRatePct = 0.004, sampleCount = 27217 },
          },
        },
        [4349] = {
          areas = {
            { areaID = 331, dropRatePct = 0.001, sampleCount = 80385 },
          },
        },
        [4351] = {
          areas = {
            { areaID = 15, dropRatePct = 0.002, sampleCount = 40615 },
          },
        },
        [4352] = {
          areas = {
            { areaID = 36, dropRatePct = 0.009, sampleCount = 32658 },
          },
        },
        [4408] = {
          areas = {
            { areaID = 331, dropRatePct = 0.001, sampleCount = 80385 },
          },
        },
        [4409] = {
          areas = {
            { areaID = 1637, dropRatePct = 0.002, sampleCount = 88562 },
          },
        },
        [4410] = {
          areas = {
            { areaID = 331, dropRatePct = 0.004, sampleCount = 25036 },
            { areaID = 406, dropRatePct = 0.002, sampleCount = 63585 },
            { areaID = 1637, dropRatePct = 0.001, sampleCount = 88562 },
          },
        },
        [4412] = {
          areas = {
            { areaID = 406, dropRatePct = 0.004, sampleCount = 26679 },
          },
        },
        [6044] = {
          areas = {
            { areaID = 331, dropRatePct = 0.004, sampleCount = 25036 },
          },
        },
        [6211] = {
          areas = {
            { areaID = 44, dropRatePct = 0.005, sampleCount = 21672 },
          },
        },
        [6271] = {
          areas = {
            { areaID = 17, dropRatePct = 0.002, sampleCount = 50390 },
          },
        },
        [6344] = {
          areas = {
            { areaID = 1519, dropRatePct = 0.002, sampleCount = 56120 },
            { areaID = 1638, dropRatePct = 0.004, sampleCount = 27217 },
          },
        },
        [6347] = {
          areas = {
            { areaID = 1637, dropRatePct = 0.003, sampleCount = 36456 },
          },
        },
        [6348] = {
          areas = {
            { areaID = 331, dropRatePct = 0.002, sampleCount = 80385 },
            { areaID = 1637, dropRatePct = 0.001, sampleCount = 88562 },
            { areaID = 1638, dropRatePct = 0.002, sampleCount = 50658 },
            { areaID = 1657, dropRatePct = 0.005, sampleCount = 19757 },
          },
        },
        [6391] = {
          areas = {
            { areaID = 331, dropRatePct = 0.001, sampleCount = 80385 },
            { areaID = 1657, dropRatePct = 0.005, sampleCount = 19757 },
          },
        },
        [7085] = {
          areas = {
            { areaID = 36, dropRatePct = 0.003, sampleCount = 32658 },
            { areaID = 405, dropRatePct = 0.006, sampleCount = 16902 },
          },
        },
        [7092] = {
          areas = {
            { areaID = 44, dropRatePct = 0.003, sampleCount = 39438 },
          },
        },
        [7975] = {
          areas = {
            { areaID = 490, dropRatePct = 0.011, sampleCount = 17774 },
          },
        },
        [7992] = {
          areas = {
            { areaID = 493, dropRatePct = 0.002, sampleCount = 217483 },
          },
        },
        [9293] = {
          areas = {
            { areaID = 28, dropRatePct = 0.054, sampleCount = 1848 },
          },
        },
        [9295] = {
          areas = {
            { areaID = 41, dropRatePct = 0.004, sampleCount = 22586 },
          },
        },
        [10312] = {
          areas = {
            { areaID = 357, dropRatePct = 0, sampleCount = 534356 },
          },
        },
        [10315] = {
          areas = {
            { areaID = 357, dropRatePct = 0.007, sampleCount = 15079 },
          },
        },
        [10606] = {
          areas = {
            { areaID = 28, dropRatePct = 0.054, sampleCount = 1848 },
          },
        },
        [11081] = {
          areas = {
            { areaID = 406, dropRatePct = 0.003, sampleCount = 63585 },
          },
        },
        [11098] = {
          areas = {
            { areaID = 44, dropRatePct = 0.005, sampleCount = 39438 },
          },
        },
        [11165] = {
          areas = {
            { areaID = 45, dropRatePct = 0.004, sampleCount = 24381 },
            { areaID = 405, dropRatePct = 0.001, sampleCount = 78584 },
          },
        },
        [11202] = {
          areas = {
            { areaID = 493, dropRatePct = 0.001, sampleCount = 217483 },
          },
        },
        [11204] = {
          areas = {
            { areaID = 357, dropRatePct = 0, sampleCount = 534356 },
          },
        },
        [11225] = {
          areas = {
            { areaID = 47, dropRatePct = 0.001, sampleCount = 169085 },
          },
        },
        [14466] = {
          areas = {
            { areaID = 41, dropRatePct = 0.004, sampleCount = 22586 },
          },
        },
        [14474] = {
          areas = {
            { areaID = 618, dropRatePct = 0.002, sampleCount = 47183 },
          },
        },
        [14478] = {
          areas = {
            { areaID = 618, dropRatePct = 0.002, sampleCount = 47183 },
          },
        },
        [14492] = {
          areas = {
            { areaID = 41, dropRatePct = 0.004, sampleCount = 22586 },
          },
        },
        [14508] = {
          areas = {
            { areaID = 618, dropRatePct = 0.002, sampleCount = 47183 },
          },
        },
        [15743] = {
          areas = {
            { areaID = 618, dropRatePct = 0.004, sampleCount = 47183 },
          },
        },
        [15745] = {
          areas = {
            { areaID = 139, dropRatePct = 0.004, sampleCount = 28285 },
          },
        },
        [15746] = {
          areas = {
            { areaID = 618, dropRatePct = 0.002, sampleCount = 47183 },
          },
        },
        [15757] = {
          areas = {
            { areaID = 616, dropRatePct = 0.033, sampleCount = 3022 },
          },
        },
        [16218] = {
          areas = {
            { areaID = 139, dropRatePct = 0.004, sampleCount = 28285 },
          },
        },
      },
      fishingSteps = {
        {
          areas = {},
          fishIDs = {},
          from = 1,
          to = 75,
        },
        {
          areas = {
            { areaID = 1657, minSkill = 1, noGetaway = 75 },
            { areaID = 1537, minSkill = 1, noGetaway = 75 },
            { areaID = 1519, minSkill = 1, noGetaway = 75 },
            { areaID = 1637, minSkill = 1, noGetaway = 75 },
            { areaID = 1638, minSkill = 1, noGetaway = 75 },
            { areaID = 1497, minSkill = 1, noGetaway = 75 },
          },
          fishIDs = {},
          from = 75,
          to = 150,
        },
        {
          areas = {
            {
              areaID = 15,
              requirements = {
                {
                  locationsText = "Alterac Mountains, Arathi Highlands, Desolace, Dustwallow Marsh, Scarlet Monastery, Stranglethorn Vale (excluding Jaguero Isle), Swamp of Sorrows, and Thousand Needles",
                  minSkill = 130,
                  noGetaway = 225,
                },
              },
            },
            {
              areaID = 33,
              requirements = {
                {
                  locationsText = "Alterac Mountains, Arathi Highlands, Desolace, Dustwallow Marsh, Scarlet Monastery, Stranglethorn Vale (excluding Jaguero Isle), Swamp of Sorrows, and Thousand Needles",
                  minSkill = 130,
                  noGetaway = 225,
                },
                {
                  locationsText = "Azshara (excluding Bay of Storms, Hetaera's Clutch, and Scalebeard's Cave), Felwood, Feralas, The Hinterlands, Maraudon, Moonglade, Stranglethorn Vale (Jaguero Isle), Tanaris, The Temple of Atal'Hakkar, Un'Goro Crater, and Western Plaguelands.",
                  minSkill = 205,
                  noGetaway = 300,
                },
              },
            },
          },
          fishIDs = {},
          from = 150,
          to = 225,
        },
        {
          areas = {
            {
              areaID = 440,
              requirements = {
                {
                  locationsText = "Azshara (excluding Bay of Storms, Hetaera's Clutch, and Scalebeard's Cave), Felwood, Feralas, The Hinterlands, Maraudon, Moonglade, Stranglethorn Vale (Jaguero Isle), Tanaris, The Temple of Atal'Hakkar, Un'Goro Crater, and Western Plaguelands.",
                  minSkill = 205,
                  noGetaway = 300,
                },
              },
            },
          },
          fishIDs = {},
          from = 225,
          to = 300,
        },
      },
    },
    gatheringGuides = {
      herbalism = {
        bands = {
          {
            itemIDs = {},
            maxSkill = 70,
            minSkill = 1,
            zones = {},
          },
          {
            itemIDs = {},
            maxSkill = 115,
            minSkill = 70,
            zones = {},
          },
          {
            itemIDs = {},
            maxSkill = 170,
            minSkill = 115,
            zones = {},
          },
          {
            itemIDs = {},
            maxSkill = 205,
            minSkill = 170,
            zones = {},
          },
          {
            itemIDs = {},
            maxSkill = 225,
            minSkill = 205,
            zones = {},
          },
        },
        profession = "herbalism",
      },
      mining = {
        bands = {
          {
            itemIDs = {},
            maxSkill = 65,
            minSkill = 1,
            zones = {},
          },
          {
            itemIDs = {},
            maxSkill = 125,
            minSkill = 65,
            zones = {},
          },
          {
            itemIDs = {},
            maxSkill = 175,
            minSkill = 125,
            zones = {},
          },
          {
            itemIDs = {},
            maxSkill = 225,
            minSkill = 175,
            zones = {},
          },
        },
        profession = "mining",
      },
      skinning = {
        bands = {
          {
            itemIDs = {},
            maxSkill = 75,
            minSkill = 1,
            zones = {},
          },
          {
            itemIDs = {},
            maxSkill = 125,
            minSkill = 75,
            zones = {
              { areaID = 17 },
              { areaID = 38 },
              { areaID = 148 },
            },
          },
          {
            itemIDs = {},
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
            itemIDs = {},
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
