
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
