local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local AquariumController = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClaimAquarium = Remotes:WaitForChild("ClaimAquarium")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")

local player = Players.LocalPlayer
local canClaim = false
local claimTarget = nil
local playerData = nil
local interactionDebounce = false

local FishConfig = require(ReplicatedStorage.Shared.FishConfig)

-- Shared logic to determine slot ID from slot object
local function GetSlotId(slotInstance)
	if not slotInstance then return nil end
	local name = slotInstance.Name
	local numericId = name:match("%d+")
	
	if not numericId and name == "FishSlot" then
		numericId = "1"
	end
	
	-- Robust normalization: strip leading zeros (01 -> 1)
	if numericId then
		numericId = tostring(tonumber(numericId) or numericId)
	end
	
	return numericId
end

function AquariumController.UpdateSlotColors(data)
	if not data or not data.FishSchool then return end
	
	local tank = AquariumController.GetMyAquarium()
	if not tank then return end
	
	local slotsContainer = tank:FindFirstChild("Slots") or tank:FindFirstChild("FishSlot") or tank
	if slotsContainer.Name == "FishSlot" and slotsContainer.Parent ~= tank then
		slotsContainer = slotsContainer.Parent
	end
	
	local fishSchool = data.FishSchool
	
	for _, slotInstance in ipairs(slotsContainer:GetChildren()) do
		local numericId = GetSlotId(slotInstance)
		
		if numericId then
			local fishData = fishSchool[tostring(numericId)] or fishSchool[tonumber(numericId)]
			local face = slotInstance:FindFirstChild("FishFace") or slotInstance:FindFirstChildWhichIsA("BasePart")
			
			if face then
				if fishData then
					-- Occupied: Set to Rarity Color
					local speciesId = fishData.Id
					local config = FishConfig.Fish[speciesId]
					if config and config.Rarity then
						local rData = FishConfig.Rarities[config.Rarity]
						if rData and rData.Color then
							face.Color = rData.Color
						else
							face.Color = Color3.new(1,1,1) -- Default
						end
					end
					
					-- Update Level Text on FishFace if it exists
					local levelGui = face:FindFirstChild("Level")
					if levelGui then
						local txt = levelGui:FindFirstChild("LevelText")
						if txt then
							txt.Text = tostring(math.max(1, fishData.Level or 1)) -- Ensure valid number
						end
					end
				else
					-- Empty: Reset
					face.Color = Color3.fromRGB(163, 162, 165) -- Default Grey
					
					-- Hide or Clear Level Text
					local levelGui = face:FindFirstChild("Level")
					if levelGui then
						local txt = levelGui:FindFirstChild("LevelText")
						if txt then txt.Text = "" end
					end
				end
			end
		end
	end
end

-- Listen for data updates to track IsConverting state
DataUpdateEvent.OnClientEvent:Connect(function(data)
	if not data then return end
	
	-- Partial Update Merge (Preserves FishSchool when optimized out)
	if not playerData then
		playerData = data
	else
		for k, v in pairs(data) do
			playerData[k] = v
		end
	end
	
	AquariumController.UpdateSlotColors(playerData)
end)

local function Abbreviate(n)
	if n < 1000 then return tostring(math.floor(n + 0.5)) end
	local suffixes = {"K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc"}
	local i = math.floor(math.log10(n) / 3)
	local val = n / (10 ^ (i * 3))
	local suffix = suffixes[i] or ""
	return string.format("%.1f%s", val, suffix):gsub("%.0", "")
end

local function FormatNumber(n, forceAbbreviate)
    if forceAbbreviate then return Abbreviate(n) end
	return tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function AquariumController.Start()
	local interactionFrame, keybindLabel, actionLabel
	local upgradeFrame, upgradeKeybindLabel, upgradeActionLabel
	local handleAquariumInteraction
	local handleUpgradeInteraction
	
	local function SetupUI()
		local playerGui = player:WaitForChild("PlayerGui", 10)
		if not playerGui then return end
		local mainGui = playerGui:WaitForChild("Main", 10)
		if not mainGui then return end
		
		interactionFrame = mainGui:WaitForChild("Interaction", 10)
		if interactionFrame then
			keybindLabel = interactionFrame:WaitForChild("Keybind", 5)
			actionLabel = interactionFrame:WaitForChild("InteractionType", 5)
			interactionFrame.Visible = false
			
			-- Create Upgrade Frame
			if not mainGui:FindFirstChild("UpgradeInteraction") then
				upgradeFrame = interactionFrame:Clone()
				upgradeFrame.Name = "UpgradeInteraction"
				upgradeFrame.Parent = mainGui
				
				-- Add a UIScale to make it smaller
				local scale = Instance.new("UIScale")
				scale.Scale = 0.85
				scale.Parent = upgradeFrame
				
				-- Adjust Y position to sit above the existing frame
				-- Default position logic usually sets UDim2 based on WorldToScreenPoint
				-- We will offset the Y manually in the RenderStepped loop
			else
				upgradeFrame = mainGui:FindFirstChild("UpgradeInteraction")
			end
			
			if upgradeFrame then
				upgradeKeybindLabel = upgradeFrame:WaitForChild("Keybind", 5)
				upgradeActionLabel = upgradeFrame:WaitForChild("InteractionType", 5)
				upgradeFrame.Visible = false
				
				local upgradeButton = upgradeFrame:FindFirstChild("InteractionAction") or upgradeFrame:FindFirstChild("InteractionButton")
				if upgradeButton and (upgradeButton:IsA("TextButton") or upgradeButton:IsA("ImageButton")) then
					local function onUpgradeActivated()
						if handleUpgradeInteraction then handleUpgradeInteraction() end
						
						local originalColor = upgradeButton.BackgroundColor3
						upgradeButton.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
						task.delay(0.1, function()
							upgradeButton.BackgroundColor3 = originalColor
						end)
					end
					
					upgradeButton.Activated:Connect(onUpgradeActivated)
				end
			end
			
			-- Rebind Interaction Actions (Click/Tap)
			local interactionButton = interactionFrame:FindFirstChild("InteractionAction") or interactionFrame:FindFirstChild("InteractionButton")
			if interactionButton and (interactionButton:IsA("TextButton") or interactionButton:IsA("ImageButton")) then
				local function onActivated()
					handleAquariumInteraction()
					
					-- Visual Feedback
					local originalColor = interactionButton.BackgroundColor3
					interactionButton.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
					task.delay(0.1, function()
						interactionButton.BackgroundColor3 = originalColor
					end)
				end

				interactionButton.Activated:Connect(onActivated)
				
				-- Extra responsiveness for Touch/Touchpad (Filtered by Slot Logic)
				interactionButton.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
						-- Defer to let the Slot Click logic run first? Or check here?
						-- The Slot Click logic is in UserInputService.InputBegan which runs parallel/before GUI usually?
						-- Actually, GUI sinks input if Active=true.
						-- Let's just rely on Activated for the button, and handle slot clicking separately.
						-- But user said "tapping on fish slots shouldn't make your weapon go off". 
						-- That likely refers to the TOOL (ToolController/Weapon).
						-- Wait, "weapon go off"? This implies the player is holding a tool.
						onActivated()
					end
				end)
			end
		end
	end
	
	task.spawn(SetupUI)
	
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		SetupUI()
	end)
	
	RunService.Heartbeat:Connect(function()
		-- Verify UI exists
		if not interactionFrame or not keybindLabel or not actionLabel then return end
		
		-- Detect if on "Spawn" part
		-- Find nearest Aquarium Spawn
		local char = player.Character
		if not char or not char.PrimaryPart then return end
		
		local root = char.PrimaryPart.Position
		local aquariums = workspace:WaitForChild("Aquariums"):GetChildren()
		
		local nearest = nil
		local dist = 8 -- Interaction Radius
		
		for _, plot in ipairs(aquariums) do
			local spawnPart = plot:FindFirstChild("Spawn")
			if spawnPart then
				local d = (spawnPart.Position - root).Magnitude
				if d < dist then
					dist = d
					nearest = plot
				end
			end
		end
		
		if nearest then
			local ownerPart = nearest:FindFirstChild("Ownership")
			local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
			local lbl = gui and gui:FindFirstChild("TextLabel")
			
			local expected = player.Name .. "'s Aquarium"
			
			-- Check if this is the player's aquarium
				if lbl and lbl.Text == expected then
				canClaim = true
				claimTarget = nearest
				interactionFrame.Visible = true
				keybindLabel.Text = "E"
				
				if playerData and playerData.IsConverting then
					actionLabel.Text = "Cancel Convert"
				else
					actionLabel.Text = "Convert At Aquarium"
				end
				
				-- Dynamic Positioning Logic for Owned
				local spawnPart = nearest:FindFirstChild("Spawn")
				if spawnPart then
					local cam = workspace.CurrentCamera
					local worldPos = spawnPart.Position + Vector3.new(0, 5, 0)
					local vector, onScreen = cam:WorldToScreenPoint(worldPos)
					
					if onScreen then
						local currentPos = interactionFrame.Position
						local targetPos = UDim2.new(0, vector.X, 0, vector.Y)
						interactionFrame.Position = currentPos:Lerp(targetPos, 0.2)
						
						-- Upgrade Frame Logic
						if upgradeFrame then
							upgradeFrame.Visible = true
							upgradeKeybindLabel.Text = "F"
							local currentLevel = (playerData and playerData.AquariumLevel) or 0
							local cost = 2500 * math.pow(2, currentLevel)
							local useAbbr = playerData and playerData.Settings and playerData.Settings.AbbreviateAlgae
							
							local currentMult = math.pow(1.5, currentLevel)
							local nextMult = math.pow(1.5, currentLevel + 1)
							local currentStr = string.format("%.2f", currentMult):gsub("%.?0+$", "") .. "x"
							local nextStr = string.format("%.2f", nextMult):gsub("%.?0+$", "") .. "x"
							
							upgradeActionLabel.Text = "Upgrade Convert Rate (" .. currentStr .. " -> " .. nextStr .. ") [Cost: " .. FormatNumber(cost, useAbbr) .. "]"
							
							local upgCurrentPos = upgradeFrame.Position
							local upgTargetPos = UDim2.new(0, vector.X, 0, vector.Y - 75) -- 75 pixels above (higher to avoid clipping)
							upgradeFrame.Position = upgCurrentPos:Lerp(upgTargetPos, 0.2)
						end
					else
						interactionFrame.Visible = false
						if upgradeFrame then upgradeFrame.Visible = false end
					end
				end

			elseif lbl and lbl.Text == "Unclaimed" then
				canClaim = true
				claimTarget = nearest
				interactionFrame.Visible = true
				if upgradeFrame then upgradeFrame.Visible = false end
				keybindLabel.Text = "E"
				actionLabel.Text = "Claim Aquarium"
				
				local spawnPart = nearest:FindFirstChild("Spawn")
				if spawnPart then
					local cam = workspace.CurrentCamera
					local worldPos = spawnPart.Position + Vector3.new(0, 5, 0)
					local vector, onScreen = cam:WorldToScreenPoint(worldPos)
					
					if onScreen then
						local currentPos = interactionFrame.Position
						local targetPos = UDim2.new(0, vector.X, 0, vector.Y)
						interactionFrame.Position = currentPos:Lerp(targetPos, 0.2)
					else
						interactionFrame.Visible = false
					end
				end
				
			else
				-- Owned by someone else OR invalid state -> Hide and Ignore
				canClaim = false
				claimTarget = nil
				if upgradeFrame then upgradeFrame.Visible = false end
				if not actionLabel.Text:match("Shop") and not actionLabel.Text:match("Talk") and not actionLabel.Text:match("Cannon") and not actionLabel.Text:match("Machine") then
					interactionFrame.Visible = false
				end
			end
		else
			-- IMPORTANT: Reset state when no nearest found
			canClaim = false
			claimTarget = nil
			if upgradeFrame then upgradeFrame.Visible = false end
			
			-- Only hide if WE owns it (check text) or if it's generic
			-- Prevents hiding Shop interaction
			if not actionLabel.Text:match("Shop") and not actionLabel.Text:match("Talk") and not actionLabel.Text:match("Cannon") and not actionLabel.Text:match("Machine") then
				interactionFrame.Visible = false
			end
		end
	end)
	
	-- Shared interaction logic (for both E key and click/tap)
	handleAquariumInteraction = function()
		-- Check debounce
		if interactionDebounce then 
			print("Please wait before interacting again")
			return 
		end
		
		if canClaim and claimTarget then
			-- Set debounce
			interactionDebounce = true
			
			-- Check if this is a conversion or claim action
			local ownerPart = claimTarget:FindFirstChild("Ownership")
			local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
			local lbl = gui and gui:FindFirstChild("TextLabel")
			local expected = player.Name .. "'s Aquarium"
			
			if lbl and lbl.Text == expected then
				-- Get or create ConversionControl RemoteEvent
				local ConversionControl = Remotes:FindFirstChild("ConversionControl")
				if not ConversionControl then
					ConversionControl = Instance.new("RemoteEvent")
					ConversionControl.Name = "ConversionControl"
					ConversionControl.Parent = Remotes
				end
				
				-- Check if canceling or starting conversion
				if playerData and playerData.IsConverting then
					-- Cancel Conversion
					ConversionControl:FireServer("stop")
					print("Cancelled conversion")
				else
					-- Start Conversion
					ConversionControl:FireServer("start", claimTarget)
					print("Started conversion at aquarium")
				end
			else
				-- Claim Aquarium
				local success, msg = ClaimAquarium:InvokeServer(claimTarget)
				if success then
					print("Claimed!")
					
					-- Request data sync to spawn fish now that we have a tank
					local RequestData = Remotes:FindFirstChild("RequestData")
					if RequestData then RequestData:FireServer() end
				else
					warn("Failed: " .. msg)
				end
			end
			
			-- Reset debounce after short cooldown
			task.delay(0.3, function()
				interactionDebounce = false
			end)
		end
	end
	
	handleUpgradeInteraction = function()
		if interactionDebounce then return end
		if canClaim and claimTarget then
			local ownerPart = claimTarget:FindFirstChild("Ownership")
			local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
			local lbl = gui and gui:FindFirstChild("TextLabel")
			local expected = player.Name .. "'s Aquarium"
			
			if lbl and lbl.Text == expected then
				interactionDebounce = true
				
				local UpgradeAquarium = Remotes:FindFirstChild("UpgradeAquarium")
				if UpgradeAquarium then
					local success, msg = UpgradeAquarium:InvokeServer(claimTarget)
					if success then
						print("Upgraded to level: " .. tostring(msg))
					else
						warn("Failed to upgrade: " .. tostring(msg))
					end
				end
				
				task.delay(0.3, function()
					interactionDebounce = false
				end)
			end
		end
	end
	
	-- Slot Click Persistence: Detect clicks even if GPE is true for non-interactive elements?
	-- For now, let's keep GPE but increase accuracy.
	UserInputService.InputBegan:Connect(function(input, gpe)
		local isClick = (input.UserInputType == Enum.UserInputType.MouseButton1)
		local isTouch = (input.UserInputType == Enum.UserInputType.Touch)
		
		if input.KeyCode == Enum.KeyCode.E then
			if gpe then return end
			handleAquariumInteraction()
		elseif input.KeyCode == Enum.KeyCode.F then
			if gpe then return end
			if upgradeFrame and upgradeFrame.Visible then
				handleUpgradeInteraction()
			end
		elseif isClick or isTouch then
			-- If gpe is true, it might be a button click. We usually want buttons to block slot clicks.
			if gpe then return end 
			
			-- Slot Click Logic
			local cam = workspace.CurrentCamera
			local mousePos = UserInputService:GetMouseLocation()
			local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
			
			local aqFolder = workspace:FindFirstChild("Aquariums")
			if not aqFolder then return end
			
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = {aqFolder}
			
			-- Increased distance to 500
			local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
			if result and result.Instance then
				local hit = result.Instance
				
				local function FindSlot(part)
					local current = part
					while current and current ~= workspace do
						if current.Name:match("FishSlot") or current.Name:match("%d+") then
							return current
						end
						current = current.Parent
					end
					return nil
				end
				
				local slot = FindSlot(hit)
				if slot then
					-- Guard: only open info if this slot belongs to the local player's aquarium
					local plotModel = slot
					while plotModel and plotModel.Parent and plotModel.Parent ~= aqFolder do
						plotModel = plotModel.Parent
					end
					local isMyPlot = false
					if plotModel and plotModel.Parent == aqFolder then
						if plotModel:GetAttribute("OwnerUserId") == player.UserId then
							isMyPlot = true
						else
							local ownerPart = plotModel:FindFirstChild("Ownership")
							local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
							local lbl = gui and gui:FindFirstChild("TextLabel")
							if lbl and lbl.Text == player.Name .. "'s Aquarium" then
								isMyPlot = true
							end
						end
					end

					if isMyPlot then
						local slotId = GetSlotId(slot)
						if slotId and playerData and playerData.FishSchool then
							local fishData = playerData.FishSchool[tostring(slotId)] or playerData.FishSchool[tonumber(slotId)]
							if fishData then
								AquariumController.OpenFishInfo(slotId)
							end
						end
					end
				end
			end
		end
	end)
end

local FishInfoLoop = nil

function AquariumController.OpenFishInfo(slotId)
	local mainGui = player.PlayerGui:WaitForChild("Main")
	local infoFrame = mainGui:FindFirstChild("FishInfo")
	if not infoFrame then return end
	
	-- Get initial data for static fields (Name, Desc, Rarity)
	local fishData = playerData.FishSchool[tostring(slotId)] or playerData.FishSchool[tonumber(slotId)]
	if not fishData then return end
	
	local config = FishConfig.Fish[fishData.Id]
	if not config then return end
	
	-- Animation: Reset Scale
	local uiScale = infoFrame:FindFirstChild("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Name = "UIScale"
		uiScale.Parent = infoFrame
	end
	
	-- Cancel any ongoing close animations to prevent race conditions
	if AquariumController._ActiveCloseTween then
		AquariumController._ActiveCloseTween:Cancel()
		AquariumController._ActiveCloseTween = nil
	end
	
	uiScale.Scale = 0
	infoFrame.Visible = true
	
	local TweenService = game:GetService("TweenService")
	TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	
	-- Close Button
	local closeBtn = infoFrame:FindFirstChild("Close")
	if closeBtn then
		local btn = closeBtn:FindFirstChild("CloseButton")
		if btn then
			-- Disconnect previous connections using module-level storage
			if AquariumController._SubmitCloseConn then 
				AquariumController._SubmitCloseConn:Disconnect() 
				AquariumController._SubmitCloseConn = nil
			end
			
			AquariumController._SubmitCloseConn = btn.MouseButton1Click:Connect(function()
				-- Animate Out
				local tw = TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0})
				AquariumController._ActiveCloseTween = tw
				tw:Play()
				
				tw.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Completed then
						infoFrame.Visible = false
						if FishInfoLoop then FishInfoLoop:Disconnect() FishInfoLoop = nil end
					end
					if AquariumController._ActiveCloseTween == tw then
						AquariumController._ActiveCloseTween = nil
					end
				end)
			end)
		end
	end
	
	-- 1. Name & Desc (Static)
	local nameFrame = infoFrame:FindFirstChild("FishName")
	if nameFrame then
		local txt = nameFrame:FindFirstChild("Name") or nameFrame:FindFirstChild("FishName")
		if txt then 
			txt.Text = fishData.Name or config.Name
			txt.TextColor3 = Color3.new(1,1,1)
		end
	end
	
	-- Rarity Text Logic (Static)
	local rarityFrame = infoFrame:FindFirstChild("FishRarity")
	if rarityFrame then
		local txt = rarityFrame:FindFirstChild("Rarity") or rarityFrame:FindFirstChild("TextLabel")
		if txt then
			local rarity = config.Rarity or "Common"
			local colorTrait = config.ColorTrait or "Colorless"
			
			txt.Text = colorTrait .. " " .. rarity
			
			if colorTrait == "Orange" then
				txt.TextColor3 = Color3.fromRGB(255, 150, 0)
			elseif colorTrait == "Pink" then
				txt.TextColor3 = Color3.fromRGB(255, 100, 200)
			elseif colorTrait == "Green" then
				txt.TextColor3 = Color3.fromRGB(100, 255, 100)
			else
				txt.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end
	
	local descFrame = infoFrame:FindFirstChild("DescriptionFrame")
	if descFrame then
		local txt = descFrame:FindFirstChild("DescriptionText")
		if txt then txt.Text = config.Description or "" end
	end
	
	-- 4. Viewport (Static Init)
	local imageFrame = infoFrame:FindFirstChild("ImageFrame")
	local m = nil
	local finalCF = nil
	if imageFrame then
		-- Clear old
		for _, c in ipairs(imageFrame:GetChildren()) do
			if c:IsA("ViewportFrame") then c:Destroy() end
		end
		
		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.new(1, 0, 1, 0)
		vp.BackgroundTransparency = 1
		vp.Parent = imageFrame
		
		local cam = Instance.new("Camera")
		vp.CurrentCamera = cam
		cam.Parent = vp
		
		local FishModels = ReplicatedStorage:WaitForChild("Fishes")
		local templateM = FishModels:FindFirstChild(config.ModelName or "Basic Fish")
		
		if templateM then
			m = templateM:Clone()
			m.Parent = vp
			
			local cf, size = m:GetBoundingBox()
			local currentRotation = cf - cf.Position
			local desiredOffset = CFrame.Angles(0, math.rad(240), 0)
			finalCF = CFrame.new(0, 0, 0) * currentRotation * desiredOffset
			
			if m.PrimaryPart then
				m:SetPrimaryPartCFrame(finalCF)
			else
				m:PivotTo(finalCF)
			end
			
			local maxDim = math.max(size.X, size.Y, size.Z)
			local dist = maxDim * 1.2
			cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, dist), Vector3.new(0, 0, 0))
		end
	end

	-- LOOP FOR REAL-TIME UPDATES
	if FishInfoLoop then FishInfoLoop:Disconnect() end
	local seed = math.random(1, 10000)
	
	FishInfoLoop = RunService.RenderStepped:Connect(function()
		if not infoFrame.Visible then 
			if FishInfoLoop then FishInfoLoop:Disconnect() FishInfoLoop = nil end
			return 
		end
		
		-- Fetch LATEST data
		local fishSchool = playerData and playerData.FishSchool
		if not fishSchool then return end
		
		local currentData = fishSchool[tostring(slotId)] or fishSchool[tonumber(slotId)]
		if not currentData then return end
		
		-- 1. XP & Level Update
		local level = currentData.Level or 1
		local currentExp = currentData.Exp or 0
		local maxExp = math.floor(25 * math.pow(3, level - 1))
		
		local levelFrame = infoFrame:FindFirstChild("Level")
		if levelFrame then
			local txt = levelFrame:FindFirstChild("LevelText")
			if txt then txt.Text = tostring(level) end
		end
		
		local xpFrame = infoFrame:FindFirstChild("XPProgress")
		if xpFrame then
			local txt = xpFrame:FindFirstChild("XPProgressText") or infoFrame:FindFirstChild("XPProgressText")
			if txt then 
				txt.Text = math.floor(currentExp) .. " / " .. maxExp .. " XP" 
			end
			
			local bar = xpFrame:FindFirstChild("Progress")
			if bar then
				-- Using user's desired constraints from manual edit
				local pct = math.min(currentExp / maxExp, 0.878)
				bar.Size = UDim2.new(pct, 0, 0.45, 0)
			end
		end
		
		-- 2. Stats Update
		local statsFrame = infoFrame:FindFirstChild("FishStats")
		if statsFrame then
			local baseStats = config.BaseStats or {}
			local multGather = 1 + 0.15 * (level - 1) -- 15% Linear
			local multMove = 1 + 0.05 * (level - 1) -- 5% Linear (Unchanged)
			local multConvert = 1.1 ^ (level - 1) -- 10% Exponential!
			
			local s_ga = math.floor((baseStats.GatherAmount or 0) * multGather)
			local s_ms = math.floor((baseStats.MoveSpeed or 0) * multMove)
			local s_ca = math.floor((baseStats.ConvertAmount or 0) * multConvert)
			
			local t_ga = statsFrame:FindFirstChild("GatherAmount")
			local t_gs = statsFrame:FindFirstChild("GatherSpeed")
			local t_ms = statsFrame:FindFirstChild("MoveSpeed")
			local t_ca = statsFrame:FindFirstChild("ConvertAmount")
			local t_cs = statsFrame:FindFirstChild("ConvertSpeed")
			local t_fa = statsFrame:FindFirstChild("FishAttack")
			local t_fas = statsFrame:FindFirstChild("FishAttackSpeed")
			
			if t_ga then t_ga.Text = "Gather Amount: " .. s_ga end
			if t_gs then t_gs.Text = "Gather Speed: " .. (baseStats.GatherSpeed or 0) .. "s" end
			if t_ms then t_ms.Text = "Move Speed: " .. s_ms end
			if t_ca then t_ca.Text = "Convert Amount: " .. s_ca end
			if t_cs then t_cs.Text = "Convert Speed: " .. (baseStats.ConvertSpeed or 0) .. "s" end
			if t_fa then t_fa.Text = "Attack: " .. (baseStats.Attack or 0) end
			if t_fas then t_fas.Text = "Attack Speed: " .. (baseStats.AttackSpeed or 0) .. "s" end
		end
		
		-- 3. Viewport Animation
		if m and m.Parent then
			local t = os.clock()
			local speed = 0.8
			local amp = 0.5
			local dx = math.noise(t * speed, seed, 0) * amp
			local dy = math.noise(t * speed, seed, 100) * amp
			local dz = math.noise(t * speed, seed, 200) * amp
			local swayX = math.rad(math.sin(t * 1.5) * 5)
			local swayZ = math.rad(math.cos(t * 1.2) * 3)
			local offsetCF = CFrame.new(dx, dy, dz) * CFrame.Angles(swayX, 0, swayZ)
			
			if m.PrimaryPart then
				m:SetPrimaryPartCFrame(finalCF * offsetCF)
			else
				m:PivotTo(finalCF * offsetCF)
			end
		end
	end)
end

function AquariumController.GetMyAquarium()
	local folder = workspace:FindFirstChild("Aquariums")
	if not folder then return nil end
	
	local aquariums = folder:GetChildren()
	for _, plot in ipairs(aquariums) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	
	-- Fallback for legacy support if needed (or if replication is slow)
	for _, plot in ipairs(aquariums) do
		local ownerPart = plot:FindFirstChild("Ownership")
		if ownerPart then
			local gui = ownerPart:FindFirstChild("SurfaceGui")
			if gui then
				local lbl = gui:FindFirstChild("TextLabel")
				local expected = player.Name .. "'s Aquarium"
				if lbl and lbl.Text == expected then
					return plot
				end
			end
		end
	end
	return nil
end

return AquariumController
