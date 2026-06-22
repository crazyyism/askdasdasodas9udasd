local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local FishController = require(script.Parent.FishController)

local VFXController = {}

local rainmakerStates = {}
local activeBlackHoles = {} -- [Player] = Sphere Instance
local beamCache = {}

local originalC0Cache = setmetatable({}, {__mode = "k"})

local function getOriginalC0(motor)
	if not originalC0Cache[motor] then
		originalC0Cache[motor] = motor.C0
	end
	return originalC0Cache[motor]
end

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ActiveUpdaters = {}
local nextUpdaterId = 1
RunService.RenderStepped:Connect(function(dt)
	for _, updater in pairs(ActiveUpdaters) do
		updater(dt)
	end
end)

local localData = nil
local DataUpdateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DataUpdateEvent")

local function PlaySFX(sound, parent, duration)
	if not sound then return end
	
	-- Check Settings
	local isSfxDisabled = false
	if localData and localData.Settings then
		isSfxDisabled = localData.Settings.DisableSFX
	end
	
	if isSfxDisabled then return end
	
	local s = sound:Clone()
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, (duration or s.TimeLength) + 1)
	return s
end

function VFXController.PlayRainmakerAbility(player)
	if not player or not player.Character then return end
	local char = player.Character
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	-- Play Charge Sound
	local chargeSfx = ReplicatedStorage.VFX.Rainmaker:FindFirstChild("ChargeAbility")
	PlaySFX(chargeSfx, root)
	
	-- Animations
	local hum = char:FindFirstChild("Humanoid")
	local animator = hum and hum:FindFirstChild("Animator")
	local chargeTrack, fireTrack
	
	if animator then
		-- Load Charge Animation (plays for 2 seconds)
		local chargeAnim = Instance.new("Animation")
		chargeAnim.AnimationId = "rbxassetid://86689941560059"
		chargeTrack = animator:LoadAnimation(chargeAnim)
		chargeTrack.Priority = Enum.AnimationPriority.Action4
		chargeTrack.Looped = false
		
		-- Load Fire Animation (plays for 2.325 seconds)
		local fireAnim = Instance.new("Animation")
		fireAnim.AnimationId = "rbxassetid://87878824664845"
		fireTrack = animator:LoadAnimation(fireAnim)
		fireTrack.Priority = Enum.AnimationPriority.Action4
		fireTrack.Looped = true
	
		chargeTrack:Play()
		
		-- Stop charge and start fire animation at 2 seconds
		task.delay(2, function()
			if chargeTrack then chargeTrack:Stop() end
			if fireTrack then fireTrack:Play() end
			
			-- Play Fire Sound
			local fireSfx = ReplicatedStorage.VFX.Rainmaker:FindFirstChild("FireAbility")
			PlaySFX(fireSfx, root)
			
			-- Distance Check for Screen Effects
			local distToLocal = 0
			local localPlayer = Players.LocalPlayer
			if localPlayer and localPlayer.Character and localPlayer.Character.PrimaryPart then
				distToLocal = (localPlayer.Character.PrimaryPart.Position - root.Position).Magnitude
			elseif player ~= localPlayer then
				distToLocal = 99999
			end
			
			-- Only play Screen VFX if within range (or self)
			if distToLocal <= 100 then
				-- Impact Flash Effect (0.2 seconds, 2 flashes)
				local Lighting = game:GetService("Lighting")
				local colorCorrection = Instance.new("ColorCorrectionEffect")
				colorCorrection.Parent = Lighting
				
				task.spawn(function()
					-- Flash 1: Blue highlights, black background
					colorCorrection.Brightness = -1
					colorCorrection.Saturation = 1
					colorCorrection.TintColor = Color3.fromRGB(0, 100, 255)
					colorCorrection.Contrast = 1
					
					task.wait(0.05)
					
					-- Invert: White highlights, blue background
					colorCorrection.Brightness = 0.5
					colorCorrection.Saturation = -1
					colorCorrection.TintColor = Color3.fromRGB(100, 150, 255)
					colorCorrection.Contrast = 0.5
					
					task.wait(0.05)
					
					-- Flash 2: Blue highlights, black background
					colorCorrection.Brightness = -1
					colorCorrection.Saturation = 1
					colorCorrection.TintColor = Color3.fromRGB(0, 100, 255)
					colorCorrection.Contrast = 1
					
					task.wait(0.05)
					
					-- Invert: White highlights, blue background
					colorCorrection.Brightness = 0.5
					colorCorrection.Saturation = -1
					colorCorrection.TintColor = Color3.fromRGB(100, 150, 255)
					colorCorrection.Contrast = 0.5
					
					task.wait(0.05)
					
					-- Cleanup
					colorCorrection:Destroy()
				end)
				
				-- Camera Shake Effect (2.15 seconds, gradually calming down)
				local camera = workspace.CurrentCamera
				if camera then
					task.spawn(function()
						local shakeDuration = 2.325
						local startTime = os.clock()
						local shakeFrequency = 30 -- Hz
						
						while os.clock() - startTime < shakeDuration do
							local elapsed = os.clock() - startTime
							local progress = elapsed / shakeDuration
							
							-- Decay from strong to weak (exponential decay)
							local intensity = 0.5 * math.exp(-progress * 3) -- Start at 0.5, decay exponentially
							
							-- Random shake offset
							local randomX = (math.random() - 0.5) * 2 * intensity
							local randomY = (math.random() - 0.5) * 2 * intensity
							local randomZ = (math.random() - 0.5) * 2 * intensity
							
							-- Apply shake to camera
							camera.CFrame = camera.CFrame * CFrame.Angles(
								math.rad(randomX),
								math.rad(randomY),
								math.rad(randomZ)
							)
							
							RunService.RenderStepped:Wait()
						end
					end)
				end
			end
		end)
		
		-- Stop fire animation at 4.325 seconds (2 + 2.325)
		task.delay(4.325, function()
			if fireTrack then fireTrack:Stop() end
		end)
	end
	
	-- Setup barrel rotation (starts immediately)
	local tool = char:FindFirstChild("Rainmaker")
	if tool then
		local handle = tool:FindFirstChild("Handle")
		local motor = handle and handle:FindFirstChild("MainRotate")
		
		-- Barrel rotation state
		local barrelSpeed = 0
		local barrelAngle = 0
		local barrelActive = true -- Start active immediately
		local baseC0 = motor and getOriginalC0(motor)
		
		-- Start barrel rotation loop immediately
		local updaterId = nextUpdaterId
		nextUpdaterId += 1
		ActiveUpdaters[updaterId] = function(dt)
			if not tool.Parent or tool.Parent ~= char then
				ActiveUpdaters[updaterId] = nil
				return
			end
			
			local accel = 12.5
			local targetSpeed = barrelActive and 25 or 0
			
			if barrelSpeed < targetSpeed then
				barrelSpeed = math.min(barrelSpeed + (accel * dt), 25)
			else
				barrelSpeed = math.max(barrelSpeed - (accel * dt), 0)
			end
			
			if barrelSpeed > 0 then
				barrelAngle = barrelAngle + (barrelSpeed * dt)
				if motor then
					local base = baseC0 or CFrame.new(0, -0.5, 0)
					motor.C0 = base * CFrame.Angles(barrelAngle, 0, 0)
				end
			elseif barrelSpeed <= 0 and not barrelActive then
				-- Fully stopped, disconnect
				ActiveUpdaters[updaterId] = nil
				if motor and baseC0 then
					motor.C0 = baseC0
				end
			end
		end
		
		-- Enable tool beams/particles after 2 second delay (when VFX spawns)
		task.delay(2, function()
			if not tool.Parent or tool.Parent ~= char then return end
			
			-- Enable tool beams/particles
			local toolBeamOriginals = {}
			
			-- Cache and initialize tool beams
			for _, desc in ipairs(tool:GetDescendants()) do
				if desc:IsA("Beam") then
					toolBeamOriginals[desc] = desc.Transparency
					desc.Transparency = NumberSequence.new(1) -- Start fully invisible
					desc.Enabled = true
					desc:SetAttribute("CurrentOpacity", 0)
				elseif desc:IsA("ParticleEmitter") then
					desc.Enabled = true
				end
			end
			
			-- Fade IN tool beams
			task.spawn(function()
				local duration = 0.6
				local start = os.clock()
				while true do
					local elapsed = os.clock() - start
					local alpha = math.min(elapsed / duration, 1)
					
					for desc, orig in pairs(toolBeamOriginals) do
						if desc.Parent then
							local kps = {}
							for _, kp in ipairs(orig.Keypoints) do
								local val = kp.Value + (1 - kp.Value) * (1 - alpha) -- Fade from 1 to original
								table.insert(kps, NumberSequenceKeypoint.new(kp.Time, val, kp.Envelope))
							end
							desc.Transparency = NumberSequence.new(kps)
							desc:SetAttribute("CurrentOpacity", alpha)
						end
					end
					
					if alpha >= 1 then break end
					RunService.Heartbeat:Wait()
				end
			end)
			
			-- Fade OUT tool beams after ability (2.325 seconds active time)
			task.delay(2.325, function()
				barrelActive = false -- Start barrel deceleration
				
				-- Disable particles immediately when fade starts
				for _, desc in ipairs(tool:GetDescendants()) do
					if desc:IsA("ParticleEmitter") then
						desc.Enabled = false
					end
				end
				
				local duration = 0.6
				local start = os.clock()
				while true do
					local elapsed = os.clock() - start
					local alpha = math.min(elapsed / duration, 1)
					
					for desc, orig in pairs(toolBeamOriginals) do
						if desc.Parent then
							local kps = {}
							for _, kp in ipairs(orig.Keypoints) do
								local val = kp.Value + (1 - kp.Value) * alpha -- Fade from original to 1
								table.insert(kps, NumberSequenceKeypoint.new(kp.Time, val, kp.Envelope))
							end
							desc.Transparency = NumberSequence.new(kps)
							desc:SetAttribute("CurrentOpacity", 1 - alpha)
						end
					end
					
					if alpha >= 1 then
						-- Disable beams at end
						for desc, _ in pairs(toolBeamOriginals) do
							if desc.Parent and desc:IsA("Beam") then
								desc.Enabled = false
							end
						end
						break
					end
					RunService.Heartbeat:Wait()
				end
			end)
		end)
	end
	
	task.spawn(function()
		task.wait(2)
		if not char.Parent then return end
		
		local vfxPrefab = ReplicatedStorage.VFX.Rainmaker:FindFirstChild("RainmakerAbilityVFX")
		if not vfxPrefab then 
			warn("RainmakerAbilityVFX missing") 
			return 
		end
		
		local vfx = vfxPrefab:Clone()
		vfx.CFrame = root.CFrame * CFrame.new(0, 0, -10) 
		vfx.Parent = workspace
		if vfx:IsA("BasePart") then
			vfx.Anchored = false
			vfx.Massless = true
			vfx.CanCollide = false
		end
		
		-- Physics Constraint Follow
		local att0 = Instance.new("Attachment")
		att0.Parent = vfx
		
		local att1 = Instance.new("Attachment")
		att1.CFrame = CFrame.new(0, 0, -5)
		att1.Parent = root
		
		local alignPos = Instance.new("AlignPosition")
		alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
		alignPos.Attachment0 = att0
		alignPos.Attachment1 = att1
		alignPos.RigidityEnabled = true
		alignPos.Parent = vfx
		
		local alignRot = Instance.new("AlignOrientation")
		alignRot.Mode = Enum.OrientationAlignmentMode.TwoAttachment
		alignRot.Attachment0 = att0
		alignRot.Attachment1 = att1
		alignRot.RigidityEnabled = true
		alignRot.Parent = vfx
		
		-- Cache original beam transparency (for ability VFX, no fade-in, just enable)
		local beamOriginals = {}
		for _, d in ipairs(vfx:GetDescendants()) do
			if d:IsA("Beam") then 
				beamOriginals[d] = d.Transparency
				-- Skip fade-in, immediately show at full opacity
				d.Enabled = true
			end
			if d:IsA("ParticleEmitter") then 
				d.Enabled = true 
			end
		end
		
		task.wait(2.325)
		
		-- Fade Out (beams only)
		local duration = 0.6
		local start = os.clock()
		while true do
			local alpha = math.min((os.clock() - start)/duration, 1)
			for _, d in ipairs(vfx:GetDescendants()) do
				if d:IsA("Beam") and beamOriginals[d] then
					-- Preserve original keypoints, multiply by fade
					local original = beamOriginals[d]
					local keypoints = {}
					for i, kp in ipairs(original.Keypoints) do
						table.insert(keypoints, NumberSequenceKeypoint.new(
							kp.Time,
							kp.Value + (1 - kp.Value) * alpha -- Fade from original to 1
						))
					end
					d.Transparency = NumberSequence.new(keypoints)
				elseif d:IsA("ParticleEmitter") then
					d.Enabled = false
				end
			end
			if alpha >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		
		-- Disable beams after fade out
		for _, d in ipairs(vfx:GetDescendants()) do
			if d:IsA("Beam") then d.Enabled = false end
		end
		
		vfx:Destroy()
		if att1 then att1:Destroy() end
	end)
end

function VFXController.HandleRainmakerState(player, state)
	if not player or not player.Character then return end
	local char = player.Character
	local tool = char and char:FindFirstChild("Rainmaker")
	
	if not tool and player then
		local bp = player:FindFirstChild("Backpack")
		tool = bp and bp:FindFirstChild("Rainmaker")
	end
	
	if not tool then
		-- Tool might be destroyed or not found
		return 
	end
	
	local handle = tool:FindFirstChild("Handle")
	local motor = handle and handle:FindFirstChild("MainRotate")
	
	if not rainmakerStates[player] then
		rainmakerStates[player] = {
			Speed = 0,
			Angle = 0,
			TargetSpeed = 0,
			IsActive = false,
			Conn = nil,
			FadeThreads = {}
		}
	end
	
	local d = rainmakerStates[player]
	
	-- State Guard: Don't repeat identical state logic (Prevents duplicate sfx)
	if d.LastState == state then return end
	d.LastState = state
	
	-- Helper for Particles/Beams
	local function setParticles(active)
		local targetOpacity = active and 1 or 0 -- 1 = Opacity (0 Transparancy), wait. Transparency: 1 is invisible.
		-- My logic in HarvestController was:
		-- updateBeamOpacity(beam, opacity) where opacity 1 = Visible(Original), 0 = Invisible(Transp 1).
		
		-- Ported logic:
		for _, desc in ipairs(tool:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = active
			elseif desc:IsA("Beam") then
				desc.Enabled = true
				
				-- Cache Original
				if not beamCache[desc] then
					if not desc:GetAttribute("CurrentOpacity") then
						beamCache[desc] = desc.Transparency
					end
				end
				
				local orig = beamCache[desc]
				if not orig then continue end
				
				-- Fade Thread
				if d.FadeThreads[desc] then task.cancel(d.FadeThreads[desc]) end
				
				local startOp = desc:GetAttribute("CurrentOpacity") or 0
				local targetOp = active and 1 or 0 -- 1 is Fully Visible (Original), 0 is Invisible (Transp 1)
				
				d.FadeThreads[desc] = task.spawn(function()
					local t = 0
					local duration = 0.6
					local start = os.clock()
					while true do
						local elapsed = os.clock() - start
						local alpha = math.min(elapsed / duration, 1)
						local cur = startOp + (targetOp - startOp) * alpha
						
						-- Apply
						local kps = {}
						for _, kp in ipairs(orig.Keypoints) do
							local val = kp.Value + (1 - kp.Value) * (1 - cur)
							table.insert(kps, NumberSequenceKeypoint.new(kp.Time, val, kp.Envelope))
						end
						desc.Transparency = NumberSequence.new(kps)
						desc:SetAttribute("CurrentOpacity", cur)
						
						if alpha >= 1 then 
							if not active then desc.Enabled = false end
							break 
						end
						RunService.Heartbeat:Wait()
					end
					d.FadeThreads[desc] = nil
				end)
			end
		end
	end
	
	if state == "Charge" then
		d.IsActive = true
		
		-- Store BaseC0 if not exists
		if motor and not d.BaseC0 then
			d.BaseC0 = getOriginalC0(motor)
		end
		
		-- Start Loop if needed
		if not d.UpdaterId then
			d.UpdaterId = nextUpdaterId
			nextUpdaterId += 1
			ActiveUpdaters[d.UpdaterId] = function(dt)
				if not tool.Parent or tool.Parent ~= char then
					ActiveUpdaters[d.UpdaterId] = nil
					d.UpdaterId = nil
					d.IsActive = false
					d.BaseC0 = nil
					return
				end
				
				local accel = 12.5 
				local target = d.IsActive and 25 or 0
				
				if d.Speed < target then
					d.Speed = math.min(d.Speed + (accel*dt), 25)
				else
					d.Speed = math.max(d.Speed - (accel*dt), 0)
				end
				
				if d.Speed > 0 then
					d.Angle = d.Angle + (d.Speed * dt)
					if motor then 
						local base = d.BaseC0 or CFrame.new(0,-0.5,0)
						motor.C0 = base * CFrame.Angles(d.Angle, 0, 0) 
					end 
				elseif d.Speed <= 0 and not d.IsActive then
					ActiveUpdaters[d.UpdaterId] = nil
					d.UpdaterId = nil
					d.Angle = 0 -- Reset?
					if motor and d.BaseC0 then
						motor.C0 = d.BaseC0
					end
				end
			end
		end
		
		-- Audio (Charge)
		local chargeSfx = tool.Handle:FindFirstChild("Charge") or ReplicatedStorage.VFX.Rainmaker.Charge:Clone()
		chargeSfx.Name = "Charge"
		chargeSfx.Parent = tool.Handle
		
		local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
		if not isSfxDisabled and not chargeSfx.Playing then
			chargeSfx:Play()
		end
		
		-- Init Beams to invisible?
		setParticles(false)
		
	elseif state == "Fire" then
		d.IsActive = true
		d.TargetSpeed = 25 -- Full speed
		setParticles(true)
		
		-- Stop Charge Sound
		local chargeSfx = tool.Handle:FindFirstChild("Charge")
		if chargeSfx then chargeSfx:Stop() end
		
		-- Minigun Loop Sound
		local loopSfx = tool.Handle:FindFirstChild("Minigun") or ReplicatedStorage.VFX.Rainmaker.Minigun:Clone()
		loopSfx.Name = "Minigun"
		loopSfx.Parent = tool.Handle
		loopSfx.Looped = true
		
		local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
		if not isSfxDisabled and not loopSfx.Playing then 
			loopSfx:Play() 
		end
		
	elseif state == "Stop" then
		d.IsActive = false
		d.TargetSpeed = 0
		setParticles(false)
		
		-- Stop Sounds
		local chargeSfx = tool.Handle:FindFirstChild("Charge")
		if chargeSfx then chargeSfx:Stop() end
		
		local loopSfx = tool.Handle:FindFirstChild("Minigun")
		if loopSfx then loopSfx:Stop() end
		
		local endSfx = ReplicatedStorage.VFX.Rainmaker.End:Clone()
		PlaySFX(endSfx, tool.Handle, 2)
	end
end

function VFXController.PlayGuardianVFX(player, hrp, movetype)
	if movetype == "main" then
		local RS = ReplicatedStorage
		local TweenService = game:GetService("TweenService")
		local Debris = game:GetService("Debris")

		local guardianPrefab = RS.VFX.GuardianCall:FindFirstChild("guardiene")
		if not guardianPrefab then return end
		local guardian = guardianPrefab:Clone()

		-- Ensure no initial collision spike: configure before parenting
		local parts = {}
		for _, part in pairs(guardian:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false -- Also disable raycast/querying
				part.Massless = true
				table.insert(parts, part)
				-- Put guardian into NPCs collision group so it won't collide with Players
				pcall(function()
					part.CollisionGroup = "NPCs"
				end)
			end
		end

		guardian.Parent = workspace
		
		-- Robust Collision Disable: Humanoids often re-enable CanCollide on certain parts.
		-- We use a heartbeat connection to keep it off until destroyed.
		local collisionConn
		collisionConn = game:GetService("RunService").Heartbeat:Connect(function()
			if not guardian or not guardian.Parent then
				if collisionConn then collisionConn:Disconnect() end
				return
			end
			for _, p in ipairs(parts) do
				if p.Parent then p.CanCollide = false end
			end
		end)

		task.spawn(function()
			local fogFolder = RS.VFX.GuardianCall:FindFirstChild("fog")
			local vfxPrefab = fogFolder and fogFolder:FindFirstChild("Attachment")
			if not vfxPrefab then return end
			local vfx = vfxPrefab:Clone()
			vfx.Parent = guardian.HumanoidRootPart

			vfx.CFrame = CFrame.new() -- Reset to match parent's orientation

			for _, Particles in ipairs(vfx:GetDescendants()) do
				if Particles:IsA("ParticleEmitter") then
					Particles.Enabled = true
				end
			end

			task.wait(.6)
			for _, Particles in ipairs(vfx:GetDescendants()) do
				if Particles:IsA("ParticleEmitter") then
					Particles.Enabled = false
				end
			end

			task.wait(2)
			vfx:Destroy()
		end)

		local audioFolder = RS.VFX.GuardianCall:FindFirstChild("voicelines") 
		if audioFolder then
			local audioFiles = audioFolder:GetChildren()
			if #audioFiles > 0 then
				local randomAudio = audioFiles[math.random(1, #audioFiles)]
				PlaySFX(randomAudio, guardian, 15)
			end
		end

		-- Position guardian behind the player
		local playerCFrame = hrp.CFrame
		local behindOffset = playerCFrame.LookVector * -20 -- 20 studs behind player
		local spawnPosition = hrp.Position + behindOffset

		spawnPosition = Vector3.new(spawnPosition.X, spawnPosition.Y + 3, spawnPosition.Z)

		-- Set guardian position and make it face the same direction as player
		guardian:PivotTo(CFrame.new(spawnPosition, spawnPosition + playerCFrame.LookVector))

		-- Get guardian's humanoid and animator for animation
		local guardianHumanoid = guardian:FindFirstChild("Humanoid")
		local guardianAnimator = guardianHumanoid and guardianHumanoid:FindFirstChild("Animator")

		-- Load and play guardian animation
		local guardianAnimation
		if guardianAnimator then
			local animationId = RS.VFX.GuardianCall:FindFirstChild("Animation")
			if animationId then
				guardianAnimation = guardianAnimator:LoadAnimation(animationId)
				guardianAnimation:Play()
			end
		end

		-- Calculate forward position (in front of player)
		local forwardOffset = playerCFrame.LookVector * 15 -- 15 studs in front of player
		local targetPosition = hrp.CFrame * CFrame.new(0, 3, -15)

		-- Create tween to move guardian forward
		local moveInfo = TweenInfo.new(
			0.6,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

		local moveTween = TweenService:Create(
			guardian.PrimaryPart,
			moveInfo,
			{CFrame = targetPosition}
		)

		moveTween:Play()
		moveTween.Completed:Connect(function()
			local slashSfx = RS.VFX.GuardianCall:FindFirstChild("slash")
			PlaySFX(slashSfx, guardian, 15)

			local vfxFolder = RS.VFX.GuardianCall:FindFirstChild("guardianvfx")
			local vfx1Prefab = vfxFolder and vfxFolder:FindFirstChild("Vfx")
			if vfx1Prefab then
				local vfx1 = vfx1Prefab:Clone()
				vfx1.Parent = guardian.HumanoidRootPart

				for _, Particles in ipairs(vfx1:GetDescendants()) do
					if Particles:IsA("ParticleEmitter") then
						local emitCount = Particles:GetAttribute("EmitCount") or 1
						task.wait() 
						Particles:Emit(emitCount)
					end
				end
				Debris:AddItem(vfx1, 5)
			end

			-- Wait 1.5 seconds before fading
			task.wait(1.5)

			-- Collect all parts that can be made transparent
			local partsToFade = {}
			for _, part in pairs(guardian:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("Decal") or part:IsA("Texture") then
					table.insert(partsToFade, part)
				end
			end

			-- Create fade out tween
			local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local lastTween = nil
			-- Create fade tweens for all parts
			for _, part in pairs(partsToFade) do
				local tween = TweenService:Create(part, fadeInfo, {Transparency = 1})
				tween:Play()
				lastTween = tween
			end

			-- Clean up after fade completes
			if lastTween then
				lastTween.Completed:Connect(function()
					guardian:Destroy()
				end)
			else
				guardian:Destroy()
			end
		end)

		Debris:AddItem(guardian, 15)
	else
		-- Indicator and Crater
		local RS = ReplicatedStorage
		local indicatorFolder = RS.VFX.GuardianCall:FindFirstChild("indicator")
		local vfx1Prefab = indicatorFolder and indicatorFolder:FindFirstChild("Attachment")
		
		if vfx1Prefab then
			local vfx1 = vfx1Prefab:Clone()
			vfx1.Parent = hrp

			-- Crater logic
			local CraterModule = _G.CraterModule -- Fallback if placed in _G
			if not CraterModule then
				-- Try to find it if it's a script/module
				local search = RS:FindFirstChild("CraterModule", true)
				if search then CraterModule = require(search) end
			end

			if CraterModule and CraterModule.Explosion then
				local gentleVelocity = {
					MinHorizontal = 10,
					MaxHorizontal = 20,
					Upward = 8,
					RandomUpward = true
				}
				local craterPosition = hrp.CFrame
				CraterModule.Explosion(craterPosition * CFrame.new(0,-2,0), 25, .35,.75, false, gentleVelocity)
			end

			for _, Particles in ipairs(vfx1:GetDescendants()) do
				if Particles:IsA("ParticleEmitter") then
					local emitCount = Particles:GetAttribute("EmitCount") or 1
					task.wait() 
					Particles:Emit(emitCount)
				end
			end
			Debris:AddItem(vfx1, 5)
		end
	end
end

function VFXController.PlayDescentFromHeaven(player, hitboxPosition, extraData)
	local RS = ReplicatedStorage
	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	
	local function ApplySunkissedTint(model)
		if not (extraData and extraData.SunkissedTint) then return end
		local fieryOrangeRed = Color3.fromRGB(255, 119, 85)
		local deepRed = Color3.fromRGB(255, 119, 85)
		
		for _, desc in pairs(model:GetDescendants()) do
			if desc:IsA("MeshPart") then
				desc.TextureID = ""
				desc.Color = deepRed
				desc.Material = Enum.Material.Neon
			elseif desc:IsA("BasePart") then
				desc.Color = deepRed
				desc.Material = Enum.Material.Neon
			elseif desc:IsA("SpecialMesh") then
				desc.TextureId = ""
				desc.VertexColor = Vector3.new(deepRed.R, deepRed.G, deepRed.B)
			elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
				desc.Color = ColorSequence.new(fieryOrangeRed)
			elseif desc:IsA("Decal") or desc:IsA("Texture") then
				desc.Color3 = fieryOrangeRed
			elseif desc:IsA("Light") then
				desc.Color = fieryOrangeRed
			end
		end
		
		if model:IsA("BasePart") then model.Color = deepRed end
		if model:IsA("MeshPart") then model.TextureID = "" end
	end

	-- Helper function to create and setup a ghostguardiene
	local function createGhostguardiene(spawnOffset, targetOffset, facingDirection)
		local vfxFolder = RS:FindFirstChild("VFX")
		local dfhFolder = vfxFolder and vfxFolder:FindFirstChild("DescentFromHeaven")
		local template = dfhFolder and dfhFolder:FindFirstChild("ghostguardiene")
		
		if not template then return end
		
		local ghostguardiene = template:Clone()
		
		-- Ensure no initial collision spike: configure before parenting
		for _, part in pairs(ghostguardiene:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
				part.Massless = true
				-- Put ghostguardiene into NPCs collision group so it won't collide with Players
				pcall(function()
					part.CollisionGroup = "NPCs"
				end)
			end
		end
		
		-- Continuous collision fix (Humanoids reset CanCollide)
		local conn
		conn = RunService.Stepped:Connect(function()
			if not ghostguardiene or not ghostguardiene.Parent then
				if conn then conn:Disconnect() end
				return
			end
			for _, part in pairs(ghostguardiene:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
				end
			end
		end)
		
		ApplySunkissedTint(ghostguardiene)
		ghostguardiene.Parent = workspace
		
		-- Spawn 100 studs up from hitbox position with offset
		local spawnPosition = hitboxPosition + spawnOffset + Vector3.new(0, 100, 0)
		-- Set facing direction
		local spawnCFrame = CFrame.new(spawnPosition, spawnPosition + facingDirection)
		ghostguardiene:PivotTo(spawnCFrame)
		
		-- Get ghostguardiene's humanoid and animator for animation
		local ghostguardieneHumanoid = ghostguardiene:FindFirstChild("Humanoid")
		local ghostguardieneAnimator = ghostguardieneHumanoid and ghostguardieneHumanoid:FindFirstChild("Animator")
		
		-- Load and play ghostguardiene animation
		if ghostguardieneAnimator then
			local animationId = dfhFolder:FindFirstChild("Animation")
			if animationId then
				local ghostguardieneAnimation = ghostguardieneAnimator:LoadAnimation(animationId)
				ghostguardieneAnimation:Play()
			end
		end
		
		-- Calculate target position (90 studs down from spawn, with offset)
		local targetPosition = hitboxPosition + targetOffset + Vector3.new(0, 10, 0)
		local targetCFrame = CFrame.new(targetPosition, targetPosition + facingDirection)
		
		-- Create tween to move ghostguardiene down
		local moveInfo = TweenInfo.new(
			0.15, -- Duration
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.Out
		)
		
		local moveTween = TweenService:Create(
			ghostguardiene.PrimaryPart,
			moveInfo,
			{CFrame = targetCFrame}
		)
		
		moveTween:Play()
		
		-- Start fade timer: fade out after 1 second of spawning
		task.spawn(function()
			task.wait(1) 
			
			if not ghostguardiene or not ghostguardiene.Parent then return end
			
			local partsToFade = {}
			for _, part in pairs(ghostguardiene:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("Decal") or part:IsA("Texture") then
					table.insert(partsToFade, part)
				end
			end
			
			local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local lastTween
			for _, part in pairs(partsToFade) do
				lastTween = TweenService:Create(part, fadeInfo, {Transparency = 1})
				lastTween:Play()
			end
			
			if lastTween then
				lastTween.Completed:Connect(function()
					ghostguardiene:Destroy()
				end)
			else
				Debris:AddItem(ghostguardiene, 0.5)
			end
		end)
		
		Debris:AddItem(ghostguardiene, 15)
	end
	
	-- Spawn Sigil Immediately
	local dfhFolder = RS.VFX:FindFirstChild("DescentFromHeaven")
	local sigilTemplate = dfhFolder and dfhFolder:FindFirstChild("sigil") -- Lowercase or Capital? User said "sigil"
	if not sigilTemplate then sigilTemplate = dfhFolder and dfhFolder:FindFirstChild("Sigil") end
	
	if sigilTemplate then
		local sigilPart = Instance.new("Part")
		sigilPart.Name = "SigilAnchor"
		sigilPart.Transparency = 1
		sigilPart.CanCollide = false
		sigilPart.Anchored = true
		sigilPart.Position = hitboxPosition + Vector3.new(0, 0.5, 0) -- Slightly above ground
		sigilPart.Parent = workspace
		
		local sigil = sigilTemplate:Clone()
		ApplySunkissedTint(sigil)
		sigil.Parent = sigilPart
		
		-- Enable Particles
		for _, p in ipairs(sigil:GetDescendants()) do
			if p:IsA("ParticleEmitter") then
				p.Enabled = true
				-- p:Emit(1) -- Emit or just enable? "make that sigil enable for 2 seconds" implies enable
			end
		end
		
		-- Cleanup Sigil after 2 seconds
		Debris:AddItem(sigilPart, 3.5) -- Safety cleanup
		task.delay(2, function()
			if sigilPart and sigilPart.Parent then
				-- Fade out? or just destroy? "then have the rest of the vfx start"
				for _, p in ipairs(sigil:GetDescendants()) do
					if p:IsA("ParticleEmitter") then
						p.Enabled = false
					end
				end
			end
		end)
	end
	
	-- Delay the rest of the VFX by 2 seconds
	task.delay(2, function()
		-- Spawn Landing VFX at hitbox position
		local landingPart = dfhFolder and dfhFolder:FindFirstChild("Landing")
		
		if landingPart then
			local landingClone = landingPart:Clone()
			local landingAttachment = landingClone:FindFirstChildOfClass("Attachment")
			
			if landingAttachment then
				local tempPart = Instance.new("Part")
				tempPart.Name = "LandingPart"
				tempPart.Size = Vector3.new(1, 1, 1)
				tempPart.Transparency = 1
				tempPart.CanCollide = false
				tempPart.Anchored = true
				tempPart.Position = hitboxPosition
				tempPart.Parent = workspace
				
				ApplySunkissedTint(landingClone)
				
				landingAttachment.Parent = tempPart
				landingAttachment.Position = Vector3.new(0, 0, 0)
	
				-- Function to spawn landing VFX (sounds and particles)
				local function spawnLandingVFX()
					local slashSound = dfhFolder:FindFirstChild("slash")
					if slashSound then
						task.spawn(function()
							PlaySFX(slashSound, tempPart)
							task.wait(.2)
							
							local slashAfterSound = dfhFolder:FindFirstChild("slashafter")
							if slashAfterSound then
								PlaySFX(slashAfterSound, tempPart)
							end
						end)
					end
					
					task.wait(.15)
					for _, Particles in ipairs(landingAttachment:GetDescendants()) do
						if Particles:IsA("ParticleEmitter") then
							local emitCount = Particles:GetAttribute("EmitCount")
							if emitCount then
								task.wait()
								Particles:Emit(emitCount)
							end
						end
					end
					Debris:AddItem(tempPart, 5)
				end
				
				landingClone:Destroy()
				spawnLandingVFX()
			else
				landingClone:Destroy()
			end
		end
		
		-- Spawn single guardiene facing forward
		local targetCharacter = player.Character or Players.LocalPlayer.Character
		local hrp = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
		local facingDirection = (extraData and extraData.FacingDirection) or (hrp and hrp.CFrame.LookVector) or Vector3.new(0, 0, -1)
		
		createGhostguardiene(
			Vector3.new(0, 0, 0), -- No spawn offset
			Vector3.new(0, 0, 0), -- No target offset
			facingDirection -- Facing direction
		)
	end)
end

function VFXController.PlaySunkissedMelee(targetPlayer, comboPhase)
	local char = targetPlayer.Character
	if not char or not char.PrimaryPart then return end

	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local skVFX = vfxFolder and vfxFolder:FindFirstChild("SunkissedArt")
	local rsSK = ReplicatedStorage:FindFirstChild("SunkissedArt")
	
	local soundName = "SunkissedArt" .. tostring(comboPhase == 0 and 3 or comboPhase)
	local sfx = (rsSK and rsSK:FindFirstChild(soundName)) or ReplicatedStorage:FindFirstChild(soundName)
	if sfx and sfx:IsA("Sound") then
		local s = sfx:Clone()
		s.Volume = s.Volume > 0 and s.Volume or 0.5
		s.Parent = char.PrimaryPart
		s:Play()
		game.Debris:AddItem(s, 10)
	end

	if comboPhase == 1 then
		local firstHit = skVFX and skVFX:FindFirstChild("FirstHit")
		if firstHit then
			local hitClone = firstHit:Clone()
			hitClone.Parent = char.PrimaryPart
			
			local isLowDetail = localData and localData.Settings and localData.Settings.LowDetailMode
			local detailMult = isLowDetail and 0.5 or 1.0
			
			for _, p in ipairs(hitClone:GetChildren()) do
				if p:IsA("ParticleEmitter") then
					local burstAmount = (p:GetAttribute("EmitCount") or p:GetAttribute("Count") or 25)
					p:Emit(math.max(1, math.floor(burstAmount * detailMult)))
				end
			end
			game.Debris:AddItem(hitClone, 3)
		end

	elseif comboPhase == 2 then
		local secondHit = (skVFX and skVFX:FindFirstChild("SecondHit")) or (rsSK and rsSK:FindFirstChild("SecondHit"))
		if secondHit then
			local hitClone = secondHit:Clone()
			hitClone.Parent = char.PrimaryPart
			
			local isLowDetail = localData and localData.Settings and localData.Settings.LowDetailMode
			
			for _, p in ipairs(hitClone:GetChildren()) do
				if p:IsA("ParticleEmitter") then
					if isLowDetail then
						p.Rate = math.max(1, math.floor(p.Rate * 0.5))
					end
					p.Enabled = true
				end
			end
			
			task.delay(0.3, function()
				if hitClone and hitClone.Parent then
					for _, p in ipairs(hitClone:GetChildren()) do
						if p:IsA("ParticleEmitter") then
							p.Enabled = false
						end
					end
				end
			end)
			
			game.Debris:AddItem(hitClone, 4)
		end
	end
end

function VFXController.PlaySunkissedAbility(targetPlayer)
	local char = targetPlayer.Character
	if not char or not char.PrimaryPart then return end
	local root = char.PrimaryPart
	
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local skVFX = vfxFolder and vfxFolder:FindFirstChild("SunkissedArt")
	local sunObj = (skVFX and skVFX:FindFirstChild("Sun")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("Sun"))
	
	local sunClone = nil
	if sunObj then
		sunClone = sunObj:Clone()
		sunClone.Position = Vector3.new(0, 20, 0)
		sunClone.Parent = root
		for _, p in ipairs(sunClone:GetDescendants()) do
			if p:IsA("ParticleEmitter") then p.Enabled = true end
		end
	end
	
	local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
	if not isSfxDisabled then
		local sfx1 = (skVFX and skVFX:FindFirstChild("Ability1")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("Ability1")) or ReplicatedStorage:FindFirstChild("SunkissedArtAbility1")
		if sfx1 and sfx1:IsA("Sound") then
			local s1 = sfx1:Clone()
			s1.Parent = root
			s1:Play()
			game.Debris:AddItem(s1, math.max(6, sfx1.TimeLength + 1))
		end
		
		local sfx3 = (skVFX and skVFX:FindFirstChild("Ability3")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("Ability3")) or ReplicatedStorage:FindFirstChild("SunkissedArtAbility3")
		if sfx3 and sfx3:IsA("Sound") then
			local s3 = sfx3:Clone()
			s3.Parent = root
			s3:Play()
			game.Debris:AddItem(s3, math.max(6, sfx3.TimeLength + 1))
		end
	end
	
	local beamsObj = (skVFX and skVFX:FindFirstChild("beams")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("beams"))
	if beamsObj then
		local beamsClone = beamsObj:Clone()
		beamsClone.Parent = root
		if beamsClone:IsA("Attachment") then beamsClone.Position = Vector3.new(0, -2.8, 0) end
		
		local bList = {}
		for _, b in ipairs(beamsClone:GetDescendants()) do
			if b:IsA("Beam") or b:IsA("ParticleEmitter") or b:IsA("Trail") then
				table.insert(bList, {Obj = b, OrigTrans = b.Transparency})
				local newKeypoints = {}
				for _, kp in ipairs(b.Transparency.Keypoints) do
					table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, 1, kp.Envelope))
				end
				b.Transparency = NumberSequence.new(newKeypoints)
				if b:IsA("ParticleEmitter") or b:IsA("Trail") then b.Enabled = true end
			end
		end
		
		task.spawn(function()
			local RunService = game:GetService("RunService")
			local startTime = os.clock()
			local duration = 3.0
			local fadeInTime = 0.5
			local fadeOutTime = 0.5
			local disabledParticles = false
			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not beamsClone or not beamsClone.Parent then
					if conn then conn:Disconnect() end
					return
				end
				local elapsed = os.clock() - startTime
				if elapsed >= duration then
					beamsClone:Destroy()
					if conn then conn:Disconnect() end
					return
				end
				local alpha = 0
				if elapsed < fadeInTime then
					alpha = 1.0 - (elapsed / fadeInTime)
				elseif elapsed >= duration - fadeOutTime then
					alpha = (elapsed - (duration - fadeOutTime)) / fadeOutTime
					if not disabledParticles then
						disabledParticles = true
						for _, b in ipairs(beamsClone:GetDescendants()) do
							if b:IsA("ParticleEmitter") or b:IsA("Trail") then b.Enabled = false end
						end
					end
				else
					alpha = 0.0
				end
				for _, data in ipairs(bList) do
					local newKeypoints = {}
					for _, kp in ipairs(data.OrigTrans.Keypoints) do
						local newVal = math.clamp(kp.Value + (1 - kp.Value) * alpha, 0, 1)
						local newEnv = kp.Envelope
						if newVal + newEnv > 1.0 then newEnv = 1.0 - newVal end
						if newVal - newEnv < 0.0 then newEnv = newVal end
						table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, newVal, newEnv))
					end
					data.Obj.Transparency = NumberSequence.new(newKeypoints)
				end
			end)
		end)
	end
	
	task.delay(1.0, function()
		if not sunClone then return end
		local pList = {}
		for _, p in ipairs(sunClone:GetDescendants()) do
			if p:IsA("ParticleEmitter") then
				table.insert(pList, {Emitter = p, OrigSize = p.Size, OrigSpeed = p.Speed})
			end
		end
		
		local rightHand = char:FindFirstChild("RightHand")
		if rightHand then
			local attachWorldPos = root.CFrame:PointToWorldSpace(Vector3.new(0, 20, 0))
			local localOffset = rightHand.CFrame:PointToObjectSpace(attachWorldPos)
			sunClone.Parent = rightHand
			sunClone.Position = localOffset
			
			local TweenService = game:GetService("TweenService")
			local tweenDur = 1.4
			local tsInfo = TweenInfo.new(tweenDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(sunClone, tsInfo, {Position = Vector3.new(0, 0, 0)})
			tween:Play()
			
			if #pList > 0 then
				task.spawn(function()
					local RunService = game:GetService("RunService")
					local startTime = os.clock()
					local conn
					conn = RunService.Heartbeat:Connect(function()
						if not sunClone or not sunClone.Parent then
							conn:Disconnect()
							return
						end
						local elapsed = os.clock() - startTime
						if elapsed >= tweenDur then
							elapsed = tweenDur
							conn:Disconnect()
						end
						local alpha = elapsed / tweenDur
						local easedAlpha = 1 - (1 - alpha) * (1 - alpha)
						local scale = 1.0 - (0.666 * easedAlpha)
						for _, data in ipairs(pList) do
							local newKeypoints = {}
							for _, kp in ipairs(data.OrigSize.Keypoints) do
								local newVal = math.max(0, kp.Value * scale)
								local newEnv = math.max(0, kp.Envelope * scale)
								if newEnv > newVal * 2 then newEnv = newVal * 2 end
								table.insert(newKeypoints, NumberSequenceKeypoint.new(kp.Time, newVal, newEnv))
							end
							data.Emitter.Size = NumberSequence.new(newKeypoints)
							data.Emitter.Speed = NumberRange.new(data.OrigSpeed.Min * scale, data.OrigSpeed.Max * scale)
						end
					end)
				end)
			end
		end
	end)
	
	task.delay(2.8, function()
		if sunClone then
			for _, p in ipairs(sunClone:GetDescendants()) do
				if p:IsA("ParticleEmitter") then p.Enabled = false end
			end
			game.Debris:AddItem(sunClone, 4)
		end
		
		local burstObj = skVFX and skVFX:FindFirstChild("Burst")
		if burstObj then
			local burstClone = burstObj:Clone()
			burstClone.Parent = workspace.Terrain
			burstClone.WorldPosition = root.Position - Vector3.new(0, 2.7, 0)
			for _, p in ipairs(burstClone:GetDescendants()) do
				if p:IsA("ParticleEmitter") then p:Emit(p:GetAttribute("EmitCount") or p:GetAttribute("Count") or 40) end
			end
			game.Debris:AddItem(burstClone, 4)
			
			if not isSfxDisabled then
				local sfx2 = (skVFX and skVFX:FindFirstChild("Ability2")) or (ReplicatedStorage:FindFirstChild("SunkissedArt") and ReplicatedStorage.SunkissedArt:FindFirstChild("Ability2")) or ReplicatedStorage:FindFirstChild("SunkissedArtAbility2")
				if sfx2 and sfx2:IsA("Sound") then
					local s2 = sfx2:Clone()
					s2.Parent = burstClone
					s2:Play()
				end
			end
		end
	end)
end

VFXController.ActiveSanctuaryVFX = {}

function VFXController.PlaySanctuary(targetPlayer, customData)
	if not targetPlayer or not customData or not customData.Position then return end
	local position = customData.Position
	
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	if not vfxFolder then return end
	local illusionaryFishFolder = vfxFolder:FindFirstChild("Illusionary Fish")
	if not illusionaryFishFolder then return end
	
	local sanctuaryTemplate = illusionaryFishFolder:FindFirstChild("sanctuary")
	if not sanctuaryTemplate then return end
	
	local sanctuary = sanctuaryTemplate:Clone()
	sanctuary.Anchored = true
	sanctuary.CanCollide = false
	local spawnPos = position + Vector3.new(0, 0.45, 0)
	sanctuary.Position = spawnPos
	sanctuary.Parent = workspace.Terrain
	
	local spsan = illusionaryFishFolder:FindFirstChild("Spsan")
	local spsan2 = illusionaryFishFolder:FindFirstChild("Spsan2")
	if spsan then
		PlaySFX(spsan, sanctuary)
	end
	if spsan2 then
		local s2 = PlaySFX(spsan2, sanctuary, 6)
		if s2 then
			task.delay(2.5, function()
				if s2 and s2.Parent then
					local fadeTween = TweenService:Create(s2, TweenInfo.new(2.5, Enum.EasingStyle.Linear), {Volume = 0})
					fadeTween:Play()
				end
			end)
		end
	end
	
	-- Enable all particles and store original sizes
	for _, child in ipairs(sanctuary:GetDescendants()) do
		if child:IsA("ParticleEmitter") then
			child.Enabled = true
		end
	end
	
	local originalSize = sanctuary.Size
	local originalBeams = {}
	local floatingParts = {}
	
	local illudedAtt = sanctuary:FindFirstChild("Illuded", true)
	local illudedFloatData = nil
	if illudedAtt then
		illudedFloatData = {
			OriginalCFrame = illudedAtt.CFrame,
			OriginalPosition = illudedAtt.Position,
			RandSpeed = math.random(8, 15) / 10,
			RandOffset = math.random() * 2 * math.pi,
			RotX = 0,
			RotY = math.rad(30),
			RotZ = 0,
		}
	end
	
	local posOffset = spawnPos - sanctuaryTemplate.Position
	for _, child in ipairs(sanctuary:GetChildren()) do
		if child:IsA("BasePart") then
			child.Position = child.Position + posOffset
			child.Anchored = true
			child.CanCollide = false
			table.insert(floatingParts, {
				Part = child,
				OriginalCFrame = child.CFrame,
				OriginalSize = child.Size,
				RelativePos = child.Position - spawnPos,
				IsModel = false,
				RandSpeed = math.random(8, 15) / 10,
				RandOffset = math.random() * 2 * math.pi,
				RotX = math.random(-8, 8) * 0.1,
				RotY = math.random(-8, 8) * 0.1,
				RotZ = math.random(-8, 8) * 0.1,
				RiseDelay = math.random() * 0.5,
				RiseDuration = 1.0 + math.random() * 1.5
			})
		elseif child:IsA("Model") then
			local pivot = child:GetPivot()
			child:PivotTo(pivot + posOffset)
			for _, p in ipairs(child:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Anchored = true
					p.CanCollide = false
				end
			end
			table.insert(floatingParts, {
				Part = child,
				OriginalCFrame = child:GetPivot(),
				OriginalSize = child:GetScale(),
				RelativePos = child:GetPivot().Position - spawnPos,
				IsModel = true,
				RandSpeed = math.random(8, 15) / 10,
				RandOffset = math.random() * 2 * math.pi,
				RotX = math.random(-8, 8) * 0.1,
				RotY = math.random(-8, 8) * 0.1,
				RotZ = math.random(-8, 8) * 0.1,
				RiseDelay = math.random() * 0.5,
				RiseDuration = 1.0 + math.random() * 1.5
			})
		end
	end
	
	
	for _, child in ipairs(sanctuary:GetDescendants()) do
		if child:IsA("Beam") then
			originalBeams[child] = {
				Width0 = child.Width0,
				Width1 = child.Width1
			}
		elseif child:IsA("Attachment") then
			originalBeams[child] = {
				Position = child.Position
			}
		end
	end
	
	-- Set to small size
	local startScale = 0.05
	sanctuary.Size = originalSize * startScale
	for obj, data in pairs(originalBeams) do
		if obj:IsA("Beam") then
			obj.Width0 = data.Width0 * startScale
			obj.Width1 = data.Width1 * startScale
		elseif obj:IsA("Attachment") then
			obj.Position = data.Position * startScale
		end
	end
	for _, pData in ipairs(floatingParts) do
		if pData.IsModel then
			pData.Part:ScaleTo(pData.OriginalSize * startScale)
		else
			pData.Part.Size = pData.OriginalSize * startScale
		end
	end
	
	-- Tween up to original size
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	
	local scaleValue = Instance.new("NumberValue")
	scaleValue.Value = startScale
	
	local state = {IsOrbiting = false}
	
	local conn = scaleValue.Changed:Connect(function(scale)
		sanctuary.Size = originalSize * scale
		for obj, data in pairs(originalBeams) do
			if obj:IsA("Beam") then
				obj.Width0 = data.Width0 * scale
				obj.Width1 = data.Width1 * scale
			elseif obj:IsA("Attachment") then
				obj.Position = data.Position * scale
			end
		end
		
		if not state.IsOrbiting then
			for _, pData in ipairs(floatingParts) do
				if pData.Part.Parent then
					if pData.IsModel then
						pData.Part:ScaleTo(math.max(0.001, pData.OriginalSize * scale))
					else
						pData.Part.Size = pData.OriginalSize * scale
					end
				end
			end
		end
	end)
	
	local t = 0
	local floatConn
	floatConn = RunService.RenderStepped:Connect(function(dt)
		t = t + dt
		local currentScale = scaleValue.Value
		
		if illudedAtt and illudedFloatData then
			local floatOffset = math.sin((t * illudedFloatData.RandSpeed) + illudedFloatData.RandOffset) * 0.8
			local currentRot = CFrame.Angles(t * illudedFloatData.RotX, t * illudedFloatData.RotY, t * illudedFloatData.RotZ)
			
			local scaledPos = illudedFloatData.OriginalPosition * currentScale
			illudedAtt.CFrame = CFrame.new(scaledPos + Vector3.new(0, floatOffset, 0)) * currentRot * illudedFloatData.OriginalCFrame.Rotation
		end
		
		for _, pData in ipairs(floatingParts) do
			if pData.Part.Parent then
				local riseTime = math.max(0, t - pData.RiseDelay)
				local rise = math.min(1, riseTime / pData.RiseDuration)
				rise = 1 - math.pow(1 - rise, 3) -- Smooth cubic out
				
				local floatOffset = math.sin((t * pData.RandSpeed) + pData.RandOffset) * 0.8 * rise
				local yOffset = -5 * (1 - rise)
				
				local currentRot = CFrame.Angles(t * pData.RotX, t * pData.RotY, t * pData.RotZ)
				local scaledPos = spawnPos + (pData.RelativePos * currentScale)
				
				local newCFrame = CFrame.new(scaledPos + Vector3.new(0, yOffset + floatOffset, 0)) * currentRot * pData.OriginalCFrame.Rotation
				
				if pData.IsModel then
					pData.Part:PivotTo(newCFrame)
				else
					pData.Part.CFrame = newCFrame
				end
			end
		end
	end)
	
	local tweenUp = TweenService:Create(scaleValue, tweenInfo, {Value = 1.5})
	tweenUp:Play()
	
	-- 10 seconds later, tween down and destroy
	local fadeThread = task.delay(10, function()
		if floatConn then floatConn:Disconnect() end
		
		for _, pData in ipairs(floatingParts) do
			local part = pData.Part
			if part and part.Parent then
				part.Parent = workspace.Terrain
				
				local fallOffset = Vector3.new(0, -8, 0)
				local randomRot = CFrame.Angles(math.random(-3,3), math.random(-3,3), math.random(-3,3))
				
				if pData.IsModel then
					for _, p in ipairs(part:GetDescendants()) do
						if p:IsA("BasePart") then
							p.Anchored = true
							p.CanCollide = false
							TweenService:Create(p, TweenInfo.new(2.0, Enum.EasingStyle.Linear), {Transparency = 1}):Play()
						end
					end
					
					local cv = Instance.new("CFrameValue")
					cv.Value = part:GetPivot()
					cv.Changed:Connect(function(val)
						if part and part.Parent then
							part:PivotTo(val)
						end
					end)
					
					local fadeTween = TweenService:Create(cv, TweenInfo.new(2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Value = (cv.Value * randomRot) + fallOffset
					})
					fadeTween:Play()
					Debris:AddItem(cv, 2.1)
				else
					part.Anchored = true
					part.CanCollide = false
					
					local fadeTween = TweenService:Create(part, TweenInfo.new(2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						CFrame = (part.CFrame * randomRot) + fallOffset,
						Transparency = 1
					})
					fadeTween:Play()
				end
				
				Debris:AddItem(part, 2.1)
			end
		end
		
		for _, child in ipairs(sanctuary:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = false
			end
		end
		
		local tweenDownInfo = TweenInfo.new(2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tweenDown = TweenService:Create(scaleValue, tweenDownInfo, {Value = 0})
		tweenDown:Play()
		tweenDown.Completed:Wait()
		if conn then conn:Disconnect() end
		sanctuary:Destroy()
		scaleValue:Destroy()
		
		VFXController.ActiveSanctuaryVFX[targetPlayer.UserId] = nil
	end)
	
	VFXController.ActiveSanctuaryVFX[targetPlayer.UserId] = {
		Model = sanctuary,
		FloatingParts = floatingParts,
		FloatConn = floatConn,
		ScaleValue = scaleValue,
		FadeThread = fadeThread,
		State = state
	}
end

function VFXController.PlaySanctuaryBullets(targetPlayer, customData)
	if not customData or not customData.Position then return end
	local position = customData.Position
	local count = customData.ExplosionCount or 40
	local delay = customData.ExplosionDelay or 0.05
	local rStep = customData.RadiusStep or 1.0
	local angleStep = customData.AngleStep or 36
	
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local illusionaryFishFolder = vfxFolder and vfxFolder:FindFirstChild("Illusionary Fish")
	local bulletTemplate = illusionaryFishFolder and illusionaryFishFolder:FindFirstChild("Bullet")
	local spirallusionFolder = illusionaryFishFolder and illusionaryFishFolder:FindFirstChild("spirallusion")
	local spawnAttTemplate = spirallusionFolder and spirallusionFolder:FindFirstChild("spawn")
	local expl1 = illusionaryFishFolder and illusionaryFishFolder:FindFirstChild("Expl1")
	local expl2 = illusionaryFishFolder and illusionaryFishFolder:FindFirstChild("Expl2")
	
	if not bulletTemplate or not spawnAttTemplate then return end
	
	-- Find the Illuded attachment from the active sanctuary
	local activeSanc = VFXController.ActiveSanctuaryVFX[targetPlayer.UserId]
	local startPos = position + Vector3.new(0, 15, 0) -- default fallback
	if activeSanc and activeSanc.Model then
		local illudedAtt = activeSanc.Model:FindFirstChild("Illuded", true)
		if illudedAtt then
			startPos = illudedAtt.WorldPosition
		end
	end
	
	-- Play Spirallusion Spawn SFX at startPos
	local spawnSfx = illusionaryFishFolder:FindFirstChild("Spawn")
	if spawnSfx then
		local anchor = Instance.new("Part")
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.Position = startPos
		anchor.Parent = workspace.Terrain
		Debris:AddItem(anchor, 5)
		PlaySFX(spawnSfx, anchor)
	end
	
	for i = 1, count do
		task.delay(i * delay, function()
			local radius = i * rStep
			local angle = math.rad(i * angleStep)
			local offset = Vector3.new(math.cos(angle) * radius, 1.5, math.sin(angle) * radius)
			local endPos = position + offset
			
			local bulletDuration = 0.8 -- fixed duration to match server delay
			local bullet = bulletTemplate:Clone()
			
			if bullet:IsA("Attachment") then
				local carrier = Instance.new("Part")
				carrier.Name = "BulletCarrier"
				carrier.Transparency = 1
				carrier.Size = Vector3.new(0.5,0.5,0.5)
				carrier.CanCollide = false
				carrier.Anchored = true
				carrier.Position = startPos
				carrier.Parent = workspace.Terrain
				bullet.Parent = carrier
				bullet = carrier
			else
				bullet.Parent = workspace.Terrain
				bullet.CFrame = CFrame.new(startPos)
				bullet.Anchored = true
				bullet.CanCollide = false
			end
			
			local startTime = os.clock()
			local midPoint = (startPos + endPos) / 2
			-- Rainmaker uses 50 height, user wants curve like rainmaker but slower. 
			local height = math.max((startPos - endPos).Magnitude * 0.5, 20) 
			local controlPoint = midPoint + Vector3.new(0, height, 0)
			
			local forward = (endPos - startPos).Unit
			local up = Vector3.new(0, 1, 0)
			local right = forward:Cross(up)
			if right.Magnitude < 0.001 then right = Vector3.new(1, 0, 0) end
			
			local spreadRotation = CFrame.fromAxisAngle(forward, math.random() * math.pi * 2)
			local spreadRight = spreadRotation:VectorToWorldSpace(right)
			
			local connection
			connection = RunService.RenderStepped:Connect(function()
				local t = math.clamp((os.clock() - startTime) / bulletDuration, 0, 1)
				
				local l1 = startPos:Lerp(controlPoint, t)
				local l2 = controlPoint:Lerp(endPos, t)
				local currentPos = l1:Lerp(l2, t)
				
				local amp = math.sin(t * math.pi) * 10
				local wobbleOffset = spreadRight * math.sin(t * math.pi * 4) * amp
				
				local finalPos = currentPos + wobbleOffset
				local tangent = (2 * (1-t) * (controlPoint - startPos) + 2 * t * (endPos - controlPoint)).Unit
				
				if tangent.Magnitude > 0 then
					bullet.CFrame = CFrame.lookAt(finalPos, finalPos + tangent) * CFrame.Angles(math.rad(90), 0, 0)
				else
					bullet.CFrame = CFrame.new(finalPos)
				end
				
				if t >= 1 then
					connection:Disconnect()
					bullet:Destroy()
					
					-- Explosion
					local anchor = Instance.new("Part")
					anchor.Size = Vector3.new(0.1, 0.1, 0.1)
					anchor.Transparency = 1
					anchor.Anchored = true
					anchor.CanCollide = false
					anchor.Position = endPos
					anchor.Parent = workspace.Terrain
					Debris:AddItem(anchor, 2)
					
					local newAtt = spawnAttTemplate:Clone()
					newAtt.Parent = anchor
					for _, child in ipairs(newAtt:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							local emitCount = child:GetAttribute("emitcount") or 10
							child:Emit(emitCount)
						end
					end
					
					if expl1 then PlaySFX(expl1, anchor) end
					if expl2 then PlaySFX(expl2, anchor) end
				end
			end)
		end)
	end
end

function VFXController.PlayMobCollectSparkles(startPos, numSparkles)
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	local sparkleTemplate = vfxFolder and vfxFolder:FindFirstChild("CollectSparkle")
	if not sparkleTemplate then
		warn("VFXController: CollectSparkle template missing from ReplicatedStorage.VFX!")
		return
	end
	
	numSparkles = numSparkles or 5
	for i = 1, numSparkles do
		task.spawn(function()
			-- Staggered delay for organic visual spread
			task.wait((i - 1) * 0.05 + math.random() * 0.05)
			
			local currentChar = Players.LocalPlayer.Character
			local currentHrp = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
			if not currentHrp then return end
			
			local sparkle = sparkleTemplate:Clone()
			sparkle.CFrame = CFrame.new(startPos)
			sparkle.Anchored = true
			sparkle.CanCollide = false
			sparkle.Parent = workspace
			
			-- Emitters and Trails cache
			local originalSizes = {}
			local originalTrailWidths = {}
			
			for _, child in ipairs(sparkle:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					originalSizes[child] = child.Size
					child.Enabled = true
				elseif child:IsA("Trail") then
					originalTrailWidths[child] = child.WidthScale
					child.Enabled = true
				end
			end
			
			local duration = 0.8 + math.random() * 0.4
			local startTime = os.clock()
			
			-- Calculate random sideways & height offsets for the parabola/curve
			local angle = math.random() * math.pi * 2
			local sideDist = math.random(6, 18)
			local controlOffset = Vector3.new(
				math.cos(angle) * sideDist,
				math.random(12, 24),
				math.sin(angle) * sideDist
			)
			
			local connection
			connection = RunService.RenderStepped:Connect(function()
				local activeChar = Players.LocalPlayer.Character
				local activeHrp = activeChar and activeChar:FindFirstChild("HumanoidRootPart")
				if not activeHrp then
					connection:Disconnect()
					sparkle:Destroy()
					return
				end
				
				local elapsed = os.clock() - startTime
				local t = math.clamp(elapsed / duration, 0, 1)
				
				-- Quadratic InOut Easing:
				local easedT
				if t < 0.5 then
					easedT = 2 * t * t
				else
					easedT = -1 + (4 - 2 * t) * t
				end
				
				-- Dynamic target update to track moving player
				local playerPos = activeHrp.Position
				local controlPoint = startPos:Lerp(playerPos, 0.5) + controlOffset
				
				-- 3-Point Bezier Curve math
				local p1 = startPos:Lerp(controlPoint, easedT)
				local p2 = controlPoint:Lerp(playerPos, easedT)
				local finalPos = p1:Lerp(p2, easedT)
				
				sparkle.CFrame = CFrame.new(finalPos)
				
				-- Dynamically shrink emitters and trails
				local sparkleScaleFactor = (1 - t) * (1 + 4 * t)
				local shrinkFactor = 1 - t
				for emitter, origSize in pairs(originalSizes) do
					local kps = {}
					for _, kp in ipairs(origSize.Keypoints) do
						table.insert(kps, NumberSequenceKeypoint.new(kp.Time, math.max(0, kp.Value * sparkleScaleFactor), math.max(0, kp.Envelope * sparkleScaleFactor)))
					end
					emitter.Size = NumberSequence.new(kps)
				end
				
				for trail, origWidth in pairs(originalTrailWidths) do
					local kps = {}
					for _, kp in ipairs(origWidth.Keypoints) do
						table.insert(kps, NumberSequenceKeypoint.new(kp.Time, math.max(0, kp.Value * shrinkFactor)))
					end
					trail.WidthScale = NumberSequence.new(kps)
				end
				
				if t >= 1 then
					connection:Disconnect()
					sparkle:Destroy()
				end
			end)
		end)
	end
end

function VFXController.Start()
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		localData = data
	end)
	
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local VFXReplication = Remotes:WaitForChild("VFXReplication", 10)
	
	if VFXReplication then
		VFXReplication.OnClientEvent:Connect(function(vfxName, targetPlayer, targetIndex, customData, extraData, extraData2)
			if vfxName == "MobCollectSparkle" then
				VFXController.PlayMobCollectSparkles(customData, extraData)
				return
			end
			if vfxName == "Sanctuary" then
				if customData and customData.Position then
					VFXController.PlaySanctuary(targetPlayer, customData)
				end
				return
			end
			if vfxName == "SanctuaryBullets" then
				VFXController.PlaySanctuaryBullets(targetPlayer, customData)
				return
			end
			
			if vfxName == "ChromaticBlast" then
				if extraData and extraData.Position then
					local playData = {Color = customData, Position = extraData.Position}
					-- Merge additional properties (ForceOverride, etc)
					if type(extraData) == "table" then
						for k, v in pairs(extraData) do
							if playData[k] == nil then playData[k] = v end
						end
					end
					VFXController.Play("ChromaticBlast", nil, playData)
					return
				end

				local model = nil
				if targetPlayer == Players.LocalPlayer then
					model = FishController.GetFish(targetIndex)
				else
					local fishName = "Fish_" .. targetPlayer.UserId .. "_" .. tostring(targetIndex)
					model = workspace:FindFirstChild(fishName)
				end
				
				if model then
					VFXController.Play("ChromaticBlast", model, {Color = customData})
				end
				return
			end

			if vfxName == "RainmakerState" then
				if targetPlayer ~= Players.LocalPlayer then
					VFXController.HandleRainmakerState(targetPlayer, customData) -- customData is State ("Charge", "Fire", "Stop")
				end
				return
			end
			
			if vfxName == "RainmakerAbility" then
				VFXController.PlayRainmakerAbility(targetPlayer)
				return
			end
		
			if vfxName == "TropicalGust" then
				VFXController.Play("TropicalGust", nil, {Position = customData, Duration = extraData})
				return
			end

			if vfxName == "DescentFromHeaven" then
				VFXController.PlayDescentFromHeaven(targetPlayer, customData, extraData)
				return
			end
			
			if vfxName == "GuardianVFX" then
				VFXController.PlayGuardianVFX(targetPlayer, customData, extraData) -- customData: hrp, extraData: movetype
				return
			end

			if vfxName == "Synesthesia" then
				VFXController.Play("Synesthesia", nil, customData)
				return
			end
			
			if vfxName == "Black Hole" then
				VFXController.Play("Black Hole", nil, {Position = customData.Position, Duration = customData.Duration, Player = targetPlayer})
				return
			end
			
			if vfxName == "BlackHoleCollect" then
				VFXController.Play("BlackHoleCollect", nil, {Position = customData, Player = targetPlayer})
				return
			end
			
			local isForeign = (targetPlayer ~= Players.LocalPlayer)
			
			if vfxName == "Wave" then
				if not isForeign then return end -- Local handles own prediction
				VFXController.Play("Wave", nil, customData, true)
				return
			end
			
			if vfxName == "PinnedDown" then
				VFXController.PlayPinnedDown(customData.Pos, customData.Dur, customData.Height, isForeign)
				return
			end
			
			if vfxName == "RabbitEnter" or vfxName == "RabbitCollect" then
				-- Rabbit sounds generally don't need greying as they are sounds? 
				-- Or user wants particles greyed? Rabbit has no particles implemented yet, just Sound.
				VFXController.PlayRabbitSound(vfxName, customData)
				return
			end

			if vfxName == "RainmakerBullet" then
				if customData and extraData then
					VFXController.PlayRainmakerBullet(customData, extraData, extraData2)
				end
				return
			end
			
			-- Logic for Local Player's fish (Since they are local models)
			if targetPlayer == Players.LocalPlayer then
				local model = FishController.GetFish(targetIndex)
				if model then
					VFXController.Play(vfxName, model, customData, false)
				end
			else
				-- Foreign Player Logic
				if vfxName == "SunkissedMelee" then
					VFXController.PlaySunkissedMelee(targetPlayer, customData)
					return
				end
				if vfxName == "SunkissedAbility" then
					VFXController.PlaySunkissedAbility(targetPlayer)
					return
				end
				-- Future: If fish are replicated...
			end
		end)
	else
		warn("VFXController: VFXReplication remote missing!")
	end
	
	-- Observer for Algae Infection (Client Side Optimization)
	local CollectionService = game:GetService("CollectionService")
	local activeInfectionVFX = {} -- [Part] = {Particles...}
	
	local function onAlgaePartAdded(part)
		-- Check initial state
		if part:GetAttribute("InfectionActive") then
			-- (Duplicate logic handling below)
		end
		
		part:GetAttributeChangedSignal("InfectionActive"):Connect(function()
			if part:GetAttribute("InfectionActive") then
				-- Enable VFX
				if activeInfectionVFX[part] then return end -- Already active
				
				local vfxFolder = ReplicatedStorage:WaitForChild("VFX", 5)
				local folder = vfxFolder and vfxFolder:FindFirstChild("Infect")
				
				if folder then
					local particles = {}
					for _, child in ipairs(folder:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							local clone = child:Clone()
							clone.Parent = part
							clone.Enabled = true
							table.insert(particles, clone)
						end
					end
					activeInfectionVFX[part] = particles
				end
			else
				-- Disable VFX
				local list = activeInfectionVFX[part]
				if list then
					for _, p in ipairs(list) do
						p.Enabled = false
						Debris:AddItem(p, 2)
					end
					activeInfectionVFX[part] = nil
				end
			end
		end)
	end
	
	CollectionService:GetInstanceAddedSignal("AlgaePart"):Connect(onAlgaePartAdded)
	for _, p in ipairs(CollectionService:GetTagged("AlgaePart")) do
		onAlgaePartAdded(p)
	end
end

local function ApplyOverride(root, data)
	if not root or not data or not data.ForceOverride then return end
	
	local color = data.Color or Color3.new(1,1,1)
	local transp = data.Transparency or 0.5
	local colorSeq = ColorSequence.new(color)
	local transpSeq = NumberSequence.new(transp)
	
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Color = colorSeq
			d.Transparency = transpSeq
		elseif d:IsA("BasePart") then
			d.Color = color
			d.Transparency = transp
		end
	end
end

function VFXController.Play(vfxName, target, data, isForeign)
	if vfxName == "SharkScythe" then
		-- Debug
		-- print("VFXController: SharkScythe triggered on", target)
		
		-- Target is expected to be Character or Model with PrimaryPart
		local root = target.PrimaryPart or (target:IsA("Model") and target.PrimaryPart) or target
		if not root then 
			warn("VFXController: SharkScythe target has no root")
			return 
		end
		
		local VFXFolder = ReplicatedStorage:WaitForChild("VFX", 5)
		local SharkFolder = VFXFolder and VFXFolder:WaitForChild("SharkScythe", 2)
		
		if SharkFolder then
			-- 1. SFX
			local sfx = SharkFolder:FindFirstChild("SwingSFX")
			PlaySFX(sfx, root, 2)
			
			-- 2. VFX Attachment
			local attTemplate = SharkFolder:FindFirstChild("Attachment")
			if attTemplate then
				local att = attTemplate:Clone()
				att.Parent = root
				
				for _, child in ipairs(att:GetDescendants()) do
					if child:IsA("ParticleEmitter") then
						local count = child:GetAttribute("EmitCount") or 1
						child:Emit(count)
					end
				end
				
				Debris:AddItem(att, 2)
			else
				warn("VFXController: Attachment not found in RS.VFX.SharkScythe")
			end
		end

	elseif vfxName == "Dive" then
		local folder = ReplicatedStorage:WaitForChild("VFX", 5)
		local diveFolder = folder and folder:WaitForChild("Dive", 5)
		
		-- Play Sound
		if diveFolder then
			local sound = diveFolder:FindFirstChild("DiveSFX")
			local root = target.PrimaryPart or target:FindFirstChild("Main") or target:FindFirstChildWhichIsA("BasePart")
			if root then
				PlaySFX(sound, root)
			end
		end
		
		local template = diveFolder and diveFolder:WaitForChild("DiveVFX", 5)
		local attachmentTemplate = template and template:WaitForChild("Attachment", 5)
		
		if attachmentTemplate then
			-- Clone Attachment to Target (PrimaryPart or Main)
			local root = target.PrimaryPart or target:FindFirstChild("Main") or target:FindFirstChildWhichIsA("BasePart")
			if not root then return end
			
			local vfx = attachmentTemplate:Clone()
			vfx.Parent = root
			
			-- Emit
			for _, child in ipairs(vfx:GetChildren()) do
				if child:IsA("ParticleEmitter") then
					local count = child:GetAttribute("EmitCount") or 1
					child:Emit(count)
				end
			end
			
			ApplyOverride(vfx, data)
			
			-- Cleanup
			Debris:AddItem(vfx, 3) 
		else
			warn("VFXController: DiveVFX Attachment not found")
		end

	elseif vfxName == "Synesthesia" then
		local position = data and data.Position
		if not position then return end
		
		local folder = ReplicatedStorage:FindFirstChild("VFX")
		local synFolder = folder and folder:FindFirstChild("Synesthesia")
		
		if synFolder then
			local root = Instance.new("Part")
			root.Name = "SynesthesiaVFX"
			root.Anchored = true
			root.CanCollide = false
			root.Transparency = 1
			root.Size = Vector3.new(1,1,1)
			root.Position = position
			root.Parent = workspace
			
			-- SFX2 (Start sound)
			local sfx2 = synFolder:FindFirstChild("SFX2")
			PlaySFX(sfx2, root)
			
			-- Visual Particles
			local endHit = synFolder:FindFirstChild("EndHit")
			local attTemplate = endHit and endHit:FindFirstChild("Attachment")
			
			if attTemplate then
				local att = attTemplate:Clone()
				att.Parent = root
				
				local emitters = {}
				for _, child in ipairs(att:GetDescendants()) do
					if child:IsA("ParticleEmitter") then
						table.insert(emitters, child)
						child.Enabled = true -- Start emitting (Lead-in)
					end
				end
				
				-- Timing Logic
				task.delay(2, function()
					if not root or not root.Parent then return end
					
					-- SFX (Emission sound)
					local sfx = synFolder:FindFirstChild("SFX")
					PlaySFX(sfx, root)
					
					for _, emitter in ipairs(emitters) do
						if emitter.Parent then
							local count = emitter:GetAttribute("EmitCount") or 40
							emitter:Emit(count) -- Final Burst
							emitter.Enabled = false -- Disable immediately after burst
						end
					end
				end)
			end
			
			Debris:AddItem(root, 7)
		end
		
	elseif vfxName == "Black Hole" then
		local pos = data.Position
		local duration = data.Duration or 10
		if not pos then return end
		
		local targetHeight = 18
		local spawnPos = pos -- Start at floor
		
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		local bhFolder = vfxFolder and vfxFolder:FindFirstChild("BlackHole")
		local spherePrefab = bhFolder and bhFolder:FindFirstChild("Sphere")
		
		if spherePrefab then
			local sphere = spherePrefab:Clone()
			local owner = data.Player
			if owner then
				activeBlackHoles[owner] = sphere
			end
			sphere.Position = spawnPos
			sphere.Transparency = 1
			sphere.Anchored = true
			sphere.CanCollide = false
			sphere.Parent = workspace
			
			-- Prepare Beams and Particles
			local beams = {}
			local particles = {}
			for _, d in ipairs(sphere:GetDescendants()) do
				if d:IsA("Beam") then
					d.Enabled = true
					local origTrans = d.Transparency
					d.Transparency = NumberSequence.new(1)
					beams[d] = origTrans
				elseif d:IsA("ParticleEmitter") then
					d.Enabled = false
					particles[d] = true
				end
			end
			
			-- Fade In
			task.spawn(function()
				local fadeTime = 1.5
				local start = os.clock()
				while os.clock() - start < fadeTime do
					local alpha = math.min((os.clock() - start) / fadeTime, 1)
					sphere.Transparency = 1 - alpha
					
					for beam, orig in pairs(beams) do
						local kps = {}
						for _, kp in ipairs(orig.Keypoints) do
							table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value + (1 - kp.Value) * (1 - alpha)))
						end
						beam.Transparency = NumberSequence.new(kps)
					end
					
					if alpha >= 1 then break end
					RunService.RenderStepped:Wait()
				end
				sphere.Transparency = 0
				for p, _ in pairs(particles) do p.Enabled = true end
			end)
			
			-- Motion & Rotation logic
			local startTime = os.clock()
			local rotationId = nextUpdaterId
			nextUpdaterId += 1
			ActiveUpdaters[rotationId] = function(dt)
				if not sphere or not sphere.Parent then
					ActiveUpdaters[rotationId] = nil
					return
				end
				local elapsed = os.clock() - startTime
				
				-- 1. Tween Upwards (Smooth start)
				local upAlpha = math.min(elapsed / 3, 1) -- Takes 3s to reach full height
				local upProgress = 1 - math.pow(1 - upAlpha, 3) -- Ease Out Cubic
				local currentHeight = upProgress * targetHeight
				
				-- 2. Wandering (Sine waves for smooth drifting)
				local driftX = math.sin(elapsed * 0.8) * 6
				local driftZ = math.cos(elapsed * 0.7) * 6
				local driftY = math.sin(elapsed * 1.2) * 2
				
				local wanderOffset = Vector3.new(driftX, driftY, driftZ)
				local baseCenter = pos + Vector3.new(0, currentHeight, 0)
				
				-- 3. Rotation (ONLY Y axis)
				local rotation = CFrame.Angles(0, elapsed * 2, 0)
				
				sphere.CFrame = CFrame.new(baseCenter + wanderOffset) * rotation
			end
			
			-- Cleanup with Fade Out
			task.delay(duration, function()
				ActiveUpdaters[rotationId] = nil
				
				-- Disable particles immediately so they stop emitting during the fade
				for p, _ in pairs(particles) do p.Enabled = false end
				
				local start = os.clock()
				local fadeOutTime = 1.2
				while os.clock() - start < fadeOutTime do
					local elapsed = os.clock() - start
					local alpha = math.min(elapsed / fadeOutTime, 1)
					
					-- Fade sphere (1.2s total)
					sphere.Transparency = alpha
					
					-- Fade beams faster (gone by 0.7s)
					local beamAlpha = math.min(elapsed / 0.7, 1)
					for beam, orig in pairs(beams) do
						local kps = {}
						for _, kp in ipairs(orig.Keypoints) do
							table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value + (1 - kp.Value) * beamAlpha))
						end
						beam.Transparency = NumberSequence.new(kps)
					end
					
					if alpha >= 1 then break end
					RunService.RenderStepped:Wait()
				end
				local owner = data.Player
				if owner and activeBlackHoles[owner] == sphere then
					activeBlackHoles[owner] = nil
				end
				sphere:Destroy()
			end)
		end

	elseif vfxName == "TropicalGust" then
		local folder = ReplicatedStorage:WaitForChild("VFX", 5)
		local gustFolder = folder and folder:WaitForChild("TropicalGust", 5)
		
		if gustFolder then
			local sfx = gustFolder:FindFirstChild("GustSFX")
			if sfx and data.Position then
				local part = Instance.new("Part")
				part.Name = "GustSFXLocation"
				part.Transparency = 1
				part.CanCollide = false
				part.Anchored = true
				part.Position = data.Position
				part.Parent = workspace
				
				local sound = sfx:Clone()
				sound.Parent = part
				-- Random Pitch for variety
				sound.PlaybackSpeed = 0.9 + math.random() * 0.2
				
				local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
				if not isSfxDisabled then
					sound:Play()
				end
				
				Debris:AddItem(part, sound.TimeLength + 1)
			end
		end
		
	elseif vfxName == "ChromaticBlast" then
		local folder = ReplicatedStorage:WaitForChild("VFX", 5)
		local cbFolder = folder and folder:FindFirstChild("ChromaticBlast")
		local attachmentTemplate = cbFolder and cbFolder:FindFirstChild("Attachment")
		
		if attachmentTemplate then
			local root = nil
			local tempPart = nil
			
			if data and data.Position then
				-- Temporary anchor for position
				tempPart = Instance.new("Part")
				tempPart.Transparency = 1
				tempPart.Anchored = true
				tempPart.CanCollide = false
				tempPart.Position = data.Position
				tempPart.Parent = workspace
				root = tempPart
				Debris:AddItem(tempPart, 3) 
			elseif target then
				root = target.PrimaryPart or target:FindFirstChild("Main") or target:FindFirstChildWhichIsA("BasePart")
			end
			
			if not root then return end
			
			local vfx = attachmentTemplate:Clone()
			vfx.Parent = root
			
			local color = (data and data.Color) or Color3.new(1,1,1)
			if typeof(color) ~= "Color3" then
				-- Fallback if data.Color is invalid type (e.g. table from some serialization)
				color = Color3.new(1, 1, 1) 
			end
			
			-- Emit particles with the matching color
			for _, child in ipairs(vfx:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child.Color = ColorSequence.new(color)
					local count = child:GetAttribute("EmitCount") or 40
					child:Emit(count)
				elseif child:IsA("Beam") or child:IsA("Trail") then
					child.Color = ColorSequence.new(color)
				end
			end
			
			ApplyOverride(vfx, data)
			
			Debris:AddItem(vfx, 3) 
		end
		

		
		-- Redundant Bruh3 logic removed (Moved to MusicController)
		
	elseif vfxName == "BlackHoleCollect" then
		local pos = data.Position
		if not pos then return end
		
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		local bhFolder = vfxFolder and vfxFolder:FindFirstChild("BlackHole")
		local sfx = bhFolder and bhFolder:FindFirstChild("SFX")
		
		-- Play Sound
		if sfx then
			local root = Instance.new("Part")
			root.Name = "BlackHoleCollectSFX"
			root.Transparency = 1
			root.Anchored = true
			root.CanCollide = false
			root.Position = pos
			root.Parent = workspace
			
			PlaySFX(sfx, root)
			Debris:AddItem(root, sfx.TimeLength + 0.1)
		end
		
		-- LEACH BEAM EFFECT
		local owner = data.Player
		local blackHole = owner and activeBlackHoles[owner]
		if blackHole and blackHole.Parent then
			local bhPos = blackHole.Position
			
			-- Create Temporary Attachments
			local attTop = Instance.new("Attachment")
			attTop.Name = "BlackHoleUpperAtt"
			attTop.Parent = blackHole
			
			local tempFloorPart = Instance.new("Part")
			tempFloorPart.Transparency = 1
			tempFloorPart.Anchored = true
			tempFloorPart.CanCollide = false
			tempFloorPart.Position = pos
			tempFloorPart.Parent = workspace
			
			local attBottom = Instance.new("Attachment")
			attBottom.Name = "BlackHoleLowerAtt"
			attBottom.Parent = tempFloorPart
			
			-- Get Beam Template (Use ConversionBeam as base)
			local cbFolder = vfxFolder:FindFirstChild("ConversionBeam")
			local template = cbFolder and cbFolder:FindFirstChildWhichIsA("Beam")
			
			if template then
				local beam = template:Clone()
				beam.Attachment0 = attTop
				beam.Attachment1 = attBottom
				beam.Color = ColorSequence.new(Color3.fromRGB(120, 0, 200)) -- Dark Purple
				beam.Width0 = 4.5
				beam.Width1 = 0
				beam.Transparency = NumberSequence.new(0)
				beam.Enabled = true
				beam.Parent = tempFloorPart
				
				-- Fade and cleanup
				task.spawn(function()
					local fadeDuration = 0.4
					local startTime = os.clock()
					while os.clock() - startTime < fadeDuration do
						local alpha = (os.clock() - startTime) / fadeDuration
						beam.Transparency = NumberSequence.new(alpha)
						beam.Width0 = 4.5 * (1 - alpha)
						RunService.RenderStepped:Wait()
					end
					attTop:Destroy()
					tempFloorPart:Destroy()
				end)
			else
				attTop:Destroy()
				tempFloorPart:Destroy()
			end
		end
	elseif vfxName == "Wave" then
		local startCF = data.StartCFrame
		if not startCF then return end
		
		local folder = ReplicatedStorage:WaitForChild("VFX", 5)
		local waveTemplate = folder and folder:WaitForChild("Wave", 5) and folder.Wave:WaitForChild("Wave", 5)
		
		if waveTemplate then
			local wave = waveTemplate:Clone()
			wave.Parent = workspace
			
			-- Initial State (Below Ground & Invisible)
			local rotationOffset = CFrame.Angles(math.rad(90), math.rad(0), 0)
			local initialPos = startCF * CFrame.new(0, -15, 0) * rotationOffset
			wave:PivotTo(initialPos)
			wave.Transparency = 1 -- Start invisible
			
			-- Play Spawn SFX
			local waveSFX = folder.Wave:FindFirstChild("WaveSFX")
			PlaySFX(waveSFX, wave)
			
			-- Simply Enable (No Tween)
			wave.Transparency = 0
			
			-- Greyscale for Foreign Players
			if isForeign then
				local grey = Color3.new(0.5, 0.5, 0.5)
				local greySeq = ColorSequence.new(grey)
				for _, d in ipairs(wave:GetDescendants()) do
					if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
						d.Color = greySeq
					elseif d:IsA("BasePart") and d.Transparency < 1 then
						d.Color = grey
					end
				end
			end
			
			-- Enable Beams/Particles
			for _, child in ipairs(wave:GetDescendants()) do
				if child:IsA("Beam") or child:IsA("ParticleEmitter") or child:IsA("Trail") then
					child.Enabled = true
				end
			end
			
			-- Animation Loop
			local RunService = game:GetService("RunService")
			local startTime = os.clock()
			local duration = 2
			local speed = 40 -- 20-25 studs/sec
			
			local hitFish = {}
			local waveId = nextUpdaterId
			nextUpdaterId += 1
			ActiveUpdaters[waveId] = function(dt)
				if not wave or not wave.Parent then
					ActiveUpdaters[waveId] = nil
					return
				end
				
				local elapsed = os.clock() - startTime
				
				-- Movement (Forward + Bobbing)
				local forwardDist = elapsed * speed
				local bob = math.sin(elapsed * 10) * -0.7 -- Up/Down
				
				-- Rise up logic (First 0.5s)
				local riseOffset = -15
				if elapsed < 0.5 then
					riseOffset = -15 + (elapsed / 0.5) * 15 -- Lerp -15 -> 0
				elseif elapsed > (duration - 0.5) then
					-- Sink down logic (Last 0.5s)
					local sinkTime = elapsed - (duration - 0.5)
					riseOffset = 0 - (sinkTime / 0.5) * 15 -- Lerp 0 -> -15
				else
					riseOffset = 0
				end
				
				local currentCF = startCF * CFrame.new(0, riseOffset + bob, -forwardDist) * rotationOffset -- Moving/Facing Forward (-Z) with rotation
				wave:PivotTo(currentCF)
				
				-- Check Collision with Fish
				-- Check Collision with Fish (Throttled)
				local checkInterval = 0.1
				local lastCheck = wave:GetAttribute("LastCheck") or 0
				
				if (elapsed - lastCheck) >= checkInterval then
					wave:SetAttribute("LastCheck", elapsed)
					
					local fishes = FishController.GetSpawnedFish()
					if fishes then
						local wavePos = (wave:IsA("BasePart") and wave.Position) or 
							(wave:IsA("Model") and wave.PrimaryPart and wave.PrimaryPart.Position) or 
							currentCF.Position
						
						for index, fishModel in pairs(fishes) do
							if not hitFish[index] and fishModel and fishModel.Parent and fishModel.PrimaryPart then
								local dist = (fishModel.PrimaryPart.Position - wavePos).Magnitude
								if dist < 14 then
									hitFish[index] = true
									local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
									local evt = Remotes and Remotes:FindFirstChild("PoseidonFishHitEvent")
									if evt then
										evt:FireServer(tonumber(index))
									end
								end
							end
						end
					end
				end
				
				if elapsed >= duration then
					-- End
					ActiveUpdaters[waveId] = nil
					
					-- Fade Out (Simply Disable)
					wave.Transparency = 1
					
					for _, child in ipairs(wave:GetDescendants()) do
						if child:IsA("ParticleEmitter") then child.Enabled = false end
						if child:IsA("Beam") then child.Enabled = false end
						if child:IsA("Trail") then child.Enabled = false end
					end
					
					game:GetService("Debris"):AddItem(wave, 2)
				end
			end
		end
	elseif vfxName == "Bloodthirst" then
		-- Data: Use provided params or defaults
		local startPos = data.StartPos
		local startDir = data.StartDir
		
		-- If Chain Path is present, derive start from Path
		if data.Path and #data.Path > 0 then
			startPos = data.Path[1]
			if #data.Path > 1 then
				startDir = (data.Path[2] - data.Path[1]).Unit
			else
				startDir = Vector3.new(0, 0, -1)
			end
		else
			-- Fallback to Target/Player
			if not startPos and target then
				if target:IsA("Model") and target.PrimaryPart then
					startPos = target.PrimaryPart.Position
					startDir = target.PrimaryPart.CFrame.LookVector
				elseif target:IsA("BasePart") then
					startPos = target.Position
					startDir = target.CFrame.LookVector
				end
			end
		end

		local duration = data.Duration or 7
		local speed = data.Speed or 40
		local seed = data.Seed or os.time()
		local ricochetVar = data.RicochetVariance or 45
		
		if not startPos then return end
		if not startDir then startDir = Vector3.new(0, 0, -1) end
		
		-- Setup Random Stream
		local rng = Random.new(seed)
		
		-- Create Visuals
		local folder = ReplicatedStorage:FindFirstChild("VFX")
		local slashTemplate = folder and folder:FindFirstChild("Bloodthirst") and folder.Bloodthirst:FindFirstChild("Slash")
		
		if not slashTemplate then return end
		
		local slash = slashTemplate:Clone()
		slash.Parent = workspace
		
		ApplyOverride(slash, data)
		
		-- Use Model Pivot or Part CFrame
		local currentPos = startPos + Vector3.new(0, 2, 0)
		-- Flatten Y direction but keep Y position
		local flatDir = Vector3.new(startDir.X, 0, startDir.Z).Unit
		if flatDir.Magnitude < 0.1 then flatDir = Vector3.new(0, 0, -1) end
		local currentDir = flatDir
		
		local startCF = CFrame.lookAt(currentPos, currentPos + currentDir) * CFrame.Angles(0, 0, math.rad(90))
		slash:PivotTo(startCF)
		
		-- Enable Particles
		for _, d in ipairs(slash:GetDescendants()) do
			if d:IsA("ParticleEmitter") then 
				d.Enabled = true
				d:Emit(1) 
			end
		end
		
		-- Play SFX
		local sfx = slash:FindFirstChild("SFX") or (folder.Bloodthirst:FindFirstChild("SFX"))
		PlaySFX(sfx, (slash:IsA("Model") and slash.PrimaryPart) or slash)
		
		-- Movement Loop
		local RunService = game:GetService("RunService")
		local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
		local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
		
		-- Mode Switch: Chain Path vs Ricochet
		if data.Path and #data.Path > 1 then
			-- CHAIN MODE
			local path = data.Path
			local totalPoints = #path
			local currentPointIndex = 1
			local startTime = os.clock()
			
			local currentSegStart = path[1]
			local currentSegEnd = path[2]
			local segDist = (currentSegEnd - currentSegStart).Magnitude
			local segDuration = segDist / speed
			local segStartTime = startTime
			
			local updaterId = nextUpdaterId
			nextUpdaterId += 1
			ActiveUpdaters[updaterId] = function(dt)
				if not slash or not slash.Parent then
					ActiveUpdaters[updaterId] = nil
					return
				end
				
				local now = os.clock()
				local segElapsed = now - segStartTime
				
				-- Move along segment
				local alpha = math.min(segElapsed / segDuration, 1)
				local currentPos = currentSegStart:Lerp(currentSegEnd, alpha)
				
				-- Orientation
				local dir = (currentSegEnd - currentSegStart).Unit
				if dir.Magnitude > 0 then
					slash:PivotTo(CFrame.lookAt(currentPos, currentPos + dir) * CFrame.Angles(0, 0, math.rad(90)))
				else
					slash:PivotTo(CFrame.new(currentPos))
				end
				
				-- Next Segment?
				if alpha >= 1 then
					currentPointIndex += 1
					if currentPointIndex >= totalPoints then
						-- Done
						ActiveUpdaters[updaterId] = nil
						-- Fade Out
						local TweenService = game:GetService("TweenService")
						if slash:IsA("BasePart") then
							TweenService:Create(slash, TweenInfo.new(0.5), {Transparency = 1}):Play()
						end
						for _, d in ipairs(slash:GetDescendants()) do
							if d:IsA("ParticleEmitter") then d.Enabled = false end
							if d:IsA("BasePart") or d:IsA("Decal") then 
								TweenService:Create(d, TweenInfo.new(0.5), {Transparency = 1}):Play() 
							end
						end
						Debris:AddItem(slash, 1)
						return
					else
						-- Start Next Segment
						currentSegStart = path[currentPointIndex]
						currentSegEnd = path[currentPointIndex+1]
						segDist = (currentSegEnd - currentSegStart).Magnitude
						segDuration = math.max(segDist / speed, 0.05) -- prevent div/0
						segStartTime = now
					end
				end
			end
		else
			-- LEGACY RICOCHET MODE
			-- Ray Params for Wall Check
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Include
		local filterFolders = {}
		for fieldName, _ in pairs(ResourceConfig.Fields) do
			local f = workspace:FindFirstChild(fieldName)
			if f then table.insert(filterFolders, f) end
		end
		rayParams.FilterDescendantsInstances = filterFolders
		
		local startTime = os.clock()
		local updaterId2 = nextUpdaterId
		nextUpdaterId += 1
		
		ActiveUpdaters[updaterId2] = function(dt)
			if not slash or not slash.Parent then
				ActiveUpdaters[updaterId2] = nil
				return
			end
			
			local elapsed = os.clock() - startTime
			if elapsed >= duration then
				ActiveUpdaters[updaterId2] = nil
				-- Fade Out
				local TweenService = game:GetService("TweenService")
				if slash:IsA("BasePart") then
					TweenService:Create(slash, TweenInfo.new(0.5), {Transparency = 1}):Play()
				end
				for _, d in ipairs(slash:GetDescendants()) do
					if d:IsA("ParticleEmitter") then d.Enabled = false end
					if d:IsA("BasePart") or d:IsA("Decal") then 
						TweenService:Create(d, TweenInfo.new(0.5), {Transparency = 1}):Play() 
					end
				end
				Debris:AddItem(slash, 1)
				return
			end
			
			-- Move
			local moveDist = speed * dt
			local targetPos = currentPos + (currentDir * moveDist)
			
			-- Wall Check (Ground Check Method)
			-- Check ahead
			local groundCheck = workspace:Raycast(targetPos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), rayParams)
			
			if not groundCheck then
				-- Ricochet
				local normal = -currentDir -- Default bounce back
				
				-- Try to find wall normal by casting back or checking edge?
				-- Since we just fell off the edge, the wall is effectively the edge of the previous valid ground.
				-- Simplest visual ricochet: Just turn 180 + variance
				
				-- Try to infer edge normal by checking side probes?
				-- Expensive. Let's use the same logic as Server (which needs to be robust).
				-- If Server logic just bounces back:
				
				-- Probe slightly backwards to find ground we just left?
				-- Actually, if 'targetPos' is void, we stop at 'currentPos' and turn.
				targetPos = currentPos -- Snap back
				
				-- Calculate Reflect
				-- For void variance:
				local angle = math.rad(rng:NextNumber(-ricochetVar, ricochetVar))
				-- Reflect 180 is boring, usually "Ricochet" implies bouncing off a wall.
				-- If no wall (void), maybe turn 90?
				-- Let's stick to the behavior: Reflect vector around "Normal".
				-- If fell off world, typical normal is pointing IN to the field.
				-- Let's approximate normal as -CurrentDir (bounce back) but with high variance it looks okay.
				
				-- Server logic used:
				-- normal = -currentDir 
				-- ... probe logic ...
				
				-- Let's replicate the probe logic for accuracy
				local probeOrigin = currentPos - Vector3.new(0, 2.5, 0)
				local probeDir = -currentDir * 5 -- Look back
				local wallHit = workspace:Raycast(probeOrigin, probeDir, rayParams)
				if wallHit then
					-- We are essentially raycasting "into" the floor edge we just passed?
					-- No, this is tricky. 
					-- Let's simplify: Just bounce random +/- 90 degrees from -Dir
				end
				
				-- Apply Variance to the 'Bounce Back' vector
				local baseDir = -currentDir
				local randomAngle = math.rad(rng:NextNumber(-ricochetVar, ricochetVar))
				currentDir = CFrame.Angles(0, randomAngle, 0) * baseDir
				
				-- Force update target to new dir slightly to prevent getting stuck
				targetPos = currentPos + (currentDir * (moveDist * 0.1))
			else
				-- Update Position
			end
			
			currentPos = targetPos
			slash:PivotTo(CFrame.lookAt(currentPos, currentPos + currentDir) * CFrame.Angles(0, 0, math.rad(90)))
		end
		end -- End LEGACY RICOCHET MODE
	end
end

-- Pinned Down VFX: Tween pin up and down
function VFXController.PlayPinnedDown(position, duration, tweenHeight, isForeign)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	
	-- Clone pin from ReplicatedStorage
	local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
	if not vfxFolder then return end
	local pinFolder = vfxFolder:FindFirstChild("Pin")
	if not pinFolder then return end
	local pinTemplate = pinFolder:FindFirstChild("Pin")
	if not pinTemplate then return end
	
	local pin = pinTemplate:Clone()
	
	-- Position 10 studs underground initially
	local startPos = position - Vector3.new(0, 10, 0)
	pin:PivotTo(CFrame.new(startPos))
	pin.Parent = workspace
	
	-- Greyscale for Foreign Players
	if isForeign then
		local grey = Color3.new(0.5, 0.5, 0.5)
		local greySeq = ColorSequence.new(grey)
		for _, d in ipairs(pin:GetDescendants()) do
			if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
				d.Color = greySeq
			elseif d:IsA("BasePart") and d.Transparency < 1 then
				d.Color = grey
			end
		end
	end
	
	-- Enable all particles
	for _, desc in ipairs(pin:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = true
		end
		
		-- Grey out for foreign players
		if isForeign then
			if desc:IsA("BasePart") then
				desc.Color = Color3.new(0.5, 0.5, 0.5)
			elseif desc:IsA("ParticleEmitter") or desc:IsA("Beam") then
				desc.Color = ColorSequence.new(Color3.new(0.5, 0.5, 0.5))
			end
		end
	end
	
	if not pin or not pin.Parent then return end
	
	local TweenService = game:GetService("TweenService")
	local startCF = pin:GetPivot()
	-- Pin spawns 10 studs underground, so we need to tween up by (tweenHeight + 10)
	local targetCF = startCF * CFrame.new(0, tweenHeight + 10, 0)
	
	-- Create a Part to tween (workaround for model tweening)
	local tweenPart = Instance.new("Part")
	tweenPart.Anchored = true
	tweenPart.CanCollide = false
	tweenPart.Transparency = 1
	tweenPart.CFrame = startCF
	tweenPart.Parent = workspace
	
	-- Tween UP (1 second)
	local tweenUp = TweenService:Create(tweenPart, 
		TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{CFrame = targetCF}
	)
	
	-- Update pin position to match tween part
	local pinUpdaterId = nextUpdaterId
	nextUpdaterId += 1
	ActiveUpdaters[pinUpdaterId] = function()
		if pin and pin.Parent and tweenPart and tweenPart.Parent then
			pin:PivotTo(tweenPart.CFrame)
		else
			ActiveUpdaters[pinUpdaterId] = nil
		end
	end
	
	tweenUp:Play()
	tweenUp.Completed:Wait()
	
	-- After duration, fade and tween DOWN
	task.delay(duration, function()
		if not pin or not pin.Parent then 
			ActiveUpdaters[pinUpdaterId] = nil
			if tweenPart then tweenPart:Destroy() end
			return 
		end
		
		-- Fade all parts and disable particles
		for _, desc in ipairs(pin:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then
				desc.Enabled = false
			elseif desc:IsA("BasePart") then
				local tween = TweenService:Create(desc,
					TweenInfo.new(2, Enum.EasingStyle.Linear),
					{Transparency = 1}
				)
				tween:Play()
			elseif desc:IsA("Decal") or desc:IsA("Texture") then
				local tween = TweenService:Create(desc,
					TweenInfo.new(2, Enum.EasingStyle.Linear),
					{Transparency = 1}
				)
				tween:Play()
			end
		end
		
		-- Tween DOWN
		local tweenDown = TweenService:Create(tweenPart,
			TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{CFrame = startCF}
		)
		
		tweenDown:Play()
		tweenDown.Completed:Wait()
		
		-- Cleanup
		ActiveUpdaters[pinUpdaterId] = nil
		if tweenPart then tweenPart:Destroy() end
	end)
end

function VFXController.PlayRabbitSound(name, pos)
	if not pos then return end

	local RS = game:GetService("ReplicatedStorage")
	local sfxFolder = RS:FindFirstChild("SFX")
	local rabbitFolder = sfxFolder and sfxFolder:FindFirstChild("RabbitFish")
	if not rabbitFolder then return end

	local soundName
	if name == "RabbitEnter" then
		if math.random() > 0.5 then soundName = "Rabbit1" else soundName = "Rabbit2" end
	elseif name == "RabbitCollect" then
		local r = math.random(1, 3)
		soundName = "RabbitCollect" .. r
	end

	if not soundName then return end

	local template = rabbitFolder:FindFirstChild(soundName)
	if template then
		local sound = template:Clone()

		-- Play at location
		local part = Instance.new("Part")
		part.Name = "RabbitSFX"
		part.Transparency = 1
		part.CanCollide = false
		part.Anchored = true
		part.Position = pos
		part.Parent = workspace

		sound.Parent = part
		local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
		if not isSfxDisabled then
			sound:Play()
		end

		game.Debris:AddItem(part, sound.TimeLength + 0.1)
	end
end

function VFXController.PlayRainmakerBullet(startPos, endPos, duration)
	local RS = game:GetService("ReplicatedStorage")
	duration = duration or (math.random() * 0.35 + 0.4)
	
	-- Template (Defensive check)
	local vfx = RS:FindFirstChild("VFX")
	local rmFolder = vfx and vfx:FindFirstChild("Rainmaker")
	local template = rmFolder and rmFolder:FindFirstChild("Bullet")
	
	if not template then return end
	
	local bullet = template:Clone()
	
	-- Handle Attachment vs Part
	if bullet:IsA("Attachment") then
		local carrier = Instance.new("Part")
		carrier.Name = "BulletCarrier"
		carrier.Transparency = 1
		carrier.Size = Vector3.new(0.5,0.5,0.5)
		carrier.CanCollide = false
		carrier.Anchored = true
		carrier.Position = startPos
		carrier.Parent = workspace
		bullet.Parent = carrier
		bullet = carrier
	else
		bullet.Parent = workspace
		bullet.CFrame = CFrame.new(startPos)
		bullet.Anchored = true
		bullet.CanCollide = false
	end
	
	local RunService = game:GetService("RunService")
	local startTime = os.clock()

	local midPoint = (startPos + endPos) / 2
	local height = math.max((startPos - endPos).Magnitude * 1, 50) 
	local controlPoint = midPoint + Vector3.new(0, height, 0)
	
	-- Pre-calculate random spread direction
	local forward = (endPos - startPos).Unit
	local up = Vector3.new(0, 1, 0)
	local right = forward:Cross(up)
	if right.Magnitude < 0.001 then right = Vector3.new(1, 0, 0) end
	
	-- Randomize the wobble plane
	local randomAngle = math.random() * math.pi * 2
	local spreadRotation = CFrame.fromAxisAngle(forward, randomAngle)
	local spreadRight = spreadRotation:VectorToWorldSpace(right)
	
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local elapsed = now - startTime
		local t = math.clamp(elapsed / duration, 0, 1)
		
		-- Bezier Calculation
		local l1 = startPos:Lerp(controlPoint, t)
		local l2 = controlPoint:Lerp(endPos, t)
		local currentPos = l1:Lerp(l2, t)
		
		-- Wobble Calculation
		local freq = 1 -- Wobble frequency
		local amp = math.sin(t * math.pi) * 25 -- Amplitude peaks in middle (Increased from 14)
		local wobbleOffset = spreadRight * math.sin(t * freq * math.pi * 2) * amp
		
		-- Final Position
		local finalPos = currentPos + wobbleOffset
		
		-- Orientation (Look along tangent)
		local tangent = (2 * (1-t) * (controlPoint - startPos) + 2 * t * (endPos - controlPoint)).Unit
		bullet.CFrame = CFrame.lookAt(finalPos, finalPos + tangent) * CFrame.Angles(math.rad(90), 0, 0)
		
		if t >= 1 then
			connection:Disconnect()
			
			-- Explosion Logic
			if rmFolder then
				local explodeFolder = rmFolder:FindFirstChild("Explode")
				local explodeAtt = explodeFolder and explodeFolder:FindFirstChild("Attachment")
				
				if explodeAtt then
					local p = Instance.new("Part")
					p.Name = "ExplosionFX"
					p.Transparency = 1
					p.Anchored = true
					p.CanCollide = false
					p.Position = endPos
					p.Parent = workspace
					
					local att = explodeAtt:Clone()
					att.Parent = p
					
					for _, child in ipairs(att:GetChildren()) do
						if child:IsA("ParticleEmitter") then
							local count = child:GetAttribute("EmitCount") or 1
							child:Emit(count)
						end
					end
					
					game.Debris:AddItem(p, 2)
				end
			end
			
			for _, d in ipairs(bullet:GetDescendants()) do
				if d:IsA("Trail") or d:IsA("ParticleEmitter") then
					d.Enabled = false
				elseif d:IsA("BasePart") or d:IsA("Decal") then
					d.Transparency = 1
				end
			end
			
			if bullet:IsA("BasePart") then bullet.Transparency = 1 end
			game.Debris:AddItem(bullet, 2)
		end
	end)
end

return VFXController
