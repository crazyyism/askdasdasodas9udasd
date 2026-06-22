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
	local radius = abilityConfig.Radius or 10
	local amount = (abilityConfig.Amount or 12) * multiplier
	VFXReplication:FireAllClients("Synesthesia", player, fishIndex, {Position = position})
	task.delay(2, function()
		if not player or not player.Parent then return end
		local HarvestService = require(script.Parent.Parent.HarvestService)
		local overlapParams = BuildAlgaeOverlapParams()
		local toHarvest = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, overlapParams)) do
			if part:IsA("BasePart") then table.insert(toHarvest, part) end
		end
		if #toHarvest > 0 then HarvestService.HarvestBatch(player, toHarvest, amount, true, true) end
		local buffRange = abilityConfig.BuffRange or radius
		if player.Character and player.Character.PrimaryPart then
			if (player.Character.PrimaryPart.Position - position).Magnitude <= buffRange then
				AbilityService.ApplyBuff(player, "Harmony")
			end
		end
	end)
end


end
