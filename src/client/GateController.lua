local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GateController = {}

local player = Players.LocalPlayer
local gatesFolder = workspace:WaitForChild("Gates", 10)

-- Data Sync
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")

local clientData = {}

local function UpdateGates()
	if not gatesFolder then return end
	if not clientData then return end
	
	-- Calculate Fish Count
	-- "amount of fish" -> count of fish in the school
	local fishCount = 0
	if clientData.FishSchool then
		for _, _ in pairs(clientData.FishSchool) do
			fishCount = fishCount + 1
		end
	end
	
	for _, gateGroup in ipairs(gatesFolder:GetChildren()) do
		local fishReq = gateGroup:FindFirstChild("FishRequired")
		local gateCollide = gateGroup:FindFirstChild("GateCollide")
		
		if fishReq and gateCollide and fishReq:IsA("IntValue") and gateCollide:IsA("BasePart") then
			local req = fishReq.Value
			
			if fishCount >= req then
				-- Has enough fish: Open Gate (CanCollide = false)
				gateCollide.CanCollide = false
				gateCollide.Transparency = 1 -- Fully transparent
			else
				-- Not enough: Close Gate.
				gateCollide.CanCollide = true
				gateCollide.Transparency = 0.7 -- Semi-transparent
			end
		end
	end
end

local function DeepMerge(target, source)
	for k, v in pairs(source) do
		if type(v) == "table" and type(target[k]) == "table" then
			DeepMerge(target[k], v)
		else
			target[k] = v
		end
	end
end

function GateController.Start()
	if not gatesFolder then return end
	
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		if not clientData then clientData = {} end
		DeepMerge(clientData, data)
		UpdateGates()
	end)
	
	-- Listen for new gates (Streaming)
	gatesFolder.ChildAdded:Connect(function(child)
		UpdateGates()
	end)
	
	-- Initial Update loop (in case of streaming)
	task.spawn(function()
		while true do
			task.wait(1)
			UpdateGates()
		end 
	end)
end

return GateController
