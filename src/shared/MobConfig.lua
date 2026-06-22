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
		LeashRange = 45,
		AggroRange = 35,
		ContactRange = 5,
		DamageCooldown = 0.8,
		HipHeight = 3,
		RespawnTime = 60,
		Drops = {
			{Type = "Token", Name = "Biomass", MinAmount = 75, MaxAmount = 200, Chance = 1.0},
			{Type = "Token", Name = "FishFeed", MinAmount = 1, MaxAmount = 3, Chance = 0.5},
			{Type = "Token", Name = "Pearl", MinAmount = 1, MaxAmount = 2, Chance = 0.1},
			{Type = "Token", Name = "Green Gem", MinAmount = 1, MaxAmount = 1, Chance = 0.07},
			
			
		}
	},
}

return MobConfig
