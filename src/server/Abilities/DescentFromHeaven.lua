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
	local radius = abilityConfig.Radius or 20
	local amount = (abilityConfig.Amount or 15) * multiplier
	VFXReplication:FireAllClients("DescentFromHeaven", player, fishIndex, position, extraData)
	task.delay(2.15, function()
		if not player or not player.Parent then return end
		local HarvestService = require(script.Parent.Parent.HarvestService)
		local overlapParams = BuildAlgaeOverlapParams()
		local toHarvest = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, overlapParams)) do
			if part:IsA("BasePart") then table.insert(toHarvest, part) end
		end
		if #toHarvest > 0 then HarvestService.HarvestBatch(player, toHarvest, amount, true, true) end
		local playerParams = OverlapParams.new()
		playerParams.FilterType = Enum.RaycastFilterType.Include
		local allChars = {}
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(allChars, p.Character) end end
		playerParams.FilterDescendantsInstances = allChars
		local hitPlayers = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, playerParams)) do
			local plr = Players:GetPlayerFromCharacter(part.Parent)
			if plr and not hitPlayers[plr] then hitPlayers[plr] = true; AbilityService.ApplyBuff(plr, "Blessed") end
		end
		AbilityService.DealAbilityDamage(player, position, abilityConfig)
	end)
end


end
