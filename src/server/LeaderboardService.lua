local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerData = require(script.Parent.PlayerData)

local LeaderboardService = {}

local function FormatTime(minutes)
	minutes = math.floor(minutes)
	if minutes < 60 then
		return minutes .. "m"
	end
	
	local hours = math.floor(minutes / 60)
	local mins = minutes % 60
	
	if hours < 24 then
		return string.format("%dh %dm", hours, mins)
	end
	
	local days = math.floor(hours / 24)
	hours = hours % 24
	
	return string.format("%dd %dh", days, hours)
end

local LEADERBOARDS = {
	{
		Id = "Algae",
		ODS = DataStoreService:GetOrderedDataStore("GlobalAlgaeLeaderboard"),
		StatKey = "LifetimeAlgae",
		ModelName = "GlobalLeaderboard",
		ScoreLabelCandidates = {"AlgaeCollected", "Score", "Value"}
	},
	{
		Id = "Biomass",
		ODS = DataStoreService:GetOrderedDataStore("GlobalBiomassLeaderboard"),
		StatKey = "LifetimeBiomass",
		ModelName = "BiomassLeaderboard",
		ScoreLabelCandidates = {"BiomassCollected", "AlgaeCollected", "Score", "Value"} 
	},
	{
		Id = "TimePlayed",
		ODS = DataStoreService:GetOrderedDataStore("GlobalTimePlayedLeaderboard_v1"),
		StatKey = "TimePlayed",
		ModelName = "TimeLeaderboard",
		ScoreLabelCandidates = {"TimePlayed", "AlgaeCollected", "Score", "Value"},
		Formatter = FormatTime
	},
	{
		Id = "NoobieTurtle",
		ODS = DataStoreService:GetOrderedDataStore("GlobalNoobieTurtleLeaderboard"),
		StatKey = "NoobieTurtleQuestsCompleted",
		ModelName = "NoobieTurtleLeaderboard",
		ScoreLabelCandidates = {"QuestsCompleted", "TimePlayed", "AlgaeCollected", "Score", "Value"}
	}
}

local REFRESH_RATE = 120 -- Increased from 30s to 120s to stop DataStore ratelimits
local UsernameCache = {}
local LastSavedScores = {}

local function Abbreviate(number)
	local suffixes = {"k", "M", "B", "T", "qd", "Qn", "sx", "Sp", "O", "N", "de", "Ud", "DD", "tdD", "qdD", "QnD", "sxD", "SpD", "OcD", "NvD", "Vig", "uVig", "dVig", "tVig", "qVig", "QnVE", "sxVig", "SpVig", "OcVig", "NvVig", "Trig", "uTrig", "dTrig", "tTrig", "qTrig", "QnTrig", "sxTrig", "SpTrig", "OcTrig", "NvTrig"}
	local s = 0 
	math.floor(number)
	local str = tostring(math.floor(number))
	if #str < 4 then return str end
	
	local scale = math.floor((#str - 1) / 3)
	local left = number / (10 ^ (scale * 3))
	
	local suffix = suffixes[scale] or "?"
	return string.format("%.1f%s", left, suffix)
end

local function UpdateSingleBoard(config)
	local ODS = config.ODS
	
	-- 1. Save current players' data to ODS
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.get(player)
		if data and data[config.StatKey] then
			local val = math.floor(data[config.StatKey] or 0)
			
			local uid = tostring(player.UserId)
			if not LastSavedScores[uid] then LastSavedScores[uid] = {} end
			
			-- Only fire SetAsync if the player's value actually changed since the last 2 minute poll!
			if LastSavedScores[uid][config.Id] ~= val then
				local success = false
				for attempt = 1, 3 do
					success = pcall(function()
						ODS:SetAsync(uid, val)
					end)
					if success then break end
					if attempt < 3 then task.wait(2 * attempt) end
				end
				
				if success then
					LastSavedScores[uid][config.Id] = val
				else
					warn("Leaderboard ("..config.Id.."): ODS:SetAsync formally failed after 3 Retries!")
				end
				
				task.wait(0.2) -- Stagger consecutive updates so we don't bombard the ratelimit queue
			end
		end
	end

	-- 2. Get Sorted Data
	local success, pages = false, nil
	for attempt = 1, 3 do
		success, pages = pcall(function()
			return ODS:GetSortedAsync(false, 50) -- Descending
		end)
		if success and pages then break end
		if attempt < 3 then task.wait(3 * attempt) end -- Auto-healing Exponential Backoff for 500 API errors
	end

	if success and pages then
		local data = pages:GetCurrentPage()
		
		-- 3. Update Visuals
		local model = workspace:FindFirstChild(config.ModelName)
		if not model then 
			-- Don't warn every time if the model is missing, maybe it's not setup yet
			return 
		end
		
		local display = model:FindFirstChild("LeaderboardDisplay") -- SurfaceGui
		if not display then return end
		
		local mainFrame = display:FindFirstChild("MainFrame")
		if not mainFrame then return end
		
		local entries = mainFrame:FindFirstChild("Entries")
		if not entries then return end
		
		local template = entries:FindFirstChild("Entry_Template")
		-- Create template if not exists from Entry_1
		if not template then
			local e1 = entries:FindFirstChild("Entry_1")
			if e1 then
				template = e1:Clone()
				template.Name = "Entry_Template"
				template.Parent = nil 
				e1.Visible = false
				e1.Name = "Entry_Template"
				template = e1
			else
				warn("Leaderboard ("..config.Id.."): No Entry_1 to clone from")
				return
			end
		end
		
		-- Clear old entries (except template)
		for _, child in ipairs(entries:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "Entry_Template" then
				child:Destroy()
			end
		end
		
		-- Populate
		for rank, entry in ipairs(data) do
			local userId = entry.key
			local score = entry.value
			
			local newEntry = template:Clone()
			newEntry.Name = "Rank_" .. rank
			newEntry.Visible = true
			newEntry.Parent = entries
			
			-- Setup Data
			local nameLabel = newEntry:FindFirstChild("Name")
			local posLabel = newEntry:FindFirstChild("Pos")
			
			-- Find Score Label
			local scoreLabel = nil
			for _, candidate in ipairs(config.ScoreLabelCandidates) do
				scoreLabel = newEntry:FindFirstChild(candidate)
				if scoreLabel then break end
			end
			
			if nameLabel then
				if UsernameCache[userId] then
					nameLabel.Text = UsernameCache[userId]
				else
					nameLabel.Text = "Loading..."
					task.spawn(function()
						local nameSuccess, name = pcall(function()
							return Players:GetNameFromUserIdAsync(tonumber(userId))
						end)
						if nameSuccess and name then
							UsernameCache[userId] = name
							if nameLabel and nameLabel.Parent then
								nameLabel.Text = name
							end
						else
							if nameLabel and nameLabel.Parent then
								nameLabel.Text = "Unknown"
							end
						end
					end)
				end
			end
			
			if scoreLabel then
				if config.Formatter then
					scoreLabel.Text = config.Formatter(score)
				else
					scoreLabel.Text = Abbreviate(score)
				end
			end
			
			if posLabel then
				posLabel.Text = "#" .. rank
			end
		end
	else
		warn("Leaderboard ("..config.Id.."): Failed to fetch ODS pages")
	end
end

local function UpdateAllBoards()
	for _, boardConfig in ipairs(LEADERBOARDS) do
		task.spawn(function()
			UpdateSingleBoard(boardConfig)
		end)
		-- Stagger the 4 Leaderboards by 3.5 seconds each to explicitly prevent Roblox 'InternalServerError' flooding
		task.wait(3.5)
	end
end

function LeaderboardService.GetTopPlayers(limit, boardId)
	limit = limit or 30
	boardId = boardId or "Algae" -- Default to Algae old behavior
	
	local config = nil
	for _, b in ipairs(LEADERBOARDS) do
		if b.Id == boardId then
			config = b
			break
		end
	end
	
	if not config then
		warn("LeaderboardService: Invalid Board ID " .. tostring(boardId))
		return {}
	end
	
	local ODS = config.ODS
	local success, pages = pcall(function()
		return ODS:GetSortedAsync(false, limit)
	end)

	if not success or not pages then 
		warn("Failed to fetch leaderboard data for " .. boardId)
		return {} 
	end

	local data = pages:GetCurrentPage()
	local results = {}

	for rank, entry in ipairs(data) do
		local userId = entry.key
		local score = entry.value
		local name = "Loading..."
		
		if UsernameCache[userId] then
			name = UsernameCache[userId]
		else
			local nameSuccess, fetchedName = pcall(function()
				return Players:GetNameFromUserIdAsync(tonumber(userId))
			end)
			if nameSuccess and fetchedName then
				name = fetchedName
				UsernameCache[userId] = name
			else
				name = "Unknown"
			end
			task.wait(0.05) -- Prevent hard-locking the server threads if 50+ missing players need to be resolved!
		end
		
		table.insert(results, {
			Rank = rank,
			Name = name,
			UserId = userId, 
			Score = score
		})
	end

	return results
end


function LeaderboardService.CreateSnapshot(snapshotName)
	-- Default to Algae for snapshot if not specified, 
	-- but actually snapshots usually aggregate or are specific. 
	-- The previous code just called GetTopPlayers(100) which defaulted to Algae.
	-- We preserve this behavior.
	local entries = LeaderboardService.GetTopPlayers(100, "Algae") 
	local SnapshotDS = DataStoreService:GetDataStore("LeaderboardSnapshots")
	
	if #entries == 0 then
		warn("No entries found to snapshot.")
		return
	end

	local success, err = pcall(function()
		SnapshotDS:SetAsync(snapshotName, entries)
	end)

	if success then
		print("Successfully saved snapshot '" .. snapshotName .. "' with " .. #entries .. " entries.")
	else
		warn("Failed to save snapshot: " .. tostring(err))
	end
end

function LeaderboardService.GetSnapshot(snapshotName)
	local SnapshotDS = DataStoreService:GetDataStore("LeaderboardSnapshots")
	local success, data = pcall(function()
		return SnapshotDS:GetAsync(snapshotName)
	end)
	
	if success and data then
		return data
	else
		warn("Failed to load snapshot '" .. snapshotName .. "'")
		return nil
	end
end

-- Init Loop
task.spawn(function()
	while true do
		UpdateAllBoards()
		task.wait(REFRESH_RATE)
	end
end)

return LeaderboardService
