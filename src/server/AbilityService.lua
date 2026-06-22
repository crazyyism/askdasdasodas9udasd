local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local FishConfig = require(ReplicatedStorage.Shared.FishConfig)
local QuestConfig = require(ReplicatedStorage.Shared.QuestConfig)
local PlayerData = require(script.Parent.PlayerData)
local FishService = require(script.Parent.FishService)
local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
local MobService = require(script.Parent.MobService)

local AbilityService = {}
AbilityService.ExpectedRhythmHits = {}

-- Track player ability buffs
-- Structure: PlayerBuffs[player.UserId] = {AlgaeBoost = {Stacks = 5, ExpiresAt = os.time() + 30}}
local PlayerBuffs = {}
local playerFishPositions = {} -- [userId] = {[indexStr] = position}
local AbilityCooldowns = {} -- [UserId] = { [FishIndex] = NextTime }
local ActivePins = {} -- {Hitbox=Part, Position=V3, Radius=N, Expires=Time, BoostAmount=N}

-- SetupRemoteEvent
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end


local TriggerAbilityEvent = Remotes:FindFirstChild("TriggerAbilityEvent")
if not TriggerAbilityEvent then
	TriggerAbilityEvent = Instance.new("RemoteEvent")
	TriggerAbilityEvent.Name = "TriggerAbilityEvent"
	TriggerAbilityEvent.Parent = Remotes
end
local AbilityBuffUpdate = Remotes:FindFirstChild("AbilityBuffUpdate")
if not AbilityBuffUpdate then
	AbilityBuffUpdate = Instance.new("RemoteEvent")
	AbilityBuffUpdate.Name = "AbilityBuffUpdate"
	AbilityBuffUpdate.Parent = Remotes
end

local VFXReplication = Remotes:FindFirstChild("VFXReplication")
if not VFXReplication then
	VFXReplication = Instance.new("RemoteEvent")
	VFXReplication.Name = "VFXReplication"
	VFXReplication.Parent = Remotes
end

local FishReplicationEvent = Remotes:FindFirstChild("FishReplicationEvent")
if not FishReplicationEvent then
	FishReplicationEvent = Instance.new("RemoteEvent")
	FishReplicationEvent.Name = "FishReplicationEvent"
	FishReplicationEvent.Parent = Remotes
end

local BackpackReplicationEvent = Remotes:FindFirstChild("BackpackReplicationEvent")
if not BackpackReplicationEvent then
	BackpackReplicationEvent = Instance.new("RemoteEvent")
	BackpackReplicationEvent.Name = "BackpackReplicationEvent"
	BackpackReplicationEvent.Parent = Remotes
end

local RhythmGameEvent = Remotes:FindFirstChild("RhythmGameEvent")
if not RhythmGameEvent then
	RhythmGameEvent = Instance.new("RemoteEvent")
	RhythmGameEvent.Name = "RhythmGameEvent"
	RhythmGameEvent.Parent = Remotes
end

local RhythmHitEvent = Remotes:FindFirstChild("RhythmHitEvent")
if not RhythmHitEvent then
	RhythmHitEvent = Instance.new("RemoteEvent")
	RhythmHitEvent.Name = "RhythmHitEvent"
	RhythmHitEvent.Parent = Remotes
end

local RhythmMissEvent = Remotes:FindFirstChild("RhythmMissEvent")
if not RhythmMissEvent then
	RhythmMissEvent = Instance.new("RemoteEvent")
	RhythmMissEvent.Name = "RhythmMissEvent"
	RhythmMissEvent.Parent = Remotes
end

local DataUpdateEvent = Remotes:FindFirstChild("DataUpdateEvent")
if not DataUpdateEvent then
	DataUpdateEvent = Instance.new("RemoteEvent")
	DataUpdateEvent.Name = "DataUpdateEvent"
	DataUpdateEvent.Parent = Remotes
end

local PinBoostConvertEvent = Remotes:FindFirstChild("PinBoostConvertEvent")
if not PinBoostConvertEvent then
	PinBoostConvertEvent = Instance.new("RemoteEvent")
	PinBoostConvertEvent.Name = "PinBoostConvertEvent"
	PinBoostConvertEvent.Parent = Remotes
end

local FishStateRelay = Remotes:FindFirstChild("FishStateRelay")
if not FishStateRelay then
	FishStateRelay = Instance.new("RemoteEvent")
	FishStateRelay.Name = "FishStateRelay"
	FishStateRelay.Parent = Remotes
end

FishStateRelay.OnServerEvent:Connect(function(player, stateData)
	-- Store for server logic (like Black Hole)
	if not playerFishPositions[player.UserId] then
		playerFishPositions[player.UserId] = {}
	end
	for index, data in pairs(stateData) do
		if data.CF then
			playerFishPositions[player.UserId][tostring(index)] = data.CF.Position
		end
	end

	-- Relay to everyone EXCEPT the sender
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			FishStateRelay:FireClient(other, player.UserId, stateData)
		end
	end
end)

function AbilityService.GetToolBoostMultiplier(player)
	local userId = player.UserId
	if not PlayerBuffs[userId] then return 1 end

	local boostData = PlayerBuffs[userId].ToolBoost
	if not boostData then return 1 end

	if os.time() >= boostData.ExpiresAt then
		PlayerBuffs[userId].ToolBoost = nil
		return 1
	end

	-- Calculate multiplier: Additive (1 + StackAmount * stacks)
	local stackAmt = boostData.StackAmount or 0.25
	return 1 + (stackAmt * boostData.Stacks)
end

function AbilityService.IncrementAbilitiesCommitted(player)
	PlayerData.update(player, function(data)
		data.AbilitiesCommitted = (data.AbilitiesCommitted or 0) + 1
		-- If an active quest tracks AbilitiesCommitted, mark quests dirty so the
		-- client quest UI reflects the new count immediately.
		if data.ActiveQuests then
			for qId, _ in pairs(data.ActiveQuests) do
				local qCfg = QuestConfig.Quests[qId]
				if qCfg and qCfg.Goals and qCfg.Goals["AbilitiesCommitted"] then
					data._QuestsDirty = true
					break
				end
			end
		end
		return data
	end)
end

function AbilityService.SpawnMitosisClone(player)
	-- Use a dedicated server-side runtime storage for temporary fish
	if not _G.TemporaryFish then _G.TemporaryFish = {} end
	
	local data = PlayerData.get(player)
	if not data or not data.FishSchool then return end
	
	local school = data.FishSchool
	
	-- 1. Select Random Fish to Clone
	local keys = {}
	local maxIndex = 0
	for k, v in pairs(school) do
		if tonumber(k) then 
			table.insert(keys, k) 
			if tonumber(k) > maxIndex then maxIndex = tonumber(k) end
		end
	end
	
	local pool = {}
	for _, k in ipairs(keys) do
		local f = school[k]
		if f and f.Id ~= "Mirror Fish" and not f.IsTemporary then
			table.insert(pool, {Key = k, Fish = f})
		end
	end
	
	if #pool == 0 then return end
	
	local selected = pool[math.random(1, #pool)]
	local targetFish = selected.Fish
	
	-- Use a high index for temporary fish (1000+)
	local cloneIndex = 1000 + math.random(1, 9999)
	while school[tostring(cloneIndex)] or (_G.TemporaryFish[player.UserId] and _G.TemporaryFish[player.UserId][tostring(cloneIndex)]) do
		cloneIndex += 1
	end
	
	local cloneData = {
		Id = targetFish.Id,
		UniqueId = HttpService:GenerateGUID(false),
		IsTemporary = true,
		ExpiresAt = os.time() + 30,
		VisualOverride = {
			Color = Color3.fromRGB(0, 255, 255), -- Neon Blue/Cyan
			Transparency = 0.5,
			Material = Enum.Material.Neon
		}
	}
	
	-- Store in runtime table
	if not _G.TemporaryFish[player.UserId] then
		_G.TemporaryFish[player.UserId] = {}
	end
	_G.TemporaryFish[player.UserId][tostring(cloneIndex)] = cloneData
	
	-- Send via FishReplicationEvent with ONLY the temporary fish
	if FishReplicationEvent then
		-- Create a packet: {OwnerUserId = id, [cloneIndex] = cloneData}
		local tempPacket = {OwnerUserId = player.UserId, [tostring(cloneIndex)] = cloneData, __IsTemporary = true}
		FishReplicationEvent:FireAllClients(tempPacket)
	end
	
	-- Schedule Removal
	task.delay(20, function()
		if _G.TemporaryFish[player.UserId] then
			_G.TemporaryFish[player.UserId][tostring(cloneIndex)] = nil
			
			-- Send removal signal (Use false instead of nil so it iterates in pairs)
			if FishReplicationEvent then
				local removalPacket = {OwnerUserId = player.UserId, [tostring(cloneIndex)] = false, __IsTemporary = true}
				FishReplicationEvent:FireAllClients(removalPacket)
			end
		end
	end)
end

-- Helper: Resolve ability name to full config
local function GetAbilityConfig(fishConfig)
	if not fishConfig then return nil end
	
	-- New system: AbilityName references FishConfig.Abilities
	if fishConfig.AbilityName then
		return FishConfig.Abilities[fishConfig.AbilityName]
	end
	
	-- Legacy system: Ability is inline
	if fishConfig.Ability then
		return fishConfig.Ability
	end
	
	return nil
end

-- Helper: Resolve buff name to full config
local function GetBuffConfig(buffName)
	return FishConfig.Buffs[buffName]
end

-- Apply Algae Boost ability
local function ApplyAlgaeBoost(player, fishId, extraData)
	local config = FishConfig.Fish[fishId]
	local ability = GetAbilityConfig(config)
	if not ability or ability.Name ~= "Algae Boost" then return end
	
	local userId = player.UserId
	if not PlayerBuffs[userId] then
		PlayerBuffs[userId] = {}
	end
	
	local currentBoost = PlayerBuffs[userId].AlgaeBoost
	
	if not currentBoost then
		-- First stack
		PlayerBuffs[userId].AlgaeBoost = {
			Stacks = 1,
			Multiplier = ability.BoostMultiplier,
			MaxStacks = ability.MaxStacks,
			ExpiresAt = os.time() + ability.Duration
		}
		print("AbilityService: " .. player.Name .. " gained Algae Boost (Stack 1)")
	elseif currentBoost.Stacks < currentBoost.MaxStacks then
		-- Add stack
		currentBoost.Stacks = currentBoost.Stacks + 1
		currentBoost.ExpiresAt = os.time() + ability.Duration -- Refresh timer
		print("AbilityService: " .. player.Name .. " Algae Boost stacked to " .. currentBoost.Stacks)
		if currentBoost.Stacks == currentBoost.MaxStacks then
			PlayerData.IncrementQuestGoal(player, "MaxStacksReached", 1)
		end
	else
		-- Max stacks reached, just refresh timer
		currentBoost.ExpiresAt = os.time() + ability.Duration
		print("AbilityService: " .. player.Name .. " Algae Boost timer refreshed (Max stacks: " .. currentBoost.MaxStacks .. ")")
		currentBoost.ExpiresAt = os.time() + ability.Duration
		print("AbilityService: " .. player.Name .. " Algae Boost timer refreshed (Max stacks: " .. currentBoost.MaxStacks .. ")")
	end
	
	-- Apply Multiplier (Mirror Fish)
	if extraData and extraData.Multiplier then
		local baseMult = ability.BoostMultiplier - 1
		local newMult = 1 + (baseMult * extraData.Multiplier)
		local currentStacks = PlayerBuffs[userId].AlgaeBoost.Stacks
		
		-- Recalculate stored multiplier? No, stored is per-stack.
		-- We need to update the effective multiplier for this stack?
		-- Complex. Simplified: Just apply the multiplier to the *duration* as a proxy for power?
		-- Or better: temporarily boost the stack's multiplier value in the table? 
		-- Issue: If we change the Multiplier in the PlayerBuffs table, it affects ALL stacks.
		-- Mirror Fish is rare/mythic. Let's make it powerful.
		-- If we just updated duration, it's safe.
		PlayerBuffs[userId].AlgaeBoost.ExpiresAt = os.time() + (ability.Duration * extraData.Multiplier)
	end
	
	-- Notify client for UI/VFX
	local boostInfo = PlayerBuffs[userId].AlgaeBoost
	AbilityBuffUpdate:FireClient(player, "AlgaeBoost", boostInfo.Stacks, boostInfo.ExpiresAt)
	
	-- Update PlayerData Stat for UI Sync
	AbilityService.UpdatePlayerStats(player)
end

local function ApplyToolBoost(player, config)
	local userId = player.UserId
	if not PlayerBuffs[userId] then PlayerBuffs[userId] = {} end
	
	local settings = (config and config.ToolBoostStats) or {}
	local duration = settings.Duration or 10
	local stackAmount = settings.StackAmount or 0.25
	
	local current = PlayerBuffs[userId].ToolBoost
	local stacksChanged = false
	
	if not current then
		PlayerBuffs[userId].ToolBoost = {
			Stacks = 1,
			ExpiresAt = os.time() + duration,
			StackAmount = stackAmount,
			LastSent = 0
		}
		stacksChanged = true
	else
		local oldStacks = current.Stacks
		current.Stacks += 1
		stacksChanged = true
		current.ExpiresAt = os.time() + duration
		current.StackAmount = stackAmount -- Update if changed dynamically?
	end
	
	local now = os.clock()
	local info = PlayerBuffs[userId].ToolBoost
	
	-- Optimize: Only recalculate stats if stacks changed
	if stacksChanged then
		AbilityService.UpdatePlayerStats(player)
	end
	
	-- Notify Client (Throttle refreshes)
	if AbilityBuffUpdate and (stacksChanged or (now - (info.LastSent or 0) > 1.0)) then
		AbilityBuffUpdate:FireClient(player, "ToolAlgae", info.Stacks, info.ExpiresAt)
		info.LastSent = now
	end
end

-- Helper: Apply Pin Boost (Stackable by multiple pins)
local function ApplyPinBoost(player, boostAmount)
	local userId = player.UserId
	if not PlayerBuffs[userId] then PlayerBuffs[userId] = {} end
	
	-- Pin Boost is stackable - each pin adds to the stack
	if not PlayerBuffs[userId].PinBoost then
		PlayerBuffs[userId].PinBoost = {
			Stacks = 1,
			BoostAmount = boostAmount
		}
		
		-- Spawn the 2-second passive conversion tick (converts 1% algae per stack → Biomass)
		task.spawn(function()
			while player.Parent and PlayerBuffs[userId] and PlayerBuffs[userId].PinBoost do
				task.wait(2)
				-- Re-check after wait: buff may have expired
				if not player.Parent or not PlayerBuffs[userId] or not PlayerBuffs[userId].PinBoost then break end
				
				local stacks = PlayerBuffs[userId].PinBoost.Stacks
				local conversionRate = 0.025  * stacks  -- 1% per stack (e.g. 3 stacks = 3%)
				
				PlayerData.update(player, function(data)
					if not data or not data.Plankton then return nil end
					
					-- Count total algae
					local totalAlgae = 0
					for _, amt in pairs(data.Plankton) do
						totalAlgae += math.max(0, tonumber(amt) or 0)
					end
					if totalAlgae <= 0 then return nil end
					
					-- How much algae to pull this tick
					local toConvert = math.max(1, math.floor(totalAlgae * conversionRate))
					local convertMult  = (data.Stats and data.Stats.ConvertMultiplier) or 1
					local bioPerAlgae  = (data.Stats and data.Stats.BiomassPerAlgae)  or 1
					
					-- Drain proportionally across all algae types to avoid depleting one type
					local biomassGained = 0
					local remaining = toConvert
					for typeName, amt in pairs(data.Plankton) do
						if remaining <= 0 then break end
						local take = math.min(
							math.ceil(amt / totalAlgae * toConvert),  -- proportional share
							math.floor(amt),                           -- can't take more than available
							remaining                                  -- don't over-convert
						)
						if take > 0 then
							local resType  = ResourceConfig.Types[typeName]
							local baseVal  = (resType and resType.BaseValue) or 1
							data.Plankton[typeName] -= take
							biomassGained += take * baseVal * convertMult * bioPerAlgae
							remaining -= take
						end
					end
										if biomassGained <= 0 then return nil end
					
					data.Biomass = (data.Biomass or 0) + biomassGained
					data.LifetimeBiomass = (data.LifetimeBiomass or 0) + biomassGained
					
					-- Sync leaderstats so counter ticks up visibly
					local ls = player:FindFirstChild("leaderstats")
					if ls then
						local bio = ls:FindFirstChild("Biomass")
						local alg = ls:FindFirstChild("Algae")
						if bio then bio.Value = data.Biomass end
						if alg then
							local newTotal = 0
							for _, a in pairs(data.Plankton) do newTotal += a end
							alg.Value = newTotal
						end
					end
					
					-- Fire visual event so the client can show beam + text
					PinBoostConvertEvent:FireClient(player, biomassGained, toConvert)
					
					return data
				end)
			end
		end)
	else
		PlayerBuffs[userId].PinBoost.Stacks += 1
	end
	
	-- Update player stats
	AbilityService.UpdatePlayerStats(player)
	
	-- Notify client
	if AbilityBuffUpdate then
		local info = PlayerBuffs[userId].PinBoost
		AbilityBuffUpdate:FireClient(player, "PinBoost", info.Stacks, 0)
	end
end

-- Helper: Remove Pin Boost stack
local function RemovePinBoost(player, boostAmount)
	local userId = player.UserId
	if not PlayerBuffs[userId] or not PlayerBuffs[userId].PinBoost then return end
	
	local pinBoost = PlayerBuffs[userId].PinBoost
	pinBoost.Stacks -= 1
	
	if pinBoost.Stacks <= 0 then
		-- Remove buff entirely
		PlayerBuffs[userId].PinBoost = nil
		
		-- Update PlayerData Stat for UI Sync
		AbilityService.UpdatePlayerStats(player)
		
		-- Notify client
		if AbilityBuffUpdate then
			AbilityBuffUpdate:FireClient(player, "PinBoost", 0, 0)
		end
	else
		-- Update stats with reduced stacks
		AbilityService.UpdatePlayerStats(player)
		
		-- Notify client
		if AbilityBuffUpdate then
			AbilityBuffUpdate:FireClient(player, "PinBoost", pinBoost.Stacks, 0)
		end
	end
end

-- Helper: Apply Bullet Blessing Buff
local function ApplyBulletBlessing(player, buffConfig)
	local userId = player.UserId
	if not PlayerBuffs[userId] then PlayerBuffs[userId] = {} end
	
	-- Apply buff with 30 second duration
	PlayerBuffs[userId].BulletBlessing = {
		Active = true,
		ExpiryTime = os.time() + buffConfig.Duration,
		AlgaeBoost = buffConfig.AlgaeBoostAmount or 0.02,
		CritPowerBonus = buffConfig.CritPowerBonus or 0.25
	}
	
	-- Update stats immediately
	AbilityService.UpdatePlayerStats(player)
	
	-- Notify client
	if AbilityBuffUpdate then
		AbilityBuffUpdate:FireClient(player, "BulletBlessing", 1, PlayerBuffs[userId].BulletBlessing.ExpiryTime)
	end
end

-- Helper: Get Bullet Blessing Algae Bonus
local function GetBulletBlessingBonus(player)
	local userId = player.UserId
	if not PlayerBuffs[userId] or not PlayerBuffs[userId].BulletBlessing then 
		return 1 
	end
	
	local bb = PlayerBuffs[userId].BulletBlessing
	
	-- Check if buff has expired
	if os.time() >= bb.ExpiryTime then
		PlayerBuffs[userId].BulletBlessing = nil
		-- Notify client of expiry
		if AbilityBuffUpdate then
			AbilityBuffUpdate:FireClient(player, "BulletBlessing", 0, 0)
		end
		AbilityService.UpdatePlayerStats(player)
		return 1
	end
	
	local algaeBonus = 1 + bb.AlgaeBoost
	
	return algaeBonus
end

-- Helper: Check if Bullet Blessing is active
local function HasBulletBlessing(player)
	local userId = player.UserId
	if not PlayerBuffs[userId] or not PlayerBuffs[userId].BulletBlessing then
		return false
	end
	
	local bb = PlayerBuffs[userId].BulletBlessing
	
	-- Check if expired
	if os.time() >= bb.ExpiryTime then
		PlayerBuffs[userId].BulletBlessing = nil
		-- Notify client of expiry
		if AbilityBuffUpdate then
			AbilityBuffUpdate:FireClient(player, "BulletBlessing", 0, 0)
		end
		AbilityService.UpdatePlayerStats(player)
		return false
	end
	
	return true
end

-- Helper: Update All Player Stats based on active buffs
function AbilityService.UpdatePlayerStats(player)
	local userId = player.UserId
	if not PlayerBuffs[userId] then return end

	PlayerData.update(player, function(data)
		data = PlayerData.RecalculateStats(data)
		if not data.Stats then return data end

		local buffs = PlayerBuffs[userId]
		
		-- 1. Algae Recall (Combined Pin + AlgaeBoost + BulletBlessing)
		local algaeMultP = 0
		if buffs.AlgaeBoost then
			local b = buffs.AlgaeBoost
			algaeMultP = algaeMultP + ((b.Multiplier - 1) * b.Stacks)
		end
		if buffs.PinBoost then
			local p = buffs.PinBoost
			algaeMultP = algaeMultP + (p.BoostAmount * p.Stacks)
		end
		if buffs.BulletBlessing then
			algaeMultP = algaeMultP + (buffs.BulletBlessing.AlgaeBoost or 0)
		end
		if buffs.Fertilize then
			local bCfg = FishConfig.Buffs.Fertilize
			algaeMultP = algaeMultP + ((bCfg and bCfg.AlgaeBoostAmount) or 1.0)
		end
		data.Stats.PercentAlgae = data.Stats.PercentAlgae + algaeMultP

		-- 2. Tool Speed (PinBoost)
		if buffs.PinBoost then
			local p = buffs.PinBoost
			local pinCfg = FishConfig.Buffs.PinBoost
			local toolSpeedBonus = (pinCfg and pinCfg.ToolSpeedBonus) or 0.025
			data.Stats.ToolSpeed = 1.0 + (toolSpeedBonus * p.Stacks)
		end

		-- 3. Walk Speed (Speed Buff)
		if buffs.Speed then
			local b = buffs.Speed
			local speedCfg = FishConfig.Buffs.Speed
			local speedMultiplier = (speedCfg and speedCfg.Multiplier) or 0.1
			data.Stats.PlayerWalkSpeedMult = data.Stats.PlayerWalkSpeedMult + (speedMultiplier * b.Stacks)
		end

		-- 4. Critical Chance (Focus)
		if buffs.Focus then
			local f = buffs.Focus
			local fCfg = FishConfig.Buffs.Focus
			local critAdd = (fCfg and fCfg.CriticalChance) or 0.03
			data.Stats.CritChanceBonus = f.Stacks * critAdd
		end

		-- 5. Specific Recalls (Pink, Green, Orange)
		if buffs.PinkAlgaeBoost then
			local b = buffs.PinkAlgaeBoost
			local bCfg = FishConfig.Buffs.PinkAlgaeBoost
			local mult = b.CustomMultiplier or (bCfg and bCfg.Multiplier) or 0.5
			data.Stats.PercentPinkAlgae = data.Stats.PercentPinkAlgae + (mult * b.Stacks)
			data.Stats.InstantConversion = data.Stats.InstantConversion + (0.01 * b.Stacks)
		end
		if buffs.GreenAlgaeBoost then
			local b = buffs.GreenAlgaeBoost
			local bCfg = FishConfig.Buffs.GreenAlgaeBoost
			local mult = b.CustomMultiplier or (bCfg and bCfg.Multiplier) or 0.5
			data.Stats.PercentGreenAlgae = data.Stats.PercentGreenAlgae + (mult * b.Stacks)
		end
		if buffs.OrangeAlgaeBoost then
			local b = buffs.OrangeAlgaeBoost
			local bCfg = FishConfig.Buffs.OrangeAlgaeBoost
			local mult = b.CustomMultiplier or (bCfg and bCfg.Multiplier) or 0.5
			data.Stats.PercentOrangeAlgae = data.Stats.PercentOrangeAlgae + (mult * b.Stacks)
		end

		if buffs.Harmony then
			local b = buffs.Harmony
			local bCfg = FishConfig.Buffs.Harmony
			local pinkMult = (bCfg and bCfg.Multiplier) or 0.2
			local critPowerAdd = (bCfg and bCfg.CritPowerBoost) or 0.5
			data.Stats.PercentPinkAlgae = data.Stats.PercentPinkAlgae + (pinkMult * b.Stacks)
			data.Stats.CritPowerBonus = data.Stats.CritPowerBonus + (critPowerAdd * b.Stacks)
		end

		-- 6. Bullet Blessing Extra Stats
		if buffs.BulletBlessing then
			local bb = buffs.BulletBlessing
			data.Stats.CritPowerBonus = data.Stats.CritPowerBonus + (bb.CritPowerBonus or 0)
			data.Stats.InstantConversion = data.Stats.InstantConversion + (bb.InstantConversion or 0)
		end

		-- 7. Tool Recall (ToolBoost)
		if buffs.ToolBoost then
			local b = buffs.ToolBoost
			local bCfg = FishConfig.Buffs.ToolBoost
			local mult = (bCfg and bCfg.StackAmount) or 0.25
			data.Stats.ToolAlgae = data.Stats.ToolAlgae + (mult * b.Stacks)
		end

		-- 8. Test Phase Buff
		if buffs.TestPhase then
			local bCfg = FishConfig.Buffs.TestPhase
			local algaeAdd = (bCfg and bCfg.AlgaeBoost) or 100
			local convertAdd = (bCfg and bCfg.ConvertBoost) or 100
			data.Stats.PercentAlgae = data.Stats.PercentAlgae + algaeAdd
			data.Stats.ConvertMultiplier = data.Stats.ConvertMultiplier + convertAdd
		end
		
		-- 8.5 Bloated (Capacity Buff)
		if buffs.Bloated then
			local S = buffs.Bloated.Stacks or 0
			if S > 0 then
				local gain = FishConfig.Buffs.Bloated and FishConfig.Buffs.Bloated.CapacityPercentGain or 0.03
				data.Stats.CapacityMultiplier = data.Stats.CapacityMultiplier + (gain * S)
			end
		end
		
		-- 9. Rhythm Fever (Linear)
		if buffs.RhythmFever then
			local S = buffs.RhythmFever.Stacks or 0
			if S > 0 then
				local rfCfg = FishConfig.Buffs.RhythmFever
				local totalBoost = S * (rfCfg and rfCfg.Multiplier or 0.03)
				
				data.Stats.PercentAlgae += totalBoost
				data.Stats.PercentPinkAlgae += totalBoost
				data.Stats.PercentGreenAlgae += totalBoost
				data.Stats.PercentOrangeAlgae += totalBoost
			end
		end

		-- 10. Rhythm Fever+ (Linear Powerhouse)
		if buffs.RhythmFeverPlus then
			local S = buffs.RhythmFeverPlus.Stacks or 0
			if S > 0 then
				local algaeAdd = S * 0.10 -- 10% per stack
				local critPowerAdd = S * 0.25 -- 25% per stack
				local instantConvAdd = S * 0.01 -- 1% per stack
				local megaCritChanceAdd = S * 0.0075 -- 0.75% per stack
				
				data.Stats.PercentAlgae += algaeAdd
				data.Stats.PercentPinkAlgae += algaeAdd
				data.Stats.PercentGreenAlgae += algaeAdd
				data.Stats.PercentOrangeAlgae += algaeAdd
				
				data.Stats.CritPowerBonus += critPowerAdd
				data.Stats.MegaCritChance += megaCritChanceAdd
				data.Stats.InstantConversion += instantConvAdd
			end
		end
		
		-- 11. Blessed (Descent from Heaven)
		if buffs.Blessed then
			local b = buffs.Blessed
			local bCfg = FishConfig.Buffs.Blessed
			local orangeAdd = (bCfg and bCfg.OrangeAlgaeBonus) or 1.0
			local moveSpeedAdd = (bCfg and bCfg.MoveSpeedBonus) or 0.05
			local critPowerAdd = (bCfg and bCfg.CritPowerBonus) or 0.20
			local fishSpeedAdd = (bCfg and bCfg.FishMoveSpeedBonus) or 0.10
			
			data.Stats.PercentOrangeAlgae = data.Stats.PercentOrangeAlgae + (orangeAdd * b.Stacks)
			data.Stats.PlayerWalkSpeedMult = data.Stats.PlayerWalkSpeedMult + (moveSpeedAdd * b.Stacks)
			data.Stats.CritPowerBonus = data.Stats.CritPowerBonus + (critPowerAdd * b.Stacks)
			data.Stats.FishMoveSpeedMultiplier = data.Stats.FishMoveSpeedMultiplier + (fishSpeedAdd * b.Stacks)
		end

		-- Apply Walkspeed to Character
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			local base = data.Stats.PlayerWalkSpeedMult or 1.0
			local ability = data.Stats.FishMoveSpeedMultiplier or 1.0
			player.Character.Humanoid.WalkSpeed = 21 * base * ability
		end
		
		-- Final Capacity pass for Abilities
		if data.BaseCapacity then
			data.MaxCapacity = math.floor(data.BaseCapacity * (data.Stats.CapacityMultiplier or 1.0))
		end

		return data
	end)
end

-- Helper: Generic Buff Application
function AbilityService.ApplyBuff(player, buffName, customDuration, customMultiplier)
	local buffConfig = FishConfig.Buffs[buffName]
	if not buffConfig then return end

	local userId = player.UserId
	if not PlayerBuffs[userId] then PlayerBuffs[userId] = {} end

	local duration = customDuration or buffConfig.Duration or 10
	local maxStacks = buffConfig.MaxStacks or 10

	local current = PlayerBuffs[userId][buffName]
	local stacksChanged = false
	
	if not current then
		PlayerBuffs[userId][buffName] = {
			Stacks = 1,
			ExpiresAt = os.time() + duration,
			Max = maxStacks,
			LastSent = 0,
			CustomMultiplier = customMultiplier
		}
		stacksChanged = true
	else		-- If ApplyBuff is just refreshing, check MaxStacks limit
		if current.Stacks < (current.Max or maxStacks) then
			current.Stacks = current.Stacks + 1
			stacksChanged = true
			if current.Stacks == (current.Max or maxStacks) then
				PlayerData.IncrementQuestGoal(player, "MaxStacksReached", 1)
			end
		end
		-- Always refresh duration and potentially update custom multiplier
		current.ExpiresAt = os.time() + duration
		if customMultiplier then current.CustomMultiplier = customMultiplier end
	end

	local info = PlayerBuffs[userId][buffName]
	local now = os.clock()
	
	-- Optimize: Only fire remote if stacks changed or enough time passed (throttle timer updates to 1s)
	if stacksChanged or (now - (info.LastSent or 0) > 1.0) then
		AbilityBuffUpdate:FireClient(player, buffName, info.Stacks, info.ExpiresAt)
		info.LastSent = now
	end
	
	-- Optimize: Only recalculate stats if stacks changed (Timer refresh doesn't affect stats)
	if stacksChanged then
		AbilityService.UpdatePlayerStats(player)
	end

	-- Check for To The Moon Activation (Moved here so it triggers on any stack gain, e.g. commands)
	local rfConfig = FishConfig.Buffs.RhythmFever
	local maxStacks = rfConfig and rfConfig.MaxStacks or 200
	
	if buffName == "RhythmFever" and info.Stacks >= maxStacks and stacksChanged then
		-- Defensive check: strict maxStacks required
		if info.Stacks < maxStacks then return end
		
		local data = PlayerData.get(player)
		local moonStacks = AbilityService.GetBuffStacks(player, "ToTheMoon")
		
		local hasArtifact = false
		if data and data.EquippedArtifacts then
			if table.find(data.EquippedArtifacts, "Rhythmic Chromatose") then
				hasArtifact = true
			end
		end
		
		local moonCleanup = PlayerBuffs[userId] and PlayerBuffs[userId].MoonCleanup
		if hasArtifact and moonStacks == 0 and not moonCleanup then
			AbilityService.TriggerToTheMoon(player)
		end
	end
end

function AbilityService.ApplyTestPhaseBuff(player)
	if FishConfig.TestPhaseEnabled then
		-- Apply TestPhase buff if enabled in config
		AbilityService.ApplyBuff(player, "TestPhase")
	end
end

-- Expose Bullet Blessing functions for external use
AbilityService.ApplyBulletBlessing = ApplyBulletBlessing
AbilityService.GetBulletBlessingBonus = GetBulletBlessingBonus
AbilityService.HasBulletBlessing = HasBulletBlessing


-- Helper: Get Total Algae Boost Multiplier
function AbilityService.GetAlgaeBoostMultiplier(player)
	local userId = player.UserId
	local mult = 1
	if PlayerBuffs[userId] then
		if PlayerBuffs[userId].AlgaeBoost then
			local b = PlayerBuffs[userId].AlgaeBoost
			mult = mult + ((b.Multiplier - 1) * b.Stacks)
		end
		if PlayerBuffs[userId].PinBoost then
			local p = PlayerBuffs[userId].PinBoost
			mult = mult + (p.BoostAmount * p.Stacks)
		end
	end
	return mult
end

-- Expose pin list for passive systems (e.g. Surging Pins)
function AbilityService.GetActivePins()
	return ActivePins
end

function AbilityService.GetSpeedBoostMultiplier(player)
	local userId = player.UserId
	local mult = 1
	if PlayerBuffs[userId] and PlayerBuffs[userId].Speed then
		local b = PlayerBuffs[userId].Speed
		local cfg = FishConfig.Buffs.Speed
		local multiplier = cfg and cfg.Multiplier or 0.1
		mult = mult + (multiplier * b.Stacks)
	end
	return mult
end

-- Helper: Apply Speed Buff
local function ApplySpeedBuff(player)
	local buffConfig = FishConfig.Buffs.Speed
	if not buffConfig then return end
    
    local userId = player.UserId
    if not PlayerBuffs[userId] then PlayerBuffs[userId] = {} end
    
    local currentSpeed = PlayerBuffs[userId].Speed
    if not currentSpeed then
        PlayerBuffs[userId].Speed = {
            Stacks = 1,
            ExpiresAt = os.time() + buffConfig.Duration, -- Changed to ExpiresAt
            Max = buffConfig.MaxStacks
        }
    elseif currentSpeed.Stacks < currentSpeed.Max then
        currentSpeed.Stacks += 1
        currentSpeed.ExpiresAt = os.time() + buffConfig.Duration
    else
        currentSpeed.ExpiresAt = os.time() + buffConfig.Duration
    end
    
    -- Notify client
    local info = PlayerBuffs[userId].Speed
    AbilityBuffUpdate:FireClient(player, "Speed", info.Stacks, info.ExpiresAt)
    
    -- Update Stats
    AbilityService.UpdatePlayerStats(player)
end

-- Expose for external use
AbilityService.ApplySpeedBuff = ApplySpeedBuff

-- Central Pin System
local function UpdatePinBoostState(player, stacks, boostAmount)
	local userId = player.UserId
	if not PlayerBuffs[userId] then PlayerBuffs[userId] = {} end
	
	local changed = false
	if stacks <= 0 then
		if PlayerBuffs[userId].PinBoost then
			PlayerBuffs[userId].PinBoost = nil
			if AbilityBuffUpdate then AbilityBuffUpdate:FireClient(player, "PinBoost", 0, 0) end
			changed = true
		end
	else
		local pb = PlayerBuffs[userId].PinBoost
		if not pb then
			local newBuff = {Stacks = stacks, BoostAmount = boostAmount}
			PlayerBuffs[userId].PinBoost = newBuff
			changed = true
			
			-- 2-second passive conversion tick: 1% algae per stack -> Biomass
			-- Identity check (== newBuff) stops the loop automatically when the player
			-- steps out of the pin and a new PinBoost table is created on re-entry.
			task.spawn(function()
				while player.Parent and PlayerBuffs[userId] and PlayerBuffs[userId].PinBoost == newBuff do
					task.wait(2)
					if not player.Parent or not PlayerBuffs[userId] or PlayerBuffs[userId].PinBoost ~= newBuff then break end
					
					local currentStacks = newBuff.Stacks
					local conversionRate = 0.01 * currentStacks  -- 1% per stack
					
					PlayerData.update(player, function(data)
						if not data or not data.Plankton then return nil end
						
						-- Total current algae
						local totalAlgae = 0
						for _, amt in pairs(data.Plankton) do
							totalAlgae += math.max(0, tonumber(amt) or 0)
						end
						if totalAlgae <= 0 then return nil end
						
						local toConvert = math.max(1, math.floor(totalAlgae * conversionRate))
						local convertMult = (data.Stats and data.Stats.ConvertMultiplier) or 1
						local bioPerAlgae = (data.Stats and data.Stats.BiomassPerAlgae) or 1
						
						-- Drain proportionally across all algae types
						local biomassGained = 0
						local remaining = toConvert
						for typeName, amt in pairs(data.Plankton) do
							if remaining <= 0 then break end
							local take = math.min(
								math.ceil(amt / totalAlgae * toConvert),  -- proportional share
								math.floor(amt),                          -- cap at available
								remaining                                 -- don't over-convert
							)
							if take > 0 then
								local resType = ResourceConfig.Types[typeName]
								local baseVal = (resType and resType.BaseValue) or 1
								data.Plankton[typeName] -= take
								biomassGained += take * baseVal * convertMult * bioPerAlgae
								remaining -= take
							end
						end
						
						if biomassGained <= 0 then return nil end
						
						data.Biomass = (data.Biomass or 0) + biomassGained
						data.LifetimeBiomass = (data.LifetimeBiomass or 0) + biomassGained
						
						-- Sync leaderstats so counter ticks up visibly
						local ls = player:FindFirstChild("leaderstats")
						if ls then
							local bio = ls:FindFirstChild("Biomass")
							local alg = ls:FindFirstChild("Algae")
							if bio then bio.Value = data.Biomass end
							if alg then
								local newTotal = 0
								for _, a in pairs(data.Plankton) do newTotal += a end
								alg.Value = newTotal
							end
						end
						
						return data
					end)
				end
			end)
		else
			if pb.Stacks ~= stacks or pb.BoostAmount ~= boostAmount then
				pb.Stacks = stacks
				pb.BoostAmount = boostAmount
				changed = true
			end
		end
		-- Update UI if changed
		if changed and AbilityBuffUpdate then 
			AbilityBuffUpdate:FireClient(player, "PinBoost", stacks, os.time()+999) 
		end
	end
	
	-- Sync Data only on change to save bandwidth
	if changed then
		AbilityService.UpdatePlayerStats(player)
	end
end

local function UpdatePinSystem()
	local now = os.clock()
	local pinsToRemove = {}
	local pinClusters = {} 
	local clusterSizes = {}
	local nextClusterId = 1
	
	-- 1. Cluster Pins
	for i, pin in ipairs(ActivePins) do
		if not pin.Hitbox or not pin.Hitbox.Parent or now > pin.Expires then
			table.insert(pinsToRemove, i)
		else
			if not pinClusters[pin] then
				pinClusters[pin] = nextClusterId
				clusterSizes[nextClusterId] = 1
				nextClusterId += 1
				
				-- Flood Fill
				local queue = {pin}
				while #queue > 0 do
					local curr = table.remove(queue)
					local cId = pinClusters[curr]
					
					for _, other in ipairs(ActivePins) do
						if other ~= curr and not pinClusters[other] and other.Hitbox and other.Hitbox.Parent and now <= other.Expires then
							-- Intersect Check (Cylindrical Approx)
							local p1 = curr.Position * Vector3.new(1,0,1)
							local p2 = other.Position * Vector3.new(1,0,1)
							local distXZ = (p1 - p2).Magnitude
							local yDist = math.abs(curr.Position.Y - other.Position.Y)
							
							if distXZ < (curr.Radius + other.Radius) and yDist < 18 then -- 18 to allow some Y variance (Size.Y=20)
								pinClusters[other] = cId
								clusterSizes[cId] += 1
								table.insert(queue, other)
							end
						end
					end
				end
			end
		end
	end
	
	-- Cleanup
	for i = #pinsToRemove, 1, -1 do
		local idx = pinsToRemove[i]
		local p = ActivePins[idx]
		if p.Hitbox then p.Hitbox:Destroy() end
		table.remove(ActivePins, idx)
	end
	
	-- 2. Update Players
	local Players = game:GetService("Players")
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character.PrimaryPart then
			local pPos = player.Character.PrimaryPart.Position
			local pPosXZ = pPos * Vector3.new(1,0,1)
			
			local touchedClusters = {}
			local boostRef = 0.5
			
			for _, pin in ipairs(ActivePins) do
				local distXZ = (pPosXZ - (pin.Position * Vector3.new(1,0,1))).Magnitude
				local distY = math.abs(pPos.Y - pin.Position.Y)
				
				if distXZ <= pin.Radius and distY <= 10 then -- Half Height
					local cId = pinClusters[pin]
					if cId then
						touchedClusters[cId] = true
						boostRef = pin.BoostAmount
					end
				end
			end
			
			local totalStacks = 0
			for cId, _ in pairs(touchedClusters) do
				totalStacks += clusterSizes[cId]
			end
			
			UpdatePinBoostState(player, totalStacks, boostRef)
		end
	end
end

task.spawn(function()
	while true do
		UpdatePinSystem()
		task.wait(0.1) -- Throttle to 10Hz
	end
end)

local function UpdateTrailPassives()
	local HarvestService = require(script.Parent.HarvestService)
	if not HarvestService.MarkAlgaeArea then return end
	
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		local positions = playerFishPositions[userId]
		if not positions then continue end
		
		local data = PlayerData.get(player)
		if not data or not data.FishSchool then continue end
		
		for idxStr, fishData in pairs(data.FishSchool) do
			local cfg = FishConfig.Fish[fishData.Id]
			local passive = cfg and cfg.Passive
			
			if passive == "Trail of Light" then
				local pos = positions[tostring(idxStr)]
				if pos then
					local passCfg = FishConfig.Passives["Trail of Light"]
					local radius = passCfg and passCfg.Radius or 4
					local duration = passCfg and passCfg.Duration or 5
					local multiplier = passCfg and passCfg.Multiplier or 1.1
					
					HarvestService.MarkAlgaeArea(pos, radius, duration, multiplier)
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		UpdateTrailPassives()
		task.wait(1)
	end
end)

-- =========================================================
-- Shared helper: builds OverlapParams filtered to algae fields.
-- Eliminates the repeated 6-line filter setup in every ability handler.
-- =========================================================
local function BuildAlgaeOverlapParams()
	local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local folders = {}
	for fieldName in pairs(ResourceConfig.Fields) do
		local f = workspace:FindFirstChild(fieldName)
		if f then table.insert(folders, f) end
	end
	params.FilterDescendantsInstances = folders
	return params
end

-- =========================================================
-- Ability Dispatch Table
-- Signature: handler(player, fishIndex, fishId, position,
--                    abilityConfig, multiplier, vfxOverride, extraData, data)
-- =========================================================
local AbilityHandlers = {}

function AbilityService.DealAbilityDamage(player, position, abilityConfig)
	if not abilityConfig.Damage then return end
	local range = abilityConfig.Range or 10
	local dmg = abilityConfig.Damage
	
	local PlayerData = require(script.Parent.PlayerData)
	local data = PlayerData.get(player)
	if not data then return end
	
	local playerAttack = (data.Stats and data.Stats.Attack) or 1
	local playerFishAttack = (data.Stats and data.Stats.FishAttack) or 0
	local rawDamage = (dmg + playerFishAttack) * playerAttack
	
	local critChance = (data.Stats and data.Stats.CriticalChance) or 0.01
	local critPower = (data.Stats and data.Stats.CriticalPower) or 3.0
	local megaCritChance = (data.Stats and data.Stats.MegaCritChance) or 0
	local megaCritPower = (data.Stats and data.Stats.MegaCritPower) or 10.0
	
	for _, mobData in ipairs(MobService.GetMobs()) do
		if mobData.Mob and mobData.Mob.PrimaryPart then
			local dist = (mobData.Mob.PrimaryPart.Position - position).Magnitude
			if dist <= range then
				local isCrit = false
				local finalDmg = rawDamage
				if math.random() <= megaCritChance then
					isCrit = true
					finalDmg = rawDamage * megaCritPower
				elseif math.random() <= critChance then
					isCrit = true
					finalDmg = rawDamage * critPower
				end
				
				MobService.DamageMob(mobData.Mob, finalDmg, isCrit, false, player)
			end
		end
	end
end


AbilityHandlers["Mitosis"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	AbilityService.SpawnMitosisClone(player)
end

AbilityHandlers["Algae Boost"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	ApplyAlgaeBoost(player, fishId, extraData)
end

AbilityHandlers["Dive"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if not position then return end
	local HarvestService = require(script.Parent.HarvestService)
	local radius = (abilityConfig and abilityConfig.Radius) or 3
	local amount = ((abilityConfig and abilityConfig.Amount) or 13) * multiplier
	local overlapParams = BuildAlgaeOverlapParams()
	local boxSize = Vector3.new(radius * 2, 10, radius * 2)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(position), boxSize, overlapParams)
	local toHarvest = {}
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then table.insert(toHarvest, part) end
	end
	if #toHarvest > 0 then HarvestService.HarvestMultipleBatched(player, toHarvest, amount) end
	VFXReplication:FireAllClients("Dive", player, fishIndex, vfxOverride)
end

AbilityHandlers["Duplication"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	local school = data.FishSchool
	local pool = {}
	for _, fish in pairs(school) do
		local resolvedAbility = fish.AbilityName
		if not resolvedAbility and FishConfig.Fish[fish.Id] then
			resolvedAbility = FishConfig.Fish[fish.Id].AbilityName
		end
		if fish.Id ~= "Mirror Fish" and resolvedAbility ~= "Duplication" then
			table.insert(pool, fish)
		end
	end
	local abilityList = {}
	for _, fish in ipairs(pool) do
		local targetCfg = FishConfig.Fish[fish.Id]
		if targetCfg then
			local aName = fish.AbilityName or targetCfg.AbilityName
			if aName and aName ~= "Duplication" then
				table.insert(abilityList, { AbilityName = aName, FishId = fish.Id })
			end
		end
	end
	if #abilityList == 0 then
		table.insert(abilityList, { AbilityName = "Dive", FishId = "Mirror Fish" })
	end
	local newVfxOverride = { Color = Color3.new(1, 1, 1), ForceOverride = true }
	local newExtraData = { Multiplier = multiplier, VFXOverride = newVfxOverride }
	if extraData then
		for k, v in pairs(extraData) do
			if newExtraData[k] == nil then newExtraData[k] = v end
		end
	end
	for _, entry in ipairs(abilityList) do
		AbilityService.ExecuteAbility(player, fishIndex, entry.FishId, position, entry.AbilityName, newExtraData)
	end
end

AbilityHandlers["Obsession"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	AbilityService.DealAbilityDamage(player, position, abilityConfig)
	local dist = math.huge
	if player.Character and player.Character.PrimaryPart and position then
		dist = (player.Character.PrimaryPart.Position - position).Magnitude
	end
	local buffRange = abilityConfig.BuffRange or 10
	if dist <= buffRange and abilityConfig.Buffs then
		for _, buffName in ipairs(abilityConfig.Buffs) do AbilityService.ApplyBuff(player, buffName) end
	end
	VFXReplication:FireAllClients("Obsession", player, fishIndex, vfxOverride)
end

AbilityHandlers["Pink Boost"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if abilityConfig.Buffs then
		for _, buffName in ipairs(abilityConfig.Buffs) do AbilityService.ApplyBuff(player, buffName) end
	end
	VFXReplication:FireAllClients("Obsession", player, fishIndex, vfxOverride) -- Use generic buff vfx
end

AbilityHandlers["Green Boost"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if abilityConfig.Buffs then
		for _, buffName in ipairs(abilityConfig.Buffs) do AbilityService.ApplyBuff(player, buffName) end
	end
	VFXReplication:FireAllClients("Obsession", player, fishIndex, vfxOverride) -- Use generic buff vfx
end

AbilityHandlers["Orange Boost"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if abilityConfig.Buffs then
		for _, buffName in ipairs(abilityConfig.Buffs) do AbilityService.ApplyBuff(player, buffName) end
	end
	VFXReplication:FireAllClients("Obsession", player, fishIndex, vfxOverride) -- Use generic buff vfx
end

AbilityHandlers["Infectious Hellfire"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if not position then return end
	VFXReplication:FireAllClients("Infect", player, fishIndex, vfxOverride)
	local FieldService = require(script.Parent.FieldService)
	local radius = abilityConfig.Radius or 10
	local duration = abilityConfig.InitialDuration or 5
	local globalMult = (abilityConfig.GlobalMultiplier or 1.5) * multiplier
	local specificMults = abilityConfig.SpecificMultipliers or { GreenAlgae = 2.5 }
	local overlapParams = BuildAlgaeOverlapParams()
	local parts = workspace:GetPartBoundsInRadius(position, radius, overlapParams)
	for _, part in ipairs(parts) do
		if part:IsA("BasePart") then FieldService.InfectPart(part, duration, globalMult, specificMults) end
	end
end

AbilityHandlers["Tropical Gust"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if not position then return end
	AbilityService.DealAbilityDamage(player, position, abilityConfig)
	local duration = abilityConfig.Duration or 10
	local tickRate = abilityConfig.TickRate or 1.5
	local buffRange = abilityConfig.BuffRange or 10
	local gustPos = position
	VFXReplication:FireAllClients("TropicalGust", player, fishIndex, position, duration, vfxOverride)
	task.spawn(function()
		local elapsed = 0
		while elapsed < duration do
			task.wait(tickRate)
			elapsed += tickRate
			if player.Character and player.Character.PrimaryPart then
				if (player.Character.PrimaryPart.Position - gustPos).Magnitude <= buffRange then
					if abilityConfig.Buffs then
						for _, buffName in ipairs(abilityConfig.Buffs) do AbilityService.ApplyBuff(player, buffName) end
					end
				end
			end
		end
	end)
end

AbilityHandlers["Solar Flare"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if not position then return end
	local duration = abilityConfig.Duration or 5
	local radius = abilityConfig.RefillRadius or 5
	local amount = (abilityConfig.RefillAmount or 5) * multiplier
	local rate = abilityConfig.RefillRate or 0.5
	local sunPart = Instance.new("Part")
	sunPart.Name = "SolarFlareLogic"; sunPart.Transparency = 1; sunPart.CanCollide = false
	sunPart.Anchored = true; sunPart.Size = Vector3.new(1,1,1); sunPart.Position = position
	sunPart.Parent = workspace
	VFXReplication:FireAllClients("SolarFlare", player, fishIndex, sunPart, duration, vfxOverride)
	task.spawn(function()
		if abilityConfig.DamageTick == false then
			AbilityService.DealAbilityDamage(player, position, abilityConfig)
		end
		local elapsed = 0
		local lastDamageTick = 0
		local HarvestService = require(script.Parent.HarvestService)
		local TweenService = game:GetService("TweenService")
		local startPos = position
		while elapsed < duration do
			local dt = task.wait(rate); elapsed += dt
			if not sunPart or not sunPart.Parent then break end
			if not sunPart:GetAttribute("Moving") then
				if extraData and extraData.TargetPos then
					local target = Vector3.new(extraData.TargetPos.X, startPos.Y, extraData.TargetPos.Z)
					sunPart:SetAttribute("Moving", true)
					local moveTime = extraData.MoveTime or 1.0
					TweenService:Create(sunPart, TweenInfo.new(moveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = target}):Play()
					
					if not extraData.OutwardOnly then
						task.delay(moveTime, function() if sunPart and sunPart.Parent then sunPart:SetAttribute("Moving", false) end end)
					end
				else
					local centerPos = player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position or startPos
					local target = Vector3.new(centerPos.X, startPos.Y, centerPos.Z)
					local dist = (target - sunPart.Position).Magnitude
					local moveTime = math.max(0.5, dist / 4)
					TweenService:Create(sunPart, TweenInfo.new(moveTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = target}):Play()
					sunPart:SetAttribute("Moving", true)
					task.delay(moveTime, function() if sunPart and sunPart.Parent then sunPart:SetAttribute("Moving", false) end end)
				end
			end
			local visualRootPos = sunPart.Position + Vector3.new(0, 14, 0)
			local pPos = visualRootPos + Vector3.new(0, -14, 0)
			local overlapParams = BuildAlgaeOverlapParams()
			local toRefill = {}
			for _, part in ipairs(workspace:GetPartBoundsInRadius(pPos, radius, overlapParams)) do
				if part:IsA("BasePart") and part:FindFirstChild("Capacity") then table.insert(toRefill, part) end
			end
			if #toRefill > 0 then HarvestService.BatchedRefill(player, toRefill, amount) end
			if player.Character and player.Character.PrimaryPart then
				if (player.Character.PrimaryPart.Position - visualRootPos).Magnitude <= radius + 5 and abilityConfig.Buffs then
					for _, buffName in ipairs(abilityConfig.Buffs) do AbilityService.ApplyBuff(player, buffName) end
				end
			end
			if type(abilityConfig.DamageTick) == "number" then
				if elapsed - lastDamageTick >= abilityConfig.DamageTick then
					AbilityService.DealAbilityDamage(player, visualRootPos, abilityConfig)
					lastDamageTick = elapsed
				end
			end
		end
		if sunPart and sunPart.Parent then sunPart:Destroy() end
	end)
end

AbilityHandlers["Descent From Heaven"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if not position then return end
	local radius = abilityConfig.Radius or 20
	local amount = (abilityConfig.Amount or 15) * multiplier
	VFXReplication:FireAllClients("DescentFromHeaven", player, fishIndex, position, extraData)
	task.delay(2.15, function()
		if not player or not player.Parent then return end
		local HarvestService = require(script.Parent.HarvestService)
		local overlapParams = BuildAlgaeOverlapParams()
		local toHarvest = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, overlapParams)) do
			if part:IsA("BasePart") then table.insert(toHarvest, part) end
		end
		if #toHarvest > 0 then HarvestService.HarvestBatch(player, toHarvest, amount, true, true) end
		local playerParams = OverlapParams.new()
		playerParams.FilterType = Enum.RaycastFilterType.Include
		local allChars = {}
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(allChars, p.Character) end end
		playerParams.FilterDescendantsInstances = allChars
		local hitPlayers = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(position, radius, playerParams)) do
			local plr = Players:GetPlayerFromCharacter(part.Parent)
			if plr and not hitPlayers[plr] then hitPlayers[plr] = true; AbilityService.ApplyBuff(plr, "Blessed") end
		end
		AbilityService.DealAbilityDamage(player, position, abilityConfig)
	end)
end

AbilityHandlers["Chromatic Blast"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if not position then return end
	local color = (vfxOverride and vfxOverride.Color) or Color3.new(1,1,1)
	VFXReplication:FireAllClients("ChromaticBlast", player, fishIndex, color, {Position = position, ForceOverride = (vfxOverride ~= nil)})
	RhythmGameEvent:FireClient(player, abilityConfig.Count or 5)
end

AbilityHandlers["Pinned Down"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if not position then return end
	-- Scale duration by fish level: base + 0.3s per level above 1
	local fishData = data and data.FishSchool and data.FishSchool[tostring(fishIndex)]
	local fishLevel = (fishData and fishData.Level) or 1
	local duration = (abilityConfig.Duration or 15) + (fishLevel - 1) * 0.3
	local tweenHeight = abilityConfig.TweenHeight or 14
	local boostAmount = (abilityConfig.AlgaeBoostAmount or 0.15) * multiplier
	local radius = abilityConfig.Radius or 10
	VFXReplication:FireAllClients("PinnedDown", player, fishIndex, {Pos=position, Dur=duration, Height=tweenHeight, Override=vfxOverride})
	local hitbox = Instance.new("Part")
	hitbox.Name = "PinHitbox"; hitbox.Anchored = true; hitbox.CanCollide = false
	hitbox.Transparency = 1; hitbox.Size = Vector3.new(radius*2, 20, radius*2)
	hitbox.Position = position; hitbox.Parent = workspace
	table.insert(ActivePins, { Hitbox = hitbox, Position = position, Radius = radius, Expires = os.clock() + duration, BoostAmount = boostAmount })
end

AbilityHandlers["Surging Pins"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	local pins = AbilityService.GetActivePins()
	if not pins then return end
	
	local now = os.clock()
	local fishData = data and data.FishSchool and (data.FishSchool[fishIndex] or data.FishSchool[tostring(fishIndex)])
	local fishLevel = fishData and fishData.Level or 1
	local gatherAmount = math.floor(7 * (1 + 0.1 * (fishLevel - 1)))
	if gatherAmount < 1 then gatherAmount = 1 end

	local surgeParts = {}
	local uniqueParts = {}
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {workspace.Terrain}
	
	-- Harvest around ALL pins and pulse ALL pins
	for _, pin in ipairs(pins) do
		if pin.Hitbox and pin.Hitbox.Parent and now <= pin.Expires then
			local nearby = workspace:GetPartBoundsInRadius(pin.Position, pin.Radius, params)
			for _, part in ipairs(nearby) do
				if part:IsA("BasePart") and part:FindFirstChild("Capacity") and part:FindFirstChild("AlgaeAmount") then
					if not uniqueParts[part] then
						uniqueParts[part] = true
						table.insert(surgeParts, part)
					end
				end
			end
			
			-- Fire neon pink pulse VFX at EVERY pin
			VFXReplication:FireAllClients("SurgingPin", nil, nil, pin.Position)
		end
	end
	
	if #surgeParts > 0 then
		local HarvestService = require(script.Parent.HarvestService)
		HarvestService.HarvestBatch(player, surgeParts, gatherAmount, true, true)
	end
end

AbilityHandlers["Grand Slam"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	if not extraData or type(extraData.Targets) ~= "table" then return end
	local HarvestService = require(script.Parent.HarvestService)
	local radius = 14
	local amount = 20 * multiplier
	local timing = extraData.Timing or 2
	
	task.spawn(function()
		local ResourceConfig = require(game:GetService("ReplicatedStorage").Shared.ResourceConfig)
		
		-- TargetPos gets parsed directly, wait syncs seamlessly with the client's jump duration
		for i, targetPos in ipairs(extraData.Targets) do
			task.wait(timing)
			
			local toHarvestPink = {}
			local toHarvestOther = {}
			
			print("[Grand Slam] Checking algae to harvest at targetPos: " .. tostring(targetPos) .. " within radius " .. tostring(radius))
			
			-- Robust 2D distance check ignoring heights (same robust logic as Shark Scythe)
			for fieldName, _ in pairs(ResourceConfig.Fields) do
				local f = workspace:FindFirstChild(fieldName)
				if f then
					for _, part in ipairs(f:GetChildren()) do
						if part:IsA("BasePart") then
							local cap = part:FindFirstChild("Capacity")
							local aa = part:FindFirstChild("AlgaeAmount")
							if cap and aa and cap.Value > 0 then
								local distXZ = Vector2.new(part.Position.X - targetPos.X, part.Position.Z - targetPos.Z).Magnitude
								if distXZ <= radius then
									if part.Name == "PinkAlgae" then
										table.insert(toHarvestPink, part)
									else
										table.insert(toHarvestOther, part)
									end
								end
							end
						end
					end
				end
			end
			
			-- Dynamic parsing for Bloat Passive (Blobfish only)
			local pinkAmount = amount
			local fishSchool = data and data.FishSchool or {}
			local fData = fishSchool[fishIndex] or fishSchool[tostring(fishIndex)]
			
			if fData then
				local FishConfig = require(game:GetService("ReplicatedStorage").Shared.FishConfig)
				local fCfg = FishConfig.Fish[fData.Id]
				
				if fCfg and fCfg.Passive == "Bloat" then
					local buffs = PlayerBuffs[player.UserId]
					if buffs and buffs.Bloated and (buffs.Bloated.Stacks or 0) > 0 then
						local stacks = buffs.Bloated.Stacks
						local bloatCfg = FishConfig.Passives["Bloat"]
						local pinkBoostPerStack = (bloatCfg and bloatCfg.PinkBoostPerStack) or 0.10
						local bloatMult = 1.0 + (stacks * pinkBoostPerStack)
						
						pinkAmount = math.floor(amount * bloatMult)
						print("[Grand Slam - Bloat Passive] Blobfish has " .. stacks .. "x Bloated! Pink Algae harvest boosted from " .. amount .. " to " .. pinkAmount)
					end
				end
			end
			
			if #toHarvestPink > 0 then
				HarvestService.HarvestBatch(player, toHarvestPink, pinkAmount, false, true)
			end
			if #toHarvestOther > 0 then
				HarvestService.HarvestBatch(player, toHarvestOther, amount, false, true)
			end
			
			if #toHarvestPink == 0 and #toHarvestOther == 0 then
				print("[Grand Slam] Warning: Slam landed but NO algae was near targetPos")
			end
			
			-- Check if player is standing in the visualizer radius to grant buffs
			if player and player.Character and player.Character.PrimaryPart then
				local playerPos = player.Character.PrimaryPart.Position
				local distToPlayer = Vector2.new(playerPos.X - targetPos.X, playerPos.Z - targetPos.Z).Magnitude
				if distToPlayer <= radius then
					AbilityService.ApplyBuff(player, "PinkAlgaeBoost")
					AbilityService.ApplyBuff(player, "Bloated")
					print("[Grand Slam] Player inside slam radius! Granted Pink Boost and Bloated.")
				end
			end
			AbilityService.DealAbilityDamage(player, targetPos, abilityConfig)
		end
	end)
end


AbilityHandlers["Bloodthirst"] = function(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	local duration = abilityConfig.Duration or 7
	local moveSpeed = abilityConfig.MoveSpeed or 20
	local radius = abilityConfig.Radius or 4
	local harvestAmount = (abilityConfig.HarvestAmount or 3) * multiplier
	local tickRate = abilityConfig.TickRate or 0.1
	local hitCheckInterval = abilityConfig.HitCheckInterval or 0.3
	local ricochetVar = abilityConfig.RicochetAngleVariance or 45
	local HarvestService = require(script.Parent.HarvestService)
	if extraData and type(extraData) == "table" and #extraData > 1 then
		-- Path mode
		VFXReplication:FireAllClients("Bloodthirst", player, fishIndex, { Path = extraData, Duration = duration, Speed = moveSpeed, Override = vfxOverride })
		task.spawn(function()
			if abilityConfig.DamageTick == false then
				AbilityService.DealAbilityDamage(player, position, abilityConfig)
			end
			local path = extraData
			local lastPlayerHitTime = 0
			local lastDamageTick = os.clock()
			local overlapParams = BuildAlgaeOverlapParams()
			for i = 1, #path - 1 do
				local p1, p2 = path[i], path[i+1]
				local segmentVec = (p2 - p1)
				local dist = segmentVec.Magnitude
				if dist < 0.1 then continue end
				local steps = math.ceil((dist / moveSpeed) / tickRate)
				local stepTime = (dist / moveSpeed) / steps
				for s = 1, steps do
					task.wait(stepTime)
					local currentPos = p1 + segmentVec * (s / steps)
					local toHarvest = {}
					for _, p in ipairs(workspace:GetPartBoundsInRadius(currentPos, radius, overlapParams)) do
						if p:IsA("BasePart") then table.insert(toHarvest, p) end
					end
					if #toHarvest > 0 then HarvestService.HarvestBatch(player, toHarvest, harvestAmount, true, true) end
					if type(abilityConfig.DamageTick) == "number" then
						if os.clock() - lastDamageTick >= abilityConfig.DamageTick then
							AbilityService.DealAbilityDamage(player, currentPos, abilityConfig)
							lastDamageTick = os.clock()
						end
					end
					local now = os.clock()
					if now - lastPlayerHitTime > 1.0 and player.Character and player.Character.PrimaryPart then
						if (player.Character.PrimaryPart.Position - currentPos).Magnitude < (radius+2) then
							lastPlayerHitTime = now; ApplyToolBoost(player, abilityConfig)
						end
					end
				end
			end
		end)
	else
		-- Free-roam mode
		VFXReplication:FireAllClients("Bloodthirst", player, fishIndex, { StartPos = position, Duration = duration, Speed = moveSpeed, RicochetVariance = ricochetVar, Override = vfxOverride })
		task.spawn(function()
			if abilityConfig.DamageTick == false then
				AbilityService.DealAbilityDamage(player, position, abilityConfig)
			end
			local startTime = os.clock()
			local currentPos = position
			local currentDir = player.Character.PrimaryPart.CFrame.LookVector * Vector3.new(1,0,1)
			if currentDir.Magnitude < 0.1 then currentDir = Vector3.new(0,0,-1) end
			local lastHitCheck, lastPlayerHitTime = 0, 0
			local lastDamageTick = os.clock()
			local overlapParams = BuildAlgaeOverlapParams()
			while os.clock() - startTime < duration do
				local dt = task.wait(tickRate)
				currentPos = currentPos + currentDir * (moveSpeed * dt)
				if type(abilityConfig.DamageTick) == "number" then
					if os.clock() - lastDamageTick >= abilityConfig.DamageTick then
						AbilityService.DealAbilityDamage(player, currentPos, abilityConfig)
						lastDamageTick = os.clock()
					end
				end
				if os.clock() - lastHitCheck > hitCheckInterval then
					lastHitCheck = os.clock()
					local toHarvest = {}
					for _, p in ipairs(workspace:GetPartBoundsInRadius(currentPos, radius, overlapParams)) do
						if p:IsA("BasePart") then table.insert(toHarvest, p) end
					end
					if #toHarvest > 0 then HarvestService.HarvestMultipleBatched(player, toHarvest, harvestAmount) end
				end
				if os.clock() - lastPlayerHitTime > 1.0 and player.Character and player.Character.PrimaryPart then
					if (player.Character.PrimaryPart.Position - currentPos).Magnitude < (radius + 2) then
local AbilitiesFolder = script.Parent:WaitForChild("Abilities")
for _, child in ipairs(AbilitiesFolder:GetChildren()) do
	if child:IsA("ModuleScript") then
		local setupFunc = require(child)
		local context = {
			AbilityService = AbilityService,
			VFXReplication = VFXReplication,
			RhythmGameEvent = RhythmGameEvent,
			ActivePins = ActivePins,
			PlayerData = PlayerData,
			PlayerBuffs = PlayerBuffs,
			BuildAlgaeOverlapParams = BuildAlgaeOverlapParams,
			playerFishPositions = playerFishPositions
		}
		AbilityHandlers[child.Name] = setupFunc(context)
	end
end

-- Helper: Core Ability Execution logic
function AbilityService.ExecuteAbility(player, fishIndex, fishId, position, abilityNameOverride, extraData)
	local data = PlayerData.get(player)
	if not data or not data.FishSchool then return end
	
	AbilityService.IncrementAbilitiesCommitted(player)
	FishService.AddXP(player, fishIndex, 10)
	
	local config = FishConfig.Fish[fishId]
	if not config then return end
	
	-- Determine which ability to use
	local abilityName = abilityNameOverride or config.AbilityName
	if not abilityName then return end
	
	-- Special SFX Passthrough (Rabbit Fish)
	if abilityName == "RabbitEnter" or abilityName == "RabbitCollect" then
		VFXReplication:FireAllClients(abilityName, player, fishIndex, position)
		return
	end
	
	-- Resolve ability config
	local abilityConfig = FishConfig.Abilities[abilityName]
	
	-- Passives/Special abilities might not be in the Abilities table (e.g. Mitosis)
	if not abilityConfig and abilityName ~= "Mitosis" then
		warn("AbilityService: ExecuteAbility - Ability not found in config:", abilityName)
		return
	end

	local vfxOverride = extraData and extraData.VFXOverride
	local multiplier = (extraData and extraData.Multiplier) or 1.0

	-- Dispatch to the registered handler, or fall back to generic buff+VFX logic
	local handler = AbilityHandlers[abilityName]
	if handler then
		handler(player, fishIndex, fishId, position, abilityConfig, multiplier, vfxOverride, extraData, data)
	else
		-- Generic Fallback (Buffs and VFX only)
		local dist = math.huge
		if player.Character and player.Character.PrimaryPart and position then
			dist = (player.Character.PrimaryPart.Position - position).Magnitude
		end
		local buffRange = (abilityConfig and abilityConfig.BuffRange) or 10
		if dist <= buffRange and abilityConfig and abilityConfig.Buffs then
			for _, buffName in ipairs(abilityConfig.Buffs) do
				AbilityService.ApplyBuff(player, buffName)
			end
		end
		VFXReplication:FireAllClients(abilityName, player, fishIndex, vfxOverride)
	end
end


-- Handle ability triggers from client
-- Handle ability triggers from client
TriggerAbilityEvent.OnServerEvent:Connect(function(player, fishIndex, fishId, position, abilityNameOverride, extraData)
	-- 1. Basic Validation
	if not fishIndex or not fishId then return end
	local data = PlayerData.get(player)
	if not data or not data.FishSchool then return end
	
	local fishData = data.FishSchool[tostring(fishIndex)]
	if not fishData then return end
	
	-- Verify Fish Identity
	if fishData.Id ~= fishId then 
		warn("AbilityService: FishID Mismatch for " .. player.Name)
		return 
	end
	
	local config = FishConfig.Fish[fishId]
	if not config then return end

	-- 2. Validate Ability & Cooldown
	local now = os.time()
	if not AbilityCooldowns[player.UserId] then AbilityCooldowns[player.UserId] = {} end
	local cdData = AbilityCooldowns[player.UserId]
	
	local validAbilityName = nil
	local validatedExtraData = nil
	local cooldownDuration = 4 -- Default cooldown
	
	-- Check allowed abilities
	local allowedAbilities = {}
	if config.AbilityName then allowedAbilities[config.AbilityName] = true end
	if config.SecondaryAbilities then
		for _, name in ipairs(config.SecondaryAbilities) do
			allowedAbilities[name] = true
		end
	end
	
	-- Determine Valid Ability
	if abilityNameOverride == "RabbitEnter" or abilityNameOverride == "RabbitCollect" then
		-- Rabbit Fish SFX
		if fishId == "Rabbit Fish" then
			validAbilityName = abilityNameOverride
			cooldownDuration = 1 -- Short cooldown for SFX
		end
	elseif abilityNameOverride == "Mitosis" then
		-- Mitosis Passive
		if config.Passive == "Mitosis" then
			validAbilityName = "Mitosis"
			cooldownDuration = 5
		end
	else
		-- Standard Abilities
		if allowedAbilities[abilityNameOverride] then
			validAbilityName = abilityNameOverride
			
			validatedExtraData = extraData
			-- Validate ExtraData (e.g. Bloodthirst pathing)
            if validAbilityName == "Bloodthirst" and type(extraData) == "table" then
                 if #extraData > 30 then 
                      warn("AbilityService: Bloodthirst path too long from " .. player.Name)
					  return
                 end
            end
		else
			-- Fallback: If no valid override sent, use default if it matches intent (OR reject)
			-- Client always sends specific ability now, so we reject if it doesn't match allowed list.
		end
	end
	
	if not validAbilityName then
		-- warn("AbilityService: Rejected invalid ability '" .. tostring(abilityNameOverride) .. "' for " .. fishId)
		return
	end
	
	-- 3. Check Cooldown
	if (cdData[fishIndex] or 0) > now then 
		-- warn("AbilityService: Cooldown active for " .. player.Name .. " fish " .. fishIndex)
		return 
	end
	
	-- Apply Cooldown
	cdData[fishIndex] = now + cooldownDuration

	AbilityService.ExecuteAbility(player, fishIndex, fishId, position, validAbilityName, validatedExtraData)
end)
	
function AbilityService.TriggerToTheMoon(player)
	AbilityService.IncrementAbilitiesCommitted(player)
	AbilityService.ApplyBuff(player, "ToTheMoon")

	
	if PlayerBuffs[player.UserId] then
		PlayerBuffs[player.UserId].MoonCleanup = true
	end
	
	-- Override Music
	player:SetAttribute("MusicOverride", "rbxassetid://129293559792801")
	
	local moonConfig = FishConfig.Buffs.ToTheMoon
	local duration = moonConfig and moonConfig.Duration or 45

	task.spawn(function()
		local startTime = os.time()
		while os.time() - startTime < duration do
			if not player or not player.Parent then break end
			
			if AbilityService.GetBuffStacks(player, "ToTheMoon") <= 0 then 
				player:SetAttribute("MusicOverride", nil)
				break 
			end
			
			local hue = (os.clock() * 0.3) % 1
			local color = Color3.fromHSV(hue, 1, 1)
			
			if AbilityService.TriggerChromaticBlast then
				-- Random Position
				if player.Character and player.Character.PrimaryPart then
					local rootPos = player.Character.PrimaryPart.Position
					local angle = math.random() * math.pi * 2
					local dist = math.random(5, 25)
					local offset = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
					local targetPos = rootPos + offset
					
					AbilityService.TriggerChromaticBlast(player, color, targetPos)
					
					-- Mob Damage during ToTheMoon Blast
					local pd = PlayerData.get(player)
					local playerAttack = (pd and pd.Stats and pd.Stats.Attack) or 1
					local critChance = (pd and pd.Stats and pd.Stats.CriticalChance) or 0.01
					local critPower = (pd and pd.Stats and pd.Stats.CriticalPower) or 3.0
					local megaCritChance = (pd and pd.Stats and pd.Stats.MegaCritChance) or 0
					local megaCritPower = (pd and pd.Stats and pd.Stats.MegaCritPower) or 10.0
					
					local isCrit = false
					local finalDamage = playerAttack * 1.5 -- Blast multiplier
					
					if math.random() <= megaCritChance then
						isCrit = true
						finalDamage = finalDamage * megaCritPower
					elseif math.random() <= critChance then
						isCrit = true
						finalDamage = finalDamage * critPower
					end
					
					local avgLevel = MobService.GetAverageFishLevel(player)
					
					for _, mobData in ipairs(MobService.GetMobs()) do
						if mobData.Mob and mobData.Mob.PrimaryPart then
							local mDist = (mobData.Mob.PrimaryPart.Position - targetPos).Magnitude
							if mDist <= 10 then -- AOE radius
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
			end
			
			task.wait(0.2) -- Fast spawn rate for "Prismatic" feel
		end
	end)
	
	-- Schedule Cleanup
	task.delay(duration, function()
		-- Remove Music Override
		player:SetAttribute("MusicOverride", nil)
		
		-- Remove Buffs
		if PlayerBuffs[player.UserId] then
			PlayerBuffs[player.UserId]["RhythmFever"] = nil
			-- PlayerBuffs[player.UserId]["RhythmFeverPlus"] = nil -- Maintained as requested
			PlayerBuffs[player.UserId]["ToTheMoon"] = nil
			
			-- Notify Client
			if AbilityBuffUpdate then
				AbilityBuffUpdate:FireClient(player, "RhythmFever", 0, 0)
				-- AbilityBuffUpdate:FireClient(player, "RhythmFeverPlus", 0, 0) -- Maintained
				AbilityBuffUpdate:FireClient(player, "ToTheMoon", 0, 0)
			end
			
			PlayerBuffs[player.UserId].MoonCleanup = nil
			
			-- Update Stats
			AbilityService.UpdatePlayerStats(player)
		end
	end)
end

-- Helper: Trigger Chromatic Blast Effect (Visuals + Harvest)
function AbilityService.TriggerChromaticBlast(player, color, specificPos)
	local char = player.Character
	if not char then return end
	
	AbilityService.IncrementAbilitiesCommitted(player)
	
	if specificPos then
		-- New Mode: Spawn at specific position (To The Moon)
		VFXReplication:FireAllClients("ChromaticBlast", player, nil, color, {Position = specificPos})
		
		-- Harvest Area (radius 3, amount 10)
		local HarvestService = require(script.Parent.HarvestService)
		local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
		
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Include
		
		local filterFolders = {}
		for fieldName, _ in pairs(ResourceConfig.Fields) do
			local f = workspace:FindFirstChild(fieldName)
			if f then table.insert(filterFolders, f) end
		end
		overlapParams.FilterDescendantsInstances = filterFolders
		
		local radius = 3
		local hitParts = workspace:GetPartBoundsInRadius(specificPos, radius, overlapParams)
		
		local algaeTargets = {}
		for _, p in ipairs(hitParts) do
			if p:IsA("BasePart") then
				table.insert(algaeTargets, p)
			end
		end
		
		if #algaeTargets > 0 then
			HarvestService.HarvestMultipleBatched(player, algaeTargets, 10, true)
		end
		return
	end

	-- Existing Mode: Fish Squad
	-- Find a random fish model for this player
	local myFish = {}
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name:match("^Fish_" .. player.UserId .. "_%d+$") and child:IsA("Model") and child.PrimaryPart then
			table.insert(myFish, child)
		end
	end
	
	if #myFish > 0 then
		local HarvestService = require(script.Parent.HarvestService) -- Lazy load
		local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
		
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Include
		
		local filterFolders = {}
		for fieldName, _ in pairs(ResourceConfig.Fields) do
			local f = workspace:FindFirstChild(fieldName)
			if f then table.insert(filterFolders, f) end
		end
		overlapParams.FilterDescendantsInstances = filterFolders
		
		for _, fish in ipairs(myFish) do
			local fIndex = tonumber(fish.Name:match("_(%d+)$"))
			local harvestPos = fish.PrimaryPart.Position
			
			-- Fire VFX Replication for EVERY fish
			if fIndex then
				VFXReplication:FireAllClients("ChromaticBlast", player, fIndex, color)
			end

			-- AOE Harvest (3x3 blocks radius approx 10 studs)
			local radius = 8 -- Slightly smaller AOE since it's now per-fish
			local hitParts = workspace:GetPartBoundsInRadius(harvestPos, radius, overlapParams)
			
			local algaeTargets = {}
			for _, p in ipairs(hitParts) do
				if p:IsA("BasePart") then
					table.insert(algaeTargets, p)
				end
			end
			
			if #algaeTargets > 0 then
				HarvestService.HarvestMultipleBatched(player, algaeTargets, 6) -- Slightly lower amount per fish to balance it being squad-wide
			end
		end
	end
end

RhythmHitEvent.OnServerEvent:Connect(function(player, rating, color)
	local expected = AbilityService.ExpectedRhythmHits[player.UserId] or 0
	if expected <= 0 then
		warn("AbilityService: Rejected RhythmHitEvent from " .. player.Name .. " (no expected hits)")
		return
	end
	AbilityService.ExpectedRhythmHits[player.UserId] = expected - 1
	
	-- print("AbilityService: Rhythm HIT from " .. player.Name .. " (" .. tostring(rating) .. ")")
	-- Grant stacks based on rating
	local stacks = 0
	if rating == "Perfect" then
		stacks = 5
	elseif rating == "Good" then
		stacks = 3
	elseif rating == "Bad" then
		stacks = 1
	end
	
	if stacks == 0 then return end
	
	for i = 1, stacks do
		AbilityService.ApplyBuff(player, "RhythmFever")
	end
	
	-- Check for To The Moon Passive (Polarized Artifact)
	-- Check for To The Moon Passive (Rhythm Fish)
	local data = PlayerData.get(player)
	local moonStacks = AbilityService.GetBuffStacks(player, "ToTheMoon")
	-- local hasArtifact check removed as it's now tied to Rhythm Fish in ApplyBuff
	
	-- Debug Logging
	print(string.format("RhythmHit: Player=%s Rating=%s MoonStacks=%s", player.Name, tostring(rating), tostring(moonStacks)))

	-- 1. Add RhythmFever+ if To The Moon is active and hit is Perfect
	if moonStacks > 0 then
		if string.lower(rating) == "perfect" then
			AbilityService.ApplyBuff(player, "RhythmFeverPlus")
			print("Applied RhythmFeverPlus stack")
		end
		-- During To The Moon, verify if we skip standard Chromatic Blast on hit in favor of the 2s loop?
		-- The user said "make a chromatic blast appear every 2 seconds" but didn't explicitly forbid on-hit. 
		-- However, typically auto-fire replaces manual fire to avoid chaos. I will skip manual blast here.
		return 
	end

	local currentRF = AbilityService.GetBuffStacks(player, "RhythmFever")
	-- To The Moon activation is handled in ApplyBuff now
	
	-- Chromatic Blast Effect: Collect Algae at a random fish position (Normal Mode)
	AbilityService.TriggerChromaticBlast(player, color)
end)


RhythmMissEvent.OnServerEvent:Connect(function(player)
	local expected = AbilityService.ExpectedRhythmHits[player.UserId] or 0
	if expected > 0 then
		AbilityService.ExpectedRhythmHits[player.UserId] = expected - 1
	end
	
	print("AbilityService: Rhythm MISS from " .. player.Name)
	local userId = player.UserId
	
	-- To The Moon Protection (No consequences)
	if AbilityService.GetBuffStacks(player, "ToTheMoon") > 0 then
		return
	end
	
	if PlayerBuffs[userId] and PlayerBuffs[userId].RhythmFever then
		local current = PlayerBuffs[userId].RhythmFever
		
		-- Safety Check: If hitting max stacks (To The Moon readiness), prevent accidental drop
		if current.Stacks >= 350 then
			return 
		end
		
		if current.Stacks > 0 then
			-- Reduce stacks by 80% (keep 20%)
			local oldStacks = current.Stacks
			current.Stacks = math.floor(current.Stacks * 0.2)
			print("AbilityService: " .. player.Name .. " Rhythm Fever stacks reduced: " .. oldStacks .. " -> " .. current.Stacks)
			
			if current.Stacks <= 0 then
				PlayerBuffs[userId].RhythmFever = nil
				AbilityBuffUpdate:FireClient(player, "RhythmFever", 0, 0)
				print("AbilityService: " .. player.Name .. " Rhythm Fever buff removed.")
			else
				-- Notify client
				AbilityBuffUpdate:FireClient(player, "RhythmFever", current.Stacks, current.Expires)
				print("AbilityService: " .. player.Name .. " Rhythm Fever updated. New stacks: " .. current.Stacks)
			end
			
			-- Update Stats
			AbilityService.UpdatePlayerStats(player)
		end
	end
end)

-- Clean up expired buffs periodically (Consolidated system)
task.spawn(function()
	while true do
		task.wait(1) -- Check every 1 second
		
		local currentTime = os.time()
		for userId, buffs in pairs(PlayerBuffs) do
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				PlayerBuffs[userId] = nil
				continue
			end

			local needsStatUpdate = false
			local expiredBuffs = {}
			
			for bName, bData in pairs(buffs) do
				-- Skip pseudo-buffs/permanent ones or flags
				if bName == "PinBoost" or bName == "MoonCleanup" then continue end
				
				local expiry = bData.ExpiresAt or bData.Expires or bData.ExpiryTime
				if expiry and expiry > 0 and currentTime >= expiry then
					table.insert(expiredBuffs, bName)
				end
			end
			
			for _, bName in ipairs(expiredBuffs) do
				buffs[bName] = nil
				needsStatUpdate = true
				if AbilityBuffUpdate then
					AbilityBuffUpdate:FireClient(player, bName, 0, 0)
				end
				print("AbilityService: " .. player.Name .. "'s " .. bName .. " expired and was removed.")
			end
			
			if needsStatUpdate then
				AbilityService.UpdatePlayerStats(player)
			end
		end
	end
end)

-- Clean up on leave to prevent saving temp buffs
-- Clean up on leave
Players.PlayerRemoving:Connect(function(player)
	PlayerBuffs[player.UserId] = nil
	if _G.TemporaryFish then
		_G.TemporaryFish[player.UserId] = nil
	end
	-- No need to update PlayerData here as PlayerData.stop handles transient stat clearing.
end)






function AbilityService.Start()
	print("AbilityService: Started")
	
	-- Hook into PlayerAdded for TestPhase buff
	Players.PlayerAdded:Connect(function(player)
		AbilityService.ApplyTestPhaseBuff(player)
	end)
	
	-- Apply to existing players (hot reload)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			AbilityService.ApplyTestPhaseBuff(player)
		end)
	end
	
	-- Replicate Fish to all clients
	-- Replicate Fish to all clients
	task.spawn(function()
		while true do
			task.wait(3)
			local packet = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local d = PlayerData.get(p)
				-- Only replicate fish for players who have claimed an aquarium (Validated by client receiving it)
				if d and d.FishSchool then
					local school = {}
					-- Copy permanent fish
					for k, v in pairs(d.FishSchool) do school[tostring(k)] = v end
					-- Copy temporary fish
					if _G.TemporaryFish and _G.TemporaryFish[p.UserId] then
						for k, v in pairs(_G.TemporaryFish[p.UserId]) do school[tostring(k)] = v end
					end
					
					packet[tostring(p.UserId)] = school
				end
			end
			FishReplicationEvent:FireAllClients(packet)
		end
	end)
	
	
	-- Sunray Artifact Passive Loop
	task.spawn(function()
		local ResourceConfig = require(ReplicatedStorage.Shared.ResourceConfig)
		local FieldService = require(script.Parent.FieldService)
		
		-- Optimization: Cache fields
		local fieldFolders = {}
		for fieldName, _ in pairs(ResourceConfig.Fields) do
			local f = workspace:FindFirstChild(fieldName)
			if f then table.insert(fieldFolders, f) end
		end
		
		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = Enum.RaycastFilterType.Include
		overlapParams.FilterDescendantsInstances = fieldFolders
		
		while true do
			task.wait(0.75)
			for _, player in ipairs(Players:GetPlayers()) do
				local success, err = pcall(function()
					local data = PlayerData.get(player)
					if data and data.EquippedArtifacts and table.find(data.EquippedArtifacts, "Sunray Artifact") then
						local char = player.Character
						if char and char.PrimaryPart then
							local rootPos = char.PrimaryPart.Position
							
							-- Check radius 20
							local parts = workspace:GetPartBoundsInRadius(rootPos, 20, overlapParams)
							for _, part in ipairs(parts) do
								if part:IsA("BasePart") then
									FieldService.ForceRegrow(part, 1)
								end
							end
						end
					end
				end)
				if not success then warn("Error in Sunray loop: " .. tostring(err)) end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(3)
			local backpackPacket = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local d = PlayerData.get(p)
				if d and d.EquippedBackpack then
					backpackPacket[tostring(p.UserId)] = d.EquippedBackpack
				end
			end
			BackpackReplicationEvent:FireAllClients(backpackPacket)
		end
	end)
end

function AbilityService.GetBuffStacks(player, buffName)
	local userId = player.UserId
	if not PlayerBuffs[userId] then return 0 end
	
	local buffData = PlayerBuffs[userId][buffName]
	if not buffData then return 0 end
	
	if not buffData.ExpiresAt then
		-- Invalid buff data?
		PlayerBuffs[userId][buffName] = nil
		return 0
	end
	
	if os.time() >= buffData.ExpiresAt then
		PlayerBuffs[userId][buffName] = nil
		return 0
	end
	
	return buffData.Stacks or 0
end

-- Periodic Buff Cleanup System
local RunService = game:GetService("RunService")
local lastCleanupTime = os.clock()
local CLEANUP_INTERVAL = 1 -- Check every 1 second

-- Removed redundant Heartbeat cleanup to use consolidated system above
-- RunService.Heartbeat was here

function AbilityService.ExecuteSolarFlare(player, position, multiplier, extraData, vfxOverride)
	local data = PlayerData.get(player)
	local handler = AbilityHandlers["Solar Flare"]
	if handler then
		local config = FishConfig.Abilities["Solar Flare"] or {Duration = 5, RefillRadius = 5, RefillAmount = 5, RefillRate = 0.5}
		handler(player, 1, "Simulated", position, config, multiplier or 1.0, vfxOverride, extraData, data)
	end
end

function AbilityService.ExecuteDescentFromHeaven(player, position, multiplier, extraData)
	local data = PlayerData.get(player)
	local handler = AbilityHandlers["Descent From Heaven"]
	if handler then
		local config = FishConfig.Abilities["Descent From Heaven"] or {Radius = 20, Amount = 15}
		handler(player, 1, "Simulated", position, config, multiplier or 1.0, nil, extraData, data)
	end
end

return AbilityService
