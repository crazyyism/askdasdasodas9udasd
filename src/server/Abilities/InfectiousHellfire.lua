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
	VFXReplication:FireAllClients("Infect", player, fishIndex, vfxOverride)
	local FieldService = require(script.Parent.Parent.FieldService)
	local radius = abilityConfig.Radius or 10
	local duration = abilityConfig.InitialDuration or 5
	local globalMult = (abilityConfig.GlobalMultiplier or 1.5) * multiplier
	local specificMults = abilityConfig.SpecificMultipliers or { GreenAlgae = 2.5 }
	local overlapParams = BuildAlgaeOverlapParams()
	local parts = workspace:GetPartBoundsInRadius(position, radius, overlapParams)
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then FieldService.InfectPart(part, duration, globalMult, specificMults) end
	end
end


end
