local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end

local _E = ns.Data._empty
ns.Data._loaders["systems"] = function()
  return {
    camping = {
      camp_spell_1229432 = {
        campKey = "camp_spell_1229432",
        formulaItemIDs = _E,
        icon = 134250,
        itemID = 279978,
        profession = "leatherworking",
        reagents = {
          { count = 5, itemID = 2318 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1229432,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1229432",
      },
      camp_spell_1229504 = {
        campKey = "camp_spell_1229504",
        formulaItemIDs = _E,
        icon = 132484,
        itemID = 279972,
        profession = "tailoring",
        reagents = {
          { count = 1, itemID = 2320 },
          { count = 1, itemID = 2996 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1229504,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1229504",
      },
      camp_spell_1229517 = {
        campKey = "camp_spell_1229517",
        formulaItemIDs = _E,
        icon = 132761,
        itemID = 279979,
        profession = "skinning",
        reagents = {
          { count = 3, itemID = 2318 },
          { count = 2, itemID = 4470 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/item=279979",
      },
      camp_spell_1229705 = {
        campKey = "camp_spell_1229705",
        formulaItemIDs = _E,
        icon = 133751,
        itemID = 279962,
        profession = "herbalism",
        reagents = {
          { count = 1, itemID = 765 },
          { count = 1, itemID = 2447 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/item=279962",
      },
      camp_spell_1229737 = {
        campKey = "camp_spell_1229737",
        campfireCapacity = 3,
        formulaItemIDs = _E,
        icon = 7808148,
        itemID = 279981,
        profession = "cooking",
        reagents = {
          { count = 1, itemID = 4470 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1229737,
        tier = 0,
        wowheadURL = "https://www.wowhead.com/forever/spell=1229737",
      },
      camp_spell_1229745 = {
        campKey = "camp_spell_1229745",
        formulaItemIDs = _E,
        icon = 4777763,
        itemID = 279967,
        profession = "fishing",
        reagents = {
          { count = 1, itemID = 3371 },
          { count = 1, itemID = 6291 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1229745,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1229745",
      },
      camp_spell_1230117 = {
        campKey = "camp_spell_1230117",
        formulaItemIDs = _E,
        icon = 133681,
        itemID = 279968,
        profession = "first-aid",
        reagents = {
          { count = 1, itemID = 159 },
          { count = 3, itemID = 1251 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1230117,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1230117",
      },
      camp_spell_1230161 = {
        campKey = "camp_spell_1230161",
        formulaItemIDs = _E,
        icon = 134419,
        itemID = 279960,
        profession = "mining",
        reagents = {
          { count = 1, itemID = 2835 },
          { count = 1, itemID = 2840 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1230161,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1230161",
      },
      camp_spell_1230171 = {
        campKey = "camp_spell_1230171",
        formulaItemIDs = _E,
        icon = 135243,
        itemID = 279944,
        profession = "blacksmithing",
        reagents = {
          { count = 1, itemID = 2835 },
          { count = 1, itemID = 2840 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1230171,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1230171",
      },
      camp_spell_1230564 = {
        campKey = "camp_spell_1230564",
        formulaItemIDs = _E,
        icon = 135738,
        itemID = 279956,
        profession = "alchemy",
        reagents = {
          { count = 1, itemID = 2447 },
          { count = 1, itemID = 3371 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1230564,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1230564",
      },
      camp_spell_1230643 = {
        campKey = "camp_spell_1230643",
        formulaItemIDs = _E,
        icon = 4631367,
        itemID = 279976,
        profession = "enchanting",
        reagents = {
          { count = 1, itemID = 4470 },
          { count = 1, itemID = 10940 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1230643,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1230643",
      },
      camp_spell_1230656 = {
        campKey = "camp_spell_1230656",
        formulaItemIDs = _E,
        icon = 133871,
        itemID = 279950,
        profession = "engineering",
        reagents = {
          { count = 1, itemID = 4359 },
          { count = 1, itemID = 4361 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1230656,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1230656",
      },
      camp_spell_1262975 = {
        campKey = "camp_spell_1262975",
        formulaItemIDs = _E,
        icon = 134385,
        itemID = 279948,
        profession = "mining",
        reagents = {
          { count = 1, itemID = 2772 },
          { count = 2, itemID = 2838 },
          { count = 1, itemID = 2842 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        spellID = 1262975,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1262975",
      },
      camp_spell_1262978 = {
        campKey = "camp_spell_1262978",
        formulaItemIDs = _E,
        icon = 2066011,
        itemID = 279957,
        profession = "cooking",
        reagents = {
          { count = 1, itemID = 3713 },
          { count = 2, itemID = 12037 },
          { count = 1, itemID = 12204 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        spellID = 1262978,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1262978",
      },
      camp_spell_1262980 = {
        campKey = "camp_spell_1262980",
        formulaItemIDs = _E,
        icon = 134188,
        itemID = 279964,
        profession = "herbalism",
        reagents = {
          { count = 2, itemID = 4470 },
          { count = 1, itemID = 8831 },
          { count = 1, itemID = 8836 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/item=279964",
      },
      camp_spell_1262982 = {
        campKey = "camp_spell_1262982",
        formulaItemIDs = _E,
        icon = 5948139,
        itemID = 279938,
        profession = "skinning",
        reagents = {
          { count = 1, itemID = 3575 },
          { count = 4, itemID = 4234 },
          { count = 2, itemID = 4470 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/item=279938",
      },
      camp_spell_1262985 = {
        campKey = "camp_spell_1262985",
        formulaItemIDs = _E,
        icon = 133735,
        itemID = 279969,
        profession = "skinning",
        reagents = {
          { count = 3, itemID = 2319 },
          { count = 1, itemID = 2321 },
          { count = 2, itemID = 5784 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/item=279969",
      },
      camp_spell_1262990 = {
        campKey = "camp_spell_1262990",
        formulaItemIDs = _E,
        icon = 1053359,
        itemID = 279965,
        profession = "fishing",
        reagents = {
          { count = 2, itemID = 4470 },
          { count = 2, itemID = 8365 },
          { count = 1, itemID = 8925 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        spellID = 1262990,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1262990",
      },
      camp_spell_1262996 = {
        campKey = "camp_spell_1262996",
        formulaItemIDs = _E,
        icon = 463860,
        itemID = 279940,
        profession = "first-aid",
        reagents = {
          { count = 2, itemID = 4470 },
          { count = 1, itemID = 6452 },
          { count = 2, itemID = 8544 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        spellID = 1262996,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1262996",
      },
      camp_spell_1262998 = {
        campKey = "camp_spell_1262998",
        formulaItemIDs = _E,
        icon = 132930,
        itemID = 279966,
        profession = "fishing",
        reagents = {
          { count = 5, itemID = 4470 },
          { count = 2, itemID = 14048 },
          { count = 1, itemID = 273295 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1262998,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1262998",
      },
      camp_spell_1263001 = {
        campKey = "camp_spell_1263001",
        formulaItemIDs = _E,
        icon = 4626285,
        itemID = 279951,
        profession = "first-aid",
        reagents = {
          { count = 2, itemID = 4470 },
          { count = 2, itemID = 6453 },
          { count = 5, itemID = 14530 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1263001,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263001",
      },
      camp_spell_1263005 = {
        campKey = "camp_spell_1263005",
        formulaItemIDs = _E,
        icon = 3566827,
        itemID = 279970,
        profession = "alchemy",
        reagents = {
          { count = 1, itemID = 2452 },
          { count = 1, itemID = 3356 },
          { count = 1, itemID = 3372 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        spellID = 1263005,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263005",
      },
      camp_spell_1263031 = {
        campKey = "camp_spell_1263031",
        formulaItemIDs = _E,
        icon = 4559256,
        itemID = 279941,
        profession = "leatherworking",
        reagents = {
          { count = 5, itemID = 2319 },
          { count = 3, itemID = 2321 },
          { count = 2, itemID = 4470 },
        },
        reagentsKnown = true,
        reqSkill = 125,
        spellID = 1263031,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263031",
      },
      camp_spell_1263032 = {
        campKey = "camp_spell_1263032",
        formulaItemIDs = _E,
        icon = 4777839,
        itemID = 279943,
        profession = "tailoring",
        reagents = {
          { count = 3, itemID = 2321 },
          { count = 5, itemID = 4305 },
          { count = 2, itemID = 4470 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        spellID = 1263032,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263032",
      },
      camp_spell_1263034 = {
        campKey = "camp_spell_1263034",
        formulaItemIDs = _E,
        icon = 1336885,
        itemID = 279949,
        profession = "engineering",
        reagents = {
          { count = 1, itemID = 4234 },
          { count = 1, itemID = 4371 },
          { count = 2, itemID = 4375 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        spellID = 1263034,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263034",
      },
      camp_spell_1263041 = {
        campKey = "camp_spell_1263041",
        formulaItemIDs = _E,
        icon = 1020356,
        itemID = 279988,
        profession = "blacksmithing",
        reagents = {
          { count = 2, itemID = 2319 },
          { count = 5, itemID = 2841 },
          { count = 2, itemID = 3478 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        spellID = 1263041,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263041",
      },
      camp_spell_1263056 = {
        campKey = "camp_spell_1263056",
        formulaItemIDs = _E,
        icon = 986482,
        itemID = 279985,
        profession = "enchanting",
        reagents = {
          { count = 2, itemID = 11137 },
          { count = 1, itemID = 11174 },
        },
        reagentsKnown = true,
        reqSkill = 140,
        spellID = 1263056,
        tier = 2,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263056",
      },
      camp_spell_1263067 = {
        campKey = "camp_spell_1263067",
        formulaItemIDs = _E,
        icon = 629055,
        itemID = 279982,
        profession = "cooking",
        reagents = {
          { count = 5, itemID = 159 },
          { count = 4, itemID = 3713 },
          { count = 10, itemID = 10284 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1263067,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263067",
      },
      camp_spell_1263070 = {
        campKey = "camp_spell_1263070",
        formulaItemIDs = _E,
        icon = 656440,
        itemID = 279947,
        profession = "herbalism",
        reagents = {
          { count = 1, itemID = 8925 },
          { count = 4, itemID = 13465 },
          { count = 2, itemID = 14047 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/item=279947",
      },
      camp_spell_1263071 = {
        campKey = "camp_spell_1263071",
        formulaItemIDs = _E,
        icon = 5931157,
        itemID = 279952,
        profession = "mining",
        reagents = {
          { count = 1, itemID = 6037 },
          { count = 5, itemID = 12359 },
          { count = 2, itemID = 12365 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1263071,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263071",
      },
      camp_spell_1263073 = {
        campKey = "camp_spell_1263073",
        formulaItemIDs = _E,
        icon = 4374708,
        itemID = 279955,
        profession = "blacksmithing",
        reagents = {
          { count = 2, itemID = 8170 },
          { count = 5, itemID = 12359 },
          { count = 1, itemID = 273127 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1263073,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263073",
      },
      camp_spell_1263078 = {
        campKey = "camp_spell_1263078",
        formulaItemIDs = _E,
        icon = 4777830,
        itemID = 279990,
        profession = "alchemy",
        reagents = {
          { count = 1, itemID = 8925 },
          { count = 2, itemID = 13463 },
          { count = 1, itemID = 273125 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1263078,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263078",
      },
      camp_spell_1263079 = {
        campKey = "camp_spell_1263079",
        formulaItemIDs = _E,
        icon = 3622223,
        itemID = 279945,
        profession = "leatherworking",
        reagents = {
          { count = 5, itemID = 8170 },
          { count = 1, itemID = 14341 },
          { count = 1, itemID = 273130 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1263079,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263079",
      },
      camp_spell_1263080 = {
        campKey = "camp_spell_1263080",
        formulaItemIDs = _E,
        icon = 2067081,
        itemID = 279959,
        profession = "tailoring",
        reagents = {
          { count = 4, itemID = 4470 },
          { count = 4, itemID = 14048 },
          { count = 1, itemID = 273131 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1263080,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263080",
      },
      camp_spell_1263082 = {
        campKey = "camp_spell_1263082",
        formulaItemIDs = _E,
        icon = 3622205,
        itemID = 279987,
        profession = "enchanting",
        reagents = {
          { count = 2, itemID = 14344 },
          { count = 4, itemID = 16203 },
          { count = 1, itemID = 273128 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1263082,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263082",
      },
      camp_spell_1263083 = {
        campKey = "camp_spell_1263083",
        formulaItemIDs = _E,
        icon = 4624728,
        itemID = 279989,
        profession = "engineering",
        reagents = {
          { count = 2, itemID = 15994 },
          { count = 1, itemID = 273129 },
        },
        reagentsKnown = true,
        reqSkill = 300,
        spellID = 1263083,
        tier = 3,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263083",
      },
      camp_spell_1263425 = {
        campKey = "camp_spell_1263425",
        formulaItemIDs = _E,
        icon = 132484,
        itemID = 279973,
        profession = "tailoring",
        reagents = {
          { count = 1, itemID = 2320 },
          { count = 1, itemID = 2996 },
        },
        reagentsKnown = true,
        reqSkill = 1,
        spellID = 1263425,
        tier = 1,
        wowheadURL = "https://www.wowhead.com/forever/spell=1263425",
      },
      camp_spell_1278062 = {
        campKey = "camp_spell_1278062",
        formulaItemIDs = _E,
        icon = 134435,
        profession = "herbalism",
        reagents = _E,
        reagentsKnown = true,
        reqSkill = 1,
        tier = 4,
      },
      camp_spell_1278067 = {
        campKey = "camp_spell_1278067",
        formulaItemIDs = _E,
        icon = 466035,
        profession = "fishing",
        reagents = _E,
        reagentsKnown = true,
        reqSkill = 1,
        tier = 4,
      },
      camp_spell_1278068 = {
        campKey = "camp_spell_1278068",
        formulaItemIDs = _E,
        icon = 4777838,
        profession = "skinning",
        reagents = _E,
        reagentsKnown = true,
        reqSkill = 1,
        tier = 4,
      },
      camp_spell_1283400 = {
        campKey = "camp_spell_1283400",
        campfireCapacity = 5,
        formulaItemIDs = _E,
        icon = 7808148,
        itemID = 279961,
        profession = "cooking",
        reagents = {
          { count = 1, itemID = 11291 },
        },
        reagentsKnown = true,
        reqSkill = 90,
        spellID = 1283400,
        tier = 0,
        wowheadURL = "https://www.wowhead.com/forever/spell=1283400",
      },
      camp_spell_1291341 = {
        campKey = "camp_spell_1291341",
        campfireCapacity = 10,
        formulaItemIDs = _E,
        icon = 7808148,
        itemID = 279974,
        profession = "cooking",
        reagents = {
          { count = 1, itemID = 272941 },
        },
        reagentsKnown = true,
        reqSkill = 200,
        spellID = 1291341,
        tier = 0,
        wowheadURL = "https://www.wowhead.com/forever/spell=1291341",
      },
    },
    certifications = {
      alchemy = { icon = 237450, itemID = 271621, profession = "alchemy", reqSkill = 300 },
      blacksmithing = { icon = 237450, itemID = 271622, profession = "blacksmithing", reqSkill = 300 },
      enchanting = { icon = 237450, itemID = 271624, profession = "enchanting", reqSkill = 300 },
      engineering = { icon = 237450, itemID = 271625, profession = "engineering", reqSkill = 300 },
      leatherworking = { icon = 237450, itemID = 271626, profession = "leatherworking", reqSkill = 300 },
      tailoring = { icon = 237450, itemID = 271627, profession = "tailoring", reqSkill = 300 },
    },
    comprehension = {
      bundle = {
        drops = {
          { itemID = 213564, ratePct = 3788 },
          { itemID = 215257, ratePct = 3729 },
          { itemID = 274947, ratePct = 7553 },
          { itemID = 275067, ratePct = 7547 },
          { itemID = 275069, ratePct = 7535 },
        },
        itemID = 277651,
        sampleCount = 17,
      },
      tiers = {
        {
          greySkill = 30,
          reqSkill = 1,
          scrollItemIDs = { 211780, 211785, 211786, 211787 },
          tierKey = "tier_1",
        },
        {
          greySkill = 75,
          reqSkill = 15,
          scrollItemIDs = { 211784, 211853, 211854, 211855 },
          tierKey = "tier_15",
        },
        {
          greySkill = 200,
          reqSkill = 50,
          scrollItemIDs = { 213543, 213544, 213545, 213546, 213547 },
          tierKey = "tier_50",
        },
        {
          greySkill = 300,
          reqSkill = 175,
          scrollItemIDs = { 281015, 281016, 281017, 281018 },
          tierKey = "tier_175",
        },
      },
    },
    essences = {
      [10938] = {
        inputCount = 3,
        inputItemID = 10938,
        noSkillGain = true,
        outputCount = 1,
        outputItemID = 10939,
        pairKey = "magic",
        profession = "enchanting",
      },
      [10939] = {
        inputCount = 1,
        inputItemID = 10939,
        noSkillGain = true,
        outputCount = 3,
        outputItemID = 10938,
        pairKey = "magic",
        profession = "enchanting",
      },
      [10998] = {
        inputCount = 3,
        inputItemID = 10998,
        noSkillGain = true,
        outputCount = 1,
        outputItemID = 11082,
        pairKey = "astral",
        profession = "enchanting",
      },
      [11082] = {
        inputCount = 1,
        inputItemID = 11082,
        noSkillGain = true,
        outputCount = 3,
        outputItemID = 10998,
        pairKey = "astral",
        profession = "enchanting",
      },
      [11134] = {
        inputCount = 3,
        inputItemID = 11134,
        noSkillGain = true,
        outputCount = 1,
        outputItemID = 11135,
        pairKey = "mystic",
        profession = "enchanting",
      },
      [11135] = {
        inputCount = 1,
        inputItemID = 11135,
        noSkillGain = true,
        outputCount = 3,
        outputItemID = 11134,
        pairKey = "mystic",
        profession = "enchanting",
      },
      [11174] = {
        inputCount = 3,
        inputItemID = 11174,
        noSkillGain = true,
        outputCount = 1,
        outputItemID = 11175,
        pairKey = "nether",
        profession = "enchanting",
      },
      [11175] = {
        inputCount = 1,
        inputItemID = 11175,
        noSkillGain = true,
        outputCount = 3,
        outputItemID = 11174,
        pairKey = "nether",
        profession = "enchanting",
      },
      [16202] = {
        inputCount = 3,
        inputItemID = 16202,
        noSkillGain = true,
        outputCount = 1,
        outputItemID = 16203,
        pairKey = "eternal",
        profession = "enchanting",
      },
      [16203] = {
        inputCount = 1,
        inputItemID = 16203,
        noSkillGain = true,
        outputCount = 3,
        outputItemID = 16202,
        pairKey = "eternal",
        profession = "enchanting",
      },
    },
    legacyPerks = {
      legacy_node_110284 = {
        category = "profession",
        icon = 133740,
        maxRank = 1,
        perkKey = "legacy_node_110284",
        professions = _E,
        traitNodeID = 110284,
      },
      legacy_node_110286 = {
        category = "profession",
        icon = 133789,
        maxRank = 2,
        perkKey = "legacy_node_110286",
        professions = _E,
        traitNodeID = 110286,
      },
      legacy_node_110289 = {
        category = "profession",
        icon = 236571,
        maxRank = 5,
        perkKey = "legacy_node_110289",
        professions = { "cooking" },
        traitNodeID = 110289,
      },
      legacy_node_110290 = {
        category = "profession",
        icon = 134378,
        maxRank = 5,
        perkKey = "legacy_node_110290",
        professions = _E,
        traitNodeID = 110290,
      },
      legacy_node_110291 = {
        category = "profession",
        icon = 133651,
        maxRank = 5,
        perkKey = "legacy_node_110291",
        professions = { "mining", "herbalism", "skinning" },
        traitNodeID = 110291,
      },
      legacy_node_110292 = {
        category = "profession",
        icon = 135725,
        maxRank = 3,
        perkKey = "legacy_node_110292",
        professions = { "alchemy", "blacksmithing", "enchanting", "engineering", "leatherworking", "tailoring" },
        traitNodeID = 110292,
      },
      legacy_node_110293 = {
        category = "profession",
        icon = 237270,
        maxRank = 2,
        perkKey = "legacy_node_110293",
        professions = { "fishing" },
        traitNodeID = 110293,
      },
      legacy_node_113506 = {
        category = "profession",
        icon = 134400,
        maxRank = 1,
        perkKey = "legacy_node_113506",
        professions = _E,
        traitNodeID = 113506,
      },
      legacy_node_113508 = {
        category = "profession",
        icon = 134400,
        maxRank = 1,
        perkKey = "legacy_node_113508",
        professions = _E,
        traitNodeID = 113508,
      },
    },
    ranks = {
      alchemy = {
        {
          conditions = _E,
          method = "trainer",
          profession = "alchemy",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3603,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1470,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1215,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 253004,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5500,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1246,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11041,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2132,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3184,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11047,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11046,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11044,
            },
            { npcID = 257019 },
            { npcID = 257005 },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "alchemy",
          rankIndex = 2,
          rankKey = "journeyman",
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3964,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5499,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5177,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3009,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3347,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4609,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2391,
            },
            { npcID = 2837 },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "alchemy",
          rankIndex = 3,
          rankKey = "expert",
          skillCap = 225,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4160,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 246795,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4611,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "alchemy",
          rankIndex = 4,
          rankKey = "artisan",
          skillCap = 300,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 7948,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 1386,
            },
            { npcID = 259585 },
          },
        },
      },
      blacksmithing = {
        {
          conditions = _E,
          method = "trainer",
          profession = "blacksmithing",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2836,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3355,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4258,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 28694,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "blacksmithing",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2836,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3355,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4258,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 28694,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "blacksmithing",
          rankIndex = 3,
          rankKey = "expert",
          reqLevel = 20,
          reqSkill = 125,
          routeReminderSkill = 125,
          skillCap = 225,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3355,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4258,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 28694,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "blacksmithing",
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 200,
          routeReminderSkill = 200,
          skillCap = 300,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2836,
            },
          },
        },
      },
      cooking = {
        {
          conditions = _E,
          method = "trainer",
          profession = "cooking",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1355,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 1382,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1430,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1699,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3026,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3067,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3087,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3399,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4210,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4552,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5159,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5482,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6286,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 244512,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 249968,
            },
            { npcID = 251905 },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 252084,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 256655,
            },
            { npcID = 257006 },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 265944,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "cooking",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1355,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 1382,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1430,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1699,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3026,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3067,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3087,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3399,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4210,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4552,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5159,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5482,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6286,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 244512,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 249968,
            },
            { npcID = 251905 },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 252084,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 256655,
            },
            { npcID = 257006 },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 265944,
            },
          },
        },
        {
          bookItemID = 16072,
          conditions = _E,
          method = "book",
          profession = "cooking",
          rankIndex = 3,
          rankKey = "expert",
          skillCap = 225,
          trainers = {
            { npcID = 3955 },
            { npcID = 12033 },
          },
        },
        {
          conditions = {
            { kind = "skill", min = 225, profession = "cooking" },
            { kind = "level", min = 35 },
          },
          method = "quest",
          profession = "cooking",
          questID = 6610,
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 225,
          routeReminderSkill = 225,
          skillCap = 300,
          trainers = {
            { npcID = 8125 },
            { npcID = 5428 },
            { npcID = 5429 },
            { npcID = 5430 },
            { npcID = 14123 },
          },
        },
      },
      enchanting = {
        {
          conditions = {
            { kind = "skill", min = 1, profession = "enchanting" },
            { kind = "level", min = 1 },
          },
          method = "trainer",
          profession = "enchanting",
          rankIndex = 1,
          rankKey = "apprentice",
          reqLevel = 1,
          reqSkill = 1,
          routeReminderSkill = 1,
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3606,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11065,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11068,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11070,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1317,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5157,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 7949,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11071,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5695,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11066,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11067,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3011,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3345,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4616,
            },
          },
        },
        {
          conditions = {
            { kind = "skill", min = 50, profession = "enchanting" },
            { kind = "level", min = 10 },
          },
          method = "trainer",
          profession = "enchanting",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3606,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11065,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11068,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11070,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1317,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5157,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 7949,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11071,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5695,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11066,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11067,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3011,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3345,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4616,
            },
          },
        },
        {
          conditions = {
            { kind = "skill", min = 125, profession = "enchanting" },
            { kind = "level", min = 20 },
          },
          method = "trainer",
          profession = "enchanting",
          rankIndex = 3,
          rankKey = "expert",
          reqLevel = 20,
          reqSkill = 125,
          routeReminderSkill = 125,
          skillCap = 225,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11072,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11074,
            },
          },
        },
        {
          conditions = {
            { kind = "skill", min = 225, profession = "enchanting" },
            { kind = "level", min = 35 },
          },
          method = "trainer",
          profession = "enchanting",
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 225,
          routeReminderSkill = 225,
          skillCap = 300,
          trainers = {
            { npcID = 11073 },
          },
        },
      },
      engineering = {
        {
          conditions = {
            { kind = "skill", min = 1, profession = "engineering" },
            { kind = "level", min = 1 },
          },
          method = "trainer",
          profession = "engineering",
          rankIndex = 1,
          rankKey = "apprentice",
          reqLevel = 1,
          reqSkill = 1,
          routeReminderSkill = 1,
          skillCap = 75,
          trainers = {
            { npcID = 1702 },
            { npcID = 11028 },
            { npcID = 3290 },
            { npcID = 11026 },
            { npcID = 4586 },
            { npcID = 11037 },
            { npcID = 11025 },
            { npcID = 10993 },
            { npcID = 2857 },
            { npcID = 3494 },
            { npcID = 251684 },
          },
        },
        {
          conditions = {
            { kind = "skill", min = 50, profession = "engineering" },
            { kind = "level", min = 10 },
          },
          method = "trainer",
          profession = "engineering",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            { npcID = 1676 },
            { npcID = 11029 },
            { npcID = 3412 },
          },
        },
        {
          conditions = {
            { kind = "skill", min = 125, profession = "engineering" },
            { kind = "level", min = 20 },
          },
          method = "trainer",
          profession = "engineering",
          rankIndex = 3,
          rankKey = "expert",
          reqLevel = 20,
          reqSkill = 125,
          routeReminderSkill = 125,
          skillCap = 225,
          trainers = {
            { npcID = 5174 },
            { npcID = 5518 },
            { npcID = 11031 },
            { npcID = 11017 },
          },
        },
        {
          conditions = {
            { kind = "skill", min = 225, profession = "engineering" },
            { kind = "level", min = 35 },
          },
          method = "trainer",
          profession = "engineering",
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 225,
          routeReminderSkill = 225,
          skillCap = 300,
          trainers = {
            { npcID = 249235 },
            { npcID = 8736 },
          },
        },
      },
      ["first-aid"] = {
        {
          conditions = _E,
          method = "trainer",
          profession = "first-aid",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2326,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2327,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2329,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2798,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3181,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3373,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4211,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4591,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5150,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5759,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5939,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5943,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6094,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 251977,
            },
            { npcID = 257007 },
            { npcID = 257018 },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "first-aid",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2326,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2327,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2329,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2798,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3181,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3373,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4211,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4591,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5150,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5759,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5939,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5943,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6094,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 251977,
            },
            { npcID = 257007 },
            { npcID = 257018 },
          },
        },
        {
          bookItemID = 16084,
          conditions = _E,
          method = "book",
          profession = "first-aid",
          rankIndex = 3,
          rankKey = "expert",
          skillCap = 225,
          trainers = {
            { npcID = 2805 },
            { npcID = 13476 },
          },
        },
        {
          conditions = {
            { kind = "skill", min = 225, profession = "first-aid" },
            { kind = "level", min = 35 },
          },
          method = "quest",
          profession = "first-aid",
          questID = 6625,
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 225,
          routeReminderSkill = 225,
          skillCap = 300,
          trainers = {
            { npcID = 5150 },
            { npcID = 3373 },
            { npcID = 12939 },
            { npcID = 12920 },
          },
        },
      },
      fishing = {
        {
          conditions = _E,
          method = "trainer",
          profession = "fishing",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1651,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1680,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1683,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1700,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2367,
            },
            { npcID = 2834 },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3028,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3179,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3332,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3607,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4156,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4573,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5161,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5493,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5690,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5938,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5941,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 7946,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 12032,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 12961,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 14740,
            },
            { npcID = 251992 },
            { npcID = 257008 },
            { npcID = 260558 },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "fishing",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1651,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1680,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1683,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1700,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 2367,
            },
            { npcID = 2834 },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3028,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3179,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3332,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3607,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4156,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4573,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5161,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5493,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5690,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5938,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 5941,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 7946,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 12032,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 12961,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 14740,
            },
            { npcID = 251992 },
            { npcID = 257008 },
            { npcID = 260558 },
          },
        },
        {
          bookItemID = 16083,
          conditions = _E,
          method = "book",
          profession = "fishing",
          rankIndex = 3,
          rankKey = "expert",
          skillCap = 225,
          trainers = {
            { npcID = 2626 },
          },
        },
        {
          conditions = {
            { kind = "skill", min = 225, profession = "fishing" },
            { kind = "level", min = 35 },
          },
          method = "quest",
          profession = "fishing",
          questID = 6607,
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 225,
          routeReminderSkill = 225,
          skillCap = 300,
          trainers = {
            { npcID = 12919 },
          },
        },
      },
      herbalism = {
        {
          conditions = _E,
          method = "trainer",
          profession = "herbalism",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 812,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 908,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1218,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1458,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1473,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2114,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2390,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2856,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3013,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3185,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3404,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3604,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3965,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4204,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4614,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4898,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5137,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5502,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5566,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 8146,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 12025,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 247223,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 254345,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257021,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 267326,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 267329,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 267332,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 267335,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 267338,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 275321,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "herbalism",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 812,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 908,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1218,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1458,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1473,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2114,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2390,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2856,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3013,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3185,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3404,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3604,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3965,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4204,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4614,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4898,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5137,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5502,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5566,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 8146,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 12025,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 254345,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257021,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 275321,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "herbalism",
          rankIndex = 3,
          rankKey = "expert",
          reqLevel = 20,
          reqSkill = 125,
          routeReminderSkill = 125,
          skillCap = 225,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 812,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 908,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1218,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1458,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1473,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2114,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2390,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2856,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3013,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3185,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3404,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3604,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3965,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4204,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4614,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4898,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5137,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5502,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5566,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 8146,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 12025,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 254345,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257021,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 275321,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "herbalism",
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 200,
          routeReminderSkill = 200,
          skillCap = 300,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 812,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 908,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1218,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1458,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1473,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2114,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2390,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2856,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3013,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3185,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3404,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3604,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3965,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4204,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4614,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4898,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5137,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5502,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5566,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 8146,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 12025,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 254345,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257021,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 275321,
            },
          },
        },
      },
      leatherworking = {
        {
          conditions = _E,
          method = "trainer",
          profession = "leatherworking",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3007,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4212,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7088,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11097,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11098,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "leatherworking",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3007,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4212,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11097,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11098,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "leatherworking",
          rankIndex = 3,
          rankKey = "expert",
          reqLevel = 20,
          reqSkill = 125,
          routeReminderSkill = 125,
          skillCap = 225,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3007,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4212,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "leatherworking",
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 200,
          routeReminderSkill = 200,
          skillCap = 300,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11097,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11098,
            },
          },
        },
      },
      mining = {
        {
          conditions = _E,
          method = "trainer",
          profession = "mining",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1681,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1701,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3001,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3137,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3175,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3357,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3555,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4254,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4598,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5392,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5513,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6297,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 247226,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 267325,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 267328,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 267331,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 267334,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 267337,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "mining",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1681,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1701,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3001,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3137,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3175,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3357,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3555,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4254,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4598,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5392,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5513,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6297,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "mining",
          rankIndex = 3,
          rankKey = "expert",
          reqLevel = 20,
          reqSkill = 125,
          routeReminderSkill = 125,
          skillCap = 225,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1681,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1701,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3001,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3137,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3175,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3357,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3555,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4254,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4598,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5392,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5513,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6297,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "mining",
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 200,
          routeReminderSkill = 200,
          skillCap = 300,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1681,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1701,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3001,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 3137,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3175,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3357,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3555,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4254,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 4598,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5392,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 5513,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6297,
            },
          },
        },
      },
      skinning = {
        {
          conditions = _E,
          method = "trainer",
          profession = "skinning",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1292,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6287,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6288,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6289,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6290,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6291,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6292,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6295,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6306,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6387,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7087,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7088,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7089,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 8144,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 12030,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 247227,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257003,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257024,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 267324,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 267327,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 267330,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 267333,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 267336,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "skinning",
          rankIndex = 2,
          rankKey = "journeyman",
          reqLevel = 10,
          reqSkill = 50,
          routeReminderSkill = 50,
          skillCap = 150,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1292,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6287,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6288,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6289,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6290,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6291,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6292,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6295,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6306,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6387,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7087,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7088,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7089,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 8144,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 12030,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257003,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257024,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "skinning",
          rankIndex = 3,
          rankKey = "expert",
          reqLevel = 20,
          reqSkill = 125,
          routeReminderSkill = 125,
          skillCap = 225,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1292,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6287,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6288,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6289,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6290,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6291,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6292,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6295,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6306,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6387,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7087,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7088,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7089,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 8144,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 12030,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257003,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257024,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "skinning",
          rankIndex = 4,
          rankKey = "artisan",
          reqLevel = 35,
          reqSkill = 200,
          routeReminderSkill = 200,
          skillCap = 300,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1292,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6287,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6288,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6289,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6290,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6291,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6292,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6295,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 6306,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 6387,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7087,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7088,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 7089,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 8144,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 12030,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257003,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 257024,
            },
          },
        },
      },
      tailoring = {
        {
          conditions = _E,
          method = "trainer",
          profession = "tailoring",
          rankIndex = 1,
          rankKey = "apprentice",
          skillCap = 75,
          trainers = {
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1103,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1300,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 1703,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 2855,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3484,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 3523,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 4193,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11048,
            },
            {
              conditions = {
                { kind = "faction", side = "A" },
              },
              npcID = 11050,
            },
            {
              conditions = {
                { kind = "faction", side = "H" },
              },
              npcID = 11051,
            },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "tailoring",
          rankIndex = 2,
          rankKey = "journeyman",
          skillCap = 150,
          trainers = {
            { npcID = 1103 },
            { npcID = 1703 },
            { npcID = 1300 },
            { npcID = 3523 },
            { npcID = 11048 },
            { npcID = 4193 },
            { npcID = 11050 },
            { npcID = 2855 },
            { npcID = 3484 },
            { npcID = 11051 },
            { npcID = 252380 },
            { npcID = 251991 },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "tailoring",
          rankIndex = 3,
          rankKey = "expert",
          skillCap = 225,
          trainers = {
            { npcID = 251972 },
            { npcID = 5153 },
            { npcID = 5567 },
            { npcID = 2627 },
            { npcID = 11049 },
            { npcID = 4159 },
            { npcID = 3363 },
            { npcID = 3704 },
            { npcID = 3004 },
          },
        },
        {
          conditions = _E,
          method = "trainer",
          profession = "tailoring",
          rankIndex = 4,
          rankKey = "artisan",
          skillCap = 300,
          trainers = {
            { npcID = 4576 },
            { npcID = 1346 },
          },
        },
      },
    },
    specializations = {
      [9787] = {
        abilitySpellID = 9787,
        exclusiveGroup = "blacksmithing",
        minLevel = 40,
        minSkill = 200,
        profession = "blacksmithing",
        specKey = "weaponsmith",
        variants = _E,
      },
      [9788] = {
        abilitySpellID = 9788,
        exclusiveGroup = "blacksmithing",
        minLevel = 40,
        minSkill = 200,
        profession = "blacksmithing",
        specKey = "armorsmith",
        variants = _E,
      },
      [10656] = {
        abilitySpellID = 10656,
        exclusiveGroup = "leatherworking",
        minLevel = 40,
        minSkill = 225,
        profession = "leatherworking",
        specKey = "dragonscale",
        variants = _E,
      },
      [10658] = {
        abilitySpellID = 10658,
        exclusiveGroup = "leatherworking",
        minLevel = 40,
        minSkill = 225,
        profession = "leatherworking",
        specKey = "elemental",
        variants = _E,
      },
      [10660] = {
        abilitySpellID = 10660,
        exclusiveGroup = "leatherworking",
        minLevel = 40,
        minSkill = 225,
        profession = "leatherworking",
        specKey = "tribal",
        variants = _E,
      },
      [17039] = {
        abilitySpellID = 17039,
        exclusiveGroup = "blacksmithing_weaponsmith",
        minLevel = 40,
        minSkill = 200,
        profession = "blacksmithing",
        specKey = "master_swordsmith",
        variants = _E,
      },
      [17040] = {
        abilitySpellID = 17040,
        exclusiveGroup = "blacksmithing_weaponsmith",
        minLevel = 40,
        minSkill = 200,
        profession = "blacksmithing",
        specKey = "master_hammersmith",
        variants = _E,
      },
      [17041] = {
        abilitySpellID = 17041,
        exclusiveGroup = "blacksmithing_weaponsmith",
        minLevel = 40,
        minSkill = 200,
        profession = "blacksmithing",
        specKey = "master_axesmith",
        variants = _E,
      },
      [20219] = {
        abilitySpellID = 20219,
        exclusiveGroup = "engineering",
        minLevel = 30,
        minSkill = 200,
        profession = "engineering",
        specKey = "gnomish",
        variants = {
          N = {
            prereqQuestGroups = _E,
            questID = 3647,
            turnInItems = {
              { count = 1, itemID = 11423 },
            },
          },
        },
      },
      [20222] = {
        abilitySpellID = 20222,
        exclusiveGroup = "engineering",
        minLevel = 30,
        minSkill = 200,
        profession = "engineering",
        specKey = "goblin",
        variants = {
          N = {
            prereqQuestGroups = _E,
            questID = 3644,
            turnInItems = {
              { count = 1, itemID = 11422 },
            },
          },
        },
      },
    },
    tools = {
      [2901] = {
        bindOnPickup = false,
        itemID = 2901,
        minSkill = 1,
        profession = "mining",
        tier = 2,
        toolCategory = "mining_pick",
      },
      [5956] = {
        bindOnPickup = false,
        itemID = 5956,
        minSkill = 1,
        profession = "blacksmithing",
        tier = 1,
        toolCategory = "blacksmith_hammer",
      },
      [6206] = {
        bindOnPickup = false,
        itemID = 6206,
        minSkill = 1,
        profession = "mining",
        tier = 3,
        toolCategory = "mining_pick",
      },
      [6218] = {
        bindOnPickup = true,
        craftSpellID = 7421,
        itemID = 6218,
        minSkill = 1,
        profession = "enchanting",
        tier = 1,
        toolCategory = "runed_rod",
      },
      [6219] = {
        bindOnPickup = false,
        craftSpellID = 7430,
        itemID = 6219,
        minSkill = 50,
        profession = "engineering",
        tier = 2,
        toolCategory = "arclight_spanner",
      },
      [6339] = {
        bindOnPickup = true,
        craftSpellID = 7795,
        itemID = 6339,
        minSkill = 1,
        profession = "enchanting",
        tier = 2,
        toolCategory = "runed_rod",
      },
      [7005] = {
        bindOnPickup = false,
        itemID = 7005,
        minSkill = 1,
        profession = "skinning",
        tier = 1,
        toolCategory = "skinning_knife",
      },
      [9149] = {
        bindOnPickup = true,
        craftSpellID = 11459,
        itemID = 9149,
        minSkill = 1,
        profession = "alchemy",
        tier = 1,
        toolCategory = "philosophers_stone",
      },
      [10498] = {
        bindOnPickup = false,
        craftSpellID = 12590,
        itemID = 10498,
        minSkill = 1,
        profession = "engineering",
        tier = 1,
        toolCategory = "gyromatic_micro_adjustor",
      },
      [11130] = {
        bindOnPickup = true,
        craftSpellID = 13628,
        itemID = 11130,
        minSkill = 1,
        profession = "enchanting",
        tier = 3,
        toolCategory = "runed_rod",
      },
      [11145] = {
        bindOnPickup = true,
        craftSpellID = 13702,
        itemID = 11145,
        minSkill = 1,
        profession = "enchanting",
        tier = 4,
        toolCategory = "runed_rod",
      },
      [12709] = {
        bindOnPickup = true,
        itemID = 12709,
        minSkill = 1,
        profession = "skinning",
        tier = 4,
        toolCategory = "skinning_knife",
      },
      [13503] = {
        bindOnPickup = true,
        craftSpellID = 17632,
        itemID = 13503,
        minSkill = 275,
        profession = "alchemy",
        tier = 2,
        toolCategory = "philosophers_stone",
      },
      [16207] = {
        bindOnPickup = true,
        craftSpellID = 20051,
        itemID = 16207,
        minSkill = 1,
        profession = "enchanting",
        tier = 5,
        toolCategory = "runed_rod",
      },
      [259229] = {
        bindOnPickup = false,
        itemID = 259229,
        minSkill = 1,
        profession = "mining",
        tier = 1,
        toolCategory = "mining_pick",
      },
      [260811] = {
        bindOnPickup = false,
        craftSpellID = 1266924,
        itemID = 260811,
        minSkill = 1,
        profession = "engineering",
        tier = 1,
        toolCategory = "gnomish_army_knife",
      },
      [269716] = {
        bindOnPickup = true,
        itemID = 269716,
        minSkill = 1,
        profession = "skinning",
        tier = 2,
        toolCategory = "skinning_knife",
      },
      [281665] = {
        bindOnPickup = true,
        itemID = 281665,
        minSkill = 1,
        profession = "blacksmithing",
        tier = 2,
        toolCategory = "blacksmith_hammer",
      },
      [282550] = {
        bindOnPickup = false,
        itemID = 282550,
        minSkill = 1,
        profession = "engineering",
        tier = 1,
        toolCategory = "arclight_spanner",
      },
      [285280] = {
        bindOnPickup = true,
        craftSpellID = 1317963,
        itemID = 285280,
        minSkill = 195,
        profession = "blacksmithing",
        tier = 3,
        toolCategory = "blacksmith_hammer",
      },
      [285281] = {
        bindOnPickup = true,
        craftSpellID = 1317964,
        itemID = 285281,
        minSkill = 270,
        profession = "blacksmithing",
        tier = 4,
        toolCategory = "blacksmith_hammer",
      },
      [287069] = {
        bindOnPickup = true,
        itemID = 287069,
        minSkill = 1,
        profession = "skinning",
        tier = 3,
        toolCategory = "skinning_knife",
      },
    },
  }
end
