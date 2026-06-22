local MusicConfig = {
	--// Default music when NOT in a MusicZone part
	["Default"] = "rbxassetid://120154548262870", -- Change this to your main background music
	
	["ToTheMoon"] = "rbxassetid://17681260753",
	ToTheMoonStartTime = 70, -- Adjust this to set where the To The Moon music starts (in seconds)
	ToTheMoonBeatThreshold = 0.96, -- Beat detection threshold (from 0.0 to 1.0)
	
	--// You can also add specific fallback areas here if you want
	-- ["Freshwater Reef"] = "rbxassetid://1840638510",
	
	--// Configuration
	FadeTime = 2,
	MaxVolume = 0.6,
}

return MusicConfig
