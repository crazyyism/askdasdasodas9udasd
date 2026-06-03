local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FishConfig = require(ReplicatedStorage.Shared.FishConfig)

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local AbilityUIController = {}

local activeBuffs = {} -- Track active buffs: {AlgaeBoost = {Stacks=5, ExpiresAt=time}}

local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)

-- Track current artifacts to handle unequip logic
local currentArtifacts = {}

function AbilityUIController.Start()
	print("AbilityUIController: Starting...")
	
	local buffBar, abilityTemplate, buffDescription, buffDescriptionEquip
	local equipBar, equipTemplate
	
	local function SetupUI()
		local mainGui = PlayerGui:WaitForChild("Main", 10)
		if not mainGui then return end
		
		buffBar = mainGui:WaitForChild("BuffBar", 10)
		buffDescription = mainGui:WaitForChild("BuffDescription", 10)
		buffDescriptionEquip = mainGui:WaitForChild("BuffDescriptionEquip", 10) -- New Frame
		if not buffBar or not buffDescription then return end
		
		-- FIX: Ensure frames don't sink input (blocks mobile camera)
		buffBar.Active = false
		buffDescription.Active = false
		if buffDescriptionEquip then 
			buffDescriptionEquip.Active = false 
		end
		
		abilityTemplate = buffBar:WaitForChild("AbilityTemplate", 10)
		if abilityTemplate then
			abilityTemplate.Visible = false
		end

		equipBar = mainGui:WaitForChild("EquipBar", 10)
		equipTemplate = equipBar:WaitForChild("AbilityTemplate", 10)
		if equipTemplate then
			equipTemplate.Visible = false
		end
		
		buffDescription.Visible = false
		if buffDescriptionEquip then buffDescriptionEquip.Visible = false end
		
		-- Clear any lingering buff frames (except template)
		for _, child in ipairs(buffBar:GetChildren()) do
			if child.Name:match("Buff_") then
				child:Destroy()
			end
		end

		for _, child in ipairs(equipBar:GetChildren()) do
			if child.Name:match("Buff_") then
				child:Destroy()
			end
		end
		
		-- Re-populate
		for buffName, buffData in pairs(activeBuffs) do
			if buffData.Permanent then
				UpdateBuffDisplay(equipBar, equipTemplate, buffDescription, buffName)
			else
				UpdateBuffDisplay(buffBar, abilityTemplate, buffDescription, buffName)
			end
		end
	end
	
	task.spawn(SetupUI)
	
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		SetupUI()
	end)
	
	-- Setup RemoteEvent listener
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local AbilityBuffUpdate = Remotes:WaitForChild("AbilityBuffUpdate")
	local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
	
	-- Listen for buff updates from server
	AbilityBuffUpdate.OnClientEvent:Connect(function(buffName, stacks, expiresAt)
		-- Ensure UI is ready logic?
		if not buffBar then SetupUI() end
		
		if stacks > 0 then
			if not expiresAt then expiresAt = os.time() + 10 end
			activeBuffs[buffName] = {Stacks = stacks, ExpiresAt = expiresAt}
			if buffBar and abilityTemplate then
				UpdateBuffDisplay(buffBar, abilityTemplate, buffDescription, buffName)
			end
		else
			activeBuffs[buffName] = nil
			if buffBar then
				RemoveBuffDisplay(buffBar, buffName)
			end
			if equipBar then
				RemoveBuffDisplay(equipBar, buffName)
			end
		end
	end)
	
	-- Listen for Artifact Updates
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		if not buffBar then SetupUI() end
		
		local newArtifacts = {}
		
		if data.EquippedArtifacts then
			-- Add/Update Artifacts
			for _, artName in ipairs(data.EquippedArtifacts) do
				newArtifacts[artName] = true
				if not activeBuffs[artName] then
					-- Register as permanent buff
					activeBuffs[artName] = {Stacks = 1, Permanent = true}
					if equipBar and equipTemplate then
						UpdateBuffDisplay(equipBar, equipTemplate, buffDescription, artName)
					end
				end
			end
		end
		

		
		if data.ActiveReefBoosts then
			for reefName, boostData in pairs(data.ActiveReefBoosts) do
				local buffName = reefName .. " Boost"
				if os.time() < boostData.ExpiresAt then
					activeBuffs[buffName] = {Stacks = boostData.Multiplier, ExpiresAt = boostData.ExpiresAt}
					if buffBar and abilityTemplate then
						UpdateBuffDisplay(buffBar, abilityTemplate, buffDescription, buffName)
					end
				end
			end
		end
		
		-- Remove Unequipped Artifacts / Backpacks
		for artName, _ in pairs(currentArtifacts) do
			if not newArtifacts[artName] then
				activeBuffs[artName] = nil
				if equipBar then
					RemoveBuffDisplay(equipBar, artName)
				end
			end
		end
		
		currentArtifacts = newArtifacts
	end)
	
	-- Update loop for progress bars AND hover detection
	RunService.Heartbeat:Connect(function()
		if not buffBar or not buffDescription then return end
		
		local currentTime = os.time()
		local mouse = player:GetMouse()
		local mouseX = mouse.X
		local mouseY = mouse.Y
		
		local anyHovered = false
		local specificHoveredBuffName = nil
		
		for buffName, buffData in pairs(activeBuffs) do
			local targetBar = buffData.Permanent and equipBar or buffBar
			local buffFrame = targetBar:FindFirstChild("Buff_" .. buffName)
			if buffFrame and buffFrame.Visible then
				-- 1. Update Progress & Count
				local progress = buffFrame:FindFirstChild("Progress")
				local countLabel = buffFrame:FindFirstChild("Count")
				
				if buffData.Permanent then
					-- Permanent Buff Logic (Artifacts)
					if progress then
						-- Full bar or Hidden? User requested "simply have the name... no duration".
						-- Full bar indicates valid/active.
						progress.Size = UDim2.new(1, 0, 1, 0)
					end
					if countLabel then
						countLabel.Visible = false -- No stack count for artifacts usually
					end
				else
					if countLabel then countLabel.Visible = true end
					
					local exp = buffData.ExpiresAt or currentTime
					local timeRemaining = exp - currentTime
					-- Remove buff if expired
					if timeRemaining <= 0 then
						activeBuffs[buffName] = nil
						RemoveBuffDisplay(buffBar, buffName)
					else
						local abilityConfig = GetAbilityConfigByName(buffName)
						if abilityConfig then
							-- For Focus buff, use 10 seconds (buff duration), not ability duration
							-- For other buffs, use their configured duration
							local maxDuration
							if buffName == "Focus" then
								maxDuration = 10 -- Focus buff lasts 10 seconds
							else
								maxDuration = abilityConfig.Duration or 10
							end
							
							local progressPercent = timeRemaining / maxDuration
							if progressPercent > 1 then progressPercent = 1 end
							
							if progress then
								-- Vertical Progress Bar (Fills from Bottom)
								progress.AnchorPoint = Vector2.new(0, 1)
								progress.Position = UDim2.new(0, 0, 1, 0)
								progress.Size = UDim2.new(1, 0, progressPercent, 0)
							end
						end
					end
				end
				
				if countLabel and not buffData.Permanent then
					countLabel.Text = tostring(buffData.Stacks)
				end
					
				-- 2. Check Hover (Manual AABB check to bypass ZIndex blocks)
				if not anyHovered then
					local absPos = buffFrame.AbsolutePosition
					local absSize = buffFrame.AbsoluteSize
					
					-- Standard AABB check
					local isOver = (mouseX >= absPos.X and mouseX <= absPos.X + absSize.X and mouseY >= absPos.Y and mouseY <= absPos.Y + absSize.Y)
					if isOver then
						anyHovered = true
						specificHoveredBuffName = buffName
					end
				end
			end
		end
		
		-- 3. Update Tooltip Visibility
		if anyHovered and specificHoveredBuffName then
			local abilityConfig = GetAbilityConfigByName(specificHoveredBuffName)
			local buffData = activeBuffs[specificHoveredBuffName]
			
			if not abilityConfig then
				-- No config found, hide tooltips
				buffDescription.Visible = false
				if buffDescriptionEquip then buffDescriptionEquip.Visible = false end
			else
				buffDescription.ZIndex = 100 
				if buffDescriptionEquip then buffDescriptionEquip.ZIndex = 100 end
				
				local isEquipment = (buffData and buffData.Permanent) and (abilityConfig.Stats ~= nil or abilityConfig.ProductType == "Backpack")
				
				if isEquipment and buffDescriptionEquip then
					-- Equipment tooltip
					buffDescription.Visible = false
					buffDescriptionEquip.Visible = true
					
					local container = buffDescriptionEquip
					local equipName = container:FindFirstChild("EquipName")
					local equipDesc = container:FindFirstChild("EquipDescription") 
					
					if equipName then equipName.Text = abilityConfig.Name end
					if equipDesc then equipDesc.Text = abilityConfig.Description or "" end
					
					local template = container:FindFirstChild("BuffText")
					if template then
						template.Visible = false
						
						-- Clear old items
						for _, child in ipairs(container:GetChildren()) do
							local keep = false
							if child == template or child == equipName or child == equipDesc then keep = true end
							if child:IsA("UIListLayout") or child:IsA("UIPadding") or child:IsA("UICorner") or child:IsA("UIStroke") then keep = true end
							if not keep then child:Destroy() end
						end
						
						-- Populate Stats
						if abilityConfig.Stats then
							local statMap = {
								SpeedBoost = "Speed Boost", AlgaeBoost = "Algae Boost", CapacityBoost = "Capacity Boost",
								ConvertBoost = "Convert Boost", InstantConvertBoost = "Instant Conversion Boost",
								OrangeAlgaeBoost = "Orange Algae Boost", GreenAlgaeBoost = "Green Algae Boost",
								PinkAlgaeBoost = "Pink Algae Boost", BiomassBoost = "Biomass Boost",
								CritChanceBoost = "Crit Chance Boost", CritPowerBoost = "Crit Power Boost",
								WalkSpeedMult = "Move Speed", Algae = "Algae", CapacityMult = "Capacity",
								ConvertMultiplier = "Convert Rate", InstantConversion = "Instant Conversion",
								CritChanceBonus = "Crit Chance", CritPowerBonus = "Crit Power", BiomassPerAlgae = "Biomass",
								PinkAlgae = "Pink Algae", GreenAlgae = "Green Algae", OrangeAlgae = "Orange Algae"
							}
							
							for statKey, statVal in pairs(abilityConfig.Stats) do
								local displayVal = statVal
								local suffix = ""
								if type(statVal) == "number" then
									if statKey:match("Boost") or statKey:match("Mult") or statKey:match("Bonus") or statKey:match("Conversion") or statKey:match("Rate") then
										displayVal = math.floor(statVal * 100 + 0.5)
										suffix = "%"
									end
								end
								local displayName = statMap[statKey] or statKey
								local newItem = template:Clone()
								newItem.Name = "Stat_" .. statKey
								newItem.Text = string.format("+%s%s %s", tostring(displayVal), suffix, displayName)
								newItem.Visible = true
								newItem.Parent = container
							end
						end
						
						-- Populate Passive
						if abilityConfig.Passive then
							local newItem = template:Clone()
							newItem.Name = "Stat_Passive"
							newItem.Text = "Passive: " .. abilityConfig.Passive
							newItem.Visible = true
							newItem.TextColor3 = Color3.fromRGB(255, 215, 0)
							newItem.Parent = container
						end
						
						-- Populate Backpack Stats
						if abilityConfig.ProductType == "Backpack" then
							if abilityConfig.Capacity and abilityConfig.Capacity > 0 then
								local newItem = template:Clone()
								newItem.Name = "Stat_Capacity"
								newItem.Text = "+" .. abilityConfig.Capacity .. " Max Capacity"
								newItem.Visible = true
								newItem.Parent = container
							end
							if abilityConfig.ConvertAdd and abilityConfig.ConvertAdd > 0 then
								local newItem = template:Clone()
								newItem.Name = "Stat_ConvertAdd"
								newItem.Text = "+" .. abilityConfig.ConvertAdd .. "% Convert Rate"
								newItem.Visible = true
								newItem.Parent = container
							end
							if abilityConfig.AlgaePercentAdd and abilityConfig.AlgaePercentAdd > 0 then
								local newItem = template:Clone()
								newItem.Name = "Stat_AlgaePercentAdd"
								newItem.Text = "+" .. abilityConfig.AlgaePercentAdd .. "% All Algae"
								newItem.Visible = true
								newItem.Parent = container
							end
						end
					end
					
					buffDescriptionEquip.AnchorPoint = Vector2.new(1, 1)
					buffDescriptionEquip.Position = UDim2.new(0, mouseX - 10, 0, mouseY)
				else
					-- Standard tooltip
					buffDescription.Visible = true
					if buffDescriptionEquip then buffDescriptionEquip.Visible = false end
					
					local buffName_field = buffDescription:FindFirstChild("BuffName")
					local description_field = buffDescription:FindFirstChild("Description")
					local count_field = buffDescription:FindFirstChild("Count")
					local timer_field = buffDescription:FindFirstChild("Timer")
					
					if buffName_field then buffName_field.Text = abilityConfig.Name end
					if description_field then 
						local desc = abilityConfig.Description
						if type(desc) == "function" then
							local stacks = (buffData and buffData.Stacks) or 1
							desc = desc(stacks)
						end
						description_field.Text = desc
					end
					
					if count_field then
						if buffData and buffData.Permanent then
							count_field.Visible = false
						elseif buffData then
							count_field.Visible = true
							count_field.Text = "(x" .. tostring(buffData.Stacks) .. ")"
						end
					end
					if timer_field then
						if buffData and buffData.Permanent then
							timer_field.Visible = false
						elseif buffData then
							timer_field.Visible = true
							local timeLeft = buffData.ExpiresAt - currentTime
							if timeLeft < 0 then timeLeft = 0 end
							timer_field.Text = tostring(math.ceil(timeLeft)) .. "s"
						end
					end
					
					local abilityImage = buffDescription:FindFirstChild("AbilityImage")
					if abilityImage then
						local img = abilityConfig.Icon or abilityConfig.Image
						if img and img ~= "" then
							abilityImage.Image = img
						end
					end
					
					buffDescription.AnchorPoint = Vector2.new(0, 1)
					buffDescription.Position = UDim2.new(0, mouseX, 0, mouseY)
				end
			end
		else
			-- No hover
			buffDescription.Visible = false
			if buffDescriptionEquip then buffDescriptionEquip.Visible = false end
		end
	end)
	
	print("AbilityUIController: Started")
end

function GetAbilityConfigByName(abilityName)
	if type(abilityName) == "string" and abilityName:match(" Boost$") and abilityName:match("Reef") then
		local reefName = abilityName:gsub(" Boost$", "")
		return {
			Name = abilityName,
			Description = function(s) 
				return reefName .. " Algae Boost +" .. math.floor((s - 1) * 100) .. "%"
			end,
			Duration = 600, -- 10 minutes
			Image = "rbxassetid://137465296316335" -- Orange boost placeholder image
		}
	end

	if FishConfig.Buffs and FishConfig.Buffs[abilityName] then
		local cfg = FishConfig.Buffs[abilityName]
		if not cfg.Name then cfg.Name = abilityName end
		return cfg
	end

	if EquipmentConfig[abilityName] then
		return EquipmentConfig[abilityName]
	end
	if abilityName == "PinkAlgaeBoost" then
		for _, fishData in pairs(FishConfig.Fish) do
			if fishData.Ability and fishData.Ability.Name == "Obsession" then
				return fishData.Ability
			end
		end
	end

	if abilityName == "Focus" then
		for _, fishData in pairs(FishConfig.Fish) do
			if fishData.Ability and fishData.Ability.Name == "Tropical Gust" then
				return fishData.Ability
			end
		end
	end
	
	if abilityName == "ToolAlgae" or abilityName == "ToolAlgaeRecall" then
		return FishConfig.Buffs["ToolBoost"]
	end

	if abilityName == "PinBoost" then
		return FishConfig.Abilities["Pinned Down"]
	end

	for fishId, fishData in pairs(FishConfig.Fish) do
		if fishData.Ability then
			if fishData.Ability.Name == abilityName then
				return fishData.Ability
			end
			if fishData.Ability.Name:gsub(" ", "") == abilityName then
				return fishData.Ability
			end
		end
	end
	return nil
end

function UpdateBuffDisplay(buffBar, template, buffDescription, buffName)
	local buffFrame = buffBar:FindFirstChild("Buff_" .. buffName)
	
	if not buffFrame then
		-- Create new buff display
		buffFrame = template:Clone()
		buffFrame.Name = "Buff_" .. buffName
		buffFrame.Visible = true
		buffFrame.Active = true
		buffFrame.Parent = buffBar
		
		-- Get ability config for icon
		local abilityConfig = GetAbilityConfigByName(buffName)
		if abilityConfig then
			local abilityImage = buffFrame:FindFirstChild("AbilityImage")
			if abilityImage then
				local img = abilityConfig.Icon or abilityConfig.Image
				if img then
					abilityImage.Image = img
				end
			end
			
			-- ZIndex Layering (Bar over Image)
			local prog = buffFrame:FindFirstChild("Progress")
			local count = buffFrame:FindFirstChild("Count")
			
			if abilityImage then abilityImage.ZIndex = 1 end
			if prog then prog.ZIndex = 2 end
			if count then count.ZIndex = 3 end
		end
		
	end
	
	-- Note: Hover logic is now handled in the Heartbeat loop for reliability
end

-- Remove buff display
function RemoveBuffDisplay(buffBar, buffName)
	local buffFrame = buffBar:FindFirstChild("Buff_" .. buffName)
	if buffFrame then
		buffFrame:Destroy()
	end
end

function AbilityUIController.GetBuffStacks(buffName)
	local data = activeBuffs[buffName]
	if not data then return 0 end
	
	-- Check expiry
	if not data.Permanent and (not data.ExpiresAt or os.time() >= data.ExpiresAt) then
		activeBuffs[buffName] = nil
		return 0
	end
	
	return data.Stacks or 0
end

return AbilityUIController


