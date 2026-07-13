local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)
local NotifierController = require(script.Parent:WaitForChild("NotifierController"))

local ShopController = {}

local player = Players.LocalPlayer
local currentShop = nil
local shopOpen = false
local interactionDebounce = false
local clientData = {}
local isFirstDataLoad = true
local knownShops = {} -- List of {Instance = model, Key = configKey, Platform = part}
local shopTarget = nil
local currentShopEntry = nil -- Specific entry from knownShops
local currentOpenFrame = nil
local currentShopItems = {} -- Array of {Key = "ItemID", Data = ItemData, CamIndex = 1}

local function FormatNumber(n)
	return tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end


-- Forward declaration for interaction handler
local handleInteraction

-- Data Sync
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
DataUpdateEvent.OnClientEvent:Connect(function(data)
	if data then 
		-- Check for Purchase Success (Inventory/Tool count increase)
		local playedSound = false
						
			-- Initial load skip logic
		if isFirstDataLoad then
			clientData = data
			isFirstDataLoad = false
		else
			if clientData then -- Should be true if logic flows correctly
				local function getDictSize(dict)
					local c = 0
					for k, v in pairs(dict or {}) do c = c + (type(v) == "number" and v or 1) end
					return c
				end
				local oldInv = getDictSize(clientData.Inventory)
				local newInv = getDictSize(data.Inventory)
				local oldTools = #(clientData.UnlockedTools or {})
				local newTools = #(data.UnlockedTools or {})
				local oldBackpacks = #(clientData.UnlockedBackpacks or {})
				local newBackpacks = #(data.UnlockedBackpacks or {})
				local oldArtifacts = #(clientData.UnlockedArtifacts or {})
				local newArtifacts = #(data.UnlockedArtifacts or {})
				
				-- Inventory Diff Notification Removed to prevent duplicates with Quest/Token/Harvest notifications.
				-- if (newInv > oldInv) then ... end
				
				if (newTools > oldTools) then
					for _, toolId in ipairs(data.UnlockedTools or {}) do
						if not table.find(clientData.UnlockedTools or {}, toolId) then
							local cfg = EquipmentConfig[toolId]
							local name = cfg and cfg.Name or toolId
							NotifierController:Notify("Unlocked " .. name .. "!", Color3.fromRGB(0, 255, 255))
						end
					end
				end
				
				if (newBackpacks > oldBackpacks) then
					for _, bpId in ipairs(data.UnlockedBackpacks or {}) do
						if not table.find(clientData.UnlockedBackpacks or {}, bpId) then
							local cfg = EquipmentConfig[bpId]
							local name = cfg and cfg.Name or bpId
							NotifierController:Notify("Unlocked " .. name .. "!", Color3.fromRGB(255, 170, 0))
						end
					end
				end

				if (newArtifacts > oldArtifacts) then
					for _, artId in ipairs(data.UnlockedArtifacts or {}) do
						if not table.find(clientData.UnlockedArtifacts or {}, artId) then
							local cfg = EquipmentConfig[artId]
							local name = cfg and cfg.Name or artId
							NotifierController:Notify("Unlocked " .. name .. "!", Color3.fromRGB(180, 100, 255))
						end
					end
				end
				
				if (newInv > oldInv) or (newTools > oldTools) or (newBackpacks > oldBackpacks) or (newArtifacts > oldArtifacts) then
					local sfx = ReplicatedStorage:FindFirstChild("VFX") and ReplicatedStorage.VFX:FindFirstChild("PurchaseSFX")
					local isSfxDisabled = data and data.Settings and data.Settings.DisableSFX
					if sfx and not isSfxDisabled then 
						sfx:Play() 
					end
				end
			end
			
			-- Merge Data
			if not clientData then
				clientData = data
			else
				for k, v in pairs(data) do
					clientData[k] = v
				end
			end
		end

		-- Refresh UI if open
		if shopOpen and currentOpenFrame and shopTarget then
			ShopController.UpdateShopDisplay(currentOpenFrame, shopTarget)
		end
	end
end)

-- Animation Constants & Variables
local UI_BLUR_NAME = "ShopUIBlur" -- Keeping for potential future use or cleanup, but not using it.
local cameraTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local cam = workspace.CurrentCamera

local currentShopCams = {}
local currentCamIndex = 1


local function RegisterShop(model)
	-- Duplicate Check
	for _, s in ipairs(knownShops) do
		if s.Instance == model then return end
	end

	-- Skip if this is part of a character (Prevents equipped artifacts from being shops)
	if model:FindFirstChild("Humanoid") or model:FindFirstAncestorOfClass("Player") or (model.Parent and model.Parent:FindFirstChild("Humanoid")) then
		return
	end
	
	-- Additional check for accessories/tools in character
	if model:FindFirstAncestorOfClass("Accessory") or model:FindFirstAncestorOfClass("Tool") then
		local char = model:FindFirstAncestorOfClass("Model")
		if char and char:FindFirstChild("Humanoid") then return end
	end

	local name = model.Name
	local targetKey = nil
	
	-- Prioritize direct key match first
	if ShopConfig.Shops[name] then
		targetKey = name
	else
		-- Normalize name by removing spaces (e.g., "Zooplankton Machine" -> "ZooplanktonMachine")
		local cleanName = name:gsub("%s+", "")
		if ShopConfig.Shops[cleanName] then
			targetKey = cleanName
		end
	end
	
	if not targetKey then
		if name == "EggShop" or name == "BasicEggShop" then 
			targetKey = "EggShop" 
		elseif name == "NoobShop" then 
			targetKey = "NoobShop"
		elseif name == "ArtifactShop1" then -- Strict match for the main shop model
			targetKey = "ArtifactShop1"
		elseif name == "RunicShop" then
			targetKey = "RunicShop"
		elseif name == "ZooplanktonMachine" then
			targetKey = "ZooplanktonMachine"
		elseif name:lower():match("shop") or name:lower():match("egg") then
			if name:lower():match("noob") then targetKey = "NoobShop" else targetKey = "EggShop" end
		end
	end
	
	if targetKey then
		local platform = model:FindFirstChild("Platform", true) or model:FindFirstChild("platform", true) or model:FindFirstChildWhichIsA("BasePart")
		if platform then
			table.insert(knownShops, {Instance = model, Key = targetKey, Platform = platform})
		end
	end
end

-- Recursive scan
local function ScanForShops(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") then
			RegisterShop(child)
			ScanForShops(child) -- Check inside folders
		end
	end
end

function ShopController.Start()
	-- Request Initial Data
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local RequestData = Remotes:FindFirstChild("RequestData")
	if RequestData then RequestData:FireServer() end

	-- Initial Scan
	ScanForShops(workspace)
	
	-- Listen for new shops (Streaming/Late Load)
	workspace.DescendantAdded:Connect(function(descendant)
		-- Check for containers
		if descendant:IsA("Model") or descendant:IsA("Folder") then
			RegisterShop(descendant)
		end
		-- Check for delayed platforms
		if descendant.Name == "Platform" or descendant.Name == "platform" then
			-- It might be inside a shop that failed to register earlier
			local p = descendant.Parent
			while p and p ~= workspace do
				RegisterShop(p)
				p = p.Parent
			end
		end
	end)
	
	local playerGui = player:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("Main")
	local interactionFrame = mainGui:WaitForChild("Interaction")
	local keybindLabel = interactionFrame:WaitForChild("Keybind")
	local actionLabel = interactionFrame:WaitForChild("InteractionType")
	
	-- Setup Blur (Disabled for now as per rework, but keeping cleanup if needed)
	local blur = Lighting:FindFirstChild(UI_BLUR_NAME)
	if blur then blur:Destroy() end -- Ensure no blur exists

	
	-- Get existing Shop UI from Main
	local shopFrame = mainGui:WaitForChild("ShopEquipHolder")

	-- Get Equipment Shop UI
	-- local equipmentFrame = mainGui:WaitForChild("ShopEquipment", 2) -- User implies only ShopEquipHolder exists
	local equipmentFrame = nil -- Disable for now to force usage of ShopEquipHolder logic
	
	-- Initialize Frame State
	local function closeFrameState(f)
		f.Visible = false
	end
	
	closeFrameState(shopFrame)
	if equipmentFrame then closeFrameState(equipmentFrame) end
	
	local canInteract = false
	-- shopTarget and currentOpenFrame moved to module scope
	
	-- Character Died Hook
	local function connectToCharacter(character)
		-- Re-cache UI references in case they were reset
		local playerGui = player:WaitForChild("PlayerGui")
		mainGui = playerGui:WaitForChild("Main")
		interactionFrame = mainGui:WaitForChild("Interaction")
		keybindLabel = interactionFrame:WaitForChild("Keybind")
		actionLabel = interactionFrame:WaitForChild("InteractionType")
		shopFrame = mainGui:WaitForChild("ShopEquipHolder")
		equipmentFrame = nil -- mainGui:FindFirstChild("ShopEquipment")
		
		-- Ensure frames are in closed state
		closeFrameState(shopFrame)
		if equipmentFrame then closeFrameState(equipmentFrame) end
		
		-- Setup Interaction Button Click Handler
		local interactionButton = interactionFrame:FindFirstChild("InteractionButton")
		if interactionButton and (interactionButton:IsA("TextButton") or interactionButton:IsA("ImageButton")) then
			local function onActivated()
				if handleInteraction then
					handleInteraction()
					
					-- Visual Feedback
					local originalColor = interactionButton.BackgroundColor3
					interactionButton.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
					task.delay(0.1, function()
						interactionButton.BackgroundColor3 = originalColor
					end)
				end
			end

			interactionButton.Activated:Connect(onActivated)

			-- Extra responsiveness for Touch/Touchpad
			interactionButton.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					onActivated()
				end
			end)
		end
		
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			if shopOpen then 
				if currentOpenFrame then ShopController.CloseShop(currentOpenFrame)
				else ShopController.CloseShop(shopFrame) end
			end
		end)
	end
	if player.Character then connectToCharacter(player.Character) end
	player.CharacterAdded:Connect(connectToCharacter)
	
	-- Proximity detection (using cached shops)
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		if not char or not char.PrimaryPart then return end
		local root = char.PrimaryPart.Position
		
		-- 1. Find the nearest shop
		local nearestEntry = nil
		local minDistance = math.huge
		local DEFAULT_RANGE = 25
		
		-- Check aquarium priority
		local nearAquarium = false
		local aquariumsFolder = game.Workspace:FindFirstChild("Aquariums")
		if aquariumsFolder then
			for _, plot in ipairs(aquariumsFolder:GetChildren()) do
				local spawnPart = plot:FindFirstChild("Spawn")
				if spawnPart and (spawnPart.Position - root).Magnitude < 8 then
					nearAquarium = true; break
				end
			end
		end

		if not nearAquarium then
			for _, shop in ipairs(knownShops) do
				if shop.Platform and shop.Platform.Parent then
					local dist = (shop.Platform.Position - root).Magnitude
					local shopCfg = ShopConfig.Shops[shop.Key]
					local maxRange = shopCfg and shopCfg.Range or DEFAULT_RANGE
					
					if dist < maxRange and dist < minDistance then
						minDistance = dist
						nearestEntry = shop
					end
				end
			end
		end

		-- 2. Handle Logic based on state
		if shopOpen then
			-- We are in a shop. Check distance to the shop entry we OPENED.
			local entry = currentShopEntry or nearestEntry
			if entry and entry.Platform then
				local dist = (entry.Platform.Position - root).Magnitude
				local shopCfg = ShopConfig.Shops[entry.Key]
				local maxRange = (shopCfg and shopCfg.Range or DEFAULT_RANGE) + 5
				
				if dist > maxRange then
					-- Walked too far away
					ShopController.CloseShop(currentOpenFrame or shopFrame)
					interactionFrame.Visible = false
					currentShopEntry = nil
					shopTarget = nil
					canInteract = false
					return
				end
			end

			-- Show Close UI (Bottom Center)
			interactionFrame.Visible = true
			interactionFrame.Position = UDim2.new(0.5, 0, 0.85, 0)
			interactionFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			keybindLabel.Text = "E"
			actionLabel.Text = "Close Shop"
			canInteract = true
			shopTarget = entry and entry.Key
		else
			-- Shop is closed. 
			currentShopEntry = nearestEntry
			
			if nearestEntry then
				canInteract = true
				shopTarget = nearestEntry.Key
				
				local platform = nearestEntry.Platform
				local worldPos = platform and (platform:IsA("BasePart") and platform.Position or platform:GetPivot().Position) + Vector3.new(0, 5, 0)
				
				if worldPos then
					local vector, onScreen = cam:WorldToScreenPoint(worldPos)
					if onScreen then
						interactionFrame.Visible = true
						-- Smooth positioning above shop
						local targetPos = UDim2.new(0, vector.X, 0, vector.Y)
						interactionFrame.Position = interactionFrame.Position:Lerp(targetPos, 0.2)
					else
						interactionFrame.Visible = false
					end
				else
					interactionFrame.Visible = true -- Fallback static
				end
				
				keybindLabel.Text = "E"
				local shopCfg = ShopConfig.Shops[nearestEntry.Key]
				actionLabel.Text = "Open " .. (shopCfg and (shopCfg.ShopName or "Shop") or "Shop")
			else
				-- No shop nearby
				canInteract = false
				shopTarget = nil
				if not actionLabel.Text:match("Talk") and not actionLabel.Text:match("Cannon") and not actionLabel.Text:match("Wish") and not actionLabel.Text:match("Aquarium") and not actionLabel.Text:match("Convert") then
					interactionFrame.Visible = false
				end
			end
		end
	end)
	
	handleInteraction = function()
		if interactionDebounce then return end
		
		if canInteract and shopTarget then
			interactionDebounce = true
			if not shopOpen then
				local cfg = ShopConfig.Shops[shopTarget]
				
				if cfg and cfg.RequiredFish then
					local fishCount = 0
					if clientData.FishSchool then
						for _, _ in pairs(clientData.FishSchool) do fishCount += 1 end
					end
					
					if fishCount < cfg.RequiredFish then
						NotifierController:Notify("You need " .. cfg.RequiredFish .. " fish to enter this shop!", Color3.fromRGB(255, 50, 50))
						task.delay(0.3, function() interactionDebounce = false end)
						return
					end
				end
				
				local targetFrame = shopFrame
				
				if cfg and cfg.ShopType == "Equipment" and equipmentFrame then
					targetFrame = equipmentFrame
				end
				
				currentOpenFrame = targetFrame
				local success = ShopController.OpenShop(targetFrame, nil, shopTarget)
				if not success then
					currentOpenFrame = nil
					shopOpen = false
					currentShopEntry = nil
				end
			else
				ShopController.CloseShop(currentOpenFrame or shopFrame)
				currentOpenFrame = nil
				currentShopEntry = nil
			end
			task.delay(0.3, function() interactionDebounce = false end)
		end
	end
	
	-- E key handler
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.E then
			handleInteraction()
		end
	end)
end




-- We need a robust input handler for the purchase button that changes behavior
local currentPurchaseConnection = nil

function ShopController.UpdatePurchaseButton(shopFrame, shopName, itemEntry, displayPrice)
	local item = itemEntry.Data
	local itemId = itemEntry.Key
	
	local equipHolder = shopFrame:FindFirstChild("ShopEquipHolder") or shopFrame
	local shopEquip = equipHolder:FindFirstChild("ShopEquip")
	if not shopEquip then return end
	
	local buyFrame = shopEquip:FindFirstChild("Buy")
	local purchaseButton = buyFrame and buyFrame:FindFirstChild("PurchaseButton")
	local buttonText = buyFrame and buyFrame:FindFirstChild("ButtonText")
	if purchaseButton and not buttonText then buttonText = purchaseButton:FindFirstChild("ButtonText") end
	
	if not purchaseButton then return end
	
	-- Cleanup old connection
	if currentPurchaseConnection then
		currentPurchaseConnection:Disconnect()
		currentPurchaseConnection = nil
	end
	
	local isOwned = false
	local isEquipped = false
	local isConsumable = (item.ProductType == "Egg" or item.ProductType == "Item") -- Treat as consumable
	
	if item.ProductType == "Tool" then
		if clientData.UnlockedTools and table.find(clientData.UnlockedTools, item.ToolId) then
			isOwned = true
		end
		if clientData.EquippedTool == item.ToolId then
			isEquipped = true
		end
	elseif item.ProductType == "Backpack" then
		if clientData.UnlockedBackpacks and table.find(clientData.UnlockedBackpacks, item.BackpackId) then
			isOwned = true
		end
		if clientData.EquippedBackpack == item.BackpackId then
			isEquipped = true
		end
	elseif item.ProductType == "Artifact" then
		if clientData.UnlockedArtifacts and table.find(clientData.UnlockedArtifacts, item.Name) then
			isOwned = true
		end
		if clientData.EquippedArtifacts and table.find(clientData.EquippedArtifacts, item.Name) then
			isEquipped = true
		end
	end
	
	-- Consumables (Eggs) are never "Owned/Equipped" in the UI sense, always purchaseable
	if isConsumable then
		isOwned = false 
		isEquipped = false
		
		if itemId == "Rhythm Egg" then
			if clientData.Inventory and (clientData.Inventory["Rhythm Egg"] or 0) > 0 then
				isOwned = true
			end
			if clientData.FishSchool then
				for _, fish in pairs(clientData.FishSchool) do
					if fish.Id == "Rhythm Fish" or fish.Id == "Rhythm Egg" then isOwned = true end
				end
			end
			if ShopController.RhythmGamepassOwned == nil then
				task.spawn(function()
					local MarketplaceService = game:GetService("MarketplaceService")
					local s, owns = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1661441381) end)
					ShopController.RhythmGamepassOwned = (s and owns) or false
				end)
			end
			if ShopController.RhythmGamepassOwned then
				isOwned = true
			end
		end
	end
	
	if isOwned then
		if itemId == "Hydroglider" and not (clientData.UnlockedTools and table.find(clientData.UnlockedTools, "Hydroglider+")) then
			-- Upgrade State for Hydroglider
			local upgradeItem = EquipmentConfig["Hydroglider+"]
			local upgradeId = "Hydroglider+"
			
			local canAfford = true
			local missingMaterial = nil
			
			if upgradeItem.Currency == "Biomass" then
				canAfford = (clientData.Biomass or 0) >= upgradeItem.Price
			end
			
			if canAfford and upgradeItem.Materials then
				for matName, required in pairs(upgradeItem.Materials) do
					local owned = 0
					if matName == "Pearl" then
						owned = clientData.Pearls or 0
					elseif clientData.Inventory then
						owned = clientData.Inventory[matName] or 0
					end
					if owned < required then
						canAfford = false
						missingMaterial = matName
						break
					end
				end
			end
			
			if canAfford then
				purchaseButton.Interactable = true
				purchaseButton.Active = true
				purchaseButton.AutoButtonColor = true
				purchaseButton.BackgroundColor3 = Color3.fromRGB(150, 0, 255)
				if buttonText then buttonText.Text = "Upgrade" end
				if buyFrame then buyFrame.BackgroundColor3 = Color3.fromRGB(150, 0, 255) end
				
				currentPurchaseConnection = purchaseButton.MouseButton1Click:Connect(function()
					ShopController.PurchaseItem(shopName, upgradeId, upgradeItem)
				end)
			else
				purchaseButton.Interactable = false
				purchaseButton.AutoButtonColor = false
				purchaseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
				if buyFrame then buyFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50) end
				if buttonText then 
					if missingMaterial then
						local displayMat = missingMaterial == "Pearl" and "Pearls" or missingMaterial
						buttonText.Text = "Not enough " .. displayMat
					else
						buttonText.Text = "Not enough " .. upgradeItem.Currency 
					end
				end
			end
			
			-- Update UI to show Upgrade Cost
			local cost = shopEquip:FindFirstChild("Cost")
			if cost and cost:FindFirstChild("CostText") then
				cost.CostText.Text = FormatNumber(upgradeItem.Price) .. " Biomass"
			end
			
			-- Manually append upgrade materials
			local materialReqFrame = shopEquip:FindFirstChild("MaterialReq")
			if materialReqFrame and upgradeItem.Materials then
				local template = materialReqFrame:FindFirstChild("AbilityTemplate")
				if template then
					-- Clear previous generated items
					for _, child in ipairs(materialReqFrame:GetChildren()) do
						if child:IsA("Frame") and child.Name == "MaterialItem" then
							child:Destroy()
						end
					end
					materialReqFrame.Visible = true
					for matName, requiredAmount in pairs(upgradeItem.Materials) do
						local matItem = template:Clone()
						matItem.Name = "MaterialItem"
						matItem.Visible = true
						matItem.Parent = materialReqFrame
						
						local amountLabel = matItem:FindFirstChild("Amount")
						local imageLabel = matItem:FindFirstChild("AbilityImage")
						local ownedCount = 0
						if matName == "Pearl" then ownedCount = clientData.Pearls or 0
						elseif clientData.Inventory then ownedCount = clientData.Inventory[matName] or 0 end
						
						if amountLabel then
							amountLabel.Text = tostring(requiredAmount)
							amountLabel.TextColor3 = (ownedCount >= requiredAmount) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 50, 50)
						end
						if imageLabel then
							local eggCfg = EquipmentConfig[matName]
							if eggCfg and eggCfg.ImageId then imageLabel.Image = eggCfg.ImageId end
						end
					end
				end
			end
			
			return
		end

		if isEquipped then
			-- Equipped State
			if item.ProductType == "Artifact" then
				-- Artifacts can be unequipped
				purchaseButton.Interactable = true
				purchaseButton.Active = true
				purchaseButton.AutoButtonColor = true
				purchaseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) -- Red for Unequip
				if buttonText then buttonText.Text = "Unequip" end
				
				-- Reset Buy Frame Color
				if buyFrame then
					buyFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
				end
				
				currentPurchaseConnection = purchaseButton.MouseButton1Click:Connect(function()
					ShopController.EquipItem(itemId, item)
				end)
			else
				-- Standard items (Tools/Backpacks) are just "Equipped" or "Owned" for unique items
				purchaseButton.Interactable = false
				purchaseButton.AutoButtonColor = false
				purchaseButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
				if buttonText then buttonText.Text = "Equipped" end
				
				-- Reset Buy Frame Color
				if buyFrame then
					-- Equipped usually means greyed out or theme?
					-- Let's stick to theme/default logic to "clear the red"
					local shopData = ShopConfig.Shops[shopName]
					if shopData.Theme and shopData.Theme.ButtonColor then
						buyFrame.BackgroundColor3 = shopData.Theme.ButtonColor
					else
						buyFrame.BackgroundColor3 = Color3.fromRGB(45, 180, 100)
					end
				end
			end
		else
			-- Equip State or Owned Consumable
			if isConsumable then
				purchaseButton.Interactable = false
				purchaseButton.Active = false
				purchaseButton.AutoButtonColor = false
				purchaseButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
				
				if buttonText then buttonText.Text = "Purchased" end
				
				-- Reset Buy Frame Color
				if buyFrame then
					local shopData = ShopConfig.Shops[shopName]
					if shopData.Theme and shopData.Theme.ButtonColor then
						buyFrame.BackgroundColor3 = shopData.Theme.ButtonColor
					else
						buyFrame.BackgroundColor3 = Color3.fromRGB(45, 180, 100)
					end
				end
			else
				purchaseButton.Interactable = true
				purchaseButton.Active = true
				purchaseButton.AutoButtonColor = true
				-- Theme color?
				local shopData = ShopConfig.Shops[shopName]
				if shopData.Theme and shopData.Theme.ButtonColor then 
					purchaseButton.BackgroundColor3 = shopData.Theme.ButtonColor 
				else
					purchaseButton.BackgroundColor3 = Color3.fromRGB(45, 180, 100)
				end
				
				if buttonText then buttonText.Text = "Equip" end
				
				-- Reset Buy Frame Color
				if buyFrame then
					local shopData = ShopConfig.Shops[shopName]
					if shopData.Theme and shopData.Theme.ButtonColor then
						buyFrame.BackgroundColor3 = shopData.Theme.ButtonColor
					else
						buyFrame.BackgroundColor3 = Color3.fromRGB(45, 180, 100)
					end
				end
				
				currentPurchaseConnection = purchaseButton.MouseButton1Click:Connect(function()
					ShopController.EquipItem(itemId, item)
				end)
			end
		end
	else
		-- Purchase State
		local canAfford = true
		local missingMaterial = nil
		
		if item.Currency == "Biomass" then
			canAfford = (clientData.Biomass or 0) >= displayPrice
		elseif item.Currency == "Algae" then
			local totalAlgae = 0
			if clientData.Plankton then
				for _, v in pairs(clientData.Plankton) do totalAlgae += v end
			end
			canAfford = totalAlgae >= displayPrice
		end
		
		-- Check Materials
		if canAfford and item.Materials then
			for matName, required in pairs(item.Materials) do
				local owned = 0
				if matName == "Pearl" then
					-- Pearls are stored as a dedicated integer, not in Inventory
					owned = clientData.Pearls or 0
				elseif clientData.Inventory then
					owned = clientData.Inventory[matName] or 0
				end
				
				if owned < required then
					canAfford = false
					missingMaterial = matName
					break
				end
			end
		end

		if canAfford then
			purchaseButton.Interactable = true
			purchaseButton.Active = true
			purchaseButton.AutoButtonColor = true
			local shopData = ShopConfig.Shops[shopName]
			if shopData.Theme and shopData.Theme.ButtonColor then 
				purchaseButton.BackgroundColor3 = shopData.Theme.ButtonColor 
			else
				purchaseButton.BackgroundColor3 = Color3.fromRGB(45, 180, 100)
			end
			
			if buttonText then 
				if isConsumable then
					buttonText.Text = "Buy"
				else
					buttonText.Text = "Purchase" 
				end
			end
			
			-- Reset Buy Frame Color (if it was red)
			if buyFrame then
				buyFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- Default or Transparent? assuming white/theme
				-- If buyFrame is transparent, this might look weird. Checking transparency might be better, or just rely on button.
				-- User asked for "buy frame" specifically.
				-- Let's try setting it to a neutral color or theme if possible, but for now we reset it.
				-- Actually better to check theme.
				local shopData = ShopConfig.Shops[shopName]
				if shopData.Theme and shopData.Theme.ButtonColor then
					buyFrame.BackgroundColor3 = shopData.Theme.ButtonColor
				else
					buyFrame.BackgroundColor3 = Color3.fromRGB(45, 180, 100) -- Match button default Green
				end
			end
			
			currentPurchaseConnection = purchaseButton.MouseButton1Click:Connect(function()
				ShopController.PurchaseItem(shopName, itemId, item)
			end)
		else
			-- Not Enough
			purchaseButton.Interactable = false
			purchaseButton.AutoButtonColor = false
			purchaseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			
			-- Also set Buy frame to red as requested
			if buyFrame then
				buyFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			end
			
			if buttonText then 
				if missingMaterial then
					local displayMat = missingMaterial == "Pearl" and "Pearls" or missingMaterial
					buttonText.Text = "Not enough " .. displayMat
				else
					buttonText.Text = "Not enough " .. item.Currency 
				end
			end
		end
	end
end

local shopConnections = {}

function ShopController.ClearConnections()
	for _, conn in pairs(shopConnections) do
		if conn then conn:Disconnect() end
	end
	shopConnections = {}
	
	-- Also clear purchase button connection if it exists separately
	if currentPurchaseConnection then
		currentPurchaseConnection:Disconnect()
		currentPurchaseConnection = nil
	end
end

function ShopController.UpdateShopDisplay(shopFrame, shopName)
	local itemEntry = currentShopItems[currentCamIndex]
	if not itemEntry then return end
	
	local item = itemEntry.Data
	
	-- shopFrame IS ShopEquipHolder now
	local shopEquip = shopFrame:FindFirstChild("ShopEquip")
	
	if shopEquip then
		local desc = shopEquip:FindFirstChild("Description")
		if desc and desc:FindFirstChild("DescriptionText") then
			desc.DescriptionText.Text = item.Description
		end
		
		local materialName = shopEquip:FindFirstChild("MaterialName")
		if materialName then
			materialName.Text = item.DisplayName or item.Name
		end
		
		local cost = shopEquip:FindFirstChild("Cost")
		local displayPrice = item.Price
		if item.Scaling then
			local count = (clientData.PurchaseStats and clientData.PurchaseStats[item.Name]) or 0
			local base = item.Scaling.Base or displayPrice
			local mult = item.Scaling.Multiplier or 1
			local max = item.Scaling.Max or math.huge
			displayPrice = math.min(base * (mult ^ count), max)
		end
		
		if cost and cost:FindFirstChild("CostText") then
			local suffix = (item.Currency == "Biomass" and " Biomass") or ""
			cost.CostText.Text = FormatNumber(displayPrice) .. suffix
		end

		-- Handle Material Requirements
		local materialReqFrame = shopEquip:FindFirstChild("MaterialReq")
		if materialReqFrame then
			local template = materialReqFrame:FindFirstChild("AbilityTemplate")
			if template then
				-- Hide template
				template.Visible = false
				
				-- Clear old items
				for _, child in ipairs(materialReqFrame:GetChildren()) do
					if child:IsA("Frame") and child.Name == "MaterialItem" then
						child:Destroy()
					end
				end
				
				local materials = item.Materials
				if materials and next(materials) then
					materialReqFrame.Visible = true
					local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
					
					for matName, requiredAmount in pairs(materials) do
						local matItem = template:Clone()
						matItem.Name = "MaterialItem"
						matItem.Visible = true
						matItem.Parent = materialReqFrame
						
						local amountLabel = matItem:FindFirstChild("Amount")
						local imageLabel = matItem:FindFirstChild("AbilityImage")
						
						-- Check how many we have
						local ownedCount = 0
						if matName == "Pearl" then
							-- Pearls use a dedicated integer field, not Inventory
							ownedCount = clientData.Pearls or 0
						elseif clientData.Inventory then
							ownedCount = clientData.Inventory[matName] or 0
						end
						
						if amountLabel then
							amountLabel.Text = tostring(requiredAmount)
							if ownedCount >= requiredAmount then
								amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White
							else
								amountLabel.TextColor3 = Color3.fromRGB(255, 50, 50) -- Red
							end
						end
						
						if imageLabel then
							local eggCfg = EquipmentConfig[matName]
							if eggCfg and eggCfg.ImageId then
								imageLabel.Image = eggCfg.ImageId
							end
						end
					end
				else
					materialReqFrame.Visible = false
				end
			end
		end
		-- Update ShopInfo Buffs
		local shopInfo = shopFrame:FindFirstChild("ShopInfo")
		if shopInfo then
			local buffsFrame = shopInfo:FindFirstChild("Buffs")
			if buffsFrame then
				local template = buffsFrame:FindFirstChild("Buff")
				if template then
					template.Visible = false
					
					-- Clear old items
					for _, child in ipairs(buffsFrame:GetChildren()) do
						if child:IsA("TextLabel") and child.Name ~= "Buff" then
							child:Destroy()
						end
					end
					
					local activeBuffs = {}
					
					-- Base Equipment Config Buffs (Backpacks)
					if item.Capacity and item.Capacity > 0 then table.insert(activeBuffs, "+" .. item.Capacity .. " Max Capacity") end
					if item.ConvertAdd and item.ConvertAdd > 0 then table.insert(activeBuffs, "+" .. item.ConvertAdd .. "% Convert Rate") end
					if item.AlgaePercentAdd and item.AlgaePercentAdd > 0 then table.insert(activeBuffs, "+" .. item.AlgaePercentAdd .. "% All Algae") end
					
					-- Artifact Stats
					if item.Stats then
						if item.Stats.AlgaeBoost then table.insert(activeBuffs, "+" .. (item.Stats.AlgaeBoost * 100) .. "% All Algae") end
						if item.Stats.CapacityBoost then table.insert(activeBuffs, "+" .. (item.Stats.CapacityBoost * 100) .. "% Capacity") end
						if item.Stats.ConvertBoost then table.insert(activeBuffs, "+" .. (item.Stats.ConvertBoost * 100) .. "% Convert Rate") end
						if item.Stats.SpeedBoost then table.insert(activeBuffs, "+" .. (item.Stats.SpeedBoost * 100) .. "% Move Speed") end
						if item.Stats.InstantConvertBoost then table.insert(activeBuffs, "+" .. (item.Stats.InstantConvertBoost * 100) .. "% Inst. Convert") end
						if item.Stats.OrangeAlgaeBoost then table.insert(activeBuffs, "+" .. (item.Stats.OrangeAlgaeBoost * 100) .. "% Orange Algae") end
						if item.Stats.GreenAlgaeBoost then table.insert(activeBuffs, "+" .. (item.Stats.GreenAlgaeBoost * 100) .. "% Green Algae") end
						if item.Stats.PinkAlgaeBoost then table.insert(activeBuffs, "+" .. (item.Stats.PinkAlgaeBoost * 100) .. "% Pink Algae") end
						if item.Stats.BiomassBoost then table.insert(activeBuffs, "+" .. (item.Stats.BiomassBoost * 100) .. "% Biomass / Algae") end
					end
					
					if item.Passive then
						table.insert(activeBuffs, "Passive: " .. item.Passive)
					end
					
					-- Tools (from ToolConfig)
					if item.ProductType == "Tool" and item.ToolId then
						local ToolConfig = require(ReplicatedStorage.Shared.ToolConfig)
						local tc = ToolConfig[item.ToolId]
						if tc then
							if tc.CapacityBurn then table.insert(activeBuffs, "Consumes " .. tc.CapacityBurn .. " Cap/hit") end
							if tc.Cooldown then table.insert(activeBuffs, tc.Cooldown .. "s Cooldown") end
							if tc.HarvestRadius then table.insert(activeBuffs, "Harvest Radius: " .. tc.HarvestRadius .. " studs") end
							if tc.Pattern and #tc.Pattern > 1 then table.insert(activeBuffs, "Hits " .. #tc.Pattern .. " Tiles") end
							if tc.HasAbility then table.insert(activeBuffs, "Has Ability") end
						end
					end
					
					if #activeBuffs > 0 then
						shopInfo.Visible = true
						for _, buffText in ipairs(activeBuffs) do
							local t = template:Clone()
							t.Name = "ActiveBuff"
							t.Text = buffText
							t.Visible = true
							t.Parent = buffsFrame
						end
					else
						shopInfo.Visible = false
					end
				end
			end
		end
		
		ShopController.UpdatePurchaseButton(shopFrame, shopName, itemEntry, displayPrice)
	end
end

local camTargetVal = Instance.new("CFrameValue")
camTargetVal.Name = "ShopCamTarget"

function ShopController.PerformCameraTween(targetIndex)
	if not currentShopCams[targetIndex] then return end
	local targetPart = currentShopCams[targetIndex]
	
	-- Tween the VALUE, not the camera directly, so the RenderStepped can read it and add wobble
	local tween = TweenService:Create(camTargetVal, cameraTweenInfo, {Value = targetPart.CFrame})
	tween:Play()
end

function ShopController.StartCameraLoop()
	-- Clean up existing
	if shopConnections["CameraRender"] then shopConnections["CameraRender"]:Disconnect() end
	
	local startTime = os.clock()
	
	shopConnections["CameraRender"] = RunService.RenderStepped:Connect(function()
		local t = os.clock() - startTime
		
		-- Wobble Math
		local wobbleX = math.sin(t * 0.5) * 0.06 -- Adjust speed and intensity
		local wobbleY = math.cos(t * 0.4) * 0.06
		local wobbleZ = math.sin(t * 0.3) * 0.06
		
		local wobbleAngles = CFrame.Angles(wobbleX, wobbleY, wobbleZ)
		
		-- Simply set camera to Target + Wobble
		cam.CFrame = camTargetVal.Value * wobbleAngles
	end)
end

function ShopController.OpenShop(shopFrame, template, shopName)
	if shopOpen then 
		return false 
	end
	
	-- Find shop instance for cameras
	local shopInstance = nil
	for _, s in ipairs(knownShops) do
		if s.Key == shopName then
			shopInstance = s.Instance
			break
		end
	end
	
	if not shopInstance then 
		warn("Shop Instance not found for camera:", shopName)
		return false
	end
	
	-- Collect Cameras
	currentShopCams = {}
	for _, child in ipairs(shopInstance:GetChildren()) do
		if child.Name:match("^Cam%d+$") then
			table.insert(currentShopCams, child)
		end
	end
	
	table.sort(currentShopCams, function(a, b)
		local nA = tonumber(a.Name:match("%d+"))
		local nB = tonumber(b.Name:match("%d+"))
		return nA < nB
	end)
	
	if #currentShopCams == 0 then 
		warn("No shop cameras found in model!")
		return false
	end

	-- Collect Items from EquipmentConfig for this Shop
	currentShopItems = {}
	for key, item in pairs(EquipmentConfig) do
		if item.Shop == shopName then
			-- Parse Cam number
			if item.Cam then
				local camNum = tonumber(item.Cam:match("%d+"))
				if camNum then
					table.insert(currentShopItems, {Key = key, Data = item, CamIndex = camNum})
				else
					warn("Item " .. key .. " has invalid Cam property: " .. tostring(item.Cam))
				end
			else
				warn("Item " .. key .. " is missing Cam property in EquipmentConfig")
			end
		end
	end
	
	-- Sort items by Cam Index matches strictly
	table.sort(currentShopItems, function(a, b)
		return a.CamIndex < b.CamIndex
	end)
	
	if #currentShopItems == 0 then
		warn("No items found for shop: " .. shopName .. " in EquipmentConfig!")
		return false
	end
	
	shopOpen = true
	currentCamIndex = 1
	ShopController.ClearConnections() -- Safety clear
	
	-- Initial Camera Setup
	cam.CameraType = Enum.CameraType.Scriptable
	
	-- Start from current player view for smooth transition
	camTargetVal.Value = cam.CFrame 
	
	-- Start the wobble loop IMMEDIATELY so `cam.CFrame` is being updated by `camTargetVal`
	ShopController.StartCameraLoop()
	
	-- Tween to first shop cam
	if currentShopCams[1] then
		-- Use PerformCameraTween logic but explicitly here or check if function handles it
		-- PerformCameraTween expects index 1..N.
		ShopController.PerformCameraTween(1)
	end
	
	-- Setup UI
	shopFrame.Visible = true
	
	local equipHolder = shopFrame:FindFirstChild("ShopEquipHolder") or shopFrame
	-- Make sure the inner ShopEquip frame is visible
	local shopEquip = equipHolder:FindFirstChild("ShopEquip")
	if shopEquip then
		shopEquip.Visible = true
	else
		warn("DEBUG: ShopEquip frame not found in", equipHolder:GetFullName())
	end

	local navFrame = equipHolder:FindFirstChild("ShopNavigate")
	
	if navFrame then
		navFrame.Visible = (#currentShopCams > 1)
		
		local leftBtn = navFrame:FindFirstChild("Left") and navFrame.Left:FindFirstChild("LeftButton")
		local rightBtn = navFrame:FindFirstChild("Right") and navFrame.Right:FindFirstChild("RightButton")
		
		if leftBtn then
			shopConnections.Left = leftBtn.MouseButton1Click:Connect(function()
				currentCamIndex = currentCamIndex - 1
				if currentCamIndex < 1 then currentCamIndex = #currentShopCams end
				ShopController.PerformCameraTween(currentCamIndex)
				ShopController.UpdateShopDisplay(shopFrame, shopName)
			end)
		end
		
		if rightBtn then
			shopConnections.Right = rightBtn.MouseButton1Click:Connect(function()
				currentCamIndex = currentCamIndex + 1
				if currentCamIndex > #currentShopCams then currentCamIndex = 1 end
				ShopController.PerformCameraTween(currentCamIndex)
				ShopController.UpdateShopDisplay(shopFrame, shopName)
			end)
		end
	end
	
	ShopController.UpdateShopDisplay(shopFrame, shopName)
	return true
end

function ShopController.CloseShop(shopFrame)
	if not shopOpen then return end
	shopOpen = false
	
	shopFrame.Visible = false
	cam.CameraType = Enum.CameraType.Custom
	
	ShopController.ClearConnections()
end


function ShopController.PurchaseItem(shopName, itemId, itemData)
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if Remotes then
		local PurchaseEvent = Remotes:FindFirstChild("PurchaseShopItem")
		if not PurchaseEvent then
			PurchaseEvent = Instance.new("RemoteEvent")
			PurchaseEvent.Name = "PurchaseShopItem"
			PurchaseEvent.Parent = Remotes
		end
		PurchaseEvent:FireServer(shopName, itemId)
	end
end

function ShopController.EquipItem(itemId, itemData)
	print("Attempting to equip:", itemData.Name)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if Remotes then
		local EquipEvent = Remotes:FindFirstChild("EquipShopItem")
		if not EquipEvent then
			EquipEvent = Instance.new("RemoteEvent")
			EquipEvent.Name = "EquipShopItem"
			EquipEvent.Parent = Remotes
		end
		
		-- Use the strict ID required for unlocking, or fallback to the config key
		local targetId = itemId
		if itemData.ProductType == "Tool" and itemData.ToolId then
			targetId = itemData.ToolId
		elseif itemData.ProductType == "Backpack" and itemData.BackpackId then
			targetId = itemData.BackpackId
		elseif itemData.ProductType == "Artifact" and itemData.Name then
			targetId = itemData.Name
		end
		
		EquipEvent:FireServer(itemData.ProductType, targetId)
	end
end

return ShopController
