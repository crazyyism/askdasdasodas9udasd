local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NotifierController = {}

local container = nil
local template = nil
local isSetup = false

-- Constants
local NOTIFICATION_DURATION = 5
local MAX_NOTIFICATIONS = 5
local STACK_PADDING = 5

local function SetupUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then return end
	
	local mainGui = playerGui:WaitForChild("Main", 10)
	if not mainGui then return end
	
	-- 1. Find Template
	-- We look for a frame named "Notifier" inside Main or its children
	local existingNotifier = mainGui:FindFirstChild("Notifier", true) 
	
	if existingNotifier then
		template = existingNotifier:Clone()
		template.Visible = false
		template.Parent = nil -- Keep in memory
		existingNotifier.Visible = false -- Hide original if it was visible
	else
		warn("NotifierController: Could not find 'Notifier' UI template in Main GUI.")
		return
	end
	
	-- 2. Create Container (Top Left/Center stack)
	-- Check if we already made one (in case of respawn loop)
	container = mainGui:FindFirstChild("NotificationContainer")
	if not container then
		container = Instance.new("Frame")
		container.Name = "NotificationContainer"
		container.Parent = mainGui
		-- Position Bottom-Right, with some padding
		container.Position = UDim2.new(.9, 0, .8, 0) 
		container.AnchorPoint = Vector2.new(.5,.5) -- Anchor bottom right
		container.Size = UDim2.new(.6, 0, .6, 0)
		container.BackgroundTransparency = 1
		container.BorderSizePixel = 0
		
		local layout = Instance.new("UIListLayout")
		layout.Parent = container
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, STACK_PADDING)
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom -- Stack UP from bottom
	end
	
	isSetup = true
end

function NotifierController.Start()
	task.spawn(SetupUI)
	
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		SetupUI()
	end)
	
	-- Connect Server Remote
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")
	local NotificationEvent = Remotes:FindFirstChild("NotificationEvent")
	if not NotificationEvent then
		NotificationEvent = Instance.new("RemoteEvent")
		NotificationEvent.Name = "NotificationEvent"
		NotificationEvent.Parent = Remotes
	end
	
	NotificationEvent.OnClientEvent:Connect(function(text, color)
		NotifierController:Notify(text, color)
	end)
end

local activeNotifications = {}

function NotifierController:Notify(text, color)
	if not isSetup or not container or not template then 
		-- Try setup again if missing
		SetupUI()
		if not isSetup then return end
	end
	
	-- Parsing +X Item format to detect stackable elements
	local countStr, itemName = string.match(text, "^%+([%d%.,]+)%s+(.+)$")
	local newCount = nil
	if countStr then
		newCount = tonumber((string.gsub(countStr, ",", "")))
	end
	
	if newCount and itemName and activeNotifications[itemName] and activeNotifications[itemName].Notif and activeNotifications[itemName].Notif.Parent then
		local stack = activeNotifications[itemName]
		stack.Count = stack.Count + newCount
		
		local formatted = tostring(stack.Count):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		stack.Label.Text = "+" .. formatted .. " " .. itemName
		
		local tweenInfoPop = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(stack.Notif, tweenInfoPop, {Size = stack.OrigSize + UDim2.new(0, 0, 0, 15)}):Play()
		task.delay(0.15, function()
			if stack.Notif and stack.Notif.Parent then
				TweenService:Create(stack.Notif, tweenInfoPop, {Size = stack.OrigSize}):Play()
			end
		end)
		
		stack.UpdateId = stack.UpdateId + 1
		local currentId = stack.UpdateId
		
		task.delay(NOTIFICATION_DURATION, function()
			if stack.UpdateId == currentId then
				local tweenInfoOut = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				if stack.TextFrame then TweenService:Create(stack.TextFrame, tweenInfoOut, {BackgroundTransparency = 1}):Play() end
				if stack.Label then TweenService:Create(stack.Label, tweenInfoOut, {TextTransparency = 1}):Play() end
				if stack.Notif then TweenService:Create(stack.Notif, tweenInfoOut, {Size = UDim2.new(stack.OrigSize.X.Scale, stack.OrigSize.X.Offset, 0, 0)}):Play() end
				task.wait(1.0)
				if stack.Notif then stack.Notif:Destroy() end
				if activeNotifications[itemName] == stack then activeNotifications[itemName] = nil end
			end
		end)
		
		return
	end
	
	-- Clone Template for new or non-stackable notification
	local notif = template:Clone()
	notif.Visible = true
	
	-- Populate Text
	local textFrame = notif:FindFirstChild("NotifierTextFrame")
	local label = textFrame and textFrame:FindFirstChild("NotifierText") or notif:FindFirstChild("NotifierText")
	
	if label and label:IsA("TextLabel") then
		label.Text = text
		if color then label.TextColor3 = color end
	end
	
	notif.Parent = container
	
	-- Capture Original Transparency from template
	local originalNotifTrans = template.BackgroundTransparency
	local templateTextFrame = template:FindFirstChild("NotifierTextFrame")
	local originalBgTrans = templateTextFrame and templateTextFrame.BackgroundTransparency or 0
	
	-- Animation: Pop In
	local originalSize = notif.Size
	notif.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)
	notif.BackgroundTransparency = 1
	if textFrame then textFrame.BackgroundTransparency = 1 end
	if label then label.TextTransparency = 1 end
	
	local tweenInfoIn = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	
	TweenService:Create(notif, tweenInfoIn, {Size = originalSize, BackgroundTransparency = originalNotifTrans}):Play()
	
	if textFrame then 
		TweenService:Create(textFrame, tweenInfoIn, {BackgroundTransparency = originalBgTrans}):Play()
	end
	if label then
		TweenService:Create(label, tweenInfoIn, {TextTransparency = 0}):Play()
	end
	
	local stackRef = nil
	if newCount and itemName then
		stackRef = {
			Notif = notif,
			Label = label,
			TextFrame = textFrame,
			Count = newCount,
			UpdateId = 1,
			OrigSize = originalSize
		}
		activeNotifications[itemName] = stackRef
	end
	
	local currentId = stackRef and stackRef.UpdateId or 1
	task.delay(NOTIFICATION_DURATION, function()
		if stackRef and stackRef.UpdateId ~= currentId then return end
		if not notif or not notif.Parent then return end
		
		-- Fade Out
		local tweenInfoOut = TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		
		if textFrame then
			TweenService:Create(textFrame, tweenInfoOut, {BackgroundTransparency = 1}):Play()
		end
		if label then
			TweenService:Create(label, tweenInfoOut, {TextTransparency = 1}):Play()
		end
		
		TweenService:Create(notif, tweenInfoOut, {Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)}):Play()
		
		task.wait(1.0)
		if notif then notif:Destroy() end
		if stackRef and activeNotifications[itemName] == stackRef then activeNotifications[itemName] = nil end
	end)
end

return NotifierController
