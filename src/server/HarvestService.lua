local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
local ToolConfig = require(ReplicatedStorage.Shared.ToolConfig)

local SecurityService = require(script.Parent.SecurityService)
local FishService = require(script.Parent.FishService)
local MobService = require(script.Parent.MobService)
local HitboxCache = require(script.Parent.HitboxCache)

local CapacityNotified = {} -- [userId] = clock()
local CAPACITY_NOTIFY_COOLDOWN = 5

local function getFieldFolder(fieldName)
	if not fieldName then return nil end
	
	local folder = workspace:FindFirstChild(fieldName)
	if folder then return folder end
	
	local reefsFolder = workspace:FindFirstChild("Reefs")
	if reefsFolder then
		folder = reefsFolder:FindFirstChild(fieldName)
		if folder then return folder end
	end
	
	local cleanName = string.lower(fieldName):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
	
	for _, child in ipairs(workspace:GetChildren()) do
		local childClean = string.lower(child.Name):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
		if childClean == cleanName then
			return child
		end
	end
	
	if reefsFolder then
		for _, child in ipairs(reefsFolder:GetChildren()) do
			local childClean = string.lower(child.Name):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
			if childClean == cleanName then
				return child
			end
		end
	end
	
	return nil
end

local function GetFieldConfig(fieldName)
	if not fieldName then return nil end
	local cfg = ResourceConfig.Fields[fieldName]
	if cfg then return cfg end
	
	local clean = string.lower(fieldName):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
	for name, data in pairs(ResourceConfig.Fields) do
		local c = string.lower(name):gsub("’", "'"):gsub("'", ""):gsub("%s+", "")
		if c == clean then
			return data
		end
	end
	return nil
end

local function NotifyCapacityFull(player)
	local now = os.clock()
	if not CapacityNotified[player.UserId] or (now - CapacityNotified[player.UserId]) >= CAPACITY_NOTIFY_COOLDOWN then
		CapacityNotified[player.UserId] = now
		local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if Remotes then
			local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
			if NotificationEvent then
				NotificationEvent:FireClient(player, "Your backpack is full! Empty it at your Aquarium.", Color3.fromRGB(255, 50, 50))
			end
		end
	end
end

local function ClearAlgaeMark(targetPart)
	if not targetPart then return end
	targetPart:SetAttribute("AlgaeMarkEnd", 0)
	targetPart:SetAttribute("AlgaeMarkUpgraded", nil)
	local existing = targetPart:FindFirstChild("AlgaeMarkVFX")
	if existing then existing:Destroy() end
end

local function TrackAlgaePerSecond(data, amount)
	local clock = math.floor(os.clock())
	if data._MaxAlgaeSecStamp ~= clock then
		data._MaxAlgaeSecStamp = clock
		data._AlgaeGatheredLastSecond = 0
	end
	data._AlgaeGatheredLastSecond = (data._AlgaeGatheredLastSecond or 0) + amount
	if data._AlgaeGatheredLastSecond > (data.MaxAlgaePerSecond or 0) then
		data.MaxAlgaePerSecond = data._AlgaeGatheredLastSecond
	end
end

local function GetFieldName(part)
	if not part then return nil end
	local p = part.Parent
	while p and p ~= workspace do
		if GetFieldConfig(p.Name) then return p.Name end
		p = p.Parent
	end
	return part.Parent and part.Parent.Name
end

local function ValidateZoneAccess(data, targetPart)
	local fieldName = GetFieldName(targetPart)
	if not fieldName then return true end
	
	local config = GetFieldConfig(fieldName)
	if not config then return true end

	local fishCount = 0
	if data.FishSchool then
		for _ in pairs(data.FishSchool) do fishCount += 1 end
	end
	
	local required = config.FishRequired or 0
	if fishCount < required then
		return false
	end
	
	return true
end



local function GetActiveQuests(data, player)
	local QuestConfig = require(ReplicatedStorage.Shared.QuestConfig)
	if not data or not data.ActiveQuests then return {} end
	
	local quests = {}
	for qId, prog in pairs(data.ActiveQuests) do
		if qId == "NoobieTurtle" then
			local fishCount = 0
			for _ in pairs(data.FishSchool or {}) do fishCount = fishCount + 1 end
			-- Pass existing progress so UpdateNoobieTurtle uses locked field keys
			-- instead of re-deriving from current fishCount (which may have changed mid-quest)
			quests[qId] = {
				Config = QuestConfig.UpdateNoobieTurtle(data.NoobieTurtleQuestsCompleted or 0, fishCount, player.UserId, prog),
				Progress = prog
			}
		elseif qId == "ElderTurtle" then
			local fishCount = 0
			for _ in pairs(data.FishSchool or {}) do fishCount = fishCount + 1 end
			quests[qId] = {
				Config = QuestConfig.UpdateElderTurtle(data.ElderTurtleQuestsCompleted or 0, fishCount, player.UserId, prog),
				Progress = prog
			}
		else
			local c = QuestConfig.Quests[qId]
			if c then
				quests[qId] = { Config = c, Progress = prog }
			end
		end
	end
	
	return quests
end

-- Helper: Get combined algae multipliers for a specific target
local function GetAlgaeMultipliers(data, targetPart, consumeMark)
	if not data or not data.Stats or not targetPart then return 1 end
	
	local baseBoost = (data.Stats.BaseAlgae or 0)
	local percentBoost = (data.Stats.PercentAlgae or 0)
	
	-- Global Item Timers
	if data.Stats.FertilizerEnd and data.Stats.FertilizerEnd > os.time() then
		percentBoost = percentBoost + 1.0 -- +100%
	end
	
	local rType = targetPart.Name
	if rType == "PinkAlgae" then 
		baseBoost = baseBoost + (data.Stats.BasePinkAlgae or 0)
		percentBoost = percentBoost + (data.Stats.PercentPinkAlgae or 0)
	elseif rType == "OrangeAlgae" then 
		baseBoost = baseBoost + (data.Stats.BaseOrangeAlgae or 0)
		percentBoost = percentBoost + (data.Stats.PercentOrangeAlgae or 0)
	elseif rType == "GreenAlgae" then 
		baseBoost = baseBoost + (data.Stats.BaseGreenAlgae or 0)
		percentBoost = percentBoost + (data.Stats.PercentGreenAlgae or 0)
	elseif rType == "MysticAlgae" then
		baseBoost = baseBoost + (data.Stats.BaseMysticAlgae or 0) + (data.Stats.BaseGreenAlgae or 0) + (data.Stats.BasePinkAlgae or 0) + (data.Stats.BaseOrangeAlgae or 0)
		percentBoost = percentBoost + (data.Stats.PercentMysticAlgae or 0) + (data.Stats.PercentGreenAlgae or 0) + (data.Stats.PercentPinkAlgae or 0) + (data.Stats.PercentOrangeAlgae or 0)
	end
	
	local markMult = 1.0
	if (targetPart:GetAttribute("AlgaeMarkEnd") or 0) > os.time() then
		-- Use attribute for dynamic multiplier (from Glow or Trail) or fallback to defaults
		local dynamicMult = targetPart:GetAttribute("AlgaeMarkMultiplier")
		if dynamicMult then
			markMult = dynamicMult
		else
			-- Legacy fallback behavior
			markMult = (rType == "OrangeAlgae" and 1.5 or 1.1)
		end
		
		if consumeMark then ClearAlgaeMark(targetPart) end
	end
	
	local infectMult = targetPart:GetAttribute("HarvestMultiplier") or 1
	
	local reefMult = 1
	local fieldName = GetFieldName(targetPart)
	if fieldName and data.ActiveReefBoosts and data.ActiveReefBoosts[fieldName] then
		if os.time() < data.ActiveReefBoosts[fieldName].ExpiresAt then
			reefMult = data.ActiveReefBoosts[fieldName].Multiplier
		end
	end
	
	return (1 + baseBoost + percentBoost) * markMult * infectMult * reefMult
end

-- Helper: Get total critical power including bonuses
local function GetCritPower(data)
	if not data or not data.Stats then return 3.0 end
	local baseCritPower = data.Stats.CriticalPower or 3.0
	local critPowerBonus = 1 + (data.Stats.CritPowerBonus or 0)
	return baseCritPower * critPowerBonus
end

-- Standard Critical Hit Roll
local function RollPRD(data, chance, key)
	if chance >= 1 then return true end
	if chance <= 0 then return false end
	
	if not data.Session then data.Session = {} end
	if not data.Session.PRD then data.Session.PRD = {} end
	
	local src, lne = debug.info(2, "sl")
	key = key or (tostring(src) .. ":" .. tostring(lne))
	
	local accumulated = (data.Session.PRD[key] or 0) + chance
	
	if accumulated >= 1 then
		data.Session.PRD[key] = accumulated - 1
		return true
	elseif math.random() < accumulated then
		data.Session.PRD[key] = 0
		return true
	end
	
	data.Session.PRD[key] = accumulated
	return false
end

-- True Random Unified BSS Table Spinner
local function PercentageRandomizing(LootTable)
	if LootTable then
		local Total_Percentage = 0
		for _, total_percent in pairs(LootTable) do
			Total_Percentage += total_percent
		end
		
		-- Floating point drift accommodation 
		if math.abs(Total_Percentage - 100) <= 0.001 then
			local WeightedLootTable = {}
			local WeightedMultiplys = 1

			for _, percentage in pairs(LootTable) do
				if percentage > 0 and percentage < 1 then
					local TotalMultiplied = 0
					local temp = percentage
					for i = 0, 10 do
						if temp > 0 and temp < 1 then
							temp *= 10
							TotalMultiplied += 1
						end
					end
					if TotalMultiplied > WeightedMultiplys then
						WeightedMultiplys = TotalMultiplied
					end
				end
			end

			for item, percentage in pairs(LootTable) do
				local WeightedPercentage = percentage
				for i = 0, WeightedMultiplys do
					WeightedPercentage *= 10
				end
				WeightedLootTable[item] = WeightedPercentage
			end
			
			local Smallest_Percent = math.huge
			for _, percentage in pairs(WeightedLootTable) do
				if percentage > 0 and percentage < Smallest_Percent then
					Smallest_Percent = percentage
				end
			end
			
			if Smallest_Percent > 10 then
				for item, percentage in pairs(WeightedLootTable) do
					WeightedLootTable[item] = percentage / 10
				end
			end
			
			local sum = 0
			for k, v in pairs(WeightedLootTable) do
				sum = sum + v
			end

			local r = math.random() * sum
			for k, v in pairs(WeightedLootTable) do
				r = r - v
				if r <= 0 then
					return k
				end
			end
		else
			warn("Randomizing Total Percentage must be precisely 100! Got: " .. Total_Percentage)
		end
	else
		warn("Randomizing requires a loot table!")
	end
	return "Normal"
end

local HarvestService = {}
HarvestService.RollPRD = RollPRD

-- Unified Export for True Random Pie Chart Crits Contexts (Abilities, Tokens, Field, etc)
function HarvestService.RollCriticalOutcome(data, forcedCrit)
	local critResult = "Normal"
	if forcedCrit ~= nil then
		critResult = forcedCrit and "Critical" or "Normal"
	else
		local rawCrit = (data.Stats.CriticalChance or 0.01) + (data.Stats.CritChanceBonus or 0)
		local rawMega = data.Stats.MegaCritChance or 0.01
		
		local critPct = rawCrit * 100
		local megaPct = rawMega * 100
		
		if critPct > 100 then
			local overCrit = critPct - 100
			critPct = 100
			megaPct = megaPct + overCrit
		end
		
		local trueMegaPct = critPct * (math.min(100, tonumber(megaPct) or 0) / 100)
		local trueCritPct = critPct - trueMegaPct
		local normalPct = math.max(0, 100 - (trueCritPct + trueMegaPct))
		
		critResult = PercentageRandomizing({
			["Normal"] = normalPct,
			["Critical"] = trueCritPct,
			["MegaCritical"] = trueMegaPct
		})
	end
	return critResult
end

-- Export the math standard multiplier values for the respective outcomes
function HarvestService.GetCritMultiplier(data, critResult)
	if critResult == "MegaCritical" then
		return data.Stats.MegaCritPower or 10.0
	elseif critResult == "Critical" then
		local baseCritPower = data.Stats.CriticalPower or 3.0
		local critPowerBonus = 1 + (data.Stats.CritPowerBonus or 0)
		return baseCritPower * critPowerBonus
	end
	return 1.0
end

-- Setup RemoteEvent
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local HarvestEvent = Remotes:FindFirstChild("HarvestEvent")
if not HarvestEvent then
	HarvestEvent = Instance.new("RemoteEvent")
	HarvestEvent.Name = "HarvestEvent"
	HarvestEvent.Parent = Remotes
end

local VisualEvent = Remotes:FindFirstChild("VisualEvent")
if not VisualEvent then
	VisualEvent = Instance.new("RemoteEvent")
	VisualEvent.Name = "VisualEvent"
	VisualEvent.Parent = Remotes
end

local VFXReplication = Remotes:FindFirstChild("VFXReplication")
if not VFXReplication then
	VFXReplication = Instance.new("RemoteEvent")
	VFXReplication.Name = "VFXReplication"
	VFXReplication.Parent = Remotes
end

-- Batch System for Visual Feedback (like Bee Swarm Simulator)
-- PlayerBatches[userId] = { Position = Vector3, Amount = number, Color = Color3, IsCrit = bool, LastUpdate = clock, Scheduled = bool }
local PlayerBatches = {}
local PlayerBiomassBatches = {} -- Separate batch tracker for instant conversion
local BATCH_WINDOW = 0.05 -- 50ms window to accumulate harvests into one visual

local function FlushBatch(player, userId)
	local batch = PlayerBatches[userId]
	if not batch or batch.Amount == 0 then return end
	
	-- Fire the accumulated visual
	VisualEvent:FireClient(player, batch.Position, batch.Amount, batch.Color, batch.IsCrit, false, nil, nil, nil, batch.IsMegaCrit)
	
	-- Clear batch
	PlayerBatches[userId] = nil
end

local function FlushBiomassBatch(player, userId)
	local batch = PlayerBiomassBatches[userId]
	if not batch or batch.Amount == 0 then return end
	
	-- Fire the accumulated biomass visual (5th param = isBiomass=true)
	VisualEvent:FireClient(player, batch.Position, batch.Amount, Color3.fromRGB(255, 255, 255), false, true)
	
	-- Clear batch
	PlayerBiomassBatches[userId] = nil
end

local function AddToBatch(player, position, amount, color, isCrit, isMegaCrit)
	local userId = player.UserId
	local now = os.clock()
	
	-- Check if there's an active batch
	local batch = PlayerBatches[userId]
	
	if batch and (now - batch.LastUpdate) <= BATCH_WINDOW then
		-- Add to existing batch
		batch.Amount += amount
		batch.LastUpdate = now
		-- If crit was ever true in this batch, keep it
		if isCrit then batch.IsCrit = true end
		if isMegaCrit then batch.IsMegaCrit = true end
	else
		-- Flush old batch if it exists
		if batch then
			FlushBatch(player, userId)
		end
		
		-- Create new batch
		PlayerBatches[userId] = {
			Position = position,
			Amount = amount,
			Color = color,
			IsCrit = isCrit,
			IsMegaCrit = isMegaCrit, -- Track Mega Crit
			LastUpdate = now,
			Scheduled = false
		}
		
		batch = PlayerBatches[userId]
	end
	
	-- Schedule flush if not already scheduled
	if not batch.Scheduled then
		batch.Scheduled = true
		task.delay(BATCH_WINDOW, function()
			if PlayerBatches[userId] == batch then
				FlushBatch(player, userId)
			end
		end)
	end
end

local function AddToBiomassBatch(player, position, amount)
	local userId = player.UserId
	local now = os.clock()
	
	-- Check if there's an active biomass batch
	local batch = PlayerBiomassBatches[userId]
	
	if batch and (now - batch.LastUpdate) <= BATCH_WINDOW then
		-- Add to existing batch
		batch.Amount += amount
		batch.LastUpdate = now
		-- Position stays at first conversion of batch
	else
		-- Flush old batch if it exists
		if batch then
			FlushBiomassBatch(player, userId)
		end
		
		-- Create new batch (offset below algae position to prevent overlap)
		PlayerBiomassBatches[userId] = {
			Position = position + Vector3.new(0, -2.5, 0),
			Amount = amount,
			LastUpdate = now,
			Scheduled = false
		}
		
		batch = PlayerBiomassBatches[userId]
	end
	
	-- Schedule flush if not already scheduled
	if not batch.Scheduled then
		batch.Scheduled = true
		task.delay(BATCH_WINDOW, function()
			if PlayerBiomassBatches[userId] == batch then
				FlushBiomassBatch(player, userId)
			end
		end)
	end
end



local function ApplyInstantConversion(player, data, yield, position, skipVisual, bonusRate)
	local convertedBiomass = 0
	local algaeToConvert = 0
	local convRate = (data.Stats.InstantConversion or 0) + (bonusRate or 0)

	if convRate > 0 and yield > 0 then
		-- Hard stop: never convert when the backpack is at or above MaxCapacity.
		-- data.MaxCapacity already includes all artifact/backpack bonuses, so no
		-- extra multiplier should be applied here (it caused over-conversion when full).
		local totalPlankton = 0
		if data.Plankton then
			for _, v in pairs(data.Plankton) do totalPlankton += v end
		end

		if totalPlankton >= (data.MaxCapacity or 200) then
			return yield, 0  -- backpack full — no instant conversion
		end

		local availableSpace = math.max(0, (data.MaxCapacity or 200) - totalPlankton)

		-- Cap convertible amount to what would actually fit
		local convertibleYield = math.min(yield, availableSpace)

		if convertibleYield > 0 then
			-- Use probabilistic rounding for small yields
			algaeToConvert = math.floor(convertibleYield * convRate + math.random())

			if algaeToConvert > 0 then
				-- Biomass from instant conversion equals algae converted (ignores multipliers)
				convertedBiomass = algaeToConvert

				data.Biomass = (data.Biomass or 0) + convertedBiomass

				-- Update Leaderboard
				local ls = player:FindFirstChild("leaderstats")
				if ls then
					local bio = ls:FindFirstChild("Biomass")
					if bio then bio.Value = data.Biomass end
				end

				-- Add to biomass batch (Visuals)
				if position and (not skipVisual or yield > 10) then
					AddToBiomassBatch(player, position, convertedBiomass)
				end

				-- Subtract from yield
				yield = math.max(0, yield - algaeToConvert)
			end
		end
	end
	return yield, convertedBiomass
end

-- ... (Remotes setup unchanged)

-- Removing global constants slightly in favor of dynamic config? 
-- Or keeping as defaults.
local HARVEST_DISTANCE = 25 
local BASE_COOLDOWN = 1

local playerCooldowns = {}

local function ApplyAlgaeMark(targetPart, duration, multiplier)
	-- Check if already marked
	if (targetPart:GetAttribute("AlgaeMarkEnd") or 0) > os.time() then return end

	-- Logic: Set Attribute for logic
	local endTime = os.time() + duration
	targetPart:SetAttribute("AlgaeMarkEnd", endTime)
	if multiplier then
		targetPart:SetAttribute("AlgaeMarkMultiplier", multiplier)
	end
	
	-- Visuals: Trigger Client Side (Optimized)
	-- We use VFXReplication with a new "AlgaeMark" type
	-- Args correspond to handling in VisualController: effectName, player(nil), fishIndex(nil), targetPart, duration
	VFXReplication:FireAllClients("AlgaeMark", nil, nil, targetPart, duration)
end

local function TriggerPassive(player, fishIndex, fishConfig, centerPart)
	local passives = fishConfig.Passives or (fishConfig.Passive and {fishConfig.Passive})
	if not passives then return end
	
	local AbilityService: any = require(script.Parent.AbilityService)
	
	for _, passiveName in ipairs(passives) do
		local passiveData = FishConfig.Passives[passiveName]
		if not passiveData then continue end

		-- Trigger XP Gain (+5 for Passive)
		FishService.AddXPToData(PlayerData.get(player), fishIndex, 5, player)
		
		AbilityService.IncrementAbilitiesCommitted(player)
		
		if passiveName == "Glow" then
			-- Mark nearby algae
			local radius = passiveData.Radius or 24
			local duration = passiveData.Duration or 10
			local centerPos = centerPart.Position
			
			-- Optimization: Search in same parent folder (Field)
			local field = centerPart.Parent
			if field then
				for _, part in ipairs(field:GetDescendants()) do
					if part:IsA("BasePart") and part:FindFirstChild("Capacity") then
						if (part.Position - centerPos).Magnitude <= radius then
							ApplyAlgaeMark(part, duration)
						end
					end
				end
			end
		elseif passiveName == "Mitosis" then
			AbilityService.SpawnMitosisClone(player)
		elseif passiveName == "Glow+" then
			-- Like Glow, but upgrading already-marked algae to 1.75x (red mark)
			local radius = passiveData.Radius or 24
			local duration = passiveData.Duration or 10
			local normalMult = passiveData.Multiplier or 1.1
			local upgradedMult = passiveData.UpgradedMultiplier or 1.75
			local centerPos = centerPart.Position
			
			local field = centerPart.Parent
			if field then
				for _, part in ipairs(field:GetDescendants()) do
					if part:IsA("BasePart") and part:FindFirstChild("Capacity") then
						if (part.Position - centerPos).Magnitude <= radius then
							if (part:GetAttribute("AlgaeMarkEnd") or 0) > os.time() then
								-- Already marked — upgrade to red 1.75x mark
								local endTime = os.time() + duration
								part:SetAttribute("AlgaeMarkEnd", endTime)
								part:SetAttribute("AlgaeMarkMultiplier", upgradedMult)
								part:SetAttribute("AlgaeMarkUpgraded", true)
								VFXReplication:FireAllClients("AlgaeMarkPlus", nil, nil, part, duration)
							else
								-- Not marked — apply normal 1.1x mark
								ApplyAlgaeMark(part, duration, normalMult)
							end
						end
					end
				end
			end
		elseif passiveName == "Mitosis" then
			AbilityService.SpawnMitosisClone(player)
		end
	end
end

local function UpdateQuestGoal(progress, goals, key, yield)
	if goals[key] then
		local current = progress[key] or 0
		local limit = goals[key]
		local nxt = current + yield
		if nxt > limit then nxt = limit end
		progress[key] = nxt
	end
end

-- Helper: Process Logic inside Data Update scope to enable batching
local function ProcessHarvestData(player, data, targetPart, unitValue, actualBurn, skipVisual, forcedCrit)
	if not ValidateZoneAccess(data, targetPart) then return nil end
	
	local current = data.Plankton[targetPart.Name] or 0
	
	local totalPlankton = 0
	for _, count in pairs(data.Plankton) do totalPlankton += count end
	
	local bagIsFull = false
	if totalPlankton >= data.MaxCapacity then 
		bagIsFull = true
		NotifyCapacityFull(player)
	end
	
	-- Multipliers
	local totalMult = GetAlgaeMultipliers(data, targetPart, true)
	local toolMult = data.Stats.ToolAlgae or 1.0
	
	local finalAmount = math.floor((unitValue * actualBurn) * totalMult * toolMult + 0.5)
	if finalAmount < 1 then finalAmount = 1 end

	-- Critical Hit
	local isCrit = false
	local isMegaCrit = false
	local overCrit = 0
	local critResult = "Normal"
	
	if forcedCrit ~= nil then
		if type(forcedCrit) == "string" then
			critResult = forcedCrit
		else
			critResult = forcedCrit and "Critical" or "Normal"
		end
	else
		local rawCrit = (data.Stats.CriticalChance or 0.01) + (data.Stats.CritChanceBonus or 0)
		local rawMega = data.Stats.MegaCritChance or 0.01
		
		local critPct = rawCrit * 100
		local megaPct = rawMega * 100
		
		-- BSS Mechanics: Any standard crit chance over 100% gracefully spills over directly into Mega Crit chance natively!
		if critPct > 100 then
			overCrit = critPct - 100
			critPct = 100
			megaPct = megaPct + overCrit
		end
		
		-- Mega Crits 'convert' Crits natively, meaning they physically multiply the Crit volume pie chart slice!
		local trueMegaPct = critPct * (math.min(100, tonumber(megaPct) or 0) / 100)
		local trueCritPct = critPct - trueMegaPct
		
		local normalPct = 100 - (trueCritPct + trueMegaPct)
		if normalPct < 0 then normalPct = 0 end
		
		critResult = PercentageRandomizing({
			["Normal"] = normalPct,
			["Critical"] = trueCritPct,
			["MegaCritical"] = trueMegaPct
		})
	end
	
	if critResult == "Critical" or critResult == "MegaCritical" then
		if critResult == "MegaCritical" then
			isMegaCrit = true
			local megaPower = data.Stats.MegaCritPower or 10.0
			finalAmount = math.floor(finalAmount * megaPower)
		else
			isCrit = true
			local critPower = GetCritPower(data)
			finalAmount = math.floor(finalAmount * critPower)
		end
	end
	
	-- Strict Clamp: Prevent overfilling!
	if totalPlankton + finalAmount > data.MaxCapacity then
		finalAmount = math.max(0, data.MaxCapacity - totalPlankton)
		if finalAmount <= 0 then
			NotifyCapacityFull(player)
		end
	end

	-- Quest Update (Use gross amount before conversion)
	for questId, qData in pairs(GetActiveQuests(data, player)) do
		local qConfig = qData.Config
		local progress = qData.Progress
		if qConfig then
			local reqMet = true
			if qConfig.RequiredBackpack and data.EquippedBackpack ~= qConfig.RequiredBackpack then reqMet = false end
			
			if reqMet then
				local grossYield = finalAmount -- Amount before conversion
				if qConfig.Goals then
					-- Multi-Goal
					if type(progress) ~= "table" then progress = {} end
					UpdateQuestGoal(progress, qConfig.Goals, targetPart.Name, grossYield)
					
					local fieldName = GetFieldName(targetPart)
					if fieldName then
						UpdateQuestGoal(progress, qConfig.Goals, fieldName .. "_" .. targetPart.Name, grossYield)
						UpdateQuestGoal(progress, qConfig.Goals, fieldName, grossYield)
					end
					data.ActiveQuests[questId] = progress
				else
					-- Single Goal
					if (qConfig.TargetResource == "Any" or qConfig.TargetResource == targetPart.Name) then
						local fieldName = GetFieldName(targetPart)
						if not qConfig.TargetLocation or qConfig.TargetLocation == fieldName then
							local current = tonumber(progress) or 0
							local nxt = current + grossYield
							if nxt > qConfig.GoalAmount then nxt = qConfig.GoalAmount end
							data.ActiveQuests[questId] = nxt
						end
					end
				end
			end
		end
	end

	-- Flag Quests dirty since we loop over and modify them manually inside the data model
	PlayerData.SetDirty(player, "Quests")

	-- Instant Conversion
	local _yield, convertedAmount = ApplyInstantConversion(player, data, finalAmount, targetPart.Position, skipVisual)
	finalAmount = _yield

	data.Plankton[targetPart.Name] = current + finalAmount
	data.LifetimeAlgae = (data.LifetimeAlgae or 0) + finalAmount
	TrackAlgaePerSecond(data, finalAmount)
	
	-- Leaderstats
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local algaeStat = leaderstats:FindFirstChild("Algae")
		if algaeStat then algaeStat.Value = totalPlankton + finalAmount end
	end
	
	-- Visuals
	if not skipVisual then
		local resType = ResourceConfig.Types[targetPart.Name]
		local color = (resType and resType.Color) or Color3.new(1,1,1)
		VisualEvent:FireClient(player, targetPart.Position + Vector3.new(0, 2, 0), finalAmount, color, isCrit, false, nil, nil, nil, isMegaCrit)
	end
	
	return finalAmount, isCrit, convertedAmount, isMegaCrit
end

local function UpdateVisualShrink(targetPart, actualBurn)
	local capacityVal = targetPart:FindFirstChild("Capacity")
	
	-- We still need to ensure MaxCapacity is set for Client logic
	local maxCap = targetPart:GetAttribute("MaxCapacity")
	if not maxCap then
		-- Approximation if server restart happen mid-depletion
		maxCap = capacityVal.Value + actualBurn
		targetPart:SetAttribute("MaxCapacity", maxCap)
	end
	
	if capacityVal.Value <= 0 then
		local FieldService = require(script.Parent.FieldService)
		FieldService.Consume(targetPart)
	end
	-- Visuals are handled by Client via Capacity change detection
end

function HarvestService.ExtractTokens(parts)
	if type(parts) ~= "table" then parts = {parts} end
	for _, part in ipairs(parts) do
		if part and part:IsA("BasePart") and part:GetAttribute("HasToken") then
			part:SetAttribute("HasToken", nil)
			
			local debrisVfx = part:FindFirstChild("TokenDebrisVFX")
			if debrisVfx then debrisVfx:Destroy() end
			
			local reefName = GetFieldName(part) or "the ocean"
			local startPos = part.Position
			
			-- BSS Leaf Effect 1: Sound
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://150829875" -- Placeholder Rustle
			sound.Parent = part
			sound.RollOffMaxDistance = 50
			sound.PlayOnRemove = true
			sound:Destroy()

			-- BSS Leaf Effect 2: Particle Burst
			local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
			local leafBurst = vfxFolder and vfxFolder:FindFirstChild("Token") and vfxFolder.Token:FindFirstChild("LeafBurst")
			if not leafBurst then
				-- Fallback burst
				local att = Instance.new("Attachment")
				att.Position = startPos
				att.Parent = workspace.Terrain
				local emitter = Instance.new("ParticleEmitter")
				emitter.Color = ColorSequence.new(Color3.fromRGB(50, 205, 50))
				emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
				emitter.Lifetime = NumberRange.new(0.5, 1)
				emitter.Speed = NumberRange.new(10, 20)
				emitter.SpreadAngle = Vector2.new(180, 180)
				emitter.Parent = att
				emitter:Emit(15)
				game.Debris:AddItem(att, 2)
			else
				local att = Instance.new("Attachment")
				att.Position = startPos
				att.Parent = workspace.Terrain
				local emitter = leafBurst:Clone()
				emitter.Parent = att
				emitter:Emit(15)
				game.Debris:AddItem(att, 2)
			end
			
			task.defer(function()
				HarvestService.SpawnToken(nil, startPos, reefName)
			end)
		end
	end
end

local function ExecuteHarvestBatch(player, parts, toolStats, skipVisual, consolidateVisuals)
	local burnAmount = toolStats.CapacityBurn or 1
	local requests = {}
	
	-- Separation
	for _, part in ipairs(parts) do
		if part and part.Parent then
			local algaeAmountVal = part:FindFirstChild("AlgaeAmount")
			local capacityVal = part:FindFirstChild("Capacity")
			if algaeAmountVal and capacityVal and capacityVal.Value > 0 then
				local actualBurn = math.min(burnAmount, capacityVal.Value)
				table.insert(requests, {
					Part = part,
					Unit = algaeAmountVal.Value,
					Burn = actualBurn,
					CV = capacityVal
				})
			end
		end
	end
	
	-- Token Extraction (Process tokens FIRST before anything else)
	HarvestService.ExtractTokens(parts)
	
	if #requests == 0 then return end
	
	-- 1. Pre-Check
	local cachedData = PlayerData.get(player)
	if cachedData then
		local total = 0
		if cachedData.Plankton then for _, c in pairs(cachedData.Plankton) do total += c end end
		local capMult = (cachedData.Stats and cachedData.Stats.CapacityMultiplier) or 1.0
		local effectiveMax = math.floor(cachedData.MaxCapacity * capMult)
		if total >= effectiveMax then
			NotifyCapacityFull(player)
			return
		end 
	end

	PlayerData.update(player, function(data)
		local anySuccess = false
		local totalYield = 0
		local totalConv = 0
		local anyCrit = false
		local anyMegaCrit = false
		local batchCenter = Vector3.zero
		local count = 0
		local yieldByType = {}
		
		local innerSkip = skipVisual or consolidateVisuals
		local batchCritResult = HarvestService.RollCriticalOutcome(data, nil)
		
		for _, req in ipairs(requests) do
			local res, resCrit, resConv, resMegaCrit = ProcessHarvestData(player, data, req.Part, req.Unit, req.Burn, innerSkip, batchCritResult)
			if res then 
				req.Success = true
				req.FinalYield = res
				req.GrossYield = res + (resConv or 0)
				anySuccess = true
				if consolidateVisuals then
					totalYield += res
					totalConv += (resConv or 0)
					if resCrit then anyCrit = true end
					if resMegaCrit then anyMegaCrit = true end
					
					local tName = req.Part.Name
					yieldByType[tName] = (yieldByType[tName] or 0) + res
					
					batchCenter += req.Part.Position
					count += 1
				end
			end
		end
		
		if consolidateVisuals and count > 0 then
			local VisualEvent = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("VisualEvent")
			
			-- Fire separate popup for each algae type
			for typeName, amount in pairs(yieldByType) do
				if amount > 0 then
					local typeCenter = Vector3.zero
					local typeCount = 0
					
					for _, req in ipairs(requests) do
						if req.Success and req.Part.Name == typeName then
							typeCenter += req.Part.Position
							typeCount += 1
						end
					end
					
					local finalPos = (typeCount > 0) and (typeCenter / typeCount) or (batchCenter / count)
					local resType = ResourceConfig.Types[typeName]
					local typeColor = (resType and resType.Color) or Color3.fromRGB(255, 215, 0)
					
					VisualEvent:FireClient(player, finalPos + Vector3.new(0, 4, 0), amount, typeColor, anyCrit, nil, nil, nil, true, anyMegaCrit)
				end
			end
			
			-- Biomass Popup (consolidated)
			if totalConv > 0 then
				local avgPos = batchCenter/count
				VisualEvent:FireClient(player, avgPos + Vector3.new(0, 6, 0), totalConv, Color3.fromRGB(255, 255, 255), false, true, nil, nil, true, anyMegaCrit)
			end
		end
		
		if anyCrit then PlayerData.IncrementQuestGoal(player, "Criticals", 1) end
		if anyMegaCrit then PlayerData.IncrementQuestGoal(player, "MegaCriticals", 1) end
		
		if anySuccess then return data end
		return nil
	end)

	local FieldService = require(script.Parent.FieldService)
	local SeaMineService = require(script.Parent.SeaMineService)
	
	-- Shrink + Mark Dirty (Tokens have already been handled)
	local anySuccess = false
	for _, req in ipairs(requests) do
		if req.Success then
			anySuccess = true
			req.CV.Value -= req.Burn
			FieldService.MarkDirty(req.Part)
			UpdateVisualShrink(req.Part, req.Burn)
			if req.GrossYield and req.GrossYield > 0 then
				SeaMineService.AddAlgae(player, req.Part.Position, req.GrossYield)
			end
		end
	end
	
	if anySuccess then
		-- Spawn logic moved exclusively to MobSpawnConfig 120s timer
	end
end

function HarvestService.ApplyAlgaeMark(targetPart, duration, multiplier)
	ApplyAlgaeMark(targetPart, duration, multiplier)
end

function HarvestService.MarkAlgaeArea(position, radius, duration, multiplier)
	local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	local filterFolders = {}
	for fieldName, _ in pairs(ResourceConfig.Fields) do
		local f = getFieldFolder(fieldName)
		if f then table.insert(filterFolders, f) end
	end
	overlapParams.FilterDescendantsInstances = filterFolders

	local parts = workspace:GetPartBoundsInRadius(position, radius, overlapParams)
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then
			ApplyAlgaeMark(part, duration, multiplier)
		end
	end
end

function HarvestService.SpawnToken(player, position, reefName)
	local TokenConfig = require(ReplicatedStorage.Shared.TokenConfig)
	local dropItem = TokenConfig.GetRandomDrop()
	if not dropItem then return end
	
	local startPos = position + Vector3.new(0, 4, 0)
	
	-- Container Part (Guarantees safe Orientation/Position/Touched methods regardless of TokenTemplate type)
	local rootToken = Instance.new("Part")
	rootToken.Name = "DropToken"
	rootToken.Size = Vector3.new(6, 6, 6)
	rootToken.Transparency = 1
	rootToken.Anchored = true
	rootToken.CanCollide = false
	rootToken.Position = startPos
	rootToken.CFrame = CFrame.new(startPos) * CFrame.Angles(0, 0, 0)
	
	local tokenName = string.gsub(dropItem, "%s+", ""):lower()
	local tokensFolder = ReplicatedStorage:FindFirstChild("Tokens")
	local tokenTemplate = nil
	if tokensFolder then
		for _, child in ipairs(tokensFolder:GetChildren()) do
			if string.lower(string.gsub(child.Name, "%s+", "")) == tokenName then
				tokenTemplate = child
				break
			end
		end
	end
	
	local visuals
	if tokenTemplate then
		visuals = tokenTemplate:Clone()
	else
		visuals = Instance.new("Part")
		visuals.Shape = Enum.PartType.Cylinder
		visuals.Size = Vector3.new(1, 4, 4)
		visuals.Color = Color3.fromRGB(255, 235, 150)
		visuals.Material = Enum.Material.Neon
	end
	
	-- Root token starts upright for 3D models
	rootToken.CFrame = CFrame.new(startPos) * CFrame.Angles(0, 0, 0)
	
	visuals.Parent = rootToken
	
	-- Secure weld based on Type
	if visuals:IsA("Model") then
		visuals:PivotTo(rootToken.CFrame)
		for _, child in ipairs(visuals:GetDescendants()) do
			if child:IsA("BasePart") then
				child.Anchored = false
				child.CanCollide = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = rootToken
				weld.Part1 = child
				weld.Parent = rootToken
			end
		end
	elseif visuals:IsA("BasePart") then
		visuals.Anchored = false
		visuals.CanCollide = false
		visuals.CFrame = rootToken.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rootToken
		weld.Part1 = visuals
		weld.Parent = rootToken
	end
	-- Pop in animation setup
	local originalSizes = {}
	originalSizes[rootToken] = rootToken.Size
	rootToken.Size = Vector3.new(0, 0, 0)
	
	for _, child in ipairs(rootToken:GetDescendants()) do
		if child:IsA("BasePart") then
			originalSizes[child] = child.Size
			child.Size = Vector3.new(0, 0, 0)
		end
	end
	
	rootToken.Parent = workspace
	
	-- Tweens on safe root part
	local TweenService = game:GetService("TweenService")
	
	local popInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for part, size in pairs(originalSizes) do
		TweenService:Create(part, popInfo, {Size = size}):Play()
	end
	
	game:GetService("CollectionService"):AddTag(rootToken, "DropToken")
	

	-- Touch logic
	local isCollected = false
	rootToken.Touched:Connect(function(hit)
		if isCollected then return end
		local hitPlayer = game.Players:GetPlayerFromCharacter(hit.Parent)
		if hitPlayer then
			isCollected = true
			
			-- Shrink Animation
			local shrinkInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			TweenService:Create(rootToken, shrinkInfo, {Size = Vector3.new(0, 0, 0)}):Play()
			for _, c in ipairs(rootToken:GetDescendants()) do
				if c:IsA("BasePart") then
					TweenService:Create(c, shrinkInfo, {Size = Vector3.new(0, 0, 0)}):Play()
				end
			end
			
			task.delay(0.3, function()
				if rootToken and rootToken.Parent then rootToken:Destroy() end
			end)
			
			local PlayerData = require(script.Parent.PlayerData)
			local amountGained = 0

			PlayerData.update(hitPlayer, function(data)
				local luckStat = (data.Stats and data.Stats.Luck) or 1.0
				data.TokensGathered = (data.TokensGathered or 0) + 1
				
				if dropItem == "Biomass" then
					local baseBiomass = math.random(100, 1500)
					amountGained = math.floor(baseBiomass * luckStat)
					
					data.Biomass = (data.Biomass or 0) + amountGained
					data.BiomassTokensGathered = (data.BiomassTokensGathered or 0) + 1
				else
					if type(data.Inventory) ~= "table" then data.Inventory = {} end
					-- Luck gives a chance for double drops!
					local copies = math.floor(luckStat)
					local remainder = luckStat - copies
					if math.random() < remainder then copies = copies + 1 end
					if copies < 1 then copies = 1 end
					
					data.Inventory[dropItem] = (data.Inventory[dropItem] or 0) + copies
					
					amountGained = copies
					data._InventoryDirty = true
				end
				return data
			end)
			
			PlayerData.IncrementQuestGoal(hitPlayer, "TokensCollected", 1)
			PlayerData.IncrementQuestGoal(hitPlayer, "TokensCollected_" .. tostring(dropItem), 1)
			
			if dropItem == "Biomass" then
				local ls = hitPlayer:FindFirstChild("leaderstats")
				if ls and ls:FindFirstChild("Biomass") then
					local pData = PlayerData.get(hitPlayer)
					ls.Biomass.Value = pData.Biomass or 0
				end
				local NotificationEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("NotificationEvent")
				if NotificationEvent then
					NotificationEvent:FireClient(hitPlayer, "+" .. amountGained .. " Biomass", Color3.fromRGB(0, 255, 255))
				end
			else
				local ItemAddedEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemAddedEvent")
				ItemAddedEvent:FireClient(hitPlayer, dropItem, amountGained, "Item", 0, 0)
			end
		end
	end)
	
	-- Tween fade out visuals
	task.delay(TokenConfig.TokenDespawnTime - 2, function()
		if rootToken and rootToken.Parent then
			for _, c in ipairs(rootToken:GetDescendants()) do
				if c:IsA("BasePart") and c ~= rootToken then
					TweenService:Create(c, TweenInfo.new(0.5), {Transparency = 0.6}):Play()
				elseif c:IsA("Decal") or c:IsA("Texture") then
					TweenService:Create(c, TweenInfo.new(0.5), {Transparency = 0.6}):Play()
				elseif c:IsA("TextLabel") then
					TweenService:Create(c, TweenInfo.new(0.5), {TextTransparency = 0.6}):Play() 
				end
			end
		end
	end)
	
	game.Debris:AddItem(rootToken, TokenConfig.TokenDespawnTime)
end

local BeatHarvestEvent = Remotes:FindFirstChild("BeatHarvestEvent")
if not BeatHarvestEvent then
	BeatHarvestEvent = Instance.new("RemoteEvent")
	BeatHarvestEvent.Name = "BeatHarvestEvent"
	BeatHarvestEvent.Parent = Remotes
end

BeatHarvestEvent.OnServerEvent:Connect(function(player)
	local MusicConfig = require(ReplicatedStorage.Shared.MusicConfig)
	local override = player:GetAttribute("MusicOverride")
	
	if override ~= MusicConfig["ToTheMoon"] then return end
	
	local char = player.Character
	local root = char and char.PrimaryPart
	if not root then return end
	
	local RADIUS = 25
	local AMOUNT = 1
	local rootPos = root.Position
	
	local candidates = {}
	
	-- Optimization: Only check fields (folders in Workspace with "Field" in name or from Config)
	for fieldName, _ in pairs(ResourceConfig.Fields) do
		local field = getFieldFolder(fieldName)
		if field then
			for _, part in ipairs(field:GetDescendants()) do
				if part:IsA("BasePart") then
					local cap = part:FindFirstChild("Capacity")
					if cap and cap.Value > 0 then
						if (part.Position - rootPos).Magnitude <= RADIUS then
							table.insert(candidates, part)
						end
					end
				end
			end
		end
	end
	
	if #candidates > 0 then
		ExecuteHarvestBatch(player, candidates, {CapacityBurn = AMOUNT}, false, true)
	end
end)

local function ExecuteHarvest(player, targetPartOrBatch, toolStats)
	local PlayerData = require(script.Parent.PlayerData)
	PlayerData.IncrementQuestGoal(player, "Harvests", 1)
	
	if type(targetPartOrBatch) == "table" then
		ExecuteHarvestBatch(player, targetPartOrBatch, toolStats)
	else
		ExecuteHarvestBatch(player, {targetPartOrBatch}, toolStats)
	end
end

-- function HarvestService.HarvestMultipleBatched(player, parts, amount)
-- 	local toolStats = { CapacityBurn = amount or 1 }
-- 	ExecuteHarvestBatch(player, parts, toolStats, false, true)
-- end

function HarvestService.OnHarvest(player, arg)
	if not SecurityService.ValidateRemoteCall(player, "HarvestEvent") then return end
	local character = player.Character
	if not character then return end
	local root = character.PrimaryPart
	if not root then return end
	
	local equippedTool = character:FindFirstChildWhichIsA("Tool")
	local toolName = equippedTool and equippedTool.Name or "Default"
	local toolStats = ToolConfig[toolName] or ToolConfig["Default"]
	
	-- HARD PASS TOKEN EXTRACTION: Unconditionally intercept tokens immediately
	-- (Prevents range checks, cooldowns, and full bag states from stopping the token spawn)
	if type(arg) == "table" then
		HarvestService.ExtractTokens(arg)
	else
		HarvestService.ExtractTokens({arg})
	end
	
	local allowedRange = toolStats.HarvestRadius or HARVEST_DISTANCE
	local activeCooldown = toolStats.Cooldown or BASE_COOLDOWN
	
	local pData = PlayerData.get(player)
	local currentToolSpeed = (pData and pData.Stats and pData.Stats.ToolSpeed) or 1
	

	
	activeCooldown = activeCooldown / currentToolSpeed
	
	local now = os.clock()
	local cdData = playerCooldowns[player.UserId] or { LastTime = 0 }
	
	if type(arg) == "table" then
		-- BATCH MODE
		local validParts = {}
		local maxDist = (toolName == "Sun Staff" or toolName == "SunStaff" or toolName == "Crystiken") and 150 or (allowedRange + 5)
		
		for _, part in ipairs(arg) do
			if part and part:IsA("BasePart") then
				local distXZ = Vector2.new(root.Position.X - part.Position.X, root.Position.Z - part.Position.Z).Magnitude
				if distXZ <= maxDist and math.abs(root.Position.Y - part.Position.Y) < 35 then
					table.insert(validParts, part)
				end
			end
		end
		
		if #validParts == 0 then return end
		
		-- Simple Cooldown check for batch (Permissive for jitter)
		if toolName ~= "Crystiken" then
			if now - cdData.LastTime < (activeCooldown * 0.1) then return end
		end
		
		playerCooldowns[player.UserId] = { LastTime = now, LastPart = nil }
		ExecuteHarvest(player, validParts, toolStats)
	else
		-- SINGLE MODE (with Pattern support)
		local targetPart = arg
		if not targetPart or not targetPart:IsA("BasePart") then return end
		
		-- Start Validation
		local validParent = targetPart.Parent and targetPart.Parent.Name
		if not validParent or not GetFieldConfig(validParent) then return end
		if not ResourceConfig.Types[targetPart.Name] then return end
		
		local maxSingleDist = (toolName == "Sun Staff" or toolName == "SunStaff" or toolName == "Crystiken") and 150 or allowedRange
		local distXZ = Vector2.new(root.Position.X - targetPart.Position.X, root.Position.Z - targetPart.Position.Z).Magnitude
		if distXZ > maxSingleDist or math.abs(root.Position.Y - targetPart.Position.Y) >= 35 then return end
		
		-- Cooldown Logic (Use LastPart optimization for single clicking)
		if cdData.LastPart ~= targetPart and activeCooldown > 0.15 then activeCooldown = 0.15 end
		if now - cdData.LastTime < activeCooldown then return end
		
		playerCooldowns[player.UserId] = { LastTime = now, LastPart = targetPart }
		
		-- Process Pattern
		local pattern = toolStats.Pattern or { {0,0} }
		local targets = {}
		
		if toolStats.HarvestRadius then
			-- Radius-based Collection (Robust for irregular fields)
			local centerPos = targetPart.Position
			local radius = toolStats.HarvestRadius
			local fieldFolder = targetPart.Parent
			
			if fieldFolder then
				for _, p in ipairs(fieldFolder:GetDescendants()) do
					if p:IsA("BasePart") then
						local cap = p:FindFirstChild("Capacity")
						local aa = p:FindFirstChild("AlgaeAmount")
						-- Only collect valid resources
						if cap and aa and cap.Value > 0 then
							if (p.Position - centerPos).Magnitude <= radius then
								table.insert(targets, p)
							end
						end
					end
				end
			end
		else
			-- Grid Pattern Collection
			local centerPos = targetPart.Position
			local playerCF = root.CFrame
			local playerLookRaw = playerCF.LookVector * Vector3.new(1, 0, 1)
			if playerLookRaw.Magnitude > 0 then
				playerLookRaw = playerLookRaw.Unit
			else
				playerLookRaw = Vector3.new(0, 0, -1)
			end
			
			-- Get local horizontal axes of targetPart (projected onto XZ plane)
			local partLook = targetPart.CFrame.LookVector * Vector3.new(1, 0, 1)
			if partLook.Magnitude > 0 then partLook = partLook.Unit else partLook = Vector3.new(0, 0, -1) end
			
			local partRight = targetPart.CFrame.RightVector * Vector3.new(1, 0, 1)
			if partRight.Magnitude > 0 then partRight = partRight.Unit else partRight = Vector3.new(1, 0, 0) end
			
			-- Project player look onto the part's local axes to find the closest local direction
			local dotLook = playerLookRaw:Dot(partLook)
			local dotRight = playerLookRaw:Dot(partRight)
			
			local playerLook
			if math.abs(dotLook) > math.abs(dotRight) then
				playerLook = partLook * math.sign(dotLook)
			else
				playerLook = partRight * math.sign(dotRight)
			end
			local playerRight = playerLook:Cross(Vector3.new(0, 1, 0))
			
			for _, offset in ipairs(pattern) do
				local ox, oz = offset[1], offset[2]
				if ox == 0 and oz == 0 then
					if not table.find(targets, targetPart) then
						table.insert(targets, targetPart)
					end
				else
					local size = targetPart:GetAttribute("OriginalSize") or targetPart.Size
					local spacing = math.max(size.X, size.Z)
					local offsetVec = (playerRight * ox + playerLook * oz) * spacing
					local expectedPos = centerPos + offsetVec
					
					local bestPart = nil
					local bestDist = math.huge
					local fieldFolder = targetPart.Parent
					
					if fieldFolder then
						for _, p in ipairs(fieldFolder:GetDescendants()) do
							if p:IsA("BasePart") and p ~= targetPart and not table.find(targets, p) then
								local cap = p:FindFirstChild("Capacity")
								local aa = p:FindFirstChild("AlgaeAmount")
								if cap and aa and cap.Value > 0 then
									local dist = (p.Position - expectedPos).Magnitude
									if dist < (spacing * 1.5) and dist < bestDist then
										bestDist = dist
										bestPart = p
									end
								end
							end
						end
					end
					if bestPart then table.insert(targets, bestPart) end
				end
			end
		end
		
		-- Execute Batch for Pattern
		if #targets > 1 then
			HarvestService.HarvestMultipleBatched(player, targets, toolStats.CapacityBurn or 1)
		elseif #targets == 1 then
			ExecuteHarvest(player, targets, toolStats)
		end
	end
	
	-- Tool Mob Damage Processing
	local MobService = require(script.Parent.MobService)
	local pd = PlayerData.get(player)
	if pd and pd.Stats then
		local playerAttack = pd.Stats.Attack or 1
		local critChance = pd.Stats.CriticalChance or 0.01
		local critPower = pd.Stats.CriticalPower or 3.0
		local megaCritChance = pd.Stats.MegaCritChance or 0
		local megaCritPower = pd.Stats.MegaCritPower or 10.0
		local avgLevel = MobService.GetAverageFishLevel(player)
		
		if toolName == "SharkScythe" or toolName == "Shark Scythe" then
			local finalDamage = (ToolConfig["SharkScythe"].MobDamage or 30) * playerAttack
			local isCrit = false
			if math.random() <= megaCritChance then
				isCrit = true; finalDamage = finalDamage * megaCritPower
			elseif math.random() <= critChance then
				isCrit = true; finalDamage = finalDamage * critPower
			end
			
			local VFXReplication = game.ReplicatedStorage:FindFirstChild("Remotes") and game.ReplicatedStorage.Remotes:FindFirstChild("VFXReplication")
			if VFXReplication then
				VFXReplication:FireAllClients("SharkScythe", player, nil, nil)
				if pd and pd.Settings and pd.Settings.HitboxVisualizer then
					VFXReplication:FireClient(player, "HitboxVisualizer", nil, nil, {Position = root.Position, Size = 15, Shape = "Sphere", Duration = 0.5})
				end
			end
			
			for _, mobData in ipairs(MobService.GetMobs()) do
				if mobData.Mob and mobData.Mob.PrimaryPart then
					local mPos = Vector3.new(mobData.Mob.PrimaryPart.Position.X, 0, mobData.Mob.PrimaryPart.Position.Z)
					local pPos = Vector3.new(root.Position.X, 0, root.Position.Z)
					if (mPos - pPos).Magnitude <= 15 then
						local mobLevel = mobData.Mob:FindFirstChild("Level") and mobData.Mob.Level.Value or 1
						local missChance = 0
						if mobLevel - avgLevel > 0 then missChance = 1 - math.pow(0.5, mobLevel - avgLevel) end
						MobService.DamageMob(mobData.Mob, finalDamage, isCrit, math.random() < missChance, player)
					end
				end
			end
		elseif toolName == "Crystiken" then
			local finalDamage = (ToolConfig["Crystiken"].MobDamage or 5) * playerAttack
			local isCrit = false
			if math.random() <= megaCritChance then
				isCrit = true; finalDamage = finalDamage * megaCritPower
			elseif math.random() <= critChance then
				isCrit = true; finalDamage = finalDamage * critPower
			end
			
			for _, mobData in ipairs(MobService.GetMobs()) do
				if mobData.Mob and mobData.Mob.PrimaryPart then
					-- Crystiken has 20 range, we use 25 for safe measure against ping
					local mPos = Vector3.new(mobData.Mob.PrimaryPart.Position.X, 0, mobData.Mob.PrimaryPart.Position.Z)
					local pPos = Vector3.new(root.Position.X, 0, root.Position.Z)
					if (mPos - pPos).Magnitude <= 25 then
						local mobLevel = mobData.Mob:FindFirstChild("Level") and mobData.Mob.Level.Value or 1
						local missChance = 0
						if mobLevel - avgLevel > 0 then missChance = 1 - math.pow(0.5, mobLevel - avgLevel) end
						MobService.DamageMob(mobData.Mob, finalDamage, isCrit, math.random() < missChance, player)
					end
				end
			end
		end
	end
end

local FishHarvestEvent = Remotes:FindFirstChild("FishHarvestEvent")
if not FishHarvestEvent then
	FishHarvestEvent = Instance.new("RemoteEvent")
	FishHarvestEvent.Name = "FishHarvestEvent"
	FishHarvestEvent.Parent = Remotes
end

local function ProcessFishHarvest(player, fishIndex, targetPart, isRecursiveCall, forcedMegaCrit)
	-- 1. Validation
	if not targetPart or not targetPart.Parent then return end
	
	local fieldName = GetFieldName(targetPart)
	local fieldConfig = GetFieldConfig(fieldName)
	if not fieldConfig then return end 
	
	if player.Character and player.Character.PrimaryPart then
		local dist = (player.Character.PrimaryPart.Position - targetPart.Position).Magnitude
		if dist > 100 then 
			-- warn("Server: Fish too far from player (" .. dist .. ")")
			return 
		end
	else
		return
	end
	
	-- 2. Get Stats & Execute
	PlayerData.update(player, function(data)
		if not ValidateZoneAccess(data, targetPart) then return nil end
		
		-- Try both number and string keys
		local fishData = data.FishSchool[fishIndex] or data.FishSchool[tostring(fishIndex)] or data.FishSchool[tonumber(fishIndex)]
		
		-- Check temporary fish if not found in main school
		if not fishData and _G.TemporaryFish and _G.TemporaryFish[player.UserId] then
			fishData = _G.TemporaryFish[player.UserId][tostring(fishIndex)]
		end
		
		if not fishData then 
			-- Silently return for temporary fish that already expired
			return nil 
		end
		
		local speciesConfig = FishConfig.Fish[fishData.Id]
		if not speciesConfig then 
			warn("Server: Fish ID " .. tostring(fishData.Id) .. " not found in config")
			return nil 
		end
		
		-- PASSIVE LOGIC CHECK
		if not isRecursiveCall and speciesConfig.Passive then
			if not data.Session then data.Session = {} end
			if not data.Session.FishPassiveCounts then data.Session.FishPassiveCounts = {} end
			
			local fid = tostring(fishIndex)
			local count = (data.Session.FishPassiveCounts[fid] or 0) + 1
			data.Session.FishPassiveCounts[fid] = count
			
			-- Check Trigger (Currently hardcoded for Glow logic or generic?)
			local passiveDef = FishConfig.Passives and FishConfig.Passives[speciesConfig.Passive]
			if passiveDef then
				local shouldTrigger = false
				
				if passiveDef.TriggerCount then
					if count % passiveDef.TriggerCount == 0 then
						shouldTrigger = true
					end
				elseif passiveDef.Chance then
					-- 1 in X chance
					if math.random(1, passiveDef.Chance) == 1 then
						shouldTrigger = true
					end
				elseif passiveDef.AlwaysTrigger then
					-- Triggers every gather; condition checked inside TriggerPassive
					shouldTrigger = true
					print("[DEBUG] Passive AlwaysTrigger met for:", speciesConfig.Passive)
				end
				
				if shouldTrigger then
					print("[DEBUG] Calling TriggerPassive for:", speciesConfig.Passive)
					TriggerPassive(player, fishIndex, speciesConfig, targetPart)
				end
			end
		end
		
		-- PASSIVE: _my.safespace. Check
		if speciesConfig.Passive == "_my.safespace." then
			local passiveCfg = FishConfig.Passives["_my.safespace."]
			local sanctuaryRadius = passiveCfg and passiveCfg.SanctuaryRadius or 15
			local harvestRadius = passiveCfg and passiveCfg.HarvestRadius or 6.5
			
			local AbilityService = require(script.Parent.AbilityService)
			local activeSanctuaries = AbilityService.ActiveSanctuaries
			if activeSanctuaries then
				for _, sanc in pairs(activeSanctuaries) do
					if sanc.IsActive and sanc.Position then
						if (targetPart.Position - sanc.Position).Magnitude <= sanctuaryRadius then
							forcedMegaCrit = true
							break
						end
					end
				end
			end
			
			if forcedMegaCrit and not isRecursiveCall then
				local fieldFolder = targetPart.Parent
				for _, child in ipairs(fieldFolder:GetDescendants()) do
					if child:IsA("BasePart") and child ~= targetPart then
						if (child.Position - targetPart.Position).Magnitude <= harvestRadius then
							task.spawn(function()
								ProcessFishHarvest(player, fishIndex, child, true, true)
							end)
						end
					end
				end
			end
		end
		
		-- Add Harvest XP (+2)
		FishService.AddXPToData(data, fishIndex, 2, player)
		
		local fishLevel = fishData.Level or 1
		local levelGatherBonus = 1 + (0.15 * (fishLevel - 1)) -- 15% linearly per level above 1
		local levelConvBonus = (fishLevel - 1) * 0.01 -- 1% conversion chance per level above 1
		
		local gatherAmount = math.floor((speciesConfig.BaseStats.GatherAmount or 1) * levelGatherBonus)
		
		-- 100% Boost if Fish ColorTrait matches Target Algae Color!
		if speciesConfig.ColorTrait and speciesConfig.ColorTrait ~= "Colorless" then
			if string.match(targetPart.Name, speciesConfig.ColorTrait) then
				gatherAmount = gatherAmount * 2
			end
		end
		
		-- Calculate Yield Logic
		local unitYield = 1
		local yieldVal = targetPart:FindFirstChild("AlgaeAmount")
		if yieldVal then unitYield = yieldVal.Value end
		
		-- Multipliers
		local totalMult = GetAlgaeMultipliers(data, targetPart, true)
		
		-- Critical Hit Logic
		local isCrit = false
		local isMegaCrit = false
		local overCrit = 0
		
		local rawCrit = (data.Stats.CriticalChance or 0.01) + (data.Stats.CritChanceBonus or 0)
		local rawMega = data.Stats.MegaCritChance or 0.01
		
		local critPct = rawCrit * 100
		local megaPct = rawMega * 100
		
		if critPct > 100 then
			overCrit = critPct - 100
			critPct = 100
			megaPct = megaPct + overCrit
		end
		
		local trueMegaPct = critPct * (math.min(100, megaPct) / 100)
		local trueCritPct = critPct - trueMegaPct
		
		local normalPct = 100 - (trueCritPct + trueMegaPct)
		if normalPct < 0 then normalPct = 0 end
		
		local critResult = PercentageRandomizing({
			["Normal"] = normalPct,
			["Critical"] = trueCritPct,
			["MegaCritical"] = trueMegaPct
		})
		
		if forcedMegaCrit then
			isMegaCrit = true
			isCrit = false
			local megaPower = data.Stats.MegaCritPower or 10.0
			unitYield = unitYield * megaPower
		else
			if critResult == "Critical" or critResult == "MegaCritical" then
				if critResult == "MegaCritical" then
					isMegaCrit = true
					local megaPower = data.Stats.MegaCritPower or 10.0
					unitYield = unitYield * megaPower
				else
					isCrit = true
					local critPower = GetCritPower(data)
					unitYield = unitYield * critPower
				end
			end
		end
		
		-- Total reward = Fish Power * Plant Yield * Multipliers
		local totalReward = math.floor(gatherAmount * unitYield * totalMult + 0.5)
		-- Capacity Check (Player Backpack)
		-- We need space for totalReward
		local currentTotal = 0
		for _, amt in pairs(data.Plankton) do currentTotal += amt end
		
		local spaceLeft = data.MaxCapacity - currentTotal
		local actualReward = math.min(totalReward, spaceLeft)
		local bagIsFull = false
		if actualReward <= 0 then
			bagIsFull = true
			actualReward = 0
			NotifyCapacityFull(player)
			return nil -- DO NOT consume field capacity if backpack is full
		end
		
		-- Calculate how much field capacity this consumes
		-- E.g. 1 gatherAmount = 1 capacity unit cost
		-- If we are only taking partial reward, do we reduce cost? 
		-- Let's keep it simple: consume full cost or ratio.
		local cost = gatherAmount
		if isCrit then
			-- Logic: Does crit consume 3x capacity? Usually Crits are "Bonus" so they don't consume extra resource.
			-- Let's assume standard cost.
		end
		
		-- Field Capacity Check
		local capacityVal = targetPart:FindFirstChild("Capacity")
		if not capacityVal or capacityVal.Value <= 0 then 
			-- warn("Server: Field Depleted")
			return nil 
		end
		
		-- Clamp cost to remaining field life
		local actualCost = math.min(cost, capacityVal.Value)
		
		-- Execute Harvest
		capacityVal.Value = capacityVal.Value - actualCost
		
		-- Mark Dirty
		local FieldService = require(script.Parent.FieldService)
		FieldService.MarkDirty(targetPart)
		
		-- Logic: Ensure MaxCapacity is set (for Client Visuals)
		local maxCap = targetPart:GetAttribute("MaxCapacity")
		if not maxCap then
			maxCap = capacityVal.Value + actualCost
			targetPart:SetAttribute("MaxCapacity", maxCap)
		end
		
		-- If empty, FieldService logic usually handles respawn/hide but here we trigger consume if needed?
		-- FieldService.MarkDirty handles regen delay. But if empty we need to hide it?
		-- Client handles hide on Capacity <= 0.
		-- BUT server might need to "Consume" to trigger specific game logic if any. 
		if capacityVal.Value <= 0 then
			local FieldService = require(script.Parent.FieldService)
			FieldService.Consume(targetPart)
		end
		
		-- Give Rewards
		local rType = targetPart.Name
		
		-- Instant Conversion
		local grossReward = actualReward
		actualReward = ApplyInstantConversion(player, data, actualReward, targetPart.Position, nil, levelConvBonus)
		
		data.Plankton[rType] = (data.Plankton[rType] or 0) + actualReward
		data.LifetimeAlgae = (data.LifetimeAlgae or 0) + actualReward
		TrackAlgaePerSecond(data, actualReward)
		
		-- Update Quest Progress
		for questId, qData in pairs(GetActiveQuests(data, player)) do
			local qConfig = qData.Config
			local progress = qData.Progress
			if qConfig then
				-- Requirement Check
				local reqMet = true
				if qConfig.RequiredBackpack and data.EquippedBackpack ~= qConfig.RequiredBackpack then reqMet = false end
				
				if reqMet then
					-- Use grossReward for quests so conversion doesn't hinder progress
					if qConfig.Goals then
						-- Multi-Goal
						if type(progress) ~= "table" then progress = {} end
						if qConfig.Goals[rType] then
							local current = progress[rType] or 0
							local limit = qConfig.Goals[rType]
							local nxt = current + grossReward
							if nxt > limit then nxt = limit end
							progress[rType] = nxt
						end
						
						-- Check Field_Resource Goal
						local key = fieldName .. "_" .. rType
						if qConfig.Goals[key] then
							local current = progress[key] or 0
							local limit = qConfig.Goals[key]
							local nxt = current + grossReward
							if nxt > limit then nxt = limit end
							progress[key] = nxt
						end
						
						-- Generic Field Goal (any algae from a specific field, e.g. NoobieTurtle)
						if fieldName and qConfig.Goals[fieldName] then
							local current = progress[fieldName] or 0
							local limit = qConfig.Goals[fieldName]
							local nxt = current + grossReward
							if nxt > limit then nxt = limit end
							progress[fieldName] = nxt
						end
						
						data.ActiveQuests[questId] = progress

					else
						-- Single Goal
						if (qConfig.TargetResource == "Any" or qConfig.TargetResource == rType) then
							local shouldCount = true
							if qConfig.TargetLocation and qConfig.TargetLocation ~= fieldName then
								shouldCount = false
							end
							
							if shouldCount then
								local current = tonumber(progress) or 0
								local nxt = current + grossReward
								if nxt > qConfig.GoalAmount then nxt = qConfig.GoalAmount end
								data.ActiveQuests[questId] = nxt
							end
						end
					end
				end -- End reqMet
			end
		end
		
		PlayerData.SetDirty(player, "Quests")
		
		-- Leaderstats
		local ls = player:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Algae") then
			ls.Algae.Value = currentTotal + actualReward
		end
		
		-- Visuals (Batched) - Uses server-side 50ms batching window
		local resType = ResourceConfig.Types[rType]
		local color = (resType and resType.Color) or Color3.new(1,1,1)
		AddToBatch(player, targetPart.Position + Vector3.new(0, 2, 0), actualReward, color, isCrit, isMegaCrit)
		
		if grossReward > 0 then
			local SeaMineService = require(script.Parent.SeaMineService)
			SeaMineService.AddAlgae(player, targetPart.Position, grossReward)
		end
		
		return data, actualReward
	end)
end

FishHarvestEvent.OnServerEvent:Connect(function(player, fishIndex, targetPart)
	if not SecurityService.ValidateRemoteCall(player, "FishHarvestEvent") then return end
	ProcessFishHarvest(player, fishIndex, targetPart)
end)

-- Poseidon Wave Ability
local PoseidonCooldowns = {} -- [UserId] = nextTime
	local PoseidonWaveEvent = Remotes:FindFirstChild("PoseidonWaveEvent")
	if not PoseidonWaveEvent then
		PoseidonWaveEvent = Instance.new("RemoteEvent")
		PoseidonWaveEvent.Name = "PoseidonWaveEvent"
		PoseidonWaveEvent.Parent = Remotes
	end
	
	local VFXReplication = Remotes:FindFirstChild("VFXReplication")
	if not VFXReplication then
		VFXReplication = Instance.new("RemoteEvent")
		VFXReplication.Name = "VFXReplication"
		VFXReplication.Parent = Remotes
	end
	
	local SunkissedOrbEvent = Remotes:FindFirstChild("SunkissedOrbEvent")
	if not SunkissedOrbEvent then
		SunkissedOrbEvent = Instance.new("RemoteEvent")
		SunkissedOrbEvent.Name = "SunkissedOrbEvent"
		SunkissedOrbEvent.Parent = Remotes
	end
	
	local SunkissedMeleeEvent = Remotes:FindFirstChild("SunkissedMeleeEvent")
	if not SunkissedMeleeEvent then
		SunkissedMeleeEvent = Instance.new("RemoteEvent")
		SunkissedMeleeEvent.Name = "SunkissedMeleeEvent"
		SunkissedMeleeEvent.Parent = Remotes
	end
	
	local SunkissedSunWrathEvent = Remotes:FindFirstChild("SunkissedSunWrathEvent")
	if not SunkissedSunWrathEvent then
		SunkissedSunWrathEvent = Instance.new("RemoteEvent")
		SunkissedSunWrathEvent.Name = "SunkissedSunWrathEvent"
		SunkissedSunWrathEvent.Parent = Remotes
	end
	
	SunkissedSunWrathEvent.OnServerEvent:Connect(function(player, rootCF)
		if typeof(rootCF) ~= "CFrame" then return end
		local data = PlayerData.get(player)
		if not data then return end
		
		local AbilityService = require(script.Parent.AbilityService)
		
		-- Use our new specific function to check TheSunsWrath CD via BuffStacks safely
		if AbilityService.GetBuffStacks(player, "TheSunsWrath") > 0 then return end
		
		-- Radius harvest 15, Capacity 20
		local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Include
		local filterFolders = {}
		for fieldName, _ in pairs(ResourceConfig.Fields) do
			local f = getFieldFolder(fieldName)
			if f then table.insert(filterFolders, f) end
		end
		
		local mobsFolder = workspace:FindFirstChild("Mobs")
		if mobsFolder then table.insert(filterFolders, mobsFolder) end
		
		overlapParams.FilterDescendantsInstances = filterFolders
		
		local parts = workspace:GetPartBoundsInRadius(rootCF.Position, 20, overlapParams)
		local algaeTargets = {}
		local visualTargets = {}
		local mobTargets = {}
		local hitList = {}
		local visualHitList = {}
		local mobHitList = {}
		
		for _, p in ipairs(parts) do
			if p:IsA("BasePart") then
				if p.Name:match("Algae") then
					if not visualHitList[p] then
						table.insert(visualTargets, p)
						visualHitList[p] = true
					end
					
					if not hitList[p] then
						local cap = p:FindFirstChild("Capacity")
						if cap and cap.Value > 0 then
							table.insert(algaeTargets, p)
							hitList[p] = true
						end
					end
				else
					local model = p:FindFirstAncestorWhichIsA("Model")
					if model and model.Parent == mobsFolder and p == model.PrimaryPart then
						if not visualHitList[model] then
							table.insert(visualTargets, p)
							visualHitList[model] = true
						end
						
						if not mobHitList[model] then
							table.insert(mobTargets, model)
							mobHitList[model] = true
						end
					end
				end
			end
		end
		
		if #algaeTargets > 0 then
			HarvestService.HarvestMultipleBatched(player, algaeTargets, 20)
		end
		
		if #mobTargets > 0 then
			local MobService = require(script.Parent.MobService)
			local pd = PlayerData.get(player)
			local playerAttack = (pd and pd.Stats and pd.Stats.Attack) or 1
			local critChance = (pd and pd.Stats and pd.Stats.CriticalChance) or 0.01
			local critPower = (pd and pd.Stats and pd.Stats.CriticalPower) or 3.0
			local megaCritChance = (pd and pd.Stats and pd.Stats.MegaCritChance) or 0
			local megaCritPower = (pd and pd.Stats and pd.Stats.MegaCritPower) or 10.0
			
			local avgLevel = MobService.GetAverageFishLevel(player)
			local ToolConfig = require(ReplicatedStorage.Shared.ToolConfig)
			local baseDamage = (ToolConfig["Sunkissed Art"].SunWrathInitialDamage or 400) * playerAttack * math.max(1, avgLevel)
			
			if pd and pd.Settings and pd.Settings.HitboxVisualizer then
				VFXReplication:FireClient(player, "HitboxVisualizer", nil, nil, {Position = rootCF.Position, Size = 20, Shape = "Sphere", Duration = 1.0})
			end
			
			for _, mobModel in ipairs(mobTargets) do
				local finalDamage = baseDamage
				local isCrit = false
				if math.random() <= megaCritChance then
					isCrit = true; finalDamage = finalDamage * megaCritPower
				elseif math.random() <= critChance then
					isCrit = true; finalDamage = finalDamage * critPower
				end
				
				local mobLevel = mobModel:FindFirstChild("Level") and mobModel.Level.Value or 1
				local missChance = 0
				if mobLevel - avgLevel > 0 then missChance = 1 - math.pow(0.5, mobLevel - avgLevel) end
				
				MobService.DamageMob(mobModel, finalDamage, isCrit, math.random() < missChance, player)
			end
		end
		
		-- "spawn Solar Flares ANYWHERE IN THE REEF if there are reefs in proximity"
		if #visualTargets > 0 and AbilityService.ExecuteSolarFlare then
			task.spawn(function()
				local validTargets = {}
				for _, algae in ipairs(visualTargets) do
					table.insert(validTargets, algae)
				end
				
				local selectedPositions = {}
				for i = 1, math.min(5, #validTargets) do
					local randIndex = math.random(1, #validTargets)
					table.insert(selectedPositions, validTargets[randIndex].Position)
					table.remove(validTargets, randIndex)
				end
				
				local vfxOverride = {Color = Color3.fromRGB(255, 80, 0), ForceOverride = true}
				for _, pos in ipairs(selectedPositions) do
					local extraData = {
						TargetPos = pos,
						MoveTime = 0.8,
						OutwardOnly = true,
						DamageOverride = ToolConfig["Sunkissed Art"].AbilityDamage or 30
					}
					AbilityService.ExecuteSolarFlare(player, rootCF.Position, 1.0, extraData, vfxOverride)
					task.wait(0.15)
				end
			end)
		end
		
	-- Buff and block ability for 30s
		AbilityService.ApplyBuff(player, "TheSunsWrath")
	end)
	
	local SunkissedMeleeCooldowns = {}
	SunkissedMeleeEvent.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if (SunkissedMeleeCooldowns[player.UserId] or 0) > now then return end
		SunkissedMeleeCooldowns[player.UserId] = now + 0.15
		
		local data = PlayerData.get(player)
		if not data then return end
		if data.EquippedTool ~= "Sunkissed Art" and data.EquippedTool ~= "SunkissedArt" then return end
		
		local root = player.Character and player.Character.PrimaryPart
		if not root then return end
		
		local pd = data
		local playerAttack = (pd and pd.Stats and pd.Stats.Attack) or 1
		local finalDamage = (ToolConfig["Sunkissed Art"].MobDamage or 20) * playerAttack
		
		local MobService = require(script.Parent.MobService)
		local avgLevel = MobService.GetAverageFishLevel(player)
		finalDamage = finalDamage * math.max(1, avgLevel)
		
		local critChance = (pd and pd.Stats and pd.Stats.CriticalChance) or 0.01
		local critPower = (pd and pd.Stats and pd.Stats.CriticalPower) or 3.0
		local megaCritChance = (pd and pd.Stats and pd.Stats.MegaCritChance) or 0
		local megaCritPower = (pd and pd.Stats and pd.Stats.MegaCritPower) or 10.0
		
		local isCrit = false
		if math.random() <= megaCritChance then
			isCrit = true
			finalDamage = finalDamage * megaCritPower
		elseif math.random() <= critChance then
			isCrit = true
			finalDamage = finalDamage * critPower
		end
		
		local hitCenter = root.Position + (root.CFrame.LookVector * 15)
		
		if pd.Settings and pd.Settings.HitboxVisualizer then
			VFXReplication:FireClient(player, "HitboxVisualizer", nil, nil, {Position = hitCenter, Size = 15, Shape = "Sphere", Duration = 1.0})
		end
		
		local MobService = require(script.Parent.MobService)
		local avgLevel = MobService.GetAverageFishLevel(player)
		for _, mobData in ipairs(MobService.GetMobs()) do
			if mobData.Mob and mobData.Mob.PrimaryPart then
				if (mobData.Mob.PrimaryPart.Position - hitCenter).Magnitude <= 15 then
					local mobLevel = mobData.Mob:FindFirstChild("Level") and mobData.Mob.Level.Value or 1
					local levelDiff = mobLevel - avgLevel
					local missChance = 0
					if levelDiff > 0 then
						missChance = 1 - math.pow(0.5, levelDiff)
					end
					local isMiss = math.random() < missChance
					MobService.DamageMob(mobData.Mob, finalDamage, isCrit, isMiss, player)
				end
			end
		end
	end)
	
	local SunkissedOrbCooldowns = {}
	local SunkissedFireballCounts = {}
	SunkissedOrbEvent.OnServerEvent:Connect(function(player, startCF)
		local now = os.clock()
		if (SunkissedOrbCooldowns[player.UserId] or 0) > now then return end
		SunkissedOrbCooldowns[player.UserId] = now + 1
		
		local data = PlayerData.get(player)
		if not data then return end
		
		if data.EquippedTool ~= "Sunkissed Art" and data.EquippedTool ~= "SunkissedArt" then return end
		if typeof(startCF) ~= "CFrame" then return end
		if not player.Character or not player.Character.PrimaryPart then return end
		
		local dist = (player.Character.PrimaryPart.Position - startCF.Position).Magnitude
		if dist > 20 then return end
		
		SunkissedFireballCounts[player.UserId] = (SunkissedFireballCounts[player.UserId] or 0) + 1
		local isThirdFireball = (SunkissedFireballCounts[player.UserId] % 3 == 0)
		
		local vfxFolder = ReplicatedStorage:FindFirstChild("VFX")
		local skVFX = vfxFolder and vfxFolder:FindFirstChild("SunkissedArt")
		local orbyObj = (skVFX and skVFX:FindFirstChild("Orby1")) or (vfxFolder and vfxFolder:FindFirstChild("Orby1"))
		
		if not orbyObj then
			warn("SunkissedOrbEvent FAILED: Could not find 'Orby1' in either RS.VFX or RS.VFX.SunkissedArt")
			return
		end
		
		local orb = orbyObj:Clone()
		orb.CFrame = startCF
		orb.Anchored = false
		orb.CanCollide = false
		orb.Massless = true
		orb.Parent = workspace
		
		local att = Instance.new("Attachment")
		att.Parent = orb
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.MaxForce = math.huge
		lv.VectorVelocity = startCF.LookVector * 50
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = orb
		
		for _, desc in ipairs(orb:GetDescendants()) do
			if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then
				desc.Enabled = true
			end
		end
		
		local hitList = {}
		local startTime = os.clock()
		local duration = 1.5
		local speed = 50
		local lastDamageTick = os.clock()
		
		local RunService = game:GetService("RunService")
		local connection
		
		connection = RunService.Heartbeat:Connect(function()
			if not orb or not orb.Parent then
				if connection then connection:Disconnect() end
				return
			end
			
			local now = os.clock()
			if now - lastDamageTick >= 0.15 then
				lastDamageTick = now
				local pd = PlayerData.get(player)
				local playerAttack = (pd and pd.Stats and pd.Stats.Attack) or 1
				local finalDamage = (ToolConfig["Sunkissed Art"].OrbTickDamage or 10) * playerAttack
				
				local critChance = (pd and pd.Stats and pd.Stats.CriticalChance) or 0.01
				local critPower = (pd and pd.Stats and pd.Stats.CriticalPower) or 3.0
				local megaCritChance = (pd and pd.Stats and pd.Stats.MegaCritChance) or 0
				local megaCritPower = (pd and pd.Stats and pd.Stats.MegaCritPower) or 10.0
				
				local isCrit = false
				if math.random() <= megaCritChance then
					isCrit = true
					finalDamage = finalDamage * megaCritPower
				elseif math.random() <= critChance then
					isCrit = true
					finalDamage = finalDamage * critPower
				end
				
				if pd and pd.Settings and pd.Settings.HitboxVisualizer then
					VFXReplication:FireClient(player, "HitboxVisualizer", nil, nil, {Position = orb.Position, Size = 12, Shape = "Sphere", Duration = 0.2})
				end
				
				local MobService = require(script.Parent.MobService)
				local avgLevel = MobService.GetAverageFishLevel(player)
				for _, mobData in ipairs(MobService.GetMobs()) do
					if mobData.Mob and mobData.Mob.PrimaryPart then
						if (mobData.Mob.PrimaryPart.Position - orb.Position).Magnitude <= 12 then
							local mobLevel = mobData.Mob:FindFirstChild("Level") and mobData.Mob.Level.Value or 1
							local levelDiff = mobLevel - avgLevel
							local missChance = 0
							if levelDiff > 0 then
								missChance = 1 - math.pow(0.5, levelDiff)
							end
							local isMiss = math.random() < missChance
							MobService.DamageMob(mobData.Mob, finalDamage, isCrit, isMiss)
						end
					end
				end
			end
			
			local elapsed = os.clock() - startTime
			if elapsed > duration then
				if connection then connection:Disconnect() end
				if lv then lv:Destroy() end
				orb.Anchored = true
				
				if isThirdFireball then
					local AbilityService = require(script.Parent.AbilityService)
					if AbilityService.ExecuteSolarFlare then
						local vfxOverride = {Color = Color3.fromRGB(255, 80, 0), ForceOverride = true}
						-- Pass nil for extraData, then pass vfxOverride securely
						AbilityService.ExecuteSolarFlare(player, orb.Position, 1.0, nil, vfxOverride)
					end
				end
				
				-- Explosion Logic (12x12 radius, collect 6 capacity)
				local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Include
				local filterFolders = {}
				for fieldName, _ in pairs(ResourceConfig.Fields) do
					local f = getFieldFolder(fieldName)
					if f then table.insert(filterFolders, f) end
				end
				overlapParams.FilterDescendantsInstances = filterFolders
				
				local parts = workspace:GetPartBoundsInRadius(orb.Position, 12, overlapParams)
				local algaeTargets = {}
				for _, p in ipairs(parts) do
					if p:IsA("BasePart") and p.Name:match("Algae") then
						local cap = p:FindFirstChild("Capacity")
						if cap and cap.Value > 0 then
							table.insert(algaeTargets, p)
						end
					end
				end
				if #algaeTargets > 0 then
					HarvestService.HarvestMultipleBatched(player, algaeTargets, 15)
				end
				
				-- Damage Mobs
				local pd = PlayerData.get(player)
				local playerAttack = (pd and pd.Stats and pd.Stats.Attack) or 1
				local critChance = (pd and pd.Stats and pd.Stats.CriticalChance) or 0.01
				local critPower = (pd and pd.Stats and pd.Stats.CriticalPower) or 3.0
				local megaCritChance = (pd and pd.Stats and pd.Stats.MegaCritChance) or 0
				local megaCritPower = (pd and pd.Stats and pd.Stats.MegaCritPower) or 10.0
				
				local isCrit = false
				
				local MobService = require(script.Parent.MobService)
				local avgLevel = MobService.GetAverageFishLevel(player)
				local finalDamage = (playerAttack * (ToolConfig["Sunkissed Art"].ExplosionDamage or 2)) * math.max(1, avgLevel) -- Sunkissed orb might do more damage since it's a big explosion
				
				if math.random() <= megaCritChance then
					isCrit = true
					finalDamage = finalDamage * megaCritPower
				elseif math.random() <= critChance then
					isCrit = true
					finalDamage = finalDamage * critPower
				end
				
				if pd and pd.Settings and pd.Settings.HitboxVisualizer then
					VFXReplication:FireClient(player, "HitboxVisualizer", nil, nil, {Position = orb.Position, Size = 12, Shape = "Sphere", Duration = 1.0})
				end
				
				local MobService = require(script.Parent.MobService)
				local avgLevel = MobService.GetAverageFishLevel(player)
				
				for _, mobData in ipairs(MobService.GetMobs()) do
					if mobData.Mob and mobData.Mob.PrimaryPart then
						local dist = (mobData.Mob.PrimaryPart.Position - orb.Position).Magnitude
						if dist <= 12 then
							local mobLevel = mobData.Mob:FindFirstChild("Level") and mobData.Mob.Level.Value or 1
							local levelDiff = mobLevel - avgLevel
							local missChance = 0
							if levelDiff > 0 then
								missChance = 1 - math.pow(0.5, levelDiff)
							end
							local isMiss = math.random() < missChance
							
							MobService.DamageMob(mobData.Mob, finalDamage, isCrit, isMiss)
						end
					end
				end
				
				local skFolder = vfxFolder:FindFirstChild("SunkissedArt")
				local explodeAtt = skFolder and skFolder:FindFirstChild("Explode")
				if explodeAtt then
					local expClone = explodeAtt:Clone()
					expClone.Parent = orb
					
					local isLowDetail = data.Settings and data.Settings.LowDetailMode
					local detailMult = isLowDetail and 0.5 or 1.0
					
					for _, p in ipairs(expClone:GetChildren()) do
						if p:IsA("ParticleEmitter") then
							local burst = p:GetAttribute("EmitCount") or p:GetAttribute("Count") or 30
							p:Emit(math.max(1, math.floor(burst * detailMult)))
						end
					end
				end
				
				for _, desc in ipairs(orb:GetDescendants()) do
					if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then
						desc.Enabled = false
					end
				end
				
				local rsRoot = ReplicatedStorage:FindFirstChild("SunkissedArt")
				local sfx = (skFolder and skFolder:FindFirstChild("SunkissedArt4")) or (rsRoot and rsRoot:FindFirstChild("SunkissedArt4")) or ReplicatedStorage:FindFirstChild("SunkissedArt4")
				
				if sfx and sfx:IsA("Sound") then
					local s = sfx:Clone()
					s.Parent = orb
					s:Play()
				end
				
				orb.Transparency = 1
				game.Debris:AddItem(orb, 4) -- Give plenty of time for SunkissedArt4 to finish playing
				return
			end
			
			-- Physics engine seamlessly handles continuous movement for perfectly smooth VFX
			-- orb.CFrame = startCF * CFrame.new(0, 0, -elapsed * speed)
			
			local checkInterval = 0.1
			local lastCheck = orb:GetAttribute("LastCheck") or 0
			if (elapsed - lastCheck) >= checkInterval then
				orb:SetAttribute("LastCheck", elapsed)
				
				local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Include
				local filterFolders = {}
				for fieldName, _ in pairs(ResourceConfig.Fields) do
					local f = getFieldFolder(fieldName)
					if f then table.insert(filterFolders, f) end
				end
				overlapParams.FilterDescendantsInstances = filterFolders
				
				local parts = workspace:GetPartBoundsInRadius(orb.Position, 8, overlapParams)
				local algaeTargets = {}
				for _, p in ipairs(parts) do
					if not hitList[p] and p:IsA("BasePart") and p.Name:match("Algae") then
						local cap = p:FindFirstChild("Capacity")
						if cap and cap.Value > 0 then
							table.insert(algaeTargets, p)
							hitList[p] = true
						end
					end
				end
				if #algaeTargets > 0 then
					HarvestService.HarvestMultipleBatched(player, algaeTargets, 9)
				end
			end
		end)
	end)

    PoseidonWaveEvent.OnServerEvent:Connect(function(player, startCF)
		-- 1. Data Validation
		local data = PlayerData.get(player)
		if not data then return end
		
		-- Verify Poseidon is equipped
		if data.EquippedTool ~= "Poseidon" then
			return
		end
		
		-- 2. Cooldown Check
		local ToolConfig = require(ReplicatedStorage.Shared.ToolConfig)
		local activeCooldown = ToolConfig["Poseidon"].Cooldown or 0.6
		local currentToolSpeed = (data.Stats and data.Stats.ToolSpeed) or 1
		activeCooldown = activeCooldown / currentToolSpeed
		
		local now = os.clock()
		if (PoseidonCooldowns[player.UserId] or 0) > now then return end
		PoseidonCooldowns[player.UserId] = now + math.max(0.05, activeCooldown * 0.8) -- Permissive to account for ping

		-- Validation: Distance check
		if not player.Character or not player.Character.PrimaryPart then return end
		-- startCF validation (ensure it's a CFrame)
		if typeof(startCF) ~= "CFrame" then return end
		
		local dist = (player.Character.PrimaryPart.Position - startCF.Position).Magnitude
		if dist > 20 then return end -- Too far (increased from 15 to allow slight lag leniency)
		
		local AbilityService = require(script.Parent.AbilityService)
		local tidalSurgeStacks = AbilityService.GetBuffStacks(player, "TidalSurge")
		
		local waveCFs = {startCF}
		if tidalSurgeStacks >= 200 then
			table.insert(waveCFs, startCF * CFrame.Angles(0, math.rad(45), 0))
			table.insert(waveCFs, startCF * CFrame.Angles(0, math.rad(-45), 0))
		end
		
		for _, waveCF in ipairs(waveCFs) do
			-- Fire Visuals to ALL clients 
			if VFXReplication then
				VFXReplication:FireAllClients("Wave", player, nil, {StartCFrame = waveCF})
			end
			
			-- Server Hitbox Logic (Math only, no physical part to prevent replication lag)
			local hitboxSize = Vector3.new(35, 12, 35)
			
			local hitList = {} -- Debounce per wave
			local startTime = os.clock()
			local duration = 2
			local speed = 40
			local lastCheck = 0
			
			local RunService = game:GetService("RunService")
			local connection
			
			connection = RunService.Heartbeat:Connect(function()
				local elapsed = os.clock() - startTime
				if elapsed > duration then
					if connection then connection:Disconnect() end
					return
				end
				
				-- Throttle: Only check every 0.1s
				local checkInterval = 0.1
				if (elapsed - lastCheck) < checkInterval then return end
				lastCheck = elapsed
				
				-- Calculate current CFrame mathematically
				local currentCFrame = waveCF * CFrame.new(0, 0, -elapsed * speed)
				
				local MobService = require(script.Parent.MobService)
				local pd = PlayerData.get(player)
				if pd and pd.Stats then
					local playerAttack = pd.Stats.Attack or 1
					local finalDamage = (ToolConfig["Poseidon"].MobDamage or 7) * playerAttack
					local critChance = pd.Stats.CriticalChance or 0.01
					local critPower = pd.Stats.CriticalPower or 3.0
					local megaCritChance = pd.Stats.MegaCritChance or 0
					local megaCritPower = pd.Stats.MegaCritPower or 10.0
					local avgLevel = MobService.GetAverageFishLevel(player)
					
					finalDamage = finalDamage * math.max(1, avgLevel)
					
					local isCrit = false
					if math.random() <= megaCritChance then
						isCrit = true; finalDamage = finalDamage * megaCritPower
					elseif math.random() <= critChance then
						isCrit = true; finalDamage = finalDamage * critPower
					end
					
					for _, mobData in ipairs(MobService.GetMobs()) do
						if mobData.Mob and mobData.Mob.PrimaryPart then
							if (mobData.Mob.PrimaryPart.Position - currentCFrame.Position).Magnitude <= 15 then
								local mobLevel = mobData.Mob:FindFirstChild("Level") and mobData.Mob.Level.Value or 1
								local missChance = 0
								if mobLevel - avgLevel > 0 then missChance = 1 - math.pow(0.5, mobLevel - avgLevel) end
								MobService.DamageMob(mobData.Mob, finalDamage, isCrit, math.random() < missChance, player)
							end
						end
					end
				end
				
				-- Detect Algae
				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Include
				local filterFolders = {}
				for fieldName, _ in pairs(ResourceConfig.Fields) do
					local f = getFieldFolder(fieldName)
					if f then table.insert(filterFolders, f) end
				end
				overlapParams.FilterDescendantsInstances = filterFolders
				
				local parts = workspace:GetPartBoundsInBox(currentCFrame, hitboxSize, overlapParams)
				local algaeTargets = {}
				
				
				for _, p in ipairs(parts) do
					if not hitList[p] and p.Name:match("Algae") then
						-- Validate it's a resource field part
						local field = p.Parent
						if field and GetFieldConfig(field.Name) then
							hitList[p] = true
							table.insert(algaeTargets, p)
						end
					end
				end
				
				-- Use batched harvest helper (auto-batches by color, reduces lag)
				if #algaeTargets > 0 then
					HarvestService.HarvestMultipleBatched(player, algaeTargets, 5)
				end
			end)
		end
	end)
	
	local RainmakerBulletDamageEvent = Remotes:FindFirstChild("RainmakerBulletDamageEvent")
	if not RainmakerBulletDamageEvent then
		RainmakerBulletDamageEvent = Instance.new("RemoteEvent")
		RainmakerBulletDamageEvent.Name = "RainmakerBulletDamageEvent"
		RainmakerBulletDamageEvent.Parent = Remotes
	end

	RainmakerBulletDamageEvent.OnServerEvent:Connect(function(player, targetPart)
		local data = PlayerData.get(player)
		if not data then return end
		if data.EquippedTool ~= "Rainmaker" then return end
		
		local root = player.Character and player.Character.PrimaryPart
		if not root or not targetPart then return end
		
		local mobModel = targetPart.Parent
		if not mobModel or not mobModel:FindFirstChild("Health") then return end
		
		local MobService = require(script.Parent.MobService)
		local pd = data
		local playerAttack = (pd and pd.Stats and pd.Stats.Attack) or 1
		local finalDamage = (ToolConfig["Rainmaker"].MobDamage or 5) * playerAttack
		
		local critChance = (pd and pd.Stats and pd.Stats.CriticalChance) or 0.01
		local critPower = (pd and pd.Stats and pd.Stats.CriticalPower) or 3.0
		local megaCritChance = (pd and pd.Stats and pd.Stats.MegaCritChance) or 0
		local megaCritPower = (pd and pd.Stats and pd.Stats.MegaCritPower) or 10.0
		
		local isCrit = false
		if math.random() <= megaCritChance then
			isCrit = true; finalDamage = finalDamage * megaCritPower
		elseif math.random() <= critChance then
			isCrit = true; finalDamage = finalDamage * critPower
		end
		
		local avgLevel = MobService.GetAverageFishLevel(player)
		if (targetPart.Position - root.Position).Magnitude <= 100 then
			if pd and pd.Settings and pd.Settings.HitboxVisualizer then
				VFXReplication:FireClient(player, "HitboxVisualizer", nil, nil, {Position = targetPart.Position, Size = 5, Shape = "Sphere", Duration = 0.5})
			end
			local mobLevel = mobModel:FindFirstChild("Level") and mobModel.Level.Value or 1
			local missChance = 0
			if mobLevel - avgLevel > 0 then missChance = 1 - math.pow(0.5, mobLevel - avgLevel) end
			
			finalDamage = finalDamage * math.max(1, avgLevel)
			MobService.DamageMob(mobModel, finalDamage, isCrit, math.random() < missChance, player)
		end
	end)
	
	HarvestEvent.OnServerEvent:Connect(HarvestService.OnHarvest)
	
	local PoseidonFishHitEvent = Remotes:FindFirstChild("PoseidonFishHitEvent")
	if not PoseidonFishHitEvent then
		PoseidonFishHitEvent = Instance.new("RemoteEvent")
		PoseidonFishHitEvent.Name = "PoseidonFishHitEvent"
		PoseidonFishHitEvent.Parent = Remotes
	end

	PoseidonFishHitEvent.OnServerEvent:Connect(function(player, fishIndex)
		local data = PlayerData.get(player)
		if data and data.EquippedTool == "Poseidon" then
			-- Grant Tidal Surge buff when a wave hits a fish
			local AbilityService = require(script.Parent.AbilityService)
			AbilityService.ApplyBuff(player, "TidalSurge")
		end
	end)



-- Batch harvest multiple targets (optimized for abilities that hit many algae at once)
-- Reduces lag by batching visuals by algae type instead of firing individual events
function HarvestService.HarvestMultipleBatched(player, targets, amountPerTarget, isRainmaker)
	if not player or not targets or #targets == 0 then return 0 end
	
	local FieldService = require(script.Parent.FieldService)
	local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
	local AbilityService: any = require(script.Parent.AbilityService)
	
	local harvestBatches = {} 
	local totalGained = 0
	
	-- Single Transaction Optimization
	PlayerData.update(player, function(data)
		if not data.Stats then return data end -- Safety
		
		-- Calculate Multipliers Once
		local globalMult = (data.Stats.Algae) or 1
		local convRate = data.Stats.InstantConversion or 0
		if convRate > 1 then convRate = 1 end
		
		-- Two-pass batching: Sum raw amounts first to prevent precision loss from individual flooring
		local tally = {} -- [key] = { cost, rType, fieldName, specMult, mMult, iMult, samplePos }
		
		for _, targetPart in ipairs(targets) do
			if targetPart and targetPart.Parent and targetPart:IsA("BasePart") then
				local capacityVal = targetPart:FindFirstChild("Capacity")
				if capacityVal and capacityVal.Value > 0 then
					local cost = math.min(amountPerTarget, capacityVal.Value)
					
					-- Reduce Field (autoritative physical change)
					capacityVal.Value = capacityVal.Value - cost
					FieldService.MarkDirty(targetPart)
					
					-- Visual Shrink
					local origSize = targetPart:GetAttribute("OriginalSize")
					if not origSize then origSize = targetPart.Size; targetPart:SetAttribute("OriginalSize", origSize) end
					local maxCap = targetPart:GetAttribute("MaxCapacity") or 40
					local shrink = (origSize.Y / maxCap) * cost
					
					if capacityVal.Value <= 0 then
						targetPart.Transparency = 1; targetPart.CanCollide = false
						for _,d in ipairs(targetPart:GetChildren()) do if d:IsA("Decal") then d.Transparency=1 end end
					else
						local newH = math.max(targetPart.Size.Y - shrink, origSize.Y/maxCap)
						targetPart.Size = Vector3.new(origSize.X, newH, origSize.Z)
						targetPart.CFrame = targetPart.CFrame * CFrame.new(0, -shrink/2, 0)
					end
					
					-- Identify Yield and Multipliers for this specific part
					local rType = targetPart.Name
					local yieldVal = targetPart:FindFirstChild("Yield")
					local unitYield = yieldVal and yieldVal.Value or 1
					
					local totalMult = GetAlgaeMultipliers(data, targetPart, true)
					local fieldName = GetFieldName(targetPart)
					
					-- Group parts by identical properties that affect final yield
					local key = string.format("%s|%d|%.3f|%s", rType, unitYield, totalMult, fieldName or "")
					if not tally[key] then
						tally[key] = {
							cost = 0,
							rType = rType,
							unitYield = unitYield,
							fieldName = fieldName,
							totalMult = totalMult,
							samplePos = targetPart.Position
						}
					end
					tally[key].cost += cost
				end
			end
		end
		
		-- Second Pass: Apply stats to collective totals of each group
		for _, entry in pairs(tally) do
			local toolMult = 1.0
			if isRainmaker then toolMult = data.Stats.ToolAlgae or 1.0 end
			
			local grossAmount = math.floor((entry.cost * entry.unitYield) * entry.totalMult * toolMult + 0.5)
			
			-- Apply Independent Crit calculations dynamically to EACH batch slice utilizing PercentageRandomizing
			local isCritHit = false
			local isMegaCritHit = false
			
			local rawCrit = (data.Stats.CriticalChance or 0.01) + (data.Stats.CritChanceBonus or 0)
			local rawMega = data.Stats.MegaCritChance or 0.01
			
			local critPct = rawCrit * 100
			local megaPct = rawMega * 100
			
			if critPct > 100 then
				local overCrit = critPct - 100
				critPct = 100
				megaPct = megaPct + overCrit
			end
			
			local trueMegaPct = critPct * (math.min(100, megaPct) / 100)
			local trueCritPct = critPct - trueMegaPct
			local normalPct = math.max(0, 100 - (trueCritPct + trueMegaPct))
			
			local critResult = PercentageRandomizing({
				["Normal"] = normalPct,
				["Critical"] = trueCritPct,
				["MegaCritical"] = trueMegaPct
			})
			
			if critResult == "Critical" or critResult == "MegaCritical" then
				if critResult == "MegaCritical" then
					isMegaCritHit = true
					local megaPower = data.Stats.MegaCritPower or 10.0
					grossAmount = math.floor(grossAmount * megaPower)
				else
					isCritHit = true
					local critPower = GetCritPower(data)
					grossAmount = math.floor(grossAmount * critPower)
				end
			end
			
			-- Instant Conversion applied to collective total
			local finalToBackpack, bioGained = ApplyInstantConversion(player, data, grossAmount, entry.samplePos, true)
			
			-- Backpack Clamp
			local currentPl = 0; for _,v in pairs(data.Plankton) do currentPl += v end
			local spaceLeft = data.MaxCapacity - currentPl
			finalToBackpack = math.max(0, math.min(finalToBackpack, spaceLeft))
			
			local combinedGross = finalToBackpack + bioGained
			
			if combinedGross > 0 then
				local rType = entry.rType
				data.Plankton[rType] = (data.Plankton[rType] or 0) + finalToBackpack
				data.LifetimeAlgae = (data.LifetimeAlgae or 0) + finalToBackpack
				TrackAlgaePerSecond(data, finalToBackpack)
				
				-- Batch Visuals
				if not harvestBatches[rType] then harvestBatches[rType] = {total=0, grossTotal=0, positions={}, crits=0, megaCrits=0} end
				harvestBatches[rType].total += finalToBackpack
				harvestBatches[rType].grossTotal += combinedGross
				table.insert(harvestBatches[rType].positions, entry.samplePos)
				if isCritHit then
					harvestBatches[rType].crits = (harvestBatches[rType].crits or 0) + 1
				elseif isMegaCritHit then
					harvestBatches[rType].megaCrits = (harvestBatches[rType].megaCrits or 0) + 1
				end

				-- Quest Update (Use combinedGross once for the whole type-batch)
				for questId, qData in pairs(GetActiveQuests(data, player)) do
					local qConfig = qData.Config
					local progress = qData.Progress
					if qConfig then
						local reqMet = true
						if qConfig.RequiredBackpack and data.EquippedBackpack ~= qConfig.RequiredBackpack then reqMet = false end
						
						if reqMet then
							if qConfig.Goals then
								if type(progress) ~= "table" then progress = {} end
								
								if qConfig.Goals[rType] then
									local curProg = progress[rType] or 0
									local lim = qConfig.Goals[rType]
									local nxt = curProg + combinedGross
									if nxt > lim then nxt = lim end
									progress[rType] = nxt
								end
								
								if entry.fieldName then
									local fieldKey = entry.fieldName .. "_" .. rType
									if qConfig.Goals[fieldKey] then
										local curProg = progress[fieldKey] or 0
										local nxt = curProg + combinedGross
										if nxt > qConfig.Goals[fieldKey] then nxt = qConfig.Goals[fieldKey] end
										progress[fieldKey] = nxt
									end
									
									if qConfig.Goals[entry.fieldName] then
										local curProg = progress[entry.fieldName] or 0
										local nxt = curProg + combinedGross
										if nxt > qConfig.Goals[entry.fieldName] then nxt = qConfig.Goals[entry.fieldName] end
										progress[entry.fieldName] = nxt
									end
								end
								data.ActiveQuests[questId] = progress
							else
								-- Single Goal
								local locMatch = not qConfig.TargetLocation or qConfig.TargetLocation == entry.fieldName
								if locMatch and (qConfig.TargetResource == "Any" or qConfig.TargetResource == rType) then
									local curProg = tonumber(progress) or 0
									local nxt = curProg + combinedGross
									if nxt > qConfig.GoalAmount then nxt = qConfig.GoalAmount end
									data.ActiveQuests[questId] = nxt
								end
							end
						end
					end
				end
			end
		end
		
		PlayerData.SetDirty(player, "Quests")
		
		return data
	end)
	
	-- Fire Visuals (Direct fire to show all colors)
	local totalCrits = 0
	for rType, batch in pairs(harvestBatches) do
		if batch.total > 0 and #batch.positions > 0 then
			local avg = Vector3.new(); for _,p in ipairs(batch.positions) do avg+=p end
			avg = avg / #batch.positions
			
			local resType = ResourceConfig.Types[rType]
			local color = (resType and resType.Color) or Color3.new(1,1,1)
			-- Fire directly instead of AddToBatch to ensure all colors show
			VisualEvent:FireClient(player, avg + Vector3.new(0,2,0), batch.total, color, (batch.crits or 0) > 0, false, nil, nil, nil, (batch.megaCrits or 0) > 0)
			
			local SeaMineService = require(script.Parent.SeaMineService)
			SeaMineService.AddAlgae(player, avg, batch.grossTotal)
			
			-- Track total crits
			totalCrits = totalCrits + (batch.crits or 0)
		end
	end
	
	return totalGained
end


local function handleSunkissedAttachments(character, doEquip, toolOverride)
	local rHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local lHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	local tool = toolOverride or character:FindFirstChild("Sunkissed Art") or character:FindFirstChild("SunkissedArt")
	
	if doEquip and tool then
		local attTemplate = tool:FindFirstChildWhichIsA("Attachment", true)
		if attTemplate then
			if rHand and not rHand:FindFirstChild("SunkissedAttachmentServer") then
				local c = attTemplate:Clone()
				c.Name = "SunkissedAttachmentServer"
				c.Parent = rHand
			end
			if lHand and not lHand:FindFirstChild("SunkissedAttachmentServer") then
				local c = attTemplate:Clone()
				c.Name = "SunkissedAttachmentServer"
				c.Parent = lHand
			end
		end
	else
		if rHand then
			for _, d in ipairs(rHand:GetChildren()) do
				if d.Name == "SunkissedAttachmentServer" then d:Destroy() end
			end
		end
		if lHand then
			for _, d in ipairs(lHand:GetChildren()) do
				if d.Name == "SunkissedAttachmentServer" then d:Destroy() end
			end
		end
	end
end

-- Tool Spawning Logic (Ensure player starts with equipped tool)
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and (child.Name == "Sunkissed Art" or child.Name == "SunkissedArt") then
				task.delay(0.1, function()
					handleSunkissedAttachments(char, true, child)
				end)
			end
		end)
		
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and (child.Name == "Sunkissed Art" or child.Name == "SunkissedArt") then
				handleSunkissedAttachments(char, false)
			end
		end)

		task.spawn(function()
			if not player or not player.Parent then return end
			
			local data = nil
			-- Wait for data to load
			while player.Parent do
				data = PlayerData.get(player)
				if data then break end
				task.wait(0.5)
			end
			
			if not player.Parent or not data then return end
			
			local toolName = data.EquippedTool or "Fishing Net"
			
			-- Check if already has it
			local existingTool = player.Backpack:FindFirstChild(toolName) or char:FindFirstChild(toolName)
			if existingTool then
				existingTool.CanBeDropped = false
				local humanoid = char:FindFirstChild("Humanoid")
				if existingTool.Parent == player.Backpack and humanoid then
					task.delay(0.1, function()
						if humanoid.Parent and existingTool.Parent == player.Backpack then
							humanoid:EquipTool(existingTool)
						end
					end)
				end
				return
			end
			
			local tools = ReplicatedStorage:FindFirstChild("Tools")
			local toolModel = tools and tools:FindFirstChild(toolName)
			
			if toolModel then
				local clone = toolModel:Clone()
				clone.CanBeDropped = false
				clone.Parent = player.Backpack
				
				-- Ensure the tool is physically equipped when they spawn
				local humanoid = char:FindFirstChild("Humanoid")
				if humanoid then
					task.delay(0.1, function()
						if clone.Parent == player.Backpack and humanoid.Parent then
							humanoid:EquipTool(clone)
						end
					end)
				end
			else
				-- warn("Tool not found in ReplicatedStorage: " .. toolName)
			end
		end)
	end)
end)

function HarvestService.HarvestBatch(player, parts, amount, skipVisual, consolidateVisuals)
	ExecuteHarvestBatch(player, parts, {CapacityBurn = amount}, skipVisual, consolidateVisuals)
end

function HarvestService.HarvestTarget(player, targetPart, amount, skipVisual, optionalConvertMult)
	if not targetPart or not targetPart:IsA("BasePart") then 

		return 0 
	end

	local cap = targetPart:FindFirstChild("Capacity")
	if not cap or cap.Value <= 0 then 
		return 
	end
	local algaeAmt = targetPart:FindFirstChild("AlgaeAmount")
	-- Standardize: Unit is the full AlgaeAmount (Per Capacity). 
	-- Previous code divided by 4, creating inconsistency with ExecuteHarvestBatch.
	local unitVal = algaeAmt and algaeAmt.Value

	local burn = math.min(amount, cap.Value)

	local capturedYield = 0
	PlayerData.update(player, function(data)
		-- ABILITY CONVERSION MODE (Bypass Bag, Direct O2)
		if optionalConvertMult then
			local totalMult = GetAlgaeMultipliers(data, targetPart, true)
            
            local critChance = (data.Stats.CriticalChance or 0.01) + (data.Stats.CritChanceBonus or 0)
			local isCrit = HarvestService.RollPRD(data, critChance)
			local critMult = isCrit and GetCritPower(data) or 1

            local rawYield = (unitVal * burn) * totalMult * critMult
            local biomass = math.floor(rawYield * optionalConvertMult + 0.5)
            
            if biomass > 0 then
	            data.Biomass = (data.Biomass or 0) + biomass
	            capturedYield = biomass
	            
	            -- Leaderstats
	            local ls = player:FindFirstChild("leaderstats")
	            if ls and ls:FindFirstChild("Biomass") then ls.Biomass.Value = data.Biomass end
	            
	            -- Visual (If not skipped)
	            if not skipVisual then
	                local VisualEvent = Remotes:FindFirstChild("VisualEvent")
	                if VisualEvent then
	                	-- 5th arg: IsBiomass=true (VisualEvent typically: Pos, Amt, Color, IsCrit, IsBiomass)
	                	VisualEvent:FireClient(player, targetPart.Position + Vector3.new(0,2,0), biomass, Color3.fromRGB(0, 255, 255), isCrit, true)
	                end
	            end

				-- Quest Update (Even for Direct Conversion)
				for questId, qData in pairs(GetActiveQuests(data, player)) do
					local qConfig = qData.Config
					local progress = qData.Progress
					if qConfig then
						if qConfig.Goals then
							if type(progress) ~= "table" then progress = {} end
							if qConfig.Goals[targetPart.Name] then
								local cur = progress[targetPart.Name] or 0
								local nxt = cur + rawYield
								if nxt > qConfig.Goals[targetPart.Name] then nxt = qConfig.Goals[targetPart.Name] end
								progress[targetPart.Name] = nxt
							end
							local fieldName = GetFieldName(targetPart)
							if fieldName and qConfig.Goals[fieldName] then
								local cur = progress[fieldName] or 0
								local nxt = cur + rawYield
								if nxt > qConfig.Goals[fieldName] then nxt = qConfig.Goals[fieldName] end
								progress[fieldName] = nxt
							end
							data.ActiveQuests[questId] = progress
						else
							if qConfig.TargetResource == "Any" or qConfig.TargetResource == targetPart.Name then
								local fieldName = GetFieldName(targetPart)
								if not qConfig.TargetLocation or qConfig.TargetLocation == fieldName then
									local cur = tonumber(progress) or 0
									local nxt = cur + rawYield
									if nxt > qConfig.GoalAmount then nxt = qConfig.GoalAmount end
									data.ActiveQuests[questId] = nxt
								end
							end
						end
					end
				end
            end
            return data, capturedYield
		end

		local currentPl = 0
		if data.Plankton then
			for _,c in pairs(data.Plankton) do currentPl += c end
		end
		if currentPl >= data.MaxCapacity then 
			-- Return 0 yield instead of nil to prevent capacity reduction without reward
			return data, 0 
		end

		-- Multipliers
		local totalMult = GetAlgaeMultipliers(data, targetPart)
		
		-- Critical Hit
		local critChance = (data.Stats.CriticalChance or 0.01) + (data.Stats.CritChanceBonus or 0)
		local isCrit = HarvestService.RollPRD(data, critChance)
		local critMult = isCrit and GetCritPower(data) or 1
		
		local toolMult = data.Stats.ToolAlgae or 1.0
		local yield = math.floor((unitVal * burn) * totalMult * toolMult * critMult + 0.5)
		local space = data.MaxCapacity - currentPl
		local finalYield = math.min(yield, space)
		if finalYield <= 0 then return data, 0 end
		
		local grossYield = finalYield -- Amount before conversion

		-- Quest Update (Use gross amount before conversion)
		for questId, qData in pairs(GetActiveQuests(data, player)) do
			local qConfig = qData.Config
			local progress = qData.Progress
			if qConfig then
				-- Requirement Check
				local reqMet = true
				if qConfig.RequiredBackpack and data.EquippedBackpack ~= qConfig.RequiredBackpack then reqMet = false end
				
				if reqMet then
					if qConfig.Goals then
						-- Multi-Goal
						if type(progress) ~= "table" then progress = {} end
						if qConfig.Goals[targetPart.Name] then
							local current = progress[targetPart.Name] or 0
							local limit = qConfig.Goals[targetPart.Name]
							local nxt = current + grossYield
							if nxt > limit then nxt = limit end
							progress[targetPart.Name] = nxt
						end
						
						-- Check Field_Resource Goal
						local fieldName = GetFieldName(targetPart)
						if fieldName then
							local key = fieldName .. "_" .. targetPart.Name
							if qConfig.Goals[key] then
								local current = progress[key] or 0
								local limit = qConfig.Goals[key]
								local nxt = current + grossYield
								if nxt > limit then nxt = limit end
								progress[key] = nxt
							end
						end
						
						-- Generic Field Goal
						if fieldName and qConfig.Goals[fieldName] then
							local current = progress[fieldName] or 0
							local limit = qConfig.Goals[fieldName]
							local nxt = current + grossYield
							if nxt > limit then nxt = limit end
							progress[fieldName] = nxt
						end
						data.ActiveQuests[questId] = progress
					else
						-- Single Goal
						if (qConfig.TargetResource == "Any" or qConfig.TargetResource == targetPart.Name) then
							local fieldName = GetFieldName(targetPart)
							if not qConfig.TargetLocation or qConfig.TargetLocation == fieldName then
								local current = tonumber(progress) or 0
								local nxt = current + grossYield
								if nxt > qConfig.GoalAmount then nxt = qConfig.GoalAmount end
								data.ActiveQuests[questId] = nxt
							end
						end
					end
				end
			end
		end

		PlayerData.SetDirty(player, "Quests")

		-- Instant Conversion
		finalYield = ApplyInstantConversion(player, data, finalYield, targetPart.Position, skipVisual)
		capturedYield = finalYield

		data.Plankton[targetPart.Name] = (data.Plankton[targetPart.Name] or 0) + finalYield
		data.LifetimeAlgae = (data.LifetimeAlgae or 0) + finalYield
		TrackAlgaePerSecond(data, finalYield)

		-- Leaderstats
		local ls = player:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Algae") then ls.Algae.Value = currentPl + finalYield end

		-- Visual Event to Client
		if not skipVisual then
			local resType = ResourceConfig.Types[targetPart.Name]
			local color = (resType and resType.Color) or Color3.new(1,1,1)
			VisualEvent:FireClient(player, targetPart.Position + Vector3.new(0,2,0), finalYield, color, isCrit)
		end

		return data, capturedYield
	end, skipVisual) -- Pass skipVisual as skipRemote
	
	-- Return yield to caller
	-- Note: PlayerData.update returns updatedData. We need to extract yield inside or compute it again?
	-- Or rely on upvalue modification? `finalYield` is local inside callback.
	-- PlayerData.update logic: returns what callback returns.
	
	-- Let's change this to capturing yield via upvalue.


	-- Physical Update
	cap.Value -= burn
	
	-- Mark Dirty
	local FieldService = require(script.Parent.FieldService)
	FieldService.MarkDirty(targetPart)

	-- Shrink Logic (Removed: Visuals handled by Client FieldController listening to .Value change)
	
	return capturedYield
end

function HarvestService.RefillTarget(player, targetPart, amount)
	if not targetPart or not targetPart:IsA("BasePart") then return end
	
	-- Validate Fields
	local cap = targetPart:FindFirstChild("Capacity")
	local algaeAmt = targetPart:FindFirstChild("AlgaeAmount")
	if not cap or not algaeAmt then return end
	
	local origSize = targetPart:GetAttribute("OriginalSize")
	if not origSize then origSize = targetPart.Size; targetPart:SetAttribute("OriginalSize", origSize) end
	local origCF = targetPart:GetAttribute("OriginalCFrame")
	if not origCF then origCF = targetPart.CFrame; targetPart:SetAttribute("OriginalCFrame", origCF) end

	-- 1. Give Loot to Player (as if harvested)
	local gainAmount = amount -- usually 1
	local unitVal = algaeAmt.Value
	
	PlayerData.update(player, function(data)
		local currentTotal = 0
		if data.Plankton then
			for _, c in pairs(data.Plankton) do currentTotal += c end
		end
		
		-- Multipliers
		local totalMult = GetAlgaeMultipliers(data, targetPart)
		
		local AbilityService: any = require(script.Parent.AbilityService)
		local abilityMult = 1
		if AbilityService.GetAlgaeBoostMultiplier then
			abilityMult = AbilityService.GetAlgaeBoostMultiplier(player)
		end
		
		-- Critical Hit
		local critChance = (data.Stats.CriticalChance or 0.01) + (data.Stats.CritChanceBonus or 0)
		local isCrit = math.random() < critChance
		local critMult = isCrit and GetCritPower(data) or 1
		
		local yield = math.floor((unitVal * gainAmount) * totalMult * abilityMult * critMult + 0.5)
		local space = data.MaxCapacity - currentTotal
		-- If full, we still allow refill but maybe no loot? 
		-- "should get the amount... from each algae being refilled"
		-- If backpack full, they get nothing.
		local finalYield = math.max(0, math.min(yield, space))
		
		if finalYield > 0 then
			local convRate = data.Stats.InstantConversion or 0
			if convRate > 0 and finalYield > 0 then
				local converted = math.floor(finalYield * convRate)
				if converted < 1 then converted = 1 end
				
				-- Bonus only
				-- finalYield = finalYield - converted (REMOVED)
				data.Biomass = (data.Biomass or 0) + converted
				
				-- Fire Visual (Assuming VisualEvent upvalue is visible, otherwise find it from Remotes)
				local HelperRemotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
				local HelperVis = HelperRemotes:FindFirstChild("VisualEvent")
				if HelperVis then
					HelperVis:FireClient(player, targetPart.Position, converted, Color3.new(1,1,1), false, false, nil, 0.7)
				end
			end
			
			data.Plankton[targetPart.Name] = (data.Plankton[targetPart.Name] or 0) + finalYield
			
			-- Quest Logic (Use gross amount before conversion)
			for questId, qData in pairs(GetActiveQuests(data, player)) do
				local qConfig = qData.Config
				local progress = qData.Progress
				local grossYield = yield -- Amount before conversion or space check? yield is before space check.
				-- Actually we should use finalYield (limited by space) to stay consistent.
				local questAmount = finalYield 
				
				if qConfig then
					if qConfig.Goals then
						-- Multi-Goal
						if type(progress) ~= "table" then progress = {} end
						if qConfig.Goals[targetPart.Name] then
							local current = progress[targetPart.Name] or 0
							local limit = qConfig.Goals[targetPart.Name]
							local nxt = current + questAmount
							if nxt > limit then nxt = limit end
							progress[targetPart.Name] = nxt
						end
						-- Generic Field Goal (NoobieTurtle field-keyed goals)
						local fName = GetFieldName(targetPart)
						if fName and qConfig.Goals[fName] then
							local current = progress[fName] or 0
							local limit = qConfig.Goals[fName]
							local nxt = current + questAmount
							if nxt > limit then nxt = limit end
							progress[fName] = nxt
						end
						data.ActiveQuests[questId] = progress

					else
						-- Single Goal
						if (qConfig.TargetResource == "Any" or qConfig.TargetResource == targetPart.Name) then
							local current = tonumber(progress) or 0
							local nxt = current + questAmount
							if nxt > qConfig.GoalAmount then nxt = qConfig.GoalAmount end
							data.ActiveQuests[questId] = nxt
						end
					end
				end
			end
			
			PlayerData.SetDirty(player, "Quests")
			
			local ls = player:FindFirstChild("leaderstats")
			if ls and ls:FindFirstChild("Algae") then ls.Algae.Value = currentTotal + finalYield end
			
			-- Visual LOOT
			local HelperVis = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("VisualEvent")
			if HelperVis then
				local resType = require(game.ReplicatedStorage.Shared.ResourceConfig).Types[targetPart.Name]
				local color = (resType and resType.Color) or Color3.new(1,1,1)
				HelperVis:FireClient(player, targetPart.Position + Vector3.new(0,2,0), finalYield, color, isCrit)
			end
		end
		return data
	end)
	
	-- 2. Refill Capacity
	cap.Value = cap.Value + amount
	
	-- 3. Restore Visuals (Removed: Visuals handled by Client FieldController listening to .Value change)
end





function HarvestService.BatchedRefill(player, parts, amount)
	local FieldService = require(script.Parent.FieldService)
	for _, part in ipairs(parts) do
		local cap = part:FindFirstChild("Capacity")
		if cap then
			local current = cap.Value
			local max = part:GetAttribute("MaxCapacity") or 100
			if current < max then
				local newVal = current + amount
				if newVal > max then newVal = max end
				cap.Value = newVal
				-- Visuals handled by Client FieldController listening to .Value change
			end
		end
	end
end

-- Cleanup caches
Players.PlayerRemoving:Connect(function(player)
	PoseidonCooldowns[player.UserId] = nil
	PlayerBatches[player.UserId] = nil
	PlayerBiomassBatches[player.UserId] = nil
end)

return HarvestService
