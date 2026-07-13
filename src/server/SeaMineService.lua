local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
local TokenConfig = require(ReplicatedStorage.Shared.TokenConfig)
local ChanceConfig = require(ReplicatedStorage.Shared.ChanceConfig)

local SeaMineService = {}

local function getFieldFolder(fieldName)
	if not fieldName then return nil end
	
	local folder = Workspace:FindFirstChild(fieldName)
	if folder then return folder end
	
	local reefsFolder = Workspace:FindFirstChild("Reefs")
	if reefsFolder then
		folder = reefsFolder:FindFirstChild(fieldName)
		if folder then return folder end
	end
	
	local cleanName = string.lower(fieldName):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
	
	for _, child in ipairs(Workspace:GetChildren()) do
		local childClean = string.lower(child.Name):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
		if childClean == cleanName then
			return child
		end
	end
	
	if reefsFolder then
		for _, child in ipairs(reefsFolder:GetChildren()) do
			local childClean = string.lower(child.Name):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
			if childClean == cleanName then
				return child
			end
		end
	end
	
	return nil
end

local activeMines = {} -- Array of active mine tables
local MINE_LIFETIME = 300 -- 5 minutes
local MAX_MINES_PER_REEF = 3
local MINE_SPAWN_INTERVAL = 300 -- 5 minutes
local COLLECTION_RADIUS = 100


local REEF_MULTIPLIERS = {
	["Freshwater Reef"] = 1,
	["Coral Reef"] = 1.5,
	["Trash Reef"] = 2,
	["Sun Reef"] = 5,
	["Runic Reef"] = 15,
	["Coralline Reef"] = 30,
	["Obsidian Reef"] = 100,
	["Axolotl Reef"] = 150,
	["Crystal Reef"] = 250,
	["Ghastly Reef"] = 500,
	["Heavensent Reef"] = 1500,
	["Ancient Reef"] = 4000,
	["Warrior's Reef"] = 10000,
}

local function GetRandomRarity()
	local totalWeight = 0
	for _, tier in pairs(ChanceConfig.SeaMineTypes) do
		totalWeight = totalWeight + tier.Weight
	end
	
	local rand = math.random() * totalWeight
	for name, tier in pairs(ChanceConfig.SeaMineTypes) do
		if rand <= tier.Weight then
			return name, tier
		end
		rand = rand - tier.Weight
	end
	return "Common", ChanceConfig.SeaMineTypes["Common"]
end

-- List of reef names
local REEFS = {}
for name, _ in pairs(ResourceConfig.Fields) do
	table.insert(REEFS, name)
end

-- Minimum distance a mine target position must be from any player's aquarium
local AQUARIUM_EXCLUSION_RADIUS = 80

-- Returns true if 'pos' is within AQUARIUM_EXCLUSION_RADIUS of any claimed aquarium
local function IsTooCloseToAquarium(pos)
	local aquariumsFolder = Workspace:FindFirstChild("Aquariums")
	if not aquariumsFolder then return false end
	for _, plot in ipairs(aquariumsFolder:GetChildren()) do
		local owner = plot:GetAttribute("OwnerUserId")
		if owner then -- Only check claimed aquariums
			local refPart = plot:FindFirstChild("Spawn") or (plot:IsA("Model") and plot.PrimaryPart) or plot:FindFirstChildWhichIsA("BasePart")
			if refPart then
				local dist = (refPart.Position - pos).Magnitude
				if dist <= AQUARIUM_EXCLUSION_RADIUS then
					return true
				end
			end
		end
	end
	return false
end

function SeaMineService.Start()
	-- Clean up existing mines from workspace just in case
	local existingFolder = Workspace:FindFirstChild("SeaMines")
	if not existingFolder then
		existingFolder = Instance.new("Folder")
		existingFolder.Name = "SeaMines"
		existingFolder.Parent = Workspace
	else
		existingFolder:ClearAllChildren()
	end
	
	task.spawn(function()
		while true do
			task.wait(MINE_SPAWN_INTERVAL)
			SeaMineService.TrySpawnMine()
		end
	end)
end

function SeaMineService.TrySpawnMine()
	if #REEFS == 0 then return end
	local reefName = REEFS[math.random(1, #REEFS)]
	local reefFolder = getFieldFolder(reefName)
	if not reefFolder then return end
	
	-- Count current mines in this reef
	local count = 0
	for _, mineData in ipairs(activeMines) do
		if mineData.Reef == reefName then
			count = count + 1
		end
	end
	
	if count >= MAX_MINES_PER_REEF then
		return
	end
	
	-- Pick a spawn position using a random part in the reef (away from aquariums)
	local parts = {}
	for _, child in ipairs(reefFolder:GetChildren()) do
		if child:IsA("BasePart") then
			local candidatePos = child.Position + Vector3.new(0, 15, 0)
			if not IsTooCloseToAquarium(candidatePos) then
				table.insert(parts, child)
			end
		end
	end
	if #parts == 0 then return end
	
	local randomPart = parts[math.random(1, #parts)]
	local spawnPos = randomPart.Position + Vector3.new(0, 15, 0) -- Floating above the reef
	
	SeaMineService.SpawnMine(spawnPos, reefName)
end

function SeaMineService.SpawnMine(position, reefName)
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	if not vfxFolder or not vfxFolder:FindFirstChild("SeaMine") then
		warn("SeaMineService: No SeaMine model in RS.VFX")
		return
	end
	
	local seaminesFolder = Workspace:FindFirstChild("SeaMines")
	if not seaminesFolder then
		seaminesFolder = Instance.new("Folder")
		seaminesFolder.Name = "SeaMines"
		seaminesFolder.Parent = Workspace
	end
	
	local mineModel = vfxFolder.SeaMine:Clone()
	mineModel.Parent = seaminesFolder
	
	local mainPart = mineModel:FindFirstChild("Main")
	if not mainPart then
		warn("SeaMineService: SeaMine model missing Main part")
		mineModel:Destroy()
		return
	end
	
	local startCFrame = CFrame.new(position - Vector3.new(0, 30, 0))
	
	if mineModel:IsA("Model") then
		mineModel:PivotTo(startCFrame)
		-- Weld everything to mainPart and unanchor so tweening mainPart moves everything
		for _, child in ipairs(mineModel:GetDescendants()) do
			if child:IsA("BasePart") and child ~= mainPart then
				child.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = mainPart
				weld.Part1 = child
				weld.Parent = mainPart
			end
		end
	else
		mainPart.CFrame = startCFrame
	end
	mainPart.Anchored = true
	
	-- Select rarity and scale capacity
	local rarityName, rarityConfig = GetRandomRarity()
	local targetCapacity = math.floor(rarityConfig.BaseCapacity)
	
	-- Style the Model based on rarity (neon, colors, highlights)
	for _, p in ipairs(mineModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p:SetAttribute("TargetTransparency", p.Transparency)
			p.Transparency = 1
			p.Color = rarityConfig.Color
			p.Material = rarityConfig.Material
		end
	end
	
	local highlight = Instance.new("Highlight")
	highlight.Name = "RarityHighlight"
	highlight.Adornee = mineModel
	highlight.FillColor = rarityConfig.Color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0
	highlight.Parent = mineModel
	
	local mineData = {
		Model = mineModel,
		MainPart = mainPart,
		Reef = reefName,
		SpawnTime = os.time(),
		AlgaeAmount = 0,
		TargetCapacity = targetCapacity,
		RarityName = rarityConfig.Name,
		RarityKey = rarityName,
		RewardMultiplier = rarityConfig.RewardMultiplier,
		Position = position,
		Exploded = false,
		Contributors = {}
	}
	table.insert(activeMines, mineData)
	
	local basePosValue = Instance.new("Vector3Value")
	basePosValue.Value = startCFrame.Position
	basePosValue.Parent = mainPart

	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	TweenService:Create(basePosValue, tweenInfo, {Value = position}):Play()
	
	for _, p in ipairs(mineModel:GetDescendants()) do
		if p:IsA("BasePart") then
			local t = p:GetAttribute("TargetTransparency") or 0
			TweenService:Create(p, tweenInfo, {Transparency = t}):Play()
		end
	end
	
	-- Notify all players in the server
	local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
	if NotificationEvent then
		NotificationEvent:FireAllClients("A " .. rarityConfig.Name .. " has spawned in " .. reefName .. "!", Color3.fromRGB(255, 100, 100))
	end
	
	local function updateUI()
		if not mineData.Exploded then
			local timeLeft = MINE_LIFETIME - (os.time() - mineData.SpawnTime)
			if timeLeft < 0 then timeLeft = 0 end
			
			mainPart:SetAttribute("MineTimeLeft", timeLeft)
			mainPart:SetAttribute("AlgaeAmount", mineData.AlgaeAmount)
			mainPart:SetAttribute("TargetCapacity", mineData.TargetCapacity)
			mainPart:SetAttribute("MineRarityName", mineData.RarityName)
		end
	end
	
	task.spawn(function()
		while not mineData.Exploded and mineModel.Parent do
			updateUI()
			task.wait(1)
		end
	end)
	
	-- Floating and moving animation loop
	task.spawn(function()
		local rs = game:GetService("RunService")
		local startT = os.clock()
		local lastMoveTime = startT
		local moveInterval = 10
		local isInitialTween = true

		while not mineData.Exploded and mineModel.Parent do
			rs.Heartbeat:Wait()
			local now = os.clock()
			
			if now - startT >= 2 and isInitialTween then
				isInitialTween = false
				lastMoveTime = now
			end
			
			if not isInitialTween and now - lastMoveTime >= moveInterval then
				lastMoveTime = now
				local reefFolder = getFieldFolder(reefName)
				if reefFolder then
					-- Only pick parts that are not near any aquarium
					local parts = {}
					for _, child in ipairs(reefFolder:GetChildren()) do
						if child:IsA("BasePart") then
							local candidatePos = child.Position + Vector3.new(0, 15, 0)
							if not IsTooCloseToAquarium(candidatePos) then
								table.insert(parts, child)
							end
						end
					end
					if #parts > 0 then
						local randomPart = parts[math.random(1, #parts)]
						local newPos = randomPart.Position + Vector3.new(0, 15, 0)
						TweenService:Create(basePosValue, TweenInfo.new(moveInterval, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Value = newPos}):Play()
					end
				end
			end
			
			local offset = math.sin((now - startT) * 2) * 2
			mineData.Position = basePosValue.Value
			mainPart.CFrame = CFrame.new(basePosValue.Value) * CFrame.new(0, offset, 0)
		end
	end)
	
	task.delay(MINE_LIFETIME, function()
		if not mineData.Exploded then
			SeaMineService.ExplodeMine(mineData, false) -- despawn naturally
		end
	end)
end

function SeaMineService.SpawnMineUser(player, position, reefName)
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	if not vfxFolder or not vfxFolder:FindFirstChild("SeaMine") then
		warn("SeaMineService: No SeaMine model in RS.VFX")
		return
	end
	
	local seaminesFolder = Workspace:FindFirstChild("SeaMines")
	if not seaminesFolder then
		seaminesFolder = Instance.new("Folder")
		seaminesFolder.Name = "SeaMines"
		seaminesFolder.Parent = Workspace
	end
	
	local mineModel = vfxFolder.SeaMine:Clone()
	mineModel.Parent = seaminesFolder
	
	local mainPart = mineModel:FindFirstChild("Main")
	if not mainPart then
		warn("SeaMineService: SeaMine model missing Main part")
		mineModel:Destroy()
		return
	end
	
	local startCFrame = CFrame.new(position - Vector3.new(0, 30, 0))
	
	if mineModel:IsA("Model") then
		mineModel:PivotTo(startCFrame)
		-- Weld everything to mainPart and unanchor so tweening mainPart moves everything
		for _, child in ipairs(mineModel:GetDescendants()) do
			if child:IsA("BasePart") and child ~= mainPart then
				child.Anchored = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = mainPart
				weld.Part1 = child
				weld.Parent = mainPart
			end
		end
	else
		mainPart.CFrame = startCFrame
	end
	mainPart.Anchored = true
	
	-- Select rarity and scale capacity
	local rarityName, rarityConfig = GetRandomRarity()
	local targetCapacity = math.floor(rarityConfig.BaseCapacity)
	
	-- Style the Model based on rarity (neon, colors, highlights)
	for _, p in ipairs(mineModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p:SetAttribute("TargetTransparency", p.Transparency)
			p.Transparency = 1
			p.Color = rarityConfig.Color
			p.Material = rarityConfig.Material
		end
	end
	
	local highlight = Instance.new("Highlight")
	highlight.Name = "RarityHighlight"
	highlight.Adornee = mineModel
	highlight.FillColor = rarityConfig.Color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0
	highlight.Parent = mineModel
	
	local mineData = {
		Model = mineModel,
		MainPart = mainPart,
		Reef = reefName,
		SpawnTime = os.time(),
		AlgaeAmount = 0,
		TargetCapacity = targetCapacity,
		RarityName = rarityConfig.Name,
		RarityKey = rarityName,
		RewardMultiplier = rarityConfig.RewardMultiplier,
		Position = position,
		Exploded = false,
		Contributors = {}
	}
	table.insert(activeMines, mineData)
	
	local basePosValue = Instance.new("Vector3Value")
	basePosValue.Value = startCFrame.Position
	basePosValue.Parent = mainPart

	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	TweenService:Create(basePosValue, tweenInfo, {Value = position}):Play()
	
	for _, p in ipairs(mineModel:GetDescendants()) do
		if p:IsA("BasePart") then
			local t = p:GetAttribute("TargetTransparency") or 0
			TweenService:Create(p, tweenInfo, {Transparency = t}):Play()
		end
	end
	
	local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
	if NotificationEvent then
		NotificationEvent:FireAllClients(player.Name .. " has spawned a " .. rarityConfig.Name .. " in " .. reefName .. "!", Color3.fromRGB(50, 255, 50))
	end
	
	local function updateUI()
		if not mineData.Exploded then
			local timeLeft = MINE_LIFETIME - (os.time() - mineData.SpawnTime)
			if timeLeft < 0 then timeLeft = 0 end
			
			mainPart:SetAttribute("MineTimeLeft", timeLeft)
			mainPart:SetAttribute("AlgaeAmount", mineData.AlgaeAmount)
			mainPart:SetAttribute("TargetCapacity", mineData.TargetCapacity)
			mainPart:SetAttribute("MineRarityName", mineData.RarityName)
		end
	end
	
	task.spawn(function()
		while not mineData.Exploded and mineModel.Parent do
			updateUI()
			task.wait(1)
		end
	end)
	
	-- Floating and moving animation loop
	task.spawn(function()
		local rs = game:GetService("RunService")
		local startT = os.clock()
		local lastMoveTime = startT
		local moveInterval = 10
		local isInitialTween = true

		while not mineData.Exploded and mineModel.Parent do
			rs.Heartbeat:Wait()
			local now = os.clock()
			
			if now - startT >= 2 and isInitialTween then
				isInitialTween = false
				lastMoveTime = now
			end
			
			if not isInitialTween and now - lastMoveTime >= moveInterval then
				lastMoveTime = now
				local reefFolder = getFieldFolder(reefName)
				if reefFolder then
					-- Only pick parts that are not near any aquarium
					local parts = {}
					for _, child in ipairs(reefFolder:GetChildren()) do
						if child:IsA("BasePart") then
							local candidatePos = child.Position + Vector3.new(0, 15, 0)
							if not IsTooCloseToAquarium(candidatePos) then
								table.insert(parts, child)
							end
						end
					end
					if #parts > 0 then
						local randomPart = parts[math.random(1, #parts)]
						local newPos = randomPart.Position + Vector3.new(0, 15, 0)
						TweenService:Create(basePosValue, TweenInfo.new(moveInterval, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Value = newPos}):Play()
					end
				end
			end
			
			local offset = math.sin((now - startT) * 2) * 2
			mineData.Position = basePosValue.Value
			mainPart.CFrame = CFrame.new(basePosValue.Value) * CFrame.new(0, offset, 0)
		end
	end)
	
	task.delay(MINE_LIFETIME, function()
		if not mineData.Exploded then
			SeaMineService.ExplodeMine(mineData, false) -- despawn naturally
		end
	end)
end

function SeaMineService.AddAlgae(player, position, amount)
	if amount <= 0 then return end
	
	local closestMine = nil
	local closestDist = COLLECTION_RADIUS
	
	for _, mineData in ipairs(activeMines) do
		if not mineData.Exploded then
			local dist = (mineData.Position - position).Magnitude
			if dist <= closestDist then
				closestDist = dist
				closestMine = mineData
			end
		end
	end
	
	if closestMine then
		closestMine.AlgaeAmount = closestMine.AlgaeAmount + amount
		if player then
			closestMine.Contributors[player.UserId] = (closestMine.Contributors[player.UserId] or 0) + amount
		end
		if closestMine.MainPart then
			closestMine.MainPart:SetAttribute("AlgaeAmount", closestMine.AlgaeAmount)
		end
		
		-- Check if pop capacity reached
		if closestMine.AlgaeAmount >= closestMine.TargetCapacity then
			SeaMineService.ExplodeMine(closestMine, true)
		end
	end
end

function SeaMineService.ExplodeMine(mineData, wasPopped)
	mineData.Exploded = true
	
	-- Increment SeaMinesPopped quest goal for contributors >= 100 algae
	if wasPopped then
		local PlayerData = require(script.Parent.PlayerData)
		local Players = game:GetService("Players")
		for userId, contribAmount in pairs(mineData.Contributors) do
			if contribAmount >= 100 then
				local player = Players:GetPlayerByUserId(userId)
				if player then
					PlayerData.update(player, function(data)
						data.SeaMinesPopped = (data.SeaMinesPopped or 0) + 1

						if mineData.RarityData and mineData.RarityData.Name then
							local specificKey = string.gsub(mineData.RarityData.Name, ' Sea Mine', 'SeaMinesPopped')
							data[specificKey] = (data[specificKey] or 0) + 1
						end
						return data
					end)
				end
			end
		end
	end
	
	local shakeDur = wasPopped and 1.5 or 0.5
	local mainPart = mineData.MainPart
	local startCf = mainPart.CFrame
	
	if mainPart then
		if wasPopped then
			task.spawn(function()
				local rs = game:GetService("RunService")
				local startT = os.clock()
				while os.clock() - startT < shakeDur and mainPart.Parent do
					rs.Heartbeat:Wait()
					local rx = (math.random() - 0.5) * 5
					local ry = (math.random() - 0.5) * 5
					local rz = (math.random() - 0.5) * 5
					mainPart.CFrame = startCf * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
				end
			end)
		end
		
		for _, p in ipairs(mineData.Model:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(shakeDur), {Transparency = 1}):Play()
			elseif p:IsA("BillboardGui") then
				p.Enabled = false
			end
		end
	end
	
	task.wait(shakeDur)
	
	if wasPopped then
		SeaMineService.SpawnTokens(mineData)
		
		if mainPart then
			local vfx = game:GetService("ReplicatedStorage"):FindFirstChild("VFX")
			local explodeEffect = vfx and vfx:FindFirstChild("SeaMineExplode")
			if explodeEffect then
				local sfx = explodeEffect:FindFirstChild("ExplodeSFX")
				if sfx then
					local cloneSfx = sfx:Clone()
					cloneSfx.Parent = mainPart
					cloneSfx:Play()
				end
				local att = explodeEffect:FindFirstChild("Attachment")
				if att then
					local cloneAtt = att:Clone()
					cloneAtt.Parent = mainPart
					for _, child in ipairs(cloneAtt:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							child:Emit(child:GetAttribute("EmitCount") or 40)
						end
					end
				end
				-- Preserve mainPart so the sound and particles finish playing
				mainPart.Parent = workspace
				mainPart.Transparency = 1
				mainPart.Anchored = true
				game:GetService("Debris"):AddItem(mainPart, 5)
			end
		end
	end
	
	if mineData.Model then
		mineData.Model:Destroy()
	end
	
	local idx = table.find(activeMines, mineData)
	if idx then
		table.remove(activeMines, idx)
	end
end

function SeaMineService.GetRandomScaledDrop(bonusMultiplier, rarityKey)
	local Drops = ChanceConfig.SeaMineDrops[rarityKey] or ChanceConfig.SeaMineDrops["Common"]
	local totalWeight = 0
	
	local scaledDrops = {}
	for _, drop in ipairs(Drops) do
		local chance = drop.Chance
		-- Scale the chance of non-feed items with the continuous multiplier
		if chance < 50 then
			chance = chance * bonusMultiplier
		end
		table.insert(scaledDrops, {Item = drop.Item, Chance = chance})
		totalWeight = totalWeight + chance
	end
	
	local rand = math.random() * totalWeight
	for _, drop in ipairs(scaledDrops) do
		if rand <= drop.Chance then
			return drop.Item
		end
		rand = rand - drop.Chance
	end
	return nil
end

function SeaMineService.SpawnTokens(mineData)
	local centerPos = mineData.Position
	if mineData.MainPart and mineData.MainPart.Parent then
		centerPos = mineData.MainPart.Position
	end
	
	local baseDrops = math.random(40, 70)
	local tierScale = 1 + math.max(0, math.log10(mineData.RewardMultiplier or 1))
	local amountToSpawn = math.floor(baseDrops * tierScale)
	local algaeMod = math.floor(mineData.AlgaeAmount / 10000)
	-- Diminishing returns scaling scaled up by Sprout Rarity's multiplier
	local bonusMultiplier = (1 + (math.log10(algaeMod + 1) * 0.75)) * (mineData.RewardMultiplier or 1)
	
	local Players = game:GetService("Players")
	local PlayerData = require(script.Parent.PlayerData)
	
	-- Calculate total algae contributed to normalize proportions
	local totalContributed = 0
	for _, contrib in pairs(mineData.Contributors) do
		totalContributed = totalContributed + contrib
	end
	if totalContributed <= 0 then return end
	
	for userId, contrib in pairs(mineData.Contributors) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local fraction = math.clamp(contrib / totalContributed, 0, 1)
			local playerAmountToSpawn = math.max(1, math.floor(amountToSpawn * fraction))
			
			local playerBiomass = 0
			local playerItems = {}
			for i = 1, playerAmountToSpawn do
				local dropItem = SeaMineService.GetRandomScaledDrop(bonusMultiplier, mineData.RarityKey)
				if dropItem == "Biomass" then
					local bioCfg = ChanceConfig.SeaMineBiomassReward or {Min = 90, Max = 150, Divisor = 17500}
					local rarityCfg = ChanceConfig.SeaMineTypes[mineData.RarityKey]
					local baseMultiplier = math.random(bioCfg.Min, bioCfg.Max) / bioCfg.Divisor
					local specificMultiplier = rarityCfg and rarityCfg.BiomassRewardMultiplier or 1
					playerBiomass = playerBiomass + math.floor(mineData.AlgaeAmount * baseMultiplier * specificMultiplier)
				elseif dropItem then
					local itemAmount = 1
					local isRare = string.find(dropItem, "Egg") or string.find(dropItem, "Gem") or dropItem == "Remote Warp"
					if not isRare then
						itemAmount = math.max(1, math.floor(mineData.RewardMultiplier or 1))
					end
					playerItems[dropItem] = (playerItems[dropItem] or 0) + itemAmount
				end
			end
			
			-- Grant rewards to the player
			PlayerData.update(player, function(data)
				if playerBiomass > 0 then
					data.Biomass = (data.Biomass or 0) + playerBiomass
					data.LifetimeBiomass = (data.LifetimeBiomass or 0) + playerBiomass
				end
				for itemName, amount in pairs(playerItems) do
					if type(data.Inventory) ~= "table" then data.Inventory = {} end
					data.Inventory[itemName] = (data.Inventory[itemName] or 0) + amount
					data._InventoryDirty = true
				end
				return data
			end)
			
			-- Fire UI alerts
			if playerBiomass > 0 then
				local ls = player:FindFirstChild("leaderstats")
				if ls and ls:FindFirstChild("Biomass") then
					local pData = PlayerData.get(player)
					ls.Biomass.Value = pData.Biomass or 0
				end
				local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
				if NotificationEvent then
					NotificationEvent:FireClient(player, "+" .. playerBiomass .. " Biomass", Color3.fromRGB(0, 255, 255))
				end
			end
			for itemName, amount in pairs(playerItems) do
				local ItemAddedEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ItemAddedEvent")
				if ItemAddedEvent then
					ItemAddedEvent:FireClient(player, itemName, amount, "Item", 0, 0)
				end
			end
			
			-- Trigger client-side sparkle effects
			local VFXReplication = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("VFXReplication")
			if VFXReplication then
				local totalSparkles = math.clamp(playerAmountToSpawn, 5, 20)
				VFXReplication:FireClient(player, "MobCollectSparkle", player, nil, centerPos, totalSparkles)
			end
		end
	end
end

return SeaMineService

