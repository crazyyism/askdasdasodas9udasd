local TokenConfig = {}

TokenConfig.TokenDespawnTime = 20
TokenConfig.TokenSpawnChance = 0.005 -- 5% chance on each harvested algae node

TokenConfig.Drops = {
    -- Low tier / Common Drops
    {Item = "Biomass", Chance = 300},
    {Item = "Fish Feed", Chance = 150},
	{Item = "Zooplankton", Chance = 15},
    {Item = "Pearl", Chance = 7},
    
    -- High tier / Rare Drops
	{Item = "Sea Mine", Chance = 1},
	{Item = "Bronze Egg", Chance = 0.05},
    {Item = "Sapphire Egg", Chance = 0.0025},
	{Item = "Ruby Egg", Chance = 0.0001},
}

function TokenConfig.GetRandomDrop()
	local totalWeight = 0
	for _, drop in ipairs(TokenConfig.Drops) do
		totalWeight = totalWeight + drop.Chance
	end
	
	local rand = math.random() * totalWeight
	for _, drop in ipairs(TokenConfig.Drops) do
		if rand <= drop.Chance then
			return drop.Item
		end
		rand = rand - drop.Chance
	end
	return nil
end

return TokenConfig
