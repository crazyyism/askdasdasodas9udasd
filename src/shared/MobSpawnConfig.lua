local MobSpawnConfig = {}

MobSpawnConfig.Reefs = {
	["Freshwater Reef"] = {
		{
			SpawnPartName = "FrogSpawn",
			Level = 1,
			-- RespawnTime = 3 -- Optional override (falls back to MobConfig default if nil)
		}
	},
	["Trash Reef"] = {
		{
			SpawnPartName = "spawnfrog",
			Level = 2,
			RespawnTime = 120,
			SpawnAtPart = true
		},
		{
			SpawnPartName = "FrogSpawn",
			Level = 2,
			RespawnTime = 120,
			SpawnAtPart = true
		}
	},
	["Obsidian Reef"] = {
		{
			SpawnPartName = "SpawnLM",
			Template = "LavaMonster",
			Level = 5,
			RespawnTime = 300,
			SpawnAtPart = true
		}
	},
	["Axolotl Reef"] = {
		{
			SpawnPartName = "AxolotlSpawn",
			Template = "Axolotl",
			Level = 5,
			RespawnTime = 300,
			SpawnAtPart = true
		}
	}
}

return MobSpawnConfig
