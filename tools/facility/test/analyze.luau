-- headless sanity checks over the mock scene: size sanity + walkability flood fill
local parts = MOCK_ALL_PARTS()
local inRoot = {}
for _, p in ipairs(parts) do
	if p.Parent and p:IsDescendantOf(root) then inRoot[#inRoot + 1] = p end
end

local function aabb(p)
	local cf, s = p.CFrame, p.Size
	local r = cf.r
	local hx = (math.abs(r[1][1]) * s.X + math.abs(r[1][2]) * s.Y + math.abs(r[1][3]) * s.Z) / 2
	local hy = (math.abs(r[2][1]) * s.X + math.abs(r[2][2]) * s.Y + math.abs(r[2][3]) * s.Z) / 2
	local hz = (math.abs(r[3][1]) * s.X + math.abs(r[3][2]) * s.Y + math.abs(r[3][3]) * s.Z) / 2
	local c = cf.p
	return c.X - hx, c.X + hx, c.Y - hy, c.Y + hy, c.Z - hz, c.Z + hz
end

local bad, counts = 0, {}
for _, p in ipairs(inRoot) do
	local s = p.Size
	if s.X <= 0 or s.Y <= 0 or s.Z <= 0 or s.X ~= s.X then
		bad += 1
		if bad < 15 then print("BAD SIZE", p:GetFullName(), s.X, s.Y, s.Z) end
	end
	local top = p
	while top.Parent and top.Parent ~= root do top = top.Parent end
	counts[top.Name] = (counts[top.Name] or 0) + 1
end
print("PARTS", #inRoot, "bad", bad)
for k, v in pairs(counts) do print("COUNT", k, v) end

-- grid
local X0, X1, Z0, Z1 = -62, 62, -170, 52
local W, H = X1 - X0, Z1 - Z0
local floorG, blockG = {}, {}
for i = 1, W * H do floorG[i] = false blockG[i] = false end
local function idx(ix, iz) return (iz - Z0) * W + (ix - X0) + 1 end -- ix,iz = integer cell (cell centre +0.5)
local PR = 0.95 -- player radius inflation
for _, p in ipairs(inRoot) do
	local x0, x1, y0, y1, z0, z1 = aabb(p)
	if p.Name == "Floor" or p.Name == "Walkway" then
		for ix = math.max(X0, math.floor(x0)), math.min(X1 - 1, math.ceil(x1) - 1) do
			for iz = math.max(Z0, math.floor(z0)), math.min(Z1 - 1, math.ceil(z1) - 1) do
				if p.Name == "Floor" and ix + 0.5 > x0 and ix + 0.5 < x1 and iz + 0.5 > z0 and iz + 0.5 < z1 then floorG[idx(ix, iz)] = true end
			end
		end
	end
	if p.CanCollide and y0 < 5.5 and y1 > 1.3 and p.Name ~= "Floor" then
		for ix = math.max(X0, math.floor(x0 - PR)), math.min(X1 - 1, math.ceil(x1 + PR) - 1) do
			for iz = math.max(Z0, math.floor(z0 - PR)), math.min(Z1 - 1, math.ceil(z1 + PR) - 1) do
				local cx, cz = ix + 0.5, iz + 0.5
				if cx > x0 - PR and cx < x1 + PR and cz > z0 - PR and cz < z1 + PR then blockG[idx(ix, iz)] = true end
			end
		end
	end
end

local function cellOf(x, z) return math.floor(x), math.floor(z) end
local function walkable(ix, iz)
	if ix < X0 or ix >= X1 or iz < Z0 or iz >= Z1 then return false end
	return floorG[idx(ix, iz)] and not blockG[idx(ix, iz)]
end
local reach = {}
local function flood(sx, sz)
	local qx, qz, head = {}, {}, 1
	local cx, cz = cellOf(sx, sz)
	if not walkable(cx, cz) then return false end
	reach[idx(cx, cz)] = true
	qx[1], qz[1] = cx, cz
	local tail = 1
	while head <= tail do
		local x, z = qx[head], qz[head]
		head += 1
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nx, nz = x + d[1], z + d[2]
			if walkable(nx, nz) and not reach[idx(nx, nz)] then
				reach[idx(nx, nz)] = true
				tail += 1
				qx[tail], qz[tail] = nx, nz
			end
		end
	end
	return true
end
local SPAWN = { 0, 30 }
local okStart = flood(SPAWN[1], SPAWN[2])
print("START", okStart and "ok" or "BLOCKED")

local function check(label, x, z, tol)
	local cx, cz = cellOf(x, z)
	local r = reach[idx(cx, cz)]
	tol = tol or 2 -- marker may sit against a wall / inside its own prop footprint
	if not r then
		for dx = -tol, tol do for dz = -tol, tol do
			if reach[idx(cx + dx, cz + dz)] then r = true end
		end end
	end
	print((r and "OK   " or "FAIL ") .. label, string.format("(%.1f, %.1f)", x, z))
	return r
end

-- doorways: both sides must be reachable
for _, d in ipairs(META.DW) do
	if d.kind ~= "window" and d.kind ~= "sealed" then
		local mid = (d.a0 + d.a1) / 2
		if d.axis == "x" then
			check("door " .. d.id .. " lo", mid, d.f - 2.5)
			check("door " .. d.id .. " hi", mid, d.f + 2.5)
		else
			check("door " .. d.id .. " lo", d.f - 2.5, mid)
			check("door " .. d.id .. " hi", d.f + 2.5, mid)
		end
	end
end
-- tagged gameplay markers (if the builder created any)
local CS = game:GetService("CollectionService")
local function posOfInst(inst)
	if inst.CFrame then return inst.CFrame.p end
	if inst.PrimaryPart then return inst.PrimaryPart.CFrame.p end
	return Vector3.zero
end
for _, t in ipairs({ "PlayerSpawn", "ChestSpawn", "Extraction", "EnemySpawn", "NPCSpawn", "PatrolPoint" }) do
	for _, inst in ipairs(CS:GetTagged(t)) do
		local pos = posOfInst(inst)
		local extra = inst:GetAttribute("Tier") or inst:GetAttribute("Type") or ""
		print(string.format("MARK\t%s\t%s\t%.1f\t%.1f\t%s", t, inst.Name, pos.X, pos.Z, extra))
		if pos.Y < 2.5 then check(t .. " " .. inst.Name, pos.X, pos.Z, t == "ChestSpawn" and 3 or 2) end
	end
end

-- dump for plotting
local rows = {}
for iz = Z0, Z1 - 1 do
	local cs = {}
	for ix = X0, X1 - 1 do
		local i = idx(ix, iz)
		local c = " "
		if floorG[i] then
			if blockG[i] then c = "#" elseif reach[i] then c = "." else c = "," end
		end
		cs[#cs + 1] = c
	end
	rows[#rows + 1] = table.concat(cs)
end
print("GRIDINFO", X0, X1, Z0, Z1)
for i, r in ipairs(rows) do print("ROW", r) end
local unreachable = 0
for i = 1, W * H do if floorG[i] and not blockG[i] and not reach[i] then unreachable += 1 end end
print("UNREACHABLE_FREE_CELLS", unreachable)
