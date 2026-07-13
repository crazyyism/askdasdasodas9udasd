local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local EffectController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")

local clientData = nil
local bobTime = 0
local originalUIPosition = nil

DataUpdateEvent.OnClientEvent:Connect(function(data)
	if data then
		if not clientData then
			clientData = data
		else
			for k, v in pairs(data) do
				clientData[k] = v
			end
		end
	end
end)

local function GetSettings()
	return clientData and clientData.Settings or {}
end

function EffectController.Start()
	-- Request Data
	local RequestData = Remotes:FindFirstChild("RequestData")
	if RequestData then RequestData:FireServer() end

	RunService.RenderStepped:Connect(function(dt)
		local settings = GetSettings()
		
		-- 1. UI Parallax
		local disableParallax = settings.DisableParallax
		local mainGui = player.PlayerGui:FindFirstChild("Main")
		local mainFrame = mainGui and mainGui:FindFirstChild("Main")
		
		if mainFrame then
			if not originalUIPosition then
				originalUIPosition = mainFrame.Position
			end
			
			if not disableParallax then
				local viewportSize = camera.ViewportSize
				local centerX, centerY = viewportSize.X / 2, viewportSize.Y / 2
				
				-- Calculate mouse offset from center (-1 to 1)
				local mouseOffsetX = (mouse.X - centerX) / centerX
				local mouseOffsetY = (mouse.Y - centerY) / centerY
				
				-- Define maximum pixel offset
				local maxOffset = 15
				
				-- Target position
				local targetX = -mouseOffsetX * maxOffset
				local targetY = -mouseOffsetY * maxOffset
				
				-- Smoothly lerp towards target
				local targetUDim2 = UDim2.new(
					originalUIPosition.X.Scale, originalUIPosition.X.Offset + targetX,
					originalUIPosition.Y.Scale, originalUIPosition.Y.Offset + targetY
				)
				
				mainFrame.Position = mainFrame.Position:Lerp(targetUDim2, dt * 5)
			else
				-- Snap back to original
				mainFrame.Position = mainFrame.Position:Lerp(originalUIPosition, dt * 10)
			end
		end
		
		-- 2. Dynamic Camera (Bobbing)
		local disableCamera = settings.DisableDynamicCamera
		if not disableCamera then
			local char = player.Character
			local hum = char and char:FindFirstChild("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			
			if hum and root and hum.Health > 0 then
				local state = hum:GetState()
				local isGrounded = state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
				
				if isGrounded then
					local speed = root.AssemblyLinearVelocity.Magnitude
					if speed <= 0.5 then
						-- Idle Breathing
						local breathSpeed = 1.5
						local breathIntensity = 0.05
						
						bobTime = bobTime + (dt * breathSpeed)
						local breathY = math.sin(bobTime) * breathIntensity
						
						local offset = CFrame.new(0, breathY, 0)
						camera.CFrame = camera.CFrame * offset
					else
						-- Moving, no artificial bobbing (let camera follow torso naturally)
						bobTime = 0
					end
				else
					-- Airborne, gently reset
					bobTime = 0
				end
			end
		end
	end)
end

return EffectController
