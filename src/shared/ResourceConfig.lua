local ResourceConfig = {}

ResourceConfig.Types = {
	['PinkAlgae'] = {
		Name = 'Pink Algae',
		Color = Color3.fromRGB(255, 105, 180), -- Pink
		BaseValue = 1,
		Description = 'Common pink algae.',
	},
	['OrangeAlgae'] = {
		Name = 'Orange Algae',
		Color = Color3.fromRGB(255, 165, 0), -- Orange
		BaseValue = 1,
		Description = 'Bright orange algae.',
	},
	['GreenAlgae'] = {
		Name = 'Green Algae',
		Color = Color3.fromRGB(50, 205, 50), -- Green
		BaseValue = 1,
		Description = 'Nutrient-rich green algae.',
	},
	['MysticAlgae'] = {
		Name = 'Mystic Algae',
		Color = Color3.fromRGB(190,190,190), -- Purple
		BaseValue = 1,
		Description = 'A rare, glowing mystical algae.',
	},
}

ResourceConfig.Fields = {
	["Freshwater Reef"] = { -- Folder Name in Workspace
		Name = "Freshwater Reef",
		RegenDelay = 5,
		RegenInterval = 0.5,
		FishRequired = 0,
	},
	["Coral Reef"] = { -- Folder Name in Workspace
		Name = "Coral Reef",
		RegenDelay = 5,
		RegenInterval = 0.5,
		FishRequired = 0,
	},
	["Trash Reef"] = { -- Folder Name in Workspace
		Name = "Trash Reef",
		RegenDelay = 5,
		RegenInterval = 0.5,
		FishRequired = 0,
	},
	["Sun Reef"] = { -- Folder Name in Workspace
		Name = "Sun Reef",
		RegenDelay = 2,
		RegenInterval = 0.1,
		FishRequired = 0,
	},
	["Runic Reef"] = { -- Folder Name in Workspace
		Name = "Runic Reef",
		RegenDelay = 5,
		RegenInterval = 0.5,
		FishRequired = 5,
	},
	["Obsidian Reef"] = { -- Folder Name in Workspace
		Name = "Obsidian Reef",
		RegenDelay = 3,
		RegenInterval = 0.2,
		FishRequired = 10,
	},
	["Crystal Reef"] = { -- Folder Name in Workspace
		Name = "Crystal Reef",
		RegenDelay = 5,
		RegenInterval = 0.5,
		FishRequired = 10,
	},
	["Coralline Reef"] = { -- Folder Name in Workspace
		Name = "Coralline Reef",
		RegenDelay = 5,
		RegenInterval = 0.5,
		FishRequired = 5,
	},
	["Ghastly Reef"] = { -- Folder Name in Workspace
		Name = "Ghastly Reef",
		RegenDelay = 5,
		RegenInterval = 0.5,
		FishRequired = 10,
	},
	["Heavensent Reef"] = { -- Folder Name in Workspace
		Name = "Heavensent Reef",
		RegenDelay = 2,
		RegenInterval = 0.2,
		FishRequired = 15,
	},
	["Ancient Reef"] = { -- Folder Name in Workspace
		Name = "Ancient Reef",
		RegenDelay = 5,
		RegenInterval = 0.5,
		FishRequired = 15,
	},
	["Warrior's Reef"] = { -- Folder Name in Workspace
		Name = "Warrior's Reef",
		RegenDelay = 5,
		RegenInterval = 0.5,
		FishRequired = 15,
	},
}

ResourceConfig.Fields["Warrior’s Reef"] = ResourceConfig.Fields["Warrior's Reef"]

return ResourceConfig
