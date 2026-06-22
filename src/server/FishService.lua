local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(script.Parent.PlayerData)

local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
local MobService = require(script.Parent.MobService)

local FishService = {}

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local DebugAddFishEvent = Remotes:FindFirstChild("DebugAddFishEvent")
if not DebugAddFishEvent then
	DebugAddFishEvent = Instance.new("RemoteEvent")
	DebugAddFishEvent.Name = "DebugAddFishEvent"
	DebugAddFishEvent.Parent = Remotes
end

local FishLeveledUpEvent = Remotes:FindFirstChild("FishLeveledUpEvent")
if not FishLeveledUpEvent then
	FishLeveledUpEvent = Instance.new("RemoteEvent")
	FishLeveledUpEvent.Name = "FishLeveledUpEvent"
	FishLeveledUpEvent.Parent = Remotes
end

-- XP Formula: 25 * (3 ^ (Level - 1))
local function GetXPForNextLevel(currentLevel)
	return math.floor(25 * math.pow(3, currentLevel - 1))
end

function FishService.AddXPToData(data, fishIndex, amount, player)
	if not data.FishSchool then return end
	
	-- Handle potential string/number index mismatch
	local schoolIndex = tostring(fishIndex)
	local fishData = data.FishSchool[schoolIndex]
	
	if not fishData then return end
	
	fishData.Exp = (fishData.Exp or 0) + amount
	if not fishData.Level then fishData.Level = 1 end
	
	local req = GetXPForNextLevel(fishData.Level)
	
	local leveledUp = false
	-- Level Up Loop
	while fishData.Exp >= req do
		fishData.Exp = fishData.Exp - req
		fishData.Level = fishData.Level + 1
		leveledUp = true
		req = GetXPForNextLevel(fishData.Level)
	end
	
	if leveledUp then
		data._FishDirty = true
		if player then
			FishLeveledUpEvent:FireClient(player, fishData.Name or fishData.Id, fishData.Level)
		end
	end
	
	return leveledUp
end

function FishService.AddXP(player, fishIndex, amount)
	local leveledUp = false
	
	PlayerData.update(player, function(data)
		leveledUp = FishService.AddXPToData(data, fishIndex, amount, player)
		return data
	end)
end

function FishService.Start()
    DebugAddFishEvent.OnServerEvent:Connect(function(player, count)
        local amount = tonumber(count) or 0
        if amount == 0 then return end
        
        -- Cap requests
        if amount > 100 then amount = 100 end 
        if amount < -100 then amount = -100 end

        if amount < -100 then amount = -100 end


        PlayerData.update(player, function(data)
            if not data.FishSchool then data.FishSchool = {} end
            
            if amount > 0 then
                -- ADD
                for i = 1, amount do
                    -- Find next slot
                    local nextSlot = 1
                    while data.FishSchool[tostring(nextSlot)] do
                        nextSlot += 1
                    end
                    
                    data.FishSchool[tostring(nextSlot)] = {
                        Id = "Basic Fish",
                        Name = "Basic Fish",
                        Level = 1,
                        Exp = 0,
						UniqueId = game:GetService("HttpService"):GenerateGUID(false)
                    }
                end
            else
                -- REMOVE
                local removeCount = math.abs(amount)
                for i = 1, removeCount do
                     -- Find any slot to remove
                     local keyToRemove = nil
                     for k, _ in pairs(data.FishSchool) do
                        keyToRemove = k
                        break
                     end
                     if keyToRemove then
                        data.FishSchool[keyToRemove] = nil
                     end
                end
            end
			data._FishDirty = true
            return data
        end)
    end)

	local EvictFishEvent = Remotes:FindFirstChild("EvictFishEvent")
	if not EvictFishEvent then
		EvictFishEvent = Instance.new("RemoteEvent")
		EvictFishEvent.Name = "EvictFishEvent"
		EvictFishEvent.Parent = Remotes
	end
	
	EvictFishEvent.OnServerEvent:Connect(function(player, fishIndex)
		PlayerData.update(player, function(data)
			if data.FishSchool and data.FishSchool[tostring(fishIndex)] then
				data.FishSchool[tostring(fishIndex)] = nil
				data._FishDirty = true
			end
			return data
		end)
	end)
	
	local FishStateRelay = Remotes:FindFirstChild("FishStateRelay")
	if not FishStateRelay then
		FishStateRelay = Instance.new("RemoteEvent")
		FishStateRelay.Name = "FishStateRelay"
		FishStateRelay.Parent = Remotes
	end
	
	local playerFishStates = {}
	FishStateRelay.OnServerEvent:Connect(function(player, stateData)
		playerFishStates[player.UserId] = stateData
		-- Relay to all OTHER clients
		-- stateData: {[FishIndex] = {State="Moving", Target=Vector3, ...}}
		-- for _, other in ipairs(game:GetService("Players"):GetPlayers()) do
		-- 	if other ~= player then
		-- 		FishStateRelay:FireClient(other, player.UserId, stateData)
		-- 	end
		-- end
	end)
	
	-- Fish DPS Loop (Server-side)
	local fishCooldowns = {}
	local playerLastTargets = {}
	local lastDpsTick = os.clock()
	game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastDpsTick >= 0.05 then -- High tick rate for varied attack speeds
			lastDpsTick = now
			
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if not root then continue end
				
				-- Check for nearby mobs
				local targetMob = nil
				local shortestDist = 20
				
				-- First, look for any mobs actively chasing this player
				local chasingMobs = {}
				for _, mobData in ipairs(MobService.GetMobs()) do
					if mobData.Mob and mobData.Mob.PrimaryPart and mobData.State == "Chasing" and mobData.Target == player then
						table.insert(chasingMobs, mobData)
					end
				end
				
				if #chasingMobs > 0 then
					local closestChasingMob = nil
					local closestChasingDist = math.huge
					for _, mobData in ipairs(chasingMobs) do
						local dist = (mobData.Mob.PrimaryPart.Position - root.Position).Magnitude
						if dist < closestChasingDist then
							closestChasingDist = dist
							closestChasingMob = mobData.Mob
						end
					end
					targetMob = closestChasingMob
				else
					-- Fallback to default proximity check (closest within 20 studs)
					for _, mobData in ipairs(MobService.GetMobs()) do
						if mobData.Mob and mobData.Mob.PrimaryPart then
							local dist = (mobData.Mob.PrimaryPart.Position - root.Position).Magnitude
							if dist < shortestDist then
								shortestDist = dist
								targetMob = mobData.Mob
							end
						end
					end
				end
				
				if targetMob then
					-- Calculate per-fish DPS with level difference miss chance
					local data = PlayerData.get(player)
					if data and data.FishSchool then
						local playerAttack = (data.Stats and data.Stats.Attack) or 1
						local playerFishAttack = (data.Stats and data.Stats.FishAttack) or 0
						
						local mobLevel = targetMob:FindFirstChild("Level") and targetMob.Level.Value or 1
						local anyFishAttacked = false
						
						local userId = player.UserId
						if not fishCooldowns[userId] then fishCooldowns[userId] = {} end
						local pCooldowns = fishCooldowns[userId]
						
						for index, fishData in pairs(data.FishSchool) do
							if not targetMob or not targetMob.Parent or not targetMob.PrimaryPart then
								break
							end
							if type(fishData) == "table" and fishData.Id then
								local fConfig = FishConfig.Fish[fishData.Id]
								if fConfig and fConfig.BaseStats and fConfig.BaseStats.Attack then
									local atkSpeed = fConfig.BaseStats.AttackSpeed or 1.0
									local nextAttack = pCooldowns[index] or 0
									
									if now >= nextAttack then
										local canAttack = false
										local pState = playerFishStates[userId]
										local fState = pState and pState[tostring(index)]
										if fState and fState.CF then
											local fPos = fState.CF.Position
											local dist = (targetMob.PrimaryPart.Position - fPos).Magnitude
											local orbitRadius = 8 + (math.sqrt(tonumber(index) or 1) * 1.5)
											if dist <= orbitRadius + 5 then
												canAttack = true
											end
										end
										
										if canAttack then
											pCooldowns[index] = now + (1.0 / atkSpeed)
											anyFishAttacked = true
									local fishBaseAttack = fConfig.BaseStats.Attack
									local fishLevel = fishData.Level or 1
									
									local levelDiff = mobLevel - fishLevel
									local missChance = 0
									if levelDiff > 0 then
										missChance = 1 - math.pow(0.5, levelDiff)
									end
									
									if math.random() < missChance then
										MobService.DamageMob(targetMob, 0, false, true, player)
									else
										local rawDamage = (fishBaseAttack + playerFishAttack) * playerAttack
										
										local critChance = (data.Stats and data.Stats.CriticalChance) or 0.01
										local critPower = (data.Stats and data.Stats.CriticalPower) or 3.0
										local megaCritChance = (data.Stats and data.Stats.MegaCritChance) or 0
										local megaCritPower = (data.Stats and data.Stats.MegaCritPower) or 10.0
										
										local isCrit = false
										if math.random() <= megaCritChance then
											isCrit = true
											rawDamage = rawDamage * megaCritPower
										elseif math.random() <= critChance then
											isCrit = true
											rawDamage = rawDamage * critPower
										end
										
										MobService.DamageMob(targetMob, rawDamage, isCrit, false, player)
										end
									end
									end
								end
							end
						end
						
						-- Cleanup cooldowns for missing fish
						for idx, _ in pairs(pCooldowns) do
							if not data.FishSchool[idx] then
								pCooldowns[idx] = nil
							end
						end
						
						if playerLastTargets[userId] ~= targetMob then
							playerLastTargets[userId] = targetMob
							if FishStateRelay then
								FishStateRelay:FireClient(player, {OrbitTarget = targetMob})
							end
						end
					end
				else
					-- Tell client to stop orbiting
					local data = PlayerData.get(player)
					if data and data.FishSchool then
						if playerLastTargets[player.UserId] ~= nil then
							playerLastTargets[player.UserId] = nil
							if FishStateRelay then
								FishStateRelay:FireClient(player, {OrbitTarget = nil})
							end
						end
					end
				end
			end
		end
	end)
end

return FishService
