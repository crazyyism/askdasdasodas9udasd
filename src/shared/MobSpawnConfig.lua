local MobSpawnConfig = {}

MobSpawnConfig.Reefs = {
	["Freshwater Reef"] = {
		{
			Template = "Jellyfish", -- You can change this to any Mob template inside ReplicatedStorage
			Health = 20,
			Level = 1,
			SpawnPartName = "MobSpawn",
			RespawnTime = 5, -- Seconds to wait before respawning
			Drops = {
				{Type = "Token", Name = "Biomass", Amount = 5, Chance = 1.0},
				{Type = "Token", Name = "FishFeed", Amount = 1, Chance = 1.0}
			}
		}
	}
}

return MobSpawnConfig
