local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
local TokenConfig = require(ReplicatedStorage.Shared.TokenConfig)

local SeaMineService = {}

local activeMines = {} -- Array of active mine tables
local MINE_LIFETIME = 60
local MAX_MINES_PER_REEF = 3
local MINE_SPAWN_INTERVAL = 300 -- 5 minutes
local COLLECTION_RADIUS = 100

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
			local refPart = plot:FindFirstChild("Spawn") or plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart")
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
	local reefFolder = Workspace:FindFirstChild(reefName)
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
	
	for _, p in ipairs(mineModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p:SetAttribute("TargetTransparency", p.Transparency)
			p.Transparency = 1
		end
	end
	
	local mineData = {
		Model = mineModel,
		MainPart = mainPart,
		Reef = reefName,
		SpawnTime = os.time(),
		AlgaeAmount = 0,
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
		NotificationEvent:FireAllClients("A sea mine has spawned in " .. reefName .. "!", Color3.fromRGB(255, 100, 100))
	end
	
	local function updateUI()
		if not mineData.Exploded then
			local timeLeft = MINE_LIFETIME - (os.time() - mineData.SpawnTime)
			if timeLeft < 0 then timeLeft = 0 end
			
			mainPart:SetAttribute("MineTimeLeft", timeLeft)
			mainPart:SetAttribute("AlgaeAmount", mineData.AlgaeAmount)
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
				local reefFolder = Workspace:FindFirstChild(reefName)
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
			SeaMineService.ExplodeMine(mineData)
		end
	end)
end

function SeaMineService.SpawnMineUser(player, position, reefName)
	-- Same as internal spawn, but includes user notification
	SeaMineService.SpawnMine(position, reefName)
	local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
	if NotificationEvent then
		NotificationEvent:FireAllClients(player.Name .. " has spawned a Sea Mine in " .. reefName .. "!", Color3.fromRGB(50, 255, 50))
	end
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
	end
end

function SeaMineService.ExplodeMine(mineData)
	mineData.Exploded = true
	
	-- Increment SeaMinesPopped quest goal for contributors >= 1000 algae
	-- But only if the mine itself had at least 1000 (meaning it drops rewards)
	if mineData.AlgaeAmount >= 1000 then
		local PlayerData = require(script.Parent.PlayerData)
		local Players = game:GetService("Players")
		for userId, contribAmount in pairs(mineData.Contributors) do
			if contribAmount >= 1000 then
				local player = Players:GetPlayerByUserId(userId)
				if player then
					PlayerData.update(player, function(data)
						data.SeaMinesPopped = (data.SeaMinesPopped or 0) + 1
						return data
					end)
				end
			end
		end
	end
	
	local shakeDur = 1.5
	local mainPart = mineData.MainPart
	local startCf = mainPart.CFrame
	
	if mainPart then
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
		
		for _, p in ipairs(mineData.Model:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(shakeDur), {Transparency = 1}):Play()
			elseif p:IsA("BillboardGui") then
				p.Enabled = false
			end
		end
	end
	
	task.wait(shakeDur)
	
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
	
	if mineData.Model then
		mineData.Model:Destroy()
	end
	
	local idx = table.find(activeMines, mineData)
	if idx then
		table.remove(activeMines, idx)
	end
end

function SeaMineService.GetRandomScaledDrop(bonusMultiplier)
	local Drops = TokenConfig.Drops
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
	if mineData.AlgaeAmount < 1000 then return end

	local centerPos = mineData.Position
	if mineData.MainPart and mineData.MainPart.Parent then
		centerPos = mineData.MainPart.Position
	end
	
	local amountToSpawn = math.random(40, 70)
	local algaeMod = math.floor(mineData.AlgaeAmount / 10000)
	-- Diminishing returns scaling to keep rewards difficult and ensure biomass/fish feed stays dominant
	local bonusMultiplier = 1 + (math.log10(algaeMod + 1) * 0.75)
	
	-- Find all valid algae parts strictly underneath the mine (within ~40x40 column area)
	local validParts = {}
	local reefFolder = Workspace:FindFirstChild(mineData.Reef)
	if reefFolder then
		for _, child in ipairs(reefFolder:GetChildren()) do
			if child:IsA("BasePart") then
				-- Ignore Y level for distance calculation to find parts roughly in the 2D area below it
				local ppos = child.Position
				local flatDist = Vector2.new(ppos.X - centerPos.X, ppos.Z - centerPos.Z).Magnitude
				if flatDist <= 40 then
					table.insert(validParts, child)
				end
			end
		end
	end
	
	for i = 1, amountToSpawn do
		task.delay(i * 0.05, function()
			-- Pick a random valid part directly below it, or fallback to centerPos flat offset
			local p = nil
			if #validParts > 0 then
				p = validParts[math.random(1, #validParts)]
			end
			
			local dropItem = SeaMineService.GetRandomScaledDrop(bonusMultiplier)
			local tokenBiomass = 0
			if dropItem == "Biomass" then
				local multiplier = math.random(90, 150) / 17500
				tokenBiomass = math.floor(mineData.AlgaeAmount * multiplier)
			end
			
			SeaMineService.CreatePhysicsToken(p, centerPos, mineData.Reef, dropItem, tokenBiomass)
		end)
	end
end

function SeaMineService.CreatePhysicsToken(targetPart, fallbackCenter, reefName, dropItem, dynBiomass)
	if not dropItem then return end
	
	local finalPos
	if targetPart then
		finalPos = targetPart.Position + Vector3.new(0, 4, 0)
	else
		-- Fallback if no parts found
		local rx = (math.random() - 0.5) * 40
		local rz = (math.random() - 0.5) * 40
		finalPos = Vector3.new(fallbackCenter.X + rx, fallbackCenter.Y - 15, fallbackCenter.Z + rz)
	end
	
	local rootToken = Instance.new("Part")
	rootToken.Name = "DropToken"
	rootToken.Size = Vector3.new(6, 6, 6)
	rootToken.Transparency = 1
	rootToken.Anchored = true
	rootToken.CanCollide = false
	rootToken.Position = finalPos
	rootToken.CFrame = CFrame.new(finalPos)
	
	local tokenName = string.gsub(dropItem, "%s+", ""):lower()
	local tokensFolder = ReplicatedStorage:FindFirstChild("Tokens")
	local tokenTemplate = nil
	if tokensFolder then
		for _, child in ipairs(tokensFolder:GetChildren()) do
			if string.lower(string.gsub(child.Name, "%s+", "")) == tokenName then
				tokenTemplate = child
				break
			end
		end
	end
	
	local visuals
	if tokenTemplate then
		visuals = tokenTemplate:Clone()
	else
		-- Fallback visually just in case missing model
		visuals = Instance.new("Part")
		visuals.Shape = Enum.PartType.Cylinder
		visuals.Size = Vector3.new(1, 4, 4)
		visuals.Color = Color3.fromRGB(255, 235, 150)
		visuals.Material = Enum.Material.Neon
	end
	
	-- Rotate root token upright for 3D models
	rootToken.CFrame = CFrame.new(finalPos) * CFrame.Angles(0, 0, 0)
	
	visuals.Parent = rootToken
	
	if visuals:IsA("Model") then
		visuals:PivotTo(rootToken.CFrame)
		for _, child in ipairs(visuals:GetDescendants()) do
			if child:IsA("BasePart") then
				child.Anchored = false
				child.CanCollide = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rootToken
				weld.Part1 = child
				weld.Parent = rootToken
			end
		end
	elseif visuals:IsA("BasePart") then
		visuals.Anchored = false
		visuals.CanCollide = false
		visuals.CFrame = rootToken.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootToken
		weld.Part1 = visuals
		weld.Parent = rootToken
	end
	
	-- Immediate Pop-in animation setup
	local originalSizes = {}
	originalSizes[rootToken] = rootToken.Size
	rootToken.Size = Vector3.new(0, 0, 0)
	
	for _, child in ipairs(rootToken:GetDescendants()) do
		if child:IsA("BasePart") then
			originalSizes[child] = child.Size
			child.Size = Vector3.new(0, 0, 0)
		end
	end
	
	rootToken.Parent = workspace
	
	local popInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for part, size in pairs(originalSizes) do
		TweenService:Create(part, popInfo, {Size = size}):Play()
	end
	
	game:GetService("CollectionService"):AddTag(rootToken, "DropToken")
	
	-- Despawn after 20 seconds, fade out halfway through
	task.delay(18, function()
		if rootToken and rootToken.Parent then
			for _, c in ipairs(rootToken:GetDescendants()) do
				if c:IsA("BasePart") and c ~= rootToken then
					TweenService:Create(c, TweenInfo.new(0.5), {Transparency = 0.6}):Play()
				elseif c:IsA("Decal") or c:IsA("Texture") then
					TweenService:Create(c, TweenInfo.new(0.5), {Transparency = 0.6}):Play()
				elseif c:IsA("TextLabel") then
					TweenService:Create(c, TweenInfo.new(0.5), {TextTransparency = 0.6}):Play() 
				end
			end
		end
	end)
	
	task.delay(20, function()
		if rootToken and rootToken.Parent then
			rootToken:Destroy()
		end
	end)
	
	-- Touch logic (Finder's Keepers)
	local isCollected = false
	rootToken.Touched:Connect(function(hit)
		if isCollected then return end
		local hitPlayer = game.Players:GetPlayerFromCharacter(hit.Parent)
		if hitPlayer then
			isCollected = true
			
			local shrinkInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			TweenService:Create(rootToken, shrinkInfo, {Size = Vector3.new(0, 0, 0)}):Play()
			for _, c in ipairs(rootToken:GetDescendants()) do
				if c:IsA("BasePart") then
					TweenService:Create(c, shrinkInfo, {Size = Vector3.new(0, 0, 0)}):Play()
				end
			end
			
			task.delay(0.3, function()
				if rootToken and rootToken.Parent then rootToken:Destroy() end
			end)
			
			local PlayerData = require(script.Parent.PlayerData)
			PlayerData.update(hitPlayer, function(data)
				if dropItem == "Biomass" then
					data.Biomass = (data.Biomass or 0) + dynBiomass
					data.LifetimeBiomass = (data.LifetimeBiomass or 0) + dynBiomass
				else
					if type(data.Inventory) ~= "table" then data.Inventory = {} end
					data.Inventory[dropItem] = (data.Inventory[dropItem] or 0) + 1
					data._InventoryDirty = true
				end
				return data
			end)
			
			if dropItem == "Biomass" then
				local ls = hitPlayer:FindFirstChild("leaderstats")
				if ls and ls:FindFirstChild("Biomass") then
					local pData = PlayerData.get(hitPlayer)
					ls.Biomass.Value = pData.Biomass or 0
				end
				local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
				if NotificationEvent then
					NotificationEvent:FireClient(hitPlayer, "+" .. dynBiomass .. " Biomass", Color3.fromRGB(0, 255, 255))
				end
			else
				local ItemAddedEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemAddedEvent")
				ItemAddedEvent:FireClient(hitPlayer, dropItem, 1, "Item", 0, 0)
			end
		end
	end)
end

return SeaMineService
