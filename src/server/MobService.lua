local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(script.Parent.PlayerData)
local MobConfig = require(ReplicatedStorage.Shared.MobConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)

local MobService = {}

local function getFieldFolder(fieldName)
	if not fieldName then return nil end
	local folder = workspace:FindFirstChild(fieldName)
	if folder then return folder end
	
	local cleanName = string.lower(fieldName):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
	for _, child in ipairs(workspace:GetChildren()) do
		local childClean = string.lower(child.Name):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
		if childClean == cleanName then
			return child
		end
	end
	return nil
end

local reefAABBs = {}

local function getFolderAABB(folder)
	local minX, maxX = math.huge, -math.huge
	local minY, maxY = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	local hasParts = false
	
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			local pos = child.Position
			local size = child.Size
			
			local halfX = size.X / 2
			local halfY = size.Y / 2
			local halfZ = size.Z / 2
			
			minX = math.min(minX, pos.X - halfX)
			maxX = math.max(maxX, pos.X + halfX)
			minY = math.min(minY, pos.Y - halfY)
			maxY = math.max(maxY, pos.Y + halfY)
			minZ = math.min(minZ, pos.Z - halfZ)
			maxZ = math.max(maxZ, pos.Z + halfZ)
			hasParts = true
		end
	end
	
	if hasParts then
		return {
			Min = Vector3.new(minX, minY, minZ),
			Max = Vector3.new(maxX, maxY, maxZ)
		}
	end
	return nil
end

local function getReefAABB(reefName)
	if reefAABBs[reefName] then return reefAABBs[reefName] end
	local folder = getFieldFolder(reefName)
	if folder then
		local aabb = getFolderAABB(folder)
		if aabb then
			reefAABBs[reefName] = aabb
			return aabb
		end
	end
	return nil
end

local function isPositionInAABB(pos, aabb)
	if not aabb then return false end
	local marginX = 25
	local marginZ = 25
	local marginY = 30
	
	return pos.X >= (aabb.Min.X - marginX) and pos.X <= (aabb.Max.X + marginX)
		and pos.Z >= (aabb.Min.Z - marginZ) and pos.Z <= (aabb.Max.Z + marginZ)
		and pos.Y >= (aabb.Min.Y - 10) and pos.Y <= (aabb.Max.Y + marginY)
end

local function isPlayerInReef(player, reefName, spawnPos, leashRange)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")
	if not root or not hum or hum.Health <= 0 then return false end
	
	if spawnPos and leashRange then
		local dist = (root.Position - spawnPos).Magnitude
		if dist <= leashRange then
			return true
		end
	end
	
	local aabb = getReefAABB(reefName)
	if not aabb then return false end
	
	return isPositionInAABB(root.Position, aabb)
end

local activeMobs = {} -- {Mob = Model, SpawnPos = Vector3, State = "Idle", Target = Player, NextAttack = time, Health = IntValue, Damage = IntValue}

local DamageVisualEvent = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("DamageVisualEvent")
if not DamageVisualEvent then
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		DamageVisualEvent = Instance.new("RemoteEvent")
		DamageVisualEvent.Name = "DamageVisualEvent"
		DamageVisualEvent.Parent = remotes
	end
end

local function ShowDamageNumber(part, amount, isCrit, isMiss, player)
	if DamageVisualEvent then
		if player then
			DamageVisualEvent:FireClient(player, part.Position, amount, isCrit, isMiss)
		else
			DamageVisualEvent:FireAllClients(part.Position, amount, isCrit, isMiss)
		end
	end
end

function MobService.GetAverageFishLevel(player)
	local data = PlayerData.get(player)
	if not data or not data.FishSchool then return 1 end
	
	local totalLevel = 0
	local count = 0
	for _, f in pairs(data.FishSchool) do
		if type(f) == "table" and f.Level then
			totalLevel = totalLevel + f.Level
			count = count + 1
		end
	end
	
	return count > 0 and math.floor(totalLevel / count) or 1
end

function MobService.DamageMob(mobModel, amount, isCrit, isMiss, player)
	if not mobModel or not mobModel.Parent then return end
	local root = mobModel.PrimaryPart or mobModel:FindFirstChild("HumanoidRootPart")
	
	if isMiss then
		if root then ShowDamageNumber(root, 0, false, true, player) end
		return
	end
	
	local health = mobModel:FindFirstChild("Health")
	local maxHealth = mobModel:FindFirstChild("MaxHealth")
	if not health then return end
	
	health.Value = math.max(0, health.Value - amount)
	
	if root then
		ShowDamageNumber(root, amount, isCrit, false, player)
		
		-- Update UI
		local titleUI = root:FindFirstChild("TitleUI")
		if titleUI and maxHealth then
			local healthFrame = titleUI:FindFirstChild("Health")
			if healthFrame then
				local bar = healthFrame:FindFirstChild("HealthBar")
				local amtText = healthFrame:FindFirstChild("HealthAmount")
				if bar then
					local origScaleX = bar:GetAttribute("OrigScaleX") or 1
					local origOffsetX = bar:GetAttribute("OrigOffsetX") or 0
					local origScaleY = bar:GetAttribute("OrigScaleY") or 1
					local origOffsetY = bar:GetAttribute("OrigOffsetY") or 0
					local pct = math.clamp(health.Value / maxHealth.Value, 0, 1)
					bar.Size = UDim2.new(origScaleX * pct, origOffsetX * pct, origScaleY, origOffsetY)
					bar.BackgroundColor3 = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), pct)
				end
				if amtText then
					amtText.Text = tostring(math.floor(health.Value)) .. "/" .. tostring(math.floor(maxHealth.Value))
				end
			end
		end
	end
	if health.Value <= 0 then
		-- Kill mob
		for i, data in ipairs(activeMobs) do
			if data.Mob == mobModel then
				if data.AttackIndicator then
					data.AttackIndicator:Destroy()
				end
				table.remove(activeMobs, i)
				break
			end
		end
		
		-- Drop logic
		local reefName = mobModel:GetAttribute("ReefName")
		local configId = mobModel:GetAttribute("ReefConfigId")
		local spawnPartName = mobModel:GetAttribute("SpawnPartName")
		
		if root then
			local mobType = mobModel:GetAttribute("MobType") or mobModel.Name
			local mobConfig = MobConfig.MobTypes[mobType]
			local drops = nil
			
			local Shared = ReplicatedStorage:FindFirstChild("Shared")
			if Shared and Shared:FindFirstChild("MobSpawnConfig") then
				local MobSpawnConfig = require(Shared.MobSpawnConfig)
				local config = reefName and configId and MobSpawnConfig.Reefs[reefName] and MobSpawnConfig.Reefs[reefName][configId]
				drops = (config and config.Drops) or (mobConfig and mobConfig.Drops)
			else
				drops = mobConfig and mobConfig.Drops
			end
			
			if drops and player then
				-- 1. Gather all direct rewards to grant
				local mobLevel = mobModel:FindFirstChild("Level") and mobModel.Level.Value or 1
				local rewardMultiplier = math.pow(1.3, mobLevel - 1)
				
				local grantedRewards = {}
				local totalSparkles = 0
				
				for _, drop in ipairs(drops) do
					if math.random() <= (drop.Chance or 1) then
						if drop.Type == "Token" then
							local minAmount = drop.MinAmount or drop.Amount or 1
							local maxAmount = drop.MaxAmount or drop.Amount or 1
							local chosenAmount = math.random(minAmount, maxAmount)
							local finalAmount = math.floor(chosenAmount * rewardMultiplier)
							
							if finalAmount > 0 then
								table.insert(grantedRewards, {
									Name = drop.Name,
									Amount = finalAmount
								})
								if drop.Name == "Biomass" then
									totalSparkles = totalSparkles + 6
								else
									totalSparkles = totalSparkles + math.clamp(finalAmount, 1, 5)
								end
							end
						end
					end
				end
				
				totalSparkles = math.clamp(totalSparkles, 5, 20)
				
				-- 2. Grant rewards directly to PlayerData
				PlayerData.update(player, function(data)
					for _, reward in ipairs(grantedRewards) do
						if reward.Name == "Biomass" then
							data.Biomass = (data.Biomass or 0) + reward.Amount
							data.LifetimeBiomass = (data.LifetimeBiomass or 0) + reward.Amount
						else
							if type(data.Inventory) ~= "table" then data.Inventory = {} end
							data.Inventory[reward.Name] = (data.Inventory[reward.Name] or 0) + reward.Amount
							data._InventoryDirty = true
						end
					end
					return data
				end)
				
				-- 3. Fire UI alerts and notifications back to the player
				for _, reward in ipairs(grantedRewards) do
					if reward.Name == "Biomass" then
						local ls = player:FindFirstChild("leaderstats")
						if ls and ls:FindFirstChild("Biomass") then
							local pData = PlayerData.get(player)
							ls.Biomass.Value = pData.Biomass or 0
						end
						local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
						if NotificationEvent then
							NotificationEvent:FireClient(player, "+" .. reward.Amount .. " Biomass", Color3.fromRGB(0, 255, 255))
						end
					else
						local ItemAddedEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ItemAddedEvent")
						if ItemAddedEvent then
							ItemAddedEvent:FireClient(player, reward.Name, reward.Amount, "Item", 0, 0)
						end
					end
				end
				
				-- 4. Trigger client-side sparkle effects
				local VFXReplication = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("VFXReplication")
				if VFXReplication then
					VFXReplication:FireClient(player, "MobCollectSparkle", player, nil, root.Position, totalSparkles)
				end
			end
			
			local reefFolder = getFieldFolder(reefName)
			if reefFolder and spawnPartName then
				local spawnPart = reefFolder:FindFirstChild(spawnPartName, true)
				if spawnPart then
					spawnPart:SetAttribute("LastDeathTime", os.time())
				end
			end
		end
		
		-- Simple death effect
		if root then
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CFrame = root.CFrame
			p.Size = Vector3.new(4,4,4)
			p.Color = Color3.new(1, 0, 0)
			p.Material = Enum.Material.Neon
			p.Parent = workspace
			
			local TweenService = game:GetService("TweenService")
			TweenService:Create(p, TweenInfo.new(0.5), {Size = Vector3.new(0,0,0), Transparency = 1}):Play()
			Debris:AddItem(p, 0.5)
		end
		
		mobModel:Destroy()
	end
end

-- Create a basic placeholder mob if no template is provided
local function CreatePlaceholderMob(healthAmount, levelAmount, damageAmount)
	local model = Instance.new("Model")
	model.Name = "EnemyMob"
	
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2)
	root.Color = Color3.new(1, 0.2, 0.2)
	root.CanCollide = true
	root.Parent = model
	
	model.PrimaryPart = root
	
	local hum = Instance.new("Humanoid")
	hum.Parent = model
	
	local health = Instance.new("NumberValue")
	health.Name = "Health"
	health.Value = healthAmount or 100
	health.Parent = model
	
	local damage = Instance.new("NumberValue")
	damage.Name = "Damage"
	damage.Value = damageAmount or 10
	damage.Parent = model
	
	local maxHealth = Instance.new("NumberValue")
	maxHealth.Name = "MaxHealth"
	maxHealth.Value = healthAmount or 100
	maxHealth.Parent = model
	
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = levelAmount or 1
	level.Parent = model
	
	return model
end

function MobService.SpawnMob(spawnCFrame, healthAmount, levelAmount, template, damageAmount, mobName, mobConfig)
	local mob = template and template:Clone() or CreatePlaceholderMob(healthAmount, levelAmount, damageAmount)
	if mobName then
		mob.Name = mobName
	end
	
	-- Ensure Health, MaxHealth, Level, and Damage value objects are initialized
	local health = mob:FindFirstChild("Health")
	if not health then
		health = Instance.new("NumberValue")
		health.Name = "Health"
		health.Parent = mob
	end
	health.Value = healthAmount or 50
	
	local maxHealth = mob:FindFirstChild("MaxHealth")
	if not maxHealth then
		maxHealth = Instance.new("NumberValue")
		maxHealth.Name = "MaxHealth"
		maxHealth.Parent = mob
	end
	maxHealth.Value = healthAmount or 50
	
	local level = mob:FindFirstChild("Level")
	if not level then
		level = Instance.new("IntValue")
		level.Name = "Level"
		level.Parent = mob
	end
	level.Value = levelAmount or 1
	
	local damageVal = mob:FindFirstChild("Damage")
	if not damageVal then
		damageVal = Instance.new("NumberValue")
		damageVal.Name = "Damage"
		damageVal.Parent = mob
	end
	damageVal.Value = damageAmount or 10

	-- Ensure a HumanoidRootPart exists for the Humanoid to stand on
	local hrp = mob:FindFirstChild("HumanoidRootPart")
	if not hrp then
		local rootPart = mob:FindFirstChild("Root")
		if rootPart then
			hrp = Instance.new("Part")
			hrp.Name = "HumanoidRootPart"
			hrp.Size = Vector3.new(2, 2, 2)
			hrp.CFrame = rootPart.CFrame
			hrp.Transparency = 1
			hrp.CanCollide = true
			hrp.Parent = mob
			
			-- Weld Root to HumanoidRootPart
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hrp
			weld.Part1 = rootPart
			weld.Parent = hrp
		end
	end
	
	if hrp then
		mob.PrimaryPart = hrp
	else
		local rootPart = mob:FindFirstChild("Root") or mob:FindFirstChildOfClass("BasePart")
		if rootPart then
			mob.PrimaryPart = rootPart
		else
			warn("MobService: Spawned mob model '" .. mob.Name .. "' has no PrimaryPart and no BaseParts!")
			mob:Destroy()
			return nil
		end
	end
	
	mob:SetPrimaryPartCFrame(spawnCFrame)
	mob.Parent = workspace
	
	-- Force CanCollide = false on all parts EXCEPT HumanoidRootPart so that HipHeight standing operates correctly
	for _, part in ipairs(mob:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = false
		end
	end
	-- Attach Health UI
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	if vfxFolder and mob.PrimaryPart then
		local mobHealthFolder = vfxFolder:FindFirstChild("MobHealth")
		if mobHealthFolder then
			local titleUITemplate = mobHealthFolder:FindFirstChild("TitleUI")
			if titleUITemplate then
				local titleUI = titleUITemplate:Clone()
				titleUI.Parent = mob.PrimaryPart
				
				local hFrame = titleUI:FindFirstChild("Health")
				if hFrame then
					local bar = hFrame:FindFirstChild("HealthBar")
					if bar then
						bar:SetAttribute("OrigScaleX", bar.Size.X.Scale)
						bar:SetAttribute("OrigOffsetX", bar.Size.X.Offset)
						bar:SetAttribute("OrigScaleY", bar.Size.Y.Scale)
						bar:SetAttribute("OrigOffsetY", bar.Size.Y.Offset)
						
						local origPos = bar.Position
						local origSizeX = bar.Size.X
						local origAnchorX = bar.AnchorPoint.X
						
						local rightScale = origPos.X.Scale + origSizeX.Scale * (1 - origAnchorX)
						local rightOffset = origPos.X.Offset + origSizeX.Offset * (1 - origAnchorX)
						
						bar.AnchorPoint = Vector2.new(1, bar.AnchorPoint.Y)
						bar.Position = UDim2.new(rightScale, rightOffset, origPos.Y.Scale, origPos.Y.Offset)
						bar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
					end
					
					local amtText = hFrame:FindFirstChild("HealthAmount")
					local lvlText = hFrame:FindFirstChild("Level")
					if amtText and maxHealth and health then
						amtText.Text = tostring(math.floor(health.Value)) .. "/" .. tostring(math.floor(maxHealth.Value))
					end
					if lvlText and level then
						lvlText.Text = "Lv. " .. tostring(level.Value)
					end
				end
			end
		end
	end
	
	local hum = mob:FindFirstChildOfClass("Humanoid")
	if not hum then
		hum = Instance.new("Humanoid")
		hum.Parent = mob
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	
	hum.RigType = Enum.HumanoidRigType.R15
	hum.WalkSpeed = mobConfig and mobConfig.WalkSpeed or 8
	if mobConfig and mobConfig.HipHeight then
		hum.HipHeight = mobConfig.HipHeight
	end

	-- Auto-weld parts to the PrimaryPart if they aren't already welded or jointed
	if mob.PrimaryPart then
		local hasJoints = false
		for _, desc in ipairs(mob:GetDescendants()) do
			if desc:IsA("Weld") or desc:IsA("WeldConstraint") or desc:IsA("Motor6D") or desc:IsA("ManualWeld") then
				hasJoints = true
				break
			end
		end
		
		if not hasJoints then
			for _, part in ipairs(mob:GetDescendants()) do
				if part:IsA("BasePart") and part ~= mob.PrimaryPart then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = mob.PrimaryPart
					weld.Part1 = part
					weld.Parent = mob.PrimaryPart
				end
			end
		end
	end

	local walkTrack = nil
	local idleTrack = nil
	if hum then
		local walkAnim = mob:FindFirstChild("Walk")
		local idleAnim = mob:FindFirstChild("Idle")
		if walkAnim or idleAnim then
			local animator = hum:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = hum
			end
			if walkAnim then
				walkTrack = animator:LoadAnimation(walkAnim)
				walkTrack.Looped = true
			end
			if idleAnim then
				idleTrack = animator:LoadAnimation(idleAnim)
				idleTrack.Looped = true
			end
		end
	end

	table.insert(activeMobs, {
		Mob = mob,
		SpawnPos = spawnCFrame.Position,
		State = "Idle",
		Target = nil,
		LastWanderTime = 0,
		LastDamageTime = 0,
		WanderInterval = 0,
		LastHopTime = 0,
		Health = mob:FindFirstChild("Health"),
		Damage = mob:FindFirstChild("Damage"),
		Config = mobConfig,
		WalkTrack = walkTrack,
		IdleTrack = idleTrack
	})
	
	mob:SetAttribute("MobType", mobName)
	
	return mob
end

function MobService.GetMobs()
	return activeMobs
end

function MobService.Start()
	-- Server loop for mob AI
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, data in ipairs(activeMobs) do
			local mob = data.Mob
			if not mob or not mob.Parent then continue end
			local root = mob.PrimaryPart or mob:FindFirstChild("HumanoidRootPart")
			local hum = mob:FindFirstChild("Humanoid")
			if not root or not hum then continue end
			
			-- Update animations based on movement velocity
			local walkTrack = data.WalkTrack
			local idleTrack = data.IdleTrack
			if walkTrack or idleTrack then
				local speed = root.AssemblyLinearVelocity.Magnitude
				if speed > 0.5 then
					if idleTrack and idleTrack.IsPlaying then
						idleTrack:Stop(0.2)
					end
					if walkTrack and not walkTrack.IsPlaying then
						walkTrack:Play(0.2)
					end
				else
					if walkTrack and walkTrack.IsPlaying then
						walkTrack:Stop(0.2)
					end
					if idleTrack and not idleTrack.IsPlaying then
						idleTrack:Play(0.2)
					end
				end
			end
			
			local cfg = data.Config or {}
			local walkSpeed = cfg.WalkSpeed or 8
			local chaseSpeed = cfg.ChaseSpeed or 14
			local returnSpeed = cfg.ReturnSpeed or 12
			local wanderRadius = cfg.WanderRadius or 15
			local aggroRange = cfg.AggroRange or 35
			local leashRange = cfg.LeashRange or 45
			local contactRange = cfg.ContactRange or 5
			local damageCooldown = cfg.DamageCooldown or 0.8
			local hopInterval = cfg.HopInterval
			
			-- Frog Hopping: make Frogs jump periodically to simulate hopping movement
			if hopInterval then
				if now - (data.LastHopTime or 0) > hopInterval then
					data.LastHopTime = now
					hum.Jump = true
				end
			end
			
			local state = data.State
			
			if state == "Idle" or state == "Returning" then
				-- Look for nearest player within aggroRange or inside the reef
				local nearestPlayer = nil
				local shortestDist = math.huge
				local reefName = mob:GetAttribute("ReefName")
				
				for _, p in ipairs(Players:GetPlayers()) do
					local char = p.Character
					local pRoot = char and char:FindFirstChild("HumanoidRootPart")
					local pHum = char and char:FindFirstChild("Humanoid")
					if pRoot and pHum and pHum.Health > 0 then
						local dist = (pRoot.Position - root.Position).Magnitude
						
						if reefName then
							-- Aggro if player is inside the same reef
							if isPlayerInReef(p, reefName, data.SpawnPos, leashRange) then
								if dist < shortestDist then
									shortestDist = dist
									nearestPlayer = p
								end
							end
						else
							-- Fallback: aggro if within standard aggroRange
							if dist < aggroRange then
								if dist < shortestDist then
									shortestDist = dist
									nearestPlayer = p
								end
							end
						end
					end
				end
				
				if nearestPlayer then
					data.Target = nearestPlayer
					data.Mob:SetAttribute("TargetingPlayer", true)
					data.State = "Chasing"
					hum.WalkSpeed = chaseSpeed
				elseif state == "Returning" then
					-- If in Returning state and no player, check if we arrived at spawn
					local dist = (root.Position - data.SpawnPos).Magnitude
					if dist < 2 then
						data.State = "Idle"
						hum.WalkSpeed = walkSpeed
						data.LastWanderTime = 0 -- wander immediately
						data.WanderInterval = 0
					else
						hum.WalkSpeed = returnSpeed
						hum:MoveTo(data.SpawnPos)
					end
				elseif state == "Idle" then
					-- Check if any player is within leashRange of the spawn point
					local playerNearby = false
					for _, p in ipairs(Players:GetPlayers()) do
						local char = p.Character
						local pRoot = char and char:FindFirstChild("HumanoidRootPart")
						if pRoot then
							local distToSpawn = (pRoot.Position - data.SpawnPos).Magnitude
							if distToSpawn <= leashRange then
								playerNearby = true
								break
							end
						end
					end
					
					if playerNearby then
						-- Idle wandering
						if now - (data.LastWanderTime or 0) > (data.WanderInterval or 0) then
							data.LastWanderTime = now
							data.WanderInterval = math.random(3, 6)
							hum.WalkSpeed = walkSpeed
							
							local offset = Vector3.new(math.random(-wanderRadius, wanderRadius), 0, math.random(-wanderRadius, wanderRadius))
							local targetPos = data.SpawnPos + offset
							hum:MoveTo(targetPos)
						end
					else
						-- No player nearby, stand still at its spawn position
						local dist = (root.Position - data.SpawnPos).Magnitude
						if dist > 2 then
							hum.WalkSpeed = returnSpeed
							hum:MoveTo(data.SpawnPos)
						else
							hum:MoveTo(root.Position)
						end
					end
				end
				
			elseif state == "Chasing" then
				local target = data.Target
				local targetChar = target and target.Character
				local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
				local targetHum = targetChar and targetChar:FindFirstChild("Humanoid")
				
				if targetRoot and targetHum and targetHum.Health > 0 then
					local targetPos = targetRoot.Position
					local distToSpawn = (root.Position - data.SpawnPos).Magnitude
					local distToPlayer = (root.Position - targetPos).Magnitude
					
					local reefName = mob:GetAttribute("ReefName")
					local shouldDeaggro = false
					if reefName then
						shouldDeaggro = not isPlayerInReef(target, reefName, data.SpawnPos, leashRange)
					else
						shouldDeaggro = (distToSpawn > leashRange)
					end
					
					-- If player leaves reef/range, target becomes invalid
					if shouldDeaggro then
						data.State = "Returning"
						data.Target = nil
						data.Mob:SetAttribute("TargetingPlayer", nil)
						hum.WalkSpeed = returnSpeed
						hum:MoveTo(data.SpawnPos)
					else
						-- Keep chasing the player
						hum.WalkSpeed = chaseSpeed
						hum:MoveTo(targetPos)
						
						-- Contact damage check: deal damage to player on touch/proximity
						if distToPlayer <= contactRange then
							if now - (data.LastDamageTime or 0) >= damageCooldown then
								data.LastDamageTime = now
								local dmg = data.Damage and data.Damage.Value or (cfg.Damage or 10)
								targetHum:TakeDamage(dmg)
							end
						end
					end
				else
					-- Target lost or dead
					data.State = "Returning"
					data.Target = nil
					data.Mob:SetAttribute("TargetingPlayer", nil)
					hum.WalkSpeed = returnSpeed
					hum:MoveTo(data.SpawnPos)
				end
			end
		end
	end)
	
	-- Command to spawn a test mob (e.g. /spawnmob Frog 1)
	Players.PlayerAdded:Connect(function(p)
		p.Chatted:Connect(function(msg)
			if msg:sub(1, 9) == "/spawnmob" then
				local args = string.split(msg, " ")
				local query = args[2] or "Frog"
				local levelAmount = tonumber(args[3]) or 1
				
				local mobType = nil
				local mobConfig = nil
				for key, cfg in pairs(MobConfig.MobTypes) do
					if string.lower(key) == string.lower(query) then
						mobType = key
						mobConfig = cfg
						break
					end
				end
				
				if not mobType then
					mobType = string.upper(query:sub(1,1)) .. string.lower(query:sub(2))
					mobConfig = MobConfig.MobTypes[mobType]
				end
				
				local health = mobConfig and mobConfig.Health or 50
				local damage = mobConfig and mobConfig.Damage or 10
				
				if p.Character and p.Character.PrimaryPart then
					local cf = p.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -10)
					local templateFolder = ReplicatedStorage:FindFirstChild("Mobs")
					
					local template = nil
					if templateFolder then
						for _, child in ipairs(templateFolder:GetChildren()) do
							if string.lower(child.Name) == string.lower(mobType) then
								template = child
								break
							end
						end
					end
					
					MobService.SpawnMob(cf, health, levelAmount, template, damage, mobType, mobConfig)
					print("Spawned test mob " .. mobType .. " with " .. health .. " HP and Level " .. levelAmount)
				end
			end
		end)
	end)
	
	-- Start Spawner Loop
	task.spawn(function()
		local function getStandardMobType(partName)
			-- Format 1: [MobType]Spawn (e.g. FrogSpawn)
			local rawType = partName:match("^([%a%d%s]+)[Ss]pawn")
			if not rawType then
				-- Format 2: Spawn[MobType] (e.g. spawnfrog)
				rawType = partName:match("^[Ss]pawn([%a%d%s]+)")
			end
			if not rawType then return nil end
			
			local cleanType = rawType:gsub("^%s*", ""):gsub("%s*$", "")
			if #cleanType == 0 then return nil end
			
			local capitalized = string.upper(cleanType:sub(1,1)) .. string.lower(cleanType:sub(2))
			return capitalized
		end

		local Shared = ReplicatedStorage:FindFirstChild("Shared")
		if Shared and Shared:FindFirstChild("MobSpawnConfig") then
			local MobSpawnConfig = require(Shared.MobSpawnConfig)
			
			local activeSpawns = {}
			while task.wait(2) do
				for reefName, _ in pairs(ResourceConfig.Fields) do
					local reefFolder = getFieldFolder(reefName)
					if reefFolder then
						local configs = MobSpawnConfig.Reefs[reefName] or {}
						for _, child in ipairs(reefFolder:GetDescendants()) do
							local mobType = getStandardMobType(child.Name)
							if mobType then
								local spawnPart = child
								local existingMob = activeSpawns[spawnPart]
								
								if not existingMob or not existingMob.Parent or not existingMob:FindFirstChild("Health") or existingMob.Health.Value <= 0 then
									-- Find config override if any
									local config = nil
									local configId = nil
									for idx, cfg in ipairs(configs) do
										if string.lower(cfg.SpawnPartName) == string.lower(spawnPart.Name) then
											config = cfg
											configId = idx
											break
										end
									end
									
									local lastDeath = spawnPart:GetAttribute("LastDeathTime") or 0
									local mobConfig = MobConfig.MobTypes[mobType]
									local respawnTime = (config and config.RespawnTime) or (mobConfig and mobConfig.RespawnTime) or 5
									
									local elapsed = os.time() - lastDeath
									local timeLeft = respawnTime - elapsed
									
									if timeLeft > 0 then
										-- Time has not elapsed yet, just wait (GUI removed)
									else
										-- Clean up timer GUI when spawning or if time has elapsed
										local billboard = spawnPart:FindFirstChild("RespawnGui")
										if billboard then
											billboard:Destroy()
										end
										
										local templateFolder = ReplicatedStorage:FindFirstChild("Mobs")
										local templateName = (config and config.Template) or (mobConfig and mobConfig.Name) or mobType
										local template = templateFolder and templateFolder:FindFirstChild(templateName)
										
										local health = (config and config.Health) or (mobConfig and mobConfig.Health) or 50
										local damage = (config and config.Damage) or (mobConfig and mobConfig.Damage) or 10
										local level = (config and config.Level) or (mobConfig and mobConfig.Level) or 1
										
										local randomPart = spawnPart
										if not (config and config.SpawnAtPart) then
											local eligibleParts = {}
											for _, desc in ipairs(reefFolder:GetDescendants()) do
												if desc:IsA("BasePart") and not desc.Name:lower():match("spawn") and not desc.Name:lower():match("gate") then
													table.insert(eligibleParts, desc)
												end
											end
											if #eligibleParts > 0 then
												randomPart = eligibleParts[math.random(1, #eligibleParts)]
											end
										end
										local spawnCF = nil
										if randomPart:IsA("BasePart") then
											spawnCF = randomPart.CFrame * CFrame.new(0, 10, 0)
										elseif randomPart:IsA("Model") then
											spawnCF = randomPart:GetPivot() * CFrame.new(0, 10, 0)
										end
										
										if spawnCF then
											local newMob = MobService.SpawnMob(spawnCF, health, level, template, damage, mobType, mobConfig)
											if newMob then
												if configId then
													newMob:SetAttribute("ReefConfigId", configId)
												end
												newMob:SetAttribute("ReefName", reefName)
												newMob:SetAttribute("SpawnPartName", spawnPart.Name)
												
												print("MobService: Spawned " .. mobType .. " at spawn part: " .. spawnPart.Name)
												activeSpawns[spawnPart] = newMob
											else
												warn("MobService: Failed to spawn " .. mobType .. " at spawn part: " .. spawnPart.Name)
											end
										end
									end
								else
									-- Clean up timer GUI if the mob is alive
									local billboard = spawnPart:FindFirstChild("RespawnGui")
									if billboard then
										billboard:Destroy()
									end
								end
							end
						end
					end
				end
			end
		end
	end)
end

return MobService
