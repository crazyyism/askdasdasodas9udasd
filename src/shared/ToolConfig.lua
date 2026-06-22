local ToolConfig = {
	["Fishing Net"] = {
		DisplayName = "Fishing Net",
		CapacityBurn = 2,   -- was 2
		Cooldown = 1.1,     -- was 1.25 | Dense DPS: 5.5
		-- {0,0} is the target block. {1,0} is right, {0,1} is forward, etc.
		Pattern = {
			{0, 0}, -- Center (block player is targeting)
			{0, 1}, -- Forward neighbor (block in front of center)
		},
	},
	["Scissors"] = {
		DisplayName = "Scissors",
		CapacityBurn = 6,   -- was 4
		Cooldown = 0.5,    -- was 1.0 | Dense DPS: 8.0
		Pattern = {
			{0, 1}, 
		},
	},
	["Shovel"] = {
		DisplayName = "Shovel",
		CapacityBurn = 5,   -- was 4
		Cooldown = 0.7,     -- was 0.8 | Dense DPS: 21.4
		Pattern = {
			{0, 0},
			{0, 1},
			{0, 2}
		},
	},
	["FishingHook"] = {
		DisplayName = "Fishing Hook",
		CapacityBurn = 14,  -- was 12
		Cooldown = 0.4,     -- unchanged | Dense DPS: 35.0
		Pattern = {
			{0, 1}, 
		},
	},
	["MegaNet"] = {
		DisplayName = "Mega Net",
		CapacityBurn = 10,   -- was 6
		Cooldown = 0.8,     -- was 0.9 | Dense DPS: 61.3
		Pattern = {
			{0, 1},
			{0, 2}, 
			{0, 3}, 
			{0, 4}, 
			{0, 5}, 
			{0, 6}, 
			{0, 7}
		},
	},
	["Rainmaker"] = {
		DisplayName = "Rainmaker",
		CapacityBurn = 15,
		Cooldown = 0.04,
		HarvestRadius = 25,
		HasAbility = true,
		Pattern = {
			{0, 0},
		},
	},
	["SharkScythe"] = {
		DisplayName = "Shark Scythe",
		CapacityBurn = 6,
		Cooldown = 1.5,
		HarvestRadius = 14,
		Pattern = {}, -- Ignored due to HarvestRadius
	},

	["Poseidon"] = {
		DisplayName = "Poseidon",
		CapacityBurn = 4,
		Cooldown = .6,
		Pattern = {
			{0, 0}, {0, 1}, {0, 2}, {0,3}, {1,0}, {-1,0}, {2,0}, {-2,0}, {-2,1}, {2,1}, {2,2}, {-2,2}, {2,3}, {-2,3}
		},
	},
	["Sunkissed Art"] = {
		DisplayName = "Sunkissed Art",
		HasAbility = true,
		CapacityBurn = 10,
		Cooldown = .1,
		Pattern = {
			{-1,1}, {0,1}, {1,1}, {2,1},
			{-1,2}, {0,2}, {1,2}, {2,2},
			{-1,3}, {0,3}, {1,3}, {2,3},
			{-1,4}, {0,4}, {1,4}, {2,4},
			{-1,5}, {0,5}, {1,5}, {2,5},
			{-1,6}, {0,6}, {1,6}, {2,6},
		},
	},
	["StoneHammer"] = {
		DisplayName = "Stone Hammer",
		CapacityBurn = 5,   -- unchanged
		Cooldown = 1.0,     -- was 1.3 | Dense DPS: 80.0
		-- 4x4 square directly in front of the player
		-- z=1 (one block ahead) to z=4, x=-1 to x=2 (4 wide, roughly centered)
		Pattern = {
			{-1,1}, {0,1}, {1,1}, {2,1},
			{-1,2}, {0,2}, {1,2}, {2,2},
			{-1,3}, {0,3}, {1,3}, {2,3},
			{-1,4}, {0,4}, {1,4}, {2,4},
		},
	},
	["Sun Staff"] = {
		DisplayName = "Sun Staff",
		CapacityBurn = 4,   -- unchanged
		Cooldown = 0.3,     -- was 1.3 | Dense DPS: 80.0
		HarvestRadius = 2,
		Pattern = {},
	},
	["Crystiken"] = {
		DisplayName = "Crystiken",
		CapacityBurn = 1,
		Cooldown = 1,
		ShurikenLifetime = .8,
		ShurikenRange = 13,
		Pattern = {},
	},
	["Eviction"] = {
		DisplayName = "Eviction",
		CapacityBurn = 0,
		Cooldown = 0.5,
		Pattern = {{0,0}}
	},
	["Default"] = {
		DisplayName = "Tool",
		CapacityBurn = 1,
		Cooldown = 1,
		Pattern = {{0,0}}
	}
}

ToolConfig["SunkissedArt"] = ToolConfig["Sunkissed Art"]
ToolConfig["SharkScythe"] = ToolConfig["Shark Scythe"]
ToolConfig["Stone Hammer"] = ToolConfig["StoneHammer"]

return ToolConfig
