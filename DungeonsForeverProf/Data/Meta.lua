local _, ns = ...
if type(ns) ~= "table" then ns = _G.DF_NS or {} end

ns.Data = ns.Data or {}
local Data = ns.Data
Data._loaders = Data._loaders or {}
Data._recipeLoaders = Data._recipeLoaders or {}
Data.recipes = Data.recipes or {}
Data.locales = Data.locales or {}

local _roMt = {
  __newindex = function() error("DungeonsForeverProf: static data table is read-only", 2) end,
  __metatable = false,
}
local _empty = setmetatable({}, _roMt)
Data._empty = _empty

local function _freeze(tbl, seen)
  if type(tbl) ~= "table" or tbl == _empty then return tbl end
  seen = seen or {}
  if seen[tbl] then return tbl end
  seen[tbl] = true
  for _, v in pairs(tbl) do
    if type(v) == "table" and v ~= _empty then _freeze(v, seen) end
  end
  return setmetatable(tbl, _roMt)
end
Data._freeze = _freeze

Data.meta = _freeze({ branch = "forever", contractVersion = 1, fingerprint = "sha256:ba3b0a452353f80b1a90f705573da65c83cd827849ce908cb351b3e0b4b42d3b", foreverBuild = "1.60.1.71091" })

Data.professions = _freeze({
  alchemy = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 1 },
      { icon = "inv_misc_dust_02", key = "reagents", order = 10 },
      { icon = "inv_potion_54", key = "recovery_potions", order = 20 },
      { icon = "inv_potion_54", key = "potions", order = 25 },
      { icon = "inv_potion_32", key = "elixirs", order = 30 },
      { icon = "inv_potion_62", key = "flasks", order = 40 },
      { icon = "inv_potion_101", key = "weapon_oils", order = 50 },
      { icon = "inv_potion_76", key = "draughts", order = 55 },
      { icon = "inv_misc_stonetablet_05", key = "lesser_transmutations", order = 60 },
      { icon = "inv_misc_stonetablet_05", key = "greater_transmutations", order = 65 },
      { icon = "inv_misc_bag_08", key = "miscellaneous", order = 70 },
      { icon = "inv_misc_coin_16", key = "favor_exchange", order = 900 },
    },
    icon = 136240,
    kind = "primary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110292" },
    racialKeys = {},
    slug = "alchemy",
  },
  blacksmithing = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 1 },
      { icon = "inv_misc_dust_02", key = "reagents", order = 10 },
      { icon = "inv_stone_sharpeningstone_02", key = "weapon_stones", order = 20 },
      { icon = "inv_helmet_24", key = "plate_helmets", order = 30 },
      { icon = "inv_shoulder_02", key = "plate_pauldrons", order = 40 },
      { icon = "inv_chest_plate04", key = "plate_chestguards", order = 50 },
      { icon = "inv_bracer_07", key = "plate_bracers", order = 60 },
      { icon = "inv_gauntlets_04", key = "plate_gauntlets", order = 70 },
      { icon = "inv_belt_03", key = "plate_belts", order = 80 },
      { icon = "inv_pants_04", key = "plate_legguards", order = 90 },
      { icon = "inv_boots_05", key = "plate_boots", order = 100 },
      { icon = "inv_helmet_03", key = "mail_helmets", order = 110 },
      { icon = "inv_shoulder_01", key = "mail_pauldrons", order = 120 },
      { icon = "inv_chest_chain_05", key = "mail_chestguards", order = 130 },
      { icon = "inv_bracer_03", key = "mail_bracers", order = 140 },
      { icon = "inv_gauntlets_05", key = "mail_gauntlets", order = 150 },
      { icon = "inv_belt_02", key = "mail_belts", order = 160 },
      { icon = "inv_pants_03", key = "mail_legguards", order = 170 },
      { icon = "inv_boots_01", key = "mail_boots", order = 180 },
      { icon = "inv_axe_09", key = "two_handed_axes", order = 190 },
      { icon = "inv_hammer_05", key = "two_handed_maces", order = 200 },
      { icon = "inv_spear_06", key = "polearms", order = 210 },
      { icon = "inv_sword_25", key = "two_handed_swords", order = 220 },
      { icon = "inv_axe_06", key = "one_handed_axes", order = 230 },
      { icon = "inv_weapon_shortblade_05", key = "daggers", order = 240 },
      { icon = "inv_gauntlets_04", key = "fist_weapons", order = 250 },
      { icon = "inv_mace_01", key = "one_handed_maces", order = 260 },
      { icon = "inv_sword_04", key = "one_handed_swords", order = 270 },
      { icon = "inv_shield_04", key = "shields", order = 280 },
      { icon = "inv_throwingknife_01", key = "thrown", order = 285 },
      { icon = "inv_misc_bag_08", key = "miscellaneous", order = 290 },
      { icon = "inv_rod_enchanted", key = "inert_enchanting_rods", order = 300 },
      { icon = "inv_misc_coin_16", key = "favor_exchange", order = 900 },
    },
    icon = 136241,
    kind = "primary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110292" },
    racialKeys = {},
    slug = "blacksmithing",
  },
  camping = { categories = {}, icon = 135805, kind = "system", maxSkillCap = 300, perkKeys = {}, racialKeys = {}, slug = "camping" },
  comprehension = {
    categories = {
      { icon = "", key = "tier_1", order = 900 },
      { icon = "", key = "tier_15", order = 900 },
      { icon = "", key = "tier_175", order = 900 },
      { icon = "", key = "tier_50", order = 900 },
    },
    icon = 135933,
    kind = "system",
    maxSkillCap = 300,
    perkKeys = {},
    racialKeys = {},
    slug = "comprehension",
  },
  cooking = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 1 },
      { icon = "inv_misc_food_11", key = "everyday_meals", order = 10 },
      { icon = "inv_misc_food_15", key = "stamina_food", order = 15 },
      { icon = "inv_misc_food_14", key = "strength_food", order = 20 },
      { icon = "inv_misc_food_16", key = "agility_food", order = 30 },
      { icon = "inv_misc_food_63", key = "intellect_food", order = 40 },
      { icon = "inv_misc_food_64", key = "spell_damage_food", order = 50 },
      { icon = "inv_misc_food_13", key = "attack_power_food", order = 60 },
      { icon = "inv_misc_food_13", key = "combat_prowess_food", order = 70 },
      { icon = "inv_misc_food_14", key = "armor_food", order = 80 },
      { icon = "inv_misc_fish_02", key = "fishermans_delights", order = 88 },
      { icon = "inv_drink_05", key = "delightful_drinks", order = 90 },
      { icon = "inv_drink_07", key = "soothing_drinks", order = 100 },
      { icon = "inv_misc_food_12", key = "miscellaneous_cuisines", order = 200 },
      { icon = "inv_misc_food_62", key = "winter_veil_treats", order = 300 },
      { icon = "inv_misc_coin_16", key = "favor_exchange", order = 900 },
    },
    icon = 133971,
    kind = "secondary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110289" },
    racialKeys = {},
    slug = "cooking",
  },
  enchanting = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 1 },
      { icon = "inv_misc_dust_02", key = "reagents", order = 10 },
      { icon = "inv_staff_goldfeathered_01", key = "runed_enchanting_rods", order = 20 },
      { icon = "inv_potion_105", key = "wizard_oils", order = 30 },
      { icon = "inv_chest_cloth_21", key = "chest_enchants", order = 60 },
      { icon = "inv_bracer_07", key = "bracer_enchants", order = 70 },
      { icon = "inv_gauntlets_04", key = "glove_enchants", order = 80 },
      { icon = "inv_boots_05", key = "boots_enchants", order = 110 },
      { icon = "inv_axe_09", key = "two_handed_weapon_enchants", order = 120 },
      { icon = "inv_sword_04", key = "weapon_enchants", order = 130 },
      { icon = "inv_shield_04", key = "shield_enchants", order = 140 },
      { icon = "inv_misc_orb_01", key = "off_hand_enchants", order = 150 },
      { icon = "inv_jewelry_necklace_07", key = "amulet_enchants", order = 160 },
      { icon = "inv_misc_cape_02", key = "cloak_enchants", order = 170 },
      { icon = "inv_relics_idolofhealth", key = "relics", order = 200 },
      { icon = "inv_misc_gem_01", key = "curios", order = 210 },
      { icon = "inv_staff_13", key = "staves", order = 220 },
      { icon = "inv_wand_01", key = "wands", order = 230 },
      { icon = "inv_misc_book_09", key = "off_hands", order = 240 },
      { icon = "inv_misc_coin_16", key = "favor_exchange", order = 900 },
    },
    icon = 136244,
    kind = "primary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110292" },
    racialKeys = {},
    slug = "enchanting",
  },
  engineering = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 1 },
      { icon = "inv_misc_gear_01", key = "parts", order = 10 },
      { icon = "inv_misc_bomb_02", key = "explosives", order = 20 },
      { icon = "inv_misc_missilelarge_red", key = "fireworks", order = 30 },
      { icon = "inv_gizmo_06", key = "consumable_devices", order = 40 },
      { icon = "inv_gizmo_01", key = "devices", order = 50 },
      { icon = "inv_gizmo_02", key = "gadgets", order = 60 },
      { icon = "inv_misc_bomb_04", key = "pets_and_guardians", order = 70 },
      { icon = "inv_helmet_47", key = "cloth_headgear", order = 80 },
      { icon = "inv_helmet_47", key = "leather_headgear", order = 90 },
      { icon = "inv_helmet_47", key = "mail_headgear", order = 100 },
      { icon = "inv_helmet_47", key = "plate_headgear", order = 110 },
      { icon = "inv_weapon_rifle_01", key = "ranged_weapons", order = 120 },
      { icon = "inv_misc_spyglass_02", key = "scopes", order = 130 },
      { icon = "inv_ammo_bullet_02", key = "ammunition", order = 140 },
      { icon = "inv_misc_coin_16", key = "favor_exchange", order = 900 },
    },
    icon = 136243,
    kind = "primary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110292" },
    racialKeys = {},
    slug = "engineering",
  },
  ["first-aid"] = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 1 },
      { icon = "inv_misc_bandage_12", key = "bandages", order = 10 },
      { icon = "inv_misc_slime_01", key = "curatives", order = 10 },
      { icon = "inv_potion_54", key = "healing_potions", order = 10 },
    },
    icon = 135966,
    kind = "secondary",
    maxSkillCap = 300,
    perkKeys = {},
    racialKeys = {},
    slug = "first-aid",
  },
  fishing = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 900 },
    },
    icon = 136245,
    kind = "secondary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110293" },
    racialKeys = {},
    slug = "fishing",
  },
  herbalism = {
    categories = {
      { icon = "", key = "herbalism", order = 0 },
      { icon = "spell_fire_fire", key = "camping", order = 1 },
    },
    icon = 136246,
    kind = "primary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110291" },
    racialKeys = {},
    slug = "herbalism",
  },
  leatherworking = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 1 },
      { icon = "inv_misc_dust_02", key = "reagents", order = 100 },
      { icon = "inv_misc_bag_10", key = "bags", order = 200 },
      { icon = "inv_misc_cape_02", key = "cloaks", order = 300 },
      { icon = "inv_helmet_15", key = "leather_helmets", order = 400 },
      { icon = "inv_shoulder_07", key = "leather_pauldrons", order = 500 },
      { icon = "inv_chest_leather_05", key = "leather_chestguards", order = 600 },
      { icon = "inv_bracer_06", key = "leather_bracers", order = 700 },
      { icon = "inv_gauntlets_05", key = "leather_gauntlets", order = 800 },
      { icon = "inv_misc_coin_16", key = "favor_exchange", order = 900 },
      { icon = "inv_belt_04", key = "leather_belts", order = 900 },
      { icon = "inv_pants_02", key = "leather_legguards", order = 1000 },
      { icon = "inv_boots_05", key = "leather_boots", order = 1100 },
      { icon = "inv_helmet_03", key = "mail_helmets", order = 1200 },
      { icon = "inv_shoulder_01", key = "mail_pauldrons", order = 1300 },
      { icon = "inv_chest_chain_05", key = "mail_chestguards", order = 1400 },
      { icon = "inv_bracer_03", key = "mail_bracers", order = 1500 },
      { icon = "inv_gauntlets_05", key = "mail_gauntlets", order = 1600 },
      { icon = "inv_belt_02", key = "mail_belts", order = 1700 },
      { icon = "inv_pants_03", key = "mail_legguards", order = 1800 },
      { icon = "inv_boots_01", key = "mail_boots", order = 1900 },
      { icon = "inv_misc_armorkit_17", key = "armor_kits", order = 2000 },
      { icon = "inv_misc_quiver_03", key = "quivers", order = 2100 },
      { icon = "inv_misc_bag_09", key = "ammo_pouches", order = 2200 },
      { icon = "inv_misc_bag_08", key = "miscellaneous", order = 2450 },
    },
    icon = 136247,
    kind = "primary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110292" },
    racialKeys = {},
    slug = "leatherworking",
  },
  mining = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 1 },
      { icon = "inv_ingot_02", key = "smelted_bars", order = 100 },
    },
    icon = 136248,
    kind = "primary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110291" },
    racialKeys = {},
    slug = "mining",
  },
  poisons = {
    categories = {
      { icon = "ability_poisons", key = "poisons", order = 0 },
    },
    icon = 136242,
    kind = "system",
    maxSkillCap = 300,
    perkKeys = {},
    racialKeys = {},
    slug = "poisons",
  },
  skinning = {
    categories = {
      { icon = "", key = "skinning", order = 0 },
      { icon = "spell_fire_fire", key = "camping", order = 1 },
    },
    icon = 134366,
    kind = "primary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110291" },
    racialKeys = {},
    slug = "skinning",
  },
  tailoring = {
    categories = {
      { icon = "spell_fire_fire", key = "camping", order = 1 },
      { icon = "inv_misc_dust_02", key = "reagents", order = 100 },
      { icon = "inv_misc_bag_10", key = "bags", order = 300 },
      { icon = "inv_misc_bag_17", key = "specialty_bags", order = 400 },
      { icon = "inv_misc_cape_02", key = "cloaks", order = 500 },
      { icon = "inv_helmet_31", key = "hoods", order = 600 },
      { icon = "inv_shoulder_09", key = "spaulders", order = 700 },
      { icon = "inv_chest_cloth_21", key = "robes_and_vests", order = 800 },
      { icon = "inv_bracer_09", key = "bracers", order = 900 },
      { icon = "inv_misc_coin_16", key = "favor_exchange", order = 900 },
      { icon = "inv_gauntlets_18", key = "gloves", order = 1000 },
      { icon = "inv_belt_06", key = "belts", order = 1100 },
      { icon = "inv_pants_01", key = "leggings", order = 1200 },
      { icon = "inv_boots_09", key = "shoes", order = 1300 },
      { icon = "inv_shirt_01", key = "shirts", order = 1400 },
      { icon = "inv_chest_cloth_17", key = "dressed_for_the_occasion", order = 1500 },
      { icon = "inv_misc_bag_08", key = "miscellaneous", order = 1550 },
    },
    icon = 136249,
    kind = "primary",
    maxSkillCap = 300,
    perkKeys = { "legacy_node_110292" },
    racialKeys = {},
    slug = "tailoring",
  },
})

Data.skillLines = _freeze({
  [40] = { isPrimarySlot = false, profession = "poisons", skillLineID = 40, track = "forever" },
  [129] = { isPrimarySlot = false, profession = "first-aid", skillLineID = 129, track = "forever" },
  [164] = { isPrimarySlot = true, profession = "blacksmithing", skillLineID = 164, track = "forever" },
  [165] = { isPrimarySlot = true, profession = "leatherworking", skillLineID = 165, track = "forever" },
  [171] = { isPrimarySlot = true, profession = "alchemy", skillLineID = 171, track = "forever" },
  [182] = { isPrimarySlot = true, profession = "herbalism", skillLineID = 182, track = "forever" },
  [185] = { isPrimarySlot = false, profession = "cooking", skillLineID = 185, track = "forever" },
  [186] = { isPrimarySlot = true, profession = "mining", skillLineID = 186, track = "forever" },
  [197] = { isPrimarySlot = true, profession = "tailoring", skillLineID = 197, track = "forever" },
  [202] = { isPrimarySlot = true, profession = "engineering", skillLineID = 202, track = "forever" },
  [333] = { isPrimarySlot = true, profession = "enchanting", skillLineID = 333, track = "forever" },
  [356] = { isPrimarySlot = false, profession = "fishing", skillLineID = 356, track = "forever" },
  [393] = { isPrimarySlot = true, profession = "skinning", skillLineID = 393, track = "forever" },
  [2937] = { isPrimarySlot = true, profession = "alchemy", skillLineID = 2937, track = "forever" },
  [2938] = { isPrimarySlot = true, profession = "blacksmithing", skillLineID = 2938, track = "forever" },
  [2939] = { isPrimarySlot = false, profession = "cooking", skillLineID = 2939, track = "forever" },
  [2940] = { isPrimarySlot = true, profession = "enchanting", skillLineID = 2940, track = "forever" },
  [2941] = { isPrimarySlot = true, profession = "engineering", skillLineID = 2941, track = "forever" },
  [2942] = { isPrimarySlot = false, profession = "first-aid", skillLineID = 2942, track = "forever" },
  [2944] = { isPrimarySlot = true, profession = "herbalism", skillLineID = 2944, track = "forever" },
  [2945] = { isPrimarySlot = true, profession = "leatherworking", skillLineID = 2945, track = "forever" },
  [2946] = { isPrimarySlot = true, profession = "mining", skillLineID = 2946, track = "forever" },
  [2947] = { isPrimarySlot = true, profession = "skinning", skillLineID = 2947, track = "forever" },
  [2948] = { isPrimarySlot = true, profession = "tailoring", skillLineID = 2948, track = "forever" },
  [3012] = { isPrimarySlot = false, profession = "comprehension", skillLineID = 3012, track = "forever" },
})

function Data.Ensure(domain)
  if type(domain) ~= "string" then error("Ensure(domain): string expected", 2) end
  local existing = Data[domain]
  if type(existing) == "table" then return existing end
  local loader = Data._loaders[domain]
  if type(loader) ~= "function" then error("Ensure(domain): unknown domain " .. domain, 2) end
  local loaded = loader()
  Data._loaders[domain] = nil
  Data[domain] = _freeze(loaded)
  return Data[domain]
end
ns.Ensure = Data.Ensure

function Data.EnsureRecipes(slug)
  if type(slug) ~= "string" then error("EnsureRecipes(slug): string expected", 2) end
  local existing = Data.recipes[slug]
  if type(existing) == "table" then return existing end
  local loader = Data._recipeLoaders[slug]
  if type(loader) ~= "function" then error("EnsureRecipes(slug): unknown profession " .. slug, 2) end
  local loaded = loader()
  Data._recipeLoaders[slug] = nil
  Data.recipes[slug] = _freeze(loaded)
  return Data.recipes[slug]
end
ns.EnsureRecipes = Data.EnsureRecipes
