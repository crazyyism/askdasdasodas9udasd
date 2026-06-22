local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local DialogueConfig = require(ReplicatedStorage.Shared.DialogueConfig)
local QuestConfig = require(ReplicatedStorage.Shared.QuestConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)
local BackpackConfig = {}
for k, v in pairs(EquipmentConfig) do
	if v.ProductType == "Backpack" then
		BackpackConfig[v.BackpackId or k] = v
	end
end
local NotifierController = require(script.Parent:WaitForChild("NotifierController"))

local QuestController = {}

local player = Players.LocalPlayer
local interactionDebounce = false
local isQuestInteractable = false
local currentDialogueIndex = 1
local dialogueActive = false
local isInitialized = false -- Track first load

-- Quest State
local activeQuests = {}
local completedQuests = {}
local alreadyNotifiedQuests = {} -- Session-based duplicate prevention
local lastPlanktonState = {}
local questIndicatorInstance = nil

local QUEST_CHAIN = QuestConfig.QuestChain

-- UI References
local interactionFrame, keybindLabel, actionLabel
local questUi, questNameLabel, questTextLabel, questSkipBtn
local questFrame, questScroll, questTemplate
local questsButton

-- Forward declaration for interaction handler
local handleQuestInteraction

-- Remotes
local DataUpdateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DataUpdateEvent")

-- Data Listener for Progress
local localData = nil

local function PlaySFX(soundInstance, fallbackId)
	local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
	if isSfxDisabled then return end

	local sound = nil
	if soundInstance and soundInstance:IsA("Sound") then
		sound = soundInstance:Clone()
	elseif fallbackId then
		sound = Instance.new("Sound")
		sound.SoundId = fallbackId
		sound.Volume = 0.5
	end

	if sound then
		sound.Parent = game:GetService("SoundService")
		sound:Play()
		local length = sound.TimeLength > 0 and sound.TimeLength or 2
		game:GetService("Debris"):AddItem(sound, length + 0.5)
	end
end

local function NotifyQuestCompletion(qId)
	local qConfig = QuestConfig.Quests[qId]
	local qName = qConfig and qConfig.Name or qId
	NotifierController:Notify("Quest Completed: " .. qName .. "!", Color3.fromRGB(255, 215, 0))
	
	-- Notify Rewards
	if qConfig and qConfig.Rewards then
		if qConfig.Rewards.BiomassAmount then
			NotifierController:Notify("Received " .. qConfig.Rewards.BiomassAmount .. " Biomass", Color3.fromRGB(0, 255, 255))
		end
		if qConfig.Rewards.Items then
			-- Deduplicate and Count
			local counts = {}
			local order = {} -- maintain order
			
			for k, v in pairs(qConfig.Rewards.Items) do
				local item, amount
				if type(k) == "number" then
					item = v
					amount = 1
				else
					item = k
					amount = v
				end

				if not counts[item] then
					counts[item] = 0
					table.insert(order, item)
				end
				counts[item] += amount
			end
			
			for _, item in ipairs(order) do
				local c = counts[item]
				if c > 1 then
					NotifierController:Notify("Received " .. c .. "x " .. item, Color3.fromRGB(0, 255, 0))
				else
					NotifierController:Notify("Received " .. item, Color3.fromRGB(0, 255, 0))
				end
			end
		end
	end
	-- Play SFX (Quest Finish)
	local finishGoalSfx = ReplicatedStorage:FindFirstChild("SFX") and ReplicatedStorage.SFX:FindFirstChild("Quest") and ReplicatedStorage.SFX.Quest:FindFirstChild("FinishGoal")
	PlaySFX(finishGoalSfx, "rbxassetid://9086152864")
end

-- Data Listener for Progress
DataUpdateEvent.OnClientEvent:Connect(function(data)
	local oldNoobieStats = localData and localData.NoobieTurtleQuestsCompleted or 0
	
	-- Merge Data (Handle Partials)
	if not localData then
		localData = data
	else
		for k, v in pairs(data) do
			localData[k] = v 
		end
	end
	
	-- Check Completions
	local newCompleted = data.CompletedQuests or {}
	
	if isInitialized then
		for qId, _ in pairs(newCompleted) do
			if not completedQuests[qId] and not alreadyNotifiedQuests[qId] then
				alreadyNotifiedQuests[qId] = true
				NotifyQuestCompletion(qId)
			end
		end
		
		if data.NoobieTurtleQuestsCompleted and data.NoobieTurtleQuestsCompleted > oldNoobieStats then
			NotifyQuestCompletion("NoobieTurtle")
		end
		
		local oldLavaStats = localData and localData.LavaTurtleQuestsCompleted or 0
		if data.LavaTurtleQuestsCompleted and data.LavaTurtleQuestsCompleted > oldLavaStats then
			NotifyQuestCompletion("LavaTurtle")
			NotifierController:Notify("Permanent Buff Gained: 1x Lava Enhancement!", Color3.fromRGB(255, 69, 0))
		end
	end
	
	-- Update Persistent State from MERGED data
	if localData.CompletedQuests then
		completedQuests = localData.CompletedQuests
	end
	
	-- Sync alreadyNotifiedQuests to keep it clean?
	-- Actually, removing it caused duplicate notifications if the server sends a packet where the quest is briefly missing or if race conditions occur.
	-- It is safer to NEVER clear this flag for the session unless we explicitly handle a "Quest Reset" event.
	-- for k, _ in pairs(alreadyNotifiedQuests) do
	-- 	if not completedQuests[k] then
	-- 		alreadyNotifiedQuests[k] = nil
	-- 	end
	-- end
	
	-- Update NoobieTurtle Quest (pass stored progress to lock in the assigned field)
	local fishCount = 0
	if localData.FishSchool then
		for _, _ in pairs(localData.FishSchool) do fishCount = fishCount + 1 end
	end
	local noobieProg = localData.ActiveQuests and localData.ActiveQuests["NoobieTurtle"]
	QuestConfig.UpdateNoobieTurtle(localData.NoobieTurtleQuestsCompleted or 0, fishCount, player.UserId, noobieProg)
	DialogueConfig["NoobieTurtle_Start"] = QuestConfig.Dialogue["NoobieTurtle_Start"]
	DialogueConfig["NoobieTurtle_InProgress"] = QuestConfig.Dialogue["NoobieTurtle_InProgress"]
	DialogueConfig["NoobieTurtle_Complete"] = QuestConfig.Dialogue["NoobieTurtle_Complete"]
	
	-- Sync Quests from Server Data
	if data.ActiveQuests then
		local anyChanges = false
		local oldQuests = activeQuests
		activeQuests = {}
		
		for qId, prog in pairs(data.ActiveQuests) do
			activeQuests[qId] = prog
			
			local oldProg = oldQuests[qId]
			local shouldUpdate = false
			
			-- Check for changes in progress to avoid continuous redraws
			if type(prog) == "table" then
				if type(oldProg) ~= "table" then 
					shouldUpdate = true 
				else
					for k, v in pairs(prog) do
						if oldProg[k] ~= v then shouldUpdate = true break end
					end
				end
			else
				if oldProg ~= prog then shouldUpdate = true end
			end
			
			-- Handle Brand New Quests Only
			if isInitialized and oldProg == nil then
				shouldUpdate = true
				local qName = QuestConfig.Quests[qId] and QuestConfig.Quests[qId].Name or qId
				NotifierController:Notify("Quest Received: " .. qName, Color3.fromRGB(0, 191, 255))
				
				local receiveSfx = ReplicatedStorage:FindFirstChild("SFX") and ReplicatedStorage.SFX:FindFirstChild("Quest") and (ReplicatedStorage.SFX.Quest:FindFirstChild("Receive") or ReplicatedStorage.SFX.Quest:FindFirstChild("Recieve"))
				PlaySFX(receiveSfx, "rbxassetid://4612382414")
			end
			
			if shouldUpdate then
				anyChanges = true
				local config = QuestConfig.Quests[qId]
				if config then
					local function checkComplete(p)
						if config.Goals then
							local progTable = (type(p) == "table") and p or {}
							for res, goal in pairs(config.Goals) do
								local cur = progTable[res] or 0
								if res == "AbilitiesCommitted" and localData.AbilitiesCommitted then
									cur = localData.AbilitiesCommitted
								elseif res == "SeaMinesPopped" and localData.SeaMinesPopped then
									cur = localData.SeaMinesPopped
								end
								if cur < goal then return false end
							end
							return true
						else
							return (tonumber(p) or 0) >= (config.GoalAmount or 1)
						end
					end
					
					local wasReady = oldProg ~= nil and checkComplete(oldProg)
					local nowReady = checkComplete(prog)
					
					if isInitialized and nowReady and not wasReady then
						NotifierController:Notify(config.Name .. " is done! Talk to " .. (config.Giver or "Quest Giver"), Color3.fromRGB(0, 255, 0))
						local finishSfx = ReplicatedStorage:FindFirstChild("SFX") and ReplicatedStorage.SFX:FindFirstChild("Quest") and ReplicatedStorage.SFX.Quest:FindFirstChild("Finish")
						PlaySFX(finishSfx, "rbxassetid://9086152864")
					end
				end
			end
		end
		
		-- Check for removed quests
		for oQ, _ in pairs(oldQuests) do
			if data.ActiveQuests[oQ] == nil then
				anyChanges = true
			end
		end
		
		if anyChanges then
			QuestController.UpdateQuestUI()
		end
	elseif data.AbilitiesCommitted ~= nil or data.SeaMinesPopped ~= nil then
		-- AbilitiesCommitted/SeaMinesPopped changed without a full quest update —
		-- still redraw so the ability counter in the quest bar reflects the new value.
		local hasRelevantQuest = false
		for qId, _ in pairs(activeQuests) do
			local qCfg = QuestConfig.Quests[qId]
			if qCfg and qCfg.Goals then
				if qCfg.Goals["AbilitiesCommitted"] or qCfg.Goals["SeaMinesPopped"] then
					hasRelevantQuest = true
					break
				end
			end
		end
		if hasRelevantQuest then
			QuestController.UpdateQuestUI()
		end
	end

	
	isInitialized = true
end)

local function SetupUI()
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then return end
	local mainGui = playerGui:WaitForChild("Main", 10) -- ScreenGui
	if not mainGui then return end
	
	local TweenService = game:GetService("TweenService")

	-- Interaction UI (Shared)
	interactionFrame = mainGui:FindFirstChild("Interaction")
	if interactionFrame then
		keybindLabel = interactionFrame:FindFirstChild("Keybind")
		actionLabel = interactionFrame:FindFirstChild("InteractionType")
	end
	
	-- Quest Dialogue UI
	questUi = playerGui:FindFirstChild("QuestDialogue") or mainGui:FindFirstChild("QuestDialogue")
	if questUi then
		if questUi:IsA("ScreenGui") then questUi.Enabled = false else questUi.Visible = false end
		-- FIX: Ensure full screen overlays don't block mobile camera
		if questUi:IsA("GuiObject") then questUi.Active = false end
		
		local textFrame = questUi:FindFirstChild("ConfirmationTextFrame")
		if textFrame then
			questTextLabel = textFrame:FindFirstChild("ConfirmationText")
		end
		
		questNameLabel = questUi:FindFirstChild("QuestGiverName")
		questSkipBtn = questUi:FindFirstChild("ClickToSkipButton")
		
		if questSkipBtn then
			questSkipBtn.MouseButton1Click:Connect(function()
				if dialogueActive then
					QuestController.AdvanceDialogue()
				end
			end)
		end
		
	end
	
	-- Inner Main Frame Reference
	local mainFrame = mainGui:WaitForChild("Main", 5)
	
	-- Main Quest Frame (The list)
	if mainFrame then
		questFrame = mainFrame:WaitForChild("QuestFrame", 5)
	end
	
	if not questFrame then
		questFrame = mainGui:FindFirstChild("QuestFrame") or playerGui:FindFirstChild("QuestFrame")
	end
	
	-- Sliding State
    local isQuestOpen = false
    local hiddenPos = UDim2.new(-1, 0, 1, 0)
    local openPos = UDim2.new(0, 0, 1, 0)

	if questFrame then
		-- Init Position
        questFrame.Visible = true
        questFrame.Position = hiddenPos
		
		local scroll = questFrame:FindFirstChild("ScrollingFrame")
		if scroll then
			questScroll = scroll
			questTemplate = scroll:FindFirstChild("TemplateQuest")
			if questTemplate then
				questTemplate.Visible = false -- Hide template
			end
		end
	else
		warn("QuestController: QuestFrame not found in SetupUI")
	end
	
	-- Quests Button
	local buttonHolders = nil
	if mainFrame then
		buttonHolders = mainFrame:WaitForChild("ButtonHolders", 5)
	end
	
	if buttonHolders then
		questsButton = buttonHolders:FindFirstChild("quests") or buttonHolders:FindFirstChild("Quests") or buttonHolders:FindFirstChild("Quest")
		-- Note: Click handling moved to HUDController to coordinate with Inventory/Statistics sliding.
	else
		warn("QuestController: ButtonHolders not found inside Main Frame")
	end
	
	-- Setup Interaction Button Click Handler
	if interactionFrame then
		local interactionButton = interactionFrame:FindFirstChild("InteractionButton")
		if interactionButton and (interactionButton:IsA("TextButton") or interactionButton:IsA("ImageButton")) then
			-- Clear old connections if any (prevents duplicate connections)
			interactionButton.Activated:Connect(function()
				-- This will call handleQuestInteraction which is defined later
				if handleQuestInteraction then
					handleQuestInteraction()
				end
			end)
		end
	end
	
	-- Force update UI in case data arrived before UI was ready
	QuestController.UpdateQuestUI()
	
	-- Reset dialogue state on respawn to prevent softlocks
	dialogueActive = false
end

function QuestController.AssignQuest(questId)
	if not questId then return end
	
	-- Fire Server to Start Quest persistent state
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local StartQuest = Remotes:FindFirstChild("StartQuest")
	if StartQuest then
		StartQuest:FireServer(questId)
	else
		warn("Client: StartQuest Remote missing!")
	end

	if activeQuests[questId] then return end
	
	-- Notify immediately since we are starting it locally
	local config = QuestConfig.Quests[questId]
	local qName = config and config.Name or questId
	NotifierController:Notify("Received Quest: " .. qName, Color3.fromRGB(255, 215, 0))
	
	local sfxFolder = ReplicatedStorage:FindFirstChild("SFX") and ReplicatedStorage.SFX:FindFirstChild("Quest")
	local assignSfx = sfxFolder and (sfxFolder:FindFirstChild("Assign") or sfxFolder:FindFirstChild("Start") or sfxFolder:FindFirstChild("Accept") or sfxFolder:FindFirstChild("Receive") or sfxFolder:FindFirstChild("Recieve"))
	PlaySFX(assignSfx, "rbxassetid://4612382414")
	
	activeQuests[questId] = 0
	
	-- Open UI to show new quest
	if questFrame then
		if questFrame:IsA("ScreenGui") then questFrame.Enabled = true else questFrame.Visible = true end
	end
	QuestController.UpdateQuestUI()
end

function QuestController.UpdateQuestUI()
	if not questFrame or not questScroll or not questTemplate then return end

	-- Cleanup non-active quests
	for _, child in ipairs(questScroll:GetChildren()) do
		if child:IsA("Frame") and child ~= questTemplate then
			local qId = child.Name:match("^Quest_(.+)")
			if not qId or not activeQuests[qId] then
				child:Destroy()
			end
		end
	end

	for qId, prog in pairs(activeQuests) do
		local config = QuestConfig.Quests[qId]
		if not config then continue end

		-- Find or Create Item
		local item = questScroll:FindFirstChild("Quest_" .. qId)
		if not item then
			item = questTemplate:Clone()
			item.Name = "Quest_" .. qId
			item.Parent = questScroll
			item.Visible = true
		end

		-- Update Data
		local nameLabel = item:FindFirstChild("QuestName")
		if nameLabel then 
			nameLabel.Text = config.Name
		end

		-- Identify Template inside Item (New Structure: TemplateQuest -> Progress)
		local template = item:FindFirstChild("Progress") or item:FindFirstChild("Progress_Template")
		if not template then continue end
		
		-- Mark Template
		if template.Name ~= "Progress_Template" then
			template.Name = "Progress_Template"
			template.Visible = false
		end

		-- Cleanup Current Goals
		for _, c in ipairs(item:GetChildren()) do
			if c.Name:match("^Goal_") then c:Destroy() end
		end
		
		local DefaultColor = Color3.fromRGB(0,255,0)

		if config.Goals then
			-- Multi-Goal Logic
			local progTable = (type(prog) == "table") and prog or {}
			
			local keys = {}
			for k in pairs(config.Goals) do table.insert(keys, k) end
			table.sort(keys)
			
			local allMet = true
			for _, k in ipairs(keys) do
				local g = config.Goals[k]
				local c = progTable[k] or 0
				if localData and (k == "AbilitiesCommitted" or k == "SeaMinesPopped" or k == "TokensGathered" or k == "BiomassTokensGathered" or k == "MaxAlgaePerSecond" or k == "EquipmentsPurchased") then c = localData[k] or 0 elseif k == "FishRequired" then local _c=0; for _,_ in pairs(localData.FishSchool or {}) do _c=_c+1 end; c = _c end
				if c < g then allMet = false break end
			end
			
			local i = 1
			for _, k in ipairs(keys) do
				local goal = config.Goals[k]
				local cur = progTable[k] or 0
				if localData and (k == "AbilitiesCommitted" or k == "SeaMinesPopped" or k == "TokensGathered" or k == "BiomassTokensGathered" or k == "MaxAlgaePerSecond" or k == "EquipmentsPurchased") then cur = localData[k] or 0 elseif k == "FishRequired" then local _c=0; for _,_ in pairs(localData.FishSchool or {}) do _c=_c+1 end; cur = _c end
				local pct = math.clamp(cur/goal, 0, 1)

				local row = template:Clone()
				row.Name = "Goal_" .. k
				row.Parent = item -- Parent to TemplateQuest
				row.Visible = true
				row.LayoutOrder = i
				
				-- Update Visuals
				local niceName = k:gsub("(%u)", " %1"):gsub("^%s", "")
				local task = row:FindFirstChild("Task")
				if task then
					if allMet then
						task.Text = "Complete! Return to " .. (config.Giver or "Quest Giver")
					elseif BackpackConfig[k] then
						-- Backpack Equip Goal
						task.Text = "(" .. niceName .. ") Equipped: " .. math.floor(cur) .. "/" .. goal
					else
						-- Check for Location_Resource pattern (e.g. "Freshwater Reef_GreenAlgae")
						local loc, res = k:match("^(.*)_(.*)$")
						if loc and res then
							local niceRes = res:gsub("(%u)", " %1"):gsub("^%s", "")
							task.Text = "Collect " .. goal .. " " .. niceRes .. " from " .. loc .. "   " .. math.floor(cur) .. "/" .. goal
						elseif k == "AbilitiesCommitted" then
							task.Text = "Use abilities: " .. math.floor(cur) .. "/" .. goal
						elseif k == "SeaMinesPopped" then
							task.Text = "Pop sea mines: " .. math.floor(cur) .. "/" .. goal
						elseif k == "TokensGathered" then
							task.Text = "Collect tokens: " .. math.floor(cur) .. "/" .. goal
						elseif k == "BiomassTokensGathered" then
							task.Text = "Collect biomass tokens: " .. math.floor(cur) .. "/" .. goal
						elseif k == "MaxAlgaePerSecond" then
							task.Text = "Reach Algae/sec: " .. math.floor(cur) .. "/" .. goal
						elseif k == "FishRequired" then
							task.Text = "Fish placed in aquarium: " .. math.floor(cur) .. "/" .. goal
						elseif k == "EquipmentsPurchased" then
							task.Text = "Purchase equipments: " .. math.floor(cur) .. "/" .. goal
						elseif k:match("Algae$") then
							task.Text = "Collect " .. goal .. " " .. niceName .. "   " .. math.floor(cur) .. "/" .. goal
						else
							-- Plain field name (e.g. "Sun Reef") — show "Algae from [Field]"
							task.Text = "Collect " .. goal .. " Algae from " .. niceName .. "   " .. math.floor(cur) .. "/" .. goal
						end
					end
				end
				
				local bar = row:FindFirstChild("ProgressBar")
				if bar then
					bar.AnchorPoint = Vector2.new(0, 0)
					bar.Position = UDim2.new(0, 0, 0, 0)
					bar.Size = UDim2.new(pct, 0, 1, 0)
				end
				i += 1
			end
			
			local inv = item:FindFirstChild("InventoryText")
			if inv then inv.Visible = false end

		else
			-- Single Goal
			local cur = tonumber(prog) or 0
			local max = config.GoalAmount or 1
			local pct = math.clamp(cur/max, 0, 1)
			local isComplete = cur >= max
			
			local row = template:Clone()
			row.Name = "Goal_Single"
			row.Parent = item -- Parent to TemplateQuest
			row.Visible = true
			row.LayoutOrder = 1
			
			local task = row:FindFirstChild("Task")
			if task then
				if isComplete then
					task.Text = "Complete! Return to " .. (config.Giver or "Quest Giver")
				else
					local desc = config.Description
					if not desc then
						local targetRes = config.TargetResource or "Any"
						local targetResName = targetRes == "Any" and "Algae" or (targetRes:gsub("(%u)", " %1"):gsub("^%s", ""))
						if config.TargetLocation then
							desc = "Collect " .. max .. " " .. targetResName .. " from " .. config.TargetLocation
						else
							desc = "Collect " .. max .. " " .. targetResName
						end
					end
					task.Text = desc .. "   " .. math.floor(cur) .. "/" .. max
				end
			end
			
			local bar = row:FindFirstChild("ProgressBar")
			if bar then
				bar.AnchorPoint = Vector2.new(0, 0)
				bar.Position = UDim2.new(0, 0, 0, 0)
				bar.Size = UDim2.new(pct, 0, 1, 0)
				local col = DefaultColor
				bar.BackgroundColor3 = col
			end
			local inv = item:FindFirstChild("InventoryText")
			if inv then 
				inv.Text = math.floor(cur) .. "/" .. max
				inv.Visible = true 
			end
		end
		
		-- Manual Item Sizing (Scale & Layout)
		local headerHeight = 0.03
		local childHeight = 0.1

		local numChildren = 0
		for _, c in ipairs(item:GetChildren()) do
			if c.Name:match("^Goal_") and c.Visible then 
				numChildren += 1
			end
		end
		
		local contentHeight = numChildren * childHeight
		local totalHeight = headerHeight + contentHeight + 0.005
	end
end

local activeDialogueId = "WelcomeDialogue"

-- Typewriter State
local isTyping = false
local skipTypewriter = false
local generatedLabels = {}

local function ClearTypewriter()
	for _, label in ipairs(generatedLabels) do
		label:Destroy()
	end
	table.clear(generatedLabels)
	if questTextLabel then
		questTextLabel.Visible = true
		questTextLabel.TextTransparency = 0
	end
end

local function GetBoldFont(baseFont)
	local name = baseFont.Name
	if not name:find("Bold") then
		local boldFont = Enum.Font[name .. "Bold"]
		if boldFont then
			return boldFont
		end
	end
	return baseFont
end

local function TokenizeDialogue(text)
	local tokens = {}
	
	local styleStack = {
		{
			bold = false,
			shake = false,
			color = nil,
			gradient = nil
		}
	}
	
	local function currentStyle()
		return styleStack[#styleStack]
	end

	local i = 1
	while i <= #text do
		local tag, closing = nil, false
		if text:sub(i, i) == "[" then
			local tagEnd = text:find("]", i)
			if tagEnd then
				local tagContent = text:sub(i + 1, tagEnd - 1)
				if tagContent:sub(1, 1) == "/" then
					closing = true
					tagContent = tagContent:sub(2)
				end
				
				local tagName = tagContent:match("^([%w_]+)")
				if tagName == "bold" or tagName == "shake" or tagName == "emph" or tagName == "emphasis" then
					tag = tagName
					i = tagEnd + 1
					
					if closing then
						if #styleStack > 1 then
							table.remove(styleStack)
						end
					else
						local colorAttr = tagContent:match("color=([%d%s,]+)")
						local gradientAttr = tagContent:match("gradient=([%d%s,|;]+)")
						
						local parsedColor = nil
						if colorAttr then
							local r, g, b = colorAttr:match("(%d+)[%s,]+(%d+)[%s,]+(%d+)")
							if r and g and b then
								parsedColor = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
							end
						end
						
						local parsedGradient = nil
						if gradientAttr then
							local color1, color2 = gradientAttr:match("([^|;]+)[|;](.+)")
							if color1 and color2 then
								local r1, g1, b1 = color1:match("(%d+)[%s,]+(%d+)[%s,]+(%d+)")
								local r2, g2, b2 = color2:match("(%d+)[%s,]+(%d+)[%s,]+(%d+)")
								if r1 and g1 and b1 and r2 and g2 and b2 then
									parsedGradient = {
										Color3.fromRGB(tonumber(r1), tonumber(g1), tonumber(b1)),
										Color3.fromRGB(tonumber(r2), tonumber(g2), tonumber(b2))
									}
								end
							end
						end
						
						local parent = currentStyle()
						local newStyle = {
							bold = parent.bold,
							shake = parent.shake,
							color = parsedColor or parent.color,
							gradient = parsedGradient or (not parsedColor and parent.gradient or nil)
						}
						
						if tag == "bold" then
							newStyle.bold = true
						elseif tag == "shake" then
							newStyle.shake = true
						elseif tag == "emph" or tag == "emphasis" then
							newStyle.bold = true
							newStyle.shake = true
						end
						
						table.insert(styleStack, newStyle)
					end
				end
			end
		end

		if not tag then
			local char = text:sub(i, i)
			if char:match("%s") then
				i = i + 1
			else
				local wordStart = i
				while i <= #text do
					local nextChar = text:sub(i, i)
					if nextChar:match("%s") then
						break
					end
					if nextChar == "[" then
						local tagEnd = text:find("]", i)
						if tagEnd then
							local tagContent = text:sub(i + 1, tagEnd - 1)
							if tagContent:sub(1, 1) == "/" then tagContent = tagContent:sub(2) end
							local tagName = tagContent:match("^([%w_]+)")
							if tagName == "bold" or tagName == "shake" or tagName == "emph" or tagName == "emphasis" then
								break
							end
						end
					end
					i = i + 1
				end
				local word = text:sub(wordStart, i - 1)
				local style = currentStyle()
				table.insert(tokens, {
					text = word,
					bold = style.bold,
					shake = style.shake,
					color = style.color,
					gradient = style.gradient
				})
			end
		end
	end
	return tokens
end

local function PlayTypewriter(text)
	if not questTextLabel then return end
	
	local textFrame = questTextLabel.Parent
	if not textFrame then return end
	
	-- Setup Container
	ClearTypewriter()
	questTextLabel.Visible = false -- Hide original
	
	isTyping = true
	skipTypewriter = false
	
	local TextService = game:GetService("TextService")
	local TweenService = game:GetService("TweenService")
	
	local font = questTextLabel.Font
	local color = questTextLabel.TextColor3
	local containerSize = textFrame.AbsoluteSize
	local containerWidth = containerSize.X
	local containerHeight = containerSize.Y
	
	-- Tokenize text into styled words
	local styledWords = TokenizeDialogue(text)
	
	-- 1. Calculate Optimal Font Size (Mimic TextScaled)
	local minSize = 10
	local maxSize = 60 -- Reasonable max for dialogue
	local bestSize = minSize
	
	-- Helper to check if text fits at a given size
	local function checkFits(size)
		local cx, cy = 0, 0
		local lh = size * 1.2
		local sw = TextService:GetTextSize(" ", size, font, Vector2.new(1000, 1000)).X
		
		for _, item in ipairs(styledWords) do
			local wordFont = item.bold and GetBoldFont(font) or font
			local wBounds = TextService:GetTextSize(item.text, size, wordFont, Vector2.new(containerWidth, 1000))
			if wBounds.X > containerWidth then return false end -- Word too long alone
			
			if cx + wBounds.X > containerWidth then
				cx = 0
				cy = cy + lh
			end
			cx = cx + wBounds.X + sw
		end
		
		if cy + lh > containerHeight then return false end
		return true
	end
	
	-- Find best size
	for s = maxSize, minSize, -1 do
		if checkFits(s) then
			bestSize = s
			break
		end
	end
	
	local textSize = bestSize
	local lineHeight = textSize * 1.2
	local spaceWidth = TextService:GetTextSize(" ", textSize, font, Vector2.new(1000, 1000)).X
	
	-- 2. Layout Calculation
	local layout = {} -- Stores {word, x, y, width, height, bold, shake, color, gradient}
	local currentX = 0
	local currentY = 0
	local lineLineWidths = {} -- Track width of each line for centering
	
	for i, item in ipairs(styledWords) do
		local wordFont = item.bold and GetBoldFont(font) or font
		local bounds = TextService:GetTextSize(item.text, textSize, wordFont, Vector2.new(containerWidth, 1000))
		
		if currentX + bounds.X > containerWidth and currentX > 0 then
			-- New Line
			lineLineWidths[#lineLineWidths + 1] = currentX - spaceWidth -- Remove trailing space
			currentX = 0
			currentY = currentY + lineHeight
		end
		
		table.insert(layout, {
			text = item.text,
			x = currentX,
			y = currentY,
			w = bounds.X,
			h = bounds.Y,
			lineIndex = #lineLineWidths + 1,
			bold = item.bold,
			shake = item.shake,
			color = item.color,
			gradient = item.gradient
		})
		
		currentX = currentX + bounds.X + spaceWidth
	end
	-- Handle last line
	lineLineWidths[#lineLineWidths + 1] = currentX - spaceWidth
	
	local totalContentHeight = currentY + lineHeight
	
	-- 3. Render and Animate
	local startYOffset = (containerHeight - totalContentHeight) / 2 -- Vertical Center
	
	local totalDelay = 0
	local delayStep = 0.03 -- Faster typing
	
	for _, item in ipairs(layout) do
		-- Horizontal Center per line
		local lineWidth = lineLineWidths[item.lineIndex] or 0
		local startXOffset = (containerWidth - lineWidth) / 2
		
		local finalX = item.x + startXOffset
		local finalY = item.y + startYOffset
		
		-- Create Label
		local label = Instance.new("TextLabel")
		label.Name = "Word"
		label.Text = item.text
		label.Font = item.bold and GetBoldFont(font) or font
		label.TextSize = textSize
		label.TextColor3 = item.color or color
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromOffset(item.w, item.h)
		label.Parent = textFrame
		
		if item.gradient then
			local uiGradient = Instance.new("UIGradient")
			uiGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, item.gradient[1]),
				ColorSequenceKeypoint.new(1, item.gradient[2])
			})
			uiGradient.Parent = label
		end
		
		-- Animation Setup
		local targetPos = UDim2.new(0, finalX, 0, finalY)
		local startPos = UDim2.new(0, finalX, 0, finalY + 15) -- Start slightly lower
		
		label.Position = startPos
		label.TextTransparency = 1
		
		-- Store target for skip logic
		label:SetAttribute("TargetPosX", targetPos.X.Offset)
		label:SetAttribute("TargetPosY", targetPos.Y.Offset)
		
		table.insert(generatedLabels, label)
		
		task.spawn(function()
			if not skipTypewriter then
				task.wait(totalDelay)
			end
			
			if skipTypewriter then
				label.Position = targetPos
				label.TextTransparency = 0
			else
				local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				TweenService:Create(label, tweenInfo, {Position = targetPos, TextTransparency = 0}):Play()
				
				if item.shake then
					task.spawn(function()
						local startTime = os.clock()
						local duration = 0.65
						local shakeSpeed = 0.02
						while os.clock() - startTime < duration do
							if skipTypewriter then break end
							local elapsed = os.clock() - startTime
							local progress = elapsed / duration
							local intensity = (1 - progress) * 12
							
							local offsetX = math.random(-intensity, intensity)
							local offsetY = math.random(-intensity, intensity)
							
							label.Position = UDim2.new(0, finalX + offsetX, 0, finalY + offsetY)
							task.wait(shakeSpeed)
						end
						label.Position = targetPos
					end)
				end
			end
		end)
		
		totalDelay = totalDelay + delayStep
		if skipTypewriter then break end
	end
	
	task.spawn(function()
		if not skipTypewriter then task.wait(totalDelay + 0.5) end
		isTyping = false
	end)
end

function QuestController.AdvanceDialogue()
	if not dialogueActive then return end
	
	-- Handle Skip
	if isTyping then
		skipTypewriter = true
		task.wait() -- Allow spawned threads to catch skip flag
		
		-- Force Finish Animation logic
		for _, label in ipairs(generatedLabels) do
			label.TextTransparency = 0
			local tx = label:GetAttribute("TargetPosX")
			local ty = label:GetAttribute("TargetPosY")
			if tx and ty then
				label.Position = UDim2.fromOffset(tx, ty)
			end
		end
		
		isTyping = false
		return
	end
	
	local dConfig = DialogueConfig[activeDialogueId] or DialogueConfig.WelcomeDialogue
	local messages = dConfig.Messages or dConfig
	currentDialogueIndex = currentDialogueIndex + 1
	
	if currentDialogueIndex > #messages then
		QuestController.EndDialogue()
	else
		QuestController.ShowText(messages[currentDialogueIndex])
	end
end

function QuestController.ShowText(text)
	if questTextLabel then
		PlayTypewriter(text)
	end
end

function QuestController.StartDialogue(key, giverName)
	activeDialogueId = key or "WelcomeDialogue"
	if not questUi then return end
	dialogueActive = true
	
	if interactionFrame then interactionFrame.Visible = false end
	
	if questUi:IsA("ScreenGui") then questUi.Enabled = true else questUi.Visible = true end
	
	-- Animate Dialogue Frame (Tween Up)
	local mainFrame = questUi
	if mainFrame:IsA("ScreenGui") then 
		mainFrame = questUi:FindFirstChild("MainBackground") or questUi:FindFirstChildOfClass("Frame")
	end
	
	if mainFrame and mainFrame:IsA("GuiObject") then
		local TweenService = game:GetService("TweenService")
		-- Reset to potentially off-screen or lower position
		local targetPos = mainFrame.Position
		mainFrame.Position = targetPos + UDim2.fromOffset(0, 50)
		
		TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = targetPos
		}):Play()
	end
	
	currentDialogueIndex = 1
	if questNameLabel then 
		questNameLabel.Text = giverName or DialogueConfig.QuestGiverName or "Quest Giver"
	end
	
	local dConfig = DialogueConfig[activeDialogueId]
	local msgs = (dConfig and (dConfig.Messages or dConfig)) or {"..."}
	QuestController.ShowText(msgs[1])
end

function QuestController.EndDialogue()
	dialogueActive = false
	if questUi:IsA("ScreenGui") then questUi.Enabled = false else questUi.Visible = false end
	
	ClearTypewriter()
	
	local dConfig = DialogueConfig[activeDialogueId] or DialogueConfig.WelcomeDialogue
	
	-- Assign Quest if defined in config
	if dConfig.QuestID then
		QuestController.AssignQuest(dConfig.QuestID)
	end
	
	-- Finish Quest
	if dConfig.FinishQuestID then
		local qId = dConfig.FinishQuestID
		-- Optimistic Update to prevent logic sticking on old state
		-- completedQuests[qId] = os.time() -- REMOVED: Allow DataUpdateEvent to trigger notifications
		if activeQuests[qId] then
			activeQuests[qId] = nil
			QuestController.UpdateQuestUI()
		end

		local Remotes = ReplicatedStorage:WaitForChild("Remotes")
		local FinishQuest = Remotes:FindFirstChild("FinishQuest")
		if FinishQuest then FinishQuest:FireServer(qId) end
	end
end





function QuestController.Start()
	task.spawn(SetupUI)
	
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		SetupUI()
		
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.Died:Connect(function()
				if dialogueActive then
					QuestController.EndDialogue()
				end
			end)
		end
	end)
	
	-- Shared quest interaction logic
	handleQuestInteraction = function()
		if not isQuestInteractable or dialogueActive or interactionDebounce then return end
		interactionDebounce = true
		
		local npcName = _G.CurrentQuestGiver or "Elder Turtle"
		local key = "NoMoreQuests"
		
		local npcQuestId = nil
		local npcQuestState = nil
		
		for qId, prog in pairs(activeQuests) do
			local qc = QuestConfig.Quests[qId]
			if qc and (qc.Giver == npcName or (not qc.Giver and npcName == "Elder Turtle")) then
				local isComplete = false
				if qc.Goals then
					local progTable = (type(prog) == "table") and prog or {}
					local allMet = true
					for res, goal in pairs(qc.Goals) do
						local cur = progTable[res] or 0
						if localData and (res == "AbilitiesCommitted" or res == "SeaMinesPopped" or res == "TokensGathered" or res == "BiomassTokensGathered" or res == "MaxAlgaePerSecond" or res == "EquipmentsPurchased") then cur = localData[res] or 0 elseif res == "FishRequired" then local _c=0; for _,_ in pairs(localData.FishSchool or {}) do _c=_c+1 end; cur = _c end
						if cur < goal then allMet = false; break end
					end
					isComplete = allMet
				else
					local cur = tonumber(prog) or 0
					isComplete = cur >= (qc.GoalAmount or 1)
				end
				
				if isComplete then
					npcQuestId = qId
					npcQuestState = "Complete"
					break -- Priority to turn in
				else
					npcQuestId = qId
					npcQuestState = "InProgress"
				end
			end
		end
		
		if npcQuestId then
			key = npcQuestId .. "_" .. npcQuestState
		else
			-- Determine Next Quest
			if npcName == "Noobie Turtle" then
				key = "NoobieTurtle_Start"
			else
				local nextQuest = nil
				for _, qId in ipairs(QUEST_CHAIN) do
					if not completedQuests[qId] and not activeQuests[qId] then
						local qc = QuestConfig.Quests[qId]
						if qc and (qc.Giver == npcName or not qc.Giver) then
							nextQuest = qId
							break
						end
					end
				end
				
				if nextQuest then
					if nextQuest == "FreshwaterCleaning" then
						key = "WelcomeDialogue"
					else
						key = nextQuest .. "_Start"
					end
				else
					key = "NoMoreQuests"
				end
			end
		end
		if not DialogueConfig[key] then
			warn("QuestController: Dialogue key not found: " .. tostring(key))
			key = "NoMoreQuests"
		end

		QuestController.StartDialogue(key, npcName)
		task.wait(0.5)
		interactionDebounce = false
	end
	
	-- Input Handling
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.E then
			handleQuestInteraction()
		end
	end)

	
	local function connectInteractionButton()
		local playerGui = player:WaitForChild("PlayerGui")
		local mainGui = playerGui:WaitForChild("Main")
		local interactionFrame = mainGui:WaitForChild("Interaction")
		local button = interactionFrame:FindFirstChild("InteractionButton")
		if button and (button:IsA("TextButton") or button:IsA("ImageButton")) then
			local function onActivated()
				handleQuestInteraction()
				
				-- Visual Feedback
				local originalColor = button.BackgroundColor3
				button.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
				task.delay(0.1, function()
					button.BackgroundColor3 = originalColor
				end)
			end

			button.Activated:Connect(onActivated)

			-- Extra responsiveness for Touch/Touchpad
			button.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					onActivated()
				end
			end)
		end
	end
	task.spawn(connectInteractionButton)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		connectInteractionButton()
	end)
	
	-- Proximity Loop
	-- Proximity Loop & VFX
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		if not char or not char.PrimaryPart then return end
		local root = char.PrimaryPart.Position
		
		-- 1. Identify Potential NPCs
		local npcs = {}
		
		-- Elder Turtle candidates
		-- Priority: workspace.ElderTurtle (Folder) -> containing Platform or QGModel
		local elderFolder = workspace:FindFirstChild("Elder Turtle") or workspace:FindFirstChild("QuestGiver") or workspace:FindFirstChild("QuestGiver1")
		
		if elderFolder then
			-- User says Platform is inside the Folder directly
			local platform = elderFolder:FindFirstChild("Platform") or elderFolder:FindFirstChild("platform")
			
			if platform then
				-- If Platform found, treat the Folder as the NPC container, and Platform as the Root
				table.insert(npcs, {Model = elderFolder, Name = "Elder Turtle", Root = platform})
			else
				-- Fallback: Check for QGModel inside Folder
				local qgModel = elderFolder:FindFirstChild("QGModel")
				if qgModel then
					table.insert(npcs, {Model = qgModel, Name = "Elder Turtle"})
				elseif elderFolder:IsA("Model") and elderFolder.PrimaryPart then
					-- Fallback: The Folder is actually a Model
					table.insert(npcs, {Model = elderFolder, Name = "Elder Turtle"})
				end
			end
		end
		
		-- Check specialized folder (NPCs)
		if workspace:FindFirstChild("NPCs") then
			local e = workspace.NPCs:FindFirstChild("Elder Turtle") or workspace.NPCs:FindFirstChild("QuestGiver")
			if e and not elderFolder then
				local platform = e:FindFirstChild("Platform")
				if platform then
					table.insert(npcs, {Model = e, Name = "Elder Turtle", Root = platform})
				else
					local qg = e:FindFirstChild("QGModel") or (e:IsA("Model") and e)
					if qg then table.insert(npcs, {Model = qg, Name = "Elder Turtle"}) end
				end
			end

			local bb = workspace.NPCs:FindFirstChild("Noobie Turtle")
			if bb then
				local platform = bb:FindFirstChild("Platform")
				table.insert(npcs, {Model = bb, Name = "Noobie Turtle", Root = platform})
			end
		end
		
		local NoobieTurtleFolder = workspace:FindFirstChild("Noobie Turtle")
		if NoobieTurtleFolder then
			local platform = NoobieTurtleFolder:FindFirstChild("Platform")
			table.insert(npcs, {Model = NoobieTurtleFolder, Name = "Noobie Turtle", Root = platform})
		end
		
		local LavaTurtleFolder = workspace:FindFirstChild("Lava Turtle") or (workspace:FindFirstChild("NPCs") and workspace.NPCs:FindFirstChild("Lava Turtle"))
		if LavaTurtleFolder then
			local platform = LavaTurtleFolder:FindFirstChild("Platform") or LavaTurtleFolder:FindFirstChild("Head")
			table.insert(npcs, {Model = LavaTurtleFolder, Name = "Lava Turtle", Root = platform})
		end

		-- 2. Find Nearest
		local nearestNPC = nil
		local minDist = 25 -- Increased range
		
		for _, npcData in ipairs(npcs) do
			-- Robust Root finding if not already set
			local nRoot = npcData.Root
			if not nRoot then
				local model = npcData.Model
				nRoot = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("Head") or model:FindFirstChild("Platform") or model:FindFirstChild("Main")
				
				if not nRoot then
					for _, child in ipairs(model:GetChildren()) do
						if child:IsA("BasePart") then
							nRoot = child
							break
						end
					end
				end
				npcData.Root = nRoot
			end
			
			if nRoot then
				local dist = (nRoot.Position - root).Magnitude
				if dist < minDist then
					minDist = dist
					nearestNPC = npcData
				end
			end
		end
		
		-- 3. Update UI Interaction
		if nearestNPC and interactionFrame and keybindLabel and actionLabel then
			local nRoot = nearestNPC.Root
			-- Save reference for VFX
			local vfxPlatform = nearestNPC.Model:FindFirstChild("Platform") or nRoot 
			
			if not dialogueActive then
				interactionFrame.Visible = true
				
				local head = nearestNPC.Model:FindFirstChild("Head") or nRoot
				local offset = Vector3.new(0, 5, 0)
				local worldPos = (head and head.Position or nRoot.Position) + offset
				
				local vector, onScreen = workspace.CurrentCamera:WorldToScreenPoint(worldPos)
				if onScreen then
					local currentPos = interactionFrame.Position
					local targetPos = UDim2.fromOffset(vector.X, vector.Y)
					interactionFrame.Position = currentPos:Lerp(targetPos, 0.2)
				else
					-- Clamp to screen edge or just hide? User complained about seeing nothing.
					-- Let's just keep it visible if close enough, maybe even if offscreen (clamped)
					-- But for now, standard logic. Maybe the issue was nRoot being nil.
					interactionFrame.Position = UDim2.fromOffset(vector.X, vector.Y)
				end
				
				keybindLabel.Text = "E"
				actionLabel.Text = "Talk to " .. nearestNPC.Name
				isQuestInteractable = true
				_G.CurrentQuestGiver = nearestNPC.Name
			else
				interactionFrame.Visible = false
			end
			
		else
			-- No NPC nearby
			if not dialogueActive then
				if not actionLabel.Text:match("Shop") and not actionLabel.Text:match("Aquarium") and not actionLabel.Text:match("Convert") and not actionLabel.Text:match("Cannon") and not actionLabel.Text:match("Machine") then
					interactionFrame.Visible = false
				end
			end
			isQuestInteractable = false
			_G.CurrentQuestGiver = nil
		end
		
		-- 4. VFX Logic (Quest Indicators for ALL NPCs)
		for _, npcData in ipairs(npcs) do
			local shouldShow = false
			
			if npcData.Name == "Elder Turtle" then
				for qId, prog in pairs(activeQuests) do
					local qc = QuestConfig.Quests[qId]
					if qc and (qc.Giver == "Elder Turtle" or not qc.Giver) then
						local isComplete = false
						if qc.Goals then
							local progTable = (type(prog) == "table") and prog or {}
							local allMet = true
							for res, goal in pairs(qc.Goals) do
								local cur = progTable[res] or 0
								if localData and (res == "AbilitiesCommitted" or res == "SeaMinesPopped" or res == "TokensGathered" or res == "BiomassTokensGathered" or res == "MaxAlgaePerSecond" or res == "EquipmentsPurchased") then cur = localData[res] or 0 elseif res == "FishRequired" then local c=0; for _,_ in pairs(localData.FishSchool or {}) do c=c+1 end; cur = c end
								
								if cur < goal then allMet = false; break end
							end
							isComplete = allMet
						else
							local cur = tonumber(prog) or 0
							isComplete = cur >= (qc.GoalAmount or 1)
						end
						if isComplete then shouldShow = true; break end
					end
				end
				
				if not shouldShow then
					for _, qId in ipairs(QUEST_CHAIN) do
						if not completedQuests[qId] then
							-- This is the next chronological quest needed.
							if not activeQuests[qId] then
								local qc = QuestConfig.Quests[qId]
								if qc and (qc.Giver == "Elder Turtle" or not qc.Giver) then
									shouldShow = true
								end
							end
							break -- Stop searching the chain! Don't look at quest 5 if quest 4 is active!
						end
					end
				end
			elseif npcData.Name == "Noobie Turtle" then
				if activeQuests["NoobieTurtle"] then
					local qc = QuestConfig.Quests["NoobieTurtle"]
					local prog = activeQuests["NoobieTurtle"]
					if qc then
						local isComplete = false
						local progTable = (type(prog) == "table") and prog or {}
						local allMet = true
						for res, goal in pairs(qc.Goals) do
							local cur = progTable[res] or 0
							if localData and (res == "AbilitiesCommitted" or res == "SeaMinesPopped" or res == "TokensGathered" or res == "BiomassTokensGathered" or res == "MaxAlgaePerSecond" or res == "EquipmentsPurchased") then cur = localData[res] or 0 elseif res == "FishRequired" then local c=0; for _,_ in pairs(localData.FishSchool or {}) do c=c+1 end; cur = c end
							
							if cur < goal then allMet = false; break end
						end
						if allMet then shouldShow = true end
					end
				elseif not completedQuests["NoobieTurtle"] then
					shouldShow = true
				end
			elseif npcData.Name == "Lava Turtle" then
				if activeQuests["LavaTurtle"] then
					local qc = QuestConfig.Quests["LavaTurtle"]
					local prog = activeQuests["LavaTurtle"]
					if qc then
						local isComplete = false
						local progTable = (type(prog) == "table") and prog or {}
						local allMet = true
						for res, goal in pairs(qc.Goals) do
							local cur = progTable[res] or 0
							if localData and (res == "AbilitiesCommitted" or res == "SeaMinesPopped" or res == "TokensGathered" or res == "BiomassTokensGathered" or res == "MaxAlgaePerSecond" or res == "EquipmentsPurchased") then cur = localData[res] or 0 elseif res == "FishRequired" then local c=0; for _,_ in pairs(localData.FishSchool or {}) do c=c+1 end; cur = c end
							
							if cur < goal then allMet = false; break end
						end
						if allMet then shouldShow = true end
					end
				elseif not completedQuests["LavaTurtle"] then
					shouldShow = true
				end
			end
			
			local vfxPlatform = npcData.Model:FindFirstChild("Platform") or npcData.Root
			local currentInd = vfxPlatform and vfxPlatform:FindFirstChild("QuestIndicate")
			
			if shouldShow then
				if not currentInd and vfxPlatform then
					local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
					local template = vfxFolder and vfxFolder:FindFirstChild("QuestIndicate")
					if template then
						local newInd = template:Clone()
						newInd.Parent = vfxPlatform
					end
				end
			else
				if currentInd then
					currentInd:Destroy()
				end
			end
		end
	end)
end

return QuestController

