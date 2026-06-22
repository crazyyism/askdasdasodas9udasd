local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local isHolding = false
local isLoopRunning = false
local activeToolName = "Fishing Net"
local currentStats = {}
local myHarvestAnim = nil
local beamCache = {}
local isAbilityActive = false
local isGliding = false
local cleanupAbilityAction = nil

local mobileControlsGui = nil
local harvestButton = nil
local abilityButton = nil
local activeAbilityConfig = nil

local function getFieldFolder(fieldName)
	if not fieldName then return nil end
	local folder = game.Workspace:FindFirstChild(fieldName)
	if folder then return folder end
	
	local cleanName = string.lower(fieldName):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
	for _, child in ipairs(game.Workspace:GetChildren()) do
		local childClean = string.lower(child.Name):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
		if childClean == cleanName then
			return child
		end
	end
	return nil
end

if player.Character then
	mouse.TargetFilter = player.Character
end
player.CharacterAdded:Connect(function(character)
	mouse.TargetFilter = character
	isAbilityActive = false
    -- SetHarvesting will be called after it is defined below
end)

-- Wait for Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HarvestEvent = Remotes:WaitForChild("HarvestEvent")

local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
local ToolConfig = require(ReplicatedStorage.Shared.ToolConfig)
local VFXController = require(script.Parent.VFXController)

local VFXReplication = Remotes:WaitForChild("VFXReplication")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
local localData = nil

DataUpdateEvent.OnClientEvent:Connect(function(data)
	localData = data
end)

local HarvestController = {}

local function SetHarvesting(state)
	isHolding = state
	if harvestButton then
		harvestButton.BackgroundColor3 = state and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(0, 0, 0)
	end
end

player.CharacterAdded:Connect(function(character)
    SetHarvesting(false)
end)

function HarvestController.attemptHarvest()
	if isGliding then return end
	local character = player.Character
	if not character or not character.PrimaryPart then return end
	
	-- Requirement: Must have the active tool equipped
	if not character:FindFirstChild(activeToolName) then
		return
	end
	
	local rootPos = character.PrimaryPart.Position
	local closestPart = nil
	local closestDist = math.huge -- Search for closest valid one
	
	-- Iterate through all known fields to find nearest flower
	for fieldName, _ in pairs(ResourceConfig.Fields) do
		local fieldFolder = getFieldFolder(fieldName)
		if fieldFolder then
			for _, part in ipairs(fieldFolder:GetChildren()) do
				if part:IsA("BasePart") and part.Transparency < 1 then
					-- Horizontal Distance (XZ plane)
					local dx = part.Position.X - rootPos.X
					local dz = part.Position.Z - rootPos.Z
					local distXZ = math.sqrt(dx*dx + dz*dz)
					
					-- Tighten the tolerance range so the player must physically stand in the reef
					local dy = math.abs(part.Position.Y - rootPos.Y)
					
					-- 4.5 studs provides enough leniency to collect while walking between blocks
					-- without magically sucking up algae from the sand.
					if distXZ <= 4.5 and dy < 15 then
						-- Valid "Near"
						if distXZ < closestDist then
							closestDist = distXZ
							closestPart = part
						end
					end
				end
			end
		end
	end
	
	if closestPart then
		HarvestEvent:FireServer(closestPart)
		
		-- Play a local sound or tween here for immediate feedback
		local highlight = Instance.new("Highlight")
		highlight.Adornee = closestPart
		highlight.FillColor = Color3.new(1,1,1)
		highlight.FillTransparency = 0.5
		highlight.OutlineTransparency = 1
		highlight.Parent = closestPart
		game.Debris:AddItem(highlight, 0.2)
	end
end

function HarvestController.attemptRainHarvest(radius, callback, exclusionMap)
	if isGliding then return end
	local character = player.Character
	if not character or not character.PrimaryPart then return end
	local rootPos = character.PrimaryPart.Position
	
	-- Determine Start Position (Muzzles)
	local tool = character:FindFirstChild("Rainmaker")
	local startPos = rootPos -- Default
	
	if tool then
		-- Search for group in Tool or Handle
		local group = tool:FindFirstChild("Cylindricals") or tool:FindFirstChild("Cylindrical")
		if not group and tool:FindFirstChild("Handle") then
			group = tool.Handle:FindFirstChild("Cylindricals") or tool.Handle:FindFirstChild("Cylindrical")
		end
		
		if group then
			if group:IsA("BasePart") then
				startPos = group.Position
			else
				local parts = {}
				for _, c in ipairs(group:GetChildren()) do
					if c:IsA("BasePart") then table.insert(parts, c) end
				end
				if #parts > 0 then
					startPos = parts[math.random(1, #parts)].Position
				end
			end
		elseif tool:FindFirstChild("Handle") then
			startPos = tool.Handle.Position
		end
	end

	-- Gather candidates
	local candidates = {}
	local freshCandidates = {}
	
	local now = os.clock()
	
	-- Function to add candidate
	local function addCandidate(p)
		table.insert(candidates, p)
		-- Check exclusion
		if not exclusionMap or not exclusionMap[p] or (now - exclusionMap[p] > 0.25) then
			table.insert(freshCandidates, p)
		end
	end
	
	for fieldName, _ in pairs(ResourceConfig.Fields) do
		local f = game.Workspace:FindFirstChild(fieldName)
		if f then
			for _, p in ipairs(f:GetChildren()) do
				local cap = p:FindFirstChild("Capacity")
				if p:IsA("BasePart") and cap and cap.Value > 0 then
					local dist = (p.Position - rootPos).Magnitude
					if dist <= radius then
						addCandidate(p)
					end
				end
			end
		end
	end
	

	
	local VFXController = require(script.Parent.VFXController)
	
	local closestMob = _G.OrbitTarget and (_G.OrbitTarget:FindFirstChild("Hitbox") or _G.OrbitTarget.PrimaryPart)
	if not closestMob then
		local bestDist = 100
		for _, child in ipairs(workspace:GetChildren()) do
			if child:FindFirstChild("Health") and child:FindFirstChild("Level") and child.PrimaryPart then
				if child:GetAttribute("TargetingPlayer") == true then
					local targetPart = child:FindFirstChild("Hitbox") or child.PrimaryPart
					local dist = (targetPart.Position - startPos).Magnitude
					if dist < bestDist then
						bestDist = dist
						closestMob = targetPart
					end
				end
			end
		end
	end
	
	local p
	local isMobHit = false
	if closestMob and (#candidates == 0 or math.random() < 0.8) then -- 80% chance to target mob if algae exists, 100% if no algae
		p = closestMob
		isMobHit = true
	elseif #candidates > 0 then
		if #freshCandidates > 0 then
			p = freshCandidates[math.random(1, #freshCandidates)]
		else
			p = candidates[math.random(1, #candidates)]
		end
	end
	
	if p then
		-- Update Exclusion
		if not isMobHit and exclusionMap then
			exclusionMap[p] = now
		end
		
		local duration = 0.2
		
		if VFXController.PlayRainmakerBullet then
			-- Replicate to others (and self via relay)
			local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			local VFXRep = Remotes and Remotes:FindFirstChild("VFXReplication")
			if VFXRep then
				-- Args: EventName, TargetIndex(nil), CustomData(Start), ExtraData(End), ExtraData2(Duration)
				VFXRep:FireServer("RainmakerBullet", nil, startPos, p.Position, duration)
			end
		end
		
		-- Delayed Harvest & Impact Visual
		task.delay(duration, function()
			if isMobHit then
				local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
				local BulletDmg = Remotes and Remotes:FindFirstChild("RainmakerBulletDamageEvent")
				if BulletDmg then BulletDmg:FireServer(p) end
			else
				if callback then
					callback(p)
				else
					HarvestEvent:FireServer(p)
				end
			end
		end)
	else
		-- Miss Logic: Fire into sky
		local randomDir = Vector3.new(
			(math.random() - 0.5) * 4.0, 
			math.random(1.0, 2.0), 
			(math.random() - 0.5) * 4.0
		).Unit
		local skyTarget = startPos + (randomDir * 40)
		
		if VFXController.PlayRainmakerBullet then
			-- Replicate Miss
			local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			local VFXRep = Remotes and Remotes:FindFirstChild("VFXReplication")
			if VFXRep then
				VFXRep:FireServer("RainmakerBullet", nil, startPos, skyTarget, 0.2)
			end
		end
	end
end

local function startHarvestLoop()
	if isGliding then 
		isHolding = false
		return 
	end
	if isAbilityActive then return end
	if isLoopRunning then return end
	isLoopRunning = true
	
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local animator = humanoid and humanoid:FindFirstChild("Animator")
	
	-- Get initial tool name for comparison
	local initialEquippedTool = character and character:FindFirstChildWhichIsA("Tool")
	local initialToolName = initialEquippedTool and initialEquippedTool.Name or "Fishing Net"
	if initialToolName == "Rainmaker" then
		task.spawn(function()
			local VFXController = require(script.Parent.VFXController)
			local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local VFXRep = Remotes and Remotes:FindFirstChild("VFXReplication")
			
			-- Helper to Sync State
			local function setRainmakerState(state)
				-- Local Visuals
				VFXController.HandleRainmakerState(player, state)
				-- Server Relay
				if VFXRep then
					VFXRep:FireServer("RainmakerState", nil, state)
				end
			end

			-- Load Anims (Animations replicate, so keep here or move to VFX? Keep here for input control)
			local chargeTrack, fireTrack
			if animator then
				local a1 = Instance.new("Animation")
				a1.AnimationId = "rbxassetid://133655228684848" -- Charge
				chargeTrack = animator:LoadAnimation(a1)
				chargeTrack.Priority = Enum.AnimationPriority.Action4
				
				local a2 = Instance.new("Animation")
				a2.AnimationId = "rbxassetid://136672336833170" -- Fire
				fireTrack = animator:LoadAnimation(a2)
				fireTrack.Priority = Enum.AnimationPriority.Action4
				fireTrack.Looped = true
			end
			
			-- CHARGE
			setRainmakerState("Charge")

			if chargeTrack then chargeTrack:Play() end
			
			local start = os.clock()
			while os.clock() - start < 2 do
				if isAbilityActive or not isHolding then 
					isLoopRunning = false
					if chargeTrack then chargeTrack:Stop() end
					setRainmakerState("Stop")
					return 
				end
				task.wait(0.1)
			end
			
			if chargeTrack then chargeTrack:Stop() end
			
			-- FIRE
			setRainmakerState("Fire")
			
			-- BATCHING SETUP
			local batchQueue = {}
			local lastFlush = os.clock()
			local flushConn = game:GetService("RunService").Heartbeat:Connect(function()
				local now = os.clock()
				-- Ensure minimum 0.1s between flushes to prevent server jitter rejection
				local timeDiff = now - lastFlush
				if #batchQueue > 0 and timeDiff >= 0.1 and (timeDiff > 0.35 or #batchQueue >= 5) then
					HarvestEvent:FireServer(batchQueue)
					table.clear(batchQueue)
					lastFlush = now
				end
			end)
			
			if fireTrack then fireTrack:Play() end
			
			local exclusionMap = {}
			
			while isHolding and isLoopRunning do
				if isAbilityActive then
					-- Stop firing if ability starts
					isHolding = false
					isLoopRunning = false
					break
				end
				
				local curChar = player.Character
				local curTool = curChar and curChar:FindFirstChildWhichIsA("Tool")
				if not curTool or curTool.Name ~= initialToolName then break end
				
				HarvestController.attemptRainHarvest(25, function(targetPart)
					table.insert(batchQueue, targetPart)
				end, exclusionMap)
				
				local cooldown = ToolConfig["Rainmaker"] and ToolConfig["Rainmaker"].Cooldown or 0.05
				task.wait(cooldown)
			end
			
			-- STOP
			setRainmakerState("Stop")
			
			if fireTrack then fireTrack:Stop() end
			isLoopRunning = false
			
			-- Keep flush alive for cleanup of delayed shots (Wait 2s)
			task.delay(2.0, function()
				if flushConn then 
					flushConn:Disconnect()
					if #batchQueue > 0 then HarvestEvent:FireServer(batchQueue) end
				end
			end)
		end)
		return
	end

	-- STANDARD LOGIC (Animation, Poseidon, etc.)
	local myHarvestAnim = nil -- Local scope for standard loop
	
	-- Load Animation
	if animator then
		local animObj = nil
		if initialToolName == "Poseidon" then
			-- Custom Poseidon Harvest Animation
			animObj = Instance.new("Animation")
			animObj.AnimationId = "rbxassetid://101639884816704" -- Custom ID
		elseif initialToolName == "SharkScythe" then
			-- Custom Shark Scythe Harvest Animation
			animObj = Instance.new("Animation")
			animObj.AnimationId = "rbxassetid://133526167661932" 
		else
			-- Default Animation
			local animFolder = ReplicatedStorage:FindFirstChild("Animations")
			animObj = animFolder and animFolder:FindFirstChild("Collecting")
		end
		
		if animObj then
			myHarvestAnim = animator:LoadAnimation(animObj)
			if myHarvestAnim then
				myHarvestAnim.Priority = Enum.AnimationPriority.Action4
				myHarvestAnim.Looped = false
			end
			-- Cleanup temp anim object if we made it
			if initialToolName == "Poseidon" or initialToolName == "SharkScythe" then animObj:Destroy() end
		end
	end

	-- Use persistent swipe count if valid combo, otherwise reset
	if os.clock() - (activeToolName == "Poseidon" and _G.PoseidonLastSwipe or 0) > 3 then
		_G.PoseidonSwipeCount = 0
	end
	
	if os.clock() - (activeToolName == "Sunkissed Art" and _G.SunkissedLastSwipe or activeToolName == "SunkissedArt" and _G.SunkissedLastSwipe or 0) > 2.5 then
		_G.SunkissedComboTotal = 0
	end

	task.spawn(function()
		while isHolding and isLoopRunning do
			if not player.Character or not player.Character:FindFirstChild("Humanoid") then
				isLoopRunning = false
				break
			end
			
			if isAbilityActive then
				-- Stop firing if ability starts
				isHolding = false
				isLoopRunning = false
				break
			end
			
			-- Check if tool is still equipped
			local currentCharacter = player.Character -- Re-fetch character in case it changed
			local equippedTool = currentCharacter and currentCharacter:FindFirstChildWhichIsA("Tool")
			if not equippedTool or equippedTool.Name ~= initialToolName then
				-- Tool was unequipped or changed, stop loop
				break
			end
			
			if initialToolName == "Sunkissed Art" or initialToolName == "SunkissedArt" then
				if not _G.SunkissedComboTotal then _G.SunkissedComboTotal = 0 end
				
				local comboPhase = _G.SunkissedComboTotal % 3
				local animObj = Instance.new("Animation")
				if comboPhase == 0 then
					animObj.AnimationId = "rbxassetid://112629197241390"
				elseif comboPhase == 1 then
					animObj.AnimationId = "rbxassetid://90397141021684"
				else
					animObj.AnimationId = "rbxassetid://112056941137570"
				end
				
				if myHarvestAnim then
					if myHarvestAnim.IsPlaying then myHarvestAnim:Stop() end
					myHarvestAnim:Destroy()
				end
				
				myHarvestAnim = animator:LoadAnimation(animObj)
				myHarvestAnim.Priority = Enum.AnimationPriority.Action4
				myHarvestAnim.Looped = false
				animObj:Destroy()
			end

			-- Play animation
			if myHarvestAnim then
				-- Force restart to sync with gather speed
				if myHarvestAnim.IsPlaying then myHarvestAnim:Stop() end
				myHarvestAnim:Play()
			end
			
			if initialToolName == "Eviction" then
				task.spawn(function()
					local char = player.Character
					local rootPos = char and char.PrimaryPart and char.PrimaryPart.Position
					
					if rootPos then
						local AquariumController = require(script.Parent.AquariumController)
						local myTank = AquariumController.GetMyAquarium()
						if myTank then
							local closestFish = nil
							local closestDist = 15
							
							for _, child in ipairs(workspace:GetChildren()) do
								if child.Name:match("^Fish_" .. player.UserId .. "_") and child:FindFirstChild("PrimaryPart") then
									local dist = (child.PrimaryPart.Position - rootPos).Magnitude
									if dist < closestDist then
										closestDist = dist
										closestFish = child
									end
								end
							end
							
							if closestFish then
								local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
								local EvictFishEvent = Remotes:FindFirstChild("EvictFishEvent")
								if EvictFishEvent then
									local indexStr = closestFish.Name:match("Fish_%d+_(.+)")
									if indexStr then
										EvictFishEvent:FireServer(indexStr)
										
										local hl = Instance.new("Highlight")
										hl.Adornee = closestFish
										hl.FillColor = Color3.fromRGB(255, 0, 0)
										hl.Parent = closestFish
										game:GetService("Debris"):AddItem(hl, 0.5)
									end
								end
							end
						end
					end
				end)
			end
			
			if initialToolName == "Sun Staff" or initialToolName == "SunStaff" then
				task.spawn(function()
					local char = player.Character
					local rootPos = char and char.PrimaryPart and char.PrimaryPart.Position
					local tool = char and char:FindFirstChildWhichIsA("Tool")
					local handle = tool and tool:FindFirstChild("Handle")
					local targetAttach = handle and handle:FindFirstChild("TargetAttachment")
					
					if rootPos then
						local candidates = {}
						for fieldName, _ in pairs(ResourceConfig.Fields) do
							local fieldFolder = game.Workspace:FindFirstChild(fieldName)
							if fieldFolder then
								for _, p in ipairs(fieldFolder:GetChildren()) do
									local cap = p:FindFirstChild("Capacity")
									if p:IsA("BasePart") and cap and cap.Value > 0 then
										if (p.Position - rootPos).Magnitude <= 30 then
											table.insert(candidates, p)
										end
									end
								end
							end
						end
						
						if #candidates > 0 then
							local targetAlgae = candidates[math.random(1, #candidates)]
							
							local toolStats = ToolConfig[initialToolName] or ToolConfig["Sun Staff"] or {}
							local harvestR = toolStats.HarvestRadius or 5
							local rawCooldown = toolStats.Cooldown or 1.0
							local tweenTime = rawCooldown * 0.5
							
							local sunPart = tool and (tool:FindFirstChild("Sun") or tool:FindFirstChild("FloatingBall"))
							local wasAnchored = false
							
							if sunPart then
								wasAnchored = sunPart.Anchored
								sunPart.Anchored = true -- Override any physics/localscript temporarily
								
								local TweenService = game:GetService("TweenService")
								local info = TweenInfo.new(tweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
								local goalPos = targetAlgae.Position + Vector3.new(0, 2.5, 0)
								
								local tweenOut = TweenService:Create(sunPart, info, {CFrame = CFrame.new(goalPos)})
								tweenOut:Play()
							end
							
							task.wait(tweenTime)
							
							-- By calculating the physical block width, we convert raw 5 studs into '5 blocks' wide
							local spacing = math.max(targetAlgae.Size.X, targetAlgae.Size.Z)
							local actualRadius = (harvestR * spacing) + 0.1
							
							local toHarvest = {}
							for fieldName, _ in pairs(ResourceConfig.Fields) do
								local fieldFolder = game.Workspace:FindFirstChild(fieldName)
								if fieldFolder then
									for _, p in ipairs(fieldFolder:GetChildren()) do
										local cap = p:FindFirstChild("Capacity")
										if p:IsA("BasePart") and cap and cap.Value > 0 then
											-- Use the scaled HarvestRadius around the targetAlgae block
											if (p.Position - targetAlgae.Position).Magnitude <= actualRadius then
												table.insert(toHarvest, p)
											end
										end
									end
								end
							end
							
							if #toHarvest > 0 then
								local Remotes = ReplicatedStorage:WaitForChild("Remotes")
								local HarvestEvent = Remotes:WaitForChild("HarvestEvent")
								HarvestEvent:FireServer(toHarvest)
								
								-- Feedback
								for _, p in ipairs(toHarvest) do
									local hl = Instance.new("Highlight")
									hl.Adornee = p
									hl.FillColor = Color3.fromRGB(255, 200, 50)
									hl.FillTransparency = 0.5
									hl.OutlineTransparency = 1
									hl.Parent = p
									game.Debris:AddItem(hl, 0.25)
								end
							end
							
							-- Tween Back
							if sunPart then
								local elapsed = 0
								local rs = game:GetService("RunService")
								while elapsed < tweenTime do
									local dt = rs.Heartbeat:Wait()
									elapsed += dt
									local alpha = math.clamp(elapsed / tweenTime, 0, 1)
									
									-- Track the handle or head so it smoothly goes back to player
									local returnPoint = handle and handle.CFrame or (char and char.PrimaryPart.CFrame) or CFrame.new()
									local targetLocal = returnPoint * CFrame.new(0, 2, 0) -- Target slightly above handle
									
									if targetAttach then
										targetLocal = targetAttach.WorldCFrame
									end
									
									sunPart.CFrame = sunPart.CFrame:Lerp(targetLocal, alpha)
								end
								
								-- Release control back to original script
								sunPart.Anchored = wasAnchored
							end
						end
					end
				end)
			end

			if initialToolName == "Crystiken" then
				task.spawn(function()
					local char = player.Character
					local rootPos = char and char.PrimaryPart and char.PrimaryPart.Position
					local rootCF = char and char.PrimaryPart and char.PrimaryPart.CFrame
					local tool = char and char:FindFirstChildWhichIsA("Tool")
					local handle = tool and tool:FindFirstChild("Handle")
					
					if rootCF and handle then
						local toolStats = ToolConfig[initialToolName] or ToolConfig["Crystiken"] or {}
						local rawCooldown = toolStats.Cooldown or 1.0
						local shurikenLifetime = toolStats.ShurikenLifetime or 1.5
						local shurikenRange = toolStats.ShurikenRange or 20
						local duration = shurikenLifetime
						
						-- Identify the active Grip Weld holding the Tool logically
						local rightGrip = nil
						local origC1 = nil
						for _, v in ipairs(char:GetDescendants()) do
							if v:IsA("Weld") and v.Part1 == handle then
								rightGrip = v
								origC1 = v.C1
								break
							end
						end
						
						local hitBlocks = {}
						local D = shurikenRange
						local W = D * 0.4
						local elapsed = 0
						local rs = game:GetService("RunService")
						
						local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
						local HarvestEvent = Remotes:WaitForChild("HarvestEvent")
						
						local initialRotCF = CFrame.lookAt(Vector3.zero, rootCF.LookVector * Vector3.new(1,0,1))
						local currentPos = rootCF.Position

						while elapsed < duration do
							local dt = rs.Heartbeat:Wait()
							elapsed += dt
							local t = math.clamp(elapsed / duration, 0, 1)
							
							-- Custom "OutIn" Easing Style with a Linear Blend:
							local ts = game:GetService("TweenService")
							local linearT = t
							local easedT
							if t < 0.5 then
								-- First half: "Out" (fast start from hand, decelerates to an epic hang at the peak)
								easedT = ts:GetValue(t * 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) * 0.5
							else
								-- Second half: "In" (slow start from peak, accelerates violently back into hand)
								easedT = 0.5 + ts:GetValue((t - 0.5) * 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In) * 0.5
							end
							
							-- Blending 40% linear speed guarantees the shuriken softly glides through the peak instead of mathematically freezing
							local adjustedT = linearT * 0.4 + easedT * 0.6
							
							if tool.Parent ~= char then break end -- Stop cleanly if unequipped
							
							-- Tween position exactly over ~0.3s instead of snapping instantly (Lerp factor = roughly 3.33)
							local liveCF = char and char.PrimaryPart and char.PrimaryPart.CFrame or rootCF
							currentPos = currentPos:Lerp(liveCF.Position, math.clamp(dt * 10, 0, 1))
							
							local liveFlatYCF = initialRotCF + currentPos
							
							-- Parametric figure-eight loop (Boomerang) mapped to the custom Easing Curve
							local forward = D * math.sin(adjustedT * math.pi)
							local right = -W * math.sin(adjustedT * 2 * math.pi) 
							
							-- Tilt the shuriken so it lays completely flat (sideways)
							local spin = CFrame.Angles(0, linearT * -0.6 * math.pi * 16, 0)
							local tilt = CFrame.Angles(0, 0, math.rad(90))
							
							local newCF = liveFlatYCF * CFrame.new(right, 0, -forward) * spin * tilt
							
							-- Dynamically adjust the weld's offset so the Handle structurally moves strictly to the world coordinate 
							if rightGrip and rightGrip.Part0 then
								rightGrip.C1 = newCF:Inverse() * rightGrip.Part0.CFrame * rightGrip.C0
							end
							
							local currentBatch = {}
							
							-- Hit detection using the central Handle naturally traversing ANY global field
							for fieldName, _ in pairs(ResourceConfig.Fields) do
								local currentField = game.Workspace:FindFirstChild(fieldName)
								if currentField then
									for _, p in ipairs(currentField:GetChildren()) do
										local cap = p:FindFirstChild("Capacity")
										if p:IsA("BasePart") and cap and cap.Value > 0 then
											if not hitBlocks[p] then
												if (p.Position - handle.Position).Magnitude <= 4.5 then
													hitBlocks[p] = true
													table.insert(currentBatch, p)
													
													-- Instant Visual Feedback
													local hl = Instance.new("Highlight")
													hl.Adornee = p
													hl.FillColor = Color3.fromRGB(0, 255, 255)
													hl.FillTransparency = 0.5
													hl.OutlineTransparency = 1
													hl.Parent = p
													game.Debris:AddItem(hl, 0.25)
												end
											end
										end
									end
								end
							end
							
							-- Transmit live hits continuously instead of waiting for the parabola to finish
							if #currentBatch > 0 then
								HarvestEvent:FireServer(currentBatch)
							end
						end
						
						-- Seamlessly restore the physical tool handle directly to the native grip
						if rightGrip and origC1 then
							rightGrip.C1 = origC1
						end
					end
				end)
			end

			
			if initialToolName == "Poseidon" then
				task.wait(0.2) -- Delay capture to sync with animation impact
				
				-- Play Harvest SFX
				local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
				local waveFolder = vfxFolder and vfxFolder:FindFirstChild("Wave")
				local sfx = waveFolder and waveFolder:FindFirstChild("HarvestSFX")
				local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
				if sfx and character.PrimaryPart and not isSfxDisabled then
					local s = sfx:Clone()
					s.Parent = character.PrimaryPart
					s:Play()
					game.Debris:AddItem(s, 1)
				end
			elseif initialToolName == "SharkScythe" then
				task.wait(0.45)
				-- VFX & SFX via Controller
				VFXController.Play("SharkScythe", character)
				
				task.wait(0.21) -- Complete the 0.66s delay for harvest
			elseif initialToolName == "Sunkissed Art" or initialToolName == "SunkissedArt" then
				task.wait(0.2)
				
				local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
				if not isSfxDisabled and character and character.PrimaryPart then
					local comboPhase = (_G.SunkissedComboTotal or 0) % 3
					local soundName = "SunkissedArt" .. tostring(comboPhase + 1)
					
					local sFolder = ReplicatedStorage:FindFirstChild("SunkissedArt")
					local sfx = sFolder and sFolder:FindFirstChild(soundName)
					if not sfx then
						sfx = ReplicatedStorage:FindFirstChild(soundName)
					end
					
					if sfx and sfx:IsA("Sound") then
						
						local s = sfx:Clone()
						if s.Volume == 0 then s.Volume = 0.5 end
						s.Parent = character.PrimaryPart
						s:Play()
						game.Debris:AddItem(s, 10)
					else
						warn("SunkissedArt SFX missing: could not find " .. soundName .. " in ReplicatedStorage!")
					end
				end
			elseif initialToolName == "Crystiken" then
				local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
				if not isSfxDisabled and character and character.PrimaryPart then
					local sFolder = ReplicatedStorage:FindFirstChild("SFX")
					local cFolder = sFolder and sFolder:FindFirstChild("Crystiken")
					local sfx = cFolder and cFolder:FindFirstChild("SFX")
					if sfx and sfx:IsA("Sound") then
						local s = sfx:Clone()
						s.Parent = character.PrimaryPart
						s:Play()
						game.Debris:AddItem(s, 5)
					end
				end
			elseif initialToolName == "Sun Staff" or initialToolName == "SunStaff" then
				local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
				if not isSfxDisabled and character and character.PrimaryPart then
					local sFolder = ReplicatedStorage:FindFirstChild("SFX")
					local ssFolder = sFolder and sFolder:FindFirstChild("SunStaff")
					local sfx = ssFolder and ssFolder:FindFirstChild("SFX")
					if sfx and sfx:IsA("Sound") then
						local s = sfx:Clone()
						s.Parent = character.PrimaryPart
						s:Play()
						game.Debris:AddItem(s, 5)
					end
				end
			end
			
			-- Increment Logic
			if initialToolName == "Poseidon" then
				if not _G.PoseidonSwipeCount then _G.PoseidonSwipeCount = 0 end
				_G.PoseidonSwipeCount += 1
				_G.PoseidonLastSwipe = os.clock()
				
				if _G.PoseidonSwipeCount % 6 == 0 then
					local Remotes = ReplicatedStorage:WaitForChild("Remotes")
					local PoseidonWaveEvent = Remotes:FindFirstChild("PoseidonWaveEvent")
					if PoseidonWaveEvent then
						PoseidonWaveEvent:FireServer(character.PrimaryPart.CFrame)
						
						-- Trigger Local Visuals Immediately
						local VFXController = require(script.Parent.VFXController)
						VFXController.Play("Wave", nil, {StartCFrame = character.PrimaryPart.CFrame})
					end
				end
			end
			
			if initialToolName == "Sunkissed Art" or initialToolName == "SunkissedArt" then
				_G.SunkissedComboTotal = (_G.SunkissedComboTotal or 0) + 1
				_G.SunkissedLastSwipe = os.clock()
				
				local comboPhase = _G.SunkissedComboTotal % 3
				if VFXReplication then
					VFXReplication:FireServer("SunkissedMelee", nil, comboPhase)
				end
				
				-- Handle the FirstHit VFX logic
				if _G.SunkissedComboTotal % 3 == 1 then
					task.delay(0.15, function()
						local char = player.Character
						if char and char.PrimaryPart then
							local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
							local skVFX = vfxFolder and vfxFolder:FindFirstChild("SunkissedArt")
							local firstHit = skVFX and skVFX:FindFirstChild("FirstHit")
							
							if firstHit then
								local hitClone = firstHit:Clone()
								hitClone.Parent = char.PrimaryPart
								
								local isLowDetail = localData and localData.Settings and localData.Settings.LowDetailMode
								local detailMult = isLowDetail and 0.5 or 1.0
								
								for _, p in ipairs(hitClone:GetChildren()) do
									if p:IsA("ParticleEmitter") then
										local burstAmount = (p:GetAttribute("EmitCount") or p:GetAttribute("Count") or 25)
										p:Emit(math.max(1, math.floor(burstAmount * detailMult)))
									end
								end
								game.Debris:AddItem(hitClone, 3)
							end
						end
					end)
				elseif _G.SunkissedComboTotal % 3 == 2 then
					task.delay(0.1, function()
						local char = player.Character
						if char and char.PrimaryPart then
							local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
							local skVFX = vfxFolder and vfxFolder:FindFirstChild("SunkissedArt")
							local rsSK = ReplicatedStorage:FindFirstChild("SunkissedArt")
							local secondHit = (skVFX and skVFX:FindFirstChild("SecondHit")) or (rsSK and rsSK:FindFirstChild("SecondHit"))
							
							if secondHit then
								local hitClone = secondHit:Clone()
								hitClone.Parent = char.PrimaryPart
								
								local isLowDetail = localData and localData.Settings and localData.Settings.LowDetailMode
								
								for _, p in ipairs(hitClone:GetChildren()) do
									if p:IsA("ParticleEmitter") then
										if isLowDetail then
											p.Rate = math.max(1, math.floor(p.Rate * 0.5))
										end
										p.Enabled = true
									end
								end
								
								task.delay(0.3, function()
									if hitClone and hitClone.Parent then
										for _, p in ipairs(hitClone:GetChildren()) do
											if p:IsA("ParticleEmitter") then
												p.Enabled = false
											end
										end
									end
								end)
								
								game.Debris:AddItem(hitClone, 4)
							end
						end
					end)
				elseif _G.SunkissedComboTotal % 3 == 0 then
					task.delay(0.3, function()
						local char = player.Character
						if char and char.PrimaryPart then
							local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
							local SunkissedOrbEvent = Remotes:WaitForChild("SunkissedOrbEvent", 5)
							if SunkissedOrbEvent then
								SunkissedOrbEvent:FireServer(char.PrimaryPart.CFrame)
							end
						end
					end)
				end
			end
			
			if initialToolName ~= "Sun Staff" and initialToolName ~= "SunStaff" and initialToolName ~= "Crystiken" then
				HarvestController.attemptHarvest()
				if initialToolName == "Sunkissed Art" or initialToolName == "SunkissedArt" then
					local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
					local SunkissedMeleeEvent = Remotes:WaitForChild("SunkissedMeleeEvent", 2)
					if SunkissedMeleeEvent then
						SunkissedMeleeEvent:FireServer()
					end
				end
			end
			
			-- Get equipped tool's cooldown from config
			local currentTool = currentCharacter and currentCharacter:FindFirstChildWhichIsA("Tool")
			local currentToolName = currentTool and currentTool.Name or "Fishing Net"
			local toolStats = ToolConfig[currentToolName] or {}
			local cooldown = toolStats.Cooldown or 1.0
			
			if initialToolName == "Sunkissed Art" or initialToolName == "SunkissedArt" then
				local comboPhase = (_G.SunkissedComboTotal or 1) % 3
				if comboPhase == 0 then
					cooldown = 1.2
				else
					cooldown = 0.3
				end
			end
			
			-- Apply Tool Speed Stat
			-- Formula: NewCooldown = Base / SpeedMultiplier
			local speedMult = currentStats.ToolSpeed or 1.0
			cooldown = cooldown / speedMult
			
			-- Add small buffer to prevent client/server timing mismatches
			task.wait(cooldown + .15)
		end
		
		isLoopRunning = false
		if myHarvestAnim then 
			-- Allow animation to finish for SharkScythe
			if initialToolName == "SharkScythe" and myHarvestAnim.IsPlaying then
				local rem = myHarvestAnim.Length - myHarvestAnim.TimePosition
				if rem > 0 then task.wait(rem) end
			end
			
			myHarvestAnim:Stop()
			-- We don't necessarily want to destroy it here if we load it every time, 
			-- but the loop reloads it. Destroying is fine to avoid leaks.
			myHarvestAnim:Destroy()
			myHarvestAnim = nil -- Local logic
		end
	end)
end

local hasBulletBlessing = false -- Track if Bullet Blessing is active
local bulletBlessingExpiry = 0 -- Track when it expires locally

-- Listen for Bullet Blessing buff updates
local AbilityBuffUpdate = Remotes:WaitForChild("AbilityBuffUpdate")
AbilityBuffUpdate.OnClientEvent:Connect(function(buffName, stacks, expiryTime)
	if buffName == "BulletBlessing" then
		hasBulletBlessing = (stacks > 0)
		bulletBlessingExpiry = expiryTime
		
		-- Mobile Button HUD Update
		if abilityButton then
			local label = abilityButton:FindFirstChild("Label")
			if stacks > 0 then
				task.spawn(function()
					while hasBulletBlessing and os.time() < bulletBlessingExpiry do
						local rem = bulletBlessingExpiry - os.time()
						if label then label.Text = "WAIT (" .. rem .. "s)" end
						task.wait(1)
					end

					if os.time() >= bulletBlessingExpiry then
						hasBulletBlessing = false
						if label then label.Text = "Ability" end
					end
				end)
			else
				if label then label.Text = "Ability" end
			end
		end
	end
end)

function HarvestController.attemptSunkissedAbility()
	print("attemptSunkissedAbility Triggered! ActiveTool:", activeToolName)
	if isGliding then print("Aborted: Player is gliding") return end
	if activeToolName ~= "Sunkissed Art" and activeToolName ~= "SunkissedArt" then print("Aborted: Wrong tool name") return end
	if isAbilityActive then print("Aborted: Ability is already active") return end

	local now = os.clock()
	if not player:GetAttribute("NoCooldowns") then
		if _G.SunkissedAbilityLastUsed and (now - _G.SunkissedAbilityLastUsed < 30) then
			warn("The Sun's Wrath is active! Cannot use ability.")
			return
		end
	end
	_G.SunkissedAbilityLastUsed = now

	isAbilityActive = true
	isHolding = false
	SetHarvesting(false)
	
	if VFXReplication then
		VFXReplication:FireServer("SunkissedAbility")
	end
	
	local char = player.Character
	if not char then isAbilityActive = false return end
	local hum = char:FindFirstChild("Humanoid")
	local root = char.PrimaryPart
	if not hum or not root then isAbilityActive = false return end
	
	local originalWalkSpeed = 20
	if hum then
		originalWalkSpeed = hum.WalkSpeed
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end
	
	local animId = "103759166258061"
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. animId
	local animator = hum:FindFirstChild("Animator")
	local track = nil
	if animator then
		track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action4 -- Force priority over core scripts
		track:Play()
	end
	
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local skVFX = vfxFolder and vfxFolder:FindFirstChild("SunkissedArt")
	-- Fallback checking just in case
	local sunObj = (skVFX and skVFX:FindFirstChild("Sun")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("Sun"))
	
	if not sunObj then
		warn("CRITICAL: RS.VFX.SunkissedArt.Sun is MISSING! The sequence cannot render visually!")
	end
	
	local sunClone = nil
	if sunObj then
		sunClone = sunObj:Clone()
		sunClone.Position = Vector3.new(0, 20, 0)
		sunClone.Parent = root
		
		for _, p in ipairs(sunClone:GetDescendants()) do
			if p:IsA("ParticleEmitter") then
				p.Enabled = true
			end
		end
	end
	
	local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
	if not isSfxDisabled then
		local sfx1 = (skVFX and skVFX:FindFirstChild("Ability1")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("Ability1")) or ReplicatedStorage:FindFirstChild("SunkissedArtAbility1")
		if sfx1 and sfx1:IsA("Sound") then
			local s1 = sfx1:Clone()
			s1.Parent = root
			s1:Play()
			game.Debris:AddItem(s1, math.max(6, sfx1.TimeLength + 1))
		end
		
		local sfx3 = (skVFX and skVFX:FindFirstChild("Ability3")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("Ability3")) or ReplicatedStorage:FindFirstChild("SunkissedArtAbility3")
		if sfx3 and sfx3:IsA("Sound") then
			local s3 = sfx3:Clone()
			s3.Parent = root
			s3:Play()
			game.Debris:AddItem(s3, math.max(6, sfx3.TimeLength + 1))
		end
	end
	
	local beamsObj = (skVFX and skVFX:FindFirstChild("beams")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("beams"))
	if beamsObj then
		local beamsClone = beamsObj:Clone()
		beamsClone.Parent = root
		if beamsClone:IsA("Attachment") then beamsClone.Position = Vector3.new(0, -2.8, 0) end
		
		local bList = {}
		for _, b in ipairs(beamsClone:GetDescendants()) do
			if b:IsA("Beam") or b:IsA("ParticleEmitter") or b:IsA("Trail") then
				table.insert(bList, {Obj = b, OrigTrans = b.Transparency})
				local newKeypoints = {}
				for _, kp in ipairs(b.Transparency.Keypoints) do
					table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, 1, kp.Envelope))
				end
				b.Transparency = NumberSequence.new(newKeypoints)
				
				if b:IsA("ParticleEmitter") or b:IsA("Trail") then
					b.Enabled = true
				end
			end
		end
		
		task.spawn(function()
			local RunService = game:GetService("RunService")
			local startTime = os.clock()
			local duration = 3.0
			local fadeInTime = 0.5
			local fadeOutTime = 0.5
			
			local conn
			local disabledParticles = false
			
			conn = RunService.Heartbeat:Connect(function()
				if not beamsClone or not beamsClone.Parent then
					if conn then conn:Disconnect() end
					return
				end
				
				local elapsed = os.clock() - startTime
				if elapsed >= duration then
					beamsClone:Destroy()
					if conn then conn:Disconnect() end
					return
				end
				
				local alpha = 0
				if elapsed < fadeInTime then
					alpha = 1.0 - (elapsed / fadeInTime)
				elseif elapsed >= duration - fadeOutTime then
					alpha = (elapsed - (duration - fadeOutTime)) / fadeOutTime
					
					if not disabledParticles then
						disabledParticles = true
						for _, b in ipairs(beamsClone:GetDescendants()) do
							if b:IsA("ParticleEmitter") or b:IsA("Trail") then
								b.Enabled = false
							end
						end
					end
				else
					alpha = 0.0
				end
				
				for _, data in ipairs(bList) do
					local newKeypoints = {}
					for _, kp in ipairs(data.OrigTrans.Keypoints) do
						local newVal = math.clamp(kp.Value + (1 - kp.Value) * alpha, 0, 1)
						local newEnv = kp.Envelope
						if newVal + newEnv > 1.0 then newEnv = 1.0 - newVal end
						if newVal - newEnv < 0.0 then newEnv = newVal end
						
						table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, newVal, newEnv))
					end
					data.Obj.Transparency = NumberSequence.new(newKeypoints)
				end
			end)
		end)
	end
	
	task.delay(1.0, function()
		if not sunClone then return end
		local pList = {}
		for _, p in ipairs(sunClone:GetDescendants()) do
			if p:IsA("ParticleEmitter") then
				table.insert(pList, {
					Emitter = p, 
					OrigSize = p.Size, 
					OrigSpeed = p.Speed
				})
			end
		end
		
		local rightHand = char:FindFirstChild("RightHand")
		if rightHand then
			local attachWorldPos = root.CFrame:PointToWorldSpace(Vector3.new(0, 20, 0))
			local localOffset = rightHand.CFrame:PointToObjectSpace(attachWorldPos)
			
			sunClone.Parent = rightHand
			sunClone.Position = localOffset
			
			local TweenService = game:GetService("TweenService")
			local tweenDur = 1.4
			local tsInfo = TweenInfo.new(tweenDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(sunClone, tsInfo, {Position = Vector3.new(0, 0, 0)})
			tween:Play()
			
			-- Smoothly mathematically Tween the complex NumberSequence arrays to exactly sync with the movement tween!
			if #pList > 0 then
				task.spawn(function()
					local RunService = game:GetService("RunService")
					local startTime = os.clock()
					local conn
					conn = RunService.Heartbeat:Connect(function()
						if not sunClone or not sunClone.Parent then
							conn:Disconnect()
							return
						end
						
						local elapsed = os.clock() - startTime
						if elapsed >= tweenDur then
							elapsed = tweenDur
							conn:Disconnect()
						end
						
						local alpha = elapsed / tweenDur
						local easedAlpha = 1 - (1 - alpha) * (1 - alpha) -- Quad Out Easing!
						local scale = 1.0 - (0.666 * easedAlpha) -- Scales from 1.0 down to beautifully exactly ~0.33
						
						for _, data in ipairs(pList) do
							local newKeypoints = {}
							for _, kp in ipairs(data.OrigSize.Keypoints) do
								local newVal = math.max(0, kp.Value * scale)
								local newEnv = math.max(0, kp.Envelope * scale)
								if newEnv > newVal * 2 then newEnv = newVal * 2 end
								table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, newVal, newEnv))
							end
							data.Emitter.Size = NumberSequence.new(newKeypoints)
							
							data.Emitter.Speed = NumberRange.new(
								data.OrigSpeed.Min * scale,
								data.OrigSpeed.Max * scale
							)
						end
					end)
				end)
			end
		end
	end)
	
	task.delay(2.8, function()
		if sunClone then
			for _, p in ipairs(sunClone:GetDescendants()) do
				if p:IsA("ParticleEmitter") then p.Enabled = false end
			end
			game.Debris:AddItem(sunClone, 4)
		end
		
		local burstObj = skVFX and skVFX:FindFirstChild("Burst")
		if burstObj then
			local burstClone = burstObj:Clone()
			
			-- Parent directly to Terrain so the attachment perfectly stays upright natively
			burstClone.Parent = workspace.Terrain
			burstClone.WorldPosition = root.Position - Vector3.new(0, 2.7, 0)
			
			for _, p in ipairs(burstClone:GetDescendants()) do
				if p:IsA("ParticleEmitter") then p:Emit(p:GetAttribute("EmitCount") or p:GetAttribute("Count") or 40) end
			end
			game.Debris:AddItem(burstClone, 4)
			
			local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
			if not isSfxDisabled then
				local sfx2 = (skVFX and skVFX:FindFirstChild("Ability2")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("Ability2")) or ReplicatedStorage:FindFirstChild("SunkissedArtAbility2")
				if sfx2 and sfx2:IsA("Sound") then
					local s2 = sfx2:Clone()
					s2.Parent = burstClone
					s2:Play()
				end
			end
		end
		
		local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
		local SunkissedSunWrathEvent = Remotes:WaitForChild("SunkissedSunWrathEvent", 5)
		if SunkissedSunWrathEvent then
			SunkissedSunWrathEvent:FireServer(root.CFrame)
		end
		-- Screen Flash (Black and Bright Orange-Red)
		task.spawn(function()
			local Lighting = game:GetService("Lighting")
			local colorCorrection = Instance.new("ColorCorrectionEffect")
			colorCorrection.Parent = Lighting
			
			-- Flash 1: Bright fiery highlights, pure black background
			colorCorrection.Brightness = -1
			colorCorrection.Saturation = 1
			colorCorrection.TintColor = Color3.fromRGB(255, 80, 0)
			colorCorrection.Contrast = 1
			
			task.wait(0.05)
			
			-- Invert: White highlights, Orange background
			colorCorrection.Brightness = 0.5
			colorCorrection.Saturation = -1
			colorCorrection.TintColor = Color3.fromRGB(255, 150, 50)
			colorCorrection.Contrast = 0.5
			
			task.wait(0.05)
			
			-- Flash 2: Bright fiery highlights, pure black background
			colorCorrection.Brightness = -1
			colorCorrection.Saturation = 1
			colorCorrection.TintColor = Color3.fromRGB(255, 80, 0)
			colorCorrection.Contrast = 1
			
			task.wait(0.05)
			
			-- Invert: White highlights, Orange background
			colorCorrection.Brightness = 0.5
			colorCorrection.Saturation = -1
			colorCorrection.TintColor = Color3.fromRGB(255, 150, 50)
			colorCorrection.Contrast = 0.5
			
			task.wait(0.05)
			
			-- Cleanup
			colorCorrection:Destroy()
		end)
		
		-- Screen Shake (Matches Rainmaker exactly)
		local camera = workspace.CurrentCamera
		if camera then
			task.spawn(function()
				local RunService = game:GetService("RunService")
				local shakeDuration = 2.325
				local startTime = os.clock()
				
				while os.clock() - startTime < shakeDuration do
					local elapsed = os.clock() - startTime
					local progress = elapsed / shakeDuration
					local intensity = 0.5 * math.exp(-progress * 3) -- Exponential decay
					
					local randomX = (math.random() - 0.5) * 2 * intensity
					local randomY = (math.random() - 0.5) * 2 * intensity
					local randomZ = (math.random() - 0.5) * 2 * intensity
					
					camera.CFrame = camera.CFrame * CFrame.Angles(
						math.rad(randomX * 3), -- multiplier to give it some chunk
						math.rad(randomY * 3),
						math.rad(randomZ * 3)
					)
					RunService.RenderStepped:Wait()
				end
			end)
		end
	end)
	
	-- Let the animation finish its follow-through completely before giving player movement control!
	task.delay(3.5, function()
		if hum then
			hum.WalkSpeed = originalWalkSpeed
			hum.JumpPower = 50
		end
		
		if track then
			track:Stop()
			track:Destroy()
		end
		
		isAbilityActive = false
	end)
end

function HarvestController.attemptRainmakerAbility()
	if isGliding then return end
	if activeToolName ~= "Rainmaker" then return end
	if isAbilityActive then return end
	
	-- Prevent ability if Bullet Blessing is active
	if not player:GetAttribute("NoCooldowns") then
		if hasBulletBlessing then
			if os.time() < bulletBlessingExpiry then
				warn("[Rainmaker] Cannot use ability while Bullet Blessing is active!")
				return
			else
				hasBulletBlessing = false
			end
		end
	end
	
	-- Cooldown check? Handled by ability active for now.
	
	isAbilityActive = true
	isHolding = false -- Stop firing
	
	-- Stop Charge/Fire Visuals locally immediately?
	VFXController.HandleRainmakerState(player, "Stop")
	VFXReplication:FireServer("RainmakerState", nil, "Stop")
	
	-- Prevent Movement but Allow Rotation
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	local originalWalkSpeed = 21
	if hum then 
		originalWalkSpeed = hum.WalkSpeed
		hum.WalkSpeed = 0 -- Lock movement
		-- Disable Running state to prevent walk animation from playing
		hum:SetStateEnabled(Enum.HumanoidStateType.Running, false)
		-- Keep AutoRotate = true (default) to allow rotation
	end
	
	-- Continuously enforce WalkSpeed lock (prevents fish abilities from unlocking)
	local RunService = game:GetService("RunService")
	local lockConnection
	lockConnection = RunService.Heartbeat:Connect(function()
		if not isAbilityActive then
			if lockConnection then lockConnection:Disconnect() end
			return
		end
		if hum and hum.Parent then
			hum.WalkSpeed = 0 -- Continuously reset to 0
		end
	end)
	
	-- Fire Server for Logic & Replication
	-- Using VFXReplication with special name to trigger server logic + visual relay
	-- Or better: A dedicated Remote. 
	-- Let's use "RainmakerAbility" on VFXReplication for now as a trigger, 
	-- BUT server needs to handle damage logic.
	-- Ideally: FireServer("ActivateAbility", "RainmakerUltimate")
	local AbilityActivation = Remotes:WaitForChild("AbilityActivation", 5) 
	-- Check if exists, if not, fallback or error. assuming I'll create it.
	if AbilityActivation then
		AbilityActivation:FireServer("RainmakerUltimate")
	else
		-- Fallback to VFXReplication if I can hook logic there? No, separate concerns.
		-- I will create AbilityActivation in the next steps.
		warn("AbilityActivation remote missing")
	end
	
	local cleanupAbility = nil
	local tool = player.Character and player.Character:FindFirstChild("Rainmaker")
	
	cleanupAbility = function()
		if not isAbilityActive then return end
		isAbilityActive = false
		
		if lockConnection then lockConnection:Disconnect() lockConnection = nil end
		if hum then 
			hum.WalkSpeed = originalWalkSpeed
			hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
		end
		
		-- Force Stop VFX
		VFXController.HandleRainmakerState(player, "Stop")
		VFXReplication:FireServer("RainmakerState", nil, "Stop")
		
		cleanupAbility = nil
	end
	
	-- Monitor Tool Validity
	local ancestryConn
	if tool then
		ancestryConn = tool.AncestryChanged:Connect(function(_, parent)
			if parent ~= player.Character then
				if cleanupAbilityAction then cleanupAbilityAction() end
				if ancestryConn then ancestryConn:Disconnect() end
			end
		end)
	end
	
	cleanupAbilityAction = cleanupAbility
	
	task.delay(4.825, function() -- 2s start + 2.325s dur + 0.5 buffer
		if cleanupAbilityAction then cleanupAbilityAction() end
		if ancestryConn then ancestryConn:Disconnect() end
	end)
end

function HarvestController.onInput(actionName, inputState, inputObject)
	-- Only handle PC input input here (Left Click for Harvest, R for Ability)
	-- Mobile input is handled by the custom GUI buttons
	local tapToHold = true
	if localData and localData.Settings and localData.Settings.TapToHold == false then
		tapToHold = false
	end

	if inputState == Enum.UserInputState.Begin then
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.KeyCode == Enum.KeyCode.ButtonR2 or inputObject.KeyCode == Enum.KeyCode.ButtonX then
			-- PC Click / Gamepad Trigger / ButtonX Harvest
			if isAbilityActive or isGliding then return end
			
			if tapToHold then
				-- Toggle
				if isHolding then
					SetHarvesting(false)
				else
					SetHarvesting(true)
					startHarvestLoop()
				end
			else
				-- Hold
				SetHarvesting(true)
				startHarvestLoop()
			end
		elseif inputObject.KeyCode == Enum.KeyCode.R or inputObject.KeyCode == Enum.KeyCode.ButtonR1 then
			-- PC Ability Key / Gamepad R1
			print("R Key registered in HarvestController. Validating Gliding:", isGliding)
			if isGliding then return end
			if activeToolName == "Rainmaker" then
				HarvestController.attemptRainmakerAbility()
			elseif activeToolName == "Sunkissed Art" or activeToolName == "SunkissedArt" then
				HarvestController.attemptSunkissedAbility()
			else
				print("R Key pressed but activeToolName ("..tostring(activeToolName)..") has no bind.")
			end
		end
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.KeyCode == Enum.KeyCode.ButtonR2 or inputObject.KeyCode == Enum.KeyCode.ButtonX then
			if not tapToHold then
				SetHarvesting(false)
			end
		end
	end
end

-- Bind PC Inputs using UserInputService directly for simplicity alongside custom GUI
UserInputService.InputBegan:Connect(function(input, gamProcessed) 
	if gamProcessed then return end
	if input.UserInputType == Enum.UserInputType.Gamepad1 then return end -- ConsoleController handles this via CAS
	HarvestController.onInput("PCInput", Enum.UserInputState.Begin, input)
end)

UserInputService.InputEnded:Connect(function(input, gamProcessed) 
	if input.UserInputType == Enum.UserInputType.Gamepad1 then return end -- ConsoleController handles this via CAS
	HarvestController.onInput("PCInput", Enum.UserInputState.End, input)
end)

--// ===================================
--// CUSTOM MOBILE CONTROLS
--// ===================================

-- Declarations moved to top

local function createMobileControls()
	if mobileControlsGui then mobileControlsGui:Destroy() end

	local playerGui = player:WaitForChild("PlayerGui")
	mobileControlsGui = Instance.new("ScreenGui")
	mobileControlsGui.Name = "CustomMobileControls"
	mobileControlsGui.ResetOnSpawn = false
	mobileControlsGui.Enabled = true
	mobileControlsGui.IgnoreGuiInset = true
	mobileControlsGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "ControlsFrame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = mobileControlsGui

	-- Helper to create styled buttons (matching MobileControls reference)
	local function createButton(name, text, position, size, color)
		local button = Instance.new("TextButton")
		button.Name = name .. "Button"
		button.Size = size
		button.Position = position
		button.BackgroundColor3 = color
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundTransparency = 0.6
		button.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 2
		stroke.Transparency = 0.7
		stroke.Parent = button

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = button

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 0.7, 0)
		label.Position = UDim2.new(0, 0, 0.15, 0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = button

		return button
	end

	-- Create Harvest Button (M1 Equivalent)
	-- M1 Position Ref: UDim2.new(0.7, 0, 0.7, 0)
	-- Size Ref: UDim2.new(.075, 0, .125, 0)
	harvestButton = createButton(
		"Harvest", 
		"Harvest", 
		UDim2.new(0.8, 0, 0.65, 0), -- Slightly offset from M1 position to avoid conflict if both exist, or use M1 spot
		UDim2.new(0.15, 0, 0.25, 0), -- Larger for ease of use? No, user asked for M1 size: .075, .125
		Color3.fromRGB(0, 0, 0)
	)
	-- Override size to match request exactly
	harvestButton.Size = UDim2.new(0.075, 0, 0.125, 0) 
	harvestButton.Position = UDim2.new(0.75, 0, 0.7, 0) -- Adjust to typical M1 spot

	-- Create Ability Button (Block Equivalent)
	-- Block Position Ref: UDim2.new(0.775, 0, 0.5, 0)
	-- Size Ref: UDim2.new(.075, 0, .125, 0)
	abilityButton = createButton(
		"Ability", 
		"Ability", 
		UDim2.new(0.65, 0, 0.7, 0), -- To the left of Harvest
		UDim2.new(0.075, 0, 0.125, 0),
		Color3.fromRGB(0, 0, 0)
	)
	
	-- Setup Harvest Logic (Toggle to harvest)
	harvestButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if isAbilityActive or isGliding then return end
			
			local tapToHold = true
			if localData and localData.Settings and localData.Settings.TapToHold == false then
				tapToHold = false
			end

			-- Global Toggle Logic
			if tapToHold then
				if isHolding then
					SetHarvesting(false)
				else
					SetHarvesting(true)
					startHarvestLoop()
				end
			else
				SetHarvesting(true)
				startHarvestLoop()
			end
		end
	end)

	harvestButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			local tapToHold = true
			if localData and localData.Settings and localData.Settings.TapToHold == false then
				tapToHold = false
			end

			if not tapToHold then
				SetHarvesting(false)
			end
		end
	end)

	-- Setup Ability Logic (Tap to activate)
	abilityButton.Activated:Connect(function()
		if isGliding then return end
		if activeToolName == "Rainmaker" then
			HarvestController.attemptRainmakerAbility()
		elseif activeToolName == "Sunkissed Art" or activeToolName == "SunkissedArt" then
			HarvestController.attemptSunkissedAbility()
		end
		
		-- Visual feedback
		local originalColor = abilityButton.BackgroundColor3
		abilityButton.BackgroundColor3 = Color3.fromRGB(34, 55, 88) -- Blueish tint
		task.delay(0.1, function()
			abilityButton.BackgroundColor3 = originalColor
		end)
	end)
	
	-- Initially hide ability button
	abilityButton.Visible = false
	
	-- Only show controls on mobile
	mobileControlsGui.Enabled = UserInputService.TouchEnabled
end
local function updateAbilityButtonVisibility(toolName)
	if not abilityButton then return end
	
	local toolConfig = ToolConfig[toolName]
	if toolConfig and toolConfig.HasAbility then
		abilityButton.Visible = true
		abilityButton.Text = " "
        local label = abilityButton:FindFirstChild("Label")
        if label then label.Text = "Ability" end
	else
		abilityButton.Visible = false
	end
end

-- Initialize Controls
task.spawn(function()
	if UserInputService.TouchEnabled then
		createMobileControls()
		updateAbilityButtonVisibility(activeToolName)
	end
end)

-- Remove CAS Bindings
-- ContextActionService bindings removed as requested

-- Enforce Tool Holding (Bee Swarm Style)
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	-- Disable Backpack GUI so users can't manually unequip via UI
	pcall(function() 
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) 
	end)
end)

-- Mobile Tap Anywhere Logic (DISABLED - Use Harvest Button Instead)
-- Harvesting on mobile now requires using the "Harvest" button
-- This prevents accidental harvesting when moving the camera


local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")

DataUpdateEvent.OnClientEvent:Connect(function(data)
	if data.Stats then currentStats = data.Stats end
	
	if data.EquippedTool and data.EquippedTool ~= activeToolName then
		activeToolName = data.EquippedTool
		-- Update ability button visibility for new tool
		updateAbilityButtonVisibility(activeToolName)
		-- Trigger re-equip if necessary
		if player.Character then
			local hum = player.Character:FindFirstChild("Humanoid")
			local bp = player:FindFirstChild("Backpack")
			if hum and bp then
				local tool = bp:FindFirstChild(activeToolName)
				if tool then hum:EquipTool(tool) end
			end
		end
	end
end)

local function onCharacterAdded(character)
	-- Reset State on Respawn
	SetHarvesting(false)
	isLoopRunning = false

	-- 1. Setup Tool Activation Logic
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			-- Tool.Activated logic removed (Moved to Tap-to-Toggle)
		end
	end)

    character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") and child.Name == activeToolName then
            SetHarvesting(false) -- Stop if we unequip the active tool
        end
    end)
	
	-- 2. Enforce Active Tool Equip
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then return end
	
	local backpack = player:WaitForChild("Backpack")
	
	local function equipActiveTool()
		-- Unequip wrong tools?
		-- Bee Swarm style: You can ONLY hold the one tool.
		-- So if we hold something else, unequip it? 
		-- For now, just equip the right one if present.
		
		local tool = backpack:FindFirstChild(activeToolName)
		if tool then
			humanoid:EquipTool(tool)
		end
	end
	
	-- Auto-equip if it lands in backpack (e.g. unequipped or spawned)
	backpack.ChildAdded:Connect(function(child)
		if child.Name == activeToolName then
			task.wait() -- Small yield to ensure physics/parenting ready
			humanoid:EquipTool(child)
		end
	end)
	
	-- Initial Equip
	equipActiveTool()
end

if player.Character then
	onCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

function HarvestController.SetGliding(gliding)
	isGliding = gliding
	if gliding then
		SetHarvesting(false)
		HarvestController.CancelActions()
	end
end

function HarvestController.GetGliding()
	return isGliding
end

function HarvestController.CancelActions()
	SetHarvesting(false)
	if isAbilityActive and cleanupAbilityAction then
		cleanupAbilityAction()
	end
end

return HarvestController
