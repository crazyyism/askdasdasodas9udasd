local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local MusicConfig = require(ReplicatedStorage.Shared.MusicConfig)
local CollectionService = game:GetService("CollectionService")

local MusicController = {}

local player = Players.LocalPlayer
local currentSound = nil
local currentMusicId = nil -- The actual string ID (rbxassetid://...)
local lastData = nil

local DataUpdateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DataUpdateEvent")

--// Helper to find music for current location
local function GetCurrentMusic()
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if not char or (hum and hum.Health <= 0) then return nil end
	
	local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
	if not root then return nil end
	
	local pos = root.Position
	
	-- Check for boss override
	local bossOverride = player:GetAttribute("BossMusicOverride")
	if bossOverride then return bossOverride end
	
	-- Check for server override
	local override = player:GetAttribute("MusicOverride")
	if override then return override end
	
	local bestPriority = -1
	local bestMusicId = nil

	-- 1. Check for manual MusicZone parts (Tagged)
	local zones = CollectionService:GetTagged("MusicZone")
	
	-- DEBUG: print(#zones .. " MusicZones found in game")
	
	for _, zone in ipairs(zones) do
		if zone:IsA("BasePart") then
			local relative = zone.CFrame:PointToObjectSpace(pos)
			local halfSize = zone.Size / 2
			
			-- Check collision
			local isInside = math.abs(relative.X) < halfSize.X and 
			                 math.abs(relative.Y) < halfSize.Y + 10 and -- Increased buffer
			                 math.abs(relative.Z) < halfSize.Z
			
			if isInside then
				-- Look for MusicId
				local valObj = zone:FindFirstChild("MusicId") or zone:FindFirstChildWhichIsA("IntValue") or zone:FindFirstChildWhichIsA("StringValue")
				
				-- Ensure we don't accidentally use "Priority" as MusicId
				if valObj and valObj.Name == "Priority" then
					valObj = nil
					for _, child in ipairs(zone:GetChildren()) do
						if (child:IsA("IntValue") or child:IsA("StringValue")) and child.Name ~= "Priority" then
							valObj = child
							break
						end
					end
				end

				if valObj then
					local priority = zone:GetAttribute("Priority") or 0
					local priorityVal = zone:FindFirstChild("Priority")
					if priorityVal and priorityVal:IsA("ValueBase") then
						priority = priorityVal.Value
					end
					
					if priority > bestPriority then
						bestPriority = priority
						local rawId = tostring(valObj.Value)
						bestMusicId = string.find(rawId, "rbxassetid://") and rawId or "rbxassetid://" .. rawId
						-- warn("FOUND ZONE MUSIC: " .. bestMusicId .. " Priority: " .. priority)
					end
				end
			end
		end
	end
	
	-- Fallback for parts that might be named "MusicZone" but not tagged
	if not bestMusicId then
		for _, part in ipairs(workspace:GetDescendants()) do
			if part.Name == "MusicZone" and part:IsA("BasePart") then
				local relative = part.CFrame:PointToObjectSpace(pos)
				local halfSize = part.Size / 2
				if math.abs(relative.X) < halfSize.X and 
				   math.abs(relative.Y) < halfSize.Y + 10 and 
				   math.abs(relative.Z) < halfSize.Z then
					
					local valObj = part:FindFirstChild("MusicId") or part:FindFirstChildWhichIsA("IntValue")
					if valObj then
						local rawId = tostring(valObj.Value)
						bestMusicId = string.find(rawId, "rbxassetid://") and rawId or "rbxassetid://" .. rawId
						break
					end
				end
			end
		end
	end
	
	if bestMusicId then
		return bestMusicId
	end
	
	return MusicConfig.Default
end

local function FadeIn(sound, targetVolume)
	sound.Volume = 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(MusicConfig.FadeTime or 2), {Volume = targetVolume}):Play()
end

local function FadeOut(sound)
	local tween = TweenService:Create(sound, TweenInfo.new(MusicConfig.FadeTime or 2), {Volume = 0})
	tween:Play()
	tween.Completed:Connect(function()
		if sound.Volume == 0 then
			sound:Stop()
			sound:Destroy()
		end
	end)
end

function MusicController.UpdateMusic()
	local newMusicId = GetCurrentMusic()
	local isMuted = lastData and lastData.Settings and lastData.Settings.MuteMusic
	local maxVol = MusicConfig.MaxVolume or 0.5
	
	-- No change in music track
	if newMusicId == currentMusicId then 
		if currentSound then
			local targetVol = (isMuted) and 0 or maxVol
			if math.abs(currentSound.Volume - targetVol) > 0.01 then
				TweenService:Create(currentSound, TweenInfo.new(1), {Volume = targetVol}):Play()
			end
		end
		return 
	end
	
	-- Music Changed (or entered/left zone)
	currentMusicId = newMusicId
	
	-- Fade out old
	if currentSound then
		FadeOut(currentSound)
		currentSound = nil
	end
	
	-- Fade in new
	if newMusicId then
		local sound = Instance.new("Sound")
		sound.Name = "ZoneMusic"
		sound.SoundId = newMusicId
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = game:GetService("SoundService")
		
		-- Special Start Time for To The Moon
		if newMusicId == MusicConfig["ToTheMoon"] then
			sound.TimePosition = MusicConfig.ToTheMoonStartTime or 0
		end
		
		currentSound = sound
		if not isMuted then
			FadeIn(sound, maxVol)
		else
			sound:Play()
		end
	end
end

function MusicController.Start()
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		lastData = data
	end)
	
	-- Main Loop
	task.spawn(function()
		while true do
			MusicController.UpdateMusic()
			task.wait(0.5)
		end
	end)

	-- VFX Handling for "To The Moon"
	local lighting = game:GetService("Lighting")
	local ccName = "CrowdFlash"
	local cc = nil

	-- Constants for Vfx
	local baseDistance = 11
	local minOffset, maxOffset = 0, 15
	local minCurve, maxCurve = 15, 33
	local minWidth, maxWidth = 4, 10
	local lerpSpeed = 0.07

	local function lerp(a, b, t)
		return a + (b - a) * t
	end

	-- Screen Visualizer for "To The Moon"
	local VisualizerContainer = nil
	local visualizerBars = {}
	local lastVisualizerBeatIndex = -1

	local function IsInVfxWindow(timePos)
		return (timePos >= 74.6 and timePos <= 94) or (timePos >= 117.3 and timePos <= 126.3) or (timePos >= 128 and timePos <= 137.3) or (timePos >= 138)
	end

	local function createVisualizer()
		if VisualizerContainer then return end
		
		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then return end
		
		VisualizerContainer = Instance.new("ScreenGui")
		VisualizerContainer.Name = "ToTheMoonVisualizerGui"
		VisualizerContainer.ResetOnSpawn = false
		VisualizerContainer.DisplayOrder = 9999
		VisualizerContainer.IgnoreGuiInset = true
		VisualizerContainer.Parent = playerGui
		
		local numBars = 16
		local barWidth = 1 / numBars
		local gapScale = 0.8 -- 20% gap between bars so they are separate
		
		table.clear(visualizerBars)
		
		for i = 1, numBars do
			-- Top bar
			local topBar = Instance.new("Frame")
			topBar.Name = "TopBar_" .. i
			topBar.AnchorPoint = Vector2.new(0.5, 0)
			topBar.Position = UDim2.new((i - 0.5) * barWidth, 0, 0, 0)
			topBar.Size = UDim2.new(barWidth * gapScale, 0, 0, 0)
			topBar.BorderSizePixel = 0
			topBar.Parent = VisualizerContainer
			
			-- Bottom bar
			local bottomBar = Instance.new("Frame")
			bottomBar.Name = "BottomBar_" .. i
			bottomBar.AnchorPoint = Vector2.new(0.5, 1)
			bottomBar.Position = UDim2.new((i - 0.5) * barWidth, 0, 1, 0)
			bottomBar.Size = UDim2.new(barWidth * gapScale, 0, 0, 0)
			bottomBar.BorderSizePixel = 0
			bottomBar.Parent = VisualizerContainer
			
			table.insert(visualizerBars, {
				top = topBar,
				bottom = bottomBar,
				index = i
			})
		end
	end

	local function destroyVisualizer()
		if VisualizerContainer then
			VisualizerContainer:Destroy()
			VisualizerContainer = nil
		end
		table.clear(visualizerBars)
	end

	-- State Tracking
	local activeEffects = {} -- [UserId] = {Sound, Bruh3, ...}

	RunService.RenderStepped:Connect(function(dt)
		local disableStrobing = lastData and lastData.Settings and lastData.Settings.DisableStrobing
		
		-- Handle "To The Moon" Visualizer for LocalPlayer or Nearby Players
		local localIsToTheMoon = false
		local timePos = 0
		local localPos = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position
		
		for _, p in ipairs(Players:GetPlayers()) do
			local override = p:GetAttribute("MusicOverride")
			if override == MusicConfig["ToTheMoon"] then
				if p == player then
					localIsToTheMoon = true
					timePos = currentSound and currentSound.IsPlaying and currentSound.TimePosition or 0
					break
				elseif localPos and p.Character and p.Character.PrimaryPart then
					local dist = (p.Character.PrimaryPart.Position - localPos).Magnitude
					if dist <= 150 then
						localIsToTheMoon = true
						if activeEffects[p.UserId] and activeEffects[p.UserId].Sound then
							timePos = activeEffects[p.UserId].Sound.TimePosition
						end
						break
					end
				end
			end
		end
		
		local inVfxWindow = IsInVfxWindow(timePos)
		
		if localIsToTheMoon and not disableStrobing and inVfxWindow then
			createVisualizer()
			
			-- Beat Detection at constant 180 BPM based on TimePosition
			local beatInterval = 60 / 180
			local currentBeatIndex = math.floor(timePos / beatInterval)
			local isBeat = false
			if currentBeatIndex ~= lastVisualizerBeatIndex then
				lastVisualizerBeatIndex = currentBeatIndex
				isBeat = true
			end
			
			local maxHeight = 0.15 -- max 15% Y scale height
			
			-- Cycling "To The Moon" colors
			local hue = (os.clock() * 0.3) % 1
			local rainbowColor = Color3.fromHSV(hue, 0.8, 1)
			local darkRainbowColor = Color3.fromHSV(hue, 0.8, 0.18) -- Darker shade of the same rainbow hue
			
			for _, bar in ipairs(visualizerBars) do
				local i = bar.index
				
				-- Alternate colors: even is rainbow, odd is dark rainbow
				local color = (i % 2 == 0) and rainbowColor or darkRainbowColor
				
				if not bar.currentHeight then
					bar.currentHeight = 0
				end
				
				-- Snaps up to a NEW random peak ONLY on beats, decays on normal frames
				if isBeat then
					bar.sensitivity = 0.35 + 0.65 * math.random()
					bar.currentHeight = bar.sensitivity * maxHeight
				else
					bar.currentHeight = math.max(0, bar.currentHeight - (dt * 0.6))
				end
				
				local targetHeightScale = math.clamp(bar.currentHeight, 0, maxHeight)
				
				if bar.top and bar.top.Parent then
					bar.top.Size = UDim2.new(bar.top.Size.X.Scale, 0, targetHeightScale, 0)
					bar.top.BackgroundColor3 = color
				end
				if bar.bottom and bar.bottom.Parent then
					bar.bottom.Size = UDim2.new(bar.bottom.Size.X.Scale, 0, targetHeightScale, 0)
					bar.bottom.BackgroundColor3 = color
				end
			end
		else
			destroyVisualizer()
		end

		local maxIntensity = 0
		local myChar = player.Character
		local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
		
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChild("Humanoid")
			local isAlive = hum and hum.Health > 0
			
			if not root or not isAlive then 
				-- Cleanup if character lost or dead
				if activeEffects[p.UserId] then
					if activeEffects[p.UserId].Sound then activeEffects[p.UserId].Sound:Destroy() end
					if activeEffects[p.UserId].Bruh3 then activeEffects[p.UserId].Bruh3:Destroy() end
					activeEffects[p.UserId] = nil
				end
				continue 
			end
			
			local override = p:GetAttribute("MusicOverride")
			local isToTheMoon = (override == MusicConfig["ToTheMoon"])
			
			if isToTheMoon then
				-- Ensure Effect State Exists
				if not activeEffects[p.UserId] then
					activeEffects[p.UserId] = {
						LeftZ = -baseDistance, 
						RightZ = baseDistance,
						CurveSize = minCurve,
						LastBeatIndex = -1
					}
				end
				local state = activeEffects[p.UserId]
				
				-- 1. Manage Sound
				local soundObj = nil
				if p == player then
					soundObj = currentSound -- Use main 2D sound
				else
					-- Spawn 3D Sound for others
					if not state.Sound or not state.Sound.Parent then
						local s = Instance.new("Sound")
						s.SoundId = MusicConfig["ToTheMoon"]
						s.Looped = true
						s.RollOffMaxDistance = 150
						s.Volume = 0.5
						s.Parent = root
						s.Name = "MoonFX_Audio"
						s:Play()
						s.TimePosition = MusicConfig.ToTheMoonStartTime or 0
						state.Sound = s
					end
					soundObj = state.Sound
				end
				
				-- 2. Visuals (Bruh3)
				if not state.Bruh3 or not state.Bruh3.Parent then
					-- Clone Template
					local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
					local cbFolder = vfxFolder and vfxFolder:FindFirstChild("ChromaticBlast")
					local template = cbFolder and cbFolder:FindFirstChild("bruh3")
					if template then
						local b = template:Clone()
						if b:IsA("Attachment") then b.Position = Vector3.new(0,0,0) end
						b.Parent = root
						state.Bruh3 = b
					end
				end
				
				-- 3. Animate Visuals
				if state.Bruh3 and soundObj and soundObj.IsPlaying then
					local loudness = math.clamp((soundObj.PlaybackLoudness / 1300), 0, 1)
					local sTimePos = soundObj.TimePosition
					local inEmitWindow = IsInVfxWindow(sTimePos)
					
					local beatInterval = 60 / 180
					local currentBeatIndex = math.floor(sTimePos / beatInterval)
					local isBeat = (currentBeatIndex ~= state.LastBeatIndex)
					
					if not state.Intensity then
						state.Intensity = 0
					end
					
					local isNewBeat = false
					if isBeat and inEmitWindow then
						state.LastBeatIndex = currentBeatIndex
						state.Intensity = 1.0
						isNewBeat = true
					else
						state.Intensity = math.max(0, state.Intensity - dt * 3.5)
					end

					if myRoot and isAlive and inEmitWindow then
						local dist = (root.Position - myRoot.Position).Magnitude
						if dist < 100 then
							-- Distance attenuation for intensity
							local distFactor = 1 - (dist / 100)
							local localInt = state.Intensity * distFactor
							if localInt > maxIntensity then maxIntensity = localInt end
						end
					end
					
					-- Update Beams (Same Logic)
					local bruh2 = state.Bruh3:FindFirstChild("bruh2")
					local leftAtt = bruh2 and bruh2:FindFirstChild("Left")
					local rightAtt = bruh2 and bruh2:FindFirstChild("Right")
					
					if leftAtt and rightAtt then
						local offset = minOffset + (maxOffset - minOffset) * loudness
						local targetZ = baseDistance + offset
						local currentZ = lerp((state.RightZ + math.abs(state.LeftZ)) / 2, targetZ, lerpSpeed)
						state.LeftZ = -currentZ
						state.RightZ = currentZ
						
						leftAtt.Position = Vector3.new(0, 0, state.LeftZ)
						rightAtt.Position = Vector3.new(0, 0, state.RightZ)
						
						local targetCurve = minCurve + (maxCurve - minCurve) * loudness
						state.CurveSize = lerp(state.CurveSize, targetCurve, lerpSpeed)
						local targetWidth = minWidth + (maxWidth - minWidth) * loudness
						
						local beamSpeed = 0.4 + (loudness * 3)
						
						for _, child in ipairs(leftAtt:GetChildren()) do
							if child:IsA("Beam") then
								child.CurveSize0 = state.CurveSize
								child.CurveSize1 = -state.CurveSize
								child.Width0 = targetWidth
								child.Width1 = targetWidth
								child.TextureSpeed = beamSpeed
								child.Color = ColorSequence.new(Color3.fromHSV((os.clock() * 0.3) % 1, 0.8, 1))
							end
						end
						for _, child in ipairs(rightAtt:GetChildren()) do
							if child:IsA("Beam") then
								child.CurveSize0 = -state.CurveSize
								child.CurveSize1 = state.CurveSize
								child.Width0 = targetWidth
								child.Width1 = targetWidth
								child.TextureSpeed = beamSpeed
								child.Color = ColorSequence.new(Color3.fromHSV((os.clock() * 0.3) % 1, 0.8, 1))
							end
						end
						-- Particles
						local rbColor = ColorSequence.new(Color3.fromHSV((os.clock() * 0.3) % 1, 0.8, 1))
						for _, d in ipairs(state.Bruh3:GetDescendants()) do
							if d:IsA("ParticleEmitter") then d.Color = rbColor end
						end
						
						-- Emit Particles from "root" attachment on beat (180 BPM constant tempo, only within active song timeframes)
						local rootAtt = state.Bruh3:FindFirstChild("root")
						if rootAtt and isNewBeat then
							-- Harvest trigger for LocalPlayer
							if p == player then
								local evt = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("BeatHarvestEvent")
								if evt then evt:FireServer() end
							end
							
							for _, child in ipairs(rootAtt:GetChildren()) do
								local emitAmount = child:GetAttribute("emit")
								if child:IsA("ParticleEmitter") and emitAmount and type(emitAmount) == "number" then
									child:Emit(emitAmount)
								end
							end
						end
					end
				end
				
			else
				-- Not ToTheMoon: Cleanup
				if activeEffects[p.UserId] then
					if activeEffects[p.UserId].Sound then activeEffects[p.UserId].Sound:Destroy() end
					if activeEffects[p.UserId].Bruh3 then activeEffects[p.UserId].Bruh3:Destroy() end
					activeEffects[p.UserId] = nil
				end
			end
		end
		
		-- Global Screen Effects (Shake / Color Correction)
		if maxIntensity > 0 and not disableStrobing then
			if not cc or not cc.Parent then
				cc = lighting:FindFirstChild(ccName) or Instance.new("ColorCorrectionEffect")
				cc.Name = ccName
				cc.Parent = lighting
			end
			
			local intensity = maxIntensity -- Already clamped 0-1
			
			-- Shake
			if intensity > 0.1 then
				local cam = workspace.CurrentCamera
				local shakeX = (math.random() - 0.5) * intensity * 0.02 * (maxIntensity) -- Scale with intensity
				local shakeY = (math.random() - 0.5) * intensity * 0.02 * (maxIntensity)
				cam.CFrame = cam.CFrame * CFrame.Angles(shakeX, shakeY, 0)
			end
			
			-- Color
			if intensity > 0.5 then
				local hue = (os.clock() * 0.6) % 1
				local targetColor = Color3.fromHSV(hue, 0.4, 1)
				cc.TintColor = cc.TintColor:Lerp(targetColor, 0.18)
				cc.Saturation = 0.18
				cc.Brightness = intensity * 0.15
			else
				cc.TintColor = cc.TintColor:Lerp(Color3.new(1,1,1), 0.1)
				cc.Saturation = lerp(cc.Saturation, 0, 0.1)
				cc.Brightness = lerp(cc.Brightness, 0, 0.1)
			end
		else
			-- No intensity: Fade out
			if cc then
				cc.TintColor = cc.TintColor:Lerp(Color3.new(1,1,1), 0.1)
				cc.Saturation = lerp(cc.Saturation, 0, 0.1)
				cc.Brightness = lerp(cc.Brightness, 0, 0.1)
				if cc.Saturation < 0.01 and cc.Brightness < 0.01 then
					cc:Destroy()
					cc = nil
				end
			end
		end
	end)
end

return MusicController
