local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-- Auto-setup GlobalSpawns folder
local globalSpawns = Workspace:FindFirstChild("GlobalSpawns")
if not globalSpawns then
	globalSpawns = Instance.new("Folder")
	globalSpawns.Name = "GlobalSpawns"
	globalSpawns.Parent = Workspace
end
local spawnLM = Workspace:FindFirstChild("SpawnLM")
if spawnLM then
	spawnLM.Parent = globalSpawns
end

local PlayerData = require(script.Parent.PlayerData)
local MobConfig = require(ReplicatedStorage.Shared.MobConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
local ChanceConfig = require(ReplicatedStorage.Shared.ChanceConfig)

local MobService = {}
local mobDamageTrackers = setmetatable({}, {__mode = "k"})

local function getFieldFolder(fieldName)
	if not fieldName then return nil end
	
	local folder = workspace:FindFirstChild(fieldName)
	if folder then return folder end
	
	local reefsFolder = workspace:FindFirstChild("Reefs")
	if reefsFolder then
		folder = reefsFolder:FindFirstChild(fieldName)
		if folder then return folder end
	end
	
	local cleanName = string.lower(fieldName):gsub("â€™", "'"):gsub("'", ""):gsub("%s+", "")
	
	for _, child in ipairs(workspace:GetChildren()) do
		local childClean = string.lower(child.Name):gsub("â€™", "'"):gsub("'", ""):gsub("%s+", "")
		if childClean == cleanName then
			return child
		end
	end
	
	if reefsFolder then
		for _, child in ipairs(reefsFolder:GetChildren()) do
			local childClean = string.lower(child.Name):gsub("â€™", "'"):gsub("'", ""):gsub("%s+", "")
			if childClean == cleanName then
				return child
			end
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

local function isAnyPlayerInReef(reefName)
	for _, p in ipairs(Players:GetPlayers()) do
		if isPlayerInReef(p, reefName) then
			return true
		end
	end
	return false
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

local damageQueue = { All = {}, Players = {} }

local function ShowDamageNumber(part, amount, isCrit, isMiss, player, isAbility)
	if not DamageVisualEvent or not part then return end
	
	local data = {
		pos = part.Position,
		amount = amount,
		isCrit = isCrit,
		isMiss = isMiss,
		isMegaCrit = false,
		isAbility = isAbility
	}
	
	if player then
		if not damageQueue.Players[player] then damageQueue.Players[player] = {} end
		table.insert(damageQueue.Players[player], data)
	else
		table.insert(damageQueue.All, data)
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

function MobService.UpdateLevelUI(mobModel)
	if not mobModel or not mobModel.PrimaryPart then return end
	local root = mobModel.PrimaryPart
	local titleUI = root:FindFirstChild("TitleUI")
	local level = mobModel:FindFirstChild("Level")
	if titleUI and level then
		local healthFrame = titleUI:FindFirstChild("Health")
		if healthFrame then
			local lvlText = healthFrame:FindFirstChild("Level")
			if lvlText then
				lvlText.Text = "Lv. " .. tostring(level.Value)
			end
		end
	end
end

function MobService.DamageMob(mobModel, amount, isCrit, isMiss, player, isAbility)
	if isAbility == nil then isAbility = true end
	if not mobModel or not mobModel.Parent then return end
	local root = mobModel.PrimaryPart or mobModel:FindFirstChild("HumanoidRootPart")
	
	if isMiss then
		if root then ShowDamageNumber(root, 0, false, true, player, isAbility) end
		return
	end
	
	local health = mobModel:FindFirstChild("Health")
	local maxHealth = mobModel:FindFirstChild("MaxHealth")
	if not health then return end
	
	health.Value = math.max(0, health.Value - amount)
	
	-- King Frog Minion Spawning
	local mobType = mobModel:GetAttribute("MobType") or mobModel.Name
	if mobType == "King Frog" and health.Value > 0 then
		local dmgFrog = (mobModel:GetAttribute("DamageSinceLastFrog") or 0) + amount
		local dmgAxolotl = (mobModel:GetAttribute("DamageSinceLastAxolotl") or 0) + amount
		
		local numFrogsToSpawn = math.floor(dmgFrog / 1000)
		if numFrogsToSpawn > 0 then
			dmgFrog = dmgFrog - (numFrogsToSpawn * 1000)
			
			local templateFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Mobs")
			local templateFrog = templateFolder and templateFolder:FindFirstChild("Frog")
			if templateFrog then
				for i = 1, numFrogsToSpawn do
					local spawnDist = math.random(5, 15)
					local spawnAngle = math.random() * math.pi * 2
					local spawnCF = root.CFrame * CFrame.new(math.cos(spawnAngle) * spawnDist, 5, math.sin(spawnAngle) * spawnDist)
					local frogLvl = mobModel:FindFirstChild("Level") and mobModel.Level.Value or 5
					local minion = MobService.SpawnMob(spawnCF, 100, frogLvl, templateFrog, 10, "Frog", MobConfig.MobTypes["Frog"])
					if minion then
						minion:SetAttribute("Owner", mobModel:GetAttribute("Owner") or "Global")
					end
				end
			end
		end
		
		local numAxolotlsToSpawn = math.floor(dmgAxolotl / 2500)
		if numAxolotlsToSpawn > 0 then
			dmgAxolotl = dmgAxolotl - (numAxolotlsToSpawn * 2500)
			
			local templateFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Mobs")
			local templateAxo = templateFolder and templateFolder:FindFirstChild("Axolotl")
			if templateAxo then
				for i = 1, numAxolotlsToSpawn * 2 do -- Spawns 2 Axolotls per 2500 dmg
					local spawnDist = math.random(5, 15)
					local spawnAngle = math.random() * math.pi * 2
					local spawnCF = root.CFrame * CFrame.new(math.cos(spawnAngle) * spawnDist, 5, math.sin(spawnAngle) * spawnDist)
					local axoLvl = mobModel:FindFirstChild("Level") and mobModel.Level.Value or 5
					local minion = MobService.SpawnMob(spawnCF, 500, axoLvl, templateAxo, 20, "Axolotl", MobConfig.MobTypes["Axolotl"])
					if minion then
						minion:SetAttribute("Owner", mobModel:GetAttribute("Owner") or "Global")
					end
				end
			end
		end
		
		mobModel:SetAttribute("DamageSinceLastFrog", dmgFrog)
		mobModel:SetAttribute("DamageSinceLastAxolotl", dmgAxolotl)
	end
	
	if player then
		if not mobDamageTrackers[mobModel] then mobDamageTrackers[mobModel] = {} end
		mobDamageTrackers[mobModel][player.UserId] = (mobDamageTrackers[mobModel][player.UserId] or 0) + amount
		
		-- Track Quest Progress
		PlayerData.IncrementQuestGoal(player, "TotalDamageDealt", amount)
		
		local mobType = mobModel:GetAttribute("MobType") or mobModel.Name
		local mConfig = MobConfig.MobTypes and MobConfig.MobTypes[mobType]
		if mConfig and mConfig.HasBossBar then
			PlayerData.IncrementQuestGoal(player, "BossDamage", amount)
		end
	end
	
	if root then
		ShowDamageNumber(root, amount, isCrit, false, player, isAbility)
		
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
		
		local mobType = mobModel:GetAttribute("MobType") or mobModel.Name
		local mobConfig = MobConfig.MobTypes[mobType]
		
		local playersToReward = {}
		if mobConfig and mobConfig.IsGlobal then
			local threshold = maxHealth and (maxHealth.Value * 0.10) or 0
			local trackers = mobDamageTrackers[mobModel] or {}
			for userId, dmg in pairs(trackers) do
				if dmg >= threshold then
					local p = Players:GetPlayerByUserId(userId)
					if p then table.insert(playersToReward, p) end
				end
			end
		else
			if player then table.insert(playersToReward, player) end
		end
		
		local PlayerData = require(script.Parent.PlayerData)
		for _, rewardPlayer in ipairs(playersToReward) do
			PlayerData.IncrementQuestGoal(rewardPlayer, "MobsKilled", 1)
			PlayerData.IncrementQuestGoal(rewardPlayer, "MobsKilled_" .. mobType, 1)
			
			if mobType == "LavaMonster" then
				PlayerData.update(rewardPlayer, function(data)
					data.LavaMonsterDefeated = true
				end)
			end
		end
		
		-- Drop logic
		local reefName = mobModel:GetAttribute("ReefName")
		local configId = mobModel:GetAttribute("ReefConfigId")
		local spawnPartName = mobModel:GetAttribute("SpawnPartName")
		
		if root then
			local Shared = ReplicatedStorage:FindFirstChild("Shared")
			local MobSpawnConfig = Shared and Shared:FindFirstChild("MobSpawnConfig") and require(Shared.MobSpawnConfig)
			local config = reefName and configId and MobSpawnConfig and MobSpawnConfig.Reefs[reefName] and MobSpawnConfig.Reefs[reefName][configId]
			
			for _, rewardPlayer in ipairs(playersToReward) do
				local drops = nil
				if not (_G.AutoLootEnabled and _G.AutoLootEnabled[rewardPlayer.UserId]) then
					drops = (config and config.Drops) or ChanceConfig.MobDrops[mobType] or (mobConfig and ChanceConfig.MobDrops[mobConfig.Name])
				else
					drops = ChanceConfig.MobDrops[mobType] or (mobConfig and ChanceConfig.MobDrops[mobConfig.Name])
				end
				
				if drops then
					local mobLevel = mobModel:FindFirstChild("Level") and mobModel.Level.Value or 1
					local rewardMultiplier = 1 -- Intentionally removing level scaling
					
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
									table.insert(grantedRewards, {Name = drop.Name, Amount = finalAmount})
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
					
					PlayerData.update(rewardPlayer, function(data)
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
					
					for _, reward in ipairs(grantedRewards) do
						if reward.Name == "Biomass" then
							local ls = rewardPlayer:FindFirstChild("leaderstats")
							if ls and ls:FindFirstChild("Biomass") then
								local pData = PlayerData.get(rewardPlayer)
								ls.Biomass.Value = pData.Biomass or 0
							end
							local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
							if NotificationEvent then
								NotificationEvent:FireClient(rewardPlayer, "+" .. reward.Amount .. " Biomass", Color3.fromRGB(0, 255, 255))
							end
						else
							local ItemAddedEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ItemAddedEvent")
							if ItemAddedEvent then
								ItemAddedEvent:FireClient(rewardPlayer, reward.Name, reward.Amount, "Item", 0, 0)
							end
						end
					end
					
					local VFXReplication = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("VFXReplication")
					if VFXReplication then
						VFXReplication:FireClient(rewardPlayer, "MobCollectSparkle", rewardPlayer, nil, root.Position, totalSparkles)
					end
				end
			end
			
			local reefFolder = getFieldFolder(reefName)
			if reefFolder and spawnPartName then
				local spawnPartObj = mobModel:FindFirstChild("SpawnPartRef")
				local spawnPart = spawnPartObj and spawnPartObj.Value
				local ownerName = mobModel:GetAttribute("Owner")
				if spawnPart and ownerName then
					spawnPart:SetAttribute("LastDeathTime_" .. ownerName, os.time())
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
		mob:SetAttribute("MobType", mobName)
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
		local rootPart = mob:FindFirstChild("Root") or mob:FindFirstChild("Torso") or mob:FindFirstChild("UpperTorso") or mob:FindFirstChildWhichIsA("BasePart")
		if rootPart then
			hrp = Instance.new("Part")
			hrp.Name = "HumanoidRootPart"
			hrp.Size = Vector3.new(2, 2, 2)
			hrp.CFrame = rootPart.CFrame
			hrp.Transparency = 1
			hrp.CanCollide = true
			hrp.Parent = mob
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hrp
			weld.Part1 = rootPart
			weld.Parent = hrp
		end
	end
	if hrp then
		mob.PrimaryPart = hrp
	else
		warn("MobService: Spawned mob model '" .. mob.Name .. "' has no BaseParts!")
		mob:Destroy()
		return nil
	end
	
	-- It's critical to apply ScaleTo AFTER the PrimaryPart is correctly set
	mob:PivotTo(spawnCFrame)
	
	if mobConfig and mobConfig.Scale then
		mob:ScaleTo(mobConfig.Scale)
	end
	
	local mobsFolder = workspace:FindFirstChild("Mobs")
	if not mobsFolder then
		mobsFolder = Instance.new("Folder")
		mobsFolder.Name = "Mobs"
		mobsFolder.Parent = workspace
	end
	mob.Parent = mobsFolder
	
	-- Force Unanchor, CollisionGroup, and physics optimizations
	for _, part in ipairs(mob:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CollisionGroup = "Mobs"
			if part ~= mob.PrimaryPart then
				part.CanCollide = false
				part.Massless = true
			end
		end
	end
	
	if mob.PrimaryPart and mob.PrimaryPart:CanSetNetworkOwnership() then
		mob.PrimaryPart:SetNetworkOwner(nil)
	end
	
	if mobConfig and mobConfig.WalkSpeed == 0 and mobName ~= "Axolotl" and mob.PrimaryPart then
		mob.PrimaryPart.Anchored = true
	end
	
	-- Attach Health UI
	local titleUITemplate = nil
	local mobsFolder = ReplicatedStorage:FindFirstChild("Mobs")
	if mobsFolder then
		titleUITemplate = mobsFolder:FindFirstChild("TitleUI")
	end
	
	if not titleUITemplate then
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		if vfxFolder then
			local mobHealthFolder = vfxFolder:FindFirstChild("MobHealth")
			if mobHealthFolder then
				titleUITemplate = mobHealthFolder:FindFirstChild("TitleUI")
			end
		end
	end
	
	if titleUITemplate and mob.PrimaryPart then
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
						
						local leftScale = origPos.X.Scale - origSizeX.Scale * origAnchorX
						local leftOffset = origPos.X.Offset - origSizeX.Offset * origAnchorX
						
						bar.AnchorPoint = Vector2.new(0, bar.AnchorPoint.Y)
						bar.Position = UDim2.new(leftScale, leftOffset, origPos.Y.Scale, origPos.Y.Offset)
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
					
					local nameText = hFrame:FindFirstChild("MobName") or hFrame:FindFirstChild("Name") or titleUI:FindFirstChild("MobName") or titleUI:FindFirstChild("Name")
					if not nameText then
						nameText = Instance.new("TextLabel")
						nameText.Name = "MobName"
						nameText.BackgroundTransparency = 1
						nameText.Size = UDim2.new(1, 0, 0.4, 0)
						nameText.Position = UDim2.new(0, 0, -0.45, 0)
						nameText.Font = Enum.Font.FredokaOne
						nameText.TextColor3 = Color3.new(1, 1, 1)
						nameText.TextStrokeTransparency = 0
						nameText.TextScaled = true
						nameText.Parent = hFrame
					end
					nameText.Text = (mobConfig and mobConfig.Name) or mobName or mob.Name
				end
	end
	
	local hum = mob:FindFirstChildOfClass("Humanoid")
	if not hum then
		hum = Instance.new("Humanoid")
		hum.Parent = mob
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	
	if mob:FindFirstChild("Torso") then
		hum.RigType = Enum.HumanoidRigType.R6
	else
		hum.RigType = Enum.HumanoidRigType.R15
	end
	
	hum.WalkSpeed = mobConfig and mobConfig.WalkSpeed or 8
	if mobConfig and mobConfig.HipHeight then
		if hum.RigType == Enum.HumanoidRigType.R15 then
			hum.HipHeight = mobConfig.HipHeight
		else
			hum.HipHeight = 0
		end
	end

	if mobConfig and mobConfig.Scale then
		local scales = {"BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale"}
		for _, scaleName in ipairs(scales) do
			local scaleVal = hum:FindFirstChild(scaleName)
			if not scaleVal then
				scaleVal = Instance.new("NumberValue")
				scaleVal.Name = scaleName
				scaleVal.Parent = hum
			end
			scaleVal.Value = mobConfig.Scale
		end
		
		if hum.RigType == Enum.HumanoidRigType.R6 and mobConfig.Scale and mobConfig.Scale ~= 1 then
			local motors = {}
			for _, desc in ipairs(mob:GetDescendants()) do
				if desc:IsA("Motor6D") then
					table.insert(motors, desc)
				end
			end
			if #motors > 0 then
				local scale = mobConfig.Scale
				local connection
				connection = RunService.Stepped:Connect(function()
					if not mob.Parent or hum.Health <= 0 then
						connection:Disconnect()
						return
					end
					for _, motor in ipairs(motors) do
						local t = motor.Transform
						if t.Position.Magnitude > 0.001 then
							motor.Transform = CFrame.new(t.Position * scale) * (t - t.Position)
						end
					end
				end)
			end
		end
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
		
		if (mobName == "Frog" or mobName == "King Frog" or mobName == "Axolotl") then
			local oldRoot = mob.PrimaryPart
			if oldRoot then
				if oldRoot.Name == "HumanoidRootPart" then
					oldRoot.Name = "VisualRootPart"
				end
				local newRoot = Instance.new("Part")
				newRoot.Name = "HumanoidRootPart"
				newRoot.Size = oldRoot.Size
				if mobName == "Axolotl" then
					newRoot.CFrame = oldRoot.CFrame * CFrame.Angles(0, -math.pi/2, 0)
				else
					newRoot.CFrame = oldRoot.CFrame * CFrame.Angles(0, math.pi, 0)
				end
				newRoot.Transparency = 1
				newRoot.CanCollide = false
				newRoot.Parent = mob
				mob.PrimaryPart = newRoot
				
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = newRoot
				weld.Part1 = oldRoot
				weld.Parent = newRoot
				
				local titleUI = oldRoot:FindFirstChild("TitleUI")
				if titleUI then
					titleUI.Parent = newRoot
				end
			end
		end
	end

	local walkTrack = nil
	local idleTrack = nil
	local runTrack = nil
	local attackTrack = nil
	local attack2Track = nil
	local dashTrack = nil
	local roarTrack = nil
	local geyserTrack = nil
	local sunkissedTrack1 = nil
	local sunkissedTrack2 = nil
	local sunkissedTrack3 = nil

	-- Skeleton: inject Executioner animations programmatically so no Studio edits are needed
	if mobName == "Skeleton" then
		local function injectAnim(name, id)
			if not mob:FindFirstChild(name, true) then
				local a = Instance.new("Animation")
				a.Name = name
				a.AnimationId = id
				a.Parent = mob
			end
		end
		injectAnim("Idle", "rbxassetid://107563853393140")
		injectAnim("Walk", "rbxassetid://121211694117042")
		injectAnim("Run",  "rbxassetid://110140857799762")
		injectAnim("m1",   "rbxassetid://126575891845553")
		injectAnim("m2",   "rbxassetid://72009504229810")
		injectAnim("m3",   "rbxassetid://77829428848192")
	end

	if hum then
		local walkAnim
		local idleAnim
		local runAnim
		local attackAnim
		local attack2Anim
		local dashAnim
		local roarAnim
		local geyserAnim
		local m1Anim
		local m2Anim
		local m3Anim
		
		for _, desc in ipairs(mob:GetDescendants()) do
			if desc:IsA("Animation") then
				if desc.Name == "Walk" then walkAnim = desc end
				if desc.Name == "Idle" then idleAnim = desc end
				if desc.Name == "Run" then runAnim = desc end
				if desc.Name == "Attack1" then attackAnim = desc end
				if desc.Name == "Attack2" then attack2Anim = desc end
				if desc.Name == "Dash" then dashAnim = desc end
				if desc.Name == "Roar" then roarAnim = desc end
				if string.lower(desc.Name) == "geyserlaunch" then geyserAnim = desc end
				if desc.Name == "m1" then m1Anim = desc end
				if desc.Name == "m2" then m2Anim = desc end
				if desc.Name == "m3" then m3Anim = desc end
			end
		end
		
		print("DEBUG SPAWN: Mob", mob.Name, "Walk:", walkAnim ~= nil, "Idle:", idleAnim ~= nil, "Attack1:", attackAnim ~= nil, "Attack2:", attack2Anim ~= nil, "Dash:", dashAnim ~= nil, "Roar:", roarAnim ~= nil, "Geyser:", geyserAnim ~= nil)
		
		if walkAnim or idleAnim or attackAnim or dashAnim or roarAnim or attack2Anim or geyserAnim then
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
			if runAnim then
				runTrack = animator:LoadAnimation(runAnim)
				runTrack.Looped = true
			end
			if attackAnim then
				attackTrack = animator:LoadAnimation(attackAnim)
				attackTrack.Looped = false
			end
			if attack2Anim then
				attack2Track = animator:LoadAnimation(attack2Anim)
				attack2Track.Looped = false
			end
			if dashAnim then
				dashTrack = animator:LoadAnimation(dashAnim)
				dashTrack.Looped = false
			end
			if roarAnim then
				roarTrack = animator:LoadAnimation(roarAnim)
				roarTrack.Looped = false
			end
			if geyserAnim then
				geyserTrack = animator:LoadAnimation(geyserAnim)
				geyserTrack.Looped = false
			end
			
			if m1Anim then
				sunkissedTrack1 = animator:LoadAnimation(m1Anim)
				sunkissedTrack1.Looped = false
				sunkissedTrack1.Priority = Enum.AnimationPriority.Action4
			end
			
			if m2Anim then
				sunkissedTrack2 = animator:LoadAnimation(m2Anim)
				sunkissedTrack2.Looped = false
				sunkissedTrack2.Priority = Enum.AnimationPriority.Action4
			end
			
			if m3Anim then
				sunkissedTrack3 = animator:LoadAnimation(m3Anim)
				sunkissedTrack3.Looped = false
				sunkissedTrack3.Priority = Enum.AnimationPriority.Action4
			end
		end
	end

	local mobData = {
		Mob = mob,
		SpawnPos = spawnCFrame.Position,
		State = (mobName == "LavaMonster" and "Spawning" or "Idle"),
		Target = nil,
		LastWanderTime = 0,
		LastDamageTime = 0,
		WanderInterval = 0,
		LastHopTime = 0,
		LastDashTime = (mobName == "Axolotl" and os.clock() - ((mobConfig.AttackCooldown or 5.0) - 3.0)) or 0,
		LastGeyserTime = 0,
		Health = mob:FindFirstChild("Health"),
		Damage = mob:FindFirstChild("Damage"),
		Config = mobConfig,
		WalkTrack = walkTrack,
		IdleTrack = idleTrack,
		RunTrack = runTrack,
		AttackTrack = attackTrack,
		Attack2Track = attack2Track,
		DashTrack = dashTrack,
		RoarTrack = roarTrack,
		GeyserTrack = geyserTrack,
		SunkissedTrack1 = sunkissedTrack1,
		SunkissedTrack2 = sunkissedTrack2,
		SunkissedTrack3 = sunkissedTrack3,
	}
	table.insert(activeMobs, mobData)
	
	mob:SetAttribute("MobType", mobName)

	-- Skeleton: attach Eyes, input, aura VFX props via Motor6D (mirrors Executioner VISUALS)
	if mobName == "Skeleton" then
		local vfxSkel = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("Skeleton")
		if vfxSkel then
			local SKELETON_VISUALS = {
				{ Template = "Eyes",  AttachTo = "Head",             C0 = CFrame.new(0, 0, 0) },
				{ Template = "input", AttachTo = "Right Arm",        C0 = CFrame.new(0, 0, 0) },
				{ Template = "aura",  AttachTo = "HumanoidRootPart", C0 = CFrame.new(0, 0, 0) },
			}
			for _, item in ipairs(SKELETON_VISUALS) do
				local attachPart = mob:FindFirstChild(item.AttachTo)
				local template = vfxSkel:FindFirstChild(item.Template)
				if attachPart and template then
					local clone = template:Clone()
					clone.Parent = mob
					local motor = Instance.new("Motor6D")
					motor.Name = item.Template .. "Weld"
					motor.Part0 = attachPart
					motor.Part1 = clone
					motor.C0 = item.C0
					motor.Parent = clone
				end
			end
		end
	end

	
	if mobName == "Axolotl" then
		task.spawn(function()
			if attack2Track then attack2Track:Play(0) end
			local vfxFolder = game:GetService("ReplicatedStorage"):FindFirstChild("VFX") and game:GetService("ReplicatedStorage").VFX:FindFirstChild("Axolotl")
			if vfxFolder and mob.PrimaryPart then
				local sfx = vfxFolder:FindFirstChild("AxolotlSFX")
				if sfx then
					local s = sfx:Clone()
					s.Parent = mob.PrimaryPart
					s:Play()
					game:GetService("Debris"):AddItem(s, 3)
				end
				local vfxPart = vfxFolder:FindFirstChild("AxolotlVFX")
				if vfxPart then
					local vfxClone = vfxPart:Clone()
					vfxClone.CFrame = mob.PrimaryPart.CFrame
					vfxClone.Parent = workspace
					game:GetService("Debris"):AddItem(vfxClone, 3)
					for _, p in ipairs(vfxClone:GetDescendants()) do
						if p:IsA("ParticleEmitter") then
							p:Emit(p:GetAttribute("EmitCount") or 30)
						end
					end
				end
			end
		end)
	end
	
	if mobName == "LavaMonster" then
		task.spawn(function()
			local root = mob.PrimaryPart
			local hum = mob:FindFirstChildOfClass("Humanoid")
			if not root or not hum then return end
			
			-- Wait until grounded
			while root and root.Parent and hum.Health > 0 do
				if math.abs(root.AssemblyLinearVelocity.Y) < 1 then
					break
				end
				task.wait(0.1)
			end
			
			if not root or not root.Parent or hum.Health <= 0 then return end
			
			local groundPos = root.Position - Vector3.new(0, (hum.HipHeight or 0) + (root.Size.Y/2), 0)
			local RS = game:GetService("ReplicatedStorage")
			local debris = game:GetService("Debris")
			
			-- Play Land animation
			local landAnim
			for _, desc in ipairs(mob:GetDescendants()) do
				if desc:IsA("Animation") and desc.Name == "Land" then
					landAnim = desc
					break
				end
			end
			
			local landTrack
			if landAnim then
				local animator = hum:FindFirstChildOfClass("Animator")
				if animator then
					landTrack = animator:LoadAnimation(landAnim)
					landTrack:Play()
				end
			end
			
			-- Lightning module
			local LightningBolt = require(RS.Lightning)
			local LightningSparks = require(RS.Lightning.LightningSparks)
			
			local targetPart = Instance.new("Part")
			targetPart.Size = Vector3.new(1, 1, 1)
			targetPart.Transparency = 1
			targetPart.Anchored = true
			targetPart.CanCollide = false
			targetPart.CFrame = CFrame.new(groundPos)
			targetPart.Parent = workspace

			local att2 = Instance.new("Attachment")
			att2.Parent = targetPart

			-- Create attachment above the ground point (attachment 1) - lightning strikes DOWN
			local skyPart = Instance.new("Part")
			skyPart.Size = Vector3.new(1, 1, 1)
			skyPart.Transparency = 1
			skyPart.Anchored = true
			skyPart.CanCollide = false
			skyPart.CFrame = CFrame.new(groundPos + Vector3.new(0, 150, 0))
			skyPart.Parent = workspace

			local att1 = Instance.new("Attachment")
			att1.Parent = skyPart

			-- Create lightning bolt
			local bolt = LightningBolt.new(att1, att2, 35)
			bolt.Thickness = 4.5
			bolt.Color = Color3.fromRGB(255, 100, 0) -- Lava Orange
			bolt.PulseSpeed = 2
			bolt.PulseLength = 3
			bolt.MaxThicknessMultiplier = 1.4
			bolt.FadeLength = 0.1
			bolt.MinRadius = 0
			bolt.MaxRadius = 35
			bolt.CurveSize0, bolt.CurveSize1 = 0, 0
			bolt.MinTransparency = 0
			bolt.MaxTransparency = 1

			local lightningsparks = LightningSparks.new(bolt, 40)

			-- Play LightningStrike sound
			task.spawn(function()
				local sfx = RS.VFX:FindFirstChild("LavaMonster") and RS.VFX.LavaMonster:FindFirstChild("LightningStrike")
				if sfx then
					local sfxClone = sfx:Clone()
					sfxClone.Parent = targetPart
					sfxClone:Play()
					debris:AddItem(sfxClone, 5)
				end
			end)

			-- Landing parts/particles
			local landingTemplate = RS.VFX:FindFirstChild("LavaMonster") and RS.VFX.LavaMonster:FindFirstChild("Landing")
			local landingParts = nil
			if landingTemplate then
				landingParts = landingTemplate:Clone()
				if landingParts:IsA("Attachment") then
					landingParts.Parent = att2
				else
					landingParts.CFrame = CFrame.new(groundPos)
					landingParts.Parent = workspace
				end
				
				task.spawn(function()
					task.wait(0.2)
					local descendants = landingParts:GetDescendants()
					for _, particle in pairs(descendants) do
						if particle:IsA("ParticleEmitter") then
							local emitCount = particle:GetAttribute("EmitCount") or 50
							particle:Emit(math.min(emitCount, 40))
							task.wait(0.01)
						end
					end
				end)
			end

			task.spawn(function()
				task.wait(0.6) 
				bolt:DestroyDissipate(0.3, 0.4) 
				lightningsparks:Destroy() 
				task.wait(4)
				if att1 and att1.Parent then att1:Destroy() end
				if att2 and att2.Parent then att2:Destroy() end
				if targetPart and targetPart.Parent then targetPart:Destroy() end
				if skyPart and skyPart.Parent then skyPart:Destroy() end
			end)

			if landingParts then
				task.spawn(function()
					task.wait(4)
					if landingParts and landingParts.Parent then
						landingParts:Destroy()
					end
				end)
			end
			
			if landTrack then
				landTrack.Stopped:Wait()
			else
				task.wait(0.7)
			end
			
			if mobData and hum.Health > 0 then
				mobData.State = "Idle"
			end
		end)
	end
	
	return mob
end

function MobService.GetMobs()
	return activeMobs
end

function MobService.Start()
	if not workspace:FindFirstChild("Mobs") then
		local folder = Instance.new("Folder")
		folder.Name = "Mobs"
		folder.Parent = workspace
	end

	-- Server loop for mob AI
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		
		-- Flush Damage Queue (Network Optimization)
		if #damageQueue.All > 0 then
			DamageVisualEvent:FireAllClients(damageQueue.All)
			table.clear(damageQueue.All)
		end
		for p, q in pairs(damageQueue.Players) do
			if #q > 0 then
				DamageVisualEvent:FireClient(p, q)
				table.clear(q)
			end
		end
		
		-- Cleanup missing mobs backwards
		for i = #activeMobs, 1, -1 do
			local mobData = activeMobs[i]
			if not mobData.Mob or not mobData.Mob.Parent then
				if mobData.AttackIndicator then mobData.AttackIndicator:Destroy() end
				table.remove(activeMobs, i)
			end
		end
		
		for _, data in ipairs(activeMobs) do
			local mob = data.Mob
			if not mob or not mob.Parent then continue end
			local root = mob.PrimaryPart or mob:FindFirstChild("HumanoidRootPart")
			local hum = mob:FindFirstChild("Humanoid")
			if not root then continue end
			
			local cfg = data.Config or {}
			
			if not hum then continue end
			
			-- Update animations based on movement velocity (Idle / Walk / Run)
			local walkTrack = data.WalkTrack
			local idleTrack = data.IdleTrack
			local runTrack  = data.RunTrack
			if (walkTrack or idleTrack or runTrack) and data.State ~= "Spawning" and data.State ~= "Attacking" and data.State ~= "Dashing" and data.State ~= "Roaring" and not data.Hibernating then
				local speed = root.AssemblyLinearVelocity.Magnitude
				if speed > 15 and runTrack then
					-- Running
					if idleTrack and idleTrack.IsPlaying then idleTrack:Stop(0.2) end
					if walkTrack and walkTrack.IsPlaying then walkTrack:Stop(0.2) end
					if not runTrack.IsPlaying then runTrack:Play(0.2) end
				elseif speed > 0.5 then
					-- Walking
					if idleTrack and idleTrack.IsPlaying then idleTrack:Stop(0.2) end
					if runTrack and runTrack.IsPlaying then runTrack:Stop(0.2) end
					if walkTrack and not walkTrack.IsPlaying then walkTrack:Play(0.2) end
				else
					-- Idle
					if walkTrack and walkTrack.IsPlaying then walkTrack:Stop(0.2) end
					if runTrack and runTrack.IsPlaying then runTrack:Stop(0.2) end
					if idleTrack and not idleTrack.IsPlaying then idleTrack:Play(0.2) end
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
				-- Look for Owner player within aggroRange or inside the reef
				local nearestPlayer = nil
				local shortestDist = math.huge
				local reefName = mob:GetAttribute("ReefName")
				local ownerName = mob:GetAttribute("Owner")
				local potentialTargets = {}
				if ownerName == "Global" then
					potentialTargets = Players:GetPlayers()
				else
					local p = ownerName and Players:FindFirstChild(ownerName)
					if p then table.insert(potentialTargets, p) end
				end
				
				for _, p in ipairs(potentialTargets) do
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
						local shouldDespawn = false
						local ownerName = mob:GetAttribute("Owner")
						if ownerName and ownerName ~= "Global" then
							local p = Players:FindFirstChild(ownerName)
							if not p then
								shouldDespawn = true
							else
								local reefName = mob:GetAttribute("ReefName")
								local pRoot = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
								if reefName and pRoot then
									local allReefs = workspace:FindFirstChild("Reefs") and workspace.Reefs:GetChildren() or {}
									local inReef = false
									for _, reefFolder in ipairs(allReefs) do
										if reefFolder.Name == reefName then
											local hitbox = reefFolder:FindFirstChild("Hitbox")
											if hitbox then
												local dx = pRoot.Position.X - hitbox.Position.X
												local dz = pRoot.Position.Z - hitbox.Position.Z
												local distXZ = math.sqrt(dx*dx + dz*dz)
												local radius = math.max(hitbox.Size.X, hitbox.Size.Z) / 2
												if distXZ <= radius and math.abs(pRoot.Position.Y - hitbox.Position.Y) <= (hitbox.Size.Y / 2 + 100) then
													inReef = true
												end
											end
											break
										end
									end
									if not inReef then
										shouldDespawn = true
									end
								end
							end
						end
						
						if shouldDespawn then
							if data.AttackIndicator then data.AttackIndicator:Destroy() end
							mob:Destroy()
							continue
						end
						
						data.State = "Idle"
						hum.WalkSpeed = walkSpeed
						data.LastWanderTime = 0 -- wander immediately
						data.WanderInterval = 0
					else
						hum.WalkSpeed = returnSpeed
						hum:MoveTo(data.SpawnPos)
					end
				elseif state == "Idle" then
					-- Check if Owner is within leashRange of the spawn point
					local playerNearby = false
					local ownerName = mob:GetAttribute("Owner")
					local p = ownerName and Players:FindFirstChild(ownerName)
					if p then
						local char = p.Character
						local pRoot = char and char:FindFirstChild("HumanoidRootPart")
						if pRoot then
							local distToSpawn = (pRoot.Position - data.SpawnPos).Magnitude
							if distToSpawn <= leashRange then
								playerNearby = true
							end
						end
					end
					
					if playerNearby then
						if cfg.Name == "Axolotl" and data.Hibernating then
							data.Hibernating = false
							if data.AttackTrack then
								data.AttackTrack:Stop(0.2)
								data.AttackTrack:AdjustSpeed(1)
							end
							if data.Attack2Track then data.Attack2Track:Play(0) end
							local vfxFolder = game:GetService("ReplicatedStorage"):FindFirstChild("VFX") and game:GetService("ReplicatedStorage").VFX:FindFirstChild("Axolotl")
							if vfxFolder and root then
								local sfx = vfxFolder:FindFirstChild("AxolotlSFX")
								if sfx then
									local s = sfx:Clone()
									s.Parent = root
									s:Play()
									game:GetService("Debris"):AddItem(s, 3)
								end
								local vfxPart = vfxFolder:FindFirstChild("AxolotlVFX")
								if vfxPart then
									local vfxClone = vfxPart:Clone()
									vfxClone.CFrame = root.CFrame
									vfxClone.Parent = workspace
									game:GetService("Debris"):AddItem(vfxClone, 3)
									for _, p in ipairs(vfxClone:GetDescendants()) do
										if p:IsA("ParticleEmitter") then p:Emit(p:GetAttribute("EmitCount") or 30) end
									end
								end
							end
							data.LastDashTime = now - ((cfg.AttackCooldown or 5.0) - 3.0)
						end

						-- Idle behavior: wander around spawn point
						if cfg.Name ~= "Axolotl" then
							if now - data.LastWanderTime > data.WanderInterval then
								data.LastWanderTime = now
								data.WanderInterval = math.random(2, 5)
								
								local angle = math.random() * math.pi * 2
								local distOffset = math.random() * (wanderRadius or 15)
								local targetPos = data.SpawnPos + Vector3.new(math.cos(angle) * distOffset, 0, math.sin(angle) * distOffset)
								hum.WalkSpeed = walkSpeed
								hum:MoveTo(targetPos)
							end
						end
					else
						-- No player nearby, stand still at its spawn position
						if cfg.Name == "Axolotl" then
							if not data.Hibernating then
								data.Hibernating = true
								if data.IdleTrack then data.IdleTrack:Stop(0.2) end
								if data.AttackTrack then
									data.AttackTrack:Play(0.2)
									
									task.spawn(function()
										task.wait(1.35)
										if not root or not root.Parent or not data.Hibernating then return end
										
										local vfxFolder = game:GetService("ReplicatedStorage"):FindFirstChild("VFX") and game:GetService("ReplicatedStorage").VFX:FindFirstChild("Axolotl")
										if vfxFolder then
											local sfx = vfxFolder:FindFirstChild("AxolotlSFX")
											if sfx then
												local s = sfx:Clone()
												s.Parent = root
												s:Play()
												game:GetService("Debris"):AddItem(s, 3)
											end
											local vfxPart = vfxFolder:FindFirstChild("AxolotlVFX")
											if vfxPart then
												local vfxClone = vfxPart:Clone()
												vfxClone.CFrame = root.CFrame
												vfxClone.Parent = workspace
												game:GetService("Debris"):AddItem(vfxClone, 3)
												for _, p in ipairs(vfxClone:GetDescendants()) do
													if p:IsA("ParticleEmitter") then p:Emit(p:GetAttribute("EmitCount") or 30) end
												end
											end
										end
										
										local remain = math.max(0, data.AttackTrack.Length - 1.35)
										task.wait(remain)
										if data.AttackTrack and data.Hibernating then
											data.AttackTrack:AdjustSpeed(0)
											data.AttackTrack.TimePosition = data.AttackTrack.Length * 0.99
										end
									end)
								end
							end
						else
							local dist = (root.Position - data.SpawnPos).Magnitude
							if dist > 2 then
								hum.WalkSpeed = returnSpeed
								hum:MoveTo(data.SpawnPos)
							else
								hum:MoveTo(root.Position)
							end
						end
					end
				end
				
			elseif state == "Chasing" or state == "Dashing" or state == "Roaring" or state == "Attacking" then
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
						if state == "Chasing" then
							hum.WalkSpeed = chaseSpeed
							hum:MoveTo(targetPos)
						end
						
						-- Axolotl Attack Sequence
						if state == "Chasing" and cfg.Name == "Axolotl" and distToPlayer <= (cfg.ContactRange or 50) then
							local attackCd = cfg.AttackCooldown or 3.0
							if now - (data.LastDashTime or 0) >= attackCd then
								data.LastDashTime = now
								data.State = "Attacking"
								
								local lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
								local startCFrame = root.CFrame
								if (lookPos - root.Position).Magnitude > 0.01 then
									startCFrame = CFrame.lookAt(root.Position, lookPos)
								end
								mob:PivotTo(startCFrame)
								
								task.spawn(function()
									local function spawnIndicator(pos, radius, duration)
										local ind = Instance.new("Part")
										ind.Shape = Enum.PartType.Cylinder
										ind.Size = Vector3.new(0.2, 0, 0)
										ind.Color = Color3.fromRGB(255, 0,0) -- pink
										ind.Material = Enum.Material.Neon
										ind.Transparency = 1
										ind.Anchored = true
										ind.CanCollide = false
										ind.CastShadow = false
										
										local rayParams = RaycastParams.new()
										rayParams.FilterDescendantsInstances = {mob, workspace:FindFirstChild("Mobs")}
										local ray = workspace:Raycast(pos, Vector3.new(0, -15, 0), rayParams)
										local floorPos = pos
										if ray then floorPos = ray.Position end
										
										ind.CFrame = CFrame.new(floorPos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi/2)
										ind.Parent = workspace
										
										local hl = Instance.new("Highlight")
										hl.Adornee = ind
										hl.FillColor = ind.Color
										hl.FillTransparency = 0.5
										hl.OutlineTransparency = 1
										hl.Parent = ind
										
										local ts = game:GetService("TweenService")
										ts:Create(ind, TweenInfo.new(0.3), {Size = Vector3.new(0.2, radius*2, radius*2), Transparency = 0.6}):Play()
										
										task.delay(duration, function()
											if ind.Parent then
												ts:Create(ind, TweenInfo.new(0.2), {Transparency = 1}):Play()
												game:GetService("Debris"):AddItem(ind, 0.25)
											end
										end)
									end

									for currentLeap = 1, 3 do
										if not root or not root.Parent or hum.Health <= 0 then break end
	if data.IdleTrack then data.IdleTrack:Stop(0) end
										if data.AttackTrack then data.AttackTrack:Play(0) end

										spawnIndicator(root.Position, cfg.Attack1Radius or 25, 1.33)

										local attackLen = data.AttackTrack and data.AttackTrack.Length or 2.0
										local lockInTime = math.max(0, attackLen - 1.5)
										local teleportPos = nil

										task.spawn(function()
											task.wait(lockInTime)
											if not root or not root.Parent or hum.Health <= 0 then return end
											local finalTarget = targetRoot and targetRoot.Position or targetPos
											teleportPos = Vector3.new(finalTarget.X, root.Position.Y, finalTarget.Z)
											spawnIndicator(teleportPos, cfg.Attack2Radius or 10, 1.66)
										end)

										-- We need to wait 1.35s to reach the 1.33s damage mark
										task.wait(1.35)
										if not root or not root.Parent or hum.Health <= 0 then return end

										-- Attack 1 Damage Check and VFX
										if mob:FindFirstChild("Level") then
											mob.Level.Value = mob.Level.Value + 8
											MobService.UpdateLevelUI(mob)
										end
										local vfxFolder = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("Axolotl")
										if vfxFolder then
											local sfx = vfxFolder:FindFirstChild("AxolotlSFX")
											if sfx then
												local s = sfx:Clone()
												s.Parent = root
												s:Play()
												game:GetService("Debris"):AddItem(s, 3)
											end
											local vfxPart = vfxFolder:FindFirstChild("AxolotlVFX")
											if vfxPart then
												local vfxClone = vfxPart:Clone()
												vfxClone.CFrame = root.CFrame
												vfxClone.Parent = workspace
												game:GetService("Debris"):AddItem(vfxClone, 3)
												for _, p in ipairs(vfxClone:GetDescendants()) do
													if p:IsA("ParticleEmitter") then
														p:Emit(p:GetAttribute("EmitCount") or 30)
													end
												end
											end
										end

										local op = OverlapParams.new()
										op.FilterType = Enum.RaycastFilterType.Exclude
										op.FilterDescendantsInstances = {mob}

										local partsInHitbox = workspace:GetPartBoundsInRadius(root.Position, cfg.Attack1Radius or 25, op)
										local hitPlayers = {}
										for _, part in ipairs(partsInHitbox) do
											local char = part.Parent
											if char and char:FindFirstChild("Humanoid") then
												local hitPlayer = Players:GetPlayerFromCharacter(char)
												if hitPlayer and not hitPlayers[hitPlayer] and mob:GetAttribute("Owner") == hitPlayer.Name or mob:GetAttribute("Owner") == "Global" then
													hitPlayers[hitPlayer] = true
													local targetHum = char:FindFirstChild("Humanoid")
													if targetHum and targetHum.Health > 0 then
														targetHum:TakeDamage(cfg.Attack1Damage or 30)
													end
												end
											end
										end

										-- Now wait for Attack 1 to fully finish
										if data.AttackTrack then
											if data.AttackTrack.IsPlaying then
												data.AttackTrack.Stopped:Wait()
											end
										else
											task.wait(0.67) -- roughly 2.0 total
										end

										if not root or not root.Parent or hum.Health <= 0 then return end

										-- Teleport
										if not teleportPos then
											local p = targetRoot and targetRoot.Position or targetPos
											teleportPos = Vector3.new(p.X, root.Position.Y, p.Z)
										end

										local lookPos2 = Vector3.new(targetRoot and targetRoot.Position.X or teleportPos.X, teleportPos.Y, targetRoot and targetRoot.Position.Z or teleportPos.Z)

										local newCFrame = CFrame.new(teleportPos)
										if (lookPos2 - teleportPos).Magnitude > 0.01 then
											newCFrame = CFrame.lookAt(teleportPos, lookPos2)
										else
											newCFrame = CFrame.new(teleportPos) * root.CFrame.Rotation
										end
										root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
										root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
										mob:PivotTo(newCFrame)

										-- Attack 2
										if data.AttackTrack then data.AttackTrack:Stop(0) end
										if data.Attack2Track then data.Attack2Track:Play(0) end

										-- Wait 0.16s for Attack 2 Damage Check
										task.wait(0.16)
										if not root or not root.Parent or hum.Health <= 0 then return end

										-- Attack 2 Damage Check and VFX
										if mob:FindFirstChild("Level") then
											mob.Level.Value = math.max(1, mob.Level.Value - 8)
											MobService.UpdateLevelUI(mob)
										end
										if vfxFolder then
											local sfx = vfxFolder:FindFirstChild("AxolotlSFX")
											if sfx then
												local s = sfx:Clone()
												s.Parent = root
												s:Play()
												game:GetService("Debris"):AddItem(s, 3)
											end
											local vfxPart = vfxFolder:FindFirstChild("AxolotlVFX")
											if vfxPart then
												local vfxClone = vfxPart:Clone()
												vfxClone.CFrame = root.CFrame
												vfxClone.Parent = workspace
												game:GetService("Debris"):AddItem(vfxClone, 3)
												for _, p in ipairs(vfxClone:GetDescendants()) do
													if p:IsA("ParticleEmitter") then
														p:Emit(p:GetAttribute("EmitCount") or 30)
													end
												end
											end
										end

										local op2 = OverlapParams.new()
										op2.FilterType = Enum.RaycastFilterType.Exclude
										op2.FilterDescendantsInstances = {mob}

										local partsInHitbox2 = workspace:GetPartBoundsInRadius(root.Position, cfg.Attack2Radius or 25, op2)
										local hitPlayers2 = {}
										for _, part in ipairs(partsInHitbox2) do
											local char = part.Parent
											if char and char:FindFirstChild("Humanoid") then
												local hitPlayer = Players:GetPlayerFromCharacter(char)
												if hitPlayer and not hitPlayers2[hitPlayer] and mob:GetAttribute("Owner") == hitPlayer.Name or mob:GetAttribute("Owner") == "Global" then
													hitPlayers2[hitPlayer] = true
													local targetHum = char:FindFirstChild("Humanoid")
													if targetHum and targetHum.Health > 0 then
														targetHum:TakeDamage(cfg.Attack2Damage or 30)
													end
												end
											end
										end

										-- Now wait for Attack 2 to fully finish
										if data.Attack2Track then
											if data.Attack2Track.IsPlaying then
												data.Attack2Track.Stopped:Wait()
											end
											data.Attack2Track:Stop(0)
										else
											task.wait(0.84)
										end


										task.wait(0.5)
									end

									if data.State == "Attacking" then 
										data.State = "Idle" 
										data.LastDashTime = os.clock()
									end
								end)
								
								continue
							end
						end

									-- Geysers Logic
						local geyserCd = cfg.GeyserCooldown or 30.0
						local firstGeyser = (data.LastGeyserTime == 0)
						if state == "Chasing" and data.GeyserTrack and (firstGeyser or now - (data.LastGeyserTime or 0) >= geyserCd) then
							data.LastGeyserTime = now
							data.State = "Geysering"
							hum.WalkSpeed = 0
							local lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
							root.CFrame = CFrame.lookAt(root.Position, lookPos)
							if data.WalkTrack then data.WalkTrack:Stop() end
							if data.IdleTrack then data.IdleTrack:Stop() end
							
							data.GeyserTrack:Play()
							data.GeyserTrack:AdjustSpeed(0.57) -- 1 / 1.75
							
							-- Preload VFX like Dash
							local vfxPreDash = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("PreDash")
							if vfxPreDash then
								local preDashClone = vfxPreDash:Clone()
								preDashClone.CFrame = root.CFrame * CFrame.new(0, -6, 0)
								preDashClone.Parent = workspace
								Debris:AddItem(preDashClone, 2)
								for _, desc in ipairs(preDashClone:GetDescendants()) do
									if desc:IsA("ParticleEmitter") then desc:Emit(desc:GetAttribute("EmitCount") or cfg.PreDashEmit or 20) end
								end
							end
							
							-- Launch Background Geyser Coroutine
							task.spawn(function()
								local duration = cfg.GeyserSpawnDuration or 10.0
								local rate = cfg.GeyserSpawnRate or 5
								local radius = cfg.GeyserSpawnRadius or 80
								local interval = 1 / rate
								local elapsed = 0
								
								local TweenService = game:GetService("TweenService")
								
								while elapsed < duration and root and root.Parent do
									task.wait(interval)
									elapsed = elapsed + interval
									
									task.spawn(function()
										local offsetX = (math.random() - 0.5) * 2 * radius
										local offsetZ = (math.random() - 0.5) * 2 * radius
										local rayParams = RaycastParams.new()
										rayParams.FilterType = Enum.RaycastFilterType.Exclude
										local ignoreList = {mob}
										for _, p in ipairs(Players:GetPlayers()) do
											if p.Character then table.insert(ignoreList, p.Character) end
										end
										rayParams.FilterDescendantsInstances = ignoreList
										
										local rayHit = workspace:Raycast(root.Position + Vector3.new(offsetX, 50, offsetZ), Vector3.new(0, -100, 0), rayParams)
										local groundPos = root.Position + Vector3.new(offsetX, -6, offsetZ)
										if rayHit then groundPos = rayHit.Position end
										
										local gRadius = cfg.GeyserRadius or 2.5
										local indicator = Instance.new("Part")
										indicator.Name = "GeyserIndicator"
										indicator.Shape = Enum.PartType.Cylinder
										indicator.Size = Vector3.new(120, gRadius*3, gRadius*3)
										indicator.CFrame = CFrame.new(groundPos) * CFrame.Angles(0, 0, math.rad(90))
										indicator.Anchored = true
										indicator.CanCollide = false
										indicator.Material = Enum.Material.Neon
										indicator.CastShadow = false
										indicator.Color = Color3.fromRGB(255, 0, 0)
										indicator.Parent = workspace
										
										local vfxFolder = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster")
										local indSfxTemp = vfxFolder and vfxFolder:FindFirstChild("IndicatorSFX")
										if indSfxTemp then
											local sfx = indSfxTemp:Clone()
											sfx.Parent = indicator
											sfx:Play()
										end
										
										local ti = TweenInfo.new(.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
										local tween = TweenService:Create(indicator, ti, {
											Size = Vector3.new(120, 0.2, 0.2),
											Transparency = 1
										})
										tween:Play()
										
										task.wait(2)
										if indicator then indicator:Destroy() end
										
										local vfxFolder = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster")
										local geyserVfx = vfxFolder and vfxFolder:FindFirstChild("Geyser")
										local sfxTemplate = vfxFolder and vfxFolder:FindFirstChild("GeyserSFX")
										
										if geyserVfx then
											local clone = geyserVfx:Clone()
											clone.CFrame = CFrame.new(groundPos)
											clone.Parent = workspace
											Debris:AddItem(clone, (cfg.GeyserDuration or 3) + 2)
											
											local sfx = nil
											if sfxTemplate then
												sfx = sfxTemplate:Clone()
												sfx.Parent = clone
												sfx.Volume = 0
												sfx:Play()
												TweenService:Create(sfx, TweenInfo.new(0.5), {Volume = sfxTemplate.Volume}):Play()
											end
											
											local beams = {}
											for _, desc in ipairs(clone:GetDescendants()) do
												if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then
													desc.Enabled = true
												elseif desc:IsA("Beam") then
													table.insert(beams, desc)
													local origWidth0, origWidth1 = desc.Width0, desc.Width1
													desc:SetAttribute("OrigW0", origWidth0)
													desc:SetAttribute("OrigW1", origWidth1)
													desc.Width0, desc.Width1 = 0, 0
													TweenService:Create(desc, TweenInfo.new(0.5), {Width0 = origWidth0, Width1 = origWidth1}):Play()
												end
											end
											
											local dmgDuration = cfg.GeyserDuration or 3.0
											local dmgElapsed = 0
											local lastDamageTicks = {}
											
											while dmgElapsed < dmgDuration and clone and clone.Parent do
												task.wait(0.1)
												dmgElapsed = dmgElapsed + 0.1
												
												local dmg = cfg.GeyserDamage or 10
												local now = os.clock()
												for _, p in ipairs(Players:GetPlayers()) do
													if mob:GetAttribute("Owner") == p.Name or mob:GetAttribute("Owner") == "Global" then
														local pChar = p.Character
														local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
														local pHum = pChar and pChar:FindFirstChild("Humanoid")
														if pRoot and pHum and pHum.Health > 0 then
															local dist = (pRoot.Position - clone.Position).Magnitude
															if dist <= (gRadius * 2) then
																local lastTick = lastDamageTicks[p] or 0
																if now - lastTick >= 1.0 then
																	lastDamageTicks[p] = now
																	pHum:TakeDamage(dmg)
																end
															end
														end
													end
												end
											end
											
											for _, desc in ipairs(clone:GetDescendants()) do
												if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then
													desc.Enabled = false
												elseif desc:IsA("Beam") then
													TweenService:Create(desc, TweenInfo.new(0.5), {Width0 = 0, Width1 = 0}):Play()
												end
											end
											if sfx then
												TweenService:Create(sfx, TweenInfo.new(0.5), {Volume = 0}):Play()
											end
										end
									end)
								end
							end)
							
							task.delay(data.GeyserTrack.Length / 0.57, function()
								if data.State == "Geysering" then data.State = "Idle" end
							end)
							continue
						end
						
									-- Dash / Roar Logic
						if state == "Chasing" and data.DashTrack and distToPlayer >= 30 and distToPlayer <= 90 then
							local dashCd = cfg.DashCooldown or 5.0
							if now - (data.LastDashTime or 0) >= dashCd then
								data.LastDashTime = now
								
								-- 50/50 Roll for Dash vs Roar if Roar is available
								local attackChoice = 1 -- 1 = Dash, 2 = Roar
								if data.RoarTrack then
									attackChoice = math.random(1, 2)
								end
								
								if attackChoice == 1 then
									data.State = "Dashing"
									hum.WalkSpeed = 0
									local lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
									root.CFrame = CFrame.lookAt(root.Position, lookPos)
									if data.WalkTrack then data.WalkTrack:Stop() end
									if data.IdleTrack then data.IdleTrack:Stop() end
									data.DashTrack:Play()
									
									local vfxYOffset = -6
									local rayParams = RaycastParams.new()
									local ignoreList = {mob}
									for _, p in ipairs(Players:GetPlayers()) do
										if p.Character then table.insert(ignoreList, p.Character) end
									end
									rayParams.FilterDescendantsInstances = ignoreList
									local ray = workspace:Raycast(root.Position, Vector3.new(0, -15, 0), rayParams)
									if ray then vfxYOffset = ray.Position.Y - root.Position.Y end
									
									local vfxPreDash = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("PreDash")
									if vfxPreDash then
										local preDashClone = vfxPreDash:Clone()
										preDashClone.CFrame = root.CFrame * CFrame.new(0, vfxYOffset, 0)
										preDashClone.Parent = workspace
										Debris:AddItem(preDashClone, 2)
										for _, desc in ipairs(preDashClone:GetDescendants()) do
											if desc:IsA("ParticleEmitter") then desc:Emit(desc:GetAttribute("EmitCount") or cfg.PreDashEmit or 20) end
										end
									end
									
									local startFlatPos = Vector3.new(root.Position.X, 0, root.Position.Z)
									local targetFlatPos = Vector3.new(targetPos.X, 0, targetPos.Z)
									local flatDist = (targetFlatPos - startFlatPos).Magnitude
									local dashDirection = (targetFlatPos - startFlatPos).Unit
									if flatDist == 0 then dashDirection = Vector3.new(0,0,1) end
									
									-- Raycast to prevent dashing through walls
									local rayParams = RaycastParams.new()
									rayParams.FilterType = Enum.RaycastFilterType.Exclude
									local ignoreList = {mob}
									for _, p in ipairs(Players:GetPlayers()) do
										if p.Character then table.insert(ignoreList, p.Character) end
									end
									rayParams.FilterDescendantsInstances = ignoreList
									
									local rayHit = workspace:Raycast(root.Position, dashDirection * flatDist, rayParams)
									if rayHit then
										-- Stop right in front of the wall
										flatDist = math.max(0, (rayHit.Position - root.Position).Magnitude - (root.Size.Z/2 + 1))
									end
									
									local warningPart = Instance.new("Part")
									warningPart.Name = "DashIndicator"
									warningPart.Size = Vector3.new(14, 0.2, 0)
									warningPart.Color = Color3.fromRGB(255, 0, 0)
									warningPart.Material = Enum.Material.Neon
									warningPart.Transparency = 0.5
									warningPart.Anchored = true
									warningPart.CanCollide = false
									warningPart.CastShadow = false
									local floorCFrame = root.CFrame * CFrame.new(0, vfxYOffset + 0.1, 0)
									warningPart.CFrame = floorCFrame
									warningPart.Parent = workspace
									
									local ts = game:GetService("TweenService")
									local ti = TweenInfo.new(0.9, Enum.EasingStyle.Linear)
									local goalCFrame = floorCFrame * CFrame.new(0, 0, -flatDist/2)
									local goalSize = Vector3.new(14, 0.2, flatDist)
									local tween = ts:Create(warningPart, ti, {Size = goalSize, CFrame = goalCFrame})
									tween:Play()
									Debris:AddItem(warningPart, 1.1)
									
									task.delay(0.9, function()
										if not root or not root.Parent or hum.Health <= 0 then return end
										
										local dashSfx = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("DashSFX")
										if dashSfx then
											local s = dashSfx:Clone()
											s.Parent = root
											s:Play()
											Debris:AddItem(s, 2)
										end
										
										local dash1Vfx = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("Dash1")
										if dash1Vfx then
											local d1 = dash1Vfx:Clone()
											d1.CFrame = root.CFrame * CFrame.new(0, 0, -3)
											d1.Parent = workspace
											Debris:AddItem(d1, 2)
											for _, desc in ipairs(d1:GetDescendants()) do
												if desc:IsA("ParticleEmitter") then desc:Emit(desc:GetAttribute("EmitCount") or cfg.DashEmitAmount or 20) end
											end
										end
										
										local origAnchored = root.Anchored
										root.Anchored = true
										
										-- Prevent flinging by disabling collisions during the anchored dash
										local collisionStates = {}
										for _, p in ipairs(mob:GetDescendants()) do
											if p:IsA("BasePart") then
												collisionStates[p] = p.CanCollide
												p.CanCollide = false
											end
										end
										
										-- Dash Damage Check using the DashIndicator box
										local op = OverlapParams.new()
										op.FilterType = Enum.RaycastFilterType.Exclude
										op.FilterDescendantsInstances = {mob}
										
										local dmg = cfg.DashDamage or data.Damage and data.Damage.Value or 30
										local partsInHitbox = workspace:GetPartBoundsInBox(goalCFrame, goalSize, op)
										local hitPlayers = {}
										
										for _, part in ipairs(partsInHitbox) do
											local char = part.Parent
											if char and char:FindFirstChild("Humanoid") then
												local hitPlayer = Players:GetPlayerFromCharacter(char)
												if hitPlayer and not hitPlayers[hitPlayer] and mob:GetAttribute("Owner") == hitPlayer.Name or mob:GetAttribute("Owner") == "Global" then
													hitPlayers[hitPlayer] = true
													local targetRoot = char:FindFirstChild("HumanoidRootPart")
													local targetHum = char:FindFirstChild("Humanoid")
													if targetHum and targetHum.Health > 0 then
														targetHum:TakeDamage(dmg)
													end
												end
											end
										end
										
										local dashInfo = TweenInfo.new(cfg.DashDuration or 0.2, Enum.EasingStyle.Linear)
										local finalCFrame = root.CFrame + (dashDirection * flatDist)
										local dashTween = ts:Create(root, dashInfo, {CFrame = finalCFrame})
										dashTween:Play()
										task.delay(cfg.DashDuration or 0.2, function()
											if root and root.Parent then 
												root.Anchored = origAnchored 
												for p, state in pairs(collisionStates) do
													if p and p.Parent then p.CanCollide = state end
												end
											end
											if data.DashTrack then data.DashTrack:Stop() end
											if data.State == "Dashing" then data.State = "Idle" end
										end)
									end)
								else
									-- Roar Logic
									data.State = "Roaring"
									hum.WalkSpeed = 0
									local lookPos = Vector3.new(targetPos.X, root.Position.Y, targetPos.Z)
									root.CFrame = CFrame.lookAt(root.Position, lookPos)
									if data.WalkTrack then data.WalkTrack:Stop() end
									if data.IdleTrack then data.IdleTrack:Stop() end
									data.RoarTrack:Play()
									
									local vfxYOffset = -6
									local rayParams = RaycastParams.new()
									local ignoreList = {mob}
									for _, p in ipairs(Players:GetPlayers()) do
										if p.Character then table.insert(ignoreList, p.Character) end
									end
									rayParams.FilterDescendantsInstances = ignoreList
									local ray = workspace:Raycast(root.Position, Vector3.new(0, -15, 0), rayParams)
									if ray then vfxYOffset = ray.Position.Y - root.Position.Y end
									
									local vfxPreDash = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("PreDash")
									if vfxPreDash then
										local preDashClone = vfxPreDash:Clone()
										preDashClone.CFrame = root.CFrame * CFrame.new(0, vfxYOffset, 0)
										preDashClone.Parent = workspace
										Debris:AddItem(preDashClone, 2)
										for _, desc in ipairs(preDashClone:GetDescendants()) do
											if desc:IsA("ParticleEmitter") then desc:Emit(desc:GetAttribute("EmitCount") or cfg.PreDashEmit or 20) end
										end
									end
									
									task.delay(cfg.FireballDelay or 0.6, function()
										if not root or not root.Parent or hum.Health <= 0 then return end
										
										local roarSfx = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("RoarSFX")
										if roarSfx then
											local s = roarSfx:Clone()
											s.Parent = root
											s:Play()
											Debris:AddItem(s, 3)
										end
										
										local explodeVFX = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("Explode")
										if explodeVFX then
											local att = explodeVFX:FindFirstChildOfClass("Attachment")
											if att then
												local c = att:Clone()
												c.Parent = root
												for _, desc in ipairs(c:GetDescendants()) do
													if desc:IsA("ParticleEmitter") then
														desc:Emit(desc:GetAttribute("EmitCount") or cfg.FireballExplosionEmit or 20)
													end
												end
												Debris:AddItem(c, 2)
											end
										end
										
										local orby = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("SunkissedArt") and ReplicatedStorage.VFX.SunkissedArt:FindFirstChild("Orby1")
										if orby then
											local orb = orby:Clone()
											orb.CFrame = root.CFrame * CFrame.new(0, 0, -5)
											orb.Anchored = false
											orb.CanCollide = false
											orb.Massless = true
											orb.Parent = workspace
											
											for _, desc in ipairs(orb:GetDescendants()) do
												if desc:IsA("ParticleEmitter") then
													local newKeypoints = {}
													for _, kp in ipairs(desc.Size.Keypoints) do
														table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, kp.Value * 2, kp.Envelope * 2))
													end
													desc.Size = NumberSequence.new(newKeypoints)
													desc.Enabled = true
												elseif desc:IsA("Trail") then
													desc.Enabled = true
												end
											end
											
											local att = Instance.new("Attachment", orb)
											local lv = Instance.new("LinearVelocity", orb)
											lv.Attachment0 = att
											lv.MaxForce = math.huge
											lv.VectorVelocity = root.CFrame.LookVector * (cfg.FireballSpeed or 10)
											lv.RelativeTo = Enum.ActuatorRelativeTo.World
											
											local hitPlayers = {}
											local startTime = os.clock()
											local connection
											connection = game:GetService("RunService").Heartbeat:Connect(function()
												if not orb or not orb.Parent then
													if connection then connection:Disconnect() end
													return
												end
												
												local nowTime = os.clock()
												for _, p in ipairs(Players:GetPlayers()) do
													local pChar = p.Character
													local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
													local pHum = pChar and pChar:FindFirstChild("Humanoid")
													if pRoot and pHum and pHum.Health > 0 then
														if (pRoot.Position - orb.Position).Magnitude <= (cfg.FireballTickRadius or 10) then
															local lastHit = hitPlayers[p.UserId] or 0
															if nowTime - lastHit >= 0.5 then
																hitPlayers[p.UserId] = nowTime
																pHum:TakeDamage(cfg.FireballTickDamage or 10)
															end
														end
													end
												end
												
												if nowTime - startTime >= (cfg.FireballDuration or 4.0) then
													if connection then connection:Disconnect() end
													if lv then lv:Destroy() end
													orb.Anchored = true
													
													for _, p in ipairs(Players:GetPlayers()) do
														if mob:GetAttribute("Owner") == p.Name or mob:GetAttribute("Owner") == "Global" then
															local pChar = p.Character
															local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
															local pHum = pChar and pChar:FindFirstChild("Humanoid")
															if pRoot and pHum and pHum.Health > 0 then
																if (pRoot.Position - orb.Position).Magnitude <= (cfg.FireballExplosionRadius or 20) then
																	pHum:TakeDamage(cfg.FireballExplosionDamage or 30)
																end
															end
														end
													end
													
													for _, desc in ipairs(orb:GetDescendants()) do
														if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then
															desc.Enabled = false
														end
													end
													
													local skFolder = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("SunkissedArt")
													local explodeAtt = skFolder and skFolder:FindFirstChild("Explode")
													if explodeAtt then
														local expClone = explodeAtt:Clone()
														expClone.Parent = orb
														
														for _, p in ipairs(expClone:GetChildren()) do
															if p:IsA("ParticleEmitter") then
																p.Speed = NumberRange.new(p.Speed.Min * 2, p.Speed.Max * 2)
																
																local newKeypoints = {}
																for _, kp in ipairs(p.Size.Keypoints) do
																	table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, kp.Value * 2, kp.Envelope * 2))
																end
																p.Size = NumberSequence.new(newKeypoints)
																
																local burst = p:GetAttribute("EmitCount") or p:GetAttribute("Count") or 30
																p:Emit(math.max(1, math.floor(burst)))
															end
														end
													end
													
													local sfx = (skFolder and skFolder:FindFirstChild("SunkissedArt4")) or ReplicatedStorage:FindFirstChild("SunkissedArt4")
													if sfx and sfx:IsA("Sound") then
														local s = sfx:Clone()
														s.Parent = orb
														s:Play()
													end
													
													orb.Transparency = 1
													Debris:AddItem(orb, 4)
												end
											end)
										end
										
										task.delay(1, function()
											if data.RoarTrack then data.RoarTrack:Stop() end
											if data.State == "Roaring" then data.State = "Idle" end
										end)
									end)
								end
								
								continue -- Skip the contact check for this heartbeat
							end
						end
						
						-- Contact damage check: deal damage to player on touch/proximity
						local hitbox = mob:FindFirstChild("Hitbox", true)
						local triggerAttack = false
						
						if hitbox and hitbox:IsA("BasePart") then
							local op = OverlapParams.new()
							op.FilterDescendantsInstances = {targetChar}
							op.FilterType = Enum.RaycastFilterType.Include
							local parts = workspace:GetPartsInPart(hitbox, op)
							
							if now - (data.LastHitboxDebug or 0) > 1 then
								data.LastHitboxDebug = now
								print("DEBUG: Hitbox exists. Intersection count:", #parts, "Hitbox Size:", hitbox.Size, "Hitbox Position:", hitbox.Position)
							end
							
							if #parts > 0 then
								triggerAttack = true
							end
						else
							if now - (data.LastHitboxDebug or 0) > 1 then
								data.LastHitboxDebug = now
								print("DEBUG: No Hitbox found. distToPlayer:", distToPlayer, "contactRange:", contactRange)
							end
							
							if distToPlayer <= contactRange then
								triggerAttack = true
							end
						end
						
						if triggerAttack and cfg.Name ~= "Axolotl" then
							if now - (data.LastDamageTime or 0) >= damageCooldown then
								data.LastDamageTime = now
								
								if data.AttackTrack or data.SunkissedTrack1 then
									local slamCd = 20.0
									if data.AttackTrack and now - (data.LastSlamTime or 0) >= slamCd then
										data.LastSlamTime = now
										
										print("DEBUG: AttackTrack found! Triggering attack sequence for", mob.Name)

										-- Start custom attack sequence
										data.State = "Attacking"
										hum.WalkSpeed = 0
										hum:MoveTo(root.Position)
										
										local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
										if root and targetRoot then
											local lookPos = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
											root.CFrame = CFrame.lookAt(root.Position, lookPos)
										end
										
										-- Stop other animations
										if data.WalkTrack then data.WalkTrack:Stop() end
										if data.IdleTrack then data.IdleTrack:Stop() end
										
										data.AttackTrack:Play()
										data.AttackTrack:AdjustSpeed(1 / 1.5)
										
										local vfxYOffset = -6
										local rayParams = RaycastParams.new()
										local ignoreList = {mob}
										for _, p in ipairs(Players:GetPlayers()) do
											if p.Character then table.insert(ignoreList, p.Character) end
										end
										rayParams.FilterDescendantsInstances = ignoreList
										local ray = workspace:Raycast(root.Position, Vector3.new(0, -15, 0), rayParams)
										if ray then vfxYOffset = ray.Position.Y - root.Position.Y end
										
										local vfxPreDash = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("PreDash")
										if vfxPreDash then
											local preDashClone = vfxPreDash:Clone()
											preDashClone.CFrame = root.CFrame * CFrame.new(0, vfxYOffset, 0)
											preDashClone.Parent = workspace
											Debris:AddItem(preDashClone, 2)
											for _, desc in ipairs(preDashClone:GetDescendants()) do
												if desc:IsA("ParticleEmitter") then desc:Emit(desc:GetAttribute("EmitCount") or 20) end
											end
										end
										
										task.delay(1.05, function()
											if not root or not root.Parent or hum.Health <= 0 then return end
											local vfxSlam = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("Slam")
											if vfxSlam and vfxSlam:IsA("Sound") then
												local s = vfxSlam:Clone()
												s.Parent = root
												s:Play()
												Debris:AddItem(s, s.TimeLength + 1)
											end
											
											local vfxEnd = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("LavaMonster") and ReplicatedStorage.VFX.LavaMonster:FindFirstChild("End")
											local vfxYOffset = -6
											local rayParams = RaycastParams.new()
											local ignoreList = {mob}
											for _, p in ipairs(Players:GetPlayers()) do
												if p.Character then table.insert(ignoreList, p.Character) end
											end
											rayParams.FilterDescendantsInstances = ignoreList
											local ray = workspace:Raycast(root.Position, Vector3.new(0, -15, 0), rayParams)
											if ray then vfxYOffset = ray.Position.Y - root.Position.Y end
											
											local aoePos = root.CFrame * CFrame.new(0, vfxYOffset, 0)
											if vfxEnd then
												local endClone = vfxEnd:Clone()
												endClone.CFrame = aoePos
												endClone.Parent = workspace
												Debris:AddItem(endClone, 3)
												for _, desc in ipairs(endClone:GetDescendants()) do
													if desc:IsA("ParticleEmitter") then desc:Emit(desc:GetAttribute("EmitCount") or 20) end
												end
											end
											
											for _, p in ipairs(Players:GetPlayers()) do
												if mob:GetAttribute("Owner") == p.Name or mob:GetAttribute("Owner") == "Global" then
													local pChar = p.Character
													local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
													local pHum = pChar and pChar:FindFirstChild("Humanoid")
													if pRoot and pHum and pHum.Health > 0 then
														if (pRoot.Position - aoePos.Position).Magnitude <= (cfg.AoERange or 25) then
															pHum:TakeDamage(cfg.Damage or 50)
														end
													end
												end
											end
										end)
										
										task.delay(cfg.AttackCooldown or 2.0, function()
											if data.State == "Attacking" then
												data.State = "Idle"
												if hum and hum.Parent then
													hum.WalkSpeed = cfg.WalkSpeed or 8
												end
											end
										end)
									else
										-- Basic Attack Combo (Sunkissed Art or Skeleton M1)
										data.State = "Attacking"
										hum.WalkSpeed = 0
										hum:MoveTo(root.Position)
										
										local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
										if root and targetRoot then
											local lookPos = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
											root.CFrame = CFrame.lookAt(root.Position, lookPos)
										end
										
										if data.WalkTrack then data.WalkTrack:Stop() end
										if data.IdleTrack then data.IdleTrack:Stop() end
										if data.RunTrack then data.RunTrack:Stop() end

										-- Determine combo phase count (Skeleton uses 3, others 2)
										local maxPhase = data.SunkissedTrack3 and 3 or 2
										data.SunkissedComboPhase = (data.SunkissedComboPhase or 0) + 1
										if data.SunkissedComboPhase > maxPhase then data.SunkissedComboPhase = 1 end
										
										local phase = data.SunkissedComboPhase
										-- Stop whichever tracks aren't about to play, then restart the active one
										local m1Tracks = {data.SunkissedTrack1, data.SunkissedTrack2, data.SunkissedTrack3}
										for i, t in ipairs(m1Tracks) do
											if t and i ~= phase then t:Stop(0) end
										end
										if phase == 1 and data.SunkissedTrack1 then
											data.SunkissedTrack1:Stop(0)
											data.SunkissedTrack1:Play(0)
										elseif phase == 2 and data.SunkissedTrack2 then
											data.SunkissedTrack2:Stop(0)
											data.SunkissedTrack2:Play(0)
										elseif phase == 3 and data.SunkissedTrack3 then
											data.SunkissedTrack3:Stop(0)
											data.SunkissedTrack3:Play(0)
										end
										
										task.delay(0.3, function()
											if not root or not root.Parent or hum.Health <= 0 then return end
											
											-- === SKELETON M1 VFX ===
											if cfg.Name == "Skeleton" then
												local skelVFX = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("Skeleton")
												if skelVFX then
													-- Pick hit VFX by phase: 1→Hit4, 2→Hit4Return, 3→Hits13
													local hitVfxNames = { "Hit4", "Hit4Return", "Hits13" }
													local hitVfxName = hitVfxNames[phase] or "Hit4"
													local hitVfx = skelVFX:FindFirstChild(hitVfxName)
													if hitVfx then
														local clone = hitVfx:Clone()
														if clone:IsA("BasePart") then
															clone.CFrame = root.CFrame * CFrame.new(0, 0, -3)
															clone.Anchored = true
															clone.CanCollide = false
															clone.Parent = workspace
														else
															clone.Parent = root
														end
														for _, desc in ipairs(clone:GetDescendants()) do
															if desc:IsA("ParticleEmitter") then
																desc:Emit(desc:GetAttribute("EmitCount") or 20)
															end
														end
														Debris:AddItem(clone, 2)
													end
													-- Also burst Hits13 on phases 1 and 2 for multi-hit feel
													if phase ~= 3 then
														local hits13 = skelVFX:FindFirstChild("Hits13")
														if hits13 then
															local c = hits13:Clone()
															if c:IsA("BasePart") then
																c.CFrame = root.CFrame * CFrame.new(0, 0, -3)
																c.Anchored = true
																c.CanCollide = false
																c.Parent = workspace
															else
																c.Parent = root
															end
															for _, desc in ipairs(c:GetDescendants()) do
																if desc:IsA("ParticleEmitter") then desc:Emit(desc:GetAttribute("EmitCount") or 15) end
															end
															Debris:AddItem(c, 2)
														end
													end
												end

												-- Skeleton M1 damage: 5x5x5 hitbox 3 studs ahead (mirrors Executioner)
												local hitPos = root.CFrame * CFrame.new(0, 0, -3)
												local op = OverlapParams.new()
												op.FilterType = Enum.RaycastFilterType.Exclude
												op.FilterDescendantsInstances = {mob}
												local partsHit = workspace:GetPartBoundsInBox(hitPos, Vector3.new(5, 5, 5), op)
												local hitChars = {}
												for _, part in ipairs(partsHit) do
													local char = part.Parent
													if char and char:FindFirstChild("Humanoid") and not hitChars[char] then
														local hitPlayer = Players:GetPlayerFromCharacter(char)
														if hitPlayer and (mob:GetAttribute("Owner") == hitPlayer.Name or mob:GetAttribute("Owner") == "Global") then
															hitChars[char] = true
															local pHum = char:FindFirstChild("Humanoid")
															if pHum and pHum.Health > 0 then
																pHum:TakeDamage(cfg.Damage or 15)
															end
														end
													end
												end
												
											else
												-- === SUNKISSED ART VFX (original) ===
												local rsSK = ReplicatedStorage:FindFirstChild("SunkissedArt")
												local soundName = "SunkissedArt" .. tostring(phase)
												local sfx = (rsSK and rsSK:FindFirstChild(soundName)) or ReplicatedStorage:FindFirstChild(soundName)
												if sfx and sfx:IsA("Sound") then
													local s = sfx:Clone()
													s.Volume = s.Volume > 0 and s.Volume or 0.5
													s.Parent = root
													s:Play()
													Debris:AddItem(s, 2)
												end
												
												local skVFX = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("SunkissedArt")
												local hitVfxName = phase == 1 and "FirstHit" or "SecondHit"
												local hitVfx = (skVFX and skVFX:FindFirstChild(hitVfxName)) or (rsSK and rsSK:FindFirstChild(hitVfxName))
												if hitVfx then
													local hitClone = hitVfx:Clone()
													if hitClone:IsA("BasePart") then
														hitClone.CFrame = root.CFrame
														hitClone.Anchored = true
														hitClone.CanCollide = false
														hitClone.Massless = true
														hitClone.Parent = workspace
													else
														hitClone.Parent = root
													end
													
													for _, p in ipairs(hitClone:GetChildren()) do
														if p:IsA("ParticleEmitter") then
															p.Speed = NumberRange.new(p.Speed.Min * 2, p.Speed.Max * 2)
															local newKeypoints = {}
															for _, kp in ipairs(p.Size.Keypoints) do
																table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, kp.Value * 2, kp.Envelope * 2))
															end
															p.Size = NumberSequence.new(newKeypoints)
															
															if phase == 1 then
																local burstAmount = (p:GetAttribute("EmitCount") or p:GetAttribute("Count") or 25)
																p:Emit(math.max(1, math.floor(burstAmount)))
															elseif phase == 2 then
																p.Rate = math.max(1, math.floor(p.Rate / 2))
																p.Enabled = true
															end
														end
													end
													
													if phase == 2 then
														task.delay(0.3, function()
															if hitClone and hitClone.Parent then
																for _, p in ipairs(hitClone:GetChildren()) do
																	if p:IsA("ParticleEmitter") then
																		p.Enabled = false
																	end
																end
															end
														end)
													end
													
													Debris:AddItem(hitClone, phase == 1 and 3 or 4)
												end
												
												local basicAoeRange = 12
												local basicDamage = 25
												local basicHitPos = root.CFrame * CFrame.new(0, 0, -6)
												
												for _, p in ipairs(Players:GetPlayers()) do
													if mob:GetAttribute("Owner") == p.Name or mob:GetAttribute("Owner") == "Global" then
														local pChar = p.Character
														local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
														local pHum = pChar and pChar:FindFirstChild("Humanoid")
														if pRoot and pHum and pHum.Health > 0 then
															if (pRoot.Position - basicHitPos.Position).Magnitude <= basicAoeRange then
																pHum:TakeDamage(basicDamage)
															end
														end
													end
												end
											end
										end)
										
										task.delay(0.8, function()
											if data.State == "Attacking" then
												data.State = "Idle"
												if hum and hum.Parent then
													hum.WalkSpeed = cfg.WalkSpeed or 8
												end
											end
										end)
									end
								else
									print("DEBUG: AttackTrack is nil! Falling back to standard contact damage.")
									-- Standard contact damage
									local targetPlayer = Players:GetPlayerFromCharacter(data.Target.Character)
									if targetPlayer and mob:GetAttribute("Owner") == targetPlayer.Name or mob:GetAttribute("Owner") == "Global" then
										local dmg = data.Damage and data.Damage.Value or (cfg.Damage or 10)
										targetHum:TakeDamage(dmg)
									end
								end
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
			elseif state == "Attacking" then
				-- Immobilized during attack sequence, do nothing
			end
		end
	end)
	
	-- Command to spawn a test mob (e.g. /spawnmob Frog 1)
	Players.PlayerAdded:Connect(function(p)
		p.Chatted:Connect(function(msg)
			if msg:sub(1, 9) == "/spawnmob" then
				local args = string.split(msg, " ")
				local levelAmount = tonumber(args[#args])
				local query = ""
				if levelAmount then
					query = table.concat(args, " ", 2, #args - 1)
				else
					levelAmount = 1
					query = table.concat(args, " ", 2, #args)
				end
				if query == "" then query = "Frog" end
				
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
					
					local newMob = MobService.SpawnMob(cf, health, levelAmount, template, damage, mobType, mobConfig)
					if newMob then
						newMob:SetAttribute("Owner", p.Name)
					end
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
			
			local cleanType = string.gsub(rawType, "^%s*", "")
			cleanType = string.gsub(cleanType, "%s*$", "")
			if string.len(cleanType) == 0 then return nil end
			
			local capitalized = string.upper(cleanType:sub(1,1)) .. string.lower(cleanType:sub(2))
			return capitalized
		end

		local Shared = ReplicatedStorage:FindFirstChild("Shared")
		if Shared and Shared:FindFirstChild("MobSpawnConfig") then
			local MobSpawnConfig = require(Shared.MobSpawnConfig)
			
			local function getPlayerReef(player, allReefs)
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then return nil end
				for _, reefFolder in ipairs(allReefs) do
					local reefName = reefFolder.Name
					if reefFolder then
						local hitbox = reefFolder:FindFirstChild("Hitbox")
						if hitbox then
							local dx = hrp.Position.X - hitbox.Position.X
							local dz = hrp.Position.Z - hitbox.Position.Z
							local distXZ = math.sqrt(dx*dx + dz*dz)
							local radius = math.max(hitbox.Size.X, hitbox.Size.Z) / 2
							if distXZ <= radius and math.abs(hrp.Position.Y - hitbox.Position.Y) <= (hitbox.Size.Y / 2 + 100) then
								return reefName
							end
						else
							-- No Hitbox found! Dynamically calculate bounds from all parts in the reef.
							local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
							local hasParts = false
							for _, part in ipairs(reefFolder:GetDescendants()) do
								if part:IsA("BasePart") then
									minX = math.min(minX, part.Position.X)
									minZ = math.min(minZ, part.Position.Z)
									maxX = math.max(maxX, part.Position.X)
									maxZ = math.max(maxZ, part.Position.Z)
									hasParts = true
								end
							end
							if hasParts then
								-- AABB check with small padding instead of massive radius
								local padding = 15
								if hrp.Position.X >= minX - padding and hrp.Position.X <= maxX + padding and
								   hrp.Position.Z >= minZ - padding and hrp.Position.Z <= maxZ + padding then
									return reefName
								end
							end
						end
					end
				end
				return nil
			end

			local activeSpawns = {} -- Map: PlayerName -> { spawnPart -> mob }
			while task.wait(2) do
				local allReefs = {}
				local reefsFolder = workspace:FindFirstChild("Reefs")
				if reefsFolder then
					for _, child in ipairs(reefsFolder:GetChildren()) do
						if child.Name:match("Reef$") then
							table.insert(allReefs, child)
						end
					end
				end
				
				local globalSpawnsFolder = workspace:FindFirstChild("GlobalSpawns")
				if globalSpawnsFolder then
					table.insert(allReefs, globalSpawnsFolder)
				end
				
				local occupiedReefs = {}
				for _, player in ipairs(Players:GetPlayers()) do
					local r = getPlayerReef(player, allReefs)
					if r then occupiedReefs[r] = true end
				end
				
				local iterateList = {}
				table.insert(iterateList, {Name = "Global", IsGlobal = true})
				for _, player in ipairs(Players:GetPlayers()) do
					table.insert(iterateList, {Name = player.Name, Character = player.Character, IsGlobal = false})
				end
				
				for _, pData in ipairs(iterateList) do
					local pName = pData.Name
					local isGlobalPass = pData.IsGlobal
					
					activeSpawns[pName] = activeSpawns[pName] or {}
					local pSpawns = activeSpawns[pName]
					
					local currentReef = nil
					if isGlobalPass then
						currentReef = "GLOBAL_PASS"
					else
						currentReef = getPlayerReef(pData, allReefs)
					end
					
					-- if not isGlobalPass and not currentReef then print("[DEBUG SPAWNER] Player " .. pName .. " is not inside any reef.") end
					
					for _, reefFolder in ipairs(allReefs) do
						local reefName = reefFolder.Name
						if reefFolder then
							local configs = MobSpawnConfig.Reefs[reefName] or {}
							for _, child in ipairs(reefFolder:GetDescendants()) do
								if not child:IsA("BasePart") then continue end -- ignore GUIs, scripts, etc.
								local attrMob = child:GetAttribute("Mob") or child:GetAttribute("MobType")
								local mobType = attrMob or getStandardMobType(child.Name)
								if mobType then
									local spawnPart = child
									local existingMob = pSpawns[spawnPart]
									
									if not existingMob or not existingMob.Parent or not existingMob:FindFirstChild("Health") or existingMob.Health.Value <= 0 then
										local config, configId = nil, nil
										for idx, cfg in ipairs(configs) do
											if string.lower(cfg.SpawnPartName) == string.lower(spawnPart.Name) then
												config, configId = cfg, idx
												break
											end
										end
										
										if config and config.Template then mobType = config.Template end
										if attrMob then mobType = attrMob end
										
										local mobConfig = nil
										for key, cfg in pairs(MobConfig.MobTypes) do
											if string.lower(key) == string.lower(mobType) then
												mobType = key; mobConfig = cfg; break
											end
										end
										if not mobConfig then mobConfig = MobConfig.MobTypes[mobType] end
										
										-- Filter based on pass
										if isGlobalPass then
											if not (mobConfig and mobConfig.IsGlobal) then continue end
										else
											if mobConfig and mobConfig.IsGlobal then continue end
										end
										
										local lastDeath = spawnPart:GetAttribute("LastDeathTime_" .. pName) or 0
										local respawnTime = (config and config.RespawnTime) or (mobConfig and mobConfig.RespawnTime) or 5
										
										local elapsed = os.time() - lastDeath
										local timeLeft = respawnTime - elapsed
										
										local guiName = "RespawnGui_" .. pName
										
										if timeLeft > 0 then
											-- Ensure GUI updates if they aren't fully spawned yet
											local billboard = spawnPart:FindFirstChild(guiName)
											if not billboard then
												local templateUI = ReplicatedStorage:FindFirstChild("Mobs") and ReplicatedStorage.Mobs:FindFirstChild("RespawnUI")
												if templateUI then
													billboard = templateUI:Clone()
													billboard.Name = guiName
													billboard.Parent = spawnPart
												end
											end
											if billboard then
												local textLabel = billboard:FindFirstChild("Health") and billboard.Health:FindFirstChild("RespawnsIn")
												if textLabel then
													textLabel.Text = "Respawns in: " .. math.ceil(timeLeft) .. "s"
												end
											end
										else
											local shouldSpawn = false
											if isGlobalPass then
												if reefName == "GlobalSpawns" or occupiedReefs[reefName] then
													shouldSpawn = true
												end
											elseif not isGlobalPass and currentReef == reefName then
												shouldSpawn = true
											end
											
											if shouldSpawn then
											print("[DEBUG SPAWNER] Processing spawn for " .. mobType .. " in " .. reefName)
											if elapsed >= respawnTime then
												print("[DEBUG SPAWNER] Respawn time met for " .. mobType .. ". Spawning!")
												local billboard = spawnPart:FindFirstChild(guiName)
												if billboard then billboard:Destroy() end
												
												local templateFolder = ReplicatedStorage:FindFirstChild("Mobs")
												local templateName = attrMob or (config and config.Template) or (mobConfig and mobConfig.Name) or mobType
												local template = templateFolder and templateFolder:FindFirstChild(templateName)
												
												local attrHealth = spawnPart:GetAttribute("Health")
												local attrLevel = spawnPart:GetAttribute("Level")
												local attrDamage = spawnPart:GetAttribute("Damage")
												
												local health = attrHealth or (config and config.Health) or (mobConfig and mobConfig.Health) or 50
												local damage = attrDamage or (config and config.Damage) or (mobConfig and mobConfig.Damage) or 10
												local level = attrLevel or (config and config.Level) or (mobConfig and mobConfig.Level) or 1
												
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
												if randomPart:IsA("BasePart") then spawnCF = randomPart.CFrame * CFrame.new(0, 10, 0)
												elseif randomPart:IsA("Model") then spawnCF = randomPart:GetPivot() * CFrame.new(0, 10, 0) end
												
												if spawnCF then
													local newMob = MobService.SpawnMob(spawnCF, health, level, template, damage, mobType, mobConfig)
													if newMob then
														if configId then newMob:SetAttribute("ReefConfigId", configId) end
														newMob:SetAttribute("ReefName", reefName)
														newMob:SetAttribute("SpawnPartName", spawnPart.Name)
														
														local spawnPartRef = Instance.new("ObjectValue")
														spawnPartRef.Name = "SpawnPartRef"
														spawnPartRef.Value = spawnPart
														spawnPartRef.Parent = newMob
														
														newMob:SetAttribute("Owner", pName)
														
														if isGlobalPass then
															local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
															if Remotes then
																local sysChat = Remotes:FindFirstChild("SystemChatEvent")
																if not sysChat then
																	sysChat = Instance.new("RemoteEvent")
																	sysChat.Name = "SystemChatEvent"
																	sysChat.Parent = Remotes
																end
																if mobType == "LavaMonster" then
																	sysChat:FireAllClients("<font color='#FFA500'>[SERVER]: The water rises in temperature.</font>")
																end
															end
														end
														
														print("MobService: Spawned " .. (isGlobalPass and "global" or "instanced") .. " " .. mobType .. " for " .. pName)
															pSpawns[spawnPart] = newMob
														end
													end
												end
											else
												-- Not in reef, just clean up GUI if time has elapsed
												local billboard = spawnPart:FindFirstChild(guiName)
												if billboard then billboard:Destroy() end
											end
										end
									else
										local guiName = "RespawnGui_" .. pName
										local billboard = spawnPart:FindFirstChild(guiName)
										if billboard then billboard:Destroy() end
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
