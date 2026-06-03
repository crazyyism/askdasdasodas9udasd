local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsController = {}

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateSetting = Remotes:WaitForChild("UpdateSetting")
local DataUpdateEvent = Remotes:WaitForChild("DataUpdateEvent")

local localData = nil

local function UpdateUI(settingsFrame)
	if not localData then return end
	local settings = localData.Settings or {}
	
	local scrollingFrame = settingsFrame -- The image shows SettingsFrame might be the container or have a grid
	local grid = settingsFrame:FindFirstChild("UIGridLayout")
	local template = settingsFrame:FindFirstChild("TemplateStat")
	
	if not template then return end
	template.Visible = false
	
	-- Clear old
	for _, child in ipairs(settingsFrame:GetChildren()) do
		if child ~= template and not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	
	-- Populate Settings
	local settingsList = {
		{Key = "AlgaeText", Name = "Algae Text"},
		{Key = "AbbreviateAlgae", Name = "Abbreviate Algae"},
		{Key = "TapToHold", Name = "Tap to Hold"},
		{Key = "MuteMusic", Name = "Mute Music"},
		{Key = "DisableStrobing", Name = "Disable Strobing"},
		{Key = "HideArtifacts", Name = "Hide Artifact"},
		{Key = "LowDetailMode", Name = "Low Detail Mode"},
		{Key = "HighlightFish", Name = "Highlight Fish"},
		{Key = "HideOtherFish", Name = "Hide Other Fish"},
		{Key = "DisableSFX", Name = "Disable SFX"},
	}
	
	for _, setting in ipairs(settingsList) do
		local val = settings[setting.Key]
		if val == nil then
			if setting.Key == "AlgaeText" then
				val = true
			else
				val = false
			end
		end
		
		local item = template:Clone()
		item.Name = setting.Key
		item.Visible = true
		item.Active = true
		item.Parent = settingsFrame
		
		local nameLbl = item:FindFirstChild("SettingName")
		local statusLbl = item:FindFirstChild("OnOrOff")
		
		if nameLbl then nameLbl.Text = setting.Name end
		if statusLbl then 
			statusLbl.Text = val and "ON" or "OFF"
			statusLbl.TextColor3 = val and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
		end
		
		-- Toggle Logic
		local btn = item:IsA("GuiButton") and item or item:FindFirstChildWhichIsA("GuiButton")
		if not btn then
			-- If no button, make the whole frame clickable if it's not already
			-- But usually TemplateStat is a TextButton or has one.
			-- Let's check for an ImageButton or TextButton.
		end
		
		-- Use a generic click handler on the item itself if it's a frame
		item.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local newVal = not val
				UpdateSetting:FireServer(setting.Key, newVal)
				
				if statusLbl then
					statusLbl.Text = newVal and "ON" or "OFF"
					statusLbl.TextColor3 = newVal and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
				end
			end
		end)
	end
	
end

function SettingsController.Start()
	local function Setup()
		local mainGui = PlayerGui:WaitForChild("Main", 10)
		if not mainGui then return end
		local mainFrame = mainGui:WaitForChild("Main", 10)
		if not mainFrame then return end
		
		local statsFrame = mainFrame:WaitForChild("StatisticsFrame", 10)
		if not statsFrame then return end
		
		local settingsFrame = statsFrame:WaitForChild("SettingsFrame", 10)
		if not settingsFrame then return end
		
		DataUpdateEvent.OnClientEvent:Connect(function(data)
			localData = data
			UpdateUI(settingsFrame)
		end)
		
		-- Initial update if data available
		if localData then
			UpdateUI(settingsFrame)
		end
	end
	
	task.spawn(Setup)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		Setup()
	end)
end

return SettingsController
