--!nocheck
-- =============================================================================
--  HALCYON RESEARCH STATION  -  SITE 9
--  FacilityBuilder.luau  (generated from tools/facility/src/*.luau - see build.sh)
--
--  HOW TO USE
--    1. Open an EMPTY baseplate place in Roblox Studio (Edit mode).
--    2. View > Command Bar, paste this whole file, press Enter.
--    3. Wait a few seconds.  Everything lands in Workspace.Facility.
--    4. Run it again any time: it deletes the previous Facility and rebuilds.
--
--  Everything is built from anchored Parts + Lights + Particles, grouped per room.
--  Tweak the CFG table below (light strength, clutter density, world offset).
-- =============================================================================

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")

local CFG = {
	SEED = 90210,
	LIGHT_SCALE = 1.0, -- multiply every light's brightness
	LIGHT_DENSITY = 1.0, -- 0..1 fraction of lights created (try 0.6 for mobile-heavy games). Emergency + chest lights are always kept.
	DETAIL = 1.0, -- 0..1 clutter density (papers, stains, rubble). Lower for mobile.
	ORIGIN = Vector3.new(0, 0, 0), -- shift the whole facility (studs)
	FLICKER = true, -- install the client ambience script (flicker, fans, sparks)
	REMOVE_BASEPLATE = true, -- delete Workspace.Baseplate (its top would z-fight with the floor)
}

local rng = Random.new(CFG.SEED)
local function rand(a, b) return rng:NextNumber(a, b) end
local function chance(p) return rng:NextNumber() < p * CFG.DETAIL end
local function pick(t) return t[rng:NextInteger(1, #t)] end

-- ---------------------------------------------------------------- palette
local function C(r, g, b) return Color3.fromRGB(r, g, b) end
local function shade(c, f)
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end
local function jitter(c, a) return shade(c, 1 + rand(-a, a)) end

local PAL = {
	concrete = C(118, 116, 110), concreteDark = C(74, 72, 68), concreteWarm = C(104, 96, 84),
	steel = C(112, 118, 124), steelDark = C(48, 52, 56), steelLight = C(158, 164, 168),
	offwhite = C(196, 198, 190), blue = C(66, 90, 112), blueDark = C(34, 46, 60),
	tileWhite = C(186, 196, 192), tileGreen = C(92, 124, 106), tileDark = C(60, 76, 74),
	rust = C(118, 68, 40), rustDark = C(78, 46, 30), grime = C(34, 30, 24), black = C(16, 16, 18),
	yellow = C(226, 178, 34), orange = C(212, 108, 30), red = C(170, 30, 28), redDark = C(92, 14, 14),
	green = C(48, 160, 82), cyan = C(70, 200, 212), blood = C(66, 10, 10),
	wood = C(122, 94, 62), cardboard = C(152, 120, 80), paper = C(214, 210, 196),
}
local M = Enum.Material
local NID = Enum.NormalId
local DOORH = 8.5
local WT = 1 -- wall thickness
local FACE = { ["+z"] = 0, ["+x"] = math.pi / 2, ["-z"] = math.pi, ["-x"] = -math.pi / 2 }
local function yawOf(f) if type(f) == "string" then return FACE[f] end return f or 0 end

-- ---------------------------------------------------------------- root
local old = Workspace:FindFirstChild("Facility")
if old then old:Destroy() end
for _, c in ipairs(Lighting:GetChildren()) do
	if c.Name:sub(1, 10) == "FacilityFX" then c:Destroy() end
end
if CFG.REMOVE_BASEPLATE then
	local bp = Workspace:FindFirstChild("Baseplate")
	if bp then bp:Destroy() end
end
local root = Instance.new("Model")
root.Name = "Facility"
root.Parent = Workspace

-- ---------------------------------------------------------------- primitives
-- every primitive: anchored, no touch events. o = { deco, cc, shadow, tr, refl, shape }
local function mk(parent, name, size, cf, mat, color, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Material = mat or M.Concrete
	p.Color = color or PAL.concrete
	if o.shape then p.Shape = o.shape end
	if o.tr then p.Transparency = o.tr end
	if o.refl then p.Reflectance = o.refl end
	if o.deco then
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	end
	if o.cc ~= nil then p.CanCollide = o.cc end
	if o.shadow ~= nil then p.CastShadow = o.shadow end
	p.Parent = parent
	return p
end

-- axis-aligned box from extents
local function bx(parent, name, x0, x1, y0, y1, z0, z1, mat, color, o)
	return mk(parent, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat, color, o)
end
-- box by centre + size, optional yaw
local function cb(parent, name, cx, cy, cz, sx, sy, sz, yaw, mat, color, o)
	local cf = CFrame.new(cx, cy, cz)
	if yaw and yaw ~= 0 then cf = cf * CFrame.Angles(0, yaw, 0) end
	return mk(parent, name, Vector3.new(sx, sy, sz), cf, mat, color, o)
end
local CYL = Enum.PartType.Cylinder
local function asCyl(o) -- copy options (never mutate shared option tables like DECO)
	local n = {}
	for k, v in pairs(o or {}) do n[k] = v end
	n.shape = CYL
	return n
end
local function cylY(parent, name, cx, y0, y1, cz, d, mat, color, o) -- upright cylinder
	o = asCyl(o)
	return mk(parent, name, Vector3.new(y1 - y0, d, d),
		CFrame.new(cx, (y0 + y1) / 2, cz) * CFrame.Angles(0, 0, math.rad(90)), mat, color, o)
end
local function cylX(parent, name, x0, x1, cy, cz, d, mat, color, o) -- cylinder along X
	o = asCyl(o)
	return mk(parent, name, Vector3.new(x1 - x0, d, d), CFrame.new((x0 + x1) / 2, cy, cz), mat, color, o)
end
local function cylZ(parent, name, z0, z1, cx, cy, d, mat, color, o) -- cylinder along Z
	o = asCyl(o)
	return mk(parent, name, Vector3.new(z1 - z0, d, d),
		CFrame.new(cx, cy, (z0 + z1) / 2) * CFrame.Angles(0, math.rad(90), 0), mat, color, o)
end
local function disc(parent, name, cx, y, cz, d, thick, mat, color, o) -- flat disc on floor/ceiling
	o = asCyl(o)
	return mk(parent, name, Vector3.new(thick, d, d),
		CFrame.new(cx, y, cz) * CFrame.Angles(0, 0, math.rad(90)), mat, color, o)
end
local function fold(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end
local function tag(inst, t) CollectionService:AddTag(inst, t) end

-- plan-axis helpers: axis "x" = wall runs along X at plane z=f ; "z" = runs along Z at plane x=f
local function slab(parent, name, axis, a0, a1, y0, y1, f0, f1, mat, color, o)
	if axis == "x" then return bx(parent, name, a0, a1, y0, y1, f0, f1, mat, color, o) end
	return bx(parent, name, f0, f1, y0, y1, a0, a1, mat, color, o)
end
local function fr(f, s, d) -- slab extent from plane f going s direction by d
	if s > 0 then return f, f + d end
	return f - d, f
end
local function facingOf(axis, s) -- facing string of a wall's interior side
	if axis == "x" then return s > 0 and "+z" or "-z" end
	return s > 0 and "+x" or "-x"
end

-- ---------------------------------------------------------------- doorways
-- Every opening between rooms is declared once; both neighbouring rooms pick it up.
--   axis/f  : wall plane (shared line between the rooms)   a0..a1 : span along the wall
--   top     : door height (default DOORH)   kind : frame | blast | gate | window | sealed | broken
--   loText / hiText : sign shown on the low / high side of the wall (names the destination)
local DW = {
	{ id = "R-S", axis = "x", f = 0, a0 = -5, a1 = 5, kind = "gate", loText = "RECEPTION", hiText = "SECURITY CHECKPOINT" },
	{ id = "S-C", axis = "x", f = -24, a0 = -4, a1 = 4, kind = "blast", loText = "SECURITY CHECKPOINT", hiText = "MAIN CORRIDOR  A" },
	{ id = "C-L", axis = "z", f = -6, a0 = -42, a1 = -36, kind = "frame", loText = "BIOLOGICAL RESEARCH", hiText = "MAIN CORRIDOR" },
	{ id = "C-M", axis = "z", f = 6, a0 = -42, a1 = -36, kind = "frame", loText = "MAIN CORRIDOR", hiText = "MEDICAL / RECOVERY" },
	{ id = "C-W", axis = "z", f = -6, a0 = -76, a1 = -68, kind = "frame", top = 10, loText = "STORAGE  B", hiText = "MAIN CORRIDOR" },
	{ id = "C-T", axis = "z", f = 6, a0 = -76, a1 = -68, kind = "frame", top = 10, loText = "MAIN CORRIDOR", hiText = "MAINTENANCE" },
	{ id = "L-W", axis = "x", f = -54, a0 = -30, a1 = -24, kind = "frame", loText = "STORAGE  B", hiText = "R&D  LAB" },
	{ id = "M-T", axis = "x", f = -54, a0 = 26, a1 = 32, kind = "frame", loText = "MAINTENANCE", hiText = "RECOVERY WARD" },
	{ id = "C-D", axis = "x", f = -84, a0 = -4, a1 = 4, kind = "blast", top = 8, loText = "DECONTAMINATION", hiText = "MAIN CORRIDOR" },
	{ id = "D-X", axis = "x", f = -96, a0 = -4, a1 = 4, kind = "blast", top = 8, loText = "CONTAINMENT AREA", hiText = "DECONTAMINATION" },
	{ id = "X-E", axis = "x", f = -136, a0 = -4, a1 = 4, kind = "blast", top = 8, loText = "EVACUATION LIFT", hiText = "CONTAINMENT AREA" },
	{ id = "T-SA", axis = "x", f = -84, a0 = 32, a1 = 36, kind = "frame", top = 7.5, loText = "SERVICE HALLWAY", hiText = "MAINTENANCE" },
	{ id = "SA-SB", axis = "z", f = 30, a0 = -108, a1 = -104, kind = "frame", top = 7, loText = "", hiText = "" },
	{ id = "SB-X", axis = "z", f = 22, a0 = -108, a1 = -104, kind = "frame", top = 7, loText = "RESTRICTED  SERVICE ACCESS", hiText = "" },
	-- observation windows
	{ id = "W-CL", axis = "z", f = -6, a0 = -52, a1 = -45, kind = "window", y0 = 3, y1 = 8 },
	{ id = "W-CL2", axis = "z", f = -6, a0 = -33, a1 = -27, kind = "window", y0 = 3, y1 = 8 },
	{ id = "W-CM", axis = "z", f = 6, a0 = -33, a1 = -27, kind = "window", y0 = 3, y1 = 8 },
	{ id = "W-CM2", axis = "z", f = 6, a0 = -52, a1 = -46, kind = "window", y0 = 3, y1 = 8, broken = true },
	-- main entrance: sealed blast door (story: nobody gets in or out this way)
	{ id = "ENT", axis = "x", f = 36, a0 = -6, a1 = 6, kind = "sealed", loText = "", hiText = "" },
}
local function doorsFor(axis, f, a0, a1)
	local out = {}
	for _, d in ipairs(DW) do
		if d.axis == axis and math.abs(d.f - f) < 0.01 and d.a0 >= a0 - 0.01 and d.a1 <= a1 + 0.01 then
			-- the sealed entrance is a solid door: the wall stays closed, the door is drawn over it
			if d.kind ~= "sealed" then
				out[#out + 1] = { d.a0, d.a1, y0 = d.y0 or 0, y1 = d.y1 or d.top or DOORH, d = d }
			end
		end
	end
	table.sort(out, function(p, q) return p[1] < q[1] end)
	return out
end

-- ---------------------------------------------------------------- walls
-- one straight wall run with openings, trim, pilasters and grime
local function wallRun(r, axis, f, s, a0, a1, h)
	local st = r.wall
	local lo, hi = fr(f, s, WT)
	local fi = f + s * WT -- interior face plane
	local ops = doorsFor(axis, f, a0, a1)
	local arch = r.arch
	local segs = {}
	local cur = a0
	for _, o in ipairs(ops) do
		if o[1] > cur then segs[#segs + 1] = { cur, o[1] } end
		if o.y0 > 0 then slab(arch, "Sill", axis, o[1], o[2], 0, o.y0, lo, hi, st.mat, st.color) end
		if o.y1 < h then slab(arch, "Lintel", axis, o[1], o[2], o.y1, h, lo, hi, st.mat, st.color) end
		cur = o[2]
	end
	if cur < a1 then segs[#segs + 1] = { cur, a1 } end

	local tlo, thi = fr(fi, s, 0.18) -- trim layer (proud of the wall face)
	local plo, phi = fr(fi, s, 0.5)
	local b0, b1 = fr(fi, s, 0.26)
	local c0, c1 = fr(fi, s, 0.3)
	for _, sg in ipairs(segs) do
		local len = sg[2] - sg[1]
		if len > 0.2 then
			slab(arch, "Wall", axis, sg[1], sg[2], 0, h, lo, hi, st.mat, jitter(st.color, 0.04))
			if st.wain then -- tiled / panelled lower band
				slab(arch, "Wainscot", axis, sg[1], sg[2], 0.6, st.wain.h, tlo, thi, st.wain.mat, st.wain.color)
				slab(arch, "WainCap", axis, sg[1], sg[2], st.wain.h, st.wain.h + 0.35, c0, c1, M.Metal, st.trim or PAL.steelDark, { deco = true })
			end
			slab(arch, "Baseboard", axis, sg[1], sg[2], 0, 0.6, b0, b1, M.Concrete, PAL.concreteDark)
			slab(arch, "CeilTrim", axis, sg[1], sg[2], h - 0.7, h, c0, c1, M.Metal, st.trim or PAL.steelDark, { deco = true })
			if st.pil and len > st.pil.every * 1.2 then -- structural pilasters
				local x = sg[1] + st.pil.every / 2
				while x < sg[2] - 1.5 do
					slab(arch, "Pilaster", axis, x - 0.7, x + 0.7, 0, h, plo, phi, st.pil.mat or st.mat, st.pil.color or shade(st.color, 0.82))
					x += st.pil.every
				end
			end
			if st.panels then -- shallow raised wall panels break up big flat surfaces
				local pw = st.panels.w or 4
				local y0 = (st.wain and st.wain.h + 0.6) or 1.2
				local a = sg[1] + 0.8
				while a + pw - 1.2 < sg[2] - 0.6 do
					slab(arch, "WallPanel", axis, a, a + pw - 1.2, y0, h - 1.4, tlo, thi, st.mat, shade(st.color, st.panels.shade or 0.9), { deco = true })
					a += pw
				end
			end
			if st.accent then -- thin horizontal accent line (colour-coded by area)
				local ac = st.accent
				slab(arch, "AccentLine", axis, sg[1], sg[2], ac.y, ac.y + (ac.h or 0.3), c0, c1, ac.mat or M.Metal, ac.color or PAL.blue, { deco = true })
			end
			-- grime: vertical streaks + damp band
			local n = math.floor(len / 9 * (r.damage or 0.3) * CFG.DETAIL * 2.2)
			for _ = 1, n do
				local a = rand(sg[1] + 1, sg[2] - 1)
				local w = rand(0.4, 1.6)
				local top = rand(h * 0.45, h - 1)
				local bot = top - rand(3, 8)
				local g0, g1 = fr(fi, s, 0.06)
				slab(r.story, "WallStreak", axis, a - w / 2, a + w / 2, math.max(0.6, bot), top, g0, g1, M.Concrete, PAL.grime, { deco = true, tr = rand(0.45, 0.75) })
			end
			if (r.damage or 0) > 0.15 and len > 4 then
				local g0, g1 = fr(fi, s, 0.05)
				slab(r.story, "DampBand", axis, sg[1], sg[2], 0.6, rand(1.8, 3.2), g0, g1, M.Concrete, PAL.grime, { deco = true, tr = 0.62 })
			end
		end
	end
	return segs
end

-- ---------------------------------------------------------------- rooms
local ROOMS = {}
local function newRoom(def)
	local r = def
	r.model = fold(root, def.name)
	r.arch = fold(r.model, "Architecture")
	r.props = fold(r.model, "Props")
	r.lights = fold(r.model, "Lighting")
	r.story = fold(r.model, "Story")
	r.damage = def.damage or 0.3
	r.floor = def.floor or { mat = M.Concrete, color = PAL.concrete }
	ROOMS[def.name] = r
	-- interior extents (inside the walls)
	r.ix0, r.ix1, r.iz0, r.iz1 = r.x0 + WT, r.x1 - WT, r.z0 + WT, r.z1 - WT
	-- floor + ceiling slabs
	bx(r.arch, "Floor", r.x0, r.x1, -1, 0, r.z0, r.z1, r.floor.mat, r.floor.color)
	bx(r.arch, "Ceiling", r.x0, r.x1, r.h, r.h + 1, r.z0, r.z1, M.Concrete, shade(r.ceilColor or PAL.concreteDark, 1))
	-- four walls (N/S span the full width; W/E fit between them)
	wallRun(r, "x", r.z0, 1, r.x0, r.x1, r.h) -- north edge, interior faces +z
	wallRun(r, "x", r.z1, -1, r.x0, r.x1, r.h) -- south edge
	wallRun(r, "z", r.x0, 1, r.z0 + WT, r.z1 - WT, r.h) -- west edge
	wallRun(r, "z", r.x1, -1, r.z0 + WT, r.z1 - WT, r.h) -- east edge
	return r
end

-- floor overlay (inlay / walkway / grating panel)
local function floorZone(r, name, x0, x1, z0, z1, mat, color, o)
	return bx(r.arch, name, x0, x1, 0, 0.04, z0, z1, mat, color, o or { deco = true })
end
