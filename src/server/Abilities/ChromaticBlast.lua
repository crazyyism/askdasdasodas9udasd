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
	local color = (vfxOverride and vfxOverride.Color) or Color3.new(1,1,1)
	VFXReplication:FireAllClients("ChromaticBlast", player, fishIndex, color, {Position = position, ForceOverride = (vfxOverride ~= nil)})
	local count = abilityConfig.Count or 5
	local spawnRate = abilityConfig.SpawnRate or 3.0
	local shrinkTime = abilityConfig.ShrinkTime or 2.5
	local minigameDuration = abilityConfig.MinigameDuration or ((count * spawnRate) + shrinkTime + 2)
	
	local uid = player.UserId
	AbilityService.ExpectedRhythmHits[uid] = (AbilityService.ExpectedRhythmHits[uid] or 0) + count
	
	RhythmGameEvent:FireClient(player, count, spawnRate, shrinkTime)
	
	-- Timeout to clear expected hits if client never finishes minigame
	task.delay(minigameDuration, function()
		if AbilityService.ExpectedRhythmHits[uid] then
			AbilityService.ExpectedRhythmHits[uid] = math.max(0, AbilityService.ExpectedRhythmHits[uid] - count)
		end
	end)
end


end
