local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)

local FieldService = {}

local function getFieldFolder(fieldName)
	if not fieldName then return nil end
	local folder = Workspace:FindFirstChild(fieldName)
	if folder then return folder end
	
	local cleanName = string.lower(fieldName):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
	for _, child in ipairs(Workspace:GetChildren()) do
		local childClean = string.lower(child.Name):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
		if childClean == cleanName then
			return child
		end
	end
	return nil
end

-- Store regeneration data: { [Part] = { MaxCapacity = 5, NextRegen = 0 } }
local activeFlowers = {}

local dirtyFlowers = {} -- [Part] = true
local REGEN_INTERVAL = .05 -- 20Hz for smoother visuals
local REGEN_AMOUNT = 2 -- Regen 2 per tick (40 capacity/sec)

-- Token Logic
local TOKEN_SPAWN_INTERVAL = 10 -- seconds

function FieldService.MarkDirty(part)
	dirtyFlowers[part] = true
	part:SetAttribute("LastHarvestTime", os.clock())
end

function FieldService.Consume(part)
	FieldService.MarkDirty(part)
	-- Any additional logic for consumed parts (e.g. effects) can go here
end

function FieldService.ForceRegrow(part, amount)
	local cap = part:FindFirstChild("Capacity")
	local max = part:GetAttribute("MaxCapacity")
	if not cap or not max then return end
	
	if cap.Value < max then
		local oldVal = cap.Value
		cap.Value = math.min(cap.Value + amount, max)
		
		-- Local visual shrinking and fading is handled entirely by FieldController now!
		if oldVal <= 0 and cap.Value > 0 then
			part.CanCollide = false
		end
		
		-- If full, remove from dirty list (stop natural regen)
		if cap.Value >= max then
			dirtyFlowers[part] = nil
		end
	end
end

function FieldService.RegisterField(folder, fieldName)
	local fieldCfg = ResourceConfig.Fields[fieldName]
	local regenDelay = fieldCfg and fieldCfg.RegenDelay or 5
	local regenInterval = fieldCfg and fieldCfg.RegenInterval or 0.1 -- Default fast
	
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			local capacity = child:FindFirstChild("Capacity")
			local algaeAmount = child:FindFirstChild("AlgaeAmount")
			
			if capacity and algaeAmount then
				-- Setup Attributes for Visuals
				if not child:GetAttribute("OriginalSize") then
					child:SetAttribute("OriginalSize", child.Size)
				end
				if not child:GetAttribute("OriginalCFrame") then
					child:SetAttribute("OriginalCFrame", child.CFrame)
				end
				if not child:GetAttribute("MaxCapacity") then
					child:SetAttribute("MaxCapacity", capacity.Value)
				end
				
				-- Track this flower
				activeFlowers[child] = {
					MaxCapacity = capacity.Value,
					RegenDelay = regenDelay,
					RegenInterval = regenInterval,
				}
				game:GetService("CollectionService"):AddTag(child, "AlgaePart")
				
				-- Ensure Physics are correct initially
				child.CanCollide = false
			end
		end
	end
	
	-- Listen for new parts added later? (Optional)
end

-- Infect logic
function FieldService.InfectPart(part, duration, globalMult, specificMults)
	if not part or not part.Parent then return end
	
	-- Defaults
	globalMult = globalMult or 2
	specificMults = specificMults or {}
	
	-- If already infected, maybe extend? For now, simple override if not active
	if part:GetAttribute("InfectionActive") then 
		return 
	end
	
	part:SetAttribute("InfectionActive", true)
	
	if specificMults[part.Name] then
		part:SetAttribute("HarvestMultiplier", specificMults[part.Name])
	else
		part:SetAttribute("HarvestMultiplier", globalMult)
	end
	
	-- Visual Change (Particles) - MOVED TO CLIENT
	-- Optimization: Only replicate the Attribute. Client observes "AlgaePart" tag and "InfectionActive".
	
	-- Spread Logic Schedule
	task.delay(1, function()
		if not part or not part.Parent or not part:GetAttribute("InfectionActive") then return end
		
		-- Calculate next duration
		local nextDuration = duration * 0.6 -- Exponential decay
		if nextDuration < 0.25 then nextDuration = 0.25 end
		
		-- Find neighbors
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Include
		overlapParams.FilterDescendantsInstances = {part.Parent} -- Only same field
		
		local neighbors = workspace:GetPartBoundsInRadius(part.Position, 8, overlapParams) -- ~8 studs for neighbors
		for _, n in ipairs(neighbors) do
			if n ~= part and n:IsA("BasePart") and not n:GetAttribute("InfectionActive") then
				-- Only spread if the new duration allows for meaningful life? 
				-- Logic says "decrease all the way to .25", implying spread continues until then?
				-- Let's just spread!
				FieldService.InfectPart(n, nextDuration, globalMult, specificMults)
			end
		end
	end)
	
	-- Expiry
	task.delay(duration, function()
		if part and part.Parent then
			part:SetAttribute("InfectionActive", nil)
			part:SetAttribute("HarvestMultiplier", nil)
			-- Client cleanup handled via attribute change
		end
	end)
end

function FieldService.Start()
	-- Find all defined fields in Workspace
	for fieldName, _ in pairs(ResourceConfig.Fields) do
		local folder = getFieldFolder(fieldName)
		if folder then
			FieldService.RegisterField(folder, fieldName)
		else
			warn("Field Folder not found in Workspace: " .. fieldName)
		end
	end

	-- Start Regen Loop
	task.spawn(function()
		while true do
			local processQueue = {}
			for part, _ in pairs(dirtyFlowers) do
				table.insert(processQueue, part)
			end
			
			if #processQueue == 0 then
				task.wait(0.5) -- React faster to new damage
			else
				local now = os.clock()
				for _, part in ipairs(processQueue) do
					local data = activeFlowers[part]
					-- Check field-specific delay (Regrow happens RegenDelay seconds AFTER last harvest)
					local lastGather = part:GetAttribute("LastHarvestTime") or 0
					local regenDelay = data and data.RegenDelay or 5
					
					if now - lastGather >= regenDelay then
						if data then
							local nextTick = part:GetAttribute("NextRegenTick") or 0
							if now < nextTick then continue end
							
							local cap = part:FindFirstChild("Capacity")
							if cap and cap.Value < data.MaxCapacity then
								cap.Value = math.min(cap.Value + REGEN_AMOUNT, data.MaxCapacity)
								
								-- Schedule next tick
								part:SetAttribute("NextRegenTick", now + (data.RegenInterval or 0.5))
								
								-- Server does NOT modify transparency, size, or CFrame for SHRINKING anymore, 
								-- but must RESTORE them for logic visibility. (Update: Removed as FieldController handles ALL visual states purely locally, preventing server-client pop-in conflicts)
								
								-- If full, remove from dirty
								if cap.Value >= data.MaxCapacity then
									dirtyFlowers[part] = nil
								end
							else
								dirtyFlowers[part] = nil -- Valid panic removal
							end
						else
							dirtyFlowers[part] = nil
						end
					end
				end
				task.wait(REGEN_INTERVAL)
			end
		end
	end)
	
	-- Start Global Token Spawner
	task.spawn(function()
		while true do
			task.wait(TOKEN_SPAWN_INTERVAL)
			
			-- Collect all eligible fully grown algae parts
			local eligibleParts = {}
			for fieldName, _ in pairs(ResourceConfig.Fields) do
				local folder = getFieldFolder(fieldName)
				if folder then
					for _, child in ipairs(folder:GetChildren()) do
						if child:IsA("BasePart") then
							local capacity = child:FindFirstChild("Capacity")
							local max = child:GetAttribute("MaxCapacity")
							-- Only pick parts that are reasonably alive and don't already have a token
							if capacity and max and capacity.Value >= max * 0.5 and not child:GetAttribute("HasToken") then
								table.insert(eligibleParts, child)
							end
						end
					end
				end
			end
			
			if #eligibleParts > 0 then
				local chosenPart = eligibleParts[math.random(1, #eligibleParts)]
				chosenPart:SetAttribute("HasToken", true)
				
				-- Add Visual Debris
				local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
				local tokenDebris = vfxFolder and vfxFolder:FindFirstChild("Token") and vfxFolder.Token:FindFirstChild("Debris")
				if tokenDebris and tokenDebris:IsA("ParticleEmitter") then
					local debrisClone = tokenDebris:Clone()
					debrisClone.Name = "TokenDebrisVFX"
					debrisClone.Parent = chosenPart
					-- Make sure it's emitting
					debrisClone.Enabled = true
				end
				print("A token has spawned in " .. (chosenPart.Parent and chosenPart.Parent.Name or "the ocean") .. "!")
				
				-- 120s Lifetime for unharvested tokens
				task.delay(120, function()
					if chosenPart and chosenPart.Parent and chosenPart:GetAttribute("HasToken") then
						chosenPart:SetAttribute("HasToken", nil)
						local debrisVfx = chosenPart:FindFirstChild("TokenDebrisVFX")
						if debrisVfx then
							-- Disable emission and let remaining particles fade
							if debrisVfx:IsA("ParticleEmitter") then
								debrisVfx.Enabled = false
								game.Debris:AddItem(debrisVfx, 2)
							else
								debrisVfx:Destroy()
							end
						end
					end
				end)
			end
		end
	end)
end

return FieldService
