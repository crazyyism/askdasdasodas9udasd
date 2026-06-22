local Players = game:GetService("Players")

-- CONFIGURATION
local IS_WHITELIST_ENABLED = false -- Set to false to allow everyone to join
local ALLOWED_USERNAMES = {
	"Crazyyism",
	"DevilDiver232",
	"superh1pp00",
	"Antwar_master",
	"Hgausgsjsbn",
	"doriisbored",
	"mew1707",
	"EddoIsToGood4U",
	"Jayden_Swordmaster2",
	"PlushCharlie",
	"OOFp9",
	"calixxsalt",
	"BroUNeed2GetGood",
	"FlamingFoxykiller",
	"yogohurted",
	"Fatborricky",
	"Madoromiyumee",
	"kryspin700",
	"Tacocat_128",
	"cryptocomboss",
	"gigiaka_gojo",
	"Dylanve14",
	"teenytiny4567",
	"Mr1_Frog",
	"LegandarySam09",
	"djyanie",
	"2Hydrogen",
	"Divided_vn",
	"hexamber1",
	"HelloPoopy60000",
	"toxikguytr54261",
	"Skep_haIo",
	"Erayege42",
	"cryptobossvxz",
	"janshoy",
	"kekrnickle_kvn",
	"fdrpoop",
	"Bienmiu",
	"frontlinegirls",
	"random_corr",
	"Aaaronip",
	"Astracle_s",
	"EllabellTheLolGirl",
	"RVCabra",
	"oserus",
	"Mearscape3",
	"lolpleplays",
	"GamerYT1220",
	"PotitoDuritoKawaii",
	


}

local KICK_MESSAGE = "This game is currently in private maintenance. Please try again later!"

local function OnPlayerAdded(player: Player)
	if not IS_WHITELIST_ENABLED then return end
	
	local isAllowed = false
	for _, username in ipairs(ALLOWED_USERNAMES) do
		if player.Name == username then
			isAllowed = true
			break
		end
	end
	
	if not isAllowed then
		player:Kick(KICK_MESSAGE)
		warn("[Whitelist] Kicked unauthorized player: " .. player.Name)
	else
		print("[Whitelist] Allowed whitelisted player: " .. player.Name)
	end
end

-- Connect to PlayerAdded
Players.PlayerAdded:Connect(OnPlayerAdded)

-- Check any players already in the server (useful for studio testing or hot-reloading)
for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end

return nil
