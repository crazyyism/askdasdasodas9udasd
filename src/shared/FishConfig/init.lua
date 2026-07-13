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
FishConfig.Abilities = require(script.Abilities)
FishConfig.Passives = require(script.Passives)
FishConfig.Buffs = require(script.Buffs)
FishConfig.Fish = require(script.Fish)
return FishConfig
