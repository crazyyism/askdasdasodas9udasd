return {
	["Guardian's Protection"] = {
		Name = "Guardian's Protection",
		Description = "When locking on to a mob, spawn a Guardian Call in front of it to deal 10x the fish's attack and harvest algae.",
	},
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
		Description = "After every 10 collects, Mitosis triggers: spawn a temporary clone of the fish that collects algae. Lasts 30 seconds. Limit 10.",
		MaxClones = 10,
		TriggerCount = 10,
	},
	["_my.safespace."] = {
		Name = "_my.safespace.",
		Description = "When collecting inside a Sanctuary, always mega crit, gain 100% MoveSpeed/Collection Speed, and harvest a 3x3 block.",
		SanctuaryRadius = 15,
		SpeedMultiplier = 2,
		GatherMultiplier = 2,
		HarvestRadius = 6.5,
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
		Description = "Every 3rd collect, mark nearby algae (4 tile radius) to give 1.1x algae. If the algae is already marked, upgrades that mark turning it red and boosting it to 1.75x instead.",
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

