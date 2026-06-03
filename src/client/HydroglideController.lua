local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local AnimationController = require(script.Parent.AnimationController)
local HarvestController = require(script.Parent.HarvestController)

local HydroglideController = {}

local isGliding = false
local currentGlideVFX = nil
local glideAnimTrack = nil
local lastJumpTime = 0
local glideStartTime = 0
local hiddenTools = {} -- [Tool] = original transparency map
local GLIDE_SPEED = 65 -- Forward speed
local SINK_SPEED = -2 -- Slow descent for "glide" feel

local attachment = nil
local linearVelocity = nil
local alignOrientation = nil
local currentBank = 0
local currentPitch = 0
local startGlideHeight = 0

local MAX_ASCENT_STUDS = 50
local ASCENT_SPEED_MULT = 1.1 -- Factor of GLIDE_SPEED for verticality
local GLOBAL_GLIDE_CEILING = 42

function HydroglideController.Start()
	local player = Players.LocalPlayer
	
	-- Listen for Data Updates to track ownership
	local unlockedTools = {}
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
	
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		if data and data.UnlockedTools then
			unlockedTools = {}
			for _, toolId in ipairs(data.UnlockedTools) do
				unlockedTools[toolId] = true
			end
		end
	end)

	local lastPressTime = 0
	local function onJumpPress()
		-- Debounce to prevent double-trigger from multiple input events (JumpRequest + InputBegan)
		local pressNow = os.clock()
		if pressNow - lastPressTime < 0.2 then return end
		lastPressTime = pressNow

		local character = player.Character
		if not character then return end
		local humanoid = character:FindFirstChild("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart then return end
		
		if isGliding then
			-- DISMOUNT logic
			HydroglideController.StopGlide()
		elseif humanoid.FloorMaterial == Enum.Material.Air then
			-- Double Jump Trigger
			if pressNow - lastJumpTime > 0.15 then
				-- Check Ownership
				if not unlockedTools["Hydroglider"] then return end
				
				-- Altitude Check: Only works at -20 Y (World Position) and below
				if rootPart.Position.Y <= GLOBAL_GLIDE_CEILING then
					HydroglideController.StartGlide()
				end
			end
		else
			-- Track ground jump time
			lastJumpTime = pressNow
		end
	end

	-- Connect to JumpRequest (Handles Mobile/Space)
	UserInputService.JumpRequest:Connect(onJumpPress)
	
	-- Supplemental InputBegan for specific key handling if needed
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			-- InputBegan can be more reliable than JumpRequest for "single press" detection in some states
			onJumpPress()
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not isGliding then return end
		HydroglideController.UpdateGlide(dt)
	end)
end

function HydroglideController.StartGlide()
	if isGliding then return end
	
	local player = Players.LocalPlayer
	local character = player.Character
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return end
	
	isGliding = true
	startGlideHeight = rootPart.Position.Y
	glideStartTime = os.clock()
	currentBank = 0
	HarvestController.SetGliding(true)

	-- Hide Current Tool
	local tool = character:FindFirstChildWhichIsA("Tool")
	if tool then
		local transparencies = {}
		for _, desc in ipairs(tool:GetDescendants()) do
			if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
				transparencies[desc] = desc.Transparency
				desc.Transparency = 1
			end
		end
		hiddenTools[tool] = transparencies
	end
	
	-- 1. Physics Setup (Legacy BodyMovers)
	local bv = Instance.new("BodyVelocity")
	bv.Name = "HydroglideVelocity"
	bv.MaxForce = Vector3.new(1, 1, 1) * 1000000 -- Consistent strong force
	bv.Velocity = (rootPart.CFrame.LookVector * GLIDE_SPEED) + Vector3.new(0, SINK_SPEED, 0)
	bv.Parent = rootPart
	linearVelocity = bv -- Reusing variable name for cleaner diff, but it holds a BodyVelocity now
	
	local bg = Instance.new("BodyGyro")
	bg.Name = "HydroglideGyro"
	bg.MaxTorque = Vector3.new(1, 1, 1) * 1000000
	bg.P = 10000 -- Responsiveness
	bg.D = 500   -- Damping
	bg.CFrame = rootPart.CFrame
	bg.Parent = rootPart
	alignOrientation = bg -- Reusing variable name for Gyro
	
	-- 2. VFX Spawn (Accessing RS.VFX.Hydroglide.Hydroglide)
	local vfxBase = ReplicatedStorage:WaitForChild("VFX"):FindFirstChild("Hydroglide")
	local glideModelFolder = vfxBase and vfxBase:FindFirstChild("Hydroglide")
	
	if glideModelFolder then
		currentGlideVFX = glideModelFolder:Clone()
		currentGlideVFX.Name = "Hydroglide_Instance"
		currentGlideVFX.Parent = character
		
		-- Clean existing rigging for fresh weld setup
		for _, d in ipairs(currentGlideVFX:GetDescendants()) do
			if d:IsA("Weld") or d:IsA("WeldConstraint") then
				d:Destroy()
			end
		end

		local mainPart = currentGlideVFX:FindFirstChild("Main") or currentGlideVFX:FindFirstChildWhichIsA("BasePart", true)
		
		if mainPart then
			-- Position Main on Right Hand initially
			local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
			local targetPart = rightHand or rootPart
			
			mainPart.CFrame = targetPart.CFrame * CFrame.new(0, 0, 0)
			mainPart.Anchored = false
			mainPart.CanCollide = false
			mainPart.Massless = true
			
			-- Weld Logic (Simpler than constraints for VFX attachment)
			local weld = Instance.new("Weld")
			weld.Part0 = targetPart
			weld.Part1 = mainPart
			weld.C0 = CFrame.new(0,0,0)
			weld.C1 = CFrame.Angles(0, math.rad(-90), math.rad(-90)) -- Adjust based on model orientation
			weld.Parent = mainPart
			
			-- Ensure all other parts in the model are welded to Main
			for _, descendant in ipairs(currentGlideVFX:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant ~= mainPart then
					descendant.Anchored = false
					descendant.CanCollide = false
					descendant.Massless = true
					
					local subWeld = Instance.new("WeldConstraint")
					subWeld.Part0 = mainPart
					subWeld.Part1 = descendant
					subWeld.Parent = descendant
				end
			end
			
			-- 2.5 Particles & Beam Fading (Enable/Disable particles, Fade beams)
			local glideBeamOriginals = {}
			local glidePartOriginals = {}
			for _, desc in ipairs(currentGlideVFX:GetDescendants()) do
				if desc:IsA("ParticleEmitter") then
					desc.Enabled = true
				elseif desc:IsA("Beam") then
					glideBeamOriginals[desc] = desc.Transparency
					desc.Transparency = NumberSequence.new(1) -- Start invisible
					desc.Enabled = true
				elseif desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
					glidePartOriginals[desc] = desc.Transparency
					desc.Transparency = 1
				end
			end
			
			-- Fade IN Beams and Parts
			task.spawn(function()
				local duration = 0.4
				local startTime = os.clock()
				while isGliding and currentGlideVFX do
					local elapsed = os.clock() - startTime
					local alpha = math.min(elapsed / duration, 1)
					
					-- Fade Beams
					for beam, orig in pairs(glideBeamOriginals) do
						if beam.Parent then
							local kps = {}
							for _, kp in ipairs(orig.Keypoints) do
								local val = kp.Value + (1 - kp.Value) * (1 - alpha)
								table.insert(kps, NumberSequenceKeypoint.new(kp.Time, val, kp.Envelope))
							end
							beam.Transparency = NumberSequence.new(kps)
						end
					end
					
					-- Fade Parts
					for part, orig in pairs(glidePartOriginals) do
						if part.Parent then
							part.Transparency = orig + (1 - orig) * (1 - alpha)
						end
					end
					
					if alpha >= 1 then break end
					RunService.Heartbeat:Wait()
				end
			end)
		end
	end
	
	-- 3. Play Animation (Explicitly Load and Loop)
	AnimationController.SetSuspended(true)
	
	local vfxSource = ReplicatedStorage:WaitForChild("VFX"):FindFirstChild("Hydroglide")
	local animStart = vfxSource and vfxSource:FindFirstChild("HydroglideStart")
	local animLoop = vfxSource and vfxSource:FindFirstChild("HydroglideAnim")
	
	local animator = humanoid:FindFirstChild("Animator")
	if animator then
		-- Stop ALL existing tracks for a clean slate
		for _, tr in ipairs(humanoid:GetPlayingAnimationTracks()) do
			tr:Stop(0.4)
		end
		
		-- Play the Startup Animation once
		if animStart then
			local startTrack = animator:LoadAnimation(animStart)
			startTrack.Priority = Enum.AnimationPriority.Action4
			startTrack.Looped = false
			startTrack:Play(0.1)
		end
		
		-- Play the Main Gliding Loop
		if animLoop then
			glideAnimTrack = animator:LoadAnimation(animLoop)
			glideAnimTrack.Priority = Enum.AnimationPriority.Action3 -- Slightly lower so Startup can override it
			glideAnimTrack.Looped = true
			glideAnimTrack:Play(0.1)
		end
	end
	
	-- State Setup: Set to Physics to disable default Animate script logic while gliding
	humanoid.AutoRotate = false
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
end

function HydroglideController.UpdateGlide(dt)
	local player = Players.LocalPlayer
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChild("Humanoid")
	
	if not rootPart or not humanoid or not linearVelocity or not alignOrientation then
		HydroglideController.StopGlide()
		return
	end
	
	-- Stop if landed (FloorMaterial check + Raycast backup for wall collisions/Physics state)
	-- Ignore Water/Ocean for landing
	local isOnGround = (humanoid.FloorMaterial ~= Enum.Material.Air and humanoid.FloorMaterial ~= Enum.Material.Water)
	
	if not isOnGround then
		-- Downward raycast to check proximity to floor (since FloorMaterial is unreliable in Physics state)
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.RespectCanCollide = true
		
		-- Filter Character AND all Fish
		local filterList = {character}
		local FishController = require(script.Parent.FishController)
		local allFish = FishController.GetAllFish()
		if allFish then
			for _, fishModel in pairs(allFish) do
				table.insert(filterList, fishModel)
			end
		end
		-- Also filter remote fish if possible, or just all "Fish_*" models in workspace? 
		-- Safer to just dump the workspace/Fishes or specific folders if organized?
		-- Let's just iterate workspace for things starting with "Fish_" to be safe and robust.
		for _, child in ipairs(workspace:GetChildren()) do
			if child.Name:match("^Fish_") then
				table.insert(filterList, child)
			end
		end
		
		rayParams.FilterDescendantsInstances = filterList
		
		local rayResult = workspace:Raycast(rootPart.Position, Vector3.new(0, -3.5, 0), rayParams)
		if rayResult then
			local inst = rayResult.Instance
			local isOcean = string.find(string.lower(inst.Name), "ocean") or inst:FindFirstAncestor("Ocean") or inst:FindFirstAncestor("ocean")
			if not isOcean then
				isOnGround = true
			end
		end
	end

	if isOnGround or rootPart.Position.Y > GLOBAL_GLIDE_CEILING + 10 then -- Increased buffer to prevent accidental hard stops
		HydroglideController.StopGlide()
		return
	end
	
	-- Movement & Steering Logic
	local camera = workspace.CurrentCamera
	local moveDir = humanoid.MoveDirection
	local localMove = rootPart.CFrame:VectorToObjectSpace(moveDir)
	
	-- Determine Target Facing (Steering follows Camera now, A/D only tilts)
	local camLook = camera.CFrame.LookVector
	local targetLook = Vector3.new(camLook.X, 0, camLook.Z)
	if targetLook.Magnitude > 0.1 then
		targetLook = targetLook.Unit
	else
		targetLook = rootPart.CFrame.LookVector
	end
	
	-- 1. Calculate Banking (Roll/A-D) and Pitch (Tilt/Camera)
	-- Banking based on horizontal input (A/D) - only tilts, doesn't steer
	local targetBank = -localMove.X * math.rad(30)
	currentBank = currentBank + (targetBank - currentBank) * (1 - math.exp(-dt * 8))

	-- 2. Vertical Ascent Logic (Capped at 15 studs with strict clamping)
	-- Acceleration Factor (1.0 second to reach full speed)
	local elapsed = os.clock() - glideStartTime
	local speedMult = math.clamp(elapsed / 1.0, 0, 1)
	local currentMaxSpeed = GLIDE_SPEED * speedMult
	
	-- Vertical intent based on camera pitch
	local verticalClimb = camLook.Y * currentMaxSpeed * ASCENT_SPEED_MULT
	
	-- Apply pitch tilt based on where we are looking (Tilt up when looking up)
	local targetPitch = -camLook.Y * math.rad(30)
	currentPitch = currentPitch + (targetPitch - currentPitch) * (1 - math.exp(-dt * 6))

	-- Check height caps (Relative 50 studs OR Global 7 barrier)
	local currentAltitude = rootPart.Position.Y
	local altitudeGain = currentAltitude - startGlideHeight
	
	-- Total vertical intent (Climb/Input + Default Sink)
	local totalVerticalVelocity = verticalClimb + SINK_SPEED
	
	-- Unified Dampening: Slow down as we approach EITHER limit
	local distToRelative = MAX_ASCENT_STUDS - altitudeGain
	local distToGlobal = GLOBAL_GLIDE_CEILING - currentAltitude
	local distToCeiling = math.min(distToRelative, distToGlobal)
	
	local margin = 5 
	if distToCeiling < margin and totalVerticalVelocity > 0 then
		-- Smoothly reduce upward velocity to 0 as we hit the limit
		local t = math.clamp(distToCeiling / margin, 0, 1)
		totalVerticalVelocity = totalVerticalVelocity * (t * t) 
	end
	
	-- Strict Ceiling Enforcement (Push down if overshot)
	if distToCeiling <= 0 then
		-- distToCeiling is negative overlap amount. 
		-- Correction force proportional to overshoot distance, but CAPPED to prevent ground slams
		local correctionValues = distToCeiling * 10 -- Reduced multiplier (was 200) for softer rejection
		
		-- Cap max downward correction speed to -15 to prevent instant ground collision
		local maxCorrectionSpeed = -15
		
		-- Force velocity down if it's trying to go up, or if the correction is stronger than current fall
		-- We use math.max on the correction to ensure we don't apply -1000 velocity
		totalVerticalVelocity = math.min(totalVerticalVelocity, math.max(correctionValues, maxCorrectionSpeed))
	end
	
	-- 3. Update target orientation (including Banking and Pitch)
	local baseRot = CFrame.lookAt(Vector3.new(0, 0, 0), targetLook, Vector3.new(0, 1, 0))
	alignOrientation.CFrame = baseRot * CFrame.Angles(currentPitch, 0, currentBank)
	
	-- 4. Update velocity
	-- Using targetLook specifically for horizontal velocity ensures pitch-rotation NEVER affects altitude
	local horizontalVelocity = targetLook * currentMaxSpeed
	linearVelocity.Velocity = horizontalVelocity + Vector3.new(0, totalVerticalVelocity, 0)
end

function HydroglideController.StopGlide()
	local wasGliding = isGliding
	isGliding = false
	HarvestController.SetGliding(false)
	
	local player = Players.LocalPlayer
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	-- Capture Momentum before destruction
	local launchVelocity = Vector3.zero
	if wasGliding and rootPart then
		local cam = workspace.CurrentCamera
		local lookDir = cam and cam.CFrame.LookVector or rootPart.CFrame.LookVector
		
		-- Use pure camera direction for "Tidebreaker" feel (Look up to fly up, down to dive)
		-- Speed: 120
		launchVelocity = lookDir * 120
	end
	
	-- Restore Tools
	for tool, transparencies in pairs(hiddenTools) do
		if tool.Parent then
			for part, trans in pairs(transparencies) do
				if part.Parent then
					part.Transparency = trans
				end
			end
		end
	end
	hiddenTools = {}

	if humanoid then
		humanoid.AutoRotate = true
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	
	AnimationController.SetSuspended(false)
	
	if attachment then attachment:Destroy() attachment = nil end
	if linearVelocity then linearVelocity:Destroy() linearVelocity = nil end
	if alignOrientation then alignOrientation:Destroy() alignOrientation = nil end
	
	-- Apply Exit Momentum
	if rootPart and launchVelocity.Magnitude > 0 then
		rootPart.AssemblyLinearVelocity = launchVelocity
	end
	
	if currentGlideVFX then
		local vfxToCleanup = currentGlideVFX
		currentGlideVFX = nil
		
		-- Collect beams and parts for fade-out
		local beams = {}
		local beamOriginals = {}
		local parts = {}
		local partOriginals = {}
		
		for _, desc in ipairs(vfxToCleanup:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = false
			elseif desc:IsA("Beam") then
				table.insert(beams, desc)
				beamOriginals[desc] = desc.Transparency
			elseif desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
				table.insert(parts, desc)
				partOriginals[desc] = desc.Transparency
			end
		end
		
		-- Fade-out loop then destroy
		task.spawn(function()
			local duration = 0.5
			local startTime = os.clock()
			
			while true do
				local elapsed = os.clock() - startTime
				local alpha = math.min(elapsed / duration, 1)
				
				-- Fade Beams
				for _, beam in ipairs(beams) do
					if beam.Parent then
						local orig = beamOriginals[beam]
						local kps = {}
						for _, kp in ipairs(orig.Keypoints) do
							local val = kp.Value + (1 - kp.Value) * alpha
							table.insert(kps, NumberSequenceKeypoint.new(kp.Time, val, kp.Envelope))
						end
						beam.Transparency = NumberSequence.new(kps)
					end
				end
				
				-- Fade Parts
				for _, part in ipairs(parts) do
					if part.Parent then
						local orig = partOriginals[part]
						part.Transparency = orig + (1 - orig) * alpha
					end
				end
				
				if alpha >= 1 then break end
				RunService.Heartbeat:Wait()
			end
			
			vfxToCleanup:Destroy()
		end)
	end
	
	if glideAnimTrack then
		glideAnimTrack:Stop(0.7)
		glideAnimTrack = nil
	end
	
	currentBank = 0
	currentPitch = 0
end

return HydroglideController
