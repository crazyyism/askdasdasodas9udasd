local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function Abbreviate(n)
	if n < 1000 then return tostring(math.floor(n + 0.5)) end
	local suffixes = {"K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "Dc"}
	local i = math.floor(math.log10(n) / 3)
	local val = n / (10 ^ (i * 3))
	local suffix = suffixes[i] or ""
	return string.format("%.1f%s", val, suffix):gsub("%.0", "")
end

local function FormatNumber(n, forceAbbreviate)
    if forceAbbreviate then return Abbreviate(n) end
	return tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function ApplyOverride(root, data)
	if not root or not data or not data.ForceOverride then return end
	
	local color = data.Color or Color3.new(1,1,1)
	local colorSeq = ColorSequence.new(color)
	
	-- Only override transparency if explicitly provided in data
	local transpSeq
	if data.Transparency then
		transpSeq = NumberSequence.new(data.Transparency)
	end
	
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
			d.Color = colorSeq
			if transpSeq then d.Transparency = transpSeq end
		elseif d:IsA("BasePart") then
			d.Color = color
			if data.Transparency then d.Transparency = data.Transparency end
		end
	end
end

local VisualController = {}

-- Wait for Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local VisualEvent = Remotes:WaitForChild("VisualEvent")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
local DamageVisualEvent = Remotes:WaitForChild("DamageVisualEvent")

local player = Players.LocalPlayer
local localData = nil
local recentSpawns = {} -- {[Vector3] = count} to track spatial stacking
local pendingBatches = {} -- List of currently accumulating batches

-- Persistent UI for conversion stacking
local conversionGui = nil
local conversionContainer = nil

local function getConversionContainer()
	if conversionGui and conversionGui.Parent and conversionContainer and conversionContainer.Parent then
		return conversionContainer
	end
	
	-- Cleanup old if partially broken
	if conversionGui then conversionGui:Destroy() end
	
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return nil end
	
	conversionGui = Instance.new("BillboardGui")
	conversionGui.Name = "ConversionVisuals"
	conversionGui.Size = UDim2.new(0, 200, 0, 300) -- Large enough to hold 8 labels
	conversionGui.StudsOffset = Vector3.new(0, 4, 0)
	conversionGui.Adornee = head
	conversionGui.AlwaysOnTop = true
	conversionGui.Parent = player.PlayerGui
	
	conversionContainer = Instance.new("Frame")
	conversionContainer.Size = UDim2.new(1, 0, 1, 0)
	conversionContainer.BackgroundTransparency = 1
	conversionContainer.Parent = conversionGui
	
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom -- Stack from bottom up
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 7)
	layout.Parent = conversionContainer
	
	return conversionContainer
end

function VisualController.BatchSpawn(pos, amount, color, isCrit, sizeScale, isMegaCrit)
	-- Check setting
	if localData and localData.Settings and localData.Settings.AlgaeText == false then return end
	
	-- Check for existing batch to merge with (Must match Color & Size to stack ONLY same type)
	local foundBatch = nil
	local targetSize = sizeScale or 1
	
	for _, batch in ipairs(pendingBatches) do
		-- Merge if: Same color and Close proximity
		if batch.Color == color and (batch.Position - pos).Magnitude < 20 then
			foundBatch = batch
			break
		end
	end
	
	if foundBatch then
		-- Merge into existing
		local oldAmount = foundBatch.Amount
		local oldCount = foundBatch.Count
		
		foundBatch.Amount = oldAmount + amount
		foundBatch.Count = oldCount + 1
		foundBatch.Amount = oldAmount + amount
		foundBatch.Count = oldCount + 1
		if isCrit then foundBatch.IsCrit = true end -- Upgrade to crit if any part is crit
		if isMegaCrit then foundBatch.IsMegaCrit = true end -- Upgrade to Mega Crit
		
		-- Running average for position
		foundBatch.Position = foundBatch.Position:Lerp(pos, 1 / (oldCount + 1))
	else
		-- Create new batch
		local newBatch = {
			Amount = amount,
			Position = pos,
			Color = color,
			IsCrit = isCrit,
			IsMegaCrit = isMegaCrit,
			SizeScale = targetSize,
			Count = 1
		}
		table.insert(pendingBatches, newBatch)
		
		
		-- Schedule release
		task.delay(0.15, function()
			-- Remove from pending
			local idx = table.find(pendingBatches, newBatch)
			if idx then table.remove(pendingBatches, idx) end
			
			-- Render
			VisualController.SpawnFloatingText(newBatch.Position, newBatch.Amount, newBatch.Color, newBatch.IsCrit, newBatch.SizeScale, newBatch.IsMegaCrit)
		end)
	end
end

function VisualController.Start()
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 10)
		if not map then return end
		
		local topParts = {}
		for _, part in ipairs(map:GetDescendants()) do
			if part.Name == "Top" and part:IsA("BasePart") then
				table.insert(topParts, {Part = part, OriginalTransparency = part.Transparency})
			end
		end
		
		RunService.RenderStepped:Connect(function()
			local character = Players.LocalPlayer.Character
			if not character then return end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then return end
			
			for _, data in ipairs(topParts) do
				local part = data.Part
				if part.Parent then
					local diff = part.Position.Y - root.Position.Y
					if diff > 0 then
						if diff >= 20 then
							part.Transparency = 1
						else
							part.Transparency = data.OriginalTransparency + (1 - data.OriginalTransparency) * (diff / 20)
						end
					else
						part.Transparency = data.OriginalTransparency
					end
				end
			end
		end)
	end)

	DataUpdateEvent.OnClientEvent:Connect(function(data)
		localData = data
	end)

	VisualEvent.OnClientEvent:Connect(function(pos, amount, color, isCrit, isConversion, fishModel, sizeScale, isPreBatched, isMegaCrit) -- Added isMegaCrit
		-- Check setting for consolidated server events too
		if not isConversion and localData and localData.Settings and localData.Settings.AlgaeText == false then return end
		
		-- Remove special case - biomass text should appear at world position like algae
		-- Use batching to combine numbers if many appear at once (e.g. Area Harvest)
		-- Biomass text uses smaller size scale
		local scale = isConversion and 0.7 or (sizeScale or 1)
		
		if isPreBatched then
			-- Skip client batching for server-consolidated events
			VisualController.SpawnFloatingText(pos, amount, color, isCrit, scale, isMegaCrit)
		else
			VisualController.BatchSpawn(pos, amount, color, isCrit, scale, isMegaCrit)
		end
	end)
	
	DamageVisualEvent.OnClientEvent:Connect(function(pos, amount, isCrit, isMiss, isMegaCrit)
		VisualController.SpawnDamageText(pos, amount, isCrit, isMiss, isMegaCrit)
	end)
	
	-- Reset container on character respawn
	player.CharacterAdded:Connect(function()
		if conversionGui then
			conversionGui:Destroy()
			conversionGui = nil
			conversionContainer = nil
		end
	end)
	
	-- Sea Mine text formatted custom to client
	task.spawn(function()
		while true do
			task.wait(0.1)
			local useAbbr = localData and localData.Settings and localData.Settings.AbbreviateAlgae
			local seaMinesFolder = workspace:FindFirstChild("SeaMines")
			if seaMinesFolder then
				for _, mineModel in ipairs(seaMinesFolder:GetChildren()) do
					if mineModel.Name == "SeaMine" then
						local mainPart = mineModel:FindFirstChild("Main")
						if mainPart then
							local amt = mainPart:GetAttribute("AlgaeAmount")
							local targetCap = mainPart:GetAttribute("TargetCapacity") or 1000
							local rarityName = mainPart:GetAttribute("MineRarityName") or "Sea Mine"
							local timeLeft = mainPart:GetAttribute("MineTimeLeft")
							if amt then
								local gui = mainPart:FindFirstChild("QuestIndicate") or mainPart:FindFirstChildWhichIsA("BillboardGui")
								if gui then
									local titleUI = gui:FindFirstChild("TitleUI")
									if titleUI then
										local algaeFrame = titleUI:FindFirstChild("Algae")
										if algaeFrame then
											local amountUI = algaeFrame:FindFirstChild("AlgaeAmount")
											if amountUI then
												amountUI.Text = FormatNumber(amt, useAbbr) .. " / " .. FormatNumber(targetCap, useAbbr)
											end
											local timerUI = algaeFrame:FindFirstChild("Timer")
											if timerUI and timeLeft then
												local m = math.floor(timeLeft / 60)
												local s = timeLeft % 60
												timerUI.Text = rarityName .. " (" .. string.format("%d:%02d", m, s) .. ")"
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end)
end

function VisualController.SpawnConversionText(amount, color)
	local container = getConversionContainer()
	if not container then return end
	
	-- Manage Limit (Max 8)
	local children = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(children, child)
		end
	end
	
	-- Keep recent few
	if #children >= 6 then
		table.sort(children, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		local oldest = children[1]
		if oldest then oldest:Destroy() end
	end

	local useAbbr = localData and localData.Settings and localData.Settings.AbbreviateAlgae
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 0, 0) -- Start height 0
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "+" .. FormatNumber(amount, useAbbr)
	textLabel.TextColor3 = color
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.Cartoon -- More dynamic font
	textLabel.TextStrokeTransparency = 0 -- Outline
	textLabel.TextStrokeColor3 = Color3.new(0,0,0)
	textLabel.LayoutOrder = os.clock() * 1000
	textLabel.Rotation = math.random(-10, 10) -- Dynamic tilt
	textLabel.Parent = container
	
	-- Initial state
	textLabel.TextTransparency = 1
	textLabel.TextStrokeTransparency = 1
	
	-- Animate
	task.spawn(function()
		-- POP IN (Elastic Scale + Fade In)
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
		
		-- 1. Size Pop
		local targetSize = UDim2.new(1, 0, 0, 35) -- Target Height
		textLabel:TweenSize(targetSize, Enum.EasingDirection.Out, Enum.EasingStyle.Elastic, 0.5, true)
		
		-- 2. Fade In + Stroke
		TweenService:Create(textLabel, TweenInfo.new(0.3), {
			TextTransparency = 0,
			TextStrokeTransparency = 0
		}):Play()
		
		-- 3. Float/Wobble Loop
		local startRot = textLabel.Rotation
		local startTime = os.clock()
		while textLabel.Parent and os.clock() - startTime < 1.0 do
			local t = os.clock() - startTime
			textLabel.Rotation = startRot + math.sin(t * 10) * 5 -- Wobble
			RunService.Heartbeat:Wait()
		end
		
		-- FADE OUT (Fly up + Fade)
		if textLabel.Parent then
			local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(textLabel, fadeInfo, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				Rotation = startRot + math.random(-20, 20) -- Spin out
			}):Play()
			
			task.wait(0.5)
			textLabel:Destroy()
		end
	end)
end

local ActiveTexts = {} -- List of {Attachment=att, Label=gui, Start=time, Pos=vec3, Duration=1, IsCrit=bool}

-- Shared Render Loop
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = #ActiveTexts, 1, -1 do
		local data = ActiveTexts[i]
		local elapsed = now - data.Start
		
		if elapsed >= data.Duration then
			-- Cleanup
			if data.Attachment then data.Attachment:Destroy() end
			table.remove(ActiveTexts, i)
		else
			local progress = elapsed / data.Duration
			
			-- Float Up Logarithmically/EaseOut
			local yOffset = 4 * math.sin(progress * math.pi * 0.5)
			
			-- Side to Side Wave
			local waveFreq = 8
			local waveAmp = 0.5
			local xOffset = math.sin(elapsed * waveFreq) * waveAmp
			
			if data.Attachment then
				data.Attachment.WorldPosition = data.BasePos + Vector3.new(xOffset, yOffset, 0)
			end
			
			if data.Label then
				-- Fade Out
				if progress > 0.6 then
					local fadeProg = (progress - 0.6) / 0.4
					data.Label.TextTransparency = fadeProg
					data.Label.TextStrokeTransparency = fadeProg
				end
				
				-- Crit Effects (BSS Style: Jitter + Color Flash)
				if data.IsMegaCrit then
					-- MEGA CRIT: Large Jitter + Red/Original Color Flash
					data.Label.Rotation = math.sin(now * 40) * 10
					
					local flashFreq = 15 -- Faster Flash
					local isRed = math.floor(now * flashFreq) % 2 == 0
					
					data.Label.TextColor3 = isRed and Color3.fromRGB(255, 0, 0) or data.Color
					
					-- Pulse Size
					local scalePulse = 1 + math.sin(now * 10) * 0.2
					-- Note: Can't easily pulse UDim2 size dynamically here without refetching original, 
					-- but rotation/color is enough for now along with the large initialization size.
					
				elseif data.IsCrit then
					data.Label.Rotation = math.sin(now * 30) * 12
					
					-- Color Flashing (Normal -> Yellow -> Normal)
					local flashFreq = 10 -- Hz
					local isFlash = math.floor(now * flashFreq) % 2 == 0
					data.Label.TextColor3 = isFlash and Color3.fromRGB(255, 255, 0) or data.Color
				else
					data.Label.Rotation = -xOffset * 10
					data.Label.TextColor3 = data.Color
				end
			end
		end
	end
end)

function VisualController.SpawnFloatingText(pos, amount, color, isCrit, sizeScale, isMegaCrit)
	-- Removed merge with ActiveTexts - only pending batches can merge
	-- This prevents adding to numbers that are already visually shown

	-- Spatial stacking (Coarse grid to group nearby multi-type spawns)
	local gridSize = 6
	local gridPos = Vector3.new(math.floor(pos.X/gridSize), math.floor(pos.Y/gridSize), math.floor(pos.Z/gridSize))
	local stackHeight = recentSpawns[gridPos] or 0
	recentSpawns[gridPos] = stackHeight + 1
	
	-- Clean up decrement
	task.delay(0.5, function()
		if recentSpawns[gridPos] then
			local newVal = recentSpawns[gridPos] - 1
			if newVal <= 0 then
				recentSpawns[gridPos] = nil -- Actual cleanup
			else
				recentSpawns[gridPos] = newVal
			end
		end
	end)

	-- Tighter stack with more vertical space
	local offset = Vector3.new(math.random(-5, 5)/20, stackHeight * 1.6, math.random(-5, 5)/20)
	local finalPos = pos + offset

	if isMegaCrit then
		-- Mega Crit floats slightly higher to stand out
		finalPos = finalPos + Vector3.new(0, 2, 0)
	end
	
	-- Safety Cap for ActiveTexts to prevent memory explosion
	if #ActiveTexts > 200 then
		-- Remove oldest
		local old = table.remove(ActiveTexts, 1)
		if old and old.Attachment then old.Attachment:Destroy() end
		if old and old.Label then old.Label:Destroy() end
	end

	-- Optimization: Use Attachment in Terrain instead of Part
	local att = Instance.new("Attachment")
	att.Position = finalPos
	att.Parent = workspace.Terrain
	
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 100, 0, 50)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = att
	bb.Parent = att -- Parent to attachment so it cleans up with it
	
	local useAbbr = localData and localData.Settings and localData.Settings.AbbreviateAlgae
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "+" .. FormatNumber(amount, useAbbr)
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.Cartoon
	label.TextScaled = true
	label.Parent = bb
	
	local baseScale = (sizeScale or 1) * 0.6
	-- Dynamic Scale based on Amount
	local amountScale = math.clamp(0.57 + math.log10(amount) * 0.2, 0.57, 2.5)
	
	if isCrit then
		amountScale = amountScale * 1.5 -- Bigger for crits
	end
	
	if isMegaCrit then
		amountScale = amountScale * 2.5 -- Even Bigger for Mega Crits
		label.Rotation = math.random(-15, 15) -- Initial aggressive tilt
	end

	local targetSize = UDim2.new(baseScale * amountScale, 0, baseScale * amountScale, 0)
	
	label.Size = UDim2.new(0,0,0,0)
	label:TweenSize(targetSize, Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.4, true)
	
	table.insert(ActiveTexts, {
		Attachment = att,
		Label = label,
		Start = os.clock(),
		BasePos = finalPos,
		Duration = isCrit and 1.5 or 1.0,
		IsCrit = isCrit,
		IsMegaCrit = isMegaCrit,
		Amount = amount,
		Color = color
	})
end

function VisualController.SpawnDamageText(pos, amount, isCrit, isMiss, isMegaCrit)
	-- Same spatial stacking logic as algae
	local gridSize = 6
	local gridPos = Vector3.new(math.floor(pos.X/gridSize), math.floor(pos.Y/gridSize), math.floor(pos.Z/gridSize))
	local stackHeight = recentSpawns[gridPos] or 0
	recentSpawns[gridPos] = stackHeight + 1
	
	task.delay(0.5, function()
		if recentSpawns[gridPos] then
			local newVal = recentSpawns[gridPos] - 1
			if newVal <= 0 then
				recentSpawns[gridPos] = nil
			else
				recentSpawns[gridPos] = newVal
			end
		end
	end)

	local offset = Vector3.new(math.random(-5, 5)/20, stackHeight * 1.6, math.random(-5, 5)/20)
	local finalPos = pos + offset

	if isMegaCrit then
		finalPos = finalPos + Vector3.new(0, 2, 0)
	end
	
	if #ActiveTexts > 200 then
		local old = table.remove(ActiveTexts, 1)
		if old and old.Attachment then old.Attachment:Destroy() end
		if old and old.Label then old.Label:Destroy() end
	end

	local att = Instance.new("Attachment")
	att.Position = finalPos
	att.Parent = workspace.Terrain
	
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 100, 0, 50)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = att
	bb.Parent = att
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	
	local useAbbr = localData and localData.Settings and localData.Settings.AbbreviateAlgae
	local color = Color3.fromRGB(255, 255, 255)
	
	if isMiss then
		label.Text = "MISS"
		color = Color3.fromRGB(200, 200, 200)
		label.TextStrokeColor3 = Color3.fromRGB(100, 100, 100)
	else
		label.Text = FormatNumber(amount, useAbbr)
		if isMegaCrit then
			color = Color3.fromRGB(255, 0, 255)
		elseif isCrit then
			color = Color3.fromRGB(255, 50, 50)
		end
	end
	
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = bb
	
	local baseScale = 0.8
	local amountScale = 1
	if not isMiss then
		amountScale = math.clamp(0.57 + math.log10(amount) * 0.2, 0.57, 2.5)
	end
	
	if isCrit then
		amountScale = amountScale * 1.5
	end
	
	if isMegaCrit then
		amountScale = amountScale * 2.5
		label.Rotation = math.random(-15, 15)
	end

	local targetSize = UDim2.new(baseScale * amountScale, 0, baseScale * amountScale, 0)
	
	label.Size = UDim2.new(0,0,0,0)
	label:TweenSize(targetSize, Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.4, true)
	
	table.insert(ActiveTexts, {
		Attachment = att,
		Label = label,
		Start = os.clock(),
		BasePos = finalPos,
		Duration = isCrit and 1.5 or 1.0,
		IsCrit = isCrit,
		IsMegaCrit = isMegaCrit,
		Amount = amount,
		Color = color
	})
end

-- Listener for specific VFX events (Particles, etc.)
local VFXReplication = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("VFXReplication")
VFXReplication.OnClientEvent:Connect(function(effectName, player, fishIndex, arg4, arg5, arg6)
	-- Find the fish model (Supports Remote and Local) if applicable
	local fishName = nil
	local fishModel = nil
	if player and fishIndex then
		fishName = "Fish_" .. player.UserId .. "_" .. tostring(fishIndex)
		fishModel = workspace:FindFirstChild(fishName)
	end
	-- Note: TropicalGust might rely on position only, fishModel is optional context
	
	if effectName == "Obsession" then
		if not fishModel or not fishModel.PrimaryPart then return end
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		local obsessionVFX = vfxFolder.Obsession.Explode.Attachment
		
		if obsessionVFX then
			local clone = obsessionVFX:Clone()

			
			
			-- Handle Attachment vs Part/Model
			if clone:IsA("Attachment") then
				clone.Parent = workspace.Terrain
				-- Initial Pos
				clone.WorldPosition = fishModel.PrimaryPart.Position
				clone.WorldOrientation = Vector3.new(0, 0, 0) -- Force Upright
				
				-- Follow Loop
				local RunService = game:GetService("RunService")
				local connection
				connection = RunService.Heartbeat:Connect(function()
					if not clone or not clone.Parent then
						if connection then connection:Disconnect() end
						return
					end
					if fishModel and fishModel.PrimaryPart then
						clone.WorldPosition = fishModel.PrimaryPart.Position
						-- Maintain Orientation
						clone.WorldOrientation = Vector3.new(0, 0, 0)
					else
						-- Fish gone, destroy vfx? or let it expire
						if connection then connection:Disconnect() end
						clone:Destroy()
					end
				end)
			else
				clone.Parent = workspace
				if clone:IsA("BasePart") then
					clone.CFrame = CFrame.new(fishModel.PrimaryPart.Position)
				elseif clone:IsA("Model") then
					clone:PivotTo(CFrame.new(fishModel.PrimaryPart.Position))
				end
			end
			
			-- Emit Particles
			for _, child in ipairs(clone:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					local count = child:GetAttribute("EmitCount") or 50
					child:Emit(count)
					task.delay(1, function() child.Enabled = false end) -- Turn off after 1s to prevent infinite loop if Rate > 0
				end
			end
			
			-- Cleanup

			local sfx = vfxFolder.Obsession.ObsessionSFX:Clone()
			sfx.Parent = clone
			local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
			if not isSfxDisabled then sfx:Play() end
			
			-- Apply Override if force override is set (arg4 matches vfxOverride structure)
			if type(arg4) == "table" and arg4.ForceOverride then
				ApplyOverride(clone, arg4)
			end

			game:GetService("Debris"):AddItem(sfx, 5)
			game.Debris:AddItem(clone, 5)
		end
	elseif effectName == "Infect" then
		if not fishModel or not fishModel.PrimaryPart then return end
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		
		-- Safely navigate path: VFX.Infect.VFXInfect.Burst1
		local infectFolder = vfxFolder and vfxFolder:FindFirstChild("Infect")
		local subFolder = infectFolder and infectFolder:FindFirstChild("VFXInfect")
		local burst = subFolder and subFolder:FindFirstChild("Burst1")
		
		if burst then
			local clone = burst:Clone()
			
			-- Handle Attachment vs Part/Model (Obsession Logic)
			if clone:IsA("Attachment") then
				clone.Parent = workspace.Terrain
				clone.WorldPosition = fishModel.PrimaryPart.Position
				clone.WorldOrientation = Vector3.new(0, 0, 0)
				
				-- Follow Loop
				local RunService = game:GetService("RunService")
				local connection
				connection = RunService.Heartbeat:Connect(function()
					if not clone or not clone.Parent then
						if connection then connection:Disconnect() end
						return
					end
					if fishModel and fishModel.PrimaryPart then
						clone.WorldPosition = fishModel.PrimaryPart.Position
						clone.WorldOrientation = Vector3.new(0, 0, 0)
					else
						if connection then connection:Disconnect() end
						clone:Destroy()
					end
				end)
			else
				clone.Parent = workspace
				if clone:IsA("BasePart") then
					clone.CFrame = CFrame.new(fishModel.PrimaryPart.Position)
				elseif clone:IsA("Model") then
					clone:PivotTo(CFrame.new(fishModel.PrimaryPart.Position))
				end
			end
			
			-- Apply Overrides if provided (Infect uses arg4 for vfxOverride)
			if type(arg4) == "table" and arg4.ForceOverride then
				ApplyOverride(clone, arg4)
			end

			-- Emit Particles at Peak (approx 0.5s delay)
			task.delay(0.5, function()
				if not clone or not clone.Parent then return end
				
				-- Sound
				if infectFolder then
					local sfx = infectFolder:FindFirstChild("InfectSFX")
					local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
					if sfx and not isSfxDisabled then
						local s = sfx:Clone()
						s.Parent = clone
						s:Play()
					end
				end
				
				for _, child in ipairs(clone:GetDescendants()) do
					if child:IsA("ParticleEmitter") then
						local count = child:GetAttribute("EmitCount") or 20 -- Default to 20 if logic not set
						child:Emit(count)
						-- task.delay(1, function() child.Enabled = false end) -- Not needed for Emit, but if using Enabled=true it is.
					end
				end
			end)
			
			game.Debris:AddItem(clone, 5)
		end
	elseif effectName == "TropicalGust" then
		-- arg4 = position, arg5 = duration, arg6 = override
		local position = arg4
		local duration = arg5
		local override = arg6
		
		if not position or not duration then return end
		
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		local gustTemplate = vfxFolder and vfxFolder:FindFirstChild("TropicalGust") and vfxFolder.TropicalGust:FindFirstChild("TropicalGust")
		
		if gustTemplate then
			local clone = gustTemplate:Clone()
			clone.Parent = workspace
			local startCF = CFrame.new(position)
			
			if clone:IsA("BasePart") then
				clone.CFrame = startCF
				clone.Anchored = true
				clone.CanCollide = false
			elseif clone:IsA("Model") then
				clone:PivotTo(startCF)
			end
			
			-- Emit initial particle burst if needed, or enable Enabled
			for _, child in ipairs(clone:GetDescendants()) do
				if child:IsA("ParticleEmitter") then
					child.Enabled = true
				end
			end
			
			-- Apply Override
			if override then
				ApplyOverride(clone, override)
			end
			
			-- Setup Beams connecting fish to gust
			local beams = {}
			if fishModel and fishModel.PrimaryPart then
				local gustBeamFolder = vfxFolder and vfxFolder:FindFirstChild("TropicalGust")
				if gustBeamFolder then
					-- Create attachments
					local fishAttachment = Instance.new("Attachment")
					fishAttachment.Name = "GustBeamAttachment"
					fishAttachment.Parent = fishModel.PrimaryPart
					
					local gustAttachment = Instance.new("Attachment")
					gustAttachment.Name = "GustTargetAttachment"
					if clone:IsA("BasePart") then
						gustAttachment.Parent = clone
					elseif clone:IsA("Model") and clone.PrimaryPart then
						gustAttachment.Parent = clone.PrimaryPart
					end
					
					-- Clone all beams from the VFX folder
					for _, child in ipairs(gustBeamFolder:GetChildren()) do
						if child:IsA("Beam") then
							local beamClone = child:Clone()
							beamClone.Attachment0 = fishAttachment
							beamClone.Attachment1 = gustAttachment
							beamClone.Parent = fishAttachment
							table.insert(beams, beamClone)
						end
					end
				end
			end
			
			-- Client-side stationary tornado for duration
			local startTime = os.clock()
			local RunService = game:GetService("RunService")
			local connection
			
			connection = RunService.Heartbeat:Connect(function()
				local elapsed = os.clock() - startTime
				if elapsed >= duration then
					if connection then connection:Disconnect() end
					
                    -- Fade out particles
                    for _, child in ipairs(clone:GetDescendants()) do
                        if child:IsA("ParticleEmitter") then child.Enabled = false end
                    end
                    
                    -- Cleanup beams
                    for _, beam in ipairs(beams) do
                    	if beam and beam.Parent then
                    		beam:Destroy()
                    	end
                    end
                    
					game.Debris:AddItem(clone, 2)
					return
				end
			end)
		end
	elseif effectName == "Dive" then
		-- Existing Dive VFX logic if any (currently handled via same flow or separate?)
		-- If Dive also needs VFX, add here.
		-- Assuming Dive might just be the jump, or has its own particles.
		
	elseif effectName == "SolarFlare" then
		-- arg4 is LogicPart, arg5 is duration
		local logicPart = arg4
		local duration = arg5
		if typeof(logicPart) ~= "Instance" or not logicPart:IsA("BasePart") then return end
		if not duration then duration = 10 end -- Default fallback
		
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		local sunTemplate = vfxFolder and vfxFolder:FindFirstChild("Sun") and vfxFolder.Sun:FindFirstChild("SunVFX")
		
		if sunTemplate then
			local sun = sunTemplate:Clone()
			sun.Parent = workspace
			
			-- Apply Overrides if provided (SolarFlare uses arg6 for vfxOverride)
			if type(arg6) == "table" and arg6.ForceOverride then
				ApplyOverride(sun, arg6)
			end

			local offset = Vector3.new(0, 14, 0)
			local RunService = game:GetService("RunService")
			local startTime = os.clock()
			
			-- Capture Original Stats for proper fade-in
			local originalTrans = sun.Transparency
			local originalStats = {} -- [instance] = value
			
			for _, d in ipairs(sun:GetDescendants()) do
				if d:IsA("Decal") then
					originalStats[d] = d.Transparency
				elseif d:IsA("Light") then
					originalStats[d] = d.Brightness
				elseif d:IsA("Beam") or d:IsA("Trail") then
					originalStats[d] = d.Transparency
				end
			end
			
			-- Initial State (Invisible)
			sun.Transparency = 1
			for _, d in ipairs(sun:GetDescendants()) do
				if d:IsA("ParticleEmitter") then d.Enabled = false end
				if d:IsA("Beam") or d:IsA("Trail") then d.Enabled = false end
				if d:IsA("Decal") then d.Transparency = 1 end
				if d:IsA("Light") then d.Enabled = false end
			end
			
			local fadeInTime = 1
			local fadeOutTime = 1
			local connection
			
			connection = RunService.Heartbeat:Connect(function()
				-- Cleanup if Server Part is gone
				if not logicPart or not logicPart.Parent then
					if connection then connection:Disconnect() end
					-- Quick Fade out or Destroy
					game.Debris:AddItem(sun, 0) 
					return
				end
				
				local elapsed = os.clock() - startTime
				local timeLeft = duration - elapsed
				
				-- 1. Position Sync with Wobble
				local currentPos = logicPart.Position + offset
				
				-- Rise Logic (0 to 1s)
				if elapsed < 1 then
					local riseProgress = TweenService:GetValue(elapsed / 1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local currentOffset = Vector3.new(0,0,0):Lerp(offset, riseProgress)
					currentPos = logicPart.Position + currentOffset
				end
				
				local spin = elapsed * 1
				local wobbleCF = CFrame.Angles(0, spin, 0) * CFrame.Angles(math.sin(elapsed * 3) * 0.1, 0, math.cos(elapsed * 2.5) * 0.1)
				
				sun.CFrame = CFrame.new(currentPos) * wobbleCF
				
				-- 2. Opacity Calculation (Fade In / Out)
				local alpha = 1 -- 1 = Invisible, 0 = Fully Visible
				if elapsed < fadeInTime then
					alpha = 1 - (elapsed / fadeInTime)
				elseif timeLeft < fadeOutTime then
					alpha = 1 - (timeLeft / fadeOutTime)
				else
					alpha = 0
				end
				alpha = math.clamp(alpha, 0, 1)
				
				-- Apply Transparency (Fade from 1 to originalTrans)
				sun.Transparency = alpha + (1 - alpha) * originalTrans
				
				for _, d in ipairs(sun:GetDescendants()) do
					if d:IsA("Decal") then
						local orig = originalStats[d] or 0
						d.Transparency = alpha + (1 - alpha) * orig
					elseif d:IsA("Light") then 
						local orig = originalStats[d] or 1
						d.Enabled = (alpha < 0.95)
						d.Brightness = (1 - alpha) * orig
					end
				end
				
				-- 3. Particles
				local particlesActive = (alpha < 0.8)
				for _, d in ipairs(sun:GetDescendants()) do
					if d:IsA("ParticleEmitter") then
						d.Enabled = particlesActive
					end
				end
				
				-- 4. Beams (Pulse + Original Transparency Support)
				local pulse = 0.5 + 0.5 * math.sin(elapsed * 3)
				local visibilityFactor = 1 - alpha 
				
				for _, d in ipairs(sun:GetDescendants()) do
					if d:IsA("Beam") or d:IsA("Trail") then
						d.Enabled = (visibilityFactor > 0.01)
						local origSeq = originalStats[d]
						if origSeq and typeof(origSeq) == "NumberSequence" then
							local newKps = {}
							for _, kp in ipairs(origSeq.Keypoints) do
								local targetTrans = alpha + (1 - alpha) * kp.Value
								targetTrans = math.clamp(targetTrans + (1 - pulse) * 0.3 * (1-alpha), 0, 1)
								table.insert(newKps, NumberSequenceKeypoint.new(kp.Time, targetTrans, kp.Envelope))
							end
							d.Transparency = NumberSequence.new(newKps)
						else
							d.Transparency = NumberSequence.new(math.clamp(alpha + (1-pulse)*0.5, 0, 1))
						end
					end
				end
			end)
		end
	elseif effectName == "AlgaeMark" then
		-- arg4 = targetPart, arg5 = duration
		local targetPart = arg4
		local duration = arg5
		
		if not targetPart or not duration then return end
		if not targetPart.Parent then return end -- Part destroyed
		
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		local template = vfxFolder and vfxFolder:FindFirstChild("AlgaeMark")
		
		if template then
			-- Check for existing to avoid stacking heavy VFX
			local existing = targetPart:FindFirstChild("AlgaeMarkVFX")
			if existing then 
				-- Just refresh duration if possible? Hard to sync. Destroy old.
				existing:Destroy() 
			end
			
			local clone = template:Clone()
			clone.Name = "AlgaeMarkVFX"
			clone.Parent = targetPart
			
			-- Start invisible
			local beams = {}
			local originalSequences = {}
			
			for _, desc in ipairs(clone:GetDescendants()) do
				if desc:IsA("Beam") then
					table.insert(beams, desc)
					originalSequences[desc] = desc.Transparency
					desc.Transparency = NumberSequence.new(1)
				end
			end
			
			if #beams == 0 then return end
			
			local startTime = os.clock()
			local RunService = game:GetService("RunService")
			local conn
			
			conn = RunService.Heartbeat:Connect(function()
				if not clone or not clone.Parent or not targetPart or not targetPart.Parent then 
					if conn then conn:Disconnect() end
					if clone and clone.Parent then clone:Destroy() end
					return 
				end
				
				local elapsed = os.clock() - startTime
				if elapsed > duration then
					if conn then conn:Disconnect() end
					clone:Destroy()
					return
				end
				
				-- Fade Logic
				local fadeInDur = 0.5 -- Faster fade in for client responsiveness
				local fadeOutDur = 1
				local alpha = 1 
				
				if elapsed < fadeInDur then
					alpha = elapsed / fadeInDur
				elseif elapsed > (duration - fadeOutDur) then
					alpha = (duration - elapsed) / fadeOutDur
				end
				
				alpha = math.clamp(alpha, 0, 1)
				local transpMult = 1 - alpha 
				
				for _, beam in ipairs(beams) do
					local orig = originalSequences[beam]
					local newKPs = {}
					for _, kp in ipairs(orig.Keypoints) do
						local newT = kp.Value + (1 - kp.Value) * transpMult
						table.insert(newKPs, NumberSequenceKeypoint.new(kp.Time, newT, kp.Envelope))
					end
					beam.Transparency = NumberSequence.new(newKPs)
				end
			end)
		end
		
	elseif effectName == "AlgaeMarkPlus" then
		-- Glow+ upgrade: tint the existing AlgaeMarkVFX beams RED (1.75x mark)
		-- arg4 = targetPart, arg5 = duration
		local targetPart = arg4
		local duration = arg5 or 10
		if not targetPart or not targetPart.Parent then return end
		
		local RED_COLOR = ColorSequence.new(Color3.fromRGB(255, 60, 60))
		
		local function tintRed(vfxInstance)
			for _, desc in ipairs(vfxInstance:GetDescendants()) do
				if desc:IsA("Beam") then
					desc.Color = RED_COLOR
				end
			end
		end
		
		-- Find existing mark VFX and tint it red
		local existing = targetPart:FindFirstChild("AlgaeMarkVFX")
		if existing then
			tintRed(existing)
		else
			-- Race condition: no existing VFX yet — spawn a red one from template
			local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
			local template = vfxFolder and vfxFolder:FindFirstChild("AlgaeMark")
			if template then
				local clone = template:Clone()
				clone.Name = "AlgaeMarkVFX"
				tintRed(clone)
				clone.Parent = targetPart
				game.Debris:AddItem(clone, duration)
			end
		end

	elseif effectName == "SurgingPin" then
		-- Surging Pins passive: expanding neon-pink disc at pin world position
		-- arg4 = pin world position (Vector3)
		local pinPos = arg4
		if typeof(pinPos) ~= "Vector3" then return end
		
		-- Disc 1 — main expanding ring
		local disc = Instance.new("Part")
		disc.Size = Vector3.new(0.5, 0.25, 0.5)
		disc.Anchored = true
		disc.CanCollide = false
		disc.CastShadow = false
		disc.Material = Enum.Material.Neon
		disc.Color = Color3.fromRGB(255, 60, 200)
		disc.Transparency = 0.0
		disc.CFrame = CFrame.new(pinPos - Vector3.new(0, 7, 0))
		disc.Parent = workspace

		-- Play Sound
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		if vfxFolder then
			local sfx = vfxFolder:FindFirstChild("PinSFX")
			if sfx then
				local cloneSFX = sfx:Clone()
				cloneSFX.Parent = disc -- Parent to Part for 3D positional audio
				cloneSFX.PlaybackSpeed = 1.3 -- slightly faster/higher pitched for "pulse"
				cloneSFX:Play()
			end
		end

		TweenService:Create(disc,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(24, 0.25, 24), Transparency = 1 }
		):Play()

		-- Disc 2 — slightly delayed inner bloom for a "double pulse" feel
		task.delay(0.08, function()
			if not disc.Parent then return end
			local bloom = Instance.new("Part")
			bloom.Size = Vector3.new(0.3, 0.25, 0.3)
			bloom.Anchored = true
			bloom.CanCollide = false
			bloom.CastShadow = false
			bloom.Material = Enum.Material.Neon
			bloom.Color = Color3.fromRGB(255, 140, 230)  -- lighter pink inner
			bloom.Transparency = 0.2
			bloom.CFrame = CFrame.new(pinPos - Vector3.new(0, 6.95, 0))
			bloom.Parent = workspace
			TweenService:Create(bloom,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = Vector3.new(18, 0.25, 18), Transparency = 1 }
			):Play()
			game.Debris:AddItem(bloom, 0.85)
		end)

		game.Debris:AddItem(disc, 1.1)

	end
end)

return VisualController
