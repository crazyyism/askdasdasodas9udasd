local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HarvestService = require(script.Parent.HarvestService) -- For PRD helper
local SecurityService = require(script.Parent.SecurityService)
local FishService = require(script.Parent.FishService)

local AquariumService = {}
local rng = Random.new()

-- Remotes
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local ClaimAquarium = Remotes:FindFirstChild("ClaimAquarium")
if not ClaimAquarium then
	ClaimAquarium = Instance.new("RemoteFunction")
	ClaimAquarium.Name = "ClaimAquarium"
	ClaimAquarium.Parent = Remotes
end

local StartQuest = Remotes:FindFirstChild("StartQuest")
if not StartQuest then
	StartQuest = Instance.new("RemoteEvent")
	StartQuest.Name = "StartQuest"
	StartQuest.Parent = Remotes
end

local FinishQuest = Remotes:FindFirstChild("FinishQuest")
if not FinishQuest then
	FinishQuest = Instance.new("RemoteEvent")
	FinishQuest.Name = "FinishQuest"
	FinishQuest.Parent = Remotes
end

local UpgradeAquarium = Remotes:FindFirstChild("UpgradeAquarium")
if not UpgradeAquarium then
	UpgradeAquarium = Instance.new("RemoteFunction")
	UpgradeAquarium.Name = "UpgradeAquarium"
	UpgradeAquarium.Parent = Remotes
end

local AquariumState = {} -- [AquariumModel] = Player or nil
local PlayerAquarium = {} -- [Player] = AquariumModel

function AquariumService.Start()
	-- Init any existing aquariums
	local plots = workspace:WaitForChild("Aquariums"):GetChildren()
	for _, plot in ipairs(plots) do
		AquariumState[plot] = nil
		
		-- Ensure Text is "Unclaimed"
		local ownerPart = plot:FindFirstChild("Ownership")
		if ownerPart then
			local gui = ownerPart:FindFirstChild("SurfaceGui")
			if gui then
				local lbl = gui:FindFirstChild("TextLabel")
				if lbl then lbl.Text = "Unclaimed" end
			end
		end
		
		-- Setup Proximity Prompt if not exists or handle on client?
		-- Let's assume Client handles the input "E".
		-- Client fires RemoteFunction to claim.
	end
	
	ClaimAquarium.OnServerInvoke = function(player, aquariumModel)
		if not SecurityService.ValidateRemoteCall(player, "ClaimAquarium") then return false, "Security Check Failed" end
		-- Validate
		if PlayerAquarium[player] then return false, "Already own an aquarium!" end
		if AquariumState[aquariumModel] then return false, "Already claimed!" end
		
		-- Claim
		AquariumState[aquariumModel] = player
		PlayerAquarium[player] = aquariumModel
		aquariumModel:SetAttribute("OwnerUserId", player.UserId)
		
		-- Update Text
		local ownerPart = aquariumModel:FindFirstChild("Ownership")
		if ownerPart then
			local gui = ownerPart:FindFirstChild("SurfaceGui")
			if gui and gui:FindFirstChild("TextLabel") then
				gui.TextLabel.Text = player.Name .. "'s Aquarium"
			end
		end
		
		-- Sync Visuals
		AquariumService.UpdateAquariumVisuals(player, aquariumModel)

		-- Update Respawn Location
		local spawnPart = aquariumModel:FindFirstChild("Spawn")
		if spawnPart then
			-- Create or reuse a SpawnLocation to allow resetting to aquarium
			local respawnPoint = aquariumModel:FindFirstChild("OwnerSpawn")
			if not respawnPoint then
				respawnPoint = Instance.new("SpawnLocation")
				respawnPoint.Name = "OwnerSpawn"
				respawnPoint.Size = Vector3.new(4, 0.5, 4)
				respawnPoint.Transparency = 1
				respawnPoint.CanCollide = false
				respawnPoint.Anchored = true
				respawnPoint.Neutral = false
				respawnPoint.Enabled = true
				respawnPoint.Parent = aquariumModel
			end
			-- Align with visual spawn part
			respawnPoint.CFrame = spawnPart.CFrame + Vector3.new(0, 5, 0)
			
			player.RespawnLocation = respawnPoint
		end
		
		return true
	end

	UpgradeAquarium.OnServerInvoke = function(player, aquariumModel)
		if not SecurityService.ValidateRemoteCall(player, "UpgradeAquarium") then return false, "Security Check Failed" end
		
		if PlayerAquarium[player] ~= aquariumModel then
			return false, "You do not own this aquarium!"
		end
		
		local PlayerData = require(script.Parent.PlayerData)
		local success, msg = false, "Unknown Error"
		
		PlayerData.update(player, function(data)
			local currentLevel = data.AquariumLevel or 0
			local cost = math.floor(2500 * math.pow(3, currentLevel))
			
			if (data.Biomass or 0) < cost then
				msg = "Not enough Biomass! Need " .. cost
				return nil
			end
			
			-- Deduct Biomass and upgrade
			data.Biomass = data.Biomass - cost
			data.AquariumLevel = currentLevel + 1
			
			-- Update leaderstats
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local bioStat = leaderstats:FindFirstChild("Biomass")
				if bioStat then bioStat.Value = data.Biomass end
			end
			
			-- Recalculate stats applies the new AquariumMultiplier
			PlayerData.RecalculateStats(data)
			
			success = true
			msg = data.AquariumLevel
			return data
		end)
		
		if success then
			local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
			if NotificationEvent then
				NotificationEvent:FireClient(player, "Aquarium Upgraded to Level " .. msg .. "!", Color3.fromRGB(50, 255, 50))
			end
			return true, msg
		end
		return false, msg
	end

	StartQuest.OnServerEvent:Connect(function(player, questId)
		if not SecurityService.ValidateRemoteCall(player, "StartQuest") then return end
		local PlayerData = require(script.Parent.PlayerData)
		local QuestConfig = require(ReplicatedStorage.Shared.QuestConfig)
		
		PlayerData.update(player, function(data)
			if questId == "NoobieTurtle" then
				local fishCount = 0
				for _, _ in pairs(data.FishSchool or {}) do fishCount = fishCount + 1 end
				QuestConfig.UpdateNoobieTurtle(data.NoobieTurtleQuestsCompleted or 0, fishCount, player.UserId)
			elseif questId == "ElderTurtle" then
				local fishCount = 0
				for _, _ in pairs(data.FishSchool or {}) do fishCount = fishCount + 1 end
				QuestConfig.UpdateElderTurtle(data.ElderTurtleQuestsCompleted or 0, fishCount, player.UserId)
			end
			
			if data.ActiveQuests and data.ActiveQuests[questId] then
				 return nil 
			end
			
			-- Block restarting completed quests
			if data.CompletedQuests and data.CompletedQuests[questId] then
				warn("Player " .. player.Name .. " tried to restart completed quest: " .. questId)
				return nil
			end
			
			local qCfg = QuestConfig.Quests[questId]
			local initialProgress = 0
			if qCfg and qCfg.Goals then
				-- Pre-populate all goal keys to 0.
				-- This locks in the target field (e.g. "Sun Reef") at quest-start time.
				-- Without this, UpdateNoobieTurtle re-derives the field from current fishCount
				-- on every harvest call, so adding/removing fish mid-quest shifts the tracked field.
				initialProgress = {}
				for k, _ in pairs(qCfg.Goals) do
					initialProgress[k] = 0
				end
			end
			
			if not data.ActiveQuests then data.ActiveQuests = {} end
			data.ActiveQuests[questId] = initialProgress
			data._QuestsDirty = true
			
			return data
		end)
	end)

	FinishQuest.OnServerEvent:Connect(function(player, questId)
		if not SecurityService.ValidateRemoteCall(player, "FinishQuest") then return end
		local PlayerData = require(script.Parent.PlayerData)
		local QuestConfig = require(ReplicatedStorage.Shared.QuestConfig)
		
		PlayerData.update(player, function(data)
			if not data.ActiveQuests or data.ActiveQuests[questId] == nil then
				return nil
			end
			
			local prog = data.ActiveQuests[questId]
			
			-- Rebuild config using the stored progress (locked fields) so the completion
			-- check uses the same goals that were tracked during the quest
			local qCfg
			if questId == "NoobieTurtle" then
				local fishCount = 0
				for _, _ in pairs(data.FishSchool or {}) do fishCount = fishCount + 1 end
				qCfg = QuestConfig.UpdateNoobieTurtle(data.NoobieTurtleQuestsCompleted or 0, fishCount, player.UserId, prog)
			elseif questId == "ElderTurtle" then
				local fishCount = 0
				for _, _ in pairs(data.FishSchool or {}) do fishCount = fishCount + 1 end
				qCfg = QuestConfig.UpdateElderTurtle(data.ElderTurtleQuestsCompleted or 0, fishCount, player.UserId, prog)
			else
				qCfg = QuestConfig.Quests[questId]
			end
			if not qCfg then return nil end
			
			if qCfg.Goals then
				-- Some goals (e.g. AbilitiesCommitted, SeaMinesPopped) are read directly
				-- from data fields rather than progress table. Only reject non-table progress
				-- if there are real progress-tracked goals that require it.
				local hasProgressGoals = false
				for res in pairs(qCfg.Goals) do
					if res ~= "AbilitiesCommitted" and not string.find(res, "SeaMinesPopped") and res ~= "TokensGathered" and res ~= "BiomassTokensGathered" and res ~= "EquipmentsPurchased" and res ~= "MaxAlgaePerSecond" and res ~= "FishRequired" then
						hasProgressGoals = true
						break
					end
				end
				if hasProgressGoals and type(prog) ~= "table" then return nil end
				local safeProgress = (type(prog) == "table") and prog or {}
				for res, goal in pairs(qCfg.Goals) do
					local current
					if res == "AbilitiesCommitted" or string.find(res, "SeaMinesPopped") or res == "TokensGathered" or res == "BiomassTokensGathered" or res == "EquipmentsPurchased" or res == "MaxAlgaePerSecond" then current = data[res] or 0 elseif res == "FishRequired" then local c=0; for _,_ in pairs(data.FishSchool or {}) do c=c+1 end; current = c else current = safeProgress[res] or 0 end
					
					if current < goal then return nil end
				end

			else
				if (prog or 0) < qCfg.GoalAmount then
					 return nil 
				end
			end
			
			if qCfg.Rewards then
				if qCfg.Rewards.AlgaeAmount then
					data.Plankton.GreenAlgae = (data.Plankton.GreenAlgae or 0) + qCfg.Rewards.AlgaeAmount
				end
				if qCfg.Rewards.BiomassAmount then
					data.Biomass = (data.Biomass or 0) + qCfg.Rewards.BiomassAmount
				end
				if qCfg.Rewards.Items then
					data._InventoryDirty = true
					for k, v in pairs(qCfg.Rewards.Items) do
						local item = type(k) == "number" and v or k
						local amount = type(k) == "number" and 1 or v
						
						if item == "Pearl" then
							data.Pearls = (data.Pearls or 0) + amount
						else
							if type(data.Inventory) ~= "table" then data.Inventory = {} end
							data.Inventory[item] = (data.Inventory[item] or 0) + amount
						end
					end
				end
			end
			
			if questId == "NoobieTurtle" then
				local prevCount = data.NoobieTurtleQuestsCompleted or 0
				local newCount = prevCount + 1
				data.NoobieTurtleQuestsCompleted = newCount
				data._QuestsDirty = true
				
				-- Sea Mine rewards
				-- Every 2 quests: +1 Sea Mine
				-- Every 10 quests: +10 bonus Sea Mines (on top of the regular reward)
				local minesToGive = 0
				if newCount % 2 == 0 then
					minesToGive = minesToGive + 1
				end
				if newCount % 5 == 0 then
					minesToGive = minesToGive + 10
				end
				
				if minesToGive > 0 then
					if type(data.Inventory) ~= "table" then data.Inventory = {} end
					data.Inventory["Sea Mine"] = (data.Inventory["Sea Mine"] or 0) + minesToGive
					data._InventoryDirty = true
					-- Store for notification outside the update callback
					data._PendingSeaMinesNotification = minesToGive
				end

			elseif questId == "ElderTurtle" then
				local prevCount = data.ElderTurtleQuestsCompleted or 0
				local newCount = prevCount + 1
				data.ElderTurtleQuestsCompleted = newCount
				data._QuestsDirty = true

			elseif string.sub(questId, 1, 4) == "Lava" then
				-- If it's a Lava Turtle Quest
				data.LavaEnhancements = (data.LavaEnhancements or 0) + 1
				
				local PlayerDataMod = require(script.Parent.PlayerData)
				PlayerDataMod.RecalculateStats(data)
				
				if not data.CompletedQuests then data.CompletedQuests = {} end
				data.CompletedQuests[questId] = os.time()
				data._QuestsDirty = true
			else
				if not data.CompletedQuests then data.CompletedQuests = {} end
				data.CompletedQuests[questId] = os.time()
				data._QuestsDirty = true
			end
			
			data.ActiveQuests[questId] = nil  
			
		
			
			return data
		end)
		
		-- Notify player about Sea Mine rewards (read after update is committed)
		local afterData = PlayerData.get(player)
		if afterData and afterData._PendingSeaMinesNotification then
			local minesAwarded = afterData._PendingSeaMinesNotification
			PlayerData.update(player, function(data)
				data._PendingSeaMinesNotification = nil
				return data
			end, true)
			
			local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
			if NotificationEvent then
				local msg = "Quest Reward: +" .. minesAwarded .. " Sea Mine" .. (minesAwarded > 1 and "s" or "")
				if minesAwarded > 1 then
					msg = msg .. " (includes " .. (minesAwarded - 1) .. " milestone bonus!)"
				end
				NotificationEvent:FireClient(player, msg, Color3.fromRGB(255, 100, 100))
			end
			local ItemAddedEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ItemAddedEvent")
			if ItemAddedEvent then
				ItemAddedEvent:FireClient(player, "Sea Mine", minesAwarded, "Item", 0, 0)
			end
		end
	end)

	function AquariumService.UpdateSlotVisuals(slotInstance, fishData)
		local facePart = slotInstance:FindFirstChild("FishFace") or slotInstance:FindFirstChildWhichIsA("BasePart")
		
		if not fishData then
			-- CLEAR SLOT
			if facePart then
				for _, d in ipairs(facePart:GetChildren()) do
					if d:IsA("Decal") then d.Texture = "" end
				end
				if facePart:IsA("BasePart") then
					facePart.Color = Color3.fromRGB(163, 162, 165) -- Default Grey
				end
			end
			return
		end

		local FishConfig = require(game:GetService("ReplicatedStorage").Shared.FishConfig)
		local fishCfg = FishConfig.Fish[fishData.Id]
		if not fishCfg then 
			warn("AquariumService: No config found for fish ID:", fishData.Id)
			return 
		end

		-- 1. Update Decal on FishFace part
		if facePart then
			-- Find the existing decal (don't create new ones)
			local decal = facePart:FindFirstChildOfClass("Decal")
			if decal then
				local success, err = pcall(function()
					-- Force refresh by setting to blank first (fixes Roblox asset loading issue)
					task.spawn(function()
						decal.Texture = ""
						task.wait(0.05)
						decal.Texture = fishCfg.DecalId or ""
					end)
				end)
				if not success then
					warn("AquariumService: Failed to set decal texture:", err)
				end
			else
				warn("AquariumService: No Decal found in FishFace part for slot", slotInstance.Name)
			end
		else
			warn("AquariumService: No FishFace part found for slot", slotInstance.Name)
		end

		-- 2. Update Color of FishFace Only
		local rarity = fishData.Rarity or fishCfg.Rarity or "Common"
		local rarCfg = FishConfig.Rarities[rarity]
		if rarCfg then
			if facePart and facePart:IsA("BasePart") then
				facePart.Color = rarCfg.Color
			end
		end
	end

	function AquariumService.UpdateAquariumVisuals(player, aquariumModel)
		local PlayerData = require(script.Parent.PlayerData)
		local data = PlayerData.get(player)
		if not data then return end
		-- data.FishSchool may be nil if empty, that's fine
		local school = data.FishSchool or {}
		
		-- Find slots either in a folder named "Slots" or "FishSlot" (if it's the container)
		local slotsContainer = aquariumModel:FindFirstChild("Slots") or aquariumModel:FindFirstChild("FishSlot") or aquariumModel
		if slotsContainer.Name == "FishSlot" and slotsContainer.Parent ~= aquariumModel then
			slotsContainer = slotsContainer.Parent
		end
		
		-- Helper to safely clear a slot
		local function ClearSlotVisuals(slotInst)
			local facePart = slotInst:FindFirstChild("FishFace") or slotInst:FindFirstChildWhichIsA("BasePart")
			if facePart then
				for _, d in ipairs(facePart:GetChildren()) do
					if d:IsA("Decal") then d.Texture = "" end
				end
				if facePart:IsA("BasePart") then
					facePart.Color = Color3.fromRGB(163, 162, 165) -- Default Grey
				end
			end
		end

		-- Iterate ALL physical slots to ensure we clear ones the player doesn't use
		for _, child in ipairs(slotsContainer:GetChildren()) do
			-- Check if this child represents a valid slot (Has number or is "FishSlot")
			local num = child.Name:match("%d+")
			if not num and (child.Name == "FishSlot") then num = "1" end
			
			if num then
				-- Check if player has fish for this slot
				local idxStr = tostring(tonumber(num)) -- Normalize to "1", "2"
				local fishData = school[idxStr]
				
				if fishData then
					AquariumService.UpdateSlotVisuals(child, fishData)
				else
					-- Player has no fish here -> CLEAR IT
					ClearSlotVisuals(child)
				end
			end
		end
	end
	
	local ProcessEggDrop = Remotes:FindFirstChild("ProcessEggDrop")
	if not ProcessEggDrop then
		ProcessEggDrop = Instance.new("RemoteFunction")
		ProcessEggDrop.Name = "ProcessEggDrop"
		ProcessEggDrop.Parent = Remotes
	end
	
	ProcessEggDrop.OnServerInvoke = function(player, aquariumModel, eggName, slotId, feedAmount)
		if not SecurityService.ValidateRemoteCall(player, "ProcessEggDrop") then return false, "Security Check Failed" end
		-- 1. Validate Ownership
		if PlayerAquarium[player] ~= aquariumModel then
			return false, "You don't own this aquarium!"
		end
		
		if not slotId then return false, "No slot specified!" end
		
		-- Sanitize slotId: Extract only the number
		local rawSlotId = tostring(slotId)
		local numericSlotId = rawSlotId:match("%d+")
		
		if not numericSlotId then
			return false, "Invalid Slot ID: " .. rawSlotId
		end
		slotId = numericSlotId
		
		local PlayerData = require(script.Parent.PlayerData)
		local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
		local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)
		
		local success, msg = false, "Unknown Error"
		local newFish = nil
		local finalConsumedCount = 1
		
		-- 2. Transaction
		PlayerData.update(player, function(data)
			-- Validate egg config FIRST (before consuming anything)
			local eggCfg = EquipmentConfig[eggName]
			if not eggCfg then
				msg = "This item cannot be placed in an aquarium slot!"
				return nil
			end
			
			-- Check Inventory Count
			local availableCount = (data.Inventory and data.Inventory[eggName]) or 0
			
			if availableCount <= 0 then
				msg = "Item not found in inventory!"
				return nil
			end

			-- Validate Slot Usage
			local slotOccupied = (data.FishSchool[tostring(slotId)] ~= nil)
			
			if eggCfg.IsEviction then
				if not slotOccupied then
					msg = "This slot is already empty!"
					return nil
				end
				
				data.Inventory[eggName] = data.Inventory[eggName] - 1
				if data.Inventory[eggName] <= 0 then data.Inventory[eggName] = nil end
				
				data._InventoryDirty = true
				
				data.FishSchool[tostring(slotId)] = nil
				data._FishDirty = true
				
				success = true
				return data
			end
			
			if eggCfg.IsFeed then
				if not slotOccupied then
					msg = "This slot is empty! You can only feed existing fish."
					return nil
				end
				
				local rawFeed = tonumber(feedAmount) or 1
				if rawFeed ~= rawFeed then rawFeed = 1 end -- NaN check
				feedAmount = math.floor(math.clamp(rawFeed, 1, availableCount))
				
				if feedAmount > availableCount then
					msg = "Not enough feed in inventory!"
					return nil
				end
				
				-- Consume Feed
				data.Inventory[eggName] = data.Inventory[eggName] - feedAmount
				if data.Inventory[eggName] <= 0 then data.Inventory[eggName] = nil end
				
				data._InventoryDirty = true
				
				-- Add XP
				FishService.AddXPToData(data, slotId, 1000 * feedAmount, player)
				
				newFish = data.FishSchool[tostring(slotId)]
				success = true
				return data
			end
			
			local isHatchable = eggCfg.Rarities ~= nil and not eggCfg.IsFeed and eggName ~= "Rhythm Egg"
			
			if isHatchable then
				local targetRarities = {}
				if data.Settings and data.Settings.UntilMythic then
					targetRarities["Mythic"] = true
				elseif data.Settings and data.Settings.UntilLegendary then
					targetRarities["Legendary"] = true
					targetRarities["Mythic"] = true
				end
				
				if eggCfg.RequiresFish then
					if not slotOccupied then
						msg = "This item requires an existing fish to use!"
						return nil
					end
				end
				
				local consumedCount = 0
				local lastRolledFish = nil
				local rollAgain = true
				
				while rollAgain do
					local currentCount = (data.Inventory and data.Inventory[eggName]) or 0
					if currentCount <= 0 then
						break
					end
					
					data.Inventory[eggName] = data.Inventory[eggName] - 1
					if data.Inventory[eggName] <= 0 then data.Inventory[eggName] = nil end
					data._InventoryDirty = true
					consumedCount = consumedCount + 1
					
					-- Rarity Roll
					local chosenRarity = "Common"
					local priorities = {"Mythic", "Legendary", "Epic", "Rare", "Common"}
					local totalWeight = 0
					for _, rarity in ipairs(priorities) do
						totalWeight = totalWeight + (eggCfg.Rarities[rarity] or 0)
					end
					
					if totalWeight > 0 then
						local roll = rng:NextNumber(0, totalWeight)
						local currentSum = 0
						chosenRarity = nil
						for _, rarity in ipairs(priorities) do
							local weight = eggCfg.Rarities[rarity] or 0
							if weight <= 0 then continue end
							
							currentSum = currentSum + weight
							if roll <= currentSum then
								chosenRarity = rarity
								break
							end
						end
						if not chosenRarity then chosenRarity = "Common" end
					end
					
					if chosenRarity == "Common" and (eggCfg.Rarities.Common or 0) == 0 then
						for _, r in ipairs(priorities) do
							if (eggCfg.Rarities[r] or 0) > 0 then
								chosenRarity = r
								break
							end
						end
					end
					
					-- Pick Fish ID
					local candidates = {}
					for id, fish in pairs(FishConfig.Fish) do
						if id ~= "Rhythm Fish" and fish.Rarity == chosenRarity then
							table.insert(candidates, id)
						end
					end
					if #candidates == 0 then
						chosenRarity = "Common"
						for id, fish in pairs(FishConfig.Fish) do
							if fish.Rarity == "Common" then
								table.insert(candidates, id)
							end
						end
					end
					
					local fishId = candidates[rng:NextInteger(1, #candidates)]
					if not fishId then fishId = "Basic Fish" end
					local fishCfg = FishConfig.Fish[fishId]
					
					if not data.UnlockedFishes then data.UnlockedFishes = {} end
					local isNew = not data.UnlockedFishes[fishId]
					if isNew then
						data.UnlockedFishes[fishId] = true
					end
					
					local oldFish = data.FishSchool[tostring(slotId)]
					lastRolledFish = {
						Id = fishId,
						Name = fishCfg.Name,
						Level = oldFish and oldFish.Level or 1,
						Exp = oldFish and oldFish.Exp or 0,
						Rarity = chosenRarity,
						IsNew = isNew,
						UniqueId = game:GetService("HttpService"):GenerateGUID(false)
					}
					
					data.FishSchool[tostring(slotId)] = lastRolledFish
					
					if next(targetRarities) == nil or targetRarities[chosenRarity] then
						rollAgain = false
					end
				end
				
				newFish = lastRolledFish
				finalConsumedCount = consumedCount
				
				-- Track Quest Progress
				if finalConsumedCount > 0 then
					PlayerData.IncrementQuestGoal(player, "EggsHatched", finalConsumedCount)
				end
				
				data._FishDirty = true
				data._QuestsDirty = true
			else
				-- Standard non-loop behavior (Rhythm Egg)
				if eggName ~= "Rhythm Egg" then
					if data.Inventory[eggName] and data.Inventory[eggName] > 0 then
						data.Inventory[eggName] = data.Inventory[eggName] - 1
						if data.Inventory[eggName] <= 0 then data.Inventory[eggName] = nil end
						data._InventoryDirty = true
					end
				end
				
				if eggCfg.RequiresFish then
					if not slotOccupied then
						msg = "This item requires an existing fish to use!"
						return nil
					end
				end
				
				if eggName == "Rhythm Egg" then
					for _, fish in pairs(data.FishSchool) do
						if fish.Id == "Rhythm Fish" then
							msg = "You already have a Rhythm Fish! (Unique)"
							return nil
						end
					end
				end
				
				local chosenRarity = "Common"
				local priorities = {"Mythic", "Legendary", "Epic", "Rare", "Common"}
				local totalWeight = 0
				for _, rarity in ipairs(priorities) do
					totalWeight = totalWeight + (eggCfg.Rarities[rarity] or 0)
				end
				
				if totalWeight > 0 then
					local roll = rng:NextNumber(0, totalWeight)
					local currentSum = 0
					chosenRarity = nil
					for _, rarity in ipairs(priorities) do
						local weight = eggCfg.Rarities[rarity] or 0
						if weight <= 0 then continue end
						
						currentSum = currentSum + weight
						if roll <= currentSum then
							chosenRarity = rarity
							break
						end
					end
					if not chosenRarity then chosenRarity = "Common" end
				end
				
				if chosenRarity == "Common" and (eggCfg.Rarities.Common or 0) == 0 then
					for _, r in ipairs(priorities) do
						if (eggCfg.Rarities[r] or 0) > 0 then
							chosenRarity = r
							break
						end
					end
				end
				
				local candidates = {}
				if eggName == "Rhythm Egg" then
					table.insert(candidates, "Rhythm Fish")
					chosenRarity = "Legendary"
				else
					for id, fish in pairs(FishConfig.Fish) do
						if id ~= "Rhythm Fish" and fish.Rarity == chosenRarity then
							table.insert(candidates, id)
						end
					end
				end
				
				if #candidates == 0 then
					chosenRarity = "Common"
					for id, fish in pairs(FishConfig.Fish) do
						if fish.Rarity == "Common" then
							table.insert(candidates, id)
						end
					end
				end
				
				local fishId = candidates[rng:NextInteger(1, #candidates)]
				if not fishId then fishId = "Basic Fish" end
				local fishCfg = FishConfig.Fish[fishId]
				
				if not data.UnlockedFishes then data.UnlockedFishes = {} end
				local isNew = not data.UnlockedFishes[fishId]
				if isNew then
					data.UnlockedFishes[fishId] = true
				end
				
				local oldFish = data.FishSchool[tostring(slotId)]
				newFish = {
					Id = fishId,
					Name = fishCfg.Name,
					Level = oldFish and oldFish.Level or 1,
					Exp = oldFish and oldFish.Exp or 0,
					Rarity = chosenRarity,
					IsNew = isNew,
					UniqueId = game:GetService("HttpService"):GenerateGUID(false)
				}
				data.FishSchool[tostring(slotId)] = newFish
				data._FishDirty = true
				data._QuestsDirty = true
				finalConsumedCount = 1
			end
			
			-- Update Visuals on Server
			local slotsContainer = aquariumModel:FindFirstChild("Slots") or aquariumModel:FindFirstChild("FishSlot") or aquariumModel
			if slotsContainer.Name == "FishSlot" and slotsContainer.Parent ~= aquariumModel then
				slotsContainer = slotsContainer.Parent
			end

			local slotInstance = nil
			local idStr = tostring(slotId)
			for _, child in ipairs(slotsContainer:GetChildren()) do
				local num = child.Name:match("%d+")
				if num == idStr then
					slotInstance = child
					break
				end
			end
			
			if not slotInstance and (idStr == "1" or idStr == "0") then
				slotInstance = slotsContainer:FindFirstChild("FishSlot")
			end

			if slotInstance then
				if newFish then
					AquariumService.UpdateSlotVisuals(slotInstance, newFish)
				else
					local facePart = slotInstance:FindFirstChild("FishFace") or slotInstance:FindFirstChildWhichIsA("BasePart")
					if facePart then
						for _, d in ipairs(facePart:GetChildren()) do
							if d:IsA("Decal") then d.Texture = "" end
						end
						if facePart:IsA("BasePart") then
							facePart.Color = Color3.fromRGB(163, 162, 165)
						end
					end
				end
			end
			
			success = true
			return data
		end)
		
		if success then
			return true, newFish, finalConsumedCount
		else
			return false, msg
		end
	end
	
	local DropConsumable = Remotes:FindFirstChild("DropConsumable")
	if not DropConsumable then
		DropConsumable = Instance.new("RemoteFunction")
		DropConsumable.Name = "DropConsumable"
		DropConsumable.Parent = Remotes
	end

	DropConsumable.OnServerInvoke = function(player, itemName)
		if not SecurityService.ValidateRemoteCall(player, "DropConsumable") then return false, "Security Check Failed" end
		local EquipmentConfig = require(game:GetService("ReplicatedStorage").Shared.EquipmentConfig)
		local config = EquipmentConfig[itemName]
		if not config or not config.IsConsumable then
			return false, "Invalid consumable"
		end

		local PlayerData = require(script.Parent.PlayerData)
		local success, msg = false, "Unknown Error"

		PlayerData.update(player, function(data)
			-- Check Inventory
			if not data.Inventory or not data.Inventory[itemName] or data.Inventory[itemName] <= 0 then
				msg = "Item not found in inventory!"
				return nil
			end
			
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if not rootPart then
				msg = "Character not found"
				return nil
			end

			local function GetClosestReef(pos)
				local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
				for rName, _ in pairs(ResourceConfig.Fields) do
					local f = workspace:FindFirstChild("Reefs") and workspace.Reefs:FindFirstChild(rName)
					if f then
						local hitbox = f:FindFirstChild("Hitbox")
						if hitbox then
							local dx = pos.X - hitbox.Position.X
							local dz = pos.Z - hitbox.Position.Z
							local distXZ = math.sqrt(dx*dx + dz*dz)
							local radius = math.max(hitbox.Size.X, hitbox.Size.Z) / 2
							if distXZ <= radius and math.abs(pos.Y - hitbox.Position.Y) <= (hitbox.Size.Y / 2 + 100) then
								return rName
							end
						end
					end
				end
				return nil
			end

			local reefName = nil
			if itemName == "Sea Mine" or itemName == "Fertilizer" then
				reefName = GetClosestReef(rootPart.Position)
				if not reefName then
					msg = "You must be standing near a Reef to use this!"
					local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
					if NotificationEvent then
						NotificationEvent:FireClient(player, msg, Color3.fromRGB(255, 100, 100))
					end
					return nil
				end
			end

			if itemName == "Convertrix" then
				if not data.Plankton then
					msg = "You have no algae to convert!"
					return nil
				end
				
				local totalAlgae = 0
				for _, amt in pairs(data.Plankton) do totalAlgae += amt end
				if totalAlgae <= 0 then
					msg = "You have no algae to convert!"
					return nil
				end
				
				data.Inventory[itemName] = data.Inventory[itemName] - 1
				if data.Inventory[itemName] <= 0 then data.Inventory[itemName] = nil end
				data._InventoryDirty = true
				
				-- Convert all algae
				local convertMult = data.Stats and data.Stats.ConvertMultiplier or 1
				local critChance = (data.Stats and data.Stats.CriticalChance or 0.01) + (data.Stats and data.Stats.CritChanceBonus or 0)
				local isCrit = false
				if math.random() < critChance then isCrit = true end
				
				local yieldMult = 1.0
				if isCrit then
					local baseCritPower = data.Stats and data.Stats.CriticalPower or 3.0
					local critPowerBonus = 1 + (data.Stats and data.Stats.CritPowerBonus or 0)
					yieldMult = baseCritPower * critPowerBonus
				end
				
				local gained = 0
				local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
				
				local EquipmentConfig = require(game:GetService("ReplicatedStorage").Shared.EquipmentConfig)
				local cfg = EquipmentConfig[itemName]
				local baseYieldMult = cfg and cfg.BaseYieldMultiplier or 1.0
				
				for typeName, amt in pairs(data.Plankton) do
					if amt > 0 then
						local resType = ResourceConfig.Types[typeName]
						local resBaseValue = resType and resType.BaseValue or 1
						gained += (amt * resBaseValue * (data.Stats and data.Stats.BiomassPerAlgae or 1.0) * yieldMult * baseYieldMult)
					end
				end
				
				data.Plankton = {} -- Clear all algae
				data.Biomass = (data.Biomass or 0) + gained
				data.LifetimeBiomass = (data.LifetimeBiomass or 0) + gained
				
				local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
				if NotificationEvent then
					local critMsg = isCrit and " (CRITICAL!)" or ""
					NotificationEvent:FireClient(player, "Used Convertrix! Converted all algae into " .. tostring(math.floor(gained)) .. " Biomass!" .. critMsg, Color3.fromRGB(0, 255, 150))
				end
				
				success = true
			elseif itemName == "Sea Mine" then
				-- Consume Item
				data.Inventory[itemName] = data.Inventory[itemName] - 1
				if data.Inventory[itemName] <= 0 then data.Inventory[itemName] = nil end
				data._InventoryDirty = true

				-- Spawn Mine (Use rootPart pos but a bit higher)
				local SeaMineService = require(script.Parent.SeaMineService)
				local spawnPos = rootPart.Position + Vector3.new(0, 15, 0)
				SeaMineService.SpawnMineUser(player, spawnPos, reefName)
				
				success = true
			elseif itemName == "Fertilizer" then
				-- Consume Item
				data.Inventory[itemName] = data.Inventory[itemName] - 1
				if data.Inventory[itemName] <= 0 then data.Inventory[itemName] = nil end
				data._InventoryDirty = true
				
				local EquipmentConfig = require(game:GetService("ReplicatedStorage").Shared.EquipmentConfig)
				local cfg = EquipmentConfig[itemName]
				local duration = cfg and cfg.Duration or 600
				local multiplier = cfg and cfg.Multiplier or 2.0
				
				if not data.ActiveReefBoosts then data.ActiveReefBoosts = {} end
				data.ActiveReefBoosts[reefName] = {
					ExpiresAt = os.time() + duration,
					Multiplier = multiplier
				}
				
				local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
				if NotificationEvent then
					local boostPercent = (multiplier - 1) * 100
					local mins = math.floor(duration / 60)
					NotificationEvent:FireClient(player, "Used Fertilizer on " .. reefName .. "! +" .. boostPercent .. "% Algae for " .. mins .. " Minutes!", Color3.fromRGB(50, 255, 50))
				end
				
				success = true
			elseif itemName == "Orange Gem" or itemName == "Green Gem" or itemName == "Pink Gem" then
				data.Inventory[itemName] = data.Inventory[itemName] - 1
				if data.Inventory[itemName] <= 0 then data.Inventory[itemName] = nil end
				data._InventoryDirty = true
				
				-- Store the buff to apply outside the transaction
				data._PendingGemBuff = itemName .. "Boost"
				
				-- Notification happens here so it's guaranteed
				local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
				if NotificationEvent then
					NotificationEvent:FireClient(player, "Used " .. itemName .. "!", Color3.fromRGB(200, 200, 255))
				end
				success = true
			elseif itemName == "Remote Warp" then
				local ownedAquarium = PlayerAquarium[player]
				if not ownedAquarium then
					msg = "You don't own an aquarium!"
					return nil
				end
				
				local respawnPoint = ownedAquarium:FindFirstChild("OwnerSpawn")
				if not respawnPoint then
					msg = "Aquarium spawn point not found!"
					return nil
				end
				
				data.Inventory[itemName] = data.Inventory[itemName] - 1
				if data.Inventory[itemName] <= 0 then data.Inventory[itemName] = nil end
				data._InventoryDirty = true
				
				data._PendingWarpPos = respawnPoint.Position + Vector3.new(0, 5, 0)
				
				success = true
			elseif itemName == "Skull" then
				data.Inventory[itemName] = data.Inventory[itemName] - 1
				if data.Inventory[itemName] <= 0 then data.Inventory[itemName] = nil end
				data._InventoryDirty = true
				
				data._PendingSkullSpawns = 15
				
				success = true
			end

			return data
		end)
		
		-- Apply the buff after the transaction is fully completed
		if success then
			local afterData = PlayerData.get(player)
			if afterData and afterData._PendingGemBuff then
				local buffName = afterData._PendingGemBuff
				
				local originalItemName = buffName:gsub("Boost", "")
				local EquipmentConfig = require(game:GetService("ReplicatedStorage").Shared.EquipmentConfig)
				local cfg = EquipmentConfig[originalItemName]
				local customDuration = cfg and cfg.Duration
				local customMultiplier = cfg and (cfg.Multiplier - 1.0)
				
				local AbilityService = require(script.Parent.AbilityService)
				AbilityService.ApplyBuff(player, buffName:gsub(" ", ""), customDuration, customMultiplier)
				
				-- Clear pending buff
				PlayerData.update(player, function(d)
					d._PendingGemBuff = nil
					return d
				end, true)
			end
			
			if afterData and afterData._PendingWarpPos then
				local warpPos = afterData._PendingWarpPos
				local character = player.Character
				if character and character:FindFirstChild("HumanoidRootPart") then
					character.HumanoidRootPart.CFrame = CFrame.new(warpPos)
					local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
					if NotificationEvent then
						NotificationEvent:FireClient(player, "Warped to your Aquarium!", Color3.fromRGB(150, 150, 255))
					end
				end
				
				-- Clear pending warp
				PlayerData.update(player, function(d)
					d._PendingWarpPos = nil
					return d
				end, true)
			end
			
			if afterData and afterData._PendingSkullSpawns then
				local count = afterData._PendingSkullSpawns
				
				PlayerData.update(player, function(d)
					d._PendingSkullSpawns = nil
					return d
				end, true)
				
				local HttpService = game:GetService("HttpService")
				if not _G.TemporaryFish then _G.TemporaryFish = {} end
				if not _G.TemporaryFish[player.UserId] then _G.TemporaryFish[player.UserId] = {} end
				
				local possibleFish = {"Basic Fish", "Diver Fish", "Zombie Fish", "Puppeteer Fish"}
				local packet = {OwnerUserId = player.UserId, __IsTemporary = true}
				local numSpawned = 0
				
				for i = 1, count do
					local targetId = possibleFish[math.random(1, #possibleFish)]
					local cloneIndex = 1000 + math.random(1, 9999)
					while (_G.TemporaryFish[player.UserId][tostring(cloneIndex)] or (afterData.FishSchool and afterData.FishSchool[tostring(cloneIndex)])) do
						cloneIndex += 1
					end
					
					local cloneData = {
						Id = targetId,
						UniqueId = HttpService:GenerateGUID(false),
						IsTemporary = true,
						ExpiresAt = os.time() + 600,
						VisualOverride = {
							Color = Color3.fromRGB(0, 255, 255),
							Transparency = 0.5,
							Material = Enum.Material.Neon
						}
					}
					
					_G.TemporaryFish[player.UserId][tostring(cloneIndex)] = cloneData
					packet[tostring(cloneIndex)] = cloneData
					numSpawned += 1
				end
				
				local FishReplicationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("FishReplicationEvent")
				if FishReplicationEvent and numSpawned > 0 then
					FishReplicationEvent:FireAllClients(packet)
				end
				
				local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
				if NotificationEvent then
					NotificationEvent:FireClient(player, "Summoned 15 Ghost Fish for 10 Minutes!", Color3.fromRGB(0, 255, 255))
				end
			end
		end

		return success, msg
	end

	
	function AquariumService.ReleaseAquarium(player)
		local owned = PlayerAquarium[player]
		
		-- Fallback scanner: If player isn't mapped in PlayerAquarium, scan workspace for orphaned claims
		if not owned and player then
			local folder = workspace:FindFirstChild("Aquariums")
			if folder then
				for _, plot in ipairs(folder:GetChildren()) do
					local isMatch = false
					if plot:GetAttribute("OwnerUserId") == player.UserId then
						isMatch = true
					else
						-- Also match by legacy text label to clear any desynced visual signs
						local ownerPart = plot:FindFirstChild("Ownership")
						local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
						local lbl = gui and gui:FindFirstChild("TextLabel")
						local expected = player.Name .. "'s Aquarium"
						if lbl and lbl.Text == expected then
							isMatch = true
						end
					end
					
					if isMatch then
						owned = plot
						break
					end
				end
			end
		end
		
		if owned then
			AquariumState[owned] = nil
			PlayerAquarium[player] = nil
			if player then
				for p, aq in pairs(PlayerAquarium) do
					if p.UserId == player.UserId then
						PlayerAquarium[p] = nil
					end
				end
			end
			owned:SetAttribute("OwnerUserId", 0)
			
			-- Reset Visuals (Clear Fish Slots)
			local slotsContainer = owned:FindFirstChild("Slots") or owned:FindFirstChild("FishSlot") or owned
			if slotsContainer.Name == "FishSlot" and slotsContainer.Parent ~= owned then
				slotsContainer = slotsContainer.Parent
			end
			
			for _, child in ipairs(slotsContainer:GetChildren()) do
				local facePart = child:FindFirstChild("FishFace") or child:FindFirstChildWhichIsA("BasePart")
				if facePart then
					-- destroy decal textures
					for _, d in ipairs(facePart:GetChildren()) do
						if d:IsA("Decal") then
							d.Texture = ""
						end
					end
					
					-- Reset color
					if facePart:IsA("BasePart") then
						facePart.Color = Color3.fromRGB(163, 162, 165) -- Default Grey
					end
				end
			end
			
			-- Reset Text
			local ownerPart = owned:FindFirstChild("Ownership")
			if ownerPart then
				local gui = ownerPart:FindFirstChild("SurfaceGui")
				if gui and gui:FindFirstChild("TextLabel") then
					gui.TextLabel.Text = "Unclaimed"
				end
			end
			
			-- Cleanup Respawn Point
			local respawnPoint = owned:FindFirstChild("OwnerSpawn")
			if respawnPoint then
				respawnPoint:Destroy()
			end
		end
	end

	Players.PlayerRemoving:Connect(AquariumService.ReleaseAquarium)
end

return AquariumService


