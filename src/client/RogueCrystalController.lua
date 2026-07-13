local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MobConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MobConfig"))

local RogueCrystalController = {}

function RogueCrystalController.Start()
	task.spawn(function()
		local localPlayer = Players.LocalPlayer
		local mobsFolder = Workspace:WaitForChild("Mobs", math.huge)
	
	local activeFish = nil
	local rootPart = nil
	local state = "Spawning" -- Spawning, Idle, Chasing, Attacking, Returning
	local spawnCFrame = nil
	local cfg = MobConfig.MobTypes["Rogue Crystal Fish"] or {}
	local moveSpeed = cfg.ChaseSpeed or 16
	local returnSpeed = cfg.ReturnSpeed or 12
	local aggroRange = cfg.AggroRange or 30
	local contactDamage = cfg.Damage or 10
	local bounceDamage = cfg.Attack1Damage or 30
	local attackCooldownLength = cfg.AttackCooldown or 1.5
	
	local function initFish(fishModel)
		activeFish = fishModel
		rootPart = fishModel:FindFirstChild("HumanoidRootPart") or fishModel.PrimaryPart or fishModel:FindFirstChildWhichIsA("BasePart")
		if not rootPart then return end
		
		spawnCFrame = rootPart.CFrame
		
		-- Dive up animation
		local startCFrame = spawnCFrame * CFrame.new(0, -20, 0)
		activeFish:PivotTo(startCFrame)
		
		local cframeVal = Instance.new("CFrameValue")
		cframeVal.Value = startCFrame
		cframeVal.Changed:Connect(function(val)
			if activeFish and activeFish.Parent then
				activeFish:PivotTo(val)
			end
		end)
		
		local diveTween = TweenService:Create(cframeVal, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = spawnCFrame})
		diveTween:Play()
		diveTween.Completed:Wait()
		cframeVal:Destroy()
		
		state = "Idle"
		
		-- Wiggle setup
		local timePassed = 0
		local lastDamageTime = 0
		local attackCooldown = false
		
		RunService.Heartbeat:Connect(function(dt)
			if not activeFish or not activeFish.Parent or not rootPart then return end
			if state == "Attacking" or state == "Spawning" then return end
			
			timePassed = timePassed + dt
			local char = localPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChild("Humanoid")
			
			if not hrp or not hum or hum.Health <= 0 then
				-- Return to spawn smoothly
				local distToSpawn = (rootPart.Position - spawnCFrame.Position).Magnitude
				if distToSpawn > 1 then
					local targetCFrame = CFrame.lookAt(rootPart.Position, spawnCFrame.Position)
					local newPos = rootPart.Position + targetCFrame.LookVector * (returnSpeed * dt)
					local wiggle = CFrame.Angles(0, math.sin(timePassed * 8) * 0.3, 0)
					activeFish:PivotTo(CFrame.new(newPos) * targetCFrame.Rotation * wiggle)
					state = "Returning"
				else
					local wiggle = CFrame.Angles(0, math.sin(timePassed * 5) * 0.2, 0)
					activeFish:PivotTo(spawnCFrame * wiggle)
					state = "Idle"
				end
				return
			end
			
			local dist = (hrp.Position - rootPart.Position).Magnitude
			
			if dist <= aggroRange then
				state = "Chasing"
				-- Move towards player smoothly
				local targetCFrame = CFrame.lookAt(rootPart.Position, hrp.Position)
				local newPos = rootPart.Position + targetCFrame.LookVector * (moveSpeed * dt)
				
				-- Add wiggle to the rotation
				local wiggle = CFrame.Angles(0, math.sin(timePassed * 8) * 0.3, 0)
				activeFish:PivotTo(CFrame.new(newPos) * targetCFrame.Rotation * wiggle)
				
				-- Check touch damage
				if dist < 4 and (os.clock() - lastDamageTime) > 1 then
					lastDamageTime = os.clock()
					hum:TakeDamage(contactDamage)
				end
			elseif dist > aggroRange and dist < cfg.LeashRange then -- Only aggro if reasonably close
				if not attackCooldown then
					state = "Attacking"
					attackCooldown = true
					
					task.spawn(function()
						local startPos = rootPart.Position
						local targetPos = hrp.Position
						local lookDir = CFrame.lookAt(startPos, targetPos)
						
						local cfVal = Instance.new("CFrameValue")
						cfVal.Value = lookDir.Rotation + startPos
						local conn = cfVal.Changed:Connect(function(val)
							if activeFish and activeFish.Parent then
								activeFish:PivotTo(val)
							end
						end)
						
						-- Bounce back
						local backPos = startPos - lookDir.LookVector * 15
						local t1 = TweenService:Create(cfVal, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Value = lookDir.Rotation + backPos})
						t1:Play()
						t1.Completed:Wait()
						
						-- Launch forward
						-- Refresh target pos in case player moved
						if hrp then targetPos = hrp.Position end
						local attackLook = CFrame.lookAt(rootPart.Position, targetPos)
						local forwardPos = targetPos + attackLook.LookVector * 10 -- Go past them a bit
						
						local hitPlayer = false
						local hitConn
						hitConn = RunService.Heartbeat:Connect(function()
							if hrp and not hitPlayer then
								if (rootPart.Position - hrp.Position).Magnitude < 10 then
									hitPlayer = true
									hum:TakeDamage(bounceDamage)
								end
							end
						end)
						
						local t2 = TweenService:Create(cfVal, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {Value = attackLook.Rotation + forwardPos})
						t2:Play()
						t2.Completed:Wait()
						hitConn:Disconnect()
						
						-- Come back to original launch spot
						local t3 = TweenService:Create(cfVal, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Value = lookDir.Rotation + startPos})
						t3:Play()
						t3.Completed:Wait()
						
						conn:Disconnect()
						cfVal:Destroy()
						
						state = "Idle"
						task.wait(attackCooldownLength) -- Attack cooldown
						attackCooldown = false
					end)
				end
			else
				-- Too far, return to spawn smoothly if not there
				local distToSpawn = (rootPart.Position - spawnCFrame.Position).Magnitude
				if distToSpawn > 1 then
					local targetCFrame = CFrame.lookAt(rootPart.Position, spawnCFrame.Position)
					local moveSpeed = 12
					local newPos = rootPart.Position + targetCFrame.LookVector * (moveSpeed * dt)
					local wiggle = CFrame.Angles(0, math.sin(timePassed * 8) * 0.3, 0)
					activeFish:PivotTo(CFrame.new(newPos) * targetCFrame.Rotation * wiggle)
					state = "Returning"
				else
					local wiggle = CFrame.Angles(0, math.sin(timePassed * 5) * 0.2, 0)
					activeFish:PivotTo(spawnCFrame * wiggle)
					state = "Idle"
				end
			end
		end)
	end
	
	mobsFolder.ChildAdded:Connect(function(child)
		if child.Name == "Rogue Crystal Fish" then
			initFish(child)
		end
	end)
	
	for _, child in ipairs(mobsFolder:GetChildren()) do
		if child.Name == "Rogue Crystal Fish" then
			initFish(child)
		end
	end
	end)
end

return RogueCrystalController
