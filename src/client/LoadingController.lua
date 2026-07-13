local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local LoadingController = {}

local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

-- State variables
local isLoadedFinished = false
local isSkipped = false
local inPhase2 = false
local charConnection = nil
local hiddenGuis = {}
local guiAddedConnection = nil
local loadingSound = nil

-- Wave background variables
local TilesContainer = nil
local waveConnection = nil
local tilesList = {}
local transitionStartTime = nil

-- UI References
local ScreenGui
local MainFrame
local ProgressBarFill
local TitleLabel
local PercentageLabel
local SkipPrompt
local FadeOverlay
local FunnyImage

local Phase2Frame
local PlayButton
local Phase2Title
local Phase2BlackBottom
local Phase2BlackTop
local Phase2Music
local Phase2BlackBottomChildren = {}
local buttonOriginalPositions = {}

local lsCameraPart = nil
local avatarModel = nil

-- Helper: Swap Lighting configurations
local originalLightingCache = Instance.new("Folder")
local lsEffects = {}

local function applyLSLighting()
	local LightingFolder = ReplicatedStorage:WaitForChild("Lighting", 5)
	if not LightingFolder then return end
	local LSLighting = LightingFolder:FindFirstChild("LSLighting")
	if not LSLighting then return end
	
	-- Move typical lighting effects to cache to preserve them
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("Clouds") then
			child.Parent = originalLightingCache
		end
	end
	
	-- Clone and parent the LS ones
	for _, child in ipairs(LSLighting:GetChildren()) do
		local clone = child:Clone()
		table.insert(lsEffects, clone)
		clone.Parent = Lighting
	end
end

local function restoreOriginalLighting()
	-- Clean up LS effects
	for _, effect in ipairs(lsEffects) do
		effect:Destroy()
	end
	table.clear(lsEffects)
	
	-- Restore original cached effects
	for _, child in ipairs(originalLightingCache:GetChildren()) do
		child.Parent = Lighting
	end
end

-- Helper: Initialize Loading Screen UI from existing StarterGui element
local function createUI()
	local template = StarterGui:WaitForChild("LoadingScreenGui", 5)
	if template then
		template.ResetOnSpawn = false
	end

	ScreenGui = player:WaitForChild("PlayerGui"):FindFirstChild("LoadingScreenGui")
	if not ScreenGui then
		if template then
			ScreenGui = template:Clone()
			ScreenGui.Parent = player.PlayerGui
		else
			warn("LoadingScreenGui template not found in StarterGui!")
			return false
		end
	end
	ScreenGui.ResetOnSpawn = false

	MainFrame = ScreenGui:WaitForChild("MainFrame")
	FadeOverlay = ScreenGui:WaitForChild("FadeOverlay")
	ProgressBarFill = ScreenGui:WaitForChild("ProgressBarFill")
	
	local CenterContainer = MainFrame:WaitForChild("CenterContainer")
	TitleLabel = CenterContainer:WaitForChild("TitleLabel")
	PercentageLabel = MainFrame:WaitForChild("PercentageLabel")
	SkipPrompt = MainFrame:WaitForChild("SkipPrompt")
	FunnyImage = ScreenGui:FindFirstChild("FunnyImage")
	
	Phase2Frame = ScreenGui:FindFirstChild("Phase2")
	if Phase2Frame then
		PlayButton = Phase2Frame:FindFirstChild("Play")
		Phase2Title = Phase2Frame:FindFirstChild("Title")
		Phase2BlackBottom = Phase2Frame:FindFirstChild("BlackBottom")
		Phase2BlackTop = Phase2Frame:FindFirstChild("BlackTop")
		Phase2Music = Phase2Frame:FindFirstChild("Music")
		
		-- Destroy Settings and Credits buttons if they exist
		local settingsBtn = Phase2Frame:FindFirstChild("Settings")
		if settingsBtn then settingsBtn:Destroy() end
		local creditsBtn = Phase2Frame:FindFirstChild("Credits")
		if creditsBtn then creditsBtn:Destroy() end
		
		if PlayButton then
			buttonOriginalPositions[PlayButton] = PlayButton.Position
			
			if Phase2Title then
				buttonOriginalPositions[Phase2Title] = Phase2Title.Position
				Phase2Title.Visible = true
			end
			
			if Phase2BlackTop then 
				buttonOriginalPositions[Phase2BlackTop] = Phase2BlackTop.Position 
				Phase2BlackTop.Visible = true
			end
			if Phase2Music then 
				buttonOriginalPositions[Phase2Music] = Phase2Music.Position 
				Phase2Music.Visible = true
			end
			if Phase2BlackBottom then
				buttonOriginalPositions[Phase2BlackBottom] = Phase2BlackBottom.Position
				Phase2BlackBottom.Visible = true
				table.clear(Phase2BlackBottomChildren)
				for _, child in ipairs(Phase2BlackBottom:GetChildren()) do
					if child:IsA("GuiObject") and string.sub(child.Name, 1, 11) == "BlackBottom" then
						table.insert(Phase2BlackBottomChildren, child)
						buttonOriginalPositions[child] = child.Position
						child.Visible = true
					end
				end
				-- Sort by Name so BlackBottom1 -> BlackBottom2 -> BlackBottom3 order is strictly guaranteed
				table.sort(Phase2BlackBottomChildren, function(a, b)
					return a.Name < b.Name
				end)
			end
			Phase2Frame.Visible = false
			PlayButton.Visible = true
		end
	end
	
	-- Ensure starting state
	ScreenGui.Enabled = true
	ScreenGui.DisplayOrder = 99999
	MainFrame.Visible = true
	MainFrame.BackgroundTransparency = 0
	FadeOverlay.Visible = true
	FadeOverlay.BackgroundTransparency = 1
	ProgressBarFill.Visible = true
	ProgressBarFill.BackgroundTransparency = 0
	ProgressBarFill.Size = UDim2.new(0, 0, ProgressBarFill.Size.Y.Scale, ProgressBarFill.Size.Y.Offset)
	SkipPrompt.TextTransparency = 1
	TitleLabel.TextTransparency = 0
	PercentageLabel.TextTransparency = 0
	PercentageLabel.Text = "0%"
	if FunnyImage then
		FunnyImage.Visible = true
		FunnyImage.ImageTransparency = 0
		FunnyImage.Rotation = 0
	end

	return true
end

-- Helper: Animate Loading Text
local function startLoadingTextAnimation()
	task.spawn(function()
		local dots = 0
		while TitleLabel and TitleLabel.Parent and not isLoadedFinished do
			local text = "loading"
			if dots == 1 then text = "loading."
			elseif dots == 2 then text = "loading.."
			elseif dots == 3 then text = "loading..."
			end
			TitleLabel.Text = text
			dots = (dots + 1) % 4
			task.wait(0.5)
		end
	end)
end

-- Helper: Rotate FunnyImage
local function startFunnyImageRotation()
	if not FunnyImage then return end
	local RunService = game:GetService("RunService")
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if FunnyImage and FunnyImage.Parent and not isLoadedFinished then
			FunnyImage.Rotation = FunnyImage.Rotation + (90 * dt)
		else
			if connection then connection:Disconnect() end
		end
	end)
end

-- Helper: Create 16x9 Wave Grid of Tiles
local function createWaveGrid()
	if not MainFrame then return end
	
	-- Bring other MainFrame children to front (ZIndex >= 2)
	for _, child in ipairs(MainFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child.ZIndex = math.max(child.ZIndex, 2)
			for _, descendant in ipairs(child:GetDescendants()) do
				if descendant:IsA("GuiObject") then
					descendant.ZIndex = math.max(descendant.ZIndex, 2)
				end
			end
		end
	end
	
	-- Set MainFrame background to a very dark grey to make tile gaps pop
	MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	
	-- Create Frame to hold tiles container
	TilesContainer = Instance.new("Frame")
	TilesContainer.Name = "TilesContainer"
	TilesContainer.Size = UDim2.new(1, 0, 1, 0)
	TilesContainer.Position = UDim2.new(0, 0, 0, 0)
	TilesContainer.BackgroundTransparency = 1
	TilesContainer.ZIndex = 1
	TilesContainer.Parent = MainFrame
	
	local cols = 16
	local rows = 9
	table.clear(tilesList)
	
	local cellWidth = 1 / cols
	local cellHeight = 1 / rows
	
	for r = 1, rows do
		for c = 1, cols do
			local tile = Instance.new("Frame")
			tile.Name = string.format("Tile_%d_%d", c, r)
			tile.AnchorPoint = Vector2.new(0.5, 0.5)
			tile.Position = UDim2.new((c - 0.5) * cellWidth, 0, (r - 0.5) * cellHeight, 0)
			tile.BackgroundColor3 = Color3.fromRGB(5, 5, 5) -- darker grey
			tile.BorderSizePixel = 0
			tile.ZIndex = 1
			tile.Parent = TilesContainer
			
			table.insert(tilesList, {
				instance = tile,
				c = c,
				r = r,
				-- Precompute Euclidean distance to the top-right corner tile (cols, 1)
				dist = math.sqrt((c - cols)^2 + (r - 1)^2)
			})
		end
	end
end

-- Helper: Animate Wave grid tiles
local function startWaveAnimation()
	if waveConnection then
		waveConnection:Disconnect()
		waveConnection = nil
	end
	
	local RunService = game:GetService("RunService")
	local startTime = os.clock()
	
	local cols = 16
	local rows = 9
	local cellWidth = 1 / cols
	local cellHeight = 1 / rows
	
	-- Tweakable Wave Constants (User modified values preserved)
	local waveSpeed = 14        -- Speed at which the ripple sweeps across the grid
	local pulseDuration = 0.4    -- How long the swell lasts on any individual tile
	local period = 2            -- Total time between the start of successive ripples
	local wavePower = 2.5         -- Sharpness of the wave peak
	local baseScale = 0.75        -- Scale of tiles in resting state
	local peakScale = 1.65        -- Scale of tiles at peak of wave
	local scaleRange = peakScale - baseScale
	
	local baseColor = Color3.fromRGB(0,0,0) -- Darker grey color
	local peakColor = Color3.fromRGB(100, 100, 100) -- Dimmer white
	
	waveConnection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - startTime
		
		-- Calculate the fade progress if we are transitioning to phase 2
		local fadeProgress = 0
		if isLoadedFinished and transitionStartTime then
			local fadeElapsed = os.clock() - transitionStartTime
			fadeProgress = math.clamp(fadeElapsed / 0.4, 0, 1)
		end
		
		-- Calculate the time elapsed since the current ripple cycle started
		local timeSincePulseStart = t % period
		
		for _, item in ipairs(tilesList) do
			local tile = item.instance
			if tile and tile.Parent then
				-- Calculate time offset based on distance to source
				local timeDiff = timeSincePulseStart - (item.dist / waveSpeed)
				
				local intensity = 0
				if timeDiff >= 0 and timeDiff < pulseDuration then
					-- Map to [0, math.pi] for sine-based swell up and down
					local angle = (timeDiff / pulseDuration) * math.pi
					intensity = math.sin(angle) ^ wavePower
				end
				
				-- Lerp size, color, and transparency
				local currentScale = baseScale + (intensity * scaleRange)
				tile.Size = UDim2.new(cellWidth * currentScale, 0, cellHeight * currentScale, 0)
				tile.BackgroundColor3 = baseColor:Lerp(peakColor, intensity)
				tile.BackgroundTransparency = fadeProgress
			end
		end
	end)
end

-- Helper: UI Parallax for Phase 2 Buttons
local function startFloatingButtons()
	local RunService = game:GetService("RunService")
	local mouse = player:GetMouse()
	
	-- We apply a smooth lerp factor to make it feel weighty
	local currentOffsetX = 0
	local currentOffsetY = 0
	
	-- Max pixel displacement
	local maxOffset = 30 
	
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not inPhase2 or not Phase2Frame then
			if connection then connection:Disconnect() end
			return
		end
		
		local screenSize = workspace.CurrentCamera.ViewportSize
		local ndcX = 0
		local ndcY = 0
		
		if screenSize.X > 0 and screenSize.Y > 0 then
			ndcX = (mouse.X / screenSize.X) * 2 - 1
			ndcY = (mouse.Y / screenSize.Y) * 2 - 1
		end
		
		ndcX = math.clamp(ndcX, -1, 1)
		ndcY = math.clamp(ndcY, -1, 1)
		
		-- Move opposite to the mouse to match the 3D camera pan illusion
		local targetOffsetX = -ndcX * maxOffset
		local targetOffsetY = -ndcY * maxOffset
		
		-- Smooth Lerp
		currentOffsetX = currentOffsetX + (targetOffsetX - currentOffsetX) * 0.1
		currentOffsetY = currentOffsetY + (targetOffsetY - currentOffsetY) * 0.1
		
		-- Title (Furthest back - moves the least)
		if Phase2Title and buttonOriginalPositions[Phase2Title] then
			local orig = buttonOriginalPositions[Phase2Title]
			local depthMult = 0.3
			Phase2Title.Position = UDim2.new(orig.X.Scale, orig.X.Offset + (currentOffsetX * depthMult), orig.Y.Scale, orig.Y.Offset + (currentOffsetY * depthMult))
			Phase2Title.Rotation = 0
		end
		
		-- Play (Foreground - moves the most)
		if PlayButton and buttonOriginalPositions[PlayButton] then
			local orig = buttonOriginalPositions[PlayButton]
			local depthMult = 1.0
			PlayButton.Position = UDim2.new(orig.X.Scale, orig.X.Offset + (currentOffsetX * depthMult), orig.Y.Scale, orig.Y.Offset + (currentOffsetY * depthMult))
			PlayButton.Rotation = 0
		end
	end)
end

-- Helper: Pulsate skip prompt
local function startPulsatingSkipPrompt()
	task.spawn(function()
		SkipPrompt.TextTransparency = 0
		while SkipPrompt and SkipPrompt.Parent and not isLoadedFinished do
			local tweenOut = TweenService:Create(SkipPrompt, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0.6})
			local tweenIn = TweenService:Create(SkipPrompt, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0})
			
			tweenOut:Play()
			tweenOut.Completed:Wait()
			if isLoadedFinished then break end
			tweenIn:Play()
			tweenIn.Completed:Wait()
		end
	end)
end

-- Camera Parallax Movement Loop
local function startParallax(cameraPart)
	if not cameraPart then return end
	
	local baseCF = cameraPart.CFrame
	local maxTiltX = math.rad(4) -- vertical tilt limit
	local maxTiltY = math.rad(6) -- horizontal tilt limit
	local mouse = player:GetMouse()
	
	task.spawn(function()
		while inPhase2 do
			local screenSize = workspace.CurrentCamera.ViewportSize
			local mouseX = mouse.X
			local mouseY = mouse.Y
			
			local ndcX = 0
			local ndcY = 0
			
			if screenSize.X > 0 and screenSize.Y > 0 then
				ndcX = (mouseX / screenSize.X) * 2 - 1
				ndcY = (mouseY / screenSize.Y) * 2 - 1
			end
			
			ndcX = math.clamp(ndcX, -1, 1)
			ndcY = math.clamp(ndcY, -1, 1)
			
			-- Tilt camera slightly based on normalized cursor position
			local targetCF = baseCF
				* CFrame.Angles(0, -ndcX * maxTiltY, 0)
				* CFrame.Angles(-ndcY * maxTiltX, 0, 0)
				* CFrame.new(-ndcX * 1.5, -ndcY * 1.0, 0)
			
			workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(targetCF, 0.08)
			task.wait()
		end
	end)
end

-- Spawn Transition: Fade screen to black, reset camera, revert lighting, enable controls
local function startSpawnTransition(avatarModel)
	inPhase2 = false
	
	-- 1. Fade to black over 1 second
	local fadeInfo = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	FadeOverlay.ZIndex = 100 -- Ensure overlay covers the Phase 2 buttons
	TweenService:Create(FadeOverlay, fadeInfo, {BackgroundTransparency = 0}):Play()
	
	if loadingSound then
		TweenService:Create(loadingSound, fadeInfo, {Volume = 0}):Play()
	end
	
	task.wait(1.0)
	
	-- 2. Cleanup loading rig/avatar and reset camera
	if avatarModel then
		avatarModel:Destroy()
	end
	
	-- Revert to Original Lighting
	restoreOriginalLighting()
	
	-- Restore original player camera mode
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	
	-- Request server to spawn the player character
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local SpawnPlayerRequest = Remotes:WaitForChild("SpawnPlayerRequest")
	SpawnPlayerRequest:FireServer()
	
	-- Wait for the character to actually load into the game
	local char = player.Character or player.CharacterAdded:Wait()
	
	-- Wait for their appearance (clothes, accessories, packages) to load
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	
	-- Preload the exact character model assets locally to guarantee no pop-in
	pcall(function()
		ContentProvider:PreloadAsync({char})
	end)
	
	-- Re-enable Player controls now that character is loaded
	local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
	local controls = PlayerModule:GetControls()
	controls:Enable()
	
	-- Restore hidden GUIs
	if guiAddedConnection then
		guiAddedConnection:Disconnect()
		guiAddedConnection = nil
	end
	for gui, _ in pairs(hiddenGuis) do
		if gui and gui.Parent then
			gui.Enabled = true
		end
	end
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	
	-- 3. Fade from black back to transparent
	TweenService:Create(FadeOverlay, fadeInfo, {BackgroundTransparency = 1}):Play()
	task.wait(1.0)
	
	-- 4. Clean up GUI completely
	ScreenGui:Destroy()
	
	if loadingSound then
		loadingSound:Destroy()
		loadingSound = nil
	end
end

-- Preload Phase 2 data asynchronously
local function preloadPhase2Async()
	-- 1. Apply Lighting in background (does not affect black screen)
	applyLSLighting()
	
	-- 2. Fetch avatar and camera part
	local loadingStuff = workspace:WaitForChild("LoadingScreenStuff", 5)
	if loadingStuff then
		lsCameraPart = loadingStuff:FindFirstChild("Camera")
		
		local originalRig = loadingStuff:FindFirstChild("LoadingRig")
		if originalRig then
			local success, desc = pcall(function()
				return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
			end)
			
			if success and desc then
				avatarModel = Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
			else
				local char = player.Character
				if char then
					char.Archivable = true
					avatarModel = char:Clone()
				end
			end

			if avatarModel then
				avatarModel.Name = "PlayerLoadingAvatar"
				avatarModel:PivotTo(originalRig:GetPivot())
				
				local union = originalRig:FindFirstChild("Union")
				if union then
					local newUnion = union:Clone()
					newUnion.Parent = avatarModel
					
					local oldJoint = nil
					for _, joint in ipairs(originalRig:GetDescendants()) do
						if (joint:IsA("JointInstance") or joint:IsA("WeldConstraint")) and (joint.Part0 == union or joint.Part1 == union) then
							oldJoint = joint
							break
						end
					end
					
					if oldJoint and avatarModel:FindFirstChild(oldJoint.Part0.Name) and avatarModel:FindFirstChild(oldJoint.Part1.Name) then
						local newJoint = oldJoint:Clone()
						newJoint.Parent = newUnion
						if newJoint.Part0 == union then
							newJoint.Part0 = newUnion
							newJoint.Part1 = avatarModel:FindFirstChild(oldJoint.Part1.Name)
						else
							newJoint.Part1 = newUnion
							newJoint.Part0 = avatarModel:FindFirstChild(oldJoint.Part0.Name)
						end
					else
						local rightHand = avatarModel:FindFirstChild("RightHand")
						if rightHand then
							local weld = Instance.new("WeldConstraint")
							weld.Part0 = rightHand
							weld.Part1 = newUnion
							weld.Parent = newUnion
						end
					end
				end
				
				originalRig:Destroy()
				avatarModel.Parent = loadingStuff

				for _, part in ipairs(avatarModel:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
						if part.Name == "HumanoidRootPart" then
							part.Anchored = true
						else
							part.Anchored = false
						end
					end
				end

				local humanoid = avatarModel:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					
					local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
					local anim = Instance.new("Animation")
					anim.AnimationId = "rbxassetid://126803128347877"
					local track = animator:LoadAnimation(anim)
					track.Looped = true
					track:Play()
				end
			end
		end
		
		-- Start parallax behind the loading screen!
		if lsCameraPart then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
			workspace.CurrentCamera.CFrame = lsCameraPart.CFrame
			inPhase2 = true
			startParallax(lsCameraPart)
		end
	end
end

-- Transition to Phase 2: Fade out loading UI, start parallax
local function transitionToPhase2()
	isLoadedFinished = true
	transitionStartTime = os.clock()

	-- Fade out the loading screen overlay elements over 2.5 seconds
	local fadeInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(TitleLabel, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(PercentageLabel, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(SkipPrompt, fadeInfo, {TextTransparency = 1}):Play()
	if FunnyImage then
		TweenService:Create(FunnyImage, fadeInfo, {ImageTransparency = 1}):Play()
	end
	TweenService:Create(ProgressBarFill, fadeInfo, {BackgroundTransparency = 1}):Play()
	

	if Phase2Frame then
		Phase2Frame.GroupTransparency = 0
		Phase2Frame.Visible = true
		
		-- Tween Phase 2 elements into place
		local enterTweenInfo = TweenInfo.new(2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		
		-- Tween from DOWN (Y.Scale + 1.2)
		-- Bar itself tweens immediately
		if Phase2BlackBottom and buttonOriginalPositions[Phase2BlackBottom] then
			local orig = buttonOriginalPositions[Phase2BlackBottom]
			Phase2BlackBottom.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale + 1.2, orig.Y.Offset)
			TweenService:Create(Phase2BlackBottom, enterTweenInfo, {Position = orig}):Play()
		end

		-- Title and Play tween in after the bar with 0.3s gaps
		if Phase2Title and buttonOriginalPositions[Phase2Title] then
			local orig = buttonOriginalPositions[Phase2Title]
			Phase2Title.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale + 1.2, orig.Y.Offset)
			task.delay(0.3, function()
				if Phase2Title and Phase2Title.Parent then
					TweenService:Create(Phase2Title, enterTweenInfo, {Position = orig}):Play()
				end
			end)
		end
		if PlayButton and buttonOriginalPositions[PlayButton] then
			local orig = buttonOriginalPositions[PlayButton]
			PlayButton.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale + 1.2, orig.Y.Offset)
			task.delay(0.6, function()
				if PlayButton and PlayButton.Parent then
					TweenService:Create(PlayButton, enterTweenInfo, {Position = orig}):Play()
				end
			end)
		end

		-- Tween from RIGHT (X.Scale + 1.2) in increments of 0.2s, starting even later (0.8s)
		for i, child in ipairs(Phase2BlackBottomChildren) do
			if buttonOriginalPositions[child] then
				local orig = buttonOriginalPositions[child]
				child.Position = UDim2.new(orig.X.Scale + 1.2, orig.X.Offset, orig.Y.Scale, orig.Y.Offset)
				task.delay(0.8 + (i * 0.2), function()
					if child and child.Parent then
						TweenService:Create(child, enterTweenInfo, {Position = orig}):Play()
					end
				end)
			end
		end

		-- Tween from UP (Y.Scale - 1.2)
		if Phase2Music and buttonOriginalPositions[Phase2Music] then
			local orig = buttonOriginalPositions[Phase2Music]
			Phase2Music.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale - 1.2, orig.Y.Offset)
			TweenService:Create(Phase2Music, enterTweenInfo, {Position = orig}):Play()
		end
		if Phase2BlackTop and buttonOriginalPositions[Phase2BlackTop] then
			local orig = buttonOriginalPositions[Phase2BlackTop]
			Phase2BlackTop.Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale - 1.2, orig.Y.Offset)
			TweenService:Create(Phase2BlackTop, enterTweenInfo, {Position = orig}):Play()
		end
	end
	
	-- Fade out main background to reveal 3D scene (parallax starts)
	TweenService:Create(MainFrame, fadeInfo, {BackgroundTransparency = 1}):Play()
	task.wait(2.5)

	-- Destroy now-invisible Phase 1 elements
	TitleLabel:Destroy()
	PercentageLabel:Destroy()
	SkipPrompt:Destroy()
	if FunnyImage then
		FunnyImage:Destroy()
	end
	if waveConnection then
		waveConnection:Disconnect()
		waveConnection = nil
	end
	if TilesContainer then
		TilesContainer:Destroy()
		TilesContainer = nil
	end
	table.clear(tilesList)
	


	inPhase2 = true

	-- Initialize Phase 2 elements
	task.spawn(function()
		if Phase2Frame and PlayButton then
			-- Start UI Parallax after the enter tweens complete to prevent conflicts
			task.delay(1.1, function()
				if inPhase2 then
					startFloatingButtons()
				end
			end)
			
			-- Hook up the Play button
			local playConnection
			playConnection = PlayButton.MouseButton1Click:Connect(function()
				if not inPhase2 then return end
				playConnection:Disconnect()
				
				-- Stop parallax immediately
				inPhase2 = false
				
				-- Reverse all Phase 2 tweens
				local exitTweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				
				-- Tween RIGHT (X.Scale + 1.2) - Reverse order of children (Child 3 -> Child 2 -> Child 1)
				local numChildren = #Phase2BlackBottomChildren
				for i, child in ipairs(Phase2BlackBottomChildren) do
					if buttonOriginalPositions[child] then
						local orig = buttonOriginalPositions[child]
						local reverseIndex = numChildren - i -- Child 3 = 0s, Child 2 = 0.2s, Child 1 = 0.4s
						task.delay(reverseIndex * 0.2, function()
							if child and child.Parent then
								TweenService:Create(child, exitTweenInfo, {
									Position = UDim2.new(orig.X.Scale + 1.2, orig.X.Offset, orig.Y.Scale, orig.Y.Offset)
								}):Play()
							end
						end)
					end
				end

				-- Tween PlayButton DOWN (0.6s)
				if PlayButton and buttonOriginalPositions[PlayButton] then
					local orig = buttonOriginalPositions[PlayButton]
					task.delay(0.6, function()
						if PlayButton and PlayButton.Parent then
							TweenService:Create(PlayButton, exitTweenInfo, {
								Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale + 1.2, orig.Y.Offset)
							}):Play()
						end
					end)
				end
				
				-- Tween Title DOWN (0.9s)
				if Phase2Title and buttonOriginalPositions[Phase2Title] then
					local orig = buttonOriginalPositions[Phase2Title]
					task.delay(0.9, function()
						if Phase2Title and Phase2Title.Parent then
							TweenService:Create(Phase2Title, exitTweenInfo, {
								Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale + 1.2, orig.Y.Offset)
							}):Play()
						end
					end)
				end
				
				-- Tween Base Bars DOWN/UP (1.2s)
				local finalDelay = 1.2
				if Phase2BlackBottom and buttonOriginalPositions[Phase2BlackBottom] then
					local orig = buttonOriginalPositions[Phase2BlackBottom]
					task.delay(finalDelay, function()
						if Phase2BlackBottom and Phase2BlackBottom.Parent then
							TweenService:Create(Phase2BlackBottom, exitTweenInfo, {
								Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale + 1.2, orig.Y.Offset)
							}):Play()
						end
					end)
				end

				if Phase2Music and buttonOriginalPositions[Phase2Music] then
					local orig = buttonOriginalPositions[Phase2Music]
					task.delay(finalDelay, function()
						if Phase2Music and Phase2Music.Parent then
							TweenService:Create(Phase2Music, exitTweenInfo, {
								Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale - 1.2, orig.Y.Offset)
							}):Play()
						end
					end)
				end
				
				if Phase2BlackTop and buttonOriginalPositions[Phase2BlackTop] then
					local orig = buttonOriginalPositions[Phase2BlackTop]
					task.delay(finalDelay, function()
						if Phase2BlackTop and Phase2BlackTop.Parent then
							TweenService:Create(Phase2BlackTop, exitTweenInfo, {
								Position = UDim2.new(orig.X.Scale, orig.X.Offset, orig.Y.Scale - 1.2, orig.Y.Offset)
							}):Play()
						end
					end)
				end
				
				-- Wait for the absolute longest tween + delay to finish before starting spawn transition
				task.wait(finalDelay + 0.8)
				
				startSpawnTransition(avatarModel)
			end)
		else
			-- Fallback to clicking anywhere
			local phase2InputConnection
			phase2InputConnection = UserInputService.InputBegan:Connect(function(input, gpe)
				if not inPhase2 then return end
				if gpe then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					phase2InputConnection:Disconnect()
					startSpawnTransition(avatarModel)
				end
			end)
		end
	end)
end

function LoadingController.Start()
	-- 1. Create interface
	local success = createUI()
	if not success then return end
	
	-- Initialize and start wave grid background
	createWaveGrid()
	startWaveAnimation()
	
	-- Start background animations
	startLoadingTextAnimation()
	startFunnyImageRotation()
	
	-- Preload Phase 2 in the background to prevent hitches at 100%
	task.spawn(preloadPhase2Async)

	-- Create and play loading background music
	loadingSound = Instance.new("Sound")
	loadingSound.SoundId = "rbxassetid://139307780959520"
	loadingSound.Looped = true
	loadingSound.Volume = 1.5
	loadingSound.Parent = workspace
	loadingSound:Play()


	-- Hide all other UI and CoreGui
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	
	local playerGui = player:WaitForChild("PlayerGui")
	local function hideGui(gui)
		if gui:IsA("ScreenGui") and gui.Name ~= "LoadingScreenGui" and gui.Name ~= "RobloxGui" then
			hiddenGuis[gui] = true
			gui.Enabled = false
		end
	end
	
	for _, gui in ipairs(playerGui:GetChildren()) do
		hideGui(gui)
	end
	guiAddedConnection = playerGui.ChildAdded:Connect(hideGui)

	-- Disable player controls immediately at start
	local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
	local controls = PlayerModule:GetControls()
	controls:Disable()

	-- 2. Gather EVERYTHING to preload (Animations, Sounds, Textures, Meshes, UI, VFX)
	local servicesToSearch = {
		ReplicatedStorage,
		ReplicatedFirst,
		game:GetService("Lighting"),
		game:GetService("StarterGui"),
		game:GetService("StarterPlayer"),
		game:GetService("SoundService")
	}
	
	local loadingStuff = workspace:FindFirstChild("LoadingScreenStuff")
	if loadingStuff then
		table.insert(servicesToSearch, loadingStuff)
	end
	
	local npcsFolder = workspace:FindFirstChild("NPCs")
	if npcsFolder then
		table.insert(servicesToSearch, npcsFolder)
	end

	local preloadableClasses = {
		"Animation", "Decal", "Texture", "Sound", "MeshPart", "SpecialMesh", 
		"ImageLabel", "ImageButton", "ParticleEmitter", "Trail", "Beam",
		"SurfaceAppearance", "VideoFrame", "Shirt", "Pants", "ShirtGraphic", "CharacterMesh"
	}

	local assetsToLoad = {}
	for _, service in ipairs(servicesToSearch) do
		for _, desc in ipairs(service:GetDescendants()) do
			for _, className in ipairs(preloadableClasses) do
				if desc:IsA(className) then
					table.insert(assetsToLoad, desc)
					break
				end
			end
		end
	end

	-- 3. Concurrent Timer: Allow skip after 15 seconds
	local allowSkip = false
	local skipInputConnection = nil
	task.spawn(function()
		task.wait(15)
		if not isLoadedFinished and not isSkipped then
			allowSkip = true
			startPulsatingSkipPrompt()
			
			-- Listen for skip clicks anywhere on the frame
			skipInputConnection = UserInputService.InputBegan:Connect(function(input, gpe)
				if not allowSkip or isSkipped or isLoadedFinished then return end
				if gpe then return end
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					isSkipped = true
					if skipInputConnection then
						skipInputConnection:Disconnect()
					end
					transitionToPhase2()
				end
			end)
		end
	end)

	-- 4. Preloading sequence
	local totalAssets = #assetsToLoad
	if totalAssets > 0 then
		local loadedCount = 0
		
		pcall(function()
			ContentProvider:PreloadAsync(assetsToLoad, function(contentId, assetFetchStatus)
				if isSkipped then return end
				loadedCount = loadedCount + 1
				local progress = loadedCount / totalAssets
				
				-- Smoothly set size and percentage text
				ProgressBarFill.Size = UDim2.new(progress, 0, 0.019, 0)
				PercentageLabel.Text = math.floor(progress * 100) .. "%"
			end)
		end)
	end

	-- Finalize loading bar if not skipped
	if not isSkipped then
		ProgressBarFill.Size = UDim2.new(1, 0, 0.019, 0)
		PercentageLabel.Text = "100%"
		task.wait(0.4)
		
		if skipInputConnection then
			skipInputConnection:Disconnect()
		end
		
		transitionToPhase2()
	end
	
	-- Yield client script initialization until the player has actually spawned into the game.
	-- This prevents 'Infinite yield possible' warnings in ShopController and other UI controllers.
	if not player.Character then
		player.CharacterAdded:Wait()
	end
end

return LoadingController
