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
	-- Scale duration by fish level: base + 0.3s per level above 1
	local fishData = data and data.FishSchool and data.FishSchool[tostring(fishIndex)]
	local fishLevel = (fishData and fishData.Level) or 1
	local duration = (abilityConfig.Duration or 15) + (fishLevel - 1) * 0.3
	local tweenHeight = abilityConfig.TweenHeight or 14
	local boostAmount = (abilityConfig.AlgaeBoostAmount or 0.15) * multiplier
	local radius = abilityConfig.Radius or 10
	VFXReplication:FireAllClients("PinnedDown", player, fishIndex, {Pos=position, Dur=duration, Height=tweenHeight, Override=vfxOverride})
	local hitbox = Instance.new("Part")
	hitbox.Name = "PinHitbox"; hitbox.Anchored = true; hitbox.CanCollide = false
	hitbox.Transparency = 1; hitbox.Size = Vector3.new(radius*2, 20, radius*2)
	hitbox.Position = position; hitbox.Parent = workspace
	table.insert(ActivePins, { Hitbox = hitbox, Position = position, Radius = radius, Expires = os.clock() + duration, BoostAmount = boostAmount })
end


end
