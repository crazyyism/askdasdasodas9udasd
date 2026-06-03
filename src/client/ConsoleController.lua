local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ConsoleController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Constants for consistent mapping
local BIND_HARVEST = "ConsoleHarvest"
local BIND_ABILITY = "ConsoleAbility"
local BIND_INVENTORY = "ConsoleInventory"
local BIND_QUESTS = "ConsoleQuests"
local BIND_SHOP = "ConsoleShop"

function ConsoleController.Start()
	-- Detect Gamepad
	UserInputService.GamepadConnected:Connect(function(gamepadNum)
		print("Gamepad connected:", gamepadNum)
	end)

	-- 1. Harvesting (R2 / RT and ButtonX)
	local HarvestController = require(script.Parent.HarvestController)
	
	local function handleHarvestInput(actionName, inputState, inputObject)
		HarvestController.onInput("ConsoleInput", inputState, inputObject)
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindAction(BIND_HARVEST, handleHarvestInput, false, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonX)

	-- 2. Ability (R1 / RB)
	local function handleAbilityInput(actionName, inputState, inputObject)
		if inputState == Enum.UserInputState.Begin then
			HarvestController.attemptRainmakerAbility()
		end
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindAction(BIND_ABILITY, handleAbilityInput, false, Enum.KeyCode.ButtonR1)

	-- 3. UI Navigation & Toggles
	local HUDController = require(script.Parent.HUDController)
	
	local function toggleUI(actionName, inputState, inputObject)
		if inputState ~= Enum.UserInputState.Begin then return end
		
		local mainGui = playerGui:FindFirstChild("Main")
		local mainFrame = mainGui and mainGui:FindFirstChild("Main")
		if not mainFrame then return end

		if inputObject.KeyCode == Enum.KeyCode.ButtonY or inputObject.KeyCode == Enum.KeyCode.DPadUp then
			-- Toggle Inventory
			local invFrame = mainFrame:FindFirstChild("InventoryFrame")
			if invFrame then HUDController.ToggleFrame("Inventory", invFrame) end
		elseif inputObject.KeyCode == Enum.KeyCode.DPadLeft then
			-- Toggle Quests
			local questFrame = mainFrame:FindFirstChild("QuestFrame")
			if questFrame then HUDController.ToggleFrame("Quest", questFrame) end
		elseif inputObject.KeyCode == Enum.KeyCode.DPadRight then
			-- Toggle Shop (Closest or default)
			-- Shop usually requires proximity, but we could toggle the UI if near
			-- For now, let's keep it to Inventory/Quests/Stats
			local statsFrame = mainFrame:FindFirstChild("StatisticsFrame")
			if statsFrame then HUDController.ToggleFrame("Statistics", statsFrame) end
		elseif inputObject.KeyCode == Enum.KeyCode.ButtonB then
			-- Close Active Frame
			if HUDController.ActiveFrame then
				local frameName = HUDController.ActiveFrame .. "Frame"
				local frame = mainFrame:FindFirstChild(frameName)
				if frame then HUDController.ToggleFrame(HUDController.ActiveFrame, frame) end
			end
		end
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindAction("ConsoleUIToggle", toggleUI, false, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)

    -- 4. Virtual Cursor Toggle (ButtonSelect / L3/R3)
    -- Virtual Cursor is useful for Drag and Drop in Inventory
    local virtualCursorEnabled = false
    UserInputService.InputBegan:Connect(function(input, gpe)
        if input.KeyCode == Enum.KeyCode.ButtonSelect or input.KeyCode == Enum.KeyCode.ButtonL3 then
             virtualCursorEnabled = not virtualCursorEnabled
             -- Roblox doesn't expose a simple toggle for the internal virtual cursor easily without CoreScripts,
             -- but we can enable/disable GuiNavigation or simulate a cursor.
             -- Standard Roblox approach for custom games is to use GuiService properties.
             GuiService.GuiNavigationEnabled = not virtualCursorEnabled
        end
    end)
end

return ConsoleController
