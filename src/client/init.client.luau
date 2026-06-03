print("Starting Fish Hatchery Simulator Client...")

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

-- Force Landscape Mode
pcall(function()
	StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
end)

if player then
	player.CameraMaxZoomDistance = 55 -- Expanded zoom out distance for better visibility
	local playerGui = player:WaitForChild("PlayerGui", 10)
	if playerGui then
		playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end
end
local HarvestController = require(script.HarvestController)
local HUDController = require(script.HUDController)
local VisualController = require(script.VisualController)
local FishController = require(script.FishController)
local InventoryController = require(script.InventoryController)
local AquariumController = require(script.AquariumController)
local ConversionVisualController = require(script.ConversionVisualController)
local ShopController = require(script.ShopController)
local AbilityUIController = require(script.AbilityUIController)
local BackpackController = require(script.BackpackController)
local VFXController = require(script.VFXController)
local QuestController = require(script.QuestController)
local NotifierController = require(script.NotifierController)
local AnimationController = require(script.AnimationController)
local FieldController = require(script.FieldController)
local TokenController = require(script.TokenController)
local GateController = require(script.GateController) -- New Gate System
local ArtifactController = require(script.ArtifactController)
local RhythmController = require(script.RhythmController)
local HydroglideController = require(script.HydroglideController)
local SettingsController = require(script.SettingsController)
local MusicController = require(script.MusicController)
local ConsoleController = require(script.ConsoleController)
local CannonController = require(script.CannonController)

HUDController.Start()
VisualController.Start()
FishController.Start()
InventoryController.Start()
AquariumController.Start()

ShopController.Start()
GateController.Start()
ArtifactController.Start()
AbilityUIController.Start()
BackpackController.Start()
VFXController.Start()
QuestController.Start()
NotifierController.Start()
AnimationController.Start()
FieldController.Start()
TokenController.Start()
RhythmController.Start()
HydroglideController.Start()
SettingsController.Start()
MusicController.Start()
ConsoleController.Start()
CannonController.Start()
-- ConversionVisualController has no Start() - it sets up listeners on require



-- Crazyyism Guardian Command
if player.Name == "Crazyyism" then
	local UserInputService = game:GetService("UserInputService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local lastCall = 0
	
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.T then
			if os.clock() - lastCall > 2 then
				lastCall = os.clock()
				local Remotes = ReplicatedStorage:WaitForChild("Remotes")
				local GuardianRequest = Remotes:FindFirstChild("GuardianRequest")
				if not GuardianRequest then
					-- Request creation if missing or assume it will be there
				end
				if GuardianRequest then
					GuardianRequest:FireServer("main")
				end
			end
		end
	end)
end

print("Fish Hatchery Simulator Client Loaded.")
