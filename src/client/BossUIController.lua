local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local MobConfig = require(ReplicatedStorage.Shared.MobConfig)
local HotSpotController = require(script.Parent.HotSpotController)

local BossUIController = {}

local localPlayer = Players.LocalPlayer
local gui = nil
local canvasGroup = nil
local fillFrame = nil
local nameText = nil
local hpText = nil
local currentBoss = nil

local FADE_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local isVisible = false

local function FindUI()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	gui = playerGui:WaitForChild("BossHealthGui")
	canvasGroup = gui:WaitForChild("BossContainer")
	canvasGroup.GroupTransparency = 1 -- Hidden by default
	
	nameText = canvasGroup:WaitForChild("BossName")
	local bgFrame = canvasGroup:WaitForChild("Background")
	fillFrame = bgFrame:WaitForChild("Fill")
	hpText = bgFrame:WaitForChild("HPText")
end

local function formatNumber(n)
	local formatted = tostring(math.floor(n))
	local k
	while true do  
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if (k==0) then
			break
		end
	end
	return formatted
end

local function UpdateUI(mob, cfg)
	local healthVal = mob:FindFirstChild("Health")
	local maxHealthVal = mob:FindFirstChild("MaxHealth")
	
	if healthVal and maxHealthVal then
		local hp = healthVal.Value
		local maxHp = maxHealthVal.Value
		local ratio = math.clamp(hp / maxHp, 0, 1)
		
		hpText.Text = formatNumber(hp) .. " / " .. formatNumber(maxHp) .. " HP"
		TweenService:Create(fillFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(ratio, 0, 1, 0)}):Play()
	end
	nameText.Text = cfg.Name or mob.Name
end

local function ShowBoss(mob, cfg)
	if not gui then FindUI() end
	currentBoss = mob
	
	if cfg.BossMusicId then
		localPlayer:SetAttribute("BossMusicOverride", cfg.BossMusicId)
	end
	
	if not isVisible then
		isVisible = true
		canvasGroup.Visible = true
		UpdateUI(mob, cfg)
		TweenService:Create(canvasGroup, FADE_TWEEN_INFO, {GroupTransparency = 0}):Play()
	end
	
	if cfg.Name == "Lava Monster" or mob:GetAttribute("MobType") == "LavaMonster" then
		HotSpotController.Activate(mob)
	else
		HotSpotController.Deactivate()
	end
end

local function HideBoss()
	currentBoss = nil
	localPlayer:SetAttribute("BossMusicOverride", nil)
	if isVisible then
		isVisible = false
		HotSpotController.Deactivate()
		if canvasGroup then
			local tween = TweenService:Create(canvasGroup, FADE_TWEEN_INFO, {GroupTransparency = 1})
			tween:Play()
			tween.Completed:Connect(function()
				if not isVisible then
					canvasGroup.Visible = false
				end
			end)
		end
	end
end

function BossUIController.Start()
	-- Give UI time to clone into PlayerGui before trying to find it
	task.spawn(function()
		FindUI()
		
		RunService.Heartbeat:Connect(function()
			local char = localPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp then return end
			
			local closestBoss = nil
			local closestDist = 120 -- Radius threshold
			
			local mobsFolder = Workspace:FindFirstChild("Mobs")
			if mobsFolder then
				for _, mob in ipairs(mobsFolder:GetChildren()) do
					local owner = mob:GetAttribute("Owner")
					local mobType = mob:GetAttribute("MobType")
					
					if (owner == localPlayer.Name or owner == "Global") and mobType then
						local cfg = MobConfig.MobTypes[mobType]
						if cfg and cfg.HasBossBar then
							local mobHrp = mob:FindFirstChild("HumanoidRootPart") or mob.PrimaryPart
							local healthVal = mob:FindFirstChild("Health")
							
							if mobHrp and healthVal and healthVal.Value > 0 then
								local dist = (hrp.Position - mobHrp.Position).Magnitude
								if dist <= closestDist then
									closestDist = dist
									closestBoss = {Mob = mob, Config = cfg}
								end
							end
						end
					end
				end
			end
			
			if closestBoss then
				ShowBoss(closestBoss.Mob, closestBoss.Config)
				if isVisible then
					UpdateUI(closestBoss.Mob, closestBoss.Config)
				end
			else
				HideBoss()
			end
		end)
	end)
end

return BossUIController
