local EquipmentConfig = {

	-- NoobShop Items
	["Sunkissed Art"] = {
		Name = "Sunkissed Art",
		Description = "da big barrel of algae. Boosts algae by 35% and Convert Rate by a whopping 250%",
		Price = 10000000, -- was 100,000 | pre-RunicShop grind wall — week 1-2
		Currency = "Biomass",
		Materials = {
			["Pearl"] = 75,
			["Sparking Sun"] = 1,
			["Orange Gem"] = 50,
			
		},
		ProductType = "Tool",
		ToolId = "Sunkissed Art",
		Shop = "VolcanicShop",
		Cam = "Cam2"
	},
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
		Description = "The starter backpack, holds 250 algae. Boosts Convert Rate by 0% and Algae by 0%.",
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
		Description = "Holds more than a pouch. Boosts Convert Rate by 25% and Algae by 0%.",
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
		Description = "A reliable tank to hold your needs. Boosts Convert Rate by 50% and Algae by 15%.",
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
		Description = "An aquarium to hold algae, its like a mini home for ya fish. Boosts Convert Rate by 100% and Algae by 25%.",
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
		Description = "da big barrel of algae. Boosts Convert Rate by 250% and Algae by 35%.",
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

	-- EggShop Items
	["Fish Feed"] = {
		Name = "Fish Feed",
		DisplayName = "Fish Feed",
		Description = "Feed this to a fish to give them 1000 XP!",
		ImageId = "rbxassetid://131703071734552", -- Placeholder
		Price = 10000,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Item",
		Shop = "EggShop",
		Cam = "Cam6",
		RequiresFish = true,
		IsFeed = true, -- Flag for client/server logic
		XPAmount = 1000,
	},
	["Rhythm Egg"] = {
		Name = "Rhythm Egg",
		DisplayName = "Rhythm Egg",
		Description = "A special egg that guarantees a Rhythm Fish! (Unique: Only one per aquarium-owner)",
		ImageId = "rbxassetid://91092112542656", -- New Placeholder
		Price = 0,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam5",
		Materials = {
			["Pearl"] = 1000
		},
		Rarities = {
			Common = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0,
			Mythic = 0,
			Special = 100
		}
	},
	["Ruby Egg"] = {
		Name = "Ruby Egg",
		DisplayName = "Ruby Egg",
		Description = "A vibrant, red egg that glimmers with the power of rubies. Guarantees a Legendary fish!",
		ImageId = "rbxassetid://117172911785170", -- Placeholder
		Price = 0,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam4",
		Materials = {
			["Pearl"] = 100
		},
		Rarities = {
			Common = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 98,
			Mythic = 2
		}
	},
	["Sapphire Egg"] = {
		Name = "Sapphire Egg",
		DisplayName = "Sapphire Egg",
		Description = "An egg infused with sapphire crystals. Guarantees an Epic fish!",
		ImageId = "rbxassetid://85374010696833", -- Placeholder
		Price = 0,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam3",
		Materials = {
			["Pearl"] = 25
		},
		Rarities = {
			Common = 0,
			Rare = 0,
			Epic = 85,
			Legendary = 14,
			Mythic = 1
		}
	},
	["Bronze Egg"] = {
		Name = "Bronze Egg",
		DisplayName = "Bronze Egg",
		Description = "A sparkling egg with a tough coating of bronze. Guarantees a Rare fish!",
		ImageId = "rbxassetid://108860105364532", -- Placeholder
		Price = 0,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam2",
		Materials = {
			["Pearl"] = 5
		},
		Rarities = {
			Common = 0,
			Rare = 70,
			Epic = 25,
			Legendary = 4.9,
			Mythic = 0.1
		}
	},
	["Basic Egg"] = {
		Name = "Basic Egg",
		DisplayName = "Basic Egg",
		Description = "Guarantees a Basic Fish, with the possibility of something rarer..",
		ImageId = "rbxassetid://91092112542656", -- Placeholder
		Price = 250,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Egg",
		Shop = "EggShop",
		Cam = "Cam1",
		Scaling = {
			Multiplier = 4,
			Max = 100000
		},
		Rarities = {
			Common = 85,
			Rare = 12,
			Epic = 2,
			Legendary = 0.9999999,
			Mythic = 0.0000001
		}
	},

	-- ZooplanktonMachine Items
	["Eviction_1"] = {
		Name = "Eviction",
		DisplayName = "1x Eviction",
		Description = "Swipe over a fish in your aquarium to remove it.",
		Price = 250000,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Item",
		Shop = "ZooplanktonMachine",
		Cam = "Cam1"
	},
	["Zooplankton_1"] = {
		Name = "Zooplankton",
		DisplayName = "1x Zooplankton",
		Description = "A single zooplankton. Transforms your fish into a random fish!",
		Price = 1250000,
		Currency = "Biomass",
		Amount = 1,
		ProductType = "Item",
		Shop = "ZooplanktonMachine",
		Cam = "Cam1"
	},
	["Zooplankton_10"] = {
		Name = "Zooplankton",
		DisplayName = "10x Zooplankton",
		Description = "Ten zooplankton packages. Bulk mutation power!",
		Price = 12500000,
		Currency = "Biomass",
		Amount = 10,
		ProductType = "Item",
		Shop = "ZooplanktonMachine",
		Cam = "Cam2"
	},
	["Zooplankton_100"] = {
		Name = "Zooplankton",
		DisplayName = "100x Zooplankton",
		Description = "One hundred zooplankton packages. High volume mutations!",
		Price = 125000000,
		Currency = "Biomass",
		Amount = 100,
		ProductType = "Item",
		Shop = "ZooplanktonMachine",
		Cam = "Cam3"
	},
	["Zooplankton_1000"] = {
		Name = "Zooplankton",
		DisplayName = "1,000x Zooplankton",
		Description = "One thousand zooplankton packages. Mega volume mutations!",
		Price = 1250000000,
		Currency = "Biomass",
		Amount = 1000,
		ProductType = "Item",
		Shop = "ZooplanktonMachine",
		Cam = "Cam4"
	},
	["Zooplankton_10000"] = {
		Name = "Zooplankton",
		DisplayName = "10,000x Zooplankton",
		Description = "Ten thousand zooplankton packages. Colossal volume mutations!",
		Price = 12500000000,
		Currency = "Biomass",
		Amount = 10000,
		ProductType = "Item",
		Shop = "ZooplanktonMachine",
		Cam = "Cam5"
	},
	["Zooplankton_100000"] = {
		Name = "Zooplankton",
		DisplayName = "100,000x Zooplankton",
		Description = "One hundred thousand zooplankton packages. Ultimate volume mutations!",
		Price = 125000000000,
		Currency = "Biomass",
		Amount = 100000,
		ProductType = "Item",
		Shop = "ZooplanktonMachine",
		Cam = "Cam6"
	},

	-- RunicShop Items
	["MegaNet"] = {
		Name = "Mega Net",
		Description = "An upgrade of the Fishing Net, clears a lot more algae in the front of the player, with faster swing speeds.",
		Price = 150000, -- was 62,500
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "MegaNet",
		Shop = "RunicShop",
		Cam = "Cam5"
	},
	["StoneHammer"] = {
		Name = "Stone Hammer",
		Description = "A stone hammer forged for giants",
		Price = 400000, -- was 180,000
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "StoneHammer",
		Shop = "RunicShop",
		Cam = "Cam6"
	},
	["Sun Staff"] = {
		Name = "Sun Staff",
		Description = "A portable sun encapsulated in a staff.",
		Price = 1000000,
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Sun Staff",
		Shop = "RunicShop",
		Cam = "Cam7"
	},
	["SharkScythe"] = {
		Name = "Shark Scythe",
		Description = "A scythe embued with the power of the greatest sharks.",
		Price = 4500000,
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "SharkScythe",
		Shop = "RunicShop",
		Cam = "Cam8"
	},
	["Poseidon"] = {
		Name = "Poseidon",
		Description = "God's greatest gift. Spawns a TIDAL WAVE after 6 consecutive hits.",
		Price = 12500000,
		Currency = "Biomass",
		ProductType = "Tool",
		ToolId = "Poseidon",
		Shop = "AbyssShop",
		Cam = "Cam1"
	},
	["Water Wings"] = {
		Name = "Water Wings",
		Description = "Wings forged from the depths of the Abyss. Boosts Convert Rate by 600% and Algae by 100%.",
		Price = 125000000,
		Materials = {
			["Convertrix"] = 10,
			["Pearl"] = 100,
			["Fertilizer"] = 25,
			["Sea Mine"] = 25,

			["Sapphire Egg"] = 2
		},
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "WaterWings",
		Shop = "AbyssShop",
		Cam = "Cam2",
		Capacity = 5000000,
		ConvertAdd = 1200,
		AlgaePercentAdd = 250,
	},
	["Runic Shard"] = {
		Name = "Runic Shard",
		Description = "A fragment from the runic dimension put on Earth. Its ability to contain large amounts of algae is given due to its artifact on the back of the carved stone. Boosts Convert Rate by 375% and Algae by 55%.",
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
	["Stonepack"] = {
		Name = "Stonepack",
		Description = "A sturdy backpack made from carved runic stones. Holds 3 million algae. Boosts Convert Rate by 525% and Algae by 70%.",
		Price = 6000000,
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "Stonepack",
		Shop = "RunicShop",
		Cam = "Cam3",
		-- Backpack Stats
		Capacity = 700000,
		ConvertAdd = 525,
		AlgaePercentAdd = 70,
	},
	["Turtle Shell"] = {
		Name = "Turtle Shell",
		Description = "A shell from the ancient turtles of the sea. Boosts Convert Rate by 450% and Algae by 62%.",
		Price = 750000, -- was 1,250,000 | pairs with StoneHammer (1.8M) — early-mid
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "TurtleShell",
		Shop = "RunicShop",
		Cam = "Cam2",
		-- Backpack Stats
		Capacity = 325000,
		ConvertAdd = 450,
		AlgaePercentAdd = 62,
	},
	["Portable Pillar"] = {
		Name = "Portable Pillar",
		Description = "A portable pillar of immense runic energy. Boosts Convert Rate by 750% and Algae by 110%.",
		Price = 15000000,
		Currency = "Biomass",
		ProductType = "Backpack",
		BackpackId = "PortablePillar",
		Shop = "RunicShop",
		Cam = "Cam4",
		-- Backpack Stats
		Capacity = 2000000,
		ConvertAdd = 750,
		AlgaePercentAdd = 110,
		GreenAlgaeBoost = 1.25
	},

	-- ArtifactShop1 Items
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
	["Polarized Artifact"] = {
		Name = "Polarized Artifact",
		Description = "An artifact of polarizing light. Boosts Algae by 25%, Move Speed by 30%, Capacity by 10%, Convert Rate by 300%, +5% Instant Conversion, and +10% Biomass per Algae. Also grants +25% Specific Algae for all types!",
		Price = 5000000, 
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
		Price = 25000000,
		Currency = "Biomass",
		Image = "rbxassetid://81956234626056",
		ProductType = "Artifact",
		ArtifactId = "Sunray Artifact",
		Shop = "VolcanicShop",
		Cam = "Cam1",
		Materials = {
			["Sparking Sun"] = 1,
			["Pearl"] = 50,
			["Sea Mine"] = 10,
			["Orange Gem"] = 50,
			["Fertilizer"] = 25,
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
		Price = 15000000, -- Selling for 15M Biomass as it's powerful
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
			SpeedBoost = 0.3,
			CapacityBoost = 2.5,
		},
		Passive = "To the Moon"
	},

	-- General/Definitions Items
	["Hydroglider+"] = {
		Name = "Hydroglider+",
		Description = "An upgraded hydroglider with increased speed, acceleration, and launch velocity.",
		Price = 2500000,
		Currency = "Biomass",
		Materials = {
			["Pearl"] = 20
		},
		ProductType = "Tool",
		ToolId = "Hydroglider+",
		IsUpgrade = true,
	},
	["Sea Mine"] = {
		DisplayName = "Sea Mine",
		Description = "Drag to spawn a Sea Mine on the current reef!",
		ImageId = "rbxassetid://83516768366792", -- Placeholder
		IsConsumable = true, 
	},
	["Fertilizer"] = {
		DisplayName = "Fertilizer",
		Description = "Boosts the algae from the reef you are on by 100% for 10 minutes.",
		ImageId = "rbxassetid://76687032697276", -- Placeholder
		IsConsumable = true,
		Multiplier = 2.0,
		Duration = 600, -- 10 minutes in seconds
	},
	["Sparking Sun"] = {
		DisplayName = "Sparking Sun",
		Description = "A radiant, sparking fragment of a sun. A precious resource.",
		ImageId = "rbxassetid://81956234626056", -- Placeholder (Sun-like icon)
	},

	["Orange Gem"] = {
		DisplayName = "Orange Gem",
		Description = "A glowing orange gemstone. Boosts Orange Algae by 1.5x (+50%) for 15 minutes.",
		ImageId = "rbxassetid://140450762160289",
		IsConsumable = true,
		Multiplier = 1.5,
		Duration = 900, -- 15 minutes in seconds
	},
	["Pink Gem"] = {
		DisplayName = "Pink Gem",
		Description = "A glowing pink gemstone. Boosts Pink Algae by 1.5x (+50%) for 15 minutes.",
		ImageId = "rbxassetid://122222171689349",
		IsConsumable = true,
		Multiplier = 1.5,
		Duration = 900,
	},
	["Remote Warp"] = {
		DisplayName = "Remote Warp",
		Description = "Teleports you back to your aquarium instantly!",
		ImageId = "rbxassetid://89821557756505", -- Placeholder teleporter icon
		IsConsumable = true,
	},
	["Skull"] = {
		DisplayName = "Skull",
		Description = "Spawns 15 ghost fish to help you collect algae for 10 minutes.",
		ImageId = "rbxassetid://6034176435", -- Placeholder skull icon
		IsConsumable = true,
	},
	["Convertrix"] = {
		DisplayName = "Convertrix",
		Description = "Instantly converts all algae in your backpack into biomass!",
		ImageId = "rbxassetid://134745319133733", -- Generic potion/chemical placeholder
		IsConsumable = true,
		BaseYieldMultiplier = 1.0, -- Used to scale the amount of biomass gained
	},
	["Green Gem"] = {
		DisplayName = "Green Gem",
		Description = "A glowing green gemstone. Boosts Green Algae by 1.5x (+50%) for 15 minutes.",
		ImageId = "rbxassetid://92265509856999",
		IsConsumable = true,
		Multiplier = 1.5,
		Duration = 900,
	},




	["Heavensent Egg"] = {
		DisplayName = "Heavensent Egg",
		Description = "An egg created by the heavens above. Guarantees a Mythic fish!",
		ImageId = "rbxassetid://83380572998155",
		Rarities = {
			Common = 0,
			Rare = 0,
			Epic = 0,
			Legendary = 0,
			Mythic = 100
		}
	},
	["Eviction"] = {
		DisplayName = "Eviction",
		Description = "Swipe over a fish in your aquarium to remove it.",
		ImageId = "rbxassetid://80180445405238", -- Placeholder
		RequiresFish = true,
		IsEviction = true,
	},
	["Pearl"] = {
		DisplayName = "Pearl",
		Description = "A precious resource used for crafting.",
		ImageId = "rbxassetid://80180445405238", -- Placeholder (Pearl-like icon)
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
			Legendary = 1.997,
			Mythic = 0.003
		}
	},
}

return EquipmentConfig
