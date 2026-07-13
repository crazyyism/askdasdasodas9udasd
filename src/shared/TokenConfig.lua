local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ChanceConfig"))

local TokenConfig = {}

-- Despawn time for dropped tokens
TokenConfig.TokenDespawnTime = 20

function TokenConfig.GetRandomDrop()
	local totalWeight = 0
	for _, drop in ipairs(ChanceConfig.SeaMineDrops) do
		totalWeight = totalWeight + drop.Chance
	end
	
	local rand = math.random() * totalWeight
	for _, drop in ipairs(ChanceConfig.SeaMineDrops) do
		if rand <= drop.Chance then
			return drop.Item
		end
		rand = rand - drop.Chance
	end
	return nil
end

return TokenConfig
