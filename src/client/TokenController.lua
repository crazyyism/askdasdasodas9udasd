local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local NotifierController = require(script.Parent:WaitForChild("NotifierController"))

local TokenController = {}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CollectToken = Remotes:WaitForChild("CollectToken")
local DataUpdateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DataUpdateEvent")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local collectedTokens = {} -- Local Cache
local processingTokens = {} -- Debounce
local localData = nil

local tokenFolder = workspace:WaitForChild("TokenRewards")

local function HideToken(tokenPart, instant)
	if not tokenPart then return end
	tokenPart.CanQuery = false
	tokenPart.CanTouch = false
	
	if instant then
		tokenPart.Transparency = 0.7
		for _, c in ipairs(tokenPart:GetChildren()) do
			if c:IsA("Decal") or c:IsA("Texture") then
				c.Transparency = 0.7
			elseif c:IsA("BillboardGui") then
				c.Enabled = false
			end
		end
	else
		local t = TweenService:Create(tokenPart, TweenInfo.new(0.5), {Transparency = 0.7})
		t:Play()
		
		-- Also hide children (Decals, etc)
		for _, c in ipairs(tokenPart:GetChildren()) do
			if c:IsA("Decal") or c:IsA("Texture") then
				TweenService:Create(c, TweenInfo.new(0.5), {Transparency = 0.7}):Play()
			elseif c:IsA("BillboardGui") then 
				c.Enabled = false 
			end
		end
	end
end



local function GetTokenId(part)
	local id = part:GetAttribute("UniqueId")
	if id then return id end
	
    -- Fallback: Name + Position (Auto-Unique)
	-- Prefer OriginalPosition if set (to handle floating visuals)
	local pos = part:GetAttribute("OriginalPosition")
	if not pos then 
		-- If not set, use current and warn? Or just use current.
		-- Best to force set if missing in Setup, but if called early, use Position.
		pos = part.Position 
	end
	
    local posId = string.format("%d_%d_%d", math.floor(pos.X * 100), math.floor(pos.Y * 100), math.floor(pos.Z * 100))
    return part.Name .. "_" .. posId
end

local function OnTokenTouch(tokenPart)
	if processingTokens[tokenPart] then return end
	
	local tokenId = GetTokenId(tokenPart)
	if collectedTokens[tokenId] then return end
	
	processingTokens[tokenPart] = true
	
	local success, msg = CollectToken:InvokeServer(tokenPart)
	
	processingTokens[tokenPart] = nil
	
	if success then
		local tokenId = GetTokenId(tokenPart)
		collectedTokens[tokenId] = true
		HideToken(tokenPart)
		NotifierController:Notify("Token Collected! " .. (msg or ""), Color3.fromRGB(255, 170, 0))
		
		-- Play Sound if exists
		local sfx = ReplicatedStorage:FindFirstChild("SFX") and ReplicatedStorage.SFX:FindFirstChild("TokenCollect")
		local isSfxDisabled = localData and localData.Settings and localData.Settings.DisableSFX
		if sfx and not isSfxDisabled then sfx:Play() end
	else
		-- If failed because already collected, hide it anyway
		if msg == "Already Collected" then
			local tokenId = GetTokenId(tokenPart)
			collectedTokens[tokenId] = true
			HideToken(tokenPart)
		end
	end
end

local function SetupToken(tokenPart)
	if not tokenPart:IsA("BasePart") then return end
	
	-- Cache original position for ID stability BEFORE tweening
	if not tokenPart:GetAttribute("OriginalPosition") then
		tokenPart:SetAttribute("OriginalPosition", tokenPart.Position)
	end

	-- Visuals: Floating/Spinning
	local originalY = tokenPart.Position.Y
	local floatTween = TweenService:Create(tokenPart, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = tokenPart.Position + Vector3.new(0, 1, 0)
	})
	floatTween:Play()
	
	local spinInfo = TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	local spinTween = TweenService:Create(tokenPart, spinInfo, {Orientation = tokenPart.Orientation + Vector3.new(0, 360, 0)})
	spinTween:Play()

	-- Check if already collected
	local tokenId = GetTokenId(tokenPart)
	if collectedTokens[tokenId] then
		HideToken(tokenPart, true)
		return
	end
	
	-- Touch Detection
	tokenPart.Touched:Connect(function(hit)
		if hit.Parent == player.Character then
			OnTokenTouch(tokenPart)
		end
	end)
end

function TokenController.Start()
	local tokenMap = {} -- [id] = Part

	-- Listen for Data Updates to sync collected state
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		-- Merge Data Logic (Handle Partials)
		if not localData then
			localData = data
		else
			for k, v in pairs(data) do
				localData[k] = v
			end
		end
		if data.CollectedTokens then
			for id, _ in pairs(data.CollectedTokens) do
				collectedTokens[id] = true
				
				-- Hide if currently visible using map lookup
				local t = tokenMap[id]
				if t then 
					HideToken(t, true) 
				else
					-- Fallback search if map not populated yet? (Should be handled by SetupToken checking collectedTokens)
				end
			end
		end
	end)
	
	-- Init existing
	for _, child in ipairs(tokenFolder:GetChildren()) do
		SetupToken(child)
		local id = GetTokenId(child)
		tokenMap[id] = child
	end
	
	-- Listen for new
	tokenFolder.ChildAdded:Connect(function(child)
		SetupToken(child)
		local id = GetTokenId(child)
		tokenMap[id] = child
	end)
	
	-- Re-apply hidden state on character respawn (since StreamOut/In might reset visuals locally)
	player.CharacterAdded:Connect(function()
		task.wait(1) -- Wait for workspace to settle
		for id, _ in pairs(collectedTokens) do
			-- Find token by UniqueId or Name
			for _, child in ipairs(tokenFolder:GetChildren()) do
				if GetTokenId(child) == id then
					HideToken(child, true)
				end
			end
		end
	end)
	
	-- Optimize drop tokens from Sea Mines/Harvesting globally
	local activeDropTokens = {}

	local function AddDropToken(token)
		-- Add slight offset for visuals
		token:SetAttribute("VisualYOffset", math.random() * 1.5)
		token:SetAttribute("OriginalPos", token.Position)
		activeDropTokens[token] = true
	end

	CollectionService:GetInstanceAddedSignal("DropToken"):Connect(AddDropToken)

	CollectionService:GetInstanceRemovedSignal("DropToken"):Connect(function(token)
		activeDropTokens[token] = nil
	end)

	for _, token in ipairs(CollectionService:GetTagged("DropToken")) do
		AddDropToken(token)
	end

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for token, _ in pairs(activeDropTokens) do
			if token.Parent then
				-- We calculate their animation independently based on clock 
				-- so they stay perfectly in sync without accumulating precision loss
				local origPos = token:GetAttribute("OriginalPos")
				if origPos then
					local animTime = now + (token:GetAttribute("VisualYOffset") or 0)
					local floatOffset = math.sin(animTime * 2.5) * 1.5 + 1.5
					local spinRot = (now * 90) % 360
					token.CFrame = CFrame.new(origPos + Vector3.new(0, floatOffset, 0)) * CFrame.Angles(0, math.rad(spinRot), 0)
				end
			end
		end
	end)
end

return TokenController
