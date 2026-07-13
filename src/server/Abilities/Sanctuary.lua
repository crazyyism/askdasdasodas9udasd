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
		VFXReplication:FireAllClients("Sanctuary", player, fishIndex, {Position = position})
		
		local numExplosions = abilityConfig.ExplosionCount or 15
		local duration = abilityConfig.Duration or 10
		local delayBetween = abilityConfig.ExplosionDelay or (duration / numExplosions)

		VFXReplication:FireAllClients("SanctuaryBullets", player, fishIndex, {
			Position = position,
			ExplosionCount = numExplosions,
			ExplosionDelay = delayBetween,
			RadiusStep = abilityConfig.RadiusStep or 1,
			AngleStep = abilityConfig.AngleStep or 36
		})

		-- Spiral explosions
		task.spawn(function()
			local collectionRadius = abilityConfig.CollectionRadius or 6
			local collectionAmount = (abilityConfig.CollectionAmount or 12) * multiplier
			
			local angleOffset = 0
			local radius = 0
			for i = 1, numExplosions do
				task.wait(delayBetween)
				if not player or not player.Parent then break end
				
				angleOffset = angleOffset + math.rad(abilityConfig.AngleStep or 36)
				radius = radius + (abilityConfig.RadiusStep or 1)
				
				local explPos = position + Vector3.new(math.cos(angleOffset) * radius, 0, math.sin(angleOffset) * radius)
				
				-- Raycast downward to snap explPos to ground
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				if player.Character then
					raycastParams.FilterDescendantsInstances = {player.Character}
				end
				local raycastResult = workspace:Raycast(explPos + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), raycastParams)
				if raycastResult and raycastResult.Instance then
					explPos = raycastResult.Position
				end
				
				-- Delay collection to match bullet travel time (0.8s)
				task.delay(0.8, function()
					local toHarvest = {}
					local overlapParams = BuildAlgaeOverlapParams()
					local parts = workspace:GetPartBoundsInRadius(explPos, collectionRadius, overlapParams)
					for _, p in ipairs(parts) do
						if p:IsA("BasePart") then table.insert(toHarvest, p) end
					end
					
					if #toHarvest > 0 then
						HarvestService.HarvestMultipleBatched(player, toHarvest, collectionAmount, true)
					end
				end)
			end
		end)
		
		-- Buff Aura Loop
		task.spawn(function()
			local buffDuration = duration
			local elapsed = 0
			local buffRate = 2.0
			local sanctuaryRadius = abilityConfig.SanctuaryRadius or 30
			
			-- Initial grant if they are inside when it spawns
			if player and player.Character and player.Character.PrimaryPart then
				local dist = (player.Character.PrimaryPart.Position - position).Magnitude
				if dist <= sanctuaryRadius then
					AbilityService.ApplyBuff(player, "Dreaming")
				end
			end
			
			while elapsed < buffDuration do
				local dt = task.wait(buffRate)
				elapsed = elapsed + dt
				if not player or not player.Character or not player.Character.PrimaryPart then break end
				
				local dist = (player.Character.PrimaryPart.Position - position).Magnitude
				if dist <= sanctuaryRadius then
					AbilityService.ApplyBuff(player, "Dreaming")
				end
			end
		end)
	end
end
