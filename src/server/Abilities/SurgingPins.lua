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
	local pins = AbilityService.GetActivePins()
	if not pins then return end
	
	local now = os.clock()
	local fishData = data and data.FishSchool and (data.FishSchool[fishIndex] or data.FishSchool[tostring(fishIndex)])
	local fishLevel = fishData and fishData.Level or 1
	local gatherAmount = math.floor(7 * (1 + 0.1 * (fishLevel - 1)))
	if gatherAmount < 1 then gatherAmount = 1 end

	local surgeParts = {}
	local uniqueParts = {}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {workspace.Terrain}
	
	-- Harvest around ALL pins and pulse ALL pins
	for _, pin in ipairs(pins) do
		if pin.Hitbox and pin.Hitbox.Parent and now <= pin.Expires then
			local nearby = workspace:GetPartBoundsInRadius(pin.Position, pin.Radius, params)
			for _, part in ipairs(nearby) do
				if part:IsA("BasePart") and part:FindFirstChild("Capacity") and part:FindFirstChild("AlgaeAmount") then
					if not uniqueParts[part] then
						uniqueParts[part] = true
						table.insert(surgeParts, part)
					end
				end
			end
			
			-- Fire neon pink pulse VFX at EVERY pin
			VFXReplication:FireAllClients("SurgingPin", nil, nil, pin.Position)
		end
	end
	
	if #surgeParts > 0 then
		local HarvestService = require(script.Parent.Parent.HarvestService)
		HarvestService.HarvestBatch(player, surgeParts, gatherAmount, true, true)
	end
end


end
