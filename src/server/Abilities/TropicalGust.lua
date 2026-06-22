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
	AbilityService.DealAbilityDamage(player, position, abilityConfig)
	local duration = abilityConfig.Duration or 10
	local tickRate = abilityConfig.TickRate or 1.5
	local buffRange = abilityConfig.BuffRange or 10
	local gustPos = position
	VFXReplication:FireAllClients("TropicalGust", player, fishIndex, position, duration, vfxOverride)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			task.wait(tickRate)
			elapsed += tickRate
			if player.Character and player.Character.PrimaryPart then
				if (player.Character.PrimaryPart.Position - gustPos).Magnitude <= buffRange then
					if abilityConfig.Buffs then
						for _, buffName in ipairs(abilityConfig.Buffs) do AbilityService.ApplyBuff(player, buffName) end
					end
				end
			end
		end
	end)
end


end
