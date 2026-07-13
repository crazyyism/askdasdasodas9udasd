return {
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
		EnergyRequired = 30,
		Duration = 15,
		TweenHeight = -2,
		AlgaeBoostAmount = 0.15,
		ToolSpeedBonus = 0.025,
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
		EnergyPerHarvest = { Min = 1, Max = 5 },
		EnergyRequired = 24,
		Radius = 15,
		Count = 7,
		SpawnRate = 0.6,
		ShrinkTime = 1.2,
		MinigameDuration = 10, 
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
		Description = "A chorus of music will spew out of the ground for two seconds, and will blast out afterwards. During the blast, it will collect algae around it and if in proximity, grants a buff of Harmony. Harmony grants 50% critical power and 20% pink algae."
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
	["Sanctuary"] = {
		EnergyPerHarvest = { Min = 1, Max = 5 },
		EnergyRequired = 10,
		Description = "spawn me a haven of my imagination. Spawns a sanctuary that that grants 'dreaming'. lasts for 10 seconds. along with that, during sanctuary, it spawns 25 explosive pieces in a spiral to collect algae.",
		ExplosionCount = 15,
		ExplosionDelay = 0.15,
		RadiusStep = 1,
		AngleStep = 36,
		CollectionRadius = 6,
		CollectionAmount = 12
	},
}

