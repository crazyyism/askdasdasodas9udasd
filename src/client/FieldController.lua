local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local FieldController = {}

local activeConnections = {} -- [Part] = {Connections...}

-- Helper to update visuals based on capacity
local function UpdateAlgaeVisuals(part)
	local cap = part:FindFirstChild("Capacity")
	local maxCapAttr = part:GetAttribute("MaxCapacity")
	
	-- Wait for attributes if not ready (rare but possible fast stream)
	if not maxCapAttr then
		if cap then maxCapAttr = cap.Value end -- Fallback or wait?
		if not maxCapAttr then return end
	end
	
	local maxCap = maxCapAttr
	local curCap = cap and cap.Value or 0
	
	local origSize = part:GetAttribute("OriginalSize")
	local origCF = part:GetAttribute("OriginalCFrame")
	
	if not origSize or not origCF then
		-- Initialize Attributes if missing (Client side init?)
		-- Ideally Server sets these once. If Server stopped setting them, Client must snap current as original?
		-- No, Server FieldService.RegisterField sets them.
		return
	end
	
	-- Calculate Visual State
	if curCap <= 0 then
		part.Transparency = 1
		for _, d in ipairs(part:GetChildren()) do
			if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
		end
	else
		-- Visible
		local origTrans = part:GetAttribute("OriginalTransparency") or 0
		part.Transparency = origTrans
		for _, d in ipairs(part:GetChildren()) do
			if d:IsA("Decal") or d:IsA("Texture") then d.Transparency = origTrans end
		end
		
		-- Shrink
		local missing = maxCap - curCap
		local scaleFactor = 1 / maxCap
		local yReduce = (origSize.Y * scaleFactor) * missing
		
		-- Clamp
		local newSizeY = math.max(origSize.Y * scaleFactor, origSize.Y - yReduce)
		local newSize = Vector3.new(origSize.X, newSizeY, origSize.Z)
		
		-- Positioning (Shrink from top, so move down by half reduction)
		local totalReduction = origSize.Y - newSizeY
		local yShift = totalReduction / 2
		
		-- Apply
		part.Size = newSize
		part.CFrame = origCF * CFrame.new(0, -yShift, 0)
	end
end

local function OnAlgaePartAdded(part)
	-- Cache original if not present (Safety)
	if not part:GetAttribute("OriginalSize") then
		part:SetAttribute("OriginalSize", part.Size)
		part:SetAttribute("OriginalCFrame", part.CFrame)
		part:SetAttribute("OriginalTransparency", part.Transparency)
	end
	
	local cap = part:WaitForChild("Capacity", 5)
	if not cap then return end
	
	-- Store Max Cap if not set
	if not part:GetAttribute("MaxCapacity") then
		part:SetAttribute("MaxCapacity", cap.Value)
	end
	
	-- Initial Update
	UpdateAlgaeVisuals(part)
	
	-- Listen
	local conn = cap:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateAlgaeVisuals(part)
	end)
	
	activeConnections[part] = {conn}
end

local function OnAlgaePartRemoved(part)
	if activeConnections[part] then
		for _, c in ipairs(activeConnections[part]) do c:Disconnect() end
		activeConnections[part] = nil
	end
end

function FieldController.Start()
	CollectionService:GetInstanceAddedSignal("AlgaePart"):Connect(OnAlgaePartAdded)
	CollectionService:GetInstanceRemovedSignal("AlgaePart"):Connect(OnAlgaePartRemoved)
	
	for _, p in ipairs(CollectionService:GetTagged("AlgaePart")) do
		OnAlgaePartAdded(p)
	end
end

return FieldController
