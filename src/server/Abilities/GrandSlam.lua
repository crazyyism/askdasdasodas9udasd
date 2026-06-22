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
	if not extraData or type(extraData.Targets) ~= "table" then return end
	local HarvestService = require(script.Parent.Parent.HarvestService)
	local radius = 14
	local amount = 20 * multiplier
	local timing = extraData.Timing or 2
	
	task.spawn(function()
		local ResourceConfig = require(game:GetService("ReplicatedStorage").Shared.ResourceConfig)
		
		-- TargetPos gets parsed directly, wait syncs seamlessly with the client's jump duration
		local lastPos = position
		for i, targetPos in ipairs(extraData.Targets) do
			task.wait(timing)
			if not player or not player.Character or not player.Character.PrimaryPart then break end
			
			local dist = (targetPos - player.Character.PrimaryPart.Position).Magnitude
			if dist > 150 then -- Sanity check to prevent map-wide exploit (assume 150 studs max jump)
				warn("AbilityService: Grand Slam target out of bounds for " .. player.Name)
				break
			end
			
			local toHarvestPink = {}
			local toHarvestOther = {}
			
			print("[Grand Slam] Checking algae to harvest at targetPos: " .. tostring(targetPos) .. " within radius " .. tostring(radius))
			
			-- Robust 2D distance check ignoring heights (same robust logic as Shark Scythe)
			for fieldName, _ in pairs(ResourceConfig.Fields) do
				local f = workspace:FindFirstChild(fieldName)
				if f then
					for _, part in ipairs(f:GetChildren()) do
						if part:IsA("BasePart") then
							local cap = part:FindFirstChild("Capacity")
							local aa = part:FindFirstChild("AlgaeAmount")
							if cap and aa and cap.Value > 0 then
								local distXZ = Vector2.new(part.Position.X - targetPos.X, part.Position.Z - targetPos.Z).Magnitude
								if distXZ <= radius then
									if part.Name == "PinkAlgae" then
										table.insert(toHarvestPink, part)
									else
										table.insert(toHarvestOther, part)
									end
								end
							end
						end
					end
				end
			end
			
			-- Dynamic parsing for Bloat Passive (Blobfish only)
			local pinkAmount = amount
			local fishSchool = data and data.FishSchool or {}
			local fData = fishSchool[fishIndex] or fishSchool[tostring(fishIndex)]
			
			if fData then
				local FishConfig = require(game:GetService("ReplicatedStorage").Shared.FishConfig)
				local fCfg = FishConfig.Fish[fData.Id]
				
				if fCfg and fCfg.Passive == "Bloat" then
					local buffs = PlayerBuffs[player.UserId]
					if buffs and buffs.Bloated and (buffs.Bloated.Stacks or 0) > 0 then
						local stacks = buffs.Bloated.Stacks
						local bloatCfg = FishConfig.Passives["Bloat"]
						local pinkBoostPerStack = (bloatCfg and bloatCfg.PinkBoostPerStack) or 0.10
						local bloatMult = 1.0 + (stacks * pinkBoostPerStack)
						
						pinkAmount = math.floor(amount * bloatMult)
						print("[Grand Slam - Bloat Passive] Blobfish has " .. stacks .. "x Bloated! Pink Algae harvest boosted from " .. amount .. " to " .. pinkAmount)
					end
				end
			end
			
			if #toHarvestPink > 0 then
				HarvestService.HarvestBatch(player, toHarvestPink, pinkAmount, false, true)
			end
			if #toHarvestOther > 0 then
				HarvestService.HarvestBatch(player, toHarvestOther, amount, false, true)
			end
			
			if #toHarvestPink == 0 and #toHarvestOther == 0 then
				print("[Grand Slam] Warning: Slam landed but NO algae was near targetPos")
			end
			
			-- Check if player is standing in the visualizer radius to grant buffs
			if player and player.Character and player.Character.PrimaryPart then
				local playerPos = player.Character.PrimaryPart.Position
				local distToPlayer = Vector2.new(playerPos.X - targetPos.X, playerPos.Z - targetPos.Z).Magnitude
				if distToPlayer <= radius then
					AbilityService.ApplyBuff(player, "PinkAlgaeBoost")
					AbilityService.ApplyBuff(player, "Bloated")
					print("[Grand Slam] Player inside slam radius! Granted Pink Boost and Bloated.")
				end
			end
			AbilityService.DealAbilityDamage(player, targetPos, abilityConfig)
		end
	end)
end



end
