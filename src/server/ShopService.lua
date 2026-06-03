local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.Server.PlayerData)
local ShopConfig = require(ReplicatedStorage.Shared.ShopConfig)
local EquipmentConfig = require(ReplicatedStorage.Shared.EquipmentConfig)
local SecurityService = require(script.Parent.SecurityService)

-- Remote Event Setup
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseEvent = Remotes:FindFirstChild("PurchaseShopItem")
if not PurchaseEvent then
	PurchaseEvent = Instance.new("RemoteEvent")
	PurchaseEvent.Name = "PurchaseShopItem"
	PurchaseEvent.Parent = Remotes
end

local ItemAddedEvent = Remotes:FindFirstChild("ItemAddedEvent")
if not ItemAddedEvent then
	ItemAddedEvent = Instance.new("RemoteEvent")
	ItemAddedEvent.Name = "ItemAddedEvent"
	ItemAddedEvent.Parent = Remotes
end

local EquipEvent = Remotes:FindFirstChild("EquipShopItem")
if not EquipEvent then
	EquipEvent = Instance.new("RemoteEvent")
	EquipEvent.Name = "EquipShopItem"
	EquipEvent.Parent = Remotes
end

local ShopService = {}

function ShopService.ProcessPurchase(player, shopName, itemId)
	local itemData = EquipmentConfig[itemId]
	if not itemData then
		warn("Item ID not found:", itemId)
		return
	end
	
	local successData = nil
	local spentAmount = 0
	
	PlayerData.update(player, function(data)
		local price = itemData.Price
		local currency = itemData.Currency
		
		-- Sever-Side Zone Gate Enforcement
		local fishCount = 0
		if data.FishSchool then
			for _, _ in pairs(data.FishSchool) do fishCount += 1 end
		end
		
		local shopCfg = ShopConfig.Shops[shopName]
		if shopCfg and shopCfg.RequiredFish and fishCount < shopCfg.RequiredFish then
			warn("Exploit Prevented: " .. player.Name .. " attempted to buy from " .. shopName .. " with only " .. fishCount .. " fish. (" .. shopCfg.RequiredFish .. " Required)")
			return nil
		end
		
		-- Dynamic Pricing Logic
		if itemData.Scaling then
			local count = (data.PurchaseStats and data.PurchaseStats[itemData.Name]) or 0
			local base = itemData.Scaling.Base or price
			local mult = itemData.Scaling.Multiplier or 1
			local max = itemData.Scaling.Max or math.huge
			
			price = math.min(base * (mult ^ count), max)
		end
		
		-- Check Ownership (Tools/Backpacks)
		if itemData.ProductType == "Tool" and data.UnlockedTools and table.find(data.UnlockedTools, itemData.ToolId) then
			return nil
		elseif itemData.ProductType == "Backpack" and data.UnlockedBackpacks and table.find(data.UnlockedBackpacks, itemData.BackpackId) then
			return nil
		elseif itemData.ProductType == "Artifact" and data.UnlockedArtifacts and table.find(data.UnlockedArtifacts, itemData.Name) then
			return nil
		end
		
		-- Check balance
		if currency == "Biomass" then
			if data.Biomass < price then
				return nil -- Cancel update
			end
			data.Biomass -= price
		elseif currency == "Algae" then
			-- Sum up all plankton as "Algae"
			local totalAlgae = 0
			if data.Plankton then
				for _, v in pairs(data.Plankton) do totalAlgae += v end
			end
			
			if totalAlgae < price then
				return nil
			end
			
			-- Deduct proportional or from specific? 
			local remainingToPay = price
			-- Pink first
			local currentPink = data.Plankton and data.Plankton.PinkAlgae or 0
			local pinkDeduct = math.min(currentPink, remainingToPay)
			if data.Plankton then data.Plankton.PinkAlgae = currentPink - pinkDeduct end
			remainingToPay -= pinkDeduct
			
			-- Orange next
			if remainingToPay > 0 then
				local currentOrange = data.Plankton and data.Plankton.OrangeAlgae or 0
				local orangeDeduct = math.min(currentOrange, remainingToPay)
				if data.Plankton then data.Plankton.OrangeAlgae = currentOrange - orangeDeduct end
				remainingToPay -= orangeDeduct
			end
			
			-- Green last
			if remainingToPay > 0 then
				local currentGreen = data.Plankton and data.Plankton.GreenAlgae or 0
				local greenDeduct = math.min(currentGreen, remainingToPay)
				if data.Plankton then data.Plankton.GreenAlgae = currentGreen - greenDeduct end
				remainingToPay -= greenDeduct
			end
		else
			-- Assume free? or warn
			if price > 0 then
				warn("Unknown currency type:", currency)
				return nil
			end
		end
		
		-- Rhythm Egg Unique Purchase Enforcement
		if itemId == "Rhythm Egg" then
			if data.Inventory and (data.Inventory["Rhythm Egg"] or 0) > 0 then
				return nil
			end
			if data.FishSchool then
				for _, fish in pairs(data.FishSchool) do
					if fish.Id == "Rhythm Fish" or fish.Id == "Rhythm Egg" then
						return nil
					end
				end
			end
			-- Fallback Server Check
			local MarketplaceService = game:GetService("MarketplaceService")
			local owns = false
			pcall(function() owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1661441381) end)
			if owns then return nil end
		end
		
		-- Check and Deduct Materials
		if itemData.Materials then
			for matName, required in pairs(itemData.Materials) do
				if matName == "Pearl" then
					local currentPearls = data.Pearls or 0
					if currentPearls < required then
						return nil -- Not enough pearls
					end
					data.Pearls = currentPearls - required
				else
					local ownedAmount = (data.Inventory and data.Inventory[matName]) or 0
					if ownedAmount < required then
						return nil -- Not enough materials
					end
					
					-- Deduct
					data.Inventory[matName] = data.Inventory[matName] - required
					if data.Inventory[matName] <= 0 then data.Inventory[matName] = nil end
					data._InventoryDirty = true
				end
			end
		end
		
		-- Give the item
		if itemData.ProductType == "Tool" then
			if not data.UnlockedTools then data.UnlockedTools = {} end
			if not table.find(data.UnlockedTools, itemData.ToolId) then
				table.insert(data.UnlockedTools, itemData.ToolId)
				data._UnlockablesDirty = true
			end
			data.EquippedTool = itemData.ToolId -- Auto-equip
			
			-- Physically give the tool if it exists
			local toolsFolder = ReplicatedStorage:FindFirstChild("Tools")
			local toolModel = toolsFolder and toolsFolder:FindFirstChild(itemData.ToolId)
			if toolModel then
				local newTool = toolModel:Clone()
				newTool.Parent = player.Backpack
				local currentTool = player.Character and player.Character:FindFirstChildWhichIsA("Tool")
				if currentTool then currentTool:Destroy() end -- Remove old
				newTool.Parent = player.Character -- Equip new
			end
			
		elseif itemData.ProductType == "Backpack" then
			if not data.UnlockedBackpacks then data.UnlockedBackpacks = {} end
			if not table.find(data.UnlockedBackpacks, itemData.BackpackId) then
				table.insert(data.UnlockedBackpacks, itemData.BackpackId)
				data._UnlockablesDirty = true
			end
			data.EquippedBackpack = itemData.BackpackId
			
			-- Recalculate Stats
			PlayerData.RecalculateStats(data)
			
		elseif itemData.ProductType == "Artifact" then
			if not data.UnlockedArtifacts then data.UnlockedArtifacts = {} end
			if not table.find(data.UnlockedArtifacts, itemData.Name) then
				table.insert(data.UnlockedArtifacts, itemData.Name)
				data._UnlockablesDirty = true
			end
			if not data.EquippedArtifacts then data.EquippedArtifacts = {} end
			if #data.EquippedArtifacts < 2 then
				table.insert(data.EquippedArtifacts, itemData.Name)
				PlayerData.RecalculateStats(data)
			end
			
		else
			-- Regular items (Eggs/Etc)
			if type(data.Inventory) ~= "table" then
				data.Inventory = {}
			end
			
			data.Inventory[itemData.Name] = (data.Inventory[itemData.Name] or 0) + (itemData.Amount or 1)
			data._InventoryDirty = true
		end
		
		-- Update Purchase Stats for scaling
		if not data.PurchaseStats then data.PurchaseStats = {} end
		data.PurchaseStats[itemData.Name] = (data.PurchaseStats[itemData.Name] or 0) + 1
		
		-- Track specifically for Quest Progress!
		if itemType == "Tool" or itemType == "Backpack" then
			data.EquipmentsPurchased = (data.EquipmentsPurchased or 0) + 1
		end
		
		spentAmount = price
		successData = data
		return data
	end)
	
	if successData then
		-- Fire lightweight event
		local newBalance = 0
		if itemData.Currency == "Biomass" then
			newBalance = successData.Biomass
		elseif itemData.Currency == "Algae" then
			-- Calc total algae
			for _, v in pairs(successData.Plankton or {}) do newBalance += v end
		end
		
		ItemAddedEvent:FireClient(player, itemData.Name, itemData.Amount or 1, itemData.Currency, spentAmount, newBalance)
	end
end

-- Connect the remote
-- Connect the remote
PurchaseEvent.OnServerEvent:Connect(function(player, shopName, itemId)
	if not SecurityService.ValidateRemoteCall(player, "PurchaseShopItem") then return end
	ShopService.ProcessPurchase(player, shopName, itemId)
end)

function ShopService.ProcessEquip(player, itemType, itemId)
	PlayerData.update(player, function(data)
		if itemType == "Tool" then
			if data.UnlockedTools and table.find(data.UnlockedTools, itemId) then
				data.EquippedTool = itemId
				
				-- Physically equip
				local toolsFolder = ReplicatedStorage:FindFirstChild("Tools")
				local toolModel = toolsFolder and toolsFolder:FindFirstChild(itemId)
				if toolModel then
					local newTool = toolModel:Clone()
					newTool.Parent = player.Backpack
					
					if player.Character then
						local currentTool = player.Character:FindFirstChildWhichIsA("Tool")
						if currentTool then currentTool:Destroy() end
						newTool.Parent = player.Character
					end
				end
			end
		elseif itemType == "Backpack" then
			if data.UnlockedBackpacks and table.find(data.UnlockedBackpacks, itemId) then
				data.EquippedBackpack = itemId
				PlayerData.RecalculateStats(data)
			end
		elseif itemType == "Artifact" then
			if data.UnlockedArtifacts and table.find(data.UnlockedArtifacts, itemId) then
				if not data.EquippedArtifacts then data.EquippedArtifacts = {} end
				
				-- Check if already equipped
				local tablePos = table.find(data.EquippedArtifacts, itemId)
				if tablePos then
					-- Unequip (Toggle off if trying to equip same item)
					-- Or typically UI sends "Unequip" via a separate action, but sticking to "Equip" usually means "Toggle" or "Select".
					-- Given "can have up to two", clicking an equipped one usually unequips it.
					table.remove(data.EquippedArtifacts, tablePos)
				else
					-- Equip
					if #data.EquippedArtifacts >= 2 then
						table.remove(data.EquippedArtifacts, 1) -- Remove oldest (limit 2)
					end
					table.insert(data.EquippedArtifacts, itemId)
				end
				PlayerData.RecalculateStats(data)
			end
		end
		return data
	end)
end

EquipEvent.OnServerEvent:Connect(function(player, itemType, itemId)
	if not SecurityService.ValidateRemoteCall(player, "EquipShopItem") then return end
	ShopService.ProcessEquip(player, itemType, itemId)
end)

return ShopService
