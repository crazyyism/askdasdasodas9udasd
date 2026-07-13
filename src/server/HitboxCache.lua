local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PartCache = require(ReplicatedStorage:WaitForChild("PartCache"):WaitForChild("PartCache"))

local HitboxCache = {}

local template = Instance.new("Part")
template.Anchored = true
template.CanCollide = false
template.CanQuery = true
template.CanTouch = false
template.Transparency = 1
template.Material = Enum.Material.SmoothPlastic
template.Name = "HitboxTemplate"
template.Size = Vector3.new(1, 1, 1)

-- Pre-allocate 100 hitboxes
HitboxCache.Provider = PartCache.new(template, 100)
-- Hide inactive hitboxes far away in workspace so they can still be used for spatial queries
HitboxCache.Provider:SetCacheParent(workspace)

function HitboxCache.GetHitbox(size, name)
	local part = HitboxCache.Provider:GetPart()
	if size then part.Size = size end
	if name then part.Name = name end
	return part
end

function HitboxCache.ReturnHitbox(part)
	if not part then return end
	part.Name = "HitboxTemplate"
	HitboxCache.Provider:ReturnPart(part)
end

return HitboxCache
