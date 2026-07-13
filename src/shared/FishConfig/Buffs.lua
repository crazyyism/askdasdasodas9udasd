return {
	InfiniteCapacity = {
		Name = "Infinite Capacity",
		Stat = {"CapacityMult"},
		Duration = 999999999,
		MaxStacks = 1,
		CapacityMult = 1e12,
		Description = function(s) return "+999999% Capacity" end,
		Image = "rbxassetid://106511130630799", -- Placeholder
	},
	InstantFire = {
		Name = "Instant Fire",
		Stat = {"ToolSpeed"},
		Duration = 999999999,
		MaxStacks = 1,
		ToolSpeed = 1000000000,
		Description = function(s) return "+100000000000% Tool Speed" end,
		Image = "rbxassetid://88880625345798", -- Placeholder
	},
	TidalSurge = {
		Name = "Tidal Surge",
		Stat = {"CriticalPower", "ToolSpeed"},
		Duration = 45,
		MaxStacks = 200,
		CritPowerBonus = 0.01,
		ToolSpeedBonus = 0.005,
		Description = function(s) return "+" .. (s*1) .. "% Critical Power & +" .. (s*0.5) .. "% Tool Speed" end,
		Image = "rbxassetid://6521360146", -- Placeholder wave icon
	},
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
	GreenGemBoost = {
		Name = "Green Gem",
		Stat = "GreenAlgae",
		Duration = 900,
		Multiplier = 1, -- +100% per stack
		Description = function(s) return "+" .. (s*100) .. "% Green Algae" end,
		Image = "rbxassetid://76687032697276", -- Placeholder
	},
	OrangeGemBoost = {
		Name = "Orange Gem",
		Stat = "OrangeAlgae",
		Duration = 900,
		Multiplier = 1,
		Description = function(s) return "+" .. (s*100) .. "% Orange Algae" end,
		Image = "rbxassetid://81956234626056",
	},
	PinkGemBoost = {
		Name = "Pink Gem",
		Stat = "PinkAlgae",
		Duration = 900,
		Multiplier = 1,
		Description = function(s) return "+" .. (s*100) .. "% Pink Algae" end,
		Image = "rbxassetid://80180445405238",
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

	Dreaming = {
		Name = "Dreaming",
		Stat = {"CritChanceBonus", "MegaCritChance", "CritPowerBonus", "CapacityMultiplier"},
		Duration = 30,
		MaxStacks = 30,
		CritChanceBonusAmount = 0.005,
		MegaCritChanceBonusAmount = 0.005,
		CritPowerBonusAmount = 0.05,
		CapacityPercentGainAmount = 0.01,
		Description = function(s) return "+" .. (s*0.5) .. "% Crit/Mega Crit Chance, +" .. (s*5) .. "% Crit Power, +" .. (s) .. "% Capacity" end,
	},
	RhythmFeverPlus = {
		Name = "Rhythm Fever+",
		Stat = {"CritPowerBonus", "InstantConversion", "Algae", "MegaCritChance"},
		Duration = 110, -- Slightly longer than ToTheMoon to ensure cleanup
		MaxStacks = 10,
		Description = function(s) return "+" .. (s*25) .. "% Crit Power, +" .. (s*1) .. "% Inst. Conv, +" .. (s*10) .. "% All Algae, +" .. (s*0.75) .. "% Mega Crit" end,
		Image = "rbxassetid://136768414531009", -- Use Rhythm Fever icon for now
	},
	ToTheMoon = {
		Name = "To The Moon",
		Duration = 90,
		MaxStacks = 1,
		Description = function(s) return "Rhythm mini-game now grants Rhythm Fever+" end,
		Image = "rbxassetid://136768414531009",
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
	-- Specific Reef Boosts (Fertilizer)
	["Freshwater Reef Boost"] = {
		Name = "Freshwater Reef Boost",
		Duration = 600,
		Description = function(s) return "Freshwater Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://99573954545827", -- Placeholder
	},
	["Coral Reef Boost"] = {
		Name = "Coral Reef Boost",
		Duration = 600,
		Description = function(s) return "Coral Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://138326733105283", -- Placeholder
	},
	["Trash Reef Boost"] = {
		Name = "Trash Reef Boost",
		Duration = 600,
		Description = function(s) return "Trash Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://139126235785451", -- Placeholder
	},
	["Sun Reef Boost"] = {
		Name = "Sun Reef Boost",
		Duration = 600,
		Description = function(s) return "Sun Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://86841882553583", -- Placeholder
	},
	["Runic Reef Boost"] = {
		Name = "Runic Reef Boost",
		Duration = 600,
		Description = function(s) return "Runic Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://73927614335540", -- Placeholder
	},
	["Obsidian Reef Boost"] = {
		Name = "Obsidian Reef Boost",
		Duration = 600,
		Description = function(s) return "Obsidian Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://100787135091763", -- Placeholder
	},
	["Crystal Reef Boost"] = {
		Name = "Crystal Reef Boost",
		Duration = 600,
		Description = function(s) return "Crystal Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://109850306612953", -- Placeholder
	},
	["Coralline Reef Boost"] = {
		Name = "Coralline Reef Boost",
		Duration = 600,
		Description = function(s) return "Coralline Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://89189196307393", -- Placeholder
	},
	["Ghastly Reef Boost"] = {
		Name = "Ghastly Reef Boost",
		Duration = 600,
		Description = function(s) return "Ghastly Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://103766158402815", -- Placeholder
	},
	["Heavensent Reef Boost"] = {
		Name = "Heavensent Reef Boost",
		Duration = 600,
		Description = function(s) return "Heavensent Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://105631283747728", -- Placeholder
	},
	["Ancient Reef Boost"] = {
		Name = "Ancient Reef Boost",
		Duration = 600,
		Description = function(s) return "Ancient Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://94740113371182", -- Placeholder
	},
	["Warrior's Reef Boost"] = {
		Name = "Warrior's Reef Boost",
		Duration = 600,
		Description = function(s) return "Warrior's Reef Algae Boost +" .. math.floor((s - 1) * 100) .. "%" end,
		Image = "rbxassetid://109015949755734", -- Placeholder
	},
}
