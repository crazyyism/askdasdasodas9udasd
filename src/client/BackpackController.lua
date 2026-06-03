local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BackpackController = {}

function BackpackController.Start()
	local player = Players.LocalPlayer
	local currentBackpackId = nil
	local currentBackpackModel = nil
	
	-- Track other players' backpacks
	local remoteBackpacks = {} -- [Player] = {Id = "Pouch", Model = model}
	
	local function equipBackpack(backpackId, targetCharacter)
		if not backpackId then return end
		local character = targetCharacter or player.Character
		if not character then return end
		
		-- Cleanup existing
		local existing = character:FindFirstChild("EquippedBackpack")
		if existing then existing:Destroy() end
		-- Also cleanup legacy name just in case
		local legacy = character:FindFirstChild("Pouch")
		if legacy then legacy:Destroy() end
		
		-- Get Template
		local backpackFolder = ReplicatedStorage:WaitForChild("Backpacks", 5)
		if not backpackFolder then return end
		
		local template = backpackFolder:FindFirstChild(backpackId)
		if not template then 
			warn("BackpackController: Template not found for", backpackId)
			return 
		end
		
		-- Find Torso
		local torso = character:WaitForChild("UpperTorso", 5) or character:WaitForChild("Torso", 5)
		if not torso then return end
		
		-- Clone
		local model = template:Clone()
		model.Name = "EquippedBackpack"
		
		-- Find Handle
		local handle = model:FindFirstChild("Handle")
		if not handle and model:IsA("BasePart") then handle = model end
		
		if not handle then
			warn("BackpackController: Handle not found in", backpackId)
			return
		end
		
		local backpackAttach = handle:FindFirstChild("BackpackAttach")
		if not backpackAttach then
			warn("BackpackController: BackpackAttach not found in Handle for", backpackId)
			return
		end
		
		-- Attachment Logic
		local bodyAttach = Instance.new("Attachment")
		bodyAttach.Name = "BodyBackpackAttachment"
		bodyAttach.Position = Vector3.new(0, 0, 0)
		bodyAttach.Parent = torso
		
		local constraint = Instance.new("RigidConstraint")
		constraint.Attachment0 = bodyAttach
		constraint.Attachment1 = backpackAttach
		constraint.Parent = handle
		
		-- Physics cleanup
		for _, desc in ipairs(model:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.CanCollide = false
				desc.Massless = true
				desc.Anchored = false
			end
		end
		if model:IsA("BasePart") then
			model.CanCollide = false; model.Massless = true; model.Anchored = false
		end
		
		model.Parent = character
		
		-- Track if local player
		if character == player.Character then
			currentBackpackModel = model
			currentBackpackId = backpackId
			print("BackpackController: Equipped", backpackId, "on local player")
		else
			print("BackpackController: Equipped", backpackId, "on remote player", character.Name)
			return model
		end
	end
	
	-- Data Sync (Local Player)
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		if data and data.EquippedBackpack then
			local oldId = currentBackpackId
			currentBackpackId = data.EquippedBackpack -- Cache immediately
			
			-- Update if ID changed OR model is missing
			if currentBackpackId ~= oldId or not currentBackpackModel or not currentBackpackModel.Parent then
				equipBackpack(currentBackpackId)
			end
		end
	end)
	
	-- Request Initial Data
	local RequestData = Remotes:FindFirstChild("RequestData")
	if RequestData then RequestData:FireServer() end
	
	player.CharacterAdded:Connect(function()
		currentBackpackModel = nil
		if currentBackpackId then
			equipBackpack(currentBackpackId)
		end
	end)
	
	-- Remote Player Backpack Replication
	local BackpackReplicationEvent = Remotes:FindFirstChild("BackpackReplicationEvent")
	if not BackpackReplicationEvent then
		-- Create it if it doesn't exist (server should create it, but just in case)
		task.wait(2)
		BackpackReplicationEvent = Remotes:FindFirstChild("BackpackReplicationEvent")
	end
	
	if BackpackReplicationEvent then
		BackpackReplicationEvent.OnClientEvent:Connect(function(allPlayerBackpacks)
			-- allPlayerBackpacks = {[UserId] = "BackpackId"}
			for userIdStr, backpackId in pairs(allPlayerBackpacks) do
				local uid = tonumber(userIdStr)
				if uid == player.UserId then continue end -- Skip local player
				
				local otherPlayer = Players:GetPlayerByUserId(uid)
				if otherPlayer and otherPlayer.Character then
					local existing = otherPlayer.Character:FindFirstChild("EquippedBackpack")
					local currentId = remoteBackpacks[otherPlayer] and remoteBackpacks[otherPlayer].Id
					
					-- Only update if backpack ID changed
					if backpackId ~= currentId or not existing then
						local newModel = equipBackpack(backpackId, otherPlayer.Character)
						remoteBackpacks[otherPlayer] = {Id = backpackId, Model = newModel}
					end
				end
			end
		end)
	end
	
	-- Handle remote players joining
	Players.PlayerAdded:Connect(function(otherPlayer)
		if otherPlayer == player then return end
		
		otherPlayer.CharacterAdded:Connect(function(char)
			task.wait(1) -- Wait for data to sync
			-- Re-equip backpack if we have data
			if remoteBackpacks[otherPlayer] and remoteBackpacks[otherPlayer].Id then
				equipBackpack(remoteBackpacks[otherPlayer].Id, char)
			end
		end)
	end)
	
	-- Handle players already in game
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player and otherPlayer.Character then
			otherPlayer.CharacterAdded:Connect(function(char)
				task.wait(1)
				if remoteBackpacks[otherPlayer] and remoteBackpacks[otherPlayer].Id then
					equipBackpack(remoteBackpacks[otherPlayer].Id, char)
				end
			end)
		end
	end
	
	-- Cleanup when players leave
	Players.PlayerRemoving:Connect(function(otherPlayer)
		remoteBackpacks[otherPlayer] = nil
	end)
end

return BackpackController
