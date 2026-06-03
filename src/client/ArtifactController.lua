local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ArtifactController = {}

local player = Players.LocalPlayer
local artifactsFolder = nil -- Container for visual models
local activeArtifacts = {} -- List of {Model, AngleOffset}
local activeSettings = {}

local ART_HEIGHT = 7
local ART_RADIUS = 8
local ROT_SPEED = (math.pi * 2) / 10 -- 1 rotation per 10 seconds

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")

local function ClearArtifacts()
	for _, entry in ipairs(activeArtifacts) do
		if entry.Model then entry.Model:Destroy() end
	end
	activeArtifacts = {}
end

local function LoadArtifacts(list)
	ClearArtifacts()
	
	if activeSettings.HideArtifacts then return end
	if not list or #list == 0 then return end
	
	if not artifactsFolder then
		artifactsFolder = Instance.new("Folder")
		artifactsFolder.Name = "ClientArtifacts"
		artifactsFolder.Parent = workspace.CurrentCamera
	end
	
	local count = #list
	for i, artName in ipairs(list) do
		-- Find Model
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		local artFolder = vfxFolder and vfxFolder:FindFirstChild("Artifacts")
		local artTemplate = artFolder and artFolder:FindFirstChild(artName)
		
		if artTemplate then
			local model = artTemplate:Clone()
			-- Ensure it's not colliding
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.Anchored = true
					d.Massless = true
				end
			end
			model.Parent = artifactsFolder
			
			-- Distribute evenly
			local phase = (i - 1) * ((math.pi * 2) / count)
			table.insert(activeArtifacts, {Model = model, Phase = phase, Name = artName})
		else
			warn("ArtifactController: Could not find visual model for " .. tostring(artName))
		end
	end
end

local function UpdateVisuals(dt)
	local char = player.Character
	if not char or not char.PrimaryPart then 
		-- Hide if no character
		if artifactsFolder then artifactsFolder.Parent = nil end
		return 
	end
	
	if artifactsFolder then artifactsFolder.Parent = workspace.CurrentCamera end
	
	local rootPos = char.PrimaryPart.Position
	local time = os.clock()
	local baseAngle = time * ROT_SPEED
	
	for _, entry in ipairs(activeArtifacts) do
		local angle = baseAngle + entry.Phase
		local offset = Vector3.new(math.cos(angle) * ART_RADIUS, ART_HEIGHT, math.sin(angle) * ART_RADIUS)
		local targetPos = rootPos + offset
		
		-- Smooth Follow
		if not entry.CurrentPos then entry.CurrentPos = targetPos end
		
		-- Lerp factor (adjust 5.0 for speed/delay)
		local lerpFactor = math.clamp(dt * 5.0, 0, 1)
		entry.CurrentPos = entry.CurrentPos:Lerp(targetPos, lerpFactor)
		
		-- Orientation: Spin slowly
		local spin = time * 1.0 -- Radians/sec
		local cf = CFrame.new(entry.CurrentPos) * CFrame.Angles(0, spin, 0)
		
		if entry.Model:IsA("Model") then
			if entry.Model.PrimaryPart then
				entry.Model:SetPrimaryPartCFrame(cf)
			else
				entry.Model:PivotTo(cf)
			end
		elseif entry.Model:IsA("BasePart") then
			entry.Model.CFrame = cf
		end
	end
end

-- Global Particle Throttle for Low Detail Mode
local function ApplyLowDetailMode(enabled)
	local function process(obj)
		if obj:IsA("ParticleEmitter") then
			if enabled then
				if not obj:GetAttribute("OriginalRate") then
					obj:SetAttribute("OriginalRate", obj.Rate)
				end
				-- Apply 25% rate
				local orig = obj:GetAttribute("OriginalRate")
				obj.Rate = orig * 0.25
			else
				-- Restore
				local orig = obj:GetAttribute("OriginalRate")
				if orig then
					obj.Rate = orig
				end
			end
		end
	end
	
	for _, v in ipairs(workspace:GetDescendants()) do process(v) end
	for _, v in ipairs(workspace.CurrentCamera:GetDescendants()) do process(v) end
end

-- Monitor new particles
workspace.DescendantAdded:Connect(function(desc)
	if activeSettings and activeSettings.LowDetailMode then
		if desc:IsA("ParticleEmitter") then
			task.wait() -- Wait for properties to initialize
			if not desc:GetAttribute("OriginalRate") then
				desc:SetAttribute("OriginalRate", desc.Rate)
			end
			desc.Rate = desc:GetAttribute("OriginalRate") * 0.25
		end
	end
end)

function ArtifactController.Start()
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		-- Update Settings
		local oldSettings = activeSettings or {}
		activeSettings = data.Settings or {}
		
		-- Handle Hide Artifacts
		if activeSettings.HideArtifacts ~= oldSettings.HideArtifacts then
			if activeSettings.HideArtifacts then
				ClearArtifacts()
			else
				LoadArtifacts(data.EquippedArtifacts or {})
			end
		end
		
		-- Handle Low Detail Mode
		-- Note: We check strict difference to avoid spamming on every update
		if activeSettings.LowDetailMode ~= oldSettings.LowDetailMode then
			ApplyLowDetailMode(activeSettings.LowDetailMode)
		end
		
		-- Artifact Loading
		if data.EquippedArtifacts and not activeSettings.HideArtifacts then
			-- Check if changed (Optimization)
			local isDifferent = false
			local currentCount = #activeArtifacts
			
			if #data.EquippedArtifacts ~= currentCount then
				isDifferent = true
			else
				for i, name in ipairs(data.EquippedArtifacts) do
					if activeArtifacts[i] and activeArtifacts[i].Name ~= name then
						isDifferent = true
						break
					end
				end
			end
			
			if isDifferent then
				LoadArtifacts(data.EquippedArtifacts)
			end
		end
	end)
	
	RunService.Heartbeat:Connect(UpdateVisuals)
end

return ArtifactController
