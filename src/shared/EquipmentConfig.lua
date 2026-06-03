local EquipmentConfig = {
	-- Noob Shop Items
	["Fishing Net"] = {
		Name = "Fishing Net",
		Description = "The trusty starter net.",
		Price = 0,
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Fishing Net",
		Shop = "NoobShop",
		Cam = "Cam1"
	},
	["Scissors"] = {
		Name = "Scissors",
		Description = "Although lacking range, its precision cuts deep through algae.",
		Price = 900, -- was 1,500 (~day 1-2)
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Scissors",
		Shop = "NoobShop",
		Cam = "Cam2"
	},
	["Shovel"] = {
		Name = "Shovel",
		Description = "Good ol' reliable, wood handle with a metal sheet at the end, collecting decent amounts of algae.",
		Price = 4000, -- was 6,000 (~day 3-5)
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Shovel",
		Shop = "NoobShop",
		Cam = "Cam3"
	},
	["FishingHook"] = {
		Name = "Fishing Hook",
		Description = "A hook off a fishing rod! Optimal for quick swipes, yet lacks a lot of range.",
		Price = 12500, -- was 25,000 (~week 1, NoobShop cap)
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "FishingHook",
		Shop = "NoobShop",
		Cam = "Cam4"
	},
	["Crystiken"] = {
		Name = "Crystiken",
		Description = "A crystalline shuriken from the crystal reef.",
		Price = 45000,
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Crystiken",
		Shop = "NoobShop",
		Cam = "Cam5"
	},
	["Pouch"] = {
		Name = "Pouch",
		Description = "The starter backpack, holds 250 algae.",
		Price = 0,
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "Pouch",
		Shop = "NoobShop",
		Cam = "Cam6",
		-- Backpack Stats
		Capacity = 400,
		ConvertAdd = 0,
		AlgaePercentAdd = 0,
	},
	["Bucket"] = {
		Name = "Bucket",
		Description = "Holds more than a pouch. Boosts Convert Rate by 25%",
		Price = 2000, -- was 1,000 | pairs with Scissors (4k) — day 1-2
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "Bucket",
		Shop = "NoobShop",
		Cam = "Cam7",
		-- Backpack Stats
		Capacity = 1750,
		ConvertAdd = 25,
		AlgaePercentAdd = 0,
	},
	["OxygenTank"] = {
		Name = "Oxygen Tank",
		Description = "A reliable tank to hold your needs. Boosts algae by 15% and Convert Rate by 50%",
		Price = 8750, -- was 7,500 | pairs with Shovel (20k) — day 3-5
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "OxygenTank",
		Shop = "NoobShop",
		Cam = "Cam8",
		-- Backpack Stats
		Capacity = 4500,
		ConvertAdd = 50,
		AlgaePercentAdd = 15,
	},
	["Aquarium"] = {
		Name = "Aquarium",
		Description = "An aquarium to hold algae, its like a mini home for ya fish Boosts algae by 25% and Convert Rate by 100%.",
		Price = 25750, -- was 30,000 | pairs with FishingHook (75k) — week 1
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "Aquarium",
		Shop = "NoobShop",
		Cam = "Cam9",
		-- Backpack Stats
		Capacity = 17500,
		ConvertAdd = 100,
		AlgaePercentAdd = 25,
	},
	["Barrel"] = {
		Name = "Barrel",
		Description = "da big barrel of algae. Boosts algae by 35% and Convert Rate by a whopping 250%",
		Price = 75000,
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "Barrel",
		Shop = "NoobShop",
		Cam = "Cam10",
		-- Backpack Stats
		Capacity = 32500, -- was 65,000 | softens the 15x gap to RunicShard
		ConvertAdd = 250,
		AlgaePercentAdd = 35,
	},
	["Sunkissed Art"] = {
		Name = "Sunkissed Art",
		Description = "da big barrel of algae. Boosts algae by 35% and Convert Rate by a whopping 250%",
		Price = 0, -- was 100,000 | pre-RunicShop grind wall — week 1-2
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Sunkissed Art",
		Shop = "NoobShop",
		Cam = "Cam11"
	},
	["Polarized Artifact"] = {
		Name = "Polarized Artifact",
		Description = "An artifact of polarizing light. Boosts Algae by 25%, Move Speed by 30%, Capacity by 10%, Convert Rate by 300%, +5% Instant Conversion, and +10% Biomass per Algae. Also grants +25% Specific Algae for all types!",
		Price = 750000, 
		Currency = "Biomass",
		Materials = {
			["Pearl"] = 25,
			["Sea Mine"] = 5,
			["Sapphire Egg"] = 1
		},
		Image = "rbxassetid://83922655853881", --81956234626056
		ProductType = "Artifact",
		ArtifactId = "Polarized Artifact",
		Shop = "ArtifactShop1",
		Cam = "Cam1", 
		Stats = {
			SpeedBoost = 0.3,
			AlgaeBoost = 0.25,
			CapacityBoost = 2.5,
			ConvertBoost = 3,
			InstantConvertBoost = 0.05,
			PinkAlgaeBoost = 1.5,
			CriticalChance = 0.05,
			BiomassBoost = 0.1
		}
	},
	["Sunray Artifact"] = {
		Name = "Sunray Artifact",
		Description = "A radiant artifact that empowers orange algae. Boosts Orange Algae by 100%, Biomass by 40%, Convert Rate by 500%, Speed by 15%, and Backpack Capacity by 100%. Heals algae around you.",
		Price = 1500000,
		Currency = "Biomass",
		Image = "rbxassetid://81956234626056",
		ProductType = "Artifact",
		ArtifactId = "Sunray Artifact",
		Shop = "ArtifactShop1",
		Cam = "Cam3",
		Materials = {
			["Pearl"] = 35,
			["Sea Mine"] = 3,
			["Ruby Egg"] = 1
		},
		Stats = {
			OrangeAlgaeBoost = 1.0,
			BiomassBoost = 0.4,
			ConvertBoost = 5,
			SpeedBoost = 0.15,
			CapacityBoost = 0.75  -- +100% backpack capacity
		},
		Passive = "Blessing of Ra"
	},
	["Rhythmic Chromatose"] = {
		Name = "Rhythmic Chromatose",
		Description = "An artifact that resonates with the rhythm of the ocean. Boosts All Algae by 150%, Convert Rate by 400%, 20% Instant Conversion, 25% Biomass, and 30% Movespeed. Grants the 'To The Moon' Passive (Rhythm Fish Exclusive)",
		Price = 2500000, -- Selling for 25M Biomass as it's powerful
		Materials = {
			["Pearl"] = 100,
			["Sea Mine"] = 40
		},
		Currency = "Biomass",
		Image = "rbxassetid://97824366226147",
		ProductType = "Artifact",
		ArtifactId = "Rhythmic Chromatose",
		Shop = "ArtifactShop1",
		Cam = "Cam4",
		Stats = {
			AlgaeBoost = 1.5,
			ConvertBoost = 4,
			InstantConvertBoost = 0.2,
			BiomassBoost = 0.25,
			SpeedBoost = 0.3
		},
		Passive = "To the Moon"
	},
	["Rainmaker"] = {
		Name = "Rainmaker",
		Description = "A tool that rains the depths of atlantic onto the reef. Harnesses the power to use a hydro-blast to decimate algae.",
		Price = 10000000,
		Materials = {
			["Pearl"] = 35,
			["Sea Mine"] = 2,
			["Sapphire Egg"] = 1
		},
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Rainmaker",
		Shop = "ArtifactShop1",
		Cam = "Cam2"
	},
	["Hydroglider"] = {
		Name = "Hydroglider",
		Description = "Glide through the waters by jumping mid-air",
		Price = 25000,
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Hydroglider",
		Shop = "NoobShop",
		Cam = "Cam12"
	},
	-- Egg Shop Items
	["Basic Egg"] = {
		Name = "Basic Egg",
		Description = "Guarantees a Basic Fish, with the possibility of something rarer..",
		Price = 250,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam1",
		Scaling = {
			Multiplier = 4,
			Max = 100000
		}
	},
	["Ruby Egg"] = {
		Name = "Ruby Egg",
		Description = "A vibrant, red egg that glimmers with the power of rubies. Guarantees a Legendary fish!",
		Price = 0,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam4",
		Materials = {
			["Pearl"] = 100
		}
	},
	["Rhythm Egg"] = {
		Name = "Rhythm Egg",
		Description = "A special egg that guarantees a Rhythm Fish! (One-time purchase)",
		Price = 0,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam5",
		Materials = {
			["Pearl"] = 1000
		}
	},
	["Sapphire Egg"] = {
		Name = "Sapphire Egg",
		Description = "A vibrant cobalt egg that glimmers like sapphire. Guarantees anything above epic.",
		Price = 0,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam3",
		Materials = {
			["Pearl"] = 25
		}
	},
	["Bronze Egg"] = {
		Name = "Bronze Egg",
		Description = "A sparkling egg with a tough coating of bronze. Guarantees fish above rare!",
		Price = 0,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam2",
		Materials = {
			["Pearl"] = 5
		}
	},
	["Fish Feed"] = {
		Name = "Fish Feed",
		Description = "Use on fish to give them 1000 XP",
		Price = 10000,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Item",
		Shop = "EggShop",
		Cam = "Cam6",
	},
	-- Runic Shop Items
	["Runic Shard"] = {
		Name = "Runic Shard",
		Description = "A fragment from the runic dimension put on Earth. Its ability to contain large amounts of algae is given due to its artifact on the back of the carved stone.",
		Price = 225000, -- was 250,000 | pairs with MegaNet (600k) — RunicShop gateway
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "RunicShard",
		Shop = "RunicShop",
		Cam = "Cam1",
		-- Backpack Stats
		Capacity = 125000,
		ConvertAdd = 375, -- was 200 (BUG: was less than Barrel's 250!)
		AlgaePercentAdd = 55,
	},
	["Turtle Shell"] = {
		Name = "Turtle Shell",
		Description = "A shell from the ancient turtles of the sea. Holds 3 million algae.",
		Price = 1500000, -- was 1,250,000 | pairs with StoneHammer (1.8M) — early-mid
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "TurtleShell",
		Shop = "RunicShop",
		Cam = "Cam2",
		-- Backpack Stats
		Capacity = 400000,
		ConvertAdd = 525, -- was 300 (BUG: was less than corrected RunicShard's 375!)
		AlgaePercentAdd = 70, -- was 65
	},
	["Poseidon"] = {
		Name = "Poseidon",
		Description = "God's greatest gift. Spawns a TIDAL WAVE after 6 consecutive hits.",
		Price = 3500000,
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Poseidon",
		Shop = "RunicShop",
		Cam = "Cam7"
	},
	["MegaNet"] = {
		Name = "Mega Net",
		Description = "An upgrade of the Fishing Net, clears a lot more algae in the front of the player, with faster swing speeds.",
		Price = 62500, -- was 125,000 (~8x FishingHook — RunicShop gateway wall)
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "MegaNet",
		Shop = "RunicShop",
		Cam = "Cam3"
	},
	["Sun Staff"] = {
		Name = "Sun Staff",
		Description = "A portable sun encapsulated in a staff.",
		Price = 350000,
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Sun Staff",
		Shop = "RunicShop",
		Cam = "Cam5"
	},
	["SharkScythe"] = {
		Name = "Shark Scythe",
		Description = "A scythe embued with the power of the greatest sharks.",
		Price = 8500000,
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "SharkScythe",
		Shop = "RunicShop",
		Cam = "Cam6"
	},
	["StoneHammer"] = {
		Name = "Stone Hammer",
		Description = "A stone hammer forged for giants",
		Price = 180000, -- was 750,000 (~3x MegaNet — early-mid, Pro Shop tier 2)
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "StoneHammer",
		Shop = "RunicShop",
		Cam = "Cam4"
	},
}

EquipmentConfig.Eggs = {
	["Basic Egg"] = {
		DisplayName = "Basic Egg",
		Description = "Guarantees a Basic Fish, with the possibility of something rarer..",
		ImageId = "rbxassetid://91092112542656", -- Placeholder
		Rarities = {
			Common = 98,
			Rare = 1.5,
			Epic = 0.4,
			Legendary = .1,
			Mythic = 0
		}
	},
	["Ruby Egg"] = {
		DisplayName = "Ruby Egg",
		Description = "A vibrant, red egg that glimmers with the power of rubies. Guarantees a Legendary fish!",
		ImageId = "rbxassetid://117172911785170", -- Placeholder
		Rarities = {
			Common = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 98,
			Mythic = 2
		}
	},
	["Sapphire Egg"] = {
		DisplayName = "Sapphire Egg",
		Description = "test",
		ImageId = "rbxassetid://85374010696833", -- Placeholder
		Rarities = {
			Common = 0,
			Rare = 0,
			Epic = 85,
			Legendary = 14,
			Mythic = 1
		}
	},
	["Bronze Egg"] = {
		DisplayName = "Bronze Egg",
		Description = "A sparkling egg with a tough coating of bronze. Guarantees fish above rare!",
		ImageId = "rbxassetid://108860105364532", -- Placeholder
		Rarities = {
			Common = 0,
			Rare = 70,
			Epic = 25,
			Legendary = 4.9,
			Mythic = 0.1
		}
	},
	["mythic Egg"] = {
		DisplayName = "Mythic Egg",
		Description = "Guaranteed Mythic Fish!",
		ImageId = "rbxassetid://88144930254065",
		Rarities = {
			Common = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0,
			Mythic = 100
		}
	},
	["Rhythm Egg"] = {
		DisplayName = "Rhythm Egg",
		Description = "A special egg that guarantees a Rhythm Fish! (Unique: Only one per aquarium-owner)",
		ImageId = "rbxassetid://91092112542656", -- New Placeholder
		Rarities = {
			Common = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0,
			Mythic = 0,
			Special = 100
		}
	},
	["Zooplankton"] = {
		DisplayName = "Zooplankton",
		Description = "Transforms your fish into a random fish!",
		ImageId = "rbxassetid://75165572204410", -- Placeholder
		RequiresFish = true,
		Rarities = {
			Common = 0,
			Rare = 90,
			Epic = 8,
			Legendary = 1.999,
			Mythic = 0.001
		}
	},
	["Pearl"] = {
		DisplayName = "Pearl",
		Description = "A precious resource used for crafting.",
		ImageId = "rbxassetid://80180445405238", -- Placeholder (Pearl-like icon)
	},
	["Sparking Sun"] = {
		DisplayName = "Sparking Sun",
		Description = "A radiant, sparking fragment of a sun. A precious resource.",
		ImageId = "rbxassetid://81956234626056", -- Placeholder (Sun-like icon)
	},

	["Fish Feed"] = {
		DisplayName = "Fish Feed",
		Description = "Feed this to a fish to give them 1000 XP!",
		ImageId = "rbxassetid://131703071734552", -- Placeholder
		RequiresFish = true,
		IsFeed = true, -- Flag for client/server logic
	},
	["Sea Mine"] = {
		DisplayName = "Sea Mine",
		Description = "Drag to spawn a Sea Mine on the current reef!",
		ImageId = "rbxassetid://83516768366792", -- Placeholder
		IsConsumable = true, 
	},
	["Fertilizer"] = {
		DisplayName = "Fertilizer",
		Description = "Boosts algae by 100% for 10 minutes.",
		ImageId = "rbxassetid://76687032697276", -- Placeholder
		IsConsumable = true,
	}
}

return EquipmentConfig
