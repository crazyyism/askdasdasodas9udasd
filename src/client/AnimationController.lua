local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AnimationController = {}

local TOOL_ANIMS = {
	["Poseidon"] = {
		Walk = "rbxassetid://86136328279399", 
		Idle = "rbxassetid://114736736181628"
	},
	["Rainmaker"] = {
		-- Placeholder IDs - User should replace these
		Walk = "rbxassetid://98782603691033", 
		Idle = "rbxassetid://91448879172185"
	},
	["SharkScythe"] = {
		Walk = "rbxassetid://72306696588438", -- Placeholder
		Idle = "rbxassetid://123756384047722", -- Placeholder
		Harvest = "rbxassetid://133526167661932" -- Placeholder (Custom Key)
	},
	["Sunkissed Art"] = {
		Walk = "rbxassetid://103782561694242",
		Idle = "rbxassetid://82032778681674"
	}
}

-- Customize your default player animations here!
-- Leave as "" or "rbxassetid://0" to use the standard Roblox animations.
local DEFAULT_PLAYER_ANIMS = {
	Walk = "rbxassetid://0",
	Idle = "rbxassetid://116536081429516"
}

local DEFAULT_TOOL_ID = "rbxassetid://507768375" -- Standard Right Arm Up

local currentOverride = nil
local overrideConn = nil
local originalAnimsMap = {} -- Store per-character originals to restore

local function stopOverride()
	if overrideConn then
		overrideConn:Disconnect()
		overrideConn = nil
	end
	
	if currentOverride then
		if currentOverride.WalkTrack then currentOverride.WalkTrack:Stop(0.2) end
		if currentOverride.IdleTrack then currentOverride.IdleTrack:Stop(0.2) end
		currentOverride = nil
	end
end

local isSuspended = false



local function updateOverride()
	if isSuspended or not currentOverride then return end
	local char = currentOverride.Character
	if not char or not char.Parent then stopOverride(); return end
	
	local hum = char:FindFirstChild("Humanoid")
	if not hum then return end
	
	local state = hum:GetState()
	local isAirborne = (state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall)
	local move = hum.MoveDirection.Magnitude > 0.05 -- More sensitive
	
	if isAirborne then
		if currentOverride.WalkTrack and currentOverride.WalkTrack.IsPlaying then
			currentOverride.WalkTrack:Stop(0.2)
		end
		if currentOverride.IdleTrack and currentOverride.IdleTrack.IsPlaying then
			currentOverride.IdleTrack:Stop(0.2)
		end
	elseif move then
		-- Play Walk
		if currentOverride.IdleTrack and currentOverride.IdleTrack.IsPlaying then
			currentOverride.IdleTrack:Stop(0.2)
		end
		
		local scale = hum.WalkSpeed / 21
		if currentOverride.WalkTrack then
			if not currentOverride.WalkTrack.IsPlaying then
				currentOverride.WalkTrack:Play(0.2)
			end
			currentOverride.WalkTrack:AdjustSpeed(scale)
		end
	else
		-- Play Idle
		if currentOverride.WalkTrack and currentOverride.WalkTrack.IsPlaying then
			currentOverride.WalkTrack:Stop(0.2)
		end
		if currentOverride.IdleTrack and not currentOverride.IdleTrack.IsPlaying then
			currentOverride.IdleTrack:Play(0.2)
		end
	end
	
	-- Suppress Animate script tracks (Extensive list for R6/R15/Custom)
	local suppressNames = {
		"WalkAnim", "RunAnim", "Animation1", "Animation2", "ToolNoneAnim",
		"walk", "run", "idle", "Run", "Walk", "Idle", "toolidle", "toolnone"
	}
	
	for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do
		local isCustom = (tr == currentOverride.WalkTrack or tr == currentOverride.IdleTrack)
		if not isCustom then
			for _, name in ipairs(suppressNames) do
				if tr.Name:lower() == name:lower() then
					tr:Stop(0.1)
					break
				end
			end
		end
	end
end

local function applyAnimation(char, toolName)
	if isSuspended then return end
	
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 3)
		if not hum then return end
		local animator = hum:WaitForChild("Animator", 3)
		if not animator then return end
		
		-- Check if the tool is still equipped (if a toolName was provided)
		if toolName and not char:FindFirstChild(toolName) then return end

		local config = toolName and TOOL_ANIMS[toolName]
	
	if config then
		-- ENABLE OVERRIDE
		stopOverride() -- Clear previous
		
		-- 2. Load Custom
		local walkAnim = Instance.new("Animation")
		walkAnim.AnimationId = config.Walk
		local walkTrack = animator:LoadAnimation(walkAnim)
		walkTrack.Priority = Enum.AnimationPriority.Action3 -- Action3 to ensure it wins
		walkTrack.Looped = true
		
		local idleAnim = Instance.new("Animation")
		idleAnim.AnimationId = config.Idle
		local idleTrack = animator:LoadAnimation(idleAnim)
		idleTrack.Priority = Enum.AnimationPriority.Action3
		idleTrack.Looped = true
		
		currentOverride = {
			Character = char,
			WalkTrack = walkTrack,
			IdleTrack = idleTrack
		}
		
		overrideConn = RunService.Heartbeat:Connect(updateOverride)
		
	else
		-- DISABLE OVERRIDE (RESTORE)
		stopOverride()
	end
	
	-- Force Stop standard tracks ONLY if we have a custom config to replace them with
	if config then
		local suppressNames = {"walk", "run", "idle", "WalkAnim", "RunAnim", "ToolNoneAnim", "toolidle", "toolnone"}
		for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do
			local isCustom = currentOverride and (tr == currentOverride.WalkTrack or tr == currentOverride.IdleTrack)
			if not isCustom then
				for _, name in ipairs(suppressNames) do
					if tr.Name:lower() == name:lower() then
						tr:Stop(0.1)
						break
					end
				end
			end
		end
	end
	end)
end

function AnimationController.SetSuspended(suspended)
	isSuspended = suspended
	if suspended then
		stopOverride()
	else
		-- Re-evaluate initial tool if needed
		local player = Players.LocalPlayer
		local char = player.Character
		if char then
			local tool = char:FindFirstChildWhichIsA("Tool")
			if tool then applyAnimation(char, tool.Name) end
		end
	end
end

function AnimationController.Start()
	local player = Players.LocalPlayer
	
	local function onCharAdded(char)
		originalAnimsMap = {} -- Reset store

		-- Inject Default Anims into Animate script
		task.spawn(function()
			local animate = char:WaitForChild("Animate", 5)
			if animate then
				local needsRefresh = false
				
				if DEFAULT_PLAYER_ANIMS.Walk ~= "" and DEFAULT_PLAYER_ANIMS.Walk ~= "rbxassetid://0" then
					local walk = animate:FindFirstChild("walk")
					if walk and walk:FindFirstChild("WalkAnim") then walk.WalkAnim.AnimationId = DEFAULT_PLAYER_ANIMS.Walk end
					local run = animate:FindFirstChild("run")
					if run and run:FindFirstChild("RunAnim") then run.RunAnim.AnimationId = DEFAULT_PLAYER_ANIMS.Walk end
					needsRefresh = true
				end
				
				if DEFAULT_PLAYER_ANIMS.Idle ~= "" and DEFAULT_PLAYER_ANIMS.Idle ~= "rbxassetid://0" then
					local idle = animate:FindFirstChild("idle")
					if idle and idle:FindFirstChild("Animation1") then idle.Animation1.AnimationId = DEFAULT_PLAYER_ANIMS.Idle end
					if idle and idle:FindFirstChild("Animation2") then idle.Animation2.AnimationId = DEFAULT_PLAYER_ANIMS.Idle end
					needsRefresh = true
				end
				
				if needsRefresh then
					-- Refresh Animate script
					animate.Disabled = true
					task.wait()
					animate.Disabled = false
				end
			end
		end)

		-- Watch for tool equip
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				applyAnimation(char, child.Name)
			end
		end)
		
		-- Watch for tool unequip
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				applyAnimation(char, nil)
			end
		end)
		
		-- Check Initial
		local initTool = char:FindFirstChildWhichIsA("Tool")
		if initTool then
			applyAnimation(char, initTool.Name)
		else
			applyAnimation(char, nil)
		end
	end
	
	player.CharacterAdded:Connect(onCharAdded)
	if player.Character then onCharAdded(player.Character) end
end

return AnimationController
