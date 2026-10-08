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


-- ---------------------------------------------------------------- lights & fx
local FACEFOR = { ["+z"] = NID.Back, ["-z"] = NID.Front, ["+x"] = NID.Right, ["-x"] = NID.Left }

local function addLight(kind, parent, color, bright, range, o)
	o = o or {}
	if CFG.LIGHT_DENSITY < 1 and not o.keep and rng:NextNumber() > CFG.LIGHT_DENSITY then return nil end
	local L
	if kind == "point" then
		L = Instance.new("PointLight")
	elseif kind == "spot" then
		L = Instance.new("SpotLight")
		L.Angle = o.angle or 90
		L.Face = o.face or NID.Bottom
	else
		L = Instance.new("SurfaceLight")
		L.Angle = o.angle or 150
		L.Face = o.face or NID.Bottom
	end
	L.Color = color
	L.Brightness = bright * CFG.LIGHT_SCALE
	L.Range = range
	L.Shadows = o.shadows == true
	L.Parent = parent
	return L
end

-- ceiling strip light (fluorescent). o: dead, flicker(0..1), shadows, angle
local function lampStrip(r, cx, y, cz, axis, len, color, bright, range, o)
	o = o or {}
	local sx, sz = len, 1.1
	if axis == "z" then sx, sz = 1.1, len end
	cb(r.lights, "LampHousing", cx, y - 0.12, cz, sx, 0.24, sz, 0, M.Metal, PAL.steelDark, { deco = true })
	local lit = not o.dead
	local tube = cb(r.lights, "LampTube", cx, y - 0.27, cz, sx - 0.3, 0.1, sz - 0.3, 0,
		lit and M.Neon or M.SmoothPlastic, lit and color or shade(color, 0.22), { deco = true })
	if lit then addLight("surface", tube, color, bright, range, { shadows = o.shadows, angle = o.angle }) end
	if o.flicker and lit then
		tag(tube, "FlickerLight")
		tube:SetAttribute("Flicker", o.flicker)
	end
	return tube
end

-- caged industrial lamp (maintenance / storage / bunker look)
local function lampCage(r, cx, y, cz, color, bright, range, o)
	o = o or {}
	cb(r.lights, "CageMount", cx, y - 0.15, cz, 1.2, 0.3, 3.4, 0, M.Metal, PAL.steelDark, { deco = true })
	local lit = not o.dead
	local tube = cb(r.lights, "CageTube", cx, y - 0.5, cz, 0.7, 0.35, 3.0, 0,
		lit and M.Neon or M.SmoothPlastic, lit and color or shade(color, 0.2), { deco = true })
	for _, dx in ipairs({ -0.55, 0.55 }) do
		cb(r.lights, "CageBar", cx + dx, y - 0.5, cz, 0.12, 0.6, 3.3, 0, M.Metal, PAL.steelDark, { deco = true })
	end
	if lit then addLight("point", tube, color, bright, range, { shadows = o.shadows }) end
	if o.flicker and lit then
		tag(tube, "FlickerLight")
		tube:SetAttribute("Flicker", o.flicker)
	end
	return tube
end

-- small wall sconce / status light (facing = direction it points)
local function lampWall(r, x, y, z, facing, color, bright, range, o)
	o = o or {}
	local yaw = yawOf(facing)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	mk(r.lights, "SconceBase", Vector3.new(1.4, 0.8, 0.3), cf * CFrame.new(0, 0, 0.15), M.Metal, PAL.steelDark, { deco = true })
	local g = mk(r.lights, "SconceGlass", Vector3.new(1.0, 0.5, 0.2), cf * CFrame.new(0, 0, 0.38), M.Neon, color, { deco = true })
	if not o.noLight then addLight("point", g, color, bright, range, { shadows = false }) end
	if o.flicker then
		tag(g, "FlickerLight")
		g:SetAttribute("Flicker", o.flicker)
	end
	return g
end

-- red emergency beacon, pulses via client script
local function lampRed(r, x, y, z, facing, o)
	o = o or {}
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yawOf(facing), 0)
	mk(r.lights, "BeaconBase", Vector3.new(1.4, 1.4, 0.4), cf * CFrame.new(0, 0, 0.2), M.Metal, PAL.steelDark, { deco = true })
	local dome = mk(r.lights, "BeaconDome", Vector3.new(1.1, 1.1, 0.9), cf * CFrame.new(0, 0, 0.7), M.Neon, C(230, 30, 24), { deco = true, shape = Enum.PartType.Ball })
	addLight("point", dome, C(255, 40, 30), o.bright or 2.2, o.range or 22, { shadows = false, keep = true })
	tag(dome, "PulseLight")
	dome:SetAttribute("Speed", o.speed or 2.2)
	return dome
end

-- invisible light carrier (chest glow, accent washes)
local function glow(r, x, y, z, color, bright, range, kind)
	local p = mk(r.lights, "Glow", Vector3.new(0.4, 0.4, 0.4), CFrame.new(x, y, z), M.SmoothPlastic, PAL.black, { deco = true, tr = 1 })
	addLight(kind or "point", p, color, bright, range, { shadows = false, keep = true })
	return p
end

-- particle emitters --------------------------------------------------------
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local function emitter(r, x, y, z, kind, o)
	o = o or {}
	local sz = o.size or Vector3.new(0.5, 0.5, 0.5)
	local p = mk(r.props, "FX_" .. kind, sz, CFrame.new(x, y, z), M.SmoothPlastic, PAL.black, { deco = true, tr = 1 })
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0.6
	if kind == "steam" then
		e.Texture = SMOKE
		e.Rate = o.rate or 7
		e.Lifetime = NumberRange.new(2.5, 4)
		e.Speed = NumberRange.new(o.speed or 4, (o.speed or 4) + 3)
		e.SpreadAngle = Vector2.new(14, 14)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 4.5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.6, 0.86), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(C(205, 208, 206))
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.EmissionDirection = o.dir or NID.Top
	elseif kind == "dust" then
		e.Texture = SMOKE
		e.Rate = o.rate or 3
		e.Lifetime = NumberRange.new(7, 11)
		e.Speed = NumberRange.new(0.1, 0.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.9) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.9), NumberSequenceKeypoint.new(0.8, 0.9), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(C(190, 185, 170))
		e.Shape = Enum.ParticleEmitterShape.Box
	elseif kind == "spark" then
		e.Texture = SPARK
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.3, 0.7)
		e.Speed = NumberRange.new(8, 18)
		e.SpreadAngle = Vector2.new(55, 55)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		e.Color = ColorSequence.new(C(255, 190, 90))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Acceleration = Vector3.new(0, -40, 0)
		e.EmissionDirection = o.dir or NID.Bottom
		tag(p, "SparkSource")
		p:SetAttribute("Every", o.every or 6)
	elseif kind == "drip" then
		e.Texture = SPARK
		e.Rate = o.rate or 1.4
		e.Lifetime = NumberRange.new(0.8, 1.1)
		e.Speed = NumberRange.new(0, 0)
		e.SpreadAngle = Vector2.new(0, 0)
		e.Size = NumberSequence.new(0.18)
		e.Transparency = NumberSequence.new(0.35)
		e.Color = ColorSequence.new(C(150, 180, 190))
		e.Acceleration = Vector3.new(0, -34, 0)
		e.EmissionDirection = NID.Bottom
	end
	e.Parent = p
	return p
end

-- ---------------------------------------------------------------- text / signs
local function surfText(part, face, text, fg, o)
	o = o or {}
	local s = part.Size
	local w, h
	if face == NID.Front or face == NID.Back then
		w, h = s.X, s.Y
	elseif face == NID.Left or face == NID.Right then
		w, h = s.Z, s.Y
	else
		w, h = s.X, s.Z
	end
	local ppu = o.ppu or 44
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(math.max(16, math.floor(w * ppu)), math.max(16, math.floor(h * ppu)))
	g.LightInfluence = o.glow and 0 or 1
	g.Parent = part
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = holder
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextColor3 = fg
	t.Font = o.font or Enum.Font.GothamBold
	t.TextScaled = true
	t.TextWrapped = true
	t.Parent = holder
	return g
end

local function hazardGradient(parent, c0, c1)
	local n = 10
	local kps = {}
	kps[#kps + 1] = ColorSequenceKeypoint.new(0, c0)
	for i = 1, n - 1 do
		local before = (i - 1) % 2 == 0 and c0 or c1
		local after = i % 2 == 0 and c0 or c1
		kps[#kps + 1] = ColorSequenceKeypoint.new(i / n - 0.0005, before)
		kps[#kps + 1] = ColorSequenceKeypoint.new(i / n + 0.0005, after)
	end
	kps[#kps + 1] = ColorSequenceKeypoint.new(1, (n - 1) % 2 == 0 and c0 or c1)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BorderSizePixel = 0
	local gr = Instance.new("UIGradient")
	gr.Color = ColorSequence.new(kps)
	gr.Rotation = 45
	gr.Parent = f
	f.Parent = parent
end

-- diagonal yellow/black hazard stripes on a part face
local function hazardFace(part, face, c0, c1)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(256, 64)
	g.Parent = part
	hazardGradient(g, c0 or PAL.yellow, c1 or PAL.black)
end


-- ---------------------------------------------------------------- props
-- Convention: prop(r, x, z, facing, ...) builds at floor level in room r.
-- facing is "+z" "-z" "+x" "-x" (or a yaw in radians). Rows extend along local +X,
-- the prop's front is local +Z.  Pass r.story as the room for narrative clutter.
local P = {}
local function lp(par, name, cf, ox, oy, oz, sx, sy, sz, mat, color, o)
	return mk(par, name, Vector3.new(sx, sy, sz), cf * CFrame.new(ox, oy, oz), mat, color, o)
end
local function frame(x, y0, z, f) return CFrame.new(x, y0, z) * CFrame.Angles(0, yawOf(f), 0) end
local DECO = { deco = true }
local SHAPE_BALL = Enum.PartType.Ball

function P.sign(r, text, x, y, z, w, h, facing, bg, fg, o)
	o = o or {}
	local yaw = yawOf(facing)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 0.09)
	local p = mk(r.props, "Sign", Vector3.new(w, h, 0.15), cf, o.mat or M.SmoothPlastic, bg or PAL.steelDark, DECO)
	surfText(p, NID.Back, text, fg or PAL.offwhite, o)
	return p
end
-- yellow hazard / red restricted plates
function P.hazardSign(r, text, x, y, z, w, h, facing) return P.sign(r, text, x, y, z, w, h, facing, PAL.yellow, PAL.black) end
function P.restrictedSign(r, text, x, y, z, w, h, facing) return P.sign(r, text, x, y, z, w, h, facing, PAL.red, PAL.offwhite) end
function P.infoSign(r, text, x, y, z, w, h, facing) return P.sign(r, text, x, y, z, w, h, facing, PAL.blueDark, PAL.offwhite) end
function P.greenSign(r, text, x, y, z, w, h, facing) return P.sign(r, text, x, y, z, w, h, facing, PAL.green, PAL.offwhite) end

function P.poster(r, x, y, z, facing, variant)
	local V = {
		{ "REPORT ALL ANOMALIES\nTO YOUR SUPERVISOR", C(206, 198, 170), C(40, 40, 40) },
		{ "WASH HANDS\nBEFORE LEAVING SECTOR", C(168, 196, 206), C(24, 40, 56) },
		{ "NO FOOD OR DRINK\nIN LABORATORIES", C(214, 160, 70), C(40, 24, 8) },
		{ "BADGE UP.\nBADGE OUT.", C(120, 150, 130), C(12, 30, 16) },
		{ "DAYS SINCE LAST\nINCIDENT:  0", C(190, 60, 52), C(250, 240, 230) },
		{ "SAFETY IS\nEVERYONE'S JOB", C(210, 190, 90), C(30, 30, 30) },
	}
	local v = V[variant or rng:NextInteger(1, #V)]
	local p = P.sign(r, v[1], x, y, z, 3.2, 4.4, facing, v[2], v[3], { font = Enum.Font.GothamMedium })
	return p
end

-- ----- storage ---------------------------------------------------------
function P.crate(r, x, y0, z, w, h, d, facing, kind)
	kind = kind or "wood"
	local par = r.props
	local cf = frame(x, y0, z, facing)
	local mat, col = M.WoodPlanks, jitter(PAL.wood, 0.12)
	if kind == "metal" then mat, col = M.Metal, jitter(C(70, 82, 74), 0.15) end
	if kind == "bio" then mat, col = M.Plastic, jitter(C(176, 146, 40), 0.1) end
	if kind == "cardboard" then mat, col = M.Cardboard, jitter(PAL.cardboard, 0.1) end
	lp(par, "Crate", cf, 0, h / 2, 0, w, h, d, mat, col)
	if kind == "wood" or kind == "metal" then
		local band = kind == "wood" and shade(col, 0.62) or PAL.steelLight
		lp(par, "CrateBand", cf, 0, h / 2, -d * 0.3, w + 0.1, h + 0.1, 0.35, mat, band, DECO)
		lp(par, "CrateBand", cf, 0, h / 2, d * 0.3, w + 0.1, h + 0.1, 0.35, mat, band, DECO)
	end
	local lab = kind == "bio" and PAL.black or (kind == "metal" and PAL.yellow or PAL.paper)
	lp(par, "CrateLabel", cf, 0, h * 0.62, d / 2 + 0.03, math.min(w * 0.45, 1.8), h * 0.22, 0.05, M.SmoothPlastic, lab, DECO)
end
function P.pallet(r, x, z, facing)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "PalletDeck", cf, 0, 0.55, 0, 4, 0.2, 4, M.WoodPlanks, jitter(PAL.wood, 0.1))
	for i = -1, 1 do lp(par, "PalletRunner", cf, i * 1.7, 0.22, 0, 0.5, 0.44, 4, M.WoodPlanks, shade(PAL.wood, 0.8)) end
end
function P.barrel(r, x, z, color, y0)
	y0 = y0 or 0
	local par = r.props
	local col = color or pick({ PAL.rust, PAL.blueDark, C(70, 84, 70), PAL.steelDark })
	cylY(par, "Barrel", x, y0, y0 + 3.4, z, 2.2, M.Metal, col)
	cylY(par, "BarrelRing", x, y0 + 1.0, y0 + 1.25, z, 2.32, M.Metal, shade(col, 0.7), DECO)
	cylY(par, "BarrelRing", x, y0 + 2.2, y0 + 2.45, z, 2.32, M.Metal, shade(col, 0.7), DECO)
end
-- shelving run along local +X.  tiers x bays; stocked with random boxes
function P.shelf(r, x, z, facing, bays, tiers, stock)
	local par, cf = r.props, frame(x, 0, z, facing)
	local bay, spacing = 6, 3.3
	local len, H = bays * bay, tiers * spacing + 0.6
	for i = 0, bays do
		for _, dz in ipairs({ -0.95, 0.95 }) do
			lp(par, "Upright", cf, i * bay, H / 2, dz, 0.3, H, 0.3, M.Metal, PAL.blue)
		end
	end
	for t = 0, tiers - 1 do
		local y = 0.35 + t * spacing
		lp(par, "ShelfPlank", cf, len / 2, y, 0, len, 0.2, 2.2, M.Metal, PAL.steelDark)
		for b = 0, bays - 1 do
			if chance(stock or 0.8) or (stock or 0.8) >= 1 then
				local n = rng:NextInteger(1, 3)
				for k = 1, n do
					local bw, bh, bd = rand(1.2, 2.1), rand(1.2, 2.4), rand(1.1, 1.7)
					local col = pick({ PAL.cardboard, jitter(PAL.cardboard, 0.2), C(70, 78, 70), C(150, 150, 140), jitter(PAL.wood, 0.1) })
					lp(par, "StockBox", cf, b * bay + (k - 0.5) * (bay / n), y + 0.1 + bh / 2, rand(-0.2, 0.2), bw, bh, bd,
						col == PAL.cardboard and M.Cardboard or M.SmoothPlastic, col, DECO)
				end
			end
		end
	end
end
function P.lockers(r, x, z, facing, n, h)
	h = h or 6.4
	local par, cf = r.props, frame(x, 0, z, facing)
	local col = jitter(C(62, 74, 66), 0.12)
	for i = 0, n - 1 do
		local c = jitter(col, 0.08)
		lp(par, "Locker", cf, i * 2 + 1, h / 2, 0.9, 1.95, h, 1.8, M.Metal, shade(c, 0.7))
		lp(par, "LockerDoor", cf, i * 2 + 1, h / 2, 1.82, 1.75, h - 0.3, 0.1, M.CorrodedMetal, c, DECO)
		lp(par, "LockerVent", cf, i * 2 + 1, h - 0.9, 1.9, 1.2, 0.5, 0.05, M.Metal, PAL.black, DECO)
	end
end
function P.cabinet(r, x, z, facing, w, h, d, color)
	local par, cf = r.props, frame(x, 0, z, facing)
	local c = color or jitter(PAL.steel, 0.1)
	lp(par, "Cabinet", cf, 0, h / 2, 0, w, h, d, M.Metal, c)
	lp(par, "CabinetDoorSeam", cf, 0, h / 2, d / 2 + 0.02, 0.1, h - 0.4, 0.05, M.Metal, PAL.black, DECO)
	lp(par, "CabinetHandle", cf, w * 0.12, h * 0.5, d / 2 + 0.1, 0.15, 0.9, 0.15, M.Metal, PAL.steelLight, DECO)
	lp(par, "CabinetHandle", cf, -w * 0.12, h * 0.5, d / 2 + 0.1, 0.15, 0.9, 0.15, M.Metal, PAL.steelLight, DECO)
end
function P.jersey(r, x, z, facing, len)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "BarrierBase", cf, 0, 0.7, 0, len, 1.4, 2.2, M.Concrete, jitter(PAL.concrete, 0.1))
	lp(par, "BarrierTop", cf, 0, 2.1, 0, len, 1.4, 1.0, M.Concrete, jitter(PAL.concrete, 0.1))
end

-- ----- furniture -------------------------------------------------------
function P.desk(r, x, z, facing, w, d, color)
	local par, cf = r.props, frame(x, 0, z, facing)
	local c = color or jitter(PAL.steel, 0.1)
	lp(par, "DeskTop", cf, 0, 3.0, 0, w, 0.3, d, M.Metal, c)
	lp(par, "DeskSide", cf, -w / 2 + 0.2, 1.5, 0, 0.4, 3, d - 0.3, M.Metal, shade(c, 0.8))
	lp(par, "DeskSide", cf, w / 2 - 0.2, 1.5, 0, 0.4, 3, d - 0.3, M.Metal, shade(c, 0.8))
	lp(par, "DeskPanel", cf, 0, 1.6, -d / 2 + 0.3, w - 0.6, 2.6, 0.25, M.Metal, shade(c, 0.7))
end
function P.chair(r, x, z, facing, tipped)
	local par = r.props
	local cf = frame(x, 0, z, facing)
	if tipped then cf = CFrame.new(x, 1.0, z) * CFrame.Angles(0, yawOf(facing), 0) * CFrame.Angles(0, 0, math.rad(rand(80, 95))) end
	lp(par, "ChairSeat", cf, 0, 1.9, 0, 1.8, 0.28, 1.8, M.Fabric, PAL.blueDark)
	lp(par, "ChairBack", cf, 0, 3.2, -0.8, 1.7, 2.2, 0.25, M.Fabric, PAL.blueDark)
	lp(par, "ChairPost", cf, 0, 1.0, 0, 0.3, 1.8, 0.3, M.Metal, PAL.steelDark)
	lp(par, "ChairBase", cf, 0, 0.2, 0, 1.8, 0.2, 0.3, M.Metal, PAL.steelDark, DECO)
	lp(par, "ChairBase", cf, 0, 0.2, 0, 0.3, 0.2, 1.8, M.Metal, PAL.steelDark, DECO)
end
function P.bench(r, x, z, facing, len, tipped)
	local par = r.props
	local cf = frame(x, 0, z, facing)
	if tipped then cf = CFrame.new(x, 0.9, z) * CFrame.Angles(0, yawOf(facing), 0) * CFrame.Angles(math.rad(88), 0, 0) end
	lp(par, "BenchSeat", cf, len / 2, 1.7, 0, len, 0.3, 1.6, M.Metal, PAL.steelDark)
	lp(par, "BenchCushion", cf, len / 2, 1.95, 0, len - 0.4, 0.25, 1.3, M.Fabric, PAL.blueDark, DECO)
	lp(par, "BenchLeg", cf, 0.4, 0.85, 0, 0.3, 1.7, 1.4, M.Metal, PAL.steelDark)
	lp(par, "BenchLeg", cf, len - 0.4, 0.85, 0, 0.3, 1.7, 1.4, M.Metal, PAL.steelDark)
end
function P.monitor(r, x, y, z, facing, state, scrCol)
	local par, cf = r.props, frame(x, y, z, facing)
	lp(par, "MonitorBezel", cf, 0, 0.9, 0, 2.3, 1.7, 0.3, M.SmoothPlastic, PAL.black, DECO)
	lp(par, "MonitorStand", cf, 0, 0.15, -0.1, 0.5, 0.3, 0.5, M.SmoothPlastic, PAL.black, DECO)
	if state == "on" then
		local col = scrCol or pick({ PAL.cyan, PAL.green, C(90, 160, 220) })
		local s = lp(par, "MonitorScreen", cf, 0, 0.95, 0.17, 2.0, 1.4, 0.05, M.Neon, shade(col, 0.55), DECO)
		tag(s, "Screen")
	elseif state == "broken" then
		lp(par, "MonitorScreen", cf, 0, 0.95, 0.17, 2.0, 1.4, 0.05, M.Glass, C(10, 12, 14), { deco = true, refl = 0.2 })
		lp(par, "MonitorCrack", cf, 0, 0.95, 0.2, 0.08, 1.7, 0.03, M.SmoothPlastic, C(150, 160, 160), DECO)
	else
		lp(par, "MonitorScreen", cf, 0, 0.95, 0.17, 2.0, 1.4, 0.05, M.Glass, C(14, 18, 20), { deco = true, refl = 0.15 })
	end
end
function P.console(r, x, z, facing, w, states)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "ConsoleBody", cf, w / 2, 1.5, 0, w, 3.0, 2.6, M.Metal, PAL.steelDark)
	lp(par, "ConsoleTop", cf, w / 2, 3.05, 0, w + 0.2, 0.2, 2.8, M.Metal, PAL.steel)
	lp(par, "Keyboard", cf, w / 2, 3.25, 0.6, math.min(w - 1, 2.6), 0.15, 0.8, M.SmoothPlastic, C(40, 42, 44), DECO)
	local n = math.max(1, math.floor(w / 3))
	for i = 1, n do
		local wp = cf * Vector3.new((i - 0.5) * (w / n), 3.15, -0.4)
		P.monitor(r, wp.X, wp.Y, wp.Z, facing, states and states[i] or "on")
	end
end
function P.cabinetMed(r, x, y, z, facing, w, h)
	local par, cf = r.props, frame(x, y, z, facing)
	lp(par, "WallCabinet", cf, 0, h / 2, 0.6, w, h, 1.2, M.Metal, PAL.offwhite)
	lp(par, "WallCabinetGlass", cf, 0, h / 2, 1.22, w - 0.4, h - 0.4, 0.05, M.Glass, C(160, 200, 200), { deco = true, tr = 0.6 })
	lp(par, "MedCross", cf, 0, h - 0.5, 1.26, 0.8, 0.2, 0.04, M.SmoothPlastic, PAL.green, DECO)
	lp(par, "MedCross", cf, 0, h - 0.5, 1.26, 0.2, 0.8, 0.04, M.SmoothPlastic, PAL.green, DECO)
end

-- ----- laboratory ------------------------------------------------------
function P.labTable(r, x, z, facing, len, theme)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "LabBase", cf, len / 2, 1.4, 0, len - 0.4, 2.8, 2.2, M.Metal, PAL.offwhite)
	lp(par, "LabTop", cf, len / 2, 2.95, 0, len, 0.22, 2.7, M.SmoothPlastic, C(34, 44, 48))
	lp(par, "LabKick", cf, len / 2, 0.2, 0, len - 0.2, 0.4, 2.3, M.Metal, PAL.steelDark, DECO)
	local top = 3.06
	if theme == "chem" then
		for i = 1, math.max(2, math.floor(len / 3)) do
			local fx = i * (len / (math.floor(len / 3) + 1))
			local col = pick({ C(120, 210, 120), C(220, 200, 90), C(120, 190, 230) })
			lp(par, "Flask", cf, fx, top + 0.5, rand(-0.5, 0.5), 0.7, 1.0, 0.7, M.Glass, col, { deco = true, tr = 0.35 })
		end
		lp(par, "Burner", cf, len * 0.8, top + 0.4, 0, 0.6, 0.8, 0.6, M.Metal, PAL.steelDark, DECO)
	elseif theme == "bio" then
		lp(par, "MicroscopeBase", cf, len * 0.3, top + 0.1, 0, 1.2, 0.2, 1.4, M.Metal, PAL.black, DECO)
		lp(par, "MicroscopeArm", cf, len * 0.3, top + 0.9, -0.3, 0.3, 1.6, 0.3, M.Metal, PAL.black, DECO)
		lp(par, "MicroscopeTube", cf, len * 0.3, top + 1.6, 0, 0.35, 0.35, 1.0, M.Metal, PAL.steelDark, DECO)
		lp(par, "PetriTray", cf, len * 0.65, top + 0.1, 0, 1.8, 0.15, 1.2, M.SmoothPlastic, PAL.offwhite, DECO)
	else
		lp(par, "Instrument", cf, len * 0.3, top + 0.6, 0, 1.8, 1.2, 1.4, M.Metal, PAL.steelDark, DECO)
		lp(par, "InstrumentScreen", cf, len * 0.3, top + 0.8, 0.72, 1.2, 0.5, 0.05, M.Neon, shade(PAL.cyan, 0.5), DECO)
		lp(par, "Instrument", cf, len * 0.7, top + 0.5, 0, 1.6, 1.0, 1.4, M.Metal, shade(PAL.steelDark, 1.3), DECO)
	end
end
function P.fumeHood(r, x, z, facing)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "HoodBase", cf, 0, 1.5, 0, 5, 3, 2.6, M.Metal, PAL.offwhite)
	lp(par, "HoodTop", cf, 0, 3.1, 0, 5.2, 0.2, 2.8, M.SmoothPlastic, C(34, 44, 48))
	lp(par, "HoodBack", cf, 0, 5.6, -1.1, 5, 5, 0.3, M.Metal, PAL.offwhite)
	lp(par, "HoodSash", cf, 0, 5.4, 1.2, 4.6, 3.6, 0.1, M.Glass, C(170, 210, 210), { deco = true, tr = 0.7 })
	lp(par, "HoodCanopy", cf, 0, 8.0, 0, 5.2, 0.5, 2.8, M.Metal, PAL.steel)
	lp(par, "HoodDuct", cf, 0, 10.6, -0.4, 1.4, 5, 1.4, M.Metal, PAL.steelLight, DECO)
end
-- containment tank. state: full | cracked | empty ; specimen adds a dark shape inside
function P.tank(r, x, z, diam, h, liquid, state, specimen)
	local par = r.props
	state = state or "full"
	cylY(par, "TankBase", x, 0, 1.0, z, diam + 1.2, M.Metal, PAL.steelDark)
	cylY(par, "TankCap", x, h, h + 0.9, z, diam + 1.0, M.Metal, PAL.steelDark)
	if state ~= "cracked" then
		cylY(par, "TankGlass", x, 1.0, h, z, diam, M.Glass, C(190, 220, 220), { tr = 0.72, refl = 0.1, shadow = false })
	else
		cylY(par, "TankGlassLow", x, 1.0, h * 0.5, z, diam, M.Glass, C(190, 220, 220), { tr = 0.72, refl = 0.1, shadow = false })
		for i = 1, 3 do
			lp(par, "GlassShard", frame(x + math.cos(i * 2.1) * diam * 0.5, h * 0.45 + i * 0.4, z + math.sin(i * 2.1) * diam * 0.5, rand(0, 6)),
				0, 0, 0, 0.1, rand(1.5, 3), rand(0.6, 1.3), M.Glass, C(190, 220, 220), { deco = true, tr = 0.6 })
		end
	end
	if state == "full" then
		cylY(par, "TankLiquid", x, 1.2, h - 0.6, z, diam - 0.3, M.Neon, liquid, { deco = true, tr = 0.55 })
	elseif state == "cracked" then
		cylY(par, "TankLiquid", x, 1.2, h * 0.28, z, diam - 0.3, M.Neon, liquid, { deco = true, tr = 0.5 })
		disc(par, "TankSpill", x, 0.06, z, diam * 2.4, 0.05, M.Neon, shade(liquid, 0.5), { deco = true, tr = 0.6 })
	end
	if specimen then
		local sy = state == "full" and h * 0.5 or 1.4
		cylY(par, "Specimen", x, sy - 1.8, sy + 1.8, z, diam * 0.28, M.SmoothPlastic, C(34, 30, 28), { deco = true })
		mk(par, "SpecimenHead", Vector3.new(diam * 0.4, diam * 0.46, diam * 0.4), CFrame.new(x, sy + 2.1, z), M.SmoothPlastic, C(34, 30, 28), { deco = true, shape = SHAPE_BALL })
	end
	cylY(par, "TankPipe", x + diam * 0.35, h + 0.9, r.h, z, 0.5, M.Metal, PAL.steel, DECO)
end

-- ----- medical ---------------------------------------------------------
function P.bed(r, x, z, facing, state)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "BedFrame", cf, 0, 1.9, 0, 3.0, 0.3, 6.8, M.Metal, PAL.steelLight)
	lp(par, "Mattress", cf, 0, 2.3, 0.2, 2.8, 0.5, 6.0, M.Fabric, state == "stained" and C(170, 160, 150) or PAL.offwhite)
	lp(par, "Pillow", cf, 0, 2.7, -2.4, 2.0, 0.4, 1.2, M.Fabric, PAL.offwhite, DECO)
	lp(par, "BedHead", cf, 0, 3.2, -3.4, 3.0, 2.4, 0.3, M.Metal, PAL.steelLight)
	lp(par, "BedFoot", cf, 0, 2.6, 3.4, 3.0, 1.4, 0.3, M.Metal, PAL.steelLight)
	for _, sx in ipairs({ -1.55, 1.55 }) do
		lp(par, "BedRail", cf, sx, 2.9, 0, 0.15, 0.15, 5.0, M.Metal, PAL.steelLight, DECO)
		lp(par, "BedLeg", cf, sx, 0.95, -2.8, 0.3, 1.9, 0.3, M.Metal, PAL.steelDark)
		lp(par, "BedLeg", cf, sx, 0.95, 2.8, 0.3, 1.9, 0.3, M.Metal, PAL.steelDark)
	end
	if state == "stained" then
		lp(par, "BedStain", cf, 0.3, 2.58, 0.4, 1.6, 0.04, 2.2, M.SmoothPlastic, PAL.blood, { deco = true, tr = 0.15 })
	elseif state == "straps" then
		for _, oz in ipairs({ -1.2, 0.6, 2.2 }) do
			lp(par, "Strap", cf, 0, 2.62, oz, 3.2, 0.12, 0.35, M.Fabric, C(40, 32, 26), DECO)
		end
	end
end
function P.ivStand(r, x, z)
	local par = r.props
	cylY(par, "IVPole", x, 0.3, 6.2, z, 0.25, M.Metal, PAL.steelLight, DECO)
	cb(par, "IVBase", x, 0.15, z, 2.0, 0.3, 0.3, 0, M.Metal, PAL.steelDark, DECO)
	cb(par, "IVBase", x, 0.15, z, 0.3, 0.3, 2.0, 0, M.Metal, PAL.steelDark, DECO)
	cb(par, "IVBag", x + 0.5, 5.4, z, 0.5, 1.1, 0.25, 0, M.Glass, C(180, 210, 230), { deco = true, tr = 0.45 })
end
function P.curtain(r, x, y0, z, facing, len, h)
	local par, cf = r.props, frame(x, y0, z, facing)
	lp(par, "CurtainTrack", cf, len / 2, h + 0.15, 0, len, 0.2, 0.3, M.Metal, PAL.steelLight, DECO)
	lp(par, "Curtain", cf, len / 2, h / 2 - 0.1, 0, len, h - 0.6, 0.12, M.Fabric, C(150, 176, 168), { deco = true, tr = 0.12 })
end
function P.gurney(r, x, z, facing, tipped)
	local par = r.props
	local cf = frame(x, 0, z, facing)
	if tipped then cf = CFrame.new(x, 1.2, z) * CFrame.Angles(0, yawOf(facing), 0) * CFrame.Angles(0, 0, math.rad(84)) end
	lp(par, "GurneyTop", cf, 0, 2.5, 0, 2.6, 0.3, 6.4, M.Metal, PAL.steelLight)
	lp(par, "GurneyPad", cf, 0, 2.85, 0, 2.4, 0.4, 6.0, M.Fabric, C(70, 100, 110), DECO)
	for _, sx in ipairs({ -1.0, 1.0 }) do
		lp(par, "GurneyLeg", cf, sx, 1.2, -2.4, 0.25, 2.4, 0.25, M.Metal, PAL.steelDark)
		lp(par, "GurneyLeg", cf, sx, 1.2, 2.4, 0.25, 2.4, 0.25, M.Metal, PAL.steelDark)
	end
end

-- ----- industrial ------------------------------------------------------
function P.generator(r, x, z, facing, w, d, h)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "GenBase", cf, 0, 0.5, 0, w + 0.6, 1.0, d + 0.6, M.Concrete, PAL.concreteDark)
	lp(par, "GenBody", cf, 0, 1.0 + h / 2, 0, w, h, d, M.Metal, jitter(C(70, 84, 70), 0.1))
	for i = -2, 2 do
		lp(par, "GenRib", cf, i * (w / 5.5), 1.0 + h / 2, d / 2 + 0.1, 0.4, h - 0.6, 0.3, M.Metal, PAL.steelDark, DECO)
	end
	lp(par, "GenPanel", cf, 0, 1.0 + h * 0.62, d / 2 + 0.1, w * 0.4, h * 0.3, 0.2, M.Metal, PAL.black)
	for i = 1, 3 do
		lp(par, "GenLED", cf, -w * 0.12 + i * 0.7, 1.0 + h * 0.66, d / 2 + 0.25, 0.3, 0.3, 0.1, M.Neon, pick({ PAL.green, PAL.orange, PAL.red }), DECO)
	end
	cylY(par, "GenExhaust", x + w * 0.3, 1.0 + h, r.h - 0.5, z - d * 0.2, 1.1, M.CorrodedMetal, PAL.rustDark, DECO)
	local hz = lp(par, "GenHazard", cf, 0, 1.4, d / 2 + 0.31, w, 0.9, 0.05, M.SmoothPlastic, PAL.yellow, DECO)
	hazardFace(hz, NID.Back)
end
-- the maintenance landmark: reactor core with glowing band
function P.reactor(r, x, z, diam, h)
	local par = r.props
	cylY(par, "ReactorPlinth", x, 0, 1.0, z, diam + 6, M.Concrete, PAL.concreteDark)
	cylY(par, "ReactorShell", x, 1.0, h, z, diam, M.Metal, jitter(C(78, 88, 82), 0.06))
	for i, yy in ipairs({ 4, 8.5, 13 }) do
		if yy < h - 1 then cylY(par, "ReactorRing", x, yy, yy + 0.6, z, diam + 0.6, M.CorrodedMetal, PAL.rustDark, DECO) end
	end
	local band = cylY(par, "ReactorCoreBand", x, 6.0, 7.4, z, diam + 0.25, M.Neon, C(255, 130, 40), { deco = true, tr = 0.25 })
	addLight("point", band, C(255, 140, 60), 2.2, 30, { shadows = false })
	tag(band, "PulseLight")
	band:SetAttribute("Speed", 0.7)
	cylY(par, "ReactorCap", x, h, h + 0.8, z, diam * 0.7, M.Metal, PAL.steelDark)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		cylY(par, "CoolantPipe", x + math.cos(a) * diam * 0.36, h + 0.8, r.h, z + math.sin(a) * diam * 0.36, 0.9, M.Metal, PAL.steel, DECO)
	end
end

function P.pipeRun(r, axis, a0, a1, f, y, d, color, o)
	o = o or {}
	local par = r.props
	local col = color or PAL.rust
	local p
	if axis == "x" then p = cylX(par, "Pipe", a0, a1, y, f, d, M.Metal, col, DECO)
	else p = cylZ(par, "Pipe", a0, a1, f, y, d, M.Metal, col, DECO) end
	local a = a0 + 3
	while a < a1 do
		if axis == "x" then
			cb(par, "PipeHanger", a, (y + r.h) / 2, f, 0.3, r.h - y, d + 0.5, 0, M.Metal, PAL.steelDark, DECO)
		else
			cb(par, "PipeHanger", f, (y + r.h) / 2, a, d + 0.5, r.h - y, 0.3, 0, M.Metal, PAL.steelDark, DECO)
		end
		a += 8
	end
	if o.valves then
		local a2 = a0 + (a1 - a0) * 0.45
		if axis == "x" then
			cylX(par, "Flange", a2 - 0.3, a2 + 0.3, y, f, d + 0.5, M.Metal, PAL.steelDark, DECO)
			cylY(par, "ValveStem", a2, y, y + d / 2 + 0.9, f, 0.2, M.Metal, PAL.steelDark, DECO)
			cylY(par, "ValveWheel", a2, y + d / 2 + 0.9, y + d / 2 + 1.0, f, 1.1, M.Metal, PAL.red, DECO)
		else
			cylZ(par, "Flange", a2 - 0.3, a2 + 0.3, f, y, d + 0.5, M.Metal, PAL.steelDark, DECO)
			cylY(par, "ValveStem", f, y, y + d / 2 + 0.9, a2, 0.2, M.Metal, PAL.steelDark, DECO)
			cylY(par, "ValveWheel", f, y + d / 2 + 0.9, y + d / 2 + 1.0, a2, 1.1, M.Metal, PAL.red, DECO)
		end
	end
	return p
end
function P.cableTray(r, axis, a0, a1, f, y, w)
	local par = r.props
	if axis == "x" then
		bx(par, "TrayBed", a0, a1, y, y + 0.15, f - w / 2, f + w / 2, M.Metal, PAL.steelDark, DECO)
		bx(par, "TrayRail", a0, a1, y, y + 0.5, f - w / 2, f - w / 2 + 0.15, M.Metal, PAL.steelDark, DECO)
		bx(par, "TrayRail", a0, a1, y, y + 0.5, f + w / 2 - 0.15, f + w / 2, M.Metal, PAL.steelDark, DECO)
		cylX(par, "Cable", a0, a1, y + 0.3, f - w * 0.2, 0.22, M.Rubber, PAL.black, DECO)
		cylX(par, "Cable", a0, a1, y + 0.3, f + w * 0.1, 0.18, M.Rubber, PAL.yellow, DECO)
	else
		bx(par, "TrayBed", f - w / 2, f + w / 2, y, y + 0.15, a0, a1, M.Metal, PAL.steelDark, DECO)
		bx(par, "TrayRail", f - w / 2, f - w / 2 + 0.15, y, y + 0.5, a0, a1, M.Metal, PAL.steelDark, DECO)
		bx(par, "TrayRail", f + w / 2 - 0.15, f + w / 2, y, y + 0.5, a0, a1, M.Metal, PAL.steelDark, DECO)
		cylZ(par, "Cable", a0, a1, f - w * 0.2, y + 0.3, 0.22, M.Rubber, PAL.black, DECO)
		cylZ(par, "Cable", a0, a1, f + w * 0.1, y + 0.3, 0.18, M.Rubber, PAL.yellow, DECO)
	end
	local a = a0 + 2
	while a < a1 do
		if axis == "x" then bx(par, "TrayHanger", a - 0.1, a + 0.1, y, r.h, f - 0.1, f + 0.1, M.Metal, PAL.steelDark, DECO)
		else bx(par, "TrayHanger", f - 0.1, f + 0.1, y, r.h, a - 0.1, a + 0.1, M.Metal, PAL.steelDark, DECO) end
		a += 9
	end
end
function P.duct(r, axis, a0, a1, f, y, w, h, color)
	local par = r.props
	local col = color or PAL.steelLight
	if axis == "x" then
		bx(par, "Duct", a0, a1, y, y + h, f - w / 2, f + w / 2, M.Metal, col, DECO)
		local a = a0 + 4
		while a < a1 do bx(par, "DuctSeam", a - 0.15, a + 0.15, y - 0.1, y + h + 0.1, f - w / 2 - 0.1, f + w / 2 + 0.1, M.Metal, shade(col, 0.6), DECO) a += 6 end
	else
		bx(par, "Duct", f - w / 2, f + w / 2, y, y + h, a0, a1, M.Metal, col, DECO)
		local a = a0 + 4
		while a < a1 do bx(par, "DuctSeam", f - w / 2 - 0.1, f + w / 2 + 0.1, y - 0.1, y + h + 0.1, a - 0.15, a + 0.15, M.Metal, shade(col, 0.6), DECO) a += 6 end
	end
end
function P.vent(r, x, y, z, facing, w, h)
	local par, cf = r.props, frame(x, y, z, facing)
	lp(par, "VentFrame", cf, 0, h / 2, 0.15, w + 0.3, h + 0.3, 0.3, M.Metal, PAL.steelDark, DECO)
	lp(par, "VentBack", cf, 0, h / 2, 0.32, w, h, 0.05, M.SmoothPlastic, PAL.black, DECO)
	for i = 1, 4 do lp(par, "VentSlat", cf, 0, h * i / 5, 0.38, w, 0.12, 0.12, M.Metal, PAL.steel, DECO) end
end
-- ceiling/wall fan. blades spin on clients (tag Fan). facing = direction the fan blows
function P.fan(r, x, y, z, facing, d)
	local par = r.props
	local yaw = yawOf(facing)
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	mk(par, "FanHousing", Vector3.new(d + 0.6, d + 0.6, 0.6), cf * CFrame.new(0, 0, 0.3), M.Metal, PAL.steelDark, DECO)
	local m = Instance.new("Model")
	m.Name = "FanBlades"
	local hub = mk(m, "Hub", Vector3.new(0.7, 0.7, 0.4), cf * CFrame.new(0, 0, 0.7), M.Metal, PAL.black, DECO)
	mk(m, "Blade", Vector3.new(d * 0.9, 0.6, 0.12), cf * CFrame.new(0, 0, 0.7), M.Metal, PAL.steel, DECO)
	mk(m, "Blade", Vector3.new(0.6, d * 0.9, 0.12), cf * CFrame.new(0, 0, 0.7), M.Metal, PAL.steel, DECO)
	m.PrimaryPart = hub
	m.Parent = par
	tag(m, "Fan")
	m:SetAttribute("Speed", rand(2.5, 4.5))
end
function P.cctv(r, x, y, z, facing, state)
	local par = r.props
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yawOf(facing), 0)
	lp(par, "CamBracket", cf, 0, 0, 0.3, 0.3, 0.3, 0.6, M.Metal, PAL.steelDark, DECO)
	local tilt = cf * CFrame.new(0, -0.3, 1.0) * CFrame.Angles(math.rad(state == "dead" and 40 or 18), 0, state == "dead" and math.rad(14) or 0)
	local body = mk(par, "CCTV", Vector3.new(0.9, 0.8, 2.0), tilt, M.Metal, PAL.offwhite, DECO)
	mk(par, "CCTVLens", Vector3.new(0.6, 0.6, 0.3), tilt * CFrame.new(0, 0, 1.1), M.Glass, C(10, 12, 14), { deco = true, refl = 0.3 })
	if state ~= "dead" then
		local led = mk(par, "CCTVLed", Vector3.new(0.2, 0.2, 0.1), tilt * CFrame.new(0.28, 0.3, 0.9), M.Neon, C(255, 40, 30), DECO)
		tag(led, "PulseLight")
		led:SetAttribute("Speed", 1.4)
	end
	tag(body, "Camera")
end
function P.panel(r, x, y, z, facing, w, h, state)
	local par, cf = r.props, frame(x, y, z, facing)
	lp(par, "ElecPanel", cf, 0, h / 2, 0.25, w, h, 0.5, M.Metal, jitter(PAL.steel, 0.1), DECO)
	lp(par, "PanelDoor", cf, 0, h / 2, 0.52, w - 0.3, h - 0.3, 0.06, M.Metal, shade(PAL.steel, 0.85), DECO)
	for i = 1, 3 do
		lp(par, "PanelLED", cf, -w / 2 + 0.5 + i * 0.45, h - 0.55, 0.58, 0.22, 0.22, 0.06, M.Neon,
			(state == "dead" and PAL.redDark) or pick({ PAL.green, PAL.green, PAL.orange }), DECO)
	end
	P.hazardSign(r, "HIGH VOLTAGE", x, y + h + 0.9, z, 2.4, 1.0, facing)
	if state == "open" then
		local open = cf * CFrame.new(-w / 2, 0, 0.55) * CFrame.Angles(0, math.rad(-70), 0)
		mk(par, "PanelDoorOpen", Vector3.new(w - 0.3, h - 0.3, 0.06), open * CFrame.new((w - 0.3) / 2, h / 2, 0), M.Metal, shade(PAL.steel, 0.85), DECO)
		for i = 1, 3 do
			lp(par, "Wire", cf, -0.8 + i * 0.7, h * 0.4, 0.62, 0.12, rand(1, 2.5), 0.12, M.Rubber, pick({ PAL.red, PAL.yellow, PAL.black, PAL.cyan }), DECO)
		end
		emitter(r, x, y + h * 0.4, z + 0.6, "spark", { every = rand(4, 9), dir = NID.Front })
	end
end
function P.extinguisher(r, x, z, facing)
	local par = r.props
	local cf = frame(x, 0, z, facing)
	cylY(par, "Extinguisher", x, 1.6, 3.9, z, 0.8, M.Metal, PAL.red, DECO)
	lp(par, "ExtHead", cf, 0, 4.1, 0, 0.5, 0.4, 0.5, M.Metal, PAL.black, DECO)
	lp(par, "ExtBracket", cf, 0, 3.0, -0.45, 0.9, 0.3, 0.2, M.Metal, PAL.steelDark, DECO)
	P.sign(r, "FIRE", x, 5.2, z, 1.4, 0.7, facing, PAL.red, PAL.offwhite)
end
function P.exitSign(r, x, y, z, facing, text)
	local par = r.props
	local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yawOf(facing), 0)
	local p = mk(par, "ExitSign", Vector3.new(3.2, 1.2, 0.3), cf * CFrame.new(0, 0, 0.15), M.Neon, shade(PAL.green, 0.8), DECO)
	surfText(p, NID.Back, text or "EXIT", C(10, 30, 14), { font = Enum.Font.GothamBlack, glow = true })
	addLight("point", p, PAL.green, 0.5, 9, { shadows = false })
end

-- ----- story / mess ----------------------------------------------------
function P.blood(r, x, z, size, yaw)
	local par = r.story
	for i = 1, 3 do
		local s = size * rand(0.5, 1.0)
		cb(par, "Blood", x + rand(-size, size) * 0.3, 0.05 + i * 0.002, z + rand(-size, size) * 0.3, s, 0.04, s * rand(0.5, 1.0),
			(yaw or 0) + rand(-1, 1), M.SmoothPlastic, jitter(PAL.blood, 0.25), { deco = true, refl = 0.12 })
	end
end
function P.bloodWall(r, x, y, z, facing, h)
	local par, cf = r.story, frame(x, y, z, facing)
	lp(par, "BloodSmear", cf, 0, -h / 2, 0.05, rand(0.8, 1.6), h, 0.04, M.SmoothPlastic, PAL.blood, { deco = true, tr = 0.1 })
	lp(par, "BloodSmear", cf, rand(-0.6, 0.6), -h * 0.4, 0.05, 0.35, h * 0.8, 0.04, M.SmoothPlastic, shade(PAL.blood, 0.8), { deco = true, tr = 0.1 })
end
function P.drag(r, x0, z0, x1, z1)
	local n = math.floor(math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2) / 2.5)
	local yaw = math.atan2(x1 - x0, z1 - z0)
	for i = 0, n do
		local t = i / math.max(1, n)
		cb(r.story, "DragMark", x0 + (x1 - x0) * t + rand(-0.3, 0.3), 0.05, z0 + (z1 - z0) * t + rand(-0.3, 0.3),
			rand(0.9, 1.5) * (1.1 - t * 0.6), 0.04, 2.4, yaw, M.SmoothPlastic, jitter(PAL.blood, 0.2), { deco = true, refl = 0.1 })
	end
end
function P.papers(r, x, z, radius, n)
	n = math.floor(n * CFG.DETAIL)
	for _ = 1, n do
		local a, d = rand(0, 6.28), rand(0, radius)
		cb(r.story, "Paper", x + math.cos(a) * d, 0.06 + rand(0, 0.02), z + math.sin(a) * d, rand(0.9, 1.2), 0.03, rand(1.2, 1.6), rand(0, 6.28),
			M.SmoothPlastic, jitter(PAL.paper, 0.12), DECO)
	end
end
function P.rubble(r, x, z, radius, n, big)
	n = math.floor(n * math.max(CFG.DETAIL, 0.3))
	for _ = 1, n do
		local a, d = rand(0, 6.28), rand(0, radius)
		local s = rand(0.4, big and 2.2 or 1.2)
		local px, pz = x + math.cos(a) * d, z + math.sin(a) * d
		mk(r.story, "Rubble", Vector3.new(s, s * rand(0.5, 1.0), s * rand(0.6, 1.2)),
			CFrame.new(px, s * 0.25, pz) * CFrame.Angles(rand(-0.4, 0.4), rand(0, 6.28), rand(-0.4, 0.4)),
			M.Concrete, jitter(PAL.concreteDark, 0.25), { cc = s > 1.5, shadow = false, deco = s <= 1.5 })
	end
end
function P.puddle(r, x, z, d)
	disc(r.story, "Puddle", x, 0.05, z, d, 0.05, M.SmoothPlastic, C(28, 32, 34), { deco = true, refl = 0.55, tr = 0.1 })
end
function P.stain(r, x, z, w, d, yaw)
	cb(r.story, "FloorStain", x, 0.045, z, w, 0.03, d, yaw or 0, M.Concrete, PAL.grime, { deco = true, tr = rand(0.45, 0.7) })
end
function P.drain(r, x, z)
	disc(r.story, "Drain", x, 0.05, z, 1.8, 0.05, M.Metal, PAL.black, DECO)
	cb(r.story, "DrainBar", x, 0.09, z, 1.5, 0.04, 0.12, 0, M.Metal, PAL.steelDark, DECO)
	cb(r.story, "DrainBar", x, 0.09, z, 0.12, 0.04, 1.5, 0, M.Metal, PAL.steelDark, DECO)
end
-- yellow/black stripe band on the floor
function P.hazardFloor(r, x0, x1, z0, z1)
	local p = bx(r.story, "HazardStripe", x0, x1, 0, 0.05, z0, z1, M.SmoothPlastic, PAL.yellow, DECO)
	hazardFace(p, NID.Top)
end
function P.lineFloor(r, x0, x1, z0, z1, color)
	bx(r.story, "FloorLine", x0, x1, 0, 0.045, z0, z1, M.SmoothPlastic, color or PAL.yellow, DECO)
end
function P.whiteboard(r, x, y, z, w, h, facing, text)
	local p = P.sign(r, text, x, y, z, w, h, facing, PAL.offwhite, C(30, 40, 90), { font = Enum.Font.Code })
	return p
end

-- ----- structures ------------------------------------------------------
function P.stairs(r, x, z, facing, width, rise, steps, run)
	local par, cf = r.props, frame(x, 0, z, facing)
	run = run or 1.4
	for i = 1, steps do
		lp(par, "Step", cf, 0, rise * i / 2, (i - 0.5) * run, width, rise * i, run, M.DiamondPlate, PAL.steelDark)
	end
	for _, sx in ipairs({ -width / 2 - 0.1, width / 2 + 0.1 }) do
		lp(par, "StairRail", cf, sx, rise * steps * 0.5 + 2.2, steps * run / 2, 0.2, 0.2, steps * run + 1, M.Metal, PAL.yellow, { deco = true, shadow = false })
		for i = 0, steps, 3 do
			lp(par, "StairPost", cf, sx, rise * math.max(i, 1) + 1.2, i * run, 0.2, 2.4, 0.2, M.Metal, PAL.yellow, DECO)
		end
	end
end
-- elevated walkway. rails: table of sides {n,s,e,w}
function P.catwalk(r, x0, x1, z0, z1, y, rails)
	local par = r.props
	bx(par, "CatwalkDeck", x0, x1, y - 0.3, y, z0, z1, M.DiamondPlate, jitter(PAL.steelDark, 0.1))
	bx(par, "CatwalkBeam", x0, x1, y - 1.1, y - 0.3, z0 + 0.2, z0 + 0.5, M.Metal, PAL.steelDark, DECO)
	bx(par, "CatwalkBeam", x0, x1, y - 1.1, y - 0.3, z1 - 0.5, z1 - 0.2, M.Metal, PAL.steelDark, DECO)
	local function railX(zz, a0, a1)
		bx(par, "Rail", a0, a1, y + 3.2, y + 3.4, zz - 0.1, zz + 0.1, M.Metal, PAL.yellow, { shadow = false })
		bx(par, "Rail", a0, a1, y + 1.6, y + 1.8, zz - 0.1, zz + 0.1, M.Metal, PAL.yellow, { shadow = false })
		local a = a0
		while a <= a1 do bx(par, "RailPost", a - 0.1, a + 0.1, y, y + 3.4, zz - 0.1, zz + 0.1, M.Metal, PAL.yellow, { shadow = false }) a += 6 end
	end
	local function railZ(xx, a0, a1)
		bx(par, "Rail", xx - 0.1, xx + 0.1, y + 3.2, y + 3.4, a0, a1, M.Metal, PAL.yellow, { shadow = false })
		bx(par, "Rail", xx - 0.1, xx + 0.1, y + 1.6, y + 1.8, a0, a1, M.Metal, PAL.yellow, { shadow = false })
		local a = a0
		while a <= a1 do bx(par, "RailPost", xx - 0.1, xx + 0.1, y, y + 3.4, a - 0.1, a + 0.1, M.Metal, PAL.yellow, { shadow = false }) a += 6 end
	end
	rails = rails or {}
	if rails.n then railX(z0 + 0.1, x0, x1) end
	if rails.s then railX(z1 - 0.1, x0, x1) end
	if rails.w then railZ(x0 + 0.1, z0, z1) end
	if rails.e then railZ(x1 - 0.1, z0, z1) end
	-- support columns
	for _, cx in ipairs({ x0 + 0.6, x1 - 0.6 }) do
		for _, cz in ipairs({ z0 + 0.6, z1 - 0.6 }) do
			bx(par, "CatwalkColumn", cx - 0.35, cx + 0.35, 0, y - 0.3, cz - 0.35, cz + 0.35, M.Metal, PAL.steelDark)
		end
	end
end
function P.forklift(r, x, z, facing)
	local par, cf = r.props, frame(x, 0, z, facing)
	local body = PAL.orange
	lp(par, "ForkliftBody", cf, 0, 1.8, -1.0, 3.6, 2.2, 5.2, M.Metal, body)
	lp(par, "ForkliftCounterweight", cf, 0, 2.2, -3.6, 3.4, 2.4, 1.0, M.Metal, shade(body, 0.7))
	lp(par, "ForkliftSeat", cf, 0, 3.3, -1.6, 2.0, 0.4, 2.0, M.Fabric, PAL.black, DECO)
	for _, sx in ipairs({ -1.5, 1.5 }) do
		lp(par, "CabPost", cf, sx, 5.2, -2.6, 0.25, 4.2, 0.25, M.Metal, PAL.black, DECO)
		lp(par, "CabPost", cf, sx, 5.2, 0.4, 0.25, 4.2, 0.25, M.Metal, PAL.black, DECO)
		lp(par, "MastRail", cf, sx * 0.5, 4.4, 2.0, 0.4, 8.6, 0.5, M.Metal, PAL.steelDark)
		lp(par, "Fork", cf, sx * 0.8, 0.6, 3.6, 0.5, 0.3, 4.6, M.Metal, PAL.steelDark)
	end
	lp(par, "CabRoof", cf, 0, 7.4, -1.1, 3.6, 0.25, 3.4, M.Metal, PAL.black, DECO)
	for _, sx in ipairs({ -1.9, 1.9 }) do
		for _, oz in ipairs({ -3.0, 1.0 }) do
			mk(par, "Wheel", Vector3.new(1.2, 2.6, 2.6), cf * CFrame.new(sx, 1.3, oz) * CFrame.Angles(0, 0, math.rad(90)), M.Rubber, PAL.black, { shape = CYL, shadow = false, deco = true })
		end
	end
end
function P.cart(r, x, z, facing, loaded)
	local par, cf = r.props, frame(x, 0, z, facing)
	lp(par, "CartDeck", cf, 0, 1.2, 0, 3.4, 0.2, 2.2, M.Metal, PAL.steelDark)
	lp(par, "CartShelf", cf, 0, 2.7, 0, 3.4, 0.2, 2.2, M.Metal, PAL.steelDark)
	for _, sx in ipairs({ -1.6, 1.6 }) do
		lp(par, "CartPost", cf, sx, 2.0, -1.0, 0.2, 2.8, 0.2, M.Metal, PAL.steelDark)
		lp(par, "CartPost", cf, sx, 2.0, 1.0, 0.2, 2.8, 0.2, M.Metal, PAL.steelDark)
		for _, oz in ipairs({ -0.9, 0.9 }) do
			mk(par, "Caster", Vector3.new(0.3, 0.7, 0.7), cf * CFrame.new(sx, 0.4, oz) * CFrame.Angles(0, 0, math.rad(90)), M.Rubber, PAL.black, { shape = CYL, deco = true })
		end
	end
	if loaded then
		lp(par, "CartToolbox", cf, -0.6, 1.6, 0, 1.4, 0.8, 1.0, M.Metal, PAL.red, DECO)
		lp(par, "CartCan", cf, 0.9, 3.1, 0, 0.7, 0.8, 0.7, M.Metal, PAL.yellow, DECO)
	end
end
function P.detector(r, x, z, facing, ok)
	local par, cf = r.props, frame(x, 0, z, facing)
	for _, sx in ipairs({ -1.8, 1.8 }) do lp(par, "DetectorPost", cf, sx, 3.6, 0, 0.7, 7.2, 1.6, M.Metal, PAL.offwhite) end
	lp(par, "DetectorTop", cf, 0, 7.4, 0, 4.3, 0.8, 1.6, M.Metal, PAL.offwhite)
	local led = lp(par, "DetectorLight", cf, 0, 7.4, 0.85, 1.2, 0.35, 0.05, M.Neon, ok and PAL.green or PAL.red, DECO)
	if not ok then tag(led, "PulseLight") led:SetAttribute("Speed", 1.2) end
end
function P.keycardReader(r, x, y, z, facing, id, state)
	local par, cf = r.props, frame(x, y, z, facing)
	local body = lp(par, "KeycardReader", cf, 0, 0, 0.15, 0.9, 1.4, 0.3, M.Metal, PAL.black, DECO)
	local col = state == "unlocked" and PAL.green or (state == "dead" and PAL.black or PAL.red)
	lp(par, "ReaderLED", cf, 0, 0.35, 0.33, 0.3, 0.2, 0.05, M.Neon, col, DECO)
	lp(par, "ReaderSlot", cf, 0, -0.1, 0.33, 0.6, 0.08, 0.05, M.Metal, PAL.steelLight, DECO)
	body:SetAttribute("DoorId", id or "")
	tag(body, "KeycardReader")
end
function P.sandbag(r, x, z, facing, n)
	local cf = frame(x, 0, z, facing)
	for i = 0, n - 1 do
		lp(r.props, "Sandbag", cf, i * 1.6, 0.5, 0, 1.7, 1.0, 1.0, M.Fabric, jitter(C(130, 118, 90), 0.1))
		if i < n - 1 then lp(r.props, "Sandbag", cf, i * 1.6 + 0.8, 1.45, 0, 1.7, 0.9, 1.0, M.Fabric, jitter(C(130, 118, 90), 0.1)) end
	end
end

-- claw gouges on a wall (scary story detail). x,y,z at wall face, facing = wall normal
function P.claw(r, x, y, z, facing, n)
	local cf = frame(x, y, z, facing)
	for i = 1, (n or 4) do
		lp(r.story, "ClawMark", cf, (i - (n or 4) / 2 - 0.5) * 0.55, rand(-0.2, 0.2), 0.04, 0.13, rand(3.2, 4.8), 0.05, M.Concrete, C(36, 33, 30), { deco = true, tr = 0.1 })
	end
end
-- scattered glass fragments
function P.shards(r, x, z, radius, n)
	n = math.floor(n * math.max(CFG.DETAIL, 0.3))
	for _ = 1, n do
		local a, d = rand(0, 6.28), rand(0, radius)
		cb(r.story, "GlassShard", x + math.cos(a) * d, 0.08, z + math.sin(a) * d, rand(0.3, 0.9), 0.04, rand(0.3, 1.0), rand(0, 6.28),
			M.Glass, C(190, 220, 220), { deco = true, tr = 0.45 })
	end
end


-- ---------------------------------------------------------------- architecture helpers
-- interior partition wall with gaps. gaps = { {a0,a1,top?}, ... }; windows = { {a0,a1,y0,y1} }
local function partWall(r, axis, f, a0, a1, h, gaps, mat, color, opts)
	opts = opts or {}
	local t = opts.t or 0.8
	local f0, f1 = f - t / 2, f + t / 2
	local cuts = {}
	for _, g in ipairs(gaps or {}) do cuts[#cuts + 1] = { g[1], g[2], 0, g[3] or DOORH } end
	for _, w in ipairs(opts.windows or {}) do cuts[#cuts + 1] = { w[1], w[2], w[3], w[4] } end
	table.sort(cuts, function(p, q) return p[1] < q[1] end)
	local cur = a0
	local par = r.arch
	for _, c in ipairs(cuts) do
		if c[1] > cur then slab(par, "Partition", axis, cur, c[1], 0, h, f0, f1, mat or M.Concrete, color or PAL.concrete) end
		if c[3] > 0 then slab(par, "PartitionSill", axis, c[1], c[2], 0, c[3], f0, f1, mat or M.Concrete, color or PAL.concrete) end
		if c[4] < h then slab(par, "PartitionLintel", axis, c[1], c[2], c[4], h, f0, f1, mat or M.Concrete, color or PAL.concrete) end
		if c[3] > 0 then -- glass
			slab(par, "PartitionGlass", axis, c[1], c[2], c[3], c[4], f - 0.08, f + 0.08, M.Glass, C(170, 205, 205), { tr = 0.7, refl = 0.08, shadow = false })
			slab(par, "PartitionMullion", axis, (c[1] + c[2]) / 2 - 0.1, (c[1] + c[2]) / 2 + 0.1, c[3], c[4], f0, f1, M.Metal, PAL.steelDark, { shadow = false })
		end
		cur = c[2]
	end
	if cur < a1 then slab(par, "Partition", axis, cur, a1, 0, h, f0, f1, mat or M.Concrete, color or PAL.concrete) end
	-- door jambs
	for _, g in ipairs(gaps or {}) do
		slab(par, "PartJamb", axis, g[1] - 0.4, g[1], 0, g[3] or DOORH, f0 - 0.1, f1 + 0.1, M.Metal, PAL.steelDark, DECO)
		slab(par, "PartJamb", axis, g[2], g[2] + 0.4, 0, g[3] or DOORH, f0 - 0.1, f1 + 0.1, M.Metal, PAL.steelDark, DECO)
	end
end

-- suspended ceiling tiles with a T-bar grid; some tiles missing (damage) and left hanging
local function dropCeiling(r, y, holeProb, tint)
	local T = 4
	local x0, x1, z0, z1 = r.ix0, r.ix1, r.iz0, r.iz1
	local xs, zs = {}, {}
	local x = x0
	while x < x1 - 0.5 do xs[#xs + 1] = x x += T end
	xs[#xs + 1] = x1
	local z = z0
	while z < z1 - 0.5 do zs[#zs + 1] = z z += T end
	zs[#zs + 1] = z1
	local base = tint or C(176, 178, 172)
	local holes = {}
	for j = 1, #zs - 1 do
		local runStart = nil
		local function flush(i)
			if runStart then
				bx(r.arch, "CeilingTiles", xs[runStart], xs[i], y - 0.15, y, zs[j], zs[j + 1], M.Fabric, jitter(shade(base, 0.9), 0.08), { cc = false, shadow = false })
				runStart = nil
			end
		end
		for i = 1, #xs - 1 do
			local hole = rng:NextNumber() < holeProb * (0.4 + 0.6 * CFG.DETAIL)
			if hole then
				flush(i)
				holes[#holes + 1] = { (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2 }
			elseif not runStart then
				runStart = i
			end
		end
		flush(#xs)
	end
	-- grid
	for i = 1, #xs do bx(r.arch, "TBar", xs[i] - 0.1, xs[i] + 0.1, y - 0.28, y - 0.14, z0, z1, M.Metal, PAL.steelLight, DECO) end
	for j = 1, #zs do bx(r.arch, "TBar", x0, x1, y - 0.28, y - 0.14, zs[j] - 0.1, zs[j] + 0.1, M.Metal, PAL.steelLight, DECO) end
	-- hanging broken tiles + dark plenum glimpsed through the holes
	for _, h in ipairs(holes) do
		if chance(0.55) then
			cb(r.story, "HangingTile", h[1] + rand(-1, 1), y - rand(0.7, 1.4), h[2] + rand(-1, 1), 3.6, 0.15, 3.0, rand(0, 3),
				M.Fabric, shade(base, 0.8), { deco = true })
		end
	end
	return holes
end

-- structural beams across the ceiling (axis = direction the beam runs)
local function beams(r, axis, spacing, drop, color)
	local lo, hi, o0, o1
	if axis == "x" then
		lo, hi, o0, o1 = r.ix0, r.ix1, r.iz0, r.iz1
	else
		lo, hi, o0, o1 = r.iz0, r.iz1, r.ix0, r.ix1
	end
	local o = o0 + spacing / 2
	while o < o1 do
		if axis == "x" then
			bx(r.arch, "Beam", lo, hi, r.h - drop, r.h, o - 0.6, o + 0.6, M.Metal, color or PAL.steelDark, { cc = false })
			bx(r.arch, "BeamFlange", lo, hi, r.h - drop - 0.2, r.h - drop, o - 1.1, o + 1.1, M.Metal, color or PAL.steelDark, DECO)
		else
			bx(r.arch, "Beam", o - 0.6, o + 0.6, r.h - drop, r.h, lo, hi, M.Metal, color or PAL.steelDark, { cc = false })
			bx(r.arch, "BeamFlange", o - 1.1, o + 1.1, r.h - drop - 0.2, r.h - drop, lo, hi, M.Metal, color or PAL.steelDark, DECO)
		end
		o += spacing
	end
end

-- free-standing column
local function column(r, x, z, w, h, mat, color)
	bx(r.arch, "Column", x - w / 2, x + w / 2, 0, h or r.h, z - w / 2, z + w / 2, mat or M.Concrete, color or PAL.concrete)
	bx(r.arch, "ColumnBase", x - w / 2 - 0.2, x + w / 2 + 0.2, 0, 1.0, z - w / 2 - 0.2, z + w / 2 + 0.2, M.Concrete, shade(color or PAL.concrete, 0.8), DECO)
	bx(r.arch, "ColumnCap", x - w / 2 - 0.2, x + w / 2 + 0.2, (h or r.h) - 1.0, (h or r.h), z - w / 2 - 0.2, z + w / 2 + 0.2, M.Concrete, shade(color or PAL.concrete, 0.8), DECO)
end

-- ---------------------------------------------------------------- doorway dressing
local DWR = { props = fold(root, "Doorways"), story = nil, lights = nil, h = 12 }
DWR.story = DWR.props
DWR.lights = DWR.props
local DOOR_LIGHT = { ["S-C"] = "green", ["C-D"] = "red", ["D-X"] = "red", ["X-E"] = "green", ["R-S"] = "green" }

local function buildDoorway(d)
	local par = DWR.props
	local top = d.y1 or d.top or DOORH
	local axis, f, a0, a1 = d.axis, d.f, d.a0, d.a1
	local mid = (a0 + a1) / 2
	local jw = (d.kind == "blast") and 1.1 or 0.6
	local col = (d.kind == "blast") and PAL.steelDark or shade(PAL.steelDark, 1.2)
	local f0, f1 = f - 1.12, f + 1.12
	if d.kind == "window" then
		local y0, y1 = d.y0, d.y1
		slab(par, "WinFrame", axis, a0 - 0.3, a0, y0 - 0.3, y1 + 0.3, f0, f1, M.Metal, PAL.steelDark, { shadow = false })
		slab(par, "WinFrame", axis, a1, a1 + 0.3, y0 - 0.3, y1 + 0.3, f0, f1, M.Metal, PAL.steelDark, { shadow = false })
		slab(par, "WinFrame", axis, a0, a1, y1, y1 + 0.3, f0, f1, M.Metal, PAL.steelDark, { shadow = false })
		slab(par, "WinFrame", axis, a0, a1, y0 - 0.3, y0, f0, f1, M.Metal, PAL.steelDark, { shadow = false })
		if d.broken then
			slab(par, "WinGlass", axis, a0, a0 + (a1 - a0) * 0.38, y0, y1, f - 0.08, f + 0.08, M.Glass, C(170, 205, 205), { tr = 0.72, refl = 0.08, shadow = false })
			slab(par, "WinGlass", axis, a1 - (a1 - a0) * 0.18, a1, y0 + 1.5, y1, f - 0.08, f + 0.08, M.Glass, C(170, 205, 205), { tr = 0.72, refl = 0.08, shadow = false })
			slab(par, "WinShard", axis, a0 + (a1 - a0) * 0.38, a0 + (a1 - a0) * 0.38 + 0.15, y0, y1 - 1.5, f - 0.05, f + 0.05, M.Glass, C(200, 230, 230), { deco = true, tr = 0.55 })
		else
			slab(par, "WinGlass", axis, a0, a1, y0, y1, f - 0.08, f + 0.08, M.Glass, C(170, 205, 205), { tr = 0.72, refl = 0.08, shadow = false })
			slab(par, "WinMullion", axis, mid - 0.12, mid + 0.12, y0, y1, f0, f1, M.Metal, PAL.steelDark, { shadow = false })
		end
		return
	end
	-- jambs + header
	slab(par, "DoorJamb", axis, a0 - jw, a0, 0, top, f0, f1, M.Metal, col, { shadow = false })
	slab(par, "DoorJamb", axis, a1, a1 + jw, 0, top, f0, f1, M.Metal, col, { shadow = false })
	slab(par, "DoorHeader", axis, a0 - jw, a1 + jw, top, top + 0.7, f0, f1, M.Metal, col, { shadow = false })
	-- floor threshold
	slab(par, "Threshold", axis, a0, a1, 0, 0.06, f - 1.1, f + 1.1, M.Metal, PAL.steelDark, DECO)

	if d.kind == "blast" then
		-- retracted leaves sit proud of the wall on the low side; hazard stripe jamb faces
		local w = (a1 - a0) / 2
		local lo, hi = f - 1.5, f - 1.0
		slab(par, "BlastLeaf", axis, a0 - w - jw, a0 - jw, 0, top, lo, hi, M.DiamondPlate, shade(PAL.steelDark, 1.1), { shadow = false })
		slab(par, "BlastLeaf", axis, a1 + jw, a1 + jw + w, 0, top, lo, hi, M.DiamondPlate, shade(PAL.steelDark, 1.1), { shadow = false })
		local hz = slab(par, "BlastHazard", axis, a0 - jw, a1 + jw, top - 0.5, top + 0.7, f - 1.14, f - 1.1, M.SmoothPlastic, PAL.yellow, DECO)
		hazardFace(hz, axis == "x" and NID.Front or NID.Left)
		local hz2 = slab(par, "BlastHazard", axis, a0 - jw, a1 + jw, top - 0.5, top + 0.7, f + 1.1, f + 1.14, M.SmoothPlastic, PAL.yellow, DECO)
		hazardFace(hz2, axis == "x" and NID.Back or NID.Right)
		-- status light + readers
		local lc = DOOR_LIGHT[d.id] or "red"
		local cc = lc == "green" and PAL.green or PAL.red
		for _, side in ipairs({ -1, 1 }) do
			local px = axis == "x" and mid or (f + side * 1.2)
			local pz = axis == "x" and (f + side * 1.2) or mid
			local fac = axis == "x" and (side < 0 and "-z" or "+z") or (side < 0 and "-x" or "+x")
			local led = mk(par, "DoorStatus", Vector3.new(axis == "x" and 3 or 0.35, 0.35, axis == "x" and 0.35 or 3),
				CFrame.new(px, top - 0.9, pz), M.Neon, cc, DECO)
			if lc == "red" then tag(led, "PulseLight") led:SetAttribute("Speed", 1.5) end
			local rx = axis == "x" and (a1 + jw + 1.1) or (f + side * 1.15)
			local rz = axis == "x" and (f + side * 1.15) or (a1 + jw + 1.1)
			P.keycardReader(DWR, rx, 4.6, rz, fac, d.id, lc == "green" and "unlocked" or nil)
		end
	elseif d.kind == "gate" then
		for _, side in ipairs({ -1, 1 }) do
			local px = axis == "x" and mid or (f + side * 1.2)
			local pz = axis == "x" and (f + side * 1.2) or mid
			mk(par, "GateLight", Vector3.new(axis == "x" and 4 or 0.3, 0.3, axis == "x" and 0.3 or 4), CFrame.new(px, top - 0.5, pz), M.Neon, PAL.green, DECO)
		end
	end

	-- destination signs
	local function signAt(side, text)
		if not text or text == "" then return end
		local px = axis == "x" and mid or (f + side * 1.0)
		local pz = axis == "x" and (f + side * 1.0) or mid
		local fac = axis == "x" and (side < 0 and "-z" or "+z") or (side < 0 and "-x" or "+x")
		local w = math.min(math.max(#text * 0.5 + 1.4, 5), 11)
		local fn, bg, fg = P.infoSign, nil, nil
		if text:find("RESTRICTED") or text:find("CONTAINMENT") or text:find("DECON") then fn = P.restrictedSign end
		if text:find("MAINTENANCE") or text:find("SERVICE") or text:find("LOADING") then fn = P.hazardSign end
		if text:find("EVACUATION") then fn = P.greenSign end
		fn(DWR, text, px, top + 1.5, pz, w, 1.1, fac)
	end
	signAt(-1, d.loText)
	signAt(1, d.hiText)
end

local function buildAllDoorways()
	for _, d in ipairs(DW) do
		if d.kind == "sealed" then
			-- big sealed main entrance, drawn flush against the reception's south wall
			local par = DWR.props
			local zf = d.f - 1.0 -- interior face of the reception south wall
			bx(par, "EntranceFrame", d.a0 - 1.2, d.a1 + 1.2, 0, 12.4, zf - 0.7, zf + 0.05, M.Metal, PAL.steelDark)
			bx(par, "EntranceDoor", d.a0, d.a1, 0, 11.4, zf - 0.55, zf - 0.1, M.DiamondPlate, shade(PAL.steelDark, 1.15))
			bx(par, "EntranceSeamV", -0.15, 0.15, 0, 11.4, zf - 0.6, zf - 0.55, M.Metal, PAL.black, DECO)
			local hz = bx(par, "EntranceHazard", d.a0 - 1.2, d.a1 + 1.2, 11.4, 12.4, zf - 0.75, zf - 0.7, M.SmoothPlastic, PAL.yellow, DECO)
			hazardFace(hz, NID.Back)
			cylZ(par, "EntranceLockWheel", zf - 0.75, zf - 0.55, 0, 5.5, 3.0, M.Metal, PAL.red, DECO)
			-- dents: the door was beaten from the inside
			for i = 1, 5 do
				local px, py = rand(d.a0 + 1, d.a1 - 1), rand(2, 8)
				mk(par, "Dent", Vector3.new(rand(1.2, 2.4), rand(1.2, 2.4), 0.12),
					CFrame.new(px, py, zf - 0.62) * CFrame.Angles(rand(-0.2, 0.2), rand(-0.2, 0.2), rand(0, 3)), M.Metal, shade(PAL.steelDark, rand(0.55, 0.8)), DECO)
			end
		else
			buildDoorway(d)
		end
	end
end


-- ===========================================================================
--  ROOMS
-- ===========================================================================
local WALL = {
	lobby = { mat = M.Concrete, color = C(142, 140, 132), wain = { h = 5, mat = M.Metal, color = C(58, 64, 68) }, trim = PAL.steelDark, pil = { every = 12 },
		panels = { w = 4.5, shade = 0.86 }, accent = { y = 9.4, h = 0.45, mat = M.Metal, color = PAL.blue } },
	sec = { mat = M.Concrete, color = C(150, 152, 150), wain = { h = 4, mat = M.Metal, color = PAL.steelDark }, trim = PAL.steelDark, pil = { every = 10 },
		accent = { y = 6.0, h = 0.25, mat = M.Neon, color = shade(PAL.red, 0.5) } },
	corr = { mat = M.Concrete, color = C(128, 130, 124), wain = { h = 4.4, mat = M.CeramicTiles, color = PAL.tileWhite }, trim = PAL.tileGreen },
	lab = { mat = M.Plaster, color = C(148, 162, 170), wain = { h = 4.6, mat = M.CeramicTiles, color = C(190, 204, 204) }, trim = PAL.blue, pil = { every = 12 },
		accent = { y = 6.4, h = 0.22, mat = M.Neon, color = shade(PAL.cyan, 0.4) } },
	med = { mat = M.Plaster, color = C(128, 158, 140), wain = { h = 4.8, mat = M.CeramicTiles, color = PAL.tileWhite }, trim = PAL.tileDark, pil = { every = 12, color = C(118, 146, 130) } },
	storage = { mat = M.Concrete, color = C(104, 102, 96), trim = PAL.steelDark, pil = { every = 10, color = C(86, 84, 80) } },
	maint = { mat = M.Concrete, color = C(86, 80, 72), wain = { h = 3.2, mat = M.CorrodedMetal, color = PAL.rustDark }, trim = PAL.rustDark, pil = { every = 11, color = C(70, 66, 60) } },
	service = { mat = M.Concrete, color = C(80, 76, 70), trim = PAL.rustDark },
	decon = { mat = M.Concrete, color = C(150, 156, 156), wain = { h = 6, mat = M.CeramicTiles, color = C(168, 184, 184) }, trim = PAL.steelDark },
	restricted = { mat = M.Concrete, color = C(68, 68, 70), wain = { h = 7, mat = M.DiamondPlate, color = PAL.steelDark }, trim = PAL.black, pil = { every = 11, color = C(52, 52, 56) },
		panels = { w = 5, shade = 0.9 }, accent = { y = 11, h = 0.3, mat = M.Neon, color = shade(PAL.red, 0.45) } },
	lift = { mat = M.Concrete, color = C(96, 98, 96), wain = { h = 4, mat = M.Metal, color = PAL.steelDark }, trim = PAL.green },
}
local WHITE = C(255, 246, 230)
local COLD = C(214, 232, 255)
local WARM = C(255, 206, 140)

-- small helpers used by several rooms -----------------------------------------
local function vending(r, x, z, facing, tint)
	local cf = frame(x, 0, z, facing)
	lp(r.props, "VendBody", cf, 0, 3.3, 0, 3.2, 6.6, 2.6, M.Metal, tint or C(150, 40, 40))
	local scr = lp(r.props, "VendPanel", cf, -0.3, 3.7, 1.32, 2.2, 3.8, 0.1, M.Neon, C(150, 190, 210), DECO)
	lp(r.props, "VendSlot", cf, -0.3, 1.0, 1.32, 2.2, 0.8, 0.1, M.Metal, PAL.black, DECO)
	tag(scr, "FlickerLight")
	scr:SetAttribute("Flicker", 0.25)
end
local function cageBox(r, x0, x1, z0, z1, h, gaps) -- chain-link-ish security cage; gaps = { {axis,a0,a1} }
	local function side(axis, f, a0, a1, gap)
		local segs = {}
		if gap then
			if gap[1] > a0 then segs[#segs + 1] = { a0, gap[1] } end
			if gap[2] < a1 then segs[#segs + 1] = { gap[2], a1 } end
			bx(r.props, "CageTop", axis == "x" and gap[1] or f - 0.1, axis == "x" and gap[2] or f + 0.1, h - 0.4, h,
				axis == "x" and f - 0.1 or gap[1], axis == "x" and f + 0.1 or gap[2], M.Metal, PAL.steelDark, DECO)
		else
			segs[1] = { a0, a1 }
		end
		for _, s in ipairs(segs) do
			slab(r.props, "CageMesh", axis, s[1], s[2], 0.4, h - 0.4, f - 0.06, f + 0.06, M.Metal, PAL.steel, { tr = 0.55, shadow = false })
			slab(r.props, "CageRail", axis, s[1], s[2], 0, 0.4, f - 0.15, f + 0.15, M.Metal, PAL.steelDark, { shadow = false })
			slab(r.props, "CageRail", axis, s[1], s[2], h - 0.4, h, f - 0.15, f + 0.15, M.Metal, PAL.steelDark, { shadow = false })
			local a = s[1]
			while a <= s[2] + 0.01 do
				slab(r.props, "CagePost", axis, a - 0.12, a + 0.12, 0, h, f - 0.15, f + 0.15, M.Metal, PAL.steelDark, { shadow = false })
				a += 5
			end
		end
	end
	local g = gaps or {}
	side("x", z0, x0, x1, g.n)
	side("x", z1, x0, x1, g.s)
	side("z", x0, z0, z1, g.w)
	side("z", x1, z0, z1, g.e)
end

-- =============================================================================
-- RECEPTION  (hero: official entrance, mostly intact, just evacuated)
-- =============================================================================
do
	local r = newRoom({ name = "Reception", x0 = -25, x1 = 25, z0 = 0, z1 = 36, h = 18,
		floor = { mat = M.Marble, color = C(152, 150, 142) }, wall = WALL.lobby, damage = 0.2 })
	floorZone(r, "CarpetRunner", -3.2, 3.2, 1, 35, M.Fabric, C(52, 66, 74))
	floorZone(r, "CarpetEdge", -3.4, -3.2, 1, 35, M.Fabric, PAL.yellow)
	floorZone(r, "CarpetEdge", 3.2, 3.4, 1, 35, M.Fabric, PAL.yellow)
	disc(r.arch, "FloorLogo", 0, 0.05, 18, 12, 0.06, M.Metal, PAL.steelDark, DECO)
	disc(r.arch, "FloorLogoRing", 0, 0.08, 18, 10.4, 0.06, M.Neon, shade(PAL.cyan, 0.45), DECO)
	disc(r.arch, "FloorLogoInner", 0, 0.1, 18, 9.6, 0.06, M.Metal, PAL.steelDark, DECO)
	beams(r, "x", 9, 1.6)
	column(r, -13, 20, 2.4, 18, M.Concrete, C(120, 118, 112))
	column(r, 13, 20, 2.4, 18, M.Concrete, C(120, 118, 112))
	column(r, -13, 8, 2.4, 18, M.Concrete, C(120, 118, 112))
	column(r, 13, 8, 2.4, 18, M.Concrete, C(120, 118, 112))

	-- lighting: neutral white, a couple of tubes failing
	local y = r.h - 1.7
	for _, z in ipairs({ 5, 15, 26 }) do
		for _, x in ipairs({ -10, 10 }) do
			local f = (z == 15 and x == 10) and 0.5 or nil
			lampStrip(r, x, y, z, "x", 8, WHITE, 1.5, 30, { flicker = f, dead = (z == 26 and x == -10) })
		end
	end
	lampWall(r, -24, 7, 8, "+x", WARM, 0.8, 14)
	lampWall(r, 24, 7, 8, "-x", WARM, 0.8, 14)
	lampWall(r, -24, 7, 28, "+x", WARM, 0.7, 14, { flicker = 0.4 })
	lampWall(r, 24, 7, 28, "-x", WARM, 0.7, 14)

	-- north wall: facility logo above the checkpoint gate
	cylZ(r.props, "LogoDisc", 1.0, 1.35, 0, 15.0, 4.4, M.Metal, PAL.steelDark, DECO)
	cylZ(r.props, "LogoRing", 1.0, 1.5, 0, 15.0, 4.9, M.Neon, shade(PAL.cyan, 0.5), DECO)
	cylZ(r.props, "LogoCore", 1.35, 1.6, 0, 15.0, 2.2, M.Metal, PAL.blue, DECO)
	P.sign(r, "HALCYON  RESEARCH  STATION", 0, 11.9, 1.0, 17, 1.5, "+z", PAL.blueDark, PAL.offwhite, { font = Enum.Font.GothamBlack })
	-- banners between the pilasters (one has come down), status screens
	for sx, zs in pairs({ [-1] = { 9, 33 }, [1] = { 7, 21, 31 } }) do
		for _, z in ipairs(zs) do
			local bx0 = sx * 23.7
			cb(r.props, "Banner", bx0, 11, z, 0.12, 8, 2.6, 0, M.Fabric, PAL.blueDark, DECO)
			cb(r.props, "BannerEmblem", bx0 - sx * 0.08, 12.5, z, 0.06, 2.0, 1.4, 0, M.SmoothPlastic, shade(PAL.cyan, 0.55), DECO)
		end
	end
	cb(r.story, "FallenBanner", -18, 0.08, 20.5, 2.6, 0.06, 8, 0.5, M.Fabric, PAL.blueDark, DECO)
	local scr = P.sign(r, "FACILITY STATUS\nLEVEL 3 BREACH\nALL SYSTEMS OFFLINE", 24, 11, 26, 5, 2.6, "-x", C(8, 24, 20), PAL.green, { font = Enum.Font.Code, glow = true })
	tag(scr, "Screen")
	P.sign(r, "ENTRANCE SEALED  -  LOCKDOWN IN EFFECT", 0, 14.6, 35, 15, 1.8, "-z", PAL.red, PAL.offwhite, { font = Enum.Font.GothamBlack })

	-- reception counter with enclosed back office
	bx(r.props, "DeskFront", -22, -8, 0, 3.7, 10, 11, M.Metal, C(58, 66, 70))
	bx(r.props, "DeskTop", -22.4, -7.6, 3.7, 4.0, 9.4, 11.4, M.Granite, C(36, 38, 40))
	bx(r.props, "DeskSide", -22.4, -21.4, 0, 3.7, 3, 10, M.Metal, C(58, 66, 70))
	bx(r.props, "DeskSideTop", -22.6, -21.2, 3.7, 4.0, 3, 10, M.Granite, C(36, 38, 40))
	P.sign(r, "VISITOR  RECEPTION", -15, 2.0, 11.0, 8, 1.2, "+z", PAL.blueDark, PAL.offwhite)
	P.monitor(r, -17, 4.0, 9.8, "-z", "on")
	P.monitor(r, -12, 4.0, 9.8, "-z", "broken")
	P.monitor(r, -20, 4.0, 9.8, "-z", "off")
	P.chair(r, -16.5, 7.2, "+z", true)
	P.cabinet(r, -20, 2.1, "+z", 3.2, 6.4, 1.6)
	P.cabinet(r, -16.4, 2.1, "+z", 3.2, 6.4, 1.6)
	P.cabinet(r, -12.8, 2.1, "+z", 3.2, 6.4, 1.6)

	-- notices, directory, posters
	P.restrictedSign(r, "LEVEL 3 CONTAINMENT BREACH\nEVACUATE IMMEDIATELY", -24, 9, 16, 6, 3, "+x")
	P.sign(r, "VISITOR DIRECTORY\nSECURITY ........ L1\nBIOLOGICAL RES. .. L2\nMEDICAL / RECOVERY L2\nSTORAGE B ........ L2\nMAINTENANCE ...... L2\nCONTAINMENT ... RESTRICTED",
		24, 9, 14, 7, 5.2, "-x", PAL.blueDark, PAL.offwhite, { font = Enum.Font.Code })
	P.poster(r, -24, 8, 20, "+x", 1)
	P.poster(r, -24, 8, 23, "+x", 5)
	P.extinguisher(r, -23.4, 12, "+x")
	P.extinguisher(r, 23.4, 30, "-x")
	vending(r, -22.6, 30, "+x", C(150, 40, 40))
	vending(r, -22.6, 26.2, "+x", C(40, 90, 150))
	P.bench(r, 12, 22, "+z", 8, false)
	P.bench(r, 14, 27, "+z", 7, true)
	P.cctv(r, -23.7, 14.5, 4, "+x")
	P.cctv(r, 23.7, 14.5, 32, "-x", "dead")

	-- story: people left in a hurry, someone didn't make it to the door
	P.papers(r, -6, 22, 8, 16)
	P.papers(r, 6, 12, 6, 10)
	P.papers(r, -15, 12, 6, 12)
	P.papers(r, 16, 25, 5, 8)
	P.drag(r, 1.5, 5, 2.4, 32)
	P.blood(r, 2.2, 32.5, 3)
	P.bloodWall(r, -1.5, 7.3, 34.5, "-z", 3)
	P.bloodWall(r, 1.8, 5.8, 34.5, "-z", 2.5)
	P.bloodWall(r, 3.4, 8.1, 34.5, "-z", 3.2)
	P.stain(r, -5, 25, 6, 4, 0.3)
	P.stain(r, 12, 10, 5, 3, 1.1)
	P.puddle(r, -2, 29, 3.5)
	emitter(r, 0, 9, 18, "dust", { size = Vector3.new(40, 10, 28), rate = 4 })
end

-- =============================================================================
-- SECURITY CHECKPOINT  (clean, militarised, strong light with red accents)
-- =============================================================================
do
	local r = newRoom({ name = "Security", x0 = -15, x1 = 15, z0 = -24, z1 = 0, h = 12,
		floor = { mat = M.Concrete, color = C(124, 126, 124) }, wall = WALL.sec, damage = 0.3 })
	dropCeiling(r, r.h - 1.0, 0.05, C(168, 172, 170))
	local y = r.h - 1.15
	for _, z in ipairs({ -4, -12, -19 }) do
		for _, x in ipairs({ -8, 8 }) do
			lampStrip(r, x, y, z, "x", 7, C(250, 252, 255), 1.7, 26, { flicker = (x == 8 and z == -12) and 0.6 or nil, dead = (x == -8 and z == -19) })
		end
	end
	lampRed(r, -6.5, 8.8, -23, "+z")
	lampRed(r, 6.5, 8.8, -23, "+z")

	-- checkpoint lanes
	P.detector(r, -4, -5, "+z", true)
	P.detector(r, 4, -5, "+z", false)
	P.jersey(r, -10.5, -5, "+z", 7)
	P.jersey(r, 10.5, -5, "+z", 7)
	P.lineFloor(r, -6.1, -5.9, -9, -1)
	P.lineFloor(r, 5.9, 6.1, -9, -1)
	P.lineFloor(r, -0.1, 0.1, -9, -1)
	P.lineFloor(r, -14, 14, -9.2, -8.9)

	-- control desk + CCTV wall
	P.console(r, 7, -13, "+z", 7, { "on", "broken", "on" })
	P.chair(r, 9, -10.4, "+z", true)
	bx(r.props, "CCTVDesk", 12, 14, 0, 3.4, -22.5, -14.5, M.Metal, PAL.steelDark)
	local states = { "on", "on", "broken", "off", "on", "on" }
	local k = 1
	for _, yr in ipairs({ 4.6, 7.0 }) do
		for _, zc in ipairs({ -21, -18.2, -15.4 }) do
			P.monitor(r, 13.8, yr, zc, "-x", states[k])
			k += 1
		end
	end
	P.infoSign(r, "CCTV CONTROL", 14, 10.2, -18.2, 6, 1, "-x")

	-- armoury cage (uncommon chest spot) + lockers
	cageBox(r, -14, -7, -22, -15, 7.5, { e = { -20, -17 } })
	P.shelf(r, -12.6, -22.5, -math.pi / 2, 1, 2, 0.6)
	P.cabinet(r, -9.2, -21.6, "+z", 2.4, 6.2, 2.2)
	P.restrictedSign(r, "SECURITY EQUIPMENT\nAUTHORIZED ONLY", -14, 8.5, -18.5, 5, 1.8, "+x")
	P.lockers(r, -14, -3, "+x", 5)
	P.poster(r, -14, 8.6, -9, "+x", 4)

	-- last stand at the blast door
	P.sandbag(r, 5, -19.5, "+z", 4)
	P.hazardFloor(r, -4, 4, -22.8, -20.6)
	P.blood(r, 9, -10, 2.5)
	P.drag(r, 8, -11.5, 3, -19)
	P.papers(r, 0, -14, 7, 14)
	P.papers(r, -4, -3, 4, 6)
	P.cctv(r, -13.6, 10.5, -2, "+x")
	P.cctv(r, 13.6, 10.5, -2, "-x", "dead")
	P.extinguisher(r, 13.4, -2.6, "-x")
	P.exitSign(r, 0, 10.4, -22.9, "+z", "EXIT")
	P.stain(r, -3, -15, 5, 3, 0.4)
end

-- =============================================================================
-- MAIN CORRIDOR A  (spine of the facility: tiled, long, lights failing northward)
-- =============================================================================
do
	local r = newRoom({ name = "MainCorridor", x0 = -6, x1 = 6, z0 = -84, z1 = -24, h = 11,
		floor = { mat = M.Concrete, color = C(94, 94, 90) }, wall = WALL.corr, damage = 0.45 })
	dropCeiling(r, r.h - 1.2, 0.09, C(172, 174, 168))
	floorZone(r, "Walkway", -2.2, 2.2, -83, -25, M.Rubber, C(66, 70, 68))
	floorZone(r, "WalkEdge", -2.4, -2.2, -83, -25, M.SmoothPlastic, PAL.yellow)
	floorZone(r, "WalkEdge", 2.2, 2.4, -83, -25, M.SmoothPlastic, PAL.yellow)
	local y = r.h - 1.35
	for i, z in ipairs({ -30, -40, -50, -60, -70, -80 }) do
		lampStrip(r, 0, y, z, "z", 6, COLD, 1.5, 24, { flicker = (i == 3) and 0.5 or (i == 5 and 0.9 or nil), dead = (i == 4) })
	end
	P.pipeRun(r, "z", -83, -25, 4.3, 8.6, 0.7, PAL.steelLight, { valves = true })
	P.pipeRun(r, "z", -83, -25, 4.3, 7.3, 0.4, PAL.rust)
	P.cableTray(r, "z", -83, -25, -4.2, 8.9, 1.6)
	P.vent(r, -4.95, 6.2, -58, "+x", 2.4, 1.4)
	P.vent(r, 4.95, 6.2, -31, "-x", 2.4, 1.4)
	P.panel(r, 4.9, 3.0, -48, "-x", 1.8, 3.0, "open")
	P.panel(r, -4.9, 3.0, -64, "+x", 1.8, 3.0)
	P.fan(r, 4.95, 6.6, -66, "-x", 2.4)

	-- benches, carts, extinguishers: a lived-in hall
	P.bench(r, -3.9, -28, "+x", 6, false)
	P.bench(r, 3.9, -47, "-x", 6, true)
	P.cart(r, 3.4, -61.5, "+z", true)
	P.cart(r, -3.6, -80.5, "+x", false)
	P.extinguisher(r, 4.5, -33, "-x")
	P.extinguisher(r, -4.5, -78, "+x")
	P.poster(r, -5, 7.4, -30, "+x", 2)
	P.poster(r, 5, 7.4, -60, "-x", 1)
	P.infoSign(r, "SECTOR C  -  LEVEL 2", -5, 9.2, -39, 5.5, 1.1, "+x")
	P.exitSign(r, 0, 9.4, -26, "+z", "EXIT")
	P.cctv(r, -4.9, 9.6, -30, "+x")
	P.cctv(r, 4.9, 9.6, -70, "-x", "dead")
	lampRed(r, 4.9, 8.0, -80, "-x")

	-- the deeper north end is in worse shape
	P.rubble(r, -3.5, -60, 2.5, 7)
	P.rubble(r, 3.5, -57, 2.0, 6)
	P.rubble(r, -3, -81, 1.8, 6, true)
	P.drag(r, 2.2, -68, 0, -82)
	P.blood(r, 0.5, -81, 3)
	P.papers(r, 0, -45, 4, 14)
	P.papers(r, 0, -72, 4, 10)
	P.puddle(r, -1, -64, 3.2)
	P.puddle(r, 2, -38, 2.4)
	P.stain(r, -2, -54, 4, 5, 0.2)
	P.drain(r, 0, -48)
	emitter(r, -2.5, 9.0, -57, "drip", {})
	emitter(r, 1, 9.0, -63, "drip", { rate = 2 })
end


-- glass wall run with gaps: gaps = { {a0,a1}, ... }
local function glassRun(r, axis, f, a0, a1, h, gaps, tint)
	local cuts = {}
	for _, g in ipairs(gaps or {}) do cuts[#cuts + 1] = g end
	table.sort(cuts, function(p, q) return p[1] < q[1] end)
	local par = r.props
	local function seg(s0, s1)
		slab(par, "GlassKick", axis, s0, s1, 0, 0.8, f - 0.2, f + 0.2, M.Metal, PAL.steelDark)
		slab(par, "GlassPane", axis, s0, s1, 0.8, h - 0.5, f - 0.07, f + 0.07, M.Glass, tint or C(170, 205, 205), { tr = 0.72, refl = 0.08, shadow = false })
		slab(par, "GlassTop", axis, s0, s1, h - 0.5, h, f - 0.2, f + 0.2, M.Metal, PAL.steelDark, { shadow = false })
		local a = s0
		while a <= s1 + 0.01 do
			slab(par, "GlassPost", axis, a - 0.15, a + 0.15, 0, h, f - 0.2, f + 0.2, M.Metal, PAL.steelDark, { shadow = false })
			a += 6.5
		end
	end
	local cur = a0
	for _, g in ipairs(cuts) do
		if g[1] > cur then seg(cur, g[1]) end
		slab(par, "GlassHeader", axis, g[1], g[2], 7.4, h, f - 0.2, f + 0.2, M.Metal, PAL.steelDark, { shadow = false })
		slab(par, "GlassPost", axis, g[1] - 0.15, g[1] + 0.15, 0, h, f - 0.2, f + 0.2, M.Metal, PAL.steelDark, { shadow = false })
		slab(par, "GlassPost", axis, g[2] - 0.15, g[2] + 0.15, 0, h, f - 0.2, f + 0.2, M.Metal, PAL.steelDark, { shadow = false })
		cur = g[2]
	end
	if cur < a1 then seg(cur, a1) end
end

-- =============================================================================
-- BIOLOGICAL RESEARCH LAB  (hero: cold light, glass containment cell, failed experiment)
-- =============================================================================
do
	local r = newRoom({ name = "ResearchLab", x0 = -46, x1 = -6, z0 = -54, z1 = -24, h = 14,
		floor = { mat = M.Concrete, color = C(150, 160, 162) }, wall = WALL.lab, damage = 0.35 })
	dropCeiling(r, r.h - 1.2, 0.07, C(180, 188, 190))
	floorZone(r, "FloorInlay", -44.9, -7.1, -26.2, -25.1, M.SmoothPlastic, C(120, 134, 140))
	P.lineFloor(r, -44.9, -7.1, -39.15, -38.85, PAL.cyan)
	P.hazardFloor(r, -43.5, -31.5, -33.2, -32.2)

	-- cold lighting; one bank dead, one stuttering
	local y = r.h - 1.35
	for _, z in ipairs({ -47, -39, -31 }) do
		for _, x in ipairs({ -39, -25, -13 }) do
			if not (x == -25 and z == -39) then
				lampStrip(r, x, y, z, "x", 8, COLD, 1.5, 26, { flicker = (x == -39 and z == -31) and 0.7 or nil, dead = (x == -13 and z == -47) })
			end
		end
	end
	lampWall(r, -44.9, 8, -52, "+x", PAL.cyan, 0.7, 14, { flicker = 0.3 })
	lampWall(r, -7.1, 8, -50, "-x", PAL.cyan, 0.6, 12)

	-- landmark: glass containment cell with the failed specimen tank
	glassRun(r, "x", -47, -44, -31, 8, nil)
	glassRun(r, "x", -34, -44, -31, 8, nil)
	glassRun(r, "z", -44, -47, -34, 8, nil)
	glassRun(r, "z", -31, -47, -34, 8, { { -43, -39 }, { -37.2, -34 } }) -- door + shattered section
	P.tank(r, -37.5, -40.5, 5.2, 9, C(90, 230, 150), "cracked", true)
	glow(r, -37.5, 4, -40.5, C(90, 240, 160), 1.3, 20)
	P.panel(r, -44.9, 3, -43, "+x", 2, 3, "open")
	P.gurney(r, -41, -36.5, "+z", true)
	P.console(r, -42.6, -45.8, "+z", 3, { "broken" })
	P.blood(r, -40, -38, 3.5)
	P.blood(r, -33, -36, 2.5)
	P.shards(r, -30.2, -36, 4, 14)
	P.claw(r, -43.9, 3.2, -40, "+x", 4)
	P.restrictedSign(r, "CONTAINMENT CELL 04\nSPECIMEN 07", -31, 9.2, -41, 5.5, 1.6, "+x")
	emitter(r, -37.5, 12.2, -40.5, "spark", { every = 5, dir = NID.Bottom })
	emitter(r, -34, 12.0, -43, "drip", {})
	P.rubble(r, -37, -40, 3.8, 8)

	-- behind the cell: a storage nook, rare chest spot
	P.shelf(r, -44.4, -52.4, 0, 1, 2, 0.5)
	P.crate(r, -33, 0, -51.8, 2.4, 2.4, 2.4, 0.2, "bio")
	P.crate(r, -33, 2.4, -51.8, 2.2, 1.8, 2.2, 0.1, "bio")
	P.sign(r, "BIOLOGICAL RESEARCH\nSECTOR C", -38, 10.5, -53, 12, 2.4, "+z", PAL.blueDark, PAL.offwhite)
	local hz = bx(r.props, "HazardBand", -45, -31, 6.8, 7.5, -53.2, -53, M.SmoothPlastic, PAL.yellow, DECO)
	hazardFace(hz, NID.Back)

	-- work islands with different purposes
	P.labTable(r, -26, -47, "+z", 10, "chem")
	P.labTable(r, -26, -31, "+z", 10, "bio")
	P.labTable(r, -43, -26.5, "+z", 12, "elec")
	P.labTable(r, -28, -26.5, "+z", 10, "chem")
	P.fumeHood(r, -19, -51.5, "+z")
	P.fumeHood(r, -11.5, -51.5, "+z")
	P.chair(r, -21, -44.6, "-z", true)
	P.chair(r, -15, -33.5, "+z", false)
	P.cabinet(r, -10, -25.9, "-z", 3.2, 6.2, 1.6)
	P.whiteboard(r, -36, 7, -25, 7, 3.6, "-z", "SPECIMEN 07\nCONTAINMENT FAILURE\nT+14:32  -  DO NOT OPEN CELL 04")
	P.whiteboard(r, -20, 7, -25, 5, 3.6, "-z", "SEQ-44 / SEQ-45\nRESULTS UNSTABLE\nREQUEST EVAC")
	P.infoSign(r, "PPE\nREQUIRED", -7, 7.2, -43.4, 2.4, 1.6, "-x")
	P.poster(r, -14, 8, -25, "-z", 3)
	P.extinguisher(r, -7.4, -44.2, "-x")
	P.cctv(r, -44.7, 11.4, -30, "+x")
	P.cctv(r, -7.3, 11.4, -50, "-x", "dead")
	P.exitSign(r, -27, 12.4, -53, "+z", "EXIT")

	-- mess
	P.papers(r, -24, -39, 9, 22)
	P.papers(r, -14, -44, 5, 10)
	P.blood(r, -20, -36, 2.5)
	P.drag(r, -34, -41, -9.5, -40)
	P.puddle(r, -29, -40, 3.2)
	P.puddle(r, -12, -35, 2.2)
	P.stain(r, -20, -30, 6, 4, 0.5)
	P.drain(r, -20, -39)
	P.drain(r, -34, -29)
	emitter(r, -26, 8, -39, "dust", { size = Vector3.new(24, 8, 14), rate = 3 })
end

-- =============================================================================
-- MEDICAL / RECOVERY WARD  (tiled, collapsed ceiling, unsettling)
-- =============================================================================
do
	local r = newRoom({ name = "Medical", x0 = 6, x1 = 46, z0 = -54, z1 = -24, h = 12,
		floor = { mat = M.CeramicTiles, color = C(150, 168, 160) }, wall = WALL.med, damage = 0.55 })
	dropCeiling(r, r.h - 1.0, 0.16, C(172, 180, 174))
	P.lineFloor(r, 7, 45, -39.15, -38.85, PAL.green)
	local y = r.h - 1.15
	local MED = C(206, 236, 220)
	lampStrip(r, 14, y, -39, "x", 6, MED, 1.4, 22, {})
	lampStrip(r, 26, y, -46, "x", 6, MED, 1.4, 22, { flicker = 0.4 })
	lampStrip(r, 26, y, -32, "x", 6, MED, 1.4, 22, {})
	lampStrip(r, 38, y, -46, "x", 6, MED, 1.4, 22, { dead = true })
	lampStrip(r, 38, y, -32, "x", 6, MED, 1.4, 22, { flicker = 0.9 })
	lampStrip(r, 13, y, -48, "x", 5, MED, 1.2, 16, {})
	lampStrip(r, 13, y, -30, "x", 5, C(255, 170, 150), 0.9, 14, { flicker = 0.8 })

	-- interior partitions: treatment room (NW), observation room (SW), open aisle between
	partWall(r, "x", -43, 7, 19, r.h, { { 12, 17 } }, M.Plaster, C(128, 158, 140), { windows = {} })
	partWall(r, "z", 19, -53, -43, r.h, nil, M.Plaster, C(128, 158, 140), { windows = { { -50, -46, 3, 8 } } })
	partWall(r, "x", -35, 7, 19, r.h, { { 9, 13 } }, M.Plaster, C(128, 158, 140), { windows = { { 15, 18, 3, 8 } } })
	partWall(r, "z", 19, -35, -25, r.h, nil, M.Plaster, C(128, 158, 140), { windows = { { -31, -28, 3, 8 } } })

	-- treatment room
	P.bed(r, 15, -49, "+z", "stained")
	P.ivStand(r, 12, -50)
	P.cabinetMed(r, 7, 3.4, -52, "+x", 4, 4.6)
	P.cabinetMed(r, 7, 3.4, -46, "+x", 4, 4.6)
	P.blood(r, 14, -46, 3.2)
	P.sign(r, "TREATMENT  2", 14.5, 9, -43.45, 4.5, 1.1, "-z", PAL.blueDark, PAL.offwhite)

	-- observation room: straps, scratches, a camera that still watches
	P.bed(r, 13, -29.5, "+z", "straps")
	P.claw(r, 7.5, 4.2, -28, "+x", 5)
	P.claw(r, 7.5, 3.8, -32, "+x", 4)
	P.cctv(r, 18.2, 10.2, -26, "-x")
	P.sign(r, "OBSERVATION  3", 11, 9, -34.55, 4.5, 1.1, "+z", PAL.blueDark, PAL.offwhite)
	P.blood(r, 10, -28, 2.6)
	lampRed(r, 7.4, 8.6, -26.5, "+x", { bright = 1.4, range = 12 })

	-- ward: beds, curtains, drips
	for _, x in ipairs({ 22.5, 37, 42 }) do P.bed(r, x, -48.8, "+z", (x == 37) and "stained" or nil) end
	for _, x in ipairs({ 22.5, 28, 34, 40 }) do P.bed(r, x, -28.8, "-z", (x == 28) and "stained" or nil) end
	P.curtain(r, 25.2, 0.3, -45, "+x", 6, 7)
	P.curtain(r, 39.5, 0.3, -45, "+x", 6, 7)
	P.curtain(r, 31, 0.3, -25.6, "+x", 6.5, 7)
	P.ivStand(r, 25, -47)
	P.ivStand(r, 39.7, -47.5)
	P.ivStand(r, 31, -30)
	P.gurney(r, 44, -37, "+x", true)
	P.cabinetMed(r, 45, 3.4, -41, "-x", 5, 4.6)
	P.cabinetMed(r, 45, 3.4, -33, "-x", 5, 4.6)
	P.infoSign(r, "RECOVERY WARD  B", 7, 10.0, -39, 5, 1.1, "+x")
	P.greenSign(r, "EXIT  >>", 45, 9, -45, 5, 1.1, "-x")
	P.poster(r, 35, 8, -53, "+z", 2)
	P.poster(r, 35, 8, -25, "-z", 6)
	P.exitSign(r, 31.5, 10.4, -53, "+z", "EXIT")

	-- the ceiling came down over the aisle
	P.rubble(r, 30, -38, 4.5, 18)
	for i = 1, 4 do
		cb(r.story, "CollapsedPanel", 30 + rand(-3, 3), 9.6 - i * 0.3, -38 + rand(-3, 3), 4.2, 0.2, 3.4, rand(0, 3), M.Fabric, C(150, 156, 150), { deco = true })
	end
	emitter(r, 30, 10.2, -38, "spark", { every = 8, dir = NID.Bottom })
	emitter(r, 33, 10.4, -37, "drip", { rate = 2 })
	P.papers(r, 22, -39, 7, 18)
	P.papers(r, 40, -39, 4, 8)
	P.blood(r, 36, -40, 3)
	P.drag(r, 40, -43, 24, -39)
	P.puddle(r, 31, -36, 3)
	P.stain(r, 26, -42, 5, 3, 0.2)
	P.drain(r, 31, -39)
	P.cctv(r, 44.7, 10.5, -26, "-x", "dead")
	emitter(r, 26, 6, -39, "dust", { size = Vector3.new(36, 6, 12), rate = 3 })
end


-- =============================================================================
-- STORAGE B  (packed warehouse, tall ceiling, overhead crane, loading dock)
-- =============================================================================
do
	local r = newRoom({ name = "StorageB", x0 = -46, x1 = -6, z0 = -84, z1 = -54, h = 20,
		floor = { mat = M.Concrete, color = C(92, 90, 86) }, wall = WALL.storage, damage = 0.5 })
	beams(r, "z", 10, 2.2)
	-- floor: worn concrete with painted lanes
	for _, x in ipairs({ -39, -31 }) do P.lineFloor(r, x - 0.15, x + 0.15, -82, -58, PAL.yellow) end
	P.lineFloor(r, -22.1, -21.9, -82, -56, PAL.yellow)
	P.lineFloor(r, -44, -8, -61.1, -60.9, PAL.yellow)
	P.hazardFloor(r, -25, -13, -83, -81.6) -- loading dock threshold

	-- warm caged lamps, many of them dying
	local y = r.h - 2.4
	local n = 0
	for _, z in ipairs({ -78, -66 }) do
		for _, x in ipairs({ -39, -29, -19, -11 }) do
			n += 1
			lampCage(r, x, y, z, WARM, 2.2, 32, { dead = (n % 5 == 0), flicker = (n % 4 == 0) and 0.8 or nil })
		end
	end

	-- overhead crane (landmark you can see from the corridor)
	for _, x in ipairs({ -42, -10 }) do bx(r.props, "CraneRail", x - 0.5, x + 0.5, 16.2, 17.2, -83, -55, M.Metal, PAL.yellow, { cc = false }) end
	bx(r.props, "CraneBridge", -43, -9, 15.2, 16.2, -71, -69, M.Metal, PAL.yellow, { cc = false })
	bx(r.props, "CraneTrolley", -27.5, -24.5, 14.4, 15.2, -71.5, -68.5, M.Metal, PAL.steelDark, { cc = false })
	cylY(r.props, "CraneChain", -26, 8.2, 14.4, -70, 0.35, M.Metal, PAL.steelDark, DECO)
	bx(r.props, "CraneHookBlock", -27, -25, 7.2, 8.2, -71, -69, M.Metal, PAL.yellow, { cc = false })
	P.hazardSign(r, "OVERHEAD CRANE\nWATCH LOADS", -45, 9, -70, 7, 1.8, "+x")

	-- shelving aisles
	P.shelf(r, -43, -82, -math.pi / 2, 4, 4, 0.9)
	P.shelf(r, -35, -82, -math.pi / 2, 4, 4, 0.9)
	P.shelf(r, -27, -82, -math.pi / 2, 3, 4, 0.9)
	P.hazardSign(r, "MAX LOAD\n500 KG / TIER", -39, 6.0, -58.3, 4.5, 1.4, "-z")

	-- freight zone, east side (keeps the door lane clear)
	P.crate(r, -9.8, 0, -81.5, 3.2, 3.2, 3.2, 0.2, "wood")
	P.crate(r, -9.8, 3.2, -81.5, 2.8, 2.4, 2.8, 0.5, "wood")
	P.crate(r, -14, 0, -81.5, 3.2, 2.8, 3.2, -0.1, "metal")
	P.crate(r, -22, 0, -79.5, 3, 2.6, 3, 0.3, "bio")
	P.pallet(r, -18, -80.5, 0.1)
	P.crate(r, -18, 0.75, -80.5, 2.6, 2.6, 2.6, 0.1, "cardboard")
	P.barrel(r, -8.6, -78.6)
	P.barrel(r, -8.6, -76.8, PAL.yellow)
	P.crate(r, -9.5, 0, -57.2, 4, 3.4, 3.2, 0.05, "wood")
	P.crate(r, -14, 0, -57.2, 3.2, 3.0, 3.0, 0.2, "bio")
	P.crate(r, -14, 3.0, -57.2, 2.6, 2.0, 2.6, -0.2, "wood")
	P.barrel(r, -18, -56.6)
	P.pallet(r, -40, -59.5, 0)
	P.forklift(r, -16, -63, math.pi)
	-- spilled barrels
	cylX(r.props, "BarrelLying", -20.4, -17.0, 1.1, -58.8, 2.2, M.Metal, PAL.rustDark)
	disc(r.story, "ToxicSpill", -16, 0.06, -58.8, 5.4, 0.05, M.Neon, C(60, 140, 50), { deco = true, tr = 0.6 })
	glow(r, -16, 1.2, -58.8, C(80, 220, 70), 0.7, 10)

	-- loading dock shutter (sealed) in the north wall
	bx(r.props, "DockFrame", -26, -12, 0, 11.2, -83, -82.6, M.Metal, PAL.steelDark)
	bx(r.props, "DockShutter", -25, -13, 0, 10.2, -82.6, -82.3, M.CorrodedMetal, jitter(PAL.steel, 0.1))
	for i = 1, 9 do bx(r.props, "DockSlat", -25, -13, i * 1.1 - 0.1, i * 1.1, -82.3, -82.2, M.Metal, PAL.steelDark, DECO) end
	P.hazardSign(r, "LOADING DOCK B\nKEEP CLEAR", -19, 12.6, -83, 9, 1.8, "+z")
	P.cctv(r, -44.7, 14, -56, "+x")
	P.cctv(r, -7.3, 14, -80, "-x", "dead")
	P.panel(r, -7.1, 3.2, -64, "-x", 2.0, 3.2, "open")
	P.extinguisher(r, -7.4, -73, "-x")
	P.exitSign(r, -27, 11.6, -55.1, "-z", "EXIT")

	-- mess
	P.papers(r, -30, -62, 5, 8)
	P.rubble(r, -38, -60, 3, 6)
	P.stain(r, -28, -70, 6, 5, 0.3)
	P.stain(r, -14, -70, 5, 4, 1.0)
	P.puddle(r, -33, -66, 3.4)
	P.drain(r, -22, -69)
	emitter(r, -33, 14, -70, "drip", { rate = 2 })
	emitter(r, -26, 8, -70, "dust", { size = Vector3.new(34, 14, 22), rate = 5 })
end

-- =============================================================================
-- MAINTENANCE / POWER  (dark, warm, reactor landmark, catwalk)
-- =============================================================================
do
	local r = newRoom({ name = "Maintenance", x0 = 6, x1 = 46, z0 = -84, z1 = -54, h = 18,
		floor = { mat = M.DiamondPlate, color = C(66, 68, 68) }, wall = WALL.maint, damage = 0.7 })
	beams(r, "x", 11, 1.8, PAL.rustDark)
	floorZone(r, "ConcretePatch", 7, 17, -83, -55, M.Concrete, C(70, 68, 62))
	P.lineFloor(r, 7, 45, -62.1, -61.9, PAL.yellow)

	-- the reactor: orange glow is the main light source in the room
	P.reactor(r, 26, -69, 10, 15)
	for _, a in ipairs({ 0, 1.57, 3.14, 4.71 }) do
		local px, pz = 26 + math.cos(a) * 9.4, -69 + math.sin(a) * 9.4
		cylY(r.props, "ReactorBollard", px, 0, 3, pz, 1.2, M.Metal, PAL.yellow)
	end
	P.hazardSign(r, "REACTOR  COOLING LOOP B\nHIGH VOLTAGE", 26, 11, -82.9, 10, 2.2, "+z")
	local y = r.h - 2.2
	lampCage(r, 12, y, -62, WARM, 1.6, 26, { dead = true })
	lampCage(r, 14, y, -76, WARM, 1.6, 26, { flicker = 0.9 })
	lampCage(r, 38, y, -62, WARM, 1.6, 26, {})
	lampCage(r, 36, y, -78, WARM, 1.4, 24, { flicker = 0.5 })
	lampRed(r, 7.3, 12, -60, "+x")
	lampRed(r, 44.7, 12, -60, "-x")

	-- upper level catwalk + stairs
	P.catwalk(r, 38, 45, -83, -65.6, 6, { w = true, n = true, e = true })
	P.stairs(r, 41.5, -55.2, math.pi, 3.5, 0.75, 8, 1.3)
	P.crate(r, 42.5, 6, -80, 2.4, 2, 2.4, 0.3, "metal")
	P.panel(r, 38.1, 7.6, -74, "+x", 2, 3, "open")

	-- generators + tool storage
	P.generator(r, 12, -80.4, "+z", 6, 4, 5)
	P.generator(r, 19, -80.4, "+z", 6, 4, 5)
	P.lockers(r, 7, -56, "+x", 5)
	P.cabinet(r, 8.4, -78, "+x", 3.4, 6, 1.8, jitter(PAL.rust, 0.1))
	P.cabinet(r, 8.4, -74.8, "+x", 3.0, 6, 1.8, jitter(PAL.steel, 0.1))
	P.cart(r, 12.5, -59, "+z", true)
	P.cart(r, 19.5, -57.6, "+z", false)
	P.crate(r, 41.5, 0, -75, 2.6, 2.2, 2.6, 0.6, "metal")
	P.barrel(r, 44, -58)
	P.barrel(r, 44, -60.4)
	P.barrel(r, 42.5, -59.2, PAL.yellow)

	-- infrastructure overhead and on the walls
	P.pipeRun(r, "x", 7, 45, -60, 15.5, 1.4, PAL.rust, { valves = true })
	P.pipeRun(r, "x", 7, 45, -77.5, 14.5, 1.2, PAL.steelLight, { valves = true })
	P.pipeRun(r, "z", -83, -55, 9, 13.8, 1.0, PAL.rust)
	P.pipeRun(r, "z", -83, -55, 43.5, 14.2, 0.9, PAL.rustDark)
	P.duct(r, "z", -83, -55, 15, 14.5, 3, 2.4)
	P.cableTray(r, "x", 7, 45, -66, 13.6, 2)
	P.cableTray(r, "z", -83, -55, 33.5, 12.9, 1.6)
	P.vent(r, 45, 6.5, -58, "-x", 2.6, 1.6)
	P.fan(r, 7.1, 10, -70, "+x", 3)
	P.fan(r, 45, 10, -66, "-x", 3)
	P.panel(r, 14, 3.3, -83, "+z", 2.2, 3.6, "open")
	P.panel(r, 30, 3.3, -83, "+z", 2.2, 3.6)
	P.cctv(r, 7.3, 14, -58, "+x")
	P.exitSign(r, 29, 12.4, -55.1, "-z", "EXIT")

	-- steam and water
	emitter(r, 10, 0.4, -57.2, "steam", { dir = NID.Top, rate = 8 })
	emitter(r, 40.5, 0.4, -72, "steam", { dir = NID.Top, rate = 6 })
	cylY(r.props, "SteamVent", 10, 0, 0.6, -57.2, 1.6, M.Metal, PAL.steelDark, DECO)
	cylY(r.props, "SteamVent", 40.5, 0, 0.6, -72, 1.6, M.Metal, PAL.steelDark, DECO)
	emitter(r, 21, 15.0, -60, "drip", { rate = 2 })
	P.puddle(r, 21, -57, 4)
	P.puddle(r, 35, -71, 3.2)
	P.stain(r, 24, -80, 10, 3, 0.1)
	P.rubble(r, 38, -58, 3, 8)
	P.papers(r, 14, -66, 4, 6)
	P.drain(r, 21, -66)
	emitter(r, 26, 8, -69, "dust", { size = Vector3.new(36, 14, 24), rate = 4 })
end

-- =============================================================================
-- SERVICE HALLWAY (narrow, pipe-choked, optional route toward the restricted wing)
-- =============================================================================
do
	local r = newRoom({ name = "ServiceHallA", x0 = 30, x1 = 38, z0 = -110, z1 = -84, h = 8,
		floor = { mat = M.DiamondPlate, color = C(62, 64, 62) }, wall = WALL.service, damage = 0.8 })
	P.pipeRun(r, "z", -109, -85, 31.9, 5.9, 0.9, PAL.rust, { valves = true })
	P.pipeRun(r, "z", -109, -85, 36.1, 6.4, 0.7, PAL.steelLight)
	P.pipeRun(r, "z", -109, -85, 36.1, 4.4, 0.5, PAL.rustDark)
	P.cableTray(r, "z", -109, -85, 34, 7.3, 1.4)
	lampCage(r, 34, 7.3, -90, WARM, 1.2, 14, {})
	lampCage(r, 34, 7.3, -98, WARM, 1.0, 14, { flicker = 0.9 })
	lampCage(r, 34, 7.3, -106, WARM, 1.0, 14, { dead = true })
	lampRed(r, 36.7, 5.2, -100, "-x", { bright = 1.2, range = 12 })
	P.vent(r, 31.05, 3, -95, "+x", 2, 1.2)
	P.panel(r, 36.9, 3.0, -92, "-x", 1.8, 3.0, "open")
	P.hazardSign(r, "SERVICE HALLWAY\nAUTHORIZED STAFF ONLY", 36.95, 4.6, -97, 4.5, 1.4, "-x")
	P.cart(r, 34.4, -88.2, "-z", true)
	emitter(r, 34, 0.3, -101, "steam", { dir = NID.Top, rate = 5 })
	P.puddle(r, 33, -94, 2.4)
	P.drain(r, 34, -97)
	P.papers(r, 34, -103, 2, 5)
	P.stain(r, 34, -100, 4, 5, 0.1)
	cylY(r.props, "SteamVent", 34, 0, 0.5, -101, 1.4, M.Metal, PAL.steelDark, DECO)
end

do
	local r = newRoom({ name = "ServiceHallB", x0 = 22, x1 = 30, z0 = -110, z1 = -102, h = 8,
		floor = { mat = M.DiamondPlate, color = C(62, 64, 62) }, wall = WALL.service, damage = 0.8 })
	lampRed(r, 26, 6.8, -102.9, "-z")
	lampCage(r, 26, 7.3, -106, WARM, 0.9, 12, { flicker = 0.9 })
	P.pipeRun(r, "x", 23, 29, -109, 5.4, 0.9, PAL.rust, { valves = true })
	P.panel(r, 26, 3.0, -109, "+z", 2.2, 3.0, "open")
	P.restrictedSign(r, "RESTRICTED\nSERVICE ACCESS", 29.95, 5.4, -108.2, 4, 1.6, "-x")
	P.rubble(r, 26, -106, 1.8, 4)
	P.papers(r, 26, -105, 1.5, 4)
	P.blood(r, 25, -105, 1.8)
end


local function hazmat(r, x, z, facing)
	local cf = frame(x, 0, z, facing)
	lp(r.props, "HazmatBody", cf, 0, 3.6, 0, 1.8, 3.2, 1.0, M.Fabric, PAL.orange, DECO)
	lp(r.props, "HazmatLegs", cf, 0, 1.2, 0, 1.5, 2.4, 0.9, M.Fabric, shade(PAL.orange, 0.85), DECO)
	lp(r.props, "HazmatArms", cf, 0, 3.7, 0.1, 2.6, 0.6, 0.6, M.Fabric, PAL.orange, DECO)
	mk(r.props, "HazmatHelmet", Vector3.new(1.2, 1.3, 1.2), cf * CFrame.new(0, 5.6, 0), M.Glass, C(150, 170, 150), { deco = true, tr = 0.4, shape = SHAPE_BALL })
end

-- =============================================================================
-- DECONTAMINATION AIRLOCK  (restricted corridor: tight, red/white, wet)
-- =============================================================================
do
	local r = newRoom({ name = "Decon", x0 = -6, x1 = 6, z0 = -96, z1 = -84, h = 9,
		floor = { mat = M.CeramicTiles, color = C(150, 162, 160) }, wall = WALL.decon, damage = 0.6 })
	floorZone(r, "DrainChannel", -0.5, 0.5, -95, -85, M.Metal, PAL.steelDark)
	P.hazardFloor(r, -4, 4, -87.4, -85.1)
	P.hazardFloor(r, -4, 4, -94.9, -92.6)
	lampStrip(r, 0, r.h - 0.1, -90, "x", 5, C(235, 245, 255), 1.3, 14, { flicker = 0.9 })
	lampRed(r, -4.8, 7.4, -86.5, "+x", { bright = 1.6, range = 14 })
	lampRed(r, 4.8, 7.4, -93.5, "-x", { bright = 1.6, range = 14 })
	-- ceiling spray rail
	P.pipeRun(r, "z", -95, -85, -2.5, 8.2, 0.5, PAL.steelLight)
	P.pipeRun(r, "z", -95, -85, 2.5, 8.2, 0.5, PAL.steelLight)
	for _, z in ipairs({ -93.5, -91, -88.5, -86.2 }) do
		for _, x in ipairs({ -2.5, 2.5 }) do cylY(r.props, "SprayNozzle", x, 7.5, 8.0, z, 0.5, M.Metal, PAL.steelDark, DECO) end
	end
	P.hazardSign(r, "DECONTAMINATION CYCLE\nMANDATORY", -5, 6.2, -90, 6, 2, "+x")
	P.restrictedSign(r, "NO ENTRY\nBIOHAZARD", 5, 6.2, -90, 4, 2, "-x")
	hazmat(r, -4.3, -87, "+x")
	hazmat(r, -4.3, -93, "+x")
	P.drain(r, 0, -90)
	P.drain(r, 0, -87.6)
	P.puddle(r, 2, -89, 3)
	P.puddle(r, -2.4, -92, 2.2)
	P.stain(r, 0, -91, 4, 4, 0.2)
	emitter(r, 0, 8.6, -90, "drip", { rate = 3 })
	emitter(r, 2.5, 0.4, -86.5, "steam", { dir = NID.Top, rate = 5 })
	cylY(r.props, "SteamVent", 2.5, 0, 0.5, -86.5, 1.2, M.Metal, PAL.steelDark, DECO)
	P.blood(r, 1, -94, 2.5)
	P.drag(r, 0.5, -89, 0, -95)
end

-- =============================================================================
-- RESTRICTED CONTAINMENT AREA  (hero: breached chamber, red emergency lighting)
-- =============================================================================
do
	local r = newRoom({ name = "Containment", x0 = -22, x1 = 22, z0 = -136, z1 = -96, h = 26,
		floor = { mat = M.DiamondPlate, color = C(48, 50, 54) }, wall = WALL.restricted, damage = 0.85 })
	beams(r, "x", 10, 2.4, C(40, 40, 44))
	floorZone(r, "ReinforcedPad", -4.2, 4.2, -105, -97, M.Metal, C(36, 38, 42))
	P.hazardFloor(r, -4, 4, -100.2, -97.8)
	P.hazardFloor(r, -4, 4, -134.2, -131.8)

	-- the chamber: shattered cylinder, something big left through the breach
	local cx, cz = 0, -116
	cylY(r.props, "ChamberPlinth", cx, 0, 1.0, cz, 23, M.Metal, C(40, 42, 46))
	disc(r.props, "ChamberHazardRing", cx, 1.03, cz, 22, 0.05, M.SmoothPlastic, PAL.yellow, DECO)
	disc(r.props, "ChamberHazardInner", cx, 1.06, cz, 20.2, 0.05, M.Metal, C(40, 42, 46), DECO)
	cylY(r.props, "ChamberBase", cx, 1.0, 2.2, cz, 15, M.Metal, PAL.steelDark)
	cylY(r.props, "ChamberGlassLow", cx, 2.2, 8, cz, 14, M.Glass, C(190, 215, 215), { tr = 0.78, refl = 0.1, shadow = false })
	cylY(r.props, "ChamberRing", cx, 8, 8.8, cz, 14.6, M.Metal, PAL.steelDark)
	cylY(r.props, "ChamberRing", cx, 15.2, 16, cz, 14.6, M.Metal, PAL.steelDark)
	cylY(r.props, "ChamberGlassHigh", cx, 16, 23, cz, 14, M.Glass, C(190, 215, 215), { tr = 0.8, refl = 0.1, shadow = false })
	cylY(r.props, "ChamberCap", cx, 23, 24.2, cz, 15, M.Metal, PAL.steelDark)
	for i = 0, 3 do -- structural struts holding the broken middle section
		local a = i * math.pi / 2 + 0.4
		cylY(r.props, "ChamberStrut", cx + math.cos(a) * 6.9, 8.8, 15.2, cz + math.sin(a) * 6.9, 0.7, M.Metal, PAL.steel, { shadow = false })
	end
	cylY(r.props, "ChamberCore", cx, 2.2, 23, cz, 2.6, M.Metal, PAL.steelDark, DECO)
	local core = disc(r.props, "ChamberGlowPlate", cx, 2.3, cz, 11, 0.15, M.Neon, C(150, 20, 16), { deco = true, tr = 0.35 })
	addLight("point", core, C(255, 40, 30), 2.6, 38, { shadows = false })
	tag(core, "PulseLight")
	core:SetAttribute("Speed", 0.9)
	for i = 0, 3 do -- coolant lines from the cap to the ceiling
		local a = i * math.pi / 2 + math.pi / 4
		cylY(r.props, "ChamberPipe", cx + math.cos(a) * 5, 24.2, r.h, cz + math.sin(a) * 5, 1.5, M.Metal, PAL.steel, DECO)
	end
	P.shards(r, cx, cz, 12.5, 40)
	P.rubble(r, cx, cz, 11, 12)
	P.blood(r, 9, -113, 4)
	P.blood(r, -9, -123, 3.5)
	P.drag(r, 10, -112, 19, -106)
	P.claw(r, 20.9, 4.6, -112, "-x", 5)
	P.claw(r, 20.9, 4.4, -122, "-x", 4)
	P.restrictedSign(r, "CONTAINMENT AREA\nSUBJECT 07  -  BREACH", 0, 17, -135, 12, 3, "+z")
	emitter(r, cx, 22, cz, "spark", { every = 4, dir = NID.Bottom })
	emitter(r, cx, 0.5, cz, "steam", { size = Vector3.new(10, 0.5, 10), dir = NID.Top, rate = 5 })
	emitter(r, cx, 6, cz, "dust", { size = Vector3.new(30, 14, 30), rate = 6 })

	-- observation gallery (west) overlooking the chamber
	P.catwalk(r, -21, -14, -134, -109, 7, { e = true, n = true })
	P.stairs(r, -17.5, -97.3, math.pi, 3.5, 0.78, 9, 1.3)
	bx(r.props, "GalleryConsole", -21, -19.2, 7, 10.2, -131, -121, M.Metal, PAL.steelDark)
	P.monitor(r, -19.6, 10.2, -129.5, "+x", "on", PAL.red)
	P.monitor(r, -19.6, 10.2, -126.5, "+x", "broken")
	P.monitor(r, -19.6, 10.2, -123.5, "+x", "on")
	P.monitor(r, -19.6, 10.2, -121.6, "+x", "off")
	P.sign(r, "OBSERVATION GALLERY 2\nKEYCARD LEVEL 4", -21, 11.6, -112, 6, 1.6, "+x", PAL.red, PAL.offwhite)
	bx(r.props, "GalleryWindowSill", -21, -20.2, 7, 9.5, -108.8, -108.4, M.Metal, PAL.steelDark, DECO)

	-- pylons, machinery, wall plant
	for _, z in ipairs({ -113, -121 }) do
		cylY(r.props, "Pylon", 15.5, 0, r.h, z, 3.2, M.Metal, C(62, 64, 68))
		cylY(r.props, "PylonBand", 15.5, 9, 10.5, z, 3.5, M.Neon, shade(PAL.red, 0.7), DECO)
		cylY(r.props, "PylonBase", 15.5, 0, 1.2, z, 4.6, M.Concrete, PAL.concreteDark, DECO)
	end
	P.generator(r, 8, -133, "+z", 7, 3.4, 6)
	P.generator(r, 14, -133, "+z", 7, 3.4, 6)
	P.pipeRun(r, "x", -21, 21, -100, 22, 2.0, PAL.steelDark, { valves = true })
	P.pipeRun(r, "x", -21, 21, -133, 21, 1.6, PAL.rustDark)
	P.pipeRun(r, "z", -135, -97, 18, 20, 1.6, PAL.steelDark)
	P.cableTray(r, "x", -21, 21, -104, 19, 2.4)
	P.panel(r, 21, 3.0, -100, "-x", 2.2, 3.6, "open")
	P.panel(r, -20.9, 3.0, -100, "+x", 2.2, 3.6, "open")
	P.crate(r, 18, 0, -99, 3.2, 3, 3.2, 0.4, "metal")
	P.gurney(r, 17, -127, "+z", true)
	P.cart(r, 12, -101, "+z", true)
	-- hanging cables
	for i = 1, 7 do
		cylY(r.story, "HangingCable", rand(-18, 18), r.h - rand(4, 9), r.h, rand(-132, -100), 0.2, M.Rubber, PAL.black, DECO)
	end

	-- lighting: almost none but emergency red; one white tube stuttering over the gallery
	for _, p in ipairs({ { -20.9, -102 }, { -20.9, -132 }, { 20.9, -103 }, { 20.9, -133 } }) do
		lampRed(r, p[1], 14, p[2], p[1] < 0 and "+x" or "-x", { bright = 2.4, range = 30 })
	end
	lampRed(r, -8, 14, -135, "+z", { bright = 2.4, range = 30 })
	lampRed(r, 8, 14, -135, "+z", { bright = 2.4, range = 30 })
	lampStrip(r, -17.5, 24, -121, "z", 8, C(220, 230, 255), 1.4, 26, { flicker = 1.0 })
	lampCage(r, 15.5, 13, -100, C(255, 120, 80), 1.0, 20, { flicker = 0.6 })
	P.cctv(r, -20.7, 14.5, -105, "+x", "dead")
	P.cctv(r, 20.7, 14.5, -130, "-x")
	P.papers(r, 10, -128, 6, 12)
	P.papers(r, -10, -102, 5, 8)
	P.puddle(r, 14, -104, 3.5)
	P.stain(r, -10, -124, 8, 6, 0.4)
end

-- =============================================================================
-- EVACUATION LIFT  (the goal: safe green light after the red)
-- =============================================================================
do
	local r = newRoom({ name = "Extraction", x0 = -8, x1 = 8, z0 = -160, z1 = -136, h = 12,
		floor = { mat = M.Concrete, color = C(104, 106, 102) }, wall = WALL.lift, damage = 0.4 })
	beams(r, "x", 8, 1.4)
	floorZone(r, "PadFrame", -5.5, 5.5, -153.5, -142.5, M.Metal, C(52, 56, 54))
	disc(r.arch, "PadRing", 0, 0.08, -148, 10.6, 0.06, M.Neon, shade(PAL.green, 0.5), DECO)
	disc(r.arch, "PadInner", 0, 0.1, -148, 9.6, 0.06, M.Metal, C(52, 56, 54), DECO)
	P.lineFloor(r, -0.15, 0.15, -141.5, -137, PAL.green)
	P.hazardFloor(r, -4, 4, -139.6, -137.2)
	P.hazardFloor(r, -4, 4, -156.8, -154.6)
	-- lift cabin (open doors), landmark at the end
	bx(r.props, "LiftBack", -3.6, 3.6, 0, 9, -159, -158.4, M.Metal, PAL.steelDark)
	bx(r.props, "LiftSideW", -3.6, -3.2, 0, 9, -159, -153.6, M.Metal, PAL.steelDark)
	bx(r.props, "LiftSideE", 3.2, 3.6, 0, 9, -159, -153.6, M.Metal, PAL.steelDark)
	bx(r.props, "LiftCeiling", -3.6, 3.6, 9, 9.4, -159, -153.6, M.Metal, PAL.steelDark)
	bx(r.props, "LiftFrameHead", -4.8, 4.8, 9.4, 10.6, -159, -153.2, M.Metal, PAL.steelDark)
	bx(r.props, "LiftDoorLeaf", -4.8, -3.6, 0, 9.4, -154.4, -153.6, M.DiamondPlate, shade(PAL.steelDark, 1.2))
	bx(r.props, "LiftDoorLeaf", 3.6, 4.8, 0, 9.4, -154.4, -153.6, M.DiamondPlate, shade(PAL.steelDark, 1.2))
	local lp1 = bx(r.lights, "LiftLightPanel", -2.4, 2.4, 8.9, 9.0, -157.6, -154.6, M.Neon, C(220, 255, 230), DECO)
	addLight("surface", lp1, C(220, 255, 230), 1.6, 22, { shadows = false })
	P.sign(r, "EVACUATION LIFT", 0, 11.2, -153.2, 8, 1.1, "+z", PAL.green, PAL.offwhite, { font = Enum.Font.GothamBlack })
	P.sign(r, "LIFT STANDBY\nHOLD POSITION FOR EXTRACTION", 7, 6.4, -150, 5.5, 2.4, "-x", C(10, 30, 16), PAL.green, { font = Enum.Font.Code, glow = true })
	P.keycardReader(r, 6.9, 4.6, -156, "-x", "X-E", "unlocked")
	-- green = safe
	lampStrip(r, -4, r.h - 1.6, -143, "x", 6, C(190, 255, 205), 1.4, 20, {})
	lampStrip(r, 4, r.h - 1.6, -150, "x", 6, C(190, 255, 205), 1.4, 20, { flicker = 0.3 })
	lampStrip(r, 0, r.h - 1.6, -156, "x", 6, C(190, 255, 205), 1.2, 18, {})
	lampWall(r, -6.9, 7.5, -146, "+x", PAL.green, 0.8, 14)
	lampWall(r, 6.9, 7.5, -142, "-x", PAL.green, 0.8, 14, { noLight = true })
	P.exitSign(r, 0, 10.4, -137.2, "-z", "EXIT")
	-- aftermath: someone fought to hold the lift
	P.crate(r, -6, 0, -141, 2.4, 2.2, 2.4, 0.3, "metal")
	P.crate(r, -5.4, 0, -157.4, 2.6, 2.2, 2.6, 0.5, "wood")
	P.barrel(r, 5.8, -157.6, PAL.blueDark)
	P.bench(r, -6.4, -149, "+x", 5, false)
	P.blood(r, 1.5, -145, 3)
	P.drag(r, 0, -137, 2, -144)
	P.claw(r, -3.5, 4.0, -155.5, "+x", 4)
	P.papers(r, 0, -148, 5, 10)
	P.rubble(r, 5, -140, 2, 5)
	P.cctv(r, -6.7, 10.5, -138, "+x")
	P.extinguisher(r, 6.6, -141, "-x")
	emitter(r, 0, 5, -149, "dust", { size = Vector3.new(12, 8, 18), rate = 3 })
end


-- =============================================================================
--  GAMEPLAY MARKERS  (tagged placeholders you wire to your own systems)
--    Tags:  PlayerSpawn  ChestSpawn  Extraction  EnemySpawn  NPCSpawn  PatrolPoint
--    Chest models carry Attributes  Tier ("Common"|"Uncommon"|"Rare"|"Legendary")  ChestId
-- =============================================================================
local MARK = fold(root, "GameplayMarkers")
local MK = {
	spawns = fold(MARK, "PlayerSpawns"), chests = fold(MARK, "Chests"), extraction = fold(MARK, "Extraction"),
	enemies = fold(MARK, "EnemySpawns"), npcs = fold(MARK, "NPCSpawns"), patrol = fold(MARK, "PatrolRoutes"),
	ambient = fold(MARK, "AmbientZones"),
}
local TIER = {
	Common = { mat = M.WoodPlanks, color = C(112, 84, 54), trim = PAL.steelDark, glow = nil },
	Uncommon = { mat = M.Metal, color = C(62, 96, 70), trim = PAL.steelLight, glow = PAL.green },
	Rare = { mat = M.Metal, color = C(50, 78, 120), trim = PAL.cyan, glow = PAL.cyan },
	Legendary = { mat = M.Metal, color = C(36, 32, 30), trim = C(255, 190, 70), glow = C(255, 190, 70) },
}
local chestCount = 0
local function chest(room, id, x, y0, z, facing, tier)
	local t = TIER[tier]
	chestCount += 1
	local m = Instance.new("Model")
	m.Name = id
	local cf = frame(x, y0, z, facing)
	local body = lp(m, "Body", cf, 0, 0.9, 0, 3.2, 1.8, 2.2, t.mat, t.color)
	lp(m, "Lid", cf, 0, 2.15, 0, 3.3, 0.7, 2.3, t.mat, shade(t.color, 1.12))
	lp(m, "LidTop", cf, 0, 2.62, 0, 3.0, 0.3, 2.0, t.mat, shade(t.color, 1.05), DECO)
	for _, ox in ipairs({ -1.1, 1.1 }) do
		lp(m, "Band", cf, ox, 1.3, 0, 0.3, 2.4, 2.35, M.Metal, t.trim == PAL.cyan and PAL.steelDark or t.trim, DECO)
	end
	local latch = lp(m, "Latch", cf, 0, 1.9, 1.15, 0.6, 0.8, 0.2, t.glow and M.Neon or M.Metal, t.glow or PAL.steelLight, DECO)
	m.PrimaryPart = body
	m:SetAttribute("Tier", tier)
	m:SetAttribute("ChestId", id)
	m.Parent = MK.chests
	tag(m, "ChestSpawn")
	-- a subtle practical light so the chest reads without an arrow
	if t.glow then
		glow(room, x, y0 + 3.2, z, t.glow, tier == "Legendary" and 1.4 or 0.8, tier == "Legendary" and 16 or 11)
	else
		glow(room, x, y0 + 3.2, z, C(255, 214, 160), 0.35, 9)
	end
	return m
end

local function marker(folder, name, x, y, z, t, attrs, size)
	local p = mk(folder, name, size or Vector3.new(3, 1, 3), CFrame.new(x, y, z), M.SmoothPlastic, PAL.cyan, { deco = true, tr = 1 })
	for k, v in pairs(attrs or {}) do p:SetAttribute(k, v) end
	tag(p, t)
	return p
end

-- player spawns (reception, facing the facility)
for i, x in ipairs({ -7, -2.5, 2.5, 7 }) do
	local s = Instance.new("SpawnLocation")
	s.Name = "Spawn" .. i
	s.Anchored = true
	s.CanCollide = false
	s.CanTouch = false
	s.Neutral = true
	s.Duration = 0
	s.Size = Vector3.new(4, 0.4, 4)
	s.CFrame = CFrame.new(x, 0.25, 29.5)
	s.Transparency = 1
	local d = s:FindFirstChildOfClass("Decal")
	if d then d:Destroy() end
	s.Parent = MK.spawns
	tag(s, "PlayerSpawn")
end

-- chests: integrated into their rooms
chest(ROOMS.Reception, "Chest_Reception_Desk", -10.2, 0, 4.6, "+z", "Common")
chest(ROOMS.Security, "Chest_Security_Armoury", -10, 0, -16.6, "+x", "Uncommon")
chest(ROOMS.ResearchLab, "Chest_Lab_BehindCell", -37, 0, -51.7, "+z", "Rare")
chest(ROOMS.Medical, "Chest_Medical_Treatment", 9.2, 0, -51.4, "+x", "Uncommon")
chest(ROOMS.StorageB, "Chest_Storage_Freight", -12.6, 0, -78.4, "-z", "Common")
chest(ROOMS.StorageB, "Chest_Storage_ShelfAisle", -31, 0, -80.8, "+z", "Common")
chest(ROOMS.Maintenance, "Chest_Power_Generator", 24.6, 0, -80.8, "+z", "Uncommon")
chest(ROOMS.Maintenance, "Chest_Power_UnderCatwalk", 43, 0, -80.4, "-x", "Common")
chest(ROOMS.ServiceHallA, "Chest_Service_DeadEnd", 35.4, 0, -107.8, "-z", "Rare")
chest(ROOMS.Containment, "Chest_Containment_Gallery", -17.5, 7, -132.6, "+z", "Legendary")

-- extraction zone: stand on the pad in front of the lift
marker(MK.extraction, "ExtractionZone", 0, 3.5, -148, "Extraction", { Name = "Evacuation Lift" }, Vector3.new(10, 7, 10))

-- enemy spawns (Type is yours to interpret)
for _, e in ipairs({
	{ -9, -131, "Elite", "Containment" }, { 14, -129, "Standard", "Containment" }, { 12, -101, "Standard", "Containment" },
	{ -20, -66, "Standard", "StorageB" }, { -41, -79, "Standard", "StorageB" }, { 36, -62, "Standard", "Maintenance" },
	{ -12, -37, "Standard", "ResearchLab" }, { 38, -38, "Standard", "Medical" }, { 34, -96, "Standard", "ServiceHall" },
	{ 0, -66, "Standard", "MainCorridor" },
}) do
	marker(MK.enemies, "EnemySpawn_" .. e[4], e[1], 0.5, e[2], "EnemySpawn", { Type = e[3], Zone = e[4] })
end
-- friendly NPC spawns
for _, e in ipairs({ { -14, 22, "Reception" }, { 16, 14, "Reception" }, { 4, -17, "Security" } }) do
	marker(MK.npcs, "NPCSpawn_" .. e[3], e[1], 0.5, e[2], "NPCSpawn", { Zone = e[3] })
end
-- patrol routes: ordered points, Attribute Route + Index
local ROUTES = {
	MainSpine = { { 0, -28 }, { 0, -45 }, { 0, -62 }, { 0, -80 }, { 0, -62 }, { 0, -45 } },
	LabLoop = { { -10, -39 }, { -22, -39 }, { -30, -29 }, { -22, -50 }, { -12, -45 } },
	WardLoop = { { 12, -39 }, { 26, -39 }, { 40, -39 }, { 40, -33 }, { 26, -33 }, { 26, -44 } },
	StorageLoop = { { -11, -72 }, { -20, -66 }, { -31, -70 }, { -31, -62 }, { -26, -58 }, { -14, -62 } },
	PowerLoop = { { 11, -72 }, { 20, -58 }, { 32, -58 }, { 36, -72 }, { 28, -80 }, { 14, -66 } },
	ContainmentLoop = { { 0, -100 }, { 12, -108 }, { 13, -126 }, { 0, -132 }, { -10, -126 }, { -10, -108 } },
}
for rname, pts in pairs(ROUTES) do
	for i, p in ipairs(pts) do
		marker(MK.patrol, "Patrol_" .. rname .. "_" .. i, p[1], 0.5, p[2], "PatrolPoint", { Route = rname, Index = i }, Vector3.new(1.5, 1, 1.5))
	end
end
-- ambient sound zones (set the SoundId attribute to your own audio asset)
for _, z in ipairs({
	{ "Reception", 0, 18, 50, 36, "ventilation hum" }, { "ResearchLab", -26, -39, 40, 30, "electrical buzz" },
	{ "Maintenance", 26, -69, 40, 30, "machinery rumble" }, { "Containment", 0, -116, 44, 40, "low drone + alarm" },
	{ "StorageB", -26, -69, 40, 30, "distant metal creaks" }, { "Medical", 26, -39, 40, 30, "monitor beeps" },
}) do
	local p = marker(MK.ambient, "Ambient_" .. z[1], z[2], 6, z[3], "AmbientZone",
		{ SoundId = "", Volume = 0.5, Suggestion = z[6] }, Vector3.new(z[4], 12, z[5]))
	p.CanQuery = false
end

-- =============================================================================
--  FACILITY MAPS  (schematic wall maps: facing +z = viewer looks north, -z = looks south)
-- =============================================================================
local MAP_COL = {
	Reception = C(70, 110, 150), Security = C(150, 70, 70), MainCorridor = C(110, 112, 108), ResearchLab = C(70, 150, 170),
	Medical = C(90, 160, 120), StorageB = C(150, 130, 70), Maintenance = C(170, 110, 50), ServiceHallA = C(120, 90, 60),
	ServiceHallB = C(120, 90, 60), Decon = C(160, 160, 60), Containment = C(190, 50, 50), Extraction = C(60, 190, 100),
}
local function facilityMap(r, x, y, z, facing, w, h, here)
	local p = P.sign(r, "", x, y, z, w, h, facing, C(14, 22, 30), PAL.offwhite)
	for _, c in ipairs(p:GetChildren()) do c:Destroy() end
	local g = Instance.new("SurfaceGui")
	g.Face = NID.Back
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(math.floor(w * 60), math.floor(h * 60))
	g.Parent = p
	local X0, X1, Z0, Z1 = -50, 50, -164, 40
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.08)
	title.Text = "SITE 9  -  FACILITY MAP"
	title.TextColor3 = PAL.offwhite
	title.Font = Enum.Font.Code
	title.TextScaled = true
	title.Parent = g
	local box = Instance.new("Frame")
	box.Position = UDim2.fromScale(0.04, 0.1)
	box.Size = UDim2.fromScale(0.92, 0.86)
	box.BackgroundTransparency = 1
	box.Parent = g
	for name, rm in pairs(ROOMS) do
		local x0, x1, z0, z1 = rm.x0, rm.x1, rm.z0, rm.z1
		local sx0, sx1, sy0, sy1
		if facing == "+z" then
			sx0, sx1 = (x0 - X0) / (X1 - X0), (x1 - X0) / (X1 - X0)
			sy0, sy1 = (z0 - Z0) / (Z1 - Z0), (z1 - Z0) / (Z1 - Z0)
		else
			sx0, sx1 = (X1 - x1) / (X1 - X0), (X1 - x0) / (X1 - X0)
			sy0, sy1 = (Z1 - z1) / (Z1 - Z0), (Z1 - z0) / (Z1 - Z0)
		end
		local f = Instance.new("Frame")
		f.Position = UDim2.fromScale(sx0, sy0)
		f.Size = UDim2.fromScale(sx1 - sx0, sy1 - sy0)
		f.BackgroundColor3 = MAP_COL[name] or PAL.steel
		f.BorderSizePixel = 1
		f.BackgroundTransparency = (name == here) and 0 or 0.45
		f.Parent = box
		if name == here then
			local d = Instance.new("TextLabel")
			d.BackgroundTransparency = 1
			d.Size = UDim2.fromScale(1, 1)
			d.Text = "YOU ARE HERE"
			d.TextColor3 = C(255, 255, 255)
			d.Font = Enum.Font.GothamBlack
			d.TextScaled = true
			d.Parent = f
		end
	end
	return p
end
facilityMap(ROOMS.Reception, 17, 8.4, 1.0, "+z", 6, 8.6, "Reception")
facilityMap(ROOMS.Security, 10, 7.4, -1.0, "-z", 5, 6.8, "Security")

-- =============================================================================
--  ATMOSPHERE  (global lighting, post effects, client ambience script)
-- =============================================================================
pcall(function() Lighting.Technology = Enum.Technology.Future end)
Lighting.Brightness = 0
Lighting.ClockTime = 0
Lighting.Ambient = C(15, 17, 21)
Lighting.OutdoorAmbient = C(0, 0, 0)
Lighting.ExposureCompensation = 0.35
Lighting.GlobalShadows = true
pcall(function() Lighting.EnvironmentDiffuseScale = 0.06 end)
pcall(function() Lighting.EnvironmentSpecularScale = 0.35 end)
pcall(function() Lighting.ShadowSoftness = 0.25 end)
local atm = Instance.new("Atmosphere")
atm.Name = "FacilityFX_Atmosphere"
atm.Density = 0.3
atm.Offset = 0
atm.Color = C(34, 38, 44)
atm.Decay = C(14, 16, 20)
atm.Glare = 0
atm.Haze = 0.6
atm.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "FacilityFX_Color"
cc.Brightness = 0.02
cc.Contrast = 0.2
cc.Saturation = -0.18
cc.TintColor = C(236, 242, 250)
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "FacilityFX_Bloom"
bloom.Intensity = 0.45
bloom.Size = 24
bloom.Threshold = 0.95
bloom.Parent = Lighting

local RUNTIME = [==[
-- FacilityAmbience (LocalScript): light flicker, pulsing beacons, fans, sparks, ambient audio zones.
local CS = game:GetService("CollectionService")
local RS = game:GetService("RunService")
local rng = Random.new()

local flick, pulse = {}, {}
local function lightOf(inst) return inst:FindFirstChildWhichIsA("Light") end
local function addFlick(inst)
	if not inst:IsA("BasePart") then return end
	local l = lightOf(inst)
	flick[inst] = { l = l, base = l and l.Brightness or 0, sev = inst:GetAttribute("Flicker") or 0.5,
		t = rng:NextNumber(0, 2), on = true, mat = inst.Material, col = inst.Color }
end
local function addPulse(inst)
	if not inst:IsA("BasePart") then return end
	local l = lightOf(inst)
	if l then pulse[inst] = { l = l, base = l.Brightness, speed = inst:GetAttribute("Speed") or 1.5, ph = rng:NextNumber(0, 6) } end
end
for _, i in ipairs(CS:GetTagged("FlickerLight")) do addFlick(i) end
for _, i in ipairs(CS:GetTagged("PulseLight")) do addPulse(i) end
CS:GetInstanceAddedSignal("FlickerLight"):Connect(addFlick)
CS:GetInstanceAddedSignal("PulseLight"):Connect(addPulse)

local fans = {}
for _, m in ipairs(CS:GetTagged("Fan")) do fans[m] = m:GetAttribute("Speed") or 3 end

local sparks, nextSpark = {}, {}
for _, p in ipairs(CS:GetTagged("SparkSource")) do
	sparks[p] = p:FindFirstChildOfClass("ParticleEmitter")
	nextSpark[p] = os.clock() + rng:NextNumber(1, p:GetAttribute("Every") or 6)
end

local t = 0
RS.Heartbeat:Connect(function(dt)
	t += dt
	for inst, s in pairs(flick) do
		s.t -= dt
		if s.t <= 0 then
			if s.on then
				if rng:NextNumber() < s.sev * 0.5 then
					s.on = false
					s.t = rng:NextNumber(0.03, 0.2)
				else
					s.t = rng:NextNumber(0.4, 3.5) / (0.4 + s.sev)
				end
			else
				s.on = true
				s.t = rng:NextNumber(0.1, 2.2) / (0.4 + s.sev)
			end
			if s.l then s.l.Brightness = s.on and s.base or s.base * rng:NextNumber(0, 0.12) end
			inst.Material = s.on and s.mat or Enum.Material.SmoothPlastic
		end
	end
	for _, s in pairs(pulse) do
		s.l.Brightness = s.base * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(t * s.speed + s.ph)))
	end
	for m, sp in pairs(fans) do
		if m.Parent then m:PivotTo(m:GetPivot() * CFrame.Angles(0, 0, sp * dt)) end
	end
	local now = os.clock()
	for p, e in pairs(sparks) do
		if e and now >= nextSpark[p] then
			e:Emit(rng:NextInteger(6, 14))
			nextSpark[p] = now + rng:NextNumber(1.5, p:GetAttribute("Every") or 6)
		end
	end
end)

-- ambient loops: set the SoundId attribute on parts in Workspace.Facility.GameplayMarkers.AmbientZones
for _, z in ipairs(CS:GetTagged("AmbientZone")) do
	local id = z:GetAttribute("SoundId")
	if id and id ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Looped = true
		s.Volume = z:GetAttribute("Volume") or 0.5
		s.RollOffMaxDistance = math.max(z.Size.X, z.Size.Z)
		s.Parent = z
		s:Play()
	end
end
]==]
if CFG.FLICKER then
	local sps = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	if sps then
		local old = sps:FindFirstChild("FacilityAmbience")
		if old then old:Destroy() end
		local ls = Instance.new("LocalScript")
		ls.Name = "FacilityAmbience"
		ls.Source = RUNTIME
		ls.Parent = sps
	end
end


-- ---------------------------------------------------------------- finish
buildAllDoorways()

if CFG.ORIGIN ~= Vector3.zero then
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then d.CFrame = d.CFrame + CFG.ORIGIN end
	end
end

local nParts, nLights = 0, 0
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") then nParts += 1 end
	if d:IsA("Light") then nLights += 1 end
end
print(("[Facility] built: %d parts, %d lights, %d chests. Hit Play - spawn is in Reception."):format(nParts, nLights, chestCount))
if FACILITY_TEST_HOOK then FACILITY_TEST_HOOK({ DW = DW, ROOMS = ROOMS }) end -- only defined by the headless test harness
return root

