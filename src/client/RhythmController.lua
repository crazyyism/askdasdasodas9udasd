local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local RhythmController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RhythmGameEvent = Remotes:WaitForChild("RhythmGameEvent")
local RhythmHitEvent = Remotes:WaitForChild("RhythmHitEvent")
local RhythmMissEvent = Remotes:WaitForChild("RhythmMissEvent")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
local localData = nil

DataUpdateEvent.OnClientEvent:Connect(function(data)
	localData = data
end)

local activeButtons = {} -- [ButtonInstance] = HitFunction

local function GetPrismColor()
	return Color3.fromHSV(math.random(), 0.7, 0.9)
end

local BUTTON_MAPPING = {
	{Key = Enum.KeyCode.Z, Name = "Z"},
	{Key = Enum.KeyCode.X, Name = "X"},
	{Key = Enum.KeyCode.C, Name = "C"},
	{Key = Enum.KeyCode.V, Name = "V"},
	{Key = Enum.KeyCode.F, Name = "F"},
	{Key = Enum.KeyCode.G, Name = "G"},
	{Key = Enum.KeyCode.H, Name = "H"},
	{Key = Enum.KeyCode.B, Name = "B"},
}

local function GetRhythmScreen()
	local existing = playerGui:FindFirstChild("RhythmGame")
	if existing then return existing end
	
	local gui = Instance.new("ScreenGui")
	gui.Name = "RhythmGame"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui
	return gui
end

local function SpawnButton(shrinkTime)
	shrinkTime = shrinkTime or 2.5
	local screen = GetRhythmScreen()
	local mainGui = playerGui:WaitForChild("Main")
	local template = mainGui:WaitForChild("RhythmButton")
	local button = template:Clone()
	button.Visible = true
	button.Active = true
	button.Parent = screen
	
	local btnInfo = BUTTON_MAPPING[math.random(1, #BUTTON_MAPPING)]
	local color = GetPrismColor()
	local gamepadKey = btnInfo.Key
	local spawnTime = os.clock()
	
	button:SetAttribute("GamepadKey", gamepadKey.Value)
	button:SetAttribute("SpawnTime", spawnTime)
	

	local rx = 0.15 + math.random() * 0.7
	local ry = 0.15 + math.random() * 0.7
	button.Position = UDim2.fromScale(rx, ry)
	button.BackgroundColor3 = color
	
	local indicator = button:WaitForChild("RhythmIndicator")
	local stroke = button:WaitForChild("UIStroke")
	local iStroke = indicator:WaitForChild("UIStroke")
	
	indicator.BackgroundColor3 = color
	stroke.Color = color
	iStroke.Color = color

	-- Animations
	-- Fade In
	button.BackgroundTransparency = 1
	stroke.Transparency = 1
	indicator.BackgroundTransparency = 1
	iStroke.Transparency = 1
	
	TweenService:Create(button, TweenInfo.new(0.3), {BackgroundTransparency = 0.6}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
	TweenService:Create(indicator, TweenInfo.new(0.3), {BackgroundTransparency = 0.7}):Play()
	TweenService:Create(iStroke, TweenInfo.new(0.3), {Transparency = 0}):Play()
	
	-- Console Icon
	local icon = Instance.new("TextLabel")
	icon.Name = "ConsoleIcon"
	icon.Size = UDim2.fromScale(0.6, 0.6)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Text = btnInfo.Name
	icon.TextColor3 = Color3.new(1, 1, 1)
	icon.Font = Enum.Font.FredokaOne
	icon.TextScaled = true
	icon.ZIndex = 5
	icon.Visible = true -- Show it to PC users as well!
	icon.Parent = button
	
	local iStroke2 = Instance.new("UIStroke")
	iStroke2.Thickness = 2
	iStroke2.Parent = icon
	
	local rhythmTween = TweenService:Create(indicator, TweenInfo.new(shrinkTime, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(0, 0)
	})
	rhythmTween:Play()
	
	local finished = false
	
	local function Cleanup(isSuccess)
		if finished then return end
		finished = true
		
		if isSuccess then
			-- Success Grow + Fade Out
			local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local growSize = UDim2.new(button.Size.X.Scale * 1.5, button.Size.X.Offset * 1.5, button.Size.Y.Scale * 1.5, button.Size.Y.Offset * 1.5)
			
			TweenService:Create(button, info, {Size = growSize, BackgroundTransparency = 1}):Play()
			TweenService:Create(stroke, info, {Transparency = 1}):Play()
			TweenService:Create(indicator, info, {BackgroundTransparency = 1}):Play()
			TweenService:Create(iStroke, info, {Transparency = 1}):Play()
			
			task.delay(0.5, function()
				button:Destroy()
			end)
		else
			RhythmMissEvent:FireServer()
			-- Miss Fade out animation
			local fadeInfo = TweenInfo.new(0.3)
			TweenService:Create(button, fadeInfo, {BackgroundTransparency = 1}):Play()
			TweenService:Create(stroke, fadeInfo, {Transparency = 1}):Play()
			TweenService:Create(indicator, fadeInfo, {BackgroundTransparency = 1}):Play()
			TweenService:Create(iStroke, fadeInfo, {Transparency = 1}):Play()
			task.delay(0.3, function()
				button:Destroy()
			end)
		end
	end
	
	-- Store for console/accessibility
	activeButtons[button] = function()
		if finished then return end
		-- Simulate the click logic directly
		
		-- Play random rhythm sound from folder
		local rhythmSFX = ReplicatedStorage:FindFirstChild("SFX") and ReplicatedStorage.SFX:FindFirstChild("Rhythm")
		local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
		if rhythmSFX and not isSfxDisabled then
			local sounds = rhythmSFX:GetChildren()
			if #sounds > 0 then
				local sound = sounds[math.random(1, #sounds)]:Clone()
				sound.Parent = player.Character or workspace
				sound:Play()
				Debris:AddItem(sound, 3)
			end
		end
		
		local timeElapsed = os.clock() - spawnTime
		-- Scale logic: starts at 2.0, goes to 0 over shrinkTime seconds.
		-- Hits 1.0 (the target) at exactly half of shrinkTime.
		local currentScale = 2.0 - (2.0 * (timeElapsed / shrinkTime))
		
		local diff = math.abs(currentScale - 1.0)
		local rating = nil
		local isSuccess = false
		
		if diff <= 0.15 then
			rating = "Perfect"
			isSuccess = true
		elseif diff <= 0.4 then
			rating = "Good"
			isSuccess = true
		elseif diff <= 0.7 then
			rating = "Bad"
			isSuccess = true
		end
		
		if isSuccess then
			RhythmHitEvent:FireServer(rating, color)
			
			-- Visual Feedback
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Thickness = 8
			
			local hitLabel = Instance.new("TextLabel")
			hitLabel.Text = rating:upper() .. "!"
			hitLabel.TextColor3 = (rating == "Perfect" and Color3.fromRGB(255, 255, 0)) or Color3.fromRGB(255, 255, 255)
			hitLabel.Font = Enum.Font.Cartoon
			hitLabel.TextScaled = true
			hitLabel.Size = UDim2.fromScale(0, 0) -- Start at 0 for pop animation
			hitLabel.Position = UDim2.fromScale(0.5, -0.5)
			hitLabel.AnchorPoint = Vector2.new(0.5, 0.5)
			hitLabel.BackgroundTransparency = 1
			hitLabel.Rotation = math.random(-15, 15) -- Random tilt for dynamism
			hitLabel.Parent = button

			local labelStroke = Instance.new("UIStroke")
			labelStroke.Thickness = 3
			labelStroke.Color = Color3.new(0, 0, 0)
			labelStroke.Parent = hitLabel

			-- Dynamic Pop and Float animation
			local targetSize = UDim2.fromScale(1.875, 0.625) -- 1.25x bigger
			TweenService:Create(hitLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = targetSize}):Play()
			TweenService:Create(hitLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.fromScale(0.5, -1.2), TextTransparency = 1}):Play()
			TweenService:Create(labelStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
		else
			-- MISS
			stroke.Color = Color3.fromRGB(255, 0, 0)
		end
		
		Cleanup(isSuccess)
	end
	
	button.InputBegan:Connect(function(input)
		if finished then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		
		activeButtons[button]()
	end)
	
	button.Destroying:Connect(function()
		activeButtons[button] = nil
	end)
	
	-- Auto cleanup after shrinkTime seconds (+ some grace)
	task.delay(shrinkTime + 0.2, function()
		Cleanup(false) -- Auto cleanup counts as a miss
	end)
end

function RhythmController.Start()
	RhythmGameEvent.OnClientEvent:Connect(function(maxCount, spawnRate, shrinkTime)
		spawnRate = spawnRate or 3.0
		shrinkTime = shrinkTime or 2.5
		
		local startTime = os.clock()
		local nextSpawn = 0
		local spawnCount = 0
		
		local connection
		connection = game:GetService("RunService").Heartbeat:Connect(function()
			local now = os.clock()
			local elapsed = now - startTime
			
			if spawnCount >= maxCount then
				connection:Disconnect()
				return
			end
			
			if elapsed >= nextSpawn and spawnCount < maxCount then
				SpawnButton(shrinkTime)
				spawnCount = spawnCount + 1
				nextSpawn = elapsed + spawnRate
			end
		end)

		local inputConn
		inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end

			
			local screen = playerGui:FindFirstChild("RhythmGame")
			if not screen then return end
			
			local bestButton = nil
			local oldestTime = math.huge
			
			for btn, hitFunc in pairs(activeButtons) do
				if btn:GetAttribute("GamepadKey") == input.KeyCode.Value then
					local sTime = btn:GetAttribute("SpawnTime") or 0
					if sTime < oldestTime then
						oldestTime = sTime
						bestButton = btn
					end
				end
			end
			
			if bestButton and activeButtons[bestButton] then
				activeButtons[bestButton]()
			end
		end)
		
		-- Cleanup when the main game sequence is done? 
		-- maxCount ensures the loop disconnects, let's disconnect input too after a while.
		task.delay(maxCount * 3.5 + 5, function()
			if inputConn then inputConn:Disconnect() end
		end)
	end)
end

return RhythmController
