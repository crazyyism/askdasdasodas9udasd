local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)

local TokenService = {}

-- Setup Remotes
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local CollectToken = Remotes:FindFirstChild("CollectToken")
if not CollectToken then
	CollectToken = Instance.new("RemoteFunction")
	CollectToken.Name = "CollectToken"
	CollectToken.Parent = Remotes
end

-- Ensure Token Folder Exists
local tokenFolder = workspace:FindFirstChild("TokenRewards")
if not tokenFolder then
	tokenFolder = Instance.new("Folder")
	tokenFolder.Name = "TokenRewards"
	tokenFolder.Parent = workspace
end

function TokenService.Start()
	CollectToken.OnServerInvoke = function(player, tokenPart)
		if not tokenPart or not tokenPart:IsDescendantOf(tokenFolder) then
			return false, "Invalid Token"
		end
		
		-- Distance Check
		if player.Character and player.Character.PrimaryPart then
			local dist = (player.Character.PrimaryPart.Position - tokenPart.Position).Magnitude
			if dist > 15 then -- generous allowance for lag
				return false, "Too Far" 
			end
		else
			return false, "No Character"
		end
		
		-- Check Persistence
		-- Priority: Attribute "UniqueId" > Name + Position (Auto-Unique)
		local tokenId = tokenPart:GetAttribute("UniqueId")
		
		if not tokenId then
        -- Generate ID based on Position (Resolution: 0.01 studs)
        local pos = tokenPart.Position
        local posId = string.format("%d_%d_%d", math.floor(pos.X * 100), math.floor(pos.Y * 100), math.floor(pos.Z * 100))
        tokenId = tokenPart.Name .. "_" .. posId
    end 

		local success = false
		local rewardMsg = ""
		
		PlayerData.update(player, function(data)
			if not data.CollectedTokens then data.CollectedTokens = {} end
			
			if data.CollectedTokens[tokenId] then
				return nil -- Already collected
			end
			
			-- Mark Collected
			data.CollectedTokens[tokenId] = os.time()
			data._TokensDirty = true
			success = true
			
			-- Give Rewards
			-- Read from ValueObjects or Attributes inside the part
			local biomassVal = tokenPart:GetAttribute("Biomass") or tokenPart:FindFirstChild("Biomass")
			local algaeVal = tokenPart:GetAttribute("Algae") or tokenPart:FindFirstChild("Algae")
			local itemVal = tokenPart:GetAttribute("Item") or tokenPart:FindFirstChild("Item")
			
			-- Allow Attributes or IntValues/StringValues
			local bAmt = (type(biomassVal) == "number" and biomassVal) or (biomassVal and biomassVal.Value) or 0
			local aAmt = (type(algaeVal) == "number" and algaeVal) or (algaeVal and algaeVal.Value) or 0
			local iName = (type(itemVal) == "string" and itemVal) or (itemVal and itemVal.Value) or nil
			
			if bAmt > 0 then
				data.Biomass = (data.Biomass or 0) + bAmt
				rewardMsg = rewardMsg .. "+" .. bAmt .. " Biomass "
				
				-- Leaderstats update
				local ls = player:FindFirstChild("leaderstats")
				if ls and ls:FindFirstChild("Biomass") then
					ls.Biomass.Value = data.Biomass
				end
			end
			
			if aAmt > 0 then
				local HarvestService = require(script.Parent.HarvestService)
				local critResult = HarvestService.RollCriticalOutcome(data)
				local critMult = HarvestService.GetCritMultiplier(data, critResult)
				
				aAmt = math.floor(aAmt * critMult)
				
				local aType = tokenPart:GetAttribute("AlgaeType") or "GreenAlgae"
				data.Plankton[aType] = (data.Plankton[aType] or 0) + aAmt
				data.LifetimeAlgae = (data.LifetimeAlgae or 0) + aAmt
				
				if critResult == "MegaCritical" then
					rewardMsg = rewardMsg .. "+" .. aAmt .. " " .. aType .. " (MEGA CRIT!) "
				elseif critResult == "Critical" then
					rewardMsg = rewardMsg .. "+" .. aAmt .. " " .. aType .. " (Crit!) "
				else
					rewardMsg = rewardMsg .. "+" .. aAmt .. " " .. aType .. " "
				end
			end
			
			if iName then
				if type(data.Inventory) ~= "table" then data.Inventory = {} end
				data.Inventory[iName] = (data.Inventory[iName] or 0) + 1
				data._InventoryDirty = true
				rewardMsg = rewardMsg .. "+1 " .. iName .. " "
			end
			
			return data
		end)
		
		if success then
			return true, rewardMsg
		else
			return false, "Already Collected"
		end
	end
end

return TokenService
