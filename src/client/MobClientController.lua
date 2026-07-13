local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local MobClientController = {}

function MobClientController.Start()
	local localPlayer = Players.LocalPlayer
	task.spawn(function()
		local mobsFolder = Workspace:WaitForChild("Mobs", math.huge)

		local function onMobAdded(mob)
			if not mob:IsA("Model") then return end

			task.spawn(function()
				local owner = mob:GetAttribute("Owner")
				local timer = 0
				while not owner and timer < 5 do
					task.wait(0.1)
					timer = timer + 0.1
					owner = mob:GetAttribute("Owner")
				end

				-- Hide mobs that belong to other players
				if owner and owner ~= localPlayer.Name and owner ~= "Global" then
					mob.Parent = nil
				end
			end)
		end

		mobsFolder.ChildAdded:Connect(onMobAdded)
		for _, mob in ipairs(mobsFolder:GetChildren()) do
			onMobAdded(mob)
		end
	end)

	-- System chat messages (boss spawns, etc.)
	task.spawn(function()
		local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
		local sysChat = Remotes:WaitForChild("SystemChatEvent", 10)
		if sysChat then
			sysChat.OnClientEvent:Connect(function(message)
				local TCS = game:GetService("TextChatService")
				local rbx = TCS:FindFirstChild("TextChannels")
					and TCS.TextChannels:FindFirstChild("RBXSystem")
				if rbx then rbx:DisplaySystemMessage(message) end
			end)
		end
	end)
end

return MobClientController
