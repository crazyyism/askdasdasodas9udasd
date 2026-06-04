local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")
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

-- UI References
local ScreenGui
local MainFrame
local ProgressBarFill
local TitleLabel
local PercentageLabel
local SkipPrompt
local FadeOverlay
local FunnyImage

-- Preloaded Phase 2 Data
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
	ScreenGui = player:WaitForChild("PlayerGui"):FindFirstChild("LoadingScreenGui")
	if not ScreenGui then
		local template = StarterGui:WaitForChild("LoadingScreenGui", 5)
		if template then
			ScreenGui = template:Clone()
			ScreenGui.Parent = player.PlayerGui
		else
			warn("LoadingScreenGui template not found in StarterGui!")
			return false
		end
	end

	MainFrame = ScreenGui:WaitForChild("MainFrame")
	FadeOverlay = ScreenGui:WaitForChild("FadeOverlay")
	ProgressBarFill = ScreenGui:WaitForChild("ProgressBarFill")
	
	local CenterContainer = MainFrame:WaitForChild("CenterContainer")
	TitleLabel = CenterContainer:WaitForChild("TitleLabel")
	PercentageLabel = MainFrame:WaitForChild("PercentageLabel")
	SkipPrompt = MainFrame:WaitForChild("SkipPrompt")
	FunnyImage = ScreenGui:FindFirstChild("FunnyImage")
	
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
				return Players:GetHumanoidDescriptionFromUserId(player.UserId)
			end)
			
			if success and desc then
				avatarModel = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
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

	-- Fade out the loading screen overlay elements over 2.5 seconds
	local fadeInfo = TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(TitleLabel, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(PercentageLabel, fadeInfo, {TextTransparency = 1}):Play()
	TweenService:Create(SkipPrompt, fadeInfo, {TextTransparency = 1}):Play()
	if FunnyImage then
		TweenService:Create(FunnyImage, fadeInfo, {ImageTransparency = 1}):Play()
	end
	TweenService:Create(ProgressBarFill, fadeInfo, {BackgroundTransparency = 1}):Play()
	
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
	local success = createUI()
	if not success then return end
	
	-- Start background animations
	startLoadingTextAnimation()
	startFunnyImageRotation()
	
	-- Preload Phase 2 in the background to prevent hitches at 100%
	task.spawn(preloadPhase2Async)

	-- Create and play loading background music
	loadingSound = Instance.new("Sound")
	loadingSound.SoundId = "rbxassetid://139307780959520"
	loadingSound.Looped = true
	loadingSound.Volume = 0.5
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
		workspace,
		ReplicatedStorage,
		ReplicatedFirst,
		game:GetService("Lighting"),
		game:GetService("StarterGui"),
		game:GetService("StarterPlayer"),
		game:GetService("SoundService")
	}

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

	-- 3. Concurrent Timer: Allow skip after 10 seconds
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
				Size = UDim2.new(progress, 0, 0.019, 0)
			}):Play()
			
			PercentageLabel.Text = math.floor(progress * 100) .. "%"
			
			task.wait(0.02) -- yield to keep the UI fluid
		end
	end

	-- Finalize loading bar if not skipped
	if not isSkipped then
		TweenService:Create(ProgressBarFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0.019, 0)
		}):Play()
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
