local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local HUDController = {}

local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)
local NotifierController = require(script.Parent:WaitForChild("NotifierController"))

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

function HUDController.Start()
	-- State Variables (Persist across resets)
	local algaeLabel, algaePerSec, progressBar, progressBarOriginalSize, biomassLabel, biomassPerSec
	
	local lastAlgae = 0
	local lastBiomass = 0
	local displayedAlgae = 0
	local displayedBiomass = 0
	local firstSync = true
	local accumAlgae = 0
	local accumBiomass = 0
	local nextRateUpdate = os.clock() + 1
	local lastKnownData = nil
	local UpdateHUD -- Forward declaration call
	
	local function SetupUI()
		local mainGui = PlayerGui:WaitForChild("Main", 10)
		if not mainGui then return end
		
		local algaeFrame = mainGui:WaitForChild("Algae", 10)
		local biomassFrame = mainGui:WaitForChild("Biomass", 10)
		
		if not algaeFrame or not biomassFrame then return end
		
		algaeLabel = algaeFrame:WaitForChild("AlgaeAmount")
		algaePerSec = algaeFrame:FindFirstChild("AlgaePerSec")
		
		-- Progress Bar Init
		-- Progress Bar Init
		local newBar = algaeFrame:FindFirstChild("Progress")
		if newBar and newBar ~= progressBar then
			progressBar = newBar
			progressBarOriginalSize = progressBar.Size
			-- Ensure anchor/position setup
			progressBar.AnchorPoint = Vector2.new(0, 0.5)
			if progressBar.Position.X.Scale == 0 and progressBar.Position.X.Offset == 0 then
				progressBar.Position = UDim2.new(0, 0, 0.5, 0)
			end
		end
		
		biomassLabel = biomassFrame:WaitForChild("BiomassAmount")
		biomassPerSec = biomassFrame:FindFirstChild("BiomassPerSec")
		
		-- Restore previous state if available
		if lastKnownData and UpdateHUD then
			UpdateHUD(lastKnownData)
		end
	end
	
	-- Initial Setup
	task.spawn(SetupUI)
	
	-- Hook Reset
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		SetupUI()
	end)
	
	-- Connect to Data Updates
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
	
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		if UpdateHUD then UpdateHUD(data) end
	end)
	
	local FishLeveledUpEvent = Remotes:WaitForChild("FishLeveledUpEvent", 5)
	if FishLeveledUpEvent then
		FishLeveledUpEvent.OnClientEvent:Connect(function(fishName, newLevel)
			NotifierController:Notify(fishName .. " leveled up to Level " .. newLevel .. "!", Color3.fromRGB(255, 215, 0))
		end)
	end
	
	local ItemAddedEvent = Remotes:WaitForChild("ItemAddedEvent", 5)
	if ItemAddedEvent then
		ItemAddedEvent.OnClientEvent:Connect(function(itemName, amount, currency, spent, newBalance)
			if lastKnownData then
				-- Update Balance targets (Heartbeat handles the smoothing)
				if currency == "Biomass" then
					lastKnownData.Biomass = newBalance
					lastBiomass = newBalance
				elseif currency == "Algae" then
					lastAlgae = newBalance 
				end
			end

			-- Notification Logic
			local itemData = EquipmentConfig[itemName]
			if itemData then
				-- Only notify for Eggs/Consumables here, as Tools/Backpacks are handled by ShopController's DataUpdateEvent
				if itemData.ProductType == "Egg" then
					if currency ~= "Item" then
						local displayAmount = (amount > 1) and (" (x" .. amount .. ")") or ""
						NotifierController:Notify("Purchased " .. (itemData.Name or itemName) .. displayAmount .. "!", Color3.fromRGB(200, 255, 200))
					end
				end
			end
		end)
	end
	
	UpdateHUD = function(data)
		if not data then return end
		lastKnownData = data
		
		-- Update Biomass Target
		if data.Biomass ~= nil then
			if firstSync then
				displayedBiomass = data.Biomass
			end
			
			local delta = data.Biomass - lastBiomass
			if delta > 0 then accumBiomass += delta end
			lastBiomass = data.Biomass
		end
		
		-- Update Algae Target
		if data.Plankton and data.MaxCapacity then
			local total = 0
			for _, count in pairs(data.Plankton) do
				total += count
			end
			
			if firstSync then
				displayedAlgae = total
				firstSync = false
			end
			
			local delta = total - lastAlgae
			if delta > 0 then accumAlgae += delta end
			lastAlgae = total
		end
		
		-- Update Statistics UI
		if HUDController.UpdateStatistics and data.Stats then
			HUDController.UpdateStatistics(data.Stats)
		end
	end
	
	-- Main UI Loop
	local RunService = game:GetService("RunService")
	RunService.Heartbeat:Connect(function(dt)
		-- Smooth Number Interpolation
		if lastKnownData then
			-- 1. Smooth Biomass
			local targetBio = lastKnownData.Biomass or 0
			if math.abs(targetBio - displayedBiomass) > 0.1 then
				-- Reaches roughly 95% in 0.4s with factor 8
				displayedBiomass = displayedBiomass + (targetBio - displayedBiomass) * math.min(dt * 8, 1)
			else
				displayedBiomass = targetBio
			end
			local useAbbr = lastKnownData and lastKnownData.Settings and lastKnownData.Settings.AbbreviateAlgae
			if biomassLabel then biomassLabel.Text = FormatNumber(displayedBiomass, useAbbr) end

			-- 2. Smooth Algae
			local targetAlgae = lastAlgae
			if math.abs(targetAlgae - displayedAlgae) > 0.1 then
				displayedAlgae = displayedAlgae + (targetAlgae - displayedAlgae) * math.min(dt * 8, 1)
			else
				displayedAlgae = targetAlgae
			end
			
			local maxCap = lastKnownData.MaxCapacity or 1
			if algaeLabel then
				algaeLabel.Text = FormatNumber(displayedAlgae, useAbbr) .. "/" .. FormatNumber(maxCap, useAbbr)
			end

			-- 3. Smooth Progress Bar
			if progressBar and progressBarOriginalSize then
				local percentage = maxCap > 0 and math.min(displayedAlgae / maxCap, 1) or 0
				local newSize = UDim2.new(
					progressBarOriginalSize.X.Scale * percentage,
					progressBarOriginalSize.X.Offset * percentage,
					progressBarOriginalSize.Y.Scale,
					progressBarOriginalSize.Y.Offset
				)
				progressBar.Size = newSize
				
				-- Red/Green tinting
				local green = 1 - percentage
				local red = percentage
				progressBar.BackgroundColor3 = Color3.new(red, green, 0)
			end
		end

		-- Rate Loop (1s Interval)
		local now = os.clock()
		if now >= nextRateUpdate then
			nextRateUpdate = now + 1
			
			-- Update UI
			local useAbbr = lastKnownData and lastKnownData.Settings and lastKnownData.Settings.AbbreviateAlgae
			if algaePerSec then
				if accumAlgae > 0 then
					algaePerSec.Visible = true
					algaePerSec.Text = "+" .. FormatNumber(accumAlgae, useAbbr) .. "/s"
				else
					algaePerSec.Visible = false
				end
			end
			
			if biomassPerSec then
				if accumBiomass > 0 then
					biomassPerSec.Visible = true
					biomassPerSec.Text = "+" .. FormatNumber(accumBiomass, useAbbr) .. "/s"
				else
					biomassPerSec.Visible = false
				end
			end
			
			-- Reset
			accumAlgae = 0
			accumBiomass = 0
		end
	end)

    -------------------------------------------------------
    -- INVENTORY SLIDE LOGIC
    -------------------------------------------------------
    local TweenService = game:GetService("TweenService")
    
    -- Structure: Main(ScreenGui) -> Main(Frame) -> ButtonHolders -> Inventory
    --                                           -> InventoryFrame
    -- Structure: Main(ScreenGui) -> Main(Frame) -> ButtonHolders -> Inventory
    --                                           -> InventoryFrame
    local mainFrame = nil
    
    local function RebindSlideLogic()
        local mainGui = player.PlayerGui:FindFirstChild("Main")
        if not mainGui then return end
        mainFrame = mainGui:FindFirstChild("Main")
        
        if mainFrame then
            local btnHolders = mainFrame:FindFirstChild("ButtonHolders")
            local invFrame = mainFrame:FindFirstChild("InventoryFrame")
            
            if btnHolders and invFrame then
                -- CRITICAL FIX: Ensure Main frame does NOT sink input (blocks mobile camera)
                if mainFrame then mainFrame.Active = false end
                
                local invBtn = btnHolders:FindFirstChild("Inventory")
                local statsBtn = btnHolders:FindFirstChild("Statistics")
                local statsFrame = mainFrame:FindFirstChild("StatisticsFrame")
                local questBtn = btnHolders:FindFirstChild("quests") or btnHolders:FindFirstChild("Quests") or btnHolders:FindFirstChild("Quest")
                local questFrame = mainFrame:FindFirstChild("QuestFrame")
                local indexBtn = btnHolders:FindFirstChild("Index")
                local indexFrame = mainFrame:FindFirstChild("IndexFrame")
                
                -- Note: Active Frame state resets on Rebind (UI is usually closed on reset anyway)
                HUDController.ActiveFrame = nil 
                
                -- Shared Config
                local hiddenPos = UDim2.new(-1, 0, 1, 0)
                local openPos = UDim2.new(0, 0, 1, 0)
                local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
                
                HUDController.ToggleFrame = function(name, frame)
                    -- Cleanup Index Details if closing Index
                    if HUDController.ActiveFrame == "Index" then
                         HUDController.DetailsOpen = false
                         if indexFrame then
                             local moreDetails = indexFrame:FindFirstChild("MoreDetails")
                             if moreDetails then moreDetails.Visible = false end
                         end
                         if HUDController.ViewLoop then 
                             HUDController.ViewLoop:Disconnect() 
                             HUDController.ViewLoop = nil 
                         end
                    end
                    
                    if HUDController.ActiveFrame == name then
                        -- Close current
                        TweenService:Create(frame, tweenInfo, {Position = hiddenPos}):Play()
                        HUDController.ActiveFrame = nil
                        GuiService.SelectedObject = nil
                    else
                        -- Close previous if exists (Use direct references)
                        if HUDController.ActiveFrame == "Inventory" and invFrame then
                             TweenService:Create(invFrame, tweenInfo, {Position = hiddenPos}):Play()
                        elseif HUDController.ActiveFrame == "Statistics" and statsFrame then
                             TweenService:Create(statsFrame, tweenInfo, {Position = hiddenPos}):Play()
                        elseif HUDController.ActiveFrame == "Quest" and questFrame then
                             TweenService:Create(questFrame, tweenInfo, {Position = hiddenPos}):Play()
                        elseif HUDController.ActiveFrame == "Index" and indexFrame then
                             TweenService:Create(indexFrame, tweenInfo, {Position = hiddenPos}):Play()
                        end
                        
                        -- Open new
                        TweenService:Create(frame, tweenInfo, {Position = openPos}):Play()
                        HUDController.ActiveFrame = name

                        -- Support Gamepad Navigation: Select first button
                        task.delay(0.1, function()
                            local firstBtn = frame:FindFirstChildWhichIsA("GuiButton", true)
                            if firstBtn and UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1) then
                                GuiService.SelectedObject = firstBtn
                            end
                        end)
                    end
                end

                if invBtn then
                    invFrame.Position = hiddenPos
                    -- Disconnect previous if any? Usually reset destroys old buttons so clean connections.
                    invBtn.MouseButton1Click:Connect(function()
                        HUDController.ToggleFrame("Inventory", invFrame)
                    end)
                end
                
                if questBtn and questFrame then
                     questFrame.Position = hiddenPos
                      questBtn.MouseButton1Click:Connect(function()
                          HUDController.ToggleFrame("Quest", questFrame)
                         -- Optional: Notify QuestController to update? 
                         -- It updates on data change anyway.
                     end)
                end
                
                if statsBtn and statsFrame then
                     statsFrame.Position = hiddenPos
                      statsBtn.MouseButton1Click:Connect(function()
                          HUDController.ToggleFrame("Statistics", statsFrame)
                     end)
                end
                
                -- Index Logic
                    if indexBtn and indexFrame then
                    indexFrame.Position = hiddenPos
                    
                    local isPopulated = false
					local FishModels = ReplicatedStorage:WaitForChild("Fishes")
					
					-- Helper to show details
					local function ShowDetails(key, data)
						local detailsFrame = indexFrame:FindFirstChild("MoreDetails")
						local mainScroll = indexFrame:FindFirstChild("ScrollingFrame")
						if not detailsFrame or not mainScroll then return end
						
						-- Setup Initial Positions for Slide
						detailsFrame.Visible = true
						detailsFrame.Position = UDim2.new(-2, 0, 0, 0) -- Start off-screen right
						mainScroll.Visible = true
						
						-- Tween In Details, Out List
						local twInfo = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
						TweenService:Create(detailsFrame, twInfo, {Position = UDim2.new(1, 0, 0, 0)}):Play()
						-- TweenService:Create(mainScroll, twInfo, {Position = UDim2.new(-2, 0, 0, 0)}):Play() -- Removed to keep visible
						
						-- Mark as details open for back button logic
						HUDController.DetailsOpen = true
						
						-- Close Button Logic (Create one or use existing if user made it? Image doesn't show back button.)
						-- We will assume clicking "Index" again closes everything, but let's see if we can add a simple back logic?
						-- For now, just show it.
						
						-- 1. Fish Name
						local fName = detailsFrame:FindFirstChild("FishName")
						if fName then fName.Text = data.Name end
						
						local fRarity = detailsFrame:FindFirstChild("FishRarity")
						if fRarity then
							local colorTrait = data.ColorTrait or "Colorless"
							local rarityStr = data.Rarity or "Common"
							
							fRarity.Text = colorTrait .. " " .. rarityStr
							
							if colorTrait == "Orange" then
								fRarity.TextColor3 = Color3.fromRGB(255, 150, 0)
							elseif colorTrait == "Pink" then
								fRarity.TextColor3 = Color3.fromRGB(255, 100, 200)
							elseif colorTrait == "Green" then
								fRarity.TextColor3 = Color3.fromRGB(100, 255, 100)
							else
								fRarity.TextColor3 = Color3.fromRGB(255, 255, 255)
							end
						end
						
						-- 2. Viewport Frame (Angles)
						local vp = detailsFrame:FindFirstChild("ViewportFrame")
						if vp then
							vp:ClearAllChildren()
							
							-- Setup Camera
							local cam = Instance.new("Camera")
							vp.CurrentCamera = cam
							cam.Parent = vp
							
							-- Clone Model
							local modelConfig = data.ModelName or key
							local templateM = FishModels:FindFirstChild(modelConfig)
							if templateM then
								local m = templateM:Clone()
								m.Parent = vp
								
								-- Position Model using logic from InventoryController
								local cf, size = m:GetBoundingBox()
								
								local currentRotation = cf - cf.Position -- Extract rotation only
								local desiredOffset = CFrame.Angles(0, math.rad(240), 0)
								
								-- Reset to 0,0,0 but keep rotation, then apply offset
								local finalCF = CFrame.new(0, 0, 0) * currentRotation * desiredOffset
								
								if m.PrimaryPart then
									m:SetPrimaryPartCFrame(finalCF)
								else
									m:PivotTo(finalCF)
								end
								
								-- Position Camera to fit
								local maxDim = math.max(size.X, size.Y, size.Z)
								local dist = maxDim * 1.1 -- Distance factor
								cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, dist), Vector3.new(0, 0, 0))
								
								-- IDLE WOBBLE ANIMATION
								if HUDController.ViewLoop then HUDController.ViewLoop:Disconnect() end
								local RunService = game:GetService("RunService")
								local seed = math.random(1, 10000)
								
								HUDController.ViewLoop = RunService.RenderStepped:Connect(function()
									if not m or not m.Parent then 
										if HUDController.ViewLoop then HUDController.ViewLoop:Disconnect() end
										return 
									end
									
									local t = os.clock()
									
									-- Gentle floating (Noise based, like FishController but scaled for UI)
									-- FishController uses floatRange = 3. We use much less for UI (e.g. 0.5)
									local speed = 0.8
									local amp = 0.8
									
									local dx = math.noise(t * speed, seed, 0) * amp
									local dy = math.noise(t * speed, seed, 100) * amp -- Up/Down
									local dz = math.noise(t * speed, seed, 200) * amp
									
									-- Gentle Rotation Sway
									local swayX = math.rad(math.sin(t * 1.5) * 5)
									local swayZ = math.rad(math.cos(t * 1.2) * 3)
									
									local offsetCF = CFrame.new(dx, dy, dz) * CFrame.Angles(swayX, 0, swayZ)
									
									if m.PrimaryPart then
										m:SetPrimaryPartCFrame(finalCF * offsetCF)
									else
										m:PivotTo(finalCF * offsetCF)
									end
									
									
									-- Special Visuals: Puppeteer Fish Spinner (Static Global Up)
									local spinner = m:FindFirstChild("SpinnerThing")
									if spinner and m.PrimaryPart then
										-- Face up 4 studs above, IGNORING fish rotation (Global Up)
										-- Used Position from PrimaryPart, but keep Rotation neutral
										spinner.CFrame = CFrame.new(m.PrimaryPart.Position + Vector3.new(0, 4, 0))
									end
								end)
							end
						end
						
						-- 3. Amount Values
						local amts = detailsFrame:FindFirstChild("AmountValues")
						if amts then
							local stats = data.BaseStats or {}
							local gs = amts:FindFirstChild("GatherSpeed")
							local ga = amts:FindFirstChild("GatherAmount")
							local ms = amts:FindFirstChild("MoveSpeed") or amts:FindFirstChild("FishSpeed")
							local ca = amts:FindFirstChild("ConvertAmount")
							local cs = amts:FindFirstChild("ConvertSpeed")
							local fa = amts:FindFirstChild("FishAttack")
							local fas = amts:FindFirstChild("FishAttackSpeed")
							
							if gs then gs.Text = "Gather Speed: " .. tostring(stats.GatherSpeed or 0) .. "s" end
							if ga then ga.Text = "Gather Amount: " .. tostring(stats.GatherAmount or 0) end
							if ms then ms.Text = "Move Speed: " .. tostring(stats.MoveSpeed or 0) end
							if ca then ca.Text = "Convert Amount: " .. tostring(stats.ConvertAmount or 0) end
							if cs then cs.Text = "Convert Speed: " .. tostring(stats.ConvertSpeed or 0) .. "s" end
							if fa then fa.Text = "Attack: " .. tostring(stats.Attack or 0) end
							if fas then fas.Text = "Attack Speed: " .. tostring(stats.AttackSpeed or 0) .. "s" end
						end
						
						-- 4. Abilities
						local abScroll = detailsFrame:FindFirstChild("ScrollingFrame")
						local abTemplate = abScroll and abScroll:FindFirstChild("AbilitiesInfoTemplate")
						
						if abScroll and abTemplate then
							abTemplate.Visible = false
							
							-- Clear old
							for _, c in ipairs(abScroll:GetChildren()) do
								if c ~= abTemplate and not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") then
									c:Destroy()
								end
							end
							
							-- Gather Abilities
							local abilitiesToList = {}
							
							-- 1. Passive
							if data.Passive then
								local passiveCfg = FishConfig.Passives and FishConfig.Passives[data.Passive]
								if passiveCfg then
									-- Clone and maybe prefix name? "Passive: Glow" or just "Glow"
									local displayCfg = table.clone(passiveCfg)
									-- displayCfg.Name = "Passive: " .. (passiveCfg.Name or "Unknown") -- Option A
									-- User asked "Does glow show... just like how they show abilities". 
									-- Usually passives are labelled "Passive: Name".
									-- But existing abilities just show Name.
									-- I'll keep it simple: Just Name unless user wants distinction.
									-- Let's add "(Passive)" to the name for clarity?
									displayCfg.Name = (passiveCfg.Name or "Unknown") .. " (Passive)"
									table.insert(abilitiesToList, displayCfg)
								end
							end

							-- 2. Main Ability (via AbilityName string)
							if data.AbilityName then
								local abCfg = FishConfig.Abilities[data.AbilityName]
								if abCfg then
									-- Create a display copy to attach the Name (which is the key in Config)
									local displayCfg = table.clone(abCfg)
									displayCfg.Name = data.AbilityName .. " (Ability)"
									table.insert(abilitiesToList, displayCfg)
								end
							end
							
							-- 3. Secondary Abilities
							if data.SecondaryAbilities then
								for _, secName in ipairs(data.SecondaryAbilities) do
									local secCfg = FishConfig.Abilities[secName]
									if secCfg then
										local displayCfg = table.clone(secCfg)
										displayCfg.Name = secName .. " (Ability)"
										table.insert(abilitiesToList, displayCfg)
									end
								end
							end

							-- 4. Legacy/Direct Table Support
							if data.Ability and type(data.Ability) == "table" then
								-- 1. Main Ability
								local displayCfg = table.clone(data.Ability)
								displayCfg.Name = (displayCfg.Name or "Ability") .. " (Ability)"
								table.insert(abilitiesToList, displayCfg)
								
								-- 2. Sub-Abilities (Nested tables with Name/Description)
								for k, v in pairs(data.Ability) do
									if type(v) == "table" and v.Name and (v.Description or v.Name) then
										if v ~= data.Ability then
											local subCfg = table.clone(v)
											subCfg.Name = (subCfg.Name or "SubAbility") .. " (Ability)"
											table.insert(abilitiesToList, subCfg) 
										end
									end
								end
							end
							
							-- Populate UI
							if #abilitiesToList > 0 then
								for _, abCfg in ipairs(abilitiesToList) do
									local item = abTemplate:Clone()
									item.Name = "Ability_" .. (abCfg.Name or "Unknown")
									item.Visible = true
									item.Parent = abScroll
									
									local aName = item:FindFirstChild("AbilityName")
									local aDesc = item:FindFirstChild("AbilityDescription")
									
									if aName then 
										aName.Text = abCfg.Name or "Ability" 
									end
									
									if aDesc then 
										if abCfg.Description and abCfg.Description ~= "" then
											aDesc.Text = abCfg.Description
										else
											aDesc.Text = "No description available."
										end
									end
								end
							end
						end
					end
                    
                    local function PopulateIndex()
                        if isPopulated then return end
                        isPopulated = true
                        
                        local scroll = indexFrame:FindFirstChild("ScrollingFrame")
                        local template = scroll and scroll:FindFirstChild("TemplateIndex")
                        if not scroll or not template then return end
                        
                        -- Hide template
                        template.Visible = false
                        
                        -- 1. Gather Data
                        local list = {}
                        for key, data in pairs(FishConfig.Fish) do
                            table.insert(list, {Key = key, Data = data})
                        end
                        
                        -- 2. Sort
                        local RarityWeights = {
                            Common = 1,
                            Rare = 2,
                            Epic = 3,
                            Legendary = 4,
                            Mythic = 5
                        }
                        
                        table.sort(list, function(a, b)
                            local rA = RarityWeights[a.Data.Rarity] or 0
                            local rB = RarityWeights[b.Data.Rarity] or 0
                            
                            if rA ~= rB then
                                return rA < rB -- Most common (1) first
                            else
                                return a.Data.Name < b.Data.Name -- Alphabetical
                            end
                        end)
                        
                        -- 3. Create Items
                        for _, itemData in ipairs(list) do
                            local clone = template:Clone()
                            clone.Name = itemData.Data.Name
                            clone.Visible = true
                            clone.Parent = scroll
                            
                            local img = clone:FindFirstChild("FishImage")
                            local name = clone:FindFirstChild("FishName")
                            local desc = clone:FindFirstChild("FishDescription")
                            
                            if img then 
                                img.Image = itemData.Data.DecalId or "" 
                                local rarityConfig = FishConfig.Rarities[itemData.Data.Rarity]
                                if rarityConfig and rarityConfig.Color then
                                    img.BackgroundColor3 = rarityConfig.Color
                                end
                            end
                            if name then name.Text = itemData.Data.Name end
                            if desc then desc.Text = itemData.Data.Description end
                            
                            -- Cleanup if needed (UIGridLayout handles pos)
							
							local moreBtn = clone:FindFirstChild("MoreDetailsButton")
							if moreBtn then
								moreBtn.MouseButton1Click:Connect(function()
									ShowDetails(itemData.Key, itemData.Data)
								end)
							end
                        end
                    end
                    
                    indexBtn.MouseButton1Click:Connect(function()
						local moreDetails = indexFrame:FindFirstChild("MoreDetails")
						local mainScroll = indexFrame:FindFirstChild("ScrollingFrame")
						
						-- Check if we are closing and need to animate details away
						-- Reset details state if closing, but don't animate separately to avoid visual conflicts
						if HUDController.ActiveFrame == "Index" then
							HUDController.DetailsOpen = false
							if moreDetails then moreDetails.Visible = false end
							
							-- Cleanup Viewport Animation
							if HUDController.ViewLoop then 
								HUDController.ViewLoop:Disconnect() 
								HUDController.ViewLoop = nil 
							end
						end
						
						-- Toggle Main Frame (Always)
						HUDController.ToggleFrame("Index", indexFrame)
						
						-- If opening, populate (isPopulated check handles duplication)
						if HUDController.ActiveFrame == "Index" then
							PopulateIndex()
							
							-- Ensure Reset State (redundant but safe)
							if moreDetails then moreDetails.Position = UDim2.new(1, 0, 0, 0); moreDetails.Visible = false end
							if mainScroll then mainScroll.Position = UDim2.new(.5, 0, 0.55, 0); mainScroll.Visible = true end
							HUDController.DetailsOpen = false
						end
                    end)
                end
                
                -- Statistics Update Logic Hook (Wrapped safely)
                    if statsFrame then
                        -- (Re-bind the UpdateStatistics function here since references changed)
                        local scrollFrame = statsFrame:FindFirstChild("ScrollingFrame")
                        local template = scrollFrame and scrollFrame:FindFirstChild("TemplateStat")
                        if template then template.Visible = false end
                        
                        local StatConfig = {
                            {Key = "BaseAlgae", Name = "Algae", Format = "Percent", Description = "Multiplies all algae collection"},

                            {Key = "BaseGreenAlgae", Name = "Green Algae", Format = "Percent", Description = "Multiplies green algae collection"},
                            {Key = "BasePinkAlgae", Name = "Pink Algae", Format = "Percent", Description = "Multiplies pink algae collection"},
                            {Key = "BaseOrangeAlgae", Name = "Orange Algae", Format = "Percent", Description = "Multiplies orange algae collection"},
                            {Key = "BaseMysticAlgae", Name = "Mystic Algae", Format = "Percent", Description = "Multiplies mystic algae collection"},
                            {Key = "CriticalChance", Name = "Critical Chance", Format = "Percent", Description = "Chance to triple algae collection"},
                            {Key = "CriticalPower", Name = "Critical Power", Format = "Percent", Description = "The final multiplier applied to critical hits (Base 3x)"},
                            {Key = "MegaCritChance", Name = "Mega Crit Chance", Format = "Percent", Description = "Chance for a Critical Hit to be a Mega Crit"},
                            {Key = "MegaCritPower", Name = "Mega Crit Power", Format = "Percent", Description = "Multiplier for Mega Critical Hits (Base 10x)"},
                             {Key = "InstantConversion", Name = "Instant Conversion", Format = "Percent", Description = "Converts algae to biomass instantly on harvest"},
                            {Key = "ConvertMultiplier", Name = "Convert Multiplier", Format = "Percent", Description = "Multiplies biomass gained from conversion"},
                            {Key = "FishMoveSpeedMultiplier", Name = "Fish Movespeed Multiplier", Format = "Percent", Description = "Multiplies fish movement speed"},
                            {Key = "ToolAlgae", Name = "Tool Algae", Format = "Percent", Description = "Multiplies algae from all sources including abilities"},
                            {Key = "ToolSpeed", Name = "Tool Speed", Format = "Percent", Description = "Boosts tool swinging and harvest speed"},
                            {Key = "PlayerWalkSpeed", Name = "Movespeed", Format = "Raw", Description = "Your movement speed"},
                            {Key = "CapacityMultiplier", Name = "Capacity", Format = "Percent", Description = "Multiplies your backpack capacity"},
                            {Key = "BiomassPerAlgae", Name = "Biomass", Format = "Percent", Description = "Increases biomass gained per algae converted"},
                        }
                        

                        
                        HUDController.UpdateStatistics = function(stats)
                            if not scrollFrame or not template or not scrollFrame.Parent then return end
                            -- Clear old items
                            for _, child in ipairs(scrollFrame:GetChildren()) do
                                if child ~= template and not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") then
                                    child:Destroy()
                                end
                            end
                            -- Populate
                             for _, entry in ipairs(StatConfig) do
                                local val = nil
                                if entry.Key == "PlayerWalkSpeed" then
                                     if stats and stats.PlayerWalkSpeed then
                                          val = stats.PlayerWalkSpeed
                                     else
                                          local char = game.Players.LocalPlayer.Character
                                          local hum = char and char:FindFirstChild("Humanoid")
                                          val = hum and hum.WalkSpeed or 21
                                     end
                                 elseif stats then
                                     val = stats[entry.Key]
                                     if entry.Key == "CriticalChance" then
                                         val = (val or 0.01) + (stats.CritChanceBonus or 0)
                                     elseif entry.Key == "CriticalPower" then
                                         val = (val or 3.0) * (1 + (stats.CritPowerBonus or 0))
                                     elseif entry.Key == "BaseAlgae" then
                                         val = 1 + (stats.BaseAlgae or 0) + (stats.PercentAlgae or 0)
                                     elseif entry.Key == "BaseGreenAlgae" then
                                         val = 1 + (stats.BaseGreenAlgae or 0) + (stats.PercentGreenAlgae or 0)
                                     elseif entry.Key == "BasePinkAlgae" then
                                         val = 1 + (stats.BasePinkAlgae or 0) + (stats.PercentPinkAlgae or 0)
                                     elseif entry.Key == "BaseOrangeAlgae" then
                                         val = 1 + (stats.BaseOrangeAlgae or 0) + (stats.PercentOrangeAlgae or 0)
                                     elseif entry.Key == "BaseMysticAlgae" then
                                         val = 1 + (stats.BaseMysticAlgae or 0) + (stats.PercentMysticAlgae or 0) 
												+ (stats.BaseGreenAlgae or 0) + (stats.PercentGreenAlgae or 0)
												+ (stats.BasePinkAlgae or 0) + (stats.PercentPinkAlgae or 0)
												+ (stats.BaseOrangeAlgae or 0) + (stats.PercentOrangeAlgae or 0)
                                     end
                                 end

                                if val then
                                    local item = template:Clone()
                                    item.Name = entry.Key
                                    item.Visible = true
                                    item.Parent = scrollFrame
                                    local nameLbl = item:FindFirstChild("StatName")
                                    local valLbl = item:FindFirstChild("StatPercent")
                                    if nameLbl then nameLbl.Text = entry.Name end
                                    if valLbl then
                                        if entry.Format == "Raw" then
                                            valLbl.Text = tostring(math.floor(val * 10 + 0.5)/10)
                                        else
                                            local percent = math.floor(val * 100 + 0.5)
                                            valLbl.Text = percent .. "%"
                                        end
                                    end
                                    

                                end
                            end
                        end
                    end
            end
        end
    end
  
    
    task.spawn(RebindSlideLogic)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        RebindSlideLogic()
    end)
end

return HUDController
