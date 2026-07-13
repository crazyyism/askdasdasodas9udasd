return {
	-- Starting Fish
	["Basic Fish"] = {
		Name = "Basic Fish",
		ModelName = "Basic Fish",
		Rarity = "Common",
		ColorTrait = "Colorless",
		DecalId = "rbxassetid://105676799503686", -- Placeholder decal
		Description = "A hardworking fish, although the fish has no abilities of his own.",
		BaseStats = {
			GatherSpeed = 2, -- Seconds to gather 1 resource
			GatherAmount = 1, -- Amount collected per gather
			MoveSpeed = 12, -- Studs per second
			ConvertSpeed = 3, -- Seconds per conversion cycle
			ConvertAmount = 250, -- Algae converted per cycle
			Attack = 2,			AttackSpeed = 1.0,
		},
		--Ability = {
		--	Name = "Algae Boost",
		--	Icon = "rbxassetid://110932553731669", -- Replace with actual icon asset ID
		--	EnergyPerHarvest = { Min = 1, Max = 3 }, -- Random energy per harvest
		--	EnergyRequired = 16, -- Energy needed to trigger ability
		--	BoostMultiplier = 1.05, -- 					5% boost per stack
		--	MaxStacks = 10, -- Maximum stacks
		--	Duration = 10, -- Seconds before boost expires
		--	Description = "Boosts algae production by 5% per stack, up to 10 stacks (50% total)."
		--},
	},
	["Clown Fish"] = {
		Name = "Clown Fish",
		ModelName = "Clown Fish",
		Rarity = "Rare",
		ColorTrait = "Orange",
		DecalId = "rbxassetid://86603723013509", -- Placeholder decal
		Description = "Just a general clown fish. He produces orange algae boosts quite frequently though!",
		BaseStats = {
			GatherSpeed = 2.5, -- Seconds to gather 1 resource
			GatherAmount = 3, -- Amount collected per gather
			MoveSpeed = 14, -- Studs per second
			ConvertSpeed = 2, -- Seconds per conversion cycle
			ConvertAmount = 300, -- Algae converted per cycle
			Attack = 3,			AttackSpeed = 1.0,
		},
		AbilityName = "Orange Boost",
	},
	["Crystal Fish"] = {
		Name = "Crystal Fish",
		ModelName = "Crystal Fish",
		Rarity = "Rare",
		ColorTrait = "Pink",
		DecalId = "rbxassetid://104831842920737", -- Placeholder decal
		Description = "Meant to simply grow as a generic crystal, one gained sentience as a fish. Although spiky, hes quite gentle and loves pink!",
		BaseStats = {
			GatherSpeed = 1.5, -- Seconds to gather 1 resource
			GatherAmount = 12, -- Amount collected per gather
			MoveSpeed = 15, -- Studs per second
			ConvertSpeed = 1.5, -- Seconds per conversion cycle
			ConvertAmount = 200, -- Algae converted per cycle
			Attack = 4,			AttackSpeed = 1.0,
		},
		AbilityName = "Pink Boost",
	},
	["Diver Fish"] = {
		Name = "Diver Fish",
		ModelName = "Diver Fish",
		Rarity = "Rare",
		ColorTrait = "Colorless",
		DecalId = "rbxassetid://133217307368571", -- Placeholder decal
		Description = "A fish with a desire to explore the coral reefs. Kinda ironic he has scuba gear even though hes a fish lol",
		BaseStats = {
			GatherSpeed = 4,
			GatherAmount = 2,
			MoveSpeed = 16,
			ConvertSpeed = 1.75,   -- was 2 | CR: 80â†’114/s (fixed: was below Common 83/s)
			ConvertAmount = 200,   -- was 160
			Attack = 3,			AttackSpeed = 1.0,
		},
		AbilityName = "Dive",
	},

	["Blobfish"] = {
		Name = "Blobfish",
		ModelName = "Blobfish",
		Rarity = "Legendary",
		ColorTrait = "Pink",
		DecalId = "rbxassetid://76826327008056", -- Placeholder decal
		Description = "Look at this fattie bruh hes almost like rabbit fish LOL",
		BaseStats = {
			GatherSpeed = 4,
			GatherAmount = 6,
			MoveSpeed = 12,
			ConvertSpeed = 4,
			ConvertAmount = 500,
			Attack = 10,			AttackSpeed = 1.0,
		},
		AbilityName = "Grand Slam",
		Passive = "Bloat",
	},
	["Angler Fish"] = {
		Name = "Angler Fish",
		ModelName = "Angler Fish",
		Rarity = "Rare",
		ColorTrait = "Colorless",
		DecalId = "rbxassetid://87123207653413", -- Placeholder decal
		Description = "A fish with a bioluminescent light in front of his face. Marks algae for extra collection!",
		BaseStats = {
			GatherSpeed = 3,       -- shortened for better GatherRate
			GatherAmount = 3,
			MoveSpeed = 14,
			ConvertSpeed = 2,      -- was 3 | CR: 66.7â†’140/s (fixed: was worst in roster)
			ConvertAmount = 280,   -- was 200
			Attack = 2,			AttackSpeed = 1.0,
		},
		Passive = "Glow",
	},
	["Sun Fish"] = {
		Name = "Sun Fish",
		ModelName = "Sun Fish",
		Rarity = "Epic",
		ColorTrait = "Orange",
		DecalId = "rbxassetid://117297031669619", -- Placeholder decal
		Description = "A Fish that emits the warmth of the sun.",
		BaseStats = {
			GatherSpeed = 2,       -- was 6 | GR: 0.67â†’1.0/s (fixed: was below Rare Angler)
			GatherAmount = 4,
			MoveSpeed = 16,
			ConvertSpeed = 2,
			ConvertAmount = 600,
			Attack = 5,			AttackSpeed = 1.0,
		},
		AbilityName = "Solar Flare",
	},
	["Acoustic Fish"] = {
		Name = "Acoustic Fish",
		ModelName = "Acoustic Fish",
		Rarity = "Epic",
		ColorTrait = "Pink",
		DecalId = "rbxassetid://126736394753403", -- Placeholder decal
		Description = "She plays the euphonium, and is quite anxious of her abilities of music.",
		BaseStats = {
			GatherSpeed = 1,
			GatherAmount = 3,
			MoveSpeed = 30,
			ConvertSpeed = 1,
			ConvertAmount = 700,
			Attack = 3,			AttackSpeed = 1.0,
		},
		AbilityName = "Synesthesia",
	},
	["Ghillie Fish"] = {
		Name = "Ghillie Fish",
		ModelName = "Ghillie Fish",
		Rarity = "Epic",
		ColorTrait = "Green",
		DecalId = "rbxassetid://117123594503538", -- Placeholder decal
		Description = "He likes to pretend hes in some tactical warfare, hiding in the bushes. He kinda looks like that one plant from plants vs zombies.",
		BaseStats = {
			GatherSpeed = 2, -- Seconds to gather 1 resource
			GatherAmount = 4, -- Amount collected per gather
			MoveSpeed = 17, -- Studs per second
			ConvertSpeed = 1.5, -- Seconds per conversion cycle
			ConvertAmount = 160, -- Algae converted per cycle
			Attack = 9,			AttackSpeed = 1.0,
		},
		AbilityName = "Tropical Gust", -- References FishConfig.Abilities
		BuffNames = {"Focus"}, -- References FishConfig.Buffs
	},
	["Obsessed Fish"] = {
		Name = "Obsessed Fish",
		ModelName = "Obsessed Fish",
		Rarity = "Epic",
		ColorTrait = "Pink",
		DecalId = "rbxassetid://123245044460052", -- Placeholder decal
		Description = "A fish with a desire to gather with other fish in her area. Idk bruh she basically colette from brawl stars but a fish now",
		BaseStats = {
			GatherSpeed = 2,
			GatherAmount = 3,
			MoveSpeed = 25,
			ConvertSpeed = 1,
			ConvertAmount = 200,
			Attack = 6,			AttackSpeed = 1.0,
		},
		AbilityName = "Obsession",
		BuffNames = {"PinkAlgaeBoost"},
	},
	["Interstellar Fish"] = {
		Name = "Interstellar Fish",
		ModelName = "Interstellar Fish",
		Rarity = "Epic",
		ColorTrait = "Pink",
		DecalId = "rbxassetid://87229085599061", -- Placeholder decal
		Description = "The interstellar fish knows nothing but to wander the constant void of his life without purpose. He's sluggish and overall lazy, but has the ability to summon singularities.",
		BaseStats = {
			GatherSpeed = 4,
			GatherAmount = 15,
			MoveSpeed = 9,
			ConvertSpeed = 2.5,    -- was 5 | CR: 100â†’300/s (fixed: was below Epic Mirror)
			ConvertAmount = 750,   -- was 500
			Attack = 5,			AttackSpeed = 1.0,
		},
		AbilityName = "Black Hole"
	},
	["Zombie Fish"] = {
		Name = "Zombie Fish",
		ModelName = "Zombie Fish",
		Rarity = "Legendary",
		ColorTrait = "Green",
		DecalId = "rbxassetid://94300830301551", -- Placeholder decal
		Description = "He's an undead one, and a pretty slow one at that, yet devastatingly effective. Uses the power of his infection to spread to algae, boosting production, especially for algae matching his type.",
		BaseStats = {
			GatherSpeed = 2.5,
			GatherAmount = 8,
			MoveSpeed = 15,
			ConvertSpeed = 3,      -- was 5 | CR: 120â†’250/s (fixed: was below several Epics)
			ConvertAmount = 750,   -- was 600
			Attack = 15,			AttackSpeed = 1.0,
		},
		AbilityName = "Infectious Hellfire",
		SecondaryAbilities = {"Bloodthirst"},
	},
	["Rhythm Fish"] = {
		Name = "Rhythm Fish",
		ModelName = "Rhythm Fish",
		Rarity = "Special",
		ColorTrait = "Colorless",
		DecalId = "rbxassetid://87126443009563", -- Placeholder decal
		Description = "A fish of created from shapes and beats, blasting a chromatic haven of color and sound.",
		AbilityName = "Chromatic Blast",
		BaseStats = {
			GatherSpeed = 2.5, -- Seconds to gather 1 resource
			GatherAmount = 8, -- Amount collected per gather
			MoveSpeed = 20, -- Studs per second
			ConvertSpeed = 3, -- Seconds per conversion cycle
			ConvertAmount = 600, -- Algae converted per cycle
			Attack = 8,			AttackSpeed = 1.0,
		},
		Passive = "Overtaking Melody"
	},
	["Puppeteer Fish"] = {
		Name = "Puppeteer Fish",
		ModelName = "Puppeteer Fish",
		Rarity = "Legendary",
		ColorTrait = "Pink",
		DecalId = "rbxassetid://90363643420672", -- Placeholder decal
		Description = "A fish with incredible precision and control! Her ability to perform allows her to pinpoint any algae spot, devastating everything around it.",
		BaseStats = {
			GatherSpeed = 2,
			GatherAmount = 5,
			MoveSpeed = 17,
			ConvertSpeed = 2,      -- was 5 | CR: 80â†’250/s (fixed: was same as Diver Rare)
			ConvertAmount = 500,   -- was 400
			Attack = 7,			AttackSpeed = 1.0,
		},
		AbilityName = "Pinned Down",
		SecondaryAbilities = {"Surging Pins"},
		BuffNames = {"PinBoost"},
	},
	["Rabbit Fish"] = {
		Name = "Rabbit Fish",
		ModelName = "Rabbit Fish",
		Rarity = "Legendary",
		ColorTrait = "Colorless",
		DecalId = "rbxassetid://75915383204282",
		Description = "iya haaaaa tuff king right here",
		BaseStats = {
			GatherSpeed = .2,
			GatherAmount = 5,
			MoveSpeed = 50,
			ConvertSpeed = .5,
			ConvertAmount = 50,
			Attack = 13,			AttackSpeed = 1.0,
		},
		Passive = "Glow+" -- Upgraded: now upgrades existing marks to 1.75x (red)
	},
	["Seraphish"] = {
		Name = "Seraphish",
		ModelName = "Seraphish",
		Rarity = "Mythic",
		ColorTrait = "Orange",
		DecalId = "rbxassetid://85404072064412",
		Passives = {"Guardian's Protection"},
		Description = "please speed i need thisssss",
		BaseStats = {
			GatherSpeed = 2,
			GatherAmount = 20,
			MoveSpeed = 30,
			ConvertSpeed = 2,
			ConvertAmount = 2500,
			Attack = 14,			AttackSpeed = 1.0,
		},
		AbilityName = "Descent From Heaven",
		SecondaryAbilities = {"Solar Flare"},
		Passive = "Trail of Light"
	},
	["Illusionary Fish"] = {
		Name = "Illusionary Fish",
		ModelName = "Illusionary Fish",
		Rarity = "Mythic",
		ColorTrait = "Colorless",
		DecalId = "rbxassetid://87667845434617",
		Description = "you're my visionary. be the good puppet that i need. let me harness your dreams, and in return, the illusion of freedom will consume you.",
		BaseStats = {
			GatherSpeed = 2,
			GatherAmount = 20,
			MoveSpeed = 30,
			ConvertSpeed = 2,
			ConvertAmount = 2500,
			Attack = 4,			AttackSpeed = 1.0,
		},
		AbilityName = "Sanctuary",
		Passive = "_my.safespace.",
	},
	["Mirror Fish"] = {
		Name = "Mirror Fish",
		ModelName = "Mirror Fish",
		Rarity = "Epic",
		ColorTrait = "Colorless",
		DecalId = "rbxassetid://95060244071345", -- Placeholder
		Description = "A mysterious fish that reflects others around them to create an army.",
		BaseStats = {
			GatherSpeed = 1,
			GatherAmount = 2,
			MoveSpeed = 16,
			ConvertSpeed = 1,
			ConvertAmount = 300,
			Attack = 20,			AttackSpeed = 1.0,
		},
		Passive = "Mitosis",
	},
}
