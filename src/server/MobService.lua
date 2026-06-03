local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(script.Parent.PlayerData)

local MobService = {}
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
	local root = mobModel:FindFirstChild("HumanoidRootPart")
	
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
		
		if reefName and configId then
			local Shared = ReplicatedStorage:FindFirstChild("Shared")
			if Shared and Shared:FindFirstChild("MobSpawnConfig") then
				local MobSpawnConfig = require(Shared.MobSpawnConfig)
				local config = MobSpawnConfig.Reefs[reefName] and MobSpawnConfig.Reefs[reefName][configId]
				if config and config.Drops then
					local tokenFolder = workspace:FindFirstChild("TokenRewards")
					if tokenFolder then
						for _, drop in ipairs(config.Drops) do
							if math.random() <= (drop.Chance or 1) then
								if drop.Type == "Token" then
									local amountToSpawn = 1
									if drop.Name ~= "Biomass" and drop.Amount > 1 then
										amountToSpawn = drop.Amount
									end
									
									for i = 1, amountToSpawn do
										local p = Instance.new("Part")
										p.Size = Vector3.new(2, 2, 2)
										p.Position = root.Position + Vector3.new(math.random(-3, 3), 2, math.random(-3, 3))
										p.Shape = Enum.PartType.Ball
										p.Material = Enum.Material.Neon
										p.Color = Color3.fromRGB(0, 255, 0)
										if drop.Name == "FishFeed" then p.Color = Color3.fromRGB(150, 75, 0) end
										
										p.Anchored = true
										p.CanCollide = false
										
										if drop.Name == "Biomass" then
											p:SetAttribute("Biomass", drop.Amount)
										else
											p:SetAttribute("Item", drop.Name)
										end
										
										p.Name = drop.Name .. "Token"
										local posId = string.format("%d_%d_%d_%d", math.floor(p.Position.X * 100), math.floor(p.Position.Y * 100), math.floor(p.Position.Z * 100), math.random(1, 9999))
										p:SetAttribute("UniqueId", p.Name .. "_" .. posId)
										
										p.Parent = tokenFolder
										game.Debris:AddItem(p, 30)
									end
								end
							end
						end
					end
				end
			end
			
			local reefFolder = workspace:FindFirstChild(reefName)
			if reefFolder and spawnPartName then
				local spawnPart = reefFolder:FindFirstChild(spawnPartName)
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
local function CreatePlaceholderMob(healthAmount, levelAmount)
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
	damage.Value = 10
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

function MobService.SpawnMob(spawnCFrame, healthAmount, levelAmount, template)
	local mob = template and template:Clone() or CreatePlaceholderMob(healthAmount, levelAmount)
	
	mob:SetPrimaryPartCFrame(spawnCFrame)
	mob.Parent = workspace
	
	local health = mob:FindFirstChild("Health")
	local maxHealth = mob:FindFirstChild("MaxHealth")
	local level = mob:FindFirstChild("Level")
	
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
	
	table.insert(activeMobs, {
		Mob = mob,
		SpawnPos = spawnCFrame.Position,
		State = "Idle",
		Target = nil,
		NextAttack = 0,
		Health = mob:FindFirstChild("Health"),
		Damage = mob:FindFirstChild("Damage")
	})
	
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
			
			local root = mob:FindFirstChild("HumanoidRootPart")
			local hum = mob:FindFirstChild("Humanoid")
			if not root or not hum then continue end
			
			local state = data.State
			
			if state == "Idle" then
				-- Look for nearest player within 40 studs
				local nearestPlayer = nil
				local shortestDist = 40
				
				for _, p in ipairs(Players:GetPlayers()) do
					local char = p.Character
					local pRoot = char and char:FindFirstChild("HumanoidRootPart")
					if pRoot then
						local dist = (pRoot.Position - root.Position).Magnitude
						if dist < shortestDist then
							shortestDist = dist
							nearestPlayer = p
						end
					end
				end
				
				if nearestPlayer then
					data.Target = nearestPlayer
					data.Mob:SetAttribute("TargetingPlayer", true)
					data.State = "Chasing"
				end
				
			elseif state == "Chasing" then
				if data.Target and data.Target.Character and data.Target.Character.PrimaryPart then
					local targetPos = data.Target.Character.PrimaryPart.Position
					local distToSpawn = (root.Position - data.SpawnPos).Magnitude
					local distToPlayer = (root.Position - targetPos).Magnitude
					
					if distToSpawn > 60 then
						data.State = "Returning"
						data.Target = nil
						data.Mob:SetAttribute("TargetingPlayer", nil)
						hum:MoveTo(data.SpawnPos)
					elseif distToPlayer < 8 then
						hum:MoveTo(root.Position)
						data.State = "Windup"
						data.NextAttack = now + 0.8 -- 0.6s tracking + 0.2s locked in
						data.AttackPos = targetPos
						
						local indicator = Instance.new("Part")
						indicator.Name = "DangerIndicator"
						indicator.Anchored = true
						indicator.CanCollide = false
						indicator.Shape = Enum.PartType.Cylinder
						indicator.Size = Vector3.new(0.2, 13, 13)
						indicator.Color = Color3.new(1, 0.5, 0.5) -- Lighter color while aiming
						indicator.Material = Enum.Material.Neon
						indicator.Transparency = 1
						
						local raycastParams = RaycastParams.new()
						raycastParams.FilterDescendantsInstances = {data.Mob, data.Target.Character}
						raycastParams.FilterType = Enum.RaycastFilterType.Exclude
						local rayResult = workspace:Raycast(targetPos, Vector3.new(0, -10, 0), raycastParams)
						local placePos = rayResult and rayResult.Position or (targetPos - Vector3.new(0, 2.5, 0))
						
						indicator.CFrame = CFrame.new(placePos) * CFrame.Angles(0, 0, math.pi/2)
						indicator.Parent = workspace
						
						local TweenService = game:GetService("TweenService")
						TweenService:Create(indicator, TweenInfo.new(0.2), {Transparency = 0.6}):Play()
						
						data.AttackIndicator = indicator
						data.IndicatorLocked = false
						Debris:AddItem(indicator, 2)
					else
						hum:MoveTo(targetPos)
					end
				else
					data.State = "Returning"
					data.Target = nil
					data.Mob:SetAttribute("TargetingPlayer", nil)
					hum:MoveTo(data.SpawnPos)
				end
				
			elseif state == "Windup" then
				if data.Target and data.Target.Character and data.Target.Character.PrimaryPart then
					if now < data.NextAttack - 0.2 then
						-- Tracking phase
						local targetPos = data.Target.Character.PrimaryPart.Position
						data.AttackPos = targetPos
						
						if data.AttackIndicator then
							local raycastParams = RaycastParams.new()
							raycastParams.FilterDescendantsInstances = {data.Mob, data.Target.Character}
							raycastParams.FilterType = Enum.RaycastFilterType.Exclude
							local rayResult = workspace:Raycast(targetPos, Vector3.new(0, -10, 0), raycastParams)
							local placePos = rayResult and rayResult.Position or (targetPos - Vector3.new(0, 2.5, 0))
							data.AttackIndicator.CFrame = CFrame.new(placePos) * CFrame.Angles(0, 0, math.pi/2)
						end
						
						local lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
						if (lookPos - root.Position).Magnitude > 0.1 then
							root.CFrame = CFrame.lookAt(root.Position, lookPos)
						end
					elseif not data.IndicatorLocked then
						-- Lock phase
						data.IndicatorLocked = true
						if data.AttackIndicator then
							local TweenService = game:GetService("TweenService")
							TweenService:Create(data.AttackIndicator, TweenInfo.new(0.1), {Transparency = 0.2, Color = Color3.new(1, 0, 0)}):Play()
						end
					end
				end
				
				if now >= data.NextAttack then
					data.State = "Leaping"
					hum.Jump = true
					hum:MoveTo(data.AttackPos or data.SpawnPos)
					data.NextAttack = now + 0.5
				end
				
			elseif state == "Leaping" then
				local targetPos = data.AttackPos or root.Position
				local distToTarget = (root.Position - targetPos).Magnitude
				
				if distToTarget < 4 or now >= data.NextAttack then
					-- Deal damage if player is still in the zone
					if data.Target and data.Target.Character and data.Target.Character.PrimaryPart then
						local distToPlayer = (data.Target.Character.PrimaryPart.Position - targetPos).Magnitude
						if distToPlayer < 6.5 then
							local targetHum = data.Target.Character:FindFirstChild("Humanoid")
							if targetHum then
								local dmg = data.Damage and data.Damage.Value or 10
								targetHum:TakeDamage(dmg)
							end
						end
					end
					
					if data.AttackIndicator then
						local TweenService = game:GetService("TweenService")
						TweenService:Create(data.AttackIndicator, TweenInfo.new(0.2), {Transparency = 1}):Play()
						Debris:AddItem(data.AttackIndicator, 0.2)
						data.AttackIndicator = nil
					end
					
					data.State = "LeapingBack"
					hum.Jump = true
					local dir = (root.Position - targetPos).Unit
					if dir.Magnitude < 0.1 or dir ~= dir then dir = Vector3.new(0, 0, 1) end
					dir = Vector3.new(dir.X, 0, dir.Z).Unit
					data.LeapBackPos = root.Position + dir * 12
					hum:MoveTo(data.LeapBackPos)
					data.NextAttack = now + 0.5
				end
				
			elseif state == "LeapingBack" then
				local distToTarget = data.LeapBackPos and (root.Position - data.LeapBackPos).Magnitude or 0
				if distToTarget < 2 or now >= data.NextAttack then
					data.State = "Cooldown"
					hum:MoveTo(root.Position)
					data.NextAttack = now + 1.0
				end
				
			elseif state == "Cooldown" then
				if now >= data.NextAttack then
					data.State = "Chasing"
				end
				
			elseif state == "Returning" then
				if data.AttackIndicator then
					data.AttackIndicator:Destroy()
					data.AttackIndicator = nil
				end
				local dist = (root.Position - data.SpawnPos).Magnitude
				if dist < 2 then
					data.State = "Idle"
				else
					hum:MoveTo(data.SpawnPos)
				end
			end
		end
	end)
	
	-- Command to spawn a test mob
	Players.PlayerAdded:Connect(function(p)
		p.Chatted:Connect(function(msg)
			if msg:sub(1, 9) == "/spawnmob" then
				local args = string.split(msg, " ")
				local healthAmount = tonumber(args[2]) or 100
				local levelAmount = tonumber(args[3]) or 1
				
				if p.Character and p.Character.PrimaryPart then
					local cf = p.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -10)
					MobService.SpawnMob(cf, healthAmount, levelAmount)
					print("Spawned test mob with " .. healthAmount .. " HP and Level " .. levelAmount)
				end
			end
		end)
	end)
	
	-- Start Spawner Loop
	task.spawn(function()
		local Shared = ReplicatedStorage:FindFirstChild("Shared")
		if Shared and Shared:FindFirstChild("MobSpawnConfig") then
			local MobSpawnConfig = require(Shared.MobSpawnConfig)
			
			local activeSpawns = {}
			while task.wait(2) do
				for reefName, configs in pairs(MobSpawnConfig.Reefs) do
					local reefFolder = workspace:FindFirstChild(reefName)
					if reefFolder then
						for i, config in ipairs(configs) do
							local targetName = config.SpawnPartName
							if i > 1 then targetName = targetName .. tostring(i) end
							
							local spawnPart = reefFolder:FindFirstChild(targetName)
							if spawnPart then
								local existingMob = activeSpawns[spawnPart]
								if not existingMob or not existingMob.Parent or not existingMob:FindFirstChild("Health") or existingMob.Health.Value <= 0 then
									local lastDeath = spawnPart:GetAttribute("LastDeathTime") or 0
									if os.time() - lastDeath >= (config.RespawnTime or 5) then
										local templateFolder = ReplicatedStorage:FindFirstChild("Mobs")
										local template = templateFolder and templateFolder:FindFirstChild(config.Template)
										
										local spawnCF = spawnPart.CFrame * CFrame.new(0, 5, 0)
										local newMob = MobService.SpawnMob(spawnCF, config.Health, config.Level, template)
										
										newMob:SetAttribute("ReefConfigId", i)
										newMob:SetAttribute("ReefName", reefName)
										newMob:SetAttribute("SpawnPartName", spawnPart.Name)
										
										activeSpawns[spawnPart] = newMob
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
