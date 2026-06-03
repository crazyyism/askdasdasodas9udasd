---
description: How to add a new Fish Species to the game
---

1. Open `src/shared/FishConfig.lua`.
2. Add a new entry to the `FishConfig.Fish` table.
   ```lua
   ["fish_id"] = {
       Name = "Fish Name",
       Rarity = "Common", -- Common, Rare, Epic, Legendary, Mythic
       Description = "Flavor text.",
       BaseStats = {
           GatherAmount = 1,
           GatherSpeed = 1.0,
           MoveSpeed = 12,
       },
       Abilities = { "AbilityName" },
       Tokens = { "TokenName" },
   },
   ```
3. Create a model for the fish:
   - Create a MeshPart or Part in Roblox Studio.
   - Name it exactly as the `fish_id`.
   - Place it in `ReplicatedStorage.Assets.FishModels`.
4. (Optional) Define new Ability logic in `src/server/AbilityService.lua` (if it's a new ability).
