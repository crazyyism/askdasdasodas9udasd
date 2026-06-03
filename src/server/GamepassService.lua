local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(script.Parent.PlayerData)

local GamepassService = {}

-- ==================== CONFIGURATION ====================
GamepassService.Gamepasses = {
	["Rhythm Egg"] = {
		Id = 1661441381,
		Type = "Item",
		GrantOnce = true, -- Only grant if not in inventory
	},
}
-- =======================================================

function GamepassService.CheckAndGrantItems(player)
	-- ... (Wait Logic remains same)
	-- Wait for data ...
	local attempts = 0
	while not PlayerData.isLoaded(player) and attempts < 15 do
		task.wait(1)
		attempts += 1
	end

	if not PlayerData.isLoaded(player) then 
		warn("GamepassService: Failed to load data for " .. player.Name .. " after 15s")
		return 
	end

	local data = PlayerData.get(player)
	if data and data._LoadFailed then 
		warn("GamepassService: Data load failed for " .. player.Name .. ", skipping gamepass grant to protect data.")
		return 
	end

	for itemName, config in pairs(GamepassService.Gamepasses) do
		if config.Type == "Item" then
			task.spawn(function()
				print("GamepassService: Checking " .. itemName .. " (" .. config.Id .. ") for " .. player.Name)
				local success, result = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, config.Id)
				end)
				
				local owns = false
				local err = nil
				if success then
					owns = result
				else
					err = result
				end
				
				-- Bypass for Testers
				if player.Name == "Player1" or player.Name == "Player2" then
					print("GamepassService: Tester bypass active for " .. player.Name)
					owns = true
					success = true
				end

				if success then
					if owns then
						print("GamepassService: " .. player.Name .. " OWNS " .. itemName)
						PlayerData.update(player, function(d)
							if type(d.Inventory) ~= "table" then d.Inventory = {} end
							
							local grant = true
							local denialReason = ""
							
							if config.GrantOnce then
								-- Check Inventory
								if d.Inventory[itemName] and d.Inventory[itemName] > 0 then
									grant = false
									denialReason = "Already in Inventory"
								end
							end
							
							if grant then
								print("GamepassService: Granting " .. itemName .. " to " .. player.Name)
								d.Inventory[itemName] = (d.Inventory[itemName] or 0) + 1
							else
								print("GamepassService: Not granting " .. itemName .. " to " .. player.Name .. ". Reason: " .. denialReason)
							end
							
							return d
						end)
					else
						print("GamepassService: " .. player.Name .. " DOES NOT OWN " .. itemName)
					end
				else
					warn("GamepassService: Failed to check gamepass " .. config.Id .. " for " .. player.Name .. ": " .. tostring(err))
				end
			end)
		end
	end
end


function GamepassService.Start()
	Players.PlayerAdded:Connect(function(player)
		-- Wait a bit for PlayerData to initialize
		task.wait(1)
		GamepassService.CheckAndGrantItems(player)
	end)

	-- Handle players already in the server
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			task.wait(1)
			GamepassService.CheckAndGrantItems(player)
		end)
	end

	-- Handle purchases while in-game
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
		if not wasPurchased then return end
		
		for itemName, config in pairs(GamepassService.Gamepasses) do
			if config.Id == gamepassId and config.Type == "Item" then
				PlayerData.update(player, function(d)
					if type(d.Inventory) ~= "table" then d.Inventory = {} end
					if config.GrantOnce then
						if not d.Inventory[itemName] or d.Inventory[itemName] <= 0 then
							d.Inventory[itemName] = (d.Inventory[itemName] or 0) + 1
						end
					else
						d.Inventory[itemName] = (d.Inventory[itemName] or 0) + 1
					end
					return d
				end)
			end
		end
	end)
end

return GamepassService
