local FishConfig = {}

FishConfig.TestPhaseEnabled = false -- Parameter to enable/disable TestPhase buff on join

FishConfig.Rarities = {
	Common = { Color = Color3.fromRGB(200, 200, 200) },
	Rare = { Color = Color3.fromRGB(100, 200, 255) },
	Epic = { Color = Color3.fromRGB(200, 0, 255) },
	Legendary = { Color = Color3.fromRGB(255, 0, 0) },
	Mythic = { Color = Color3.fromRGB(0, 255, 255) },
	Special = { Color = Color3.fromRGB(255, 215, 0) }, -- Gold
}



-- ==================== ABILITIES REGISTRY ====================
-- Define all abilities here once, then assign to fish by name
FishConfig.Abilities = {
	["Tropical Gust"] = {
		EnergyPerHarvest = { Min = 0.5, Max = 4 },
		EnergyRequired = 40,
		BuffRange = 25, -- Range to receive Focus buff
		Duration = 4,
		TickRate = .75,
		Damage = 10,
		Range = 8,
		DamageTick = .4,
		Buffs = {"Focus", "Speed", "GreenAlgaeBoost"},
		Description = "Spawns a gust of wind that applies Focus & Speed buffs. (+3% Crit Chance & +10% Move Speed per stack, max 10x)."
	},
	["Obsession"] = {
		EnergyPerHarvest = { Min = 0.5, Max = 7.5 },
		EnergyRequired = 27,
		Radius = 12,
		Amount = 2,
		BuffRange = 25,
		Damage = 100,
		Range = 10,
		DamageTick = false,
		Buffs = {"PinkAlgaeBoost"},
		Description = "Jumps and pulses the air with a lovestruck hue. 50% Pink Algae Boost"
	},
	["Infectious Hellfire"] = {
		EnergyPerHarvest = { Min = 1, Max = 5 },
		EnergyRequired = 53,
		Radius = 10,
		InitialDuration = 8,
		MinDuration = 0.25,
		SpreadDelay = 1,
		SpreadProb = 1.0,
		DecayRate = 0.6,
		GlobalMultiplier = 1.5,
		SpecificMultipliers = { GreenAlgae = 2.5 },
		Description = "Infects algae with a hellish plague. When an algae block is infected, algae production from said block will multiply by 1.5. However, if the algae block is green, it will multiply the algae production of said block by 2.5, rather than 1.5."
	},
	["Pinned Down"] = {
		EnergyPerHarvest = { Min = 0.5, Max = 6.5 },
		EnergyRequired = 66,
		Duration = 15,
		TweenHeight = -2,
		AlgaeBoostAmount = 0.15,
		Description = "Spawns a pin that grants 15% algae boost, plus 2.5% tool speed boost. Multiple pins stack, even with multiple people! For every stack of Pin Boost, 1% of your algae capacity gets converted."
	},
	["Bloodthirst"] = {
		Duration = 9,
		Radius = 4,
		MoveSpeed = 40,
		HarvestAmount = 3,
		TickRate = 0.1,
		HitCheckInterval = 0.1,
		RicochetAngleVariance = 45,
		MaxBounces = 15,
		Damage = 40,
		Range = 3,
		DamageTick = 0.1,
		Description = "Fires a slash that bounces from fish to fish collecting algae everywhere it goes."
	},
	["Dive"] = {
		EnergyPerHarvest = { Min = 0.5, Max = 4.5 },
		EnergyRequired = 16,
		Radius = 3,
		Amount = 13,
		Description = "Dives and harvests 13 capacity from all blocks in a 3-stud radius."
	},
	["Solar Flare"] = {
		EnergyPerHarvest = { Min = 1, Max = 3 },
		EnergyRequired = 33,
		Duration = 10,
		RefillRadius = 10,
		RefillAmount = 8,
		RefillRate = .25,
		Damage = 30,
		Range = 10,
		DamageTick = 0.25,
		Buffs = {"OrangeAlgaeBoost"},
		Description = "Summons a sun that refills algae around it and grants an Orange Algae Boost for every tick you are within its radius."
	},
	["Chromatic Blast"] = {
		EnergyPerHarvest = { Min = 1, Max = 3 },
		EnergyRequired = 24,
		Radius = 15,
		Count = 3,
		Description = "Spawns a rhythm minigame that requries you to press the buttons that spawn around your screen according to when the ring around it shrinks. Pressing the button when the ring matches the size of the button will grant a stack of Rhythm Fever, boosting ALL algae by 3%. Perfects grant 5 stacks, Goods grant 3 staccks, and Bads grant 1 stack. When missing a button, your stack of Rhythm Fever decreases by a factor of 80%."
	},
	["Duplication"] = {
		EnergyPerHarvest = { Min = 1, Max = 20 },
		EnergyRequired = 200,
		Description = "Duplicates a random ability from another fish in your aquarium. If no other fish are present, it performs Dive. Algae from mirror fish is lessened from original ability."
	},
	["Synesthesia"] = {
		EnergyPerHarvest = { Min = 0.5, Max = 5 },
		EnergyRequired = 53,
		Radius = 8,
		Amount = 15,
		BuffRange = 30,
		Damage = 80,
		Range = 25,
		DamageTick = false,
		Buffs = {"Harmony"},
		Description = "A chorus of music will spew out of the ground for two seconds, and will blast out afterwards. During the blast, it will collect algae around it and if in proximity, grants a buff of Harmony."
	},
	["Black Hole"] = {
		EnergyPerHarvest = { Min = 1, Max = 5 },
		EnergyRequired = 40,
		Duration = 20,
		TickRate = 0.15,
		HarvestRadius = 5,
		HarvestAmount = 8,
		Damage = 25,
		Range = 30,
		DamageTick = 0.15,
		Description = "Summon a point of singularity to collect algae for you. Every 0.25 seconds of the black hole's existence, algae will be taken in a 5x5 radius around a fish. Lasts around 10 seconds before disappearing. Scales with your Pink Algae stat: +1% harvest per 10% Pink Algae bonus."
	},
	["Descent From Heaven"] = {
		EnergyPerHarvest = { Min = 1, Max = 8 },
		EnergyRequired = 80,
		Radius = 20,
		Amount = 15,
		Buffs = {"Blessed"},
		Damage = 500,
		Range = 30,
		DamageTick = false,
		Description = "Spawns in a ghost guardian from the heavens above which strike down where the fish is located. When the ability is initially activated, it will spawn a sigil below to indicate where the guardian is. Standing below that sigil when the guardian strikes will grant a stack of Blessed. Blessed grants orange algae, player movespeed, fish movespeed, and critical power."
	},
	["Surging Pins"] = {
		EnergyPerHarvest = { Min = 0.5, Max = 4 },
		EnergyRequired = 53,
		LevelRequired = 0,
		Description = "Forces a power surge across all active pins, collecting 7 algae (+10% per level) in a 4x4 radius. Ability locked under level 4."
	},
	["Grand Slam"] = {
		EnergyPerHarvest = { Min = 2, Max = 6 },
		EnergyRequired = 35,
		Damage = 200,
		Range = 14,
		DamageTick = false,
		Description = "Leaps into the air, growing 4x its size, and crashes down to collect 20 capacity in a 14x14 radius. It then leaps 5 more times, crashing into 5 more random spots!"
	},
	["Pink Boost"] = {
		EnergyPerHarvest = { Min = 1, Max = 5 },
		EnergyRequired = 20,
		Buffs = {"PinkAlgaeBoost"},
		Description = "Grants a stack of Pink Boost, increasing Pink Algae production by 50% for 10 seconds."
	},
	["Green Boost"] = {
		EnergyPerHarvest = { Min = 1, Max = 5 },
		EnergyRequired = 20,
		Buffs = {"GreenAlgaeBoost"},
		Description = "Grants a stack of Green Boost, increasing Green Algae production by 50% for 7 seconds."
	},
	["Orange Boost"] = {
		EnergyPerHarvest = { Min = 1, Max = 5 },
		EnergyRequired = 20,
		Buffs = {"OrangeAlgaeBoost"},
		Description = "Grants a stack of Orange Boost, increasing Orange Algae production by 50% for 7 seconds."
	},
}

-- ==================== PASSIVES REGISTRY ==================
FishConfig.Passives = {
	["Glow"] = {
		Name = "Glow",
		Description = "Every 3rd collect, mark nearby algae (4 tile radius/24 studs) to give 1.1x algae.",
		TriggerCount = 3,
		Radius = 6, -- roughly 4 tiles
		Multiplier = 1.1,
		Duration = 10,
	},
	["Overtaking Melody"] = {
		Name = "Overtaking Melody",
		Description = "For each stack of Rhythm Fever, this fish moves 5% faster, collects 5% faster, and converts 5% faster.",
		MoveSpeedBonusPerStack = 0.05,
		GatherSpeedBonusPerStack = 0.05,
		ConvertSpeedBonusPerStack = 0.05,
	},
	["To The Moon"] = {
		Name = "To The Moon",
		Description = "After 200 stacks of Rhythm Fever are hit, To The Moon will activate. During To The Moon, every single perfect hit from Chromatic Blast applies a buff of Rhythm Fever+, giving significant buffs and lasting significantly longer than Rhythm Fever",
	},
	["Mitosis"] = {
		Name = "Mitosis",
		Description = "1/100 chance on gather to create a temporary clone of a random fish in your aquarium for 17 seconds. The clone is neon blue and slightly transparent.",
		Duration = 17,
		Chance = 100, -- 1 in 100
	},
	["Trail of Light"] = {
		Name = "Trail of Light",
		Description = "Every 1s, nearby algae (4x4 radius) is marked, for 1.1x algae.",
		Radius = 4,
		Multiplier = 1.1,
		Duration = 5,
	},
	["Glow+"] = {
		Name = "Glow+",
		Description = "Every 3rd collect, mark nearby algae (4 tile radius) to give 1.1x algae. If the algae is already marked, upgrades that mark â€” turning it red and boosting it to 1.75x instead.",
		TriggerCount = 3,
		Radius = 6,
		Multiplier = 1.1,
		UpgradedMultiplier = 1.75,
		Duration = 10,
	},
	["Bloat"] = {
		Name = "Bloat",
		Description = "Grand Slam collects +6% more Pink Algae per stack of Bloated buff active.",
		PinkBoostPerStack = 0.06,
	},
}

-- ==================== BUFFS REGISTRY ====================
-- Define all buffs here once, then assign to abilities/fish by name
FishConfig.Buffs = {
	Focus = {
		Name = "Focus",
		Stat = {"CriticalChance"},
		MaxStacks = 10,
		CriticalChance = 0.03, -- +3% per stack
		Description = function(s) return "+" .. (s*3) .. "% Critical Chance" end,
		Image = "rbxassetid://122717261789181", -- Placeholder
	},
	PinkAlgaeBoost = {
		Name = "Pink Boost",
		Stat = "PinkAlgae",
		Duration = 10,
		MaxStacks = 10,
		Multiplier = 0.5,
		Description = function(s) return "+" .. (s*50) .. "% Pink Algae" end,
		Image = "rbxassetid://125426013806302", -- Placeholder
	},
	GreenAlgaeBoost = {
		Name = "Green Boost",
		Stat = "GreenAlgae",
		Duration = 7,
		MaxStacks = 10,
		Multiplier = 0.5, -- +50% per stack
		Description = function(s) return "+" .. (s*50) .. "% Green Algae" end,
		Image = "rbxassetid://76687032697276", -- Placeholder
	},
	OrangeAlgaeBoost = {
		Name = "Orange Boost",
		Stat = "OrangeAlgae",
		Duration = 7,
		MaxStacks = 10,
		Multiplier = 0.5, -- +50% per stack
		Description = function(s) return "+" .. (s*50) .. "% Orange Algae" end,
		Image = "rbxassetid://137465296316335", -- Placeholder
	},
	PinBoost = {
		Name = "Pin Boost",
		Stat = {"Algae", "ToolSpeed"},
		Duration = 1000,
		AlgaeBoostAmount = 0.15,
		ToolSpeedBonus = 0.025,
		Description = function(s) return "+" .. (s*15) .. "% Algae & +" .. (s*2.5) .. "% Tool Speed" end,
		Image = "rbxassetid://126760095285818", -- Placeholder
	},
	TheSunsWrath = {
		Name = "The Sun's Wrath",
		Duration = 30,
		MaxStacks = 1,
		OrangeAlgaeBoost = 1.0, -- +100%
		MegaCritChanceBonus = 0.05, -- +5%
		Description = function(s) return "+100% Orange Algae & +5% Mega-Crit Chance. Sunkissed Ability Cooldown." end,
	},
	ToolBoost = {
		Name = "Tool Boost",
		Stat = "ToolAlgae",
		Duration = 7,
		StackAmount = 0.25, -- +25% per stack 
		Description = function(s) return "+" .. (s*25) .. "% Tool Algae" end,
		Image = "rbxassetid://105676799503686", -- Placeholder
	},
	RhythmFever = {
		Name = "Rhythm Fever",
		Stat = {"Algae", "PinkAlgae", "GreenAlgae", "OrangeAlgae"},
		Duration = 30,
		MaxStacks = 200,
		Multiplier = 0.03,
		Description = function(s) return "+" .. (s*3) .. "% Algae + All Algae Types" end,
		Image = "rbxassetid://77262491853063", -- Placeholder
	},
	Speed = {
		Name = "Speed",
		Stat = {"PlayerWalkSpeedMult"},
		Duration = 10,
		MaxStacks = 10,
		Multiplier = 0.1, -- +10% per stack
		Description = function(s) return "+" .. (s*10) .. "% Move Speed" end,
		Image = "rbxassetid://70627586472131", -- Placeholder
	},
	Harmony = {
		Name = "Harmony",
		Stat = {"PinkAlgae", "CritPowerBonus"},
		Duration = 30,
		MaxStacks = 10,
		Multiplier = 0.20,      -- Pink Algae (+20%)
		CritPowerBoost = 0.50,  -- Crit Power (+50%)
		Description = function(s) return "+" .. (s*20) .. "% Pink Algae & +" .. (s*50) .. "% Crit Power" end,
		Image = "rbxassetid://88503856342395", -- Placeholder
	},
	-- CriticalBoost removed - Critical hits now use fixed multiplier
	BulletBlessing = {
		Name = "Bullet Blessing",
		Stat = {"CritPowerBonus", "Algae"},
		Duration = 30, -- 30 second duration
		CritPowerBonus = 0.25, -- +25% critical power (makes crits 3.75x instead of 3x)
		AlgaeBoostAmount = 0.02, -- +2% algae boost
		InstantConversion = 0.02, -- +2% instant conversion
		Description = function(s) return "+25% Crit Power, +2% Algae & +2% Inst. Conv. Cannot use Rainmaker ability." end,
		Image = "rbxassetid://76283250371440", -- Placeholder
	},
	Bloated = {
		Name = "Bloated",
		Duration = 60, -- 10 minutes
		MaxStacks = 100, -- Arbitrary high max stacks if they can stack indefinitely
		CapacityPercentGain = 0.03, -- 3% capacity per stack
		Description = function(s) return "+" .. (s * 3) .. "% Capacity" end,
		Image = "rbxassetid://88503856342395", -- Placeholder
	},
	TestPhase = {
		Name = "Test Phase",
		Duration = 432000, -- 5 days
		MaxStacks = 1,
		AlgaeBoost = 100, -- +10000%
		ConvertBoost = 100, -- +10000%
		Description = function(s) return "TEST PHASE: +10000% Algae & Conversion stats" end,
		Image = "rbxassetid://137465296316335", -- Placeholder
	},
	Fertilize = {
		Name = "Fertilize",
		Stat = {"Algae"},
		Duration = 600, -- 10 minutes
		MaxStacks = 1,
		AlgaeBoostAmount = 1.0, -- +100%
		Description = function(s) return "Boosts Algae gain by 100%." end,
		Image = "rbxassetid://76687032697276", -- Placeholder
	},
	ToTheMoon = {
		Name = "To The Moon",
		Stat = {"Algae"},
		Duration = 90,
		MaxStacks = 1,
		Description = function(s) return "GO CRAZYYYYYYYYYYYYYYYY" end,
		Image = "rbxassetid://113411057215867", -- Use Rhythm Fever icon for now
	},
	RhythmFeverPlus = {
		Name = "Rhythm Fever+",
		Stat = {"CritPowerBonus", "InstantConversion", "Algae", "MegaCritChance"},
		Duration = 65, -- Slightly longer than ToTheMoon to ensure cleanup
		MaxStacks = 500,
		Description = function(s) return "+" .. (s*25) .. "% Crit Power, +" .. (s*1) .. "% Inst. Conv, +" .. (s*10) .. "% All Algae, +" .. (s*0.75) .. "% Mega Crit" end,
		Image = "rbxassetid://136768414531009", -- Use Rhythm Fever icon for now
	},
	Blessed = {
		Name = "Blessed",
		Stat = {"OrangeAlgae", "PlayerWalkSpeedMult", "CritPowerBonus", "FishMoveSpeedMultiplier"},
		Duration = 30,
		MaxStacks = 10,
		OrangeAlgaeBonus = 0.33, -- +100%
		MoveSpeedBonus = 0.05, -- +5%
		CritPowerBonus = 0.20, -- +20%
		FishMoveSpeedBonus = 0.10, -- +10%
		Description = function(s) return "Blessed by the Heavens, " .. (s*33) .. "% Orange Algae, " .. (s*5) .. "% Move Speed, " .. (s*20) .. "% Crit Power, " .. (s*10) .. "% Fish Speed" end,
		Image = "rbxassetid://138240321477449", -- Placeholder (Descent Icon?)
	},
}

-- ==================== FISH REGISTRY ====================
FishConfig.Fish = {
	-- Starting Fish
	["Basic Fish"] = {
		Name = "Basic Fish",
		ModelName = "Basic Fish",
		Rarity = "Common",
		ColorTrait = "Colorless",
		DecalId = "rbxassetid://105676799503686", -- Placeholder decal
		Description = "A hardworking fish, although the fish has no abilities of his own.",
		BaseStats = {
			GatherSpeed = 3, -- Seconds to gather 1 resource
			GatherAmount = 1, -- Amount collected per gather
			MoveSpeed = 12, -- Studs per second
			ConvertSpeed = 3, -- Seconds per conversion cycle
			ConvertAmount = 250, -- Algae converted per cycle
			Attack = 5,			AttackSpeed = 1.0,
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
			GatherSpeed = 3, -- Seconds to gather 1 resource
			GatherAmount = 1, -- Amount collected per gather
			MoveSpeed = 12, -- Studs per second
			ConvertSpeed = 3, -- Seconds per conversion cycle
			ConvertAmount = 250, -- Algae converted per cycle
			Attack = 10,			AttackSpeed = 1.0,
		},
		AbilityName = "Orange Boost",
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
			Attack = 10,			AttackSpeed = 1.0,
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
			Attack = 40,			AttackSpeed = 1.0,
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
			Attack = 10,			AttackSpeed = 1.0,
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
			GatherSpeed = 4,       -- was 6 | GR: 0.67â†’1.0/s (fixed: was below Rare Angler)
			GatherAmount = 4,
			MoveSpeed = 16,
			ConvertSpeed = 2,
			ConvertAmount = 250,
			Attack = 20,			AttackSpeed = 1.0,
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
			ConvertAmount = 100,
			Attack = 20,			AttackSpeed = 1.0,
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
			Attack = 20,			AttackSpeed = 1.0,
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
			Attack = 20,			AttackSpeed = 1.0,
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
			Attack = 20,			AttackSpeed = 1.0,
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
			Attack = 40,			AttackSpeed = 1.0,
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
			Attack = 50,			AttackSpeed = 1.0,
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
			Attack = 40,			AttackSpeed = 1.0,
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
			Attack = 40,			AttackSpeed = 1.0,
		},
		Passive = "Glow+" -- Upgraded: now upgrades existing marks to 1.75x (red)
	},
	["Seraphish"] = {
		Name = "Seraphish",
		ModelName = "Seraphish",
		Rarity = "Mythic",
		ColorTrait = "Orange",
		DecalId = "rbxassetid://85404072064412",
		Description = "please speed i need thisssss",
		BaseStats = {
			GatherSpeed = 2,
			GatherAmount = 20,
			MoveSpeed = 30,
			ConvertSpeed = 2,
			ConvertAmount = 2500,
			Attack = 80,			AttackSpeed = 1.0,
		},
		AbilityName = "Descent From Heaven",
		SecondaryAbilities = {"Solar Flare"},
		Passive = "Trail of Light"
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
			MoveSpeed = 22,
			ConvertSpeed = 1,
			ConvertAmount = 300,
			Attack = 20,			AttackSpeed = 1.0,
		},
		Passive = "Mitosis",
	},
}





return FishConfig

