local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)

-- Auto-build Backpack lookup cache
local BackpackConfig = {}
for key, data in pairs(EquipmentConfig) do
	if data.ProductType == "Backpack" then
		BackpackConfig[data.BackpackId or key] = data
	end
end

-- Setup Remote for Data Sync (Must be declared before functions use it)
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local DataUpdateEvent = Remotes:FindFirstChild("DataUpdateEvent")
if not DataUpdateEvent then
	DataUpdateEvent = Instance.new("RemoteEvent")
	DataUpdateEvent.Name = "DataUpdateEvent"
	DataUpdateEvent.Parent = Remotes
end

local SessionData = {}
local isDeadDataStore = false

local RequestData = Remotes:FindFirstChild("RequestData")
if not RequestData then
	RequestData = Instance.new("RemoteEvent")
	RequestData.Name = "RequestData"
	RequestData.Parent = Remotes
end
RequestData.OnServerEvent:Connect(function(player)
	local data = SessionData[player.UserId]
	if data then
		DataUpdateEvent:FireClient(player, data)
	end
end)

-- Use native GlobalDataStore for production data persistence
local DataStore = DataStoreService:GetDataStore("Fish_Hatchery")

local PlayerData = {}

local DEFAULT_DATA = {
	Biomass = 0,
	Pearls = 0,
	LifetimeAlgae = 0,
	AbilitiesCommitted = 0,
	TimePlayed = 0,
	Plankton = {
		PinkAlgae = 0,
		OrangeAlgae = 0,
		GreenAlgae = 0,
		MysticAlgae = 0,
	},
	EquippedBackpack = "Pouch",
	MaxCapacity = 200, -- Will be synced with BackpackConfig
	FishSchool = {
		-- [SlotId] = {Id = "Basic Fish", ...}
	},
	Stats = {
		BaseAlgae = 0, -- Base Multiplier Boost
		BasePinkAlgae = 0,
		BaseGreenAlgae = 0,
		BaseOrangeAlgae = 0,
		BaseMysticAlgae = 0,
		PercentAlgae = 0,
		PercentPinkAlgae = 0,
		PercentGreenAlgae = 0,
		PercentOrangeAlgae = 0,
		PercentMysticAlgae = 0,
		
		CriticalPower = 3.0, -- Default 3x Crit
		MegaCritChance = 0.01, -- 1% Base
		MegaCritPower = 10.0, -- 10x Multiplier
		CriticalChance = 0.01,
		
		PlayerWalkSpeedMult = 1.0, 


		FishMoveSpeedMultiplier = 1.0, -- Multiplies fish speed (100%)
		
		-- Conversion Stats
		ConvertMultiplier = 1.0, -- Default 100% (1.0)
		InstantConversion = 0, -- Percentage (0 to 1) of harvest instantly converted to Oxygen
		ToolAlgae = 1.0, -- Multiplier for tool algae collection
		CapacityMultiplier = 1.0, -- Multiplies Backpack Capacity
		BiomassPerAlgae = 1.0, -- Multiplier for O2 yield
		
		Attack = 1.0, -- Base Player Attack (used for abilities)
		FishAttack = 0, -- Bonus Fish Attack (added to base fish stats)
	},
	EquippedTool = "Fishing Net",
	UnlockedTools = { "Fishing Net" },
	UnlockedBackpacks = { "Pouch" },
	Inventory = { "Basic Egg" },
	UnlockedArtifacts = {},
	EquippedArtifacts = {},
	UnlockedZones = { "StartingReef" },
	PurchaseStats = {}, -- [ItemName] = TotalPurchased
	UnlockedFishes = {}, -- [FishId] = true
	ActiveQuests = {},
	CompletedQuests = {}, -- [QuestId] = timestamp
	CollectedTokens = {}, -- [TokenId] = timestamp (or boolean)
	LavaEnhancements = 0,
	LavaTurtleQuestsCompleted = 0,
	NoobieTurtleQuestsCompleted = 0,
	Settings = {
		AlgaeText = true,
		AbbreviateAlgae = false,
		TapToHold = false,
		MuteMusic = false,
		DisableStrobing = false,
		HideArtifacts = false,
		LowDetailMode = false,
		HighlightFish = false,
		HideOtherFish = false,
		DisableSFX = false,
	},
}

local function DeepCopy(orig)
	local copy
	if type(orig) == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
		end
		setmetatable(copy, DeepCopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local function SanitizeData(data)
	if not data then return end
	
	-- Biomass
	if data.Biomass ~= data.Biomass then -- NaN Check
		data.Biomass = 0
	end
	if type(data.Biomass) ~= "number" then
		data.Biomass = 0
	end

	-- LifetimeBiomass
	if not data.LifetimeBiomass then
		data.LifetimeBiomass = data.Biomass -- Best guess for existing players
	end
	if type(data.LifetimeBiomass) ~= "number" then
		data.LifetimeBiomass = 0
	end
	
	-- Pearls
	if data.Pearls ~= data.Pearls or type(data.Pearls) ~= "number" then
		data.Pearls = 0
	end
	
	-- Migrating & Memory Safety: Old Array to Dictionary O(N) Cleanup
	if data.Inventory then
		local isArray = false
		for k, v in pairs(data.Inventory) do
			if type(k) == "number" then
				isArray = true
				break
			end
		end

		if isArray then
			local newInv = {}
			for _, item in ipairs(data.Inventory) do
				if item == "Pearl" then
					data.Pearls = data.Pearls + 1
				else
					newInv[item] = (newInv[item] or 0) + 1
				end
			end
			data.Inventory = newInv
			data._InventoryDirty = true 
		end
	else
		data.Inventory = {}
	end

	-- TimePlayed
	if not data.TimePlayed or type(data.TimePlayed) ~= "number" then
		data.TimePlayed = 0
	end
	
	-- Plankton
	if data.Plankton then
		for k, v in pairs(data.Plankton) do
			if v ~= v then -- NaN Check
				data.Plankton[k] = 0
			end
			if type(v) ~= "number" then
				data.Plankton[k] = 0
			end
		end
	end
	
	-- CompletedQuests
	if not data.CompletedQuests then data.CompletedQuests = {} end
	
	-- ActiveQuests
	if not data.ActiveQuests then data.ActiveQuests = {} end
	
	-- Note: CollectedTokens is a table of timestamps/bools, we don't need deep validation but ensure it exists
	if not data.CollectedTokens then data.CollectedTokens = {} end
	
	return data
end

-- Helper for stat syncing (exposed for ShopService)
function PlayerData.RecalculateStats(data)
	-- Reset Base Stats
	if not data.Stats then data.Stats = {} end
	data.Stats.CapacityMultiplier = 1.0
	data.Stats.PlayerWalkSpeedMult = 1.0
	data.Stats.BaseAlgae = 0
	data.Stats.BasePinkAlgae = 0
	data.Stats.BaseGreenAlgae = 0
	data.Stats.BaseOrangeAlgae = 0
	data.Stats.BaseMysticAlgae = 0
	data.Stats.PercentAlgae = 0
	data.Stats.PercentPinkAlgae = 0
	data.Stats.PercentGreenAlgae = 0
	data.Stats.PercentOrangeAlgae = 0
	data.Stats.PercentMysticAlgae = 0
	data.Stats.BiomassPerAlgae = 1.0  -- MUST reset or artifact bonuses compound on every RecalculateStats call
	
	data.Stats.ConvertMultiplier = 1.0
	
	-- Ability Resets (Prevents permanent buffs on rejoin)
	data.Stats.FishMoveSpeedMultiplier = 1.0
	data.Stats.CritChanceBonus = 0
	data.Stats.CriticalPower = 3.0 -- Reset to base 3x
	data.Stats.CritPowerBonus = 0
	data.Stats.MegaCritChance = 0.01 -- Reset to base 1%
	data.Stats.MegaCritPower = 10.0 -- Reset to base 10x
	data.Stats.ToolAlgae = 1.0
	data.Stats.ToolSpeed = 1.0
	data.Stats.InstantConversion = 0
	data.Stats.FishEnergyGainBoost = 0
	
	data.Stats.Attack = 1.0
	data.Stats.FishAttack = 0
	
	-- Lava Enhancement Stats
	local lavaBuffs = data.LavaEnhancements or 0
	if lavaBuffs > 0 then
		data.Stats.ConvertMultiplier += (lavaBuffs * 0.50)
		data.Stats.BaseOrangeAlgae += (lavaBuffs * 0.05)
		data.Stats.FishMoveSpeedMultiplier += (lavaBuffs * 0.02)
		data.Stats.BaseAlgae += (lavaBuffs * 0.03)
		data.Stats.FishEnergyGainBoost += (lavaBuffs * 0.03)
	end
	
	-- Backpack Stats
	local bp = data.EquippedBackpack or "Pouch"
	local bpCfg = BackpackConfig[bp]
	local baseCap = 200
	
	if bpCfg then
		baseCap = bpCfg.Capacity or 200
		
		if bpCfg.ConvertAdd then
			data.Stats.ConvertMultiplier = 1.0 + (bpCfg.ConvertAdd / 100)
		end
		if bpCfg.AlgaePercentAdd then
			data.Stats.BaseAlgae = (bpCfg.AlgaePercentAdd / 100)
		end
	end
	
	data.BaseCapacity = baseCap -- Start with base
	data.MaxCapacity = baseCap	
	-- Artifact Stats
	if data.EquippedArtifacts then
		for _, artName in ipairs(data.EquippedArtifacts) do
			local artCfg = EquipmentConfig[artName]
			if artCfg and artCfg.Stats then
				if artCfg.Stats.SpeedBoost or artCfg.Stats.WalkSpeedMult then
					data.Stats.PlayerWalkSpeedMult += (artCfg.Stats.SpeedBoost or artCfg.Stats.WalkSpeedMult)
				end
				if artCfg.Stats.AlgaeBoost or artCfg.Stats.AlgaeMult then
					data.Stats.BaseAlgae += (artCfg.Stats.AlgaeBoost or artCfg.Stats.AlgaeMult)
				end
				if artCfg.Stats.CapacityBoost or artCfg.Stats.CapacityMult then
					data.Stats.CapacityMultiplier += (artCfg.Stats.CapacityBoost or artCfg.Stats.CapacityMult)
				end
				if artCfg.Stats.ConvertBoost or artCfg.Stats.ConvertMultiplier then
					data.Stats.ConvertMultiplier += (artCfg.Stats.ConvertBoost or artCfg.Stats.ConvertMultiplier)
				end
				if artCfg.Stats.InstantConvertBoost or artCfg.Stats.InstantConversion then
					data.Stats.InstantConversion += (artCfg.Stats.InstantConvertBoost or artCfg.Stats.InstantConversion)
				end
				if artCfg.Stats.PinkAlgaeBoost or artCfg.Stats.PinkAlgaeMult then
					data.Stats.BasePinkAlgae += (artCfg.Stats.PinkAlgaeBoost or artCfg.Stats.PinkAlgaeMult)
				end
				if artCfg.Stats.GreenAlgaeBoost or artCfg.Stats.GreenAlgaeMult then
					data.Stats.BaseGreenAlgae += (artCfg.Stats.GreenAlgaeBoost or artCfg.Stats.GreenAlgaeMult)
				end
				if artCfg.Stats.OrangeAlgaeBoost or artCfg.Stats.OrangeAlgaeMult then
					data.Stats.BaseOrangeAlgae += (artCfg.Stats.OrangeAlgaeBoost or artCfg.Stats.OrangeAlgaeMult)
				end
				if artCfg.Stats.BiomassBoost then
					data.Stats.BiomassPerAlgae += artCfg.Stats.BiomassBoost
				end
				if artCfg.Stats.CritChanceBoost then
					data.Stats.CritChanceBonus += artCfg.Stats.CritChanceBoost
				end
				if artCfg.Stats.CritPowerBoost then
					data.Stats.CritPowerBonus += artCfg.Stats.CritPowerBoost
				end
			end
		end
	end
	
	-- Final Capacity
	data.MaxCapacity = math.floor((data.BaseCapacity or baseCap) * data.Stats.CapacityMultiplier)
	
	return data
end

function PlayerData.start(player)
	-- Listen for Character Reset to re-apply stats
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5) -- Wait for load
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and SessionData[player.UserId] and SessionData[player.UserId].Stats then
			local s = SessionData[player.UserId].Stats
			local base = s.PlayerWalkSpeedMult or 1.0
			local ability = s.FishMoveSpeedMultiplier or 1.0
			hum.WalkSpeed = 21 * base * ability
		end
	end)

	if isDeadDataStore then
		SessionData[player.UserId] = DeepCopy(DEFAULT_DATA)
		PlayerData.RecalculateStats(SessionData[player.UserId])
		
		if DataUpdateEvent then
			DataUpdateEvent:FireClient(player, SessionData[player.UserId])
		end
		
		-- Apply WalkSpeed for Initial Spawn (if char already exists)
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			local s = SessionData[player.UserId].Stats
			local base = s.PlayerWalkSpeedMult or 1.0
			local ability = s.FishMoveSpeedMultiplier or 1.0
			player.Character.Humanoid.WalkSpeed = 21 * base * ability
		end
		
		return
	end


	local success, result
	local maxRetries = 15
	local retryDelay = 2

	for i = 1, maxRetries do
		success, result = pcall(function()
			local acquiredData
			DataStore:UpdateAsync("User_" .. player.UserId, function(stored)
				if not stored then
					stored = DeepCopy(DEFAULT_DATA)
				end
				
				-- Check for active lock from another server (90s expiration)
				local lockExp = 90
				if stored._SessionLock and stored._SessionLock ~= game.JobId and stored._LastSaved and (os.time() - stored._LastSaved) < lockExp then
					error("SESSION_LOCKED") 
				end
				
				-- Acquire lock
				stored._SessionLock = game.JobId
				stored._LastSaved = os.time()
				acquiredData = stored
				
				return stored
			end)
			return acquiredData
		end)
		
		if success and result then
			break
		elseif not success and string.find(tostring(result), "SESSION_LOCKED") then
			warn("PlayerData: Session locked for " .. player.Name .. ". Retrying... (" .. i .. "/" .. maxRetries .. ")")
			task.wait(retryDelay)
		elseif not success then
			warn("PlayerData: Load error for " .. player.Name .. ": " .. tostring(result))
			task.wait(retryDelay)
		end
	end

	if success and result then
		-- Migration: Oxygen to Biomass
		if result.Oxygen then
			result.Biomass = (result.Biomass or 0) + result.Oxygen
			result.Oxygen = nil
		end
		
		-- Migration: BiomassTank -> OxygenTank
		if result.EquippedBackpack == "BiomassTank" then
			result.EquippedBackpack = "OxygenTank"
		end
		if result.UnlockedBackpacks then
			local idx = table.find(result.UnlockedBackpacks, "BiomassTank")
			if idx then
				result.UnlockedBackpacks[idx] = "OxygenTank"
			end
		end
		
		if result.Stats and result.Stats.OxygenPerAlgae then
			result.Stats.BiomassPerAlgae = result.Stats.OxygenPerAlgae
			result.Stats.OxygenPerAlgae = nil
		end

		-- Reconcile with default data in case of updates
		for k, v in pairs(DEFAULT_DATA) do
			if result[k] == nil then
				result[k] = DeepCopy(v)
			end
		end
		
		-- Reconcile Stats specifically
		if result.Stats and DEFAULT_DATA.Stats then
			for k, v in pairs(DEFAULT_DATA.Stats) do
				if result.Stats[k] == nil then
					result.Stats[k] = v
				end
			end
		end
		
		-- Sanitize
		result = SanitizeData(result)
		
		-- Full Stat Recalculation (Backpack + Artifacts)
		PlayerData.RecalculateStats(result)
		
		SessionData[player.UserId] = result
		
		-- Apply WalkSpeed Immediately (Side Effect)
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			local base = result.Stats.PlayerWalkSpeedMult or 1.0
			local ability = result.Stats.FishMoveSpeedMultiplier or 1.0
			player.Character.Humanoid.WalkSpeed = 21 * base * ability
		end
		
		-- Sanity Check: Remove any non-numeric slots
		if result.FishSchool then
			for k, _ in pairs(result.FishSchool) do
				if not tonumber(k) then
					warn("PlayerData: Removing corrupted slot entry from " .. player.Name .. ": " .. tostring(k))
					result.FishSchool[k] = nil
				end
			end
		end
		
		-- Migration: CompletedQuests
		if not result.CompletedQuests or next(result.CompletedQuests) == nil then
			-- If it's missing or empty, check for old format in ActiveQuest
			if result.ActiveQuest and result.ActiveQuest.Completed then
				if not result.CompletedQuests then result.CompletedQuests = {} end
				for k, v in pairs(result.ActiveQuest.Completed) do
					if type(k) == "string" then
						result.CompletedQuests[k] = v
					elseif type(v) == "string" then
						result.CompletedQuests[v] = os.time()
					end
				end
			end
		end
		
		-- Migration: ActiveQuests
		if result.ActiveQuest then
			if not result.ActiveQuests then result.ActiveQuests = {} end
			if result.ActiveQuest.Id then
				result.ActiveQuests[result.ActiveQuest.Id] = result.ActiveQuest.Progress
			end
			result.ActiveQuest = nil
		end
		
		if not result.ActiveQuests then
			result.ActiveQuests = {}
		end

		-- Migration: CollectedTokens
		if not result.CollectedTokens then
			result.CollectedTokens = {}
		end


	else
		-- Handle failure
		if not success then
			warn("DataStore load failed for " .. player.Name .. ": " .. tostring(result))
			if RunService:IsStudio() and (string.find(tostring(result), "API Services rejected") or string.find(tostring(result), "Studio access to APIs")) then
				warn("⚠️ Studio API Access is disabled. Data will not save. Enable in Game Settings > Security > Enable Studio Access to API Services.")
				isDeadDataStore = true
			else
				-- Critical Failure: Mark as failed load to prevent overwriting data with empty defaults
				if not SessionData[player.UserId] then SessionData[player.UserId] = {} end
				SessionData[player.UserId]._LoadFailed = true
				
				-- Notify player? kick? For now, just ensuring we don't save is the priority.
				-- We still load default data so they can play, but we WON'T save it.
			end
		end
		
		SessionData[player.UserId] = DeepCopy(DEFAULT_DATA)
		if not success and not isDeadDataStore then
			-- Re-apply flag to the fresh session object
			SessionData[player.UserId]._LoadFailed = true
		end
		
		-- Sync default capacity
		local bp = DEFAULT_DATA.EquippedBackpack
		if BackpackConfig[bp] then 
			SessionData[player.UserId].MaxCapacity = BackpackConfig[bp].Capacity 
			
			-- Apply ConvertAdd bonus
			local cfg = BackpackConfig[bp]
			if not SessionData[player.UserId].Stats then SessionData[player.UserId].Stats = {} end
			if cfg.ConvertAdd then
				SessionData[player.UserId].Stats.ConvertMultiplier = 1.0 + (cfg.ConvertAdd / 100)
			else
				SessionData[player.UserId].Stats.ConvertMultiplier = 1.0
			end
			
			-- Apply AlgaePercentAdd bonus
			if cfg.AlgaePercentAdd then
				SessionData[player.UserId].Stats.BaseAlgae = (cfg.AlgaePercentAdd / 100)
			else
				SessionData[player.UserId].Stats.BaseAlgae = 0
			end
		end
	end
	

	-- Create Leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	
	local algaeStat = Instance.new("IntValue")
	algaeStat.Name = "Algae"
	-- Sum up current plankton
	local total = 0
	if SessionData[player.UserId] and SessionData[player.UserId].Plankton then
		for _, v in pairs(SessionData[player.UserId].Plankton) do total += v end
	end
	algaeStat.Value = total
	algaeStat.Parent = leaderstats
	
	local biomassStat = Instance.new("IntValue")
	biomassStat.Name = "Biomass"
	biomassStat.Value = SessionData[player.UserId].Biomass or 0
	biomassStat.Parent = leaderstats
	
	-- Parent leaderstats last to ensure all values replicate properly
	leaderstats.Parent = player

	-- Send Initial Data
	if DataUpdateEvent then
		DataUpdateEvent:FireClient(player, SessionData[player.UserId])
	end
end

-- Clears all runtime-only flags that must not be persisted to the DataStore.
-- Called before every save (both on PlayerRemoving and BindToClose).
local function ClearTransientFlags(data)
	data.IsConverting = false
	data._FishDirty = nil
	data._InventoryDirty = nil
	data._QuestsDirty = nil
	data._TokensDirty = nil
	data._UnlockablesDirty = nil
	data._LoadFailed = nil
	data._PendingSeaMinesNotification = nil
end

function PlayerData.stop(player)
	if isDeadDataStore then return end

	local data = SessionData[player.UserId]
	if data then
		-- CRITICAL: Do not save if the load failed initially (prevents wiping data)
		if data._LoadFailed then
			warn("PlayerData: Data load failed for " .. player.Name .. ", SKIPPING SAVE to prevent data loss.")
			SessionData[player.UserId] = nil
			return
		end
		

		-- Clear transient session flags before saving
		ClearTransientFlags(data)
		
		pcall(function()
			DataStore:UpdateAsync("User_" .. player.UserId, function(stored)
				-- Ensure we only save if we own the lock, or if the lock is somehow lost (allows graceful recovery)
				if stored and stored._SessionLock and stored._SessionLock ~= game.JobId then
					warn("PlayerData: Cannot save data for " .. player.Name .. ". Lock stolen by another server.")
					return nil -- Abort save to prevent overwriting new server's data
				end
				
				-- Unlock session on successful leave
				data._SessionLock = nil
				data._LastSaved = os.time()
				
				return data
			end)
		end)
		
		-- Only clear if the session hasn't been replaced (Race condition protection)
		if SessionData[player.UserId] == data then
			SessionData[player.UserId] = nil
		end
	end
end

function PlayerData.get(player)
	return SessionData[player.UserId] or DeepCopy(DEFAULT_DATA)
end

function PlayerData.isLoaded(player)
	return SessionData[player.UserId] ~= nil
end



local dirtyUsers = {}

-- Replication Loop (Throttled to ~10Hz)
-- Replication Loop (Throttled to ~10Hz)
task.spawn(function()
	while true do
		task.wait(0.1) -- 10 updates per second max
		for userId, _ in pairs(dirtyUsers) do
			local player = Players:GetPlayerByUserId(userId)
			local data = SessionData[userId]
			if player and data and DataUpdateEvent then
				-- Optimization: Strip heavy tables from frequent updates unless dirty
				local packet = table.clone(data) 
				
				-- 1. Fish School (Already Optimized)
				if not data._FishDirty then
					packet.FishSchool = nil
				else
					data._FishDirty = false
				end
				
				-- 2. Inventory (New Optimization)
				if not data._InventoryDirty then
					packet.Inventory = nil
				else
					data._InventoryDirty = false
				end
				
				-- 3. Quests (New Optimization)
				if not data._QuestsDirty then
					packet.CompletedQuests = nil
					packet.ActiveQuests = nil
				else
					data._QuestsDirty = false
				end
				
				-- 4. Tokens (New Optimization)
				if not data._TokensDirty then
					packet.CollectedTokens = nil
				else
					data._TokensDirty = false
				end
				
				-- 5. Unlockables (Tools/Backpacks/Artifacts - Grouped under _UnlockablesDirty)
				-- Optional: Could be separate, but grouping is simpler for now
				if not data._UnlockablesDirty then
					packet.UnlockedTools = nil
					packet.UnlockedBackpacks = nil
					packet.UnlockedArtifacts = nil
				else
					data._UnlockablesDirty = false
				end
				
				DataUpdateEvent:FireClient(player, packet)
			end
			dirtyUsers[userId] = nil
		end
	end
end)

function PlayerData.SetDirty(player, category)
	if not player then return end
	local data = SessionData[player.UserId]
	if data then
		if category == "Fish" then data._FishDirty = true
		elseif category == "Inventory" then data._InventoryDirty = true
		elseif category == "Quests" then data._QuestsDirty = true
		elseif category == "Tokens" then data._TokensDirty = true
		elseif category == "Unlockables" then data._UnlockablesDirty = true
		end
		
		-- Also ensure global dirty is set to trigger send
	end
end

function PlayerData.IncrementQuestGoal(player, goalKey, amount)
	PlayerData.update(player, function(data)
		if not data.ActiveQuests then return nil end
		local QuestConfig = require(game:GetService("ReplicatedStorage").Shared.QuestConfig)
		local updated = false
		for questId, progress in pairs(data.ActiveQuests) do
			local qConfig = QuestConfig.Quests[questId]
			-- Exclude NoobieTurtle since it scales dynamically and isn't statically in QuestConfig.Quests by default?
			-- Actually NoobieTurtle is generated in ActiveQuests but its config comes from UpdateNoobieTurtle.
			-- If it's NoobieTurtle, the qConfig might be missing or different, but the Quests table holds the generated one natively.
			if questId == "NoobieTurtle" and QuestConfig.Quests["NoobieTurtle"] then
				qConfig = QuestConfig.Quests["NoobieTurtle"]
			end
			
			if qConfig and qConfig.Goals and qConfig.Goals[goalKey] then
				if type(progress) ~= "table" then
					-- Migrate single string goals to table if needed
					progress = {}
					data.ActiveQuests[questId] = progress
				end
				local current = progress[goalKey] or 0
				local limit = qConfig.Goals[goalKey]
				local nxt = current + (amount or 1)
				if nxt > limit then nxt = limit end
				if progress[goalKey] ~= nxt then
					progress[goalKey] = nxt
					updated = true
				end
			end
		end
		if updated then
			data._QuestsDirty = true
			return data
		end
		return nil
	end)
end

function PlayerData.update(player, callback, skipRemote)
	if not player then return end
	local data = SessionData[player.UserId]
	if data then
		local newData = callback(data)
		if newData then
			newData = SanitizeData(newData)
			SessionData[player.UserId] = newData
			
			-- Mark dirty instead of firing immediately
			if not skipRemote then
				dirtyUsers[player.UserId] = true
			end
			
			-- Apply WalkSpeed Side Effect Immediately & Update Stat for UI
			if newData.Stats then
				local base = newData.Stats.PlayerWalkSpeedMult or 1.0
				local abilityMult = newData.Stats.FishMoveSpeedMultiplier or 1.0
				local finalSpeed = 21 * base * abilityMult
				
				-- Set Stat for UI
				newData.Stats.PlayerWalkSpeed = finalSpeed
				
				if player.Character and player.Character:FindFirstChild("Humanoid") then
					player.Character.Humanoid.WalkSpeed = finalSpeed
				end
			end
		end
	end
end

-- Auto-hook into Players
-- Check for players already here (in case of reload)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function() PlayerData.start(player) end)
end

Players.PlayerAdded:Connect(PlayerData.start)
Players.PlayerRemoving:Connect(PlayerData.stop)

-- BindToClose: Force-save ALL active sessions when the server shuts down.
-- This is critical for data persistence when switching between private/public servers,
-- since PlayerRemoving may not fire in time during a normal server shutdown.
game:BindToClose(function()
	if RunService:IsStudio() then task.wait(1) return end
	
	local threads = 0
	for userId, data in pairs(SessionData) do
		if not data._LoadFailed then
			ClearTransientFlags(data)
			
			local capturedUserId = userId
			local capturedData = data
			
			threads += 1
			task.spawn(function()
				pcall(function()
					DataStore:UpdateAsync("User_" .. capturedUserId, function(stored)
						if stored and stored._SessionLock and stored._SessionLock ~= game.JobId then
							return nil
						end
						capturedData._SessionLock = nil
						capturedData._LastSaved = os.time()
						return capturedData
					end)
				end)
				threads -= 1
			end)
		end
	end
	
	-- Wait for all saves to complete (up to 25s Roblox limit)
	local start = os.clock()
	while threads > 0 and (os.clock() - start) < 25 do
		task.wait(0.1)
	end
end)

local UpdateSetting = Remotes:FindFirstChild("UpdateSetting")
if not UpdateSetting then
	UpdateSetting = Instance.new("RemoteEvent")
	UpdateSetting.Name = "UpdateSetting"
	UpdateSetting.Parent = Remotes
end

UpdateSetting.OnServerEvent:Connect(function(player, settingName, value)
	PlayerData.update(player, function(data)
		if not data.Settings then data.Settings = {} end
		data.Settings[settingName] = value
		return data
	end)
end)

-- Time Tracking Loop (Increments every minute)
task.spawn(function()
	while true do
		task.wait(60)
		for userId, _ in pairs(SessionData) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				PlayerData.update(player, function(data)
					data.TimePlayed = (data.TimePlayed or 0) + 1
					return data
				end, true) -- Skip remote update for this background task to avoid spam
			end
		end
	end
end)

return PlayerData
