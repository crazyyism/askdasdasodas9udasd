local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TutorialController = {}
local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")

local localData = nil
local currentStep = 0

local tutorialDialogue = nil
local tutorialLabel = nil
local currentTypewriterThread = nil

local currentBeam = nil
local attPlayer = nil
local attTarget = nil

-- Listen to DataUpdateEvent to sync local state
DataUpdateEvent.OnClientEvent:Connect(function(data)
	if not localData then
		localData = data
	else
		for k, v in pairs(data) do
			localData[k] = v
		end
	end
end)

local function shouldBypassTutorial()
	if not localData then 
		print("[Tutorial Debug] localData is nil, bypass = false")
		return false 
	end
	if localData.TutorialCompleted == true then 
		print("[Tutorial Debug] TutorialCompleted is true, bypass = true")
		return true 
	end
	
	-- Check for returning player progress that indicates they are way past the tutorial:
	
	-- 1. If they have completed any quest OTHER than FreshwaterCleaning
	if localData.CompletedQuests then
		for qId, _ in pairs(localData.CompletedQuests) do
			if qId ~= "FreshwaterCleaning" then
				print("[Tutorial Debug] Player has completed advanced quests, bypass = true")
				return true
			end
		end
	end
	
	-- 2. If they have unlocked tools other than starter Net and tutorial Scissors
	if localData.UnlockedTools then
		for _, tool in ipairs(localData.UnlockedTools) do
			if tool ~= "Fishing Net" and tool ~= "Scissors" then
				print("[Tutorial Debug] Player has advanced tools, bypass = true")
				return true
			end
		end
	end
	
	-- 3. If they have unlocked backpacks other than the starter Pouch
	if localData.UnlockedBackpacks then
		for _, bp in ipairs(localData.UnlockedBackpacks) do
			if bp ~= "Pouch" then
				print("[Tutorial Debug] Player has advanced backpacks, bypass = true")
				return true
			end
		end
	end
	
	-- 4. If they have Scissors and have completed FreshwaterCleaning
	local hasScissors = localData.UnlockedTools and table.find(localData.UnlockedTools, "Scissors") ~= nil
	local hasCompletedQuest = localData.CompletedQuests and localData.CompletedQuests["FreshwaterCleaning"] ~= nil
	if hasScissors and hasCompletedQuest then
		print("[Tutorial Debug] Player finished tutorial objectives, bypass = true")
		return true
	end
	
	-- 5. If they have high Biomass (meaning they played beyond the start)
	if (localData.Biomass or 0) > 1500 then
		print("[Tutorial Debug] Player has high Biomass, bypass = true")
		return true
	end

	print("[Tutorial Debug] No bypass conditions met, bypass = false")
	return false
end

local function setupTutorialUI()
	if tutorialDialogue then return end
	
	local playerGui = player:WaitForChild("PlayerGui")
	local main = playerGui:WaitForChild("Main")
	tutorialDialogue = main:WaitForChild("TutorialDialogue")
	
	tutorialDialogue.Visible = true
	
	local questGiverName = tutorialDialogue:WaitForChild("QuestGiverName")
	questGiverName.Text = "Tutorial"
	
	local confirmationTextFrame = tutorialDialogue:WaitForChild("ConfirmationTextFrame")
	tutorialLabel = confirmationTextFrame:WaitForChild("ConfirmationText")
end

local function playTypewriter(textLabel, text)
	if currentTypewriterThread then
		task.cancel(currentTypewriterThread)
		currentTypewriterThread = nil
	end
	
	textLabel.MaxVisibleGraphemes = 0
	textLabel.Text = text
	
	currentTypewriterThread = task.spawn(function()
		local length = utf8.len(text) or #text
		for i = 1, length do
			textLabel.MaxVisibleGraphemes = i
			task.wait(0.02)
		end
		textLabel.MaxVisibleGraphemes = -1 -- Show everything at the end
		currentTypewriterThread = nil
	end)
end

local function updateText(text)
	setupTutorialUI()
	if tutorialLabel then
		playTypewriter(tutorialLabel, text)
	end
end

local function destroyTutorialUI()
	if currentTypewriterThread then
		task.cancel(currentTypewriterThread)
		currentTypewriterThread = nil
	end
	if tutorialDialogue then
		tutorialDialogue.Visible = false
		tutorialDialogue = nil
		tutorialLabel = nil
	end
end

local function clearBeam()
	if currentBeam then currentBeam:Destroy() currentBeam = nil end
	if attPlayer then attPlayer:Destroy() attPlayer = nil end
	if attTarget then attTarget:Destroy() attTarget = nil end
end

local function createBeam(targetPart)
	clearBeam()
	if not targetPart or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
	
	local root = player.Character.HumanoidRootPart
	attPlayer = Instance.new("Attachment")
	attPlayer.Name = "TutorialAttPlayer"
	attPlayer.Parent = root
	
	attTarget = Instance.new("Attachment")
	attTarget.Name = "TutorialAttTarget"
	attTarget.Parent = targetPart
	
	currentBeam = Instance.new("Beam")
	currentBeam.Name = "TutorialBeam"
	currentBeam.Attachment0 = attPlayer
	currentBeam.Attachment1 = attTarget
	currentBeam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
	currentBeam.LightInfluence = 0
	currentBeam.LightEmission = 0.8
	currentBeam.Width0 = 0.5
	currentBeam.Width1 = 0.5
	currentBeam.FaceCamera = true
	currentBeam.TextureSpeed = 2
	currentBeam.Parent = root
end

local function createHighlight(element)
	if not element then return nil end
	
	local highlight = Instance.new("Frame")
	highlight.Name = "TutorialHighlight"
	highlight.Size = UDim2.new(1.1, 0, 1.1, 0)
	highlight.Position = UDim2.new(-0.05, 0, -0.05, 0)
	highlight.BackgroundTransparency = 0.95
	highlight.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	highlight.BorderSizePixel = 0
	highlight.ZIndex = element.ZIndex + 5
	
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = highlight
	
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(255, 215, 0)
	uiStroke.Thickness = 3
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.Parent = highlight
	
	highlight.Parent = element
	
	-- Pulsate border transparency via UIStroke
	task.spawn(function()
		local t = 0
		while highlight and highlight.Parent and uiStroke and uiStroke.Parent do
			local transparency = 0.4 + math.sin(t * 5) * 0.3
			highlight.BackgroundTransparency = 0.9 + math.sin(t * 5) * 0.05
			uiStroke.Transparency = transparency
			t = t + 0.05
			task.wait(0.05)
		end
	end)
	
	return highlight
end

local function findClosestUnclaimedAquarium()
	local folder = workspace:FindFirstChild("Aquariums")
	if not folder then return nil end
	
	local char = player.Character
	if not char or not char.PrimaryPart then return nil end
	local playerPos = char.PrimaryPart.Position
	
	local closest = nil
	local minDist = math.huge
	
	for _, plot in ipairs(folder:GetChildren()) do
		local ownerId = plot:GetAttribute("OwnerUserId")
		local isUnclaimed = (ownerId == nil or ownerId == 0)
		
		if not isUnclaimed then
			local ownerPart = plot:FindFirstChild("Ownership")
			local gui = ownerPart and ownerPart:FindFirstChild("SurfaceGui")
			local lbl = gui and gui:FindFirstChild("TextLabel")
			if lbl and lbl.Text == "Unclaimed" then
				isUnclaimed = true
			end
		end
		
		if isUnclaimed then
			local rootPart = (plot:IsA("Model") and plot.PrimaryPart) or plot:FindFirstChild("Ownership") or plot:FindFirstChildWhichIsA("BasePart")
			if rootPart then
				local dist = (rootPart.Position - playerPos).Magnitude
				if dist < minDist then
					minDist = dist
					closest = rootPart
				end
			end
		end
	end
	
	return closest
end

local function findElderTurtleRoot()
	local elder = workspace:FindFirstChild("Elder Turtle") or workspace:FindFirstChild("QuestGiver") or workspace:FindFirstChild("QuestGiver1")
	if elder then
		return elder:FindFirstChild("Platform") or elder:FindFirstChild("platform") or elder.PrimaryPart or elder:FindFirstChildWhichIsA("BasePart")
	end
	
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		local e = npcs:FindFirstChild("Elder Turtle") or npcs:FindFirstChild("QuestGiver")
		if e then
			return e:FindFirstChild("Platform") or e:FindFirstChild("platform") or e.PrimaryPart or e:FindFirstChildWhichIsA("BasePart")
		end
	end
	return nil
end

local function findFieldPart(fieldName)
	local folder = workspace:FindFirstChild(fieldName)
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("BasePart") then
				return child
			end
		end
		if folder:IsA("Model") and folder.PrimaryPart then
			return folder.PrimaryPart
		end
	end
	return nil
end

local function findNoobShopPart()
	for _, child in ipairs(workspace:GetChildren()) do
		local name = child.Name
		local isNoobShop = (name == "NoobShop") or (name:lower():match("shop") and name:lower():match("noob"))
		if isNoobShop then
			local platform = child:FindFirstChild("Platform", true) or child:FindFirstChild("platform", true) or child:FindFirstChildWhichIsA("BasePart", true)
			if platform then return platform end
		end
	end
	
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		for _, child in ipairs(npcs:GetChildren()) do
			local name = child.Name
			local isNoobShop = (name == "NoobShop") or (name:lower():match("shop") and name:lower():match("noob"))
			if isNoobShop then
				local platform = child:FindFirstChild("Platform", true) or child:FindFirstChild("platform", true) or child:FindFirstChildWhichIsA("BasePart", true)
				if platform then return platform end
			end
		end
	end
	return nil
end

function TutorialController.Start()
	print("[Tutorial Debug] TutorialController Starting...")
	
	task.spawn(function()
		-- 1. Wait for player character, data, and wait until the loading screen is fully gone
		print("[Tutorial Debug] Waiting for player character and HumanoidRootPart...")
		while not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") do task.wait(0.5) end
		print("[Tutorial Debug] Character ready. Waiting for localData...")
		while not localData do task.wait(0.5) end
		
		print("[Tutorial Debug] localData loaded. Waiting 2.0 second buffer for replication and UI setup...")
		task.wait(2.0)
		
		-- 2. Bypass check
		print("[Tutorial Debug] Running shouldBypassTutorial check...")
		if shouldBypassTutorial() then
			print("[Tutorial Debug] Tutorial bypassed for returning player.")
			local CompleteTutorial = Remotes:FindFirstChild("CompleteTutorial")
			if CompleteTutorial then
				CompleteTutorial:FireServer()
			end
			return
		end
		
		print("[Tutorial Debug] Tutorial active: beginning sequence.")
		
		-- Connect char added callback to recreate beams if player dies
		player.CharacterAdded:Connect(function(char)
			print("[Tutorial Debug] Character respawned during tutorial. Recreating active elements...")
			task.wait(0.5)
			if currentStep == 1 then
				local target = findClosestUnclaimedAquarium()
				if target then createBeam(target) end
			elseif currentStep == 4 or currentStep == 6 then
				local target = findElderTurtleRoot()
				if target then createBeam(target) end
			elseif currentStep == 5 then
				local target = findFieldPart("Freshwater Reef")
				if target then createBeam(target) end
			elseif currentStep == 8 then
				local target = findNoobShopPart()
				if target then createBeam(target) end
			end
		end)
		
		-- STEP 1: Claim Aquarium
		currentStep = 1
		print("[Tutorial Debug] Starting Step 1: Claim Aquarium")
		setupTutorialUI()
		
		local closest = findClosestUnclaimedAquarium()
		if closest then 
			print("[Tutorial Debug] Directing player to closest unclaimed aquarium: " .. closest.Parent.Name)
			createBeam(closest) 
		else
			warn("[Tutorial Debug] No unclaimed aquarium found in the workspace!")
		end
		updateText("Welcome to Fish Hatchery! Follow the blue beam to claim your aquarium.")
		
		local AquariumController = require(script.Parent.AquariumController)
		while not AquariumController.GetMyAquarium() do
			local currentClosest = findClosestUnclaimedAquarium()
			if currentClosest and (not attTarget or attTarget.Parent ~= currentClosest) then
				print("[Tutorial Debug] Closest unclaimed aquarium changed to: " .. currentClosest.Parent.Name .. ". Redirecting beam.")
				createBeam(currentClosest)
			end
			task.wait(1)
		end
		
		print("[Tutorial Debug] Step 1 Complete: Aquarium claimed! Clearing beam.")
		clearBeam()
		
		-- STEP 2: Highlight Inventory Icon & STEP 3: Highlight Basic Egg Slot
		currentStep = 2
		print("[Tutorial Debug] Starting Step 2 & 3: Open Inventory and Hatch Basic Egg")
		local HUDController = require(script.Parent.HUDController)
		
		local mainGui = player.PlayerGui:WaitForChild("Main")
		local mainFrame = mainGui:WaitForChild("Main")
		local btnHolders = mainFrame:WaitForChild("ButtonHolders")
		local invBtn = btnHolders:WaitForChild("Inventory")
		
		local invFrame = player.PlayerGui:FindFirstChild("InventoryFrame", true)
		if not invFrame then
			invFrame = mainGui:WaitForChild("InventoryFrame", 10)
		end
		local scrollingFrame = invFrame:WaitForChild("ScrollingFrame")
		
		local eggHighlight = nil
		local invHighlight = nil
		local lastText = nil
		
		while true do
			local active = (HUDController.ActiveFrame == "Inventory")
			local targetText = ""
			
			if active then
				if invHighlight then 
					print("[Tutorial Debug] Inventory opened. Destroying button highlight.")
					invHighlight:Destroy() 
					invHighlight = nil 
				end
				local eggSlot = scrollingFrame:FindFirstChild("Basic Egg")
				if eggSlot and not eggHighlight then
					print("[Tutorial Debug] Creating highlight on Basic Egg slot.")
					eggHighlight = createHighlight(eggSlot)
				end
				targetText = "Drag the Basic Egg listed in your inventory to any empty slot."
			else
				if eggHighlight then 
					print("[Tutorial Debug] Inventory closed. Destroying egg slot highlight.")
					eggHighlight:Destroy() 
					eggHighlight = nil 
				end
				if not invHighlight then
					print("[Tutorial Debug] Creating highlight on Inventory button.")
					invHighlight = createHighlight(invBtn)
				end
				targetText = "Open your inventory by clicking the Inventory icon on the left."
			end
			
			if targetText ~= lastText then
				lastText = targetText
				updateText(targetText)
			end
			
			-- Exit step once they hatch a fish
			local school = localData and localData.FishSchool
			if school and next(school) then
				print("[Tutorial Debug] Detected fish in school!")
				break
			end
			task.wait(0.2)
		end
		
		print("[Tutorial Debug] Step 2 & 3 Complete: Fish hatched! Clearing highlights.")
		if eggHighlight then eggHighlight:Destroy() end
		if invHighlight then invHighlight:Destroy() end
		
		-- STEP 4: Guide to Quest Giver (Elder Turtle)
		currentStep = 4
		print("[Tutorial Debug] Starting Step 4: Guide to Quest Giver (Elder Turtle)")
		local elderRoot = findElderTurtleRoot()
		if elderRoot then
			print("[Tutorial Debug] Spawning beam pointing to Elder Turtle.")
			createBeam(elderRoot)
		else
			warn("[Tutorial Debug] Elder Turtle platform could not be resolved in the workspace!")
		end
		updateText("Your first egg has hatched. Now follow the blue beam to talk to the Elder Turtle for your first quest.")
		
		while true do
			if localData and (localData.ActiveQuests["FreshwaterCleaning"] or localData.CompletedQuests["FreshwaterCleaning"]) then
				print("[Tutorial Debug] Detected quest 'FreshwaterCleaning' has been accepted/completed.")
				break
			end
			task.wait(0.5)
		end
		
		print("[Tutorial Debug] Step 4 Complete: Quest accepted! Clearing beam.")
		clearBeam()
		
		-- STEP 5: Harvest Quest Algae
		currentStep = 5
		print("[Tutorial Debug] Starting Step 5: Harvest Quest Algae")
		local freshwaterReefPart = findFieldPart("Freshwater Reef")
		if freshwaterReefPart then
			print("[Tutorial Debug] Spawning beam pointing to Freshwater Reef.")
			createBeam(freshwaterReefPart)
		else
			warn("[Tutorial Debug] Freshwater Reef platform could not be resolved in the workspace!")
		end
		updateText("Elder Turtle has asked to collect 200 algae from the Freshwater Reef. Follow the blue beam to complete the quest. Pressing your screen will harvest algae, and your fish will help you collect some too!")
		
		while true do
			local completed = localData and localData.CompletedQuests and localData.CompletedQuests["FreshwaterCleaning"] ~= nil
			local progress = localData and localData.ActiveQuests and localData.ActiveQuests["FreshwaterCleaning"]
			local hasEnough = progress and type(progress) == "number" and progress >= 200
			
			if completed or hasEnough then
				print("[Tutorial Debug] Completed quest or gathered 200+ algae.")
				break
			end
			task.wait(0.5)
		end
		
		print("[Tutorial Debug] Step 5 Complete: Algae gathered! Clearing beam.")
		clearBeam()
		
		-- STEP 6: Return to Elder Turtle (Turn In Quest)
		currentStep = 6
		print("[Tutorial Debug] Starting Step 6: Return to Elder Turtle (Turn In Quest)")
		if elderRoot then
			print("[Tutorial Debug] Spawning beam pointing to Elder Turtle.")
			createBeam(elderRoot)
		else
			warn("[Tutorial Debug] Elder Turtle platform could not be resolved in the workspace!")
		end
		updateText("You collected enough Algae! Return to the Elder Turtle to continue along with the game.")
		
		while true do
			if localData and localData.CompletedQuests and localData.CompletedQuests["FreshwaterCleaning"] ~= nil then
				print("[Tutorial Debug] Detected quest 'FreshwaterCleaning' has been completed.")
				break
			end
			task.wait(0.5)
		end
		
		print("[Tutorial Debug] Step 6 Complete: Quest turned in! Clearing beam.")
		clearBeam()
		
		-- STEP 7: Accumulate 900 Biomass
		currentStep = 7
		print("[Tutorial Debug] Starting Step 7: Accumulate 900 Biomass")
		local lastGuideState = nil -- nil, "harvest", "convert"
		
		while true do
			local currentBiomass = localData and localData.Biomass or 0
			if currentBiomass >= 900 then
				break
			end
			
			-- Check backpack capacity
			local totalAlgae = 0
			if localData and localData.Plankton then
				for _, amt in pairs(localData.Plankton) do totalAlgae += amt end
			end
			local maxCap = localData and localData.MaxCapacity or 200
			
			-- If backpack is almost full, or they already have some algae and are close to 900 total if converted, guide to converter
			local hasEnoughToConvert = (totalAlgae >= maxCap * 0.8) or (currentBiomass + totalAlgae >= 900)
			
			if hasEnoughToConvert then
				if lastGuideState ~= "convert" then
					lastGuideState = "convert"
					local myAq = AquariumController.GetMyAquarium()
					local spawnPart = myAq and myAq:FindFirstChild("Spawn")
					if spawnPart then
						print("[Tutorial Debug] Backpack full/sufficient, pointing to Aquarium converter.")
						createBeam(spawnPart)
						updateText("Your backpack is filling up! Go to your Aquarium to convert your Algae into Biomass!")
					else
						warn("[Tutorial Debug] Aquarium Spawn not found for converter step!")
					end
				end
			else
				if lastGuideState ~= "harvest" then
					lastGuideState = "harvest"
					local reefPart = findFieldPart("Freshwater Reef")
					if reefPart then
						print("[Tutorial Debug] Backpack has space, pointing to Freshwater Reef.")
						createBeam(reefPart)
						updateText("Harvest Algae in the Freshwater Reef to gather more resources! You need 900 Biomass.")
					else
						warn("[Tutorial Debug] Freshwater Reef part not found for harvesting step!")
					end
				end
			end
			task.wait(1.0)
		end
		
		print("[Tutorial Debug] Step 7 Complete: Replaced 900+ Biomass! Clearing beam.")
		clearBeam()
		
		-- STEP 8: Buy Scissors
		currentStep = 8
		print("[Tutorial Debug] Starting Step 8: Buy Scissors from Noob Shop")
		local shopPart = findNoobShopPart()
		if shopPart then
			print("[Tutorial Debug] Spawning beam pointing to Noob Shop.")
			createBeam(shopPart)
		else
			warn("[Tutorial Debug] Noob Shop platform could not be resolved in the workspace!")
		end
		updateText("Nice! Now head to the Noob Shop and purchase the Scissors for 900 Biomass!")
		
		while true do
			if localData and localData.UnlockedTools and table.find(localData.UnlockedTools, "Scissors") then
				print("[Tutorial Debug] Scissors unlocked!")
				break
			end
			task.wait(0.5)
		end
		
		print("[Tutorial Debug] Step 8 Complete: Scissors purchased! Clearing beam.")
		clearBeam()
		
		-- STEP 9: Done!
		currentStep = 9
		print("[Tutorial Debug] Starting Step 9: Completion")
		updateText("Yay! You completed the tutorial!!! There is much to offer in this game, look around for loot, progress further to unlock some insane stuff, and just have fun! :)))")
		
		local CompleteTutorial = Remotes:FindFirstChild("CompleteTutorial")
		if CompleteTutorial then
			print("[Tutorial Debug] Firing CompleteTutorial remote event to the server.")
			CompleteTutorial:FireServer()
		end
		
		task.wait(13)
		print("[Tutorial Debug] Destroying Tutorial GUI.")
		destroyTutorialUI()
	end)
end

return TutorialController
