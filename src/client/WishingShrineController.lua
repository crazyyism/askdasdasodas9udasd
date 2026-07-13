local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local WishingShrineController = {}
local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ClaimWishingShrineEvent = Remotes:WaitForChild("ClaimWishingShrine")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")

local NotifierController = require(script.Parent:WaitForChild("NotifierController"))

local interactionDebounce = false
local nearestShrine = nil

local clientData = nil

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

function WishingShrineController.Start()
	-- Request Initial Data
	local RequestData = Remotes:FindFirstChild("RequestData")
	if RequestData then RequestData:FireServer() end
	
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then return end
	local mainGui = playerGui:WaitForChild("Main", 10)
	if not mainGui then return end
	
	local interactionFrame = mainGui:WaitForChild("Interaction", 10)
	if not interactionFrame then return end
	
	local keybindLabel = interactionFrame:WaitForChild("Keybind")
	local actionLabel = interactionFrame:WaitForChild("InteractionType")
	local interactionButton = interactionFrame:FindFirstChild("InteractionButton")

	local knownShrines = {}
	
	local function RegisterShrine(obj)
		if obj:IsA("Model") and obj.Name == "WishingShrine" then
			local targetPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			
			if targetPart and not table.find(knownShrines, targetPart) then
				table.insert(knownShrines, targetPart)
			end
		end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		RegisterShrine(obj)
	end
	
	workspace.DescendantAdded:Connect(RegisterShrine)

	local function FindNearShrine(rootPos)
		local closest = nil
		local minDist = 25 

		for _, targetPart in ipairs(knownShrines) do
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
	
	local function AttemptClaim()
		if interactionDebounce then return end
		interactionDebounce = true
		
		if not clientData then 
			interactionDebounce = false
			return 
		end
		
		local fishCount = 0
		if clientData.FishSchool then
			for _, _ in pairs(clientData.FishSchool) do
				fishCount = fishCount + 1
			end
		end
		
		if fishCount < 10 then
			NotifierController:Notify("You need 10 fish to use the shrine!", Color3.fromRGB(255, 100, 100))
			task.wait(1)
			interactionDebounce = false
			return
		end
		
		local lastClaim = clientData.LastShrineClaim or 0
		local timeSince = os.time() - lastClaim
		if timeSince < 3600 then
			local timeLeft = 3600 - timeSince
			local mins = math.ceil(timeLeft / 60)
			NotifierController:Notify("Shrine is recharging! Wait " .. mins .. " mins.", Color3.fromRGB(255, 100, 100))
			task.wait(1)
			interactionDebounce = false
			return
		end
		
		ClaimWishingShrineEvent:FireServer()
		
		task.wait(1)
		interactionDebounce = false
	end

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		if not char or not char.PrimaryPart then return end
		local hrp = char.PrimaryPart

		nearestShrine = FindNearShrine(hrp.Position)

		if nearestShrine then
			if not interactionFrame.Visible or actionLabel.Text:match("Wish") then
				interactionFrame.Visible = true
				
				local worldPos = nearestShrine.Position + Vector3.new(0, 5, 0)
				local vector, onScreen = workspace.CurrentCamera:WorldToScreenPoint(worldPos)
				
				if onScreen then
					local targetPos = UDim2.fromOffset(vector.X, vector.Y)
					interactionFrame.Position = interactionFrame.Position:Lerp(targetPos, 0.2)
				else
					interactionFrame.Visible = false
				end
				
				keybindLabel.Text = "E"
				actionLabel.Text = "Make a Wish"
				actionLabel.TextColor3 = Color3.new(1, 1, 1)
			end
		else
			if interactionFrame.Visible and actionLabel.Text:match("Wish") then
				interactionFrame.Visible = false
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.E and nearestShrine then
			AttemptClaim()
		end
	end)

	if interactionButton then
		interactionButton.Activated:Connect(function()
			if nearestShrine then
				AttemptClaim()
			end
		end)
	end
end

return WishingShrineController
