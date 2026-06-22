local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

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
	if not position then return end
	local HarvestService = require(script.Parent.Parent.HarvestService)
	local radius = (abilityConfig and abilityConfig.Radius) or 3
	local amount = ((abilityConfig and abilityConfig.Amount) or 13) * multiplier
	local overlapParams = BuildAlgaeOverlapParams()
	local boxSize = Vector3.new(radius * 2, 10, radius * 2)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(position), boxSize, overlapParams)
	local toHarvest = {}
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then table.insert(toHarvest, part) end
	end
	if #toHarvest > 0 then HarvestService.HarvestMultipleBatched(player, toHarvest, amount) end
	VFXReplication:FireAllClients("Dive", player, fishIndex, vfxOverride)
end


end
