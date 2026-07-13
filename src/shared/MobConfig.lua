local MobConfig = {}

--[[
	MobConfig parameter documentation:
	- Name: The display name of the mob.
	- Level: The default level of the mob.
	- Health: The base health of the mob.
	- Damage: The damage dealt by the mob on contact.
	- WalkSpeed: The speed of the mob when wandering (Idle state).
	- ChaseSpeed: The speed of the mob when pursuing a player.
	- ReturnSpeed: The speed of the mob when returning to its spawn point.
	- WanderRadius: How far (in studs) the mob can wander from its spawn point.
	- LeashRange: How far (in studs) the mob can chase a player from its spawn point before losing aggro.
	- AggroRange: How close (in studs) a player must be to the mob to trigger the chase.
	- ContactRange: The maximum distance (in studs) to deal contact damage.
	- DamageCooldown: The cooldown time (in seconds) between contact damage hits.
	- HopInterval: (Optional) If set, the mob will jump every X seconds to simulate hopping.
	- RespawnTime: The default time (in seconds) to wait before respawning this mob when killed.
	- Drops: A list of drop definitions:
		- Type: Type of drop (e.g. "Token").
		- Name: Name of the drop item (e.g. "Biomass", "FishFeed", "Pearl").
		- MinAmount: The minimum amount of the item to drop.
		- MaxAmount: The maximum amount of the item to drop.
		- Chance: The chance (0.0 to 1.0) of this drop triggering.
]]

MobConfig.MobTypes = {
	["Frog"] = {
		Name = "Frog",
		Level = 1,
		Health = 50,
		Damage = 10,
		WalkSpeed = 10,
		ChaseSpeed = 14,
		ReturnSpeed = 12,
		WanderRadius = 15,
		LeashRange = 70,
		AggroRange = 70,
		ContactRange = 5,
		DamageCooldown = 0.8,
		HipHeight = 3,
		RespawnTime = 60,
	},
	["King Frog"] = {
		Name = "King Frog",
		ModelName = "King Frog",
		Level = 5,
		Health = 15000,
		Damage = 25,
		WalkSpeed = 12,
		ChaseSpeed = 12,
		ReturnSpeed = 14,
		WanderRadius = 50,
		LeashRange = 100,
		AggroRange = 0,
		ContactRange = 8,
		DamageCooldown = 1.0,
		HipHeight = 8,
		RespawnTime = 120,
		HasBossBar = true,
		IsGlobal = false,
	},
	["LavaMonster"] = {
		Name = "Lava Monster",
		Level = 10,
		Health = 200000,
		Damage = 25,
		WalkSpeed = 22,
		ChaseSpeed = 22,
		ReturnSpeed = 22,
		WanderRadius = 25,
		LeashRange = 100,
		AggroRange = 70,
		ContactRange = 15,
		DamageCooldown = 1.0,
		AttackCooldown = 1.5,
		AoERange = 25,
		DashCooldown = 1.0,
		DashDamage = 25,
		DashDuration = 0.2,
		DashKnockback = 1500,
		DashEmitAmount = 20,
		FireballSpeed = 40,
		FireballDelay = 0.6,
		FireballDuration = 6.0,
		FireballTickDamage = 10,
		FireballTickRadius = 12,
		FireballExplosionDamage = 25,
		FireballExplosionRadius = 20,
		FireballExplosionEmit = 30,
		GeyserCooldown = 25.0,
		GeyserDamage = 10,
		GeyserRadius = 4.5,
		GeyserDuration = 5.0,
		GeyserSpawnDuration = 10.0,
		GeyserSpawnRate = 3,
		GeyserSpawnRadius = 50,
		PreDashEmit = 20,
		Scale = 2.0,          
		HipHeight = 4.4,
		RespawnTime = 300,
		HasBossBar = true,
		BossMusicId = "rbxassetid://18953994906", -- Epic boss music placeholder
		BossMusicVolume = 1,
		IsGlobal = true,
	},
}

MobConfig.MobTypes["LM"] = MobConfig.MobTypes["LavaMonster"]

MobConfig.MobTypes["Axolotl"] = {
	Name = "Axolotl",
	Level = 5,
	Health = 500,
	Damage = 0, -- Damage is handled by the custom attacks, not contact
	WalkSpeed = 0, -- Stationary
	ChaseSpeed = 0, -- Stationary
	ReturnSpeed = 0, -- Stationary
	WanderRadius = 0,
	LeashRange = 100,
	AggroRange = 70,
	ContactRange = 50,
	DamageCooldown = 1.0,
	AttackCooldown = 6.0,
	Attack1Damage = 30,
	Attack1Radius = 20,
	Attack2Damage = 30,
	Attack2Radius = 20,
	Scale = 1.0,
	HipHeight = 1.5,
	RespawnTime = 30,
}

MobConfig.MobTypes["Skeleton"] = {
	Name = "Skeleton",
	Level = 3,
	Health = 250,
	Damage = 15,
	WalkSpeed = 12,
	ChaseSpeed = 18,
	ReturnSpeed = 14,
	WanderRadius = 10,
	LeashRange = 70,
	AggroRange = 50,
	ContactRange = 6,
	DamageCooldown = 1.5,
	HipHeight = 3,
	RespawnTime = 60,
	Drops = {
		{Type = "Token", Name = "Skull", MinAmount = 1, MaxAmount = 4, Chance = 0.1}
	},
}






return MobConfig
