-- list collidable parts intersecting a region (edit numbers as needed)
local RX0, RX1, RZ0, RZ1 = 33, 40, -66, -57
for _, p in ipairs(inRoot) do
	local x0, x1, y0, y1, z0, z1 = aabb(p)
	if p.CanCollide and y0 < 5.5 and y1 > 1.3 and x1 > RX0 and x0 < RX1 and z1 > RZ0 and z0 < RZ1 then
		print(string.format("DBG %-22s x[%.1f,%.1f] y[%.1f,%.1f] z[%.1f,%.1f]", p.Name, x0, x1, y0, y1, z0, z1))
	end
end
