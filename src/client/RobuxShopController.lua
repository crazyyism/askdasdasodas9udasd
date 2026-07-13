local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local RobuxShopConfig = require(ReplicatedStorage.Shared.RobuxShopConfig)
local NotifierController = require(script.Parent:WaitForChild("NotifierController"))

local player = Players.LocalPlayer

local localData = nil
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")
DataUpdateEvent.OnClientEvent:Connect(function(data)
	localData = data
end)

local RobuxShopController = {}

function RobuxShopController.Start()
	local mainGui = player:WaitForChild("PlayerGui"):WaitForChild("Main", 10)
	if not mainGui then return end
	
	local robuxFrame = mainGui:FindFirstChild("RobuxFrame", true)
	if not robuxFrame then return end
	
	local scrollFrame = robuxFrame:FindFirstChild("ScrollingFrame")
	if not scrollFrame then return end
	
	local template = scrollFrame:FindFirstChild("TemplatePurchase")
	if not template then return end
	
	template.Visible = false
	
	-- We need a local cache of PlayerData to check if they already have the item
	local localData = nil
	local DataUpdateEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DataUpdateEvent")
	
	DataUpdateEvent.OnClientEvent:Connect(function(data)
		if data then
			localData = data
			RobuxShopController.RefreshUI()
		end
	end)
	
	-- Store all the generated item buttons so we can update them later
	RobuxShopController.ItemFrames = {}
	
	for key, itemData in pairs(RobuxShopConfig.Items) do
		local clone = template:Clone()
		clone.Name = key
		clone.Visible = true
		clone.Parent = scrollFrame
		print("[RobuxShop] Cloned template for:", key)
		
		local titleLabel = clone:FindFirstChild("MaterialTitle", true)
		local descLabel = clone:FindFirstChild("MaterialDescription", true)
		local priceLabel = clone:FindFirstChild("Price", true)
		local imgLabel = clone:FindFirstChild("ImageLabel", true)
		
		if titleLabel then titleLabel.Text = itemData.Name or key end
		if descLabel then descLabel.Text = itemData.Description or "" end
		if priceLabel then priceLabel.Text = itemData.Price or "???" end
		if imgLabel then 
			imgLabel.Image = itemData.ImageId or "" 
			
			if itemData.RainbowImage then
				-- Animate the background color through the rainbow
				task.spawn(function()
					local RunService = game:GetService("RunService")
					RunService.RenderStepped:Connect(function()
						if not imgLabel.Parent then return end
						-- Cycle through hue (0 to 1) over time (e.g. 2 seconds full loop)
						local hue = (tick() % 2) / 2
						if itemData.ModelName then
							imgLabel.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
						else
							imgLabel.ImageColor3 = Color3.fromHSV(hue, 1, 1)
						end
					end)
				end)
			end
			
			if itemData.ModelName then
				imgLabel.Image = "" -- Clear the image so the rainbow color is a solid block behind the fish
				imgLabel.BackgroundTransparency = 0 -- Make background visible for rainbow
				local vp = Instance.new("ViewportFrame")
				vp.Size = UDim2.new(1, 0, 1, 0)
				vp.BackgroundTransparency = 1
				vp.Ambient = Color3.new(1, 1, 1)
				vp.LightColor = Color3.new(1, 1, 1)
				vp.LightDirection = Vector3.new(0, -1, -1)
				vp.ZIndex = imgLabel.ZIndex + 1
				vp.Parent = imgLabel
				
				local cam = Instance.new("Camera")
				vp.CurrentCamera = cam
				cam.Parent = vp
				
				local FishModels = ReplicatedStorage:WaitForChild("Fishes")
				local templateM = FishModels:FindFirstChild(itemData.ModelName)
				print("[RobuxShop] Model search for", itemData.ModelName, "Result:", templateM ~= nil)
				if templateM then
					local m = templateM:Clone()
					m.Parent = vp
					
					local cf, size = m:GetBoundingBox()
					local currentRotation = cf - cf.Position
					local desiredOffset = CFrame.Angles(0, math.rad(240), 0)
					local finalCF = CFrame.new(0, 0, 0) * currentRotation * desiredOffset
					
					if m.PrimaryPart then
						m:PivotTo(finalCF)
					else
						m:PivotTo(finalCF)
					end
					
					local maxDim = math.max(size.X, size.Y, size.Z)
					local dist = maxDim * 1.1
					cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, dist), Vector3.new(0, 0, 0))
					
					task.spawn(function()
						local RunService = game:GetService("RunService")
						local seed = math.random(1, 10000)
						RunService.RenderStepped:Connect(function()
							if not m or not m.Parent then return end
							local t = os.clock()
							local speed = 0.8
							local amp = 0.8
							
							local dx = math.noise(t * speed, seed, 0) * amp
							local dy = math.noise(t * speed, seed, 100) * amp
							local dz = math.noise(t * speed, seed, 200) * amp
							
							local swayX = math.rad(math.sin(t * 1.5) * 5)
							local swayZ = math.rad(math.cos(t * 1.2) * 3)
							
							local offsetCF = CFrame.new(dx, dy, dz) * CFrame.Angles(swayX, 0, swayZ)
							
							if m.PrimaryPart then
								m:PivotTo(finalCF * offsetCF)
							else
								m:PivotTo(finalCF * offsetCF)
							end
						end)
					end)
				end
			end
		end
		
		table.insert(RobuxShopController.ItemFrames, {
			Frame = clone,
			Config = itemData
		})
		
		clone.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if clone:GetAttribute("Owned") then
					NotifierController:Notify("You already own this item!", Color3.fromRGB(255, 100, 100))
					return
				end
				
				if itemData.Type == "Gamepass" then
					MarketplaceService:PromptGamePassPurchase(player, itemData.Id)
				elseif itemData.Type == "Product" then
					MarketplaceService:PromptProductPurchase(player, itemData.Id)
				end
			end
		end)
	end
	
	-- Initial refresh attempt
	task.spawn(function()
		task.wait(2)
		RobuxShopController.RefreshUI()
	end)
end

function RobuxShopController.RefreshUI()
	for _, itemInfo in ipairs(RobuxShopController.ItemFrames) do
		local frame = itemInfo.Frame
		local cfg = itemInfo.Config
		local priceLabel = frame:FindFirstChild("Price")
		
		local owned = false
		
		-- Check user inventory first (fastest)
		if localData and localData.Inventory and cfg.GrantsItem then
			if localData.Inventory[cfg.GrantsItem] and localData.Inventory[cfg.GrantsItem] > 0 then
				owned = true
			end
		end
		
		-- If not found in inventory, and it's a Gamepass, we can also check MarketplaceService natively
		if not owned and cfg.Type == "Gamepass" then
			local s, res = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, cfg.Id)
			end)
			if s and res then
				owned = true
			end
		end
		
		if owned then
			frame:SetAttribute("Owned", true)
			frame.BackgroundColor3 = Color3.fromRGB(100, 100, 100) -- Make it look disabled
			if priceLabel then priceLabel.Text = "OWNED" end
		end
	end
end

return RobuxShopController
