local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.Server.PlayerData)

local SecurityService = {}

local playerStats = {} -- [userId] = { LastPos = Vector3, LastTime = number, Violations = number }
local remoteUsage = {} -- [userId] = { [remoteName] = { Count = number, LastReset = number } }

local MAX_VELOCITY_TOLERANCE = 1.3 -- 30% margin for latency/physics
local MAX_VIOLATIONS = 5 -- How many times they can fail before being flagged/kicked
local REMOTE_LIMIT_WINDOW = 1.0 -- 1 second
local MAX_REMOTES_PER_WINDOW = 30 -- Adjust based on batching needs

function SecurityService.LogViolation(player, reason)
	-- Disabled per user request
	return
end

-- Check if player is moving too fast
-- Velocity check disabled per user request
function SecurityService.CheckVelocity(player)
	return
end

-- Rate limit remote usage
function SecurityService.ValidateRemoteCall(player, remoteName)
	-- Disabled per user request
	return true
end

function SecurityService.Start()
	Players.PlayerAdded:Connect(function(player)
		playerStats[player.UserId] = { LastPos = Vector3.zero, LastTime = os.clock(), Violations = 0 }
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		playerStats[player.UserId] = nil
		remoteUsage[player.UserId] = nil
	end)
end

return SecurityService
