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
	local duration = abilityConfig.Duration or 10
	local tickRate = abilityConfig.TickRate or 0.25
	local radius = abilityConfig.HarvestRadius or 5
	local baseAmount = (abilityConfig.HarvestAmount or 8) * multiplier
	local pData = PlayerData.get(player)
	local pinkBoost = (pData and pData.Stats and pData.Stats.BasePinkAlgae) or 0
	local amount = baseAmount * (1 + math.floor(pinkBoost * 10) * 0.01)
	VFXReplication:FireAllClients("Black Hole", player, fishIndex, {Position = position, Duration = duration})
	task.spawn(function()
		if abilityConfig.DamageTick == false then
			AbilityService.DealAbilityDamage(player, position, abilityConfig)
		end
		local HarvestService = require(script.Parent.Parent.HarvestService)
		local overlapParams = BuildAlgaeOverlapParams()
		local elapsed, nextFishIndex = 0, 1
		local lastDamageTick = 0
		while elapsed < duration do
			if not player or not player.Parent then break end
			local myFish = {}
			local tracked = playerFishPositions[player.UserId]
			if tracked then for _, pos in pairs(tracked) do table.insert(myFish, pos) end end
			if #myFish == 0 then
				for _, child in ipairs(workspace:GetChildren()) do
					if child.Name:match("^Fish_"..player.UserId.."_%d+$") and child:IsA("Model") and child.PrimaryPart then
						table.insert(myFish, child.PrimaryPart.Position)
					end
				end
			end
			if #myFish > 0 then
				if nextFishIndex > #myFish then nextFishIndex = 1 end
				local fishPos = myFish[nextFishIndex]; nextFishIndex += 1
				local toHarvest = {}
				for _, part in ipairs(workspace:GetPartBoundsInRadius(fishPos, radius, overlapParams)) do
					if part:IsA("BasePart") then table.insert(toHarvest, part) end
				end
				if #toHarvest > 0 then
					HarvestService.HarvestMultipleBatched(player, toHarvest, amount, true)
					VFXReplication:FireAllClients("BlackHoleCollect", player, nil, fishPos)
				end
			end
			if type(abilityConfig.DamageTick) == "number" then
				if elapsed - lastDamageTick >= abilityConfig.DamageTick then
					AbilityService.DealAbilityDamage(player, position, abilityConfig)
					lastDamageTick = elapsed
				end
			end
			if player.Character and player.Character.PrimaryPart then
				local buffRange = (abilityConfig.BuffRange or radius) + 5
				if (player.Character.PrimaryPart.Position - position).Magnitude <= buffRange then
					AbilityService.ApplyBuff(player, "PinkAlgaeBoost")
				end
			end
			task.wait(tickRate); elapsed += tickRate
		end
	end)
end
end
