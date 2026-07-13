print("Starting Fish Hatchery Simulator Server...")

-- Load Services
local PlayerData = require(script.PlayerData)
local HarvestService = require(script.HarvestService)
local FieldService = require(script.FieldService)
local ConversionService = require(script.ConversionService)
local FishService = require(script.FishService)
local AquariumService = require(script.AquariumService)
local ShopService = require(script.ShopService)
local AbilityService = require(script.AbilityService)
local LeaderboardService = require(script.LeaderboardService)
local WhitelistService = require(script.WhitelistService)
local TokenService = require(script.TokenService)
local GamepassService = require(script.GamepassService)
local SecurityService = require(script.SecurityService)
local SeaMineService = require(script.SeaMineService)
local MobService = require(script.MobService)
local WishingShrineService = require(script.WishingShrineService)
local PhysicsService = game:GetService("PhysicsService")

-- Create collision groups to disable unwanted physics interactions
pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:RegisterCollisionGroup("Mobs")
end)
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Players", "Mobs", false)

-- Disable auto loading characters so they only spawn when the loading screen finishes
game:GetService("Players").CharacterAutoLoads = false

local function SetCollisionGroup(character)
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("BasePart") then
			child.CollisionGroup = "Players"
		end
	end
end

FieldService.Start()
ConversionService.Start()
FishService.Start()
AquariumService.Start()
AbilityService.Start()
TokenService.Start()
GamepassService.Start()
SecurityService.Start()
SeaMineService.Start()
MobService.Start()
WishingShrineService.Start()
-- ShopService doesn't have a .Start() yet but it connects OnServerEvent on requirement


-- Setup Conversion RemoteEvent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getFieldFolder(fieldName)
	if not fieldName then return nil end
	
	local folder = workspace:FindFirstChild(fieldName)
	if folder then return folder end
	
	local reefsFolder = workspace:FindFirstChild("Reefs")
	if reefsFolder then
		folder = reefsFolder:FindFirstChild(fieldName)
		if folder then return folder end
	end
	
	local cleanName = string.lower(fieldName):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
	
	for _, child in ipairs(workspace:GetChildren()) do
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


local VFXReplication = Remotes:FindFirstChild("VFXReplication")
if not VFXReplication then
	VFXReplication = Instance.new("RemoteEvent")
	VFXReplication.Name = "VFXReplication"
	VFXReplication.Parent = Remotes
end

VFXReplication.OnServerEvent:Connect(function(player, vfxName, targetIndex, customData, extraData, extraData2)
	-- print("Server Relay:", vfxName, player.Name) -- Useful debug
	-- Relay to all OTHER clients (or all, client filters self)
	-- Pass 'player' as the source so clients know who did it
	VFXReplication:FireAllClients(vfxName, player, targetIndex, customData, extraData, extraData2)
end)

local ConversionControl = Remotes:FindFirstChild("ConversionControl")
if not ConversionControl then
	ConversionControl = Instance.new("RemoteEvent")
	ConversionControl.Name = "ConversionControl"
	ConversionControl.Parent = Remotes
end

ConversionControl.OnServerEvent:Connect(function(player, action, aquarium)
	if action == "start" then
		-- Validate player owns this aquarium
		local ownerPart = aquarium and aquarium:FindFirstChild("Ownership")
		local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
		local lbl = gui and gui:FindFirstChild("TextLabel")
		local expected = player.Name .. "'s Aquarium"
		
		if lbl and lbl.Text == expected then
			-- Valid - Start conversion
			ConversionService.Convert(player)
		else
			warn("Player " .. player.Name .. " tried to convert at aquarium they don't own")
		end
	elseif action == "stop" then
		-- Stop conversion
		ConversionService.Stop(player)
	end
end)

local AbilityActivation = Remotes:FindFirstChild("AbilityActivation")
if not AbilityActivation then
	AbilityActivation = Instance.new("RemoteEvent")
	AbilityActivation.Name = "AbilityActivation"
	AbilityActivation.Parent = Remotes
end

local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
if not NotificationEvent then
	NotificationEvent = Instance.new("RemoteEvent")
	NotificationEvent.Name = "NotificationEvent"
	NotificationEvent.Parent = Remotes
end

local SpawnPlayerRequest = Remotes:FindFirstChild("SpawnPlayerRequest")
if not SpawnPlayerRequest then
	SpawnPlayerRequest = Instance.new("RemoteEvent")
	SpawnPlayerRequest.Name = "SpawnPlayerRequest"
	SpawnPlayerRequest.Parent = Remotes
end

SpawnPlayerRequest.OnServerEvent:Connect(function(player)
	player:LoadCharacter()
end)

AbilityActivation.OnServerEvent:Connect(function(player, abilityName)
	if abilityName == "RainmakerUltimate" then
		
		-- Check if Bullet Blessing is already active
		local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
		
		-- Prevent ability if Bullet Blessing is active
		if AbilityService.HasBulletBlessing(player) then
			warn("[Rainmaker] " .. player.Name .. " tried to use ability while Bullet Blessing is active!")
			return
		end
		
		-- Apply Bullet Blessing immediately when ability is called
		AbilityService.ApplyBulletBlessing(player, FishConfig.Buffs.BulletBlessing)
		print("[Rainmaker] " .. player.Name .. " activated Bullet Blessing!")
		
		-- 1. Broadcast Visuals (Visuals have built-in delay)
		VFXReplication:FireAllClients("RainmakerAbility", player)
		
		-- 2. Server Logic: Harvest Algae
		task.spawn(function()
			task.wait(2)
			
			local char = player.Character
			if not char or not char.Parent then return end
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root then return end
			
			local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
			
			-- Pre-build filter
			local filterList = {}
			for fieldName, _ in pairs(ResourceConfig.Fields) do
				local f = getFieldFolder(fieldName)
				if f then table.insert(filterList, f) end
			end
			
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Include
			rayParams.FilterDescendantsInstances = filterList
			
			-- Beam Params
			local duration = 2.325
			local tickRate = 0.2
			local length = 70
			local width = 15
			local height = 10
			
			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Include
			overlapParams.FilterDescendantsInstances = filterList

			local startTime = os.clock()
			while os.clock() - startTime < duration do
				if not player.Parent or not char.Parent or not root.Parent then break end 
				
				local algaeTargets = {}
				
				-- Define Beam Box (In front of player)
				-- Center is moved forward by half the length
				local boxCFrame = root.CFrame * CFrame.new(0, 0, -length/2)
				local boxSize = Vector3.new(width, height, length)
				
				local parts = workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)
				
				for _, p in ipairs(parts) do
					if p:IsA("BasePart") then
						-- Validate
						local cap = p:FindFirstChild("Capacity")
						if cap and cap.Value > 0 then
							table.insert(algaeTargets, p)
						end
					end
				end
				
				if #algaeTargets > 0 then
					HarvestService.HarvestMultipleBatched(player, algaeTargets, 10, true)
				end
				
				-- Damage Mobs
				local pd = PlayerData.get(player)
				local playerAttack = (pd and pd.Stats and pd.Stats.Attack) or 1
				local critChance = (pd and pd.Stats and pd.Stats.CriticalChance) or 0.01
				local critPower = (pd and pd.Stats and pd.Stats.CriticalPower) or 3.0
				local megaCritChance = (pd and pd.Stats and pd.Stats.MegaCritChance) or 0
				local megaCritPower = (pd and pd.Stats and pd.Stats.MegaCritPower) or 10.0
				
				local isCrit = false
				local ToolConfig = require(ReplicatedStorage.Shared.ToolConfig)
				local finalDamage = (ToolConfig["Rainmaker"].AbilityDamage or 50) * playerAttack
				
				if math.random() <= megaCritChance then
					isCrit = true
					finalDamage = finalDamage * megaCritPower
				elseif math.random() <= critChance then
					isCrit = true
					finalDamage = finalDamage * critPower
				end
				
				local avgLevel = MobService.GetAverageFishLevel(player)
				
				if pd and pd.Settings and pd.Settings.HitboxVisualizer then
					VFXReplication:FireClient(player, "HitboxVisualizer", nil, nil, {Shape = "Box", Size = boxSize, CFrame = boxCFrame, Duration = 0.5})
				end
				
				for _, mobData in ipairs(MobService.GetMobs()) do
					if mobData.Mob and mobData.Mob.PrimaryPart then
						local localPos = boxCFrame:PointToObjectSpace(mobData.Mob.PrimaryPart.Position)
						local halfSize = boxSize / 2
						if math.abs(localPos.X) <= halfSize.X and math.abs(localPos.Y) <= halfSize.Y and math.abs(localPos.Z) <= halfSize.Z then
							local mobLevel = mobData.Mob:FindFirstChild("Level") and mobData.Mob.Level.Value or 1
							local levelDiff = mobLevel - avgLevel
							local missChance = 0
							if levelDiff > 0 then
								missChance = 1 - math.pow(0.5, levelDiff)
							end
							local isMiss = math.random() < missChance
							
							MobService.DamageMob(mobData.Mob, finalDamage, isCrit, isMiss)
						end
					end
				end

				task.wait(tickRate)
			end
		end)
	end
end)



-- Guardian Activation (Special for Crazyyism)
local GuardianRequest = Remotes:FindFirstChild("GuardianRequest")
if not GuardianRequest then
	GuardianRequest = Instance.new("RemoteEvent")
	GuardianRequest.Name = "GuardianRequest"
	GuardianRequest.Parent = Remotes
end

GuardianRequest.OnServerEvent:Connect(function(player, movetype)
	if player.Name ~= "Crazyyism" then return end
	
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	-- Replicate VFX to all clients
	VFXReplication:FireAllClients("GuardianVFX", player, nil, hrp, movetype)
	
	-- Gameplay Logic
	if movetype == "main" then
		local AbilityService = require(script.AbilityService)
		AbilityService.TriggerGuardianCall(player, hrp, 0) -- 0 damage for the admin manual call
	end
end)

print("Fish Hatchery Simulator Server Loaded.")

-- Admin Commands
local AllowedUsers = {["Crazyyism"] = true, ["Player1"] = true, ["Player2"] = true, ["EllabellTheLolGirl"] = true, ["Aaaronip"] = true}
local BadgeService = game:GetService("BadgeService")
local WELCOME_BADGE_ID = 2305187807978897

local TextChatService = game:GetService("TextChatService")
pcall(function()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		TextChatService.ShouldDeliverCallback = function(textChatMessage, targetTextSource)
			if textChatMessage.Text and textChatMessage.Text:sub(1, 1) == "/" then
				return false
			end
			return true
		end
	end
end)

game:GetService("Players").PlayerAdded:Connect(function(player)
	-- Tutorial Safety Check: Reset orphaned aquarium claims if player hasn't completed the tutorial
	task.spawn(function()
		while not PlayerData.isLoaded(player) do
			task.wait(0.1)
		end
		local data = PlayerData.get(player)
		if data and data.TutorialCompleted == false then
			print("[Tutorial Safety] Player " .. player.Name .. " has not completed the tutorial. Releasing any owned aquariums to ensure a clean start.")
			AquariumService.ReleaseAquarium(player)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		SetCollisionGroup(character)
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "Players"
			end
		end)
		
		-- Force strict standardized global R15 proportions for competitive visuals
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			for _, scaleName in ipairs({"BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale"}) do
				local sv = humanoid:FindFirstChild(scaleName)
				if sv and sv:IsA("NumberValue") then
					sv.Value = 1.0
				end
			end
			
			local typeScale = humanoid:FindFirstChild("BodyTypeScale")
			if typeScale then typeScale.Value = 0 end -- 0 = Classic Blocky / Normal R15
			
			local propScale = humanoid:FindFirstChild("BodyProportionScale")
			if propScale then propScale.Value = 0 end
			
			-- Fix: Auto-respawn logic since CharacterAutoLoads = false
			humanoid.Died:Connect(function()
				task.delay(game:GetService("Players").RespawnTime, function()
					if player and player.Parent then
						player:LoadCharacter()
					end
				end)
			end)
		end
	end)

	-- Award Welcome Badge
	task.spawn(function()
		if WELCOME_BADGE_ID > 0 then
			pcall(function()
				if not BadgeService:UserHasBadgeAsync(player.UserId, WELCOME_BADGE_ID) then
					BadgeService:AwardBadgeAsync(player.UserId, WELCOME_BADGE_ID)
				end
			end)
		end
	end)

	player.Chatted:Connect(function(msg)
		print("Chat from " .. player.Name .. ": " .. msg)
		if msg:lower() == "/resetdata" then
			local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
			if NotificationEvent then
				NotificationEvent:FireClient(player, "WARNING: This will reset ALL your progress. This cannot be undone! Type '/resetdata confirm' to proceed.", Color3.fromRGB(255, 100, 100))
			end
		elseif msg:lower() == "/resetdata confirm" then
			-- 1. Release aquarium
			AquariumService.ReleaseAquarium(player)
			-- 2. Reset Player Data
			PlayerData.Reset(player)
			-- 3. Kick player to complete reset
			player:Kick("Your progress has been successfully reset! Please rejoin to start fresh.")
		elseif msg:lower():sub(1, 10) == "/copydata " and AllowedUsers[player.Name] then
			local arg = msg:sub(11)
			arg = arg:match("^%s*(.-)%s*$")
			
			local targetUserId = tonumber(arg)
			local targetName = arg
			
			task.spawn(function()
				local DataStoreService = game:GetService("DataStoreService")
				local DataStore = DataStoreService:GetDataStore("Fish_Hatchery")
				
				if not targetUserId then
					-- Resolve username to UserId
					local success, resolvedId = pcall(function()
						return game:GetService("Players"):GetUserIdFromNameAsync(arg)
					end)
					if success and resolvedId then
						targetUserId = resolvedId
					else
						local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
						if NotificationEvent then
							NotificationEvent:FireClient(player, "Error: Could not resolve username '" .. arg .. "'", Color3.fromRGB(255, 50, 50))
						end
						return
					end
				else
					-- Resolve UserId to username
					local success, resolvedName = pcall(function()
						return game:GetService("Players"):GetNameFromUserIdAsync(targetUserId)
					end)
					if success and resolvedName then
						targetName = resolvedName
					end
				end
				
				-- Read target data from DataStore
				local success, result = pcall(function()
					return DataStore:GetAsync("User_" .. targetUserId)
				end)
				
				if success and result then
					-- 1. Release current aquarium
					AquariumService.ReleaseAquarium(player)
					
					-- 2. Update data
					local function deepCopy(orig)
						local copy
						if type(orig) == "table" then
							copy = {}
							for orig_key, orig_value in next, orig, nil do
								copy[deepCopy(orig_key)] = deepCopy(orig_value)
							end
						else
							copy = orig
						end
						return copy
					end
					
					local cleanTargetData = deepCopy(result)
					cleanTargetData._SessionLock = nil
					cleanTargetData._LastSaved = nil
					
					PlayerData.update(player, function(data)
						for k, v in pairs(cleanTargetData) do
							if k ~= "_SessionLock" and k ~= "_LastSaved" then
								data[k] = v
							end
						end
						return data
					end)
					
					-- 3. Kick player to force reload
					player:Kick("Successfully copied progress from " .. targetName .. "! Rejoin to play with this progress.")
				else
					local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
					if NotificationEvent then
						NotificationEvent:FireClient(player, "Error: Could not load data for " .. targetName .. " (DataStore empty or failed)", Color3.fromRGB(255, 50, 50))
					end
				end
			end)
		elseif msg:lower():sub(1, 16) == "/resetdataother " and AllowedUsers[player.Name] then
			local arg = msg:sub(17)
			arg = arg:match("^%s*(.-)%s*$")
			
			local targetUserId = tonumber(arg)
			local targetName = arg
			
			task.spawn(function()
				local DataStoreService = game:GetService("DataStoreService")
				local DataStore = DataStoreService:GetDataStore("Fish_Hatchery")
				
				if not targetUserId then
					-- Resolve username to UserId
					local success, resolvedId = pcall(function()
						return game:GetService("Players"):GetUserIdFromNameAsync(arg)
					end)
					if success and resolvedId then
						targetUserId = resolvedId
					else
						local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
						if NotificationEvent then
							NotificationEvent:FireClient(player, "Error: Could not resolve username '" .. arg .. "'", Color3.fromRGB(255, 50, 50))
						end
						return
					end
				else
					-- Resolve UserId to username
					local success, resolvedName = pcall(function()
						return game:GetService("Players"):GetNameFromUserIdAsync(targetUserId)
					end)
					if success and resolvedName then
						targetName = resolvedName
					end
				end
				
				local targetPlayer = game:GetService("Players"):GetPlayerByUserId(targetUserId)
				if targetPlayer then
					targetPlayer:Kick("Your data has been wiped by an administrator.")
					task.wait(2) -- Wait for session cleanup
				end
				
				local success, result = pcall(function()
					DataStore:RemoveAsync("User_" .. targetUserId)
				end)
				
				if success then
					local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
					if NotificationEvent then
						NotificationEvent:FireClient(player, "Successfully wiped data for " .. targetName .. ".", Color3.fromRGB(50, 255, 50))
					end
				else
					local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
					if NotificationEvent then
						NotificationEvent:FireClient(player, "Error: Failed to wipe data for " .. targetName .. ".", Color3.fromRGB(255, 50, 50))
					end
				end
			end)
		elseif msg:lower() == "/testcapacity" and AllowedUsers[player.Name] then
			local currentState = player:GetAttribute("InfiniteCapacity") or false
			player:SetAttribute("InfiniteCapacity", not currentState)
			
			if not currentState then
				AbilityService.ApplyBuff(player, "InfiniteCapacity")
				print(player.Name .. " enabled infinite capacity.")
			else
				AbilityService.RemoveBuff(player, "InfiniteCapacity")
				print(player.Name .. " disabled infinite capacity.")
			end
		elseif msg:lower() == "/default" and AllowedUsers[player.Name] then
			player:SetAttribute("InfiniteCapacity", false)
			player:SetAttribute("InstantFire", false)
			AbilityService.RemoveBuff(player, "InfiniteCapacity")
			AbilityService.RemoveBuff(player, "InstantFire")
			
			PlayerData.update(player, function(data)
				if not data.Stats then data.Stats = {} end
				-- Recalculate properly from backpack/artifacts
				PlayerData.RecalculateStats(data)
				print(player.Name .. " reset default stats.")
				return data
			end)
		elseif msg:lower() == "/cooldowns" and AllowedUsers[player.Name] then
			local currentState = player:GetAttribute("NoCooldowns") or false
			player:SetAttribute("NoCooldowns", not currentState)
			print(player.Name .. " toggled ability cooldowns: " .. tostring(not currentState))
		elseif msg:lower() == "/instantfire" and AllowedUsers[player.Name] then
			local currentState = player:GetAttribute("InstantFire") or false
			player:SetAttribute("InstantFire", not currentState)
			
			if not currentState then
				AbilityService.ApplyBuff(player, "InstantFire")
				print(player.Name .. " enabled instant fire.")
			else
				AbilityService.RemoveBuff(player, "InstantFire")
				print(player.Name .. " disabled instant fire.")
			end
		elseif msg:sub(1, 13):lower() == "/setaquarium " and AllowedUsers[player.Name] then
			local arg = msg:sub(14)
			-- Trim whitespace check?
			-- Validate fish exists
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local FishConfig
			if ReplicatedStorage:FindFirstChild("Shared") then
				FishConfig = require(ReplicatedStorage.Shared.FishConfig)
			else
				FishConfig = require(ReplicatedStorage:FindFirstChild("FishConfig") or ReplicatedStorage.Shared.FishConfig)
			end
			local targetFish = nil
			-- Case insensitive search
			for name, _ in pairs(FishConfig.Fish) do
				if name:lower() == arg:lower() then
					targetFish = name
					break
				end
			end
			
			if targetFish then
				PlayerData.update(player, function(data)
					if data.FishInventory then
						local HttpService = game:GetService("HttpService")
						for _, fish in ipairs(data.FishInventory) do
							fish.Id = targetFish
							fish.UniqueId = HttpService:GenerateGUID(false)
						end
						print(player.Name .. " set aquarium to " .. targetFish)
					end
					return data
				end)
			else
				print("Invalid fish name: " .. arg)
			end
		elseif msg:lower() == "/instantconvert" then
			-- Convert all algae in backpack to biomass
			PlayerData.update(player, function(data)
				if not data.Plankton then return data end
				
				local totalAlgae = 0
				for algaeType, amount in pairs(data.Plankton) do
					totalAlgae = totalAlgae + amount
				end
				
				if totalAlgae > 0 then
					-- Clear all algae
					data.Plankton = {
						GreenAlgae = 0,
						PinkAlgae = 0,
						OrangeAlgae = 0
					}
					
					-- Add to biomass
					data.Biomass = (data.Biomass or 0) + totalAlgae
					
					print(player.Name .. " converted " .. totalAlgae .. " algae to biomass!")
				else
					print(player.Name .. " has no algae to convert")
				end
				
				return data
			end)
		elseif msg:lower():sub(1, 10) == "/tothemoon" and AllowedUsers[player.Name] then
			local targetPlayer = player
			local args = msg:split(" ")
			if #args > 1 then
				local targetName = args[2]
				-- Find player by Name or DisplayName
				local found = false
				for _, p in pairs(game:GetService("Players"):GetPlayers()) do
					if p.Name:lower() == targetName:lower() or p.DisplayName:lower() == targetName:lower() then
						targetPlayer = p
						found = true
						break
					end
				end
				
				-- Partial match support
				if not found then
					for _, p in pairs(game:GetService("Players"):GetPlayers()) do
						if p.Name:lower():find(targetName:lower()) then
							targetPlayer = p
							break
						end
					end
				end
			end

			-- Grant 200 Stacks of Rhythm Fever
			for i = 1, 200 do
				AbilityService.ApplyBuff(targetPlayer, "RhythmFever")
			end
			
			local moonStacks = AbilityService.GetBuffStacks(targetPlayer, "ToTheMoon")
			if moonStacks == 0 then
				AbilityService.TriggerToTheMoon(targetPlayer)
			end
			
			print(player.Name .. " granted 200 Rhythm Fever stacks and activated To The Moon for " .. targetPlayer.Name)
		elseif msg:lower():sub(1, 11) == "/reefboost " and AllowedUsers[player.Name] then
			local argStr = msg:sub(12)
			local args = argStr:split(" ")
			if #args >= 2 then
				local mult = tonumber(args[1])
				if mult then
					local reefName = table.concat(args, " ", 2)
					
					PlayerData.update(player, function(data)
						if not data.ActiveReefBoosts then data.ActiveReefBoosts = {} end
						data.ActiveReefBoosts[reefName] = {
							Multiplier = mult,
							ExpiresAt = os.time() + 600 -- 10 minutes
						}
						return data
					end)
					
					print(player.Name .. " granted " .. mult .. "x Reef Boost for " .. reefName .. " for 10 minutes!")
				end
			end
		elseif msg:lower():sub(1, 9) == "/biomass " and AllowedUsers[player.Name] then
			local argStr = msg:sub(10)
			local amount = tonumber(argStr)
			if amount then
				PlayerData.update(player, function(data)
					data.Biomass = (data.Biomass or 0) + amount
					return data
				end)
				print(player.Name .. " granted themselves " .. amount .. " Biomass!")
			end
		elseif msg:lower():sub(1, 6) == "/give " and AllowedUsers[player.Name] then
			local argStr = msg:sub(7)
			-- Split by spaces, but handle multi-word items and optional player target
			-- Format: /give [Amount] [Item Name] [TargetPlayer - optional]
			
			-- 1. Parse space-separated parts
			local parts = argStr:split(" ")
			
			-- We need at least an amount and part of an item name
			if #parts >= 2 then
				local amountStr = table.remove(parts, 1) -- First token is amount
				local amount = tonumber(amountStr)
				
				if amount and amount > 0 then
					-- Check if the last token matches a player name
					local targetName = parts[#parts]
					local targetPlayer = player -- Default to self
					local isOtherPlayer = false
					
					-- Try to find target player in server
					for _, p in pairs(game:GetService("Players"):GetPlayers()) do
						if p.Name:lower() == targetName:lower() or (p.DisplayName and p.DisplayName:lower() == targetName:lower()) then
							targetPlayer = p
							isOtherPlayer = true
							break
						end
					end
					
					-- If the last part was a player name, pop it off the list of strings making up the item name
					if isOtherPlayer then
						table.remove(parts, #parts)
					end
					
					-- The remaining parts make up the item name
					if #parts > 0 then
						local itemNameQuery = table.concat(parts, " "):lower()
						
						-- Figure out if the item exists and get its proper format
						local properItemName = nil
						
						-- Check currencies first
						if itemNameQuery == "biomass" then properItemName = "Biomass"
						elseif itemNameQuery == "pearl" or itemNameQuery == "pearls" then properItemName = "Pearls"
						elseif itemNameQuery == "greenalgae" or itemNameQuery == "green algae" then properItemName = "GreenAlgae"
						elseif itemNameQuery == "pinkalgae" or itemNameQuery == "pink algae" then properItemName = "PinkAlgae"
						elseif itemNameQuery == "orangealgae" or itemNameQuery == "orange algae" then properItemName = "OrangeAlgae"
						elseif itemNameQuery == "mysticalgae" or itemNameQuery == "mystic algae" then properItemName = "MysticAlgae"
						else
							-- Check Equipment Config (Eggs/Items)
							local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)
							for key, _ in pairs(EquipmentConfig) do
								if type(key) == "string" and key:lower() == itemNameQuery then
									properItemName = key
									break
								end
							end
						end
						
						if properItemName then
							PlayerData.update(targetPlayer, function(data)
								if properItemName == "Biomass" then
									data.Biomass = (data.Biomass or 0) + amount
								elseif properItemName == "Pearls" then
									data.Pearls = (data.Pearls or 0) + amount
								elseif properItemName == "GreenAlgae" or properItemName == "PinkAlgae" or properItemName == "OrangeAlgae" or properItemName == "MysticAlgae" then
									if not data.Plankton then data.Plankton = {} end
									data.Plankton[properItemName] = (data.Plankton[properItemName] or 0) + amount
								else
									-- It's an inventory item
									if type(data.Inventory) ~= "table" then data.Inventory = {} end
									data.Inventory[properItemName] = (data.Inventory[properItemName] or 0) + amount
									data._InventoryDirty = true
								end
								return data
							end)
							print(player.Name .. " gave " .. amount .. " " .. properItemName .. " to " .. targetPlayer.Name)
						else
							print("[Give Command] Could not find item matching: " .. itemNameQuery)
						end
					end
				end
			end
		elseif msg:lower() == "/unlockall" and AllowedUsers[player.Name] then
			PlayerData.update(player, function(data)
				-- Give max resources
				data.Biomass = 999999999
				data.Pearls = 999999999
				if not data.Plankton then data.Plankton = {} end
				data.Plankton.GreenAlgae = 999999999
				data.Plankton.PinkAlgae = 999999999
				data.Plankton.OrangeAlgae = 999999999
				data.Plankton.MysticAlgae = 999999999
				
				local ReplicatedStorage = game:GetService("ReplicatedStorage")
				local Shared = ReplicatedStorage:FindFirstChild("Shared")
				if Shared then
					-- Unlock all tools
					local ToolConfig = require(Shared.ToolConfig)
					if not data.UnlockedTools then data.UnlockedTools = {} end
					for name, _ in pairs(ToolConfig) do
						if not table.find(data.UnlockedTools, name) then
							table.insert(data.UnlockedTools, name)
						end
					end
					
					-- Unlock all backpacks
					local BackpackConfig = require(Shared.BackpackConfig)
					if not data.UnlockedBackpacks then data.UnlockedBackpacks = {} end
					for name, _ in pairs(BackpackConfig) do
						if not table.find(data.UnlockedBackpacks, name) then
							table.insert(data.UnlockedBackpacks, name)
						end
					end
				end
				
				print(player.Name .. " unlocked everything and gave themselves massive resources.")
				return data
			end)
		end
	end)
end)
