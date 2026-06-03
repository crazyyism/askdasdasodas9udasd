local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local VisualEvent = Remotes:WaitForChild("VisualEvent")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")

local ConversionVisualController = {}

local fishBeams = {} -- [fishModel] = {beam1, beam2, ...}
local isCurrentlyConverting = false

-- Helper to tween NumberSequence transparency using a proxy value (Alpha: 0=Invisible, 1=Original)
local function animateBeamTransparency(beam, originalSeq, startAlpha, endAlpha, duration)
	local val = Instance.new("NumberValue")
	val.Value = startAlpha
	val.Parent = beam -- Clean up later
	
	-- Helper to calculate sequence at alpha
	local function updateTransparency(alpha)
		local newKeypoints = {}
		for _, kp in ipairs(originalSeq.Keypoints) do
			-- alpha=0 -> 1 (Invisible)
			-- alpha=1 -> kp.Value (Original)
			local newVal = 1 - alpha * (1 - kp.Value)
			
			-- Ensure 0-1 range
			if newVal < 0 then newVal = 0 elseif newVal > 1 then newVal = 1 end
			
			-- Scale envelope too
			local newEnvelope = kp.Envelope * alpha
			
			table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, newVal, newEnvelope))
		end
		beam.Transparency = NumberSequence.new(newKeypoints)
	end

	-- Apply initial
	updateTransparency(startAlpha)
	
	local con = val.Changed:Connect(function(v)
		if beam and beam.Parent then
			updateTransparency(v)
		end
	end)
	
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(val, info, {Value = endAlpha})
	tween:Play()
	tween.Completed:Connect(function()
		con:Disconnect()
		val:Destroy()
	end)
	return tween
end

-- Function to create beams for a specific fish (e.g. during conversion)
function ConversionVisualController.CreateBeamsForFish(fishModel, ownerOverride)
	if fishBeams[fishModel] then return end -- Already has beams
	
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local beamFolder = vfxFolder and vfxFolder:FindFirstChild("ConversionBeam")
	if not beamFolder then return end
	
	local targetPlayer = ownerOverride or player
	local character = targetPlayer.Character
	if not character or not character.PrimaryPart then return end
	
	local playerAttachment = character.PrimaryPart:FindFirstChild("ConversionAttachment")
	if not playerAttachment then
		playerAttachment = Instance.new("Attachment")
		playerAttachment.Name = "ConversionAttachment"
		playerAttachment.Parent = character.PrimaryPart
	end
	
	local fishPart = fishModel.PrimaryPart
	if not fishPart then return end
	
	local fishAttachment = fishPart:FindFirstChild("BeamAttachment")
	if not fishAttachment then
		fishAttachment = Instance.new("Attachment")
		fishAttachment.Name = "BeamAttachment"
		fishAttachment.Parent = fishPart
	end
	
	local beamsData = {}
	for _, beamTemplate in ipairs(beamFolder:GetChildren()) do
		if beamTemplate:IsA("Beam") then
			local beam = beamTemplate:Clone()
			beam.Attachment0 = fishAttachment
			beam.Attachment1 = playerAttachment
			beam.Parent = fishPart
			
			-- Store Original Transparency
			local originalTransparency = beam.Transparency
			
			-- Curve Animation (Existing)
			beam.CurveSize0 = 20
			beam.CurveSize1 = 20
			
			-- Fade In: Alpha 0 (Invisible) -> 1 (Original)
			animateBeamTransparency(beam, originalTransparency, 0, 1, 0.15)
			
			beam.Enabled = true
			table.insert(beamsData, {Beam = beam, OriginalTransparency = originalTransparency})
			
			-- Tween to straight
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(beam, tweenInfo, {CurveSize0 = 0, CurveSize1 = 0}):Play()
		end
	end
	
	fishBeams[fishModel] = beamsData
end

-- Function to remove beams from a specific fish
function ConversionVisualController.RemoveBeamsFromFish(fishModel)
	local beamsData = fishBeams[fishModel]
	if beamsData then
		for _, data in ipairs(beamsData) do
			local beam = data.Beam
			local original = data.OriginalTransparency
			
			if beam and beam.Parent then
				-- Fade Out: Alpha 1 (Original) -> 0 (Invisible)
				local fadeTween = animateBeamTransparency(beam, original, 1, 0, 0.5)
				fadeTween.Completed:Connect(function()
					if beam and beam.Parent then
						beam:Destroy()
					end
				end)
			end
		end
		fishBeams[fishModel] = nil
	end
end

-- Function to cleanup all beams
local function cleanupAllBeams()
	for fishModel, _ in pairs(fishBeams) do
		ConversionVisualController.RemoveBeamsFromFish(fishModel)
	end
end

-- Pulsing Beam Animation Loop
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for fishModel, beamsData in pairs(fishBeams) do
		for _, data in ipairs(beamsData) do
			local beam = data.Beam
			if beam and beam.Parent then
				-- Pulse width
				local pulse = 0.8 + math.sin(t * 12) * 0.2
				local originalW0 = data.OriginalW0 or beam.Width0
				local originalW1 = data.OriginalW1 or beam.Width1
				
				-- Cache if not done
				if not data.OriginalW0 then
					data.OriginalW0 = beam.Width0
					data.OriginalW1 = beam.Width1
				end
				
				beam.Width0 = originalW0 * pulse
				beam.Width1 = originalW1 * pulse
			end
		end
	end
end)

-- Listen for conversion state changes (to handle overall cleanup/state)
DataUpdateEvent.OnClientEvent:Connect(function(data)
	if not data then return end
	
	local wasConverting = isCurrentlyConverting
	isCurrentlyConverting = data.IsConverting or false
	
	if wasConverting and not isCurrentlyConverting then
		-- Stopped converting, kill all beams
		cleanupAllBeams()
	end
end)

return ConversionVisualController
