local HotSpotController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local minigameFrame = nil
local circle = nil
local heatText = nil
local gradient = nil
local hotspotBg = nil
local activeParticles = {}
local lastParticleSpawn = 0
local circleFlame = nil

local isActive = false
local currentHeat = 0
local activeBossMob = nil
local maxHeat = 100

local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

local function FindUI()
	if minigameFrame and minigameFrame.Parent then return end
	
	local gui = localPlayer:WaitForChild("PlayerGui")
	local mainGui = gui:WaitForChild("Main")
	minigameFrame = mainGui:WaitForChild("HotSpotMinigane")
	circle = minigameFrame:WaitForChild("Circle")
	heatText = minigameFrame:WaitForChild("HotSpotLevel")
	
	-- Setup Visuals for 2D Circle HotSpot
	minigameFrame.BackgroundColor3 = Color3.fromRGB(255, 170, 0) -- Light Orange Background
	
	gradient = minigameFrame:WaitForChild("HotSpotGlow")
	
	if circle and not circleFlame then
		circleFlame = Instance.new("ImageLabel")
		circleFlame.Name = "CircleFlame"
		circleFlame.Image = "rbxassetid://119387723789903"
		circleFlame.BackgroundTransparency = 1
		circleFlame.Size = UDim2.fromScale(4.5,4.5)
		circleFlame.AnchorPoint = Vector2.new(0.5, 0.5)
		circleFlame.Position = UDim2.fromScale(.5, -.5)
		circleFlame.ImageColor3 = Color3.new(1, 1, 1) -- White
		circleFlame.ZIndex = circle.ZIndex + 1
		circleFlame.Parent = circle
	end
	
	hotspotBg = minigameFrame:FindFirstChild("HotspotBackground") or minigameFrame:FindFirstChild("HotSpotBackground") or minigameFrame:FindFirstChild("hotspotbackground")
	if hotspotBg then
		hotspotBg.Size = UDim2.fromScale(1, 1)
		hotspotBg.Position = UDim2.fromScale(0.5, 0.5)
		hotspotBg.AnchorPoint = Vector2.new(0.5, 0.5)
		hotspotBg.ClipsDescendants = false
	end
	
	-- UI Dragging Setup
	circle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not isActive then return end
			dragging = true
			dragStart = input.Position
			startPos = circle.Position
			
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	minigameFrame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
end

-- Hot Spot Movement State
local targetOffset = Vector2.new(0, 0)
local currentOffset = Vector2.new(0, 0)
local offsetSpeed = 0.5
local lastNewOffsetTime = 0
local lastNotifTime = 0

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging and isActive and minigameFrame and circle then
		local delta = input.Position - dragStart
		
		-- Calculate new position in scale (since frame size might change)
		local frameSize = minigameFrame.AbsoluteSize
		local circleSize = circle.AbsoluteSize
		
		-- Convert start pos to absolute pixels, add delta, convert back to scale
		local startAbs = Vector2.new(startPos.X.Scale * frameSize.X, startPos.Y.Scale * frameSize.Y)
		local newAbsX = startAbs.X + delta.X
		local newAbsY = startAbs.Y + delta.Y
		
		-- Clamp to boundaries (Frame size - circle size)
		local anchorOffsetX = circle.AnchorPoint.X * circleSize.X
		local anchorOffsetY = circle.AnchorPoint.Y * circleSize.Y
		
		newAbsX = math.clamp(newAbsX, anchorOffsetX, frameSize.X - circleSize.X + anchorOffsetX)
		newAbsY = math.clamp(newAbsY, anchorOffsetY, frameSize.Y - circleSize.Y + anchorOffsetY)
		
		circle.Position = UDim2.new(newAbsX / frameSize.X, 0, newAbsY / frameSize.Y, 0)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not isActive or not minigameFrame then return end
	
	-- 1. Move Hot Spot
	if os.clock() - lastNewOffsetTime > 1.5 then
		-- Generate new offset within roughly 60% of the center (-0.3 to 0.3)
		-- Since rotation is 45, the X/Y axes are diagonal. Just moving offset vector is fine.
		targetOffset = Vector2.new(
			(math.random() - 0.5) * 0.6,
			(math.random() - 0.5) * 0.6
		)
		lastNewOffsetTime = os.clock()
		offsetSpeed = math.random(8, 15) / 10 -- Random speed between 0.8 and 1.5
	end
	
	-- Smoothly tween current offset to target
	currentOffset = currentOffset:Lerp(targetOffset, dt * offsetSpeed)
	-- currentOffset varies from -0.3 to 0.3. Map it to Position (0.2 to 0.8)
	gradient.Position = UDim2.new(0.5 + currentOffset.X, 0, 0.5 + currentOffset.Y, 0)
	
	-- 2. Calculate Distance
	local frameCenterAbs = minigameFrame.AbsolutePosition + (minigameFrame.AbsoluteSize / 2)
	local hotSpotAbsX = frameCenterAbs.X + (currentOffset.X * minigameFrame.AbsoluteSize.X)
	local hotSpotAbsY = frameCenterAbs.Y + (currentOffset.Y * minigameFrame.AbsoluteSize.Y)
	local hotSpotAbs = Vector2.new(hotSpotAbsX, hotSpotAbsY)
	
	-- Circle center absolute
	local circleAbs = circle.AbsolutePosition + (circle.AbsoluteSize * (Vector2.new(0.5, 0.5) - circle.AnchorPoint))
	
	local dist = (circleAbs - hotSpotAbs).Magnitude
	
	-- 3. Heat Logic
	if dist <= 50 then
		currentHeat = math.max(0, currentHeat - (5 * dt)) -- -5 per sec
	else
		currentHeat = math.min(maxHeat, currentHeat + (5 * dt)) -- +5 per sec
	end
	
	-- Update text
	heatText.Text = "Heat: " .. math.floor(currentHeat) .. "/" .. maxHeat
	
	if currentHeat > 75 and os.clock() - lastNotifTime > 10 then
		lastNotifTime = os.clock()
		local NotifierController = require(script.Parent.NotifierController)
		NotifierController:Notify("Drag the white circle into the deeper orange!", Color3.fromRGB(255, 100, 0))
	end
	
	-- 4. Damage Logic
	if currentHeat >= maxHeat then
		local char = localPlayer.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(10 * dt)
			end
		end
	end
	
	-- 5. Animate Circle Flame Flipbook
	if circleFlame then
		local fps = 15
		local frameIndex = math.floor(os.clock() * fps) % 16
		local col = frameIndex % 4
		local row = math.floor(frameIndex / 4)
		local texSizeX, texSizeY = 1024, 1024
		local frameW, frameH = texSizeX / 4, texSizeY / 4
		circleFlame.ImageRectOffset = Vector2.new(col * frameW, row * frameH)
		circleFlame.ImageRectSize = Vector2.new(frameW, frameH)
	end
	
	-- 6. 2D Particle Emitter (Flipbook)
	if isActive and hotspotBg then
		if os.clock() - lastParticleSpawn > 0.03 then
			lastParticleSpawn = os.clock()
			
			local p = Instance.new("ImageLabel")
			p.Image = "rbxassetid://74091341996632"
			p.BackgroundTransparency = 1
			p.ZIndex = -99999
			p.ImageColor3 = Color3.fromRGB(255, 120, 0) -- Bright Orange
			
			local sizeScale = math.random(50, 75) / 100 -- 3x to 5x smaller than frame
			p.Size = UDim2.fromScale(sizeScale, sizeScale)
			p.AnchorPoint = Vector2.new(0.5, 0.5)
			
			local angle = math.random() * math.pi * 2
			local dirX, dirY = math.cos(angle), math.sin(angle)
			
			-- Find intersection with unit square border [-0.5, 0.5]
			local t = 0.5 / math.max(math.abs(dirX), math.abs(dirY))
			local spawnDist = t * 0.85 -- Slightly inside the border
			
			p.Position = UDim2.fromScale(0.5 + dirX * spawnDist, 0.5 + dirY * spawnDist)
			p.Rotation = math.deg(math.atan2(dirY, dirX)) + 90
			p.Parent = hotspotBg
			
			local lifetime = math.random(40, 70) / 100 -- 0.4s to 0.7s
			table.insert(activeParticles, {
				UI = p,
				SpawnTime = os.clock(),
				Lifetime = lifetime,
				DirX = dirX,
				DirY = dirY,
				StartDist = spawnDist
			})
		end
	end
	
	-- Update Particles
	for i = #activeParticles, 1, -1 do
		local pData = activeParticles[i]
		local age = os.clock() - pData.SpawnTime
		if age >= pData.Lifetime then
			pData.UI:Destroy()
			table.remove(activeParticles, i)
		else
			local progress = age / pData.Lifetime
			
			-- Move outward slightly
			local currentDist = pData.StartDist + (progress * 0.2)
			pData.UI.Position = UDim2.fromScale(0.5 + pData.DirX * currentDist, 0.5 + pData.DirY * currentDist)
			
			local frameIndex = math.clamp(math.floor(progress * 16), 0, 15)
			local col = frameIndex % 4
			local row = math.floor(frameIndex / 4)
			
			local texSizeX, texSizeY = 1024, 1024
			local frameW, frameH = texSizeX / 4, texSizeY / 4
			pData.UI.ImageRectOffset = Vector2.new(col * frameW, row * frameH)
			pData.UI.ImageRectSize = Vector2.new(frameW, frameH)
		end
	end
end)

function HotSpotController.Activate(bossMob)
	FindUI()
	
	if activeBossMob ~= bossMob then
		-- Only reset if the previous boss is actually dead/destroyed
		if activeBossMob then
			local hp = activeBossMob:FindFirstChild("Health")
			if not activeBossMob.Parent or (hp and hp.Value <= 0) then
				currentHeat = 0
			end
		end
		activeBossMob = bossMob
	end
	
	isActive = true
	minigameFrame.Visible = true
end

function HotSpotController.Deactivate()
	isActive = false
	dragging = false
	if minigameFrame then
		minigameFrame.Visible = false
	end
end

function HotSpotController.IsActive()
	return isActive
end

return HotSpotController
