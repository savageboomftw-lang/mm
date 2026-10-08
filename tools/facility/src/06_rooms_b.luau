
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
