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

	return function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
		if not position then return end
		AbilityService.ApplyBuff(player, "Dreaming")
		VFXReplication:FireAllClients("Sanctuary", player, fishIndex, {Position = position})
		
		-- Spiral explosions
		task.spawn(function()
			local numExplosions = 25
			local duration = 10
			local delayBetween = duration / numExplosions
			local angleOffset = 0
			local radius = 0
			for i = 1, numExplosions do
				task.wait(delayBetween)
				if not player or not player.Parent then break end
				
				angleOffset = angleOffset + math.rad(360 / 5)
				radius = radius + (15 / numExplosions)
				
				local explPos = position + Vector3.new(math.cos(angleOffset) * radius, 0, math.sin(angleOffset) * radius)
				
				local toHarvest = {}
				local overlapParams = BuildAlgaeOverlapParams()
				local parts = workspace:GetPartBoundsInRadius(explPos, 4, overlapParams)
				for _, p in ipairs(parts) do
					if p:IsA("BasePart") then table.insert(toHarvest, p) end
				end
				
				if #toHarvest > 0 then
					HarvestService.HarvestMultipleBatched(player, toHarvest, 10 * multiplier, true)
				end
			end
		end)
	end
end
