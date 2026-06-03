local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)

local InventoryController = {}
local player = Players.LocalPlayer

function InventoryController.Start()
	-- Data Sync
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
	
	-- Cached References
	local cachedContainer, cachedTemplate
	
	local function SetupGUI()
		local playerGui = player:WaitForChild("PlayerGui")
		local mainGui = playerGui:WaitForChild("Main", 10)
		if not mainGui then return end
		
		local mainFrame = mainGui:WaitForChild("Main", 10)
		if not mainFrame then return end
		
		local invFrame = mainFrame:WaitForChild("InventoryFrame")
		local scrolling = invFrame:WaitForChild("ScrollingFrame")
		local template = scrolling:WaitForChild("TemplateMaterial")
		
		template.Visible = false
		cachedContainer = scrolling
		cachedTemplate = template
		
		-- Trigger Refresh if we already have data
		if InventoryController.PlayerData and InventoryController.PlayerData.Inventory then
			InventoryController.Refresh(cachedContainer, cachedTemplate, InventoryController.PlayerData.Inventory)
		end
	end

	-- Initial Setup
	task.spawn(SetupGUI)
	
	-- Handle Reset (Respawn reloads GUI)
	player.CharacterAdded:Connect(function()
		task.wait(0.5) -- Wait for GUI to rebuild
		SetupGUI()
	end)
	
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		if not data then return end
		
		-- Partial Update Merge (Preserves FishSchool when optimized out)
		if not InventoryController.PlayerData then
			InventoryController.PlayerData = data
		else
			for k, v in pairs(data) do
				InventoryController.PlayerData[k] = v
			end
		end
		
		local pData = InventoryController.PlayerData
		if not pData.Inventory then return end
		
		-- If GUI broke or reset, try to fix refs
		if not cachedContainer or not cachedContainer.Parent then
			SetupGUI()
		end
		
		if cachedContainer and cachedTemplate then
			InventoryController.Refresh(cachedContainer, cachedTemplate, InventoryController.PlayerData.Inventory)
		end
	end)
	
	local ItemAddedEvent = Remotes:WaitForChild("ItemAddedEvent", 5)
	if ItemAddedEvent then
		ItemAddedEvent.OnClientEvent:Connect(function(itemName, amount, currency, cost, balance)
			-- Update Local Data manually to avoid full re-fetch lag
			if InventoryController.PlayerData then
				local d = InventoryController.PlayerData
				
				-- 1. Update Inventory
				if type(d.Inventory) ~= "table" then d.Inventory = {} end
				d.Inventory[itemName] = (d.Inventory[itemName] or 0) + amount
				
				-- 2. Trigger Refresh
				if cachedContainer and cachedTemplate then
					InventoryController.Refresh(cachedContainer, cachedTemplate, d.Inventory)
				end
				
				-- 3. Notify
				local NotifierController = require(script.Parent:WaitForChild("NotifierController"))
				if NotifierController then
					local color = Color3.fromRGB(255, 255, 255)
					if itemName:match("Egg") then color = Color3.fromRGB(255, 200, 50) end
					NotifierController:Notify("+" .. amount .. " " .. itemName, color)
				end
			end
		end)
	end
end

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local dragging = nil -- {Name = "Basic Egg", Element = UIElement}
local dragIcon = nil

function InventoryController.Refresh(container, template, inventoryList)
	-- Clear old (except template and layout)
	for _, child in ipairs(container:GetChildren()) do
		if child ~= template and not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
	
	-- Aggregate Items (Stacking) / Backward compatibility for partial array states optionally
	local counts = {}
	for k, v in pairs(inventoryList) do
		if type(k) == "number" then
			counts[v] = (counts[v] or 0) + 1
		else
			counts[k] = v
		end
	end
	
	-- Inject Pearls (Virtual Item)
	if InventoryController.PlayerData and InventoryController.PlayerData.Pearls and InventoryController.PlayerData.Pearls > 0 then
		counts["Pearl"] = InventoryController.PlayerData.Pearls
	end
	
	-- Create UI
	for itemId, count in pairs(counts) do
		local config = EquipmentConfig.Eggs[itemId] 
		
		if config then
			local card = template:Clone()
			card.Name = itemId
			card.Visible = true
			
			local title = card:FindFirstChild("MaterialTitle")
			local desc = card:FindFirstChild("MaterialDescription")
			local amt = card:FindFirstChild("MaterialAmount")
			local icon = card:FindFirstChild("ImageLabel")
			
			if title then title.Text = config.DisplayName or itemId end
			if desc then desc.Text = config.Description or "" end
			if amt then amt.Text = "x" .. tostring(count) end
			if icon then icon.Image = config.ImageId or "" end

			-- Check for Unique Item State (e.g. Rhythm Egg greyed out if Rhythm Fish owned)
			local isGreyed = false
			if itemId == "Rhythm Egg" then
				local school = (InventoryController.PlayerData and InventoryController.PlayerData.FishSchool) or {}
				for _, fish in pairs(school) do
					if fish.Id == "Rhythm Fish" then
						isGreyed = true
						break
					end
				end
			end

			if isGreyed then
				if icon then icon.ImageColor3 = Color3.fromRGB(100, 100, 100) end
				if title then title.TextColor3 = Color3.fromRGB(150, 150, 150) end
				if amt then amt.Text = "(Used)" end
				card.Active = false
			else
				card.Active = true
			end
			
			card.Selectable = true
			card.Parent = container
			
			-- Drag Start
			card.InputBegan:Connect(function(input)
				if isGreyed then return end -- Cannot drag greyed items
				if itemId == "Pearl" then return end -- Pearls are not draggable
				
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					if not dragging then
						InventoryController.StartDrag(itemId, icon)
					else
					end
				end
			end)
		end
	end
end

local function GetCorrectSlotColor(slotId)
	local fishSchool = (InventoryController.PlayerData and InventoryController.PlayerData.FishSchool) or {}
	
	-- Robust lookup: Check both string and number keys
	local idStr = tostring(slotId)
	local idNum = tonumber(slotId)
	
	local fishData = fishSchool[idStr] or (idNum and fishSchool[idNum])
	
	if fishData then
		local rarity = fishData.Rarity
		local rarCfg = FishConfig.Rarities[rarity]
		if rarCfg then
			return rarCfg.Color
		end
	end
	return Color3.fromRGB(163, 162, 165) -- Default Grey
end

function InventoryController.StartDrag(itemName, sourceIcon)
	local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
	local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)
	local config = EquipmentConfig.Eggs[itemName]
	
	dragging = {
		Name = itemName,
		Config = config
	}
	
	-- Create Ghost
	local player = Players.LocalPlayer
	local mouse = player:GetMouse()
	local screenGui = player.PlayerGui:FindFirstChild("Main") -- Using existing ScreenGui
	
	if not screenGui then return end
	
	dragIcon = Instance.new("ImageLabel")
	dragIcon.Size = UDim2.new(0, 60, 0, 60) -- Slightly larger for visibility
	dragIcon.Image = sourceIcon.Image
	dragIcon.BackgroundTransparency = 1
	dragIcon.ImageTransparency = 0.5
	dragIcon.AnchorPoint = Vector2.new(0.5, 0.5) -- Center pivot
	
	-- Accurate mouse location (GetMouseLocation includes TopBar, which ViewportPointToRay expects)
	local mousePos = UserInputService:GetMouseLocation()
	dragIcon.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
	dragIcon.ZIndex = 200 -- Above everything
	dragIcon.Parent = screenGui

	InventoryController.ShowSlotIndicators()
end

local activeHighlights = {} -- [SlotInstance] = Highlight (Optional outline)
local slotOriginalProps = {} -- [Part] = {Color, Material}
local lastHoveredSlot = nil

-- Helper to find which slot a part belongs to
local function FindSlotFromPart(part)
	local current = part
	while current and current ~= workspace do
		if activeHighlights[current] then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Shared logic to determine slot ID from slot object and its vertical index
local function GetSlotId(slotInstance, index)
	if not slotInstance then return nil end
	local name = slotInstance.Name
	local numericId = name:match("%d+")
	
	if not numericId then
		if name == "FishSlot" then
			numericId = "1"
		else
			numericId = tostring(index)
		end
	end
	
	-- Robust normalization: strip leading zeros (01 -> 1)
	if numericId then
		numericId = tostring(tonumber(numericId) or numericId)
	end
	
	return numericId
end

function InventoryController.DecrementLocalInventory(itemName, amount)
	local deduct = amount or 1
	if not InventoryController.PlayerData or not InventoryController.PlayerData.Inventory then return end
	
	-- Rhythm Egg is unique and persistent
	if itemName == "Rhythm Egg" then return end
	
	local inv = InventoryController.PlayerData.Inventory
	if inv[itemName] and inv[itemName] > 0 then
		inv[itemName] = inv[itemName] - deduct
		if inv[itemName] <= 0 then inv[itemName] = nil end
	else
		-- Fallback for unmigrated arrays (should not really trigger for large numbers)
		for i = 1, deduct do
			local idx = table.find(inv, itemName)
			if idx then
				table.remove(inv, idx)
			else
				break
			end
		end
	end
end

-- NEW: Robust slot detection using both Raycast and Screen-Space Proximity
local function GetSlotFromInput(mousePos)
	local cam = workspace.CurrentCamera
	
	-- Collect valid targets for raycast (Only active slots)
	local validTargets = {}
	for slot, _ in pairs(activeHighlights) do
		table.insert(validTargets, slot)
	end

	-- 1. Precision Raycast (Filter DESCENDANTS of slots only)
	if #validTargets > 0 then
		-- ViewportPointToRay expects position INCLUDING TopBar (GuiInset)
		local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = validTargets -- Only hit slots
		
		local result = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
		if result and result.Instance then
			local slot = FindSlotFromPart(result.Instance)
			if slot then
				local tank = slot:FindFirstAncestorOfClass("Model") or slot.Parent
				-- Double check ownership just in case
				if tank then -- and tank:GetAttribute("OwnerUserId") == player.UserId then -- Relaxed check
					return slot
				end
			end
		end
	end
	
	-- 2. Visual Projection (Fallback for Mobile/Obstructions or missed ray)
	-- Checks if mouse is visually over a slot center in screen space
	local AquariumController = require(script.Parent.AquariumController)
	local myTank = AquariumController.GetMyAquarium()
	if not myTank then return nil end
	
	local slotsFolder = myTank:FindFirstChild("Slots") or myTank:FindFirstChild("FishSlot") or myTank
	if slotsFolder.Name == "FishSlot" and slotsFolder.Parent ~= myTank then
		slotsFolder = slotsFolder.Parent
	end
	
	local closestSlot = nil
	local minScreenDist = 120 -- Increased from 80 for better mobile tolerance
	
	for _, slot in ipairs(slotsFolder:GetChildren()) do
		local face = slot:FindFirstChild("FishFace") or slot:FindFirstChildWhichIsA("BasePart") or slot
		local worldPos = face:IsA("BasePart") and face.Position or slot:GetPivot().Position
		
		local screenPos, onScreen = cam:WorldToScreenPoint(worldPos)
		if onScreen then
			local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
			if dist < minScreenDist then
				minScreenDist = dist
				closestSlot = slot
			end
		end
	end
	
	return closestSlot
end

function InventoryController.ShowSlotIndicators()
	local AquariumController = require(script.Parent.AquariumController)
	local myTank = AquariumController.GetMyAquarium()
	
	-- Fallback if not found by attribute
	if not myTank then
		local folder = workspace:FindFirstChild("Aquariums")
		if folder then
			for _, plot in ipairs(folder:GetChildren()) do
				local ownerPart = plot:FindFirstChild("Ownership")
				local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
				local lbl = gui and gui:FindFirstChild("TextLabel")
				if lbl and lbl.Text == Players.LocalPlayer.Name .. "'s Aquarium" then
					myTank = plot
					break
				end
			end
		end
	end

	if not myTank then return end
	
	local slotsFolder = myTank:FindFirstChild("Slots") or myTank:FindFirstChild("FishSlot") or myTank
	
	if slotsFolder.Name == "FishSlot" and slotsFolder.Parent ~= myTank then
		slotsFolder = slotsFolder.Parent
	end

	local fishSchool = (InventoryController.PlayerData and InventoryController.PlayerData.FishSchool) or {}
	local count = 0
	
	for i, slotInstance in ipairs(slotsFolder:GetChildren()) do
		local numericId = GetSlotId(slotInstance, i)
		-- Check both string and number keys for robustness
		local isOccupied = numericId and (fishSchool[numericId] ~= nil or fishSchool[tonumber(numericId)] ~= nil)
		
		-- Find the FishFace part
		local face = slotInstance:FindFirstChild("FishFace") or slotInstance:FindFirstChildWhichIsA("BasePart")
		
		if face then
			-- Store original state
			slotOriginalProps[face] = {
				Color = face.Color,
				Material = face.Material,
				SlotId = numericId
			}
			
			-- Determine validity
			local isValidTarget = false
			local itemRequiresFish = dragging and dragging.Config and dragging.Config.RequiresFish
			
			if itemRequiresFish then
				-- Mutator: Valid only if occupied
				if isOccupied then isValidTarget = true end
			else
				-- Standard Egg: Valid only if empty (normally) or occupied (replacement)
				-- Let's highlight empty ones as suggest, and occupied ones as neutral
				if not isOccupied then isValidTarget = true end
			end
			
			-- Apply Highlight Color
			if isValidTarget then
				if itemRequiresFish then
					-- face.Color = Color3.fromRGB(200, 0, 255) -- Purple for Mutators
				else
					-- face.Color = Color3.fromRGB(0, 100, 50) -- Green for Eggs
				end
			end
			
			-- Add Highlight
			if isValidTarget or (not itemRequiresFish) then -- Show highlight for everything for standard eggs so they know they CAN replace
				local highlight = Instance.new("Highlight")
				highlight.Name = "SlotHighlight"
				highlight.FillTransparency = 0.85 -- Subtle base fill
				highlight.FillColor = Color3.fromRGB(255, 255, 255)
				highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
				highlight.OutlineTransparency = 0.5
				highlight.Adornee = slotInstance
				highlight.Parent = slotInstance
				activeHighlights[slotInstance] = highlight
				count += 1
			end
			end
		end
	end

function InventoryController.HideSlotIndicators(justFilledSlotId)
	local fishSchool = (InventoryController.PlayerData and InventoryController.PlayerData.FishSchool) or {}
	
	-- Restore original colors/materials
	for part, props in pairs(slotOriginalProps) do
		if part and part.Parent then
			local id = props.SlotId
			
			part.Material = props.Material
			
			-- Use dynamic color check to handle rarity changes correctly
			local isNewlyOccupied = (id and tostring(id) == tostring(justFilledSlotId))
			if not isNewlyOccupied then
				part.Color = GetCorrectSlotColor(id)
			end
		end
	end
	slotOriginalProps = {}

	for slot, highlight in pairs(activeHighlights) do
		if highlight then highlight:Destroy() end
	end
	activeHighlights = {}
	lastHoveredSlot = nil
end

function InventoryController.UpdateDrag(input)
	if dragging and dragIcon then
		local mousePos = UserInputService:GetMouseLocation()
		dragIcon.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
		
		local hoveredNow = GetSlotFromInput(mousePos)
		
		-- Update visual feedback
		if lastHoveredSlot ~= hoveredNow then
			-- Reset old
			if lastHoveredSlot then
				local oldFace = lastHoveredSlot:FindFirstChild("FishFace") or lastHoveredSlot:FindFirstChildWhichIsA("BasePart")
				if oldFace then
					local slotId = lastHoveredSlot.Name:match("%d+")
					oldFace.Color = GetCorrectSlotColor(slotId)
				end

				if activeHighlights[lastHoveredSlot] then
					activeHighlights[lastHoveredSlot].FillTransparency = 0.7
					activeHighlights[lastHoveredSlot].FillColor = Color3.fromRGB(255, 255, 255)
					activeHighlights[lastHoveredSlot].OutlineTransparency = 0.3
				end
			end
			
			-- Highlight new
			if hoveredNow then
				local newFace = hoveredNow:FindFirstChild("FishFace") or hoveredNow:FindFirstChildWhichIsA("BasePart")
				if newFace then
					newFace.Color = Color3.fromRGB(0, 255, 0) -- Bright green as requested
				end

				if activeHighlights[hoveredNow] then
					activeHighlights[hoveredNow].FillTransparency = 0.3 -- Much more visible when active
					activeHighlights[hoveredNow].FillColor = Color3.fromRGB(0, 255, 150)
					activeHighlights[hoveredNow].OutlineTransparency = 0 -- Solid outline
				end
			end
			lastHoveredSlot = hoveredNow
		end
	end
end

function InventoryController.EndDrag(input)
	if dragging and dragIcon then
		local mousePos = UserInputService:GetMouseLocation()
		dragIcon:Destroy()
		dragIcon = nil
		
		-- Prioritize the slot that was visually highlighted to the user to prevent input errors
		local slotInstance = lastHoveredSlot
		if not slotInstance then
			slotInstance = GetSlotFromInput(mousePos)
		end
		
		-- Check aquarium hierarchy (Support Folder OR Model roots)
		local aquarium = nil
		if slotInstance then
			local current = slotInstance.Parent
			while current and current ~= workspace do
				if current.Parent == workspace:FindFirstChild("Aquariums") then
					aquarium = current -- This is the Plot (e.g. "Aquarium")
					break
				end
				current = current.Parent
			end
		end
		
		-- Support dropping non-slot items (like Sea Mines)
		local isConsumable = dragging.Config and dragging.Config.IsConsumable
		if isConsumable and not slotInstance then
			local itemName = dragging.Name
			local Remotes = ReplicatedStorage:WaitForChild("Remotes")
			local DropConsumable = Remotes:FindFirstChild("DropConsumable")
			if DropConsumable then
				local success, res = DropConsumable:InvokeServer(itemName)
				if success then
					InventoryController.DecrementLocalInventory(itemName)
				else
					warn("InventoryController: Drop failed - " .. tostring(res))
				end
			end
			InventoryController.HideSlotIndicators()
			dragging = nil
			return
		end

		if slotInstance and aquarium then
			local itemName = dragging.Name
			
			-- Calculate Slot ID using shared helper
			local slotsContainer = slotInstance.Parent
			local indexHint = 1
			if slotsContainer then
				for idx, child in ipairs(slotsContainer:GetChildren()) do
					if child == slotInstance then indexHint = idx break end
				end
			end
			local targetNumericId = GetSlotId(slotInstance, indexHint)
			
			local function proceedHatch(feedAmount)
				local feedCount = tonumber(feedAmount) or 1
				local Remotes = ReplicatedStorage:WaitForChild("Remotes")
				local ProcessEggDrop = Remotes:WaitForChild("ProcessEggDrop")
				local success, res = ProcessEggDrop:InvokeServer(aquarium, itemName, targetNumericId, feedCount)
				
				if success then
					task.spawn(InventoryController.PlayHatchAnimation, slotInstance)
					
					-- Directly subtract chunked amount 
					InventoryController.DecrementLocalInventory(itemName, feedCount)
					
					InventoryController.ShowHatchedUI(res, itemName, targetNumericId, aquarium, feedCount)
				else
					warn("InventoryController: Hatch failed - " .. tostring(res))
				end
			end
			
			local fishSchool = (InventoryController.PlayerData and InventoryController.PlayerData.FishSchool) or {}
			local occupiedValue = fishSchool[tostring(targetNumericId)] or fishSchool[tonumber(targetNumericId)]

			-- Fallback: If data is out of sync but visual model exists, treat as occupied (client-side prediction)
			if not occupiedValue and slotInstance then
				local hasModel = slotInstance:FindFirstChild("Model") or slotInstance:FindFirstChild("FishDisplay")
				if hasModel then occupiedValue = {Id = "Unknown"} end
			end
			
			local itemRequiresFish = dragging.Config and dragging.Config.RequiresFish
			local isFeed = dragging.Config and dragging.Config.IsFeed
			
			if isFeed then
				if not occupiedValue then
					warn("InventoryController: This item requires an existing fish!")
					InventoryController.HideSlotIndicators()
					dragging = nil
					return
				else
					InventoryController.ShowFeedConfirmation(itemName, occupiedValue, proceedHatch)
				end
			elseif itemRequiresFish then
				if not occupiedValue then
					-- Cannot use on empty slot
					warn("InventoryController: This item requires an existing fish!")
					InventoryController.HideSlotIndicators()
					dragging = nil
					return
				else
					InventoryController.ShowConfirmation("Use this item on this fish?", proceedHatch)
				end
			else
				-- Standard Egg behavior
				if occupiedValue then
					InventoryController.ShowConfirmation("Replace existing fish?", proceedHatch)
				else
					local displayName = dragging.Config and dragging.Config.DisplayName or itemName
					InventoryController.ShowConfirmation("Hatch " .. displayName .. "?", proceedHatch)
				end
			end
			
			-- Cleanup visual indicators immediately since drag is effectively over (waiting for confirmation)
			InventoryController.HideSlotIndicators()
		else
			print("EndDrag: Drop failed. Slot:", slotInstance and slotInstance.Name or "nil", "Aquarium:", aquarium and aquarium.Name or "nil")
			InventoryController.HideSlotIndicators()
		end
		
		dragging = nil
	end
end

-- Global Input Hooks
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		InventoryController.UpdateDrag(input)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		InventoryController.EndDrag(input)
	end
end)

function InventoryController.PlayHatchAnimation(slotInstance)
	-- Removed part animation
end

function InventoryController.ShowHatchedUI(fishData, lastItemName, lastSlotId, lastAquarium, feedCount)
	feedCount = tonumber(feedCount) or 1
	local player = Players.LocalPlayer
	local mainGui = player.PlayerGui:FindFirstChild("Main")
	if not mainGui then return end

	local hatchFrame = mainGui:FindFirstChild("FishOpen")
	if not hatchFrame then
		warn("InventoryController: FishOpen frame not found in Main GUI!")
		return
	end

	-- 1. Setup Text: "You got a [FishName]!"
	local youGotFrame = hatchFrame:FindFirstChild("YouGotFrame")
	local youGotText = youGotFrame and youGotFrame:FindFirstChild("YouGotText")
	
	local itemCfg = EquipmentConfig.Eggs[lastItemName]
	local isFeed = itemCfg and itemCfg.IsFeed

	if youGotText then
		if isFeed then
			youGotText.Text = "You fed " .. fishData.Name .. "!"
		else
			youGotText.Text = "You got a " .. fishData.Name .. "!"
		end
		
		-- Color by rarity? Optional polish
		local rarityColor = FishConfig.Rarities[fishData.Rarity] and FishConfig.Rarities[fishData.Rarity].Color or Color3.new(1,1,1)
		youGotText.TextColor3 = rarityColor
		
		-- Special Rarity SFX
		if not isFeed then
			local sfxFolder = ReplicatedStorage:FindFirstChild("SFX")
			if sfxFolder then
				if fishData.Rarity == "Mythic" then
					local msfx = sfxFolder:FindFirstChild("OpeningMythic")
					if msfx then
						local s = msfx:Clone()
						s.Parent = workspace
						s:Play()
						game.Debris:AddItem(s, 5)
					end
				elseif fishData.Rarity == "Legendary" then
					local lsfx = sfxFolder:FindFirstChild("OpeningLegendary")
					if lsfx then
						local s = lsfx:Clone()
						s.Parent = workspace
						s:Play()
						game.Debris:AddItem(s, 5)
					end
				end
			end
		end
	end

	-- 2. Setup Description
	local fishCfg = FishConfig.Fish[fishData.Id]
	local descFrame = hatchFrame:FindFirstChild("DescriptionFrame")
	local descText = descFrame and descFrame:FindFirstChild("DescriptionText")
	if descText then
		if isFeed then
			descText.Text = "They gained " .. (1000 * feedCount) .. " XP!"
		else
			descText.Text = fishCfg and fishCfg.Description or "No description available."
		end
	end

	-- 3. New Frame Logic
	local newFrame = hatchFrame:FindFirstChild("NewFrame")
	if newFrame then
		newFrame.Visible = (fishData.IsNew == true)
	end

	-- 4. 3D Render (ViewportFrame)
	local imageFrame = hatchFrame:FindFirstChild("ImageFrame")
	if imageFrame then
		-- Clear old content
		for _, child in ipairs(imageFrame:GetChildren()) do
			if child:IsA("ViewportFrame") then child:Destroy() end
		end

		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.new(1, 0, 1, 0)
		vp.BackgroundTransparency = 1
		vp.Parent = imageFrame
		
		-- Setup Camera
		local camera = Instance.new("Camera")
		vp.CurrentCamera = camera
		camera.Parent = vp
		
		-- Get Model
		local FishModels = ReplicatedStorage:WaitForChild("Fishes")
		local modelTemplate = fishCfg and FishModels:FindFirstChild(fishCfg.ModelName or "Basic Fish")
		
		if modelTemplate then
			local model = modelTemplate:Clone()
			model.Parent = vp
			
			-- Position Model
			local cf, size = model:GetBoundingBox()
			
			-- Move model to origin BUT preserve its source orientation
			-- The source models in ReplicatedStorage are assumed to be oriented correctly relative to each other.
			
			local currentRotation = cf - cf.Position -- Extract rotation only
			local desiredOffset = CFrame.Angles(0, math.rad(240), 0)
			
			-- Reset to 0,0,0 but keep rotation, then apply offset
			local finalCF = CFrame.new(0, 0, 0) * currentRotation * desiredOffset
			
			if model.PrimaryPart then
				model:SetPrimaryPartCFrame(finalCF)
			else
				model:PivotTo(finalCF)
			end
			
			-- Position Camera to fit
			local maxDim = math.max(size.X, size.Y, size.Z)
			local dist = maxDim * 1.1 -- Distance factor (1.0 might be too close for some)
			camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, dist), Vector3.new(0, 0, 0))
		end
	end

	-- 5. Animations (Pop & Wobble)
	-- Cleanup previous loop
	if InventoryController.HatchAnimConn then 
		InventoryController.HatchAnimConn:Disconnect()
		InventoryController.HatchAnimConn = nil
	end
	
	-- Pop Effect (Using UIScale)
	local uiScale = hatchFrame:FindFirstChild("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = hatchFrame
	end
	
	-- Ensure centered pivot for rotation/scaling
	hatchFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	hatchFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	uiScale.Scale = 0
	game:GetService("TweenService"):Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Scale = 1}):Play()
	
	-- Wobble Loop (Dynamic idle)
	local animStart = os.clock()
	InventoryController.HatchAnimConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - animStart
		-- Gentle sine wave rotation
		local rot = math.sin(t * 2) * 2 -- +/- 2 degrees
		hatchFrame.Rotation = rot
	end)

	-- 6. Close Button
	local confirmContainer = hatchFrame:FindFirstChild("Confirm")
	local confirmBtn = confirmContainer and confirmContainer:FindFirstChild("ConfirmButton")
	
	if confirmBtn then
		if InventoryController.CloseBtnConn then InventoryController.CloseBtnConn:Disconnect() end
		
		InventoryController.CloseBtnConn = confirmBtn.MouseButton1Click:Connect(function()
			hatchFrame.Visible = false
			if InventoryController.HatchAnimConn then 
				InventoryController.HatchAnimConn:Disconnect()
				InventoryController.HatchAnimConn = nil
			end
		end)
	end

	-- 7. Use Again Logic (UseAgain Frame)
	local useAgainFrame = hatchFrame:FindFirstChild("UseAgain")
	if useAgainFrame then
		local shouldShow = false
		local remainingCount = 0
		

		-- Logic: Show if we have more
		if InventoryController.PlayerData and InventoryController.PlayerData.Inventory then
			for _, item in ipairs(InventoryController.PlayerData.Inventory) do
				if item == lastItemName then remainingCount += 1 end
			end
		end
		
		-- We used one, so check if we have any left
		if remainingCount > 0 then shouldShow = true end
		
		if shouldShow then
			useAgainFrame.Visible = true
			local btn = useAgainFrame:FindFirstChild("ConfirmButton")
			
			if btn then
				-- Cleanup old connection
				if InventoryController.UseAgainConn then InventoryController.UseAgainConn:Disconnect() end
				
				InventoryController.UseAgainConn = btn.MouseButton1Click:Connect(function()
					-- Guard: disconnect immediately so rapid clicks can't re-trigger
					if InventoryController.UseAgainConn then
						InventoryController.UseAgainConn:Disconnect()
						InventoryController.UseAgainConn = nil
					end
					-- Call Server
					local Remotes = ReplicatedStorage:WaitForChild("Remotes")
					local ProcessEggDrop = Remotes:WaitForChild("ProcessEggDrop")
					local success, res = ProcessEggDrop:InvokeServer(lastAquarium, lastItemName, lastSlotId)
					
					if success then
						task.spawn(function()
							InventoryController.DecrementLocalInventory(lastItemName)
							InventoryController.ShowHatchedUI(res, lastItemName, lastSlotId, lastAquarium)
						end)
					else
						warn("InventoryController: Use Again failed - " .. tostring(res))
						useAgainFrame.Visible = false
					end
				end)
			end
		else
			useAgainFrame.Visible = false
		end
	end

	hatchFrame.Visible = true
end

local confirmationConnections = {}

function InventoryController.ShowConfirmation(message, onConfirm)
	local player = Players.LocalPlayer
	local mainGui = player.PlayerGui:FindFirstChild("Main")
	if not mainGui then return end

	local confirmFrame = mainGui:FindFirstChild("Confirmation")
	if not confirmFrame then
		warn("InventoryController: Confirmation frame not found in Main GUI! Ensure it is named 'Confirmation'.")
		return 
	end

	-- Cleanup old connections to prevent duplicate firing
	for _, conn in ipairs(confirmationConnections) do
		conn:Disconnect()
	end
	confirmationConnections = {}

	-- Setup Text
	local txtFrame = confirmFrame:FindFirstChild("ConfirmationTextFrame")
	local txtLabel = txtFrame and txtFrame:FindFirstChild("ConfirmationText")
	if txtLabel then
		txtLabel.Text = message
	else
		warn("InventoryController: ConfirmationText not found")
	end

	-- Setup Buttons
	local function close()
		confirmFrame.Visible = false
		if InventoryController.ConfirmAnimConn then 
			InventoryController.ConfirmAnimConn:Disconnect()
			InventoryController.ConfirmAnimConn = nil
		end
	end

	-- Hierarchy: Confirmation -> Confirm -> ConfirmButton
	local confirmContainer = confirmFrame:FindFirstChild("Confirm")
	local yesBtn = confirmContainer and confirmContainer:FindFirstChild("ConfirmButton")

	-- Hierarchy: Confirmation -> Deny -> DenyButton
	local denyContainer = confirmFrame:FindFirstChild("Deny")
	local noBtn = denyContainer and denyContainer:FindFirstChild("DenyButton")

	if yesBtn then
		local c = yesBtn.MouseButton1Click:Connect(function()
			close()
			if onConfirm then onConfirm() end
		end)
		table.insert(confirmationConnections, c)
	else
		warn("InventoryController: ConfirmButton not found")
	end

	if noBtn then
		local c = noBtn.MouseButton1Click:Connect(function()
			close()
		end)
		table.insert(confirmationConnections, c)
	else
		warn("InventoryController: DenyButton not found")
	end

	-- Animation (Pop & Wobble)
	if InventoryController.ConfirmAnimConn then 
		InventoryController.ConfirmAnimConn:Disconnect()
		InventoryController.ConfirmAnimConn = nil
	end

	local uiScale = confirmFrame:FindFirstChild("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = confirmFrame
	end
	
	confirmFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	confirmFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	uiScale.Scale = 0
	game:GetService("TweenService"):Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Scale = 1}):Play()
	
	local animStart = os.clock()
	InventoryController.ConfirmAnimConn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - animStart
		confirmFrame.Rotation = math.sin(t * 2) * 2
	end)

	confirmFrame.ZIndex = 2000 -- Ensure it's above interaction prompts
	confirmFrame.Visible = true
end

local feedConnections = {}

function InventoryController.ShowFeedConfirmation(itemName, occupiedValue, onConfirm)
	local player = Players.LocalPlayer
	local mainGui = player.PlayerGui:FindFirstChild("Main")
	if not mainGui then return end

	local feedFrame = mainGui:FindFirstChild("MultipleUseFrame")
	if not feedFrame then
		warn("InventoryController: MultipleUseFrame not found!")
		-- Fallback if frame isn't added to Main GUI yet
		InventoryController.ShowConfirmation("Use this item on this fish?", function() onConfirm(1) end)
		return 
	end

	-- Cleanup old connections
	for _, conn in ipairs(feedConnections) do
		conn:Disconnect()
	end
	feedConnections = {}
	
	-- Calculate available treats
	local availableTreats = 0
	if InventoryController.PlayerData and InventoryController.PlayerData.Inventory then
	    availableTreats = InventoryController.PlayerData.Inventory[itemName] or 0
	end
	
	-- Calculate required for next level
	local level = occupiedValue.Level or 1
	local currentExp = occupiedValue.Exp or 0
	local maxExp = math.floor(25 * math.pow(3, level - 1))
	local neededExp = math.max(1, maxExp - currentExp)
	local feedNeeded = math.ceil(neededExp / 1000)
	
	local function close()
		feedFrame.Visible = false
		if InventoryController.FeedAnimConn then 
			InventoryController.FeedAnimConn:Disconnect()
			InventoryController.FeedAnimConn = nil
		end
	end
	
	-- Setup UI Pointers
	local enter1 = feedFrame:FindFirstChild("Enter1")
	local enter2 = feedFrame:FindFirstChild("Enter2")
	local enter3 = feedFrame:FindFirstChild("Enter3")
	local feedBtn = feedFrame:FindFirstChild("Feed")
	local denyBtn = feedFrame:FindFirstChild("Deny")
	local textBox = feedFrame:FindFirstChild("TextBox")
	
	if textBox then 
		textBox.Text = "1" 
		table.insert(feedConnections, textBox.FocusLost:Connect(function()
			local num = tonumber(textBox.Text)
			if not num then
				textBox.Text = "1"
			else
				num = math.floor(num)
				if num > availableTreats then num = availableTreats end
				if num < 1 then num = 1 end
				textBox.Text = tostring(num)
			end
		end))
	end
	if enter1 then
	    local bBtn = enter1:FindFirstChild("ConfirmButton")
	    if bBtn then
	        table.insert(feedConnections, bBtn.MouseButton1Click:Connect(function()
	            if textBox then textBox.Text = "1" end
	        end))
	    end
	end
	
	if enter2 then
	    local bTxt = enter2:FindFirstChild("ButtonText")
	    local bBtn = enter2:FindFirstChild("ConfirmButton")
	    if bTxt then
	        bTxt.Text = "Feed Until Next Level (" .. feedNeeded .. " treats)"
	    end
	    if bBtn then
	        if availableTreats < feedNeeded then
	            table.insert(feedConnections, bBtn.MouseButton1Click:Connect(function()
	                -- Disabled, do nothing
	            end))
	        else
	            table.insert(feedConnections, bBtn.MouseButton1Click:Connect(function()
	                if textBox then textBox.Text = tostring(feedNeeded) end
	            end))
	        end
	    end
	end
	
	if enter3 then
	    local bTxt = enter3:FindFirstChild("ButtonText")
	    local bBtn = enter3:FindFirstChild("ConfirmButton")
	    if bTxt then bTxt.Text = "Feed All (" .. availableTreats .. " treats)" end
	    if bBtn then
	        table.insert(feedConnections, bBtn.MouseButton1Click:Connect(function()
	            if textBox then textBox.Text = tostring(availableTreats) end
	        end))
	    end
	end
	
	if feedBtn then
	    local fBtn = feedBtn:FindFirstChild("ConfirmButton")
	    if fBtn then
	        table.insert(feedConnections, fBtn.MouseButton1Click:Connect(function()
	            local amount = 1
	            if textBox then amount = tonumber(textBox.Text) or 1 end
	            if amount > availableTreats then amount = availableTreats end
	            if amount < 1 then amount = 1 end
	            close()
	            if onConfirm then onConfirm(amount) end
	        end))
	    end
	end
	
	if denyBtn then
	    local dBtn = denyBtn:FindFirstChild("DenyButton") or denyBtn:FindFirstChild("ConfirmButton") or denyBtn
	    if dBtn:IsA("GuiButton") or dBtn:FindFirstChildWhichIsA("GuiButton") then
	        local actualBtn = dBtn:IsA("GuiButton") and dBtn or dBtn:FindFirstChildWhichIsA("GuiButton")
	        table.insert(feedConnections, actualBtn.MouseButton1Click:Connect(function()
	            close()
	        end))
	    end
	end
	
	-- Animation (Pop & Wobble)
	if InventoryController.FeedAnimConn then 
		InventoryController.FeedAnimConn:Disconnect()
		InventoryController.FeedAnimConn = nil
	end

	local uiScale = feedFrame:FindFirstChild("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = feedFrame
	end
	
	feedFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	feedFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	
	uiScale.Scale = 0
	game:GetService("TweenService"):Create(uiScale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Scale = 1}):Play()
	
	local animStart = os.clock()
	InventoryController.FeedAnimConn = game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock() - animStart
		feedFrame.Rotation = math.sin(t * 2) * 2
	end)

	feedFrame.ZIndex = 2000 
	feedFrame.Visible = true
end

return InventoryController
