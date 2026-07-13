local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local ChanceConfig = require(ReplicatedStorage.Shared.ChanceConfig)

local WishingShrineService = {}

local COOLDOWN_SECONDS = 3600 -- 1 Hour
local REQUIRED_FISH = 10

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local ClaimWishingShrineEvent = Remotes:FindFirstChild("ClaimWishingShrine")
if not ClaimWishingShrineEvent then
	ClaimWishingShrineEvent = Instance.new("RemoteEvent")
	ClaimWishingShrineEvent.Name = "ClaimWishingShrine"
	ClaimWishingShrineEvent.Parent = Remotes
end

local function GetRandomItem()
	local totalWeight = 0
	for _, drop in ipairs(ChanceConfig.WishingShrineDrops) do
		totalWeight = totalWeight + drop.Chance
	end
	
	local rand = math.random() * totalWeight
	for _, drop in ipairs(ChanceConfig.WishingShrineDrops) do
		if rand <= drop.Chance then
			return drop.Item
		end
		rand = rand - drop.Chance
	end
	return "Biomass"
end

local function GetRollCount()
	local totalWeight = 0
	for _, roll in ipairs(ChanceConfig.WishingShrineRolls) do
		totalWeight = totalWeight + roll.Chance
	end
	
	local rand = math.random() * totalWeight
	for _, roll in ipairs(ChanceConfig.WishingShrineRolls) do
		if rand <= roll.Chance then
			return roll.Amount
		end
		rand = rand - roll.Chance
	end
	return 1
end

function WishingShrineService.Start()
	ClaimWishingShrineEvent.OnServerEvent:Connect(function(player)
		local data = PlayerData.get(player)
		if not data then return end
		
		-- Check Cooldown
		local lastClaim = data.LastShrineClaim or 0
		local timeSince = os.time() - lastClaim
		if timeSince < COOLDOWN_SECONDS then
			-- Send cooldown notification
			local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
			if NotificationEvent then
				local timeLeft = COOLDOWN_SECONDS - timeSince
				local mins = math.ceil(timeLeft / 60)
				NotificationEvent:FireClient(player, "Shrine is recharging! Wait " .. mins .. " mins.", Color3.fromRGB(255, 100, 100))
			end
			return
		end
		
		-- Check Fish Requirement
		local fishCount = 0
		if data.FishSchool then
			for _, _ in pairs(data.FishSchool) do
				fishCount = fishCount + 1
			end
		end
		
		if fishCount < REQUIRED_FISH then
			local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
			if NotificationEvent then
				NotificationEvent:FireClient(player, "You need " .. REQUIRED_FISH .. " fish to use the shrine!", Color3.fromRGB(255, 100, 100))
			end
			return
		end
		
		-- Passed checks, grant rewards
		local rollCount = GetRollCount()
		local grantedItems = {}
		local grantedBiomass = 0
		
		for i = 1, rollCount do
			local item = GetRandomItem()
			if item == "Biomass" then
				grantedBiomass = grantedBiomass + math.random(5000, 15000)
			else
				local amount = 1
				if item == "Fish Feed" or item == "Zooplankton" then
					amount = math.random(3, 5)
				elseif item == "Pearl" then
					amount = math.random(5, 10)
				end
				grantedItems[item] = (grantedItems[item] or 0) + amount
			end
		end
		
		-- Update Data
		PlayerData.update(player, function(d)
			d.LastShrineClaim = os.time()
			
			if grantedBiomass > 0 then
				d.Biomass = (d.Biomass or 0) + grantedBiomass
				d.LifetimeBiomass = (d.LifetimeBiomass or d.Biomass or 0) + grantedBiomass
			end
			
			for itemName, qty in pairs(grantedItems) do
				if itemName == "Pearl" then
					d.Pearls = (d.Pearls or 0) + qty
				else
					if not d.Inventory then d.Inventory = {} end
					d.Inventory[itemName] = (d.Inventory[itemName] or 0) + qty
					d._InventoryDirty = true
				end
			end
			
			return d
		end)
		
		-- Send UI Updates
		local ls = player:FindFirstChild("leaderstats")
		if grantedBiomass > 0 and ls and ls:FindFirstChild("Biomass") then
			ls.Biomass.Value = (ls.Biomass.Value or 0) + grantedBiomass
			local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
			if NotificationEvent then
				NotificationEvent:FireClient(player, "+" .. grantedBiomass .. " Biomass from Shrine!", Color3.fromRGB(0, 255, 255))
			end
		end
		
		local ItemAddedEvent = Remotes:FindFirstChild("ItemAddedEvent")
		if ItemAddedEvent then
			for itemName, qty in pairs(grantedItems) do
				ItemAddedEvent:FireClient(player, itemName, qty, "Item", 0, 0)
			end
		end
		
		-- Success sound/VFX could be added via remote here if desired
		local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
		if NotificationEvent then
			NotificationEvent:FireClient(player, "The Shrine has answered your wish!", Color3.fromRGB(150, 255, 100))
		end
	end)
end

return WishingShrineService
