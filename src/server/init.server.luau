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
local PhysicsService = game:GetService("PhysicsService")

-- Create collision group for players to disable player-player collision
pcall(function()
	PhysicsService:RegisterCollisionGroup("Players")
end)
PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)

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
-- ShopService doesn't have a .Start() yet but it connects OnServerEvent on requirement

-- Setup Conversion RemoteEvent
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")


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

AbilityActivation.OnServerEvent:Connect(function(player, abilityName)
	if abilityName == "RainmakerUltimate" then
		AbilityService.IncrementAbilitiesCommitted(player)
		
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
				local f = workspace:FindFirstChild(fieldName)
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
				local finalDamage = 50 * playerAttack
				
				if math.random() <= megaCritChance then
					isCrit = true
					finalDamage = finalDamage * megaCritPower
				elseif math.random() <= critChance then
					isCrit = true
					finalDamage = finalDamage * critPower
				end
				
				local avgLevel = MobService.GetAverageFishLevel(player)
				
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
	
	-- Gameplay Logic: Harvest after tween delay
	if movetype == "main" then
		task.delay(0.6, function()
			if not player or not player.Character or not player.Character.PrimaryPart then return end
			
			-- Strictly in front: Offset center by half the box depth (50)
			local boxDepth = 100
			local targetCF = player.Character.PrimaryPart.CFrame * CFrame.new(0, 0, -boxDepth/2) 
			local size = Vector3.new(50, 50, boxDepth) 
			
			local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Include
			local filterFolders = {}
			for fieldName, _ in pairs(ResourceConfig.Fields) do
				local f = workspace:FindFirstChild(fieldName)
				if f then table.insert(filterFolders, f) end
			end
			overlapParams.FilterDescendantsInstances = filterFolders
			
			local parts = workspace:GetPartBoundsInBox(targetCF, size, overlapParams)
			local algaeTargets = {}
			for _, p in ipairs(parts) do
				if p:IsA("BasePart") then
					local capacity = p:FindFirstChild("Capacity")
					if capacity and capacity.Value > 0 then
						table.insert(algaeTargets, p)
					end
				end
			end
			
			if #algaeTargets > 0 then
				-- Large batch harvest: 50 base algae per target (affected by mults)
				HarvestService.HarvestMultipleBatched(player, algaeTargets, 50, true)
			end
		end)
	end
end)

print("Fish Hatchery Simulator Server Loaded.")

-- Admin Commands
local AllowedUsers = {["Crazyyism"] = true, ["Player1"] = true, ["Player2"] = true, ["EllabellTheLolGirl"] = true}
local BadgeService = game:GetService("BadgeService")
local WELCOME_BADGE_ID = 2305187807978897

game:GetService("Players").PlayerAdded:Connect(function(player)
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
		if msg:lower() == "/testcapacity" and AllowedUsers[player.Name] then
			PlayerData.update(player, function(data)
				if not data.Stats then data.Stats = {} end
				-- Set MaxCapacity directly — RecalculateStats resets CapacityMultiplier
				-- to 1.0 at startup so we bypass it entirely for this debug command.
				data.MaxCapacity = math.huge
				data._InfiniteCapacity = true
				print(player.Name .. " enabled infinite capacity.")
				return data
			end)
		elseif msg:lower() == "/default" and AllowedUsers[player.Name] then
			PlayerData.update(player, function(data)
				if not data.Stats then data.Stats = {} end
				data._InfiniteCapacity = nil
				-- Recalculate properly from backpack/artifacts
				PlayerData.RecalculateStats(data)
				print(player.Name .. " reset capacity.")
				return data
			end)
		elseif msg:lower() == "/cooldowns" and AllowedUsers[player.Name] then
			local currentState = player:GetAttribute("NoCooldowns") or false
			player:SetAttribute("NoCooldowns", not currentState)
			print(player.Name .. " toggled ability cooldowns: " .. tostring(not currentState))
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
			print(player.Name .. " granted 200 Rhythm Fever stacks to " .. targetPlayer.Name)
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
							if EquipmentConfig.Eggs then
								for key, _ in pairs(EquipmentConfig.Eggs) do
									if key:lower() == itemNameQuery then
										properItemName = key
										break
									end
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
