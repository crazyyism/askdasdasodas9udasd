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
	local duration = abilityConfig.Duration or 5
	local radius = abilityConfig.RefillRadius or 5
	local amount = (abilityConfig.RefillAmount or 5) * multiplier
	local rate = abilityConfig.RefillRate or 0.5
	local sunPart = Instance.new("Part")
	sunPart.Name = "SolarFlareLogic"; sunPart.Transparency = 1; sunPart.CanCollide = false
	sunPart.Anchored = true; sunPart.Size = Vector3.new(1,1,1); sunPart.Position = position
	sunPart.Parent = workspace
	VFXReplication:FireAllClients("SolarFlare", player, fishIndex, sunPart, duration, vfxOverride)
	task.spawn(function()
		if abilityConfig.DamageTick == false then
			AbilityService.DealAbilityDamage(player, position, abilityConfig)
		end
		local elapsed = 0
		local lastDamageTick = 0
		local HarvestService = require(script.Parent.Parent.HarvestService)
		local TweenService = game:GetService("TweenService")
		local startPos = position
		while elapsed < duration do
			local dt = task.wait(rate); elapsed += dt
			if not sunPart or not sunPart.Parent then break end
			if not sunPart:GetAttribute("Moving") then
				if extraData and extraData.TargetPos then
					local target = Vector3.new(extraData.TargetPos.X, startPos.Y, extraData.TargetPos.Z)
					sunPart:SetAttribute("Moving", true)
					local moveTime = extraData.MoveTime or 1.0
					TweenService:Create(sunPart, TweenInfo.new(moveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = target}):Play()
					
					if not extraData.OutwardOnly then
						task.delay(moveTime, function() if sunPart and sunPart.Parent then sunPart:SetAttribute("Moving", false) end end)
					end
				else
					local centerPos = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position or startPos
					local target = Vector3.new(centerPos.X, startPos.Y, centerPos.Z)
					local dist = (target - sunPart.Position).Magnitude
					local moveTime = math.max(0.5, dist / 4)
					TweenService:Create(sunPart, TweenInfo.new(moveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = target}):Play()
					sunPart:SetAttribute("Moving", true)
					task.delay(moveTime, function() if sunPart and sunPart.Parent then sunPart:SetAttribute("Moving", false) end end)
				end
			end
			local visualRootPos = sunPart.Position + Vector3.new(0, 14, 0)
			local pPos = visualRootPos + Vector3.new(0, -14, 0)
			local overlapParams = BuildAlgaeOverlapParams()
			local toRefill = {}
			for _, part in ipairs(workspace:GetPartBoundsInRadius(pPos, radius, overlapParams)) do
				if part:IsA("BasePart") and part:FindFirstChild("Capacity") then table.insert(toRefill, part) end
			end
			if #toRefill > 0 then HarvestService.BatchedRefill(player, toRefill, amount) end
			if player.Character and player.Character.PrimaryPart then
				if (player.Character.PrimaryPart.Position - visualRootPos).Magnitude <= radius + 5 and abilityConfig.Buffs then
					for _, buffName in ipairs(abilityConfig.Buffs) do AbilityService.ApplyBuff(player, buffName) end
				end
			end
			if type(abilityConfig.DamageTick) == "number" then
				if elapsed - lastDamageTick >= abilityConfig.DamageTick then
					AbilityService.DealAbilityDamage(player, visualRootPos, abilityConfig)
					lastDamageTick = elapsed
				end
			end
		end
		if sunPart and sunPart.Parent then sunPart:Destroy() end
	end)
end


end
