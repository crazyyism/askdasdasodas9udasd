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

	return function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
		local duration = abilityConfig.Duration or 7
		local moveSpeed = abilityConfig.MoveSpeed or 20
		local radius = abilityConfig.Radius or 4
		local harvestAmount = (abilityConfig.HarvestAmount or 3) * multiplier
		local tickRate = abilityConfig.TickRate or 0.1
		local hitCheckInterval = abilityConfig.HitCheckInterval or 0.3
		local ricochetVar = abilityConfig.RicochetAngleVariance or 45
		local HarvestService = require(script.Parent.Parent.HarvestService)
		
		-- Helper for ApplyToolBoost
		local function ApplyToolBoost(plr, cfg)
			if cfg and cfg.Buffs then
				for _, buffName in ipairs(cfg.Buffs) do AbilityService.ApplyBuff(plr, buffName) end
			end
		end

		if extraData and type(extraData) == "table" and #extraData > 1 then
			-- Path mode
			VFXReplication:FireAllClients("Bloodthirst", player, fishIndex, { Path = extraData, Duration = duration, Speed = moveSpeed, Override = vfxOverride })
			task.spawn(function()
				if abilityConfig.DamageTick == false then
					AbilityService.DealAbilityDamage(player, position, abilityConfig)
				end
				local path = extraData
				local lastPlayerHitTime = 0
				local lastDamageTick = os.clock()
				local overlapParams = BuildAlgaeOverlapParams()
				
				local maxAllowedDistance = (abilityConfig.MaxJumpDistance or 50) * multiplier
				local lastPos = path[1]
				
				for i = 1, #path - 1 do
					local p1, p2 = path[i], path[i+1]
					
					-- Security: Distance Validation!
					if (p2 - p1).Magnitude > maxAllowedDistance + 10 then
						warn("AbilityService: Bloodthirst target out of range for " .. player.Name)
						break
					end
					
					local segmentVec = (p2 - p1)
					local dist = segmentVec.Magnitude
					if dist < 0.1 then continue end
					local steps = math.ceil((dist / moveSpeed) / tickRate)
					local stepTime = (dist / moveSpeed) / steps
					for s = 1, steps do
						task.wait(stepTime)
						if not player or not player.Parent then return end
						local currentPos = p1 + segmentVec * (s / steps)
						local toHarvest = {}
						for _, p in ipairs(workspace:GetPartBoundsInRadius(currentPos, radius, overlapParams)) do
							if p:IsA("BasePart") then table.insert(toHarvest, p) end
						end
						if #toHarvest > 0 then HarvestService.HarvestMultipleBatched(player, toHarvest, harvestAmount, true) end
						if type(abilityConfig.DamageTick) == "number" then
							if os.clock() - lastDamageTick >= abilityConfig.DamageTick then
								AbilityService.DealAbilityDamage(player, currentPos, abilityConfig)
								lastDamageTick = os.clock()
							end
						end
						local now = os.clock()
						if now - lastPlayerHitTime > 1.0 and player.Character and player.Character.PrimaryPart then
							if (player.Character.PrimaryPart.Position - currentPos).Magnitude < (radius+2) then
								lastPlayerHitTime = now; ApplyToolBoost(player, abilityConfig)
							end
						end
					end
				end
			end)
		else
			-- Free-roam mode
			VFXReplication:FireAllClients("Bloodthirst", player, fishIndex, { StartPos = position, Duration = duration, Speed = moveSpeed, RicochetVariance = ricochetVar, Override = vfxOverride })
			task.spawn(function()
				if abilityConfig.DamageTick == false then
					AbilityService.DealAbilityDamage(player, position, abilityConfig)
				end
				local startTime = os.clock()
				local currentPos = position
				local currentDir = player.Character.PrimaryPart.CFrame.LookVector * Vector3.new(1,0,1)
				if currentDir.Magnitude < 0.1 then currentDir = Vector3.new(0,0,-1) end
				local lastHitCheck, lastPlayerHitTime = 0, 0
				local lastDamageTick = os.clock()
				local overlapParams = BuildAlgaeOverlapParams()
				while os.clock() - startTime < duration do
					local dt = task.wait(tickRate)
					if not player or not player.Parent then return end
					currentPos = currentPos + currentDir * (moveSpeed * dt)
					if type(abilityConfig.DamageTick) == "number" then
						if os.clock() - lastDamageTick >= abilityConfig.DamageTick then
							AbilityService.DealAbilityDamage(player, currentPos, abilityConfig)
							lastDamageTick = os.clock()
						end
					end
					if os.clock() - lastHitCheck > hitCheckInterval then
						lastHitCheck = os.clock()
						local toHarvest = {}
						for _, p in ipairs(workspace:GetPartBoundsInRadius(currentPos, radius, overlapParams)) do
							if p:IsA("BasePart") then table.insert(toHarvest, p) end
						end
						if #toHarvest > 0 then HarvestService.HarvestMultipleBatched(player, toHarvest, harvestAmount, true) end
					end
					if os.clock() - lastPlayerHitTime > 1.0 and player.Character and player.Character.PrimaryPart then
						if (player.Character.PrimaryPart.Position - currentPos).Magnitude < (radius + 2) then
							lastPlayerHitTime = os.clock(); ApplyToolBoost(player, abilityConfig)
						end
					end
				end
			end)
		end
	end
end
