local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local FishConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishConfig"))

return function(context)
	local AbilityService = context.AbilityService
	local HarvestService = context.HarvestService
	local FieldService = context.FieldService
	local VFXReplication = context.VFXReplication
	local RhythmGameEvent = context.RhythmGameEvent
	local ActivePins = context.ActivePins
	local PlayerData = context.PlayerData
	local PlayerBuffs = context.PlayerBuffs
	local BuildAlgaeOverlapParams = context.BuildAlgaeOverlapParams
	local playerFishPositions = context.playerFishPositions

	return  function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	local school = data.FishSchool
	local pool = {}
	for _, fish in pairs(school) do
		local resolvedAbility = fish.AbilityName
		if not resolvedAbility and FishConfig.Fish[fish.Id] then
			resolvedAbility = FishConfig.Fish[fish.Id].AbilityName
		end
		if fish.Id ~= "Mirror Fish" and resolvedAbility ~= "Duplication" then
			table.insert(pool, fish)
		end
	end
	local abilityList = {}
	for _, fish in ipairs(pool) do
		local targetCfg = FishConfig.Fish[fish.Id]
		if targetCfg then
			local aName = fish.AbilityName or targetCfg.AbilityName
			if aName and aName ~= "Duplication" then
				table.insert(abilityList, { AbilityName = aName, FishId = fish.Id })
			end
		end
	end
	if #abilityList == 0 then
		table.insert(abilityList, { AbilityName = "Dive", FishId = "Mirror Fish" })
	end
	local newVfxOverride = { Color = Color3.new(1, 1, 1), ForceOverride = true }
	local newExtraData = { Multiplier = multiplier, VFXOverride = newVfxOverride }
	if extraData then
		for k, v in pairs(extraData) do
			if newExtraData[k] == nil then newExtraData[k] = v end
		end
	end
	
	local randomEntry = abilityList[math.random(1, #abilityList)]
	AbilityService.ExecuteAbility(player, fishIndex, randomEntry.FishId, position, randomEntry.AbilityName, newExtraData)
end


end
