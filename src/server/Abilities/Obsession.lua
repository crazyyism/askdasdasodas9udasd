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
	AbilityService.DealAbilityDamage(player, position, abilityConfig)
	local dist = math.huge
	if player.Character and player.Character.PrimaryPart and position then
		dist = (player.Character.PrimaryPart.Position - position).Magnitude
	end
	local buffRange = abilityConfig.BuffRange or 10
	if dist <= buffRange and abilityConfig.Buffs then
		for _, buffName in ipairs(abilityConfig.Buffs) do AbilityService.ApplyBuff(player, buffName) end
	end
	VFXReplication:FireAllClients("Obsession", player, fishIndex, vfxOverride)
end


end
