local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")

local LoadingController = {}

local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

-- State variables
local isLoadedFinished = false
local isSkipped = false
local inPhase2 = false
local charConnection = nil

-- UI References
local ScreenGui
local MainFrame
local ProgressBarFill
local ProgressContainer
local ProgressStroke
local TitleLabel
local SubtitleLabel
local StatusLabel
local PercentageLabel
local SkipPrompt
local FadeOverlay

-- Helper: Swap Lighting configurations
local function applyLighting(lightingFolder)
	if not lightingFolder then return end
	
	-- Clear typical lighting effects that are swapped
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("Clouds") then
			child:Destroy()
		end
	end
	
	-- Clone and parent the new ones
	for _, child in ipairs(lightingFolder:GetChildren()) do
		child:Clone().Parent = Lighting
	end
end

-- Helper: Create Loading Screen UI programmatically
local function createUI()
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "LoadingScreenGui"
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.DisplayOrder = 99999
	ScreenGui.ResetOnSpawn = false
	ScreenGui.Parent = player:WaitForChild("PlayerGui")

	MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = UDim2.new(1, 0, 1, 0)
	MainFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
	MainFrame.BorderSizePixel = 0
	MainFrame.Parent = MainFrame

	local BackgroundGradient = Instance.new("UIGradient")
	BackgroundGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 10, 18)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 18, 30))
	})
	BackgroundGradient.Rotation = 45
	BackgroundGradient.Parent = MainFrame
	MainFrame.Parent = ScreenGui

	-- Center Container for Logo / Subtitle
	local CenterContainer = Instance.new("Frame")
	CenterContainer.Name = "CenterContainer"
	CenterContainer.Size = UDim2.new(0.6, 0, 0.4, 0)
	CenterContainer.Position = UDim2.new(0.2, 0, 0.2, 0)
	CenterContainer.BackgroundTransparency = 1
	CenterContainer.Parent = MainFrame

	TitleLabel = Instance.new("TextLabel")
	TitleLabel.Name = "TitleLabel"
	TitleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	TitleLabel.Position = UDim2.new(0, 0, 0, 0)
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.Font = Enum.Font.Montserrat
	TitleLabel.Text = "FISH HATCHERY SIMULATOR"
	TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TitleLabel.TextSize = 42
	TitleLabel.TextWrapped = true
	TitleLabel.RichText = true
	TitleLabel.Parent = CenterContainer

	SubtitleLabel = Instance.new("TextLabel")
	SubtitleLabel.Name = "SubtitleLabel"
	SubtitleLabel.Size = UDim2.new(1, 0, 0.3, 0)
	SubtitleLabel.Position = UDim2.new(0, 0, 0.5, 0)
	SubtitleLabel.BackgroundTransparency = 1
	SubtitleLabel.Font = Enum.Font.GothamMedium
	SubtitleLabel.Text = "PREPARE TO DIVE IN..."
	SubtitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
	SubtitleLabel.TextSize = 16
	SubtitleLabel.TextWrapped = true
	SubtitleLabel.Parent = CenterContainer

	-- Progress Bar Container
	ProgressContainer = Instance.new("Frame")
	ProgressContainer.Name = "ProgressContainer"
	ProgressContainer.Size = UDim2.new(0.5, 0, 0.08, 0)
	ProgressContainer.Position = UDim2.new(0.25, 0, 0.68, 0)
	ProgressContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ProgressContainer.BackgroundTransparency = 0.95
	ProgressContainer.BorderSizePixel = 0
	ProgressContainer.Parent = MainFrame

	local ProgressCorner = Instance.new("UICorner")
	ProgressCorner.CornerRadius = UDim.new(0.5, 0)
	ProgressCorner.Parent = ProgressContainer

	ProgressStroke = Instance.new("UIStroke")
	ProgressStroke.Color = Color3.fromRGB(255, 255, 255)
	ProgressStroke.Transparency = 0.9
	ProgressStroke.Thickness = 1.5
	ProgressStroke.Parent = ProgressContainer

	ProgressBarFill = Instance.new("Frame")
	ProgressBarFill.Name = "ProgressBarFill"
	ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
	ProgressBarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	ProgressBarFill.BorderSizePixel = 0
	ProgressBarFill.Parent = ProgressContainer

	local FillCorner = Instance.new("UICorner")
	FillCorner.CornerRadius = UDim.new(0.5, 0)
	FillCorner.Parent = ProgressBarFill

	local FillGradient = Instance.new("UIGradient")
	FillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 80, 255))
	})
	FillGradient.Parent = ProgressBarFill

	-- Status text (Asset name loading)
	StatusLabel = Instance.new("TextLabel")
	StatusLabel.Name = "StatusLabel"
	StatusLabel.Size = UDim2.new(0.5, 0, 0.04, 0)
	StatusLabel.Position = UDim2.new(0.25, 0, 0.63, 0)
	StatusLabel.BackgroundTransparency = 1
	StatusLabel.Font = Enum.Font.Gotham
	StatusLabel.Text = "Initializing systems..."
	StatusLabel.TextColor3 = Color3.fromRGB(180, 185, 200)
	StatusLabel.TextSize = 13
	StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	StatusLabel.Parent = MainFrame

	-- Percentage text
	PercentageLabel = Instance.new("TextLabel")
	PercentageLabel.Name = "PercentageLabel"
	PercentageLabel.Size = UDim2.new(0.5, 0, 0.04, 0)
	PercentageLabel.Position = UDim2.new(0.25, 0, 0.63, 0)
	PercentageLabel.BackgroundTransparency = 1
	PercentageLabel.Font = Enum.Font.GothamBold
	PercentageLabel.Text = "0%"
	PercentageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	PercentageLabel.TextSize = 13
	PercentageLabel.TextXAlignment = Enum.TextXAlignment.Right
	PercentageLabel.Parent = MainFrame

	-- Skip prompt
	SkipPrompt = Instance.new("TextLabel")
	SkipPrompt.Name = "SkipPrompt"
	SkipPrompt.Size = UDim2.new(1, 0, 0.06, 0)
	SkipPrompt.Position = UDim2.new(0, 0, 0.8, 0)
	SkipPrompt.BackgroundTransparency = 1
	SkipPrompt.Font = Enum.Font.GothamMedium
	SkipPrompt.Text = "PRESS ANYWHERE TO SKIP"
	SkipPrompt.TextColor3 = Color3.fromRGB(255, 255, 255)
	SkipPrompt.TextSize = 14
	SkipPrompt.TextTransparency = 1 -- Hidden initially
	SkipPrompt.Parent = MainFrame

	-- Spawn transition overlay
	FadeOverlay = Instance.new("Frame")
	FadeOverlay.Name = "FadeOverlay"
	FadeOverlay.Size = UDim2.new(1, 0, 1, 0)
	FadeOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	FadeOverlay.BackgroundTransparency = 1 -- Hidden initially
	FadeOverlay.BorderSizePixel = 0
	FadeOverlay.ZIndex = 10
	FadeOverlay.Parent = ScreenGui
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
	TweenService:Create(FadeOverlay, fadeInfo, {BackgroundTransparency = 0}):Play()
	task.wait(1.0)
	
	-- 2. Cleanup loading rig/avatar and reset camera
	if avatarModel then
		avatarModel:Destroy()
	end
	
	-- Revert to Original Lighting
	local LightingFolder = ReplicatedStorage:WaitForChild("Lighting", 5)
	if LightingFolder then
		local OriginalLighting = LightingFolder:FindFirstChild("OriginalLighting")
		if OriginalLighting then
			applyLighting(OriginalLighting)
		end
	end
	
	-- Restore original player camera mode
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	
	-- Re-enable Player controls
	local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
	local controls = PlayerModule:GetControls()
	controls:Enable()
	
	-- Disconnect player spawn anchor logic
	if charConnection then
		charConnection:Disconnect()
		charConnection = nil
	end
	
	-- Unanchor player character parts
	local char = player.Character
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = false
			end
		end
	end
	
	-- 3. Fade from black back to transparent
	TweenService:Create(FadeOverlay, fadeInfo, {BackgroundTransparency = 1}):Play()
	task.wait(1.0)
	
	-- 4. Clean up GUI completely
	ScreenGui:Destroy()
end

-- Transition to Phase 2: Fade out loading UI, start parallax, load avatar and custom lighting
local function transitionToPhase2()
	isLoadedFinished = true
	
	-- Load/Apply LSLighting configuration
	local LightingFolder = ReplicatedStorage:WaitForChild("Lighting", 5)
	if LightingFolder then
		local LSLighting = LightingFolder:FindFirstChild("LSLighting")
		if LSLighting then
			applyLighting(LSLighting)
		end
	end

	-- Replace LoadingRig with player avatar
	local loadingStuff = workspace:WaitForChild("LoadingScreenStuff", 5)
	local originalRig = loadingStuff and loadingStuff:FindFirstChild("LoadingRig")
	local avatarModel = nil

	if loadingStuff and originalRig then
		local success, model = pcall(function()
			return Players:CreateHumanoidModelFromUserId(player.UserId)
		end)
		
		if success and model then
			avatarModel = model
		else
			-- Fallback: clone local character if available
			local char = player.Character
			if char then
				char.Archivable = true
				avatarModel = char:Clone()
			end
		end

		if avatarModel then
			avatarModel.Name = "PlayerLoadingAvatar"
			avatarModel:PivotTo(originalRig:GetPivot())
			originalRig:Destroy()
			avatarModel.Parent = loadingStuff

			-- Anchor all parts to keep static in front of camera
			for _, part in ipairs(avatarModel:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.Anchored = true
				end
			end

			-- Play specified animation: 126803128347877
			local humanoid = avatarModel:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
				local anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://126803128347877"
				local track = animator:LoadAnimation(anim)
				track.Looped = true
				track:Play()
			end
		end
	end

	-- Focus camera onto the Camera Part inside LoadingScreenStuff
	local lsCameraPart = loadingStuff and loadingStuff:FindFirstChild("Camera")
	if lsCameraPart then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame = lsCameraPart.CFrame
	end

	-- Fade out the loading screen overlay elements over 1 second
	local fadeInfo = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(TitleLabel, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(SubtitleLabel, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(StatusLabel, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(PercentageLabel, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(SkipPrompt, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(ProgressContainer, fadeInfo, {BackgroundTransparency = 1}):Play()
	TweenService:Create(ProgressStroke, fadeInfo, {Transparency = 1}):Play()
	TweenService:Create(ProgressBarFill, fadeInfo, {BackgroundTransparency = 1}):Play()
	
	-- Fade out main background to reveal 3D scene (parallax starts)
	TweenService:Create(MainFrame, fadeInfo, {BackgroundTransparency = 1}):Play()
	task.wait(1.0)

	-- Destroy now-invisible Phase 1 elements
	TitleLabel:Destroy()
	SubtitleLabel:Destroy()
	StatusLabel:Destroy()
	PercentageLabel:Destroy()
	SkipPrompt:Destroy()
	ProgressContainer:Destroy()

	-- Start camera parallax
	inPhase2 = true
	startParallax(lsCameraPart)

	-- Listen for clicks anywhere on screen to enter the game
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

function LoadingController.Start()
	-- 1. Create interface
	createUI()

	-- Disable player controls immediately at start
	local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
	local controls = PlayerModule:GetControls()
	controls:Disable()

	-- Keep player anchored during loading process
	local function anchorCharacter(char)
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		if hrp then
			hrp.Anchored = true
		end
	end
	if player.Character then
		anchorCharacter(player.Character)
	end
	charConnection = player.CharacterAdded:Connect(anchorCharacter)

	-- 2. Gather assets to preload (Animations, Sounds, Textures, Meshes)
	local foldersToLoad = {
		ReplicatedStorage:FindFirstChild("Shared"),
		ReplicatedStorage:FindFirstChild("Animations"),
		ReplicatedStorage:FindFirstChild("Backpacks"),
		ReplicatedStorage:FindFirstChild("ClientSidedObjects"),
		ReplicatedStorage:FindFirstChild("Fishes"),
		ReplicatedStorage:FindFirstChild("Lighting"),
		workspace:FindFirstChild("LoadingScreenStuff")
	}

	local assetsToLoad = {}
	for _, folder in ipairs(foldersToLoad) do
		if folder then
			for _, desc in ipairs(folder:GetDescendants()) do
				if desc:IsA("Animation") or desc:IsA("Decal") or desc:IsA("Texture") or desc:IsA("Sound") or desc:IsA("MeshPart") or desc:IsA("SpecialMesh") then
					table.insert(assetsToLoad, desc)
				end
			end
		end
	end

	-- 3. Concurrent Timer: Allow skip after 10 seconds
	local allowSkip = false
	local skipInputConnection = nil
	task.spawn(function()
		task.wait(10)
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
		local batchSize = 5 -- small batches for smooth GUI updates
		
		for i = 1, totalAssets, batchSize do
			if isSkipped then break end
			
			local batch = {}
			for j = i, math.min(i + batchSize - 1, totalAssets) do
				table.insert(batch, assetsToLoad[j])
			end
			
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
			
			loadedCount = math.min(i + batchSize - 1, totalAssets)
			local progress = loadedCount / totalAssets
			
			-- Animate loading bar and progress indicators
			TweenService:Create(ProgressBarFill, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(progress, 0, 1, 0)
			}):Play()
			
			PercentageLabel.Text = math.floor(progress * 100) .. "%"
			
			local currentAsset = batch[#batch]
			if currentAsset then
				StatusLabel.Text = "Loading asset: " .. currentAsset.Name
			end
			
			task.wait(0.02) -- yield to keep the UI fluid
		end
	end

	-- Finalize loading bar if not skipped
	if not isSkipped then
		TweenService:Create(ProgressBarFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 1, 0)
		}):Play()
		PercentageLabel.Text = "100%"
		StatusLabel.Text = "Assets loaded successfully!"
		task.wait(0.4)
		
		if skipInputConnection then
			skipInputConnection:Disconnect()
		end
		
		transitionToPhase2()
	end
end

return LoadingController
