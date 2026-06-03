local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
local AbilityService = require(script.Parent.AbilityService)
local SecurityService = require(script.Parent.SecurityService)

local ConversionService = {}

local convertingPlayers = {} -- [UserId] = true/false
local fishLoops = {} -- [UserId] = {[fishIndex] = thread}

-- Get existing VisualEvent from Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local VisualEvent = Remotes:WaitForChild("VisualEvent")

-- Setup RemoteEvent for fish readiness
local UpdateFishReadyState = Remotes:FindFirstChild("UpdateFishReadyState")
if not UpdateFishReadyState then
	UpdateFishReadyState = Instance.new("RemoteEvent")
	UpdateFishReadyState.Name = "UpdateFishReadyState"
	UpdateFishReadyState.Parent = Remotes
end

local FishConvertedEvent = Remotes:FindFirstChild("FishConvertedEvent")
if not FishConvertedEvent then
	FishConvertedEvent = Instance.new("RemoteEvent")
	FishConvertedEvent.Name = "FishConvertedEvent"
	FishConvertedEvent.Parent = Remotes
end

-- Standard Critical Hit Roll
local function RollPRD(data, chance)
	if chance >= 1 then return true end
	if chance <= 0 then return false end
	return math.random() < chance
end

-- Individual Fish Conversion Logic
function ConversionService.StartFishLoop(player, fishIndex)
	local userId = player.UserId
	if not fishLoops[userId] then fishLoops[userId] = {} end
	
	-- Stop existing loop if any
	if fishLoops[userId][fishIndex] then
		task.cancel(fishLoops[userId][fishIndex])
	end
	
	fishLoops[userId][fishIndex] = task.spawn(function()
		while convertingPlayers[userId] and player.Parent do
			-- 1. Get current data
			local data = PlayerData.get(player)
			if not data then break end
			
			-- 2. Validate Fish and Algae
			local fishData = data.FishSchool and data.FishSchool[tostring(fishIndex)]
			local totalAlgae = 0
			for _, amt in pairs(data.Plankton or {}) do totalAlgae += amt end
			
			if not fishData or totalAlgae <= 0 then
				-- Stop this fish's loop if it no longer exists or no algae
				break
			end
			
			-- 3. Get Stats
			local fishConfig = FishConfig.Fish[fishData.Id]
			if not fishConfig or not fishConfig.BaseStats then break end
			
			local waitTime = fishConfig.BaseStats.ConvertSpeed or 3
			local fishLevel = fishData.Level or 1
			local levelBonus = 1.1 ^ (fishLevel - 1) -- Exponential +10% per level !
			local totalAmount = math.floor((fishConfig.BaseStats.ConvertAmount or 1) * levelBonus)
			
			-- PASSIVE: Overtaking Melody (Boost speeds by 1% per stack)
			if fishConfig.Passive == "Overtaking Melody" then
				local stacks = AbilityService.GetBuffStacks(player, "RhythmFever")
				if stacks > 0 then
					local boost = 1 + (stacks * 0.01)
					waitTime = waitTime / boost
				end
			end
			
			-- 4. Initial Wait (Individual timing)
			task.wait(waitTime)
			
			-- 5. Final check before work
			if not convertingPlayers[userId] then break end
			
			-- 6. Perform Work
			local biomassGained = 0
			local isCrit = false
			
			PlayerData.update(player, function(updatedData)
				local convertMult = updatedData.Stats and updatedData.Stats.ConvertMultiplier or 1
				local totalAlgaeToTake = totalAmount * convertMult
				local rawAlgaeTaken = 0
				
				-- Handle Criticals
				local critChance = (updatedData.Stats.CriticalChance or 0.01) + (updatedData.Stats.CritChanceBonus or 0)
				isCrit = RollPRD(updatedData, critChance)
				
				local yieldMult = 1.0
				if isCrit then
					local baseCritPower = updatedData.Stats.CriticalPower or 3.0
					local critPowerBonus = 1 + (updatedData.Stats.CritPowerBonus or 0)
					yieldMult = baseCritPower * critPowerBonus -- Matching Harvest logic
				end
				
				local gained = 0
				for typeName, amt in pairs(updatedData.Plankton) do
					if amt > 0 and totalAlgaeToTake > 0 then
						local take = math.min(tonumber(amt) or 0, totalAlgaeToTake)
						local resType = ResourceConfig.Types[typeName]
						local resBaseValue = resType and resType.BaseValue or 1
						
						updatedData.Plankton[typeName] -= take
						gained += (take * resBaseValue * (updatedData.Stats.BiomassPerAlgae or 1.0) * yieldMult)
						rawAlgaeTaken += take
						totalAlgaeToTake -= take
					end
				end
				
				if rawAlgaeTaken > 0 then
					updatedData.Biomass = (updatedData.Biomass or 0) + gained
					updatedData.LifetimeBiomass = (updatedData.LifetimeBiomass or 0) + gained
					biomassGained = gained
					
					-- Update Leaderstats
					local leaderstats = player:FindFirstChild("leaderstats")
					if leaderstats then
						local bioStat = leaderstats:FindFirstChild("Biomass")
						local alStat = leaderstats:FindFirstChild("Algae")
						if bioStat then bioStat.Value = updatedData.Biomass end
						if alStat then 
							local newTotal = 0
							for _, amt in pairs(updatedData.Plankton) do newTotal += amt end
							alStat.Value = newTotal
						end
					end
					return updatedData
				end
				return nil -- No algae left
			end)
			
			-- 7. Visual Feedback
			if biomassGained > 0 then
				FishConvertedEvent:FireClient(player, fishIndex, biomassGained, isCrit)
			end
		end
		
		if fishLoops[userId] then
			fishLoops[userId][fishIndex] = nil
		end
	end)
end

UpdateFishReadyState.OnServerEvent:Connect(function(player, fishIndex, isReady)
	if not SecurityService.ValidateRemoteCall(player, "UpdateFishReadyState") then return end
	local userId = player.UserId
	if not convertingPlayers[userId] then return end
	
	if isReady then
		ConversionService.StartFishLoop(player, fishIndex)
	else
		-- Stop fish loop if it was running
		if fishLoops[userId] and fishLoops[userId][fishIndex] then
			task.cancel(fishLoops[userId][fishIndex])
			fishLoops[userId][fishIndex] = nil
		end
	end
end)

function ConversionService.Convert(player)
	if convertingPlayers[player.UserId] then return end
	convertingPlayers[player.UserId] = true
	
	-- Set converting flag in player data and sync to client
	PlayerData.update(player, function(data)
		data.IsConverting = true
		return data
	end)
	
	-- Explicitly sync to client
	local currentData = PlayerData.get(player)
	if currentData then
		local DataUpdateEvent = Remotes:FindFirstChild("DataUpdateEvent")
		if DataUpdateEvent then
			DataUpdateEvent:FireClient(player, currentData)
		end
	end
	
	-- We don't need a master loop anymore. 
	-- Each fish will start its own loop via the UpdateFishReadyState event.
	-- We just need a proximity check to auto-stop everything if player leaves.
	task.spawn(function()
		while convertingPlayers[player.UserId] and player.Parent do
			local char = player.Character
			if char and char.PrimaryPart then
				-- 1. Check Algae
				local data = PlayerData.get(player)
				local totalAlgae = 0
				if data and data.Plankton then
					for _, amt in pairs(data.Plankton) do totalAlgae += amt end
				end
				
				if totalAlgae <= 0 then
					ConversionService.Stop(player)
					break 
				end

				-- 2. Find player's aquarium
				local aquariumsFolder = Workspace:FindFirstChild("Aquariums")
				local playerAquarium = nil
				
				if aquariumsFolder then
					for _, plot in ipairs(aquariumsFolder:GetChildren()) do
						-- Strict Attribute Check
						if plot:GetAttribute("OwnerUserId") == player.UserId then
							playerAquarium = plot
							break
						end
					end
					
					-- Fallback for legacy text (only if attributes fail for some reason)
					if not playerAquarium then
						for _, plot in ipairs(aquariumsFolder:GetChildren()) do
							local ownerPart = plot:FindFirstChild("Ownership")
							local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
							local lbl = gui and gui:FindFirstChild("TextLabel")
							local expected = player.Name .. "'s Aquarium"
							
							if lbl and lbl.Text == expected then
								playerAquarium = plot
								break
							end
						end
					end
				end
				
				if playerAquarium then
					local refPart = playerAquarium:FindFirstChild("Spawn") or playerAquarium.PrimaryPart or playerAquarium:FindFirstChildWhichIsA("BasePart")
					if refPart then
						local distance = (char.PrimaryPart.Position - refPart.Position).Magnitude
						if distance > 100 then
							-- Player moved away
							ConversionService.Stop(player)
							break
						end
					end
				else
					ConversionService.Stop(player)
					break
				end
			end
			task.wait(2)
		end
	end)
end

function ConversionService.Stop(player)
	local userId = player.UserId
	convertingPlayers[userId] = false
	
	-- Cleanup all fish loops
	if fishLoops[userId] then
		for _, thread in pairs(fishLoops[userId]) do
			task.cancel(thread)
		end
		fishLoops[userId] = nil
	end
	
	-- Clear converting flag and sync to client
	PlayerData.update(player, function(data)
		data.IsConverting = false
		return data
	end)
	
	-- Explicitly sync to client
	local currentData = PlayerData.get(player)
	if currentData then
		local DataUpdateEvent = Remotes:FindFirstChild("DataUpdateEvent")
		if DataUpdateEvent then
			DataUpdateEvent:FireClient(player, currentData)
		end
	end
end

-- Initialize Zone Detection
function ConversionService.Start()
	Players.PlayerAdded:Connect(function(player)
		PlayerData.update(player, function(data)
			data.IsConverting = false
			return data
		end)
	end)
	
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerData.update(player, function(data)
			data.IsConverting = false
			return data
		end)
	end
end

return ConversionService
