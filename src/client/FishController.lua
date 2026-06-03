local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
local ConversionVisualController = require(script.Parent.ConversionVisualController)
local VisualController = require(script.Parent.VisualController)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
local HueShifter = require(ReplicatedStorage.Shared.HueShifter)
local AbilityUIController = require(script.Parent.AbilityUIController)

local FishController = {}
local rng = Random.new()
local spawnedFish = {} -- [index] = Model defined in FishSchool array
local smoothedRootCF = nil
local currentPlankton = 0
local maxCapacity = 0
local playerData = nil -- Store full player data including IsConverting
local remoteFish = {} -- [UserId] = {[Index] = Model}
local remoteFishStates = {} -- [UserId] = {[FishIndex] = {State="...", TargetPos=Vector3}}

local player = Players.LocalPlayer
local FishModels = ReplicatedStorage:WaitForChild("Fishes")

-- State Enums (Defined at top for scoping)
local S_IDLE = "Idle"
local S_MOVING = "Moving"
local S_GATHERING = "Gathering"
local S_DELIVERING = "Delivering" -- Going to player
local S_RETREATING = "Retreating" -- Going back to tank
local S_CONVERT_TO_PLAYER = "ConvertToPlayer"
local S_CONVERT_TO_SLOT = "ConvertToSlot"
local S_CONVERT_WAIT = "ConvertWait"
local S_ORBIT_ATTACK = "OrbitAttack"
local S_CASTING_ABILITY = "CastingAbility"

if not _G.LoggedConv then _G.LoggedConv = {} end

function FishController.Start()
	-- Cleanup any lingering fish from previous session (Studio/Fast Rejoin)
	-- Cleanup any lingering fish from previous session (Studio/Fast Rejoin)
	for _, child in ipairs(game.Workspace:GetChildren()) do
		if child.Name:match("^Fish_" .. player.UserId .. "_%d+$") then
			ConversionVisualController.RemoveBeamsFromFish(child) -- Ensure beams are gone
			child:Destroy()
		end
	end

	DataUpdateEvent.OnClientEvent:Connect(function(data)
		FishController.SyncFish(data)
		FishController.UpdateHighlights(data)
	end)
	
	-- Request Initial Data (in case we missed the join event)
	local RequestData = Remotes:FindFirstChild("RequestData")
	if RequestData then RequestData:FireServer() end
	
	local FishConvertedEvent = Remotes:WaitForChild("FishConvertedEvent")
	FishConvertedEvent.OnClientEvent:Connect(function(fishIndex, amount, isCrit)
		-- Visual Feedback (Refactored to VisualController for stacking/juice)
		if amount and amount > 0 then
			VisualController.SpawnConversionText(amount, Color3.fromRGB(0, 255, 255), isCrit)
		end

		local model = spawnedFish[fishIndex]
		if not model then return end
		
		local state = _G.FishStates and _G.FishStates[model]
		if state then
			-- Conversion finished! Go back to player to pick up more algae
			state.State = S_CONVERT_TO_PLAYER
			state.TripTimer = nil
			-- Notify server we aren't at the slot anymore
			local UpdateFishReadyState = Remotes:WaitForChild("UpdateFishReadyState")
			UpdateFishReadyState:FireServer(fishIndex, false)
		end
	end)
	
	local FishStateRelay = Remotes:WaitForChild("FishStateRelay")
	FishStateRelay.OnClientEvent:Connect(function(packet)
		if packet.OrbitTarget ~= nil then
			_G.OrbitTarget = packet.OrbitTarget
		else
			_G.OrbitTarget = nil
		end
	end)

	-- Pin Boost passive conversion visuals
	local PinBoostConvertEvent = Remotes:WaitForChild("PinBoostConvertEvent", 10)
	if PinBoostConvertEvent then
		PinBoostConvertEvent.OnClientEvent:Connect(function(biomassGained, algaeTaken)
			if not biomassGained or biomassGained <= 0 then return end

			local PIN_COLOR  = Color3.fromRGB(100, 255, 140) -- lime green, distinct from fish cyan
			local PIN_COLOR2 = Color3.fromRGB(80,  210, 110)

			-- 1. Conversion panel text (same strip as fish converts, different colour)
			VisualController.SpawnConversionText(biomassGained, PIN_COLOR)

			-- 2. 3D floating text above the player's head
			local char = Players.LocalPlayer.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local useAbbr = localData and localData.Settings and localData.Settings.AbbreviateAlgae
				local function fmt(n)
					if useAbbr then
						if n >= 1e6 then return string.format("%.1fM", n/1e6)
						elseif n >= 1e3 then return string.format("%.1fK", n/1e3) end
					end
					return tostring(math.floor(n + 0.5))
				end

				-- Float text in 3D at player head level
				VisualController.SpawnFloatingText(
					hrp.Position + Vector3.new(0, 3, 0),
					biomassGained,
					PIN_COLOR,
					false,  -- not a crit
					1.1,    -- slightly larger scale
					false
				)

				-- 3. Beam link: rises from below the player upward (pin → player)
				task.spawn(function()
					-- Bottom attachment (pin level, 8 studs below HRP)
					local attBottom = Instance.new("Attachment")
					attBottom.WorldPosition = hrp.Position - Vector3.new(0, 8, 0)
					attBottom.Parent = workspace.Terrain

					-- Top attachment (at HRP)
					local attTop = Instance.new("Attachment")
					attTop.Parent = hrp

					-- Beam
					local beam = Instance.new("Beam")
					beam.Attachment0 = attBottom
					beam.Attachment1 = attTop
					beam.Width0 = 0.25
					beam.Width1 = 0.08
					beam.FaceCamera = true
					beam.LightEmission = 0.8
					beam.LightInfluence = 0.2
					beam.TextureSpeed = 2
					beam.TextureLength = 2
					beam.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, PIN_COLOR2),
						ColorSequenceKeypoint.new(1, PIN_COLOR),
					})
					-- Start transparent, flash in then out
					beam.Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.15, 0.1),
						NumberSequenceKeypoint.new(0.6, 0.1),
						NumberSequenceKeypoint.new(1, 1),
					})
					beam.CurveSize0 = 0
					beam.CurveSize1 = 0
					beam.Parent = hrp

					game.Debris:AddItem(attBottom, 0.9)
					game.Debris:AddItem(attTop,    0.9)
					game.Debris:AddItem(beam,      0.9)
				end)
			end
		end)
	end

	
	RunService.Heartbeat:Connect(FishController.OnHeartbeat)
	
	-- Listen for Temporary Fish (like Mitosis clones)
	local FishReplicationEvent = Remotes:WaitForChild("FishReplicationEvent", 5)
	if FishReplicationEvent then
		FishReplicationEvent.OnClientEvent:Connect(function(packet)
			if not packet then return end
			
			-- Handle Temporary Fish (like Mitosis clones)
			if packet.__IsTemporary then
				local ownerId = packet.OwnerUserId
				if not ownerId then return end
				
				for indexStr, fishData in pairs(packet) do
					if indexStr ~= "__IsTemporary" and indexStr ~= "OwnerUserId" then
						if ownerId == player.UserId then
							-- Local Player's Temporary Fish
							if fishData == nil or fishData == false then
								local model = spawnedFish[indexStr]
								if model then
									ConversionVisualController.RemoveBeamsFromFish(model)
									model:Destroy()
									spawnedFish[indexStr] = nil
									if _G.FishStates then _G.FishStates[model] = nil end
								end
							else
								SpawnFish(tonumber(indexStr) or indexStr, fishData)
							end
						else
							-- Remote Player's Temporary Fish
							if not remoteFish[ownerId] then remoteFish[ownerId] = {} end
							if fishData == nil or fishData == false then
								local model = remoteFish[ownerId][indexStr]
								if model then
									ConversionVisualController.RemoveBeamsFromFish(model)
									model:Destroy()
									remoteFish[ownerId][indexStr] = nil
								end
							else
								SpawnRemoteFish(ownerId, indexStr, fishData)
							end
						end
					end
				end
			else
				-- Handle Regular Global Fish Replication
				FishController.SyncRemoteFish(packet)
			end
		end)
	end
end

local function UpdateHighlight(model, enabled, forceRed)
	if not model then return end
	local highlight = model:FindFirstChild("FishHighlight")
	
	if enabled or forceRed then
		if not highlight then
			highlight = Instance.new("Highlight")
			highlight.Name = "FishHighlight"
			highlight.Adornee = model
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = model
		end
		
		if forceRed then
			highlight.FillTransparency = 0.5
			highlight.FillColor = Color3.fromRGB(255, 0, 0)
			highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
			highlight.OutlineTransparency = 0
		else
			highlight.FillTransparency = 1
			highlight.OutlineColor = Color3.fromRGB(255, 215, 0) -- Gold
			highlight.OutlineTransparency = 0
		end
	else
		if highlight then
			highlight:Destroy()
		end
	end
end

function FishController.UpdateHighlights(data)
	local settings = data and data.Settings or (playerData and playerData.Settings)
	local enabled = settings and settings.HighlightFish or false
	
	for _, model in pairs(spawnedFish) do
		local state = _G.FishStates and _G.FishStates[model]
		local forceRed = state and state.LastForceRed or false
		UpdateHighlight(model, enabled, forceRed)
	end
end

function FishController.GetFish(index)
	return spawnedFish[index] or spawnedFish[tostring(index)]
end

function FishController.GetAllFish()
	return spawnedFish
end

function FishController.SyncFish(data)
	if not data then return end
	
	-- Store full player data (includes IsConverting)
	playerData = data
	-- print("FishController: SyncFish received data. IsConverting =", tostring(data.IsConverting))
	
	if not data.FishSchool then return end
	
	-- Update Capacity Info
	maxCapacity = data.MaxCapacity or 0
	currentPlankton = 0
	if data.Plankton then
		for _, count in pairs(data.Plankton) do
			currentPlankton += count
		end
	end
	
	-- 1. Spawn/Update Fish
	local activeSlots = {}
	for slotId, fishData in pairs(data.FishSchool) do
		local numericSlot = tonumber(slotId)
		if numericSlot then
			activeSlots[tostring(numericSlot)] = true
			local existingModel = spawnedFish[tostring(numericSlot)] -- Ensure string key access
			
			if existingModel then
				-- Check if ID changed (Replacement) - Use UniqueId if available, else fallback to ID
				local currentUniqueId = existingModel:GetAttribute("UniqueId")
				local currentId = existingModel:GetAttribute("FishID")
				
				local isDifferent = false
				
				-- Check Species ID Change (Primary Check)
				if currentId ~= fishData.Id then
					isDifferent = true
				end
				
				-- Check Unique ID Change (Secondary Check)
				if fishData.UniqueId and currentUniqueId ~= fishData.UniqueId then
					isDifferent = true
				end
				
				if isDifferent then
					-- Cleanup old
					ConversionVisualController.RemoveBeamsFromFish(existingModel)
					existingModel:Destroy()
					spawnedFish[tostring(numericSlot)] = nil
					if _G.FishStates then _G.FishStates[existingModel] = nil end
					if _G.FishSpawnLocks then _G.FishSpawnLocks[tostring(numericSlot)] = nil end
					
					-- Spawn new
					SpawnFish(numericSlot, fishData)
				else
					-- Check for attribute desync (OwnerUserId etc) - update if needed
					-- Also ensure model exists in Workspace
					if not existingModel.Parent then
						spawnedFish[tostring(numericSlot)] = nil
						SpawnFish(numericSlot, fishData)
					end
				end
			else
				SpawnFish(numericSlot, fishData)
			end
		end
	end
	
	-- 2. Remove Fish that are no longer in data
	-- Create a list of keys to remove first to avoid issues
	local keysToRemove = {}
	for slotId, _ in pairs(spawnedFish) do
		if not activeSlots[tostring(slotId)] then
			table.insert(keysToRemove, slotId)
		end
	end
	
	for _, slotId in ipairs(keysToRemove) do
		local model = spawnedFish[slotId]
		if model then
			ConversionVisualController.RemoveBeamsFromFish(model)
			model:Destroy()
			spawnedFish[slotId] = nil
			if _G.FishStates then _G.FishStates[model] = nil end
		end
	end

	-- 3. Update UI (Level Text)
	local AquariumController = require(script.Parent.AquariumController)
	local myTank = AquariumController.GetMyAquarium()
	if myTank and data.FishSchool then
		local slotsContainer = myTank:FindFirstChild("Slots") or myTank:FindFirstChild("FishSlot") or myTank
		
		for slotId, fishData in pairs(data.FishSchool) do
			local slotStr = tostring(slotId)
			local slotInstance = slotsContainer:FindFirstChild(slotStr)
			
			-- Robust lookup if direct name fail
			if not slotInstance then
				for _, child in ipairs(slotsContainer:GetChildren()) do
					if child.Name:match("%d+") == slotStr then
						slotInstance = child
						break
					end
				end
			end
			
			if slotInstance then
				local facePart = slotInstance:FindFirstChild("FishFace")
				if facePart then
					local sg = facePart:FindFirstChild("Level")
					if sg then
						local txt = sg:FindFirstChild("LevelText")
						if txt then
							txt.Text = tostring(fishData.Level or 1)
						end
					end
				end
			end
			
			-- Update Attribute on existing fish
			local model = spawnedFish[slotStr]
			if model then
				model:SetAttribute("Level", fishData.Level or 1)
			end
		end
	end
end

-- REMOTE FISH LOGIC

function FishController.SyncRemoteFish(packet)
	-- 1. Sync In (Spawn/Update/RemoveFish)
	for userIdStr, school in pairs(packet) do
		local uid = tonumber(userIdStr)
		if uid == player.UserId then continue end
		
		if not remoteFish[uid] then remoteFish[uid] = {} end
		local currentSet = remoteFish[uid]
		
		-- A. Update/Spawn
		for idx, data in pairs(school) do
			local idxStr = tostring(idx)
			local existing = currentSet[idxStr] -- keys are strings in remoteFish usually? let's stick to what SpawnRemoteFish does.
			-- SpawnRemoteFish uses remoteFish[uid][idx]. idx comes from pairs(school). 
			-- Usually idx is string in JSON/Packet from server.
			
			if not existing then
				SpawnRemoteFish(uid, idx, data)
			else
				-- Check for change
				local currentId = existing:GetAttribute("FishID")
				if currentId ~= data.Id then
					ConversionVisualController.RemoveBeamsFromFish(existing)
					existing:Destroy()
					currentSet[idx] = nil -- clear ref
					SpawnRemoteFish(uid, idx, data)
				end
			end
		end
		
		-- B. Remove Missing Fish for this user
		for idx, model in pairs(currentSet) do
			if not school[idx] and not school[tostring(idx)] and not school[tonumber(idx) or -1] then
				ConversionVisualController.RemoveBeamsFromFish(model)
				model:Destroy()
				currentSet[idx] = nil
			end
		end
	end
	
	-- 2. Sync Out (Remove Missing Users)
	for uid, userFish in pairs(remoteFish) do
		local uidStr = tostring(uid)
		if not packet[uidStr] and not packet[uid] then
			for _, model in pairs(userFish) do
				ConversionVisualController.RemoveBeamsFromFish(model)
				model:Destroy()
			end
			remoteFish[uid] = nil
			remoteFishStates[uid] = nil
		end
	end
end

function SpawnRemoteFish(uid, idx, data)
	-- First check if the player has an aquarium
	local tank = GetAquariumForUser(uid)
	if not tank or not tank:FindFirstChild("Spawn") then
		-- Don't spawn fish if player doesn't have an aquarium
		return
	end
	
	local config = FishConfig.Fish[data.Id]
	local modelName = config and config.ModelName or "Basic Fish"
	local template = FishModels:FindFirstChild(modelName)
	if not template then return end
	
	local clone = template:Clone()
	clone.Name = "Fish_" .. uid .. "_" .. idx
	clone:SetAttribute("FishID", data.Id)
	clone:SetAttribute("OwnerUserId", uid)
	
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
		end
	end
	
	clone.Parent = game.Workspace
	remoteFish[uid][idx] = clone
	
	-- Apply Rhythm Fish Effect
	if data.Id == "Rhythm Fish" then
		local shifter = HueShifter.new(clone, HueShifter.CreateInfo(3))
		shifter:Play()
	end
	
	-- Position at tank spawn
	clone:PivotTo(tank.Spawn.CFrame * CFrame.new(0, 5, 0))
end

function GetAquariumForUser(uid)
	local folder = workspace:FindFirstChild("Aquariums")
	if not folder then return nil end
	for _, p in ipairs(folder:GetChildren()) do
		if p:GetAttribute("OwnerUserId") == uid then return p end
	end
	return nil
end

function SpawnFish(index, fishData)
	local indexStr = tostring(index)
	
	-- Prevent duplicate spawning
	if spawnedFish[indexStr] then
		-- Fish already successfully spawned, no need to retry
		return
	end
	
	-- Use a spawn-in-progress lock with timeout
	if not _G.FishSpawnLocks then _G.FishSpawnLocks = {} end
	
	local lockData = _G.FishSpawnLocks[indexStr]
	if lockData then
		local lockAge = os.clock() - lockData.StartTime
		if lockAge < 5 then
			-- Lock is still fresh, skip
			return
		else
			-- Lock is stale (>5 seconds), clear it and retry
			_G.FishSpawnLocks[indexStr] = nil
		end
	end
	
	_G.FishSpawnLocks[indexStr] = { StartTime = os.clock() }
	
	local config = FishConfig.Fish[fishData.Id]
	local modelName = config and config.ModelName or "Basic Fish" -- Default to Basic Fish
	
	local template = FishModels:FindFirstChild(modelName)
	if not template then
			warn("FishController: Could not find model for " .. modelName)
		_G.FishSpawnLocks[indexStr] = nil
		return
	end
	
	local clone = template:Clone()
	clone.Name = "Fish_" .. player.UserId .. "_" .. indexStr
	
	-- Paranoia Check: Destroy if exists in workspace already
	local existing = game.Workspace:FindFirstChild(clone.Name)
	if existing then existing:Destroy() end

	clone:SetAttribute("FishID", fishData.Id) -- For stat lookup
	if fishData.UniqueId then
		clone:SetAttribute("UniqueId", fishData.UniqueId)
	end
	clone:SetAttribute("OwnerUserId", player.UserId)
	clone:SetAttribute("Level", fishData.Level or 1)
	
	-- Setup Model
	if not clone.PrimaryPart then
		-- Fallback to Main or first part
		local main = clone:FindFirstChild("Main") or clone:FindFirstChildWhichIsA("BasePart")
		if main then
			clone.PrimaryPart = main
		else
			warn("FishController: Fish Model has no PrimaryPart and no BasePart found!")
			clone:Destroy()
			_G.FishSpawnLocks[indexStr] = nil
			return
		end
	end
	
	-- Ensure all parts are anchored (for CFrame movement) and Visible
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.Transparency = 0 -- Force visible just in case
		end
	end
	
	-- Initial Position
	-- Check if we have an assigned Aquarium (via AquariumController)
	local AquariumController = require(script.Parent.AquariumController) -- Lazy load to avoid cycle
	local myTank = AquariumController.GetMyAquarium()
	
	if not myTank then
		-- Small delay/retry for replication lag if we just joined or claimed
		for i = 1, 3 do
			task.wait(0.2)
			myTank = AquariumController.GetMyAquarium()
			if myTank then break end
		end
	end
	
	if not myTank then
		-- Don't spam warnings if player simply doesn't have a tank yet
		clone:Destroy()
		_G.FishSpawnLocks[indexStr] = nil
		-- We DON'T set spawnedFish[index] so SyncFish can retry later when tank exists
		return 
	end
	
	-- Spawn at the assigned slot
	local slotsContainer = myTank:FindFirstChild("Slots") or myTank:FindFirstChild("FishSlot") or myTank
	local slotIdStr = indexStr
	
	-- Robust look-up order using name matching
	local slotInstance = nil
	for _, child in ipairs(slotsContainer:GetChildren()) do
		local num = child.Name:match("%d+")
		if num == slotIdStr then
			slotInstance = child
			break
		end
	end
	
	-- Fallback for specific "FishSlot" (Index 1)
	if not slotInstance and slotsContainer and (slotIdStr == "1" or slotIdStr == "0") then
		slotInstance = slotsContainer:FindFirstChild("FishSlot")
	end
	
	if slotInstance then
		-- print("FishController: Found slot instance for index", index)
		-- Use FishFace part for positioning if it exists
		local spawnPart = slotInstance:FindFirstChild("FishFace") or slotInstance:FindFirstChildWhichIsA("BasePart") or slotInstance
		local slotCF = spawnPart:IsA("BasePart") and spawnPart.CFrame or slotInstance:GetPivot()
		
		-- Face away from the front (assuming Front is where the face is)
		clone:SetPrimaryPartCFrame(slotCF * CFrame.new(0, 0, 2))
	else
		-- Fallback to player
		if player.Character and player.Character.PrimaryPart then
			-- Random scatter around player
			local angle = math.random() * math.pi * 2
			local radius = math.random(5, 15)
			local offsetX = math.cos(angle) * radius
			local offsetZ = math.sin(angle) * radius
			clone:SetPrimaryPartCFrame(player.Character.PrimaryPart.CFrame * CFrame.new(offsetX, math.random(2, 8), offsetZ))
		end
	end
	
	clone.Parent = game.Workspace
	spawnedFish[indexStr] = clone
	_G.FishSpawnLocks[indexStr] = nil -- Release lock after successful spawn
	
	-- Apply Highlight if enabled
	local settings = playerData and playerData.Settings
	if settings and settings.HighlightFish then
		UpdateHighlight(clone, true)
	end
	
	-- Apply Rhythm Fish Effect
	if fishData.Id == "Rhythm Fish" then
		local shifter = HueShifter.new(clone, HueShifter.CreateInfo(3))
		shifter:Play()
	end
	
	-- Apply Visual Override (Temporary Clones)
	if fishData.VisualOverride then
		local vo = fishData.VisualOverride
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				if vo.Color then desc.Color = vo.Color end
				if vo.Transparency then desc.Transparency = vo.Transparency end
				if vo.Material then desc.Material = vo.Material end
			elseif desc:IsA("Decal") or desc:IsA("Texture") then
				if vo.Transparency then desc.Transparency = vo.Transparency end
			end
		end

		
		-- Also apply Highlight with Blue Color
		local hi = Instance.new("Highlight")
		hi.FillColor = vo.Color or Color3.fromRGB(0, 255, 255)
		hi.OutlineColor = Color3.new(1,1,1)
		hi.FillTransparency = 0.5
		hi.OutlineTransparency = 0
		hi.Parent = clone
	end
	
	-- Create Energy Bar if ability exists
	if config.AbilityName or config.Ability then
		local templateGui = FishModels:FindFirstChild("EnergyGui")
		local bb
		
		if templateGui then
			bb = templateGui:Clone()
			bb.Adornee = clone.PrimaryPart
			bb.Parent = clone.PrimaryPart
		end
	end
end


local FishHarvestEvent = Remotes:WaitForChild("FishHarvestEvent")
local UpdateFishReadyState = Remotes:WaitForChild("UpdateFishReadyState")

-- Track ready state for each fish index
local fishReadyStates = {} -- [index] = boolean

-- Helper to find nearest algae
-- Helper to find a random valid algae in range
-- Helper to check active obsession
local function IsObsessionActive(state)
	return state.AbilityActive and state.AbilityName == "Obsession"
end

-- Helper: Check if an algae part is already being targeted by another fish
local function IsTargeted(targetPart)
	if not _G.FishStates then return false end
	for _, state in pairs(_G.FishStates) do
		if state.Target == targetPart then
			return true
		end
	end
	return false
end

-- Helper to find nearest algae
-- Helper to find nearest algae in specific field
local function FindTarget(rootPos, allowedField)
	if not allowedField then return nil end
	
	local candidates = {}
	local scanRange = 60 
	
	local folder = game.Workspace:FindFirstChild(allowedField)
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			local cap = part:FindFirstChild("Capacity")
			if part:IsA("BasePart") and cap and cap.Value > 0 then
				local dist = (part.Position - rootPos).Magnitude
				if dist < scanRange then
					-- Filter out already targeted blocks
					if not IsTargeted(part) then
						table.insert(candidates, part)
					end
				end
			end
		end
	end
	
	if #candidates > 0 then
		return candidates[math.random(1, #candidates)]
	end
	return nil
end

-- Helper: Check if player is standing in a valid field
-- Helper: Check if player is standing in a valid field and return name
local function IsPlayerInField(char)
	if not char then return nil end
	local root = char.PrimaryPart
	if not root then return nil end
	
	-- Raycast down with penetration
	local params = RaycastParams.new()
	local ignoreList = {char}
	params.FilterDescendantsInstances = ignoreList
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	local attempts = 5
	local ray = game.Workspace:Raycast(root.Position, Vector3.new(0, -20, 0), params)
	
	while ray and ray.Instance and attempts > 0 do
		local parent = ray.Instance.Parent
		if parent and ResourceConfig.Fields[parent.Name] then
			return parent.Name
		end
		
		-- If hit PinHitbox or transparent debris, ignore and retry
		if ray.Instance.Name == "PinHitbox" or ray.Instance.Transparency >= 0.95 then
			table.insert(ignoreList, ray.Instance)
			params.FilterDescendantsInstances = ignoreList
			ray = game.Workspace:Raycast(root.Position, Vector3.new(0, -20, 0), params)
			attempts -= 1
		else
			-- Hit something solid that isn't a field (e.g. ground outside field)
			break
		end
	end
	
	return nil
end

-- Helper to find random neighbor algae
-- Helper to find random neighbor algae in specific field
local function FindRandomNeighbor(centerPos, radius, excludePart, allowedField)
	if not allowedField then return nil end

	local candidates = {}
	local folder = game.Workspace:FindFirstChild(allowedField)
	
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			local cap = part:FindFirstChild("Capacity")
			if part:IsA("BasePart") and cap and cap.Value > 0 and part ~= excludePart then
				local dist = (part.Position - centerPos).Magnitude
				if dist <= radius then
					-- Filter out already targeted blocks
					if not IsTargeted(part) then
						table.insert(candidates, part)
					end
				end
			end
		end
	end
	
	if #candidates > 0 then
		return candidates[math.random(1, #candidates)]
	end
	return nil
end


-- Helper: Safe Unit Vector to prevent NaN errors
local function SafeUnit(vec)
	if vec.Magnitude > 0.0001 then
		return vec.Unit
	end
	return Vector3.new(0,0,1) -- Default forward
end


function FishController.OnHeartbeat(dt)
						
	-- REMOTE FISH UPDATE
	-- Broadcast Local Fish States Periodically (High frequency CF sync)
	if not _G.LastStateBroadcast or os.clock() - _G.LastStateBroadcast > 0.1 then
		_G.LastStateBroadcast = os.clock()
		local myStates = {}
		local changed = false
		for i, model in pairs(spawnedFish) do
			if model.PrimaryPart then
				local s = _G.FishStates and _G.FishStates[model]
				myStates[tostring(i)] = {
					CF = model.PrimaryPart.CFrame,
					State = s and s.State or S_IDLE,
					Target = s and (s.TargetPos or (s.Target and s.Target:IsA("BasePart") and s.Target.Position))
				}
				changed = true
			end
		end
		
		if changed then
			local FishStateRelay = Remotes:FindFirstChild("FishStateRelay")
			if FishStateRelay then
				FishStateRelay:FireServer(myStates)
			end
		end
	end
	
	-- Listen (One-time setup check)
	if not _G.FishRelayConnected then
		_G.FishRelayConnected = true
		local FishStateRelay = Remotes:WaitForChild("FishStateRelay", 5)
		if FishStateRelay then
			FishStateRelay.OnClientEvent:Connect(function(uid, stateData)
				remoteFishStates[uid] = stateData
			end)
		end
	end

	local settings = playerData and playerData.Settings
	local hideOthers = settings and settings.HideOtherFish or false

	for uid, userFish in pairs(remoteFish) do
		local userStates = remoteFishStates[uid]
		local ownerPlayer = Players:GetPlayerByUserId(uid)
		local tank = GetAquariumForUser(uid)
		
		for idx, model in pairs(userFish) do
			if model and model.PrimaryPart then
				-- Handle Visibility
				local isVisible = not hideOthers
				if isVisible and model.Parent == nil then
					model.Parent = game.Workspace
				elseif not isVisible and model.Parent ~= nil then
					model.Parent = nil
					ConversionVisualController.RemoveBeamsFromFish(model)
				end
				
				if not isVisible then continue end

				-- Basic Wander State (Default)
				local state = _G.FishStates and _G.FishStates[model]
				if not state then
					state = {TargetPos = nil, LastFacingDir = model.PrimaryPart.CFrame.LookVector}
					if not _G.FishStates then _G.FishStates = {} end
					_G.FishStates[model] = state
				end
				
				local currentPos = model.PrimaryPart.Position
				local target = state.TargetPos
				
				-- Check for Replicated State
				local repData = userStates and userStates[tostring(idx)] -- Indexes are strings in JSON
				local mirrored = false
				
				if repData then
					mirrored = true
					local targetCF = repData.CF
					local rState = repData.State
					local rTarget = repData.Target
					
					-- 1. Sync Movement (Smooth Lerp to exact owner position & wiggle)
					if targetCF then
						model:SetPrimaryPartCFrame(model.PrimaryPart.CFrame:Lerp(targetCF, 0.25))
					end
					
					-- 2. Sync State-Specific Visuals
					if rState == S_GATHERING then
						-- Orientation only if target known (Movement is baked into CF)
						if rTarget then
							local look = CFrame.lookAt(model.PrimaryPart.Position, rTarget)
							model:SetPrimaryPartCFrame(model.PrimaryPart.CFrame:Lerp(look, 0.1))
						end
						ConversionVisualController.RemoveBeamsFromFish(model)
					elseif rState == S_CONVERT_WAIT or rState == S_CONVERT_TO_SLOT or rState == S_CONVERT_TO_PLAYER then
						-- Sync Conversion Beams
						if rState == S_CONVERT_WAIT then
							ConversionVisualController.CreateBeamsForFish(model, ownerPlayer)
						else
							ConversionVisualController.RemoveBeamsFromFish(model)
						end
					else
						-- Default Cleanup
						ConversionVisualController.RemoveBeamsFromFish(model)
					end
				end
				
				if not mirrored then
					-- DEFAULT BEHAVIOR (Follow/Tank)
					-- Check Owner Position
					local ownerChar = ownerPlayer and ownerPlayer.Character
					local ownerRoot = ownerChar and ownerChar.PrimaryPart
					
					local isAtTank = false
					
					if ownerRoot and tank and tank:FindFirstChild("Spawn") then
						if (ownerRoot.Position - tank.Spawn.Position).Magnitude < 25 then
							isAtTank = true
						end
					end
					
					-- If owner is essentially missing or offline, default to tank if exists
					if not ownerRoot and tank then isAtTank = true end
					
					if isAtTank then
						-- TANK BEHAVIOR (Wander)
						if tank and tank:FindFirstChild("FishWander") then
							local bounds = tank.FishWander
							if not target or (currentPos - target).Magnitude < 2 then
								local size = bounds.Size
								local center = bounds.Position
								target = center + Vector3.new((math.random()-0.5)*size.X, 0, (math.random()-0.5)*size.Z)
								state.TargetPos = target
							end
						elseif tank and tank:FindFirstChild("Spawn") then
							target = tank.Spawn.Position + Vector3.new(0,5,0)
						else
							target = currentPos -- Stay put
						end
						
						-- Execute Movement (Wander specific)
						if target then
							local dir = (target - currentPos).Unit
							local dist = (target - currentPos).Magnitude
							if dist > 0.1 then
								local look = CFrame.lookAt(currentPos, target)
								model:SetPrimaryPartCFrame(model.PrimaryPart.CFrame:Lerp(look + dir * (dt * 8), 0.1))
							end
						end
						
					elseif ownerRoot then
						-- FOLLOW PLAYER BEHAVIOR (Swarm)
						-- Use simple formation index
						local numericIndex = tonumber(idx) or 1
						local goldenAngle = 2.39996
						local orbitRadius = 6 + (math.sqrt(numericIndex) * 2.5)
						local orbitAngle = numericIndex * goldenAngle
						
						-- Home position relative to owner
						local homeX = math.cos(orbitAngle) * orbitRadius
						local homeZ = math.sin(orbitAngle) * orbitRadius
						local homeY = 0
						
						local offset = Vector3.new(homeX, homeY, homeZ)
						local destination = ownerRoot.Position + offset
						
						-- Teleport if too far
						if (destination - currentPos).Magnitude > 50 then
							model:SetPrimaryPartCFrame(CFrame.new(destination))
						else
							-- Move
							local vec = (destination - currentPos)
							local dist = vec.Magnitude
							local speed = 12
							
							if dist > 0.1 then
								local step = math.min(dist, speed * dt)
								local newPos = currentPos + (vec.Unit * step)
								
								-- Rotation
								local lookAt = ownerRoot.Position
								local lookCF = CFrame.lookAt(newPos, lookAt)
								
								model:SetPrimaryPartCFrame(model.PrimaryPart.CFrame:Lerp(lookCF, 0.1) + (newPos - currentPos))
							end
						end
					end
				end -- End Not Mirrored
			end
		end
	end

	local char = player.Character
	if not char or not char.PrimaryPart then return end
	
	local targetRootCF = char.PrimaryPart.CFrame
	
	local AquariumController = require(script.Parent.AquariumController)
	local myTank = AquariumController.GetMyAquarium()
	
	-- Fallback: If myTank is nil, try to find it by proximity and ownership label as a last resort
	if not myTank then
		local folder = workspace:FindFirstChild("Aquariums")
		if folder then
			for _, plot in ipairs(folder:GetChildren()) do
				local ownerPart = plot:FindFirstChild("Ownership")
				local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
				local lbl = gui and gui:FindFirstChild("TextLabel")
				if lbl and lbl.Text == player.Name .. "'s Aquarium" then
					myTank = plot
					break
				end
			end
		end
	end

	local isInTankMode = false
	local tankWanderCenter = nil
	local tankWanderSize = nil
	
	if myTank then
		local spawnPart = myTank:FindFirstChild("Spawn")
		if spawnPart then
			local dist = (char.PrimaryPart.Position - spawnPart.Position).Magnitude
			if dist < 30 then -- Increased radius to capture aquarium area better
				isInTankMode = true
				-- Prefer "Wander" part name as requested
				local wanderPart = myTank:FindFirstChild("Wander") or myTank:FindFirstChild("FishWander")
				if wanderPart and wanderPart:IsA("BasePart") then
					tankWanderCenter = wanderPart.Position
					tankWanderSize = wanderPart.Size
				end
			end
		end
	end
	
	-- if isInTankMode and tankWanderCenter then
	--	targetRootCF = tankWanderCenter -- Swarm anchors to tank center
	-- end
	-- Removed to allow free wandering (Point A -> Point B) without swarm orbit constraints
	
	-- Smooth the Root CFrame for formation drag
	if not smoothedRootCF then smoothedRootCF = targetRootCF end
	if (targetRootCF.Position - smoothedRootCF.Position).Magnitude > 50 then
		smoothedRootCF = targetRootCF -- Snap on teleport
	else
		smoothedRootCF = smoothedRootCF:Lerp(targetRootCF, 0.1) -- Slower drag
	end
	
	local rootPos = smoothedRootCF.Position 
	local time = os.clock()
	local inField = IsPlayerInField(char)
	
	local isCurrentlyConverting = playerData and playerData.IsConverting
	if isCurrentlyConverting then
		-- Only print once per state change to avoid spam
		if not _G.LastConvertState then
			_G.LastConvertState = true
		end
	else
		if _G.LastConvertState then
			_G.LastConvertState = false
		end
	end
	for i, fishEntry in pairs(spawnedFish) do
		local model = fishEntry
		if not model or not model.PrimaryPart then continue end
		
		local numericIndex = tonumber(i)
		if not numericIndex then 
			-- This is a corrupted entry (likely from hitting the folder instead of a slot)
			continue 
		end
		
		local currentCF = model.PrimaryPart.CFrame
		local currentPos = currentCF.Position
		
		local fId = model:GetAttribute("FishID") or "Basic Fish"
		local config = FishConfig.Fish[fId]
		
		-- Clear conversion state when not converting
		if not isCurrentlyConverting then
			if _G.FishConversionStates and _G.FishConversionStates[model] then
				_G.FishConversionStates[model] = nil
			end
			
			-- Reset ready state if we stop converting
			if fishReadyStates[i] then
				fishReadyStates[i] = false
				UpdateFishReadyState:FireServer(i, false)
			end
		end
		
		-- Logic: Ensure State
		if not _G.FishStates then _G.FishStates = {} end
		local state = _G.FishStates[model]
		if not state then
			local fId = model:GetAttribute("FishID") or "Basic Fish"
			local cfg = FishConfig.Fish[fId] or FishConfig.Fish["Basic Fish"]
			local baseStats = (cfg and cfg.BaseStats) or {}
			
			-- Fetch ability requirement to safely pad random initial spawn variance without overflowing
			local reqEnergy = 12
			if cfg and (cfg.Ability or cfg.AbilityName) then
				local abilityConfig = cfg.Ability or (cfg.AbilityName and FishConfig.Abilities[cfg.AbilityName])
				if abilityConfig and abilityConfig.EnergyRequired then
					reqEnergy = abilityConfig.EnergyRequired
				end
			end

			state = {
				State = S_IDLE,
				Target = nil,
				Timer = 0,
				Stats = {
					GatherSpeed = baseStats.GatherSpeed or 1,
					GatherAmount = baseStats.GatherAmount or 1,
					MoveSpeed = baseStats.MoveSpeed or 12
				},
				FishIndex = i,
				LastFacingDir = model.PrimaryPart.CFrame.LookVector,
				LastPos = currentPos,
				LastMoveTime = time,
				Energy = rng:NextNumber(0, reqEnergy * 0.6), -- Safely desync without overflowing their specific maximum
			}
			-- Randomize target position slightly to prevent stacking on spawn
			if state.State == S_IDLE then
				local rndAngle = rng:NextNumber() * math.pi * 2
				local rndDist = rng:NextNumber(5, 10)
				state.CurrentWanderOffset = Vector3.new(math.cos(rndAngle) * rndDist, rng:NextNumber(-2, 2), math.sin(rndAngle) * rndDist)
			end
			_G.FishStates[model] = state
		end
		
		-- State Tracking Logic for SFX
		if state.LastState ~= state.State then
			state.LastState = state.State
			state.StateStartTime = time
		end
		
		-- Stuck Detection: If not moving but not supposed to be stationary
		if (currentPos - state.LastPos).Magnitude > 0.1 then
			state.LastPos = currentPos
			state.LastMoveTime = time
		elseif state.State ~= S_IDLE and state.State ~= S_GATHERING and state.State ~= S_CONVERT_WAIT then
			if time - state.LastMoveTime > 3 then
				state.State = S_IDLE
				state.Target = nil
				state.LastMoveTime = time
				-- Visual snap if really far
				if (rootPos - currentPos).Magnitude > 50 then
					model:SetPrimaryPartCFrame(CFrame.new(rootPos))
				end
			end
		end
		
		-------------------------------------------------------
		-- ABILITY PRE-HIGHLIGHT (One Harvest Away)
		-------------------------------------------------------
		local isForceRed = false
		if not state.PerformingAbility and state.Energy then
			local fId = model:GetAttribute("FishID") or "Basic Fish"
			local cfg = FishConfig.Fish[fId]
			if cfg and (cfg.Ability or cfg.AbilityName) then
				local abilityConfig = cfg.Ability or (cfg.AbilityName and FishConfig.Abilities[cfg.AbilityName])
				if abilityConfig then
					local required = abilityConfig.EnergyRequired or 12
					local gainData = abilityConfig.EnergyPerHarvest
					local maxGain = (type(gainData) == "table" and gainData.Max) or tonumber(gainData) or 1
					local boostMult = 1.0 + (playerData and playerData.Stats and playerData.Stats.FishEnergyGainBoost or 0)
					maxGain = maxGain * boostMult
					
					if state.Energy >= (required - maxGain) then
						isForceRed = true
					end
				end
			end
		end

		local settingsData = playerData and playerData.Settings or {}
		local setEnabled = settingsData.HighlightFish or false
		if state.LastForceRed ~= isForceRed then
			state.LastForceRed = isForceRed
			UpdateHighlight(model, setEnabled, isForceRed)
		end
		
		-------------------------------------------------------
		-- ABILITY TRIGGER (Dolphin Jump Animation)
		-------------------------------------------------------
		-- ABILITY TRIGGER (Dolphin Jump Animation)
		-------------------------------------------------------
		if state.AbilityReady and not state.PerformingAbility then
			local fId = model:GetAttribute("FishID") or "Basic Fish"
			local cfg = FishConfig.Fish[fId]
			
			-- Check if fish has ability (support both old and new systems)
			local hasAbility = (cfg and (cfg.Ability or cfg.AbilityName))
			if not hasAbility then return end
			
			state.PerformingAbility = true
			state.AbilityReady = false
			state.Energy = 0
			state.AbilityTriggerDelay = nil -- Clear staggered trigger
			
			-- Determine ability to trigger
			local abilityToTrigger = cfg.AbilityName or (cfg.Ability and cfg.Ability.Name)
			
			-- Support Secondary Abilities (e.g. Bloodthirst, Surging Pins)
			if cfg.SecondaryAbilities and #cfg.SecondaryAbilities > 0 then
				local pool = {abilityToTrigger}
				for _, sub in ipairs(cfg.SecondaryAbilities) do
					local abilityCfg = FishConfig.Abilities[sub]
					local reqLevel = abilityCfg and abilityCfg.LevelRequired or 0
					
					local fishLevel = 1
					local pData = _G.ClientData
					if pData and pData.FishSchool then
						local fData = pData.FishSchool[i] or pData.FishSchool[tostring(i)]
						if fData and fData.Level then fishLevel = fData.Level end
					end
					
					if fishLevel >= reqLevel then
						table.insert(pool, sub)
					end
				end
				local rng = Random.new()
				abilityToTrigger = pool[rng:NextInteger(1, #pool)]
			end
			
			if abilityToTrigger == "Obsession" then
				state.PerformingAbility = true -- Redundant but safe
				
				local startPos = currentPos
				local jumpHeight = 5
				local jumpDuration = 0.65
				local jumpStartTime = time
				local hasTriggered = false
				local jumpDirection = state.LastFacingDir or currentCF.LookVector
				
				task.spawn(function()
					local elapsed = 0
					while elapsed < jumpDuration do
						elapsed = os.clock() - jumpStartTime
						local progress = elapsed / jumpDuration
						
						-- Trigger at peak (approx 0.5 progress)
						if progress >= 0.5 and not hasTriggered then
							hasTriggered = true
							local TriggerAbilityEvent = Remotes:WaitForChild("TriggerAbilityEvent")
							TriggerAbilityEvent:FireServer(i, fId, model.PrimaryPart.Position, abilityToTrigger)
						end
						
						-- Vertical Hop (Sine wave 0 -> pi)
						local yOffset = math.sin(progress * math.pi) * jumpHeight
						-- ... (Keep existing Obsession animation)
						local newPos = startPos + Vector3.new(0, yOffset, 0)
						local velocity = math.cos(progress * math.pi) * jumpHeight
						local pitch = math.atan(velocity * 0.3)
						local facingCF = CFrame.lookAt(newPos, newPos + jumpDirection) * CFrame.Angles(pitch, 0, 0)
						model:SetPrimaryPartCFrame(facingCF)
						
						task.wait(0.016)
					end
					
					state.PerformingAbility = false
				end)
				
			elseif abilityToTrigger == "Grand Slam" then
				state.PerformingAbility = true
				
				local startPos = currentPos
				local spots = {startPos}
				
				-- Pre-calculate closest field ONCE per ability trigger
				local FieldConfig = require(game:GetService("ReplicatedStorage").Shared.ResourceConfig)
				local closestField = nil
				local closestDist = math.huge
				
				for fName, _ in pairs(FieldConfig.Fields) do
					local fw = workspace:FindFirstChild(fName)
					if fw then
						-- Folders don't have PrimaryPart. Get the first algae node instead to approximate field position.
						local firstPart = fw:FindFirstChildWhichIsA("BasePart")
						if firstPart then
							local d = (startPos - firstPart.Position).Magnitude
							if d < closestDist then
								closestDist = d
								closestField = fw
							end
						end
					end
				end
				
				local function getRandomSpot(origin, minR, maxR)
					-- If field found, just pick a random algae node within it and add a small variance
					if closestField then
						local parts = closestField:GetChildren()
						if #parts > 0 then
							local targetCount = 0
							local randPart = nil
							-- Try to find a node within maxR distance (safety cutoff after 15 tries)
							for _ = 1, 15 do
								randPart = parts[math.random(1, #parts)]
								if randPart:IsA("BasePart") then
									if (origin - randPart.Position).Magnitude <= maxR then
										break
									end
								end
							end
							
							if randPart and randPart:IsA("BasePart") then
								local newX = randPart.Position.X + Random.new():NextNumber(-2, 2)
								local newZ = randPart.Position.Z + Random.new():NextNumber(-2, 2)
								return Vector3.new(newX, origin.Y, newZ)
							end
						end
					end
					
					-- Fallback to pure local radius
					local r = Random.new():NextNumber(minR, maxR)
					local angle = Random.new():NextNumber(0, math.pi * 2)
					local offset = Vector3.new(math.cos(angle)*r, 0, math.sin(angle)*r)
					local newPos = origin + offset
					return Vector3.new(newPos.X, origin.Y, newPos.Z)
				end
				
				-- 1st is current pos, 2nd-6th are random (6 total spots = 5 extra loops)
				table.insert(spots, getRandomSpot(startPos, 15, 30))
				table.insert(spots, getRandomSpot(spots[2], 15, 30))
				table.insert(spots, getRandomSpot(spots[3], 15, 30))
				table.insert(spots, getRandomSpot(spots[4], 15, 30))
				table.insert(spots, getRandomSpot(spots[5], 15, 30))
				
				local extraData = {Targets = spots, Timing = 1.1}
				local TriggerAbilityEvent = Remotes:WaitForChild("TriggerAbilityEvent")
				TriggerAbilityEvent:FireServer(i, fId, model.PrimaryPart.Position, abilityToTrigger, extraData)
				
				task.spawn(function()
					local originalCF = model:GetPrimaryPartCFrame()
					
					-- Anti-Exponential Growth Cache: Lock the baseline scale so lag stutters never physically multiply an already-scaled Blobfish to infinity!
					local originalScale = model:GetAttribute("BaseScale")
					if not originalScale then
						originalScale = model:GetScale()
						model:SetAttribute("BaseScale", originalScale)
					end
					
					-- Tween up scale over first 0.5s to 4x size
					local ts = game:GetService("TweenService")
					local scaleNum = Instance.new("NumberValue")
					scaleNum.Value = originalScale
					scaleNum.Changed:Connect(function(val)
						if model and model.Parent then
							model:ScaleTo(val)
						end
					end)
					ts:Create(scaleNum, TweenInfo.new(0.5), {Value = originalScale * 8}):Play()
					game.Debris:AddItem(scaleNum, 16) -- cleanup safety (6 jumps of 2.0s ~ 12s total)
					
					local currentPoint = originalCF.Position
					local vfxFolder = game:GetService("ReplicatedStorage"):FindFirstChild("VFX")
					local blobfishFolder = vfxFolder and vfxFolder:FindFirstChild("Blobfish")
					
					for jumpNum, targetPoint in ipairs(spots) do
						local jumpDuration = 1.1
						
						local indicator = Instance.new("Part")
						indicator.Shape = Enum.PartType.Cylinder
						indicator.Size = Vector3.new(0.2, 0, 0)
						indicator.Color = Color3.fromRGB(255, 105, 180) -- Hot pink
						indicator.Material = Enum.Material.Neon
						indicator.Transparency = 1
						indicator.Anchored = true
						indicator.CanCollide = false
						-- Cylinder flat faces are along the X axis. Rotate 90 degrees around Z to lay it flat.
						indicator.CFrame = CFrame.new(targetPoint + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi/2)
						indicator.Parent = workspace
						
						local highlight = Instance.new("Highlight")
						highlight.Adornee = indicator
						highlight.FillColor = indicator.Color
						highlight.OutlineColor = Color3.new(1, 1, 1)
						highlight.FillTransparency = 0.5
						highlight.OutlineTransparency = 0
						highlight.Parent = indicator
						
						ts:Create(indicator, TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Vector3.new(2, 28, 28), Transparency = 0.6}):Play()
						
						local jumpHeight = 30 -- higher height since fish is bigger
						local startTime = os.clock()
						local jumpDirection = (targetPoint - currentPoint)
						
						-- if magnitude is ~0 (first jump is straight up), default to forward look vector
						if jumpDirection.Magnitude < 0.1 then 
							jumpDirection = originalCF.LookVector 
						else
							jumpDirection = jumpDirection.Unit 
						end
						
						while true do
							local elapsed = os.clock() - startTime
							if elapsed >= jumpDuration then break end
							local progress = elapsed / jumpDuration
							
							local xzPos = currentPoint:Lerp(targetPoint, progress)
							-- Sine wave logic gives us natural fast/slow/fast motion over top
							local yOffset = math.sin(progress * math.pi) * jumpHeight
							local newPos = xzPos + Vector3.new(0, yOffset, 0)
							
							local velocityY = math.cos(progress * math.pi) * jumpHeight
							local pitch = math.atan(velocityY * 0.15)
							
							local facingCF = CFrame.lookAt(newPos, newPos + jumpDirection) * CFrame.Angles(pitch, 0, 0)
							if model and model.PrimaryPart then
								model:SetPrimaryPartCFrame(facingCF)
							end
							task.wait(0.016)
						end
						
						-- Jump landed
						ts:Create(indicator, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.2, 35, 35), Transparency = 1}):Play()
						ts:Create(highlight, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FillTransparency = 1, OutlineTransparency = 1}):Play()
						game.Debris:AddItem(indicator, 0.5)

						currentPoint = targetPoint
						if model and model.PrimaryPart then
							model:SetPrimaryPartCFrame(CFrame.lookAt(targetPoint, targetPoint + jumpDirection))
						end
						
						-- Visuals/SFX play when slamming
						if blobfishFolder then
							local explodeAtt = blobfishFolder.Explode.impact
							local sfx1 = blobfishFolder:FindFirstChild("SFX1")
							local sfx2 = blobfishFolder:FindFirstChild("SFX2")
							
							local p = Instance.new("Part")
							p.Anchored = true; p.CanCollide = false; p.Transparency = 1
							p.Position = targetPoint + Vector3.new(0,2.5,0)
							p.Parent = workspace
							game.Debris:AddItem(p, 3)
							
							if explodeAtt then
								local clone = explodeAtt:Clone()
								clone.Parent = p
								-- Trigger all emitters within attachment
								for _, em in ipairs(clone:GetChildren()) do
									if em:IsA("ParticleEmitter") then
										em:Emit(em:GetAttribute("EmitCount") or 40)
									end
								end
							end
							-- Play audio local to position
							if sfx1 then local s = sfx1:Clone(); s.Parent = p; s:Play() end
							if sfx2 then local s = sfx2:Clone(); s.Parent = p; s:Play() end
						end
					end
					
					-- Restore scale safely back to normal size
					ts:Create(scaleNum, TweenInfo.new(0.5), {Value = originalScale}):Play()
					task.wait(0.5)
					state.PerformingAbility = false
				end)
				
			else
				-- Standard Ability (Dolphin Jump) for both Primary and Secondary (Bloodthirst)
				
				-- Store current position AND rotation
				local startCF = currentCF
				local startPos = currentPos
				local jumpHeight = 8 
				local jumpDuration = 1.5 
				local jumpStartTime = time
				
				-- Determine forward direction for jump
				local jumpDirection = state.LastFacingDir or startCF.LookVector
				
				-- Trigger server-side ability effect IMMEDIATELY or at PEAK? 
				-- Previous code fired immediately.
				local TriggerAbilityEvent = Remotes:WaitForChild("TriggerAbilityEvent")
				
				local extraData = nil
				if abilityToTrigger == "Bloodthirst" then
					-- Calculate Chain Path (Fish to Fish)
					local chainPath = {model.PrimaryPart.Position}
					local visited = {[model] = true} -- Key by instance
					local currentFish = model
					local bConfig = FishConfig.Abilities["Bloodthirst"]
					local maxBounces = bConfig and bConfig.MaxBounces or 25
					local maxRange = 60
					
					for b = 1, maxBounces do
						local nearest = nil
						local minDesc = maxRange
						
						for _, other in pairs(spawnedFish) do
							if other and other.PrimaryPart and not visited[other] then
								local dist = (other.PrimaryPart.Position - currentFish.PrimaryPart.Position).Magnitude
								if dist < minDesc then
									minDesc = dist
									nearest = other
								end
							end
						end
						
						if nearest then
							visited[nearest] = true
							table.insert(chainPath, nearest.PrimaryPart.Position)
							currentFish = nearest
						else
							break
						end
					end
					extraData = chainPath
				end
				
				-- Check if ability should trigger at peak or immediately
				local triggerAtPeak = (abilityToTrigger == "Pinned Down")
				
				if not triggerAtPeak then
					-- Trigger immediately for most abilities
					TriggerAbilityEvent:FireServer(i, fId, model.PrimaryPart.Position, abilityToTrigger, extraData)
				end
				
				-- Perform dolphin jump animation
				task.spawn(function()
					local hasTriggered = not triggerAtPeak -- If not triggering at peak, already triggered
					local elapsed = 0
					while elapsed < jumpDuration do
						elapsed = os.clock() - jumpStartTime
						local progress = elapsed / jumpDuration
						
						-- Trigger at peak if needed (approx 0.5 progress)
						if triggerAtPeak and progress >= 0.5 and not hasTriggered then
							hasTriggered = true
							TriggerAbilityEvent:FireServer(i, fId, model.PrimaryPart.Position, abilityToTrigger, extraData)
						end
						
						-- Parabolic arc (up then down)
						local yOffset = math.sin(progress * math.pi) * jumpHeight
						local newPos = startPos + Vector3.new(0, yOffset, 0)
						
						-- Calculate pitch angle for dolphin-like motion
						-- Velocity tells us if we're going up or down
						local velocity = math.cos(progress * math.pi) * jumpHeight
						
						-- Create pitch based on vertical velocity
						-- Positive = Up, Negative = Down (Dolphin Dive)
						local pitch = math.atan(velocity * 0.3)
						
						-- Create rotation: keep level, face jump direction, then apply pitch
						local facingCF = CFrame.lookAt(newPos, newPos + jumpDirection) * CFrame.Angles(pitch, 0, 0)
						
						-- Apply CFrame
						if model and model.PrimaryPart then
							model:SetPrimaryPartCFrame(facingCF)
						end
						
						task.wait(0.03) -- ~30 FPS for smooth animation
					end
					
					-- Animation complete - restore to ground level
					state.PerformingAbility = false
				end)
			end
		end
		
		-- Initialize loop variables
		local destination = nil
		local slotPos = nil
		local targetPos = nil
		local speedMult = (playerData and playerData.Stats and playerData.Stats.FishMoveSpeedMultiplier) or 1
		local level = model:GetAttribute("Level") or 1
		local levelSpeedMult = 1 + (0.05 * (level - 1)) -- 5% speed per level
		local moveSpeed = state.Stats.MoveSpeed * speedMult * levelSpeedMult
		
		-- PASSIVE: Overtaking Melody (Boost speeds by 1% per stack)
		local collectTimeMult = 1
		local fId = model:GetAttribute("FishID") or "Basic Fish"
		local cfg = FishConfig.Fish[fId]
		if cfg and cfg.Passive == "Overtaking Melody" then
			local stacks = AbilityUIController.GetBuffStacks("RhythmFever")
			if stacks > 0 then
				local boost = 1 + (stacks * 0.01)
				moveSpeed = moveSpeed * boost
				collectTimeMult = 1 / boost
			end
		end
		
		state.CurrentCollectTimeMult = collectTimeMult -- Store for gathering logic
		
		-- =========================================================
		-- If fish is actively performing an ability animation, 
		-- suspend ordinary state logic and physics to let the ability
		-- control the fish's motion and prevent ghost-gathering.
		-- =========================================================
		if state.PerformingAbility then
			if state.State == S_GATHERING then 
				state.State = S_IDLE
				state.Target = nil
			end
			continue
		end
		
		-------------------------------------------------------
		-- STATE RESOLVER (Avoid Conflicts)
		-------------------------------------------------------
		
		-- 1. Mode Transitions
		if isCurrentlyConverting then
			-- Force conversion chain if not already in it
			if state.State ~= S_CONVERT_TO_PLAYER and state.State ~= S_CONVERT_TO_SLOT and state.State ~= S_CONVERT_WAIT then
				state.Target = nil
				state.State = S_CONVERT_TO_PLAYER
			end
		else
			-- Not converting: If we were in a conversion state, reset to Idle
			if state.State == S_CONVERT_TO_PLAYER or state.State == S_CONVERT_TO_SLOT or state.State == S_CONVERT_WAIT then
				state.State = S_IDLE
				-- Safety: Ensure beams are definitely removed
				ConversionVisualController.RemoveBeamsFromFish(model)
			end
			
			-- 2. Tank Mode Transitions
			if isInTankMode then
				-- If we were gathering or delivering and user came home, retreat
				if state.State == S_MOVING or state.State == S_GATHERING or state.State == S_DELIVERING then
					state.State = S_RETREATING
				end
			end
			
			-- 3. Combat Mode Transitions
			if _G.OrbitTarget and _G.OrbitTarget.Parent and _G.OrbitTarget.PrimaryPart then
				if state.State == S_MOVING or state.State == S_GATHERING or state.State == S_IDLE then
					state.State = S_ORBIT_ATTACK
					state.Target = nil
				end
			else
				if state.State == S_ORBIT_ATTACK or state.State == S_CASTING_ABILITY then
					state.State = S_IDLE
				end
			end
		end

		-------------------------------------------------------
		-- AI DECISIONS
		-------------------------------------------------------
		
		-- VALIDATE TARGET (Only for Gathering/Moving)
		if state.Target then
			if not inField then
				-- Player physically left the reef! Abort current harvest immediately.
				state.Target = nil
				if state.State == S_MOVING or state.State == S_GATHERING then
					state.State = S_IDLE -- Force them back to formation logic
				end
			elseif state.Target.Parent == nil or state.Target.Transparency >= 1 then
				-- Field block was destroyed or despawned
				state.Target = nil
				if state.State == S_MOVING or state.State == S_GATHERING then
					state.State = S_IDLE
				end
			end
		end

		-- CONVERSION LOOP (HIVE MODE) - HIGHEST PRIORITY
		if isCurrentlyConverting then
			local slotsContainer = myTank and (myTank:FindFirstChild("Slots") or myTank:FindFirstChild("FishSlot"))
			local slotIdStr = tostring(i)
			-- Robust look-up order for user's specific hierarchy
			local slotInstance = slotsContainer and (
				slotsContainer:FindFirstChild(slotIdStr) 
				or slotsContainer:FindFirstChild("Slot" .. slotIdStr)
				or slotsContainer:FindFirstChild("FishSlot" .. slotIdStr)
			)
			
			-- Final fallback: if numericId is used and no name matches, check by index
			if not slotInstance and slotsContainer and tonumber(slotIdStr) then
				slotInstance = slotsContainer:GetChildren()[tonumber(slotIdStr)]
			end

			if slotInstance then
				local facePart = slotInstance:FindFirstChild("FishFace") or slotInstance:FindFirstChildWhichIsA("BasePart")
				if facePart then
					-- Position 2.5 studs in front of the face
					slotPos = (facePart.CFrame * CFrame.new(0, 0, 0)).Position
				else
					local pivot = slotInstance:GetPivot()
					slotPos = pivot.Position + pivot.LookVector * 2.5
				end
			end

			-- Initialize conversion state if needed (and clear field targets)
			if state.State ~= S_CONVERT_TO_PLAYER and state.State ~= S_CONVERT_TO_SLOT and state.State ~= S_CONVERT_WAIT then
				if not _G.LoggedConv[i] then
					print("Fish " .. i .. " entering Conversion Loop")
					_G.LoggedConv[i] = true
				end
				state.Target = nil -- Stop gathering
				state.State = S_CONVERT_TO_PLAYER
			end

			if state.State == S_CONVERT_TO_PLAYER then
				local dest = char.PrimaryPart.Position
				local dist = (dest - currentPos).Magnitude
				if dist < 4 then
					print("Fish " .. i .. " reached player, heading to slot")
					state.State = S_CONVERT_TO_SLOT
				else
					targetPos = dest
				end
				-- Beams OFF
				ConversionVisualController.RemoveBeamsFromFish(model)
				if fishReadyStates[i] then
					fishReadyStates[i] = false
					UpdateFishReadyState:FireServer(i, false)
				end

			elseif state.State == S_CONVERT_TO_SLOT then
				if slotPos then
					local dist = (slotPos - currentPos).Magnitude
					if dist < 2.5 then -- Slightly larger range for easier snapping
						print("Fish " .. i .. " reached slot, starting deposit")
						state.State = S_CONVERT_WAIT
						-- Notify server we are ready
						if not fishReadyStates[i] then
							fishReadyStates[i] = true
							UpdateFishReadyState:FireServer(i, true)
						end
					else
						targetPos = slotPos
					end
				else
					-- If slot is missing, conversion can't proceed. 
					-- Just hover at player for now so it doesn't flicker.
					targetPos = char.PrimaryPart.Position
					if time % 5 < 0.1 then
						warn("Fish " .. i .. " cannot find slot " .. tostring(i) .. " for conversion!")
					end
				end
				-- Beams OFF
				ConversionVisualController.RemoveBeamsFromFish(model)

			elseif state.State == S_CONVERT_WAIT then
				-- Stay at slot and wobble
				local hoverPos = slotPos or currentPos
				local wobbleY = math.sin(os.clock() * 4) * 0.5
				destination = hoverPos + Vector3.new(0, wobbleY, 0)
				
				-- Face outward from the hive
				local facePart = slotInstance and (slotInstance:FindFirstChild("FishFace") or slotInstance:FindFirstChildWhichIsA("BasePart"))
				if facePart then
					local facingCF = CFrame.lookAt(currentPos, currentPos + facePart.CFrame.LookVector)
					model:SetPrimaryPartCFrame(facingCF)
				end

				-- Beams ON
				ConversionVisualController.CreateBeamsForFish(model)
			end

		-- DELIVERING: Fly back to player
		elseif state.State == S_DELIVERING then
			local dest = char.PrimaryPart.Position
			local dist = (dest - currentPos).Magnitude
			if dist < 4 then
				state.State = S_IDLE
			else
				targetPos = dest
			end

		-- IDLE: Look for food (ONLY IF PLAYER IN FIELD AND NOT FULL)
		elseif state.State == S_IDLE then
			-- Use global capacity or default to a safe value
			local localMax = (maxCapacity > 0 and maxCapacity) or 5
			if inField and currentPlankton < localMax then
				-- Search around PLAYER, not the fish (which might be trailing behind)
				-- This ensures a "Bee Swarm" style spread where they pick random spots in the field you are standing in.
				local found = FindTarget(char.PrimaryPart.Position, inField)
				if found then
					-- Rabbit Fish SFX: Enter Field
					local fId = model:GetAttribute("FishID")
					-- Check idle duration to ensure we were actually following (not just rapid retargeting)
					local lastSfx = state.LastRabbitSfxTime or 0
					if fId == "Rabbit Fish" and (time - (state.StateStartTime or 0) > 0.5) and (time - lastSfx > 2) then
						local TriggerAbilityEvent = Remotes:WaitForChild("TriggerAbilityEvent")
						TriggerAbilityEvent:FireServer(numericIndex, fId, model.PrimaryPart.Position, "RabbitEnter")
						state.LastRabbitSfxTime = time
					end
					
					print("Fish " .. i .. " found target, moving to collect")
					state.Target = found
					state.State = S_MOVING
					
					-- Pre-calculate targetPos for this frame so we don't fall back to formation logic
					-- (which would cause the fish to momentarily face the player)
					targetPos = state.Target.Position + Vector3.new(0, 2, 0)
				end
			end
			-- Else: Stays Idle (Formation)
			
		-- MOVING: Fly to food
		elseif state.State == S_MOVING then
			if state.Target then
				-- Validate capacity while moving? Optional.
				-- If valid target
				local dest = state.Target.Position + Vector3.new(0, 2, 0)
				local dist = (dest - model.PrimaryPart.Position).Magnitude
				
				if dist < 1.0 then
					state.State = S_GATHERING
					state.Timer = time + (state.Stats.GatherSpeed * (state.CurrentCollectTimeMult or 1))
					state.GatherRoll = math.rad(rng:NextNumber(-15, 15)) -- Random Roll variation
					state.GatherPitch = math.rad(rng:NextNumber(15, 40)) -- Random Pitch (Nose down)
					state.GatherYaw = math.rad(rng:NextNumber(-30, 30)) -- Random Yaw variation
				else
					targetPos = dest
				end
			else
				state.State = S_IDLE
			end
			
		-- ORBIT ATTACK: Orbit mob and attack
		elseif state.State == S_ORBIT_ATTACK then
			if _G.OrbitTarget and _G.OrbitTarget.Parent and _G.OrbitTarget.PrimaryPart then
				-- Movement target
				local mobRoot = _G.OrbitTarget.PrimaryPart
				local center = mobRoot.Position
				local goldenAngle = 2.39996
				local orbitRadius = 8 + (math.sqrt(numericIndex) * 1.5)
				local orbitSpeed = 4.0
				local orbitAngle = (numericIndex * goldenAngle) + (time * orbitSpeed)
				local offset = Vector3.new(math.cos(orbitAngle) * orbitRadius, 2 + math.sin(time * 2 + numericIndex), math.sin(orbitAngle) * orbitRadius)
				targetPos = center + offset -- Orbit mob
				
				-- Attack & Energy Logic
				local atkSpeed = state.Stats.AttackSpeed or 1.0
				if not state.NextAttackTime then state.NextAttackTime = time + (1.0 / atkSpeed) end
				
				if time >= state.NextAttackTime then
					state.NextAttackTime = time + (1.0 / atkSpeed)
					
					-- Gain Half Energy
					if not state.Energy then state.Energy = 0 end
					
					local fId = model:GetAttribute("FishID") or "Basic Fish"
					local cfg = FishConfig.Fish[fId]
					if cfg and (cfg.Ability or cfg.AbilityName) then
						local abilityConfig = cfg.Ability or (cfg.AbilityName and FishConfig.Abilities[cfg.AbilityName])
						if abilityConfig and abilityConfig.Damage and abilityConfig.Damage > 0 then
							local required = abilityConfig.EnergyRequired or 12
							local gainData = abilityConfig.EnergyPerHarvest
							local energyGain = 1
							if type(gainData) == "table" then
								energyGain = rng:NextNumber(gainData.Min or 1, gainData.Max or 1)
							else
								energyGain = tonumber(gainData) or 1
							end
							
							local boostMult = 1.0 + (playerData and playerData.Stats and playerData.Stats.FishEnergyGainBoost or 0)
							energyGain = (energyGain * boostMult) / 2.0 -- HALF ENERGY
							
							state.Energy = state.Energy + energyGain
							
							-- Update UI Bar
							if model.PrimaryPart then
								local bb = model.PrimaryPart:FindFirstChild("EnergyGui")
								if bb and bb.Enabled then
									local energyBar = bb:FindFirstChild("EnergyBar") or bb:FindFirstChild("Background")
									if energyBar then
										local fill = energyBar:FindFirstChild("Fill", true)
										if fill then
											local pct = math.clamp(state.Energy / required, 0, 1)
											local isHorizontal = (fill.Parent.AbsoluteSize.X > fill.Parent.AbsoluteSize.Y)
											if isHorizontal then
												fill:TweenSize(UDim2.new(pct, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, 0.1, true)
											else
												fill:TweenSize(UDim2.new(1, 0, pct, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, 0.1, true)
											end
										end
									end
								end
							end
							
							if state.Energy >= required then
								state.State = S_CASTING_ABILITY
								state.Energy = 0
								state.NextAttackTime = nil -- Reset attack timer for when it comes back
							end
						end
					end
				end
			else
				state.State = S_IDLE
			end
			
		-- CASTING ABILITY: Fly to center of mob and trigger
		elseif state.State == S_CASTING_ABILITY then
			if _G.OrbitTarget and _G.OrbitTarget.Parent and _G.OrbitTarget.PrimaryPart then
				local center = _G.OrbitTarget.PrimaryPart.Position
				targetPos = center
				
				local dist = (center - model.PrimaryPart.Position).Magnitude
				if dist < 4.0 then
					-- We reached the center! Tell the client to perform the ability
					state.AbilityReady = true
					state.State = S_ORBIT_ATTACK -- Go back to orbiting after casting
				end
			else
				state.State = S_IDLE
			end
			
		-- GATHERING: Munch munch
		elseif state.State == S_GATHERING then
			if state.Target then
				-- Position: Hover over target (above it)
				local hoverPos = state.Target.Position + Vector3.new(0, 10, 0)
				destination = hoverPos
				
				-- But FACE the algae below (so fish looks down)
				targetPos = state.Target.Position
				
				if time >= state.Timer then
					FishHarvestEvent:FireServer(state.FishIndex, state.Target)
					
					-- Rabbit Fish SFX: Collect (1/40)
					local fId = model:GetAttribute("FishID")
					if fId == "Rabbit Fish" and rng:NextInteger(1, 40) == 1 then
						local TriggerAbilityEvent = Remotes:WaitForChild("TriggerAbilityEvent")
						TriggerAbilityEvent:FireServer(numericIndex, fId, model.PrimaryPart.Position, "RabbitCollect")
					end
					
					-- INCREMENT ABILITY ENERGY
					if not state.Energy then state.Energy = 0 end
					if not state.Energy2 then state.Energy2 = 0 end -- Secondary
					
					local fId = model:GetAttribute("FishID") or "Basic Fish"
					local cfg = FishConfig.Fish[fId]
				
				if cfg and (cfg.Ability or cfg.AbilityName) then
					local abilityConfig = cfg.Ability or (cfg.AbilityName and FishConfig.Abilities[cfg.AbilityName])
					if not abilityConfig then
						warn("FishController: Ability not found for", fId, "- AbilityName:", cfg.AbilityName)
					else
                    local required = abilityConfig.EnergyRequired or 12
                    
						local gainData = abilityConfig.EnergyPerHarvest
						local energyGain = 1
						if type(gainData) == "table" then
							-- Use NextNumber for continuous randomness instead of discrete integers
							energyGain = rng:NextNumber(gainData.Min or 1, gainData.Max or 1)
						else
							energyGain = tonumber(gainData) or 1
						end
						
						local boostMult = 1.0 + (playerData and playerData.Stats and playerData.Stats.FishEnergyGainBoost or 0)
						energyGain = energyGain * boostMult
						
						-- PASSIVE: Mitosis (Mirror Fish) - 1/70 Chance
						if cfg and cfg.Passive == "Mitosis" then
							local passiveCfg = FishConfig.Passives.Mitosis
							local chance = passiveCfg and passiveCfg.Chance or 70
							if rng:NextInteger(1, chance) == 1 then
								-- Trigger Duplicate
								local TriggerAbilityEvent = Remotes:WaitForChild("TriggerAbilityEvent")
								TriggerAbilityEvent:FireServer(numericIndex, fId, model.PrimaryPart.Position, "Mitosis")
							end
						end
						
						state.Energy = state.Energy + energyGain
                        
								-- Update GUI
						if model.PrimaryPart then
							local bb = model.PrimaryPart:FindFirstChild("EnergyGui")
							if bb then
								-- Calculates percentage
								local pct = math.min(state.Energy / required, 1)

								-- Update Primary Bar
								local energyBar = bb:FindFirstChild("EnergyBar") or bb:FindFirstChild("Background")
								local fill = nil
								
								-- Try to find Fill
								if energyBar then
									fill = energyBar:FindFirstChild("Fill", true) -- Recursive search
								end
								
								if fill then
									-- Determine direction based on size (Assumption: wider = horizontal)
									local isHorizontal = (fill.Parent.AbsoluteSize.X > fill.Parent.AbsoluteSize.Y)
									
									if isHorizontal then
										fill:TweenSize(UDim2.new(pct, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, 0.2, true)
									else
										fill:TweenSize(UDim2.new(1, 0, pct, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Linear, 0.2, true)
									end
								else
									-- Debug structure
									warn("FishController: Energy 'Fill' not found in EnergyGui for " .. fId)
									if energyBar then
										print("Children of EnergyBar:", energyBar:GetChildren())
									else
										print("EnergyBar not found in", bb:GetChildren())
									end
								end
							end
						end
						
						-- Ability Trigger: Once threshold is met, immediately ready it
						if state.Energy >= required then
							state.AbilityReady = true
						end
					end
				else
						-- print("Fish " .. i .. " has no ability configured")
					end
					
					-- SyncFish will run soon.
					local localMax = (maxCapacity > 0 and maxCapacity) or 5
					if currentPlankton >= localMax then
						print("Fish " .. i .. " bag full (" .. currentPlankton .. "/" .. localMax .. "), returning to player")
						state.Target = nil
						state.State = S_DELIVERING
					else
						-- HOPPING LOGIC: Find random neighbor
						local nextTarget = FindRandomNeighbor(state.Target.Position, 15, state.Target, inField)
						
						if nextTarget and inField then
							state.Target = nextTarget
							state.State = S_MOVING
						else
							state.Target = nil
							state.State = S_IDLE
						end
					end
				end
			else
				state.State = S_IDLE
			end
		
		-- RETREATING: Fly back to tank
		elseif state.State == S_RETREATING then
			if isInTankMode and tankWanderCenter then
				-- Go straight to the tank center (plus a small index-based offset for spacing)
				local goldenAngle = 2.39996
				local orbitRadius = 2 + (math.sqrt(numericIndex) * 1.5)
				local orbitAngle = numericIndex * goldenAngle
				local offset = Vector3.new(math.cos(orbitAngle) * orbitRadius, 0, math.sin(orbitAngle) * orbitRadius)
				
				destination = tankWanderCenter + offset
				
				local dist = (destination - currentPos).Magnitude
				if dist < 1 then
					state.State = S_IDLE -- Arrived back!
				end
			else
				state.State = S_IDLE -- Lost tank, go back to formation
			end
		end
		
		-- MOVEMENT PHYSICS
		local finalNewPos = currentPos
		local facingCF = nil 
		
		-- Determine Destination (Point-to-Point System)
		local isFormation = false
		local isDirectMovement = false -- For conversion states that need straight-line movement
		
		-- PRIORITY 1: Direct point-to-point movement (conversion, gathering, etc.)
		if targetPos then
			destination = targetPos
			isDirectMovement = true
		elseif isCurrentlyConverting and slotPos then
			-- Moving directly to slot during conversion - NO formation influence
			destination = slotPos
			isDirectMovement = true
		elseif state.State == S_CONVERT_TO_PLAYER then
			-- Moving directly to player - NO formation influence
			destination = char.PrimaryPart.Position
			isDirectMovement = true
		elseif isInTankMode and tankWanderCenter then
			-- TANK WANDER (Wander around inside the aquarium volume)
			-- Reach target check: If arrived or no target, pick a new random spot in the "Wander" part
			if not state.TankWanderTarget or (currentPos - state.TankWanderTarget).Magnitude < 4 then
				local size = tankWanderSize or Vector3.new(10, 5, 10)
				local center = tankWanderCenter
				state.TankWanderTarget = center + Vector3.new(
					(math.random() - 0.5) * size.X,
					(math.random() - 0.5) * (size.Y or 10),
					(math.random() - 0.5) * size.Z
				)
			end
			destination = state.TankWanderTarget
		elseif _G.OrbitTarget and _G.OrbitTarget.Parent and _G.OrbitTarget.PrimaryPart then
			-- ORBIT TARGET: Orbit around a mob (combat)
			local center = _G.OrbitTarget.PrimaryPart.Position
			local goldenAngle = 2.39996
			local orbitRadius = 8 + (math.sqrt(numericIndex) * 1.5)
			local orbitSpeed = 4.0
			local orbitAngle = (numericIndex * goldenAngle) + (os.clock() * orbitSpeed)
			local offset = Vector3.new(math.cos(orbitAngle) * orbitRadius, 2 + math.sin(os.clock() * 2 + numericIndex), math.sin(orbitAngle) * orbitRadius)
			destination = center + offset
			isDirectMovement = true
		else
			-- FORMATION: Stationary around player (No Wandering)
			-- If in formation, we are NOT in the conversion zone
			if fishReadyStates[i] then
				fishReadyStates[i] = false
				UpdateFishReadyState:FireServer(i, false)
				ConversionVisualController.RemoveBeamsFromFish(model)
			end

			-- Base position using golden angle distribution
			-- Temporary clones (Mitosis) have indices 1000+, map them to a closer orbit (e.g. 15-30 range)
			local formationIndex = (numericIndex >= 1000) and ((numericIndex % 15) + 12) or numericIndex
			local goldenAngle = 2.39996
			local orbitRadius = 6 + (math.sqrt(formationIndex) * 2.5)
			local orbitAngle = formationIndex * goldenAngle
			
			-- Home position
			local homeX = math.cos(orbitAngle) * orbitRadius
			local homeZ = math.sin(orbitAngle) * orbitRadius
			local homeY = 0
			
			-- Add random floating motion using noise
			local seed = formationIndex * 1337
			local floatSpeed = 0.3 -- Slower than before for gentle floating
			local floatRange = 3 -- How far they drift from home
			
			local driftX = math.noise(time * floatSpeed, seed, 0) * floatRange
			local driftY = math.noise(time * floatSpeed, seed, 100) * floatRange
			local driftZ = math.noise(time * floatSpeed, seed, 200) * floatRange
			
			local offset = Vector3.new(homeX + driftX, homeY + driftY, homeZ + driftZ)
			destination = (smoothedRootCF * CFrame.new(offset)).Position
			isFormation = true
		end
		
		-- EXECUTE CONSTANT MOVEMENT
		-- "Always follow 8 walkspeed" (or config speed)
		local speed = moveSpeed or 8 -- Use calculated moveSpeed which includes multiplier
		local vec = (destination - currentPos)
		local dist = vec.Magnitude
		
		-- Distance Snap (Teleport if too far - increased threshold)
		if dist > 500 then
			finalNewPos = destination
		else
			-- Constant Speed Math
			-- Only move if strictly needed (reduce jitter at destination)
			if dist > 0.1 then
				local step = math.min(dist, speed * dt)
				finalNewPos = currentPos + (vec.Unit * step)
			else
				finalNewPos = destination
			end
		end
		
		-- ROTATION LOGIC - Face movement direction or face player when idle
		local travelVec = (finalNewPos - currentPos)
		local targetLookDir = state.LastFacingDir or model.PrimaryPart.CFrame.LookVector
		
		-- If moving, face the direction of travel (including pitch for gathering)
		if travelVec.Magnitude > 0.05 then
			targetLookDir = SafeUnit(travelVec)
			-- Keep full 3D direction (no flattening) so fish can look down/up
		elseif isFormation then
			-- If idle/in formation, face toward the player
			local toPlayer = (rootPos - currentPos)
			if toPlayer.Magnitude > 0.1 then
				targetLookDir = SafeUnit(toPlayer)
			end
		end
		-- Otherwise keep current facing (stationary, not in formation)


		-- Apply Smoothing to the Heading Vector with Adaptive Speed
		local finalHeading = SafeUnit(targetLookDir)
		
		-- Calculate how different the current and target directions are
		local dotProduct = state.LastFacingDir:Dot(finalHeading)
		local angleDifference = math.acos(math.clamp(dotProduct, -1, 1))
		
		-- Adaptive lerp speed: Turn faster when facing wrong direction
		local lerpSpeed = 0.1 -- Base speed
		if angleDifference > math.rad(90) then
			-- Facing completely wrong direction (backwards): snap instantly
			lerpSpeed = 1.0
		elseif angleDifference > math.rad(45) then
			-- Facing moderately wrong: turn fast
			lerpSpeed = 0.5
		elseif travelVec.Magnitude > 0.05 then
			-- Actively moving: turn moderately fast
			lerpSpeed = 0.3
		end
		


		state.LastFacingDir = state.LastFacingDir:Lerp(finalHeading, lerpSpeed)
		if state.LastFacingDir.Magnitude < 0.01 then
			state.LastFacingDir = Vector3.new(0, 0, 1)
		end
		state.LastFacingDir = state.LastFacingDir.Unit -- Ensure unit vector
		state.LastFacingDir = state.LastFacingDir.Unit
		
		local baseLook = CFrame.lookAt(finalNewPos, finalNewPos + state.LastFacingDir)

		
		-- Final Aesthetic Wiggle (Additive based on state)
		if isCurrentlyConverting and state.State == S_CONVERT_WAIT then
			local wobble = math.sin(time * 15) * 0.4
			facingCF = baseLook * CFrame.Angles(0, wobble, 0)
		elseif travelVec.Magnitude > 0.05 then
			local swimWiggle = math.sin(time * 18) * 0.25
			facingCF = baseLook * CFrame.Angles(0, swimWiggle, swimWiggle * 0.5)
		else
			-- Calm Idle Wiggle
			local wY = math.sin(time * 12) * 0.15
			local wZ = math.cos(time * 12) * 0.07
			facingCF = baseLook * CFrame.Angles(0, wY, wZ)
		end
		
		-- Final CFrame Update (SKIP if performing ability!)
		if not state.PerformingAbility then
			if facingCF then
				-- Special case: If distance snap happened, apply immediately
				if dist > 100 then
					model:SetPrimaryPartCFrame(facingCF)
					state.LastFacingDir = facingCF.LookVector
				else
					-- Smooth rotation while maintaining correct position
					local currentRot = currentCF.Rotation
					local targetRot = facingCF.Rotation
					local smoothRot = currentRot:Lerp(targetRot, 0.2) -- Smoother turning
					
					-- Apply position + smoothed rotation
					model:SetPrimaryPartCFrame(CFrame.new(finalNewPos) * smoothRot)
				end
			end
		end
		
		-- Special Visuals: Puppeteer Fish Spinner
		local spinner = model:FindFirstChild("SpinnerThing") or model:FindFirstChild("SpinningPart")
		if spinner and model.PrimaryPart then
			local spinTime = time * 2
			-- 4 studs up
			local offset = Vector3.new(0, 4, 0)
			
			-- Smooth rotation + Wobble
			-- Base rotation (Y axis spin)
			local baseRot = CFrame.Angles(0, spinTime, 0)
			
			-- Wobble (Sine waves on X/Z)
			local wobble = CFrame.Angles(
				math.sin(spinTime * 1.5) * 0.2, -- X tilt
				0, 
				math.cos(spinTime * 1.2) * 0.2  -- Z tilt
			)
			
			-- Combine: Fish Position (Global) + Offset + Rotation (Global Upright)
			-- Using Position ensures it stays upright even if the fish tilts
			local targetCF = CFrame.new(model.PrimaryPart.Position + offset) * baseRot * wobble
			
			-- Smooth Lerp (Dynamic Lag)
			spinner.CFrame = spinner.CFrame:Lerp(targetCF, 0.1)
		end
	end
end

function FishController.GetSpawnedFish()
	return spawnedFish
end

return FishController
