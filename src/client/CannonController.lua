local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CannonController = {}
local player = Players.LocalPlayer

local interactionDebounce = false
local nearestCannon = nil

function CannonController.Start()
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then return end
	local mainGui = playerGui:WaitForChild("Main", 10)
	if not mainGui then return end
	
	local interactionFrame = mainGui:WaitForChild("Interaction", 10)
	if not interactionFrame then return end
	
	local keybindLabel = interactionFrame:WaitForChild("Keybind")
	local actionLabel = interactionFrame:WaitForChild("InteractionType")
	local interactionButton = interactionFrame:FindFirstChild("InteractionButton")

	local knownCannons = {}
	
	local function RegisterCannon(obj)
		if obj.Name == "Cannon" then
			local targetPart = nil
			if obj:IsA("BasePart") then
				targetPart = obj
			elseif obj:IsA("Model") then
				targetPart = obj.PrimaryPart or obj:FindFirstChild("Barrel") or obj:FindFirstChildWhichIsA("BasePart")
			end
			
			if targetPart and not table.find(knownCannons, targetPart) then
				table.insert(knownCannons, targetPart)
			end
		end
	end
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		RegisterCannon(obj)
	end
	
	workspace.DescendantAdded:Connect(RegisterCannon)

	local function FindNearCannon(rootPos)
		local closest = nil
		local minDist = 25 -- Interact range increased for large models

		for _, targetPart in ipairs(knownCannons) do
			if targetPart and targetPart.Parent then
				local dist = (targetPart.Position - rootPos).Magnitude
				if dist < minDist then
					minDist = dist
					closest = targetPart
				end
			end
		end
		
		return closest
	end

	local function LaunchPlayer(cannonPart)
		if interactionDebounce then return end
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChild("Humanoid")
		if not hrp or not hum then return end

		interactionDebounce = true
		
		-- Ensure player is somewhat aligned with cannon before launching
		hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + cannonPart.CFrame.LookVector)
		
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		task.wait(0.05)
		
		-- Default Powers
		local power = 400
		local verticalPower = 200
		
		-- Look for custom IntValues (Check part itself, or parent model)
		local searchTarget = cannonPart
		if cannonPart.Parent and cannonPart.Parent.Name == "Cannon" then
			searchTarget = cannonPart.Parent
		end
		
		local vPowerObj = searchTarget:FindFirstChild("VPower") or cannonPart:FindFirstChild("VPower")
		local hPowerObj = searchTarget:FindFirstChild("HPower") or cannonPart:FindFirstChild("HPower")
		
		if vPowerObj and vPowerObj:IsA("IntValue") then
			verticalPower = vPowerObj.Value
		end
		
		if hPowerObj and hPowerObj:IsA("IntValue") then
			power = hPowerObj.Value
		end
		
		-- Use the cannon's LookVector for direction
		local direction = cannonPart.CFrame.LookVector
		
		-- Reset velocity first
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyLinearVelocity = (direction * power) + Vector3.new(0, verticalPower, 0)
		
		-- Sound effect
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://13475971485" -- Cannon or big jump SFX
		sound.Volume = 1
		sound.Parent = hrp
		sound:Play()
		game.Debris:AddItem(sound, 2)
		
		task.wait(1)
		interactionDebounce = false
	end

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		if not char or not char.PrimaryPart then return end
		local hrp = char.PrimaryPart

		nearestCannon = FindNearCannon(hrp.Position)

		if nearestCannon then
			-- Show interaction if not currently taken by something more important
			if not interactionFrame.Visible or actionLabel.Text:match("Cannon") then
				interactionFrame.Visible = true
				
				local worldPos = nearestCannon.Position + Vector3.new(0, 3, 0)
				local vector, onScreen = workspace.CurrentCamera:WorldToScreenPoint(worldPos)
				
				if onScreen then
					local targetPos = UDim2.fromOffset(vector.X, vector.Y)
					interactionFrame.Position = interactionFrame.Position:Lerp(targetPos, 0.2)
				end
				
				keybindLabel.Text = "E"
				actionLabel.Text = "Use Cannon"
			end
		else
			-- If the screen is showing Cannon text and no cannon is near, hide it
			if interactionFrame.Visible and actionLabel.Text:match("Cannon") then
				interactionFrame.Visible = false
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.E and nearestCannon then
			LaunchPlayer(nearestCannon)
		end
	end)

	if interactionButton then
		local function onActivated()
			if nearestCannon then
				LaunchPlayer(nearestCannon)
				local originalColor = interactionButton.BackgroundColor3
				interactionButton.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
				task.delay(0.1, function() interactionButton.BackgroundColor3 = originalColor end)
			end
		end

		interactionButton.Activated:Connect(onActivated)
		interactionButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				onActivated()
			end
		end)
	end
end

return CannonController
