local ChanceConfig = {}

-- Sea Mine Rarity Types: Defines the spawn chance weights and stats for different mine rarities
ChanceConfig.SeaMineTypes = {
	["Common"] = {
		Name = "Common Sea Mine",
		Weight = 80,
		BaseCapacity = 25000,
		Color = Color3.fromRGB(50, 205, 50), -- Green
		Material = Enum.Material.Plastic,
		RewardMultiplier = 0.25,
		BiomassRewardMultiplier = 1,
	},
	["Uncommon"] = {
		Name = "Uncommon Sea Mine",
		Weight = 12.5,
		BaseCapacity = 75000,
		Color = Color3.fromRGB(255, 215, 0), -- Gold/Yellow
		Material = Enum.Material.Glass,
		RewardMultiplier = 0.5,
		BiomassRewardMultiplier = 3,
	},
	["Rare"] = {
		Name = "Rare Sea Mine",
		Weight = 5,
		BaseCapacity = 250000,
		Color = Color3.fromRGB(0, 191, 255), -- Deep Sky Blue
		Material = Enum.Material.Glass,
		RewardMultiplier = 0.75,
		BiomassRewardMultiplier = 8,
	},
	["Epic"] = {
		Name = "Epic Sea Mine",
		Weight = 1.5,
		BaseCapacity = 1250000,
		Color = Color3.fromRGB(139, 0, 139), -- Dark Magenta
		Material = Enum.Material.Neon,
		RewardMultiplier = 1,
		BiomassRewardMultiplier = 12,
	},
	["Legendary"] = {
		Name = "Legendary Sea Mine",
		Weight = 0.45,
		BaseCapacity = 5000000,
		Color = Color3.fromRGB(255, 69, 0), -- Orange Red
		Material = Enum.Material.Neon,
		RewardMultiplier = 2,
		BiomassRewardMultiplier = 20,
	},
	["Supreme"] = {
		Name = "Supreme Sea Mine",
		Weight = 0.05,
		BaseCapacity = 25000000,
		Color = Color3.fromRGB(238, 130, 238), -- Violet
		Material = Enum.Material.Neon,
		RewardMultiplier = 5,
		BiomassRewardMultiplier = 100,
	}
}

-- Mob Drops: Defines the items and chances for each mob type
ChanceConfig.MobDrops = {
    ["Frog"] = {
        {Type = "Token", Name = "Biomass", MinAmount = 75, MaxAmount = 200, Chance = 1.0},
        {Type = "Token", Name = "FishFeed", MinAmount = 1, MaxAmount = 10, Chance = 1},
        {Type = "Token", Name = "Zooplankton", MinAmount = 1, MaxAmount = 3, Chance = 0.5},
        {Type = "Token", Name = "Pearl", MinAmount = 1, MaxAmount = 2, Chance = 0.1},
        {Type = "Token", Name = "Green Gem", MinAmount = 1, MaxAmount = 1, Chance = 0.07},
    },
    ["Axolotl"] = {
        {Type = "Token", Name = "Biomass", MinAmount = 75, MaxAmount = 200, Chance = 1.0},
        {Type = "Token", Name = "FishFeed", MinAmount = 1, MaxAmount = 10, Chance = 1},
        {Type = "Token", Name = "Zooplankton", MinAmount = 1, MaxAmount = 3, Chance = 0.5},
        {Type = "Token", Name = "Pearl", MinAmount = 1, MaxAmount = 5, Chance = 0.1},
        {Type = "Token", Name = "Pink Gem", MinAmount = 1, MaxAmount = 2, Chance = 0.125},
    },
    ["King Frog"] = {
        {Type = "Token", Name = "Biomass", MinAmount = 2000, MaxAmount = 5000, Chance = 1.0},
        {Type = "Token", Name = "FishFeed", MinAmount = 50, MaxAmount = 100, Chance = 1.0},
        {Type = "Token", Name = "Pearl", MinAmount = 10, MaxAmount = 20, Chance = 1.0},
        {Type = "Token", Name = "Green Gem", MinAmount = 5, MaxAmount = 10, Chance = 1.0},
        {Type = "Token", Name = "Bronze Egg", MinAmount = 1, MaxAmount = 2, Chance = 0.5},
        {Type = "Token", Name = "Sapphire Egg", MinAmount = 1, MaxAmount = 1, Chance = 0.1},
    },
    ["LavaMonster"] = {
        {Type = "Token", Name = "Biomass", MinAmount = 1500000, MaxAmount = 2750000, Chance = 1.0},
        {Type = "Token", Name = "Sparking Sun", MinAmount = 1, MaxAmount = 1, Chance = 1.0},
        {Type = "Token", Name = "FishFeed", MinAmount = 1000, MaxAmount = 2500, Chance = 1},
        {Type = "Token", Name = "Pearl", MinAmount = 5, MaxAmount = 50, Chance = 1},
        {Type = "Token", Name = "Zooplankton", MinAmount = 25, MaxAmount = 300, Chance = 1},
        {Type = "Token", Name = "Remote Warp", MinAmount = 1, MaxAmount = 4, Chance = 0.5},
        {Type = "Token", Name = "Convertrix", MinAmount = 1, MaxAmount = 4, Chance = 0.25},
        {Type = "Token", Name = "Sea Mine", MinAmount = 1, MaxAmount = 25, Chance = 0.25},
        {Type = "Token", Name = "Orange Gem", MinAmount = 1, MaxAmount = 20, Chance = 1},
        {Type = "Token", Name = "Fertilizer", MinAmount = 1, MaxAmount = 15, Chance = 0.5},
        {Type = "Token", Name = "Ruby Egg", MinAmount = 1, MaxAmount = 1, Chance = 0.075},
    }
}
-- Sea Mine (Token) Drops: Balanced so that every rarity tier has exactly 1000 total weight.
ChanceConfig.SeaMineDrops = {
    ["Common"] = {
        {Item = "Biomass", Chance = 400},
        {Item = "Fish Feed", Chance = 300},
        {Item = "Zooplankton", Chance = 150},
        {Item = "Pearl", Chance = 10},
        {Item = "Sea Mine", Chance = 3},
        {Item = "Fertilizer", Chance = 3},
        {Item = "Green Gem", Chance = 3},
        {Item = "Pink Gem", Chance = 3},
        {Item = "Orange Gem", Chance = 3},
        {Item = "Remote Warp", Chance = 1},
        {Item = "Bronze Egg", Chance = 1}, -- ~5% chance per Common mine
    },
    ["Uncommon"] = {
        {Item = "Biomass", Chance = 350},
        {Item = "Fish Feed", Chance = 250},
        {Item = "Zooplankton", Chance = 150},
        {Item = "Pearl", Chance = 20},
        {Item = "Sea Mine", Chance = 8},
        {Item = "Fertilizer", Chance = 8},
        {Item = "Convertrix", Chance = 8},
        {Item = "Green Gem", Chance = 8},
        {Item = "Pink Gem", Chance = 8},
        {Item = "Orange Gem", Chance = 8},
        {Item = "Remote Warp", Chance = 8},
        {Item = "Bronze Egg", Chance = 4}, -- ~28% chance per Uncommon mine
        {Item = "Sapphire Egg", Chance = 0.3}, -- ~8% chance per Uncommon mine
    },
    ["Rare"] = {
        {Item = "Biomass", Chance = 250},
        {Item = "Fish Feed", Chance = 200},
        {Item = "Zooplankton", Chance = 200},
        {Item = "Pearl", Chance = 40},
        {Item = "Sea Mine", Chance = 40},
        {Item = "Fertilizer", Chance = 30},
        {Item = "Convertrix", Chance = 30},
        {Item = "Green Gem", Chance = 15},
        {Item = "Pink Gem", Chance = 15},
        {Item = "Orange Gem", Chance = 15},
        {Item = "Remote Warp", Chance = 25},
        {Item = "Bronze Egg", Chance = 84}, -- ~1.1 expected per Rare mine
        {Item = "Sapphire Egg", Chance = 1.5}, -- ~18% chance per Rare mine
        {Item = "Ruby Egg", Chance = 0.5}, -- ~6% chance per Rare mine
    },
    ["Epic"] = {
        {Item = "Biomass", Chance = 106},
        {Item = "Fish Feed", Chance = 150},
        {Item = "Zooplankton", Chance = 250},
        {Item = "Pearl", Chance = 200},
        {Item = "Sea Mine", Chance = 100},
        {Item = "Fertilizer", Chance = 40},
        {Item = "Convertrix", Chance = 40},
        {Item = "Green Gem", Chance = 20},
        {Item = "Pink Gem", Chance = 20},
        {Item = "Orange Gem", Chance = 20},
        {Item = "Remote Warp", Chance = 35},
        {Item = "Bronze Egg", Chance = 7}, -- ~1 expected per Epic mine
        {Item = "Sapphire Egg", Chance = 1}, -- ~40% chance per Epic mine
        {Item = "Ruby Egg", Chance = 0.3}, -- ~15% chance per Epic mine
    },
    ["Legendary"] = {
        {Item = "Biomass", Chance = 50},
        {Item = "Fish Feed", Chance = 50},
        {Item = "Zooplankton", Chance = 200},
        {Item = "Pearl", Chance = 240},
        {Item = "Sea Mine", Chance = 150},
        {Item = "Fertilizer", Chance = 60},
        {Item = "Convertrix", Chance = 60},
        {Item = "Green Gem", Chance = 30},
        {Item = "Pink Gem", Chance = 30},
        {Item = "Orange Gem", Chance = 30},
        {Item = "Remote Warp", Chance = 60},
        {Item = "Sapphire Egg", Chance = 6}, -- ~2.3 expected per Legendary mine
        {Item = "Ruby Egg", Chance = 2}, -- ~42% chance per Legendary mine
    },
    ["Supreme"] = {
        {Item = "Biomass", Chance = 10},
        {Item = "Fish Feed", Chance = 10},
        {Item = "Zooplankton", Chance = 100},
        {Item = "Pearl", Chance = 200},
        {Item = "Sea Mine", Chance = 154.5},
        {Item = "Fertilizer", Chance = 100},
        {Item = "Convertrix", Chance = 100},
        {Item = "Green Gem", Chance = 50},
        {Item = "Pink Gem", Chance = 50},
        {Item = "Orange Gem", Chance = 50},
        {Item = "Remote Warp", Chance = 100},
        {Item = "Bronze Egg", Chance = 50}, -- ~5.5 expected per Supreme mine
        {Item = "Sapphire Egg", Chance = 50}, -- ~5.5 expected per Supreme mine
        {Item = "Ruby Egg", Chance = 20}, -- ~2.2 expected per Supreme mine
        {Item = "Heavensent Egg", Chance = 1}, -- Exactly 50% chance per Supreme mine
    }
}

-- Token Spawn Chance (Chance to spawn a token from harvesting algae)
ChanceConfig.TokenSpawnChance = 0.005

-- Wishing Shrine Config
ChanceConfig.WishingShrineRolls = {
	{Amount = 1, Chance = 50},
	{Amount = 2, Chance = 30},
	{Amount = 3, Chance = 15},
	{Amount = 4, Chance = 5},
}

ChanceConfig.WishingShrineDrops = {
	{Item = "Biomass", Chance = 400},
	{Item = "Fish Feed", Chance = 300},
	{Item = "Zooplankton", Chance = 150},
	{Item = "Pearl", Chance = 50},
	{Item = "Green Gem", Chance = 30},
	{Item = "Pink Gem", Chance = 30},
	{Item = "Orange Gem", Chance = 30},
	{Item = "Fertilizer", Chance = 20},
	{Item = "Sea Mine", Chance = 20},
	{Item = "Convertrix", Chance = 10},
	{Item = "Remote Warp", Chance = 10},
	{Item = "Bronze Egg", Chance = 5},
	{Item = "Sapphire Egg", Chance = 2},
	{Item = "Ruby Egg", Chance = 1},
	{Item = "Heavensent Egg", Chance = 0.1},
}

return ChanceConfig
